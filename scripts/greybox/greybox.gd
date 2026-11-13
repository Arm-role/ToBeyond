extends Control
## Domino Run greybox (docs/plan-domino-run.md, phase 1). Self-contained: no
## Artifacts, red/blue Gems, one enemy after another, real HP on both sides.
## Open with ?mode=greybox (web) or -- --mode=greybox.

const N := 8
const HAND_SIZE := 3
const RED_DMG := 4
const BLUE_BLOCK := 3
const TILE := 190.0
const GAP := 14.0
const ROW_Y := 400.0
const COL := {"red": Color("#e5484d"), "blue": Color("#2f7fd6")}

var sfx: Node
var hp: float = 30.0
var max_hp: float = 30.0
var stage: int = 1
var enemy_hp: int = 0
var enemy_max: int = 18
var strike_dmg: float = 8.0
var strike_tile: int = 4
var hand: Array[String] = []        # "" = slot already placed
var board: Dictionary = {}          # tile -> colour
var selected: int = -1
var busy: bool = false
var over: bool = false

var tile_btns: Array[Button] = []
var hand_btns: Array[Button] = []
var fire: Label
var flag: Label
var stage_lbl: Label
var enemy_lbl: Label
var enemy_bar: ProgressBar
var intent_lbl: Label
var hp_lbl: Label
var hp_bar: ProgressBar
var msg: Label
var go_btn: Button


func _ready() -> void:
	sfx = preload("res://scripts/sfx_manager.gd").new()
	add_child(sfx)
	_build()
	_new_enemy()
	_new_turn()


