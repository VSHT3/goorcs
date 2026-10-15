extends "res://tests/match_multiplayer_test.gd"


func _run() -> void:
	success_message = "PASS: separate host/client processes agree on assigned shortest branches, sends, movement, wave leaks and cursor resets"
	planning_worker_path = "res://tests/match_branch_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_branch_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Branch peers synchronize")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		await _edit(lane, slot, 1, 2)
		for y: int in [1, 3]:
			for x: int in range(1, 6):
				await _edit(lane, slot, x, y)
	await _wait_board("guest", 0, 11, true)
	await _wait_board("host", 1, 11, true)
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _wait_combat("host", {"queued_sends": [1, 0]}, "Remote queued send accepted by host")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Peer receives captured wave")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _wait_combat("host", {"income": [0, 4], "queued_sends": [1, 0]}, "Remote send reserves the next current-combat delivery")
	await _command("host", {"action": "step", "delta": 2.5})
	var accepted: Dictionary = await _agree("Moving branches and host-supplied speed agree")
	var board_zero: Array = accepted["enemies"][0]
	var board_one: Array = accepted["enemies"][1]
	_check(board_zero.size() == 6 and board_one.size() == 4 and _matches(accepted, {"queued_sends": [0, 0]}), "Paced sends and unchanged regular streams all survive on accepted paths")
	for slot: int in range(2):
		var enemies: Array = accepted["enemies"][slot]
		for index: int in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			var y: int = 3 if index % 2 == 0 else 1
			_check(enemy["route"].size() == 8 and enemy["route"][2] == str(Vector2i(1, y)), "Peer publishes full alternating equal-length instance route")
			var progress: float = float(enemy["progress"])
			var expected_progress: float = 2.5 - (float(accepted["rules"]["send_spawn_interval"]) if slot == 0 and index == 5 else 0.0)
			_check(is_equal_approx(progress, expected_progress) and enemy["pos"] == str(Vector2(progress - 1.0, y)), "Host movement follows each assigned branch from its actual delivery time")
	await _command("guest", {"action": "step", "delta": 100.0})
	var after_client_step: Dictionary = await _agree("Client cannot independently move or reroll accepted routes")
	_check(after_client_step == accepted, "Client step cannot affect authoritative wave, routes or positions")
	await _command("host", {"action": "step", "delta": 5.0})
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [94, 96]}, "Both peer boards leak on their own equal-length paths")
	await _agree("Wave-clear state agrees")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 2}, "Next wave synchronizes")
	await _command("host", {"action": "step", "delta": 2.5})
	accepted = await _agree("Second-wave branch assignments agree")
	for slot: int in range(2):
		var enemies: Array = accepted["enemies"][slot]
		_check(enemies.size() == 4 and enemies[0]["route"][2] == str(Vector2i(1, 3)), "New wave resets each board's first fork choice")
	await _command("host", {"action": "step", "delta": 5.0})
	await _wait_combat("guest", {"phase": 0, "wave": 2, "health": [90, 92]}, "Second wave completes with matching persistent health")
	await _agree("Both waves finish identically on real peers")
	await _finish()


func _agree(description: String) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var host: Dictionary = _snapshot("host").get("combat", {})
		var guest: Dictionary = _snapshot("guest").get("combat", {})
		if not host.is_empty() and host == guest:
			return host
		await create_timer(0.02).timeout
	_check(false, description)
	return _snapshot("host").get("combat", {})
