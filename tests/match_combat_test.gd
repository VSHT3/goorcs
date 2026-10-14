extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_commands_and_snapshots()
	_test_targeting_policies()
	_test_range_and_ties()
	_test_routes_and_both_board_clear()
	_test_kills_and_persistence()
	_test_tower_type_stats()
	_test_custom_tower_definition()
	_test_economy_and_upgrades()
	_test_area_kills_and_bounties()
	_test_builtin_upgrade_values()
	_test_wave_scaling_and_rewards()
	_test_enemy_sends()
	_test_typed_enemy_sends()
	_test_typed_enemy_defense()
	_test_weighted_wave_constraints_and_streams()
	_test_weighted_wave_randomness_and_extension()
	_test_resource_damage_and_roster_clearance()
	_test_simultaneous_and_ordinary_outcomes()
	if failures == 0:
		print("PASS: authoritative purchases/upgrades/sales, currency and reward atomicity, per-tower kills, tile range/AoE, scaling, resource stats, targeting, captured routes and frozen outcomes")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 10
	rules.enemy_health = 8
	rules.enemy_speed = 1.0
	rules.wave_weight = 3
	rules.spawn_interval = 0.5
	rules.tower_definitions = [_definition(&"arrow_tower", 2, 20.0, 0.5)]
	rules.health_growth = 2
	rules.speed_growth = 0.0
	rules.wave_weight_growth = 0
	return rules


func _definition(type_id: StringName, damage: int, range_cells: float, interval: float) -> TowerDefinition:
	var reward := TowerReward.new()
	reward.id = type_id
	reward.title = String(type_id)
	var definition := TowerDefinition.new()
	definition.reward = reward
	definition.damage = damage
	definition.range_cells = range_cells
	definition.interval = interval
	return definition


func _line(length: int) -> Array:
	var route: Array = []
	for x: int in range(length + 1):
		route.append(Vector2i(x, 0))
	return route


func _routes(first: int = 10, second: int = 10) -> Array[Array]:
	return [_line(first), _line(second)]


func _run_wave(combat: MatchCombat, ticks: int = 2400) -> void:
	for tick: int in range(ticks):
		if combat.phase != MatchCombat.Phase.WAVE:
			return
		combat.advance(1.0 / 60.0)
	_check(combat.phase != MatchCombat.Phase.WAVE, "Wave completes within its deterministic simulation deadline")


