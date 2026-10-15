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
	_test_level_pricing_orders()
	_test_area_kills_and_bounties()
	_test_builtin_upgrade_values()
	_test_wave_scaling_and_rewards()
	_test_enemy_sends()
	_test_typed_enemy_sends()
	_test_typed_enemy_defense()
	_test_weighted_wave_constraints_and_streams()
	_test_weighted_wave_randomness_and_extension()
	_test_growing_count_caps()
	_test_resource_damage_and_roster_clearance()
	_test_simultaneous_and_ordinary_outcomes()
	_test_shortest_branch_assignment()
	_test_nested_branch_assignment()
	_test_routing_validation()
	_test_special_transactions()
	_test_second_archer_targets_and_cadence()
	_test_ballista_bounce()
	_test_ballista_configuration()
	_test_ballista_pierce_geometry()
	_test_ballista_pierce_deaths_and_policies()
	_test_ballista_pierce_snapshot_lifecycle()
	_test_evolution_configuration()
	_test_rune_continuous_damage()
	_test_rune_fraction_isolation_and_cleanup()
	_test_onyx_pulses()
	_test_rune_evolution_persistence()
	_test_special_snapshot_and_growth()
	_test_freeze_transactions()
	_test_freeze_damage_and_expiry()
	_test_freeze_source_isolation()
	_test_slow_motion_history()
	_test_debug_round_reset()
	if failures == 0:
		print("PASS: authoritative purchases/upgrades/sales, currency and reward atomicity, per-tower kills, tile range/AoE, scaling, resource stats, targeting, captured routes and frozen outcomes")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


# These existing tower/stream regressions isolate three single-member identities.
# Shipped progression, groups and abilities are covered by enemy_mechanics_test.
func _catalog_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog.enemies = [
		preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/runner.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/brute.tres").duplicate() as EnemyDefinition,
	]
	for enemy: EnemyDefinition in rules.catalog.enemies:
		enemy.send_first_wave = 1
	rules.catalog.enemies[1].first_wave = 3
	rules.catalog.enemies[2].first_wave = 6
	return rules


func _rules() -> CombatRules:
	var rules := _catalog_rules()
	rules.base_health = 10
	rules.enemy_health = 8
	rules.enemy_speed = 1.0
	rules.wave_weight = 3
	rules.spawn_interval = 0.5
	# These combat/economy fixtures intentionally isolate regular cadence from timing variation.
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	rules.catalog.towers = [_definition(&"arrow_tower", 2, 20.0, 0.5)]
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


func _routes(first: int = 10, second: int = 10) -> Array[Dictionary]:
	return [_routing(_line(first)), _routing(_line(second))]


func _routing(route: Array) -> Dictionary:
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	return {"route": route, "next": next}


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
	_check(combat.towers[0][0]["type_id"] == "arrow_tower" and typeof(combat.towers[0][0]["type_id"]) == TYPE_STRING, "Tower type is a network-safe stable String")
	_check(combat.has_tower(0, Vector2i(2, 1)) and not combat.has_tower(1, Vector2i(2, 1)), "Tower cells belong to their own board")
	_check(not combat.build(0, Vector2i(2, 1), &"arrow_tower", 0), "Duplicate cell placement is rejected")
	var id: int = combat.towers[0][0]["id"]
	_check(not combat.set_targeting(1, id, 1) and not combat.set_targeting(0, id, -1) and not combat.set_targeting(0, id, 0), "Wrong board, invalid mode, and no-op targeting leave towers untouched")
	_check(combat.set_targeting(0, id, MatchCombat.TargetMode.CLOSEST), "Existing own tower changes targeting")
	var invalid_routes: Array[Dictionary] = [_routing([]), _routing(_line(10))]
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
	_check(fresh["tower_types"]["arrow_tower"] == _type_snapshot(_rules().catalog.towers[0]), "Tower type titles and all authoritative stats are detached from snapshots")
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
	rules.catalog.towers[0].range_cells = 3.0
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
	var routes: Array[Dictionary] = [_routing([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]), _routing(_line(5))]
	combat.start_wave(routes)
	routes[0]["route"][1] = Vector2i(99, 99)
	routes[1]["next"].clear()
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
	rules.catalog.towers[0].damage = 20
	rules.catalog.towers[0].interval = 0.1
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
	var boundary_shots: Array[int] = [1, 2, 0]
	for index: int in range(type_ids.size()):
		var rules := _catalog_rules()
		var interval: float = rules.catalog.towers[index].interval
		rules.enemy_health = 100
		rules.enemy_speed = 0.0
		rules.wave_weight = 2
		rules.spawn_interval = 0.0
		var combat := MatchCombat.new(rules)
		var type_id: StringName = type_ids[index]
		_check(combat.build(0, Vector2i(0, 1), type_id, 0), "Configured tower %s builds" % type_id)
		combat.build(1, Vector2i(0, 3), type_id, 0)
		combat.build(1, Vector2i(0, 4), type_id, 0)
		combat.start_wave(_routes())
		combat.advance(0.01)
		var second_hp: int = 100 - damages[index] if index == 2 else 100
		_check(combat.enemies[0][0]["hp"] == 100 - damages[index] and combat.enemies[0][1]["hp"] == second_hp, "Tower %s performs its configured single-target or full-footprint damage" % type_id)
		_check(combat.enemies[1][0]["hp"] == 100 - boundary_shots[index] * damages[index] and combat.enemies[1][1]["hp"] == 100, "Tower %s uses its own tile range at three- and four-cell boundaries" % type_id)
		combat.advance(interval * 0.9)
		_check(combat.towers[0][0]["shot"] == 1 and combat.enemies[0][0]["hp"] == 100 - damages[index], "Tower %s cannot fire before its own interval" % type_id)
		combat.advance(interval * 0.2)
		_check(combat.towers[0][0]["shot"] == 2 and combat.enemies[0][0]["hp"] == 100 - 2 * damages[index], "Tower %s fires again after its own interval" % type_id)


func _test_custom_tower_definition() -> void:
	var rules := _catalog_rules()
	rules.enemy_health = 20
	rules.enemy_speed = 0.0
	rules.wave_weight = 1
	# Detach the default array before adding a local definition; never mutate shared resources.
	rules.catalog.towers = rules.catalog.towers.duplicate()
	var custom := _definition(&"test_fourth_tower", 9, 6.0, 0.2)
	custom.reward.title = "Test fourth tower"
	rules.catalog.towers.append(custom)
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
		"cost": definition.cost, "upgrade_base_cost": definition.upgrade_base_cost,
		"damage_upgrade_bonus": definition.damage_upgrade_bonus,
		"speed_upgrade_multiplier": definition.speed_upgrade_multiplier,
		"area_attack": definition.area_attack,
		"special_upgrade": definition.special_upgrade,
		"special_upgrade_title": definition.special_upgrade_title,
		"special_upgrade_cost": definition.special_upgrade_cost,
		"evolutions": definition.evolutions.duplicate(true),
	}


func _test_economy_and_upgrades() -> void:
	var rules := _rules()
	rules.starting_coins = 120
	var combat := MatchCombat.new(rules)
	_check(combat.coins == [120, 120], "Each player starts with the configured Coins")
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.coins == [75, 120], "Purchase spends the owning player's exact price")
	var id: int = combat.towers[0][0]["id"]
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.upgrade_tower(1, id, "damage") and not combat.sell_tower(1, id) and not combat.upgrade_tower(0, id, "unknown") and not combat.sell_tower(0, -1), "Wrong owner, missing tower and unknown upgrade are rejected")
	_check(not combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.snapshot() == frozen, "Invalid purchases and tower commands spend nothing or change stats/IDs")
	_check(combat.upgrade_tower(0, id, "damage") and combat.coins[0] == 45 and combat.towers[0][0]["damage"] == 3 and combat.towers[0][0]["damage_upgraded"], "One-time damage purchase applies its configured bonus atomically")
	combat.start_wave(_routes())
	combat.advance(0.1)
	var cooldown: float = combat.towers[0][0]["cooldown"]
	_check(combat.upgrade_tower(0, id, "speed") and combat.coins[0] == 0, "Exact remaining Coins buy a speed upgrade during combat")
	var tower: Dictionary = combat.towers[0][0]
	_check(tower["speed_upgraded"] and is_equal_approx(tower["interval"], 0.4) and is_equal_approx(tower["cooldown"], cooldown * 0.8) and tower["invested"] == 120 and tower["sell_value"] == 72, "Effective attack interval, reload and invested/refund stats include paid upgrades")
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, id, "damage") and not combat.upgrade_tower(0, id, "speed") and not combat.build(0, Vector2i(2, 1), &"arrow_tower", 0) and combat.snapshot() == frozen, "Repeated upgrades and insufficient-money purchase mutate nothing")
	_check(combat.sell_tower(0, id) and combat.coins[0] == 72 and combat.towers[0].is_empty(), "Live sale refunds 60 percent of actual investment and removes the tower")
	frozen = combat.snapshot()
	_check(not combat.sell_tower(0, id) and not combat.upgrade_tower(0, id, "damage") and combat.snapshot() == frozen, "Repeated sale and stale upgrade cannot grant money or affect removed towers")
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", 0) and combat.towers[0][0]["id"] == id + 1, "Failed purchases do not consume IDs; rebuying gets the next identity")
	var replacement: Dictionary = combat.towers[0][0]
	_check(not replacement["damage_upgraded"] and not replacement["speed_upgraded"] and replacement["kills"] == 0 and replacement["damage"] == 2, "Rebuy has no inherited kills or upgrades")
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, replacement["id"], "damage") and not combat.upgrade_tower(0, replacement["id"], "speed") and combat.snapshot() == frozen, "Unaffordable upgrades leave Coins, readiness-independent stats, and investment untouched")
	_check(combat.sell_tower(0, replacement["id"]) and combat.coins[0] == 54, "Sale/rebuy loses money rather than manufacturing it")
	var rounding_rules := _rules()
	rounding_rules.catalog.towers[0].cost = 46
	combat = MatchCombat.new(rounding_rules)
	combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
	_check(combat.towers[0][0]["sell_value"] == 27 and combat.sell_tower(0, 1) and combat.coins[0] == 181, "Sale floors fractional refund Coins")


func _test_level_pricing_orders() -> void:
	for base_cost: int in [30, 55]:
		for first: String in ["damage", "speed"]:
			var rules := _rules()
			rules.catalog.towers[0].upgrade_base_cost = base_cost
			var second_cost: int = ceili(base_cost * 1.5)
			var invested: int = 45 + base_cost + second_cost
			rules.starting_coins = invested
			var combat := MatchCombat.new(rules)
			combat.build(0, Vector2i(1, 1), &"arrow_tower", 0)
			var tower: Dictionary = combat.towers[0][0]
			var definition: Dictionary = combat.snapshot()["tower_types"]["arrow_tower"]
			var second: String = "speed" if first == "damage" else "damage"
			_check(MatchCombat.tower_level(tower) == 1 and MatchCombat.tower_upgrade_cost(tower, definition) == base_cost, "Fresh tower uses its own base upgrade price at level I")
			_check(combat.upgrade_tower(0, tower["id"], first) and combat.coins[0] == second_cost and MatchCombat.tower_level(tower) == 2, "First %s purchase pays the base price and advances exactly one level" % first)
			_check(MatchCombat.tower_upgrade_cost(tower, definition) == second_cost, "The other stat costs 150 percent of base, rounded up")
			var frozen: Dictionary = combat.snapshot()
			_check(not combat.upgrade_tower(0, tower["id"], first) and combat.snapshot() == frozen, "Repeating the first stat cannot advance level or spend Coins")
			combat.coins[0] = second_cost - 1
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(0, tower["id"], second) and combat.snapshot() == frozen, "One Coin below the increased price cannot buy the second upgrade")
			combat.coins[0] = second_cost
			_check(combat.upgrade_tower(0, tower["id"], second) and combat.coins[0] == 0 and MatchCombat.tower_level(tower) == 3, "Exact increased price buys %s second and reaches level III" % second)
			_check(MatchCombat.tower_upgrade_cost(tower, definition) == 2 * base_cost, "Level III quotes 200 percent of original price, not compounded 225 percent")
			_check(tower["invested"] == invested and tower["sell_value"] == floori(invested * 0.6), "Both purchase orders preserve actual investment and refund")
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(0, tower["id"], second) and combat.snapshot() == frozen, "Repeating either purchased stat cannot advance beyond level III")


