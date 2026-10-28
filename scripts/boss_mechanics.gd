class_name BossMechanics
extends RefCounted
## Route motion decisions only. MatchCombat owns clocks, rolls, damage and events.

const EPSILON: float = 0.000000001


static func has_abilities(definition: Dictionary) -> bool:
	return float(definition["tower_attack_interval"]) > 0.0 or float(definition["stomp_interval"]) > 0.0 or float(definition["jump_interval"]) > 0.0


static func can_act(enemy: Dictionary) -> bool:
	return enemy["locomotion"] in ["path", "wheels"]


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


static func prepare(enemy: Dictionary) -> void:
	if float(enemy["cast_remaining"]) > EPSILON or float(enemy["tower_attack_remaining"]) > EPSILON:
		enemy["speed"] = 0.0
	elif enemy["locomotion"] == "jump":
		enemy["speed"] = float(enemy["jump_distance"]) / float(enemy["jump_duration"])
	elif not can_act(enemy):
		enemy["speed"] = 0.0
	else:
		enemy["speed"] = float(enemy["base_speed"]) * (float(enemy.get("slow_multiplier", TowerDefinition.FREEZE_SPEED_MULTIPLIER)) if enemy["slowed"] else 1.0)


static func event_step(enemy: Dictionary, definition: Dictionary) -> float:
	if not can_act(enemy):
		return maxf(EPSILON, float(enemy["jump_remaining"]))
	if float(enemy["cast_remaining"]) > EPSILON or float(enemy["tower_attack_remaining"]) > EPSILON:
		return INF
	return maxf(EPSILON, float(enemy["next_jump"]) - float(enemy["age"])) if float(definition["jump_interval"]) > 0.0 else INF
