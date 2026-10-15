class_name TowerDefinition
extends Resource

const SECOND_ARCHER_ATTACK_RATE_MULTIPLIER: float = 1.1
const BOUNCE_DAMAGE_MULTIPLIER: float = 0.5

@export var reward: TowerReward
@export var damage: int = 2
@export var range_cells: float = 3.0
@export var interval: float = 0.75
@export var cost: int = 45
@export var upgrade_base_cost: int = 30
@export var damage_upgrade_bonus: int = 1
@export var speed_upgrade_multiplier: float = 0.8
@export var area_attack: bool = false
@export var special_upgrade: String = ""
@export var special_upgrade_title: String = ""
@export var special_upgrade_cost: int = 0
@export var evolutions: Dictionary = {}
