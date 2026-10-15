extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_schedule()
	_test_edges_and_validation()
	_test_stream_and_isolation()
	_test_round_cadence()
	if failures == 0:
		print("PASS: bounded shared regular timing, actual mixed spawns, snapshots, sends and independent RNG streams")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.wave_weight = 30
	rules.wave_weight_growth = 0
	rules.enemy_speed = 0.1
	rules.speed_growth = 0.0
	rules.starting_coins = 1000
	rules.spawn_jitter_ratio = 0.4
	rules.spawn_interval_reduction_per_wave = 0.0
	return rules


func _routing() -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(101):
		route.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < 100 else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _combat(rules: CombatRules, timing_seed: int = 71) -> MatchCombat:
	var combat := MatchCombat.new(rules, _random(11), _random(23), _random(timing_seed))
	combat.wave = 9
	return combat


func _test_schedule() -> void:
	var rules := _rules()
	var first := _combat(rules)
	_check(first.snapshot()["spawn_times"].is_empty(), "Initial N0 snapshot has an empty timetable")
	_check(first.start_wave(_routing()), "Valid timing starts wave")
	var repeated := _combat(_rules())
	repeated.start_wave(_routing())
	var different := _combat(_rules(), 72)
	different.start_wave(_routing())
	_check(first.spawn_times == repeated.spawn_times and first.wave_roster == repeated.wave_roster, "Explicit seeds reproduce composition and timing")
	_check(first.spawn_times != different.spawn_times and first.wave_roster == different.wave_roster, "Timing seeds vary delivery without changing composition")
	var times: Array[float] = first.spawn_times
	_check(times[0] == 0.0 and times.back() == (times.size() - 1) * rules.spawn_interval, "Delivery endpoints preserve exact regular window")
	var varied: bool = false
	for index: int in range(1, times.size()):
		var gap: float = times[index] - times[index - 1]
		_check(gap > 0.0 and gap >= rules.spawn_interval * (1.0 - 2.0 * rules.spawn_jitter_ratio) - 0.000001 and gap <= rules.spawn_interval * (1.0 + 2.0 * rules.spawn_jitter_ratio) + 0.000001, "Every gap is ordered and bounded without long delivery pauses")
		_check(absf(times[index] - index * rules.spawn_interval) <= rules.spawn_jitter_ratio * rules.spawn_interval + 0.000001, "Each planned offset is bounded")
		varied = varied or not is_equal_approx(times[index], index * rules.spawn_interval)
	_check(varied, "Nonzero shipped ratio produces irregular clusters")
	var detached: Dictionary = first.snapshot()
	detached["spawn_times"][0] = 999.0
	_check(first.spawn_times[0] == 0.0, "Snapshot timetable is detached")


func _test_edges_and_validation() -> void:
	for count: int in [1, 2, 6]:
		for interval: float in [0.0, 0.75]:
			var rules := _rules()
			rules.wave_weight = count
			rules.spawn_interval = interval
			var combat := MatchCombat.new(rules, _random(1), _random(2), _random(3))
			combat.start_wave(_routing())
			_check(combat.spawn_times.size() == count and combat.spawn_times[0] == 0.0 and combat.spawn_times.back() == (count - 1) * interval, "Singleton, pair and zero interval retain exact endpoints")
			if interval == 0.0:
				combat.advance(0.01)
				_check(combat.snapshot()["spawned"] == [count, count], "Zero interval delivers entire regular stream on both boards")
	for ratio: float in [-0.1, 0.5, INF, NAN]:
		var rules := _rules()
		var combat := _combat(rules)
		combat.send_enemy(0, &"runner")
		rules.spawn_jitter_ratio = ratio
		var before: Dictionary = combat.snapshot()
		var wave_state: int = combat._wave_random.state
		var timing_state: int = combat._timing_random.state
		_check(not combat.start_wave(_routing()) and combat.snapshot() == before and combat._wave_random.state == wave_state and combat._timing_random.state == timing_state, "Invalid jitter rejects atomically before queues, wave or RNG change")


