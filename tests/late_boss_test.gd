extends SceneTree

const TROLL := &"troll"
const MACHINE := &"orc_war_machine"
const MANCER := &"necorcmancer_mancer"

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_encounters()
	_test_send_atomicity()
	_test_three_bosses()
	_test_damage_types()
	_test_machine_elements()
	_test_fractional_damage()
	_test_stomp()
	_test_club_target_and_cancellation()
	_test_stunned_weapons()
	_test_stunned_support_and_economy()
	_test_machine_route_and_jumps()
	_test_jump_weights_and_endpoint()
	_test_cannon_targets()
	_test_machine_summons()
	_test_machine_cancellation()
	_test_mixed_route_targeting()
	_test_simulation_partition()
	_test_sandbox_consumer()
	if failures == 0:
		print("PASS: late bosses together, captured-route weighted jumps, distinct global cannon targets, suspended tower roles, elemental damage, bounded troops and partition/reset agreement")
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
		definition.jump_interval = 0.0
		definition.jump_weights = PackedInt32Array()


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
		var first: String = "boulders" if branch == "freeze_runes" else ("bounty_board" if branch in ["stronger_mark", "income_aura"] else branch)
		_check(combat.upgrade_tower(0, tower["id"], first), "Fixture buys real tower evolution")
		if branch != first:
			_check(combat.upgrade_tower(0, tower["id"], branch), "Fixture buys real tower follow-up")
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


func _test_three_bosses() -> void:
	var rules := _rules(false)
	for id: StringName in [MANCER, TROLL, MACHINE]:
		var definition: EnemyDefinition = _enemy(rules, id)
		definition.boss_spawn_chance = 1.0
		definition.boss_spawn_chance_growth = 0.0
		definition.boss_spawn_chance_cap = 1.0
	for seed_value: int in range(12):
		var combat := _combat(rules, seed_value)
		_check(combat.debug_set_round(200) and combat.start_wave(_routing(_layout())), "Late normal wave admits simultaneous boss reservations")
		var consumed: int = 0
		var definitions: Dictionary = combat.snapshot()["enemy_types"]
		for group: Dictionary in combat.wave_groups:
			consumed += int(definitions[group["type_id"]]["spawn_weight"])
		_check(consumed == rules.wave_weight + 199 * rules.wave_weight_growth, "Three simultaneous bosses still consume the exact ordinary wave budget")
		for id: StringName in [MANCER, TROLL, MACHINE]:
			_check(combat.wave_roster.count(String(id)) == 1, "One late boss never excludes another: " + String(id))
	rules = _rules()
	rules.enemy_speed = 0.1
	var combat := _start(rules, [String(TROLL), String(MACHINE), String(MANCER)], _layout(true, 40))
	var troll: Dictionary = _find(combat, TROLL)
	var machine: Dictionary = _find(combat, MACHINE)
	var mancer: Dictionary = _find(combat, MANCER)
	machine["progress"] = 6.0
	machine["pos"] = combat._position(machine["route"], 6.0)
	mancer["progress"] = 20.0
	mancer["pos"] = combat._position(mancer["route"], 20.0)
	var nearest: Dictionary = _weapon(combat, &"war_drums", "", Vector2i(0, 3))
	var remote: Dictionary = _weapon(combat, &"gold_mine", "", Vector2i(39, 4))
	combat.advance(31.0)
	_check(combat.enemies[0].has(troll) and combat.enemies[0].has(machine) and combat.enemies[0].has(mancer), "All three bosses remain simultaneously live under their actual mechanics")
	_check(int(troll["stomp_count"]) > 0 and int(troll["tower_attack_count"]) > 0 and int(nearest["stun_count"]) > 0, "Coexisting Troll still walks, stomps and clubs")
	_check(int(machine["jump_count"]) > 0 and int(machine["tower_attack_count"]) > 0 and int(machine["summon_count"]) > 0 and int(remote["stun_count"]) > 0, "Coexisting Machine still jumps, fires global cannons and deploys troops")
	_check(int(mancer["summon_count"]) > 0 and not _find(combat, &"necorcmancer").is_empty() and not _find(combat, &"skeleorc").is_empty(), "Coexisting Mancer retains its nested real NecOrcmancer and SkeleOrc rituals")


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


