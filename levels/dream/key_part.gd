extends Area3D

@export var key_id = 1
@export var texture: Texture2D

@onready var sprite: Sprite3D = $Sprite3D

var start_y = 0.0
var time_passed = 0.0

func _ready() -> void:
	start_y = position.y
	if texture and sprite:
		sprite.texture = texture
	body_entered.connect(_on_body_entered)
	


func _process(delta: float) -> void:
	time_passed += delta * 3.0
	position.y = start_y + sin(time_passed) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if GameManager.has_method("collect_key"):
			GameManager.collect_key(key_id)
		queue_free()
