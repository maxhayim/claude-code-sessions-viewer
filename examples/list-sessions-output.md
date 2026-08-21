# Example: /list-sessions output

Sample output from the plain-text slash command (paths anonymized):

```
Found 5 Claude Code session(s) across 3 project location(s).

== MyProject  (/Users/you/Projects/MyProject) ==
  [2026-08-20 14:32] 87f78955  (142 lines)  Can you help me debug the auth flow?
  [2026-08-18 09:10] a3d9e211  (58 lines)   Add unit tests for the parser

== dotfiles  (/Users/you/dotfiles) ==
  [2026-08-15 20:05] 6b1f0e42  (23 lines)   Update my zsh aliases

== side-project  (/Users/you/Projects/side-project) ==
  [2026-08-10 11:47] c209aa88  (301 lines)  Refactor the API client
  [2026-08-02 16:20] 5e77bb01  (12 lines)   Quick question about npm workspaces
```

See the main [README](../README.md) for how to get the visual (`fzf`)
version of this same data.
