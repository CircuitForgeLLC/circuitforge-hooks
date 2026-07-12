# circuitforge-hooks

Centralised git hooks for all CircuitForge repos.

## What it does

- **pre-commit** — scans staged changes for secrets and PII via gitleaks
- **commit-msg** — enforces conventional commit format
- **pre-push** — holds pushes during core hours (see below), then scans full branch history as a safety net before push

## Core-hours push hold

Pushes attempted Mon-Fri 10:00-15:00 local time are held rather than sent — this is a
visible conflict-of-interest guardrail, not a concealment mechanism. Each hold prints
exactly what happened and why. Nothing about the commit itself changes (author, timestamp,
content are untouched); only the point at which it becomes visible on the remote is
deferred until outside that window.

- Held pushes are recorded in `/Library/Development/CircuitForge/.push-queue/queue.tsv`.
- A cron job (`*/20 * * * *`, see `crontab -l`) runs `scripts/flush-push-queue.sh` every 20
  minutes; it's a no-op while still in core hours, and delivers any queued pushes once
  outside that window.
- To push immediately regardless of the current time (e.g. you know you're clear to,
  or you're testing): `bash scripts/flush-push-queue.sh --force`. This bypasses only the
  time hold — the gitleaks scan still runs on every actual push, no exceptions.
- Activity log: `/Library/Development/CircuitForge/.push-queue/queue.log`.

## Install

From any CircuitForge product repo root:

```bash
bash /Library/Development/CircuitForge/circuitforge-hooks/install.sh
```

On Heimdall live deploys (`/devl/<repo>/`), add the same line to the deploy script.

## Per-repo allowlists

Create `.gitleaks.toml` at the repo root to extend the base config:

```toml
[extend]
path = "/Library/Development/CircuitForge/circuitforge-hooks/gitleaks.toml"

[allowlist]
regexes = [
    '\d{10}\.html',   # example: Craigslist listing IDs
]
```

## Testing

```bash
bash tests/test_hooks.sh
```

## Requirements

- `gitleaks` binary: `sudo apt-get install gitleaks`
- bash 4+

## Adding a new rule

Edit `gitleaks.toml`. Follow the pattern of the existing `[[rules]]` blocks.
Add tests to `tests/test_hooks.sh` covering both the blocked and allowed cases.

---

Humans own design, architecture, code review, testing, and verification. LLMs are part of our development workflow. [Our positions on LLM use →](https://circuitforge.tech/positions)
