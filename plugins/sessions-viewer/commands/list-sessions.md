---
description: List every Claude Code session ever recorded on this machine, by name, alphabetically
argument-hint: ""
---

Run this command and show me the full output exactly as printed — every session shown by its real name (its `/rename` title if it has one, its first-message preview otherwise), sorted alphabetically and letter-grouped:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py"
```

After showing the output, briefly note which session was most recently active and ask if I want to `/resume` a specific one.
