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

## Before submitting a PR

- Run `python -m py_compile` on any Python files you touched.
- Run [`shellcheck`](https://www.shellcheck.net/) on `bin/claude-sessions` if you touched it.
- Validate any JSON manifest changes with `python -m json.tool <file>`.
- Test against a real `~/.claude/projects/` directory if your change touches
  session parsing — synthetic test data can miss real transcript quirks.

## Reporting bugs

Use the [bug report template](../../issues/new?template=bug_report.md) and
include your OS, Claude Code version, and (if relevant) `fzf --version`.
