extends Area3D

@export var stats: PickupStats

func _ready() -> void:
	add_to_group("chapter4_pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var w := body.get_node_or_null("Weapon")
		var sfx := body.get_node_or_null("PickupSound")
		var ammo_amount := stats.amount if stats else 8
		if w and w.has_method("add_ammo"):
			w.add_ammo(ammo_amount)
			if sfx:
				sfx.play()
			queue_free()
