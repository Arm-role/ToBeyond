class_name VfxManager
extends RefCounted

# ---------------------------------------------------------------------------
# Particles (FxParticles: a few dozen sprites drawn in code, phone-friendly)
# ---------------------------------------------------------------------------
static var _dot_tex: GradientTexture2D = null
static var _coin_tex: ImageTexture = null
static var _add_mat: CanvasItemMaterial = null


## Touchscreens get about half the particles.
static func _count(n: int) -> int:
	return maxi(4, int(n * (0.5 if DisplayServer.is_touchscreen_available() else 1.0)))


static func _dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex


## Small golden coin drawn in code (gold disc, darker rim, highlight).
static func coin_texture() -> Texture2D:
	if _coin_tex == null:
		var n := 40
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				if d > 1.0:
					continue
				var c := Color("#ffd23f")
				if d > 0.82:
					c = Color("#c58a12")
				elif Vector2(x - 14.0, y - 13.0).length() < 7.0:
					c = Color("#fff3a8")
				img.set_pixel(x, y, c)
		_coin_tex = ImageTexture.create_from_image(img)
	return _coin_tex


## Hard-edged round spark (solid core, short soft rim) for particles that must
## read on bright cards.
static var _spark_tex: GradientTexture2D = null

static func _spark() -> Texture2D:
	if _spark_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_spark_tex = GradientTexture2D.new()
		_spark_tex.gradient = g
		_spark_tex.fill = GradientTexture2D.FILL_RADIAL
		_spark_tex.fill_from = Vector2(0.5, 0.5)
		_spark_tex.fill_to = Vector2(1.0, 0.5)
		_spark_tex.width = 32
		_spark_tex.height = 32
	return _spark_tex


static func _additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func _fx(layer: Control, at_global: Vector2, additive: bool) -> FxParticles:
	var fx := FxParticles.new()
	fx.tex = _dot()
	if additive:
		fx.material = _additive()
	fx.position = layer.get_global_transform().affine_inverse() * at_global
	layer.add_child(fx)
	return fx


## One-shot radial burst. `mid` (optional) is a second colour the particle
## fades through, e.g. yellow -> orange -> transparent. `size` is in dot-texture
## scale (1.0 = 32 px).
static func burst_particles(layer: Control, at_global: Vector2, col: Color, amount: int = 14, speed: float = 220.0, life: float = 0.5, size: float = 0.5, gravity: float = 0.0, mid: Color = Color(0, 0, 0, 0), speed_multiplier: float = 1.0, additive: bool = true, hard: bool = false) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var fx := _fx(layer, at_global, additive)
	fx.col_from = col
	fx.col_mid = mid
	fx.gravity = gravity
	fx.damping = 2.2
	if hard:
		fx.tex = _spark()
		fx.shrink_to = 0.45
	fx.speed_scale = speed_multiplier
	fx.burst(_count(amount), speed * 0.4, speed, life, size)


## Continuous trail that stays behind a moving point. Move `.position` with
## trail_move(); call stop_trail() when done.
static func start_trail(layer: Control, at_global: Vector2, col: Color, mid: Color) -> FxParticles:
	var fx := _fx(layer, at_global, true)
	fx.head = fx.position
	fx.position = Vector2.ZERO  # particles keep their place while the head moves
	fx.col_from = col
	fx.col_mid = mid
	fx.continuous = true
	fx.emit_rate = 70.0 if not DisplayServer.is_touchscreen_available() else 40.0
	fx.emit_life = 0.4
	fx.size_scale = 0.8
	return fx


static func trail_move(fx: FxParticles, at_global: Vector2) -> void:
	if fx != null and is_instance_valid(fx):
		fx.head = fx.get_parent().get_global_transform().affine_inverse() * at_global


static func stop_trail(fx: FxParticles) -> void:
	if fx != null and is_instance_valid(fx):
		fx.stop()


## Coins falling from the top edge across `width` px (victory screen).
static func coin_rain(layer: Control, amount: int, width: float) -> void:
	var fx := _fx(layer, layer.get_global_rect().position + Vector2(layer.size.x * 0.5, -30.0), false)
	fx.tex = coin_texture()
	fx.col_from = Color.WHITE
	fx.gravity = 900.0
	fx.shrink = false
	fx.fade_from = 0.7
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in _count(amount):
		fx.add_particle(Vector2(rng.randf_range(-width * 0.5, width * 0.5), 0.0), Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(260.0, 460.0)), rng.randf_range(1.2, 2.0), rng.randf_range(0.55, 0.95), rng.randf_range(-6.0, 6.0))
		fx._p.back()["age"] = -rng.randf() * 0.5  # stagger the start


