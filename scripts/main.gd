extends Control

# ==============================================================================
# To Beyond - Godot 4 Full Implementation
# Faithfully matching To_Beyond_Draft.html Logic 100%
# ==============================================================================

const N_TILES: int = 8
const TILE_DIR: Array[String] = ["N", "N", "E", "E", "S", "S", "W", "W"]
const COLOR_ORDER: Array[String] = ["red", "green", "orange", "blue"]
const DIR_ORDER: Array[String] = ["N", "E", "S", "W"]
const BOSS_PICS: Array[String] = ["👹", "👺", "👻", "💀", "🐲", "🧟"]

const COLORS = {
	"red": Color("#d63a3a"),
	"green": Color("#2e9e5b"),
	"orange": Color("#f08a24"),
	"blue": Color("#2f7fd6"),
	"blank": Color("#555566"),
	"empty_tile": Color("#2b2250"),
	"brass": Color("#d3a64a"),
	"brass_bright": Color("#f0cf86"),
	"gold": Color("#F2B63C"),
	"bg": Color("#1f1836"),
	"text_dim": Color("#a79fc4"),
	"text_bright": Color("#f3ead7")
}

var EMBLEMS = {}
var BALL_TEXTURE: Texture2D = null

func init_textures() -> void:
	for d in ["N", "E", "S", "W"]:
		var p = "res://assets/emblems/emblem_%s.svg" % d.to_lower()
		if ResourceLoader.exists(p):
			EMBLEMS[d] = load(p)
	if ResourceLoader.exists("res://assets/ball.svg"):
		BALL_TEXTURE = load("res://assets/ball.svg")

# --- Stone Formulas ---
var stone_formulas = [
	{"key": "col", "name": "สีเรียงกัน", "desc": "สีเดียวกันวางติดกัน (ใบเดี่ยวนับด้วย)", "min": 1, "a": 1, "g": 1},
	{"key": "dsame", "name": "ทิศเรียงกัน", "desc": "ทิศของการ์ดเหมือนกันวางติดกัน", "min": 2, "a": 2, "g": 1},
	{"key": "alt", "name": "สลับสี", "desc": "สองสีวางสลับกัน (3 ใบขึ้นไป)", "min": 3, "a": 3, "g": 1},
	{"key": "dtile", "name": "ทิศตรงช่อง", "desc": "ทิศการ์ดตรงกับช่องทุกใบ", "min": 1, "a": 2, "g": 2},
	{"key": "cd", "name": "สีทิศ", "desc": "สีเดียวกัน และทิศตรงช่องทุกใบ", "min": 2, "a": 3, "g": 3},
	{"key": "twin", "name": "ฝาแฝด", "desc": "การ์ดเหมือนกันทั้งสีและทิศ วางติดกัน", "min": 2, "a": 4, "g": 4}
]

# --- Progression & Stat Limits (Matching Draft) ---
const EATK_START: int = 10
const PHP_GROW: float = 1.2
const WALK_START: int = 3
const DISCARD_START: int = 3
const HAND_START: int = 8
const HAND_CAP: int = 12
const BOSS_BLANKS: int = 15

var walk_max: int = WALK_START
var discard_max: int = DISCARD_START
var hand_max: int = HAND_START

var enemy_atk: int = EATK_START
var walks_left: int = WALK_START
var discards_left: int = DISCARD_START

var player_max_hp: int = enemy_atk * walk_max
var player_hp: int = player_max_hp

var enemy_max_hp: int = 50
var enemy_hp: int = 50

# --- State Variables ---
var deck: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var placed_cards: Dictionary = {} # tile_idx -> card dict
var selected_card_ids: Array[int] = []
var card_uid_counter: int = 0

var stage: int = 1
var coins: int = 0
var sort_mode: String = "color" # "color" or "dir"

var is_busy: bool = false
var speed_multiplier: float = 1.0
var discovered_formulas: Array[String] = ["col"]

func is_boss() -> bool:
	return stage % 3 == 0

# --- Artifact System ---
const MAX_ARTIFACTS: int = 5
var artifacts: Array = []  # Array of null or Dict

const ARTIFACT_CATALOG: Array[Dictionary] = [
	{"type": "add5",        "name": "Gem Blade",       "icon": "⚔️", "desc": "+10 ATK เพิ่มเติมเมื่อยิงโจมตี",          "color": Color("#2f7fd6"), "price": 5},
	{"type": "mult2",       "name": "Rune Lens",        "icon": "🔮", "desc": "ตัวคูณ +5 ก่อนคิดดาเมจสุดท้าย",          "color": Color("#d63a3a"), "price": 6},
	{"type": "reverse",     "name": "Mirror Walk",      "icon": "↩️", "desc": "ลูกไฟเดินย้อนกลับอีกรอบ +50% ATK รวม",   "color": Color("#a66cf2"), "price": 6},
	{"type": "emptyAtk",    "name": "Empty Fist",       "icon": "👊", "desc": "+2 ATK ต่อช่องกระดานที่ว่างเปล่า",       "color": Color("#a66cf2"), "price": 6},
	{"type": "firstGem",    "name": "First Strike",     "icon": "🥇", "desc": "+8 ATK สำหรับการ์ดในช่องแรก",           "color": Color("#f08a24"), "price": 6},
	{"type": "walkCoin",    "name": "Gold Step",        "icon": "👟", "desc": "รับ 🪙 1 เหรียญต่อรอบเดินที่เหลือเมื่อชนะ", "color": Color("#f08a24"), "price": 6},
	{"type": "stoneUp",     "name": "Stone Carver",     "icon": "🪨", "desc": "ตัวสะสมพลัง Stone: ตัวคูณ ×1.5",        "color": Color("#a66cf2"), "price": 7},
	{"type": "freediscard", "name": "Wild Shuffle",     "icon": "♻️", "desc": "ทิ้งการ์ดได้แม้มี Gem วางอยู่บนกระดาน",   "color": Color("#2e9e5b"), "price": 8},
	{"type": "atk15",       "name": "Power Core",       "icon": "⚡", "desc": "ATK รวมทั้งหมด ×1.5",                    "color": Color("#2f7fd6"), "price": 8},
	{"type": "greenCoin",   "name": "Coin Hoard",       "icon": "🪙", "desc": "รับดอกเบี้ย +1🪙 ต่อ 5🪙 ที่ถือไว้ (สูงสุด 10)", "color": Color("#2e9e5b"), "price": 6},
]

# --- Node References ---
@onready var stage_label: Label = $TopBar/StageLabel
@onready var coins_label: Label = $TopBar/CoinsLabel
@onready var speed_btn: Button = $TopBar/SpeedBtn
@onready var restart_btn: Button = $TopBar/RestartBtn

@onready var hero_hp_bar: ProgressBar = $Preview/HeroCol/HeroHPBar
@onready var hero_hp_label: Label = $Preview/HeroCol/HeroHPText
@onready var hero_pic: Label = $Preview/HeroCol/HeroPic
@onready var calc_label: Label = $Preview/CenterCol/CalcLabel

