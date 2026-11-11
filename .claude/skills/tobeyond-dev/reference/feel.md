# Game feel (animation, timing, sfx, juice)

The draft is not the reference for feel. The user's eye is: change one thing, show the preview or a `record.js` sheet, ask for one adjustment ("slower beat? longer hold?"). Don't guess several numbers at once.

## Current timings (keep unless the user asks)
| What | Value | Where |
|---|---|---|
| Card placement beat (between launches) | 0.28 s | `PLACE_BEAT`, `scripts/main.gd` |
| Card flight hand → tile | 0.48 s, sine in-out, 70 px arc, rotation → 0 | `PLACE_FLIGHT`, `auto_place_selected` |
| Landing pop | scale 1.2 → 1 in 0.3 s (back/out), white flash 0.22 s, ring 0.35 s | `VfxManager.pop_tile_anim(…, landed=true)` |
| Landing sfx | `sfx.step(k)` rising pentatonic per card; `whoosh` at launch (-12 dB) | `_land_card` |
| Walk step | 0.45 s ÷ speed | `battle_manager.gd` |
| Hit-stop | 0.03 / 0.07 / 0.12 s by tier (`Engine.time_scale = 0.04`, real-time timer) | `BattleManager._hit_stop` |
| Shake | `main.shake_node(node, intensity, duration, rot_deg)` | `scripts/main.gd` |
| Trigger punch | `VfxManager.trigger_juice` (scale punch, wobble, white flash) | `scripts/vfx_manager.gd` |

## Rules
- The player must not feel rushed: placement is paced by the player, so it ignores `speed_multiplier` (the ▶ x1 button). Battle effects (shake, damage numbers, toasts, walk) divide by it. Keep that split.
- One card per beat; the next launches while the previous one lands (flights overlap, impacts don't).
- Play the sfx in the landing callback, not at tween start; pitch/step follows the beat index.
- No frame where a finished item sits idle waiting for its turn, and no empty hole where an item will appear (show the empty slot art until it lands).
- Start pose is applied in the same frame the motion starts; don't delay a tween with `set_delay` on something already drawn in its final state.
- Anything flying is a copy (`duplicate()`) in `main`, `z_index` 200, `mouse_filter = IGNORE`, without its `CardSway` child; free it in the landing callback. Block the walk button meanwhile (`_placing`).
- `Engine.time_scale` only with a real-time timer: `create_timer(dur, true, false, true)` (4th arg `ignore_time_scale`).
- New juice goes into `VfxManager` with its timing as parameters, not inline tweens in `main.gd`.
- Keep Thai wording, numbers and rounding as they are.

## Checklist for a feel change
1. Change one value or one behaviour. `build.sh --check`.
2. `tools/parity/build.sh`, then `record.js` (below); run it through `runner` if the output is long, and have `parity-checker` read the sheet, not the main session.
3. Read the sheet: does anything sit still, jump, overlap badly, or vanish for a frame?
4. Commit, push, give the preview URL, ask for one adjustment.
5. `advisor` only when a feel change touches several systems (hit-stop, time scale, battle flow).

## Recording
`node tools/parity/record.js main --steps="386,600;458,600;530,600;477,678" --region=90,350,1100,330 --fps=12 --after=1800 --cols=3`
- `main` = a `?dbg=` scenario; `--steps` = clicks `x,y` (1280×720 CSS px) and waits `wN` ms.
- Output `build/record/<name>.png` (cells left→right, top→bottom, cell i ≈ 1000/fps·i ms after the last click) and a text line with Godot errors.
- Swiftshader runs ~15 fps and screenshots are slow, so a real device is smoother than the sheet. Judge order and gaps, not exact smoothness.
- The 8-card hand in `main`: cards at x = 386, 458, 530, … y = 600; Walk/"วาง" button at 477,678.