## Fires laser beam from Hero or Enemy with animated width & alpha fade
static func fire_laser_beam(effects_layer: Control, line: Line2D, from_pos: Vector2, to_pos: Vector2, col: Color, beam_w: float = 20.0, duration: float = 0.25, speed_multiplier: float = 1.0) -> void:
	if not effects_layer or not line: return
	var p0 = (effects_layer.get_global_transform().affine_inverse() * from_pos)
	var p1 = (effects_layer.get_global_transform().affine_inverse() * to_pos)
	line.clear_points()
	line.add_point(p0)
	line.add_point(p0)
	line.default_color = col
	line.width = beam_w
	line.modulate.a = 1.0
	line.visible = true

	var tween = effects_layer.create_tween()
	tween.tween_method(func(pos: Vector2):
		if line.get_point_count() >= 2:
			line.set_point_position(1, pos)
	, p0, p1, 0.25 / speed_multiplier)

	tween.tween_interval(duration / speed_multiplier)
	tween.tween_property(line, "width", 0.0, 0.12 / speed_multiplier)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.12 / speed_multiplier)
	tween.tween_callback(func():
		line.visible = false
		line.clear_points()
	)

## Shakes a node on damage taken
static func shake_node(node: Control, intensity: float = 14.0, duration: float = 0.38, speed_multiplier: float = 1.0, rot_deg: float = 6.0) -> void:
	if not node: return
	node.pivot_offset = node.size * 0.5
	var orig_pos = node.position
	var orig_rot = node.rotation
	var tween = node.create_tween()
	var steps = int(duration / 0.04)
	for i in range(steps):
		var decay = 1.0 - (float(i) / float(steps))
		var offset = Vector2(randf_range(-intensity, intensity) * decay, randf_range(-intensity * 0.35, intensity * 0.35) * decay)
		var rot_offset = deg_to_rad(randf_range(-rot_deg, rot_deg) * decay)
		tween.tween_property(node, "position", orig_pos + offset, 0.04 / speed_multiplier)
		tween.parallel().tween_property(node, "rotation", orig_rot + rot_offset, 0.04 / speed_multiplier)
	tween.tween_property(node, "position", orig_pos, 0.04 / speed_multiplier)
	tween.parallel().tween_property(node, "rotation", orig_rot, 0.04 / speed_multiplier)

## Spawns pop-up floating damage text
static func spawn_damage_number(effects_layer: Control, text: String, target_global_pos: Vector2, col: Color = Color("#ff4d5e"), is_big: bool = true, speed_multiplier: float = 1.0) -> void:
	if not effects_layer: return
	var pop = Label.new()
	pop.text = text
	# Draft `.dmgpop`: 900-weight 34px (×1.5) red number with a black shadow;
	# pops from ×0.5 to ×1.3, then rises ~1.4× its height while fading.
	pop.theme_type_variation = &"BoldLabel"
	pop.add_theme_font_size_override("font_size", 51 if is_big else 33)
	pop.add_theme_color_override("font_color", col)
	pop.add_theme_color_override("font_shadow_color", Color.BLACK)
	pop.add_theme_constant_override("shadow_offset_x", 0)
	pop.add_theme_constant_override("shadow_offset_y", 3)
	pop.add_theme_constant_override("shadow_outline_size", 9)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.z_index = 120

	effects_layer.add_child(pop)
	var box := Vector2(240.0, 80.0)
	var center = effects_layer.get_global_transform().affine_inverse() * target_global_pos
	pop.size = box
	pop.pivot_offset = box * 0.5
	pop.position = center - box * 0.5
	pop.scale = Vector2(0.5, 0.5)
	pop.modulate.a = 0.0

	var total := 0.9 / speed_multiplier
	var tween = effects_layer.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pop, "scale", Vector2(1.3, 1.3), total * 0.2)
	tween.parallel().tween_property(pop, "modulate:a", 1.0, total * 0.2)
	tween.parallel().tween_property(pop, "position:y", pop.position.y - 15.0, total * 0.2)
	tween.tween_property(pop, "scale", Vector2.ONE, total * 0.8)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, total * 0.8)
	tween.parallel().tween_property(pop, "position:y", pop.position.y - 70.0, total * 0.8)
	tween.tween_callback(pop.queue_free)


## Displays formula discovery toast banner
static func show_discovery_toast(toast: PanelContainer, toast_label: Label, f_info: Dictionary, speed_multiplier: float = 1.0) -> void:
	if not toast or not toast_label or f_info.is_empty(): return
	toast_label.text = "✨ ค้นพบสูตรใหม่! · %s (%s) · ATK +%d" % [f_info.get("name", ""), f_info.get("desc", ""), f_info.get("a", 1)]
	toast.visible = true
	toast.modulate.a = 0.0
	var orig_y = 70.0
	toast.position.y = orig_y - 25.0

	var tween = toast.create_tween()
	tween.tween_property(toast, "position:y", orig_y, 0.28 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.25 / speed_multiplier)
	tween.tween_interval(2.2 / speed_multiplier)
	tween.tween_property(toast, "position:y", orig_y - 20.0, 0.25 / speed_multiplier)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.25 / speed_multiplier)
	tween.tween_callback(func(): toast.visible = false)

