#!/usr/bin/env python3
"""
List every Claude Code session ever recorded on this machine, across all
projects and worktrees, sorted by most recently updated.

Reads ~/.claude/projects/<encoded-path>/<session-id>.jsonl
"""
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"

_repo_name_cache = {}


def repo_name(project_path: str):
    """The project's real identity: its GitHub/git remote name if it's a git
    checkout with an origin remote (e.g. "MaXHyM-Scripts" even when the
    local folder is just called "Repo"). Returns (name, is_repo) — is_repo
    is False when there's no remote to identify it by (not a git repo, or a
    git repo with no origin configured), so the caller can avoid bucketing
    unrelated sessions together under a generic folder name."""
    if project_path in _repo_name_cache:
        return _repo_name_cache[project_path]

    name = None
    try:
        result = subprocess.run(
            ["git", "-C", project_path, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=2,
        )
        if result.returncode == 0 and result.stdout.strip():
            url = result.stdout.strip().rstrip("/")
            if url.endswith(".git"):
                url = url[:-4]
            name = url.rsplit("/", 1)[-1] or None
    except (OSError, subprocess.SubprocessError):
        pass

    is_repo = name is not None
    if not name:
        name = os.path.basename(project_path.rstrip("/")) or project_path

    _repo_name_cache[project_path] = (name, is_repo)
    return _repo_name_cache[project_path]


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


def session_name(jsonl_path: Path):
    """The custom title set via Claude Code's /rename command, if any (the
    most recent one, if renamed more than once). A rename can happen
    anywhere in a session, so this scans the whole file rather than just
    the first few lines — cheaply, via a substring check before parsing."""
    name = None
    try:
        with jsonl_path.open("r", errors="ignore") as f:
            for line in f:
                if '"type":"agent-name"' not in line and '"type": "agent-name"' not in line:
                    continue
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("type") == "agent-name" and obj.get("agentName"):
                    name = obj["agentName"]
    except OSError:
        pass
    return name


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
        # glob("*.jsonl"), not "**/*.jsonl": sub-agent transcripts live one
        # level deeper, in <session_id>/subagents/agent-*.jsonl. Those are
        # execution logs for a Task-tool call within a session, not
        # resumable sessions in their own right, so they're intentionally
        # not picked up here.
        for jsonl_file in project_dir.glob("*.jsonl"):
            try:
                mtime = jsonl_file.stat().st_mtime
            except OSError:
                continue
            real_path = extract_cwd(jsonl_file) or fallback_path
            name = session_name(jsonl_file)
            preview = first_user_message(jsonl_file)
            folder_name, is_repo = repo_name(real_path)
            # A real git repo's sessions group together under its repo name.
            # A session with no identifiable repo (run from a plain folder
            # like a general workspace root) isn't really part of any
            # project cohort, so it gets its own top-level entry instead of
            # being hidden inside a generic folder-name bucket.
            if is_repo:
                project_name = folder_name
            else:
                raw = name or preview
                project_name = raw if len(raw) <= 60 else raw[:59] + "…"
            sessions.append(
                {
                    "project": real_path,
                    "project_name": project_name,
                    "session_id": jsonl_file.stem,
                    "path": str(jsonl_file),
                    "mtime": mtime,
                    "preview": preview,
                    "turns": count_lines(jsonl_file),
                    "name": name,
                }
            )
    return sessions


def sort_sessions(sessions, sort_by):
    if sort_by == "date":
        sessions.sort(key=lambda s: s["mtime"], reverse=True)
    elif sort_by == "session":
        # Alphabetical by the session's own display text (its /rename name
        # if it has one, else its first-message preview) — used for the
        # session list within an already-chosen project.
        sessions.sort(key=lambda s: (s["name"] or s["preview"]).lower())
    else:
        # Alphabetical by project name first (so same-project sessions stay
        # grouped together in print_human instead of interleaving by date),
        # most-recent session first within each project.
        sessions.sort(key=lambda s: (s["project_name"].lower(), s["project"].lower(), -s["mtime"]))
    return sessions


def print_tsv(sessions, grouped=False):
    """Machine-readable output for the fzf-powered browser (bin/claude-sessions).
    Columns: date | project_name | location | session_id | preview | path |
    display (the /rename name if the session has one, else the preview
    text — what the picker actually shows for each row). When grouped=True,
    a dictionary-style "§ <letter>" divider row (see print_projects_tsv) is
    printed before each new starting letter of the display text."""
    color = "" if os.environ.get("NO_COLOR") else "\033[1;38;2;217;119;87m"
    reset = "" if os.environ.get("NO_COLOR") else "\033[0m"
    current_letter = None

    for s in sessions:
        when = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        preview = s["preview"].replace("\t", " ")
        display = (s["name"] or s["preview"]).replace("\t", " ")

        if grouped:
            letter = display[0].upper() if display else "#"
            if not letter.isalpha():
                letter = "#"
            if letter != current_letter:
                current_letter = letter
                print(f"\t\t\t\t\t\t{color}{DIVIDER_MARK} {letter}{reset}")

        print(f"{when}\t{s['project_name']}\t{s['project']}\t{s['session_id']}\t{preview}\t{s['path']}\t{display}")


DIVIDER_MARK = "§"  # prefixes letter-group header rows so bin/claude-sessions
                     # can recognize and ignore them if one is ever selected.


def print_projects_tsv(sessions):
    """One row per unique project *name* (not location — two different
    checkouts of the same-named project are grouped together), for the
    project-picker stage of bin/claude-sessions. Columns: project_name |
    session_count | latest_date. Dictionary-style: a letter divider row is
    printed before each new starting letter."""
    projects = {}
    for s in sessions:
        p = projects.setdefault(s["project_name"], {"count": 0, "latest": s["mtime"]})
        p["count"] += 1
        p["latest"] = max(p["latest"], s["mtime"])

    color = "" if os.environ.get("NO_COLOR") else "\033[1;38;2;217;119;87m"
    reset = "" if os.environ.get("NO_COLOR") else "\033[0m"

    current_letter = None
    for name, info in sorted(projects.items(), key=lambda kv: kv[0].lower()):
        letter = name[0].upper() if name else "#"
        if not letter.isalpha():
            letter = "#"
        if letter != current_letter:
            current_letter = letter
            print(f"{color}{DIVIDER_MARK} {letter}{reset}\t\t")
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

    sort_by = get_arg_value("--sort-by=") or "name"
    sessions = sort_sessions(sessions, sort_by)

    project_filter = get_arg_value("--project=")
    if project_filter is not None:
        sessions = [s for s in sessions if s["project_name"] == project_filter]

    if "--tsv" in sys.argv:
        print_tsv(sessions, grouped="--grouped" in sys.argv)
    else:
        print_human(sessions)


if __name__ == "__main__":
    main()
