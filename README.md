# circuitforge-hooks

Centralised git hooks for all CircuitForge repos.

## What it does

- **pre-commit** — scans staged changes for secrets and PII via gitleaks
- **commit-msg** — enforces conventional commit format
- **pre-push** — scans full branch history as a safety net before push

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
