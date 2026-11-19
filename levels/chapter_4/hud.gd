extends CanvasLayer

@onready var ammo_label: Label = $Ammo
@onready var health_label: Label = $HealthLabel
@onready var timer_label: Label = $TimerLabel
@onready var menu: Control = get_node_or_null("Menu")

var last_hp: int = -1
var damage_flash: ColorRect
var level_info_label: Label
var score_label: Label
var pause_button: Button

func _ready() -> void:
	var crt := get_node_or_null("ColorRect")

	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.color = Color(0.85, 0.05, 0.05, 0.0)
	add_child(damage_flash)

	level_info_label = Label.new()
	level_info_label.name = "LevelInfoLabel"
	level_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_info_label.offset_top = 62.0
	level_info_label.offset_bottom = 96.0
	level_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_info_label.add_theme_font_size_override("font_size", 22)
	level_info_label.add_theme_constant_override("outline_size", 6)
	level_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(level_info_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_left = -260.0
	score_label.offset_top = 24.0
	score_label.offset_right = -28.0
	score_label.offset_bottom = 66.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_constant_override("outline_size", 7)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.text = "ОЧКИ: 0"
	add_child(score_label)

	var is_mobile := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")
	if is_mobile:
		pause_button = Button.new()
		pause_button.name = "PauseButton"
		pause_button.text = "МЕНЮ"
		pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pause_button.offset_left = -130.0
		pause_button.offset_top = 74.0
		pause_button.offset_right = -28.0
		pause_button.offset_bottom = 118.0
		pause_button.add_theme_font_size_override("font_size", 20)
		pause_button.pressed.connect(_on_pause_pressed)
		add_child(pause_button)

	if crt:
		var idx := crt.get_index()
		move_child(damage_flash, idx)
		move_child(level_info_label, crt.get_index())
		move_child(score_label, crt.get_index())
		if pause_button:
			move_child(pause_button, crt.get_index())

func _on_pause_pressed() -> void:
	if menu and menu.has_method("open_menu"):
		menu.open_menu()

func setup_level_hud(title: String, goal_text: String, score_val: int) -> void:
	if level_info_label:
		level_info_label.text = title + " · " + goal_text
	update_score(score_val)

func update_goal(title: String, goal_text: String) -> void:
	if level_info_label:
		level_info_label.text = title + " · " + goal_text

func update_score(score_val: int) -> void:
	if score_label:
		score_label.text = "ОЧКИ: " + str(score_val)

func _on_weapon_ammo_changed(in_mag: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = str(in_mag) + " / " + str(reserve)

func _on_health_changed(current: int, max_hp: int) -> void:
	if last_hp != -1 and current < last_hp and damage_flash:
		damage_flash.color.a = 0.45
		var tw := create_tween()
		tw.tween_property(damage_flash, "color:a", 0.0, 0.35)
	last_hp = current

	if not health_label:
		return
	var hearts := ""
	for i in range(max_hp):
		hearts += "♥ " if i < current else "♡ "
	health_label.text = hearts.strip_edges()

func _on_time_updated(seconds_left: float) -> void:
	if not timer_label:
		return
	var s := ceili(seconds_left)
	var mins := int(floor(float(s) / 60.0))
	var secs := s % 60
	timer_label.text = "%d:%02d" % [mins, secs]

func show_escape_banner() -> void:
	var banner := Label.new()
	banner.text = "ВЫХОД ОТКРЫТ!"
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.add_theme_font_size_override("font_size", 42)
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(banner)

	var crt := get_node_or_null("ColorRect")
	if crt:
		move_child(banner, crt.get_index())

	var tw := create_tween().set_loops(4)
	tw.tween_property(banner, "modulate:a", 0.1, 0.25)
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	await tw.finished
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(banner):
		banner.queue_free()
