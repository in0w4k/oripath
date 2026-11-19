extends Node3D

signal health_changed(current: int, max_hp: int)
signal died

@export var stats: PlayerStats

var max_health: int = 3
var current_health: int = 3
var is_invincible: bool = false

func _ready() -> void:
	max_health = stats.max_health if stats else 3
	current_health = max_health
	health_changed.emit.call_deferred(current_health, max_health)

func take_damage(amount: int) -> void:
	if is_invincible or current_health <= 0:
		return

	max_health = stats.max_health if stats else max_health
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)

	if has_node("HurtSound"):
		$HurtSound.play()

	if current_health == 0:
		died.emit()
		get_tree().reload_current_scene.call_deferred()
	else:
		_trigger_invincibility()

func heal(amount: int) -> void:
	max_health = stats.max_health if stats else max_health
	if current_health <= 0 or current_health >= max_health:
		return
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	if has_node("HealSound"):
		$HealSound.play()

func _trigger_invincibility() -> void:
	var inv_time := stats.invincibility_duration if stats else 0.6
	is_invincible = true
	await get_tree().create_timer(inv_time).timeout
	is_invincible = false
