extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_planning_fifo_and_captured_cadence()
	_test_live_cooldown_and_independent_boards()
	_test_coarse_and_fine_delivery()
	_test_mixed_delivery_stats_and_regular_limits()
	_test_pending_gaps_rewards_and_late_orders()
	_test_sent_kills_and_clearance()
	_test_rejections_terminal_and_reset()
	_test_regular_randomness_isolation()
	_test_long_fifo()
	if failures == 0:
		print("PASS: independent paid FIFO send streams, captured cadence, current-combat delivery, fractional travel, pending clearance, atomicity and frozen results")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	# Isolate paid FIFO behavior from shipped progression/group composition.
	rules.catalog.enemies = [
		preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/runner.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/brute.tres").duplicate() as EnemyDefinition,
	]
	for enemy: EnemyDefinition in rules.catalog.enemies:
		enemy.send_first_wave = 1
	rules.base_health = 1000
	rules.starting_coins = 1000
	rules.enemy_health = 8
	rules.enemy_speed = 1.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.5
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	return rules


func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func _combat(rules: CombatRules) -> MatchCombat:
	return MatchCombat.new(rules, _random(11), _random(23), _random(71))


func _routing(length: int = 100) -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(length + 1):
		route.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < length else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _types(enemies: Array) -> Array[String]:
	var result: Array[String] = []
	for enemy: Dictionary in enemies:
		result.append(enemy["type_id"])
	return result


func _test_planning_fifo_and_captured_cadence() -> void:
	var rules := _rules()
	rules.wave_weight = 3
	rules.spawn_interval = 0.35
	var combat := _combat(rules)
	for type_id: StringName in [&"runner", &"brute", &"grunt", &"runner"]:
		_check(combat.send_enemy(0, type_id), "Planning accepts each typed paid FIFO reservation")
	_check(combat.coins == [890, 1000] and combat.income == [10, 0] and combat.enemies == [[], []], "Planning charges each configured price and income once without spawning")
	var pending: Dictionary = combat.snapshot()
	_check(pending["send_queues"] == [[], ["runner", "brute", "grunt", "runner"]] and pending["queued_sends"] == [0, 4], "Snapshots expose destination-owned pending FIFO deliveries")
	pending["send_queues"][1][0] = "changed"
	pending["queued_sends"][1] = 99
	pending["rules"]["send_spawn_interval"] = 99.0
	# A source edit cannot replace a match's admitted cadence, even with invalid timing.
	rules.send_spawn_interval = NAN
	_check(combat.start_wave(_routing()), "An admitted finite cadence survives later source-resource edits")
	_check(_types(combat.enemies[1]) == ["runner"] and combat.queued_sends == [0, 3] and combat.enemies[1][0]["progress"] == 0.0, "Wave start delivers at most the first planning order at time zero")
	_check(is_equal_approx(combat.snapshot()["rules"]["send_spawn_interval"], 0.35) and combat.snapshot()["send_queues"][1] == ["brute", "grunt", "runner"], "Captured cadence and remaining FIFO are detached from resource and snapshot mutation")
	combat.advance(0.349)
	_check(combat.snapshot()["spawned"] == [1, 1] and _types(combat.enemies[1]) == ["runner", "grunt"] and combat.queued_sends == [0, 3], "Neither stream delivers its second event before the shared boundary")
	combat.advance(0.002)
	_check(combat.snapshot()["spawned"] == [2, 2] and _types(combat.enemies[1]) == ["runner", "grunt", "grunt", "brute"] and combat.queued_sends == [0, 2], "Regular and sent streams both deliver at the same boundary without stealing a slot")
	_check(is_equal_approx(combat.enemies[1][3]["progress"], 0.001 * 0.65), "A sent Brute travels only the fractional tick after its true due time")
	combat.advance(0.35)
	_check(combat.snapshot()["spawned"] == [3, 3] and _types(combat.enemies[1]) == ["runner", "grunt", "grunt", "brute", "grunt", "grunt"] and combat.queued_sends == [0, 1], "Later same-time events retain FIFO delivery independently of regular progress")
	combat.advance(0.35)
	_check(_types(combat.enemies[1]) == ["runner", "grunt", "grunt", "brute", "grunt", "grunt", "runner"] and combat.queued_sends == [0, 0] and combat.snapshot()["total"] == 3, "All paid orders arrive exactly once without changing the regular roster total")