func _test_stream_and_isolation() -> void:
	var rules := _rules()
	var combat := _combat(rules)
	var tie_state: int = combat._random.state
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routing())
	var planned: Array[float] = combat.spawn_times.duplicate()
	var wave_state: int = combat._wave_random.state
	var timing_state: int = combat._timing_random.state
	combat.send_enemy(1, &"brute")
	combat.send_enemy(1, &"runner")
	_check(combat.queued_sends == [1, 1] and combat.spawn_times == planned and combat._timing_random.state == timing_state and combat._wave_random.state == wave_state and combat._random.state == tie_state, "Independent FIFO reservations do not alter timetable or consume any random stream")
	# Resource mutation after capture cannot retime an active wave.
	rules.spawn_interval = 99.0
	rules.spawn_jitter_ratio = 0.0
	var elapsed: float = 0.0
	var types: Dictionary = {}
	for index: int in range(planned.size()):
		if index > 0:
			var before_time: float = planned[index] - 0.00001
			combat.advance(before_time - elapsed)
			elapsed = before_time
			_check(combat.snapshot()["spawned"] == [index, index], "No board spawns before its planned boundary")
		var after_time: float = planned[index] + 0.00001
		combat.advance(after_time - elapsed)
		elapsed = after_time
		_check(combat.snapshot()["spawned"] == [index + 1, index + 1], "Both boards spawn immediately after the captured boundary")
		for slot: int in range(2):
			for regular_index: int in range(index + 1):
				var send_offset: int = 1 if regular_index == 0 else 2
				var enemy: Dictionary = combat.enemies[slot][regular_index + send_offset]
				var type_id: String = combat.wave_roster[regular_index]
				types[type_id] = true
				_check(enemy["type_id"] == type_id and is_equal_approx(enemy["progress"], (elapsed - planned[regular_index]) * float(enemy["speed"])), "Actual mixed-type progress uses planned time and host type speed on both boards")
	_check(types.size() > 1, "Regression observes actual mixed regular roster")
	_check(combat.spawn_times == planned and combat._timing_random.state == timing_state and combat._wave_random.state == wave_state and combat._random.state == tie_state, "Spawning consumes no further RNG and captured schedule survives mutable resource changes")
	var regular_rules := _rules()
	regular_rules.spawn_jitter_ratio = 0.0
	var regular := _combat(regular_rules)
	regular.start_wave(_routing())
	_check(regular.wave_roster == combat.wave_roster and regular._wave_random.state == wave_state and regular._random.state == tie_state, "Changing jitter cannot perturb composition or terminal tie RNG")


