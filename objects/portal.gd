extends Area3D

@export var is_final_portal: bool = false
@export var target_scene: PackedScene

@onready var glitch_sound: AudioStreamPlayer = $GlitchSound 

var is_active = false
var is_transitioning = false

func _ready() -> void:
	visible = false
	monitoring = false
	GameManager.portal_opened.connect(activate_portal)

	if get_tree().current_scene and get_tree().current_scene.name == "world_25d":
		is_final_portal = false
		target_scene = preload("res://levels/street/world_3.tscn")

func activate_portal() -> void:
	is_active = true
	visible = true
	monitoring = true

func _hide_hud() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	var hud = current_scene.find_child("MobileHUD", true, false)
	if hud:
		if "force_hidden" in hud:
			hud.force_hidden = true
		hud.hide()

func _on_body_entered(body: Node3D) -> void:
	if is_active and not is_transitioning and body.is_in_group("player"):
		is_transitioning = true
		_hide_hud()

		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
			body.set_physics_process(false)
		
		if is_final_portal:
			trigger_crt_shutdown()
		else:
			trigger_scene_transition()	

func trigger_scene_transition():
	_hide_hud()
	if glitch_sound:
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
		
	var next = target_scene
	if not next:
		if get_tree().current_scene and get_tree().current_scene.name == "world_25d":
			next = load("res://levels/street/world_3.tscn")
		else:
			next = load("res://levels/dream/world_25d.tscn")
	GameManager.load_chapter(next)

func trigger_crt_shutdown() -> void:
	_hide_hud()
	if glitch_sound:
		glitch_sound.pitch_scale = 5.0
		glitch_sound.play()

	var current_scene = get_tree().current_scene
	var canvas = current_scene.find_child("CanvasLayer", true, false) if current_scene else null
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

func reset_shader() -> void:
	var post_process = get_tree().root.find_child("ColorRect", true, false)
	if post_process and post_process.material:
		var mat = post_process.material as ShaderMaterial
		mat.set_shader_parameter("enable_monochrome", false)
		mat.set_shader_parameter("saturation", 0.18)
		mat.set_shader_parameter("invert_colors", false)
		mat.set_shader_parameter("target_resolution", Vector2(854, 480))
		mat.set_shader_parameter("dither_intensity", 0.12)
