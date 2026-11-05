extends Area3D

signal player_entered_door

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var col_shape: CollisionShape3D = $CollisionShape3D

var is_open: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false

func open_door() -> void:
	visible = true
	monitoring = true
	is_open = true
	if anim_tree:
		anim_tree["parameters/conditions/is_open"] = true
	if anim_player:
		await anim_player.animation_finished
		if anim_tree:
			anim_tree["parameters/conditions/is_idle"] = true

func _on_body_entered(body: Node3D) -> void:
	if not is_open or is_transitioning:
		return
	if body.is_in_group("player"):
		is_transitioning = true
		player_entered_door.emit()
		
		var world = get_tree().current_scene
		if world and world.has_method("on_door_entered"):
			world.on_door_entered()
