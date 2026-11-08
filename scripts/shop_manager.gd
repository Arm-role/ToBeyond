class_name ShopManager
extends RefCounted

const MAX_ARTIFACTS: int = 5
const HAND_CAP: int = 12
# These entries are deliberately disabled in the HTML draft itself: its
# one-row board cannot support the required route/board mechanics yet.
const DRAFT_DISABLED_ARTIFACTS: Array[String] = ["fatePay", "helperC", "helperR", "lshape", "moneybox"]

const ARTIFACT_CATALOG: Array[Dictionary] = [
	{"type": "add5",        "name": "Gem Blade",       "icon": "⚔️", "desc": "+10 ATK เพิ่มเติมเมื่อยิงโจมตี",          "color": Color("#2f7fd6"), "price": 5},
	{"type": "mult2",       "name": "Rune Lens",        "icon": "🔮", "desc": "ตัวคูณ +5 ก่อนคิดดาเมจสุดท้าย",          "color": Color("#d63a3a"), "price": 6},
	{"type": "reverse",     "name": "Mirror Walk",      "icon": "↩️", "desc": "ลูกไฟเดินย้อนกลับและทำผลของแต่ละช่องซ้ำ",   "color": Color("#a66cf2"), "price": 6},
	{"type": "emptyAtk",    "name": "Empty Fist",       "icon": "👊", "desc": "+2 ATK ต่อช่องกระดานที่ว่างเปล่า",       "color": Color("#a66cf2"), "price": 6},
	{"type": "firstGem",    "name": "First Strike",     "icon": "🥇", "desc": "Gem ใบแรกที่ลูกไฟถึงได้รับโบนัสพลังตามกลุ่ม",  "color": Color("#f08a24"), "price": 6},
	{"type": "walkCoin",    "name": "Gold Step",        "icon": "👟", "desc": "รับ 🪙 1 เหรียญต่อรอบเดินที่เหลือเมื่อชนะ", "color": Color("#f08a24"), "price": 6},
	{"type": "stoneUp",     "name": "Stone Carver",     "icon": "🪨", "desc": "ตัวคูณเริ่ม ×1 และเพิ่มตามการอัปเกรด Stone",  "color": Color("#a66cf2"), "price": 7, "m": 1.0},
	{"type": "freediscard", "name": "Wild Shuffle",     "icon": "♻️", "desc": "ทิ้งการ์ดได้แม้มี Gem วางอยู่บนกระดาน",   "color": Color("#2e9e5b"), "price": 8},
	{"type": "atk15",       "name": "Power Core",       "icon": "⚡", "desc": "ATK รวมทั้งหมด ×1.5",                    "color": Color("#2f7fd6"), "price": 8},
	{"type": "greenCoin",   "name": "Coin Hoard",       "icon": "🪙", "desc": "ตก Gem สีเขียวมีโอกาส 1/3 ได้ 1🪙",            "color": Color("#2e9e5b"), "price": 6},
	{"type":"stone3", "name":"โบนัสกลุ่มสี", "icon":"💠", "desc":"โบนัส Stone กลุ่มสี", "color":Color("#2f7fd6"), "price":6},
	{"type":"tileAtk", "name":"พลังช่องพิเศษ", "icon":"✦", "desc":"เพิ่มพลังตามช่องพิเศษ", "color":Color("#a66cf2"), "price":6},
	{"type":"north5", "name":"แนวเหนือ", "icon":"N5", "desc":"โบนัสเมื่อทิศเหนือเรียงกัน", "color":Color("#f08a24"), "price":6},
	{"type":"eastG", "name":"แนวตะวันออก", "icon":"E×2", "desc":"โบนัสแนวตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"west5", "name":"แนวตะวันตก", "icon":"W+", "desc":"โบนัสแนวตะวันตก", "color":Color("#2f7fd6"), "price":6},
	{"type":"south5", "name":"แนวใต้", "icon":"S", "desc":"โบนัสแนวใต้", "color":Color("#d63a3a"), "price":6},
	{"type":"equalG", "name":"ยกระดับกลุ่ม", "icon":"=", "desc":"กลุ่ม Stone ต่ำสุดเท่ากลุ่มสูงสุด", "color":Color("#2f7fd6"), "price":6},
	{"type":"isoGem", "name":"โดดเดี่ยว", "icon":"M+", "desc":"โบนัสเมื่อ Gem อยู่โดดเดี่ยว", "color":Color("#2f7fd6"), "price":6},
	{"type":"chaosStack", "name":"สะสม Chaos", "icon":"+0", "desc":"ใช้ Chaos แล้ว ATK +2 ถาวร", "color":Color("#a66cf2"), "price":6, "m":0},
	{"type":"discardStack", "name":"เก็บไพ่ทิ้ง", "icon":"+0", "desc":"ชนะแล้วเพิ่มตัวคูณตามการทิ้ง", "color":Color("#d63a3a"), "price":6, "m":0},
	{"type":"chaosAtk", "name":"คลัง Chaos", "icon":"+10", "desc":"ATK +10 ต่อ Chaos ที่ถือ", "color":Color("#a66cf2"), "price":6},
	{"type":"fullSell", "name":"ขายเต็มราคา", "icon":"💰", "desc":"ขาย Artifact และ Chaos ได้เต็มราคา", "color":Color("#f08a24"), "price":6},
	{"type":"dirNHit", "name":"คูณทิศเหนือ", "icon":"↑+3", "desc":"โบนัสโจมตีทิศเหนือ", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirEHit", "name":"คูณทิศตะวันออก", "icon":"→+3", "desc":"โบนัสโจมตีทิศตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirSHit", "name":"คูณทิศใต้", "icon":"↓+3", "desc":"โบนัสโจมตีทิศใต้", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirWHit", "name":"คูณทิศตะวันตก", "icon":"←+3", "desc":"โบนัสโจมตีทิศตะวันตก", "color":Color("#2e9e5b"), "price":6},
	{"type":"artiPay", "name":"รายได้ Artifact", "icon":"🏺", "desc":"ชนะแล้วรับรายได้ตาม Artifact", "color":Color("#f08a24"), "price":6},
	{"type":"fatePay", "name":"รายได้ Gem", "icon":"🎴", "desc":"รายได้จาก Gem", "color":Color("#f08a24"), "price":6},
	{"type":"totem", "name":"โทเท็ม", "icon":"🗿", "desc":"วางโบนัสโทเท็มบนช่อง", "color":Color("#a66cf2"), "price":6},
	{"type":"orangeN", "name":"ส้มแจก Chaos", "icon":"N", "desc":"Gem ส้มให้ Chaos", "color":Color("#f08a24"), "price":6},
	{"type":"helperOdd", "name":"ผู้ช่วยเลขคี่", "icon":"คี่", "desc":"ผู้ช่วยช่องคี่", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperEven", "name":"ผู้ช่วยเลขคู่", "icon":"คู่", "desc":"ผู้ช่วยช่องคู่", "color":Color("#2f7fd6"), "price":6},
	{"type":"redS", "name":"คูณแดงใต้", "icon":"S×1", "desc":"โบนัสแดงใต้", "color":Color("#d63a3a"), "price":6},
	{"type":"stone7W", "name":"พลังตะวันตก", "icon":"W+0", "desc":"โบนัส Stone ตะวันตก", "color":Color("#a66cf2"), "price":6},
	{"type":"stone7E", "name":"คูณตะวันออก", "icon":"E+0", "desc":"โบนัส Stone ตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperC", "name":"ผู้ช่วยมุม", "icon":"🔷", "desc":"ผู้ช่วยมุม", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperR", "name":"ผู้ช่วยย้อนกลับ", "icon":"⏪", "desc":"ผู้ช่วยย้อนกลับ", "color":Color("#2e9e5b"), "price":6},
	{"type":"lshape", "name":"สูตรตัว L", "icon":"L", "desc":"สูตรตัว L", "color":Color("#2e9e5b"), "price":8},
	{"type":"moneybox", "name":"กล่องเงิน", "icon":"💰", "desc":"กล่องเงินบนกระดาน", "color":Color("#2e9e5b"), "price":8},
]

const CHAOS_CATALOG: Array[Dictionary] = [
	{"kind":"color", "col":"red", "name":"Chaos เปลี่ยนสีแดง", "icon":"🎨", "price":5, "color":Color("#d63a3a")},
	{"kind":"color", "col":"green", "name":"Chaos เปลี่ยนสีเขียว", "icon":"🎨", "price":5, "color":Color("#2e9e5b")},
	{"kind":"color", "col":"orange", "name":"Chaos เปลี่ยนสีส้ม", "icon":"🎨", "price":5, "color":Color("#f08a24")},
	{"kind":"color", "col":"blue", "name":"Chaos เปลี่ยนสีน้ำเงิน", "icon":"🎨", "price":5, "color":Color("#2f7fd6")},
	{"kind":"dirc", "dir":"N", "name":"Chaos เปลี่ยนทิศเหนือ", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"E", "name":"Chaos เปลี่ยนทิศตะวันออก", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"S", "name":"Chaos เปลี่ยนทิศใต้", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"W", "name":"Chaos เปลี่ยนทิศตะวันตก", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"tdir", "dir":"N", "name":"Chaos ทิศช่องเหนือ", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"E", "name":"Chaos ทิศช่องตะวันออก", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"S", "name":"Chaos ทิศช่องใต้", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"W", "name":"Chaos ทิศช่องตะวันตก", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"mtile", "name":"Chaos MULT +5", "icon":"⚡", "price":5, "color":Color("#a66cf2")},
	{"kind":"xmult", "name":"Chaos MULT ×1.2", "icon":"×", "price":6, "color":Color("#a66cf2")},
	{"kind":"xatk", "name":"Chaos ATK ×1.2", "icon":"✦", "price":6, "color":Color("#a66cf2")},
	{"kind":"goldify", "name":"Chaos Gem ทอง", "icon":"✨", "price":6, "color":Color("#f2b63c")},
	{"kind":"destroy", "name":"Chaos ทำลาย Gem", "icon":"💥", "price":5, "color":Color("#e0605e")},
	{"kind":"crystal", "name":"ผลึก Gem", "icon":"💎", "price":6, "color":Color("#72d8ff")},
]

var _main: Node
var shop_tab: String = "game"
var shop_offers: Array[Dictionary] = []
var reroll_cost: int = 5

func _init(main: Node = null) -> void:
	_main = main

static func has_artifact(artifacts: Array, type_key: String) -> bool:
	for it in artifacts:
		if it != null and it.get("type") == type_key:
			return true
	return false


static func is_draft_enabled(type_key: String) -> bool:
	return not DRAFT_DISABLED_ARTIFACTS.has(type_key)

func get_sell_price(artifact: Dictionary) -> int:
	return int(artifact.get("price", 6)) if _main.has_artifact("fullSell") else int(artifact.get("price", 6) / 3.0)

static func get_stone_upgrade_cost(formula_a: int) -> int:
	return 6 + (formula_a - 1) * 2

static func get_unowned_artifact_offers(artifacts: Array, count: int = 4) -> Array[Dictionary]:
	var owned_types: Array[String] = []
	for art in artifacts:
		if art != null:
			owned_types.append(art["type"])

	var pool: Array[Dictionary] = []
	for a in ARTIFACT_CATALOG:
		if is_draft_enabled(a["type"]) and not owned_types.has(a["type"]):
			pool.append(a.duplicate())

	pool.shuffle()
	var result: Array[Dictionary] = []
	var limit = mini(count, pool.size())
	for i in range(limit):
		result.append(pool[i])
	return result


# ==============================================================================
# Shop UI & Operations (Instance Methods)
# ==============================================================================

func open_shop() -> void:
	shop_tab = "game"
	reroll_cost = 5
	generate_game_offers()
	_main.shop_modal.visible = true
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins
	_update_tab_buttons()


func set_tab(tab: String) -> void:
	shop_tab = tab
	render_shop_offers()
	_update_tab_buttons()


func _update_tab_buttons() -> void:
	var tabs := {"game": _main.shop_game_tab, "artifact": _main.shop_artifact_tab, "chaos": _main.shop_chaos_tab, "upgrade": _main.shop_upgrade_tab}
	for key in tabs:
		var button: Button = tabs[key]
		var active: bool = key == shop_tab
		button.modulate = Color.WHITE if active else Color(0.72, 0.67, 0.82)
		button.disabled = false


func generate_game_offers() -> void:
	shop_offers.clear()
	for item in get_unowned_artifact_offers(_main.artifacts, 2):
		shop_offers.append({"kind": "artifact", "item": item, "sold": false})
	var upgrades: Array[Dictionary] = [
		{"kind":"stat", "stat":"hand", "title":"🃏 Hand +1", "price":6, "color":Color("#3a8f5a")},
		{"kind":"stat", "stat":"walk", "title":"❤️ Walk +1", "price":6, "color":Color("#8a5cd6")},
		{"kind":"stat", "stat":"disc", "title":"♻️ Discard +1", "price":6, "color":Color("#8a5cd6")},
	]
	upgrades.shuffle()
	shop_offers.append(upgrades[0].duplicate())
	var available_stones: Array = []
	for idx in range(_main.stone_formulas.size()):
		if _main.discovered_formulas.has(_main.stone_formulas[idx]["key"]):
			available_stones.append(idx)
	if not available_stones.is_empty():
		var stone_idx: int = int(available_stones.pick_random())
		shop_offers.append({"kind":"stone", "idx":stone_idx, "sold":false})
	var chaos_def: Dictionary = CHAOS_CATALOG[randi_range(0, CHAOS_CATALOG.size() - 1)]
	shop_offers.append({"kind":"chaos", "item":chaos_def, "sold":false})


func reroll_shop() -> void:
	if _main.coins < reroll_cost:
		return
	_main.coins -= reroll_cost
	reroll_cost += 2
	generate_game_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins
	render_shop_offers()


func _make_card_style(color: Color, hovered: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.35) if disabled else (color.lightened(0.08) if hovered else color)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color("#d3a64a")
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_right = 15
	style.corner_radius_bottom_left = 15
	if not disabled:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		style.shadow_size = 5
	return style


func _add_shop_card(category: String, title: String, detail: String, price: int, color: Color, available: bool, on_buy: Callable, tooltip: String = "", icon_texture: Texture2D = null) -> void:
	# Direct Godot equivalent of HTML .sitem: 104×122 at 1280, scaled 1.5×.
	var card := Control.new()
	card.custom_minimum_size = Vector2(156, 183)
	card.tooltip_text = tooltip
	if not available:
		card.modulate = Color(1.0, 1.0, 1.0, 0.45)

	var action := Button.new()
	action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action.tooltip_text = tooltip
	action.disabled = not available
	action.add_theme_stylebox_override("normal", _make_card_style(color, false, not available))
	action.add_theme_stylebox_override("hover", _make_card_style(color, true, false))
	action.add_theme_stylebox_override("pressed", _make_card_style(color.darkened(0.12), true, false))
	action.add_theme_stylebox_override("disabled", _make_card_style(color, false, true))
	if category == "REROLL":
		action.pressed.connect(on_buy)
	else:
		action.pressed.connect(func():
			_main.show_action_dialog("ซื้อ %s" % title, "%s\n\nราคา 🪙 %d" % [detail, price], "ซื้อ", on_buy)
		)
	card.add_child(action)

	if icon_texture != null:
		var cover := TextureRect.new()
		cover.set_anchors_preset(Control.PRESET_TOP_WIDE)
		cover.offset_top = 15.0
		cover.offset_bottom = 88.0
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.texture = icon_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(cover)

	var title_label := Label.new()
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 94.0 if icon_texture != null else 12.0
	title_label.offset_bottom = 120.0
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(title_label)

	var price_label := Label.new()
	price_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price_label.offset_left = 12.0
	price_label.offset_right = -12.0
	price_label.offset_top = -38.0
	price_label.offset_bottom = -9.0
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.text = "ซื้อแล้ว" if price == -2 else ("สูงสุด" if price < 0 else "🪙 %d" % price)
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color.WHITE)
	price_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.28))
	price_label.add_theme_constant_override("outline_size", 2)
	price_label.add_theme_stylebox_override("normal", _make_price_style())
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(price_label)
	_main.shop_offer_container.add_child(card)


