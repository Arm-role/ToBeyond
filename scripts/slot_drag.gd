class_name SlotDrag
extends RefCounted

## Drag-and-drop for every card, moved from main.gd. Drag state lives here.
## kinds: "artifact"/"chaos" (owned slots: swap or drop in the centre zone to
## sell), "hand" (Gem → board tile), "board" (tile → tile / back to hand),
## "shop" (offer card → out of the shop panel / onto its slot row to buy).

var _main: Node

var drag_kind: String = ""
var drag_from: int = -1
var drag_start: Vector2 = Vector2.ZERO
var drag_moved: bool = false
var _src: Control = null
var _shop_action: Button = null
var _shop_kind: String = ""
var _ghost: Control = null
var _src_alpha: float = 1.0
## Drop here (middle of the screen) to sell the dragged Artifact / Chaos.
const SELL_ZONE := Rect2(480, 230, 960, 300)  # outside the shop: above the board tiles
const DRAG_THRESHOLD: float = 16.0
var _sell_hint: PanelContainer = null


func _init(main: Node) -> void:
	_main = main


func on_input(event: InputEvent) -> void:
	if _main.action_dialog != null and _main.action_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin(event.position)
		elif not drag_kind.is_empty():
			finish(event.position)
	elif event is InputEventMouseMotion and not drag_kind.is_empty():
		if not drag_moved and event.position.distance_to(drag_start) >= DRAG_THRESHOLD:
			drag_moved = true
			_start_visuals()
		if drag_moved and _ghost != null:
			_ghost.position = event.position - _ghost.size * 0.5


func _hit(c: Control, pos: Vector2) -> bool:
	return c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos)


func begin(mouse_pos: Vector2) -> void:
	# A release can be lost (focus loss, touch cancel): never keep a stale drag.
	if not drag_kind.is_empty() or _ghost != null:
		drag_kind = ""
		drag_moved = false
		_end_visuals()
	if _main.is_busy:
		return
	var shop_open: bool = _main.shop_modal.visible
	if shop_open:
		if _hit(_main.shop_offer_frame, mouse_pos):
			for card in _main.get_tree().get_nodes_in_group(&"shop_card"):
				if card is Control and _hit(card, mouse_pos) and card.has_meta("drag_action"):
					_arm("shop", -1, mouse_pos, card)
					_shop_action = card.get_meta("drag_action")
					_shop_kind = card.get_meta("drag_kind")
					return
	else:
		# Hand cards overlap: the highest z_index under the cursor wins.
		var best: Control = null
		for child in _main.hand_container.get_children():
			if child is Control and child.has_meta("card_id") and _hit(child, mouse_pos):
				if best == null or child.z_index >= best.z_index:
					best = child
		if best != null:
			_arm("hand", int(best.get_meta("card_id")), mouse_pos, best)
			return
		for i in range(_main.N_TILES):
			var tile := _main.tiles_container.get_child(i) as Control
			if _main.placed_cards.has(i) and _hit(tile, mouse_pos):
				_arm("board", i, mouse_pos, tile)
				return
	for i in range(_main.MAX_ARTIFACTS):
		var artifact_slot = _main.artifact_row.get_child(i + 1) as Control
		if _main.artifacts[i] != null and _hit(artifact_slot, mouse_pos):
			_arm("artifact", i, mouse_pos, artifact_slot)
			return
	for i in range(_main.chaos_slots.get_child_count()):
		var chaos_slot = _main.chaos_slots.get_child(i) as Control
		if _main.chaos[i] != null and _hit(chaos_slot, mouse_pos):
			_arm("chaos", i, mouse_pos, chaos_slot)
			return


func _arm(kind: String, from: int, pos: Vector2, src: Control) -> void:
	drag_kind = kind
	drag_from = from
	drag_start = pos
	drag_moved = false
	_src = src


func _start_visuals() -> void:
	if drag_kind == "artifact" or drag_kind == "chaos":
		_show_sell_hint(true)
	if _src == null or not is_instance_valid(_src):
		return
	_ghost = _src.duplicate(0) as Control
	_ghost.z_index = 200
	_ghost.size = _src.size
	_ghost.modulate.a = 0.85
	_set_ignore(_ghost)
	_main.add_child(_ghost)
	_ghost.position = drag_start - _ghost.size * 0.5
	_src_alpha = _src.modulate.a
	_src.modulate.a = 0.35


