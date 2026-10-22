class_name MatchCombat
extends RefCounted

enum Phase { PLANNING, WAVE, FINISHED }
enum TargetMode { FURTHEST, CLOSEST, STRONGEST, LAST = 3 }

const DEATH_EVENT_LIFETIME: float = 2.0
# Bounded redirects per bolt; decaying Magic odds normally stop far earlier.
const MAX_BOUNCE_POINTS: int = 24
# Seconds an Orcapult-thrown enemy spends in the air between the two boards.
const FLIGHT_DURATION: float = 1.6
const NO_BONUS: Dictionary = {}
# Send orders may wait off-screen for one board up to this many at a time.
const SEND_QUEUE_LIMIT: int = 20
# Each wave-weight point above light rabble lengthens the gap after a send order by 5%.
const SEND_WEIGHT_DELAY: float = 0.05
const SEND_WEIGHT_FREE: int = 5
const NO_ARCHERS: Array = []

var phase: Phase = Phase.PLANNING
var wave: int = 0
var base_health: Array[int] = []
# Starting health plus the max HP every Heart of the Mountain on that board has grown.
var base_max_health: Array[int] = []
var coins: Array[int] = []
var reroll_currency: Array[int] = [0, 0]
# Recurring bonus on each surviving wave clear; queues belong to the target board.
var income: Array[int] = [0, 0]
var queued_sends: Array[int]:
	get:
		return [_pending_sends(0), _pending_sends(1)]
# Whole send orders (a group counts once) still waiting for each target board.
var queued_send_orders: Array[int]:
	get:
		return [_pending_orders(0), _pending_orders(1)]
var winner: int = -1
var coin_flip: bool = false
var towers: Array[Array] = [[], []]
var enemies: Array[Array] = [[], []]
# Enemies thrown by an Orcapult, airborne until they land on the target board.
var flights: Array[Dictionary] = []
var bombs: Array[Dictionary] = []
# Grand Mage Nullify: simulation time until each board's Magic towers fall silent.
var _magic_nullified_until: Array[float] = [0.0, 0.0]
# Recent deaths a Raise the Fallen spell may call back: progress, route and time.
var _fallen: Array[Array] = [[], []]
var _bomb_explosions: Array[Dictionary] = []
var _next_bomb_id: int = 1
var _next_flight_id: int = 1
# One host-generated ordered regular stream, replayed independently on both boards.
var wave_roster: Array[String] = []
var spawn_times: Array[float] = []
var wave_groups: Array[Dictionary] = []
var statistics_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var enemy_totals: Array[Dictionary] = [{"kills": {}, "sent": {}}, {"kills": {}, "sent": {}}]
var _recap := MatchRecap.new()
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
var _boss_stream: bool = false

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
# Magic Ballista bounce rolls never perturb waves, placement rolls or drops.
var _magic_random := RandomNumberGenerator.new()
# Critical hits from Bloodlust auras; only towers with crit chance draw from it.
var _crit_random := RandomNumberGenerator.new()
# Birth mutations never consume composition, timing, send, loot or combat rolls.
var _variant_random := RandomNumberGenerator.new()
# Per-source accepted exposure, not fractional HP or render-frame contacts.
var _shield_exposure: Dictionary = {}
var _stun_refresh_times: Dictionary = {}
var _death_rates: Array[float] = []
var _death_fractions: Array[float] = []
var _roll_rules: TowerRollRules
var _boss_loot: BossRewardLedger
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
# Slows, stationary casts and jump phases retain historical route-cell motion.
# Reused float records retain precision without per-tick history allocations.
var _slow_motion: Dictionary = {}
var _step_start_time: float = 0.0
# Burn retains its original tower dictionary even after sale, never in snapshots.
var _burns: Dictionary = {}
var _speed_cache_wave: int = -1
var _current_wave_speed: float = 0.0
var _next_wave_speed: float = 0.0
var _ability_pass: Array[Array] = [[], []]
# Host-only acceleration of current-position targeting; historical attack
# sampling still scans the accepted motion history. Buckets reuse their arrays.
var _target_grid: Array[Dictionary] = [{}, {}]
var _target_grid_valid: Array[bool] = [false, false]
var _target_grid_counts: Array[int] = [-1, -1]
var _target_candidates: Array[Array] = [[], []]
# Bumped whenever an enemy joins a board or enters another rounded cell. A
# tower whose range held no enemy cell at this version still holds none, so its
# current-position scan is skipped: [slot, version, range, cell] per tower ID.
var _cell_versions: Array[int] = [0, 0]
var _empty_reach: Dictionary = {}


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
	_magic_random.seed = _wave_random.seed ^ 0x4d414749
	_crit_random.seed = _wave_random.seed ^ 0x43524954
	_variant_random.seed = _wave_random.seed ^ 0x56415249
	var reward_random := RandomNumberGenerator.new()
	reward_random.seed = _wave_random.seed ^ 0x424f5353
	_boss_loot = BossRewardLedger.new(rules.boss_reward_rules, reward_random, not _sandbox_mode)
	if not _boss_loot.error_message.is_empty():
		push_error("Invalid boss rewards: " + _boss_loot.error_message)
		_roster_configuration_valid = false
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
	base_max_health = [rules.base_health, rules.base_health]
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
			"immune_elements": _element_set(definition.immune_elements),
			"nonphysical_damage_multiplier": definition.nonphysical_damage_multiplier,
			"fire_damage_multiplier": definition.fire_damage_multiplier,
			"lightning_damage_multiplier": definition.lightning_damage_multiplier,
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
			"heal_restores_shield": definition.heal_restores_shield,
			"shakra_radius": definition.shakra_radius, "shakra_max_bonus": definition.shakra_max_bonus,
			"ward_interval": definition.ward_interval, "ward_duration": definition.ward_duration, "ward_radius": definition.ward_radius,
			"spellbook": definition.spellbook.duplicate(true),
			"phase_interval": definition.phase_interval, "phase_immune_elements": _element_set(definition.phase_immune_elements),
			"summon_interval": definition.summon_interval,
			"summon_cast_duration": definition.summon_cast_duration,
			"summon_type": String(definition.summon_type),
			"summon_min": definition.summon_min, "summon_max": definition.summon_max,
			"summon_limit": definition.summon_limit,
			"summon_pool": definition.summon_pool.duplicate(), "summon_weights": definition.summon_weights.duplicate(),
			"stomp_interval": definition.stomp_interval, "stomp_radius": definition.stomp_radius,
			"stomp_health_fraction": definition.stomp_health_fraction,
			"tower_attack_kind": String(definition.tower_attack_kind),
			"tower_attack_interval": definition.tower_attack_interval,
			"tower_attack_range": definition.tower_attack_range,
			"tower_attack_cast_duration": definition.tower_attack_cast_duration,
			"tower_stun_duration": definition.tower_stun_duration,
			"tower_attack_targets": definition.tower_attack_targets,
			"jump_interval": definition.jump_interval, "jump_weights": definition.jump_weights.duplicate(),
			"jump_deploy_duration": definition.jump_deploy_duration,
			"jump_charge_duration": definition.jump_charge_duration, "jump_duration": definition.jump_duration,
			"jump_land_duration": definition.jump_land_duration,
		}
		_enemy_types[type_id].merge(EnemyMechanics.capture(definition))
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
			"damage_type": definition.damage_type,
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
		"stunned_remaining": 0.0, "stun_count": 0, "stun_source": "", "stun_position": Vector2(cell),
		"tracking_target_id": -1, "tracking_aim": Vector2(cell),
		"kills": 0, "damage_dealt": 0, "coins_generated": 0, "indirect_damage": 0,
		"damage_upgraded": false, "speed_upgraded": false,
		"special_upgraded": false, "freeze_upgraded": false, "evolution": "",
		"secondary_shot": 0, "secondary_aim": Vector2(cell), "secondary_target_id": -1,
		"advancement": "", "advancement_path": [] as Array[String], "extra_archers": [] as Array[Dictionary],
		"firing": false, "continuous_fire_time": 0.0, "refuel_remaining": 0.0, "refuel_duration": 0.0,
		"bounce_active": false, "bounce_aim": Vector2(cell),
		"pierce_active": false, "pierce_aim": Vector2(cell),
		"bounce_points": [] as Array[Vector2], "split_paths": [] as Array[Array], "branch_upgrades": [] as Array[String],
		"branch_pierce": 0, "bolt_scale": 1.0, "bolt_reach": 0.0, "magic_bounce": {}, "magic_split": 1,
		"orbit_bonus": 0, "max_hp_drain": 0.0, "max_hp_drain_limit": 0.0, "void_tendrils": 0, "drain_targets": [] as Array[int],
		"shards_generated": 0, "thrown": 0,
		"damage": definition["damage"], "interval": definition["interval"],
		"range": definition["range"], "base_damage": definition["damage"], "base_interval": definition["interval"],
		"behavior_kind": definition["behavior_kind"], "behavior_config": definition["behavior_config"].duplicate(true),
		"followup": "", "bounty_target_id": -1, "production_elapsed": 0.0,
		"chain_points": [] as Array[Vector2],
		"rarity": rolled["rarity"], "attributes": rolled["attributes"].duplicate(true),
		"rarity_rerolls": 0, "attribute_rerolls": 0,
		"rarity_reroll_cost": -1, "attribute_reroll_cost": -1,
		"support_damage_bonus": 0.0, "support_speed_bonus": 0.0, "support_range_bonus": 0.0, "crit_chance": 0.0, "crits": 0,
		"withered_until": 0.0, "wither": 0.0, "wither_remaining": 0.0, "nullified": false,
		"capstone": "", "base_max_health_bonus": 0, "base_max_health_per_round": 0, "base_max_health_limit": 0,
		"base_regen": 0, "output_multiplier": 1.0,
		"invested": 0 if _sandbox_mode else cost, "sell_value": 0 if _sandbox_mode else _sell_value(cost),
	})
	_recap.register_tower(slot, towers[slot].back())
	if not _sandbox_mode:
		coins[slot] -= cost
		_recap.add(slot, "spent", "towers", cost)
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
			_recap.add(slot, "spent", "rarity_shards", int(tower["rarity_reroll_cost"]))
		tower["rarity_rerolls"] += 1
		tower["attribute_rerolls"] = 0
	else:
		if not _sandbox_mode:
			coins[slot] -= int(tower["attribute_reroll_cost"])
			_recap.add(slot, "spent", "attribute_rerolls", int(tower["attribute_reroll_cost"]))
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
		# Totals of purchased branch upgrades, derived here rather than stored.
		var branch_pierce: int = 0
		var bolt_scale: float = 1.0
		var bolt_reach: float = 0.0
		var magic_bounce: Dictionary = {}
		var magic_split: int = 1
		var orbit_bonus: int = 0
		var extra_range: float = 0.0
		var max_hp_drain: float = float(branch.get("max_hp_damage", 0.0))
		var tendrils: int = int(branch.get("tendrils", 0))
		var interval_scale: float = 1.0
		for step: Dictionary in branch.get("upgrades", []):
			if not tower.get("branch_upgrades", []).has(step["id"]):
				continue
			branch_pierce += int(step.get("pierce", 0))
			bolt_scale += float(step.get("bolt_scale", 0.0))
			bolt_reach += float(step.get("bolt_reach", 0.0))
			if step.has("magic_bounce"):
				magic_bounce = step["magic_bounce"].duplicate()
			magic_split = maxi(magic_split, int(step.get("magic_split", 1)))
			orbit_bonus += int(step.get("orbit_bonus", 0))
			extra_range += float(step.get("range_bonus", 0.0))
			max_hp_drain += float(step.get("max_hp_damage", 0.0))
			tendrils += int(step.get("tendril_bonus", 0))
			interval_scale *= float(step.get("periodic_interval_multiplier", 1.0))
			var added: Dictionary = step.get("behavior_add", {})
			for key: String in added:
				behavior[key] = behavior.get(key, 0) + added[key]
		var output_multiplier: float = 1.0
		var max_health_per_round: int = 0
		var max_health_limit: int = 0
		var regen: int = 0
		for step: Dictionary in branch.get("capstones", {}).get(tower.get("capstone", ""), []):
			if tower["branch_upgrades"].has(step["id"]):
				output_multiplier *= float(step.get("output_multiplier", 1.0))
				max_health_per_round += int(step.get("base_max_health_per_round", 0))
				max_health_limit = maxi(max_health_limit, int(step.get("base_max_health_limit", 0)))
				regen += int(step.get("base_regen", 0))
		tower["output_multiplier"] = output_multiplier
		tower["base_max_health_per_round"] = max_health_per_round
		tower["base_max_health_limit"] = max_health_limit
		tower["base_regen"] = regen
		if kind == "crystal":
			behavior["periodic_interval"] = float(behavior["periodic_interval"]) * interval_scale
		tower["branch_pierce"] = branch_pierce
		tower["magic_split"] = magic_split
		tower["bolt_scale"] = bolt_scale
		tower["bolt_reach"] = bolt_reach
		tower["magic_bounce"] = magic_bounce
		tower["orbit_bonus"] = orbit_bonus
		tower["max_hp_drain"] = max_hp_drain
		tower["max_hp_drain_limit"] = float(branch.get("max_hp_damage_limit", 0.0))
		tower["void_tendrils"] = tendrils
		var base_range: float = float(config.get("range_cells", definition["range"])) + extra_range
		var range_bonus: float = float(modifiers.get("range", 0.0))
		# Rolled range scales the circular reach proportionally; drawbacks never
		# shrink it below one cell (or a smaller authored base).
		tower["range"] = maxf(minf(1.0, base_range), base_range * (1.0 + range_bonus)) if range_bonus < 0.0 else base_range * (1.0 + range_bonus)
		tower["behavior_config"] = behavior
		tower["support_damage_bonus"] = 0.0
		tower["support_speed_bonus"] = 0.0
		tower["support_range_bonus"] = 0.0
		tower["crit_chance"] = 0.0
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
			for aura: String in ["range_aura", "crit_chance"]:
				if behavior.has(aura):
					behavior[aura] = float(behavior[aura]) * strength
		elif kind == "economy":
			behavior["clear_income"] = ceili(float(behavior["clear_income"]) * (1.0 + income_bonus))
			behavior["periodic_income"] = ceili(float(behavior["periodic_income"]) * (1.0 + income_bonus))
		elif kind == "crystal":
			behavior["clear_shards"] = ceili(float(behavior["clear_shards"]) * (1.0 + income_bonus) * output_multiplier - 0.000000001)
			behavior["periodic_shards"] = ceili(float(behavior["periodic_shards"]) * (1.0 + income_bonus) * output_multiplier - 0.000000001)
		elif kind == "bounty":
			behavior["mark_income_bonus"] = float(behavior["mark_income_bonus"]) * (1.0 + income_bonus)
		elif kind == "income_aura":
			behavior["kill_income_bonus"] = float(behavior["kill_income_bonus"]) * (1.0 + income_bonus)
		elif kind == "catapult":
			if tower["special_upgraded"]:
				behavior["throw_count"] += int(definition["special_upgrade_config"].get("extra_throws", 0))
		elif kind == "chain":
			behavior["hit_count"] += int(modifiers.get("chain_jumps", 0.0))
			if tower["special_upgraded"]:
				behavior["successive_hit_bonus"] += float(definition["special_upgrade_config"].get("successive_hit_bonus", 0.0))
		tower["rarity_reroll_cost"] = -1 if _roll_rules == null else (0 if _sandbox_mode else _roll_rules.rarity_reroll_cost(tower["rarity_rerolls"]))
		tower["attribute_reroll_cost"] = -1 if _roll_rules == null else (0 if _sandbox_mode else _roll_rules.attribute_reroll_cost(tower["attribute_rerolls"]))
		tower["element"] = String(TowerDefinition.element_of(_tower_damage_type(tower))) if kind in ["attack", "chain", "catapult"] else ""
	_refresh_max_health(slot)
	for tower: Dictionary in towers[slot]:
		# Keep bonuses as 64-bit floats; Vector2 components narrow them to 32-bit.
		var damage_groups: Dictionary[String, float] = {}
		var speed_groups: Dictionary[String, float] = {}
		var range_groups: Dictionary[String, float] = {}
		var crit_groups: Dictionary[String, float] = {}
		for support: Dictionary in towers[slot]:
			if support["behavior_kind"] != "support" or float(support["stunned_remaining"]) > 0.000000001 or not cell_in_range(support["cell"], tower["cell"], support["range"]):
				continue
			var config: Dictionary = support["behavior_config"]
			var group: String = config["stack_group"]
			damage_groups[group] = maxf(damage_groups.get(group, 0.0), float(config["damage_bonus"]))
			speed_groups[group] = maxf(speed_groups.get(group, 0.0), float(config["attack_speed_bonus"]))
			range_groups[group] = maxf(range_groups.get(group, 0.0), float(config.get("range_aura", 0.0)))
			crit_groups[group] = maxf(crit_groups.get(group, 0.0), float(config.get("crit_chance", 0.0)))
		for bonus: float in damage_groups.values():
			tower["support_damage_bonus"] += bonus
		for bonus: float in speed_groups.values():
			tower["support_speed_bonus"] += bonus
		# Reach and crits only help towers that attack; auras never extend auras.
		if tower["behavior_kind"] in ["attack", "chain", "catapult"]:
			for bonus: float in range_groups.values():
				tower["support_range_bonus"] += bonus
			tower["range"] = float(tower["range"]) + float(tower["support_range_bonus"])
			for bonus: float in crit_groups.values():
				tower["crit_chance"] += bonus
			tower["crit_chance"] = minf(float(tower["crit_chance"]), TowerDefinition.MAX_CRIT_CHANCE)
		var modifiers: Dictionary = tower["modifiers"]
		var damage_multiplier: float = (1.0 + float(modifiers.get("damage", 0.0))) * (1.0 + float(tower["support_damage_bonus"]))
		# Dreadmaw's Soulfire withers a tower's damage until it fades.
		if float(tower.get("withered_until", 0.0)) > _elapsed + 0.000000001:
			damage_multiplier *= 1.0 - float(tower["wither"])
		var speed_multiplier: float = (1.0 + float(modifiers.get("attack_speed", 0.0))) * (1.0 + float(tower["support_speed_bonus"]))
		var old_interval: float = tower["interval"]
		tower["damage_multiplier"] = damage_multiplier
		tower["speed_multiplier"] = speed_multiplier
		# Preserve ceil for fractional damage without adding HP for arithmetic noise.
		tower["damage"] = ceili(float(tower["base_damage"]) * damage_multiplier - 0.000000001)
		tower["interval"] = float(tower["base_interval"]) / speed_multiplier
		if old_interval > 0.0:
			tower["cooldown"] *= float(tower["interval"]) / old_interval
		if tower["behavior_kind"] == "bounty" and float(tower["stunned_remaining"]) <= 0.000000001 and int(tower["bounty_target_id"]) >= 0:
			var index: int = _enemy_index(slot, tower["bounty_target_id"])
			if index >= 0:
				enemies[slot][index]["bounty_damage_bonus"] = tower["behavior_config"]["mark_damage_bonus"]
				enemies[slot][index]["bounty_income_bonus"] = tower["behavior_config"]["mark_income_bonus"]


