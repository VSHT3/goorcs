extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_variant_births()
	_test_summon_capacity_and_transfer()
	_test_kamika_hits_and_stun()
	_test_projectile_shield_break()
	_test_undead_immunity()
	_test_continuous_shields()
	_test_giant_bomb()
	_test_bomb_fine_expiry()
	_test_bomb_partition_and_boundaries()
	_test_bomb_wave_and_reset()
	if failures == 0:
		print("PASS: late Skeltorc variants, captured summon lineage, ten-hit shields, cadence invariance, delayed same-board bomb stuns and wave/reset ownership")
	quit(1 if failures else 0)


func _rules() -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	var enemies: Array[EnemyDefinition] = []
	for definition: EnemyDefinition in rules.catalog.enemies:
		enemies.append(definition.duplicate() as EnemyDefinition)
	rules.catalog.enemies = enemies
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.starting_coins = 100000
	rules.base_health = 10000
	rules.enemy_health = 101
	rules.health_growth = 1
	rules.enemy_speed = 0.1
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	return rules


func _routes(length: int = 100, row: int = 4) -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(length + 1):
		route.append(Vector2i(x, row))
		next[Vector2i(x, row)] = [Vector2i(x + 1, row)] if x < length else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _empty(round_number: int = 151, rules: CombatRules = null) -> MatchCombat:
	var random := RandomNumberGenerator.new()
	random.seed = 88271
	var core := MatchCombat.new(_rules() if rules == null else rules, null, random)
	_check(core.sandbox_start(_routes(), round_number, []), "Start actual isolated late-round Sandbox model")
	return core


func _definition(rules: CombatRules, id: StringName) -> EnemyDefinition:
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.id == id:
			return definition
	_check(false, "Required registered identity: " + String(id))
	return null


func _tower(core: MatchCombat, cell: Vector2i = Vector2i(0, 1), type_id: StringName = &"arrow_tower", slot: int = 0) -> Dictionary:
	_check(core.build(slot, cell, type_id, MatchCombat.TargetMode.FURTHEST), "Build actual damage/stun fixture tower")
	return core.towers[slot].back()


func _birth(core: MatchCombat, type_id: String = "kamikaorc", progress: float = 10.0, slot: int = 0) -> Dictionary:
	core._spawn_enemy(slot, type_id, progress, core._elapsed)
	return core.enemies[slot].back()


func _variant_seed(wins: bool) -> int:
	var random := RandomNumberGenerator.new()
	for seed_value: int in range(100000):
		random.seed = seed_value
		if (random.randf() < 0.01) == wins:
			return seed_value
	_check(false, "Find deterministic 1-percent roll fixture")
	return 0


func _test_variant_births() -> void:
	var rules: CombatRules = _rules()
	var core: MatchCombat = _empty(150, rules)
	core._variant_random.seed = _variant_seed(true)
	var untouched: int = core._variant_random.state
	var before_gate: Dictionary = _birth(core, "skeleorc", 2.25)
	_check(before_gate["type_id"] == "skeleorc" and core._variant_random.state == untouched, "Round 150 cannot replace a Skeltorc or consume a variant roll")
	core = _empty(151, rules)
	core._variant_random.seed = _variant_seed(false)
	_check(_birth(core, "skeleorc")["type_id"] == "skeleorc", "A failed eligible roll keeps the normal identity")
	for round_number: int in [151, 152, 180]:
		core = _empty(round_number, rules)
		core._variant_random.seed = _variant_seed(true)
		var other_streams: Array[int] = [core._wave_random.state, core._group_random.state, core._roll_random.state, core._drop_random.state]
		var next_id: int = core._next_enemy_id
		var route: Array[Vector2i] = []
		route.assign(_routes()[0]["route"])
		core._spawn_enemy(0, "skeleorc", 2.25, core._elapsed, route, 423)
		var giant: Dictionary = core.enemies[0].back()
		var ordinary_hp: int = int(MatchCombat.enemy_preview(_definition(rules, &"skeleorc"), rules, round_number)["max_hp"])
		var ordinary_speed: float = float(MatchCombat.enemy_preview(_definition(rules, &"skeleorc"), rules, round_number)["speed"])
		_check(giant["type_id"] == "giant_skeltorc" and giant["id"] == next_id and core._next_enemy_id == next_id + 1, "Eligible replacement creates one accepted Giant identity, not a second unit")
		_check(giant["max_hp"] == ordinary_hp * 50 and giant["hp"] == giant["max_hp"] and is_equal_approx(giant["base_speed"], ordinary_speed * 0.8), "Giant uses 50x already-rounded normal HP and exactly 20-percent slower original movement")
		_check(giant["route"] == route and is_equal_approx(giant["progress"], 2.25) and giant["summoner_id"] == 423, "Variant retains captured route, exact progress and direct summoner lineage")
		_check(giant["fire_immune"] and giant["ice_immune"] and not giant["burning"] and not giant["slowed"], "Giant retains undead fire/ice immunity")
		_check(other_streams == [core._wave_random.state, core._group_random.state, core._roll_random.state, core._drop_random.state], "Variant rolls do not perturb wave, summon-group, tower-roll or loot streams")
		untouched = core._variant_random.state
		_birth(core, "grunt")
		_birth(core, "giant_skeltorc")
		_check(core._variant_random.state == untouched, "Unrelated and explicit Giant births never reroll an existing identity")


