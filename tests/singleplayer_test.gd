extends SceneTree

const DRAFT_FIXTURE = preload("res://tests/commander_fixture_worker.gd")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _classic_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.roll_rules = null
	rules.catalog.towers = [
		preload("res://resources/combat/towers/arrow_tower.tres").duplicate(true) as TowerDefinition,
		preload("res://resources/combat/towers/orc_ballista.tres").duplicate(true) as TowerDefinition,
		preload("res://resources/combat/towers/rune_obelisk.tres").duplicate(true) as TowerDefinition,
	]
	return rules


func _run() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	# Isolate mirrored lifecycle from the shipped randomized horde composition.
	var rules: CombatRules = _classic_rules()
	rules.base_health = 10
	var grunt: EnemyDefinition = preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
	grunt.send_first_wave = 1
	rules.catalog.enemies = [grunt]
	planning.combat_rules = rules
	root.add_child(planning)
	planning.start_singleplayer()
	_check(planning.selecting_loadout and not planning.active, "Singleplayer opens explicit loadout selection before board admission")
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Solo fixture completes a fresh hero draft and commits its three tested identities")
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
	planning.build_tower(0, DRAFT_FIXTURE.free_cell(planning, Vector2i(2, 3), 3), &"arrow_tower", 0)
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
	planning.build_tower(0, DRAFT_FIXTURE.free_cell(planning, Vector2i(0, 0), 0), &"arrow_tower", 0)
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
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Reopening requires a fresh hero draft and chosen loadout")
	_check(planning.layouts[0].used_tiles() == 0 and planning.combat["wave"] == 0 and planning.combat["towers"] == [[], []] and planning.combat["coins"] == initial_coins and planning.combat["income"] == [0, 0] and planning.combat["queued_sends"] == [0, 0], "Reopening starts a fresh match")
	planning.stop_singleplayer()
	_solo_sends(planning)
	_solo_typed_sends(planning)
	_solo_specials(planning)
	_solo_last_targeting(planning)
	_solo_footprints(planning)
	planning.queue_free()
	session.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: offline mirrored commands, enemy sends/income/delivery, ownership, transactions, waves, results, and fresh restart")
	quit(1 if failures > 0 else 0)


