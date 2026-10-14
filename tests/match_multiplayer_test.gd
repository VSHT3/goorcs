extends "res://tests/match_planning_test.gd"


func _run() -> void:
	success_message = "PASS: real peers agree on authoritative economy, enemy sends/income/delivery, ownership, live combat, readiness, waves, persistent damage and terminal results"
	planning_worker_path = "res://tests/match_multiplayer_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_combat_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = hosted["code"]
	await _connect_guest("guest", "host", code)
	await _paths()
	await _wait_combat("guest", {"phase": 0, "health": [2, 2], "coins": [200, 200]}, "Guest uses the host's base and starting Coins configuration")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Ready host awaits guest")
	await _build("host", 0, 1, 1, 0)
	await _wait_for("guest", {"flags": [false, false]}, "Planning construction clears readiness")
	var tower: Dictionary = await _wait_tower("guest", 0, Vector2i(1, 1), 0)
	var tower_id: int = int(tower["id"])
	await _wait_combat("guest", {"coins": [155, 200]}, "A real host purchase debits exactly its authoritative price")
	var before: Dictionary = _snapshot("host")["combat"]
	await _build("guest", 0, 2, 1, 1)
	await _build("host", 0, 1, 4, 0)
	await _build("host", 0, -1, 2, 0)
	await _build("host", 0, 1, 1, 0)
	await _build("host", 0, 2, 1, 99)
	await _build("host", 0, 2, 1, 0, "unknown_tower")
	await _command("guest", {"action": "target", "slot": 0, "tower_id": tower_id, "mode": 2})
	await _command("guest", {"action": "upgrade", "slot": 0, "tower_id": tower_id, "upgrade": "damage"})
	await _command("guest", {"action": "sell", "slot": 0, "tower_id": tower_id})
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": tower_id, "upgrade": "unknown"})
	await _command("host", {"action": "sell", "slot": 0, "tower_id": -1})
	await _edit("host", 0, 1, 1)
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Ownership, occupied/path/outside cells and invalid modes preserve authoritative towers")
	_check(_snapshot("host")["boards"][0]["used"] == 12, "Path cannot overwrite a tower")
	for mode: int in [1, 2, 0]:
		await _command("host", {"action": "target", "slot": 0, "tower_id": tower_id, "mode": mode})
		await _wait_tower("guest", 0, Vector2i(1, 1), mode)
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Guest sees wave start")
	var paths: Array = _snapshot("host")["boards"]
	await _edit("guest", 1, 1, 4, false)
	await _command("host", {"action": "clear", "slot": 0})
	await _command("guest", {"action": "ready", "value": false})
	await _build("host", 0, 3, 3, 1)
	await _wait_tower("guest", 0, Vector2i(3, 3), 1)
	await _command("host", {"action": "target", "slot": 0, "tower_id": tower_id, "mode": 2})
	await _wait_tower("guest", 0, Vector2i(1, 1), 2)
	await _wait_combat("host", {"phase": 0, "wave": 1, "health": [2, 1]}, "Defended host kills enemy; guest leak damages base")
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [2, 1]}, "Both peers agree on first-wave damage")
	_check(_snapshot("host")["boards"] == paths and _snapshot("guest")["boards"] == paths, "Combat rejects route edits without changing captured boards")
	_check(_snapshot("host")["flags"] == [false, false] and not _snapshot("guest")["locked"], "Both-board clearance resets readiness and unlocks planning")
	await _wait_combat("guest", {"coins": [148, 235]}, "Kill bounty belongs only to the killer's board; both surviving boards receive one wave reward")
	var killer: Dictionary = await _wait_tower("guest", 0, Vector2i(3, 3), 1)
	_check(killer["kills"] == 1 and tower_id != int(killer["id"]), "Per-tower kills replicate from the authoritative attack")
	await _command("host", {"action": "ready", "value": true})
	await create_timer(0.2).timeout
	_check(_snapshot("guest")["combat"]["wave"] == 1 and _snapshot("host")["combat"]["phase"] == 0, "One ready player cannot start next wave")
	await _command("guest", {"action": "ready", "value": true})
	await _wait_combat("host", {"phase": 2, "wave": 2, "health": [2, 0], "winner": 0, "coin_flip": false}, "Ordinary base defeat awards surviving host without RNG")
	await _wait_combat("guest", {"phase": 2, "wave": 2, "health": [2, 0], "winner": 0, "coin_flip": false}, "Guest sees identical ordinary result")
	await _assert_terminal(tower_id)
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Disconnect clears combat")
	await _connect_guest("guest", "host", code)
	await _paths()
	await _wait_combat("guest", {"phase": 0, "health": [2, 2], "wave": 0}, "Rejoin resets health and waves")
	_check(_snapshot("host")["combat"]["towers"] == [[], []], "Rejoin removes previous towers")
	await _wait_combat("host", {"coins": [200, 200]}, "Rejoin resets match-only Coins")
	await _both_ready()
	await _wait_combat("host", {"phase": 0, "wave": 1, "health": [1, 1]}, "Equal undefended routes damage both bases together")
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [1, 1]}, "Guest agrees on persistent equal damage")
	await _both_ready()
	var final_state: Dictionary = await _wait_combat("host", {"phase": 2, "wave": 2, "health": [0, 0], "coin_flip": true}, "Same-tick simultaneous defeat invokes coin flip")
	_check(int(final_state.get("winner", -1)) in [0, 1], "Coin flip produces exactly one player winner")
	await _wait_combat("guest", {"phase": 2, "health": [0, 0], "coin_flip": true, "winner": final_state.get("winner", -1)}, "Guest receives the host's coin-flip winner")
	await _assert_terminal(-1)
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Leave resets typed tower boards")
	await _connect_guest("guest", "host", code)
	for type_id: String in ["orc_ballista", "rune_obelisk"]:
		var cell := Vector2i(2 if type_id == "orc_ballista" else 4, 2)
		await _build("host", 0, cell.x, cell.y, 0, type_id)
		var typed_host: Dictionary = await _wait_tower("guest", 0, cell, 0)
		_check(typed_host.get("type_id") == type_id, "Guest sees the host's chosen tower identity")
		await _build("guest", 1, cell.x, cell.y, 1, type_id)
		var typed_guest: Dictionary = await _wait_tower("host", 1, cell, 1)
		_check(typed_guest.get("type_id") == type_id, "Host accepts the guest's chosen tower identity")
	_check(_snapshot("host")["combat"]["tower_types"] == _snapshot("guest")["combat"]["tower_types"], "Both peers use detached host-owned per-type stats")
	await _peer_economy()
	await _peer_sends(code)
	await _peer_typed_sends(code)
	await _finish()


