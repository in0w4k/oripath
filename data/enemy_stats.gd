class_name EnemyStats
extends Resource

@export var enemy_name: String = "Enemy"
@export var max_health: int = 2
@export var damage: int = 1
@export var score_value: int = 100

@export_group("Navigation")
@export var patrol_speed: float = 2.8
@export var waypoint_reach_dist: float = 0.9
@export var arena_limit: float = 13.5
@export var body_radius: float = 0.65
@export var sight_range: float = 18.0

@export_group("Patroller Combat")
@export var chase_speed: float = 4.5
@export var lunge_speed: float = 3.0
@export var sight_fov_deg: float = 130.0
@export var close_sense_range: float = 5.0
@export var lose_sight_time: float = 4.0
@export var attack_range: float = 2.4
@export var attack_hit_range: float = 3.0
@export var wind_up_time: float = 0.42
@export var cooldown_time: float = 0.85

@export_group("Charger Combat")
@export var charge_trigger_range: float = 7.0
@export var fuse_time: float = 0.55
@export var dash_speed: float = 11.5
@export var max_dash_time: float = 0.95
@export var explode_trigger_dist: float = 2.1
@export var blast_radius: float = 3.8
@export var stun_duration: float = 1.2

@export_group("Ranged Combat")
@export var min_preferred_dist: float = 5.5
@export var max_preferred_dist: float = 13.5
@export var reposition_speed: float = 3.5
@export var retreat_speed: float = 4.2
@export var aim_wind_up: float = 0.5
@export var aim_track_ratio: float = 0.82
@export var projectile_speed: float = 16.0
@export var projectile_hit_radius: float = 0.85
@export var projectile_lifetime: float = 4.0
