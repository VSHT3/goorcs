extends "res://tests/match_planning_test.gd"


func _run() -> void:
	success_message = "PASS: isolated pacing clocks, solo mirroring, legal-route autoplay, finite rewards/results, and real peer consent/ownership/shared rosters/disconnect/rejoin"
	_suite_deadline_msec = Time.get_ticks_msec() + 90000
	_test_solo_autoplay()
	_test_simulation_clock()
	_directory = OS.get_temp_dir().path_join("goorcs_pacing_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	planning_worker_path = "res://tests/match_pacing_worker.gd"
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	await _test_peer_pacing(port)
	await _finish()


func _model_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 4
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.health_growth = 0
	rules.speed_growth = 0.0
	rules.enemy_speed = 26.0
	rules.spawn_interval = 0.05
	rules.enemy_definitions = [rules.enemy_definitions[0]]
	return rules


func _new_solo(rules: CombatRules) -> MatchPlanning:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	planning.combat_rules = rules
	root.add_child(planning)
	planning.start_singleplayer()
	planning.set_physics_process(false)
	return planning


func _dispose_model(planning: MatchPlanning) -> void:
	var session: MultiplayerSession = planning.session
	planning.free()
	session.free()


func _model_route(planning: MatchPlanning) -> void:
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)


func _test_solo_autoplay() -> void:
	var planning: MatchPlanning = _new_solo(_model_rules())
	_check(planning.combat["speed_votes"] == [false, false] and planning.combat["autoplay_votes"] == [false, false] and planning.combat["speed_multiplier"] == 1.0 and not planning.combat["autoplay"], "Fresh accepted snapshots contain inactive pacing state")
	planning.request_pacing("speed", true)
	planning.request_pacing("autoplay", true)
	_check(planning.combat["speed_votes"] == [true, true] and planning.combat["autoplay_votes"] == [true, true] and planning.combat["speed_multiplier"] == 2.0 and planning.combat["autoplay"], "Solo consent mirrors both votes without an opponent UI command")
	for tick: int in range(5):
		planning._physics_process(1.0)
	_check(planning.combat["wave"] == 0 and not planning.is_physics_processing(), "Illegal routes pause autoplay without a busy restart loop")
	planning.request_edit(0, Vector2i(0, 0), true)
	_model_route(planning)
	_check(planning.combat["wave"] == 0, "A connected base is insufficient while disconnected path islands remain")
	planning.request_edit(0, Vector2i(0, 0), false)
	_check(planning.combat["wave"] == 0 and planning.can_edit_path(0) and not planning.is_physics_processing(), "A legal initial strategy still pauses autoplay for manual Ready")
	planning.submit_ready(true)
	_check(planning.combat["wave"] == 1 and planning.locked and planning.locked_routes[0] == planning.layouts[0].route and planning.locked_routes[1] == planning.layouts[1].route, "Manual initial Ready captures both legal mirrored routes")
	var initial_coins: Array = planning.combat["coins"].duplicate()
	# Mutable presentation copies must not become gameplay consent or route state.
	planning.combat["speed_votes"][0] = false
	planning.combat["autoplay_votes"][0] = false
	planning.combat["speed_multiplier"] = 99.0
	planning.combat["autoplay"] = false
	planning.locked_routes[0].clear()
	planning._physics_process(0.3)
	_check(planning.combat["wave"] == 2 and planning.combat["health"] == [3, 3] and planning.combat["speed_multiplier"] == 2.0 and planning.combat["autoplay_votes"] == [true, true], "Host-private consent survives UI mutation and immediately starts exactly one next wave on clearance")
	var first_reward: int = int(planning.combat["rules"]["wave_reward"]) - planning.combat_rules.wave_reward_growth
	_check(planning.combat["coins"][0] == initial_coins[0] + first_reward, "Autoplay awards the first surviving clear exactly once")
	planning.request_pacing("autoplay", false)
	_check(not planning.combat["autoplay"] and planning.combat["autoplay_votes"] == [false, false] and planning.combat["phase"] == MatchCombat.Phase.WAVE, "Solo withdrawal mirrors and never aborts the active wave")
	planning._physics_process(0.3)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["wave"] == 2 and planning.ready_flags == [false, false], "Disabled autoplay returns to an ordinary planning break")
	var stopped: Dictionary = planning.combat.duplicate(true)
	for tick: int in range(5):
		planning._physics_process(1.0)
	_check(planning.combat == stopped, "Stopped autoplay cannot advance or repay the same cleared wave")
	planning.submit_ready(true)
	_check(planning.combat["wave"] == 3 and planning.locked_routes[0] == planning.layouts[0].route, "Manual ready still starts through the same route capture gate")
	planning.request_pacing("autoplay", true)
	planning._physics_process(0.3)
	_check(planning.combat["wave"] == 4 and planning.combat["phase"] == MatchCombat.Phase.WAVE, "Autoplay enabled during combat resumes at the next clear")
	var before_terminal: Array = planning.combat["coins"].duplicate()
	planning._physics_process(0.3)
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["wave"] == 4 and planning.combat["coins"] == before_terminal and planning.combat["speed_votes"] == [false, false] and planning.combat["autoplay_votes"] == [false, false] and not planning.combat["autoplay"] and not planning.is_physics_processing(), "Terminal autoplay resets votes, pays no terminal clear, and stops at a finite wave")
	var finished: Dictionary = planning.combat.duplicate(true)
	planning.request_pacing("autoplay", true)
	planning.request_pacing("speed", true)
	planning.submit_ready(true)
	planning._physics_process(10.0)
	_check(planning.combat == finished, "Results reject pacing, readiness and automatic restarts")
	planning.stop_singleplayer()
	planning.request_pacing("autoplay", true)
	_check(not planning.active and planning.combat["autoplay_votes"] == [false, false], "Inactive runs cannot accumulate consent")
	planning.start_singleplayer()
	_check(planning.combat["wave"] == 0 and planning.combat["speed_votes"] == [false, false] and planning.combat["autoplay_votes"] == [false, false] and planning.layouts[0].used_tiles() == 0, "Fresh solo matches reset all consent and routes")
	_dispose_model(planning)


