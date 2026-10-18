extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: separate gameplay peers enforce private decks, host-owned combat/rewards and directional Ballista target/release presentation"
	planning_worker_path = "res://tests/gameplay_peer_scenarios_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 140000
	_directory = OS.get_temp_dir().path_join("gorcs_gameplay_peer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = hosted.get("code", "")
	await _connect_guest("guest", "host", code)
	if "--ballista-only" in OS.get_cmdline_user_args():
		await _directional_ballista_scenario(code)
		await _finish()
		return
	await _admission_and_rolls()
	if failures == 0:
		await _chain_scenario(code)
	if failures == 0:
		await _support_scenario(code)
	if failures == 0:
		await _production_scenario(code)
	if failures == 0:
		await _bounty_scenario(code)
	if failures == 0:
		await _directional_ballista_scenario(code)
	await _finish()


func _snapshot(lane: String) -> Dictionary:
	var result: Dictionary = super._snapshot(lane)
	for kind: String in ["gameplay", "scenario"]:
		var path: String = _path(lane, kind)
		if FileAccess.file_exists(path):
			var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if extra is Dictionary:
				result.merge(extra, true)
	return result


func _agree(description: String) -> Dictionary:
	var deadline: int = mini(_suite_deadline_msec, Time.get_ticks_msec() + 5000)
	while Time.get_ticks_msec() < deadline:
		var host: Dictionary = _snapshot("host").get("combat", {})
		var guest: Dictionary = _snapshot("guest").get("combat", {})
		if not host.is_empty() and host == guest:
			return host
		await create_timer(0.02).timeout
	_check(false, description)
	return _snapshot("host").get("combat", {})


func _choose(lane: String, ids: Array) -> void:
	await _command(lane, {"action": "select", "ids": ids})
	await _wait_for(lane, {"chosen_tower_ids": ids}, "Only the owner's accepted deck returns to its process")


func _commit_decks(host_ids: Array, guest_ids: Array) -> void:
	await _choose("host", host_ids)
	await _choose("guest", guest_ids)
	await _command("host", {"action": "commit"})
	await _wait_for("guest", {"active": false, "opponent_committed": true}, "One deck commit never admits board play")
	await _command("guest", {"action": "commit"})
	await _wait_for("host", {"active": true, "selecting_loadout": false}, "Both private deck commits admit the host")
	await _wait_for("guest", {"active": true, "selecting_loadout": false}, "Both private deck commits admit the client")
	await _command("host", {"action": "seed_fixture"})
	await _agree("Admitted gameplay state agrees without sharing opponent decks")
	_assert_private_decks(host_ids, guest_ids, [[], []])


func _assert_private_decks(host_ids: Array, guest_ids: Array, expected_placed_ids: Array) -> void:
	var host_snapshot: Dictionary = _snapshot("host")
	_check(_matches(host_snapshot, {"chosen_tower_ids": host_ids}) and _matches(_snapshot("guest"), {"chosen_tower_ids": guest_ids}), "Each real process retains its own distinct deck only")
	var payloads: Array = host_snapshot.get("wire_deck_paths", [])
	_check(payloads.size() == 2, "Host exposes both actual recipient-targeted snapshot privacy audits")
	if payloads.size() != 2:
		return
	for slot: int in range(2):
		var paths: Dictionary = payloads[slot]
		var wanted: Array = host_ids if slot == 0 else guest_ids
		_check(paths.size() == 1 and _matches(paths, {"chosen_tower_ids": wanted}), "Recipient %d's actual wire snapshot exposes only its own deck array, including nested gameplay fields; found %s" % [slot, JSON.stringify(paths)])
	var public_views: Array = host_snapshot.get("wire_public_towers", [])
	_check(public_views.size() == 2, "Both targeted payload audits retain public catalog and scoutable placed-tower identities")
	if public_views.size() != 2:
		return
	var combat: Dictionary = host_snapshot.get("combat", {})
	var fixture_catalog_ids: Array = host_snapshot.get("fixture_catalog_ids", [])
	var admitted_catalog_ids: Array = combat.get("tower_types", {}).keys()
	admitted_catalog_ids.sort()
	_check(not fixture_catalog_ids.is_empty() and admitted_catalog_ids == fixture_catalog_ids, "Admission retains the complete host fixture catalog, not just either private deck")
	var placed_ids: Array = [[], []]
	for board: int in range(2):
		for tower: Dictionary in combat.get("towers", [[], []])[board]:
			placed_ids[board].append(tower["type_id"])
	_check(placed_ids == expected_placed_ids, "Privacy audit observes the accepted placements for this lifecycle stage")
	for slot: int in range(2):
		var view: Dictionary = public_views[slot]
		_check(view.get("catalog_ids", []) == fixture_catalog_ids, "Recipient %d retains every public fixture catalog identity independently of dictionary ordering" % slot)
		_check(view.get("placed_ids", []) == expected_placed_ids, "Recipient %d can scout both accepted boards at this lifecycle stage without revealing the opponent's unplaced deck" % slot)


func _fresh(code: String, scenario: String, host_ids: Array, guest_ids: Array) -> void:
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Leaving tears down the previous accepted gameplay model")
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "scenario", "name": scenario})
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"selecting_loadout": true, "active": false, "chosen_tower_ids": []}, "Rejoin starts with a fresh uncommitted private deck")
	await _commit_decks(host_ids, guest_ids)
	await _paths()


