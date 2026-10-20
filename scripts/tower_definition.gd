class_name TowerDefinition
extends Resource

const SECOND_ARCHER_ATTACK_RATE_MULTIPLIER: float = 1.1
const BOUNCE_DAMAGE_MULTIPLIER: float = 0.5
const FREEZE_HP_SCALE: float = 100.0
const FREEZE_SPEED_MULTIPLIER: float = 0.8
const FREEZE_DURATION: float = 2.0
# Most homing bolts one Magic Ballista shot may split into.
const MAX_MAGIC_SPLIT: int = 5
# Rune evolutions that deal continuous (rather than pulsed) damage.
const CONTINUOUS_RUNE_BRANCHES: Array[String] = ["boulders", "void_monolith"]
# Orcapult evolutions and the arm properties their steps may raise.
const CATAPULT_BRANCHES: Array[String] = ["siege_arm", "long_toss"]
const CATAPULT_KEYS: Array[String] = ["lift", "throw_count", "slam_radius", "landing_progress", "landing_haste"]
# War Drums evolutions and the aura strengths their steps may raise. range_aura
# adds cells of reach to nearby attacking towers; crit_chance gives their
# discrete hits that chance to deal CRIT_MULTIPLIER damage.
const SUPPORT_BRANCHES: Array[String] = ["forge", "command_banner", "lookout_horn", "bloodlust_totem"]
const SUPPORT_KEYS: Array[String] = ["damage_bonus", "attack_speed_bonus", "range_aura", "crit_chance"]
const CRIT_MULTIPLIER: float = 2.0
const MAX_CRIT_CHANCE: float = 0.75

@export var reward: TowerReward
@export var damage: int = 2
@export var damage_type: StringName = &"physical"
@export var range_cells: float = 3.0
@export var interval: float = 0.75
@export var cost: int = 45
@export var upgrade_base_cost: int = 30
@export var damage_upgrade_bonus: int = 1
@export var speed_upgrade_multiplier: float = 0.8
@export var area_attack: bool = false
# "attack" retains the original direct/area attack rules. Other kinds are
# mechanics, never collection identities; configs are captured by the host.
@export_enum("attack", "chain", "support", "economy", "catapult") var behavior_kind: String = "attack"
@export var behavior_config: Dictionary = {}
# Passive buildings use role-specific effects for the existing damage/speed
# purchase actions; attack kinds retain the ordinary numerical stat upgrades.
@export var upgrade_effects: Dictionary = {}
# Explicit eligible effects, including effects compatible with future branches.
# Empty is valid for injected catalogs that do not opt into placement rolls.
@export var roll_attributes: PackedStringArray = PackedStringArray()
# Rarity rules resolve authored rarity-specific slot overrides by profile.
@export_enum("attack", "support", "economy") var roll_profile: String = "attack"
# Presentation family, not a targeting or damage rule.
@export_enum("Bow", "Ballista", "Rune") var attack_sound: int = CombatSoundEvents.Cue.BOW
@export var special_upgrade: String = ""
@export var special_upgrade_title: String = ""
@export var special_upgrade_cost: int = 0
@export var special_upgrade_config: Dictionary = {}
@export var evolutions: Dictionary = {}
@export var advancements: Dictionary = {}


static func freeze_duration(max_hp: int) -> float:
	return FREEZE_DURATION / (1.0 + float(max_hp) / FREEZE_HP_SCALE)




static func valid_advancements(definition: TowerDefinition) -> bool:
	if not definition.advancements.is_empty() and (definition.behavior_kind != "attack" or definition.special_upgrade != "second_archer" or definition.area_attack or not definition.evolutions.is_empty()):
		return false
	for branch: Variant in definition.advancements:
		if not branch is String or String(branch).is_empty() or branch in ["damage", "speed", "special"] or not definition.advancements[branch] is Dictionary:
			return false
		var config: Dictionary = definition.advancements[branch]
		if not _valid_advancement(config):
			return false
		var effective_interval: float = definition.interval * definition.speed_upgrade_multiplier / SECOND_ARCHER_ATTACK_RATE_MULTIPLIER / float(config.get("attack_rate_multiplier", 1.0))
		var visited: Dictionary = {branch: true}
		var previous: String = String(config.get("requires", ""))
		while not previous.is_empty():
			if visited.has(previous) or not definition.advancements.has(previous) or not definition.advancements[previous] is Dictionary:
				return false
			visited[previous] = true
			var ancestor: Dictionary = definition.advancements[previous]
			if not _valid_advancement(ancestor):
				return false
			effective_interval /= float(ancestor.get("attack_rate_multiplier", 1.0))
			previous = String(ancestor.get("requires", ""))
		if not is_finite(effective_interval) or effective_interval <= 0.0:
			return false
	return true


