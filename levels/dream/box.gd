extends RigidBody3D

var start_position: Vector3
var is_respawning: bool = false

func _ready() -> void:
	start_position = global_position

func respawn() -> void:
	if is_respawning:
		return
	is_respawning = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = start_position

	await get_tree().physics_frame
	await get_tree().physics_frame

	global_position = start_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	is_respawning = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_box") and not event.is_echo():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var my_dist = global_position.distance_to(player.global_position)
			
			var is_closest = true
			for other in get_tree().get_nodes_in_group("boxes"):
				if other != self and is_instance_valid(other):
					if other.global_position.distance_to(player.global_position) < my_dist:
						is_closest = false
						break
			
			if is_closest and my_dist < 10.0:
				respawn()