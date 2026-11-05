extends Area3D

@export var speed: float = 12.0
@export var direction: float = 1.0
@export var min_x: float = -38.0
@export var max_x: float = 38.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var engine_sound: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var hit_sound: AudioStreamPlayer = $HitSound

const CAR_TEXTURES = [
	preload("res://assets/car1.png"),
	preload("res://assets/car2.png"),
	preload("res://assets/car3.png")
]

var is_stopped: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if engine_sound:
		engine_sound.finished.connect(func():
			if not is_stopped:
				engine_sound.play()
		)
		if not engine_sound.playing:
			engine_sound.play()

	if sprite and CAR_TEXTURES.size() > 0:
		var idx = randi() % CAR_TEXTURES.size()
		if direction < 0:
			idx = (idx + 1) % CAR_TEXTURES.size()
		sprite.texture = CAR_TEXTURES[idx]
		sprite.flip_h = (direction < 0)

func _physics_process(delta: float) -> void:
	global_position.x += direction * speed * delta
	if direction > 0 and global_position.x > max_x:
		global_position.x = min_x
		_change_sprite()
	elif direction < 0 and global_position.x < min_x:
		global_position.x = max_x
		_change_sprite()

func _change_sprite() -> void:
	if sprite and CAR_TEXTURES.size() > 0:
		sprite.texture = CAR_TEXTURES.pick_random()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.get("is_invulnerable") == true:
			return
		
		if hit_sound:
			hit_sound.play()

		GameManager.take_damage(1)
		if body is CharacterBody3D:
			var push_z = 1.0 if body.global_position.z > global_position.z else -1.0
			body.velocity = Vector3(direction * 4.0, 4.0, push_z * 6.0)
			if body.has_method("start_invulnerability"):
				body.start_invulnerability(1.2)

func stop_car() -> void:
	is_stopped = true
	set_physics_process(false)
	if engine_sound:
		engine_sound.stop()
	if hit_sound:
		hit_sound.stop()