@onready var enemy_name: Label = $Preview/EnemyCol/EnemyName
@onready var enemy_pic: Label = $Preview/EnemyCol/EnemyPic
@onready var enemy_hp_bar: ProgressBar = $Preview/EnemyCol/EnemyHPBar
@onready var enemy_hp_label: Label = $Preview/EnemyCol/EnemyHPText
@onready var enemy_atk_label: Label = $Preview/EnemyCol/EnemyAtkText
@onready var msg_label: Label = $Preview/EnemyCol/MsgLabel

# Artifact Row
@onready var artifact_row: HBoxContainer = $ArtifactRow

# Effects Layer References
@onready var effects_layer: Control = $EffectsLayer
@onready var beam_line: Line2D = $EffectsLayer/BeamLine
@onready var enemy_beam_line: Line2D = $EffectsLayer/EnemyBeamLine
@onready var toast: PanelContainer = $EffectsLayer/Toast
@onready var toast_label: Label = $EffectsLayer/Toast/ToastLabel

@onready var tiles_container: HBoxContainer = $BoardSection/TilesContainer
@onready var gstrip_container: HBoxContainer = $BoardSection/GstripContainer
@onready var token: Control = $BoardSection/Token

@onready var hand_container: HBoxContainer = $BottomSection/HandContainer
@onready var deck_count_btn: Button = $BottomSection/ControlsRow/ToolCol/DeckCountBtn
@onready var stone_btn: Button = $BottomSection/ControlsRow/ToolCol/StoneBtn
@onready var sort_color_btn: Button = $BottomSection/ControlsRow/ActionCol/SortGroup/SortColorBtn
@onready var sort_dir_btn: Button = $BottomSection/ControlsRow/ActionCol/SortGroup/SortDirBtn
@onready var walk_btn: Button = $BottomSection/ControlsRow/ActionCol/WalkBtn
@onready var discard_btn: Button = $BottomSection/ControlsRow/ActionCol/DiscardBtn

# Modals
@onready var reward_modal: PanelContainer = $RewardModal
@onready var reward_info: Label = $RewardModal/VBox/RewardInfo
@onready var reward_next_btn: Button = $RewardModal/VBox/NextBtn

@onready var gameover_modal: PanelContainer = $GameOverModal
@onready var gameover_info: Label = $GameOverModal/VBox/GameOverInfo
@onready var gameover_btn: Button = $GameOverModal/VBox/RetryBtn

@onready var stone_modal: PanelContainer = $StoneModal
@onready var stone_list: VBoxContainer = $StoneModal/VBox/Scroll/List
@onready var stone_close_btn: Button = $StoneModal/VBox/CloseBtn

# Deck Modal
@onready var deck_modal: PanelContainer = $DeckModal
@onready var deck_modal_list: VBoxContainer = $DeckModal/VBox/Scroll/List
@onready var deck_modal_close_btn: Button = $DeckModal/VBox/CloseBtn

# Shop Modal
@onready var shop_modal: PanelContainer = $ShopModal
@onready var shop_coins_label: Label = $ShopModal/ShopVBox/ShopHeader/ShopCoinsLabel
@onready var shop_leave_btn: Button = $ShopModal/ShopVBox/ShopHeader/ShopLeaveBtn
@onready var shop_items_container: HBoxContainer = $ShopModal/ShopVBox/ShopItemsScroll/ShopItemsContainer
@onready var shop_offer_container: HBoxContainer = $ShopModal/ShopVBox/ShopOfferScroll/ShopOfferContainer


func _ready() -> void:
	init_textures()
	setup_token_visual()
	connect_ui_signals()
	setup_stone_modal_content()
	start_new_game()


func setup_token_visual() -> void:
	token.custom_minimum_size = Vector2(48, 64)
	if BALL_TEXTURE != null:
		var tex_rect = TextureRect.new()
		tex_rect.name = "BallTexture"
		tex_rect.texture = BALL_TEXTURE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(44, 60)
		token.add_child(tex_rect)
	else:
		var lbl = Label.new()
		lbl.text = "🔥"
		lbl.add_theme_font_size_override("font_size", 34)
		token.add_child(lbl)


func connect_ui_signals() -> void:
	restart_btn.pressed.connect(start_new_game)
	speed_btn.pressed.connect(_on_speed_toggle)
	deck_count_btn.pressed.connect(open_deck_modal)
	deck_modal_close_btn.pressed.connect(func(): deck_modal.visible = false)
	walk_btn.pressed.connect(_on_walk_pressed)
	discard_btn.pressed.connect(_on_discard_pressed)
	sort_color_btn.pressed.connect(func(): set_sort_mode("color"))
	sort_dir_btn.pressed.connect(func(): set_sort_mode("dir"))
	stone_btn.pressed.connect(func(): stone_modal.visible = true)
	stone_close_btn.pressed.connect(func(): stone_modal.visible = false)
	reward_next_btn.pressed.connect(_on_reward_shop_pressed)
	gameover_btn.pressed.connect(start_new_game)
	shop_leave_btn.pressed.connect(_on_shop_leave)

	# Connect tile click events
	for i in range(N_TILES):
		var tile_btn = tiles_container.get_child(i) as Button
		var idx = i
		tile_btn.pressed.connect(func(): _on_tile_clicked(idx))

	# Connect artifact slot buttons
	for i in range(MAX_ARTIFACTS):
		var slot = artifact_row.get_child(i + 1) as Button
		var slot_idx = i
		slot.pressed.connect(func(): _on_artifact_slot_pressed(slot_idx))


# ==============================================================================
# Game Loop & Initializations
# ==============================================================================

func start_new_game() -> void:
	stage = 1
	coins = 0
	walk_max = WALK_START
	discard_max = DISCARD_START
	hand_max = HAND_START

	enemy_atk = EATK_START
	walks_left = walk_max
	discards_left = discard_max

	player_max_hp = enemy_atk * walk_max
	player_hp = player_max_hp

	enemy_max_hp = 50
	enemy_hp = enemy_max_hp

	is_busy = false
	hand.clear()
	placed_cards.clear()
	selected_card_ids.clear()
	artifacts.clear()
	for i in range(MAX_ARTIFACTS): artifacts.append(null)
	discovered_formulas = ["col"]

	reward_modal.visible = false
	gameover_modal.visible = false
	stone_modal.visible = false
	shop_modal.visible = false
	deck_modal.visible = false
	token.visible = false

	enemy_pic.modulate = Color.WHITE
	enemy_pic.scale = Vector2.ONE
	hero_pic.modulate = Color.WHITE
	hero_pic.scale = Vector2.ONE

	build_deck()
	spawn_current_enemy()


