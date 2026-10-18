class_name MatchCombat
extends RefCounted

enum Phase { PLANNING, WAVE, FINISHED }
enum TargetMode { FURTHEST, CLOSEST, STRONGEST, LAST = 3 }

const DEATH_EVENT_LIFETIME: float = 2.0
const NO_BONUS: Dictionary = {}

var phase: Phase = Phase.PLANNING
var wave: int = 0
var base_health: Array[int] = []
var coins: Array[int] = []
var reroll_currency: Array[int] = [0, 0]
# Recurring bonus on each surviving wave clear; queues belong to the target board.
var income: Array[int] = [0, 0]
var queued_sends: Array[int]:
	get:
		return [_pending_sends(0), _pending_sends(1)]
var winner: int = -1
var coin_flip: bool = false
var towers: Array[Array] = [[], []]
var enemies: Array[Array] = [[], []]
# One host-generated ordered regular stream, replayed independently on both boards.
var wave_roster: Array[String] = []
var spawn_times: Array[float] = []
var wave_groups: Array[Dictionary] = []
var statistics_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var enemy_totals: Array[Dictionary] = [{"kills": {}, "sent": {}}, {"kills": {}, "sent": {}}]
var _death_events: Array[Array] = [[], []]
var _death_heads: Array[int] = [0, 0]
var _death_time: float = 0.0
var _death_generation: int = 0
var _next_death_id: int = 1
var _sound_events := CombatSoundEvents.new()
var _sandbox_mode: bool = false
# Parallel to the individual FIFO: only the last member waits ordinary cooldown.
var _send_group_ends: Array[Array] = [[], []]
var _special_stream: bool = false

var _rules: CombatRules
# Captured once from resources so commands, attacks, and snapshots share host-owned stats.
var _tower_types: Dictionary = {}
var _enemy_types: Dictionary = {}
var _send_queues: Array[Array] = [[], []]
# Consumed prefixes are compacted amortized, never shifted for each delivery.
var _send_heads: Array[int] = [0, 0]
var _next_send_times: Array[float] = [0.0, 0.0]
var _send_spawn_interval: float
var _active_send_spawn_interval: float = 0.0
var _spawn_interval_reduction_per_wave: float
var _max_spawn_interval_reduction: float
var _random: RandomNumberGenerator
var _wave_random: RandomNumberGenerator
var _timing_random: RandomNumberGenerator
var _group_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _roll_random := RandomNumberGenerator.new()
var _drop_random := RandomNumberGenerator.new()
var _roll_rules: TowerRollRules
var _roster_configuration_valid: bool = true
var _routes: Array[Array] = [[], []]
var _routing_next: Array[Dictionary] = [{}, {}]
var _fork_cursors: Array[Dictionary] = [{}, {}]
var _spawned: Array[int] = [0, 0]
var _elapsed: float = 0.0
var _next_tower_id: int = 1
var _next_enemy_id: int = 1
# Host-only fractional HP, isolated by tower and enemy and retired with either.
var _continuous_damage: Dictionary = {}
# Fractional vulnerability credit follows its original Board, not the current mark.
var _continuous_bonus: Dictionary = {}
# Spawn times cap first-tick exposure even when due events arrive mid-tick.
var _enemy_spawn_times: Dictionary = {}
# Only enemies slowed at tick start need a two-speed historical motion record.
# Reused float records retain precision without per-tick history allocations.
var _slow_motion: Dictionary = {}
var _step_start_time: float = 0.0
# Burn retains its original tower dictionary even after sale, never in snapshots.
var _burns: Dictionary = {}
var _speed_cache_wave: int = -1
var _current_wave_speed: float = 0.0
var _next_wave_speed: float = 0.0


func _init(rules: CombatRules, random: RandomNumberGenerator = null, wave_random: RandomNumberGenerator = null, timing_random: RandomNumberGenerator = null, roll_random: RandomNumberGenerator = null, drop_random: RandomNumberGenerator = null) -> void:
	# Freeze admitted rules; resource edits cannot enable a match bypass.
	_rules = rules.duplicate() as CombatRules
	_sandbox_mode = rules.sandbox_mode
	_send_spawn_interval = rules.send_spawn_interval
	_spawn_interval_reduction_per_wave = rules.spawn_interval_reduction_per_wave
	_max_spawn_interval_reduction = rules.max_spawn_interval_reduction
	_random = random
	if _random == null:
		_random = RandomNumberGenerator.new()
		_random.randomize()
	_wave_random = wave_random
	if _wave_random == null:
		_wave_random = RandomNumberGenerator.new()
		_wave_random.randomize()
	_timing_random = timing_random
	if _timing_random == null:
		_timing_random = RandomNumberGenerator.new()
		_timing_random.randomize()
	# Paid groups/rituals never perturb regular composition, timing or tie rolls.
	_group_random.seed = _wave_random.seed ^ 0x534b454c
	_roll_random = roll_random if roll_random != null else RandomNumberGenerator.new()
	if roll_random == null:
		_roll_random.seed = _wave_random.seed ^ 0x524f4c4c
	_drop_random = drop_random if drop_random != null else RandomNumberGenerator.new()
	if drop_random == null:
		_drop_random.seed = _wave_random.seed ^ 0x44524f50
	reroll_currency = [rules.starting_reroll_currency, rules.starting_reroll_currency]
	if rules.starting_reroll_currency < 0 or rules.clear_reroll_currency < 0:
		push_error("Reroll currency grants must be nonnegative")
		_roster_configuration_valid = false
	if rules.roll_rules != null:
		_roll_rules = rules.roll_rules.duplicate(true) as TowerRollRules
	if rules.wave_weight <= 0 or rules.wave_weight_growth < 0 or not is_finite(rules.spawn_interval) or rules.spawn_interval < 0.0:
		push_error("Combat waves require positive weight, nonnegative growth and a finite nonnegative spawn interval")
		_roster_configuration_valid = false
	if not rules.valid_speed_progression():
		push_error("Combat speed requires a finite nonnegative baseline/growth fraction and positive milestone round span")
		_roster_configuration_valid = false
	base_health = [rules.base_health, rules.base_health]
	coins = [rules.starting_coins, rules.starting_coins]
	if rules.catalog == null:
		push_error("Combat requires a content catalog")
		_roster_configuration_valid = false
		return
	var catalog_errors: PackedStringArray = rules.catalog.validation_errors()
	if not catalog_errors.is_empty():
		push_error("Invalid content catalog: " + " ".join(catalog_errors))
		_roster_configuration_valid = false
		return
	for definition: EnemyDefinition in rules.catalog.enemies:
		var type_id: String = String(definition.id)
		_enemy_types[type_id] = {
			"title": definition.title, "health_multiplier": definition.health_multiplier,
			"description": definition.description,
			"fire_immune": definition.fire_immune, "ice_immune": definition.ice_immune,
			"death_sound": CombatSoundEvents.Cue.BONES if definition.blood_color.a == 0.0 else CombatSoundEvents.Cue.DEATH,
			"speed_multiplier": definition.speed_multiplier,
			"send_cost": definition.send_cost, "send_income": definition.send_income,
			"base_damage": definition.base_damage, "spawn_weight": definition.spawn_weight,
			"first_wave": definition.first_wave, "max_per_wave": definition.max_per_wave,
			"count_cap_growth": definition.count_cap_growth,
			"count_cap_growth_interval": definition.count_cap_growth_interval,
			"max_weight_share": definition.max_weight_share,
			"send_first_wave": definition.send_first_wave,
			"regular_spawn_enabled": definition.regular_spawn_enabled,
			"boss": definition.boss, "boss_spawn_chance": definition.boss_spawn_chance,
			"boss_spawn_chance_growth": definition.boss_spawn_chance_growth,
			"boss_spawn_chance_cap": definition.boss_spawn_chance_cap,
			"send_enabled": definition.send_enabled,
			"group_weights": definition.group_weights.duplicate(),
			"group_interval": definition.group_interval, "kill_bounty": definition.kill_bounty,
			"reroll_drop_chance": definition.reroll_drop_chance,
			"reroll_drop_amount": definition.reroll_drop_amount,
			"heal_interval": definition.heal_interval, "heal_radius": definition.heal_radius,
			"heal_fraction": definition.heal_fraction,
			"summon_interval": definition.summon_interval,
			"summon_cast_duration": definition.summon_cast_duration,
			"summon_type": String(definition.summon_type),
			"summon_min": definition.summon_min, "summon_max": definition.summon_max,
			"summon_limit": definition.summon_limit,
		}
	var has_remainder_enemy: bool = false
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.regular_spawn_enabled and not definition.boss and definition.spawn_weight == 1 and definition.first_wave == 1 and definition.max_per_wave == 0 and definition.max_weight_share == 1.0:
			has_remainder_enemy = true
	if not has_remainder_enemy:
		push_error("Combat regular waves require an always-unlocked weight-one enemy with unlimited count and full weight share")
		_roster_configuration_valid = false
	for definition: TowerDefinition in rules.catalog.towers:
		var type_id: String = String(definition.reward.id)
		_tower_types[type_id] = {
			"title": definition.reward.title, "damage": definition.damage,
			"range": definition.range_cells, "interval": definition.interval,
			"cost": definition.cost, "upgrade_base_cost": definition.upgrade_base_cost,
			"damage_upgrade_bonus": definition.damage_upgrade_bonus,
			"speed_upgrade_multiplier": definition.speed_upgrade_multiplier,
			"area_attack": definition.area_attack,
			"directional_weapon": not definition.reward.directional_weapon_textures.is_empty(),
			"attack_sound": definition.attack_sound,
			"special_upgrade": definition.special_upgrade,
			"special_upgrade_title": definition.special_upgrade_title,
			"special_upgrade_cost": definition.special_upgrade_cost,
			"evolutions": definition.evolutions.duplicate(true),
			"advancements": definition.advancements.duplicate(true),
			"behavior_kind": definition.behavior_kind,
			"behavior_config": definition.behavior_config.duplicate(true),
			"upgrade_effects": definition.upgrade_effects.duplicate(true),
			"special_upgrade_config": definition.special_upgrade_config.duplicate(true),
			"roll_attributes": definition.roll_attributes.duplicate(),
			"roll_profile": definition.roll_profile,
		}
		if _roll_rules != null:
			var roll_errors: PackedStringArray = _roll_rules.validation_errors(definition.roll_attributes, definition.roll_profile)
			if not roll_errors.is_empty():
				push_error("Invalid tower rolls for %s: %s" % [type_id, " ".join(roll_errors)])
				_roster_configuration_valid = false




func _can_build(slot: int, cell: Vector2i, type_id: StringName, mode: int) -> bool:
	return _roster_configuration_valid and phase != Phase.FINISHED and _valid_slot(slot) and _valid_mode(mode) and _tower_types.has(String(type_id)) and not has_tower(slot, cell) and (_sandbox_mode or coins[slot] >= int(_tower_types[String(type_id)]["cost"]))


func build(slot: int, cell: Vector2i, type_id: StringName, mode: int) -> bool:
	if not _can_build(slot, cell, type_id, mode):
		return false
	_build_accepted(slot, cell, type_id, mode, _placement_roll(_tower_types[String(type_id)]))
	return true


func build_mirrored(slot: int, cell: Vector2i, type_id: StringName, mode: int) -> bool:
	if not _can_build(slot, cell, type_id, mode) or not _can_build(1 - slot, cell, type_id, mode):
		return false
	var rolled: Dictionary = _placement_roll(_tower_types[String(type_id)])
	_build_accepted(slot, cell, type_id, mode, rolled)
	_build_accepted(1 - slot, cell, type_id, mode, rolled)
	return true


func _placement_roll(definition: Dictionary) -> Dictionary:
	if _roll_rules == null:
		return {"rarity": "", "attributes": [] as Array[Dictionary]}
	return _roll_rules.generate_admitted(_roll_random, definition["roll_attributes"], "", definition["roll_profile"])


