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

const HIT_FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")

## Flash the node white for a moment (assets/shaders/hit_flash.gdshader).
func _hit_flash(node: CanvasItem, color: Color = Color.WHITE, dur: float = 0.22) -> void:
	var mat := node.material as ShaderMaterial
	if mat == null or mat.shader != HIT_FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = HIT_FLASH_SHADER
		node.material = mat
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 1.0)
	_ct().tween_property(mat, "shader_parameter/flash", 0.0, dur / _spd()).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _timer(sec: float) -> Signal:
	return _main.get_tree().create_timer(sec / _main.speed_multiplier).timeout

func _spd() -> float:
	return _main.speed_multiplier


# ---------------------------------------------------------------------------
# Public entry point — called from main._on_walk_pressed()
# ---------------------------------------------------------------------------

var _step_i: int = 0


func run_walk() -> void:
	_step_i = 0
	_main.walks_left -= 1
	_main.is_busy = true
	_main.begin_walk_damage()
	_main.update_all_ui()
	_main.msg_label.text = "กำลังเดิน..."

	var token: Control          = _main.token
	var tiles_container         = _main.tiles_container
	token.visible = true
	var tween = _ct()
	# Draft: one stop every 500 ms (0.45 s slide + short pause).
	var step_duration = 0.45 / _spd()

	var walk_steps: Array[Dictionary] = build_walk_steps()
	for step in walk_steps:
		var idx: int = step["tile"]
		var helper_pass: bool = step["helper"]
		var tile_btn = tiles_container.get_child(idx) as Button
		# Derive the token position from the actual tile instead of fixed 1280px
		# offsets. This remains correct at the 1920 canvas and when scaled.
		var target_pos = tile_btn.position + (tile_btn.size - token.size) * 0.5
		tween.tween_property(token, "position", target_pos, step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_visit_tile.bind(idx, helper_pass))
		var step_card = _main.placed_cards.get(idx)
		if step_card != null and step_card.get("gold", false) and not step_card.get("is_blank", false):
			# Gold Gem: a visible second beat where its landing effects trigger again.
			tween.tween_interval(0.32 / _spd())
			tween.tween_callback(_retrigger_gold.bind(idx, helper_pass))
		if str(step.get("fx", "")) != "":
			tween.tween_callback(_artifact_pop.bind(_main.artifact_slot(str(step["fx"])), 0))
		tween.tween_interval(0.05 / _spd())

	tween.finished.connect(_on_walk_finished)


## Every stop of one walk, in order: {"tile", "helper", "fx"}.
## Helper passes come first, then the fireball (with the way back for Mirror Walk).
func build_walk_steps() -> Array[Dictionary]:
	var placed_cards: Dictionary = _main.placed_cards
	var N_TILES: int = _main.N_TILES
	# Collect stops (Tile 0 + all cards + Chaos crystals + Totems)
	var active_tiles: Array[int] = [0]
	for i in range(1, N_TILES):
		if placed_cards.has(i) or _main.chaos_crystals.has(i) or _main.totem_tiles.has(i):
			active_tiles.append(i)

	var forward_tiles: Array[int] = active_tiles.duplicate()
	var back_type: String = _main.artifact_sys.rule_type(&"walk_back")
	if back_type != "" and active_tiles.size() > 1:
		var rev = active_tiles.duplicate()
		rev.reverse()
		rev.pop_front()
		for idx in rev:
			active_tiles.append(idx)

	# Odd/Even helpers take their own pass before the fireball. Their pass
	# triggers landing effects but intentionally does not consume First Strike.
	var walk_steps: Array[Dictionary] = []
	for helper_rule in [&"helper_odd", &"helper_even"]:
		var helper_type: String = _main.artifact_sys.rule_type(helper_rule)
		if helper_type == "":
			continue
		var wants_odd: bool = helper_rule == &"helper_odd"
		var first_helper_step := true
		for tile_idx in forward_tiles:
			if ((tile_idx + 1) % 2 == 1) == wants_odd:
				walk_steps.append({"tile": tile_idx, "helper": true, "fx": helper_type if first_helper_step else ""})
				first_helper_step = false
	for k in range(active_tiles.size()):
		# The first stop after the last forward tile is where the ball turns back.
		walk_steps.append({"tile": active_tiles[k], "helper": false, "fx": back_type if (k == forward_tiles.size() and k > 0) else ""})

	return walk_steps


