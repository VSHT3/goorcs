extends SceneTree

const TROLL := &"troll"
const MACHINE := &"orc_war_machine"

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_encounters()
	_test_send_atomicity()
	_test_damage_types()
	_test_fractional_damage()
	_test_stomp()
	_test_club_target_and_cancellation()
	_test_stunned_weapons()
	_test_stunned_support_and_economy()
	_test_machine_terrain_and_jumps()
	_test_machine_summons()
	_test_machine_cancellation()
	_test_mixed_route_targeting()
	_test_simulation_partition()
	_test_sandbox_consumer()
	if failures == 0:
		print("PASS: late boss encounters, damage typing, stomp retirement, tower stuns, direct terrain/jumps, weighted route-joining troops and real Sandbox clocks/reset")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rng(seed_value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = seed_value
	return result


func _rules(sandbox: bool = true) -> CombatRules:
	var result := CombatRules.new()
	result.catalog = result.catalog.duplicate() as ContentCatalog
	var enemies: Array[EnemyDefinition] = []
	for definition: EnemyDefinition in result.catalog.enemies:
		enemies.append(definition.duplicate() as EnemyDefinition)
	result.catalog.enemies = enemies
	var towers: Array[TowerDefinition] = []
	for definition: TowerDefinition in result.catalog.towers:
		var owned := definition.duplicate() as TowerDefinition
		owned.advancements = definition.advancements.duplicate(true)
		owned.evolutions = definition.evolutions.duplicate(true)
		towers.append(owned)
	result.catalog.towers = towers
	result.roll_rules = null
	result.sandbox_mode = sandbox
	result.starting_coins = 100000
	result.base_health = 100000
	result.enemy_health = 100000
	result.health_growth = 0
	result.enemy_speed = 0.0
	result.speed_growth_fraction = 0.0
	result.spawn_interval = 0.0
	result.spawn_jitter_ratio = 0.0
	result.spawn_interval_reduction_per_wave = 0.0
	return result


func _enemy(rules: CombatRules, id: StringName) -> EnemyDefinition:
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.id == id:
			return definition
	_check(false, "Shipped catalog contains " + String(id))
	return null


func _tower(rules: CombatRules, id: StringName) -> TowerDefinition:
	for definition: TowerDefinition in rules.catalog.towers:
		if definition.reward.id == id:
			return definition
	_check(false, "Shipped tower catalog contains " + String(id))
	return null


func _combat(rules: CombatRules, seed_value: int = 71) -> MatchCombat:
	return MatchCombat.new(rules, _rng(seed_value + 1), _rng(seed_value), _rng(seed_value + 2), _rng(seed_value + 3), _rng(seed_value + 4))


func _layout(detour: bool = false, width: int = 14) -> PathLayout:
	var result := PathLayout.new(Vector2i(width, 5), width * 5 - 2, Vector2i(0, 2), Vector2i(width - 1, 2))
	if detour:
		result.place(Vector2i(0, 1))
		result.place(Vector2i(width - 1, 1))
		for x: int in range(width):
			result.place(Vector2i(x, 0))
	else:
		for x: int in range(1, width - 1):
			result.place(Vector2i(x, 2))
	return result


func _routing(layout: PathLayout) -> Array[Dictionary]:
	var captured: Dictionary = layout.capture_routing()
	return [captured, captured]


func _start(rules: CombatRules, roster: Array[String], layout: PathLayout = null, seed_value: int = 71) -> MatchCombat:
	var result := _combat(rules, seed_value)
	if layout == null:
		layout = _layout()
	_check(result.sandbox_start(_routing(layout), 1, roster), "Actual combat admits resource-backed boss fixture")
	result.advance(0.000001)
	return result


func _quiet(rules: CombatRules) -> void:
	for id: StringName in [TROLL, MACHINE]:
		var definition: EnemyDefinition = _enemy(rules, id)
		definition.tower_attack_interval = 0.0
		definition.tower_attack_kind = &""
		definition.stomp_interval = 0.0
		definition.summon_interval = 0.0


func _weapon(combat: MatchCombat, type_id: StringName, branch: String = "", cell: Vector2i = Vector2i(0, 1)) -> Dictionary:
	_check(combat.build(0, cell, type_id, MatchCombat.TargetMode.FURTHEST), "Fixture builds real tower")
	var tower: Dictionary = combat.towers[0].back()
	if branch.is_empty():
		return tower
	for command: String in ["damage", "speed"]:
		_check(combat.upgrade_tower(0, tower["id"], command), "Fixture buys ordinary prerequisite " + command)
	var definition: Dictionary = combat.snapshot()["tower_types"][String(type_id)]
	if type_id == &"arrow_tower":
		_check(combat.upgrade_tower(0, tower["id"], "special"), "Fixture buys second archer prerequisite")
		var path: Array[String] = []
		var cursor: String = branch
		while not cursor.is_empty():
			path.push_front(cursor)
			cursor = String(definition["advancements"][cursor].get("requires", ""))
		for command: String in path:
			_check(combat.upgrade_tower(0, tower["id"], command), "Fixture buys real advancement " + command)
	else:
		_check(combat.upgrade_tower(0, tower["id"], "boulders" if branch == "freeze_runes" else branch), "Fixture buys real rune evolution")
		if branch == "freeze_runes":
			_check(combat.upgrade_tower(0, tower["id"], branch), "Fixture buys ice follow-up")
	return tower


func _find(combat: MatchCombat, type_id: StringName, slot: int = 0) -> Dictionary:
	for enemy: Dictionary in combat.enemies[slot]:
		if enemy["type_id"] == String(type_id):
			return enemy
	return {}


func _test_encounters() -> void:
	for profile: Array in [[TROLL, 60], [MACHINE, 100]]:
		var id: StringName = profile[0]
		var debut: int = profile[1]
		for seed_value: int in range(32):
			for round_number: int in [1, debut - 1, debut]:
				var rules := _rules(false)
				var combat := _combat(rules, seed_value)
				_check(combat.debug_set_round(round_number) and combat.start_wave(_routing(_layout())), "Normal encounter generator starts requested round")
				_check(combat.wave_roster.count(String(id)) == (1 if round_number == debut else 0), "No early boss and exactly one guaranteed debut: " + String(id))
				var consumed: int = 0
				var counts: Dictionary = {}
				var definitions: Dictionary = combat.snapshot()["enemy_types"]
				var budget: int = rules.wave_weight + (round_number - 1) * rules.wave_weight_growth
				for group: Dictionary in combat.wave_groups:
					consumed += int(definitions[group["type_id"]]["spawn_weight"])
					counts[group["type_id"]] = int(counts.get(group["type_id"], 0)) + 1
				_check(consumed == budget, "Boss reservation consumes real group weight without shrinking or overflowing wave")
				for type_id: String in counts:
					var definition: Dictionary = definitions[type_id]
					var cap: int = combat._enemy_count_cap(definition, round_number)
					_check(cap == 0 or int(counts[type_id]) <= cap, "Actual roster obeys every hard group cap")
					_check(int(counts[type_id]) * int(definition["spawn_weight"]) <= floori(budget * float(definition["max_weight_share"])), "Actual roster obeys boss and ordinary weight shares")
		# Deterministic odds boundaries detect accidental ordinary-selection admission.
		for odds: Array in [[0.0, 0.0, 1.0, 1, 0], [1.0, 0.0, 1.0, 1, 1], [0.0, 1.0, 1.0, 1, 0], [0.0, 1.0, 1.0, 2, 1], [0.0, 1.0, 0.0, 20, 0]]:
			var rules := _rules(false)
			var boss: EnemyDefinition = _enemy(rules, id)
			boss.boss_spawn_chance = odds[0]
			boss.boss_spawn_chance_growth = odds[1]
			boss.boss_spawn_chance_cap = odds[2]
			for seed_value: int in range(12):
				var combat := _combat(rules, seed_value)
				combat.debug_set_round(debut + int(odds[3]))
				combat.start_wave(_routing(_layout()))
				_check(combat.wave_roster.count(String(id)) == int(odds[4]), "Configured odds, post-debut growth offset and cap affect real later encounters")
		var encounters: Array[int] = [0, 0]
		for seed_value: int in range(256):
			for index: int in range(2):
				var combat := _combat(_rules(false), seed_value)
				combat.debug_set_round(debut + (1 if index == 0 else 80))
				combat.start_wave(_routing(_layout()))
				var count: int = combat.wave_roster.count(String(id))
				_check(count <= 1, "Later random encounters never repeat the boss")
				encounters[index] += count
		_check(encounters[0] > 0 and encounters[1] > encounters[0] and encounters[1] < 128, "Shipped late odds grow but remain rare over deterministic seeds")


func _test_send_atomicity() -> void:
	for malicious: bool in [false, true]:
		var rules := _rules(false)
		if malicious:
			for id: StringName in [TROLL, MACHINE]:
				var boss: EnemyDefinition = _enemy(rules, id)
				boss.send_enabled = true
				boss.send_first_wave = 1
		for round_number: int in [1, 59, 60, 99, 100, 500]:
			var combat := _combat(rules)
			combat.debug_set_round(round_number)
			for active: bool in [false, true]:
				if active:
					combat.start_wave(_routing(_layout()))
				var frozen: Dictionary = combat.snapshot()
				var streams: Array[int] = [combat._random.state, combat._wave_random.state, combat._timing_random.state, combat._group_random.state, combat._roll_random.state, combat._drop_random.state]
				for id: StringName in [TROLL, MACHINE]:
					_check(not frozen["enemy_types"][String(id)]["send_available"], "Accepted send consumers never offer a boss even with malicious local send flags")
					_check(not combat.send_enemy(0, id) and not combat.send_enemy(1, id) and not combat.send_enemy_mirrored(0, id), "Host rejects both boss sends and mirrored commands")
				_check(combat.snapshot() == frozen and streams == [combat._random.state, combat._wave_random.state, combat._timing_random.state, combat._group_random.state, combat._roll_random.state, combat._drop_random.state], "Rejected boss commands mutate no balances, queues, totals or gameplay RNG stream")


func _test_damage_types() -> void:
	for kind: StringName in [&"physical", &"fire", &"magic", &"lightning", &"explosive", &"ice"]:
		var rules := _rules()
		_quiet(rules)
		_tower(rules, &"arrow_tower").damage_type = kind
		_tower(rules, &"arrow_tower").damage = 4
		var combat := _start(rules, [String(TROLL)])
		var enemy: Dictionary = _find(combat, TROLL)
		_weapon(combat, &"arrow_tower")
		var hp: int = enemy["hp"]
		combat.advance(0.001)
		_check(hp - int(enemy["hp"]) == (4 if kind == &"physical" else 6), "Actual captured tower hit applies Troll vulnerability exactly once for " + String(kind))
	# Real weapon dispatch must preserve shaft/stone physical and spell/explosion kinds.
	for profile: Array in [[&"arrow_tower", "", false], [&"arrow_tower", "fire_arrows", false], [&"arrow_tower", "bomb_arrows", true], [&"arrow_tower", "molotov", true], [&"arrow_tower", "aom", true], [&"rune_obelisk", "", true], [&"rune_obelisk", "onyx_ring", true], [&"lightning", "", true]]:
		var losses: Array[int] = []
		for victim: StringName in [&"grunt", TROLL]:
			var rules := _rules()
			_quiet(rules)
			_enemy(rules, victim).health_multiplier = 1.0
			_tower(rules, profile[0]).damage = 8
			var combat := _start(rules, [String(victim)])
			var enemy: Dictionary = _find(combat, victim)
			var tower: Dictionary = _weapon(combat, profile[0], profile[1])
			var hp: int = enemy["hp"]
			combat.advance(float(tower["interval"]) if profile[1] == "onyx_ring" else 0.001)
			losses.append(hp - int(enemy["hp"]))
		_check(losses[0] > 0 and losses[1] == (ceili(losses[0] * 1.5) if profile[2] else losses[0]), "Real weapon dispatch uses intended damage kind: " + String(profile[0]) + "/" + String(profile[1]))
	for branch: String in ["bomb_arrows", "molotov", "aom"]:
		var losses: Array[int] = []
		for victim: StringName in [&"grunt", TROLL]:
			var rules := _rules()
			_quiet(rules)
			_tower(rules, &"arrow_tower").damage = 8
			var combat := _start(rules, ["grunt"])
			_check(combat.sandbox_spawn(0, victim, 1), "Splash fixture adds distinct actual secondary victim")
			var primary: Dictionary = combat.enemies[0][0]
			var secondary: Dictionary = combat.enemies[0][1]
			secondary["pos"] = Vector2(0.4, 2)
			var tower: Dictionary = _weapon(combat, &"arrow_tower", branch)
			var hp: int = secondary["hp"]
			combat._attack_arrow(0, tower, primary["id"], primary["pos"], combat.snapshot()["tower_types"]["arrow_tower"]["advancements"][branch])
			losses.append(hp - int(secondary["hp"]))
		_check(losses[0] > 0 and losses[1] == ceili(losses[0] * 1.5), "Nonphysical splash uses Troll multiplier once independently of primary hit: " + branch)
	for kind: StringName in [&"physical", &"magic"]:
		var rules := _rules()
		_quiet(rules)
		var combat := _start(rules, [String(TROLL)])
		var tower: Dictionary = _weapon(combat, &"arrow_tower")
		_weapon(combat, &"gold_mine", "bounty_board", Vector2i(1, 1))
		combat._update_bounties(0)
		var target: Dictionary = _find(combat, TROLL)
		var hp: int = target["hp"]
		combat._hit(0, tower, 0, 20, false, kind)
		_check(hp - int(target["hp"]) == (24 if kind == &"physical" else 36), "Existing real bounty mark and Troll vulnerability each multiply exactly once")


func _test_fractional_damage() -> void:
	for branch: String in ["burn", "boulders", "freeze_runes", "flamethrower"]:
		var rules := _rules()
		_quiet(rules)
		if branch == "flamethrower":
			_tower(rules, &"arrow_tower").advancements["flamethrower"]["continuous_dps"] = 1.0
			_tower(rules, &"arrow_tower").advancements["flamethrower"]["burn_dps"] = 0.000000001
		if branch in ["boulders", "freeze_runes"]:
			_tower(rules, &"rune_obelisk").evolutions["boulders"]["damage"] = 1
		for victim: StringName in [&"grunt", TROLL]:
			var combat := _start(rules, [String(victim)])
			var enemy: Dictionary = _find(combat, victim)
			var tower: Dictionary = _weapon(combat, &"arrow_tower" if branch in ["burn", "flamethrower"] else &"rune_obelisk", "fire_arrows" if branch == "burn" else branch)
			if branch == "burn":
				var config: Dictionary = combat.snapshot()["tower_types"]["arrow_tower"]["advancements"]["fire_arrows"].duplicate(true)
				config["burn_dps"] = 1.0
				combat._ignite(enemy, tower, config)
				tower["cooldown"] = 1000.0
			var hp: int = enemy["hp"]
			combat.advance(0.5)
			_check(enemy["hp"] == hp, "Sub-HP " + branch + " contact cannot round up each simulation tick")
			combat.advance(0.25)
			var boosted: bool = victim == TROLL and branch != "boulders"
			_check(hp - int(enemy["hp"]) == (1 if boosted else 0), "Vulnerability multiplies continuous/burn rate before fractional floor: " + branch)
			combat.advance(1.25)
			_check(hp - int(enemy["hp"]) == (3 if boosted else 2), "Two seconds integrate one nonphysical multiplier, not per-tick ceilings: " + branch)


func _test_stomp() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.1
	_enemy(rules, TROLL).tower_attack_interval = 0.0
	_enemy(rules, TROLL).tower_attack_kind = &""
	_enemy(rules, &"grunt").reroll_drop_chance = 1.0
	_enemy(rules, &"grunt").reroll_drop_amount = 5
	var combat := _start(rules, [String(TROLL)])
	var troll: Dictionary = _find(combat, TROLL)
	_check(float(troll["base_speed"]) < rules.enemy_speed * 0.15, "Shipped Troll walks extremely slowly")
	_check(combat.sandbox_spawn(0, &"grunt", 3), "Stomp fixture spawns actual other enemies")
	var nearby: Dictionary = combat.enemies[0][1]
	var survivor: Dictionary = combat.enemies[0][2]
	var outside: Dictionary = combat.enemies[0][3]
	var tower: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(13, 4))
	nearby["hp"] = 1
	outside["route"] = [Vector2i(1, 3), Vector2i(13, 3)]
	outside["pos"] = Vector2(1, 3)
	var hp: int = troll["hp"]
	var coins: Array[int] = combat.coins.duplicate()
	var shards: Array[int] = combat.reroll_currency.duplicate()
	var totals: Array[Dictionary] = combat.enemy_totals.duplicate(true)
	var drop_state: int = combat._drop_random.state
	combat.advance(2.399999)
	_check(troll["stomp_count"] == 1 and not combat.enemies[0].has(nearby) and combat.enemies[0].has(outside) and troll["hp"] == hp, "Walking Troll stomps nearby other enemies, not itself or outside-radius victims")
	_check(int(survivor["hp"]) == int(survivor["max_hp"]) - ceili(float(survivor["max_hp"]) * 0.08) and tower["kills"] == 0, "Stomp uses victim maximum HP and never credits a distant tower for its friendly kill")
	_check(combat.coins == coins and combat.reroll_currency == shards and combat.enemy_totals == totals and combat._drop_random.state == drop_state, "Friendly stomp death grants no bounty, Shards, tower kills or drop RNG")
	var still := _start(_rules(), [String(TROLL)])
	still.advance(5.0)
	_check(_find(still, TROLL)["stomp_count"] == 0, "A stationary Troll cannot produce walking stomps")
	rules = _rules()
	rules.enemy_speed = 0.1
	_enemy(rules, TROLL).tower_attack_interval = 1.0
	_enemy(rules, TROLL).tower_attack_cast_duration = 2.0
	_enemy(rules, TROLL).stomp_interval = 0.5
	combat = _start(rules, [String(TROLL)])
	_weapon(combat, &"arrow_tower")
	troll = _find(combat, TROLL)
	combat.advance(0.999999)
	var stomps: int = troll["stomp_count"]
	var progress: float = troll["progress"]
	combat.advance(1.0)
	_check(troll["stomp_count"] == stomps and is_equal_approx(float(troll["progress"]), progress), "Stationary club windup cannot keep stepping or stomping")


