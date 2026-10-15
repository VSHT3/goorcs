class_name MatchCombat
extends RefCounted

enum Phase { PLANNING, WAVE, FINISHED }
enum TargetMode { FURTHEST, CLOSEST, STRONGEST }

var phase: Phase = Phase.PLANNING
var wave: int = 0
var base_health: Array[int] = []
var coins: Array[int] = []
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
# Spawn times cap first-tick exposure even when due events arrive mid-tick.
var _enemy_spawn_times: Dictionary = {}
# Actual Rune HP removed, including damage before either evolution purchase.
var _rune_damage: Dictionary = {}
# Only enemies slowed at tick start need a two-speed historical motion record.
# Reused float records retain precision without per-tick history allocations.
var _slow_motion: Dictionary = {}
var _step_start_time: float = 0.0


func _init(rules: CombatRules, random: RandomNumberGenerator = null, wave_random: RandomNumberGenerator = null, timing_random: RandomNumberGenerator = null) -> void:
	_rules = rules
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
	if rules.wave_weight <= 0 or rules.wave_weight_growth < 0 or not is_finite(rules.spawn_interval) or rules.spawn_interval < 0.0:
		push_error("Combat waves require positive weight, nonnegative growth and a finite nonnegative spawn interval")
		_roster_configuration_valid = false
	base_health = [rules.base_health, rules.base_health]
	coins = [rules.starting_coins, rules.starting_coins]
	for definition: EnemyDefinition in rules.enemy_definitions:
		if definition == null:
			push_error("Combat enemy_definitions contains a null entry")
			_roster_configuration_valid = false
			continue
		var type_id: String = String(definition.id)
		if type_id.is_empty() or definition.title.is_empty() or not is_finite(definition.health_multiplier) or definition.health_multiplier <= 0.0 or not is_finite(definition.speed_multiplier) or definition.speed_multiplier <= 0.0 or definition.send_cost <= 0 or definition.send_income < 0 or definition.base_damage <= 0 or definition.spawn_weight <= 0 or definition.first_wave < 1 or definition.max_per_wave < 0 or definition.count_cap_growth < 0 or definition.count_cap_growth_interval < 1 or not is_finite(definition.max_weight_share) or definition.max_weight_share < 0.0 or definition.max_weight_share > 1.0:
			push_error("Invalid combat enemy definition '%s': require positive multipliers/price/damage/weight/unlock/growth interval, nonnegative income/count cap/growth, and finite share in [0, 1]" % type_id)
			_roster_configuration_valid = false
			continue
		if _enemy_types.has(type_id):
			push_error("Duplicate combat enemy definition '%s'" % type_id)
			_roster_configuration_valid = false
			continue
		_enemy_types[type_id] = {
			"title": definition.title, "health_multiplier": definition.health_multiplier,
			"description": definition.description,
			"speed_multiplier": definition.speed_multiplier,
			"send_cost": definition.send_cost, "send_income": definition.send_income,
			"base_damage": definition.base_damage, "spawn_weight": definition.spawn_weight,
			"first_wave": definition.first_wave, "max_per_wave": definition.max_per_wave,
			"count_cap_growth": definition.count_cap_growth,
			"count_cap_growth_interval": definition.count_cap_growth_interval,
			"max_weight_share": definition.max_weight_share,
		}
	if not _enemy_types.has("grunt") or int(_enemy_types["grunt"]["spawn_weight"]) != 1 or int(_enemy_types["grunt"]["first_wave"]) != 1 or int(_enemy_types["grunt"]["max_per_wave"]) != 0 or float(_enemy_types["grunt"]["max_weight_share"]) != 1.0:
		push_error("Combat regular waves require an always-unlocked weight-one Grunt with unlimited count and full weight share")
		_roster_configuration_valid = false
	for definition: TowerDefinition in rules.tower_definitions:
		if definition == null:
			push_error("Combat tower_definitions contains a null entry")
			continue
		if definition.reward == null:
			push_error("Combat tower definition '%s' has no reward" % definition.resource_path)
			continue
		var type_id: String = String(definition.reward.id)
		if type_id.is_empty() or definition.damage <= 0 or not is_finite(definition.range_cells) or definition.range_cells <= 0.0 or not is_finite(definition.interval) or definition.interval <= 0.0 or definition.cost <= 0 or definition.upgrade_base_cost <= 0 or definition.damage_upgrade_bonus <= 0 or not is_finite(definition.speed_upgrade_multiplier) or definition.speed_upgrade_multiplier <= 0.0 or definition.speed_upgrade_multiplier >= 1.0:
			push_error("Invalid combat tower definition '%s' (%s): positive stats/prices and speed multiplier between zero and one are required" % [type_id, definition.resource_path])
			continue
		if definition.special_upgrade not in ["", "second_archer", "bounce"] or (not definition.special_upgrade.is_empty() and (definition.special_upgrade_title.is_empty() or definition.special_upgrade_cost <= 0)) or not _valid_evolutions(definition):
			push_error("Invalid combat special upgrade for tower '%s'" % type_id)
			continue
		if _tower_types.has(type_id):
			push_error("Duplicate combat tower definition '%s': keeping the first valid definition" % type_id)
			continue
		_tower_types[type_id] = {
			"title": definition.reward.title, "damage": definition.damage,
			"range": definition.range_cells, "interval": definition.interval,
			"cost": definition.cost, "upgrade_base_cost": definition.upgrade_base_cost,
			"damage_upgrade_bonus": definition.damage_upgrade_bonus,
			"speed_upgrade_multiplier": definition.speed_upgrade_multiplier,
			"area_attack": definition.area_attack,
			"special_upgrade": definition.special_upgrade,
			"special_upgrade_title": definition.special_upgrade_title,
			"special_upgrade_cost": definition.special_upgrade_cost,
			"evolutions": definition.evolutions.duplicate(true),
		}


