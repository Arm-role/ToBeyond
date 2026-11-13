extends Control
## Domino Run greybox (docs/plan-domino-run.md, phases 1-2). Self-contained.
## Red/blue Gems, one enemy after another, real HP on both sides. Three
## hard-coded Artifacts sit behind the toggles on the left (phase 2 test).
## Open with ?mode=greybox (web) or -- --mode=greybox.

const N := 8
const HAND_SIZE := 3
const RED_DMG := 4
const BLUE_BLOCK := 3
const TILE := 160.0
const GAP := 12.0
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

# Phase 2 artifacts (toggles): MIRROR bounces back at the last tile, COAL keeps
# popped Gems for one more walk, RIPOSTE reflects the strike off a blue Gem on the flag tile.
const ARTS := {
	"mirror": ["🪞 กำแพงกระจก", "ลูกไฟเด้งกลับที่ช่อง 8 ทุกอย่างป๊อปสองรอบ (ธงด้วย)"],
	"coal": ["♨ ถ่านไฟ", "Gem ที่ป๊อปแล้วอยู่ต่ออีกหนึ่งรอบ"],
	"riposte": ["↩ ตอบโต้", "Gem น้ำเงินบนช่องธง สะท้อนการตีกลับไปที่ศัตรู"],
}
var art_on: Dictionary = {"mirror": false, "coal": false, "riposte": false}
var locked: Dictionary = {}          # tiles holding a kept (coal) Gem
var art_btns: Dictionary = {}
var art_tip: Label

# Characters: staged beside the row. Reactions always tween to/from these fixed
# home positions (never relative), so rapid pops cannot make them drift.
const HERO_HOME := Vector2(60.0, 395.0)
const ENEMY_HOME := Vector2(1660.0, 395.0)
var hero: Label
var enemy: Label
var hero_hp_small: Label
var enemy_hp_small: Label
var badge: Label
var _react_tw: Dictionary = {}

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


func _char(emoji: String, home: Vector2) -> Label:
	var l := Label.new()
	l.text = emoji
	l.add_theme_font_size_override("font_size", 150)
	l.position = home
	l.size = Vector2(200, 190)
	l.pivot_offset = Vector2(100, 95)
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
	hero = _char("🧙", HERO_HOME)
	enemy = _char("👹", ENEMY_HOME)
	hero_hp_small = _label("", 34, HERO_HOME + Vector2(0, 190), 200.0)
	enemy_hp_small = _label("", 34, ENEMY_HOME + Vector2(0, 190), 200.0)
	badge = _label("", 52, HERO_HOME + Vector2(0, -75), 200.0)
	badge.visible = false
	badge.pivot_offset = Vector2(100, 40)
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
	var ay := 20.0
	for k in ARTS:
		var ab := Button.new()
		ab.toggle_mode = true
		ab.text = ARTS[k][0]
		ab.position = Vector2(30, ay)
		ab.size = Vector2(300, 80)
		ab.add_theme_font_size_override("font_size", 30)
		ab.toggled.connect(_on_art.bind(k))
		add_child(ab)
		art_btns[k] = ab
		ay += 95.0
	art_tip = _label("Artifact ทดสอบ (กดเปิด/ปิด)", 24, Vector2(1320, 30), 520.0)
	art_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	art_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_tip.size = Vector2(540, 160)
	hp_bar = _bar(Vector2(660, 930), Color("#2fa866"))
	hp_lbl = _label("", 34, Vector2(660, 960))
	msg = _label("", 36, Vector2(460, 620), 1000.0)


func _on_art(on: bool, key: String) -> void:
	art_on[key] = on
	art_tip.text = "%s\n%s" % [ARTS[key][0], ARTS[key][1]]
	sfx.play("place", 1.3, -8.0)


func _new_enemy() -> void:
	enemy_hp = enemy_max
	strike_tile = randi_range(2, 7) - 1