func spawn_current_enemy() -> void:
	var boss_idx = (stage - 1) % BOSS_PICS.size()
	enemy_pic.text = BOSS_PICS[boss_idx]
	if is_boss():
		enemy_name.text = "👑 บอสใหญ่ ด่าน %d" % stage
		boss_skill()
	else:
		enemy_name.text = "ศัตรู ด่าน %d" % stage

	start_new_round()


func boss_skill() -> void:
	if not is_boss(): return
	for i in range(BOSS_BLANKS):
		deck.append({
			"id": card_uid_counter,
			"color": "blank",
			"dir": "blank",
			"is_blank": true,
			"gold": false
		})
		card_uid_counter += 1
	deck.shuffle()
	msg_label.text = "⚠️ บอสใส่การ์ดเปล่า 15 ใบเข้าสำรับ (ชั่วคราว)!"


func build_deck() -> void:
	deck.clear()
	card_uid_counter = 0
	for col in COLOR_ORDER:
		for dir in DIR_ORDER:
			for k in range(3):
				deck.append({
					"id": card_uid_counter,
					"color": col,
					"dir": dir,
					"is_blank": false,
					"gold": false
				})
				card_uid_counter += 1
	deck.shuffle()


func draw_up_to_hand(target_count: int) -> void:
	while hand.size() < target_count and deck.size() > 0:
		hand.append(deck.pop_back())


func start_new_round() -> void:
	placed_cards.clear()
	selected_card_ids.clear()
	draw_up_to_hand(hand_max)
	update_all_ui()
	refresh_calc()


# ==============================================================================
# Rendering: Tiles, Hand & UI
# ==============================================================================

func update_all_ui() -> void:
	stage_label.text = "ด่านที่: %d" % stage
	coins_label.text = "🪙 เหรียญ: %d" % coins
	deck_count_btn.text = "🂠 กองการ์ด: %d ใบ 🔍" % deck.size()

	hero_hp_label.text = "HP %d / %d" % [player_hp, player_max_hp]
	hero_hp_bar.max_value = player_max_hp
	hero_hp_bar.value = player_hp

	enemy_hp_label.text = "HP %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_atk_label.text = "⚔ โจมตี %d" % enemy_atk

	walk_btn.disabled = is_busy or (walks_left <= 0 and selected_card_ids.is_empty())
	if selected_card_ids.size() > 0:
		walk_btn.text = "วางการ์ด (%d)" % selected_card_ids.size()
	else:
		walk_btn.text = "เดิน (%d รอบ)" % walks_left

	# Rule: If board has cards, cannot discard unless freediscard artifact is owned
	var blocked = (placed_cards.size() > 0) and (not has_artifact("freediscard"))
	discard_btn.disabled = is_busy or discards_left <= 0 or selected_card_ids.is_empty() or blocked

	if blocked:
		discard_btn.text = "วาง Gem แล้วทิ้งไม่ได้"
	elif selected_card_ids.size() > 0:
		discard_btn.text = "ทิ้ง Gem (%d) [%d รอบ]" % [selected_card_ids.size(), discards_left]
	else:
		discard_btn.text = "ทิ้ง Gem (%d รอบ)" % discards_left

	render_tiles()
	render_hand()
	render_artifact_row()


func render_tiles() -> void:
	for i in range(N_TILES):
		var tile_btn = tiles_container.get_child(i) as Button
		var t_dir = TILE_DIR[i]

		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_width_left = 3
		sb.border_width_right = 3

		if placed_cards.has(i):
			var card = placed_cards[i]
			var is_blank = card.get("is_blank", false)

			if is_blank:
				sb.bg_color = Color("#3a3a48")
				sb.border_color = Color("#777788")
				tile_btn.icon = null
				tile_btn.text = "%d\n\n[การ์ดเปล่า]" % (i + 1)
				tile_btn.modulate = Color(0.8, 0.8, 0.8)
			else:
				var c_dir = card["dir"]
				var c_col = card["color"]
				var is_match = (c_dir == t_dir)

				sb.bg_color = COLORS.get(c_col, COLORS["empty_tile"]).darkened(0.2)
				sb.border_color = COLORS["gold"] if is_match else COLORS["brass"]

				var icon_tex = EMBLEMS.get(c_dir)
				if icon_tex != null:
					tile_btn.icon = icon_tex
					tile_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					tile_btn.expand_icon = true
					tile_btn.text = "%d\n\n%s" % [i + 1, "★ GOLD" if is_match else ""]
				else:
					tile_btn.icon = null
					tile_btn.text = "#%d\n%s\n%s" % [i + 1, c_dir, "★ GOLD" if is_match else ""]
				tile_btn.modulate = COLORS["gold"] if is_match else Color.WHITE

			tile_btn.add_theme_stylebox_override("normal", sb)
			tile_btn.add_theme_stylebox_override("hover", sb)
			tile_btn.add_theme_stylebox_override("pressed", sb)
		else:
			sb.bg_color = COLORS["empty_tile"]
			sb.border_color = COLORS["brass"]
			var icon_tex = EMBLEMS.get(t_dir)
			if icon_tex != null:
				tile_btn.icon = icon_tex
				tile_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tile_btn.expand_icon = true
				tile_btn.text = "%d\n\n" % (i + 1)
			else:
				tile_btn.icon = null
				tile_btn.text = "#%d\n%s\n" % [i + 1, t_dir]
			tile_btn.modulate = Color(0.65, 0.65, 0.75)
			tile_btn.add_theme_stylebox_override("normal", sb)
			tile_btn.add_theme_stylebox_override("hover", sb)
			tile_btn.add_theme_stylebox_override("pressed", sb)


func render_hand() -> void:
	if sort_mode == "color":
		hand.sort_custom(func(a, b):
			var ca = COLOR_ORDER.find(a["color"])
			var cb = COLOR_ORDER.find(b["color"])
			if ca != cb: return ca < cb
			return DIR_ORDER.find(a["dir"]) < DIR_ORDER.find(b["dir"])
		)
	else:
		hand.sort_custom(func(a, b):
			var da = DIR_ORDER.find(a["dir"])
			var db = DIR_ORDER.find(b["dir"])
			if da != db: return da < db
			return COLOR_ORDER.find(a["color"]) < COLOR_ORDER.find(b["color"])
		)

	for child in hand_container.get_children():
		child.queue_free()

	for card in hand:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(76, 104)
		var is_sel = selected_card_ids.has(card["id"])
		var is_blank = card.get("is_blank", false)

		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.border_width_top = 3 if is_sel else 2
		sb.border_width_bottom = 3 if is_sel else 2
		sb.border_width_left = 3 if is_sel else 2
		sb.border_width_right = 3 if is_sel else 2

		if is_blank:
			sb.bg_color = Color("#40404e")
			sb.border_color = Color("#ffd966") if is_sel else Color("#888899")
			btn.icon = null
			btn.text = "⬜\n[การ์ดเปล่า]%s" % ["\n▲ เลือก" if is_sel else ""]
			btn.tooltip_text = "การ์ดเปล่าจากสกิลบอส ไม่มีสีไม่มีทิศ (แนะนำให้เลือกทิ้ง Discard)"
		else:
			var c_col = card["color"]
			var c_dir = card["dir"]
			sb.bg_color = COLORS.get(c_col, Color.GRAY)
			sb.border_color = COLORS["brass_bright"] if is_sel else COLORS["brass"]

			var icon_tex = EMBLEMS.get(c_dir)
			if icon_tex != null:
				btn.icon = icon_tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.expand_icon = true
				if is_sel:
					btn.text = "▲ เลือก"
					btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				else:
					btn.text = ""
			else:
				btn.icon = null
				btn.text = "%s\n%s%s" % [c_col.to_upper(), c_dir, "\n✓ เลือก" if is_sel else ""]

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

		var card_id = card["id"]
		btn.pressed.connect(func(): _on_hand_card_clicked(card_id))
		hand_container.add_child(btn)


