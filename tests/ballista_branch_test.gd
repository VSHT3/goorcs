extends SceneTree
## Ballista branch upgrades: ordered Bigger/Biggest Wood and Magic Ballista chains,
## their compounding stats, pierce/reach/lane rules, decaying magic redirects
## that loop back only when no new enemy remains, and Roman-numeral levels.

const PIERCE_PATH: Array[String] = ["bigger_wood_1", "bigger_wood_2", "biggest_wood_1", "biggest_wood_2", "biggest_wood_3"]

var failures: int = 0


func _init() -> void:
	_test_validation()
	_test_purchase_order_and_stats()
	_test_pierce_and_reach()
	_test_magic_redirects()
	_test_magic_loops_without_new_enemies()
	_test_double_and_stronger_magic()
	_test_roman_levels()
	if failures == 0:
		print("PASS: ordered Bigger/Biggest Wood and Magic/Double/Stronger Magic/S.U.M.G.G.M. chains, compounding stats, pierce/reach, decaying looping and split magic redirects, and Roman levels")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _rules() -> CombatRules:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	return rules


# A Ballista at (0, 1) looking along a straight route on row 1 toward it.
func _combat(commands: Array[String], seed_value: int = 7) -> MatchCombat:
	var wave_random := RandomNumberGenerator.new()
	wave_random.seed = seed_value
	var combat := MatchCombat.new(_rules(), null, wave_random)
	combat.build(0, Vector2i(0, 1), &"orc_ballista", MatchCombat.TargetMode.FURTHEST)
	var tower: Dictionary = combat.towers[0][0]
	for command: String in ["damage", "speed"] + commands:
		_check(combat.upgrade_tower(0, tower["id"], command), "Ordered purchase accepted: %s" % command)
	return combat


func _route() -> Array:
	var route: Array = []
	for x: int in range(12, 0, -1):
		route.append(Vector2i(x, 1))
	return route


func _routing() -> Array[Dictionary]:
	var route: Array = _route()
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


# Freeze enemies at the given x cells (route progress 12 - x) with large HP.
func _place(combat: MatchCombat, cells_x: Array) -> void:
	combat.sandbox_start(_routing(), 1, [] as Array[String])
	combat.sandbox_spawn(0, &"grunt", cells_x.size())
	for index: int in range(cells_x.size()):
		var enemy: Dictionary = combat.enemies[0][index]
		enemy["progress"] = 12.0 - float(cells_x[index])
		enemy["pos"] = combat._position(enemy["route"], enemy["progress"])
		enemy["hp"] = 1000
		enemy["max_hp"] = 1000
		enemy["base_speed"] = 0.0
		enemy["speed"] = 0.0


func _fire(combat: MatchCombat) -> Dictionary:
	var tower: Dictionary = combat.towers[0][0]
	tower["cooldown"] = 0.0
	combat.advance(0.001)
	return tower


func _damaged(combat: MatchCombat) -> Array:
	var cells: Array = []
	for enemy: Dictionary in combat.enemies[0]:
		if int(enemy["hp"]) < 1000:
			cells.append(Vector2(enemy["pos"]).round().x)
	cells.sort()
	return cells


func _test_validation() -> void:
	var definition: TowerDefinition = (load("res://resources/combat/towers/orc_ballista.tres") as TowerDefinition)
	_check(TowerDefinition.valid_evolutions(definition), "Shipped Ballista branch upgrades validate")
	var magic := {"id": "m", "title": "M", "cost": 1, "magic_bounce": {"chance": 0.75, "decay": 0.05}}
	_check(TowerDefinition.valid_branch_upgrades("bounce", [magic]), "Magic redirect odds are valid on the Bounce branch")
	_check(not TowerDefinition.valid_branch_upgrades("pierce", [magic]), "Magic redirects never belong to the Pierce branch")
	_check(not TowerDefinition.valid_branch_upgrades("bounce", [{"id": "m", "title": "M", "cost": 1, "magic_bounce": {"chance": 1.5, "decay": 0.05}}]), "Redirect chance above 100% is rejected")
	_check(not TowerDefinition.valid_branch_upgrades("pierce", [{"id": "a", "title": "A", "cost": 1}, {"id": "a", "title": "B", "cost": 1}]), "Duplicate step IDs are rejected")
	_check(not TowerDefinition.valid_branch_upgrades("pierce", [{"id": "a", "title": "A", "cost": 1, "explode": true}]), "Unknown step fields are rejected")
	_check(not TowerDefinition.valid_branch_upgrades("pierce", []), "An empty chain is rejected")
	_check(not TowerDefinition.valid_branch_upgrades("pierce", [{"id": "d", "title": "D", "cost": 1, "magic_split": 2}]), "Magic splits never belong to the Pierce branch")
	_check(not TowerDefinition.valid_branch_upgrades("bounce", [{"id": "d", "title": "D", "cost": 1, "magic_split": 1}]), "A split must create at least two bolts")
	_check(not TowerDefinition.valid_branch_upgrades("bounce", [{"id": "d", "title": "D", "cost": 1, "magic_split": TowerDefinition.MAX_MAGIC_SPLIT + 1}]), "Splits are bounded")