func _test_machine_elements() -> void:
	for kind: StringName in [&"physical", &"fire", &"magic", &"lightning", &"explosive", &"ice"]:
		for composed: bool in [false, true]:
			var rules := _rules()
			_quiet(rules)
			_tower(rules, &"arrow_tower").damage_type = kind
			_tower(rules, &"arrow_tower").damage = 10
			if composed:
				_enemy(rules, MACHINE).nonphysical_damage_multiplier = 1.5
			var combat := _start(rules, [String(MACHINE)])
			var machine: Dictionary = _find(combat, MACHINE)
			var tower: Dictionary = _weapon(combat, &"arrow_tower")
			if composed:
				_weapon(combat, &"gold_mine", "bounty_board", Vector2i(1, 1))
				combat._update_bounties(0)
			# Mutating local definitions after admission cannot change captured hits.
			_enemy(rules, MACHINE).fire_damage_multiplier = 7.0
			_enemy(rules, MACHINE).lightning_damage_multiplier = 7.0
			var hp: int = machine["hp"]
			var multiplier: float = 1.2 if kind == &"fire" else (0.9 if kind == &"lightning" else 1.0)
			if composed:
				multiplier *= 1.2 * (1.0 if kind == &"physical" else 1.5)
			combat._hit(0, tower, 0, 10, false, kind)
			_check(hp - int(machine["hp"]) == ceili(10.0 * multiplier - 0.000000001), "Captured Machine element, generic vulnerability and bounty compose exactly once: " + String(kind))
	for profile: Array in [[&"lightning", ""], [&"arrow_tower", "molotov"], [&"arrow_tower", "aom"], [&"rune_obelisk", "onyx_ring"]]:
		var losses: Array[int] = []
		for victim: StringName in [&"grunt", MACHINE]:
			var rules := _rules()
			_quiet(rules)
			_tower(rules, profile[0]).damage = 10
			var combat := _start(rules, [String(victim)])
			var target: Dictionary = _find(combat, victim)
			var tower: Dictionary = _weapon(combat, profile[0], profile[1])
			var hp: int = target["hp"]
			combat.advance(float(tower["interval"]) if profile[1] == "onyx_ring" else 0.001)
			losses.append(hp - int(target["hp"]))
		var multiplier: float = 0.9 if profile[0] == &"lightning" else (1.2 if profile[1] == "molotov" else 1.0)
		_check(losses[0] > 0 and losses[1] == ceili(losses[0] * multiplier - 0.000000001), "Real weapon dispatch applies Machine's intended element: " + String(profile[0]) + "/" + String(profile[1]))


func _test_fractional_damage() -> void:
	for branch: String in ["burn", "boulders", "freeze_runes", "flamethrower"]:
		var rules := _rules()
		_quiet(rules)
		if branch == "flamethrower":
			_tower(rules, &"arrow_tower").advancements["flamethrower"]["continuous_dps"] = 1.0
			_tower(rules, &"arrow_tower").advancements["flamethrower"]["burn_dps"] = 0.000000001
		if branch in ["boulders", "freeze_runes"]:
			_tower(rules, &"rune_obelisk").evolutions["boulders"]["damage"] = 1
		for victim: StringName in [&"grunt", TROLL, MACHINE]:
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
			combat.advance(0.5)
			var rate: float = 1.5 if boosted else (1.2 if victim == MACHINE and branch in ["burn", "flamethrower"] else 1.0)
			_check(hp - int(enemy["hp"]) == floori(2.5 * rate + 0.000000001), "Fractional stream/burn keeps Machine fire weakness without per-tick rounding: " + branch)


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
	_check(float(troll["tower_attack_remaining"]) > 1.24 and troll["tower_attack_target_ids"] == [nearest["id"]] and float(nearest["stunned_remaining"]) == 0.0, "Twenty-five simulation seconds starts a real windup toward nearest tower, not first-built tower")
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
	_check(_find(combat, TROLL)["tower_attack_target_ids"] == [first["id"]], "Equal-distance club targets use stable tower ID rather than array/cell ordering")


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


func _stun_rules() -> CombatRules:
	var rules := _rules()
	_quiet(rules)
	var troll: EnemyDefinition = _enemy(rules, TROLL)
	troll.tower_attack_kind = &"club"
	troll.tower_attack_interval = 100.0
	troll.tower_attack_cast_duration = 0.1
	troll.tower_stun_duration = 2.0
	return rules


func _club_impact(combat: MatchCombat, target: Dictionary) -> void:
	var troll: Dictionary = _find(combat, TROLL)
	var count: int = target["stun_count"]
	troll["next_tower_attack"] = float(troll["age"]) + 0.1
	combat.advance(0.2)
	_check(int(target["stun_count"]) == count + 1 and is_equal_approx(float(target["stunned_remaining"]), 2.0), "Actual nearest-tower club impact starts an exact fixture stun")


func _kill_grunt_payout(combat: MatchCombat, attacker: Dictionary) -> int:
	_check(combat.sandbox_spawn(0, &"grunt", 1), "Income fixture creates an actual bounty-bearing victim")
	var coins: int = combat.coins[0]
	combat._hit(0, attacker, combat._enemy_index(0, _find(combat, &"grunt")["id"]), 100000000)
	return combat.coins[0] - coins