## Draft `.disc-toast`: centred at 36% height, fades in rising 15 px,
## holds, then fades out rising another 15 px.
static func show_center_toast(toast: PanelContainer, duration: float = 2.6) -> void:
	if not toast: return
	toast.visible = true
	toast.reset_size()
	var parent_size: Vector2 = toast.get_parent_area_size()
	var x := (parent_size.x - toast.size.x) * 0.5
	var y := parent_size.y * 0.36 - toast.size.y * 0.5
	toast.position = Vector2(x, y + 15.0)
	toast.modulate.a = 0.0
	var tween = toast.create_tween()
	tween.tween_property(toast, "position:y", y, duration * 0.1)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, duration * 0.1)
	tween.tween_interval(duration * 0.7)
	tween.tween_property(toast, "position:y", y - 15.0, duration * 0.2)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, duration * 0.2)
	tween.tween_callback(func(): toast.visible = false)

## Quick pop bounce when placing or moving a tile card (.tile.tplace)
static func pop_tile_anim(tile_btn: Control, delay: float = 0.0, landed: bool = false) -> void:
	if not tile_btn: return
	tile_btn.pivot_offset = tile_btn.size / 2.0
	# Card "lands" on the tile: starts big and faint, slams down with a small
	# overshoot, flashes white, and a ring bursts out from the tile.
	# Start pose is applied at once (no frame where the finished card sits
	# still while it waits its turn); the stagger between cards is kept short
	# so the empty-slot gap never reads as a stall.
	# `landed`: a flying card just arrived, so the tile is already solid; only
	# give it an impact squash and a white flash.
	tile_btn.scale = Vector2(1.2, 1.2) if landed else Vector2(1.6, 1.6)
	tile_btn.self_modulate = Color(2.2, 2.2, 2.2, 1.0 if landed else 0.0)
	var tween = tile_btn.create_tween().set_parallel(true)
	tween.tween_property(tile_btn, "scale", Vector2.ONE, 0.3).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile_btn, "self_modulate", Color.WHITE, 0.22).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.pivot_offset = tile_btn.size / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 0.95, 0.7, 0.9)
	sb.set_corner_radius_all(18)
	ring.add_theme_stylebox_override("panel", sb)
	ring.modulate.a = 0.0
	tile_btn.add_child(ring)
	var rt = ring.create_tween().set_parallel(true)
	var rd: float = 0.0 if landed else 0.12
	rt.tween_property(ring, "modulate:a", 1.0, 0.01).set_delay(delay + rd)
	rt.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.35).set_delay(delay + rd).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.3).set_delay(delay + 0.14)
	rt.chain().tween_callback(ring.queue_free)


## Glowing frame around a tile that fades out by itself (Chaos changed it,
## Totem moved onto it).
static func tile_glow(tile_btn: Control, color: Color, duration: float = 1.4) -> void:
	if tile_btn == null or not is_instance_valid(tile_btn): return
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.set_border_width_all(6)
	sb.border_color = color
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.8)
	sb.shadow_size = 18
	frame.add_theme_stylebox_override("panel", sb)
	tile_btn.add_child(frame)
	var t := frame.create_tween()
	t.tween_interval(duration * 0.3)
	t.tween_property(frame, "modulate:a", 0.0, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(frame.queue_free)


const HIT_FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")

## "Trigger" juice when a tile, artifact or number fires: a quick scale punch,
## a wobble that settles, and a white flash over the node and its children.
static func trigger_juice(node: Control, speed_multiplier: float = 1.0, punch: float = 1.2, wobble_deg: float = 7.0, flash_peak: float = 0.7) -> void:
	if node == null or not is_instance_valid(node): return
	var old: Tween = node.get_meta("juice_tween") if node.has_meta("juice_tween") else null
	if old != null and old.is_valid():
		old.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE
	node.rotation = 0.0
	var z0: int = node.get_meta("juice_z", node.z_index)
	node.set_meta("juice_z", z0)
	node.z_index = z0 + 10
	var d := 1.0 / maxf(speed_multiplier, 0.01)

	var mat: ShaderMaterial = null
	if flash_peak > 0.0:
		mat = node.material as ShaderMaterial
		if mat == null or mat.shader != HIT_FLASH_SHADER:
			mat = ShaderMaterial.new()
			mat.shader = HIT_FLASH_SHADER
			node.material = mat
		_share_material(node)
		mat.set_shader_parameter("flash", flash_peak)

	var t := node.create_tween()
	node.set_meta("juice_tween", t)
	t.tween_property(node, "scale", Vector2(punch, punch), 0.06 * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.34 * d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): node.z_index = z0)
	var w := deg_to_rad(wobble_deg)
	var old_wob: Tween = node.get_meta("juice_wob") if node.has_meta("juice_wob") else null
	if old_wob != null and old_wob.is_valid():
		old_wob.kill()
	var wob := node.create_tween()
	node.set_meta("juice_wob", wob)
	wob.tween_property(node, "rotation", w, 0.06 * d)
	wob.tween_property(node, "rotation", -w * 0.6, 0.09 * d)
	wob.tween_property(node, "rotation", w * 0.3, 0.09 * d)
	wob.tween_property(node, "rotation", 0.0, 0.1 * d)
	if mat != null:
		var f := node.create_tween()
		f.tween_property(mat, "shader_parameter/flash", 0.0, 0.25 * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Children without their own material draw with the parent's (the flash shader).
static func _share_material(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasItem and (c as CanvasItem).material == null:
			(c as CanvasItem).use_parent_material = true
			_share_material(c)
