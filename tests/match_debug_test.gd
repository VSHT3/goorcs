extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_authority()
	_test_planning_transaction()
	_test_currency_only()
	_test_wave_jump()
	_test_growth_and_retention()
	_test_bounds_and_terminal()
	await process_frame
	if failures == 0:
		print("PASS: solo-only debug authority, atomic Coin/Shard bounds, currency-only state/RNG preservation, round reset without rewards, transient cancellation, milestone growth and permanent-state retention")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _new_model(with_route: bool = true, with_rolls: bool = false) -> MatchPlanning:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	var rules := CombatRules.new()
	rules.starting_coins = 2000
	rules.starting_reroll_currency = 200
	if with_rolls:
		rules.roll_rules = preload("res://resources/combat/prototype.tres").roll_rules.duplicate(true) as TowerRollRules
	rules.base_health = 1000
	rules.wave_weight = 6
	rules.wave_weight_growth = 0
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition]
	rules.catalog.enemies[0].send_first_wave = 1
	rules.enemy_speed = 1.0
	rules.speed_growth_fraction = 0.0
	rules.health_growth = 0
	var tower := rules.catalog.towers[0].duplicate() as TowerDefinition
	tower.range_cells = 0.1
	rules.catalog.towers = [tower]
	planning.combat_rules = rules
	root.add_child(planning)
	planning.start_singleplayer()
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Debug fixture explicitly admits its authored tower")
	planning.set_physics_process(false)
	if with_route:
		for x: int in range(1, 13):
			planning.request_edit(0, Vector2i(x, 4), true)
	return planning


func _dispose(planning: MatchPlanning) -> void:
	var session: MultiplayerSession = planning.session
	planning.free()
	session.free()


func _make_host(planning: MatchPlanning) -> void:
	# Synthetic transport identity exercises local authority without socket setup.
	planning.singleplayer = false
	planning.session.is_host = true
	planning.session.state = MultiplayerSession.State.CONNECTED
	planning._active_peer_id = 77


func _build_upgraded(planning: MatchPlanning) -> void:
	planning.build_tower(0, Vector2i(0, 0), &"arrow_tower", MatchCombat.TargetMode.CLOSEST)
	var tower_id: int = planning.combat["towers"][0][0]["id"]
	for upgrade: String in ["damage", "speed", "special"]:
		planning.upgrade_tower(0, tower_id, upgrade)
	planning.set_targeting(0, tower_id, MatchCombat.TargetMode.STRONGEST)


