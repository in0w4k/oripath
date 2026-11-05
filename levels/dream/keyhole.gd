extends Area3D

@export var falling_platform: RigidBody3D
@onready var audio_lock: AudioStreamPlayer = $AudioStreamPlayer
@onready var sprite: Sprite3D = $Sprite3D

var block15: CSGBox3D
var is_unlocked = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if owner and owner.has_node("%block15"):
		block15 = owner.get_node("%block15")
	else:
		block15 = get_tree().root.find_child("block15", true, false)
	
	if block15:
		block15.visible = false
	
	if owner and owner.has_node("%FallingPlatform"):
		falling_platform = owner.get_node("%FallingPlatform")
	else:
		falling_platform = get_tree().root.find_child("FallingPlatform", true, false)

func _on_body_entered(body: Node3D) -> void:
	if is_unlocked:
		return
	if body.is_in_group("player"):
		if GameManager.has_all_keys():
			try_unlock()
		else:
			var count = GameManager.collected_keys.size()
			GameManager.show_notification.emit("Замок закрыт. Нужно частей: %d/2" % count)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.show_notification.emit("")	

func try_unlock():
	if GameManager.has_all_keys():
		is_unlocked = true

		if audio_lock:
			audio_lock.play()

		if block15:
			block15.visible = true
		
		GameManager.portal_opened.emit()
		
		if falling_platform and falling_platform.has_method("drop"):
			falling_platform.drop()

		if sprite:
			sprite.visible = false