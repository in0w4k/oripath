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
@warning_ignore("unused_signal")
signal camera_shake(intensity: float, duration: float)

var device_profile: int = 0

@export var win_score = 20
@export var time_limit = 30.0

var score: int = 0
var time_left = 30.0
var player_name = "Игрок"
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

const save_path_settings = "user://settings.cfg"

@onready var audio_coin: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	time_left = time_limit
	player_name_changed.emit(player_name)
	load_settings()
	$Music.finished.connect(func(): $Music.play())

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
	if not OS.has_feature("mobile"):
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
	var session = current_session_id
	await get_tree().create_timer(3.0, true, false, true).timeout
	if session == current_session_id:
		restart_game()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "player_name", player_name)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "is_fullscreen", is_fullscreen)
	config.set_value("settings", "is_music_on", is_music_on)
	config.save(save_path_settings)

func load_settings() -> void:
	var config = ConfigFile.new()
	if FileAccess.file_exists(save_path_settings):
		config.load(save_path_settings)
		player_name = config.get_value("settings", "player_name", "Player")
		music_volume = clampf(config.get_value("settings", "music_volume", 1.0), 0.0, 1.0)
		is_fullscreen = config.get_value("settings", "is_fullscreen", false)
		is_music_on = config.get_value("settings", "is_music_on", true)

		apply_loaded_settings()
	
func apply_loaded_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(music_volume))
	$Music.stream_paused = not is_music_on
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
		
func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func get_death_message() -> String:
	return death_messages.pick_random().replace("{name}", player_name)

func trigger_death() -> void:
	if is_game_over:
		return
	is_game_over = true

	var current_scene = get_tree().current_scene
	var hud = current_scene.find_child("MobileHUD", true, false) if current_scene else null
	if hud:
		if "force_hidden" in hud:
			hud.force_hidden = true
		hud.hide()
	var canvas = current_scene.find_child("CanvasLayer", true, false) if current_scene else null
	var crt = canvas.get_node_or_null("ColorRect") if canvas else null

	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label = Label.new()
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

	var session = current_session_id
	await get_tree().create_timer(1.1, true, false, true).timeout
	
	if session == current_session_id:
		restart_game()
	if is_instance_valid(bg):
		bg.queue_free()

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
	
	if is_music_on:
		$Music.stream_paused = false
		if not $Music.playing:
			$Music.play()
			
	get_tree().change_scene_to_packed(scene)
	
func start_new_game() -> void:
	load_chapter(load("res://levels/dream/world_25d.tscn"))

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
	if is_music_on:
		$Music.stream_paused = false
		if not $Music.playing:
			$Music.play()
	get_tree().change_scene_to_file("res://levels/dream/world_25d.tscn")
