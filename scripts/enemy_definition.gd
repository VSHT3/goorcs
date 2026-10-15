class_name EnemyDefinition
extends Resource

# Multipliers apply to the match's wave-scaled baseline; artwork is local only.
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var base_damage: int = 1
@export var spawn_weight: int = 1
@export var first_wave: int = 1
# Zero means unlimited. Share caps this type's total weight, not its head count.
@export var max_per_wave: int = 0
# Finite caps gain this amount every interval waves after first_wave.
@export var count_cap_growth: int = 0
@export var count_cap_growth_interval: int = 1
@export_range(0.0, 1.0) var max_weight_share: float = 1.0
@export var send_cost: int = 20
@export var send_income: int = 2
@export var texture: Texture2D
@export var source_faces_left: bool = false

# Local board presentation only; never part of the host's combat rules.
@export var board_height: float = 0.50
@export var board_anchor: Vector2 = Vector2(0.5, 0.90625)