func _test_summon_capacity_and_transfer() -> void:
	var rules: CombatRules = _rules()
	_definition(rules, &"skeleorc").spawn_variant_chance = 1.0
	var core: MatchCombat = _empty(151, rules)
	var caster: Dictionary = _birth(core, "necorcmancer", 10.25)
	for ritual: int in range(4):
		core._finish_summon(0, caster, core._enemy_types["necorcmancer"])
	var children: int = 0
	for enemy: Dictionary in core.enemies[0]:
		if enemy["summoner_id"] == caster["id"]:
			children += 1
			_check(enemy["type_id"] == "giant_skeltorc" and enemy["route"] == caster["route"] and is_equal_approx(enemy["progress"], caster["progress"]), "Every actual ritual child retains the Giant identity and captured parent route")
	_check(children == int(core._enemy_types["necorcmancer"]["summon_limit"]), "Giant children occupy their normal direct-child capacity without extra summon slots")
	core = _empty(151)
	core._variant_random.seed = _variant_seed(false)
	var ordinary: Dictionary = _birth(core, "skeleorc", 10.0)
	var catapult: Dictionary = _tower(core, Vector2i(10, 3), &"orcapult")
	core._variant_random.seed = _variant_seed(true)
	var unchanged: int = core._variant_random.state
	var id: int = ordinary["id"]
	core._launch(0, catapult, ordinary)
	core._elapsed += MatchCombat.FLIGHT_DURATION
	core._land_flights()
	_check(core._variant_random.state == unchanged and core.enemies[0].back()["id"] == id and core.enemies[0].back()["type_id"] == "skeleorc", "Orcapult landing transfers the same accepted enemy and never rolls a new Giant birth")


func _test_kamika_hits_and_stun() -> void:
	var core: MatchCombat = _empty(80)
	var killer: Dictionary = _tower(core, Vector2i(10, 3))
	var support: Dictionary = _tower(core, Vector2i(11, 3), &"war_drums")
	var mine: Dictionary = _tower(core, Vector2i(9, 5), &"gold_mine")
	var outside: Dictionary = _tower(core, Vector2i(12, 4), &"gold_mine")
	var victim: Dictionary = _birth(core)
	_birth(core, "grunt", 60.0)
	var hp: int = victim["hp"]
	var coins: Array[int] = core.coins.duplicate()
	var index: int = core._enemy_index(0, victim["id"])
	_check(not core._hit(0, killer, index, 0) and victim["shield_hits"] == 10, "Zero-damage contacts cannot strip a shield")
	for hit: int in range(10):
		_check(not core._hit(0, killer, index, 100000), "Shield absorbs the whole positive hit")
		_check(victim["hp"] == hp and victim["shield_hits"] == 9 - hit, "A hit removes exactly one charge regardless of damage; final charge has no overflow")
	_check(killer["damage_dealt"] == 0 and killer["kills"] == 0 and core.coins == coins, "Absorbed hits grant no damage credit, kills, rewards or currency")
	_check(core._hit(0, killer, index, 100000) and killer["kills"] == 1, "The first unshielded hit can kill the low-HP KamikaOrc")
	for tower: Dictionary in [killer, support, mine]:
		_check(is_equal_approx(tower["stunned_remaining"], 3.0), "Same-board one-tile death stun reaches attacker/support/mine roles including diagonal cells")
	_check(outside["stunned_remaining"] == 0.0, "Death stun never reaches a tower outside the one-tile footprint")
	core.advance(1.25)
	_check(is_equal_approx(mine["stunned_remaining"], 1.75), "New death stun ages only after the actual death boundary")
	core.advance(1.75)
	_check(mine["stunned_remaining"] == 0.0 and support["stunned_remaining"] == 0.0, "All affected roles recover when the nonstacking stun expires")


