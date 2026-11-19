extends Node3D

signal time_updated(seconds_left: float)

@export var fallback_level_data: LevelData

@onready var spawner: Node3D = $Spawner
@onready var white_door: Area3D = $WhiteDoor
@onready var door_hint: Label3D = get_node_or_null("DoorHint")
@onready var exit_area: Area3D = $WhiteDoor/ExitArea
@onready var survival_timer: Timer = $SurvivalTimer
@onready var player: CharacterBody3D = $Player4
@onready var initial_enemies_root: Node3D = $InitialEnemies
@onready var initial_pickups_root: Node3D = $InitialPickups
@onready var lights_root: Node3D = get_node_or_null("Room/Lights")

var level_data: LevelData
var is_ending: bool = false
var door_opened: bool = false
var kills: int = 0
var run_score: int = 0

func _ready() -> void:
	if GameManager and GameManager.has_method("get_current_level_data"):
		level_data = GameManager.get_current_level_data()
	if not level_data:
		level_data = fallback_level_data

	if door_hint:
		door_hint.visible = false

	if white_door:
		white_door.player_entered_door.connect(on_door_entered)

	exit_area.monitoring = false
	exit_area.body_entered.connect(_on_exit_area_body_entered)

	var hud := player.get_node_or_null("CanvasLayer") if player else null
	if hud and hud.has_method("_on_time_updated"):
		time_updated.connect(hud._on_time_updated)

	_load_from_level_data()

func _load_from_level_data() -> void:
	if not level_data:
		return

	if lights_root:
		for c in lights_root.get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).light_energy *= level_data.light_energy_scale

	for c in initial_enemies_root.get_children():
		c.queue_free()
	for c in initial_pickups_root.get_children():
		c.queue_free()

	var enemy_count := mini(level_data.initial_enemy_scenes.size(), level_data.initial_enemy_positions.size())
	for i in range(enemy_count):
		var scene := level_data.initial_enemy_scenes[i]
		if not scene:
			continue
		var pos := level_data.initial_enemy_positions[i]
		var inst := scene.instantiate()
		if spawner and spawner.has_method("assign_patrol_route"):
			spawner.assign_patrol_route(inst, pos)
		if inst is Node3D:
			(inst as Node3D).position = pos
		initial_enemies_root.add_child(inst)
		if inst is Node3D:
			(inst as Node3D).global_position = pos

	var pickup_count := mini(level_data.initial_pickup_scenes.size(), level_data.initial_pickup_positions.size())
	for i in range(pickup_count):
		var p_scene := level_data.initial_pickup_scenes[i]
		if not p_scene:
			continue
		var p_pos := level_data.initial_pickup_positions[i]
		var p_inst := p_scene.instantiate()
		if p_inst is Node3D:
			(p_inst as Node3D).position = p_pos
		initial_pickups_root.add_child(p_inst)
		if p_inst is Node3D:
			(p_inst as Node3D).global_position = p_pos

	if spawner and spawner.has_method("configure_from_level"):
		spawner.configure_from_level(level_data)

	survival_timer.wait_time = level_data.time_limit
	survival_timer.one_shot = true
	if not survival_timer.timeout.is_connected(_on_survival_timer_timeout):
		survival_timer.timeout.connect(_on_survival_timer_timeout)
	survival_timer.start()

	var hud := player.get_node_or_null("CanvasLayer") if player else null
	if hud and hud.has_method("setup_level_hud"):
		hud.setup_level_hud(level_data.level_title, _get_goal_text(), run_score)

func _get_goal_text() -> String:
	if not level_data:
		return ""
	if door_opened:
		return "ИДИ В ДВЕРЬ!"
	if level_data.goal_type == LevelData.GoalType.ELIMINATE:
		return "УБИТЬ %d / %d" % [kills, level_data.goal_kills]
	return "ВЫЖИТЬ"

func _process(_delta: float) -> void:
	if is_ending:
		return
	if not survival_timer.is_stopped():
		time_updated.emit(survival_timer.time_left)

func on_enemy_killed(points: int) -> void:
	if is_ending or not level_data:
		return
	kills += 1
	run_score += points
	var hud := player.get_node_or_null("CanvasLayer") if player else null
	if hud and hud.has_method("update_score"):
		hud.update_score(run_score)
	if hud and hud.has_method("update_goal"):
		hud.update_goal(level_data.level_title, _get_goal_text())

	if level_data.goal_type == LevelData.GoalType.ELIMINATE and not door_opened:
		if kills >= level_data.goal_kills:
			_open_exit_door()