func _build_accepted(slot: int, cell: Vector2i, type_id: StringName, mode: int, rolled: Dictionary) -> void:
	var definition: Dictionary = _tower_types[String(type_id)]
	var cost: int = definition["cost"]
	towers[slot].append({
		"id": _next_tower_id, "cell": cell, "type_id": String(type_id), "mode": mode, "cooldown": 0.0,
		"target_id": -1, "shot": 0, "aim": Vector2(cell),
		"tracking_target_id": -1, "tracking_aim": Vector2(cell),
		"kills": 0, "damage_dealt": 0, "coins_generated": 0, "indirect_damage": 0,
		"damage_upgraded": false, "speed_upgraded": false,
		"special_upgraded": false, "freeze_upgraded": false, "evolution": "", "secondary_mode": mode,
		"secondary_shot": 0, "secondary_aim": Vector2(cell), "secondary_target_id": -1,
		"advancement": "", "advancement_path": [] as Array[String], "extra_archers": [] as Array[Dictionary],
		"firing": false, "continuous_fire_time": 0.0, "refuel_remaining": 0.0, "refuel_duration": 0.0,
		"bounce_active": false, "bounce_aim": Vector2(cell),
		"pierce_active": false, "pierce_aim": Vector2(cell),
		"damage": definition["damage"], "interval": definition["interval"],
		"range": definition["range"], "base_damage": definition["damage"], "base_interval": definition["interval"],
		"behavior_kind": definition["behavior_kind"], "behavior_config": definition["behavior_config"].duplicate(true),
		"followup": "", "bounty_target_id": -1, "production_elapsed": 0.0,
		"chain_points": [] as Array[Vector2],
		"rarity": rolled["rarity"], "attributes": rolled["attributes"].duplicate(true),
		"rarity_rerolls": 0, "attribute_rerolls": 0,
		"rarity_reroll_cost": -1, "attribute_reroll_cost": -1,
		"support_damage_bonus": 0.0, "support_speed_bonus": 0.0,
		"invested": 0 if _sandbox_mode else cost, "sell_value": 0 if _sandbox_mode else _sell_value(cost),
	})
	if not _sandbox_mode:
		coins[slot] -= cost
	_next_tower_id += 1
	_refresh_board(slot)
	_update_tracking_target(slot, towers[slot].back())
	_sound_events.record(CombatSoundEvents.Cue.PURCHASE, slot, Vector2(cell), _death_time)


func _find_tower(slot: int, tower_id: int) -> Dictionary:
	for tower: Dictionary in towers[slot]:
		if int(tower["id"]) == tower_id:
			return tower
	return {}


func _can_reroll(slot: int, tower_id: int, kind: String) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or _roll_rules == null or kind not in ["rarity", "attributes"]:
		return false
	var tower: Dictionary = _find_tower(slot, tower_id)
	if tower.is_empty():
		return false
	var cost: int = tower["rarity_reroll_cost" if kind == "rarity" else "attribute_reroll_cost"]
	return cost >= 0 and (_sandbox_mode or (reroll_currency[slot] if kind == "rarity" else coins[slot]) >= cost)


func reroll_tower(slot: int, tower_id: int, kind: String) -> bool:
	if not _can_reroll(slot, tower_id, kind):
		return false
	var tower: Dictionary = _find_tower(slot, tower_id)
	_apply_reroll(slot, tower, kind, _reroll_result(tower, kind))
	return true


func reroll_tower_mirrored(slot: int, tower_id: int, kind: String) -> bool:
	if not _can_reroll(slot, tower_id, kind):
		return false
	var tower: Dictionary = _find_tower(slot, tower_id)
	var counterpart: Dictionary = {}
	for other: Dictionary in towers[1 - slot]:
		if other["cell"] == tower["cell"] and other["type_id"] == tower["type_id"]:
			counterpart = other
			break
	if counterpart.is_empty() or not _can_reroll(1 - slot, counterpart["id"], kind) or counterpart["rarity"] != tower["rarity"]:
		return false
	var rolled: Dictionary = _reroll_result(tower, kind)
	_apply_reroll(slot, tower, kind, rolled)
	_apply_reroll(1 - slot, counterpart, kind, rolled)
	return true


func _reroll_result(tower: Dictionary, kind: String) -> Dictionary:
	var definition: Dictionary = _tower_types[tower["type_id"]]
	if kind == "rarity":
		return _roll_rules.generate_admitted(_roll_random, definition["roll_attributes"], tower["rarity"], definition["roll_profile"])
	return _roll_rules.regenerate_attributes_admitted(tower["rarity"], _roll_random, definition["roll_attributes"], definition["roll_profile"])


func _apply_reroll(slot: int, tower: Dictionary, kind: String, rolled: Dictionary) -> void:
	if kind == "rarity":
		if not _sandbox_mode:
			reroll_currency[slot] -= int(tower["rarity_reroll_cost"])
		tower["rarity_rerolls"] += 1
		tower["attribute_rerolls"] = 0
	else:
		if not _sandbox_mode:
			coins[slot] -= int(tower["attribute_reroll_cost"])
		tower["attribute_rerolls"] += 1
	tower["rarity"] = rolled["rarity"]
	tower["attributes"] = rolled["attributes"].duplicate(true)
	_refresh_board(slot)


# Derive effective values from purchased baselines, never from prior rolled stats.
# Recompute only when the board changes, not for each target/attack.
func _refresh_board(slot: int) -> void:
	for tower: Dictionary in towers[slot]:
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var branch: Dictionary = definition["evolutions"].get(tower["evolution"], {})
		var config: Dictionary = branch.get("followups", {}).get(tower["followup"], branch)
		var kind: String = config.get("behavior_kind", definition["behavior_kind"])
		var behavior: Dictionary = config.get("behavior_config", definition["behavior_config"]).duplicate(true)
		var modifiers: Dictionary = TowerRollRules.modifiers(tower["attributes"])
		tower["modifiers"] = modifiers
		tower["behavior_kind"] = kind
		var base_range: float = float(config.get("range_cells", definition["range"]))
		var range_bonus: float = float(modifiers.get("range", 0.0))
		tower["range"] = base_range
		# A signed range roll must change usable tiles, not just a fractional label.
		# Zero preserves authored geometry; drawbacks floor at one cell or a smaller base.
		if range_bonus > 0.0:
			tower["range"] = ceilf(base_range * (1.0 + range_bonus))
		elif range_bonus < 0.0:
			tower["range"] = maxf(minf(1.0, base_range), floorf(base_range * (1.0 + range_bonus)))
		tower["behavior_config"] = behavior
		tower["support_damage_bonus"] = 0.0
		tower["support_speed_bonus"] = 0.0
		var damage_bonus: float = 0.0
		var speed_bonus: float = 0.0
		var income_bonus: float = float(modifiers.get("economy_production", 0.0))
		for action: String in ["damage", "speed"]:
			if not tower[action + "_upgraded"]:
				continue
			var effect: Dictionary = definition["upgrade_effects"].get(action, {})
			damage_bonus += float(effect.get("damage_bonus", 0.0))
			speed_bonus += float(effect.get("attack_speed_bonus", 0.0))
			income_bonus += float(effect.get("income_bonus", 0.0))
		if kind == "support":
			var strength: float = 1.0 + float(modifiers.get("support_buff", 0.0))
			var damage: float = float(behavior["damage_bonus"])
			var speed: float = float(behavior["attack_speed_bonus"])
			behavior["damage_bonus"] = (damage + (damage_bonus + speed_bonus if speed == 0.0 else damage_bonus)) * strength if damage > 0.0 else 0.0
			behavior["attack_speed_bonus"] = (speed + (damage_bonus + speed_bonus if damage == 0.0 else speed_bonus)) * strength if speed > 0.0 else 0.0
		elif kind == "economy":
			behavior["clear_income"] = ceili(float(behavior["clear_income"]) * (1.0 + income_bonus))
			behavior["periodic_income"] = ceili(float(behavior["periodic_income"]) * (1.0 + income_bonus))
		elif kind == "bounty":
			behavior["mark_income_bonus"] = float(behavior["mark_income_bonus"]) * (1.0 + income_bonus)
		elif kind == "income_aura":
			behavior["kill_income_bonus"] = float(behavior["kill_income_bonus"]) * (1.0 + income_bonus)
		elif kind == "chain":
			behavior["hit_count"] += int(modifiers.get("chain_jumps", 0.0))
			if tower["special_upgraded"]:
				behavior["successive_hit_bonus"] += float(definition["special_upgrade_config"].get("successive_hit_bonus", 0.0))
		tower["rarity_reroll_cost"] = -1 if _roll_rules == null else (0 if _sandbox_mode else _roll_rules.rarity_reroll_cost(tower["rarity_rerolls"]))
		tower["attribute_reroll_cost"] = -1 if _roll_rules == null else (0 if _sandbox_mode else _roll_rules.attribute_reroll_cost(tower["attribute_rerolls"]))
	for tower: Dictionary in towers[slot]:
		# Keep bonuses as 64-bit floats; Vector2 components narrow them to 32-bit.
		var damage_groups: Dictionary[String, float] = {}
		var speed_groups: Dictionary[String, float] = {}
		for support: Dictionary in towers[slot]:
			if support["behavior_kind"] != "support" or not cell_in_range(support["cell"], tower["cell"], support["range"]):
				continue
			var config: Dictionary = support["behavior_config"]
			var group: String = config["stack_group"]
			damage_groups[group] = maxf(damage_groups.get(group, 0.0), float(config["damage_bonus"]))
			speed_groups[group] = maxf(speed_groups.get(group, 0.0), float(config["attack_speed_bonus"]))
		for bonus: float in damage_groups.values():
			tower["support_damage_bonus"] += bonus
		for bonus: float in speed_groups.values():
			tower["support_speed_bonus"] += bonus
		var modifiers: Dictionary = tower["modifiers"]
		var damage_multiplier: float = (1.0 + float(modifiers.get("damage", 0.0))) * (1.0 + float(tower["support_damage_bonus"]))
		var speed_multiplier: float = (1.0 + float(modifiers.get("attack_speed", 0.0))) * (1.0 + float(tower["support_speed_bonus"]))
		var old_interval: float = tower["interval"]
		tower["damage_multiplier"] = damage_multiplier
		tower["speed_multiplier"] = speed_multiplier
		# Preserve ceil for fractional damage without adding HP for arithmetic noise.
		tower["damage"] = ceili(float(tower["base_damage"]) * damage_multiplier - 0.000000001)
		tower["interval"] = float(tower["base_interval"]) / speed_multiplier
		if old_interval > 0.0:
			tower["cooldown"] *= float(tower["interval"]) / old_interval
		if tower["behavior_kind"] == "bounty" and int(tower["bounty_target_id"]) >= 0:
			var index: int = _enemy_index(slot, tower["bounty_target_id"])
			if index >= 0:
				enemies[slot][index]["bounty_damage_bonus"] = tower["behavior_config"]["mark_damage_bonus"]
				enemies[slot][index]["bounty_income_bonus"] = tower["behavior_config"]["mark_income_bonus"]


func _clear_tower_mark(slot: int, tower: Dictionary) -> void:
	var index: int = _enemy_index(slot, tower["bounty_target_id"])
	if index >= 0 and int(enemies[slot][index]["bounty_tower_id"]) == int(tower["id"]):
		enemies[slot][index]["bounty_tower_id"] = -1
		enemies[slot][index]["bounty_damage_bonus"] = 0.0
		enemies[slot][index]["bounty_income_bonus"] = 0.0
	tower["bounty_target_id"] = -1


func set_targeting(slot: int, tower_id: int, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] == tower_id:
			if tower["mode"] == mode:
				return false
			tower["mode"] = mode
			_update_tracking_target(slot, tower)
			return true
	return false


func set_secondary_targeting(slot: int, tower_id: int, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] != tower_id:
			continue
		if not tower["special_upgraded"] or _tower_types[tower["type_id"]]["special_upgrade"] != "second_archer" or _archer_count(tower) < 2 or tower["secondary_mode"] == mode:
			return false
		tower["secondary_mode"] = mode
		return true
	return false


func set_archer_targeting(slot: int, tower_id: int, archer_index: int, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode) or archer_index < 2:
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] != tower_id:
			continue
		var extra: Array = tower["extra_archers"]
		if archer_index - 2 >= extra.size() or extra[archer_index - 2]["mode"] == mode:
			return false
		extra[archer_index - 2]["mode"] = mode
		return true
	return false


func upgrade_tower(slot: int, tower_id: int, upgrade: String) -> bool:
	return _upgrade_tower(slot, tower_id, upgrade, false)


func upgrade_tower_mirrored(slot: int, tower_id: int, upgrade: String) -> bool:
	return _upgrade_tower(slot, tower_id, upgrade, true)


