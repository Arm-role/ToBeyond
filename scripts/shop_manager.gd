class_name ShopManager
extends RefCounted

const MAX_ARTIFACTS: int = 5
const HAND_CAP: int = 12
const HAND_PRICE: int = 10
const STAT_PRICE: int = 10
const STONE_UPGRADE_PRICE: int = 3
const REROLL_START: int = 5
const REROLL_STEP: int = 2
const OFFER_ARTIFACTS: int = 2
const OFFER_MISC: int = 5
# These entries are deliberately disabled in the HTML draft itself: its
# one-row board cannot support the required route/board mechanics yet.
## Artifact and Chaos definitions live in res://data (ArtifactData / ChaosData,
## loaded by ArtifactSystem). These views keep the Dictionary shapes the shop
## and UI code use.
static var ARTIFACT_CATALOG: Array[Dictionary] = _build_catalog()
static var ARTIFACT_RARITY: Dictionary = _build_rarity()
static var CHAOS_CATALOG: Array[Dictionary] = _build_chaos()


static func _build_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in ArtifactSystem.all():
		out.append(d.make_instance())
	return out


static func _build_rarity() -> Dictionary:
	var out := {}
	for d in ArtifactSystem.all():
		if d.rarity != "":
			out[d.id] = d.rarity
	return out


static func _build_chaos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ArtifactSystem.chaos_all():
		out.append(c.make_offer())
	return out


const DIR_TH: Dictionary = {"N": "เหนือ", "E": "ตะวันออก", "S": "ใต้", "W": "ตะวันตก"}


static func display_name(item: Dictionary) -> String:
	var t: String = item.get("type", "")
	var d := ArtifactSystem.get_def(t)
	if d != null and d.draft_name != "":
		return d.draft_name
	return item.get("name", t)


## Main node, so descriptions can show live values like the draft's "ตอนนี้ ×1.3".
static var live_main: Node = null


static func _r2(v: float) -> String:
	var r := snappedf(v, 0.01)
	return str(int(r)) if is_equal_approx(r, floorf(r)) else String.num(r, 2)


static func display_desc(item: Dictionary) -> String:
	var t: String = item.get("type", "")
	var m: Variant = item.get("m", null)
	var mv: float = float(m) if m != null else 0.0
	var dc := func(d: String) -> int:
		return live_main.tile_direction_count(d) if live_main != null else 0
	match t:
		"chaosStack":
			return "ทุกครั้งที่ใช้การ์ด Chaos: ATK ของการ์ดนี้ +2 ถาวร · ตอนโจมตี ATK +%s" % _r2(mv)
		"discardStack":
			return "ตอนชนะศัตรู: ตัวคูณของการ์ดนี้ + จำนวนครั้งที่ทิ้งได้ที่เหลือ ถาวร · ตอนโจมตี ตัวคูณ +%s" % _r2(mv)
		"stoneUp":
			return "ทุกครั้งที่อัปเกรด stone (ซื้อในร้าน): ตัวสะสมของการ์ดนี้ +0.2 ถาวร · ตอนโจมตี ตัวคูณ × %s" % _r2(mv if m != null else 1.0)
		"redS":
			return "ตอนเดิน ถ้ามีสูตรที่การ์ดสีแดงทิศ S วางบนช่องทิศ S ครบทั้ง 2 ช่อง: ตัวสะสมของการ์ดนี้ +0.5 ถาวร · ตอนโจมตี ตัวคูณ × %s" % _r2(mv if m != null else 1.0)
		"stone7W":
			return "ตอนเดิน ทุก Gem สีน้ำเงินทิศตะวันตกที่วางบนช่องทิศตะวันตก (นับทีละใบ): ATK ของการ์ดนี้ +3 ต่อใบ ถาวร · ตอนโจมตี ATK +%s" % _r2(mv)
		"stone7E":
			return "ตอนเดิน ทุก Gem สีเขียวทิศตะวันออกที่วางบนช่องทิศตะวันออก (นับทีละใบ): ตัวคูณของการ์ดนี้ +1 ต่อใบ ถาวร · ตอนโจมตี ตัวคูณ +%s" % _r2(mv)
		"eastG":
			var n: int = dc.call("E")
			var f: float = 2.0 if n >= 8 else 1.0 + 0.1 * n
			return "ทุกครั้งที่เดินตกช่องที่วาง Gem ทิศตะวันออก (สีไหนก็ได้ ช่องไหนก็ได้): ตัวคูณ × (1 + 0.1 ต่อช่องทิศ E บนกระดาน) · ตอนนี้ ×%s · ทั้งกระดานเป็นทิศ E (8 ช่อง) ได้โบนัสเป็น ×2" % _r2(f)
		"north5":
			var n2: int = dc.call("N")
			var e: float = 2.0 if n2 >= 8 else 1.0 + 0.12 * n2
			return "ตอนโจมตี: ตัวคูณยกกำลัง (1 + 0.12 ต่อช่องทิศ N บนกระดาน) · ตอนนี้ ^%s · ทั้งกระดานเป็นทิศ N (8 ช่อง) ได้โบนัสเป็นยกกำลัง 2 พอดี" % _r2(e)
	var def := ArtifactSystem.get_def(t)
	if def != null and def.draft_desc != "":
		return def.draft_desc
	return item.get("desc", "")


