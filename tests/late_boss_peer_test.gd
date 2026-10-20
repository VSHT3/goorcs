extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: separate normal-match peers agree on late bosses, captured element damage, random twin cannon stuns, painted-route jump stages, troop output and simultaneous three-boss waves despite divergent client resources"
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
		for cell: Vector2i in [Vector2i(7, 3), Vector2i(10, 3), Vector2i(12, 4)]:
			await _build(lane, slot, cell.x, cell.y, MatchCombat.TargetMode.STRONGEST)
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
	await _assert_client_frozen(accepted, "Troll")
	await _command("host", {"action": "step", "delta": 24.999})
	accepted = await _agree("Host club windup replicates")
	for slot: int in range(2):
		var troll: Dictionary = _first(accepted, "troll", slot)
		_check(float(troll["tower_attack_remaining"]) > 1.24 and troll["tower_attack_target_ids"] == [accepted["towers"][slot][0]["id"]] and troll["tower_attack_aims"] == [str(Vector2(1, 3))], "Accepted nearest-tower club windup and captured aim win over client instant casts")
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
		_check(_of_type(accepted, "orc_war_machine", slot).size() == 1, "Both normal boards receive the guaranteed machine")
		var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
		_check_machine_route(machine)
		_check(int(machine["max_hp"]) > 1000000 and is_equal_approx(float(machine["base_speed"]), 0.0014) and machine["locomotion"] == "wheels", "Machine starts on host-owned ordinary-route wheels at its captured slow speed")
	var machine_rules: Dictionary = accepted["enemy_types"]["orc_war_machine"]
	_check(is_equal_approx(float(machine_rules["fire_damage_multiplier"]), 1.2) and is_equal_approx(float(machine_rules["lightning_damage_multiplier"]), 0.9), "Accepted fire and lightning modifiers replace divergent client resources")
	for kind: String in ["physical", "fire", "lightning"]:
		var before_hp: Array[int] = []
		for slot: int in range(2):
			before_hp.append(int(_first(accepted, "orc_war_machine", slot)["hp"]))
		await _command("host", {"action": "typed_damage_fixture", "type_id": "orc_war_machine", "kind": kind})
		accepted = await _agree("Captured machine element damage replicates")
		var expected: int = 24 if kind == "fire" else (18 if kind == "lightning" else 20)
		for slot: int in range(2):
			_check(before_hp[slot] - int(_first(accepted, "orc_war_machine", slot)["hp"]) == expected, "Host applies captured " + kind + " damage, not client multipliers")
	await _command("host", {"action": "step", "delta": 9.249})
	accepted = await _agree("First expanded troop deployment replicates")
	_check_machine_troops(accepted, true)
	await _command("host", {"action": "step", "delta": 2.75})
	accepted = await _agree("Random two-target cannon windup replicates")
	var cannon_targets: Array[Array] = []
	var prior_stuns: Array[Dictionary] = [{}, {}]
	for slot: int in range(2):
		for tower: Dictionary in accepted["towers"][slot]:
			prior_stuns[slot][int(tower["id"])] = int(tower["stun_count"])
		var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
		var targets: Array = machine["tower_attack_target_ids"]
		var aims: Array = machine["tower_attack_aims"]
		# JSON numbers are floats; Array membership requires matching ID types.
		var target_ids: Array[int] = []
		for target_id: Variant in targets:
			target_ids.append(int(target_id))
		cannon_targets.append(target_ids)
		_check(targets.size() == 2 and targets[0] != targets[1] and aims.size() == 2 and float(machine["tower_attack_remaining"]) > 1.39, "Accepted cannon captures two distinct host-randomized targets and windup aims")
		var far_targets: int = 0
		for index: int in range(targets.size()):
			for tower: Dictionary in accepted["towers"][slot]:
				if tower["id"] == targets[index]:
					_check(aims[index] == str(_tower_position(tower)), "Each accepted shell retains its selected tower's aim")
					if _tower_position(tower).distance_to(_painted_position(float(machine["progress"]))) > 4.5:
						far_targets += 1
		_check(far_targets >= 1, "Global cannon selection includes a tower outside the former range restriction")
	await _assert_client_frozen(accepted, "cannon windup")
	await _command("host", {"action": "step", "delta": 1.4})
	accepted = await _agree("Both random cannon impacts replicate")
	for slot: int in range(2):
		var stuns: int = 0
		for tower: Dictionary in accepted["towers"][slot]:
			if int(tower["id"]) in cannon_targets[slot]:
				stuns += 1
				_check(tower["stun_source"] == "cannon" and int(tower["stun_count"]) == int(prior_stuns[slot][int(tower["id"])]) + 1 and is_equal_approx(float(tower["stunned_remaining"]), 8.0), "Each selected tower receives one new host eight-second cannon stun")
			else:
				_check(int(tower["stun_count"]) == int(prior_stuns[slot][int(tower["id"])]), "One cannon volley never stuns an unselected tower")
		_check(stuns == 2, "Both selected cannon shells resolve on each accepted board")
	var stages: Array[Array] = [["wheels"], ["wheels"]]
	var takeoff_progress: Array[float] = [-1.0, -1.0]
	for tick: int in range(40):
		await _command("host", {"action": "step", "delta": 0.25})
		accepted = await _agree("Host ordinary-route jump boundary replicates")
		for slot: int in range(2):
			var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
			_check_machine_route(machine)
			var stage: String = machine["locomotion"]
			if stages[slot].back() != stage:
				stages[slot].append(stage)
			if stage == "jump_deploy":
				takeoff_progress[slot] = float(machine["progress"])
			if stage in ["jump", "jump_land"]:
				var distance: int = int(machine["jump_distance"])
				_check(distance >= 2 and distance <= 5 and int(machine["jump_count"]) == 1, "Host accepts one weighted two-to-five-cell jump, not client rapid five-cell jumps")
				_check(is_equal_approx(float(machine["jump_target_progress"]) - takeoff_progress[slot], float(distance)) and machine["jump_to"] == str(_painted_position(float(machine["jump_target_progress"]))), "Accepted jump advances captured route-cell distance around the painted corner")
		if stages[0].size() == 6 and stages[1].size() == 6:
			break
	for slot: int in range(2):
		_check(stages[slot] == ["wheels", "jump_deploy", "jump_charge", "jump", "jump_land", "wheels"], "Both peers observe the complete legs, crouch, flight, landing and wheels sequence")
	_check_machine_troops(accepted, false)
	await _assert_client_frozen(accepted, "machine jump and troop state")
	await _reject_boss_sends(accepted)
	await _command("host", {"action": "round_fixture", "round": 400, "all_bosses": true})
	await _wait_combat("guest", {"wave": 399, "phase": 0}, "Host selects an ordinary late three-boss encounter seed")
	await _both_ready()
	await _wait_combat("guest", {"wave": 400, "phase": 1}, "Normal readiness admits the simultaneous late encounter")
	await _command("host", {"action": "step", "delta": 0.001})
	accepted = await _agree("Three simultaneous actual bosses replicate")
	for type_id: String in ["necorcmancer_mancer", "troll", "orc_war_machine"]:
		_check(accepted["wave_roster"].count(type_id) == 1, "Ordinary late wave reserves one " + type_id + " alongside the other bosses")
		for slot: int in range(2):
			_check(_of_type(accepted, type_id, slot).size() == 1, "Both peer boards retain a live simultaneous " + type_id)
	await _assert_client_frozen(accepted, "simultaneous three-boss state")
	await _reject_boss_sends(accepted)
	await _test_paid_boss_sends()
	await _finish()


