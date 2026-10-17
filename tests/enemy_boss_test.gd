extends SceneTree

const BOSS := &"necorcmancer_mancer"

var failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rng(seed_value: int = 71) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func _routes(length: int = 100) -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(length + 1):
		route.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < length else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _sandbox(roster: Array[String], length: int = 100) -> MatchCombat:
	var rules := _boss_rules()
	rules.sandbox_mode = true
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.1
	var combat := MatchCombat.new(rules, null, _rng())
	_check(combat.sandbox_start(_routes(length), 1, roster), "Sandbox admits exact boss lifecycle fixture")
	combat.advance(0.001)
	return combat


func _init() -> void:
	_test_boss_rosters()
	_test_chance_boundaries()
	_test_boss_send_atomicity()
	_test_live_ramp_and_cast()
	_test_summon_graph()
	_test_boss_death_and_leak()
	if failures == 0:
		print("PASS: reserved boss encounters, configurable chance ramp, atomic unsendability and live HP/cast/death/leak state")
	quit(1 if failures > 0 else 0)


func _boss_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.starting_coins = 10000
	rules.base_health = 10000
	rules.enemy_speed = 0.05
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	return rules


func _definition(rules: CombatRules, type_id: StringName) -> EnemyDefinition:
	for enemy: EnemyDefinition in rules.catalog.enemies:
		if enemy.id == type_id:
			return enemy
	_check(false, "Expected registered enemy identity: " + String(type_id))
	return null


func _wave(rules: CombatRules, round_number: int, seed_value: int) -> MatchCombat:
	var combat := MatchCombat.new(rules, null, _rng(seed_value))
	_check(combat.debug_set_round(round_number), "Host admits requested test round")
	_check(combat.start_wave(_routes(1000)), "Real roster generation starts requested round")
	return combat


func _boss_count(combat: MatchCombat) -> int:
	return combat.wave_roster.count(String(BOSS))


func _test_boss_rosters() -> void:
	var rules := _boss_rules()
	for seed_value: int in range(64):
		for round_number: int in [1, 34, 39, 40]:
			var combat := _wave(rules, round_number, seed_value)
			_check(_boss_count(combat) == (1 if round_number == 40 else 0), "Boss is absent before debut and guaranteed exactly once on debut for every seed")
			var consumed: int = 0
			var counts: Dictionary = {}
			var types: Dictionary = combat.snapshot()["enemy_types"]
			var budget: int = rules.wave_weight + (round_number - 1) * rules.wave_weight_growth
			for group: Dictionary in combat.wave_groups:
				var type_id: String = group["type_id"]
				consumed += int(types[type_id]["spawn_weight"])
				counts[type_id] = int(counts.get(type_id, 0)) + 1
			_check(consumed == budget, "Boss reservation leaves an exactly filled ordinary group-weight budget")
			for type_id: String in counts:
				var definition: Dictionary = types[type_id]
				var cap: int = combat._enemy_count_cap(definition, round_number)
				_check(cap == 0 or counts[type_id] <= cap, "Reserved and ordinary groups obey hard counts")
				_check(counts[type_id] * int(definition["spawn_weight"]) <= floori(budget * float(definition["max_weight_share"])), "Reserved and ordinary groups obey weight shares")
	var encounters: Array[int] = [0, 0, 0]
	for seed_value: int in range(512):
		for index: int in range(3):
			var combat := _wave(rules, [41, 61, 101][index], seed_value)
			var count: int = _boss_count(combat)
			_check(count <= 1, "Later waves never repeatedly choose a boss")
			encounters[index] += count
	_check(encounters[0] > 0 and encounters[0] < encounters[1] and encounters[1] < encounters[2] and encounters[2] < 512, "Seeded real encounters become more frequent but remain occasional")


