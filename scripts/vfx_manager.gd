class_name VfxManager
extends RefCounted

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
	, p0, p1, 0.07 / speed_multiplier)

	tween.tween_interval(duration / speed_multiplier)
	tween.tween_property(line, "width", 0.0, 0.12 / speed_multiplier)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.12 / speed_multiplier)
	tween.tween_callback(func():
		line.visible = false
		line.clear_points()
	)

## Shakes a node on damage taken
static func shake_node(node: Control, intensity: float = 14.0, duration: float = 0.38, speed_multiplier: float = 1.0) -> void:
	if not node: return
	node.pivot_offset = node.size * 0.5
	var orig_pos = node.position
	var orig_rot = node.rotation
	var tween = node.create_tween()
	var steps = int(duration / 0.04)
	for i in range(steps):
		var decay = 1.0 - (float(i) / float(steps))
		var offset = Vector2(randf_range(-intensity, intensity) * decay, randf_range(-intensity * 0.35, intensity * 0.35) * decay)
		var rot_offset = deg_to_rad(randf_range(-6.0, 6.0) * decay)
		tween.tween_property(node, "position", orig_pos + offset, 0.04 / speed_multiplier)
		tween.parallel().tween_property(node, "rotation", orig_rot + rot_offset, 0.04 / speed_multiplier)
	tween.tween_property(node, "position", orig_pos, 0.04 / speed_multiplier)
	tween.parallel().tween_property(node, "rotation", orig_rot, 0.04 / speed_multiplier)

## Spawns pop-up floating damage text
static func spawn_damage_number(effects_layer: Control, text: String, target_global_pos: Vector2, col: Color = Color("#ff4d5e"), is_big: bool = true, speed_multiplier: float = 1.0) -> void:
	if not effects_layer: return
	var pop = Label.new()
	pop.text = text
	pop.add_theme_font_size_override("font_size", 34 if is_big else 22)
	pop.add_theme_color_override("font_color", col)
	pop.add_theme_color_override("font_shadow_color", Color.BLACK)
	pop.add_theme_constant_override("shadow_offset_x", 2)
	pop.add_theme_constant_override("shadow_offset_y", 2)
	pop.add_theme_constant_override("shadow_outline_size", 4)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE

	effects_layer.add_child(pop)
	var start_pos = (effects_layer.get_global_transform().affine_inverse() * target_global_pos) + Vector2(randf_range(-15.0, 15.0), -10.0)
	pop.position = start_pos - Vector2(50.0, 20.0)
	pop.size = Vector2(100.0, 40.0)
	pop.pivot_offset = Vector2(50.0, 20.0)
	pop.scale = Vector2(0.5, 0.5)
	pop.modulate.a = 0.0

	var tween = effects_layer.create_tween()
	tween.tween_property(pop, "scale", Vector2(1.3, 1.3), 0.14 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pop, "modulate:a", 1.0, 0.12 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 45.0, 0.14 / speed_multiplier)

	tween.tween_property(pop, "scale", Vector2.ONE, 0.2 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 75.0, 0.35 / speed_multiplier)

	tween.tween_property(pop, "modulate:a", 0.0, 0.22 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 95.0, 0.22 / speed_multiplier)
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

## Quick pop bounce when placing or moving a tile card (.tile.tplace)
static func pop_tile_anim(tile_btn: Control) -> void:
	if not tile_btn: return
	tile_btn.pivot_offset = tile_btn.size / 2.0
	var tween = tile_btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tile_btn.scale = Vector2(1.12, 1.12)
	tween.tween_property(tile_btn, "scale", Vector2.ONE, 0.28)