func _stable(description: String, before: Dictionary, random_state: String = "") -> void:
	# Commands acknowledge locally before a remote RPC is handled. Give the
	# real host its bounded transport turn before comparing complete snapshots.
	await create_timer(0.15).timeout
	_check(await _agree(description) == before, description)
	if not random_state.is_empty():
		_check(_snapshot("host").get("roll_state", "") == random_state, description + ": no gameplay RNG consumed")


func _tower(state: Dictionary, slot: int, cell: Vector2i) -> Dictionary:
	for tower: Dictionary in state.get("towers", [[], []])[slot]:
		if tower.get("cell") == str(cell):
			return tower
	_check(false, "Expected accepted tower at %s on board %d" % [cell, slot])
	return {}


func _place(lane: String, slot: int, cell: Vector2i, type_id: String, mode: int = MatchCombat.TargetMode.FURTHEST) -> Dictionary:
	await _build(lane, slot, cell.x, cell.y, mode, type_id)
	return await _wait_tower("guest" if lane == "host" else "host", slot, cell, mode)


func _upgrade(lane: String, slot: int, id: int, upgrades: Array) -> void:
	for upgrade: String in upgrades:
		await _command(lane, {"action": "upgrade", "slot": slot, "tower_id": id, "upgrade": upgrade})
		var observer: String = "guest" if lane == "host" else "host"
		var deadline: int = mini(_suite_deadline_msec, Time.get_ticks_msec() + 5000)
		var accepted: bool = false
		while Time.get_ticks_msec() < deadline and not accepted:
			var state: Dictionary = _snapshot(observer).get("combat", {})
			for tower: Dictionary in state.get("towers", [[], []])[slot]:
				if int(tower["id"]) != id:
					continue
				accepted = bool(tower.get(upgrade + "_upgraded", false)) if upgrade in ["damage", "speed", "special"] else tower.get("evolution", "") == upgrade or tower.get("followup", "") == upgrade
			if not accepted:
				await create_timer(0.02).timeout
		_check(accepted, "Remote observer receives the host-accepted %s purchase" % upgrade)


func _reroll(lane: String, slot: int, id: int, kind: String) -> void:
	await _command(lane, {"action": "reroll", "slot": slot, "tower_id": id, "kind": kind})