func _test_commands_and_snapshots() -> void:
	var combat := MatchCombat.new(_rules())
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.wave == 0 and combat.base_health == [10, 10], "New combat begins planning with two full bases")
	_check(not combat.advance(1.0), "Planning has no autonomous simulation")
	_check(not combat.build(-1, Vector2i.ZERO, &"arrow_tower", 0) and not combat.build(2, Vector2i.ZERO, &"arrow_tower", 0) and not combat.build(0, Vector2i.ZERO, &"arrow_tower", 3), "Invalid owner or targeting mode is rejected")
	var before_unknown: Dictionary = combat.snapshot()
	_check(not combat.build(0, Vector2i(2, 1), &"unknown_tower", 0) and combat.snapshot() == before_unknown, "Unknown type is rejected without changing any authoritative state")
	_check(combat.build(0, Vector2i(2, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Paid placement succeeds during planning")
	_check(combat.towers[0][0]["id"] == 1 and combat.towers[0][0]["type_id"] == "arrow_tower" and typeof(combat.towers[0][0]["type_id"]) == TYPE_STRING, "Unknown commands do not consume IDs; tower type is a network-safe stable String")
	_check(combat.has_tower(0, Vector2i(2, 1)) and not combat.has_tower(1, Vector2i(2, 1)), "Tower cells belong to their own board")
	_check(not combat.build(0, Vector2i(2, 1), &"arrow_tower", 0), "Duplicate cell placement is rejected")
	var id: int = combat.towers[0][0]["id"]
	_check(not combat.set_targeting(1, id, 1) and not combat.set_targeting(0, id, -1) and not combat.set_targeting(0, id, 0), "Wrong board, invalid mode, and no-op targeting leave towers untouched")
	_check(combat.set_targeting(0, id, MatchCombat.TargetMode.CLOSEST), "Existing own tower changes targeting")
	var invalid_routes: Array[Array] = [[], _line(10)]
	_check(not combat.start_wave(invalid_routes) and combat.wave == 0, "Missing route cannot start or increment a wave")
	_check(combat.start_wave(_routes()) and not combat.start_wave(_routes()), "Only planning can start a wave")
	_check(combat.build(1, Vector2i(2, 1), &"arrow_tower", MatchCombat.TargetMode.STRONGEST), "Paid placement remains available during combat")
	combat.advance(0.1)
	var copy: Dictionary = combat.snapshot()
	copy["health"][0] = 0
	copy["coins"][0] = 99999
	copy["towers"][0][0]["damage"] = 999
	copy["towers"][0][0]["invested"] = 999
	copy["towers"][0][0]["kills"] = 999
	copy["towers"][0][0]["mode"] = 2
	copy["enemies"][0][0]["hp"] = -100
	copy["spawned"][0] = 99
	copy["tower_types"]["arrow_tower"]["damage"] = 999
	copy["tower_types"]["arrow_tower"]["range"] = 999.0
	copy["tower_types"]["arrow_tower"]["interval"] = 999.0
	copy["tower_types"]["arrow_tower"]["title"] = "Changed"
	copy["towers"][0][0]["type_id"] = "changed_type"
	var fresh: Dictionary = combat.snapshot()
	_check(fresh["health"][0] == 10 and fresh["towers"][0][0]["mode"] == 1 and fresh["enemies"][0][0]["hp"] == 6 and fresh["spawned"][0] == 1 and fresh["towers"][0][0]["type_id"] == "arrow_tower", "Snapshot nested arrays/dictionaries are detached from authoritative state")
	_check(fresh["tower_types"]["arrow_tower"] == _type_snapshot(_rules().tower_definitions[0]), "Tower type titles and all authoritative stats are detached from snapshots")
	_check(fresh["coins"] == [155, 155] and fresh["towers"][0][0]["damage"] == 2 and fresh["towers"][0][0]["invested"] == 45 and fresh["towers"][0][0]["kills"] == 0, "Snapshot currency and effective tower stats cannot alter host state")
	_check(not fresh["rules"].has("damage") and not fresh["rules"].has("range") and not fresh["rules"].has("interval"), "Rules snapshot has no obsolete global tower stats")
	_check(not combat.advance(0.0) and not combat.advance(-1.0), "Nonpositive ticks cannot mutate combat")


func _test_targeting_policies() -> void:
	var expected: Array[Array] = [[4, 8, 8], [6, 8, 6], [6, 6, 8]]
	for mode: int in range(3):
		var combat := MatchCombat.new(_rules())
		combat.build(0, Vector2i(0, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
		combat.start_wave(_routes())
		combat.advance(0.1)
		var first_id: int = combat.enemies[0][0]["id"]
		_check(combat.enemies[0][0]["hp"] == 6, "First shot damages a naturally spawned enemy")
		if mode != MatchCombat.TargetMode.FURTHEST:
			combat.set_targeting(0, combat.towers[0][0]["id"], mode)
		combat.advance(1.0)
		var health: Array[int] = []
		for enemy: Dictionary in combat.snapshot()["enemies"][0]:
			health.append(enemy["hp"])
		_check(health == expected[mode], "Policy %d produces its own observable damage distribution: %s" % [mode, health])
		var target_index: int = [0, 2, 1][mode]
		_check(combat.towers[0][0]["target_id"] == combat.enemies[0][target_index]["id"] and combat.towers[0][0]["shot"] == 2, "Policy %d publishes matching native instant-hit visual event" % mode)
		if mode == MatchCombat.TargetMode.STRONGEST:
			_check(combat.towers[0][0]["target_id"] != first_id and combat.enemies[0][0]["max_hp"] == combat.enemies[0][1]["max_hp"], "Strongest compares current HP, not equal starting maximum HP")


func _test_range_and_ties() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.0
	rules.wave_weight = 1
	rules.tower_definitions[0].range_cells = 3.0
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(0, 3), &"arrow_tower", 0)
	combat.build(0, Vector2i(3, 3), &"arrow_tower", 0)
	combat.build(0, Vector2i(4, 3), &"arrow_tower", 0)
	combat.start_wave(_routes())
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == 4 and combat.towers[0][0]["shot"] == 1 and combat.towers[0][1]["shot"] == 1 and combat.towers[0][2]["shot"] == 0, "Tile range includes the full diagonal boundary and excludes the next outer tile")
	_check(MatchCombat.cell_in_range(Vector2i.ZERO, Vector2i(1, 1), 1.0) and not MatchCombat.cell_in_range(Vector2i.ZERO, Vector2i(2, 1), 1.0), "Shared range rule includes eight neighboring cells only at range one")
	# Tile membership rounds the authoritative position; it is not a continuous circle.
	combat.enemies[0][0]["pos"] = Vector2(0.49, 0.49)
	_check(combat._target(0, combat.towers[0][1], 3.0) == 0, "Fractional position inside the entrance tile remains on its diagonal boundary")
	combat.enemies[0][0]["pos"] = Vector2(-0.51, 0.0)
	_check(combat._target(0, combat.towers[0][1], 3.0) == -1, "Rounded enemy tile beyond a boundary is not in range")
	for mode: int in range(3):
		rules = _rules()
		rules.enemy_speed = 0.0
		rules.spawn_interval = 0.0
		combat = MatchCombat.new(rules)
		combat.start_wave(_routes())
		combat.advance(0.1)
		var smallest_id: int = combat.enemies[0][0]["id"]
		combat.enemies[0].reverse()
		combat.build(0, Vector2i(0, 1), &"arrow_tower", mode)
		combat.advance(0.1)
		_check(combat.towers[0][0]["target_id"] == smallest_id and combat.enemies[0][2]["hp"] == 6, "Policy %d breaks equal candidate scores by smallest ID rather than array order" % mode)


func _test_routes_and_both_board_clear() -> void:
	var rules := _rules()
	rules.wave_weight = 1
	var combat := MatchCombat.new(rules)
	var routes: Array[Array] = [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], _line(5)]
	combat.start_wave(routes)
	routes[0][1] = Vector2i(99, 99)
	routes[1].clear()
	combat.advance(0.5)
	_check(combat.enemies[0][0]["pos"].is_equal_approx(Vector2(0.5, 0.0)), "Enemy interpolates along an immutable captured route")
	combat.advance(1.0)
	_check(combat.enemies[0][0]["pos"].is_equal_approx(Vector2(1.0, 0.5)) and is_equal_approx(combat.enemies[0][0]["progress"], 1.5), "Corner interpolation uses route distance, not straight-line base distance")
	combat.advance(1.5)
	_check(combat.enemies[0].is_empty() and combat.base_health == [9, 10] and combat.phase == MatchCombat.Phase.WAVE, "A clear short board cannot finish while the other board has an enemy")
	combat.advance(2.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [9, 9], "Only both cleared boards return to planning")
	_check(combat.wave == 1 and combat.snapshot()["spawned"] == [1, 1], "Wave and spawn totals remain readable after completion")
	# A gap with no alive enemies is not a clear while scheduled spawns remain.
	rules.spawn_interval = 4.0
	rules.wave_weight = 2
	combat = MatchCombat.new(rules)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.enemies[0].is_empty() and combat.enemies[1].is_empty() and combat.phase == MatchCombat.Phase.WAVE and combat.snapshot()["spawned"] == [1, 1], "Unspawned scheduled enemies keep the wave active even with both boards temporarily empty")
	_run_wave(combat)
	_check(combat.base_health == [8, 8] and combat.snapshot()["spawned"] == [2, 2], "Both boards receive the same regular scheduled wave")


func _test_kills_and_persistence() -> void:
	var rules := _rules()
	rules.wave_weight = 2
	rules.enemy_health = 2
	rules.health_growth = 2
	rules.tower_definitions[0].damage = 20
	rules.tower_definitions[0].interval = 0.1
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	combat.start_wave(_routes(2, 2))
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [10, 8], "Killed enemies never leak; unprotected board keeps accumulated damage")
	_check(combat.enemies[0].is_empty() and combat.enemies[1].is_empty() and combat.towers[0][0]["shot"] == 2, "Both wave enemy lists clear and tower shot history persists")
	var tower_id: int = combat.towers[0][0]["id"]
	var before: int = combat.towers[0][0]["shot"]
	_check(not combat.advance(10.0) and combat.wave == 1 and combat.base_health == [10, 8], "Cleared waves wait in planning rather than starting automatically")
	combat.start_wave(_routes(2, 2))
	combat.advance(0.1)
	_check(combat.wave == 2 and combat.enemies[1][0]["max_hp"] == 4 and combat.snapshot()["rules"]["enemy_health"] == 4, "Each next wave applies configured enemy health growth")
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [10, 6] and combat.towers[0][0]["id"] == tower_id and combat.towers[0][0]["shot"] == before + 2, "Bases, fixed-stat towers, and monotonic shot counters persist across waves")
	# A lethal hit at the endpoint is resolved before leak bookkeeping.
	rules.wave_weight = 1
	combat = MatchCombat.new(rules)
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.base_health == [10, 9] and combat.phase == MatchCombat.Phase.PLANNING, "Instant-hit death at the endpoint cannot damage that base")


