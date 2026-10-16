extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_progression_and_atomic_groups()
	_test_regular_group_budget_and_pacing()
	_test_circular_heal()
	_test_summon_lifecycle()
	_test_cast_death_and_portal()
	_test_cast_slow_and_exposure()
	_test_coarse_and_playback_clock()
	_test_sandbox_capture_and_statistics()
	_test_metadata_validation()
	if failures == 0:
		print("PASS: staged enemy progression, atomic groups, circular healing, captured-route summons, cast exposure, sandbox gates and accepted totals")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rules(sandbox: bool = false) -> CombatRules:
	var rules := CombatRules.new()
	rules.sandbox_mode = sandbox
	rules.starting_coins = 1000
	rules.base_health = 1000
	rules.enemy_health = 100
	rules.enemy_speed = 0.1
	rules.health_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight_growth = 0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	return rules


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
	var combat := MatchCombat.new(_rules(true), null, _rng())
	_check(combat.sandbox_start(_routes(length), 1, roster), "Sandbox admits exact authored test roster")
	combat.advance(0.001)
	return combat


func _test_progression_and_atomic_groups() -> void:
	var rules := _rules()
	var combat := MatchCombat.new(rules, null, _rng())
	var frozen: Dictionary = combat.snapshot()
	var random_state: int = combat._group_random.state
	for type_id: StringName in [&"grunt", &"runner", &"brute", &"orc_chief", &"necorcmancer", &"skeleorc"]:
		_check(not combat.send_enemy(0, type_id), "Locked or summon-only purchases reject at round one")
	_check(combat.snapshot() == frozen and combat._group_random.state == random_state, "Rejected sends spend no money, reserve no enemies and consume no random choices")
	var wave_state: int = combat._wave_random.state
	_check(combat.send_enemy(0, &"orcling"), "Orcling is the initial purchasable enemy")
	var count: int = combat.queued_sends[1]
	_check(count >= 2 and count <= 4 and combat.coins == [988, 1000] and combat.income == [1, 0], "One atomic group pays its price and income exactly once")
	_check(combat.snapshot()["enemy_totals"][0]["sent"]["orcling"] == count and combat._wave_random.state == wave_state, "Accepted individual send totals count the group without perturbing regular RNG")
	combat.coins[0] = 11
	frozen = combat.snapshot()
	random_state = combat._group_random.state
	_check(not combat.send_enemy(0, &"orcling") and combat.snapshot() == frozen and combat._group_random.state == random_state, "Unaffordable groups cannot roll or grant free members")
	for entry: Array in [["grunt", 6], ["runner", 12], ["brute", 22], ["orc_chief", 34], ["necorcmancer", 46]]:
		combat = MatchCombat.new(rules, null, _rng())
		combat.debug_set_round(int(entry[1]) - 1)
		_check(not combat.snapshot()["enemy_types"][entry[0]]["send_available"] and not combat.send_enemy(0, StringName(entry[0])), "Send gate rejects immediately before its own unlock")
		combat.debug_set_round(int(entry[1]))
		_check(combat.snapshot()["enemy_types"][entry[0]]["send_available"] and combat.send_enemy(0, StringName(entry[0])), "Planning preview and host validator admit the intended unlock round")
	combat = MatchCombat.new(rules, null, _rng())
	combat.send_enemy(0, &"orcling")
	count = combat.queued_sends[1]
	combat.send_enemy(0, &"orcling")
	combat.start_wave(_routes())
	_check(combat.queued_sends[1] >= count, "Wave start releases only one group member, not the whole FIFO")
	combat.advance((count - 1) * 0.065 + 0.000001)
	var pending: int = combat.queued_sends[1]
	combat.advance(rules.send_spawn_interval - 0.00001)
	_check(combat.queued_sends[1] == pending, "The group tail retains full ordinary cooldown before the next order")
	combat.advance(0.00002)
	_check(combat.queued_sends[1] == pending - 1, "Next group begins at ordinary cooldown after the preceding last member")


