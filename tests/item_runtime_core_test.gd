extends SceneTree

const CATALOG: ContentCatalog = preload("res://resources/content_catalog.tres")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rng(seed_value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = seed_value
	return result


func _host(items: Array = []) -> MatchCombat:
	var rules := CombatRules.new()
	rules.starting_coins = 100000
	rules.starting_reroll_currency = 1000
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_jitter_ratio = 0.0
	var host := MatchCombat.new(rules, _rng(11), _rng(22), _rng(33), _rng(44), _rng(55))
	host.configure_item_loadouts([["arrow_tower", "orc_ballista", "war_drums", "gold_mine"], ["arrow_tower"]])
	if not items.is_empty():
		_check(host.set_items(0, items), "Host admits complete valid item set")
	return host


func _all_ids() -> Array:
	var result: Array = []
	for item: ItemDefinition in CATALOG.items:
		result.append(String(item.id))
	return result

func _isolated_catalog() -> ContentCatalog:
	var isolated: ContentCatalog = CATALOG.duplicate() as ContentCatalog
	isolated.items = []
	for source: ItemDefinition in CATALOG.items:
		isolated.items.append(source.duplicate(true) as ItemDefinition)
	return isolated


func _routing() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(14, 5), 30, Vector2i(0, 2), Vector2i(13, 2))
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 2))
	return [layout.capture_routing(), layout.capture_routing()]


func _start(host: MatchCombat) -> void:
	_check(host.start_wave(_routing()), "Host admits actual combat with item-aware next round")


func _run() -> void:
	_test_ownership_and_once_per_run()
	_test_capture_and_invalid_admission()
	_test_command_atomicity_and_snapshots()
	_test_retained_clocks_and_replacements()
	_test_starting_configuration()
	if failures == 0:
		print("PASS: host item ownership is uncapped, Paw is once-per-run and idempotent, snapshots detach, commands reject atomically, clocks and replacement ledgers survive reconciliation")
	quit(1 if failures else 0)


func _test_ownership_and_once_per_run() -> void:
	var host: MatchCombat = _host()
	var runtime: MatchItemRuntime = host.item_runtime
	_check(runtime.owned_ids(0).is_empty() and runtime.owned_ids(1).is_empty(), "Normal runs begin with no owned items")
	var before_rng: int = runtime.random.state
	_check(host.set_items(0, _all_ids()), "All 130 distinct items coexist on one player")
	_check(runtime.owned_ids(0).size() == 130 and runtime.owned_ids(1).is_empty(), "Ownership has no equipment cap or cross-board bleed")
	for item: ItemDefinition in CATALOG.items:
		_check(runtime.has(0, item.id), "All simultaneous ownership retains " + String(item.id))
	_check(runtime.random.state != before_rng, "First Paw grant consumes its independent reward draw even when every Legendary is owned")
	_check(host.base_max_health[0] == 80 and host.base_health[0] == 80, "All max-health items compose before permanent Paw half, without equip healing")
	_check(runtime.definitions.has(runtime.state(0)["defense"]["paw_reward"]), "Paw records a real captured Legendary reward")
	var paw_draw: int = runtime.random.state
	_check(host.remove_item(0, &"monkeys_paw") and host.grant_item(0, &"monkeys_paw"), "Paw can be removed and readded")
	_check(runtime.random.state == paw_draw and host.base_max_health[0] == 80, "Readding Paw neither rerolls nor applies the curse twice")
	_check(host.set_items(0, []), "Entire owned inventory may be removed without a capacity restriction")
	_check(host.base_max_health[0] == 50 and host.base_health[0] == 50, "Paw curse permanently remains after removing every item")
	_check(runtime.defense.maximum_health(0, 120) == 60, "Permanent curse also halves later maximum-HP gains")
	_check(runtime.state(0)["seen"].size() == 130, "Seen run history survives removal of every ownership entry")
	_check(host.set_items(0, _all_ids()) and runtime.random.state == paw_draw, "Reequipping all 130 retains once-per-run reward history")
	var fresh: MatchCombat = _host()
	_check(not fresh.item_runtime.state(0)["seen"].has("monkeys_paw") and fresh.base_max_health[0] == 100, "A reconstructed run alone resets consumed effects and permanent curse")


