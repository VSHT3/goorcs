extends "res://tests/match_branch_test.gd"

var _fence_token: int = 0


func _run() -> void:
	success_message = "PASS: separate authenticated commander peers agree on independent selections/terrain, frozen commitments, paid clear ownership, Ready locks and host-only Rally/Stasis outcomes despite divergent client data"
	planning_worker_path = "res://tests/commander_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_directory = OS.get_temp_dir().path_join("gorcs_commander_peers_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	await _command("host", {"action": "draft_seed", "seed": 9182})
	await _command("guest", {"action": "draft_seed", "seed": 99999})
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"selecting": true}, "Real admission opens the secret-number draft before any tower selection")
	await _settle()
	var hidden: Dictionary = _snapshot("guest")["commander_draft"]
	_check(_matches(hidden, {"phase": "guessing", "target": -1, "guesses": [-1, -1]}) and _snapshot("guest")["chosen_deck"].is_empty(), "Even the authenticated client receives no secret target, guesses or premature tower choices")
	await _command("guest", {"action": "forge_guess", "value": 50.5})
	await _command("guest", {"action": "forge_deck"})
	await _settle()
	_check(_snapshot("host")["commander_draft"] == hidden and _snapshot("guest")["chosen_deck"].is_empty(), "The host rejects noninteger raw guesses and authenticated tower-phase bypass attempts")
	var draft_random := RandomNumberGenerator.new()
	draft_random.seed = 9182
	var target: int = draft_random.randi_range(0, 100)
	var far_guess: int = 100 if target < 50 else 0
	await _command("host", {"action": "guess", "value": target})
	await _settle()
	var locked: Dictionary = _snapshot("guest")["commander_draft"]
	_check(_matches(locked, {"guess_locked": [true, false], "target": -1, "guesses": [-1, -1]}), "The first real lock reveals status only, never the host's committed guess")
	await _command("host", {"action": "guess", "value": far_guess})
	await _command("guest", {"action": "guess", "value": far_guess})
	await _settle()
	var revealed: Dictionary = _snapshot("guest")["commander_draft"]
	_check(_matches(revealed, {"target": target, "guesses": [target, far_guess], "first_picker": 0, "picker": 0}), "Both peers receive one authoritative reveal and the closer player's ordered first pick despite divergent local RNG")
	await _command("guest", {"action": "forge_commander", "commander": "knight"})
	await _command("guest", {"action": "forge_deck"})
	await _settle()
	_check(_snapshot("guest")["commander_draft"] == revealed and _snapshot("guest")["chosen_deck"].is_empty(), "Authenticated out-of-turn hero selection and post-reveal tower bypass are still rejected")
	await _command("host", {"action": "commander", "commander": "knight"})
	await _settle()
	var first_pick: Dictionary = _snapshot("guest")["commander_draft"]
	await _command("host", {"action": "commander", "commander": "priestess"})
	await _command("guest", {"action": "commander", "commander": "knight"})
	await _settle()
	_check(_snapshot("guest")["commander_draft"] == first_pick and first_pick["picks"] == ["knight", ""], "The first pick freezes immediately and the second player cannot duplicate it")
	await _command("guest", {"action": "commander", "commander": "priestess"})
	await _wait_for("guest", {"chosen_commander": "priestess", "commander_ids": ["knight", "priestess"]}, "Distinct ordered hero picks publish the accepted public identities")
	await _settle()
	_check(_snapshot("guest")["commander_draft"]["phase"] == "loadout", "Only both final hero picks unlock tower selection")
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "deck"})
		await _wait_for(lane, {"chosen_deck": ["arrow_tower"]}, "Each peer explicitly admits its own loadout")
	await _command("host", {"action": "seed", "seed": 84421})
	await _command("host", {"action": "commit"})
	await _command("host", {"action": "commander", "commander": "priestess"})
	_check(not _snapshot("host")["active"] and _snapshot("host")["committed"] and _snapshot("host")["chosen_commander"] == "knight", "First commitment freezes only that player's commander and does not start boards")
	await _command("guest", {"action": "commit"})
	await _wait_for("guest", {"active": true, "committed": true}, "Both commitments start the actual multiplayer boards")
	var initial: Dictionary = await _settle()
	var random := RandomNumberGenerator.new()
	random.seed = 84421
	var expected: Array = [CommanderRules.generate(&"knight", PathLayout.new(), random), CommanderRules.generate(&"priestess", PathLayout.new(), random)]
	var serialized: Variant = JSON.parse_string(JSON.stringify(expected))
	_check(initial["commanders"] == serialized, "Host independently generates each board with its own RNG and publishes the accepted cells despite divergent guest dimensions")
	_check(initial["commanders"][0]["landmark"] != initial["commanders"][1]["landmark"] or initial["commanders"][0]["obstacles"] != initial["commanders"][1]["obstacles"], "The two accepted terrains are independent draws, not copied results")
	await _command("guest", {"action": "forge_commander", "commander": "knight"})
	_check(await _settle() == initial and _snapshot("guest")["chosen_commander"] == "priestess", "An authenticated forged post-commit selection cannot replace the frozen identity or terrain")
	await _terrain_and_clears(initial)
	await _abilities()
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Disconnect removes commander match state")
	await _command("host", {"action": "draft_seed", "seed": 127})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("guest", {"selecting": true, "committed": false}, "Rejoin opens a completely fresh secret-number draft")
	await _settle()
	var replay: Dictionary = _snapshot("guest")["commander_draft"]
	_check(_snapshot("host")["combat"]["commanders"] == [{}, {}] and _matches(replay, {"phase": "guessing", "picks": ["", ""], "target": -1, "guesses": [-1, -1]}), "Rejoin retains neither the prior reveal, hero choices, terrain nor cooldowns")
	draft_random.seed = 127
	var replay_target: int = draft_random.randi_range(0, 100)
	var tie_winner: int = draft_random.randi_range(0, 1)
	await _command("host", {"action": "guess", "value": 50})
	await _command("guest", {"action": "guess", "value": 50})
	await _settle()
	var tied: Dictionary = _snapshot("guest")["commander_draft"]
	_check(tied == _snapshot("host")["commander_draft"] and tied["target"] == replay_target and tied["first_picker"] == tie_winner and tied["picker"] == tie_winner, "A real-peer equal-distance replay reveals exactly the host's fresh coin-flip winner")
	await _finish()


