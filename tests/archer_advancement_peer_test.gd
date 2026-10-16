extends "res://tests/match_branch_test.gd"
func _run() -> void:
	success_message = "PASS: real host/client pay captured archer path prices, reject cross-owner/switch commands, replicate four targets, burns and bomb damage"
	planning_worker_path = "res://tests/archer_advancement_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec()+90000
	_directory = OS.get_temp_dir().path_join("gorcs_archer_peer_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port==0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host",{"action":"host","port":port})
	await _connect_guest("guest","host",hosted["code"])
	await _paths()
	var commands: Array[String] = ["four_archers","fire_arrows","bomb_arrows"]
	for lane: String in ["host","guest"]:
		var slot: int = 0 if lane=="host" else 1
		var observer: String = "guest" if slot==0 else "host"
		for index: int in range(3):
			await _build(lane,slot,index*2,3,0)
			var tower: Dictionary = await _wait_tower(observer,slot,Vector2i(index*2,3),0)
			for upgrade: String in ["damage","speed","special",commands[index]]:
				await _command(lane,{"action":"upgrade","slot":slot,"tower_id":tower["id"],"upgrade":upgrade})
	await _wait_combat("guest",{"coins":[7040,7040]},"Both lanes pay host-defined prices rather than guest one-Coin overrides")
	var accepted: Dictionary = await _agree("Paid archer advancements agree")
	for slot: int in range(2):
		for index: int in range(3):
			_check(accepted["towers"][slot][index]["advancement"]==commands[index],"Real remote purchases retain branch identity")
	var tower_id: int = int(accepted["towers"][0][0]["id"])
	await _command("guest",{"action":"upgrade","slot":0,"tower_id":tower_id,"upgrade":"fire_arrows"})
	await _command("host",{"action":"upgrade","slot":0,"tower_id":tower_id,"upgrade":"bomb_arrows"})
	_check(await _agree("Rejected path mutations agree")==accepted,"Cross-owner and exclusive-branch switches cannot spend or mutate")
	await _command("host",{"action":"target_archer_3","slot":0,"tower_id":tower_id,"mode":2})
	await _command("host",{"action":"target_archer_4","slot":0,"tower_id":tower_id,"mode":1})
	await _both_ready()
	await _wait_combat("guest",{"phase":1,"wave":1},"New archer peer wave accepted")
	await _command("host",{"action":"step","delta":0.01})
	accepted = await _agree("First full archer volleys reach client")
	var four: Dictionary = accepted["towers"][0][0]
	var distinct: Dictionary = {}
	for id: int in [int(four["target_id"]),int(four["secondary_target_id"]),int(four["extra_archers"][0]["target_id"]),int(four["extra_archers"][1]["target_id"])]: distinct[id]=true
	_check(distinct.size()==4 and not distinct.has(-1) and _matches(four["extra_archers"][0],{"mode":2}) and _matches(four["extra_archers"][1],{"mode":1}),"Both peers receive four accepted distinct shots and independent selectors")
	_check(accepted["enemies"][0].any(func(enemy:Dictionary)->bool:return enemy["burning"]) and accepted["enemies"][0].any(func(enemy:Dictionary)->bool:return enemy["hp"]<390),"Host volleys publish ignition and increased circular bomb damage")
	await _command("guest",{"action":"step","delta":10.0})
	_check(await _agree("Client cannot advance burns")==accepted,"Guest cannot independently tick fire or choose targets")
	await _finish()
