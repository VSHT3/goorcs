class_name ItemStatEffects
extends RefCounted
## Item modifiers are products, flat points are sums; branch baselines belong to combat.

const FILTERS: PackedStringArray = ["attacking", "arrow", "ballista", "rune", "lightning", "orcapult", "drums", "physical", "fire", "physical_projectile", "physical_ballista", "projectile", "explosive_arrow", "fire_arrow", "flamethrower", "molotov", "pulsed_rune", "forge", "command_banner", "lookout_horn", "bloodlust_totem"]
const MULTIPLIERS: PackedStringArray = ["damage_multiplier", "direct_damage_multiplier", "attack_rate_multiplier", "reload_multiplier", "crit_damage_multiplier", "support_multiplier", "support_damage_multiplier", "support_speed_multiplier", "support_range_multiplier", "support_crit_multiplier", "splash_radius_multiplier", "burn_duration_multiplier"]
const ADDITIONS: PackedStringArray = ["range_add", "crit_chance_add", "chain_hits_add", "chain_range_add", "pierce_add", "throw_count_add", "lift_classes_add", "throw_distance_add"]
const COUNT_KEYS: PackedStringArray = ["chain_hits_add", "pierce_add", "throw_count_add", "lift_classes_add"]
const SUPPORT_FILTERS: PackedStringArray = ["drums", "forge", "command_banner", "lookout_horn", "bloodlust_totem"]
const PARAMETER_KEYS: Dictionary = {
	"sturdy_pickaxe": ["production_multiplier"], "copper_tooth": ["bonus_coins"],
	"orc_tusk": ["health_multiplier"], "torn_boot": ["speed_multiplier"], "dabloons": ["cost_multiplier"],
	"trollhide_earplugs": ["duration_multiplier"], "gravediggers_lantern": ["damage_multiplier"],
	"menders_spool": ["duration_multiplier"], "mooncap_jerky": ["boss_multiplier", "nonboss_multiplier"],
	"counting_frame": ["production_multiplier"], "command_banner": ["speed_multiplier"],
	"orcish_lunch_tin": ["base_coins", "round_divisor", "streak_divisor"],
	"prospectors_diamond": ["production_multiplier"], "frostbite_nail": ["damage_multiplier"],
	"watchmans_cup": ["damage_multiplier", "tiles"], "butchers_apron": ["damage_multiplier", "hp_fraction"],
	"crystal_sutures": ["heal_fraction"],
	"philosophers_stone": ["event_period", "bounty_multiplier", "shards", "rush_seconds"],
	"wormwood_censer": ["healing_multiplier"], "siege_carpenters_brace": ["damage_per_second", "maximum_bonus"],
	"choir_of_empty_helmets": ["radius", "damage_per_identity", "max_identities"],
	"necromancers_receipt": ["damage_multiplier", "duration"], "trollhide_apron": ["duration_multiplier"],
	"accountants_abacus": ["clear_multiplier"], "ironroot_bulb": ["max_health_add"],
	"concucktion": ["targeting_random"], "monkeys_paw": ["max_health_multiplier", "reward_tier"],
	"troll_kings_molar": ["max_health_add"], "gravebound_ledger": ["mark_multiplier"],
	"bloodglass_hourglass": ["duration_multiplier"], "witchs_folded_ladder": ["duration", "cooldown", "range_add"],
	"mimics_lunch_pail": ["wait_seconds", "bonus_coins"], "clockwork_raincloud": ["every", "stun_duration"],
	"undertakers_spade": ["periodic_multiplier", "clear_multiplier"],
	"couriers_basalt_boots": ["health_multiplier", "cost_multiplier"],
	"spore_spawn_of_marko": ["initial_quota", "feed_cost", "damage_fraction", "duration", "spread_radius"],
	"royal_printing_plate": ["periodic_multiplier", "clear_multiplier"],
	"bottomless_quiver": ["every", "damage_multiplier"], "empty_throne": ["damage_multiplier"],
	"worldroot_seed": ["damage_per_clear", "damage_cap"],
	"sun_in_a_cage": ["charge_duration", "burst_multiplier", "radius", "shutdown_duration"],
	"dreadmaws_second_heart": ["reserve_fraction"], "golden_harvest_sickle": ["clear_multiplier"],
	"bastion_in_a_bottle": ["duration", "cooldown", "damage_prevent_fraction", "damage_prevent_cap"],
	"minute_hand_cannon": ["duration", "cooldown", "attack_rate_multiplier"],
	"philosophorers_stone": ["event_period", "bounty_multiplier", "shards", "rush_seconds"],
	"the_whole_shebang": ["rate_per_clear", "rate_cap"],
	"mountains_pocket_change": ["production_multiplier", "shard_chance", "shards"],
	"entire_quiver": ["every", "damage_multiplier"], "one_more_you_git": ["health_remaining", "stun_duration"],
	"the_walking_fortress": ["max_health_add", "duration", "cooldown", "heal"],
	"ominous_bells_of_doom": ["wave_step", "damage_initial", "damage_step", "damage_cap"],
	"philosophorers_stoner": ["event_period", "bounty_multiplier", "shards", "rush_seconds", "overheal_coins_multiplier"],
	"the_whole_shebang_orcfeccion": ["rate_per_clear", "rate_cap"]
}
const INTEGER_PARAMETERS: PackedStringArray = ["bonus_coins", "base_coins", "round_divisor", "streak_divisor", "tiles", "event_period", "shards", "max_identities", "max_health_add", "targeting_random", "reward_tier", "every", "initial_quota", "feed_cost", "health_remaining", "wave_step", "heal"]
const FRACTION_PARAMETERS: PackedStringArray = ["hp_fraction", "heal_fraction", "damage_fraction", "reserve_fraction", "damage_prevent_fraction", "shard_chance"]