func _admission_and_rolls() -> void:
	await _wait_for("guest", {"selecting_loadout": true, "active": false}, "Transport connection enters loadout selection, not planning")
	var before: Dictionary = _snapshot("host").get("combat", {}).duplicate(true)
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		await _command(lane, {"action": "authenticated_ready"})
		await _command(lane, {"action": "authenticated_build", "slot": slot, "x": 1, "y": 3, "type_id": "arrow_tower"})
		await _command(lane, {"action": "commit"})
	await create_timer(0.15).timeout
	for lane: String in ["host", "guest"]:
		_check(_snapshot(lane).get("active", true) == false and _snapshot(lane).get("combat", {}) == before and _matches(_snapshot(lane), {"flags": [false, false]}), "Authenticated board commands and empty commits cannot bypass deck admission")
	for ids: Array in [[], ["arrow_tower", "arrow_tower"], ["arrow_tower", "orc_ballista", "rune_obelisk", "lightning", "gold_mine"], ["unknown_tower"]]:
		await _command("guest", {"action": "authenticated_select", "ids": ids, "owned": ["arrow_tower", "orc_ballista", "rune_obelisk", "lightning", "gold_mine"]})
	await create_timer(0.15).timeout
	_check(_matches(_snapshot("guest"), {"chosen_tower_ids": [], "selecting_loadout": true, "active": false}), "Host rejects empty, duplicate, over-four and unregistered deck claims over the real RPC")
	await _command("guest", {"action": "authenticated_select", "ids": ["gold_mine"], "owned": ["arrow_tower"]})
	await create_timer(0.15).timeout
	_check(_matches(_snapshot("guest"), {"chosen_tower_ids": []}), "Claimed collection ownership cannot equip a tower outside that collection")
	var host_ids: Array = ["arrow_tower", "orc_ballista", "rune_obelisk"]
	var guest_ids: Array = ["arrow_tower", "lightning"]
	await _commit_decks(host_ids, guest_ids)
	await _paths()
	before = await _agree("Initial host-defined match resources agree")
	_check(_matches(before, {"coins": [100, 100], "reroll_currency": [8, 8]}), "Client cannot substitute its 99999 Coins or 999 rarity currency at admission")
	var random_state: String = _snapshot("host")["roll_state"]
	await _command("host", {"action": "authenticated_build", "slot": 0, "x": 2, "y": 3, "type_id": "gold_mine"})
	await _command("guest", {"action": "authenticated_build", "slot": 1, "x": 2, "y": 3, "type_id": "orc_ballista"})
	await _stable("Host and remote sender cannot buy an owned-but-unequipped identity", before, random_state)
	var ids: Array[int] = []
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		var placed: Dictionary = await _place(lane, slot, Vector2i(1, 3), "arrow_tower")
		ids.append(int(placed["id"]))
		_check(placed["rarity"] in ["common", "mythic"] and placed["attributes"].size() == 1 and placed["attributes"][0]["effect"] == "damage" and placed["attributes"][0]["value"] == 0.25 and placed["damage"] == 13, "Accepted placement uses the host's roll pool and effective damage, never the guest's 99% modifier")
	await _wait_combat("guest", {"coins": [55, 55]}, "Both senders pay the host's 45-Coin price, not the client's one-Coin definition")
	before = await _agree("Paid placement rolls agree")
	random_state = _snapshot("host")["roll_state"]
	await _reroll("guest", 0, ids[0], "rarity")
	await _reroll("host", 1, ids[1], "attributes")
	await _reroll("guest", 1, ids[1], "outcome")
	await _command("guest", {"action": "forged_rewards"})
	await _command("guest", {"action": "debug", "round": 1, "money": 999999, "shards": 999999})
	await _stable("Wrong-owner, invalid-kind and forged currency/drop/outcome commands change no state or resources", before, random_state)
	await _command("guest", {"action": "mutate_display"})
	await _stable("Mutating client display copies cannot set accepted currency, enemies or winner", before, random_state)
	for slot: int in range(2):
		await _reroll("host" if slot == 0 else "guest", slot, ids[slot], "attributes")
	await _wait_combat("guest", {"coins": [35, 35]}, "Attribute regeneration debits only match Coins")
	var attributes: Dictionary = await _agree("Attribute rerolls reach both processes")
	for slot: int in range(2):
		var old: Dictionary = _tower(before, slot, Vector2i(1, 3))
		var changed: Dictionary = _tower(attributes, slot, Vector2i(1, 3))
		_check(changed["rarity"] == old["rarity"] and changed["attribute_rerolls"] == 1 and changed["attribute_reroll_cost"] == 35 and changed["rarity_rerolls"] == 0, "Attribute rerolls retain rarity and advance only their independent cost counter")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Host commits its otherwise-manageable rolled tower")
	before = await _agree("Committed host state agrees")
	random_state = _snapshot("host")["roll_state"]
	await _reroll("host", 0, ids[0], "rarity")
	await _reroll("host", 0, ids[0], "attributes")
	await _stable("Committed Ready rejects both reroll kinds atomically", before, random_state)
	await _command("guest", {"action": "ready", "value": true})
	await _wait_combat("guest", {"phase": 1}, "Both commits begin combat without automatic simulation")
	for slot: int in range(2):
		await _reroll("host" if slot == 0 else "guest", slot, ids[slot], "rarity")
	await _wait_combat("guest", {"reroll_currency": [0, 0], "coins": [35, 35]}, "Rarity regeneration pays only its separate host-owned resource during combat")
	var rerolled: Dictionary = await _agree("Combat rarity results agree")
	for slot: int in range(2):
		var old: Dictionary = _tower(attributes, slot, Vector2i(1, 3))
		var changed: Dictionary = _tower(rerolled, slot, Vector2i(1, 3))
		_check(changed["rarity"] != old["rarity"] and changed["rarity_rerolls"] == 1 and changed["rarity_reroll_cost"] == 14 and changed["attribute_rerolls"] == 0 and changed["attribute_reroll_cost"] == 20, "Rarity excludes the old tier, preserves its own accelerating counter and resets only attribute cost")
	for slot: int in range(2):
		await _reroll("host" if slot == 0 else "guest", slot, ids[slot], "attributes")
	await _wait_combat("guest", {"coins": [15, 15]}, "Reset attribute price is used by both senders in live combat")
	before = await _agree("Exhausted reroll resources agree")
	random_state = _snapshot("host")["roll_state"]
	for slot: int in range(2):
		for kind: String in ["rarity", "attributes"]:
			await _reroll("host" if slot == 0 else "guest", slot, ids[slot], kind)
	await _stable("Insufficient rarity currency and Coins preserve all attributes, counters, balances and RNG", before, random_state)
	_assert_private_decks(host_ids, guest_ids, [["arrow_tower"], ["arrow_tower"]])