func _upgrade_tower(slot: int, tower_id: int, upgrade: String, mirrored: bool) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot):
		return false
	var tower: Dictionary = _find_tower(slot, tower_id)
	if tower.is_empty():
		return false
	var definition: Dictionary = _tower_types[tower["type_id"]]
	var branches: Dictionary = definition["evolutions"]
	var current: Dictionary = branches.get(tower["evolution"], {})
	var followups: Dictionary = current.get("followups", {})
	var evolution: bool = branches.has(upgrade)
	var followup: bool = followups.has(upgrade)
	var advancement: bool = definition["advancements"].has(upgrade)
	var freeze: bool = upgrade == "freeze_runes" and current.get("followup", {}).get("id", "") == upgrade
	var config: Dictionary = {}
	var flag: String = ""
	if upgrade in ["damage", "speed"]:
		flag = upgrade + "_upgraded"
		if tower[flag]:
			return false
	elif upgrade == "special":
		flag = "special_upgraded"
		if definition["special_upgrade"].is_empty() or tower[flag] or not tower["damage_upgraded"] or not tower["speed_upgraded"]:
			return false
	elif evolution:
		if not String(tower["evolution"]).is_empty() or not tower["damage_upgraded"] or not tower["speed_upgraded"]:
			return false
		if not String(definition["special_upgrade"]).is_empty() and not tower["special_upgraded"]:
			return false
		config = branches[upgrade]
	elif followup:
		if not String(tower["followup"]).is_empty():
			return false
		config = followups[upgrade]
	elif advancement:
		config = definition["advancements"][upgrade]
		if not tower["special_upgraded"] or String(tower["advancement"]) != String(config.get("requires", "")):
			return false
	elif freeze:
		if tower["freeze_upgraded"]:
			return false
		flag = "freeze_upgraded"
		config = current["followup"]
	else:
		return false
	var cost: int = int(config["cost"]) if not config.is_empty() else (int(definition["special_upgrade_cost"]) if upgrade == "special" else tower_upgrade_cost(tower, definition))
	if not _sandbox_mode and coins[slot] < cost:
		return false
	if mirrored:
		var counterpart: Dictionary = {}
		for other: Dictionary in towers[1 - slot]:
			if other["cell"] == tower["cell"] and other["type_id"] == tower["type_id"]:
				counterpart = other
				break
		# Local validation is complete; after the counterpart accepts, neither
		# board has a remaining rejection path or an intervening callback.
		if counterpart.is_empty() or not upgrade_tower(1 - slot, counterpart["id"], upgrade):
			return false
	if not _sandbox_mode:
		coins[slot] -= cost
		tower["invested"] += cost
		tower["sell_value"] = _sell_value(tower["invested"])
	if not flag.is_empty():
		tower[flag] = true
	if evolution:
		tower["evolution"] = upgrade
		tower["special_upgraded"] = true
		tower["production_elapsed"] = 0.0
		if config.has("damage"):
			# Authored Rune evolution stats are its upgraded branch baseline.
			tower["base_damage"] = config["damage"]
			tower["base_interval"] = config["interval"]
	elif followup:
		if config["behavior_kind"] != "bounty":
			_clear_tower_mark(slot, tower)
		tower["followup"] = upgrade
		tower["production_elapsed"] = 0.0
	elif advancement:
		tower["advancement"] = upgrade
		tower["advancement_path"].append(upgrade)
		var extra: Array = tower["extra_archers"]
		var count: int = maxi(0, int(config.get("archer_count", 2)) - 2)
		while extra.size() > count:
			extra.pop_back()
		while extra.size() < count:
			extra.append({"mode": tower["mode"], "shot": 0, "aim": Vector2(tower["cell"]), "target_id": -1})
		tower["secondary_target_id"] = -1
		tower["firing"] = false
		tower["continuous_fire_time"] = 0.0
		tower["refuel_remaining"] = 0.0
		tower["refuel_duration"] = float(config.get("refuel_duration", 0.0))
	elif upgrade == "damage" and definition["upgrade_effects"].is_empty():
		tower["base_damage"] += definition["damage_upgrade_bonus"]
	elif upgrade == "speed" and definition["upgrade_effects"].is_empty():
		tower["base_interval"] *= definition["speed_upgrade_multiplier"]
	elif upgrade == "special" and definition["special_upgrade"] == "second_archer":
		tower["base_interval"] /= TowerDefinition.SECOND_ARCHER_ATTACK_RATE_MULTIPLIER
	if advancement and config.has("attack_rate_multiplier"):
		tower["base_interval"] /= float(config["attack_rate_multiplier"])
	_refresh_board(slot)
	if evolution and config.has("interval"):
		tower["cooldown"] = tower["interval"]
	_sound_events.record(CombatSoundEvents.Cue.UPGRADE, slot, Vector2(tower["cell"]), _death_time)
	return true


func sell_tower(slot: int, tower_id: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot):
		return false
	for index: int in range(towers[slot].size()):
		var tower: Dictionary = towers[slot][index]
		if tower["id"] != tower_id:
			continue
		if not _sandbox_mode:
			coins[slot] += _sell_value(tower["invested"])
		_continuous_damage.erase(tower_id)
		_continuous_bonus.erase(tower_id)
		_clear_tower_mark(slot, tower)
		towers[slot].remove_at(index)
		_refresh_board(slot)
		_sound_events.record(CombatSoundEvents.Cue.SALE, slot, Vector2(tower["cell"]), _death_time)
		return true
	return false


# Level is derived from accepted upgrades, never a second mutable copy of tower state.
static func tower_level(tower: Dictionary) -> int:
	return 1 + int(bool(tower["damage_upgraded"])) + int(bool(tower["speed_upgraded"])) + int(bool(tower.get("special_upgraded", false))) + int(bool(tower.get("freeze_upgraded", false))) + tower.get("advancement_path", []).size() + int(not String(tower.get("followup", "")).is_empty()) + int(not String(tower.get("evolution", "")).is_empty() and _tower_has_separate_special(tower))


static func _tower_has_separate_special(tower: Dictionary) -> bool:
	return tower.get("behavior_kind", "") == "chain"


static func tower_upgrade_cost(tower: Dictionary, definition: Dictionary) -> int:
	# Each level adds half the original price, not half the previous price.
	return ceili(float(definition["upgrade_base_cost"]) * (1.0 + 0.5 * (tower_level(tower) - 1)))


static func _sell_value(invested: int) -> int:
	return floori(float(invested) * 0.6)


static func cell_in_range(origin: Vector2i, cell: Vector2i, range_cells: float) -> bool:
	return maxi(absi(cell.x - origin.x), absi(cell.y - origin.y)) <= range_cells


func has_tower(slot: int, cell: Vector2i) -> bool:
	if not _valid_slot(slot):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["cell"] == cell:
			return true
	return false


func grow_for_main_round() -> void:
	assert(phase == Phase.PLANNING)
	_reset_death_events()
	for board: Array in towers:
		for tower: Dictionary in board:
			tower["cell"] += Vector2i.DOWN
			tower["aim"] += Vector2.DOWN
			tower["tracking_aim"] += Vector2.DOWN
			tower["secondary_aim"] += Vector2.DOWN
			tower["chain_points"].clear()
			for archer: Dictionary in tower["extra_archers"]:
				archer["aim"] += Vector2.DOWN
			tower["bounce_aim"] += Vector2.DOWN
			tower["pierce_aim"] += Vector2.DOWN


func _can_send_enemy(slot: int, type_id: StringName) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _enemy_types.has(String(type_id)) or not _valid_send_timing():
		return false
	var definition: Dictionary = _enemy_types[String(type_id)]
	var delivery_wave: int = wave + 1 if phase == Phase.PLANNING else wave
	return definition["send_enabled"] and delivery_wave >= int(definition["send_first_wave"]) and (_sandbox_mode or coins[slot] >= int(definition["send_cost"]))


func send_enemy(slot: int, type_id: StringName) -> bool:
	if not _can_send_enemy(slot, type_id):
		return false
	_send_enemy_accepted(slot, type_id)
	return true


func send_enemy_mirrored(slot: int, type_id: StringName) -> bool:
	if not _can_send_enemy(slot, type_id) or not _can_send_enemy(1 - slot, type_id):
		return false
	_send_enemy_accepted(slot, type_id)
	_send_enemy_accepted(1 - slot, type_id)
	return true


func _send_enemy_accepted(slot: int, type_id: StringName) -> void:
	var definition: Dictionary = _enemy_types[String(type_id)]
	var cost: int = definition["send_cost"]
	var target: int = 1 - slot
	var count: int = _roll_group(definition, _group_random)
	_special_stream = _special_stream or float(definition["heal_interval"]) > 0.0 or float(definition["summon_interval"]) > 0.0
	if _pending_sends(target) == 0 and phase == Phase.WAVE:
		_next_send_times[target] = maxf(_next_send_times[target], _elapsed)
	for member: int in range(count):
		_send_queues[target].append(String(type_id))
		_send_group_ends[target].append(member == count - 1)
	if not _sandbox_mode:
		coins[slot] -= cost
	income[slot] += int(definition["send_income"])
	_add_total(slot, "sent", String(type_id), count)
	_sound_events.record(CombatSoundEvents.Cue.SEND, slot, Vector2.ZERO, _death_time)
	if phase == Phase.WAVE and _next_send_times[target] <= _elapsed:
		_spawn_send(target)


func _valid_send_timing() -> bool:
	return is_finite(_send_spawn_interval) and _send_spawn_interval > 0.0 and _valid_interval_scaling()


func _pending_sends(slot: int) -> int:
	return _send_queues[slot].size() - _send_heads[slot]



# Debug jumps abandon a round, never clear it: no bounty, income or wave reward.
func debug_set_round(round_number: int) -> bool:
	if (phase == Phase.FINISHED and not _sandbox_mode) or round_number < 1 or (round_number > 1000 and not _sandbox_mode):
		return false
	phase = Phase.PLANNING
	wave = round_number - 1
	winner = -1
	coin_flip = false
	enemies = [[], []]
	_reset_death_events()
	wave_roster.clear()
	wave_groups.clear()
	_special_stream = false
	spawn_times.clear()
	_send_queues = [[], []]
	_send_group_ends = [[], []]
	_send_heads = [0, 0]
	_next_send_times = [0.0, 0.0]
	_active_send_spawn_interval = 0.0
	_routes = [[], []]
	_routing_next = [{}, {}]
	_fork_cursors = [{}, {}]
	_spawned = [0, 0]
	_elapsed = 0.0
	_step_start_time = 0.0
	_continuous_damage.clear()
	_continuous_bonus.clear()
	_burns.clear()
	_enemy_spawn_times.clear()
	_slow_motion.clear()
	for board: Array in towers:
		for tower: Dictionary in board:
			tower["bounty_target_id"] = -1
			tower["production_elapsed"] = 0.0
			tower["chain_points"].clear()
			tower["cooldown"] = tower["interval"] if tower["evolution"] == "onyx_ring" else 0.0
			_reset_firing(tower)
			tower["target_id"] = -1
			tower["secondary_target_id"] = -1
			tower["shot"] = 0
			tower["secondary_shot"] = 0
			tower["aim"] = Vector2(tower["cell"])
			tower["tracking_target_id"] = -1
			tower["tracking_aim"] = Vector2(tower["cell"])
			tower["secondary_aim"] = Vector2(tower["cell"])
			for archer: Dictionary in tower["extra_archers"]:
				archer["shot"] = 0
				archer["target_id"] = -1
				archer["aim"] = Vector2(tower["cell"])
			tower["bounce_aim"] = Vector2(tower["cell"])
			tower["bounce_active"] = false
			tower["pierce_aim"] = Vector2(tower["cell"])
			tower["pierce_active"] = false
	return true

func start_wave(routing: Array[Dictionary]) -> bool:
	if phase != Phase.PLANNING or not _roster_configuration_valid or not _valid_routes(routing) or not _valid_spawn_timing() or not _valid_send_timing():
		return false
	var groups: Array[Dictionary] = _generate_wave_groups(wave + 1)
	if groups.is_empty():
		return false
	_admit_wave(routing, wave + 1, groups)
	return true


func sandbox_start(routing: Array[Dictionary], round_number: int, roster: Array[String]) -> bool:
	if not _sandbox_mode or not _roster_configuration_valid or round_number < 1 or not _valid_routes(routing) or not _valid_spawn_timing() or not _valid_send_timing():
		return false
	var groups: Array[Dictionary] = []
	for type_id: String in roster:
		if not _enemy_types.has(type_id):
			return false
		groups.append({"type_id": type_id, "count": 1})
	debug_set_round(round_number)
	_admit_wave(routing, round_number, groups)
	return true


func sandbox_start_wave(routing: Array[Dictionary], round_number: int) -> bool:
	if not _sandbox_mode or round_number < 1 or not _roster_configuration_valid or not _valid_routes(routing) or not _valid_spawn_timing() or not _valid_send_timing():
		return false
	var groups: Array[Dictionary] = _generate_wave_groups(round_number)
	if groups.is_empty():
		return false
	debug_set_round(round_number)
	_admit_wave(routing, round_number, groups)
	return true


func sandbox_spawn(slot: int, type_id: StringName, count: int) -> bool:
	if not _sandbox_mode or phase != Phase.WAVE or not _valid_slot(slot) or not _enemy_types.has(String(type_id)) or count < 1 or _routes[slot].is_empty():
		return false
	for index: int in range(count):
		_spawn_enemy(slot, String(type_id), 0.0, _elapsed)
	return true


func _valid_routes(routing: Array[Dictionary]) -> bool:
	if routing.size() != 2:
		return false
	for captured: Dictionary in routing:
		if not _valid_routing(captured):
			return false
	return true


