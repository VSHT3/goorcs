class_name CombatRules
extends Resource

# Provisional match-only playtest values, independent of collection progression.
@export var base_health: int = 10
@export var enemy_health: int = 8
@export var enemy_speed: float = 2.0
@export var wave_weight: int = 6
@export var spawn_interval: float = 0.75
@export_range(0.0, 0.499, 0.001) var spawn_jitter_ratio: float = 0.4
# Fractions of the original interval, shared by regular and paid-send streams.
@export_range(0.0, 1.0, 0.001) var spawn_interval_reduction_per_wave: float = 0.005
@export_range(0.0, 0.999, 0.001) var max_spawn_interval_reduction: float = 0.5
@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")
@export var health_growth: int = 2
@export var speed_growth: float = 0.15
@export var wave_weight_growth: int = 2
@export var starting_coins: int = 200
@export var kill_bounty: int = 3
@export var wave_reward: int = 30
@export var wave_reward_growth: int = 5
@export var send_spawn_interval: float = 0.35
@export var main_round_interval: int = 10
@export var ready_window_seconds: float = 20.0
@export var tiles_per_expansion: int = 6


func _init() -> void:
	# Each rules resource owns its registration arrays; definitions remain shared
	# until a caller explicitly duplicates a definition to tune a fixture.
	catalog = catalog.duplicate() as ContentCatalog