func _solo_footprints(planning: MatchPlanning) -> void:
	var rules: CombatRules = _classic_rules()
	rules.roll_rules = preload("res://resources/combat/tower_rolls.tres")
	rules.starting_coins = 10000
	rules.catalog.towers.append(preload("res://resources/combat/towers/orcapult.tres").duplicate(true) as TowerDefinition)
	planning.combat_rules = rules
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"orcapult", &"arrow_tower"]) and planning.commit_loadout(), "Footprint fixture admits the real commander terrain and Orcapult loadout")
	var cell := Vector2i(-1, -1)
	for y: int in range(planning.layouts[0].dimensions.y):
		for x: int in range(planning.layouts[0].dimensions.x - 1):
			var candidate := Vector2i(x, y)
			if planning._build_layout_clear(0, candidate, Vector2i(2, 1)) and planning._build_layout_clear(1, candidate, Vector2i(2, 1)):
				cell = candidate
				break
		if cell.x >= 0:
			break
	_check(cell.x >= 0, "Generated terrain leaves common legal two-tile building ground")
	if cell.x < 0:
		planning.stop_singleplayer()
		return
	var second: Vector2i = cell + Vector2i.RIGHT
	_check(planning._host_layouts[1].place(second), "Counterpart-only second-tile path fixture places")
	planning._publish_snapshot()
	var before: Dictionary = planning._host_combat.snapshot()
	var random_state: int = planning._host_combat._roll_random.state
	_check(not planning._apply_tower_command(1, "build", 0, cell, -1, 0, "orcapult") and planning._host_combat.snapshot() == before and planning._host_combat._roll_random.state == random_state, "Solo prevalidates every mirrored path cell before either purchase or RNG draw")
	_check(not planning._apply_tower_command(2, "build", 1, cell, -1, 0, "orcapult") and planning._host_combat.snapshot() == before and planning._host_combat._roll_random.state == random_state, "The ordinary authoritative command consumer rejects a non-anchor path cell too")
	planning._host_layouts[1].erase(second)
	# A smaller counterpart board exercises its own bounds rather than assuming symmetry.
	var original_dimensions: Vector2i = planning._host_layouts[1].dimensions
	planning._host_layouts[1].dimensions.x = second.x
	_check(not planning._apply_tower_command(1, "build", 0, cell, -1, 0, "orcapult") and planning._host_combat.snapshot() == before and planning._host_combat._roll_random.state == random_state, "Mirrored layout bounds reject a footprint before the first board mutates")
	planning._host_layouts[1].dimensions = original_dimensions
	_check(not planning._apply_tower_command(1, "build", 0, Vector2i(original_dimensions.x - 1, 0), -1, 0, "orcapult") and planning._host_combat.snapshot() == before and planning._host_combat._roll_random.state == random_state, "The host rejects a partial two-tile footprint at the outer board edge")
	_check(planning._apply_tower_command(1, "build", 0, cell, -1, 0, "orcapult"), "Both clear footprints admit one atomic mirrored purchase")
	for slot: int in range(2):
		_check(planning.combat["towers"][slot].size() == 1 and planning.combat["towers"][slot][0]["footprint"] == Vector2i(2, 1) and planning._host_combat.has_tower(slot, second), "Published solo towers retain the full occupied rectangle on each board")
	before = planning._host_combat.snapshot()
	random_state = planning._host_combat._roll_random.state
	planning.request_edit(0, second, true)
	_check(not planning.layouts[0].has_path(second) and not planning.layouts[1].has_path(second) and planning._host_combat.snapshot() == before, "Path editing cannot cross either tower's non-anchor tile")
	_check(not planning._apply_tower_command(1, "build", 0, second, -1, 0, "arrow_tower") and planning._host_combat.snapshot() == before and planning._host_combat._roll_random.state == random_state, "Solo overlap rejection neither spends nor rerolls on either board")
	var tower_id: int = planning.combat["towers"][0][0]["id"]
	planning.sell_tower(0, tower_id)
	_check(planning.combat["towers"] == [[], []] and not planning._host_combat.has_tower(0, second) and not planning._host_combat.has_tower(1, second), "One tower-ID sale frees both full mirrored footprints")
	planning.request_edit(0, second, true)
	_check(planning.layouts[0].has_path(second) and planning.layouts[1].has_path(second), "Former second tiles become editable after mirrored sale")
	planning.stop_singleplayer()


