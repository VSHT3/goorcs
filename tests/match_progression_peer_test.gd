extends "res://tests/match_planning_test.gd"


func _run() -> void:
	success_message = "PASS: separate host/client committed locks, host-only real-time deadline, autoplay strategy pause, shared exact growth and preserved towers/routes, fresh rejoin"
	planning_worker_path = "res://tests/match_progression_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_progression_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = hosted["code"]
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"active": true}, "Separate guest receives active setup")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 13):
			await _edit(lane, slot, x, 4)
		await _command(lane, {"action": "build", "slot": slot, "x": 0, "y": 0, "type_id": "arrow_tower", "mode": 0})
	await _wait_board("host", 1, 12, true)
	await _wait_shared({"wave": 0, "setup_round": true, "main_round": false, "path_editing": true, "ready_seconds_left": -1.0})
	_check(_snapshot("guest")["combat"]["rules"]["main_round_interval"] == 10 and _snapshot("guest")["combat"]["rules"]["ready_window_seconds"] == 20.0 and _snapshot("guest")["combat"]["rules"]["tiles_per_expansion"] == 6, "Guest accepts host tuning rather than its deliberately incompatible local defaults")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Host Ready commits only its slot")
	await _probe_commit("host", 0)
	await _command("host", {"action": "advance", "seconds": 1000.0})
	await _wait_shared({"wave": 0, "ready_seconds_left": -1.0})
	_check(_snapshot("guest")["permissions"] == [{"path": false, "towers": false}, {"path": true, "towers": true}], "Replicated permission APIs lock only the committed setup player")
	await _command("guest", {"action": "ready", "value": true})
	await _wait_shared({"phase": MatchCombat.Phase.WAVE, "wave": 1})
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		var tower_id: int = int(_snapshot(lane)["combat"]["towers"][slot][0]["id"])
		for upgrade: String in ["damage", "speed"]:
			await _command(lane, {"action": "upgrade", "slot": slot, "tower_id": tower_id, "upgrade": upgrade})
	await _command("host", {"action": "advance", "seconds": 1.0})
	await _wait_shared({"phase": MatchCombat.Phase.PLANNING, "wave": 1, "path_editing": false, "ready_seconds_left": -1.0})
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "pacing", "option": "speed", "enabled": true})
	await _command("guest", {"action": "ready", "value": true})
	await _wait_for("host", {"flags": [false, true]}, "Guest Ready is independently admitted")
	await _wait_shared({"ready_seconds_left": 20.0, "speed_multiplier": 2.0})
	await _probe_commit("guest", 1)
	var ordinary_boards: Array = _snapshot("host")["boards"].duplicate(true)
	await _edit("host", 0, 1, 4, false)
	await _command("host", {"action": "clear", "slot": 0})
	await _command("guest", {"action": "forged_ready", "slot": 0})
	await _command("host", {"action": "forged_ready", "slot": 1})
	await _command("guest", {"action": "advance", "seconds": 1000.0})
	await create_timer(0.1).timeout
	_check(_snapshot("host")["boards"] == ordinary_boards and _snapshot("guest")["boards"] == ordinary_boards and _snapshot("host")["flags"] == [false, true] and _snapshot("host")["combat"]["ready_seconds_left"] == 20.0, "Ordinary path locks, forged ownership and guest elapsed time cannot alter host routes/readiness/deadline")
	await _command("host", {"action": "advance", "seconds": 0.03125})
	_check(_snapshot("host")["combat"]["ready_seconds_left"] == 20.0, "Deadline publishes no earlier than the real-time cadence")
	await _command("host", {"action": "advance", "seconds": 0.09375})
	await _wait_shared({"ready_seconds_left": 19.875, "wave": 1})
	await _command("host", {"action": "advance", "seconds": 19.375})
	await _wait_shared({"ready_seconds_left": 0.5, "wave": 1})
	await _command("host", {"action": "advance", "seconds": 0.5})
	await _wait_shared({"phase": MatchCombat.Phase.WAVE, "wave": 2, "ready_seconds_left": -1.0})
	_check(_snapshot("host")["flags"] == [false, true] and _snapshot("guest")["permissions"] == [{"path": false, "towers": true}, {"path": false, "towers": true}], "The host deadline starts both routes without fabricating the other Ready and restores combat management")
	await _command("host", {"action": "advance", "seconds": 1.0})
	await _wait_shared({"phase": MatchCombat.Phase.PLANNING, "wave": 2})
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "pacing", "option": "autoplay", "enabled": true})
	await _wait_shared({"phase": MatchCombat.Phase.WAVE, "wave": 3, "autoplay": true})
	await _command("host", {"action": "advance_to_strategy"})
	await _wait_shared({"phase": MatchCombat.Phase.PLANNING, "wave": 9, "main_round": true, "board_origin_y": 0, "ready_seconds_left": -1.0})
	var original_towers: Array = _snapshot("host")["combat"]["towers"].duplicate(true)
	for upcoming: int in [10, 20, 30]:
		var expansions: int = upcoming / 10 - 1
		await _wait_shared({"phase": MatchCombat.Phase.PLANNING, "wave": upcoming - 1, "main_round": true, "path_editing": true, "board_origin_y": -expansions, "ready_seconds_left": -1.0, "autoplay_votes": [true, true], "speed_votes": [true, true]})
		for lane: String in ["host", "guest"]:
			var snapshot: Dictionary = _snapshot(lane)
			for slot: int in range(2):
				_check(_equal_state(snapshot["board_settings"][slot], {"dimensions": [14 + expansions, 9 + expansions * 2], "budget": 30 + expansions * 6, "entrance": [0, 4 + expansions], "base": [13, 4 + expansions]}), "Both real peers share grown width/height, budget and unchanged endpoint x before round %d" % upcoming)
				var expected_route: Array = []
				for cell: Array in ordinary_boards[slot]["route"]:
					expected_route.append([cell[0], int(cell[1]) + expansions])
				_check(_equal_state(snapshot["boards"][slot]["route"], expected_route) and snapshot["boards"][slot]["legal"], "Grown route retains its exact connected shape on both peers")
				var expected_tower: Dictionary = original_towers[slot][0].duplicate(true)
				expected_tower["cell"] = str(Vector2i(0, expansions))
				expected_tower["aim"] = str(Vector2(0, expansions))
				_check(snapshot["combat"]["towers"][slot][0] == expected_tower, "Growth preserves tower IDs, stats, investment and world-positioned bases/aim on both peers")
		if expansions > 0:
			var outer_x: int = 13 + expansions
			var base_y: int = 4 + expansions
			for lane: String in ["host", "guest"]:
				var slot: int = 0 if lane == "host" else 1
				for x: int in range(14, outer_x + 1):
					await _edit(lane, slot, x, base_y)
			for lane: String in ["host", "guest"]:
				for slot: int in range(2):
					await _wait_board(lane, slot, 12 + expansions, true)
					var snapshot: Dictionary = _snapshot(lane)
					var expected_route: Array = []
					for cell: Array in ordinary_boards[slot]["route"]:
						expected_route.append([cell[0], int(cell[1]) + expansions])
					_check(_equal_state(snapshot["boards"][slot]["route"], expected_route), "Building beyond the fixed base preserves the original shortest route on both real peers")
			for lane: String in ["host", "guest"]:
				var slot: int = 0 if lane == "host" else 1
				for x: int in range(outer_x, 13, -1):
					await _edit(lane, slot, x, base_y, false)
			for lane: String in ["host", "guest"]:
				for slot: int in range(2):
					await _wait_board(lane, slot, 12, true)
		var before_repeat: Dictionary = _snapshot("host").duplicate(true)
		await _command("host", {"action": "repeat_planning"})
		await create_timer(0.1).timeout
		_check(_snapshot("guest")["board_settings"] == before_repeat["board_settings"] and _snapshot("guest")["combat"] == before_repeat["combat"], "Repeated preparation and reliable publishes cannot duplicate growth")
		await _command("host", {"action": "ready", "value": true})
		await _wait_for("guest", {"flags": [true, false]}, "Main-round manual commitment is shared")
		await _command("host", {"action": "advance", "seconds": 1000.0})
		await _wait_shared({"wave": upcoming - 1, "ready_seconds_left": -1.0, "main_round": true})
		await _command("guest", {"action": "ready", "value": true})
		await _wait_shared({"phase": MatchCombat.Phase.WAVE, "wave": upcoming})
		if upcoming < 30:
			await _command("host", {"action": "advance_to_strategy"})
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Leaving expanded peers clears the run")
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"active": true, "flags": [false, false]}, "Rejoining starts fresh setup")
	await _wait_shared({"wave": 0, "setup_round": true, "main_round": false, "board_origin_y": 0, "ready_seconds_left": -1.0, "towers": [[], []], "autoplay_votes": [false, false], "speed_votes": [false, false]})
	for lane: String in ["host", "guest"]:
		_check(_equal_state(_snapshot(lane)["board_settings"], [{"dimensions": [14, 9], "budget": 30, "entrance": [0, 4], "base": [13, 4]}, {"dimensions": [14, 9], "budget": 30, "entrance": [0, 4], "base": [13, 4]}]) and _snapshot(lane)["boards"][0]["used"] == 0 and _snapshot(lane)["boards"][1]["used"] == 0, "Fresh admission restores original host configuration and empty routes on both peers")
	await _finish()


