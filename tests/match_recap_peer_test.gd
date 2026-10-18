extends "res://tests/match_branch_test.gd"

func _run() -> void:
	success_message = "PASS: separate peers agree on terminal recap, payer-owned purchases/upgrades/orders, retained sold tower, capped fatal leak and terminal command rejection"
	planning_worker_path = "res://tests/match_recap_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_recap_peer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Recap peers admit their real private loadouts")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5): await _edit(lane, slot, x, 2)
		await _command(lane, {"action": "build", "slot": slot, "x": 1, "y": 0, "type_id": "arrow_tower", "mode": 0})
	var built: Dictionary = await _agree("Real purchases synchronize")
	var id: int = int(built["towers"][0][0]["id"])
	await _command("host", {"action": "upgrade", "slot": 0, "tower_id": id, "upgrade": "damage"})
	await _command("host", {"action": "sell", "slot": 0, "tower_id": id})
	await _command("guest", {"action": "send", "slot": 1, "type_id": "grunt"})
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 1}, "Both peers open their captured routes")
	await _command("host", {"action": "step", "delta": 0.001})
	var live: Dictionary = await _agree("Live host state agrees")
	_check(live["recap"].is_empty(), "The live wire state does not publish a terminal tower history")
	await _command("guest", {"action": "finish_recap"})
	_check(await _agree("Client cannot terminate the authoritative run") == live, "A client cannot choose a terminal outcome or report")
	await _command("host", {"action": "finish_recap"})
	await _wait_combat("guest", {"phase": 2}, "Host fatal leak ends both peers")
	var final: Dictionary = await _agree("Both complete final reports agree byte-for-byte after transport normalization")
	var host: Dictionary = final["recap"]["sides"][0]
	var guest: Dictionary = final["recap"]["sides"][1]
	_check(host["towers"].size() == 1 and host["towers"][0]["sold"] and final["towers"][0].is_empty(), "Sold tower is retained only as report history, not an active board entity")
	_check(int(host["spent"]["towers"]) == int(built["tower_types"]["arrow_tower"]["cost"]) and int(guest["spent"]["towers"]) == int(host["spent"]["towers"]), "Both payer-owned tower transactions are accounted independently")
	_check(int(host["spent"]["upgrades"]) > 0 and int(guest["spent"]["upgrades"]) == 0 and int(host["earned"]["sale_coins"]) > 0 and int(guest["earned"]["sale_coins"]) == 0, "Upgrade cost and refund stay with their actual owner")
	_check(int(guest["spent"]["sends"]) == int(final["enemy_types"]["grunt"]["send_cost"]) and int(host["spent"]["sends"]) == 0, "A remote accepted order is charged only to its payer in the report")
	_check(int(host["leaks"]["grunt"]) == 1 and int(host["base_damage"]["grunt"]) == 1 and host["defeated_by"] == "grunt", "The final real leak records capped HP removal and fatal enemy type")
	await _command("guest", {"action": "sell", "slot": 1, "tower_id": final["towers"][1][0]["id"]})
	await _command("host", {"action": "step", "delta": 10.0})
	_check(await _agree("Terminal state remains frozen on both processes") == final, "Late client mutations and host ticks cannot alter the recap")
	await _finish()