func _refresh_max_health(slot: int) -> void:
	var maximum: int = _rules.base_health
	for tower: Dictionary in towers[slot]:
		maximum += int(tower.get("base_max_health_bonus", 0))
	base_max_health[slot] = maximum
	base_health[slot] = mini(base_health[slot], maximum)


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
	var steps: Array = current.get("upgrades", [])
	var purchased_steps: Array = tower.get("branch_upgrades", [])
	var branch_step: bool = purchased_steps.size() < steps.size() and steps[purchased_steps.size()]["id"] == upgrade
	# After the last ordered step, one exclusive capstone path continues in order.
	var capstone_path: String = ""
	var capstone_config: Dictionary = {}
	if not branch_step and not steps.is_empty() and purchased_steps.size() >= steps.size():
		var capstones: Dictionary = current.get("capstones", {})
		var chosen: String = tower.get("capstone", "")
		var bought: int = purchased_steps.size() - steps.size()
		for path: String in capstones:
			var path_steps: Array = capstones[path]
			if (chosen.is_empty() or chosen == path) and bought < path_steps.size() and path_steps[bought]["id"] == upgrade:
				capstone_path = path
				capstone_config = path_steps[bought]
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
	elif branch_step:
		config = steps[purchased_steps.size()]
	elif not capstone_path.is_empty():
		config = capstone_config
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
		_recap.add(slot, "spent", "upgrades", cost)
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
			extra.append({"shot": 0, "aim": Vector2(tower["cell"]), "target_id": -1})
		tower["secondary_target_id"] = -1
		tower["firing"] = false
		tower["continuous_fire_time"] = 0.0
		tower["refuel_remaining"] = 0.0
		tower["refuel_duration"] = float(config.get("refuel_duration", 0.0))
	elif not capstone_path.is_empty():
		tower["branch_upgrades"].append(upgrade)
		tower["capstone"] = capstone_path
	elif branch_step:
		tower["branch_upgrades"].append(upgrade)
		# Compound on the evolved base, like Arrow attack-rate advancements.
		tower["base_damage"] = float(tower["base_damage"]) * float(config.get("damage_multiplier", 1.0))
		tower["base_interval"] = float(tower["base_interval"]) / float(config.get("attack_rate_multiplier", 1.0))
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
			_recap.add(slot, "earned", "sale_coins", _sell_value(tower["invested"]))
		_continuous_damage.erase(tower_id)
		_continuous_bonus.erase(tower_id)
		_stun_refresh_times.erase(tower_id)
		for enemy_id: int in _shield_exposure:
			_shield_exposure[enemy_id].erase(tower_id)
		_clear_tower_mark(slot, tower)
		_recap.sell(slot, tower_id)
		towers[slot].remove_at(index)
		_refresh_board(slot)
		_sound_events.record(CombatSoundEvents.Cue.SALE, slot, Vector2(tower["cell"]), _death_time)
		return true
	return false


# Level is derived from accepted upgrades, never a second mutable copy of tower state.
static func tower_level(tower: Dictionary) -> int:
	return 1 + int(bool(tower["damage_upgraded"])) + int(bool(tower["speed_upgraded"])) + int(bool(tower.get("special_upgraded", false))) + int(bool(tower.get("freeze_upgraded", false))) + tower.get("advancement_path", []).size() + int(not String(tower.get("followup", "")).is_empty()) + int(not String(tower.get("evolution", "")).is_empty() and _tower_has_separate_special(tower)) + tower.get("branch_upgrades", []).size()


static func _tower_has_separate_special(tower: Dictionary) -> bool:
	return tower.get("behavior_kind", "") in ["chain", "catapult"]


static func tower_upgrade_cost(tower: Dictionary, definition: Dictionary) -> int:
	# Each level adds half the original price, not half the previous price.
	return ceili(float(definition["upgrade_base_cost"]) * (1.0 + 0.5 * (tower_level(tower) - 1)))


static func _sell_value(invested: int) -> int:
	return floori(float(invested) * 0.6)


# Tower reach is a circle around the tower's cell centre: fractional range
# bonuses add only the few tiles they actually reach, instead of a whole ring.
static func cell_in_range(origin: Vector2i, cell: Vector2i, range_cells: float) -> bool:
	var dx: int = cell.x - origin.x
	var dy: int = cell.y - origin.y
	return float(dx * dx + dy * dy) <= range_cells * range_cells + 0.000001


# Square (Chebyshev) blast areas for enemy death stuns and Giant bombs.
static func cell_in_square(origin: Vector2i, cell: Vector2i, radius: float) -> bool:
	return maxi(absi(cell.x - origin.x), absi(cell.y - origin.y)) <= radius


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
			tower["bounce_points"].clear()
			tower["split_paths"].clear()
			for archer: Dictionary in tower["extra_archers"]:
				archer["aim"] += Vector2.DOWN
			tower["bounce_aim"] += Vector2.DOWN
			tower["pierce_aim"] += Vector2.DOWN


func _can_send_enemy(slot: int, type_id: StringName) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _enemy_types.has(String(type_id)) or not _valid_send_timing():
		return false
	var definition: Dictionary = _enemy_types[String(type_id)]
	var delivery_wave: int = wave + 1 if phase == Phase.PLANNING else wave
	return definition["send_enabled"] and delivery_wave >= int(definition["send_first_wave"]) and (_sandbox_mode or coins[slot] >= int(definition["send_cost"])) and income[slot] >= -int(definition["send_income"]) and _pending_orders(1 - slot) < SEND_QUEUE_LIMIT


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
	_special_stream = _special_stream or float(definition["heal_interval"]) > 0.0 or float(definition["ward_interval"]) > 0.0 or float(definition["summon_interval"]) > 0.0 or EnemyMechanics.has_abilities(definition)
	_boss_stream = _boss_stream or _requires_combat_events(definition)
	if _pending_sends(target) == 0 and phase == Phase.WAVE:
		_next_send_times[target] = maxf(_next_send_times[target], _elapsed)
	for member: int in range(count):
		_send_queues[target].append(String(type_id))
		_send_group_ends[target].append(member == count - 1)
	if not _sandbox_mode:
		coins[slot] -= cost
		_recap.add(slot, "spent", "sends", cost)
	income[slot] += int(definition["send_income"])
	_add_total(slot, "sent", String(type_id), count)
	_sound_events.record(CombatSoundEvents.Cue.SEND, slot, Vector2.ZERO, _death_time)
	if phase == Phase.WAVE and _next_send_times[target] <= _elapsed:
		_spawn_send(target)


func _valid_send_timing() -> bool:
	return is_finite(_send_spawn_interval) and _send_spawn_interval > 0.0 and _valid_interval_scaling()


func _pending_sends(slot: int) -> int:
	return _send_queues[slot].size() - _send_heads[slot]


func _pending_orders(slot: int) -> int:
	var orders: int = 0
	for index: int in range(_send_heads[slot], _send_group_ends[slot].size()):
		if _send_group_ends[slot][index]:
			orders += 1
	return orders


# Heavier sends take slightly longer to clear the portal before the next order.
static func send_order_gap(base_gap: float, weight: int) -> float:
	return base_gap * (1.0 + SEND_WEIGHT_DELAY * maxf(0.0, float(weight - SEND_WEIGHT_FREE)))



# Debug jumps abandon a round, never clear it: no bounty, income or wave reward.
func debug_set_round(round_number: int) -> bool:
	if (phase == Phase.FINISHED and not _sandbox_mode) or round_number < 1 or (round_number > 1000 and not _sandbox_mode):
		return false
	phase = Phase.PLANNING
	wave = round_number - 1
	winner = -1
	coin_flip = false
	enemies = [[], []]
	_target_grid_valid = [false, false]
	flights.clear()
	_reset_death_events()
	wave_roster.clear()
	wave_groups.clear()
	_special_stream = false
	_boss_stream = false
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
	_magic_nullified_until = [0.0, 0.0]
	_fallen = [[], []]
	_step_start_time = 0.0
	_continuous_damage.clear()
	_continuous_bonus.clear()
	_burns.clear()
	_shield_exposure.clear()
	_enemy_spawn_times.clear()
	_slow_motion.clear()
	for board: Array in towers:
		for tower: Dictionary in board:
			tower["bounty_target_id"] = -1
			tower["production_elapsed"] = 0.0
			tower["chain_points"].clear()
			tower["cooldown"] = tower["interval"] if tower["evolution"] == "onyx_ring" else 0.0
			_reset_firing(tower)
			_clear_stun(tower)
			_clear_spell_marks(tower)
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
			tower["bounce_points"].clear()
			tower["split_paths"].clear()
			tower["pierce_aim"] = Vector2(tower["cell"])
			tower["pierce_active"] = false
	for slot: int in range(2):
		_refresh_board(slot)
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
	_empty_reach.clear()
	wave_roster.clear()
	spawn_times.clear()
	_special_stream = false
	_boss_stream = false
	for slot: int in range(2):
		for index: int in range(_send_heads[slot], _send_queues[slot].size()):
			var pending: Dictionary = _enemy_types[_send_queues[slot][index]]
			_special_stream = _special_stream or float(pending["heal_interval"]) > 0.0 or float(pending["ward_interval"]) > 0.0 or float(pending["summon_interval"]) > 0.0 or EnemyMechanics.has_abilities(pending)
			_boss_stream = _boss_stream or _requires_combat_events(pending, wave_number)
	var interval_multiplier: float = _spawn_interval_multiplier(wave_number)
	var group_times: Array[float] = _generate_spawn_times(groups.size(), _rules.spawn_interval * interval_multiplier)
	var offset: float = 0.0
	for index: int in range(groups.size()):
		var group: Dictionary = groups[index]
		var definition: Dictionary = _enemy_types[group["type_id"]]
		_special_stream = _special_stream or float(definition["heal_interval"]) > 0.0 or float(definition["ward_interval"]) > 0.0 or float(definition["summon_interval"]) > 0.0 or EnemyMechanics.has_abilities(definition)
		_boss_stream = _boss_stream or _requires_combat_events(definition, wave_number)
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
	_magic_nullified_until = [0.0, 0.0]
	_fallen = [[], []]
	_next_send_times = [0.0, 0.0]
	wave = wave_number
	phase = Phase.WAVE
	for slot: int in range(2):
		var withered: bool = false
		for tower: Dictionary in towers[slot]:
			_reset_firing(tower)
			_clear_stun(tower)
			withered = withered or float(tower.get("withered_until", 0.0)) > 0.0
			_clear_spell_marks(tower)
		if withered:
			_refresh_board(slot)
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
	if _special_stream or _boss_stream or periodic:
		for slot: int in range(2):
			_spawn_enemies(slot)
	while remaining > 0.000000001:
		if _boss_stream:
			for slot: int in range(2):
				_prepare_boss_motion(slot)
				_update_bounties(slot)
				_attack(slot, 0.0)
		var step: float = _next_event_step(remaining, periodic) if _special_stream or _boss_stream or periodic else remaining
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
			if periodic and base_health[0] > 0 and base_health[1] > 0:
				_produce_periodic(slot, step)
			_advance_stuns(slot, step)
			# A dead caster never resolves its due ritual.
			_enemy_abilities(slot)
			_apply_leaks(slot)
			if _boss_stream:
				_prepare_boss_motion(slot)
				_attack(slot, 0.0)
			for tower: Dictionary in towers[slot]:
				_update_tracking_target(slot, tower)
		_land_flights()
		if base_health[0] > 0 and base_health[1] > 0:
			_advance_bombs()
		remaining -= step
		if (periodic or _boss_stream) and (base_health[0] == 0 or base_health[1] == 0 or _wave_cleared()):
			break
	for index: int in range(_bomb_explosions.size() - 1, -1, -1):
		if _death_time - float(_bomb_explosions[index]["time"]) >= DEATH_EVENT_LIFETIME - 0.000000001:
			_bomb_explosions.remove_at(index)
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
				_clear_stun(tower)
				_clear_spell_marks(tower)
				tower["production_elapsed"] = 0.0
			_refresh_board(slot)
		_magic_nullified_until = [0.0, 0.0]
		flights.clear()
		bombs.clear()
		_bomb_explosions.clear()
		for board: Array in enemies:
			for enemy: Dictionary in board:
				enemy["stunned_remaining"] = 0.0
				enemy["stun_source"] = ""
				BossMechanics.prepare(enemy)
	elif _wave_cleared():
		var reward: int = _rules.wave_reward + wave * _rules.wave_reward_growth
		_recap.rounds_cleared += 1
		for slot: int in range(2):
			coins[slot] += reward + income[slot]
			reroll_currency[slot] += _rules.clear_reroll_currency
			_recap.add(slot, "earned", "wave_coins", reward)
			_recap.add(slot, "earned", "income_coins", income[slot])
			_recap.add(slot, "earned", "clear_shards", _rules.clear_reroll_currency)
			for tower: Dictionary in towers[slot]:
				if tower["behavior_kind"] == "economy" and float(tower["stunned_remaining"]) <= 0.000000001:
					var produced: int = int(tower["behavior_config"]["clear_income"])
					coins[slot] += produced
					tower["coins_generated"] += produced
					_recap.add(slot, "earned", "production_coins", produced)
				elif tower["behavior_kind"] == "crystal" and float(tower["stunned_remaining"]) <= 0.000000001:
					var dug: int = int(tower["behavior_config"]["clear_shards"])
					reroll_currency[slot] += dug
					tower["shards_generated"] += dug
					_recap.add(slot, "earned", "production_shards", dug)
					# Heart growth stays on the mine, so selling it takes the grown max HP away.
					var growth: int = mini(int(tower["base_max_health_per_round"]), int(tower["base_max_health_limit"]) - base_max_health[slot])
					if growth > 0:
						tower["base_max_health_bonus"] += growth
						base_max_health[slot] += growth
					base_health[slot] = mini(base_max_health[slot], base_health[slot] + int(tower["base_regen"]))
				_reset_firing(tower)
				_clear_stun(tower)
				_clear_spell_marks(tower)
			_refresh_board(slot)
		_magic_nullified_until = [0.0, 0.0]
		phase = Phase.PLANNING
	return true