const COL_TH: Dictionary = {"red": "แดง", "green": "เขียว", "orange": "ส้ม", "blue": "น้ำเงิน"}


## Chaos texts from the draft (label / title / desc live in data/chaos/*.tres).
static func chaos_label(c: Dictionary) -> String:
	var d := ArtifactSystem.chaos_def(c)
	return d.label if d != null else ""


static func chaos_name(c: Dictionary) -> String:
	var d := ArtifactSystem.chaos_def(c)
	return d.title if d != null else "Chaos"


static func chaos_desc(c: Dictionary) -> String:
	var d := ArtifactSystem.chaos_def(c)
	return d.desc if d != null else ""


## Cover art like the draft's itemCover(): SVG art, else the direction emblem.
func art_cover(item: Dictionary) -> Texture2D:
	var d := ArtifactSystem.get_def(item.get("type", ""))
	if d == null:
		return null
	if d.texture != null:
		return d.texture
	return GameAssets.EMBLEMS.get(d.emblem_dir) if d.emblem_dir != "" else null


var _main: Node
var shop_tab: String = "game"
var shop_offers: Array[Dictionary] = []
var shop_bought: Array[String] = []
var reroll_cost: int = REROLL_START

func _init(main: Node = null) -> void:
	_main = main
	if main != null:
		live_main = main

static func has_artifact(artifacts: Array, type_key: String) -> bool:
	for it in artifacts:
		if it != null and it.get("type") == type_key:
			return true
	return false


static func is_draft_enabled(type_key: String) -> bool:
	var d := ArtifactSystem.get_def(type_key)
	return d != null and d.in_draft_pool

func get_sell_price(artifact: Dictionary) -> int:
	return int(artifact.get("price", 6)) if _main.artifact_sys.has_rule(&"full_sell") else int(artifact.get("price", 6) / 3.0)

static func get_stone_upgrade_cost() -> int:
	return STONE_UPGRADE_PRICE

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
	reroll_cost = REROLL_START
	shop_bought.clear()
	generate_game_offers()
	_main.shop_modal.visible = true
	# Slide up from the bottom edge; stop at the preview/gameplay divider.
	var shop_top: float = _main.get_node("Preview").offset_bottom
	_main.shop_modal.offset_top = _main.size.y
	var slide: Tween = _main.shop_modal.create_tween()
	slide.tween_property(_main.shop_modal, "offset_top", shop_top, 0.35 / _main.speed_multiplier) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Draft `.shopscroll`: dashed, rounded frame around the offers.
	var frame := DashedStyleBox.new()
	frame.border_color = Color(0.827451, 0.65098, 0.290196, 0.35)
	frame.corner_radius = 21.0
	frame.set_content_margin_all(12.0)
	_main.shop_offer_frame.add_theme_stylebox_override("panel", frame)
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_update_tab_buttons()


func set_tab(tab: String) -> void:
	shop_tab = tab
	render_shop_offers()
	_update_tab_buttons()


