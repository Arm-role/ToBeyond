extends Control

# ==============================================================================
# To Beyond - Godot 4 Full Implementation
# Faithfully matching To_Beyond_Draft.html Logic 100%
# ==============================================================================

const N_TILES: int = 8
const DEFAULT_TILE_DIR: Array[String] = ["N", "N", "E", "E", "S", "S", "W", "W"]
var TILE_DIR: Array[String] = DEFAULT_TILE_DIR.duplicate()
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

var EMBLEMS = {}           # dir -> Texture2D (white)
var EMBLEMS_GOLD = {}      # dir -> Texture2D (gold, matched)
var CHAOS_TEX = {}         # chaos kind -> Texture2D
var GEM_FRAME_TEX = {}     # color -> Texture2D (placed card frame)
var TILE_EMPTY_TEX = {}    # tile index -> Texture2D
var PLACED_TILE_TEX = {}   # "idx_color_dir" or "idx_blank" -> Texture2D
var CARD_TEMPLATE_TEX: Texture2D = null
var CRYSTAL_TEX: Texture2D = null
var BALL_TEXTURE: Texture2D = null

func init_textures() -> void:
	if ResourceLoader.exists("res://assets/frames/card_template.svg"):
		CARD_TEMPLATE_TEX = load("res://assets/frames/card_template.svg")

	# Emblems (white & gold variants)
	for d in ["N", "E", "S", "W"]:
		var dl = d.to_lower()
		var pw = "res://assets/emblems/emblem_%s.svg" % dl
		var pg = "res://assets/emblems/emblem_%s_gold.svg" % dl
		if ResourceLoader.exists(pw):
			EMBLEMS[d] = load(pw)
		if ResourceLoader.exists(pg):
			EMBLEMS_GOLD[d] = load(pg)

	# Chaos SVGs
	var chaos_keys = ["color","mtile","goldify","crystal","destroy"]
	for key in chaos_keys:
		var p = "res://assets/chaos/%s.svg" % key
		if ResourceLoader.exists(p):
			CHAOS_TEX[key] = load(p)

	# Gem frames (placed card)
	for col in ["red","green","orange","blue","blank"]:
		var p = "res://assets/frames/gem_frame_%s.svg" % col
		if ResourceLoader.exists(p):
			GEM_FRAME_TEX[col] = load(p)

	# Tile empty SVGs (per slot)
	for i in range(N_TILES):
		var p = "res://assets/tiles/tile_empty_%d.svg" % i
		if ResourceLoader.exists(p):
			TILE_EMPTY_TEX[i] = load(p)

	# Placed tile SVGs (exact match with To_Beyond_Draft.html syncTiles)
	for i in range(N_TILES):
		for col in ["red", "green", "orange", "blue"]:
			for d in ["N", "E", "S", "W"]:
				var p = "res://assets/tiles/placed/tile_%d_%s_%s.svg" % [i, col, d]
				if ResourceLoader.exists(p):
					PLACED_TILE_TEX["%d_%s_%s" % [i, col, d]] = load(p)
		var pb = "res://assets/tiles/placed/tile_%d_blank.svg" % i
		if ResourceLoader.exists(pb):
			PLACED_TILE_TEX["%d_blank" % i] = load(pb)

	# Crystal
	if ResourceLoader.exists("res://assets/crystal.svg"):
		CRYSTAL_TEX = load("res://assets/crystal.svg")

	# Ball
	if ResourceLoader.exists("res://assets/ball.svg"):
		BALL_TEXTURE = load("res://assets/ball.svg")

# --- Stone Formulas ---
var stone_formulas: Array[Dictionary] = StoneCalc.DEFAULT_FORMULAS.duplicate(true)

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

var enemy_atk: float = EATK_START
var walks_left: int = WALK_START
var discards_left: int = DISCARD_START

var player_max_hp: float = enemy_atk * walk_max
var player_hp: float = player_max_hp

var enemy_max_hp: int = 50
var enemy_hp: int = 50

# --- State Variables ---
var deck: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var placed_cards: Dictionary = {} # tile_idx -> card dict
var selected_card_ids: Array[int] = []
var card_uid_counter: int = 0

var stage: int = 1
var sfx: Node # SfxManager (scripts/sfx_manager.gd)
var coins: int = 0
var sort_mode: String = "color" # "color" or "dir"

var is_busy: bool = false
var speed_multiplier: float = 1.0
## The web draft exposes these four base recipes from the beginning. The two
## higher-value recipes remain discoveries.
var discovered_formulas: Array[String] = ["col", "dsame", "alt", "dtile"]

## Damage is accumulated as the token visits cards during a walk.
var walk_base_damage: int = 0
var walk_mult_bonus: float = 0.0
var first_gem_triggered: bool = false
var first_gem_tile: int = -1
var artifact_sys: ArtifactSystem
var totem_tiles: Array[int] = []

# --- Chaos System (ported from the web draft) ---
var chaos: Array = [null, null, null] # Array of null or { kind, col?, dir? }
var selected_chaos_slot: int = -1
var deck_mods: Array[Dictionary] = []
var gold_mods: Array[Dictionary] = []
var deck_removals: Array[Dictionary] = []
var chaos_mult_tiles: Dictionary = {} # tile index -> true, MULT +5
var chaos_xmult_tiles: Dictionary = {} # tile index -> true, MULT ×1.2
var chaos_xatk_tiles: Dictionary = {} # tile index -> true, ATK ×1.2
var chaos_crystals: Dictionary = {} # tile index -> current HP
const CRYSTAL_HP: int = 5
const CRYSTAL_GEMS: int = 3

func is_boss() -> bool:
	return stage % 3 == 0

# --- Artifact System ---
const MAX_ARTIFACTS: int = ShopManager.MAX_ARTIFACTS
var artifacts: Array = []  # Array of null or Dict

# --- Node References ---
@onready var stage_label: Label = $TopBar/StageLabel
@onready var coins_label: Label = $TopBar/CoinsLabel
@onready var speed_btn: Button = $TopBar/SpeedBtn
@onready var restart_btn: Button = $TopBar/RestartBtn

@onready var hero_hp_bar: ProgressBar = $Preview/PreviewHBox/HeroCol/PhpBox/HeroHPBar
@onready var hero_hp_label: Label = $Preview/PreviewHBox/HeroCol/PhpBox/HeroHPText
@onready var hero_pic: Label = $Preview/PreviewHBox/HeroCol/HeroPic
@onready var calc_label: RichTextLabel = $Preview/PreviewHBox/HeroCol/CalcLabel