func _next_event_step(maximum: float, periodic: bool = false) -> float:
	var duration: float = maximum
	for bomb: Dictionary in bombs:
		duration = minf(duration, float(bomb["fuse_remaining"]))
	for flight: Dictionary in flights:
		duration = minf(duration, float(flight["land_time"]) - _elapsed)
	for slot: int in range(2):
		if _spawned[slot] < spawn_times.size():
			duration = minf(duration, spawn_times[_spawned[slot]] - _elapsed)
		if _pending_sends(slot) > 0:
			duration = minf(duration, _next_send_times[slot] - _elapsed)
		# One pass: a minimum does not depend on the order it is taken in.
		var nullifying: bool = _magic_nullified_until[slot] > _elapsed + 0.000000001
		for tower: Dictionary in towers[slot]:
			if _boss_stream:
				var stunned: float = tower["stunned_remaining"]
				if stunned > 0.000000001:
					duration = minf(duration, stunned)
				else:
					var cooldown: float = tower["cooldown"]
					var kind: String = tower["behavior_kind"]
					if cooldown > 0.000000001 and (kind == "attack" or kind == "chain") and not (nullifying and tower.get("element", "") == "magic"):
						duration = minf(duration, cooldown)
			var withered: float = tower["withered_until"]
			if withered > _elapsed:
				duration = minf(duration, withered - _elapsed)
		if periodic:
			for tower: Dictionary in towers[slot]:
				if float(tower["stunned_remaining"]) <= 0.000000001 and _periodic_amount(tower) > 0:
					duration = minf(duration, float(tower["behavior_config"]["periodic_interval"]) - float(tower["production_elapsed"]))
		for enemy: Dictionary in enemies[slot]:
			var definition: Dictionary = _enemy_types[enemy["type_id"]]
			if int(enemy["shield_max_hits"]) > 0 or float(definition["death_stun_duration"]) > 0.0 or float(definition["death_bomb_fuse"]) > 0.0:
				duration = minf(duration, _shield_event_step(slot, enemy, duration))
			if float(definition["death_stun_duration"]) > 0.0 or float(definition["death_bomb_fuse"]) > 0.0:
				duration = minf(duration, _death_stun_event_step(slot, enemy, duration))
			if float(enemy["stunned_remaining"]) > 0.000000001:
				duration = minf(duration, float(enemy["stunned_remaining"]))
				continue
			if _boss_stream:
				if float(enemy["slow_remaining"]) > 0.000000001:
					duration = minf(duration, float(enemy["slow_remaining"]))
				duration = minf(duration, BossMechanics.event_step(enemy, definition))
				if float(enemy["speed"]) > 0.0:
					duration = minf(duration, _next_attack_entry(slot, enemy, definition, duration))
				if float(enemy["tower_attack_remaining"]) > 0.000000001:
					duration = minf(duration, float(enemy["tower_attack_remaining"]))
				elif float(definition["tower_attack_interval"]) > 0.0 and float(enemy["cast_remaining"]) <= 0.000000001 and BossMechanics.can_act(enemy):
					duration = minf(duration, maxf(0.000000001, float(enemy["next_tower_attack"]) - float(enemy["age"])))
				if float(definition["stomp_interval"]) > 0.0:
					duration = minf(duration, maxf(0.000000001, float(enemy["next_stomp"]) - float(enemy["age"])))
			if periodic and float(enemy["speed"]) > 0.0:
				duration = minf(duration, maxf(0.0, float(enemy["route"].size() - 1) - float(enemy["progress"])) / float(enemy["speed"]))
			if float(enemy["cast_remaining"]) > 0.0:
				duration = minf(duration, float(enemy["cast_remaining"]))
			elif float(definition["summon_interval"]) > 0.0 and (not _boss_stream or (float(enemy["tower_attack_remaining"]) <= 0.000000001 and BossMechanics.can_act(enemy))):
				duration = minf(duration, float(enemy["next_summon"]) - float(enemy["age"]))
			duration = minf(duration, EnemyMechanics.event_step(enemy, definition))
			if float(definition["heal_interval"]) > 0.0:
				duration = minf(duration, _heal_wait(slot, enemy, definition))
			if float(definition["ward_interval"]) > 0.0:
				duration = minf(duration, maxf(0.000000001, float(enemy["next_ward"]) - float(enemy["age"])))
			if float(definition["phase_interval"]) > 0.0:
				var interval: float = definition["phase_interval"]
				duration = minf(duration, maxf(0.000000001, interval - fposmod(float(enemy["age"]), interval)))
			if not definition["spellbook"].is_empty() and String(enemy["spell"]).is_empty():
				duration = minf(duration, maxf(0.000000001, float(enemy["next_spell"]) - float(enemy["age"])))
			if float(enemy.get("ward_until", 0.0)) > _elapsed:
				duration = minf(duration, float(enemy["ward_until"]) - _elapsed)
			if float(enemy.get("haste_until", 0.0)) > _elapsed:
				duration = minf(duration, float(enemy["haste_until"]) - _elapsed)
			if _magic_nullified_until[slot] > _elapsed:
				duration = minf(duration, _magic_nullified_until[slot] - _elapsed)
	return maxf(0.000000001, duration)


# Grand Mage: glide, then stand still for the next castable spell in the rotation.
func _advance_spellbook(slot: int, mage: Dictionary, book: Dictionary) -> void:
	if not String(mage["spell"]).is_empty():
		if float(mage["cast_remaining"]) <= 0.000000001:
			_resolve_spell(slot, mage, book)
		return
	if float(mage["age"]) + 0.000000001 < float(mage["next_spell"]) or not BossMechanics.can_act(mage) or float(mage["tower_attack_remaining"]) > 0.000000001:
		return
	var order: Array = book["order"]
	for attempt: int in range(order.size()):
		var index: int = (int(mage["spell_index"]) + attempt) % order.size()
		if _begin_spell(slot, mage, book, String(order[index])):
			mage["spell_index"] = (index + 1) % order.size()
			return
	mage["next_spell"] = float(mage["age"]) + float(book["glide"])


func _begin_spell(slot: int, mage: Dictionary, book: Dictionary, spell: String) -> bool:
	var config: Dictionary = book[spell]
	match spell:
		"barrier":
			if float(mage["hp"]) > float(mage["max_hp"]) * float(config["below"]) or int(mage["barriers"]) >= int(config["limit"]):
				return false
		"fireball":
			if towers[slot].is_empty():
				return false
			mage["spell_aim"] = Vector2(towers[slot][_group_random.randi_range(0, towers[slot].size() - 1)]["cell"])
		"portal":
			if _portal_passengers(slot, mage, int(config["count"])).is_empty():
				return false
			mage["spell_aim"] = _position(mage["route"], minf(float(mage["progress"]) + Spellbook.PORTAL_LEAD, float(mage["route"].size() - 1) - 0.5))
		"soulfire":
			if towers[slot].is_empty():
				return false
			mage["spell_aim"] = _densest_tower_cell(slot, float(config["radius"]))
		"raise_dead":
			if _risen_candidates(slot, mage, config).is_empty():
				return false
	mage["spell"] = spell
	mage["spell_phase"] = "shield" if spell == "nullify" else "cast"
	mage["spell_shielded"] = spell == "nullify"
	mage["cast_remaining"] = Spellbook.cast_time(book, spell)
	mage["spell_duration"] = mage["cast_remaining"]
	mage["spell_count"] += 1
	mage["animation"] = spell
	mage["animation_elapsed"] = 0.0
	mage["speed"] = 0.0
	_sound_events.record(CombatSoundEvents.Cue.RUNE, slot, mage["pos"], _death_time)
	return true


func _resolve_spell(slot: int, mage: Dictionary, book: Dictionary) -> void:
	var spell: String = mage["spell"]
	var config: Dictionary = book[spell]
	var effect: Dictionary = {"id": int(mage["spell_count"]), "kind": spell, "pos": mage["pos"]}
	match spell:
		"nullify":
			if mage["spell_phase"] == "shield":
				# The channel ends in a staff strike that silences the board's Magic.
				mage["spell_shielded"] = false
				mage["spell_phase"] = "strike"
				mage["cast_remaining"] = float(config["strike"])
				mage["spell_duration"] = mage["cast_remaining"]
				mage["animation"] = "nullify_strike"
				mage["animation_elapsed"] = 0.0
				_magic_nullified_until[slot] = maxf(_magic_nullified_until[slot], _elapsed + float(config["duration"]))
				mage["spell_effect"] = effect
				_sound_events.record(CombatSoundEvents.Cue.TROLL_STOMP, slot, mage["pos"], _death_time)
				return
		"fireball":
			var aim: Vector2 = mage["spell_aim"]
			effect["to"] = aim
			for tower: Dictionary in towers[slot]:
				if cell_in_range(Vector2i(aim), tower["cell"], float(config["radius"])):
					_stun_tower(slot, tower, float(config["stun"]), "fireball", aim)
			_refresh_board(slot)
			_update_bounties(slot)
			mage["spell_effect"] = effect
			_sound_events.record(CombatSoundEvents.Cue.EXPLOSION, slot, aim, _death_time)
		"portal":
			var from: Array[Vector2] = []
			var front: float = float(mage["progress"]) + Spellbook.PORTAL_LEAD
			for passenger: Dictionary in _portal_passengers(slot, mage, int(config["count"])):
				from.append(passenger["pos"])
				passenger["progress"] = minf(front, float(passenger["route"].size() - 1) - 0.5)
				passenger["pos"] = _position(passenger["route"], passenger["progress"])
				_slow_motion.erase(passenger["id"])
			_enemies_relocated(slot)
			effect["from"] = from
			effect["to"] = _position(mage["route"], minf(front, float(mage["route"].size() - 1) - 0.5))
			mage["spell_effect"] = effect
			_sound_events.record(CombatSoundEvents.Cue.PORTAL, slot, effect["to"], _death_time)
		"haste":
			var radius_squared: float = float(config["radius"]) * float(config["radius"])
			for ally: Dictionary in enemies[slot]:
				if ally["id"] == mage["id"] or int(ally["hp"]) <= 0 or _enemy_types[ally["type_id"]]["boss"]:
					continue
				if Vector2(mage["pos"]).distance_squared_to(ally["pos"]) > radius_squared:
					continue
				# Refreshing an active haste extends it; it never stacks.
				if float(ally.get("haste_multiplier", 1.0)) == 1.0:
					ally["base_speed"] = float(ally["base_speed"]) * float(config["multiplier"])
					ally["haste_multiplier"] = float(config["multiplier"])
				ally["haste_until"] = _elapsed + float(config["duration"])
				ally["haste_remaining"] = float(config["duration"])
				_prepare_motion(ally)
			mage["spell_effect"] = effect
		"soulfire":
			var aim: Vector2 = mage["spell_aim"]
			effect["to"] = aim
			for tower: Dictionary in towers[slot]:
				if cell_in_range(Vector2i(aim), tower["cell"], float(config["radius"])):
					tower["withered_until"] = maxf(float(tower["withered_until"]), _elapsed + float(config["duration"]))
					tower["wither"] = float(config["wither"])
					tower["wither_remaining"] = float(tower["withered_until"]) - _elapsed
			_refresh_board(slot)
			mage["spell_effect"] = effect
			_sound_events.record(CombatSoundEvents.Cue.EXPLOSION, slot, aim, _death_time)
		"raise_dead":
			var risen: Array[Vector2] = []
			var candidates: Array[Dictionary] = _risen_candidates(slot, mage, config)
			for record: Dictionary in candidates:
				var route: Array[Vector2i] = []
				route.assign(record["route"])
				_spawn_enemy(slot, String(config["type"]), minf(float(record["progress"]), float(route.size() - 1) - 0.5), _elapsed, route, int(mage["id"]))
				_fallen[slot].erase(record)
				risen.append(record["pos"])
			effect["from"] = risen
			mage["spell_effect"] = effect
			_sound_events.record(CombatSoundEvents.Cue.BONES, slot, mage["pos"], _death_time)
		"barrier":
			mage["shield_hits"] = int(config["hits"])
			mage["shield_max_hits"] = int(config["hits"])
			mage["hp"] = mini(int(mage["max_hp"]), int(mage["hp"]) + maxi(1, ceili(float(mage["max_hp"]) * float(config["heal"]))))
			mage["barriers"] = int(mage["barriers"]) + 1
			mage["spell_effect"] = effect
	mage["spell"] = ""
	mage["spell_phase"] = ""
	mage["animation"] = "walk"
	mage["animation_elapsed"] = 0.0
	mage["next_spell"] = float(mage["age"]) + float(book["glide"])
	BossMechanics.prepare(mage)


# The tower cell with the most towers within the radius; ties keep the oldest tower.
func _densest_tower_cell(slot: int, radius: float) -> Vector2:
	var best: Dictionary = towers[slot][0]
	var best_count: int = -1
	for tower: Dictionary in towers[slot]:
		var count: int = 0
		for other: Dictionary in towers[slot]:
			count += int(cell_in_range(tower["cell"], other["cell"], radius))
		if count > best_count:
			best = tower
			best_count = count
	return Vector2(best["cell"])


# The most recent fallen within reach, newest first.
func _risen_candidates(slot: int, caster: Dictionary, config: Dictionary) -> Array[Dictionary]:
	var radius_squared: float = float(config["radius"]) * float(config["radius"])
	var result: Array[Dictionary] = []
	for index: int in range(_fallen[slot].size() - 1, -1, -1):
		var record: Dictionary = _fallen[slot][index]
		if float(record["time"]) < _elapsed - float(config["window"]) or Vector2(record["pos"]).distance_squared_to(caster["pos"]) > radius_squared:
			continue
		result.append(record)
		if result.size() >= int(config["count"]):
			break
	return result


# Rearmost living, walking non-boss orcs that are well behind the portal exit.
func _portal_passengers(slot: int, mage: Dictionary, count: int) -> Array[Dictionary]:
	var front: float = float(mage["progress"]) + Spellbook.PORTAL_LEAD
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies[slot]:
		if enemy["id"] == mage["id"] or int(enemy["hp"]) <= 0 or _enemy_types[enemy["type_id"]]["boss"] or not BossMechanics.can_act(enemy):
			continue
		if float(_enemy_spawn_times[enemy["id"]]) > _elapsed + 0.000000001 or float(enemy["progress"]) >= minf(front, float(enemy["route"].size() - 1) - 0.5) - 1.0:
			continue
		result.append(enemy)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["progress"]) < float(b["progress"]) or (float(a["progress"]) == float(b["progress"]) and int(a["id"]) < int(b["id"])))
	return result.slice(0, count)


# Stunned orcs stay put whatever their base speed becomes.
func _prepare_motion(enemy: Dictionary) -> void:
	BossMechanics.prepare(enemy)
	if float(enemy["stunned_remaining"]) > 0.000000001:
		enemy["speed"] = 0.0


# A slain Grand Mage's last swing: a long stun on the board's most valuable tower.
func _death_bolt(slot: int, enemy: Dictionary, definition: Dictionary) -> void:
	var bolt: Dictionary = definition["spellbook"].get("death_bolt", NO_BONUS)
	if bolt.is_empty() or towers[slot].is_empty():
		return
	var target: Dictionary = towers[slot][0]
	for tower: Dictionary in towers[slot]:
		var value := Vector2i(int(tower["invested"]), int(tower["damage_dealt"]))
		var best := Vector2i(int(target["invested"]), int(target["damage_dealt"]))
		if value.x > best.x or (value.x == best.x and (value.y > best.y or (value.y == best.y and int(tower["id"]) < int(target["id"])))):
			target = tower
	_stun_tower(slot, target, float(bolt["stun"]), "death_bolt", enemy["pos"])
	enemy["death_bolt_to"] = Vector2(target["cell"])
	_refresh_board(slot)
	_update_bounties(slot)


func _cast_ward(slot: int, caster: Dictionary, definition: Dictionary) -> void:
	caster["next_ward"] += float(definition["ward_interval"])
	caster["ward_count"] += 1
	caster["animation"] = "heal"
	caster["animation_elapsed"] = 0.0
	var radius_squared: float = float(definition["ward_radius"]) * float(definition["ward_radius"])
	for ally: Dictionary in enemies[slot]:
		var type: Dictionary = _enemy_types[ally["type_id"]]
		if ally["id"] == caster["id"] or int(ally["hp"]) <= 0 or type["boss"] or float(type["ward_interval"]) > 0.0:
			continue
		if Vector2(caster["pos"]).distance_squared_to(ally["pos"]) <= radius_squared:
			ally["ward_until"] = _elapsed + float(definition["ward_duration"])
			ally["ward_source"] = caster["id"]
			ally["warded"] = true


# OrcShakra casters charge heals faster near their own kind; others keep a fixed schedule.
func _heal_due(slot: int, enemy: Dictionary, definition: Dictionary) -> bool:
	if float(definition["shakra_radius"]) <= 0.0:
		if float(enemy["age"]) + 0.000000001 < float(enemy["next_heal"]):
			return false
		enemy["next_heal"] += float(definition["heal_interval"])
		return true
	var rate: float = 1.0 + _shakra_bonus(slot, enemy, definition)
	enemy["heal_charge"] = float(enemy["heal_charge"]) + (float(enemy["age"]) - float(enemy["heal_clock"])) * rate
	enemy["heal_clock"] = enemy["age"]
	if float(enemy["heal_charge"]) + 0.000000001 < float(definition["heal_interval"]):
		return false
	enemy["heal_charge"] = float(enemy["heal_charge"]) - float(definition["heal_interval"])
	return true


