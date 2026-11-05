extends Area3D

@export var player_spawn_position: Vector3 = Vector3(0, 1.5, 0)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("respawn"):
		body.respawn()

	elif body.is_in_group("player") or body is CharacterBody3D:
		body.velocity = Vector3.ZERO
		body.global_position = player_spawn_position