func _label(text: String, size: int, pos: Vector2, w: float = 600.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.size = Vector2(w, size * 1.6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _bar(pos: Vector2, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(600, 26)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("fill", fill)
	add_child(b)
	return b


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#171320")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage_lbl = _label("", 34, Vector2(660, 20))
	enemy_lbl = _label("", 40, Vector2(660, 70))
	enemy_bar = _bar(Vector2(660, 130), Color("#c0392b"))
	intent_lbl = _label("", 34, Vector2(660, 170))
	var x0 := (1920.0 - (N * TILE + (N - 1) * GAP)) * 0.5
	for i in N:
		var b := Button.new()
		b.position = Vector2(x0 + i * (TILE + GAP), ROW_Y)
		b.size = Vector2(TILE, TILE)
		b.pivot_offset = b.size * 0.5
		b.add_theme_font_size_override("font_size", 46)
		b.pressed.connect(_on_tile.bind(i))
		add_child(b)
		tile_btns.append(b)
		var n := Label.new()
		n.text = str(i + 1)
		n.modulate = Color(1, 1, 1, 0.35)
		n.position = Vector2(8, 4)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
	flag = Label.new()
	flag.text = "⚔"
	flag.add_theme_font_size_override("font_size", 72)
	flag.size = Vector2(TILE, 90)
	flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(flag)
	fire = Label.new()
	fire.text = "🔥"
	fire.add_theme_font_size_override("font_size", 80)
	fire.size = Vector2(TILE, 100)
	fire.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire.visible = false
	fire.z_index = 10
	add_child(fire)
	for i in HAND_SIZE:
		var h := Button.new()
		h.position = Vector2(660 + i * 210, 700)
		h.size = Vector2(190, 190)
		h.add_theme_font_size_override("font_size", 46)
		h.pressed.connect(_on_hand.bind(i))
		add_child(h)
		hand_btns.append(h)
	go_btn = Button.new()
	go_btn.text = "เดิน ▶"
	go_btn.position = Vector2(1320, 740)
	go_btn.size = Vector2(300, 110)
	go_btn.add_theme_font_size_override("font_size", 44)
	go_btn.pressed.connect(_on_go)
	add_child(go_btn)
	hp_bar = _bar(Vector2(660, 930), Color("#2fa866"))
	hp_lbl = _label("", 34, Vector2(660, 960))
	msg = _label("", 36, Vector2(460, 620), 1000.0)


func _new_enemy() -> void:
	enemy_hp = enemy_max
	strike_tile = randi_range(2, 7) - 1


func _new_turn() -> void:
	hand.clear()
	for i in HAND_SIZE:
		hand.append("red" if randf() < 0.6 else "blue")
	board.clear()
	selected = -1
	strike_tile = randi_range(1, N - 1)
	busy = false
	msg.text = ""
	_refresh()


func _gem_text(c: String) -> String:
	return "⚔ %d" % RED_DMG if c == "red" else "🛡 %d" % BLUE_BLOCK


func _style(b: Button, c: String, picked: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL[c] if c != "" else Color("#2a2438")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(6 if picked else 2)
	sb.border_color = Color("#ffd966") if picked else Color(1, 1, 1, 0.25)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)


func _refresh() -> void:
	stage_lbl.text = "ด่าน %d" % stage
	enemy_lbl.text = "👹 HP %d / %d" % [maxi(enemy_hp, 0), enemy_max]
	enemy_bar.max_value = enemy_max
	enemy_bar.value = maxi(enemy_hp, 0)
	intent_lbl.text = "ตีแรง %d ที่ช่อง %d" % [roundi(strike_dmg), strike_tile + 1]
	hp_lbl.text = "HP %d / %d" % [roundi(maxf(hp, 0.0)), roundi(max_hp)]
	hp_bar.max_value = max_hp
	hp_bar.value = maxf(hp, 0.0)
	for i in N:
		var c: String = board.get(i, "")
		tile_btns[i].text = _gem_text(c) if c != "" else ""
		_style(tile_btns[i], c)
	for i in HAND_SIZE:
		var c: String = hand[i]
		hand_btns[i].text = _gem_text(c) if c != "" else ""
		hand_btns[i].disabled = c == "" or busy
		_style(hand_btns[i], c, i == selected)
	flag.position = Vector2(tile_btns[strike_tile].position.x, ROW_Y - 100.0)
	go_btn.disabled = busy or over or board.is_empty()


func _on_hand(i: int) -> void:
	if busy or hand[i] == "":
		return
	selected = -1 if selected == i else i
	sfx.play("place", 1.2, -8.0)
	_refresh()


func _on_tile(t: int) -> void:
	if busy or over:
		return
	if board.has(t):
		# Take the Gem back to its hand slot.
		for i in HAND_SIZE:
			if hand[i] == "":
				hand[i] = board[t]
				board.erase(t)
				break
	elif selected >= 0:
		board[t] = hand[selected]
		hand[selected] = ""
		selected = -1
		sfx.play("place")
		_pop(tile_btns[t], 1.15)
	_refresh()


func _pop(b: Control, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.07)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12)


func _float_text(text: String, at: Vector2, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.position = at
	l.z_index = 20
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", at.y - 90.0, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for k in 5:
		tw.tween_property(self, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)


func _on_go() -> void:
	if busy or over or board.is_empty():
		return
	busy = true
	selected = -1
	_refresh()
	_run()


func _run() -> void:
	var block := 0
	var pops := 0
	fire.visible = true
	for t in N:
		var dur: float = lerpf(0.20, 0.07, float(t) / float(N - 1))
		var tw := create_tween()
		tw.tween_property(fire, "position", Vector2(tile_btns[t].position.x, ROW_Y - 20.0), dur)
		await tw.finished
		if board.has(t):
			var c: String = board[t]
			var centre := tile_btns[t].position + Vector2(40, 0)
			sfx.step(pops)
			pops += 1
			_pop(tile_btns[t], 1.3)
			if c == "red":
				enemy_hp -= RED_DMG
				_float_text("-%d" % RED_DMG, centre, COL["red"])
				_refresh()
				if enemy_hp <= 0:
					await _win()
					return
			else:
				block += BLUE_BLOCK
				_float_text("🛡+%d" % BLUE_BLOCK, centre, Color("#7fb8ff"))
		if t == strike_tile:
			var dmg := maxf(0.0, strike_dmg - block)
			var centre2 := tile_btns[t].position + Vector2(40, 0)
			if dmg > 0.0:
				hp -= dmg
				sfx.play("hurt")
				_shake(14.0)
				_float_text("-%d" % roundi(dmg), centre2, Color("#ff4d5e"))
			else:
				sfx.play("chime", 1.5)
				_float_text("กันได้!", centre2, Color("#7fb8ff"))
			block = 0
			_refresh()
			await get_tree().create_timer(0.3).timeout
			if hp <= 0.0:
				_lose()
				return
	fire.visible = false
	await get_tree().create_timer(0.35).timeout
	_new_turn()


func _win() -> void:
	fire.visible = false
	sfx.play("win")
	msg.text = "ชนะด่าน %d!" % stage
	await get_tree().create_timer(1.1).timeout
	stage += 1
	enemy_max = roundi(enemy_max * 1.25)
	strike_dmg *= 1.15
	hp = minf(max_hp, hp + max_hp * 0.4)
	_new_enemy()
	_new_turn()


func _lose() -> void:
	over = true
	fire.visible = false
	sfx.play("lose")
	msg.text = "แพ้ที่ด่าน %d · แตะเพื่อเริ่มใหม่" % stage
	var b := Button.new()
	b.text = "เริ่มใหม่"
	b.position = Vector2(810, 700)
	b.size = Vector2(300, 100)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(b)
