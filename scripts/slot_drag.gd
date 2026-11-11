class_name SlotDrag
extends RefCounted

## Artifact/Chaos slot drag-and-swap, moved from main.gd. Drag state lives here.

var _main: Node

var drag_kind: String = ""
var drag_from: int = -1
var drag_start: Vector2 = Vector2.ZERO
var drag_moved: bool = false

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
	if not moved:
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

