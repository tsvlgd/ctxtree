# ctxtree memory

A reproducible pack that gives Claude Code, OpenCode, Codex and Antigravity one shared memory system: global rules with a managed protocol block, a user profile, a per project `memory/` tree, sync checks, guardrails, and shared slash commands. CLI: `ctxtree`. Installer: `install.sh`.

## Where we are (2026-11-22)

- Cross platform work in flight; see `active-task.md`.
- v0.1 built: CLI, installer (4 agents), commands, skills, git guard, Claude plugin, docs. `tests/run.sh` 135 passed; `tests/live-smoke.sh` 8 passed on real Claude Code and OpenCode.
- Agent install: user says "Install ctxtree by following INSTALL.md in <repo>"; the agent runs a dry run, asks once, installs, carries over old rules, runs doctor.
- Public on GitHub (tsvlgd/ctxtree), first commit pushed. npm name ctxtree still free (checked 2026-11-22). Not installed on the owner's machine.

## Next

1. Owner review, then first commit and a private remote.
2. Migration plan for an existing setup (map old rules and memory onto ctxtree), then install.
3. Open items in `decisions.md`.

## Map

- `active-task.md`: cross platform work in flight.

- `decisions.md`: open design questions. Stable decisions: `docs/DECISIONS.md`.
- `log.md`: dated journal.