func _assert_client_frozen(accepted: Dictionary, label: String) -> void:
	var runtime: Dictionary = _debug_runtime()
	_check(runtime.get("random_states", []).size() == 6, "Host fixture exposes every authoritative RNG stream")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot simulate " + label) == accepted, "Divergent client clocks cannot change accepted " + label)
	_check(_debug_runtime() == runtime, "Client simulation requests consume no host RNG or simulation time for " + label)


func _painted_route() -> Array[Vector2i]:
	var route: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 1)]
	for x: int in range(14):
		route.append(Vector2i(x, 0))
	route.append(Vector2i(13, 1))
	route.append(Vector2i(13, 2))
	return route


func _painted_position(progress: float) -> Vector2:
	var route: Array[Vector2i] = _painted_route()
	var index: int = mini(floori(progress), route.size() - 2)
	return Vector2(route[index]).lerp(Vector2(route[index + 1]), progress - float(index))


func _tower_position(tower: Dictionary) -> Vector2:
	var position: Vector2 = str_to_var("Vector2" + String(tower["cell"]))
	return position


func _check_machine_route(machine: Dictionary) -> void:
	var expected: Array[String] = []
	for cell: Vector2i in _painted_route():
		expected.append(str(cell))
	_check(machine["route"] == expected, "Accepted machine retains the complete winding painted route, including both portal/base turns")
	_check(machine["pos"] == str(_painted_position(float(machine["progress"]))), "Logical machine position remains consistent with captured ordinary route progress during every jump stage")