func _test_tower_type_stats() -> void:
	var type_ids: Array[StringName] = [&"arrow_tower", &"orc_ballista", &"rune_obelisk"]
	var damages: Array[int] = [2, 6, 1]
	var ranges: Array[float] = [3.0, 4.0, 1.0]
	var intervals: Array[float] = [0.75, 1.5, 0.3]
	var boundary_shots: Array[int] = [1, 2, 0]
	for index: int in range(type_ids.size()):
		var rules := CombatRules.new()
		rules.enemy_health = 100
		rules.enemy_speed = 0.0
		rules.wave_weight = 2
		rules.spawn_interval = 0.0
		var combat := MatchCombat.new(rules)
		var type_id: StringName = type_ids[index]
		_check(combat.build(0, Vector2i(0, 1), type_id, 0), "Configured tower %s builds" % type_id)
		combat.build(1, Vector2i(0, 3), type_id, 0)
		combat.build(1, Vector2i(0, 4), type_id, 0)
		var types: Dictionary = combat.snapshot()["tower_types"]
		_check(types.size() == 3 and types[String(type_id)]["damage"] == damages[index] and is_equal_approx(types[String(type_id)]["range"], ranges[index]) and is_equal_approx(types[String(type_id)]["interval"], intervals[index]) and not String(types[String(type_id)]["title"]).is_empty(), "Resource %s publishes its own authoritative title and provisional stats" % type_id)
		combat.start_wave(_routes())
		combat.advance(0.01)
		var second_hp: int = 100 - damages[index] if index == 2 else 100
		_check(combat.enemies[0][0]["hp"] == 100 - damages[index] and combat.enemies[0][1]["hp"] == second_hp, "Tower %s performs its configured single-target or full-footprint damage" % type_id)
		_check(combat.enemies[1][0]["hp"] == 100 - boundary_shots[index] * damages[index] and combat.enemies[1][1]["hp"] == 100, "Tower %s uses its own tile range at three- and four-cell boundaries" % type_id)
		_check(is_equal_approx(combat.towers[0][0]["cooldown"], intervals[index]), "Tower %s stores its own firing cooldown" % type_id)
		combat.advance(intervals[index] * 0.9)
		_check(combat.towers[0][0]["shot"] == 1 and combat.enemies[0][0]["hp"] == 100 - damages[index], "Tower %s cannot fire before its own interval" % type_id)
		combat.advance(intervals[index] * 0.2)
		_check(combat.towers[0][0]["shot"] == 2 and combat.enemies[0][0]["hp"] == 100 - 2 * damages[index], "Tower %s fires again after its own interval" % type_id)


func _test_custom_tower_definition() -> void:
	var rules := CombatRules.new()
	rules.enemy_health = 20
	rules.enemy_speed = 0.0
	rules.wave_weight = 1
	# Detach the default array before adding a local definition; never mutate shared resources.
	rules.tower_definitions = rules.tower_definitions.duplicate()
	var custom := _definition(&"test_fourth_tower", 9, 6.0, 0.2)
	custom.reward.title = "Test fourth tower"
	rules.tower_definitions.append(custom)
	var combat := MatchCombat.new(rules)
	_check(combat.build(0, Vector2i(0, 5), &"test_fourth_tower", MatchCombat.TargetMode.STRONGEST), "A fourth resource-defined ID builds without any code branch")
	var types: Dictionary = combat.snapshot()["tower_types"]
	_check(types.size() == 4 and types["test_fourth_tower"] == _type_snapshot(custom), "Custom tower publishes its configured authoritative stats alongside the defaults")
	# The match owns captured stats, not subsequent edits to the source resource.
	custom.damage = 1
	custom.range_cells = 1.0
	custom.interval = 99.0
	custom.cost = 999
	custom.damage_upgrade_bonus = 999
	custom.speed_upgrade_multiplier = 0.1
	custom.area_attack = true
	custom.reward.title = "Edited source"
	_check(combat.snapshot()["tower_types"] == types, "Source resource edits cannot change an existing match's authoritative type stats")
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 11 and combat.towers[0][0]["shot"] == 1 and is_equal_approx(combat.towers[0][0]["cooldown"], 0.2), "Custom tower attacks at its configured range with its own damage and cooldown")
	combat.advance(0.21)
	_check(combat.enemies[0][0]["hp"] == 2 and combat.towers[0][0]["shot"] == 2, "Custom tower repeatedly fights through the same attack loop as built-in towers")
	combat.advance(0.21)
	_check(combat.enemies[0].is_empty() and combat.base_health[0] == rules.base_health and combat.towers[0][0]["shot"] == 3, "Custom tower kills enemies without leaking or requiring tower-specific combat code")
	_check(combat.snapshot()["tower_types"]["arrow_tower"]["damage"] == 2, "Local test definitions leave shared default resource stats unchanged")