func _test_stunned_support_and_economy() -> void:
	for branch: String in ["", "forge", "command_banner"]:
		var combat := _start(_stun_rules(), [String(TROLL)])
		var support: Dictionary = _weapon(combat, &"war_drums", branch)
		var attacker: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(1, 0))
		var damage: int = attacker["damage"]
		var interval: float = attacker["interval"]
		_check(float(attacker["support_damage_bonus"]) > 0.0 or float(attacker["support_speed_bonus"]) > 0.0, "Active support has a real consumer before stun: " + branch)
		_club_impact(combat, support)
		_check(float(attacker["support_damage_bonus"]) == 0.0 and float(attacker["support_speed_bonus"]) == 0.0 and attacker["damage"] == attacker["base_damage"] and is_equal_approx(float(attacker["interval"]), float(attacker["base_interval"])), "Club immediately removes every emitted support component: " + branch)
		combat.advance(1.999)
		_check(float(support["stunned_remaining"]) > 0.0 and float(attacker["support_damage_bonus"]) == 0.0 and float(attacker["support_speed_bonus"]) == 0.0, "Support stays absent until the exact expiry boundary")
		combat.advance(0.001)
		_check(float(support["stunned_remaining"]) == 0.0 and attacker["damage"] == damage and is_equal_approx(float(attacker["interval"]), interval), "Support restores once at exact stun expiry without a build or upgrade")
	var combat := _start(_stun_rules(), [String(TROLL)])
	var strong: Dictionary = _weapon(combat, &"war_drums")
	_check(combat.upgrade_tower(0, strong["id"], "damage") and combat.upgrade_tower(0, strong["id"], "speed"), "Duplicate support fixture upgrades strongest source")
	var weak: Dictionary = _weapon(combat, &"war_drums", "", Vector2i(1, 1))
	var attacker: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(1, 0))
	_club_impact(combat, strong)
	_check(is_equal_approx(float(attacker["support_damage_bonus"]), float(weak["behavior_config"]["damage_bonus"])) and is_equal_approx(float(attacker["support_speed_bonus"]), float(weak["behavior_config"]["attack_speed_bonus"])), "Stunning strongest duplicate preserves the weaker unstunned source rather than dropping or summing its group")
	combat.advance(2.0)
	_check(is_equal_approx(float(attacker["support_damage_bonus"]), float(strong["behavior_config"]["damage_bonus"])) and is_equal_approx(float(attacker["support_speed_bonus"]), float(strong["behavior_config"]["attack_speed_bonus"])), "Restored strongest duplicate replaces weaker values without compounding")

	combat = _start(_stun_rules(), [String(TROLL)])
	var mine: Dictionary = _weapon(combat, &"gold_mine", "royal_mint")
	_club_impact(combat, mine)
	var coins: int = combat.coins[0]
	var clock: float = mine["production_elapsed"]
	var period: float = mine["behavior_config"]["periodic_interval"]
	combat.advance(1.999)
	_check(combat.coins[0] == coins and is_equal_approx(float(mine["production_elapsed"]), clock), "Stunned Mint freezes partial periodic production instead of paying or accumulating catch-up")
	combat.advance(0.001)
	_check(float(mine["stunned_remaining"]) == 0.0 and combat.coins[0] == coins and is_equal_approx(float(mine["production_elapsed"]), clock), "Exact expiry itself adds no stunned interval to the Mint clock")
	combat.advance(period - clock - 0.001)
	_check(combat.coins[0] == coins, "Mint cannot pay early after a frozen production clock resumes")
	combat.advance(0.001)
	_check(combat.coins[0] == coins + int(mine["behavior_config"]["periodic_income"]) and is_zero_approx(float(mine["production_elapsed"])), "Mint resumes its preserved partial interval with exactly one payout, never backpay")

	combat = _start(_stun_rules(), [String(TROLL)])
	var board: Dictionary = _weapon(combat, &"gold_mine", "bounty_board")
	attacker = _weapon(combat, &"arrow_tower", "", Vector2i(1, 0))
	attacker["cooldown"] = 1000.0
	var target: Dictionary = _find(combat, TROLL)
	combat._update_bounties(0)
	_check(int(target["bounty_tower_id"]) == int(board["id"]) and float(target["bounty_damage_bonus"]) > 0.0 and float(target["bounty_income_bonus"]) > 0.0, "Active Board owns a real damage-and-income mark")
	_club_impact(combat, board)
	_check(int(target["bounty_tower_id"]) == -1 and float(target["bounty_damage_bonus"]) == 0.0 and float(target["bounty_income_bonus"]) == 0.0, "Stun immediately removes Board ownership and both emitted mark effects")
	var hp: int = target["hp"]
	combat._hit(0, attacker, combat._enemy_index(0, target["id"]), 20, false, &"physical")
	_check(hp - int(target["hp"]) == 20, "A stunned Board cannot amplify real incoming damage")
	combat.advance(1.999)
	_check(int(target["bounty_tower_id"]) == -1, "Stunned Board cannot reacquire a mark before expiry")
	combat.advance(0.001)
	_check(int(target["bounty_tower_id"]) == int(board["id"]), "Board naturally reacquires an eligible target at exact expiry")
	hp = target["hp"]
	combat._hit(0, attacker, combat._enemy_index(0, target["id"]), 20, false, &"physical")
	_check(hp - int(target["hp"]) == 24, "Restored Board applies its mark exactly once")
	_club_impact(combat, board)
	coins = combat.coins[0]
	var normal: int = combat.snapshot()["enemy_types"][String(TROLL)]["kill_bounty"]
	if normal < 0:
		normal = int(combat.snapshot()["rules"]["kill_bounty"])
	combat._hit(0, attacker, combat._enemy_index(0, target["id"]), 100000000)
	_check(combat.coins[0] - coins == normal, "Killing a formerly marked victim while Board is stunned pays no suspended mark income")

	combat = _start(_stun_rules(), [String(TROLL)])
	var aura: Dictionary = _weapon(combat, &"gold_mine", "income_aura")
	attacker = _weapon(combat, &"arrow_tower", "", Vector2i(1, 0))
	attacker["cooldown"] = 1000.0
	normal = combat.snapshot()["enemy_types"]["grunt"]["kill_bounty"]
	if normal < 0:
		normal = int(combat.snapshot()["rules"]["kill_bounty"])
	var bonus: float = aura["behavior_config"]["kill_income_bonus"]
	_check(_kill_grunt_payout(combat, attacker) == ceili(normal * (1.0 + bonus)), "Active income aura increases a real killer-location payout")
	_club_impact(combat, aura)
	_check(_kill_grunt_payout(combat, attacker) == normal and combat._income_aura_bonus(0, attacker) == 0.0, "Stunned income aura grants neither cached nor freshly queried bonus Coins")
	combat.advance(2.0)
	_check(_kill_grunt_payout(combat, attacker) == ceili(normal * (1.0 + bonus)), "Income aura restores naturally at exact expiry")

	var rules := _rules(false)
	_quiet(rules)
	for definition: EnemyDefinition in rules.catalog.enemies:
		definition.group_weights = PackedInt32Array([1])
	combat = _combat(rules)
	mine = _weapon(combat, &"gold_mine")
	var active_mine: Dictionary = _weapon(combat, &"gold_mine", "", Vector2i(1, 1))
	_check(combat.start_wave(_routing(_layout())), "Clear-income fixture starts actual normal combat")
	combat.advance(0.001)
	mine["stunned_remaining"] = 2.0
	for slot: int in range(2):
		for enemy: Dictionary in combat.enemies[slot]:
			enemy["progress"] = float(enemy["route"].size() - 1)
	coins = combat.coins[0]
	combat.advance(0.001)
	_check(combat.phase == MatchCombat.Phase.PLANNING and float(mine["stunned_remaining"]) == 0.0, "Actual wave clear resets residual stun status")
	_check(combat.coins[0] - coins == rules.wave_reward + rules.wave_reward_growth + int(active_mine["behavior_config"]["clear_income"]), "Clear rewards exclude a still-stunned Mine even though wave clear resets its stun afterward")
	_check(combat.debug_set_round(60) and float(mine["stunned_remaining"]) == 0.0, "Debug reset preserves cleared tower status without a reward")


