# Contributing

Pull requests are welcome. Open an issue first to discuss ideas or report bugs.

## Development setup

This project has no build step — it's a Claude Code plugin (Python +
bash) plus a standalone shell script. To work on it locally:

```bash
git clone https://github.com/maxhayim/claude-code-sessions-viewer.git
cd claude-code-sessions-viewer

# Test the plugin's slash command logic directly:
python3 plugins/sessions-viewer/scripts/list_sessions.py

# Test the visual browser (requires fzf):
./bin/claude-sessions
```

## Testing `bin/claude-sessions` without a real terminal

`bin/claude-sessions` normally launches an interactive `fzf` picker, which
has no non-interactive exit path to assert against. For automated tests
of its own detection logic (compact-mode auto-detect, capability checks),
set `CLAUDE_SESSIONS_VIEWER_DIAGNOSTIC=1` — the script prints its detected
`COMPACT`/`COLS`/`LINES`/`CLOUD_SUPPORTED`/`LIVE_SUPPORTED`/
`ATTACH_SUPPORTED` values and exits before touching `fzf` at all. This is
a test-only seam (not documented in the user-facing README) — see
`tests/test_claude_sessions_bash.sh` for how it's used, and
`tests/fixtures/claude` for the fake `claude` binary the tests put on
`PATH` to control what `claude --help`/`claude agents --json` report.

## Before submitting a PR

- Run `python -m py_compile` on any Python files you touched.
- Run [`shellcheck`](https://www.shellcheck.net/) on any shell scripts you
  touched — `bin/claude-sessions` needs `shellcheck -x` (it sources
  `plugins/sessions-viewer/scripts/cloud_sessions.sh`).
- Validate any JSON manifest changes with `python -m json.tool <file>`.
- Run the test suite: `./tests/test_list_sessions.sh`,
  `./tests/test_live_sessions.sh`, `./tests/test_cloud_sessions.sh`, and
  `./tests/test_claude_sessions_bash.sh`.
- Test against a real `~/.claude/projects/` directory if your change touches
  session parsing — synthetic test data can miss real transcript quirks.
- **Bump both plugin manifests on every release** —
  `plugins/sessions-viewer/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json`. These drifted at `"1.0.0"` across 11
  git tags before v3.0.0 caught up; don't let that happen again.

## Reporting bugs

Use the [bug report template](../../issues/new?template=bug_report.md) and
include your OS, Claude Code version, and (if relevant) `fzf --version`.
