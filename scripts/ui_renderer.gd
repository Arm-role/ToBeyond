class_name UiRenderer
extends RefCounted

# ==============================================================================
# UiRenderer — Handles board tiles, hand cards, artifact row, and modals UI
# ==============================================================================

var _main: Node
var known_hand_ids: Dictionary = {}
var selected_hand_ids: Dictionary = {}

func _init(main: Node) -> void:
	_main = main


func update_all_ui() -> void:
	_main.stage_label.text = "ด่าน %d" % _main.stage
	_main.coins_label.text = "🪙 %d" % _main.coins
	_main.deck_count_btn.text = "🃏 กอง %d ใบ · กดดู" % _main.deck.size()

	_main.hero_hp_label.text = "HP %d / %d" % [_main.player_hp, _main.player_max_hp]
	_main.hero_hp_bar.max_value = _main.player_max_hp
	_main.hero_hp_bar.value = _main.player_hp

	_main.enemy_hp_label.text = "HP %d / %d" % [_main.enemy_hp, _main.enemy_max_hp]
	_main.enemy_hp_bar.max_value = _main.enemy_max_hp
	_main.enemy_hp_bar.value = _main.enemy_hp
	_main.enemy_atk_label.text = "⚔ %d" % _main.enemy_atk

	_main.walk_btn.disabled = _main.is_busy or (_main.walks_left <= 0 and _main.selected_card_ids.is_empty())
	_main.restart_btn.disabled = _main.is_busy
	if _main.selected_card_ids.size() > 0:
		_main.walk_btn.text = "วาง (%d)" % _main.selected_card_ids.size()
	else:
		_main.walk_btn.text = "เดิน %d รอบ" % _main.walks_left

	# Rule: If board has cards, cannot discard unless freediscard artifact is owned
	var blocked = (_main.placed_cards.size() > 0) and (not _main.has_artifact("freediscard"))
	_main.discard_btn.disabled = _main.is_busy or _main.discards_left <= 0 or _main.selected_card_ids.is_empty() or blocked

	if blocked:
		_main.discard_btn.text = "วาง Gem แล้วทิ้งไม่ได้"
	elif _main.selected_card_ids.size() > 0:
		_main.discard_btn.text = "ทิ้ง Gem (%d)" % _main.selected_card_ids.size()
	else:
		_main.discard_btn.text = "ทิ้ง Gem"

	render_tiles()
	render_hand()
	render_artifact_row()
	render_chaos_row()


func render_tiles() -> void:
	var calc = _main.calculate_groups()
	for i in range(_main.N_TILES):
		var tile_btn = _main.tiles_container.get_child(i) as Button

		# Seamless empty stylebox so SVG fills the tile button cleanly
		var sb_empty = StyleBoxEmpty.new()
		tile_btn.add_theme_stylebox_override("normal", sb_empty)
		tile_btn.add_theme_stylebox_override("hover", sb_empty)
		tile_btn.add_theme_stylebox_override("pressed", sb_empty)
		tile_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile_btn.expand_icon = true
		tile_btn.text = ""

		if _main.placed_cards.has(i):
			var card = _main.placed_cards[i]
			var is_blank = card.get("is_blank", false) or card.get("color") == "blank"
			var is_gold = card.get("gold", false)

			if is_blank:
				var key = "%d_blank" % i
				if _main.PLACED_TILE_TEX.has(key):
					tile_btn.icon = _main.PLACED_TILE_TEX[key]
				elif _main.TILE_EMPTY_TEX.has(i):
					tile_btn.icon = _main.TILE_EMPTY_TEX[i]
				tile_btn.modulate = Color.WHITE
			else:
				var c_dir = card.get("dir", "N")
				var c_col = card.get("color", "blue")
				var key = "%d_%s_%s" % [i, c_col, c_dir]
				if _main.PLACED_TILE_TEX.has(key):
					tile_btn.icon = _main.PLACED_TILE_TEX[key]
				elif _main.TILE_EMPTY_TEX.has(i):
					tile_btn.icon = _main.TILE_EMPTY_TEX[i]

				if is_gold:
					tile_btn.modulate = Color(1.2, 1.15, 0.8)
				else:
					tile_btn.modulate = Color.WHITE
		else:
			if _main.TILE_EMPTY_TEX.has(i):
				tile_btn.icon = _main.TILE_EMPTY_TEX[i]
			tile_btn.modulate = Color.WHITE

		_apply_tile_state(tile_btn, i, calc)
		_render_crystal(tile_btn, i)
		_render_totem(tile_btn, i)

		# The strip under each tile is the player's quick Stone readout.  Render it
		# as a colored, connected-looking score badge rather than a plain label.
		var score = _main.gstrip_container.get_child(i) as Label
		var has_gem = _main.placed_cards.has(i) and not _main.placed_cards[i].get("is_blank", false)
		if not has_gem:
			score.text = "•"
			score.modulate = Color("#68627a")
			score.remove_theme_stylebox_override("normal")
			continue

		var value = int(calc["grp_val"].get(i, 1))
		var group_color = _group_color_for_tile(i, calc)
		score.text = "+%d" % value
		score.modulate = group_color
		score.add_theme_stylebox_override("normal", _make_gstrip_badge(group_color))


