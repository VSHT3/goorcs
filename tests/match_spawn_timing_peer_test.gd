extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: real peers accept one bounded host timetable and actual spawn state despite divergent client timing rules"
	planning_worker_path = "res://tests/match_spawn_timing_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_timing_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Timing peers synchronize")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
	await _wait_board("guest", 0, 4, true)
	await _wait_board("host", 1, 4, true)
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Guest receives host timetable")
	var accepted: Dictionary = await _agree("Timetables agree before any manual spawn tick")
	var times: Array = accepted.get("spawn_times", [])
	_check(times.size() == 6 and times[0] == 0.0 and times.back() == 3.75, "Host preserves exact six-enemy delivery window")
	if times.size() != 6:
		await _finish()
		return
	var varied: bool = false
	for index: int in range(1, times.size() - 1):
		varied = varied or not is_equal_approx(float(times[index]), index * 0.75)
		_check(absf(float(times[index]) - index * 0.75) <= 0.3 + 0.000001, "Peer accepted nonzero bounded host timing")
	_check(varied, "Real host timetable is not the client's regular cadence")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client step cannot regenerate schedule") == accepted, "Client cannot independently simulate regular spawns")
	var elapsed: float = 0.0
	for index: int in range(times.size()):
		if index > 0:
			var before: float = float(times[index]) - 0.00001
			await _command("host", {"action": "step", "delta": before - elapsed})
			elapsed = before
			accepted = await _agree_elapsed(elapsed, "Peers agree just before boundary")
			_check(int(accepted["spawned"][0]) == index and int(accepted["spawned"][1]) == index, "Neither peer delivers a regular enemy early")
		var after: float = float(times[index]) + 0.00001
		await _command("host", {"action": "step", "delta": after - elapsed})
		elapsed = after
		accepted = await _agree_elapsed(elapsed, "Actual regular spawn state synchronizes at each boundary")
		_check(accepted["spawn_times"] == times and int(accepted["spawned"][0]) == index + 1 and int(accepted["spawned"][1]) == index + 1, "Shared captured timetable drives both boards' actual spawn counts")
		for slot: int in range(2):
			var enemies: Array = accepted["enemies"][slot]
			_check(enemies.size() == index + 1, "Real accepted stream remains alive for progress checks")
			for enemy_index: int in range(enemies.size()):
				var enemy: Dictionary = enemies[enemy_index]
				_check(is_equal_approx(float(enemy["progress"]), (elapsed - float(times[enemy_index])) * float(enemy["speed"])), "Guest accepts host fractional travel rather than its local speed or schedule")
	await _finish()


func _agree_elapsed(elapsed: float, description: String) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var host: Dictionary = _snapshot("host").get("combat", {})
		var guest: Dictionary = _snapshot("guest").get("combat", {})
		if host == guest and not guest.is_empty() and not guest["enemies"][0].is_empty():
			var first: Dictionary = guest["enemies"][0][0]
			if absf(float(first["progress"]) - elapsed * float(first["speed"])) < 0.00000001:
				return guest
		await create_timer(0.02).timeout
	_check(false, description)
	return _snapshot("guest").get("combat", {})