func set_sort_mode(mode: String) -> void:
	sort_mode = mode
	sort_color_btn.button_pressed = (mode == "color")
	sort_dir_btn.button_pressed = (mode == "dir")
	render_hand()


# ==============================================================================
# Interactions & Auto Placement
# ==============================================================================

func _on_hand_card_clicked(card_id: int) -> void:
	if is_busy: return
	if selected_card_ids.has(card_id):
		selected_card_ids.erase(card_id)
	else:
		selected_card_ids.append(card_id)
	update_all_ui()
	refresh_calc()


func _on_tile_clicked(tile_idx: int) -> void:
	if is_busy: return

	# Rule: If tile already has card, return it to hand!
	if placed_cards.has(tile_idx):
		if hand.size() >= hand_max:
			msg_label.text = "⚠️ มือเต็ม เอา Gem กลับไม่ได้"
			return
		var card = placed_cards[tile_idx]
		placed_cards.erase(tile_idx)
		hand.append(card)
		update_all_ui()
		refresh_calc()
		return

	# If exactly one card selected in hand, place it here
	if selected_card_ids.size() == 1:
		var target_id = selected_card_ids[0]
		var found_card = null
		for card in hand:
			if card["id"] == target_id:
				found_card = card
				break
		if found_card != null:
			hand.erase(found_card)
			placed_cards[tile_idx] = found_card
			selected_card_ids.clear()
			update_all_ui()
			refresh_calc()


func _on_discard_pressed() -> void:
	if is_busy or selected_card_ids.is_empty() or discards_left <= 0:
		return
	if placed_cards.size() > 0 and not has_artifact("freediscard"):
		msg_label.text = "⚠️ วาง Gem แล้วทิ้งไม่ได้ (ดึง Gem กลับก่อน)"
		return

	discards_left -= 1
	var to_remove = []
	for card in hand:
		if selected_card_ids.has(card["id"]):
			to_remove.append(card)
	for card in to_remove:
		hand.erase(card)
	selected_card_ids.clear()
	draw_up_to_hand(hand_max)
	update_all_ui()
	refresh_calc()


# ==============================================================================
# Stone Calculations & Group Combinations (Matching Draft calcGroups)
# ==============================================================================

func calculate_groups() -> Dictionary:
	var used: Array[int] = []
	var groups: Array = []
	var grp_val: Dictionary = {} # tile_idx -> ATK per gem

	while true:
		var cands: Array = []
		for s0 in range(N_TILES):
			if used.has(s0) or not placed_cards.has(s0) or placed_cards[s0].get("is_blank", false):
				continue
			for e0 in range(s0, N_TILES):
				if used.has(e0) or not placed_cards.has(e0) or placed_cards[e0].get("is_blank", false):
					break
				var idxs: Array[int] = []
				for q in range(s0, e0 + 1):
					idxs.append(q)
				var n = idxs.size()

				var first_col = placed_cards[s0]["color"]
				var first_dir = placed_cards[s0]["dir"]

				var same_col = true
				var same_dir = true
				var dtile = true

				for idx in idxs:
					var c = placed_cards[idx]
					if c["color"] != first_col: same_col = false
					if c["dir"] != first_dir: same_dir = false
					if c["dir"] != TILE_DIR[idx]: dtile = false

				var alt_col = false
				if n >= 3:
					alt_col = (placed_cards[idxs[0]]["color"] != placed_cards[idxs[1]]["color"])
					for q in range(2, n):
						if placed_cards[idxs[q]]["color"] != placed_cards[idxs[q - 2]]["color"]:
							alt_col = false
							break

				var f = {
					"col": same_col,
					"dsame": same_dir,
					"alt": alt_col,
					"dtile": dtile,
					"cd": same_col and dtile,
					"twin": same_col and same_dir
				}

				var best_k = -1
				var best_v = 0
				for k in range(stone_formulas.size()):
					var r = stone_formulas[k]
					if f.get(r["key"], false) and n >= r["min"]:
						var v = r["a"] + r["g"] * (n - 1)
						if v > best_v or (v == best_v and k > best_k):
							best_v = v
							best_k = k

				if best_k >= 0:
					cands.append({
						"type": stone_formulas[best_k]["key"],
						"name": stone_formulas[best_k]["name"],
						"idxs": idxs,
						"col": first_col if same_col else null,
						"res": {"a": best_v, "k": best_k, "tot": best_v * n}
					})

		var best = null
		for g in cands:
			if best == null:
				best = g
				continue
			var b = best
			if g["res"]["tot"] > b["res"]["tot"] or (g["res"]["tot"] == b["res"]["tot"] and (g["res"]["a"] > b["res"]["a"] or (g["res"]["a"] == b["res"]["a"] and g["idxs"].size() > b["idxs"].size()))):
				best = g

		if best == null:
			break

		for i in best["idxs"]:
			used.append(i)
			grp_val[i] = best["res"]["a"]
		groups.append(best)

	# Sum of base damage from all cards on board
	var total_base_dmg = 0
	for i in range(N_TILES):
		if placed_cards.has(i) and not placed_cards[i].get("is_blank", false):
			total_base_dmg += grp_val.get(i, 1)

	return {
		"groups": groups,
		"grp_val": grp_val,
		"base_dmg": total_base_dmg
	}


