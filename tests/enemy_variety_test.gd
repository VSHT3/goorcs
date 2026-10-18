extends SceneTree

const IDS: Array[StringName] = [&"scrapguard", &"crate_orc", &"rage_orc", &"moss_orc"]

var failures: int = 0


func _init() -> void:
	_test_authored_registration_and_gates()
	_test_validation_graph_and_modifiers()
	_test_capture_and_generic_transitions()
	_test_physical_resistance()
	_test_crate_death_and_leak()
	_test_rage_damage_and_healing()
	_test_moss_deadlines_and_partitioning()
	_test_authored_frame_selection()
	if failures == 0:
		print("PASS: progressive enemy registration, combined child graph, physical resistance, real death children, permanent rage, timed self-regeneration and authored frame selection")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rules(sandbox: bool = true) -> CombatRules:
	var rules := CombatRules.new()
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		definitions.append(source.duplicate() as EnemyDefinition)
	rules.catalog.enemies = definitions
	rules.sandbox_mode = sandbox
	rules.starting_coins = 10000
	rules.base_health = 10000
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.1
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 200
	rules.wave_weight_growth = 0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	return rules


func _rng() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = 471
	return random


func _definition(rules: CombatRules, id: StringName) -> EnemyDefinition:
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.id == id:
			return definition
	_check(false, "Registered enemy exists: " + String(id))
	return null


func _routes(length: int = 100) -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(length + 1):
		route.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < length else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _sandbox(roster: Array[String], rules: CombatRules = null, length: int = 100) -> MatchCombat:
	var combat := MatchCombat.new(_rules() if rules == null else rules, null, _rng())
	_check(combat.sandbox_start(_routes(length), 1, roster), "Exact variety roster starts through actual Sandbox API")
	combat.advance(0.001)
	return combat


