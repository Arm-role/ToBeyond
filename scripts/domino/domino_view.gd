extends Control
## Domino Run view (docs/domino/phase-3.md). All rules live in DominoSim; this
## node only draws: a walk is replayed from the sim's event list (_play_walk).
## HP, shield and the Gems on the row come from event fields during playback
## (v_* values), never from the sim's live state.
## Open with ?mode=greybox (web) or -- --mode=greybox.

const Sim := preload("res://scripts/domino/domino_sim.gd")
const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const N := Sim.N
const HAND_SIZE := Sim.HAND_SIZE
const TILE := 160.0
const GAP := 12.0
const ROW_Y := 650.0       # gameplay half starts at PREVIEW_H
const PREVIEW_H := 525.0   # top half: the fight preview (same split as the main game)
const COL := {"red": Color("#e5484d"), "blue": Color("#2f7fd6")}
const MAX_WALK_TIME := 2.2   # fireball travel budget per walk (strike pauses do not count)

var sim := Sim.new()
var sfx: Node
var stage: int = 1
# Shown values: synced from the sim between walks, set from event fields while a walk plays.
var v_hp: float = 30.0
var v_max_hp: float = 30.0
var v_enemy_hp: int = 0
var v_enemy_max: int = 18
var v_strike: float = 8.0
var v_flag: int = 3
var v_board: Dictionary = {}        # tile -> {color, kept, ...}
var hand: Array[String] = []        # "" = slot already placed
var selected: int = -1
var busy: bool = false
var over: bool = false

var art_btns: Dictionary = {}       # artifact id -> toggle button
var art_tip: Label

# Characters: staged beside the row. Reactions always tween to/from these fixed
# home positions (never relative), so rapid pops cannot make them drift.
const HERO_HOME := Vector2(260.0, 120.0)
const ENEMY_HOME := Vector2(1460.0, 120.0)
var hero: Label
var enemy: Label
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
	sim.rng.randomize()
	_build()
	sim.start_fight(1)
	_sync()
	_new_turn()
	if "--domino-smoke" in OS.get_cmdline_user_args():
		# Headless check (build.sh --check): catalog loads, a walk with every artifact runs.
		var t := Sim.new()
		t.start_fight(1)
		for d in Catalog.all():
			t.slots.append(d)
		t.place(0, "red")
		t.place(3, "blue")
		print("TB_DOMINO_OK artifacts=%d events=%d" % [Catalog.all().size(), t.run_walk().size()])
		get_tree().quit()


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


func _bar(pos: Vector2, col: Color, w: float = 600.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(w, 26)
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
	# Top half: fight preview. Bottom half: the game you play.
	var pv := Panel.new()
	pv.position = Vector2.ZERO
	pv.size = Vector2(1920, PREVIEW_H)
	var pvs := StyleBoxFlat.new()
	pvs.bg_color = Color("#241d3a")
	pvs.border_color = Color("#c9a24b")
	pvs.border_width_bottom = 5
	pv.add_theme_stylebox_override("panel", pvs)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pv)
	stage_lbl = _label("", 34, Vector2(660, 20))
	intent_lbl = _label("", 40, Vector2(660, 75))
	enemy_bar = _bar(ENEMY_HOME + Vector2(-80, 215), Color("#c0392b"), 360.0)
	enemy_lbl = _label("", 32, ENEMY_HOME + Vector2(-200, 245), 600.0)
	hp_bar = _bar(HERO_HOME + Vector2(-80, 215), Color("#2fa866"), 360.0)
	hp_lbl = _label("", 32, HERO_HOME + Vector2(-200, 245), 600.0)
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
		h.position = Vector2(660 + i * 210, 850)
		h.size = Vector2(190, 170)
		h.add_theme_font_size_override("font_size", 46)
		h.pressed.connect(_on_hand.bind(i))
		add_child(h)
		hand_btns.append(h)
	go_btn = Button.new()
	go_btn.text = "เดิน ▶"
	go_btn.position = Vector2(1320, 870)
	go_btn.size = Vector2(300, 110)
	go_btn.add_theme_font_size_override("font_size", 44)
	go_btn.pressed.connect(_on_go)
	add_child(go_btn)
	var ay := 560.0
	for d in Catalog.all():
		var ab := Button.new()
		ab.toggle_mode = true
		ab.text = "%s %s" % [d.icon, d.name_th]
		ab.position = Vector2(30, ay)
		ab.size = Vector2(230, 80)
		ab.add_theme_font_size_override("font_size", 26)
		ab.toggled.connect(_on_art.bind(d))
		add_child(ab)
		art_btns[d.id] = ab
		ay += 95.0
	art_tip = _label("Artifact ทดสอบ (กดเปิด/ปิด)", 24, Vector2(30, 850), 380.0)
	art_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	art_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_tip.size = Vector2(380, 160)
	msg = _label("", 40, Vector2(460, 230), 1000.0)


