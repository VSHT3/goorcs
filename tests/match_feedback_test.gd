extends SceneTree
## Big-moment feedback reads accepted snapshots only: boss arrival and round
## clear banners, crystal hits, the approaching-leak warning and kill bounty
## facts. None of it may change accepted match state.

var failures: int = 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	_test_kill_and_clear_facts()
	_test_banner_rules()
	_test_health_feedback()
	_test_board_feedback()
	directory = OS.get_temp_dir().path_join("gorcs_match_feedback_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower", "lightning", "war_drums", "rune_obelisk"]}))
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	root.add_child(main)
	await process_frame
	await _test_match(main)
	main.play_screen.prepare_to_leave()
	for player: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	await create_timer(0.1).timeout
	main.queue_free()
	main = null
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: kill events carry the paid bounty, clears publish their gains, boss/round banners, base-hit and leak-warning feedback follow accepted state without changing it")
	quit.call_deferred(1 if failures > 0 else 0)


func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new()
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 4))
	return [layout.capture_routing(), layout.capture_routing()]


func _sandbox_model() -> MatchCombat:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.enemy_health = 1
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	var model := MatchCombat.new(rules)
	var roster: Array[String] = []
	model.sandbox_start(_routes(), 1, roster)
	return model


func _test_kill_and_clear_facts() -> void:
	var model: MatchCombat = _sandbox_model()
	_check(int(model.snapshot()["clears"]["count"]) == 0, "A fresh run has cleared nothing")
	model.build(0, Vector2i(0, 3), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	model.sandbox_spawn(0, &"orc_chief", 1)
	var before: int = model.coins[0]
	var shards_before: int = model.reroll_currency[0]
	var kill_coins: int = -1
	for tick: int in range(400):
		model.advance(0.05)
		var deaths: Array = model.snapshot()["deaths"][0]
		if not deaths.is_empty():
			kill_coins = int(deaths[0]["coins"])
			break
	_check(kill_coins > 0, "A tower kill publishes the bounty it paid")
	var snapshot: Dictionary = model.snapshot()
	var clears: Dictionary = snapshot["clears"]
	_check(int(clears["count"]) == 1 and model.phase == MatchCombat.Phase.PLANNING, "The sandbox wave cleared once")
	var gains: Array = clears["gains"][0]
	_check(before + kill_coins + int(gains[0]) == model.coins[0], "Kill bounty plus clear gain account for every Coin received")
	_check(shards_before + int(gains[1]) <= model.reroll_currency[0] and int(gains[1]) > 0, "Clear Shards are published for the board")
	var count: int = int(clears["count"])
	model.debug_set_round(5)
	_check(int(model.snapshot()["clears"]["count"]) == count, "A debug round jump abandons a round and never counts as a clear")


func _types() -> Dictionary:
	return {"troll": {"boss": true, "title": "Trollorc"}, "grunt": {"boss": false, "title": "Orc"}}


func _state(run: String, enemies: Array, clears: int = 0, phase: int = MatchCombat.Phase.WAVE, gains: Array = [[0, 0], [0, 0]]) -> Dictionary:
	return {"statistics_id": run, "phase": phase, "wave": 7, "enemies": [enemies, [{"id": 900, "type_id": "troll"}]],
		"enemy_types": _types(), "clears": {"count": clears, "gains": gains}}


func _test_banner_rules() -> void:
	var banner := MatchBanner.new()
	banner.catalog = preload("res://resources/content_catalog.tres")
	banner.size = Vector2(1280, 720)
	root.add_child(banner)
	banner.observe(_state("a", [{"id": 1, "type_id": "troll"}]), 0)
	_check(banner.current().is_empty(), "A boss already present when a run is first seen is not announced")
	banner.observe(_state("a", [{"id": 1, "type_id": "troll"}, {"id": 2, "type_id": "grunt"}]), 0)
	_check(banner.current().is_empty(), "Ordinary orcs never raise a banner")
	banner.observe(_state("a", [{"id": 1, "type_id": "troll"}, {"id": 3, "type_id": "troll"}]), 0)
	_check(banner.current_kind() == "boss" and banner.current()["title"] == "Trollorc", "A new boss on your board raises its banner with the accepted title")
	banner.observe(_state("a", [{"id": 1, "type_id": "troll"}, {"id": 3, "type_id": "troll"}]), 0)
	_check(banner.queued().is_empty(), "One boss is announced once, not every snapshot")
	banner.observe(_state("a", [{"id": 4, "type_id": "troll"}]), 0)
	_check(banner.queued().is_empty(), "Another boss of a type already showing does not stack a duplicate")
	banner.clear()
	banner.observe(_state("a", [], 1, MatchCombat.Phase.PLANNING, [[42, 3], [10, 0]]), 0)
	_check(banner.current_kind() == "round" and int(banner.current()["round"]) == 7 and int(banner.current()["coins"]) == 42 and int(banner.current()["shards"]) == 3, "A counted clear shows the round and your own accepted gains")
	banner.observe(_state("a", [], 1, MatchCombat.Phase.PLANNING), 0)
	_check(banner.queued().is_empty(), "The same clear count does not repeat")
	banner.observe(_state("a", [{"id": 5, "type_id": "troll"}], 1), 0)
	_check(banner.queued().size() == 1 and banner._elapsed >= MatchBanner.ENTER + MatchBanner.ROUND_HOLD, "A boss cuts a round beat short and waits only for its exit")
	for step: int in range(40):
		banner._process(0.1)
	_check(banner.current().is_empty() and not banner.is_processing(), "Banners finish in a few seconds of local time and stop processing")
	banner.observe(_state("a", [{"id": 6, "type_id": "troll"}], 1, MatchCombat.Phase.FINISHED), 0)
	_check(banner.current().is_empty(), "Results clear banners instead of announcing")
	banner.observe(_state("b", [], 3), 0)
	_check(banner.current().is_empty(), "A new run only sets its baseline, even with earlier clears")
	var opponent_boss: Dictionary = _state("b", [], 3)
	opponent_boss["enemies"][1].append({"id": 901, "type_id": "troll"})
	banner.observe(opponent_boss, 0)
	_check(banner.current().is_empty(), "A boss arriving on the opponent's board is not announced on yours")
	banner.queue_free()


func _test_health_feedback() -> void:
	var feedback := BaseHealthFeedback.new()
	root.add_child(feedback)
	feedback.observe("a", 100, 100)
	_check(feedback.pop_amount == 0 and not feedback.is_active(), "The first accepted value is only a baseline")
	feedback.observe("a", 97, 100)
	_check(feedback.pop_amount == 3 and is_equal_approx(feedback.trail, 100.0) and feedback.is_active(), "A leak pops the HP lost and leaves a trail at the old value")
	feedback._process(0.2)
	feedback.observe("a", 91, 100)
	_check(feedback.pop_amount == 9, "Quick successive leaks add into one number")
	for step: int in range(30):
		feedback._process(0.1)
	_check(not feedback.is_active() and is_equal_approx(feedback.trail, 91.0), "The trail drains to accepted HP and processing stops")
	feedback.observe("a", 95, 100)
	_check(feedback.pop_amount == 0 and not feedback.is_active(), "Healing never reads as a hit")
	feedback.observe("a", 90, 100)
	feedback._process(0.8)
	feedback.observe("a", 89, 100)
	_check(feedback.pop_amount == 1, "A later separate leak starts a fresh number")
	feedback.observe("b", 50, 100)
	_check(feedback.pop_amount == 0 and not feedback.is_active(), "A new run resets without a hit")
	feedback.queue_free()


func _board_state(run: String, health: int, enemies: Array = []) -> Dictionary:
	return {"statistics_id": run, "health": [health, 100], "enemies": [enemies, []], "towers": [[], []], "deaths": [[], []], "death_time": 0.0}


func _test_board_feedback() -> void:
	var board := PathBoard.new()
	board.size = Vector2(700, 500)
	board.layout = PathLayout.new(Vector2i(9, 7), 50, Vector2i(0, 3), Vector2i(8, 3))
	for x: int in range(1, 8):
		board.layout.place(Vector2i(x, 3))
	root.add_child(board)
	board.apply_combat(_board_state("a", 100), 0)
	_check(board._crystal_hits.is_empty(), "The first snapshot of a run is only a health baseline")
	var state: Dictionary = _board_state("a", 94)
	var copy: Dictionary = state.duplicate(true)
	board.apply_combat(state, 0)
	_check(board._crystal_hits.size() == 1 and int(board._crystal_hits[0]["damage"]) == 6, "Accepted HP lost hits this board's crystal with its size")
	_check(state == copy, "Presentation never edits the accepted snapshot")
	board.apply_combat(_board_state("a", 94), 0, 1.0, true)
	board._process(1.0)
	_check(board._crystal_hits.size() == 1 and is_zero_approx(float(board._crystal_hits[0]["age"])), "Paused simulation holds the crystal hit")
	board.apply_combat(_board_state("a", 94), 0, 3.0)
	board._process(0.1)
	_check(is_equal_approx(float(board._crystal_hits[0]["age"]), 0.3), "The hit plays on simulation time at 3x")
	board._process(1.0)
	_check(board._crystal_hits.is_empty(), "Crystal hits expire")
	board.apply_combat(_board_state("b", 40), 0)
	_check(board._crystal_hits.is_empty(), "A new run with lower HP is a baseline, not a hit")
	var route: Array = []
	for x: int in range(0, 9):
		route.append(Vector2i(x, 3))
	var far: Dictionary = {"id": 1, "type_id": "grunt", "hp": 5, "max_hp": 5, "progress": 1.0, "pos": Vector2(1, 3), "route": route}
	board.apply_combat(_board_state("b", 40, [far]), 0)
	_check(is_zero_approx(board.leak_danger()), "No warning while enemies are far from the crystal")
	var near: Dictionary = far.duplicate(true)
	near["id"] = 2
	near["progress"] = float(route.size() - 1) - 0.5
	board.apply_combat(_board_state("b", 40, [far, near]), 0)
	_check(board.leak_danger() > 0.8, "An enemy half a cell from the crystal raises the warning")
	board.queue_free()


func _test_match(main) -> void:
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	planning.set_physics_process(false)
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Feedback fixture commits a deck")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var layout: PathLayout = planning.layouts[0]
	var step: int = 1 if layout.base.x > layout.entrance.x else -1
	var x: int = layout.entrance.x + step
	while x != layout.base.x:
		planning.request_edit(0, Vector2i(x, layout.entrance.y), true)
		x += step
	planning.submit_ready(true)
	var start_health: int = int(planning.combat["health"][0])
	var coins_before_clear: int = 0
	var leaked: bool = false
	var cleared: bool = false
	for tick: int in range(6000):
		var previous: Dictionary = planning.combat
		coins_before_clear = int(previous["coins"][0])
		planning._physics_process(0.05)
		var health: int = int(planning.combat["health"][0])
		if not leaked and health < start_health:
			leaked = true
			_check(screen.health_feedback.pop_amount == start_health - health and screen.health_feedback.is_active(), "A real leak pops exactly the accepted HP lost on the HUD")
			_check(not screen.boards[0]._crystal_hits.is_empty() and int(screen.boards[0]._crystal_hits[-1]["damage"]) == start_health - health, "Your crystal reacts with the accepted HP lost")
		if int(planning.combat["phase"]) == MatchCombat.Phase.PLANNING:
			cleared = true
			break
	_check(leaked and cleared, "An undefended first round leaks and then clears")
	_check(screen.banner.current_kind() == "round" and int(screen.banner.current()["round"]) == 1, "Clearing the round raises the round banner")
	_check(int(screen.banner.current()["coins"]) == int(planning.combat["clears"]["gains"][0][0]) and int(screen.banner.current()["coins"]) > 0, "The banner shows the accepted clear gain")
	for width: int in [1280, 1000]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i(width, 720)
		await process_frame
		var panel: Rect2 = screen.banner.panel_rect()
		_check(Rect2(Vector2.ZERO, Vector2(width, 720)).encloses(panel) and not panel.intersects(screen.get_node("HUD/Header").get_global_rect()), "Round banner sits on screen below the header at %dpx" % width)
	_check(planning.debug_set_values(60, 50000, 50), "Solo debug selects the Trollorc debut round")
	_check(screen.banner.current().is_empty() or screen.banner.current_kind() == "round", "A debug jump raises no new banner")
	planning.submit_ready(true)
	var troll_id: int = -1
	for tick: int in range(4000):
		planning._physics_process(0.05)
		for enemy: Dictionary in planning.combat["enemies"][0]:
			if String(enemy["type_id"]) == "troll":
				troll_id = int(enemy["id"])
		if troll_id >= 0:
			break
	_check(troll_id >= 0, "The guaranteed Trollorc spawns")
	var announced: Array = [screen.banner.current()] + screen.banner.queued()
	_check(announced.any(func(entry: Dictionary) -> bool: return entry.get("type_id", "") == "troll" and entry["title"] == "Trollorc"), "The Trollorc's arrival is announced by name")
	var before: Dictionary = planning.combat.duplicate(true)
	screen._refresh()
	_check(planning.combat == before, "Refreshing feedback never changes accepted match state")
	for width: int in [1280, 1000]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i(width, 720)
		await process_frame
		screen._enemy_clicked(troll_id, 0)
		await process_frame
		_check(screen._enemy_inspector.visible, "The inspected Trollorc opens the right-side inspector")
		var panel: Rect2 = screen.banner.panel_rect()
		for control: Control in [screen._management, screen._enemy_inspector, screen.get_node("HUD/Header")]:
			if control.is_visible_in_tree():
				_check(not panel.intersects(control.get_global_rect()), "Boss banner keeps clear of %s at %dpx" % [control.name, width])
	screen.cancel_interaction()