func _paths() -> void:
	await _wait_for("guest", {"active": true}, "Both boards synchronize")
	for lane: String in ["host", "guest"]:
		for x: int in range(1, 13):
			await _edit(lane, 0 if lane == "host" else 1, x, 4)
	await _wait_board("guest", 0, 12, true)
	await _wait_board("host", 1, 12, true)


func _both_ready() -> void:
	await _command("host", {"action": "ready", "value": true})
	await _command("guest", {"action": "ready", "value": true})


func _build(lane: String, slot: int, x: int, y: int, mode: int, type_id: String = "arrow_tower") -> void:
	await _command(lane, {"action": "build", "slot": slot, "x": x, "y": y, "mode": mode, "type_id": type_id})


func _wait_combat(lane: String, expected: Dictionary, description: String) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var observed: Dictionary = _snapshot(lane).get("combat", {})
		if _matches(observed, expected):
			return observed
		await create_timer(0.02).timeout
	_check(false, "%s; expected %s observed %s" % [description, expected, _snapshot(lane).get("combat", {})])
	return _snapshot(lane).get("combat", {})


func _wait_tower(lane: String, slot: int, cell: Vector2i, mode: int) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var towers: Array = _snapshot(lane).get("combat", {}).get("towers", [[], []])[slot]
		for tower: Dictionary in towers:
			if tower.get("cell") == str(cell) and tower.get("mode") == mode:
				return tower
		await create_timer(0.02).timeout
	_check(false, "Tower at %s on %s uses authoritative mode %d" % [cell, lane, mode])
	return {}