func _terrain_and_clears(initial: Dictionary) -> void:
	var host_state: Dictionary = initial["commanders"][0]
	var guest_state: Dictionary = initial["commanders"][1]
	for lane: String in ["host", "guest"]:
		var slot: int = 0 if lane == "host" else 1
		var state: Dictionary = initial["commanders"][slot]
		for raw: Variant in [state["landmark"], state["obstacles"][0]]:
			var cell: Vector2i = _cell(raw)
			await _edit(lane, slot, cell.x, cell.y)
			await _build(lane, slot, cell.x, cell.y, 0)
	_check(await _settle() == initial and _snapshot("guest")["boards"][0]["used"] == 0 and _snapshot("host")["boards"][1]["used"] == 0, "Both actual command consumers reject path/tower overlap with authoritative landmark and obstacle cells")
	var landmark: Vector2i = _cell(guest_state["landmark"])
	await _command("guest", {"action": "obstacle", "x": landmark.x, "y": landmark.y})
	var foreign: Vector2i = _cell(host_state["obstacles"][0])
	await _command("guest", {"action": "forged", "command": "clear_obstacle", "slot": 0, "x": foreign.x, "y": foreign.y})
	_check(await _settle() == initial, "Authenticated remote slot forgery and landmark clearing cannot spend another player's Coins or remove terrain")
	var clear_cell: Vector2i = _cell(guest_state["obstacles"][0])
	await _command("guest", {"action": "obstacle", "x": clear_cell.x, "y": clear_cell.y})
	await _wait_combat("host", {"coins": [1000, 975]}, "Accepted clear charges the host's 25-Coin price rather than guest-local starting funds")
	var cleared: Dictionary = await _settle()
	_check(cleared["commanders"][0] == host_state and cleared["commanders"][1]["obstacles"].size() == 2 and not cleared["commanders"][1]["obstacles"].has(str(clear_cell)), "Only the authenticated guest's chosen obstacle disappears on both peers")
	await _command("guest", {"action": "obstacle", "x": clear_cell.x, "y": clear_cell.y})
	_check(await _settle() == cleared, "A repeated network clear cannot double-charge or remove another obstacle")
	await _build("guest", 1, clear_cell.x, clear_cell.y, 0)
	await _wait_tower("host", 1, clear_cell, 0)
	var second: Vector2i = _cell(guest_state["obstacles"][1])
	await _command("host", {"action": "balance", "slot": 1, "coins": 24})
	var poor: Dictionary = await _settle()
	await _command("guest", {"action": "tamper", "x": second.x, "y": second.y})
	await _command("guest", {"action": "obstacle", "x": second.x, "y": second.y})
	_check(await _settle() == poor, "Fake local Coins and terrain cannot turn an unaffordable clear into an accepted host purchase")
	await _command("host", {"action": "balance", "slot": 1, "coins": 1000})
	for lane: String in ["host", "guest"]:
		for x: int in range(1, 13):
			await _edit(lane, 0 if lane == "host" else 1, x, 4)
	await _wait_board("host", 1, 12, true)
	await _wait_board("guest", 0, 12, true)
	var build_cell: Vector2i = _open_attack_cell(host_state)
	await _build("host", 0, build_cell.x, build_cell.y, 0)
	var tower: Dictionary = await _wait_tower("guest", 0, build_cell, 0)
	_check(int(tower["damage"]) >= 100 and is_equal_approx(float(tower["interval"]), 1.0), "Accepted tower stats use real host resources, never guest-local damage or attack interval")
	await _command("host", {"action": "ability", "target": 0})
	var before_ready: Dictionary = await _settle()
	_check(before_ready["commanders"][0]["ability_remaining"] == 0.0, "Abilities cannot start while boards are still planning")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Host Ready is accepted without committing the guest")
	var ready: Dictionary = await _settle()
	await _command("host", {"action": "obstacle", "x": foreign.x, "y": foreign.y})
	_check(await _settle() == ready, "The committed player's paid clear is atomically locked by Ready")
	await _command("guest", {"action": "obstacle", "x": second.x, "y": second.y})
	await _wait_combat("host", {"coins": [ready["coins"][0], 975]}, "The not-yet-Ready player can still clear while the other is committed")
	await _command("guest", {"action": "ready", "value": true})
	await _wait_combat("guest", {"phase": MatchCombat.Phase.WAVE}, "Both real Ready commands start commander combat")
	var combat: Dictionary = await _settle()
	var third: Vector2i = _cell(guest_state["obstacles"][2])
	await _command("guest", {"action": "obstacle", "x": third.x, "y": third.y})
	_check(await _settle() == combat, "Combat rejects clearing through the authenticated remote command without spending Coins")