func _solo_last_targeting(planning: MatchPlanning) -> void:
	for count: int in [2, 4, 8, 1]:
		var rules: CombatRules = _classic_rules()
		rules.starting_coins = 10000
		rules.enemy_health = 400
		rules.health_growth = 0
		rules.enemy_speed = 1.0
		rules.speed_growth_fraction = 0.0
		rules.wave_weight = 3
		rules.spawn_interval = 0.02
		rules.spawn_jitter_ratio = 0.0
		var grunt := preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
		rules.catalog.enemies = [grunt]
		rules.catalog.towers[0].range_cells = 20.0
		# The owner's public snapshot publishes every 0.1 seconds. Keep even
		# the paid minigun interval longer than that first observation window.
		rules.catalog.towers[0].interval = 10.0
		planning.combat_rules = rules
		planning.start_singleplayer()
		_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Shared-targeting fixture completes its draft and commits its tested identities")
		planning.build_tower(0, DRAFT_FIXTURE.free_cell(planning, Vector2i(2, 3), 3), &"arrow_tower", MatchCombat.TargetMode.LAST)
		var id: int = planning.combat["towers"][0][0]["id"]
		var opponent_id: int = planning.combat["towers"][1][0]["id"]
		_check(id != opponent_id, "Accepted Last build mirrors by cell to independent tower IDs")
		var upgrades: Array[String] = ["damage", "speed", "special"]
		if count in [4, 8, 1]:
			upgrades.append("four_archers")
		if count in [8, 1]:
			upgrades.append("eight_archers")
		if count == 1:
			upgrades.append("arrow_minigun")
		var prices: Dictionary = {"damage": 30, "speed": 45, "special": 200, "four_archers": 650, "eight_archers": 800, "arrow_minigun": 1600}
		for upgrade: String in upgrades:
			var before: Array = planning.combat["coins"].duplicate()
			planning.upgrade_tower(0, id, upgrade)
			for slot: int in range(2):
				var tower: Dictionary = planning.combat["towers"][slot][0]
				_check(planning.combat["coins"][slot] == before[slot] - prices[upgrade] and tower["mode"] == MatchCombat.TargetMode.LAST, "Each mirrored paid upgrade preserves the one accepted policy and charges its real price: %s" % upgrade)
		planning.set_targeting(0, id, MatchCombat.TargetMode.STRONGEST)
		for slot: int in range(2):
			_check(planning.combat["towers"][slot][0]["mode"] == MatchCombat.TargetMode.STRONGEST, "The real validated targeting command updates both evolved towers")
		planning.set_targeting(0, id, MatchCombat.TargetMode.LAST)
		var frozen: Dictionary = planning.combat.duplicate(true)
		planning.set_targeting(1, opponent_id, MatchCombat.TargetMode.CLOSEST)
		planning.set_targeting(0, opponent_id, MatchCombat.TargetMode.CLOSEST)
		for mode: int in [-1, MatchCombat.TargetMode.LAST + 1]:
			planning.set_targeting(0, id, mode)
		planning.upgrade_tower(0, id, upgrades.back())
		_check(planning.combat == frozen, "Shared targeting grants no opponent authority; invalid modes and repeat paid upgrades reject atomically")
		for x: int in range(1, 13):
			planning.request_edit(0, Vector2i(x, 4), true)
		planning.submit_ready(true)
		_check(planning.locked and planning.combat["phase"] == MatchCombat.Phase.WAVE and planning.combat["wave_roster"] == ["grunt", "grunt", "grunt"], "Shared-targeting fixture admits exactly three real grunts on both legal routes")
		# Stage the ordinary first volley after all real births; keep the rotary
		# gun's due-at-start case separate so targeting, not spawn cadence, is tested.
		if count > 1:
			for board: Array in planning._host_combat.towers:
				board[0]["cooldown"] = 0.1
		planning._physics_process(0.1)
		for slot: int in range(2):
			var tower: Dictionary = planning.combat["towers"][slot][0]
			var ranked: Array = planning.combat["enemies"][slot].duplicate()
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if float(a["progress"]) == float(b["progress"]): return int(a["id"]) < int(b["id"])
				return float(a["progress"]) < float(b["progress"])
			)
			_check(ranked.size() == 3 and float(ranked[0]["progress"]) < float(ranked[1]["progress"]) and float(ranked[1]["progress"]) < float(ranked[2]["progress"]), "Mirrored volleys have three surviving, differently progressed real enemies")
			var streams: Array = [{"shot": tower["shot"], "aim": tower["aim"], "target_id": tower["target_id"]}]
			if count > 1:
				streams.append({"shot": tower["secondary_shot"], "aim": tower["secondary_aim"], "target_id": tower["secondary_target_id"]})
			else:
				_check(tower["secondary_shot"] == 0 and tower["secondary_target_id"] == -1, "Minigun retires the second independent firing stream")
			streams.append_array(tower["extra_archers"])
			_check(tower["mode"] == MatchCombat.TargetMode.LAST and streams.size() == count, "All 2/4/8 archers and the merged minigun retain one tower policy")
			var expected_hits: Dictionary = {}
			for index: int in range(streams.size()):
				# The rotary gun releases at tick start, before later births;
				# ordinary archer volleys select all streams at tick end.
				var expected: Dictionary = ranked.back() if count == 1 else (ranked[index] if index < ranked.size() else ranked[0])
				var expected_aim: Vector2 = Vector2(0, 4) if count == 1 else expected["pos"]
				var stream: Dictionary = streams[index]
				_check(stream["shot"] == 1 and stream["target_id"] == expected["id"] and stream["aim"] == expected_aim, "Each mirrored %d-stream volley captures its host-timed Last shot/aim/ID, distinct-first before shared fallback" % count)
				expected_hits[expected["id"]] = int(expected_hits.get(expected["id"], 0)) + 1
			for enemy: Dictionary in ranked:
				var hits: int = int(expected_hits.get(enemy["id"], 0))
				_check(enemy["max_hp"] == 400 and enemy["hp"] == 400 - hits * int(tower["damage"]), "Mirrored real attacks apply exactly the shared-policy ranked volley damage, including repeated fallback hits")
			_check(tower["damage_dealt"] == count * int(tower["damage"]) and tower["kills"] == 0, "Each mirrored paid tier deals its real volley damage without clearing the fixture")
		planning.stop_singleplayer()


