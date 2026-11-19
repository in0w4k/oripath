extends Enemy

enum State {
	PATROL,
	CHASE,
	WIND_UP,
	COOLDOWN
}

var current_state: State = State.PATROL
var state_timer: float = 0.0
var time_since_saw_player: float = 0.0
var base_sprite_y: float = 0.9

@onready var sprite: Sprite3D = $Sprite3D
@onready var windup_sound: AudioStreamPlayer = get_node_or_null("WindUpSound")
@onready var strike_sound: AudioStreamPlayer = get_node_or_null("StrikeSound")

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	if sprite:
		base_sprite_y = sprite.position.y
	set_state(State.PATROL)

func set_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0
	match current_state:
		State.PATROL:
			if sprite:
				sprite.modulate = Color.WHITE
				sprite.position = Vector3(0.0, base_sprite_y, 0.0)
				sprite.scale = Vector3.ONE
		State.CHASE:
			if sprite:
				sprite.modulate = Color(1.0, 0.82, 0.82, 1.0)
				sprite.position.x = 0.0
				sprite.scale = Vector3.ONE
		State.WIND_UP:
			if sprite:
				sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
			if windup_sound:
				windup_sound.play()
		State.COOLDOWN:
			if sprite:
				sprite.modulate = Color(0.55, 0.65, 0.85, 1.0)
				sprite.position.x = 0.0

func apply_effect(_target: Node3D) -> void:
	if current_state == State.PATROL or current_state == State.CHASE:
		set_state(State.WIND_UP)

func can_see_player() -> bool:
	if not is_instance_valid(player) or not stats:
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > stats.sight_range:
		return false

	if dist > stats.close_sense_range and facing_dir.length_squared() > 0.001:
		var dir_norm := to_player.normalized()
		var cos_half_fov := cos(deg_to_rad(stats.sight_fov_deg * 0.5))
		if facing_dir.normalized().dot(dir_norm) < cos_half_fov:
			return false

	return has_line_of_sight(player, stats.sight_range)

func _physics_process(delta: float) -> void:
	if not stats:
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
			if sprite:
				sprite.scale = sprite.scale.lerp(Vector3.ONE, delta * 10.0)
				sprite.position.y = lerpf(sprite.position.y, base_sprite_y, delta * 10.0)
			move_along_waypoints(stats.patrol_speed, delta)
			if can_see_player():
				time_since_saw_player = 0.0
				set_state(State.CHASE)

		State.CHASE:
			if sprite:
				sprite.scale = sprite.scale.lerp(Vector3.ONE, delta * 10.0)
				sprite.position.y = base_sprite_y + absf(sin(state_timer * 10.0)) * 0.08
			if has_line_of_sight(player, stats.sight_range):
				time_since_saw_player = 0.0
			else:
				time_since_saw_player += delta

			if time_since_saw_player >= stats.lose_sight_time:
				set_state(State.PATROL)
				return

			if dist_to_player <= stats.attack_range and has_line_of_sight(player, stats.attack_range + 0.5):
				set_state(State.WIND_UP)
				return

			var chase_dir := player.global_position - global_position
			chase_dir.y = 0.0
			move_with_wall_avoidance(chase_dir, stats.chase_speed, delta)

		State.WIND_UP:
			var lunge_dir := player.global_position - global_position
			lunge_dir.y = 0.0
			if dist_to_player > 0.9:
				move_with_wall_avoidance(lunge_dir, stats.lunge_speed, delta)
			if sprite:
				var progress := clampf(state_timer / maxf(stats.wind_up_time, 0.01), 0.0, 1.0)
				sprite.scale = Vector3(
					lerpf(1.0, 0.82, progress),
					lerpf(1.0, 1.28, progress),
					1.0
				)
				sprite.position.y = base_sprite_y + 0.16 * progress
				sprite.position.x = sin(state_timer * 50.0) * 0.06
			if state_timer >= stats.wind_up_time:
				_perform_strike()
				set_state(State.COOLDOWN)

		State.COOLDOWN:
			if sprite:
				sprite.scale = sprite.scale.lerp(Vector3.ONE, delta * 8.0)
				sprite.position.y = lerpf(sprite.position.y, base_sprite_y, delta * 8.0)
			if state_timer >= stats.cooldown_time:
				if has_line_of_sight(player, stats.sight_range):
					set_state(State.CHASE)
				else:
					set_state(State.PATROL)

func _perform_strike() -> void:
	if sprite:
		sprite.position = Vector3(0.0, base_sprite_y - 0.12, 0.0)
		sprite.scale = Vector3(1.42, 0.76, 1.0)
		sprite.modulate = Color(1.0, 0.1, 0.1, 1.0)
	if strike_sound:
		strike_sound.play()

	if is_instance_valid(player) and stats:
		var final_dist := Vector2(
			player.global_position.x - global_position.x,
			player.global_position.z - global_position.z
		).length()
		if final_dist <= stats.attack_hit_range and has_line_of_sight(player, stats.attack_hit_range + 0.5):
			deal_damage(player)