func _test_chance_boundaries() -> void:
	for profile: Array in [[0.0, 0.0, 1.0, 41, 0], [1.0, 0.0, 1.0, 41, 1], [0.0, 1.0, 1.0, 41, 0], [0.0, 1.0, 1.0, 42, 1], [0.0, 1.0, 0.0, 100, 0]]:
		var rules := _boss_rules()
		var boss := _definition(rules, BOSS).duplicate() as EnemyDefinition
		boss.boss_spawn_chance = profile[0]
		boss.boss_spawn_chance_growth = profile[1]
		boss.boss_spawn_chance_cap = profile[2]
		var definitions: Array[EnemyDefinition] = []
		for source: EnemyDefinition in rules.catalog.enemies:
			definitions.append(boss if source.id == BOSS else source)
		rules.catalog = rules.catalog.duplicate()
		rules.catalog.enemies = definitions
		for seed_value: int in range(16):
			_check(_boss_count(_wave(rules, profile[3], seed_value)) == profile[4], "Configured zero/one, first-post-debut growth offset and cap boundaries control actual encounters")
		_check(_boss_count(_wave(rules, 40, 1)) == 1, "Chance settings never cancel the guaranteed debut")
	# Reservation still obeys feasibility, even on the guaranteed encounter.
	for budget: int in [39, 79, 80]:
		var rules := _boss_rules()
		rules.wave_weight = budget
		rules.wave_weight_growth = 0
		_check(_boss_count(_wave(rules, 40, 2)) == (1 if budget == 80 else 0), "Boss cannot bypass remaining weight or its half-budget share")


func _test_boss_send_atomicity() -> void:
	for round_number: int in [1, 39, 40, 46, 100, 1000]:
		var combat := MatchCombat.new(_boss_rules(), null, _rng())
		combat.debug_set_round(round_number)
		for active: bool in [false, true]:
			if active:
				combat.start_wave(_routes(1000))
			var frozen: Dictionary = combat.snapshot()
			var wave_state: int = combat._wave_random.state
			var group_state: int = combat._group_random.state
			_check(not combat.send_enemy(0, BOSS) and not combat.send_enemy(1, BOSS) and not combat.send_enemy_mirrored(0, BOSS), "Boss sends always reject in planning and combat")
			_check(combat.snapshot() == frozen and combat._wave_random.state == wave_state and combat._group_random.state == group_state, "Rejected boss sends preserve balances, income, queues, totals and both gameplay RNG streams")


