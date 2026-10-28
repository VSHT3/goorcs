extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_every_purchase_and_atomic_rejection()
	_test_discounted_reroll_batches_and_max()
	_test_each_production_effect_and_exclusions()
	_test_fractional_sources_and_replacement()
	_test_cycle_batch_rng_and_counter()
	_test_actual_periodic_coarse_fine()
	_test_stone_tiers_zero_bounty_and_replacement()
	_test_rush_deadline_and_refresh()
	_test_copper_tooth_and_real_clean_clears()
	_test_mimic_wait_and_summon_serving()
	_test_send_prices_provenance_and_transfer()
	_test_mark_attribution_and_normal_bounty()
	_test_all_items_one_board_economy()
	if failures == 0:
		print("PASS: all economy items, real purchases/production/kill/clear/send callbacks, fractional ledgers, cycle RNG, replacement, deadlines, attribution, atomic rejects and all130 composition")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules(ids: Array = [], rolls: bool = false) -> CombatRules:
	var rules: CombatRules = CombatRules.new()
	rules.starting_items = [PackedStringArray(ids), PackedStringArray()]
	rules.starting_coins = 1000000
	rules.starting_reroll_currency = 100000
	rules.roll_rules = preload("res://resources/combat/tower_rolls.tres").duplicate(true) as TowerRollRules if rolls else null
	rules.enemy_health = 1000
	rules.enemy_speed = 0.0
	rules.health_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	var grunt: EnemyDefinition = preload("res://resources/combat/enemies/grunt.tres").duplicate(true) as EnemyDefinition
	grunt.send_first_wave = 1
	grunt.send_cost = 12
	grunt.reroll_drop_chance = 0.0
	var zero: EnemyDefinition = grunt.duplicate(true) as EnemyDefinition
	zero.id = &"zero_bounty"
	zero.regular_spawn_enabled = false
	zero.send_enabled = false
	zero.kill_bounty = 0
	rules.catalog.enemies = [grunt, zero]
	return rules


func _new(ids: Array = [], rolls: bool = false) -> MatchCombat:
	var combat: MatchCombat = MatchCombat.new(_rules(ids, rolls))
	_check(combat.item_runtime.error_message.is_empty(), "Shipped numeric item definitions admit the economy fixture")
	return combat


func _routes(length: int = 100) -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for index: int in range(length + 1):
		route.append(Vector2i(index, 0))
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	return [{"route": route, "next": next}, {"route": route.duplicate(), "next": next.duplicate(true)}]


func _start(combat: MatchCombat) -> void:
	_check(combat.start_wave(_routes()), "Real host admits a route and starts the wave")
	combat.advance(0.001)


func _mine(combat: MatchCombat, evolution: String = "", cell: Vector2i = Vector2i(0, 10)) -> Dictionary:
	_check(combat.build(0, cell, &"gold_mine", 0), "Real host purchases Gold Mine")
	var tower: Dictionary = combat.towers[0].back()
	if not evolution.is_empty():
		_check(combat.upgrade_tower(0, tower["id"], "damage") and combat.upgrade_tower(0, tower["id"], "speed") and combat.upgrade_tower(0, tower["id"], evolution), "Real host purchases production branch prerequisites and evolution")
	return tower


func _attacker(combat: MatchCombat, slot: int = 0, cell: Vector2i = Vector2i(0, 10)) -> Dictionary:
	_check(combat.build(slot, cell, &"arrow_tower", 0), "Real host purchases killing source outside automatic range")
	return combat.towers[slot].back()


func _kill(combat: MatchCombat, tower: Dictionary, type_id: String = "grunt", summon: bool = false) -> Dictionary:
	combat._spawn_enemy(0, type_id, 0.0, combat._elapsed, [], 700 if summon else -1)
	var enemy: Dictionary = combat.enemies[0].back()
	var coins_before: int = combat.coins[0]
	var shards_before: int = combat.reroll_currency[0]
	_check(combat._hit(0, tower, combat.enemies[0].size() - 1, 1000000000, true), "Real host resolves lethal damage and retires exactly one enemy")
	return {"coins": combat.coins[0] - coins_before, "shards": combat.reroll_currency[0] - shards_before, "golden": bool(enemy.get("item_golden", false))}


