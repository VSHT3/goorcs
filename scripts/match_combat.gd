class_name MatchCombat
extends RefCounted

enum Phase { PLANNING, WAVE, FINISHED }
enum TargetMode { FURTHEST, CLOSEST, STRONGEST }

var phase: Phase = Phase.PLANNING
var wave: int = 0
var base_health: Array[int] = []
var winner: int = -1
var coin_flip: bool = false
var towers: Array[Array] = [[], []]
var enemies: Array[Array] = [[], []]

var _rules: CombatRules
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


func build(slot: int, cell: Vector2i, mode: int) -> bool:
	if phase == Phase.FINISHED or not _valid_slot(slot) or not _valid_mode(mode) or has_tower(slot, cell):
		return false
	towers[slot].append({
		"id": _next_tower_id, "cell": cell, "mode": mode, "cooldown": 0.0,
		"target_id": -1, "shot": 0, "aim": Vector2(cell),
	})
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


func has_tower(slot: int, cell: Vector2i) -> bool:
	if not _valid_slot(slot):
		return false
	for tower: Dictionary in towers[slot]:
		if tower["cell"] == cell:
			return true
	return false


func start_wave(routes: Array[Array]) -> bool:
	if phase != Phase.PLANNING or routes.size() != 2 or routes[0].size() < 2 or routes[1].size() < 2:
		return false
	_routes = routes.duplicate(true)
	_spawned = [0, 0]
	_elapsed = 0.0
	wave += 1
	phase = Phase.WAVE
	return true


# Only the host calls this, using fixed physics deltas. Arrows hit immediately;
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
	elif _spawned[0] == _rules.enemies_per_wave and _spawned[1] == _rules.enemies_per_wave and enemies[0].is_empty() and enemies[1].is_empty():
		phase = Phase.PLANNING
	return true


func snapshot() -> Dictionary:
	return {
		"phase": phase, "wave": wave, "health": base_health.duplicate(),
		"winner": winner, "coin_flip": coin_flip,
		"towers": towers.duplicate(true), "enemies": enemies.duplicate(true),
		"spawned": _spawned.duplicate(), "total": _rules.enemies_per_wave,
		"rules": {
			"range": _rules.tower_range, "damage": _rules.tower_damage,
			"interval": _rules.tower_interval, "enemy_speed": _rules.enemy_speed,
			"enemy_health": _rules.enemy_health + maxi(0, wave - 1) * _rules.health_growth,
			"base_health": _rules.base_health,
		},
	}


func _valid_slot(slot: int) -> bool:
	return slot == 0 or slot == 1


func _valid_mode(mode: int) -> bool:
	return mode >= TargetMode.FURTHEST and mode <= TargetMode.STRONGEST


func _move_enemies(slot: int, delta: float) -> void:
	for enemy: Dictionary in enemies[slot]:
		enemy["progress"] += _rules.enemy_speed * delta
		enemy["pos"] = _position(slot, enemy["progress"])


func _spawn_enemies(slot: int) -> void:
	while _spawned[slot] < _rules.enemies_per_wave:
		var spawn_time: float = _spawned[slot] * _rules.spawn_interval
		if spawn_time > _elapsed:
			break
		# Account for the fraction of this tick after the scheduled spawn time.
		var progress: float = (_elapsed - spawn_time) * _rules.enemy_speed
		var hp: int = _rules.enemy_health + (wave - 1) * _rules.health_growth
		enemies[slot].append({
			"id": _next_enemy_id, "hp": hp, "max_hp": hp,
			"progress": progress, "pos": _position(slot, progress),
		})
		_next_enemy_id += 1
		_spawned[slot] += 1


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
		var target_index: int = _target(slot, tower)
		if target_index < 0:
			continue
		var enemy: Dictionary = enemies[slot][target_index]
		tower["target_id"] = enemy["id"]
		tower["aim"] = enemy["pos"]
		tower["shot"] += 1
		tower["cooldown"] = _rules.tower_interval
		enemy["hp"] -= _rules.tower_damage
		if enemy["hp"] <= 0:
			enemies[slot].remove_at(target_index)


# Scan in place rather than allocating or sorting candidates for each tower.
func _target(slot: int, tower: Dictionary) -> int:
	var best: int = -1
	var best_score: float = -INF
	var best_id: int = 0
	var center: Vector2 = Vector2(tower["cell"])
	var range_squared: float = _rules.tower_range * _rules.tower_range
	for index: int in range(enemies[slot].size()):
		var enemy: Dictionary = enemies[slot][index]
		var distance_squared: float = center.distance_squared_to(enemy["pos"])
		if distance_squared > range_squared:
			continue
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
