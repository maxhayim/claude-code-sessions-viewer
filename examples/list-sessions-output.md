# Example: /list-sessions output

Sample output from the plain-text slash command (paths anonymized). Each
session shows by its real name — its `/rename` title if it has one,
otherwise its first-message preview — sorted alphabetically and grouped
into dictionary-style letter sections, the same as the visual browser:

```
5 Claude Code session(s), sorted alphabetically by name.

§ A
  [2026-08-15 20:05] 6b1f0e42  (dotfiles)  Add unit tests for the parser

§ M
  [2026-08-10 11:47] c209aa88  (side-project)  My API client refactor

§ Q
  [2026-08-02 16:20] 5e77bb01  (side-project)  Quick question about npm workspaces

§ R
  [2026-08-20 14:32] 87f78955  (MyProject)  Rename: auth-flow-debug

§ U
  [2026-08-15 20:05] 6b1f0e42  (dotfiles)  Update my zsh aliases
```

The name in parentheses is each session's project — resolved from its git
remote when it's a repo, or its own top-level entry when it isn't tied to
one.

See the main [README](../README.md) for how to get the visual (`fzf`)
version of this same data.
