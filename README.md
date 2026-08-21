# Claude Code Sessions Viewer

```
   ╭──────────────────────────────────────╮
   │                                        │
   │   ┌─┐┌─┐┌─┐┬  ┬                        │
   │   │  ├─┘└─┐└┐┌┘                        │
   │   └─┘┴  └─┘ └┘   sessions viewer       │
   │                                        │
   │   for Claude Code                      │
   │                                        │
   ╰──────────────────────────────────────╯
```

[![Python Version](https://img.shields.io/badge/Python-3.8%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)](#requirements)

> **Unofficial, community-built project. Not affiliated with, endorsed by,
> or sponsored by Anthropic.** "[Claude Code](https://github.com/anthropics/claude-code)" refers to Anthropic's product;
> this tool simply reads its local session files.

> **Status: early / unverified.** This has been built and syntax-checked but
> not yet run end-to-end against real `~/.claude/projects/` data by more
> than one machine. Expect rough edges. See [Known Limitations](#known-limitations).

**Claude Code Sessions Viewer** lists — and lets you visually browse — every 
[Claude Code](https://github.com/anthropics/claude-code) session you've ever started, across every project directory and
git worktree on your machine. Claude Code's own picker only shows sessions
from your current directory unless you know to widen it, and even widened
it renders as a small fixed-height box with no real preview. This project
adds two things on top:

- **`/list-sessions`** — a plain-text listing you run inside a Claude Code
  session, grouped by project, most recent first.
- **`bin/claude-sessions`** — a standalone, `fzf`-powered visual browser:
  fuzzy search, arrow-key navigation, a live conversation preview pane, and
  one keypress to resume the session you land on.

## Features

- Scans every project directory Claude Code has ever recorded a session in,
  not just the current one
- Reads the real working directory straight from each session transcript's
  `cwd` field, rather than guessing from the encoded folder name (Claude
  Code encodes both `/` and spaces as `-`, which makes folder-name decoding
  ambiguous — see [Known Limitations](#known-limitations))
- Shows project name, full location, last-modified time, line count, and a
  preview of the session's first message
- Visual browser (`bin/claude-sessions`) adds fuzzy search, a live
  conversation preview pane, and one-keypress resume
- No network calls, no credentials, reads only local files — see
  [SECURITY.md](SECURITY.md)

## Requirements

- Python 3.8+ (standard library only — see [requirements.txt](requirements.txt))
- Claude Code, obviously — this reads its local session storage
- [`fzf`](https://github.com/junegunn/fzf) — only required for the visual
  browser (`bin/claude-sessions`); the `/list-sessions` slash command has no
  extra dependency

## Installation and Setup

### Install the slash command (plugin)

```
/plugin marketplace add maxhayim/claude-code-sessions-viewer
/plugin install sessions-viewer@claude-code-sessions-viewer
```

Then, in any Claude Code session:

```
/list-sessions
```

See [examples/list-sessions-output.md](examples/list-sessions-output.md) for
sample output.

### Install the visual browser

```bash
brew install fzf   # macOS; use your package manager on Linux

git clone https://github.com/maxhayim/claude-code-sessions-viewer.git
cd claude-code-sessions-viewer
./bin/claude-sessions
```

Run it directly in your terminal — **not** as a slash command inside a
running Claude Code session, since resuming has to replace the current
process, which a plugin command can't do from inside a session.

To use it from anywhere:
```bash
ln -s "$(pwd)/bin/claude-sessions" /usr/local/bin/claude-sessions
```

## Usage

Inside the visual browser:
- Type to fuzzy-search across project names, locations, and message previews
- Arrow keys to move through the list
- Right-hand pane live-previews the actual conversation
- `Enter` or double-click resumes the selected session (`cd`s into its
  project directory, then runs `claude --resume <id>`)
- `Esc` cancels

## How It Works

Scans `~/.claude/projects/*/*.jsonl`. Each session's real project directory
is read directly from the `cwd` field recorded in its transcript. Project
name, location, last-modified time, and a message preview are extracted per
session, sorted most-recent-first, and either printed as plain text
(`/list-sessions`) or piped into `fzf` with a live preview command
(`bin/claude-sessions`).

## Known Limitations

- **Folder-name decoding is ambiguous by design in Claude Code's own
  storage** — both `/` and spaces become `-` in the project directory name,
  so a naive decode can't tell `Foo Bar/Baz` from `Foo/Bar/Baz`. This
  project works around it by reading the transcript's own `cwd` field
  instead, but if an older or unusual transcript is missing that field, it
  falls back to the ambiguous decode and may point at the wrong directory.
- **Not yet verified across machines.** Built and reviewed against
  documented Claude Code transcript behavior, not yet confirmed against a
  wide range of real `~/.claude/projects/` data. If something breaks, please
  [open an issue](../../issues/new?template=bug_report.md).
- **`bin/claude-sessions` requires `fzf`.** No fallback visual mode if it's
  not installed — the plain-text `/list-sessions` command still works
  without it.
- **macOS/Linux only, tested on macOS.** Windows is untested; paths and the
  `cd && exec` resume flow may need adjustment.

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.
Full license text: <https://opensource.org/licenses/MIT>

## Contributing

Pull requests are welcome. Open an issue first to discuss ideas or report
bugs. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and testing notes.

## Related Projects

- [Claude Code docs: Manage sessions](https://code.claude.com/docs/en/sessions)
- [fzf](https://github.com/junegunn/fzf)
- [claude-code-history-mcp](https://mcpservers.org/servers/yudppp/claude-code-history-mcp) — MCP server alternative with search/filtering
- [tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager) — tmux-based alternative for parallel session management

## Acknowledgments
"[Claude Code](https://github.com/anthropics/claude-code)" is a trademark of Anthropic, PBC, used here solely to
describe compatibility. This project is not affiliated with, endorsed by,
or sponsored by Anthropic. All other trademarks are the property of their
respective owners.