var _runtime_ref: WeakRef
var runtime: Variant:
	get:
		return _runtime_ref.get_ref()


func _init(owner: Variant) -> void:
	_runtime_ref = weakref(owner)


static func mechanic_keys() -> PackedStringArray:
	return PackedStringArray(PARAMETER_KEYS.keys())


static func parameter_keys(mechanic: String) -> PackedStringArray:
	return PackedStringArray(PARAMETER_KEYS.get(mechanic, []))


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func validate_modifier(modifier: Dictionary) -> bool:
	if modifier.size() != 2 or not modifier.get("filter") is String or not modifier.get("values") is Dictionary:
		return false
	var filter_name: String = modifier["filter"]
	var values: Dictionary = modifier["values"]
	if filter_name not in FILTERS or values.is_empty():
		return false
	for key: Variant in values:
		if not key is String or not _number(values[key]):
			return false
		var value: float = float(values[key])
		if key in MULTIPLIERS:
			if value <= 0.0:
				return false
		elif key not in ADDITIONS and key != "freeze_slow_multiplier":
			return false
		if key in COUNT_KEYS and (not values[key] is int or value < 0.0):
			return false
		if key == "freeze_slow_multiplier" and (value <= 0.0 or value > 1.0):
			return false
		var support: bool = String(key).begins_with("support_")
		if support != (filter_name in SUPPORT_FILTERS):
			return false
		if key == "support_damage_multiplier" and filter_name != "forge":
			return false
		if key == "support_speed_multiplier" and filter_name != "command_banner":
			return false
		if key == "support_range_multiplier" and filter_name != "lookout_horn":
			return false
		if key == "support_crit_multiplier" and filter_name != "bloodlust_totem":
			return false
		if key == "splash_radius_multiplier" and filter_name != "explosive_arrow":
			return false
		if key == "burn_duration_multiplier" and filter_name != "molotov":
			return false
		if key in ["chain_hits_add", "chain_range_add"] and filter_name != "lightning":
			return false
		if key == "pierce_add" and filter_name != "physical_ballista":
			return false
		if key in ["throw_count_add", "lift_classes_add", "throw_distance_add", "reload_multiplier"] and filter_name != "orcapult":
			return false
		if key == "direct_damage_multiplier" and filter_name != "fire_arrow":
			return false
		if key == "freeze_slow_multiplier" and filter_name != "rune":
			return false
	return true


