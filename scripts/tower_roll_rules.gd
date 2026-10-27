class_name TowerRollRules
extends Resource
## Opt-in host rules. Validate evolution-safe compatibility before a transaction
## consumes currency or randomness. Pool bounds are signed fractional bonuses,
## except pierce/bounce/chain_jumps, which are additive integer counts.

const RARITIES: PackedStringArray = ["broken", "shoddy", "common", "uncommon", "rare", "epic", "legendary", "mythic"]
const EFFECTS: PackedStringArray = ["damage", "attack_speed", "range", "pierce", "bounce", "chain_jumps", "support_buff", "economy_production"]
const COUNT_EFFECTS: PackedStringArray = ["pierce", "bounce", "chain_jumps"]
const MAX_EXACT_COST: float = 9007199254740991.0

# Entries: id, title, weight, positive_slots, drawback_slots, positive_pool,
# drawback_pool. Each pool maps an effect String to inclusive Vector2 bounds.
@export var rarities: Array[Dictionary] = []
# Profile -> rarity -> Vector2i(positive slots, drawback slots). Missing overrides
# use that rarity's base slots; profiles never silently truncate requested slots.
@export var slot_profiles: Dictionary = {}
# ceil(base + linear*n + quadratic*n*n), n = accepted rerolls of this kind.
# Currencies/counters and their lifecycle belong to the authoritative host.
@export var rarity_reroll_cost_curve: Vector3 = Vector3(8.0, 4.0, 2.0)
@export var attribute_reroll_cost_curve: Vector3 = Vector3(20.0, 10.0, 5.0)


func validation_errors(compatible_effects: PackedStringArray, profile: String = "attack") -> PackedStringArray:
	var errors := PackedStringArray()
	var compatibility: Dictionary = {}
	for effect: String in compatible_effects:
		if effect not in EFFECTS or compatibility.has(effect):
			errors.append("Tower roll compatibility contains an unknown or duplicate effect '%s'." % effect)
		compatibility[effect] = true
	if not slot_profiles.has(profile) or typeof(slot_profiles[profile]) != TYPE_DICTIONARY:
		errors.append("Unknown or invalid tower roll profile '%s'." % profile)
	for profile_key: Variant in slot_profiles:
		if typeof(profile_key) != TYPE_STRING or str(profile_key).is_empty() or typeof(slot_profiles[profile_key]) != TYPE_DICTIONARY:
			errors.append("Tower roll profiles require nonempty names and override dictionaries.")
			continue
		var overrides: Dictionary = slot_profiles[profile_key]
		for rarity_key: Variant in overrides:
			if typeof(rarity_key) != TYPE_STRING or str(rarity_key) not in RARITIES or typeof(overrides[rarity_key]) != TYPE_VECTOR2I:
				errors.append("Tower roll profile '%s' has an invalid rarity or slot override." % profile_key)
				continue
			var slots: Vector2i = overrides[rarity_key]
			if not _valid_slots(slots.x, slots.y):
				errors.append("Tower roll profile '%s' has invalid slot counts." % profile_key)
	if not _valid_curve(rarity_reroll_cost_curve) or not _valid_curve(attribute_reroll_cost_curve):
		errors.append("Tower reroll costs require finite positive base/quadratic and nonnegative linear coefficients.")
	var seen: Dictionary = {}
	var weight_sum: float = 0.0
	var weighted_tiers: int = 0
	for tier: Dictionary in rarities:
		var id: String = str(tier.get("id", ""))
		if typeof(tier.get("id")) != TYPE_STRING or id not in RARITIES or seen.has(id):
			errors.append("Tower rolls contain an unknown or duplicate rarity '%s'." % id)
		seen[id] = true
		if typeof(tier.get("title")) != TYPE_STRING or str(tier.get("title", "")).is_empty():
			errors.append("Rarity '%s' requires a title." % id)
		var weight: Variant = tier.get("weight")
		if not _is_number(weight) or not is_finite(float(weight)) or float(weight) < 0.0:
			errors.append("Rarity '%s' requires a finite nonnegative weight." % id)
		else:
			weight_sum += float(weight)
			if float(weight) > 0.0:
				weighted_tiers += 1
		var positive_slots: Variant = tier.get("positive_slots")
		var drawback_slots: Variant = tier.get("drawback_slots")
		if typeof(positive_slots) != TYPE_INT or typeof(drawback_slots) != TYPE_INT:
			errors.append("Rarity '%s' requires integer slot counts." % id)
			continue
		if not _valid_slots(int(positive_slots), int(drawback_slots)):
			errors.append("Rarity '%s' has invalid attribute slot counts." % id)
			continue
		var pools_valid: bool = _validate_pool(tier.get("positive_pool"), true, id, errors)
		pools_valid = _validate_pool(tier.get("drawback_pool"), false, id, errors) and pools_valid
		if pools_valid:
			var positive: Array[String] = _eligible(tier["positive_pool"], compatible_effects)
			var drawback: Array[String] = _eligible(tier["drawback_pool"], compatible_effects)
			var slots: Vector2i = _slot_counts(tier, profile)
			if not _can_fill(positive, drawback, slots.x, slots.y, {}):
				errors.append("Rarity '%s' cannot fill profile '%s' slots without duplicate or opposing compatible effects." % [id, profile])
	for id: String in RARITIES:
		if not seen.has(id):
			errors.append("Tower rolls are missing rarity '%s'." % id)
	if not is_finite(weight_sum) or weight_sum <= 0.0 or weighted_tiers < 2:
		errors.append("Tower rolls require finite positive total weight and at least two weighted rarities for exclusion rerolls.")
	return errors


