extends SceneTree

const SHIPPED: TowerRollRules = preload("res://resources/combat/tower_rolls.tres")
const ATTACK: PackedStringArray = ["damage", "attack_speed", "range", "pierce", "bounce"]

var failures: int = 0


func _init() -> void:
	_test_weighted_exclusion()
	_test_determinism_and_compatibility()
	_test_satisfiable_selection()
	_test_invalid_configuration()
	_test_mechanics_and_detachment()
	_test_costs()
	if failures == 0:
		print("PASS: deterministic weighted rarity exclusion, compatible unique attributes, satisfiable pools, detached mechanics, and accelerating reroll costs")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func _rules() -> TowerRollRules:
	return SHIPPED.duplicate(true) as TowerRollRules


func _tier(rules: TowerRollRules, rarity: String) -> Dictionary:
	for tier: Dictionary in rules.rarities:
		if tier["id"] == rarity:
			return tier
	return {}


func _expected_rarity(rules: TowerRollRules, unit_draw: float, excluded: String) -> String:
	var total: float = 0.0
	var last: String = ""
	for tier: Dictionary in rules.rarities:
		if tier["id"] != excluded and float(tier["weight"]) > 0.0:
			total += float(tier["weight"])
			last = tier["id"]
	var draw: float = unit_draw * total
	for tier: Dictionary in rules.rarities:
		if tier["id"] == excluded or float(tier["weight"]) <= 0.0:
			continue
		draw -= float(tier["weight"])
		if draw < 0.0:
			return tier["id"]
	return last


func _test_weighted_exclusion() -> void:
	var rules: TowerRollRules = _rules()
	_check(rules.validation_errors(ATTACK).is_empty(), "Shipped attack pools validate before rolling")
	for excluded: String in TowerRollRules.RARITIES:
		for seed_value: int in range(64):
			var random: RandomNumberGenerator = _random(seed_value)
			var control: RandomNumberGenerator = _random(seed_value)
			var expected: String = _expected_rarity(rules, control.randf(), excluded)
			var result: Dictionary = rules.generate(random, ATTACK, excluded)
			_check(result["ok"] and result["rarity"] != excluded and result["rarity"] == expected, "Rerolls exclude current tier and preserve renormalized base weights")
	# Two positive weights make exclusion a certain transition, including downgrades.
	for tier: Dictionary in rules.rarities:
		tier["weight"] = 1.0 if tier["id"] in ["broken", "mythic"] else 0.0
	_check(rules.generate(_random(3), ATTACK, "mythic")["rarity"] == "broken", "Mythic rerolls can downgrade to Broken")
	_check(rules.generate(_random(3), ATTACK, "broken")["rarity"] == "mythic", "Only the remaining weighted tier can be selected")
	for seed_value: int in range(16):
		var control: RandomNumberGenerator = _random(seed_value)
		_check(rules.generate(_random(seed_value), ATTACK)["rarity"] == _expected_rarity(rules, control.randf(), ""), "Placement uses the same authored distribution without exclusion")


func _test_determinism_and_compatibility() -> void:
	var rules: TowerRollRules = _rules()
	var roles: Array[Dictionary] = [
		{"profile": "attack", "effects": PackedStringArray(["damage", "attack_speed", "range"])},
		{"profile": "attack", "effects": ATTACK},
		{"profile": "attack", "effects": PackedStringArray(["damage", "attack_speed", "range", "chain_jumps"])},
		{"profile": "support", "effects": PackedStringArray(["range", "support_buff"])},
		{"profile": "economy", "effects": PackedStringArray(["economy_production"])}
	]
	for role: Dictionary in roles:
		var effects: PackedStringArray = role["effects"]
		var profile: String = role["profile"]
		_check(rules.validation_errors(effects, profile).is_empty(), "Every complete role profile can fill every rarity")
		var first: RandomNumberGenerator = _random(54123)
		var second: RandomNumberGenerator = _random(54123)
		for rarity: String in TowerRollRules.RARITIES:
			var tier: Dictionary = _tier(rules, rarity)
			var slots := Vector2i(int(tier["positive_slots"]), int(tier["drawback_slots"]))
			var overrides: Dictionary = rules.slot_profiles[profile]
			slots = overrides.get(rarity, slots)
			for iteration: int in range(32):
				var result: Dictionary = rules.regenerate_attributes(rarity, first, effects, profile)
				var repeat: Dictionary = rules.regenerate_attributes(rarity, second, effects, profile)
				_check(result == repeat and first.state == second.state, "Injected seeds reproduce every attribute and value exactly")
				_check(result["ok"] and result["rarity"] == rarity, "Attribute rerolls preserve rarity")
				var attributes: Array[Dictionary] = result["attributes"]
				var seen: Dictionary = {}
				var positives: int = 0
				var drawbacks: int = 0
				for attribute: Dictionary in attributes:
					var effect: String = attribute["effect"]
					var positive: bool = attribute["positive"]
					var pool: Dictionary = tier["positive_pool"] if positive else tier["drawback_pool"]
					var bounds: Vector2 = pool[effect]
					var value: float = attribute["value"]
					_check(effect in effects and not seen.has(effect) and attribute["id"] == effect, "Attributes are compatible, unique, and never oppose the same stat")
					_check(is_finite(value) and value >= bounds.x and value <= bounds.y and (value > 0.0 if positive else value < 0.0), "Every value respects signed rarity-specific inclusive bounds")
					if effect in TowerRollRules.COUNT_EFFECTS:
						_check(value == floorf(value), "Mechanical attribute capacities are whole counts")
					seen[effect] = true
					positives += 1 if positive else 0
					drawbacks += 0 if positive else 1
				_check(positives == slots.x and drawbacks == slots.y, "Profile slot counts are authored exactly, never silently capped")
				if rarity in ["broken", "shoddy"]:
					_check(positives == 0 and drawbacks > 0, "Lowest shipped tiers roll only drawbacks")