func _test_club_target_and_cancellation() -> void:
	var rules := _rules()
	_enemy(rules, TROLL).stomp_interval = 0.0
	var combat := _start(rules, [String(TROLL)])
	var farther: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(2, 1))
	var nearest: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(0, 1))
	var troll: Dictionary = _find(combat, TROLL)
	combat.advance(24.999999)
	_check(float(troll["tower_attack_remaining"]) > 1.24 and int(troll["tower_attack_target_id"]) == int(nearest["id"]) and float(nearest["stunned_remaining"]) == 0.0, "Twenty-five simulation seconds starts a real windup toward nearest tower, not first-built tower")
	combat.advance(1.25)
	_check(is_equal_approx(float(nearest["stunned_remaining"]), 30.0) and float(farther["stunned_remaining"]) == 0.0 and nearest["stun_source"] == "club", "Club resolves after windup into exactly thirty-second nearest-only stun")
	combat.advance(26.25)
	_check(int(nearest["stun_count"]) >= 2 and float(nearest["stunned_remaining"]) <= 30.0 and float(nearest["stunned_remaining"]) > 25.0, "Roughly twenty-five-second club cadence refreshes without stacking stun durations")
	for killed: bool in [true, false]:
		combat = _start(rules, [String(TROLL)])
		nearest = _weapon(combat, &"arrow_tower")
		troll = _find(combat, TROLL)
		combat.advance(24.999999)
		_check(float(troll["tower_attack_remaining"]) > 0.0, "Cancellation fixture reaches actual club cast")
		if killed:
			combat._hit(0, nearest, 0, int(troll["hp"]))
		else:
			troll["progress"] = float(troll["route"].size() - 1)
		combat.advance(1.3)
		_check(combat.enemies[0].is_empty() and nearest["stun_count"] == 0 and float(nearest["stunned_remaining"]) == 0.0, "Death or leak cancels pending club rather than stunning a tower after retirement")
	combat = _start(rules, [String(TROLL)])
	var first: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(0, 3))
	_weapon(combat, &"arrow_tower", "", Vector2i(0, 1))
	combat.advance(24.999999)
	_check(int(_find(combat, TROLL)["tower_attack_target_id"]) == int(first["id"]), "Equal-distance club targets use stable tower ID rather than array/cell ordering")


