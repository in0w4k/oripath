extends Node3D

@onready var timer: Timer = $Timer

var pickup_timer: Timer
var player: Node3D
var level_data: LevelData
var is_spawning: bool = false
var elapsed_time: float = 0.0
var pending_portals: Array[Node3D] = []
var pending_counts: Dictionary = {"nurse": 0, "orderly": 0, "snowman": 0}
var pending_total: int = 0

const PATROL_ROUTES: Array = [
	[Vector3(-10.0, 0.0, -10.0), Vector3(10.0, 0.0, -10.0), Vector3(10.0, 0.0, 10.0), Vector3(-10.0, 0.0, 10.0)],
	[Vector3(-10.0, 0.0, 10.0), Vector3(10.0, 0.0, 10.0), Vector3(10.0, 0.0, -10.0), Vector3(-10.0, 0.0, -10.0)],
	[Vector3(0.0, 0.0, -8.5), Vector3(3.2, 0.0, -3.2), Vector3(8.5, 0.0, 0.0), Vector3(3.2, 0.0, 3.2), Vector3(0.0, 0.0, 8.5), Vector3(-3.2, 0.0, 3.2), Vector3(-8.5, 0.0, 0.0), Vector3(-3.2, 0.0, -3.2)],
	[Vector3(0.0, 0.0, -8.5), Vector3(-3.2, 0.0, -3.2), Vector3(-8.5, 0.0, 0.0), Vector3(-3.2, 0.0, 3.2), Vector3(0.0, 0.0, 8.5), Vector3(3.2, 0.0, 3.2), Vector3(8.5, 0.0, 0.0), Vector3(3.2, 0.0, -3.2)]
]

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	timer.one_shot = true
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	pickup_timer = Timer.new()
	pickup_timer.name = "PickupTimer"
	pickup_timer.timeout.connect(_on_pickup_timer_timeout)
	add_child(pickup_timer)

func configure_from_level(data: LevelData) -> void:
	stop_spawning()
	level_data = data
	if not level_data:
		return
	elapsed_time = 0.0
	is_spawning = true

	var wave := _get_active_wave()
	timer.wait_time = wave.spawn_interval if wave else 3.5
	timer.start()

	if pickup_timer:
		pickup_timer.wait_time = maxf(1.0, level_data.pickup_interval)
		pickup_timer.start()

func _process(delta: float) -> void:
	if is_spawning:
		elapsed_time += delta

func stop_spawning() -> void:
	is_spawning = false
	if timer:
		timer.stop()
	if pickup_timer:
		pickup_timer.stop()
	for p in pending_portals:
		if is_instance_valid(p):
			p.queue_free()
	pending_portals.clear()
	pending_total = 0
	pending_counts = {"nurse": 0, "orderly": 0, "snowman": 0}

func _get_active_wave() -> WaveData:
	if not level_data or level_data.waves.is_empty():
		return null
	var chosen: WaveData = level_data.waves[0]
	for w in level_data.waves:
		if w and elapsed_time >= w.start_time and w.start_time >= chosen.start_time:
			chosen = w
	return chosen

func _classify_path(path_str: String) -> String:
	var low := path_str.to_lower()
	if "nurse" in low:
		return "nurse"
	if "orderly" in low:
		return "orderly"
	if "snowman" in low:
		return "snowman"
	return "other"

func _get_active_enemy_counts() -> Dictionary:
	var counts: Dictionary = {
		"nurse": int(pending_counts.get("nurse", 0)),
		"orderly": int(pending_counts.get("orderly", 0)),
		"snowman": int(pending_counts.get("snowman", 0)),
		"total": pending_total
	}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		counts["total"] = int(counts["total"]) + 1
		var scr := e.get_script() as Script
		if scr:
			var key := _classify_path(scr.resource_path)
			if key in counts:
				counts[key] = int(counts[key]) + 1
	return counts

func _get_type_cap(wave: WaveData, type_key: String) -> int:
	if not wave:
		return 2
	match type_key:
		"nurse":
			return wave.nurse_cap
		"orderly":
			return wave.orderly_cap
		"snowman":
			return wave.snowman_cap
		_:
			return 2

func _pick_balanced_enemy_entry() -> Dictionary:
	if not level_data or level_data.enemy_scenes.is_empty():
		return {}
	var wave := _get_active_wave()
	var cap_total := wave.max_active_enemies if wave else 4
	var counts := _get_active_enemy_counts()
	if int(counts["total"]) >= cap_total:
		return {}

	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	for scene in level_data.enemy_scenes:
		if not scene:
			continue
		var key := _classify_path(scene.resource_path)
		var cur := int(counts.get(key, 0))
		var cap := _get_type_cap(wave, key)
		if cur >= cap:
			continue
		var w := 1.0
		if cur == 0:
			w = 2.6
		elif cur == 1:
			w = 1.2
		else:
			w = 0.65
		candidates.append({"scene": scene, "type": key})
		weights.append(w)

	if candidates.is_empty():
		return {}

	var total_w := 0.0
	for w in weights:
		total_w += w
	var roll := randf() * total_w
	var acc := 0.0
	for i in range(candidates.size()):
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[0]

