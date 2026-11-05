extends CharacterBody3D

@export_group("Movement")
@export var SPEED = 5.0
@export var jump_height: float = 1.5
@export var turn_speed: float = 14.0

@onready var raycast: RayCast3D = $RayCast3D
@onready var shadow: Sprite3D = $Shadow
@onready var model_root: Node3D = $ModelRoot
@onready var anim: AnimationPlayer = $AnimationPlayer

var JUMP_VELOCITY = 0.0
var camera_node: Node3D = null
var is_invulnerable: bool = false
var knockback_timer: float = 0.0

func _ready() -> void:
	camera_node = get_viewport().get_camera_3d()
	var gravity = get_gravity().length()
	JUMP_VELOCITY = sqrt(2 * gravity * jump_height)
	if anim and anim.has_animation("idle_normal"):
		anim.play("idle_normal")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		_update_animation()
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if not camera_node:
		camera_node = get_viewport().get_camera_3d()

	if camera_node:
		var cam_rot_y = camera_node.global_rotation.y
		var direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, cam_rot_y).normalized()
		
		if direction.length() > 0.01:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			if model_root:
				var target_angle := atan2(velocity.x, velocity.z)
				model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, turn_speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			var push_dir = -collision.get_normal()
			collider.apply_central_impulse(push_dir * 0.4)
		
	if raycast.is_colliding():
		shadow.visible = true
		shadow.global_position = raycast.get_collision_point() + Vector3(0, 0.02, 0)
	else:
		shadow.visible = false

	_update_animation()

func _update_animation() -> void:
	if not anim:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var target_anim := "idle_normal"
	if not is_on_floor():
		target_anim = "jump"
	elif speed > 0.15:
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
		anim.speed_scale = 1.15
	else:
		anim.speed_scale = 1.0

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

func apply_knockback(force: Vector3, duration: float = 0.25) -> void:
	velocity = force
	knockback_timer = duration
