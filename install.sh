#!/usr/bin/env bash
# ctxtree installer.
#
#   ./install.sh [options]
#
# Options:
#   --agents LIST        comma list of claude,opencode,codex,antigravity
#                        (default: every agent whose config folder exists)
#   --link               symlink the pack to this checkout instead of copying
#                        (for developing the pack; updates apply instantly)
#   --keep-auto-memory   leave Claude Code auto memory on (default: off)
#   --claude-plugin      Claude Code gets commands, skills and hooks from the
#                        plugin (/plugin marketplace add <this repo>); the
#                        installer then only links CLAUDE.md and sets auto memory
#   --no-git-hook        do not set up the global git pre-commit guard
#   --no-git             do not git init the global folder
#   --dry-run            print every action, change nothing
#   --verbose            print every action while installing (default: a short
#                        summary; the full list goes to $CTXTREE_HOME/install.log)
#   --uninstall          undo everything recorded in the manifest
#   --purge              with --uninstall, also delete the global folder
#   -h, --help
#
# Environment: CTXTREE_HOME (default ~/.config/ctxtree), HOME, CTXTREE_NO_SYMLINKS=1
# (force managed copies instead of symlinks, as on Windows without Developer Mode).
# Works on Linux, macOS (bash 3.2) and Windows (Git Bash). Needs bash, git, jq.
# Every file it replaces is backed up under $CTXTREE_HOME/backups/<time>/
# and every change is recorded in $CTXTREE_HOME/manifest for --uninstall.
# Running it again is safe: it converges to the same state.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTXTREE_HOME="${CTXTREE_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/ctxtree}"
PACK="$CTXTREE_HOME/pack"
MANIFEST="$CTXTREE_HOME/manifest"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CTXTREE_HOME/backups/$STAMP"
BIN_DIR="$HOME/.local/bin"
COMMANDS="learn memory-init task catchup promote project-docs"
SKILLS="memory-tree project-docs"
VERSION="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$REPO/bin/ctxtree")"

agents=""; link=0; keep_auto=0; claude_plugin=0; git_hook=1; git_init=1; dry=0; uninstall=0; purge=0; verbose=0
while [ $# -gt 0 ]; do
  case "$1" in
    --agents) agents="${2//,/ }"; shift 2 ;;
    --link) link=1; shift ;;
    --keep-auto-memory) keep_auto=1; shift ;;
    --claude-plugin) claude_plugin=1; shift ;;
    --no-git-hook) git_hook=0; shift ;;
    --no-git) git_init=0; shift ;;
    --dry-run) dry=1; shift ;;
    --verbose) verbose=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --purge) purge=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

