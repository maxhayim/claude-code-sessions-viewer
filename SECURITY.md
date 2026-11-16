# Security Policy

## Scope

This tool's core (Local sessions) only reads local files under
`~/.claude/projects/` on the machine it runs on. That part makes no network
requests, transmits no session data anywhere, and requires no credentials or
API keys.

As of v3.0.0, this tool also offers Live and Cloud session features. Both
are thin wrappers that build a command line and run your own installed
`claude` binary (`--cloud`, `--teleport`, `--from-pr`, `agents --json`,
`attach`) — any network traffic happens entirely inside the `claude` CLI,
under your own pre-existing authentication. This project:

- never reads, stores, transmits, or proxies any credential, API key, or
  OAuth token, and
- contains **no HTTP/network client code of its own** — this is a hard
  implementation constraint, not just a documentation claim. If a future
  change seems to need its own networking, that's a reason to stop and
  reconsider the design, not to add it.

SSH usage (for reaching a remote host or the Cardputer Zero in compact
mode) is always a session you already started yourself, with your own
existing setup; this project opens no ports and runs no network service of
its own. `claude --remote-control` is Anthropic's own feature — this
project only links to it, and does not reverse-engineer or build against
its internals.

## Reporting a Vulnerability

If you find a security issue (e.g. a way this tool could leak session
contents, execute unintended commands, or escape its intended scope), please
open a GitHub issue or contact the maintainer directly rather than
disclosing it publicly first.

## Known considerations

- `bin/claude-sessions` shells out to `claude --resume` and `cd` using paths
  read from your own local session transcripts. The Local session flow does
  not fetch or execute anything from the network.
- The `fzf` preview pane executes a `python3` call per highlighted row; this
  only reads local `.jsonl` files, never writes or executes their contents.
  This preview is skipped entirely in compact mode (see README).
- **Live Sessions** calls `claude agents --json`, which lists *every* active
  Claude Code session on the machine (interactive or backgrounded) —
  `pid`, `cwd`, `sessionId`, and name — not just ones started from this
  tool. This is the same visibility `claude agents` already exposes;
  this tool just surfaces it in the picker. Attaching to a session with
  `claude attach` hands control of that running process to this terminal.
- **Cloud Sessions**: there is no documented command to list existing cloud
  sessions, only to create one or attach by a known ID or URL — the menu
  says so rather than inventing a list. Creating a cloud session via
  `--cloud` is a real action against Anthropic's API and may be billed
  under your account, like any other use of the `claude` CLI.