func _visit_tile(tile_idx: int, helper_pass: bool) -> void:
	if _main.placed_cards.has(tile_idx) or _main.totem_tiles.has(tile_idx) or _main.chaos_crystals.has(tile_idx):
		_main.sfx.step(_step_i)
		var tile_ctl := _main.tiles_container.get_child(tile_idx) as Control
		_trigger_fx(tile_ctl.global_position + tile_ctl.size * 0.5, _card_fx_color(tile_idx), _step_i)
		_step_i += 1
	if _main.placed_cards.has(tile_idx):
		_spawn_tile_popup(tile_idx, helper_pass)
	if _main.totem_tiles.has(tile_idx):
		_hit_totem(tile_idx)
	if _main.chaos_crystals.has(tile_idx):
		_hit_crystal(tile_idx)


# ---------------------------------------------------------------------------
# Internal: popup "+N ATK" above a tile during walk
# ---------------------------------------------------------------------------

## Gold Gem (Chaos Goldify): its landing effects resolve a second time, with its own
## gold flash, chime and "⭐+N" popup so the retrigger is visible.
func _retrigger_gold(tile_idx: int, helper_pass: bool) -> void:
	var tile_ctl := _main.tiles_container.get_child(tile_idx) as Control
	_main.sfx.step(_step_i)
	_trigger_fx(tile_ctl.global_position + tile_ctl.size * 0.5, Color("#ffd24a"), _step_i + 2)
	_step_i += 1
	_spawn_tile_popup(tile_idx, helper_pass, true)


func _spawn_tile_popup(tile_idx: int, helper_pass: bool = false, repeat: bool = false) -> void:
	var tiles_container  = _main.tiles_container
	var effects_layer    = _main.effects_layer
	var placed_cards     = _main.placed_cards

	var tile_btn = tiles_container.get_child(tile_idx) as Button
	var card = placed_cards.get(tile_idx)
	if card == null: return

	var applied = _main.apply_tile_walk_effects(tile_idx, helper_pass)
	var gain = int(applied["gain"])
	var fired: Array = applied.get("fired", []).duplicate()
	var coin_won: bool = applied.get("coin_won", false)
	for t in fired:
		_artifact_pop(_main.artifact_slot(t), _step_i)
	if fired.has("greenCoin"):
		# Draft: "+1 🪙" in gold when the coin drops, a grey ✗ when it doesn't.
		_main.spawn_damage_number("+1 🪙" if coin_won else "✗", tile_btn.global_position + Vector2(tile_btn.size.x * 0.5, 0.0), Color("#f2c230") if coin_won else Color("#8a86a8"), false)
	if gain > 0 and not card.get("is_blank", false):
		if repeat:
			_tile_pop(tile_idx, "⭐+%d" % gain, Color("#f2b63c"))
			_hit_flash(tile_btn, Color("#ffd24a"))
			VfxManager.trigger_juice(tile_btn, _spd(), 1.25, 8.0)
		else:
			_tile_pop(tile_idx, "+%d" % gain)
			VfxManager.trigger_juice(tile_btn, _spd(), 1.15, 6.0)

	if int(applied["extra"]) > 0:
		_main.spawn_damage_number("+%d" % int(applied["extra"]), tile_btn.global_position + tile_btn.size * 0.5, Color("#ffd966"), false)
	_main.refresh_calc()
	if gain > 0 or int(applied["extra"]) > 0:
		VfxManager.trigger_juice(_main.calc_label, _spd(), 1.1, 3.0, 0.0)


