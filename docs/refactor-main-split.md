# Refactor: split `scripts/main.gd`

Goal: `main.gd` (1543 lines, 55 KB) under 40 KB / ~700 lines so it can be read in ranges cheaply
(the guard hook blocks whole `Read` of files over 40 KB). Branch: `refactor-main-split`. One block = one commit.

## Rules
- **Move code only.** No behaviour change, no renames, no logic fixes. A bug found on the way goes in "Found" below, not into the move.
- Follow the existing pattern: classes in `scripts/` that hold `_main` (`BattleManager`, `ShopManager`, `UiRenderer`, `ArtifactSystem`).
  State and `@onready` node refs stay on `main.gd`; new classes read them as `_main.xxx`.
- Keep the old method names on `main` as one-line wrappers (`debug_scenarios.gd` and the managers call them,
  and `connect_ui_signals` binds to them). Remove wrappers nobody calls only in the last block.
- After adding a `class_name` file run `godot --headless --path . --import` once, or `build.sh --check` fails to parse.
- Don't push or merge to `main` without the user's order (the guard hook asks).

## Blocks
| # | New file | Moves from `main.gd` | Status |
|---|---|---|---|
| 1 | `game_assets.gd` | `COLORS`, texture tables, `init_textures()` -> `GameAssets.load_all(n)` (static) | done, `aa038ac` |
| 2 | `board_calc.gd` | group/direction counting (`calculate_groups`, `tile_direction_*`, `matching_*`), walk/attack maths (`compute_attack`, `apply_tile_walk_effects`, totems) | done |
| 3 | `toolbar_controls.gd` | fullscreen, audio and sort buttons (`_setup_fullscreen_button`, `_setup_audio_button`, `_style_sort_button`, ...) | done |
| 4 | `action_dialog.gd` + `slot_drag.gd` | confirm dialog (`_setup_action_dialog`, `show_action_dialog`), artifact/chaos slot drag (`_input`, `_begin_slot_drag`, `_finish_slot_drag`) | done |
| 5 | `chaos_controller.gd` | Chaos use (`_apply_hand_chaos`, `_apply_chaos_to_tile`, `hit_crystal`), tile click, discard | done |
| 6 | `reward_flow.gd` (new file, not `ui_renderer.gd`, it is already ~850 lines) | `on_victory`, `render_reward_summary`, reward rows | todo |
| 7 | none | drop wrappers on `main` that no script calls; re-measure size | todo |

Line numbers drift: find functions with `grep -n "^func " scripts/main.gd`, read ranges (<=150 lines).
Expected result: `main.gd` ~600-700 lines (node refs, state, `_ready`, new game / round / hand flow).

## Risks
- Blocks 2 and 5: `await`, tweens (`main.create_tween()`), and callables passed to the managers. Keep the tween owner on `main`.
- Signals: `connect_ui_signals()` binds buttons to `main` methods; keep those methods until the connection moves too.
- Call `advisor` once before block 2 (first block that touches walk/damage logic) and once before calling the whole task done.

## Checks (every block)
Godot on this machine is not on PATH. Use:
`export GODOT="/c/Arm/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"`

1. `tools/parity/build.sh --check` -> `check OK` (~20 s).
2. `"$GODOT" --headless --path . --script res://tools/parity/artifact_regress.gd > build/regress_new.txt`, then `diff` it with the baseline: must be identical.
3. `node tools/parity/parity.js main,arts,boss,win,shop,lose,deck,stone --fast --no-shot`: the list of differing elements and texts must equal the baseline.
   Idle card sway makes px numbers move 1-3 px every run, so strip them before diffing: `sed -E 's/ d[xywh]=[+-][0-9]+//g'`.
4. Last block only: parity `--seq` for `main` and `arts` (walk/damage timing) and the `parity-check` skill once.

Baseline = output of `main` at `2bc59c7` (`build/regress_now.txt`, `build/parity_out.txt`). `build/` is not in git, so on a new
machine regenerate it first: `git worktree add ../tb_base 2bc59c7`, link `node_modules`, copy `.godot`, run the same commands there.
Expected today: regression 195 lines with no errors; parity 14/14/16/3/14/0/2/7 differing elements for
main/arts/boss/win/shop/lose/deck/stone, errors: none. Those differences against the old draft predate this refactor.

## Done so far
- Block 1 (`aa038ac`): 57 references in `main.gd`, `shop_manager.gd`, `ui_renderer.gd` now use `GameAssets.*`. `main.gd` 1543 -> 1466 lines.

- Block 2: `BoardCalc` (10 functions, `main` keeps one-line wrappers). `main.gd` 1466 -> 1393 lines. Checks equal to baseline. Advisor not consulted yet.

- Block 3: `ToolbarControls` (fullscreen, audio, sort-button style, toggle; wrappers kept). `main.gd` 1393 -> 1323 lines. Checks equal to baseline. `toolbar` must be created before `connect_ui_signals()`.

- Block 4: `ActionDialog` (setup, show; `action_dialog` + `pending_dialog_action` stay on main) and `SlotDrag` (drag state moved into it; `main._input` forwards). `main.gd` 1323 -> 1150 lines. Checks equal to baseline.

## Found (not fixed, outside the refactor)
- `scripts/game_assets.gd`: `load_all` starts with a string "docstring" (a no-op statement); use a `##` comment if touched again.
