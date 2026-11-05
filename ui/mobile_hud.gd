extends Control

@export var show_dream_tools: bool = false

@onready var health_label: Label = $SafeArea/Layout/HealthLabel
@onready var score_label: Label = $SafeArea/Layout/ScorePanel/ScoreLabel
@onready var notification_label: Label = $SafeArea/Layout/NotificationLabel
@onready var dream_tools: Control = $SafeArea/Layout/DreamTools
@onready var run_button: Control = $SafeArea/Layout/RunButton
@onready var pause_button: Control = $SafeArea/Layout/PauseButton

var _notice_token: int = 0
var force_hidden: bool = false

func _ready() -> void:
	if dream_tools:
		dream_tools.visible = show_dream_tools
	if run_button:
		run_button.visible = not show_dream_tools
	if notification_label:
		notification_label.text = ""

	GameManager.health_changed.connect(update_health)
	GameManager.show_notification.connect(show_notification_text)
	update_health(GameManager.current_health, GameManager.max_health)

func _process(_delta: float) -> void:
	var menu_node := get_tree().get_first_node_in_group("menu") as Control
	var menu_open := menu_node != null and menu_node.visible
	visible = not force_hidden and not menu_open and not GameManager.is_game_over

func update_health(current_hp: int, max_hp: int) -> void:
	if not health_label:
		return
	var text := ""
	for i in range(max_hp):
		text += "♥ " if i < current_hp else "♡ "
	health_label.text = text.strip_edges()

func set_score_text(text: String) -> void:
	if score_label:
		score_label.text = text

func show_notification_text(text: String) -> void:
	if not notification_label:
		return
	_notice_token += 1
	var my_token := _notice_token
	notification_label.text = text
	if text == "":
		return
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(notification_label) and _notice_token == my_token:
		notification_label.text = ""