## After the walk, before the Artifacts: every Gem still in the hand that carries
## a buff triggers in hand order (card["buffs"] = {type: amount}), twice for a gold
## Gem; Gems already placed on tiles do not. No buffed Gem = no delay.
func _trigger_gem_buffs() -> void:
	var k := 0
	for idx in _main.hand.size():
		var card: Dictionary = _main.hand[idx]
		if card.get("is_blank", false):
			continue
		var buffs: Dictionary = card.get("buffs", {})
		# A gold Gem retriggers everything it does: its buff triggers twice.
		var reps: int = 2 if card.get("gold", false) else 1
		for type in buffs:
			var amount: int = int(buffs[type])
			if amount <= 0 or idx >= _main.hand_container.get_child_count():
				continue
			var card_ctl := _main.hand_container.get_child(idx) as Control
			for rep in reps:
				var fx_col := Color("#ffd24a") if rep > 0 else Color("#c79bff")
				match type:
					"mult":
						_main.walk_mult_bonus += amount
						_pop_at(card_ctl, ("⭐" if rep > 0 else "") + "MULT +%d" % amount, Color("#f2b63c") if rep > 0 else Color("#c79bff"))
				_trigger_fx(card_ctl.global_position + card_ctl.size * 0.5, fx_col, k)
				VfxManager.trigger_juice(card_ctl, _spd(), 1.15, 6.0)
				_main.sfx.play("chime", pow(2.0, float([0, 2, 4, 7, 9, 12, 14][clampi(k, 0, 6)]) / 12.0), -3.0)
				_main.refresh_calc()
				VfxManager.trigger_juice(_main.calc_label, _spd(), 1.1, 3.0, 0.0)
				k += 1
				await _timer(0.45)


## Draft `.spop`: big blue number with a white glow above the tile,
## pops to ×1.25 then drifts up and fades (0.9 s).
func _tile_pop(tile_idx: int, text: String, col: Color = Color("#1f7ae0")) -> void:
	_pop_at(_main.tiles_container.get_child(tile_idx) as Control, text, col)


func _pop_at(tile_btn: Control, text: String, col: Color = Color("#1f7ae0")) -> void:
	var layer: Control = _main.effects_layer
	var pop := Label.new()
	pop.text = text
	pop.theme_type_variation = &"BoldLabel"
	pop.add_theme_font_size_override("font_size", 74 if text.length() <= 4 else 44)
	pop.add_theme_color_override("font_color", col)
	pop.add_theme_color_override("font_outline_color", Color.WHITE)
	pop.add_theme_constant_override("outline_size", 9)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.z_index = 60
	layer.add_child(pop)
	var box := Vector2(320, 100)
	var center: Vector2 = layer.get_global_transform().affine_inverse() * (tile_btn.global_position + Vector2(tile_btn.size.x * 0.5, tile_btn.size.y * 0.42))
	pop.size = box
	pop.pivot_offset = box * 0.5
	pop.position = center - box * 0.5
	pop.scale = Vector2(0.6, 0.6)
	pop.modulate.a = 0.0
	var total := 0.9 / _spd()
	var t := _ct().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(pop, "scale", Vector2(1.25, 1.25), total * 0.2)
	t.parallel().tween_property(pop, "modulate:a", 1.0, total * 0.2)
	t.parallel().tween_property(pop, "position:y", pop.position.y - 9.0, total * 0.2)
	t.tween_property(pop, "scale", Vector2.ONE, total * 0.8)
	t.parallel().tween_property(pop, "modulate:a", 0.0, total * 0.8)
	t.parallel().tween_property(pop, "position:y", pop.position.y - 33.0, total * 0.8)
	t.tween_callback(pop.queue_free)


const FX_COLORS := {"red": "#ff6b6b", "green": "#5af08a", "orange": "#ffb04a", "blue": "#6fb8ff"}


func _card_fx_color(tile_idx: int) -> Color:
	var card = _main.placed_cards.get(tile_idx)
	if card == null:
		return Color("#ffe27a")  # totem / crystal
	return Color(FX_COLORS.get(str(card.get("color", "")), "#ffffff"))


## A card/totem/crystal triggers as the token passes: a bright flash, a ring of
## sparks in the card's colour, and a few white glints. Bigger as the combo grows.
func _trigger_fx(at: Vector2, col: Color, combo: int) -> void:
	var layer: Control = _main.effects_layer
	var k := mini(combo, 8)
	VfxManager.burst_particles(layer, at, Color(1, 1, 0.9, 0.4), 3, 30.0, 0.25, 1.2 + 0.05 * k, 0.0, col, _spd())  # soft flash
	# solid sparks (normal blend so they read on bright cards), then additive glints
	VfxManager.burst_particles(layer, at, col, 22 + 2 * k, 400.0 + 25.0 * k, 0.9, 0.9, 220.0, col.lightened(0.55), _spd(), false, true)
	VfxManager.burst_particles(layer, at, Color.WHITE, 8, 520.0, 0.5, 0.7, 0.0, col, _spd())


