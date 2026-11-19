extends Node

signal ammo_changed(in_mag: int, reserve: int)

@export_group("Weapon Data")
@export var stats: WeaponStats
@export var bullet_scene: PackedScene

@export_group("Audio")
@export var shot_sounds: Array[AudioStream]
@export var reload_sound: AudioStream

@export_group("Node References")
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var anim_player: AnimationPlayer
@export var sprite: Control
@export var muzzle_hip: Marker3D
@export var muzzle_aim: Marker3D
@export var aim_ray: RayCast3D
@export var sound: AudioStreamPlayer

var current_ammo: int = 0
var reserve_ammo: int = 0
var is_aiming: bool = false
var can_shoot: bool = true
var is_reloading: bool = false
var sway_time: float = 0.0
var base_sprite_pos: Vector2
var last_word_idx: int = -1

func _ready() -> void:
	current_ammo = stats.max_ammo if stats else 8
	reserve_ammo = stats.reserve_ammo if stats else 16
	if sprite:
		base_sprite_pos = sprite.position
	if anim_player:
		anim_player.play("idle")
	ammo_changed.emit.call_deferred(current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	var want_aim := Input.is_action_pressed("aim") and not is_reloading

	if want_aim != is_aiming:
		is_aiming = want_aim
		if not is_reloading and can_shoot and anim_player:
			anim_player.play("aim_idle" if is_aiming else "idle")

	if camera:
		var aim_fov := stats.aim_fov if stats else 50.0
		var normal_fov := stats.normal_fov if stats else 75.0
		var target_fov := aim_fov if is_aiming else normal_fov
		camera.fov = lerpf(camera.fov, target_fov, delta * 12.0)

	_handle_weapon_sway(delta)

	if Input.is_action_just_pressed("fire"):
		shoot()
	elif Input.is_action_just_pressed("reload"):
		reload()

func _handle_weapon_sway(delta: float) -> void:
	if not sprite or not player:
		return

	var horizontal_vel := Vector2(player.velocity.x, player.velocity.z)
	var is_moving := horizontal_vel.length() > 0.1 and player.is_on_floor()

	if is_moving and can_shoot and not is_reloading:
		var s_speed := stats.sway_speed if stats else 9.0
		var s_amount := stats.sway_amount if stats else Vector2(10.0, 7.0)
		sway_time += delta * s_speed
		var mult := 0.3 if is_aiming else 1.0
		var bob_offset := Vector2(
			cos(sway_time) * s_amount.x * mult,
			absf(sin(sway_time)) * s_amount.y * mult
		)
		sprite.position = sprite.position.lerp(base_sprite_pos + bob_offset, delta * 10.0)
	else:
		sway_time = 0.0
		sprite.position = sprite.position.lerp(base_sprite_pos, delta * 10.0)

func shoot() -> void:
	if not can_shoot or is_reloading:
		return

	if current_ammo <= 0:
		reload()
		return

	can_shoot = false
	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)

	var words: Array[String] = stats.shot_words if stats and not stats.shot_words.is_empty() else ["ПИУ!"]
	var variant_count := maxi(words.size(), shot_sounds.size())
	var idx := 0
	if variant_count > 1:
		idx = randi() % variant_count
		if idx == last_word_idx:
			idx = (idx + 1 + (randi() % (variant_count - 1))) % variant_count
	last_word_idx = idx

	var word := words[idx % words.size()]

	if sound and not shot_sounds.is_empty():
		sound.stream = shot_sounds[idx % shot_sounds.size()]
		sound.pitch_scale = 1.0
		sound.play()

	if anim_player:
		var shoot_anim := "aim_shoot" if is_aiming else "shoot"
		if anim_player.has_animation(shoot_anim):
			anim_player.stop()
			anim_player.play(shoot_anim)

	_spawn_bullet(word)

	var rate := stats.fire_rate if stats else 0.25
	await get_tree().create_timer(rate).timeout
	can_shoot = true

	if not is_reloading and anim_player:
		anim_player.play("aim_idle" if is_aiming else "idle")

func _find_aim_point() -> Vector3:
	if camera:
		var space_state := camera.get_world_3d().direct_space_state
		var cam_pos := camera.global_position
		var cam_fwd := -camera.global_transform.basis.z
		var end_pos := cam_pos + cam_fwd * 100.0
		var exclude_rids: Array[RID] = []
		if player is CollisionObject3D:
			exclude_rids.append((player as CollisionObject3D).get_rid())

		var cursor := cam_pos
		for _i in range(6):
			var query := PhysicsRayQueryParameters3D.create(cursor, end_pos)
			query.collide_with_areas = true
			query.collide_with_bodies = true
			query.exclude = exclude_rids
			var hit := space_state.intersect_ray(query)
			if hit.is_empty():
				return end_pos
			var collider: Object = hit.get("collider")
			if collider is Hazard:
				return hit.get("position", end_pos)
			if collider is Area3D:
				exclude_rids.append((collider as CollisionObject3D).get_rid())
				cursor = (hit.get("position", end_pos) as Vector3) + cam_fwd * 0.05
				continue
			return hit.get("position", end_pos)
		return end_pos

	if aim_ray:
		aim_ray.force_raycast_update()
		if aim_ray.is_colliding():
			return aim_ray.get_collision_point()
	return Vector3.FORWARD * 100.0

func _spawn_bullet(word: String) -> void:
	if not bullet_scene:
		return

	var bullet := bullet_scene.instantiate()
	var active_muzzle := muzzle_aim if is_aiming else muzzle_hip
	var spawn_pos := active_muzzle.global_position if active_muzzle else camera.global_position
	bullet.position = spawn_pos

	var b_speed := stats.bullet_speed if stats else 25.0
	var b_damage := stats.bullet_damage if stats else 1
	var b_life := stats.bullet_lifetime if stats else 2.2
	if bullet.has_method("setup"):
		bullet.setup(word, b_speed, b_damage, b_life)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos

	var target_point := _find_aim_point()
	var shoot_dir := (target_point - spawn_pos).normalized()

	var spread := stats.hip_spread if stats else 3.0
	if not is_aiming and spread > 0.0:
		var spread_rad := deg_to_rad(spread)
		shoot_dir = shoot_dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
		shoot_dir = shoot_dir.rotated(camera.global_transform.basis.x, randf_range(-spread_rad, spread_rad))

	bullet.direction = shoot_dir.normalized()

func reload() -> void:
	var mag_size := stats.max_ammo if stats else 8
	if is_reloading or current_ammo == mag_size or reserve_ammo <= 0:
		return

	is_reloading = true
	is_aiming = false

	if sound and reload_sound:
		sound.stream = reload_sound
		sound.pitch_scale = 1.0
		sound.play()

	if anim_player and anim_player.has_animation("reload"):
		anim_player.play("reload")
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	var needed := mag_size - current_ammo
	var to_load := mini(needed, reserve_ammo)
	current_ammo += to_load
	reserve_ammo -= to_load

	is_reloading = false
	ammo_changed.emit(current_ammo, reserve_ammo)

	if anim_player:
		var want_aim := Input.is_action_pressed("aim")
		anim_player.play("aim_idle" if want_aim else "idle")

func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	ammo_changed.emit(current_ammo, reserve_ammo)
