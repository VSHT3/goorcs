class_name TowerReward
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var accent: Color = Color(0.76, 0.68, 0.4)

# Local board presentation: opaque height in cells and base in normalized texture coordinates.
@export var board_height: float = 1.45
@export var board_anchor: Vector2 = Vector2(0.5, 0.94)