## An artifact takes effect: the card bounces and glows (flash_artifact) and
## throws sparks in its own colour.
func _artifact_fx(slot: int, combo: int) -> void:
	if slot < 0 or slot + 1 >= _main.artifact_row.get_child_count():
		return
	_main.flash_artifact(slot)
	var ctl := _main.artifact_row.get_child(slot + 1) as Control
	var art = _main.artifacts[slot]
	var col: Color = Color("#ffd966")
	if art != null and art.get("color") is Color:
		col = (art["color"] as Color).lightened(0.3)
	_trigger_fx(ctl.global_position + ctl.size * 0.5, col, combo + 2)


## Landing artifact during the walk: fx plus a soft chime.
func _artifact_pop(slot: int, combo: int) -> void:
	if slot < 0:
		return
	_artifact_fx(slot, combo)
	_main.sfx.play("chime", pow(2.0, float([0, 2, 4, 7, 9, 12, 14][clampi(combo, 0, 6)]) / 12.0), -3.0)


## Flash several artifacts one after another (counters grew, Chaos given, coins paid...).
func fx_artifact_types(types: Array) -> void:
	var k := 0
	for t in types:
		var slot: int = _main.artifact_slot(str(t))
		if slot < 0:
			continue
		_artifact_pop(slot, k)
		k += 1
		await _timer(0.18)


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
	_artifact_pop(_main.artifact_slot(_main.artifact_sys.rule_type(&"totem")), _step_i)
	_tile_pop(tile_idx, "🗿+%d" % gain, Color("#7fd0ff"))
	_main.refresh_calc()


# ---------------------------------------------------------------------------
# Walk finished → hero charges → fires beam → enemy takes damage
# ---------------------------------------------------------------------------

