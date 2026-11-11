# Pitfalls already hit in this project

## Rendering / fonts
- Web exports can't use system fonts. The theme (`assets/fonts/main_theme.tres`) bundles Sarabun + Noto Color Emoji; any glyph outside them renders as a box. Missing so far: `↻ ✦ ✓ 🂠` (that is why the deck button shows 🃏; matching the draft needs an SVG icon). Check a new symbol before using it; don't add a third fallback font (metrics/colour broke).
- Theme variations: `BoldLabel`, `PlainButton`, `EmojiPic` (big emoji, negative spacing).
- Godot's SVG importer drops `<text>`: tile numbers etc. are Labels overlaid on the SVG.
- CSS dashed borders → `DashedStyleBox` (`scripts/dashed_style_box.gd`).

## Layout / UI
- Draft px × 1.5 = Godot px (1280×720 → 1920×1080).
- Modals/overlays need `z_index = 100`, otherwise hand cards draw on top.
- A new `StyleBoxFlat` has a grey background: set `bg_color = Color(0,0,0,0)` when you only want a border.
- Popup buttons: zero the content margins or the text sits off-centre.
- `queue_free()`d children still count in `get_child_count()` until the frame ends: skip `is_queued_for_deletion()`.

## GDScript
- `var x := <untyped expression>` fails ("Cannot infer the type"): give the type (`var x: float = …`).
- A new `class_name` isn't known until `godot --import` refreshes the class cache: use `preload("res://scripts/x.gd")` or run `build.sh` first.
- Don't `preload()` a newly added raw asset (SVG/PNG) before it is imported; load it in `_ready()` with `ResourceLoader.exists()`.
- JS `Math.round` ≠ GDScript `int()` (truncates): use `roundi()` to match the draft (e.g. boss HP 112.5 → 113).
- Headless Godot keeps running after a script error; always use a timeout (the tools do).

## Draft behaviour worth knowing
- Timings: walk step 450 ms ÷ speed; `attackSeq` = 350 ms pause, 450 ms per artifact step, 250 ms, then `strike` (750 ms Bézier, ease q^1.6).
- The formula shows `1 × 1 = 1` until the walk; it grows during the walk; artifacts then apply one by one.
- `spawnEnemy()` adds the CSS class `spawn` (an entrance animation): measure after it ends.
- Boss = every 3rd enemy (`bossN % 3 === 2` in the draft, `stage % 3 == 0` in Godot).

## Tooling
- Swiftshader WebGL is slow at screenshots (~0.4 s each); `--seq` therefore logs the formula by polling text and takes frames in a second pass.
- Godot web console noise "GL Driver Message … GPU stall" is filtered; real errors start with `SCRIPT ERROR` / `ERROR`.

## Animation / game feel
- A tween that sets a start pose (`alpha 0`, `scale 1.6`) with `set_delay` leaves the node in its final state until the delay ends (a finished card sits idle) or, if the pose is applied at once, a hole in the board. Apply the start pose when the motion starts; show the empty-slot art until a flying card lands.
- `Control.duplicate()` of a hand card copies its `CardSway` child, which fights tweens on rotation/scale: remove it from the copy. Hand cards are rebuilt on every `render_hand()`, so copy the visuals before `update_all_ui()`.
- A flying copy needs `mouse_filter = IGNORE`, a high `z_index`, and a flag (`_placing`) that blocks the Walk button until the last card lands.
- Non-uniform scale on a flying card stretches its emblem into an ellipse: use one uniform scale factor.
- Sound synthesis (`SfxManager._stream`) is cheap (2-40 ms); it was not the cause of a placement stall. Measure (`Time.get_ticks_usec`) before blaming it.
- Swiftshader runs ~15 fps and `page.screenshot()` is slower than the animation: screenshots miss short motion. Use `tools/parity/record.js` (video + ffmpeg).

## Lessons log (newest last)
One line per lesson, added by the worker after a task (rule: step 9 of the loop in `SKILL.md`). Format: `YYYY-MM-DD | symptom → cause → fix (commit)`. Only things confirmed by a fix that worked; no guesses. If a lesson fits a section above, put it there instead.
- 2026-11-08 | converting a global position to a Control's local space with `to_local()` → `to_local()` is a Node2D method, not a Control one → use `node.get_global_transform().affine_inverse() * global_pos` (4729858)
