# Game feel (animation, timing, sfx, juice)

The user's eye is the reference: change one thing, show the preview or a `record.js` sheet, ask for one adjustment ("slower beat? longer hold?"). Don't guess several numbers at once.

## Current timings (keep unless the user asks), all in `domino_view.gd`
| What | Value | Where |
|---|---|---|
| Fireball step | `min(0.20, 2.2 / steps)`, speeding up to 0.35× by the last step (whole walk ≤ 2.2 s, pauses not counted) | `_play_walk`, `MAX_WALK_TIME` |
| Bounce re-entry (same tile again) | 0.08 s wait | `_play_walk` (`pass`) |
| Hold after a strike (`shield_break`) | 0.3 s | `_play_walk` |
| Hold after each hit (fireball waits for the attack) | 0.25 s | `_play_walk`, `HIT_HOLD` |
| After the last event | 0.35 s, win message 1.1 s | `_play_walk`, `_win` |
| Character reaction | 0.05 s out, 0.10 s back, always to/from the fixed home | `_react` |
| Laser | grows 0.08 s, holds 0.03 s, fades 0.10 s | `_laser` |
| Tile pop | scale → 1.3 in 0.07 s, back in 0.12 s | `_pop` |
| Shake | 5 × 0.04 s, then 0.05 s home | `_shake` |

## Rules
- The sim (`domino_sim.gd`) has no timing. The view replays events; all pacing lives in `_play_walk`.
- Play the sfx on the event that lands (`pop` → `sfx.step(nth - 1)`), not at tween start.
- Reactions tween to/from fixed home positions and kill the previous tween on that node (see pitfalls.md).
- No frame where a finished item sits idle waiting for its turn, and no empty hole where an item will appear.
- Never await inside the sim; add a view handler for a new event kind instead.
- The fireball's travel time stays ≤ 2.5 s per walk.
- Keep Thai wording, numbers and rounding as they are.

## Checklist for a feel change
1. Change one value or one behaviour. `build.sh --check`.
2. `tools/parity/build.sh`, then `record.js` (below); run it through `runner` if the output is long.
3. Read the sheet: does anything sit still, jump, overlap badly, or vanish for a frame?
4. Commit, push, give the preview URL, ask for one adjustment.
5. `advisor` only when a feel change touches several systems.

## Recording
`node tools/parity/record.js domino --steps="400,740;800,740;w300;1000,900" --fps=12 --after=2500 --cols=4`
- `--steps` = clicks `x,y` (1280×720 CSS px) and waits `wN` ms; the first word only names the output file.
- Output `build/record/<name>.png` (cells left→right, top→bottom, cell i ≈ 1000/fps·i ms after the last click) and a text line with Godot errors.
- Swiftshader runs ~15 fps, so a real device is smoother than the sheet. Judge order and gaps, not exact smoothness.