func _test_simulation_clock() -> void:
	var rules: CombatRules = _model_rules()
	rules.enemy_speed = 2.0
	rules.enemy_health = 1000
	rules.send_spawn_interval = 0.4
	var tower := rules.tower_definitions[0].duplicate() as TowerDefinition
	tower.damage = 1
	tower.interval = 1.0
	tower.range_cells = 50.0
	rules.tower_definitions = [tower]
	var normal: MatchPlanning = _new_solo(rules)
	var fast: MatchPlanning = _new_solo(rules)
	for planning: MatchPlanning in [normal, fast]:
		_model_route(planning)
		planning.build_tower(0, Vector2i(2, 3), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	fast.request_pacing("speed", true)
	normal.submit_ready(true)
	fast.submit_ready(true)
	for planning: MatchPlanning in [normal, fast]:
		planning.send_enemy(0, &"grunt")
		planning.send_enemy(0, &"grunt")
	var publications: Array[int] = [0, 0]
	normal.changed.connect(func() -> void: publications[0] += 1)
	fast.changed.connect(func() -> void: publications[1] += 1)
	for tick: int in range(2):
		normal._physics_process(0.04)
		fast._physics_process(0.04)
	_check(publications == [0, 0], "Neither normal nor double speed publishes before 0.1 real seconds")
	normal._physics_process(0.04)
	fast._physics_process(0.04)
	_check(publications == [1, 1], "Snapshot cadence uses real delta even when simulation delta doubles")
	var normal_enemy: Dictionary = normal.combat["enemies"][0][0]
	var fast_enemy: Dictionary = fast.combat["enemies"][0][0]
	_check(is_equal_approx(float(fast_enemy["progress"]), 2.0 * float(normal_enemy["progress"])) and fast_enemy["speed"] == normal_enemy["speed"], "Double-speed travel doubles progress without rewriting effective instance speed")
	var normal_reload: float = float(normal.combat["towers"][0][0]["cooldown"])
	var fast_reload: float = float(fast.combat["towers"][0][0]["cooldown"])
	_check(is_equal_approx(1.0 - fast_reload, 2.0 * (1.0 - normal_reload)), "Tower reload consumption shares the doubled simulation clock")
	for tick: int in range(3):
		normal._physics_process(0.04)
		fast._physics_process(0.04)
	_check(publications == [2, 2] and normal.combat["queued_sends"] == [1, 1] and fast.combat["queued_sends"] == [0, 0], "Double speed delivers the second FIFO order after 0.4 simulation seconds while network publication counts remain equal")
	_check(normal.combat["enemies"][0].size() == 2 and fast.combat["enemies"][0].size() == 3 and normal.combat["spawned"] == [1, 1] and fast.combat["spawned"] == [1, 1], "Send cadence doubles independently of unchanged regular-spawn counts")
	for tick: int in range(9):
		normal._physics_process(0.04)
		fast._physics_process(0.04)
	_check(normal.combat["towers"][0][0]["shot"] == 1 and fast.combat["towers"][0][0]["shot"] == 2, "Double-speed reload produces the next real tower attack earlier")
	fast.request_pacing("speed", false)
	_check(fast.combat["speed_multiplier"] == 1.0 and fast.combat["phase"] == MatchCombat.Phase.WAVE, "Speed may be withdrawn during live combat without changing its phase")
	_dispose_model(normal)
	_dispose_model(fast)


func _test_peer_pacing(port: int) -> void:
	await _command("host", {"action": "pacing", "option": "speed", "enabled": true})
	_check(_snapshot("host")["combat"]["speed_votes"] == [false, false], "Disconnected host cannot pre-authorize pacing")
	var host: Dictionary = await _command("host", {"action": "host", "port": port})
	var code: String = host["code"]
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"active": true}, "Peer receives active planning")
	await _pacing("host", "speed", true)
	await _wait_combat("guest", {"speed_votes": [true, false], "speed_multiplier": 1.0}, "Host alone cannot accelerate the guest")
	await _command("guest", {"action": "forged_pacing", "option": "speed", "slot": 0, "enabled": false})
	await _command("host", {"action": "forged_pacing", "option": "speed", "slot": 1, "enabled": true})
	await _command("host", {"action": "unknown_sender"})
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"]["speed_votes"] == [true, false], "Host and remote forged ownership plus unadmitted sender cannot change another vote")
	await _pacing("guest", "speed", true)
	await _wait_combat("host", {"speed_votes": [true, true], "speed_multiplier": 2.0}, "Both peers activate double speed")
	await _pacing("guest", "speed", false)
	await _wait_combat("host", {"speed_votes": [true, false], "speed_multiplier": 1.0}, "Guest withdrawal stops both without erasing host consent")
	await _pacing("host", "autoplay", true)
	await _wait_combat("guest", {"autoplay_votes": [true, false], "autoplay": false, "wave": 0}, "Unilateral autoplay remains pending")
	await _pacing("guest", "autoplay", true)
	await _wait_combat("host", {"autoplay_votes": [true, true], "autoplay": true, "wave": 0}, "Unanimous autoplay waits on illegal paths")
	await _peer_route("host", 0)
	await _wait_combat("guest", {"wave": 0}, "One legal board cannot start the other board")
	# The longer guest route leaves a visible one-board-clear interval.
	for y: int in [3, 2, 1]:
		await _edit("guest", 1, 0, y)
	for x: int in range(1, 14):
		await _edit("guest", 1, x, 1)
	await _edit("guest", 1, 13, 2)
	await _wait_combat("host", {"wave": 0}, "Incomplete guest route pauses autoplay")
	await _edit("guest", 1, 13, 3)
	await _wait_combat("host", {"wave": 0, "setup_round": true, "ready_seconds_left": -1.0}, "Complete initial routes still require manual Ready under autoplay")
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "First initial Ready remains committed without a timer")
	await _command("guest", {"action": "ready", "value": true})
	await _wait_combat("host", {"wave": 1, "phase": MatchCombat.Phase.WAVE}, "Both manual Ready votes launch initial strategy")
	await _wait_combat("guest", {"wave": 1, "phase": MatchCombat.Phase.WAVE}, "Guest receives autoplay start")
	await _pacing("guest", "speed", true)
	await _wait_combat("host", {"speed_multiplier": 2.0}, "Live unanimous speed activation is accepted")
	await _pacing("host", "speed", false)
	await _wait_combat("guest", {"speed_votes": [false, true], "speed_multiplier": 1.0}, "Host withdrawal stops both while preserving guest consent")
	await _wait_partial_clear()
	await _wait_wave("host", 2)
	await _wait_wave("guest", 2)
	await _pacing("guest", "autoplay", false)
	await _wait_combat("host", {"autoplay_votes": [true, false], "autoplay": false}, "Either peer can cancel shared autoplay in combat")
	await _wait_combat("host", {"phase": MatchCombat.Phase.PLANNING}, "Cancelled autoplay finishes the current wave and returns to planning")
	await _wait_combat("guest", {"phase": MatchCombat.Phase.PLANNING}, "Guest sees the same stopped planning state")
	var stopped_wave: int = int(_snapshot("host")["combat"]["wave"])
	await create_timer(0.25).timeout
	_check(_snapshot("host")["combat"]["wave"] == stopped_wave and _snapshot("guest")["combat"]["wave"] == stopped_wave, "Withdrawal cannot schedule another automatic restart")
	var host_rosters: Dictionary = _snapshot("host")["wave_rosters"]
	var guest_rosters: Dictionary = _snapshot("guest")["wave_rosters"]
	_check(host_rosters.has("1") and host_rosters.has("2") and host_rosters == guest_rosters, "Separate processes accept the identical ordered weighted roster for each automatic wave")
	_check(_snapshot("host")["combat"]["wave_weight"] == 12 and _snapshot("guest")["combat"]["wave_weight"] == 12, "Host weighted budget overrides guest resource defaults")
	await _pacing("guest", "autoplay", true)
	await _wait_wave("host", stopped_wave + 1)
	await _wait_wave("guest", stopped_wave + 1)
	await _pacing("host", "autoplay", false)
	await _wait_combat("guest", {"autoplay_votes": [false, true], "autoplay": false}, "Host withdrawal also stops autoplay without erasing guest consent")
	await _wait_combat("host", {"phase": MatchCombat.Phase.PLANNING}, "Host withdrawal stops future waves after this one clears")
	await _wait_combat("guest", {"phase": MatchCombat.Phase.PLANNING}, "Both peers return to the same second cancelled break")
	stopped_wave = int(_snapshot("host")["combat"]["wave"])
	await _command("host", {"action": "ready", "value": true})
	await _wait_for("guest", {"flags": [true, false]}, "Manual ready remains available after autoplay cancellation")
	await _pacing("host", "speed", true)
	await _wait_for("guest", {"flags": [true, false]}, "Speed consent does not invalidate manual readiness")
	_check(_snapshot("host")["flags"] == [true, false], "Host speed toggle preserves its accepted ready flag")
	await _command("guest", {"action": "ready", "value": true})
	await _wait_wave("guest", stopped_wave + 1)
	for lane: String in ["host", "guest"]:
		await _command(lane, {"action": "terminal_scenario"})
	await _command("guest", {"action": "leave"})
	await _wait_for("host", {"active": false}, "Disconnect resets active match")
	_check(_snapshot("host")["combat"]["speed_votes"] == [false, false] and _snapshot("host")["combat"]["autoplay_votes"] == [false, false], "Disconnect resets all host-private votes")
	await _connect_guest("guest", "host", code)
	await _wait_for("guest", {"active": true, "locked": false, "flags": [false, false]}, "Rejoin starts fresh planning")
	for lane: String in ["host", "guest"]:
		await _wait_combat(lane, {"wave": 0, "speed_votes": [false, false], "autoplay_votes": [false, false], "speed_multiplier": 1.0, "autoplay": false}, "Fresh peer session has no inherited consent")
	await _peer_route("host", 0)
	await _peer_route("guest", 1)
	var terminal_start_coins: Array = _snapshot("host")["combat"]["coins"].duplicate()
	for lane: String in ["host", "guest"]:
		await _pacing(lane, "speed", true)
		await _pacing(lane, "autoplay", true)
	await _command("host", {"action": "ready", "value": true})
	await _command("guest", {"action": "ready", "value": true})
	await _wait_combat("host", {"phase": MatchCombat.Phase.FINISHED}, "Autoplay reaches a real terminal result")
	await _wait_combat("guest", {"phase": MatchCombat.Phase.FINISHED}, "Terminal state is accepted by the guest")
	var terminal: Dictionary = _snapshot("host")["combat"].duplicate(true)
	_check(terminal["wave"] == 1 and terminal["coins"] == terminal_start_coins and terminal["speed_votes"] == [false, false] and terminal["autoplay_votes"] == [false, false] and terminal["speed_multiplier"] == 1.0 and not terminal["autoplay"], "Terminal wave has no reward or extra start and clears pacing votes; observed " + str(terminal))
	for lane: String in ["host", "guest"]:
		await _pacing(lane, "speed", true)
		await _pacing(lane, "autoplay", true)
	await create_timer(0.15).timeout
	_check(_snapshot("host")["combat"] == terminal and _snapshot("guest")["combat"] == terminal, "Results reject pacing from both real senders without mutating shared terminal state")


