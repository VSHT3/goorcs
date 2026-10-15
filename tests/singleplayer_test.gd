extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	root.add_child(planning)
	planning.start_singleplayer()
	_check(planning.active and planning.local_slot() == 0 and session.state == MultiplayerSession.State.IDLE and not root.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "Singleplayer starts locally without installing a network peer")
	var notices: Array[String] = []
	planning.feedback.connect(func(message: String) -> void: notices.append(message))
	var untouched: Dictionary = planning.combat.duplicate(true)
	for cell: Vector2i in [Vector2i(0, 4), Vector2i(13, 4), Vector2i(-1, 4), Vector2i(14, 4)]:
		planning.request_edit(0, cell, true)
		planning.request_edit(0, cell, false)
	_check(notices.is_empty() and planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0 and planning.combat == untouched, "Endpoint and out-of-bounds strokes are silent no-ops on both boards")
	planning.submit_ready(true)
	_check(not planning.locked and planning.ready_flags == [false, false], "Illegal routes cannot start a solo wave")
	planning.request_edit(1, Vector2i(1, 4), true)
	_check(planning.layouts[1].used_tiles() == 0, "Opponent remains read-only")
	planning.request_edit(0, Vector2i(1, 4), true)
	_check(planning.layouts[1].has_path(Vector2i(1, 4)), "Accepted paths mirror")
	planning.request_edit(0, Vector2i(1, 4), false)
	_check(not planning.layouts[0].has_path(Vector2i(1, 4)) and not planning.layouts[1].has_path(Vector2i(1, 4)), "Erasing mirrors")
	planning.request_edit(0, Vector2i(1, 4), true)
	planning.request_clear(0)
	_check(planning.layouts[0].used_tiles() == 1 and planning.layouts[1].used_tiles() == 1, "Initial setup rejects Clear on both mirrored boards")
	planning.request_edit(0, Vector2i(1, 4), false)
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)
	_check(planning.layouts[0].is_ready() and planning.layouts[0].route == planning.layouts[1].route, "Both routes are legal and identical")
	var initial_coins: Array = planning.combat["coins"].duplicate()
	planning.build_tower(0, Vector2i(1, 4), &"arrow_tower", 0)
	_check(planning.combat["coins"] == initial_coins and planning.combat["towers"] == [[], []], "Rejected purchases spend nothing on either board")
	planning.build_tower(0, Vector2i(2, 3), &"arrow_tower", 0)
	var own_id: int = planning.combat["towers"][0][0]["id"]
	var other_id: int = planning.combat["towers"][1][0]["id"]
	_check(own_id != other_id and planning.combat["coins"][0] == planning.combat["coins"][1] and planning.combat["coins"][0] < initial_coins[0], "Mirrored towers retain independent IDs and pay the same price")
	planning.set_targeting(0, own_id, MatchCombat.TargetMode.STRONGEST)
	planning.upgrade_tower(0, own_id, "damage")
	planning.upgrade_tower(0, own_id, "speed")
	for slot: int in range(2):
		var tower: Dictionary = planning.combat["towers"][slot][0]
		_check(tower["mode"] == MatchCombat.TargetMode.STRONGEST and tower["damage_upgraded"] and tower["speed_upgraded"], "Targeting and both upgrades mirror by cell, not tower ID")
	var upgraded_coins: Array = planning.combat["coins"].duplicate()
	planning.upgrade_tower(0, own_id, "damage")
	_check(planning.combat["coins"] == upgraded_coins, "Rejected repeat upgrade cannot spend on either board")
	planning.sell_tower(0, other_id)
	_check(planning.combat["towers"][1].size() == 1, "Opponent tower IDs cannot be used to sell")
	planning.sell_tower(0, own_id)
	_check(planning.combat["towers"] == [[], []] and planning.combat["coins"][0] == planning.combat["coins"][1] and planning.combat["coins"][0] > upgraded_coins[0], "Selling removes both counterparts and refunds both")
	planning.submit_ready(true)
	_check(planning.locked and planning.combat["phase"] == MatchCombat.Phase.WAVE, "One Ready starts both boards")
	planning.request_clear(0)
	_check(planning.layouts[0].is_ready() and planning.layouts[1].is_ready(), "Wave routes remain locked")
	planning.build_tower(0, Vector2i(0, 0), &"arrow_tower", 0)
	_check(planning.combat["towers"][0].size() == 1 and planning.combat["towers"][1].size() == 1, "Live construction mirrors during combat")
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"][0] < planning.combat["rules"]["base_health"] and planning.combat["health"][0] == planning.combat["health"][1], "Both boards simulate leaks and return to a planning break")
	_check(planning.ready_flags == [false, false], "Every new wave requires readiness again")
	planning.submit_ready(true)
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["coin_flip"], "Mirrored base destruction uses the normal terminal coin flip")
	var final_state: Dictionary = planning.combat.duplicate(true)
	planning.build_tower(0, Vector2i(4, 3), &"arrow_tower", 0)
	planning.submit_ready(true)
	planning.send_enemy(0, &"grunt")
	planning.send_enemy(1, &"grunt")
	_check(planning.combat == final_state, "Finished solo runs reject mutations")
	planning.stop_singleplayer()
	_check(not planning.active and not planning.singleplayer and not planning.is_physics_processing(), "Leaving clears solo mode and stops simulation")
	planning.start_singleplayer()
	_check(planning.layouts[0].used_tiles() == 0 and planning.combat["wave"] == 0 and planning.combat["towers"] == [[], []] and planning.combat["coins"] == initial_coins and planning.combat["income"] == [0, 0] and planning.combat["queued_sends"] == [0, 0] and not planning.combat["sends_open"], "Reopening starts a fresh match")
	planning.stop_singleplayer()
	_solo_sends(planning)
	_solo_typed_sends(planning)
	planning.queue_free()
	session.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: offline mirrored commands, enemy sends/income/delivery, ownership, transactions, waves, results, and fresh restart")
	quit(1 if failures > 0 else 0)