func _test_stunned_weapons() -> void:
	for profile: Array in [[&"arrow_tower", ""], [&"arrow_tower", "arrow_minigun"], [&"arrow_tower", "flamethrower"], [&"rune_obelisk", "boulders"], [&"rune_obelisk", "freeze_runes"], [&"rune_obelisk", "onyx_ring"]]:
		var rules := _rules()
		_enemy(rules, TROLL).stomp_interval = 0.0
		_tower(rules, &"arrow_tower").advancements["flamethrower"]["burn_dps"] = 0.000000001
		var combat := _start(rules, [String(TROLL)])
		var tower: Dictionary = _weapon(combat, profile[0], profile[1])
		combat.advance(26.249999)
		_check(tower["stun_count"] == 1 and float(tower["stunned_remaining"]) > 29.99, "Real club stuns weapon variant " + String(profile[1]))
		if profile[1] == "flamethrower":
			_check(is_zero_approx(float(tower["continuous_fire_time"])) and not tower["firing"], "Actual accepted club impact resets the Flamethrower's uninterrupted streak")
		_check(combat.sandbox_spawn(0, &"grunt", 1), "Stun test keeps an actual target after killing Troll")
		combat._hit(0, tower, combat._enemy_index(0, _find(combat, TROLL)["id"]), 100000000)
		var target: Dictionary = _find(combat, &"grunt")
		var hp: int = target["hp"]
		var shots: int = tower["shot"]
		var cooldown: float = tower["cooldown"]
		var fuel: float = tower["continuous_fire_time"]
		combat.advance(29.5)
		_check(target["hp"] == hp and tower["shot"] == shots and is_equal_approx(float(tower["cooldown"]), cooldown) and is_equal_approx(float(tower["continuous_fire_time"]), fuel) and not tower["firing"], "Stun blocks shots, pulses, continuous damage and attack clocks throughout simulation duration: " + String(profile[1]))
		combat.advance(0.6)
		_check(float(tower["stunned_remaining"]) == 0.0, "Coarse step expires stun at its internal simulation boundary")
		combat.advance(2.0)
		_check(int(target["hp"]) < hp, "Weapon actually resumes after simulation stun expiry: " + String(profile[1]))
	# Existing ignitions are independent of a source tower's ability to fire again.
	var rules := _rules()
	_enemy(rules, TROLL).stomp_interval = 0.0
	var combat := _start(rules, [String(TROLL)])
	var tower: Dictionary = _weapon(combat, &"arrow_tower", "fire_arrows")
	var target: Dictionary = _find(combat, TROLL)
	tower["cooldown"] = 1000.0
	combat.advance(24.899999)
	combat._ignite(target, tower, combat.snapshot()["tower_types"]["arrow_tower"]["advancements"]["fire_arrows"])
	combat.advance(1.35)
	_check(tower["stun_count"] == 1 and float(tower["stunned_remaining"]) > 29.99, "Existing-burn fixture reaches a real accepted club stun")
	var hp: int = target["hp"]
	combat.advance(1.0)
	_check(hp - int(target["hp"]) == 6 and tower["shot"] == 0, "Already-ignited nonphysical burn persists while stunned source cannot shoot")