func _test_simultaneous_and_ordinary_outcomes() -> void:
	var rules := _rules()
	rules.base_health = 1
	rules.wave_weight = 2
	rules.spawn_interval = 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 982451653
	var expected_random := RandomNumberGenerator.new()
	expected_random.seed = random.seed
	var expected_winner: int = expected_random.randi_range(0, 1)
	var combat := MatchCombat.new(rules, random)
	combat.start_wave(_routes(1, 1))
	combat.advance(1.0)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.base_health == [0, 0] and combat.coin_flip and combat.winner == expected_winner, "Both-board leaks are batched, health clamps at zero, and one seeded coin flip resolves same-tick destruction")
	_check(random.state == expected_random.state, "Simultaneous destruction consumes exactly one host RNG draw")
	var frozen: Dictionary = combat.snapshot()
	var state: int = random.state
	for tick: int in range(5):
		_check(not combat.advance(1.0), "Finished outcome cannot advance or reroll")
	_check(not combat.start_wave(_routes()) and not combat.build(0, Vector2i(0, 1), &"arrow_tower", 0) and not combat.set_targeting(0, 1, 1) and not combat.upgrade_tower(0, 1, "damage") and not combat.sell_tower(0, 1), "Finished combat rejects every mutation command")
	_check(combat.snapshot() == frozen and random.state == state, "Terminal snapshot and RNG state remain frozen")
	# Different route lengths destroy only the first base on this tick.
	random = RandomNumberGenerator.new()
	random.seed = 32452843
	state = random.state
	combat = MatchCombat.new(rules, random)
	combat.start_wave(_routes(1, 2))
	combat.advance(1.0)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.base_health == [0, 1] and combat.winner == 1 and not combat.coin_flip and random.state == state, "An ordinary surviving slot wins without consuming randomness")
	# The opposite board can win too; it is not a hard-coded host outcome.
	combat = MatchCombat.new(rules, random)
	combat.start_wave(_routes(2, 1))
	combat.advance(1.0)
	_check(combat.base_health == [1, 0] and combat.winner == 0 and not combat.coin_flip and random.state == state, "Opposite ordinary outcome also leaves host RNG untouched")


func _type_snapshot(definition: TowerDefinition) -> Dictionary:
	return {
		"title": definition.reward.title, "damage": definition.damage,
		"range": definition.range_cells, "interval": definition.interval,
		"cost": definition.cost, "damage_upgrade_cost": definition.damage_upgrade_cost,
		"damage_upgrade_bonus": definition.damage_upgrade_bonus,
		"speed_upgrade_cost": definition.speed_upgrade_cost,
		"speed_upgrade_multiplier": definition.speed_upgrade_multiplier,
		"area_attack": definition.area_attack,
	}


func _test_economy_and_upgrades() -> void:
	var rules := _rules()
	rules.starting_coins = 105
	var combat := MatchCombat.new(rules)
	_check(combat.coins == [105, 105], "Each player starts with the configured Coins")
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.coins == [60, 105], "Purchase spends the owning player's exact price")
	var id: int = combat.towers[0][0]["id"]
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.upgrade_tower(1, id, "damage") and not combat.sell_tower(1, id) and not combat.upgrade_tower(0, id, "unknown") and not combat.sell_tower(0, -1), "Wrong owner, missing tower and unknown upgrade are rejected")
	_check(not combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.snapshot() == frozen, "Invalid purchases and tower commands spend nothing or change stats/IDs")
	_check(combat.upgrade_tower(0, id, "damage") and combat.coins[0] == 30 and combat.towers[0][0]["damage"] == 3 and combat.towers[0][0]["damage_upgraded"], "One-time damage purchase applies its configured bonus atomically")
	combat.start_wave(_routes())
	combat.advance(0.1)
	var cooldown: float = combat.towers[0][0]["cooldown"]
	_check(combat.upgrade_tower(0, id, "speed") and combat.coins[0] == 0, "Exact remaining Coins buy a speed upgrade during combat")
	var tower: Dictionary = combat.towers[0][0]
	_check(tower["speed_upgraded"] and is_equal_approx(tower["interval"], 0.4) and is_equal_approx(tower["cooldown"], cooldown * 0.8) and tower["invested"] == 105 and tower["sell_value"] == 63, "Effective attack interval, reload and invested/refund stats include paid upgrades")
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, id, "damage") and not combat.upgrade_tower(0, id, "speed") and not combat.build(0, Vector2i(2, 1), &"arrow_tower", 0) and combat.snapshot() == frozen, "Repeated upgrades and insufficient-money purchase mutate nothing")
	_check(combat.sell_tower(0, id) and combat.coins[0] == 63 and combat.towers[0].is_empty(), "Live sale refunds 60 percent of actual investment and removes the tower")
	frozen = combat.snapshot()
	_check(not combat.sell_tower(0, id) and not combat.upgrade_tower(0, id, "damage") and combat.snapshot() == frozen, "Repeated sale and stale upgrade cannot grant money or affect removed towers")
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.towers[0][0]["id"] == id + 1, "Failed purchases do not consume IDs; rebuying gets the next identity")
	var replacement: Dictionary = combat.towers[0][0]
	_check(not replacement["damage_upgraded"] and not replacement["speed_upgraded"] and replacement["kills"] == 0 and replacement["damage"] == 2, "Rebuy has no inherited kills or upgrades")
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, replacement["id"], "damage") and not combat.upgrade_tower(0, replacement["id"], "speed") and combat.snapshot() == frozen, "Unaffordable upgrades leave Coins, readiness-independent stats, and investment untouched")
	_check(combat.sell_tower(0, replacement["id"]) and combat.coins[0] == 45, "Sale/rebuy loses money rather than manufacturing it")
	var rounding_rules := _rules()
	rounding_rules.tower_definitions[0].cost = 46
	combat = MatchCombat.new(rounding_rules)
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	_check(combat.towers[0][0]["sell_value"] == 27 and combat.sell_tower(0, 1) and combat.coins[0] == 181, "Sale floors fractional refund Coins")