func _test_area_kills_and_bounties() -> void:
	var rules := _rules()
	rules.enemy_speed = 0.0
	rules.enemy_health = 2
	rules.spawn_interval = 0.0
	var area := _definition(&"test_area", 2, 1.0, 0.5)
	area.area_attack = true
	rules.catalog.towers = [area]
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
	var rules := _catalog_rules()
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
	var upgrade_prices: Array[int] = [30, 55, 45]
	var effective_damage: Array[int] = [3, 9, 2]
	var multipliers: Array[float] = [0.8, 0.75, 0.85]
	for index: int in range(ids.size()):
		var rules := _catalog_rules()
		rules.starting_coins = 300
		rules.enemy_health = 100
		rules.enemy_speed = 0.0
		rules.wave_weight = 1
		var combat := MatchCombat.new(rules)
		combat.build(0, Vector2i(0, 1), ids[index], 0)
		var id: int = combat.towers[0][0]["id"]
		_check(combat.upgrade_tower(0, id, "damage") and combat.upgrade_tower(0, id, "speed"), "Both configured one-time upgrades succeed with sufficient funds for %s" % ids[index])
		combat.start_wave(_routes())
		combat.advance(0.01)
		var tower: Dictionary = combat.towers[0][0]
		var type_stats: Dictionary = combat.snapshot()["tower_types"][String(ids[index])]
		_check(tower["damage"] == effective_damage[index] and combat.enemies[0][0]["hp"] == 100 - effective_damage[index] and is_equal_approx(tower["cooldown"], type_stats["interval"] * multipliers[index]), "Tower %s attacks using purchased effective damage and interval" % ids[index])
		var total_upgrades: int = upgrade_prices[index] + ceili(upgrade_prices[index] * 1.5)
		_check(combat.coins[0] == 300 - costs[index] - total_upgrades and tower["invested"] == costs[index] + total_upgrades, "Tower %s pays its original base price plus a 50-percent higher second price" % ids[index])


func _test_enemy_sends() -> void:
	var rules := _rules()
	rules.starting_coins = 40
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	var combat := MatchCombat.new(rules)
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.send_enemy(-1, &"grunt") and not combat.send_enemy(2, &"grunt") and combat.snapshot() == frozen, "Invalid send payer changes no Coins, income, queues or enemies")
	_check(combat.send_enemy(0, &"grunt") and combat.coins == [20, 40] and combat.income == [2, 0] and combat.queued_sends == [0, 1] and combat.enemies == [[], []], "Planning sends pay now and reserve exactly one enemy on the opponent, without route access")
	var copy: Dictionary = combat.snapshot()
	copy["income"][0] = 999
	copy["queued_sends"][1] = 999
	_check(combat.income == [2, 0] and combat.queued_sends == [0, 1], "Client snapshot income/queue mutations cannot affect the host")
	var invalid_routes: Array[Dictionary] = [_routing([]), _routing(_line(4))]
	frozen = combat.snapshot()
	_check(not combat.start_wave(invalid_routes) and combat.snapshot() == frozen, "Invalid wave start preserves paid queued delivery")
	combat.start_wave(_routes(4, 4))
	_check(combat.queued_sends == [0, 0] and combat.enemies[0].is_empty() and combat.enemies[1].size() == 1 and combat.enemies[1][0]["pos"] == Vector2.ZERO and combat.enemies[1][0]["hp"] == 8, "Starting a legal wave delivers the paid enemy at the opponent entrance with existing wave stats")
	_check(combat.send_enemy(0, &"grunt") and combat.coins == [0, 40] and combat.income == [4, 0] and combat.enemies[1].size() == 1 and combat.queued_sends == [0, 1], "Exact funds reserve the next paced delivery and grow only sender income")
	frozen = combat.snapshot()
	_check(not combat.send_enemy(0, &"grunt") and combat.snapshot() == frozen, "Unaffordable send cannot create a free enemy, income or reservation")
	combat.advance(1.0)
	_check(combat.queued_sends == [0, 0] and combat.enemies[0].size() == 1 and combat.enemies[1].size() == 3, "Paced sent enemies coexist with the unmodified regular stream")
	_check(combat.send_enemy(1, &"grunt") and combat.coins == [0, 20] and combat.income == [4, 2] and combat.queued_sends == [0, 0] and combat.enemies[0].size() == 2, "An available opposite stream delivers into the current combat")
	_run_wave(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health == [8, 7], "Both boards clear including every accepted send; each sent enemy causes ordinary base damage")
	_check(combat.coins == [39, 57] and combat.queued_sends == [0, 0], "Clear pays shared reward plus each sender's recurring bonus once, with no duplicate deferred orders")
	frozen = combat.snapshot()
	_check(not combat.advance(10.0) and combat.snapshot() == frozen, "Idle planning cannot pay income or deliver queued enemies again")
	combat.start_wave(_routes(4, 4))
	_check(combat.enemies == [[], []] and combat.queued_sends == [0, 0], "The next combat does not redeliver orders already handled by the send stream")
	_run_wave(combat)
	_check(combat.coins == [83, 99] and combat.base_health == [7, 6], "The same income bonus pays again on a later clear without another send")
	# Sent enemies use ordinary attack, kill attribution and bounty rules.
	rules.starting_coins = 200
	rules.catalog.towers[0].damage = 100
	rules.catalog.towers[0].interval = 0.01
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
	_check(combat.enemies[1].size() == 1 and combat.snapshot()["send_queues"][1] == ["brute"], "Wave start delivers only the first mixed FIFO order")
	combat.advance(1.0)
	var brute: Dictionary = combat.enemies[1][2]
	_check(runner["type_id"] == "runner" and runner["hp"] == 5 and is_equal_approx(runner["speed"], 1.7) and brute["type_id"] == "brute" and brute["hp"] == 20 and is_equal_approx(brute["speed"], 0.65), "Queued types use rounded health and their own wave-scaled speeds")
	_check(is_equal_approx(runner["progress"], 1.7) and is_equal_approx(brute["progress"], (1.0 - rules.send_spawn_interval) * 0.65) and is_equal_approx(combat.enemies[1][1]["progress"], 1.0) and combat.enemies[1][1]["type_id"] == "grunt", "Mixed sent travel begins at its own due time while first-wave regular Grunts keep their schedule")
	combat.advance(1.4)
	_check(combat.base_health == [10, 9] and combat.enemies[1].size() == 2 and combat.enemies[1][1]["type_id"] == "brute", "Runner reaches the base first while slower Brute and regular Grunt remain in combat")
	_run_wave(combat)
	_check(combat.base_health == [9, 5] and combat.coins == [176, 235], "Brute leaks three damage once and clear pays only sender's purchased income bonus")
	var preview: Dictionary = combat.snapshot()["enemy_types"]
	_check(preview["runner"]["health"] == 6 and preview["brute"]["health"] == 25 and is_equal_approx(preview["runner"]["speed"], 1.15 * 1.7), "Planning previews the next wave's effective typed stats, not the cleared wave")
	combat.start_wave(_routes(4, 4))
	combat.advance(1.0)
	combat.send_enemy(1, &"brute")
	combat.send_enemy(1, &"runner")
	_check(combat.snapshot()["send_queues"] == [["runner"], []] and combat.queued_sends == [1, 0] and combat.enemies[0].size() == 2, "Live mixed sends deliver the first available order and pace its FIFO successor in this combat")
	combat.advance(rules.send_spawn_interval + 0.01)
	_check(combat.enemies[0].size() == 3 and combat.enemies[0][1]["type_id"] == "brute" and combat.enemies[0][2]["type_id"] == "runner" and combat.enemies[0][1]["hp"] == 25 and combat.enemies[0][2]["hp"] == 6 and combat.queued_sends == [0, 0], "Both live types use current wave-two stats, not a deferred wave")
	_run_wave(combat)
	combat.start_wave(_routes(4, 4))
	_check(combat.enemies == [[], []], "Delivered mixed orders are absent from the following wave")
	# Resource edits after admission cannot rewrite captured type rules.
	var detached: EnemyDefinition = rules.catalog.enemies[1].duplicate()
	rules.catalog.enemies = rules.catalog.enemies.duplicate()
	rules.catalog.enemies[1] = detached
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
	rules.catalog.towers[0].damage = 5
	rules.catalog.towers[0].interval = 0.1
	var combat := MatchCombat.new(rules)
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routes())
	combat.advance(rules.send_spawn_interval + 0.01)
	combat.build(1, Vector2i(0, 1), &"arrow_tower", MatchCombat.TargetMode.STRONGEST)
	combat.advance(0.01)
	_check(combat.enemies[1][0]["hp"] == 5 and combat.enemies[1][2]["hp"] == 15 and combat.towers[1][0]["target_id"] == combat.enemies[1][2]["id"], "Strongest targets the delivered durable Brute in a mixed stream instead of the Runner")
	combat.set_targeting(1, combat.towers[1][0]["id"], MatchCombat.TargetMode.FURTHEST)
	combat.advance(0.1)
	_check(combat.enemies[1].size() == 2 and combat.towers[1][0]["kills"] == 1 and combat.coins[1] == 158, "A killed Runner pays the normal bounty once and is removed before leaks")
	var area := _definition(&"test_area", 5, 1.0, 0.1)
	area.area_attack = true
	rules.catalog.towers = [area]
	combat = MatchCombat.new(rules)
	combat.send_enemy(0, &"runner")
	combat.send_enemy(0, &"brute")
	combat.start_wave(_routes())
	combat.advance(rules.send_spawn_interval + 0.01)
	combat.build(1, Vector2i(0, 1), &"test_area", 0)
	combat.advance(0.01)
	_check(combat.enemies[1].size() == 2 and combat.enemies[1][1]["type_id"] == "brute" and combat.enemies[1][1]["hp"] == 15 and combat.towers[1][0]["kills"] == 1, "Area attacks hit the whole delivered mixed footprint, killing the fragile Runner while Brute survives")


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
		var base_cap: int = definition["max_per_wave"]
		var growth_steps: int = floori(float(maxi(0, wave_number - int(definition["first_wave"]))) / int(definition["count_cap_growth_interval"]))
		var cap: int = base_cap + growth_steps * int(definition["count_cap_growth"])
		_check(base_cap == 0 or count <= cap, "Regular type respects its wave-scaled hard count cap")
		_check(count * int(definition["spawn_weight"]) <= floori(budget * float(definition["max_weight_share"])), "Regular type respects floored total-weight share")
	_check(weight == budget and state["total"] == state["wave_roster"].size(), "Regular roster fills exact integer budget and reports actual count")


func _test_weighted_wave_constraints_and_streams() -> void:
	var saw_runner: bool = false
	var saw_brute: bool = false
	for seed_value: int in range(16):
		var rules := _catalog_rules()
		rules.base_health = 10000
		# Roster/stat fixture fixes jitter; interval progression has its own boundary suite.
		rules.spawn_jitter_ratio = 0.0
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
				combat.advance(0.01 if index == 0 else combat.spawn_times[index] - combat.spawn_times[index - 1])
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