func _chain_scenario(code: String) -> void:
	await _fresh(code, "chain", ["lightning"], ["arrow_tower", "lightning"])
	await _both_ready()
	await _wait_combat("guest", {"phase": 1}, "Both private chain decks enter host-owned combat")
	await _command("host", {"action": "step", "delta": 0.01})
	await _command("host", {"action": "formation_fixture", "slot": 0, "progress": [0.0, 1.0, 2.5, 6.0]})
	var lightning: Dictionary = await _place("host", 0, Vector2i(0, 3), "lightning", MatchCombat.TargetMode.LAST)
	await _command("host", {"action": "step", "delta": 0.01})
	var state: Dictionary = await _agree("Nearest unhit chain damage reaches the real client")
	var chain: Dictionary = _tower(state, 0, Vector2i(0, 3))
	_check(chain["chain_points"].size() == 3, "One accepted chain has exactly its configured three distinct hits")
	_check(chain["damage_dealt"] == 30 and chain["indirect_damage"] == 0 and chain["coins_generated"] == 0, "Three accepted chain contacts replicate exactly 30 lifetime damage, with no invented support or income")
	for index: int in range(4):
		_check(state["enemies"][0][index]["hp"] == (90 if index < 3 else 100), "Nearest eligible jumps deal full damage once each and leave the isolated fourth enemy untouched")
	_check(chain["chain_points"][0] != chain["chain_points"][1] and chain["chain_points"][1] != chain["chain_points"][2] and chain["chain_points"][0] != chain["chain_points"][2], "Accepted chain points never revisit an individual target")
	await _command("guest", {"action": "step", "delta": 50.0})
	await _stable("Client cannot choose chain hits or advance host combat", state)
	await _upgrade("host", 0, int(lightning["id"]), ["damage", "speed", "special"])
	await _command("host", {"action": "step", "delta": 1.0})
	state = await _agree("Purchased escalating chain damage agrees")
	_check(state["enemies"][0][0]["hp"] == 78 and state["enemies"][0][1]["hp"] == 75 and state["enemies"][0][2]["hp"] == 72, "Shared special applies 12, 15 and 18 damage to successive unhit enemies")
	await _upgrade("host", 0, int(lightning["id"]), ["longer_reach"])
	state = await _agree("Permanent chain evolution remains inside the selected identity")
	chain = _tower(state, 0, Vector2i(0, 3))
	_check(chain["type_id"] == "lightning" and chain["evolution"] == "longer_reach" and chain["range"] == 5.0 and chain["behavior_config"]["jump_distance"] == 3.5 and chain["behavior_config"]["successive_hit_bonus"] == 0.25, "Longer Reach captures range/jump changes without discarding purchased escalation or requiring another deck slot")
	_check(chain["damage_dealt"] == 75, "Lifetime damage survives both purchased escalation and permanent evolution on the actual client")
	_assert_private_decks(["lightning"], ["arrow_tower", "lightning"], [["lightning"], []])


func _support_scenario(code: String) -> void:
	await _fresh(code, "support", ["arrow_tower", "war_drums", "lightning", "gold_mine"], ["arrow_tower", "gold_mine"])
	await _place("host", 0, Vector2i(4, 3), "arrow_tower")
	await _place("guest", 1, Vector2i(4, 3), "arrow_tower")
	await _place("host", 0, Vector2i(3, 3), "war_drums")
	var stronger: Dictionary = await _place("host", 0, Vector2i(5, 3), "war_drums")
	await _upgrade("host", 0, int(stronger["id"]), ["damage", "speed"])
	var state: Dictionary = await _agree("Strongest duplicate support reaches the client")
	var archer: Dictionary = _tower(state, 0, Vector2i(4, 3))
	_check(is_equal_approx(archer["support_damage_bonus"], 0.25) and is_equal_approx(archer["support_speed_bonus"], 0.25) and archer["damage"] == 13 and is_equal_approx(archer["interval"], 0.8), "Base War Drums buffs both stats, taking the strongest upgraded duplicate instead of summing copies")
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(5, 2), Vector2i(4, 2)]:
		var support: Dictionary = await _place("host", 0, cell, "war_drums")
		await _upgrade("host", 0, int(support["id"]), ["damage", "speed", "command_banner" if cell == Vector2i(4, 2) else "forge"])
	state = await _agree("Independent permanent support families stack on actual peers")
	archer = _tower(state, 0, Vector2i(4, 3))
	_check(is_equal_approx(archer["support_damage_bonus"], 0.95) and is_equal_approx(archer["support_speed_bonus"], 0.95) and archer["damage"] == 20 and is_equal_approx(archer["interval"], 1.0 / 1.95), "Mixed Drums, pure-damage Forge and pure-speed Banner stack; duplicate Forges do not")
	_check(_tower(state, 1, Vector2i(4, 3))["damage"] == 10 and _tower(state, 1, Vector2i(4, 3))["interval"] == 1.0, "Support never crosses ownership into the opposing board")
	var forge: Dictionary = _tower(state, 0, Vector2i(3, 2))
	var banner: Dictionary = _tower(state, 0, Vector2i(4, 2))
	_check(forge["behavior_config"]["attack_speed_bonus"] == 0.0 and banner["behavior_config"]["damage_bonus"] == 0.0, "Permanent support evolutions replace the mixed base components")
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": int(forge["id"]), "upgrade": "command_banner"})
	await _stable("A purchased support evolution cannot switch branches", state)


