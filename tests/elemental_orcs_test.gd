extends SceneTree
## Tower elements and element immunity (targeting, damage, explosive-as-Fire),
## the Elemental Orcs' spawn debuts, ShaOrc heals/shield refills/OrcShakra, and
## Greater ShaOrc wards that end the moment the caster leaves the board.

const ELEMENTALS: Array[StringName] = [&"ember_orc", &"frost_orc", &"storm_orc", &"arcane_orc", &"elemetal_orc", &"omega_orc"]
const ROUTE: Array = [Vector2i(9, 2), Vector2i(8, 2), Vector2i(7, 2), Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]

var failures: int = 0


func _init() -> void:
	_test_catalog()
	_test_tower_elements()
	_test_immunity()
	_test_spawns()
	_test_shaorc()
	_test_greater_shaorc()
	if failures == 0:
		print("PASS: tower elements, immune-element damage and targeting, explosive as Fire, Elemental Orc debuts, ShaOrc heals/shield refills/OrcShakra and Greater ShaOrc wards that end with the caster")
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


func _definition(rules: CombatRules, id: StringName) -> EnemyDefinition:
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.id == id:
			return definition
	return null


func _board(rules: CombatRules = null) -> MatchCombat:
	var combat := MatchCombat.new(rules if rules != null else _rules())
	var next: Dictionary = {}
	for index: int in range(ROUTE.size()):
		next[ROUTE[index]] = [ROUTE[index + 1]] if index + 1 < ROUTE.size() else []
	var routing: Array[Dictionary] = [{"route": ROUTE, "next": next}, {"route": ROUTE, "next": next}]
	_check(combat.sandbox_start(routing, 1, [] as Array[String]), "The sandbox round starts")
	return combat


func _spawn(combat: MatchCombat, type_id: StringName, progress: float, hp: int = 1000) -> Dictionary:
	_check(combat.sandbox_spawn(0, type_id, 1), "%s spawns" % type_id)
	var enemy: Dictionary = combat.enemies[0].back()
	enemy["progress"] = progress
	enemy["pos"] = combat._position(ROUTE, progress)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["base_speed"] = 0.0
	enemy["speed"] = 0.0
	return enemy


func _test_catalog() -> void:
	var rules := _rules()
	_check(rules.catalog.validation_errors().is_empty(), "The shipped catalog with the new orcs validates: %s" % " ".join(rules.catalog.validation_errors()))
	for id: StringName in ELEMENTALS + [&"shaorc", &"greater_shaorc"]:
		var definition: EnemyDefinition = _definition(rules, id)
		_check(definition != null and definition.animation_frames != null and definition.animation_frames.has_animation(&"walk") and definition.animation_frames.has_animation(&"death"), "%s ships walk and death art" % id)
	for id: StringName in [&"shaorc", &"greater_shaorc"]:
		_check(_definition(rules, id).animation_frames.has_animation(&"heal"), "%s raises its staff" % id)
	_check(not _definition(rules, &"omega_orc").immune_elements.has("physical") and _definition(rules, &"omega_orc").immune_elements.size() == 4, "Omega is immune to everything but Physical")
	_check(_definition(rules, &"greater_shaorc").elite and not _definition(rules, &"shaorc").elite, "Only the Greater ShaOrc is elite")
	# Catalog resources are shared, so each broken value is restored afterwards.
	var storm: EnemyDefinition = _definition(rules, &"storm_orc")
	storm.immune_elements = PackedStringArray(["thunder"])
	_check(not rules.catalog.validation_errors().is_empty(), "Unknown immune elements are rejected")
	storm.immune_elements = PackedStringArray(["lightning"])
	var ember: EnemyDefinition = _definition(rules, &"ember_orc")
	ember.fire_immune = false
	_check(not rules.catalog.validation_errors().is_empty(), "Fire immunity must also block burning")
	ember.fire_immune = true
	var omega: EnemyDefinition = _definition(rules, &"omega_orc")
	omega.immune_elements.append("physical")
	_check(not rules.catalog.validation_errors().is_empty(), "An enemy immune to every element is rejected")
	omega.immune_elements.remove_at(omega.immune_elements.size() - 1)
	_check(rules.catalog.validation_errors().is_empty(), "The restored catalog validates again")