func _test_growing_count_caps() -> void:
	# Large budgets isolate count growth; a separate share-limited case proves precedence.
	var rules := _catalog_rules()
	rules.wave_weight = 100
	rules.wave_weight_growth = 0
	rules.catalog.enemies = rules.catalog.enemies.duplicate()
	var growing := EnemyDefinition.new()
	growing.id = &"test_growing_enemy"
	growing.title = "Growing"
	growing.spawn_weight = 2
	growing.first_wave = 4
	growing.max_per_wave = 2
	growing.count_cap_growth = 2
	growing.count_cap_growth_interval = 3
	growing.max_weight_share = 1.0
	rules.catalog.enemies = [rules.catalog.enemies[0], growing]
	for example: Vector2i in [Vector2i(3, 0), Vector2i(4, 2), Vector2i(6, 2), Vector2i(7, 4), Vector2i(9, 4), Vector2i(10, 6)]:
		var combat := MatchCombat.new(rules, null, _wave_rng(17))
		combat.wave = example.x - 1
		combat.start_wave(_routes(1000, 1000))
		_check(combat.wave_roster.count(String(growing.id)) == example.y, "Real roster honors unlock-relative cap growth at wave %d" % example.x)
		_check_roster_constraints(combat.snapshot(), example.x)
	growing.max_weight_share = 0.05
	var shared := MatchCombat.new(rules, null, _wave_rng(17))
	shared.wave = 99
	shared.start_wave(_routes(1000, 1000))
	_check(shared.wave_roster.count(String(growing.id)) == 2, "Weight-share ceiling still limits a much larger grown hard cap")
	_check_roster_constraints(shared.snapshot(), 100)
	growing.max_per_wave = 0
	growing.max_weight_share = 1.0
	var unlimited := MatchCombat.new(rules, null, _wave_rng(17))
	unlimited.wave = 3
	unlimited.start_wave(_routes(1000, 1000))
	_check(unlimited.wave_roster.count(String(growing.id)) > 2, "Zero base cap remains unlimited rather than becoming a finite grown cap")
	_check_roster_constraints(unlimited.snapshot(), 4)
	for type_id: String in ["runner", "brute"]:
		var late := MatchCombat.new(_catalog_rules(), null, _wave_rng(17))
		late.wave = 49
		late.start_wave(_routes(1000, 1000))
		var original_limit: int = 4 if type_id == "runner" else 2
		_check(late.wave_roster.count(type_id) > original_limit, "Late shipped waves can exceed the original fixed %s cap" % type_id)
		_check_roster_constraints(late.snapshot(), 50)


func _test_weighted_wave_randomness_and_extension() -> void:
	var variants: Dictionary = {}
	var rules := _catalog_rules()
	rules.catalog.enemies = rules.catalog.enemies.duplicate()
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
	rules.catalog.enemies.append(fourth)
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
	var rules := _catalog_rules()
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


func _branch_routing(three_way: bool = false) -> Dictionary:
	var top: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2)]
	var bottom: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 2)]
	var result: Dictionary = _routing(top)
	var other: Dictionary = _routing(bottom)
	for cell: Vector2i in other["next"]:
		if not result["next"].has(cell):
			result["next"][cell] = other["next"][cell]
	result["next"][Vector2i(1, 2)] = [Vector2i(1, 1), Vector2i(1, 3)]
	if three_way:
		result["next"][Vector2i(1, 2)].append(Vector2i(2, 2))
		result["next"][Vector2i(2, 2)] = [Vector2i(2, 1), Vector2i(2, 3)]
	return result


func _test_shortest_branch_assignment() -> void:
	for choices: int in [2, 3]:
		var rules := _rules()
		rules.base_health = 100
		rules.starting_coins = 1000
		rules.wave_weight = 4
		rules.spawn_interval = 0.0
		var combat := MatchCombat.new(rules)
		var graph: Dictionary = _branch_routing(choices == 3)
		var accepted: Dictionary = graph.duplicate(true)
		var routing: Array[Dictionary] = [graph, graph]
		_check(combat.send_enemy(1, &"grunt"), "Planning send queues a route assignment for board zero")
		_check(combat.start_wave(routing), "%d-way shortest graph starts" % choices)
		# Every delivered source consumes the same cursor; waiting orders consume none.
		_check(combat.enemies[0][0]["route"][2] == Vector2i(1, 1), "First queued send receives the first fork choice")
		_check(combat.send_enemy(1, &"grunt") and combat.enemies[0].size() == 1 and combat.queued_sends == [1, 0], "A cooling-down send reserves no route before delivery")
		graph["route"].clear()
		graph["next"][Vector2i(1, 2)].clear()
		combat.advance(0.1)
		combat.advance(0.3)
		var expected: Array = accepted["next"][Vector2i(1, 2)]
		for index: int in range(combat.enemies[0].size()):
			var enemy: Dictionary = combat.enemies[0][index]
			_check(enemy["route"][2] == expected[index % choices], "Board zero assignments rotate all %d choices, index %d" % [choices, index])
			_check(enemy["route"].size() == accepted["route"].size(), "Every assigned branch has canonical shortest length")
		for index: int in range(combat.enemies[1].size()):
			_check(combat.enemies[1][index]["route"][2] == expected[index % choices], "Other board starts its independent fork counter")
		var snapshot: Dictionary = combat.snapshot()
		snapshot["enemies"][0][0]["route"].clear()
		_check(combat.enemies[0][0]["route"].size() == 8 and combat.enemies[0][1]["route"].size() == 8, "Snapshots and other enemies cannot alias a captured instance route")
		var surviving_route: Array = combat.enemies[0][1]["route"].duplicate()
		combat.enemies[0].remove_at(0)
		_check(combat.enemies[0][0]["route"] == surviving_route, "Death before a fork never reassigns an already accepted path")
		_check(combat.send_enemy(1, &"grunt"), "Further accepted send follows prior assignment history")
		combat.advance(0.31)
		var last: Dictionary = combat.enemies[0].back()
		_check(last["route"][2] == expected[6 % choices], "Removing an enemy never rewinds the fork counter")
		combat.advance(1.79)
		var top_enemy: Dictionary = combat.enemies[1][0]
		var bottom_enemy: Dictionary = combat.enemies[1][1]
		_check(top_enemy["pos"].is_equal_approx(Vector2(1.5, 1)) and bottom_enemy["pos"].is_equal_approx(Vector2(1.5, 3)), "Equal-progress instances actually move on their own branches")
		var tower: Dictionary = {"cell": Vector2i(2, 1), "mode": MatchCombat.TargetMode.CLOSEST}
		_check(combat._target(1, tower, 0.5) == 0, "Range and closest targeting use each branch's actual position")
		_run_wave(combat)
		_check(combat.base_health == [94, 96] and combat.phase == MatchCombat.Phase.PLANNING, "Every remaining assigned route leaks once at its own endpoint")
		var reset_routing: Array[Dictionary] = [accepted, accepted]
		_check(combat.start_wave(reset_routing), "Next wave accepts captured routing again")
		combat.advance(0.1)
		_check(combat.enemies[0][0]["route"][2] == expected[0] and combat.enemies[1][0]["route"][2] == expected[0], "Each wave resets both boards' fork cursors")


func _test_nested_branch_assignment() -> void:
	var rules := _rules()
	rules.wave_weight = 12
	rules.spawn_interval = 0.0
	var combat := MatchCombat.new(rules)
	var graph: Dictionary = _branch_routing(true)
	var routing: Array[Dictionary] = [graph, graph]
	_check(combat.start_wave(routing), "Nested forks and rejoins start without enumerating routes")
	combat.advance(0.1)
	var nested: Array = []
	for enemy: Dictionary in combat.enemies[0]:
		if enemy["route"][2] == Vector2i(2, 2):
			nested.append(enemy["route"][3])
		_check(enemy["route"].back() == Vector2i(5, 2) and enemy["route"].size() == 8, "All nested/rejoined paths end at base at equal distance")
	_check(nested == [Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 1), Vector2i(2, 3)], "Nested fork rotates only for enemies whose preassigned route visits it")
	# A real layout has a straight shortest connection and a connected longer loop.
	var layout := PathLayout.new(Vector2i(6, 5), 30, Vector2i(0, 2), Vector2i(5, 2))
	for x: int in range(1, 5):
		layout.place(Vector2i(x, 2))
	for x: int in range(0, 6):
		layout.place(Vector2i(x, 1))
	var shortest: Dictionary = layout.capture_routing()
	var straight_routing: Array[Dictionary] = [shortest, shortest]
	combat = MatchCombat.new(rules)
	_check(combat.start_wave(straight_routing), "Real captured layout includes connected longer pavement")
	combat.advance(0.1)
	for enemy: Dictionary in combat.enemies[0]:
		_check(enemy["route"].size() == 6, "Longer connected alternatives never enter assigned routes")
		for cell: Vector2i in enemy["route"]:
			_check(cell.y == 2, "Shortest movement never takes the longer loop")


func _test_routing_validation() -> void:
	var combat := MatchCombat.new(_rules())
	combat.send_enemy(1, &"grunt")
	var frozen: Dictionary = combat.snapshot()
	var valid: Dictionary = _branch_routing()
	var cyclic: Dictionary = valid.duplicate(true)
	cyclic["next"][Vector2i(1, 1)].append(Vector2i(1, 2))
	var dead_end: Dictionary = valid.duplicate(true)
	dead_end["next"][Vector2i(1, 1)] = []
	var longer: Dictionary = valid.duplicate(true)
	longer["next"][Vector2i(2, 1)].append(Vector2i(2, 0))
	longer["next"][Vector2i(2, 0)] = [Vector2i(3, 0)]
	longer["next"][Vector2i(3, 0)] = [Vector2i(3, 1)]
	for invalid: Dictionary in [cyclic, dead_end, longer, {"route": valid["route"], "next": {}}, {"route": [], "next": {}}]:
		var routing: Array[Dictionary] = [valid, invalid]
		_check(not combat.start_wave(routing) and combat.snapshot() == frozen, "Invalid second graph rejects atomically without consuming sends or wave state")


func _special_rules(type_id: StringName, hp: int = 100, count: int = 3) -> CombatRules:
	var rules := _catalog_rules()
	rules.starting_coins = 10000
	rules.enemy_health = hp
	rules.enemy_speed = 0.0
	rules.wave_weight = count
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	var definition: TowerDefinition = load("res://resources/combat/towers/%s.tres" % type_id).duplicate(true)
	rules.catalog.towers = [definition]
	return rules


func _prepared_special(rules: CombatRules, type_id: StringName) -> MatchCombat:
	var combat := MatchCombat.new(rules)
	_check(combat.build(0, Vector2i(0, 1), type_id, MatchCombat.TargetMode.FURTHEST), "Special fixture builds a paid tower")
	var tower: Dictionary = combat.towers[0][0]
	_check(combat.upgrade_tower(0, tower["id"], "damage") and combat.upgrade_tower(0, tower["id"], "speed"), "Special fixture pays both prerequisite stats")
	return combat