func _finish(combat: MatchCombat, first: Dictionary, second: Dictionary) -> void:
	for slot: int in range(2):
		var tower: Dictionary = first if slot == 0 else second
		while not combat.enemies[slot].is_empty():
			combat._hit(slot, tower, 0, 1000000000, true)
	combat.advance(0.001)
	_check(combat.phase == MatchCombat.Phase.PLANNING, "Only actual exhausted host waves become rewarded clears")


func _test_every_purchase_and_atomic_rejection() -> void:
	var combat: MatchCombat = _new(["dabloons", "spore_spawn_of_marko", "the_whole_shebang"])
	for currency: String in ["coins", "shards"]:
		for kind: String in ["build", "upgrade", "terrain", "send_boss", "feed", "item_upgrade", "rarity_reroll", "attribute_reroll"]:
			_check(combat.item_price(0, currency, 11, kind) == 10 and combat.item_price(1, currency, 11, kind) == 11, "Dabloons discounts every currency/action, independently per owner: %s/%s" % [currency, kind])
	_check(combat.item_price(0, "income", 11) == 11 and combat.item_price(0, "coins", 0) == 0, "Nonpurchase balances and free prices are not discounted into currency")
	combat.coins[0] = 40
	var frozen: Dictionary = combat.snapshot()
	var random_before: int = combat.item_runtime.random.state
	var roll_before: int = combat._roll_random.state
	_check(not combat.build(0, Vector2i.ZERO, &"arrow_tower", 0) and combat.snapshot() == frozen and combat.item_runtime.random.state == random_before and combat._roll_random.state == roll_before, "Unaffordable discounted build has no payment, roll, ID or item-state mutation")
	combat.coins[0] = 109
	_check(combat.build(0, Vector2i.ZERO, &"arrow_tower", 0), "Exact discounted purchase succeeds")
	var tower: Dictionary = combat.towers[0][0]
	_check(combat.coins[0] == 68 and tower["invested"] == 41, "45-Coin build charges ceil40.5 once")
	_check(combat.upgrade_tower(0, tower["id"], "damage") and combat.coins[0] == 41 and combat.upgrade_tower(0, tower["id"], "speed") and combat.coins[0] == 0, "Both upgrade units charge discounted 27 and 41 Coins")
	_check(tower["invested"] == 109 and tower["sell_value"] == 65 and combat.sell_tower(0, tower["id"]) and combat.coins[0] == 65, "Actual discounted investment owns the refund, not undiscounted prices")
	combat.commanders[0] = {"id": "knight", "landmark": Vector2i(9, 9), "obstacles": [Vector2i(1, 1)], "obstacle_variants": [0], "ability_remaining": 0.0, "cooldown_remaining": 0.0, "ability_target": -1}
	combat.coins[0] = 23
	_check(combat.clear_obstacle(0, Vector2i(1, 1)) and combat.coins[0] == 0, "Terrain callback charges ceil25*.9 =23 Coins")
	combat.reroll_currency[0] = 4
	frozen = combat.snapshot()
	random_before = combat.item_runtime.random.state
	_check(not combat.item_command(0, &"spore_spawn_of_marko", "feed") and combat.snapshot() == frozen and combat.item_runtime.random.state == random_before, "Insufficient feed rejects atomically at discounted five-Shard quote")
	combat.reroll_currency[0] = 5
	_check(combat.item_command(0, &"spore_spawn_of_marko", "feed") and combat.reroll_currency[0] == 0, "Paid feed uses same Coin/Shard quote owner and one debit")
	combat.coins[0] = 8999
	frozen = combat.snapshot()
	_check(not combat.item_command(0, &"the_whole_shebang", "upgrade") and combat.snapshot() == frozen, "Discounted item upgrade rejects below actual 9000-Coin price")
	combat.coins[0] = 9000
	_check(combat.item_command(0, &"the_whole_shebang", "upgrade") and combat.coins[0] == 0 and combat.item_runtime.has(0, &"the_whole_shebang_orcfeccion"), "Shebang upgrade debits exactly9000 and changes actual ownership")


