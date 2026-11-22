## Memory and sync (ctxtree {{VERSION}})

One home per kind of fact, one loader per home, one save standard (the `memory-tree` skill). No other memory store: no tool private memory, no memory MCP server.

| What | Home | Loaded |
| --- | --- | --- |
| How agents behave | this file | automatically, every agent |
| Who the user is | `{{CTXTREE_HOME}}/PROFILE.md` | automatically where supported, else read it at session start |
| Project facts, decisions, state | `<repo>/memory/` | INDEX and active-task automatically where supported; topics on demand |
| Which project lives where | `{{CTXTREE_HOME}}/registry.md` | on demand |
| Human docs | `<repo>/docs/` (`project-docs` skill) | on demand |

User profile: @{{CTXTREE_HOME}}/PROFILE.md
If the profile above is not already in your context, read that file before your first reply.

- Lookup: the nearest `memory/INDEX.md` from the working directory up to the git root. Nothing else. `ctxtree where` prints it.
- Session start: if a `<project-memory>` block is in context, INDEX and active-task are loaded; otherwise read `memory/INDEX.md` first (or run `/catchup`). Say in one line where the project stands. Read only the topic file the task needs.
- Capture: the moment a decision, fact, id or correction becomes true, write it to its topic file with its why. Correct in place. Never store secret values, only where they live.
- Plan in files: a task with more than about three phases keeps Goal, Phases, Findings, Decisions and Errors in `memory/active-task.md` (`/task`). Read it again before major decisions, save findings after every two searches or reads, log every failure, delete it when done.
- Sync: when `<memory-stale>` appears or `ctxtree status` says stale, update the topic file, `log.md` and INDEX before or alongside the task.
- Session end or milestone: `/learn` (one log line, INDEX "where we are" and "next", `ctxtree check`, commit memory with the work unless it is private).
- Global write policy: `GLOBAL.md`, `PROFILE.md`, `registry.md` and `notes/` change only when the user is explicit ("always", "from now on", "everywhere") or after the user confirms a proposal (`/promote`). Never write them silently, never put project facts there, never edit inside this managed block.
- Guardrails: never create memory or AGENTS.md above a project root. `ctxtree check` and the git pre-commit guard block secrets in memory files; fix, never bypass.
- Commands: `/catchup`, `/task`, `/learn`, `/promote`, `/memory-init`, `/project-docs`.
