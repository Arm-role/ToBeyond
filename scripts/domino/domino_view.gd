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
const Chaos := preload("res://scripts/domino/domino_chaos.gd")
const SLOTS := 5
const MAX_STAGE := 10
const ARCH_TH := {"route": "เส้นทาง", "guard": "ป้องกัน", "ember": "ถ่าน", "blaze": "เปลวไฟ"}
const RARITY_TH := {"common": "สามัญ", "uncommon": "พบน้อย", "rare": "หายาก"}
const N := Sim.N
const MAX_HAND := Sim.MAX_HAND
const HAND_D := 200.0   # diamond hand card: side of the square it fits in
const TILE := 164.0
const GAP := 20.0
const TAB_H := 43.0        # height of the flag tab above each tile
const ROW_Y := 587.0       # gameplay half starts at PREVIEW_H
const PREVIEW_H := 500.0   # top half: the fight preview (same split as the main game)
const COL := {"red": Color("#e5484d"), "redcrit": Color("#ff6a3d"), "blue": Color("#2f7fd6"), "orange": Color("#f08a24"),
	"red2": Color("#b81d26"), "redcrit2": Color("#d9481a"), "blue2": Color("#1c55b3")}   # Lv2 Gems: deeper tone of the Lv1 colour
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
var v_ash: Dictionary = {}          # tile -> Gem kind: ashes left by pops (Chaos ashes)
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
const CARD_W := 96.0           # artifact cards: portrait, centred in the preview
const CARD_H := 133.0
const CARD_GAP := 28.0
const CARD_Y := 25.0
const CARD_X0 := 664.0
const FIRE_HOLD := 0.35        # pause per artifact trigger so the order can be followed
const FIRE_HOLD_MAX := 6.0     # total pause per walk
var slot_sel: int = -1              # slot picked for a swap (tap two slots to swap them)
var art_pop: Panel
var art_pop_l: Dictionary = {}
var cards_lbl: Label
var reward_ui: Control

# Characters: staged beside the row. Reactions always tween to/from these fixed
# home positions (never relative), so rapid pops cannot make them drift.
const HERO_HOME := Vector2(233.0, 186.0)
const ENEMY_HOME := Vector2(1530.0, 235.0)
var hero: Label
var enemy: Label
var badge: Label
var _react_tw: Dictionary = {}

var tile_btns: Array[Button] = []
var tile_tabs: Array[Panel] = []   # frame above each tile: where the enemy's attack flag can stand
var tile_kept: Array[TextureRect] = []
var tile_prev: Array[Panel] = []      # trace of the previous round: a Gem was placed on this tile
var v_prev: Dictionary = {}
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


## Tab frame over a tile. `lit` = the enemy's flag stands here.
func _tab_style(lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.1, 0.1, 0.30) if lit else Color(1, 1, 1, 0.05)
	sb.border_color = Color("#E0584F") if lit else Color(1, 1, 1, 0.22)
	sb.set_border_width_all(4 if lit else 2)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	return sb


func _ready() -> void:
	sfx = preload("res://scripts/sfx_manager.gd").new()
	add_child(sfx)
	sim.rng.randomize()
	sim.map_rng.randomize()
	_build()
	_add_version_stamp()
	_start_arts()
	sim.start_fight(1)
	_sync()
	_new_turn()
	if OS.has_feature("web") and "shop=1" in str(JavaScriptBridge.eval("location.search", true)):
		sim.gold = 30   # debug: ?shop=1 opens the shop at once with 30 coins
		v_gold = 30
		_refresh()
		await _shop()
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


