#!/usr/bin/env python3
"""
Print a readable preview of a Claude Code session transcript for the fzf
preview pane. Usage: preview_session.py <path-to-jsonl>
"""
import json
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