## Draft `.shoptabs`: active tab is solid brass; TEST tabs have dashed borders.
func _update_tab_buttons() -> void:
	var tabs := {"game": _main.shop_game_tab, "artifact": _main.shop_artifact_tab, "chaos": _main.shop_chaos_tab, "upgrade": _main.shop_upgrade_tab}
	for key in tabs:
		var button: Button = tabs[key]
		var active: bool = key == shop_tab
		var sb: StyleBox
		if active:
			var flat := StyleBoxFlat.new()
			flat.bg_color = GameAssets.COLORS["brass"]
			flat.border_color = GameAssets.COLORS["brass"]
			flat.set_border_width_all(3)
			flat.set_corner_radius_all(18)
			sb = flat
		elif key == "game":
			var outline := StyleBoxFlat.new()
			outline.bg_color = Color(0, 0, 0, 0)
			outline.border_color = GameAssets.COLORS["brass"]
			outline.set_border_width_all(3)
			outline.set_corner_radius_all(18)
			sb = outline
		else:
			var dashed := DashedStyleBox.new()
			dashed.border_color = GameAssets.COLORS["brass"]
			dashed.corner_radius = 18.0
			sb = dashed
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(st, sb)
		var font_col: Color = Color("#2a2140") if active else GameAssets.COLORS["brass_bright"]
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(c, font_col)
		button.modulate = Color(1, 1, 1, 0.85) if (key != "game" and not active) else Color.WHITE
		button.disabled = false


func generate_game_offers() -> void:
	shop_offers.clear()
	var used: Dictionary = {}
	var owned_types: Array[String] = []
	for artifact in _main.artifacts:
		if artifact != null:
			owned_types.append(artifact["type"])

	for _offer_index in range(OFFER_ARTIFACTS):
		for _attempt in range(60):
			var rarity_roll := randf()
			var rarity := "common" if rarity_roll < 0.70 else ("uncommon" if rarity_roll < 0.95 else "rare")
			var candidates: Array[Dictionary] = []
			for artifact in ARTIFACT_CATALOG:
				var artifact_type: String = artifact["type"]
				var offer_key := "artifact:%s" % artifact_type
				if (is_draft_enabled(artifact_type) and not owned_types.has(artifact_type)
					and ARTIFACT_RARITY.get(artifact_type, "") == rarity and not used.has(offer_key)):
					candidates.append(artifact)
			if candidates.is_empty():
				continue
			var item: Dictionary = candidates[randi_range(0, candidates.size() - 1)].duplicate()
			used["artifact:%s" % item["type"]] = true
			shop_offers.append({"kind": "artifact", "item": item, "sold": false})
			break

	for _offer_index in range(OFFER_MISC):
		for _attempt in range(60):
			var roll := randf()
			if roll < 0.35:
				var stone_indices: Array[int] = []
				for idx in range(_main.stone_formulas.size()):
					var offer_key := "stone:%d" % idx
					if (_main.discovered_formulas.has(_main.stone_formulas[idx]["key"])
						and not shop_bought.has("stone:%d" % idx) and not used.has(offer_key)):
						stone_indices.append(idx)
				if stone_indices.is_empty():
					continue
				var stone_idx: int = stone_indices[randi_range(0, stone_indices.size() - 1)]
				used["stone:%d" % stone_idx] = true
				shop_offers.append({"kind": "stone", "idx": stone_idx, "sold": false})
				break
			elif roll < 0.75:
				var chaos_indices: Array[int] = []
				for idx in range(CHAOS_CATALOG.size()):
					if not used.has("chaos:%d" % idx):
						chaos_indices.append(idx)
				if chaos_indices.is_empty():
					continue
				var chaos_idx: int = chaos_indices[randi_range(0, chaos_indices.size() - 1)]
				used["chaos:%d" % chaos_idx] = true
				shop_offers.append({"kind": "chaos", "item": CHAOS_CATALOG[chaos_idx], "sold": false})
				break
			else:
				var upgrade_keys: Array[String] = []
				var stat_types: Array[String] = ["hand", "walk", "disc"]
				for key in stat_types:
					if shop_bought.has(key) or used.has("upgrade:%s" % key):
						continue
					if key == "hand" and _main.hand_max >= HAND_CAP:
						continue
					upgrade_keys.append(key)
				if upgrade_keys.is_empty():
					continue
				var stat: String = upgrade_keys[randi_range(0, upgrade_keys.size() - 1)]
				used["upgrade:%s" % stat] = true
				shop_offers.append({"kind": "stat", "stat": stat, "sold": false})
				break


func reroll_shop() -> void:
	if _main.coins < reroll_cost:
		return
	_main.coins -= reroll_cost
	_main.sfx.play("coin")
	reroll_cost += REROLL_STEP
	generate_game_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.update_all_ui()
	render_shop_offers()


