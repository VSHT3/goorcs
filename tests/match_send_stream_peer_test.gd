extends "res://tests/match_multiplayer_test.gd"


func _run() -> void:
	success_message = "PASS: real peers share independent FIFO send clocks, concurrent portal delivery, late combat sends, pending-only clearance gaps, income and reset"
	planning_worker_path = "res://tests/match_multiplayer_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_send_stream_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = hosted["code"]
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "stream_scenario"})
	await _connect_guest("guest", "host", code)
	await _wait_combat("guest", {"phase": 0, "coins": [400, 400], "health": [20, 20]}, "Host stream fixture is admitted")
	for type_id: String in ["runner", "brute", "grunt", "runner", "brute"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
	await _wait_combat("guest", {"coins": [250, 400], "income": [14, 0], "send_queues": [[], ["runner", "brute", "grunt", "runner", "brute"]]}, "Paid mixed FIFO is owned by the destination board")
	await _paths()
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Both initial manual Ready votes admit the frozen stream")
	var state: Dictionary = await _send_agreement("Initial FIFO head")
	_check(state["rules"]["send_spawn_interval"] == 1.0 and _matches(state, {"spawn_times": [0.0, 1.0], "spawned": [0, 0], "queued_sends": [0, 4]}), "Host captures independent send cadence without rewriting the ordinary timetable")
	_check(_stream_types(state, 1) == ["runner"] and float(state["enemies"][1][0]["progress"]) == 0.0, "Planning sends deliver only the first head at combat time zero")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _send_agreement("Client cannot tick stream") == state, "A client step cannot independently deliver or move either stream")
	await _send_step(0.25)
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _wait_combat("host", {"coins": [250, 380], "income": [14, 2]}, "Guest starts its independent destination stream")
	state = await _send_agreement("Offset stream delivery")
	_check(_matches(state, {"queued_sends": [0, 4]}) and _stream_types(state, 0) == ["grunt", "grunt"] and float(state["enemies"][0][1]["progress"]) == 0.0, "Idle stream delivers at acceptance time rather than backdating to the other board's clock")
	await _send_step(0.65)
	state = await _send_agreement("First pending-only gap")
	_check(_matches(state, {"phase": MatchCombat.Phase.WAVE, "enemies": [[], []], "spawned": [1, 1], "queued_sends": [0, 4], "coins": [250, 380]}), "No living enemies during a portal gap neither clears the round nor pays income")
	await _send_step(0.2)
	state = await _send_agreement("Simultaneous ordinary and sent delivery")
	_check(_matches(state, {"spawned": [2, 2], "total": 2, "queued_sends": [0, 3]}) and _stream_types(state, 1) == ["grunt", "brute"], "Ordinary timetable and FIFO send stream both deliver at simulation second one")
	_check(is_equal_approx(float(state["enemies"][1][0]["progress"]), 2.6) and is_equal_approx(float(state["enemies"][1][1]["progress"]), 1.69), "Real client accepts fractional progress computed from each simultaneous enemy's actual speed")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "brute"})
	await _wait_combat("host", {"coins": [250, 340], "income": [14, 6], "send_queues": [["brute"], ["grunt", "runner", "brute"]]}, "Offset stream reserves its own cooldown atomically")
	await _send_step(0.149)
	state = await _send_agreement("Before offset stream due")
	_check(_matches(state, {"queued_sends": [1, 3]}), "Other board's second-one delivery cannot release the offset stream early")
	await _send_step(0.002)
	state = await _send_agreement("Offset stream due")
	_check(_matches(state, {"queued_sends": [0, 3]}) and _stream_types(state, 0) == ["grunt", "brute"], "The guest's order releases at its own second-1.25 deadline, not the opponent's clock")
	await _send_step(1.849)
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _command("host", {"action": "send", "slot": 0, "type_id": "runner"})
	await _wait_combat("guest", {"coins": [225, 320], "income": [16, 8], "send_queues": [[], ["brute", "runner"]]}, "After second three sends still target the current combat and preserve existing FIFO tails")
	state = await _send_agreement("Late host and guest sends")
	_check(_stream_types(state, 0) == ["grunt"] and float(state["enemies"][0][0]["progress"]) == 0.0 and _stream_types(state, 1) == ["runner"], "Idle late guest send delivers once now while host send waits behind the existing paid Brute")
	await _send_step(1.8)
	state = await _send_agreement("Final pending-only gap")
	_check(_matches(state, {"phase": MatchCombat.Phase.WAVE, "spawned": [2, 2], "enemies": [[], []], "send_queues": [[], ["runner"]], "coins": [225, 320]}), "Fully exhausted ordinary roster cannot clear across a pending-send-only gap or pay early income")
	await _send_step(0.11)
	state = await _send_agreement("Late queued delivery")
	_check(_matches(state, {"phase": MatchCombat.Phase.WAVE, "wave": 1, "queued_sends": [0, 0]}) and _stream_types(state, 1) == ["runner"], "The late FIFO tail arrives in round one rather than a replacement next-wave queue")
	_check(is_equal_approx(float(state["enemies"][1][0]["progress"]), 0.442), "Late delivery starts at its true second-five due time without idle catch-up travel")
	await _send_step(0.4)
	await _wait_combat("guest", {"phase": 0, "wave": 1, "health": [13, 8], "coins": [276, 363], "income": [16, 8], "send_queues": [[], []]}, "All ordinary and sent leaks clear once with exact target damage and recurring income")
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Disconnect clears stream clocks")
	await _connect_guest("guest", "host", code)
	await _wait_combat("guest", {"phase": 0, "wave": 0, "health": [20, 20], "coins": [400, 400], "income": [0, 0], "enemies": [[], []], "send_queues": [[], []]}, "Admission resets every delivery, balance and income")
	for type_id: String in ["grunt", "runner"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
	await _paths()
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Fresh manual Ready admits the reset stream")
	state = await _send_agreement("Reset stream starts at zero")
	_check(_stream_types(state, 1) == ["grunt"] and state["send_queues"] == [[], ["runner"]], "Reset clocks deliver exactly one new FIFO head at zero without inheriting the prior combat deadline")
	await _finish()


func _stream_types(combat: Dictionary, slot: int) -> Array[String]:
	var identities: Array[String] = []
	for enemy: Dictionary in combat["enemies"][slot]:
		identities.append(String(enemy["type_id"]))
	return identities