func _solo_specials(planning: MatchPlanning) -> void:
	var rules: CombatRules = _classic_rules()
	rules.starting_coins = 3000
	planning.combat_rules = rules
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Special-upgrade fixture completes its draft and commits its tested identities")
	var x: int = 2
	for choice: Dictionary in [
		{"type": &"arrow_tower", "upgrade": "special"},
		{"type": &"orc_ballista", "upgrade": "pierce"},
		{"type": &"orc_ballista", "upgrade": "bounce"},
		{"type": &"rune_obelisk", "upgrade": "boulders"},
		{"type": &"rune_obelisk", "upgrade": "onyx_ring"},
	]:
		var type_id: StringName = choice["type"]
		var upgrade: String = choice["upgrade"]
		planning.build_tower(0, DRAFT_FIXTURE.free_cell(planning, Vector2i(x, 3), 3), type_id, 0)
		var id: int = planning.combat["towers"][0].back()["id"]
		var before: Dictionary = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, upgrade)
		_check(planning.combat == before, "Solo special stays locked before both base upgrades")
		planning.upgrade_tower(0, id, "speed")
		before = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, upgrade)
		_check(planning.combat == before, "One purchased stat is not enough to unlock a solo special")
		planning.upgrade_tower(0, id, "damage")
		planning.upgrade_tower(0, id, upgrade)
		for slot: int in range(2):
			var tower: Dictionary = planning.combat["towers"][slot].back()
			_check(tower["special_upgraded"] and MatchCombat.tower_level(tower) == 4, "Accepted specials mirror to level IV through the same validator")
			if type_id == &"rune_obelisk":
				_check(tower["evolution"] == upgrade, "The chosen Rune branch mirrors to both owners")
		_check(planning.combat["coins"][0] == planning.combat["coins"][1], "Mirrored special prices debit each owner equally")
		if type_id == &"rune_obelisk":
			before = planning.combat.duplicate(true)
			planning.upgrade_tower(0, id, "onyx_ring" if upgrade == "boulders" else "boulders")
			_check(planning.combat == before, "Mirrored Rune evolution cannot switch branches or spend again")
		if type_id == &"orc_ballista":
			before = planning.combat.duplicate(true)
			planning.upgrade_tower(0, id, "bounce" if upgrade == "pierce" else "pierce")
			planning.upgrade_tower(0, id, "special")
			_check(planning.combat == before, "Mirrored Ballista choice cannot switch branches or use the obsolete generic special")
			for slot: int in range(2):
				_check(planning.combat["towers"][slot].back()["evolution"] == upgrade, "Ballista branch choice mirrors through host validation")
		if upgrade == "boulders":
			planning.upgrade_tower(0, id, "freeze_runes")
			for slot: int in range(2):
				var tower: Dictionary = planning.combat["towers"][slot].back()
				_check(tower["freeze_upgraded"] and MatchCombat.tower_level(tower) == 5, "Boulders follow-up mirrors Freeze Runes and level V")
			_check(planning.combat["coins"][0] == planning.combat["coins"][1], "Mirrored Freeze Runes purchases charge each owner equally")
		elif upgrade == "onyx_ring":
			before = planning.combat.duplicate(true)
			planning.upgrade_tower(0, id, "freeze_runes")
			_check(planning.combat == before, "Onyx cannot buy the Boulders follow-up")
		if type_id == &"arrow_tower":
			planning.set_targeting(0, id, MatchCombat.TargetMode.STRONGEST)
			for slot: int in range(2):
				var tower: Dictionary = planning.combat["towers"][slot].back()
				_check(tower["mode"] == MatchCombat.TargetMode.STRONGEST, "Second Archer shares its tower's one mirrored accepted policy")
		x += 2
	planning.stop_singleplayer()


