#!/usr/bin/env bash
# Command-builders and menu for Cloud sessions (claude --cloud / --teleport
# / --from-pr). Sourced by bin/claude-sessions — do not execute directly;
# cloud_sessions_menu() uses ACCENT/RESET/FZF_BOX, which the parent script
# defines. The *_cmd functions below are pure (no exec, no side effects)
# so they can be tested in isolation by sourcing this file directly.
#
# There is no documented command to list existing cloud sessions — only
# create-new or attach-by-known-id/url. This project does not invent one;
# the menu below says so rather than pretending a list exists.
#
# This file contains no network code of its own: every action below just
# builds an argv and execs the user's own `claude` binary, which is what
# actually talks to Anthropic's API, under the user's own existing auth.

CLOUD_HELP_CACHE=""
_cloud_help_cache() {
  if [ -z "$CLOUD_HELP_CACHE" ]; then
    CLOUD_HELP_CACHE=$(claude --help 2>&1) || CLOUD_HELP_CACHE=""
    [ -z "$CLOUD_HELP_CACHE" ] && CLOUD_HELP_CACHE=" "
  fi
}

cloud_available() {
  _cloud_help_cache
  case "$CLOUD_HELP_CACHE" in
    *"--cloud"*) return 0 ;;
    *) return 1 ;;
  esac
}

teleport_available() {
  _cloud_help_cache
  case "$CLOUD_HELP_CACHE" in
    *"--teleport"*) return 0 ;;
    *) return 1 ;;
  esac
}

from_pr_available() {
  _cloud_help_cache
  case "$CLOUD_HELP_CACHE" in
    *"--from-pr"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Each *_cmd function prints a tab-joined argv (no trailing newline) —
# never execs, never has side effects — so these are directly testable.
cloud_create_cmd() {
  if [ -n "${1:-}" ]; then
    printf 'claude\t--cloud\t%s' "$1"
  else
    printf 'claude\t--cloud'
  fi
}

cloud_attach_cmd() {
  printf 'claude\t--cloud\t%s' "$1"
}

cloud_teleport_cmd() {
  if [ -n "${1:-}" ]; then
    printf 'claude\t--teleport\t%s' "$1"
  else
    printf 'claude\t--teleport'
  fi
}

cloud_from_pr_cmd() {
  if [ -n "${1:-}" ]; then
    printf 'claude\t--from-pr\t%s' "$1"
  else
    printf 'claude\t--from-pr'
  fi
}

# UNVERIFIED: this exact combination (-p alongside --cloud <id>) hasn't
# been independently confirmed to send a one-shot follow-up to an
# existing cloud session, as opposed to, say, creating a new one. The
# menu surfaces this same caveat at the point of use.
cloud_followup_cmd() {
  printf 'claude\t--cloud\t%s\t-p\t%s' "$1" "$2"
}

# Splits a tab-joined command string (from one of the _cmd functions
# above) into the CMD array, one argv element per line — safe for
# elements containing spaces, since each was already a separate printf
# argument before being tab-joined.
_cloud_split_cmd() {
  CMD=()
  while IFS= read -r part; do
    CMD+=("$part")
  done < <(printf '%s' "$1" | tr '\t' '\n')
}

cloud_sessions_menu() {
  local action id desc msg cmd_str
  action=$(printf 'Create new cloud session\nAttach to existing (ID or URL)\nResume teleport session\nResume PR-linked session\nSend follow-up to existing cloud session\nBack\n' | \
    fzf --layout=reverse \
        --header="${ACCENT}Claude has no documented way to list existing cloud sessions —${RESET}
${ACCENT}paste a known session ID or claude.ai/code URL when asked.${RESET}" --header-first \
        --list-label=" Cloud Sessions " \
        --footer="type to search · enter/double-click: select · esc: back" \
        --prompt="❯ " --pointer="▶" \
        --bind="double-click:accept" \
        --color="pointer:#d97757,prompt:#d97757,header:#d97757,list-border:#d97757,list-label:#d97757:bold,footer:#d97757") || return 0
  [ -z "$action" ] && return

  case "$action" in
    "Create new cloud session")
      printf 'Description (optional): '
      read -r desc
      cmd_str=$(cloud_create_cmd "$desc")
      ;;
    "Attach to existing (ID or URL)")
      printf 'Session ID or claude.ai/code URL: '
      read -r id
      if [ -z "$id" ]; then
        echo "No ID/URL entered." >&2
        read -r -p "Press enter to continue..." _
        return
      fi
      cmd_str=$(cloud_attach_cmd "$id")
      ;;
    "Resume teleport session")
      printf 'Teleport session ID (blank = interactive picker): '
      read -r id
      cmd_str=$(cloud_teleport_cmd "$id")
      ;;
    "Resume PR-linked session")
      printf 'PR number or URL (blank = interactive picker): '
      read -r id
      cmd_str=$(cloud_from_pr_cmd "$id")
      ;;
    "Send follow-up to existing cloud session")
      printf 'Session ID: '
      read -r id
      printf 'Message: '
      read -r msg
      if [ -z "$id" ] || [ -z "$msg" ]; then
        echo "Both a session ID and a message are required." >&2
        read -r -p "Press enter to continue..." _
        return
      fi
      cmd_str=$(cloud_followup_cmd "$id" "$msg")
      ;;
    *)
      return
      ;;
  esac

  _cloud_split_cmd "$cmd_str"

  if [ "$action" = "Send follow-up to existing cloud session" ]; then
    echo "${ACCENT}Note: the -p + --cloud follow-up combination is not independently verified — if this errors, that's expected until confirmed.${RESET}" >&2
    "${CMD[@]}" || true
    read -r -p "Press enter to continue..." _
  else
    exec "${CMD[@]}"
  fi
}
