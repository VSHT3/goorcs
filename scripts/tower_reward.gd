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
# Optional fixed-canvas weapon poses, ordered N, NE, E, SE, S, SW, W, NW.
# Both arrays are empty for ordinary art, or contain eight aligned layers/tips.
@export var directional_weapon_textures: Array[Texture2D] = []
@export var directional_projectile_origins: PackedVector2Array = PackedVector2Array()
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
# Orcapult throwing arm: a separate layer rotated about catapult_arm_pivot
# (arm-texture pixels), placed at catapult_pivot in the icon's texture space.
# Variants may swap it with "catapult_arm_texture".
@export var catapult_arm_texture: Texture2D
@export var catapult_pivot: Vector2 = Vector2.ZERO
@export var catapult_arm_pivot: Vector2 = Vector2.ZERO


func board_variant(evolution: String, followup: String = "", steps: Array = [], tiers: Array = []) -> Dictionary:
	# The latest purchased branch upgrade with its own art wins, then the
	# follow-up and evolution, then the latest stat/special tier.
	for index: int in range(steps.size() - 1, -1, -1):
		if board_variants.has(steps[index]):
			return board_variants[steps[index]]
	if board_variants.has(followup):
		return board_variants[followup]
	if board_variants.has(evolution):
		return board_variants[evolution]
	for index: int in range(tiers.size() - 1, -1, -1):
		if board_variants.has(tiers[index]):
			return board_variants[tiers[index]]
	return EMPTY_BOARD_VARIANT


const EMPTY_BOARD_VARIANT: Dictionary = {}
