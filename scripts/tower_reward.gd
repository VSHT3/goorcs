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

# Board-only layers leave collection/source artwork intact. Rig coordinates share
# the icon's texture-local space, so inherited tower variants need no ID switches.
@export var board_texture: Texture2D
# Optional branch records: {texture, board_height, board_anchor, archer_pivot,
# secondary_sprite_offset, additional_archer_offsets, portrait_bounds}.
# Advancement keys use the evolution argument; follow-up keys retain precedence.
@export var board_variants: Dictionary = {}
@export var mirror_board: bool = false
@export var archer_head_texture: Texture2D
@export var archer_body_texture: Texture2D
@export var archer_pivot: Vector2 = Vector2.ZERO
# A negative muzzle coordinate uses the ordinary centered projectile origin.
@export var projectile_origin: Vector2 = Vector2(-1, -1)
@export var projectile_length: float = 0.18
@export var projectile_width: float = 1.3
@export var secondary_sprite_offset: Vector2
# Rear archers reuse the same layered rig with these texture-local offsets.
@export var additional_archer_offsets: PackedVector2Array = PackedVector2Array()


func board_variant(evolution: String, followup: String = "") -> Dictionary:
	if board_variants.has(followup):
		return board_variants[followup]
	if board_variants.has(evolution):
		return board_variants[evolution]
	return EMPTY_BOARD_VARIANT


const EMPTY_BOARD_VARIANT: Dictionary = {}