func refresh_calc() -> void:
	var result = calculate_groups()
	var base_dmg = result["base_dmg"]

	var atk = 1 + base_dmg
	var mult = 1.0

	# Pre-evaluate Artifacts (attackSeq preview)
	if has_artifact("add5"):
		atk += 10
	if has_artifact("mult2"):
		mult += 5.0
	if has_artifact("emptyAtk"):
		atk += 2 * (N_TILES - placed_cards.size())
	if has_artifact("atk15"):
		atk = int(atk * 1.5)
	if has_artifact("firstGem") and placed_cards.has(0):
		atk += 8
	if has_artifact("stoneUp"):
		mult *= 1.5
	if has_artifact("reverse"):
		atk = int(atk * 1.5)

	var final_dmg = int(atk * mult)
	calc_label.text = "%d   ×   %.2f   =   ดาเมจ: %d" % [atk, mult, final_dmg]

	# Check for new Stone formula discoveries
	for g in result["groups"]:
		var key = g["type"]
		if not discovered_formulas.has(key):
			discovered_formulas.append(key)
			show_discovery_toast(key)

	# Update Gstrip badges
	for i in range(N_TILES):
		var lbl = gstrip_container.get_child(i) as Label
		if placed_cards.has(i) and not placed_cards[i].get("is_blank", false):
			var val = result["grp_val"].get(i, 1)
			lbl.text = "+%d" % val
			var g_col = COLORS["brass"]
			for g in result["groups"]:
				if g["idxs"].has(i):
					if g["col"] != null:
						g_col = COLORS.get(g["col"], COLORS["brass"])
					else:
						g_col = Color("#E040FB")
					break
			lbl.modulate = g_col
		else:
			lbl.text = "•"
			lbl.modulate = Color(0.35, 0.35, 0.45)


# --- Smart Auto-Placement Solver ---
func auto_place_selected() -> void:
	var cards_to_place = []
	for card in hand:
		if selected_card_ids.has(card["id"]):
			cards_to_place.append(card)

	var free_slots = []
	for i in range(N_TILES):
		if not placed_cards.has(i):
			free_slots.append(i)

	var n = mini(cards_to_place.size(), free_slots.size())
	if n <= 0: return

	var best_score = -1
	var best_perm = []

	var perm = cards_to_place.slice(0, n)
	for trial in range(40):
		if trial > 0:
			perm.shuffle()
		for k in range(n):
			placed_cards[free_slots[k]] = perm[k]
		var score = calculate_groups()["base_dmg"]
		if score > best_score:
			best_score = score
			best_perm = perm.duplicate()
		for k in range(n):
			placed_cards.erase(free_slots[k])

	for k in range(n):
		var c = best_perm[k]
		var slot = free_slots[k]
		hand.erase(c)
		placed_cards[slot] = c

	selected_card_ids.clear()
	update_all_ui()
	refresh_calc()


# ==============================================================================
# Animated Walk & Battle Execution
# ==============================================================================

func _on_walk_pressed() -> void:
	if is_busy: return

	# If cards selected, click walk executes auto-placement
	if selected_card_ids.size() > 0:
		auto_place_selected()
		return

	if walks_left <= 0: return

	walks_left -= 1
	is_busy = true
	update_all_ui()
	msg_label.text = "🔥 กำลังเดินสำรวจกระดาน..."

	token.visible = true
	var tween = create_tween()
	var step_duration = 0.26 / speed_multiplier

	# Collect stops (Tile 0 + all tiles with placed cards)
	var active_tiles: Array[int] = [0]
	for i in range(1, N_TILES):
		if placed_cards.has(i):
			active_tiles.append(i)

	if has_artifact("reverse") and active_tiles.size() > 1:
		var rev = active_tiles.duplicate()
		rev.reverse()
		rev.pop_front()
		for idx in rev:
			active_tiles.append(idx)

	var tile_btn_sample = tiles_container.get_child(0) as Button
	var tile_w = tile_btn_sample.size.x + 12.0

	for idx in active_tiles:
		var target_x = 16.0 + idx * tile_w + (tile_btn_sample.size.x - token.size.x) * 0.5
		var target_pos = Vector2(target_x, 26.0)
		tween.tween_property(token, "position", target_pos, step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if placed_cards.has(idx):
				_spawn_tile_popup(idx)
		)
		tween.tween_interval(0.06 / speed_multiplier)

	tween.finished.connect(_on_walk_finished)


func _spawn_tile_popup(tile_idx: int) -> void:
	var tile_btn = tiles_container.get_child(tile_idx) as Button
	var card = placed_cards.get(tile_idx)
	if card == null: return

	var calc = calculate_groups()
	var gain = calc["grp_val"].get(tile_idx, 1)

	var pop = Label.new()
	if card.get("is_blank", false):
		pop.text = "+0"
		pop.modulate = Color.GRAY
	else:
		pop.text = "+%d ATK" % gain
		pop.modulate = COLORS.get(card["color"], Color.CYAN)

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

	var pop_tween = create_tween()
	pop_tween.tween_property(pop, "scale", Vector2(1.15, 1.15), 0.12 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.parallel().tween_property(pop, "position:y", start_pos.y - 30.0, 0.3 / speed_multiplier)
	pop_tween.tween_property(pop, "scale", Vector2(0.9, 0.9), 0.12 / speed_multiplier)
	pop_tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.18 / speed_multiplier)
	pop_tween.parallel().tween_property(pop, "position:y", start_pos.y - 50.0, 0.18 / speed_multiplier)
	pop_tween.tween_callback(pop.queue_free)