func _permanent_tower(tower: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["id", "type_id", "cell", "mode", "damage", "interval", "damage_upgraded", "speed_upgraded", "special_upgraded", "evolution", "freeze_upgraded", "invested", "sell_value", "kills"]:
		if tower.has(key):
			result[key] = tower[key]
	return result


func _test_authority() -> void:
	var planning: MatchPlanning = _new_model()
	_check(planning.can_debug(), "An active solo match exposes the local debug API")
	_make_host(planning)
	planning._host_combat.coins = [111, 222]
	planning._host_combat.reroll_currency = [13, 29]
	planning._publish_snapshot()
	var untouched: Dictionary = planning._snapshot().duplicate(true)
	_check(not planning.can_debug() and not planning.debug_set_values(4, 777, 61) and planning._snapshot() == untouched, "Multiplayer hosts get no round / Coin / Shard editing")
	_check(planning._set_debug_values(4, 777, 61), "The host-side fixture setter still applies a validated jump")
	_check(planning.combat["coins"] == [777, 222] and planning.combat["reroll_currency"] == [61, 29] and planning.combat["wave"] == 3 and planning.combat["phase"] == MatchCombat.Phase.PLANNING, "A host jump changes only slot zero balances and grants no wave or Shard reward to the guest")
	planning.session.is_host = false
	var before: Dictionary = planning._snapshot().duplicate(true)
	_check(not planning.can_debug() and not planning._set_debug_values(9, 999, 999) and planning._snapshot() == before, "A synthetic connected guest cannot mutate authoritative debug values")
	planning.session.is_host = true
	planning.active = false
	planning.selecting_loadout = true
	before = planning._snapshot().duplicate(true)
	_check(not planning.can_debug() and not planning._set_debug_values(9, 999, 999) and planning._snapshot() == before, "Inactive hosts cannot use the debug API")
	planning.active = true
	planning.selecting_loadout = false
	planning.session.state = MultiplayerSession.State.HOSTING
	_check(not planning.can_debug() and not planning._set_debug_values(9, 999, 999), "A host still waiting for connection cannot alter a match")
	_dispose(planning)
	planning = _new_model()
	before = planning._snapshot().duplicate(true)
	planning._apply_command(2, "debug", 1, Vector2i.ZERO, true)
	planning._apply_tower_command(2, "debug", 1, Vector2i.ZERO, -1, 9, "999")
	_check(planning._snapshot() == before, "Existing guest planning and tower command dispatchers provide no debug command bypass")
	_dispose(planning)


func _test_planning_transaction() -> void:
	var planning: MatchPlanning = _new_model()
	_build_upgraded(planning)
	planning.send_enemy(0, &"grunt")
	planning._host_combat.base_health = [97, 83]
	planning._host_combat.wave = 1
	planning._enter_planning()
	planning._publish_snapshot()
	planning._apply_command(2, "ready", 1, Vector2i.ZERO, true)
	planning.request_pacing("speed", true)
	planning._host_autoplay_votes = [true, false]
	planning._publish_snapshot()
	_check(planning.combat["ready_seconds_left"] > 0.0 and planning.ready_flags == [false, true] and planning.combat["queued_sends"] == [1, 1], "The planning fixture has a real deadline, committed slot and paid pending sends")
	var core: MatchCombat = planning._host_combat
	var layout: PathLayout = planning._host_layouts[0]
	var route: Array = planning.layouts[0].route.duplicate()
	var towers: Array = planning.combat["towers"].duplicate(true)
	var income: Array = planning.combat["income"].duplicate()
	var publications: Array[int] = [0]
	planning.changed.connect(func() -> void: publications[0] += 1)
	_check(planning.debug_set_values(3, 909, 57), "Round changes accept a complete validated debug transaction")
	_check(publications[0] == 1 and planning._host_combat == core and planning._host_layouts[0] == layout, "A debug jump reuses the real authoritative model and publishes one complete accepted snapshot")
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["wave"] == 2 and planning.combat["coins"] == [909, 909] and planning.combat["reroll_currency"] == [57, 57], "Solo jumps set the upcoming round and both mirrored Coin/Shard balances without clear grants")
	_check(planning.combat["health"] == [97, 83] and planning.combat["income"] == income and planning.layouts[0].route == route and planning.layouts[1].route == route, "Planning jumps preserve health, purchased send income and both real paths")
	for slot: int in range(2):
		_check(_permanent_tower(planning.combat["towers"][slot][0]) == _permanent_tower(towers[slot][0]), "Planning jumps preserve paid towers, upgrades, targeting, damage and investment")
	_check(planning.ready_flags == [false, false] and not planning.locked and planning.locked_routes == [[], []] and planning.combat["ready_seconds_left"] == -1.0 and not planning.is_physics_processing(), "Round changes release readiness, deadline, route locks and physics processing")
	_check(planning.combat["speed_votes"] == [false, false] and planning.combat["autoplay_votes"] == [false, false] and planning.combat["speed_multiplier"] == 1.0 and not planning.combat["autoplay"], "Round changes release both pacing vote sets")
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["send_queues"] == [[], []], "Round changes cancel paid pending deliveries without refunding or deleting recurring income")
	_dispose(planning)


func _random_states(planning: MatchPlanning) -> PackedInt64Array:
	var core: MatchCombat = planning._host_combat
	return PackedInt64Array([core._random.state, core._wave_random.state, core._timing_random.state, core._group_random.state, core._roll_random.state, core._drop_random.state])


