extends "res://tests/match_planning_test.gd"


func _run() -> void:
	success_message = "PASS: real peers agree on live tower targeting/building, path locks, waves/both-ready breaks, persistent damage, normal defeat and terminal host-owned coin flip"
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
	await _wait_combat("guest", {"phase": 0, "health": [2, 2]}, "Guest uses the host's base configuration")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Ready host awaits guest")
	await _build("host", 0, 1, 1, 0)
	await _wait_for("guest", {"flags": [false, false]}, "Planning construction clears readiness")
	var tower: Dictionary = await _wait_tower("guest", 0, Vector2i(1, 1), 0)
	var tower_id: int = int(tower["id"])
	var before: Dictionary = _snapshot("host")["combat"]
	await _build("guest", 0, 2, 1, 1)
	await _build("host", 0, 1, 4, 0)
	await _build("host", 0, -1, 2, 0)
	await _build("host", 0, 1, 1, 0)
	await _build("host", 0, 2, 1, 99)
	await _command("guest", {"action": "target", "slot": 0, "tower_id": tower_id, "mode": 2})
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
	await _both_ready()
	await _wait_combat("host", {"phase": 0, "wave": 1, "health": [1, 1]}, "Equal undefended routes damage both bases together")
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [1, 1]}, "Guest agrees on persistent equal damage")
	await _both_ready()
	var final_state: Dictionary = await _wait_combat("host", {"phase": 2, "wave": 2, "health": [0, 0], "coin_flip": true}, "Same-tick simultaneous defeat invokes coin flip")
	_check(int(final_state.get("winner", -1)) in [0, 1], "Coin flip produces exactly one player winner")
	await _wait_combat("guest", {"phase": 2, "health": [0, 0], "coin_flip": true, "winner": final_state.get("winner", -1)}, "Guest receives the host's coin-flip winner")
	await _assert_terminal(-1)
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


func _build(lane: String, slot: int, x: int, y: int, mode: int) -> void:
	await _command(lane, {"action": "build", "slot": slot, "x": x, "y": y, "mode": mode})


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
	await _edit("host", 0, 1, 4, false)
	await create_timer(0.2).timeout
	_check(_snapshot("host")["combat"] == outcome and _snapshot("guest")["combat"] == outcome, "Finished run rejects commands and cannot reroll or resume")
