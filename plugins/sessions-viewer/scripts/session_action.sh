#!/usr/bin/env bash
# Right-arrow action menu for a highlighted row in bin/claude-sessions:
# Open / Rename / Delete / Back for that one session, navigated the same
# way as the main list — arrow keys + Enter, no mouse needed. Invoked by
# fzf's execute() bind, so it runs with the parent fzf temporarily
# suspended and full terminal control handed to it.
#
# Usage: session_action.sh <session_id> <jsonl_path> <cd_path> <display_name> <last_active>

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSION_ID="${1:-}"
JSONL_PATH="${2:-}"
CD_PATH="${3:-}"
DISPLAY_NAME="${4:-}"
LAST_ACTIVE="${5:-}"

# No-op on the pinned "+ Start New Session" row, a letter divider, or
# anything without a real session behind it.
if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "__NEW_SESSION__" ]; then
  exit 0
fi
case "$DISPLAY_NAME" in
  *§*) exit 0 ;;
esac

ACCENT_COLOR="pointer:#d97757,prompt:#d97757,marker:#d97757,hl:#d97757,hl+:#d97757,fg+:#ffffff:bold,header:#d97757,footer:#d97757,footer-border:#d97757,border:#d97757,input-border:#d97757,input-label:#d97757:bold,list-border:#d97757,list-label:#d97757:bold,info:#d97757,separator:#d97757,scrollbar:#d97757,spinner:#d97757"

# The main list has no live preview pane (that was a separate box fzf can
# never share a footer with); this is where that info actually lives now —
# a static header showing this one session's last-active date, location,
# and context usage, computed once before opening the menu.
INFO=$(python3 "$SCRIPT_DIR/preview_session.py" "$JSONL_PATH" "$LAST_ACTIVE" "$CD_PATH" --metadata-only)

# `|| true` on each fzf call below is load-bearing: fzf exits non-zero on
# Esc/no-selection, which under `set -e` would otherwise kill this script
# right there — silently, before the case block below ever runs — instead
# of treating Esc the same as picking "Back"/"Cancel".
ACTION=$(printf 'Open\nRename\nDelete\nBack\n' | fzf \
  --height=~40% --layout=reverse \
  --input-border=rounded --input-label=" 🔍 Search " \
  --list-border=rounded --list-label=" $DISPLAY_NAME " \
  --header="$INFO" \
  --footer="↑↓: navigate  ·  enter: select  ·  esc: back" \
  --footer-border=rounded \
  --prompt="❯ " --ghost="Type to search" \
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
      --height=~40% --layout=reverse \
      --input-border=rounded --input-label=" 🔍 Search " \
      --list-border=rounded --list-label=" Delete: $DISPLAY_NAME " \
      --footer="↑↓: navigate  ·  enter: select  ·  esc: cancel" \
      --footer-border=rounded \
      --prompt="❯ " --ghost="Type to search" \
      --color="$ACCENT_COLOR") || true
    if [ "$CONFIRM" = "Yes, delete" ]; then
      rm -f -- "$JSONL_PATH"
    fi
    ;;
  *)
    # Back, Esc, or any other cancel — do nothing and return to the list.
    ;;
esac