func _admit_wave(routing: Array[Dictionary], wave_number: int, groups: Array[Dictionary]) -> void:
	wave_groups = groups
	wave_roster.clear()
	spawn_times.clear()
	_special_stream = false
	for slot: int in range(2):
		for index: int in range(_send_heads[slot], _send_queues[slot].size()):
			var pending: Dictionary = _enemy_types[_send_queues[slot][index]]
			_special_stream = _special_stream or float(pending["heal_interval"]) > 0.0 or float(pending["summon_interval"]) > 0.0
	var interval_multiplier: float = _spawn_interval_multiplier(wave_number)
	var group_times: Array[float] = _generate_spawn_times(groups.size(), _rules.spawn_interval * interval_multiplier)
	var offset: float = 0.0
	for index: int in range(groups.size()):
		var group: Dictionary = groups[index]
		var definition: Dictionary = _enemy_types[group["type_id"]]
		_special_stream = _special_stream or float(definition["heal_interval"]) > 0.0 or float(definition["summon_interval"]) > 0.0
		var spacing: float = _enemy_types[group["type_id"]]["group_interval"]
		for member: int in range(int(group["count"])):
			wave_roster.append(group["type_id"])
			spawn_times.append(group_times[index] + offset + member * spacing)
		offset += (int(group["count"]) - 1) * spacing
	_active_send_spawn_interval = _send_spawn_interval * interval_multiplier
	_routes = [routing[0]["route"].duplicate(), routing[1]["route"].duplicate()]
	_routing_next = [routing[0]["next"].duplicate(true), routing[1]["next"].duplicate(true)]
	_fork_cursors = [{}, {}]
	_spawned = [0, 0]
	if _sandbox_mode:
		_spawned[1] = wave_roster.size()
	_elapsed = 0.0
	_next_send_times = [0.0, 0.0]
	wave = wave_number
	phase = Phase.WAVE
	for board: Array in towers:
		for tower: Dictionary in board:
			_reset_firing(tower)
	for slot: int in range(2):
		if _pending_sends(slot) > 0:
			_spawn_send(slot)


func _valid_spawn_timing() -> bool:
	return is_finite(_rules.spawn_interval) and _rules.spawn_interval >= 0.0 and is_finite(_rules.spawn_jitter_ratio) and _rules.spawn_jitter_ratio >= 0.0 and _rules.spawn_jitter_ratio < 0.5 and _valid_interval_scaling()


func _valid_interval_scaling() -> bool:
	return is_finite(_spawn_interval_reduction_per_wave) and _spawn_interval_reduction_per_wave >= 0.0 and is_finite(_max_spawn_interval_reduction) and _max_spawn_interval_reduction >= 0.0 and _max_spawn_interval_reduction < 1.0


func _spawn_interval_multiplier(wave_number: int) -> float:
	return 1.0 - minf(maxi(0, wave_number - 1) * _spawn_interval_reduction_per_wave, _max_spawn_interval_reduction)



func _generate_spawn_times(count: int, interval: float) -> Array[float]:
	var times: Array[float] = []
	times.resize(count)
	for index: int in range(count):
		var time: float = index * interval
		if index > 0 and index < count - 1 and interval > 0.0 and _rules.spawn_jitter_ratio > 0.0:
			time += _timing_random.randf_range(-_rules.spawn_jitter_ratio, _rules.spawn_jitter_ratio) * interval
		times[index] = time
	return times


# Validate the whole graph in linear space, without enumerating complete paths.
# Reverse distances reject cycles, dead ends, and longer alternatives before any
# wave state (including queued sends and random roster selection) is changed.
func _valid_routing(captured: Dictionary) -> bool:
	if not captured.get("route") is Array or not captured.get("next") is Dictionary:
		return false
	var route: Array = captured["route"]
	var next: Dictionary = captured["next"]
	if route.size() < 2:
		return false
	for cell: Variant in route:
		if not cell is Vector2i:
			return false
	var base: Vector2i = route.back()
	if not next.has(base) or not next[base] is Array or not next[base].is_empty():
		return false
	var previous: Dictionary = {}
	for cell: Variant in next:
		if not cell is Vector2i or not next[cell] is Array:
			return false
		var choices: Array = next[cell]
		if cell != base and choices.is_empty():
			return false
		var seen: Dictionary = {}
		for successor: Variant in choices:
			if not successor is Vector2i or not next.has(successor) or seen.has(successor):
				return false
			if absi(cell.x - successor.x) + absi(cell.y - successor.y) != 1:
				return false
			seen[successor] = true
			if not previous.has(successor):
				previous[successor] = []
			previous[successor].append(cell)
	var distance: Dictionary = {base: 0}
	var pending: Array[Vector2i] = [base]
	var head: int = 0
	while head < pending.size():
		var cell: Vector2i = pending[head]
		head += 1
		for predecessor: Vector2i in previous.get(cell, []):
			if not distance.has(predecessor):
				distance[predecessor] = int(distance[cell]) + 1
				pending.append(predecessor)
	if distance.size() != next.size() or int(distance.get(route[0], -1)) != route.size() - 1:
		return false
	for cell: Vector2i in next:
		for successor: Vector2i in next[cell]:
			if int(distance[successor]) != int(distance[cell]) - 1:
				return false
	for index: int in range(route.size() - 1):
		if not next.has(route[index]) or not next[route[index]].has(route[index + 1]):
			return false
	return true


func _assign_route(slot: int) -> Array[Vector2i]:
	var route: Array[Vector2i] = [_routes[slot][0]]
	# Validation guarantees every successor reduces base distance by exactly one.
	for step: int in range(_routes[slot].size() - 1):
		var cell: Vector2i = route.back()
		var choices: Array = _routing_next[slot][cell]
		var choice: int = 0
		if choices.size() > 1:
			choice = int(_fork_cursors[slot].get(cell, 0))
			_fork_cursors[slot][cell] = (choice + 1) % choices.size()
		route.append(choices[choice])
	return route


# Only the host calls this, using fixed physics deltas. All towers hit immediately;
# the shot counter and aim position are cosmetic events for snapshot consumers.
func advance(delta: float) -> bool:
	if phase != Phase.WAVE or not is_finite(delta) or delta <= 0.0:
		return false
	var remaining: float = delta
	var periodic: bool = _has_periodic_production()
	if _special_stream or periodic:
		for slot: int in range(2):
			_spawn_enemies(slot)
	while remaining > 0.000000001:
		var step: float = _next_event_step(remaining, periodic) if _special_stream or periodic else remaining
		_step_start_time = _elapsed
		_elapsed += step
		_death_time += step
		for slot: int in range(2):
			_move_enemies(slot, step)
			_spawn_enemies(slot)
			_update_bounties(slot)
			_attack_flames(slot, step)
			_apply_burns(slot)
			_attack(slot, step)
			# A dead caster never resolves its due ritual.
			_enemy_abilities(slot)
			_apply_leaks(slot)
			for tower: Dictionary in towers[slot]:
				_update_tracking_target(slot, tower)
		remaining -= step
		if periodic and base_health[0] > 0 and base_health[1] > 0:
			_produce_periodic(step)
		if periodic and (base_health[0] == 0 or base_health[1] == 0 or _wave_cleared()):
			break
	for slot: int in range(2):
		var events: Array = _death_events[slot]
		var first: int = _death_heads[slot]
		while first < events.size() and _death_time - float(events[first]["time"]) >= DEATH_EVENT_LIFETIME - 0.000000001:
			first += 1
		_death_heads[slot] = first
		if first == events.size():
			events.clear()
			_death_heads[slot] = 0
		elif first >= 64 and first * 2 >= events.size():
			_death_events[slot] = events.slice(first)
			_death_heads[slot] = 0
	# Resolve only after BOTH boards have applied this tick's damage.
	if base_health[0] == 0 or base_health[1] == 0:
		phase = Phase.FINISHED
		coin_flip = base_health[0] == 0 and base_health[1] == 0
		winner = _random.randi_range(0, 1) if coin_flip else (1 if base_health[0] == 0 else 0)
		for slot: int in range(2):
			for tower: Dictionary in towers[slot]:
				_clear_tower_mark(slot, tower)
				_reset_firing(tower)
				tower["production_elapsed"] = 0.0
	elif _wave_cleared():
		var reward: int = _rules.wave_reward + wave * _rules.wave_reward_growth
		for slot: int in range(2):
			coins[slot] += reward + income[slot]
			reroll_currency[slot] += _rules.clear_reroll_currency
			for tower: Dictionary in towers[slot]:
				_reset_firing(tower)
				if tower["behavior_kind"] == "economy":
					var produced: int = int(tower["behavior_config"]["clear_income"])
					coins[slot] += produced
					tower["coins_generated"] += produced
		phase = Phase.PLANNING
	return true


func _next_event_step(maximum: float, periodic: bool = false) -> float:
	var duration: float = maximum
	for slot: int in range(2):
		if _spawned[slot] < spawn_times.size():
			duration = minf(duration, spawn_times[_spawned[slot]] - _elapsed)
		if _pending_sends(slot) > 0:
			duration = minf(duration, _next_send_times[slot] - _elapsed)
		if periodic:
			for tower: Dictionary in towers[slot]:
				if tower["behavior_kind"] == "economy" and int(tower["behavior_config"]["periodic_income"]) > 0:
					duration = minf(duration, float(tower["behavior_config"]["periodic_interval"]) - float(tower["production_elapsed"]))
		for enemy: Dictionary in enemies[slot]:
			var definition: Dictionary = _enemy_types[enemy["type_id"]]
			if periodic and float(enemy["speed"]) > 0.0:
				duration = minf(duration, maxf(0.0, float(enemy["route"].size() - 1) - float(enemy["progress"])) / float(enemy["speed"]))
			if float(enemy["cast_remaining"]) > 0.0:
				duration = minf(duration, float(enemy["cast_remaining"]))
			elif float(definition["summon_interval"]) > 0.0:
				duration = minf(duration, float(enemy["next_summon"]) - float(enemy["age"]))
			if float(definition["heal_interval"]) > 0.0:
				duration = minf(duration, float(enemy["next_heal"]) - float(enemy["age"]))
	return maxf(0.000000001, duration)


func _wave_cleared() -> bool:
	return _spawned[0] == wave_roster.size() and _spawned[1] == wave_roster.size() and _pending_sends(0) == 0 and _pending_sends(1) == 0 and enemies[0].is_empty() and enemies[1].is_empty()


func _has_periodic_production() -> bool:
	for board: Array in towers:
		for tower: Dictionary in board:
			if tower["behavior_kind"] == "economy" and int(tower["behavior_config"]["periodic_income"]) > 0:
				return true
	return false


func _produce_periodic(delta: float) -> void:
	for slot: int in range(2):
		for tower: Dictionary in towers[slot]:
			if tower["behavior_kind"] != "economy":
				continue
			var config: Dictionary = tower["behavior_config"]
			if int(config["periodic_income"]) <= 0:
				continue
			tower["production_elapsed"] += delta
			var count: int = floori((float(tower["production_elapsed"]) + 0.000000001) / float(config["periodic_interval"]))
			if count > 0:
				tower["production_elapsed"] = maxf(0.0, float(tower["production_elapsed"]) - count * float(config["periodic_interval"]))
				var produced: int = count * int(config["periodic_income"])
				coins[slot] += produced
				tower["coins_generated"] += produced


func _update_bounties(slot: int) -> void:
	for tower: Dictionary in towers[slot]:
		if tower["behavior_kind"] != "bounty" or int(tower["bounty_target_id"]) >= 0:
			continue
		var selected: Dictionary = {}
		for enemy: Dictionary in enemies[slot]:
			if int(enemy["hp"]) <= 0 or int(enemy["bounty_tower_id"]) >= 0 or not cell_in_range(tower["cell"], Vector2i(enemy["pos"].round()), tower["range"]):
				continue
			if selected.is_empty() or int(enemy["max_hp"]) > int(selected["max_hp"]) or (int(enemy["max_hp"]) == int(selected["max_hp"]) and int(enemy["id"]) < int(selected["id"])):
				selected = enemy
		if not selected.is_empty():
			tower["bounty_target_id"] = selected["id"]
			selected["bounty_tower_id"] = tower["id"]
			selected["bounty_damage_bonus"] = tower["behavior_config"]["mark_damage_bonus"]
			selected["bounty_income_bonus"] = tower["behavior_config"]["mark_income_bonus"]


func _income_aura_source(slot: int, tower: Dictionary) -> Dictionary:
	# Strict comparison retains the oldest accepted source on equal strengths.
	var selected: Dictionary = NO_BONUS
	var strongest: float = 0.0
	for source: Dictionary in towers[slot]:
		if source["behavior_kind"] == "income_aura" and cell_in_range(source["cell"], tower["cell"], source["range"]):
			var bonus: float = source["behavior_config"]["kill_income_bonus"]
			if bonus > strongest:
				selected = source
				strongest = bonus
	return selected