func _test_discounted_reroll_batches_and_max() -> void:
	var combat: MatchCombat = _new(["dabloons"], true)
	var tower: Dictionary = _attacker(combat)
	var expected_ten: int = 0
	for index: int in range(10):
		expected_ten += ceili(float(8 + 4 * index + 2 * index * index) * 0.9)
	combat.reroll_currency[0] = expected_ten - 1
	var frozen: Dictionary = combat.snapshot()
	var random_before: int = combat._roll_random.state
	_check(not combat.reroll_tower(0, tower["id"], "rarity", 10) and combat.snapshot() == frozen and combat._roll_random.state == random_before, "Discounted ten-roll batch is atomic at sum-of-unit quotes")
	combat.reroll_currency[0] = expected_ten
	_check(combat.reroll_tower(0, tower["id"], "rarity", 0) and tower["rarity_rerolls"] == 10 and combat.reroll_currency[0] == 0, "Max searches the discounted increasing curve and buys exactly ten units")
	_check(tower["rarity_batch_results"].size() == 10, "Accepted Max executes each real rarity candidate")
	combat.coins[0] = 18
	_check(combat.reroll_tower(0, tower["id"], "attributes") and combat.coins[0] == 0, "Attribute reroll pays discounted20-Coin unit and no Shards")
	frozen = combat.snapshot()
	random_before = combat._roll_random.state
	_check(not combat.reroll_tower(0, tower["id"], "rarity", 10.0) and not combat.reroll_tower(0, tower["id"], "rarity", -1) and combat.snapshot() == frozen and combat._roll_random.state == random_before, "Noninteger and unsupported batch atoms reject before any RNG")


func _test_each_production_effect_and_exclusions() -> void:
	var cases: Array[Dictionary] = [
		{"id": "sturdy_pickaxe", "base_clear": 108, "base_periodic": 108, "mint_clear": 108, "mint_periodic": 108},
		{"id": "counting_frame", "base_clear": 110, "base_periodic": 110, "mint_clear": 100, "mint_periodic": 100},
		{"id": "accountants_abacus", "base_clear": 125, "base_periodic": 100, "mint_clear": 125, "mint_periodic": 100},
		{"id": "golden_harvest_sickle", "base_clear": 150, "base_periodic": 100, "mint_clear": 150, "mint_periodic": 100},
		{"id": "undertakers_spade", "base_clear": 85, "base_periodic": 135, "mint_clear": 85, "mint_periodic": 135},
		{"id": "royal_printing_plate", "base_clear": 100, "base_periodic": 100, "mint_clear": 80, "mint_periodic": 150},
		{"id": "mountains_pocket_change", "base_clear": 200, "base_periodic": 200, "mint_clear": 200, "mint_periodic": 200},
	]
	for example: Dictionary in cases:
		var combat: MatchCombat = _new([example["id"]])
		var mine: Dictionary = _mine(combat)
		var mint: Dictionary = _mine(combat, "royal_mint", Vector2i(1, 10))
		var crystal: Dictionary = _mine(combat, "crystal_mine", Vector2i(2, 10))
		_start(combat)
		for source: Dictionary in [mine, mint]:
			var prefix: String = "base" if source == mine else "mint"
			for periodic: bool in [false, true]:
				var produced: int = combat.item_runtime.economy.production(0, source, "coins", 100, 1, periodic)
				var before: int = combat.coins[0]
				combat.item_credit(0, "coins", produced)
				_check(produced == int(example[prefix + ("_periodic" if periodic else "_clear")]) and combat.coins[0] == before + produced, "%s changes actual %s %s output with its authored number" % [example["id"], prefix, "periodic" if periodic else "clear"])
		_check(combat.item_runtime.economy.production(0, crystal, "shards", 100, 1, true) == 100, "%s Coin modifier never changes Crystal Shards" % example["id"])
		_check(is_equal_approx(combat.item_runtime.economy.bounty_bonus(0, mine, 0.5, "mark"), 0.5), "%s never alters Board mark income" % example["id"])
	var diamond: MatchCombat = _new(["prospectors_diamond"])
	var crystal: Dictionary = _mine(diamond, "crystal_mine")
	var coin_mine: Dictionary = _mine(diamond, "", Vector2i(1, 10))
	_start(diamond)
	_check(diamond.item_runtime.economy.production(0, crystal, "shards", 100, 1, false) == 120 and diamond.item_runtime.economy.production(0, crystal, "shards", 100, 1, true) == 120, "Prospector changes clear and periodic Crystal Shards by20%")
	_check(diamond.item_runtime.economy.production(0, coin_mine, "coins", 100, 1, true) == 100, "Prospector never adds Coin production")