func _test_area_kills_and_bounties() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.0
	rules.enemy_health = 2
	rules.spawn_interval = 0.0
	var area := _definition(&"test_area", 2, 1.0, 0.5)
	area.area_attack = true
	rules.tower_definitions = [area]
	var combat := MatchCombat.new(rules)
	combat.start_wave(_routes())
	combat.advance(0.1)
	var first_id: int = combat.enemies[0][0]["id"]
	combat.enemies[0][0]["pos"] = Vector2(0.49, 0.49)
	combat.enemies[0][1]["pos"] = Vector2(1.49, 1.49)
	combat.enemies[0][2]["pos"] = Vector2(1.51, 0.0)
	combat.build(0, Vector2i.ZERO, &"test_area", 0)
	combat.build(0, Vector2i(0, 1), &"test_area", 0)
	# Attack the fixed fixture before movement overwrites its positions.
	combat._attack(0, 0.01)
	_check(combat.enemies[0].size() == 1 and combat.enemies[0][0]["pos"] == Vector2(1.51, 0.0), "One area attack hits every enemy on the tile/eight neighbors, never the outer rounded tile")
	_check(combat.towers[0][0]["kills"] == 2 and combat.towers[0][1]["kills"] == 0 and combat.coins == [116, 200], "Overlapping area towers attribute each kill and bounty exactly once to the killing tower/board")
	_check(combat.towers[0][0]["shot"] == 1 and combat.towers[0][0]["target_id"] == first_id, "Area attacks publish one cosmetic event, not a separate shot for each victim")
	var before: Array[int] = combat.coins.duplicate()
	combat._attack(0, 0.1)
	_check(combat.coins == before and combat.towers[0][0]["kills"] == 2, "Removed enemies cannot pay a second kill bounty")
	combat.sell_tower(0, 1)
	_check(combat.coins[0] == 143, "Kill income is not counted again as tower investment on sale")


func _test_wave_scaling_and_rewards() -> void:
	var rules := CombatRules.new()
	rules.base_health = 100
	rules.enemy_health = 8
	rules.enemy_speed = 2.0
	rules.wave_weight = 6
	rules.spawn_interval = 0.0
	var combat := MatchCombat.new(rules)
	for wave_number: int in range(1, 4):
		combat.start_wave(_routes(5, 5))
		combat.advance(0.1)
		var budget: int = 6 + (wave_number - 1) * 2
		var count: int = combat.wave_roster.size()
		var speed: float = 2.0 + (wave_number - 1) * 0.15
		var hp: int = 8 + (wave_number - 1) * 2
		var state: Dictionary = combat.snapshot()
		_check(state["wave_weight"] == budget and state["total"] == count and state["spawned"] == [count, count] and combat.enemies[0].size() == count and combat.enemies[1].size() == count, "Wave %d schedules the shared actual roster within its growing weight budget" % wave_number)
		_check(state["rules"]["enemy_health"] == hp and is_equal_approx(state["rules"]["enemy_speed"], speed), "Wave %d preserves baseline health and speed growth" % wave_number)
		for enemy: Dictionary in combat.enemies[0]:
			var type_stats: Dictionary = state["enemy_types"][enemy["type_id"]]
			_check(enemy["max_hp"] == ceili(hp * float(type_stats["health_multiplier"])) and is_equal_approx(float(enemy["progress"]), float(enemy["speed"]) * 0.1), "Real spawns apply delivery-wave per-type health and fractional-tick speed")
		var before: int = combat.coins[0]
		_run_wave(combat)
		_check(combat.coins == [before + 30 + 5 * wave_number, before + 30 + 5 * wave_number], "Both surviving boards receive one wave-clear reward, including a board that leaked")
		var frozen: Dictionary = combat.snapshot()
		_check(not combat.advance(100.0) and combat.snapshot() == frozen, "Planning cannot pay the cleared wave again")
	rules.base_health = 1
	combat = MatchCombat.new(rules)
	combat.start_wave(_routes(1, 1))
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.coins == [200, 200], "A terminal defeat is not a rewarded wave-clear")


func _test_builtin_upgrade_values() -> void:
	var ids: Array[StringName] = [&"arrow_tower", &"orc_ballista", &"rune_obelisk"]
	var costs: Array[int] = [45, 85, 70]
	var upgrade_costs: Array[int] = [30, 55, 45]
	var effective_damage: Array[int] = [3, 9, 2]
	var multipliers: Array[float] = [0.8, 0.75, 0.85]
	for index: int in range(ids.size()):
		var rules := CombatRules.new()
		rules.enemy_health = 100
		rules.enemy_speed = 0.0
		rules.wave_weight = 1
		var combat := MatchCombat.new(rules)
		combat.build(0, Vector2i(0, 1), ids[index], 0)
		var id: int = combat.towers[0][0]["id"]
		_check(combat.upgrade_tower(0, id, "damage") and combat.upgrade_tower(0, id, "speed"), "Both configured one-time upgrades are affordable from starting Coins for %s" % ids[index])
		var type_stats: Dictionary = combat.snapshot()["tower_types"][String(ids[index])]
		_check(type_stats["cost"] == costs[index] and type_stats["damage_upgrade_cost"] == upgrade_costs[index] and type_stats["speed_upgrade_cost"] == upgrade_costs[index] and is_equal_approx(type_stats["speed_upgrade_multiplier"], multipliers[index]), "Tower %s publishes its distinct upgrade prices and speed bonus" % ids[index])
		combat.start_wave(_routes())
		combat.advance(0.01)
		var tower: Dictionary = combat.towers[0][0]
		_check(tower["damage"] == effective_damage[index] and combat.enemies[0][0]["hp"] == 100 - effective_damage[index] and is_equal_approx(tower["cooldown"], type_stats["interval"] * multipliers[index]), "Tower %s attacks using purchased effective damage and interval" % ids[index])
		_check(combat.coins[0] == 200 - costs[index] - 2 * upgrade_costs[index] and tower["invested"] == costs[index] + 2 * upgrade_costs[index], "Tower %s accounts for each paid upgrade exactly once" % ids[index])