func _on_timer_timeout() -> void:
	if not is_spawning or not level_data:
		return
	var entry := _pick_balanced_enemy_entry()
	if not entry.is_empty():
		var spawn_pos := _pick_enemy_spawn_pos()
		if spawn_pos != Vector3.INF:
			_begin_enemy_telegraph(entry["scene"] as PackedScene, spawn_pos, String(entry["type"]))
	if is_spawning and timer:
		var wave := _get_active_wave()
		timer.wait_time = wave.spawn_interval if wave else 3.5
		timer.start()

func _is_spot_clear(pos: Vector3) -> bool:
	var spacing := level_data.min_entity_spacing if level_data else 2.8
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Node3D:
			if (e as Node3D).global_position.distance_to(pos) < spacing:
				return false
	for p in pending_portals:
		if is_instance_valid(p) and p.global_position.distance_to(pos) < spacing:
			return false
	return true

func _pick_enemy_spawn_pos() -> Vector3:
	if not level_data or level_data.enemy_spawn_points.is_empty():
		return Vector3.INF
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	var min_dist := level_data.min_enemy_player_dist
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var cam := player.get_node_or_null("Camera3D") as Camera3D if is_instance_valid(player) else null
	var fwd3 := -cam.global_transform.basis.z if cam else (-player.global_transform.basis.z if is_instance_valid(player) else Vector3.FORWARD)
	var flat_fwd := Vector2(fwd3.x, fwd3.z)
	if flat_fwd.length() > 0.01:
		flat_fwd = flat_fwd.normalized()

	var scored: Array[Dictionary] = []
	for pt in level_data.enemy_spawn_points:
		var dist := Vector2(pt.x - player_pos.x, pt.z - player_pos.z).length()
		if is_instance_valid(player) and dist < min_dist:
			continue
		if not _is_spot_clear(pt):
			continue
		var score := minf(dist, 16.0) * 0.12 + randf_range(0.0, 0.8)
		if is_instance_valid(player) and dist > 0.1:
			var dir_to_pt := Vector2(pt.x - player_pos.x, pt.z - player_pos.z).normalized()
			var dot := flat_fwd.dot(dir_to_pt)
			if dot < 0.35:
				score += 3.0
			elif dot < 0.65:
				score += 1.2
		scored.append({"pos": pt, "score": score})

	if scored.is_empty():
		return Vector3.INF

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var top_count := mini(3, scored.size())
	return scored[randi() % top_count]["pos"] as Vector3

