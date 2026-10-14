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
		return [_send_queues[0].size(), _send_queues[1].size()]
var winner: int = -1
var coin_flip: bool = false
var towers: Array[Array] = [[], []]
var enemies: Array[Array] = [[], []]

var _rules: CombatRules
# Captured once from resources so commands, attacks, and snapshots share host-owned stats.
var _tower_types: Dictionary = {}
var _enemy_types: Dictionary = {}
var _send_queues: Array[Array] = [[], []]
var _random: RandomNumberGenerator
var _routes: Array[Array] = [[], []]
var _spawned: Array[int] = [0, 0]
var _elapsed: float = 0.0
var _next_tower_id: int = 1
var _next_enemy_id: int = 1


func _init(rules: CombatRules, random: RandomNumberGenerator = null) -> void:
	_rules = rules
	_random = random
	if _random == null:
		_random = RandomNumberGenerator.new()
		_random.randomize()
	base_health = [rules.base_health, rules.base_health]
	coins = [rules.starting_coins, rules.starting_coins]
	for definition: EnemyDefinition in rules.enemy_definitions:
		if definition == null:
			push_error("Combat enemy_definitions contains a null entry")
			continue
		var type_id: String = String(definition.id)
		if type_id.is_empty() or definition.title.is_empty() or not is_finite(definition.health_multiplier) or definition.health_multiplier <= 0.0 or not is_finite(definition.speed_multiplier) or definition.speed_multiplier <= 0.0 or definition.send_cost <= 0 or definition.send_income < 0:
			push_error("Invalid combat enemy definition '%s': positive multipliers/price and nonnegative income are required" % type_id)
			continue
		if _enemy_types.has(type_id):
			push_error("Duplicate combat enemy definition '%s': keeping the first valid definition" % type_id)
			continue
		_enemy_types[type_id] = {
			"title": definition.title, "health_multiplier": definition.health_multiplier,
			"speed_multiplier": definition.speed_multiplier,
			"send_cost": definition.send_cost, "send_income": definition.send_income,
		}
	for definition: TowerDefinition in rules.tower_definitions:
		if definition == null:
			push_error("Combat tower_definitions contains a null entry")
			continue
		if definition.reward == null:
			push_error("Combat tower definition '%s' has no reward" % definition.resource_path)
			continue
		var type_id: String = String(definition.reward.id)
		if type_id.is_empty() or definition.damage <= 0 or not is_finite(definition.range_cells) or definition.range_cells <= 0.0 or not is_finite(definition.interval) or definition.interval <= 0.0 or definition.cost <= 0 or definition.damage_upgrade_cost <= 0 or definition.damage_upgrade_bonus <= 0 or definition.speed_upgrade_cost <= 0 or not is_finite(definition.speed_upgrade_multiplier) or definition.speed_upgrade_multiplier <= 0.0 or definition.speed_upgrade_multiplier >= 1.0:
			push_error("Invalid combat tower definition '%s' (%s): positive stats/prices and speed multiplier between zero and one are required" % [type_id, definition.resource_path])
			continue
		if _tower_types.has(type_id):
			push_error("Duplicate combat tower definition '%s': keeping the first valid definition" % type_id)
			continue
		_tower_types[type_id] = {
			"title": definition.reward.title, "damage": definition.damage,
			"range": definition.range_cells, "interval": definition.interval,
			"cost": definition.cost, "damage_upgrade_cost": definition.damage_upgrade_cost,
			"damage_upgrade_bonus": definition.damage_upgrade_bonus,
			"speed_upgrade_cost": definition.speed_upgrade_cost,
			"speed_upgrade_multiplier": definition.speed_upgrade_multiplier,
			"area_attack": definition.area_attack,
		}


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


func upgrade_tower(slot: int, tower_id: int, upgrade: String) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or (upgrade != "damage" and upgrade != "speed"):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["id"] != tower_id:
			continue
		var flag: String = upgrade + "_upgraded"
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var cost: int = definition[upgrade + "_upgrade_cost"]
		if tower[flag] or coins[slot] < cost:
			return false
		coins[slot] -= cost
		tower[flag] = true
		tower["invested"] += cost
		tower["sell_value"] = _sell_value(tower["invested"])
		if upgrade == "damage":
			tower["damage"] += definition["damage_upgrade_bonus"]
		else:
			tower["interval"] *= definition["speed_upgrade_multiplier"]
			# Accelerate the current reload, but never grant an immediate extra shot.
			tower["cooldown"] *= definition["speed_upgrade_multiplier"]
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
		towers[slot].remove_at(index)
		return true
	return false


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


func send_enemy(slot: int, type_id: StringName) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _enemy_types.has(String(type_id)):
		return false
	var definition: Dictionary = _enemy_types[String(type_id)]
	var cost: int = definition["send_cost"]
	if coins[slot] < cost:
		return false
	var target: int = 1 - slot
	# Acceptance purchases either immediate delivery or a typed next-wave order.
	# Neither editable routes nor client-provided stats enter this transaction.
	coins[slot] -= cost
	income[slot] += int(definition["send_income"])
	if _sends_open():
		_spawn_enemy(target, String(type_id), 0.0)
	else:
		_send_queues[target].append(String(type_id))
	return true


func _sends_open() -> bool:
	return phase == Phase.WAVE and _elapsed < _rules.send_cutoff_seconds