static func _valid_evolutions(definition: TowerDefinition) -> bool:
	if not definition.evolutions.is_empty() and not definition.special_upgrade.is_empty():
		return false
	for branch: Variant in definition.evolutions:
		if not branch is String or branch not in ["boulders", "onyx_ring"] or not definition.evolutions[branch] is Dictionary:
			return false
		var config: Dictionary = definition.evolutions[branch]
		if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0 or not config.get("damage") is int or int(config["damage"]) <= 0 or not config.get("continuous") is bool:
			return false
		if typeof(config.get("interval")) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var interval: float = float(config["interval"])
		if not is_finite(interval) or (bool(config["continuous"]) and interval != 0.0) or (not bool(config["continuous"]) and interval <= 0.0):
			return false
		if bool(config["continuous"]) != (branch == "boulders") or not definition.area_attack:
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


func build(slot: int, cell: Vector2i, type_id: StringName, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode) or not _tower_types.has(String(type_id)) or has_tower(slot, cell):
		return false
	var definition: Dictionary = _tower_types[String(type_id)]
	var cost: int = definition["cost"]
	if coins[slot] < cost:
		return false
	towers[slot].append({
		"id": _next_tower_id, "cell": cell, "type_id": String(type_id), "mode": mode, "cooldown": 0.0,
		"target_id": -1, "shot": 0, "aim": Vector2(cell),
		"kills": 0, "damage_upgraded": false, "speed_upgraded": false,
		"special_upgraded": false, "freeze_upgraded": false, "evolution": "", "secondary_mode": mode,
		"secondary_shot": 0, "secondary_aim": Vector2(cell), "secondary_target_id": -1,
		"bounce_active": false, "bounce_aim": Vector2(cell),
		"damage": definition["damage"], "interval": definition["interval"],
		"invested": cost, "sell_value": _sell_value(cost),
	})
	coins[slot] -= cost
	_next_tower_id += 1
	return true


func set_targeting(slot: int, tower_id: int, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] == tower_id:
			if tower["mode"] == mode:
				return false
			tower["mode"] = mode
			return true
	return false


