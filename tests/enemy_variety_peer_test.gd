extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: real authenticated peers retain host physical resistance, individual death children, permanent rage and self-regeneration despite divergent guest resources"
	planning_worker_path = "res://tests/enemy_variety_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_enemy_variety_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Variety peers admit")
	var initial: Dictionary = await _agree("Initial host-owned variety metadata agrees")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "moss_orc"})
	_check(await _agree("Locked new send remains atomic") == initial, "Guest cannot bypass MossOrc progression with local metadata")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
	# Far from the entrance, so this actual credited tower cannot auto-hit our fixtures.
	await _build("guest", 1, 5, 0, MatchCombat.TargetMode.FURTHEST, "arrow_tower")
	await _wait_tower("host", 1, Vector2i(5, 0), MatchCombat.TargetMode.FURTHEST)
	await _command("host", {"action": "variety_round"})
	await _wait_combat("guest", {"wave": 65}, "Host round unlock reaches guest")
	for type_id: String in ["scrapguard", "crate_orc", "rage_orc", "moss_orc"]:
		await _command("host", {"action": "send", "slot": 0, "type_id": type_id})
	await _wait_combat("guest", {"income": [15, 0]}, "Four independent paid identities accepted")
	var ordered: Dictionary = await _agree("Accepted variety economy agrees")
	_check(ordered["coins"][0] == 9715 and ordered["queued_sends"][1] == 4, "Fixture prices 35 + 50 + 80 + 120 buy one individual each, no rolled Orcling group")
	await _both_ready()
	await _wait_combat("guest", {"wave": 66, "phase": 1}, "Variety wave starts")
	await _command("host", {"action": "step", "delta": 1.1})
	var before: Dictionary = await _agree("All new enemies enter host combat")
	var crate: Dictionary = _enemy(before, "crate_orc")
	var route: Array = crate["route"].duplicate()
	var progress: float = crate["progress"]
	var original_orclings: Dictionary = {}
	for enemy: Dictionary in before["enemies"][1]:
		if enemy["type_id"] == "orcling":
			original_orclings[enemy["id"]] = true
	await _command("host", {"action": "variety_damage"})
	var accepted: Dictionary = await _agree("Actual host damage and death children replicate")
	var scrap: Dictionary = _enemy(accepted, "scrapguard")
	var rage: Dictionary = _enemy(accepted, "rage_orc")
	var moss: Dictionary = _enemy(accepted, "moss_orc")
	_check(scrap["hp"] == int(scrap["max_hp"]) - 5 and float(scrap["physical_damage_multiplier"]) == 0.5, "Guest sees host half physical damage, not its local resistance")
	_check(rage["enraged"] and is_equal_approx(float(rage["base_speed"]), 0.05 * 0.8 * 1.6), "Accepted permanent rage uses host resource multiplier once")
	_check(moss["hp"] == int(moss["max_hp"]) - 100 and moss["regeneration_count"] == 0, "Self-heal does not arrive before birth-relative four-second deadline")
	var children: int = 0
	for enemy: Dictionary in accepted["enemies"][1]:
		_check(enemy["id"] != crate["id"], "Real crate death retires parent from accepted living state")
		if enemy["type_id"] == "orcling" and not original_orclings.has(enemy["id"]):
			children += 1
			_check(enemy["route"] == route and is_equal_approx(float(enemy["progress"]), progress) and float(enemy["age"]) == 0.0, "Every replicated child retains exact captured parent route/progress and birth time")
	_check(children == 2 and accepted["enemy_totals"][1]["kills"].get("crate_orc", 0) == 1, "Host creates exactly two individual Orclings despite guest's authored five")
	await _command("guest", {"action": "step", "delta": 100.0})
	await _command("guest", {"action": "variety_damage"})
	_check(await _agree("Guest cannot author clocks or hit fixtures") == accepted, "Client step and local fixture command cannot heal, enrage, damage or spawn accepted enemies")
	await _command("host", {"action": "step", "delta": 4.0})
	var healed: Dictionary = await _agree("Host regeneration deadline replicates")
	moss = _enemy(healed, "moss_orc")
	rage = _enemy(healed, "rage_orc")
	scrap = _enemy(healed, "scrapguard")
	_check(moss["regeneration_count"] == 1 and moss["hp"] == int(moss["max_hp"]) - 52, "Only host's actual eight-percent periodic heal reaches guest")
	_check(scrap["hp"] == int(scrap["max_hp"]) - 5 and rage["hp"] == int(rage["max_hp"]) / 2, "Moss never heals nearby allies and client local data cannot do so")
	_check(rage["enraged"] and is_equal_approx(float(rage["base_speed"]), 0.05 * 0.8 * 1.6) and healed["statistics_id"] == initial["statistics_id"], "Permanent host transition and run identity survive later snapshots")
	var detached: Dictionary = healed.duplicate(true)
	detached["enemies"][1][0]["hp"] = -123
	_check(await _agree("Detached observer cannot mutate live host state") == healed, "Consumer-side mutation cannot change either real peer's authoritative state")
	await _finish()


func _enemy(state: Dictionary, type_id: String) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", [[], []])[1]:
		if enemy["type_id"] == type_id:
			return enemy
	_check(false, "Expected accepted variety enemy: " + type_id)
	return {}