func _test_live_ramp_and_cast() -> void:
	var rules := _boss_rules()
	for round_number: int in [1, 40, 46, 100]:
		var combat := MatchCombat.new(rules, null, _rng())
		combat.debug_set_round(round_number)
		var baseline: int = rules.enemy_health + round_number - 1
		var preview: Dictionary = combat.snapshot()["enemy_types"]
		_check(preview["grunt"]["health"] == ceili(baseline * _definition(rules, &"grunt").health_multiplier), "Accepted planning preview uses one HP per completed round")
		if round_number >= 46:
			_check(combat.send_enemy(0, &"necorcmancer"), "Ordinary NecOrcmancer remains sendable at its unlock")
		combat.start_wave(_routes(1000))
		combat.advance(0.001)
		for slot: int in range(2):
			for enemy: Dictionary in combat.enemies[slot]:
				var definition := _definition(rules, StringName(enemy["type_id"]))
				var expected: int = ceili(baseline * definition.health_multiplier)
				_check(enemy["max_hp"] == expected and enemy["max_hp"] == preview[enemy["type_id"]]["health"] and MatchCombat.enemy_preview(definition, rules, round_number)["max_hp"] == expected, "Regular and paid live HP agree with accepted and guide previews at the new linear slope")
	# A focused extension of the existing NecOrcmancer mechanics fixture.
	rules.sandbox_mode = true
	var combat := MatchCombat.new(rules, null, _rng())
	_check(combat.sandbox_start(_routes(1000), 40, [String(BOSS), "necorcmancer"]), "Both independent caster identities remain available")
	combat.advance(0.001)
	var boss: Dictionary = combat.enemies[0][0]
	var ordinary: Dictionary = combat.enemies[0][1]
	_check(boss["max_hp"] > ordinary["max_hp"] and boss["speed"] < ordinary["speed"], "Live boss is tougher and slower than original NecOrcmancer")
	combat.advance(6.999)
	_check(boss["animation"] == "cast" and boss["speed"] == 0.0, "New boss performs a stationary summoning ritual")
	var progress: float = boss["progress"]
	combat.advance(1.15)
	var children: int = 0
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == boss["id"]:
			children += 1
			_check(child["type_id"] == "necorcmancer" and child["route"] == boss["route"] and is_equal_approx(child["progress"], progress), "Boss summons NecOrcmancers on its captured route and cast position")
			var expected: int = ceili((rules.enemy_health + 39) * _definition(rules, &"necorcmancer").health_multiplier)
			_check(child["max_hp"] == expected and child["max_hp"] == MatchCombat.enemy_preview(_definition(rules, &"necorcmancer"), rules, 40)["max_hp"], "Summoned NecOrcmancer HP uses the same new slope and guide preview")
			_check(child["age"] == 0.0 and child["summon_count"] == 0, "New NecOrcmancers cannot cascade a ritual on their birth tick")
	_check(children in [2, 3, 4] and boss["summon_count"] == 1, "Boss resolves one bounded inherited ritual")
	var child_ids: Array[int] = []
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == boss["id"]:
			child_ids.append(child["id"])
	combat.advance(8.15)
	for child_id: int in child_ids:
		var grandchildren: int = 0
		for enemy: Dictionary in combat.enemies[0]:
			if enemy["summoner_id"] == child_id:
				grandchildren += 1
				_check(enemy["type_id"] == "skeleorc" and enemy["max_hp"] == ceili((rules.enemy_health + 39) * _definition(rules, &"skeleorc").health_multiplier), "Boss-raised NecOrcmancers retain real wave-scaled SkeleOrc rituals")
		_check(grandchildren in [2, 3, 4], "Each boss-raised NecOrcmancer independently resolves its ordinary bounded ritual")
	var direct_children: int = 0
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == boss["id"]:
			direct_children += 1
	_check(direct_children <= 6, "Grandchildren do not bypass the boss's direct-child cap")


func _test_summon_graph() -> void:
	var rules := _boss_rules()
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		definitions.append(source.duplicate() as EnemyDefinition)
	rules.catalog.enemies = definitions
	_check(rules.catalog.validation_errors().is_empty(), "The boss-to-NecOrcmancer-to-SkeleOrc chain is admitted")
	var ordinary: EnemyDefinition = _definition(rules, &"necorcmancer")
	ordinary.summon_type = BOSS
	_check(not rules.catalog.validation_errors().is_empty(), "A two-type summon cycle is rejected before simulation")
	ordinary.summon_type = &"skeleorc"
	var boss: EnemyDefinition = _definition(rules, BOSS)
	boss.summon_type = BOSS
	_check(not rules.catalog.validation_errors().is_empty(), "A self-summoning boss is rejected before simulation")


func _test_boss_death_and_leak() -> void:
	var combat: MatchCombat = _sandbox([String(BOSS)])
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	combat.advance(6.999)
	combat._hit(0, combat.towers[0][0], 0, 1000000)
	combat.advance(1.15)
	_check(combat.enemies[0].is_empty() and combat.snapshot()["enemy_totals"][0]["kills"].get(String(BOSS), 0) == 1, "Killed boss cancels its pending ritual and records its own identity once")
	combat = _wave(_boss_rules(), 40, 71)
	combat.advance(0.001)
	var boss: Dictionary = combat.enemies[0][0]
	var health: int = combat.base_health[0]
	boss["progress"] = float(boss["route"].size() - 1) - 0.001
	combat.advance(1.0)
	_check(not combat.enemies[0].has(boss) and combat.base_health[0] == health - int(boss["damage"]), "Boss leaks its captured heavy base damage without summoning")