func _test_stunned_support_and_economy() -> void:
	var rules := _rules()
	_quiet(rules)
	var combat := _start(rules, [String(TROLL)])
	var mine: Dictionary = _weapon(combat, &"gold_mine", "royal_mint", Vector2i(1, 1))
	var drums: Dictionary = _weapon(combat, &"war_drums", "", Vector2i(0, 1))
	var attacker: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(0, 0))
	var damage: int = attacker["damage"]
	var interval: float = attacker["interval"]
	mine["stunned_remaining"] = 30.0
	drums["stunned_remaining"] = 30.0
	var coins: int = combat.coins[0]
	combat.advance(10.0)
	_check(combat.coins[0] > coins and attacker["damage"] == damage and is_equal_approx(float(attacker["interval"]), interval) and int(attacker["shot"]) > 0, "Stunned economy still produces and stunned support still buffs actual attacking consumer")
	_check(combat.debug_set_round(60) and float(mine["stunned_remaining"]) == 0.0 and float(drums["stunned_remaining"]) == 0.0, "Debug/wave reset clears every accepted tower stun")


func _machine_rules() -> CombatRules:
	var rules := _rules()
	_quiet(rules)
	rules.enemy_speed = 1.0
	_enemy(rules, MACHINE).speed_multiplier = 1.0
	return rules


