extends Control

@onready var start_button = $MenuContent/StartButton
@onready var restart_button = $MenuContent/RestartButton
@onready var quit_button = $MenuContent/QuitButton

@onready var volume_slider = $SettingsContent/VolumeSlider
@onready var fullscreen_check = $SettingsContent/FullscreenCheck
@onready var music_check = $SettingsContent/MusicCheck


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	start_button.pressed.connect(on_start_pressed)
	restart_button.pressed.connect(on_restart_pressed)
	quit_button.pressed.connect(on_quit_pressed)

	volume_slider.value = GameManager.music_volume * 100.0 if volume_slider.max_value > 1.0 else GameManager.music_volume
	fullscreen_check.button_pressed = GameManager.is_fullscreen
	music_check.button_pressed = GameManager.is_music_on

	volume_slider.value_changed.connect(on_volume_changed)
	fullscreen_check.toggled.connect(on_fullscreen_changed)
	music_check.toggled.connect(on_music_changed)

	if not GameManager.game_started:
		open_menu()
	else:
		hide()

	$AnimationPlayer.play("menu_idle")

	$ChaptersContent/Chapter1Button.pressed.connect(func(): on_chapter_selected(load("res://levels/dream/world_25d.tscn")))
	$ChaptersContent/Chapter2Button.pressed.connect(func(): on_chapter_selected(load("res://levels/street/world_3.tscn")))
	$ChaptersContent/Chapter3Button.hide()
	$ChaptersContent/Chapter4Button.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			if GameManager.game_started:
				close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()

func on_start_pressed() -> void:
	if GameManager.game_started:
		close_menu()
	else:
		show_name_prompt()

func on_restart_pressed() -> void:
	close_menu()
	GameManager.restart_game()

func on_quit_pressed() -> void:
	get_tree().quit()

func open_menu() -> void:
	_on_menu_button_pressed()
	update_menu()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_menu() -> void:
	if GameManager.game_started:
		start_button.texture_normal = preload("res://assets/menu/continue_button.png")
		start_button.texture_hover = preload("res://assets/menu/continue_button_inverted.png")
		start_button.texture_pressed = preload("res://assets/menu/continue_button_inverted.png")
		restart_button.visible = true
	else:
		start_button.texture_normal = preload("res://assets/menu/start_button.png")
		start_button.texture_hover = preload("res://assets/menu/start_button_inverted.png")
		start_button.texture_pressed = preload("res://assets/menu/start_button_inverted.png")
		restart_button.visible = false

func on_name_changed(new_name: String) -> void:
	GameManager.player_name = new_name.strip_edges()
	GameManager.player_name_changed.emit(GameManager.player_name)
	GameManager.save_settings()

func on_volume_changed(value: float) -> void:
	var norm_val = value / 100.0 if volume_slider.max_value > 1.0 else value
	GameManager.music_volume = norm_val
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(norm_val))
	GameManager.save_settings()

func on_fullscreen_changed(checked: bool) -> void:
	GameManager.is_fullscreen = checked
	if not OS.has_feature("mobile"):
		if checked:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	GameManager.save_settings()

func on_music_changed(checked: bool) -> void:
	GameManager.is_music_on = checked
	GameManager.get_node("Music").stream_paused = not checked
	GameManager.save_settings()

func on_chapter_selected(scene: PackedScene) -> void:
	close_menu()
	GameManager.load_chapter(scene)

func show_name_prompt() -> void:
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	bg.add_child(vbox)

	var prompt_label = Label.new()
	prompt_label.text = "Как вас зовут?"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 42)
	prompt_label.visible_characters = 0
	vbox.add_child(prompt_label)

	var input = LineEdit.new()
	input.custom_minimum_size = Vector2(320, 50)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.placeholder_text = "Введите имя..."
	input.max_length = 16
	input.add_theme_font_size_override("font_size", 28)
	input.modulate.a = 0.0
	vbox.add_child(input)

	var hint = Button.new()
	hint.text = "[ Нажмите Enter ]"
	hint.flat = true
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.0)
	vbox.add_child(hint)

	for i in range(prompt_label.text.length()):
		if not is_instance_valid(prompt_label):
			return
		prompt_label.visible_characters = i + 1
		await get_tree().create_timer(0.07, true, false, true).timeout

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(input, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(hint, "modulate:a", 0.6, 0.3)
	input.grab_focus()

	var submit_fn = func(entered_text: String):
		var clean_name = entered_text.strip_edges()
		if clean_name != "":
			GameManager.player_name = clean_name
		else:
			GameManager.player_name = "Игрок"
		GameManager.player_name_changed.emit(GameManager.player_name)
		GameManager.save_settings()
		if is_instance_valid(bg):
			bg.queue_free()
		close_menu()
		GameManager.start_new_game()

	input.text_submitted.connect(submit_fn)
	hint.pressed.connect(func(): submit_fn.call(input.text))

func _on_menu_button_pressed() -> void:
	$AnimationPlayer.play("menu_idle")
	$SettingsContent.hide()
	$ChaptersContent.hide()
	$MenuContent.show()

func _on_settings_button_pressed() -> void:
	$AnimationPlayer.play("settings_idle")
	$MenuContent.hide()
	$ChaptersContent.hide()
	$SettingsContent.show()

func _on_chapters_button_pressed() -> void:
	$AnimationPlayer.play("chapters_idle")
	$MenuContent.hide()
	$SettingsContent.hide()
	$ChaptersContent.show()
