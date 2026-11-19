extends Control

@export var max_radius: float = 55.0
@export var deadzone: float = 0.12

var is_dragging: bool = false
var knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)

func _process(_delta: float) -> void:
	if not is_dragging:
		var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var target_offset := input_vec * max_radius
		if (knob_offset - target_offset).length_squared() > 0.001:
			knob_offset = target_offset
			queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			_update_stick(event.position)
		else:
			_release_stick()
		accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		_update_stick(event.position)
		accept_event()

func _update_stick(local_pos: Vector2) -> void:
	var center := size * 0.5
	var delta := local_pos - center
	if delta.length() > max_radius:
		delta = delta.normalized() * max_radius
	knob_offset = delta
	queue_redraw()
	var vec := delta / max_radius
	_apply_axis("ui_left", "ui_right", vec.x)
	_apply_axis("ui_up", "ui_down", vec.y)

func _apply_axis(neg_action: String, pos_action: String, val: float) -> void:
	if val < -deadzone:
		Input.action_press(neg_action, clampf(-val, 0.0, 1.0))
		Input.action_release(pos_action)
	elif val > deadzone:
		Input.action_press(pos_action, clampf(val, 0.0, 1.0))
		Input.action_release(neg_action)
	else:
		Input.action_release(neg_action)
		Input.action_release(pos_action)

func _release_stick() -> void:
	is_dragging = false
	knob_offset = Vector2.ZERO
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5

	draw_circle(center, max_radius + 14.0, Color(0.05, 0.05, 0.05, 0.3))
	draw_arc(center, max_radius + 14.0, 0.0, TAU, 48, Color.WHITE, 3.0)

	var knob_pos := center + knob_offset
	draw_circle(knob_pos, 26.0, Color.WHITE if is_dragging else Color(0.85, 0.85, 0.85, 0.9))
	draw_arc(knob_pos, 26.0, 0.0, TAU, 32, Color.BLACK, 3.0)
