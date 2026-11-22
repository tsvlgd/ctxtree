# Diagrams

Updated: 2026-11-22

Hand drawn diagrams for the README. Each `.excalidraw` file is the source of truth; the `.svg` and `.png` beside it are rendered from it. Every label comes from `README.md`, `docs/ARCHITECTURE.md`, `docs/FLOWS.md`, `install.sh` and `bin/ctxtree`.

| Diagram | Purpose | Source | Renders |
| --- | --- | --- | --- |
| Architecture | The global layer (`~/.config/ctxtree`) and the project layer (`memory/`, `docs/`), and how Claude Code, OpenCode, Codex and Antigravity each load rules, profile and memory. | [architecture.excalidraw](architecture.excalidraw) | [svg](architecture.svg), [png](architecture.png) |
| Session lifecycle | One session from the SessionStart hook through work, the Stop hook, `/learn` and the commit guard, plus the fresh and stale loop. | [session-lifecycle.excalidraw](session-lifecycle.excalidraw) | [svg](session-lifecycle.svg), [png](session-lifecycle.png) |
| Install | What `./install.sh` does step by step, the manifest and backups it keeps, and the `--uninstall` path back. | [install.excalidraw](install.excalidraw) | [svg](install.svg), [png](install.png) |

## Colors

The same meaning in every diagram: blue is the global layer, green is project memory, orange is the agents, red is a check that can block, gray is the uninstall path, yellow is next steps.

## Edit and rebuild

Open a `.excalidraw` file in excalidraw.com or in VS Code with the `pomdtr.excalidraw-editor` extension, save it, then rebuild every SVG and PNG:

```bash
cd docs/diagrams/render && npm ci && node render.mjs
```

The script runs the official Excalidraw exporter (`@excalidraw/excalidraw` `exportToSvg`) in headless Chrome. The SVG embeds a subset of Excalifont (SIL Open Font License), so it renders on GitHub with no network access. The PNG is a 2x screenshot of that SVG on white. Set `CHROME_PATH` if Chrome is not at a standard location. Pass slugs to rebuild only some diagrams, for example `node render.mjs install`.

## Walkthrough notes

- Architecture: read top down. Rules are a symlink to `GLOBAL.md` in every agent; the profile and the project memory arrive by a different route per agent, written in each agent box.
- Session lifecycle: follow the numbers 1 to 5 clockwise, then back to 1 at the next session. The bottom panel is the state the hooks and the git guard check.
- Install: the left column is the install order; every step writes to the manifest on the right, which `--uninstall` replays in reverse.