func _test_regular_group_budget_and_pacing() -> void:
	var rules := _rules()
	rules.wave_weight = 20
	var saw_group: bool = false
	for seed_value: int in range(12):
		var combat := MatchCombat.new(rules, null, _rng(seed_value))
		combat.start_wave(_routes())
		var budget: int = 0
		var flattened: Array[String] = []
		var offset: int = 0
		for group: Dictionary in combat.wave_groups:
			var definition: Dictionary = combat.snapshot()["enemy_types"][group["type_id"]]
			budget += int(definition["spawn_weight"])
			for member: int in range(int(group["count"])):
				flattened.append(group["type_id"])
				if member > 0:
					_check(is_equal_approx(combat.spawn_times[offset + member] - combat.spawn_times[offset + member - 1], 0.065), "Grouped members use short spacing rather than full portal cooldown")
			if group["type_id"] == "orcling":
				saw_group = true
				_check(int(group["count"]) in [2, 3, 4], "Shipped Orclings never spawn alone or in oversized groups")
			if offset + int(group["count"]) < combat.spawn_times.size():
				_check(is_equal_approx(combat.spawn_times[offset + int(group["count"])] - combat.spawn_times[offset + int(group["count"]) - 1], rules.spawn_interval), "Regular event cooldown begins after the last group member")
			offset += int(group["count"])
		_check(budget == rules.wave_weight and flattened == combat.wave_roster, "Group weight is charged once and flattened roster preserves accepted order")
		combat.advance(combat.spawn_times.back() + 0.01)
		_check(combat.enemies[0].size() == combat.enemies[1].size(), "Both boards receive every accepted regular member")
		for index: int in range(combat.enemies[0].size()):
			_check(combat.enemies[0][index]["type_id"] == combat.enemies[1][index]["type_id"] and is_equal_approx(combat.enemies[0][index]["age"], combat.enemies[1][index]["age"]), "Boards share accepted grouping and birth timetable, not independent random rolls")
	_check(saw_group, "Seeded regular rosters exercise Orcling groups")
	var encountered: Dictionary = {}
	var progression := _rules()
	progression.wave_weight = 200
	for wave_number: int in [1, 6, 12, 22, 34, 46]:
		for seed_value: int in range(8):
			var combat := MatchCombat.new(progression, null, _rng(seed_value))
			combat.debug_set_round(wave_number)
			combat.start_wave(_routes())
			var consumed: int = 0
			var counts: Dictionary = {}
			for group: Dictionary in combat.wave_groups:
				var type_id: String = group["type_id"]
				var definition: Dictionary = combat.snapshot()["enemy_types"][type_id]
				encountered[type_id] = true
				consumed += int(definition["spawn_weight"])
				counts[type_id] = int(counts.get(type_id, 0)) + 1
				_check(definition["regular_spawn_enabled"] and wave_number >= int(definition["first_wave"]), "Regular generation obeys staged encounters and excludes summoned-only enemies")
			_check(consumed == 200, "Every staged roster fills the exact group budget")
			for type_id: String in counts:
				var definition: Dictionary = combat.snapshot()["enemy_types"][type_id]
				var cap: int = combat._enemy_count_cap(definition, wave_number)
				_check(cap == 0 or int(counts[type_id]) <= cap, "Leaders obey unlock-relative growing hard caps")
				_check(int(counts[type_id]) * int(definition["spawn_weight"]) <= floori(200.0 * float(definition["max_weight_share"])), "Group counts obey their total weight-share ceiling")
	for type_id: String in ["orcling", "grunt", "runner", "brute", "orc_chief", "necorcmancer"]:
		_check(encountered.has(type_id), "Staged host generator actually includes each regular role")


func _test_circular_heal() -> void:
	var combat: MatchCombat = _sandbox(["orc_chief"])
	combat.sandbox_spawn(0, &"grunt", 3)
	var chief: Dictionary = combat.enemies[0][0]
	chief["hp"] = 200
	chief["next_heal"] = chief["age"] + 0.01
	var nearby: Dictionary = combat.enemies[0][1]
	var diagonal: Dictionary = combat.enemies[0][2]
	var capped: Dictionary = combat.enemies[0][3]
	nearby["hp"] = 40
	diagonal["hp"] = 40
	capped["hp"] = 99
	# This point rounds into a neighboring square, but lies outside the true circle.
	diagonal["route"] = [Vector2i(1, 1), Vector2i(2, 1)]
	diagonal["progress"] = 0.3
	diagonal["pos"] = Vector2(1.3, 1)
	combat.advance(0.009)
	_check(nearby["hp"] == 40, "Healing does not occur before the simulation deadline")
	combat.advance(0.001)
	_check(nearby["hp"] == 44 and diagonal["hp"] == 40 and capped["hp"] == 100 and chief["hp"] == 200, "Heal is circular, other-allies-only, max-HP based and capped without self healing")
	_check(chief["heal_count"] == 1 and chief["animation"] == "heal", "Accepted healing emits one simulation animation/counter")