func _on_walk_finished() -> void:
	var token: Control = _main.token
	var hero_pic: Control = _main.hero_pic
	var enemy_pic: Control = _main.enemy_pic
	var layer: Control = _main.effects_layer

	# 0. Artifacts resolve one by one (draft attackSeq()): the calc shows the raw
	#    walk total, then each artifact flashes and updates it, 450 ms apart.
	await _trigger_gem_buffs()
	var steps: Array = []
	_main.compute_attack(steps)
	_main.show_calc(steps[0]["atk"], steps[0]["mult"])
	await _timer(0.35)
	for i in range(1, steps.size()):
		_artifact_fx(int(steps[i]["slot"]), i - 1)
		_main.sfx.play("chime", pow(2.0, float([0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24][clampi(i - 1, 0, 10)]) / 12.0))
		_main.show_calc(steps[i]["atk"], steps[i]["mult"])
		VfxManager.trigger_juice(_main.calc_label, _spd(), 1.15, 4.0, 0.0)
		await _timer(0.45)
	# Final total: a bigger pop, tinted by how big the hit is compared with the enemy's HP.
	var pre_dmg: int = maxi(1, int(_main.compute_attack()["dmg"]))
	var ratio := float(pre_dmg) / float(maxi(1, _main.enemy_hp))
	var tier := 2 if ratio >= 1.0 else (1 if ratio >= 0.4 else 0)
	if steps.size() > 1 or tier > 0:
		VfxManager.trigger_juice(_main.calc_label, _spd(), 1.2 + 0.1 * tier, 3.0, 0.0)
	if tier > 0:
		_main.calc_label.modulate = Color("#ffd36b") if tier == 1 else Color("#ff8a50")
		_ct().tween_property(_main.calc_label, "modulate", Color.WHITE, 0.9 / _spd())
	# Every trigger has resolved: slam the total in big above the calc, hold a beat to read it.
	await _timer(0.2)
	_show_summary(pre_dmg, tier)
	await _timer(0.6 + 0.15 * tier)

	# 1. Fireball (draft strike()): cubic Bézier from the token to the hero —
	#    keeps heading right first, then curves in from below; 750 ms.
	_main.sfx.play("whoosh")
	_main.msg_label.text = "🔥"
	var p0: Vector2 = token.global_position + token.size * 0.5
	var p3: Vector2 = hero_pic.global_position + hero_pic.size * 0.5
	var L := maxf(1.0, p0.distance_to(p3))
	var c1 := p0 + Vector2(maxf(210.0, L * 0.5), 0.0)
	var c2 := p3 + Vector2(0.0, maxf(240.0, L * 0.5))
	token.pivot_offset = token.size * 0.5
	var trail := VfxManager.start_trail(layer, p0, Color("#fff1a8"), Color("#ff7a1f"))
	var fly := _ct()
	fly.tween_method(func(q: float):
		var e := pow(q, 1.6)
		var u := 1.0 - e
		var pos := u * u * u * p0 + 3.0 * u * u * e * c1 + 3.0 * u * e * e * c2 + e * e * e * p3
		var tan := 3.0 * u * u * (c1 - p0) + 6.0 * u * e * (c2 - c1) + 3.0 * e * e * (p3 - c2)
		token.global_position = pos - token.size * 0.5
		token.rotation = tan.angle()
		VfxManager.trail_move(trail, pos)
	, 0.0, 1.0, 0.75 / _spd())
	await fly.finished
	VfxManager.stop_trail(trail)
	token.visible = false
	token.rotation = 0.0
	token.position = Vector2(20.0, 26.0)
	_burst(p3)

	# 2. Hero casts (.hero.cast 0.7 s) inside a shrinking charge ring.
	_main.msg_label.text = "✨"
	_hero_cast(hero_pic)
	_charge_ring(p3)
	await _timer(0.7)

	# 3. Beam hero → enemy grows for 0.25 s, then a burst on the enemy.
	_main.msg_label.text = "🔥"
	var atk_result = _main.compute_attack()
	var dmg = atk_result["dmg"]
	if dmg <= 0: dmg = 1
	var enemy_center: Vector2 = enemy_pic.global_position + enemy_pic.size * 0.5
	_main.fire_laser_beam(_main.beam_line, p3, enemy_center, Color.WHITE, 15.0, 0.05)
	await _timer(0.3)
	_burst(enemy_center)
	_hide_summary()
	_main.msg_label.text = ""
	_main.sfx.play("hit", 1.0 - 0.18 * tier, 1.5 * tier)
	_hit_stop(tier)
	if tier > 0:
		_main.shake_node(_main, 7.0 + 6.0 * tier, 0.3, 0.0)

	# 4. Enemy takes damage and shakes (.enemy.hit).
	_main.enemy_hp = maxi(0, _main.enemy_hp - dmg)
	_main.enemy_hp_label.text = "HP %s / %s" % [_main.fmt_num(_main.enemy_hp), _main.fmt_num(_main.enemy_max_hp)]
	_ct().tween_property(_main.enemy_hp_bar, "value", float(_main.enemy_hp), 0.4 / _spd())
	_main.shake_node(enemy_pic, 18.0 * (1.0 + 0.35 * tier), 0.5)
	_hit_flash(enemy_pic)
	if _main.enemy_hp <= 0:
		VfxManager.burst_particles(layer, enemy_center, Color("#fff3b0"), 36, 520.0, 0.95, 0.8, 900.0, Color("#ff7a2e"), _spd())
		VfxManager.burst_particles(layer, enemy_center, Color("#ffffff"), 14, 300.0, 0.6, 0.5, 0.0, Color("#9fd0ff"), _spd())
		await _timer(0.35)
		_ct().tween_property(enemy_pic, "modulate:a", 0.0, 0.5 / _spd())
		await _timer(0.55)
		_main.msg_label.text = "ชนะ!"
		_main.sfx.play("win")
		await _timer(0.7)
		_main.on_victory()
	else:
		await _timer(0.9)
		_enemy_counter_attack()


