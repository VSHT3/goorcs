extends "res://tests/match_planning_test.gd"


func _run() -> void:
	success_message = "PASS: real peers agree on authoritative Coins, purchases/upgrades/sales and ownership, live combat commands, reward/kills, readiness, waves, persistent damage and terminal results"
	planning_worker_path = "res://tests/match_multiplayer_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 60000
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
