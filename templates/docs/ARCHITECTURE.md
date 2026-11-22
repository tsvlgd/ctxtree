# Architecture

Last verified against the code: {{DATE}}. What the parts are and how they connect. Facts here must match the code; anything uncertain is marked "unverified".

## Context

Who and what talks to the system.

```mermaid
flowchart LR
  user([User]) --> app[{{PROJECT}}]
  app --> ext1[(External service or store)]
```

## Components

| Component | Responsibility | Lives in |
| --- | --- | --- |
| <name> | <one sentence> | `<path>` |

```mermaid
flowchart TB
  subgraph {{PROJECT}}
    a[Component A] --> b[Component B]
  end
```

## Data

Where data lives, who owns it, and how it moves. Name stores exactly.

## Boundaries and constraints

Limits that shape the design (runtime, cost, compliance, scale), each with the decision in `DECISIONS.md` that follows from it.