@onready var enemy_name: Label = $Preview/PreviewHBox/EnemyCol/EnemyName
@onready var enemy_pic: Label = $Preview/PreviewHBox/EnemyCol/EnemyPic
@onready var enemy_hp_bar: ProgressBar = $Preview/PreviewHBox/EnemyCol/EnemyHPBar
@onready var enemy_hp_label: Label = $Preview/PreviewHBox/EnemyCol/EnemyHPText
@onready var enemy_atk_label: Label = $Preview/PreviewHBox/EnemyCol/EnemyAtkText
@onready var msg_label: Label = $Preview/PreviewHBox/EnemyCol/MsgLabel
@onready var enemy_skill_label: Label = $Preview/PreviewHBox/EnemyCol/EnemySkill

# Artifact Row
@onready var artifact_row: HBoxContainer = $ArtifactRow
@onready var chaos_slots: HBoxContainer = $ChaosRow/Slots

# Effects Layer References
@onready var effects_layer: Control = $EffectsLayer
@onready var beam_line: Line2D = $EffectsLayer/BeamLine
@onready var enemy_beam_line: Line2D = $EffectsLayer/EnemyBeamLine
@onready var toast: PanelContainer = $EffectsLayer/Toast
@onready var toast_label: Label = $EffectsLayer/Toast/ToastLabel

@onready var tiles_container: HBoxContainer = $BoardSection/TilesContainer
@onready var gstrip_container: HBoxContainer = $BoardSection/GstripContainer
@onready var token: Control = $BoardSection/Token

@onready var hand_container: Control = $BottomSection/HandContainer
@onready var deck_count_btn: Button = $ToolCol/DeckCountBtn
@onready var stone_btn: Button = $ToolCol/StoneBtn
@onready var sort_color_btn: Button = $BottomSection/ControlsRow/ActionCol/SortGroup/SortFrame/HBox/SortColorBtn
@onready var sort_dir_btn: Button = $BottomSection/ControlsRow/ActionCol/SortGroup/SortFrame/HBox/SortDirBtn
@onready var walk_btn: Button = $BottomSection/ControlsRow/ActionCol/WalkBtn
@onready var discard_btn: Button = $BottomSection/ControlsRow/ActionCol/DiscardBtn

# Modals
@onready var reward_modal: PanelContainer = $RewardModal
@onready var reward_info: VBoxContainer = $RewardModal/VBox/RewardInfo
@onready var reward_next_btn: Button = $RewardModal/VBox/NextBtn

@onready var gameover_modal: Control = $GameOverModal
@onready var gameover_info: Label = $GameOverModal/Center/Panel/VBox/GameOverInfo
@onready var gameover_btn: Button = $GameOverModal/Center/Panel/VBox/RetryBtn

@onready var stone_modal: Control = $StoneModal
@onready var stone_list: VBoxContainer = $StoneModal/Center/Panel/VBox/Scroll/List
@onready var stone_close_btn: Button = $StoneModal/Center/Panel/VBox/CloseBtn

# Deck Modal
@onready var deck_modal: Control = $DeckModal
@onready var deck_modal_list: VBoxContainer = $DeckModal/Center/Panel/VBox/Scroll/List
@onready var deck_modal_close_btn: Button = $DeckModal/Center/Panel/VBox/CloseBtn

# Shop Modal
@onready var shop_modal: PanelContainer = $ShopModal
@onready var shop_coins_label: Label = $ShopModal/ShopVBox/ShopHeader/ShopCoinsLabel
@onready var shop_reroll_btn: Button = $ShopModal/ShopVBox/ShopHeader/ShopRerollBtn
@onready var shop_leave_btn: Button = $ShopModal/ShopVBox/ShopHeader/ShopLeaveBtn
@onready var shop_game_tab: Button = $ShopModal/ShopVBox/ShopTabs/GameTab
@onready var shop_artifact_tab: Button = $ShopModal/ShopVBox/ShopTabs/ArtifactTab
@onready var shop_chaos_tab: Button = $ShopModal/ShopVBox/ShopTabs/ChaosTab
@onready var shop_upgrade_tab: Button = $ShopModal/ShopVBox/ShopTabs/UpgradeTab
@onready var shop_items_container: Container = $ShopModal/ShopVBox/ShopOwnedRow/ShopItemsContainer
@onready var shop_chaos_container: Container = $ShopModal/ShopVBox/ShopOwnedRow/ShopChaosContainer
@onready var shop_offer_frame: PanelContainer = $ShopModal/ShopVBox/ShopOfferFrame
@onready var shop_offer_container: Container = $ShopModal/ShopVBox/ShopOfferFrame/ShopOfferScroll/ShopOfferContainer


var battle_mgr: BattleManager
var shop_mgr: ShopManager
var ui_renderer: UiRenderer
var action_dialog: Control
var pending_dialog_action: Callable
var drag_kind: String = ""
var drag_from: int = -1
var drag_start: Vector2 = Vector2.ZERO
var drag_moved: bool = false


func _ready() -> void:
	sfx = preload("res://scripts/sfx_manager.gd").new()
	add_child(sfx)
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://assets/shaders/bg_drift.gdshader")
	$Background.material = bg_mat
	init_textures()
	setup_token_visual()
	_setup_beams()
	connect_ui_signals()
	battle_mgr = BattleManager.new(self)
	artifact_sys = ArtifactSystem.new(self)
	shop_mgr = ShopManager.new(self)
	ui_renderer = UiRenderer.new(self)
	_setup_action_dialog()
	setup_stone_modal_content()
	_style_sort_button(sort_color_btn, sort_mode == "color")
	_style_sort_button(sort_dir_btn, sort_mode == "dir")
	hand_container.resized.connect(render_hand)
	start_new_game()
	# Test states for tools/parity (only active with ?dbg= / --dbg=).
	add_child(preload("res://scripts/debug_scenarios.gd").new())


func setup_token_visual() -> void:
	# Gameplay is authored against the 1920×1080 canvas (the HTML draft scaled
	# from 1280×720 at 1.5×), so keep the travelling token proportional.
	# Draft: ball height = tile × 0.7, aspect 98:168 → about 84×143 here.
	token.custom_minimum_size = Vector2(84, 143)
	token.size = Vector2(84, 143)
	if BALL_TEXTURE != null:
		var tex_rect = TextureRect.new()
		tex_rect.name = "BallTexture"
		tex_rect.texture = BALL_TEXTURE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(84, 143)
		tex_rect.size = Vector2(84, 143)
		token.add_child(tex_rect)
	else:
		var lbl = Label.new()
		lbl.text = "🔥"
		lbl.add_theme_font_size_override("font_size", 51)
		token.add_child(lbl)


