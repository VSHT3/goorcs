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

# Texture-local pixels for an authored muzzle and optional second-archer overlay.
# A negative muzzle coordinate uses the ordinary centered projectile origin.
@export var projectile_origin: Vector2 = Vector2(-1, -1)
@export var projectile_length: float = 0.18
@export var projectile_width: float = 1.3
@export var secondary_sprite_region: Rect2
@export var secondary_sprite_offset: Vector2
# Rear archers reuse the same crop and muzzle, with these texture-local offsets.
@export var additional_archer_offsets: PackedVector2Array = PackedVector2Array()
