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
@onready var calc_label: RichTextLabel = $Preview/CalcLabel
@onready var summary_label: Label = $Preview/SummaryLabel

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
@onready var shop_offer_frame: PanelContainer = $ShopModal/ShopVBox/ShopOfferFrame
@onready var shop_offer_container: Container = $ShopModal/ShopVBox/ShopOfferFrame/ShopOfferScroll/ShopOfferContainer


var battle_mgr: BattleManager
var shop_mgr: ShopManager
var ui_renderer: UiRenderer
var board_calc: BoardCalc
var toolbar: ToolbarControls
var action_dlg: ActionDialog
var slot_drag: SlotDrag
var chaos_ctl: ChaosController
var reward_flow: RewardFlow
var action_dialog: Control
var pending_dialog_action: Callable


func _ready() -> void:
	sfx = preload("res://scripts/sfx_manager.gd").new()
	add_child(sfx)
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://assets/shaders/bg_drift.gdshader")
	$Background.material = bg_mat
	GameAssets.load_all(N_TILES)
	setup_token_visual()
	_setup_beams()
	toolbar = ToolbarControls.new(self)
	action_dlg = ActionDialog.new(self)
	slot_drag = SlotDrag.new(self)
	chaos_ctl = ChaosController.new(self)
	reward_flow = RewardFlow.new(self)
	connect_ui_signals()
	battle_mgr = BattleManager.new(self)
	artifact_sys = ArtifactSystem.new(self)
	shop_mgr = ShopManager.new(self)
	ui_renderer = UiRenderer.new(self)
	board_calc = BoardCalc.new(self)
	StoneCalc.validate_formulas(stone_formulas)
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
	if GameAssets.BALL_TEXTURE != null:
		var tex_rect = TextureRect.new()
		tex_rect.name = "BallTexture"
		tex_rect.texture = GameAssets.BALL_TEXTURE
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


func _setup_action_dialog() -> void:
	action_dlg.setup()


func show_action_dialog(title_text: String, detail: String, confirm_text: String, action: Callable, disabled: bool = false, rarity: String = "") -> void:
	action_dlg.show_dialog(title_text, detail, confirm_text, action, disabled, rarity)


func _input(event: InputEvent) -> void:
	slot_drag.on_input(event)


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
	StoneCalc.validate_formulas(stone_formulas)
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
	var old_totems := totem_tiles.duplicate()
	board_calc.shuffle_totems()
	update_all_ui()
	refresh_calc()
	for t in totem_tiles:
		if not old_totems.has(t):
			VfxManager.tile_glow(tiles_container.get_child(t) as Control, Color("#7fd0ff"))


# ==============================================================================
# Rendering: Tiles, Hand & UI
# ==============================================================================

func update_all_ui() -> void:
	ui_renderer.update_all_ui()


func render_tiles() -> void:
	ui_renderer.render_tiles()


func pop_tile_anim(tile_idx: int, delay: float = 0.0) -> void:
	if tile_idx < 0 or tile_idx >= N_TILES: return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(sfx.play.bind("place"))
	else:
		sfx.play("place")
	var tile_btn = tiles_container.get_child(tile_idx) as Button
	VfxManager.pop_tile_anim(tile_btn, delay)


func render_hand() -> void:
	ui_renderer.render_hand()


func set_sort_mode(mode: String) -> void:
	sort_mode = mode
	_style_sort_button(sort_color_btn, mode == "color")
	_style_sort_button(sort_dir_btn, mode == "dir")
	render_hand()


func _setup_fullscreen_button() -> void:
	toolbar._setup_fullscreen_button()


func _setup_audio_button() -> void:
	toolbar._setup_audio_button()


func _toggle_fullscreen() -> void:
	toolbar._toggle_fullscreen()


func _style_sort_button(btn: Button, active: bool) -> void:
	toolbar._style_sort_button(btn, active)


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
	chaos_ctl.on_slot_pressed(slot_idx)


func _finish_chaos(slot_idx: int, message: String) -> void:
	chaos_ctl.finish(slot_idx, message)


func hit_crystal(tile_idx: int) -> Dictionary:
	return chaos_ctl.hit_crystal(tile_idx)


func _on_tile_clicked(tile_idx: int) -> void:
	chaos_ctl.on_tile_clicked(tile_idx)


func _on_discard_pressed() -> void:
	chaos_ctl.on_discard_pressed()



# ==============================================================================
# Stone Calculations & Group Combinations (Matching Draft calcGroups)
# ==============================================================================

func calculate_groups() -> Dictionary:
	return board_calc.calculate_groups()


func tile_direction_count(direction: String) -> int:
	return board_calc.tile_direction_count(direction)


func tile_direction_run(direction: String) -> int:
	return board_calc.tile_direction_run(direction)


func matching_group_count(direction: String, color: String) -> int:
	return board_calc.matching_group_count(direction, color)


func matching_card_count(direction: String, color: String) -> int:
	return board_calc.matching_card_count(direction, color)


func give_random_chaos() -> bool:
	var slot: int = chaos.find(null)
	if slot < 0:
		return false
	var definition: Dictionary = ShopManager.CHAOS_CATALOG[randi_range(0, ShopManager.CHAOS_CATALOG.size() - 1)]
	chaos[slot] = ArtifactSystem.chaos_def(definition).make_card()
	return true


func prepare_walk_artifacts() -> void:
	# Counters fed by the board and Chaos makers trigger right before the
	# walk, matching the draft's pre-route timing.
	artifact_sys.pre_walk()


func sync_totems() -> void:
	board_calc.sync_totems()


func totem_attack(tile_idx: int) -> int:
	return board_calc.totem_attack(tile_idx)


