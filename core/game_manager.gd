extends Node

signal score_changed(new_score)
signal game_won
signal game_lost
signal player_name_changed(new_name)
signal portal_opened
signal key_collected(key_id: int, total_keys: int)
signal all_keys_collected
signal show_notification(text: String)
signal health_changed(current_hp: int, max_hp: int)
signal device_profile_changed(profile_idx: int)
signal save_changed
@warning_ignore("unused_signal")
signal camera_shake(intensity: float, duration: float)

var device_profile: int = 0

@export var win_score: int = 20
@export var time_limit: float = 30.0

var score: int = 0
var time_left: float = 30.0
var player_name: String = "Игрок"
var music_volume: float = 1.0
var is_fullscreen: bool = false
var is_music_on: bool = true

var game_started: bool = false
var is_game_over: bool = false
var timer_active: bool = false
var current_session_id: int = 0

var max_health: int = 3
var current_health: int = 3

var collected_keys: Array[int] = []

var save_data: SaveData = SaveData.new()
var level_catalog: Array[LevelData] = []
var selected_level_id: int = 1

const LEVEL_PATHS: Array[String] = [
	"res://data/levels/level_01.tres",
	"res://data/levels/level_02.tres",
	"res://data/levels/level_03.tres"
]

const death_messages: Array[String] = [
	"Ещё раз?",
	"Серьёзно?",
	"Бывает.",
	"Ну и зачем?",
	"Попробуй открыть глаза.",
	"И это всё, {name}?",
	"Слабовато, {name}.",
	"Ты это специально, {name}?",
	"Соберись.",
	"Почти получилось.",
	"F",
	"Never gonna give you up"
]

@onready var audio_coin: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	time_left = time_limit
	_load_level_catalog()
	load_progress()
	$Music.finished.connect(func(): $Music.play())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()

func _load_level_catalog() -> void:
	level_catalog.clear()
	for path in LEVEL_PATHS:
		var res := load(path)
		if res is LevelData:
			level_catalog.append(res as LevelData)

func get_level_data_by_id(level_id: int) -> LevelData:
	for lvl in level_catalog:
		if lvl.level_id == level_id:
			return lvl
	if not level_catalog.is_empty():
		return level_catalog[0]
	return null

func get_current_level_data() -> LevelData:
	return get_level_data_by_id(selected_level_id)

func get_highest_unlocked_level() -> int:
	var highest := 1
	if save_data:
		for id in save_data.unlocked_levels:
			if id > highest:
				highest = id
	return clampi(highest, 1, maxi(1, level_catalog.size()))

func load_progress() -> void:
	save_data = SaveSystem.load_save()
	player_name = save_data.player_name
	music_volume = save_data.music_volume
	is_fullscreen = save_data.is_fullscreen
	is_music_on = save_data.is_music_on
	apply_loaded_settings()
	save_changed.emit()

func save_progress() -> void:
	if not save_data:
		save_data = SaveData.new()
	save_data.player_name = player_name
	save_data.music_volume = music_volume
	save_data.is_fullscreen = is_fullscreen
	save_data.is_music_on = is_music_on
	SaveSystem.save(save_data)

func complete_arena_level(level_id: int, run_score: int) -> void:
	if not save_data:
		save_data = SaveData.new()
	save_data.record_level_complete(level_id, run_score, maxi(3, level_catalog.size()))
	save_progress()
	save_changed.emit()

func reset_all_progress() -> void:
	SaveSystem.delete_save()
	save_data = SaveData.new()
	player_name = save_data.player_name
	music_volume = save_data.music_volume
	is_fullscreen = save_data.is_fullscreen
	is_music_on = save_data.is_music_on
	selected_level_id = 1
	apply_loaded_settings()
	save_changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			set_device_profile(0)
		elif event.keycode == KEY_F2:
			set_device_profile(1)
		elif event.keycode == KEY_F3:
			set_device_profile(2)

func set_device_profile(idx: int) -> void:
	device_profile = idx
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		match idx:
			0:
				DisplayServer.window_set_size(Vector2i(1440, 810))
			1:
				DisplayServer.window_set_size(Vector2i(1560, 720))
			2:
				DisplayServer.window_set_size(Vector2i(1200, 900))
	device_profile_changed.emit(device_profile)