func _assert_terminal(tower_id: int) -> void:
	var outcome: Dictionary = _snapshot("host")["combat"]
	await _command("host", {"action": "ready", "value": true})
	await _build("guest", 1, 1, 3, 0)
	await _command("host", {"action": "target", "slot": 0, "tower_id": tower_id, "mode": 1})
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": tower_id, "upgrade": "damage"})
	await _command("host", {"action": "sell", "slot": 0, "tower_id": tower_id})
	await _edit("host", 0, 1, 4, false)
	await _command("host", {"action": "send", "slot": 0, "type_id": "grunt"})
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	for type_id: String in ["runner", "brute"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
		await _command("guest", {"action": "send", "slot": 1, "type_id": type_id})
	await create_timer(0.2).timeout
	_check(_snapshot("host")["combat"] == outcome and _snapshot("guest")["combat"] == outcome, "Finished run rejects commands and cannot reroll or resume")


func _peer_economy() -> void:
	# The preceding typed purchases leave each player one Ballista, one Rune and 45 Coins.
	await _wait_combat("guest", {"coins": [45, 45]}, "Different tower prices debit both network owners")
	await _paths()
	var ballista: Dictionary = await _wait_tower("guest", 0, Vector2i(2, 2), 0)
	var rune: Dictionary = await _wait_tower("guest", 0, Vector2i(4, 2), 0)
	var ballista_id: int = int(ballista["id"])
	var rune_id: int = int(rune["id"])
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Ready remains available with a paid defense")
	var before: Dictionary = _snapshot("host")["combat"]
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": ballista_id, "upgrade": "damage"})
	await _build("host", 0, 6, 2, 0, "rune_obelisk")
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before and _snapshot("guest")["flags"] == [true, false], "Insufficient Coins reject purchases/upgrades without mutation or readiness loss")
	await _command("host", {"action": "sell", "slot": 0, "tower_id": rune_id})
	await _wait_combat("guest", {"coins": [87, 45]}, "Host sale credits only the owning board's floor refund")
	await _wait_for("guest", {"flags": [false, false]}, "Planning sale clears readiness")
	_check(_snapshot("guest")["combat"]["towers"][0].size() == 1, "Sold tower disappears on the remote peer")
	before = _snapshot("host")["combat"]
	await _command("host", {"action": "sell", "slot": 0, "tower_id": rune_id})
	await _command("guest", {"action": "sell", "slot": 0, "tower_id": ballista_id})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Repeated and cross-owner network sales cannot create Coins")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Host can ready again before upgrade")
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": ballista_id, "upgrade": "damage"})
	await _wait_combat("guest", {"coins": [32, 45]}, "Host one-time damage upgrade pays its type-specific price")
	await _wait_for("guest", {"flags": [false, false]}, "Planning upgrade clears readiness")
	ballista = await _wait_tower("guest", 0, Vector2i(2, 2), 0)
	_check(ballista["damage_upgraded"] and ballista["damage"] == 102 and ballista["invested"] == 140 and ballista["sell_value"] == 84, "Network snapshot carries effective damage and real upgraded investment")
	before = _snapshot("host")["combat"]
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": ballista_id, "upgrade": "damage"})
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": ballista_id, "upgrade": "speed"})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Already purchased and unaffordable upgrades preserve every authoritative field")
	var guest_rune: Dictionary = await _wait_tower("host", 1, Vector2i(4, 2), 1)
	var guest_rune_id: int = int(guest_rune["id"])
	await _command("guest", {"action": "ready", "value": true})
	await _wait_for("host", {"flags": [false, true]}, "Guest readiness replicates before upgrade")
	await _command("guest", {"action": "upgrade", "slot": 1, "tower_id": guest_rune_id, "upgrade": "speed"})
	await _wait_combat("host", {"coins": [32, 0]}, "Remote command buys speed with exactly the remaining Coins")
	await _wait_for("host", {"flags": [false, false]}, "Remote upgrade clears readiness")
	guest_rune = await _wait_tower("host", 1, Vector2i(4, 2), 1)
	_check(guest_rune["speed_upgraded"] and is_equal_approx(float(guest_rune["interval"]), 0.05 * 0.85) and guest_rune["invested"] == 115 and guest_rune["sell_value"] == 69, "Guest receives host stats, not its deliberately different local combat configuration")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1}, "Paid/upgraded towers still allow wave starts")
	await _command("host", {"action": "sell", "slot": 0, "tower_id": ballista_id})
	await _wait_combat("guest", {"phase": 1, "coins": [116, 0]}, "Upgraded tower sale is authoritative and legal during a wave")
	await _command("guest", {"action": "sell", "slot": 1, "tower_id": guest_rune_id})
	await _wait_combat("host", {"phase": 1, "coins": [116, 69]}, "Guest can sell during combat with its upgraded refund")
	await _build("host", 0, 5, 2, 0)
	var live_tower: Dictionary = await _wait_tower("guest", 0, Vector2i(5, 2), 0)
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": int(live_tower["id"]), "upgrade": "speed"})
	await _wait_combat("guest", {"phase": 1, "coins": [41, 69]}, "Live tower purchase and speed upgrade debit once without stopping the wave")
	live_tower = await _wait_tower("guest", 0, Vector2i(5, 2), 0)
	_check(live_tower["speed_upgraded"] and not live_tower["damage_upgraded"] and live_tower["kills"] == 0 and is_equal_approx(float(live_tower["interval"]), 0.04), "Live upgraded replacement keeps independent one-time status and host-effective interval")
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": int(live_tower["id"]), "upgrade": "damage"})
	await _wait_combat("guest", {"phase": 1, "coins": [11, 69]}, "Damage upgrade also remains available during combat")
	live_tower = await _wait_tower("guest", 0, Vector2i(5, 2), 0)
	_check(live_tower["damage_upgraded"] and live_tower["damage"] == 100 and live_tower["invested"] == 105 and live_tower["sell_value"] == 63, "Live damage upgrade replicates effective stats and full investment")


