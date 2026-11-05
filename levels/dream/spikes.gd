extends Area3D

@export var bounce_force: float = 6.0
@onready var hurt_sound: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.get("is_invulnerable") == true:
			return

		if hurt_sound:
			hurt_sound.play()

		GameManager.take_damage(1)
		
		if body is CharacterBody3D:
			var push_dir = (body.global_position - global_position).normalized()
			push_dir.y = 0.5
			if body.has_method("apply_knockback"):
				body.apply_knockback(push_dir.normalized() * bounce_force)
			else:
				body.velocity = push_dir.normalized() * bounce_force

			if body.has_method("start_invulnerability"):
				body.start_invulnerability(1.0)