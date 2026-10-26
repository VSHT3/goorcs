class_name CommanderRules
extends RefCounted

const KNIGHT: StringName = &"knight"
const PRIESTESS: StringName = &"priestess"
const RADIUS: float = 2.5
const BASTION_DAMAGE_BONUS: float = 0.15
const SANCTUARY_ATTACK_RATE_BONUS: float = 0.15
const RALLY_ATTACK_RATE_BONUS: float = 0.30
const RALLY_DURATION: float = 8.0
const STASIS_SLOW: float = 0.40
const STASIS_DURATION: float = 6.0
const ABILITY_COOLDOWN: float = 45.0
const CLEAR_COST: int = 25
const OBSTACLE_COUNT: int = 9
const OBSTACLE_VARIANT_COUNT: int = 4


static func valid(id: StringName) -> bool:
	return id in [KNIGHT, PRIESTESS]


static func title(id: StringName) -> String:
	match id:
		KNIGHT:
			return "Knight"
		PRIESTESS:
			return "Priestess"
	return ""


static func ability_title(id: StringName) -> String:
	match id:
		KNIGHT:
			return "Rally"
		PRIESTESS:
			return "Stasis"
	return ""


static func generate(id: StringName, layout: PathLayout, rng: RandomNumberGenerator) -> Dictionary:
	if not valid(id) or layout == null or rng == null:
		return {}
	# Reserve a shortest entrance/base route, straight on the normal match board.
	# Terrain never consumes path budget or forces a longer route around it.
	var reserved: Dictionary[Vector2i, bool] = {}
	var cell: Vector2i = layout.entrance
	reserved[cell] = true
	while cell.x != layout.base.x:
		cell.x += 1 if cell.x < layout.base.x else -1
		reserved[cell] = true
	while cell.y != layout.base.y:
		cell.y += 1 if cell.y < layout.base.y else -1
		reserved[cell] = true
	if reserved.size() - 2 > layout.budget:
		return {}
	var candidates: Array[Vector2i] = []
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			cell = Vector2i(x, y)
			if not reserved.has(cell) and not layout.has_path(cell):
				candidates.append(cell)
	# Reserve one real horizontal building footprint before choosing terrain.
	# Each independently generated board must have room for an Orcapult.
	var build_pairs: Array[Vector2i] = []
	for candidate: Vector2i in candidates:
		var neighbor: Vector2i = candidate + Vector2i.RIGHT
		if layout.contains(neighbor) and not reserved.has(neighbor) and not layout.has_path(neighbor):
			build_pairs.append(candidate)
	if build_pairs.is_empty():
		return {}
	var build_anchor: Vector2i = build_pairs[rng.randi_range(0, build_pairs.size() - 1)]
	var minimum_build_cells: int = mini(8, maxi(2, layout.dimensions.x * layout.dimensions.y / 4))
	var obstacle_count: int = mini(OBSTACLE_COUNT, layout.dimensions.x * layout.dimensions.y / 14)
	obstacle_count = mini(obstacle_count, candidates.size() - minimum_build_cells - 1)
	if obstacle_count < 0:
		return {}
	candidates.erase(build_anchor)
	candidates.erase(build_anchor + Vector2i.RIGHT)
	for index: int in range(obstacle_count + 1):
		var other: int = rng.randi_range(index, candidates.size() - 1)
		var swap: Vector2i = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	var obstacles: Array[Vector2i] = []
	# A host-rolled rotation guarantees all four looks on ordinary boards.
	# Parallel metadata follows its occupied cell through removals and growth.
	var obstacle_variants: Array[int] = []
	var variant_offset: int = rng.randi_range(0, OBSTACLE_VARIANT_COUNT - 1)
	for index: int in range(obstacle_count):
		obstacles.append(candidates[index + 1])
		obstacle_variants.append((index + variant_offset) % OBSTACLE_VARIANT_COUNT)
	return {
		"id": String(id), "landmark": candidates[0], "obstacles": obstacles,
		"obstacle_variants": obstacle_variants,
		"ability_remaining": 0.0, "cooldown_remaining": 0.0, "ability_target": -1,
	}