## Returns {ok:true, rarity:String, attributes:Array[Dictionary]} or
## {ok:false, error:String}. Invalid input never advances the supplied RNG.
func generate(random: RandomNumberGenerator, compatible_effects: PackedStringArray, excluded_rarity: String = "", profile: String = "attack") -> Dictionary:
	var errors: PackedStringArray = validation_errors(compatible_effects, profile)
	if not errors.is_empty():
		return _failure(" ".join(errors))
	return generate_admitted(random, compatible_effects, excluded_rarity, profile)


## Only use after validation_errors succeeds for the captured, unchanged rules,
## compatibility, and profile. Skips schema validation without copying resources.
func generate_admitted(random: RandomNumberGenerator, compatible_effects: PackedStringArray, excluded_rarity: String = "", profile: String = "attack") -> Dictionary:
	if random == null:
		return _failure("Tower rolls require an injected RandomNumberGenerator.")
	if not excluded_rarity.is_empty() and excluded_rarity not in RARITIES:
		return _failure("Cannot exclude unknown rarity '%s'." % excluded_rarity)
	if not slot_profiles.has(profile) or typeof(slot_profiles[profile]) != TYPE_DICTIONARY:
		return _failure("Unknown or invalid tower roll profile '%s'." % profile)
	var total: float = 0.0
	var last_weighted: Dictionary = {}
	for tier: Dictionary in rarities:
		if tier["id"] != excluded_rarity and float(tier["weight"]) > 0.0:
			total += float(tier["weight"])
			last_weighted = tier
	var draw: float = random.randf() * total
	for tier: Dictionary in rarities:
		if tier["id"] == excluded_rarity or float(tier["weight"]) <= 0.0:
			continue
		draw -= float(tier["weight"])
		if draw < 0.0:
			return _generate_tier(tier, random, compatible_effects, profile)
	# randf includes its upper endpoint: select the last actual weighted interval,
	# never fabricate a default for malformed configuration.
	return _generate_tier(last_weighted, random, compatible_effects, profile)


func regenerate_attributes(rarity: String, random: RandomNumberGenerator, compatible_effects: PackedStringArray, profile: String = "attack") -> Dictionary:
	var errors: PackedStringArray = validation_errors(compatible_effects, profile)
	if not errors.is_empty():
		return _failure(" ".join(errors))
	return regenerate_attributes_admitted(rarity, random, compatible_effects, profile)


