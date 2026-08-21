#!/usr/bin/env bash
# Right-arrow action menu for a highlighted row in bin/claude-sessions:
# offers Open (resume) or Delete for that one session. Invoked by fzf's
# execute() bind, so it runs with the parent fzf temporarily suspended and
# full terminal control handed to it.
#
# Usage: session_action.sh <session_id> <jsonl_path> <cd_path> <display_name>

set -euo pipefail

SESSION_ID="${1:-}"
JSONL_PATH="${2:-}"
CD_PATH="${3:-}"
DISPLAY_NAME="${4:-}"

# No-op on the pinned "+ Start New Session" row, a letter divider, or
# anything without a real session behind it.
if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "__NEW_SESSION__" ]; then
  exit 0
fi
case "$DISPLAY_NAME" in
  *§*) exit 0 ;;
esac

ACCENT_COLOR="pointer:#d97757,prompt:#d97757,header:#d97757,border:#d97757"

ACTION=$(printf 'Open\nDelete\n' | fzf \
  --height=~30% --layout=reverse --border=rounded \
  --header="$DISPLAY_NAME" --prompt="Action ❯ " \
  --color="$ACCENT_COLOR")

case "$ACTION" in
  Open)
    if [ ! -d "$CD_PATH" ]; then
      echo "Project directory no longer exists: $CD_PATH" >&2
      read -r -p "Press enter to continue..." _
      exit 0
    fi
    (cd "$CD_PATH" && claude --resume "$SESSION_ID")
    ;;
  Delete)
    CONFIRM=$(printf 'Cancel\nYes, delete\n' | fzf \
      --height=~30% --layout=reverse --border=rounded \
      --header="Delete: $DISPLAY_NAME" --prompt="Confirm ❯ " \
      --color="$ACCENT_COLOR")
    if [ "$CONFIRM" = "Yes, delete" ]; then
      rm -f -- "$JSONL_PATH"
    fi
    ;;
esac
