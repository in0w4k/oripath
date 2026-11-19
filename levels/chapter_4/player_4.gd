extends CharacterBody3D

@export var stats: PlayerStats

@onready var camera: Camera3D = $Camera3D
@onready var menu: Control = get_node_or_null("CanvasLayer/Menu")

var is_mobile: bool = false
var is_touch_looking: bool = false

func _ready() -> void:
	is_mobile = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if not is_mobile and not get_tree().paused:
		if menu and not menu.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	var mouse_sens := stats.mouse_sensitivity if stats else 0.002
	var touch_sens := stats.touch_look_sensitivity if stats else 0.004

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.2, PI / 2.2)

	elif is_mobile and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var half_width := get_viewport().get_visible_rect().size.x * 0.45
		if event.pressed and event.position.x > half_width:
			is_touch_looking = true
		else:
			is_touch_looking = false

	elif is_mobile and event is InputEventMouseMotion and is_touch_looking:
		rotate_y(-event.relative.x * touch_sens)
		camera.rotate_x(-event.relative.y * touch_sens)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.2, PI / 2.2)

func _physics_process(delta: float) -> void:
	var move_speed := stats.move_speed if stats else 5.2
	var jump_vel := stats.jump_velocity if stats else 4.5

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_vel

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()
