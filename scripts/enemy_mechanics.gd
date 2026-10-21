class_name EnemyMechanics
extends RefCounted
## Resource-driven individual abilities; the host owns damage and simulation time.

const EPSILON: float = 0.000000001


static func capture(definition: EnemyDefinition) -> Dictionary:
	return {
		"physical_damage_multiplier": definition.physical_damage_multiplier,
		"health_base_type": String(definition.health_base_type),
		"health_base_multiplier": definition.health_base_multiplier,
		"spawn_variant": String(definition.spawn_variant),
		"spawn_variant_first_wave": definition.spawn_variant_first_wave,
		"spawn_variant_chance": definition.spawn_variant_chance,
		"hit_shield": definition.hit_shield,
		"death_stun_radius": definition.death_stun_radius,
		"death_stun_duration": definition.death_stun_duration,
		"death_bomb_fuse": definition.death_bomb_fuse,
		"death_bomb_radius": definition.death_bomb_radius,
		"death_bomb_stun_duration": definition.death_bomb_stun_duration,
		"death_spawn_type": String(definition.death_spawn_type),
		"death_spawn_count": definition.death_spawn_count,
		"enrage_health_fraction": definition.enrage_health_fraction,
		"enrage_speed_multiplier": definition.enrage_speed_multiplier,
		"regeneration_interval": definition.regeneration_interval,
		"regeneration_fraction": definition.regeneration_fraction,
	}


static func initialize(enemy: Dictionary, definition: Dictionary) -> void:
	enemy["physical_damage_multiplier"] = float(definition["physical_damage_multiplier"])
	enemy["shield_hits"] = int(definition["hit_shield"])
	enemy["shield_max_hits"] = int(definition["hit_shield"])
	enemy["shield_hit_count"] = 0
	enemy["stunned_remaining"] = 0.0
	enemy["stun_count"] = 0
	enemy["stun_source"] = ""
	enemy["stun_position"] = enemy.get("pos", Vector2.ZERO)
	enemy["enraged"] = false
	enemy["regeneration_count"] = 0
	enemy["next_regeneration"] = float(definition["regeneration_interval"])



static func absorb_hit(enemy: Dictionary, positive_damage: float) -> bool:
	if positive_damage <= 0.0 or int(enemy["shield_hits"]) <= 0:
		return false
	enemy["shield_hits"] = int(enemy["shield_hits"]) - 1
	enemy["shield_hit_count"] = int(enemy["shield_hit_count"]) + 1
	return true

static func after_damage(enemy: Dictionary, definition: Dictionary) -> void:
	if int(enemy["hp"]) <= 0 or bool(enemy["enraged"]) or float(definition["enrage_health_fraction"]) <= 0.0:
		return
	if float(enemy["hp"]) > float(enemy["max_hp"]) * float(definition["enrage_health_fraction"]):
		return
	enemy["enraged"] = true
	enemy["base_speed"] = float(enemy["base_speed"]) * float(definition["enrage_speed_multiplier"])
	BossMechanics.prepare(enemy)
	if float(enemy["stunned_remaining"]) > EPSILON:
		enemy["speed"] = 0.0


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
		# Spellcasters regenerate silently rather than interrupting a cast pose.
		if definition.get("spellbook", {}).is_empty():
			enemy["animation"] = "heal"
			enemy["animation_elapsed"] = 0.0
