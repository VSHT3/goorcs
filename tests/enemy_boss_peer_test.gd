extends "res://tests/match_branch_test.gd"

const BOSS := "necorcmancer_mancer"


func _run() -> void:
	success_message = "PASS: separate host/client admit round40 boss, accepted HP/speed and inherited summons despite divergent local resources; unsendable commands stay atomic"
	planning_worker_path = "res://tests/enemy_boss_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_enemy_boss_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Explicit loadout commitments admit both boss peers")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
	await _command("host", {"action": "round_fixture", "round": 40})
	await _wait_combat("guest", {"wave": 39}, "Remote receives host round40 planning")
	var planning_state: Dictionary = await _agree("Round40 preview agrees")
	_check(planning_state["enemy_types"].has(BOSS) and not planning_state["enemy_types"][BOSS]["send_available"], "Host boss metadata overrides client's sendable local resource")
	await _reject_both(planning_state)
	await _both_ready()
	await _wait_combat("guest", {"wave": 40, "phase": 1}, "Both ready starts guaranteed boss round through normal admission")
	await _command("host", {"action": "step", "delta": 0.001})
	var accepted: Dictionary = await _agree("Guaranteed live boss replicates")
	var rules := CombatRules.new()
	var boss_definition: EnemyDefinition
	for definition: EnemyDefinition in rules.catalog.enemies:
		if String(definition.id) == BOSS:
			boss_definition = definition
	_check(boss_definition != null, "Boss is registered in shipped catalog")
	for slot: int in range(2):
		var bosses: Array[Dictionary] = _bosses(accepted, slot)
		_check(bosses.size() == 1, "Each accepted board has exactly one guaranteed boss")
		if bosses.size() != 1 or boss_definition == null:
			continue
		var boss: Dictionary = bosses[0]
		var expected_hp: int = ceili((rules.enemy_health + 39) * boss_definition.health_multiplier)
		_check(int(boss["max_hp"]) == expected_hp and int(boss["max_hp"]) == int(planning_state["enemy_types"][BOSS]["health"]), "Real host/client live HP matches new slope and accepted planning preview, not client-local HP")
		_check(is_equal_approx(float(boss["speed"]), 0.05 * boss_definition.speed_multiplier), "Client renders captured host boss speed rather than divergent local multiplier")
	await _reject_both(accepted)
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot advance boss") == accepted, "Guest cannot move boss or run its faster local summon clock")
	await _command("host", {"action": "step", "delta": 6.999})
	accepted = await _agree("Host ritual begins on both peers")
	for slot: int in range(2):
		for boss: Dictionary in _bosses(accepted, slot):
			_check(boss["animation"] == "cast" and float(boss["speed"]) == 0.0, "Only host begins stationary boss ritual")
	await _command("host", {"action": "step", "delta": 1.15})
	accepted = await _agree("Host boss children replicate")
	var child_ids: Array[Array] = [[], []]
	for slot: int in range(2):
		for boss: Dictionary in _bosses(accepted, slot):
			var children: int = 0
			for enemy: Dictionary in accepted["enemies"][slot]:
				if enemy["summoner_id"] == boss["id"]:
					children += 1
					child_ids[slot].append(enemy["id"])
					_check(enemy["type_id"] == "necorcmancer" and enemy["route"] == boss["route"] and is_equal_approx(float(enemy["progress"]), float(boss["progress"])) and int(enemy["max_hp"]) == (rules.enemy_health + 39) * 5, "Replicated boss children are host-scaled NecOrcmancers on the captured route")
			_check(children in [2, 3, 4] and int(boss["summon_count"]) == 1, "Exactly one host ritual produces its bounded children")
	await _command("host", {"action": "step", "delta": 8.15})
	accepted = await _agree("Boss-raised NecOrcmancers summon their own children")
	for slot: int in range(2):
		for child_id: Variant in child_ids[slot]:
			var grandchildren: int = 0
			for enemy: Dictionary in accepted["enemies"][slot]:
				if enemy["summoner_id"] == child_id:
					grandchildren += 1
					_check(enemy["type_id"] == "skeleorc" and int(enemy["max_hp"]) == ceili((rules.enemy_health + 39) * 0.5), "Replicated second-generation skeletons use the accepted host HP progression")
			_check(grandchildren in [2, 3, 4], "Each accepted boss-raised NecOrcmancer independently casts an ordinary ritual")
	await _command("host", {"action": "round_fixture", "round": 100})
	await _wait_combat("guest", {"wave": 99, "phase": 0}, "Late planning also uses host-authoritative boss gate")
	await _reject_both(await _agree("Late boss preview agrees"))
	await _finish()


func _reject_both(frozen: Dictionary) -> void:
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "send", "slot": 0 if lane == "host" else 1, "type_id": BOSS})
	_check(await _agree("Rejected boss commands replicate no changes") == frozen, "Host and remote boss sends cannot spend coins, grant income, enqueue enemies or change totals")


func _bosses(state: Dictionary, slot: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in state["enemies"][slot]:
		if enemy["type_id"] == BOSS:
			result.append(enemy)
	return result
