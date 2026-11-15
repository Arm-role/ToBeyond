extends Control
## Domino Run view (docs/domino/phase-3.md). All rules live in DominoSim; this
## node only draws: a walk is replayed from the sim's event list (_play_walk).
## HP, shield and the Gems on the row come from event fields during playback
## (v_* values), never from the sim's live state.
## This is the main scene.

const Sim := preload("res://scripts/domino/domino_sim.gd")
const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const Reward := preload("res://scripts/domino/domino_reward.gd")
const Shop := preload("res://scripts/domino/domino_shop.gd")
const SLOTS := 5
const MAX_STAGE := 10
const ARCH_TH := {"route": "เส้นทาง", "guard": "ป้องกัน", "ember": "ถ่าน", "blaze": "เปลวไฟ"}
const RARITY_TH := {"common": "สามัญ", "uncommon": "พบน้อย", "rare": "หายาก"}
const N := Sim.N
const MAX_HAND := Sim.MAX_HAND
const TILE := 160.0
const GAP := 12.0
const ROW_Y := 650.0       # gameplay half starts at PREVIEW_H
const PREVIEW_H := 525.0   # top half: the fight preview (same split as the main game)
const COL := {"red": Color("#e5484d"), "blue": Color("#2f7fd6"), "orange": Color("#f08a24")}
const MAX_WALK_TIME := 6.0   # fireball travel budget per walk (strike pauses do not count); slow on purpose, the eye follows step by step

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
var v_flag2: int = -1               # second flag (twin-flag boss), -1 = none
var v_gold: int = 0
var v_boss: Resource = null
var flag_seen: bool = false         # smoke boss: a flag is revealed once the fireball is within 2 tiles
var v_board: Dictionary = {}        # tile -> {color, kept, ...}
var hand: Array[String] = []        # "" = slot already placed
var selected: int = -1
var busy: bool = false
var over: bool = false

var slot_arr: Array = []            # SLOTS entries, null = empty; sim.slots = the non-null ones in order
var slot_btns: Array[Button] = []
var slot_cards: Array = []          # per slot: {icon, name, sub, badge} labels drawn on the card
var card_orders: Dictionary = {}    # artifact id -> fire orders seen in this walk
var fire_hold_used := 0.0
var tally: Dictionary = {}   # this walk's damage to the enemy per source ("base" or artifact id), in order of first hit
var tally_lbl: Label
var speed_btn: Button
var last_cause := -1   # `cause_i` of the previous fire: same value = the same pop
var fired_arts: Dictionary = {}   # artifacts that already fired in this walk
const RARITY_COL := {"common": "#8aa0b8", "uncommon": "#6fd08c", "rare": "#ffcf5a"}
const CARD_W := 150.0           # artifact cards: portrait, centred in the preview
const CARD_H := 215.0
const CARD_GAP := 14.0
const CARD_Y := 295.0
const CARD_X0 := (1920.0 - (5 * CARD_W + 4 * CARD_GAP)) * 0.5
const FIRE_HOLD := 0.35        # pause per artifact trigger so the order can be followed
const FIRE_HOLD_MAX := 6.0     # total pause per walk
var slot_sel: int = -1              # slot picked for a swap (tap two slots to swap them)
var art_tip: Label
var reward_ui: Control

# Characters: staged beside the row. Reactions always tween to/from these fixed
# home positions (never relative), so rapid pops cannot make them drift.
const HERO_HOME := Vector2(260.0, 120.0)
const ENEMY_HOME := Vector2(1460.0, 120.0)
var hero: Label
var enemy: Label
var badge: Label
var _react_tw: Dictionary = {}

var tile_btns: Array[Button] = []
var tile_kept: Array[TextureRect] = []
var _tex_cache: Dictionary = {}   # path -> Texture2D / StyleBoxTexture (null = missing art)
var hand_btns: Array[Button] = []
var discard_btn: Button
var deck_btn: Button
var deck_ui: Control
var fire: Label
var flag: Label
var flag2: Label
var gold_lbl: Label
var boss_lbl: Label
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
	_add_version_stamp()
	_start_arts()
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


## Bottom-right version stamp (same as the main game): project version + build commit.
func _speed_label() -> void:
	speed_btn.text = "⏩ ×%d" % roundi(Engine.time_scale)