func _test_capture_and_invalid_admission() -> void:
	var host: MatchCombat = _host(["iron_arrowhead"])
	var runtime: MatchItemRuntime = host.item_runtime
	var before: Array[Dictionary] = runtime.snapshot()
	var draw: int = runtime.random.state
	for invalid: Array in [["iron_arrowhead", "unknown_item"], ["monkeys_paw", "monkeys_paw"], ["monkeys_paw", 7], [null], [false], [{"id": "monkeys_paw"}], [""], [Vector2.ZERO]]:
		_check(not runtime.set_owned(0, invalid), "Malformed/unknown/duplicate owned atoms reject as a complete transaction")
		_check(runtime.snapshot() == before and runtime.random.state == draw, "Rejected owned set changes no state and consumes no Paw draw")
	_check(not runtime.set_owned(-1, []) and not runtime.set_owned(2, []), "Invalid board indices reject without touching another board")
	var custom: ContentCatalog = _isolated_catalog()
	var captured := MatchItemRuntime.new(host, custom, 73)
	var id: StringName = custom.items[0].id
	var accepted: Dictionary = captured.config(0, id).duplicate(true)
	custom.items[0].runtime.clear()
	custom.items[0].title = "Changed after admission"
	_check(captured.config(0, id) == accepted and captured.definitions[String(id)]["title"] != custom.items[0].title, "Runtime captures nested numeric records and metadata independently of mutable resources")
	for invalid_record: Dictionary in [{"unknown": 1}, {"stats": [{"filter": "everyone", "values": {"damage_multiplier": 2.0}}]}, {"stats": [{"filter": "attacking", "values": {"damage_multiplier": "2"}}]}, {"stats": [{"filter": "attacking", "values": {"damage_multiplier": NAN}}]}, {"stats": [{"filter": "attacking", "values": {"damage_multiplier": INF}}]}, {"mechanic": "monkeys_paw", "parameters": {"not_authored": 1}}]:
		var invalid_catalog: ContentCatalog = _isolated_catalog()
		invalid_catalog.items[0].runtime = invalid_record
		var rejected := MatchItemRuntime.new(host, invalid_catalog, 73)
		var rejected_draw: int = rejected.random.state
		_check(not rejected.error_message.is_empty() and not rejected.grant(0, &"monkeys_paw"), "Malformed authored runtime rejects admission without a numeric fallback")
		_check(rejected.random.state == rejected_draw and rejected.owned_ids(0).is_empty(), "Invalid authored numeric data cannot mutate ownership or RNG")


