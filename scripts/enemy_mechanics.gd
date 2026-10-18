class_name EnemyMechanics
extends RefCounted
## Resource-driven individual abilities; the host owns damage and simulation time.

const EPSILON: float = 0.000000001


static func capture(definition: EnemyDefinition) -> Dictionary:
	return {
		"physical_damage_multiplier": definition.physical_damage_multiplier,
		"death_spawn_type": String(definition.death_spawn_type),
		"death_spawn_count": definition.death_spawn_count,
		"enrage_health_fraction": definition.enrage_health_fraction,
		"enrage_speed_multiplier": definition.enrage_speed_multiplier,
		"regeneration_interval": definition.regeneration_interval,
		"regeneration_fraction": definition.regeneration_fraction,
	}


static func initialize(enemy: Dictionary, definition: Dictionary) -> void:
	enemy["physical_damage_multiplier"] = float(definition["physical_damage_multiplier"])
	enemy["enraged"] = false
	enemy["regeneration_count"] = 0
	enemy["next_regeneration"] = float(definition["regeneration_interval"])


static func after_damage(enemy: Dictionary, definition: Dictionary) -> void:
	if int(enemy["hp"]) <= 0 or bool(enemy["enraged"]) or float(definition["enrage_health_fraction"]) <= 0.0:
		return
	if float(enemy["hp"]) > float(enemy["max_hp"]) * float(definition["enrage_health_fraction"]):
		return
	enemy["enraged"] = true
	enemy["base_speed"] = float(enemy["base_speed"]) * float(definition["enrage_speed_multiplier"])
	BossMechanics.prepare(enemy)


static func has_abilities(definition: Dictionary) -> bool:
	return float(definition["regeneration_interval"]) > 0.0


static func event_step(enemy: Dictionary, definition: Dictionary) -> float:
	if int(enemy["hp"]) <= 0 or not has_abilities(definition):
		return INF
	return maxf(EPSILON, float(enemy["next_regeneration"]) - float(enemy["age"]))


static func advance(enemy: Dictionary, definition: Dictionary) -> void:
	if int(enemy["hp"]) <= 0 or not has_abilities(definition):
		return
	var interval: float = float(definition["regeneration_interval"])
	while float(enemy["next_regeneration"]) <= float(enemy["age"]) + EPSILON:
		enemy["next_regeneration"] = float(enemy["next_regeneration"]) + interval
		var healed: int = mini(int(enemy["max_hp"]) - int(enemy["hp"]), ceili(float(enemy["max_hp"]) * float(definition["regeneration_fraction"])))
		if healed <= 0:
			continue
		enemy["hp"] = int(enemy["hp"]) + healed
		enemy["regeneration_count"] = int(enemy["regeneration_count"]) + 1
		enemy["animation"] = "heal"
		enemy["animation_elapsed"] = 0.0