func _test_machine_terrain_and_jumps() -> void:
	var road := _start(_machine_rules(), [String(MACHINE)], _layout(false))
	var grass := _start(_machine_rules(), [String(MACHINE)], _layout(true))
	road.advance(2.0)
	grass.advance(2.0)
	var wheels: Dictionary = _find(road, MACHINE)
	var legs: Dictionary = _find(grass, MACHINE)
	_check(wheels["locomotion"] == "wheels" and legs["locomotion"] == "legs" and float(wheels["pos"].x) > float(legs["pos"].x), "Actual road exposure drives faster wheels while unpainted direct line deploys slower legs")
	_check(is_equal_approx(float(legs["pos"].y), 2.0) and float(legs["pos"].x) > 0.1, "Machine bypasses painted maze instead of following the ordinary vertical first segment")
	for mutate_during_flight: bool in [false, true]:
		var combat := _start(_machine_rules(), [String(MACHINE)], _layout(true))
		var blocker: Dictionary = _weapon(combat, &"war_drums", "", Vector2i(2, 2))
		var machine: Dictionary = _find(combat, MACHINE)
		var saw_charge: bool = false
		var saw_jump: bool = false
		var original_landing := Vector2i(-1, -1)
		var rebuilt: bool = false
		for tick: int in range(180):
			combat.advance(0.1)
			if machine["locomotion"] == "jump_charge":
				saw_charge = true
			if machine["locomotion"] == "jump":
				saw_jump = true
			if not rebuilt and machine["locomotion"] == ("jump" if mutate_during_flight else "jump_charge"):
				original_landing = Vector2i(Vector2(machine["jump_to"]).round())
				_check(original_landing.x > 2 and original_landing.y == 2, "Charge chooses nearest initially vacant forward landing cell")
				_weapon(combat, &"war_drums", "", original_landing)
				rebuilt = true
			if rebuilt and float(machine["pos"].x) > float(original_landing.x) and machine["locomotion"] not in ["jump", "jump_charge"]:
				break
		_check(saw_charge and saw_jump and rebuilt and float(machine["pos"].x) > float(original_landing.x), "Charged machine jump revalidates newly built landing obstruction during charge or flight")
		_check(combat.has_tower(0, Vector2i(2, 2)) and combat.has_tower(0, original_landing) and blocker["id"] == combat.towers[0][0]["id"], "Machine jumps preserve every blocking tower rather than destroying or overlapping one")
		_check(not combat.has_tower(0, Vector2i(Vector2(machine["pos"]).round())) and machine["pos"].y == 2.0 and machine["pos"].x < 14.0, "Landed machine remains vacant, direct and inside captured board")
		_check(absf(float(machine["pos"].x) - float(original_landing.x + 1)) < 0.1, "Revalidated jump lands at nearest vacant cell beyond the new blocker, not an arbitrary farther cell")
	var blocked_rules := _machine_rules()
	var blocked_definition: EnemyDefinition = _enemy(blocked_rules, MACHINE)
	blocked_definition.tower_attack_kind = &"cannon"
	blocked_definition.tower_attack_interval = 1.0
	blocked_definition.tower_attack_cast_duration = 0.2
	blocked_definition.summon_interval = 1.0
	blocked_definition.summon_cast_duration = 0.2
	blocked_definition.summon_min = 1
	blocked_definition.summon_max = 1
	blocked_definition.summon_limit = 2
	# Core API deliberately occupies even the base to exercise the otherwise
	# unreachable no-vacant-forward branch; normal consumers forbid base builds.
	var blocked := _start(blocked_rules, [String(MACHINE)], _layout(true, 6))
	for x: int in range(1, 6):
		_weapon(blocked, &"war_drums", "", Vector2i(x, 2))
	var waiting: Dictionary = _find(blocked, MACHINE)
	blocked.advance(30.0)
	_check(blocked.enemies[0].has(waiting) and float(waiting["pos"].x) < 1.0 and not blocked.has_tower(0, Vector2i(Vector2(waiting["pos"]).round())), "No vacant forward landing returns from a coarse advance and waits without overlap, leak or hang")
	_check(int(waiting["tower_attack_count"]) > 0 and int(waiting["summon_count"]) > 0 and int(blocked.towers[0][0]["stun_count"]) > 0, "No-empty-landing wait still advances real cannon and troop clocks")