func _test_summon_lifecycle() -> void:
	var combat: MatchCombat = _sandbox(["necorcmancer"])
	var caster: Dictionary = combat.enemies[0][0]
	combat.advance(6.999)
	_check(caster["animation"] == "cast" and caster["cast_remaining"] > 1.14 and caster["speed"] == 0.0, "Seven-second deadline begins a stationary staff cast")
	var progress: float = caster["progress"]
	combat.advance(1.15)
	_check(is_equal_approx(caster["progress"], progress) and caster["summon_count"] == 1 and caster["animation"] == "walk", "Caster stays stationary for the complete ritual and resolves once")
	_check(combat.enemies[0].size() in [3, 4, 5], "Host ritual raises two to four children")
	var ids: Dictionary = {}
	for child: Dictionary in combat.enemies[0]:
		_check(not ids.has(child["id"]), "Summons have stable distinct authoritative IDs")
		ids[child["id"]] = true
		if child["id"] == caster["id"]:
			continue
		_check(child["type_id"] == "skeleorc" and child["summoner_id"] == caster["id"] and child["route"] == caster["route"] and is_equal_approx(child["progress"], progress), "Children inherit the remaining captured caster route and exact position, never the portal")
		_check(child["age"] == 0.0 and child["summon_count"] == 0, "New summons start with zero exposure and cannot recursively cast")
	combat.advance(22.0)
	var living: int = 0
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == caster["id"]:
			living += 1
	_check(living == 6, "Repeated host casts cannot exceed six living children per caster")
	combat._retire_enemy(caster["id"])
	combat.enemies[0].erase(caster)
	combat.advance(0.1)
	_check(combat.phase == MatchCombat.Phase.WAVE, "Living children hold clearance open after their caster dies")


func _test_cast_death_and_portal() -> void:
	var combat: MatchCombat = _sandbox(["necorcmancer"])
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	var caster: Dictionary = combat.enemies[0][0]
	combat.advance(6.999)
	combat._hit(0, combat.towers[0][0], 0, 100000)
	combat.advance(1.15)
	_check(combat.enemies[0].is_empty() and combat.snapshot()["enemy_totals"][0]["kills"].get("necorcmancer", 0) == 1, "Killed casting enemy cannot heal, summon late, or grant repeated death counts")
	combat = _sandbox(["necorcmancer"], 1)
	caster = combat.enemies[0][0]
	caster["progress"] = 0.99
	caster["next_summon"] = caster["age"] + 1.0
	combat.advance(1.0)
	_check(combat.enemies[0].is_empty() and caster["summon_count"] == 0, "A caster reaching the base cannot begin a ritual or spawn portal children")


func _test_cast_slow_and_exposure() -> void:
	var combat: MatchCombat = _sandbox(["necorcmancer"])
	var caster: Dictionary = combat.enemies[0][0]
	caster["next_summon"] = caster["age"] + 0.01
	combat.advance(0.01)
	caster["slow_remaining"] = 0.3
	caster["slowed"] = true
	var progress: float = caster["progress"]
	combat.advance(0.5)
	_check(caster["progress"] == progress and not caster["slowed"] and caster["speed"] == 0.0, "Slow expires in simulation time while cast remains truly stationary")
	combat.build(0, Vector2i(0, 1), &"rune_obelisk", 0)
	var tower: Dictionary = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "damage")
	combat.upgrade_tower(0, tower["id"], "speed")
	combat.upgrade_tower(0, tower["id"], "boulders")
	var hp: int = caster["hp"]
	combat.advance(0.65)
	_check(int(caster["hp"]) < hp, "Stationary casts retain full continuous damage exposure")
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == caster["id"]:
			_check(child["hp"] == child["max_hp"] and child["age"] == 0.0, "Ritual-boundary newborns never receive pre-birth continuous damage")
	_check(caster["speed"] == caster["base_speed"], "Cast completion restores unslowed speed rather than global playback-scaled speed")


