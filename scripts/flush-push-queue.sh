#!/usr/bin/env bash
# flush-push-queue.sh — deliver pushes held by the pre-push core-hours guardrail.
#
# By default, only runs outside core hours (Mon-Fri 10:00-15:00 local) — this is the
# script a periodic cron job should call. Pass --force to flush immediately regardless
# of the current time (still goes through the normal pre-push hook, including the
# gitleaks scan — this only bypasses the core-hours hold, nothing else).
#
# Usage:
#   bash flush-push-queue.sh           # no-op if currently in core hours
#   bash flush-push-queue.sh --force   # flush right now regardless of time
set -uo pipefail

QUEUE_DIR="${CIRCUITFORGE_QUEUE_DIR:-/Library/Development/CircuitForge/.push-queue}"
QUEUE_FILE="$QUEUE_DIR/queue.tsv"
LOG_FILE="$QUEUE_DIR/queue.log"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

in_core_hours() {
    local dow hour
    dow=$(date +%u)
    hour=$(date +%H)
    hour=$((10#$hour))
    if (( dow >= 1 && dow <= 5 )) && (( hour >= 10 && hour < 15 )); then
        return 0
    fi
    return 1
}

mkdir -p "$QUEUE_DIR"
touch "$QUEUE_FILE" "$LOG_FILE"

if [[ "$FORCE" == "false" ]] && in_core_hours; then
    # Quiet no-op — this is the expected outcome most times a cron-driven run fires
    # during the work day. Log at debug level only to avoid noisy logs.
    exit 0
fi

if [[ ! -s "$QUEUE_FILE" ]]; then
    exit 0
fi

ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }

remaining_file=$(mktemp)
trap 'rm -f "$remaining_file"' EXIT

while IFS=$'\t' read -r repo_root remote local_ref; do
    [[ -z "$repo_root" ]] && continue

    if [[ ! -d "$repo_root/.git" ]]; then
        echo "$(ts)  drop     $repo_root  $remote  $local_ref  (repo no longer exists)" >> "$LOG_FILE"
        continue
    fi

    branch="${local_ref#refs/heads/}"
    # CIRCUITFORGE_BYPASS_CORE_HOURS tells the pre-push hook (still installed, still runs
    # the gitleaks scan) that THIS script already made the "is it actually time to push"
    # decision — otherwise a --force flush during core hours would just re-queue itself.
    if CIRCUITFORGE_BYPASS_CORE_HOURS=1 git -C "$repo_root" push "$remote" "$local_ref" 2>>"$LOG_FILE"; then
        echo "$(ts)  pushed   $repo_root  $remote  $branch" >> "$LOG_FILE"
    else
        echo "$(ts)  retry    $repo_root  $remote  $branch  (push failed, kept in queue)" >> "$LOG_FILE"
        echo -e "$repo_root\t$remote\t$local_ref" >> "$remaining_file"
    fi
done < "$QUEUE_FILE"

mv "$remaining_file" "$QUEUE_FILE"
trap - EXIT