func _test_command_atomicity_and_snapshots() -> void:
	var host: MatchCombat = _host(_all_ids())
	_check(host.build(0, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Build accepted attacking target")
	_check(host.build(0, Vector2i(3, 1), &"war_drums", MatchCombat.TargetMode.FURTHEST), "Build accepted ineligible support target")
	var runtime: MatchItemRuntime = host.item_runtime
	var arrow: int = int(host.towers[0][0]["id"])
	var support: int = int(host.towers[0][1]["id"])
	var before: Array[Dictionary] = runtime.snapshot()
	_check(not runtime.command(0, &"witchs_folded_ladder", "active"), "Combat-only active rejects during planning")
	_check(runtime.snapshot() == before, "Rejected planning active does not start its cooldown")
	_start(host)
	var draw: int = runtime.random.state
	before = runtime.snapshot()
	for args: Array in [[0, &"minute_hand_cannon", "active", support], [0, &"minute_hand_cannon", "active", 999999], [1, &"minute_hand_cannon", "active", arrow], [0, &"worldroot_seed", "bind", support], [0, &"spore_spawn_of_marko", "feed", arrow], [0, &"iron_arrowhead", "grant", -1], [0, &"the_whole_shebang", "upgrade", -1]]:
		_check(not runtime.command(args[0], args[1], args[2], args[3]), "Invalid/unowned/extra-target or already-upgraded item command rejects")
	_check(runtime.snapshot() == before and runtime.random.state == draw, "Rejected commands preserve all gameplay ledgers and RNG")
	var exposed: Array[Dictionary] = runtime.snapshot()
	var action: Dictionary = exposed[0]["entries"]["minute_hand_cannon"]["actions"]["active"]
	_check(action["target_ids"] == [arrow] and action["enabled"] and action["requires_target"], "Host publishes only real eligible Cannon targets")
	_check(runtime.command(0, &"minute_hand_cannon", "active", arrow), "Cannon active executes on the real attacker")
	_check(runtime.command(0, &"witchs_folded_ladder", "active"), "Ladder active coexists with Cannon")
	_check(runtime.command(0, &"bastion_in_a_bottle", "active") and runtime.command(0, &"the_walking_fortress", "active"), "Both defense actives independently execute with every item owned")
	_check(runtime.command(0, &"worldroot_seed", "bind", arrow), "Worldroot binds one accepted friendly attacker")
	var shards: int = host.reroll_currency[0]
	var quota: int = int(runtime.state(0)["combat"]["spore_quota"])
	_check(runtime.command(0, &"spore_spawn_of_marko", "feed"), "Spore feeding executes a real paid quota change")
	_check(host.reroll_currency[0] == shards - 5 and int(runtime.state(0)["combat"]["spore_quota"]) == quota + 1, "Discounted feed rounds once and debits exactly once")
	before = runtime.snapshot()
	_check(not runtime.command(0, &"worldroot_seed", "bind", arrow) and not runtime.command(0, &"minute_hand_cannon", "active", arrow), "Consumed bind and cooling active cannot be repeated")
	_check(runtime.snapshot() == before, "Repeated rejected commands leave accepted active clocks unchanged")
	var detached: Array[Dictionary] = runtime.snapshot()
	detached[0]["active"]["minute_hand_cannon"]["remaining"] = 999.0
	detached[0]["entries"]["minute_hand_cannon"]["actions"]["active"]["target_ids"].clear()
	detached[0]["progression"]["worldroot"]["bound_id"] = -1
	detached[0]["owned"].clear()
	_check(runtime.snapshot() == before, "Returned nested ownership, clocks, targets and progression snapshots cannot mutate authoritative state")
	_check(runtime.next_event_step(20.0) <= 5.0, "Composed next deadline includes the earliest independently active effect")
	var clock: float = runtime.clock
	runtime.advance(0.0)
	runtime.advance(-1.0)
	runtime.advance(NAN)
	_check(runtime.clock == clock and runtime.snapshot() == before, "Zero and invalid simulation spans never advance timers")
	_check(host.advance(0.01), "Real host simulation advances with valid combat time")
	_check(is_equal_approx(runtime.clock, clock + 0.01) and runtime.owned_ids(0).size() == 130, "All 130 ownership entries and independent active items advance in the real host")


func _test_retained_clocks_and_replacements() -> void:
	var host: MatchCombat = _host(["witchs_folded_ladder", "philosophers_stone", "philosophorers_stone", "philosophorers_stoner", "the_whole_shebang", "the_whole_shebang_orcfeccion", "dabloons"])
	var runtime: MatchItemRuntime = host.item_runtime
	_start(host)
	_check(runtime.command(0, &"witchs_folded_ladder", "active"), "Retained clock fixture activates Ladder")
	runtime.advance(2.0)
	_check(runtime.state(0)["cooldowns"]["witchs_folded_ladder"] == 28.0, "Cooldown advances exactly once per simulation span")
	_check(runtime.remove(0, &"witchs_folded_ladder"), "Active item can be unequipped")
	_check(not runtime.state(0)["active"].has("witchs_folded_ladder"), "Unequipping immediately disables its timed buff")
	runtime.advance(3.0)
	_check(runtime.grant(0, &"witchs_folded_ladder") and not runtime.can_command(0, &"witchs_folded_ladder", "active"), "Reequipping retains the advancing cooldown and never auto-recasts")
	_check(runtime.state(0)["cooldowns"]["witchs_folded_ladder"] == 25.0, "Unequipped cooldown retains its exact remaining duration")
	for index: int in range(4):
		var reward: Dictionary = runtime.economy.on_kill(0, {"birth_kind": "wave"}, 3)
		_check(reward["bounty_multiplier"] == 1.0 and reward["bonus_shards"] == 0, "Lower stones do not create parallel triggers while all tiers are owned")
	var fifth: Dictionary = runtime.economy.on_kill(0, {"birth_kind": "wave"}, 3)
	_check(fifth["bounty_multiplier"] == 5.0 and fifth["bonus_shards"] == 1 and runtime.state(0)["economy"]["stone_counter"] == 5, "Highest owned Stone alone controls one shared counter and Gold Rush")
	_check(runtime.remove(0, &"philosophorers_stoner"), "Highest Stone can be explicitly removed")
	_check(runtime.state(0)["economy"]["stone_counter"] == 5 and runtime.state(0)["economy"]["rush_until"] == 0.0, "Removal cancels the active Rush but retains the shared counter")
	for index: int in range(4):
		runtime.economy.on_kill(0, {"birth_kind": "wave"}, 3)
	var tenth: Dictionary = runtime.economy.on_kill(0, {"birth_kind": "wave"}, 3)
	_check(tenth["bounty_multiplier"] == 5.0 and tenth["bonus_shards"] == 1 and runtime.state(0)["economy"]["stone_counter"] == 10, "Legendary precedence inherits the same counter without resetting to zero")
	var coins: int = host.coins[0]
	_check(not runtime.command(0, &"the_whole_shebang", "upgrade") and host.coins[0] == coins, "Already-owned BangBang prevents a paid duplicate upgrade while preserving both IDs")
	_check(runtime.remove(0, &"the_whole_shebang_orcfeccion"), "Explicitly removing upgrade target restores upgrade eligibility")
	var ledger: Dictionary = runtime.state(0)["progression"]["shebang"].duplicate(true)
	_check(runtime.command(0, &"the_whole_shebang", "upgrade"), "Paid Shebang upgrade performs a single explicit replacement")
	_check(host.coins[0] == coins - 9000 and not runtime.has(0, &"the_whole_shebang") and runtime.has(0, &"the_whole_shebang_orcfeccion"), "Upgrade applies discount once, debits once and replaces only its source")
	_check(runtime.state(0)["progression"]["shebang"] == ledger, "Paid replacement preserves the complete historical branch ledger")


func _test_starting_configuration() -> void:
	var rules := CombatRules.new()
	rules.starting_items = [PackedStringArray(["iron_arrowhead", "lucky_fang"]), PackedStringArray(["oiled_gears"])]
	var host := MatchCombat.new(rules, _rng(61), _rng(62))
	rules.starting_items[0].clear()
	rules.starting_items[1].append("monkeys_paw")
	_check(host.item_runtime.owned_ids(0) == ["iron_arrowhead", "lucky_fang"] and host.item_runtime.owned_ids(1) == ["oiled_gears"], "Host captures independent starting board inventories before later rule edits")
	_check(host.base_max_health[0] == 100 and host.base_max_health[1] == 100, "Changing admitted starting arrays cannot inject a later Paw curse")