func _test_purchase_order_and_stats() -> void:
	var combat := _combat(["pierce"])
	var tower: Dictionary = combat.towers[0][0]
	_check(not combat.upgrade_tower(0, tower["id"], "bigger_wood_2"), "Bigger Wood II requires Bigger Wood I")
	_check(not combat.upgrade_tower(0, tower["id"], "magic_ballista"), "Magic Ballista is unavailable on the Pierce branch")
	var damage: float = float(tower["base_damage"])
	var interval: float = float(tower["base_interval"])
	var level: int = MatchCombat.tower_level(tower)
	var multipliers: Array[float] = [1.5, 1.5, 1.25, 1.25, 1.25]
	for index: int in range(PIERCE_PATH.size()):
		_check(combat.upgrade_tower(0, tower["id"], PIERCE_PATH[index]), "Next step in order is accepted: %s" % PIERCE_PATH[index])
		damage *= multipliers[index]
		if index >= 2:
			interval /= 0.875
		_check(is_equal_approx(float(tower["base_damage"]), damage) and tower["damage"] == ceili(damage - 0.000000001), "Damage compounds per step: %s" % PIERCE_PATH[index])
		_check(is_equal_approx(float(tower["base_interval"]), interval), "Biggest Wood alone slows attacks by 12.5%%: %s" % PIERCE_PATH[index])
		_check(tower["branch_pierce"] == index + 1 and MatchCombat.tower_level(tower) == level + index + 1, "Each step adds one pierce and one level")
	_check(is_equal_approx(float(tower["bolt_scale"]), 1.0 + 3 * 0.35) and is_equal_approx(float(tower["bolt_reach"]), 3.0), "Biggest Wood grows the bolt and its reach three times")
	_check(not combat.upgrade_tower(0, tower["id"], "biggest_wood_3"), "A finished chain cannot be bought again")
	_check(combat._tower_damage_type(tower) == &"physical", "Wood bolts stay physical")
	var magic := _combat(["bounce"])
	tower = magic.towers[0][0]
	_check(not magic.upgrade_tower(0, tower["id"], "bigger_wood_1"), "Wood steps are unavailable on the Bounce branch")
	_check(magic._tower_damage_type(tower) == &"physical", "Bounce 1 is physical before Magic Ballista")
	_check(magic.upgrade_tower(0, tower["id"], "magic_ballista") and magic._tower_damage_type(tower) == &"magic", "Magic Ballista changes the damage type to magic")
	var actions: Dictionary = MatchPlanningScreen.tower_upgrade_actions(tower, magic._tower_types["orc_ballista"])
	_check(actions.has("magic_ballista") and actions["magic_ballista"]["purchased"], "Inspection lists the purchased Magic Ballista step")
	_check(MatchPlanningScreen.tower_display_title(tower, magic._tower_types["orc_ballista"]).begins_with("Magic Ballista"), "The tower title follows the last purchased step")


