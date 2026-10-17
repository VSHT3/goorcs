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
	var target_commands: Array[String] = ["target_archer_3","target_archer_4","target_secondary","target"]
	for slot: int in range(2):
		var lane: String = "host" if slot==0 else "guest"
		var observer: String = "guest" if slot==0 else "host"
		var id: int = int(accepted["towers"][slot][0]["id"])
		for action: String in target_commands:
			await _command(lane,{"action":action,"slot":slot,"tower_id":id,"mode":MatchCombat.TargetMode.LAST})
		var changed: Dictionary = await _wait_tower(observer,slot,Vector2i(0,3),MatchCombat.TargetMode.LAST)
		_check(changed["secondary_mode"]==MatchCombat.TargetMode.LAST and changed["extra_archers"][0]["mode"]==MatchCombat.TargetMode.LAST and changed["extra_archers"][1]["mode"]==MatchCombat.TargetMode.LAST,"Both real senders independently submit accepted Last modes for all four archers")
	accepted = await _agree("Accepted Last policies agree")
	for slot: int in range(2):
		var owner: String = "host" if slot==0 else "guest"
		var other: String = "guest" if slot==0 else "host"
		var id: int = int(accepted["towers"][slot][0]["id"])
		for action: String in target_commands:
			await _command(other,{"action":action,"slot":slot,"tower_id":id,"mode":MatchCombat.TargetMode.CLOSEST})
			await _command(owner,{"action":action,"slot":slot,"tower_id":id,"mode":MatchCombat.TargetMode.LAST+1})
	await create_timer(0.15).timeout
	_check(await _agree("Rejected policy mutations agree")==accepted,"Wrong-owner and out-of-bounds primary, secondary and extra archer requests cannot change accepted Last policies")
	await _command("host",{"action":"ready","value":true})
	await _wait_for("guest",{"flags":[true,false]},"Last-equipped host commits initial planning")
	accepted = await _agree("Committed Last policies agree")
	for action: String in target_commands:
		await _command("host",{"action":action,"slot":0,"tower_id":tower_id,"mode":MatchCombat.TargetMode.CLOSEST})
	await _build("host",0,6,3,MatchCombat.TargetMode.LAST)
	await create_timer(0.15).timeout
	_check(await _agree("Committed targeting rejection agrees")==accepted,"Committed Ready rejects otherwise-valid Last tower purchases and changes to every independent archer policy")
	await _command("guest",{"action":"ready","value":true})
	await _wait_combat("guest",{"phase":1,"wave":1},"New archer peer wave accepted")
	await _command("host",{"action":"step","delta":0.01})
	accepted = await _agree("First full archer volleys reach client")
	var four: Dictionary = accepted["towers"][0][0]
	var distinct: Dictionary = {}
	for id: int in [int(four["target_id"]),int(four["secondary_target_id"]),int(four["extra_archers"][0]["target_id"]),int(four["extra_archers"][1]["target_id"])]: distinct[id]=true
	_check(distinct.size()==4 and not distinct.has(-1) and four["mode"]==MatchCombat.TargetMode.LAST and four["secondary_mode"]==MatchCombat.TargetMode.LAST and _matches(four["extra_archers"][0],{"mode":MatchCombat.TargetMode.LAST}) and _matches(four["extra_archers"][1],{"mode":MatchCombat.TargetMode.LAST}),"Both peers receive four accepted distinct Last shots and independent policies")
	_check(accepted["enemies"][0].any(func(enemy:Dictionary)->bool:return enemy["burning"]) and accepted["enemies"][0].any(func(enemy:Dictionary)->bool:return enemy["hp"]<390),"Host volleys publish ignition and increased circular bomb damage")
	await _command("guest",{"action":"step","delta":10.0})
	_check(await _agree("Client cannot advance burns")==accepted,"Guest cannot independently tick fire or choose targets")
	await _finish()