func _on_walk_finished() -> void:
	# 1. Fireball flies up to Hero along curved Bézier path
	msg_label.text = "✨ รวมพลังเวทเข้าสู่ฮีโร่!"
	var start_global = token.global_position + token.size * 0.5
	var hero_center = hero_pic.global_position + hero_pic.size * 0.5
	var mid_global = (start_global + hero_center) * 0.5 + Vector2(-60.0, -100.0)

	var fly_tween = create_tween()
	fly_tween.tween_method(func(t: float):
		var omt = 1.0 - t
		token.global_position = omt * omt * start_global + 2.0 * omt * t * mid_global + t * t * hero_center - token.size * 0.5
	, 0.0, 1.0, 0.35 / speed_multiplier).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await fly_tween.finished
	token.visible = false
	token.position = Vector2(20.0, 26.0)

	# 2. Hero charge pulse
	hero_pic.pivot_offset = hero_pic.size * 0.5
	var charge_tween = create_tween()
	charge_tween.tween_property(hero_pic, "scale", Vector2(1.35, 1.35), 0.2 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge_tween.parallel().tween_property(hero_pic, "modulate", Color(1.4, 1.25, 0.5), 0.2 / speed_multiplier)
	charge_tween.tween_interval(0.12 / speed_multiplier)
	charge_tween.tween_property(hero_pic, "scale", Vector2.ONE, 0.15 / speed_multiplier)
	charge_tween.parallel().tween_property(hero_pic, "modulate", Color.WHITE, 0.15 / speed_multiplier)
	await charge_tween.finished

	# 3. Calculate Attack & Final Damage (Matching attackSeq)
	var calc = calculate_groups()
	var atk = 1 + calc["base_dmg"]
	var mult = 1.0

	if has_artifact("add5"): atk += 10
	if has_artifact("mult2"): mult += 5.0
	if has_artifact("emptyAtk"): atk += 2 * (N_TILES - placed_cards.size())
	if has_artifact("atk15"): atk = int(atk * 1.5)
	if has_artifact("firstGem") and placed_cards.has(0): atk += 8
	if has_artifact("stoneUp"): mult *= 1.5
	if has_artifact("reverse"): atk = int(atk * 1.5)

	var dmg = int(atk * mult)
	if dmg <= 0: dmg = 1

	msg_label.text = "🧙 ฮีโร่ยิงลำแสงเวท %d ดาเมจ!" % dmg
	var enemy_center = enemy_pic.global_position + enemy_pic.size * 0.5

	fire_laser_beam(beam_line, hero_center, enemy_center, Color(1.0, 0.78, 0.25), 24.0, 0.28)

	await get_tree().create_timer(0.08 / speed_multiplier).timeout

	# 4. Enemy takes damage
	enemy_hp = maxi(0, enemy_hp - dmg)
	enemy_hp_label.text = "HP %d / %d" % [enemy_hp, enemy_max_hp]
	create_tween().tween_property(enemy_hp_bar, "value", float(enemy_hp), 0.35 / speed_multiplier)

	shake_node(enemy_pic, 18.0, 0.42)
	enemy_pic.modulate = Color(1.6, 0.2, 0.2)
	var enemy_hurt = create_tween()
	enemy_hurt.tween_property(enemy_pic, "modulate", Color.WHITE, 0.25 / speed_multiplier)

	spawn_damage_number("-%d" % dmg, enemy_center, Color("#ff4d5e"), true)

	await get_tree().create_timer(0.6 / speed_multiplier).timeout

	if enemy_hp <= 0:
		on_victory()
	else:
		_enemy_counter_attack()


func _enemy_counter_attack() -> void:
	msg_label.text = "👹 ศัตรูโจมตีสวนกลับ!"

	var enemy_center = enemy_pic.global_position + enemy_pic.size * 0.5
	var hero_center = hero_pic.global_position + hero_pic.size * 0.5

	# 1. Enemy lunges forward
	enemy_pic.pivot_offset = enemy_pic.size * 0.5
	var orig_pos = enemy_pic.position
	var lunge_tween = create_tween()
	lunge_tween.tween_property(enemy_pic, "position:x", orig_pos.x - 35.0, 0.16 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(enemy_pic, "position:x", orig_pos.x, 0.14 / speed_multiplier)

	await get_tree().create_timer(0.18 / speed_multiplier).timeout

	# 2. Enemy fires counter-attack beam
	fire_laser_beam(enemy_beam_line, enemy_center, hero_center, Color(0.9, 0.25, 0.95), 22.0, 0.28)

	await get_tree().create_timer(0.08 / speed_multiplier).timeout

	# 3. Rule: Hero HP is tied to walks_left!
	player_hp = enemy_atk * walks_left
	hero_hp_label.text = "HP %d / %d" % [player_hp, player_max_hp]
	create_tween().tween_property(hero_hp_bar, "value", float(player_hp), 0.3 / speed_multiplier)

	shake_node(hero_pic, 15.0, 0.38)
	hero_pic.modulate = Color.RED
	var hurt_tween = create_tween()
	hurt_tween.tween_property(hero_pic, "modulate", Color.WHITE, 0.25 / speed_multiplier)

	spawn_damage_number("-%d" % enemy_atk, hero_center, Color("#ff3355"), true)

	await get_tree().create_timer(0.5 / speed_multiplier).timeout

	# 4. Check if player ran out of walks
	if walks_left <= 0 or player_hp <= 0:
		on_game_over()
	else:
		is_busy = false
		start_new_round()


func on_victory() -> void:
	is_busy = false
	msg_label.text = "🏆 ชนะศัตรูแล้ว!"
	var fade_tween = create_tween()
	fade_tween.tween_property(enemy_pic, "modulate:a", 0.0, 0.4 / speed_multiplier)
	fade_tween.parallel().tween_property(enemy_pic, "scale", Vector2(0.5, 0.5), 0.4 / speed_multiplier)

	await fade_tween.finished

	# Matching Draft Reward: base (4) + walks + interest (held/5, max 10) + artifacts
	var base_reward = 4
	var interest = mini(10, int(coins / 5))
	var walk_reward = walks_left
	var arti_count = 0
	for a in artifacts:
		if a != null: arti_count += 1
	var arti_pay = 0
	if has_artifact("greenCoin"):
		arti_pay = interest # extra interest
	if has_artifact("walkCoin"):
		walk_reward = walks_left * 2

	var total_gain = base_reward + walk_reward + interest + arti_pay
	coins += total_gain

	var reward_text = "เอาชนะด่านที่ %d สำเร็จ!\n\n🪙 รางวัลพื้นฐาน: +%d" % [stage, base_reward]
	reward_text += "\n🪙 เลือดที่เหลือ (%d รอบ): +%d" % [walks_left, walk_reward]
	if interest > 0:
		reward_text += "\n🪙 ดอกเบี้ย (มี %d ÷ 5): +%d" % [coins - total_gain, interest]
	reward_text += "\n\nรวมได้รับ: +%d 🪙\n💊 พลังชีวิตฟื้นฟูเต็มเปี่ยม" % total_gain

	reward_info.text = reward_text
	update_all_ui()
	reward_modal.visible = true


func _on_reward_shop_pressed() -> void:
	reward_modal.visible = false
	open_shop()


func open_shop() -> void:
	shop_modal.visible = true
	_render_shop_owned()
	_render_shop_offers()
	shop_coins_label.text = "🪙 %d" % coins


func _render_shop_owned() -> void:
	for child in shop_items_container.get_children():
		child.queue_free()

	for i in range(MAX_ARTIFACTS):
		var art = artifacts[i]
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(72, 84)
		slot_btn.add_theme_font_size_override("font_size", 28)
		if art != null:
			slot_btn.text = art["icon"]
			slot_btn.tooltip_text = "%s\n%s\n(แตะเพื่อขาย 🪙%d)" % [art["name"], art["desc"], int(art["price"] / 3.0)]
			var sell_idx = i
			slot_btn.pressed.connect(func(): _sell_artifact(sell_idx))
		else:
			slot_btn.text = "·"
			slot_btn.disabled = true
		shop_items_container.add_child(slot_btn)


func _render_shop_offers() -> void:
	for child in shop_offer_container.get_children():
		child.queue_free()

	# 1. Basic Stat Upgrades (Matching Draft: Hand+1, HP/Walk+1, Discard+1)
	# Hand +1 (Price: 6)
	var hand_btn = Button.new()
	hand_btn.custom_minimum_size = Vector2(100, 110)
	hand_btn.add_theme_font_size_override("font_size", 14)
	var hand_maxed = (hand_max >= HAND_CAP)
	hand_btn.text = "🃏 Hand +1\n(ปัจจุบัน %d)\n%s" % [hand_max, "สูงสุด" if hand_maxed else "🪙 6"]
	hand_btn.disabled = hand_maxed or (coins < 6)
	hand_btn.pressed.connect(func(): _buy_stat("hand", 6))
	shop_offer_container.add_child(hand_btn)

	# Walk / HP +1 (Price: 6)
	var walk_btn_up = Button.new()
	walk_btn_up.custom_minimum_size = Vector2(100, 110)
	walk_btn_up.add_theme_font_size_override("font_size", 14)
	walk_btn_up.text = "❤️ HP (Walk)+1\n(ปัจจุบัน %d รอบ)\n🪙 6" % walk_max
	walk_btn_up.disabled = (coins < 6)
	walk_btn_up.pressed.connect(func(): _buy_stat("walk", 6))
	shop_offer_container.add_child(walk_btn_up)

	# Discard +1 (Price: 6)
	var disc_btn = Button.new()
	disc_btn.custom_minimum_size = Vector2(100, 110)
	disc_btn.add_theme_font_size_override("font_size", 14)
	disc_btn.text = "♻️ ทิ้ง +1\n(ปัจจุบัน %d รอบ)\n🪙 6" % discard_max
	disc_btn.disabled = (coins < 6)
	disc_btn.pressed.connect(func(): _buy_stat("disc", 6))
	shop_offer_container.add_child(disc_btn)

	# 2. Stone Formula Upgrade
	for idx in range(stone_formulas.size()):
		var fkey = stone_formulas[idx]["key"]
		if not discovered_formulas.has(fkey): continue
		var upg_cost = 6 + (stone_formulas[idx]["a"] - 1) * 2
		var upg_btn = Button.new()
		upg_btn.custom_minimum_size = Vector2(100, 110)
		upg_btn.add_theme_font_size_override("font_size", 13)
		upg_btn.text = "🪨 %s\nATK เริ่มต้น +1\nLv%d→%d\n🪙 %d" % [
			stone_formulas[idx]["name"],
			stone_formulas[idx]["a"],
			stone_formulas[idx]["a"] + 1,
			upg_cost
		]
		upg_btn.disabled = (coins < upg_cost)
		var capture_idx = idx
		var capture_cost = upg_cost
		upg_btn.pressed.connect(func(): _buy_stone_upgrade(capture_idx, capture_cost))
		shop_offer_container.add_child(upg_btn)

	# 3. Artifact Offers (4 unowned artifacts)
	var owned_types: Array[String] = []
	for art in artifacts:
		if art != null:
			owned_types.append(art["type"])

	var pool = ARTIFACT_CATALOG.filter(func(a): return not owned_types.has(a["type"]))
	pool.shuffle()
	var offers = pool.slice(0, mini(4, pool.size()))

	for item in offers:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 110)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", item["color"])
		var is_full = not artifacts.has(null)
		var can_buy = not is_full and coins >= item["price"]
		btn.text = "%s\n%s\n🪙%d" % [item["icon"], item["name"], item["price"]]
		btn.disabled = not can_buy
		btn.tooltip_text = item["desc"]
		var capture = item
		btn.pressed.connect(func(): _buy_artifact(capture))
		shop_offer_container.add_child(btn)


func _buy_stat(stat_type: String, price: int) -> void:
	if coins < price: return
	coins -= price
	if stat_type == "hand":
		hand_max = mini(HAND_CAP, hand_max + 1)
	elif stat_type == "walk":
		walk_max += 1
		walks_left = walk_max
		player_max_hp = enemy_atk * walk_max
		player_hp = player_max_hp
	elif stat_type == "disc":
		discard_max += 1
		discards_left += 1

	update_all_ui()
	_render_shop_offers()
	shop_coins_label.text = "🪙 %d" % coins


func _buy_stone_upgrade(formula_idx: int, cost: int) -> void:
	if coins < cost: return
	coins -= cost
	stone_formulas[formula_idx]["a"] += 1
	update_all_ui()
	_render_shop_offers()
	shop_coins_label.text = "🪙 %d" % coins


func _buy_artifact(item: Dictionary) -> void:
	var slot = artifacts.find(null)
	if slot == -1 or coins < item["price"]: return
	coins -= item["price"]
	artifacts[slot] = item.duplicate()
	update_all_ui()
	_render_shop_owned()
	_render_shop_offers()
	shop_coins_label.text = "🪙 %d" % coins
	render_artifact_row()


func _sell_artifact(slot_idx: int) -> void:
	var art = artifacts[slot_idx]
	if art == null: return
	var sell_price = int(art["price"] / 3.0)
	coins += sell_price
	artifacts[slot_idx] = null
	update_all_ui()
	_render_shop_owned()
	_render_shop_offers()
	shop_coins_label.text = "🪙 %d" % coins
	render_artifact_row()


func _on_shop_leave() -> void:
	shop_modal.visible = false
	stage += 1
	enemy_pic.modulate = Color.WHITE
	enemy_pic.scale = Vector2.ONE

	# Enemy scaling per draft
	enemy_max_hp = int(enemy_max_hp * 1.5)
	enemy_hp = enemy_max_hp
	enemy_atk = int(enemy_atk * PHP_GROW)

	walks_left = walk_max
	player_max_hp = enemy_atk * walk_max
	player_hp = player_max_hp

	discards_left = discard_max + (1 if has_artifact("freediscard") else 0)

	build_deck()
	spawn_current_enemy()


func _on_artifact_slot_pressed(slot_idx: int) -> void:
	var art = artifacts[slot_idx]
	if art == null: return
	toast_label.text = "%s %s\n%s" % [art["icon"], art["name"], art["desc"]]
	toast.visible = true
	toast.modulate.a = 0.0
	var orig_y = 70.0
	toast.position.y = orig_y - 25.0
	var tween = create_tween()
	tween.tween_property(toast, "position:y", orig_y, 0.28 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.25 / speed_multiplier)
	tween.tween_interval(2.5 / speed_multiplier)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25 / speed_multiplier)
	tween.tween_callback(func(): toast.visible = false)