func _setup_beams() -> void:
	# Draft `.beam` / `.beam.ebeam` gradients.
	var hero_g := Gradient.new()
	hero_g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	hero_g.colors = PackedColorArray([Color("#fff6c0"), Color("#ffb22e"), Color("#ff5a1f")])
	beam_line.gradient = hero_g
	var enemy_g := Gradient.new()
	enemy_g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	enemy_g.colors = PackedColorArray([Color("#ffd0f0"), Color("#c03aff"), Color("#ff2e5a")])
	enemy_beam_line.gradient = enemy_g
	for l in [beam_line, enemy_beam_line]:
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND


func connect_ui_signals() -> void:
	restart_btn.pressed.connect(start_new_game)
	_setup_fullscreen_button()
	_setup_audio_button()
	speed_btn.pressed.connect(_on_speed_toggle)
	deck_count_btn.pressed.connect(open_deck_modal)
	deck_modal_close_btn.pressed.connect(func(): deck_modal.visible = false)
	walk_btn.pressed.connect(_on_walk_pressed)
	discard_btn.pressed.connect(_on_discard_pressed)
	sort_color_btn.pressed.connect(func(): set_sort_mode("color"))
	sort_dir_btn.pressed.connect(func(): set_sort_mode("dir"))
	stone_btn.pressed.connect(func():
		setup_stone_modal_content()
		stone_modal.visible = true
	)
	stone_close_btn.pressed.connect(func(): stone_modal.visible = false)
	# Like the draft's `.vw`: tapping outside the panel closes the view.
	for view in [stone_modal, deck_modal]:
		var v: Control = view
		v.get_node("Dim").gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				v.visible = false
		)
	reward_next_btn.pressed.connect(_on_reward_shop_pressed)
	gameover_btn.pressed.connect(start_new_game)
	shop_leave_btn.pressed.connect(_on_shop_leave)
	shop_reroll_btn.pressed.connect(func(): shop_mgr.reroll_shop())
	shop_game_tab.pressed.connect(func(): shop_mgr.set_tab("game"))
	shop_artifact_tab.pressed.connect(func(): shop_mgr.set_tab("artifact"))
	shop_chaos_tab.pressed.connect(func(): shop_mgr.set_tab("chaos"))
	shop_upgrade_tab.pressed.connect(func(): shop_mgr.set_tab("upgrade"))

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

	# Chaos slots are usable outside the shop, exactly like the web draft.
	for i in range(chaos_slots.get_child_count()):
		var chaos_slot = chaos_slots.get_child(i) as Button
		var chaos_idx = i
		chaos_slot.pressed.connect(func(): _on_chaos_slot_pressed(chaos_idx))


## Buy/sell popup styled like the draft's `.pop` / `.popbox`:
## title, description, action button and a "ปิด" button.
func _setup_action_dialog() -> void:
	action_dialog = Control.new()
	action_dialog.name = "ActionPopup"
	action_dialog.visible = false
	action_dialog.z_index = 200
	action_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			action_dialog.visible = false
	)
	action_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_dialog.add_child(center)
	var box := PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(660, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2d2450")
	sb.border_color = COLORS["brass"]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(21)
	sb.content_margin_left = 33.0
	sb.content_margin_right = 33.0
	sb.content_margin_top = 27.0
	sb.content_margin_bottom = 27.0
	box.add_theme_stylebox_override("panel", sb)
	center.add_child(box)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 15)
	box.add_child(vb)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"BoldLabel"
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", COLORS["brass_bright"])
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)
	var rar := Label.new()
	rar.name = "Rar"
	rar.theme_type_variation = &"BoldLabel"
	rar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rar.add_theme_font_size_override("font_size", 18)
	vb.add_child(rar)
	var desc := Label.new()
	desc.name = "Desc"
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", COLORS["text_bright"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	var acts := HBoxContainer.new()
	acts.name = "Acts"
	acts.add_theme_constant_override("separation", 12)
	vb.add_child(acts)
	var ok := Button.new()
	ok.name = "Ok"
	var close := Button.new()
	close.name = "Close"
	close.text = "ปิด"
	for b in [ok, close]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", 22)
		var bs := StyleBoxFlat.new()
		bs.bg_color = COLORS["brass_bright"] if b == ok else Color("#c9c0e6")
		if b == ok:
			bs.border_width_bottom = 66
			bs.border_color = COLORS["brass"]
			bs.border_blend = true
			bs.content_margin_top = 0.0
			bs.content_margin_bottom = 0.0
		bs.set_corner_radius_all(15)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, bs)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color("#2a2140"))
		acts.add_child(b)
	ok.pressed.connect(func():
		action_dialog.visible = false
		if pending_dialog_action.is_valid():
			pending_dialog_action.call()
		pending_dialog_action = Callable()
	)
	close.pressed.connect(func(): action_dialog.visible = false)
	add_child(action_dialog)


func show_action_dialog(title_text: String, detail: String, confirm_text: String, action: Callable, disabled: bool = false, rarity: String = "") -> void:
	pending_dialog_action = action
	var rar := action_dialog.get_node("Center/Box/VB/Rar") as Label
	rar.visible = rarity != ""
	if rarity != "":
		# Draft `.rar` pill: COMMON / UNCOMMON / RARE.
		var pal := {"common": [Color("#3a3560"), Color("#d6d9ea")], "uncommon": [Color("#1e4a37"), Color("#6df0a8")], "rare": [Color("#4a3a10"), Color("#ffcf5a")]}
		var colors: Array = pal.get(rarity, pal["common"])
		var pill := StyleBoxFlat.new()
		pill.bg_color = colors[0]
		pill.set_corner_radius_all(99)
		pill.content_margin_left = 15.0
		pill.content_margin_right = 15.0
		pill.content_margin_top = 3.0
		pill.content_margin_bottom = 3.0
		rar.add_theme_stylebox_override("normal", pill)
		rar.add_theme_color_override("font_color", colors[1])
		rar.text = rarity.to_upper()
	action_dialog.get_node("Center/Box/VB/Title").text = title_text
	action_dialog.get_node("Center/Box/VB/Desc").text = detail
	var ok := action_dialog.get_node("Center/Box/VB/Acts/Ok") as Button
	ok.text = confirm_text
	ok.disabled = disabled
	ok.modulate.a = 0.4 if disabled else 1.0
	action_dialog.visible = true


