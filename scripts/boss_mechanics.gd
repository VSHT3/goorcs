class_name BossMechanics
extends RefCounted
## Geometry and motion decisions only. MatchCombat owns clocks, damage and events.

const EPSILON: float = 0.000000001
const CLEARANCE: float = 0.00001


static func has_abilities(definition: Dictionary) -> bool:
	return float(definition["tower_attack_interval"]) > 0.0 or float(definition["stomp_interval"]) > 0.0 or bool(definition["direct_movement"])


static func can_act(enemy: Dictionary) -> bool:
	return enemy["locomotion"] not in ["jump_charge", "jump"] or bool(enemy["jump_landing_blocked"])


static func cell_ahead(enemy: Dictionary) -> Vector2i:
	var route: Array = enemy["route"]
	var direction: Vector2 = Vector2(route.back()) - Vector2(route.front())
	return Vector2i((Vector2(enemy["pos"]) + direction.normalized() * CLEARANCE).round())


# Clip a segment to the same rounded-cell rectangle used by tower targeting.
static func rectangle_span(origin: Vector2, direction: Vector2, center: Vector2, radius: float) -> Vector2:
	var low: float = 0.0
	var high: float = 1.0
	for axis: int in range(2):
		var offset: float = origin[axis] - center[axis]
		if absf(direction[axis]) <= EPSILON:
			if absf(offset) >= radius:
				return Vector2(1.0, 0.0)
			continue
		var first: float = (-radius - offset) / direction[axis]
		var last: float = (radius - offset) / direction[axis]
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
	return Vector2(low, high)


static func blocker(enemy: Dictionary, towers: Array) -> Dictionary:
	var route: Array = enemy["route"]
	var origin := Vector2(route.front())
	var direction: Vector2 = Vector2(route.back()) - origin
	var best: Dictionary = {}
	var distance: float = INF
	for tower: Dictionary in towers:
		var span: Vector2 = rectangle_span(origin, direction, Vector2(tower["cell"]), 0.5)
		if span.y <= span.x or span.y < float(enemy["progress"]) + EPSILON:
			continue
		if span.x < distance or (span.x == distance and (best.is_empty() or int(tower["id"]) < int(best["id"]))):
			distance = span.x
			best = {"id": tower["id"], "cell": tower["cell"], "entry": span.x, "exit": span.y}
	return best


static func next_cell_boundary(enemy: Dictionary, progress: float) -> float:
	var route: Array = enemy["route"]
	var origin := Vector2(route.front())
	var direction: Vector2 = Vector2(route.back()) - origin
	var position: Vector2 = origin + direction * progress
	var cell: Vector2i = Vector2i((position + direction.normalized() * CLEARANCE).round())
	var boundary: float = 1.0
	for axis: int in range(2):
		if absf(direction[axis]) <= EPSILON:
			continue
		var edge: float = float(cell[axis]) + (0.5 if direction[axis] > 0.0 else -0.5)
		var candidate: float = (edge - origin[axis]) / direction[axis]
		if candidate > progress + EPSILON:
			boundary = minf(boundary, candidate)
	return boundary


# Search cells intersecting the direct line in forward order. Every candidate is
# between accepted endpoints, so no outside-board landing can be manufactured.
static func landing(enemy: Dictionary, towers: Array, after: float) -> float:
	var route: Array = enemy["route"]
	var origin := Vector2(route.front())
	var direction: Vector2 = Vector2(route.back()) - origin
	var cursor: float = maxf(float(enemy["progress"]), after) + CLEARANCE / direction.length()
	while cursor < 1.0 + EPSILON:
		var position: Vector2 = origin + direction * minf(cursor, 1.0)
		var cell: Vector2i = Vector2i(position.round())
		var occupied: bool = false
		for tower: Dictionary in towers:
			if tower["cell"] == cell:
				occupied = true
				break
		var projected: float = clampf((Vector2(cell) - origin).dot(direction) / direction.length_squared(), cursor, 1.0)
		if not occupied and projected > after + EPSILON:
			return projected
		var next: float = next_cell_boundary(enemy, cursor)
		if next >= 1.0 - EPSILON:
			break
		cursor = next + CLEARANCE / direction.length()
	return -1.0