func _apply_tile_state(tile_btn: Button, tile_idx: int, calc: Dictionary) -> void:
	var card = _main.placed_cards.get(tile_idx)
	var is_empty = card == null
	var can_place = is_empty and not _main.is_busy and _main.selected_card_ids.size() == 1
	var has_group = is_empty == false and not card.get("is_blank", false) and calc["grp_val"].has(tile_idx)
	var matches_tile = is_empty == false and card.get("dir", "") == _main.TILE_DIR[tile_idx]
	var is_gold = is_empty == false and card.get("gold", false)

	var accent = Color("#514a68")
	var width = 2
	var glow_alpha = 0.0
	var hint = "ช่อง %d · ทิศ %s" % [tile_idx + 1, _main.TILE_DIR[tile_idx]]
	if can_place:
		accent = _main.COLORS["brass_bright"]
		width = 5
		glow_alpha = 0.50
		hint += " · วาง Gem ที่เลือกได้"
	elif is_gold:
		accent = _main.COLORS["gold"]
		width = 6
		glow_alpha = 0.75
		hint += " · Gem ทอง: ทำงานสองครั้ง"
	elif matches_tile:
		accent = _main.COLORS["brass_bright"]
		width = 5
		glow_alpha = 0.45
		hint += " · ทิศตรงช่อง"
	elif has_group:
		accent = _group_color_for_tile(tile_idx, calc)
		width = 4
		glow_alpha = 0.30
		hint += " · Stone +%d" % int(calc["grp_val"].get(tile_idx, 1))
	if _main.chaos_mult_tiles.has(tile_idx):
		hint += " · Chaos MULT +5"
		accent = Color("#c88aff")
		glow_alpha = maxf(glow_alpha, 0.55)
	if _main.chaos_xmult_tiles.has(tile_idx):
		hint += " · Chaos MULT ×1.2"
		accent = Color("#c88aff")
		glow_alpha = maxf(glow_alpha, 0.55)
	if _main.chaos_xatk_tiles.has(tile_idx):
		hint += " · Chaos ATK ×1.2"
		accent = Color("#72d8ff")
		glow_alpha = maxf(glow_alpha, 0.55)
	if _main.chaos_crystals.has(tile_idx):
		hint += " · ผลึก Gem HP %d" % int(_main.chaos_crystals[tile_idx])
		accent = Color("#72d8ff")
		glow_alpha = maxf(glow_alpha, 0.75)

	tile_btn.tooltip_text = hint
	var normal = _make_tile_frame(accent, width, glow_alpha)
	tile_btn.add_theme_stylebox_override("normal", normal)
	var hover = _make_tile_frame(accent.lightened(0.18), width + 1, minf(0.85, glow_alpha + 0.20))
	tile_btn.add_theme_stylebox_override("hover", hover)
	tile_btn.add_theme_stylebox_override("pressed", hover)


func _render_crystal(tile_btn: Button, tile_idx: int) -> void:
	var existing := tile_btn.get_node_or_null("ChaosCrystal") as Label
	if not _main.chaos_crystals.has(tile_idx):
		if existing != null:
			existing.queue_free()
		return
	if existing == null:
		existing = Label.new()
		existing.name = "ChaosCrystal"
		existing.set_anchors_preset(Control.PRESET_CENTER)
		existing.offset_left = -45.0
		existing.offset_top = -39.0
		existing.offset_right = 45.0
		existing.offset_bottom = 39.0
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		existing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		existing.add_theme_font_size_override("font_size", 36)
		existing.add_theme_color_override("font_color", Color("#72d8ff"))
		existing.add_theme_color_override("font_outline_color", Color("#ffffff"))
		existing.add_theme_constant_override("outline_size", 2)
		tile_btn.add_child(existing)
	existing.text = "💎\n%d" % int(_main.chaos_crystals[tile_idx])


