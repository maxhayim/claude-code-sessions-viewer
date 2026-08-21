#!/usr/bin/env bash
# Right-arrow action menu for a highlighted row in bin/claude-sessions:
# Open / Rename / Delete / Back for that one session, navigated the same
# way as the main list — arrow keys + Enter, no mouse needed. Invoked by
# fzf's execute() bind, so it runs with the parent fzf temporarily
# suspended and full terminal control handed to it.
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

# `|| true` on each fzf call below is load-bearing: fzf exits non-zero on
# Esc/no-selection, which under `set -e` would otherwise kill this script
# right there — silently, before the case block below ever runs — instead
# of treating Esc the same as picking "Back"/"Cancel".
ACTION=$(printf 'Open\nRename\nDelete\nBack\n' | fzf \
  --height=~30% --layout=reverse --border=rounded \
  --header="$DISPLAY_NAME"$'\n''↑↓: navigate  ·  enter: select  ·  esc: back' \
  --prompt="Action ❯ " \
  --color="$ACCENT_COLOR") || true

case "$ACTION" in
  Open)
    if [ ! -d "$CD_PATH" ]; then
      echo "Project directory no longer exists: $CD_PATH" >&2
      read -r -p "Press enter to continue..." _
      exit 0
    fi
    (cd "$CD_PATH" && claude --resume "$SESSION_ID") || true
    ;;
  Rename)
    printf 'New name: '
    read -r NEW_NAME
    if [ -n "$NEW_NAME" ]; then
      claude --resume "$SESSION_ID" "/rename $NEW_NAME" || true
    fi
    ;;
  Delete)
    CONFIRM=$(printf 'Cancel\nYes, delete\n' | fzf \
      --height=~30% --layout=reverse --border=rounded \
      --header="Delete: $DISPLAY_NAME"$'\n''↑↓: navigate  ·  enter: select  ·  esc: cancel' \
      --prompt="Confirm ❯ " \
      --color="$ACCENT_COLOR") || true
    if [ "$CONFIRM" = "Yes, delete" ]; then
      rm -f -- "$JSONL_PATH"
    fi
    ;;
  *)
    # Back, Esc, or any other cancel — do nothing and return to the list.
    ;;
esac