func _solo_sends(planning: MatchPlanning) -> void:
	# Keep send balances isolated from the preceding tower/mirroring scenario.
	var rules := CombatRules.new()
	rules.base_health = 7
	rules.starting_coins = 45
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 4
	rules.health_growth = 2
	rules.enemy_speed = 10.0
	rules.speed_growth = 0.0
	rules.spawn_interval = 0.05
	var grunt := preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
	grunt.send_cost = 20
	grunt.send_income = 2
	rules.enemy_definitions = [grunt]
	rules.send_cutoff_seconds = 0.25
	planning.combat_rules = rules
	planning.start_singleplayer()
	var before: Dictionary = planning.combat.duplicate(true)
	for slot: int in [1, -1, 2]:
		planning.send_enemy(slot, &"grunt")
	_check(planning.combat == before, "Solo sends cannot pay from the read-only opponent or an invalid slot")
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [25, 25] and planning.combat["income"] == [2, 2] and planning.combat["queued_sends"] == [1, 1] and planning.combat["enemies"] == [[], []], "Accepted planning send mirrors exactly one paid order and income gain per payer without requiring legal routes")
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [5, 5] and planning.combat["income"] == [4, 4] and planning.combat["queued_sends"] == [2, 2], "Mirrored sends spend Coins now but only accumulate future income")
	before = planning.combat.duplicate(true)
	planning.send_enemy(0, &"grunt")
	_check(planning.combat == before, "Unaffordable solo send cannot charge, grow income or mirror a free order")
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)
	planning.submit_ready(true)
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 2 and planning.combat["enemies"][1].size() == 2, "Both mirrored target queues drain onto captured routes at wave start")
	planning._physics_process(0.1)
	_check(planning.combat["spawned"] == [1, 1] and planning.combat["total"] == 1 and planning.combat["enemies"][0].size() == 3 and planning.combat["enemies"][1].size() == 3, "Sent enemies are real additional enemies, never extra regular-spawn counts")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [4, 4] and planning.combat["coins"] == [44, 44] and planning.combat["income"] == [4, 4], "Mirrored sent enemies leak on both targets and first clear pays accumulated income exactly once")
	planning.submit_ready(true)
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [24, 24] and planning.combat["income"] == [6, 6] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 1 and planning.combat["enemies"][1].size() == 1, "Early live send mirrors immediate delivery rather than queueing")
	for slot: int in range(2):
		var enemy: Dictionary = planning.combat["enemies"][slot][0]
		_check(enemy["hp"] == 6 and enemy["max_hp"] == 6, "Mirrored live sends reuse wave-scaled existing enemies")
	planning._physics_process(0.3)
	_check(planning.combat["phase"] == MatchCombat.Phase.WAVE and not planning.combat["sends_open"], "The host clock closes solo delivery at its cutoff")
	var counts: Array[int] = [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()]
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [4, 4] and planning.combat["income"] == [8, 8] and planning.combat["queued_sends"] == [1, 1] and [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()] == counts, "Late solo send mirrors paid next-wave queues without adding current enemies")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [2, 2] and planning.combat["coins"] == [52, 52] and planning.combat["income"] == [8, 8] and planning.combat["queued_sends"] == [1, 1], "Second solo clear pays recurring income again and preserves late delivery")
	planning.submit_ready(true)
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 1 and planning.combat["enemies"][1].size() == 1, "Late mirrored queues deliver at the next wave start")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["health"] == [0, 0] and planning.combat["coins"] == [52, 52] and planning.combat["income"] == [8, 8] and planning.combat["coin_flip"], "Mirrored send pressure reaches the normal terminal coin flip with no terminal income payout")
	before = planning.combat.duplicate(true)
	planning.send_enemy(0, &"grunt")
	planning.send_enemy(1, &"grunt")
	planning.submit_ready(true)
	_check(planning.combat == before, "Finished solo sends cannot spend remaining affordable Coins, gain income, create enemies or reroll")
	planning.stop_singleplayer()
	planning.start_singleplayer()
	_check(planning.combat["wave"] == 0 and planning.combat["health"] == [7, 7] and planning.combat["coins"] == [45, 45] and planning.combat["income"] == [0, 0] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"] == [[], []] and not planning.combat["sends_open"] and planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Restart clears mirrored send income, deliveries, enemies, health, routes and currency")
	planning.stop_singleplayer()


