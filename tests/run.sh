#!/usr/bin/env bash
# Test suite. Runs entirely in a throwaway HOME; never touches the real one.
#   bash tests/run.sh            all groups
#   KEEP=1 bash tests/run.sh     keep the sandbox for inspection
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
export HOME="$SANDBOX/home" GIT_CONFIG_GLOBAL="$SANDBOX/home/.gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset CTXTREE_HOME XDG_CONFIG_HOME CODEX_HOME
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME"; : > "$GIT_CONFIG_GLOBAL"
AH="$HOME/.config/ctxtree"; AM="$AH/pack/bin/ctxtree"
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }
# limited <cmd...>: run with stdin from /dev/null and a watchdog, so one hung
# command fails its test instead of stalling the run (TEST_TIMEOUT seconds, 60).
# TRACE=1 prints each test name before it runs, to locate a hang in CI logs.
TIMED_OUT=0
limited() {
  local pid w rc
  "$@" </dev/null >/dev/null 2>&1 &
  pid=$!
  ( sleep "${TEST_TIMEOUT:-60}"; kill -9 "$pid" 2>/dev/null && : > "$SANDBOX/.timeout" ) 2>/dev/null &
  w=$!
  wait "$pid"; rc=$?
  kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
  if [ -f "$SANDBOX/.timeout" ]; then rm -f "$SANDBOX/.timeout"; TIMED_OUT=1; return 124; fi
  return "$rc"
}
trace() { [ "${TRACE:-0}" = 1 ] && printf '  ..    %s\n' "$1"; return 0; }
t()    { local name="$1"; shift; trace "$name"; if limited "$@"; then ok "$name"; else bad "$name$([ "$TIMED_OUT" = 1 ] && echo ' (timed out)')"; TIMED_OUT=0; fi; }
tnot() { local name="$1"; shift; trace "$name"; if limited "$@"; then bad "$name"; else if [ "$TIMED_OUT" = 1 ]; then bad "$name (timed out)"; TIMED_OUT=0; else ok "$name"; fi; fi; }
group() { printf '\n%s\n' "$1"; }
# Portable helpers (GNU, BSD/macOS, busybox, Git Bash).
resolve() { local p="$1"; while [ -L "$p" ]; do local t; t="$(readlink "$p")"; case "$t" in /*) p="$t" ;; *) p="$(dirname "$p")/$t" ;; esac; done; printf '%s' "$p"; }
links_to() { [ -L "$1" ] && [ "$(cd "$(dirname "$(resolve "$1")")" && pwd -P)" = "$(cd "$(dirname "$2")" && pwd -P)" ]; }
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
sedi() { sed "$1" "$2" > "$2.sedi" && mv "$2.sedi" "$2"; }
sums() { cat "$@" | cksum; }
touch_at() { local e="$1"; shift; local d; d="$(date -d "@$e" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$e" +%Y%m%d%H%M.%S)"; touch -t "$d" "$@"; }
age_tree() { find "$2" -type f | while IFS= read -r f; do touch_at "$1" "$f"; done; }
count() { jq "$1" "$2"; }
cleanup() { [ "${KEEP:-0}" = 1 ] && echo "sandbox kept: $SANDBOX" || rm -rf "$SANDBOX"; }
trap cleanup EXIT

# A repo with a memory tree. mkrepo <dir>
mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q -b main && (
    cd "$1" && mkdir -p memory && printf '# T\n\n## Map\n\n- `topic.md`: t.\n' > memory/INDEX.md &&
    printf '# topic\n' > memory/topic.md && printf '# Log\n\n- 2026-01-02: b\n- 2026-01-01: a\n' > memory/log.md &&
    git -c core.hooksPath=/dev/null add -A &&
    GIT_AUTHOR_DATE="@$(( $(date +%s) - 172800 ))" GIT_COMMITTER_DATE="@$(( $(date +%s) - 172800 ))" git -c core.hooksPath=/dev/null commit -qm init )
}

# ------------------------------------------------------------------ fixtures
mkdir -p "$HOME/.claude" "$HOME/.config/opencode" "$HOME/.codex" "$HOME/.gemini"
echo "my old claude rules" > "$HOME/.claude/CLAUDE.md"
echo '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo mine"}]}]},"theme":"dark"}' > "$HOME/.claude/settings.json"
echo '{"instructions":["CONTRIBUTING.md"],"model":"x"}' > "$HOME/.config/opencode/opencode.json"
echo "my old gemini rules" > "$HOME/.gemini/GEMINI.md"
mkdir -p "$HOME/.claude/commands" "$HOME/.config/opencode/commands"
echo "my own task" > "$HOME/.claude/commands/task.md"
echo "my own promote" > "$HOME/.config/opencode/commands/promote.md"
snap() { (cd "$HOME" && find . \( -type f -o -type l \) | sort | while IFS= read -r f; do if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f $(cksum < "$f")"; fi; done | cksum); }

group "dry run changes nothing"
before="$(snap)"
bash "$REPO/install.sh" --dry-run > "$SANDBOX/dry.log" 2>&1
t "dry run exits 0" true
t "dry run leaves HOME untouched" test "$before" = "$(snap)"
t "dry run lists what it would do" grep -q '^would: ' "$SANDBOX/dry.log"

group "install (all four agents detected)"
bash "$REPO/install.sh" > "$SANDBOX/install.log" 2>&1; rc=$?
t "installer exits 0" test "$rc" = 0
for p in .claude/CLAUDE.md .config/opencode/AGENTS.md .codex/AGENTS.md .gemini/GEMINI.md; do
  t "$p links GLOBAL.md" links_to "$HOME/$p" "$AH/GLOBAL.md"
done
t "foreign CLAUDE.md backed up intact" sh -c "grep -rqx 'my old claude rules' '$AH/backups'"
t "foreign GEMINI.md backed up intact" sh -c "grep -rqx 'my old gemini rules' '$AH/backups'"
t "old CLAUDE.md rules still load (imported into GLOBAL.md)" grep -qx 'my old claude rules' "$AH/GLOBAL.md"
t "old GEMINI.md rules imported too" grep -qx 'my old gemini rules' "$AH/GLOBAL.md"
t "imported rules sit above the managed block" sh -c "awk '/my old claude rules/ {r=NR} /ctxtree:begin/ {b=NR} END {exit !(r && b && r < b)}' '$AH/GLOBAL.md'"
t "your own /task command kept, not replaced" sh -c "test ! -L '$HOME/.claude/commands/task.md' && grep -qx 'my own task' '$HOME/.claude/commands/task.md'"
t "your own opencode /promote kept" grep -qx 'my own promote' "$HOME/.config/opencode/commands/promote.md"
t "install log names what it kept" grep -q 'kept your own .*task.md' "$SANDBOX/install.log"
t "dry run says it would keep your own items" grep -q 'would keep your own' "$SANDBOX/dry.log"
t "GLOBAL.md managed block rendered" sh -c "grep -q 'ctxtree:begin' '$AH/GLOBAL.md' && grep -q '$(native "$AH")/PROFILE.md' '$AH/GLOBAL.md' && ! grep -q '{{' '$AH/GLOBAL.md'"
S="$HOME/.claude/settings.json"
t "claude: existing hook kept" test "$(count '[.hooks.SessionStart[].hooks[].command] | map(select(. == "echo mine")) | length' "$S")" = 1
t "claude: one ctxtree SessionStart hook" test "$(count '[.hooks.SessionStart[].hooks[].command] | map(select(test("ctxtree"))) | length' "$S")" = 1
t "claude: one ctxtree Stop hook" test "$(count '[.hooks.Stop[].hooks[].command] | map(select(test("ctxtree.*--stop"))) | length' "$S")" = 1
t "claude: other settings kept" test "$(jq -r .theme "$S")" = dark
t "claude: auto memory off" test "$(jq -r .autoMemoryEnabled "$S")" = false
for c in learn memory-init task catchup promote project-docs; do t "claude: /$c" test -e "$HOME/.claude/commands/$c.md"; done
t "claude: skills" test -f "$HOME/.claude/skills/memory-tree/SKILL.md"
O="$HOME/.config/opencode/opencode.json"
t "opencode: existing instruction kept" test "$(jq -r '.instructions[0]' "$O")" = CONTRIBUTING.md
t "opencode: memory and profile instructions" test "$(jq '[.instructions[] | select(. == "memory/INDEX.md" or . == "memory/active-task.md" or endswith("ctxtree/PROFILE.md"))] | length' "$O")" = 3
t "opencode: commands without argument-hint" sh -c "test -f '$HOME/.config/opencode/commands/learn.md' && ! grep -q argument-hint '$HOME/.config/opencode/commands/learn.md'"
t "codex + opencode: skills in ~/.agents/skills" test -f "$HOME/.agents/skills/project-docs/SKILL.md"
t "codex: prompts" test -e "$HOME/.codex/prompts/catchup.md"
t "codex: hooks.json start hook prints profile" sh -c "jq -e '[.hooks.SessionStart[].hooks[].command] | any(test(\"context --profile\$\"))' '$HOME/.codex/hooks.json'"
t "antigravity: skills" test -f "$HOME/.gemini/config/skills/memory-tree/SKILL.md"
t "antigravity: workflows without argument-hint" sh -c "test -f '$HOME/.gemini/config/global_workflows/task.md' && ! grep -q argument-hint '$HOME/.gemini/config/global_workflows/task.md'"
t "ctxtree on PATH" command -v ctxtree
t "global folder is a git repo" test -d "$AH/.git"
t "git guard set as core.hooksPath" test "$(git config --global core.hooksPath)" = "$(native "$AH/pack/git-hooks")"
t "hook commands run through bash with a quoted path" sh -c "jq -e '[.hooks.SessionStart[].hooks[].command] | any(startswith(\"bash \\\"\"))' '$S'"
if [ -f "$AH/pack/bin/ctxtree.cmd" ]; then
  t "windows: ctxtree.cmd shim runs through Git Bash" sh -c "cmd //c \"\$(cygpath -w '$AH/pack/bin/ctxtree.cmd')\" version | grep -q 'ctxtree '"
fi
t "doctor passes" "$AM" doctor

group "reinstall is idempotent and keeps your edits"
echo "- my own rule" >> "$AH/PROFILE.md"
sedi 's/^- <how agents should work with you.*/- always write tests first/' "$AH/GLOBAL.md"
sedi 's/^- Lookup: .*/- tampered/' "$AH/GLOBAL.md"
sum_before="$(sums "$S" "$O" "$HOME/.codex/hooks.json")"
manifest_lines="$(sort -u "$AH/manifest" | wc -l)"
bash "$REPO/install.sh" > "$SANDBOX/install2.log" 2>&1
t "reinstall exits 0" true
t "settings unchanged on reinstall" test "$sum_before" = "$(sums "$S" "$O" "$HOME/.codex/hooks.json")"
t "still one ctxtree SessionStart hook" test "$(count '[.hooks.SessionStart[].hooks[].command] | map(select(test("ctxtree"))) | length' "$S")" = 1
t "manifest has no duplicate lines" test "$(wc -l < "$AH/manifest")" = "$manifest_lines"
t "profile edit kept" grep -qx -- "- my own rule" "$AH/PROFILE.md"
t "user section edit kept" grep -qx -- "- always write tests first" "$AH/GLOBAL.md"
t "managed block restored" sh -c "! grep -q tampered '$AH/GLOBAL.md' && grep -q '^- Lookup: ' '$AH/GLOBAL.md'"
t "rules imported once across reinstalls" test "$(grep -cx 'my old claude rules' "$AH/GLOBAL.md")" = 1
dupes="$(grep -rlx 'my old claude rules' "$AH/backups")"
t "foreign files not backed up twice" test "$(printf '%s\n' "$dupes" | grep -c .)" = 1
[ "$(printf '%s\n' "$dupes" | grep -c .)" = 1 ] || { echo "        matching backups:"; printf '%s\n' "$dupes" | sed "s|$AH|        ~ctxtree|"; ls -laR "$AH/backups" | sed 's/^/        /' | head -40; }

group "lookup rule"
mkrepo "$SANDBOX/w/app"
mkdir -p "$SANDBOX/w/app/src/deep" "$SANDBOX/w/app/vendor/lib" "$SANDBOX/w/plain/memory" "$SANDBOX/w/plain/sub" "$SANDBOX/w/empty"
git -C "$SANDBOX/w/app/vendor/lib" init -q
echo "# P" > "$SANDBOX/w/plain/memory/INDEX.md"
t "repo root finds its tree" test "$("$AM" where "$SANDBOX/w/app")" = "$(cd "$SANDBOX/w/app" && pwd -P)"
t "subfolder finds the repo tree" test "$("$AM" where "$SANDBOX/w/app/src/deep")" = "$(cd "$SANDBOX/w/app" && pwd -P)"
t "nested repo does not see the parent tree" test -z "$("$AM" where "$SANDBOX/w/app/vendor/lib")"
t "non git folder with a tree finds it" test -n "$("$AM" where "$SANDBOX/w/plain")"
t "non git subfolder does not walk up" test -z "$("$AM" where "$SANDBOX/w/plain/sub")"
t "folder without a tree finds nothing" test "$(cd "$SANDBOX/w/empty" && "$AM" status)" = none

group "sync: staleness, session start, stop hook"
R="$SANDBOX/w/app"
old=$(( $(date +%s) - 86400 ))
age_tree "$old" "$R/memory"
t "fresh right after memory commit" test "$(cd "$R" && "$AM" status)" = fresh
echo x > "$R/code.txt"; git -C "$R" add code.txt; git -C "$R" -c core.hooksPath=/dev/null commit -qm "feat: add code"
t "code commit makes memory stale" test "$(cd "$R" && "$AM" status)" = "stale 1"
out="$(printf '{"cwd":"%s","source":"startup"}' "$R" | "$AM" context)"
t "session start shows memory-stale with the commit" sh -c "printf '%s' \"\$1\" | grep -q '<memory-stale>' && printf '%s' \"\$1\" | grep -q 'feat: add code'" _ "$out"
t "session start injects INDEX" sh -c "printf '%s' \"\$1\" | grep -q '<file path=.*INDEX.md'" _ "$out"
stop="$(printf '{"cwd":"%s","stop_hook_active":false}' "$R" | "$AM" context --stop)"
t "stop hook blocks once while stale" sh -c "printf '%s' \"\$1\" | jq -e '.decision == \"block\" and (.reason | test(\"behind\"))'" _ "$stop"
export CTXTREE_STATE_DIR="$SANDBOX/state"
first="$(printf '{"cwd":"%s","session_id":"s1"}' "$R" | "$AM" context --stop)"
again="$(printf '{"cwd":"%s","session_id":"s1"}' "$R" | "$AM" context --stop)"
t "stop blocks once per session per code state" sh -c "test -n \"\$1\" && test -z \"\$2\"" _ "$first" "$again"
t "another session is blocked again" test -n "$(printf '{"cwd":"%s","session_id":"s2"}' "$R" | "$AM" context --stop)"
echo y > "$R/code2.txt"; git -C "$R" add code2.txt; git -C "$R" -c core.hooksPath=/dev/null commit -qm "feat: more code"
t "new commits re-arm the stop block" test -n "$(printf '{"cwd":"%s","session_id":"s1"}' "$R" | "$AM" context --stop)"
t "stop hook never loops (stop_hook_active)" test -z "$(printf '{"cwd":"%s","stop_hook_active":true}' "$R" | "$AM" context --stop)"
echo "- note" >> "$R/memory/topic.md"
t "editing memory clears staleness" test "$(cd "$R" && "$AM" status)" = fresh
t "stop hook silent when fresh" test -z "$(printf '{"cwd":"%s"}' "$R" | "$AM" context --stop)"
echo "# P" > "$AH/PROFILE.md.test" && cp "$AH/PROFILE.md" "$SANDBOX/profile.bak"
t "context --profile prints the profile" sh -c "printf '{\"cwd\":\"%s\"}' '$R' | '$AM' context --profile | grep -q '<user-profile'"
printf '# Active task: x\n' > "$R/memory/active-task.md"; touch_at "$(( $(date +%s) - 20 * 86400 ))" "$R/memory/active-task.md"
t "old active task gets a task-stale note" sh -c "printf '{\"cwd\":\"%s\"}' '$R' | '$AM' context | grep -q '<task-stale>'"
rm -f "$R/memory/active-task.md" "$AH/PROFILE.md.test"
t "hook input with a Windows style cwd and escapes parses" sh -c "printf '{\"session_id\":\"a\\\\b\",\"cwd\":\"%s\",\"source\":\"resume\"}' '$R' | '$AM' context | grep -q 'trigger=\"resume\"'"
git -C "$R" -c core.hooksPath=/dev/null commit -q --allow-empty -m "fix: quote \" backslash \\ tab	end" 2>/dev/null
echo z > "$R/z.txt"; git -C "$R" add z.txt; git -C "$R" -c core.hooksPath=/dev/null commit -qm 'feat: "quoted" \path\ and	tab'
age_tree "$old" "$R/memory"
stopjson="$(printf '{"cwd":"%s","session_id":"esc"}' "$R" | "$AM" context --stop)"
t "stop JSON stays valid with quotes, backslashes and tabs" sh -c "printf '%s' \"\$1\" | jq -e '.decision == \"block\" and (.reason | test(\"quoted\"))'" _ "$stopjson"
t "no tree: context prints nothing" test -z "$(printf '{"cwd":"%s"}' "$SANDBOX/w/empty" | "$AM" context)"

group "init guardrails"
tnot "init refuses the home directory" sh -c "cd '$HOME' && '$AM' init"
mkdir -p "$SANDBOX/w/proj/sub"; git -C "$SANDBOX/w/proj" init -q
tnot "init refuses below the git root" sh -c "cd '$SANDBOX/w/proj/sub' && '$AM' init"
t "init creates the tree at the git root" sh -c "cd '$SANDBOX/w/proj' && '$AM' init api 'web app'"
t "init made INDEX, log, topics, AGENTS.md" sh -c "cd '$SANDBOX/w/proj' && test -f memory/INDEX.md -a -f memory/log.md -a -f memory/api.md -a -f memory/web-app.md -a -f AGENTS.md"
t "init rendered placeholders" sh -c "! grep -rq '{{' '$SANDBOX/w/proj/memory' '$SANDBOX/w/proj/AGENTS.md'"
t "init added a registry row (native path)" grep -qF "| $(native "$(cd "$SANDBOX/w/proj" && pwd -P)")/memory/INDEX.md |" "$AH/registry.md"
t "init refuses to overwrite a tree" sh -c "cd '$SANDBOX/w/proj' && ! '$AM' init 2>'$SANDBOX/init.err' && grep -q 'already exists' '$SANDBOX/init.err'"
t "init accepts the git root on every platform" sh -c "cd '$SANDBOX/w/proj' && test \"\$('$AM' where)\" = \"\$(pwd -P)\""
t "fresh tree passes check" sh -c "cd '$SANDBOX/w/proj' && '$AM' check"

group "check guardrails"
C="$SANDBOX/w/proj/memory"
echo 'api_key = "sk-live-0123456789abcdefghijABCDEF"' >> "$C/api.md"
tnot "secret value in a topic fails check" sh -c "cd '$SANDBOX/w/proj' && '$AM' check"
sedi '$d' "$C/api.md"
echo 'The token lives in .env as API_TOKEN.' >> "$C/api.md"
t "naming where a secret lives passes" sh -c "cd '$SANDBOX/w/proj' && '$AM' check"
for i in $(seq 1 45); do echo "- line $i" >> "$C/INDEX.md"; done
t "oversized INDEX warns" sh -c "cd '$SANDBOX/w/proj' && '$AM' check | grep -q 'WARN  memory/INDEX.md'"
echo '- `missing.md`: gone.' >> "$C/INDEX.md"
t "broken INDEX reference warns" sh -c "cd '$SANDBOX/w/proj' && '$AM' check | grep -q 'missing.md'"
printf '# Log\n\n- 2026-01-01: a\n- 2026-02-01: b\n' > "$C/log.md"
t "log out of order warns" sh -c "cd '$SANDBOX/w/proj' && '$AM' check | grep -q 'newest first'"
cp "$AH/PROFILE.md" "$SANDBOX/p.bak"; echo 'password: hunter2hunter2hunter2hunter2' >> "$AH/PROFILE.md"
tnot "secret in PROFILE fails check --global" "$AM" check --global
cp "$SANDBOX/p.bak" "$AH/PROFILE.md"
t "clean global files pass check --global" "$AM" check --global

group "git pre-commit guard (installed globally)"
G="$SANDBOX/w/guard"; mkrepo "$G"
printf '#!/bin/sh\ntouch "%s/local-hook-ran"\n' "$SANDBOX" > "$G/.git/hooks/pre-commit"; chmod +x "$G/.git/hooks/pre-commit"
echo 'secret: AKIAABCDEFGHIJKLMNOP' >> "$G/memory/topic.md"; git -C "$G" add -A
tnot "commit with a secret in memory is blocked" git -C "$G" commit -qm "docs: leak"
git -C "$G" checkout -q -- . 2>/dev/null; git -C "$G" reset -q --hard
echo "- safe fact" >> "$G/memory/topic.md"; git -C "$G" add -A
t "clean memory commit passes" env GIT_COMMITTER_DATE="@$old" GIT_AUTHOR_DATE="@$old" git -C "$G" commit -qm "docs: memory"
t "repo's own pre-commit hook still runs" test -f "$SANDBOX/local-hook-ran"
printf '#!/bin/sh\necho "$1" > "%s/commit-msg-ran"\n' "$SANDBOX" > "$G/.git/hooks/commit-msg"
printf '#!/bin/sh\ncat > "%s/pre-push-stdin"; exit 1\n' "$SANDBOX" > "$G/.git/hooks/pre-push"
chmod +x "$G/.git/hooks/commit-msg" "$G/.git/hooks/pre-push"
echo m > "$G/m.txt"; git -C "$G" add m.txt; GIT_COMMITTER_DATE="@$old" GIT_AUTHOR_DATE="@$old" git -C "$G" commit -qm "chore: m" 2>/dev/null
t "repo's own commit-msg hook still runs, with its argument" grep -q 'COMMIT_EDITMSG' "$SANDBOX/commit-msg-ran"
git init -q --bare "$SANDBOX/w/remote.git"
tnot "repo's own pre-push hook still runs and can block a push" git -C "$G" push -q "$SANDBOX/w/remote.git" HEAD:main
t "pre-push hook receives git's stdin" grep -q 'refs/heads/main' "$SANDBOX/pre-push-stdin"
rm -f "$G/.git/hooks/pre-push"
t "push works when the repo has no pre-push hook" git -C "$G" push -q "$SANDBOX/w/remote.git" HEAD:main
t "a hook name the repo lacks is a no op" sh -c "cd '$G' && '$AH/pack/git-hooks/post-checkout' a b 1"
age_tree "$old" "$G/memory"
echo a > "$G/a.txt"; git -C "$G" add a.txt; git -C "$G" commit -qm "feat: a" 2>/dev/null
echo b > "$G/b.txt"; git -C "$G" add b.txt
t "code commit while memory is behind warns" sh -c "git -C '$G' commit -qm 'feat: b' 2>&1 | grep -q 'behind the code'"

group "uninstall restores everything"
bash "$REPO/install.sh" --uninstall > "$SANDBOX/uninstall.log" 2>&1
t "uninstall exits 0" true
t "original CLAUDE.md restored" sh -c "test ! -L '$HOME/.claude/CLAUDE.md' && grep -qx 'my old claude rules' '$HOME/.claude/CLAUDE.md'"
t "original GEMINI.md restored" grep -qx 'my old gemini rules' "$HOME/.gemini/GEMINI.md"
t "ctxtree hooks removed, yours kept" test "$(jq -c '[.hooks.SessionStart[].hooks[].command]' "$S")" = '["echo mine"]'
t "Stop event removed when empty" test "$(jq '.hooks | has("Stop")' "$S")" = false
t "opencode instructions back to original" test "$(jq -c .instructions "$O")" = '["CONTRIBUTING.md"]'
t "commands and skills removed" sh -c "test ! -e '$HOME/.claude/commands/learn.md' -a ! -e '$HOME/.agents/skills/memory-tree' -a ! -e '$HOME/.config/opencode/commands/learn.md'"
t "pack and CLI removed" sh -c "test ! -e '$AH/pack' -a ! -e '$HOME/.local/bin/ctxtree'"
t "git hooksPath unset" sh -c "! git config --global core.hooksPath"
t "your own commands survive uninstall" sh -c "grep -qx 'my own task' '$HOME/.claude/commands/task.md' && grep -qx 'my own promote' '$HOME/.config/opencode/commands/promote.md'"
t "config files ctxtree created are removed when empty" test ! -e "$HOME/.codex/hooks.json"
t "your GLOBAL.md and PROFILE.md kept" sh -c "test -f '$AH/GLOBAL.md' -a -f '$AH/PROFILE.md'"
bash "$REPO/install.sh" --agents claude > /dev/null 2>&1 && bash "$REPO/install.sh" --uninstall --purge > /dev/null 2>&1
t "--purge removes the global folder" test ! -e "$AH"

group "no symlinks (Windows without Developer Mode)"
(
  export HOME="$SANDBOX/home2" GIT_CONFIG_GLOBAL="$SANDBOX/home2/.gitconfig" CTXTREE_NO_SYMLINKS=1
  mkdir -p "$HOME/.claude" "$HOME/.config/opencode" "$HOME/.codex" "$HOME/.gemini"; : > "$GIT_CONFIG_GLOBAL"
  echo "old rules" > "$HOME/.claude/CLAUDE.md"
  A2="$HOME/.config/ctxtree"; M2="$A2/pack/bin/ctxtree"
  bash "$REPO/install.sh" > "$SANDBOX/install-nolinks.log" 2>&1
  t "install without symlinks exits 0" grep -q 'Done' "$SANDBOX/install-nolinks.log"
  t "CLAUDE.md is a managed copy, not a link" sh -c "test ! -L '$HOME/.claude/CLAUDE.md' && grep -q 'ctxtree:managed' '$HOME/.claude/CLAUDE.md'"
  t "all four rules files are managed copies" test "$(grep -l 'ctxtree:managed' "$HOME/.claude/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md" "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md" | wc -l | tr -d ' ')" = 4
  t "skills are real folders" sh -c "test -d '$HOME/.claude/skills/memory-tree' -a ! -L '$HOME/.claude/skills/memory-tree' -a -f '$HOME/.claude/skills/memory-tree/SKILL.md'"
  echo "- rule added later" >> "$A2/GLOBAL.md"
  t "copies are stale right after an edit (before any session)" sh -c "! grep -q 'rule added later' '$HOME/.codex/AGENTS.md'"
  printf '{"cwd":"%s"}' "$HOME" | "$M2" context >/dev/null
  t "a session start refreshes every copy" test "$(grep -l 'rule added later' "$HOME/.claude/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md" "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md" | wc -l | tr -d ' ')" = 4
  echo "- second edit" >> "$A2/GLOBAL.md"
  t "ctxtree sync refreshes on demand" sh -c "'$M2' sync | grep -q synced && grep -q 'second edit' '$HOME/.claude/CLAUDE.md'"
  t "doctor passes with copies" "$M2" doctor
  bash "$REPO/install.sh" > /dev/null 2>&1
  t "reinstall keeps one copy entry per file" test "$(sort "$A2/copies" | uniq -d | wc -l | tr -d ' ')" = 0
  t "reinstall does not back up its own copies" test "$(grep -rl 'ctxtree:managed' "$A2/backups" 2>/dev/null | wc -l | tr -d ' ')" = 0
  bash "$REPO/install.sh" --uninstall > /dev/null 2>&1
  t "uninstall restores the original CLAUDE.md" grep -qx 'old rules' "$HOME/.claude/CLAUDE.md"
  t "uninstall removes copies and copied skills" sh -c "test ! -e '$HOME/.codex/AGENTS.md' -a ! -e '$HOME/.claude/skills/memory-tree'"
  echo "$PASS $FAIL" > "$SANDBOX/sub.counts"
)
read sub_pass sub_fail < "$SANDBOX/sub.counts"; PASS=$sub_pass; FAIL=$sub_fail

group "repo hygiene"
cd "$REPO"
files="$(git ls-files --others --cached --exclude-standard | grep -v '^tests/')"
home_re='/(home|Users)/[a-z]'
t "no absolute home paths in the repo" sh -c "! printf '%s\n' \"\$1\" | xargs grep -lE '$home_re'" _ "$files"
t "no email addresses except example.com" sh -c "! printf '%s\n' \"\$1\" | xargs grep -ohE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' | grep -v 'example\.com\$'" _ "$files"
t "plugin manifests are valid JSON" jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json
t "scripts parse" sh -c "bash -n bin/ctxtree && bash -n install.sh && for f in git-hooks/*; do sh -n \"\$f\" || exit 1; done"
t "every git hook file is executable" sh -c "! find git-hooks -type f ! -perm -u+x | grep -q ."
t "scripts are checked out with LF endings" sh -c "! grep -l \"\$(printf '\r')\" bin/ctxtree install.sh git-hooks/pre-commit tests/run.sh"
t ".gitattributes forces LF for scripts" grep -q 'eol=lf' .gitattributes
t "every command has a description" sh -c "for f in commands/*.md; do sed -n 2p \"\$f\" | grep -q '^description: ' || exit 1; done"
t "every skill has name and description" sh -c "for f in skills/*/SKILL.md; do grep -q '^name: ' \"\$f\" && grep -q '^description: ' \"\$f\" || exit 1; done"
t "README and AGENTS.md point agents at INSTALL.md" sh -c "grep -q 'INSTALL.md' README.md && grep -q 'INSTALL.md' AGENTS.md"
t "INSTALL.md uses only flags install.sh accepts" sh -c "for f in \$(grep -oE 'install\.sh( --[a-z-]+)+' INSTALL.md | grep -oE -- '--[a-z-]+' | sort -u); do grep -qE -- \"^ +\$f\)\" install.sh || exit 1; done"
t "INSTALL.md steps stay short (two lines each at most)" sh -c "awk '/^[0-9]+\. / && length > 320 {exit 1}' INSTALL.md"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