## Uses the same admission contract as generate_admitted; only attributes roll.
func regenerate_attributes_admitted(rarity: String, random: RandomNumberGenerator, compatible_effects: PackedStringArray, profile: String = "attack") -> Dictionary:
	if random == null:
		return _failure("Tower rolls require an injected RandomNumberGenerator.")
	if not slot_profiles.has(profile) or typeof(slot_profiles[profile]) != TYPE_DICTIONARY:
		return _failure("Unknown or invalid tower roll profile '%s'." % profile)
	for tier: Dictionary in rarities:
		if tier["id"] == rarity:
			return _generate_tier(tier, random, compatible_effects, profile)
	return _failure("Cannot regenerate attributes for unknown rarity '%s'." % rarity)


func rarity_reroll_cost(completed_rerolls: int) -> int:
	return _curve_cost(rarity_reroll_cost_curve, completed_rerolls)


static func valid_reroll_batch(kind: String, requested: Variant) -> bool:
	return typeof(requested) == TYPE_INT and (requested == 1 or (kind == "rarity" and requested in [0, 10]))


## Host quote; Max stops only at affordability or the exact currency limit.
func rarity_batch_quote(completed: int, requested: int, available: int, free: bool = false) -> Dictionary:
	var count: int = 0
	var total: int = 0
	var limit: int = 10 if free and requested == 0 else requested
	if free:
		return {"count": limit, "cost": 0, "affordable": limit > 0}
	while requested == 0 or count < limit:
		var cost: int = rarity_reroll_cost(completed + count)
		if cost < 0 or total > int(MAX_EXACT_COST) - cost:
			if requested != 0:
				return {"count": requested, "cost": -1, "affordable": false}
			break
		if requested == 0 and cost > available - total:
			break
		total += cost
		count += 1
	return {"count": count, "cost": total, "affordable": count > 0 and total <= available}


