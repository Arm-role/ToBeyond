class_name ToolbarControls
extends RefCounted

## Fullscreen, audio and sort buttons, moved from main.gd.

var _main: Node


func _init(main: Node) -> void:
	_main = main


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
		var sb: StyleBox = _main.restart_btn.get_theme_stylebox("normal" if st == "focus" else st)
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
	_main.get_node("TopBar").add_child(btn)


## Round speaker button (mute / unmute), left of the fullscreen button.
func _setup_audio_button() -> void:
	var btn := Button.new()
	btn.name = "AudioBtn"
	btn.layout_mode = 1
	btn.anchors_preset = Control.PRESET_TOP_RIGHT
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	var slot: float = -321.0 if _main.get_node("TopBar").has_node("FullscreenBtn") else -249.0
	btn.offset_left = slot
	btn.offset_right = slot + 60.0
	btn.offset_top = 12.0
	btn.offset_bottom = 72.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = _main.restart_btn.get_theme_stylebox("normal" if st == "focus" else st)
		if sb != null:
			btn.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, Color("#2a2140"))
	btn.add_theme_font_size_override("font_size", 28)
	btn.text = "🔇" if _main.sfx.muted else "🔊"
	btn.pressed.connect(func():
		_main.sfx.set_muted(not _main.sfx.muted)
		btn.text = "🔇" if _main.sfx.muted else "🔊"
		if not _main.sfx.muted:
			_main.sfx.play("coin"))
	_main.get_node("TopBar").add_child(btn)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Android: also lock to landscape (only allowed while fullscreen).
	JavaScriptBridge.eval("try{screen.orientation.lock('landscape').catch(function(){})}catch(e){}")


func _style_sort_button(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameAssets.COLORS["brass"] if active else Color(0, 0, 0, 0)
	sb.content_margin_left = 27.0
	sb.content_margin_right = 27.0
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	var font_col := Color("#2a2140") if active else Color("#a79fc4")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, font_col)

