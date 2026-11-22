---
name: project-docs
description: The standard for a project's human facing docs, four files in docs/ with Mermaid diagrams (ARCHITECTURE, DECISIONS, FLOWS, OPERATIONS), verified against the code. Use when the user runs /project-docs, asks to document or diagram the architecture, record a decision, or explain how the system works for a newcomer.
---

# Project docs

Memory (`memory/`) is the agents' working state. Docs (`docs/`) are the stable, reviewed explanation for humans and new agents. A fact lives in one of them, never both: once a decision is in `docs/DECISIONS.md`, memory keeps a one line pointer.

## The four files

| File | Answers | Diagrams |
| --- | --- | --- |
| `docs/ARCHITECTURE.md` | What are the parts, how do they connect, where does data live? | context `flowchart`, component `flowchart` |
| `docs/DECISIONS.md` | Why is it built this way? One record per decision, newest first. | `timeline` of decisions |
| `docs/FLOWS.md` | What happens step by step in the flows that matter? | `sequenceDiagram` per flow, `stateDiagram-v2` per lifecycle |
| `docs/OPERATIONS.md` | How do I set up, run, deploy, roll back and fix it? Where do secrets live? | environment `flowchart` |

Templates: `$CTXTREE_HOME/pack/templates/docs/` (default `~/.config/ctxtree/pack/templates/docs/`). Small projects may skip FLOWS or OPERATIONS; say so in README rather than leaving a stub.

## Rules

- Read the code first. Every component, route, table, command and environment named in docs must exist in the repo. Anything you could not confirm is marked "unverified".
- Diagrams name real components, consistently across all four files. Keep each diagram under about 15 nodes; split instead of crowding.
- Mermaid must render: quote labels that contain punctuation (`A["Worker (API)"]`), no parentheses or colons in unquoted labels, one statement per line, `stateDiagram-v2` not `stateDiagram`.
- Decision records never get rewritten. A changed decision gets a new record with `Status: supersedes Dn`, and the old one gets `Status: superseded by Dm`.
- OPERATIONS commands are copy and paste ready and taken from package scripts, Makefiles or CI files. Secrets: name where each lives, never the value.
- Put a "Last verified against the code: <date>" line at the top of ARCHITECTURE and OPERATIONS and update it on each refresh.
- Link the docs from README and `memory/INDEX.md`.

## Refresh

On `/project-docs` or when a change alters structure, flows or operations: update the affected file in the same change, keep what is still true, fix what drifted. Docs that disagree with the code are worse than no docs.
