---
description: Propose moving a preference, lesson or rule from this session into the global files
argument-hint: "<what to make global>"
---

Global files are shared by every agent and every project. Change them only when the user is explicit or after the user confirms. Candidate: $ARGUMENTS

1. Classify it:
   - Preference about how the user works or wants things: `PROFILE.md`.
   - Rule or lesson for how every agent should behave in every project: the user section of `GLOBAL.md` (above the ctxtree managed block; never edit inside the block).
   - A project fact: it does not belong globally. Put it in the project tree instead and stop.
2. Read the target file. If it already says this, stop. If it contradicts it, show both and ask which wins.
3. Show the exact line(s) to add or change as a small diff, and ask once.
4. On yes: write it, run `ctxtree check --global`, and if the global folder is a git repo commit there with a one line reason.

The global folder is `$CTXTREE_HOME` (default `~/.config/ctxtree`).
