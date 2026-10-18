extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func rules() -> CombatRules:
	var result := CombatRules.new()
	result.starting_coins = 10000
	result.base_health = 2
	result.enemy_speed = 0.0
	result.speed_growth_fraction = 0.0
	result.spawn_interval = 0.0
	result.spawn_jitter_ratio = 0.0
	result.wave_weight = 1
	result.wave_weight_growth = 0
	var enemy: EnemyDefinition = result.catalog.enemies[0].duplicate() as EnemyDefinition
	enemy.id = &"grunt"
	enemy.kill_bounty = 7
	enemy.group_weights = PackedInt32Array([1])
	enemy.base_damage = 5
	enemy.health_multiplier = 1.0
	enemy.send_first_wave = 1
	enemy.reroll_drop_chance = 0.0
	result.catalog.enemies = [enemy]
	return result
func routing() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(6, 3), 30, Vector2i(0, 1), Vector2i(5, 1))
	for x: int in range(1, 5): layout.place(Vector2i(x, 1))
	return [layout.capture_routing(), layout.capture_routing()]
func run() -> void:
	var config := rules()
	var combat := MatchCombat.new(config)
	check(combat.build(0, Vector2i(1, 0), &"arrow_tower", 0), "Real purchase succeeds")
	var tower: Dictionary = combat.towers[0][0]
	var price: int = combat.snapshot()["tower_types"]["arrow_tower"]["cost"]
	check(not combat.build(0, Vector2i(1, 0), &"arrow_tower", 0), "Rejected duplicate purchase stays uncharged")
	check(combat.upgrade_tower(0, tower["id"], "damage"), "Real upgrade succeeds")
	var upgraded_investment: int = tower["invested"]
	check(not combat.upgrade_tower(0, tower["id"], "damage"), "Rejected repeated upgrade stays uncharged")
	check(combat.send_enemy(0, &"grunt"), "Real paid order succeeds")
	check(combat.start_wave(routing()), "Recorded run starts")
	tower["cooldown"] = 1000.0
	combat.advance(0.001)
	var enemy: Dictionary = combat.enemies[0][0]
	var hp: int = enemy["hp"]
	combat._hit(0, tower, 0, 3)
	combat._ignite(enemy, tower, {"burn_dps": 100.0, "burn_duration": 1.0})
	var refund: int = tower["sell_value"]
	check(combat.sell_tower(0, tower["id"]), "Killer sells while its actual burn remains")
	combat.advance(0.1)
	check(combat.build(0, Vector2i(1, 0), &"arrow_tower", 0), "New identity can occupy sold cell")
	combat.towers[0][0]["cooldown"] = 1000.0
	for leaked: Dictionary in combat.enemies[1]: leaked["progress"] = leaked["route"].size() - 1
	combat.advance(0.5)
	check(combat.phase == MatchCombat.Phase.FINISHED, "Actual enemy leaks terminate the run")
	var state: Dictionary = combat.snapshot()
	var side: Dictionary = state["recap"]["sides"][0]
	check(side["spent"]["towers"] == price * 2 and side["spent"]["upgrades"] == upgraded_investment - price and side["spent"]["sends"] == config.catalog.enemies[0].send_cost, "Only accepted purchase/upgrade/order transactions enter their actual categories")
	check(side["earned"]["sale_coins"] == refund and side["earned"]["kill_coins"] == 7, "Refund and actual kill income stay separate")
	var records: Array = side["towers"]
	check(records.size() == 2 and records[0]["sold"] and not records[1]["sold"] and records[0]["id"] != records[1]["id"], "Report retains sold identities separately from replacements")
	check(records[0]["damage_dealt"] == hp and records[0]["kills"] == 1, "A real sold-source burn continues updating its retained final performance")
	check(state["recap"]["sides"][1]["base_damage"]["grunt"] == 2 and state["recap"]["sides"][1]["defeated_by"] == "grunt", "Leak attribution records actual crystal HP removed and fatal type")
	var frozen: Dictionary = combat.snapshot()
	check(not combat.sell_tower(0, combat.towers[0][0]["id"]) and not combat.build(0, Vector2i(2, 0), &"arrow_tower", 0) and not combat.advance(5.0) and combat.snapshot() == frozen, "Terminal commands cannot change final accounting")
	state["recap"]["sides"][0]["towers"][0]["damage_dealt"] = -1
	check(combat.snapshot()["recap"]["sides"][0]["towers"][0]["damage_dealt"] == hp, "Nested returned report is detached from the authoritative final state")
	var fresh := MatchCombat.new(config)
	check(fresh.snapshot()["recap"].is_empty(), "A fresh ongoing model exposes no old terminal report")
	if failures == 0: print("PASS: real recap purchases/upgrades/sends/refunds, rejected transactions, retained sold-source damage, capped fatal leaks, terminal freezing and detachment")
	quit(1 if failures else 0)
