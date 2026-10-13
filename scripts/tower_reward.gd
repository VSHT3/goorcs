class_name TowerReward
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
# Remaining procedural identities, used only without an imported icon.
@export_enum("Arrow tower", "Rune obelisk") var icon_kind: int = 0
@export var accent: Color = Color(0.76, 0.68, 0.4)