# ------------------------------------------------------------------------------
# Shop cards — Godot version of the draft's `.sitem` (104×122, rows 104×106),
# scaled 1.5× for the 1920×1080 canvas.
# ------------------------------------------------------------------------------

var _offer_target: Container = null
var _card_height: float = UiRenderer.CARD_SIZE.y


func _card_box(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_price_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _card_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"BoldLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -4)
	return l


## Builds one shop card.  `opts`: cover (Texture2D), big (String, shown large
## when there is no cover), rarity ("uncommon"/"rare"), stone (Dictionary with
## name/up/lv), text_color, sold (bool), on_click (Callable).
func _add_shop_card(category: String, title: String, detail: String, price: int, color: Color, available: bool, on_buy: Callable, tooltip: String = "", icon_texture: Texture2D = null, opts: Dictionary = {}) -> void:
	var card := Control.new()
	var card_width := UiRenderer.CARD_SIZE.x
	card.custom_minimum_size = Vector2(card_width, _card_height)
	card.tooltip_text = tooltip
	var sold: bool = price == -2
	if sold:
		card.modulate.a = 0.35
	elif not available:
		card.modulate.a = 0.45
	var text_color: Color = opts.get("text_color", Color.WHITE)

	var action := Button.new()
	action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action.tooltip_text = tooltip
	action.disabled = sold
	var box := _card_box(color)
	var hover := _card_box(color.lightened(0.08))
	action.add_theme_stylebox_override("normal", box)
	action.add_theme_stylebox_override("hover", hover)
	action.add_theme_stylebox_override("pressed", hover)
	action.add_theme_stylebox_override("disabled", box)
	action.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if opts.has("on_click"):
		action.pressed.connect(opts["on_click"])
	elif category == "REROLL":
		action.pressed.connect(on_buy)
	else:
		var label := "ซื้อ 🪙 %d" % price
		var blocked := not available
		if blocked:
			if price >= 0 and _main.coins < price:
				label = "เหรียญไม่พอ"
			elif category == "ARTIFACT" and not _main.artifacts.has(null):
				label = "ช่อง Artifact เต็ม"
			elif category == "CHAOS" and not _main.chaos.has(null):
				label = "ช่อง Chaos เต็ม"
			elif price == -1:
				label = "ปิดไว้ก่อน"
		var rar: String = opts.get("rarity", "") if category == "ARTIFACT" else ""
		action.pressed.connect(func():
			_main.show_action_dialog(title, detail, label, on_buy, blocked, rar)
		)
	card.add_child(action)
	if not sold and category != "":
		# SlotDrag: drag this card out of the shop to buy it (opens the same dialog).
		card.add_to_group(&"shop_card")
		card.set_meta("drag_action", action)
		card.set_meta("drag_kind", "artifact" if category == "ARTIFACT" else ("chaos" if category == "CHAOS" else "other"))

	var price_text: String = opts.get("price_text", "ซื้อแล้ว" if sold else ("สูงสุด" if price < 0 else "🪙 %d" % price))
	if opts.get("closed", false):
		card.modulate = Color(0.75, 0.72, 0.8, 0.4)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6.0
	vb.offset_right = -6.0
	vb.offset_top = 6.0
	vb.offset_bottom = -6.0
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	if opts.has("stone"):
		var st: Dictionary = opts["stone"]
		vb.add_child(_card_label(st["name"], 14, text_color))
		var spv := HBoxContainer.new()
		spv.alignment = BoxContainer.ALIGNMENT_CENTER
		spv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spv.add_theme_constant_override("separation", 3)
		for c in st.get("pv", []):
			spv.add_child(_main.ui_renderer.make_mini_card(c[0], c[1], Vector2(22, 30)))
		vb.add_child(spv)
		vb.add_child(_card_label("+%d" % st["up"], 26, text_color))
		vb.add_child(_card_label("Lv%d → %d" % [st["lv"], st["lv"] + 1], 13, Color(1, 1, 1, 0.8)))
	elif opts.has("cover_text"):
		var ct := _card_label(opts["cover_text"], 28, Color("#fff6d6"))
		ct.custom_minimum_size = Vector2(0, 60)
		vb.add_child(ct)
		vb.add_child(_card_label(title, 17, text_color))
	elif icon_texture != null:
		var cover := TextureRect.new()
		cover.custom_minimum_size = Vector2(0, 60)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.texture = icon_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(cover)
		if category == "ARTIFACT":
			# Same look as the owned slot: cover only (details via tap / tooltip).
			cover.custom_minimum_size = Vector2(0, 90)
			cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			vb.add_child(_card_label(opts.get("label_text", title), opts.get("label_size", 17), text_color))
	else:
		var big: String = opts.get("big", title)
		var n := big.length()
		var big_size := 28 if big.contains("\n") else (28 if n <= 4 else (22 if n <= 7 else 18))
		var big_label := _card_label(big, big_size, text_color)
		big_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(big_label)

	var price_label := _card_label(price_text, 19)
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	price_label.add_theme_stylebox_override("normal", _make_price_style())
	vb.add_child(price_label)

	var rarity: String = opts.get("rarity", "")
	if rarity == "uncommon" or rarity == "rare":
		var tag := Label.new()
		tag.text = "R" if rarity == "rare" else "U"
		tag.theme_type_variation = &"BoldLabel"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color("#ffcf5a") if rarity == "rare" else Color("#6df0a8"))
		var tag_sb := StyleBoxFlat.new()
		tag_sb.bg_color = Color("#4a3a10") if rarity == "rare" else Color("#1e4a37")
		tag_sb.set_corner_radius_all(9)
		tag_sb.content_margin_left = 7.0
		tag_sb.content_margin_right = 7.0
		tag.add_theme_stylebox_override("normal", tag_sb)
		tag.position = Vector2(card_width - 34, 6)
		card.add_child(tag)

	_main.ui_renderer.set_card_template(card)
	(_offer_target if _offer_target != null else _main.shop_offer_container).add_child(card)