func _make_price_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func render_shop_owned() -> void:
	for child in _main.shop_items_container.get_children():
		child.queue_free()

	for i in range(MAX_ARTIFACTS):
		var art = _main.artifacts[i]
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(108, 120)
		slot_btn.add_theme_stylebox_override("normal", _make_card_style(Color("#b7833d")))
		slot_btn.add_theme_stylebox_override("hover", _make_card_style(Color("#e2b45b"), true))
		slot_btn.add_theme_stylebox_override("disabled", _make_card_style(Color("#4b4058"), false, true))
		if art != null:
			# Always show data-driven text too: imported SVGs can be invisible before import finishes.
			slot_btn.icon = null
			slot_btn.text = "%s\n%s" % [art["icon"], art["name"]]
			slot_btn.add_theme_font_size_override("font_size", 15)
			slot_btn.tooltip_text = "%s\n%s\nแตะเพื่อขาย 🪙 %d" % [art["name"], art.get("desc",""), get_sell_price(art)]
			var sell_idx = i
			slot_btn.pressed.connect(func(): confirm_sell_artifact(sell_idx))
		else:
			slot_btn.text = "+"
			slot_btn.add_theme_font_size_override("font_size", 30)
			slot_btn.disabled = true
		_main.shop_items_container.add_child(slot_btn)

	# Keep the three Chaos cards visible beside the artifacts, just as they are
	# during gameplay.  The shop is also where a player can free a slot again.
	for i in range(_main.chaos.size()):
		var chaos_card = _main.chaos[i]
		var chaos_btn := Button.new()
		chaos_btn.custom_minimum_size = Vector2(108, 120)
		chaos_btn.add_theme_stylebox_override("normal", _make_card_style(Color("#4c3678")))
		chaos_btn.add_theme_stylebox_override("hover", _make_card_style(Color("#7654ad"), true))
		chaos_btn.add_theme_stylebox_override("disabled", _make_card_style(Color("#3a3448"), false, true))
		if chaos_card != null:
			var chaos_title := get_chaos_title(chaos_card)
			chaos_btn.text = "%s\n%s" % [get_chaos_icon(chaos_card), chaos_title]
			chaos_btn.add_theme_font_size_override("font_size", 14)
			chaos_btn.tooltip_text = "%s\nแตะเพื่อขาย 🪙 %d" % [chaos_title, get_chaos_sell_price(chaos_card)]
			var sell_chaos_idx: int = i
			chaos_btn.pressed.connect(func(): confirm_sell_chaos(sell_chaos_idx))
		else:
			chaos_btn.text = "CHAOS\n+"
			chaos_btn.add_theme_font_size_override("font_size", 17)
			chaos_btn.disabled = true
		_main.shop_items_container.add_child(chaos_btn)