func _advance_send_wave(planning: MatchPlanning) -> void:
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break


func _solo_typed_sends(planning: MatchPlanning) -> void:
	var rules := CombatRules.new()
	rules.base_health = 11
	rules.starting_coins = 200
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 4
	rules.health_growth = 2
	rules.enemy_speed = 10.0
	rules.speed_growth = 0.0
	rules.spawn_interval = 0.05
	rules.send_cutoff_seconds = 0.25
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.enemy_definitions:
		definitions.append(source.duplicate() as EnemyDefinition)
	rules.enemy_definitions = definitions
	planning.combat_rules = rules
	planning.start_singleplayer()
	var before: Dictionary = planning.combat.duplicate(true)
	for type_id: StringName in [&"runner", &"brute"]:
		for slot: int in [1, -1, 2]:
			planning.send_enemy(slot, type_id)
	planning.send_enemy(0, &"missing_enemy")
	_check(planning.combat == before, "Typed solo ownership and unknown IDs cannot spend, gain income, queue or mirror an enemy")
	planning.send_enemy(0, &"runner")
	_check(planning.combat["coins"] == [175, 175] and planning.combat["income"] == [2, 2] and planning.combat["send_queues"] == [["runner"], ["runner"]], "Runner acceptance mirrors the same type and independently pays both validators")
	planning.send_enemy(0, &"brute")
	_check(planning.combat["coins"] == [135, 135] and planning.combat["income"] == [6, 6] and planning.combat["send_queues"] == [["runner", "brute"], ["runner", "brute"]], "Brute acceptance adds its distinct cost/income and preserves each mixed target queue")
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)
	planning.submit_ready(true)
	_check_solo_enemy_types(planning, ["runner", "brute"], 4, "Planning sends deliver identical types, not Grunt mirror defaults")
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["send_queues"] == [[], []], "Both mixed solo queues drain once")
	planning._physics_process(0.1)
	_check_solo_enemy_types(planning, ["runner", "brute", "grunt"], 4, "Regular spawn remains baseline Grunt")
	for slot: int in range(2):
		var enemies: Array = planning.combat["enemies"][slot]
		_check(is_equal_approx(float(enemies[0]["progress"]), 1.7) and is_equal_approx(float(enemies[1]["progress"]), 0.65) and is_equal_approx(float(enemies[2]["progress"]), 1.0), "Actual mirrored movement advances Runner, Brute and Grunt independently")
	_advance_solo_health(planning, [10, 10])
	_check_solo_enemy_types(planning, ["brute", "grunt"], 4, "Runner actually leaks before the others")
	_advance_solo_health(planning, [9, 9])
	_check_solo_enemy_types(planning, ["brute"], 4, "Baseline Grunt leaks while Brute still travels")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [6, 6] and planning.combat["coins"] == [176, 176], "Both Brutes leak three damage and typed recurring income pays with one clear")
	planning.submit_ready(true)
	planning.send_enemy(0, &"runner")
	planning.send_enemy(0, &"brute")
	_check_solo_enemy_types(planning, ["runner", "brute"], 6, "Early live typed sends use current-wave scaled HP")
	_check(planning.combat["coins"] == [111, 111] and planning.combat["income"] == [12, 12] and planning.combat["send_queues"] == [[], []], "Both live mirrored types pay exactly once without queueing")
	planning._physics_process(0.3)
	_check(not planning.combat["sends_open"], "Normal solo host clock closes typed immediate delivery")
	var counts: Array[int] = [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()]
	planning.send_enemy(0, &"brute")
	planning.send_enemy(0, &"runner")
	_check(planning.combat["coins"] == [46, 46] and planning.combat["income"] == [18, 18] and planning.combat["send_queues"] == [["brute", "runner"], ["brute", "runner"]] and [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()] == counts, "Cutoff preserves mixed typed next-wave order without adding live enemies")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [1, 1] and planning.combat["coins"] == [104, 104] and planning.combat["send_queues"] == [["brute", "runner"], ["brute", "runner"]], "Second clear repeats accumulated income and retains both deferred typed orders")
	planning.submit_ready(true)
	_check_solo_enemy_types(planning, ["brute", "runner"], 8, "Deferred mixed sends retain type/order and use next-wave scaled HP")
	_check(planning.combat["send_queues"] == [[], []] and planning.combat["queued_sends"] == [0, 0], "Next-wave delivery drains mixed queues and HUD totals together")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["health"] == [0, 0] and planning.combat["coin_flip"] and planning.combat["coins"] == [104, 104], "Typed mirrored pressure reaches the normal terminal result without clear income")
	before = planning.combat.duplicate(true)
	for type_id: StringName in [&"runner", &"brute", &"missing_enemy"]:
		planning.send_enemy(0, type_id)
		planning.send_enemy(1, type_id)
	_check(planning.combat == before, "Terminal typed sends cannot spend affordable Coins, create enemies, grow income or mirror")
	planning.stop_singleplayer()
	planning.start_singleplayer()
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["wave"] == 0 and planning.combat["health"] == [11, 11] and planning.combat["coins"] == [200, 200] and planning.combat["income"] == [0, 0] and planning.combat["send_queues"] == [[], []] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"] == [[], []] and not planning.combat["sends_open"], "Solo restart clears both typed queues, income, enemies, health and cutoff")
	for type_id: StringName in [&"brute", &"brute", &"brute", &"brute", &"runner"]:
		planning.send_enemy(0, type_id)
	_check(planning.combat["coins"] == [15, 15] and planning.combat["income"] == [18, 18], "Typed affordability setup independently pays each mirror")
	before = planning.combat.duplicate(true)
	for type_id: StringName in [&"runner", &"brute"]:
		planning.send_enemy(0, type_id)
	_check(planning.combat == before, "Neither unaffordable type can spend, gain income, queue or create a free mirrored order")
	planning.stop_singleplayer()