func _abilities() -> void:
	var before: Dictionary = await _settle()
	await _command("guest", {"action": "forged", "command": "ability", "slot": 0, "target": 0})
	await _command("host", {"action": "forged", "command": "ability", "slot": 1, "target": 0})
	await _command("host", {"action": "ability", "target": 1})
	_check(await _settle() == before, "Authenticated sender identity, not a claimed slot, owns each ability; Rally cannot target opposing ground")
	await _command("host", {"action": "ability", "target": 0})
	await _command("guest", {"action": "ability", "target": 0})
	var active: Dictionary = await _settle()
	_check(active["coins"] == before["coins"] and active["health"] == before["health"] and active["towers"][0].size() == before["towers"][0].size() and active["towers"][1].size() == before["towers"][1].size(), "Accepted abilities are free, never directly hurt bases and never destroy opposing towers")
	_check(is_equal_approx(float(active["towers"][0][0]["interval"]), 1.0 / 1.3) and active["commanders"][0]["ability_remaining"] == 8.0 and active["commanders"][1]["ability_remaining"] == 6.0, "Host publishes actual Rally attack rate and independent eight/six-second ability lifetimes")
	await _command("guest", {"action": "tamper"})
	await _command("guest", {"action": "ability", "target": 1})
	_check(await _settle() == active, "Zeroing a local guest cooldown cannot refresh or retarget the accepted Stasis")
	await _command("guest", {"action": "step", "delta": 100.0})
	_check(await _settle() == active, "Remote fixture clock changes cannot expire host-owned abilities or move enemies")
	await _command("host", {"action": "step", "delta": 2.0})
	var moved: Dictionary = await _settle()
	_check(not moved["enemies"][0].is_empty() and not moved["enemies"][1].is_empty(), "Actual host simulation births both board streams")
	_check(is_equal_approx(float(moved["enemies"][0][0]["progress"]), 0.12) and is_equal_approx(float(moved["enemies"][1][0]["progress"]), 0.2), "Only host Stasis movement wins over radically divergent guest-local enemy speed")
	_check(is_equal_approx(float(moved["commanders"][0]["cooldown_remaining"]), 43.0) and is_equal_approx(float(moved["commanders"][1]["ability_remaining"]), 4.0), "Both peers receive host simulation-aged ability and cooldown timers")
	await _command("host", {"action": "step", "delta": 6.5})
	var expired: Dictionary = await _settle()
	_check(expired["commanders"][0]["ability_remaining"] == 0.0 and expired["commanders"][1]["ability_remaining"] == 0.0 and is_equal_approx(float(expired["towers"][0][0]["interval"]), 1.0), "A coarse host tick crosses both ability expiries and restores real baseline attack rate")
	_check(is_equal_approx(float(expired["enemies"][0][0]["progress"]), 0.61) and is_equal_approx(float(expired["enemies"][1][0]["progress"]), 0.85), "Host integrates Stasis and ordinary post-expiry movement rather than slowing the whole coarse tick")
	await _command("host", {"action": "step", "delta": 36.499})
	var before_boundary: Dictionary = await _settle()
	_check(float(before_boundary["commanders"][0]["cooldown_remaining"]) > 0.0 and float(before_boundary["commanders"][1]["cooldown_remaining"]) > 0.0, "Both cooldowns remain unavailable immediately before 45 combat seconds")
	await _command("guest", {"action": "ability", "target": 1})
	_check(await _settle() == before_boundary, "An authenticated ability cannot reactivate even one millisecond before its actual cooldown boundary")
	await _command("host", {"action": "step", "delta": 0.001})
	var available: Dictionary = await _settle()
	_check(available["commanders"][0]["cooldown_remaining"] == 0.0 and available["commanders"][1]["cooldown_remaining"] == 0.0, "Exactly 45 simulated combat seconds reset both accepted cooldowns")
	await _command("guest", {"action": "ability", "target": 1})
	var retargeted: Dictionary = await _settle()
	_check(retargeted["commanders"][1]["ability_target"] == 1 and retargeted["commanders"][1]["ability_remaining"] == 6.0 and retargeted["commanders"][0]["ability_remaining"] == 0.0, "After real expiry the guest independently chooses its own board for the next Stasis")