func _render_totem(tile_btn: Button, tile_idx: int) -> void:
	var existing := tile_btn.get_node_or_null("ArtifactTotem") as Label
	if not _main.totem_tiles.has(tile_idx):
		if existing != null:
			existing.queue_free()
		return
	if existing == null:
		existing = Label.new()
		existing.name = "ArtifactTotem"
		existing.set_anchors_preset(Control.PRESET_TOP_LEFT)
		existing.offset_left = 5.0
		existing.offset_top = 3.0
		existing.offset_right = 78.0
		existing.offset_bottom = 34.0
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.add_theme_font_size_override("font_size", 16)
		existing.add_theme_color_override("font_color", Color("#7fd0ff"))
		existing.add_theme_color_override("font_outline_color", Color("#120d22"))
		existing.add_theme_constant_override("outline_size", 3)
		tile_btn.add_child(existing)
	existing.text = "🗿 +%d" % _main.totem_attack(tile_idx)


func _make_tile_frame(accent: Color, border_width: int, glow_alpha: float) -> StyleBoxFlat:
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	frame.border_color = accent
	frame.border_width_left = border_width
	frame.border_width_top = border_width
	frame.border_width_right = border_width
	frame.border_width_bottom = border_width
	frame.corner_radius_top_left = 8
	frame.corner_radius_top_right = 8
	frame.corner_radius_bottom_left = 8
	frame.corner_radius_bottom_right = 8
	frame.shadow_color = Color(accent.r, accent.g, accent.b, glow_alpha)
	frame.shadow_size = 8 if glow_alpha > 0.0 else 0
	return frame


func _group_color_for_tile(tile_idx: int, calc: Dictionary) -> Color:
	for group in calc["groups"]:
		if group["idxs"].has(tile_idx):
			if group["col"] != null:
				return _main.COLORS.get(group["col"], _main.COLORS["brass_bright"])
			return Color("#e040fb")
	return _main.COLORS["brass_bright"]


func _make_gstrip_badge(group_color: Color) -> StyleBoxFlat:
	var badge = StyleBoxFlat.new()
	badge.bg_color = Color(0.02, 0.02, 0.05, 0.92)
	badge.border_color = group_color
	badge.border_width_top = 9
	badge.corner_radius_bottom_left = 10
	badge.corner_radius_bottom_right = 10
	badge.content_margin_left = 12.0
	badge.content_margin_right = 12.0
	badge.content_margin_top = 3.0
	badge.content_margin_bottom = 3.0
	badge.shadow_color = Color(group_color.r, group_color.g, group_color.b, 0.35)
	badge.shadow_size = 5
	return badge