func _probe_commit(lane: String, slot: int) -> void:
	var before: Dictionary = _snapshot("host").duplicate(true)
	var tower_id: int = int(before["combat"]["towers"][slot][0]["id"])
	await _command(lane, {"action": "build", "slot": slot, "x": 1, "y": 0, "type_id": "arrow_tower", "mode": 0})
	await _command(lane, {"action": "target", "slot": slot, "tower_id": tower_id, "mode": 2})
	await _command(lane, {"action": "upgrade", "slot": slot, "tower_id": tower_id, "upgrade": "damage"})
	await _command(lane, {"action": "sell", "slot": slot, "tower_id": tower_id})
	await _command(lane, {"action": "send", "slot": slot, "type_id": "grunt"})
	await _edit(lane, slot, 1, 4, false)
	await _command(lane, {"action": "clear", "slot": slot})
	await _command(lane, {"action": "ready", "value": false})
	await _command(lane, {"action": "ready", "value": true})
	await create_timer(0.1).timeout
	for peer: String in ["host", "guest"]:
		var after: Dictionary = _snapshot(peer)
		_check(after["boards"] == before["boards"] and after["combat"] == before["combat"] and after["flags"] == before["flags"], "Committed %s commands preserve every accepted state field atomically on %s" % [lane, peer])


func _wait_shared(expected: Dictionary) -> void:
	for lane: String in ["host", "guest"]:
		var deadline: int = Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline:
			if _matches(_snapshot(lane).get("combat", {}), expected):
				break
			await create_timer(0.02).timeout
		_check(_matches(_snapshot(lane).get("combat", {}), expected), "Real %s receives shared progression %s; observed %s" % [lane, expected, _snapshot(lane)])


func _snapshot(lane: String) -> Dictionary:
	var result: Dictionary = super._snapshot(lane)
	var path: String = _path(lane, "progression")
	if FileAccess.file_exists(path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if extra is Dictionary:
			result.merge(extra)
	return result


func _equal_state(actual: Variant, expected: Variant) -> bool:
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index: int in range(expected.size()):
			if not _equal_state(actual[index], expected[index]):
				return false
		return true
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key: Variant in expected:
			if not actual.has(key) or not _equal_state(actual[key], expected[key]):
				return false
		return true
	# JSON peers deserialize integers as floats; equality is by numeric value.
	return actual == expected
