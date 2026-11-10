---
name: tobeyond-dev
description: Work on ToBeyond, the Godot 4.7 GDScript port of To_Beyond_Draft.html - make screens, text, numbers and animations match the HTML draft ("ให้เหมือนต้นฉบับ"), port or fix game logic, build the Web export, compare it with the draft, deploy previews. Use for any change under scripts/, scenes/ or assets/, and before running or testing the game.
---

# ToBeyond development

The HTML draft `To_Beyond_Draft.html` is the source of truth. The Godot game must look and behave like it.

## Rules that keep a task cheap (read first)

1. **Context is the cost.** Every turn re-reads the whole conversation. Batch shell work into one call, keep outputs short, and finish one task per session (the user starts a new session or runs `/clear` after a push).
2. **Never read big files whole.** The draft is 155 KB with lines up to 15k chars; `main.gd` ~1.6k lines, `shop_manager.gd` ~1.1k. Find with `grep -n`, then read a range: `sed -n 'a,bp' file | cut -c1-220` (≤150 lines). Start from `reference/map.md`.
3. **Check before building, build once per batch.** `tools/parity/build.sh --check` (seconds) after edits; full `build.sh` only before a visual check. Put several fixes in one build. Budget: ≤3 builds and ≤40 turns per task; past that, stop, summarise and ask.
4. **Numbers before pictures.** `parity.js` prints what differs as text. Don't open screenshots in the main session; when pixels matter, use the `parity-check` skill (the `parity-checker` agent looks at the images and returns a short list).
5. **Model roles.** The main session (Sonnet) does the work: reads, edits, decides, commits. Agents start cold (~20–90k tokens each), so call them only when they save more than they cost:
   - `advisor` (Opus, read-only) at checkpoints only: before a major decision (architecture, data format, a change across several systems), when the same error survives two fix attempts, and before declaring a large task done. At most ~4 calls per task; skip it for small, clear fixes. Give it the task, what you did or plan, the files/functions, and one concrete question. Follow its "Do next", or tell the user why not.
   - `runner` (Haiku) for commands with long output: full `build.sh`, `parity.js` over several scenarios, `setup_godot.sh`. Run short ones (`build.sh --check`, `git`) yourself.
   - `draft-scout` (Haiku) when a feature's draft code is unknown or spans several functions; for a known spot, read it yourself.
   - `parity-checker` (Sonnet) via the `parity-check` skill when pixels matter.
6. **Port, don't redesign.** Copy the draft's numbers, wording (Thai text verbatim), timings and rounding (`Math.round` → `roundi`, not `int()`).

## Facts

- Godot 4.7.2, GL Compatibility, canvas 1920×1080 = 1.5× the draft's 1280×720 (draft px × 1.5 = Godot px). Fonts: Sarabun + Noto Color Emoji via `assets/fonts/main_theme.tres`.
- Install Godot in a fresh container: `tools/parity/setup_godot.sh` (~1 min). Playwright + Chromium are preinstalled in cloud sessions.
- Work on the session branch. Every pushed branch deploys to `https://arm-role.github.io/ToBeyond/preview/<branch>/` (main → site root) via `.github/workflows/deploy.yml`, a few minutes after the push.
- Node paths: `python3 tools/parity/node_tree.py [filter]` prints the live tree of `scenes/main.tscn` (also in `SYSTEM_PATHS.md`).

## The loop

1. **Locate**: `reference/map.md` → draft function + Godot function → `grep -n`.
2. **Spec**: read the draft code for exact behaviour (or ask `draft-scout`).
3. **Edit** the GDScript / scene.
4. **Check**: `tools/parity/build.sh --check`.
5. **Compare**: `node tools/parity/parity.js <scenarios> --fast` for layout/text numbers without a build; `tools/parity/build.sh` then `node tools/parity/parity.js <scenarios> [--seq]` for the real web build, animation timing and images.
6. **Visual pass** when the change is visual: `parity-check` skill with the scenario (and `--region`).
7. **Review** (large or risky tasks only): ask `advisor` with the diff summary before calling it done.
8. **Commit** with a clear message and push (`git push -u origin <branch>`). Tell the user what changed, what you checked, and the preview URL.

## parity.js

`node tools/parity/parity.js <scenario[,scenario...]> [--fast] [--region=screen|top,board,bottom|center|x,y,w,h] [--seq[=frames]] [--all] [--no-shot]`

- Scenarios: `main` (fixed 8-card hand), `placed` (the 8 cards auto-placed: board, group strip, auto-place result), `arts` (artifacts +10, +5, A×1.5), `boss` (3rd enemy + Chaos + toast), `win`, `shop`, `lose`, `deck`, `stone`. Defined in `tools/parity/scenarios.js` (draft side) and `scripts/debug_scenarios.gd` (Godot side, `?dbg=<name>` / `-- --dbg=<name>`).
- Output: one line per differing element, Godot minus draft, CSS px of the 1280×720 page. Labels compare the drawn text (centre ±4 px, width ±max(6 px, 8%)); buttons/panels compare their boxes (±4 px). `text "a" / "b"` = wording or numbers differ (draft / Godot). Ends with Godot runtime errors.
- `--seq` clicks the first hand card, Walk, Walk, then logs every change of the damage formula with timestamps on both sides (e.g. `0.42 3×1=3 · 1.07 13×1=13`) and saves a frame sheet.
- Images: `build/parity/<scenario>[_region].png`, draft on top, Godot below; one full-resolution image per region (`screen` = top, board, bottom).
- Random content (shop offers, deck order outside the fixed hand) differs by design.
- New element to compare: add `name: [css selector, Godot path]` to the scenario's `els` (`"Path/*"` = every child, compared item by item). New state: add it to both `scenarios.js` and `debug_scenarios.gd` (reach it through the game's own functions, like `on_shop_leave()` for the next enemy).

## Other tools

- `tools/parity/build.sh [--check]`: logs in `build/import.log`, `build/export.log`.
- `python3 tools/parity/token_report.py`: turns, context size and cache use per request of this session. Use it to report cost at the end of a large task.

## Reference (read only the part you need)

- `reference/map.md`: feature → draft section/functions → Godot file/functions, data tables, draft CSS selectors.
- `reference/pitfalls.md`: Godot/web traps already hit in this project (fonts, SVG text, z-index, type inference, class cache, …).
