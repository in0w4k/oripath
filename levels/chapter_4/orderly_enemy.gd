extends Enemy

enum State {
	PATROL,
	CHASE,
	WIND_UP,
	CHARGE_DASH,
	STUNNED
}

@export_group("Orderly Sprites")
@export var tex_normal: Texture2D
@export var tex_inflated: Texture2D
@export var tex_boom: Texture2D

var current_state: State = State.PATROL
var state_timer: float = 0.0
var dash_dir: Vector3 = Vector3.FORWARD
var is_exploding: bool = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var preboom_sound: AudioStreamPlayer = get_node_or_null("PreBoomSound")
@onready var boom_sound: AudioStreamPlayer = get_node_or_null("BoomSound")
@onready var stun_sound: AudioStreamPlayer = get_node_or_null("StunSound")

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	if sprite and not tex_normal:
		tex_normal = sprite.texture
	set_state(State.PATROL)

func set_state(new_state: State) -> void:
	if is_exploding:
		return
	current_state = new_state
	state_timer = 0.0
	match current_state:
		State.PATROL:
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.modulate = Color.WHITE
				sprite.position.x = 0.0
				sprite.scale = Vector3.ONE
		State.CHASE:
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.modulate = Color(1.0, 0.85, 0.75, 1.0)
				sprite.position.x = 0.0
				sprite.scale = Vector3.ONE
		State.WIND_UP:
			if sprite:
				if tex_inflated:
					sprite.texture = tex_inflated
				sprite.modulate = Color(1.0, 0.55, 0.35, 1.0)
			if preboom_sound:
				preboom_sound.play()
			_lock_dash_direction()
		State.CHARGE_DASH:
			if sprite:
				sprite.position.x = 0.0
				sprite.scale = Vector3(1.15, 1.15, 1.0)
				sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		State.STUNNED:
			if preboom_sound and preboom_sound.playing:
				preboom_sound.stop()
			if stun_sound:
				stun_sound.play()
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.position.x = 0.0
				sprite.scale = Vector3(1.12, 0.85, 1.0)
				sprite.modulate = Color(0.65, 0.75, 1.0, 1.0)

func _lock_dash_direction() -> void:
	if is_instance_valid(player):
		var dir := player.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dash_dir = dir.normalized()
			facing_dir = dash_dir

func apply_effect(_target: Node3D) -> void:
	if is_exploding:
		return
	if current_state == State.CHARGE_DASH:
		_explode()
	elif current_state == State.PATROL or current_state == State.CHASE:
		set_state(State.WIND_UP)

func _physics_process(delta: float) -> void:
	if is_exploding or not stats:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return

	state_timer += delta
	var dist_to_player := Vector2(
		player.global_position.x - global_position.x,
		player.global_position.z - global_position.z
	).length()

	match current_state:
		State.PATROL:
			move_along_waypoints(stats.patrol_speed, delta)
			if is_visible_or_close_to_player(stats.sight_range):
				set_state(State.CHASE)

		State.CHASE:
			if dist_to_player <= stats.charge_trigger_range and has_line_of_sight(player, stats.charge_trigger_range + 0.5):
				set_state(State.WIND_UP)
				return
			if state_timer >= stats.lose_sight_time and not has_line_of_sight(player, stats.sight_range):
				set_state(State.PATROL)
				return
			var chase_dir := player.global_position - global_position
			chase_dir.y = 0.0
			move_with_wall_avoidance(chase_dir, stats.chase_speed, delta)

		State.WIND_UP:
			if state_timer < stats.fuse_time * 0.7:
				_lock_dash_direction()
			if sprite:
				sprite.position.x = sin(state_timer * 55.0) * 0.08
				var swell := 1.0 + 0.2 * clampf(state_timer / maxf(stats.fuse_time, 0.01), 0.0, 1.0)
				sprite.scale = Vector3(swell, swell, 1.0)
			if state_timer >= stats.fuse_time:
				set_state(State.CHARGE_DASH)

		State.CHARGE_DASH:
			if dist_to_player <= stats.explode_trigger_dist and has_line_of_sight(player, stats.blast_radius):
				_explode()
				return

			if _step_dash(delta):
				set_state(State.STUNNED)
				return

			var new_dist := Vector2(
				player.global_position.x - global_position.x,
				player.global_position.z - global_position.z
			).length()
			if new_dist <= stats.explode_trigger_dist and has_line_of_sight(player, stats.blast_radius):
				_explode()
				return

			if state_timer >= stats.max_dash_time:
				set_state(State.STUNNED)

		State.STUNNED:
			if sprite:
				sprite.position.x = sin(state_timer * 20.0) * 0.05
			if state_timer >= stats.stun_duration:
				if has_line_of_sight(player, stats.sight_range):
					set_state(State.CHASE)
				else:
					set_state(State.PATROL)

func _step_dash(delta: float) -> bool:
	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 0.9, 0.0)
	var step_dist := stats.dash_speed * delta
	var limit := get_arena_limit()

	var exclude_rids: Array[RID] = [self.get_rid()]
	if is_instance_valid(player) and player is CollisionObject3D:
		exclude_rids.append((player as CollisionObject3D).get_rid())

	var query := PhysicsRayQueryParameters3D.create(origin, origin + dash_dir * (step_dist + 0.55), obstacle_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude_rids

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return true

	var next_pos := global_position + dash_dir * step_dist
	if absf(next_pos.x) > limit or absf(next_pos.z) > limit:
		return true

	global_position = next_pos
	return false

func _explode() -> void:
	if is_exploding:
		return
	is_exploding = true

	if preboom_sound and preboom_sound.playing:
		preboom_sound.stop()
	if boom_sound:
		boom_sound.play()

	if sprite:
		if tex_boom:
			sprite.texture = tex_boom
		sprite.modulate = Color.WHITE
		sprite.position.x = 0.0
		sprite.scale = Vector3(1.25, 1.25, 1.0)

	if is_instance_valid(player) and stats:
		var dist := Vector2(
			player.global_position.x - global_position.x,
			player.global_position.z - global_position.z
		).length()
		if dist <= stats.blast_radius and has_line_of_sight(player, stats.blast_radius + 0.5):
			deal_damage(player)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	await get_tree().create_timer(0.45).timeout
	die(false)
