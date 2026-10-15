class_name CombatRules
extends Resource

const DEFAULT_ENEMIES: Array[EnemyDefinition] = [
	preload("res://resources/combat/enemies/grunt.tres"),
	preload("res://resources/combat/enemies/runner.tres"),
	preload("res://resources/combat/enemies/brute.tres"),
]

# Provisional match-only playtest values, independent of collection progression.
@export var base_health: int = 10
@export var enemy_health: int = 8
@export var enemy_speed: float = 2.0
@export var wave_weight: int = 6
@export var spawn_interval: float = 0.75
@export_range(0.0, 0.499, 0.001) var spawn_jitter_ratio: float = 0.4
@export var enemy_definitions: Array[EnemyDefinition] = DEFAULT_ENEMIES
@export var tower_definitions: Array[TowerDefinition] = [
	preload("res://resources/combat/towers/arrow_tower.tres"),
	preload("res://resources/combat/towers/orc_ballista.tres"),
	preload("res://resources/combat/towers/rune_obelisk.tres"),
]
@export var health_growth: int = 2
@export var speed_growth: float = 0.15
@export var wave_weight_growth: int = 2
@export var starting_coins: int = 200
@export var kill_bounty: int = 3
@export var wave_reward: int = 30
@export var wave_reward_growth: int = 5
@export var send_cutoff_seconds: float = 3.0
@export var main_round_interval: int = 10
@export var ready_window_seconds: float = 20.0
@export var tiles_per_expansion: int = 6