func get_chaos_title(chaos_card: Dictionary) -> String:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") != chaos_card.get("col", ""):
			continue
		if definition.get("dir", "") != chaos_card.get("dir", ""):
			continue
		return definition["name"]
	return "Chaos"


func get_chaos_icon(chaos_card: Dictionary) -> String:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") == chaos_card.get("col", "") and definition.get("dir", "") == chaos_card.get("dir", ""):
			return definition["icon"]
	return "✦"


func get_chaos_sell_price(chaos_card: Dictionary) -> int:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") == chaos_card.get("col", "") and definition.get("dir", "") == chaos_card.get("dir", ""):
			return int(definition["price"]) if _main.has_artifact("fullSell") else maxi(1, int(definition["price"] / 3.0))
	return 1


func confirm_sell_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.artifacts.size():
		return
	var art = _main.artifacts[slot_idx]
	if art == null:
		return
	var price: int = get_sell_price(art)
	_main.show_action_dialog("ขาย %s" % art["name"], "%s\n\nรับ 🪙 %d" % [art.get("desc", ""), price], "ขาย", func(): sell_artifact(slot_idx))


func confirm_sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var title := get_chaos_title(chaos_card)
	var price: int = get_chaos_sell_price(chaos_card)
	_main.show_action_dialog("ขาย %s" % title, "คืนช่อง Chaos\n\nรับ 🪙 %d" % price, "ขาย", func(): sell_chaos(slot_idx))