func _test_projectile_shield_break() -> void:
	var rules: CombatRules = _rules()
	rules.enemy_speed = 0.0
	rules.enemy_health = 100000
	var core: MatchCombat = _empty(100, rules)
	var tower: Dictionary = _tower(core, Vector2i(10, 3))
	for upgrade: String in ["damage", "speed", "special", "fire_arrows"]:
		_check(core.upgrade_tower(0, tower["id"], upgrade), "Buy real ignition-bearing arrows")
	var victim: Dictionary = _birth(core)
	for hit: int in range(9):
		core._hit(0, tower, 0, 100000)
	var hp: int = victim["hp"]
	var config: Dictionary = core._tower_types["arrow_tower"]["advancements"]["fire_arrows"]
	core._attack_arrow(0, tower, victim["id"], victim["pos"], config)
	_check(victim["shield_hits"] == 0 and victim["hp"] == hp and not victim["burning"], "Tenth shield-breaking projectile still blocks that same projectile's attached ignition")
	core._attack_arrow(0, tower, victim["id"], victim["pos"], config)
	_check(victim["hp"] < hp and victim["burning"], "The next real projectile damages and ignites the unprotected enemy")


func _test_undead_immunity() -> void:
	var flame: MatchCombat = _beam_fixture(true, "giant_skeltorc")
	var giant: Dictionary = flame.enemies[0][0]
	var hp: int = giant["hp"]
	flame.advance(2.0)
	_check(giant["hp"] == hp and not giant["burning"] and not flame.towers[0][0]["firing"], "Giant keeps normal Skeltorc immunity to the entire Flamethrower and burning")
	var runes: MatchCombat = _beam_fixture(false, "giant_skeltorc")
	giant = runes.enemies[0][0]
	hp = giant["hp"]
	runes.advance(0.5)
	_check(giant["hp"] < hp and not giant["slowed"], "Freeze Boulders retain direct damage but cannot slow the ice-immune Giant")


func _beam_fixture(flame: bool, type_id: String = "kamikaorc") -> MatchCombat:
	var rules: CombatRules = _rules()
	rules.enemy_speed = 0.0
	rules.enemy_health = 100000
	rules.health_growth = 0
	var core: MatchCombat = _empty(100, rules)
	var tower: Dictionary = _tower(core, Vector2i(10, 3), &"arrow_tower" if flame else &"rune_obelisk")
	for upgrade: String in ["damage", "speed", "special"] if flame else ["damage", "speed"]:
		_check(core.upgrade_tower(0, tower["id"], upgrade), "Buy actual base weapon prerequisites")
	var path: Array[String] = []
	if not flame:
		path.assign(["boulders", "freeze_runes"])
	# Resolve the authored advancement chain rather than duplicating branch stats.
	if flame:
		path.clear()
		var cursor: String = "flamethrower"
		while not cursor.is_empty():
			path.push_front(cursor)
			cursor = core.snapshot()["tower_types"]["arrow_tower"]["advancements"][cursor].get("requires", "")
	for upgrade: String in path:
		_check(core.upgrade_tower(0, tower["id"], upgrade), "Buy accepted continuous weapon branch: " + upgrade)
	_birth(core, type_id)
	return core