func _test_currency_only() -> void:
	var planning: MatchPlanning = _new_model(true, true)
	planning.build_tower(0, Vector2i.ZERO, &"arrow_tower", MatchCombat.TargetMode.CLOSEST)
	var tower_id: int = planning.combat["towers"][0][0]["id"]
	_check(planning.reroll_tower(0, tower_id, "rarity") and planning.reroll_tower(0, tower_id, "attributes"), "Currency-only fixture owns accepted rolls and both reroll counters")
	_check(planning.debug_set_values(2, 1000, int(planning.combat["reroll_currency"][0])), "Currency-only fixture advances to ordinary planning without changing Shards")
	planning.send_enemy(0, &"grunt")
	planning._apply_command(2, "ready", 1, Vector2i.ZERO, true)
	planning.request_pacing("speed", true)
	var before: Dictionary = planning._snapshot().duplicate(true)
	var random_states: PackedInt64Array = _random_states(planning)
	_check(planning.debug_set_values(2, 321, int(planning.combat["reroll_currency"][0])), "The same upcoming planning round accepts a money-only change")
	before["combat"]["coins"] = [321, 321]
	_check(planning._snapshot() == before and _random_states(planning) == random_states and planning.is_physics_processing(), "Planning money-only changes retain paths, pending sends, readiness, deadline, pacing, tower rolls and RNG")
	_check(planning.debug_set_values(2, 321, 93), "The same upcoming planning round accepts a Shards-only change")
	before["combat"]["reroll_currency"] = [93, 93]
	_check(planning._snapshot() == before and _random_states(planning) == random_states and planning.is_physics_processing(), "Planning Shards-only changes retain committed Ready, real-time deadline, queues, pacing, attributes, reroll counters and every RNG stream")
	planning.submit_ready(true)
	planning._physics_process(0.1)
	planning.send_enemy(0, &"grunt")
	planning.send_enemy(0, &"grunt")
	planning.request_pacing("autoplay", true)
	before = planning._snapshot().duplicate(true)
	random_states = _random_states(planning)
	var elapsed: float = planning._host_combat._elapsed
	_check(not planning.combat["enemies"][0].is_empty() and planning.combat["phase"] == MatchCombat.Phase.WAVE, "Currency-only wave fixture contains active enemies")
	_check(planning.debug_set_values(2, 654, int(planning.combat["reroll_currency"][0])), "The same displayed active round accepts a money-only change")
	before["combat"]["coins"] = [654, 654]
	_check(planning._snapshot() == before and _random_states(planning) == random_states and planning._host_combat._elapsed == elapsed and planning.is_physics_processing(), "Wave money-only changes preserve phase, enemies, towers, cooldowns, queues, clock, locks, pacing and RNG")
	_check(planning.debug_set_values(2, 654, 147), "The same displayed active round accepts a Shards-only change")
	before["combat"]["reroll_currency"] = [147, 147]
	_check(planning._snapshot() == before and _random_states(planning) == random_states and planning._host_combat._elapsed == elapsed and planning.is_physics_processing(), "Wave Shards-only changes preserve live enemies, spawn/send timetables, Ready, cooldowns, pacing, accepted attributes/counters and RNG")
	_dispose(planning)


func _test_wave_jump() -> void:
	var planning: MatchPlanning = _new_model()
	_build_upgraded(planning)
	planning.submit_ready(true)
	planning._physics_process(0.1)
	for index: int in range(4):
		planning.send_enemy(0, &"grunt")
	planning.request_pacing("speed", true)
	planning.request_pacing("autoplay", true)
	var income: Array = planning.combat["income"].duplicate()
	var health: Array = planning.combat["health"].duplicate()
	var tower: Dictionary = _permanent_tower(planning.combat["towers"][0][0])
	_check(planning.combat["phase"] == MatchCombat.Phase.WAVE and not planning.combat["enemies"][0].is_empty() and planning.combat["queued_sends"][0] > 0, "Wave jump fixture contains regular enemies, live sends, pending deliveries and a real timetable")
	_make_host(planning)
	var guest_money: int = planning._host_combat.coins[1]
	var guest_shards: int = planning._host_combat.reroll_currency[1]
	var before: Dictionary = planning._snapshot().duplicate(true)
	var random_states: PackedInt64Array = _random_states(planning)
	var elapsed: float = planning._host_combat._elapsed
	for shards: int in [-1, 1000000001]:
		_check(not planning._set_debug_values(31, 432, shards) and planning._snapshot() == before and _random_states(planning) == random_states and planning._host_combat._elapsed == elapsed, "Invalid third values reject before abandoning live combat or applying growth")
	_check(planning._set_debug_values(7, 432, 73), "The host-side setter can cancel an active wave into a different upcoming round")
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["wave"] == 6 and planning.combat["coins"] == [432, guest_money] and planning.combat["reroll_currency"] == [73, guest_shards] and _random_states(planning) == random_states, "Wave cancellation sets exact host balances without clear rewards, drops, refunds, income payout or RNG")
	_check(planning.combat["health"] == health and planning.combat["income"] == income and _permanent_tower(planning.combat["towers"][0][0]) == tower, "Wave cancellation retains health, income and upgraded towers")
	_check(planning.combat["enemies"] == [[], []] and planning.combat["queued_sends"] == [0, 0] and planning.combat["wave_roster"].is_empty() and planning.combat["spawn_times"].is_empty() and planning.combat["spawned"] == [0, 0] and planning.combat["total"] == 0 and planning._host_combat._elapsed == 0.0, "Wave cancellation clears every live enemy, regular timetable, send queue and elapsed wave counter")
	_check(not planning.locked and planning.locked_routes == [[], []] and not planning.is_physics_processing() and planning.combat["speed_votes"] == [false, false] and planning.combat["autoplay_votes"] == [false, false], "Wave cancellation unlocks planning and removes all consent to resume automatically")
	_dispose(planning)


