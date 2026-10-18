extends SceneTree
## Orcapult: grabbing the nearest throwable enemies, the bucket slam, flights
## onto the opponent's board, lift limits, Double Scoop, both evolution chains,
## wave-clear gating, Sandbox self-throws and renderer flight capture.

const SIEGE: Array[String] = ["iron_counterweight", "ogre_crew", "warlords_trebuchet"]
const LONG_TOSS: Array[String] = ["greased_sling", "rude_awakening", "over_the_wall"]

var failures: int = 0


func _init() -> void:
	_test_validation()
	_test_throw_and_landing()
	_test_lift_and_bosses()
	_test_slam()
	_test_double_scoop_and_branches()
	_test_wave_clear_waits_for_flights()
	_test_sandbox_self_throw()
	_test_renderer_capture()
	if failures == 0:
		print("PASS: Orcapult grabs the nearest throwable enemies, slams their neighbours, lands them on the opponent's board after the flight, respects lift/boss/re-throw limits, upgrades through Double Scoop, Siege Arm and Long Toss, holds wave clear while airborne, self-throws in Sandbox and renders flights")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _rules(sandbox: bool = false) -> CombatRules:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = sandbox
	rules.roll_rules = null
	rules.starting_coins = 1000000
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	return rules


func _definition() -> TowerDefinition:
	for definition: TowerDefinition in _rules().catalog.towers:
		if definition.reward.id == &"orcapult":
			return definition
	return null


func _routing() -> Array[Dictionary]:
	var route: Array = []
	for x: int in range(12, -1, -1):
		route.append(Vector2i(x, 0))
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


# A sandbox-started fixture: no regular roster, enemies placed by hand.
func _fixture(commands: Array = [], sandbox: bool = false) -> MatchCombat:
	# Built and started as a Sandbox; match fixtures then throw across boards.
	var combat := MatchCombat.new(_rules(true))
	combat.build(0, Vector2i(6, 1), &"orcapult", MatchCombat.TargetMode.FURTHEST)
	var tower: Dictionary = combat.towers[0][0]
	for command: Variant in commands:
		_check(combat.upgrade_tower(0, tower["id"], String(command)), "Orcapult accepts %s" % command)
	_check(combat.sandbox_start(_routing(), 1, [] as Array[String]), "Fixture wave starts")
	combat._sandbox_mode = sandbox
	return combat


func _place(combat: MatchCombat, type_id: StringName, progress: float, hp: int = 1000) -> Dictionary:
	var sandbox: bool = combat._sandbox_mode
	combat._sandbox_mode = true
	_check(combat.sandbox_spawn(0, type_id, 1), "Fixture spawns %s" % type_id)
	combat._sandbox_mode = sandbox
	var enemy: Dictionary = combat.enemies[0].back()
	enemy["progress"] = progress
	enemy["pos"] = combat._position(enemy["route"], progress)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["base_speed"] = 0.0
	enemy["speed"] = 0.0
	return enemy


func _test_validation() -> void:
	var shipped := _definition()
	_check(shipped != null and _rules().catalog.validation_errors().is_empty(), "The shipped catalog registers a valid Orcapult")
	var broken: TowerDefinition = shipped.duplicate(true)
	broken.behavior_config["throw_count"] = 0
	_check(not TowerDefinition.valid_evolutions(broken), "An Orcapult must throw at least one enemy")
	broken = shipped.duplicate(true)
	broken.behavior_config["landing_haste"] = 0.5
	_check(not TowerDefinition.valid_evolutions(broken), "Landing haste never slows thrown enemies")
	broken = shipped.duplicate(true)
	broken.special_upgrade = "escalating_chain"
	_check(not TowerDefinition.valid_special_upgrade(broken), "Escalating Chain belongs to chain towers")
	broken = shipped.duplicate(true)
	broken.evolutions["longer_reach"] = broken.evolutions["long_toss"]
	_check(not TowerDefinition.valid_evolutions(broken), "Orcapult branches are restricted")
	_check(not TowerDefinition.valid_branch_upgrades("boulders", [{"id": "x", "title": "X", "cost": 1, "behavior_add": {"lift": 1.0}}]), "Only Orcapult branches may raise lift")
	_check(not TowerDefinition.valid_branch_upgrades("siege_arm", [{"id": "x", "title": "X", "cost": 1, "behavior_add": {"throw_count": 1.5}}]), "Extra throws are whole enemies")
	_check(not TowerDefinition.valid_branch_upgrades("siege_arm", [{"id": "x", "title": "X", "cost": 1, "pierce": 1}]), "Orcapult steps reject bolt fields")


