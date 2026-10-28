extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: actual authenticated peers agree on all-130 ownership, frozen host item metadata, paid interactions, targeting, Ready/phase/cooldown rejection and combat-time state"
	planning_worker_path = "res://tests/item_peer_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 120000
	_local_ownership_and_lifetime()
	_directory = OS.get_temp_dir().path_join("gorcs_item_peer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _paths()
	var initial: Dictionary = await _agree("Initial host item admission reaches both real processes")
	_check(initial["items"][0]["owned"].size() == 130, "One board owns all 130 distinct authored items simultaneously")
	_check(initial["items"][1]["owned"].size() == 8, "Guest's empty local configuration does not replace the host's injected ownership")
	_check(initial["item_types"].size() == 130 and initial["item_types"]["spore_spawn_of_marko"]["title"] != "Local divergent item", "Static metadata is detached host data, not guest resource data")
	_check(initial["upcoming_wave"] == 10 and initial["main_round"] and initial["path_editing"], "Doom planning, strategy and actual upcoming wave share round ten")
	await _command("guest", {"action": "mutate_local_items"})
	await _command("host", {"action": "mutate_local_items"})
	_check(await _agree("Resource mutation cannot rewrite admitted item state") == initial, "Both peers may mutate local resources without changing the captured run")
	await _build("host", 0, 1, 1, MatchCombat.TargetMode.FURTHEST)
	await _build("guest", 1, 2, 1, MatchCombat.TargetMode.FURTHEST)
	await _build("guest", 1, 3, 3, MatchCombat.TargetMode.FURTHEST, "rune_obelisk")
	var host_tower: Dictionary = await _wait_tower("guest", 0, Vector2i(1, 1), MatchCombat.TargetMode.FURTHEST)
	var guest_tower: Dictionary = await _wait_tower("host", 1, Vector2i(2, 1), MatchCombat.TargetMode.FURTHEST)
	var rune: Dictionary = await _wait_tower("host", 1, Vector2i(3, 3), MatchCombat.TargetMode.FURTHEST)
	var before: Dictionary = await _agree("Real item-modified towers agree")
	_check(int(host_tower["damage"]) > int(guest_tower["damage"]), "The all-130 board's actual attacker receives composed item damage")
	var rng_before: Dictionary = _host_rng()
	for request: Dictionary in [
		{"slot": 0, "item": "iron_arrowhead", "kind": "grant"},
		{"slot": 1, "item": "iron_arrowhead", "kind": "grant"},
		{"slot": 1, "item": "unknown_item", "kind": "active"},
		{"slot": 1, "item": "witchs_folded_ladder", "kind": "active"},
		{"slot": 1, "item": "worldroot_seed", "kind": "bind", "target": host_tower["id"]},
		{"slot": 1, "item": "worldroot_seed", "kind": "bind", "target": -99},
	]:
		request["action"] = "forged_item"
		await _command("guest", request)
	_check(await _agree("Forged, wrong-owner, unknown and planning-active commands are rejected") == before and _host_rng() == rng_before, "Rejected item requests change neither inventory, costs, effects nor any host RNG")
	await _item("guest", 1, "worldroot_seed", "bind", int(guest_tower["id"]))
	var bound: Dictionary = await _agree("Friendly accepted Worldroot binding reaches both peers")
	_check(bound != before, "Real bind changes the accepted progression ledger")
	await _item("guest", 1, "worldroot_seed", "bind", int(rune["id"]))
	_check(await _agree("A bound seed cannot transfer") == bound, "Second binding cannot transfer or reset the seed")
	var shards_before: int = int(bound["reroll_currency"][1])
	await _item("guest", 1, "spore_spawn_of_marko", "feed")
	var fed: Dictionary = await _agree("First paid feed is authoritative")
	_check(int(fed["reroll_currency"][1]) == shards_before - 5, "A real feed pays ceil(5 times 0.9), not the guest's local zero balance or altered price")
	await _item("guest", 1, "spore_spawn_of_marko", "feed")
	fed = await _agree("Second feed consumes the final five Shards")
	_check(int(fed["reroll_currency"][1]) == 0, "Two actual feeds cost ten Shards total")
	rng_before = _host_rng()
	await _item("guest", 1, "spore_spawn_of_marko", "feed")
	_check(await _agree("Unaffordable feed is atomic") == fed and _host_rng() == rng_before, "Unaffordable feed cannot increase quota, consume randomness or go negative")
	var coins_before: int = int(fed["coins"][1])
	await _item("guest", 1, "the_whole_shebang", "upgrade")
	var upgraded: Dictionary = await _agree("Actual Shebang paid replacement agrees")
	_check(upgraded["items"][1]["owned"].has("the_whole_shebang_orcfeccion") and not upgraded["items"][1]["owned"].has("the_whole_shebang"), "Upgrade explicitly replaces Shebang rather than creating a duplicate")
	_check(int(upgraded["coins"][1]) == coins_before - 9000, "Upgrade uses host 10000-Coin quote with the actual ten-percent discount")
	await _command("host", {"action": "item_balances", "slot": 1, "coins": 10000, "shards": 10})
	await _command("guest", {"action": "ready", "value": true})
	before = await _agree("Guest Ready commits the owner's planning interactions")
	rng_before = _host_rng()
	await _item("guest", 1, "spore_spawn_of_marko", "feed")
	_check(await _agree("Ready blocks an otherwise affordable feed") == before and _host_rng() == rng_before, "Ready cannot be bypassed through the item RPC")
	await _command("host", {"action": "ready", "value": true})
	await _wait_combat("guest", {"phase": 1, "wave": 10}, "Doom starts the actual tenth wave, not a relabeled first wave")
	before = await _agree("Both peers accept all-130 combat start")
	_check(before["items"][0]["owned"].size() == 130, "Starting a real wave retains every simultaneous item")
	rng_before = _host_rng()
	for target: int in [int(host_tower["id"]), int(rune["id"]), -99]:
		await _item("guest", 1, "minute_hand_cannon", "active", target)
	_check(await _agree("Cannon rejects foreign, nonprojectile and missing targets") == before and _host_rng() == rng_before, "Target rejections never consume an active or its cooldown")
	var old_interval: float = float(_tower(before, 1, int(guest_tower["id"]))["interval"])
	await _item("guest", 1, "minute_hand_cannon", "active", int(guest_tower["id"]))
	var cannon: Dictionary = await _agree("Accepted targeted active reaches both processes")
	_check(is_equal_approx(float(_tower(cannon, 1, int(guest_tower["id"]))["interval"]), old_interval / 1.75), "Cannon changes the selected friendly projectile tower's actual attack interval")
	_check(float(cannon["items"][1]["cooldowns"]["minute_hand_cannon"]) == 30.0, "Accepted Cannon starts one host thirty-second cooldown")
	_check(_tower(cannon, 0, int(host_tower["id"]))["interval"] == _tower(before, 0, int(host_tower["id"]))["interval"], "A targeted item does not accidentally affect the other board")
	rng_before = _host_rng()
	await _item("guest", 1, "minute_hand_cannon", "active", int(guest_tower["id"]))
	_check(await _agree("Duplicate active rejects during cooldown") == cannon and _host_rng() == rng_before, "Cooldown rejection is atomic and does not reroll")
	await _item("host", 0, "witchs_folded_ladder", "active")
	await _item("guest", 1, "witchs_folded_ladder", "active")
	await _item("host", 0, "bastion_in_a_bottle", "active")
	await _item("guest", 1, "the_walking_fortress", "active")
	var actives: Dictionary = await _agree("Independent simultaneous actives agree")
	_check(float(actives["items"][0]["cooldowns"]["witchs_folded_ladder"]) == 30.0 and float(actives["items"][1]["cooldowns"]["the_walking_fortress"]) == 60.0, "Host and remote actions follow identical independent cooldown rules")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Guest cannot author item clock or combat") == actives, "Client stepping cannot expire buffs or advance authoritative enemies")
	await _command("host", {"action": "step", "delta": 0.25})
	var stepped: Dictionary = await _agree("Real host attacks, infection and item clocks replicate")
	_check(is_equal_approx(float(stepped["items"][1]["cooldowns"]["minute_hand_cannon"]), 29.75), "Exactly accepted simulation time advances the item clock")
	_check(stepped["enemies"][0].size() > 0 and int(stepped["enemies"][0][0]["hp"]) < int(stepped["enemies"][0][0]["max_hp"]), "All-130 combat executes real damage rather than only publishing inventory")
	await _command("host", {"action": "item_clear_wave"})
	var cleared: Dictionary = await _agree("Actual host kills and wave clear update accepted item ledgers")
	_check(cleared["phase"] == 0 and cleared["wave"] == 10 and cleared["upcoming_wave"] == 20 and cleared["main_round"] and cleared["path_editing"], "Doom clear, upcoming wave, strategy and map growth agree on twenty")
	_check(int(_snapshot("host")["boards"][0]["used"]) == 12 and int(cleared["board_origin_y"]) == -1, "Only required upcoming milestone grows maps while preserving existing path tiles")
	_check(float(_tower(cleared, 1, int(guest_tower["id"]))["damage_multiplier"]) > float(_tower(stepped, 1, int(guest_tower["id"]))["damage_multiplier"]), "A bound seed grows on the actual completed wave, not Doom's skipped rounds")
	await _finish()


func _item(lane: String, slot: int, id: String, kind: String, target: int = -1) -> void:
	await _command(lane, {"action": "item", "slot": slot, "item": id, "kind": kind, "target": target})


func _tower(state: Dictionary, slot: int, id: int) -> Dictionary:
	for tower: Dictionary in state["towers"][slot]:
		if int(tower["id"]) == id:
			return tower
	_check(false, "Expected accepted tower %d" % id)
	return {}


func _host_rng() -> Dictionary:
	var path: String = _path("host", "item_runtime")
	if not FileAccess.file_exists(path):
		_check(false, "Host publishes actual item and gameplay RNG states")
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _local_ownership_and_lifetime() -> void:
	var rules := CombatRules.new()
	var normal := MatchCombat.new(rules)
	_check(normal.item_runtime.owned_ids(0).is_empty() and normal.item_runtime.owned_ids(1).is_empty(), "Normal run starts with no item selection or acquisition")
	var all_ids: Array[String] = []
	for definition: ItemDefinition in rules.catalog.items:
		all_ids.append(String(definition.id))
	var sandbox := SandboxController.new()
	sandbox.configure(rules.catalog, rules)
	_check(sandbox.set_items(all_ids) and sandbox.combat.item_runtime.owned_ids(0).size() == 130, "Sandbox atomic editor applies every item to the actual model without a cap")
	var before: Array[Dictionary] = sandbox.combat.item_runtime.snapshot()
	var random_before: int = sandbox.combat.item_runtime.random.state
	_check(not sandbox.set_items(["iron_arrowhead", "unknown_item"]) and not sandbox.set_items(["iron_arrowhead", "iron_arrowhead"]), "Whole-set validation rejects unknown and duplicate IDs")
	_check(sandbox.combat.item_runtime.snapshot() == before and sandbox.combat.item_runtime.random.state == random_before, "Invalid editor sets cannot partially remove inventory or consume Paw RNG")
	_check(sandbox.set_items(["witchs_folded_ladder", "minute_hand_cannon"]) and sandbox.build(Vector2i(1, 1), &"arrow_tower"), "Sandbox replaces ownership explicitly and builds through the real owner")
	for x: int in range(1, 13):
		sandbox.edit_path(Vector2i(x, 4), true)
	_check(sandbox.start_wave() and sandbox.item_command(&"witchs_folded_ladder", "active"), "Sandbox active invokes the actual combat item command")
	_check(sandbox.stop(), "Stop abandons without a fictional clear")
	_check(float(sandbox.state["items"][0]["cooldowns"]["witchs_folded_ladder"]) == 30.0, "Stop preserves run cooldown instead of resetting or advancing it")
	sandbox.reset_build()
	_check(sandbox.combat.item_runtime.owned_ids(0).size() == 2 and sandbox.combat.item_runtime.owned_ids(1).is_empty(), "Reset retains only session ownership on the actual editable board")
	_check(sandbox.state["items"][0]["cooldowns"].is_empty(), "Reset starts a genuinely fresh item run with fresh cooldowns")
	_check(sandbox.resize_map(Vector2i(10, 7)) and sandbox.combat.item_runtime.owned_ids(0).size() == 2, "Resize has the same explicit fresh-run and retained-session ownership policy")
	_check(sandbox.remove_item(&"witchs_folded_ladder") and sandbox.add_item(&"iron_arrowhead"), "Sandbox remove/add wrappers mutate real ownership")
	var solo := MatchPlanning.new()
	solo.combat_rules = rules
	rules.starting_items = [PackedStringArray(["witchs_folded_ladder", "minute_hand_cannon"]), PackedStringArray(["iron_arrowhead"])]
	solo._reset_match(true)
	solo.active = true
	_check(solo._host_combat.item_runtime.owned_ids(0) == ["witchs_folded_ladder", "minute_hand_cannon"] and solo._host_combat.item_runtime.owned_ids(1) == ["witchs_folded_ladder", "minute_hand_cannon"], "Solo initial ownership mirrors board zero once rather than mixing both configured sets")
	rules.starting_items[0].append("iron_arrowhead")
	_check(not solo._host_combat.item_runtime.has(0, &"iron_arrowhead"), "Later source PackedStringArray mutation cannot affect admitted solo ownership")
	for board: PathLayout in solo._host_layouts:
		for x: int in range(1, 13):
			board.place(Vector2i(x, 4))
	_check(solo._host_combat.build_mirrored(0, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Solo uses real mirrored towers with globally distinct IDs")
	var own_id: int = int(solo._host_combat.towers[0][0]["id"])
	var other_id: int = int(solo._host_combat.towers[1][0]["id"])
	_check(solo._host_combat.start_wave([solo._host_layouts[0].capture_routing(), solo._host_layouts[1].capture_routing()]), "Solo target regression enters actual combat")
	_check(not solo.item_command(0, &"minute_hand_cannon", "active", other_id), "Solo rejects the counterpart's global tower ID")
	_check(solo.item_command(0, &"minute_hand_cannon", "active", own_id), "Solo accepts its exact own target through identical item rules")
	_check(solo._host_combat.item_runtime.state(1)["active"].is_empty() and int(solo._host_combat.item_runtime.state(0)["active"]["minute_hand_cannon"]["target_id"]) == own_id, "Solo targeted item activation is not mirrored or translated onto the wrong tower")
	_check(solo.item_command(0, &"witchs_folded_ladder", "active") and solo._host_combat.item_runtime.state(1)["cooldowns"].is_empty(), "Solo untargeted active executes once on own board only")
	solo.free()
