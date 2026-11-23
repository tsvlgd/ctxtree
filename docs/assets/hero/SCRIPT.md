# Hero script

The script for `docs/assets/hero.gif`. Write and agree the story here first; `scene.html` only renders it. Tracked in issue #6.

## What a viewer must get after one loop

> ctxtree gives coding agents the right context at the right time: one source of truth for every fact, loaded by need, kept in sync with the code, and shared by every agent.

If a newcomer would describe it only as "a tool that connects agents", the script failed.

## The central picture

One rounded box labelled **context window** sits in the middle of the frame for the whole loop. Every problem is something wrong with what is inside that box; every ctxtree beat is about putting the right thing into it. The four agent tiles (real logos, unmodified) stay at the sides, quiet until the shared memory beat.

## Beats

Captions are at most 8 words, centred above the box, one at a time. Timings are in seconds.

| # | Time | Caption | On screen | The one thing to understand | ctxtree reality |
| --- | --- | --- | --- | --- | --- |
| 1 | 0.0 to 3.5 | Every session starts from zero. | The context window is empty. A prompt bubble asks: "which package manager did we pick?" | Agents forget everything between sessions. | (problem) |
| 2 | 3.5 to 7.5 | Or drowns in everything at once. | Rules, nine skill files, old notes and a log pour in until the box overflows; the one useful line ("uses pnpm") is buried and greyed out. A small counter climbs to "15k words, every turn". | Loading everything is as bad as loading nothing. | (problem) |
| 3 | 7.5 to 11.5 | Each agent keeps its own copy. | The four agent tiles light up, each with its own note: "uses pnpm", "uses npm", "db: Postgres", "db: MySQL"; red "≠" marks between them. | No single source of truth; agents disagree. | (problem) |
| 4 | 11.5 to 14.5 | And the code moves on without them. | A commit chip "feat: switch to Bun" slides in under the box; the notes keep saying "uses pnpm" and turn amber. | Memory goes stale silently. | (problem) |
| 5 | 14.5 to 18.0 | ctxtree: one home for every fact. | The clutter clears. A `memory/` panel builds: `INDEX.md`, `stack.md`, `log.md`, `active-task.md`, with `GLOBAL.md` and `PROFILE.md` above it. | Every fact has exactly one place. | `~/.config/ctxtree/GLOBAL.md`, `PROFILE.md`, `<repo>/memory/` |
| 6 | 18.0 to 22.0 | Load only what the task needs. | Only `INDEX.md` and `active-task.md` slide into the context window (small, labelled "always"); then `stack.md` follows with the label "on demand". A counter shows "under 40 lines". | Right context, right time: small and automatic. | SessionStart hook or `instructions` load INDEX and active-task; topic files on demand |
| 7 | 22.0 to 26.0 | Kept in sync with your code. | The commit chip "feat: switch to Bun" returns; a badge on the panel flips "stale"; `stack.md` updates to "uses Bun"; the badge flips "fresh". | Memory follows the code; drift is caught. | `<memory-stale>` at session start, the Stop hook, the pre-commit guard, `/learn` |
| 8 | 26.0 to 29.5 | Shared by every agent. | Lines draw from the `memory/` panel to all four agent tiles; each tile shows the same note "uses Bun". | One truth, every agent, no disagreement. | the same tree, rules and commands in Claude Code, OpenCode, Codex and Antigravity |
| 9 | 29.5 to 34.0 | ctxtree / Context, engineered. | Title and the subline "One memory for every coding agent."; the final layout holds still. | The name and the one line promise. | |
| loop | 34.0 to 35.0 | (none) | Everything fades back to the empty box of beat 1. | | |

Total about 35 s. Each caption stays up at least 3 s, long enough to read twice.

## Visual rules

- Keep the current direction: the dark IDE like card, Inter 500 and 700, real logos on white tiles, 1280 x 640.
- Text sizes: captions 48 px or more, file names and notes 26 px or more, counters 24 px or more. Everything readable at 800 px wide.
- One thing moves at a time; transitions 0.6 to 1 s with easing.
- Colors carry meaning across beats: red is conflict, amber is stale, green is fresh and in sync, the accent is ctxtree.
- Problem beats sit slightly desaturated; answer beats are crisp. The viewer should feel the change at beat 5.

## Budget

- GIF at most 6 MB, aim for 4 MB: 15 fps during motion, holds merged.
- If 35 s does not fit, shorten beat 4 and beat 8 first (they are the simplest), never the captions' hold time.

## Open questions for the owner

1. Closing line: "Context, engineered." with the subline "One memory for every coding agent.", or the other way round?
2. Beat 2 shows a "15k words, every turn" counter, a real measurement from a real setup. Keep the number, or say "thousands of words, every turn"?
3. Length: about 35 s with nine beats, or cut to about 28 s by merging beats 3 and 4?
4. Should the agent logos appear from the first frame (as now), or only from beat 3, so the opening is about context rather than agents?