func _test_live_cooldown_and_independent_boards() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.2
	var combat := _combat(rules)
	combat.start_wave(_routing())
	combat.advance(3.1)
	_check(combat.send_enemy(0, &"runner") and combat.enemies[1].size() == 2 and combat.enemies[1].back()["progress"] == 0.0, "A live purchase after three seconds starts now in the current combat")
	combat.send_enemy(0, &"brute")
	_check(combat.queued_sends == [0, 1], "A second live order waits for that destination's cooldown")
	combat.advance(0.1)
	combat.send_enemy(1, &"brute")
	combat.send_enemy(1, &"runner")
	_check(combat.enemies[0].size() == 2 and combat.enemies[0].back()["type_id"] == "brute" and combat.enemies[0].back()["progress"] == 0.0 and combat.queued_sends == [1, 1], "The opposite destination gets its own immediate delivery and independent clock")
	combat.advance(0.249999)
	_check(combat.enemies[1].size() == 2 and combat.queued_sends == [1, 1], "A queued order cannot bypass the preceding delivery's exact cooldown")
	combat.advance(0.000002)
	_check(combat.enemies[1].size() == 3 and combat.enemies[1].back()["type_id"] == "brute" and combat.queued_sends == [1, 0], "Only the first board's due stream advances")
	_check(is_equal_approx(combat.enemies[1].back()["progress"], 0.000001 * 0.2 * 0.65), "Live queued travel uses the destination's actual due time")
	combat.advance(0.1)
	_check(combat.enemies[0].size() == 3 and combat.enemies[0].back()["type_id"] == "runner" and combat.queued_sends == [0, 0], "The other stream advances at its later independently scheduled boundary")
	var delivered: int = combat.enemies[1].size()
	combat.send_enemy(0, &"grunt")
	_check(combat.enemies[1].size() == delivered and combat.queued_sends == [0, 1], "An emptied queue retains its delivery cooldown for a new order")
	combat.advance(0.25)
	_check(combat.enemies[1].size() == delivered + 1 and combat.queued_sends == [0, 0], "The retained cooldown delivers the new order once")
	combat.advance(2.0)
	delivered = combat.enemies[1].size()
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	_check(combat.enemies[1].size() == delivered + 1 and combat.enemies[1].back()["progress"] == 0.0 and combat.queued_sends == [0, 1], "A long idle period grants one immediate delivery, not backdated travel or catch-up bursts")
	combat.advance(0.350001)
	_check(combat.enemies[1].size() == delivered + 2 and combat.queued_sends == [0, 0] and is_equal_approx(combat.enemies[1].back()["progress"], 0.000001 * 0.2 * 0.65), "An idle restart paces its successor from the new admission time")