func _peer_sends(code: String) -> void:
	# A fresh admission isolates the send economy from the exact tower assertions.
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Disconnect clears the preceding economy scenario")
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "send_scenario"})
	await _connect_guest("guest", "host", code)
	var fresh: Dictionary = await _wait_combat("guest", {"phase": 0, "wave": 0, "health": [6, 6], "coins": [45, 45], "income": [0, 0], "queued_sends": [0, 0], "sends_open": false}, "Fresh send scenario uses host resources and zero income")
	_check(fresh["enemy_types"]["grunt"]["send_cost"] == 20 and fresh["enemy_types"]["grunt"]["send_income"] == 2 and fresh["rules"]["send_cutoff_seconds"] == 0.5, "Guest receives host enemy prices instead of its cheap/high-income/long-cutoff local rules")
	var before: Dictionary = _snapshot("host")["combat"]
	await _command("guest", {"action": "send", "slot": 0, "type_id": "grunt"})
	await _command("host", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _command("guest", {"action": "send", "slot": -1, "type_id": "grunt"})
	await _command("host", {"action": "send", "slot": 2, "type_id": "grunt"})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Authenticated remote/host payers cannot spoof the other slot or use invalid slots")
	await _command("host", {"action": "send", "slot": 0, "type_id": "grunt"})
	await _wait_combat("guest", {"coins": [25, 45], "income": [2, 0], "queued_sends": [0, 1], "enemies": [[], []]}, "Host pays exactly once and queues only on the opponent before any route exists")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _wait_combat("host", {"coins": [25, 25], "income": [2, 2], "queued_sends": [1, 1]}, "Remote payer spends host price and queues on host, not its own board")
	await _command("host", {"action": "send", "slot": 0, "type_id": "grunt"})
	await _wait_combat("guest", {"coins": [5, 25], "income": [4, 2], "queued_sends": [1, 2]}, "Accepted sends accumulate future income without immediate Coins")
	before = _snapshot("host")["combat"]
	await _command("host", {"action": "send", "slot": 0, "type_id": "grunt"})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Insufficient funds change neither Coins, income, queued delivery nor enemies")
	await _paths()
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1, "queued_sends": [0, 0], "spawned": [1, 1], "total": 1}, "Starting the wave drains queues without counting sends as regular spawns")
	await _wait_enemy_counts("guest", [2, 3], "Queued orders become real enemies on their captured target routes")
	await _wait_combat("host", {"phase": 0, "wave": 1, "health": [4, 3], "coins": [44, 62], "income": [4, 2]}, "Regular plus sent leaks affect only their target, and first clear pays base reward plus accumulated income")
	await _wait_combat("guest", {"phase": 0, "health": [4, 3], "coins": [44, 62]}, "Remote sees exact authoritative target damage and first income payout")
	await _both_ready()
	await _wait_combat("host", {"phase": 1, "wave": 2, "sends_open": true}, "Next wave reopens immediate send delivery")
	await _command("host", {"action": "send", "slot": 0, "type_id": "grunt"})
	var immediate: Dictionary = await _wait_combat("guest", {"phase": 1, "coins": [24, 62], "income": [6, 2], "queued_sends": [0, 0], "spawned": [1, 1], "total": 1}, "An early live send debits now and enters combat instead of a queue")
	await _wait_enemy_counts("guest", [1, 2], "Immediate host order appears only on the guest board")
	for enemy: Dictionary in immediate["enemies"][1]:
		_check(enemy["hp"] == 6 and enemy["max_hp"] == 6, "Live sent enemies reuse the current wave-scaled enemy health")
	await _wait_combat("guest", {"phase": 1, "sends_open": false}, "Host cutoff closes delivery despite the guest's longer local cutoff")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _wait_combat("host", {"phase": 1, "coins": [24, 42], "income": [6, 4], "queued_sends": [1, 0]}, "Late remote order pays and gains income now but queues for the host's next wave")
	await _wait_enemy_counts("host", [1, 2], "Late send creates no extra current-wave enemy")
	await _wait_combat("host", {"phase": 0, "wave": 2, "health": [3, 1], "coins": [70, 86], "income": [6, 4], "queued_sends": [1, 0]}, "Second clear pays recurring income again without consuming next-wave delivery")
	await _wait_combat("guest", {"phase": 0, "coins": [70, 86], "income": [6, 4], "queued_sends": [1, 0]}, "Both peers agree on repeated income and the deferred send")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 3, "queued_sends": [0, 0], "spawned": [1, 1], "total": 1}, "Deferred send drains at the following wave start")
	await _wait_enemy_counts("guest", [2, 1], "Deferred remote send becomes a real host-board enemy")
	await _wait_combat("host", {"phase": 2, "wave": 3, "health": [1, 0], "winner": 0, "coins": [70, 86], "income": [6, 4]}, "Terminal leaks finish the run without a wave or recurring-income payout")
	await _wait_combat("guest", {"phase": 2, "winner": 0, "coins": [70, 86]}, "Guest agrees on terminal send scenario")
	await _assert_terminal(-1)
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Leaving removes send state")
	await _connect_guest("guest", "host", code)
	await _wait_combat("guest", {"phase": 0, "wave": 0, "health": [6, 6], "coins": [45, 45], "income": [0, 0], "queued_sends": [0, 0], "sends_open": false, "enemies": [[], []]}, "Rejoin resets Coins, recurring income, queues, delivery cutoff and enemies")