func _test_throw_and_landing() -> void:
	var combat := _fixture()
	var tower: Dictionary = combat.towers[0][0]
	# Tower at x=6: the enemy at x=6 is nearest; x=8 is further along but farther away.
	var far := _place(combat, &"grunt", 4.0, 500)
	var near := _place(combat, &"grunt", 6.0, 700)
	near["hp"] = 650
	combat.advance(1.0 / 60.0)
	_check(combat.flights.size() == 1 and int(combat.flights[0]["enemy"]["id"]) == int(near["id"]), "The nearest enemy is grabbed, not the furthest along")
	_check(combat._enemy_index(0, near["id"]) < 0 and combat._enemy_index(0, far["id"]) >= 0, "The thrown enemy leaves this board")
	_check(int(tower["thrown"]) == 1 and int(tower["shot"]) == 1, "Throws count on the tower")
	var flight: Dictionary = combat.flights[0]
	_check(int(flight["to_slot"]) == 1 and combat.snapshot()["flights"].size() == 1, "A match throw targets the opponent and is published")
	combat.advance(MatchCombat.FLIGHT_DURATION * 0.5)
	_check(combat.enemies[1].is_empty(), "Nothing lands before the flight ends")
	combat.advance(MatchCombat.FLIGHT_DURATION * 0.5 + 0.02)
	_check(combat.flights.is_empty() and combat.enemies[1].size() == 1, "The enemy lands on the opponent's board")
	var landed: Dictionary = combat.enemies[1][0]
	_check(int(landed["hp"]) == 650 and bool(landed["launched"]) and float(landed["progress"]) < 0.5, "It keeps its HP, lands at the portal and is marked as thrown")
	# Thrown enemies are never thrown again, even by another Orcapult.
	combat.build(1, Vector2i(11, 1), &"orcapult", MatchCombat.TargetMode.FURTHEST)
	combat.advance(1.0)
	_check(combat.flights.is_empty() and combat.enemies[1].size() == 1, "An already-thrown enemy cannot be juggled back")


func _test_lift_and_bosses() -> void:
	var combat := _fixture()
	_place(combat, &"brute", 6.0)
	_place(combat, &"troll", 5.0)
	combat.advance(1.0 / 60.0)
	_check(combat.flights.is_empty(), "The base arm cannot lift Brutes or bosses")
	var siege := _fixture(["damage", "speed", "special", "siege_arm"])
	_place(siege, &"brute", 6.0)
	_place(siege, &"troll", 5.0)
	siege.advance(1.0 / 60.0)
	_check(siege.flights.size() == 1 and siege.flights[0]["enemy"]["type_id"] == "brute", "Siege Arm lifts Brutes but never a boss")


func _test_slam() -> void:
	var combat := _fixture()
	var tower: Dictionary = combat.towers[0][0]
	var grabbed := _place(combat, &"grunt", 6.0)
	var neighbour := _place(combat, &"brute", 6.6, 100)
	var distant := _place(combat, &"brute", 9.0, 100)
	combat.advance(1.0 / 60.0)
	_check(combat.flights.size() == 1 and int(combat.flights[0]["enemy"]["id"]) == int(grabbed["id"]), "The liftable Grunt is thrown")
	_check(int(neighbour["hp"]) == 100 - int(tower["damage"]) and int(distant["hp"]) == 100, "The bucket slam only hurts enemies next to the grabbed one")


