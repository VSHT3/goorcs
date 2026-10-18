extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: separate normal-match host/client processes agree on late boss debuts, physical/nonphysical damage, club/cannon stuns, charged direct jumps, doors, rewards and resets despite divergent client resources"
	planning_worker_path = "res://tests/late_boss_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_late_boss_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Late boss peers commit their real loadouts")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(14):
			await _edit(lane, slot, x, 0)
		for x: int in [0, 13]:
			await _edit(lane, slot, x, 1)
		await _build(lane, slot, 1, 3, MatchCombat.TargetMode.STRONGEST)
		await _build(lane, slot, 3, 2, MatchCombat.TargetMode.STRONGEST)
	await _wait_board("guest", 0, 16, true)
	await _wait_board("host", 1, 16, true)
	await _command("host", {"action": "round_fixture", "round": 60})
	await _wait_combat("guest", {"wave": 59, "phase": 0}, "Host selects real Troll debut")
	var planning_state: Dictionary = await _agree("Troll preview and normal consumer agree")
	_check(not bool(planning_state["rules"]["sandbox_mode"]), "Peer regression uses normal MatchPlanning admission, not a fake sandbox transport")
	await _reject_boss_sends(planning_state)
	await _both_ready()
	await _wait_combat("guest", {"wave": 60, "phase": 1}, "Normal readiness starts Troll round")
	await _command("host", {"action": "step", "delta": 0.001})
	var accepted: Dictionary = await _agree("Actual Troll enemies replicate")
	for slot: int in range(2):
		_check(_of_type(accepted, "troll", slot).size() == 1 and _of_type(accepted, "orc_war_machine", slot).is_empty(), "Both boards receive exactly one Troll and no early machine")
		var troll: Dictionary = _first(accepted, "troll", slot)
		_check(int(troll["max_hp"]) > 100000 and float(troll["base_speed"]) < 0.01, "Host HP and slow speed override client's tiny fast Troll")
	var hp: int = int(_first(accepted, "troll")["hp"])
	await _command("host", {"action": "typed_damage_fixture", "kind": "physical"})
	accepted = await _agree("Physical damage is host-owned")
	_check(hp - int(_first(accepted, "troll")["hp"]) == 20, "Real peers apply physical damage without Troll multiplier")
	hp = int(_first(accepted, "troll")["hp"])
	await _command("host", {"action": "typed_damage_fixture", "kind": "magic"})
	accepted = await _agree("Nonphysical damage is host-owned")
	_check(hp - int(_first(accepted, "troll")["hp"]) == 30, "Real peers apply 1.5 nonphysical damage, not client's ninefold local rule")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot simulate Troll") == accepted, "Divergent client ability clocks cannot move, stomp, damage or stun independently")
	await _command("host", {"action": "step", "delta": 24.999})
	accepted = await _agree("Host club windup replicates")
	for slot: int in range(2):
		var troll: Dictionary = _first(accepted, "troll", slot)
		_check(float(troll["tower_attack_remaining"]) > 1.24 and int(troll["tower_attack_target_id"]) == int(accepted["towers"][slot][0]["id"]), "Accepted nearest-tower club windup wins over client instant casts")
	await _command("host", {"action": "step", "delta": 1.25})
	accepted = await _agree("Thirty-second club stun replicates")
	for slot: int in range(2):
		_check(int(accepted["towers"][slot][0]["stun_count"]) == 1 and is_equal_approx(float(accepted["towers"][slot][0]["stunned_remaining"]), 30.0), "Both real peers share the host's thirty-second stun")
	await _reject_boss_sends(accepted)
	var coins: Array = accepted["coins"].duplicate()
	var kills: Array[int] = []
	for slot: int in range(2):
		kills.append(int(accepted["towers"][slot][0]["kills"]))
	await _command("host", {"action": "retire_boss_fixture", "type_id": "troll"})
	accepted = await _agree("Authoritative Troll kill and reward replicate")
	for slot: int in range(2):
		_check(_of_type(accepted, "troll", slot).is_empty() and int(accepted["enemy_totals"][slot]["kills"].get("troll", 0)) == 1 and int(accepted["coins"][slot]) > int(coins[slot]) and int(accepted["towers"][slot][0]["kills"]) == kills[slot] + 1, "Real boss retirement removes target and credits exactly one host bounty/kill")
	await _command("host", {"action": "round_fixture", "round": 100})
	await _wait_combat("guest", {"wave": 99, "phase": 0}, "Host switches to machine debut")
	accepted = await _agree("Round reset clears accepted boss actions")
	for slot: int in range(2):
		_check(accepted["enemies"][slot].is_empty() and float(accepted["towers"][slot][0]["stunned_remaining"]) == 0.0, "Normal round reset clears enemies and stuns on both processes")
	await _both_ready()
	await _wait_combat("guest", {"wave": 100, "phase": 1}, "Normal readiness starts machine debut")
	await _command("host", {"action": "step", "delta": 0.001})
	accepted = await _agree("Actual machine enemies replicate")
	for slot: int in range(2):
		_check(_of_type(accepted, "orc_war_machine", slot).size() == 1, "Both normal boards receive guaranteed machine")
		var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
		_check(machine["route"].size() == 2 and int(machine["max_hp"]) > 1000000, "Accepted machine keeps a direct route and host HP rather than the client's painted route or tiny health")
	var saw_charge: bool = false
	var saw_jump: bool = false
	var saw_grass: bool = false
	for tick: int in range(60):
		await _command("host", {"action": "step", "delta": 0.25})
		accepted = await _agree("Host machine action boundary replicates")
		var machine: Dictionary = _first(accepted, "orc_war_machine")
		saw_charge = saw_charge or machine["locomotion"] == "jump_charge"
		saw_jump = saw_jump or machine["locomotion"] == "jump"
		saw_grass = saw_grass or machine["locomotion"] == "legs"
		if int(machine["summon_count"]) > 0 and int(accepted["towers"][0][1]["stun_count"]) > 0 and saw_jump:
			break
	_check(saw_charge and saw_jump, "Separate processes observe real charged jump rather than direct movement through blocking tower")
	_check(saw_grass, "Actual off-road travel deploys legs on both accepted peer views")
	var machine_state: Dictionary = _first(accepted, "orc_war_machine")
	_check(int(machine_state["summon_count"]) > 0 and int(machine_state["tower_attack_count"]) > 0, "Host machine actually completes troop doors and cannon lifecycle")
	var cannon_stuns: int = 0
	for slot: int in range(2):
		var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
		var children: int = 0
		for enemy: Dictionary in accepted["enemies"][slot]:
			if int(enemy["summoner_id"]) == int(machine["id"]):
				children += 1
				_check(enemy["type_id"] in ["orcling", "grunt", "runner"] and enemy["route"].size() > 2, "Replicated door troop uses actual ordinary painted remaining route, not direct machine line")
		_check(children >= 2 and children <= 12, "Accepted host doors create bounded real troops despite client's fast inverted pool")
		for tower: Dictionary in accepted["towers"][slot]:
			if tower["stun_source"] == "cannon" and int(tower["stun_count"]) > 0:
				cannon_stuns += 1
				_check(float(tower["stunned_remaining"]) > 0.01 and float(tower["stunned_remaining"]) <= 8.0, "Machine cannon accepted duration is host eight seconds, not client instant expiry")
	_check(cannon_stuns >= 2, "Each real peer board receives a cannon stun")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot simulate machine") == accepted, "Client cannot run divergent road, jump, cannon or door clocks")
	await _reject_boss_sends(accepted)
	await _finish()


func _reject_boss_sends(frozen: Dictionary) -> void:
	for lane: String in ["host", "guest"]:
		for type_id: String in ["troll", "orc_war_machine"]:
			_check(not frozen["enemy_types"][type_id]["send_available"], "Real accepted normal send consumer hides bosses")
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	_check(await _agree("Boss sends reject on both real peers") == frozen, "Network boss sends cannot change resources, queues, statistics or simulation")


func _of_type(state: Dictionary, type_id: String, slot: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in state["enemies"][slot]:
		if enemy["type_id"] == type_id:
			result.append(enemy)
	return result


func _first(state: Dictionary, type_id: String, slot: int = 0) -> Dictionary:
	var found: Array[Dictionary] = _of_type(state, type_id, slot)
	_check(not found.is_empty(), "Expected accepted live boss " + type_id)
	return {} if found.is_empty() else found[0]