func _heal_wait(slot: int, enemy: Dictionary, definition: Dictionary) -> float:
	if float(definition["shakra_radius"]) <= 0.0:
		return float(enemy["next_heal"]) - float(enemy["age"])
	var rate: float = 1.0 + _shakra_bonus(slot, enemy, definition)
	var charged: float = float(enemy["heal_charge"]) + (float(enemy["age"]) - float(enemy["heal_clock"])) * rate
	return maxf(0.000000001, (float(definition["heal_interval"]) - charged) / rate)


func _shakra_bonus(slot: int, enemy: Dictionary, definition: Dictionary) -> float:
	var radius_squared: float = float(definition["shakra_radius"]) * float(definition["shakra_radius"])
	var neighbours: int = 0
	for other: Dictionary in enemies[slot]:
		if other["id"] != enemy["id"] and other["type_id"] == enemy["type_id"] and int(other["hp"]) > 0 and Vector2(enemy["pos"]).distance_squared_to(other["pos"]) <= radius_squared:
			neighbours += 1
	var bonus: float = float(definition["shakra_max_bonus"]) * (1.0 - pow(0.5, neighbours))
	enemy["shakra_bonus"] = bonus
	return bonus


# Ordinary enemies only need a substep when a ready weapon can acquire them.
# Splitting on every mob's every cell while a boss exists makes a horde impose
# O(enemies) full-board simulation passes per second, including empty attacks.
func _next_attack_entry(slot: int, enemy: Dictionary, definition: Dictionary, maximum: float) -> float:
	var progress: float = enemy["progress"]
	var speed: float = enemy["speed"]
	var route: Array = enemy["route"]
	var last: int = route.size() - 1
	var duration: float = minf(maximum, maxf(0.000000001, (float(last) - progress) / speed))
	var next_index: int = floori(progress + 0.5 + 0.000000001) + 1
	while next_index <= last:
		# Move past direction-dependent half-cell rounding ties.
		var boundary: float = minf(float(last), float(next_index) - 0.5 + 0.00000001)
		var until_entry: float = maxf(0.000000001, (boundary - progress) / speed)
		if until_entry >= duration:
			break
		if definition["boss"]:
			return until_entry
		for tower: Dictionary in towers[slot]:
			if float(tower["stunned_remaining"]) > 0.000000001 or float(tower["cooldown"]) > 0.000000001 or tower["behavior_kind"] not in ["attack", "chain"]:
				continue
			var type: Dictionary = _tower_types[tower["type_id"]]
			var weapon: String = type["advancements"].get(tower["advancement"], {}).get("weapon", "arrow")
			# Continuous attacks already integrate entry/exposure historically.
			if weapon == "flamethrower" or (type["area_attack"] and type["evolutions"].get(tower["evolution"], {}).get("continuous", false)):
				continue
			if cell_in_range(tower["cell"], route[next_index], tower["range"]):
				return until_entry
		next_index += 1
	return duration


func _requires_combat_events(definition: Dictionary, wave_number: int = 0) -> bool:
	if BossMechanics.has_abilities(definition) or not definition["spellbook"].is_empty() or float(definition["phase_interval"]) > 0.0 or int(definition["hit_shield"]) > 0 or float(definition["death_stun_duration"]) > 0.0 or float(definition["death_bomb_fuse"]) > 0.0:
		return true
	var variant: String = definition["spawn_variant"]
	var birth_wave: int = wave if wave_number == 0 else wave_number
	return not variant.is_empty() and birth_wave >= int(definition["spawn_variant_first_wave"]) and _requires_combat_events(_enemy_types[variant], birth_wave)


func _shield_event_step(slot: int, enemy: Dictionary, maximum: float) -> float:
	var duration: float = maximum
	if int(enemy["shield_hits"]) <= 0 and not _shield_exposure.has(int(enemy["id"])) and float(_enemy_types[enemy["type_id"]]["death_stun_duration"]) <= 0.0 and float(_enemy_types[enemy["type_id"]]["death_bomb_fuse"]) <= 0.0:
		return duration
	var speed: float = enemy["speed"]
	if speed > 0.0:
		var boundary: float = floorf(float(enemy["progress"]) + 0.5 + 0.000000001) + 0.5 + 0.00000001
		duration = minf(duration, maxf(0.000000001, (boundary - float(enemy["progress"])) / speed))
	var streams: Dictionary = _shield_exposure.get(int(enemy["id"]), NO_BONUS)
	for tower: Dictionary in towers[slot]:
		if float(tower["stunned_remaining"]) > 0.000000001 or _silenced(slot, tower):
			continue
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var flame: bool = definition["advancements"].get(tower["advancement"], {}).get("weapon", "") == "flamethrower"
		var rune: bool = definition["area_attack"] and definition["evolutions"].get(tower["evolution"], {}).get("continuous", false)
		if not flame and not rune:
			continue
		if not cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), tower["range"]):
			continue
		var protected: float = float(streams.get(int(tower["id"]), 0.0))
		if protected > 0.000000001:
			duration = minf(duration, protected)
		elif int(enemy["shield_hits"]) > 0:
			duration = minf(duration, _shield_contact_interval(tower))
	return duration


func _shield_contact_interval(tower: Dictionary) -> float:
	var interval: float = tower["interval"]
	if interval > 0.0:
		return interval
	# Continuous Rune evolutions intentionally publish interval=0: their DPS
	# still inherits the base attack cadence and accepted speed modifiers.
	return float(_tower_types[tower["type_id"]]["interval"]) / float(tower["speed_multiplier"])


# One accepted positive-exposure interval is one contact. Its entire exposure
# is absorbed, including the tenth contact; no HP fraction or mark credit accrues.
func _shield_continuous_exposure(enemy: Dictionary, source_id: int, exposure: float, interval: float, positive_rate: float) -> float:
	if exposure <= 0.0 or positive_rate <= 0.0:
		return 0.0
	var id: int = enemy["id"]
	if int(enemy["shield_hits"]) <= 0 and not _shield_exposure.has(id):
		return exposure
	if not _shield_exposure.has(id):
		_shield_exposure[id] = {}
	var streams: Dictionary = _shield_exposure[id]
	var protected: float = float(streams.get(source_id, 0.0))
	var remaining: float = exposure
	while remaining > 0.000000001:
		if protected <= 0.000000001:
			if not EnemyMechanics.absorb_hit(enemy, positive_rate):
				break
			protected = maxf(0.000000001, interval)
		var absorbed: float = minf(remaining, protected)
		protected = maxf(0.0, protected - absorbed)
		remaining = maxf(0.0, remaining - absorbed)
	if protected > 0.000000001:
		streams[source_id] = protected
	else:
		streams.erase(source_id)
	if streams.is_empty():
		_shield_exposure.erase(id)
	return remaining


func _wave_cleared() -> bool:
	return _spawned[0] == wave_roster.size() and _spawned[1] == wave_roster.size() and _pending_sends(0) == 0 and _pending_sends(1) == 0 and enemies[0].is_empty() and enemies[1].is_empty() and flights.is_empty() and bombs.is_empty()


func _advance_bombs() -> void:
	for index: int in range(bombs.size() - 1, -1, -1):
		var bomb: Dictionary = bombs[index]
		bomb["fuse_remaining"] = maxf(0.0, float(bomb["fuse_duration"]) - (_death_time - float(bomb["time"])))
		if float(bomb["fuse_remaining"]) > 0.000000001:
			continue
		bombs.remove_at(index)
		var slot: int = bomb["slot"]
		var origin := Vector2i(Vector2(bomb["pos"]).round())
		var duration: float = bomb["stun_duration"]
		for tower: Dictionary in towers[slot]:
			if cell_in_square(origin, tower["cell"], float(bomb["radius"])):
				_stun_tower(slot, tower, duration, "giant_skeltorc_bomb", bomb["pos"])
		for enemy: Dictionary in enemies[slot]:
			if int(enemy["hp"]) <= 0 or not cell_in_square(origin, Vector2i(Vector2(enemy["pos"]).round()), float(bomb["radius"])):
				continue
			enemy["stunned_remaining"] = maxf(float(enemy["stunned_remaining"]), duration)
			enemy["stun_count"] += 1
			enemy["stun_source"] = "giant_skeltorc_bomb"
			enemy["stun_position"] = bomb["pos"]
			enemy["speed"] = 0.0
		_refresh_board(slot)
		_update_bounties(slot)
		_bomb_explosions.append({
			"id": bomb["id"], "slot": slot, "pos": bomb["pos"],
			"radius": bomb["radius"], "stun_duration": duration, "time": _death_time,
		})


func _death_stun_event_step(slot: int, enemy: Dictionary, maximum: float) -> float:
	if int(enemy["shield_hits"]) > 0:
		return maximum
	_death_rates.clear()
	_death_fractions.clear()
	var id: int = enemy["id"]
	var streams: Dictionary = _shield_exposure.get(id, NO_BONUS)
	var burn_rate: float = 0.0
	var burn_fraction: float = 0.0
	var duration: float = maximum
	if _burns.has(id):
		var burn: Dictionary = _burns[id]
		burn_rate = float(burn["dps"]) * _damage_multiplier(enemy, &"fire")
		burn_fraction = float(burn["fraction"])
		duration = minf(duration, maxf(0.000000001, float(burn["end_time"]) - _elapsed))
	for tower: Dictionary in towers[slot]:
		if float(tower["stunned_remaining"]) > 0.000000001 or _silenced(slot, tower) or float(streams.get(int(tower["id"]), 0.0)) > 0.000000001:
			continue
		if not cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), tower["range"]):
			continue
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var config: Dictionary = definition["advancements"].get(tower["advancement"], {})
		var rate: float = 0.0
		if config.get("weapon", "") == "flamethrower":
			if bool(enemy["fire_immune"]):
				continue
			if float(tower["refuel_remaining"]) > 0.000000001:
				duration = minf(duration, float(tower["refuel_remaining"]))
				continue
			var selected: int = _target(slot, tower, tower["range"], -1, -1, -1, -1, -1.0, true)
			if selected < 0:
				continue
			var share: float = 1.0
			if int(enemies[slot][selected]["id"]) != id:
				# A scorched neighbour of the stream's target takes its share.
				var scorch: float = float(config.get("scorch_radius", 0.0))
				if scorch <= 0.0 or Vector2(enemy["pos"]).distance_squared_to(enemies[slot][selected]["pos"]) > scorch * scorch:
					continue
				share = float(config["scorch_fraction"])
			duration = minf(duration, maxf(0.000000001, float(config["fuel_duration"]) - float(tower["continuous_fire_time"])))
			rate = float(config["continuous_dps"]) * share * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"]) * _damage_multiplier(enemy, &"fire")
			burn_rate = maxf(burn_rate, float(config["burn_dps"]) * float(tower["damage_multiplier"]) * _damage_multiplier(enemy, &"fire"))
		elif definition["area_attack"] and definition["evolutions"].get(tower["evolution"], {}).get("continuous", false):
			# Ignoring the tendril limit can only overestimate, which shortens the step.
			rate = (float(tower["base_damage"]) * float(tower["speed_multiplier"]) * float(tower["damage_multiplier"]) + _drain_per_second(tower, enemy)) * _damage_multiplier(enemy, _tower_damage_type(tower))
		if rate > 0.0:
			var fractions: Dictionary = _continuous_damage.get(int(tower["id"]), NO_BONUS)
			_death_rates.append(rate)
			_death_fractions.append(float(fractions.get(id, 0.0)))
	if burn_rate > 0.0:
		_death_rates.append(burn_rate)
		_death_fractions.append(burn_fraction)
	if _continuous_lethal_damage(duration) < int(enemy["hp"]):
		return duration
	var low: float = 0.0
	var high: float = duration
	for iteration: int in range(40):
		var middle: float = (low + high) * 0.5
		if _continuous_lethal_damage(middle) >= int(enemy["hp"]):
			high = middle
		else:
			low = middle
	return maxf(0.000000001, high)


func _continuous_lethal_damage(duration: float) -> int:
	var damage: int = 0
	for index: int in range(_death_rates.size()):
		damage += floori(_death_fractions[index] + _death_rates[index] * duration + 0.000000001)
	return damage


func _has_periodic_production() -> bool:
	for board: Array in towers:
		for tower: Dictionary in board:
			if _periodic_amount(tower) > 0:
				return true
	return false


# Coins (Gold Mine/Royal Mint) or Shards (Crystal Mine) produced per cycle.
static func _periodic_amount(tower: Dictionary) -> int:
	match String(tower["behavior_kind"]):
		"economy":
			return int(tower["behavior_config"]["periodic_income"])
		"crystal":
			return int(tower["behavior_config"]["periodic_shards"])
	return 0