func _pacing(lane: String, option: String, enabled: bool) -> void:
	await _command(lane, {"action": "pacing", "option": option, "enabled": enabled})


func _peer_route(lane: String, slot: int) -> void:
	for x: int in range(1, 13):
		await _edit(lane, slot, x, 4)


func _wait_combat(lane: String, expected: Dictionary, description: String) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = _snapshot(lane).get("combat", {})
		if _matches(state, expected):
			return state
		await create_timer(0.02).timeout
	_check(false, description + "; observed " + str(_snapshot(lane)))
	return _snapshot(lane).get("combat", {})


func _wait_partial_clear() -> void:
	var deadline: int = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = _snapshot("host").get("combat", {})
		var enemies: Array = state.get("enemies", [[], []])
		if int(state.get("wave", 0)) == 1 and state.get("spawned", [0, 0])[0] == state.get("total", -1) and enemies[0].is_empty() and not enemies[1].is_empty():
			_check(state["phase"] == MatchCombat.Phase.WAVE and state["autoplay"], "Clearing only one board cannot advance the autoplay wave")
			return
		await create_timer(0.02).timeout
	_check(false, "Distinct routes expose a shared snapshot after only the host board clears")


func _wait_wave(lane: String, minimum: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		if int(_snapshot(lane).get("combat", {}).get("wave", 0)) >= minimum:
			return
		await create_timer(0.02).timeout
	_check(false, "%s reaches wave %d; observed %s" % [lane, minimum, _snapshot(lane)])


func _snapshot(lane: String) -> Dictionary:
	var result: Dictionary = super._snapshot(lane)
	var path: String = _path(lane, "pacing")
	if FileAccess.file_exists(path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if extra is Dictionary:
			result.merge(extra)
	return result
