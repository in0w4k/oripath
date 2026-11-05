extends Control

@export var max_radius: float = 95.0
@export var knob_radius: float = 44.0
@export var deadzone: float = 0.12

var is_dragging: bool = false
var active_finger: int = -1
var knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(280, 280)

func _process(_delta: float) -> void:
	if not is_dragging:
		var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var target_offset := input_vec * max_radius
		if (knob_offset - target_offset).length_squared() > 0.01:
			knob_offset = target_offset
			queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_finger == -1:
			active_finger = event.index
			is_dragging = true
			_update_stick(event.position)
			accept_event()
		elif not event.pressed and event.index == active_finger:
			_release_stick()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_finger:
		_update_stick(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			_update_stick(event.position)
		else:
			_release_stick()
		accept_event()
	elif event is InputEventMouseMotion and is_dragging and active_finger == -1:
		_update_stick(event.position)
		accept_event()

func _update_stick(local_pos: Vector2) -> void:
	var center := size * 0.5
	var delta := (local_pos - center).limit_length(max_radius)
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
	active_finger = -1
	knob_offset = Vector2.ZERO
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_dragging:
			_release_stick()

func _draw() -> void:
	var center := size * 0.5
	var base_r := max_radius + 24.0

	draw_circle(center, base_r, Color(0.05, 0.05, 0.05, 0.42))
	draw_arc(center, base_r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.85), 4.0, true)

	var knob_pos := center + knob_offset
	var knob_col := Color(1.0, 1.0, 1.0, 0.96) if is_dragging else Color(0.88, 0.88, 0.88, 0.85)
	draw_circle(knob_pos, knob_radius, knob_col)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 48, Color(0.05, 0.05, 0.05, 0.95), 4.0, true)