static func _valid_advancement(config: Dictionary) -> bool:
	if not config.get("title") is String or String(config["title"]).strip_edges().is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
		return false
	var numeric: Array[String] = ["attack_rate_multiplier", "primary_multiplier", "splash_multiplier", "splash_radius", "burn_dps", "burn_duration", "continuous_dps", "fuel_duration", "refuel_duration"]
	for field: Variant in config:
		if field in numeric:
			if not _positive_number(config[field]):
				return false
		elif field not in ["title", "cost", "requires", "weapon", "archer_count"]:
			return false
	if config.has("requires") and (not config["requires"] is String or String(config["requires"]).is_empty()):
		return false
	var weapon: Variant = config.get("weapon", "arrow")
	if not weapon is String or weapon not in ["arrow", "molotov", "flamethrower", "grenade", "rocket", "minigun"]:
		return false
	if config.has("archer_count") and (not config["archer_count"] is int or int(config["archer_count"]) < 1 or int(config["archer_count"]) > 8):
		return false
	if not config.has("archer_count") and not config.has("attack_rate_multiplier") and not config.has("primary_multiplier") and not config.has("splash_radius") and not config.has("burn_dps") and not config.has("continuous_dps"):
		return false
	if config.has("splash_radius") != config.has("splash_multiplier") or config.has("burn_dps") != config.has("burn_duration"):
		return false
	if weapon in ["flamethrower", "rocket", "minigun"] and config.get("archer_count") != 1:
		return false
	if weapon in ["molotov", "grenade", "rocket"] and (not config.has("primary_multiplier") or not config.has("splash_radius")):
		return false
	if weapon == "molotov" and not config.has("burn_dps"):
		return false
	if weapon == "flamethrower":
		return config.has("continuous_dps") and config.has("fuel_duration") and config.has("refuel_duration") and config.has("burn_dps") and not config.has("primary_multiplier") and not config.has("splash_radius")
	return not config.has("continuous_dps") and not config.has("fuel_duration") and not config.has("refuel_duration")


static func valid_evolutions(definition: TowerDefinition) -> bool:
	if definition.behavior_kind != "attack":
		return _valid_role_evolutions(definition)
	if not definition.evolutions.is_empty() and not definition.special_upgrade.is_empty():
		return false
	for branch: Variant in definition.evolutions:
		if not branch is String or branch not in ["boulders", "onyx_ring", "storm_sigil", "void_monolith", "pierce", "bounce"] or not definition.evolutions[branch] is Dictionary:
			return false
		var config: Dictionary = definition.evolutions[branch]
		if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
			return false
		if branch in ["pierce", "bounce"]:
			if definition.area_attack or config.size() != (3 if config.has("upgrades") else 2):
				return false
			if config.has("upgrades") and not valid_branch_upgrades(String(branch), config["upgrades"]):
				return false
			for other_branch: Variant in definition.evolutions:
				if other_branch not in ["pierce", "bounce"]:
					return false
			continue
		if not config.get("damage") is int or int(config["damage"]) <= 0 or not config.get("continuous") is bool:
			return false
		if typeof(config.get("interval")) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var interval: float = float(config["interval"])
		if not is_finite(interval) or (bool(config["continuous"]) and interval != 0.0) or (not bool(config["continuous"]) and interval <= 0.0):
			return false
		if bool(config["continuous"]) != (branch in CONTINUOUS_RUNE_BRANCHES) or not definition.area_attack:
			return false
		if config.has("damage_type") and String(config["damage_type"]) not in ["physical", "magic", "lightning"]:
			return false
		if config.has("max_hp_damage") and (branch != "void_monolith" or not _nonnegative_number(config["max_hp_damage"])):
			return false
		if config.has("description") and not config["description"] is String:
			return false
		if config.has("upgrades") and not valid_branch_upgrades(String(branch), config["upgrades"]):
			return false
		if branch == "boulders" and not config.has("followup"):
			return false
		if config.has("followup"):
			if branch != "boulders" or not config["followup"] is Dictionary:
				return false
			var followup: Dictionary = config["followup"]
			if followup.get("id") != "freeze_runes" or not followup.get("title") is String or String(followup["title"]).is_empty() or not followup.get("cost") is int or int(followup["cost"]) <= 0:
				return false
	return true