func _new_turn() -> void:
	hand.clear()
	for i in HAND_SIZE:
		hand.append("red" if randf() < 0.6 else "blue")
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
		tile_btns[i].text = (_gem_text(c) + ("\n♨" if locked.has(i) else "")) if c != "" else ""
		_style(tile_btns[i], c)
	for i in HAND_SIZE:
		var c: String = hand[i]
		hand_btns[i].text = _gem_text(c) if c != "" else ""
		hand_btns[i].disabled = c == "" or busy
		_style(hand_btns[i], c, i == selected)
	flag.position = Vector2(tile_btns[strike_tile].position.x, ROW_Y - 100.0)
	hero_hp_small.text = "%d" % roundi(maxf(hp, 0.0))
	enemy_hp_small.text = "%d" % maxi(enemy_hp, 0)
	go_btn.disabled = busy or over or board.is_empty()
	for k in art_btns:
		art_btns[k].disabled = busy


func _on_hand(i: int) -> void:
	if busy or hand[i] == "":
		return
	selected = -1 if selected == i else i
	sfx.play("place", 1.2, -8.0)
	_refresh()


func _on_tile(t: int) -> void:
	if busy or over:
		return
	if locked.has(t):
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


## A character reacts: knocked sideways by `dx`, flashed `tint`, scaled `s`, then
## back to its fixed home. Kills the previous reaction on that node; never awaited.
func _react(node: Control, home: Vector2, dx: float, tint: Color, s: float = 1.0) -> void:
	if _react_tw.has(node) and _react_tw[node].is_valid():
		_react_tw[node].kill()
	node.position = home
	node.scale = Vector2.ONE
	node.rotation = 0.0
	node.modulate = tint
	var tw := create_tween()
	_react_tw[node] = tw
	tw.tween_property(node, "position:x", home.x + dx, 0.05)
	tw.parallel().tween_property(node, "scale", Vector2(s, s), 0.05)
	tw.parallel().tween_property(node, "modulate", Color.WHITE, 0.15)
	tw.tween_property(node, "position:x", home.x, 0.10)
	tw.parallel().tween_property(node, "scale", Vector2.ONE, 0.10)


## The enemy leans back while the fireball is on its way to the flag tile.
func _windup() -> void:
	if _react_tw.has(enemy) and _react_tw[enemy].is_valid():
		_react_tw[enemy].kill()
	enemy.position = ENEMY_HOME
	var tw := create_tween()
	_react_tw[enemy] = tw
	tw.tween_property(enemy, "scale", Vector2(1.12, 1.12), 0.06)
	tw.parallel().tween_property(enemy, "rotation", deg_to_rad(8.0), 0.06)
	var ft := create_tween()
	ft.tween_property(flag, "scale", Vector2(1.3, 1.3), 0.06)
	ft.tween_property(flag, "scale", Vector2.ONE, 0.10)


func _badge(block: int) -> void:
	if _react_tw.has(badge) and _react_tw[badge].is_valid():
		_react_tw[badge].kill()
	badge.modulate = Color.WHITE
	badge.scale = Vector2.ONE
	badge.visible = block > 0
	badge.text = "🛡%d" % block
	if block > 0:
		var tw := create_tween()
		_react_tw[badge] = tw
		tw.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.05)
		tw.tween_property(badge, "scale", Vector2.ONE, 0.08)


func _badge_break() -> void:
	if not badge.visible:
		return
	if _react_tw.has(badge) and _react_tw[badge].is_valid():
		_react_tw[badge].kill()
	var tw := create_tween()
	_react_tw[badge] = tw
	tw.tween_property(badge, "scale", Vector2(1.5, 1.5), 0.12)
	tw.parallel().tween_property(badge, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): badge.visible = false)


