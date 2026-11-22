---
name: memory-tree
description: The standard for project memory shared by every coding agent. A layered Markdown tree in ./memory/ loaded by need, never all at once. Applies in every project session without being invoked; load it when creating or restructuring memory, planning a multi step task, or when the user says "remember", "where were we", "catch me up", or runs /learn, /task, /memory-init or /catchup.
---

# Memory tree

One plain Markdown folder per project, `./memory/`, committed with the code by default, or kept on this machine only (`ctxtree init --private`, listed in `.git/info/exclude`). Every agent reads and writes the same files, so nothing depends on one tool's private memory. This tree is the only project store.

## The tree

```
memory/
  INDEX.md         layer 0  always loaded. Under 40 lines: what, where we are, next, map
  active-task.md   layer 0  only while a multi step task is in flight (planning with files)
  <topic>.md       layer 1  one per system, product or workstream: stable facts, decisions, why
  <topic>/         layer 1  a folder when one topic needs several files
  log.md           layer 2  dated journal, newest first, one or two lines per session
  archive/         layer 3  retired facts, never read unless asked
```

Global files live in `$CTXTREE_HOME` (default `~/.config/ctxtree`): `GLOBAL.md` (rules, every agent), `PROFILE.md` (the user), `registry.md` (every tree with trigger words), `notes/` (tool and machine notes). Project facts never go there.

## Lookup and loading

One rule for every agent: the nearest `memory/INDEX.md` from the working directory up to the git root (only the working directory outside git). Nothing else is searched. `ctxtree where` prints it.

- Claude Code: a SessionStart hook (`ctxtree context`) injects INDEX and `active-task.md` on startup, resume, clear and after compaction, plus a `<memory-stale>` warning when code moved since the last memory update. A Stop hook blocks once while memory is behind.
- OpenCode: its `instructions` list includes `memory/INDEX.md` and `memory/active-task.md`, resolved with the same rule.
- Agents without hooks (Codex, Antigravity, others): at session start run `/catchup` or follow "Session start" by hand.

## Session start

1. If a `<project-memory>` block is in context, INDEX and active-task are loaded; do not read them again. Otherwise read `memory/INDEX.md` and nothing else.
2. Say in one line where the project stands. If `active-task.md` exists, name the next phase and resume there.
3. If memory is stale, update it before or alongside the user's task.
4. Read only the topic file the task needs. Read `log.md` only for history questions.

## During work

- The moment a decision is made, a fact confirmed, an id created or an assumption corrected, write it to its topic file with its why. Sessions end abruptly.
- Correct in place; never append a contradicting line. One fact, one place; link instead of copying.
- Never store secret values. Write where the secret lives (`.env`, a secret manager), never the value. `ctxtree check` and the pre-commit guard block common secret formats.

## Planning with files (active-task.md)

For any task with more than about three phases or more than one sitting. Start it with `/task <goal>`.

```
# Active task: <name>
Goal: <one sentence, with the check that proves it is done>
Started: <date>

## Phases
- [x] 1. <phase>
- [ ] 2. <phase>  <- next: <exact next action>

## Findings
## Decisions
## Errors and failed attempts
- <attempt>: <why it failed>. Do not retry.
```

Rules while it exists:
- Read it again before any major decision; goals drift in long sessions.
- After every two searches, reads or browsing steps, write what you learned to Findings.
- Log every error and failed approach with its reason; never repeat a logged failure unchanged. After three failures on the same step, stop and ask the user.
- Update it the moment a phase finishes. One task at a time; a second task waits or gets its own worktree.
- When done: lasting findings and decisions go to topic files, one line to `log.md`, then delete the file.

## Session end or milestone

1. One dated line in `log.md`, newest first.
2. Update INDEX "Where we are" (dated) and "Next", 5 lines each at most.
3. Move anything stable from `log.md` into its topic file.
4. Run `ctxtree check`; fix errors.
5. Commit memory with the work (same commit or PR), unless the tree is private (listed in `.git/info/exclude`); then saving the files is enough.
6. Cross project preferences or lessons: propose them with `/promote`; never write global files silently.

`/learn` runs this step on demand.

## Staying in sync

Memory is behind when the repo has commits outside `memory/` newer than the last memory update (last commit touching `memory/`, or the newest memory file change). `ctxtree status` reports `fresh` or `stale <n>`. The SessionStart warning, the Stop hook and the git pre-commit guard all use this check. To clear it: update the topic file the commits belong to, the log and INDEX; if status did not change, refresh INDEX's date.

## Global write policy

`GLOBAL.md`, `PROFILE.md`, `registry.md` and `notes/` change only when:
- the user is explicit ("always", "from now on", "everywhere", "add to my rules"): write it, show the diff; or
- it is needed: a new tree gets a registry row (`ctxtree init` does it), or a cross project preference or lesson is proposed with `/promote` and the user confirms.

Never edit inside the `ctxtree` managed block of `GLOBAL.md`; the installer owns it.

## Creating a tree

`/memory-init`, or `ctxtree init <topic> ...` at the git root, then fill INDEX and topics from README, AGENTS.md, docs, git log and the session. Usually 2 to 6 topics. Verify that a fresh session with only INDEX and one topic file can start the next step without asking.

## Anti bloat

- INDEX is a map, not a summary. Over 40 lines means something belongs in a topic file.
- Never paste code, logs or test output into memory. Point at the file.
- Never duplicate README, AGENTS.md, docs or commits. Point at them. Stable decisions that have a `docs/DECISIONS.md` entry keep only a pointer in memory.
- Prefer "how to continue" over "what we did".
