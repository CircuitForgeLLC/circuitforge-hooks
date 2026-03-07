#!/usr/bin/env bash
# install.sh — wire circuitforge-hooks into the calling git repo
# Usage: bash /Library/Development/CircuitForge/circuitforge-hooks/install.sh
# Usage (quiet): bash /Library/Development/CircuitForge/circuitforge-hooks/install.sh --quiet
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/hooks" && pwd)"
QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

if ! git rev-parse --git-dir &>/dev/null; then
    echo "ERROR: not inside a git repo. Run from your product repo root."
    exit 1
fi

git config core.hooksPath "$HOOKS_DIR"

if [[ "$QUIET" == "false" ]]; then
    echo "CircuitForge hooks installed."
    echo "  core.hooksPath → $HOOKS_DIR"
    echo ""
    echo "Verify gitleaks is available: gitleaks version"
fi