func _enemy_abilities(slot: int) -> void:
	# New children wait for a later pass; their own ability timers start at birth.
	var count: int = enemies[slot].size()
	for index: int in range(count):
		var enemy: Dictionary = enemies[slot][index]
		if int(enemy["hp"]) <= 0 or float(enemy["progress"]) >= enemy["route"].size() - 1:
			continue
		var definition: Dictionary = _enemy_types[enemy["type_id"]]
		if enemy["animation"] == "heal" and float(enemy["animation_elapsed"]) >= 0.55:
			enemy["animation"] = "walk"
			enemy["animation_elapsed"] = 0.0
		if float(definition["heal_interval"]) > 0.0 and float(enemy["age"]) + 0.000000001 >= float(enemy["next_heal"]):
			enemy["next_heal"] += float(definition["heal_interval"])
			enemy["heal_count"] += 1
			enemy["animation"] = "heal"
			enemy["animation_elapsed"] = 0.0
			var radius_squared: float = float(definition["heal_radius"]) * float(definition["heal_radius"])
			for ally: Dictionary in enemies[slot]:
				if ally["id"] != enemy["id"] and int(ally["hp"]) > 0 and Vector2(enemy["pos"]).distance_squared_to(ally["pos"]) <= radius_squared:
					ally["hp"] = mini(int(ally["max_hp"]), int(ally["hp"]) + maxi(1, ceili(float(ally["max_hp"]) * float(definition["heal_fraction"]))))
		if float(definition["summon_interval"]) <= 0.0:
			continue
		if enemy["animation"] == "cast":
			if float(enemy["cast_remaining"]) <= 0.000000001:
				_finish_summon(slot, enemy, definition)
				enemy["animation"] = "walk"
				enemy["animation_elapsed"] = 0.0
				enemy["speed"] = float(enemy["base_speed"]) * (TowerDefinition.FREEZE_SPEED_MULTIPLIER if enemy["slowed"] else 1.0)
		elif float(enemy["age"]) + 0.000000001 >= float(enemy["next_summon"]):
			enemy["next_summon"] += float(definition["summon_interval"])
			enemy["cast_remaining"] = definition["summon_cast_duration"]
			enemy["animation"] = "cast"
			enemy["animation_elapsed"] = 0.0
			enemy["speed"] = 0.0


func _finish_summon(slot: int, caster: Dictionary, definition: Dictionary) -> void:
	var living: int = 0
	for enemy: Dictionary in enemies[slot]:
		if enemy["summoner_id"] == caster["id"] and int(enemy["hp"]) > 0:
			living += 1
	var capacity: int = maxi(0, int(definition["summon_limit"]) - living)
	if capacity == 0:
		return
	var count: int = mini(capacity, _group_random.randi_range(int(definition["summon_min"]), int(definition["summon_max"])))
	caster["summon_count"] += 1
	for member: int in range(count):
		_spawn_enemy(slot, definition["summon_type"], caster["progress"], _elapsed, caster["route"], caster["id"])


func snapshot() -> Dictionary:
	return {
		"phase": phase, "wave": wave, "health": base_health.duplicate(),
		"statistics_id": statistics_id, "enemy_totals": enemy_totals.duplicate(true),
		"wave_groups": wave_groups.duplicate(true),
		"winner": winner, "coin_flip": coin_flip,
		"coins": coins.duplicate(),
		"reroll_currency": reroll_currency.duplicate(),
		"income": income.duplicate(), "queued_sends": queued_sends,
		"send_queues": [_send_queues[0].slice(_send_heads[0]), _send_queues[1].slice(_send_heads[1])],
		"enemy_types": _enemy_types_snapshot(),
		"towers": towers.duplicate(true), "enemies": enemies.duplicate(true),
		"deaths": [_death_snapshot(0), _death_snapshot(1)], "death_time": _death_time,
		"death_generation": _death_generation,
		"sounds": _sound_events.snapshot(_death_time),
		"spawned": _spawned.duplicate(), "total": wave_roster.size(),
		"wave_roster": wave_roster.duplicate(), "wave_weight": _wave_weight(maxi(1, wave)),
		"spawn_times": spawn_times.duplicate(),
		"tower_types": _tower_types.duplicate(true),
		"rules": {
			"enemy_speed": _wave_speed(wave), "enemy_health": _wave_health(wave),
			"sandbox_mode": _sandbox_mode,
			"roll_rules_enabled": _roll_rules != null,
			"clear_reroll_currency": _rules.clear_reroll_currency,
			"starting_coins": _rules.starting_coins, "kill_bounty": _rules.kill_bounty,
			"wave_reward": _rules.wave_reward + maxi(1, wave) * _rules.wave_reward_growth,
			"base_health": _rules.base_health,
			"send_spawn_interval": _send_spawn_interval * _spawn_interval_multiplier(wave + 1) if phase == Phase.PLANNING else _active_send_spawn_interval,
			"main_round_interval": _rules.main_round_interval,
			"ready_window_seconds": _rules.ready_window_seconds,
			"tiles_per_expansion": _rules.tiles_per_expansion,
		},
	}


func _enemy_types_snapshot() -> Dictionary:
	var result: Dictionary = _enemy_types.duplicate(true)
	var preview_wave: int = wave + 1 if phase == Phase.PLANNING else wave
	for type_id: String in result:
		result[type_id]["health"] = _enemy_health(type_id, preview_wave)
		result[type_id]["speed"] = _enemy_speed(type_id, preview_wave)
		result[type_id]["send_available"] = bool(result[type_id]["send_enabled"]) and preview_wave >= int(result[type_id]["send_first_wave"])
	return result


static func enemy_preview(definition: EnemyDefinition, rules: CombatRules, wave_number: int = 1) -> Dictionary:
	return {
		"max_hp": maxi(1, ceili(float(rules.enemy_health + maxi(0, wave_number - 1) * rules.health_growth) * definition.health_multiplier)),
		"speed": rules.enemy_speed_at_wave(wave_number) * definition.speed_multiplier,
		"base_damage": definition.base_damage,
		"fire_immune": definition.fire_immune, "ice_immune": definition.ice_immune,
		"burning": false, "burn_remaining": 0.0,
	}


func _enemy_health(type_id: String, wave_number: int) -> int:
	var baseline: int = _wave_health(wave_number)
	return maxi(1, ceili(float(baseline) * float(_enemy_types[type_id]["health_multiplier"])))


func _enemy_speed(type_id: String, wave_number: int) -> float:
	var baseline: float = _wave_speed(wave_number)
	return baseline * float(_enemy_types[type_id]["speed_multiplier"])


func _wave_health(wave_number: int) -> int:
	return _rules.enemy_health + maxi(0, wave_number - 1) * _rules.health_growth


func _wave_speed(wave_number: int) -> float:
	# Admitted rules are immutable; compute current/preview baselines once per round.
	if _speed_cache_wave != wave:
		_speed_cache_wave = wave
		_current_wave_speed = _rules.enemy_speed_at_wave(wave)
		_next_wave_speed = _rules.enemy_speed_at_wave(wave + 1)
	if wave_number == wave:
		return _current_wave_speed
	if wave_number == wave + 1:
		return _next_wave_speed
	return _rules.enemy_speed_at_wave(wave_number)


func _wave_weight(wave_number: int) -> int:
	return _rules.wave_weight + maxi(0, wave_number - 1) * _rules.wave_weight_growth


func _enemy_count_cap(definition: Dictionary, wave_number: int) -> int:
	var base_cap: int = definition["max_per_wave"]
	if base_cap == 0:
		return 0
	var steps: int = floori(float(maxi(0, wave_number - int(definition["first_wave"]))) / int(definition["count_cap_growth_interval"]))
	return base_cap + steps * int(definition["count_cap_growth"])


func _generate_wave_groups(wave_number: int) -> Array[Dictionary]:
	var budget: int = _wave_weight(wave_number)
	var remaining: int = budget
	var counts: Dictionary = {}
	var roster: Array[Dictionary] = []
	var eligible: Array[String] = []
	var count_caps: Dictionary[String, int] = {}
	for type_id: String in _enemy_types:
		count_caps[type_id] = _enemy_count_cap(_enemy_types[type_id], wave_number)
		var definition: Dictionary = _enemy_types[type_id]
		var elapsed: int = wave_number - int(definition["first_wave"])
		if not definition["boss"] or not definition["regular_spawn_enabled"] or elapsed < 0:
			continue
		var weight: int = definition["spawn_weight"]
		if weight > remaining or weight > floori(float(budget) * float(definition["max_weight_share"])):
			continue
		var chance: float = minf(float(definition["boss_spawn_chance_cap"]), float(definition["boss_spawn_chance"]) + maxi(0, elapsed - 1) * float(definition["boss_spawn_chance_growth"]))
		if elapsed == 0 or _wave_random.randf() < chance:
			roster.append({"type_id": type_id, "count": 1})
			counts[type_id] = 1
			remaining -= weight
	while remaining > 0:
		eligible.clear()
		for type_id: String in _enemy_types:
			var definition: Dictionary = _enemy_types[type_id]
			var weight: int = definition["spawn_weight"]
			var count: int = counts.get(type_id, 0)
			var count_cap: int = count_caps[type_id]
			var share_cap: int = floori(float(budget) * float(definition["max_weight_share"]))
			if definition["regular_spawn_enabled"] and not definition["boss"] and wave_number >= int(definition["first_wave"]) and weight <= remaining and (count_cap == 0 or count < count_cap) and (count + 1) * weight <= share_cap:
				eligible.append(type_id)
		# A validated weight-one remainder enemy guarantees exact fill.
		if eligible.is_empty():
			push_error("Combat wave %d cannot fill its remaining weight %d" % [wave_number, remaining])
			return []
		var selected: String = eligible[_wave_random.randi_range(0, eligible.size() - 1)]
		roster.append({"type_id": selected, "count": _roll_group(_enemy_types[selected], _wave_random)})
		counts[selected] = int(counts.get(selected, 0)) + 1
		remaining -= int(_enemy_types[selected]["spawn_weight"])
	return roster


func _roll_group(definition: Dictionary, random: RandomNumberGenerator) -> int:
	var weights: PackedInt32Array = definition["group_weights"]
	if weights.size() == 1:
		return 1
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll: int = random.randi_range(1, total)
	for index: int in range(weights.size()):
		roll -= weights[index]
		if roll <= 0:
			return index + 1
	return 1


func _add_total(slot: int, kind: String, type_id: String, count: int = 1) -> void:
	var totals: Dictionary = enemy_totals[slot][kind]
	totals[type_id] = int(totals.get(type_id, 0)) + count


func _valid_slot(slot: int) -> bool:
	return slot == 0 or slot == 1


func _valid_mode(mode: int) -> bool:
	return mode >= TargetMode.FURTHEST and mode <= TargetMode.LAST


func _move_enemies(slot: int, delta: float) -> void:
	for enemy: Dictionary in enemies[slot]:
		enemy["age"] += delta
		enemy["animation_elapsed"] += delta
		var casting: bool = float(enemy["cast_remaining"]) > 0.0
		enemy["cast_remaining"] = maxf(0.0, float(enemy["cast_remaining"]) - delta)
		var base_speed: float = enemy["base_speed"]
		var slowed_seconds: float = minf(delta, float(enemy["slow_remaining"]))
		if casting:
			if not _slow_motion.has(enemy["id"]):
				_slow_motion[enemy["id"]] = [0.0, 0.0, 0.0, 0.0]
			var stationary: Array = _slow_motion[enemy["id"]]
			stationary[0] = float(enemy["progress"])
			stationary[1] = delta
			stationary[2] = 0.0
			stationary[3] = 0.0
			enemy["slow_remaining"] = maxf(0.0, float(enemy["slow_remaining"]) - delta)
			enemy["slowed"] = float(enemy["slow_remaining"]) > 0.000000001
			enemy["speed"] = 0.0
		elif slowed_seconds > 0.0:
			var slow_speed: float = base_speed * TowerDefinition.FREEZE_SPEED_MULTIPLIER
			if not _slow_motion.has(enemy["id"]):
				_slow_motion[enemy["id"]] = [0.0, 0.0, 0.0, 0.0]
			var motion: Array = _slow_motion[enemy["id"]]
			motion[0] = float(enemy["progress"])
			motion[1] = slowed_seconds
			motion[2] = slow_speed
			motion[3] = base_speed
			enemy["progress"] += slow_speed * slowed_seconds + base_speed * (delta - slowed_seconds)
			enemy["slow_remaining"] = maxf(0.0, float(enemy["slow_remaining"]) - delta)
			enemy["slowed"] = float(enemy["slow_remaining"]) > 0.000000001
			if not enemy["slowed"]:
				enemy["slow_remaining"] = 0.0
			enemy["speed"] = slow_speed if enemy["slowed"] else base_speed
		else:
			_slow_motion.erase(enemy["id"])
			enemy["progress"] += base_speed * delta
		enemy["pos"] = _position(enemy["route"], enemy["progress"])


func _spawn_enemies(slot: int) -> void:
	var total: int = wave_roster.size()
	# Merge only due events, preserving actual portal order even on a coarse tick.
	# The two clocks and regular spawn counters remain entirely independent.
	while true:
		var regular_time: float = spawn_times[_spawned[slot]] if _spawned[slot] < total else INF
		var send_time: float = _next_send_times[slot] if _pending_sends(slot) > 0 else INF
		if minf(regular_time, send_time) > _elapsed:
			break
		if send_time < regular_time:
			_spawn_send(slot)
		else:
			var type_id: String = wave_roster[_spawned[slot]]
			var progress: float = (_elapsed - regular_time) * _enemy_speed(type_id, wave)
			_spawn_enemy(slot, type_id, progress, regular_time)
			_spawned[slot] += 1