func _test_coarse_and_fine_delivery() -> void:
	var rules := _rules()
	rules.wave_weight = 4
	rules.spawn_interval = 0.4
	var coarse := _combat(rules)
	var fine := _combat(rules)
	var top: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2)]
	var bottom: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 2)]
	var next: Dictionary = {}
	for route: Array[Vector2i] in [top, bottom]:
		for index: int in range(route.size()):
			var cell: Vector2i = route[index]
			if not next.has(cell):
				next[cell] = []
			if index + 1 < route.size() and not next[cell].has(route[index + 1]):
				next[cell].append(route[index + 1])
	var routing: Array[Dictionary] = [{"route": top, "next": next}, {"route": top, "next": next}]
	for combat: MatchCombat in [coarse, fine]:
		for type_id: StringName in [&"brute", &"runner", &"grunt", &"runner", &"brute"]:
			combat.send_enemy(0, type_id)
		for type_id: StringName in [&"runner", &"brute", &"grunt"]:
			combat.send_enemy(1, type_id)
		combat.start_wave(routing)
	coarse.advance(1.41)
	for tick: int in range(141):
		fine.advance(0.01)
	_check(coarse.snapshot()["spawned"] == [4, 4] and coarse.queued_sends == [0, 0] and fine.queued_sends == [0, 0], "Both step sizes drain the same due regular and sent events")
	for slot: int in range(2):
		_check(coarse.enemies[slot].size() == fine.enemies[slot].size(), "Coarse and fine ticks produce identical delivery counts")
		for index: int in range(coarse.enemies[slot].size()):
			var first: Dictionary = coarse.enemies[slot][index]
			var second: Dictionary = fine.enemies[slot][index]
			_check(first["type_id"] == second["type_id"] and first["route"] == second["route"] and first["hp"] == second["hp"] and first["speed"] == second["speed"], "Chronological portal events assign the same typed stats and branch on coarse or fine ticks")
			_check(is_equal_approx(first["progress"], second["progress"]) and first["pos"].is_equal_approx(second["pos"]), "Every actual type speed gives the same fractional travel and corner position across step sizes")


func _test_mixed_delivery_stats_and_regular_limits() -> void:
	var rules := _rules()
	rules.health_growth = 3
	rules.speed_growth_fraction = 0.2
	var combat := _combat(rules)
	for order: int in range(6):
		combat.send_enemy(0, &"brute")
	for order: int in range(3):
		combat.send_enemy(0, &"runner")
	combat.start_wave(_routing())
	combat.advance(3.0)
	var types: Array[String] = _types(combat.enemies[1])
	_check(types.count("brute") == 6 and types.count("runner") == 3 and types.count("grunt") == 1 and combat.queued_sends == [0, 0], "Paid types ignore regular unlocks, hard caps, weight shares and total budget")
	_check(combat.wave_roster == ["grunt"] and combat.snapshot()["spawned"] == [1, 1] and combat.income == [30, 0], "Extra mixed deliveries do not change regular composition, counters or configured income gains")
	combat.advance(1000.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [999, 978], "Every extra type applies its normal resource-defined leak damage once")
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routing())
	var runner: Dictionary = combat.enemies[1][0]
	_check(runner["max_hp"] == 7 and is_equal_approx(runner["speed"], 1.04 * 1.7), "The first next-wave delivery captures delivery-wave rounded health and speed")
	combat.advance(0.36)
	var brute: Dictionary = combat.enemies[1][2]
	_check(brute["type_id"] == "brute" and brute["max_hp"] == 28 and is_equal_approx(brute["speed"], 1.04 * 0.65) and is_equal_approx(brute["progress"], 0.01 * 1.04 * 0.65), "A paced mixed successor uses the same delivery-wave scaling and its own due time")
	combat.send_enemy(0, &"grunt")
	combat.advance(0.35)
	_check(combat.enemies[1].back()["type_id"] == "grunt" and combat.enemies[1].back()["max_hp"] == 11 and is_equal_approx(combat.enemies[1].back()["speed"], 1.04), "A live successor joins that same wave's ordinary stat rules")