func _machine_rules() -> CombatRules:
	var rules := _rules()
	var weights: PackedInt32Array = _enemy(rules, MACHINE).jump_weights.duplicate()
	_quiet(rules)
	rules.enemy_speed = 1.0
	_enemy(rules, MACHINE).speed_multiplier = 1.0
	_enemy(rules, MACHINE).jump_interval = 18.0
	_enemy(rules, MACHINE).jump_weights = weights
	return rules


func _branched_layout() -> PathLayout:
	var result := _layout(true)
	result.place(Vector2i(0, 3))
	result.place(Vector2i(13, 3))
	for x: int in range(14):
		result.place(Vector2i(x, 4))
	return result


func _test_machine_route_and_jumps() -> void:
	var rules := _machine_rules()
	rules.enemy_speed = 0.5
	var definition: EnemyDefinition = _enemy(rules, MACHINE)
	definition.jump_interval = 2.0
	definition.jump_weights = PackedInt32Array([0, 0, 1, 0])
	definition.jump_deploy_duration = 0.2
	definition.jump_charge_duration = 0.3
	definition.jump_duration = 0.4
	definition.jump_land_duration = 0.2
	var layout := _layout(true)
	var combat := _start(rules, [String(MACHINE)], layout)
	var machine: Dictionary = _find(combat, MACHINE)
	var captured: Array = machine["route"].duplicate()
	_check(captured == layout.route and captured.size() > 2, "Machine captures the complete winding painted route, not the portal/base chord")
	layout.clear()
	combat.advance(0.499999)
	_check(machine["locomotion"] == "wheels" and is_equal_approx(float(machine["progress"]), 0.25) and Vector2(machine["pos"]).is_equal_approx(Vector2(0, 1.75)), "Wheels advance ordinary route-distance cells around the maze after source layout mutation")
	combat.advance(1.5)
	_check(machine["locomotion"] == "jump_deploy" and is_equal_approx(float(machine["progress"]), 1.0) and int(machine["jump_count"]) == 0, "Periodic deadline deploys legs on the captured path without a tower obstruction or premature takeoff")
	var origin: Vector2 = machine["pos"]
	combat.advance(0.2)
	_check(machine["locomotion"] == "jump_charge" and Vector2(machine["pos"]).is_equal_approx(origin), "Deployed legs crouch for the configured charge without walking")
	combat.advance(0.3)
	_check(machine["locomotion"] == "jump" and int(machine["jump_count"]) == 1 and int(machine["jump_distance"]) == 4 and is_equal_approx(float(machine["jump_target_progress"]), 5.0), "Takeoff accepts the rolled four route cells, not straight-line distance")
	_check(Vector2(machine["jump_from"]).is_equal_approx(origin) and Vector2(machine["jump_to"]).is_equal_approx(combat._position(captured, 5.0)) and origin.distance_to(machine["jump_to"]) < 4.0, "Captured flight endpoints straddle a painted corner while preserving route-cell landing distance")
	combat.advance(0.2)
	_check(machine["locomotion"] == "jump" and is_equal_approx(float(machine["progress"]), 3.0) and Vector2(machine["pos"]).is_equal_approx(combat._position(captured, 3.0)), "Airborne logical progress remains on its captured route rather than cutting the corner")
	combat.advance(0.2)
	_check(machine["locomotion"] == "jump_land" and Vector2(machine["pos"]).is_equal_approx(machine["jump_to"]) and is_equal_approx(float(machine["progress"]), 5.0), "Flight reaches exact route landing and retains a separate landing phase")
	combat.advance(0.2)
	_check(machine["locomotion"] == "wheels" and int(machine["jump_count"]) == 1 and machine["route"] == captured, "Landing retracts legs back to wheels without replacing the captured route")
	combat.advance(0.5)
	_check(float(machine["progress"]) > 5.0 and machine["locomotion"] == "wheels", "Wheels naturally resume ordinary route motion after landing")

	rules = _machine_rules()
	definition = _enemy(rules, MACHINE)
	definition.jump_interval = 1.0
	definition.jump_deploy_duration = 0.1
	definition.jump_charge_duration = 0.1
	definition.jump_duration = 0.2
	definition.jump_land_duration = 0.1
	combat = _start(rules, [String(MACHINE), String(MACHINE)], _branched_layout())
	var first: Dictionary = combat.enemies[0][0]
	var second: Dictionary = combat.enemies[0][1]
	_check(first["route"] != second["route"] and first["route"].size() == second["route"].size(), "Machines receive alternating equally short captured branches like ordinary enemies")
	combat.advance(1.3)
	for enemy: Dictionary in [first, second]:
		_check(int(enemy["jump_count"]) == 1 and Vector2(enemy["pos"]).is_equal_approx(combat._position(enemy["route"], enemy["progress"])) and Vector2(enemy["jump_to"]).is_equal_approx(combat._position(enemy["route"], enemy["jump_target_progress"])), "Each jumping machine retains its own accepted branch and route-consistent position")