func _tower(combat: MatchCombat) -> Dictionary:
	_check(combat.build(0, Vector2i(0, 2), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Real tower creates damage-accounting fixture")
	return combat.towers[0][0]


func _enemy(combat: MatchCombat, id: String) -> Dictionary:
	for enemy: Dictionary in combat.enemies[0]:
		if enemy["type_id"] == id:
			return enemy
	_check(false, "Living expected identity: " + id)
	return {}


func _test_authored_registration_and_gates() -> void:
	var rules := _rules(false)
	_check(rules.catalog.validation_errors().is_empty(), "Shipped full catalog, including nested NecOrcmancers, validates")
	var rounds: Array[int] = [9, 18, 28, 52]
	var sends: Array[int] = [16, 28, 40, 66]
	for index: int in range(IDS.size()):
		var definition: EnemyDefinition = _definition(rules, IDS[index])
		_check(definition.regular_spawn_enabled and definition.send_enabled and not definition.boss and definition.first_wave == rounds[index] and definition.send_first_wave == sends[index], "New regular identities are registered with independent wave/send gates")
		var combat := MatchCombat.new(rules, null, _rng())
		combat.debug_set_round(sends[index] - 1)
		var before: Dictionary = combat.snapshot()
		var random_state: int = combat._group_random.state
		_check(not combat.send_enemy(0, IDS[index]) and combat.snapshot() == before and combat._group_random.state == random_state, "Locked send is atomic and consumes no group randomness")
		combat.debug_set_round(sends[index])
		_check(combat.send_enemy(0, IDS[index]) and combat.queued_sends[1] == 1 and combat.income[0] == definition.send_income, "Unlock accepts exactly one authored individual, price and income")
		var types: Dictionary = combat.snapshot()["enemy_types"]
		_check(types[String(IDS[index])]["send_available"], "Host availability includes newly unlocked enemy")
		if definition.max_per_wave > 0:
			_check(combat._enemy_count_cap(types[String(IDS[index])], definition.first_wave + definition.count_cap_growth_interval - 1) == definition.max_per_wave and combat._enemy_count_cap(types[String(IDS[index])], definition.first_wave + definition.count_cap_growth_interval) == definition.max_per_wave + definition.count_cap_growth, "Finite regular caps grow relative to their debut")
		var sandbox := _sandbox([String(IDS[index])])
		_check(sandbox.sandbox_spawn(0, IDS[index], 2) and sandbox.enemies[0].size() == 3, "Sandbox exact selection includes each new identity without progression gates")
		var encountered: bool = false
		for seed_value: int in range(12):
			var random := RandomNumberGenerator.new()
			random.seed = seed_value
			var wave := MatchCombat.new(rules, null, random)
			wave.debug_set_round(rounds[index] - 1)
			wave.start_wave(_routes())
			_check(String(IDS[index]) not in wave.wave_roster, "Real weighted wave excludes new enemy immediately before debut")
			wave = MatchCombat.new(rules, null, random)
			wave.debug_set_round(rounds[index])
			wave.start_wave(_routes())
			encountered = encountered or String(IDS[index]) in wave.wave_roster
			var count: int = wave.wave_roster.count(String(IDS[index]))
			_check((definition.max_per_wave == 0 or count <= definition.max_per_wave) and count * definition.spawn_weight <= floori(rules.wave_weight * definition.max_weight_share), "Actual debut roster obeys authored hard counts and weight shares")
		_check(encountered, "Seeded real weighted waves actually introduce each registered enemy")


func _test_validation_graph_and_modifiers() -> void:
	for change: Array in [["physical_damage_multiplier", 0.0], ["physical_damage_multiplier", INF], ["enrage_health_fraction", NAN], ["enrage_health_fraction", 1.1], ["enrage_health_fraction", 0.5], ["enrage_speed_multiplier", 2.0], ["enrage_speed_multiplier", 0.9], ["regeneration_interval", -1.0], ["regeneration_interval", INF], ["regeneration_interval", 1.0], ["regeneration_fraction", 0.1], ["regeneration_fraction", 1.1], ["death_spawn_count", -1], ["death_spawn_count", 1]]:
		var catalog := ContentCatalog.new()
		var enemy := EnemyDefinition.new()
		enemy.id = &"invalid"
		enemy.title = "Invalid"
		enemy.set(change[0], change[1])
		catalog.enemies = [enemy]
		_check(not catalog.validation_errors().is_empty(), "Invalid modifier, unpaired timing or count is rejected: " + str(change))
	var rules := _rules()
	var crate: EnemyDefinition = _definition(rules, &"crate_orc")
	crate.death_spawn_type = &"missing"
	_check(not rules.catalog.validation_errors().is_empty(), "Unregistered death children reject admission")
	crate.death_spawn_type = &"necorcmancer_mancer"
	_check(not rules.catalog.validation_errors().is_empty(), "Bosses cannot be children even through death-spawn fields")
	crate.death_spawn_type = &"necorcmancer"
	var skeleton: EnemyDefinition = _definition(rules, &"skeleorc")
	skeleton.death_spawn_type = &"crate_orc"
	skeleton.death_spawn_count = 1
	_check(not rules.catalog.validation_errors().is_empty(), "Mixed death/summon cycle is rejected across three resources")
	skeleton.death_spawn_type = &""
	skeleton.death_spawn_count = 0
	_check(rules.catalog.validation_errors().is_empty(), "Acyclic death-to-NecOrcmancer-to-SkeleOrc and boss-to-NecOrcmancer remain legal")
	var rage: EnemyDefinition = _definition(rules, &"rage_orc")
	rage.animation_frames = rage.animation_frames.duplicate() as SpriteFrames
	rage.animation_frames.remove_animation(&"walk_enraged")
	_check(not rules.catalog.validation_errors().is_empty(), "Enabled enrage requires a playable authored state animation")


func _test_capture_and_generic_transitions() -> void:
	var definition := EnemyDefinition.new()
	definition.physical_damage_multiplier = 0.7
	definition.enrage_health_fraction = 0.5
	definition.enrage_speed_multiplier = 2.0
	definition.regeneration_interval = 3.0
	definition.regeneration_fraction = 0.1
	var captured: Dictionary = EnemyMechanics.capture(definition)
	definition.enrage_speed_multiplier = 9.0
	var enemy: Dictionary = {"hp": 50, "max_hp": 100, "base_speed": 2.0, "speed": 2.0, "age": 0.0, "slowed": true, "cast_remaining": 1.0, "tower_attack_remaining": 0.0, "locomotion": "path", "animation": "cast", "animation_elapsed": 0.2}
	EnemyMechanics.initialize(enemy, captured)
	EnemyMechanics.after_damage(enemy, captured)
	_check(enemy["enraged"] and enemy["base_speed"] == 4.0 and enemy["speed"] == 0.0, "Generic non-ID rage uses captured multiplier and preserves active cast")
	enemy["cast_remaining"] = 0.0
	BossMechanics.prepare(enemy)
	_check(is_equal_approx(enemy["speed"], 4.0 * TowerDefinition.FREEZE_SPEED_MULTIPLIER), "Permanent base speed composes with existing slow")
	enemy["hp"] = 100
	EnemyMechanics.after_damage(enemy, captured)
	enemy["hp"] = 25
	EnemyMechanics.after_damage(enemy, captured)
	_check(enemy["base_speed"] == 4.0, "Healing and later threshold crossings never multiply permanent rage twice")
	enemy["age"] = 3.0
	enemy["max_hp"] = 101
	EnemyMechanics.advance(enemy, captured)
	_check(enemy["hp"] == 36 and enemy["regeneration_count"] == 1 and enemy["animation"] == "heal", "Generic resource combines rage and regeneration, rounding fractional max-HP healing upward")
	enemy["hp"] = 0
	enemy["age"] = 9.0
	EnemyMechanics.advance(enemy, captured)
	_check(enemy["hp"] == 0 and EnemyMechanics.event_step(enemy, captured) == INF, "Periodic ability cannot resurrect a dead individual")


func _test_physical_resistance() -> void:
	var rules := _rules()
	var combat := _sandbox(["scrapguard"], rules)
	_definition(rules, &"scrapguard").physical_damage_multiplier = 1.0
	var enemy: Dictionary = combat.enemies[0][0]
	var tower: Dictionary = _tower(combat)
	var maximum: int = enemy["max_hp"]
	combat._hit(0, tower, 0, 11, false, &"physical")
	_check(enemy["hp"] == maximum - 6 and tower["damage_dealt"] == 6, "Physical resistance rounds once and credits only actual HP removed")
	for damage_type: StringName in [&"magic", &"fire", &"ice", &"lightning", &"explosive"]:
		var hp: int = enemy["hp"]
		combat._hit(0, tower, 0, 10, false, damage_type)
		_check(enemy["hp"] == hp - 10, "Scrap armor does not resist nonphysical damage: " + String(damage_type))
	var continuous_rules := _rules()
	continuous_rules.enemy_speed = 0.0
	var continuous := _sandbox(["scrapguard"], continuous_rules)
	_check(continuous.build(0, Vector2i(0, 1), &"rune_obelisk", MatchCombat.TargetMode.FURTHEST), "Real Rune fixture is placed beside Scrapguard")
	var rune: Dictionary = continuous.towers[0][0]
	for upgrade: String in ["damage", "speed", "boulders"]:
		_check(continuous.upgrade_tower(0, rune["id"], upgrade), "Physical continuous-damage evolution is accepted")
	var target: Dictionary = continuous.enemies[0][0]
	var expected: int = floori(float(rune["base_damage"]) * float(rune["damage_multiplier"]) * float(rune["speed_multiplier"]) * 0.5 + 0.000000001)
	continuous.advance(1.0)
	_check(int(target["max_hp"]) - int(target["hp"]) == expected and rune["damage_dealt"] == expected, "Physical resistance applies before fractional continuous damage, not only discrete hits")


func _test_crate_death_and_leak() -> void:
	var combat := _sandbox(["crate_orc"])
	var crate: Dictionary = combat.enemies[0][0]
	crate["progress"] = 4.25
	crate["pos"] = Vector2(4.25, 0.0)
	var route: Array = crate["route"].duplicate()
	var tower: Dictionary = _tower(combat)
	var coins_before: int = combat.coins[0]
	combat._hit(0, tower, 0, 10000)
	_check(combat.enemies[0].size() == 2 and combat.coins[0] == coins_before + 4, "Real player kill grants crate bounty once and exactly two individual Orclings, not rolled groups")
	var ids: Dictionary = {}
	for child: Dictionary in combat.enemies[0]:
		_check(child["type_id"] == "orcling" and child["route"] == route and child["progress"] == 4.25 and child["age"] == 0.0 and child["hp"] == child["max_hp"], "Death children inherit captured route/progress with independent fresh living state")
		_check(not ids.has(child["id"]) and child["id"] != crate["id"], "Every death child receives a distinct host identity")
		ids[child["id"]] = true
	combat.advance(0.01)
	_check(combat.phase == MatchCombat.Phase.WAVE, "Living death children prevent wave clearance")
	coins_before = combat.coins[0]
	for index: int in range(2):
		combat._hit(0, tower, 0, 10000)
	_check(combat.coins[0] == coins_before + 2 and combat.enemy_totals[0]["kills"].get("orcling", 0) == 2, "Death children retain ordinary individual Orcling rewards and kill totals")
	var leak_rules := _rules(false)
	leak_rules.wave_weight = 1
	combat = MatchCombat.new(leak_rules, null, _rng())
	_check(combat.start_wave(_routes()), "Real match admits a short leak fixture")
	combat._spawn_enemy(0, "crate_orc", 99.999, 0.0)
	crate = combat.enemies[0].back()
	var health: int = combat.base_health[0]
	combat.advance(1.0)
	var death_children: int = 0
	for child: Dictionary in combat.enemies[0]:
		if child["summoner_id"] == crate["id"]:
			death_children += 1
	_check(combat._enemy_index(0, crate["id"]) < 0 and death_children == 0 and combat.base_health[0] == health - 2 and combat.enemy_totals[0]["kills"].is_empty(), "Leaking CrateOrc damages base but creates no children or kills")
	combat = _sandbox(["troll", "crate_orc"])
	combat.advance(2.0)
	var troll: Dictionary = _enemy(combat, "troll")
	crate = _enemy(combat, "crate_orc")
	crate["hp"] = 1
	troll["next_stomp"] = troll["age"] + 0.01
	coins_before = combat.coins[0]
	combat.advance(0.01)
	var children: int = 0
	for child: Dictionary in combat.enemies[0]:
		if child["type_id"] == "orcling":
			children += 1
	_check(children == 2 and combat.coins[0] == coins_before and combat.enemy_totals[0]["kills"].is_empty(), "Collateral real death releases children without player rewards")


func _test_rage_damage_and_healing() -> void:
	var combat := _sandbox(["rage_orc"])
	var enemy: Dictionary = combat.enemies[0][0]
	var tower: Dictionary = _tower(combat)
	var base_speed: float = enemy["base_speed"]
	enemy["slowed"] = true
	enemy["slow_remaining"] = 1.0
	BossMechanics.prepare(enemy)
	var half: int = int(enemy["max_hp"]) / 2
	combat._hit(0, tower, 0, half - 1)
	_check(not enemy["enraged"], "A surviving hit above half HP does not enrage early")
	combat._hit(0, tower, 0, 1)
	_check(enemy["enraged"] and is_equal_approx(enemy["base_speed"], base_speed * 1.6), "First surviving hit at exactly half HP triggers rage")
	_check(is_equal_approx(enemy["speed"], base_speed * 1.6 * TowerDefinition.FREEZE_SPEED_MULTIPLIER), "Accepted rage speed retains active slow multiplier")
	combat.advance(1.1)
	_check(not enemy["slowed"] and is_equal_approx(enemy["speed"], base_speed * 1.6), "Slow expiry reveals permanent rage speed without multiplying again")
	enemy["hp"] = enemy["max_hp"]
	combat._hit(0, tower, 0, half)
	_check(is_equal_approx(enemy["base_speed"], base_speed * 1.6), "Healing above threshold never rearms the transition")
	var lethal := _sandbox(["rage_orc"])
	var doomed: Dictionary = lethal.enemies[0][0]
	lethal._hit(0, _tower(lethal), 0, 10000)
	_check(not doomed["enraged"] and lethal.enemies[0].is_empty(), "Lethal damage never creates a postmortem rage transition")


func _test_moss_deadlines_and_partitioning() -> void:
	var coarse := _sandbox(["moss_orc"])
	var fine := _sandbox(["moss_orc"])
	var moss: Dictionary = coarse.enemies[0][0]
	var fine_moss: Dictionary = fine.enemies[0][0]
	moss["hp"] = 400
	fine_moss["hp"] = 400
	coarse.sandbox_spawn(0, &"grunt", 1)
	var ally: Dictionary = coarse.enemies[0][1]
	ally["hp"] = 10
	coarse.advance(3.998)
	_check(moss["hp"] == 400 and moss["regeneration_count"] == 0, "Birth-relative regeneration does not happen before deadline")
	coarse.advance(0.001)
	_check(moss["hp"] == 448 and moss["regeneration_count"] == 1 and moss["animation"] == "heal" and ally["hp"] == 10, "Four-second event heals ceil(maxHP × fraction) only on itself")
	coarse.advance(8.0)
	for tick: int in range(119):
		fine.advance(0.1)
	fine.advance(0.099)
	_check(moss["hp"] == fine_moss["hp"] and moss["regeneration_count"] == fine_moss["regeneration_count"] and is_equal_approx(moss["progress"], fine_moss["progress"]) and is_equal_approx(moss["next_regeneration"], fine_moss["next_regeneration"]), "Coarse and fine simulation partitions agree on healing deadlines and motion")
	moss["hp"] = int(moss["max_hp"]) - 1
	coarse.advance(4.0)
	_check(moss["hp"] == moss["max_hp"], "Regeneration clamps at maximum HP")
	var count: int = moss["regeneration_count"]
	coarse.advance(4.0)
	_check(moss["regeneration_count"] == count and moss["next_regeneration"] > moss["age"], "Full-health intervals advance clock without a fake heal counter or pose")
	moss["hp"] = 0
	var captured: Dictionary = EnemyMechanics.capture(_definition(_rules(), &"moss_orc"))
	moss["age"] = float(moss["next_regeneration"])
	EnemyMechanics.advance(moss, captured)
	_check(moss["hp"] == 0 and moss["regeneration_count"] == count, "A due timer cannot resurrect dead MossOrc")


func _test_authored_frame_selection() -> void:
	var rules := _rules()
	for id: StringName in IDS:
		var definition: EnemyDefinition = _definition(rules, id)
		_check(definition.animation_frames.get_frame_count(&"walk") == 12 and definition.animation_frames.get_frame_count(&"death") == 12, "Every new enemy ships authored twelve-frame walk/death cycles")
		_check(EnemyVisuals.frame_texture(definition, &"walk", 0.0) != EnemyVisuals.frame_texture(definition, &"walk", 0.2), "Simulation-time selector advances actual authored walk frame")
	var rage: EnemyDefinition = _definition(rules, &"rage_orc")
	var enemy: Dictionary = {"animation": "walk", "animation_elapsed": 0.1, "enraged": true, "hp": 100, "max_hp": 350}
	_check(EnemyVisuals.enemy_texture(rage, enemy) == EnemyVisuals.frame_texture(rage, &"walk_enraged", 0.1), "Permanent host rage state selects authored enraged animation")
	enemy["hp"] = 350
	_check(EnemyVisuals.enemy_texture(rage, enemy) == EnemyVisuals.frame_texture(rage, &"walk_enraged", 0.1), "Visual enrage survives later healing above threshold")
	var moss: EnemyDefinition = _definition(rules, &"moss_orc")
	_check(is_equal_approx(EnemyVisuals.animation_duration(moss, &"heal"), 0.55) and EnemyVisuals.frame_texture(moss, &"heal", 0.1) != EnemyVisuals.frame_texture(moss, &"walk", 0.1), "Moss uses an actual authored heal animation with normal host pose duration")