func _wait_enemy_counts(lane: String, expected: Array, description: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var combat: Dictionary = _snapshot(lane).get("combat", {})
		var enemies: Array = combat.get("enemies", [[], []])
		if combat.get("phase") == 1 and [enemies[0].size(), enemies[1].size()] == expected:
			return
		await create_timer(0.02).timeout
	_check(false, "%s; expected enemy counts %s observed %s" % [description, expected, _snapshot(lane).get("combat", {})])


func _peer_typed_sends(code: String) -> void:
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Typed sends start in an independent admission")
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "typed_send_scenario"})
	await _connect_guest("guest", "host", code)
	var fresh: Dictionary = await _wait_combat("guest", {"phase": 0, "health": [7, 7], "coins": [200, 200], "income": [0, 0], "send_queues": [[], []]}, "Typed scenario starts with empty ordered queues")
	for type_id: String in ["runner", "brute"]:
		var definition: Dictionary = fresh["enemy_types"][type_id]
		_check(definition["send_cost"] == (25 if type_id == "runner" else 40) and definition["send_income"] == (2 if type_id == "runner" else 4), "Guest receives host-owned %s economy despite different local resources" % type_id)
		_check(definition["health"] == (3 if type_id == "runner" else 10) and is_equal_approx(float(definition["speed"]), 6.5 * (1.7 if type_id == "runner" else 0.65)), "Planning catalog previews host-scaled %s HP and speed" % type_id)
	var before: Dictionary = _snapshot("host")["combat"]
	for type_id: String in ["runner", "brute", "missing_enemy"]:
		await _command("guest", {"action": "send", "slot": 0, "type_id": type_id})
		await _command("host", {"action": "send", "slot": 1, "type_id": type_id})
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": "missing_enemy"})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Typed ownership and unknown-ID rejection leave Coins, income, enemies and queues untouched")
	for lane: String in ["host", "guest"]:
		for type_id: String in ["runner", "brute"]:
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	await _wait_combat("guest", {"coins": [135, 135], "income": [6, 6], "queued_sends": [2, 2], "send_queues": [["runner", "brute"], ["runner", "brute"]]}, "Each peer pays host per-type prices and preserves mixed send order on its target")
	await _paths()
	await _both_ready()
	await _wait_enemy_counts("guest", [3, 3], "Mixed planning queues join one baseline Grunt per board")
	await create_timer(0.15).timeout
	for lane: String in ["host", "guest"]:
		var moving: Dictionary = _snapshot(lane)["combat"]
		_check_peer_enemy_types(moving, [["runner", "brute", "grunt"], ["runner", "brute", "grunt"]], 4, "First-wave %s replication" % lane)
		for slot: int in range(2):
			var runner: Dictionary = moving["enemies"][slot][0]
			var brute: Dictionary = moving["enemies"][slot][1]
			_check(float(brute["progress"]) > 0.0 and is_equal_approx(float(runner["progress"]) / float(brute["progress"]), 1.7 / 0.65), "Host movement advances simultaneous Runner and Brute at independent actual speeds on %s" % lane)
	for lane: String in ["host", "guest"]:
		var runner_leaked: Dictionary = await _wait_combat(lane, {"phase": 1, "health": [6, 6]}, "Runner leaks before Grunt or Brute on %s" % lane)
		_check_peer_enemy_types(runner_leaked, [["brute", "grunt"], ["brute", "grunt"]], 4, "Fast Runner is removed, not just relabeled")
	for lane: String in ["host", "guest"]:
		var grunt_leaked: Dictionary = await _wait_combat(lane, {"phase": 1, "health": [5, 5]}, "Baseline Grunt leaks while slow Brute still travels on %s" % lane)
		_check_peer_enemy_types(grunt_leaked, [["brute"], ["brute"]], 4, "Slow Brute remains independently alive")
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [4, 4], "coins": [176, 176], "income": [6, 6]}, "Brutes finally leak and one clear pays each accumulated income")
	await _both_ready()
	await _wait_enemy_counts("guest", [1, 1], "Wave two first spawns its baseline Grunts")
	await _command("host", {"action": "send", "slot": 0, "type_id": "runner"})
	await _command("guest", {"action": "send", "slot": 1, "type_id": "brute"})
	var live: Dictionary = await _wait_combat("guest", {"phase": 1, "wave": 2, "coins": [151, 136], "income": [8, 10], "send_queues": [[], []]}, "Early typed sends use different prices and immediate delivery")
	_check_peer_enemy_types(live, [["grunt", "brute"], ["grunt", "runner"]], 6, "Live Runner and Brute use current-wave scaled HP")
	await _wait_combat("guest", {"phase": 1, "sends_open": false}, "Host cutoff applies despite guest enemy-resource differences")
	for type_id: String in ["brute", "runner"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
	for type_id: String in ["runner", "brute"]:
		await _command("guest", {"action": "send", "slot": 1, "type_id": type_id})
	await _wait_combat("guest", {"phase": 1, "coins": [86, 71], "income": [14, 16], "queued_sends": [2, 2], "send_queues": [["runner", "brute"], ["brute", "runner"]]}, "Cutoff queues retain each target's independent mixed-type order")
	await _wait_combat("host", {"phase": 0, "wave": 2, "health": [2, 2], "coins": [140, 127], "send_queues": [["runner", "brute"], ["brute", "runner"]]}, "Queued types survive wave clear and recurring income pays again")
	await _wait_combat("guest", {"phase": 0, "health": [2, 2], "coins": [140, 127]}, "Guest agrees on typed leak outcomes and recurring rewards")
	await _both_ready()
	await _wait_enemy_counts("guest", [3, 3], "Next-wave mixed queues drain once alongside regular Grunts")
	for lane: String in ["host", "guest"]:
		var delivered: Dictionary = _snapshot(lane)["combat"]
		_check_peer_enemy_types(delivered, [["runner", "brute", "grunt"], ["brute", "runner", "grunt"]], 8, "Deferred sends recompute next-wave HP without losing type or order")
		_check(_matches(delivered, {"send_queues": [[], []], "queued_sends": [0, 0]}), "Typed deliveries drain ordered queues and HUD counts together")
	var finished: Dictionary = await _wait_combat("host", {"phase": 2, "wave": 3, "health": [0, 0], "coins": [140, 127], "income": [14, 16], "coin_flip": true}, "Independent typed pressure reaches a frozen normal terminal outcome without another payout")
	await _wait_combat("guest", {"phase": 2, "winner": finished.get("winner", -1), "health": [0, 0], "coins": [140, 127]}, "Both ENet peers agree on typed-send terminal result")
	await _assert_terminal(-1)
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Leaving clears typed enemy state")
	await _connect_guest("guest", "host", code)
	await _wait_combat("guest", {"phase": 0, "wave": 0, "health": [7, 7], "coins": [200, 200], "income": [0, 0], "send_queues": [[], []], "queued_sends": [0, 0], "enemies": [[], []], "sends_open": false}, "Rejoin resets both typed queues, income, enemies and delivery window")
	for lane: String in ["host", "guest"]:
		for type_id: String in ["brute", "brute", "brute", "brute", "runner"]:
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	await _wait_combat("guest", {"coins": [15, 15], "income": [18, 18], "queued_sends": [5, 5]}, "Typed affordability scenario pays each actual price before rejection")
	before = _snapshot("host")["combat"]
	for lane: String in ["host", "guest"]:
		for type_id: String in ["runner", "brute"]:
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == before and _snapshot("guest")["combat"] == before, "Both typed unaffordable sends reject atomically even when guest local prices would permit them")


func _check_peer_enemy_types(combat: Dictionary, expected: Array, wave_health: int, description: String) -> void:
	for slot: int in range(2):
		var observed: Array = combat["enemies"][slot]
		var identities: Array[String] = []
		for enemy: Dictionary in observed:
			var type_id: String = enemy.get("type_id", "")
			identities.append(type_id)
			var hp_multiplier: float = 0.6 if type_id == "runner" else (2.5 if type_id == "brute" else 1.0)
			var speed_multiplier: float = 1.7 if type_id == "runner" else (0.65 if type_id == "brute" else 1.0)
			_check(enemy["hp"] == ceili(wave_health * hp_multiplier) and enemy["max_hp"] == ceili(wave_health * hp_multiplier) and is_equal_approx(float(enemy.get("speed", 0.0)), 6.5 * speed_multiplier), "%s: %s carries authoritative HP and speed on board %d" % [description, type_id, slot])
		_check(identities == expected[slot], "%s: board %d keeps ordered typed identities; observed %s" % [description, slot, identities])

