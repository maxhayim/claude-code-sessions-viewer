# Security Policy

## Scope

This tool only reads local files under `~/.claude/projects/` on the machine
it runs on. It does not make network requests, does not transmit session
data anywhere, and does not require any credentials or API keys.

## Reporting a Vulnerability

If you find a security issue (e.g. a way this tool could leak session
contents, execute unintended commands, or escape its intended scope), please
open a GitHub issue or contact the maintainer directly rather than
disclosing it publicly first.

## Known considerations

- `bin/claude-sessions` shells out to `claude --resume` and `cd` using paths
  read from your own local session transcripts. It does not fetch or execute
  anything from the network.
- The `fzf` preview pane executes a `python3` call per highlighted row; this
  only reads local `.jsonl` files, never writes or executes their contents.