func _test_fractional_sources_and_replacement() -> void:
	var combat: MatchCombat = _new(["prospectors_diamond"])
	var first: Dictionary = _mine(combat, "crystal_mine")
	var second: Dictionary = _mine(combat, "crystal_mine", Vector2i(1, 10))
	_start(combat)
	var economy: ItemEconomyEffects = combat.item_runtime.economy
	_check(economy.production(0, first, "shards", 2, 1, true) == 2 and economy.production(0, second, "shards", 2, 1, true) == 2, "Each real source retains its own .4 Shard fraction")
	_check(economy.production(0, first, "shards", 2, 2, true) == 5, "Repeated cycles release whole carried Shards rather than ceil each payout")
	var first_id: int = int(first["id"])
	_check(combat.sell_tower(0, first_id), "Selling a production source is a real host action")
	var replacement: Dictionary = _mine(combat, "crystal_mine", Vector2i(0, 10))
	_check(replacement["id"] != first_id and economy.production(0, replacement, "shards", 2, 1, true) == 2, "Replacement cannot inherit another tower's fractional output")
	var ledger: Dictionary = combat.item_runtime.state(0)["economy"]["production_sources"]
	_check(is_equal_approx(float(ledger[first_id]["shards"]["fraction"]), 0.2) and ledger[first_id]["shards"]["payouts"] == 3, "Sold-source ledger preserves actual historical payout count and remainder")
	_check(combat.remove_item(0, &"prospectors_diamond") and economy.production(0, second, "shards", 2, 1, true) == 2, "Removed production bonus is disabled without inventing a payout")
	_check(combat.grant_item(0, &"prospectors_diamond") and economy.production(0, second, "shards", 2, 2, true) == 5, "Reequipping retains that tower's existing fractional carry")


func _test_cycle_batch_rng_and_counter() -> void:
	var ids: Array = ["mountains_pocket_change", "philosophers_stone", "philosophorers_stone"]
	var batch: MatchCombat = _new(ids)
	var individual: MatchCombat = _new(ids)
	var batch_mine: Dictionary = _mine(batch, "royal_mint")
	var individual_mine: Dictionary = _mine(individual, "royal_mint")
	_start(batch)
	_start(individual)
	batch.item_runtime.random.seed = 772
	individual.item_runtime.random.seed = 772
	var expected_random: RandomNumberGenerator = RandomNumberGenerator.new()
	expected_random.seed = 772
	var mountain_shards: int = 0
	for cycle: int in range(27):
		if expected_random.randf() < 0.10:
			mountain_shards += 1
	var before_batch: int = batch.reroll_currency[0]
	var before_individual: int = individual.reroll_currency[0]
	var produced: int = batch.item_runtime.economy.production(0, batch_mine, "coins", 13, 27, true)
	var split_produced: int = 0
	for cycle: int in range(27):
		split_produced += individual.item_runtime.economy.production(0, individual_mine, "coins", 13, 1, true)
	_check(produced == 702 and split_produced == 702, "Mountain doubles each actual Coin payout, not its cadence")
	_check(batch.reroll_currency[0] - before_batch == mountain_shards + 2 and individual.reroll_currency[0] - before_individual == mountain_shards + 2, "Exactly27 independent10% rolls and two Legendary-counter Shards credit the real host")
	_check(batch.item_runtime.random.state == expected_random.state and individual.item_runtime.random.state == expected_random.state, "Cycle batching consumes identical per-payout item RNG, not perCoin RNG")
	var state: Dictionary = batch.item_runtime.state(0)["economy"]
	_check(state["stone_counter"] == 27 and state["production_sources"][batch_mine["id"]]["coins"]["payouts"] == 27, "All owned Stone tiers share one counter and each real cycle counts once")
	var no_event_random: int = batch.item_runtime.random.state
	_check(batch.item_runtime.economy.production(0, batch_mine, "coins", 13, 0, true) == 0 and batch.item_runtime.economy.production(0, batch_mine, "coins", 0, 9, true) == 0 and batch.item_runtime.random.state == no_event_random and state["stone_counter"] == 27, "Empty or nonexistent production creates no counters, rewards or RNG")
	batch.debug_set_round(3)
	no_event_random = batch.item_runtime.random.state
	_check(batch.item_runtime.economy.production(0, batch_mine, "coins", 13, 9, true) == 0 and batch.item_runtime.random.state == no_event_random and state["stone_counter"] == 27, "No offline periodic payout or RNG while planning/abandoned")
	var crystal: MatchCombat = _new(["philosophorers_stone", "mountains_pocket_change"])
	var crystal_mine: Dictionary = _mine(crystal, "crystal_mine")
	_start(crystal)
	no_event_random = crystal.item_runtime.random.state
	var before: int = crystal.reroll_currency[0]
	_check(crystal.item_runtime.economy.production(0, crystal_mine, "shards", 2, 10, true) == 20 and crystal.reroll_currency[0] == before + 1 and crystal.item_runtime.random.state == no_event_random, "Crystal payouts count Legendary events but never receive Mountain doubles or Shard rolls")