func _advance_solo_health(planning: MatchPlanning, expected: Array) -> void:
	for tick: int in range(600):
		if planning.combat["health"] == expected or planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break
		planning._physics_process(1.0 / 60.0)
	_check(planning.combat["health"] == expected, "Independent typed leaks reach health %s rather than moving every type at baseline speed" % [expected])


func _check_solo_enemy_types(planning: MatchPlanning, expected: Array, wave_health: int, description: String) -> void:
	var ids: Array[int] = []
	for slot: int in range(2):
		var identities: Array[String] = []
		for enemy: Dictionary in planning.combat["enemies"][slot]:
			var type_id: String = enemy.get("type_id", "")
			identities.append(type_id)
			var hp_multiplier: float = 0.6 if type_id == "runner" else (2.5 if type_id == "brute" else 1.0)
			var speed_multiplier: float = 1.7 if type_id == "runner" else (0.65 if type_id == "brute" else 1.0)
			_check(enemy["hp"] == ceili(wave_health * hp_multiplier) and enemy["max_hp"] == ceili(wave_health * hp_multiplier) and is_equal_approx(float(enemy.get("speed", 0.0)), 10.0 * speed_multiplier), "%s: %s has typed HP and speed on mirror %d" % [description, type_id, slot])
			_check(not int(enemy["id"]) in ids, "Mirrored typed enemies retain independent authoritative IDs")
			ids.append(int(enemy["id"]))
		_check(identities == expected, "%s: mirror %d has ordered types %s" % [description, slot, identities])
