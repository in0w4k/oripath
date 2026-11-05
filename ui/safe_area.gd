extends MarginContainer

@export var base_padding: int = 28

var _insets := Vector4.ZERO
var _show_notch_overlay := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(update_safe_area)
	if GameManager.has_signal("device_profile_changed"):
		GameManager.device_profile_changed.connect(func(_idx: int): update_safe_area())
	update_safe_area()

func update_safe_area() -> void:
	_insets = Vector4.ZERO
	_show_notch_overlay = false

	var profile: int = GameManager.get("device_profile") if GameManager else 0

	if OS.has_feature("mobile"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var safe_rect := Rect2(DisplayServer.get_display_safe_area())
		if screen_size.x > 0 and screen_size.y > 0:
			var vp_size := get_viewport_rect().size
			var scale_vec := vp_size / screen_size
			_insets = Vector4(
				safe_rect.position.x * scale_vec.x,
				safe_rect.position.y * scale_vec.y,
				(screen_size.x - safe_rect.end.x) * scale_vec.x,
				(screen_size.y - safe_rect.end.y) * scale_vec.y
			)
	elif profile == 1:
		_insets = Vector4(130.0, 0.0, 130.0, 58.0)
		_show_notch_overlay = true

	add_theme_constant_override("margin_left", int(_insets.x) + base_padding)
	add_theme_constant_override("margin_top", int(_insets.y) + base_padding)
	add_theme_constant_override("margin_right", int(_insets.z) + base_padding)
	add_theme_constant_override("margin_bottom", int(_insets.w) + base_padding)
	queue_redraw()

func _draw() -> void:
	if not _show_notch_overlay:
		return

	var notch_h := size.y * 0.36
	var notch_y := (size.y - notch_h) * 0.5
	var notch_w := 58.0
	draw_rect(Rect2(0.0, notch_y, notch_w, notch_h), Color(0.04, 0.04, 0.04, 1.0), true)

	var safe_pos := Vector2(_insets.x, _insets.y)
	var safe_size := Vector2(size.x - _insets.x - _insets.z, size.y - _insets.y - _insets.w)
	draw_rect(Rect2(safe_pos, safe_size), Color(0.96, 0.78, 0.26, 0.85), false, 3.0)
