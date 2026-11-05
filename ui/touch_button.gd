extends Control

signal button_pressed

@export var action_name: String = "ui_accept"
@export var button_text: String = "JUMP"
@export var font_size: int = 38
@export var is_square: bool = false

var is_pressed_down: bool = false
var active_finger: int = -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_finger == -1:
			active_finger = event.index
			_press()
			accept_event()
		elif not event.pressed and event.index == active_finger:
			_release()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_finger == -1:
			_press()
		elif not event.pressed and is_pressed_down:
			_release()
		accept_event()

func _press() -> void:
	if is_pressed_down:
		return
	is_pressed_down = true
	queue_redraw()
	if action_name != "":
		Input.action_press(action_name)
		var ev := InputEventAction.new()
		ev.action = action_name
		ev.pressed = true
		Input.parse_input_event(ev)
	button_pressed.emit()

func _release() -> void:
	if not is_pressed_down:
		return
	is_pressed_down = false
	active_finger = -1
	queue_redraw()
	if action_name != "":
		Input.action_release(action_name)
		var ev := InputEventAction.new()
		ev.action = action_name
		ev.pressed = false
		Input.parse_input_event(ev)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_pressed_down:
			_release()

func _draw() -> void:
	var center := size * 0.5
	var bg_col := Color(0.95, 0.95, 0.95, 0.9) if is_pressed_down else Color(0.08, 0.08, 0.08, 0.55)
	var border_col := Color(0.08, 0.08, 0.08, 0.95) if is_pressed_down else Color(1.0, 1.0, 1.0, 0.88)
	var text_col := Color(0.05, 0.05, 0.05, 1.0) if is_pressed_down else Color(1.0, 1.0, 1.0, 1.0)

	if is_square:
		var rect := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg_col
		sb.border_color = border_col
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		draw_style_box(sb, rect)
	else:
		var r := minf(size.x, size.y) * 0.5 - 6.0
		draw_circle(center, r, bg_col)
		draw_arc(center, r, 0.0, TAU, 64, border_col, 4.0, true)

	var font := get_theme_default_font()
	if font and button_text != "":
		var str_size := font.get_string_size(button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var pos := Vector2(center.x - str_size.x * 0.5, center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string(font, pos, button_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