func _test_pending_gaps_rewards_and_late_orders() -> void:
	var rules := _rules()
	rules.enemy_speed = 10.0
	var combat := _combat(rules)
	for order: int in range(3):
		combat.send_enemy(0, &"grunt")
	combat.start_wave(_routing(1))
	combat.advance(0.1)
	_check(combat.enemies == [[], []] and combat.snapshot()["spawned"] == [1, 1] and combat.queued_sends == [0, 2] and combat.phase == MatchCombat.Phase.WAVE, "Pending-only gaps keep combat active after both regular streams and all living enemies clear")
	_check(combat.coins == [940, 1000], "An empty alive gap pays neither wave reward nor purchased recurring income")
	combat.advance(0.249999)
	_check(combat.enemies == [[], []] and combat.queued_sends == [0, 2] and combat.phase == MatchCombat.Phase.WAVE, "Clearance cannot skip the next pending delivery boundary")
	combat.advance(0.000002)
	_check(combat.enemies[1].size() == 1 and combat.queued_sends == [0, 1], "A pending-only stream resumes ordinary enemy simulation at its due time")
	combat.advance(0.1)
	_check(combat.enemies == [[], []] and combat.phase == MatchCombat.Phase.WAVE and combat.queued_sends == [0, 1], "A second empty gap still waits for the final paid order")
	combat.advance(0.25)
	_check(combat.enemies[1].size() == 1 and combat.queued_sends == [0, 0] and combat.phase == MatchCombat.Phase.WAVE, "An empty pending queue is not enough while its final enemy lives")
	combat.advance(0.1)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [999, 996] and combat.coins == [981, 1035], "Clear rewards exactly once after pending orders and living enemies on both boards are gone")
	var cleared: Dictionary = combat.snapshot()
	_check(not combat.advance(100.0) and combat.snapshot() == cleared, "Planning cannot move old enemies or repeat the clear payout")
	combat.send_enemy(1, &"brute")
	combat.send_enemy(1, &"runner")
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.wave == 1 and combat.enemies == [[], []] and combat.snapshot()["send_queues"] == [["brute", "runner"], []], "Normal commands arriving after clear wait for the next combat without reopening the cleared wave")
	combat.start_wave(_routing(100))
	_check(_types(combat.enemies[0]) == ["brute"] and combat.enemies[0][0]["progress"] == 0.0 and combat.queued_sends == [1, 0], "Each new combat resets its send clocks and delivers only the first waiting order at zero")
	combat.advance(0.350001)
	_check(_types(combat.enemies[0]) == ["brute", "grunt", "runner"] and combat.queued_sends == [0, 0], "The remaining late order is paced once in the next combat")


func _test_sent_kills_and_clearance() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.0
	var reward := TowerReward.new()
	reward.id = &"stream_defense"
	reward.title = "Stream defense"
	var tower := TowerDefinition.new()
	tower.reward = reward
	tower.damage = 100
	tower.range_cells = 100.0
	tower.interval = 0.01
	tower.area_attack = true
	rules.catalog.towers = [tower]
	rules.catalog.starter_tower_id = &""
	var combat := _combat(rules)
	combat.build(0, Vector2i(0, 1), reward.id, MatchCombat.TargetMode.STRONGEST)
	combat.build(1, Vector2i(0, 1), reward.id, MatchCombat.TargetMode.STRONGEST)
	for type_id: StringName in [&"runner", &"brute", &"grunt"]:
		combat.send_enemy(0, type_id)
	combat.start_wave(_routing())
	combat.advance(0.01)
	_check(combat.enemies == [[], []] and combat.phase == MatchCombat.Phase.WAVE and combat.queued_sends == [0, 2] and combat.towers[1][0]["kills"] == 2, "Ordinary area damage kills initial sent and regular enemies but pending orders prevent premature clear")
	combat.advance(0.35)
	_check(combat.towers[1][0]["kills"] == 3 and combat.queued_sends == [0, 1] and combat.phase == MatchCombat.Phase.WAVE, "A later sent Brute uses normal targeting, kill attribution and clearance rules")
	combat.advance(0.35)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [1000, 1000] and combat.towers[0][0]["kills"] == 1 and combat.towers[1][0]["kills"] == 4, "Only the final paid delivery's death clears both defended boards")
	_check(combat.coins == [916, 1002], "Each regular/sent kill pays one unchanged bounty and clear pays the sender's configured recurring income once")
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.advance(10.0) and combat.snapshot() == frozen, "No removed sent enemy can pay another bounty or wave reward")


