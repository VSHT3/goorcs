extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	rules.roll_rules = null
	rules.starting_coins = 100000
	rules.enemy_health = 10000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	var core := MatchCombat.new(rules)
	var layout := PathLayout.new()
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 4))
	_check(core.start_wave([layout.capture_routing(), layout.capture_routing()]), "Start real targeting wave")
	var route: Array[Vector2i] = []
	route.assign(layout.route)
	for slot: int in range(2):
		_check(core.build(slot, Vector2i(5, 3), &"orc_ballista", 0), "Build actual directional tracker")
		for index: int in range(120):
			core._spawn_enemy(slot, "grunt", float(index % 24) * 0.5, core._elapsed, route)
		for enemy: Dictionary in core.enemies[slot]:
			enemy["hp"] -= int(enemy["id"]) % 7
	_assert_targets(core)
	for iteration: int in range(4):
		core.advance(0.1)
		_assert_targets(core)
		for slot: int in range(2):
			var tower: Dictionary = core.towers[slot][0]
			var victim: int = core._target(slot, tower, 2.75)
			_check(victim >= 0, "Dense fixture has a real in-range victim")
			if victim >= 0:
				var id: int = core.enemies[slot][victim]["id"]
				core._hit(slot, tower, victim, 1000000)
				var next: int = core._target(slot, tower, 2.75)
				_check(next >= 0 and core.enemies[slot][next]["id"] != id, "A retired victim cannot remain eligible in a range bucket")
			core._spawn_enemy(slot, "grunt", 5.0, core._elapsed, route)
		_assert_targets(core)
	core.debug_set_round(1)
	_check(core.start_wave([layout.capture_routing(), layout.capture_routing()]), "Start fresh wave after cached-target reset")
	for slot: int in range(2):
		_check(core._target(slot, core.towers[slot][0], 2.75) == -1, "Old-wave enemies cannot survive in the target lookup")
	if failures == 0:
		print("PASS: accelerated targeting preserves modes, stable ties, exclusions, fractional tile bounds, movement, retirement, spawn and reset")
	quit(0 if failures == 0 else 1)


func _assert_targets(core: MatchCombat) -> void:
	for slot: int in range(2):
		var tower: Dictionary = core.towers[slot][0]
		for mode: int in [MatchCombat.TargetMode.FURTHEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.LAST]:
			for range_cells: float in [0.75, 1.0, 2.75, 3.0]:
				var accelerated: int = core._target(slot, tower, range_cells, mode)
				var historical: int = core._target(slot, tower, range_cells, mode, -1, -1, -1, core._elapsed)
				_check(accelerated == historical, "Current range lookup agrees with exact accepted-position targeting for every mode and tile boundary")
				if accelerated >= 0:
					var id: int = core.enemies[slot][accelerated]["id"]
					var alternative: int = core._target(slot, tower, range_cells, mode, id)
					var historical_alternative: int = core._target(slot, tower, range_cells, mode, id, -1, -1, core._elapsed)
					_check(alternative == historical_alternative and (alternative < 0 or core.enemies[slot][alternative]["id"] != id), "Distinct-archer exclusions and stable ties survive spatial candidate ordering")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
