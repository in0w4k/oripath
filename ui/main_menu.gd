extends Control

@onready var start_button = $MenuContent/StartButton
@onready var restart_button = $MenuContent/RestartButton
@onready var quit_button = $MenuContent/QuitButton

@onready var volume_slider: HSlider = $SettingsContent/VolumeSlider
@onready var fullscreen_check: CheckBox = $SettingsContent/FullscreenCheck
@onready var music_check: CheckBox = $SettingsContent/MusicCheck
@onready var settings_content: VBoxContainer = $SettingsContent
@onready var chapters_content: VBoxContainer = $ChaptersContent

var best_score_label: Label
var level_buttons: Array[Button] = []
var reset_button: Button
var confirm_overlay: ColorRect
var confirm_info_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	start_button.pressed.connect(on_start_pressed)
	restart_button.pressed.connect(on_restart_pressed)
	quit_button.pressed.connect(on_quit_pressed)

	_sync_settings_ui()

	volume_slider.value_changed.connect(on_volume_changed)
	fullscreen_check.toggled.connect(on_fullscreen_changed)
	music_check.toggled.connect(on_music_changed)

	_build_reset_progress_ui()
	_build_level_select_ui()

	if GameManager and GameManager.has_signal("save_changed"):
		GameManager.save_changed.connect(_on_save_changed)

	if not GameManager.game_started:
		open_menu()
	else:
		hide()

	$AnimationPlayer.play("menu_idle")

func _on_save_changed() -> void:
	_sync_settings_ui()
	_refresh_level_select()

func _sync_settings_ui() -> void:
	var slider_val := GameManager.music_volume * 100.0 if volume_slider.max_value > 1.0 else GameManager.music_volume
	volume_slider.set_value_no_signal(slider_val)
	fullscreen_check.set_pressed_no_signal(GameManager.is_fullscreen)
	music_check.set_pressed_no_signal(GameManager.is_music_on)

func _make_button_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border_col
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _build_reset_progress_ui() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	settings_content.add_child(spacer)

	reset_button = Button.new()
	reset_button.name = "ResetProgressButton"
	reset_button.text = "СБРОСИТЬ ПРОГРЕСС"
	reset_button.add_theme_font_size_override("font_size", 20)
	reset_button.add_theme_color_override("font_color", Color.WHITE)
	reset_button.add_theme_color_override("font_hover_color", Color.WHITE)
	reset_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	reset_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.75, 0.16, 0.14, 1.0), Color.BLACK))
	reset_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.88, 0.22, 0.18, 1.0), Color.BLACK))
	reset_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.55, 0.1, 0.1, 1.0), Color.BLACK))
	reset_button.pressed.connect(_on_reset_button_pressed)
	settings_content.add_child(reset_button)

	confirm_overlay = ColorRect.new()
	confirm_overlay.name = "ConfirmResetOverlay"
	confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_overlay.visible = false
	add_child(confirm_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 200)
	panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.97, 0.96, 0.94, 1.0), Color.BLACK))
	confirm_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "СБРОСИТЬ ВЕСЬ ПРОГРЕСС?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.BLACK)
	box.add_child(title)

	confirm_info_label = Label.new()
	confirm_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_info_label.add_theme_font_size_override("font_size", 18)
	confirm_info_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0))
	box.add_child(confirm_info_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	box.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelResetButton"
	cancel_btn.text = "ОТМЕНА"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	cancel_btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.2, 0.2, 0.2, 1.0), Color.BLACK))
	cancel_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.32, 0.32, 0.32, 1.0), Color.BLACK))
	cancel_btn.pressed.connect(_on_cancel_reset_pressed)
	btn_row.add_child(cancel_btn)

	var delete_btn := Button.new()
	delete_btn.name = "ConfirmDeleteButton"
	delete_btn.text = "УДАЛИТЬ"
	delete_btn.custom_minimum_size = Vector2(140, 44)
	delete_btn.add_theme_font_size_override("font_size", 20)
	delete_btn.add_theme_color_override("font_color", Color.WHITE)
	delete_btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.78, 0.16, 0.14, 1.0), Color.BLACK))
	delete_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.9, 0.22, 0.18, 1.0), Color.BLACK))
	delete_btn.pressed.connect(_on_confirm_delete_pressed)
	btn_row.add_child(delete_btn)

func _on_reset_button_pressed() -> void:
	if not confirm_overlay:
		return
	var best := GameManager.save_data.best_score if GameManager.save_data else 0
	var unlocked_cnt := GameManager.save_data.unlocked_levels.size() if GameManager.save_data else 1
	var total_cnt := maxi(3, GameManager.level_catalog.size())
	confirm_info_label.text = "Рекорд (%d) и открытые уровни (%d / %d) будут удалены.\nЭто действие нельзя отменить." % [best, unlocked_cnt, total_cnt]
	confirm_overlay.visible = true

func _on_cancel_reset_pressed() -> void:
	if confirm_overlay:
		confirm_overlay.visible = false

func _on_confirm_delete_pressed() -> void:
	if confirm_overlay:
		confirm_overlay.visible = false
	GameManager.reset_all_progress()
	_sync_settings_ui()
	_refresh_level_select()
	if GameManager.game_started:
		GameManager.return_to_main_menu()

