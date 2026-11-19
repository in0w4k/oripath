extends Area3D

@export_flags_3d_physics var obstacle_mask: int = 1

var speed: float = 16.0
var damage: int = 1
var hit_radius: float = 0.85
var max_lifetime: float = 4.0
var direction: Vector3 = Vector3.FORWARD
var life_timer: float = 0.0
var player: Node3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

func setup(dir: Vector3, proj_speed: float, proj_damage: int, proj_hit_radius: float = 0.85, proj_lifetime: float = 4.0) -> void:
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
	speed = proj_speed
	damage = proj_damage
	hit_radius = proj_hit_radius
	max_lifetime = proj_lifetime

func _physics_process(delta: float) -> void:
	life_timer += delta
	if life_timer >= max_lifetime:
		queue_free()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_instance_valid(player):
		var flat_dist := Vector2(
			player.global_position.x - global_position.x,
			player.global_position.z - global_position.z
		).length()
		if flat_dist <= hit_radius and absf(player.global_position.y - global_position.y) <= 1.6:
			_damage_player(player)
			queue_free()
			return

	var next_pos := global_position + direction * speed * delta

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, obstacle_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider and collider is Node3D:
			var node := collider as Node3D
			if node.is_in_group("player"):
				_damage_player(node)
				queue_free()
				return
			elif node.name != "Floor" and node.name != "Ceiling":
				queue_free()
				return

	global_position = next_pos

	if is_instance_valid(player):
		var flat_dist_after := Vector2(
			player.global_position.x - global_position.x,
			player.global_position.z - global_position.z
		).length()
		if flat_dist_after <= hit_radius and absf(player.global_position.y - global_position.y) <= 1.6:
			_damage_player(player)
			queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_damage_player(body)
		queue_free()
	elif not body.is_in_group("enemies") and body.name != "Floor" and body.name != "Ceiling":
		queue_free()

func _damage_player(target: Node3D) -> void:
	var target_health := target.get_node_or_null("Health")
	if target_health and target_health.has_method("take_damage"):
		target_health.take_damage(damage)
