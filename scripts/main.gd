extends Control

@onready var button: Button = $Button
@onready var status: Label = $Status

var click_count: int = 0

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	click_count += 1
	status.text = "Clicked: %d times! (GDScript working perfectly)" % click_count
