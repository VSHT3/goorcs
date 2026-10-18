class_name CombatRules
extends Resource

# Provisional match-only playtest values, independent of collection progression.
# Captured by MatchCombat at admission; never a command-controlled match bypass.
@export var sandbox_mode: bool = false
@export var base_health: int = 100
@export var enemy_health: int = 8
@export var enemy_speed: float = 2.0
@export var wave_weight: int = 6
@export var spawn_interval: float = 0.75
@export_range(0.0, 0.499, 0.001) var spawn_jitter_ratio: float = 0.4
# Fractions of the original interval, shared by regular and paid-send streams.
@export_range(0.0, 1.0, 0.001) var spawn_interval_reduction_per_wave: float = 0.005
@export_range(0.0, 0.999, 0.001) var max_spawn_interval_reduction: float = 0.5
@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")
@export var roll_rules: TowerRollRules
@export var boss_reward_rules: BossRewardRules
@export var starting_reroll_currency: int = 0
@export var clear_reroll_currency: int = 3
@export var health_growth: int = 1
# Each milestone adds a fraction of original speed; spans grow 5, 10, 15... rounds.
@export_range(0.0, 1.0, 0.01, "or_greater") var speed_growth_fraction: float = 0.1
@export_range(1, 1000, 1, "or_greater") var speed_growth_rounds: int = 5
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


func valid_speed_progression() -> bool:
	return is_finite(enemy_speed) and enemy_speed >= 0.0 and is_finite(speed_growth_fraction) and speed_growth_fraction >= 0.0 and speed_growth_rounds > 0


func enemy_speed_at_wave(wave_number: int) -> float:
	var elapsed: int = maxi(0, wave_number - 1)
	# Invert triangular milestone boundaries without looping through earlier rounds.
	var completed: int = floori((sqrt(1.0 + 8.0 * float(elapsed) / speed_growth_rounds) - 1.0) * 0.5)
	var boundary: float = float(speed_growth_rounds) * completed * (completed + 1) * 0.5
	var progress: float = (float(elapsed) - boundary) / (float(speed_growth_rounds) * (completed + 1))
	return enemy_speed * (1.0 + speed_growth_fraction * (completed + progress))