func _jump_rules() -> CombatRules:
	var rules := _machine_rules()
	rules.enemy_speed = 0.0
	var definition: EnemyDefinition = _enemy(rules, MACHINE)
	definition.jump_interval = 1.0
	definition.jump_deploy_duration = 0.1
	definition.jump_charge_duration = 0.1
	definition.jump_duration = 0.2
	definition.jump_land_duration = 0.1
	return rules


func _test_jump_weights_and_endpoint() -> void:
	for length: int in range(2, 6):
		var rules := _jump_rules()
		var weights := PackedInt32Array([0, 0, 0, 0])
		weights[length - 2] = 1
		_enemy(rules, MACHINE).jump_weights = weights
		var combat := _start(rules, [String(MACHINE)], _layout(true))
		var machine: Dictionary = _find(combat, MACHINE)
		combat.advance(1.399999)
		_check(int(machine["jump_distance"]) == length and int(machine["jump_count"]) == 1 and is_equal_approx(float(machine["progress"]), float(length)) and machine["locomotion"] == "jump_land", "Every configured jump length reaches its exact captured route cell: " + str(length))
	var frequencies: Array[int] = [0, 0, 0, 0]
	for seed_value: int in range(256):
		var combat := _start(_jump_rules(), [String(MACHINE)], _layout(true), seed_value)
		combat.advance(1.199999)
		var length: int = _find(combat, MACHINE)["jump_distance"]
		_check(length >= 2 and length <= 5, "Shipped weighted jump never creates an unsupported distance")
		if length >= 2 and length <= 5:
			frequencies[length - 2] += 1
	_check(frequencies[0] > frequencies[1] and frequencies[1] > frequencies[2] and frequencies[2] > frequencies[3] and frequencies[3] > 0, "Seeded live jumps exercise all 45/35/15/5 outcomes with progressively rarer long tails")
	for index: int in range(4):
		_check(absf(float(frequencies[index]) / 256.0 - [0.45, 0.35, 0.15, 0.05][index]) < 0.1, "Real jump distribution retains authored weight share: " + str(index + 2))
	for remaining: float in [1.5, 2.0, 2.5, 3.5]:
		var combat := _start(_jump_rules(), [String(MACHINE)], _layout(true))
		var machine: Dictionary = _find(combat, MACHINE)
		var last: float = machine["route"].size() - 1
		machine["progress"] = last - remaining
		machine["pos"] = combat._position(machine["route"], machine["progress"])
		combat.advance(1.399999)
		if remaining < 2.0:
			_check(int(machine["jump_count"]) == 0 and machine["locomotion"] == "wheels" and is_equal_approx(float(machine["progress"]), last - remaining), "Less than two remaining cells cannot manufacture a short jump or leak")
		else:
			_check(int(machine["jump_count"]) == 1 and int(machine["jump_distance"]) >= 2 and float(machine["jump_distance"]) <= remaining and float(machine["progress"]) <= last and machine["locomotion"] == "jump_land", "Near-base weights only admit full jump lengths that fit, never overshooting or shortening")
			_check(Vector2(machine["pos"]).is_equal_approx(combat._position(machine["route"], machine["progress"])), "Near-base landing remains on its captured route")
			if remaining == 2.0:
				_check(combat.enemies[0].has(machine), "Landing at the base keeps its final landing phase before retirement")
				combat.advance(0.1)
				_check(not combat.enemies[0].has(machine) and combat.phase == MatchCombat.Phase.PLANNING, "Endpoint landing retires safely when its landing phase completes")
	var rules := _jump_rules()
	_enemy(rules, MACHINE).jump_weights = PackedInt32Array([0, 0, 0, 0])
	_check(not rules.catalog.validation_errors().is_empty(), "Enabled jumps require a positive weighted distance")
	_enemy(rules, MACHINE).jump_weights = PackedInt32Array([45, 35, 15])
	_check(not rules.catalog.validation_errors().is_empty(), "Jump weight validation rejects missing route-cell outcomes")