func _produce_periodic(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		if _periodic_amount(tower) <= 0 or float(tower["stunned_remaining"]) > 0.000000001:
			continue
		var config: Dictionary = tower["behavior_config"]
		tower["production_elapsed"] += delta
		var count: int = floori((float(tower["production_elapsed"]) + 0.000000001) / float(config["periodic_interval"]))
		if count > 0:
			tower["production_elapsed"] = maxf(0.0, float(tower["production_elapsed"]) - count * float(config["periodic_interval"]))
			var produced: int = count * _periodic_amount(tower)
			if tower["behavior_kind"] == "crystal":
				reroll_currency[slot] += produced
				tower["shards_generated"] += produced
				_recap.add(slot, "earned", "production_shards", produced)
			else:
				coins[slot] += produced
				tower["coins_generated"] += produced
				_recap.add(slot, "earned", "production_coins", produced)


func _update_bounties(slot: int) -> void:
	for tower: Dictionary in towers[slot]:
		if tower["behavior_kind"] != "bounty" or float(tower["stunned_remaining"]) > 0.000000001 or int(tower["bounty_target_id"]) >= 0:
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
		if source["behavior_kind"] == "income_aura" and float(source["stunned_remaining"]) <= 0.000000001 and cell_in_range(source["cell"], tower["cell"], source["range"]):
			var bonus: float = source["behavior_config"]["kill_income_bonus"]
			if bonus > strongest:
				selected = source
				strongest = bonus
	return selected


func _enemy_abilities(slot: int) -> void:
	# Reuse a shallow reference pass: summons wait until the next pass, and a
	# stomp may retire any other caster without shifting this traversal.
	var active: Array = _ability_pass[slot]
	active.clear()
	active.append_array(enemies[slot])
	for enemy: Dictionary in active:
		var phasing: float = float(_enemy_types[enemy["type_id"]]["phase_interval"])
		if phasing > 0.0:
			enemy["ethereal"] = int(floorf((float(enemy["age"]) + 0.000000001) / phasing)) % 2 == 1
		enemy["ward_remaining"] = maxf(0.0, float(enemy.get("ward_until", 0.0)) - _elapsed)
		enemy["warded"] = float(enemy["ward_remaining"]) > 0.000000001
		if enemy.has("haste_until"):
			enemy["haste_remaining"] = maxf(0.0, float(enemy["haste_until"]) - _elapsed)
			if float(enemy["haste_remaining"]) <= 0.000000001 and float(enemy["haste_multiplier"]) != 1.0:
				enemy["base_speed"] = float(enemy["base_speed"]) / float(enemy["haste_multiplier"])
				enemy["haste_multiplier"] = 1.0
				_prepare_motion(enemy)
	for enemy: Dictionary in active:
		if int(enemy["hp"]) <= 0 or float(enemy["stunned_remaining"]) > 0.000000001 or (float(enemy["progress"]) >= enemy["route"].size() - 1 and BossMechanics.can_act(enemy)):
			continue
		var definition: Dictionary = _enemy_types[enemy["type_id"]]
		if float(definition["ward_interval"]) > 0.0 and float(enemy["age"]) + 0.000000001 >= float(enemy["next_ward"]):
			_cast_ward(slot, enemy, definition)
		if not definition["spellbook"].is_empty():
			_advance_spellbook(slot, enemy, definition["spellbook"])
		if BossMechanics.has_abilities(definition):
			_boss_abilities(slot, enemy, definition)
			if int(enemy["hp"]) <= 0 or float(enemy["progress"]) >= enemy["route"].size() - 1:
				continue
		if enemy["animation"] == "heal" and float(enemy["animation_elapsed"]) >= 0.55:
			enemy["animation"] = "walk"
			enemy["animation_elapsed"] = 0.0
		EnemyMechanics.advance(enemy, definition)
		if float(definition["heal_interval"]) > 0.0 and _heal_due(slot, enemy, definition):
			enemy["heal_count"] += 1
			if definition["heal_restores_shield"]:
				enemy["shield_hits"] = enemy["shield_max_hits"]
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
		elif float(enemy["age"]) + 0.000000001 >= float(enemy["next_summon"]) and float(enemy["tower_attack_remaining"]) <= 0.000000001 and BossMechanics.can_act(enemy):
			enemy["next_summon"] += float(definition["summon_interval"])
			enemy["cast_remaining"] = definition["summon_cast_duration"]
			enemy["animation"] = "cast"
			enemy["animation_elapsed"] = 0.0
			enemy["speed"] = 0.0
			if float(definition["jump_interval"]) > 0.0:
				_sound_events.record(CombatSoundEvents.Cue.MACHINE_DOOR, slot, enemy["pos"], _death_time)


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
	var child_route: Array[Vector2i] = caster["route"]
	var child_progress: float = caster["progress"]
	for member: int in range(count):
		_spawn_enemy(slot, _summon_type(definition), child_progress, _elapsed, child_route, caster["id"])


func _summon_type(definition: Dictionary) -> String:
	var pool: PackedStringArray = definition["summon_pool"]
	if pool.is_empty():
		return String(definition["summon_type"])
	var weights: PackedInt32Array = definition["summon_weights"]
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll: int = _group_random.randi_range(1, total)
	for index: int in range(pool.size()):
		roll -= weights[index]
		if roll <= 0:
			return pool[index]
	assert(false, "Admitted summon weights must resolve a child")
	return ""


func _prepare_boss_motion(slot: int) -> void:
	for enemy: Dictionary in enemies[slot]:
		if float(enemy["stunned_remaining"]) <= 0.000000001 and BossMechanics.has_abilities(_enemy_types[enemy["type_id"]]):
			BossMechanics.prepare(enemy)


func _jump_phase(enemy: Dictionary, phase_name: String, duration: float) -> void:
	enemy["locomotion"] = phase_name
	enemy["animation"] = "walk" if phase_name == "wheels" else phase_name
	enemy["animation_elapsed"] = 0.0
	enemy["jump_remaining"] = duration
	BossMechanics.prepare(enemy)


func _begin_jump(slot: int, enemy: Dictionary, definition: Dictionary) -> void:
	enemy["next_jump"] = float(enemy["age"]) + float(definition["jump_interval"])
	var remaining: float = float(enemy["route"].size() - 1) - float(enemy["progress"])
	var weights: PackedInt32Array = definition["jump_weights"]
	var total: int = 0
	for index: int in range(weights.size()):
		if float(index + 2) <= remaining + 0.000000001:
			total += weights[index]
	if total <= 0:
		return
	var roll: int = _group_random.randi_range(1, total)
	for index: int in range(weights.size()):
		if float(index + 2) > remaining + 0.000000001:
			break
		roll -= weights[index]
		if roll <= 0:
			enemy["jump_distance"] = index + 2
			break
	enemy["jump_from"] = enemy["pos"]
	enemy["jump_target_progress"] = minf(float(enemy["route"].size() - 1), float(enemy["progress"]) + int(enemy["jump_distance"]))
	enemy["jump_to"] = _position(enemy["route"], enemy["jump_target_progress"])
	_jump_phase(enemy, "jump_deploy", definition["jump_deploy_duration"])
	_sound_events.record(CombatSoundEvents.Cue.MACHINE_GEAR, slot, enemy["pos"], _death_time)


func _boss_abilities(slot: int, enemy: Dictionary, definition: Dictionary) -> void:
	if not BossMechanics.can_act(enemy) and float(enemy["jump_remaining"]) <= 0.000000001:
		match String(enemy["locomotion"]):
			"jump_deploy":
				_jump_phase(enemy, "jump_charge", definition["jump_charge_duration"])
			"jump_charge":
				enemy["jump_count"] += 1
				_jump_phase(enemy, "jump", definition["jump_duration"])
				_sound_events.record(CombatSoundEvents.Cue.MACHINE_JUMP, slot, enemy["pos"], _death_time)
			"jump":
				enemy["progress"] = enemy["jump_target_progress"]
				enemy["pos"] = enemy["jump_to"]
				_enemies_relocated(slot)
				_jump_phase(enemy, "jump_land", definition["jump_land_duration"])
			"jump_land":
				_jump_phase(enemy, "wheels", 0.0)
	if float(enemy["progress"]) >= enemy["route"].size() - 1:
		return
	if enemy["animation"] == "attack" and float(enemy["tower_attack_remaining"]) <= 0.000000001:
		var kind: String = definition["tower_attack_kind"]
		_sound_events.record(CombatSoundEvents.Cue.CANNON if kind == "cannon" else CombatSoundEvents.Cue.CLUB_IMPACT, slot, enemy["pos"], _death_time)
		for target_id: int in enemy["tower_attack_target_ids"]:
			var target: Dictionary = _find_tower(slot, target_id)
			if target.is_empty():
				continue
			_stun_tower(slot, target, float(definition["tower_stun_duration"]), kind, enemy["pos"])
		_refresh_board(slot)
		_update_bounties(slot)
		enemy["animation"] = "walk"
		enemy["animation_elapsed"] = 0.0
		BossMechanics.prepare(enemy)
	if float(definition["jump_interval"]) > 0.0 and float(enemy["age"]) + 0.000000001 >= float(enemy["next_jump"]) and BossMechanics.can_act(enemy) and enemy["animation"] not in ["cast", "attack"]:
		_begin_jump(slot, enemy, definition)
	if float(definition["stomp_interval"]) > 0.0 and float(enemy["age"]) + 0.000000001 >= float(enemy["next_stomp"]):
		enemy["next_stomp"] += float(definition["stomp_interval"])
		if bool(enemy["stepped"]) and enemy["animation"] == "walk":
			enemy["stomp_count"] += 1
			_sound_events.record(CombatSoundEvents.Cue.TROLL_STOMP, slot, enemy["pos"], _death_time)
			var radius_squared: float = float(definition["stomp_radius"]) * float(definition["stomp_radius"])
			for index: int in range(enemies[slot].size() - 1, -1, -1):
				var victim: Dictionary = enemies[slot][index]
				if victim["id"] == enemy["id"] or int(victim["hp"]) <= 0 or Vector2(enemy["pos"]).distance_squared_to(victim["pos"]) > radius_squared:
					continue
				if EnemyMechanics.absorb_hit(victim, maxi(1, ceili(float(victim["max_hp"]) * float(definition["stomp_health_fraction"])))):
					continue
				victim["hp"] = maxi(0, int(victim["hp"]) - maxi(1, ceili(float(victim["max_hp"]) * float(definition["stomp_health_fraction"]))))
				EnemyMechanics.after_damage(victim, _enemy_types[victim["type_id"]])
				if int(victim["hp"]) == 0:
					_record_death(slot, victim)
					_retire_enemy(int(victim["id"]))
					enemies[slot].remove_at(index)
	if float(definition["tower_attack_interval"]) <= 0.0 or float(enemy["age"]) + 0.000000001 < float(enemy["next_tower_attack"]) or enemy["animation"] in ["cast", "attack"] or not BossMechanics.can_act(enemy):
		return
	enemy["next_tower_attack"] = float(enemy["age"]) + float(definition["tower_attack_interval"])
	var target_ids: Array[int] = enemy["tower_attack_target_ids"]
	var aims: Array[Vector2] = enemy["tower_attack_aims"]
	target_ids.clear()
	aims.clear()
	if definition["tower_attack_kind"] == "cannon":
		for shot: int in range(mini(int(definition["tower_attack_targets"]), towers[slot].size())):
			var rank: int = _group_random.randi_range(0, towers[slot].size() - target_ids.size() - 1)
			for tower: Dictionary in towers[slot]:
				if target_ids.has(int(tower["id"])):
					continue
				if rank == 0:
					target_ids.append(int(tower["id"]))
					aims.append(Vector2(tower["cell"]))
					break
				rank -= 1
	else:
		var nearest: Dictionary = {}
		var distance: float = float(definition["tower_attack_range"]) * float(definition["tower_attack_range"])
		for tower: Dictionary in towers[slot]:
			var candidate: float = Vector2(enemy["pos"]).distance_squared_to(Vector2(tower["cell"]))
			if candidate < distance or (candidate == distance and (nearest.is_empty() or int(tower["id"]) < int(nearest["id"]))):
				nearest = tower
				distance = candidate
		if not nearest.is_empty():
			target_ids.append(int(nearest["id"]))
			aims.append(Vector2(nearest["cell"]))
	if target_ids.is_empty():
		return
	enemy["tower_attack_count"] += 1
	enemy["tower_attack_remaining"] = definition["tower_attack_cast_duration"]
	enemy["animation"] = "attack"
	enemy["animation_elapsed"] = 0.0
	enemy["speed"] = 0.0


func snapshot(include_metadata: bool = true) -> Dictionary:
	var result: Dictionary = {
		"phase": phase, "wave": wave, "health": base_health.duplicate(), "max_health": base_max_health.duplicate(),
		"statistics_id": statistics_id, "enemy_totals": enemy_totals.duplicate(true),
		"recap": _recap.snapshot(_death_time) if phase == Phase.FINISHED else {},
		"winner": winner, "coin_flip": coin_flip,
		"coins": coins.duplicate(),
		"reroll_currency": reroll_currency.duplicate(),
		"income": income.duplicate(), "queued_sends": queued_sends, "queued_send_orders": queued_send_orders,
		"send_queues": [_send_queues[0].slice(_send_heads[0]), _send_queues[1].slice(_send_heads[1])],
		"towers": towers.duplicate(true), "enemies": enemies.duplicate(true),
		"flights": flights.duplicate(true), "flight_duration": FLIGHT_DURATION,
		"bombs": bombs.duplicate(true), "bomb_explosions": _bomb_explosions.duplicate(true),
		"magic_nullified": [maxf(0.0, _magic_nullified_until[0] - _elapsed), maxf(0.0, _magic_nullified_until[1] - _elapsed)],
		"deaths": [_death_snapshot(0), _death_snapshot(1)], "death_time": _death_time,
		"death_generation": _death_generation,
		"sounds": _sound_events.snapshot(_death_time),
		"boss_rewards": [_boss_loot.awards(0), _boss_loot.awards(1)],
		"spawned": _spawned.duplicate(), "total": wave_roster.size(),
		"wave_weight": _wave_weight(maxi(1, wave)),
	}
	if not include_metadata:
		return result
	result["wave_groups"] = wave_groups.duplicate(true)
	result["enemy_types"] = _enemy_types_snapshot()
	result["wave_roster"] = wave_roster.duplicate()
	result["spawn_times"] = spawn_times.duplicate()
	result["tower_types"] = _tower_types.duplicate(true)
	result["rules"] = {
			"enemy_speed": _wave_speed(wave), "enemy_health": _wave_health(wave),
			"sandbox_mode": _sandbox_mode,
			"roll_rules_enabled": _roll_rules != null,
			"clear_reroll_currency": _rules.clear_reroll_currency,
			"starting_coins": _rules.starting_coins, "kill_bounty": _rules.kill_bounty,
			"wave_reward": _rules.wave_reward + maxi(1, wave) * _rules.wave_reward_growth,
			"base_health": _rules.base_health,
			"send_spawn_interval": _send_spawn_interval * _spawn_interval_multiplier(wave + 1) if phase == Phase.PLANNING else _active_send_spawn_interval,
			"send_queue_limit": SEND_QUEUE_LIMIT,
			"main_round_interval": _rules.main_round_interval,
			"ready_window_seconds": _rules.ready_window_seconds,
			"tiles_per_expansion": _rules.tiles_per_expansion,
	}
	return result


func _enemy_types_snapshot() -> Dictionary:
	var result: Dictionary = _enemy_types.duplicate(true)
	var preview_wave: int = wave + 1 if phase == Phase.PLANNING else wave
	for type_id: String in result:
		result[type_id]["health"] = _enemy_health(type_id, preview_wave)
		result[type_id]["speed"] = _enemy_speed(type_id, preview_wave)
		result[type_id]["send_available"] = bool(result[type_id]["send_enabled"]) and preview_wave >= int(result[type_id]["send_first_wave"])
	return result


static func enemy_preview(definition: EnemyDefinition, rules: CombatRules, wave_number: int = 1) -> Dictionary:
	var health: int = maxi(1, ceili(float(rules.enemy_health + maxi(0, wave_number - 1) * rules.health_growth) * definition.health_multiplier))
	if definition.health_base_type != &"" and rules.catalog != null:
		for base: EnemyDefinition in rules.catalog.enemies:
			if base.id == definition.health_base_type:
				health = int(enemy_preview(base, rules, wave_number)["max_hp"]) * definition.health_base_multiplier
				break
	return {
		"max_hp": health,
		"speed": rules.enemy_speed_at_wave(wave_number) * definition.speed_multiplier,
		"base_damage": definition.base_damage,
		"fire_immune": definition.fire_immune, "ice_immune": definition.ice_immune,
		"nonphysical_damage_multiplier": definition.nonphysical_damage_multiplier,
		"fire_damage_multiplier": definition.fire_damage_multiplier,
		"lightning_damage_multiplier": definition.lightning_damage_multiplier,
		"boss": definition.boss, "send_enabled": definition.send_enabled,
		"jump_interval": definition.jump_interval,
		"burning": false, "burn_remaining": 0.0,
		"shield_hits": definition.hit_shield, "shield_max_hits": definition.hit_shield, "shield_hit_count": 0,
		"stunned_remaining": 0.0, "stun_count": 0, "stun_source": "",
	}


func _enemy_health(type_id: String, wave_number: int) -> int:
	var definition: Dictionary = _enemy_types[type_id]
	if not String(definition["health_base_type"]).is_empty():
		return _enemy_health(String(definition["health_base_type"]), wave_number) * int(definition["health_base_multiplier"])
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


func _enemies_relocated(slot: int) -> void:
	_target_grid_valid[slot] = false
	_cell_versions[slot] += 1


func _move_enemies(slot: int, delta: float) -> void:
	# Targeting buckets and empty-range memos depend only on rounded cells.
	var relocated: bool = false
	for enemy: Dictionary in enemies[slot]:
		if float(enemy["stunned_remaining"]) > 0.000000001:
			if not _slow_motion.has(enemy["id"]):
				_slow_motion[enemy["id"]] = [0.0, 0.0, 0.0, 0.0]
			var stationary: Array = _slow_motion[enemy["id"]]
			stationary[0] = float(enemy["progress"])
			stationary[1] = delta
			stationary[2] = 0.0
			stationary[3] = 0.0
			enemy["stunned_remaining"] = maxf(0.0, float(enemy["stunned_remaining"]) - delta)
			enemy["slow_remaining"] = maxf(0.0, float(enemy["slow_remaining"]) - delta)
			enemy["slowed"] = float(enemy["slow_remaining"]) > 0.000000001
			enemy["speed"] = 0.0
			if float(enemy["stunned_remaining"]) <= 0.000000001:
				enemy["stunned_remaining"] = 0.0
				enemy["stun_source"] = ""
				BossMechanics.prepare(enemy)
			continue
		enemy["age"] += delta
		enemy["animation_elapsed"] += delta
		var previous_progress: float = enemy["progress"]
		var casting: bool = float(enemy["cast_remaining"]) > 0.0 or float(enemy["tower_attack_remaining"]) > 0.0
		enemy["tower_attack_remaining"] = maxf(0.0, float(enemy["tower_attack_remaining"]) - delta)
		enemy["cast_remaining"] = maxf(0.0, float(enemy["cast_remaining"]) - delta)
		var base_speed: float = enemy["base_speed"]
		var slowed_seconds: float = minf(delta, float(enemy["slow_remaining"]))
		if not BossMechanics.can_act(enemy):
			if not _slow_motion.has(enemy["id"]):
				_slow_motion[enemy["id"]] = [0.0, 0.0, 0.0, 0.0]
			var jump_motion: Array = _slow_motion[enemy["id"]]
			jump_motion[0] = previous_progress
			jump_motion[1] = delta
			jump_motion[2] = enemy["speed"]
			jump_motion[3] = enemy["speed"]
			if enemy["locomotion"] == "jump":
				enemy["progress"] = minf(float(enemy["jump_target_progress"]), previous_progress + float(enemy["speed"]) * delta)
			enemy["slow_remaining"] = maxf(0.0, float(enemy["slow_remaining"]) - delta)
			enemy["slowed"] = float(enemy["slow_remaining"]) > 0.000000001
			enemy["jump_remaining"] = maxf(0.0, float(enemy["jump_remaining"]) - delta)
		elif casting:
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
			if float(_enemy_types[enemy["type_id"]]["enrage_health_fraction"]) > 0.0:
				if not _slow_motion.has(enemy["id"]):
					_slow_motion[enemy["id"]] = [0.0, 0.0, 0.0, 0.0]
				var motion: Array = _slow_motion[enemy["id"]]
				motion[0] = float(enemy["progress"])
				motion[1] = delta
				motion[2] = base_speed
				motion[3] = base_speed
			else:
				_slow_motion.erase(enemy["id"])
			enemy["progress"] += base_speed * delta
		var previous_cell: Vector2 = Vector2(enemy["pos"]).round()
		enemy["pos"] = _position(enemy["route"], enemy["progress"])
		relocated = relocated or Vector2(enemy["pos"]).round() != previous_cell
		enemy["stepped"] = float(enemy["progress"]) > previous_progress + 0.000000001 and enemy["animation"] == "walk"
	if relocated:
		_enemies_relocated(slot)


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
	_next_send_times[slot] += send_order_gap(_active_send_spawn_interval, int(_enemy_types[type_id]["spawn_weight"])) if _send_group_ends[slot][_send_heads[slot]] else float(_enemy_types[type_id]["group_interval"])
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
	var birth: Dictionary = _enemy_types[type_id]
	if wave >= int(birth["spawn_variant_first_wave"]) and float(birth["spawn_variant_chance"]) > 0.0:
		if _variant_random.randf() < float(birth["spawn_variant_chance"]):
			type_id = String(birth["spawn_variant"])
	_enemies_relocated(slot)
	var hp: int = _enemy_health(type_id, wave)
	var definition: Dictionary = _enemy_types[type_id]
	var route: Array[Vector2i] = _assign_route(slot) if captured_route.is_empty() else captured_route.duplicate()
	var speed: float = _enemy_speed(type_id, wave)
	_special_stream = _special_stream or float(definition["heal_interval"]) > 0.0 or float(definition["ward_interval"]) > 0.0 or float(definition["summon_interval"]) > 0.0 or EnemyMechanics.has_abilities(definition)
	_boss_stream = _boss_stream or _requires_combat_events(definition)
	enemies[slot].append({
		"id": _next_enemy_id, "hp": hp, "max_hp": hp, "void_drained": 0.0,
		"type_id": type_id, "base_speed": speed, "speed": speed,
		"slowed": false, "slow_remaining": 0.0,
		"fire_immune": _enemy_types[type_id]["fire_immune"], "ice_immune": _enemy_types[type_id]["ice_immune"],
		"nonphysical_damage_multiplier": _enemy_types[type_id]["nonphysical_damage_multiplier"],
		"fire_damage_multiplier": definition["fire_damage_multiplier"],
		"lightning_damage_multiplier": definition["lightning_damage_multiplier"],
		"burning": false, "burn_remaining": 0.0,
		"bounty_tower_id": -1, "bounty_damage_bonus": 0.0, "bounty_income_bonus": 0.0,
		"damage": _enemy_types[type_id]["base_damage"],
		"route": route, "progress": progress, "pos": _position(route, progress),
		"animation": "walk", "animation_elapsed": maxf(0.0, _elapsed - spawn_time),
		"age": maxf(0.0, _elapsed - spawn_time), "cast_remaining": 0.0,
		"heal_count": 0, "summon_count": 0, "summoner_id": summoner_id,
		"next_heal": _enemy_types[type_id]["heal_interval"],
		"heal_charge": 0.0, "heal_clock": maxf(0.0, _elapsed - spawn_time), "shakra_bonus": 0.0,
		"next_ward": _enemy_types[type_id]["ward_interval"], "ward_count": 0,
		"ward_until": 0.0, "ward_source": -1, "warded": false, "ethereal": false,
		"next_summon": _enemy_types[type_id]["summon_interval"],
		"tower_attack_count": 0, "tower_attack_target_ids": [] as Array[int], "tower_attack_aims": [] as Array[Vector2],
		"tower_attack_remaining": 0.0, "next_tower_attack": _enemy_types[type_id]["tower_attack_interval"],
		"stomp_count": 0, "next_stomp": _enemy_types[type_id]["stomp_interval"],
		"locomotion": "wheels" if float(definition["jump_interval"]) > 0.0 else "path",
		"next_jump": definition["jump_interval"], "jump_distance": 0, "jump_count": 0,
		"jump_remaining": 0.0, "jump_duration": _enemy_types[type_id]["jump_duration"],
		"jump_from": _position(route, progress), "jump_to": _position(route, progress),
		"jump_target_progress": progress,
		"stepped": false, "launched": false,
	})
	EnemyMechanics.initialize(enemies[slot].back(), definition)
	if not definition["spellbook"].is_empty():
		enemies[slot].back().merge({
			"spell": "", "spell_phase": "", "spell_index": 0, "spell_count": 0, "barriers": 0,
			"next_spell": float(definition["spellbook"]["glide"]), "spell_duration": 0.0,
			"spell_aim": Vector2.ZERO, "spell_shielded": false, "spell_effect": {},
		})
	_enemy_spawn_times[_next_enemy_id] = spawn_time
	_next_enemy_id += 1


func _position(route: Array, progress: float) -> Vector2:
	var last: int = route.size() - 1
	if progress >= last:
		return Vector2(route[last])
	var index: int = floori(progress)
	return Vector2(route[index]).lerp(Vector2(route[index + 1]), progress - index)


func _reset_firing(tower: Dictionary) -> void:
	tower["firing"] = false
	tower["continuous_fire_time"] = 0.0
	tower["drain_targets"].clear()
	# A committed refuel survives target loss and wave transitions.


func _clear_stun(tower: Dictionary) -> void:
	tower["stunned_remaining"] = 0.0
	tower["stun_source"] = ""
	_stun_refresh_times.erase(int(tower["id"]))


# Withering and silencing end with the wave that cast them.
func _clear_spell_marks(tower: Dictionary) -> void:
	tower["withered_until"] = 0.0
	tower["wither"] = 0.0
	tower["wither_remaining"] = 0.0
	tower["nullified"] = false


# Nullify freezes Magic towers outright, timers included.
func _silenced(slot: int, tower: Dictionary) -> bool:
	return tower.get("element", "") == "magic" and _magic_nullified_until[slot] > _elapsed + 0.000000001


func _advance_stuns(slot: int, delta: float) -> void:
	var expired: bool = false
	for tower: Dictionary in towers[slot]:
		var previous: float = tower["stunned_remaining"]
		var age: float = minf(delta, maxf(0.0, _elapsed - float(_stun_refresh_times.get(int(tower["id"]), _elapsed - delta))))
		tower["stunned_remaining"] = maxf(0.0, previous - age)
		if previous > 0.000000001:
			_stun_refresh_times[int(tower["id"])] = _elapsed
		if previous > 0.000000001 and float(tower["stunned_remaining"]) <= 0.000000001:
			_clear_stun(tower)
			expired = true
	if expired:
		_refresh_board(slot)
		_update_bounties(slot)


func _stun_tower(slot: int, tower: Dictionary, duration: float, source: String, position: Vector2) -> void:
	# An impact occurs now; the subsequent timer pass must not age it by the
	# time preceding that impact in this simulation step.
	var last_update: float = float(_stun_refresh_times.get(int(tower["id"]), _step_start_time))
	var existing: float = maxf(0.0, float(tower["stunned_remaining"]) - maxf(0.0, _elapsed - last_update))
	tower["stunned_remaining"] = maxf(existing, duration)
	_stun_refresh_times[int(tower["id"])] = _elapsed
	tower["stun_count"] += 1
	tower["stun_source"] = source
	tower["stun_position"] = position
	_reset_firing(tower)
	_clear_tower_mark(slot, tower)
	_sound_events.record(CombatSoundEvents.Cue.TOWER_STUN, slot, Vector2(tower["cell"]), _death_time)


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
		_attack_pierce(slot, tower, tower["range"], selected, time)
		_sound_events.record(CombatSoundEvents.Cue.BOW, slot, Vector2(tower["cell"]), _death_time)


func _attack_flames(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		if float(tower["stunned_remaining"]) > 0.000000001:
			tower["firing"] = false
			continue
		var config: Dictionary = _tower_types[tower["type_id"]]["advancements"].get(tower["advancement"], NO_BONUS)
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
		if not _continuous_damage.has(tower["id"]):
			_continuous_damage[tower["id"]] = {}
		var fractions: Dictionary = _continuous_damage[tower["id"]]
		var base_rate: float = float(config["continuous_dps"]) * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"]) * _elemental_damage_multiplier(enemy, &"fire")
		var rate: float = base_rate * (1.0 + float(enemy["bounty_damage_bonus"]))
		end = minf(end, time + maxf(0.0, float(config["fuel_duration"]) - float(tower["continuous_fire_time"])))
		var shield_streams: Dictionary = _shield_exposure.get(id, NO_BONUS)
		if int(enemy["shield_hits"]) > 0 or float(shield_streams.get(int(tower["id"]), 0.0)) > 0.000000001:
			var span: float = end - time
			var unshielded: float = _shield_continuous_exposure(enemy, tower["id"], span, _shield_contact_interval(tower), base_rate)
			var absorbed: float = span - unshielded
			if absorbed > 0.000000001:
				tower["target_id"] = id
				tower["aim"] = _position(enemy["route"], _historical_progress(enemy, time + absorbed))
				tower["firing"] = true
				tower["continuous_fire_time"] += absorbed
				time += absorbed
				if float(tower["continuous_fire_time"]) >= float(config["fuel_duration"]) - 0.000000001:
					tower["refuel_remaining"] = float(config["refuel_duration"])
					_reset_firing(tower)
				continue
		_ignite(enemy, tower, config, time)
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
			_hit(slot, tower, selected, damage, true, &"", bonus, true)
		_burn_until(slot, id, end)
		selected = _enemy_index(slot, id)
		if selected >= 0:
			_ignite(enemies[slot][selected], tower, config, end)
		if float(config.get("scorch_fraction", 0.0)) > 0.0 and exposure > 0.0:
			_flame_scorch(slot, tower, config, id, Vector2(tower["aim"]), time, end)
		time = end
		if float(tower["continuous_fire_time"]) >= float(config["fuel_duration"]) - 0.000000001:
			tower["refuel_remaining"] = float(config["refuel_duration"])
			_reset_firing(tower)
	if float(tower["refuel_remaining"]) <= 0.000000001 and _target(slot, tower, tower["range"], -1, -1, -1, -1, _elapsed, true) < 0:
		_reset_firing(tower)
		tower["target_id"] = -1


# Sum two independent fractional HP streams and stop on the lethal whole-HP
# crossing so a coarse simulation tick can retarget without wasting fuel.
# The flame stream also scorches orcs crowding its target: a share of the stream
# over the same span, plus ignition, through the usual shield and burn ledgers.
func _flame_scorch(slot: int, tower: Dictionary, config: Dictionary, primary_id: int, center: Vector2, start: float, end: float) -> void:
	var radius_squared: float = float(config["scorch_radius"]) * float(config["scorch_radius"])
	var victims: Array[int] = []
	for enemy: Dictionary in enemies[slot]:
		if int(enemy["id"]) == primary_id or int(enemy["hp"]) <= 0 or bool(enemy["fire_immune"]) or _immune(enemy, &"fire"):
			continue
		if float(_enemy_spawn_times[enemy["id"]]) > start + 0.000000001:
			continue
		if _position(enemy["route"], _historical_progress(enemy, end)).distance_squared_to(center) <= radius_squared:
			victims.append(int(enemy["id"]))
	var fractions: Dictionary = _continuous_damage[tower["id"]]
	for id: int in victims:
		_burn_until(slot, id, start)
		var index: int = _enemy_index(slot, id)
		if index < 0:
			continue
		var enemy: Dictionary = enemies[slot][index]
		var base_rate: float = float(config["continuous_dps"]) * float(config["scorch_fraction"]) * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"]) * _elemental_damage_multiplier(enemy, &"fire")
		var span: float = _shield_continuous_exposure(enemy, tower["id"], end - start, _shield_contact_interval(tower), base_rate)
		if span > 0.000000001:
			var total: float = float(fractions.get(id, 0.0)) + base_rate * (1.0 + float(enemy["bounty_damage_bonus"])) * span
			var bonus: Dictionary = _continuous_bonus_stream(tower["id"], id, float(enemy["bounty_damage_bonus"]) > 0.0)
			_accumulate_bonus(slot, enemy, bonus, base_rate * span)
			var damage: int = floori(total + 0.000000001)
			fractions[id] = maxf(0.0, total - damage)
			if damage > 0:
				_hit(slot, tower, index, damage, true, &"", bonus, true)
		_burn_until(slot, id, end)
		index = _enemy_index(slot, id)
		if index >= 0:
			_ignite(enemies[slot][index], tower, config, end)


func _flame_lethal_time(enemy: Dictionary, fraction: float, rate: float, time: float) -> float:
	var burn: Dictionary = _burns[enemy["id"]]
	if float(burn["last_time"]) > time + 0.000000001:
		return maxf(0.000000001, (float(enemy["hp"]) - fraction) / rate)
	var burn_fraction: float = burn["fraction"]
	var burn_rate: float = float(burn["dps"]) * _damage_multiplier(enemy, &"fire")
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
	var faded: bool = false
	for tower: Dictionary in towers[slot]:
		var withered: float = tower["withered_until"]
		if withered > 0.0 and withered <= _elapsed + 0.000000001:
			tower["withered_until"] = 0.0
			withered = 0.0
			faded = true
		tower["wither_remaining"] = maxf(0.0, withered - _elapsed)
	if faded:
		_refresh_board(slot)
	# _silenced, hoisted: only the tower's element varies within this pass.
	var nullifying: bool = _magic_nullified_until[slot] > _elapsed + 0.000000001
	for tower: Dictionary in towers[slot]:
		# Nullify silences Magic towers entirely: no shots, pulses or tendrils.
		var nullified: bool = nullifying and tower.get("element", "") == "magic"
		tower["nullified"] = nullified
		if nullified or float(tower["stunned_remaining"]) > 0.000000001:
			tower["drain_targets"].clear()
			continue
		var kind: String = tower["behavior_kind"]
		if kind == "catapult":
			_attack_catapult(slot, tower, delta)
			continue
		if kind != "attack" and kind != "chain":
			continue
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var config: Dictionary = definition["advancements"].get(tower["advancement"], NO_BONUS)
		var weapon: String = config.get("weapon", "arrow")
		if weapon == "flamethrower":
			continue
		if weapon == "minigun":
			_attack_minigun(slot, tower, delta)
			continue
		if definition["area_attack"] and definition["evolutions"].has(tower["evolution"]):
			if definition["evolutions"][tower["evolution"]]["continuous"]:
				_attack_continuous(slot, tower, tower["range"], delta)
			else:
				_attack_pulses(slot, tower, tower["range"], delta)
			continue
		var cooldown: float = maxf(0.0, tower["cooldown"] - delta)
		tower["cooldown"] = cooldown
		if cooldown > 0.000000001:
			continue
		var target_index: int = _target(slot, tower, tower["range"])
		if target_index < 0:
			continue
		var enemy: Dictionary = enemies[slot][target_index]
		tower["target_id"] = enemy["id"]
		tower["aim"] = enemy["pos"]
		tower["shot"] += 1
		var cue: int = int(definition["attack_sound"])
		if weapon == "rocket":
			cue = CombatSoundEvents.Cue.BALLISTA
		elif weapon in ["molotov", "grenade"]:
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
		secondary = _target(slot, tower, tower["range"], -1, tower["target_id"])
		if secondary < 0:
			secondary = _target(slot, tower, tower["range"])
	if secondary >= 0:
		tower["secondary_target_id"] = enemies[slot][secondary]["id"]
		tower["secondary_aim"] = enemies[slot][secondary]["pos"]
		tower["secondary_shot"] += 1
	for index: int in range(tower["extra_archers"].size()):
		var archer: Dictionary = tower["extra_archers"][index]
		archer["target_id"] = -1
		var selected: int = _target(slot, tower, tower["range"], -1, tower["target_id"], tower["secondary_target_id"], -1, -1.0, false, tower["extra_archers"], index)
		if selected < 0:
			selected = _target(slot, tower, tower["range"])
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
	var damage_type: StringName = &"fire" if config.get("weapon", "") in ["molotov", "flamethrower"] else (&"explosive" if config.has("splash_radius") else StringName(_tower_types[tower["type_id"]]["damage_type"]))
	var primary: int = _enemy_index(slot, target_id)
	if primary >= 0:
		var damage: int = ceili(float(tower["damage"]) * float(config.get("primary_multiplier", 1.0)))
		var accepted: bool = _hit(slot, tower, primary, damage, false, damage_type)
		if accepted and config.has("burn_dps"):
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
				var accepted: bool = _hit(slot, tower, index, damage, false, damage_type)
				if accepted and config.has("burn_dps"):
					var survivor: int = _enemy_index(slot, int(enemy["id"]))
					if survivor >= 0:
						_ignite(enemies[slot][survivor], tower, config)


func _enemy_index(slot: int, enemy_id: int) -> int:
	for index: int in range(enemies[slot].size()):
		if int(enemies[slot][index]["id"]) == enemy_id:
			return index
	return -1


func _ignite(enemy: Dictionary, tower: Dictionary, config: Dictionary, time: float = -1.0) -> void:
	if bool(enemy["fire_immune"]) or int(enemy["shield_hits"]) > 0:
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
	var rate: float = float(burn["dps"]) * _elemental_damage_multiplier(enemy, &"fire")
	exposure = _shield_continuous_exposure(enemy, -int(burn["source"]["id"]), exposure, _shield_contact_interval(burn["source"]), rate)
	var base_damage: float = rate * exposure
	var total: float = float(burn["fraction"]) + base_damage * (1.0 + float(enemy["bounty_damage_bonus"]))
	if float(enemy["bounty_damage_bonus"]) > 0.0 and not burn.has("bonus"):
		burn["bonus"] = {}
	var bonus: Dictionary = burn.get("bonus", NO_BONUS)
	_accumulate_bonus(slot, enemy, bonus, base_damage)
	var damage: int = floori(total + 0.000000001)
	burn["fraction"] = maxf(0.0, total - damage)
	burn["last_time"] = maxf(float(burn["last_time"]), time)
	enemy["burn_remaining"] = maxf(0.0, float(burn["end_time"]) - time)
	enemy["burning"] = float(enemy["burn_remaining"]) > 0.000000001
	if damage > 0:
		_hit(slot, burn["source"], index, damage, true, &"", bonus, true)
	if not enemy["burning"]:
		enemy["burn_remaining"] = 0.0
		_burns.erase(id)


# Rolled pierce/bounce and purchased branches are independent additive capacities.
# A bolt hits straight-through victims first, then redirects from its final hit.
# Bigger Wood steps add pierce; Biggest Wood also widens the bolt's hit lane and
# lets it fly bolt_reach cells past range. Magic Ballista keeps redirecting with a
# decaying chance, revisiting earlier victims only when no new enemy remains.
func _attack_pierce(slot: int, tower: Dictionary, range_cells: float, primary_index: int, time: float = -1.0) -> void:
	var modifiers: Dictionary = tower["modifiers"]
	var pierce: int = int(modifiers.get("pierce", 0.0)) + int(tower["evolution"] == "pierce") + int(tower.get("branch_pierce", 0))
	var bounces: int = int(modifiers.get("bounce", 0.0)) + int(tower["evolution"] == "bounce")
	var magic: Dictionary = tower.get("magic_bounce", {})
	var points: Array = tower["bounce_points"]
	points.clear()
	tower["split_paths"].clear()
	if pierce == 0 and bounces == 0:
		_hit(slot, tower, primary_index)
		return
	var hit_ids: Dictionary = {}
	var origin := Vector2(tower["cell"])
	var direction: Vector2 = Vector2(tower["aim"]) - origin
	var position: Vector2 = tower["aim"]
	var current_id: int = int(enemies[slot][primary_index]["id"])
	if pierce > 0:
		tower["pierce_active"] = true
		tower["pierce_aim"] = tower["aim"]
	if pierce == 0 or direction == Vector2.ZERO:
		hit_ids[current_id] = true
		_hit(slot, tower, primary_index)
	else:
		direction = direction.normalized()
		tower["pierce_active"] = true
		var reach: float = range_cells + float(tower.get("bolt_reach", 0.0))
		var lane: float = 0.25 * float(tower.get("bolt_scale", 1.0))
		# The straight bolt flies on to just past the circular reach.
		tower["pierce_aim"] = origin + direction * (reach + 0.5 - 0.000001)
		for contact: int in range(1 + pierce):
			var selected: int = -1
			var best_distance: float = INF
			var best_id: int = 0
			for index: int in range(enemies[slot].size()):
				var enemy: Dictionary = enemies[slot][index]
				var sampled: Vector2 = enemy["pos"] if time < 0.0 else _position(enemy["route"], _historical_progress(enemy, time))
				if int(enemy["hp"]) <= 0 or hit_ids.has(int(enemy["id"])) or (time >= 0.0 and float(_enemy_spawn_times[enemy["id"]]) > time + 0.000000001) or not cell_in_range(tower["cell"], Vector2i(sampled.round()), reach):
					continue
				var offset: Vector2 = sampled - origin
				var distance: float = offset.dot(direction)
				if distance <= 0.0 or absf(offset.cross(direction)) > lane:
					continue
				if selected < 0 or distance < best_distance or (distance == best_distance and int(enemy["id"]) < best_id):
					selected = index
					best_distance = distance
					best_id = enemy["id"]
			if selected < 0:
				break
			position = enemies[slot][selected]["pos"] if time < 0.0 else _position(enemies[slot][selected]["route"], _historical_progress(enemies[slot][selected], time))
			current_id = int(enemies[slot][selected]["id"])
			hit_ids[current_id] = true
			_hit(slot, tower, selected)
	# Double Magic / S.U.M.G.G.M.: after the first hit the bolt splits; each bolt
	# redirects on its own hit record and chance rolls, preferring a first victim
	# no earlier split bolt took.
	var taken: Dictionary = {}
	var first_id: int = _redirect(slot, tower, position, current_id, hit_ids.duplicate(), bounces, magic, points, time, taken, true)
	if first_id >= 0:
		taken[first_id] = true
	if not magic.is_empty():
		for split: int in range(int(tower.get("magic_split", 1)) - 1):
			var path: Array[Vector2] = []
			first_id = _redirect(slot, tower, position, current_id, hit_ids.duplicate(), bounces, magic, path, time, taken, false)
			if first_id >= 0:
				taken[first_id] = true
			tower["split_paths"].append(path)


# Guaranteed redirects first, then Magic's decaying chance. With no unhit enemy
# left a magic bolt loops back to earlier victims, never onto its current one.
# Returns the first redirected victim's ID, or -1.
func _redirect(slot: int, tower: Dictionary, position: Vector2, current_id: int, hit_ids: Dictionary, bounces: int, magic: Dictionary, points: Array, time: float, avoid: Dictionary, primary: bool) -> int:
	var chance: float = float(magic.get("chance", 0.0))
	var damage_type: StringName = _tower_damage_type(tower)
	var first_id: int = -1
	var jump: int = 0
	while jump < bounces or (not magic.is_empty() and chance > 0.000000001 and _magic_random.randf() < chance):
		if jump >= bounces:
			chance -= float(magic.get("decay", 0.0))
		jump += 1
		var selected: int = -1
		if jump == 1 and not avoid.is_empty():
			var excluded: Dictionary = hit_ids.duplicate()
			excluded.merge(avoid)
			selected = _nearest_unhit(slot, position, excluded, INF, time, damage_type)
		if selected < 0:
			selected = _nearest_unhit(slot, position, hit_ids, INF, time, damage_type)
		if selected < 0 and not magic.is_empty():
			selected = _nearest_unhit(slot, position, {current_id: true}, INF, time, damage_type)
		if selected < 0 or jump > MAX_BOUNCE_POINTS:
			break
		position = enemies[slot][selected]["pos"] if time < 0.0 else _position(enemies[slot][selected]["route"], _historical_progress(enemies[slot][selected], time))
		current_id = int(enemies[slot][selected]["id"])
		hit_ids[current_id] = true
		if first_id < 0:
			first_id = current_id
		tower["bounce_active"] = true
		if primary:
			tower["bounce_aim"] = position
		points.append(position)
		_hit(slot, tower, selected, ceili(float(tower["damage"]) * TowerDefinition.BOUNCE_DAMAGE_MULTIPLIER))
	return first_id


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
		selected = _nearest_unhit(slot, position, hit_ids, float(config["jump_distance"]), -1.0, _tower_damage_type(tower))


# Orcapult: grab the nearest throwable enemies in range, slam the bucket into
# their neighbours, and fling the grabbed ones onto the opponent's board
# (back to this board's own portal in Sandbox). A thrown enemy keeps its HP and
# can never be thrown again, so two Orcapults cannot juggle it forever.
func _attack_catapult(slot: int, tower: Dictionary, delta: float) -> void:
	tower["cooldown"] = maxf(0.0, float(tower["cooldown"]) - delta)
	if float(tower["cooldown"]) > 0.000000001:
		return
	var config: Dictionary = tower["behavior_config"]
	var origin := Vector2(tower["cell"])
	var candidates: Array[Dictionary] = []
	for enemy: Dictionary in enemies[slot]:
		if not throwable(enemy, _enemy_types[enemy["type_id"]], float(config["lift"])) or float(_enemy_spawn_times[enemy["id"]]) > _elapsed + 0.000000001:
			continue
		if not cell_in_range(tower["cell"], Vector2i(enemy["pos"].round()), tower["range"]):
			continue
		candidates.append(enemy)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = origin.distance_squared_to(a["pos"])
		var db: float = origin.distance_squared_to(b["pos"])
		return da < db or (da == db and int(a["id"]) < int(b["id"])))
	var grabbed: Array[Dictionary] = candidates.slice(0, int(config["throw_count"]))
	var grabbed_ids: Dictionary = {}
	for enemy: Dictionary in grabbed:
		grabbed_ids[int(enemy["id"])] = true
	tower["cooldown"] = tower["interval"]
	tower["shot"] += 1
	tower["target_id"] = grabbed[0]["id"]
	tower["aim"] = grabbed[0]["pos"]
	_sound_events.record(CombatSoundEvents.Cue.BALLISTA, slot, origin, _death_time)
	# The bucket slams down around each grabbed enemy before it is hurled.
	var radius: float = float(config["slam_radius"])
	var splashed: Array[int] = []
	if radius > 0.0:
		for enemy: Dictionary in enemies[slot]:
			if grabbed_ids.has(int(enemy["id"])) or int(enemy["hp"]) <= 0:
				continue
			for victim: Dictionary in grabbed:
				if Vector2(enemy["pos"]).distance_to(victim["pos"]) <= radius:
					splashed.append(int(enemy["id"]))
					break
	for enemy: Dictionary in grabbed:
		_launch(slot, tower, enemy)
	for id: int in splashed:
		var index: int = _enemy_index(slot, id)
		if index >= 0:
			_hit(slot, tower, index)


static func throwable(enemy: Dictionary, definition: Dictionary, lift: float) -> bool:
	return int(enemy["hp"]) > 0 and not bool(enemy.get("launched", false)) and not bool(definition.get("boss", false)) and float(definition.get("health_multiplier", 1.0)) <= lift + 0.000000001 and BossMechanics.can_act(enemy)


func _launch(slot: int, tower: Dictionary, enemy: Dictionary) -> void:
	var config: Dictionary = tower["behavior_config"]
	var target: int = slot if _sandbox_mode else 1 - slot
	var index: int = _enemy_index(slot, enemy["id"])
	if index < 0:
		return
	var from: Vector2 = enemy["pos"]
	enemies[slot].remove_at(index)
	_retire_enemy(enemy["id"])
	# Statuses and marks belong to the board it leaves.
	enemy["burning"] = false
	enemy["burn_remaining"] = 0.0
	enemy["slowed"] = false
	enemy["slow_remaining"] = 0.0
	enemy["stunned_remaining"] = 0.0
	enemy["stun_source"] = ""
	enemy["bounty_tower_id"] = -1
	enemy["bounty_damage_bonus"] = 0.0
	enemy["bounty_income_bonus"] = 0.0
	enemy["cast_remaining"] = 0.0
	enemy["tower_attack_remaining"] = 0.0
	enemy["launched"] = true
	var route: Array[Vector2i] = _assign_route(target)
	var progress: float = minf(float(config["landing_progress"]), float(route.size() - 1) * 0.6)
	tower["thrown"] = int(tower.get("thrown", 0)) + 1
	flights.append({
		"id": _next_flight_id, "from_slot": slot, "to_slot": target,
		"tower_id": tower["id"], "tower_cell": Vector2(tower["cell"]),
		"from": from, "to": _position(route, progress), "route": route, "progress": progress,
		"haste": float(config["landing_haste"]),
		"launch_time": _elapsed, "land_time": _elapsed + FLIGHT_DURATION, "clock": _death_time,
		"enemy": enemy,
	})
	_next_flight_id += 1


func _land_flights() -> void:
	var index: int = 0
	while index < flights.size():
		var flight: Dictionary = flights[index]
		if float(flight["land_time"]) > _elapsed + 0.000000001:
			index += 1
			continue
		flights.remove_at(index)
		var enemy: Dictionary = flight["enemy"]
		var target: int = flight["to_slot"]
		enemy["base_speed"] = float(enemy["base_speed"]) * float(flight["haste"])
		enemy["speed"] = enemy["base_speed"]
		enemy["route"] = flight["route"]
		enemy["progress"] = float(flight["progress"]) + (_elapsed - float(flight["land_time"])) * float(enemy["base_speed"])
		enemy["pos"] = _position(enemy["route"], enemy["progress"])
		enemy["jump_from"] = enemy["pos"]
		enemy["jump_to"] = enemy["pos"]
		enemy["jump_target_progress"] = enemy["progress"]
		_enemy_spawn_times[enemy["id"]] = float(flight["land_time"])
		enemies[target].append(enemy)
		_enemies_relocated(target)
		_sound_events.record(CombatSoundEvents.Cue.CLUB_IMPACT, target, flight["to"], _death_time)


# Bounces and chain jumps never land on an enemy immune to their element.
func _nearest_unhit(slot: int, origin: Vector2, excluded: Dictionary, radius: float = INF, time: float = -1.0, damage_type: StringName = &"") -> int:
	var best: int = -1
	var distance: float = radius * radius
	var best_id: int = 0
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if int(enemy["hp"]) <= 0 or excluded.has(int(enemy["id"])) or (time >= 0.0 and float(_enemy_spawn_times[enemy["id"]]) > time + 0.000000001):
			continue
		if damage_type != &"" and _immune(enemy, damage_type):
			continue
		var sampled: Vector2 = enemy["pos"] if time < 0.0 else _position(enemy["route"], _historical_progress(enemy, time))
		var candidate: float = origin.distance_squared_to(sampled)
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
	# Zero-length boss-stream passes integrate nothing and keep the tendrils.
	if delta <= 0.0:
		return
	var tower_id: int = tower["id"]
	if not _continuous_damage.has(tower_id):
		_continuous_damage[tower_id] = {}
	var fractions: Dictionary = _continuous_damage[tower_id]
	var exposed: Array[int] = []
	var exposures: Dictionary = {}
	var damage_type: StringName = _tower_damage_type(tower)
	var cell: Vector2i = tower["cell"]
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		# Both tests are pure: exposure skips far segments cheaply, so it filters first.
		var exposure: float = _continuous_exposure(cell, range_cells, enemy, minf(delta, _elapsed - float(_enemy_spawn_times[enemy["id"]])))
		if exposure > 0.0 and not _immune(enemy, damage_type):
			exposed.append(index)
			exposures[index] = exposure
	# A Void Monolith drains only as many enemies as it has tendrils, chosen by its target mode.
	var tendrils: int = int(tower["void_tendrils"])
	if tendrils > 0 and exposed.size() > tendrils:
		exposed.sort_custom(func(a: int, b: int) -> bool: return _drain_ranks_before(tower, enemies[slot][a], enemies[slot][b]))
		exposed.resize(tendrils)
	tower["drain_targets"].clear()
	for index: int in exposed:
		tower["drain_targets"].append(int(enemies[slot][index]["id"]))
	# Descending indices stay valid when a lethal hit removes an enemy.
	exposed.sort()
	exposed.reverse()
	for index: int in exposed:
		var enemy: Dictionary = enemies[slot][index]
		var exposure: float = exposures[index]
		var elemental: float = _elemental_damage_multiplier(enemy, _tower_damage_type(tower))
		var flat_rate: float = float(tower["base_damage"]) * float(tower["speed_multiplier"]) * float(tower["damage_multiplier"]) * elemental
		var drain_rate: float = _drain_per_second(tower, enemy) * elemental
		exposure = _shield_continuous_exposure(enemy, tower_id, exposure, _shield_contact_interval(tower), flat_rate + drain_rate)
		if exposure <= 0.0:
			continue
		if bool(tower["freeze_upgraded"]) and not bool(enemy["ice_immune"]):
			enemy["slowed"] = true
			enemy["slow_remaining"] = TowerDefinition.freeze_duration(int(enemy["max_hp"]))
			BossMechanics.prepare(enemy)
			if float(enemy["stunned_remaining"]) > 0.000000001:
				enemy["speed"] = 0.0
		var drained: float = minf(drain_rate * exposure, _drain_budget(tower, enemy))
		enemy["void_drained"] = float(enemy.get("void_drained", 0.0)) + drained
		var base_damage: float = flat_rate * exposure + drained
		var total: float = float(fractions.get(enemy["id"], 0.0)) + base_damage * (1.0 + float(enemy["bounty_damage_bonus"]))
		var bonus: Dictionary = _continuous_bonus_stream(tower_id, enemy["id"], float(enemy["bounty_damage_bonus"]) > 0.0)
		_accumulate_bonus(slot, enemy, bonus, base_damage)
		# Credit is already vulnerability-adjusted HP: mark changes affect only
		# new exposure, not saved fractions. The epsilon corrects whole-HP sums.
		var damage: int = floori(total + 0.000000001)
		fractions[enemy["id"]] = maxf(0.0, total - damage)
		if damage > 0:
			_hit(slot, tower, index, damage, true, &"", bonus, true)


# Void maximum-HP drain ignores damage and speed buffs, and every Void on the
# board shares one per-enemy budget: max_hp_damage_limit of that enemy's max HP.
func _drain_budget(tower: Dictionary, enemy: Dictionary) -> float:
	return maxf(0.0, float(enemy["max_hp"]) * float(tower["max_hp_drain_limit"]) - float(enemy.get("void_drained", 0.0)))


func _drain_per_second(tower: Dictionary, enemy: Dictionary) -> float:
	if _drain_budget(tower, enemy) <= 0.000000001:
		return 0.0
	return float(enemy["max_hp"]) * float(tower["max_hp_drain"])


static func _drain_ranks_before(tower: Dictionary, first: Dictionary, second: Dictionary) -> bool:
	var scores: Array[float] = []
	for enemy: Dictionary in [first, second]:
		match int(tower["mode"]):
			TargetMode.CLOSEST:
				scores.append(-Vector2(tower["cell"]).distance_squared_to(enemy["pos"]))
			TargetMode.STRONGEST:
				scores.append(float(enemy["hp"]))
			TargetMode.LAST:
				scores.append(-float(enemy["progress"]))
			_:
				scores.append(float(enemy["progress"]))
	if scores[0] != scores[1]:
		return scores[0] > scores[1]
	return int(first["id"]) < int(second["id"])


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
	var radius: float = floorf(range_cells) + 0.5
	for segment: int in range(floori(start), ceili(finish)):
		var from: Vector2i = route[segment]
		var to: Vector2i = route[segment + 1]
		# Both ends past one side of the square: rectangle_span would clip the
		# segment to an empty span, which adds nothing.
		if (from.x - cell.x >= radius and to.x - cell.x >= radius) or (cell.x - from.x >= radius and cell.x - to.x >= radius) or (from.y - cell.y >= radius and to.y - cell.y >= radius) or (cell.y - from.y >= radius and cell.y - to.y >= radius):
			continue
		var origin := Vector2(from)
		var direction: Vector2 = Vector2(to) - origin
		var clipped: Vector2 = BossMechanics.rectangle_span(origin, direction, Vector2(cell), radius)
		var low: float = maxf(maxf(0.0, start - segment), clipped.x)
		var high: float = minf(minf(1.0, finish - segment), clipped.y)
		distance += maxf(0.0, high - low)
	return distance / speed


func _death_snapshot(slot: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index: int in range(_death_heads[slot], _death_events[slot].size()):
		events.append(_death_events[slot][index].duplicate())
	return events


func _reset_death_events() -> void:
	_sound_events.reset()
	# Reset is a presentation-generation boundary even after the last corpse
	# expired while an accepted bomb/explosion may still be visible on a peer.
	# With nothing visible, repeating a reset stays idempotent.
	if _death_heads[0] < _death_events[0].size() or _death_heads[1] < _death_events[1].size() or not bombs.is_empty() or not _bomb_explosions.is_empty():
		_death_generation += 1
	bombs.clear()
	_bomb_explosions.clear()
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
		"hp": enemy["hp"], "max_hp": enemy["max_hp"],
		"death_stun_radius": _enemy_types[enemy["type_id"]]["death_stun_radius"],
		"bolt_to": enemy.get("death_bolt_to", Vector2(-1, -1)),
	})
	_next_death_id += 1
	# Remember ordinary deaths briefly for Raise the Fallen; bosses and the risen stay dead.
	if not _enemy_types[enemy["type_id"]]["boss"] and int(enemy["summoner_id"]) < 0:
		var fallen: Array = _fallen[slot]
		while not fallen.is_empty() and float(fallen[0]["time"]) < _elapsed - Spellbook.FALLEN_MEMORY:
			fallen.pop_front()
		fallen.append({"progress": float(enemy["progress"]), "route": enemy["route"], "pos": enemy["pos"], "time": _elapsed})
	_sound_events.record(int(_enemy_types[enemy["type_id"]]["death_sound"]), slot, enemy["pos"], _death_time)
	var definition: Dictionary = _enemy_types[enemy["type_id"]]
	if float(definition["death_bomb_fuse"]) > 0.0:
		bombs.append({
			"id": _next_bomb_id, "slot": slot, "pos": Vector2(Vector2(enemy["pos"]).round()),
			"time": _death_time, "fuse_duration": definition["death_bomb_fuse"],
			"fuse_remaining": definition["death_bomb_fuse"], "radius": definition["death_bomb_radius"],
			"stun_duration": definition["death_bomb_stun_duration"],
		})
		_next_bomb_id += 1
		_boss_stream = true
	if float(definition["death_stun_duration"]) > 0.0:
		var origin := Vector2i(Vector2(enemy["pos"]).round())
		for tower: Dictionary in towers[slot]:
			if cell_in_square(origin, tower["cell"], float(definition["death_stun_radius"])):
				_stun_tower(slot, tower, float(definition["death_stun_duration"]), "kamikaorc", enemy["pos"])
		_refresh_board(slot)
		_update_bounties(slot)
	for child: int in range(int(definition["death_spawn_count"])):
		_spawn_enemy(slot, definition["death_spawn_type"], progress, _elapsed, route, enemy["id"])