func _test_machine_summons() -> void:
	var frequencies: Dictionary = {}
	for seed_value: int in range(64):
		var rules := _machine_rules()
		var definition: EnemyDefinition = _enemy(rules, MACHINE)
		definition.summon_interval = 3.0
		definition.grass_speed_multiplier = 1.0
		definition.summon_cast_duration = 0.2
		definition.summon_min = 4
		definition.summon_max = 4
		definition.summon_limit = 5
		var layout := _layout(true, 30)
		var combat := _start(rules, [String(MACHINE)], layout, seed_value)
		var machine: Dictionary = _find(combat, MACHINE)
		combat.advance(3.2)
		var children: int = 0
		for enemy: Dictionary in combat.enemies[0]:
			if enemy["summoner_id"] != machine["id"]:
				continue
			children += 1
			frequencies[enemy["type_id"]] = int(frequencies.get(enemy["type_id"], 0)) + 1
			_check(enemy["type_id"] in ["orcling", "grunt", "runner"] and enemy["age"] < 0.00001 and enemy["route"].back() == layout.base, "Weighted doors create real ordinary newborn troops, not bosses or pre-aged portal spawns")
			_check(layout.has_path(Vector2i(Vector2(enemy["pos"]).round())) and absf(float(enemy["pos"].y) - float(machine["pos"].y)) >= 0.5, "Off-road machine troops join a real current painted route rather than inheriting the vehicle line")
			for index: int in range(1, enemy["route"].size()):
				_check(Vector2i(enemy["route"][index]).distance_squared_to(enemy["route"][index - 1]) == 1, "Every captured troop route consists of valid adjacent remaining road cells")
		_check(children == 4, "One real door cast creates the configured exact child count")
		combat.advance(6.0)
		children = 0
		for enemy: Dictionary in combat.enemies[0]:
			if enemy["summoner_id"] == machine["id"]:
				children += 1
		_check(children == 5, "Repeated random doors respect the per-machine living child cap")
	_check(int(frequencies.get("orcling", 0)) > 180 and int(frequencies.get("grunt", 0)) > 0 and int(frequencies.get("runner", 0)) > 0, "Real weighted troop outcomes are mostly Orclings while both rarer types actually occur")
	# Weighted graph validation is resource-owned, including all edges rather than only fallback summon_type.
	var rules := _rules()
	var machine: EnemyDefinition = _enemy(rules, MACHINE)
	machine.summon_weights = PackedInt32Array([1])
	_check(not rules.catalog.validation_errors().is_empty(), "Mismatched weighted child pools are rejected")
	machine.summon_pool = PackedStringArray(["orc_war_machine"])
	machine.summon_weights = PackedInt32Array([1])
	_check(not rules.catalog.validation_errors().is_empty(), "Boss/self-summon weighted references are rejected before admission")