func _build_level_select_ui() -> void:
	chapters_content.offset_left = -210.0
	chapters_content.offset_right = 210.0
	chapters_content.offset_top = -195.0
	chapters_content.offset_bottom = 195.0
	chapters_content.add_theme_constant_override("separation", 10)

	for child in chapters_content.get_children():
		if child is Control:
			(child as Control).hide()

	best_score_label = Label.new()
	best_score_label.name = "BestScoreLabel"
	best_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_score_label.add_theme_font_size_override("font_size", 22)
	best_score_label.add_theme_color_override("font_color", Color.BLACK)
	chapters_content.add_child(best_score_label)

	level_buttons.clear()
	var levels: Array[LevelData] = GameManager.level_catalog
	for lvl in levels:
		var btn := Button.new()
		btn.name = "LevelSelectButton_%d" % lvl.level_id
		btn.custom_minimum_size = Vector2(360, 48)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.42, 0.42, 1.0))
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(1.0, 1.0, 1.0, 0.92), Color.BLACK))
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.12, 0.12, 1.0), Color.BLACK))
		btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.05, 0.05, 0.05, 1.0), Color.BLACK))
		btn.add_theme_stylebox_override("disabled", _make_button_style(Color(0.8, 0.8, 0.8, 0.72), Color(0.45, 0.45, 0.45, 1.0)))
		var lvl_id := lvl.level_id
		btn.pressed.connect(func(): _on_level_selected(lvl_id))
		chapters_content.add_child(btn)
		level_buttons.append(btn)

	var story_row := HBoxContainer.new()
	story_row.alignment = BoxContainer.ALIGNMENT_CENTER
	story_row.add_theme_constant_override("separation", 10)
	chapters_content.add_child(story_row)

	var dream_btn := Button.new()
	dream_btn.text = "СОН"
	dream_btn.custom_minimum_size = Vector2(140, 36)
	dream_btn.add_theme_font_size_override("font_size", 16)
	dream_btn.add_theme_color_override("font_color", Color.BLACK)
	dream_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	dream_btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.95, 0.95, 0.95, 0.85), Color.BLACK))
	dream_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.15, 0.15, 1.0), Color.BLACK))
	dream_btn.pressed.connect(func(): on_chapter_selected(load("res://levels/dream/world_25d.tscn")))
	story_row.add_child(dream_btn)

	var street_btn := Button.new()
	street_btn.text = "УЛИЦА"
	street_btn.custom_minimum_size = Vector2(140, 36)
	street_btn.add_theme_font_size_override("font_size", 16)
	street_btn.add_theme_color_override("font_color", Color.BLACK)
	street_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	street_btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.95, 0.95, 0.95, 0.85), Color.BLACK))
	street_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.15, 0.15, 1.0), Color.BLACK))
	street_btn.pressed.connect(func(): on_chapter_selected(load("res://levels/street/world_3.tscn")))
	story_row.add_child(street_btn)

	_refresh_level_select()

func _refresh_level_select() -> void:
	if not GameManager or not GameManager.save_data:
		return
	var sd: SaveData = GameManager.save_data
	if best_score_label:
		best_score_label.text = "РЕКОРД: %d · %s" % [sd.best_score, GameManager.player_name]

	var levels: Array[LevelData] = GameManager.level_catalog
	for i in range(mini(levels.size(), level_buttons.size())):
		var lvl := levels[i]
		var btn := level_buttons[i]
		var unlocked := sd.is_level_unlocked(lvl.level_id)
		var completed := sd.is_level_completed(lvl.level_id)
		btn.disabled = not unlocked
		if not unlocked:
			btn.text = "🔒 " + lvl.level_title
		elif completed:
			var lvl_best := sd.get_level_best_score(lvl.level_id)
			btn.text = "✓ %s (%d)" % [lvl.level_title, lvl_best]
		else:
			btn.text = lvl.level_title

func _on_level_selected(level_id: int) -> void:
	if not GameManager.save_data.is_level_unlocked(level_id):
		return
	close_menu()
	GameManager.load_arena_level(level_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if confirm_overlay and confirm_overlay.visible:
			confirm_overlay.visible = false
			get_viewport().set_input_as_handled()
			return
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
	GameManager.save_progress()
	get_tree().quit()

func open_menu() -> void:
	_on_menu_button_pressed()
	update_menu()
	_sync_settings_ui()
	_refresh_level_select()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	if confirm_overlay:
		confirm_overlay.visible = false
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
	var norm_val := value / 100.0 if volume_slider.max_value > 1.0 else value
	GameManager.music_volume = norm_val
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(norm_val, 0.0001)))
	GameManager.save_settings()

func on_fullscreen_changed(checked: bool) -> void:
	GameManager.is_fullscreen = checked
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		if checked:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	GameManager.save_settings()

func on_music_changed(checked: bool) -> void:
	GameManager.is_music_on = checked
	if GameManager.has_node("Music"):
		GameManager.get_node("Music").stream_paused = not checked
	GameManager.save_settings()

func on_chapter_selected(scene: PackedScene) -> void:
	close_menu()
	GameManager.load_chapter(scene)

func show_name_prompt() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	bg.add_child(vbox)

	var prompt_label := Label.new()
	prompt_label.text = "Как вас зовут?"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 42)
	prompt_label.visible_characters = 0
	vbox.add_child(prompt_label)

	var input := LineEdit.new()
	input.custom_minimum_size = Vector2(320, 50)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.placeholder_text = "Введите имя..."
	input.text = GameManager.player_name if GameManager.player_name != "Игрок" else ""
	input.max_length = 16
	input.add_theme_font_size_override("font_size", 28)
	input.modulate.a = 0.0
	vbox.add_child(input)

	var hint := Button.new()
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

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(input, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(hint, "modulate:a", 0.6, 0.3)
	input.grab_focus()

	var submit_fn := func(entered_text: String):
		var clean_name := entered_text.strip_edges()
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
	_sync_settings_ui()
	$SettingsContent.show()

func _on_chapters_button_pressed() -> void:
	$AnimationPlayer.play("chapters_idle")
	$MenuContent.hide()
	$SettingsContent.hide()
	_refresh_level_select()
	$ChaptersContent.show()