func _process(delta: float) -> void:
	if not timer_active or is_game_over or not game_started or get_tree().paused:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		lose()

func restart_game() -> void:
	current_session_id += 1
	Engine.time_scale = 1.0
	score = 0
	is_game_over = false
	time_left = time_limit
	reset_keys()
	reset_health()
	get_tree().paused = false
	get_tree().reload_current_scene()

func add_score(value: int) -> void:
	if is_game_over:
		return
	score += value
	score_changed.emit(score)
	if audio_coin:
		audio_coin.play()
	if score >= win_score:
		win()

func win() -> void:
	is_game_over = true
	stop_timer()
	game_won.emit()
	portal_opened.emit()

func lose() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_lost.emit()
	Engine.time_scale = 0.3
	var session := current_session_id
	await get_tree().create_timer(3.0, true, false, true).timeout
	if session == current_session_id:
		restart_game()

func save_settings() -> void:
	save_progress()

func load_settings() -> void:
	load_progress()

func apply_loaded_settings() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(music_volume, 0.0001)))
	if has_node("Music"):
		$Music.stream_paused = not is_music_on
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	player_name_changed.emit(player_name)

func start_timer() -> void:
	time_left = time_limit
	timer_active = true

func stop_timer() -> void:
	timer_active = false

func collect_key(key_id: int) -> void:
	if not collected_keys.has(key_id):
		collected_keys.append(key_id)
		if audio_coin:
			audio_coin.play()
		key_collected.emit(key_id, collected_keys.size())
		if collected_keys.size() == 1:
			show_notification.emit("Собрана часть ключа... (1/2)")
		if collected_keys.size() >= 2:
			show_notification.emit("Ключ собран (2/2)!")
			all_keys_collected.emit()

func has_all_keys() -> bool:
	return collected_keys.size() >= 2

func reset_keys() -> void:
	collected_keys.clear()

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health <= 0:
		current_health = 0
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		trigger_death()

func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func get_death_message() -> String:
	return death_messages.pick_random().replace("{name}", player_name)

func trigger_death() -> void:
	if is_game_over:
		return
	is_game_over = true

	var current_scene := get_tree().current_scene
	var hud := current_scene.find_child("MobileHUD", true, false) if current_scene else null
	if hud:
		if "force_hidden" in hud:
			hud.force_hidden = true
		hud.hide()
	var canvas := current_scene.find_child("CanvasLayer", true, false) if current_scene else null
	var crt := canvas.get_node_or_null("ColorRect") if canvas else null

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.text = get_death_message()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	bg.add_child(label)

	if canvas:
		canvas.add_child(bg)
		if crt:
			canvas.move_child(bg, crt.get_index())
	else:
		get_tree().root.add_child(bg)

	var session := current_session_id
	await get_tree().create_timer(1.1, true, false, true).timeout
	if session == current_session_id:
		restart_game()
	if is_instance_valid(bg):
		bg.queue_free()

func load_arena_level(level_id: int) -> void:
	selected_level_id = clampi(level_id, 1, maxi(1, level_catalog.size()))
	load_chapter(load("res://levels/chapter_4/world_4.tscn"))

func load_chapter(scene: PackedScene) -> void:
	current_session_id += 1
	Engine.time_scale = 1.0
	score = 0
	is_game_over = false
	game_started = true
	time_left = time_limit
	timer_active = false
	reset_keys()
	reset_health()
	get_tree().paused = false
	if has_node("Music") and is_music_on:
		$Music.stream_paused = false
		if not $Music.playing:
			$Music.play()
	get_tree().change_scene_to_packed(scene)

func start_new_game() -> void:
	load_arena_level(get_highest_unlocked_level())

func return_to_main_menu() -> void:
	current_session_id += 1
	Engine.time_scale = 1.0
	score = 0
	is_game_over = false
	game_started = false
	time_left = time_limit
	timer_active = false
	reset_keys()
	reset_health()
	get_tree().paused = false
	if has_node("Music") and is_music_on:
		$Music.stream_paused = false
		if not $Music.playing:
			$Music.play()
	get_tree().change_scene_to_file("res://levels/dream/world_25d.tscn")