func set_secondary_targeting(slot: int, tower_id: int, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] != tower_id:
			continue
		if not tower["special_upgraded"] or _tower_types[tower["type_id"]]["special_upgrade"] != "second_archer" or tower["secondary_mode"] == mode:
			return false
		tower["secondary_mode"] = mode
		return true
	return false


func upgrade_tower(slot: int, tower_id: int, upgrade: String) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] != tower_id:
			continue
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var evolution: bool = definition["evolutions"].has(upgrade)
		var freeze: bool = upgrade == "freeze_runes"
		if upgrade not in ["damage", "speed", "special"] and not evolution and not freeze:
			return false
		if freeze and (tower["evolution"] != "boulders" or not definition["evolutions"].get("boulders", {}).has("followup")):
			return false
		var flag: String = "freeze_upgraded" if freeze else ("special_upgraded" if evolution else upgrade + "_upgraded")
		if (evolution or upgrade == "special") and (not tower["damage_upgraded"] or not tower["speed_upgraded"]):
			return false
		if upgrade == "special" and definition["special_upgrade"].is_empty():
			return false
		var cost: int = int(definition["evolutions"]["boulders"]["followup"]["cost"]) if freeze else (int(definition["evolutions"][upgrade]["cost"]) if evolution else (int(definition["special_upgrade_cost"]) if upgrade == "special" else tower_upgrade_cost(tower, definition)))
		if tower[flag] or coins[slot] < cost:
			return false
		coins[slot] -= cost
		tower[flag] = true
		tower["invested"] += cost
		tower["sell_value"] = _sell_value(tower["invested"])
		if evolution:
			var config: Dictionary = definition["evolutions"][upgrade]
			tower["evolution"] = upgrade
			tower["damage"] = config["damage"]
			tower["interval"] = config["interval"]
			# A new pulse requires a full reload; continuous damage starts accruing
			# only in future simulation time, without an immediate hit or old credit.
			tower["cooldown"] = config["interval"]
		elif upgrade == "damage":
			tower["damage"] += definition["damage_upgrade_bonus"]
		elif upgrade == "speed":
			tower["interval"] *= definition["speed_upgrade_multiplier"]
			# Accelerate the current reload, but never grant an immediate extra shot.
			tower["cooldown"] *= definition["speed_upgrade_multiplier"]
		elif upgrade == "special" and definition["special_upgrade"] == "second_archer":
			tower["interval"] /= TowerDefinition.SECOND_ARCHER_ATTACK_RATE_MULTIPLIER
			tower["cooldown"] /= TowerDefinition.SECOND_ARCHER_ATTACK_RATE_MULTIPLIER
		return true
	return false


func sell_tower(slot: int, tower_id: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot):
		return false
	for index: int in range(towers[slot].size()):
		var tower: Dictionary = towers[slot][index]
		if tower["id"] != tower_id:
			continue
		coins[slot] += _sell_value(tower["invested"])
		_continuous_damage.erase(tower_id)
		_rune_damage.erase(tower_id)
		towers[slot].remove_at(index)
		return true
	return false


# Level is derived from accepted upgrades, never a second mutable copy of tower state.
static func tower_level(tower: Dictionary) -> int:
	return 1 + int(bool(tower["damage_upgraded"])) + int(bool(tower["speed_upgraded"])) + int(bool(tower.get("special_upgraded", false))) + int(bool(tower.get("freeze_upgraded", false)))


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
	for board: Array in towers:
		for tower: Dictionary in board:
			tower["cell"] += Vector2i.DOWN
			tower["aim"] += Vector2.DOWN
			tower["secondary_aim"] += Vector2.DOWN
			tower["bounce_aim"] += Vector2.DOWN