func _test_satisfiable_selection() -> void:
	var rules: TowerRollRules = _rules()
	var common: Dictionary = _tier(rules, "common")
	common["positive_pool"] = {"damage": Vector2(0.1, 0.2), "range": Vector2(0.1, 0.2)}
	common["drawback_pool"] = {"damage": Vector2(-0.1, -0.05)}
	_check(rules.validation_errors(ATTACK).is_empty(), "A shared effect is valid when disjoint complete selections exist")
	for seed_value: int in range(64):
		var result: Dictionary = rules.regenerate_attributes("common", _random(seed_value), ATTACK)
		var attributes: Array[Dictionary] = result["attributes"]
		_check(attributes[0]["effect"] == "range" and attributes[1]["effect"] == "damage", "Positive selection cannot strand a mandatory drawback even when its pool overlaps")
	common["positive_pool"] = {"damage": Vector2(0.1, 0.2)}
	_check(not rules.validation_errors(ATTACK).is_empty(), "Individually large enough pools still fail when their union cannot fill disjoint slots")
	var random: RandomNumberGenerator = _random(22)
	var before: int = random.state
	var failed: Dictionary = rules.generate(random, ATTACK)
	_check(not failed["ok"] and failed.has("error") and random.state == before, "Unsatisfiable configuration returns an explicit error without consuming randomness")


func _test_invalid_configuration() -> void:
	var rules: TowerRollRules = _rules()
	var random: RandomNumberGenerator = _random(81)
	var before: int = random.state
	_check(not rules.generate(random, ATTACK, "unknown")["ok"] and random.state == before, "Unknown exclusion rejects without advancing randomness")
	_check(not rules.regenerate_attributes("unknown", random, ATTACK)["ok"] and random.state == before, "Unknown attribute-reroll rarity rejects before randomness")
	_check(not rules.generate(random, ATTACK, "", "unknown")["ok"] and random.state == before, "Unknown profiles never fall back to attack rolls")
	_check(not rules.generate(null, ATTACK)["ok"], "Missing injected RNG is an explicit failure")
	_check(not rules.validation_errors(PackedStringArray(["damage", "damage"])).is_empty(), "Duplicate compatibility effects are invalid")
	_check(not rules.validation_errors(PackedStringArray(["fake_effect"])).is_empty(), "Unknown compatibility effects are invalid")
	_check(not rules.validation_errors(PackedStringArray(["economy_production"])).is_empty(), "Economy effects cannot silently truncate attack profile slots")
	_check(not TowerRollRules.new().validation_errors(ATTACK).is_empty(), "A new empty resource never invents shipped defaults")
	for bad_weight: float in [NAN, INF, -1.0]:
		var invalid: TowerRollRules = _rules()
		invalid.rarities[0]["weight"] = bad_weight
		_check(not invalid.validation_errors(ATTACK).is_empty(), "Nonfinite or negative weights reject")
	var one_weight: TowerRollRules = _rules()
	for tier: Dictionary in one_weight.rarities:
		tier["weight"] = 1.0 if tier["id"] == "common" else 0.0
	_check(not one_weight.validation_errors(ATTACK).is_empty(), "One weighted rarity cannot satisfy exclusion rerolls")
	for bad_bounds: Vector2 in [Vector2(NAN, 0.2), Vector2(0.1, INF), Vector2(0.3, 0.1), Vector2(-0.1, 0.1)]:
		var invalid: TowerRollRules = _rules()
		_tier(invalid, "common")["positive_pool"]["damage"] = bad_bounds
		_check(not invalid.validation_errors(ATTACK).is_empty(), "Nonfinite, reversed or wrong-sign pool bounds reject")
	var fractional: TowerRollRules = _rules()
	_tier(fractional, "rare")["positive_pool"]["pierce"] = Vector2(0.5, 1.5)
	_check(not fractional.validation_errors(ATTACK).is_empty(), "Fractional mechanical count bounds reject")
	var zero_stat: TowerRollRules = _rules()
	_tier(zero_stat, "common")["drawback_pool"]["damage"] = Vector2(-1.0, -0.1)
	_check(not zero_stat.validation_errors(ATTACK).is_empty(), "Drawbacks cannot zero or reverse a base stat")
	var missing: TowerRollRules = _rules()
	missing.rarities.pop_back()
	_check(not missing.validation_errors(ATTACK).is_empty(), "Every ladder tier must be authored even when its weight is zero")
	var invalid_profile: TowerRollRules = _rules()
	invalid_profile.slot_profiles["economy"]["common"] = Vector2i(-1, 0)
	_check(not invalid_profile.validation_errors(ATTACK).is_empty(), "Malformed authored profile overrides invalidate the whole resource")


