extends Node3D

@onready var mobile_hud = $CanvasLayer/MobileHUD

func _ready() -> void:
	GameManager.is_game_over = false
	GameManager.reset_health()
	if mobile_hud:
		mobile_hud.set_score_text("Ключи: %d / 2" % GameManager.collected_keys.size())
	GameManager.key_collected.connect(_on_key_collected)

func _on_key_collected(_key_id: int, total_keys: int) -> void:
	if mobile_hud:
		mobile_hud.set_score_text("Ключи: %d / 2" % total_keys)