func send_enemy(slot: int, type_id: StringName) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _enemy_types.has(String(type_id)) or not _valid_send_timing():
		return false
	var definition: Dictionary = _enemy_types[String(type_id)]
	var cost: int = definition["send_cost"]
	if coins[slot] < cost:
		return false
	var target: int = 1 - slot
	# Payment, recurring income and FIFO reservation form one host transaction.
	# An idle stream starts now, never at an old due time or in a catch-up burst.
	if _pending_sends(target) == 0 and phase == Phase.WAVE:
		_next_send_times[target] = maxf(_next_send_times[target], _elapsed)
	_send_queues[target].append(String(type_id))
	coins[slot] -= cost
	income[slot] += int(definition["send_income"])
	if phase == Phase.WAVE and _next_send_times[target] <= _elapsed:
		_spawn_send(target)
	return true


func _valid_send_timing() -> bool:
	return is_finite(_send_spawn_interval) and _send_spawn_interval > 0.0 and _valid_interval_scaling()


func _pending_sends(slot: int) -> int:
	return _send_queues[slot].size() - _send_heads[slot]



# Debug jumps abandon a round, never clear it: no bounty, income or wave reward.
func debug_set_round(round_number: int) -> bool:
	if phase == Phase.FINISHED or round_number < 1 or round_number > 1000:
		return false
	phase = Phase.PLANNING
	wave = round_number - 1
	winner = -1
	coin_flip = false
	enemies = [[], []]
	wave_roster.clear()
	spawn_times.clear()
	_send_queues = [[], []]
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
	_rune_damage.clear()
	_enemy_spawn_times.clear()
	_slow_motion.clear()
	for board: Array in towers:
		for tower: Dictionary in board:
			tower["cooldown"] = tower["interval"] if tower["evolution"] == "onyx_ring" else 0.0
			tower["target_id"] = -1
			tower["secondary_target_id"] = -1
			tower["shot"] = 0
			tower["secondary_shot"] = 0
			tower["aim"] = Vector2(tower["cell"])
			tower["secondary_aim"] = Vector2(tower["cell"])
			tower["bounce_aim"] = Vector2(tower["cell"])
			tower["bounce_active"] = false
	return true

func start_wave(routing: Array[Dictionary]) -> bool:
	if phase != Phase.PLANNING or not _roster_configuration_valid or routing.size() != 2 or not _valid_spawn_timing() or not _valid_send_timing():
		return false
	for captured: Dictionary in routing:
		if not _valid_routing(captured):
			return false
	var roster: Array[String] = _generate_wave_roster(wave + 1)
	if roster.is_empty():
		return false
	var interval_multiplier: float = _spawn_interval_multiplier(wave + 1)
	wave_roster = roster
	spawn_times = _generate_spawn_times(roster.size(), _rules.spawn_interval * interval_multiplier)
	_active_send_spawn_interval = _send_spawn_interval * interval_multiplier
	_routes = [routing[0]["route"].duplicate(), routing[1]["route"].duplicate()]
	_routing_next = [routing[0]["next"].duplicate(true), routing[1]["next"].duplicate(true)]
	_fork_cursors = [{}, {}]
	_spawned = [0, 0]
	_elapsed = 0.0
	_next_send_times = [0.0, 0.0]
	wave += 1
	phase = Phase.WAVE
	for slot: int in range(2):
		if _pending_sends(slot) > 0:
			_spawn_send(slot)
	return true


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
	if phase != Phase.WAVE or delta <= 0.0:
		return false
	_step_start_time = _elapsed
	_elapsed += delta
	for slot: int in range(2):
		_move_enemies(slot, delta)
		_spawn_enemies(slot)
		_attack(slot, delta)
		_apply_leaks(slot)
	# Resolve only after BOTH boards have applied this tick's damage.
	if base_health[0] == 0 or base_health[1] == 0:
		phase = Phase.FINISHED
		coin_flip = base_health[0] == 0 and base_health[1] == 0
		winner = _random.randi_range(0, 1) if coin_flip else (1 if base_health[0] == 0 else 0)
	elif _spawned[0] == wave_roster.size() and _spawned[1] == wave_roster.size() and _pending_sends(0) == 0 and _pending_sends(1) == 0 and enemies[0].is_empty() and enemies[1].is_empty():
		var reward: int = _rules.wave_reward + wave * _rules.wave_reward_growth
		coins[0] += reward + income[0]
		coins[1] += reward + income[1]
		phase = Phase.PLANNING
	return true


