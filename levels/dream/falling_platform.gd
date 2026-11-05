extends RigidBody3D

var is_falling = false
var start_position: Vector3
var can_shake = true

@onready var impact_sound: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	start_position = global_position
	freeze = true
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	if impact_sound:
		impact_sound.pitch_scale = 0.2

func drop() -> void:
	is_falling = true
	can_shake = true
	freeze = false

func respawn() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	can_shake = true
	is_falling = true
	global_position = start_position

func _on_body_entered(_body: Node3D) -> void:
	if is_falling and can_shake:
		can_shake = false
		is_falling = false

		GameManager.camera_shake.emit(0.6, 0.45)	

		if impact_sound:
			impact_sound.volume_db = 10.0
			impact_sound.play()
			
			var tw = create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(impact_sound, "volume_db", -80.0, 0.15)
			tw.finished.connect(impact_sound.stop)