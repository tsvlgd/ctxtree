#!/usr/bin/env bash
# Live smoke test against the real agents on this machine. Opt in: it spends a
# few model calls. It only writes project level config inside a throwaway repo;
# global agent config is never modified.
#   bash tests/live-smoke.sh            (needs claude and/or opencode logged in)
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export CTXTREE_HOME="$W/ctxtree"; mkdir -p "$CTXTREE_HOME" "$W/bin"
ln -s "$REPO/bin/ctxtree" "$W/bin/ctxtree"; export PATH="$W/bin:$PATH"
PASS=0; FAIL=0
check() { if printf '%s' "$2" | grep -Eqi "$3"; then PASS=$((PASS+1)); echo "  ok    $1"; else FAIL=$((FAIL+1)); echo "  FAIL  $1"; printf '%s\n' "$2" | tail -5 | sed 's/^/        /'; fi; }

P="$W/smoke"; mkdir -p "$P/src"; cd "$P"; git init -q -b main
ctxtree init --name smoke api >/dev/null
sed -i 's/^One paragraph.*/Codename: BLUE HERON. A throwaway project for the ctxtree smoke test./' memory/INDEX.md
old=$(( $(date +%s) - 86400 ))
git add -A && GIT_AUTHOR_DATE="@$old" GIT_COMMITTER_DATE="@$old" git -c core.hooksPath=/dev/null commit -qm "chore: memory"
find memory -type f -exec touch -d "@$old" {} +
echo x > src/app.txt && git add -A && git -c core.hooksPath=/dev/null commit -qm "feat: smoke change"
echo "status before agents: $(ctxtree status)"

if command -v claude >/dev/null 2>&1; then
  echo "claude"
  mkdir -p .claude/commands
  cp "$REPO/commands/catchup.md" .claude/commands/
  hooks() { jq -n --arg s "bash \"$REPO/bin/ctxtree\" context" --arg t "bash \"$REPO/bin/ctxtree\" context --stop" "$1" > .claude/settings.json; }
  hooks '{hooks: {SessionStart: [{hooks: [{type: "command", command: $s}]}]}}'
  out="$(timeout 180 claude -p "Answer from your context only, no tools, two short lines: 1) the codename in the project memory. 2) yes or no: is there a memory-stale warning that mentions the commit 'feat: smoke change'?" --model haiku --setting-sources project 2>&1)"
  check "SessionStart hook injects the tree" "$out" 'BLUE HERON'
  check "stale warning reaches the model" "$out" 'yes'
  out="$(timeout 240 claude -p "/catchup" --model haiku --setting-sources project --allowedTools 'Bash(ctxtree:*)' 'Bash(git log:*)' Read 2>&1)"
  check "/catchup command runs and reports" "$out" 'BLUE HERON|throwaway'
  check "/catchup reports memory behind" "$out" 'behind|stale'
  hooks '{hooks: {SessionStart: [{hooks: [{type: "command", command: $s}]}], Stop: [{hooks: [{type: "command", command: $t}]}]}}'
  out="$(timeout 240 claude -p "Reply with exactly: DONE" --model haiku --setting-sources project 2>&1)"
  check "Stop hook makes the agent address stale memory" "$out" 'memory|log\.md|INDEX'
  if claude plugin validate "$REPO" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "  ok    plugin manifest validates"; else
    v="$(claude plugin validate "$REPO" 2>&1)"; check "plugin manifest validates" "$v" 'valid|passed|success'; fi
fi

if command -v opencode >/dev/null 2>&1; then
  echo "opencode"
  mkdir -p .opencode/commands
  awk 'NR==1 && /^---$/ {fm=1; print; next} fm && /^---$/ {fm=0} fm && /^argument-hint:/ {next} {print}' "$REPO/commands/catchup.md" > .opencode/commands/catchup.md
  printf '{"instructions": ["memory/INDEX.md", "memory/active-task.md"]}\n' > opencode.json
  out="$(cd src && timeout 180 opencode run "Answer from your context only, no tools: what is the codename in the project memory? One line." 2>&1)"
  check "instructions find memory/INDEX.md from a subfolder (git root lookup)" "$out" 'BLUE HERON'
  out="$(timeout 240 opencode run "/catchup" 2>&1)"
  check "/catchup command runs and reports" "$out" 'BLUE HERON|throwaway|smoke'
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
