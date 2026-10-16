extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_curve()
	_test_live_spawns_and_capture()
	_test_configuration()
	if failures == 0:
		print("PASS: diminishing additive speed milestones, boundary slopes, typed regular/paid spawn movement, preview agreement, and captured rules")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _test_curve() -> void:
	var rules := CombatRules.new()
	for entry: Array in [[1,2.0],[2,2.04],[5,2.16],[6,2.2],[7,2.22],[15,2.38],[16,2.4],[17,2.413333333333333],[31,2.6],[51,2.8],[101,3.166666666666667]]:
		_check(is_equal_approx(rules.enemy_speed_at_wave(int(entry[0])),float(entry[1])), "Wave %d follows the gradual diminishing curve" % int(entry[0]))
	var previous_rate: float = INF
	for milestone: int in range(1,20):
		var boundary: int = 1 + 5 * milestone * (milestone + 1) / 2
		var speed: float = rules.enemy_speed_at_wave(boundary)
		_check(is_equal_approx(speed,2.0*(1.0+0.1*milestone)), "Each milestone adds ten percent of the original speed, never compounds")
		var before: float = rules.enemy_speed_at_wave(boundary-1)
		var after: float = rules.enemy_speed_at_wave(boundary+1)
		var rate: float = after-speed
		_check(before < speed and speed < after and rate < previous_rate, "Crossing a milestone stays continuous and reduces the subsequent per-round increase")
		_check(is_equal_approx(speed-before,0.2/(5.0*milestone)) and is_equal_approx(rate,0.2/(5.0*(milestone+1))), "Each additional ten-percent step takes a longer five-round span")
		previous_rate = rate
	_check(is_equal_approx(rules.enemy_speed_at_wave(0),2.0), "Pre-wave baseline does not apply negative growth")


func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new()
	for x: int in range(1,13):
		layout.place(Vector2i(x,4))
	return [layout.capture_routing(),layout.capture_routing()]


func _test_live_spawns_and_capture() -> void:
	var rules := CombatRules.new()
	rules.base_health = 1000
	rules.starting_coins = 1000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	var grunt: EnemyDefinition = rules.catalog.enemies[0].duplicate() as EnemyDefinition
	grunt.send_first_wave = 1
	rules.catalog.enemies = [grunt]
	for entry: Array in [[1,2.0],[6,2.2],[16,2.4],[31,2.6],[51,2.8],[101,3.166666666666667]]:
		var number: int = entry[0]
		var expected: float = entry[1]
		var model := MatchCombat.new(rules)
		model.debug_set_round(number)
		_check(is_equal_approx(model.snapshot()["enemy_types"]["grunt"]["speed"],expected), "Planning previews use the upcoming round's new curve")
		_check(model.send_enemy(0,&"grunt") and model.start_wave(_routes()), "Paid and regular streams enter the same selected round")
		model.advance(0.1)
		for slot: int in range(2):
			for enemy: Dictionary in model.enemies[slot]:
				_check(is_equal_approx(enemy["base_speed"],expected) and is_equal_approx(enemy["progress"],expected*0.1), "Actual regular and sent enemies move using the host's selected speed")
		var runner: EnemyDefinition = preload("res://resources/combat/enemies/runner.tres")
		_check(is_equal_approx(MatchCombat.enemy_preview(runner,rules,number)["speed"],expected*1.7), "Enemy-type speed multipliers remain intact in the shared preview")
	var captured := MatchCombat.new(rules)
	rules.speed_growth_fraction = 1.0
	rules.speed_growth_rounds = 1
	captured.debug_set_round(16)
	_check(is_equal_approx(captured.snapshot()["enemy_types"]["grunt"]["speed"],2.4), "Editing source progression after admission cannot retune an existing host model")


func _test_configuration() -> void:
	var rules := CombatRules.new()
	rules.enemy_speed = 4.0
	rules.speed_growth_rounds = 2
	rules.speed_growth_fraction = 0.25
	_check(is_equal_approx(rules.enemy_speed_at_wave(3),5.0) and is_equal_approx(rules.enemy_speed_at_wave(7),6.0), "Custom baseline, step fraction and span use the same noncompounding rule")
	rules.speed_growth_fraction = 0.0
	_check(is_equal_approx(rules.enemy_speed_at_wave(1000),4.0), "Zero growth keeps deterministic fixture speed constant")
	rules.speed_growth_rounds = 0
	_check(not rules.valid_speed_progression(), "Invalid zero-length milestone spans are rejected before division")