func _test_growth_and_retention() -> void:
	for target: int in [20, 21, 30, 31]:
		var planning: MatchPlanning = _new_model()
		_build_upgraded(planning)
		var original_route: Array = planning.layouts[0].route.duplicate()
		var original_towers: Array = planning.combat["towers"].duplicate(true)
		var expansions: int = target / 10 - 1
		_check(planning.debug_set_values(target, 1234, int(planning.combat["reroll_currency"][0])), "Direct debug jump to round %d succeeds" % target)
		_check(planning.combat["board_origin_y"] == -expansions and planning.combat["main_round"] == (target % 10 == 0), "Direct main and non-main targets receive every reached growth milestone")
		for slot: int in range(2):
			_check(planning.layouts[slot].dimensions == Vector2i(14 + expansions, 9 + expansions * 2) and planning.layouts[slot].budget == 30 + expansions * 6 and planning.layouts[slot].is_ready(), "Jump growth expands both real boards and preserves legal paths")
			var expected: Dictionary = _permanent_tower(original_towers[slot][0])
			expected["cell"] += Vector2i(0, expansions)
			_check(_permanent_tower(planning.combat["towers"][slot][0]) == expected, "Jump growth reindexes existing towers once without changing any permanent upgrade")
			_check(planning.combat["towers"][slot][0]["cell"] + Vector2i(0, planning.combat["board_origin_y"]) == original_towers[slot][0]["cell"], "Existing towers remain stationary in world space")
			_check(planning.combat["towers"][slot][0]["tracking_aim"] + Vector2(0, planning.combat["board_origin_y"]) == original_towers[slot][0]["tracking_aim"],
				"Growth reindexes accepted tracking aim with the tower so un-aimed rests and world-space aim remain unchanged")
			for index: int in range(original_route.size()):
				_check(planning.layouts[slot].route[index] + Vector2i(0, planning.combat["board_origin_y"]) == original_route[index], "Every retained path cell stays stationary in world space")
		var grown: Dictionary = planning._snapshot().duplicate(true)
		var grown_routes: Array = [planning.layouts[0].route.duplicate(), planning.layouts[1].route.duplicate()]
		_check(planning.debug_set_values(1, 1234, int(planning.combat["reroll_currency"][0])), "Expanded matches can jump backwards to initial planning")
		_check(planning.layouts[0].dimensions == grown["dimensions"] and planning.layouts[0].budget == grown["budget"] and planning.combat["board_origin_y"] == -expansions and planning.combat["towers"] == grown["combat"]["towers"] and planning.layouts[0].route == grown_routes[0] and planning.layouts[1].route == grown_routes[1], "Backward jumps never shrink boards or move existing objects")
		var backwards: Dictionary = planning._snapshot().duplicate(true)
		_check(planning.debug_set_values(1, 1234, int(planning.combat["reroll_currency"][0])) and planning._snapshot() == backwards, "Repeated same-round application cannot reset or grow anything twice")
		_check(planning.debug_set_values(target, 1234, int(planning.combat["reroll_currency"][0])) and planning._snapshot() == grown, "Returning to an already reached milestone is idempotent")
		_check(planning.debug_set_values(41, 1234, int(planning.combat["reroll_currency"][0])) and planning.combat["board_origin_y"] == -3 and planning.layouts[0].dimensions == Vector2i(17, 15), "Later direct jumps add only previously unreached milestones")
		_dispose(planning)


func _test_bounds_and_terminal() -> void:
	var planning: MatchPlanning = _new_model(false)
	var before: Dictionary = planning._snapshot().duplicate(true)
	var random_states: PackedInt64Array = _random_states(planning)
	for values: Vector3i in [Vector3i(0, 100, 7), Vector3i(-1, 100, 7), Vector3i(1001, 100, 7), Vector3i(31, -1, 7), Vector3i(31, 1000000001, 7), Vector3i(31, 100, -1), Vector3i(31, 100, 1000000001)]:
		_check(not planning.debug_set_values(values.x, values.y, values.z) and planning._snapshot() == before and _random_states(planning) == random_states and not planning.is_physics_processing(), "Invalid round/Coin/Shard triples reject atomically before growth, reset, payment or RNG")
	_check(planning.debug_set_values(1, 0, 0) and planning.combat["coins"] == [0, 0] and planning.combat["reroll_currency"] == [0, 0], "Minimum round and zero Coins/Shards are accepted")
	_check(planning.debug_set_values(1000, 1000000000, 1000000000) and planning.combat["wave"] == 999 and planning.combat["coins"] == [1000000000, 1000000000] and planning.combat["reroll_currency"] == [1000000000, 1000000000], "Maximum supported round, Coins and Shards are accepted together")
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._host_combat.base_health = [0, 5]
	planning._host_combat.winner = 1
	planning._publish_snapshot()
	before = planning._snapshot().duplicate(true)
	planning.combat["phase"] = MatchCombat.Phase.PLANNING
	_check(not planning.can_debug() and not planning.debug_set_values(1, 1000, 1000) and planning._snapshot() == before, "Finished matches cannot be revived even by mutating the public presentation phase")
	_dispose(planning)
