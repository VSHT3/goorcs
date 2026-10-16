extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	_test_deadline_and_commit()
	_test_legal_deadline_gate()
	_test_strategy_growth_and_reset()
	_test_autoplay_strategy_pause()
	await process_frame
	if failures == 0:
		print("PASS: host-owned real-time Ready deadlines, committed command locks, strategy phases, exact growth/preservation/reset, and autoplay strategy pauses")
	quit(1 if failures > 0 else 0)


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 1000
	rules.starting_coins = 2000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition]
	rules.catalog.enemies[0].send_first_wave = 1
	rules.enemy_speed = 26.0
	rules.speed_growth_fraction = 0.0
	rules.health_growth = 0
	rules.spawn_interval = 0.0
	var tower := rules.catalog.towers[0].duplicate() as TowerDefinition
	tower.range_cells = 0.1
	rules.catalog.towers = [tower]
	return rules


func _new_model() -> MatchPlanning:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	planning.combat_rules = _rules()
	root.add_child(planning)
	planning.start_singleplayer()
	planning.set_physics_process(false)
	_route(planning)
	return planning


func _dispose(planning: MatchPlanning) -> void:
	var session: MultiplayerSession = planning.session
	planning.free()
	session.free()


func _route(planning: MatchPlanning) -> void:
	var y: int = planning.layouts[0].entrance.y
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, y), true)


func _clear_wave(planning: MatchPlanning) -> void:
	_check(planning.combat["phase"] == MatchCombat.Phase.WAVE, "A real accepted wave precedes clearance")
	planning._physics_process(1.0)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING, "A complete real wave clears into planning")


func _ready_other(planning: MatchPlanning) -> void:
	# The solo mirror's admitted sender exercises an individual committed slot.
	# Separate-process coverage below additionally proves both real senders.
	planning._apply_command(2, "ready", 1, Vector2i.ZERO, true)


