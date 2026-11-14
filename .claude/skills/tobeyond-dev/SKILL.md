---
name: tobeyond-dev
description: Work on ToBeyond, the Godot 4.7 GDScript game (Domino Run) - change screens, text, numbers, artifacts, bosses, game logic and game feel (animation, easing, timing, sfx on the beat, juice, shake, pacing), build the Web export, record animations to check them, deploy previews. Use for any change under scripts/, scenes/, data/ or assets/, for animation / game feel / juice requests ("ให้ลื่น", "เร็วไป", "พุ่ง", "ค้าง"), and before running or testing the game.
---

# ToBeyond development

The game is Domino Run: `scenes/domino.tscn` → `scripts/domino/domino_view.gd` (draws) over `domino_sim.gd` (rules, no UI). Artifacts and bosses are data in `data/domino/`. The Godot code is the source of truth; `To_Beyond_Draft.html` is only read when the user orders it. Plan and history: `docs/plan-domino-run.md`, `docs/domino/`, design rule `docs/design-principles.md`.

## Rules that keep a task cheap (read first)

1. **Context is the cost.** Every turn re-reads the whole conversation. Batch shell work into one call, keep outputs short, and finish one task per session.
2. **Never read big files whole.** `domino_sim.gd` and `domino_view.gd` are 500+ lines. Find with `grep -n`, then read a range (≤150 lines). Start from `reference/map.md`. Regress baselines are thousands of lines: grep them, never read them.
3. **Check before building, build once per batch.** `tools/parity/build.sh --check` (seconds) after edits; `--regress` after any change to rules, artifacts or bosses; full `build.sh` only before a visual check. Budget: ≤3 builds and ≤40 turns per task.
4. **Rules live in the sim.** New behaviour = a new verb, condition or event in `domino_sim.gd` plus a handler in `_play_walk`; balance changes are numbers in the `.tres` files or sim constants. The sim never awaits and never touches nodes.
5. **Model roles.** The main session (Sonnet) does the work. Agents start cold (~20–90k tokens), so call them only when they save more than they cost:
   - `advisor` (Opus, read-only) at checkpoints: before a data-structure decision, when the same error survives two fixes, before declaring a large task done. Give it the task, what you did, the files/functions and one concrete question. It may run out of turns: tell it to deliver its report without further tool calls.
   - `runner` (Haiku) for commands with long output: full `build.sh`, `setup_godot.sh`. Run short ones yourself.
6. **Keep what exists.** Keep current numbers, Thai wording, timings and rounding (`roundi`, not `int()`) unless the user asks to change them.
7. **Every playable screen shows the version stamp** bottom-right (`_add_version_stamp`).

## Facts

- Godot 4.7.2, GL Compatibility, canvas 1920×1080. Fonts: Sarabun + Noto Color Emoji via `assets/fonts/main_theme.tres`.
- Fresh container: `tools/parity/setup_godot.sh`. Playwright + Chromium are preinstalled in cloud sessions.
- New `class_name` isn't known until `godot --import`; the Domino scripts use `preload` constants instead.
- Branches, version bump and previews: `CLAUDE.md`. Debug start: `?arts=mirror,coal` (or `-- --arts=…`) pre-fills the slot bar.

## The loop

1. **Locate**: `reference/map.md` → file: function → `grep -n`. The map is checked by `build.sh --check`; if you move or rename something it lists, update the map.
2. **Edit** the GDScript / `.tres`.
3. **Check**: `tools/parity/build.sh --check`; for sim, artifact or boss changes also `--regress` (diff vs `tools/parity/baseline/domino_regress.txt`; `--regress --update` only for an intended change, and commit it). New artifact/boss/verb → add regress lines in `domino_regress.gd`.
4. **See it** when the change is visual: `tools/parity/build.sh`, then `record.js` (see `reference/feel.md`) or a Playwright screenshot script against `build/web`.
5. **Review** (large or risky tasks only): `advisor` with the diff summary.
6. **Learn**: if the task needed more than 2 fix rounds, or `advisor` listed a new pitfall, add one line to `reference/pitfalls.md` (format there).
7. **Commit**: bump the patch of `config/version` in `project.godot` (once per push; skip for `.md`-only pushes), commit, push (`git push -u origin <branch>`). Tell the user the new version, what changed, what you checked and the preview URL.

## Other tools

- `node tools/parity/record.js <name> --steps="x,y;wN;…"`: records the web build while clicking and writes a contact sheet `build/record/<name>.png` (details in `reference/feel.md`).
- `python3 tools/parity/node_tree.py`: static node tree of `scenes/domino.tscn` (most nodes are built in code, so grep `_build` instead).
- `python3 tools/parity/token_report.py`: turns, context size and cache use per request; report cost at the end of a large task.
- `evals/`: replays of past changes on old code bases; kept for history, not maintained after the old game's removal.

## Reference (read only the part you need)

- `reference/map.md`: feature → file: functions (checked by `build.sh --check`).
- `reference/feel.md`: current timings, feel rules and `record.js` usage. Read it for any animation / juice / timing change.
- `reference/pitfalls.md`: Godot/web traps already hit in this project.
