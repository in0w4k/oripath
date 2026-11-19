class_name Enemy
extends Hazard

@export_group("Navigation")
@export var patrol_waypoints: Array[Vector3] = []
@export_flags_3d_physics var obstacle_mask: int = 1

var player: Node3D
var current_waypoint_idx: int = 0
var facing_dir: Vector3 = Vector3.FORWARD
var avoid_side: float = 1.0
var avoid_timer: float = 0.0

const DEFAULT_RING_WAYPOINTS: Array[Vector3] = [
	Vector3(-8.5, 0.0, -3.5),
	Vector3(0.0, 0.0, -3.5),
	Vector3(8.5, 0.0, -3.5),
	Vector3(3.5, 0.0, 0.0),
	Vector3(8.5, 0.0, 3.5),
	Vector3(0.0, 0.0, 3.5),
	Vector3(-8.5, 0.0, 3.5),
	Vector3(-3.5, 0.0, 0.0)
]

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player")
	avoid_side = 1.0 if randf() > 0.5 else -1.0
	_ensure_default_waypoints()

func get_patrol_speed() -> float:
	return stats.patrol_speed if stats else 2.8

func get_waypoint_reach_dist() -> float:
	return stats.waypoint_reach_dist if stats else 0.9

func get_arena_limit() -> float:
	return stats.arena_limit if stats else 13.5

func get_body_radius() -> float:
	return stats.body_radius if stats else 0.65

func _ensure_default_waypoints() -> void:
	if not patrol_waypoints.is_empty():
		return
	for wp in DEFAULT_RING_WAYPOINTS:
		patrol_waypoints.append(wp)
	var best_idx := 0
	var best_dist := INF
	for i in range(patrol_waypoints.size()):
		var d := global_position.distance_to(patrol_waypoints[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	current_waypoint_idx = best_idx

func has_line_of_sight(target: Node3D, max_dist: float) -> bool:
	if not is_instance_valid(target):
		return false
	var from_pos := global_position + Vector3(0.0, 1.0, 0.0)
	var to_pos := target.global_position + Vector3(0.0, 0.5, 0.0)
	var flat_dist := Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()
	if flat_dist > max_dist:
		return false

	var space_state := get_world_3d().direct_space_state
	var exclude_rids: Array[RID] = [self.get_rid()]
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())

	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos, obstacle_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude_rids

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == target

func is_visible_or_close_to_player(max_attack_dist: float) -> bool:
	if not is_instance_valid(player):
		return false
	var flat_dist := Vector2(
		player.global_position.x - global_position.x,
		player.global_position.z - global_position.z
	).length()
	if flat_dist > max_attack_dist:
		return false
	return has_line_of_sight(player, max_attack_dist)

func move_along_waypoints(speed_val: float, delta: float) -> void:
	if patrol_waypoints.is_empty():
		return
	var reach_dist := get_waypoint_reach_dist()
	var target_wp := patrol_waypoints[current_waypoint_idx % patrol_waypoints.size()]
	var diff := Vector3(target_wp.x - global_position.x, 0.0, target_wp.z - global_position.z)
	if diff.length() <= reach_dist:
		current_waypoint_idx = (current_waypoint_idx + 1) % patrol_waypoints.size()
		target_wp = patrol_waypoints[current_waypoint_idx]
		diff = Vector3(target_wp.x - global_position.x, 0.0, target_wp.z - global_position.z)

	if diff.length() > 0.05:
		move_with_wall_avoidance(diff.normalized(), speed_val, delta)

func move_with_wall_avoidance(desired_dir: Vector3, speed_val: float, delta: float) -> bool:
	if avoid_timer > 0.0:
		avoid_timer -= delta

	var flat_dir := Vector3(desired_dir.x, 0.0, desired_dir.z).normalized()
	if flat_dir.length_squared() < 0.001:
		return false

	var radius := get_body_radius()
	var limit := get_arena_limit()
	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 0.9, 0.0)
	var lookahead := maxf(1.25, speed_val * delta + radius + 0.45)

	var exclude_rids: Array[RID] = [self.get_rid()]
	if is_instance_valid(player) and player is CollisionObject3D:
		exclude_rids.append((player as CollisionObject3D).get_rid())

	var direct_query := PhysicsRayQueryParameters3D.create(origin, origin + flat_dir * lookahead, obstacle_mask)
	direct_query.collide_with_bodies = true
	direct_query.collide_with_areas = false
	direct_query.exclude = exclude_rids
	var direct_hit := space_state.intersect_ray(direct_query)

	var move_dir := flat_dir
	if not direct_hit.is_empty():
		var normal: Vector3 = direct_hit.get("normal", Vector3.FORWARD)
		normal.y = 0.0
		if normal.length_squared() > 0.001:
			normal = normal.normalized()
			var tangent_a := Vector3(-normal.z, 0.0, normal.x)
			var tangent_b := -tangent_a
			if avoid_timer <= 0.0:
				avoid_side = 1.0 if flat_dir.dot(tangent_a) >= flat_dir.dot(tangent_b) else -1.0
				avoid_timer = 0.65
			var chosen_tangent := tangent_a if avoid_side > 0.0 else tangent_b
			move_dir = (chosen_tangent + normal * 0.25).normalized()

	var candidate_angles: Array[float] = [
		0.0,
		45.0 * avoid_side,
		-45.0 * avoid_side,
		85.0 * avoid_side,
		-85.0 * avoid_side,
		135.0 * avoid_side,
		-135.0 * avoid_side,
		180.0
	]

	var moved := false
	var step_probe := maxf(0.75, speed_val * delta + radius)
	for deg in candidate_angles:
		var test_dir := move_dir.rotated(Vector3.UP, deg_to_rad(deg))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + test_dir * step_probe, obstacle_mask)
		q.collide_with_bodies = true
		q.collide_with_areas = false
		q.exclude = exclude_rids
		if space_state.intersect_ray(q).is_empty():
			global_position += test_dir * speed_val * delta
			facing_dir = test_dir
			moved = true
			break

	_push_away_from_walls(space_state, exclude_rids, radius)
	global_position.x = clampf(global_position.x, -limit, limit)
	global_position.z = clampf(global_position.z, -limit, limit)
	return moved

func _push_away_from_walls(space_state: PhysicsDirectSpaceState3D, exclude_rids: Array[RID], radius: float) -> void:
	var origin := global_position + Vector3(0.0, 0.9, 0.0)
	var dirs: Array[Vector3] = [
		Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT,
		Vector3(0.707, 0.0, 0.707), Vector3(-0.707, 0.0, 0.707),
		Vector3(0.707, 0.0, -0.707), Vector3(-0.707, 0.0, -0.707)
	]
	for d in dirs:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * radius, obstacle_mask)
		q.collide_with_bodies = true
		q.collide_with_areas = false
		q.exclude = exclude_rids
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", origin + d * radius)
			var dist := Vector2(hit_pos.x - origin.x, hit_pos.z - origin.z).length()
			var push := radius - dist
			if push > 0.0:
				global_position -= d * push
				origin = global_position + Vector3(0.0, 0.9, 0.0)