func _test_mechanics_and_detachment() -> void:
	var rules: TowerRollRules = _rules()
	var rare: Dictionary = _tier(rules, "rare")
	rare["positive_pool"] = {"damage": Vector2(0.25, 0.25), "pierce": Vector2(2, 2)}
	var result: Dictionary = rules.regenerate_attributes("rare", _random(3), ATTACK)
	var attributes: Array[Dictionary] = result["attributes"]
	var modifiers: Dictionary = TowerRollRules.modifiers(attributes)
	_check(is_equal_approx(modifiers["damage"], 0.25) and modifiers["pierce"] == 2.0, "Snapshot modifiers preserve fractions and additive mechanic counts")
	_check(2 + int(modifiers["pierce"]) == 4, "Rolled pierce adds to an evolution capacity instead of replacing it")
	attributes[0]["value"] = 999.0
	attributes.append({"id": "fake", "effect": "fake", "value": 1.0, "positive": true})
	var again: Dictionary = rules.regenerate_attributes("rare", _random(3), ATTACK)
	_check(again["attributes"].size() == 2 and again["attributes"][0]["value"] != 999.0, "Returned attributes own detached dictionaries, not shared resource or cached state")
	_check(rare["positive_pool"]["damage"] == Vector2(0.25, 0.25), "Mutating a returned snapshot cannot retune source bounds")


func _test_costs() -> void:
	var rules: TowerRollRules = _rules()
	for kind: String in ["rarity", "attribute"]:
		var curve: Vector3 = rules.rarity_reroll_cost_curve if kind == "rarity" else rules.attribute_reroll_cost_curve
		var previous: int = 0
		var previous_increment: int = 0
		for count: int in range(64):
			var cost: int = rules.rarity_reroll_cost(count) if kind == "rarity" else rules.attribute_reroll_cost(count)
			var expected: int = ceili(curve.x + curve.y * count + curve.z * count * count)
			_check(cost == expected and cost > previous, "Reroll costs follow their authored quadratic smoothly at every count")
			if count > 1:
				_check(cost - previous > previous_increment, "Successive cost increases accelerate without bracket boundaries")
			previous_increment = cost - previous
			previous = cost
	_check(rules.rarity_reroll_cost(-1) == -1 and rules.attribute_reroll_cost(-1) == -1, "Negative counters are explicit invalid costs, never free rerolls")
	_check(rules.rarity_reroll_cost(9223372036854775807) == -1, "Costs beyond exact integer precision reject instead of wrapping or granting free rerolls")
	var original_rarity: int = rules.rarity_reroll_cost(4)
	rules.attribute_reroll_cost_curve = Vector3(3.25, 1.5, 0.25)
	_check(rules.attribute_reroll_cost(0) == 4 and rules.attribute_reroll_cost(1) == 5 and rules.attribute_reroll_cost(2) == 8, "Fractional authored costs round upward at payment boundaries")
	_check(rules.rarity_reroll_cost(4) == original_rarity, "Attribute and rarity cost curves are independent")
	for curve: Vector3 in [Vector3(INF, 1, 1), Vector3(0, 1, 1), Vector3(1, -1, 1), Vector3(1, 1, 0)]:
		rules.rarity_reroll_cost_curve = curve
		_check(rules.rarity_reroll_cost(0) == -1 and not rules.validation_errors(ATTACK).is_empty(), "Malformed cost curves fail before charging")