static func validate_runtime(record: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if record.is_empty():
		errors.append("Runtime must declare numeric effects.")
	for key: Variant in record:
		if key not in ["stats", "mechanic", "parameters"]:
			errors.append("Unknown runtime field: %s." % str(key))
	if record.has("stats"):
		if not record["stats"] is Array or record["stats"].is_empty():
			errors.append("Stats must contain modifiers.")
		else:
			for modifier: Variant in record["stats"]:
				if not modifier is Dictionary or not validate_modifier(modifier):
					errors.append("Invalid stat modifier or eligibility.")
	if record.has("mechanic"):
		if not record["mechanic"] is String or not PARAMETER_KEYS.has(record["mechanic"]):
			errors.append("Unknown item mechanic.")
		elif not record.get("parameters") is Dictionary:
			errors.append("Mechanic requires numeric parameters.")
		else:
			var required: PackedStringArray = parameter_keys(record["mechanic"])
			var parameters: Dictionary = record["parameters"]
			if parameters.size() != required.size():
				errors.append("Mechanic parameter set is incomplete or unknown.")
			for key: Variant in parameters:
				if key not in required or not _number(parameters[key]):
					errors.append("Invalid numeric parameter: %s." % str(key))
					continue
				var value: float = float(parameters[key])
				if value < 0.0 or (key in INTEGER_PARAMETERS and not parameters[key] is int) or (key in FRACTION_PARAMETERS and value > 1.0):
					errors.append("Parameter outside its numeric domain: %s." % key)
				elif value == 0.0 and key not in ["shards", "rush_seconds"]:
					errors.append("Parameter must be positive: %s." % key)
	elif record.has("parameters"):
		errors.append("Parameters require a declared mechanic.")
	if not record.has("stats") and not record.has("mechanic"):
		errors.append("Runtime has no effect.")
	return errors


static func matches_filter(tower: Dictionary, filter_name: String) -> bool:
	var family: String = String(tower.get("type_id", ""))
	var kind: String = String(tower.get("behavior_kind", ""))
	var attacking: bool = kind in ["attack", "chain", "catapult"]
	var element: String = String(tower.get("element", "")).to_lower()
	var config: Dictionary = tower.get("effective_attack_config", {})
	var weapon: String = String(config.get("weapon", "arrow"))
	var branch: String = String(tower.get("evolution", ""))
	match filter_name:
		"attacking": return attacking
		"arrow": return attacking and family == "arrow_tower"
		"ballista": return attacking and family == "orc_ballista"
		"rune": return attacking and family == "rune_obelisk"
		"lightning": return attacking and family == "lightning"
		"orcapult": return kind == "catapult" and family == "orcapult"
		"drums": return kind == "support" and family == "war_drums"
		"physical": return attacking and element == "physical"
		"fire": return attacking and element == "fire"
		"physical_projectile": return attacking and family in ["arrow_tower", "orc_ballista"] and element == "physical"
		"physical_ballista": return attacking and family == "orc_ballista" and element == "physical"
		"projectile": return attacking and family in ["arrow_tower", "orc_ballista"] and weapon != "flamethrower"
		"explosive_arrow": return attacking and family == "arrow_tower" and weapon in ["grenade", "rocket"]
		"fire_arrow": return attacking and family == "arrow_tower" and element == "fire"
		"flamethrower": return attacking and family == "arrow_tower" and weapon == "flamethrower"
		"molotov": return attacking and family == "arrow_tower" and weapon == "molotov"
		"pulsed_rune": return attacking and family == "rune_obelisk" and branch in ["onyx_ring", "storm_sigil"]
		"forge", "command_banner", "lookout_horn", "bloodlust_totem":
			return kind == "support" and family == "war_drums" and branch == filter_name
	return false


func _aggregate(slot: int, tower: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for identity: String in runtime.owned_ids(slot):
		var record: Dictionary = runtime.config(slot, StringName(identity))
		for modifier: Dictionary in record.get("stats", []):
			if not matches_filter(tower, modifier["filter"]):
				continue
			var values: Dictionary = modifier["values"]
			for key: String in values:
				if key in MULTIPLIERS:
					result[key] = float(result.get(key, 1.0)) * float(values[key])
				elif key == "freeze_slow_multiplier":
					result[key] = minf(float(result.get(key, 1.0)), float(values[key]))
				else:
					result[key] = float(result.get(key, 0.0)) + float(values[key])
	return result


func _active(slot: int, identity: StringName) -> Dictionary:
	if not runtime.has(slot, identity):
		return {}
	var active: Dictionary = runtime.state(slot).get("active", {}).get(String(identity), {})
	return active if float(active.get("remaining", 0.0)) > 0.0 else {}


func prepare_tower(slot: int, tower: Dictionary) -> void:
	var values: Dictionary = _aggregate(slot, tower)
	tower["item_modifiers"] = values
	var behavior: Dictionary = tower["behavior_config"]
	var attack: Dictionary = tower.get("effective_attack_config", {})
	var support_keys: Dictionary = {"damage_bonus": "support_damage_multiplier", "attack_speed_bonus": "support_speed_multiplier", "range_aura": "support_range_multiplier", "crit_chance": "support_crit_multiplier"}
	if tower["behavior_kind"] == "support":
		for key: String in support_keys:
			if behavior.has(key):
				behavior[key] = float(behavior[key]) * float(values.get("support_multiplier", 1.0)) * float(values.get(support_keys[key], 1.0))
	if matches_filter(tower, "attacking"):
		var reach: float = float(values.get("range_add", 0.0))
		if not _active(slot, &"witchs_folded_ladder").is_empty():
			reach += float(runtime.params(slot, &"witchs_folded_ladder")["range_add"])
		var baseline: float = float(tower["range"])
		tower["range"] = maxf(minf(1.0, baseline), baseline + reach)
	if attack.has("splash_radius"):
		attack["splash_radius"] = float(attack["splash_radius"]) * float(values.get("splash_radius_multiplier", 1.0))
	if attack.has("burn_duration"):
		attack["burn_duration"] = float(attack["burn_duration"]) * float(values.get("burn_duration_multiplier", 1.0))
	if attack.has("continuous_dps"):
		attack["continuous_dps"] = float(attack["continuous_dps"]) * float(values.get("direct_damage_multiplier", 1.0))
	if behavior.has("hit_count"):
		behavior["hit_count"] = int(behavior["hit_count"]) + int(values.get("chain_hits_add", 0))
	if behavior.has("jump_distance"):
		behavior["jump_distance"] = float(behavior["jump_distance"]) + float(values.get("chain_range_add", 0.0))
	if behavior.has("throw_count"):
		behavior["throw_count"] = int(behavior["throw_count"]) + int(values.get("throw_count_add", 0))
	if behavior.has("lift"):
		behavior["lift"] = _lift_limit(float(behavior["lift"]), int(values.get("lift_classes_add", 0)))
	tower["branch_pierce"] = int(tower.get("branch_pierce", 0)) + int(values.get("pierce_add", 0))
	tower["item_throw_distance"] = float(values.get("throw_distance_add", 0.0))
	tower["freeze_slow_multiplier"] = float(values.get("freeze_slow_multiplier", TowerDefinition.FREEZE_SPEED_MULTIPLIER)) if bool(tower.get("freeze_upgraded", false)) else TowerDefinition.FREEZE_SPEED_MULTIPLIER
	tower["item_direct_damage_multiplier"] = float(values.get("direct_damage_multiplier", 1.0))


func _lift_limit(baseline: float, classes: int) -> float:
	var limit: float = baseline
	for index: int in classes:
		var next: float = INF
		for definition: Dictionary in runtime.combat._enemy_types.values():
			var weight: float = float(definition.get("health_multiplier", 1.0))
			if not bool(definition.get("boss", false)) and weight > limit + 0.000000001:
				next = minf(next, weight)
		if is_finite(next):
			limit = next
	return limit


func _neighbor_damage(slot: int, tower: Dictionary) -> float:
	if not matches_filter(tower, "attacking"):
		return 1.0
	var result: float = 1.0
	var choir: bool = runtime.has(slot, &"choir_of_empty_helmets")
	var throne: bool = runtime.has(slot, &"empty_throne")
	if not choir and not throne:
		return result
	var identities: Dictionary = {}
	var adjacent: bool = false
	var origin: Vector2i = tower["cell"]
	var radius: float = float(runtime.params(slot, &"choir_of_empty_helmets")["radius"]) if choir else 0.0
	for other: Dictionary in runtime.combat.towers[slot]:
		if int(other["id"]) == int(tower["id"]):
			continue
		var cell: Vector2i = other["cell"]
		if choir and Vector2(origin).distance_squared_to(Vector2(cell)) <= radius * radius + 0.000000001:
			identities[String(other["type_id"])] = true
		if throne and absi(origin.x - cell.x) <= 1 and absi(origin.y - cell.y) <= 1 and matches_filter(other, "attacking"):
			adjacent = true
	if choir:
		var parameters: Dictionary = runtime.params(slot, &"choir_of_empty_helmets")
		result *= 1.0 + mini(identities.size(), int(parameters["max_identities"])) * float(parameters["damage_per_identity"])
	if throne and not adjacent:
		result *= float(runtime.params(slot, &"empty_throne")["damage_multiplier"])
	return result


func finish_tower(slot: int, tower: Dictionary, previous_interval: float) -> void:
	var values: Dictionary = tower.get("item_modifiers", {})
	var damage: float = float(values.get("damage_multiplier", 1.0)) * _neighbor_damage(slot, tower)
	var rate: float = float(values.get("attack_rate_multiplier", 1.0)) / float(values.get("reload_multiplier", 1.0))
	if matches_filter(tower, "attacking"):
		damage *= runtime.progression.damage_multiplier(slot, tower)
		rate *= 1.0 + runtime.progression.attack_rate_bonus(slot, tower)
		var cannon: Dictionary = _active(slot, &"minute_hand_cannon")
		if not cannon.is_empty() and int(cannon.get("target_id", -1)) == int(tower["id"]) and matches_filter(tower, "projectile"):
			rate *= float(runtime.params(slot, &"minute_hand_cannon")["attack_rate_multiplier"])
		tower["crit_chance"] = clampf(float(tower.get("crit_chance", 0.0)) + float(values.get("crit_chance_add", 0.0)), 0.0, TowerDefinition.MAX_CRIT_CHANCE)
	tower["crit_damage_multiplier"] = TowerDefinition.CRIT_MULTIPLIER * float(values.get("crit_damage_multiplier", 1.0))
	tower["damage_multiplier"] = float(tower["damage_multiplier"]) * damage
	tower["speed_multiplier"] = float(tower["speed_multiplier"]) * rate
	tower["damage"] = ceili(float(tower["base_damage"]) * float(tower["damage_multiplier"]) * float(tower.get("item_direct_damage_multiplier", 1.0)) - 0.000000001)
	tower["interval"] = float(tower["base_interval"]) / float(tower["speed_multiplier"])
	if previous_interval > 0.0:
		tower["cooldown"] = float(tower["cooldown"]) * float(tower["interval"]) / previous_interval
	var attack: Dictionary = tower.get("effective_attack_config", {})
	var behavior: Dictionary = tower["behavior_config"]
	tower["item_effective_parameters"] = {
		"splash_radius": float(attack.get("splash_radius", 0.0)),
		"burn_duration": float(attack.get("burn_duration", 0.0)),
		"lift": float(behavior.get("lift", 0.0)), "throw_count": int(behavior.get("throw_count", 0)),
		"chain_hits": int(behavior.get("hit_count", 0)), "chain_range": float(behavior.get("jump_distance", 0.0)),
		"pierce": int(behavior.get("pierce", 0)) + int(tower.get("branch_pierce", 0)),
		"throw_distance": float(tower.get("item_throw_distance", 0.0)),
		"continuous_attack_rate": float(tower["speed_multiplier"])
	}
