---
description: Create this project's memory tree (and AGENTS.md if missing) from what already exists
argument-hint: "[topic ...]"
---

Set up project memory here following the `memory-tree` skill.

1. Confirm this is a real project at its git root. Never create memory or AGENTS.md in the home directory or a workspace parent.
2. Gather what exists: README, AGENTS.md, CLAUDE.md, docs/, plan files, any old memory or notes files, `git log --oneline -30`, and this session.
3. Pick 2 to 6 topics: one per system, product or workstream (use these if given: $ARGUMENTS).
4. Run `ctxtree init <topic> ...` to create the skeleton and the registry row.
5. Fill INDEX (what this is, where we are, next, map) and each topic file from what you gathered. Point at repo docs instead of copying them. Fill the AGENTS.md placeholders from the repo (real commands only, verified by reading package files or running them).
6. Run `ctxtree check` and fix every error and warning.
7. Verify: from only INDEX and one topic file, could a fresh session start the next step without asking? If not, add what is missing.

Report the files created and the first "Next" item. Do not commit unless asked.