func _test_tower_elements() -> void:
	var combat := MatchCombat.new(_rules())
	var expected: Dictionary = {&"arrow_tower": "physical", &"lightning": "lightning", &"rune_obelisk": "magic", &"orcapult": "physical", &"war_drums": ""}
	var x: int = 0
	for type_id: StringName in expected:
		_check(combat.build(0, Vector2i(x, 0), type_id, MatchCombat.TargetMode.FURTHEST), "%s builds" % type_id)
		var tower: Dictionary = combat.towers[0].back()
		_check(combat.snapshot()["towers"][0].back()["element"] == expected[type_id], "%s publishes element '%s': %s" % [type_id, expected[type_id], tower["element"]])
		x += 2
	_check(TowerDefinition.element_of(&"explosive") == &"fire" and TowerDefinition.element_of(&"ice") == &"ice", "Explosive damage belongs to Fire")
	_check(MatchPlanningScreen.behavior_summary(combat.towers[0][1]).contains("Lightning element"), "The HUD names the tower's element")


func _test_immunity() -> void:
	var combat := _board()
	var ember := _spawn(combat, &"ember_orc", 7.0)
	_check(combat._immune(ember, &"fire") and combat._immune(ember, &"explosive") and not combat._immune(ember, &"physical"), "Ember Orcs shrug off Fire and explosions")
	combat.build(0, Vector2i(2, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var arrow: Dictionary = combat.towers[0].back()
	var metal := _spawn(combat, &"elemetal_orc", 8.0)
	_check(combat._target(0, arrow, arrow["range"]) == combat.enemies[0].find(ember), "Physical towers skip the EleMetal Orc and pick a target they can hurt")
	_check(not combat._hit(0, arrow, combat.enemies[0].find(metal), 50) and int(metal["hp"]) == 1000, "Physical hits deal nothing to EleMetal")
	combat.build(0, Vector2i(3, 1), &"lightning", MatchCombat.TargetMode.FURTHEST)
	var bolt: Dictionary = combat.towers[0].back()
	combat._hit(0, bolt, combat.enemies[0].find(metal), 10)
	_check(int(metal["hp"]) == 985, "Iron conducts: Lightning deals 50%% more to EleMetal (hp=%d)" % metal["hp"])
	var storm := _spawn(combat, &"storm_orc", 7.4)
	var hits: Dictionary = {int(ember["id"]): true}
	var jump: int = combat._nearest_unhit(0, ember["pos"], hits, 3.0, -1.0, combat._tower_damage_type(bolt))
	_check(jump >= 0 and combat.enemies[0][jump]["id"] != storm["id"], "Chain jumps skip the Storm Orc it cannot hurt")
	var omega := _spawn(combat, &"omega_orc", 6.0)
	combat._hit(0, bolt, combat.enemies[0].find(omega), 10)
	_check(int(omega["hp"]) == 1000, "Omega ignores Lightning")
	combat._hit(0, arrow, combat.enemies[0].find(omega), 10)
	_check(int(omega["hp"]) == 990, "Omega takes pure Physical damage")


func _test_spawns() -> void:
	var rules := _rules()
	rules.sandbox_mode = false
	var seen: Dictionary = {}
	var early: Dictionary = {}
	for seed: int in range(40):
		var combat := MatchCombat.new(rules)
		combat._wave_random.seed = seed
		for group: Dictionary in combat._generate_wave_groups(45):
			seen[group["type_id"]] = int(seen.get(group["type_id"], 0)) + int(group["count"])
		for group: Dictionary in combat._generate_wave_groups(9):
			early[group["type_id"]] = true
	for id: StringName in ELEMENTALS + [&"shaorc"]:
		_check(int(seen.get(String(id), 0)) > 0, "%s appears in regular waves by round 45" % id)
		_check(not early.has(String(id)), "%s waits for its debut" % id)
	_check(not seen.has("greater_shaorc"), "The Greater ShaOrc is a late-game orc")
	var total: int = 0
	var elementals: int = 0
	for id: String in seen:
		total += int(seen[id])
		if StringName(id) in ELEMENTALS:
			elementals += int(seen[id])
	var share: float = float(elementals) / float(total)
	_check(share > 0.1 and share < 0.27, "Elemental Orcs season waves without replacing the horde: %.0f%%" % (share * 100.0))


func _test_shaorc() -> void:
	var combat := _board()
	var shaorc := _spawn(combat, &"shaorc", 5.0)
	var hurt := _spawn(combat, &"grunt", 6.0)
	hurt["hp"] = 100
	shaorc["shield_hits"] = 0
	for step: int in range(5):
		combat.advance(1.0)
	_check(int(hurt["hp"]) == 100 and int(shaorc["shield_hits"]) == 0, "No heal before the cast")
	combat.advance(1.0)
	_check(int(hurt["hp"]) == 250 and int(shaorc["shield_hits"]) == 1 and shaorc["animation"] == "heal", "Raising the staff heals 15%% max HP and restores the shield (hp=%d)" % hurt["hp"])
	var expected: Array[float] = [0.0, 0.2, 0.3, 0.35, 0.375]
	var circle := _board()
	var first := _spawn(circle, &"shaorc", 5.0)
	var definition: Dictionary = circle._enemy_types["shaorc"]
	for neighbours: int in range(5):
		_check(is_equal_approx(circle._shakra_bonus(0, first, definition), expected[neighbours]), "OrcShakra with %d neighbours is +%s%%" % [neighbours, expected[neighbours] * 100.0])
		_spawn(circle, &"shaorc", 5.0 + 0.5 * (neighbours + 1))
	var far := _board()
	var lone := _spawn(far, &"shaorc", 9.0)
	_spawn(far, &"shaorc", 2.0)
	_check(is_zero_approx(far._shakra_bonus(0, lone, definition)), "ShaOrcs more than three tiles apart do not share OrcShakra")
	var trio := _board()
	var caster := _spawn(trio, &"shaorc", 5.0)
	_spawn(trio, &"shaorc", 5.5)
	_spawn(trio, &"shaorc", 6.0)
	var patient := _spawn(trio, &"grunt", 4.5)
	patient["hp"] = 100
	for step: int in range(46):
		trio.advance(0.1)
	_check(int(caster["heal_count"]) == 0, "Even with OrcShakra the cast needs its quickened interval")
	trio.advance(0.1)
	_check(int(caster["heal_count"]) == 1 and int(patient["hp"]) > 100, "Two nearby ShaOrcs (+30%) cast after 6 / 1.3 = 4.62s")


func _test_greater_shaorc() -> void:
	var combat := _board()
	var greater := _spawn(combat, &"greater_shaorc", 5.0)
	var near := _spawn(combat, &"grunt", 7.0)
	var outside := _spawn(combat, &"grunt", 0.5)
	var other := _spawn(combat, &"greater_shaorc", 6.0)
	# Silent second warder: it is only here to prove warders never ward each other.
	other["next_ward"] = 1000.0
	combat.build(0, Vector2i(7, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var arrow: Dictionary = combat.towers[0].back()
	arrow["cooldown"] = 1000.0
	for step: int in range(12):
		combat.advance(1.0)
	_check(int(greater["ward_count"]) == 1 and greater["animation"] == "heal", "The Greater ShaOrc raises its staff after 12s")
	_check(bool(near["warded"]) and not bool(outside["warded"]) and not bool(greater["warded"]) and not bool(other["warded"]), "Only other non-warding orcs within 3.5 tiles are warded")
	var index: int = combat.enemies[0].find(near)
	_check(not combat._hit(0, arrow, index, 500) and int(near["hp"]) == 1000, "Warded orcs are immune to all damage")
	_check(combat._target(0, arrow, 10.0) != index, "Towers ignore warded orcs")
	_check(combat.snapshot()["enemies"][0][index]["warded"], "Wards reach the board snapshot")
	combat._hit(0, arrow, combat.enemies[0].find(greater), 100000)
	combat.advance(0.01)
	_check(combat.enemies[0].find(greater) < 0 and not bool(near["warded"]) and float(near["ward_until"]) == 0.0, "Killing the Greater ShaOrc ends its wards at once")
	_check(combat._hit(0, arrow, combat.enemies[0].find(near), 5) and int(near["hp"]) == 995, "The unwarded orc takes damage again")
	var timed := _board()
	var caster := _spawn(timed, &"greater_shaorc", 5.0)
	var ally := _spawn(timed, &"runner", 6.0)
	for step: int in range(12):
		timed.advance(1.0)
	_check(bool(ally["warded"]), "The ward is up")
	for step: int in range(10):
		timed.advance(1.0)
	_check(not bool(ally["warded"]) and int(caster["ward_count"]) == 1, "The ward fades after 10s")
	timed.advance(2.0)
	_check(bool(ally["warded"]) and int(caster["ward_count"]) == 2, "It wards again every 12s")