func _chaos_card_look(chaos_def: Dictionary) -> Dictionary:
	var d := ArtifactSystem.chaos_def(chaos_def)
	if d == null:
		return {"bg": Color("#a66cf2"), "text": Color.WHITE, "cover": null}
	return {"bg": d.card_bg, "text": d.text_color, "cover": d.cover()}


func _add_chaos_card(chaos_def: Dictionary, price: int, available: bool, on_buy: Callable) -> void:
	var look := _chaos_card_look(chaos_def)
	var title: String = chaos_name(chaos_def)
	var cdef := ArtifactSystem.chaos_def(chaos_def)
	# Owned-slot look: slot colour, prefix + short label, same text size.
	var extra := {"text_color": look["text"], "label_text": cdef.slot_prefix + chaos_label(chaos_def), "label_size": 19}
	if look["cover"] == null:
		extra["cover_text"] = cdef.cover_text
	_add_shop_card("CHAOS", title, chaos_desc(chaos_def), price, cdef.slot_bg, available, on_buy, title, look["cover"], extra)


func _add_offer_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = label_text
	lab.theme_type_variation = &"BoldLabel"
	lab.custom_minimum_size = Vector2(126, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", GameAssets.COLORS["brass_bright"])
	lab.add_theme_constant_override("line_spacing", -2)
	row.add_child(lab)
	_main.shop_offer_container.add_child(row)
	return row


func get_chaos_sell_price(chaos_card: Dictionary) -> int:
	var d := ArtifactSystem.chaos_def(chaos_card)
	if d != null and _main.artifact_sys.has_rule(&"full_sell"):
		return d.price
	return 1


func confirm_sell_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.artifacts.size():
		return
	var art = _main.artifacts[slot_idx]
	if art == null:
		return
	var price: int = get_sell_price(art)
	var can_sell: bool = not _main.is_busy or _main.shop_modal.visible
	_main.show_action_dialog(display_name(art), display_desc(art), "ขาย 🪙 %d" % price, func(): sell_artifact(slot_idx), not can_sell, ARTIFACT_RARITY.get(art.get("type", ""), ""))


func confirm_sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var price: int = get_chaos_sell_price(chaos_card)
	_main.show_action_dialog(chaos_name(chaos_card), chaos_desc(chaos_card), "ขาย 🪙 %d" % price, func(): sell_chaos(slot_idx))


func render_shop_offers() -> void:
	for child in _main.shop_offer_container.get_children():
		child.queue_free()
	_offer_target = null
	if shop_tab == "game":
		_card_height = UiRenderer.CARD_SIZE.y
		_render_game_offers()
	else:
		_card_height = UiRenderer.CARD_SIZE.y
		if shop_tab == "artifact":
			_render_artifact_catalog()
		elif shop_tab == "chaos":
			_render_chaos_catalog()
		else:
			_render_upgrade_catalog()
	_offer_target = null


## Draft `.shsec` section title + a wrapping row of cards below it.
func _add_section(title: String) -> void:
	var first := true
	for child in _main.shop_offer_container.get_children():
		if not child.is_queued_for_deletion():
			first = false
			break
	var lab := Label.new()
	lab.text = title
	lab.theme_type_variation = &"BoldLabel"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", GameAssets.COLORS["brass_bright"])
	if not first:
		var line := StyleBoxFlat.new()
		line.bg_color = Color(0, 0, 0, 0)
		line.border_width_top = 2
		line.border_color = Color(0.827451, 0.65098, 0.290196, 0.3)
		line.content_margin_top = 12.0
		lab.add_theme_stylebox_override("normal", line)
	_main.shop_offer_container.add_child(lab)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 15)
	flow.add_theme_constant_override("v_separation", 15)
	_main.shop_offer_container.add_child(flow)
	_offer_target = flow


