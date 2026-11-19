class_name LevelData
extends Resource

enum GoalType {
	SURVIVE,
	ELIMINATE
}

@export var level_id: int = 1
@export var level_title: String = "УРОВЕНЬ 1 · ПАЛАТА"
@export var goal_type: GoalType = GoalType.SURVIVE
@export var goal_kills: int = 6
@export var time_limit: float = 35.0
@export var completion_bonus: int = 300
@export var light_energy_scale: float = 1.0

@export_group("Prefabs")
@export var enemy_scenes: Array[PackedScene] = []
@export var pickup_scenes: Array[PackedScene] = []

@export_group("Initial Spawns")
@export var initial_enemy_scenes: Array[PackedScene] = []
@export var initial_enemy_positions: Array[Vector3] = []
@export var initial_pickup_scenes: Array[PackedScene] = []
@export var initial_pickup_positions: Array[Vector3] = []

@export_group("Arena Spawn Points & Waves")
@export var enemy_spawn_points: Array[Vector3] = []
@export var pickup_spawn_points: Array[Vector3] = []
@export var waves: Array[WaveData] = []
@export var pickup_interval: float = 8.5
@export var max_active_pickups: int = 3
@export var min_enemy_player_dist: float = 8.5
@export var min_pickup_player_dist: float = 4.5
@export var min_entity_spacing: float = 2.8
@export var telegraph_duration: float = 0.85
