#!/usr/bin/env python3
"""
List currently active Claude Code sessions on this machine (interactive
or backgrounded), for bin/claude-sessions' Live Sessions menu.

Wraps `claude agents --json`, which prints every active session as a
JSON array of {pid, cwd, kind, startedAt, sessionId, name, status}. This
project has no network or process-management code of its own — it only
shapes that command's own output.

Usage:
  live_sessions.py --tsv      7-column TSV, same "display last" shape
                              bin/claude-sessions already expects from
                              list_sessions.py: startedAt | kind | status
                              | cwd | sessionId | name | display
  live_sessions.py --check    Exit 0 and print "ok" if `claude agents
                              --json` works at all (even with 0 sessions);
                              otherwise exit 1 and print the reason.
  live_sessions.py            Human-readable listing, for manual use.
"""
import json
import subprocess
import sys


def fetch_live_sessions(timeout=5):
    """Returns (sessions, None) on success, ([], reason) otherwise. Never
    raises — mirrors list_sessions.py's defensive subprocess handling."""
    try:
        result = subprocess.run(
            ["claude", "agents", "--json"],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return [], "claude is not on PATH"
    except subprocess.SubprocessError as e:
        return [], f"claude agents --json failed to run: {e}"

    if result.returncode != 0:
        return [], f"claude agents --json exited {result.returncode}"

    try:
        sessions = json.loads(result.stdout)
    except json.JSONDecodeError:
        return [], "claude agents --json did not return valid JSON"

    if not isinstance(sessions, list):
        return [], "claude agents --json did not return a JSON array"

    return sessions, None


def display_name(session):
    name = session.get("name") or ""
    if not name:
        session_id = session.get("sessionId") or ""
        name = session_id[:8] if session_id else "(unnamed session)"
    kind = session.get("kind") or "?"
    status = session.get("status") or "?"
    cwd = session.get("cwd") or ""
    return f"{name}  [{kind}/{status}]  {cwd}"


def print_tsv(sessions):
    for s in sessions:
        row = [
            str(s.get("startedAt") or ""),
            str(s.get("kind") or ""),
            str(s.get("status") or ""),
            str(s.get("cwd") or ""),
            str(s.get("sessionId") or ""),
            str(s.get("name") or ""),
            display_name(s),
        ]
        print("\t".join(field.replace("\t", " ") for field in row))


def print_human(sessions):
    if not sessions:
        print("No active Claude Code sessions found.")
        return
    for s in sessions:
        print(display_name(s))


def main():
    args = sys.argv[1:]

    if "--check" in args:
        sessions, reason = fetch_live_sessions()
        if reason is not None:
            print(reason, file=sys.stderr)
            sys.exit(1)
        print("ok")
        return

    sessions, reason = fetch_live_sessions()
    if reason is not None:
        # Not a hard failure for --tsv callers (an unsupported/missing
        # claude binary just means "no live sessions available" to the
        # picker) — stderr carries the reason for anyone debugging.
        print(reason, file=sys.stderr)
        sessions = []

    if "--tsv" in args:
        print_tsv(sessions)
    else:
        print_human(sessions)


if __name__ == "__main__":
    main()