func _render_game_offers() -> void:
	# Row 1: artifacts + reroll card · Row 2: Chaos / Stone / upgrades (draft genOffers).
	_offer_target = _add_offer_row("ARTIFACT")
	for index in range(shop_offers.size()):
		if shop_offers[index]["kind"] == "artifact":
			_render_offer(index)
	_add_shop_card("REROLL", "🎲\nสุ่มใหม่", "", reroll_cost, Color("#473b78"), _main.coins >= reroll_cost, reroll_shop, "สุ่มสินค้าใหม่", null, {"big": "🎲\nสุ่มใหม่"})
	_offer_target = _add_offer_row("CHAOS\nSTONE\nอัปเกรด")
	for index in range(shop_offers.size()):
		if shop_offers[index]["kind"] != "artifact":
			_render_offer(index)


func _render_offer(index: int) -> void:
	var offer: Dictionary = shop_offers[index]
	var captured_index := index
	var sold: bool = offer.get("sold", false)
	var kind: String = offer["kind"]
	if kind == "artifact":
		var item: Dictionary = offer["item"]
		_add_shop_card("ARTIFACT", display_name(item), display_desc(item), -2 if sold else item["price"], item["color"], not sold and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_game_offer(captured_index), display_desc(item), art_cover(item), {"rarity": ARTIFACT_RARITY.get(item["type"], "")})
	elif kind == "chaos":
		var chaos_def: Dictionary = offer["item"]
		_add_chaos_card(chaos_def, -2 if sold else chaos_def["price"], not sold and _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_game_offer(captured_index))
	elif kind == "stone":
		var stone_idx: int = offer["idx"]
		var stone: Dictionary = _main.stone_formulas[stone_idx]
		var stone_cost := get_stone_upgrade_cost()
		var stone_bonus: int = int(stone["bonus"])
		var stone_level: int = int(stone.get("lv", 1))
		var stone_key := "stone:%d" % stone_idx
		var is_sold: bool = sold or shop_bought.has(stone_key)
		_add_shop_card("STONE", "Stone %s Lv%d → %d" % [stone["name"], stone_level, stone_level + 1], "%s\nค่าเริ่ม ATK %d → %d" % [stone.get("desc", ""), stone["a"], stone["a"] + stone_bonus], -2 if is_sold else stone_cost, Color("#b8741f"), not is_sold and _main.coins >= stone_cost, func(): buy_game_offer(captured_index), "เพิ่มพลังเริ่มต้น Stone", null, {"stone": {"name": stone["name"], "up": stone_bonus, "lv": stone_level, "pv": stone.get("pv", [])}})
	elif kind == "stat":
		var stat: String = offer["stat"]
		var stat_info := _get_stat_offer_info(stat)
		var stat_price: int = HAND_PRICE if stat == "hand" else STAT_PRICE
		var unavailable: bool = shop_bought.has(stat) or (stat == "hand" and _main.hand_max >= HAND_CAP)
		_add_shop_card("UPGRADE", stat_info["title"], stat_info["detail"], -2 if sold or unavailable else stat_price, stat_info["color"], not sold and not unavailable and _main.coins >= stat_price, func(): buy_game_offer(captured_index), stat_info["detail"], null, {"big": stat_info["big"]})


