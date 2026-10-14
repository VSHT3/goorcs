extends "res://tests/multiplayer_session_test.gd"

var planning_worker_path: String = "res://tests/match_planning_worker.gd"


func _run() -> void:
	success_message = "PASS: two-peer distinct paths, ownership/bounds/endpoints/budget, readiness invalidation/withdrawal, route capture/lock, disconnect and fresh rejoin"
	_suite_deadline_msec = Time.get_ticks_msec() + 60000
	_directory = OS.get_temp_dir().path_join("goorcs_planning_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var host: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = host["code"]
	await _connect_guest("guest", "host", code)
	await _wait_for("host", {"active": true}, "Host enters planning")
	await _wait_for("guest", {"active": true}, "Guest receives host planning")
	await _command("guest", {"action": "ready", "value": true})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["flags"] == [false, false], "Disconnected route cannot become ready")
	for x: int in range(1, 13):
		await _edit("host", 0, x, 4)
	# Guest takes a distinct 15-step route instead of the host's 13-step route.
	await _edit("guest", 1, 0, 3)
	for x: int in range(1, 14):
		await _edit("guest", 1, x, 3)
	await _wait_board("guest", 0, 12, true)
	await _wait_board("host", 1, 14, true)
	await _wait_board("guest", 1, 14, true)
	_check(_snapshot("host")["boards"] == _snapshot("guest")["boards"], "Different mazes and shortest routes agree on both peers")
	var before: Array = _snapshot("host")["boards"]
	await _edit("guest", 0, 2, 2)
	await _edit("host", 1, 2, 2)
	await _edit("guest", 1, -1, 3)
	await _edit("host", 0, 0, 4, false)
	await create_timer(0.15).timeout
	_check(_snapshot("host")["boards"] == before and _snapshot("guest")["boards"] == before, "Ownership, bounds, and endpoint rejection preserve both boards")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Host readiness replicated")
	await _edit("host", 0, 1, 3)
	await _wait_for("guest", {"flags": [false, false]}, "Accepted edit clears readiness")
	await _edit("host", 0, 1, 3, false)
	await _command("guest", {"action": "ready", "value": true})
	await _wait_for("host", {"flags": [false, true]}, "Guest readiness replicated")
	await _command("guest", {"action": "ready", "value": false})
	await _wait_for("host", {"flags": [false, false]}, "Guest can withdraw readiness")
	await _command("guest", {"action": "ready", "value": true})
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("host", {"locked": true}, "Both legal ready routes lock atomically")
	await _wait_for("guest", {"locked": true}, "Guest observes route lock")
	var locked: Dictionary = _snapshot("host")
	_check(locked["routes"][0] == locked["boards"][0]["route"] and locked["routes"][1] == locked["boards"][1]["route"], "Captured routes equal the accepted shortest routes")
	_check(locked["routes"] == _snapshot("guest")["routes"], "Both peers capture identical routes")
	await _command("guest", {"action": "clear", "slot": 1})
	await _edit("host", 0, 1, 4, false)
	await _command("host", {"action": "ready", "value": false})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["boards"] == locked["boards"] and _snapshot("guest")["routes"] == locked["routes"] and _snapshot("host")["locked"], "Clear, edit and unready cannot alter frozen routes")
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false, "locked": false}, "Disconnect cancels planning lock")
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"active": true, "locked": false, "flags": [false, false]}, "Rejoin begins fresh planning")
	await _wait_board("host", 0, 0, false)
	await _wait_board("guest", 1, 0, false)
	# Fill the host budget with disconnected cells: host rejects the 31st tile.
	var placed: int = 0
	for y: int in range(3):
		for x: int in range(14):
			if placed < 31:
				await _edit("host", 0, x, y)
				placed += 1
	await _wait_board("guest", 0, 30, false)
	await _command("host", {"action": "clear", "slot": 0})
	await _wait_board("guest", 0, 0, false)
	await _finish()


func _start_workers() -> bool:
	for lane: String in ["host", "guest"]:
		_command_ids[lane] = 0
		var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", _directory.path_join(lane + ".log"), "--script", planning_worker_path, "--", _directory, lane])
		var pid: int = OS.create_process(OS.get_executable_path(), arguments)
		_check(pid > 0, "Start real planning peer: " + lane)
		if pid <= 0:
			return false
		_processes[lane] = pid
	for lane: String in ["host", "guest"]:
		await _wait_for(lane, {"state": "IDLE"}, "Planning worker starts")
	return failures == 0


func _snapshot(lane: String) -> Dictionary:
	var result: Dictionary = super._snapshot(lane)
	var path: String = _path(lane, "planning")
	if FileAccess.file_exists(path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if extra is Dictionary:
			result.merge(extra)
	return result


func _edit(lane: String, slot: int, x: int, y: int, place: bool = true) -> void:
	await _command(lane, {"action": "edit", "slot": slot, "x": x, "y": y, "place": place})


func _wait_board(lane: String, slot: int, used: int, legal: bool) -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var boards: Array = _snapshot(lane).get("boards", [])
		if boards.size() == 2 and boards[slot]["used"] == used and boards[slot]["legal"] == legal:
			return
		await create_timer(0.02).timeout
	_check(false, "Board %d on %s reaches used=%d legal=%s; observed %s" % [slot, lane, used, legal, _snapshot(lane)])
