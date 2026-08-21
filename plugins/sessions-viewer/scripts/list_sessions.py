#!/usr/bin/env python3
"""
List every Claude Code session ever recorded on this machine, across all
projects and worktrees, sorted by most recently updated.

Reads ~/.claude/projects/<encoded-path>/<session-id>.jsonl
"""
import json
import os
import sys
from datetime import datetime
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"


def decode_project_dir(dirname: str) -> str:
    """Best-effort decode of the dash-encoded project path back to a real path."""
    if dirname.startswith("-"):
        return "/" + dirname[1:].replace("-", "/")
    return dirname.replace("-", "/")


def extract_cwd(jsonl_path: Path, max_lines=20):
    """Claude Code session transcripts record the real working directory
    inside each line's JSON (a "cwd" field). Reading it directly avoids
    guessing, since the folder-name encoding can't tell a space from a
    slash (both become "-")."""
    try:
        with jsonl_path.open("r", errors="ignore") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                cwd = obj.get("cwd")
                if cwd:
                    return cwd
    except OSError:
        pass
    return None
    """Pull the first human message text as a preview, scanning a bounded
    number of lines so huge sessions don't slow things down."""
    try:
        with jsonl_path.open("r", errors="ignore") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = obj.get("message") or {}
                role = msg.get("role") or obj.get("type")
                if role == "user":
                    content = msg.get("content")
                    if isinstance(content, str):
                        text = content
                    elif isinstance(content, list):
                        text = " ".join(
                            block.get("text", "")
                            for block in content
                            if isinstance(block, dict) and block.get("type") == "text"
                        )
                    else:
                        text = ""
                    text = text.strip().replace("\n", " ")
                    if text:
                        return text[:100]
    except OSError:
        pass
    return "(no preview available)"


def count_lines(jsonl_path: Path) -> int:
    try:
        with jsonl_path.open("r", errors="ignore") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def gather_sessions():
    sessions = []
    if not PROJECTS_DIR.exists():
        return sessions
    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        fallback_path = decode_project_dir(project_dir.name)
        for jsonl_file in project_dir.glob("*.jsonl"):
            try:
                mtime = jsonl_file.stat().st_mtime
            except OSError:
                continue
            real_path = extract_cwd(jsonl_file) or fallback_path
            sessions.append(
                {
                    "project": real_path,
                    "project_name": os.path.basename(real_path.rstrip("/")) or real_path,
                    "session_id": jsonl_file.stem,
                    "path": str(jsonl_file),
                    "mtime": mtime,
                    "preview": first_user_message(jsonl_file),
                    "turns": count_lines(jsonl_file),
                }
            )
    sessions.sort(key=lambda s: s["mtime"], reverse=True)
    return sessions


def print_tsv(sessions):
    """Machine-readable output for the fzf-powered browser (bin/claude-sessions).
    Columns: date | project_name | location | session_id | preview | path
    (with-nth in the caller hides session_id and path from the display)."""
    for s in sessions:
        when = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        preview = s["preview"].replace("\t", " ")
        print(f"{when}\t{s['project_name']}\t{s['project']}\t{s['session_id']}\t{preview}\t{s['path']}")


def print_human(sessions):
    if not sessions:
        print("No session files found.")
        return

    print(f"Found {len(sessions)} Claude Code session(s) across "
          f"{len({s['project'] for s in sessions})} project location(s).\n")

    current_project = None
    for s in sessions:
        if s["project"] != current_project:
            current_project = s["project"]
            print(f"\n== {s['project_name']}  ({current_project}) ==")
        when = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        print(f"  [{when}] {s['session_id'][:8]}  ({s['turns']} lines)  {s['preview']}")


def main():
    if not PROJECTS_DIR.exists():
        print(f"No Claude Code project history found at {PROJECTS_DIR}")
        sys.exit(0)

    sessions = gather_sessions()

    if "--tsv" in sys.argv:
        print_tsv(sessions)
    else:
        print_human(sessions)


if __name__ == "__main__":
    main()