func _retire_enemy(enemy_id: int) -> void:
	_target_grid_valid[0] = false
	_target_grid_valid[1] = false
	_enemy_spawn_times.erase(enemy_id)
	_slow_motion.erase(enemy_id)
	_burns.erase(enemy_id)
	_shield_exposure.erase(enemy_id)
	# A Greater ShaOrc's wards end the moment it dies, leaks or is thrown away.
	for board: Array in enemies:
		for other: Dictionary in board:
			if int(other.get("ward_source", -1)) == enemy_id:
				other["ward_until"] = 0.0
				other["ward_source"] = -1
				other["warded"] = false
	for tower_id: int in _continuous_damage:
		_continuous_damage[tower_id].erase(enemy_id)
	for tower_id: int in _continuous_bonus:
		_continuous_bonus[tower_id].erase(enemy_id)
	for board: Array in towers:
		for tower: Dictionary in board:
			if int(tower["bounty_target_id"]) == enemy_id:
				tower["bounty_target_id"] = -1


func _tower_damage_type(tower: Dictionary) -> StringName:
	if tower["evolution"] == "onyx_ring":
		return &"magic"
	if tower["evolution"] == "boulders":
		return &"ice" if tower["freeze_upgraded"] else &"physical"
	var definition: Dictionary = _tower_types[tower["type_id"]]
	var evolved: Dictionary = definition["evolutions"].get(tower["evolution"], {})
	if evolved.has("damage_type"):
		return StringName(evolved["damage_type"])
	for step: Dictionary in evolved.get("upgrades", []):
		if step.has("damage_type") and tower.get("branch_upgrades", []).has(step["id"]):
			return StringName(step["damage_type"])
	var config: Dictionary = definition["advancements"].get(tower["advancement"], {})
	if config.get("weapon", "") in ["molotov", "flamethrower"]:
		return &"fire"
	if config.has("splash_radius"):
		return &"explosive"
	return StringName(definition["damage_type"])