func _test_actual_periodic_coarse_fine() -> void:
	var ids: Array = ["sturdy_pickaxe", "undertakers_spade", "royal_printing_plate", "mountains_pocket_change", "philosophorers_stone"]
	var coarse: MatchCombat = _new(ids)
	var fine: MatchCombat = _new(ids)
	var first: Dictionary = _mine(coarse, "royal_mint")
	var second: Dictionary = _mine(fine, "royal_mint")
	_start(coarse)
	_start(fine)
	coarse.item_runtime.random.seed = 159
	fine.item_runtime.random.seed = 159
	var before_coins: int = coarse.coins[0]
	var before_shards: int = coarse.reroll_currency[0]
	coarse.advance(50.0)
	for tick: int in range(500):
		fine.advance(0.1)
	# Paid Mine upgrades yield ceil(3*1.45)=5 vanilla Coins; item product is4.374.
	_check(coarse.coins[0] - before_coins == 218 and first["coins_generated"] == 218, "Actual Royal Mint callback carries5*4.374 over ten timer payouts")
	_check(coarse.coins == fine.coins and coarse.reroll_currency == fine.reroll_currency and first["coins_generated"] == second["coins_generated"] and coarse.item_runtime.random.state == fine.item_runtime.random.state, "One coarse host tick equals500 fine ticks for production totals, bonuses and RNG")
	_check(coarse.reroll_currency[0] >= before_shards + 1 and coarse.item_runtime.state(0)["economy"]["stone_counter"] == 10, "Real periodic host callbacks reach tenth Stone payout, independent of Coin amount")
	coarse._stun_tower(0, first, 5.0, "item_test", Vector2.ZERO)
	var before: int = first["coins_generated"]
	coarse.advance(4.0)
	_check(first["coins_generated"] == before, "Item multipliers never bypass actual production stun suppression")


func _test_stone_tiers_zero_bounty_and_replacement() -> void:
	var combat: MatchCombat = _new(["philosophers_stone"])
	var tower: Dictionary = _attacker(combat)
	var mine: Dictionary = _mine(combat, "royal_mint", Vector2i(1, 10))
	_start(combat)
	combat.item_runtime.economy.production(0, mine, "coins", 10, 20, true)
	_check(combat.item_runtime.state(0)["economy"]["stone_counter"] == 0, "Rare Stone never counts production")
	for index: int in range(19):
		_check(_kill(combat, tower)["coins"] == 3, "First19 Rare actual kills pay ordinary normal bounty")
	var twentieth: Dictionary = _kill(combat, tower, "zero_bounty", true)
	_check(twentieth["coins"] == 0 and twentieth["shards"] == 0 and twentieth["golden"], "Zero-bounty twentieth kill counts and is golden, but never invents normal Coins")
	for index: int in range(19):
		_kill(combat, tower)
	_check(_kill(combat, tower)["coins"] == 15, "Rare fortieth actual kill pays exactly5x normal3-Coin bounty")
	_check(combat.grant_item(0, &"philosophorers_stone"), "Higher Stone can coexist with retained Rare ID")
	combat.item_runtime.economy.production(0, mine, "coins", 1, 9, true)
	var before: int = combat.reroll_currency[0]
	var fiftieth: Dictionary = _kill(combat, tower)
	_check(fiftieth["coins"] == 15 and combat.reroll_currency[0] == before + 1 and combat.item_runtime.state(0)["economy"]["stone_counter"] == 50, "Legendary replaces Rare against same retained49->50 shared counter")
	_check(combat.remove_item(0, &"philosophorers_stone") and combat.grant_item(0, &"philosophorers_stone"), "Removing/readding highest tier is supported")
	_check(combat.item_runtime.state(0)["economy"]["stone_counter"] == 50 and _kill(combat, tower)["coins"] == 3, "Reequip retains count, gives no free boundary reward or duplicate lower-tier multiplier")