func _add_version_stamp() -> void:
	var text: String = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	if FileAccess.file_exists("res://build_info.txt"):
		var info := FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
		if info != "":
			text += " · " + info
	var lbl := Label.new()
	lbl.name = "VersionStamp"
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 4000
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(lbl)


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
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_constant_override("outline_size", 8)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		b.pressed.connect(_on_tile.bind(i))
		add_child(b)
		tile_btns.append(b)
		var n := Label.new()
		n.text = str(i + 1)
		n.add_theme_font_size_override("font_size", 22)   # sits in the art's top-left circle (centre 29,29)
		n.add_theme_color_override("font_color", Color("#F0CF86"))
		n.position = Vector2(29.0 - 15.0, 29.0 - 17.0)
		n.size = Vector2(30, 34)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
		var k := TextureRect.new()   # kept marker (gold emblem)
		k.texture = _tex("res://assets/emblems/emblem_n_gold.svg")
		k.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		k.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		k.position = Vector2(TILE - 52.0, 6)
		k.size = Vector2(46, 46)
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		k.visible = false
		b.add_child(k)
		tile_kept.append(k)
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
	flag2 = flag.duplicate()
	flag2.visible = false
	add_child(flag2)
	gold_lbl = _label("", 40, Vector2(1590, 15), 310.0)
	speed_btn = Button.new()   # walk speed: x1 -> x2 -> x3 (Engine.time_scale scales the timers and tweens of the replay)
	speed_btn.position = Vector2(30, 20)
	speed_btn.size = Vector2(150, 70)
	speed_btn.add_theme_font_size_override("font_size", 34)
	speed_btn.z_index = 5
	speed_btn.pressed.connect(func():
		Engine.time_scale = {1.0: 2.0, 2.0: 3.0}.get(Engine.time_scale, 1.0)
		_speed_label())
	add_child(speed_btn)
	_speed_label()
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_lbl = _label("", 30, Vector2(460, 135), 1000.0)
	fire = Label.new()
	fire.text = "🔥"
	fire.add_theme_font_size_override("font_size", 80)
	fire.size = Vector2(TILE, 100)
	fire.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire.visible = false
	fire.z_index = 10
	add_child(fire)
	for i in MAX_HAND:
		var h := Button.new()
		h.position = Vector2(300 + i * 210, 850)
		h.size = Vector2(190, 170)
		h.add_theme_font_size_override("font_size", 46)
		h.pressed.connect(_on_hand.bind(i))
		add_child(h)
		hand_btns.append(h)
	go_btn = Button.new()
	go_btn.text = "เดิน ▶"
	# Bottom row: pile tools on the left (info + hand action), the primary action big on the right.
	go_btn.position = Vector2(1400, 860)
	go_btn.size = Vector2(420, 150)
	go_btn.add_theme_font_size_override("font_size", 56)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("#2e9e5b")
	gsb.set_corner_radius_all(24)
	var gsd := gsb.duplicate()
	gsd.bg_color = Color("#2a3a30")
	go_btn.add_theme_stylebox_override("normal", gsb)
	go_btn.add_theme_stylebox_override("hover", gsb)
	go_btn.add_theme_stylebox_override("pressed", gsb)
	go_btn.add_theme_stylebox_override("disabled", gsd)
	go_btn.pressed.connect(_on_go)
	add_child(go_btn)
	deck_btn = Button.new()
	deck_btn.position = Vector2(40, 860)
	deck_btn.size = Vector2(230, 70)
	deck_btn.add_theme_font_size_override("font_size", 28)
	deck_btn.pressed.connect(_open_deck)
	add_child(deck_btn)
	discard_btn = Button.new()
	discard_btn.position = Vector2(40, 945)
	discard_btn.size = Vector2(230, 70)
	discard_btn.add_theme_font_size_override("font_size", 28)
	discard_btn.pressed.connect(_on_discard)
	add_child(discard_btn)
	deck_ui = Control.new()
	deck_ui.visible = false
	deck_ui.z_index = 3000
	deck_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(deck_ui)
	for i in SLOTS:
		slot_arr.append(null)
		var ab := Button.new()
		ab.position = Vector2(CARD_X0 + i * (CARD_W + CARD_GAP), CARD_Y)   # centred in the preview, between hero and enemy
		ab.size = Vector2(CARD_W, CARD_H)
		ab.pivot_offset = ab.size * 0.5
		ab.pressed.connect(_on_slot.bind(i))
		add_child(ab)
		slot_btns.append(ab)
		var card := {}
		card["icon"] = _card_label(ab, 66, Vector2(0, 10), Vector2(CARD_W, 80), HORIZONTAL_ALIGNMENT_CENTER)
		card["name"] = _card_label(ab, 24, Vector2(6, 94), Vector2(CARD_W - 12, 64), HORIZONTAL_ALIGNMENT_CENTER)
		card["name"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card["name"].clip_text = false
		card["sub"] = _card_label(ab, 18, Vector2(0, CARD_H - 52), Vector2(CARD_W, 40), HORIZONTAL_ALIGNMENT_CENTER)
		var badge := _card_label(ab, 22, Vector2(CARD_W - 62, -18), Vector2(70, 30), HORIZONTAL_ALIGNMENT_CENTER)
		badge.z_index = 5
		badge.visible = false
		card["badge"] = badge
		slot_cards.append(card)
	art_tip = _label("", 26, Vector2(1660, 545), 250.0)
	art_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	art_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_tip.size = Vector2(250, 420)
	msg = _label("", 40, Vector2(460, 230), 1000.0)


## A label drawn on a card button (clicks pass through to the button).
func _card_label(parent: Control, size_px: int, pos: Vector2, sz: Vector2, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Slot order = reaction order. Tap a slot for its text, tap a second slot to swap them.
func _on_slot(i: int) -> void:
	if busy or over:
		return
	if slot_sel == -1:
		if slot_arr[i] != null:
			slot_sel = i
			_slot_tip(slot_arr[i])
	elif slot_sel == i:
		slot_sel = -1
	else:
		var t = slot_arr[slot_sel]
		slot_arr[slot_sel] = slot_arr[i]
		slot_arr[i] = t
		slot_sel = -1
		_apply_slots()
		sfx.play("place", 1.3, -8.0)
	_refresh_slots()


func _slot_tip(d: Resource) -> void:
	art_tip.text = "%s %s\n(%s · %s)\n%s" % [d.icon, d.name_th, ARCH_TH.get(d.archetype, ""), RARITY_TH.get(d.rarity, ""), d.text_th]


func _apply_slots() -> void:
	var owned: Array = []
	for d in slot_arr:
		if d != null:
			owned.append(d)
	sim.slots = owned


func _refresh_slots() -> void:
	for i in SLOTS:
		var d = slot_arr[i]
		var b := slot_btns[i]
		var c: Dictionary = slot_cards[i]
		b.text = ""
		b.tooltip_text = d.text_th if d != null else ""
		b.disabled = busy
		c.icon.text = d.icon if d != null else ""
		c.name.text = d.name_th if d != null else "%d\n—" % (i + 1)
		c.name.modulate = Color.WHITE if d != null else Color(1, 1, 1, 0.35)
		c.sub.text = ("%d · %s" % [i + 1, ARCH_TH.get(d.archetype, "")]) if d != null else ""
		c.icon.modulate = Color.WHITE if d != null else Color(1, 1, 1, 0.3)
		var sb := StyleBoxFlat.new()
		var rc := Color(RARITY_COL.get(d.rarity, "#8aa0b8")) if d != null else Color(1, 1, 1, 0.2)
		sb.bg_color = Color("#3a2f55") if d != null else Color("#221c30")
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(6 if i == slot_sel else 3)
		sb.border_color = Color("#ffd966") if i == slot_sel else rc
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)


## Walk start: forget last walk's trigger order on the cards.
func _cards_reset() -> void:
	card_orders.clear()
	fire_hold_used = 0.0
	fired_arts.clear()
	last_cause = -1
	tally.clear()
	if tally_lbl != null:
		tally_lbl.visible = false
	for c in slot_cards:
		c.badge.visible = false


## An artifact rule fired: pulse its card and show the order it fired in (1, 2, 3 ...).
## Cause link: a thin gold beam from the tile that set the artifact off to its card.
func _fire_link(ev: Dictionary) -> void:
	var t: int = ev.get("tile", -1)
	if t < 0 or t >= N:
		return
	for i in SLOTS:
		var d = slot_arr[i]
		if d != null and d.id == ev.art:
			var from := tile_btns[t].get_global_rect().get_center()
			var to := slot_btns[i].get_global_rect().get_center()
			_laser(from, to, Color("#ffd966"), 6.0)
			return


func _card_fire(art: String, order: int) -> void:
	for i in SLOTS:
		var d = slot_arr[i]
		if d == null or d.id != art:
			continue
		var list: Array = card_orders.get(art, [])
		list.append(order)
		card_orders[art] = list
		var badge: Label = slot_cards[i].badge
		var shown: Array = list.slice(maxi(list.size() - 3, 0))
		badge.text = ("…" if list.size() > 3 else "") + "›".join(shown.map(func(n): return str(n)))
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#ffd966")
		bs.set_corner_radius_all(15)
		badge.add_theme_color_override("font_color", Color("#1a1428"))
		badge.add_theme_stylebox_override("normal", bs)
		badge.visible = true
		var b := slot_btns[i]
		if _react_tw.has(b) and _react_tw[b].is_valid():
			_react_tw[b].kill()
		b.scale = Vector2.ONE
		b.modulate = Color(1.6, 1.5, 1.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.07)
		tw.chain().tween_property(b, "scale", Vector2.ONE, 0.10)
		tw.tween_property(b, "modulate", Color.WHITE, 0.25)
		_react_tw[b] = tw
		return


## Debug: ?arts=mirror,coal (web) or -- --arts=mirror,coal starts with those artifacts.
func _start_arts() -> void:
	var arg := ""
	if OS.has_feature("web"):
		var m := RegEx.create_from_string("[?&]arts=([A-Za-z0-9_,]+)").search(str(JavaScriptBridge.eval("location.search", true)))
		arg = m.get_string(1) if m != null else ""
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--arts="):
				arg = a.substr(7)
	var i := 0
	for id in arg.split(",", false):
		var d := Catalog.get_def(id)
		if d != null and i < SLOTS:
			slot_arr[i] = d
			i += 1
	_apply_slots()


## Copies the sim's state to the shown values (between walks only).
func _sync() -> void:
	v_hp = sim.hp
	v_max_hp = sim.max_hp
	v_enemy_hp = sim.enemy_hp
	v_enemy_max = sim.enemy_max
	v_strike = sim.strike_dmg
	v_flag = sim.flags[0]
	v_flag2 = sim.flags[1] if sim.flags.size() > 1 else -1
	v_gold = sim.gold
	v_boss = sim.boss
	flag_seen = false
	v_board = sim.board.duplicate(true)


func _new_turn() -> void:
	_badge(sim.block())
	hand = sim.deal_hand(hand)   # unplaced Gems of the last hand go to the discard pile
	selected = -1
	busy = false
	msg.text = ""
	_sync()
	_refresh()


func _gem_text(c: String) -> String:
	if c == "orange":
		return "⚔ %d\nคริ %d%%" % [Sim.ORANGE_DMG, roundi(Sim.ORANGE_CRIT * 100.0)]
	return "⚔ %d" % Sim.RED_DMG if c == "red" else "🛡 %d" % Sim.BLUE_BLOCK


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Tile art from the old SVG set: empty slot art, or the placed-gem art of that slot.
func _style_tile(i: int, c: String, kept: bool) -> void:
	var key := "sb_%d_%s" % [i, c]
	if not _tex_cache.has(key):
		var t := _tex("res://assets/tiles/tile_empty_%d.svg" % i) if c == "" else _tex("res://assets/tiles/placed/tile_%d_%s_N.svg" % [i, c])
		var sbt: StyleBoxTexture = null
		if t != null:
			sbt = StyleBoxTexture.new()
			sbt.texture = t
			sbt.content_margin_top = 0.0   # emblem is gone: text centred
			sbt.content_margin_bottom = 0.0
		_tex_cache[key] = sbt
	var sb = _tex_cache[key]
	if sb == null:
		_style(tile_btns[i], c)
	else:
		for s in ["normal", "hover", "pressed", "disabled"]:
			tile_btns[i].add_theme_stylebox_override(s, sb)
	tile_kept[i].visible = kept


func _style(b: Button, c: String, picked: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL[c] if c != "" else Color("#2a2438")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(6 if picked else 2)
	sb.border_color = Color("#ffd966") if picked else Color(1, 1, 1, 0.25)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)


func _smoke() -> bool:
	return v_boss != null and v_boss.rule == &"smoke"


func _refresh() -> void:
	stage_lbl.text = ("ด่าน %d · %s %s" % [stage, v_boss.icon, v_boss.name_th]) if v_boss != null else "ด่าน %d" % stage
	boss_lbl.text = v_boss.text_th if v_boss != null else ""
	gold_lbl.text = "🪙 %d" % v_gold
	enemy_lbl.text = "👹 HP %d / %d" % [maxi(v_enemy_hp, 0), v_enemy_max]
	enemy_bar.max_value = v_enemy_max
	enemy_bar.value = maxi(v_enemy_hp, 0)
	var hidden := _smoke() and not flag_seen
	var where := "?" if hidden else ("%d, %d" % [v_flag + 1, v_flag2 + 1] if v_flag2 >= 0 else "%d" % (v_flag + 1))
	intent_lbl.text = "ตีแรง %d ที่ช่อง %s" % [roundi(v_strike), where]
	hp_lbl.text = "HP %d / %d" % [roundi(maxf(v_hp, 0.0)), roundi(v_max_hp)]
	hp_bar.max_value = v_max_hp
	hp_bar.value = maxf(v_hp, 0.0)
	for i in N:
		var g: Dictionary = v_board.get(i, {})
		var c: String = g.get("color", "")
		tile_btns[i].text = _gem_text(c).replace("
", " ") if c != "" else ""
		_style_tile(i, c, c != "" and g.get("kept", false))
	var hx := 800.0 - (hand.size() * 210.0 - 20.0) * 0.5   # hand centred between the slot bar and the go button
	for i in hand_btns.size():
		hand_btns[i].visible = i < hand.size()
		if i >= hand.size():
			continue
		hand_btns[i].position.x = hx + i * 210.0
		var c: String = hand[i]
		hand_btns[i].text = _gem_text(c) if c != "" else ""
		hand_btns[i].disabled = c == "" or busy
		_style(hand_btns[i], c, i == selected)
	flag.position = Vector2(tile_btns[v_flag].position.x, ROW_Y - 100.0)
	flag.visible = not hidden
	flag2.visible = v_flag2 >= 0 and not hidden
	if v_flag2 >= 0:
		flag2.position = Vector2(tile_btns[v_flag2].position.x, ROW_Y - 100.0)
	go_btn.disabled = busy or over or sim.board.is_empty()
	discard_btn.text = "🗑 ทิ้ง (%d)" % sim.discards_left
	discard_btn.disabled = busy or over or selected < 0 or sim.discards_left <= 0
	deck_btn.text = "🂠 สำรับ %d/%d" % [sim.deck.size(), _deck_total()]
	deck_btn.disabled = busy or over
	_refresh_slots()


func _on_hand(i: int) -> void:
	if busy or hand[i] == "":
		return
	selected = -1 if selected == i else i
	sfx.play("place", 1.2, -8.0)
	_refresh()


func _deck_total() -> int:
	var n := 0
	for c in Sim.DECK_COUNTS:
		n += int(Sim.DECK_COUNTS[c])
	return n


## Deck viewer: every card of the fight's deck by type; cards still in the draw pile are bright, drawn ones faded.
func _open_deck() -> void:
	if busy or over:
		return
	for ch in deck_ui.get_children():
		ch.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: deck_ui.visible = false)
	deck_ui.add_child(dim)
	var title := Label.new()
	title.text = "สำรับ · เหลือ %d จาก %d ใบ" % [sim.deck.size(), _deck_total()]
	title.add_theme_font_size_override("font_size", 52)
	title.position = Vector2(0, 150)
	title.size = Vector2(1920, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_ui.add_child(title)
	var left := {}
	for c in sim.deck:
		left[c] = int(left.get(c, 0)) + 1
	var names := {"red": "⚔ โจมตี", "orange": "⚡ คริ", "blue": "🛡 โล่"}
	var y := 290.0
	for c in ["red", "orange", "blue"]:
		var total := int(Sim.DECK_COUNTS[c])
		var rem := int(left.get(c, 0))
		var lbl := Label.new()
		lbl.text = "%s   เหลือ %d / %d" % [names[c], rem, total]
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.position = Vector2(200, y)
		lbl.size = Vector2(1520, 50)
		deck_ui.add_child(lbl)
		for i in total:
			var t := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = COL[c]
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.5)
			t.add_theme_stylebox_override("panel", sb)
			t.position = Vector2(200 + i * 76, y + 60)
			t.size = Vector2(66, 90)
			t.modulate.a = 1.0 if i < rem else 0.2
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deck_ui.add_child(t)
		y += 210.0
	var hint := Label.new()
	hint.text = "สว่าง = ยังอยู่ในสำรับ   ·   จาง = จั่วไปแล้ว (อยู่ในมือ/บนกระดาน/กองทิ้ง)   ·   แตะที่ไหนก็ได้เพื่อปิด"
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	hint.position = Vector2(0, 940)
	hint.size = Vector2(1920, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_ui.add_child(hint)
	deck_ui.visible = true


## Throws the selected hand Gem away and draws a replacement from the limited deck.
func _on_discard() -> void:
	if busy or over or selected < 0 or hand[selected] == "":
		return
	var n := sim.discard_card(hand[selected])
	if n == "-":
		return
	hand[selected] = n   # "" = deck and discard pile are both empty: the slot stays empty
	selected = -1
	sfx.play("place", 0.8, -8.0)
	_refresh()


func _on_tile(t: int) -> void:
	if busy or over:
		return
	if sim.board.has(t):
		# Take the Gem back to its hand slot (kept Gems stay).
		var c := sim.take(t)
		if c != "":
			for i in hand.size():
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
	if flag2.visible:
		var ft2 := create_tween()
		ft2.tween_property(flag2, "scale", Vector2(1.3, 1.3), 0.06)
		ft2.tween_property(flag2, "scale", Vector2.ONE, 0.10)


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


var _recent_floats: Array = []   # [position, time ms] of floating texts still on screen


func _float_text(text: String, at: Vector2, col: Color) -> void:
	var now := Time.get_ticks_msec()
	_recent_floats = _recent_floats.filter(func(r): return now - r[1] < 700)
	var stacked := 0
	for r in _recent_floats:
		if absf(r[0].x - at.x) < 110.0 and absf(r[0].y - at.y) < 70.0 * (stacked + 1):
			stacked += 1
	_recent_floats.append([at, now])
	at.y -= 60.0 * stacked   # texts that land together stack upward instead of overlapping
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


const HIT_HOLD := 0.4   # pause after each hit so the attack lands before the fireball moves on


func _play_walk(evs: Array) -> void:
	var steps := 0
	for ev in evs:
		if ev.k == "pass":
			steps += 1
	var step_dur: float = minf(0.42, MAX_WALK_TIME / float(maxi(steps, 1)))
	var seen := 0
	var prev_tile := -1
	var result := ""
	for j in evs.size():
		var ev: Dictionary = evs[j]
		match ev.k:
			"ignite":
				_cards_reset()
				fire.position = Vector2(HERO_HOME.x + 20.0, ROW_Y - 20.0)
				fire.visible = true
				_badge(0)
				_react(hero, HERO_HOME, 0.0, Color.WHITE, 1.15)
			"pass":
				seen += 1
				if _smoke() and (absi(ev.tile - v_flag) <= 2 or (v_flag2 >= 0 and absi(ev.tile - v_flag2) <= 2)):
					flag_seen = true
					_refresh()
				var np := _next_pass(evs, j)
				if np >= 0 and _strike_after(evs, np):
					_windup()
				if ev.tile == prev_tile:
					await get_tree().create_timer(0.08).timeout   # bounce: enter the same tile again
				else:
					var dur: float = lerpf(step_dur, step_dur * 0.6, float(seen) / float(maxi(steps, 1)))
					var tw := create_tween()
					tw.tween_property(fire, "position", Vector2(tile_btns[ev.tile].position.x, ROW_Y - 20.0), dur)
					await tw.finished
				prev_tile = ev.tile
			"fire":
				_card_fire(ev.art, ev.order)
				_fire_link(ev)
				sfx.play("chime", 1.0 + 0.06 * mini(ev.order, 10), -10.0)   # the chain climbs in pitch
				var is_boss: bool = ev.art == "enemy"
				if is_boss:
					_react(enemy, ENEMY_HOME, 10.0, Color("#c9a0ff"), 1.08)
				var shown: bool = is_boss or slot_arr.any(func(d): return d != null and d.id == ev.art)
				var first: bool = shown and not fired_arts.has(ev.art)
				fired_arts[ev.art] = true
				var same_pop: bool = ev.get("cause_i", -1) == last_cause and last_cause >= 0
				last_cause = ev.get("cause_i", -1)
				if same_pop and shown:
					await get_tree().create_timer(FIRE_HOLD * 0.6).timeout   # fires of one pop go in quick succession, results land together
				elif first:
					await get_tree().create_timer(FIRE_HOLD * 1.8).timeout   # a new artifact in the chain always gets a clear beat
				elif shown and fire_hold_used < FIRE_HOLD_MAX:
					fire_hold_used += FIRE_HOLD
					await get_tree().create_timer(FIRE_HOLD).timeout
			"pop":
				sfx.step(ev.nth - 1)
				_pop(tile_btns[ev.tile], 1.3)
				if ev.get("nullified", false):
					_float_text("0", ENEMY_HOME + Vector2(60, 0), Color("#9a9aa6"))
				if ev.get("crit", false):
					_float_text("คริ! ×2", ENEMY_HOME + Vector2(60, -50), Color("#ffb347"))
					_shake(8.0)
					await get_tree().create_timer(0.12).timeout   # hit-stop on a crit
			"hit":
				if ev.target == "enemy":
					v_enemy_hp = roundi(ev.hp_after)
					if ev.via == "reflect":
						sfx.play("hit")
						_shake(10.0)
						_strike_fx(ev.tile, "riposte")
						_react(enemy, ENEMY_HOME, 24.0, Color("#ffe08a"), 1.1)
						_float_text("↩ -%d" % roundi(ev.amount), ENEMY_HOME + Vector2(40, 0), Color("#ffd966"))
						_tally_add(ev.src, roundi(ev.amount))
					else:
						_laser(_hero_c(), _enemy_c(), Color.WHITE, 12.0)
						_react(hero, HERO_HOME, 18.0, Color.WHITE)
						_react(enemy, ENEMY_HOME, 14.0, Color("#ff9a9a"))
						_float_text("-%d" % roundi(ev.amount), ENEMY_HOME + Vector2(60, 0), COL["red"])
						_tally_add(ev.src, roundi(ev.amount))
				else:
					v_hp = ev.hp_after
					sfx.play("hurt")
					_shake(14.0)
					_strike_fx(ev.tile, "hit")
					_react(hero, HERO_HOME, -14.0, Color("#ff6b6b"))
					_float_text("-%d" % roundi(ev.amount), HERO_HOME + Vector2(60, 0), Color("#ff4d5e"))
				_refresh()
				await get_tree().create_timer(HIT_HOLD).timeout   # fireball waits for the attack beat
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
				if int(ev.get("left", 0)) > 0:
					_badge(int(ev.left))   # part of the shield is left
				else:
					_badge_break()
				_refresh()
				await get_tree().create_timer(0.3).timeout
			"flag_move":
				if v_flag == ev.from:
					v_flag = ev.to
				else:
					v_flag2 = ev.to
				_refresh()
			"spawn":
				v_board[ev.tile] = {"color": ev.color, "kept": false}
				_refresh()
			"capped":
				_float_text("สุดทาง", Vector2(tile_btns[ev.tile].position.x, ROW_Y - 120.0), Color("#c8c8d0"))
			"gold":
				v_gold = ev.total
				_float_text("+%d 🪙" % ev.amount, ENEMY_HOME + Vector2(40, 60), Color("#ffd966"))
				_refresh()
			"kill":
				result = ev.target
	fire.visible = false
	if tally_lbl != null:
		tally_lbl.visible = false
	if result == "enemy":
		await _win()
	elif result == "hero":
		_badge_break()
		_refresh()
		await get_tree().create_timer(0.3).timeout
		_lose()
	else:
		await get_tree().create_timer(0.35).timeout
		_new_turn()


## Running damage counter near the enemy; a card's own damage floats over that card.
func _tally_add(src: String, amount: int) -> void:
	tally[src] = int(tally.get(src, 0)) + amount
	var total := 0
	for k in tally:
		total += int(tally[k])
	if tally_lbl == null:
		tally_lbl = _label("", 56, ENEMY_HOME + Vector2(-100, -110), 400.0)
		tally_lbl.add_theme_color_override("font_color", Color("#ffd966"))
		tally_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		tally_lbl.add_theme_constant_override("outline_size", 10)
		tally_lbl.z_index = 20
		tally_lbl.pivot_offset = Vector2(200, 45)
	tally_lbl.text = "💥 %d" % total
	tally_lbl.visible = true
	tally_lbl.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(tally_lbl, "scale", Vector2.ONE, 0.2)
	if src != "base":
		var c := _card_center(src)
		if c != Vector2.ZERO:
			_float_text("+%d" % amount, c + Vector2(-30, -60), Color("#ffd966"))


func _card_center(art: String) -> Vector2:
	for i in SLOTS:
		var d = slot_arr[i]
		if d != null and d.id == art:
			return slot_btns[i].get_global_rect().get_center()
	return Vector2.ZERO


func _src_name(src: String) -> String:
	if src == "base":
		return "🔥 ลูกไฟ"
	if src == "enemy":
		return "👹 บอส"
	for d in slot_arr:
		if d != null and d.id == src:
			return "%s %s" % [d.icon, d.name_th]
	return src


func _win() -> void:
	sfx.play("win")
	var bonus := sim.hp_bonus()
	var hp_left := sim.hp
	var gold_before := sim.gold
	var coins := sim.claim_win()
	v_gold = sim.gold
	msg.text = "ชนะด่าน %d! +%d 🪙 (เลือดเหลือ +%d)" % [stage, coins, bonus]
	_refresh()
	await get_tree().create_timer(1.1).timeout
	if stage >= MAX_STAGE:
		over = true
		msg.text = "ผ่านครบ %d ด่าน! 🎉" % MAX_STAGE
		_restart_button()
		_refresh()
		return
	msg.text = ""
	await _summary(hp_left, bonus, coins, gold_before)
	await _shop()   # every win opens the shop; no 1-of-3 pick
	stage += 1
	hand = []   # the new fight has a fresh deck: nothing left over to discard
	sim.start_fight(stage)   # heals 40% and clears the board
	_new_turn()


## Summary screen between the win and the shop.
signal _summary_done

func _summary(hp_left: float, bonus: int, coins: int, gold_before: int) -> void:
	reward_ui = Control.new()
	reward_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.z_index = 100
	add_child(reward_ui)
	_rw_clear("สรุปด่าน %d" % stage)
	var l := Label.new()
	l.text = "❤ เลือดเหลือ  %d / %d

🪙 รางวัลชนะ  +%d
   (โบนัสเลือด +%d)

🪙 เหรียญก่อนหน้า  %d
🪙 รวมทั้งหมด  %d" % [
		roundi(hp_left), roundi(sim.max_hp), coins, bonus, gold_before, sim.gold]
	l.add_theme_font_size_override("font_size", 46)
	l.position = Vector2(0, 220)
	l.size = Vector2(1920, 560)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_ui.add_child(l)
	var go := _rw_button("ไปร้านค้า ▶", Vector2(810, 860), Vector2(300, 100), 40)
	go.pressed.connect(func(): _summary_done.emit())
	await _summary_done
	reward_ui.queue_free()


## Shop HP upgrade: show the new max HP on the hero bar.
func _sync_hero() -> void:
	v_hp = sim.hp
	v_max_hp = sim.max_hp
	_refresh()


func _lose() -> void:
	over = true
	sfx.play("lose")
	msg.text = "แพ้ที่ด่าน %d · แตะเพื่อเริ่มใหม่" % stage
	_restart_button()


func _restart_button() -> void:
	var b := Button.new()
	b.text = "เริ่มใหม่"
	b.position = Vector2(810, 700)
	b.size = Vector2(300, 100)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(b)


signal reward_done


## Reward screen: pick 1 of the offered artifacts (or skip). With full slots the
## pick asks which owned artifact to replace.
func _reward(offers: Array) -> void:
	reward_ui = Control.new()
	reward_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.z_index = 100
	add_child(reward_ui)
	_reward_offers(offers)
	await reward_done
	reward_ui.queue_free()
	slot_sel = -1
	_apply_slots()
	_refresh_slots()


func _rw_clear(title: String) -> void:
	for c in reward_ui.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.add_child(dim)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 52)
	l.position = Vector2(0, 50)
	l.size = Vector2(1920, 90)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_ui.add_child(l)