func _check_machine_troops(accepted: Dictionary, first_deployment: bool) -> void:
	for slot: int in range(2):
		var machine: Dictionary = _first(accepted, "orc_war_machine", slot)
		var deployments: int = int(machine["summon_count"])
		var children: int = 0
		for enemy: Dictionary in accepted["enemies"][slot]:
			if int(enemy["summoner_id"]) == int(machine["id"]):
				children += 1
				_check(enemy["type_id"] in ["orcling", "grunt", "runner"] and enemy["route"] == machine["route"], "Door troops inherit their machine's captured ordinary painted route")
				_check(float(enemy["progress"]) >= 0.0 and float(enemy["progress"]) < float(machine["route"].size() - 1), "Accepted infantry retain safe ordinary route-cell progress")
		if first_deployment:
			_check(deployments == 1 and children >= 4 and children <= 7, "First host troop doors release four to seven real infantry despite the client's single-child rule")
		else:
			_check(deployments >= 2 and children >= 8 and children <= mini(24, deployments * 7), "Repeated host deployments increase living infantry within the captured twenty-four-troop cap")


func _reject_boss_sends(frozen: Dictionary) -> void:
	var runtime: Dictionary = _debug_runtime()
	for lane: String in ["host", "guest"]:
		for type_id: String in ["necorcmancer_mancer", "troll", "orc_war_machine"]:
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	_check(_debug_runtime() == runtime, "Locked or income-unfunded boss orders consume no authoritative RNG or simulation time")
	_check(await _agree("Unaffordable boss sends reject on both real peers") == frozen, "Local guest send settings cannot bypass host unlock, Coins or recurring-income requirements")


func _test_paid_boss_sends() -> void:
	for type_id: String in ["necorcmancer_mancer", "troll", "orc_war_machine"]:
		var state: Dictionary = await _agree("Accepted boss send terms agree")
		var terms: Dictionary = state["enemy_types"][type_id]
		var unlock: int = int(terms["send_first_wave"])
		var cost: int = int(terms["send_cost"])
		var penalty: int = -int(terms["send_income"])
		await _command("host", {"action": "round_fixture", "round": unlock - 1})
		await _command("host", {"action": "send_economy_fixture", "coins": [cost, cost], "income": [penalty, penalty]})
		state = await _agree("Both peers receive fully funded pre-unlock boss state")
		_check(not state["enemy_types"][type_id]["send_available"], "Host unlock overrides guest's round-one local boss send gate")
		await _reject_paid_order(type_id, state)
		await _command("host", {"action": "round_fixture", "round": unlock})
		for balances: Array in [[cost - 1, penalty], [cost, penalty - 1]]:
			await _command("host", {"action": "send_economy_fixture", "coins": [balances[0], balances[0]], "income": [balances[1], balances[1]]})
			state = await _agree("Host publishes an unlocked but unfunded boss")
			_check(state["enemy_types"][type_id]["send_available"], "Affordability never removes an unlocked boss from the selector")
			await _reject_paid_order(type_id, state)
		await _command("host", {"action": "send_economy_fixture", "coins": [cost, cost], "income": [penalty, penalty]})
		var before: Dictionary = await _agree("Exact boss price and penalty are available")
		for lane: String in ["host", "guest"]:
			await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
		state = await _agree("Real host and guest commands purchase a boss at its unlock")
		_check(_matches(state, {"coins": [0, 0], "income": [0, 0], "send_queues": [[type_id], [type_id]]}), "Both send paths charge captured host Coins/income exactly once and queue one boss")
		for slot: int in range(2):
			_check(int(state["enemy_totals"][slot]["sent"].get(type_id, 0)) == int(before["enemy_totals"][slot]["sent"].get(type_id, 0)) + 1, "Each authenticated sender receives exactly one accepted boss send count")
		await _reject_paid_order(type_id, state)
		await _both_ready()
		await _command("host", {"action": "step", "delta": 0.001})
		state = await _agree("Paid bosses deliver through the actual combat FIFO")
		for slot: int in range(2):
			_check(_of_type(state, type_id, slot).size() == 1 + state["wave_roster"].count(type_id) and int(state["queued_sends"][slot]) == 0, "Each board receives the paid boss in addition to any regular encounter")


func _reject_paid_order(type_id: String, frozen: Dictionary) -> void:
	var runtime: Dictionary = _debug_runtime()
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": type_id})
	_check(await _agree("Rejected paid-boss commands leave accepted state unchanged") == frozen and _debug_runtime() == runtime, "Rejected peer orders preserve balances, queues, totals and host random streams")


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