func _get_stat_offer_info(stat_type: String) -> Dictionary:
	match stat_type:
		"hand":
			return {"title": "Hand +1", "big": "Hand\n+1", "detail": "ถือ Gem ในมือได้เพิ่ม 1 ใบ (%d/%d)" % [_main.hand_max, HAND_CAP], "color": Color("#3a8f5a")}
		"walk":
			var pct := roundi(100.0 / float(_main.walk_max))
			return {"title": "HP เพิ่ม", "big": "HP\n+%d%%" % pct, "detail": "เลือดสูงสุดเพิ่ม (รับการโจมตีได้อีก 1 ครั้ง)", "color": Color("#8a5cd6")}
		"disc":
			return {"title": "ทิ้ง +1", "big": "ทิ้ง\n+1", "detail": "ทิ้ง Gem ได้เพิ่ม 1 ครั้งต่อศัตรู", "color": Color("#8a5cd6")}
	return {}


func _render_artifact_catalog() -> void:
	for rarity in ["common", "uncommon", "rare"]:
		_add_section(rarity.to_upper())
		for item in ARTIFACT_CATALOG:
			if not is_draft_enabled(item["type"]) or ARTIFACT_RARITY.get(item["type"], "") != rarity:
				continue
			var captured_item: Dictionary = item
			var owned: bool = has_artifact(_main.artifacts, item["type"])
			_add_shop_card("ARTIFACT", display_name(item), display_desc(item), -2 if owned else item["price"], item["color"], not owned and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_artifact(captured_item), display_desc(item), art_cover(item), {"rarity": rarity})
	_add_section("ปิดไว้ก่อน (เสี่ยง bug จากการเปลี่ยนระบบเกม) · แตะดูเหตุผล")
	for item in ARTIFACT_CATALOG:
		if is_draft_enabled(item["type"]):
			continue
		_add_shop_card("ARTIFACT", display_name(item), display_desc(item) + "\n\nปิดไว้ก่อน: ระบบที่ใช้ยังไม่รองรับกระดานแถวเดียว", -1, item["color"], false, func(): pass, display_desc(item), null, {"price_text": "ปิดไว้ก่อน", "closed": true})


func _render_chaos_catalog() -> void:
	_add_section("CHAOS · แตะดูรายละเอียด / ซื้อ")
	for chaos_def in CHAOS_CATALOG:
		var captured_chaos: Dictionary = chaos_def
		_add_chaos_card(chaos_def, chaos_def["price"], _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_chaos(captured_chaos))


func _render_upgrade_catalog() -> void:
	var hand_maxed: bool = _main.hand_max >= HAND_CAP
	_add_section("อัปเกรดพื้นฐาน")
	for stat in ["hand", "walk", "disc"]:
		var info := _get_stat_offer_info(stat)
		var price: int = HAND_PRICE if stat == "hand" else STAT_PRICE
		var captured_stat: String = stat
		var unavailable: bool = shop_bought.has(stat) or (stat == "hand" and hand_maxed)
		_add_shop_card("UPGRADE", info["title"], info["detail"], -2 if shop_bought.has(stat) else (-1 if unavailable else price), info["color"], not unavailable and _main.coins >= price, func(): buy_stat(captured_stat, price), info["detail"], null, {"big": info["big"]})
	_add_section("STONE")
	for idx in range(_main.stone_formulas.size()):
		var stone: Dictionary = _main.stone_formulas[idx]
		if not _main.discovered_formulas.has(stone["key"]):
			continue
		var cost := get_stone_upgrade_cost()
		var key := "stone:%d" % idx
		var bonus: int = int(stone["bonus"])
		var level: int = int(stone.get("lv", 1))
		var captured_idx := idx
		var captured_cost := cost
		_add_shop_card("STONE", "Stone %s Lv%d → %d" % [stone["name"], level, level + 1], "%s\nค่าเริ่ม ATK %d → %d" % [stone.get("desc", ""), stone["a"], stone["a"] + bonus], -2 if shop_bought.has(key) else cost, Color("#b8741f"), not shop_bought.has(key) and _main.coins >= cost, func(): buy_stone_upgrade(captured_idx, captured_cost), "เพิ่มพลังเริ่มต้น Stone", null, {"stone": {"name": stone["name"], "up": bonus, "lv": level, "pv": stone.get("pv", [])}})


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
		buy_stone_upgrade(offer["idx"], get_stone_upgrade_cost())
	elif offer["kind"] == "stat":
		var stat_type: String = offer["stat"]
		buy_stat(stat_type, HAND_PRICE if stat_type == "hand" else STAT_PRICE)
	if _main.coins < before:
		shop_offers[index]["sold"] = true
		render_shop_offers()


