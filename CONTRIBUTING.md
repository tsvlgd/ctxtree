# Contributing

Thanks for helping. The short version:

1. Branch from `main` as `<type>/<short-slug>`: `feat/...`, `fix/...`, `docs/...`, `test/...`, `ci/...`, `refactor/...`, `chore/...`.
2. Commit with [Conventional Commits](https://www.conventionalcommits.org/): `fix(installer): keep user hooks on reinstall`.
3. Run `bash tests/run.sh` (it uses a throwaway HOME and never touches yours). Add a test for every behaviour you change.
4. Open a pull request with a conventional title. CI runs the suite on Linux, macOS, Windows and bash 3.2; it must pass.
5. Pull requests are squash merged, so `main` reads as one conventional commit per change.

Project conventions (portability, idempotent installer, never displacing a user's setup, no personal data) are in [AGENTS.md](AGENTS.md).
