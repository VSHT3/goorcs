class_name TowerReward
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
# Procedural collection icon identity, not combat behavior.
@export_range(0, 2) var icon_kind: int = 0
@export var accent: Color = Color(0.76, 0.68, 0.4)