func _test_machine_cancellation() -> void:
	for action: String in ["cannon", "doors", "jump"]:
		for killed: bool in [true, false]:
			var rules := _machine_rules()
			var definition: EnemyDefinition = _enemy(rules, MACHINE)
			if action == "cannon":
				definition.tower_attack_kind = &"cannon"
				definition.tower_attack_interval = 0.1
				definition.tower_attack_cast_duration = 1.0
			elif action == "doors":
				definition.summon_interval = 0.1
				definition.summon_cast_duration = 1.0
			var combat := _start(rules, [String(MACHINE)], _layout(true))
			var tower: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(1, 2))
			var machine: Dictionary = _find(combat, MACHINE)
			for tick: int in range(60):
				combat.advance(0.1)
				if (action == "cannon" and float(machine["tower_attack_remaining"]) > 0.0) or (action == "doors" and float(machine["cast_remaining"]) > 0.0) or (action == "jump" and machine["locomotion"] == "jump_charge"):
					break
			_check(float(machine["tower_attack_remaining"]) > 0.0 or float(machine["cast_remaining"]) > 0.0 or machine["locomotion"] == "jump_charge", "Cancellation fixture reaches actual pending machine action: " + action)
			if killed:
				combat._hit(0, tower, combat._enemy_index(0, machine["id"]), 100000000)
			else:
				machine["progress"] = 1.0
				machine["pos"] = Vector2(13, 2)
			combat.advance(5.0)
			_check(combat.enemies[0].is_empty() and int(tower["stun_count"]) == 0 and int(machine["summon_count"]) == 0, "Retired machine cannot finish pending cannon, door cast or jump after death/leak: " + action)


func _test_mixed_route_targeting() -> void:
	var rules := _machine_rules()
	var definition: EnemyDefinition = _enemy(rules, MACHINE)
	definition.summon_interval = 1.0
	definition.summon_pool = PackedStringArray(["orcling"])
	definition.summon_weights = PackedInt32Array([1])
	definition.summon_min = 1
	definition.summon_max = 1
	_tower(rules, &"arrow_tower").range_cells = 100.0
	var combat := _start(rules, [String(MACHINE)], _layout(true))
	var machine: Dictionary = _find(combat, MACHINE)
	machine["progress"] = 0.75
	machine["pos"] = combat._position(machine["route"], 0.75)
	combat._finish_summon(0, machine, combat._enemy_types[String(MACHINE)])
	_check(combat.sandbox_spawn(0, &"grunt", 1), "Mixed-route target fixture adds ordinary full-maze enemy")
	var child: Dictionary = {}
	for enemy: Dictionary in combat.enemies[0]:
		if int(enemy["summoner_id"]) == int(machine["id"]):
			child = enemy
	_check(not child.is_empty() and child["route"].size() > 2 and child["route"].size() < _layout(true).route.size(), "Real machine child owns a shortened valid painted remainder")
	var tower: Dictionary = _weapon(combat, &"arrow_tower")
	var target: int = combat._target(0, tower, 100.0, MatchCombat.TargetMode.FURTHEST)
	_check(target >= 0 and combat.enemies[0][target]["id"] == machine["id"], "Furthest compares remaining world distance, not direct normalized progress against child/full-maze progress")
	machine["progress"] = 0.25
	machine["pos"] = combat._position(machine["route"], 0.25)
	target = combat._target(0, tower, 100.0, MatchCombat.TargetMode.FURTHEST)
	_check(target >= 0 and combat.enemies[0][target]["id"] == child["id"], "Shortened joined-route troop outranks farther machine despite its local progress starting at zero")
	target = combat._target(0, tower, 100.0, MatchCombat.TargetMode.LAST)
	_check(target >= 0 and combat.enemies[0][target]["type_id"] == "grunt", "Last uses the same comparable remaining-distance ordering in reverse across all route kinds")


