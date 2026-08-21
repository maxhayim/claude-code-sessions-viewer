#!/usr/bin/env bash
# Functional tests for list_sessions.py against synthetic fixture data,
# via CLAUDE_SESSIONS_VIEWER_PROJECTS_DIR so the real ~/.claude/projects
# is never touched. Run locally with: ./tests/test_list_sessions.sh
# Exits non-zero (and prints which assertion failed) on any failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIST_SESSIONS="$REPO_ROOT/plugins/sessions-viewer/scripts/list_sessions.py"

FIXTURES_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURES_DIR"' EXIT

FAILURES=0
assert_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $desc"
    echo "  expected to find: $needle"
    echo "  --- actual output ---"
    echo "  ${haystack//$'\n'/$'\n  '}"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}
assert_not_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "FAIL: $desc"
    echo "  expected NOT to find: $needle"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS: $desc"
  fi
}

# --- Fixture 1: a git repo checked out into a generically-named local
# folder ("Repo"), with a session inside it that's never been renamed. ---
REPO1="$FIXTURES_DIR/work/my-actual-project/Repo"
mkdir -p "$REPO1"
git -C "$REPO1" init -q
git -C "$REPO1" remote add origin "https://github.com/someuser/real-repo-name.git"

PROJECTS_DIR="$FIXTURES_DIR/.claude/projects"
DIR1="$PROJECTS_DIR/-fixture-repo-one"
mkdir -p "$DIR1"
cat > "$DIR1/11111111-1111-1111-1111-111111111111.jsonl" <<EOF
{"type":"user","message":{"role":"user","content":"help me fix the login bug"},"cwd":"$REPO1"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Sure, let's look at it."}],"usage":{"input_tokens":2,"cache_read_input_tokens":100,"cache_creation_input_tokens":50,"output_tokens":10}}}
EOF

# --- Fixture 2: a renamed session, no git remote at all (plain folder). ---
DIR2="$PROJECTS_DIR/-fixture-no-git"
mkdir -p "$DIR2"
cat > "$DIR2/22222222-2222-2222-2222-222222222222.jsonl" <<EOF
{"type":"user","message":{"role":"user","content":"quick one-off question"},"cwd":"$FIXTURES_DIR/no-git-folder"}
{"type":"agent-name","agentName":"My Renamed Session","sessionId":"22222222-2222-2222-2222-222222222222"}
EOF

# --- Fixture 3: a sub-agent transcript nested under fixture 1's session —
# must NOT show up as its own entry. ---
SUBAGENT_DIR="$DIR1/11111111-1111-1111-1111-111111111111/subagents"
mkdir -p "$SUBAGENT_DIR"
cat > "$SUBAGENT_DIR/agent-should-not-appear.jsonl" <<EOF
{"type":"user","message":{"role":"user","content":"sub-agent task"},"cwd":"$REPO1"}
EOF

export CLAUDE_SESSIONS_VIEWER_PROJECTS_DIR="$PROJECTS_DIR"

echo "=== --projects-tsv: git remote name resolved, not folder name 'Repo' ==="
OUT=$(python3 "$LIST_SESSIONS" --projects-tsv)
assert_contains "$OUT" "real-repo-name" "resolves git remote name for a generically-named folder"
assert_not_contains "$OUT" $'\tRepo\t' "does not show the raw folder name 'Repo' as a project"

echo
echo "=== --tsv: renamed session's *display* column (7) prefers /rename name over raw preview ==="
OUT=$(python3 "$LIST_SESSIONS" --tsv --sort-by=session)
assert_contains "$OUT" "My Renamed Session" "shows the /rename display name somewhere in the row"
DISPLAY_COL=$(printf '%s\n' "$OUT" | awk -F'\t' '$4=="22222222-2222-2222-2222-222222222222" {print $7}')
assert_contains "$DISPLAY_COL" "My Renamed Session" "display column (7) is the rename name"
assert_not_contains "$DISPLAY_COL" "quick one-off question" "display column (7) does not fall back to preview text when a rename name exists"

echo
echo "=== sub-agent transcripts are excluded ==="
COUNT=$(python3 "$LIST_SESSIONS" --tsv | wc -l | tr -d ' ')
assert_contains "$COUNT" "2" "exactly 2 real sessions found (sub-agent transcript excluded)"

echo
echo "=== --project-preview: filters correctly by resolved project name ==="
OUT=$(python3 "$LIST_SESSIONS" --project-preview="real-repo-name")
assert_contains "$OUT" "help me fix the login bug" "project-preview shows the right session's content"

echo
echo "=== human-readable mode: dictionary letter divider present ==="
OUT=$(NO_COLOR=1 python3 "$LIST_SESSIONS")
assert_contains "$OUT" "§" "letter divider present in human-readable output"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
