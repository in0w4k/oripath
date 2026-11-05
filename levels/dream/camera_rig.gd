extends Node3D

@export var target_player: Node3D

@onready var camera: Camera3D = $Camera3D

var is_rotating = false
var shake_intensity: float = 0.0

func _ready() -> void:
	rotation.y = deg_to_rad(45)
	GameManager.camera_shake.connect(start_shake)

func _process(delta: float) -> void:
	if target_player:
		global_position.x = lerp(global_position.x, target_player.global_position.x, delta * 5.0)
		global_position.z = lerp(global_position.z, target_player.global_position.z, delta * 5.0)
		global_position.y = lerp(global_position.y, target_player.global_position.y, delta * 1.5)

	if camera:
		if shake_intensity > 0.01:
			camera.h_offset = randf_range(-shake_intensity, shake_intensity)
			camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		else:
			camera.h_offset = 0.0
			camera.v_offset = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if is_rotating:
		return
	
	if event.is_action_pressed("camera_rotate_left"):
		rotate_camera(-90)
	elif event.is_action_pressed("camera_rotate_right"):
		rotate_camera(90)

func rotate_camera(angle: float) -> void:
	is_rotating = true
	var start_y = rotation.y
	var target_y = start_y + deg_to_rad(angle)

	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", target_y, 0.4)
	tween.finished.connect(func(): 
		rotation.y = wrapf(rotation.y, -PI, PI)
		is_rotating = false
	)

func start_shake(intensity: float = 0.5, duration: float = 0.4) -> void:
	shake_intensity = intensity
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "shake_intensity", 0.0, duration)