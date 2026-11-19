# ToBeyond development workflow

Read `run/main_scene` in `project.godot` and follow the active scene's script. In the classic game, start with `main.gd` and follow its controllers and managers. In Domino Run, follow the view for UI and playback and the simulation for deterministic rules.

Use the Godot project as the source of truth. Read or search `To_Beyond_Draft.html` only when the user explicitly requests it. Preserve Thai wording, balance values, timing, and rounding outside the requested changes. Keep rules in the simulation, controllers, or data resources used by the active branch and keep rendering and animation in the view.

## Find and validate changes

1. Start with the [feature map](reference/map.md). Search for the relevant function and read the surrounding lines. Update the map when moving or renaming code it lists. Read the [game feel guide](reference/feel.md) for animation or timing changes and the [pitfalls](reference/pitfalls.md) when diagnosing a recurring issue.
2. Use Godot 4.7.2 and matching Web templates. If needed, run `bash tools/parity/setup_godot.sh`. Export `GODOT` with the executable path, then run `"$GODOT" --headless --path . --import` from the repo root on a fresh checkout or after switching branches.
3. Run `bash tools/parity/build.sh --check` for the branch's script and smoke checks. Run `bash tools/parity/build.sh --regress` after changing gameplay rules, scoring, artifacts, bosses, or Chaos. Use `--regress --update` only when you have verified that the baseline differences match the intended changes.
4. For visual or browser checks, run `bash tools/parity/build.sh`, then serve `build/web` with `python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web`. Check the affected interaction in a browser. For timing checks, use `node tools/parity/record.js` with the scenario and input sequence described in the game feel guide. Build logs are in `build/import.log` and `build/export.log`.
5. Use `python3 tools/parity/node_tree.py` to inspect the scene tree when supported by the checkout. Use the existing eval harness to replay historical scenarios when relevant.

## Version and preview

Work on the requested branch. For a requested push that includes changes beyond Markdown, bump the patch in `project.godot` once per push unless the user specifies another increment. Keep the version and commit stamp visible at the bottom right of every playable screen. GitHub Actions publishes `main` at the site root and other branches under `/ToBeyond/preview/<branch>/` on `arm-role.github.io`. Verify deployments against the intended commit and report the version, checks, and preview URL.

## Legacy draft comparison

Use this workflow only when the user requests a draft comparison and the checkout includes the parity tool. For layout and text comparisons use `--fast`. To compare the Web build or animation, build it first and use the relevant scenario, with `--seq` for a click sequence.

`node tools/parity/parity.js <scenario[,scenario...]> [--fast] [--region=screen|top,board,bottom|center|x,y,w,h] [--seq[=frames]] [--all] [--no-shot]`

- Scenarios: `main` (fixed 8-card hand), `placed` (the 8 cards auto-placed: board, group strip, auto-place result), `arts` (artifacts +10, +5, A×1.5), `boss` (3rd enemy + Chaos + toast), `win`, `shop`, `lose`, `deck`, `stone`. Defined in `tools/parity/scenarios.js` (draft side) and `scripts/debug_scenarios.gd` (Godot side, `?dbg=<name>` / `-- --dbg=<name>`).
- Output: one line per differing element, Godot minus draft, CSS px of the 1280×720 page. Labels compare the drawn text (centre ±4 px, width ±max(6 px, 8%)); buttons/panels compare their boxes (±4 px). `text "a" / "b"` = wording or numbers differ (draft / Godot). Ends with Godot runtime errors.
- `--seq` clicks the first hand card, Walk, Walk, then logs every change of the damage formula with timestamps on both sides (e.g. `0.42 3×1=3 · 1.07 13×1=13`) and saves a frame sheet.
- Images: `build/parity/<scenario>[_region].png`, draft on top, Godot below; one full-resolution image per region (`screen` = top, board, bottom).
- Random content (shop offers, deck order outside the fixed hand) differs by design.
- New element to compare: add `name: [css selector, Godot path]` to the scenario's `els` (`"Path/*"` = every child, compared item by item). New state: add it to both `scenarios.js` and `debug_scenarios.gd` (reach it through the game's own functions, like `on_shop_leave()` for the next enemy).