func buy_stat(stat_type: String, price: int) -> void:
	if not ["hand", "walk", "disc"].has(stat_type) or shop_bought.has(stat_type):
		return
	if (stat_type == "hand" and _main.hand_max >= HAND_CAP) or _main.coins < price:
		return
	_main.coins -= price
	_main.sfx.play("coin")
	if stat_type == "hand":
		_main.hand_max += 1
	elif stat_type == "walk":
		_main.walk_max += 1
		_main.walks_left = _main.walk_max
		_main.player_max_hp = _main.enemy_atk * _main.walk_max
		_main.player_hp = _main.player_max_hp
	elif stat_type == "disc":
		_main.discard_max += 1
	shop_bought.append(stat_type)

	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func buy_stone_upgrade(formula_idx: int, cost: int) -> void:
	if formula_idx < 0 or formula_idx >= _main.stone_formulas.size():
		return
	var key := "stone:%d" % formula_idx
	if shop_bought.has(key) or cost != STONE_UPGRADE_PRICE or _main.coins < cost:
		return
	_main.coins -= cost
	_main.sfx.play("coin")
	_main.stone_formulas[formula_idx]["a"] += int(_main.stone_formulas[formula_idx]["bonus"])
	_main.stone_formulas[formula_idx]["lv"] = int(_main.stone_formulas[formula_idx].get("lv", 1)) + 1
	shop_bought.append(key)
	_main.artifact_sys.stone_upgrade()
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func buy_artifact(item: Dictionary) -> void:
	var slot: int = _main.artifacts.find(null)
	if slot == -1 or _main.coins < item["price"]: return
	_main.coins -= item["price"]
	_main.sfx.play("coin")
	_main.artifacts[slot] = item.duplicate()
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.render_artifact_row()


func buy_chaos(definition: Dictionary) -> void:
	var slot: int = _main.chaos.find(null)
	if slot == -1 or _main.coins < definition["price"]:
		return
	_main.coins -= definition["price"]
	_main.sfx.play("coin")
	_main.chaos[slot] = ArtifactSystem.chaos_def(definition).make_card()
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func sell_artifact(slot_idx: int) -> void:
	var art = _main.artifacts[slot_idx]
	if art == null: return
	var sell_price = get_sell_price(art)
	_main.coins += sell_price
	_main.sfx.play("coin")
	_main.artifacts[slot_idx] = null
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.render_artifact_row()


func sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	_main.coins += get_chaos_sell_price(chaos_card)
	_main.sfx.play("coin")
	_main.chaos[slot_idx] = null
	if _main.selected_chaos_slot == slot_idx:
		_main.selected_chaos_slot = -1
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func on_shop_leave() -> void:
	_main.shop_modal.visible = false
	_main.stage += 1
	_main.enemy_pic.modulate = Color.WHITE
	_main.enemy_pic.scale = Vector2.ONE

	# Enemy scaling per draft
	_main.enemy_max_hp = roundi(_main.enemy_max_hp * 1.5)
	_main.enemy_hp = _main.enemy_max_hp
	_main.enemy_atk = _main.enemy_atk * _main.PHP_GROW

	_main.walks_left = _main.walk_max
	_main.player_max_hp = _main.enemy_atk * _main.walk_max
	_main.player_hp = _main.player_max_hp

	# Wild Shuffle permits discarding after placement, in exchange for one use.
	_main.discards_left = maxi(0, _main.discard_max - (1 if _main.artifact_sys.has_rule(&"free_discard") else 0))
	_main.artifact_sys.round_start()

	_main.build_deck()
	_main.hand.clear()
	_main.spawn_current_enemy()


func on_artifact_slot_pressed(slot_idx: int) -> void:
	# Draft openOwnedPop(): name, rarity, description and a sell button.
	confirm_sell_artifact(slot_idx)