func render_shop_offers() -> void:
	for child in _main.shop_offer_container.get_children():
		child.queue_free()
	if shop_tab == "game":
		_render_game_offers()
	elif shop_tab == "artifact":
		_render_artifact_catalog()
	elif shop_tab == "chaos":
		_render_chaos_catalog()
	else:
		_render_upgrade_catalog()


func _render_game_offers() -> void:
	for index in range(shop_offers.size()):
		var offer: Dictionary = shop_offers[index]
		var captured_index := index
		var sold: bool = offer.get("sold", false)
		var kind: String = offer["kind"]
		if kind == "artifact":
			var item: Dictionary = offer["item"]
			_add_shop_card("ARTIFACT", "%s %s" % [item["icon"], item["name"]], item["desc"], -2 if sold else item["price"], item["color"], not sold and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_game_offer(captured_index), item["desc"], _main.ART_TEX.get(item["type"]))
		elif kind == "chaos":
			var chaos_def: Dictionary = offer["item"]
			_add_shop_card("CHAOS", "%s %s" % [chaos_def["icon"], chaos_def["name"]], "เก็บในช่อง Chaos แล้วแตะเพื่อใช้", -2 if sold else chaos_def["price"], chaos_def["color"], not sold and _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_game_offer(captured_index), "Chaos")
		elif kind == "stone":
			var stone_idx: int = offer["idx"]
			var stone: Dictionary = _main.stone_formulas[stone_idx]
			var stone_cost := get_stone_upgrade_cost(stone["a"])
			_add_shop_card("STONE", "🪨 %s" % stone["name"], "ATK Lv%d → Lv%d" % [stone["a"], stone["a"] + 1], -2 if sold else stone_cost, Color("#b8741f"), not sold and _main.coins >= stone_cost, func(): buy_game_offer(captured_index), "เพิ่มพลังเริ่มต้น Stone")
		else:
			var price: int = offer["price"]
			_add_shop_card("UPGRADE", offer["title"], "อัปเกรดถาวร", -2 if sold else price, offer["color"], not sold and _main.coins >= price, func(): buy_game_offer(captured_index), "อัปเกรดถาวร")
	_add_shop_card("REROLL", "🎲\nสุ่มใหม่", "ข้อเสนอใหม่ · ราคาเพิ่มทุกครั้ง", reroll_cost, Color("#5a4d8f"), _main.coins >= reroll_cost, reroll_shop, "สุ่มข้อเสนอใหม่")


