extends Button

@export var action_name: String = "ui_accept"

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_pressed)
	button_up.connect(_on_released)

func _on_pressed() -> void:
	Input.action_press(action_name)
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_released() -> void:
	Input.action_release(action_name)
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = false
	Input.parse_input_event(ev)
