# Active task: cross platform (Linux, macOS, Windows) with end to end tests
Goal: `tests/run.sh` passes on ubuntu, macos and windows runners and under bash 3.2; installer works on Windows without admin rights.
Started: 2026-11-22

## Phases
- [x] 1. Rename to ctxtree (folder, CLI, config folder, plugin, docs)
- [x] 2. Runtime without jq or GNU only tools (hooks parse and emit JSON in bash)
- [x] 3. Portable tests; bash 3.2 plus busybox in Docker passes (101)
- [x] 4. Windows: native paths, managed copies with auto sync, bash hook form, Codex .cmd shim, LF via .gitattributes
- [ ] 5. CI matrix run on real runners (needs a private remote; owner approval)  <- next: ask the owner
- [x] 6. Docs: platform notes in README, OPERATIONS, DECISIONS D8

## Findings
- Name: ctxtree, chosen by the owner 2026-11-22 (free on npm, PyPI and crates.io; one tiny GitHub repo). The first name, agentmem, was taken on all three, including a Rust CLI with the same command.
- macOS ships bash 3.2; GNU flags to avoid: sed -i, stat -c, date -d, touch -d @, readlink -f, find -printf, md5sum, tac.

## Decisions
- See docs/DECISIONS.md D8.

## Errors and failed attempts
- Stop hook output from a stale tree replaced the answer in the live test; expected behaviour, fixed the test order, and the hook now blocks once per session per HEAD (D5).
- Same second commits hid staleness in tests (the check counts commits after the last memory update); fixtures use dated commits.