func _input(event: InputEvent) -> void:
	if action_dialog != null and action_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_slot_drag(event.position)
		elif not drag_kind.is_empty():
			_finish_slot_drag(event.position)
	elif event is InputEventMouseMotion and not drag_kind.is_empty():
		if event.position.distance_to(drag_start) >= 10.0:
			drag_moved = true


func _begin_slot_drag(mouse_pos: Vector2) -> void:
	if is_busy:
		return
	for i in range(MAX_ARTIFACTS):
		var artifact_slot = artifact_row.get_child(i + 1) as Control
		if artifacts[i] != null and artifact_slot.get_global_rect().has_point(mouse_pos):
			drag_kind = "artifact"
			drag_from = i
			drag_start = mouse_pos
			drag_moved = false
			return
	for i in range(chaos_slots.get_child_count()):
		var chaos_slot = chaos_slots.get_child(i) as Control
		if chaos[i] != null and chaos_slot.get_global_rect().has_point(mouse_pos):
			drag_kind = "chaos"
			drag_from = i
			drag_start = mouse_pos
			drag_moved = false
			return


func _finish_slot_drag(mouse_pos: Vector2) -> void:
	var kind := drag_kind
	var from := drag_from
	var moved := drag_moved
	drag_kind = ""
	drag_from = -1
	drag_moved = false
	if not moved:
		return
	var target := -1
	if kind == "artifact":
		for i in range(MAX_ARTIFACTS):
			var slot = artifact_row.get_child(i + 1) as Control
			if slot.get_global_rect().has_point(mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = artifacts[from]
			artifacts[from] = artifacts[target]
			artifacts[target] = held
			sync_totems()
	elif kind == "chaos":
		for i in range(chaos_slots.get_child_count()):
			var slot = chaos_slots.get_child(i) as Control
			if slot.get_global_rect().has_point(mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = chaos[from]
			chaos[from] = chaos[target]
			chaos[target] = held
	if target >= 0:
		update_all_ui()
		get_viewport().set_input_as_handled()


# ==============================================================================
# Game Loop & Initializations
# ==============================================================================

func start_new_game() -> void:
	if is_busy:
		return
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
	discovered_formulas = ["col", "dsame", "alt", "dtile"]
	walk_base_damage = 0
	walk_mult_bonus = 0.0
	first_gem_triggered = false
	first_gem_tile = -1
	stone_formulas = StoneCalc.DEFAULT_FORMULAS.duplicate(true)
	totem_tiles.clear()
	reset_chaos()

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
	boss_skill()
	enemy_name.text = "👑 บอส" if is_boss() else "ศัตรู"

	start_new_round()


func boss_skill() -> void:
	enemy_skill_label.visible = false
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
	enemy_skill_label.text = "สกิลบอส: ใส่การ์ดเปล่า %d ใบเข้าสำรับ (ชั่วคราว)" % BOSS_BLANKS
	enemy_skill_label.visible = true


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
	apply_deck_mods()
	deck.shuffle()


func reset_chaos() -> void:
	chaos = [null, null, null]
	selected_chaos_slot = -1
	deck_mods.clear()
	gold_mods.clear()
	deck_removals.clear()
	chaos_mult_tiles.clear()
	chaos_xmult_tiles.clear()
	chaos_xatk_tiles.clear()
	chaos_crystals.clear()
	TILE_DIR = DEFAULT_TILE_DIR.duplicate()


func apply_deck_mods() -> void:
	for mod in deck_mods:
		for card in deck:
			if card["color"] == mod["from"] and card["dir"] == mod["dir"]:
				card["color"] = mod["to"]
				card["dir"] = mod["to_dir"]
				break
	for mod in gold_mods:
		for card in deck:
			if card["color"] == mod["color"] and card["dir"] == mod["dir"]:
				card["gold"] = true
				break
	for mod in deck_removals:
		for i in range(deck.size()):
			if deck[i]["color"] == mod["color"] and deck[i]["dir"] == mod["dir"]:
				deck.remove_at(i)
				break


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
	ui_renderer.update_all_ui()


func render_tiles() -> void:
	ui_renderer.render_tiles()


func pop_tile_anim(tile_idx: int) -> void:
	if tile_idx < 0 or tile_idx >= N_TILES: return
	sfx.play("place")
	var tile_btn = tiles_container.get_child(tile_idx) as Button
	VfxManager.pop_tile_anim(tile_btn)


func render_hand() -> void:
	ui_renderer.render_hand()


func set_sort_mode(mode: String) -> void:
	sort_mode = mode
	_style_sort_button(sort_color_btn, mode == "color")
	_style_sort_button(sort_dir_btn, mode == "dir")
	render_hand()


## Round fullscreen button next to Speed (web only). Browsers only allow
## fullscreen from a tap, so it has to be a button. Hidden when the page is
## already an installed app (PWA fullscreen/standalone) or the browser can't
## do fullscreen (iPhone).
func _setup_fullscreen_button() -> void:
	if not OS.has_feature("web"):
		return
	var can: bool = JavaScriptBridge.eval("!!document.fullscreenEnabled && !(window.matchMedia('(display-mode: fullscreen)').matches || window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true)", true)
	if not can:
		return
	var btn := Button.new()
	btn.name = "FullscreenBtn"
	btn.layout_mode = 1
	btn.anchors_preset = Control.PRESET_TOP_RIGHT
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -249.0
	btn.offset_right = -189.0
	btn.offset_top = 12.0
	btn.offset_bottom = 72.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.tooltip_text = "เต็มจอ"
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := restart_btn.get_theme_stylebox("normal" if st == "focus" else st)
		if sb != null:
			btn.add_theme_stylebox_override(st, sb)
	if ResourceLoader.exists("res://assets/ui/fullscreen.svg"):
		btn.icon = load("res://assets/ui/fullscreen.svg")
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 33)
	else:
		btn.text = "เต็มจอ"
	btn.pressed.connect(_toggle_fullscreen)
	$TopBar.add_child(btn)


## Round speaker button (mute / unmute), left of the fullscreen button.
func _setup_audio_button() -> void:
	var btn := Button.new()
	btn.name = "AudioBtn"
	btn.layout_mode = 1
	btn.anchors_preset = Control.PRESET_TOP_RIGHT
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	var slot := -321.0 if $TopBar.has_node("FullscreenBtn") else -249.0
	btn.offset_left = slot
	btn.offset_right = slot + 60.0
	btn.offset_top = 12.0
	btn.offset_bottom = 72.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := restart_btn.get_theme_stylebox("normal" if st == "focus" else st)
		if sb != null:
			btn.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, Color("#2a2140"))
	btn.add_theme_font_size_override("font_size", 28)
	btn.text = "🔇" if sfx.muted else "🔊"
	btn.pressed.connect(func():
		sfx.set_muted(not sfx.muted)
		btn.text = "🔇" if sfx.muted else "🔊"
		if not sfx.muted:
			sfx.play("coin"))
	$TopBar.add_child(btn)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Android: also lock to landscape (only allowed while fullscreen).
	JavaScriptBridge.eval("try{screen.orientation.lock('landscape').catch(function(){})}catch(e){}")


