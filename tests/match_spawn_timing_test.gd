extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_schedule()
	_test_edges_and_validation()
	_test_stream_and_isolation()
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
	_check(rules.spawn_jitter_ratio == 0.4, "Default exercises shipped nonzero jitter")
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
