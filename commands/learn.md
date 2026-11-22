---
description: Capture this session into memory (project tree first; global files only per the write policy)
argument-hint: "[optional focus]"
---

Review this entire session (focus: $ARGUMENTS). Extract decisions, facts, corrections, preferences and lessons, then run the session end step of the `memory-tree` skill.

Project memory (the tree from `ctxtree where`):
1. Write each new fact or decision, with its why, into the topic file it belongs to. Correct in place; never append a contradicting line.
2. Add one dated line to `memory/log.md`, newest first.
3. Update INDEX "Where we are" (date it today) and "Next", 5 lines each at most, INDEX under 40 lines.
4. Move anything in `log.md` that became stable into its topic file. If `active-task.md` is finished, move its lasting findings and decisions to topic files and delete it.
5. Run `ctxtree check` and fix every error.
6. Commit the memory with the work if the user commits in this repo, unless memory is private (listed in `.git/info/exclude`).

Global candidates: list any preference or lesson from this session that applies beyond this project. Do not write them; offer `/promote` for each, unless the user already said it explicitly as a global rule ("always", "from now on", "everywhere").

No tree here: offer `/memory-init`. Never store secret values; name where they live.

End with a short summary of what changed and where.