func _test_double_scoop_and_branches() -> void:
	var combat := _fixture(["damage", "speed", "special"])
	for progress: float in [5.0, 6.0, 7.0]:
		_place(combat, &"grunt", progress)
	combat.advance(1.0 / 60.0)
	_check(combat.flights.size() == 2, "Double Scoop throws two enemies per swing")
	var siege := _fixture(["damage", "speed", "special", "siege_arm"] + SIEGE)
	var tower: Dictionary = siege.towers[0][0]
	var config: Dictionary = tower["behavior_config"]
	_check(int(config["throw_count"]) == 3 and is_equal_approx(float(config["lift"]), 6.0) and is_equal_approx(float(config["slam_radius"]), 1.75), "Warlord's Trebuchet throws three and lifts Chiefs")
	_check(MatchCombat.tower_level(tower) == 5 + SIEGE.size(), "Double Scoop, the evolution and each Siege step add a level")
	_place(siege, &"orc_chief", 6.0)
	siege.advance(1.0 / 60.0)
	_check(siege.flights.size() == 1, "The finale hurls an Orc Chief")
	var toss := _fixture(["damage", "speed", "special", "long_toss"] + LONG_TOSS)
	var toss_config: Dictionary = toss.towers[0][0]["behavior_config"]
	_check(is_equal_approx(float(toss_config["landing_progress"]), 8.0) and is_equal_approx(float(toss_config["landing_haste"]), 1.35), "Over the Wall lands 8 cells in at +35% speed")
	var grunt := _place(toss, &"grunt", 6.0)
	grunt["base_speed"] = 1.0
	grunt["speed"] = 1.0
	toss.advance(1.0 / 60.0)
	toss.advance(MatchCombat.FLIGHT_DURATION + 0.01)
	var landed: Dictionary = toss.enemies[1][0]
	_check(float(landed["progress"]) >= 7.2 and float(landed["progress"]) <= 7.3 and is_equal_approx(float(landed["base_speed"]), 1.35), "Long Toss lands down the path (capped at 60%% of the route) and hastes the enemy: %s" % landed["progress"])
	_check(not toss.upgrade_tower(0, toss.towers[0][0]["id"], "siege_arm"), "The two evolutions are exclusive")


func _test_wave_clear_waits_for_flights() -> void:
	var rules := _rules()
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(6, 1), &"orcapult", MatchCombat.TargetMode.FURTHEST)
	_check(combat.start_wave(_routing()), "A regular wave starts")
	for slot: int in range(2):
		combat.enemies[slot].clear()
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned = [0, 0]
	combat._spawn_enemy(0, "grunt", 6.0, 0.0)
	combat.enemies[0][0]["base_speed"] = 0.0
	combat.advance(1.0 / 60.0)
	_check(combat.flights.size() == 1 and combat.enemies[0].is_empty() and combat.phase == MatchCombat.Phase.WAVE, "An airborne enemy keeps the wave running")
	combat.advance(MatchCombat.FLIGHT_DURATION)
	_check(combat.phase == MatchCombat.Phase.WAVE and combat.enemies[1].size() == 1, "It lands and must still be dealt with")


func _test_sandbox_self_throw() -> void:
	var combat := _fixture([], true)
	_place(combat, &"grunt", 6.0)
	combat.advance(1.0 / 60.0)
	_check(combat.flights.size() == 1 and int(combat.flights[0]["to_slot"]) == 0, "Sandbox throws back to its own portal")
	combat.advance(MatchCombat.FLIGHT_DURATION)
	_check(combat.enemies[0].size() == 1 and bool(combat.enemies[0][0]["launched"]) and float(combat.enemies[0][0]["progress"]) < 0.5, "The enemy lands at this board's portal")


func _test_renderer_capture() -> void:
	var combat := _fixture()
	_place(combat, &"grunt", 6.0)
	combat.advance(1.0 / 60.0)
	var state: Dictionary = combat.snapshot()
	var layout := PathLayout.new(Vector2i(13, 4), 40, Vector2i(12, 0), Vector2i(0, 0))
	var boards: Array[PathBoard] = []
	for slot: int in range(2):
		var board := PathBoard.new()
		board.content_catalog = _rules().catalog
		board.layout = layout
		board.size = Vector2(13, 4) * 48.0
		board.tower_types = state["tower_types"]
		board.combat_towers = state["towers"][slot]
		board.combat_enemies = state["enemies"][slot]
		board.apply_deaths(state, slot)
		boards.append(board)
	_check(boards[0]._flight_traces.size() == 1 and bool(boards[0]._flight_traces[0]["out"]) and not bool(boards[0]._flight_traces[0]["in"]), "The thrower's board draws the launch")
	_check(boards[1]._flight_traces.size() == 1 and bool(boards[1]._flight_traces[0]["in"]), "The opponent's board draws the landing")
	_check(boards[0]._catapult_swings.has(int(combat.towers[0][0]["id"])), "The arm swing is tracked")
	boards[0].apply_deaths(state, 0)
	_check(boards[0]._flight_traces.size() == 1, "A republished flight is not duplicated")
	for board: PathBoard in boards:
		board.free()