func _test_special_transactions() -> void:
	var ids: Array[StringName] = [&"arrow_tower", &"orc_ballista", &"orc_ballista", &"rune_obelisk", &"rune_obelisk"]
	var upgrades: Array[String] = ["special", "pierce", "bounce", "boulders", "onyx_ring"]
	for index: int in range(ids.size()):
		var upgrade: String = upgrades[index]
		for first: String in ["damage", "speed"]:
			var rules := _special_rules(ids[index])
			var combat := MatchCombat.new(rules)
			combat.build(0, Vector2i(0, 1), ids[index], MatchCombat.TargetMode.CLOSEST)
			var tower: Dictionary = combat.towers[0][0]
			var id: int = tower["id"]
			var type_stats: Dictionary = combat.snapshot()["tower_types"][String(ids[index])]
			var price: int = type_stats["special_upgrade_cost"] if upgrade == "special" else type_stats["evolutions"][upgrade]["cost"]
			var frozen: Dictionary = combat.snapshot()
			_check(tower["evolution"] == "" and not combat.upgrade_tower(0, id, upgrade) and not combat.set_secondary_targeting(0, id, 2) and combat.snapshot() == frozen, "Special/evolution and secondary policy are locked at level I for %s" % ids[index])
			combat.upgrade_tower(0, id, first)
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(0, id, upgrade) and combat.snapshot() == frozen, "One prerequisite never unlocks a final upgrade for either stat order")
			combat.upgrade_tower(0, id, "speed" if first == "damage" else "damage")
			var stat_investment: int = tower["invested"]
			var stat_damage: int = tower["damage"]
			var stat_interval: float = tower["interval"]
			tower["cooldown"] = stat_interval * 0.6
			var stat_reload: float = tower["cooldown"]
			_check(MatchCombat.tower_level(tower) == 3 and not tower["special_upgraded"], "Both ordinary purchases reach III, not IV")
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(1, id, upgrade) and not combat.upgrade_tower(-1, id, upgrade) and not combat.upgrade_tower(2, id, upgrade) and not combat.upgrade_tower(0, id + 100, upgrade) and combat.snapshot() == frozen, "Wrong ownership, invalid slots and missing tower reject final upgrades atomically")
			if ids[index] != &"arrow_tower":
				_check(not combat.upgrade_tower(0, id, "special") and combat.snapshot() == frozen, "Evolution types have no obsolete generic special command")
			else:
				_check(not combat.upgrade_tower(0, id, "boulders") and not combat.upgrade_tower(0, id, "onyx_ring") and combat.snapshot() == frozen, "Non-Rune types cannot purchase Rune branches")
			combat.coins[0] = price - 1
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(0, id, upgrade) and combat.snapshot() == frozen, "One Coin short of the captured fixed price spends nothing")
			combat.coins[0] += 1
			_check(combat.upgrade_tower(0, id, upgrade) and combat.coins[0] == 0, "Exact fixed final-upgrade price succeeds for %s" % upgrade)
			_check(MatchCombat.tower_level(tower) == 4 and tower["invested"] == stat_investment + price and tower["sell_value"] == floori(float(tower["invested"]) * 0.6), "Accepted final upgrade reaches IV and contributes actual payment to refund")
			if ids[index] == &"rune_obelisk":
				var config: Dictionary = type_stats["evolutions"][upgrade]
				_check(tower["evolution"] == upgrade and tower["damage"] == config["damage"] and is_equal_approx(tower["interval"], config["interval"]), "Rune evolution replaces effective damage and interval with its captured branch stats")
			elif ids[index] == &"orc_ballista":
				_check(tower["evolution"] == upgrade and tower["damage"] == stat_damage and tower["interval"] == stat_interval and tower["cooldown"] == stat_reload, "Ballista branch preserves upgraded damage, cadence and live cooldown")
			combat.coins[0] = 10000
			frozen = combat.snapshot()
			_check(not combat.upgrade_tower(0, id, upgrade) and not combat.upgrade_tower(0, id, "damage") and not combat.upgrade_tower(0, id, "speed") and not combat.upgrade_tower(0, id, "boulders") and not combat.upgrade_tower(0, id, "onyx_ring") and not combat.upgrade_tower(0, id, "pierce") and not combat.upgrade_tower(0, id, "bounce") and combat.snapshot() == frozen, "Final choice excludes both branches and all repeat purchases even when funded")
			if ids[index] != &"arrow_tower":
				_check(not combat.set_secondary_targeting(0, id, 2) and combat.snapshot() == frozen, "Non-archer upgrades cannot acquire a secondary targeting policy")
			var refund: int = tower["sell_value"]
			_check(combat.sell_tower(0, id) and combat.coins[0] == 10000 + refund, "Sale includes sixty percent of all four paid levels")
			frozen = combat.snapshot()
			_check(not combat.sell_tower(0, id) and not combat.upgrade_tower(0, id, upgrade) and combat.snapshot() == frozen, "Stale final upgrade and repeat sale cannot mint a refund")
		var terminal := _prepared_special(_special_rules(ids[index]), ids[index])
		terminal.phase = MatchCombat.Phase.FINISHED
		var frozen_terminal: Dictionary = terminal.snapshot()
		_check(not terminal.upgrade_tower(0, terminal.towers[0][0]["id"], upgrade) and not terminal.set_secondary_targeting(0, terminal.towers[0][0]["id"], 2) and terminal.snapshot() == frozen_terminal, "Terminal final-upgrade and secondary commands preserve the frozen outcome")
	var ordinary := _prepared_special(_rules(), &"arrow_tower")
	var no_special: Dictionary = ordinary.snapshot()
	_check(not ordinary.upgrade_tower(0, ordinary.towers[0][0]["id"], "special") and ordinary.snapshot() == no_special, "Custom tower without a special cannot buy a no-effect level")


func _test_second_archer_targets_and_cadence() -> void:
	var combat := _prepared_special(_special_rules(&"arrow_tower"), &"arrow_tower")
	var tower: Dictionary = combat.towers[0][0]
	_check(tower["secondary_mode"] == tower["mode"], "Secondary policy starts as the build-time primary policy")
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	var old_interval: float = tower["interval"]
	var old_reload: float = tower["cooldown"]
	_check(combat.upgrade_tower(0, tower["id"], "special") and is_equal_approx(tower["interval"], old_interval / 1.1) and is_equal_approx(tower["cooldown"], old_reload / 1.1), "Second archer raises attacks per second by ten percent and rescales the live reload proportionally")
	_check(tower["shot"] == 1 and tower["secondary_shot"] == 0, "Buying a second archer does not grant a free immediate attack")
	var primary_mode: int = tower["mode"]
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.set_secondary_targeting(1, tower["id"], 2) and not combat.set_secondary_targeting(0, tower["id"], -1) and not combat.set_secondary_targeting(0, tower["id"], 3) and not combat.set_secondary_targeting(0, tower["id"], primary_mode) and combat.snapshot() == frozen, "Secondary policy validates owner, bounds and no-op atomically")
	_check(combat.set_secondary_targeting(0, tower["id"], MatchCombat.TargetMode.STRONGEST) and tower["mode"] == primary_mode, "Secondary policy changes without changing primary policy")
	combat.enemies[0][0]["progress"] = 2.0
	combat.enemies[0][1]["progress"] = 1.0
	combat.enemies[0][2]["progress"] = 0.0
	combat.enemies[0][0]["hp"] = 80
	combat.enemies[0][1]["hp"] = 60
	combat.enemies[0][2]["hp"] = 90
	combat.advance(float(tower["cooldown"]) * 0.99)
	_check(tower["shot"] == 1 and tower["secondary_shot"] == 0, "Neither archer attacks before the accelerated remaining reload")
	combat.advance(float(tower["interval"]) * 0.02)
	_check(tower["shot"] == 2 and tower["secondary_shot"] == 1 and combat.enemies[0][0]["hp"] == 77 and combat.enemies[0][1]["hp"] == 60 and combat.enemies[0][2]["hp"] == 87, "Independent furthest and strongest policies fire one full-damage arrow at distinct targets")
	_check(tower["target_id"] == combat.enemies[0][0]["id"] and tower["secondary_target_id"] == combat.enemies[0][2]["id"] and tower["aim"] == Vector2(2, 0) and tower["secondary_aim"] == Vector2.ZERO, "Each arrow publishes its own accepted target and aim")
	for volley: int in range(5):
		var shots: int = tower["shot"]
		combat.advance(float(tower["interval"]) * 0.99)
		_check(tower["shot"] == shots, "True special cadence does not fire before its interval")
		combat.advance(float(tower["interval"]) * 0.011)
		_check(tower["shot"] == shots + 1, "True special cadence fires at the interval divided by 1.1")
	# Both policies prefer the same enemy; exclusion still guarantees a second victim.
	combat = _prepared_special(_special_rules(&"arrow_tower", 100, 2), &"arrow_tower")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 97 and combat.enemies[0][1]["hp"] == 97 and tower["target_id"] != tower["secondary_target_id"], "Identical policies cannot double-hit the primary target")
	combat = _prepared_special(_special_rules(&"arrow_tower", 3, 2), &"arrow_tower")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes())
	var before: int = combat.coins[0]
	combat.advance(0.01)
	_check(combat.enemies[0].is_empty() and tower["kills"] == 2 and tower["secondary_shot"] == 1 and tower["secondary_target_id"] != tower["target_id"] and combat.coins[0] == before + 2 * int(combat.snapshot()["rules"]["kill_bounty"]), "Primary kill and array removal do not skip or revisit the second victim; both kills pay bounty")
	combat = _prepared_special(_special_rules(&"arrow_tower", 100, 1), &"arrow_tower")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 97 and tower["shot"] == 1 and tower["secondary_shot"] == 0 and tower["secondary_target_id"] == -1, "A sole living enemy never receives a second arrow")
	combat = _prepared_special(_special_rules(&"arrow_tower", 3, 1), &"arrow_tower")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0].is_empty() and tower["secondary_shot"] == 0, "Killing the only enemy does not manufacture a second arrow event")
	combat = _prepared_special(_special_rules(&"arrow_tower", 100, 3), &"arrow_tower")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	combat.set_secondary_targeting(0, tower["id"], MatchCombat.TargetMode.CLOSEST)
	combat.set_targeting(0, tower["id"], MatchCombat.TargetMode.STRONGEST)
	_check(tower["secondary_mode"] == MatchCombat.TargetMode.CLOSEST, "Changing the primary policy leaves the secondary policy independent")
	combat.enemies[0][0]["progress"] = 3.0
	combat.enemies[0][0]["hp"] = 100
	combat.enemies[0][1]["progress"] = 0.0
	combat.enemies[0][1]["hp"] = 90
	combat.enemies[0][2]["progress"] = 4.0
	combat.enemies[0][2]["hp"] = 1000
	combat.advance(float(tower["interval"]))
	_check(combat.enemies[0][0]["hp"] == 97 and combat.enemies[0][1]["hp"] == 87 and combat.enemies[0][2]["hp"] == 1000, "Independent strongest primary and closest secondary both respect the original tower range")
	var secondary_shots: int = tower["secondary_shot"]
	combat.enemies[0][0]["progress"] = 0.0
	combat.enemies[0][1]["progress"] = 5.0
	combat.enemies[0][2]["progress"] = 6.0
	combat.advance(float(tower["interval"]))
	_check(combat.enemies[0][0]["hp"] == 94 and combat.enemies[0][1]["hp"] == 87 and combat.enemies[0][2]["hp"] == 1000 and tower["secondary_shot"] == secondary_shots and tower["secondary_target_id"] == -1, "Out-of-range enemies cannot supply a second target or create a phantom secondary event")


func _test_ballista_bounce() -> void:
	# Nine primary damage must round its half-damage bounce up to five.
	var combat := _prepared_special(_special_rules(&"orc_ballista", 100, 4), &"orc_ballista")
	var tower: Dictionary = combat.towers[0][0]
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 91 and combat.enemies[0][1]["hp"] == 100 and not tower["bounce_active"], "Unupgraded ballista remains single-target")
	combat.upgrade_tower(0, tower["id"], "bounce")
	combat.enemies[0][0]["progress"] = 4.0
	combat.enemies[0][1]["progress"] = 5.0
	combat.enemies[0][2]["progress"] = 8.0
	combat.enemies[0][3]["progress"] = 10.0
	combat.advance(float(tower["interval"]))
	_check(combat.enemies[0][0]["hp"] == 82 and combat.enemies[0][1]["hp"] == 95 and combat.enemies[0][2]["hp"] == 100 and combat.enemies[0][3]["hp"] == 100, "Bounce hits only the nearest other enemy beyond tower range, once, for rounded-up half damage")
	_check(tower["bounce_active"] and tower["aim"] == Vector2(4, 0) and tower["bounce_aim"] == Vector2(5, 0), "Primary event captures sequential primary-hit and bounce endpoints")
	# Equal distances use stable IDs even after array reordering and primary removal.
	combat = _prepared_special(_special_rules(&"orc_ballista", 100, 3), &"orc_ballista")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "bounce")
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	var primary: Dictionary = combat.enemies[0][0]
	var lower_id: Dictionary = combat.enemies[0][1]
	var higher_id: Dictionary = combat.enemies[0][2]
	primary["progress"] = 4.0
	primary["hp"] = 9
	lower_id["progress"] = 5.0
	lower_id["hp"] = 5
	higher_id["progress"] = 3.0
	higher_id["hp"] = 100
	combat.enemies[0].reverse()
	combat.set_targeting(0, tower["id"], MatchCombat.TargetMode.FURTHEST)
	# The progress-five victim is outside range; progress-four remains primary.
	var before: int = combat.coins[0]
	combat.advance(float(tower["interval"]))
	_check(combat.enemies[0].size() == 1 and combat.enemies[0][0]["id"] == higher_id["id"] and combat.enemies[0][0]["hp"] == 100 and tower["kills"] == 2, "Bounce tie picks the smaller ID, survives primary removal, can kill and never chains to a third victim")
	_check(combat.coins[0] == before + 2 * int(combat.snapshot()["rules"]["kill_bounty"]) and tower["aim"] == Vector2(4, 0) and tower["bounce_aim"] == Vector2(5, 0), "Both ballista kills retain tower attribution, bounties and immutable hit positions")
	combat = _prepared_special(_special_rules(&"orc_ballista", 100, 1), &"orc_ballista")
	tower = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "bounce")
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 91 and not tower["bounce_active"], "Living primary cannot be its own bounce victim")
	combat.enemies[0][0]["hp"] = 9
	combat.advance(float(tower["interval"]))
	_check(combat.enemies[0].is_empty() and tower["kills"] == 1 and not tower["bounce_active"], "Primary kill without another living victim publishes no bounce")