# Output. A real install prints a short summary and writes every action to $LOG;
# --dry-run, --verbose and --uninstall print every action as they happen.
quiet=0
if [ "$dry" = 0 ] && [ "$uninstall" = 0 ] && [ "$verbose" = 0 ]; then quiet=1; fi
LOG="$CTXTREE_HOME/install.log"
say() { if [ "$quiet" = 1 ]; then printf '%s\n' "$*" >> "$LOG"; else printf '%s\n' "$*"; fi; }
out() { printf '%s\n' "$*"; }
tilde() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }
KEPT=""; IMPORTED=""; NOTES=""; WIRED=""
# note <text>: a line the user must see; printed now, or kept for the summary.
note() { say "$*"; NOTES="$NOTES$*
"; return 0; }
# wired <agent label> <what>: one summary row per agent.
wired() { WIRED="$WIRED$(printf '  %-13s %s' "$1" "$2")
"; return 0; }
win=0; case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) win=1 ;; esac
# native <path>: the form other programs expect (C:/x on Windows, unchanged elsewhere).
native() { if [ "$win" = 1 ] && command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# Native symlinks on Windows need Developer Mode; without it ln fails instead of copying.
[ "$win" = 1 ] && export MSYS=winsymlinks:nativestrict CYGWIN=winsymlinks:nativestrict
COPIES="$CTXTREE_HOME/copies"
run() { if [ "$dry" = 1 ]; then say "would: $*"; else "$@"; fi; }
record() { [ "$dry" = 1 ] || printf '%s\n' "$*" >> "$MANIFEST"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }

# backup_if_foreign <path>: move a file we do not own into the backup folder.
backup_if_foreign() {
  local p="$1" rel
  [ -e "$p" ] || [ -L "$p" ] || return 0
  rel="${p#"$HOME"/}"
  run mkdir -p "$BACKUP/$(dirname "$rel")"
  run mv "$p" "$BACKUP/$rel"
  record "backup $p $BACKUP/$rel"
  last_backup="$BACKUP/$rel"
  say "backed up $p"
}
last_backup=""

# is_ours <path>: true when what sits at path was placed by this installer.
is_ours() {
  if [ -L "$1" ]; then
    case "$(readlink "$1")" in "$PACK"|"$PACK"/*|"$REPO"/*|"$CTXTREE_HOME"/*) return 0 ;; esac
  fi
  grep -qxF "copy $1" "$MANIFEST" 2>/dev/null || grep -qxF "file $1" "$MANIFEST" 2>/dev/null
}

# keep_foreign <path>: the user's own command, skill or prompt with one of our names
# stays in place (never shadowed); true when it does.
keep_foreign() {
  { [ -e "$1" ] || [ -L "$1" ]; } || return 1
  is_ours "$1" && return 1
  say "$([ "$dry" = 1 ] && echo 'would keep' || echo 'kept') your own $1 (ctxtree's version stays in the pack)"
  KEPT="$KEPT $(tilde "$1")"
  return 0
}

# import_rules <shown path> <content>: rules the user had before ctxtree go into the
# user section of GLOBAL.md, above the managed block, once per distinct content,
# so they keep loading after the agent's rules file becomes a link to GLOBAL.md.
import_rules() {
  local from="$1" content sum g="$CTXTREE_HOME/GLOBAL.md"
  content="$(printf '%s\n' "$2" | awk '/<!-- ctxtree:begin -->/ {skip=1} !skip && !/ctxtree:managed copy/ {print} /<!-- ctxtree:end -->/ {skip=0}')"
  [ -n "$(printf '%s' "$content" | tr -d ' \t\r\n')" ] || return 0
  sum="$(printf '%s\n' "$content" | cksum | cut -d' ' -f1)"
  if grep -qF "(cksum $sum)" "$g" 2>/dev/null; then say "your rules from $from are already in GLOBAL.md"; return 0; fi
  if [ "$dry" = 1 ]; then say "would: copy your rules from $from into $g"; return 0; fi
  HDR="<!-- ctxtree:imported from $from (cksum $sum). Your rules from before ctxtree, still active. Edit or trim freely. -->" BODY="$content" awk '
    /<!-- ctxtree:begin -->/ && !done {print ENVIRON["HDR"]; print ENVIRON["BODY"]; print ""; done=1} {print}' "$g" > "$g.tmp" && mv "$g.tmp" "$g"
  say "copied your rules from $from into $g (they keep loading)"
  IMPORTED="$IMPORTED $from"
}

# link_rules <path>: point an agent's rules file at GLOBAL.md, carrying over its rules.
link_rules() {
  local path="$1" content=""
  is_ours "$path" || content="$(cat "$path" 2>/dev/null || true)"
  last_backup=""
  place_link "$CTXTREE_HOME/GLOBAL.md" "$path"
  if [ -n "$last_backup" ] && [ -n "$content" ]; then import_rules "~/${path#"$HOME"/}" "$content"; fi
}

# place_link <target> <link path>: a symlink, or where the OS refuses one (Windows
# without Developer Mode, or CTXTREE_NO_SYMLINKS=1) a managed copy. Copies of
# user owned files (GLOBAL.md) are listed in $COPIES and refreshed by ctxtree at
# every session start, so they cannot drift.
place_link() {
  local target="$1" path="$2"
  if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then return 0; fi
  if [ -e "$path" ] && ! [ -L "$path" ] && grep -qxF "copy $path" "$MANIFEST" 2>/dev/null; then
    run rm -rf "$path"                      # our own earlier copy: replace it
  else
    backup_if_foreign "$path"
  fi
  run mkdir -p "$(dirname "$path")"
  if [ "$dry" = 1 ]; then say "would: link $path -> $target"; return 0; fi
  if [ "${CTXTREE_NO_SYMLINKS:-0}" != 1 ] && ln -s "$target" "$path" 2>/dev/null && [ -L "$path" ]; then
    record "link $path"
    say "linked $path -> $target"
    return 0
  fi
  rm -rf "$path" 2>/dev/null
  if [ -d "$target" ]; then
    cp -R "$target" "$path"
  else
    case "$target" in
      "$CTXTREE_HOME"/*.md)
        { printf '<!-- ctxtree:managed copy of %s. Edit that file; this copy is refreshed automatically. -->\n' "$(native "$target")"; cat "$target"; } > "$path"
        grep -qxF "$target	$path" "$COPIES" 2>/dev/null || printf '%s\t%s\n' "$target" "$path" >> "$COPIES"
        ;;
      *) cp "$target" "$path" ;;
    esac
  fi
  grep -qxF "copy $path" "$MANIFEST" 2>/dev/null || record "copy $path"
  say "copied $path (symlinks unavailable)"
}

# place_file <path> < content   (generated file; replaced on every install)
place_file() {
  local path="$1" tmp
  tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$path" ] && ! [ -L "$path" ] && cmp -s "$tmp" "$path"; then rm -f "$tmp"; return 0; fi
  if [ -e "$path" ] || [ -L "$path" ]; then
    grep -qxF "file $path" "$MANIFEST" 2>/dev/null || backup_if_foreign "$path"
  fi
  run mkdir -p "$(dirname "$path")"
  if [ "$dry" = 1 ]; then say "would: write $path"; rm -f "$tmp"; else mv "$tmp" "$path"; fi
  grep -qxF "file $path" "$MANIFEST" 2>/dev/null || record "file $path"
  say "wrote $path"
}

# json_edit <file> <jq filter> [jq args...]: edit JSON in place, creating {} if missing.
json_edit() {
  local f="$1" filter="$2" tmp; shift 2
  if [ "$dry" = 1 ]; then say "would: edit $f with jq"; return 0; fi
  mkdir -p "$(dirname "$f")"
  [ -s "$f" ] || { [ "$uninstall" = 1 ] || record "json-created $f"; echo '{}' > "$f"; }
  if ! jq empty "$f" >/dev/null 2>&1; then
    note "SKIP $(tilde "$f") is not plain JSON (comments?). Add the ctxtree entries by hand; see README."
    return 0
  fi
  [ -e "$BACKUP/${f#"$HOME"/}" ] || { mkdir -p "$BACKUP/$(dirname "${f#"$HOME"/}")"; cp "$f" "$BACKUP/${f#"$HOME"/}"; }
  tmp="$(mktemp)"
  jq "$@" "$filter" "$f" | tr -d '\r' > "$tmp" && mv "$tmp" "$f"
}

# strip_frontmatter_key <key> < command.md
strip_key() { awk -v k="$1" 'NR==1 && /^---$/ {fm=1; print; next} fm && /^---$/ {fm=0} fm && index($0, k":")==1 {next} {print}'; }

# Hook filters: add our command once per event, remove any older ctxtree entry first.
HOOK_ADD='
  def ours: (.hooks // []) | any(.command | tostring | test("ctxtree"));
  .hooks = (.hooks // {})
  | .hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(ours | not)] + [{hooks: [{type: "command", command: $start, timeout: 10}]}])
  | .hooks.Stop = ([(.hooks.Stop // [])[] | select(ours | not)] + [{hooks: [{type: "command", command: $stop, timeout: 10}]}])'
HOOK_DEL='
  def ours: (.hooks // []) | any(.command | tostring | test("ctxtree"));
  if .hooks then .hooks |= with_entries(.value |= map(select(ours | not))) | .hooks |= with_entries(select(.value | length > 0)) else . end'

# ------------------------------------------------------------------ uninstall
if [ "$uninstall" = 1 ]; then
  [ -f "$MANIFEST" ] || { echo "nothing to uninstall: no $MANIFEST"; exit 0; }
  need jq
  awk '{l[NR] = $0} END {for (i = NR; i > 0; i--) print l[i]}' "$MANIFEST" | while read -r kind a b; do
    case "$kind" in
      link) [ -L "$a" ] && run rm "$a" && say "removed $a" ;;
      file) [ -f "$a" ] && run rm "$a" && say "removed $a" ;;
      backup) [ -e "$b" ] || [ -L "$b" ] && { [ -e "$a" ] || [ -L "$a" ] || { run mkdir -p "$(dirname "$a")"; run mv "$b" "$a"; say "restored $a"; }; } ;;
      json-hooks) [ -f "$a" ] && { json_edit "$a" "$HOOK_DEL"; say "removed ctxtree hooks from $a"; } ;;
      json-instructions) [ -f "$a" ] && { json_edit "$a" '.instructions = [(.instructions // [])[] | select(. as $i | $ours | index($i) | not)]' --argjson ours "$b"; say "removed ctxtree instructions from $a"; } ;;
      json-automemory) [ -f "$a" ] && { json_edit "$a" 'del(.autoMemoryEnabled)'; say "restored Claude auto memory default in $a"; } ;;
      json-created) [ -f "$a" ] && jq -e 'with_entries(select(.value != {} and .value != [])) == {}' "$a" >/dev/null 2>&1 && run rm "$a" && say "removed $a (created by ctxtree, now empty)" ;;
      dir) [ -d "$a" ] && run rm -rf "$a" && say "removed $a" ;;
      copy) { [ -e "$a" ] || [ -L "$a" ]; } && run rm -rf "$a" && say "removed $a" ;;
      gitconfig) [ "$(git config --global core.hooksPath 2>/dev/null)" = "$(native "$PACK/git-hooks")" ] && run git config --global --unset core.hooksPath && say "unset global core.hooksPath" ;;
    esac
  done
  if [ "$dry" = 0 ]; then
    mv "$MANIFEST" "$CTXTREE_HOME/manifest.uninstalled.$STAMP"
    rm -f "$CTXTREE_HOME/agents" "$COPIES"
  fi
  if [ "$purge" = 1 ]; then run rm -rf "$CTXTREE_HOME"; say "purged $CTXTREE_HOME"; fi
  [ "$dry" = 1 ] || rm -f "$LOG"
  say "uninstalled. Your GLOBAL.md, PROFILE.md and registry.md are kept unless --purge."
  exit 0
fi

# ------------------------------------------------------------------ install
need git; need jq; need awk; need sed
if [ "$quiet" = 1 ]; then mkdir -p "$CTXTREE_HOME" && : > "$LOG"; fi
if [ -z "$agents" ]; then
  [ -d "$HOME/.claude" ] && agents="$agents claude"
  [ -d "$HOME/.config/opencode" ] && agents="$agents opencode"
  [ -d "$HOME/.codex" ] && agents="$agents codex"
  [ -d "$HOME/.gemini" ] && agents="$agents antigravity"
fi
agents="$(echo $agents)"
[ -n "$agents" ] || { echo "no agents found; pass --agents claude,opencode,codex,antigravity" >&2; exit 1; }
for a in $agents; do case "$a" in claude|opencode|codex|antigravity) ;; *) echo "unknown agent $a" >&2; exit 2 ;; esac; done
say "ctxtree $VERSION -> $CTXTREE_HOME for: $agents$([ "$dry" = 1 ] && echo ' (dry run)')"

run mkdir -p "$CTXTREE_HOME/notes"
[ "$dry" = 1 ] || touch "$MANIFEST"

# 1. The pack itself.
if [ "$link" = 1 ]; then
  place_link "$REPO" "$PACK"
else
  if [ -L "$PACK" ]; then run rm "$PACK"; fi
  run mkdir -p "$PACK"
  for d in bin core templates commands skills git-hooks; do
    run rm -rf "${PACK:?}/$d"
    run cp -R "$REPO/$d" "$PACK/$d"
  done
  run chmod +x "$PACK/bin/ctxtree" "$PACK"/git-hooks/*
  grep -qxF "dir $PACK" "$MANIFEST" 2>/dev/null || record "dir $PACK"
  say "copied pack to $PACK"
fi
AM="$PACK/bin/ctxtree"
place_link "$AM" "$BIN_DIR/ctxtree"
# Hook commands: run through bash explicitly, with a native path, so they work
# under Git Bash on Windows as well as on macOS and Linux.
HOOK_CMD="bash \"$(native "$AM")\""
CODEX_CMD="$HOOK_CMD"
if [ "$win" = 1 ]; then
  # Codex runs hooks through cmd.exe, where "bash" may resolve to WSL. A .cmd shim
  # calls Git Bash by full path; one quoted path keeps cmd /C quoting intact.
  bash_exe="$(native "$(command -v bash)")"; case "$bash_exe" in *.exe) ;; *) bash_exe="$bash_exe.exe" ;; esac
  if [ "$dry" = 0 ]; then
    printf '@echo off\r\nif "%%CTXTREE_BASH%%"=="" set "CTXTREE_BASH=%s"\r\n"%%CTXTREE_BASH%%" "%%~dp0ctxtree" %%*\r\n' "$bash_exe" > "$PACK/bin/ctxtree.cmd"
  fi
  say "wrote $PACK/bin/ctxtree.cmd (for cmd.exe and PowerShell)"
  CODEX_CMD="\"$(native "$AM").cmd\""
fi

# 2. User owned global files: created once, never overwritten.
for f in GLOBAL PROFILE registry; do
  if [ ! -f "$CTXTREE_HOME/$f.md" ]; then
    run cp "$REPO/templates/$f.md" "$CTXTREE_HOME/$f.md"
    say "created $CTXTREE_HOME/$f.md (yours to edit)"
  fi
done

# 3. Managed block inside GLOBAL.md: the only part of a user file we rewrite.
block="$(sed -e "s|{{CTXTREE_HOME}}|$(native "$CTXTREE_HOME")|g" -e "s|{{VERSION}}|$VERSION|g" "$REPO/core/protocol.md")"
if [ "$dry" = 1 ]; then
  say "would: refresh the ctxtree managed block in $CTXTREE_HOME/GLOBAL.md"
else
  g="$CTXTREE_HOME/GLOBAL.md"
  grep -q '<!-- ctxtree:begin -->' "$g" || printf '\n<!-- ctxtree:begin -->\n<!-- ctxtree:end -->\n' >> "$g"
  BLOCK="$block" awk '
    /<!-- ctxtree:begin -->/ {print; print ENVIRON["BLOCK"]; skip=1; next}
    /<!-- ctxtree:end -->/ {skip=0}
    !skip {print}' "$g" > "$g.tmp" && mv "$g.tmp" "$g"
  say "refreshed managed block in $g"
fi

# 4. Git for the global folder, so every global change is a reviewable diff.
if [ "$git_init" = 1 ] && [ ! -d "$CTXTREE_HOME/.git" ]; then
  run git -C "$CTXTREE_HOME" init -q
  [ "$dry" = 1 ] || printf 'pack/\nbackups/\nmanifest*\nagents\ninstall.log\n' > "$CTXTREE_HOME/.gitignore"
  say "git initialised $CTXTREE_HOME (nothing committed)"
fi

# The install log is local detail, never part of the global folder's history.
if [ "$dry" = 0 ] && [ -f "$CTXTREE_HOME/.gitignore" ] && ! grep -qx 'install.log' "$CTXTREE_HOME/.gitignore"; then
  echo 'install.log' >> "$CTXTREE_HOME/.gitignore"
fi

# 5. Skills shared by Codex and OpenCode (both read ~/.agents/skills).
if echo " $agents " | grep -Eq ' (codex|opencode) '; then
  for s in $SKILLS; do keep_foreign "$HOME/.agents/skills/$s" || place_link "$PACK/skills/$s" "$HOME/.agents/skills/$s"; done
fi

# 6. Per agent wiring.
for a in $agents; do
  case "$a" in
    claude)
      link_rules "$HOME/.claude/CLAUDE.md"
      if [ "$claude_plugin" = 1 ]; then
        say "claude: commands, skills and hooks come from the plugin. In Claude Code run:"
        say "      /plugin marketplace add $REPO   then   /plugin install ctxtree@ctxtree"
        note "Claude Code: in Claude Code run /plugin marketplace add $REPO, then /plugin install ctxtree@ctxtree"
      else
        for c in $COMMANDS; do keep_foreign "$HOME/.claude/commands/$c.md" || place_link "$PACK/commands/$c.md" "$HOME/.claude/commands/$c.md"; done
        for s in $SKILLS; do keep_foreign "$HOME/.claude/skills/$s" || place_link "$PACK/skills/$s" "$HOME/.claude/skills/$s"; done
        json_edit "$HOME/.claude/settings.json" "$HOOK_ADD" --arg start "$HOOK_CMD context" --arg stop "$HOOK_CMD context --stop"
        grep -qxF "json-hooks $HOME/.claude/settings.json" "$MANIFEST" 2>/dev/null || record "json-hooks $HOME/.claude/settings.json"
        say "claude: SessionStart and Stop hooks set"
      fi
      if [ "$keep_auto" = 0 ]; then
        json_edit "$HOME/.claude/settings.json" '.autoMemoryEnabled = false'
        grep -qxF "json-automemory $HOME/.claude/settings.json" "$MANIFEST" 2>/dev/null || record "json-automemory $HOME/.claude/settings.json"
        say "claude: auto memory off (the memory tree replaces it)"
      fi
      wired "Claude Code" "rules$([ "$claude_plugin" = 1 ] && echo ', commands, skills and hooks from the plugin' || echo ', commands, skills, session hooks')$([ "$keep_auto" = 0 ] && echo '; auto memory off (the memory tree replaces it)')"
      ;;
    opencode)
      oc="$HOME/.config/opencode"
      link_rules "$oc/AGENTS.md"
      for c in $COMMANDS; do keep_foreign "$oc/commands/$c.md" || strip_key argument-hint < "$PACK/commands/$c.md" | place_file "$oc/commands/$c.md"; done
      ours="$(jq -cn --arg p "$(native "$CTXTREE_HOME/PROFILE.md")" '[$p, "memory/INDEX.md", "memory/active-task.md"]' | tr -d '\r')"
      json_edit "$oc/opencode.json" '.instructions = (((.instructions // []) - $ours) + $ours)' --argjson ours "$ours"
      grep -qF "json-instructions $oc/opencode.json" "$MANIFEST" 2>/dev/null || record "json-instructions $oc/opencode.json $ours"
      say "opencode: instructions load PROFILE.md, memory/INDEX.md, memory/active-task.md"
      wired "OpenCode" "rules, commands, skills, loads your profile and project memory"
      ;;
    codex)
      cx="${CODEX_HOME:-$HOME/.codex}"
      link_rules "$cx/AGENTS.md"
      for c in $COMMANDS; do keep_foreign "$cx/prompts/$c.md" || place_link "$PACK/commands/$c.md" "$cx/prompts/$c.md"; done
      json_edit "$cx/hooks.json" "$HOOK_ADD" --arg start "$CODEX_CMD context --profile" --arg stop "$CODEX_CMD context --stop"
      grep -qxF "json-hooks $cx/hooks.json" "$MANIFEST" 2>/dev/null || record "json-hooks $cx/hooks.json"
      say "codex: hooks written; open Codex and approve them once in /hooks"
      wired "Codex" "rules, prompts, skills, session hooks (approve once in Codex: /hooks)"
      ;;
    antigravity)
      gm="$HOME/.gemini"
      link_rules "$gm/GEMINI.md"
      for s in $SKILLS; do keep_foreign "$gm/config/skills/$s" || place_link "$PACK/skills/$s" "$gm/config/skills/$s"; done
      for c in $COMMANDS; do keep_foreign "$gm/config/global_workflows/$c.md" || strip_key argument-hint < "$PACK/commands/$c.md" | place_file "$gm/config/global_workflows/$c.md"; done
      say "antigravity: GEMINI.md (also read by Gemini CLI), skills and workflows set; run /catchup at session start"
      wired "Antigravity" "rules, skills, workflows (run /catchup at session start)"
      ;;
  esac
done
[ "$dry" = 1 ] || echo "$agents" > "$CTXTREE_HOME/agents"

# 7. Git pre-commit guard (secrets and size in memory files, stale memory warning).
if [ "$git_hook" = 1 ]; then
  current="$(git config --global core.hooksPath 2>/dev/null || true)"
  if [ -z "$current" ]; then
    run git config --global core.hooksPath "$(native "$PACK/git-hooks")"
    grep -qxF "gitconfig hooksPath" "$MANIFEST" 2>/dev/null || record "gitconfig hooksPath"
    say "git: global core.hooksPath -> $PACK/git-hooks"
  elif [ "$current" != "$(native "$PACK/git-hooks")" ]; then
    note "Git: core.hooksPath is already $current. To turn on the memory guard, add this line to its pre-commit:"
    note "      \"$AM\" check --staged || exit 1"
  fi
fi

if [ "$quiet" = 1 ]; then
  out "ctxtree $VERSION installed"
  out ""
  printf '%s' "$WIRED"
  if [ "$git_hook" = 0 ]; then guard="off (--no-git-hook)"
  elif [ "$(git config --global core.hooksPath 2>/dev/null)" = "$(native "$PACK/git-hooks")" ]; then guard="on in every repo; each repo's own hooks still run"
  else guard="not set (see notes)"; fi
  printf '  %-13s %s\n' "Git guard" "$guard"
  first="Kept yours"; for k in $KEPT; do printf '  %-13s %s\n' "$first" "$k"; first=""; done
  [ -z "$IMPORTED" ] || printf '  %-13s %s\n' "Your rules" "copied into GLOBAL.md from$(printf ' %s' $IMPORTED | sed 's/ /, /g; s/^, / /'), so they keep loading"
  nb="$( [ -d "$BACKUP" ] && find "$BACKUP" \( -type f -o -type l \) | wc -l | tr -d ' ' )"
  [ "${nb:-0}" -gt 0 ] && printf '  %-13s %s\n' "Backups" "$nb file(s) in $(tilde "$BACKUP") (--uninstall restores them)"
  if [ -n "$NOTES" ]; then out ""; out "Notes:"; printf '%s' "$NOTES" | sed 's/^/  /'; fi
  out ""
  out "Next:"
  out "  1. Fill in $(tilde "$CTXTREE_HOME")/PROFILE.md and the top of GLOBAL.md (yours to edit)."
  out "  2. Restart your agent sessions, then run /memory-init at a project's git root."
  out "  3. Check any time: ctxtree doctor"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) out "  Add $(tilde "$BIN_DIR") to PATH so agents can run ctxtree.";; esac
  out ""
  out "Full log: $(tilde "$LOG")"
  exit 0
fi
say ""
say "Done. Next:"
say "  1. Fill in $CTXTREE_HOME/PROFILE.md and the top of GLOBAL.md (yours to edit)."
say "  2. In a project at its git root: /memory-init (or: ctxtree init <topic> ...)."
say "  3. Verify: ctxtree doctor"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "  Note: add $BIN_DIR to PATH so agents can run ctxtree." ;; esac