func _set_ignore(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_set_ignore(c)


func _end_visuals() -> void:
	_show_sell_hint(false)
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _src != null and is_instance_valid(_src):
		_src.modulate.a = _src_alpha
	_src = null


func _tile_at(pos: Vector2) -> int:
	for i in range(_main.N_TILES):
		if _hit(_main.tiles_container.get_child(i) as Control, pos):
			return i
	return -1


func finish(mouse_pos: Vector2) -> void:
	var kind := drag_kind
	var from := drag_from
	var moved := drag_moved
	var action := _shop_action
	var shop_kind := _shop_kind
	var over_src: bool = _src != null and is_instance_valid(_src) and _hit(_src, mouse_pos)
	drag_kind = ""
	drag_from = -1
	drag_moved = false
	_shop_action = null
	_shop_kind = ""
	_end_visuals()
	# Released on its own control (a tap with finger jitter): let it be a click.
	if not moved or over_src:
		return
	# A real drag never counts as a click on the button under the cursor.
	_main.get_viewport().set_input_as_handled()
	match kind:
		"hand":
			var tile := _tile_at(mouse_pos)
			if tile >= 0:
				_main.chaos_ctl.place_from_hand(from, tile)
		"board":
			var tile := _tile_at(mouse_pos)
			if tile >= 0:
				_main.chaos_ctl.move_board_card(from, tile)
			elif _hit(_main.hand_container, mouse_pos):
				_main.chaos_ctl.return_board_card(from)
		"shop":
			var ok := false
			match shop_kind:
				"artifact":
					ok = _hit(_main.artifact_row, mouse_pos)
				"chaos":
					ok = _hit(_main.chaos_slots, mouse_pos)
				_:
					ok = mouse_pos.y < _main.shop_modal.global_position.y
			if ok and action != null and is_instance_valid(action):
				action.pressed.emit()
		"artifact", "chaos":
			_finish_slot(kind, from, mouse_pos)


## While the shop is open its whole panel is the sell zone.
func _sell_rect() -> Rect2:
	if _main.shop_modal.visible:
		return _main.shop_modal.get_global_rect()
	return SELL_ZONE


func _finish_slot(kind: String, from: int, mouse_pos: Vector2) -> void:
	if _sell_rect().has_point(mouse_pos):
		if kind == "artifact":
			_main.shop_mgr.confirm_sell_artifact(from)
		else:
			_main.shop_mgr.confirm_sell_chaos(from)
		return
	var target := -1
	if kind == "artifact":
		for i in range(_main.MAX_ARTIFACTS):
			if _hit(_main.artifact_row.get_child(i + 1) as Control, mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = _main.artifacts[from]
			_main.artifacts[from] = _main.artifacts[target]
			_main.artifacts[target] = held
			_main.sync_totems()
	else:
		for i in range(_main.chaos_slots.get_child_count()):
			if _hit(_main.chaos_slots.get_child(i) as Control, mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = _main.chaos[from]
			_main.chaos[from] = _main.chaos[target]
			_main.chaos[target] = held
			# The picked card keeps its "picked" state when it moves.
			if _main.selected_chaos_slot == from:
				_main.selected_chaos_slot = target
			elif _main.selected_chaos_slot == target:
				_main.selected_chaos_slot = from
	if target >= 0:
		_main.update_all_ui()


func _show_sell_hint(on: bool) -> void:
	if _sell_hint == null:
		if not on:
			return
		_sell_hint = PanelContainer.new()
		_sell_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_hint.z_index = 150
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.83, 0.65, 0.29, 0.12)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.83, 0.65, 0.29, 0.6)
		sb.set_corner_radius_all(24)
		_sell_hint.add_theme_stylebox_override("panel", sb)
		var lab := Label.new()
		lab.text = "ลากมาที่นี่เพื่อขาย"
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 32)
		lab.add_theme_color_override("font_color", Color(0.83, 0.65, 0.29, 0.9))
		_sell_hint.add_child(lab)
		_main.add_child(_sell_hint)
	if on:
		var r := _sell_rect()
		_sell_hint.position = r.position
		_sell_hint.size = r.size
	_sell_hint.visible = on