func _test_deadline_and_commit() -> void:
	var normal: MatchPlanning = _new_model()
	var fast: MatchPlanning = _new_model()
	for planning: MatchPlanning in [normal, fast]:
		planning.build_tower(0, Vector2i(0, 0), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
		planning.submit_ready(true)
		_clear_wave(planning)
		_check(not planning.can_edit_path(0) and planning.can_manage_towers(0) and not planning.is_physics_processing(), "Ordinary planning keeps its existing path and sleeps without a deadline")
	fast.request_pacing("speed", true)
	var publications: Array[int] = [0, 0]
	normal.changed.connect(func() -> void: publications[0] += 1)
	fast.changed.connect(func() -> void: publications[1] += 1)
	for planning: MatchPlanning in [normal, fast]:
		_ready_other(planning)
		_check(planning.ready_flags == [false, true] and planning.combat["ready_seconds_left"] == 20.0 and planning.is_physics_processing(), "The first normal Ready starts exactly one 20-real-second deadline")
		_check(not planning.can_manage_towers(1) and planning.can_manage_towers(0), "Only the committed planner loses management permission")
		var before: Dictionary = planning._snapshot().duplicate(true)
		var tower_id: int = planning.combat["towers"][1][0]["id"]
		for command: String in ["build", "target", "upgrade", "sell", "send"]:
			var argument: String = "arrow_tower" if command == "build" else ("grunt" if command == "send" else "damage")
			planning._apply_tower_command(2, command, 1, Vector2i(1, 0), tower_id, MatchCombat.TargetMode.STRONGEST, argument)
		planning._apply_command(2, "edit", 1, Vector2i(1, 4), false)
		planning._apply_command(2, "clear", 1, Vector2i.ZERO, false)
		planning._apply_command(2, "ready", 1, Vector2i.ZERO, false)
		planning._apply_command(2, "ready", 1, Vector2i.ZERO, true)
		planning._apply_tower_command(2, "send", 0, Vector2i.ZERO, -1, -1, "grunt")
		planning._apply_command(123456, "ready", 0, Vector2i.ZERO, true)
		_check(planning._snapshot() == before, "Committed/forged/unadmitted commands change no Coins, income, queues, towers, paths, votes, deadline or readiness")
		# Presentation mutation must never unlock the host-owned command gate.
		planning.ready_flags[1] = false
		planning.combat["ready_seconds_left"] = 0.0
		planning.combat["path_editing"] = true
		planning._apply_tower_command(2, "sell", 1, Vector2i.ZERO, tower_id, -1, "")
		_check(planning._snapshot() == before, "Mutable accepted copies cannot unlock committed transactions or expire the host clock")
		planning._publish_snapshot()
	publications[0] = 0
	publications[1] = 0
	for planning: MatchPlanning in [normal, fast]:
		planning._physics_process(0.05)
	_check(publications == [0, 0], "Ready countdown does not publish before 0.1 real seconds")
	for planning: MatchPlanning in [normal, fast]:
		planning._physics_process(0.075)
	_check(publications == [1, 1] and normal.combat["ready_seconds_left"] == fast.combat["ready_seconds_left"], "Ready publication cadence and countdown ignore the 2x simulation multiplier")
	for planning: MatchPlanning in [normal, fast]:
		planning._physics_process(19.375)
		_check(planning.combat["wave"] == 1 and planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["ready_seconds_left"] == 0.5, "The deadline cannot launch a wave before 20 real seconds")
		planning._physics_process(0.5)
		_check(planning.combat["wave"] == 2 and planning.combat["phase"] == MatchCombat.Phase.WAVE and planning.combat["ready_seconds_left"] == -1.0 and planning.can_manage_towers(1), "Exactly 20 real seconds starts the legal captured wave and restores tower management without a guest Ready")
		_check(planning._host_combat._elapsed == 0.0, "Deadline expiry does not apply the planning tick to the newly started combat")
		_clear_wave(planning)
		_ready_other(planning)
		planning._physics_process(1.0)
		planning.submit_ready(true)
		_check(planning.combat["wave"] == 3 and planning.combat["ready_seconds_left"] == -1.0, "Both Ready launches early and cancels its outstanding deadline")
		_dispose(planning)


func _test_legal_deadline_gate() -> void:
	var planning: MatchPlanning = _new_model()
	planning.submit_ready(true)
	_clear_wave(planning)
	_ready_other(planning)
	# Fault-inject an illegal authoritative route: expiry must never fabricate
	# pavement or waive the existing combat routing validator.
	planning._host_layouts[0].erase(Vector2i(1, 4))
	var before: Dictionary = planning._host_combat.snapshot().duplicate(true)
	planning._physics_process(20.0)
	_check(planning._host_combat.snapshot() == before and planning.combat["phase"] == MatchCombat.Phase.PLANNING and not planning._host_layouts[0].is_ready() and not planning.is_physics_processing(), "Deadline expiry cannot start an illegal route, fabricate a path, spend Coins, pay rewards or drain queued sends")
	_dispose(planning)


func _test_strategy_growth_and_reset() -> void:
	var planning: MatchPlanning = _new_model()
	planning.build_tower(0, Vector2i(0, 0), &"arrow_tower", MatchCombat.TargetMode.CLOSEST)
	var tower_id: int = planning.combat["towers"][0][0]["id"]
	planning.upgrade_tower(0, tower_id, "damage")
	planning.upgrade_tower(0, tower_id, "speed")
	planning.upgrade_tower(0, tower_id, "special")
	planning.set_secondary_targeting(0, tower_id, MatchCombat.TargetMode.STRONGEST)
	var original_towers: Array = planning.combat["towers"].duplicate(true)
	var original_route: Array[Vector2i] = planning.layouts[0].route.duplicate()
	for upcoming: int in range(1, 31):
		var strategy: bool = upcoming == 1 or upcoming % 10 == 0
		var expansions: int = maxi(0, upcoming / 10 - 1)
		_check(planning.combat["main_round"] == (upcoming % 10 == 0) and planning.combat["setup_round"] == (upcoming == 1) and planning.combat["path_editing"] == strategy and planning.can_edit_path(0) == strategy, "Upcoming round %d exposes its actual phase path permission" % upcoming)
		_check(planning.combat["board_origin_y"] == -expansions, "Round %d has exactly the scheduled world origin" % upcoming)
		for slot: int in range(2):
			_check(planning.layouts[slot].dimensions == Vector2i(14 + expansions, 9 + expansions * 2) and planning.layouts[slot].budget == 30 + expansions * 6, "Round %d gives both boards exactly one outer column, two rows and +6 tiles per growth" % upcoming)
			var expected_route: Array[Vector2i] = []
			for cell: Vector2i in original_route:
				expected_route.append(cell + Vector2i(0, expansions))
			_check(planning.layouts[slot].route == expected_route and planning.layouts[slot].is_ready(), "Growth preserves every route step and connectivity on both boards")
			var expected_tower: Dictionary = original_towers[slot][0].duplicate(true)
			expected_tower["cell"] += Vector2i(0, expansions)
			expected_tower["aim"] += Vector2(0, expansions)
			expected_tower["secondary_aim"] += Vector2(0, expansions)
			expected_tower["bounce_aim"] += Vector2(0, expansions)
			expected_tower["pierce_aim"] += Vector2(0, expansions)
			_check(planning.combat["towers"][slot][0] == expected_tower, "Expansion preserves tower IDs, targeting, upgrades, stats, reload, kills and actual investment")
			_check(planning.layouts[slot].entrance == Vector2i(0, 4 + expansions) and planning.layouts[slot].base == Vector2i(13, 4 + expansions) and expected_tower["cell"] == original_towers[slot][0]["cell"] + Vector2i(0, expansions) and expected_tower["aim"] == original_towers[slot][0]["aim"] + Vector2(0, expansions), "Endpoints, tower cells and aim retain their old x coordinates and only reindex y")
		if upcoming in [10, 20, 30]:
			if expansions > 0:
				var outer_x: int = planning.layouts[0].dimensions.x - 1
				var base_y: int = planning.layouts[0].base.y
				for x: int in range(14, outer_x + 1):
					planning.request_edit(0, Vector2i(x, base_y), true)
				for slot: int in range(2):
					_check(planning.layouts[slot].has_path(Vector2i(outer_x, base_y)) and planning.layouts[slot].is_ready() and planning.layouts[slot].route.back() == Vector2i(13, base_y), "Authoritative edits and accepted snapshots make the new outer column usable beyond the stationary base on both boards")
				for x: int in range(outer_x, 13, -1):
					planning.request_edit(0, Vector2i(x, base_y), false)
				planning.build_tower(0, Vector2i(outer_x, 0), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
				for slot: int in range(2):
					_check(planning.combat["towers"][slot].size() == 2 and planning.combat["towers"][slot][1]["cell"] == Vector2i(outer_x, 0), "The new outer column also accepts a tower through the shared build validator")
				if planning.combat["towers"][0].size() == 2:
					planning.sell_tower(0, planning.combat["towers"][0][1]["id"])
			var before_growth: Dictionary = planning._snapshot().duplicate(true)
			planning._enter_planning()
			planning._publish_snapshot()
			planning._publish_snapshot()
			_check(planning._snapshot() == before_growth, "Repeated planning preparation and snapshots never expand a milestone twice")
			planning.request_clear(0)
			_check(planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Main-round Clear mirrors through the authoritative validator")
			_check(not planning._try_start_wave(), "An illegal cleared path cannot be started through the shared gate")
			_route(planning)
		else:
			var before_path: Array = planning.layouts[0].route.duplicate()
			planning.request_clear(0)
			if not strategy:
				planning.request_edit(0, Vector2i(1, planning.layouts[0].entrance.y), false)
			_check(planning.layouts[0].route == before_path, "Clear is forbidden outside main rounds and ordinary-round path edits are forbidden")
		if strategy:
			_ready_other(planning)
			planning._physics_process(1000.0)
			_check(planning.combat["wave"] == upcoming - 1 and planning.combat["ready_seconds_left"] == -1.0 and not planning.is_physics_processing(), "Initial/main strategy remains untimed after one committed Ready")
		planning.submit_ready(true)
		_check(planning.combat["wave"] == upcoming and planning.combat["phase"] == MatchCombat.Phase.WAVE, "Manual Ready starts the accepted round %d routes" % upcoming)
		if upcoming < 30:
			_clear_wave(planning)
	planning.stop_singleplayer()
	planning.start_singleplayer()
	_check(planning.combat["board_origin_y"] == 0 and planning.combat["towers"] == [[], []] and planning.combat["ready_seconds_left"] == -1.0, "Leaving an expanded match restores initial combat and origin state for a fresh run")
	for slot: int in range(2):
		_check(planning.layouts[slot].dimensions == Vector2i(14, 9) and planning.layouts[slot].budget == 30 and planning.layouts[slot].entrance == Vector2i(0, 4) and planning.layouts[slot].base == Vector2i(13, 4) and planning.layouts[slot].used_tiles() == 0 and planning.layouts[slot].route.is_empty(), "A fresh run restores the captured initial grid, endpoints, budget and empty path on both boards")
	_dispose(planning)


func _test_autoplay_strategy_pause() -> void:
	var planning: MatchPlanning = _new_model()
	planning.request_pacing("autoplay", true)
	planning.request_pacing("speed", true)
	planning._physics_process(30.0)
	_check(planning.combat["wave"] == 0 and planning.combat["ready_seconds_left"] == -1.0, "Autoplay never skips initial setup")
	planning.submit_ready(true)
	for upcoming: int in [10, 20, 30]:
		while planning.combat["phase"] == MatchCombat.Phase.WAVE and int(planning.combat["wave"]) < upcoming:
			planning._physics_process(1.0)
		_check(planning.combat["wave"] == upcoming - 1 and planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["main_round"] and planning.combat["autoplay"] and planning.combat["autoplay_votes"] == [true, true] and planning.combat["speed_votes"] == [true, true] and not planning.is_physics_processing(), "Autoplay pauses before main round %d without erasing either unanimous vote" % upcoming)
		_ready_other(planning)
		planning._physics_process(1000.0)
		_check(planning.combat["wave"] == upcoming - 1 and planning.combat["ready_seconds_left"] == -1.0, "A main-round first Ready cannot start a deadline, even with autoplay and 2x enabled")
		planning.submit_ready(true)
		_check(planning.combat["wave"] == upcoming, "Both manual Ready votes resume a main strategy phase")
		planning._physics_process(1.0)
		_check(planning.combat["wave"] == upcoming + 1 and planning.combat["phase"] == MatchCombat.Phase.WAVE, "Preserved autoplay resumes immediately after the main round clears")
	_dispose(planning)
