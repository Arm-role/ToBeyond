class_name DebugScenarios
extends Node

## Fixed test states used by tools/parity to compare the game with
## To_Beyond_Draft.html. Does nothing unless a scenario is requested:
##   Web build : index.html?dbg=<name>
##   Headless  : godot --headless --path . -- --dbg=<name> [--rects=<file.json>]
## Web also gets window.tbRun(name), window.tbRects(json) -> window.tbRectsOut,
## and window.tbReady = <name> once the state is on screen.
## Keep the list in sync with tools/parity/scenarios.js.

const SCENARIOS := ["main", "placed", "win", "shop", "lose", "boss", "arts", "rare", "deck", "stone", "shopart", "newarts", "gembuff", "deckmarks", "goldwalk"]
## Same 8 cards as tools/parity/scenarios.js, so both hands match.
const FIXED_HAND := [["red", "N"], ["red", "N"], ["blue", "E"], ["blue", "E"],
	["green", "S"], ["orange", "W"], ["red", "S"], ["blue", "W"]]

var main: Node
var _js_refs: Array = []


func _ready() -> void:
	main = get_parent()
	var scenario := _arg("dbg")
	if OS.has_feature("web"):
		_expose_js()
	if _arg("rects") != "":
		get_window().size = Vector2i(1280, 720)
	if scenario != "":
		run.call_deferred(scenario, false)
	elif OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").tbReady = "none"


func run(scenario: String, restart: bool = true) -> void:
	if not scenario in SCENARIOS:
		push_warning("DebugScenarios: unknown scenario '%s' (have %s)" % [scenario, ", ".join(SCENARIOS)])
		return
	if restart:
		main.start_new_game()
	if scenario == "boss":
		# Third enemy = first boss, reached the same way the game does.
		main.shop_mgr.on_shop_leave()
		main.shop_mgr.on_shop_leave()
	main.coins = 25
	main.hand.clear()
	for i in FIXED_HAND.size():
		main.hand.append({"id": 9000 + i, "color": FIXED_HAND[i][0], "dir": FIXED_HAND[i][1], "is_blank": false, "gold": false})
	main.update_all_ui()
	match scenario:
		"placed":
			# All 8 fixed cards auto-placed (same as selecting them all and pressing Walk).
			main.selected_card_ids.clear()
			for c in main.hand:
				main.selected_card_ids.append(int(c["id"]))
			main.auto_place_selected()
			await get_tree().create_timer(1.2).timeout
		"gembuff":
			# Cards 4-7 placed on tiles, 0-3 stay in the hand. Buffs: hand cards 0 (+1), 1 (+2), 3 (+1)
			# trigger after the walk; placed card 5 (+1) must not.
			main.hand[0]["buffs"] = {"mult": 1}
			main.hand[1]["buffs"] = {"mult": 2}
			main.hand[3]["buffs"] = {"mult": 1}
			main.hand[3]["gold"] = true  # gold + buff: triggers twice
			main.hand[5]["buffs"] = {"mult": 1}
			main.selected_card_ids.clear()
			for i in range(4, main.hand.size()):
				main.selected_card_ids.append(int(main.hand[i]["id"]))
			main.auto_place_selected()
			await get_tree().create_timer(1.2).timeout
		"win":
			main.enemy_hp = 0
			main.on_victory()
		"shop":
			main.open_shop()
		"shopart":
			# Shop "artifact" tab lists the whole catalog (new cards included).
			main.open_shop()
			main.shop_mgr.set_tab("artifact")
			await get_tree().create_timer(0.6).timeout
		"lose":
			main.on_game_over()
		"deck":
			main.open_deck_modal()
		"goldwalk":
			# All 8 placed, hand cards 0, 3 and 7 are gold: each triggers twice (visible second beat).
			for i in [0, 3, 7]:
				main.hand[i]["gold"] = true
			main.selected_card_ids.clear()
			for c in main.hand:
				main.selected_card_ids.append(int(c["id"]))
			main.auto_place_selected()
			await get_tree().create_timer(1.2).timeout
		"deckmarks":
			# Deck modal with a few gold and buffed Gems among plain ones.
			for i in [0, 5, 12, 20, 33]:
				main.deck[i]["gold"] = true
			for i in [5, 8, 21, 40]:
				main.deck[i]["buffs"] = {"mult": 1}
			main.open_deck_modal()
		"stone":
			main.setup_stone_modal_content()
			main.stone_modal.visible = true
		"arts":
			var slot := 0
			for t in ["add5", "mult2", "atk15"]:
				for it in ShopManager.ARTIFACT_CATALOG:
					if it["type"] == t:
						main.artifacts[slot] = it.duplicate()
						slot += 1
			main.update_all_ui()
		"newarts":
			# Start playing with Empty Fist + Void Lens + Hollow Heart equipped.
			var nslot := 0
			for t in ["emptyAtk", "emptyMult", "emptyGrow"]:
				for it in ShopManager.ARTIFACT_CATALOG:
					if it["type"] == t:
						main.artifacts[nslot] = it.duplicate()
						nslot += 1
			main.update_all_ui()
		"rare":
			var rslot := 0
			for t in ["add5", "stoneUp", "north5"]:
				for it in ShopManager.ARTIFACT_CATALOG:
					if it["type"] == t:
						main.artifacts[rslot] = it.duplicate()
						rslot += 1
			main.update_all_ui()
		"boss":
			main.chaos = [{"kind": "mtile"}, {"kind": "color", "col": "red"}, {"kind": "tdir", "dir": "W"}]
			main.chaos_mult_tiles[2] = true
			main.chaos_xmult_tiles[5] = true
			main.chaos_xatk_tiles[5] = true
			for h in [main.hand[6], main.hand[7]]:
				h["is_blank"] = true
				h["color"] = "blank"
			main.update_all_ui()
			await get_tree().create_timer(0.3).timeout
			main.show_discovery_toast("cd")
			main.chaos_msg("แตะช่องที่ต้องการวาง")
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_ready_signal(scenario)