func _test_round_cadence() -> void:
	for stage: Array in [[1, 1.0], [2, 0.995], [51, 0.75], [100, 0.505], [101, 0.5], [102, 0.5], [1000, 0.5]]:
		var round_number: int = int(stage[0])
		var factor: float = float(stage[1])
		var rules := _rules()
		rules.wave_weight = 3
		rules.enemy_definitions = [rules.enemy_definitions[0]]
		rules.health_growth = 0
		rules.spawn_jitter_ratio = 0.0
		rules.spawn_interval_reduction_per_wave = 0.005
		rules.max_spawn_interval_reduction = 0.5
		var combat := _combat(rules)
		combat.wave = round_number - 1
		var regular_interval: float = 0.75 * factor
		var send_interval: float = 0.35 * factor
		_check(is_equal_approx(combat.snapshot()["rules"]["send_spawn_interval"], send_interval), "Planning previews the next round's effective send interval")
		combat.send_enemy(0, &"grunt")
		combat.send_enemy(0, &"grunt")
		_check(combat.start_wave(_routing()), "Round %d accepts scaled clocks" % round_number)
		_check(is_equal_approx(combat.spawn_times[1], regular_interval) and is_equal_approx(combat.spawn_times[2], 2.0 * regular_interval), "Regular intervals follow linear reduction and stop at the round-101 floor")
		_check(is_equal_approx(combat.snapshot()["rules"]["send_spawn_interval"], send_interval), "Both cadence owners and the host snapshot use the same round factor")
		# Neither source-resource edits nor phase previews may retime admitted combat.
		rules.spawn_interval = 99.0
		rules.send_spawn_interval = 99.0
		rules.spawn_interval_reduction_per_wave = NAN
		rules.max_spawn_interval_reduction = NAN
		combat.advance(send_interval - 0.000001)
		_check(combat.queued_sends == [0, 1] and combat.snapshot()["spawned"] == [1, 1] and combat.enemies[1].size() == 2, "Scaled send slot is not released before its boundary")
		combat.advance(0.000002)
		_check(combat.queued_sends == [0, 0] and combat.enemies[1].size() == 3 and is_equal_approx(combat.enemies[1].back()["progress"], 0.000001 * 0.1), "Scaled paid delivery occurs in this round with fractional travel only since its due time")
		combat.advance(regular_interval - send_interval - 0.000002)
		_check(combat.snapshot()["spawned"] == [1, 1], "Regular timetable retains its independent scaled boundary")
		combat.advance(0.000002)
		_check(combat.snapshot()["spawned"] == [2, 2] and is_equal_approx(combat.enemies[0].back()["progress"], 0.000001 * 0.1), "Both boards deliver regular enemies at the scaled boundary")
		for enemy: Dictionary in combat.enemies[1]:
			_check(enemy["max_hp"] == 8 and is_equal_approx(enemy["speed"], 0.1), "Cadence progression does not rewrite enemy HP or movement speed")
		_check(is_equal_approx(combat.snapshot()["rules"]["send_spawn_interval"], send_interval), "Admitted active cadence is immune to source-resource mutations")
	# Relative irregular spacing and RNG consumption stay unchanged at the cap.
	var early_rules := _rules()
	early_rules.spawn_interval_reduction_per_wave = 0.005
	var late_rules := _rules()
	late_rules.spawn_interval_reduction_per_wave = 0.005
	early_rules.enemy_definitions = [early_rules.enemy_definitions[0]]
	late_rules.enemy_definitions = [late_rules.enemy_definitions[0]]
	var early := _combat(early_rules)
	var late := _combat(late_rules)
	early.wave = 0
	late.wave = 100
	early.start_wave(_routing())
	late.start_wave(_routing())
	for index: int in range(early.spawn_times.size()):
		_check(is_equal_approx(late.spawn_times[index], early.spawn_times[index] * 0.5), "The entire jittered timetable scales uniformly rather than reducing only its average interval")
	_check(early._timing_random.state == late._timing_random.state and early.wave_roster == late.wave_roster, "Cadence progression adds no timing randomness or roster changes")
	for invalid: Array in [[-0.005, 0.5], [INF, 0.5], [NAN, 0.5], [0.005, -0.1], [0.005, 1.0], [0.005, INF], [0.005, NAN]]:
		var rules := _rules()
		rules.spawn_interval_reduction_per_wave = float(invalid[0])
		rules.max_spawn_interval_reduction = float(invalid[1])
		var combat := _combat(rules)
		var before: Dictionary = combat.snapshot()
		before["rules"].erase("send_spawn_interval")
		var random_state: int = combat._timing_random.state
		_check(not combat.send_enemy(0, &"grunt") and not combat.start_wave(_routing()), "Invalid progression cannot charge for sends or start a wave with collapsed/nonfinite intervals")
		var after: Dictionary = combat.snapshot()
		after["rules"].erase("send_spawn_interval")
		_check(before == after and combat._timing_random.state == random_state, "Rejected interval progression preserves all mutable state and timing RNG")
