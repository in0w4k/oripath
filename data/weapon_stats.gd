class_name WeaponStats
extends Resource

@export var max_ammo: int = 8
@export var reserve_ammo: int = 16
@export var fire_rate: float = 0.25
@export var hip_spread: float = 3.0
@export var aim_fov: float = 50.0
@export var normal_fov: float = 75.0
@export var sway_speed: float = 9.0
@export var sway_amount: Vector2 = Vector2(10.0, 7.0)
@export var bullet_speed: float = 25.0
@export var bullet_damage: int = 1
@export var bullet_lifetime: float = 2.2
@export var shot_words: Array[String] = ["ПИУ!", "ПАУ!", "БЭМ!", "ПИФ!", "ПАФ!"]
