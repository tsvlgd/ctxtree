---
description: Where were we? Load project memory and report state, freshness and the next step
---

1. If a `<project-memory>` block is already in context, use it. Otherwise run `ctxtree where`; if it prints a root, read `memory/INDEX.md` and `memory/active-task.md` (if it exists) under that root. If it prints nothing, say there is no project memory here and offer `/memory-init`.
2. Run `ctxtree status`. If it says `stale <n>`, list those commits (`git log --oneline -<n>`) and say memory is behind.
3. Reply in at most 6 lines: what this is, where it stands, the task in flight and its next step, and whether memory is behind.
4. Read a topic file only if the user's next request needs it.
