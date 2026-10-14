class_name CombatRules
extends Resource

# Provisional playtest values. Tower placement is free in this prototype.
@export var base_health: int = 10
@export var enemy_health: int = 8
@export var enemy_speed: float = 2.0
@export var enemies_per_wave: int = 6
@export var spawn_interval: float = 0.75
@export var tower_definitions: Array[TowerDefinition] = [
	preload("res://resources/combat/towers/arrow_tower.tres"),
	preload("res://resources/combat/towers/orc_ballista.tres"),
	preload("res://resources/combat/towers/rune_obelisk.tres"),
]
@export var health_growth: int = 2