func _cannon_rules() -> CombatRules:
	var rules := _rules()
	_quiet(rules)
	var machine: EnemyDefinition = _enemy(rules, MACHINE)
	machine.tower_attack_kind = &"cannon"
	machine.tower_attack_interval = 12.0
	machine.tower_attack_cast_duration = 1.4
	machine.tower_attack_range = 0.01
	return rules


func _cannon_windup(combat: MatchCombat) -> Dictionary:
	var machine: Dictionary = _find(combat, MACHINE)
	machine["next_tower_attack"] = float(machine["age"]) + 0.1
	combat.advance(0.1)
	return machine


func _test_cannon_targets() -> void:
	for count: int in range(3):
		var combat := _start(_cannon_rules(), [String(MACHINE)])
		for index: int in range(count):
			_weapon(combat, &"war_drums", "", Vector2i(12 + index, 4))
		_check(combat.build(1, Vector2i(13, 4), &"war_drums", MatchCombat.TargetMode.FURTHEST), "Cannon fixture creates an opposing-board non-target")
		var machine: Dictionary = _cannon_windup(combat)
		_check(machine["tower_attack_target_ids"].size() == count and machine["tower_attack_aims"].size() == count and int(machine["tower_attack_count"]) == (0 if count == 0 else 1), "Cannon captures exactly available zero/one/two owned targets without duplication or fallback")
		combat.advance(1.4)
		for tower: Dictionary in combat.towers[0]:
			_check(int(tower["stun_count"]) == 1 and is_equal_approx(float(tower["stunned_remaining"]), 8.0) and tower["stun_source"] == "cannon", "Every available distinct global cannon target receives one exact eight-second impact")
		_check(combat.towers[1][0]["stun_count"] == 0, "Cannon never selects a tower from the other board")
	var pairs: Dictionary = {}
	var frequencies: Dictionary = {}
	var replay: Array = []
	for seed_value: int in range(64):
		var combat := _start(_cannon_rules(), [String(MACHINE)], _layout(), seed_value)
		for cell: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(12, 4), Vector2i(13, 4)]:
			_weapon(combat, &"war_drums", "", cell)
		var machine: Dictionary = _cannon_windup(combat)
		var targets: Array = machine["tower_attack_target_ids"].duplicate()
		_check(targets.size() == 2 and targets[0] != targets[1], "Each seeded volley chooses two distinct targets from the whole board")
		for index: int in range(targets.size()):
			var tower: Dictionary = combat._find_tower(0, targets[index])
			frequencies[targets[index]] = int(frequencies.get(targets[index], 0)) + 1
			_check(Vector2(machine["tower_attack_aims"][index]).is_equal_approx(Vector2(tower["cell"])), "Each accepted cannon aim belongs to its paired target ID")
		targets.sort()
		pairs[str(targets)] = true
		if seed_value == 17:
			replay = machine["tower_attack_target_ids"].duplicate()
		combat.advance(1.4)
		for tower: Dictionary in combat.towers[0]:
			_check(int(tower["stun_count"]) == (1 if targets.has(tower["id"]) else 0), "A volley stuns only its two previously captured random targets")
	_check(pairs.size() >= 5 and frequencies.size() == 4, "Seeded volleys vary pairs and select both near and remote towers, not nearest-two or first-built targets")
	var combat := _start(_cannon_rules(), [String(MACHINE)], _layout(), 17)
	for cell: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(12, 4), Vector2i(13, 4)]:
		_weapon(combat, &"war_drums", "", cell)
	var machine: Dictionary = _cannon_windup(combat)
	_check(machine["tower_attack_target_ids"] == replay, "Identical admitted rules and seeds reproduce the same ordered random cannon pair")
	var targets: Array = machine["tower_attack_target_ids"].duplicate()
	var aims: Array = machine["tower_attack_aims"].duplicate()
	var sold: Dictionary = combat._find_tower(0, targets[0])
	_check(combat.sell_tower(0, sold["id"]), "Windup fixture sells one accepted cannon target")
	var replacement: Dictionary = _weapon(combat, &"war_drums", "", sold["cell"])
	_check(machine["tower_attack_target_ids"] == targets and machine["tower_attack_aims"] == aims, "Selling a target cannot rewrite the accepted pending shell IDs or aims")
	combat.advance(1.4)
	_check(replacement["stun_count"] == 0, "A sold target's pending shell never retargets the newly built replacement")
	for tower: Dictionary in combat.towers[0]:
		_check(int(tower["stun_count"]) == (1 if tower["id"] == targets[1] else 0), "Sale cancels only the missing shell while the other distinct target still resolves")