func _production_scenario(code: String) -> void:
	await _fresh(code, "economy", ["arrow_tower", "gold_mine"], ["arrow_tower", "gold_mine", "war_drums"])
	await _place("host", 0, Vector2i(0, 0), "gold_mine")
	var mint: Dictionary = await _place("host", 0, Vector2i(1, 0), "gold_mine")
	await _upgrade("host", 0, int(mint["id"]), ["damage", "speed", "royal_mint"])
	await _place("guest", 1, Vector2i(0, 0), "gold_mine")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "runner"})
	await _wait_combat("host", {"queued_sends": [1, 0]}, "A paid remote Runner joins the host's drop-eligible stream")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1}, "Economy scenario starts only after both Ready commands arrive")
	var initial: Dictionary = await _agree("Economy wave captures all paid investments")
	await _command("host", {"action": "step", "delta": 4.99})
	var state: Dictionary = await _agree("Periodic production remains simulation-timed")
	_check(state["coins"] == initial["coins"], "Royal Mint pays nothing before its five-simulation-second interval")
	await _command("host", {"action": "step", "delta": 0.01})
	state = await _agree("Host Mint cadence and amount replicate")
	_check(state["coins"][0] == initial["coins"][0] + 5 and state["coins"][1] == initial["coins"][1], "Upgraded Mint pays ceil(3 * 1.45) to its owner without interest or opponent income")
	_check(_tower(state, 0, Vector2i(1, 0))["coins_generated"] == 5 and _tower(state, 0, Vector2i(0, 0))["coins_generated"] == 0, "Only the producing Mint receives accepted periodic Coin credit")
	await _command("guest", {"action": "step", "delta": 100.0})
	await _stable("Client cannot produce extra periodic Coins or random drops", state)
	await _place("host", 0, Vector2i(0, 3), "arrow_tower")
	await _place("guest", 1, Vector2i(0, 3), "arrow_tower")
	var before_kills: Dictionary = await _agree("Actual purchased killing defenses agree")
	for tick: int in range(3):
		await _command("host", {"action": "step", "delta": 0.02})
	state = await _wait_combat("guest", {"phase": 0}, "Both regular enemies and the sent Runner die to actual tower attacks")
	state = await _agree("Exact clear production, sent rewards and distinct resource drops agree")
	_check(state["coins"][0] == before_kills["coins"][0] + 66 and state["coins"][1] == before_kills["coins"][1] + 35, "Exact clear rewards compose host 7+11 kill bounties, 11 clear Coins, 15 Mine and 22 Mint; guest gets 7+11+15+2 send income")
	_check(_matches(state, {"reroll_currency": [10, 5]}), "Per-type drops belong to the killer: host gets regular 2 + sent Runner 5 + clear 3, guest gets regular 2 + clear 3")
	_check(_matches(state["enemy_totals"][0]["kills"], {"grunt": 1, "runner": 1}) and _matches(state["enemy_totals"][1]["kills"], {"grunt": 1}), "Sent enemies die on the receiving board rather than paying their sender's defenses")
	_check(_tower(state, 0, Vector2i(0, 0))["coins_generated"] == 15 and _tower(state, 0, Vector2i(1, 0))["coins_generated"] == 27, "Distinct Mine and Mint lifetime totals replicate periodic plus clear production, excluding normal rewards")
	_check(_tower(state, 0, Vector2i(0, 3))["damage_dealt"] == 200 and _tower(state, 0, Vector2i(0, 3))["coins_generated"] == 0, "Real peer overkill counts only the two enemies' removed HP, not baseline bounty Coins")