func _test_enemy_sends() -> void:
	var rules := _rules()
	rules.starting_coins = 40
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.send_cutoff_seconds = 1.0
	var combat := MatchCombat.new(rules)
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.send_enemy(-1, &"grunt") and not combat.send_enemy(2, &"grunt") and combat.snapshot() == frozen, "Invalid send payer changes no Coins, income, queues or enemies")
	_check(combat.send_enemy(0, &"grunt") and combat.coins == [20, 40] and combat.income == [2, 0] and combat.queued_sends == [0, 1] and combat.enemies == [[], []], "Planning sends pay now and reserve exactly one enemy on the opponent, without route access")
	var copy: Dictionary = combat.snapshot()
	copy["income"][0] = 999
	copy["queued_sends"][1] = 999
	_check(combat.income == [2, 0] and combat.queued_sends == [0, 1], "Client snapshot income/queue mutations cannot affect the host")
	var invalid_routes: Array[Array] = [[], _line(4)]
	frozen = combat.snapshot()
	_check(not combat.start_wave(invalid_routes) and combat.snapshot() == frozen, "Invalid wave start preserves paid queued delivery")
	combat.start_wave(_routes(4, 4))
	_check(combat.queued_sends == [0, 0] and combat.enemies[0].is_empty() and combat.enemies[1].size() == 1 and combat.enemies[1][0]["pos"] == Vector2.ZERO and combat.enemies[1][0]["hp"] == 8, "Starting a legal wave delivers the paid enemy at the opponent entrance with existing wave stats")
	_check(combat.send_enemy(0, &"grunt") and combat.coins == [0, 40] and combat.income == [4, 0] and combat.enemies[1].size() == 2, "Exact funds send immediately during the delivery window and grow only sender income")
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"grunt") and combat.snapshot() == frozen, "Unaffordable send cannot create a free enemy or income, nor consume IDs")
	combat.advance(1.0)
	_check(not combat.snapshot()["sends_open"] and combat.enemies[0].size() == 1 and combat.enemies[1].size() == 3, "Cutoff closes at its exact boundary; sent enemies coexist with regular spawns")
	_check(combat.send_enemy(1, &"grunt") and combat.coins == [0, 20] and combat.income == [4, 2] and combat.queued_sends == [1, 0] and combat.enemies[0].size() == 1, "A cutoff order pays once and waits for the next wave, never extending current delivery")
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [9, 7], "Both boards clear including sent enemies; each sent enemy causes the usual base damage")
	_check(combat.coins == [39, 57] and combat.queued_sends == [1, 0], "Clear pays shared reward plus each sender's recurring bonus once and preserves late orders")
	frozen = combat.snapshot()
	_check(not combat.advance(10.0) and combat.snapshot() == frozen, "Idle planning cannot pay income or deliver queued enemies again")
	combat.start_wave(_routes(4, 4))
	_check(combat.enemies[0].size() == 1 and combat.enemies[0][0]["hp"] == 10 and combat.enemies[0][0]["id"] == 5 and combat.queued_sends == [0, 0], "Deferred order delivers exactly once with next-wave scaling and the next unconsumed ID")
	_run_wave(combat)
	_check(combat.coins == [83, 99] and combat.base_health == [7, 6], "The same income bonus pays again on a later clear without another send")
	# Sent enemies use ordinary attack, kill attribution and bounty rules.
	rules.starting_coins = 200
	rules.tower_definitions[0].damage = 100
	rules.tower_definitions[0].interval = 0.01
	combat = MatchCombat.new(rules)
	combat.send_enemy(0, &"grunt")
	combat.build(1, Vector2i(0, 1), &"arrow_tower", 0)
	combat.start_wave(_routes(4, 4))
	_run_wave(combat)
	_check(combat.base_health == [9, 10] and combat.towers[1][0]["kills"] == 2 and combat.coins == [217, 196], "Defenses kill sent and regular enemies through the same bounty and wave-clear rules")
	rules.base_health = 1
	combat = MatchCombat.new(rules)
	combat.send_enemy(0, &"grunt")
	combat.start_wave(_routes(4, 4))
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.FINISHED and combat.coins == [180, 200], "Terminal defeat pays no wave income even when a send earned a bonus")
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"grunt") and not combat.send_enemy(1, &"grunt") and not combat.advance(10.0) and combat.snapshot() == frozen, "Finished matches reject sends without charging, spawning, rerolling or paying income")


func _test_typed_enemy_sends() -> void:
	var rules := _rules()
	rules.wave_weight = 1
	rules.spawn_interval = 0.0
	rules.speed_growth = 0.15
	rules.send_cutoff_seconds = 1.0
	var combat := MatchCombat.new(rules)
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.send_enemy(0, &"unknown") and not combat.send_enemy(0, &"") and combat.snapshot() == frozen, "Unknown/empty enemy IDs cannot spend Coins, grow income or create orders")
	_check(combat.send_enemy(0, &"runner") and combat.send_enemy(0, &"brute") and combat.coins == [135, 200] and combat.income == [6, 0], "Runner and Brute spend their own prices and add their own recurring income")
	var copy: Dictionary = combat.snapshot()
	copy["enemy_types"]["runner"]["health_multiplier"] = 99.0
	copy["enemy_types"]["brute"]["send_cost"] = 1
	copy["send_queues"][1][0] = "grunt"
	_check(combat.snapshot()["send_queues"] == [[], ["runner", "brute"]], "Mixed queues retain identity/order despite consumer snapshot mutation")
	combat.start_wave(_routes(4, 4))
	var runner: Dictionary = combat.enemies[1][0]
	var brute: Dictionary = combat.enemies[1][1]
	_check(runner["type_id"] == "runner" and runner["hp"] == 5 and is_equal_approx(runner["speed"], 1.7) and brute["type_id"] == "brute" and brute["hp"] == 20 and is_equal_approx(brute["speed"], 0.65), "Queued types spawn with rounded Runner health and durable Brute health plus independent wave-scaled speeds")
	combat.advance(1.0)
	_check(is_equal_approx(runner["progress"], 1.7) and is_equal_approx(brute["progress"], 0.65) and is_equal_approx(combat.enemies[1][2]["progress"], 1.0) and combat.enemies[1][2]["type_id"] == "grunt", "Mixed enemies advance by their own host-captured speeds; first-wave regular enemies are Grunts")
	combat.advance(1.4)
	_check(combat.base_health == [10, 9] and combat.enemies[1].size() == 2 and combat.enemies[1][0]["type_id"] == "brute", "Runner reaches the base first while slower Brute and regular Grunt remain in combat")
	_run_wave(combat)
	_check(combat.base_health == [9, 5] and combat.coins == [176, 235], "Brute leaks three damage once and clear pays only sender's purchased income bonus")
	var preview: Dictionary = combat.snapshot()["enemy_types"]
	_check(preview["runner"]["health"] == 6 and preview["brute"]["health"] == 25 and is_equal_approx(preview["runner"]["speed"], 1.15 * 1.7), "Planning previews the next wave's effective typed stats, not the cleared wave")
	combat.start_wave(_routes(4, 4))
	combat.advance(1.0)
	combat.send_enemy(1, &"brute")
	combat.send_enemy(1, &"runner")
	_check(combat.snapshot()["send_queues"] == [["brute", "runner"], []] and combat.queued_sends == [2, 0] and combat.enemies[0].size() == 1, "Mixed orders at the exact cutoff preserve next-wave type order and spawn nothing now")
	_run_wave(combat)
	combat.start_wave(_routes(4, 4))
	_check(combat.enemies[0].size() == 2 and combat.enemies[0][0]["type_id"] == "brute" and combat.enemies[0][1]["type_id"] == "runner" and combat.enemies[0][0]["hp"] == 30 and combat.enemies[0][1]["hp"] == 8 and combat.queued_sends == [0, 0], "Deferred mixed orders deliver exactly once using wave-three stats, not purchase-time stats")
	# Resource edits after admission cannot rewrite captured type rules.
	var detached: EnemyDefinition = rules.enemy_definitions[1].duplicate()
	rules.enemy_definitions = rules.enemy_definitions.duplicate()
	rules.enemy_definitions[1] = detached
	combat = MatchCombat.new(rules)
	detached.send_cost = 1
	detached.send_income = 99
	detached.speed_multiplier = 99.0
	combat.start_wave(_routes())
	combat.send_enemy(0, &"runner")
	_check(combat.coins == [175, 200] and combat.income == [2, 0] and is_equal_approx(combat.enemies[1][0]["speed"], 1.7), "Accepted match captures type prices, income and movement independently of later resource edits")
	var exact_rules := _rules()
	exact_rules.starting_coins = 40
	combat = MatchCombat.new(exact_rules)
	_check(combat.send_enemy(0, &"brute") and combat.coins[0] == 0 and combat.snapshot()["send_queues"][1] == ["brute"], "Exact funds buy a Brute without granting a free extra order")
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"runner") and not combat.send_enemy(0, &"brute") and combat.snapshot() == frozen, "Poor typed sends cannot grow income or queues")


