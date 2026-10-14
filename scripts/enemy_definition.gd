class_name EnemyDefinition
extends Resource

# Multipliers apply to the match's wave-scaled baseline; artwork is local only.
@export var id: StringName
@export var title: String
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var send_cost: int = 20
@export var send_income: int = 2
@export var texture: Texture2D
@export var source_faces_left: bool = false