func _spawn_send(slot: int) -> void:
	var type_id: String = _send_queues[slot][_send_heads[slot]]
	var progress: float = (_elapsed - _next_send_times[slot]) * _enemy_speed(type_id, wave)
	_spawn_enemy(slot, type_id, progress, _next_send_times[slot])
	_sound_events.record(CombatSoundEvents.Cue.PORTAL, slot, Vector2(_routes[slot][0]), _death_time)
	_next_send_times[slot] += _active_send_spawn_interval if _send_group_ends[slot][_send_heads[slot]] else float(_enemy_types[type_id]["group_interval"])
	_send_heads[slot] += 1
	if _send_heads[slot] == _send_queues[slot].size():
		_send_queues[slot].clear()
		_send_heads[slot] = 0
		_send_group_ends[slot].clear()
	elif _send_heads[slot] >= 64 and _send_heads[slot] * 2 >= _send_queues[slot].size():
		_send_queues[slot] = _send_queues[slot].slice(_send_heads[slot])
		_send_group_ends[slot] = _send_group_ends[slot].slice(_send_heads[slot])
		_send_heads[slot] = 0


func _spawn_enemy(slot: int, type_id: String, progress: float, spawn_time: float, captured_route: Array[Vector2i] = [], summoner_id: int = -1) -> void:
	var hp: int = _enemy_health(type_id, wave)
	var route: Array[Vector2i] = _assign_route(slot) if captured_route.is_empty() else captured_route.duplicate()
	_special_stream = _special_stream or float(_enemy_types[type_id]["heal_interval"]) > 0.0 or float(_enemy_types[type_id]["summon_interval"]) > 0.0
	var speed: float = _enemy_speed(type_id, wave)
	enemies[slot].append({
		"id": _next_enemy_id, "hp": hp, "max_hp": hp,
		"type_id": type_id, "base_speed": speed, "speed": speed,
		"slowed": false, "slow_remaining": 0.0,
		"fire_immune": _enemy_types[type_id]["fire_immune"], "ice_immune": _enemy_types[type_id]["ice_immune"],
		"burning": false, "burn_remaining": 0.0,
		"bounty_tower_id": -1, "bounty_damage_bonus": 0.0, "bounty_income_bonus": 0.0,
		"damage": _enemy_types[type_id]["base_damage"],
		"route": route, "progress": progress, "pos": _position(route, progress),
		"animation": "walk", "animation_elapsed": maxf(0.0, _elapsed - spawn_time),
		"age": maxf(0.0, _elapsed - spawn_time), "cast_remaining": 0.0,
		"heal_count": 0, "summon_count": 0, "summoner_id": summoner_id,
		"next_heal": _enemy_types[type_id]["heal_interval"],
		"next_summon": _enemy_types[type_id]["summon_interval"],
	})
	_enemy_spawn_times[_next_enemy_id] = spawn_time
	_next_enemy_id += 1


func _position(route: Array, progress: float) -> Vector2:
	var last: int = route.size() - 1
	if progress >= last:
		return Vector2(route[last])
	var index: int = floori(progress)
	return Vector2(route[index]).lerp(Vector2(route[index + 1]), progress - index)


func _archer_count(tower: Dictionary) -> int:
	var config: Dictionary = _tower_types[tower["type_id"]]["advancements"].get(tower["advancement"], {})
	return int(config.get("archer_count", 2 if tower["special_upgraded"] else 1))


func _reset_firing(tower: Dictionary) -> void:
	tower["firing"] = false
	tower["continuous_fire_time"] = 0.0
	# A committed refuel survives target loss and wave transitions.


func _attack_minigun(slot: int, tower: Dictionary, delta: float) -> void:
	tower["cooldown"] -= delta
	if enemies[slot].is_empty():
		tower["cooldown"] = maxf(0.0, float(tower["cooldown"]))
		return
	while float(tower["cooldown"]) <= 0.000000001:
		var time: float = maxf(0.0, _elapsed + float(tower["cooldown"]))
		tower["cooldown"] += float(tower["interval"])
		var selected: int = _target(slot, tower, tower["range"], -1, -1, -1, -1, time)
		if selected < 0:
			var boundary: float = _flame_motion_boundary(slot, time, _elapsed)
			var skipped: int = maxi(0, ceili((boundary - time) / float(tower["interval"]) - 0.000000001) - 1)
			tower["cooldown"] += skipped * float(tower["interval"])
			continue
		var enemy: Dictionary = enemies[slot][selected]
		tower["target_id"] = enemy["id"]
		tower["aim"] = _position(enemy["route"], _historical_progress(enemy, time))
		tower["shot"] += 1
		tower["secondary_target_id"] = -1
		tower["bounce_active"] = false
		tower["pierce_active"] = false
		_attack_pierce(slot, tower, tower["range"], selected)
		_sound_events.record(CombatSoundEvents.Cue.BOW, slot, Vector2(tower["cell"]), _death_time)