## Big total above the live calc: slams in from ×2.4 with overshoot, tinted by hit tier.
func _show_summary(total: int, tier: int) -> void:
	var lbl: Label = _main.summary_label
	lbl.text = _main.fmt_num(total)
	lbl.visible = true
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(2.4, 2.4)
	lbl.rotation = deg_to_rad(-4.0)
	lbl.modulate = Color(1, 1, 1, 0)
	var tint: Color = [Color.WHITE, Color("#ffd36b"), Color("#ff8a50")][tier]
	var t := _ct().set_parallel(true)
	t.tween_property(lbl, "modulate", tint, 0.08 / _spd())
	t.tween_property(lbl, "scale", Vector2.ONE, 0.3 / _spd()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "rotation", 0.0, 0.3 / _spd()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_main.sfx.play("chime", 1.0 + 0.25 * tier)
	_main.shake_node(_main.calc_label, 6.0 + 4.0 * tier, 0.25, 0.0)
	var ring_to: Vector2 = Vector2.ONE * (1.0 + 0.06 * tier)
	t.chain().tween_property(lbl, "scale", ring_to, 0.25 / _spd()).set_trans(Tween.TRANS_SINE)


## The total flies into the enemy with the beam: swell and fade out on impact.
func _hide_summary() -> void:
	var lbl: Label = _main.summary_label
	if not lbl.visible: return
	var t := _ct().set_parallel(true)
	t.tween_property(lbl, "scale", lbl.scale * 1.5, 0.3 / _spd()).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, 0.3 / _spd())
	t.chain().tween_callback(func(): lbl.visible = false)



## Brief freeze on impact (draft has none; makes hits feel heavy). Uses real
## time, so it can't get stuck even if the scene restarts.
func _hit_stop(tier: int) -> void:
	var dur: float = [0.03, 0.07, 0.12][tier]
	Engine.time_scale = 0.04
	await _main.get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0