func _test_ballista_configuration() -> void:
	for branch: String in ["pierce", "bounce"]:
		var rules := _special_rules(&"orc_ballista")
		var definition: TowerDefinition = rules.catalog.towers[0]
		definition.evolutions[branch]["cost"] = 137
		definition.evolutions[branch]["title"] = "Custom branch"
		var expected: Dictionary = definition.evolutions.duplicate(true)
		_check(TowerDefinition.valid_evolutions(definition), "Ballista accepts title/price-only branch configurations")
		for invalid: Variant in [null, {}, {"title": "", "cost": 137}, {"title": 12, "cost": 137}, {"title": "Branch", "cost": 0}, {"title": "Branch", "cost": 1.5}, {"title": "Branch", "cost": 137, "damage": 9}, {"title": "Branch", "cost": 137, "interval": 1.0}, {"title": "Branch", "cost": 137, "continuous": false}, {"title": "Branch", "cost": 137, "followup": {}}]:
			var candidate: TowerDefinition = definition.duplicate(true)
			candidate.evolutions[branch] = invalid
			_check(not TowerDefinition.valid_evolutions(candidate), "Ballista rejects malformed metadata and Rune-only attack/followup fields")
		var candidate: TowerDefinition = definition.duplicate(true)
		candidate.area_attack = true
		_check(not TowerDefinition.valid_evolutions(candidate), "Ballista branches cannot enter the area attack path")
		candidate = definition.duplicate(true)
		candidate.evolutions["unknown"] = {"title": "Unknown", "cost": 137}
		_check(not TowerDefinition.valid_evolutions(candidate), "Unknown Ballista branches are rejected")
		candidate = definition.duplicate(true)
		candidate.evolutions["boulders"] = {"title": "Mixed", "cost": 137, "damage": 6, "interval": 0.0, "continuous": true}
		_check(not TowerDefinition.valid_evolutions(candidate), "Ballista and Rune schemas cannot mix")
		var combat := _prepared_special(rules, &"orc_ballista")
		var tower: Dictionary = combat.towers[0][0]
		definition.evolutions[branch]["cost"] = 1
		definition.evolutions[branch]["title"] = "Resource changed"
		var copy: Dictionary = combat.snapshot()
		copy["tower_types"]["orc_ballista"]["evolutions"][branch]["cost"] = 2
		copy["tower_types"]["orc_ballista"]["evolutions"][branch]["title"] = "Snapshot changed"
		_check(combat.snapshot()["tower_types"]["orc_ballista"]["evolutions"] == expected, "Ballista title and custom price are deep-captured against resource and snapshot mutation")
		combat.coins[0] = 136
		var frozen: Dictionary = combat.snapshot()
		_check(not combat.upgrade_tower(0, tower["id"], branch) and combat.snapshot() == frozen, "Captured custom branch price rejects insufficient funds atomically")
		combat.coins[0] = 137
		_check(combat.upgrade_tower(0, tower["id"], branch) and combat.coins[0] == 0 and tower["evolution"] == branch, "Ballista purchase charges exactly the captured custom price")


func _ballista_field(positions: Array[Vector2], branch: String = "pierce") -> MatchCombat:
	var combat := _prepared_special(_special_rules(&"orc_ballista", 100, positions.size()), &"orc_ballista")
	var tower: Dictionary = combat.towers[0][0]
	_check(combat.upgrade_tower(0, tower["id"], branch), "Ballista field fixture buys an explicit branch")
	# Spawn real host enemies without firing, then isolate the host attack geometry.
	tower["cooldown"] = 100.0
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	for index: int in range(positions.size()):
		combat.enemies[0][index]["pos"] = positions[index]
		combat.enemies[0][index]["progress"] = float(index)
	tower["cooldown"] = 0.0
	return combat


func _test_ballista_pierce_geometry() -> void:
	var combat := _ballista_field([Vector2(1, 1), Vector2(2, 1), Vector2(4, 1)])
	var tower: Dictionary = combat.towers[0][0]
	var primary: Dictionary = combat.enemies[0][2]
	combat._attack(0, 0.01)
	_check(combat.enemies[0][0]["hp"] == 91 and combat.enemies[0][1]["hp"] == 91 and primary["hp"] == 100, "Two intervening enemies intercept Pierce before the aimed primary; only two total take full upgraded damage")
	_check(tower["target_id"] == primary["id"] and tower["aim"] == Vector2(4, 1) and tower["pierce_active"] and not tower["bounce_active"] and tower["shot"] == 1, "Pierce retains the host-selected primary and aim without publishing a bounce")
	var endpoint: Vector2 = tower["pierce_aim"]
	_check(is_equal_approx(endpoint.x, 4.5) and is_equal_approx(endpoint.y, 1.0) and MatchCombat.cell_in_range(tower["cell"], Vector2i(endpoint.round()), 4.0), "Accepted straight bolt endpoint reaches the valid square range boundary")
	combat = _ballista_field([Vector2(-1, 1), Vector2(1, 1.251), Vector2(5, 1), Vector2(0, 1.2), Vector2(2, 1.25), Vector2(4, 1)])
	tower = combat.towers[0][0]
	combat._attack(0, 0.01)
	_check(combat.enemies[0][0]["hp"] == 100 and combat.enemies[0][1]["hp"] == 100 and combat.enemies[0][2]["hp"] == 100 and combat.enemies[0][3]["hp"] == 100 and combat.enemies[0][4]["hp"] == 91 and combat.enemies[0][5]["hp"] == 91, "Pierce rejects behind, off-corridor, out-of-tile-range and zero-projection enemies but includes the quarter-cell boundary")
	combat = _ballista_field([Vector2(1, 2), Vector2(2, 3), Vector2(3, 4), Vector2(4, 5)])
	tower = combat.towers[0][0]
	combat._attack(0, 0.01)
	endpoint = tower["pierce_aim"]
	_check(combat.enemies[0][0]["hp"] == 91 and combat.enemies[0][1]["hp"] == 91 and combat.enemies[0][2]["hp"] == 100 and combat.enemies[0][3]["hp"] == 100 and is_equal_approx(endpoint.x, 4.5) and is_equal_approx(endpoint.y, 5.5) and MatchCombat.cell_in_range(tower["cell"], Vector2i(endpoint.round()), 4.0), "Diagonal Pierce uses the straight ray and square Chebyshev edge, not a circular range")
	combat = _ballista_field([Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(4, 1)])
	var lowest: Dictionary = combat.enemies[0][0]
	var middle: Dictionary = combat.enemies[0][1]
	var highest: Dictionary = combat.enemies[0][2]
	combat.enemies[0].reverse()
	combat._attack(0, 0.01)
	_check(lowest["hp"] == 91 and middle["hp"] == 91 and highest["hp"] == 100, "Equal ray distances select the two smallest stable enemy IDs independent of array order")
	combat = _ballista_field([Vector2(3, 1)])
	tower = combat.towers[0][0]
	combat._attack(0, 0.01)
	_check(combat.enemies[0][0]["hp"] == 91 and tower["pierce_active"], "One living enemy receives one full Pierce hit, never a repeat")
	combat = _ballista_field([Vector2(1, 1), Vector2(0, 1)])
	tower = combat.towers[0][0]
	combat._attack(0, 0.01)
	_check(combat.enemies[0][0]["hp"] == 100 and combat.enemies[0][1]["hp"] == 91 and tower["pierce_aim"] == Vector2(tower["cell"]), "Zero-length primary direction hits only the primary and publishes its degenerate endpoint")


func _test_ballista_pierce_deaths_and_policies() -> void:
	for reverse_order: bool in [false, true]:
		var combat := _ballista_field([Vector2(1, 1), Vector2(2, 1), Vector2(3, 1)])
		var tower: Dictionary = combat.towers[0][0]
		var primary: Dictionary = combat.enemies[0][0]
		var second: Dictionary = combat.enemies[0][1]
		var third: Dictionary = combat.enemies[0][2]
		primary["hp"] = 9
		second["hp"] = 9
		combat.set_targeting(0, tower["id"], MatchCombat.TargetMode.CLOSEST)
		if reverse_order:
			combat.enemies[0].reverse()
		var before: int = combat.coins[0]
		combat._attack(0, 0.01)
		_check(combat.enemies[0].size() == 1 and combat.enemies[0][0]["id"] == third["id"] and third["hp"] == 100 and tower["kills"] == 2 and tower["target_id"] == primary["id"], "Pierce captures both victims before primary death and removal in either array order, without hitting a third")
		_check(combat.coins[0] == before + 2 * int(combat.snapshot()["rules"]["kill_bounty"]), "Both authoritative Pierce kills retain tower attribution and pay one bounty each")
	for mode: int in [MatchCombat.TargetMode.FURTHEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST]:
		var combat := _ballista_field([Vector2(2, 1), Vector2(0, 3), Vector2(-2, 1)])
		var tower: Dictionary = combat.towers[0][0]
		combat.enemies[0][1]["hp"] = 200
		combat.enemies[0][2]["pos"] = Vector2(-3, 1)
		combat.set_targeting(0, tower["id"], mode)
		var selected: int = 2 if mode == MatchCombat.TargetMode.FURTHEST else (0 if mode == MatchCombat.TargetMode.CLOSEST else 1)
		var expected: Dictionary = combat.enemies[0][selected]
		combat._attack(0, 0.01)
		_check(tower["target_id"] == expected["id"] and tower["aim"] == expected["pos"] and tower["mode"] == mode, "Pierce ray obeys the existing primary targeting policy %s" % mode)
		for index: int in range(combat.enemies[0].size()):
			var original_hp: int = 200 if index == 1 else 100
			_check(combat.enemies[0][index]["hp"] == original_hp - (9 if index == selected else 0), "Only the selected policy's ray deals damage, without redirecting off-ray")
	var sole := _ballista_field([Vector2(0, 1)])
	var sole_tower: Dictionary = sole.towers[0][0]
	sole.enemies[0][0]["hp"] = 9
	var before: int = sole.coins[0]
	sole._attack(0, 0.01)
	_check(sole.enemies[0].is_empty() and sole_tower["kills"] == 1 and sole.coins[0] == before + int(sole.snapshot()["rules"]["kill_bounty"]), "A lethal zero-direction Pierce retires the sole victim once and awards exactly one kill and bounty")


