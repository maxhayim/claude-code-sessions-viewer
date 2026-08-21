#!/usr/bin/env bash
# ctrl-x bulk-delete for one or more rows in bin/claude-sessions' main list.
# Works uniformly whether 0 rows are Tab-marked (fzf's {+n} falls back to
# the single highlighted row) or several are.
#
# Usage: bulk_delete.sh <id1> <id2> ... -- <path1> <path2> ...
# (session_ids and jsonl paths as two same-length, "--"-separated groups,
# in the same order — this is how bin/claude-sessions invokes it via
# fzf's {+4} -- {+6} placeholders.)

set -euo pipefail

IDS=()
PATHS=()
MODE="ids"
for arg in "$@"; do
  if [ "$arg" = "--" ]; then
    MODE="paths"
    continue
  fi
  if [ "$MODE" = "ids" ]; then
    IDS+=("$arg")
  else
    PATHS+=("$arg")
  fi
done

# Filter out the pinned "+ Start New Session" row (sentinel id) and any
# row with no real id/path (e.g. a letter divider, which has empty fields).
REAL_PATHS=()
for i in "${!IDS[@]}"; do
  id="${IDS[$i]}"
  path="${PATHS[$i]:-}"
  if [ -z "$id" ] || [ "$id" = "__NEW_SESSION__" ] || [ -z "$path" ]; then
    continue
  fi
  REAL_PATHS+=("$path")
done

if [ "${#REAL_PATHS[@]}" -eq 0 ]; then
  exit 0
fi

ACCENT_COLOR="pointer:#d97757,prompt:#d97757,marker:#d97757,hl:#d97757,hl+:#d97757,fg+:#ffffff:bold,header:#d97757,footer:#d97757,border:#d97757,input-border:#d97757,input-label:#d97757:bold,list-border:#d97757,list-label:#d97757:bold,info:#d97757,separator:#d97757,scrollbar:#d97757,spinner:#d97757"

COUNT="${#REAL_PATHS[@]}"
LIST_PREVIEW=$(printf '%s\n' "${REAL_PATHS[@]}" | xargs -n1 basename | sed 's/\.jsonl$//')

# `|| true`: fzf exits non-zero on Esc, which under `set -e` would
# otherwise abort this script before the case below can treat it as
# "Cancel" (same fix as session_action.sh's submenus).
CONFIRM=$(printf 'Cancel\nYes, delete %d session(s)\n' "$COUNT" | fzf \
  --height=~40% --layout=reverse \
  --input-border=rounded --input-label=" 🔍 Search " \
  --list-border=rounded --list-label=" Bulk Delete " \
  --header="$LIST_PREVIEW" \
  --footer="↑↓: navigate  ·  enter: select  ·  esc: cancel" \
  --ghost="Type to search" \
  --prompt="❯ " \
  --color="$ACCENT_COLOR") || true

case "$CONFIRM" in
  "Yes, delete "*)
    for p in "${REAL_PATHS[@]}"; do
      rm -f -- "$p"
    done
    ;;
esac