func _test_rejections_terminal_and_reset() -> void:
	for interval: float in [0.0, -0.1, INF, NAN]:
		var invalid_rules := _rules()
		invalid_rules.send_spawn_interval = interval
		var invalid := _combat(invalid_rules)
		var before: Dictionary = invalid.snapshot()
		# NaN is not equal to itself; omit this immutable configuration value from state equality.
		before["rules"].erase("send_spawn_interval")
		var random_states: Array[int] = [invalid._random.state, invalid._wave_random.state, invalid._timing_random.state]
		_check(not invalid.send_enemy(0, &"grunt") and not invalid.start_wave(_routing()), "Nonpositive or nonfinite send cadence rejects before charging or starting")
		var after: Dictionary = invalid.snapshot()
		after["rules"].erase("send_spawn_interval")
		_check(after == before and random_states == [invalid._random.state, invalid._wave_random.state, invalid._timing_random.state], "Invalid cadence preserves every mutable transaction field and all RNG streams")
		invalid_rules.send_spawn_interval = 0.35
		_check(not invalid.send_enemy(0, &"grunt") and not invalid.start_wave(_routing()), "Later source edits cannot replace an invalid captured admission configuration")
	var rules := _rules()
	rules.starting_coins = 40
	var combat := _combat(rules)
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.send_enemy(-1, &"grunt") and not combat.send_enemy(2, &"grunt") and not combat.send_enemy(0, &"") and not combat.send_enemy(0, &"unknown") and combat.snapshot() == frozen, "Malformed owners and type IDs preserve the full planning state")
	_check(combat.send_enemy(0, &"brute") and combat.coins[0] == 0 and combat.income[0] == 4 and combat.snapshot()["send_queues"][1] == ["brute"], "Exact funds atomically purchase one configured type and recurring-income gain")
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"grunt") and not combat.send_enemy(0, &"runner") and combat.snapshot() == frozen, "Insufficient funds cannot change any queue, enemy, income or currency field")
	var invalid_routing: Array[Dictionary] = [{"route": [], "next": {}}, _routing()[1]]
	_check(not combat.start_wave(invalid_routing) and combat.snapshot() == frozen, "Rejected routing preserves the already-paid FIFO and entire planning state")
	combat.start_wave(_routing())
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"grunt") and not combat.send_enemy(1, &"unknown") and not combat.send_enemy(2, &"runner") and combat.snapshot() == frozen, "Rejected live purchases are equally atomic after a stream has delivered")
	rules = _rules()
	rules.base_health = 1
	rules.enemy_speed = 10.0
	combat = _combat(rules)
	for type_id: StringName in [&"runner", &"brute", &"grunt"]:
		combat.send_enemy(0, type_id)
	combat.start_wave(_routing(1))
	var tie_state: int = combat._random.state
	combat.advance(0.11)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.coin_flip and combat._random.state != tie_state and combat.queued_sends == [0, 2], "Simultaneous destruction finishes once even with pending paid deliveries")
	_check(combat.coins == [915, 1000], "Terminal combat grants no wave reward or recurring-income payout")
	frozen = combat.snapshot()
	tie_state = combat._random.state
	_check(not combat.send_enemy(0, &"grunt") and not combat.send_enemy(1, &"brute") and not combat.start_wave(_routing()) and not combat.advance(100.0) and combat.snapshot() == frozen and combat._random.state == tie_state, "Finished state rejects charging, late delivery, rewards, movement and another result roll")
	var fresh := _combat(rules)
	_check(fresh.phase == MatchCombat.Phase.PLANNING and fresh.wave == 0 and fresh.enemies == [[], []] and fresh.queued_sends == [0, 0] and fresh.income == [0, 0] and fresh.coins == [1000, 1000], "A fresh match owner clears all pending orders, enemies, income and terminal state")
	fresh.start_wave(_routing())
	fresh.send_enemy(0, &"brute")
	_check(fresh.enemies[1].size() == 1 and fresh.enemies[1][0]["type_id"] == "brute" and fresh.enemies[1][0]["progress"] == 0.0, "Reset also clears both send clocks so a new live stream is immediately available")