func _style_sort_button(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLORS["brass"] if active else Color(0, 0, 0, 0)
	sb.content_margin_left = 27.0
	sb.content_margin_right = 27.0
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	var font_col := Color("#2a2140") if active else Color("#a79fc4")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, font_col)


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


func _on_chaos_slot_pressed(slot_idx: int) -> void:
	if is_busy or slot_idx < 0 or slot_idx >= chaos.size():
		return
	var chaos_card = chaos[slot_idx]
	if chaos_card == null:
		return
	var kind: String = chaos_card["kind"]
	if kind in ["tdir", "mtile", "xmult", "xatk", "crystal"]:
		selected_chaos_slot = -1 if selected_chaos_slot == slot_idx else slot_idx
		chaos_msg("แตะช่องที่ต้องการวาง" if selected_chaos_slot >= 0 else "ยกเลิกแล้ว")
		update_all_ui()
		return
	_apply_hand_chaos(slot_idx)


func _apply_hand_chaos(slot_idx: int) -> void:
	var chaos_card = chaos[slot_idx]
	if chaos_card == null:
		return
	var picked: Array[Dictionary] = []
	for card in hand:
		if selected_card_ids.has(card["id"]):
			picked.append(card)
	var kind: String = chaos_card["kind"]
	if kind != "destroy" and picked.any(func(c): return c.get("is_blank", false)):
		chaos_msg("การ์ดเปล่าใช้ Chaos ไม่ได้")
		return
	if kind == "color":
		if picked.is_empty():
			chaos_msg("เลือก Gem ในมือก่อน (สูงสุด 2 ใบ)")
			return
		if picked.size() > 2:
			chaos_msg("เปลี่ยนสีได้สูงสุด 2 ใบ")
			return
		if picked.all(func(c): return c["color"] == chaos_card["col"]):
			chaos_msg("Gem ที่เลือกเป็นสี%sอยู่แล้ว" % ShopManager.COL_TH.get(chaos_card["col"], ""))
			return
		for card in picked:
			if card.get("is_blank", false):
				continue
			deck_mods.append({"from": card["color"], "dir": card["dir"], "to": chaos_card["col"], "to_dir": card["dir"]})
			card["color"] = chaos_card["col"]
		_finish_chaos(slot_idx, "🎨 เปลี่ยนเป็นสี%sถาวร" % ShopManager.COL_TH.get(chaos_card["col"], ""))
	elif kind == "dirc":
		if picked.is_empty():
			chaos_msg("เลือก Gem ในมือก่อน (1 ใบ)")
			return
		if picked.size() > 1:
			chaos_msg("เปลี่ยนทิศได้ทีละ 1 ใบ")
			return
		if picked[0]["dir"] == chaos_card["dir"]:
			chaos_msg("Gem ที่เลือกเป็นทิศ%sอยู่แล้ว" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
			return
		var card = picked[0]
		deck_mods.append({"from": card["color"], "dir": card["dir"], "to": card["color"], "to_dir": chaos_card["dir"]})
		card["dir"] = chaos_card["dir"]
		_finish_chaos(slot_idx, "🧭 เปลี่ยนเป็นทิศ%sถาวร" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
	elif kind == "goldify":
		if picked.size() != 1:
			chaos_msg("เลือก Gem ในมือ 1 ใบก่อน")
			return
		if picked[0].get("gold", false):
			chaos_msg("ใบนี้เป็นการ์ดทองอยู่แล้ว")
			return
		picked[0]["gold"] = true
		gold_mods.append({"color": picked[0]["color"], "dir": picked[0]["dir"]})
		_finish_chaos(slot_idx, "✨ เป็นการ์ดทองถาวร")
	elif kind == "destroy":
		if picked.size() != 2:
			chaos_msg("เลือก Gem ในมือ 2 ใบก่อน")
			return
		for card in picked:
			if not card.get("is_blank", false):
				deck_removals.append({"color": card["color"], "dir": card["dir"]})
			hand.erase(card)
		_finish_chaos(slot_idx, "💥 ทำลาย Gem 2 ใบถาวร")


func _apply_chaos_to_tile(tile_idx: int) -> void:
	if selected_chaos_slot < 0 or selected_chaos_slot >= chaos.size():
		return
	var chaos_card = chaos[selected_chaos_slot]
	if chaos_card == null:
		selected_chaos_slot = -1
		return
	var kind: String = chaos_card["kind"]
	if kind == "tdir":
		if TILE_DIR[tile_idx] == chaos_card["dir"]:
			chaos_msg("ช่องนี้เป็นทิศ%sอยู่แล้ว" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
			return
		TILE_DIR[tile_idx] = chaos_card["dir"]
	elif kind == "mtile":
		if chaos_mult_tiles.has(tile_idx):
			chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		chaos_mult_tiles[tile_idx] = true
	elif kind == "xmult":
		if chaos_xmult_tiles.has(tile_idx):
			chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		chaos_xmult_tiles[tile_idx] = true
	elif kind == "xatk":
		if chaos_xatk_tiles.has(tile_idx):
			chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		chaos_xatk_tiles[tile_idx] = true
	elif kind == "crystal":
		if placed_cards.has(tile_idx) or chaos_crystals.has(tile_idx):
			chaos_msg("วางผลึกได้เฉพาะช่องว่าง")
			return
		chaos_crystals[tile_idx] = CRYSTAL_HP
	else:
		return
	_finish_chaos(selected_chaos_slot, "")


func _finish_chaos(slot_idx: int, message: String) -> void:
	chaos[slot_idx] = null
	selected_chaos_slot = -1
	selected_card_ids.clear()
	artifact_sys.chaos_used()
	if message != "":
		chaos_msg(message)
	update_all_ui()
	refresh_calc()


func hit_crystal(tile_idx: int) -> Dictionary:
	if not chaos_crystals.has(tile_idx):
		return {"used": 0, "broken": false}
	var current_hp: int = chaos_crystals[tile_idx]
	var incoming: int = maxi(1, walk_base_damage)
	var used: int = mini(incoming, current_hp)
	walk_base_damage = maxi(0, walk_base_damage - used)
	current_hp -= used
	if current_hp > 0:
		chaos_crystals[tile_idx] = current_hp
		update_all_ui()
		return {"used": used, "broken": false}
	chaos_crystals.erase(tile_idx)
	for _i in range(CRYSTAL_GEMS):
		var color: String = COLOR_ORDER[randi_range(0, COLOR_ORDER.size() - 1)]
		var direction: String = DIR_ORDER[randi_range(0, DIR_ORDER.size() - 1)]
		var deck_card := {"id": card_uid_counter, "color": color, "dir": direction, "is_blank": false, "gold": false}
		card_uid_counter += 1
		deck.append(deck_card)
		var hand_card := deck_card.duplicate()
		hand_card["id"] = card_uid_counter
		card_uid_counter += 1
		hand.append(hand_card)
	msg_label.text = "💎 ผลึกแตก! ได้ Gem +%d" % CRYSTAL_GEMS
	update_all_ui()
	return {"used": used, "broken": true}


func _on_tile_clicked(tile_idx: int) -> void:
	if is_busy: return
	if selected_chaos_slot >= 0:
		_apply_chaos_to_tile(tile_idx)
		return
	if chaos_crystals.has(tile_idx):
		msg_label.text = "ช่องนี้มีผลึก Gem วาง Gem ไม่ได้"
		return

	# Rule: If tile already has card, return it to hand!
	if placed_cards.has(tile_idx):
		if hand.size() >= hand_max:
			msg_label.text = "มือเต็ม เอา Gem กลับไม่ได้"
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
			pop_tile_anim(tile_idx)


func _on_discard_pressed() -> void:
	if is_busy or selected_card_ids.is_empty() or discards_left <= 0:
		return
	if placed_cards.size() > 0 and not artifact_sys.has_rule(&"free_discard"):
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
	var result: Dictionary = StoneCalc.calculate_groups(placed_cards, TILE_DIR, stone_formulas, N_TILES)
	# Equalizer lifts every completed Stone group to the highest group value.
	# This mirrors the draft's updateGroups() rule and changes real walk damage,
	# not merely the number printed under a tile.
	if artifact_sys.has_rule(&"equal_groups") and result["groups"].size() >= 2:
		var highest := 0
		for group in result["groups"]:
			highest = maxi(highest, int(group["res"]["a"]))
		for group in result["groups"]:
			group["res"]["a"] = highest
			for tile_idx in group["idxs"]:
				result["grp_val"][tile_idx] = highest
		var total := 0
		for tile_idx in range(N_TILES):
			if placed_cards.has(tile_idx) and not placed_cards[tile_idx].get("is_blank", false):
				total += int(result["grp_val"].get(tile_idx, 1))
		result["base_dmg"] = total
	return result


func tile_direction_count(direction: String) -> int:
	var count := 0
	for tile_direction in TILE_DIR:
		if tile_direction == direction:
			count += 1
	return count


func tile_direction_run(direction: String) -> int:
	var best := 0
	var run := 0
	for tile_direction in TILE_DIR:
		run = run + 1 if tile_direction == direction else 0
		best = maxi(best, run)
	return best


func matching_group_count(direction: String, color: String) -> int:
	var count := 0
	for group in calculate_groups()["groups"]:
		var matches := 0
		for tile_idx in group["idxs"]:
			var card = placed_cards.get(tile_idx)
			if card != null and TILE_DIR[tile_idx] == direction and card.get("dir") == direction and (color.is_empty() or card.get("color") == color):
				matches += 1
		if matches >= 2:
			count += 1
	return count


func matching_card_count(direction: String, color: String) -> int:
	var count := 0
	for tile_idx in placed_cards:
		var card = placed_cards[tile_idx]
		if TILE_DIR[tile_idx] == direction and card.get("dir") == direction and card.get("color") == color:
			count += 1
	return count


func give_random_chaos() -> bool:
	var slot: int = chaos.find(null)
	if slot < 0:
		return false
	var definition: Dictionary = ShopManager.CHAOS_CATALOG[randi_range(0, ShopManager.CHAOS_CATALOG.size() - 1)]
	var card: Dictionary = {"kind": definition["kind"]}
	if definition.has("col"):
		card["col"] = definition["col"]
	if definition.has("dir"):
		card["dir"] = definition["dir"]
	chaos[slot] = card
	return true


func prepare_walk_artifacts() -> void:
	# Counters fed by the board and Chaos makers trigger right before the
	# walk, matching the draft's pre-route timing.
	artifact_sys.pre_walk()


func sync_totems() -> void:
	var desired := mini(N_TILES, artifact_sys.rule_count(&"totem"))
	while totem_tiles.size() > desired:
		totem_tiles.pop_back()
	while totem_tiles.size() < desired:
		for tile_idx in range(N_TILES):
			if not totem_tiles.has(tile_idx):
				totem_tiles.append(tile_idx)
				break


func totem_attack(tile_idx: int) -> int:
	return int(round(20.0 + 40.0 * pow(float(N_TILES - 1 - tile_idx) / float(N_TILES - 1), 2.0)))


func passive_chaos_tile_count() -> int:
	return chaos_mult_tiles.size() + chaos_xmult_tiles.size() + chaos_xatk_tiles.size()


## Final attack. `steps` (optional, passed by the caller) is filled like the
## draft's attackSeq(): steps[0] is the raw walk total, then one entry per
## artifact that fired: {"slot": artifact slot, "atk": float, "mult": float}.
func compute_attack(steps: Array = []) -> Dictionary:
	var calc = calculate_groups()
	var atk: float = 1 + (walk_base_damage if is_busy else calc["base_dmg"])
	var mult: float = 1.0 + (walk_mult_bonus if is_busy else 0.0)
	steps.append({"slot": -1, "atk": atk, "mult": mult})

	# Artifacts in slot order like the draft's attackSeq() (South-five first).
	var result: Dictionary = artifact_sys.attack(calc, atk, mult, steps)
	atk = result["atk"]
	mult = result["mult"]
	return {"atk": int(round(atk)), "mult": mult, "dmg": int(round(atk * mult))}


func artifact_slot(type_key: String) -> int:
	for i in range(artifacts.size()):
		if artifacts[i] != null and artifacts[i].get("type") == type_key:
			return i
	return -1


## Draft `.islot.itrig`: the slot pops to ×1.3 with a glow for 0.5 s.
func flash_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx + 1 >= artifact_row.get_child_count():
		return
	var slot := artifact_row.get_child(slot_idx + 1) as Control
	VfxManager.trigger_juice(slot, speed_multiplier, 1.3, 9.0)


func begin_walk_damage() -> void:
	walk_base_damage = 0
	walk_mult_bonus = 0.0
	first_gem_triggered = false
	first_gem_tile = -1
	prepare_walk_artifacts()


func apply_tile_walk_effects(tile_idx: int, helper_pass: bool = false) -> Dictionary:
	var card = placed_cards.get(tile_idx)
	if card == null or card.get("is_blank", false):
		return {"gain": 0, "extra": 0, "fired": []}

	var gain = int(calculate_groups()["grp_val"].get(tile_idx, 1))
	walk_base_damage += gain
	if chaos_mult_tiles.has(tile_idx):
		walk_mult_bonus += 5.0
	if chaos_xmult_tiles.has(tile_idx):
		walk_mult_bonus = (1.0 + walk_mult_bonus) * 1.2 - 1.0
	if chaos_xatk_tiles.has(tile_idx):
		walk_base_damage = int(round(walk_base_damage * 1.2))
	var landed: Dictionary = artifact_sys.land(tile_idx, card, gain, helper_pass)
	var extra: int = landed["extra"]
	var fired: Array = landed["fired"]  # landing artifacts that took effect (for the flash + sparks)
	var coin_won: bool = landed["coin_won"]
	return {"gain": gain, "extra": extra, "fired": fired, "coin_won": coin_won}


## Number formatting from the HTML draft: integers without decimals,
## at most two decimals otherwise, thousands separators from 1,000.
static func fmt_num(v: float) -> String:
	var txt: String
	if is_equal_approx(v, round(v)):
		txt = str(int(round(v)))
	else:
		txt = ("%.2f" % v).rstrip("0").rstrip(".")
	if absf(v) >= 1000.0:
		var parts := txt.split(".")
		var digits: String = parts[0].trim_prefix("-")
		var grouped := ""
		while digits.length() > 3:
			grouped = "," + digits.right(3) + grouped
			digits = digits.left(digits.length() - 3)
		txt = ("-" if v < 0 else "") + digits + grouped + ("." + parts[1] if parts.size() > 1 else "")
	return txt


## Draft showCalc(): `ATK × MULT = TOTAL`.
func show_calc(atk: float, mult: float) -> void:
	var new_text := "[center][b][color=#5fb0ff]%s[/color][color=#a79fc4] × [/color][color=#ff6b6b]%s[/color][color=#a79fc4] = [/color]%s[/b][/center]" % [fmt_num(snappedf(atk, 0.01)), fmt_num(snappedf(mult, 0.01)), fmt_num(round(atk * mult))]
	var changed: bool = calc_label.text != new_text
	calc_label.text = new_text
	if changed and is_busy:
		VfxManager.trigger_juice(calc_label, speed_multiplier, 1.1, 0.0, 0.0)


func refresh_calc() -> void:
	var result = calculate_groups()
	# Draft refreshCalc(): `1 × 1 = 1` while placing; during the walk the totals
	# the fireball has collected so far. Artifacts are applied one by one after
	# the walk (BattleManager), not in this preview.
	if is_busy:
		show_calc(1.0 + walk_base_damage, 1.0 + walk_mult_bonus)
	else:
		show_calc(1.0, 1.0)

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

	# Render the richer connected Stone badges after the legacy label update.
	# The temporary legacy loop remains here while this dirty-worktree refactor is
	# being consolidated, but it no longer controls the visible result.
	ui_renderer.render_tiles()


# --- Smart Auto-Placement Solver ---
func auto_place_selected() -> void:
	var cards_to_place = []
	for card in hand:
		if selected_card_ids.has(card["id"]):
			cards_to_place.append(card)

	var result = StoneCalc.solve_best_placement(cards_to_place, placed_cards, TILE_DIR, stone_formulas, N_TILES)
	var best_cards: Array = result["cards"]
	var slots: Array = result["slots"]
	if slots.is_empty(): return

	for k in range(best_cards.size()):
		hand.erase(best_cards[k])
		placed_cards[slots[k]] = best_cards[k]

	selected_card_ids.clear()
	update_all_ui()
	refresh_calc()
	for slot in slots:
		pop_tile_anim(slot)


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
	battle_mgr.run_walk()


func _spawn_tile_popup(tile_idx: int) -> void:
	battle_mgr._spawn_tile_popup(tile_idx)


func on_victory() -> void:
	is_busy = false
	msg_label.text = "ชนะ!"

	# Matching draft reward: base + walks + interest + reward artifacts.
	var base_reward = 4
	var interest = mini(10, int(coins / 5))
	var walk_reward = walks_left
	var rewards: Dictionary = artifact_sys.victory()
	var arti_pay: int = rewards["rows"].get("arti", 0)
	var fate_pay: int = rewards["rows"].get("fate", 0)
	var walk_coin_bonus: int = rewards["rows"].get("walk", 0)
	var reward_fx: Array = rewards["fx"]
	if is_boss() and chaos.has(null):
		chaos[chaos.find(null)] = {"kind": "crystal"}
		msg_label.text = "💎 บอสทิ้ง Chaos ผลึก Gem!"
	var total_gain = base_reward + walk_reward + interest + int(rewards["total"])
	coins += total_gain
	if not reward_fx.is_empty():
		# The artifact row is hidden behind the reward panel, so show it paying out first.
		render_artifact_row()
		await battle_mgr.fx_artifact_types(reward_fx)
		await get_tree().create_timer(0.45 / speed_multiplier).timeout
	sfx.play("coin")

	VfxManager.coin_rain(effects_layer, clampi(total_gain * 3, 12, 40), size.x * 0.6)
	render_reward_summary(base_reward, walks_left, walk_reward, coins - total_gain, interest, total_gain, arti_pay, fate_pay, walk_coin_bonus)
	update_all_ui()
	reward_modal.visible = true


func artifact_count_any() -> int:
	var count := 0
	for artifact in artifacts:
		if artifact != null:
			count += 1
	return count


func render_reward_summary(base_reward: int, walks_remaining: int, walk_reward: int, held_coins: int, interest: int, total_gain: int, arti_pay: int = 0, fate_pay: int = 0, walk_coin_bonus: int = 0) -> void:
	for child in reward_info.get_children():
		child.queue_free()
	_add_reward_row("ชนะศัตรู", "🪙 +%d" % base_reward)
	_add_reward_row("เลือดที่เหลือ (รับได้อีก %d ครั้ง) × 1" % walks_remaining, "🪙 +%d" % walk_reward)
	_add_reward_row("ดอกเบี้ย (มี %d ÷ 5 · สูงสุด 10)" % held_coins, "🪙 +%d" % interest)
	if arti_pay > 0:
		_add_reward_row("รายได้ Artifact", "🪙 +%d" % arti_pay)
	if fate_pay > 0:
		_add_reward_row("รายได้ Gem", "🪙 +%d" % fate_pay)
	if walk_coin_bonus > 0:
		_add_reward_row("เดินประหยัด", "🪙 +%d" % walk_coin_bonus)
	_add_reward_row("รวม", "🪙 +%d" % total_gain, true)


func _add_reward_row(left_text: String, right_text: String, is_total: bool = false) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	if not is_total:
		row_style.border_width_bottom = 1
		row_style.border_color = Color(0.827451, 0.65098, 0.290196, 0.3)
	row_style.content_margin_left = 6.0
	row_style.content_margin_top = 12.0
	row_style.content_margin_right = 6.0
	row_style.content_margin_bottom = 12.0
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	row.add_child(hbox)
	var left := Label.new()
	left.text = left_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_font_size_override("font_size", 36 if is_total else 27)
	if is_total:
		left.theme_type_variation = &"BoldLabel"
	left.add_theme_color_override("font_color", Color("#f0cf86") if is_total else Color("#f3ead7"))
	hbox.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.add_theme_font_size_override("font_size", 36 if is_total else 27)
	if is_total:
		right.theme_type_variation = &"BoldLabel"
	right.add_theme_color_override("font_color", Color("#f0cf86") if is_total else Color("#f3ead7"))
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(right)
	reward_info.add_child(row)


func _on_reward_shop_pressed() -> void:
	reward_modal.visible = false
	open_shop()


func open_shop() -> void:
	shop_mgr.open_shop()


func _render_shop_owned() -> void:
	shop_mgr.render_shop_owned()


func _render_shop_offers() -> void:
	shop_mgr.render_shop_offers()


func _buy_stat(stat_type: String, price: int) -> void:
	shop_mgr.buy_stat(stat_type, price)


func _buy_stone_upgrade(formula_idx: int, cost: int) -> void:
	shop_mgr.buy_stone_upgrade(formula_idx, cost)


func _buy_artifact(item: Dictionary) -> void:
	shop_mgr.buy_artifact(item)


func _sell_artifact(slot_idx: int) -> void:
	shop_mgr.sell_artifact(slot_idx)


func _on_shop_leave() -> void:
	shop_mgr.on_shop_leave()


func _on_artifact_slot_pressed(slot_idx: int) -> void:
	shop_mgr.on_artifact_slot_pressed(slot_idx)


func render_artifact_row() -> void:
	ui_renderer.render_artifact_row()


func render_chaos_row() -> void:
	ui_renderer.render_chaos_row()


func has_artifact(type_key: String) -> bool:
	return ShopManager.has_artifact(artifacts, type_key)


func on_game_over() -> void:
	is_busy = false
	sfx.play("lose")
	msg_label.text = ""
	gameover_info.text = "ผ่านศัตรู %d ตัว" % (stage - 1)
	update_all_ui()
	gameover_modal.visible = true


func setup_stone_modal_content() -> void:
	ui_renderer.setup_stone_modal_content()


func _on_speed_toggle() -> void:
	speed_multiplier = 1.0 if speed_multiplier >= 5.0 else speed_multiplier + 1.0
	speed_btn.text = "▶ x1" if speed_multiplier == 1.0 else "⏩ x%d" % int(speed_multiplier)


func open_deck_modal() -> void:
	ui_renderer.open_deck_modal()


# ==============================================================================
# Helper VFX Methods
# ==============================================================================

func fire_laser_beam(line: Line2D, from_pos: Vector2, to_pos: Vector2, col: Color, beam_w: float = 20.0, duration: float = 0.25) -> void:
	VfxManager.fire_laser_beam(effects_layer, line, from_pos, to_pos, col, beam_w, duration, speed_multiplier)


func shake_node(node: Control, intensity: float = 14.0, duration: float = 0.38, rot_deg: float = 6.0) -> void:
	VfxManager.shake_node(node, intensity, duration, speed_multiplier, rot_deg)


func spawn_damage_number(text: String, target_global_pos: Vector2, col: Color = Color("#ff4d5e"), is_big: bool = true) -> void:
	VfxManager.spawn_damage_number(effects_layer, text, target_global_pos, col, is_big, speed_multiplier)


func show_discovery_toast(formula_key: String) -> void:
	for k in range(stone_formulas.size()):
		var f: Dictionary = stone_formulas[k]
		if f["key"] == formula_key:
			# Draft disc-toast: "✨ ค้นพบสูตรใหม่ · stone N name · ATK a"
			toast_label.text = "✨ ค้นพบสูตรใหม่ · stone %d %s · ATK %d" % [k + 1, f["name"], f["a"]]
			VfxManager.show_center_toast(toast, 2.6)
			return


var _chaos_toast: PanelContainer
var _chaos_toast_tween: Tween

## Draft `.ctoast`: purple-bordered message at the top while using Chaos.
func chaos_msg(text: String) -> void:
	if _chaos_toast == null:
		_chaos_toast = PanelContainer.new()
		_chaos_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chaos_toast.z_index = 150
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#241a3d")
		sb.border_color = Color("#a66cf2")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 27.0
		sb.content_margin_right = 27.0
		sb.content_margin_top = 15.0
		sb.content_margin_bottom = 15.0
		_chaos_toast.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.theme_type_variation = &"BoldLabel"
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chaos_toast.add_child(l)
		effects_layer.add_child(_chaos_toast)
	(_chaos_toast.get_child(0) as Label).text = text
	_chaos_toast.reset_size()
	_chaos_toast.position = Vector2((size.x - _chaos_toast.size.x) * 0.5, 105.0)
	if _chaos_toast_tween != null:
		_chaos_toast_tween.kill()
	_chaos_toast.modulate.a = 0.0
	_chaos_toast_tween = create_tween()
	_chaos_toast_tween.tween_property(_chaos_toast, "modulate:a", 1.0, 0.2)
	_chaos_toast_tween.tween_interval(2.0)
	_chaos_toast_tween.tween_property(_chaos_toast, "modulate:a", 0.0, 0.2)
