#!/usr/bin/env bash
# Functional tests for cloud_sessions.sh's pure command-builder functions
# (sourced directly — no fzf, no exec, no side effects) and its
# capability checks against a fake `claude --help` on PATH. Run locally
# with: ./tests/test_cloud_sessions.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLOUD_SESSIONS="$REPO_ROOT/plugins/sessions-viewer/scripts/cloud_sessions.sh"
FAKE_CLAUDE_DIR="$SCRIPT_DIR/fixtures"

# shellcheck disable=SC1090
source "$CLOUD_SESSIONS"

FAILURES=0
assert_eq() {
  local actual="$1" expected="$2" desc="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $desc"
    echo "  expected: $(printf '%s' "$expected" | tr '\t' '|')"
    echo "  actual:   $(printf '%s' "$actual" | tr '\t' '|')"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}

echo "=== command builders: exact tab-joined argv strings ==="
assert_eq "$(cloud_create_cmd "my desc")" "$(printf 'claude\t--cloud\tmy desc')" "cloud_create_cmd with a description"
assert_eq "$(cloud_create_cmd "")" "$(printf 'claude\t--cloud')" "cloud_create_cmd with no description"
assert_eq "$(cloud_attach_cmd "https://claude.ai/code/abc123")" "$(printf 'claude\t--cloud\thttps://claude.ai/code/abc123')" "cloud_attach_cmd by URL"
assert_eq "$(cloud_teleport_cmd "")" "$(printf 'claude\t--teleport')" "cloud_teleport_cmd with no id (interactive picker)"
assert_eq "$(cloud_teleport_cmd "sess123")" "$(printf 'claude\t--teleport\tsess123')" "cloud_teleport_cmd with an id"
assert_eq "$(cloud_from_pr_cmd "")" "$(printf 'claude\t--from-pr')" "cloud_from_pr_cmd with no value (interactive picker)"
assert_eq "$(cloud_from_pr_cmd "123")" "$(printf 'claude\t--from-pr\t123')" "cloud_from_pr_cmd with a PR number"
assert_eq "$(cloud_followup_cmd "sess123" "hello there")" "$(printf 'claude\t--cloud\tsess123\t-p\thello there')" "cloud_followup_cmd"

echo
echo "=== availability checks: each run in a fresh subshell so the help cache never bleeds between fixtures ==="
check() {
  local fn="$1" mode="$2"
  PATH="$FAKE_CLAUDE_DIR:$PATH" FAKE_CLAUDE_HELP_MODE="$mode" bash -c "source '$CLOUD_SESSIONS'; $fn && echo yes || echo no"
}
assert_eq "$(check cloud_available full)" "yes" "cloud_available is yes when --help lists --cloud"
assert_eq "$(check cloud_available old)" "no" "cloud_available is no when --help lacks --cloud"
assert_eq "$(check teleport_available full)" "yes" "teleport_available is yes when --help lists --teleport"
assert_eq "$(check teleport_available old)" "no" "teleport_available is no when --help lacks --teleport"
assert_eq "$(check from_pr_available full)" "yes" "from_pr_available is yes when --help lists --from-pr"
assert_eq "$(check from_pr_available old)" "no" "from_pr_available is no when --help lacks --from-pr"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
