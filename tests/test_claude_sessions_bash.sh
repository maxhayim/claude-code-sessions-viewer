#!/usr/bin/env bash
# Functional tests for bin/claude-sessions' own detection logic (compact
# auto-detection, flag/env overrides, capability detection), driven via
# the CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC test seam — this script otherwise
# has no non-interactive exit path to test against, since its normal
# flow launches an interactive fzf picker. Run locally with:
# ./tests/test_claude_sessions_bash.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_SESSIONS="$REPO_ROOT/bin/claude-sessions"
FAKE_CLAUDE_DIR="$SCRIPT_DIR/fixtures"
# A real-looking PATH that still has dirname/readlink/etc., just no
# `claude` binary in it — simulates "claude isn't installed" without
# also breaking this script's own pre-existing symlink-resolution logic,
# which needs those basic utilities regardless of claude's presence.
NO_CLAUDE_PATH="/usr/bin:/bin"

FAILURES=0
assert_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $desc"
    echo "  expected to find: $needle"
    echo "  actual: $haystack"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}

echo "=== compact auto-detection from terminal size ==="
OUT=$(COLUMNS=60 LINES=20 CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS")
assert_contains "$OUT" "COMPACT=1" "narrow terminal (60x20) auto-detects compact"

OUT=$(COLUMNS=200 LINES=50 CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS")
assert_contains "$OUT" "COMPACT=0" "wide terminal (200x50) auto-detects normal"

echo
echo "=== flag/env overrides take precedence over auto-detection ==="
OUT=$(COLUMNS=200 LINES=50 CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS" --compact)
assert_contains "$OUT" "COMPACT=1" "--compact flag overrides a wide terminal"

OUT=$(COLUMNS=60 LINES=20 CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS" --no-compact)
assert_contains "$OUT" "COMPACT=0" "--no-compact flag overrides a narrow terminal"

OUT=$(COLUMNS=200 LINES=50 CLAUDE_SESSIONS_VIEWER_COMPACT=1 CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS")
assert_contains "$OUT" "COMPACT=1" "CLAUDE_SESSIONS_VIEWER_COMPACT=1 env overrides a wide terminal"

echo
echo "=== --help exits cleanly without touching fzf ==="
OUT=$(bash "$CLAUDE_SESSIONS" --help)
assert_contains "$OUT" "Usage: claude-sessions" "--help prints usage and exits"

echo
echo "=== capability detection against a full-featured claude ==="
OUT=$(PATH="$FAKE_CLAUDE_DIR:$PATH" FAKE_CLAUDE_HELP_MODE=full CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS")
assert_contains "$OUT" "CLOUD_SUPPORTED=1" "full claude --help reports cloud supported"
assert_contains "$OUT" "LIVE_SUPPORTED=1" "full claude --help reports live/agents supported"
assert_contains "$OUT" "ATTACH_SUPPORTED=1" "full claude --help reports attach supported"

echo
echo "=== capability detection against an old claude (lacks the new flags) ==="
OUT=$(PATH="$FAKE_CLAUDE_DIR:$PATH" FAKE_CLAUDE_HELP_MODE=old CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS")
assert_contains "$OUT" "CLOUD_SUPPORTED=0" "old claude --help reports cloud unsupported"
assert_contains "$OUT" "LIVE_SUPPORTED=0" "old claude --help reports live/agents unsupported"
assert_contains "$OUT" "ATTACH_SUPPORTED=0" "old claude --help reports attach unsupported"

echo
echo "=== graceful degradation with no claude on PATH at all ==="
OUT=$(PATH="$NO_CLAUDE_PATH" CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1 bash "$CLAUDE_SESSIONS" 2>/dev/null)
RC=$?
assert_contains "$OUT" "CLOUD_SUPPORTED=0" "no claude on PATH degrades to unsupported, not a crash"
assert_contains "$OUT" "LIVE_SUPPORTED=0" "no claude on PATH: live unsupported"
assert_contains "$OUT" "ATTACH_SUPPORTED=0" "no claude on PATH: attach unsupported"
if [ "$RC" -eq 0 ]; then
  echo "PASS: exits 0 (no stack trace / abort) even with claude entirely missing"
else
  echo "FAIL: exits $RC instead of 0 with claude entirely missing"
  FAILURES=$((FAILURES + 1))
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
