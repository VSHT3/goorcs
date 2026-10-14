extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_commands_and_snapshots()
	_test_targeting_policies()
	_test_range_and_ties()
	_test_routes_and_both_board_clear()
	_test_kills_and_persistence()
	_test_simultaneous_and_ordinary_outcomes()
	if failures == 0:
		print("PASS: combat commands, detached snapshots, targeting/range/ties/current HP, captured movement, kills/leaks, two-board clears, persistent waves, and frozen outcomes")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 10
	rules.enemy_health = 8
	rules.enemy_speed = 1.0
	rules.enemies_per_wave = 3
	rules.spawn_interval = 0.5
	rules.tower_damage = 2
	rules.tower_range = 20.0
	rules.tower_interval = 0.5
	rules.health_growth = 2
	return rules


func _line(length: int) -> Array:
	var route: Array = []
	for x: int in range(length + 1):
		route.append(Vector2i(x, 0))
	return route


func _routes(first: int = 10, second: int = 10) -> Array[Array]:
	return [_line(first), _line(second)]


func _run_wave(combat: MatchCombat, ticks: int = 2400) -> void:
	for tick: int in range(ticks):
		if combat.phase != MatchCombat.Phase.WAVE:
			return
		combat.advance(1.0 / 60.0)
	_check(combat.phase != MatchCombat.Phase.WAVE, "Wave completes within its deterministic simulation deadline")


func _test_commands_and_snapshots() -> void:
	var combat := MatchCombat.new(_rules())
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.wave == 0 and combat.base_health == [10, 10], "New combat begins planning with two full bases")
	_check(not combat.advance(1.0), "Planning has no autonomous simulation")
	_check(not combat.build(-1, Vector2i.ZERO, 0) and not combat.build(2, Vector2i.ZERO, 0) and not combat.build(0, Vector2i.ZERO, 3), "Invalid owner or targeting mode is rejected")
	_check(combat.build(0, Vector2i(2, 1), MatchCombat.TargetMode.FURTHEST), "Free placement succeeds during planning")
	_check(combat.has_tower(0, Vector2i(2, 1)) and not combat.has_tower(1, Vector2i(2, 1)), "Tower cells belong to their own board")
	_check(not combat.build(0, Vector2i(2, 1), 0), "Duplicate cell placement is rejected")
	var id: int = combat.towers[0][0]["id"]
	_check(not combat.set_targeting(1, id, 1) and not combat.set_targeting(0, id, -1) and not combat.set_targeting(0, id, 0), "Wrong board, invalid mode, and no-op targeting leave towers untouched")
	_check(combat.set_targeting(0, id, MatchCombat.TargetMode.CLOSEST), "Existing own tower changes targeting")
	var invalid_routes: Array[Array] = [[], _line(10)]
	_check(not combat.start_wave(invalid_routes) and combat.wave == 0, "Missing route cannot start or increment a wave")
	_check(combat.start_wave(_routes()) and not combat.start_wave(_routes()), "Only planning can start a wave")
	_check(combat.build(1, Vector2i(2, 1), MatchCombat.TargetMode.STRONGEST), "Free placement remains available during combat")
	combat.advance(0.1)
	var copy: Dictionary = combat.snapshot()
	copy["health"][0] = 0
	copy["towers"][0][0]["mode"] = 2
	copy["enemies"][0][0]["hp"] = -100
	copy["spawned"][0] = 99
	copy["rules"]["damage"] = 999
	var fresh: Dictionary = combat.snapshot()
	_check(fresh["health"][0] == 10 and fresh["towers"][0][0]["mode"] == 1 and fresh["enemies"][0][0]["hp"] == 6 and fresh["spawned"][0] == 1 and fresh["rules"]["damage"] == 2, "Snapshot nested arrays/dictionaries are detached from authoritative state")
	_check(not combat.advance(0.0) and not combat.advance(-1.0), "Nonpositive ticks cannot mutate combat")


