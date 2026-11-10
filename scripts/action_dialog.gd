class_name ActionDialog
extends RefCounted

## Buy/sell confirm popup, moved from main.gd. `action_dialog` and `pending_dialog_action` stay on main.

var _main: Node


func _init(main: Node) -> void:
	_main = main


## Buy/sell popup styled like the draft's `.pop` / `.popbox`:
## title, description, action button and a "ปิด" button.
func setup() -> void:
	_main.action_dialog = Control.new()
	_main.action_dialog.name = "ActionPopup"
	_main.action_dialog.visible = false
	_main.action_dialog.z_index = 200
	_main.action_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.action_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_main.action_dialog.visible = false
	)
	_main.action_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.action_dialog.add_child(center)
	var box := PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(660, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2d2450")
	sb.border_color = GameAssets.COLORS["brass"]
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
	title.add_theme_color_override("font_color", GameAssets.COLORS["brass_bright"])
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
	desc.add_theme_color_override("font_color", GameAssets.COLORS["text_bright"])
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
		bs.bg_color = GameAssets.COLORS["brass_bright"] if b == ok else Color("#c9c0e6")
		if b == ok:
			bs.border_width_bottom = 66
			bs.border_color = GameAssets.COLORS["brass"]
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
		_main.action_dialog.visible = false
		if _main.pending_dialog_action.is_valid():
			_main.pending_dialog_action.call()
		_main.pending_dialog_action = Callable()
	)
	close.pressed.connect(func(): _main.action_dialog.visible = false)
	_main.add_child(_main.action_dialog)


func show_dialog(title_text: String, detail: String, confirm_text: String, action: Callable, disabled: bool = false, rarity: String = "") -> void:
	_main.pending_dialog_action = action
	var rar := _main.action_dialog.get_node("Center/Box/VB/Rar") as Label
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
	_main.action_dialog.get_node("Center/Box/VB/Title").text = title_text
	_main.action_dialog.get_node("Center/Box/VB/Desc").text = detail
	var ok := _main.action_dialog.get_node("Center/Box/VB/Acts/Ok") as Button
	ok.text = confirm_text
	ok.disabled = disabled
	ok.modulate.a = 0.4 if disabled else 1.0
	_main.action_dialog.visible = true