# Ordered Ballista branch upgrades, bought one after another after Pierce/Bounce.
static func valid_branch_upgrades(branch: String, upgrades: Variant) -> bool:
	if not upgrades is Array or (upgrades as Array).is_empty():
		return false
	var seen: Dictionary = {}
	for step: Variant in upgrades:
		if not step is Dictionary:
			return false
		var config: Dictionary = step
		var id: Variant = config.get("id")
		if not id is String or String(id).is_empty() or seen.has(id) or id in ["damage", "speed", "special", "pierce", "bounce"]:
			return false
		seen[id] = true
		if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
			return false
		for field: Variant in config:
			if field not in ["id", "title", "cost", "description", "damage_multiplier", "pierce", "attack_rate_multiplier", "bolt_scale", "bolt_reach", "damage_type", "magic_bounce", "magic_split", "orbit_bonus", "range_bonus", "max_hp_damage", "behavior_add", "periodic_interval_multiplier"]:
				return false
		for field: String in ["damage_multiplier", "attack_rate_multiplier"]:
			if config.has(field) and not _positive_number(config[field]):
				return false
		for field: String in ["bolt_scale", "bolt_reach"]:
			if config.has(field) and not _nonnegative_number(config[field]):
				return false
		for field: String in ["pierce", "orbit_bonus"]:
			if config.has(field) and (not config[field] is int or int(config[field]) < 0):
				return false
		if config.has("range_bonus") and not _nonnegative_number(config["range_bonus"]):
			return false
		if config.has("description") and not config["description"] is String:
			return false
		if config.has("max_hp_damage") and (branch != "void_monolith" or not _nonnegative_number(config["max_hp_damage"])):
			return false
		if config.has("periodic_interval_multiplier") and (branch != "crystal_mine" or not _positive_number(config["periodic_interval_multiplier"])):
			return false
		if config.has("behavior_add"):
			var added: Variant = config["behavior_add"]
			if branch not in ["crystal_mine"] + CATAPULT_BRANCHES + SUPPORT_BRANCHES or not added is Dictionary or (added as Dictionary).is_empty():
				return false
			for key: Variant in added:
				if branch in SUPPORT_BRANCHES:
					if key not in SUPPORT_KEYS or not _positive_number(added[key]):
						return false
				elif branch == "crystal_mine":
					if key not in ["clear_shards", "periodic_shards"] or not added[key] is int or int(added[key]) <= 0:
						return false
				elif key not in CATAPULT_KEYS or not _positive_number(added[key]) or (key == "throw_count" and not added[key] is int):
					return false
		if branch in SUPPORT_BRANCHES:
			for field: Variant in config:
				if field not in ["id", "title", "cost", "description", "range_bonus", "behavior_add"]:
					return false
		if branch in CATAPULT_BRANCHES:
			for field: Variant in config:
				if field not in ["id", "title", "cost", "description", "damage_multiplier", "attack_rate_multiplier", "range_bonus", "behavior_add"]:
					return false
		if config.has("damage_type") and String(config["damage_type"]) not in ["physical", "magic"]:
			return false
		if config.has("magic_split") and (branch != "bounce" or not config["magic_split"] is int or int(config["magic_split"]) < 2 or int(config["magic_split"]) > MAX_MAGIC_SPLIT):
			return false
		if config.has("magic_bounce"):
			var magic: Variant = config["magic_bounce"]
			if branch != "bounce" or not magic is Dictionary or (magic as Dictionary).size() != 2 or not _positive_number(magic.get("chance")) or float(magic["chance"]) > 1.0 or not _nonnegative_number(magic.get("decay")):
				return false
	return true