func _rw_button(text: String, pos: Vector2, size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", font)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_ui.add_child(b)
	return b


func _reward_offers(offers: Array) -> void:
	_rw_clear("เลือก Artifact 1 ใบ")
	var x0 := (1920.0 - (offers.size() * 440.0 + (offers.size() - 1) * 40.0)) * 0.5
	for i in offers.size():
		var d: Resource = offers[i]
		var b := _rw_button("%s\n%s\n(%s · %s)\n\n%s" % [d.icon, d.name_th, ARCH_TH.get(d.archetype, ""), RARITY_TH.get(d.rarity, ""), d.text_th],
			Vector2(x0 + i * 480.0, 180), Vector2(440, 520), 34)
		b.pressed.connect(_reward_pick.bind(d, offers))
	var skip := _rw_button("ข้าม", Vector2(810, 780), Vector2(300, 100), 40)
	skip.pressed.connect(func(): reward_done.emit())


func _reward_pick(d: Resource, offers: Array) -> void:
	sfx.play("place", 1.3, -8.0)
	for i in SLOTS:
		if slot_arr[i] == null:
			slot_arr[i] = d
			reward_done.emit()
			return
	_rw_clear("ช่องเต็ม: เลือกช่องที่จะแทนด้วย %s %s" % [d.icon, d.name_th])
	for i in SLOTS:
		var o: Resource = slot_arr[i]
		var b := _rw_button("%d  %s %s\n%s" % [i + 1, o.icon, o.name_th, o.text_th], Vector2(150 + i * 320.0, 250), Vector2(300, 420), 30)
		b.pressed.connect(func():
			slot_arr[i] = d
			reward_done.emit())
	var back := _rw_button("กลับ", Vector2(810, 780), Vector2(300, 100), 40)
	back.pressed.connect(func(): _reward_offers(offers))


## Shop after every win: 4 artifacts for coins, reroll (2, then +1 each), sell for half price.
func _shop() -> void:
	reward_ui = Control.new()
	reward_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.z_index = 100
	add_child(reward_ui)
	var rerolls := 0
	var stock: Array = Shop.stock(sim)
	var done := false
	while not done:
		_apply_slots()
		_rw_clear("ร้านค้า   🪙 %d" % sim.gold)
		var x0 := (1920.0 - (stock.size() * 420.0 + (stock.size() - 1) * 30.0)) * 0.5
		for i in stock.size():
			var d: Resource = stock[i]
			if d == null:
				continue   # already bought
			var free := slot_arr.find(null)
			var cost := Shop.price(d)
			var can := sim.gold >= cost and free >= 0
			var label := "%s\n%s\n(%s · %s)\n\n%s\n\n%s" % [d.icon, d.name_th, ARCH_TH.get(d.archetype, ""), RARITY_TH.get(d.rarity, ""), d.text_th,
				("ซื้อ %d 🪙" % cost) if free >= 0 else "ช่องเต็ม: ขายก่อน"]
			var b := _rw_button(label, Vector2(x0 + i * 450.0, 140), Vector2(420, 470), 30)
			b.disabled = not can
			b.pressed.connect(func():
				sim.gold -= cost
				slot_arr[free] = d
				stock[i] = null
				sfx.play("place", 1.3, -8.0)
				_shop_step.emit(false))
		var rc := Shop.reroll_cost(rerolls)
		var rb := _rw_button("สุ่มใหม่ %d 🪙" % rc, Vector2(160, 640), Vector2(380, 90), 34)
		rb.disabled = sim.gold < rc
		rb.pressed.connect(func():
			sim.gold -= rc
			rerolls += 1
			stock = Shop.stock(sim)
			_shop_step.emit(false))
		var hc := Shop.hp_up_cost(sim)
		var hpb := _rw_button("❤ +%d HP สูงสุด   %d 🪙\n(ตอนนี้ %d)" % [Shop.HP_UP, hc, roundi(sim.max_hp)], Vector2(580, 640), Vector2(400, 90), 28)
		hpb.disabled = sim.gold < hc
		hpb.pressed.connect(func():
			Shop.buy_hp(sim)
			_sync_hero()
			sfx.play("place", 1.3, -8.0)
			_shop_step.emit(false))
		var hdc := Shop.hand_up_cost(sim)
		var maxed: bool = sim.hand_size >= Sim.MAX_HAND
		var hdb := _rw_button(("✋ มือ +1 ช่อง   %d 🪙\n(ตอนนี้ %d)" % [hdc, sim.hand_size]) if not maxed else "✋ มือเต็มแล้ว (%d)" % sim.hand_size, Vector2(1010, 640), Vector2(400, 90), 28)
		hdb.disabled = maxed or sim.gold < hdc
		hdb.pressed.connect(func():
			Shop.buy_hand(sim)
			sfx.play("place", 1.3, -8.0)
			_shop_step.emit(false))
		for i in SLOTS:
			var o = slot_arr[i]
			var sb := _rw_button(("ขาย %s %s +%d 🪙" % [o.icon, o.name_th, Shop.sell_value(o)]) if o != null else "ช่อง %d ว่าง" % (i + 1),
				Vector2(160 + i * 320.0, 760), Vector2(300, 110), 26)
			sb.disabled = o == null
			sb.pressed.connect(func():
				sim.gold += Shop.sell_value(o)
				slot_arr[i] = null
				sfx.play("place", 1.0, -8.0)
				_shop_step.emit(false))
		var go := _rw_button("ไปต่อ ▶", Vector2(810, 920), Vector2(300, 100), 40)
		go.pressed.connect(func(): _shop_step.emit(true))
		done = await _shop_step
	reward_ui.queue_free()
	slot_sel = -1
	_apply_slots()
	_refresh_slots()
	v_gold = sim.gold


signal _shop_step(leave: bool)