func _test_continuous_shields() -> void:
	for flame: bool in [false, true]:
		var coarse: MatchCombat = _beam_fixture(flame)
		var fine: MatchCombat = _beam_fixture(flame)
		var interval: float = coarse.towers[0][0]["interval"]
		if interval <= 0.0:
			interval = float(coarse.snapshot()["tower_types"]["rune_obelisk"]["interval"]) / float(coarse.towers[0][0]["speed_multiplier"])
		coarse.advance(interval * 5.25)
		for tick: int in range(105):
			fine.advance(interval * 0.05)
		var a: Dictionary = coarse.enemies[0][0]
		var b: Dictionary = fine.enemies[0][0]
		_check(a["shield_hits"] == b["shield_hits"] and a["shield_hits"] > 0 and a["hp"] == a["max_hp"] and b["hp"] == b["max_hp"], "Continuous shield depletion follows accepted attack cadence, not frame count or accumulated integer HP")
		_check(not a["burning"] and not a["slowed"] and coarse.towers[0][0]["damage_dealt"] == 0, "Protected continuous exposure cannot ignite, freeze or accrue deferred damage credit")
		coarse.advance(interval * 6.0)
		for tick: int in range(120):
			fine.advance(interval * 0.05)
		a = coarse.enemies[0][0]
		b = fine.enemies[0][0]
		_check(a["shield_hits"] == 0 and b["shield_hits"] == 0 and a["hp"] == b["hp"] and a["hp"] < a["max_hp"], "After shield break only actual unprotected beam exposure removes HP, independent of coarse/fine stepping: flame=%s shields=%s/%s hp=%s/%s" % [flame, a["shield_hits"], b["shield_hits"], a["hp"], b["hp"]])


func _test_giant_bomb() -> void:
	var core: MatchCombat = _empty(151)
	var killer: Dictionary = _tower(core)
	var near: Dictionary = _tower(core, Vector2i(12, 4), &"gold_mine")
	var diagonal: Dictionary = _tower(core, Vector2i(12, 6), &"war_drums")
	var outside: Dictionary = _tower(core, Vector2i(13, 4), &"gold_mine")
	var opponent: Dictionary = _tower(core, Vector2i(10, 4), &"gold_mine", 1)
	var giant: Dictionary = _birth(core, "giant_skeltorc")
	var victim: Dictionary = _birth(core, "grunt", 11.0)
	var caster: Dictionary = _birth(core, "necorcmancer", 11.5)
	var distant: Dictionary = _birth(core, "grunt", 20.0)
	var coins: Array[int] = core.coins.duplicate()
	core._hit(0, killer, core._enemy_index(0, giant["id"]), 10000000)
	_check(core.coins == coins and killer["kills"] == 1, "Giant retains zero normal Skeltorc Coin bounty; a backpack bomb grants no extra reward")
	_check(core.snapshot()["bombs"].size() == 1 and near["stunned_remaining"] == 0.0 and victim["stunned_remaining"] == 0.0, "Confirmed Giant death drops one pending bomb without an immediate blast")
	core.advance(1.999)
	_check(core.snapshot()["bombs"].size() == 1 and near["stunned_remaining"] == 0.0, "Lit fuse cannot detonate before two simulation seconds")
	core.advance(0.001)
	_check(core.snapshot()["bombs"].is_empty() and not core.snapshot()["bomb_explosions"].is_empty(), "Host expires the fuse and publishes the actual blast event")
	_check(is_equal_approx(near["stunned_remaining"], 3.0) and is_equal_approx(diagonal["stunned_remaining"], 3.0) and is_equal_approx(victim["stunned_remaining"], 3.0), "Two-tile bomb affects nearby living enemies and all tower roles on its board")
	_check(outside["stunned_remaining"] == 0.0 and opponent["stunned_remaining"] == 0.0 and distant["stunned_remaining"] == 0.0, "Blast never crosses its radius or the ravine to the other board")
	var progress: float = victim["progress"]
	var age: float = caster["age"]
	var hp: int = victim["hp"]
	core.advance(2.0)
	_check(is_equal_approx(victim["progress"], progress) and is_equal_approx(caster["age"], age) and victim["hp"] == hp and caster["summon_count"] == 0, "Enemy stun freezes movement and ability clocks without dealing HP damage")
	core.advance(1.25)
	_check(victim["stunned_remaining"] == 0.0 and float(victim["progress"]) > progress and float(caster["age"]) > age, "Expiry resumes enemy motion and ability clocks for only the post-stun portion of a coarse tick")