func start_wave(routes: Array[Array]) -> bool:
	if phase != Phase.PLANNING or routes.size() != 2 or routes[0].size() < 2 or routes[1].size() < 2:
		return false
	_routes = routes.duplicate(true)
	_spawned = [0, 0]
	_elapsed = 0.0
	wave += 1
	phase = Phase.WAVE
	for slot: int in range(2):
		for type_id: String in _send_queues[slot]:
			_spawn_enemy(slot, type_id, 0.0)
		_send_queues[slot].clear()
	return true


# Only the host calls this, using fixed physics deltas. All towers hit immediately;
# the shot counter and aim position are cosmetic events for snapshot consumers.
func advance(delta: float) -> bool:
	if phase != Phase.WAVE or delta <= 0.0:
		return false
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
	elif _spawned[0] == _wave_count() and _spawned[1] == _wave_count() and enemies[0].is_empty() and enemies[1].is_empty():
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
		"send_queues": _send_queues.duplicate(true),
		"enemy_types": _enemy_types_snapshot(),
		"sends_open": _sends_open(),
		"towers": towers.duplicate(true), "enemies": enemies.duplicate(true),
		"spawned": _spawned.duplicate(), "total": _wave_count(),
		"tower_types": _tower_types.duplicate(true),
		"rules": {
			"enemy_speed": _wave_speed(wave), "enemy_health": _wave_health(wave),
			"starting_coins": _rules.starting_coins, "kill_bounty": _rules.kill_bounty,
			"wave_reward": _rules.wave_reward + maxi(1, wave) * _rules.wave_reward_growth,
			"base_health": _rules.base_health,
			"send_cutoff_seconds": _rules.send_cutoff_seconds,
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


func _wave_count() -> int:
	return _rules.enemies_per_wave + maxi(0, wave - 1) * _rules.count_growth


func _valid_slot(slot: int) -> bool:
	return slot == 0 or slot == 1


func _valid_mode(mode: int) -> bool:
	return mode >= TargetMode.FURTHEST and mode <= TargetMode.STRONGEST


func _move_enemies(slot: int, delta: float) -> void:
	for enemy: Dictionary in enemies[slot]:
		enemy["progress"] += float(enemy["speed"]) * delta
		enemy["pos"] = _position(slot, enemy["progress"])


func _spawn_enemies(slot: int) -> void:
	var total: int = _wave_count()
	var speed: float = _enemy_speed("grunt", wave)
	while _spawned[slot] < total:
		var spawn_time: float = _spawned[slot] * _rules.spawn_interval
		if spawn_time > _elapsed:
			break
		# Account for the fraction of this tick after the scheduled spawn time.
		var progress: float = (_elapsed - spawn_time) * speed
		_spawn_enemy(slot, "grunt", progress)
		_spawned[slot] += 1


func _spawn_enemy(slot: int, type_id: String, progress: float) -> void:
	var hp: int = _enemy_health(type_id, wave)
	enemies[slot].append({
		"id": _next_enemy_id, "hp": hp, "max_hp": hp,
		"type_id": type_id, "speed": _enemy_speed(type_id, wave),
		"progress": progress, "pos": _position(slot, progress),
	})
	_next_enemy_id += 1


func _position(slot: int, progress: float) -> Vector2:
	var last: int = _routes[slot].size() - 1
	if progress >= last:
		return Vector2(_routes[slot][last])
	var index: int = floori(progress)
	return Vector2(_routes[slot][index]).lerp(Vector2(_routes[slot][index + 1]), progress - index)


func _attack(slot: int, delta: float) -> void:
	for tower: Dictionary in towers[slot]:
		tower["cooldown"] = maxf(0.0, tower["cooldown"] - delta)
		if tower["cooldown"] > 0.0:
			continue
		var definition: Dictionary = _tower_types[tower["type_id"]]
		var target_index: int = _target(slot, tower, definition["range"])
		if target_index < 0:
			continue
		var enemy: Dictionary = enemies[slot][target_index]
		tower["target_id"] = enemy["id"]
		tower["aim"] = enemy["pos"]
		tower["shot"] += 1
		tower["cooldown"] = tower["interval"]
		if definition["area_attack"]:
			# Reverse traversal permits removal in place without missing a victim.
			for index: int in range(enemies[slot].size() - 1, -1, -1):
				if cell_in_range(tower["cell"], Vector2i(enemies[slot][index]["pos"].round()), definition["range"]):
					_hit(slot, tower, index)
		else:
			_hit(slot, tower, target_index)


func _hit(slot: int, tower: Dictionary, enemy_index: int) -> void:
	var enemy: Dictionary = enemies[slot][enemy_index]
	enemy["hp"] -= tower["damage"]
	if enemy["hp"] <= 0:
		tower["kills"] += 1
		coins[slot] += _rules.kill_bounty
		enemies[slot].remove_at(enemy_index)


# Scan in place rather than allocating or sorting candidates for each tower.
func _target(slot: int, tower: Dictionary, range_cells: float) -> int:
	var best: int = -1
	var best_score: float = -INF
	var best_id: int = 0
	var center: Vector2 = Vector2(tower["cell"])
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		if not cell_in_range(tower["cell"], Vector2i(enemy["pos"].round()), range_cells):
			continue
		var distance_squared: float = center.distance_squared_to(enemy["pos"])
		var score: float
		match tower["mode"]:
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
	var last: int = _routes[slot].size() - 1
	while index >= 0:
		if enemies[slot][index]["progress"] >= last:
			base_health[slot] = maxi(0, base_health[slot] - 1)
			enemies[slot].remove_at(index)
		index -= 1