func _render_artifact_catalog() -> void:
	for item in ARTIFACT_CATALOG:
		var captured_item: Dictionary = item
		var owned: bool = has_artifact(_main.artifacts, item["type"])
		var enabled: bool = is_draft_enabled(item["type"])
		var note: String = item["desc"] if enabled else "%s\nยังปิดไว้ในต้นฉบับ" % item["desc"]
		_add_shop_card("ARTIFACT", "%s %s" % [item["icon"], item["name"]], note, -2 if owned else (-1 if not enabled else item["price"]), item["color"], enabled and not owned and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_artifact(captured_item), note, _main.ART_TEX.get(item["type"]))


func _render_chaos_catalog() -> void:
	for chaos_def in CHAOS_CATALOG:
		var captured_chaos: Dictionary = chaos_def
		_add_shop_card("CHAOS", "%s %s" % [chaos_def["icon"], chaos_def["name"]], "เก็บในช่อง Chaos แล้วแตะเพื่อใช้", chaos_def["price"], chaos_def["color"], _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_chaos(captured_chaos), "Chaos")


func _render_upgrade_catalog() -> void:
	var hand_maxed: bool = _main.hand_max >= HAND_CAP
	_add_shop_card("UPGRADE", "🃏 Hand +1", "การ์ดในมือ: %d" % _main.hand_max, -1 if hand_maxed else 6, Color("#3a8f5a"), not hand_maxed and _main.coins >= 6, func(): buy_stat("hand", 6), "เพิ่มจำนวนการ์ดที่จับได้")
	_add_shop_card("UPGRADE", "❤️ Walk +1", "รอบเดิน: %d" % _main.walk_max, 6, Color("#8a5cd6"), _main.coins >= 6, func(): buy_stat("walk", 6), "เพิ่มรอบเดิน และ HP สูงสุด")
	_add_shop_card("UPGRADE", "♻️ Discard +1", "ทิ้งได้: %d" % _main.discard_max, 6, Color("#8a5cd6"), _main.coins >= 6, func(): buy_stat("disc", 6), "เพิ่มจำนวนครั้งทิ้งการ์ด")
	for idx in range(_main.stone_formulas.size()):
		var stone: Dictionary = _main.stone_formulas[idx]
		if not _main.discovered_formulas.has(stone["key"]):
			continue
		var cost := get_stone_upgrade_cost(stone["a"])
		var captured_idx := idx
		var captured_cost := cost
		_add_shop_card("STONE", "🪨 %s" % stone["name"], "ATK Lv%d → Lv%d" % [stone["a"], stone["a"] + 1], cost, Color("#b8741f"), _main.coins >= cost, func(): buy_stone_upgrade(captured_idx, captured_cost), "เพิ่มพลังเริ่มต้น Stone")