func render_hand() -> void:
	if _main.sort_mode == "color":
		_main.hand.sort_custom(func(a, b):
			var ca = _main.COLOR_ORDER.find(a["color"])
			var cb = _main.COLOR_ORDER.find(b["color"])
			if ca != cb: return ca < cb
			return _main.DIR_ORDER.find(a["dir"]) < _main.DIR_ORDER.find(b["dir"])
		)
	else:
		_main.hand.sort_custom(func(a, b):
			var da = _main.DIR_ORDER.find(a["dir"])
			var db = _main.DIR_ORDER.find(b["dir"])
			if da != db: return da < db
			return _main.COLOR_ORDER.find(a["color"]) < _main.COLOR_ORDER.find(b["color"])
		)

	for child in _main.hand_container.get_children():
		child.queue_free()

	const CARD_SIZE := Vector2(108, 140)
	const IDEAL_GAP := 9.0
	const MIN_STEP := 18.0
	var card_count = _main.hand.size()
	var ideal_width = CARD_SIZE.x * 8.0 + IDEAL_GAP * 7.0
	var available_width = maxf(_main.hand_container.size.x, ideal_width)
	var row_width = minf(ideal_width, available_width)
	var step = CARD_SIZE.x + IDEAL_GAP
	if card_count > 1 and card_count * CARD_SIZE.x + (card_count - 1) * IDEAL_GAP > row_width:
		step = maxf((row_width - CARD_SIZE.x) / float(card_count - 1), MIN_STEP)
	var used_width = CARD_SIZE.x if card_count <= 1 else CARD_SIZE.x + step * float(card_count - 1)
	var start_x = (available_width - used_width) * 0.5
	var live_ids: Dictionary = {}
	var live_selected_ids: Dictionary = {}

	for card_index in range(card_count):
		var card = _main.hand[card_index]
		var btn = Button.new()
		# Cards follow the 1920×1080 gameplay canvas (1.5× the original draft).
		btn.size = CARD_SIZE
		var is_sel = _main.selected_card_ids.has(card["id"])
		var is_blank = card.get("is_blank", false)
		btn.position = Vector2(start_x + step * card_index, 14.0 - (12.0 if is_sel else 0.0))
		btn.z_index = 20 if is_sel else card_index
		live_ids[card["id"]] = true
		if is_sel:
			live_selected_ids[card["id"]] = true

		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		var border_width = 5 if is_sel else 3
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
		sb.border_width_left = border_width
		sb.border_width_right = border_width

		if is_blank:
			sb.bg_color = Color("#40404e")
			sb.border_color = Color("#ffd966") if is_sel else Color("#888899")
			btn.icon = null
			btn.text = "⬜\n[การ์ดเปล่า]%s" % ["\n▲ เลือก" if is_sel else ""]
			btn.tooltip_text = "การ์ดเปล่าจากสกิลบอส ไม่มีสีไม่มีทิศ (แนะนำให้เลือกทิ้ง Discard)"
		else:
			var c_col = card["color"]
			var c_dir = card["dir"]
			sb.bg_color = _main.COLORS.get(c_col, Color.GRAY)
			sb.border_color = _main.COLORS["brass_bright"] if is_sel else _main.COLORS["brass"]

			var icon_tex = _main.EMBLEMS.get(c_dir)
			if icon_tex != null:
				btn.icon = icon_tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.expand_icon = true
				if is_sel:
					btn.text = "▲"
					btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				else:
					btn.text = ""
			else:
				btn.icon = null
				btn.text = "%s\n%s%s" % [c_col.to_upper(), c_dir, "\n✔ เลือก" if is_sel else ""]

		btn.add_theme_stylebox_override("normal", sb)
		var hover = sb.duplicate()
		hover.border_color = _main.COLORS["brass_bright"]
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", sb)

		var card_id = card["id"]
		btn.pressed.connect(func(): _main._on_hand_card_clicked(card_id))
		_main.hand_container.add_child(btn)
		if not known_hand_ids.has(card_id):
			var final_pos = btn.position
			btn.position.y -= 42.0
			btn.modulate.a = 0.0
			var deal = _main.create_tween()
			deal.tween_interval(float(card_index) * 0.07)
			deal.tween_property(btn, "position", final_pos, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			deal.parallel().tween_property(btn, "modulate:a", 1.0, 0.18)
		elif is_sel != selected_hand_ids.has(card_id):
			var selection_start = btn.position
			if is_sel:
				selection_start.y += 12.0
			else:
				selection_start.y -= 12.0
			btn.position = selection_start
			var lift = _main.create_tween()
			lift.tween_property(btn, "position", Vector2(start_x + step * card_index, 14.0 - (12.0 if is_sel else 0.0)), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	known_hand_ids = live_ids
	selected_hand_ids = live_selected_ids


func render_artifact_row() -> void:
	for i in range(ShopManager.MAX_ARTIFACTS):
		var slot = _main.artifact_row.get_child(i + 1) as Button
		if slot == null: continue
		var art = _main.artifacts[i]
		if art != null:
			# Use the draft SVG cover when imported, with the text icon as a safe fallback.
			slot.icon = _main.ART_TEX.get(art.get("type"))
			slot.expand_icon = slot.icon != null
			var counter = art.get("m", null)
			var has_counter: bool = counter != null and not (art.get("type") == "stoneUp" and float(counter) == 1.0)
			slot.text = str(counter) if has_counter else ("" if slot.icon != null else art["icon"])
			slot.add_theme_font_size_override("font_size", 18 if has_counter and slot.icon != null else (25 if has_counter else 42))
			slot.tooltip_text = art["name"] + "\n" + art.get("desc", "")
		else:
			slot.icon = null
			slot.expand_icon = false
			slot.text = ""
			slot.tooltip_text = ""


func render_chaos_row() -> void:
	for i in range(_main.chaos_slots.get_child_count()):
		var slot := _main.chaos_slots.get_child(i) as Button
		var chaos_card = _main.chaos[i]
		slot.disabled = chaos_card == null
		slot.icon = null
		if chaos_card == null:
			slot.text = ""
			slot.tooltip_text = "ช่อง Chaos ว่าง"
			continue
		var kind: String = chaos_card["kind"]
		var icon: String = str({"color":"🎨", "dirc":"🧭", "tdir":"🧭", "mtile":"⚡", "xmult":"×", "xatk":"✴", "goldify":"✨", "destroy":"💥", "crystal":"💎"}.get(kind, "?"))
		var label: String = str({"color":"เปลี่ยนสี", "dirc":"เปลี่ยนทิศ", "tdir":"ทิศช่อง", "mtile":"MULT +5", "xmult":"MULT ×1.2", "xatk":"ATK ×1.2", "goldify":"Gem ทอง", "destroy":"ทำลาย", "crystal":"ผลึก"}.get(kind, kind))
		if chaos_card.has("col"):
			label += " " + chaos_card["col"]
		if chaos_card.has("dir"):
			label += " " + chaos_card["dir"]
		slot.text = "%s\n%s" % [icon, label]
		slot.add_theme_font_size_override("font_size", 14)
		slot.tooltip_text = "Chaos: %s\nแตะเพื่อใช้" % label
		if i == _main.selected_chaos_slot:
			slot.modulate = Color("#f5d48e")
		else:
			slot.modulate = Color.WHITE


func setup_stone_modal_content() -> void:
	for child in _main.stone_list.get_children():
		child.queue_free()

	for r in _main.stone_formulas:
		var lbl = Label.new()
		lbl.text = "• %s (%s)\n  ขั้นต่ำ: %d ใบ | เริ่มต้น: %d ATK (+%d ต่อใบ)" % [r["name"], r["desc"], r["min"], r["a"], r["g"]]
		_main.stone_list.add_child(lbl)


func open_deck_modal() -> void:
	for child in _main.deck_modal_list.get_children():
		child.queue_free()

	var counts = {
		"red": {"N": 0, "E": 0, "S": 0, "W": 0},
		"green": {"N": 0, "E": 0, "S": 0, "W": 0},
		"orange": {"N": 0, "E": 0, "S": 0, "W": 0},
		"blue": {"N": 0, "E": 0, "S": 0, "W": 0}
	}
	var blank_count = 0

	for card in _main.deck:
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

	for col in _main.COLOR_ORDER:
		var total_col = counts[col]["N"] + counts[col]["E"] + counts[col]["S"] + counts[col]["W"]
		var title = "%s (เหลือทั้งหมด %d ใบ):" % [color_names[col], total_col]
		var detail = "   N: %d ใบ  |  E: %d ใบ  |  S: %d ใบ  |  W: %d ใบ" % [
			counts[col]["N"], counts[col]["E"], counts[col]["S"], counts[col]["W"]
		]
		var pnl = _make_deck_panel(title, detail, _main.COLORS[col].darkened(0.7), _main.COLORS[col])
		_main.deck_modal_list.add_child(pnl)

	if blank_count > 0:
		var title = "⬜ การ์ดเปล่า (ชั่วคราวจากสกิลบอส): %d ใบ" % blank_count
		var pnl = _make_deck_panel(title, "", Color("#3a3a48"), Color("#aaaaaa"))
		_main.deck_modal_list.add_child(pnl)

	_main.deck_modal.visible = true


func _make_deck_panel(title: String, detail: String, bg_col: Color, border_col: Color) -> PanelContainer:
	var pnl = PanelContainer.new()
	var pnl_sb = StyleBoxFlat.new()
	pnl_sb.bg_color = bg_col
	pnl_sb.border_color = border_col
	pnl_sb.border_width_left = 4
	pnl_sb.set_corner_radius_all(6)
	pnl.add_theme_stylebox_override("panel", pnl_sb)

	var vbox = VBoxContainer.new()
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.modulate = border_col.lightened(0.3)
	lbl_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_title)

	if not detail.is_empty():
		var lbl_detail = Label.new()
		lbl_detail.text = detail
		lbl_detail.add_theme_font_size_override("font_size", 14)
		vbox.add_child(lbl_detail)

	pnl.add_child(vbox)
	return pnl
