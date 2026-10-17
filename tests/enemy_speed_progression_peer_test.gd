extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: separate host/client agree on diminishing speed milestones, typed previews, paid/regular movement and host rules despite divergent client configuration"
	planning_worker_path = "res://tests/enemy_speed_progression_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec()+90000
	_directory = OS.get_temp_dir().path_join("gorcs_speed_peer_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host",{"action":"host","port":port})
	await _connect_guest("guest","host",hosted["code"])
	await _paths()
	for entry: Array in [[6,2.2],[16,2.4],[31,2.6],[51,2.8]]:
		var number: int = entry[0]
		var speed: float = entry[1]
		await _command("host",{"action":"debug","round":number,"money":1000,"shards":_snapshot("host")["combat"]["reroll_currency"][0]})
		await _wait_combat("guest",{"wave":number-1,"phase":0},"Guest receives selected milestone planning")
		var preview: Dictionary = await _agree("Host-owned milestone preview agrees")
		_check(is_equal_approx(float(preview["enemy_types"]["grunt"]["speed"]),speed),"Remote planning preview ignores the guest's faster local curve")
		await _command("host",{"action":"send","slot":0,"type_id":"grunt"})
		await _wait_combat("guest",{"queued_sends":[0,1]},"Paid movement fixture is reserved before readiness")
		await _both_ready()
		await _wait_combat("guest",{"wave":number,"phase":1},"Both peers admit the selected speed round")
		await _command("host",{"action":"step","delta":0.1})
		await _wait_combat("guest",{"spawned":[1,1]},"Real regular and paid births reach the client")
		var accepted: Dictionary = await _agree("Actual diminishing movement agrees")
		for slot: int in range(2):
			for enemy: Dictionary in accepted["enemies"][slot]:
				_check(is_equal_approx(float(enemy["base_speed"]),speed) and is_equal_approx(float(enemy["progress"]),speed*0.1),"Both real peers observe the same host movement for all regular and sent instances")
	await _finish()