func _bounty_scenario(code: String) -> void:
	await _fresh(code, "bounty", ["arrow_tower", "gold_mine"], ["arrow_tower", "gold_mine", "lightning"])
	var boards: Array[int] = []
	for cell: Vector2i in [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 2)]:
		var board: Dictionary = await _place("host", 0, cell, "gold_mine")
		boards.append(int(board["id"]))
		await _upgrade("host", 0, int(board["id"]), ["damage", "speed", "bounty_board"])
	await _upgrade("host", 0, boards[1], ["stronger_mark"])
	await _upgrade("host", 0, boards[3], ["income_aura"])
	await _command("guest", {"action": "send", "slot": 1, "type_id": "necorcmancer"})
	await _wait_combat("host", {"queued_sends": [1, 0]}, "Actual paid NecOrcmancer supplies summon-only drop candidates")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1}, "Bounty scenario starts only after both Ready commands arrive")
	await _command("host", {"action": "step", "delta": 0.4})
	var state: Dictionary = await _agree("Host selects exclusive highest-maximum-HP bounty targets")
	var caster_id: int = -1
	var grunt_id: int = -1
	for enemy: Dictionary in state["enemies"][0]:
		if enemy["type_id"] == "necorcmancer":
			caster_id = int(enemy["id"])
			_check(enemy["bounty_tower_id"] == boards[0] and is_equal_approx(enemy["bounty_damage_bonus"], 0.2) and is_equal_approx(enemy["bounty_income_bonus"], 0.725), "First Board selects the higher-max-HP caster and captures its damage and scaled income mark")
		elif enemy["type_id"] == "grunt":
			grunt_id = int(enemy["id"])
			_check(enemy["bounty_tower_id"] == boards[1], "Second Board selects another eligible enemy instead of stacking onto the caster")
	_check(caster_id >= 0 and grunt_id >= 0 and _tower(state, 0, Vector2i(2, 3))["bounty_target_id"] == -1, "One enemy has at most one mark and a third Board waits without a free eligible target")
	await _command("host", {"action": "formation_fixture", "slot": 0, "progress": [10.0, 10.0]})
	await _command("host", {"action": "step", "delta": 0.01})
	state = await _agree("Marks survive leaving all Board targeting ranges")
	_check(_tower(state, 0, Vector2i(0, 3))["bounty_target_id"] == caster_id and _tower(state, 0, Vector2i(1, 3))["bounty_target_id"] == grunt_id, "Each Board retains its out-of-range active enemy rather than selecting a replacement")
	await _upgrade("host", 0, boards[0], ["income_aura"])
	state = await _agree("Permanent income branch clears an existing active mark immediately")
	for enemy: Dictionary in state["enemies"][0]:
		if enemy["id"] == caster_id:
			_check(enemy["bounty_tower_id"] == -1 and enemy["bounty_damage_bonus"] == 0.0 and enemy["bounty_income_bonus"] == 0.0, "Replacing marking with an aura cannot leave stale damage or bounty income on its old enemy")
	await _command("host", {"action": "formation_fixture", "slot": 0, "progress": [0.0, 0.0]})
	await _command("host", {"action": "step", "delta": 10.1})
	state = await _agree("Real host ritual creates a marked summon-only enemy")
	var skeletons: int = 0
	for enemy: Dictionary in state["enemies"][0]:
		if enemy["type_id"] == "skeleorc":
			skeletons += 1
			_check(enemy["summoner_id"] == caster_id, "Drop-eligible SkeleOrc was genuinely summoned by the accepted caster")
	_check(skeletons == 1, "Deterministic authored ritual produces exactly one living summon")
	# All enemies leave aura range. The killing tower stays next to both auras;
	# eligibility must follow that tower, never the target's distant position.
	await _command("host", {"action": "formation_fixture", "slot": 0, "progress": [10.0, 10.0, 10.0]})
	var killer: Dictionary = await _place("host", 0, Vector2i(0, 2), "arrow_tower", MatchCombat.TargetMode.STRONGEST)
	await _command("host", {"action": "step", "delta": 0.001})
	state = await _agree("Accepted mark amplifies real physical damage")
	for enemy: Dictionary in state["enemies"][0]:
		if enemy["id"] == caster_id:
			_check(enemy["hp"] == 188 and enemy["bounty_tower_id"] == boards[2], "Remaining Board reclaims the caster and its 20% mark turns a 10-damage attack into 12")
	_check(_tower(state, 0, Vector2i(0, 2))["damage_dealt"] == 10 and _tower(state, 0, Vector2i(2, 3))["indirect_damage"] == 2, "Host partitions accepted amplified HP between killer and exclusive Board in both processes")
	await _upgrade("host", 0, int(killer["id"]), ["damage"])
	await _place("guest", 1, Vector2i(0, 3), "arrow_tower")
	var guest_killer: Dictionary = _tower(await _agree("Both killing towers are paid and accepted"), 1, Vector2i(0, 3))
	await _upgrade("guest", 1, int(guest_killer["id"]), ["damage"])
	var before_kills: Dictionary = await _agree("Bounty payout baseline excludes all actual purchases")
	await _command("guest", {"action": "forged_rewards"})
	await _command("guest", {"action": "step", "delta": 100.0})
	await _stable("Client cannot cash out bounties, summon drops or choose outcomes", before_kills)
	for tick: int in range(4):
		await _command("host", {"action": "step", "delta": 0.02})
	state = await _wait_combat("guest", {"phase": 0}, "Actual attacks clear regular, sent caster and its real summoned child")
	state = await _agree("Marked payouts, strongest duplicate aura and zero-bounty summon drops agree")
	_check(state["coins"][0] == before_kills["coins"][0] + 57 and state["coins"][1] == before_kills["coins"][1] + 20, "One final ceil yields grunt 21 + caster 25 + zero-bounty summon 0 + clear 11; duplicate auras never double the killer-location bonus and Bounty branches produce no Mine income")
	_check(_matches(state, {"reroll_currency": [16, 5]}), "Killer owns grunt 2 + sent caster 4 + summoned SkeleOrc 7 + clear 3; zero normal bounty does not remove summon drop eligibility")
	_check(_matches(state["enemy_totals"][0]["kills"], {"grunt": 1, "necorcmancer": 1, "skeleorc": 1}), "All exact rewards are backed by accepted per-type real attack kills")
	_check(_tower(state, 0, Vector2i(1, 3))["coins_generated"] == 11 and _tower(state, 0, Vector2i(2, 3))["coins_generated"] == 8 and _tower(state, 0, Vector2i(0, 3))["coins_generated"] == 9 and _tower(state, 0, Vector2i(1, 2))["coins_generated"] == 0, "Exact marked and aura bonus Coin ownership replicates without duplicate aura or zero-bounty income")
	_check(_tower(state, 0, Vector2i(0, 2))["damage_dealt"] == 338 and _tower(state, 0, Vector2i(2, 3))["indirect_damage"] == 2, "Later overkills preserve exactly 340 removed HP without attributing nonexistent amplified damage")
	_assert_private_decks(["arrow_tower", "gold_mine"], ["arrow_tower", "gold_mine", "lightning"], [["gold_mine", "gold_mine", "gold_mine", "gold_mine", "arrow_tower"], ["arrow_tower"]])