func _test_targeting_policies() -> void:
	var expected: Array[Array] = [[4, 8, 8], [6, 8, 6], [6, 6, 8]]
	for mode: int in range(3):
		var combat := MatchCombat.new(_rules())
		combat.build(0, Vector2i(0, 1), MatchCombat.TargetMode.FURTHEST)
		combat.start_wave(_routes())
		combat.advance(0.1)
		var first_id: int = combat.enemies[0][0]["id"]
		_check(combat.enemies[0][0]["hp"] == 6, "First shot damages a naturally spawned enemy")
		if mode != MatchCombat.TargetMode.FURTHEST:
			combat.set_targeting(0, combat.towers[0][0]["id"], mode)
		combat.advance(1.0)
		var health: Array[int] = []
		for enemy: Dictionary in combat.snapshot()["enemies"][0]:
			health.append(enemy["hp"])
		_check(health == expected[mode], "Policy %d produces its own observable damage distribution: %s" % [mode, health])
		var target_index: int = [0, 2, 1][mode]
		_check(combat.towers[0][0]["target_id"] == combat.enemies[0][target_index]["id"] and combat.towers[0][0]["shot"] == 2, "Policy %d publishes matching native instant-hit visual event" % mode)
		if mode == MatchCombat.TargetMode.STRONGEST:
			_check(combat.towers[0][0]["target_id"] != first_id and combat.enemies[0][0]["max_hp"] == combat.enemies[0][1]["max_hp"], "Strongest compares current HP, not equal starting maximum HP")


func _test_range_and_ties() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.0
	rules.enemies_per_wave = 1
	rules.tower_range = 3.0
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(0, 3), 0)
	combat.build(0, Vector2i(1, 3), 0)
	combat.start_wave(_routes())
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == 6 and combat.towers[0][0]["shot"] == 1 and combat.towers[0][1]["shot"] == 0, "Circular range includes exact boundary and excludes a nearby diagonal outside it")
	for mode: int in range(3):
		rules = _rules()
		rules.enemy_speed = 0.0
		rules.spawn_interval = 0.0
		combat = MatchCombat.new(rules)
		combat.start_wave(_routes())
		combat.advance(0.1)
		var smallest_id: int = combat.enemies[0][0]["id"]
		combat.enemies[0].reverse()
		combat.build(0, Vector2i(0, 1), mode)
		combat.advance(0.1)
		_check(combat.towers[0][0]["target_id"] == smallest_id and combat.enemies[0][2]["hp"] == 6, "Policy %d breaks equal candidate scores by smallest ID rather than array order" % mode)


func _test_routes_and_both_board_clear() -> void:
	var rules := _rules()
	rules.enemies_per_wave = 1
	var combat := MatchCombat.new(rules)
	var routes: Array[Array] = [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], _line(5)]
	combat.start_wave(routes)
	routes[0][1] = Vector2i(99, 99)
	routes[1].clear()
	combat.advance(0.5)
	_check(combat.enemies[0][0]["pos"].is_equal_approx(Vector2(0.5, 0.0)), "Enemy interpolates along an immutable captured route")
	combat.advance(1.0)
	_check(combat.enemies[0][0]["pos"].is_equal_approx(Vector2(1.0, 0.5)) and is_equal_approx(combat.enemies[0][0]["progress"], 1.5), "Corner interpolation uses route distance, not straight-line base distance")
	combat.advance(1.5)
	_check(combat.enemies[0].is_empty() and combat.base_health == [9, 10] and combat.phase == MatchCombat.Phase.WAVE, "A clear short board cannot finish while the other board has an enemy")
	combat.advance(2.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [9, 9], "Only both cleared boards return to planning")
	_check(combat.wave == 1 and combat.snapshot()["spawned"] == [1, 1], "Wave and spawn totals remain readable after completion")
	# A gap with no alive enemies is not a clear while scheduled spawns remain.
	rules.spawn_interval = 4.0
	rules.enemies_per_wave = 2
	combat = MatchCombat.new(rules)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.enemies[0].is_empty() and combat.enemies[1].is_empty() and combat.phase == MatchCombat.Phase.WAVE and combat.snapshot()["spawned"] == [1, 1], "Unspawned scheduled enemies keep the wave active even with both boards temporarily empty")
	_run_wave(combat)
	_check(combat.base_health == [8, 8] and combat.snapshot()["spawned"] == [2, 2], "Both boards receive the same regular scheduled wave")


