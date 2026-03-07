#!/usr/bin/env bash
# tests/test_hooks.sh — integration tests for circuitforge-hooks
# Requires: gitleaks installed, bash 4+
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Create a temp git repo for realistic staged-content tests
setup_temp_repo() {
    local dir
    dir=$(mktemp -d)
    git init "$dir" -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "Test"
    git -C "$dir" config core.hooksPath "$HOOKS_DIR"
    echo "$dir"
}

echo ""
echo "=== pre-commit hook tests ==="

# Test 1: blocks live-format Forgejo token
echo "Test 1: blocks FORGEJO_API_TOKEN=<hex>"
REPO=$(setup_temp_repo)
echo 'FORGEJO_API_TOKEN=YOUR_FORGEJO_TOKEN_HERE' > "$REPO/test.env"
git -C "$REPO" add test.env
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:1"; then pass "blocked FORGEJO_API_TOKEN"; else fail "should have blocked FORGEJO_API_TOKEN"; fi
rm -rf "$REPO"

# Test 2: blocks OpenAI-style sk- key
echo "Test 2: blocks sk-<key> pattern"
REPO=$(setup_temp_repo)
echo 'api_key = "sk-abcXYZ1234567890abcXYZ1234567890"' > "$REPO/config.py"
git -C "$REPO" add config.py
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:1"; then pass "blocked sk- key"; else fail "should have blocked sk- key"; fi
rm -rf "$REPO"

# Test 3: blocks US phone number
echo "Test 3: blocks US phone number"
REPO=$(setup_temp_repo)
echo 'phone: "5107643155"' > "$REPO/config.yaml"
git -C "$REPO" add config.yaml
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:1"; then pass "blocked phone number"; else fail "should have blocked phone number"; fi
rm -rf "$REPO"

# Test 4: blocks personal email in source
echo "Test 4: blocks personal gmail address in .py file"
REPO=$(setup_temp_repo)
echo 'DEFAULT_EMAIL = "someone@gmail.com"' > "$REPO/app.py"
git -C "$REPO" add app.py
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:1"; then pass "blocked personal email"; else fail "should have blocked personal email"; fi
rm -rf "$REPO"

# Test 5: allows .example file with placeholders
echo "Test 5: allows .example file with placeholder values"
REPO=$(setup_temp_repo)
echo 'FORGEJO_API_TOKEN=your-forgejo-api-token-here' > "$REPO/config.env.example"
git -C "$REPO" add config.env.example
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:0"; then pass "allowed .example placeholder"; else fail "should have allowed .example file"; fi
rm -rf "$REPO"

# Test 6: allows ollama api_key placeholder
echo "Test 6: allows api_key: ollama (known safe placeholder)"
REPO=$(setup_temp_repo)
printf 'backends:\n  - api_key: ollama\n' > "$REPO/llm.yaml"
git -C "$REPO" add llm.yaml
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:0"; then pass "allowed ollama api_key"; else fail "should have allowed ollama api_key"; fi
rm -rf "$REPO"

# Test 7: allows safe source file
echo "Test 7: allows normal Python import"
REPO=$(setup_temp_repo)
echo 'import streamlit as st' > "$REPO/app.py"
git -C "$REPO" add app.py
RESULT=$(cd "$REPO" && bash "$HOOKS_DIR/pre-commit" 2>&1; echo "EXIT:$?")
if echo "$RESULT" | grep -q "EXIT:0"; then pass "allowed safe file"; else fail "should have allowed safe file"; fi
rm -rf "$REPO"

echo ""
echo "=== commit-msg hook tests ==="

tmpfile=$(mktemp)

echo "Test 8: accepts feat: message"
echo "feat: add gitleaks scanning" > "$tmpfile"
if bash "$HOOKS_DIR/commit-msg" "$tmpfile" &>/dev/null; then pass "accepted feat:"; else fail "rejected valid feat:"; fi

echo "Test 9: accepts security: message (new type)"
echo "security: rotate leaked API token" > "$tmpfile"
if bash "$HOOKS_DIR/commit-msg" "$tmpfile" &>/dev/null; then pass "accepted security:"; else fail "rejected valid security:"; fi

echo "Test 10: accepts fix(scope): message"
echo "fix(wizard): handle missing user.yaml" > "$tmpfile"
if bash "$HOOKS_DIR/commit-msg" "$tmpfile" &>/dev/null; then pass "accepted fix(scope):"; else fail "rejected valid fix(scope):"; fi

echo "Test 11: rejects non-conventional message"
echo "updated the thing" > "$tmpfile"
if bash "$HOOKS_DIR/commit-msg" "$tmpfile" &>/dev/null; then fail "should have rejected"; else pass "rejected non-conventional"; fi

echo "Test 12: rejects empty message"
echo "" > "$tmpfile"
if bash "$HOOKS_DIR/commit-msg" "$tmpfile" &>/dev/null; then fail "should have rejected empty"; else pass "rejected empty message"; fi

rm -f "$tmpfile"

echo ""
echo "=== Results ==="
echo "  Passed: $PASS_COUNT"
echo "  Failed: $FAIL_COUNT"
[[ $FAIL_COUNT -eq 0 ]] && echo "All tests passed." || { echo "FAILURES detected."; exit 1; }
