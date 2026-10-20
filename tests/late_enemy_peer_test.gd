extends "res://tests/match_branch_test.gd"


func _run() -> void:
	success_message = "PASS: separate normal-match peers agree on rare Giant births, undead immunities, ten-hit shields, death stuns and delayed same-board bomb timing despite divergent client resources"
	planning_worker_path = "res://tests/late_enemy_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_late_enemy_peers_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Late enemy peers admit private loadouts")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
		await _build(lane, slot, 5, 0, MatchCombat.TargetMode.FURTHEST, "arrow_tower")
	await _command("host", {"action": "late_round"})
	var setup: Dictionary = await _agree("Both peers receive late-round host data")
	var row: int = int(_snapshot("host")["boards"][0]["route"][0][1])
	for lane: String in ["host", "guest"]:
		await _build(lane, 0 if lane == "host" else 1, 2, row - 1, MatchCombat.TargetMode.FURTHEST, "arrow_tower")
	await _both_ready()
	await _command("host", {"action": "late_births"})
	var initial: Dictionary = await _agree("Real host publishes the accepted new identities")
	for slot: int in range(2):
		var giant: Dictionary = _enemy(initial, "giant_skeltorc", slot)
		var kamika: Dictionary = _enemy(initial, "kamikaorc", slot)
		_check(giant["max_hp"] == 25000 and giant["fire_immune"] and giant["ice_immune"] and is_equal_approx(float(giant["base_speed"]), 0.05 * 0.84), "Accepted Giant uses host rounded health, movement and immunities rather than guest-local overrides")
		_check(kamika["shield_hits"] == 10 and kamika["hp"] == kamika["max_hp"], "Guest's local two-hit shield cannot replace host ten-hit state")
	await _command("host", {"action": "late_hits", "count": 9})
	var protected: Dictionary = await _agree("Nine host contacts synchronize without HP damage")
	for slot: int in range(2):
		_check(_enemy(protected, "kamikaorc", slot)["shield_hits"] == 1 and _enemy(protected, "kamikaorc", slot)["hp"] == _enemy(initial, "kamikaorc", slot)["hp"], "Nine arbitrarily large hits remove nine shields and no HP on either board")
	await _command("guest", {"action": "late_hits", "count": 100})
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Guest cannot author shield or clock changes") == protected, "Remote fixture commands cannot decide damage or simulation time")
	await _command("host", {"action": "late_hits", "count": 1})
	var broken: Dictionary = await _agree("Shield break remains an absorbed contact")
	_check(_enemy(broken, "kamikaorc", 0)["shield_hits"] == 0 and _enemy(broken, "kamikaorc", 0)["hp"] == _enemy(initial, "kamikaorc", 0)["hp"], "Tenth hit breaks protection without damage overflow")
	await _command("host", {"action": "late_hits", "count": 1})
	var dead: Dictionary = await _agree("Eleventh host contact produces actual same-board death stuns")
	for slot: int in range(2):
		_check(_find(dead, "kamikaorc", slot).is_empty() and is_equal_approx(float(dead["towers"][slot][1]["stunned_remaining"]), 3.0) and float(dead["towers"][slot][0]["stunned_remaining"]) == 0.0, "Host death radius and full three-second timer override local guest values")
	await _command("host", {"action": "step", "delta": 3.0})
	var recovered: Dictionary = await _agree("Kamika stun expires through normal host stepping")
	_check(float(recovered["towers"][0][1]["stunned_remaining"]) == 0.0, "Real peer tower recovery is accepted, not client-calculated")
	var coins: Array = recovered["coins"].duplicate()
	await _command("host", {"action": "late_giant_death", "slot": 0})
	var fuse: Dictionary = await _agree("Giant death drops accepted pending bomb")
	_check(fuse["coins"] == coins and fuse["bombs"].size() == 1 and fuse["bombs"][0]["slot"] == 0 and is_equal_approx(float(fuse["bombs"][0]["fuse_remaining"]), 2.0), "Bomb grants no extra Coins and keeps host two-second fuse on its original board")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _agree("Client cannot detonate its locally shorter fuse") == fuse, "Only host simulation advances pending bomb state")
	await _command("host", {"action": "step", "delta": 1.999})
	var waiting: Dictionary = await _agree("Bomb remains pending before the real fuse boundary")
	_check(waiting["bombs"].size() == 1 and float(waiting["towers"][0][1]["stunned_remaining"]) == 0.0, "No early bomb stun is possible before accepted detonation")
	await _command("host", {"action": "step", "delta": 0.001})
	var blast: Dictionary = await _agree("Host bomb detonation reaches both peers")
	var victim: Dictionary = _enemy(blast, "necorcmancer", 0)
	_check(blast["bombs"].is_empty() and not blast["bomb_explosions"].is_empty() and is_equal_approx(float(victim["stunned_remaining"]), 3.0) and is_equal_approx(float(blast["towers"][0][1]["stunned_remaining"]), 3.0), "Accepted blast stuns enemies and towers using host radius and timer")
	_check(_enemy(blast, "giant_skeltorc", 1)["stunned_remaining"] == 0.0 and float(blast["towers"][1][1]["stunned_remaining"]) == 0.0, "Same visual world never lets a bomb stun the other board")
	await _command("host", {"action": "step", "delta": 1.5})
	var paused_enemy: Dictionary = _enemy(await _agree("Enemy stun remains authoritative during its lifetime"), "necorcmancer", 0)
	_check(paused_enemy["progress"] == victim["progress"] and paused_enemy["age"] == victim["age"] and is_equal_approx(float(paused_enemy["stunned_remaining"]), 1.5), "Enemy movement and ability age pause while only stun duration advances")
	await _command("host", {"action": "step", "delta": 1.75})
	var resumed: Dictionary = _enemy(await _agree("Enemy resumes after accepted expiry"), "necorcmancer", 0)
	_check(resumed["stunned_remaining"] == 0.0 and float(resumed["progress"]) > float(victim["progress"]), "Normal host movement resumes for the post-expiry portion of the tick")
	await _finish()


func _find(state: Dictionary, type_id: String, slot: int) -> Dictionary:
	for enemy: Dictionary in state["enemies"][slot]:
		if enemy["type_id"] == type_id:
			return enemy
	return {}


func _enemy(state: Dictionary, type_id: String, slot: int) -> Dictionary:
	var found: Dictionary = _find(state, type_id, slot)
	_check(not found.is_empty(), "Expected real accepted enemy: " + type_id)
	return found