func _ready_signal(scenario: String) -> void:
	print("TB_READY ", scenario)
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").tbReady = scenario
	var rects_file := _arg("rects")
	if rects_file != "":
		var txt := FileAccess.get_file_as_string(rects_file)
		var paths = JSON.parse_string(txt) if txt.strip_edges() != "" else []
		print("TB_RECTS ", JSON.stringify(rects(paths if paths is Array else [])))
		get_tree().quit()


## Screen rects in CSS px of a 1280x720 page (the draft's size), plus text,
## font size and colour. "Path/*" returns every Control child of Path.
func rects(paths: Array) -> Dictionary:
	var out := {}
	for p in paths:
		var key := str(p)
		if key.ends_with("/*"):
			var parent := main.get_node_or_null(key.trim_suffix("/*"))
			var arr := []
			if parent != null:
				for ch in parent.get_children():
					if ch is Control and not ch.is_queued_for_deletion():
						arr.append(_info(ch))
			out[key] = arr
		else:
			var n := main.get_node_or_null(key)
			out[key] = _info(n) if n is Control else null
	return out


func _info(c: Control) -> Dictionary:
	var xf: Transform2D = c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
	var s := xf.get_scale()
	var d := {"x": roundi(xf.origin.x), "y": roundi(xf.origin.y), "w": roundi(c.size.x * s.x), "h": roundi(c.size.y * s.y), "vis": c.is_visible_in_tree(), "type": c.get_class()}
	var text := ""
	var font: Font = null
	var fs := 0
	var tsize := Vector2.ZERO
	var halign := HORIZONTAL_ALIGNMENT_CENTER
	var valign := VERTICAL_ALIGNMENT_CENTER
	if c is RichTextLabel:
		text = c.get_parsed_text()
		fs = c.get_theme_font_size("normal_font_size")
		d["font"] = c.get_theme_font("normal_font").get_font_name()
		d["color"] = "#" + c.get_theme_color("default_color").to_html(false)
		tsize = Vector2(c.get_content_width(), c.get_content_height())
		var ha = c.get("horizontal_alignment")
		halign = HORIZONTAL_ALIGNMENT_CENTER if "[center]" in c.text else (ha if ha != null else HORIZONTAL_ALIGNMENT_LEFT)
		valign = VERTICAL_ALIGNMENT_TOP
	elif c is Label or c is Button:
		text = c.text
		font = c.get_theme_font("font")
		fs = c.get_theme_font_size("font_size")
		d["font"] = font.get_font_name()
		d["color"] = "#" + c.get_theme_color("font_color").to_html(false)
		if c is Label:
			halign = c.horizontal_alignment
			valign = c.vertical_alignment
		else:
			halign = c.alignment
			if c.icon != null:
				d["icon"] = true
	var kids := _child_text(c)
	d["leaf"] = kids == "" and (c is Label or c is Button or c is RichTextLabel)
	d["text"] = (text + kids).strip_edges().left(60)
	if fs > 0:
		d["fs"] = snappedf(fs * s.y, 0.1)
	if (c is Label or c is RichTextLabel) and text.strip_edges() == "" \
			and not c.get_children().any(func(ch): return ch is CanvasItem and ch.visible):
		d["vis"] = false
	if text.strip_edges() != "":
		if font != null:
			var wrap: bool = c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF
			tsize = font.get_multiline_string_size(text, halign, c.size.x if wrap else -1.0, fs)
		var ox: float = [0.0, (c.size.x - tsize.x) / 2.0, c.size.x - tsize.x, 0.0][halign]
		var oy: float = [0.0, (c.size.y - tsize.y) / 2.0, c.size.y - tsize.y, 0.0][valign]
		var p := xf * Vector2(ox, oy)
		d["tb"] = [roundi(p.x), roundi(p.y), roundi(tsize.x * s.x), roundi(tsize.y * s.y)]
	return d


## Text of visible descendant labels (like the DOM's innerText of a container).
func _child_text(n: Node) -> String:
	var out := ""
	for ch in n.get_children():
		if not (ch is CanvasItem and ch.visible):
			continue
		if ch is RichTextLabel:
			out += "\n" + ch.get_parsed_text()
		elif ch is Label:
			out += "\n" + ch.text
		out += _child_text(ch)
	return out


func _expose_js() -> void:
	var win := JavaScriptBridge.get_interface("window")
	var run_cb := JavaScriptBridge.create_callback(func(args: Array): run(str(args[0])))
	var rects_cb := JavaScriptBridge.create_callback(func(args: Array):
		var paths = JSON.parse_string(str(args[0]))
		win.tbRectsOut = JSON.stringify(rects(paths if paths is Array else [])))
	_js_refs = [run_cb, rects_cb]
	win.tbRun = run_cb
	win.tbRects = rects_cb


func _arg(key: String) -> String:
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("location.search", true))
		var m := RegEx.create_from_string("[?&]" + key + "=([A-Za-z0-9_]+)").search(q)
		return m.get_string(1) if m != null else ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return ""