func _test_rush_deadline_and_refresh() -> void:
	var combat: MatchCombat = _new(["philosophers_stone", "philosophorers_stone", "philosophorers_stoner"])
	var tower: Dictionary = _attacker(combat)
	_start(combat)
	for index: int in range(4):
		_check(_kill(combat, tower)["coins"] == 3, "Highest Stone has only one five-event cadence")
	var trigger: Dictionary = _kill(combat, tower)
	_check(trigger["coins"] == 15 and trigger["shards"] == 1, "Fifth kill grants one Shard and includes its own5x Rush bounty")
	combat.advance(3.999)
	_check(_kill(combat, tower)["coins"] == 15, "Rush remains active strictly before four simulation seconds")
	combat.advance(0.001)
	_check(_kill(combat, tower)["coins"] == 3, "Exact four-second Rush deadline expires before next kill")
	_kill(combat, tower)
	_kill(combat, tower)
	_check(_kill(combat, tower)["coins"] == 15, "Tenth shared event refreshes one Rush, never25x bounty")
	combat.advance(2.0)
	for index: int in range(5):
		_kill(combat, tower)
	var until: float = combat.item_runtime.state(0)["economy"]["rush_until"]
	_check(is_equal_approx(until - combat.item_runtime.clock, 4.0), "Retrigger replaces remaining duration with four, not six seconds")
	_check(combat.remove_item(0, &"philosophorers_stoner") and _kill(combat, tower)["coins"] == 3, "Removing Orc Stone immediately disables Rush despite lower Stones remaining")
	_check(combat.grant_item(0, &"philosophorers_stoner") and _kill(combat, tower)["coins"] == 3, "Reequip cannot restore removed timed Rush; shared counter still persists")


func _test_copper_tooth_and_real_clean_clears() -> void:
	var combat: MatchCombat = _new(["copper_tooth", "orcish_lunch_tin"])
	var first: Dictionary = _attacker(combat)
	var second: Dictionary = _attacker(combat, 1)
	_start(combat)
	_check(_kill(combat, first, "zero_bounty", true)["coins"] == 0 and _kill(combat, first)["coins"] == 4 and _kill(combat, first)["coins"] == 3, "Tooth ignores zero bounty and pays only first bounty-paying actual kill")
	_finish(combat, first, second)
	var state: Dictionary = combat.item_runtime.state(0)["economy"]
	_check(state["clean_streak"] == 1 and state["item_credits"]["orcish_lunch_tin"]["coins"] == 10, "Round1 clean actual clear pays floor10.2 +floor1/2 =10")
	var before: int = combat.coins[0]
	combat.item_runtime.economy.on_clear(0, 1)
	_check(combat.coins[0] == before, "Repeated clear callback cannot pay or grow the streak twice")
	_start(combat)
	_check(_kill(combat, first)["coins"] == 4, "New real wave resets first-bounty eligibility")
	_finish(combat, first, second)
	_check(state["clean_streak"] == 2 and state["item_credits"]["orcish_lunch_tin"]["coins"] == 21, "Second clean actual clear includes current streak and pays11")
	_start(combat)
	combat.enemies[0][0]["progress"] = 100.0
	combat._apply_leaks(0)
	_finish(combat, first, second)
	_check(state["clean_streak"] == 0 and state["item_credits"]["orcish_lunch_tin"]["coins"] == 21, "Real leak resets streak and cancels all Lunch Tin clear Coins")
	_start(combat)
	var counter: int = state["stone_counter"]
	before = combat.coins[0]
	_check(combat.debug_set_round(20) and combat.coins[0] == before and state["stone_counter"] == counter and state["clean_streak"] == 0, "Round jump abandons instead of fabricating clear income/counters/streak")
	combat.item_runtime.economy.on_clear(0, 19)
	_check(combat.coins[0] == before, "Abandoned wave cannot be converted into fake Lunch Tin clear")