func _test_ballista_pierce_snapshot_lifecycle() -> void:
	var combat := _ballista_field([Vector2(1, 1), Vector2(3, 1)])
	var tower: Dictionary = combat.towers[0][0]
	_check(not tower["pierce_active"] and tower["pierce_aim"] == Vector2(tower["cell"]), "New Ballista snapshots initialize a disabled Pierce event at the tower cell")
	combat._attack(0, 0.01)
	var endpoint: Vector2 = tower["pierce_aim"]
	var copy: Dictionary = combat.snapshot()
	copy["towers"][0][0]["pierce_active"] = false
	copy["towers"][0][0]["pierce_aim"] = Vector2(99, 99)
	_check(tower["pierce_active"] and tower["pierce_aim"] == endpoint, "Pierce accepted endpoints and active state are detached snapshot values")
	combat.phase = MatchCombat.Phase.PLANNING
	var shots: int = tower["shot"]
	combat.grow_for_main_round()
	_check(tower["pierce_aim"] == endpoint + Vector2.DOWN and tower["pierce_active"] and tower["shot"] == shots, "Growth translates the accepted Pierce endpoint without changing the event")
	_check(combat.debug_set_round(5) and not tower["pierce_active"] and tower["pierce_aim"] == Vector2(tower["cell"]) and tower["evolution"] == "pierce" and tower["special_upgraded"], "Debug round reset clears Pierce cosmetics while preserving the paid branch")
	combat = _prepared_special(_special_rules(&"arrow_tower", 100, 1), &"arrow_tower")
	tower = combat.towers[0][0]
	_check(not tower["pierce_active"] and tower["pierce_aim"] == Vector2(tower["cell"]), "Non-Ballista towers carry the same inactive snapshot fields")
	tower["pierce_active"] = true
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(not tower["pierce_active"], "An ordinary authoritative shot clears stale Pierce state")


func _prepared_evolution(branch: String, rules: CombatRules) -> MatchCombat:
	var combat := _prepared_special(rules, &"rune_obelisk")
	_check(combat.upgrade_tower(0, combat.towers[0][0]["id"], branch), "Evolution fixture buys the explicit paid branch")
	return combat


func _test_evolution_configuration() -> void:
	var rules := _special_rules(&"rune_obelisk")
	var definition: TowerDefinition = rules.catalog.towers[0]
	definition.evolutions["boulders"]["followup"]["cost"] = 137
	var expected: Dictionary = definition.evolutions.duplicate(true)
	var invalid_configs: Array[Dictionary] = [
		{"field": "title", "value": ""},
		{"field": "title", "value": 12},
		{"field": "cost", "value": 0},
		{"field": "cost", "value": 1.5},
		{"field": "damage", "value": 0},
		{"field": "damage", "value": 1.5},
		{"field": "interval", "value": INF},
		{"field": "interval", "value": NAN},
		{"field": "interval", "value": -0.1},
		{"field": "interval", "value": "0"},
		{"field": "continuous", "value": false},
		{"field": "continuous", "value": 1},
	]
	for invalid: Dictionary in invalid_configs:
		var candidate: TowerDefinition = definition.duplicate(true)
		candidate.evolutions["boulders"][invalid["field"]] = invalid["value"]
		_check(not TowerDefinition.valid_evolutions(candidate), "Malformed evolution %s is rejected before capture or payment" % invalid["field"])
	var candidate: TowerDefinition = definition.duplicate(true)
	candidate.evolutions["onyx_ring"]["interval"] = 0.0
	_check(not TowerDefinition.valid_evolutions(candidate), "A discrete branch cannot have a zero interval")
	candidate = definition.duplicate(true)
	candidate.evolutions["unknown"] = candidate.evolutions["boulders"]
	_check(not TowerDefinition.valid_evolutions(candidate), "Unknown evolution names cannot enter the command contract")
	candidate = definition.duplicate(true)
	candidate.evolutions["boulders"] = 6
	_check(not TowerDefinition.valid_evolutions(candidate), "An evolution must contain a configuration dictionary")
	candidate = definition.duplicate(true)
	candidate.area_attack = false
	_check(not TowerDefinition.valid_evolutions(candidate), "Neighborhood evolutions require an area-attack definition")
	candidate = definition.duplicate(true)
	candidate.special_upgrade = "second_archer"
	_check(not TowerDefinition.valid_evolutions(candidate), "Generic special and mutually exclusive evolutions cannot coexist")
	for invalid: Variant in [null, {}, {"id": "unknown", "title": "Freeze Runes", "cost": 250}, {"id": "freeze_runes", "title": "", "cost": 250}, {"id": "freeze_runes", "title": "Freeze Runes", "cost": 0}, {"id": "freeze_runes", "title": "Freeze Runes", "cost": 250.0}]:
		candidate = definition.duplicate(true)
		candidate.evolutions["boulders"]["followup"] = invalid
		_check(not TowerDefinition.valid_evolutions(candidate), "Malformed Freeze followup cannot enter captured configuration")
	candidate = definition.duplicate(true)
	candidate.evolutions["boulders"].erase("followup")
	_check(not TowerDefinition.valid_evolutions(candidate), "Boulders requires its explicit followup metadata")
	candidate = definition.duplicate(true)
	candidate.evolutions["onyx_ring"]["followup"] = candidate.evolutions["boulders"]["followup"]
	_check(not TowerDefinition.valid_evolutions(candidate), "Onyx cannot advertise the exclusive Boulders followup")
	var combat := _prepared_special(rules, &"rune_obelisk")
	var captured: Dictionary = combat.snapshot()["tower_types"]["rune_obelisk"]["evolutions"]
	definition.evolutions["boulders"]["damage"] = 999
	definition.evolutions["boulders"]["cost"] = 1
	definition.evolutions["onyx_ring"]["interval"] = 0.01
	definition.evolutions["boulders"]["followup"]["cost"] = 1
	definition.evolutions["boulders"]["followup"]["title"] = "Changed"
	var copy: Dictionary = combat.snapshot()
	copy["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["damage"] = 888
	copy["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"]["cost"] = 2
	copy["towers"][0][0]["evolution"] = "onyx_ring"
	_check(captured == expected and combat.snapshot()["tower_types"]["rune_obelisk"]["evolutions"] == expected and combat.towers[0][0]["evolution"] == "", "Source resources and nested consumer snapshots cannot rewrite host evolution configuration")
	var before: int = combat.coins[0]
	_check(combat.upgrade_tower(0, combat.towers[0][0]["id"], "boulders") and before - combat.coins[0] == expected["boulders"]["cost"] and combat.towers[0][0]["damage"] == expected["boulders"]["damage"], "Purchase uses captured branch damage and price, never subsequently edited resource values")
	before = combat.coins[0]
	_check(combat.upgrade_tower(0, combat.towers[0][0]["id"], "freeze_runes") and before - combat.coins[0] == expected["boulders"]["followup"]["cost"] and combat.snapshot()["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"] == expected["boulders"]["followup"], "Followup price and nested metadata remain captured despite resource and snapshot mutation")


func _test_rune_continuous_damage() -> void:
	var combat := _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 100, 2))
	var tower: Dictionary = combat.towers[0][0]
	combat.start_wave(_routes())
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 100 and combat.enemies[0][1]["hp"] == 100 and tower["shot"] == 0, "Boulders entry grants no immediate pulse or rounded-up damage")
	combat.advance(0.14)
	_check(combat.enemies[0][0]["hp"] == 100, "Sub-one-HP exposure remains fractional instead of rounding every frame")
	combat.advance(0.02)
	_check(combat.enemies[0][0]["hp"] == 99 and combat.enemies[0][1]["hp"] == 99, "Accumulated fractional damage reaches every enemy, not one selected victim")
	combat.advance(0.33)
	_check(combat.enemies[0][0]["hp"] == 97 and combat.enemies[0][1]["hp"] == 97 and typeof(combat.enemies[0][0]["hp"]) == TYPE_INT and tower["shot"] == 0 and tower["interval"] == 0.0, "Half a second deals three integer HP to all neighbors without becoming a pulse attack")
	var coarse := _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 100, 1))
	var fine := _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 100, 1))
	coarse.start_wave(_routes())
	fine.start_wave(_routes())
	coarse.advance(2.0)
	for tick: int in range(120):
		fine.advance(1.0 / 60.0)
	_check(coarse.enemies[0][0]["hp"] == 88 and fine.enemies[0][0]["hp"] == 88, "Six DPS is invariant between one coarse tick and 120 physics ticks")
	var moving_rules := _special_rules(&"rune_obelisk", 100, 1)
	moving_rules.enemy_speed = 2.0
	coarse = _prepared_evolution("boulders", moving_rules)
	fine = _prepared_evolution("boulders", moving_rules)
	coarse.towers[0][0]["cell"] = Vector2i(3, 1)
	fine.towers[0][0]["cell"] = Vector2i(3, 1)
	coarse.start_wave(_routes())
	fine.start_wave(_routes())
	coarse.advance(3.0)
	for tick: int in range(300):
		fine.advance(0.01)
	_check(coarse.enemies[0][0]["hp"] == 91 and fine.enemies[0][0]["hp"] == 91 and coarse.enemies[0][0]["pos"] == Vector2(6, 0), "Coarse and fine moving enemies receive only their 1.5 seconds crossing the existing rounded 3x3 neighborhood")
	# A reversed, turning route exercises vertical segments and negative coordinates.
	var turning: Array = [Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0)]
	coarse = _prepared_evolution("boulders", moving_rules)
	fine = _prepared_evolution("boulders", moving_rules)
	coarse.towers[0][0]["cell"] = Vector2i.ZERO
	fine.towers[0][0]["cell"] = Vector2i.ZERO
	var routing: Array[Dictionary] = [_routing(turning), _routing(turning)]
	coarse.start_wave(routing)
	fine.start_wave(routing)
	coarse.advance(2.9)
	for tick: int in range(290):
		fine.advance(0.01)
	_check(coarse.enemies[0][0]["hp"] == 91 and fine.enemies[0][0]["hp"] == 91, "Path integration handles reversed axes and turns without final-position overcounting")
	var spawn_rules := _special_rules(&"rune_obelisk", 100, 2)
	spawn_rules.spawn_interval = 0.15
	coarse = _prepared_evolution("boulders", spawn_rules)
	fine = _prepared_evolution("boulders", spawn_rules)
	coarse.start_wave(_routes())
	fine.start_wave(_routes())
	coarse.advance(0.2)
	for tick: int in range(20):
		fine.advance(0.01)
	_check(coarse.enemies[0][0]["hp"] == 99 and coarse.enemies[0][1]["hp"] == 100 and fine.enemies[0][0]["hp"] == 99 and fine.enemies[0][1]["hp"] == 100, "A mid-tick spawn accrues only its own lifetime, even while stationary")
	# Live purchase starts a fresh future-time accumulator, never a transformed shot.
	combat = _prepared_special(_special_rules(&"rune_obelisk", 100, 1), &"rune_obelisk")
	tower = combat.towers[0][0]
	combat.start_wave(_routes())
	combat.advance(0.01)
	var hp: int = combat.enemies[0][0]["hp"]
	var shots: int = tower["shot"]
	combat.upgrade_tower(0, tower["id"], "boulders")
	_check(combat.enemies[0][0]["hp"] == hp and tower["shot"] == shots, "Live Boulders purchase grants no free attack")
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == hp and tower["shot"] == shots, "Old Rune reload and prior attacks cannot supply free continuous damage credit")


