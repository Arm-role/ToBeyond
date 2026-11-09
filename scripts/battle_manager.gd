class_name BattleManager
extends RefCounted

# ==============================================================================
# BattleManager — Animated walk & battle sequences
# Holds a weak reference to Main so it can read state and call callbacks.
# All tweens are created via main.create_tween() so they are tied to main's
# SceneTree lifecycle. await is called on the caller (main) via Callable.
# ==============================================================================

# Node refs — set by Main._ready() via BattleManager.new(main)
var _main: Node


func _init(main: Node) -> void:
	_main = main


# ---------------------------------------------------------------------------
# Shortcut helpers (keep code readable inside this file)
# ---------------------------------------------------------------------------

func _ct() -> Tween:
	return _main.create_tween()

func _timer(sec: float) -> Signal:
	return _main.get_tree().create_timer(sec / _main.speed_multiplier).timeout

func _spd() -> float:
	return _main.speed_multiplier


# ---------------------------------------------------------------------------
# Public entry point — called from main._on_walk_pressed()
# ---------------------------------------------------------------------------

func run_walk() -> void:
	_main.walks_left -= 1
	_main.is_busy = true
	_main.begin_walk_damage()
	_main.update_all_ui()
	_main.msg_label.text = "กำลังเดิน..."

	var token: Control          = _main.token
	var tiles_container         = _main.tiles_container
	var placed_cards: Dictionary = _main.placed_cards
	var N_TILES: int            = _main.N_TILES

	token.visible = true
	var tween = _ct()
	# Draft: one stop every 500 ms (0.45 s slide + short pause).
	var step_duration = 0.45 / _spd()

	# Collect stops (Tile 0 + all cards + Chaos crystals + Totems)
	var active_tiles: Array[int] = [0]
	for i in range(1, N_TILES):
		if placed_cards.has(i) or _main.chaos_crystals.has(i) or _main.totem_tiles.has(i):
			active_tiles.append(i)

	var forward_tiles: Array[int] = active_tiles.duplicate()
	if _main.has_artifact("reverse") and active_tiles.size() > 1:
		var rev = active_tiles.duplicate()
		rev.reverse()
		rev.pop_front()
		for idx in rev:
			active_tiles.append(idx)

	# Odd/Even helpers take their own pass before the fireball. Their pass
	# triggers landing effects but intentionally does not consume First Strike.
	var walk_steps: Array[Dictionary] = []
	for helper_type in ["helperOdd", "helperEven"]:
		if not _main.has_artifact(helper_type):
			continue
		var wants_odd: bool = helper_type == "helperOdd"
		for tile_idx in forward_tiles:
			if ((tile_idx + 1) % 2 == 1) == wants_odd:
				walk_steps.append({"tile": tile_idx, "helper": true})
	for tile_idx in active_tiles:
		walk_steps.append({"tile": tile_idx, "helper": false})

	for step in walk_steps:
		var idx: int = step["tile"]
		var helper_pass: bool = step["helper"]
		var tile_btn = tiles_container.get_child(idx) as Button
		# Derive the token position from the actual tile instead of fixed 1280px
		# offsets. This remains correct at the 1920 canvas and when scaled.
		var target_pos = tile_btn.position + (tile_btn.size - token.size) * 0.5
		tween.tween_property(token, "position", target_pos, step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_visit_tile.bind(idx, helper_pass))
		tween.tween_interval(0.05 / _spd())

	tween.finished.connect(_on_walk_finished)


func _visit_tile(tile_idx: int, helper_pass: bool) -> void:
	if _main.placed_cards.has(tile_idx):
		_spawn_tile_popup(tile_idx, helper_pass)
	if _main.totem_tiles.has(tile_idx):
		_hit_totem(tile_idx)
	if _main.chaos_crystals.has(tile_idx):
		_hit_crystal(tile_idx)


# ---------------------------------------------------------------------------
# Internal: popup "+N ATK" above a tile during walk
# ---------------------------------------------------------------------------

