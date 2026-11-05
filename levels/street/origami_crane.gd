extends Area3D

@export var crane_id: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world and world.has_method("collect_crane"):
			world.collect_crane(crane_id)
		if GameManager.audio_coin:
			GameManager.audio_coin.play()
		queue_free()