func _test_coarse_and_playback_clock() -> void:
	var coarse: MatchCombat = _sandbox(["necorcmancer"])
	var fast: MatchCombat = _sandbox(["necorcmancer"])
	var fine: MatchCombat = _sandbox(["necorcmancer"])
	coarse.advance(16.3)
	# Two half-duration real-time ticks at 2x feed the same simulation duration.
	fast.advance(4.075 * 2.0)
	fast.advance(4.075 * 2.0)
	for tick: int in range(326):
		fine.advance(0.05)
	_check(coarse.enemies[0].size() == fine.enemies[0].size() and fast.enemies[0].size() == fine.enemies[0].size(), "Coarse, fine and doubled playback clocks raise identical host child counts")
	for index: int in range(coarse.enemies[0].size()):
		var expected: Dictionary = coarse.enemies[0][index]
		for actual: Dictionary in [fast.enemies[0][index], fine.enemies[0][index]]:
			_check(actual["type_id"] == expected["type_id"] and actual["animation"] == expected["animation"] and actual["summon_count"] == expected["summon_count"], "Playback speed does not create independent ability events")
			_check(is_equal_approx(actual["progress"], expected["progress"]) and is_equal_approx(actual["age"], expected["age"]), "Event boundaries preserve scheduled birth, stationary cast and movement at every tick size")


func _test_sandbox_capture_and_statistics() -> void:
	var rules := _rules()
	rules.starting_coins = 0
	var combat := MatchCombat.new(rules)
	rules.sandbox_mode = true
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.sandbox_start(_routes(), 1, []) and not combat.sandbox_spawn(0, &"skeleorc", 1) and not combat.build(0, Vector2i.ZERO, &"arrow_tower", 0) and combat.snapshot() == frozen, "Mutating source sandbox flag cannot bypass an admitted real match")
	rules = _rules(true)
	rules.starting_coins = 0
	combat = MatchCombat.new(rules)
	rules.sandbox_mode = false
	_check(combat.build(0, Vector2i(0, 1), &"arrow_tower", 0) and combat.upgrade_tower(0, 1, "damage") and combat.coins == [0, 0], "Sandbox purchases/upgrades are free without fake finite money")
	combat.sell_tower(0, 1)
	_check(combat.coins == [0, 0], "Free purchases cannot fabricate sale proceeds")
	var id: String = combat.statistics_id
	_check(combat.sandbox_start(_routes(1), 1, []) and combat.sandbox_spawn(0, &"skeleorc", 2), "Sandbox directly spawns exact summon-only units")
	combat.advance(20.0)
	_check(combat.base_health == [1000, 1000] and combat.phase != MatchCombat.Phase.FINISHED and combat.enemy_totals[0]["kills"].is_empty(), "Sandbox leaks are invincible and never counted as kills")
	combat.debug_set_round(46)
	_check(combat.statistics_id == id and MatchCombat.new(_rules()).statistics_id != id and combat.snapshot()["rules"]["sandbox_mode"], "Snapshot identity lasts for model lifetime, differs per match and captures sandbox exclusion")
	combat.sandbox_start(_routes(), 1, [])
	combat.sandbox_spawn(0, &"skeleorc", 1)
	combat.build(0, Vector2i(0, 1), &"arrow_tower", 0)
	var before: int = combat.coins[0]
	combat._hit(0, combat.towers[0][0], 0, 100000)
	_check(combat.coins[0] == before and combat.enemy_totals[0]["kills"].get("skeleorc", 0) == 1, "Summoned units grant no farmable money but actual kills still enter per-type totals")
	var totals_copy: Dictionary = combat.snapshot()
	totals_copy["enemy_totals"][0]["kills"]["skeleorc"] = 999
	combat.debug_set_round(2)
	_check(combat.enemy_totals[0]["kills"]["skeleorc"] == 1 and combat.statistics_id == id, "Snapshot consumers and round abandonment cannot rewrite or reset accepted lifetime totals")


func _test_metadata_validation() -> void:
	var rules := _rules()
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		definitions.append(source.duplicate() as EnemyDefinition)
	rules.catalog.enemies = definitions
	var enemy: EnemyDefinition = definitions[0]
	enemy.group_weights = PackedInt32Array([0, 0])
	_check(not rules.catalog.validation_errors().is_empty(), "Empty probability mass is rejected before admission")
	enemy.group_weights = PackedInt32Array([1])
	enemy.heal_interval = 5.0
	enemy.heal_radius = NAN
	_check(not rules.catalog.validation_errors().is_empty(), "Nonfinite ability stats are rejected")
	enemy.heal_interval = 0.0
	enemy.heal_radius = 0.0
	for candidate: EnemyDefinition in definitions:
		if candidate.id == &"necorcmancer":
			candidate.summon_type = &"missing_child"
	_check(not rules.catalog.validation_errors().is_empty(), "Summon references must resolve at admission")