func _test_bomb_wave_and_reset() -> void:
	var core: MatchCombat = _empty(151)
	var killer: Dictionary = _tower(core)
	var giant: Dictionary = _birth(core, "giant_skeltorc")
	core._hit(0, killer, 0, 10000000)
	core.advance(1.999)
	_check(core.phase == MatchCombat.Phase.WAVE and core.enemies[0].is_empty(), "A last-enemy death cannot clear the wave while its fuse is pending")
	core.advance(0.001)
	_check(core.phase == MatchCombat.Phase.PLANNING and core.snapshot()["bombs"].is_empty(), "Wave can clear only after its pending bomb resolves")
	core = _empty(151)
	killer = _tower(core)
	giant = _birth(core, "giant_skeltorc")
	core._hit(0, killer, 0, 10000000)
	core.debug_set_round(1)
	_check(core.snapshot()["bombs"].is_empty() and core.snapshot()["bomb_explosions"].is_empty(), "Abandoning/resetting a round removes fuses and blast events without detonating or paying rewards")


func _test_bomb_fine_expiry() -> void:
	var core: MatchCombat = _empty(151)
	var killer: Dictionary = _tower(core)
	var giant: Dictionary = _birth(core, "giant_skeltorc")
	var victim: Dictionary = _birth(core, "grunt", 11.0)
	core._hit(0, killer, core._enemy_index(0, giant["id"]), 10000000)
	core.advance(2.0)
	for tick: int in range(180):
		core.advance(1.0 / 60.0)
	var progress: float = victim["progress"]
	core.advance(1.0 / 60.0)
	_check(victim["stunned_remaining"] == 0.0 and String(victim["stun_source"]).is_empty() and float(victim["progress"]) > progress, "Native sixty-Hz stun expiry retires tiny timer residue as exact zero and resumes movement; remaining=%s" % victim["stunned_remaining"])


func _test_bomb_partition_and_boundaries() -> void:
	var coarse: MatchCombat = _empty(151)
	var fine: MatchCombat = _empty(151)
	for core: MatchCombat in [coarse, fine]:
		var killer: Dictionary = _tower(core)
		var giant: Dictionary = _birth(core, "giant_skeltorc")
		_birth(core, "necorcmancer", 11.0)
		core._hit(0, killer, core._enemy_index(0, giant["id"]), 10000000)
	coarse.advance(5.25)
	for tick: int in range(315):
		fine.advance(1.0 / 60.0)
	var a: Dictionary = coarse.enemies[0][0]
	var b: Dictionary = fine.enemies[0][0]
	_check(a["hp"] == b["hp"] and a["summon_count"] == b["summon_count"] and is_equal_approx(a["progress"], b["progress"]) and is_equal_approx(a["age"], b["age"]) and a["stunned_remaining"] == b["stunned_remaining"], "Delayed bomb plus enemy-stun expiry preserves real coarse/fine motion, health and ritual clocks")
	var core: MatchCombat = _empty(151)
	var killer: Dictionary = _tower(core)
	var giant: Dictionary = _birth(core, "giant_skeltorc")
	var origin: Vector2 = giant["pos"]
	giant["progress"] = float(giant["route"].size() - 1)
	core._apply_leaks(0)
	_check(core.bombs.is_empty(), "A Giant reaching the crystal never drops a bomb")
	giant = _birth(core, "giant_skeltorc")
	core._hit(0, killer, 0, 10000000)
	core.advance(1.0)
	var arrived: Dictionary = _birth(core, "grunt", origin.x + 1.0)
	var hp: int = arrived["hp"]
	core.advance(1.0)
	_check(is_equal_approx(arrived["stunned_remaining"], 3.0) and arrived["hp"] == hp, "An enemy born after the bomb drop but before its blast is affected without HP damage")
	var late: Dictionary = _birth(core, "grunt", origin.x + 1.0)
	_check(late["stunned_remaining"] == 0.0, "A spent blast is not a persistent stun aura for future births")
	var second: Dictionary = _birth(core, "giant_skeltorc")
	core._hit(0, killer, core._enemy_index(0, second["id"]), 10000000)
	core.advance(2.0)
	_check(is_equal_approx(arrived["stunned_remaining"], 3.0) and is_equal_approx(late["stunned_remaining"], 3.0), "A later blast refreshes to the strongest remaining duration instead of stacking additive stun debt")
	core = _empty(151)
	killer = _tower(core)
	giant = _birth(core, "giant_skeltorc")
	core._hit(0, killer, 0, 10000000)
	core.base_health[1] = 0
	core.advance(0.1)
	_check(core.phase == MatchCombat.Phase.FINISHED and core.bombs.is_empty(), "Terminal defeat retires pending bombs without resolving post-result gameplay")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