func _test_rune_fraction_isolation_and_cleanup() -> void:
	var combat := _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 100, 2))
	var tower: Dictionary = combat.towers[0][0]
	combat.start_wave(_routes())
	combat.advance(0.1)
	var first: Dictionary = combat.enemies[0][0]
	var second: Dictionary = combat.enemies[0][1]
	first["progress"] = 3.0
	combat.set_targeting(0, tower["id"], MatchCombat.TargetMode.STRONGEST)
	combat.advance(0.1)
	_check(first["hp"] == 100 and second["hp"] == 99, "Leaving range stops damage; changing target policy cannot carry one enemy's fraction to another")
	first["progress"] = 0.0
	combat.advance(0.05)
	_check(first["hp"] == 100 and second["hp"] == 99, "Re-entry retains only this same enemy's own accumulated exposure")
	combat.send_enemy(1, &"grunt")
	var newcomer: Dictionary = combat.enemies[0].back()
	combat.advance(0.02)
	_check(first["hp"] == 99 and newcomer["hp"] == 100, "A new enemy cannot inherit an older enemy's fractional HP")
	combat = _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 100, 1))
	tower = combat.towers[0][0]
	combat.build(0, Vector2i(1, 1), &"rune_obelisk", 0)
	var other: Dictionary = combat.towers[0][1]
	combat.upgrade_tower(0, other["id"], "damage")
	combat.upgrade_tower(0, other["id"], "speed")
	combat.upgrade_tower(0, other["id"], "boulders")
	combat.start_wave(_routes())
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == 100, "Separate Boulders towers do not pool two sub-HP fractions")
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == 98, "Both towers independently cross one HP on the same enemy")
	var sold_id: int = tower["id"]
	combat.sell_tower(0, sold_id)
	_check(not combat._continuous_damage.has(sold_id), "Selling removes the source's entire bounded fractional ledger")
	combat.build(0, Vector2i(0, 1), &"rune_obelisk", 0)
	tower = combat.towers[0][1]
	combat.upgrade_tower(0, tower["id"], "damage")
	combat.upgrade_tower(0, tower["id"], "speed")
	combat.upgrade_tower(0, tower["id"], "boulders")
	combat.advance(0.1)
	_check(combat.enemies[0][0]["hp"] == 98 and tower["id"] != sold_id, "A replacement tower never inherits the sold source's fraction")
	combat = _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 1, 2))
	tower = combat.towers[0][0]
	combat.build(0, Vector2i(1, 1), &"rune_obelisk", 0)
	other = combat.towers[0][1]
	combat.upgrade_tower(0, other["id"], "damage")
	combat.upgrade_tower(0, other["id"], "speed")
	combat.upgrade_tower(0, other["id"], "boulders")
	combat.start_wave(_routes())
	combat.advance(0.1)
	var dead_id: int = combat.enemies[0][0]["id"]
	var before: int = combat.coins[0]
	combat.advance(0.1)
	_check(combat.enemies[0].is_empty() and tower["kills"] == 2 and other["kills"] == 0 and combat.coins[0] == before + 2 * int(combat.snapshot()["rules"]["kill_bounty"]) and combat._continuous_damage[tower["id"]].is_empty() and combat._continuous_damage[other["id"]].is_empty() and not combat._enemy_spawn_times.has(dead_id), "Continuous deaths retire every source's credit and spawn tracking and pay one attributed bounty per enemy")
	combat.advance(1.0)
	_check(tower["kills"] == 2 and combat.coins[0] == before + 2 * int(combat.snapshot()["rules"]["kill_bounty"]), "Empty later ticks cannot award a continuous kill twice")
	var leak_rules := _special_rules(&"rune_obelisk", 100, 1)
	leak_rules.enemy_speed = 1.0
	combat = _prepared_evolution("boulders", leak_rules)
	tower = combat.towers[0][0]
	combat.start_wave(_routes(1, 1))
	combat.advance(0.1)
	combat.advance(1.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat._enemy_spawn_times.is_empty() and combat._continuous_damage[tower["id"]].is_empty() and tower["kills"] == 0, "Leaks retire every host-only enemy entry without attributing a kill")


func _test_onyx_pulses() -> void:
	var combat := _prepared_evolution("onyx_ring", _special_rules(&"rune_obelisk", 100, 3))
	var tower: Dictionary = combat.towers[0][0]
	combat.start_wave(_routes())
	combat.advance(0.74)
	_check(combat.enemies[0][0]["hp"] == 100 and tower["shot"] == 0, "Onyx grants no purchase pulse and deals nothing between discrete pulses")
	combat.enemies[0][2]["progress"] = 2.0
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 94 and combat.enemies[0][1]["hp"] == 94 and combat.enemies[0][2]["hp"] == 100 and tower["shot"] == 1, "At .75 simulation seconds Onyx hits all and only enemies in the same 3x3 neighborhood")
	combat.advance(0.74)
	_check(combat.enemies[0][0]["hp"] == 94 and tower["shot"] == 1 and combat._continuous_damage.is_empty(), "Onyx never falls through to fractional continuous damage")
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == 88 and tower["shot"] == 2, "Each subsequent full .75-second interval deals exactly six damage")
	var coarse := _prepared_evolution("onyx_ring", _special_rules(&"rune_obelisk", 100, 1))
	var fine := _prepared_evolution("onyx_ring", _special_rules(&"rune_obelisk", 100, 1))
	coarse.start_wave(_routes())
	fine.start_wave(_routes())
	coarse.advance(2.25)
	for tick: int in range(225):
		fine.advance(0.01)
	_check(coarse.enemies[0][0]["hp"] == 82 and fine.enemies[0][0]["hp"] == 82 and coarse.towers[0][0]["shot"] == 3 and fine.towers[0][0]["shot"] == 3, "Discrete pulses preserve cadence and all due pulses across coarse simulation ticks")
	var spawn_rules := _special_rules(&"rune_obelisk", 100, 2)
	spawn_rules.spawn_interval = 0.8
	combat = _prepared_evolution("onyx_ring", spawn_rules)
	combat.start_wave(_routes())
	combat.advance(0.9)
	_check(combat.enemies[0][0]["hp"] == 94 and combat.enemies[0][1]["hp"] == 100, "A pulse cannot damage an enemy born after that pulse within a coarse tick")
	var moving_rules := _special_rules(&"rune_obelisk", 100, 1)
	moving_rules.enemy_speed = 2.0
	combat = _prepared_evolution("onyx_ring", moving_rules)
	combat.towers[0][0]["cell"] = Vector2i(2, 1)
	combat.start_wave(_routes())
	combat.advance(2.0)
	_check(combat.enemies[0][0]["hp"] == 88, "Coarse Onyx pulses sample historical pulse-time positions, not the out-of-range final position")
	combat = _prepared_special(_special_rules(&"rune_obelisk", 100, 1), &"rune_obelisk")
	tower = combat.towers[0][0]
	combat.start_wave(_routes())
	combat.advance(0.01)
	var hp: int = combat.enemies[0][0]["hp"]
	var shots: int = tower["shot"]
	combat.upgrade_tower(0, tower["id"], "onyx_ring")
	_check(combat.enemies[0][0]["hp"] == hp and tower["shot"] == shots and is_equal_approx(tower["cooldown"], 0.75), "Live Onyx purchase starts a full new reload without a free burst")
	combat.advance(0.74)
	_check(combat.enemies[0][0]["hp"] == hp and tower["shot"] == shots, "An old Rune reload cannot bring the first evolved pulse forward")
	combat.advance(0.01)
	_check(combat.enemies[0][0]["hp"] == hp - 6 and tower["shot"] == shots + 1, "First evolved pulse follows the complete purchased interval")
	combat = _prepared_evolution("onyx_ring", _special_rules(&"rune_obelisk", 6, 3))
	tower = combat.towers[0][0]
	combat.start_wave(_routes())
	var before: int = combat.coins[0]
	combat.advance(0.75)
	_check(combat.enemies[0].is_empty() and tower["kills"] == 3 and combat.coins[0] == before + 3 * int(combat.snapshot()["rules"]["kill_bounty"]), "Lethal pulse removes every victim once, without skipped indices or duplicate bounties")
	combat.advance(1.5)
	_check(tower["kills"] == 3 and combat.coins[0] == before + 3 * int(combat.snapshot()["rules"]["kill_bounty"]), "Later pulses cannot reward removed enemies again")


func _test_rune_evolution_persistence() -> void:
	for branch: String in ["boulders", "onyx_ring"]:
		var rules := _special_rules(&"rune_obelisk", 6, 1)
		rules.health_growth = 0
		rules.speed_growth = 0.0
		var combat := _prepared_evolution(branch, rules)
		combat.build(1, Vector2i(0, 1), &"rune_obelisk", 0)
		var other: Dictionary = combat.towers[1][0]
		combat.upgrade_tower(1, other["id"], "damage")
		combat.upgrade_tower(1, other["id"], "speed")
		combat.upgrade_tower(1, other["id"], branch)
		var tower: Dictionary = combat.towers[0][0]
		var copy: Dictionary = combat.snapshot()
		copy["towers"][0][0]["evolution"] = "changed"
		copy["tower_types"]["rune_obelisk"]["evolutions"][branch]["cost"] = 1
		_check(tower["evolution"] == branch and combat.snapshot()["tower_types"]["rune_obelisk"]["evolutions"][branch]["cost"] == 250, "Chosen branch identity and nested configuration are detached from client snapshots")
		var before: int = combat.coins[0]
		combat.start_wave(_routes())
		combat.advance(1.0)
		_check(combat.phase == MatchCombat.Phase.PLANNING and tower["kills"] == 1 and combat.coins[0] == before + rules.kill_bounty + rules.wave_reward + rules.wave_reward_growth, "Both evolved boards clear a real wave and receive exactly one kill and wave reward")
		var after_clear: Dictionary = combat.snapshot()
		_check(not combat.advance(1.0) and combat.snapshot() == after_clear, "Planning cannot repay an evolved wave clear")
		var invested: int = tower["invested"]
		var shots: int = tower["shot"]
		combat.grow_for_main_round()
		_check(tower["cell"] == Vector2i(0, 2) and tower["evolution"] == branch and tower["special_upgraded"] and MatchCombat.tower_level(tower) == 4 and tower["damage"] == 6 and tower["invested"] == invested and tower["shot"] == shots, "Growth preserves paid evolution, effective damage, level, investment and shot history")
		var shifted: Array = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
		var routing: Array[Dictionary] = [_routing(shifted), _routing(shifted)]
		combat.start_wave(routing)
		combat.advance(1.0)
		_check(combat.phase == MatchCombat.Phase.PLANNING and combat.wave == 2 and tower["kills"] == 2 and tower["evolution"] == branch and combat._enemy_spawn_times.is_empty(), "The next shifted wave uses the same evolution with no stale enemy damage credit")


func _test_special_snapshot_and_growth() -> void:
	var combat := _prepared_special(_special_rules(&"arrow_tower"), &"arrow_tower")
	var tower: Dictionary = combat.towers[0][0]
	combat.upgrade_tower(0, tower["id"], "special")
	combat.start_wave(_routes())
	combat.advance(0.01)
	var copy: Dictionary = combat.snapshot()
	copy["towers"][0][0]["special_upgraded"] = false
	copy["towers"][0][0]["secondary_mode"] = 2
	copy["towers"][0][0]["secondary_shot"] = 999
	copy["towers"][0][0]["secondary_aim"] = Vector2(99, 99)
	copy["towers"][0][0]["bounce_active"] = true
	copy["enemies"][0][0]["speed"] = 999.0
	copy["tower_types"]["arrow_tower"]["special_upgrade_cost"] = 1
	_check(tower["special_upgraded"] and tower["secondary_mode"] == 0 and tower["secondary_shot"] == 1 and tower["secondary_aim"] == Vector2.ZERO and not tower["bounce_active"] and combat.enemies[0][0]["speed"] == 0.0 and combat.snapshot()["tower_types"]["arrow_tower"]["special_upgrade_cost"] == 200, "Special metadata, attack events, policy and enemy speed are detached snapshot values")
	combat.phase = MatchCombat.Phase.PLANNING
	var old_aim: Vector2 = tower["aim"]
	var old_secondary: Vector2 = tower["secondary_aim"]
	var old_bounce: Vector2 = tower["bounce_aim"]
	var primary_shots: int = tower["shot"]
	var secondary_shots: int = tower["secondary_shot"]
	combat.grow_for_main_round()
	_check(tower["cell"] == Vector2i(0, 2) and tower["aim"] == old_aim + Vector2.DOWN and tower["secondary_aim"] == old_secondary + Vector2.DOWN and tower["bounce_aim"] == old_bounce + Vector2.DOWN and tower["shot"] == primary_shots and tower["secondary_shot"] == secondary_shots, "Board growth shifts every cosmetic endpoint exactly once without inventing a shot")


