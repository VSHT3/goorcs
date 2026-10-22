extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: real host/client accept atomic random groups, unlock gates, circular healing and captured-route ritual children without client simulation"
	planning_worker_path = "res://tests/enemy_mechanics_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("goorcs_enemy_mechanics_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Enemy peers admit")
	var initial: Dictionary = await _agree("Initial accepted enemy state")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "necorcmancer"})
	await _command("host", {"action": "send", "slot": 0, "type_id": "skeleorc"})
	_check(await _agree("Rejected enemy commands stay atomic") == initial, "Locked NecOrcmancer and summon-only sends cannot overspend or create free client enemies")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
	await _command("host", {"action": "round_fixture", "round": 46})
	await _wait_combat("guest", {"wave": 45}, "Host-selected final unlock is accepted")
	for type_id: String in ["orcling", "orc_chief", "necorcmancer"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
	await _wait_combat("guest", {"income": [12, 0]}, "Client receives every accepted leader/group purchase")
	var ordered: Dictionary = await _agree("Host group purchase is replicated atomically")
	var group_count: int = ordered["send_queues"][1].count("orcling")
	_check(group_count in [2, 3, 4] and _matches(ordered, {"coins": [718, 1000], "income": [12, 0]}), "Host random group pays one price/income while Chief and Necro retain their prices")
	var sent: Dictionary = ordered["enemy_totals"][0]["sent"]
	_check(sent.size() == 3 and _matches(sent, {"orcling": group_count, "orc_chief": 1, "necorcmancer": 1}), "Real peer accepted counters count actual individuals, not commands")
	await _both_ready()
	await _wait_combat("guest", {"wave": 46, "phase": 1}, "Mechanics wave starts")
	await _command("host", {"action": "step", "delta": 1.0})
	var accepted: Dictionary = await _agree("All paid identities enter current host combat")
	_check(accepted["enemies"][1].size() == group_count + 3, "Regular Orc plus complete paid group and two leaders all exist on destination board")
	await _command("host", {"action": "wound_fixture"})
	accepted = await _agree("Injured host-only fixture replicated")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot run ability clocks") == accepted, "Client step cannot independently heal, summon, move or randomize accepted state")
	await _command("host", {"action": "step", "delta": 5.0})
	accepted = await _agree("Host circular heal reaches real client")
	var chief: Dictionary = _enemy(accepted, "orc_chief")
	_check(int(chief.get("heal_count", 0)) == 1, "Only host clock emits the five-second healing event")
	for enemy: Dictionary in accepted["enemies"][1]:
		if enemy["type_id"] == "orcling":
			_check(enemy["hp"] == 12, "Client receives actual 4%-maximum allied healing rather than its divergent local metadata")
	await _command("host", {"action": "step", "delta": 2.0})
	accepted = await _agree("Host begins stationary ritual")
	var caster: Dictionary = _enemy(accepted, "necorcmancer")
	_check(caster.get("animation", "") == "cast" and caster.get("speed", -1.0) == 0.0, "Client renders accepted cast state without starting its own ritual")
	var caster_progress: float = caster.get("progress", -1.0)
	await _command("host", {"action": "step", "delta": 1.5})
	accepted = await _agree("Host ritual children replicate")
	caster = _enemy(accepted, "necorcmancer")
	var children: int = 0
	for enemy: Dictionary in accepted["enemies"][1]:
		if enemy["type_id"] == "skeleorc":
			children += 1
			_check(enemy["summoner_id"] == caster["id"] and enemy["route"] == caster["route"] and float(enemy["progress"]) >= caster_progress and float(enemy["progress"]) < 1.0, "Each real child retains caster route/progress and never restarts at portal or jumps to base")
	_check(children in [2, 3, 4] and int(caster.get("summon_count", 0)) == 1, "Exactly one host ritual creates a bounded randomized child group")
	_check(accepted["statistics_id"] == initial["statistics_id"] and not accepted["rules"]["sandbox_mode"], "Accepted statistics identity survives rounds and real match remains non-sandbox")
	var tower_cell := Vector2i(1, 1 - int(accepted["board_origin_y"]))
	await _build("guest", 1, tower_cell.x, tower_cell.y, MatchCombat.TargetMode.FURTHEST, "rune_obelisk")
	var tower: Dictionary = await _wait_tower("host", 1, tower_cell, MatchCombat.TargetMode.FURTHEST)
	for upgrade: String in ["damage", "speed", "boulders"]:
		await _command("guest", {"action": "upgrade", "slot": 1, "tower_id": int(tower["id"]), "upgrade": upgrade})
	await _wait_combat("host", {"coins": [718, 567]}, "Real guest construction and evolution are accepted before death simulation")
	var death_state: Dictionary = {}
	for tick: int in range(80):
		await _command("host", {"action": "step", "delta": 0.1})
		death_state = await _agree("Confirmed death events replicate with actual damage")
		if not death_state["deaths"][1].is_empty():
			break
	_check(not death_state["deaths"][1].is_empty(), "A real tower kill reaches both peers as one accepted corpse event")
	if not death_state["deaths"][1].is_empty():
		var event: Dictionary = death_state["deaths"][1][0]
		_check(death_state["enemy_totals"][1]["kills"].has(event["type_id"]), "Replicated death identity matches the authoritative kill totals")
		for enemy: Dictionary in death_state["enemies"][1]:
			_check(enemy["id"] != event["enemy_id"], "Replicated corpses never remain live targetable enemies")
	await _finish()


func _enemy(state: Dictionary, type_id: String) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", [[], []])[1]:
		if enemy["type_id"] == type_id:
			return enemy
	_check(false, "Expected real accepted enemy: " + type_id)
	return {}