func _test_machine_summons() -> void:
	var frequencies: Dictionary = {}
	var batch_sizes: Dictionary = {}
	for seed_value: int in range(64):
		var rules := _machine_rules()
		rules.enemy_speed = 0.0
		var definition: EnemyDefinition = _enemy(rules, MACHINE)
		definition.summon_interval = 3.0
		definition.jump_interval = 0.0
		definition.jump_weights = PackedInt32Array()
		definition.summon_cast_duration = 0.2
		var layout := _layout(true, 30)
		var combat := _start(rules, [String(MACHINE)], layout, seed_value)
		var machine: Dictionary = _find(combat, MACHINE)
		machine["progress"] = 3.25
		machine["pos"] = combat._position(machine["route"], 3.25)
		combat.advance(3.2)
		var children: int = 0
		for enemy: Dictionary in combat.enemies[0]:
			if enemy["summoner_id"] != machine["id"]:
				continue
			children += 1
			frequencies[enemy["type_id"]] = int(frequencies.get(enemy["type_id"], 0)) + 1
			_check(enemy["type_id"] in ["orcling", "grunt", "runner"] and enemy["age"] < 0.00001 and enemy["route"].back() == layout.base, "Weighted doors create real ordinary newborn troops, not bosses or pre-aged portal spawns")
			_check(enemy["route"] == machine["route"] and is_equal_approx(float(enemy["progress"]), float(machine["progress"])) and Vector2(enemy["pos"]).is_equal_approx(machine["pos"]), "New infantry inherit the Machine's captured painted route and exact current progress")
			for index: int in range(1, enemy["route"].size()):
				_check(Vector2i(enemy["route"][index]).distance_squared_to(enemy["route"][index - 1]) == 1, "Every captured troop route consists of valid adjacent remaining road cells")
		_check(children >= 4 and children <= 7, "A real door cast deploys the increased four-to-seven infantry batch")
		batch_sizes[children] = true
		combat.advance(18.0)
		children = 0
		for enemy: Dictionary in combat.enemies[0]:
			if enemy["summoner_id"] == machine["id"]:
				children += 1
		_check(children == 24, "Repeated real door casts fill but never exceed the increased twenty-four living infantry cap")
	_check(int(frequencies.get("orcling", 0)) > 180 and int(frequencies.get("grunt", 0)) > 0 and int(frequencies.get("runner", 0)) > 0, "Real weighted troop outcomes are mostly Orclings while both rarer types actually occur")
	_check(batch_sizes.has(4) and batch_sizes.has(7), "Seeded real troop casts exercise both increased batch endpoints")
	# Weighted graph validation is resource-owned, including all edges rather than only fallback summon_type.
	var rules := _rules()
	var machine: EnemyDefinition = _enemy(rules, MACHINE)
	machine.summon_weights = PackedInt32Array([1])
	_check(not rules.catalog.validation_errors().is_empty(), "Mismatched weighted child pools are rejected")
	machine.summon_pool = PackedStringArray(["orc_war_machine"])
	machine.summon_weights = PackedInt32Array([1])
	_check(not rules.catalog.validation_errors().is_empty(), "Boss/self-summon weighted references are rejected before admission")


func _test_machine_cancellation() -> void:
	for action: String in ["cannon", "doors", "jump_deploy", "jump_charge", "jump", "jump_land"]:
		var retirements: Array[String] = ["death", "reset"]
		if action in ["cannon", "doors"]:
			retirements.append("leak")
		for retirement: String in retirements:
			var rules := _machine_rules()
			rules.enemy_speed = 0.0
			var definition: EnemyDefinition = _enemy(rules, MACHINE)
			if action in ["cannon", "doors"]:
				definition.jump_interval = 0.0
				definition.jump_weights = PackedInt32Array()
			if action == "cannon":
				definition.tower_attack_kind = &"cannon"
				definition.tower_attack_interval = 0.1
				definition.tower_attack_cast_duration = 1.0
			elif action == "doors":
				definition.summon_interval = 0.1
				definition.summon_cast_duration = 1.0
			else:
				definition.jump_interval = 0.1
				definition.jump_deploy_duration = 0.2
				definition.jump_charge_duration = 0.2
				definition.jump_duration = 0.2
				definition.jump_land_duration = 0.2
			var combat := _start(rules, [String(MACHINE)], _layout(true))
			var tower: Dictionary = _weapon(combat, &"arrow_tower", "", Vector2i(1, 2))
			var other: Dictionary = _weapon(combat, &"war_drums", "", Vector2i(13, 4))
			var machine: Dictionary = _find(combat, MACHINE)
			var pending: bool = false
			for tick: int in range(20):
				combat.advance(0.05)
				pending = (action == "cannon" and float(machine["tower_attack_remaining"]) > 0.0) or (action == "doors" and float(machine["cast_remaining"]) > 0.0) or machine["locomotion"] == action
				if pending:
					break
			_check(pending, "Cancellation fixture reaches actual pending Machine phase: " + action)
			if retirement == "death":
				combat._hit(0, tower, combat._enemy_index(0, machine["id"]), 100000000)
			elif retirement == "leak":
				machine["progress"] = float(machine["route"].size() - 1)
				machine["pos"] = Vector2(machine["route"].back())
			else:
				var coins: Array[int] = combat.coins.duplicate()
				_check(combat.debug_set_round(10) and combat.coins == coins, "Debug reset abandons a pending phase without granting rewards")
			combat.advance(5.0)
			_check(combat.enemies[0].is_empty() and int(tower["stun_count"]) == 0 and int(other["stun_count"]) == 0 and int(machine["summon_count"]) == 0, "Death, leak or reset cannot resolve abandoned cannon targets, doors or jump phases: " + action + "/" + retirement)


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
	machine["progress"] = 6.75
	machine["pos"] = combat._position(machine["route"], 6.75)
	combat._finish_summon(0, machine, combat._enemy_types[String(MACHINE)])
	_check(combat.sandbox_spawn(0, &"grunt", 1), "Mixed-route target fixture adds ordinary full-maze enemy")
	var child: Dictionary = {}
	for enemy: Dictionary in combat.enemies[0]:
		if int(enemy["summoner_id"]) == int(machine["id"]):
			child = enemy
	_check(not child.is_empty() and child["route"] == machine["route"] and is_equal_approx(float(child["progress"]), 6.75), "Actual infantry inherit their parent's full captured route at its current route-cell progress")
	var tower: Dictionary = _weapon(combat, &"arrow_tower")
	var target: int = combat._target(0, tower, 100.0, MatchCombat.TargetMode.FURTHEST)
	_check(target >= 0 and combat.enemies[0][target]["id"] == machine["id"], "Furthest breaks equal Machine/infantry route progress by stable enemy ID")
	machine["progress"] = 6.25
	machine["pos"] = combat._position(machine["route"], 6.25)
	target = combat._target(0, tower, 100.0, MatchCombat.TargetMode.FURTHEST)
	_check(target >= 0 and combat.enemies[0][target]["id"] == child["id"], "Infantry farther along the captured route outrank the Machine using ordinary route-cell progress")
	target = combat._target(0, tower, 100.0, MatchCombat.TargetMode.LAST)
	_check(target >= 0 and combat.enemies[0][target]["type_id"] == "grunt", "Last chooses the ordinary newly spawned enemy behind both Machine and infantry")