func _test_typed_enemy_defense() -> void:
	var rules := _rules()
	rules.wave_weight = 1
	rules.spawn_interval = 0.0
	rules.enemy_speed = 0.0
	rules.tower_definitions[0].damage = 5
	rules.tower_definitions[0].interval = 0.1
	var combat := MatchCombat.new(rules)
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routes())
	combat.build(1, Vector2i(0, 1), &"arrow_tower", MatchCombat.TargetMode.STRONGEST)
	combat.advance(0.01)
	_check(combat.enemies[1][0]["hp"] == 5 and combat.enemies[1][1]["hp"] == 15 and combat.towers[1][0]["target_id"] == combat.enemies[1][1]["id"], "Strongest targets the durable Brute in a mixed stream instead of the Runner")
	combat.set_targeting(1, combat.towers[1][0]["id"], MatchCombat.TargetMode.FURTHEST)
	combat.advance(0.1)
	_check(combat.enemies[1].size() == 2 and combat.towers[1][0]["kills"] == 1 and combat.coins[1] == 158, "A killed Runner pays the normal bounty once and is removed before leaks")
	var area := _definition(&"test_area", 5, 1.0, 0.1)
	area.area_attack = true
	rules.tower_definitions = [area]
	combat = MatchCombat.new(rules)
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routes())
	combat.build(1, Vector2i(0, 1), &"test_area", 0)
	combat.advance(0.01)
	_check(combat.enemies[1].size() == 2 and combat.enemies[1][0]["type_id"] == "brute" and combat.enemies[1][0]["hp"] == 15 and combat.towers[1][0]["kills"] == 1, "Area attacks hit the whole mixed footprint, killing the fragile Runner while Brute survives")


