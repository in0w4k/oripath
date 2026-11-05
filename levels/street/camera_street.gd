extends Camera3D

@export var smooth_speed: float = 4.0
@export var min_x: float = -20.0
@export var max_x: float = 24.0

var target: Node3D = null
var is_cinematic: bool = false

const DEFAULT_Y = 4.2
const DEFAULT_Z = 8.5
const DEFAULT_ROT = Vector3(-15.0, 0.0, 0.0)

func _ready() -> void:
	global_position.y = DEFAULT_Y
	global_position.z = DEFAULT_Z
	rotation_degrees = DEFAULT_ROT

func _process(delta: float) -> void:
	if is_cinematic:
		return
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return
	var target_x = clamp(target.global_position.x, min_x, max_x)
	global_position.x = lerp(global_position.x, target_x, smooth_speed * delta)

func swoop_to_door(door_pos: Vector3 = Vector3(30.99, 2.0, -5.0), duration: float = 2.0) -> Tween:
	is_cinematic = true
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var cam_door_pos = Vector3(door_pos.x - 4.5, door_pos.y + 0.6, door_pos.z + 3.2)
	tw.tween_property(self, "global_position", cam_door_pos, duration)
	tw.tween_property(self, "rotation_degrees", Vector3(-6.0, -38.0, 0.0), duration)
	return tw

func swoop_back_to_player(duration: float = 1.8) -> Tween:
	if not target:
		target = get_tree().get_first_node_in_group("player")
	var target_x = clamp(target.global_position.x if target else 0.0, min_x, max_x)
	var cam_player_pos = Vector3(target_x, DEFAULT_Y, DEFAULT_Z)
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", cam_player_pos, duration)
	tw.tween_property(self, "rotation_degrees", DEFAULT_ROT, duration)
	tw.finished.connect(func(): is_cinematic = false)
	return tw