# Exclusive late paths offered once every ordered step is bought: a dictionary
# of path key -> ordered steps. Steps may raise base max HP / per-clear regen
# (whole HP) or multiply the mine's Shard output.
static func valid_capstones(upgrades: Array, capstones: Variant) -> bool:
	if not capstones is Dictionary or (capstones as Dictionary).size() < 2:
		return false
	var seen: Dictionary = {}
	for step: Dictionary in upgrades:
		seen[step["id"]] = true
	for path: Variant in capstones:
		var steps: Variant = capstones[path]
		if not path is String or String(path).is_empty() or not steps is Array or (steps as Array).is_empty():
			return false
		for step: Variant in steps:
			if not step is Dictionary:
				return false
			var config: Dictionary = step
			var id: Variant = config.get("id")
			if not id is String or String(id).is_empty() or seen.has(id) or id in ["damage", "speed", "special"]:
				return false
			seen[id] = true
			if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
				return false
			if config.has("description") and not config["description"] is String:
				return false
			var effects: int = 0
			# Per-round max HP growth always names the max HP it stops at.
			if config.has("base_max_health_per_round") != config.has("base_max_health_limit"):
				return false
			for field: Variant in config:
				match field:
					"id", "title", "cost", "description":
						pass
					"base_max_health_limit":
						if not config[field] is int or int(config[field]) <= 0:
							return false
					"base_max_health_per_round", "base_regen":
						if not config[field] is int or int(config[field]) <= 0:
							return false
						effects += 1
					"output_multiplier":
						if not _positive_number(config[field]) or float(config[field]) <= 1.0:
							return false
						effects += 1
					_:
						return false
			if effects == 0:
				return false
	return true


static func valid_behavior(definition: TowerDefinition) -> bool:
	if definition.behavior_kind == "attack":
		return definition.behavior_config.is_empty() and definition.upgrade_effects.is_empty()
	if definition.area_attack or not _valid_behavior_config(definition.behavior_kind, definition.behavior_config):
		return false
	if definition.behavior_kind in ["chain", "catapult"]:
		return definition.upgrade_effects.is_empty()
	if definition.behavior_kind not in ["support", "economy"] or definition.upgrade_effects.size() != 2:
		return false
	var damage_effect: Variant = definition.upgrade_effects.get("damage")
	var speed_effect: Variant = definition.upgrade_effects.get("speed")
	if not damage_effect is Dictionary or not speed_effect is Dictionary:
		return false
	if definition.behavior_kind == "support":
		return _positive_effect(damage_effect, "damage_bonus") and _positive_effect(speed_effect, "attack_speed_bonus")
	return _positive_effect(damage_effect, "income_bonus") and _positive_effect(speed_effect, "income_bonus")


static func valid_special_upgrade(definition: TowerDefinition) -> bool:
	match definition.special_upgrade:
		"":
			# Old injected catalogs may retain unused title/cost metadata.
			return definition.special_upgrade_config.is_empty()
		"second_archer":
			return definition.behavior_kind == "attack" and not definition.area_attack and not definition.special_upgrade_title.is_empty() and definition.special_upgrade_cost > 0 and definition.special_upgrade_config.is_empty()
		"escalating_chain":
			return definition.behavior_kind == "chain" and not definition.special_upgrade_title.is_empty() and definition.special_upgrade_cost > 0 and _positive_effect(definition.special_upgrade_config, "successive_hit_bonus")
		"double_scoop":
			return definition.behavior_kind == "catapult" and not definition.special_upgrade_title.is_empty() and definition.special_upgrade_cost > 0 and definition.special_upgrade_config.size() == 1 and definition.special_upgrade_config.get("extra_throws") is int and int(definition.special_upgrade_config["extra_throws"]) > 0
	return false