func _solo_sends(planning: MatchPlanning) -> void:
	# Keep send balances isolated from the preceding tower/mirroring scenario.
	var rules: CombatRules = _classic_rules()
	rules.base_health = 7
	rules.starting_coins = 45
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 4
	rules.health_growth = 2
	rules.enemy_speed = 10.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.05
	var grunt := preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
	grunt.send_cost = 20
	grunt.send_income = 2
	grunt.send_first_wave = 1
	rules.catalog.enemies = [grunt]
	rules.send_spawn_interval = 0.35
	planning.combat_rules = rules
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Send fixture completes its hero draft and commits its loadout before board commands")
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
	_check(planning.combat["queued_sends"] == [1, 1] and planning.combat["enemies"][0].size() == 1 and planning.combat["enemies"][1].size() == 1, "Wave start delivers only the first mirrored order and retains both FIFO tails")
	planning._physics_process(0.1)
	_check(planning.combat["spawned"] == [1, 1] and planning.combat["total"] == 1 and planning.combat["queued_sends"] == [1, 1] and planning.combat["enemies"][0].size() == 2 and planning.combat["enemies"][1].size() == 2, "Ordinary delivery runs concurrently without consuming the pending send or extra regular-spawn counts")
	planning._physics_process(0.25)
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 3 and planning.combat["enemies"][1].size() == 3, "Each mirrored stream delivers its second order at the host interval")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [4, 4] and planning.combat["coins"] == [44, 44] and planning.combat["income"] == [4, 4], "Mirrored sent enemies leak on both targets and first clear pays accumulated income exactly once")
	planning.submit_ready(true)
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [24, 24] and planning.combat["income"] == [6, 6] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 1 and planning.combat["enemies"][1].size() == 1, "Early live send mirrors immediate delivery rather than queueing")
	for slot: int in range(2):
		var enemy: Dictionary = planning.combat["enemies"][slot][0]
		_check(enemy["hp"] == 6 and enemy["max_hp"] == 6, "Mirrored live sends reuse wave-scaled existing enemies")
	planning._physics_process(0.3)
	var counts: Array[int] = [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()]
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [4, 4] and planning.combat["income"] == [8, 8] and planning.combat["queued_sends"] == [1, 1] and [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()] == counts, "Cooldown acceptance atomically pays and mirrors pending current-combat orders without early delivery")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [1, 1] and planning.combat["coins"] == [52, 52] and planning.combat["income"] == [8, 8] and planning.combat["queued_sends"] == [0, 0], "Second solo clear waits for all three leaks and pays recurring income again without deferred deliveries")
	planning.send_enemy(0, &"grunt")
	_check(planning.combat["coins"] == [32, 32] and planning.combat["income"] == [10, 10] and planning.combat["queued_sends"] == [1, 1], "A post-clear purchase stays pending until the next manual Ready")
	planning.submit_ready(true)
	_check(planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"][0].size() == 1 and planning.combat["enemies"][1].size() == 1, "Planning purchases deliver at the next wave start")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["health"] == [0, 0] and planning.combat["coins"] == [32, 32] and planning.combat["income"] == [10, 10] and planning.combat["coin_flip"], "Mirrored send pressure reaches the normal terminal coin flip with no terminal income payout")
	before = planning.combat.duplicate(true)
	planning.send_enemy(0, &"grunt")
	planning.send_enemy(1, &"grunt")
	planning.submit_ready(true)
	_check(planning.combat == before, "Finished solo sends cannot spend remaining affordable Coins, gain income, create enemies or reroll")
	planning.stop_singleplayer()
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Send restart completes a fresh draft and commits a fresh deck")
	_check(planning.combat["wave"] == 0 and planning.combat["health"] == [7, 7] and planning.combat["coins"] == [45, 45] and planning.combat["income"] == [0, 0] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"] == [[], []] and planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Restart clears mirrored send income, deliveries, enemies, health, routes and currency")
	planning.stop_singleplayer()


func _advance_send_wave(planning: MatchPlanning) -> void:
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break


func _solo_typed_sends(planning: MatchPlanning) -> void:
	var rules: CombatRules = _classic_rules()
	rules.base_health = 16
	rules.starting_coins = 200
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 4
	rules.health_growth = 2
	rules.enemy_speed = 10.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.05
	rules.send_spawn_interval = 0.35
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		if source.id in [&"grunt", &"runner", &"brute"]:
			var enemy := source.duplicate() as EnemyDefinition
			enemy.send_first_wave = 1
			definitions.append(enemy)
	rules.catalog.enemies = definitions
	planning.combat_rules = rules
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Typed-send fixture completes its draft and commits its tested identities")
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
	_check_solo_enemy_types(planning, ["runner"], 4, "Planning sends start with the FIFO head, not Grunt mirror defaults")
	_check(planning.combat["queued_sends"] == [1, 1] and planning.combat["send_queues"] == [["brute"], ["brute"]], "Both mixed solo queues retain their pending tail")
	planning._physics_process(0.45)
	_check_solo_enemy_types(planning, ["runner", "grunt", "brute"], 4, "Ordinary Grunts and paced typed sends share the captured route")
	for slot: int in range(2):
		var enemies: Array = planning.combat["enemies"][slot]
		_check(is_equal_approx(float(enemies[0]["progress"]), 7.65) and is_equal_approx(float(enemies[1]["progress"]), 4.5) and is_equal_approx(float(enemies[2]["progress"]), 0.65), "Mirrored movement uses each type's actual speed and fractional travel since its own delivery")
	_advance_solo_health(planning, [15, 15])
	_check_solo_enemy_types(planning, ["grunt", "brute"], 4, "Runner actually leaks before the others")
	_advance_solo_health(planning, [14, 14])
	_check_solo_enemy_types(planning, ["brute"], 4, "Baseline Grunt leaks while Brute still travels")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [11, 11] and planning.combat["coins"] == [176, 176], "Both Brutes leak three damage and typed recurring income pays with one clear")
	planning.submit_ready(true)
	planning.send_enemy(0, &"runner")
	planning.send_enemy(0, &"brute")
	_check_solo_enemy_types(planning, ["runner"], 6, "The early live FIFO head uses current-wave scaled HP")
	_check(planning.combat["coins"] == [111, 111] and planning.combat["income"] == [12, 12] and planning.combat["send_queues"] == [["brute"], ["brute"]], "Both live mirrored types pay exactly once while only the first is due")
	planning._physics_process(0.3)
	var counts: Array[int] = [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()]
	planning.send_enemy(0, &"brute")
	planning.send_enemy(0, &"runner")
	_check(planning.combat["coins"] == [46, 46] and planning.combat["income"] == [18, 18] and planning.combat["send_queues"] == [["brute", "brute", "runner"], ["brute", "brute", "runner"]] and [planning.combat["enemies"][0].size(), planning.combat["enemies"][1].size()] == counts, "Live orders append after the paid pending type without bypassing its cooldown or FIFO position")
	planning._physics_process(0.8)
	_check_solo_enemy_types(planning, ["grunt", "brute", "brute", "runner"], 6, "Mixed orders deliver in their purchase combat with current-wave HP after the first Runner has already leaked")
	_check(planning.combat["send_queues"] == [[], []] and planning.combat["queued_sends"] == [0, 0], "Concurrent delivery drains mixed queues and HUD totals together")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"] == [2, 2] and planning.combat["coins"] == [104, 104] and planning.combat["send_queues"] == [[], []], "Second clear repeats accumulated income only after all typed current-combat deliveries leak")
	planning.send_enemy(0, &"brute")
	planning.submit_ready(true)
	_check_solo_enemy_types(planning, ["brute"], 8, "New planning sends use the next delivery wave's scaled HP")
	_advance_send_wave(planning)
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["health"] == [0, 0] and planning.combat["coin_flip"] and planning.combat["coins"] == [64, 64], "Typed mirrored pressure reaches the normal terminal result without clear income")
	before = planning.combat.duplicate(true)
	for type_id: StringName in [&"runner", &"brute", &"missing_enemy"]:
		planning.send_enemy(0, type_id)
		planning.send_enemy(1, type_id)
	_check(planning.combat == before, "Terminal typed sends cannot spend affordable Coins, create enemies, grow income or mirror")
	planning.stop_singleplayer()
	planning.start_singleplayer()
	_check(DRAFT_FIXTURE.complete_solo(planning) and planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and planning.commit_loadout(), "Typed-send restart completes a fresh draft and commits a fresh deck")
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["wave"] == 0 and planning.combat["health"] == [16, 16] and planning.combat["coins"] == [200, 200] and planning.combat["income"] == [0, 0] and planning.combat["send_queues"] == [[], []] and planning.combat["queued_sends"] == [0, 0] and planning.combat["enemies"] == [[], []], "Solo restart clears both typed queues, income, enemies and health")
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
