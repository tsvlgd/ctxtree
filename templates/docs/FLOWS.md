# Flows

What happens, step by step, for the flows that matter. One sequence per flow, one state diagram per lifecycle. Name the real components from `ARCHITECTURE.md`.

## <Flow name>

```mermaid
sequenceDiagram
  actor U as User
  participant A as {{PROJECT}}
  U->>A: request
  A-->>U: response
```

What can fail at each step and what the user sees.

## <Entity> lifecycle

```mermaid
stateDiagram-v2
  [*] --> created
  created --> done
  done --> [*]
```