func _begin_enemy_telegraph(scene: PackedScene, spawn_pos: Vector3, type_key: String) -> void:
	pending_total += 1
	pending_counts[type_key] = int(pending_counts.get(type_key, 0)) + 1

	var telegraph_time := level_data.telegraph_duration if level_data else 0.85
	var portal := Node3D.new()
	portal.name = "SpawnPortal"
	portal.position = spawn_pos

	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.85
	disc_mesh.bottom_radius = 0.85
	disc_mesh.height = 0.04
	disc.mesh = disc_mesh
	disc.position.y = 0.03
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color = Color(0.04, 0.04, 0.04, 0.88)
	disc.material_override = disc_mat
	portal.add_child(disc)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.72
	ring_mesh.outer_radius = 0.88
	ring.mesh = ring_mesh
	ring.position.y = 0.06
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.9)
	ring.material_override = ring_mat
	portal.add_child(ring)

	var wisp := MeshInstance3D.new()
	var wisp_mesh := CylinderMesh.new()
	wisp_mesh.top_radius = 0.18
	wisp_mesh.bottom_radius = 0.55
	wisp_mesh.height = 2.4
	wisp.mesh = wisp_mesh
	wisp.position.y = 1.2
	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.albedo_color = Color(0.88, 0.88, 0.88, 0.25)
	wisp.material_override = wisp_mat
	portal.add_child(wisp)

	var cue := AudioStreamPlayer3D.new()
	cue.stream = preload("res://assets/audios/impact.wav")
	cue.volume_db = -12.0
	cue.pitch_scale = 0.65
	cue.max_distance = 22.0
	portal.add_child(cue)

	portal.scale = Vector3(0.2, 1.0, 0.2)
	add_child(portal)
	portal.global_position = spawn_pos
	pending_portals.append(portal)
	cue.play()

	var tw := portal.create_tween()
	tw.tween_property(portal, "scale", Vector3(1.1, 1.0, 1.1), telegraph_time * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(portal, "scale", Vector3(0.9, 1.0, 0.9), telegraph_time * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish_enemy_spawn.bind(portal, scene, spawn_pos, type_key))

func assign_patrol_route(enemy_node: Node, spawn_pos: Vector3) -> void:
	if not (enemy_node is Enemy):
		return
	var e := enemy_node as Enemy
	var raw_route: Array = PATROL_ROUTES[randi() % PATROL_ROUTES.size()]
	var typed_route: Array[Vector3] = []
	for pt in raw_route:
		typed_route.append(pt as Vector3)
	e.patrol_waypoints = typed_route
	var best_idx := 0
	var best_dist := INF
	for i in range(typed_route.size()):
		var d := spawn_pos.distance_to(typed_route[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	e.current_waypoint_idx = best_idx

func _finish_enemy_spawn(portal: Node3D, scene: PackedScene, spawn_pos: Vector3, type_key: String) -> void:
	pending_total = maxi(0, pending_total - 1)
	pending_counts[type_key] = maxi(0, int(pending_counts.get(type_key, 0)) - 1)
	pending_portals.erase(portal)

	if not is_spawning or not is_inside_tree() or not scene:
		if is_instance_valid(portal):
			portal.queue_free()
		return

	var instance := scene.instantiate()
	assign_patrol_route(instance, spawn_pos)
	if instance is Node3D:
		var node3d := instance as Node3D
		node3d.position = spawn_pos
		node3d.scale = Vector3(0.2, 0.2, 0.2)
	add_child(instance)
	if instance is Node3D:
		var node3d := instance as Node3D
		node3d.global_position = spawn_pos
		var spawn_tw := node3d.create_tween()
		spawn_tw.tween_property(node3d, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_instance_valid(portal):
		var fade_tw := portal.create_tween()
		fade_tw.tween_property(portal, "scale", Vector3(0.05, 0.2, 0.05), 0.2)
		fade_tw.tween_callback(portal.queue_free)

func _on_pickup_timer_timeout() -> void:
	if not is_spawning or not level_data or level_data.pickup_scenes.is_empty():
		return
	var active_pickups := get_tree().get_nodes_in_group("chapter4_pickups")
	if active_pickups.size() >= level_data.max_active_pickups:
		return

	var scene := _pick_needed_pickup_scene()
	if not scene:
		return
	var pos := _pick_pickup_spawn_pos(active_pickups)
	if pos == Vector3.INF:
		return

	var pickup := scene.instantiate()
	if pickup is Node3D:
		var p3 := pickup as Node3D
		p3.position = pos
		p3.scale = Vector3(0.2, 0.2, 0.2)
	add_child(pickup)
	if pickup is Node3D:
		var p3 := pickup as Node3D
		p3.global_position = pos
		var tw := p3.create_tween()
		tw.tween_property(p3, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pick_needed_pickup_scene() -> PackedScene:
	var scenes := level_data.pickup_scenes
	if scenes.size() < 2:
		return scenes[0] if not scenes.is_empty() else null

	var medkit_scene: PackedScene = null
	var ammo_scene: PackedScene = null
	for s in scenes:
		if not s:
			continue
		var low := s.resource_path.to_lower()
		if "medkit" in low:
			medkit_scene = s
		elif "ammo" in low:
			ammo_scene = s

	if not medkit_scene or not ammo_scene:
		return scenes.pick_random()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var health := player.get_node_or_null("Health")
		var weapon := player.get_node_or_null("Weapon")
		if health and "current_health" in health and int(health.current_health) <= 1:
			return medkit_scene if randf() < 0.72 else ammo_scene
		if weapon and "current_ammo" in weapon and "reserve_ammo" in weapon:
			if int(weapon.current_ammo) + int(weapon.reserve_ammo) <= 8:
				return ammo_scene if randf() < 0.75 else medkit_scene

	return medkit_scene if randf() < 0.5 else ammo_scene

func _pick_pickup_spawn_pos(active_pickups: Array) -> Vector3:
	if not level_data or level_data.pickup_spawn_points.is_empty():
		return Vector3.INF
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var min_dist := level_data.min_pickup_player_dist
	var spacing := level_data.min_entity_spacing

	var candidates := level_data.pickup_spawn_points.duplicate()
	candidates.shuffle()
	for pt in candidates:
		if is_instance_valid(player) and Vector2(pt.x - player_pos.x, pt.z - player_pos.z).length() < min_dist:
			continue
		var occupied := false
		for p in active_pickups:
			if is_instance_valid(p) and p is Node3D and (p as Node3D).global_position.distance_to(pt) < spacing:
				occupied = true
				break
		if not occupied:
			return pt
	return Vector3.INF
