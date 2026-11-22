# AGENTS.md

Project: ctxtree, an installable pack that gives several coding agents one shared memory system. Describe only this project here.

## Read first

- `memory/INDEX.md` if you have one (state and next; private to each developer, not in git), `README.md` (what and how), `docs/ARCHITECTURE.md` (parts), `docs/DECISIONS.md` (why).

## Installing for a user

If the user asks you to install or set up ctxtree on their machine, follow `INSTALL.md`.

## Commands

- Test: `bash tests/run.sh` (must pass before claiming a change is done; runs in a throwaway HOME)
- Live check: `bash tests/live-smoke.sh` (real agents, costs a few model calls)
- Try locally: `./install.sh --dry-run`, then `./install.sh --link`

## Conventions

- Bash plus git and jq only. Portable between GNU and BSD tools (see `mtime` and `fmt_date` in `bin/ctxtree`).
- Never put personal data, absolute home paths or real emails in the repo; `tests/run.sh` checks.
- The installer must stay idempotent, back up anything it replaces, record every change in the manifest, and undo it in `--uninstall`. Add a test for every new wiring step.
- Hooks never fail a session: `ctxtree context` always exits 0.
- Never displace the user's setup: existing rules are imported, their own same name items are kept, their repos' git hooks keep running. Test each case against a HOME that already has them.
- No emojis. No hyphens in prose.

## Branches, commits and pull requests

- Never commit to `main` directly. One branch per change, named `<type>/<short-slug>` (for example `feat/opencode-plugin`, `fix/windows-registry-path`, `docs/hero-gif`).
- Commit messages follow Conventional Commits: `<type>(<optional scope>): <summary>` in the imperative, under 72 characters, with a body that says why. Types: `feat`, `fix`, `docs`, `test`, `ci`, `refactor`, `perf`, `chore`. A breaking change adds `!` after the type and a `BREAKING CHANGE:` footer.
- Open a pull request into `main` with a title in the same format. CI (Linux, macOS, Windows, bash 3.2) must pass before merging. Squash merge, so `main` keeps one conventional commit per change.
- For parallel work use a git worktree per branch, and remove it after the merge.

## Memory

This repo keeps project memory private: each developer's `memory/` stays on their machine (`ctxtree init --private`). Stable decisions live in `docs/DECISIONS.md`, which is the shared record; memory keeps pointers. Starting files: `templates/memory/`.
