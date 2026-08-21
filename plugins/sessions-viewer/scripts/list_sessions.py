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


def first_user_message(jsonl_path: Path, max_lines=20):
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
    return sessions


def sort_sessions(sessions, sort_by):
    if sort_by == "date":
        sessions.sort(key=lambda s: s["mtime"], reverse=True)
    else:
        # Alphabetical by project name first (so same-project sessions stay
        # grouped together in print_human instead of interleaving by date),
        # most-recent session first within each project.
        sessions.sort(key=lambda s: (s["project_name"].lower(), s["project"].lower(), -s["mtime"]))
    return sessions


def print_tsv(sessions):
    """Machine-readable output for the fzf-powered browser (bin/claude-sessions).
    Columns: date | project_name | location | session_id | preview | path
    (with-nth in the caller hides session_id and path from the display)."""
    for s in sessions:
        when = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        preview = s["preview"].replace("\t", " ")
        print(f"{when}\t{s['project_name']}\t{s['project']}\t{s['session_id']}\t{preview}\t{s['path']}")


def print_projects_tsv(sessions):
    """One row per unique project *name* (not location — two different
    checkouts of the same-named project are grouped together), for the
    project-picker stage of bin/claude-sessions. Columns: project_name |
    session_count | latest_date."""
    projects = {}
    for s in sessions:
        p = projects.setdefault(s["project_name"], {"count": 0, "latest": s["mtime"]})
        p["count"] += 1
        p["latest"] = max(p["latest"], s["mtime"])

    for name, info in sorted(projects.items(), key=lambda kv: kv[0].lower()):
        when = datetime.fromtimestamp(info["latest"]).strftime("%Y-%m-%d %H:%M")
        print(f"{name}\t{info['count']}\t{when}")


def print_project_preview(sessions, project_name):
    """Detail shown in the preview pane while picking a project: every
    session with that project name, most recent first."""
    matches = [s for s in sessions if s["project_name"] == project_name]
    if not matches:
        print("No sessions found for this project.")
        return
    matches.sort(key=lambda s: s["mtime"], reverse=True)
    print(f"{project_name}\n{len(matches)} session(s)\n")
    for s in matches:
        when = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        print(f"[{when}] ({s['turns']} lines)  {s['preview']}\n")


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


def get_arg_value(prefix):
    for arg in sys.argv:
        if arg.startswith(prefix):
            return arg[len(prefix):]
    return None


def main():
    if not PROJECTS_DIR.exists():
        print(f"No Claude Code project history found at {PROJECTS_DIR}")
        sys.exit(0)

    sessions = gather_sessions()

    project_preview = get_arg_value("--project-preview=")
    if project_preview is not None:
        print_project_preview(sessions, project_preview)
        return

    if "--projects-tsv" in sys.argv:
        print_projects_tsv(sessions)
        return

    sort_by = "date" if "--sort-by=date" in sys.argv else "name"
    sessions = sort_sessions(sessions, sort_by)

    project_filter = get_arg_value("--project=")
    if project_filter is not None:
        sessions = [s for s in sessions if s["project_name"] == project_filter]

    if "--tsv" in sys.argv:
        print_tsv(sessions)
    else:
        print_human(sessions)


if __name__ == "__main__":
    main()