func _burst(at_global: Vector2) -> void:
	# Draft `.burst`: radial glow 60 px that scales ×0.3 → ×3.2 and fades (0.45 s).
	var layer: Control = _main.effects_layer
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.72, 1.0])
	g.colors = PackedColorArray([Color("#fff6c0"), Color("#ffb22e"), Color(1.0, 0.31, 0.08, 0.0), Color(1.0, 0.31, 0.08, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(90, 90)
	r.pivot_offset = r.size * 0.5
	r.position = layer.get_global_transform().affine_inverse() * at_global - r.size * 0.5
	r.scale = Vector2(0.3, 0.3)
	r.z_index = 110
	layer.add_child(r)
	var t := _ct().set_ease(Tween.EASE_OUT)
	t.tween_property(r, "scale", Vector2(3.2, 3.2), 0.45 / _spd())
	t.parallel().tween_property(r, "modulate:a", 0.0, 0.45 / _spd())
	t.tween_callback(r.queue_free)


func _charge_ring(at_global: Vector2) -> void:
	# Draft `.charge`: 96 px gold ring, scale ×2.4 → ×0.3 (ease-in, 0.65 s).
	var layer: Control = _main.effects_layer
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.78, 0.35, 0.18)
	sb.border_color = Color("#ffd36a")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(72)
	sb.shadow_color = Color(1.0, 0.59, 0.16, 0.8)
	sb.shadow_size = 24
	ring.add_theme_stylebox_override("panel", sb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(144, 144)
	ring.pivot_offset = ring.size * 0.5
	ring.position = layer.get_global_transform().affine_inverse() * at_global - ring.size * 0.5
	ring.scale = Vector2(2.4, 2.4)
	ring.modulate.a = 0.0
	ring.z_index = 105
	layer.add_child(ring)
	var t := _ct().set_ease(Tween.EASE_IN)
	t.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.65 / _spd())
	t.parallel().tween_property(ring, "modulate:a", 1.0, 0.2 / _spd())
	t.tween_callback(ring.queue_free)


func _hero_cast(hero: Control) -> void:
	# Draft `@keyframes cast` (0.7 s): rise, grow to ×1.35, wobble ±7°, glow.
	hero.pivot_offset = hero.size * 0.5
	var y0 := hero.position.y
	var h := hero.size.y
	var d := 0.7 / _spd()
	var t := _ct().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hero, "position:y", y0 - h * 0.06, d * 0.25)
	t.parallel().tween_property(hero, "scale", Vector2(1.1, 1.1), d * 0.25)
	t.parallel().tween_property(hero, "rotation", deg_to_rad(-7), d * 0.25)
	t.tween_property(hero, "position:y", y0 - h * 0.12, d * 0.30)
	t.parallel().tween_property(hero, "scale", Vector2(1.3, 1.3), d * 0.30)
	t.parallel().tween_property(hero, "rotation", deg_to_rad(7), d * 0.30)
	t.parallel().tween_property(hero, "modulate", Color(1.35, 1.15, 0.7), d * 0.30)
	t.tween_property(hero, "position:y", y0 - h * 0.08, d * 0.25)
	t.parallel().tween_property(hero, "scale", Vector2(1.35, 1.35), d * 0.25)
	t.parallel().tween_property(hero, "rotation", 0.0, d * 0.25)
	t.tween_property(hero, "position:y", y0, d * 0.20)
	t.parallel().tween_property(hero, "scale", Vector2.ONE, d * 0.20)
	t.parallel().tween_property(hero, "modulate", Color.WHITE, d * 0.20)


func _hero_ouch(hero: Control) -> void:
	_main.sfx.play("hurt")
	# Draft `@keyframes ouch` (0.45 s): knocked back with a red flash.
	hero.pivot_offset = hero.size * 0.5
	var x0 := hero.position.x
	var d := 0.45 / _spd()
	var t := _ct()
	t.tween_property(hero, "position:x", x0 - 15.0, d * 0.2)
	t.parallel().tween_property(hero, "rotation", deg_to_rad(-8), d * 0.2)
	t.parallel().tween_property(hero, "modulate", Color(1.6, 0.45, 0.45), d * 0.2)
	t.tween_property(hero, "position:x", x0 + 12.0, d * 0.3)
	t.parallel().tween_property(hero, "rotation", deg_to_rad(5), d * 0.3)
	t.parallel().tween_property(hero, "modulate", Color.WHITE, d * 0.3)
	t.tween_property(hero, "position:x", x0 - 6.0, d * 0.25)
	t.parallel().tween_property(hero, "rotation", 0.0, d * 0.25)
	t.tween_property(hero, "position:x", x0, d * 0.25)


# ---------------------------------------------------------------------------
# Enemy counter-attack sequence (draft enemyStrike())
# ---------------------------------------------------------------------------

func _enemy_counter_attack() -> void:
	var enemy_pic: Control = _main.enemy_pic
	var hero_pic: Control = _main.hero_pic
	_main.msg_label.text = "ศัตรูโจมตี!"
	var enemy_center: Vector2 = enemy_pic.global_position + enemy_pic.size * 0.5
	var hero_center: Vector2 = hero_pic.global_position + hero_pic.size * 0.5

	# Lunge (0.35 s): forward 45 px and ×1.15 at 40 %.
	enemy_pic.pivot_offset = enemy_pic.size * 0.5
	var x0 := enemy_pic.position.x
	var lunge := _ct()
	lunge.tween_property(enemy_pic, "position:x", x0 - 45.0, 0.14 / _spd())
	lunge.parallel().tween_property(enemy_pic, "scale", Vector2(1.15, 1.15), 0.14 / _spd())
	lunge.tween_property(enemy_pic, "position:x", x0, 0.21 / _spd())
	lunge.parallel().tween_property(enemy_pic, "scale", Vector2.ONE, 0.21 / _spd())
	await _timer(0.25)

	_main.fire_laser_beam(_main.enemy_beam_line, enemy_center, hero_center, Color.WHITE, 15.0, 0.05)
	await _timer(0.3)

	var before: float = _main.player_hp
	# Real HP: each enemy hit removes enemy_atk (was atk * walks_left, a round counter).
	_main.player_hp = maxf(0.0, _main.player_hp - _main.enemy_atk)
	_main.spawn_damage_number("-%s" % _main.fmt_num(roundi(before - _main.player_hp)), hero_center, Color("#ff4d5e"), true)
	_hero_ouch(hero_pic)
	_main.hero_hp_label.text = "HP %s / %s" % [_main.fmt_num(roundi(_main.player_hp)), _main.fmt_num(roundi(_main.player_max_hp))]
	_ct().tween_property(_main.hero_hp_bar, "value", float(_main.player_hp), 0.4 / _spd())
	await _timer(0.55)

	if _main.walks_left <= 0 or _main.player_hp <= 0:
		_main.msg_label.text = ""
		_main.on_game_over()
	else:
		_main.is_busy = false
		_main.msg_label.text = ""
		_main.start_new_round()
