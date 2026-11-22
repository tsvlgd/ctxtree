---
description: Start or update the in flight task plan in memory/active-task.md (planning with files)
argument-hint: "<task goal, or 'done' to close the current task>"
---

Working memory on disk for a multi step task, so a clear, compaction, crash or another agent resumes at the right step. Request: $ARGUMENTS

If no `memory/active-task.md` exists and a goal is given:
1. Restate the goal with the check that proves it is done.
2. Split it into 3 to 7 phases. Mark the first with `<- next:` and the exact next action.
3. Create `memory/active-task.md` from the template in the `memory-tree` skill (Goal, Phases, Findings, Decisions, Errors and failed attempts).

While the task runs (these rules apply until the file is deleted):
- Read `active-task.md` again before any major decision; goals drift in long sessions.
- After every two searches, reads or browsing steps, write what you learned to Findings before continuing.
- Log every error and failed approach under "Errors and failed attempts" with the reason. Never retry a logged failure unchanged.
- Tick a phase and move `<- next:` the moment a phase finishes. Never batch updates to the end.

If the request is `done`: move lasting findings and decisions to topic files, add one line to `memory/log.md`, update INDEX, then delete `active-task.md`.