func passive_chaos_tile_count() -> int:
	return board_calc.passive_chaos_tile_count()


func compute_attack(steps: Array = []) -> Dictionary:
	return board_calc.compute_attack(steps)


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
	return board_calc.apply_tile_walk_effects(tile_idx, helper_pass)


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


## Live calc: `ATK × MULT` only. The total is shown big by BattleManager._show_summary once every trigger has resolved.
func show_calc(atk: float, mult: float) -> void:
	var new_text := "[center][b][color=#5fb0ff]%s[/color][color=#a79fc4] × [/color][color=#ff6b6b]%s[/color][/b][/center]" % [fmt_num(snappedf(atk, 0.01)), fmt_num(snappedf(mult, 0.01))]
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
		summary_label.visible = false

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
			var g_col = GameAssets.COLORS["brass"]
			for g in result["groups"]:
				if g["idxs"].has(i):
					if g["col"] != null:
						g_col = GameAssets.COLORS.get(g["col"], GameAssets.COLORS["brass"])
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
## Cards placed one at a time: each hand card leaves the hand, swoops to its
## tile (accelerating, with a small arc) and lands with a pop and a rising
## note, one beat after the previous card.
const PLACE_BEAT := 0.28     # seconds between launches
const PLACE_FLIGHT := 0.48   # seconds in the air
var _placing: bool = false


func auto_place_selected() -> void:
	var cards_to_place = []
	for card in hand:
		if selected_card_ids.has(card["id"]):
			cards_to_place.append(card)

	var result = StoneCalc.solve_best_placement(cards_to_place, placed_cards, TILE_DIR, stone_formulas, N_TILES)
	var best_cards: Array = result["cards"]
	var slots: Array = result["slots"]
	if slots.is_empty(): return

	# Copy each card's hand visual before the hand is rebuilt.
	var flights: Array = []
	for k in range(best_cards.size()):
		var idx: int = hand.find(best_cards[k])
		var proxy: Control = null
		var from_rect := Rect2()
		if idx >= 0 and idx < hand_container.get_child_count():
			var src := hand_container.get_child(idx) as Control
			from_rect = src.get_global_rect()
			proxy = src.duplicate() as Control
			var sway := proxy.get_node_or_null("CardSway")
			if sway != null:
				proxy.remove_child(sway)
				sway.free()
			proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile_btn := tiles_container.get_child(slots[k]) as Button
		flights.append({"proxy": proxy, "from": from_rect, "tile": tile_btn, "empty_icon": tile_btn.icon})

	for k in range(best_cards.size()):
		hand.erase(best_cards[k])
		placed_cards[slots[k]] = best_cards[k]

	selected_card_ids.clear()
	update_all_ui()
	refresh_calc()

	_placing = true
	for k in range(flights.size()):
		var fl: Dictionary = flights[k]
		var tile_btn: Button = fl["tile"]
		var placed_icon = tile_btn.icon
		tile_btn.icon = fl["empty_icon"]   # empty slot until the card lands
		var proxy: Control = fl["proxy"]
		var last: bool = k == flights.size() - 1
		if proxy == null:
			get_tree().create_timer(k * PLACE_BEAT).timeout.connect(
				_land_card.bind(tile_btn, placed_icon, null, k, last))
			continue
		add_child(proxy)
		proxy.z_index = 200
		proxy.pivot_offset = proxy.size * 0.5
		var from_rect: Rect2 = fl["from"]
		var to_rect := tile_btn.get_global_rect()
		var p0 := from_rect.get_center()
		var p1 := to_rect.get_center()
		var s1 := Vector2.ONE * minf(to_rect.size.x / maxf(from_rect.size.x, 1.0), to_rect.size.y / maxf(from_rect.size.y, 1.0))
		var r0 := proxy.rotation
		proxy.global_position = p0 - proxy.size * 0.5
		var tw := proxy.create_tween()
		tw.tween_interval(k * PLACE_BEAT)
		tw.tween_callback(sfx.play.bind("whoosh", 1.0 + 0.08 * k, -12.0))
		tw.tween_method(func(t: float) -> void:
			var pos := p0.lerp(p1, t) + Vector2(0.0, -sin(PI * t) * 70.0)
			proxy.global_position = pos - proxy.size * 0.5
			proxy.scale = Vector2.ONE.lerp(s1, t)
			proxy.rotation = lerpf(r0, 0.0, t), 0.0, 1.0, PLACE_FLIGHT) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_land_card.bind(tile_btn, placed_icon, proxy, k, last))


func _land_card(tile_btn: Button, placed_icon: Texture2D, proxy: Control, k: int, last: bool) -> void:
	if is_instance_valid(proxy):
		proxy.queue_free()
	if is_instance_valid(tile_btn):
		tile_btn.icon = placed_icon
		sfx.step(k)
		VfxManager.pop_tile_anim(tile_btn, 0.0, true)
	if last:
		_placing = false


# ==============================================================================
# Animated Walk & Battle Execution
# ==============================================================================

func _on_walk_pressed() -> void:
	if is_busy or _placing: return

	# If cards selected, click walk executes auto-placement
	if selected_card_ids.size() > 0:
		auto_place_selected()
		return

	if walks_left <= 0: return
	battle_mgr.run_walk()


func _spawn_tile_popup(tile_idx: int) -> void:
	battle_mgr._spawn_tile_popup(tile_idx)


func on_victory() -> void:
	await reward_flow.on_victory()


func artifact_count_any() -> int:
	var count := 0
	for artifact in artifacts:
		if artifact != null:
			count += 1
	return count


func _on_reward_shop_pressed() -> void:
	reward_modal.visible = false
	open_shop()


func open_shop() -> void:
	shop_mgr.open_shop()


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