static func valid_roll_attributes(definition: TowerDefinition) -> bool:
	if definition.roll_profile != ("support" if definition.behavior_kind == "support" else ("economy" if definition.behavior_kind == "economy" else "attack")):
		return false
	var allowed: PackedStringArray = PackedStringArray()
	match definition.behavior_kind:
		"attack":
			allowed = PackedStringArray(["damage", "attack_speed", "range"])
			if not definition.area_attack:
				allowed.append_array(PackedStringArray(["pierce", "bounce"]))
		"chain":
			allowed = PackedStringArray(["damage", "attack_speed", "range", "chain_jumps"])
		"catapult":
			allowed = PackedStringArray(["damage", "attack_speed", "range"])
		"support":
			allowed = PackedStringArray(["range", "support_buff"])
		"economy":
			allowed = PackedStringArray(["economy_production"])
	var seen: Dictionary[String, bool] = {}
	for effect: String in definition.roll_attributes:
		if effect not in allowed or seen.has(effect):
			return false
		seen[effect] = true
	return true


static func _valid_behavior_config(kind: String, config: Dictionary) -> bool:
	match kind:
		"chain":
			return config.size() == 3 and config.get("hit_count") is int and int(config["hit_count"]) > 0 and _positive_number(config.get("jump_distance")) and _nonnegative_number(config.get("successive_hit_bonus"))
		"support":
			if not config.get("stack_group") is String or String(config["stack_group"]).is_empty() or not _nonnegative_number(config.get("damage_bonus")) or not _nonnegative_number(config.get("attack_speed_bonus")):
				return false
			var strength: float = float(config["damage_bonus"]) + float(config["attack_speed_bonus"])
			for key: Variant in config:
				if key in ["range_aura", "crit_chance"]:
					if not _nonnegative_number(config[key]):
						return false
					strength += float(config[key])
				elif key not in ["stack_group", "damage_bonus", "attack_speed_bonus"]:
					return false
			return strength > 0.0 and float(config.get("crit_chance", 0.0)) <= MAX_CRIT_CHANCE
		"economy":
			if config.size() != 3 or not config.get("clear_income") is int or int(config["clear_income"]) <= 0 or not config.get("periodic_income") is int or int(config["periodic_income"]) < 0 or not _nonnegative_number(config.get("periodic_interval")):
				return false
			return (int(config["periodic_income"]) == 0) == (float(config["periodic_interval"]) == 0.0)
		"bounty":
			return config.size() == 2 and _positive_number(config.get("mark_damage_bonus")) and _positive_number(config.get("mark_income_bonus"))
		"crystal":
			# Shards instead of Coins. Periodic Shards may start at zero with a
			# ready interval that later upgrades switch on.
			return config.size() == 3 and config.get("clear_shards") is int and int(config["clear_shards"]) > 0 and config.get("periodic_shards") is int and int(config["periodic_shards"]) >= 0 and _positive_number(config.get("periodic_interval"))
		"catapult":
			# lift: heaviest enemy health multiplier the arm can grab.
			return config.size() == 5 and _positive_number(config.get("lift")) and config.get("throw_count") is int and int(config["throw_count"]) > 0 and _nonnegative_number(config.get("slam_radius")) and _nonnegative_number(config.get("landing_progress")) and _positive_number(config.get("landing_haste")) and float(config["landing_haste"]) >= 1.0
		"income_aura":
			return config.size() == 2 and config.get("stack_group") is String and not String(config["stack_group"]).is_empty() and _positive_number(config.get("kill_income_bonus"))
	return false


