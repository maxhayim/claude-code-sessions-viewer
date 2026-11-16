#!/usr/bin/env bash
# Functional tests for live_sessions.py against a fake `claude` binary on
# PATH (tests/fixtures/fake-claude) — no real Claude Code session
# registry or network access needed. Run locally with:
# ./tests/test_live_sessions.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE_SESSIONS="$REPO_ROOT/plugins/sessions-viewer/scripts/live_sessions.py"
FAKE_CLAUDE_DIR="$SCRIPT_DIR/fixtures"

FAILURES=0
assert_eq() {
  local actual="$1" expected="$2" desc="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}
assert_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $desc"
    echo "  expected to find: $needle"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== --tsv: good path, two fixture sessions ==="
OUT=$(PATH="$FAKE_CLAUDE_DIR:$PATH" python3 "$LIVE_SESSIONS" --tsv)
ROWCOUNT=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
assert_eq "$ROWCOUNT" "2" "two fixture sessions printed"
assert_contains "$OUT" "Fixture One" "first fixture session name present"
assert_contains "$OUT" "Fixture Two" "second fixture session name present"
FIELDCOUNT=$(printf '%s\n' "$OUT" | head -1 | awk -F'\t' '{print NF}')
assert_eq "$FIELDCOUNT" "7" "row has exactly 7 tab-separated fields"

echo
echo "=== --check: success path ==="
OUT=$(PATH="$FAKE_CLAUDE_DIR:$PATH" python3 "$LIVE_SESSIONS" --check)
assert_eq "$OUT" "ok" "--check prints ok when claude agents --json works"

echo
echo "=== malformed JSON: no crash, empty --tsv output, stderr explains why ==="
BADFILE="$TMP_DIR/bad.json"
echo "not valid json" > "$BADFILE"
OUT=$(PATH="$FAKE_CLAUDE_DIR:$PATH" FAKE_CLAUDE_AGENTS_OUTPUT="$BADFILE" python3 "$LIVE_SESSIONS" --tsv 2>"$TMP_DIR/stderr")
assert_eq "$OUT" "" "malformed JSON yields empty --tsv output, not a crash"
ERR=$(cat "$TMP_DIR/stderr")
assert_contains "$ERR" "valid JSON" "stderr explains the malformed-JSON failure"

echo
echo "=== no claude on PATH ==="
NO_CLAUDE_PATH="/usr/bin:/bin"
OUT=$(PATH="$NO_CLAUDE_PATH" python3 "$LIVE_SESSIONS" --check 2>"$TMP_DIR/stderr")
RC=$?
assert_eq "$RC" "1" "--check exits 1 when claude isn't on PATH"
ERR=$(cat "$TMP_DIR/stderr")
assert_contains "$ERR" "not on PATH" "stderr explains claude is missing"

OUT=$(PATH="$NO_CLAUDE_PATH" python3 "$LIVE_SESSIONS" --tsv 2>/dev/null)
RC=$?
assert_eq "$RC" "0" "--tsv still exits 0 (degrades gracefully) when claude is missing"
assert_eq "$OUT" "" "--tsv prints no rows when claude is missing"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