func _test_mimic_wait_and_summon_serving() -> void:
	var combat: MatchCombat = _new(["mimics_lunch_pail"])
	var tower: Dictionary = _attacker(combat)
	combat.advance(100.0)
	_start(combat)
	_check(_kill(combat, tower)["coins"] == 3, "Planning time never prearms a Mimic serving")
	combat.advance(9.999)
	_check(not combat.item_runtime.state(0)["economy"]["mimic_ready"], "Mimic stays unarmed before ten kill-free combat seconds")
	combat.advance(0.001)
	_check(combat.item_runtime.state(0)["economy"]["mimic_ready"], "Mimic arms at exact10s deadline")
	_check(_kill(combat, tower, "zero_bounty", true)["coins"] == 0 and combat.item_runtime.state(0)["economy"]["mimic_ready"], "Summoned kill cannot pay or consume an already readied serving")
	_check(_kill(combat, tower)["coins"] == 6 and not combat.item_runtime.state(0)["economy"]["mimic_ready"] and _kill(combat, tower)["coins"] == 3, "Next eligible real kill consumes exactly one3-Coin serving")
	combat.advance(8.0)
	_kill(combat, tower, "zero_bounty", true)
	combat.advance(2.0)
	_check(not combat.item_runtime.state(0)["economy"]["mimic_ready"], "Every actual kill, including a summon, resets unarmed no-kill wait")
	combat.advance(8.0)
	_check(_kill(combat, tower, "zero_bounty")["coins"] == 3, "Nonsummoned zero-bounty kill can consume the flat serving without inventing base bounty")


func _test_send_prices_provenance_and_transfer() -> void:
	var rules: CombatRules = _rules(["dabloons", "couriers_basalt_boots", "command_banner"])
	rules.enemy_speed = 1.0
	rules.enemy_health = 100
	rules.starting_items[1] = PackedStringArray(["orc_tusk", "torn_boot"])
	var combat: MatchCombat = MatchCombat.new(rules)
	_check(combat.item_price(0, "coins", 12, "send") == 12 and combat.item_price(0, "coins", 12, "send_boss") == 11, "Courier cost and Dabloons multiply before one final ceil; bosses exclude Courier")
	var boss_profile: Dictionary = combat.item_runtime.economy.send_profile(0, {"boss": true})
	_check(boss_profile["health_multiplier"] == 1.0 and boss_profile["cost_multiplier"] == 1.0, "Courier never boosts boss sends")
	combat.coins[0] = 11
	var frozen: Dictionary = combat.snapshot()
	var group_random: int = combat._group_random.state
	var item_random: int = combat.item_runtime.random.state
	_check(not combat.send_enemy(0, &"grunt") and combat.snapshot() == frozen and combat._group_random.state == group_random and combat.item_runtime.random.state == item_random, "Declined send has no Coin/income/queue mutation or RNG")
	combat.coins[0] = 12
	_check(combat.send_enemy(0, &"grunt") and combat.coins[0] == 0, "Exact combined discounted send quote purchases one real order")
	combat.remove_item(0, &"couriers_basalt_boots")
	_start(combat)
	var sent: Dictionary = {}
	var ordinary: Dictionary = {}
	for enemy: Dictionary in combat.enemies[1]:
		if String(enemy["original_birth_kind"]) == "send":
			sent = enemy
		else:
			ordinary = enemy
	_check(not sent.is_empty() and sent["max_hp"] == 99 and is_equal_approx(float(sent["speed"]), 1.012), "Accepted send retains frozen CourierHP1.1; defender Tusk.9, Boot.88 and opponent Banner1.15 apply once")
	_check(not ordinary.is_empty() and ordinary["max_hp"] == 100 and is_equal_approx(float(ordinary["speed"]), 1.0), "Ordinary wave arrival excludes every summon/send-only modifier")
	combat._spawn_enemy(1, "grunt", 0.0, combat._elapsed, [], 777)
	var summoned: Dictionary = combat.enemies[1].back()
	_check(summoned["max_hp"] == 90 and is_equal_approx(float(summoned["speed"]), 1.012), "Caster summon receives Tusk/Boot/Banner but never Courier's purchased-send HP")
	var original_hp: int = int(sent["base_max_hp"])
	var original_speed: float = float(sent["base_speed"])
	var moved: Dictionary = sent.duplicate(true)
	moved["birth_kind"] = "transfer"
	var home_profile: Dictionary = combat.item_runtime.economy.arrival_profile(0, moved)
	var away_profile: Dictionary = combat.item_runtime.economy.arrival_profile(1, moved)
	_check(home_profile["health_multiplier"] == 1.0 and home_profile["speed_multiplier"] == 1.0 and is_equal_approx(float(away_profile["health_multiplier"]), 0.9) and is_equal_approx(float(away_profile["speed_multiplier"]), 1.012), "Transferred send keeps original provenance but reevaluates board-relative modifiers, never multiplies prior effective HP/speed")
	_check(sent["base_max_hp"] == original_hp and sent["base_speed"] == original_speed, "Pure profile quotes never mutate immutable birth baselines")