func _settle() -> Dictionary:
	# Same reliable channel as gameplay commands: the host snapshot and reply
	# fence all prior guest requests before assertions, including rejections.
	_fence_token += 1
	await _command("guest", {"action": "fence", "token": _fence_token})
	await _wait_for("guest", {"fence": _fence_token}, "Host acknowledges all earlier authenticated commands")
	return await _agree("Both real peers receive the fenced authoritative commander state")


func _snapshot(lane: String) -> Dictionary:
	var result: Dictionary = super._snapshot(lane)
	var path: String = _path(lane, "commander")
	if FileAccess.file_exists(path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if extra is Dictionary:
			result.merge(extra)
	return result


func _cell(raw: Variant) -> Vector2i:
	var parts: PackedStringArray = String(raw).trim_prefix("(").trim_suffix(")").split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _open_attack_cell(state: Dictionary) -> Vector2i:
	for x: int in range(1, 4):
		var cell := Vector2i(x, 3)
		if state["landmark"] != str(cell) and not state["obstacles"].has(str(cell)):
			return cell
	# Four blocked cells cannot occupy all six candidates.
	for x: int in range(1, 4):
		var cell := Vector2i(x, 5)
		if state["landmark"] != str(cell) and not state["obstacles"].has(str(cell)):
			return cell
	_check(false, "Generated terrain retains a reachable real attack consumer")
	return Vector2i.ZERO
