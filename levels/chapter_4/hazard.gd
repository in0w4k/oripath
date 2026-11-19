class_name Hazard
extends Area3D

@export var stats: EnemyStats

var health: int = 1
var is_dead: bool = false

func _ready() -> void:
	if stats:
		health = stats.max_health
	body_entered.connect(_on_body_entered)

func get_damage() -> int:
	return stats.damage if stats else 1

func get_score_value() -> int:
	return stats.score_value if stats else 0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		apply_effect(body)

func apply_effect(target: Node3D) -> void:
	deal_damage(target)

func deal_damage(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var target_health := target.get_node_or_null("Health")
	if target_health and target_health.has_method("take_damage"):
		target_health.take_damage(get_damage())

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	flash_hit()
	if health <= 0:
		die(true)

func die(killed_by_player: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	if killed_by_player:
		var scene := get_tree().current_scene
		if scene and scene.has_method("on_enemy_killed"):
			scene.on_enemy_killed(get_score_value())
	queue_free()

func flash_hit() -> void:
	var sprite: Sprite3D = get_node_or_null("Sprite3D")
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 0.15, 0.08)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.08)