func _test_freeze_transactions() -> void:
	for count: int in [0, 1]:
		var unprepared := MatchCombat.new(_special_rules(&"rune_obelisk"))
		unprepared.build(0, Vector2i(0, 1), &"rune_obelisk", 0)
		var early: Dictionary = unprepared.towers[0][0]
		if count == 1:
			unprepared.upgrade_tower(0, early["id"], "damage")
		var before: Dictionary = unprepared.snapshot()
		_check(not unprepared.upgrade_tower(0, early["id"], "freeze_runes") and unprepared.snapshot() == before, "Levels I and II cannot skip Boulders prerequisites with Freeze")
	for type_id: StringName in [&"rune_obelisk", &"arrow_tower", &"orc_ballista"]:
		var combat := _prepared_special(_special_rules(type_id), type_id)
		var tower: Dictionary = combat.towers[0][0]
		var frozen: Dictionary = combat.snapshot()
		_check(not tower["freeze_upgraded"] and not combat.upgrade_tower(0, tower["id"], "freeze_runes") and combat.snapshot() == frozen, "Freeze requires Boulders, never ordinary level III or another tower type")
	var rules := _special_rules(&"rune_obelisk")
	var combat := _prepared_evolution("onyx_ring", rules)
	var tower: Dictionary = combat.towers[0][0]
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.upgrade_tower(0, tower["id"], "freeze_runes") and combat.snapshot() == frozen and MatchCombat.tower_level(tower) == 4, "Onyx remains level IV and cannot purchase Freeze")
	combat = _prepared_evolution("boulders", rules)
	tower = combat.towers[0][0]
	for slot: int in [-1, 1, 2]:
		frozen = combat.snapshot()
		_check(not combat.upgrade_tower(slot, tower["id"], "freeze_runes") and combat.snapshot() == frozen, "Freeze rejects invalid ownership atomically")
	combat.coins[0] = 249
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, tower["id"], "freeze_runes") and combat.snapshot() == frozen, "Freeze cannot spend partial payment")
	combat.coins[0] = 250
	var investment: int = tower["invested"]
	var cooldown: float = tower["cooldown"]
	_check(combat.upgrade_tower(0, tower["id"], "freeze_runes") and combat.coins[0] == 0 and tower["freeze_upgraded"] and MatchCombat.tower_level(tower) == 5, "Boulders buys Freeze for exactly 250 and becomes level V")
	_check(tower["invested"] == investment + 250 and tower["sell_value"] == floori((investment + 250) * 0.6) and tower["damage"] == 6 and tower["interval"] == 0.0 and tower["cooldown"] == cooldown, "Followup adds refundable investment but changes neither DPS nor attack timing")
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, tower["id"], "freeze_runes") and not combat.upgrade_tower(0, tower["id"], "onyx_ring") and combat.snapshot() == frozen, "Freeze cannot be duplicated or used to switch branches")
	var refund: int = tower["sell_value"]
	_check(combat.sell_tower(0, tower["id"]) and combat.coins[0] == refund and combat.towers[0].is_empty(), "Selling level V refunds sixty percent of the complete paid upgrade chain")
	combat = _prepared_evolution("boulders", rules)
	tower = combat.towers[0][0]
	combat.phase = MatchCombat.Phase.FINISHED
	frozen = combat.snapshot()
	_check(not combat.upgrade_tower(0, tower["id"], "freeze_runes") and combat.snapshot() == frozen, "Finished matches reject followup transactions")


func _test_freeze_damage_and_expiry() -> void:
	var combat := _prepared_special(_special_rules(&"rune_obelisk", 20, 1), &"rune_obelisk")
	var tower: Dictionary = combat.towers[0][0]
	combat.start_wave(_routes(100, 100))
	combat.advance(0.01)
	var enemy: Dictionary = combat.enemies[0][0]
	_check(enemy["hp"] == 18 and not enemy["slowed"], "Ordinary Rune damage is real HP damage, not an early slow")
	combat.upgrade_tower(0, tower["id"], "boulders")
	combat.advance(0.34)
	_check(enemy["hp"] == 16 and not enemy["slowed"] and combat._rune_damage[tower["id"]][enemy["id"]] == 4, "Host keeps prior base and Boulders actual damage for the same source")
	var hp: int = enemy["hp"]
	combat.upgrade_tower(0, tower["id"], "freeze_runes")
	_check(enemy["hp"] == hp and not enemy["slowed"] and enemy["slow_remaining"] == 0.0, "Buying Freeze above threshold grants neither retroactive slow nor damage")
	combat.advance(0.17)
	_check(enemy["hp"] == hp - 1 and enemy["slowed"] and enemy["slow_remaining"] == 2.0, "The next qualifying upgraded damage tick activates a two-second slow")
	combat.advance(0.05)
	_check(is_equal_approx(enemy["slow_remaining"], 1.95), "Fractional exposure without actual HP damage does not refresh Freeze")
	combat.advance(0.12)
	_check(enemy["slow_remaining"] == 2.0, "Later actual damage above threshold refreshes rather than stacks the timer")
	var id: int = tower["id"]
	combat.sell_tower(0, id)
	_check(enemy["slowed"] and not combat._rune_damage.has(id) and not combat._continuous_damage.has(id), "Sale retires both source ledgers without cancelling an existing enemy slow")
	combat.advance(1.99)
	_check(enemy["slowed"] and is_equal_approx(enemy["slow_remaining"], 0.01), "Sold-tower slow persists for its remaining simulation lifetime")
	combat.advance(0.01)
	_check(not enemy["slowed"] and enemy["slow_remaining"] == 0.0 and enemy["speed"] == enemy["base_speed"], "Slow expires exactly and restores effective base speed")


func _test_freeze_source_isolation() -> void:
	var combat := _prepared_evolution("boulders", _special_rules(&"rune_obelisk", 101, 2))
	var first: Dictionary = combat.towers[0][0]
	combat.upgrade_tower(0, first["id"], "freeze_runes")
	combat.build(0, Vector2i(1, 1), &"rune_obelisk", 0)
	var second: Dictionary = combat.towers[0][1]
	for upgrade: String in ["damage", "speed", "boulders", "freeze_runes"]:
		combat.upgrade_tower(0, second["id"], upgrade)
	combat.start_wave(_routes(100, 100))
	combat.advance(2.0)
	var untouched: Dictionary = combat.enemies[0][0]
	var qualifying: Dictionary = combat.enemies[0][1]
	_check(untouched["hp"] == 77 and not untouched["slowed"] and not qualifying["slowed"], "Two sources dealing 12 HP each cannot pool their damage toward one Freeze threshold")
	second["cell"] = Vector2i(20, 20)
	untouched["progress"] = 10.0
	combat.advance(1.3333333333333333)
	_check(qualifying["hp"] == 69 and not qualifying["slowed"], "Twenty source damage stays below ceil(101 times .2), even after combined damage exceeds it")
	combat.advance(1.0 / 6.0)
	_check(qualifying["slowed"] and qualifying["slow_remaining"] == 2.0 and not untouched["slowed"], "Twenty-one actual source damage freezes only that source/enemy pair")
	var enemy_id: int = qualifying["id"]
	combat._hit(0, first, 1, 1000)
	_check(not combat._rune_damage[first["id"]].has(enemy_id) and not combat._rune_damage[second["id"]].has(enemy_id) and not combat._enemy_spawn_times.has(enemy_id), "Enemy retirement erases damage credit from every source")


func _slow_expiry_fixture(branch: String) -> MatchCombat:
	var rules := _special_rules(&"rune_obelisk", 25, 1)
	rules.enemy_speed = 2.0
	var combat := _prepared_evolution("boulders", rules)
	var source: Dictionary = combat.towers[0][0]
	source["cell"] = Vector2i(1, 1)
	combat.upgrade_tower(0, source["id"], "freeze_runes")
	combat.start_wave(_routes(100, 100))
	combat.advance(0.84)
	var enemy: Dictionary = combat.enemies[0][0]
	_check(enemy["hp"] == 20 and enemy["slowed"] and enemy["base_speed"] == 2.0 and enemy["speed"] == 1.6 and is_equal_approx(enemy["progress"], 1.68), "Actual ceil-five threshold applies a nonstacking twenty-percent movement slow")
	combat.sell_tower(0, source["id"])
	combat.build(0, Vector2i(4, 1), &"rune_obelisk", 0)
	var observer: Dictionary = combat.towers[0][0]
	for upgrade: String in ["damage", "speed", branch]:
		combat.upgrade_tower(0, observer["id"], upgrade)
	return combat


func _test_slow_motion_history() -> void:
	for branch: String in ["boulders", "onyx_ring"]:
		var coarse := _slow_expiry_fixture(branch)
		var fine := _slow_expiry_fixture(branch)
		coarse.advance(3.0)
		for tick: int in range(300):
			fine.advance(0.01)
		var enemy: Dictionary = coarse.enemies[0][0]
		var fine_enemy: Dictionary = fine.enemies[0][0]
		var expected_hp: int = 10 if branch == "boulders" else 2
		_check(is_equal_approx(enemy["progress"], 6.88) and is_equal_approx(enemy["progress"], fine_enemy["progress"]) and not enemy["slowed"] and enemy["speed"] == 2.0, "Coarse and fine movement split exactly at sold-source slow expiry")
		_check(enemy["hp"] == expected_hp and fine_enemy["hp"] == expected_hp, "Continuous exposure and historical Onyx pulses both honor the mixed-speed path")
		_check(coarse._rune_damage[coarse.towers[0][0]["id"]][enemy["id"]] == 20 - expected_hp, "Damage ledger counts actual observer HP removed, not nominal DPS or pulses")


func _test_debug_round_reset() -> void:
	var combat := _slow_expiry_fixture("boulders")
	combat.advance(0.1)
	combat.send_enemy(0, &"grunt")
	combat.send_enemy(0, &"grunt")
	var tower: Dictionary = combat.towers[0][0]
	var retained: Dictionary = tower.duplicate(true)
	var coins: Array[int] = combat.coins.duplicate()
	var health: Array[int] = combat.base_health.duplicate()
	var income: Array[int] = combat.income.duplicate()
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.debug_set_round(0) and not combat.debug_set_round(1001) and combat.snapshot() == frozen, "Invalid debug rounds reject before mutating live combat")
	_check(combat.debug_set_round(31) and combat.wave == 30 and combat.phase == MatchCombat.Phase.PLANNING, "Debug round denotes the upcoming displayed round")
	_check(combat.coins == coins and combat.base_health == health and combat.income == income and combat.towers[0][0] == retained, "Debug abandonment keeps the build, upgrades, currency, income and base health without a clear reward")
	_check(combat.enemies == [[], []] and combat.queued_sends == [0, 0] and combat.wave_roster.is_empty() and combat.spawn_times.is_empty() and combat._routes == [[], []] and combat._routing_next == [{}, {}] and combat._fork_cursors == [{}, {}] and combat._spawned == [0, 0], "Debug abandonment clears every enemy, route, fork, send and spawn timetable")
	_check(combat._elapsed == 0.0 and combat._continuous_damage.is_empty() and combat._rune_damage.is_empty() and combat._enemy_spawn_times.is_empty() and combat._slow_motion.is_empty(), "Debug abandonment clears all elapsed-time, fractional and damage-credit accounting")
	_check(combat.start_wave(_routes(100, 100)) and combat.wave == 31, "A debug jump restarts using newly captured routes at the chosen round")
	_check(combat.debug_set_round(31) and combat.phase == MatchCombat.Phase.PLANNING and combat.wave == 30, "Selecting the same displayed active round restarts its planning phase")
	_check(combat.debug_set_round(1) and combat.wave == 0 and combat.debug_set_round(1000) and combat.wave == 999, "Both debug round bounds are accepted")
	combat.phase = MatchCombat.Phase.FINISHED
	frozen = combat.snapshot()
	_check(not combat.debug_set_round(1) and combat.snapshot() == frozen, "Debug cannot revive a finished match")