func _test_regular_randomness_isolation() -> void:
	var rules := _rules()
	rules.wave_weight = 30
	rules.spawn_interval = 0.75
	rules.spawn_jitter_ratio = 0.4
	rules.enemy_speed = 0.01
	var sent := _combat(rules)
	var regular := _combat(rules)
	sent.wave = 9
	regular.wave = 9
	for type_id: StringName in [&"brute", &"runner", &"grunt", &"brute"]:
		sent.send_enemy(0, type_id)
		sent.send_enemy(1, type_id)
	sent.start_wave(_routing())
	regular.start_wave(_routing())
	_check(sent.wave_roster == regular.wave_roster and sent.spawn_times == regular.spawn_times, "Planning sends leave seeded regular composition and irregular timetable identical to a no-send match")
	for delta: float in [0.01, 0.5, 3.0, 0.1, 1.0, 20.0]:
		sent.advance(delta)
		regular.advance(delta)
		sent.send_enemy(0, &"runner")
		sent.send_enemy(0, &"brute")
		_check(sent.wave_roster == regular.wave_roster and sent.spawn_times == regular.spawn_times and sent.snapshot()["spawned"] == regular.snapshot()["spawned"] and sent.snapshot()["total"] == regular.snapshot()["total"], "Continuous early/late paid sends never reserve regular slots or change actual regular spawn counters")
		_check(sent._wave_random.state == regular._wave_random.state and sent._timing_random.state == regular._timing_random.state and sent._random.state == regular._random.state, "Purchasing and delivering sends consumes no regular roster, timing or terminal RNG")


func _test_long_fifo() -> void:
	var rules := _rules()
	rules.starting_coins = 10000
	rules.enemy_speed = 0.01
	var combat := _combat(rules)
	var orders: Array[String] = []
	var started: bool = false
	var most_waiting: int = 0
	# The queue holds twenty orders; keep it topped up as deliveries free slots.
	for index: int in range(131):
		var type_id: String = ["brute", "runner", "grunt"][index % 3]
		orders.append(type_id)
		var waits: int = 0
		while not combat.send_enemy(0, StringName(type_id)) and waits < 100:
			if not started:
				started = combat.start_wave(_routing())
			combat.advance(0.05)
			waits += 1
		most_waiting = maxi(most_waiting, combat.queued_send_orders[1])
	_check(combat.queued_send_orders[1] == MatchCombat.SEND_QUEUE_LIMIT and most_waiting == MatchCombat.SEND_QUEUE_LIMIT, "A funded long FIFO keeps exactly the twenty-order limit waiting")
	var pending: Dictionary = combat.snapshot()
	var waiting: int = pending["queued_sends"][1]
	_check(pending["send_queues"][1] == orders.slice(orders.size() - waiting), "Long-running FIFO snapshots expose only the unconsumed ordered suffix")
	pending["send_queues"][1].clear()
	_check(combat.snapshot()["send_queues"][1] == orders.slice(orders.size() - waiting), "Long FIFO snapshot mutation cannot erase authoritative future deliveries")
	combat.advance(24.0)
	var delivered: Array[String] = _types(combat.enemies[1])
	delivered.remove_at(1) # The independent regular Grunt arrived at zero after the first send.
	_check(delivered == orders and combat.queued_sends == [0, 0] and combat.snapshot()["send_queues"] == [[], []], "A long FIFO drains all mixed orders exactly once without retaining delivered snapshot entries")