## Rounded outline frame (wireframe boxes); clicks pass through.
func _frame(r: Rect2, radius: int = 12, bw: int = 3, bg: Color = Color(0, 0, 0, 0.25), border: Color = Color("#8a7fb0")) -> Panel:
	var pn := Panel.new()
	pn.position = r.position
	pn.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(bw)
	sb.border_color = border
	pn.add_theme_stylebox_override("panel", sb)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pn)
	return pn


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
	# Layout follows the wireframe (1672 px wide, scaled x1.148 to the 1920 canvas).
	_frame(Rect2(216, 25, 146, 58))
	stage_lbl = _label("", 30, Vector2(216, 33), 146.0)
	_frame(Rect2(1481, 155, 310, 49))
	intent_lbl = _label("", 28, Vector2(1481, 161), 310.0)
	enemy_bar = _bar(Vector2(1446, 425), Color("#c0392b"), 322.0)
	enemy_lbl = _label("", 26, Vector2(1307, 420), 600.0)
	hp_bar = _bar(Vector2(168, 425), Color("#2fa866"), 311.0)
	hp_lbl = _label("", 26, Vector2(23.5, 420), 600.0)
	for l in [enemy_lbl, hp_lbl]:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
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
		var tab := Panel.new()
		tab.position = Vector2(b.position.x, ROW_Y - TAB_H - 10.0)
		tab.size = Vector2(TILE, TAB_H)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_theme_stylebox_override("panel", _tab_style(false))
		add_child(tab)
		tile_tabs.append(tab)
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
		var prev_frm := Panel.new()   # previous-round trace: an empty frame in the colour of the Gem that was placed
		prev_frm.position = Vector2(5, 5)
		prev_frm.size = Vector2(TILE - 10.0, TILE - 10.0)
		prev_frm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev_frm.visible = false
		b.add_child(prev_frm)
		tile_prev.append(prev_frm)
	hero = _char("🧙", HERO_HOME)
	enemy = _char("👹", ENEMY_HOME)
	badge = _label("", 52, HERO_HOME + Vector2(0, -75), 200.0)
	badge.visible = false
	badge.pivot_offset = Vector2(100, 40)
	flag = Label.new()
	flag.text = "⚔"
	flag.add_theme_font_size_override("font_size", 40)
	flag.size = Vector2(TILE, TAB_H)
	flag.pivot_offset = flag.size * 0.5
	flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(flag)
	flag2 = flag.duplicate()
	flag2.visible = false
	add_child(flag2)
	_frame(Rect2(1730, 29, 150, 59), 29)
	gold_lbl = _label("", 34, Vector2(1730, 36), 150.0)
	speed_btn = Button.new()   # walk speed: x1 -> x2 -> x3 (Engine.time_scale scales the timers and tweens of the replay)
	speed_btn.position = Vector2(40, 25)
	speed_btn.size = Vector2(158, 58)
	speed_btn.add_theme_font_size_override("font_size", 30)
	speed_btn.z_index = 5
	speed_btn.pressed.connect(func():
		Engine.time_scale = {1.0: 2.0, 2.0: 3.0}.get(Engine.time_scale, 1.0)
		_speed_label())
	add_child(speed_btn)
	_speed_label()
	boss_lbl = _label("", 20, Vector2(1440, 208), 480.0)
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
		h.position = Vector2(300 + i * 221, 824)
		h.size = Vector2(HAND_D, HAND_D)
		h.add_theme_font_size_override("font_size", 40)
		var dia := Polygon2D.new()   # the card is a diamond (a square turned 45°) drawn behind the button's text
		dia.polygon = PackedVector2Array([Vector2(HAND_D * 0.5, 0), Vector2(HAND_D, HAND_D * 0.5), Vector2(HAND_D * 0.5, HAND_D), Vector2(0, HAND_D * 0.5)])
		dia.show_behind_parent = true
		h.add_child(dia)
		var rim := Line2D.new()
		rim.points = dia.polygon
		rim.closed = true
		rim.show_behind_parent = true
		rim.width = 4.0
		h.add_child(rim)
		h.set_meta("dia", dia)
		h.set_meta("rim", rim)
		h.pressed.connect(_on_hand.bind(i))
		add_child(h)
		hand_btns.append(h)
	go_btn = Button.new()
	go_btn.text = "เดิน ▶"
	# Bottom row: pile tools on the left (info + hand action), the primary action big on the right.
	go_btn.position = Vector2(1570, 928)
	go_btn.size = Vector2(307, 125)
	go_btn.add_theme_font_size_override("font_size", 44)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("#2e9e5b")
	gsb.set_corner_radius_all(20)
	var gsd := gsb.duplicate()
	gsd.bg_color = Color("#2a3a30")
	go_btn.add_theme_stylebox_override("normal", gsb)
	go_btn.add_theme_stylebox_override("hover", gsb)
	go_btn.add_theme_stylebox_override("pressed", gsb)
	go_btn.add_theme_stylebox_override("disabled", gsd)
	go_btn.pressed.connect(_on_go)
	add_child(go_btn)
	deck_btn = Button.new()
	deck_btn.position = Vector2(52, 886)
	deck_btn.size = Vector2(298, 122)
	deck_btn.add_theme_font_size_override("font_size", 30)
	deck_btn.pressed.connect(_open_deck)
	add_child(deck_btn)
	discard_btn = Button.new()
	discard_btn.position = Vector2(1578, 798)   # same size and weight as the go button: the two turn actions
	discard_btn.size = Vector2(293, 112)
	discard_btn.add_theme_font_size_override("font_size", 36)
	var dsb := gsb.duplicate()
	dsb.bg_color = Color("#c9822b")
	var dsd := gsb.duplicate()
	dsd.bg_color = Color("#3a3226")
	discard_btn.add_theme_stylebox_override("normal", dsb)
	discard_btn.add_theme_stylebox_override("hover", dsb)
	discard_btn.add_theme_stylebox_override("pressed", dsb)
	discard_btn.add_theme_stylebox_override("disabled", dsd)
	discard_btn.pressed.connect(_on_discard)
	add_child(discard_btn)
	deck_ui = Control.new()
	deck_ui.visible = false
	deck_ui.z_index = 3000
	deck_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(deck_ui)
	_frame(Rect2(651, 11, 619, 164), 26, 5, Color(0.02, 0.02, 0.05, 0.55), Color(0.05, 0.04, 0.1, 0.9))   # artifact tray, a dark inset like the Joker area in Balatro
	cards_lbl = _label("", 22, Vector2(960, 178), 310.0)   # "n/5" under the tray, right-aligned
	cards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cards_lbl.modulate.a = 0.75
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
		card["icon"] = _card_label(ab, 44, Vector2(0, 8), Vector2(CARD_W, 52), HORIZONTAL_ALIGNMENT_CENTER)
		card["name"] = _card_label(ab, 16, Vector2(4, 62), Vector2(CARD_W - 8, 44), HORIZONTAL_ALIGNMENT_CENTER)
		card["name"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card["name"].clip_text = false
		card["sub"] = _card_label(ab, 12, Vector2(0, CARD_H - 24), Vector2(CARD_W, 20), HORIZONTAL_ALIGNMENT_CENTER)
		var badge := _card_label(ab, 16, Vector2(CARD_W - 46, -12), Vector2(54, 24), HORIZONTAL_ALIGNMENT_CENTER)
		badge.z_index = 5
		badge.visible = false
		card["badge"] = badge
		slot_cards.append(card)
	art_pop = Panel.new()   # floating detail frame for a tapped artifact card (like the shop's panel)
	art_pop.position = Vector2(651, 220)
	art_pop.size = Vector2(619, 250)
	art_pop.z_index = 60
	art_pop.visible = false
	art_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aps := StyleBoxFlat.new()
	aps.bg_color = Color("#2a2340")
	aps.set_corner_radius_all(18)
	aps.set_border_width_all(3)
	aps.border_color = Color("#8a7fb0")
	art_pop.add_theme_stylebox_override("panel", aps)
	add_child(art_pop)
	art_pop_l["icon"] = _panel_label(art_pop, "", 72, Vector2(20, 15), Vector2(100, 100), HORIZONTAL_ALIGNMENT_CENTER)
	art_pop_l["title"] = _panel_label(art_pop, "", 36, Vector2(130, 15), Vector2(470, 60), HORIZONTAL_ALIGNMENT_LEFT)
	art_pop_l["sub"] = _panel_label(art_pop, "", 24, Vector2(130, 75), Vector2(470, 40), HORIZONTAL_ALIGNMENT_LEFT)
	art_pop_l["body"] = _panel_label(art_pop, "", 28, Vector2(24, 125), Vector2(571, 115), HORIZONTAL_ALIGNMENT_LEFT)
	art_pop_l["body"].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg = _label("", 40, Vector2(505, 300), 930.0)


## Card frame used by the shop, rewards and blinds: kind "art" (rarity border), "chaos" (indigo + gold), "enemy" (red), "util" (teal).
func _card_style(kind: String, rarity: String, state: String, st: String) -> StyleBoxFlat:
	var bg: String = {"art": "#3a2f55", "chaos": "#1d1630", "enemy": "#3a1f24", "util": "#1f3a40"}.get(kind, "#3a2f55")
	var border := Color("#c9a227") if kind == "chaos" else (Color("#d9534f") if kind == "enemy" else (Color("#5ac8c8") if kind == "util" else Color(RARITY_COL.get(rarity, "#8aa0b8"))))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = border
	if state == "owned":
		sb.border_color = Color("#ffd966")
		sb.set_border_width_all(6)
	if state == "empty":
		sb.bg_color = Color("#221c30")
		sb.border_color = Color(1, 1, 1, 0.2)
	if st == "hover":
		sb.bg_color = sb.bg_color.lightened(0.12)
		sb.set_border_width_all(6)
	elif st == "pressed":
		sb.bg_color = sb.bg_color.lightened(0.22)
	return sb


## Card (same size as the game's artifact slots, CARD_SZ): Button root, icon + foot only. All text lives in the detail panel.
## data: icon, foot, kind, rarity, state ("", "disabled" = dimmed but tappable, "empty" = no card).
func _make_card(parent: Control, pos: Vector2, sz: Vector2, data: Dictionary) -> Dictionary:
	var b := Button.new()
	b.text = ""
	b.position = pos
	b.size = sz
	b.pivot_offset = sz * 0.5
	var state: String = data.get("state", "")
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _card_style(data.get("kind", "art"), data.get("rarity", ""), state, st))
	b.disabled = state == "empty"
	if state == "disabled" or state == "empty":
		b.modulate.a = 0.55
	parent.add_child(b)
	var h := sz.y
	var w := sz.x
	var c := {"btn": b}
	c["icon"] = _card_label(b, roundi(h * 0.32), Vector2(0, h * 0.10), Vector2(w, h * 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	c["icon"].text = data.get("icon", "")
	var foot := _card_label(b, 24, Vector2(0, h * 0.74), Vector2(w, h * 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	foot.add_theme_color_override("font_color", Color("#ffd966"))
	foot.text = data.get("foot", "")
	c["foot"] = foot
	return c


const CARD_SZ := Vector2(150, 215)


## info = card data + title, sub, body (shown in the panel) + act (action button text, "" = none), ok, cb (Callable).
func _art_info(d: Resource, foot: String, act: String, ok: bool, cb: Callable) -> Dictionary:
	return {"icon": d.icon, "title": d.name_th, "sub": "%s · %s" % [ARCH_TH.get(d.archetype, ""), RARITY_TH.get(d.rarity, "")], "body": d.text_th,
		"foot": foot, "kind": "art", "rarity": d.rarity, "state": "" if ok else "disabled", "act": act, "ok": ok, "cb": cb}


func _chaos_info(cc: Dictionary, foot: String, act: String, ok: bool, cb: Callable) -> Dictionary:
	return {"icon": cc.icon, "title": cc.name, "sub": "การ์ด Chaos", "body": cc.text, "foot": foot, "kind": "chaos",
		"state": "" if ok else "disabled", "act": act, "ok": ok, "cb": cb}


## Info panel at `rect`: tap a card to fill it.
func _detail_panel(rect: Rect2) -> Control:
	var pn := Panel.new()
	pn.position = rect.position
	pn.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a2340")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color("#8a7fb0")
	pn.add_theme_stylebox_override("panel", sb)
	reward_ui.add_child(pn)
	_panel_label(pn, "แตะการ์ดเพื่อดูรายละเอียด", 30, Vector2(0, 0), rect.size, HORIZONTAL_ALIGNMENT_CENTER).modulate.a = 0.6
	return pn


func _panel_label(pn: Control, text: String, fs: int, pos: Vector2, sz: Vector2, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	pn.add_child(l)
	return l


## Add one tappable card to `cards`; tapping shows it in `panel`.
func _add_card(parent: Control, cards: Array, panel: Control, pos: Vector2, info: Dictionary) -> void:
	var c := _make_card(parent, pos, CARD_SZ, info)
	cards.append({"btn": c.btn, "info": info})
	var idx := cards.size() - 1
	c.btn.pressed.connect(func(): _detail_show(panel, cards, idx))


func _detail_show(panel: Control, cards: Array, idx: int) -> void:
	for i in cards.size():
		var inf: Dictionary = cards[i].info
		var state := "owned" if i == idx else String(inf.get("state", ""))
		for st in ["normal", "hover", "pressed", "disabled"]:
			cards[i].btn.add_theme_stylebox_override(st, _card_style(inf.get("kind", "art"), inf.get("rarity", ""), state, st))
	for ch in panel.get_children():
		ch.queue_free()
	var info: Dictionary = cards[idx].info
	var w := panel.size.x
	var h := panel.size.y
	_panel_label(panel, info.get("icon", ""), 90, Vector2(20, 20), Vector2(130, 130), HORIZONTAL_ALIGNMENT_CENTER)
	_panel_label(panel, info.get("title", ""), 40, Vector2(170, 20), Vector2(w - 190, 70), HORIZONTAL_ALIGNMENT_LEFT)
	var sub := _panel_label(panel, info.get("sub", ""), 26, Vector2(170, 90), Vector2(w - 190, 50), HORIZONTAL_ALIGNMENT_LEFT)
	sub.modulate.a = 0.7
	var body := _panel_label(panel, info.get("body", ""), 30, Vector2(24, 160), Vector2(w - 48, h - 280), HORIZONTAL_ALIGNMENT_LEFT)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if String(info.get("act", "")) != "":
		var ab := Button.new()
		ab.text = info.act
		ab.position = Vector2(24, h - 100)
		ab.size = Vector2(w - 48, 80)
		ab.add_theme_font_size_override("font_size", 34)
		ab.disabled = not bool(info.get("ok", true))
		ab.pressed.connect(func(): info.cb.call())
		panel.add_child(ab)




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
	art_pop_l.icon.text = d.icon
	art_pop_l.title.text = d.name_th
	art_pop_l.sub.text = "%s · %s" % [ARCH_TH.get(d.archetype, ""), RARITY_TH.get(d.rarity, "")]
	art_pop_l.body.text = d.text_th


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
		b.position.y = CARD_Y - (14.0 if i == slot_sel and d != null else 0.0)   # the picked card lifts out of the tray
		c.icon.text = d.icon if d != null else ""
		c.name.text = d.name_th if d != null else ""
		c.name.modulate = Color.WHITE
		c.sub.text = ("%d · %s" % [i + 1, ARCH_TH.get(d.archetype, "")]) if d != null else ""
		c.icon.modulate = Color.WHITE if d != null else Color(1, 1, 1, 0.45)
		var sb := StyleBoxFlat.new()
		var rc := Color(RARITY_COL.get(d.rarity, "#8aa0b8")) if d != null else Color(0, 0, 0, 0)
		sb.bg_color = Color("#3a2f55") if d != null else Color(0, 0, 0, 0)   # empty slot: nothing drawn, the tray shows through
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(6 if i == slot_sel else 3)
		sb.border_color = Color("#ffd966") if i == slot_sel else rc
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
	var owned := 0
	for o in slot_arr:
		if o != null:
			owned += 1
	cards_lbl.text = "การ์ด %d/%d" % [owned, SLOTS]
	art_pop.visible = slot_sel >= 0 and slot_arr[slot_sel] != null and not busy


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
	v_ash = sim.ash.duplicate()
	v_prev = sim.last_tiles().duplicate()


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
		return "🪙 +%d" % Sim.COIN_GEM
	var lv := 2 if c.ends_with("2") else 1
	var star := " ⭐" if lv == 2 else ""
	if c.begins_with("redcrit"):
		return "⚔ %d%s\n⚡ คริ 1/3" % [Sim.RED_DMG * lv, star]
	return ("⚔ %d%s" % [Sim.RED_DMG * lv, star]) if c.begins_with("red") else ("🛡 %d%s" % [Sim.BLUE_BLOCK * lv, star])


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
	tile_prev[i].visible = v_prev.has(i)
	if v_prev.has(i):
		var psb := StyleBoxFlat.new()
		var pc: Color = COL[v_prev[i]]
		psb.bg_color = Color(pc.r, pc.g, pc.b, 0.14)
		psb.set_border_width_all(6)
		psb.border_color = pc.lightened(0.15)
		psb.set_corner_radius_all(14)
		tile_prev[i].add_theme_stylebox_override("panel", psb)


func _hand_text(c: String) -> String:
	if c == "orange":
		return "🪙 +%d" % Sim.COIN_GEM
	var lv := 2 if c.ends_with("2") else 1
	var star := "⭐" if lv == 2 else ""
	if c.begins_with("redcrit"):
		return "⚔ %d%s ⚡" % [Sim.RED_DMG * lv, star]
	if c.begins_with("red"):
		return "⚔ %d%s" % [Sim.RED_DMG * lv, star]
	return ("🛡 %d%s" % [Sim.BLUE_BLOCK * lv, star]) if c.begins_with("blue") else ""


## Hand card look: flat transparent button, the colour lives in the diamond polygon behind it.
func _style_diamond(b: Button, c: String, picked: bool) -> void:
	var e := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, e)
	var dia: Polygon2D = b.get_meta("dia")
	var rim: Line2D = b.get_meta("rim")
	dia.color = COL[c] if c != "" else Color("#2a2438")
	rim.default_color = Color("#ffd966") if picked else Color(1, 1, 1, 0.3)
	rim.width = 8.0 if picked else 3.0
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))


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
	stage_lbl.text = "ด่าน %d" % stage
	boss_lbl.text = ("%s %s\n%s" % [v_boss.icon, v_boss.name_th, v_boss.text_th]) if v_boss != null else ""
	gold_lbl.text = "🪙 %d" % v_gold
	enemy_lbl.text = "👹 HP %d / %d" % [maxi(v_enemy_hp, 0), v_enemy_max]
	enemy_bar.max_value = v_enemy_max
	enemy_bar.value = maxi(v_enemy_hp, 0)
	var hidden := _smoke() and not flag_seen
	var where := "?" if hidden else ("%d, %d" % [v_flag + 1, v_flag2 + 1] if v_flag2 >= 0 else "%d" % (v_flag + 1))
	intent_lbl.text = "⚔ ตีแรง %d ที่ช่อง %s" % [roundi(v_strike), where]
	hp_lbl.text = "HP %d / %d" % [roundi(maxf(v_hp, 0.0)), roundi(v_max_hp)]
	hp_bar.max_value = v_max_hp
	hp_bar.value = maxf(v_hp, 0.0)
	for i in N:
		var g: Dictionary = v_board.get(i, {})
		var c: String = g.get("color", "")
		tile_btns[i].text = _gem_text(c).replace("
", " ") if c != "" else ("✦ +%d" % Sim.ASH_BONUS if v_ash.has(i) else "")
		if c == "" and v_ash.has(i):
			tile_btns[i].add_theme_color_override("font_color", COL["red" if v_ash[i] == "red" else v_ash[i]].lightened(0.35))
		else:
			tile_btns[i].remove_theme_color_override("font_color")
		_style_tile(i, c, c != "" and g.get("kept", false))
	var hx := 960.0 - (hand.size() * 221.0 - 21.0) * 0.5   # hand centred under the queue
	for i in hand_btns.size():
		hand_btns[i].visible = i < hand.size()
		if i >= hand.size():
			continue
		hand_btns[i].position.x = hx + i * 221.0
		var c: String = hand[i]
		hand_btns[i].text = _hand_text(c)
		hand_btns[i].disabled = c == "" or busy
		_style_diamond(hand_btns[i], c, i == selected)
	for i in tile_tabs.size():
		var lit := not hidden and (i == v_flag or i == v_flag2)
		tile_tabs[i].add_theme_stylebox_override("panel", _tab_style(lit))
	flag.position = Vector2(tile_btns[v_flag].position.x, ROW_Y - TAB_H - 10.0)
	flag.visible = not hidden
	flag2.visible = v_flag2 >= 0 and not hidden
	if v_flag2 >= 0:
		flag2.position = Vector2(tile_btns[v_flag2].position.x, ROW_Y - TAB_H - 10.0)
	go_btn.disabled = busy or over or sim.board.is_empty()
	discard_btn.text = "🗑 ทิ้ง (%d)" % sim.discards_left
	discard_btn.disabled = busy or over or selected < 0 or sim.discards_left <= 0
	deck_btn.text = "สำรับ\n%d / %d" % [sim.deck.size(), _deck_total()]
	deck_btn.disabled = busy or over
	_refresh_slots()


func _on_hand(i: int) -> void:
	if busy or hand[i] == "":
		return
	selected = -1 if selected == i else i
	sfx.play("place", 1.2, -8.0)
	_refresh()


func _deck_total() -> int:
	return Chaos.deck_total(sim)


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
	var names := {"red": "⚔ โจมตี", "red2": "⚔ โจมตี Lv2 ⭐", "redcrit": "⚔⚡ โจมตีคริ", "redcrit2": "⚔⚡ โจมตีคริ Lv2 ⭐", "orange": "🪙 เหรียญ", "blue": "🛡 โล่", "blue2": "🛡 โล่ Lv2 ⭐"}
	var y := 290.0
	var rows: Array = []
	for rc in ["red", "red2", "redcrit", "redcrit2", "orange", "blue", "blue2"]:
		if rc in ["red", "orange", "blue"] or int(sim.run_deck.get(rc, 0)) > 0:
			rows.append(rc)
	var row_step := 210.0 if rows.size() <= 3 else (170.0 if rows.size() == 4 else minf(170.0, 640.0 / rows.size()))
	for c in rows:
		var total := int(sim.run_deck.get(c, 0))
		var step := minf(76.0, 1500.0 / maxf(float(total), 1.0))
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
			t.position = Vector2(200 + i * step, y + 60)
			t.size = Vector2(step * 0.87, minf(90.0, row_step - 70.0))
			t.modulate.a = 1.0 if i < rem else 0.2
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deck_ui.add_child(t)
		y += row_step
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


## Charge: `count` small fireballs (= attack power) appear one by one in a ring around the
## source, pulsing and gathering, hold a beat, then all fly at the target together.
func _charge_volley(from: Vector2, to: Vector2, count: int, fill: Color, rim: Color) -> void:
	var n := clampi(count, 1, 12)
	var g0 := minf(0.12, 0.8 / n)   # first beat between balls; the gaps shrink to half, so the charge builds up
	var radius := 34.0 + 3.0 * n
	var balls: Array = []
	var pops: Array = []
	for i in n:
		var ball := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(13)
		sb.border_color = rim
		sb.set_border_width_all(4)
		ball.add_theme_stylebox_override("panel", sb)
		ball.size = Vector2(26, 26)
		ball.pivot_offset = Vector2(13, 13)
		var ang := TAU * i / n - PI * 0.5
		ball.position = from + Vector2(cos(ang), sin(ang)) * radius - Vector2(13, 13)
		ball.scale = Vector2.ZERO
		ball.z_index = 25
		add_child(ball)
		balls.append(ball)
		var tw := create_tween()
		tw.tween_property(ball, "scale", Vector2(1.5, 1.5), 0.06)
		tw.tween_property(ball, "scale", Vector2.ONE, 0.06)
		pops.append(tw)
		if sfx != null:
			sfx.step(i)
		var gap := g0 * lerpf(1.0, 0.5, float(i) / maxf(1.0, n - 1.0))
		await get_tree().create_timer(gap if i < n - 1 else 0.10).timeout
	# hold: one pulse and the ring coils in, then release
	for i in n:
		pops[i].kill()
		var ball: Panel = balls[i]
		var ang := TAU * i / n - PI * 0.5
		var pt := create_tween().set_parallel(true)
		pt.tween_property(ball, "scale", Vector2(1.3, 1.3), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pt.tween_property(ball, "position", from + Vector2(cos(ang), sin(ang)) * radius * 0.8 - Vector2(13, 13), 0.16)
		pt.chain().tween_property(ball, "scale", Vector2.ONE, 0.06)
	await get_tree().create_timer(0.16).timeout
	if sfx != null:
		sfx.play("whoosh", 1.0, -8.0)
	var last: Tween = null
	for i in n:
		var ball: Panel = balls[i]
		var spread := Vector2(0, (i - (n - 1) * 0.5) * 5.0)
		var tw := create_tween()
		tw.tween_interval(minf(0.015, 0.08 / n) * i)
		tw.tween_property(ball, "position", to - Vector2(13, 13) + spread, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(ball.queue_free)
		last = tw
	await last.finished


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


## True when pass event j lands on a tile where nothing happens (no pop, fire, strike...) and the
## walk keeps going the same way, so the fireball does not need to stop there.
func _pass_is_empty(evs: Array, j: int, prev_tile: int) -> bool:
	if prev_tile < 0 or j + 1 >= evs.size() or evs[j + 1].k != "pass":
		return false
	var t: int = evs[j].tile
	var n: int = evs[j + 1].tile
	return (prev_tile < t and t < n) or (prev_tile > t and t > n)


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
				elif _pass_is_empty(evs, j, prev_tile):
					pass   # nothing happens here: the fireball glides over it to the next tile that matters
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
				if ev.get("crit", false):
					_float_text("คริ! ×2", ENEMY_HOME + Vector2(60, -50), Color("#ffb347"))
					_shake(8.0)
					await get_tree().create_timer(0.12).timeout   # hit-stop on a crit
				if ev.get("nullified", false):
					_float_text("0", ENEMY_HOME + Vector2(60, 0), Color("#9a9aa6"))
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
						if ev.src == "base":
							var tb: Control = tile_btns[ev.tile]
							await _charge_volley(tb.position + tb.size * 0.5, _hero_c(), roundi(ev.amount), Color("#ff3b3b"), Color("#ffc2a8"))   # gather one ball per attack point, fly to the hero, then the beam fires at the enemy
						_laser(_hero_c(), _enemy_c(), Color.WHITE, 12.0)
						sfx.play("hit")
						_shake(6.0)
						_react(hero, HERO_HOME, 18.0, Color.WHITE)
						_react(enemy, ENEMY_HOME, 14.0, Color("#ff9a9a"))
						_float_text("-%d" % roundi(ev.amount), ENEMY_HOME + Vector2(60, 0), COL["red"])
						_tally_add(ev.src, roundi(ev.amount))
				else:
					if roundi(ev.amount) > 0:
						await _charge_volley(_enemy_c(), _hero_c(), roundi(ev.amount), Color("#a24dff"), Color("#e0c2ff"))   # enemy gathers one ball per attack point, then fires
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
				var st: int = int(ev.get("tile", -1))
				if st >= 0 and st < tile_btns.size() and ev.amount > 0:
					var sb: Control = tile_btns[st]
					await _charge_volley(sb.position + sb.size * 0.5, _hero_c(), roundi(ev.amount), Color("#3b8cff"), Color("#bfe0ff"))   # blue balls gather, then fly to the hero
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
			"ash":
				v_ash[ev.tile] = ev.kind
			"gold":
				var gt: int = int(ev.get("tile", -1))
				if ev.src == "base" and gt >= 0 and gt < tile_btns.size() and ev.amount > 0:
					var gb: Control = tile_btns[gt]
					await _charge_volley(gb.position + gb.size * 0.5, _hero_c(), roundi(ev.amount), Color("#ffa733"), Color("#ffe0a0"))   # coin Gem: orange balls gather and fly at the hero like attack / shield (not at the coin counter)
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
		tally_lbl = _label("", 56, Vector2(1040, 250), 400.0)
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
	if sim.kind == "elite":
		await _reward(Reward.offer(sim))
	await _shop()   # a shop visit after every fight
	stage += 1
	var next_plan := sim.plan(stage)
	await _blinds(stage)   # the enemy to fight and the next two, like a blind select
	hand = []   # the new fight has a fresh deck: nothing left over to discard
	sim.start_fight(stage, next_plan.boss, next_plan.kind)   # heals fully and clears the board
	_new_turn()


## Blind select (after the shop): the enemy of `first` and the next two, shown as cards.
## Only the first can be fought; the others are a preview.
signal _blind_done

func _blind_text(s: int) -> String:
	var p := sim.plan(s)
	var st := sim.enemy_stats(s, p.kind, p.boss)
	var head := "ด่าน %d\n\n" % s
	var who: String
	var extra := ""
	if p.boss != null:
		who = "%s %s\nบอส" % [p.boss.icon, p.boss.name_th]
		extra = "\n\n" + p.boss.text_th
	elif p.kind == "elite":
		who = "💀 ศัตรูแกร่ง"
		extra = "\n\nชนะแล้วเลือก Artifact 1 ใน 3"
	else:
		who = "⚔ ศัตรูปกติ"
	return "%s%s\n\n❤ %d   ⚔ %s%s" % [head, who, st.hp, str(roundi(st.dmg * 10.0) / 10.0), extra]


func _blind_data(s: int) -> Dictionary:
	var p := sim.plan(s)
	var st := sim.enemy_stats(s, p.kind, p.boss)
	var icon := "⚔"
	var title := "ศัตรูปกติ"
	var kind := ""
	var extra := ""
	if p.boss != null:
		icon = p.boss.icon
		title = p.boss.name_th
		kind = " · บอส"
		extra = "\n\n" + p.boss.text_th
	elif p.kind == "elite":
		icon = "💀"
		title = "ศัตรูแกร่ง"
		extra = "\n\nชนะแล้วเลือก Artifact 1 ใน 3"
	return {"icon": icon, "title": title, "sub": "ด่าน %d%s" % [s, kind], "kind": "enemy", "foot": "ด่าน %d" % s, "act": "", "ok": true,
		"body": "❤ %d   ⚔ %s%s" % [st.hp, str(roundi(st.dmg * 10.0) / 10.0), extra]}


func _blinds(first: int) -> void:
	reward_ui = Control.new()
	reward_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.z_index = 100
	add_child(reward_ui)
	_rw_clear("ศัตรูที่ต้องสู้")
	var n := mini(3, MAX_STAGE - first + 1)
	var panel := _detail_panel(Rect2(460, 450, 1000, 400))
	var cards: Array = []
	var x0 := (1920.0 - (n * 165.0 - 15.0)) * 0.5
	for i in n:
		_add_card(reward_ui, cards, panel, Vector2(x0 + i * 165.0, 200), _blind_data(first + i))
	_detail_show(panel, cards, 0)
	var go := _rw_button("สู้ ▶", Vector2(810, 890), Vector2(300, 100), 44)
	go.pressed.connect(func(): _blind_done.emit())
	await _blind_done
	reward_ui.queue_free()


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
	var panel := _detail_panel(Rect2(460, 450, 1000, 400))
	var cards: Array = []
	var x0 := (1920.0 - (offers.size() * 165.0 - 15.0)) * 0.5
	for i in offers.size():
		var d: Resource = offers[i]
		_add_card(reward_ui, cards, panel, Vector2(x0 + i * 165.0, 200), _art_info(d, "", "เลือก", true, _reward_pick.bind(d, offers)))
	var skip := _rw_button("ข้าม", Vector2(810, 890), Vector2(300, 100), 40)
	skip.pressed.connect(func(): reward_done.emit())


func _reward_pick(d: Resource, offers: Array) -> void:
	sfx.play("place", 1.3, -8.0)
	for i in SLOTS:
		if slot_arr[i] == null:
			slot_arr[i] = d
			reward_done.emit()
			return
	_rw_clear("ช่องเต็ม: เลือกช่องที่จะแทนด้วย %s %s" % [d.icon, d.name_th])
	var panel := _detail_panel(Rect2(460, 450, 1000, 400))
	var cards: Array = []
	var x0 := (1920.0 - (SLOTS * 165.0 - 15.0)) * 0.5
	for i in SLOTS:
		var o: Resource = slot_arr[i]
		_add_card(reward_ui, cards, panel, Vector2(x0 + i * 165.0, 200), _art_info(o, "ช่อง %d" % (i + 1), "แทนที่ด้วย %s %s" % [d.icon, d.name_th], true, func():
			slot_arr[i] = d
			reward_done.emit()))
	var back := _rw_button("กลับ", Vector2(810, 890), Vector2(300, 100), 40)
	back.pressed.connect(func(): _reward_offers(offers))


## Shop after a boss or on the shop door. Cards are small (same size as the game slots) and show only the icon and price;
## tap one to read it in the panel on the right and press its action button: 4 artifacts + 3 Chaos cards, 4 upgrades,
## the owned cards (sell for half price). Tab "Test" lists every card for free.
func _shop() -> void:
	reward_ui = Control.new()
	reward_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_ui.z_index = 100
	add_child(reward_ui)
	var stock: Array = Shop.stock(sim)
	var chaos_stock: Array = Chaos.stock(sim)
	var done := false
	var st := {"tab": 0, "rerolls": 0}
	while not done:
		_apply_slots()
		_rw_clear("ร้านค้า   🪙 %d" % sim.gold)
		for ti in 2:
			var tb := _rw_button(["ร้านค้า", "Test"][ti], Vector2(40 + ti * 190.0, 20), Vector2(180, 60), 30)
			tb.disabled = int(st.tab) == ti
			tb.pressed.connect(func():
				st.tab = ti
				_shop_step.emit(false))
		if int(st.tab) == 1:
			_shop_test_tab()
			var go_t := _rw_button("ไปต่อ ▶", Vector2(810, 960), Vector2(300, 80), 36)
			go_t.pressed.connect(func(): _shop_step.emit(true))
			done = await _shop_step
			continue
		var panel := _detail_panel(Rect2(1260, 110, 620, 520))
		var cards: Array = []
		var free := slot_arr.find(null)
		for i in stock.size():
			var d: Resource = stock[i]
			if d == null:
				continue   # already bought
			var cost := Shop.price(d)
			var can := sim.gold >= cost and free >= 0
			_add_card(reward_ui, cards, panel, Vector2(40 + i * 165.0, 110), _art_info(d, "%d 🪙" % cost, ("ซื้อ %d 🪙" % cost) if free >= 0 else "ช่องเต็ม: ขายก่อน", can, func():
				sim.gold -= cost
				slot_arr[free] = d
				stock[i] = null
				sfx.play("place", 1.3, -8.0)
				_shop_step.emit(false)))
		# Chaos cards: bought and used at once on the deck
		for i in chaos_stock.size():
			var cc = chaos_stock[i]
			if cc == null:
				continue   # already used
			var ccost := int(cc.price)
			_add_card(reward_ui, cards, panel, Vector2(740 + i * 165.0, 110), _chaos_info(cc, "%d 🪙" % ccost, "ใช้การ์ด %d 🪙" % ccost, sim.gold >= ccost, func():
				var picks: Array = [] if cc.kind == "global" else await _chaos_pick(cc)
				if (cc.kind == "global" or not picks.is_empty()) and Chaos.buy(sim, cc, picks):
					chaos_stock[i] = null
					sfx.play("place", 1.3, -8.0)
				_shop_step.emit(false)))
		# Upgrades
		var rc := Shop.reroll_cost(int(st.rerolls))
		var hc := Shop.hp_up_cost(sim)
		var hdc := Shop.hand_up_cost(sim)
		var maxed: bool = sim.hand_size >= Sim.MAX_HAND
		var dsc := Shop.discard_up_cost(sim)
		var dmaxed: bool = sim.discard_per_turn >= Sim.MAX_DISCARDS
		var ups := [
			{"icon": "❤", "title": "+%d HP สูงสุด" % Shop.HP_UP, "body": "เพิ่ม HP สูงสุดและฟื้นเท่ากัน\nตอนนี้ %d" % roundi(sim.max_hp), "cost": hc, "ok": sim.gold >= hc},
			{"icon": "✋", "title": "มือ +1 ช่อง", "body": "เพิ่มไพ่ในมือ 1 ช่อง\nตอนนี้ %d" % sim.hand_size, "cost": hdc, "ok": not maxed and sim.gold >= hdc, "max": maxed},
			{"icon": "🗑", "title": "ทิ้ง +1 ต่อรอบ", "body": "ทิ้งได้เพิ่ม 1 ครั้งต่อรอบ\nตอนนี้ %d" % sim.discard_per_turn, "cost": dsc, "ok": not dmaxed and sim.gold >= dsc, "max": dmaxed},
		]
		for i in ups.size():
			var u: Dictionary = ups[i]
			var label := "เต็มแล้ว" if u.get("max", false) else "%d 🪙" % u.cost
			_add_card(reward_ui, cards, panel, Vector2(40 + i * 165.0, 350), {"icon": u.icon, "title": u.title, "sub": "อัปเกรด", "body": u.body, "foot": label, "kind": "util",
				"state": "" if u.ok else "disabled", "act": "ซื้อ " + label, "ok": u.ok, "cb": func():
					match i:
						0:
							Shop.buy_hp(sim)
							_sync_hero()
						1:
							Shop.buy_hand(sim)
						2:
							Shop.buy_discard(sim)
					sfx.play("place", 1.3, -8.0)
					_shop_step.emit(false)})
		# Reroll is a plain button (not a card). Lambdas copy plain values, so the counter lives in `st` and the stock array is refilled in place.
		var rb := _rw_button("🎲 สุ่มใหม่  %d 🪙" % rc, Vector2(560, 400), Vector2(340, 110), 34)
		rb.disabled = sim.gold < rc
		rb.pressed.connect(func():
			sim.gold -= rc
			st.rerolls = int(st.rerolls) + 1
			stock.assign(Shop.stock(sim))
			sfx.play("place", 1.3, -8.0)
			_shop_step.emit(false))
		# Owned cards: sell
		for i in SLOTS:
			var o = slot_arr[i]
			var pos := Vector2(40 + i * 165.0, 590)
			if o == null:
				_make_card(reward_ui, pos, CARD_SZ, {"state": "empty", "kind": "art"})
				continue
			var sell := Shop.sell_value(o)
			_add_card(reward_ui, cards, panel, pos, _art_info(o, "+%d 🪙" % sell, "ขาย +%d 🪙" % sell, true, func():
				sim.gold += sell
				slot_arr[i] = null
				sfx.play("place", 1.0, -8.0)
				_shop_step.emit(false)))
		var go := _rw_button("ไปต่อ ▶", Vector2(810, 920), Vector2(300, 100), 40)
		go.pressed.connect(func(): _shop_step.emit(true))
		done = await _shop_step
	reward_ui.queue_free()
	slot_sel = -1
	_apply_slots()
	_refresh_slots()
	v_gold = sim.gold


## Test tab: every artifact and every Chaos card, free. Artifact: take / return a slot. Chaos: use on the run deck.
func _shop_test_tab() -> void:
	var panel := _detail_panel(Rect2(1400, 110, 480, 520))
	var cards: Array = []
	var arts: Array = Catalog.all()
	var free := slot_arr.find(null)
	for i in arts.size():
		var d: Resource = arts[i]
		var idx := slot_arr.find(d)
		var info := _art_info(d, "✔" if idx >= 0 else "", "คืนช่อง" if idx >= 0 else "ใช้ฟรี", idx >= 0 or free >= 0, func():
			if idx >= 0:
				slot_arr[idx] = null
			else:
				slot_arr[free] = d
			sfx.play("place", 1.3, -8.0)
			_shop_step.emit(false))
		if idx >= 0:
			info["state"] = ""
		_add_card(reward_ui, cards, panel, Vector2(40 + (i % 8) * 165.0, 110 + (i / 8) * 230.0), info)
		if idx >= 0:
			cards[cards.size() - 1].btn.add_theme_stylebox_override("normal", _card_style("art", d.rarity, "owned", "normal"))
	for i in Chaos.CARDS.size():
		var cc: Dictionary = Chaos.CARDS[i]
		var used: bool = cc.id == "ashes" and sim.ashes
		_add_card(reward_ui, cards, panel, Vector2(40 + i * 165.0, 580), _chaos_info(cc, "ฟรี", "ใช้ฟรี", not used, func():
			var free_cc: Dictionary = cc.duplicate()
			free_cc.price = 0
			var picks: Array = [] if cc.kind == "global" else await _chaos_pick(free_cc)
			if (cc.kind == "global" or not picks.is_empty()) and Chaos.buy(sim, free_cc, picks):
				sfx.play("place", 1.3, -8.0)
			_shop_step.emit(false)))


## Chaos picker: choose which Gems of the run deck the card works on (one tap = one Gem).
## Returns the chosen colours, or [] when cancelled.
signal _chaos_step(act: String)

func _chaos_pick(card: Dictionary) -> Array:
	var picks: Array = []
	var names := {"red": "⚔ แดง", "red2": "⚔ แดง ⭐", "redcrit": "⚔⚡ แดงคริ", "redcrit2": "⚔⚡ แดงคริ ⭐", "orange": "🪙 ส้ม", "blue": "🛡 น้ำเงิน", "blue2": "🛡 น้ำเงิน ⭐"}
	var result: Array = []
	while true:
		_rw_clear("%s %s" % [card.icon, card.name])
		var info := Label.new()
		var chosen := "  ".join(picks.map(func(c): return names[c]))
		info.text = "%s\n\nเลือกแล้ว %d / %d :  %s\nสำรับตอนนี้ %d ใบ" % [card.text, picks.size(), int(card.picks), chosen, Chaos.deck_total(sim)]
		info.add_theme_font_size_override("font_size", 36)
		info.position = Vector2(0, 170)
		info.size = Vector2(1920, 300)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_ui.add_child(info)
		var cols: Array = []
		for cn in Chaos.COLORS:
			if cn in ["red", "orange", "blue"] or int(sim.run_deck.get(cn, 0)) > 0:
				cols.append(cn)
		var bw := 320.0 if cols.size() <= 4 else 230.0
		var bx0 := (1920.0 - (cols.size() * (bw + 30.0) - 30.0)) * 0.5
		for ci in cols.size():
			var c: String = cols[ci]
			var used := picks.count(c)
			var left := int(sim.run_deck.get(c, 0)) - used
			var b := _rw_button("%s\nในสำรับ %d" % [names[c], left], Vector2(bx0 + ci * (bw + 30.0), 500), Vector2(bw, 200), 36 if cols.size() <= 4 else 28)
			b.disabled = left <= 0 or picks.size() >= int(card.picks) or (card.kind == "convert" and c == card.to) or (card.has("only") and c.trim_suffix("2") != card.only) or (card.kind == "upgrade" and not Chaos.UP.has(c))
			b.pressed.connect(func(): _chaos_step.emit("pick:" + c))
		var ok_b := _rw_button("ใช้การ์ด %d 🪙" % int(card.price), Vector2(560, 800), Vector2(380, 100), 40)
		ok_b.disabled = not Chaos.valid(sim, card, picks)
		ok_b.pressed.connect(func(): _chaos_step.emit("ok"))
		var clr := _rw_button("ล้างที่เลือก", Vector2(960, 800), Vector2(220, 100), 32)
		clr.disabled = picks.is_empty()
		clr.pressed.connect(func(): _chaos_step.emit("clear"))
		var cancel := _rw_button("ยกเลิก", Vector2(1200, 800), Vector2(200, 100), 32)
		cancel.pressed.connect(func(): _chaos_step.emit("cancel"))
		var act: String = await _chaos_step
		if act.begins_with("pick:"):
			picks.append(act.substr(5))
		elif act == "clear":
			picks.clear()
		elif act == "ok":
			result = picks
			break
		else:
			break
	return result


signal _shop_step(leave: bool)