func snapshot() -> Dictionary:
	return {
		"phase": phase, "wave": wave, "health": base_health.duplicate(),
		"winner": winner, "coin_flip": coin_flip,
		"coins": coins.duplicate(),
		"income": income.duplicate(), "queued_sends": queued_sends,
		"send_queues": [_send_queues[0].slice(_send_heads[0]), _send_queues[1].slice(_send_heads[1])],
		"enemy_types": _enemy_types_snapshot(),
		"towers": towers.duplicate(true), "enemies": enemies.duplicate(true),
		"spawned": _spawned.duplicate(), "total": wave_roster.size(),
		"wave_roster": wave_roster.duplicate(), "wave_weight": _wave_weight(maxi(1, wave)),
		"spawn_times": spawn_times.duplicate(),
		"tower_types": _tower_types.duplicate(true),
		"rules": {
			"enemy_speed": _wave_speed(wave), "enemy_health": _wave_health(wave),
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
	return result


func _enemy_health(type_id: String, wave_number: int) -> int:
	var baseline: int = _wave_health(wave_number)
	return maxi(1, ceili(float(baseline) * float(_enemy_types[type_id]["health_multiplier"])))


func _enemy_speed(type_id: String, wave_number: int) -> float:
	var baseline: float = _wave_speed(wave_number)
	return baseline * float(_enemy_types[type_id]["speed_multiplier"])


func _wave_health(wave_number: int) -> int:
	return _rules.enemy_health + maxi(0, wave_number - 1) * _rules.health_growth


func _wave_speed(wave_number: int) -> float:
	return _rules.enemy_speed + maxi(0, wave_number - 1) * _rules.speed_growth


func _wave_weight(wave_number: int) -> int:
	return _rules.wave_weight + maxi(0, wave_number - 1) * _rules.wave_weight_growth


func _enemy_count_cap(definition: Dictionary, wave_number: int) -> int:
	var base_cap: int = definition["max_per_wave"]
	if base_cap == 0:
		return 0
	var steps: int = floori(float(maxi(0, wave_number - int(definition["first_wave"]))) / int(definition["count_cap_growth_interval"]))
	return base_cap + steps * int(definition["count_cap_growth"])


func _generate_wave_roster(wave_number: int) -> Array[String]:
	var budget: int = _wave_weight(wave_number)
	var remaining: int = budget
	var counts: Dictionary = {}
	var roster: Array[String] = []
	var eligible: Array[String] = []
	var count_caps: Dictionary[String, int] = {}
	for type_id: String in _enemy_types:
		count_caps[type_id] = _enemy_count_cap(_enemy_types[type_id], wave_number)
	while remaining > 0:
		eligible.clear()
		for type_id: String in _enemy_types:
			var definition: Dictionary = _enemy_types[type_id]
			var weight: int = definition["spawn_weight"]
			var count: int = counts.get(type_id, 0)
			var count_cap: int = count_caps[type_id]
			var share_cap: int = floori(float(budget) * float(definition["max_weight_share"]))
			if wave_number >= int(definition["first_wave"]) and weight <= remaining and (count_cap == 0 or count < count_cap) and (count + 1) * weight <= share_cap:
				eligible.append(type_id)
		# The validated weight-one Grunt invariant guarantees exact fill.
		if eligible.is_empty():
			push_error("Combat wave %d cannot fill its remaining weight %d" % [wave_number, remaining])
			return []
		var selected: String = eligible[_wave_random.randi_range(0, eligible.size() - 1)]
		roster.append(selected)
		counts[selected] = int(counts.get(selected, 0)) + 1
		remaining -= int(_enemy_types[selected]["spawn_weight"])
	return roster


func _valid_slot(slot: int) -> bool:
	return slot == 0 or slot == 1


func _valid_mode(mode: int) -> bool:
	return mode >= TargetMode.FURTHEST and mode <= TargetMode.STRONGEST


func _move_enemies(slot: int, delta: float) -> void:
	for enemy: Dictionary in enemies[slot]:
		var base_speed: float = enemy["base_speed"]
		var slowed_seconds: float = minf(delta, float(enemy["slow_remaining"]))
		if slowed_seconds > 0.0:
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
	_next_send_times[slot] += _active_send_spawn_interval
	_send_heads[slot] += 1
	if _send_heads[slot] == _send_queues[slot].size():
		_send_queues[slot].clear()
		_send_heads[slot] = 0
	elif _send_heads[slot] >= 64 and _send_heads[slot] * 2 >= _send_queues[slot].size():
		_send_queues[slot] = _send_queues[slot].slice(_send_heads[slot])
		_send_heads[slot] = 0


func _spawn_enemy(slot: int, type_id: String, progress: float, spawn_time: float) -> void:
	var hp: int = _enemy_health(type_id, wave)
	var route: Array[Vector2i] = _assign_route(slot)
	var speed: float = _enemy_speed(type_id, wave)
	enemies[slot].append({
		"id": _next_enemy_id, "hp": hp, "max_hp": hp,
		"type_id": type_id, "base_speed": speed, "speed": speed,
		"slowed": false, "slow_remaining": 0.0,
		"damage": _enemy_types[type_id]["base_damage"],
		"route": route, "progress": progress, "pos": _position(route, progress),
	})
	_enemy_spawn_times[_next_enemy_id] = spawn_time
	_next_enemy_id += 1


func _position(route: Array, progress: float) -> Vector2:
	var last: int = route.size() - 1
	if progress >= last:
		return Vector2(route[last])
	var index: int = floori(progress)
	return Vector2(route[index]).lerp(Vector2(route[index + 1]), progress - index)


func _attack(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		var definition: Dictionary = _tower_types[tower["type_id"]]
		if tower["evolution"] != "":
			if definition["evolutions"][tower["evolution"]]["continuous"]:
				_attack_continuous(slot, tower, definition["range"], delta)
			else:
				_attack_pulses(slot, tower, definition["range"], delta)
			continue
		tower["cooldown"] = maxf(0.0, tower["cooldown"] - delta)
		if tower["cooldown"] > 0.0:
			continue
		var target_index: int = _target(slot, tower, definition["range"])
		if target_index < 0:
			continue
		var enemy: Dictionary = enemies[slot][target_index]
		tower["target_id"] = enemy["id"]
		tower["aim"] = enemy["pos"]
		tower["shot"] += 1
		tower["cooldown"] = tower["interval"]
		tower["bounce_active"] = false
		tower["secondary_target_id"] = -1
		if definition["area_attack"]:
			# Reverse traversal permits removal in place without missing a victim.
			for index: int in range(enemies[slot].size() - 1, -1, -1):
				if cell_in_range(tower["cell"], Vector2i(enemies[slot][index]["pos"].round()), definition["range"]):
					_hit(slot, tower, index)
		else:
			_hit(slot, tower, target_index)
			if tower["special_upgraded"] and definition["special_upgrade"] == "second_archer":
				var secondary_index: int = _target(slot, tower, definition["range"], tower["secondary_mode"], tower["target_id"])
				if secondary_index >= 0:
					tower["secondary_target_id"] = enemies[slot][secondary_index]["id"]
					tower["secondary_aim"] = enemies[slot][secondary_index]["pos"]
					tower["secondary_shot"] += 1
					_hit(slot, tower, secondary_index)
			elif tower["special_upgraded"] and definition["special_upgrade"] == "bounce":
				var bounce_index: int = _bounce_target(slot, tower["aim"], tower["target_id"])
				if bounce_index >= 0:
					tower["bounce_active"] = true
					tower["bounce_aim"] = enemies[slot][bounce_index]["pos"]
					_hit(slot, tower, bounce_index, ceili(float(tower["damage"]) * TowerDefinition.BOUNCE_DAMAGE_MULTIPLIER))


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
				hit_any = true
			_hit(slot, tower, index)
		if hit_any:
			tower["shot"] += 1


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
		var total: float = float(fractions.get(enemy["id"], 0.0)) + float(tower["damage"]) * exposure
		# Only whole HP reaches replicated state; retain sub-HP credit for this
		# exact pair. The epsilon corrects floating-point addition at whole HP.
		var damage: int = floori(total + 0.000000001)
		fractions[enemy["id"]] = maxf(0.0, total - damage)
		if damage > 0:
			_hit(slot, tower, index, damage)


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


func _retire_enemy(enemy_id: int) -> void:
	_enemy_spawn_times.erase(enemy_id)
	_slow_motion.erase(enemy_id)
	for tower_id: int in _rune_damage:
		_rune_damage[tower_id].erase(enemy_id)
	for tower_id: int in _continuous_damage:
		_continuous_damage[tower_id].erase(enemy_id)


func _hit(slot: int, tower: Dictionary, enemy_index: int, damage: int = -1) -> void:
	var enemy: Dictionary = enemies[slot][enemy_index]
	var hit_damage: int = mini(int(enemy["hp"]), int(tower["damage"]) if damage < 0 else damage)
	enemy["hp"] -= hit_damage
	if _tower_types[tower["type_id"]]["evolutions"].has("boulders"):
		var tower_id: int = tower["id"]
		if not _rune_damage.has(tower_id):
			_rune_damage[tower_id] = {}
		var credit: Dictionary = _rune_damage[tower_id]
		credit[enemy["id"]] = int(credit.get(enemy["id"], 0)) + hit_damage
		if hit_damage > 0 and tower["evolution"] == "boulders" and tower["freeze_upgraded"] and int(credit[enemy["id"]]) >= ceili(float(enemy["max_hp"]) * TowerDefinition.FREEZE_DAMAGE_THRESHOLD):
			enemy["slowed"] = true
			enemy["slow_remaining"] = TowerDefinition.FREEZE_DURATION
			enemy["speed"] = float(enemy["base_speed"]) * TowerDefinition.FREEZE_SPEED_MULTIPLIER
	if enemy["hp"] <= 0:
		tower["kills"] += 1
		coins[slot] += _rules.kill_bounty
		_retire_enemy(enemy["id"])
		enemies[slot].remove_at(enemy_index)


func _bounce_target(slot: int, origin: Vector2, excluded_id: int) -> int:
	var best: int = -1
	var best_distance: float = INF
	var best_id: int = 0
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if enemy["id"] == excluded_id or int(enemy["hp"]) <= 0:
			continue
		var distance: float = origin.distance_squared_to(enemy["pos"])
		var id: int = enemy["id"]
		if best < 0 or distance < best_distance or (distance == best_distance and id < best_id):
			best = index
			best_distance = distance
			best_id = id
	return best


# Scan in place rather than allocating or sorting candidates for each tower.
func _target(slot: int, tower: Dictionary, range_cells: float, mode: int = -1, excluded_id: int = -1) -> int:
	var best: int = -1
	var best_score: float = -INF
	var best_id: int = 0
	var center: Vector2 = Vector2(tower["cell"])
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if int(enemy["id"]) == excluded_id or not cell_in_range(tower["cell"], Vector2i(enemy["pos"].round()), range_cells):
			continue
		var distance_squared: float = center.distance_squared_to(enemy["pos"])
		var score: float
		match int(tower["mode"]) if mode < 0 else mode:
			TargetMode.CLOSEST:
				score = -distance_squared
			TargetMode.STRONGEST:
				score = float(enemy["hp"])
			_:
				score = enemy["progress"]
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
			base_health[slot] = maxi(0, base_health[slot] - int(enemies[slot][index]["damage"]))
			_retire_enemy(enemies[slot][index]["id"])
			enemies[slot].remove_at(index)
		index -= 1
