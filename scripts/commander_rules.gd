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
const OBSTACLE_COUNT: int = 3


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
	# Keep at least eight build cells on ordinary boards; tiny custom boards
	# still need one quarter of their ground free in addition to the route.
	var minimum_build_cells: int = mini(8, maxi(1, layout.dimensions.x * layout.dimensions.y / 4))
	if candidates.size() < OBSTACLE_COUNT + 1 + minimum_build_cells:
		return {}
	for index: int in range(OBSTACLE_COUNT + 1):
		var other: int = rng.randi_range(index, candidates.size() - 1)
		var swap: Vector2i = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	var obstacles: Array[Vector2i] = []
	for index: int in range(1, OBSTACLE_COUNT + 1):
		obstacles.append(candidates[index])
	return {
		"id": String(id), "landmark": candidates[0], "obstacles": obstacles,
		"ability_remaining": 0.0, "cooldown_remaining": 0.0, "ability_target": -1,
	}