func render_artifact_row() -> void:
	for i in range(MAX_ARTIFACTS):
		var slot = artifact_row.get_child(i + 1) as Button
		if slot == null: continue
		var art = artifacts[i]
		if art != null:
			slot.text = art["icon"]
			slot.tooltip_text = art["name"]
		else:
			slot.text = ""
			slot.tooltip_text = ""


func has_artifact(type_key: String) -> bool:
	for art in artifacts:
		if art != null and art["type"] == type_key:
			return true
	return false


func on_game_over() -> void:
	is_busy = false
	msg_label.text = "💀 คุณพ่ายแพ้..."
	gameover_info.text = "คุณพ่ายแพ้ในด่านที่ %d!\nคะแนนเหรียญสะสม: %d 🪙" % [stage, coins]
	gameover_modal.visible = true


func setup_stone_modal_content() -> void:
	for child in stone_list.get_children():
		child.queue_free()

	for r in stone_formulas:
		var lbl = Label.new()
		lbl.text = "• %s (%s)\n  ขั้นต่ำ: %d ใบ | เริ่มต้น: %d ATK (+%d ต่อใบ)" % [r["name"], r["desc"], r["min"], r["a"], r["g"]]
		stone_list.add_child(lbl)


func _on_speed_toggle() -> void:
	if speed_multiplier == 1.0:
		speed_multiplier = 2.0
		speed_btn.text = "⏩ x2"
	elif speed_multiplier == 2.0:
		speed_multiplier = 3.0
		speed_btn.text = "⏩ x3"
	else:
		speed_multiplier = 1.0
		speed_btn.text = "▶ x1"


