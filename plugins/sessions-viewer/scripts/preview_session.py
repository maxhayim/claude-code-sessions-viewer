#!/usr/bin/env python3
"""
Print info about a Claude Code session transcript, for bin/claude-sessions'
Open/Rename/Delete/Back menu — which shows this in two separate boxes:
a small metadata header, and a taller conversation-preview pane.

Usage:
  preview_session.py <path-to-jsonl> [last-active] [location]
      Metadata block only (last active, location, context usage,
      session_id) — used as the menu's --header.
  preview_session.py <path-to-jsonl> --conversation
      Conversation preview only — used as the menu's --preview.
"""
import json
import os
import sys

MAX_MESSAGES = 20
MAX_CHARS_PER_MSG = 300

# Claude's standard context window. Some accounts/models have access to a
# larger extended-context window (up to 1M tokens for some Claude 5
# models); there's no local, network-free way to know which applies to a
# given session, so this is a labeled estimate, not an exact figure.
STANDARD_CONTEXT_WINDOW = 200_000


def latest_context_usage(jsonl_path):
    """Tokens used in the most recent turn's context (input + cache read +
    cache creation — i.e. everything sent to the model that turn), from
    the last assistant message's usage block. None if no usage data
    found."""
    used = None
    try:
        with open(jsonl_path, "r", errors="ignore") as f:
            for line in f:
                if '"usage"' not in line:
                    continue
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = obj.get("message") or {}
                if msg.get("role") != "assistant":
                    continue
                usage = msg.get("usage")
                if not isinstance(usage, dict):
                    continue
                total = (
                    (usage.get("input_tokens") or 0)
                    + (usage.get("cache_read_input_tokens") or 0)
                    + (usage.get("cache_creation_input_tokens") or 0)
                )
                if total:
                    used = total
    except OSError:
        pass
    return used


def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text":
                parts.append(block.get("text", ""))
            elif block.get("type") == "tool_use":
                parts.append(f"[used tool: {block.get('name', '?')}]")
        return " ".join(parts)
    return ""


def print_metadata(path, last_active, location):
    if last_active:
        print(f"Last session: {last_active}")
    if location:
        print(f"Location: {location}")

    used = latest_context_usage(path)
    if used is not None:
        left = STANDARD_CONTEXT_WINDOW - used
        print(
            f"Context: {used:,} used / ~{max(left, 0):,} left "
            f"(of ~{STANDARD_CONTEXT_WINDOW:,} standard context — actual "
            f"limit may be higher with extended context)"
        )

    if last_active or location:
        print(f"session_id: {os.path.splitext(os.path.basename(path))[0]}")


def print_conversation(path):
    accent = "" if os.environ.get("NO_COLOR") else "\033[38;2;217;119;87m"
    reset = "" if os.environ.get("NO_COLOR") else "\033[0m"
    divider = f"{accent}{'─' * 40}{reset}"

    shown = 0
    try:
        with open(path, "r", errors="ignore") as f:
            for line in f:
                if shown >= MAX_MESSAGES:
                    print("... (truncated, showing first messages only)")
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = obj.get("message") or {}
                role = msg.get("role")
                if role not in ("user", "assistant"):
                    continue
                text = extract_text(msg.get("content")).strip().replace("\n", " ")
                if not text:
                    continue
                # Skip synthetic messages injected by slash commands like
                # /resume (caveat/command-name/stdout wrappers, and
                # Claude's "no response" ack) — noise, not conversation.
                if text.startswith("<local-command-") or text.startswith("<command-"):
                    continue
                if text.startswith("No response requested"):
                    continue
                text = text[:MAX_CHARS_PER_MSG]
                label = "You" if role == "user" else "Claude"
                print(f"[{label}] {text}")
                print(divider)
                shown += 1
    except OSError as e:
        print(f"Could not read session: {e}")

    if shown == 0:
        print("(no conversation content found)")


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        # Empty path — e.g. the pinned "+ Start New Session" row or a
        # letter divider, neither of which have a real session behind them.
        print("Select a session to see its info.")
        return

    conversation_mode = "--conversation" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--conversation"]
    path = args[0]

    if conversation_mode:
        print_conversation(path)
        return

    last_active = args[1] if len(args) > 1 else None
    location = args[2] if len(args) > 2 else None
    print_metadata(path, last_active, location)


if __name__ == "__main__":
    main()