func _on_survival_timer_timeout() -> void:
	if door_opened or is_ending:
		return
	time_updated.emit(0.0)
	if level_data and level_data.goal_type == LevelData.GoalType.ELIMINATE and kills < level_data.goal_kills:
		get_tree().reload_current_scene.call_deferred()
		return
	_open_exit_door()

func _open_exit_door() -> void:
	if door_opened:
		return
	door_opened = true
	survival_timer.stop()

	if spawner:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
		elif spawner.has_node("Timer"):
			spawner.get_node("Timer").stop()

	for child in spawner.get_children():
		if child is Hazard:
			(child as Hazard).die(false)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("die"):
			enemy.die(false)

	if white_door and white_door.has_method("open_door"):
		white_door.open_door()

	if door_hint:
		door_hint.visible = true

	var hud := player.get_node_or_null("CanvasLayer") if player else null
	if hud and hud.has_method("update_goal") and level_data:
		hud.update_goal(level_data.level_title, _get_goal_text())
	if hud and hud.has_method("show_escape_banner"):
		hud.show_escape_banner()

	exit_area.monitoring = true

func _on_exit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		on_door_entered()

func on_door_entered() -> void:
	if is_ending:
		return
	is_ending = true

	var lvl_id := level_data.level_id if level_data else 1
	var bonus := level_data.completion_bonus if level_data else 300
	var time_bonus := int(survival_timer.time_left) * 5 if level_data and level_data.goal_type == LevelData.GoalType.ELIMINATE else 0
	var final_score := run_score + bonus + time_bonus

	if GameManager and GameManager.has_method("complete_arena_level"):
		GameManager.complete_arena_level(lvl_id, final_score)

	if player:
		player.set_physics_process(false)
		player.set_process(false)
		player.set_process_unhandled_input(false)
		var weapon := player.get_node_or_null("Weapon")
		if weapon:
			weapon.set_process(false)
		var health := player.get_node_or_null("Health")
		if health:
			health.is_invincible = true

	if spawner:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
		elif spawner.has_node("Timer"):
			spawner.get_node("Timer").stop()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	for child in get_children():
		if child is Hazard:
			child.queue_free()

	trigger_crt_shutdown(lvl_id, final_score)

func trigger_crt_shutdown(lvl_id: int, final_score: int) -> void:
	var glitch_sound := AudioStreamPlayer.new()
	glitch_sound.stream = preload("res://assets/audios/noise.wav")
	glitch_sound.volume_db = 24.0
	glitch_sound.pitch_scale = 5.0
	add_child(glitch_sound)
	glitch_sound.play()

	var canvas: CanvasLayer = player.get_node_or_null("CanvasLayer") if player else null
	var crt: ColorRect = canvas.get_node_or_null("ColorRect") if canvas else null
	var screen_size := get_viewport().get_visible_rect().size

	if canvas:
		for c in canvas.get_children():
			if c != crt:
				if c is CanvasItem:
					(c as CanvasItem).hide()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var crt_line := ColorRect.new()
	crt_line.color = Color.WHITE
	crt_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_line.pivot_offset = screen_size / 2.0
	bg.add_child(crt_line)

	if canvas:
		canvas.add_child(bg)
		if crt:
			canvas.move_child(bg, crt.get_index())
	else:
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		add_child(overlay)
		overlay.add_child(bg)

	if GameManager and GameManager.has_node("Music"):
		GameManager.get_node("Music").stop()

	var tween := create_tween()
	tween.tween_property(crt_line, "scale", Vector2(1.0, 0.003), 0.24).from(Vector2(1.0, 1.0))
	tween.tween_property(crt_line, "scale", Vector2(0.003, 0.003), 0.24)
	tween.tween_property(crt_line, "modulate:a", 0.0, 0.18)
	await tween.finished
	crt_line.queue_free()
	glitch_sound.stop()

	await get_tree().create_timer(1.2, true, false, true).timeout

	var end_label := Label.new()
	if lvl_id < 3:
		end_label.text = "УРОВЕНЬ %d ПРОЙДЕН!\nОЧКИ: %d\nОТКРЫТ УРОВЕНЬ %d" % [lvl_id, final_score, lvl_id + 1]
	else:
		end_label.text = "КОНЕЦ...\nОЧКИ: %d" % final_score
	end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 46)
	end_label.add_theme_constant_override("outline_size", 10)
	end_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_label.modulate.a = 0.0
	bg.add_child(end_label)

	var tween2 := create_tween()
	tween2.tween_property(end_label, "modulate:a", 1.0, 0.8)
	await tween2.finished

	await get_tree().create_timer(2.0, true, false, true).timeout

	bg.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameManager and GameManager.has_method("return_to_main_menu"):
		GameManager.return_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