## A ⚔ flies from the flag tile to the hero (hit / blocked) or the enemy (riposte).
func _strike_fx(t: int, kind: String) -> void:
	var l := Label.new()
	l.text = "⚔"
	l.add_theme_font_size_override("font_size", 80)
	l.position = tile_btns[t].position + Vector2(TILE * 0.5 - 40.0, -60.0)
	l.z_index = 15
	if kind == "riposte":
		l.modulate = Color("#ffd966")
	add_child(l)
	var target: Vector2 = enemy.position + Vector2(60, 30) if kind == "riposte" else HERO_HOME + Vector2(60, 30)
	var tw := create_tween()
	tw.tween_property(l, "position", target, 0.1)
	tw.tween_callback(l.queue_free)


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
	var seq: Array[int] = []
	for t in N:
		seq.append(t)
	if art_on["mirror"]:
		seq.append(N - 1)
		for t in range(N - 2, -1, -1):
			seq.append(t)
	var block := 0
	var pops := 0
	fire.position = Vector2(HERO_HOME.x + 20.0, ROW_Y - 20.0)
	fire.visible = true
	_badge(0)
	_react(hero, HERO_HOME, 0.0, Color.WHITE, 1.15)
	for k in seq.size():
		var t: int = seq[k]
		var dur: float = lerpf(0.20, 0.07, float(k) / float(maxi(seq.size() - 1, 1)))
		if k + 1 < seq.size() and seq[k + 1] == strike_tile:
			_windup()
		if k > 0 and seq[k - 1] == t:
			await get_tree().create_timer(0.08).timeout
		else:
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
				_react(enemy, ENEMY_HOME, 14.0, Color("#ff9a9a"))
				_float_text("-%d" % RED_DMG, ENEMY_HOME + Vector2(60, 0), COL["red"])
				_refresh()
				if enemy_hp <= 0:
					await _win()
					return
			else:
				block += BLUE_BLOCK
				_badge(block)
				_float_text("🛡+%d" % BLUE_BLOCK, centre, Color("#7fb8ff"))
		if t == strike_tile:
			if art_on["riposte"] and board.get(t, "") == "blue":
				# Riposte: the whole strike goes back at the enemy.
				enemy_hp -= roundi(strike_dmg)
				sfx.play("hit")
				_shake(10.0)
				_strike_fx(t, "riposte")
				_react(enemy, ENEMY_HOME, 24.0, Color("#ffe08a"), 1.1)
				_float_text("↩ -%d" % roundi(strike_dmg), ENEMY_HOME + Vector2(40, 0), Color("#ffd966"))
				_refresh()
				if enemy_hp <= 0:
					await _win()
					return
			else:
				var dmg := maxf(0.0, strike_dmg - block)
				_react(enemy, ENEMY_HOME, 0.0, Color.WHITE)   # end of the windup lean
				if dmg > 0.0:
					hp -= dmg
					sfx.play("hurt")
					_shake(14.0)
					_strike_fx(t, "hit")
					_react(hero, HERO_HOME, -14.0, Color("#ff6b6b"))
					_float_text("-%d" % roundi(dmg), HERO_HOME + Vector2(60, 0), Color("#ff4d5e"))
				else:
					sfx.play("chime", 1.5)
					_strike_fx(t, "blocked")
					_float_text("กันได้!", HERO_HOME + Vector2(20, 0), Color("#7fb8ff"))
			block = 0
			_badge_break()
			_refresh()
			await get_tree().create_timer(0.3).timeout
			if hp <= 0.0:
				_lose()
				return
	fire.visible = false
	await get_tree().create_timer(0.35).timeout
	_end_walk()
	_new_turn()


## After a walk: popped Gems are cleared, except Coal Bed keeps fresh ones for one more walk.
func _end_walk() -> void:
	var keep: Dictionary = {}
	if art_on["coal"]:
		for t in board:
			if not locked.has(t):
				keep[t] = board[t]
	board = keep
	locked = keep.duplicate()


func _win() -> void:
	fire.visible = false
	sfx.play("win")
	msg.text = "ชนะด่าน %d!" % stage
	await get_tree().create_timer(1.1).timeout
	stage += 1
	enemy_max = roundi(enemy_max * 1.25)
	strike_dmg *= 1.15
	hp = minf(max_hp, hp + max_hp * 0.4)
	board.clear()
	locked.clear()
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