func _spawn_tile_popup(tile_idx: int, helper_pass: bool = false) -> void:
	var tiles_container  = _main.tiles_container
	var effects_layer    = _main.effects_layer
	var placed_cards     = _main.placed_cards

	var tile_btn = tiles_container.get_child(tile_idx) as Button
	var card = placed_cards.get(tile_idx)
	if card == null: return

	var applied = _main.apply_tile_walk_effects(tile_idx, helper_pass)
	var gain = int(applied["gain"])
	# A gold Gem (created by Chaos Goldify) resolves its landing effects twice.
	if card.get("gold", false):
		var repeated = _main.apply_tile_walk_effects(tile_idx, helper_pass)
		applied["extra"] = int(applied["extra"]) + int(repeated["extra"])
		gain += int(repeated["gain"])

	var pop = Label.new()
	if card.get("is_blank", false):
		pop.text = "+0"
		pop.modulate = Color.GRAY
	else:
		pop.text = "+%d ATK" % gain
		pop.modulate = _main.COLORS.get(card["color"], Color.CYAN)

	pop.add_theme_font_size_override("font_size", 18)
	pop.add_theme_color_override("font_shadow_color", Color.BLACK)
	pop.add_theme_constant_override("shadow_offset_x", 1)
	pop.add_theme_constant_override("shadow_offset_y", 1)
	pop.add_theme_constant_override("shadow_outline_size", 3)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE

	effects_layer.add_child(pop)
	var start_pos = (effects_layer.get_global_transform().affine_inverse() * tile_btn.global_position) + Vector2(tile_btn.size.x * 0.5 - 60.0, -10.0)
	pop.position = start_pos
	pop.size = Vector2(120, 36)
	pop.pivot_offset = Vector2(60, 18)
	pop.scale = Vector2(0.5, 0.5)

	var pop_tween = _ct()
	pop_tween.tween_property(pop, "scale", Vector2(1.15, 1.15), 0.12 / _spd()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.parallel().tween_property(pop, "position:y", start_pos.y - 30.0, 0.3 / _spd())
	pop_tween.tween_property(pop, "scale", Vector2(0.9, 0.9), 0.12 / _spd())
	pop_tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.18 / _spd())
	pop_tween.parallel().tween_property(pop, "position:y", start_pos.y - 50.0, 0.18 / _spd())
	pop_tween.tween_callback(pop.queue_free)

	if int(applied["extra"]) > 0:
		_main.spawn_damage_number("+%d" % int(applied["extra"]), tile_btn.global_position + tile_btn.size * 0.5, Color("#ffd966"), false)
	_main.refresh_calc()


func _hit_crystal(tile_idx: int) -> void:
	var tile_btn = _main.tiles_container.get_child(tile_idx) as Button
	var result: Dictionary = _main.hit_crystal(tile_idx)
	if int(result["used"]) <= 0:
		return
	var text := "💎 -%d" % int(result["used"])
	if result["broken"]:
		text = "💎 แตก! +%d Gem" % _main.CRYSTAL_GEMS
	_main.spawn_damage_number(text, tile_btn.global_position + tile_btn.size * 0.5, Color("#72d8ff"), false)
	_main.refresh_calc()


func _hit_totem(tile_idx: int) -> void:
	var tile_btn = _main.tiles_container.get_child(tile_idx) as Button
	var gain: int = _main.totem_attack(tile_idx)
	_main.walk_base_damage += gain
	_main.spawn_damage_number("🗿 +%d" % gain, tile_btn.global_position + tile_btn.size * 0.5, Color("#7fd0ff"), false)
	_main.refresh_calc()


# ---------------------------------------------------------------------------
# Walk finished → hero charges → fires beam → enemy takes damage
# ---------------------------------------------------------------------------

