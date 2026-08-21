#!/usr/bin/env python3
"""
Print a readable preview of a Claude Code session transcript for the fzf
preview pane. Usage: preview_session.py <path-to-jsonl> [last-active] [location]
"""
import json
import os
import sys

MAX_MESSAGES = 12
MAX_CHARS_PER_MSG = 300


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


def main():
    if len(sys.argv) < 2:
        print("No session path given.")
        return

    path = sys.argv[1]
    last_active = sys.argv[2] if len(sys.argv) > 2 else None
    location = sys.argv[3] if len(sys.argv) > 3 else None

    if last_active:
        print(f"Last session: {last_active}")
    if location:
        print(f"Location: {location}")
    if last_active or location:
        print(f"session_id: {os.path.splitext(os.path.basename(path))[0]}\n")

    shown = 0
    try:
        with open(path, "r", errors="ignore") as f:
            for line in f:
                if shown >= MAX_MESSAGES:
                    print("\n... (truncated, showing first messages only)")
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
                text = text[:MAX_CHARS_PER_MSG]
                label = "You" if role == "user" else "Claude"
                print(f"[{label}] {text}\n")
                shown += 1
    except OSError as e:
        print(f"Could not read session: {e}")


if __name__ == "__main__":
    main()