static func _valid_role_evolutions(definition: TowerDefinition) -> bool:
	if definition.behavior_kind not in ["chain", "support", "economy", "catapult"] or not _valid_behavior_config(definition.behavior_kind, definition.behavior_config):
		return false
	if definition.behavior_kind not in ["chain", "catapult"] and not definition.special_upgrade.is_empty():
		return false
	for branch: Variant in definition.evolutions:
		if not branch is String or not definition.evolutions[branch] is Dictionary:
			return false
		var config: Dictionary = definition.evolutions[branch]
		if not _valid_role_branch(config):
			return false
		match definition.behavior_kind:
			"catapult":
				if branch not in CATAPULT_BRANCHES or config["behavior_kind"] != "catapult" or definition.special_upgrade != "double_scoop":
					return false
				for field: Variant in config:
					if field not in ["title", "cost", "behavior_kind", "behavior_config", "description", "upgrades"]:
						return false
				if config.has("description") and not config["description"] is String:
					return false
				if config.has("upgrades") and not valid_branch_upgrades(String(branch), config["upgrades"]):
					return false
			"chain":
				if branch != "longer_reach" or definition.special_upgrade != "escalating_chain" or config.size() != 5 or config["behavior_kind"] != "chain" or not _positive_number(config.get("range_cells")) or float(config["range_cells"]) <= definition.range_cells or float(config["behavior_config"]["jump_distance"]) <= float(definition.behavior_config.get("jump_distance", INF)):
					return false
			"support":
				if branch not in SUPPORT_BRANCHES or config["behavior_kind"] != "support":
					return false
				for field: Variant in config:
					if field not in ["title", "cost", "behavior_kind", "behavior_config", "description", "upgrades"]:
						return false
				if config.has("description") and not config["description"] is String:
					return false
				if config.has("upgrades") and not valid_branch_upgrades(String(branch), config["upgrades"]):
					return false
				var effect: Dictionary = config["behavior_config"]
				if branch == "lookout_horn" and float(effect.get("range_aura", 0.0)) <= 0.0:
					return false
				if branch == "bloodlust_totem" and float(effect.get("crit_chance", 0.0)) <= 0.0:
					return false
				if branch == "forge" and (float(effect["damage_bonus"]) <= 0.0 or float(effect["attack_speed_bonus"]) != 0.0):
					return false
				if branch == "command_banner" and (float(effect["attack_speed_bonus"]) <= 0.0 or float(effect["damage_bonus"]) != 0.0):
					return false
			"economy":
				if branch == "royal_mint":
					if config.size() != 4 or config["behavior_kind"] != "economy" or int(config["behavior_config"]["clear_income"]) < int(definition.behavior_config.get("clear_income", 0)) or int(config["behavior_config"]["periodic_income"]) <= 0:
						return false
				elif branch == "crystal_mine":
					if config["behavior_kind"] != "crystal" or not config.get("upgrades") is Array or not valid_branch_upgrades("crystal_mine", config["upgrades"]):
						return false
					for field: Variant in config:
						if field not in ["title", "cost", "behavior_kind", "behavior_config", "description", "upgrades", "capstones"]:
							return false
					if config.has("capstones") and not valid_capstones(config["upgrades"], config["capstones"]):
						return false
				elif branch == "bounty_board":
					if config.size() != 5 or config["behavior_kind"] != "bounty" or not config.get("followups") is Dictionary or not _valid_bounty_followups(config["followups"], config["behavior_config"]):
						return false
				else:
					return false
	return true


static func _valid_role_branch(config: Dictionary) -> bool:
	return config.get("title") is String and not String(config["title"]).is_empty() and config.get("cost") is int and int(config["cost"]) > 0 and config.get("behavior_kind") is String and config.get("behavior_config") is Dictionary and _valid_behavior_config(String(config["behavior_kind"]), config["behavior_config"])


static func _valid_bounty_followups(followups: Dictionary, base: Dictionary) -> bool:
	if followups.is_empty():
		return false
	for branch: Variant in followups:
		if branch not in ["stronger_mark", "income_aura"] or not followups[branch] is Dictionary:
			return false
		var config: Dictionary = followups[branch]
		if config.size() != 4 or not _valid_role_branch(config):
			return false
		if config["behavior_kind"] != ("bounty" if branch == "stronger_mark" else "income_aura"):
			return false
		if branch == "stronger_mark" and (float(config["behavior_config"]["mark_damage_bonus"]) <= float(base["mark_damage_bonus"]) or float(config["behavior_config"]["mark_income_bonus"]) <= float(base["mark_income_bonus"])):
			return false
	return true


static func _positive_effect(effect: Dictionary, key: String) -> bool:
	return effect.size() == 1 and _positive_number(effect.get(key))


static func _positive_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) > 0.0


static func _nonnegative_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0
