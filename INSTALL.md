# Install ctxtree (for agents)

The user asked you to install ctxtree. Run every command yourself; never use sudo; on any failure stop and show the output.

1. Use this checkout if `install.sh` is next to this file; otherwise clone the repo into `~/.local/share/ctxtree` and work there.
2. Check `bash`, `git` and `jq` exist (on Windows use Git Bash). If jq is missing, give the user the install command for their system.
3. Run `./install.sh --dry-run`, summarize it in plain words (agents wired, files backed up, settings changed), and ask once to proceed.
4. Run `./install.sh`. It backs up anything it replaces and `./install.sh --uninstall` undoes it all.
5. The installer copies the user's old rules into `GLOBAL.md` and keeps their own same name commands. Show what it copied and offer to trim parts that describe another memory system; edit only after a yes.
6. Run `~/.local/bin/ctxtree doctor`; every line must say OK. If `~/.local/bin` is not on PATH, offer the one line to add it.
7. Tell the user to restart their agent sessions, approve hooks in Codex `/hooks` if they use Codex, and run `/memory-init` in a project.
