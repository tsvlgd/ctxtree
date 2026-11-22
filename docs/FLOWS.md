# Flows

## Session start (Claude Code, Codex)

```mermaid
sequenceDiagram
  participant A as Agent
  participant H as ctxtree context
  participant G as git
  A->>H: SessionStart (cwd, source)
  H->>H: nearest memory/INDEX.md up to git root
  H->>G: last memory update vs commits outside memory/
  H-->>A: project-memory block (INDEX, active-task, memory-stale if behind)
  A->>A: one line status, resume active task
```

OpenCode gets INDEX and active-task through `instructions`; Antigravity through `/catchup`.

## Keeping memory in sync

```mermaid
stateDiagram-v2
  [*] --> fresh
  fresh --> stale: code commit after last memory update
  stale --> fresh: memory file edited or committed
  stale --> stale: Stop hook blocks once per session per HEAD
```

Signals while stale: `<memory-stale>` at session start, one Stop block per session and code state, a warning from the git guard on each code commit without memory changes.

## Commit guard

```mermaid
sequenceDiagram
  participant D as Developer or agent
  participant P as pre-commit
  participant C as ctxtree check
  D->>P: git commit
  P->>C: staged memory files
  C-->>P: errors (secrets) / warnings (size, stale)
  alt secret found
    P-->>D: commit blocked
  else clean
    P->>P: run the repo's own .git/hooks/pre-commit
    P-->>D: commit proceeds
  end
```

## Global change (/promote)

```mermaid
sequenceDiagram
  participant A as Agent
  participant U as User
  A->>A: classify: profile, rule, or project fact
  A->>U: exact diff, ask once
  U-->>A: yes
  A->>A: write, ctxtree check --global, commit in ~/.config/ctxtree
```

## Active task lifecycle

```mermaid
stateDiagram-v2
  [*] --> planned: /task goal
  planned --> working: phase 1 next
  working --> working: phase done, findings, errors logged
  working --> closed: /task done
  closed --> [*]: facts to topics, log line, file deleted
```
