extends CharacterBody3D

const WALK_SPEED = 4.2
const RUN_SPEED = 7.4
const JUMP_VELOCITY = 6.5
const TURN_SPEED = 14.0

@onready var model_root: Node3D = $ModelRoot
@onready var base_model: Node3D = $"ModelRoot/base model"
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var raycast: RayCast3D = $RayCast3D
@onready var shadow: Sprite3D = $Shadow

var is_invulnerable: bool = false
var can_move: bool = true

func _ready() -> void:
	if anim and anim.has_animation("idle_normal"):
		anim.play("idle_normal")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var is_sprint: bool = Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
	var current_speed: float = RUN_SPEED if is_sprint else WALK_SPEED

	if not can_move:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		move_and_slide()
		update_animation(false, delta)
		return

	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY
	elif not is_on_floor() and Input.is_action_just_released("ui_accept") and velocity.y > 3.2:
		velocity.y *= 0.65

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0.01:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * (current_speed * 0.7)
		if model_root:
			var target_angle := atan2(velocity.x, velocity.z)
			model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	update_animation(is_sprint, delta)

	if raycast.is_colliding():
		shadow.visible = true
		shadow.global_position = raycast.get_collision_point() + Vector3(0, 0.02, 0)
	else:
		shadow.visible = false

func update_animation(is_sprint: bool, delta: float) -> void:
	if not anim:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var on_floor: bool = is_on_floor()

	var target_anim := "idle_normal"
	if not on_floor:
		target_anim = "jump"
	elif speed > 0.1:
		target_anim = "walk_normal"

	if anim.current_animation != target_anim and anim.has_animation(target_anim):
		anim.speed_scale = 1.0
		anim.play(target_anim, 0.12)

	if target_anim == "jump":
		if anim.current_animation == "jump" and anim.current_animation_position >= 0.25:
			anim.speed_scale = 0.0
		else:
			anim.speed_scale = 1.0
	elif target_anim == "walk_normal":
		anim.speed_scale = 1.85 if is_sprint else 1.15
	else:
		anim.speed_scale = 1.0

	if base_model:
		var target_lean := 0.22 if (on_floor and speed > 0.1 and is_sprint) else 0.0
		base_model.rotation.x = lerpf(base_model.rotation.x, target_lean, 10.0 * delta)

func start_invulnerability(duration: float = 1.0) -> void:
	if is_invulnerable:
		return
	is_invulnerable = true
	var steps := maxi(1, int(duration / 0.15))
	for i in steps:
		if not is_inside_tree():
			return
		if model_root:
			model_root.visible = (i % 2 == 0)
		await get_tree().create_timer(0.15, false).timeout
	if is_instance_valid(model_root):
		model_root.visible = true
	is_invulnerable = false

func respawn(spawn_pos: Vector3 = Vector3(0, 1, 0)) -> void:
	velocity = Vector3.ZERO
	global_position = spawn_pos
	start_invulnerability(1.0)