func _on_art(_on: bool, d: Resource) -> void:
	# Slots keep catalog order, left to right (the order artifacts react in).
	var owned: Array = []
	for a in Catalog.all():
		if art_btns[a.id].button_pressed:
			owned.append(a)
	sim.slots = owned
	art_tip.text = "%s %s\n%s" % [d.icon, d.name_th, d.text_th]
	sfx.play("place", 1.3, -8.0)


## Copies the sim's state to the shown values (between walks only).
func _sync() -> void:
	v_hp = sim.hp
	v_max_hp = sim.max_hp
	v_enemy_hp = sim.enemy_hp
	v_enemy_max = sim.enemy_max
	v_strike = sim.strike_dmg
	v_flag = sim.flags[0]
	v_board = sim.board.duplicate(true)


func _new_turn() -> void:
	hand = sim.deal_hand()
	selected = -1
	busy = false
	msg.text = ""
	_sync()
	_refresh()


func _gem_text(c: String) -> String:
	return "⚔ %d" % Sim.RED_DMG if c == "red" else "🛡 %d" % Sim.BLUE_BLOCK


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
	enemy_lbl.text = "👹 HP %d / %d" % [maxi(v_enemy_hp, 0), v_enemy_max]
	enemy_bar.max_value = v_enemy_max
	enemy_bar.value = maxi(v_enemy_hp, 0)
	intent_lbl.text = "ตีแรง %d ที่ช่อง %d" % [roundi(v_strike), v_flag + 1]
	hp_lbl.text = "HP %d / %d" % [roundi(maxf(v_hp, 0.0)), roundi(v_max_hp)]
	hp_bar.max_value = v_max_hp
	hp_bar.value = maxf(v_hp, 0.0)
	for i in N:
		var g: Dictionary = v_board.get(i, {})
		var c: String = g.get("color", "")
		tile_btns[i].text = (_gem_text(c) + ("\n♨" if g.get("kept", false) else "")) if c != "" else ""
		_style(tile_btns[i], c)
	for i in HAND_SIZE:
		var c: String = hand[i]
		hand_btns[i].text = _gem_text(c) if c != "" else ""
		hand_btns[i].disabled = c == "" or busy
		_style(hand_btns[i], c, i == selected)
	flag.position = Vector2(tile_btns[v_flag].position.x, ROW_Y - 100.0)
	go_btn.disabled = busy or over or sim.board.is_empty()
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
	if sim.board.has(t):
		# Take the Gem back to its hand slot (kept Gems stay).
		var c := sim.take(t)
		if c != "":
			for i in HAND_SIZE:
				if hand[i] == "":
					hand[i] = c
					break
	elif selected >= 0:
		sim.place(t, hand[selected])
		hand[selected] = ""
		selected = -1
		sfx.play("place")
		v_board = sim.board.duplicate(true)
		_pop(tile_btns[t], 1.15)
	v_board = sim.board.duplicate(true)
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


func _hero_c() -> Vector2:
	return HERO_HOME + Vector2(100, 95)


func _enemy_c() -> Vector2:
	return ENEMY_HOME + Vector2(100, 95)


## Laser beam like the main game's: a line that grows from `a` to `b`, then fades.
func _laser(a: Vector2, b: Vector2, col: Color, w: float = 15.0) -> void:
	var l := Line2D.new()
	l.default_color = col
	l.width = w
	l.z_index = 30
	l.add_point(a)
	l.add_point(a)
	add_child(l)
	var tw := create_tween()
	tw.tween_method(func(p: Vector2): l.set_point_position(1, p), a, b, 0.08)
	tw.tween_interval(0.03)
	tw.tween_property(l, "modulate:a", 0.0, 0.10)
	tw.tween_callback(l.queue_free)


## The strike lands: the enemy fires a laser at the hero (hit / blocked, the beam
## stops at the shield badge) or the hero returns it, gold, at the enemy (riposte).
func _strike_fx(_t: int, kind: String) -> void:
	if kind == "riposte":
		_laser(_hero_c(), _enemy_c(), Color("#ffd966"), 22.0)
	elif kind == "blocked":
		_laser(_enemy_c(), HERO_HOME + Vector2(100, 10), Color("#9fd0ff"), 15.0)
	else:
		_laser(_enemy_c(), _hero_c(), Color.WHITE, 15.0)


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
	if busy or over or sim.board.is_empty():
		return
	busy = true
	selected = -1
	v_board = sim.board.duplicate(true)   # the row as it was before the walk
	_refresh()
	var evs: Array = sim.run_walk()
	await _play_walk(evs)


## Index of the next `pass` event after j, or -1.
func _next_pass(evs: Array, j: int) -> int:
	for q in range(j + 1, evs.size()):
		if evs[q].k == "pass":
			return q
	return -1