func _simulation_signature(combat: MatchCombat) -> Dictionary:
	var result: Dictionary = {"coins": combat.coins.duplicate(), "health": combat.base_health.duplicate(), "enemies": [], "towers": []}
	for enemy: Dictionary in combat.enemies[0]:
		result["enemies"].append({"id": enemy["id"], "type": enemy["type_id"], "hp": enemy["hp"], "pos": Vector2(enemy["pos"]).snapped(Vector2(0.00001, 0.00001)), "stomps": enemy["stomp_count"], "attacks": enemy["tower_attack_count"], "summons": enemy["summon_count"], "locomotion": enemy["locomotion"]})
	for tower: Dictionary in combat.towers[0]:
		result["towers"].append({"shot": tower["shot"], "stuns": tower["stun_count"], "remaining": snappedf(float(tower["stunned_remaining"]), 0.00001)})
	return result


func _test_simulation_partition() -> void:
	for type_id: StringName in [TROLL, MACHINE]:
		var outcomes: Array[Dictionary] = []
		for step: float in [0.05, 0.5, 53.0]:
			var rules := _rules()
			rules.enemy_speed = 0.1
			if type_id == MACHINE:
				_enemy(rules, MACHINE).speed_multiplier = 10.0
			var combat := _start(rules, [String(type_id)], _layout(true, 30))
			_weapon(combat, &"war_drums", "", Vector2i(1, 2))
			for tick: int in range(roundi(53.0 / step)):
				combat.advance(step)
			outcomes.append(_simulation_signature(combat))
		_check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2], "Coarse/fine simulation partitions agree on boss movement, attacks, summons, stuns and economy: " + String(type_id))


func _test_sandbox_consumer() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.1
	var sandbox := SandboxController.new()
	sandbox.configure(rules.catalog, rules)
	var streams: Array[RandomNumberGenerator] = [sandbox.combat._random, sandbox.combat._wave_random, sandbox.combat._timing_random, sandbox.combat._group_random, sandbox.combat._roll_random, sandbox.combat._drop_random]
	for index: int in range(streams.size()):
		streams[index].seed = 1471 + index * 97
	for x: int in range(1, 13):
		_check(sandbox.edit_path(Vector2i(x, 4), true), "Real Sandbox accepts connected path")
	_check(sandbox.build(Vector2i(1, 3), &"arrow_tower"), "Real Sandbox builds a legal club target")
	sandbox.set_active(true)
	for type_id: StringName in [TROLL, MACHINE]:
		_check(sandbox.spawn(type_id, 1) and sandbox.state["enemies"][0][0]["type_id"] == String(type_id), "Real Sandbox consumer exposes and spawns late boss " + String(type_id))
		sandbox.set_paused(false)
		var frozen: Dictionary = sandbox.combat.snapshot()
		sandbox.set_paused(true)
		sandbox.advance(100.0)
		_check(sandbox.combat.snapshot() == frozen, "Sandbox pause freezes boss movement and all ability clocks")
		sandbox.set_paused(false)
		sandbox.speed = 4.0
		sandbox.advance(6.5625)
		if type_id == TROLL:
			_check(int(sandbox.state["towers"][0][0]["stun_count"]) == 1 and float(sandbox.state["towers"][0][0]["stunned_remaining"]) > 29.9, "Sandbox 4x playback feeds one authoritative thirty-second club stun, not wall time")
		_check(sandbox.stop() and sandbox.combat.enemies[0].is_empty() and float(sandbox.state["towers"][0][0]["stunned_remaining"]) == 0.0, "Sandbox Stop clears enemies, casts, jumps and tower stun while retaining build")
		_check(sandbox.restart() and sandbox.combat.enemies[0].size() == 1 and sandbox.combat.enemies[0][0]["type_id"] == String(type_id), "Sandbox replay reconstructs selected boss through real combat owner")
		sandbox.stop()
	sandbox.reset_build()
	_check(sandbox.combat.towers[0].is_empty() and sandbox.combat.enemies[0].is_empty() and sandbox.layout.is_ready(), "Sandbox Reset Build clears boss/stun state without discarding route")
