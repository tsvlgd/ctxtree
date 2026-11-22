---
description: Write or refresh docs/ARCHITECTURE, DECISIONS, FLOWS and OPERATIONS with Mermaid diagrams, verified against the code
argument-hint: "[file names to limit the run, e.g. ARCHITECTURE FLOWS]"
---

Follow the `project-docs` skill. Scope: $ARGUMENTS (default: all four files).

1. Read the code before writing: entry points, routes, config, schema and migrations, infrastructure files, and package scripts. Read `memory/` for decisions and state.
2. Write or update only the docs in scope under `docs/`, starting from the skill's templates. Keep what is still true, correct what drifted, and mark anything you could not verify as "unverified".
3. Every diagram is valid Mermaid and names real components and files. Every command in OPERATIONS is one you found in the repo.
4. Decisions: move stable decisions from memory topic files into `docs/DECISIONS.md` and replace them in memory with a one line pointer, so each fact lives in one place.
5. Link the docs from `memory/INDEX.md` and README if they are not already.
6. Report what changed per file and anything marked unverified. Do not commit unless asked.
