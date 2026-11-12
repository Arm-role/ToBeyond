class_name SlotDrag
extends RefCounted

## Artifact/Chaos slot drag-and-swap, moved from main.gd. Drag state lives here.

var _main: Node

var drag_kind: String = ""
var drag_from: int = -1
var drag_start: Vector2 = Vector2.ZERO
var drag_moved: bool = false
## Drop here (middle of the screen) to sell the dragged Artifact / Chaos.
const SELL_ZONE := Rect2(480, 330, 960, 420)
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
		if event.position.distance_to(drag_start) >= 10.0:
			drag_moved = true
			_show_sell_hint(true)


func begin(mouse_pos: Vector2) -> void:
	if _main.is_busy:
		return
	for i in range(_main.MAX_ARTIFACTS):
		var artifact_slot = _main.artifact_row.get_child(i + 1) as Control
		if _main.artifacts[i] != null and artifact_slot.get_global_rect().has_point(mouse_pos):
			drag_kind = "artifact"
			drag_from = i
			drag_start = mouse_pos
			drag_moved = false
			return
	for i in range(_main.chaos_slots.get_child_count()):
		var chaos_slot = _main.chaos_slots.get_child(i) as Control
		if _main.chaos[i] != null and chaos_slot.get_global_rect().has_point(mouse_pos):
			drag_kind = "chaos"
			drag_from = i
			drag_start = mouse_pos
			drag_moved = false
			return


func finish(mouse_pos: Vector2) -> void:
	var kind := drag_kind
	var from := drag_from
	var moved := drag_moved
	drag_kind = ""
	drag_from = -1
	drag_moved = false
	_show_sell_hint(false)
	if not moved:
		return
	if SELL_ZONE.has_point(mouse_pos):
		if kind == "artifact":
			_main.shop_mgr.confirm_sell_artifact(from)
		else:
			_main.shop_mgr.confirm_sell_chaos(from)
		_main.get_viewport().set_input_as_handled()
		return
	var target := -1
	if kind == "artifact":
		for i in range(_main.MAX_ARTIFACTS):
			var slot = _main.artifact_row.get_child(i + 1) as Control
			if slot.get_global_rect().has_point(mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = _main.artifacts[from]
			_main.artifacts[from] = _main.artifacts[target]
			_main.artifacts[target] = held
			_main.sync_totems()
	elif kind == "chaos":
		for i in range(_main.chaos_slots.get_child_count()):
			var slot = _main.chaos_slots.get_child(i) as Control
			if slot.get_global_rect().has_point(mouse_pos):
				target = i
				break
		if target >= 0 and target != from:
			var held = _main.chaos[from]
			_main.chaos[from] = _main.chaos[target]
			_main.chaos[target] = held
	if target >= 0:
		_main.update_all_ui()
		_main.get_viewport().set_input_as_handled()



func _show_sell_hint(on: bool) -> void:
	if _sell_hint == null:
		if not on:
			return
		_sell_hint = PanelContainer.new()
		_sell_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_hint.z_index = 90
		_sell_hint.position = SELL_ZONE.position
		_sell_hint.size = SELL_ZONE.size
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
	_sell_hint.visible = on
