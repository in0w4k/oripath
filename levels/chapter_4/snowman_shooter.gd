extends Enemy

enum State {
	PATROL,
	KEEP_DISTANCE,
	AIM,
	COOLDOWN
}

@export_group("Snowman Assets")
@export var projectile_scene: PackedScene
@export var tex_normal: Texture2D
@export var tex_aim: Texture2D

var current_state: State = State.PATROL
var state_timer: float = 0.0
var aim_target_pos: Vector3 = Vector3.ZERO

var aim_beam_mesh: MeshInstance3D

@onready var sprite: Sprite3D = $Sprite3D
@onready var throw_sound: AudioStreamPlayer = get_node_or_null("ThrowSound")

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	if sprite and not tex_normal:
		tex_normal = sprite.texture
	_setup_aim_beam()
	set_state(State.PATROL)

func _setup_aim_beam() -> void:
	aim_beam_mesh = MeshInstance3D.new()
	aim_beam_mesh.name = "AimBeam"
	aim_beam_mesh.top_level = true
	aim_beam_mesh.visible = false

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 1.0
	cyl.radial_segments = 6
	aim_beam_mesh.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.9)
	aim_beam_mesh.material_override = mat
	add_child(aim_beam_mesh)

func set_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0
	_clear_aim_beam()

	match current_state:
		State.PATROL:
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.modulate = Color.WHITE
				sprite.scale = Vector3.ONE
		State.KEEP_DISTANCE:
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.modulate = Color.WHITE
				sprite.scale = Vector3.ONE
		State.AIM:
			if sprite:
				if tex_aim:
					sprite.texture = tex_aim
				sprite.modulate = Color(1.0, 0.65, 0.65, 1.0)
				sprite.scale = Vector3(1.1, 1.1, 1.0)
			if is_instance_valid(player):
				aim_target_pos = Vector3(player.global_position.x, player.global_position.y + 0.2, player.global_position.z)
		State.COOLDOWN:
			if sprite:
				if tex_normal:
					sprite.texture = tex_normal
				sprite.modulate = Color(0.7, 0.82, 1.0, 1.0)
				sprite.scale = Vector3.ONE

func apply_effect(_target: Node3D) -> void:
	if current_state == State.PATROL or current_state == State.KEEP_DISTANCE:
		set_state(State.AIM)

func _physics_process(delta: float) -> void:
	if not stats:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			_clear_aim_beam()
			return

	state_timer += delta
	var to_player := player.global_position - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	var dist := flat_to_player.length()
	var can_see := has_line_of_sight(player, stats.sight_range)

	match current_state:
		State.PATROL:
			move_along_waypoints(stats.patrol_speed, delta)
			if can_see:
				set_state(State.KEEP_DISTANCE)

		State.KEEP_DISTANCE:
			if not can_see:
				if state_timer >= 2.5:
					set_state(State.PATROL)
					return
				move_along_waypoints(stats.reposition_speed, delta)
				return

			if dist < stats.min_preferred_dist:
				move_with_wall_avoidance(-flat_to_player, stats.retreat_speed, delta)
				if state_timer >= 0.45 or dist <= 2.5:
					set_state(State.AIM)
			elif dist > stats.max_preferred_dist:
				move_with_wall_avoidance(flat_to_player, stats.reposition_speed, delta)
			else:
				set_state(State.AIM)

		State.AIM:
			if state_timer < stats.aim_wind_up * stats.aim_track_ratio:
				aim_target_pos = Vector3(player.global_position.x, player.global_position.y + 0.2, player.global_position.z)

			_draw_aim_beam(global_position + Vector3(0.0, 1.05, 0.0), aim_target_pos)

			if state_timer >= stats.aim_wind_up:
				_fire_snowball()
				set_state(State.COOLDOWN)

		State.COOLDOWN:
			if dist < stats.min_preferred_dist:
				move_with_wall_avoidance(-flat_to_player, stats.retreat_speed, delta)
			if state_timer >= stats.cooldown_time:
				if can_see:
					set_state(State.KEEP_DISTANCE)
				else:
					set_state(State.PATROL)

func _draw_aim_beam(from_pos: Vector3, to_pos: Vector3) -> void:
	if not aim_beam_mesh:
		return
	var diff := to_pos - from_pos
	var length := diff.length()
	if length < 0.05:
		aim_beam_mesh.visible = false
		return

	aim_beam_mesh.visible = true
	var mid := from_pos + diff * 0.5
	var dir := diff / length
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var x_axis := up.cross(dir).normalized()
	var z_axis := dir.cross(x_axis).normalized()
	var beam_basis := Basis(x_axis, dir, z_axis)
	beam_basis = beam_basis.scaled(Vector3(1.0, length, 1.0))
	aim_beam_mesh.global_transform = Transform3D(beam_basis, mid)

func _clear_aim_beam() -> void:
	if aim_beam_mesh:
		aim_beam_mesh.visible = false

func _fire_snowball() -> void:
	_clear_aim_beam()
	if not projectile_scene or not is_inside_tree() or not stats:
		return

	var spawn_origin := Vector3(global_position.x, 1.05, global_position.z)
	var flat_aim := Vector3(aim_target_pos.x - spawn_origin.x, aim_target_pos.y - spawn_origin.y, aim_target_pos.z - spawn_origin.z)
	var fire_dir := flat_aim.normalized() if flat_aim.length_squared() > 0.001 else Vector3.FORWARD

	var proj := projectile_scene.instantiate() as Area3D
	var start_pos := spawn_origin + fire_dir * 0.65
	proj.position = start_pos
	get_tree().current_scene.add_child(proj)
	proj.global_position = start_pos
	if proj.has_method("setup"):
		proj.setup(fire_dir, stats.projectile_speed, stats.damage, stats.projectile_hit_radius, stats.projectile_lifetime)

	if throw_sound:
		throw_sound.play()