func buy_game_offer(index: int) -> void:
	if index < 0 or index >= shop_offers.size() or shop_offers[index].get("sold", false):
		return
	var offer: Dictionary = shop_offers[index]
	var before: int = _main.coins
	if offer["kind"] == "artifact":
		buy_artifact(offer["item"])
	elif offer["kind"] == "chaos":
		buy_chaos(offer["item"])
	elif offer["kind"] == "stone":
		var stone: Dictionary = _main.stone_formulas[offer["idx"]]
		buy_stone_upgrade(offer["idx"], get_stone_upgrade_cost(stone["a"]))
	else:
		buy_stat(offer["stat"], offer["price"])
	if _main.coins < before:
		shop_offers[index]["sold"] = true
		render_shop_offers()


func buy_stat(stat_type: String, price: int) -> void:
	if _main.coins < price: return
	_main.coins -= price
	if stat_type == "hand":
		_main.hand_max = mini(HAND_CAP, _main.hand_max + 1)
	elif stat_type == "walk":
		_main.walk_max += 1
		_main.walks_left = _main.walk_max
		_main.player_max_hp = _main.enemy_atk * _main.walk_max
		_main.player_hp = _main.player_max_hp
	elif stat_type == "disc":
		_main.discard_max += 1
		_main.discards_left += 1

	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins


func buy_stone_upgrade(formula_idx: int, cost: int) -> void:
	if _main.coins < cost: return
	_main.coins -= cost
	_main.stone_formulas[formula_idx]["a"] += 1
	if _main.has_artifact("stoneUp"):
		_main.stone_up_multiplier = snappedf(_main.stone_up_multiplier + 0.2, 0.1)
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins


func buy_artifact(item: Dictionary) -> void:
	var slot: int = _main.artifacts.find(null)
	if slot == -1 or _main.coins < item["price"]: return
	_main.coins -= item["price"]
	_main.artifacts[slot] = item.duplicate()
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins
	_main.render_artifact_row()


func buy_chaos(definition: Dictionary) -> void:
	var slot: int = _main.chaos.find(null)
	if slot == -1 or _main.coins < definition["price"]:
		return
	_main.coins -= definition["price"]
	var chaos_card: Dictionary = {"kind": definition["kind"]}
	if definition.has("col"):
		chaos_card["col"] = definition["col"]
	if definition.has("dir"):
		chaos_card["dir"] = definition["dir"]
	_main.chaos[slot] = chaos_card
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins


func sell_artifact(slot_idx: int) -> void:
	var art = _main.artifacts[slot_idx]
	if art == null: return
	var sell_price = get_sell_price(art)
	_main.coins += sell_price
	_main.artifacts[slot_idx] = null
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins
	_main.render_artifact_row()


func sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	_main.coins += get_chaos_sell_price(chaos_card)
	_main.chaos[slot_idx] = null
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %d" % _main.coins


func on_shop_leave() -> void:
	_main.shop_modal.visible = false
	_main.stage += 1
	_main.enemy_pic.modulate = Color.WHITE
	_main.enemy_pic.scale = Vector2.ONE

	# Enemy scaling per draft
	_main.enemy_max_hp = int(_main.enemy_max_hp * 1.5)
	_main.enemy_hp = _main.enemy_max_hp
	_main.enemy_atk = int(_main.enemy_atk * _main.PHP_GROW)

	_main.walks_left = _main.walk_max
	_main.player_max_hp = _main.enemy_atk * _main.walk_max
	_main.player_hp = _main.player_max_hp

	# Wild Shuffle permits discarding after placement, in exchange for one use.
	_main.discards_left = maxi(0, _main.discard_max - (1 if _main.has_artifact("freediscard") else 0))

	_main.build_deck()
	_main.spawn_current_enemy()


func on_artifact_slot_pressed(slot_idx: int) -> void:
	var art = _main.artifacts[slot_idx]
	if art == null: return
	_main.toast_label.text = "%s %s\n%s" % [art["icon"], art["name"], art["desc"]]
	_main.toast.visible = true
	_main.toast.modulate.a = 0.0
	var orig_y = 70.0
	_main.toast.position.y = orig_y - 25.0
	var tween = _main.create_tween()
	tween.tween_property(_main.toast, "position:y", orig_y, 0.28 / _main.speed_multiplier).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_main.toast, "modulate:a", 1.0, 0.25 / _main.speed_multiplier)
	tween.tween_interval(2.5 / _main.speed_multiplier)
	tween.tween_property(_main.toast, "position:y", orig_y - 20.0, 0.25 / _main.speed_multiplier)
	tween.parallel().tween_property(_main.toast, "modulate:a", 0.0, 0.25 / _main.speed_multiplier)
	tween.tween_callback(func(): _main.toast.visible = false)
