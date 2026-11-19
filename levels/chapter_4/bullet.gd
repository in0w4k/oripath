extends Area3D

@onready var text_label: Label3D = $TextLabel

var speed: float = 25.0
var damage: int = 1
var max_lifetime: float = 2.2
var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(max_lifetime).timeout.connect(queue_free)

func setup(word_text: String, bullet_speed: float = 25.0, bullet_damage: int = 1, bullet_lifetime: float = 2.2) -> void:
	speed = bullet_speed
	damage = bullet_damage
	max_lifetime = bullet_lifetime
	if not text_label:
		text_label = get_node_or_null("TextLabel")
	if text_label:
		text_label.text = word_text

func _physics_process(delta: float) -> void:
	var step_dist := speed * delta
	var next_pos := global_position + direction * step_dist
	if _sweep_step(global_position, next_pos):
		return
	global_position = next_pos

func _sweep_step(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var exclude_rids: Array[RID] = [self.get_rid()]
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude_rids.append((player as CollisionObject3D).get_rid())

	var cursor := from_pos
	for _attempt in range(4):
		var query := PhysicsRayQueryParameters3D.create(cursor, to_pos)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclude_rids
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return false

		var collider: Object = hit.get("collider")
		if collider is Hazard:
			global_position = hit.get("position", to_pos)
			(collider as Hazard).take_damage(damage)
			queue_free()
			return true

		if collider is Node:
			var n := collider as Node
			if n.is_in_group("player") or n.name == "Floor" or n.name == "Ceiling" or n is Area3D:
				var hit_rid: RID = hit.get("rid", RID())
				if hit_rid.is_valid():
					exclude_rids.append(hit_rid)
				elif collider is CollisionObject3D:
					exclude_rids.append((collider as CollisionObject3D).get_rid())
				cursor = (hit.get("position", to_pos) as Vector3) + direction * 0.02
				continue

		global_position = hit.get("position", to_pos)
		queue_free()
		return true

	return false

func _on_area_entered(area: Area3D) -> void:
	if area is Hazard:
		(area as Hazard).take_damage(damage)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Floor" or body.name == "Ceiling":
		return
	queue_free()
