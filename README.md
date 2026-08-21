# Claude Code Sessions Viewer

```
╭──────────────────────────────────────────╮
│                                          │
│   ┌─┐┌─┐┌─┐┬  ┬                          │
│   │  │  └─┐└┐┌┘                          │
│   └─┘└─┘└─┘ └┘   Claude Code             │
│                       Sessions Viewer    │
│                                          │
╰──────────────────────────────────────────╯
```

[![Python Version](https://img.shields.io/badge/Python-3.8%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)](#requirements)
[![Release](https://img.shields.io/badge/Release-v1.1.0-blue)](https://github.com/maxhayim/claude-code-sessions-viewer/releases/tag/v1.1.0)

> **Unofficial, community-built project. Not affiliated with, endorsed by,
> or sponsored by Anthropic.** "[Claude Code](https://github.com/anthropics/claude-code)" refers to Anthropic's product;
> this tool simply reads its local session files.

> **Status: v1.1.0.** Verified end-to-end against real
> `~/.claude/projects/` data, including the Homebrew install path. See
> [Known Limitations](#known-limitations) for what's still untested (multi-
> machine coverage, Windows).

**Claude Code Sessions Viewer** lists — and lets you visually browse — every 
[Claude Code](https://github.com/anthropics/claude-code) session you've ever started, across every project directory and
git worktree on your machine, all in one flat, alphabetically-sorted,
dictionary-style list — no digging through per-project menus. Claude Code's
own picker only shows sessions from your current directory unless you know
to widen it, and even widened it renders as a small fixed-height box with
no real preview. This project adds two things on top:

- **`/list-sessions`** — a plain-text listing you run inside a Claude Code
  session, grouped by project, most recent first.
- **`bin/claude-sessions`** — a standalone, `fzf`-powered visual browser:
  fuzzy search, arrow-key navigation, a live conversation preview pane, and
  an Open/Rename/Delete action menu for every session.

## Features

- Scans every project directory Claude Code has ever recorded a session in,
  not just the current one, and shows every session in **one flat,
  alphabetical list** — grouped into dictionary-style letter sections
  (`§ A`, `§ B`, ...) rather than nested per-project submenus
- Shows each session by its real name — its Claude Code `/rename` title if
  it has one, its first-message preview otherwise
- Resolves each project's real identity from its **git remote**, not its
  local folder name — so a repo checked out into a generically-named
  folder (e.g. everything living under a local `Repo/` directory) still
  shows its actual GitHub repo name, and a session run outside any git repo
  gets its own top-level entry instead of being lumped under a generic
  folder bucket
- Reads the real working directory straight from each session transcript's
  `cwd` field, rather than guessing from the encoded folder name (Claude
  Code encodes both `/` and spaces as `-`, which makes folder-name decoding
  ambiguous — see [Known Limitations](#known-limitations))
- Visual browser (`bin/claude-sessions`) adds fuzzy search, a live
  conversation preview pane (shows when the session was last active,
  where it lives, and the conversation itself), and:
  - **Enter / double-click** — resume the session
  - **Right arrow** — an Open / Rename / Delete action menu for the
    highlighted session, all keyboard-navigable
  - **A pinned "+ Start New Session" entry** at the top of the list —
    prompts for a name and launches a new, already-named session
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

**Via Homebrew (recommended, macOS/Linux):**
```bash
brew tap maxhayim/claude-code-sessions-viewer https://github.com/maxhayim/claude-code-sessions-viewer
brew install claude-sessions-viewer
claude-sessions
```
This pulls in `fzf` and Python automatically as dependencies.

**Manual install:**
```bash
brew install fzf   # macOS; use your package manager on Linux
# bin/claude-sessions also auto-installs fzf via brew/apt-get on first
# run if it's missing

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

Inside the visual browser, everything is keyboard-driven — arrow keys +
Enter, no mouse needed (double-click also works if you prefer it):

- **Type anything** to fuzzy-search across all session names/previews — the
  search box is always live, no need to navigate to it first
- **↑ / ↓** to move through the list; sessions are grouped into
  dictionary-style letter sections (`§ A`, `§ B`, ...)
- The pane below the list live-previews when the session was last active,
  where it lives, its context-window usage, and the conversation itself,
  with orange page-break dividers between each section
- **Enter / double-click** resumes the highlighted session (`cd`s into its
  project directory, then runs `claude --resume <id>`)
- **Right arrow** opens an action menu for the highlighted session:
  - **Open** — same as Enter
  - **Rename** — prompts for a new name and applies it via `/rename`
  - **Delete** — permanently removes that session's transcript file, after
    a confirmation step (no undo — see
    [Known Limitations](#known-limitations))
  - **Back** — closes the menu, no change
- **+ Start New Session**, pinned at the very top of the list — prompts for
  a name, then launches a fresh `claude` session already named that
- **Esc** cancels/backs out at any screen

## How It Works

Scans `~/.claude/projects/*/*.jsonl` (not `**/*.jsonl` — sub-agent
transcripts, which live one level deeper in
`<session_id>/subagents/agent-*.jsonl`, are intentionally excluded; they're
Task-tool execution logs, not resumable sessions in their own right). Each
session's real project directory is read directly from the `cwd` field
recorded in its transcript, and its display name comes from its `/rename`
title if it has one (Claude Code records this as an `agent-name` line in
the transcript), otherwise its first-message preview. Each project's
identity is resolved from `git remote get-url origin` when it's a git
checkout, falling back to the folder's own name otherwise — sessions with
no git remote (not a repo, or a repo with no `origin` configured) get
promoted to their own top-level list entry rather than being grouped
under a generic folder name. Everything is sorted alphabetically and
either printed as plain text (`/list-sessions`) or piped into `fzf` with a
live preview command (`bin/claude-sessions`).

## Known Limitations

- **Delete has no undo.** The right-arrow menu's Delete action (after
  confirmation) permanently removes that session's `.jsonl` transcript
  file from disk. There's no trash/recovery — it's gone.
- **Rename and new-session naming rely on an unverified assumption**: that
  running `claude --resume <id> "/rename <name>"` (or `claude "/rename
  <name>"` for a new session) processes the `/rename` command as the
  session's first action, the same way typing it interactively would. This
  hasn't been confirmed against a real interactive `claude` session — if
  it instead sends `/rename ...` as a literal chat message rather than
  running the command, please open an issue.
- **Folder-name decoding is ambiguous by design in Claude Code's own
  storage** — both `/` and spaces become `-` in the project directory name,
  so a naive decode can't tell `Foo Bar/Baz` from `Foo/Bar/Baz`. This
  project works around it by reading the transcript's own `cwd` field
  instead, but if an older or unusual transcript is missing that field, it
  falls back to the ambiguous decode and may point at the wrong directory.
- **Verified on one machine so far (macOS).** Confirmed working end-to-end,
  including the Homebrew install path, against real `~/.claude/projects/`
  data on a single machine. Not yet confirmed across a wide range of
  machines/data. If something breaks, please
  [open an issue](../../issues/new?template=bug_report.md).
- **`bin/claude-sessions` requires `fzf`.** If it's missing, the script
  attempts to auto-install it via `brew` (macOS) or `apt-get` (Debian/
  Ubuntu); on other systems you'll need to install it manually. The
  plain-text `/list-sessions` command has no `fzf` dependency at all.
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
