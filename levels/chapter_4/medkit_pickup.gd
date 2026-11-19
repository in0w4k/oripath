extends Area3D

@export var stats: PickupStats

func _ready() -> void:
	add_to_group("chapter4_pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var h := body.get_node_or_null("Health")
		var sfx := body.get_node_or_null("PickupSound")
		var heal_amount := stats.amount if stats else 2
		if h and h.has_method("heal"):
			if h.current_health < h.max_health:
				h.heal(heal_amount)
				if sfx:
					sfx.play()
				queue_free()