func _test_mark_attribution_and_normal_bounty() -> void:
	var combat: MatchCombat = _new(["gravebound_ledger", "philosophorers_stoner"])
	var killer: Dictionary = _attacker(combat, 0, Vector2i(0, 2))
	var board: Dictionary = _mine(combat, "bounty_board", Vector2i(1, 2))
	var tribute: Dictionary = _mine(combat, "bounty_board", Vector2i(2, 2))
	_check(combat.upgrade_tower(0, tribute["id"], "income_aura"), "Real Tribute branch removes its mark and supplies actual killing-source income")
	_start(combat)
	for index: int in range(4):
		_kill(combat, killer)
	combat._spawn_enemy(0, "grunt", 0.0, combat._elapsed)
	var enemy: Dictionary = combat.enemies[0].back()
	# Retire the current real mark normally, then let this largest victim be marked.
	if int(board["bounty_target_id"]) >= 0:
		var marked: int = combat._enemy_index(0, int(board["bounty_target_id"]))
		if marked >= 0:
			combat._hit(0, killer, marked, 1000000000, true)
	# Bring the shared counter to one event before its next real boundary.
	while int(combat.item_runtime.state(0)["economy"]["stone_counter"]) % 5 != 4:
		_kill(combat, killer)
	enemy["max_hp"] = 100000
	combat._update_bounties(0)
	_check(enemy["bounty_tower_id"] == board["id"], "Real Bounty Board assigns the marked victim")
	var coins: int = combat.coins[0]
	var board_generated: int = board["coins_generated"]
	var tribute_generated: int = tribute["coins_generated"]
	combat._hit(0, killer, combat._enemy_index(0, enemy["id"]), 1000000000, true)
	_check(combat.coins[0] - coins == 20, "Rush, upgraded Board and boosted Tribute pay twenty Coins total")
	_check(board["coins_generated"] - board_generated == 3 and tribute["coins_generated"] - tribute_generated == 2, "Combined rounding attributes marked and aura income to their actual Mine sources")


func _test_all_items_one_board_economy() -> void:
	var rules: CombatRules = _rules()
	var ids: Array = []
	for definition: ItemDefinition in rules.catalog.items:
		ids.append(String(definition.id))
	rules.starting_items[0] = PackedStringArray(ids)
	var combat: MatchCombat = MatchCombat.new(rules)
	_check(ids.size() == 130 and combat.item_runtime.owned_ids(0).size() == 130, "All130 distinct IDs coexist on one actual board without an equipment cap")
	var mine: Dictionary = _mine(combat)
	var mint: Dictionary = _mine(combat, "royal_mint", Vector2i(1, 10))
	var crystal: Dictionary = _mine(combat, "crystal_mine", Vector2i(2, 10))
	var killer: Dictionary = _attacker(combat, 0, Vector2i(3, 10))
	_start(combat)
	var economy: ItemEconomyEffects = combat.item_runtime.economy
	_check(economy.production(0, mine, "coins", 100, 1, false) == 378, "All eligible base-Mine Coin items multiply to3.78675, with one retained fraction")
	_check(economy.production(0, mint, "coins", 100, 1, false) == 275 and economy.production(0, mint, "coins", 100, 1, true) == 437, "All130 preserve Mint clear2.754/periodic4.374 branch-specific composition")
	_check(economy.production(0, crystal, "shards", 2, 2, true) == 4, "All130 Crystal gets only Prospector1.2 with fractional carry, not Coin multipliers")
	var state: Dictionary = combat.item_runtime.state(0)["economy"]
	_check(state["stone_counter"] == 5, "Five real production cycles under all three owned Stones trigger only highest shared counter")
	_check(_kill(combat, killer)["coins"] == 16, "All130 Rush normal15 plus first-kill Tooth1; lower Stones do not stack and bonuses do not recurse")
	var random_before: int = combat.item_runtime.random.state
	var frozen: Dictionary = combat.snapshot()
	_check(not combat.set_items(0, ["dabloons", "unknown"]) and not combat.set_items(0, ["dabloons", "dabloons"]) and not combat.set_items(0, ["dabloons", 3]) and combat.snapshot() == frozen and combat.item_runtime.random.state == random_before, "Unknown/duplicate/nonstrings reject the whole all130 owned-set edit atomically")
	_check(combat.item_runtime.state(1)["economy"].get("stone_counter", 0) == 0, "All130 board never advances the opponent's counter")