func _test_pierce_and_reach() -> void:
	# Bigger Wood II: Pierce 2 plus two steps = four contacts, all within range 4.
	var combat := _combat(["pierce", "bigger_wood_1", "bigger_wood_2"])
	_place(combat, [2, 3, 4, 5, 6])
	_fire(combat)
	_check(_damaged(combat) == [2.0, 3.0, 4.0], "Bigger Wood pierce stops at the tower's range: %s" % [_damaged(combat)])
	# One Biggest Wood step lets the bolt fly one cell further.
	combat = _combat(["pierce", "bigger_wood_1", "bigger_wood_2", "biggest_wood_1"])
	_place(combat, [2, 3, 4, 5, 6, 7])
	var tower: Dictionary = _fire(combat)
	_check(_damaged(combat) == [2.0, 3.0, 4.0, 5.0], "Longer bolt reach hits one cell past range: %s" % [_damaged(combat)])
	_check(tower["pierce_active"] and Vector2(tower["pierce_aim"]).x > 5.0, "The presented bolt flies to the extended reach")


func _expected_extra_bounces(seed_value: int, chance: float, decay: float, limit: int) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var extras: int = 0
	while extras < limit and chance > 0.000000001 and random.randf() < chance:
		chance -= decay
		extras += 1
	return extras


func _test_magic_redirects() -> void:
	var saw_extra: bool = false
	for seed_value: int in range(1, 9):
		var combat := _combat(["bounce", "magic_ballista"], seed_value)
		_place(combat, [2, 4, 6, 8, 10, 11, 12, 3, 5])
		var magic_seed: int = combat._magic_random.seed
		var tower: Dictionary = _fire(combat)
		var extras: int = _expected_extra_bounces(magic_seed, 0.75, 0.05, MatchCombat.MAX_BOUNCE_POINTS - 1)
		var points: Array = tower["bounce_points"]
		_check(points.size() == 1 + extras, "Guaranteed bounce plus decaying 75%% / -5%% extra redirects, seed=%d expected=%d got=%d" % [seed_value, 1 + extras, points.size()])
		saw_extra = saw_extra or extras > 0
		for index: int in range(1, points.size()):
			_check(points[index] != points[index - 1], "A redirect never stays on the enemy it just hit")
	_check(saw_extra, "Some seeds produce extra magic redirects")


func _test_magic_loops_without_new_enemies() -> void:
	var combat := _combat(["bounce", "magic_ballista"])
	var step: Dictionary = combat._tower_types["orc_ballista"]["evolutions"]["bounce"]["upgrades"][0]
	step["magic_bounce"] = {"chance": 1.0, "decay": 0.0}
	combat._refresh_board(0)
	_place(combat, [2, 4])
	var tower: Dictionary = _fire(combat)
	var points: Array = tower["bounce_points"]
	_check(points.size() == MatchCombat.MAX_BOUNCE_POINTS, "Certain redirects loop until the bounded cap: %d" % points.size())
	var alternating: bool = true
	for index: int in range(points.size()):
		alternating = alternating and Vector2(points[index]).round() == (Vector2(4, 1) if index % 2 == 0 else Vector2(2, 1))
	_check(alternating, "With no new enemy left the bolt loops back and forth between earlier victims")
	combat = _combat(["bounce", "magic_ballista"])
	_place(combat, [2])
	tower = _fire(combat)
	_check(tower["bounce_points"].is_empty() and int(combat.enemies[0][0]["hp"]) == 1000 - int(tower["damage_dealt"]) and int(tower["damage_dealt"]) > 0, "A lone enemy is hit once; a bolt never redirects onto itself")


func _test_roman_levels() -> void:
	var expected: Dictionary = {1: "I", 4: "IV", 5: "V", 6: "VI", 9: "IX", 10: "X", 14: "XIV", 40: "XL", 49: "XLIX"}
	for value: int in expected:
		_check(MatchPlanningScreen.roman_numeral(value) == expected[value], "Level %d displays as %s" % [value, expected[value]])
	var path: Array[String] = ["pierce"]
	path.append_array(PIERCE_PATH)
	var combat := _combat(path)
	var tower: Dictionary = combat.towers[0][0]
	var title: String = MatchPlanningScreen.tower_display_title(tower, combat._tower_types["orc_ballista"])
	_check(title.ends_with("· " + MatchPlanningScreen.roman_numeral(MatchCombat.tower_level(tower))) and MatchCombat.tower_level(tower) > 5, "High tower levels keep Roman numerals: %s" % title)