func _attack_flames(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		var config: Dictionary = _tower_types[tower["type_id"]]["advancements"].get(tower["advancement"], {})
		if config.get("weapon", "arrow") == "flamethrower":
			_attack_flame(slot, tower, config, delta)


# Divide at motion-cell, birth, fuel and refuel boundaries, not render frames.
func _attack_flame(slot: int, tower: Dictionary, config: Dictionary, delta: float) -> void:
	var time: float = _elapsed - delta
	tower["firing"] = false
	tower["target_id"] = -1
	tower["secondary_target_id"] = -1
	while time < _elapsed - 0.000000001:
		if float(tower["refuel_remaining"]) > 0.000000001:
			var waiting: float = minf(_elapsed - time, float(tower["refuel_remaining"]))
			tower["refuel_remaining"] = maxf(0.0, float(tower["refuel_remaining"]) - waiting)
			if float(tower["refuel_remaining"]) <= 0.000000001:
				tower["refuel_remaining"] = 0.0
			time += waiting
			_reset_firing(tower)
			continue
		var end: float = _flame_motion_boundary(slot, time, _elapsed)
		var selected: int = _target(slot, tower, tower["range"], -1, -1, -1, -1, (time + end) * 0.5, true)
		if selected < 0:
			_reset_firing(tower)
			tower["target_id"] = -1
			time = end
			continue
		var enemy: Dictionary = enemies[slot][selected]
		var id: int = enemy["id"]
		_burn_until(slot, id, time)
		selected = _enemy_index(slot, id)
		if selected < 0:
			continue
		_ignite(enemy, tower, config, time)
		if not _continuous_damage.has(tower["id"]):
			_continuous_damage[tower["id"]] = {}
		var fractions: Dictionary = _continuous_damage[tower["id"]]
		var base_rate: float = float(config["continuous_dps"]) * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"])
		var rate: float = base_rate * (1.0 + float(enemy["bounty_damage_bonus"]))
		end = minf(end, time + maxf(0.0, float(config["fuel_duration"]) - float(tower["continuous_fire_time"])))
		var burn: Dictionary = _burns[id]
		var own_burn: bool = float(burn["dps"]) <= float(config["burn_dps"]) * float(tower["damage_multiplier"])
		if not own_burn:
			end = minf(end, float(burn["end_time"]))
		if float(burn["last_time"]) > time + 0.000000001:
			end = minf(end, float(burn["last_time"]))
		end = minf(end, time + _flame_lethal_time(enemy, float(fractions.get(id, 0.0)), rate, time))
		var exposure: float = end - time
		tower["target_id"] = id
		tower["aim"] = _position(enemy["route"], _historical_progress(enemy, end))
		tower["firing"] = true
		tower["continuous_fire_time"] += exposure
		# Refresh throughout this uninterrupted span, including ticks longer than
		# the burn duration. Integration still precedes the final refresh.
		if own_burn:
			burn["end_time"] = maxf(float(burn["end_time"]), end + float(config["burn_duration"]))
		var total: float = float(fractions.get(id, 0.0)) + rate * exposure
		var bonus: Dictionary = _continuous_bonus_stream(tower["id"], id, float(enemy["bounty_damage_bonus"]) > 0.0)
		_accumulate_bonus(slot, enemy, bonus, base_rate * exposure)
		var damage: int = floori(total + 0.000000001)
		fractions[id] = maxf(0.0, total - damage)
		if damage > 0:
			_hit(slot, tower, selected, damage, true, bonus)
		_burn_until(slot, id, end)
		selected = _enemy_index(slot, id)
		if selected >= 0:
			_ignite(enemies[slot][selected], tower, config, end)
		time = end
		if float(tower["continuous_fire_time"]) >= float(config["fuel_duration"]) - 0.000000001:
			tower["refuel_remaining"] = float(config["refuel_duration"])
			_reset_firing(tower)
	if float(tower["refuel_remaining"]) <= 0.000000001 and _target(slot, tower, tower["range"], -1, -1, -1, -1, _elapsed, true) < 0:
		_reset_firing(tower)
		tower["target_id"] = -1


# Sum two independent fractional HP streams and stop on the lethal whole-HP
# crossing so a coarse simulation tick can retarget without wasting fuel.
func _flame_lethal_time(enemy: Dictionary, fraction: float, rate: float, time: float) -> float:
	var burn: Dictionary = _burns[enemy["id"]]
	if float(burn["last_time"]) > time + 0.000000001:
		return maxf(0.000000001, (float(enemy["hp"]) - fraction) / rate)
	var burn_fraction: float = burn["fraction"]
	var burn_rate: float = float(burn["dps"]) * (1.0 + float(enemy["bounty_damage_bonus"]))
	var duration: float = maxf(0.0, (float(enemy["hp"]) - fraction - burn_fraction) / (rate + burn_rate))
	var direct: float = fraction + rate * duration
	var burning: float = burn_fraction + burn_rate * duration
	if floori(direct + 0.000000001) + floori(burning + 0.000000001) < int(enemy["hp"]):
		duration += minf((floorf(direct + 0.000000001) + 1.0 - direct) / rate, (floorf(burning + 0.000000001) + 1.0 - burning) / burn_rate)
	return maxf(0.000000001, duration)


func _flame_motion_boundary(slot: int, time: float, finish: float) -> float:
	var boundary: float = finish
	for enemy: Dictionary in enemies[slot]:
		var birth: float = _enemy_spawn_times[enemy["id"]]
		if birth > time + 0.000000001:
			boundary = minf(boundary, birth)
			continue
		var speed: float = enemy["base_speed"]
		if _slow_motion.has(enemy["id"]):
			var motion: Array = _slow_motion[enemy["id"]]
			var expiry: float = _step_start_time + float(motion[1])
			if expiry > time + 0.000000001:
				boundary = minf(boundary, expiry)
				speed = motion[2]
		if speed <= 0.0:
			continue
		var progress: float = _historical_progress(enemy, time)
		var next_cell: float = floorf(progress + 0.5 + 0.000000001) + 0.5
		boundary = minf(boundary, time + (next_cell - progress) / speed)
	return maxf(time + 0.000000001, boundary)


func _attack(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		var definition: Dictionary = _tower_types[tower["type_id"]]
		if tower["behavior_kind"] not in ["attack", "chain"]:
			continue
		var config: Dictionary = definition["advancements"].get(tower["advancement"], {})
		if config.get("weapon", "arrow") == "flamethrower":
			continue
		if config.get("weapon", "arrow") == "minigun":
			_attack_minigun(slot, tower, delta)
			continue
		if tower["evolution"] == "boulders" or tower["evolution"] == "onyx_ring":
			if definition["evolutions"][tower["evolution"]]["continuous"]:
				_attack_continuous(slot, tower, tower["range"], delta)
			else:
				_attack_pulses(slot, tower, tower["range"], delta)
			continue
		tower["cooldown"] = maxf(0.0, tower["cooldown"] - delta)
		if tower["cooldown"] > 0.0:
			continue
		var target_index: int = _target(slot, tower, tower["range"])
		if target_index < 0:
			continue
		var enemy: Dictionary = enemies[slot][target_index]
		tower["target_id"] = enemy["id"]
		tower["aim"] = enemy["pos"]
		tower["shot"] += 1
		var cue: int = int(definition["attack_sound"])
		if config.get("weapon", "arrow") == "rocket":
			cue = CombatSoundEvents.Cue.BALLISTA
		elif config.get("weapon", "arrow") in ["molotov", "grenade"]:
			cue = CombatSoundEvents.Cue.RUNE
		_sound_events.record(cue, slot, Vector2(tower["cell"]), _death_time)
		tower["cooldown"] = tower["interval"]
		tower["bounce_active"] = false
		tower["pierce_active"] = false
		tower["secondary_target_id"] = -1
		if tower["behavior_kind"] == "chain":
			_attack_chain(slot, tower, target_index)
		elif definition["area_attack"]:
			# Reverse traversal permits removal in place without missing a victim.
			for index: int in range(enemies[slot].size() - 1, -1, -1):
				if cell_in_range(tower["cell"], Vector2i(enemies[slot][index]["pos"].round()), tower["range"]):
					_hit(slot, tower, index)
		else:
			if tower["special_upgraded"] and definition["special_upgrade"] == "second_archer":
				_attack_archers(slot, tower, definition)
			else:
				_attack_pierce(slot, tower, tower["range"], target_index)


# Capture every stream before applying any damage: a bomb may retire another
# archer's victim, but its accepted aim and projectile still belong to this volley.
func _attack_archers(slot: int, tower: Dictionary, definition: Dictionary) -> void:
	var config: Dictionary = definition["advancements"].get(tower["advancement"], {})
	var secondary: int = -1
	if int(config.get("archer_count", 2)) >= 2:
		secondary = _target(slot, tower, tower["range"], tower["secondary_mode"], tower["target_id"])
		if secondary < 0:
			secondary = _target(slot, tower, tower["range"], tower["secondary_mode"])
	if secondary >= 0:
		tower["secondary_target_id"] = enemies[slot][secondary]["id"]
		tower["secondary_aim"] = enemies[slot][secondary]["pos"]
		tower["secondary_shot"] += 1
	for index: int in range(tower["extra_archers"].size()):
		var archer: Dictionary = tower["extra_archers"][index]
		archer["target_id"] = -1
		var selected: int = _target(slot, tower, tower["range"], archer["mode"], tower["target_id"], tower["secondary_target_id"], -1, -1.0, false, tower["extra_archers"], index)
		if selected < 0:
			selected = _target(slot, tower, tower["range"], archer["mode"])
		if selected >= 0:
			archer["target_id"] = enemies[slot][selected]["id"]
			archer["aim"] = enemies[slot][selected]["pos"]
			archer["shot"] += 1
	_attack_arrow(slot, tower, tower["target_id"], tower["aim"], config)
	if secondary >= 0:
		_attack_arrow(slot, tower, tower["secondary_target_id"], tower["secondary_aim"], config)
	for archer: Dictionary in tower["extra_archers"]:
		if int(archer["target_id"]) >= 0:
			_attack_arrow(slot, tower, archer["target_id"], archer["aim"], config)


func _attack_arrow(slot: int, tower: Dictionary, target_id: int, impact: Vector2, config: Dictionary) -> void:
	var primary: int = _enemy_index(slot, target_id)
	if primary >= 0:
		var damage: int = ceili(float(tower["damage"]) * float(config.get("primary_multiplier", 1.0)))
		_hit(slot, tower, primary, damage)
		if config.has("burn_dps"):
			primary = _enemy_index(slot, target_id)
			if primary >= 0:
				_ignite(enemies[slot][primary], tower, config)
	if config.has("splash_radius"):
		_sound_events.record(CombatSoundEvents.Cue.EXPLOSION, slot, impact, _death_time)
		var radius_squared: float = float(config["splash_radius"]) * float(config["splash_radius"])
		var damage: int = ceili(float(tower["damage"]) * float(config["splash_multiplier"]))
		for index: int in range(enemies[slot].size() - 1, -1, -1):
			var enemy: Dictionary = enemies[slot][index]
			if int(enemy["id"]) != target_id and int(enemy["hp"]) > 0 and impact.distance_squared_to(enemy["pos"]) <= radius_squared:
				_hit(slot, tower, index, damage)
				if config.has("burn_dps"):
					var survivor: int = _enemy_index(slot, int(enemy["id"]))
					if survivor >= 0:
						_ignite(enemies[slot][survivor], tower, config)


func _enemy_index(slot: int, enemy_id: int) -> int:
	for index: int in range(enemies[slot].size()):
		if int(enemies[slot][index]["id"]) == enemy_id:
			return index
	return -1


func _ignite(enemy: Dictionary, tower: Dictionary, config: Dictionary, time: float = -1.0) -> void:
	if bool(enemy["fire_immune"]):
		return
	var id: int = enemy["id"]
	var dps: float = float(config["burn_dps"]) * float(tower["damage_multiplier"])
	var burn: Dictionary
	if _burns.has(id):
		burn = _burns[id]
		if dps < float(burn["dps"]):
			return
	else:
		burn = {"fraction": 0.0}
		_burns[id] = burn
	burn["dps"] = dps
	burn["source"] = tower
	var ignition_time: float = _elapsed if time < 0.0 else time
	burn["last_time"] = maxf(float(burn.get("last_time", ignition_time)), ignition_time)
	burn["end_time"] = maxf(float(burn.get("end_time", ignition_time)), ignition_time + float(config["burn_duration"]))
	enemy["burning"] = true
	enemy["burn_remaining"] = config["burn_duration"]


# Before new impacts, integrate only time after ignition/birth and before expiry.
# Whole HP enters the common hit/death owner; fractions never leak into snapshots.
func _apply_burns(slot: int) -> void:
	for index: int in range(enemies[slot].size() - 1, -1, -1):
		_burn_until(slot, int(enemies[slot][index]["id"]), _elapsed, index)


func _burn_until(slot: int, id: int, time: float, index: int = -1) -> void:
	if index < 0:
		index = _enemy_index(slot, id)
	if index < 0 or not _burns.has(id):
		return
	var enemy: Dictionary = enemies[slot][index]
	var burn: Dictionary = _burns[id]
	var exposure: float = maxf(0.0, minf(time, float(burn["end_time"])) - maxf(float(burn["last_time"]), float(_enemy_spawn_times[id])))
	var total: float = float(burn["fraction"]) + float(burn["dps"]) * exposure * (1.0 + float(enemy["bounty_damage_bonus"]))
	if float(enemy["bounty_damage_bonus"]) > 0.0 and not burn.has("bonus"):
		burn["bonus"] = {}
	var bonus: Dictionary = burn.get("bonus", NO_BONUS)
	_accumulate_bonus(slot, enemy, bonus, float(burn["dps"]) * exposure)
	var damage: int = floori(total + 0.000000001)
	burn["fraction"] = maxf(0.0, total - damage)
	burn["last_time"] = maxf(float(burn["last_time"]), time)
	enemy["burn_remaining"] = maxf(0.0, float(burn["end_time"]) - time)
	enemy["burning"] = float(enemy["burn_remaining"]) > 0.000000001
	if damage > 0:
		_hit(slot, burn["source"], index, damage, true, bonus)
	if not enemy["burning"]:
		enemy["burn_remaining"] = 0.0
		_burns.erase(id)


# Rolled pierce/bounce and purchased branches are independent additive capacities.
# A bolt hits straight-through victims first, then redirects from its final hit.
func _attack_pierce(slot: int, tower: Dictionary, range_cells: float, primary_index: int) -> void:
	var modifiers: Dictionary = tower["modifiers"]
	var pierce: int = int(modifiers.get("pierce", 0.0)) + int(tower["evolution"] == "pierce")
	var bounces: int = int(modifiers.get("bounce", 0.0)) + int(tower["evolution"] == "bounce")
	if pierce == 0 and bounces == 0:
		_hit(slot, tower, primary_index)
		return
	var hit_ids: Dictionary = {}
	var origin := Vector2(tower["cell"])
	var direction: Vector2 = Vector2(tower["aim"]) - origin
	var position: Vector2 = tower["aim"]
	if pierce > 0:
		tower["pierce_active"] = true
		tower["pierce_aim"] = tower["aim"]
	if pierce == 0 or direction == Vector2.ZERO:
		hit_ids[int(enemies[slot][primary_index]["id"])] = true
		_hit(slot, tower, primary_index)
	else:
		direction = direction.normalized()
		tower["pierce_active"] = true
		var radius: float = floorf(range_cells) + 0.5 - 0.000001
		tower["pierce_aim"] = origin + direction * (radius / maxf(absf(direction.x), absf(direction.y)))
		for contact: int in range(1 + pierce):
			var selected: int = -1
			var best_distance: float = INF
			var best_id: int = 0
			for index: int in range(enemies[slot].size()):
				var enemy: Dictionary = enemies[slot][index]
				if int(enemy["hp"]) <= 0 or hit_ids.has(int(enemy["id"])) or not cell_in_range(tower["cell"], Vector2i(enemy["pos"].round()), range_cells):
					continue
				var offset: Vector2 = Vector2(enemy["pos"]) - origin
				var distance: float = offset.dot(direction)
				if distance <= 0.0 or absf(offset.cross(direction)) > 0.25:
					continue
				if selected < 0 or distance < best_distance or (distance == best_distance and int(enemy["id"]) < best_id):
					selected = index
					best_distance = distance
					best_id = enemy["id"]
			if selected < 0:
				break
			position = enemies[slot][selected]["pos"]
			hit_ids[int(enemies[slot][selected]["id"])] = true
			_hit(slot, tower, selected)
	for jump: int in range(bounces):
		var selected: int = _nearest_unhit(slot, position, hit_ids)
		if selected < 0:
			break
		position = enemies[slot][selected]["pos"]
		hit_ids[int(enemies[slot][selected]["id"])] = true
		tower["bounce_active"] = true
		tower["bounce_aim"] = position
		_hit(slot, tower, selected, ceili(float(tower["damage"]) * TowerDefinition.BOUNCE_DAMAGE_MULTIPLIER))


func _attack_chain(slot: int, tower: Dictionary, primary_index: int) -> void:
	var config: Dictionary = tower["behavior_config"]
	var hit_ids: Dictionary = {}
	var points: Array[Vector2] = tower["chain_points"]
	points.clear()
	var selected: int = primary_index
	for contact: int in range(int(config["hit_count"])):
		if selected < 0:
			break
		var enemy: Dictionary = enemies[slot][selected]
		var position: Vector2 = enemy["pos"]
		hit_ids[int(enemy["id"])] = true
		points.append(position)
		_hit(slot, tower, selected, ceili(float(tower["damage"]) * (1.0 + contact * float(config["successive_hit_bonus"]))))
		selected = _nearest_unhit(slot, position, hit_ids, float(config["jump_distance"]))


func _nearest_unhit(slot: int, origin: Vector2, excluded: Dictionary, radius: float = INF) -> int:
	var best: int = -1
	var distance: float = radius * radius
	var best_id: int = 0
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if int(enemy["hp"]) <= 0 or excluded.has(int(enemy["id"])):
			continue
		var candidate: float = origin.distance_squared_to(enemy["pos"])
		if candidate > distance:
			continue
		if best < 0 or candidate < distance or (candidate == distance and int(enemy["id"]) < best_id):
			best = index
			distance = candidate
			best_id = enemy["id"]
	return best


func _attack_pulses(slot: int, tower: Dictionary, range_cells: float, delta: float) -> void:
	tower["cooldown"] -= delta
	while float(tower["cooldown"]) <= 0.000000001:
		var pulse_time: float = _elapsed + float(tower["cooldown"])
		tower["cooldown"] += float(tower["interval"])
		var hit_any: bool = false
		for index: int in range(enemies[slot].size() - 1, -1, -1):
			var enemy: Dictionary = enemies[slot][index]
			if float(_enemy_spawn_times[enemy["id"]]) > pulse_time + 0.000000001:
				continue
			var progress: float = _historical_progress(enemy, pulse_time)
			var position: Vector2 = _position(enemy["route"], progress)
			if not cell_in_range(tower["cell"], Vector2i(position.round()), range_cells):
				continue
			if not hit_any:
				tower["target_id"] = enemy["id"]
				tower["aim"] = position
				tower["pierce_active"] = false
				hit_any = true
			_hit(slot, tower, index)
		if hit_any:
			tower["shot"] += 1
			_sound_events.record(CombatSoundEvents.Cue.RUNE, slot, Vector2(tower["cell"]), _death_time)


func _attack_continuous(slot: int, tower: Dictionary, range_cells: float, delta: float) -> void:
	var tower_id: int = tower["id"]
	if not _continuous_damage.has(tower_id):
		_continuous_damage[tower_id] = {}
	var fractions: Dictionary = _continuous_damage[tower_id]
	for index: int in range(enemies[slot].size() - 1, -1, -1):
		var enemy: Dictionary = enemies[slot][index]
		var exposure: float = _continuous_exposure(tower["cell"], range_cells, enemy, minf(delta, _elapsed - float(_enemy_spawn_times[enemy["id"]])))
		if exposure <= 0.0:
			continue
		if bool(tower["freeze_upgraded"]) and not bool(enemy["ice_immune"]):
			enemy["slowed"] = true
			enemy["slow_remaining"] = TowerDefinition.freeze_duration(int(enemy["max_hp"]))
			enemy["speed"] = 0.0 if enemy["animation"] == "cast" else float(enemy["base_speed"]) * TowerDefinition.FREEZE_SPEED_MULTIPLIER
		var base_damage: float = float(tower["base_damage"]) * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"]) * exposure
		var total: float = float(fractions.get(enemy["id"], 0.0)) + base_damage * (1.0 + float(enemy["bounty_damage_bonus"]))
		var bonus: Dictionary = _continuous_bonus_stream(tower_id, enemy["id"], float(enemy["bounty_damage_bonus"]) > 0.0)
		_accumulate_bonus(slot, enemy, bonus, base_damage)
		# Credit is already vulnerability-adjusted HP: mark changes affect only
		# new exposure, not saved fractions. The epsilon corrects whole-HP sums.
		var damage: int = floori(total + 0.000000001)
		fractions[enemy["id"]] = maxf(0.0, total - damage)
		if damage > 0:
			_hit(slot, tower, index, damage, true, bonus)


# Read the motion captured before attacks, not a slow refreshed by an earlier
# tower this tick. This also makes Onyx pulses sample the correct side of expiry.
func _historical_progress(enemy: Dictionary, time: float) -> float:
	if _slow_motion.has(enemy["id"]):
		var motion: Array = _slow_motion[enemy["id"]]
		var duration: float = maxf(0.0, time - _step_start_time)
		return float(motion[0]) + minf(duration, float(motion[1])) * float(motion[2]) + maxf(0.0, duration - float(motion[1])) * float(motion[3])
	return maxf(0.0, float(enemy["progress"]) - float(enemy["base_speed"]) * (_elapsed - time))


# Integrate each constant-speed span separately when a slow expires mid-tick.
func _continuous_exposure(cell: Vector2i, range_cells: float, enemy: Dictionary, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	if _slow_motion.has(enemy["id"]):
		var motion: Array = _slow_motion[enemy["id"]]
		var slowed_seconds: float = minf(delta, float(motion[1]))
		var exposure: float = _exposure_span(cell, range_cells, enemy, motion[0], motion[2], slowed_seconds)
		var remainder: float = maxf(0.0, delta - slowed_seconds)
		return exposure + _exposure_span(cell, range_cells, enemy, float(motion[0]) + slowed_seconds * float(motion[2]), motion[3], remainder)
	var speed: float = enemy["base_speed"]
	return _exposure_span(cell, range_cells, enemy, maxf(0.0, float(enemy["progress"]) - speed * delta), speed, delta)


func _exposure_span(cell: Vector2i, range_cells: float, enemy: Dictionary, start: float, speed: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	if speed <= 0.0:
		return duration if cell_in_range(cell, Vector2i(_position(enemy["route"], start).round()), range_cells) else 0.0
	var route: Array = enemy["route"]
	var finish: float = minf(start + speed * duration, float(route.size() - 1))
	var distance: float = 0.0
	var radius: int = floori(range_cells)
	for segment: int in range(floori(start), ceili(finish)):
		var origin: Vector2i = route[segment]
		var direction: Vector2i = route[segment + 1] - origin
		var horizontal: bool = direction.x != 0
		var fixed_offset: int = absi(origin.y - cell.y) if horizontal else absi(origin.x - cell.x)
		if fixed_offset > radius:
			continue
		var axis_origin: float = origin.x if horizontal else origin.y
		var axis_center: float = cell.x if horizontal else cell.y
		var axis_direction: float = direction.x if horizontal else direction.y
		var first: float = (axis_center - radius - 0.5 - axis_origin) / axis_direction
		var last: float = (axis_center + radius + 0.5 - axis_origin) / axis_direction
		var low: float = maxf(maxf(0.0, start - segment), minf(first, last))
		var high: float = minf(minf(1.0, finish - segment), maxf(first, last))
		distance += maxf(0.0, high - low)
	return distance / speed


func _death_snapshot(slot: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index: int in range(_death_heads[slot], _death_events[slot].size()):
		events.append(_death_events[slot][index].duplicate())
	return events


func _reset_death_events() -> void:
	_sound_events.reset()
	if _death_heads[0] < _death_events[0].size() or _death_heads[1] < _death_events[1].size():
		_death_generation += 1
	_death_heads = [0, 0]
	_death_events = [[], []]


func _record_death(slot: int, enemy: Dictionary) -> void:
	var route: Array = enemy["route"]
	var progress: float = enemy["progress"]
	var faces_left: bool = false
	var horizontal_found: bool = false
	if route.size() > 1:
		var segment: int = clampi(floori(progress), 0, route.size() - 2)
		for index: int in range(segment, -1, -1):
			var direction: Vector2i = route[index + 1] - route[index]
			if direction.x != 0:
				faces_left = direction.x < 0
				horizontal_found = true
				break
		if not horizontal_found:
			for index: int in range(segment + 1, route.size() - 1):
				var direction: Vector2i = route[index + 1] - route[index]
				if direction.x != 0:
					faces_left = direction.x < 0
					break
	_death_events[slot].append({
		"id": _next_death_id, "enemy_id": enemy["id"], "type_id": enemy["type_id"],
		"pos": enemy["pos"], "faces_left": faces_left, "time": _death_time,
	})
	_next_death_id += 1
	_sound_events.record(int(_enemy_types[enemy["type_id"]]["death_sound"]), slot, enemy["pos"], _death_time)


func _retire_enemy(enemy_id: int) -> void:
	_enemy_spawn_times.erase(enemy_id)
	_slow_motion.erase(enemy_id)
	_burns.erase(enemy_id)
	for tower_id: int in _continuous_damage:
		_continuous_damage[tower_id].erase(enemy_id)
	for tower_id: int in _continuous_bonus:
		_continuous_bonus[tower_id].erase(enemy_id)
	for board: Array in towers:
		for tower: Dictionary in board:
			if int(tower["bounty_target_id"]) == enemy_id:
				tower["bounty_target_id"] = -1


func _continuous_bonus_stream(tower_id: int, enemy_id: int, marked: bool) -> Dictionary:
	if not marked and (not _continuous_bonus.has(tower_id) or not _continuous_bonus[tower_id].has(enemy_id)):
		return NO_BONUS
	if not _continuous_bonus.has(tower_id):
		_continuous_bonus[tower_id] = {}
	var streams: Dictionary = _continuous_bonus[tower_id]
	if not streams.has(enemy_id):
		streams[enemy_id] = {}
	return streams[enemy_id]


func _accumulate_bonus(slot: int, enemy: Dictionary, credit: Dictionary, base_damage: float) -> void:
	var source_id: int = enemy["bounty_tower_id"]
	var amount: float = base_damage * float(enemy["bounty_damage_bonus"])
	if source_id < 0 or amount <= 0.0:
		return
	if not credit.has(source_id):
		var source: Dictionary = _find_tower(slot, source_id)
		if source.is_empty():
			return
		credit[source_id] = {"source": source, "fraction": 0.0}
	credit[source_id]["fraction"] += amount


func _hit(slot: int, tower: Dictionary, enemy_index: int, damage: int = -1, bounty_applied: bool = false, credit: Dictionary = {}) -> void:
	var enemy: Dictionary = enemies[slot][enemy_index]
	var base_damage: int = int(tower["damage"]) if damage < 0 else damage
	var incoming_damage: int = base_damage
	if not bounty_applied:
		incoming_damage = ceili(float(base_damage) * (1.0 + float(enemy["bounty_damage_bonus"])))
	var hit_damage: int = mini(int(enemy["hp"]), incoming_damage)
	var indirect: int = 0
	if bounty_applied:
		# Quantize each source's accumulated extra HP only once, carrying sub-HP
		# credit across ticks/mark changes. Base HP gets priority on overkill.
		var available: int = 0
		for source_id: int in credit:
			available += floori(float(credit[source_id]["fraction"]) + 0.000000001)
		var budget: int = maxi(0, hit_damage - maxi(0, incoming_damage - available))
		for source_id: int in credit:
			var contribution: Dictionary = credit[source_id]
			var whole: int = floori(float(contribution["fraction"]) + 0.000000001)
			contribution["fraction"] = maxf(0.0, float(contribution["fraction"]) - mini(budget, whole))
			var removed: int = mini(budget, whole)
			contribution["source"]["indirect_damage"] += removed
			budget -= removed
			indirect += removed
	else:
		var source: Dictionary = _find_tower(slot, enemy["bounty_tower_id"]) if int(enemy["bounty_tower_id"]) >= 0 else NO_BONUS
		indirect = maxi(0, hit_damage - base_damage) if not source.is_empty() else 0
		if indirect > 0:
			source["indirect_damage"] += indirect
	tower["damage_dealt"] += hit_damage - indirect
	enemy["hp"] -= hit_damage
	if hit_damage > 0:
		_sound_events.record(CombatSoundEvents.Cue.HIT, slot, enemy["pos"], _death_time)
	if enemy["hp"] <= 0:
		tower["kills"] += 1
		var definition: Dictionary = _enemy_types[enemy["type_id"]]
		var bounty: int = int(definition["kill_bounty"])
		var normal: int = _rules.kill_bounty if bounty < 0 else bounty
		var mark_bonus: float = enemy["bounty_income_bonus"]
		var aura: Dictionary = _income_aura_source(slot, tower)
		var aura_bonus: float = float(aura["behavior_config"]["kill_income_bonus"]) if not aura.is_empty() else 0.0
		var payout: int = ceili(normal * (1.0 + mark_bonus + aura_bonus))
		coins[slot] += payout
		# Keep the single combined round-up: mark receives its incremental
		# rounded share first, then the strongest aura receives the remainder.
		var marked_payout: int = mini(payout, ceili(normal * (1.0 + mark_bonus)))
		var mark_source: Dictionary = _find_tower(slot, enemy["bounty_tower_id"]) if int(enemy["bounty_tower_id"]) >= 0 else NO_BONUS
		if not mark_source.is_empty():
			mark_source["coins_generated"] += marked_payout - normal
		if not aura.is_empty():
			aura["coins_generated"] += payout - marked_payout
		if int(definition["reroll_drop_amount"]) > 0 and float(definition["reroll_drop_chance"]) > 0.0 and _drop_random.randf() < float(definition["reroll_drop_chance"]):
			reroll_currency[slot] += int(definition["reroll_drop_amount"])
		_add_total(slot, "kills", enemy["type_id"])
		_record_death(slot, enemy)
		_retire_enemy(enemy["id"])
		enemies[slot].remove_at(enemy_index)




# Live tracking is host-owned, independent of the last released shot event.
# Resolve after damage, rituals and leaks so no retired victim is published.
func _update_tracking_target(slot: int, tower: Dictionary) -> void:
	if not _tower_types[tower["type_id"]]["directional_weapon"]:
		return
	var selected: int = _target(slot, tower, tower["range"])
	tower["tracking_target_id"] = -1 if selected < 0 else enemies[slot][selected]["id"]
	if selected >= 0:
		tower["tracking_aim"] = enemies[slot][selected]["pos"]


# Scan in place rather than allocating or sorting candidates for each tower.
func _target(slot: int, tower: Dictionary, range_cells: float, mode: int = -1, excluded_id: int = -1, excluded_second: int = -1, excluded_third: int = -1, time: float = -1.0, fire_only: bool = false, extra: Array = [], extra_count: int = 0) -> int:
	var best: int = -1
	var best_score: float = -INF
	var best_id: int = 0
	var center: Vector2 = Vector2(tower["cell"])
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if int(enemy["hp"]) <= 0 or int(enemy["id"]) == excluded_id or int(enemy["id"]) == excluded_second or int(enemy["id"]) == excluded_third or (fire_only and bool(enemy["fire_immune"])):
			continue
		var excluded: bool = false
		for earlier: int in range(extra_count):
			if int(extra[earlier]["target_id"]) == int(enemy["id"]):
				excluded = true
				break
		if excluded or (time >= 0.0 and float(_enemy_spawn_times[enemy["id"]]) > time + 0.000000001):
			continue
		var progress: float = float(enemy["progress"]) if time < 0.0 else _historical_progress(enemy, time)
		var position: Vector2 = enemy["pos"] if time < 0.0 else _position(enemy["route"], progress)
		if not cell_in_range(tower["cell"], Vector2i(position.round()), range_cells):
			continue
		var score: float
		match int(tower["mode"]) if mode < 0 else mode:
			TargetMode.CLOSEST:
				score = -center.distance_squared_to(position)
			TargetMode.STRONGEST:
				score = float(enemy["hp"])
			TargetMode.LAST:
				score = -progress
			_:
				score = progress
		var id: int = enemy["id"]
		if best < 0 or score > best_score or (score == best_score and id < best_id):
			best = index
			best_score = score
			best_id = id
	return best


func _apply_leaks(slot: int) -> void:
	var index: int = enemies[slot].size() - 1
	while index >= 0:
		if enemies[slot][index]["progress"] >= enemies[slot][index]["route"].size() - 1:
			if not _sandbox_mode:
				if base_health[slot] > 0:
					_sound_events.record(CombatSoundEvents.Cue.CRYSTAL, slot, Vector2(enemies[slot][index]["route"].back()), _death_time)
				base_health[slot] = maxi(0, base_health[slot] - int(enemies[slot][index]["damage"]))
			_retire_enemy(enemies[slot][index]["id"])
			enemies[slot].remove_at(index)
		index -= 1
