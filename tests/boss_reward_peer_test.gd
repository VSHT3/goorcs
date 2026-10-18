extends "res://tests/match_branch_test.gd"

func _run() -> void:
	success_message = "PASS: real peers agree on first-boss tier and atomic payer-owned rewards despite divergent client payouts, duplicate kills and client attempts"
	planning_worker_path = "res://tests/boss_reward_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_reward_peer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"active": true}, "Both private decks admit reward peers")
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		for x: int in range(1, 5):
			await _edit(lane, slot, x, 2)
		await _command(lane, {"action": "build", "slot": slot, "x": 1, "y": 0, "type_id": "arrow_tower", "mode": 0})
	await _open_boss()
	var before: Dictionary = await _agree("Both peers see live boss before reward")
	await _command("guest", {"action": "boss_hit_fixture", "slot": 1})
	_check(await _agree("Client cannot award boss loot") == before, "Guest cannot mint its own configured rewards or decide a boss death")
	await _command("host", {"action": "boss_hit_fixture", "slot": 1})
	var awarded: Dictionary = await _agree("Host boss award and balances replicate atomically")
	_check(awarded["boss_rewards"][0].is_empty() and awarded["boss_rewards"][1].size() == 1, "Only the killing board receives its first boss reward")
	if awarded["boss_rewards"][1].size() != 1:
		await _finish()
		return
	var reward: Dictionary = awarded["boss_rewards"][1][0]
	var rules: BossRewardRules = load("res://resources/combat/boss_rewards.tres")
	var payout: Vector2i = rules.payouts[String(reward["rarity"])]
	_check(int(reward["coins"]) == payout.x and int(reward["shards"]) == payout.y, "Wire payout comes from admitted host configuration, not seven-times guest values")
	var boss: Dictionary = awarded["enemy_types"]["necorcmancer_mancer"]
	_check(int(awarded["coins"][1]) - int(before["coins"][1]) == int(boss["kill_bounty"]) + int(reward["coins"]), "Bonus Coins and ordinary boss bounty credit together before revealing")
	var drop: int = int(awarded["reroll_currency"][1]) - int(before["reroll_currency"][1]) - int(reward["shards"])
	_check(drop == 0 or drop == int(boss["reroll_drop_amount"]), "Only the ordinary independent drop can add Shards beyond the accepted bonus")
	await _open_boss()
	await _command("host", {"action": "boss_hit_fixture", "slot": 1})
	var repeated: Dictionary = await _agree("Repeat encounter does not duplicate the first-kill award")
	_check(repeated["boss_rewards"][1] == awarded["boss_rewards"][1], "A debug round revisit preserves per-run first-kill claims and durable event IDs")
	await _command("host", {"action": "boss_hit_fixture", "slot": 0})
	var own: Dictionary = await _agree("Other board independently earns its first kill")
	_check(own["boss_rewards"][0].size() == 1 and own["boss_rewards"][1] == awarded["boss_rewards"][1], "Each player independently earns one award without altering the friend's reward")
	await _finish()

func _open_boss() -> void:
	for round_number: int in [41, 40]:
		await _command("host", {"action": "round_fixture", "round": round_number})
	await _wait_combat("guest", {"phase": 0, "wave": 39}, "Round40 planning synchronizes")
	await _both_ready()
	await _wait_combat("guest", {"phase": 1, "wave": 40}, "Both commitments open the real boss wave")
	await _command("host", {"action": "step", "delta": 0.001})
	await _agree("Boss birth synchronizes before a controlled hit")