func _ballista_views() -> Dictionary:
	var result: Dictionary = {}
	for lane: String in ["host", "guest"]:
		var response: Dictionary = await _command(lane, {"action": "ballista_probe"})
		var snapshot: Dictionary = await _wait_for(lane, {"ballista_probe": int(response["id"])}, "Real %s renderer finishes its deterministic Ballista probe" % lane)
		result[lane] = snapshot.get("ballista_views", [])
		_check(result[lane].size() == 2, "Real %s process consumes accepted combat on normal and mirrored PathBoards" % lane)
	return result


func _directional_ballista_scenario(code: String) -> void:
	await _fresh(code, "ballista", ["orc_ballista"], ["orc_ballista"])
	await _both_ready()
	await _wait_combat("guest", {"phase": 1}, "Directional fixture starts an authenticated host-owned wave")
	await _command("host", {"action": "step", "delta": 0.01})
	await _command("host", {"action": "ballista_formation"})
	await _place("host", 0, Vector2i(4, 3), "orc_ballista", MatchCombat.TargetMode.STRONGEST)
	var idle: Dictionary = await _ballista_views()
	for lane: String in ["host", "guest"]:
		for view: Dictionary in idle[lane]:
			var direction: int = 2 if view["mirrored"] else 6
			_check(_matches(view, {"poses": [direction, direction, direction]}) and view["released_pose"] == 3
				and view["tracking_target_id"] >= 0 and view["target_id"] == -1 and view["trace_count"] == 0,
				"%s consumes the host-selected live target before any shot; release state remains un-aimed SE" % lane)
	await _command("host", {"action": "ballista_reload", "seconds": 20.0})
	await _command("host", {"action": "step", "delta": 0.1})
	var loading: Dictionary = await _agree("A long initial reload publishes host-owned live tracking without a shot")
	var loading_tower: Dictionary = _tower(loading, 0, Vector2i(4, 3))
	_check(loading_tower["shot"] == 0 and loading_tower["target_id"] == -1
		and loading_tower["tracking_target_id"] == loading["enemies"][0][0]["id"]
		and float(loading_tower["cooldown"]) > 19.0,
		"Real peers accept a continuous target while no first shot is due")
	await _command("host", {"action": "ballista_reload", "seconds": 0.0})
	await _command("host", {"action": "step", "delta": 0.001})
	var accepted: Dictionary = await _agree("Actual host-selected Ballista shot and victim replicate before presentation")
	var tower: Dictionary = _tower(accepted, 0, Vector2i(4, 3))
	var target: Dictionary = accepted["enemies"][0][0]
	var decoy: Dictionary = accepted["enemies"][0][1]
	_check(int(tower["shot"]) == 1 and tower["target_id"] == target["id"]
		and tower["tracking_target_id"] == target["id"] and target["hp"] == 290 and decoy["hp"] == 100,
		"Actual STRONGEST policy tracks and shoots the farther living target, not the nearer decoy")
	var released: Dictionary = await _ballista_views()
	for lane: String in ["host", "guest"]:
		for view: Dictionary in released[lane]:
			var direction: int = 2 if view["mirrored"] else 6
			_check(view["target_id"] == tower["target_id"] and _matches(view, {"poses": [direction, direction, direction]}) and view["released_pose"] == direction and view["trace_count"] == 1, "%s presents the host's westward shot and flips only its displayed directional choice" % lane)
			_check(view["trace_aim"] == tower["aim"], "%s released bolt retains the actual accepted shot aim" % lane)
	# Eight real host simulation seconds move only the accepted victim from west
	# to east. The closer stationary decoy remains south; no new shot is due.
	await _command("host", {"action": "step", "delta": 8.0})
	var moved: Dictionary = await _agree("Moving accepted victim reaches both real presentation consumers")
	var moved_tower: Dictionary = _tower(moved, 0, Vector2i(4, 3))
	_check(moved_tower["target_id"] == tower["target_id"] and moved_tower["aim"] == tower["aim"] and moved_tower["shot"] == tower["shot"], "Movement preserves the host's accepted target identity, release aim and shot counter")
	_check(float(moved["enemies"][0][0]["progress"]) > 8.0 and float(moved["enemies"][0][1]["progress"]) == 4.0, "Actual host simulation moves the farther victim while its closer decoy stays south")
	var moving: Dictionary = await _ballista_views()
	for lane: String in ["host", "guest"]:
		for index: int in range(moving[lane].size()):
			var view: Dictionary = moving[lane][index]
			var shot_view: Dictionary = released[lane][index]
			var expected: Array = [2, 4, 6] if view["mirrored"] else [6, 4, 2]
			_check(_matches(view, {"poses": expected}) and view["released_pose"] == shot_view["released_pose"], "%s follows only the accepted victim's interpolated logical position across W/S/E, with mirrored E/S/W" % lane)
			_check(view["trace_count"] == 1 and view["trace_origin"] == shot_view["trace_origin"] and view["trace_aim"] == shot_view["trace_aim"], "%s rotating weapon cannot move the already released bolt origin or destination" % lane)
			_check(view["live_muzzle"] != view["trace_origin"] and float(view["released_origin_error"]) < 0.00001, "%s live directional muzzle changes while the captured origin remains the accepted release-pose bolt tip" % lane)
	await _command("host", {"action": "ballista_targeting", "mode": MatchCombat.TargetMode.CLOSEST})
	var changed: Dictionary = await _agree("A targeting-mode command immediately republishes the host's new live target")
	var changed_tower: Dictionary = _tower(changed, 0, Vector2i(4, 3))
	_check(changed_tower["tracking_target_id"] == decoy["id"] and changed_tower["shot"] == 1
		and changed_tower["target_id"] == target["id"] and changed_tower["aim"] == tower["aim"],
		"Mode changes select a new tracking victim during reload without rewriting the released shot")
	await _command("host", {"action": "ballista_targeting", "mode": MatchCombat.TargetMode.STRONGEST})
	await _agree("Restoring Strongest reacquires the original living victim during the same reload")
	for state: String in ["out_of_range", "dead", "absent"]:
		await _command("host", {"action": "ballista_target_state", "state": state})
		var reacquired: Dictionary = await _agree("Host's %s victim replacement reaches the real client" % state)
		var reacquired_tower: Dictionary = _tower(reacquired, 0, Vector2i(4, 3))
		_check(reacquired_tower["tracking_target_id"] == decoy["id"] and reacquired_tower["target_id"] == target["id"]
			and reacquired_tower["shot"] == 1, "The host reacquires a valid replacement for a %s victim while reloading" % state)
		var fallback: Dictionary = await _ballista_views()
		for lane: String in ["host", "guest"]:
			for index: int in range(fallback[lane].size()):
				var view: Dictionary = fallback[lane][index]
				var shot_view: Dictionary = released[lane][index]
				_check(_matches(view, {"poses": [4, 4, 4]}) and view["tracking_target_id"] == decoy["id"]
					and view["target_id"] == tower["target_id"] and view["shot"] == 1,
					"%s renders the host-selected southward replacement after the previous victim becomes %s" % [lane, state])
				_check(view["trace_count"] == 1 and view["trace_origin"] == shot_view["trace_origin"] and view["trace_aim"] == shot_view["trace_aim"], "%s %s victim cannot rewrite the released projectile" % [lane, state])
	await _command("host", {"action": "ballista_target_state", "state": "none"})
	var empty: Dictionary = await _agree("No valid live target is accepted by both real peers")
	_check(_tower(empty, 0, Vector2i(4, 3))["tracking_target_id"] == -1,
		"The host clears live tracking when no valid enemy remains")
	var held: Dictionary = await _ballista_views()
	for lane: String in ["host", "guest"]:
		for index: int in range(held[lane].size()):
			var view: Dictionary = held[lane][index]
			var shot_view: Dictionary = released[lane][index]
			_check(_matches(view, {"poses": [4, 4, 4]}) and view["tracking_target_id"] == -1
				and view["shot"] == 1 and view["trace_origin"] == shot_view["trace_origin"]
				and view["trace_aim"] == shot_view["trace_aim"],
				"%s holds its last accepted tracking aim, not the old westward shot, when no victim remains" % lane)
