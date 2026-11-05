extends Node3D

@export var total_cranes: int = 3
var collected_cranes: int = 0

@onready var camera: Camera3D = $Camera3D
@onready var white_door: Area3D = $WhiteDoor
@onready var player: CharacterBody3D = $player_3
@onready var mobile_hud = get_node_or_null("CanvasLayer/MobileHUD")

@export var target_scene: PackedScene

func _ready() -> void:
	GameManager.reset_health()
	if not mobile_hud:
		mobile_hud = find_child("MobileHUD", true, false)
	_update_hud()

func _process(_delta: float) -> void:
	if player and player.global_position.y < -4.0:
		player.respawn(Vector3(0, 1.0, 0))

func collect_crane(_crane_id: int) -> void:
	collected_cranes += 1
	_update_hud()
	
	if collected_cranes >= total_cranes:
		trigger_door_cutscene()

func _update_hud() -> void:
	if mobile_hud:
		mobile_hud.set_score_text("Оригами: %d / %d" % [collected_cranes, total_cranes])

func trigger_door_cutscene() -> void:
	if player:
		player.can_move = false
	if mobile_hud:
		mobile_hud.force_hidden = true
		mobile_hud.hide()
	
	if camera and camera.has_method("swoop_to_door") and white_door:
		camera.swoop_to_door(white_door.global_position, 2.0)
	
	await get_tree().create_timer(2.0, false).timeout
	
	if white_door and white_door.has_method("open_door"):
		white_door.open_door()
	
	await get_tree().create_timer(2.2, false).timeout
	
	if camera and camera.has_method("swoop_back_to_player"):
		camera.swoop_back_to_player(1.8)
	
	await get_tree().create_timer(1.8, false).timeout
	
	if mobile_hud:
		mobile_hud.force_hidden = false
	if player:
		player.can_move = true

func on_door_entered() -> void:
	if player:
		player.can_move = false
		player.velocity = Vector3.ZERO
	if mobile_hud:
		mobile_hud.force_hidden = true
		mobile_hud.hide()

	if target_scene:
		trigger_scene_transition()
	else:
		trigger_crt_shutdown()

func trigger_crt_shutdown() -> void:
	if mobile_hud:
		mobile_hud.force_hidden = true
		mobile_hud.hide()

	var glitch_sound = AudioStreamPlayer.new()
	glitch_sound.stream = preload("res://assets/audios/noise.wav")
	glitch_sound.volume_db = 24.0
	glitch_sound.pitch_scale = 5.0
	add_child(glitch_sound)
	glitch_sound.play()

	var canvas = find_child("CanvasLayer", true, false)
	var crt = canvas.get_node_or_null("ColorRect") if canvas else null
	var screen_size = get_viewport().get_visible_rect().size

	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var crt_line = ColorRect.new()
	crt_line.color = Color.WHITE
	crt_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_line.pivot_offset = screen_size / 2.0
	bg.add_child(crt_line)

	if canvas:
		canvas.add_child(bg)
		if crt:
			canvas.move_child(bg, crt.get_index())
	else:
		get_tree().root.add_child(bg)
	GameManager.get_node("Music").stop()

	var tween = create_tween()
	tween.tween_property(crt_line, "scale", Vector2(1.0, 0.003), 0.24).from(Vector2(1.0, 1.0))
	tween.tween_property(crt_line, "scale", Vector2(0.003, 0.003), 0.24)
	tween.tween_property(crt_line, "modulate:a", 0.0, 0.18)
	await tween.finished
	crt_line.queue_free()
	if glitch_sound:
		glitch_sound.stop()

	await get_tree().create_timer(1.2, true, false, true).timeout

	var end_label = Label.new()
	end_label.text = "КОНЕЦ..."
	end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 54)
	end_label.add_theme_constant_override("outline_size", 10)
	end_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_label.modulate.a = 0.0
	bg.add_child(end_label)

	var tween2 = create_tween()
	tween2.tween_property(end_label, "modulate:a", 1.0, 0.8)
	await tween2.finished

	await get_tree().create_timer(2.0, true, false, true).timeout

	reset_shader()
	bg.queue_free()
	GameManager.return_to_main_menu()

func trigger_scene_transition():
	if mobile_hud:
		mobile_hud.force_hidden = true
		mobile_hud.hide()

	var glitch_sound = AudioStreamPlayer.new()
	glitch_sound.stream = preload("res://assets/audios/noise.wav")
	glitch_sound.volume_db = 24.0
	glitch_sound.pitch_scale = 5.0
	add_child(glitch_sound)
	glitch_sound.play()

	var post_process = get_tree().root.find_child("ColorRect", true, false)
	if post_process and post_process.material:
		var mat = post_process.material as ShaderMaterial
		mat.set_shader_parameter("enable_monochrome", true)
		mat.set_shader_parameter("saturation", 0.0) 
		mat.set_shader_parameter("target_resolution", Vector2(80, 45))
		mat.set_shader_parameter("dither_intensity", 0.6)

	await get_tree().create_timer(0.6, true, false, true).timeout
	
	if glitch_sound:
		glitch_sound.stop()

	reset_shader()	
	GameManager.load_chapter(target_scene)

func reset_shader() -> void:
	var post_process = get_tree().root.find_child("ColorRect", true, false)
	if post_process and post_process.material:
		var mat = post_process.material as ShaderMaterial
		mat.set_shader_parameter("enable_monochrome", false)
		mat.set_shader_parameter("saturation", 0.18)
		mat.set_shader_parameter("invert_colors", false)
		mat.set_shader_parameter("target_resolution", Vector2(854, 480))
		mat.set_shader_parameter("dither_intensity", 0.12)