func _wave_rng(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func _check_roster_constraints(state: Dictionary, wave_number: int) -> void:
	var counts: Dictionary = {}
	var weight: int = 0
	var budget: int = state["wave_weight"]
	for type_id: String in state["wave_roster"]:
		var definition: Dictionary = state["enemy_types"][type_id]
		counts[type_id] = int(counts.get(type_id, 0)) + 1
		weight += int(definition["spawn_weight"])
		_check(wave_number >= int(definition["first_wave"]), "Regular roster never draws a locked type")
	for type_id: String in counts:
		var definition: Dictionary = state["enemy_types"][type_id]
		var count: int = counts[type_id]
		_check(int(definition["max_per_wave"]) == 0 or count <= int(definition["max_per_wave"]), "Regular type respects its hard count cap")
		_check(count * int(definition["spawn_weight"]) <= floori(budget * float(definition["max_weight_share"])), "Regular type respects floored total-weight share")
	_check(weight == budget and state["total"] == state["wave_roster"].size(), "Regular roster fills exact integer budget and reports actual count")


func _test_weighted_wave_constraints_and_streams() -> void:
	var saw_runner: bool = false
	var saw_brute: bool = false
	for seed_value: int in range(16):
		var rules := CombatRules.new()
		rules.base_health = 10000
		var tie_random: RandomNumberGenerator = _wave_rng(999)
		var frozen_tie_state: int = tie_random.state
		var combat := MatchCombat.new(rules, tie_random, _wave_rng(seed_value))
		for wave_number: int in range(1, 21):
			_check(combat.start_wave(_routes(1000, 1000)), "Weighted wave starts through the normal route-capture API")
			var state: Dictionary = combat.snapshot()
			_check_roster_constraints(state, wave_number)
			var roster: Array = state["wave_roster"].duplicate()
			if wave_number <= 2:
				_check(roster.count("grunt") == roster.size(), "First two waves contain only Grunts")
			saw_runner = saw_runner or roster.has("runner")
			saw_brute = saw_brute or roster.has("brute")
			if roster.has("runner") or roster.has("brute"):
				_check(roster.size() < int(state["wave_weight"]), "Heavier regular types replace head count within the budget instead of stacking extra enemies")
			state["wave_roster"].clear()
			state["enemy_types"]["brute"]["base_damage"] = 99
			_check(combat.wave_roster == roster and combat.snapshot()["enemy_types"]["brute"]["base_damage"] == 3, "Roster and resource-rule snapshots are detached from authority")
			# Observe every scheduled spawn on both boards before any can leak.
			for index: int in range(roster.size()):
				combat.advance(0.01 if index == 0 else rules.spawn_interval)
				for slot: int in range(2):
					_check(combat.enemies[slot].size() == index + 1, "Actual regular spawn stream follows roster cadence")
					var enemy: Dictionary = combat.enemies[slot][index]
					var type_id: String = roster[index]
					var definition: Dictionary = combat.snapshot()["enemy_types"][type_id]
					var hp: int = ceili((8 + 2 * (wave_number - 1)) * float(definition["health_multiplier"]))
					var speed: float = (2.0 + 0.15 * (wave_number - 1)) * float(definition["speed_multiplier"])
					_check(enemy["type_id"] == type_id and enemy["max_hp"] == hp and is_equal_approx(float(enemy["speed"]), speed) and is_equal_approx(float(enemy["progress"]), speed * 0.01), "Both real streams share order and delivery-wave stats including fractional-tick type travel")
					_check(int(enemy["damage"]) == int(definition["base_damage"]), "Regular spawns capture the same per-resource damage as sends")
				_check(combat.enemies[0][index]["id"] != combat.enemies[1][index]["id"], "Shared roster never shares mutable enemy identity between boards")
			combat.advance(2000.0)
			_check(combat.phase == MatchCombat.Phase.PLANNING, "Both actual roster streams clear into the next break")
			_check(tie_random.state == frozen_tie_state, "Regular wave choices never consume terminal coin-flip randomness")
	_check(saw_runner and saw_brute, "Unlocked weighted waves actually include both heavier shipped types")


func _test_weighted_wave_randomness_and_extension() -> void:
	var variants: Dictionary = {}
	var rules := CombatRules.new()
	rules.enemy_definitions = rules.enemy_definitions.duplicate()
	var fourth := EnemyDefinition.new()
	fourth.id = &"test_fourth_enemy"
	fourth.title = "Fourth"
	fourth.spawn_weight = 3
	fourth.first_wave = 4
	fourth.max_per_wave = 2
	fourth.max_weight_share = 0.4
	fourth.base_damage = 2
	fourth.health_multiplier = 1.25
	fourth.speed_multiplier = 0.9
	rules.enemy_definitions.append(fourth)
	var saw_fourth: bool = false
	for seed_value: int in range(32):
		var first := MatchCombat.new(rules, null, _wave_rng(seed_value))
		var second := MatchCombat.new(rules, null, _wave_rng(seed_value))
		first.wave = 11
		second.wave = 11
		first.start_wave(_routes(1000, 1000))
		second.start_wave(_routes(1000, 1000))
		_check(first.wave_roster == second.wave_roster, "Equal wave seeds repeat the ordered roster exactly")
		var state: Dictionary = first.snapshot()
		_check_roster_constraints(state, 12)
		variants[str(first.wave_roster)] = true
		var regular_roster: Array = first.wave_roster.duplicate()
		_check(first.send_enemy(0, fourth.id), "Fourth resource sends without a type-specific command branch")
		var sent: Dictionary = first.enemies[1][0]
		_check(sent["type_id"] == String(fourth.id) and sent["damage"] == 2 and sent["max_hp"] == ceili(30 * 1.25) and is_equal_approx(float(sent["speed"]), 3.65 * 0.9), "Fourth resource controls sent damage and delivery-wave multipliers")
		_check(first.wave_roster == regular_roster and first.snapshot()["total"] == regular_roster.size() and first.snapshot()["wave_weight"] == 28, "Immediate sends remain extra and consume no regular roster budget")
		first.advance(0.01)
		_check(first.enemies[1][1]["type_id"] == regular_roster[0], "Sent order does not replace the first regular scheduled type")
		first.advance(regular_roster.size() * rules.spawn_interval)
		for slot: int in range(2):
			for index: int in range(regular_roster.size()):
				var enemy: Dictionary = first.enemies[slot][index + (1 if slot == 1 else 0)]
				_check(enemy["type_id"] == regular_roster[index], "Fourth resource participates in the same actual ordered stream on both boards")
				if enemy["type_id"] == String(fourth.id):
					_check(enemy["damage"] == 2 and enemy["max_hp"] == ceili(30 * 1.25) and is_equal_approx(float(enemy["speed"]), 3.65 * 0.9), "Fourth regular spawn uses its resource damage and scaled stats without a spawning branch")
		saw_fourth = saw_fourth or regular_roster.has(String(fourth.id))
		var locked := MatchCombat.new(rules, null, _wave_rng(seed_value))
		locked.wave = 2
		locked.start_wave(_routes())
		_check(not locked.wave_roster.has(String(fourth.id)), "Fourth resource unlock is enforced without a special branch")
	_check(variants.size() > 1 and saw_fourth, "Distinct seeds vary ordered composition and include the constrained fourth resource")


func _test_resource_damage_and_roster_clearance() -> void:
	var rules := CombatRules.new()
	rules.base_health = 2
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 5.0
	var combat := MatchCombat.new(rules, null, _wave_rng(13))
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routes(100, 1))
	_check(combat.enemies[1][0]["damage"] == 3, "Queued Brute captures resource damage before movement")
	combat.advance(0.8)
	_check(combat.base_health == [2, 0] and combat.phase == MatchCombat.Phase.FINISHED and combat.winner == 0, "Brute leak applies three damage once and clamps the target base at zero")
	var frozen: Dictionary = combat.snapshot()
	combat.advance(100.0)
	_check(combat.snapshot() == frozen, "Removed Brute cannot damage a finished base a second time")
	rules.base_health = 100
	rules.wave_weight = 16
	combat = MatchCombat.new(rules, null, _wave_rng(17))
	combat.wave = 5
	combat.start_wave(_routes(1, 1))
	var total: int = combat.wave_roster.size()
	_check(total <= rules.wave_weight, "Regular head count cannot exceed its integer weight budget")
	combat.advance(2.0)
	_check(combat.enemies[0].is_empty() and combat.enemies[1].is_empty() and combat.phase == MatchCombat.Phase.WAVE, "Empty alive gap cannot clear while actual roster entries remain scheduled")
	combat.advance((total - 1) * rules.spawn_interval + 2.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.snapshot()["spawned"] == [total, total], "Clearance uses actual mixed roster length rather than weight budget")
