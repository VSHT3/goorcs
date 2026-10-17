extends "res://tests/match_branch_test.gd"
func _run() -> void:
	success_message = "PASS: real divergent peers accept host-priced complete archer chains, eight policies, minigun streams and fire-only continuous state"
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
	await _wait_combat("guest",{"coins":[47040,47040]},"Both lanes pay host-defined prices rather than guest one-Coin overrides")
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
	for slot: int in range(2):
		var lane: String="host" if slot==0 else "guest"
		var board: Array=accepted["towers"][slot]
		await _command(lane,{"action":"upgrade","slot":slot,"tower_id":board[0]["id"],"upgrade":"eight_archers"})
		for upgrade: String in ["molotov","quick_pitch","flamethrower"]:
			await _command(lane,{"action":"upgrade","slot":slot,"tower_id":board[1]["id"],"upgrade":upgrade})
		for upgrade: String in ["bigger_bombs","anti_orc_grenades","aom","aom_speed_1","aom_speed_2"]:
			await _command(lane,{"action":"upgrade","slot":slot,"tower_id":board[2]["id"],"upgrade":upgrade})
		await _build(lane,slot,6,3,0)
		var gun: Dictionary=await _wait_tower("guest" if slot==0 else "host",slot,Vector2i(6,3),0)
		for upgrade: String in ["damage","speed","special","four_archers","eight_archers","arrow_minigun"]:
			await _command(lane,{"action":"upgrade","slot":slot,"tower_id":gun["id"],"upgrade":upgrade})
		for action: String in ["target_archer_5","target_archer_6","target_archer_7","target_archer_8"]:
			await _command(lane,{"action":action,"slot":slot,"tower_id":board[0]["id"],"mode":MatchCombat.TargetMode.STRONGEST})
			await _command(lane,{"action":action,"slot":slot,"tower_id":board[0]["id"],"mode":MatchCombat.TargetMode.LAST})
	await _wait_combat("guest",{"coins":[35120,35120]},"Complete capstone paths debit host prices on both real senders")
	accepted=await _agree("Full archer chains and eight policies agree")
	for slot: int in range(2):
		var board: Array=accepted["towers"][slot]
		_check(board[0]["extra_archers"].size()==6 and board[0]["advancement_path"]==["four_archers","eight_archers"],"Eight-archer history and six extra stream policies replicate")
		for extra: Dictionary in board[0]["extra_archers"]: _check(extra["mode"]==MatchCombat.TargetMode.LAST,"All eight independent accepted modes replicate")
		_check(board[1]["advancement_path"]==["fire_arrows","molotov","quick_pitch","flamethrower"] and board[2]["advancement_path"]==["bomb_arrows","bigger_bombs","anti_orc_grenades","aom","aom_speed_1","aom_speed_2"] and board[3]["advancement_path"]==["four_archers","eight_archers","arrow_minigun"],"Accepted real peers retain every exact prerequisite purchase")
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
	for slot: int in range(2):
		var flame: Dictionary=accepted["towers"][slot][1]
		var rocket: Dictionary=accepted["towers"][slot][2]
		var gun: Dictionary=accepted["towers"][slot][3]
		_check(flame["firing"] and is_equal_approx(float(flame["continuous_fire_time"]),0.01) and flame["shot"]==0 and flame["secondary_shot"]==0,"Continuous fire state reaches divergent clients without local discrete arrows")
		_check(rocket["shot"]==1 and rocket["secondary_shot"]==0 and gun["shot"]==1 and gun["secondary_shot"]==0,"One-operator weapons publish only primary host shots")
	await _command("host",{"action":"step","delta":0.1})
	accepted=await _agree("Fast minigun stream is host-owned")
	for slot: int in range(2):
		_check(accepted["towers"][slot][3]["shot"]>=5,"Real accepted minigun emits multiple subinterval shots inside a large host tick")
	var frozen: Dictionary=accepted.duplicate(true)
	await _command("guest",{"action":"step","delta":60.0})
	_check(await _agree("Client cannot consume flame fuel")==frozen,"Divergent local config cannot integrate fuel, burn, targeting or minigun shots")
	await _finish()