func open_deck_modal() -> void:
	for child in deck_modal_list.get_children():
		child.queue_free()

	var counts = {
		"red": {"N": 0, "E": 0, "S": 0, "W": 0},
		"green": {"N": 0, "E": 0, "S": 0, "W": 0},
		"orange": {"N": 0, "E": 0, "S": 0, "W": 0},
		"blue": {"N": 0, "E": 0, "S": 0, "W": 0}
	}
	var blank_count = 0

	for card in deck:
		if card.get("is_blank", false):
			blank_count += 1
		else:
			var c = card["color"]
			var d = card["dir"]
			if counts.has(c) and counts[c].has(d):
				counts[c][d] += 1

	var color_names = {
		"red": "🔴 สีแดง",
		"green": "🟢 สีเขียว",
		"orange": "🟠 สีส้ม",
		"blue": "🔵 สีน้ำเงิน"
	}

	for col in COLOR_ORDER:
		var total_col = counts[col]["N"] + counts[col]["E"] + counts[col]["S"] + counts[col]["W"]
		var pnl = PanelContainer.new()
		var pnl_sb = StyleBoxFlat.new()
		pnl_sb.bg_color = COLORS[col].darkened(0.7)
		pnl_sb.border_color = COLORS[col]
		pnl_sb.border_width_left = 4
		pnl_sb.set_corner_radius_all(6)
		pnl.add_theme_stylebox_override("panel", pnl_sb)

		var vbox = VBoxContainer.new()
		var lbl_title = Label.new()
		lbl_title.text = "%s (เหลือทั้งหมด %d ใบ):" % [color_names[col], total_col]
		lbl_title.modulate = COLORS[col].lightened(0.3)
		lbl_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(lbl_title)

		var lbl_detail = Label.new()
		lbl_detail.text = "   N: %d ใบ  |  E: %d ใบ  |  S: %d ใบ  |  W: %d ใบ" % [
			counts[col]["N"], counts[col]["E"], counts[col]["S"], counts[col]["W"]
		]
		lbl_detail.add_theme_font_size_override("font_size", 14)
		vbox.add_child(lbl_detail)

		pnl.add_child(vbox)
		deck_modal_list.add_child(pnl)

	if blank_count > 0:
		var pnl = PanelContainer.new()
		var pnl_sb = StyleBoxFlat.new()
		pnl_sb.bg_color = Color("#3a3a48")
		pnl_sb.border_color = Color("#aaaaaa")
		pnl_sb.border_width_left = 4
		pnl_sb.set_corner_radius_all(6)
		pnl.add_theme_stylebox_override("panel", pnl_sb)

		var vbox = VBoxContainer.new()
		var lbl_title = Label.new()
		lbl_title.text = "⬜ การ์ดเปล่า (ชั่วคราวจากสกิลบอส): %d ใบ" % blank_count
		lbl_title.modulate = Color(0.9, 0.9, 0.9)
		lbl_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(lbl_title)
		pnl.add_child(vbox)
		deck_modal_list.add_child(pnl)

	deck_modal.visible = true


# ==============================================================================
# Helper VFX Methods
# ==============================================================================

func fire_laser_beam(line: Line2D, from_pos: Vector2, to_pos: Vector2, col: Color, beam_w: float = 20.0, duration: float = 0.25) -> void:
	var p0 = (effects_layer.get_global_transform().affine_inverse() * from_pos)
	var p1 = (effects_layer.get_global_transform().affine_inverse() * to_pos)
	line.clear_points()
	line.add_point(p0)
	line.add_point(p0)
	line.default_color = col
	line.width = beam_w
	line.modulate.a = 1.0
	line.visible = true

	var tween = create_tween()
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


func shake_node(node: Control, intensity: float = 14.0, duration: float = 0.38) -> void:
	node.pivot_offset = node.size * 0.5
	var orig_pos = node.position
	var orig_rot = node.rotation
	var tween = create_tween()
	var steps = int(duration / 0.04)
	for i in range(steps):
		var decay = 1.0 - (float(i) / float(steps))
		var offset = Vector2(randf_range(-intensity, intensity) * decay, randf_range(-intensity * 0.35, intensity * 0.35) * decay)
		var rot_offset = deg_to_rad(randf_range(-6.0, 6.0) * decay)
		tween.tween_property(node, "position", orig_pos + offset, 0.04 / speed_multiplier)
		tween.parallel().tween_property(node, "rotation", orig_rot + rot_offset, 0.04 / speed_multiplier)
	tween.tween_property(node, "position", orig_pos, 0.04 / speed_multiplier)
	tween.parallel().tween_property(node, "rotation", orig_rot, 0.04 / speed_multiplier)


func spawn_damage_number(text: String, target_global_pos: Vector2, col: Color = Color("#ff4d5e"), is_big: bool = true) -> void:
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

	var tween = create_tween()
	tween.tween_property(pop, "scale", Vector2(1.3, 1.3), 0.14 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pop, "modulate:a", 1.0, 0.12 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 45.0, 0.14 / speed_multiplier)

	tween.tween_property(pop, "scale", Vector2.ONE, 0.2 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 75.0, 0.35 / speed_multiplier)

	tween.tween_property(pop, "modulate:a", 0.0, 0.22 / speed_multiplier)
	tween.parallel().tween_property(pop, "position:y", start_pos.y - 95.0, 0.22 / speed_multiplier)
	tween.tween_callback(pop.queue_free)


func show_discovery_toast(formula_key: String) -> void:
	var f_info = null
	for f in stone_formulas:
		if f["key"] == formula_key:
			f_info = f
			break
	if f_info == null: return

	toast_label.text = "✨ ค้นพบสูตรใหม่! · %s (%s) · ATK +%d" % [f_info["name"], f_info["desc"], f_info["a"]]
	toast.visible = true
	toast.modulate.a = 0.0
	var orig_y = 70.0
	toast.position.y = orig_y - 25.0

	var tween = create_tween()
	tween.tween_property(toast, "position:y", orig_y, 0.28 / speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.25 / speed_multiplier)
	tween.tween_interval(2.2 / speed_multiplier)
	tween.tween_property(toast, "position:y", orig_y - 20.0, 0.25 / speed_multiplier)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.25 / speed_multiplier)
	tween.tween_callback(func(): toast.visible = false)