static func prepare(enemy: Dictionary, definition: Dictionary, road: Dictionary, towers: Array) -> void:
	var route: Array = enemy["route"]
	var length: float = Vector2(route.front()).distance_to(Vector2(route.back()))
	var locomotion: String = enemy["locomotion"]
	if float(enemy["cast_remaining"]) > EPSILON or float(enemy["tower_attack_remaining"]) > EPSILON:
		enemy["speed"] = 0.0
		return
	if locomotion == "jump":
		var target: float = float(enemy["jump_target_progress"])
		var cell: Vector2i = Vector2i(Vector2(enemy["jump_to"]).round())
		for tower: Dictionary in towers:
			if tower["cell"] == cell:
				target = landing(enemy, towers, maxf(target, float(enemy["jump_blocker_exit"])))
				break
		if target < 0.0:
			enemy["speed"] = 0.0
			enemy["jump_landing_blocked"] = true
			return
		enemy["jump_landing_blocked"] = false
		enemy["jump_target_progress"] = target
		enemy["jump_to"] = origin_position(enemy, target)
		if enemy["animation"] != "jump":
			enemy["animation"] = "jump"
			enemy["animation_elapsed"] = float(enemy["jump_duration"]) - float(enemy["jump_remaining"])
		enemy["speed"] = maxf(0.0, target - float(enemy["progress"])) / maxf(float(enemy["jump_remaining"]), EPSILON)
		return
	if locomotion == "jump_charge":
		enemy["speed"] = 0.0
		return
	var obstruction: Dictionary = blocker(enemy, towers)
	if not obstruction.is_empty() and float(obstruction["entry"]) - CLEARANCE / length <= float(enemy["progress"]) + EPSILON:
		var target: float = landing(enemy, towers, float(obstruction["exit"]))
		enemy["speed"] = 0.0
		if target < 0.0:
			return
		enemy["locomotion"] = "jump_charge"
		enemy["animation"] = "jump_charge"
		enemy["animation_elapsed"] = 0.0
		enemy["jump_remaining"] = definition["jump_charge_duration"]
		enemy["jump_from"] = enemy["pos"]
		enemy["jump_to"] = origin_position(enemy, target)
		enemy["jump_target_progress"] = target
		enemy["jump_blocker_exit"] = obstruction["exit"]
		return
	var on_road: bool = road.has(cell_ahead(enemy))
	enemy["locomotion"] = "wheels" if on_road else "legs"
	var multiplier: float = float(definition["road_speed_multiplier"] if on_road else definition["grass_speed_multiplier"])
	enemy["speed"] = float(enemy["base_speed"]) * multiplier * (TowerDefinition.FREEZE_SPEED_MULTIPLIER if enemy["slowed"] else 1.0)


static func origin_position(enemy: Dictionary, progress: float) -> Vector2:
	var route: Array = enemy["route"]
	return Vector2(route.front()).lerp(Vector2(route.back()), clampf(progress, 0.0, 1.0))


static func event_step(enemy: Dictionary, towers: Array) -> float:
	if enemy["locomotion"] in ["jump", "jump_charge"]:
		return float(enemy["jump_remaining"]) if float(enemy["jump_remaining"]) > EPSILON and not bool(enemy["jump_landing_blocked"]) else INF
	var speed: float = enemy["speed"]
	if speed <= 0.0:
		return INF
	var finish: float = minf(1.0, next_cell_boundary(enemy, float(enemy["progress"])) + EPSILON * 10.0)
	var obstruction: Dictionary = blocker(enemy, towers)
	if not obstruction.is_empty():
		var route: Array = enemy["route"]
		var length: float = Vector2(route.front()).distance_to(Vector2(route.back()))
		finish = minf(finish, float(obstruction["entry"]) - CLEARANCE / length)
	return maxf(EPSILON, (finish - float(enemy["progress"])) / speed)