func _test_kills_and_persistence() -> void:
	var rules := _rules()
	rules.enemies_per_wave = 2
	rules.enemy_health = 2
	rules.health_growth = 2
	rules.tower_damage = 20
	rules.tower_interval = 0.1
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(1, 1), 0)
	combat.start_wave(_routes(2, 2))
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [10, 8], "Killed enemies never leak; unprotected board keeps accumulated damage")
	_check(combat.enemies[0].is_empty() and combat.enemies[1].is_empty() and combat.towers[0][0]["shot"] == 2, "Both wave enemy lists clear and tower shot history persists")
	var tower_id: int = combat.towers[0][0]["id"]
	var before: int = combat.towers[0][0]["shot"]
	_check(not combat.advance(10.0) and combat.wave == 1 and combat.base_health == [10, 8], "Cleared waves wait in planning rather than starting automatically")
	combat.start_wave(_routes(2, 2))
	combat.advance(0.1)
	_check(combat.wave == 2 and combat.enemies[1][0]["max_hp"] == 4 and combat.snapshot()["rules"]["enemy_health"] == 4, "Each next wave applies configured enemy health growth")
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [10, 6] and combat.towers[0][0]["id"] == tower_id and combat.towers[0][0]["shot"] == before + 2, "Bases, fixed-stat towers, and monotonic shot counters persist across waves")
	# A lethal hit at the endpoint is resolved before leak bookkeeping.
	rules.enemies_per_wave = 1
	combat = MatchCombat.new(rules)
	combat.build(0, Vector2i(1, 1), 0)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.base_health == [10, 9] and combat.phase == MatchCombat.Phase.PLANNING, "Instant-hit death at the endpoint cannot damage that base")


func _test_simultaneous_and_ordinary_outcomes() -> void:
	var rules := _rules()
	rules.base_health = 1
	rules.enemies_per_wave = 2
	rules.spawn_interval = 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 982451653
	var expected_random := RandomNumberGenerator.new()
	expected_random.seed = random.seed
	var expected_winner: int = expected_random.randi_range(0, 1)
	var combat := MatchCombat.new(rules, random)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.base_health == [0, 0] and combat.coin_flip and combat.winner == expected_winner, "Both-board leaks are batched, health clamps at zero, and one seeded coin flip resolves same-tick destruction")
	_check(random.state == expected_random.state, "Simultaneous destruction consumes exactly one host RNG draw")
	var frozen: Dictionary = combat.snapshot()
	var state: int = random.state
	for tick: int in range(5):
		_check(not combat.advance(1.0), "Finished outcome cannot advance or reroll")
	_check(not combat.start_wave(_routes()) and not combat.build(0, Vector2i(0, 1), 0) and not combat.set_targeting(0, 1, 1), "Finished combat rejects every mutation command")
	_check(combat.snapshot() == frozen and random.state == state, "Terminal snapshot and RNG state remain frozen")
	# Different route lengths destroy only the first base on this tick.
	random = RandomNumberGenerator.new()
	random.seed = 32452843
	state = random.state
	combat = MatchCombat.new(rules, random)
	combat.start_wave(_routes(1, 2))
	combat.advance(1.0)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.base_health == [0, 1] and combat.winner == 1 and not combat.coin_flip and random.state == state, "An ordinary surviving slot wins without consuming randomness")
	# The opposite board can win too; it is not a hard-coded host outcome.
	combat = MatchCombat.new(rules, random)
	combat.start_wave(_routes(2, 1))
	combat.advance(1.0)
	_check(combat.base_health == [1, 0] and combat.winner == 0 and not combat.coin_flip and random.state == state, "Opposite ordinary outcome also leaves host RNG untouched")