## Every candidate excludes the original rarity, never the previous candidate.
func generate_batch_admitted(random: RandomNumberGenerator, compatible_effects: PackedStringArray, excluded_rarity: String, profile: String, count: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var winner: int = 0
	var best_rank: int = -1
	for index: int in range(count):
		var rolled: Dictionary = generate_admitted(random, compatible_effects, excluded_rarity, profile)
		results.append({"rarity": rolled["rarity"], "attributes": rolled["attributes"]})
		var rank: int = RARITIES.find(rolled["rarity"])
		if rank > best_rank:
			best_rank = rank
			winner = index
	return {
		"rarity": results[winner]["rarity"], "attributes": results[winner]["attributes"],
		"rarity_batch_results": results, "rarity_batch_winner": winner,
	}


func attribute_reroll_cost(completed_rerolls: int) -> int:
	return _curve_cost(attribute_reroll_cost_curve, completed_rerolls)


## Bonuses add within an effect. Stats use base*(1+bonus), attack speed uses
## base_interval/(1+bonus), and counts add to purchased mechanics. support_buff
## scales applicable buff components; economy_production scales every income
## mechanism through evolutions. No purchased state is replaced.
static func modifiers(attributes: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for attribute: Dictionary in attributes:
		var effect: String = attribute["effect"]
		result[effect] = float(result.get(effect, 0.0)) + float(attribute["value"])
	return result


func _generate_tier(tier: Dictionary, random: RandomNumberGenerator, compatible_effects: PackedStringArray, profile: String) -> Dictionary:
	var positive: Array[String] = _eligible(tier["positive_pool"], compatible_effects)
	var drawback: Array[String] = _eligible(tier["drawback_pool"], compatible_effects)
	var used: Dictionary = {}
	var attributes: Array[Dictionary] = []
	var slots: Vector2i = _slot_counts(tier, profile)
	var positive_left: int = slots.x
	var drawback_left: int = slots.y
	while positive_left > 0:
		var candidates: Array[String] = []
		for effect: String in positive:
			if used.has(effect):
				continue
			used[effect] = true
			if _can_fill(positive, drawback, positive_left - 1, drawback_left, used):
				candidates.append(effect)
			used.erase(effect)
		var chosen: String = candidates[random.randi_range(0, candidates.size() - 1)]
		used[chosen] = true
		attributes.append(_attribute(chosen, tier["positive_pool"][chosen], true, random))
		positive_left -= 1
	while drawback_left > 0:
		var candidates: Array[String] = []
		for effect: String in drawback:
			if not used.has(effect):
				candidates.append(effect)
		var chosen: String = candidates[random.randi_range(0, candidates.size() - 1)]
		used[chosen] = true
		attributes.append(_attribute(chosen, tier["drawback_pool"][chosen], false, random))
		drawback_left -= 1
	return {"ok": true, "rarity": str(tier["id"]), "attributes": attributes}


func _slot_counts(tier: Dictionary, profile: String) -> Vector2i:
	var base_slots := Vector2i(int(tier["positive_slots"]), int(tier["drawback_slots"]))
	if not slot_profiles.has(profile) or typeof(slot_profiles[profile]) != TYPE_DICTIONARY:
		return base_slots
	var overrides: Dictionary = slot_profiles[profile]
	var value: Variant = overrides.get(tier["id"], base_slots)
	return value if typeof(value) == TYPE_VECTOR2I else base_slots


static func _attribute(effect: String, bounds: Vector2, positive: bool, random: RandomNumberGenerator) -> Dictionary:
	var value: float = float(random.randi_range(int(bounds.x), int(bounds.y))) if effect in COUNT_EFFECTS else random.randf_range(bounds.x, bounds.y)
	return {"id": effect, "effect": effect, "value": value, "positive": positive}


static func _eligible(pool: Dictionary, compatible_effects: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for effect: String in pool:
		if effect in compatible_effects:
			result.append(effect)
	return result


# For two pools, individual capacities plus union capacity are necessary and
# sufficient. Also prevents a positive choice stranding required drawbacks.
static func _can_fill(positive: Array[String], drawback: Array[String], positive_slots: int, drawback_slots: int, used: Dictionary) -> bool:
	var positive_count: int = 0
	var drawback_count: int = 0
	var union: Dictionary = {}
	for effect: String in positive:
		if not used.has(effect):
			positive_count += 1
			union[effect] = true
	for effect: String in drawback:
		if not used.has(effect):
			drawback_count += 1
			union[effect] = true
	return positive_count >= positive_slots and drawback_count >= drawback_slots and union.size() >= positive_slots + drawback_slots


static func _validate_pool(value: Variant, positive: bool, rarity: String, errors: PackedStringArray) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("Rarity '%s' requires both attribute pool dictionaries." % rarity)
		return false
	var valid: bool = true
	var pool: Dictionary = value
	for key: Variant in pool:
		if typeof(key) != TYPE_STRING or str(key) not in EFFECTS or typeof(pool[key]) != TYPE_VECTOR2:
			errors.append("Rarity '%s' has an unknown effect or non-Vector2 bounds." % rarity)
			valid = false
			continue
		var effect: String = key
		var bounds: Vector2 = pool[key]
		var bounds_valid: bool = bounds.is_finite() and bounds.x <= bounds.y
		if positive:
			bounds_valid = bounds_valid and bounds.x > 0.0
		else:
			bounds_valid = bounds_valid and bounds.x > -1.0 and bounds.y < 0.0 and effect not in COUNT_EFFECTS
		if effect in COUNT_EFFECTS:
			bounds_valid = bounds_valid and bounds.x == floorf(bounds.x) and bounds.y == floorf(bounds.y) and bounds.y <= 1000000.0
		if not bounds_valid:
			errors.append("Rarity '%s' has invalid signed finite bounds for '%s'." % [rarity, effect])
			valid = false
	return valid


static func _valid_slots(positive: int, drawback: int) -> bool:
	return positive >= 0 and drawback >= 0 and positive <= EFFECTS.size() and drawback <= EFFECTS.size() and positive + drawback <= EFFECTS.size()


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _valid_curve(curve: Vector3) -> bool:
	return curve.is_finite() and curve.x >= 1.0 and curve.y >= 0.0 and curve.z > 0.0


static func _curve_cost(curve: Vector3, completed_rerolls: int) -> int:
	if completed_rerolls < 0 or not _valid_curve(curve):
		return -1
	var count: float = float(completed_rerolls)
	var cost: float = float(curve.x) + float(curve.y) * count + float(curve.z) * count * count
	if not is_finite(cost) or cost > MAX_EXACT_COST:
		return -1
	return ceili(cost)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