func _elemental_damage_multiplier(enemy: Dictionary, damage_type: StringName) -> float:
	if _immune(enemy, damage_type):
		return 0.0
	var multiplier: float = float(enemy["nonphysical_damage_multiplier"]) if damage_type != &"physical" else float(enemy["physical_damage_multiplier"])
	if damage_type == &"fire":
		multiplier *= float(enemy["fire_damage_multiplier"])
	elif damage_type == &"lightning":
		multiplier *= float(enemy["lightning_damage_multiplier"])
	return multiplier


# A set (keys only), like the catalog dictionaries, rather than an identity list.
static func _element_set(elements: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for element: String in elements:
		result[element] = true
	return result


func _immune(enemy: Dictionary, damage_type: StringName) -> bool:
	if float(enemy.get("ward_until", 0.0)) > _elapsed + 0.000000001 or bool(enemy.get("spell_shielded", false)):
		return true
	var type: Dictionary = _enemy_types.get(String(enemy.get("type_id", "")), NO_BONUS)
	if type.is_empty():
		return false
	var element: String = TowerDefinition.element_of(damage_type)
	return type["immune_elements"].has(element) or (bool(enemy.get("ethereal", false)) and type["phase_immune_elements"].has(element))


func _damage_multiplier(enemy: Dictionary, damage_type: StringName) -> float:
	return (1.0 + float(enemy["bounty_damage_bonus"])) * _elemental_damage_multiplier(enemy, damage_type)


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


func _hit(slot: int, tower: Dictionary, enemy_index: int, damage: int = -1, bounty_applied: bool = false, damage_type: StringName = &"", credit: Dictionary = NO_BONUS, shield_checked: bool = false) -> bool:
	var enemy: Dictionary = enemies[slot][enemy_index]
	var base_damage: int = int(tower["damage"]) if damage == -1 else damage
	# Discrete hits may crit; continuous streams and burns (bounty_applied) never do.
	var critical: bool = not bounty_applied and float(tower.get("crit_chance", 0.0)) > 0.0 and _crit_random.randf() < float(tower["crit_chance"])
	if critical:
		base_damage = ceili(float(base_damage) * TowerDefinition.CRIT_MULTIPLIER - 0.000000001)
	var incoming_damage: int = base_damage
	if not bounty_applied:
		var resolved_type: StringName = _tower_damage_type(tower) if damage_type == &"" else damage_type
		incoming_damage = ceili(float(base_damage) * _damage_multiplier(enemy, resolved_type) - 0.000000001)
		# Only the mark's incremental HP is indirect, not elemental vulnerability.
		base_damage = ceili(float(base_damage) * _elemental_damage_multiplier(enemy, resolved_type) - 0.000000001)
	if incoming_damage <= 0:
		return false
	if not shield_checked and EnemyMechanics.absorb_hit(enemy, incoming_damage):
		return false
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
	if critical and hit_damage > 0:
		tower["crits"] = int(tower.get("crits", 0)) + 1
	enemy["hp"] -= hit_damage
	if hit_damage > 0:
		EnemyMechanics.after_damage(enemy, _enemy_types[enemy["type_id"]])
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
		_recap.add(slot, "earned", "kill_coins", payout)
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
			_recap.add(slot, "earned", "drop_shards", int(definition["reroll_drop_amount"]))
		_death_bolt(slot, enemy, definition)
		var reward: Dictionary = _boss_loot.claim(slot, String(enemy["type_id"]), definition, wave, _death_time)
		if not reward.is_empty():
			coins[slot] += int(reward["coins"])
			reroll_currency[slot] += int(reward["shards"])
			_recap.add(slot, "earned", "boss_coins", int(reward["coins"]))
			_recap.add(slot, "earned", "boss_shards", int(reward["shards"]))
		_add_total(slot, "kills", enemy["type_id"])
		_record_death(slot, enemy)
		_retire_enemy(enemy["id"])
		enemies[slot].remove_at(enemy_index)
	return true




# Live tracking is host-owned, independent of the last released shot event.
# Resolve after damage, rituals and leaks so no retired victim is published.
func _update_tracking_target(slot: int, tower: Dictionary) -> void:
	if not _tower_types[tower["type_id"]]["directional_weapon"]:
		return
	var selected: int = _target(slot, tower, tower["range"])
	tower["tracking_target_id"] = -1 if selected < 0 else enemies[slot][selected]["id"]
	if selected >= 0:
		tower["tracking_aim"] = enemies[slot][selected]["pos"]


func _current_target_candidates(slot: int, origin: Vector2i, range_cells: float) -> Array:
	if not _target_grid_valid[slot] or _target_grid_counts[slot] != enemies[slot].size():
		var grid: Dictionary = _target_grid[slot]
		for cell: Vector2i in grid:
			grid[cell].clear()
		for enemy: Dictionary in enemies[slot]:
			var cell := Vector2i(Vector2(enemy["pos"]).round())
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(enemy)
		_target_grid_counts[slot] = enemies[slot].size()
		_target_grid_valid[slot] = true
	var candidates: Array = _target_candidates[slot]
	candidates.clear()
	var reach: int = floori(range_cells)
	for y: int in range(origin.y - reach, origin.y + reach + 1):
		for x: int in range(origin.x - reach, origin.x + reach + 1):
			var cell := Vector2i(x, y)
			if _target_grid[slot].has(cell):
				candidates.append_array(_target_grid[slot][cell])
	return candidates


# Range buckets do not change scoring/ties or the host's captured motion rules.
func _target(slot: int, tower: Dictionary, range_cells: float, mode: int = -1, excluded_id: int = -1, excluded_second: int = -1, excluded_third: int = -1, time: float = -1.0, fire_only: bool = false, extra: Array = NO_ARCHERS, extra_count: int = 0) -> int:
	var best: int = -1
	var best_score: float = -INF
	var best_id: int = 0
	var cell: Vector2i = tower["cell"]
	var tower_id: int = tower.get("id", -1)
	if time < 0.0 and _empty_reach.has(tower_id):
		var memo: Array = _empty_reach[tower_id]
		if memo[0] == slot and memo[1] == _cell_versions[slot] and memo[2] == range_cells and memo[3] == cell:
			return -1
	var center: Vector2 = Vector2(cell)
	var reach: int = floori(range_cells)
	var use_grid: bool = time < 0.0 and (reach * 2 + 1) * (reach * 2 + 1) < enemies[slot].size()
	var candidates: Array = _current_target_candidates(slot, cell, range_cells) if use_grid else enemies[slot]
	var policy: int = int(tower["mode"]) if mode < 0 else mode
	# cell_in_range's bound; filters are pure, so the cheap range test runs first.
	var limit: float = range_cells * range_cells + 0.000001
	# Never waste a shot on an enemy immune to this tower's element.
	var typed: bool = tower.get("behavior_kind", "") in ["attack", "chain"]
	var damage_type: StringName = &""
	var reached: bool = false
	for index: int in range(candidates.size()):
		var enemy: Dictionary = candidates[index]
		if time < 0.0:
			var occupied := Vector2i(Vector2(enemy["pos"]).round())
			var dx: int = occupied.x - cell.x
			var dy: int = occupied.y - cell.y
			if float(dx * dx + dy * dy) > limit:
				continue
			reached = true
		if int(enemy["hp"]) <= 0 or int(enemy["id"]) == excluded_id or int(enemy["id"]) == excluded_second or int(enemy["id"]) == excluded_third or (fire_only and bool(enemy["fire_immune"])):
			continue
		if typed and damage_type == &"":
			damage_type = _tower_damage_type(tower)
		if damage_type != &"" and _immune(enemy, damage_type):
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
		if time >= 0.0 and not cell_in_range(cell, Vector2i(position.round()), range_cells):
			continue
		var target_progress: float = progress
		var score: float
		match policy:
			TargetMode.CLOSEST:
				score = -center.distance_squared_to(position)
			TargetMode.STRONGEST:
				score = float(enemy["hp"])
			TargetMode.LAST:
				score = -target_progress
			_:
				score = target_progress
		var id: int = enemy["id"]
		if best < 0 or score > best_score or (score == best_score and id < best_id):
			best = index
			best_score = score
			best_id = id
	# Only a full scan proves the whole circle empty, for grid queries too.
	if time < 0.0 and not use_grid and not reached and tower_id >= 0:
		_empty_reach[tower_id] = [slot, _cell_versions[slot], range_cells, cell]
	return _enemy_index(slot, best_id) if use_grid and best >= 0 else best


func _apply_leaks(slot: int) -> void:
	var index: int = enemies[slot].size() - 1
	while index >= 0:
		if enemies[slot][index]["progress"] >= enemies[slot][index]["route"].size() - 1 and float(enemies[slot][index]["stunned_remaining"]) <= 0.000000001 and BossMechanics.can_act(enemies[slot][index]):
			if not _sandbox_mode:
				var health_before: int = base_health[slot]
				if base_health[slot] > 0:
					_sound_events.record(CombatSoundEvents.Cue.CRYSTAL, slot, Vector2(enemies[slot][index]["route"].back()), _death_time)
				base_health[slot] = maxi(0, base_health[slot] - int(enemies[slot][index]["damage"]))
				_recap.leak(slot, String(enemies[slot][index]["type_id"]), health_before - base_health[slot], base_health[slot] == 0)
			_retire_enemy(enemies[slot][index]["id"])
			enemies[slot].remove_at(index)
		index -= 1