## True when the walk strikes right after entering the tile of pass event p.
func _strike_after(evs: Array, p: int) -> bool:
	for q in range(p + 1, evs.size()):
		if evs[q].k == "pass":
			return false
		if evs[q].k == "strike":
			return true
	return false


func _play_walk(evs: Array) -> void:
	var steps := 0
	for ev in evs:
		if ev.k == "pass":
			steps += 1
	var step_dur: float = minf(0.20, MAX_WALK_TIME / float(maxi(steps, 1)))
	var seen := 0
	var prev_tile := -1
	var result := ""
	for j in evs.size():
		var ev: Dictionary = evs[j]
		match ev.k:
			"ignite":
				fire.position = Vector2(HERO_HOME.x + 20.0, ROW_Y - 20.0)
				fire.visible = true
				_badge(0)
				_react(hero, HERO_HOME, 0.0, Color.WHITE, 1.15)
			"pass":
				seen += 1
				var np := _next_pass(evs, j)
				if np >= 0 and _strike_after(evs, np):
					_windup()
				if ev.tile == prev_tile:
					await get_tree().create_timer(0.08).timeout   # bounce: enter the same tile again
				else:
					var dur: float = lerpf(step_dur, step_dur * 0.35, float(seen) / float(maxi(steps, 1)))
					var tw := create_tween()
					tw.tween_property(fire, "position", Vector2(tile_btns[ev.tile].position.x, ROW_Y - 20.0), dur)
					await tw.finished
				prev_tile = ev.tile
			"pop":
				sfx.step(ev.nth - 1)
				_pop(tile_btns[ev.tile], 1.3)
			"hit":
				if ev.target == "enemy":
					v_enemy_hp = roundi(ev.hp_after)
					if ev.via == "reflect":
						sfx.play("hit")
						_shake(10.0)
						_strike_fx(ev.tile, "riposte")
						_react(enemy, ENEMY_HOME, 24.0, Color("#ffe08a"), 1.1)
						_float_text("↩ -%d" % roundi(ev.amount), ENEMY_HOME + Vector2(40, 0), Color("#ffd966"))
					else:
						_laser(_hero_c(), _enemy_c(), Color.WHITE, 12.0)
						_react(hero, HERO_HOME, 18.0, Color.WHITE)
						_react(enemy, ENEMY_HOME, 14.0, Color("#ff9a9a"))
						_float_text("-%d" % roundi(ev.amount), ENEMY_HOME + Vector2(60, 0), COL["red"])
				else:
					v_hp = ev.hp_after
					sfx.play("hurt")
					_shake(14.0)
					_strike_fx(ev.tile, "hit")
					_react(hero, HERO_HOME, -14.0, Color("#ff6b6b"))
					_float_text("-%d" % roundi(ev.amount), HERO_HOME + Vector2(60, 0), Color("#ff4d5e"))
				_refresh()
			"heal":
				v_hp = ev.hp_after
				_float_text("+%d" % roundi(ev.amount), HERO_HOME + Vector2(60, 0), Color("#7be0a0"))
				_refresh()
			"shield":
				_badge(ev.total)
				_float_text("🛡+%d" % ev.amount, tile_btns[ev.tile].position + Vector2(40, 0), Color("#7fb8ff"))
			"strike":
				_react(enemy, ENEMY_HOME, 0.0, Color.WHITE)   # end of the windup lean
				if ev.redirect == "" and ev.dealt <= 0.0:
					sfx.play("chime", 1.5)
					_strike_fx(ev.tile, "blocked")
					_float_text("กันได้!", HERO_HOME + Vector2(20, 0), Color("#7fb8ff"))
			"shield_break":
				_badge_break()
				_refresh()
				await get_tree().create_timer(0.3).timeout
			"flag_move":
				v_flag = ev.to
				_refresh()
			"spawn":
				v_board[ev.tile] = {"color": ev.color, "kept": false}
				_refresh()
			"capped":
				_float_text("สุดทาง", Vector2(tile_btns[ev.tile].position.x, ROW_Y - 120.0), Color("#c8c8d0"))
			"kill":
				result = ev.target
	fire.visible = false
	if result == "enemy":
		await _win()
	elif result == "hero":
		_lose()
	else:
		await get_tree().create_timer(0.35).timeout
		_new_turn()


func _win() -> void:
	sfx.play("win")
	msg.text = "ชนะด่าน %d!" % stage
	await get_tree().create_timer(1.1).timeout
	stage += 1
	sim.start_fight(stage)   # heals 40% and clears the board
	_new_turn()


func _lose() -> void:
	over = true
	sfx.play("lose")
	msg.text = "แพ้ที่ด่าน %d · แตะเพื่อเริ่มใหม่" % stage
	var b := Button.new()
	b.text = "เริ่มใหม่"
	b.position = Vector2(810, 700)
	b.size = Vector2(300, 100)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(b)
