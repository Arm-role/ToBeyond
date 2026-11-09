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