func _on_walk_finished() -> void:
	var token     = _main.token
	var hero_pic  = _main.hero_pic
	var enemy_pic = _main.enemy_pic

	# 1. Fireball flies to Hero along curved Bézier path
	_main.msg_label.text = "✨"
	var start_global = token.global_position + token.size * 0.5
	var hero_center  = hero_pic.global_position + hero_pic.size * 0.5
	var mid_global   = (start_global + hero_center) * 0.5 + Vector2(-60.0, -100.0)

	var fly_tween = _ct()
	fly_tween.tween_method(func(t: float):
		var omt = 1.0 - t
		token.global_position = omt * omt * start_global + 2.0 * omt * t * mid_global + t * t * hero_center - token.size * 0.5
	, 0.0, 1.0, 0.35 / _spd()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await fly_tween.finished
	token.visible = false
	token.position = Vector2(20.0, 26.0)

	# 2. Hero charge pulse
	hero_pic.pivot_offset = hero_pic.size * 0.5
	var charge_tween = _ct()
	charge_tween.tween_property(hero_pic, "scale", Vector2(1.35, 1.35), 0.2 / _spd()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge_tween.parallel().tween_property(hero_pic, "modulate", Color(1.4, 1.25, 0.5), 0.2 / _spd())
	charge_tween.tween_interval(0.12 / _spd())
	charge_tween.tween_property(hero_pic, "scale", Vector2.ONE, 0.15 / _spd())
	charge_tween.parallel().tween_property(hero_pic, "modulate", Color.WHITE, 0.15 / _spd())
	await charge_tween.finished

	# 3. Calculate Attack & Final Damage
	var atk_result = _main.compute_attack()
	var dmg = atk_result["dmg"]
	if dmg <= 0: dmg = 1

	_main.msg_label.text = "🔥"
	var enemy_center = enemy_pic.global_position + enemy_pic.size * 0.5

	_main.fire_laser_beam(_main.beam_line, hero_center, enemy_center, Color(1.0, 0.78, 0.25), 24.0, 0.28)
	await _timer(0.08)

	# 4. Enemy takes damage
	_main.enemy_hp = maxi(0, _main.enemy_hp - dmg)
	_main.enemy_hp_label.text = "HP %d / %d" % [_main.enemy_hp, _main.enemy_max_hp]
	_ct().tween_property(_main.enemy_hp_bar, "value", float(_main.enemy_hp), 0.35 / _spd())

	_main.shake_node(enemy_pic, 18.0, 0.42)
	enemy_pic.modulate = Color(1.6, 0.2, 0.2)
	_ct().tween_property(enemy_pic, "modulate", Color.WHITE, 0.25 / _spd())

	_main.spawn_damage_number("-%d" % dmg, enemy_center, Color("#ff4d5e"), true)
	await _timer(0.6)

	if _main.enemy_hp <= 0:
		_main.on_victory()
	else:
		_enemy_counter_attack()


# ---------------------------------------------------------------------------
# Enemy counter-attack sequence
# ---------------------------------------------------------------------------

func _enemy_counter_attack() -> void:
	var enemy_pic = _main.enemy_pic
	var hero_pic  = _main.hero_pic

	_main.msg_label.text = "ศัตรูโจมตี!"

	var enemy_center = enemy_pic.global_position + enemy_pic.size * 0.5
	var hero_center  = hero_pic.global_position + hero_pic.size * 0.5

	# 1. Enemy lunges forward
	enemy_pic.pivot_offset = enemy_pic.size * 0.5
	var orig_pos = enemy_pic.position
	var lunge_tween = _ct()
	lunge_tween.tween_property(enemy_pic, "position:x", orig_pos.x - 35.0, 0.16 / _spd()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(enemy_pic, "position:x", orig_pos.x, 0.14 / _spd())

	await _timer(0.18)

	# 2. Enemy fires counter-attack beam
	_main.fire_laser_beam(_main.enemy_beam_line, enemy_center, hero_center, Color(0.9, 0.25, 0.95), 22.0, 0.28)
	await _timer(0.08)

	# 3. Hero HP tied to walks_left
	_main.player_hp = _main.enemy_atk * _main.walks_left
	_main.hero_hp_label.text = "HP %d / %d" % [_main.player_hp, _main.player_max_hp]
	_ct().tween_property(_main.hero_hp_bar, "value", float(_main.player_hp), 0.3 / _spd())

	_main.shake_node(hero_pic, 15.0, 0.38)
	hero_pic.modulate = Color.RED
	_ct().tween_property(hero_pic, "modulate", Color.WHITE, 0.25 / _spd())

	_main.spawn_damage_number("-%d" % _main.enemy_atk, hero_center, Color("#ff3355"), true)
	await _timer(0.5)

	# 4. Check defeat
	if _main.walks_left <= 0 or _main.player_hp <= 0:
		_main.on_game_over()
	else:
		_main.is_busy = false
		_main.msg_label.text = ""
		_main.start_new_round()