# Replays the model's sequential magic rolls: each bolt rolls until its first
# failure, then the next bolt continues on the same stream.
func _roll_chain(random: RandomNumberGenerator, chance: float, decay: float) -> int:
	var extras: int = 0
	while chance > 0.000000001 and random.randf() < chance:
		chance -= decay
		# Like the model, a success past the bounded cap is consumed, then stops.
		if extras + 1 >= MatchCombat.MAX_BOUNCE_POINTS:
			break
		extras += 1
	return extras


func _test_double_and_stronger_magic() -> void:
	var combat := _combat(["bounce"])
	var tower: Dictionary = combat.towers[0][0]
	_check(not combat.upgrade_tower(0, tower["id"], "double_magic"), "Double Magic requires Magic Ballista")
	_check(combat.upgrade_tower(0, tower["id"], "magic_ballista") and not combat.upgrade_tower(0, tower["id"], "stronger_magic"), "Stronger Magic requires Double Magic")
	_check(combat.upgrade_tower(0, tower["id"], "double_magic") and tower["magic_split"] == 2 and is_equal_approx(float(tower["magic_bounce"]["chance"]), 0.75), "Double Magic splits the bolt and keeps the original odds")
	_check(not combat.upgrade_tower(0, tower["id"], "sumggm"), "S.U.M.G.G.M. requires Stronger Magic")
	_check(combat.upgrade_tower(0, tower["id"], "stronger_magic") and is_equal_approx(float(tower["magic_bounce"]["chance"]), 0.8) and is_equal_approx(float(tower["magic_bounce"]["decay"]), 0.04), "Stronger Magic raises redirects to 80% and slows the decay to 4 points")
	_check(tower["magic_split"] == 2 and combat._tower_damage_type(tower) == &"magic", "Stronger Magic keeps the split and magic damage")
	_check(combat.upgrade_tower(0, tower["id"], "sumggm") and tower["magic_split"] == 5 and is_equal_approx(float(tower["magic_bounce"]["chance"]), 0.95) and is_equal_approx(float(tower["magic_bounce"]["decay"]), 0.03), "S.U.M.G.G.M. splits into five bolts with 95% / -3 odds")
	_check(MatchPlanningScreen.tower_display_title(tower, combat._tower_types["orc_ballista"]).begins_with("S.U.M.G.G.M."), "The tower is titled S.U.M.G.G.M.")
	var chains: Array = [
		[["bounce", "magic_ballista", "double_magic"], 2, 0.75, 0.05],
		[["bounce", "magic_ballista", "double_magic", "stronger_magic"], 2, 0.8, 0.04],
		[["bounce", "magic_ballista", "double_magic", "stronger_magic", "sumggm"], 5, 0.95, 0.03],
	]
	for chain: Array in chains:
		var bolts: int = chain[1]
		var saw_divergence: bool = false
		for seed_value: int in range(1, 9):
			var typed: Array[String] = []
			typed.assign(chain[0])
			combat = _combat(typed, seed_value)
			_place(combat, [2, 4, 6, 8, 10, 11, 12, 3, 5])
			var replay := RandomNumberGenerator.new()
			replay.seed = combat._magic_random.seed
			tower = _fire(combat)
			var paths: Array = [tower["bounce_points"]]
			paths.append_array(tower["split_paths"])
			_check(paths.size() == bolts, "%d bolts after the first hit, seed=%d" % [bolts, seed_value])
			var firsts: Dictionary = {}
			for path: Array in paths:
				var extras: int = _roll_chain(replay, float(chain[2]), float(chain[3]))
				_check(path.size() == 1 + extras, "Each bolt takes a guaranteed bounce then rolls its own %.0f%% / -%.0f odds, seed=%d" % [float(chain[2]) * 100.0, float(chain[3]) * 100.0, seed_value])
				if not path.is_empty():
					firsts[path[0]] = true
			saw_divergence = saw_divergence or firsts.size() == bolts
		_check(saw_divergence, "Split bolts seek different first victims while enough enemies exist (%d bolts)" % bolts)
	combat = _combat(["bounce", "magic_ballista"])
	_place(combat, [2, 4, 6])
	tower = _fire(combat)
	_check(tower["split_paths"].is_empty(), "Magic Ballista alone never splits")