func _simulation_signature(combat: MatchCombat) -> Dictionary:
	var result: Dictionary = {"coins": combat.coins.duplicate(), "health": combat.base_health.duplicate(), "random": combat._group_random.state, "enemies": [], "towers": []}
	for enemy: Dictionary in combat.enemies[0]:
		result["enemies"].append({
			"id": enemy["id"], "type": enemy["type_id"], "hp": enemy["hp"],
			"pos": Vector2(enemy["pos"]).snapped(Vector2(0.00001, 0.00001)),
			"progress": snappedf(float(enemy["progress"]), 0.00001), "route": enemy["route"],
			"stomps": enemy["stomp_count"], "attacks": enemy["tower_attack_count"],
			"summons": enemy["summon_count"], "locomotion": enemy["locomotion"],
			"jumps": enemy["jump_count"], "distance": enemy["jump_distance"],
			"jump_target": snappedf(float(enemy["jump_target_progress"]), 0.00001),
			"jump_remaining": snappedf(float(enemy["jump_remaining"]), 0.00001),
			"targets": enemy["tower_attack_target_ids"], "aims": enemy["tower_attack_aims"],
			"mark": enemy["bounty_tower_id"], "burn": snappedf(float(enemy["burn_remaining"]), 0.00001),
		})
	for tower: Dictionary in combat.towers[0]:
		result["towers"].append({
			"shot": tower["shot"], "stuns": tower["stun_count"], "remaining": snappedf(float(tower["stunned_remaining"]), 0.00001),
			"production": snappedf(float(tower["production_elapsed"]), 0.00001),
			"damage": tower["damage"], "interval": snappedf(float(tower["interval"]), 0.00001), "mark": tower["bounty_target_id"],
		})
	return result


func _test_simulation_partition() -> void:
	for roster: Array in [[String(TROLL)], [String(MACHINE)], [String(TROLL), String(MACHINE), String(MANCER)]]:
		var outcomes: Array[Dictionary] = []
		for step: float in [0.05, 0.5, 53.0]:
			var rules := _rules()
			rules.enemy_speed = 0.1
			var typed_roster: Array[String] = []
			typed_roster.assign(roster)
			var combat := _start(rules, typed_roster, _layout(true, 80))
			if roster.size() > 1:
				var machine: Dictionary = _find(combat, MACHINE)
				machine["progress"] = 6.0
				machine["pos"] = combat._position(machine["route"], 6.0)
				var mancer: Dictionary = _find(combat, MANCER)
				mancer["progress"] = 20.0
				mancer["pos"] = combat._position(mancer["route"], 20.0)
			_weapon(combat, &"war_drums", "", Vector2i(0, 1))
			_weapon(combat, &"arrow_tower", "fire_arrows", Vector2i(1, 1))
			_weapon(combat, &"gold_mine", "royal_mint", Vector2i(2, 1))
			_weapon(combat, &"gold_mine", "bounty_board", Vector2i(3, 1))
			_weapon(combat, &"gold_mine", "income_aura", Vector2i(4, 1))
			_weapon(combat, &"war_drums", "", Vector2i(79, 4))
			for tick: int in range(roundi(53.0 / step)):
				combat.advance(step)
			outcomes.append(_simulation_signature(combat))
		_check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2], "Fine/medium/coarse partitions agree on captured route jumps, random cannon pairs, troops, marks, support, stun expiry and paused production: " + str(roster))


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
		var replayed: Dictionary = sandbox.combat.enemies[0][0]
		_check(int(replayed["jump_count"]) == 0 and int(replayed["summon_count"]) == 0 and int(replayed["tower_attack_count"]) == 0 and replayed["tower_attack_target_ids"].is_empty() and replayed["tower_attack_aims"].is_empty() and float(replayed["jump_remaining"]) == 0.0, "Sandbox replay starts fresh counters, pending cannon arrays and jump phase rather than carrying stopped boss state")
		sandbox.stop()
	sandbox.reset_build()
	_check(sandbox.combat.towers[0].is_empty() and sandbox.combat.enemies[0].is_empty() and sandbox.layout.is_ready(), "Sandbox Reset Build clears boss/stun state without discarding route")
