---
name: tobeyond-dev
description: Work on ToBeyond, the Godot 4.7 GDScript game - change screens, text, numbers, game logic and game feel (animation, easing, timing, sfx on the beat, juice, hit-stop, shake, pacing), build the Web export, record animations to check them, compare layout with the old draft when the user orders it, deploy previews. Use for any change under scripts/, scenes/ or assets/, for animation / game feel / juice requests ("ให้ลื่น", "เร็วไป", "พุ่ง", "ค้าง"), and before running or testing the game.
---

# ToBeyond development

The Godot code is the source of truth. `To_Beyond_Draft.html` is read or searched only when the user orders it (a hook asks them); `reference/map.md` maps features to Godot functions (its appendix lists the draft's). Change behaviour from the Godot code and what the user asks for.

## Rules that keep a task cheap (read first)

1. **Context is the cost.** Every turn re-reads the whole conversation. Batch shell work into one call, keep outputs short, and finish one task per session (the user starts a new session or runs `/clear` after a push).
2. **Never read big files whole.** `main.gd`, `shop_manager.gd` and `ui_renderer.gd` are 800+ lines each. Find with `grep -n`, then read a range: `sed -n 'a,bp' file | cut -c1-220` (≤150 lines). Start from `reference/map.md`.
3. **Check before building, build once per batch.** `tools/parity/build.sh --check` (seconds) after edits; full `build.sh` only before a visual check. Put several fixes in one build. Budget: ≤3 builds and ≤40 turns per task; past that, stop, summarise and ask.
4. **Numbers before pictures.** `parity.js` prints what differs as text. Don't open screenshots in the main session; when pixels matter, use the `parity-check` skill (the `parity-checker` agent looks at the images and returns a short list).
5. **Model roles.** The main session (Sonnet) does the work: reads, edits, decides, commits. Agents start cold (~20–90k tokens each), so call them only when they save more than they cost:
   - `advisor` (Opus, read-only) at checkpoints only: before a major decision (architecture, data format, a change across several systems), when the same error survives two fix attempts, and before declaring a large task done. At most ~4 calls per task; skip it for small, clear fixes. Give it the task, what you did or plan, the files/functions, and one concrete question. Follow its "Do next", or tell the user why not.
   - `runner` (Haiku) for commands with long output: full `build.sh`, `parity.js` over several scenarios, `setup_godot.sh`. Run short ones (`build.sh --check`, `git`) yourself.
   - `parity-checker` (Sonnet) via the `parity-check` skill when pixels matter.
6. **Keep what exists.** Keep current numbers, Thai wording, timings and rounding (`roundi`, not `int()`) unless the user asks to change them.

## Facts

- Godot 4.7.2, GL Compatibility, canvas 1920×1080 = 1.5× the draft's 1280×720 (draft px × 1.5 = Godot px). Fonts: Sarabun + Noto Color Emoji via `assets/fonts/main_theme.tres`.
- Fresh container: `tools/parity/setup_godot.sh` (command list in `CLAUDE.md`). Playwright + Chromium are preinstalled in cloud sessions.
- Branches and previews: see `CLAUDE.md`. The preview deploys via `.github/workflows/deploy.yml` a few minutes after the push.
- Node paths: `python3 tools/parity/node_tree.py [filter]` prints the live tree of `scenes/main.tscn` (also in `SYSTEM_PATHS.md`).

## The loop

1. **Locate**: `reference/map.md` → Godot file: function → `grep -n`. The map is checked by `build.sh --check`; if you move or rename something it lists, update the map.
2. **Spec**: read the Godot code and the user's request. Don't open the draft unless the user orders it.
3. **Edit** the GDScript / scene.
4. **Check**: `tools/parity/build.sh --check`; for artifact / Chaos / walk / damage logic also `tools/parity/build.sh --regress` (diff vs `tools/parity/baseline/`; `--regress --update` only for an intended change, and commit it).
5. **Compare** (the parity tools compare with the draft; use them for layout/animation checks or when the user orders a draft comparison): `node tools/parity/parity.js <scenarios> --fast` for layout/text numbers without a build; `tools/parity/build.sh` then `node tools/parity/parity.js <scenarios> [--seq]` for the real web build, animation timing and images.
6. **Visual pass** when the change is visual: `parity-check` skill with the scenario (and `--region`).
7. **Review** (large or risky tasks only): ask `advisor` with the diff summary before calling it done.
8. **Learn**: if the task needed more than 2 fix rounds, or `advisor` said **stop** or listed a new pitfall, add one line to `reference/pitfalls.md` (Lessons log, format there). Skip it for routine tasks.
9. **Commit**: first bump the patch of `config/version` in `project.godot` (once per push; skip for `.md`-only pushes; see `CLAUDE.md`), then commit with a clear message and push (`git push -u origin <branch>`). Tell the user the new version, what changed, what you checked, and the preview URL.

## parity.js

`node tools/parity/parity.js <scenario[,scenario...]> [--fast] [--region=screen|top,board,bottom|center|x,y,w,h] [--seq[=frames]] [--all] [--no-shot]`

- Scenarios: `main` (fixed 8-card hand), `placed` (the 8 cards auto-placed: board, group strip, auto-place result), `arts` (artifacts +10, +5, A×1.5), `boss` (3rd enemy + Chaos + toast), `win`, `shop`, `lose`, `deck`, `stone`. Defined in `tools/parity/scenarios.js` (draft side) and `scripts/debug_scenarios.gd` (Godot side, `?dbg=<name>` / `-- --dbg=<name>`).
- Output: one line per differing element, Godot minus draft, CSS px of the 1280×720 page. Labels compare the drawn text (centre ±4 px, width ±max(6 px, 8%)); buttons/panels compare their boxes (±4 px). `text "a" / "b"` = wording or numbers differ (draft / Godot). Ends with Godot runtime errors.
- `--seq` clicks the first hand card, Walk, Walk, then logs every change of the damage formula with timestamps on both sides (e.g. `0.42 3×1=3 · 1.07 13×1=13`) and saves a frame sheet.
- Images: `build/parity/<scenario>[_region].png`, draft on top, Godot below; one full-resolution image per region (`screen` = top, board, bottom).
- Random content (shop offers, deck order outside the fixed hand) differs by design.
- New element to compare: add `name: [css selector, Godot path]` to the scenario's `els` (`"Path/*"` = every child, compared item by item). New state: add it to both `scenarios.js` and `debug_scenarios.gd` (reach it through the game's own functions, like `on_shop_leave()` for the next enemy).

## Other tools

- `node tools/parity/record.js <scenario> --steps="x,y;wN;…" [--region=x,y,w,h] [--fps=12]`: records the Godot web build while clicking, writes a contact sheet `build/record/<name>.png` of the frames after the last click. For animation/feel checks (no draft needed); details in `reference/feel.md`.

- Evals: `python3 evals/run.py list|validate|setup <id>|check <id>|record …` replay real past changes to measure whether the setup (skill, agents) helps; it never runs an agent itself. Add a task whenever a pushed change would make a good test, then `validate` it.
- Build logs: `build/import.log`, `build/export.log`. `python3 tools/parity/token_report.py` reports turns, context size and cache use per request; use it to report cost at the end of a large task. Other commands: `CLAUDE.md`.

## Reference (read only the part you need)

- `reference/map.md`: feature → Godot file: functions (checked by `build.sh --check`), data tables; appendix: draft functions and CSS selectors.
- `reference/feel.md`: game feel: current timings, rules (speed_multiplier, no idle frames, sfx on landing), checklist, and `record.js` usage. Read it for any animation / juice / timing change.
- `reference/pitfalls.md`: Godot/web traps already hit in this project (fonts, SVG text, z-index, type inference, class cache, …).
