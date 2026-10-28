extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_maximum_health_and_permanent_paw()
	_test_paw_future_mine_growth()
	_test_healing_and_overheal_carry()
	_test_sutures_actual_loss_and_clear()
	_test_dreadmaw_reserve_and_real_boss_kill()
	_test_ward_order_cap_expiry_and_rejection()
	_test_one_more_run_lifetime_and_double_leak()
	_test_stun_reducers_and_fortress()
	_test_received_slow_and_partitioning()
	_test_debug_abandon_and_new_run()
	if failures == 0:
		print("PASS: item crystal maxima, permanent Paw growth, actual healing/overheal, Sutures, boss reserves, ward/save ordering, received stuns/slows and lifecycle")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules: CombatRules = CombatRules.new()
	rules.roll_rules = null
	rules.base_health = 100
	rules.starting_coins = 1000000
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_jitter_ratio = 0.0
	return rules


func _combat(ids: Array = []) -> MatchCombat:
	var combat: MatchCombat = MatchCombat.new(_rules())
	_check(combat.set_items(0, ids), "Host accepts the complete defense fixture inventory")
	return combat


func _routes() -> Array[Dictionary]:
	var route: Array = [Vector2i(9, 0), Vector2i(8, 0), Vector2i(7, 0)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: []}
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _start(combat: MatchCombat) -> void:
	_check(combat.start_wave(_routes()), "Defense fixture enters real combat")


func _build(combat: MatchCombat, type_id: StringName, cell: Vector2i) -> Dictionary:
	_check(combat.build(0, cell, type_id, MatchCombat.TargetMode.FURTHEST), "Build defense fixture %s" % type_id)
	for tower: Dictionary in combat.towers[0]:
		if tower["cell"] == cell:
			return tower
	return {}


func _clear(combat: MatchCombat) -> void:
	_start(combat)
	for slot: int in range(2):
		combat.enemies[slot].clear()
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned = [0, 0]
	combat.advance(1.0 / 60.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING, "A genuine completed wave executes clear hooks")


func _test_maximum_health_and_permanent_paw() -> void:
	var combat: MatchCombat = _combat()
	combat.base_health[0] = 90
	_check(combat.grant_item(0, &"ironroot_bulb") and combat.base_max_health[0] == 110 and combat.base_health[0] == 90, "Bulb adds 10 maximum HP without equip healing")
	_check(combat.grant_item(0, &"troll_kings_molar") and combat.base_max_health[0] == 130 and combat.base_health[0] == 90, "Molar stacks its own 20 max HP without healing")
	_check(combat.grant_item(0, &"the_walking_fortress") and combat.base_max_health[0] == 160 and combat.base_health[0] == 90, "Fortress contributes 30 maximum HP, not free health")
	_check(combat.item_runtime.defense.heal(0, 70.0) == 70 and combat.base_health[0] == 160, "Ordinary healing reaches the item-modified maximum")
	_check(combat.set_items(0, []) and combat.base_max_health[0] == 100 and combat.base_health[0] == 100, "Removing all max-HP items clamps actual current health")
	combat.base_health[0] = 0
	_check(combat.grant_item(0, &"the_walking_fortress") and combat.base_health[0] == 0 and combat.item_runtime.defense.heal(0, 100.0) == 0, "Neither equipping health nor shared healing revives a dead base")
	combat = _combat()
	_check(combat.grant_item(0, &"monkeys_paw"), "First Paw grant succeeds")
	_check(combat.set_items(0, []) and combat.base_max_health[0] == 50 and combat.base_health[0] == 50, "Paw curse remains after removing Paw and its random reward")
	_check(combat.grant_item(0, &"ironroot_bulb") and combat.base_max_health[0] == 55 and combat.base_health[0] == 50, "Permanent Paw halves future item maximum-health gains")
	_check(combat.grant_item(0, &"monkeys_paw") and combat.item_runtime.owned_ids(0).size() == 2 and combat.base_max_health[0] == 55, "Regranting Paw neither compounds curse nor grants a second Legendary")
	combat.base_health[0] = 40
	_check(combat.item_runtime.defense.heal(0, 10.0) == 10 and combat.base_health[0] == 50, "Paw does not halve normal healing")
	_check(combat.base_max_health[1] == 100 and combat.base_health[1] == 100, "Max-HP items and Paw only alter their owner")


func _test_paw_future_mine_growth() -> void:
	var combat: MatchCombat = _combat(["monkeys_paw"])
	_check(combat.set_items(0, []), "Remove Paw reward while preserving permanent curse")
	var mine: Dictionary = _build(combat, &"gold_mine", Vector2i(1, 1))
	for command: String in ["damage", "speed", "crystal_mine", "deeper_veins", "geode_drill", "resonant_lattice", "mother_lode", "heart_of_the_mountain"]:
		_check(combat.upgrade_tower(0, int(mine["id"]), command), "Mine purchases real max-health growth branch %s" % command)
	combat.base_health[0] = 35
	_clear(combat)
	_check(combat.base_max_health[0] == 52 and combat.base_health[0] == 40 and int(mine["base_max_health_bonus"]) == 5, "Paw halves future raw mine growth once, while all five regeneration HP heal normally")
	_clear(combat)
	_check(combat.base_max_health[0] == 55 and combat.base_health[0] == 45, "Odd raw growth carries through recomputed maximum rather than losing half-HP each clear")
	_check(combat.sell_tower(0, int(mine["id"])) and combat.base_max_health[0] == 50, "Selling grown mine removes its Paw-scaled maximum contribution")


func _test_healing_and_overheal_carry() -> void:
	var combat: MatchCombat = _combat(["philosophorers_stoner"])
	var before: int = combat.coins[0]
	combat.base_health[0] = 99
	_check(combat.item_runtime.defense.heal(0, 0.5) == 0 and combat.base_health[0] == 99, "Half healing carries rather than creating a rounded-up HP")
	_check(combat.item_runtime.defense.heal(0, 1.0) == 1 and combat.base_health[0] == 100 and combat.coins[0] == before, "Actual healing fills missing HP before fractional excess conversion")
	combat.item_runtime.defense.heal(0, 0.5)
	_check(combat.coins[0] == before + 1, "Two half-overheals become exactly one actual Coin")
	_check(combat.remove_item(0, &"philosophorers_stoner"), "Stoner can be removed")
	combat.item_runtime.defense.heal(0, 0.75)
	_check(combat.coins[0] == before + 1, "Without Stoner discarded overheal does not fabricate Coins")
	_check(combat.grant_item(0, &"philosophorers_stoner"), "Stoner can be restored")
	combat.item_runtime.defense.heal(0, 0.25)
	_check(combat.coins[0] == before + 1, "Removing Stoner does not bank overheal generated while absent")
	combat.item_runtime.defense.heal(0, 0.75)
	_check(combat.coins[0] == before + 2, "Fractional conversion continues through real subsequent heal calls")
	combat.base_health[0] = 0
	combat.item_runtime.defense.heal(0, 200.0)
	_check(combat.base_health[0] == 0 and combat.coins[0] == before + 2, "Defeated base cannot revive or farm excess healing Coins")


func _test_sutures_actual_loss_and_clear() -> void:
	var combat: MatchCombat = _combat(["crystal_sutures", "bastion_in_a_bottle"])
	_start(combat)
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Sutures scenario activates ward")
	_check(combat.item_runtime.defense.leak(0, {}, 7.0) == 4, "Ward mitigation is quantized before actual first leak loss")
	combat.item_runtime.defense.on_clear(0, 1)
	_check(combat.base_health[0] == 98, "One actual four-HP leak refunds exactly floor(4/2), not raw damage")
	combat.item_runtime.defense.on_clear(0, 1)
	_check(combat.base_health[0] == 98, "Repeated clear hook cannot pay the same first-leak heal twice")
	combat.item_runtime.defense.on_wave_start(0)
	combat.item_runtime.defense.leak(0, {}, 5.0)
	combat.item_runtime.defense.leak(0, {}, 1.0)
	combat.item_runtime.defense.on_clear(0, 2)
	_check(combat.base_health[0] == 92, "Any later leak cancels Sutures even if first leak had odd damage")
	combat.item_runtime.defense.on_wave_start(0)
	combat.item_runtime.defense.leak(0, {}, 3.0)
	combat.item_runtime.defense.on_clear(0, 3)
	_check(combat.base_health[0] == 90, "An odd first leak heals rounded-down half")
	combat.base_health[0] = 2
	combat.item_runtime.defense.on_wave_start(0)
	combat.item_runtime.defense.leak(0, {}, 20.0)
	combat.item_runtime.defense.on_clear(0, 4)
	_check(combat.base_health[0] == 0, "Sutures cannot undo defeat at clear time")


func _test_dreadmaw_reserve_and_real_boss_kill() -> void:
	var combat: MatchCombat = _combat(["dreadmaws_second_heart", "bastion_in_a_bottle", "philosophorers_stoner"])
	_start(combat)
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Reserve scenario activates ward")
	combat.item_runtime.defense.leak(0, {}, 10.0)
	_check(is_equal_approx(float(combat.item_runtime.state(0)["defense"]["reserve"]), 2.5), "Dreadmaw stores half actual mitigated loss, retaining fractional HP")
	combat.item_runtime.defense.on_boss_kill(0, {"type_id": "grunt"})
	_check(combat.base_health[0] == 95, "An ordinary kill cannot consume boss reserve")
	_check(combat.remove_item(0, &"dreadmaws_second_heart"), "Reserve item can unequip")
	combat.item_runtime.defense.on_boss_kill(0, {"type_id": "dreadmaw"})
	_check(combat.base_health[0] == 95, "Boss kill while unequipped cannot trigger retained reserve")
	_check(combat.grant_item(0, &"dreadmaws_second_heart"), "Reserve item can re-equip without reset")
	combat._spawn_enemy(0, "dreadmaw", 0.0, combat._elapsed)
	var boss: Dictionary = combat.enemies[0].back()
	combat.item_damage(0, int(boss["id"]), 1000000000.0, &"physical", &"test_boss_kill")
	_check(combat.base_health[0] == 97 and is_zero_approx(float(combat.item_runtime.state(0)["defense"]["reserve"])), "Real own-board boss death consumes reserve through shared healing exactly once")
	combat.item_runtime.defense.heal(0, 0.5)
	_check(combat.base_health[0] == 98, "Fractional reserve healing carries until a later actual heal completes one HP")
	combat.base_health[0] = 1
	combat.item_runtime.defense.leak(0, {}, 1000.0)
	combat.item_runtime.defense.on_boss_kill(0, {"type_id": "dreadmaw"})
	_check(combat.base_health[0] == 0, "Reserve records clamped actual lethal loss but never revives a defeated base")


func _test_ward_order_cap_expiry_and_rejection() -> void:
	var combat: MatchCombat = _combat(["bastion_in_a_bottle"])
	var before: Dictionary = combat.item_runtime.state(0).duplicate(true)
	_check(not combat.can_item_command(0, &"bastion_in_a_bottle", "activate") and not combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Ward is not usable during planning")
	_check(combat.item_runtime.state(0) == before, "Rejected ward command mutates no state")
	_start(combat)
	_check(not combat.item_command(0, &"bastion_in_a_bottle", "activate", 123), "Base ward rejects an unrelated tower target")
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate") and not combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Initially ready ward activates once and cannot stack")
	_check(combat.item_runtime.defense.leak(0, {}, 100.0) == 80 and combat.base_health[0] == 20, "Bastion prevents at most 20 HP rather than halving a huge leak")
	_check(combat.item_runtime.defense.leak(0, {}, 10.0) == 10 and combat.base_health[0] == 10, "A consumed ward cannot mitigate a second leak")
	combat = _combat(["bastion_in_a_bottle"])
	_start(combat)
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Expiry fixture activates ward")
	combat.item_runtime.advance(6.0)
	_check(combat.item_runtime.defense.leak(0, {}, 10.0) == 10, "Six combat seconds expire an unused ward")
	_check(not combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Expiry does not reset sixty-second cooldown")
	combat.item_runtime.advance(54.0)
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Exactly sixty combat seconds restore ward readiness")
	combat = _combat(["bastion_in_a_bottle", "ominous_bells_of_doom"])
	_start(combat)
	_check(combat.wave == 10 and combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Doom fixture starts actual first stepped wave")
	_check(combat.item_runtime.defense.leak(0, {}, 40.0) == 24, "Incoming 40 is Doom-scaled to 44 before capped 20-HP ward mitigation")
	_check(combat.item_runtime.defense.leak(1, {}, 10.0) == 11, "Shared Doom applies once on opposing base even without owning Bells")


func _test_one_more_run_lifetime_and_double_leak() -> void:
	var combat: MatchCombat = _combat(["one_more_you_git", "dreadmaws_second_heart"])
	_start(combat)
	combat._spawn_enemy(0, "grunt", 0.0, combat._elapsed)
	combat._spawn_enemy(0, "dreadmaw", 0.0, combat._elapsed)
	combat._spawn_enemy(1, "grunt", 0.0, combat._elapsed)
	var grunt: Dictionary = combat.enemies[0][0]
	var boss: Dictionary = combat.enemies[0][1]
	var opponent: Dictionary = combat.enemies[1][0]
	_check(combat.item_runtime.defense.leak(0, {}, 1000.0) == 99 and combat.base_health[0] == 1, "First lethal leak saves at exactly one HP before defeat")
	_check(is_equal_approx(float(grunt["stunned_remaining"]), 3.0) and is_zero_approx(float(boss["stunned_remaining"])) and is_zero_approx(float(opponent["stunned_remaining"])), "Save stuns own living non-boss enemies only")
	_check(is_equal_approx(float(combat.item_runtime.state(0)["defense"]["reserve"]), 49.5), "Dread reserve sees only HP actually lost after lethal save")
	_check(combat.remove_item(0, &"one_more_you_git") and combat.grant_item(0, &"one_more_you_git"), "Save can be removed and restored without renewing its charge")
	_check(combat.item_runtime.defense.leak(0, {}, 1.0) == 1 and combat.base_health[0] == 0, "Second lethal leak can defeat saved base in the very same combat time")
	combat = _combat(["one_more_you_git"])
	_start(combat)
	combat.enemies[0].clear()
	for index: int in range(2):
		combat._spawn_enemy(0, "grunt", 2.0, combat._elapsed)
		combat.enemies[0].back()["damage"] = 100
	combat._apply_leaks(0)
	_check(combat.base_health[0] == 0 and combat.enemies[0].is_empty(), "Two already-arrived same-tick leaks both resolve; save stun cannot cancel the second accepted arrival")


func _test_stun_reducers_and_fortress() -> void:
	var combat: MatchCombat = _combat()
	for record: Dictionary in [{"id": "trollhide_earplugs", "expected": 8.0}, {"id": "trollhide_apron", "expected": 6.5}, {"id": "bloodglass_hourglass", "expected": 5.0}]:
		_check(combat.set_items(0, [record["id"]]) and is_equal_approx(combat.item_runtime.defense.stun_duration(0, 10.0), float(record["expected"])), "Each authored stun reducer has its own actual multiplicative effect")
	_check(combat.set_items(0, ["trollhide_earplugs", "trollhide_apron", "bloodglass_hourglass", "the_walking_fortress"]), "All stun reductions and Fortress coexist")
	var arrow: Dictionary = _build(combat, &"arrow_tower", Vector2i(1, 1))
	var drums: Dictionary = _build(combat, &"war_drums", Vector2i(3, 1))
	var mine: Dictionary = _build(combat, &"gold_mine", Vector2i(5, 1))
	_start(combat)
	for tower: Dictionary in [arrow, drums, mine]:
		combat._stun_tower(0, tower, 10.0, "test", Vector2.ZERO)
		_check(is_equal_approx(float(tower["stunned_remaining"]), 2.6), "All three stun reducers multiply on attackers, support and economy towers")
	arrow["withered_until"] = 20.0
	arrow["wither"] = 0.5
	combat.base_health[0] = 80
	_check(combat.item_command(0, &"the_walking_fortress", "activate") and combat.base_health[0] == 90, "Rally restores ten actual HP, not max-health growth")
	_check(is_equal_approx(float(arrow["stunned_remaining"]), 2.6) and float(arrow["withered_until"]) == 20.0, "Rally does not cleanse existing stun or wither")
	for tower: Dictionary in [arrow, drums, mine]:
		combat._clear_stun(tower)
		combat._stun_tower(0, tower, 10.0, "blocked", Vector2.ZERO)
		_check(is_zero_approx(float(tower["stunned_remaining"])), "Active Fortress blocks every new friendly tower stun")
	_check(is_equal_approx(combat.item_runtime.defense.stun_duration(1, 10.0), 10.0), "Own stun items never protect opponent")
	combat.item_runtime.advance(6.0)
	combat._stun_tower(0, arrow, 10.0, "after_expiry", Vector2.ZERO)
	_check(is_equal_approx(float(arrow["stunned_remaining"]), 2.6) and not combat.item_command(0, &"the_walking_fortress", "activate"), "At six seconds new stuns resume while Rally remains on cooldown")
	combat.item_runtime.advance(54.0)
	combat.base_health[0] = 129
	var coins: int = combat.coins[0]
	_check(combat.grant_item(0, &"philosophorers_stoner") and combat.item_command(0, &"the_walking_fortress", "activate") and combat.base_health[0] == 130 and combat.coins[0] == coins + 9, "Rally's ten healing uses shared real-heal/overheal conversion after cooldown")


func _test_received_slow_and_partitioning() -> void:
	var coarse: MatchCombat = _combat(["menders_spool"])
	var fine: MatchCombat = _combat(["menders_spool"])
	var towers: Array[Dictionary] = []
	for combat: MatchCombat in [coarse, fine]:
		var tower: Dictionary = _build(combat, &"arrow_tower", Vector2i(1, 1))
		towers.append(tower)
		_start(combat)
		var interval: float = float(tower["interval"])
		combat.item_slow_tower(0, int(tower["id"]), 0.5, 10.0)
		_check(is_equal_approx(float(tower["interval"]), interval * 2.0) and is_equal_approx(combat.item_runtime.defense.tower_slow_duration(0, 10.0), 8.5), "Mender shortens a genuine received tower slow to 8.5 seconds without altering its strength")
		_check(is_equal_approx(combat.item_runtime.defense.stun_duration(0, 10.0), 10.0), "Mender does not shorten received stuns instead of slows")
		_check(not combat.item_runtime.defense.apply_tower_slow(0, -1, 0.5, 10.0), "Received slow rejects nonexistent friendly target")
	coarse.item_runtime.advance(8.0)
	for tick: int in range(80):
		fine.item_runtime.advance(0.1)
	_check(is_equal_approx(float(towers[0]["interval"]), float(towers[1]["interval"])) and is_equal_approx(coarse.item_runtime.defense.next_event_step(2.0), 0.5), "Coarse/fine advances retain same real slow-expiry boundary")
	coarse.item_runtime.advance(0.5)
	for tick: int in range(5):
		fine.item_runtime.advance(0.1)
	_check(is_equal_approx(float(towers[0]["received_slow_multiplier"]), 1.0) and is_equal_approx(float(towers[1]["received_slow_multiplier"]), 1.0), "Both partitions expire received slow at exactly 8.5 seconds; %s@%s vs %s@%s" % [towers[0].get("received_slow_multiplier", -1), coarse.item_runtime.clock, towers[1].get("received_slow_multiplier", -1), fine.item_runtime.clock])
	coarse.item_slow_tower(0, int(towers[0]["id"]), 0.8, 10.0)
	coarse.item_slow_tower(0, int(towers[0]["id"]), 0.5, 1.0)
	coarse.item_runtime.advance(0.85)
	_check(is_equal_approx(float(towers[0]["received_slow_multiplier"]), 0.8), "An expired stronger slow reveals independently surviving weaker slow: %s@%s ledger=%s" % [towers[0].get("received_slow_multiplier", -1), coarse.item_runtime.clock, coarse.item_runtime.state(0)["defense"].get("tower_slows", {})])
	coarse.item_runtime.advance(7.65)
	_check(is_equal_approx(float(towers[0]["received_slow_multiplier"]), 1.0), "The weaker slow does not inherit stronger slow's expiry or get refreshed accidentally")


func _test_debug_abandon_and_new_run() -> void:
	var combat: MatchCombat = _combat(["crystal_sutures", "dreadmaws_second_heart", "bastion_in_a_bottle", "one_more_you_git"])
	_start(combat)
	_check(combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Debug fixture activates ward")
	combat.item_runtime.defense.leak(0, {}, 8.0)
	var health: int = combat.base_health[0]
	var reserve: float = float(combat.item_runtime.state(0)["defense"]["reserve"])
	_check(combat.debug_set_round(30), "Debug abandons active defense wave")
	_check(combat.base_health[0] == health and is_equal_approx(float(combat.item_runtime.state(0)["defense"]["reserve"]), reserve), "Debug abandonment neither heals Sutures nor discards run reserve")
	combat.item_runtime.defense.on_clear(0, 29)
	_check(combat.base_health[0] == health, "Abandoned first leak cannot produce a later fake Sutures payout")
	_start(combat)
	_check(not combat.item_command(0, &"bastion_in_a_bottle", "activate"), "Debug jump retains the real active cooldown")
	combat.item_runtime.defense.leak(0, {}, 1000.0)
	_check(combat.base_health[0] == 1, "Unconsumed once-per-run save survives a debug jump")
	combat.item_runtime.defense.on_wave_abandon(0)
	combat.item_runtime.defense.on_wave_start(0)
	combat.item_runtime.defense.leak(0, {}, 1.0)
	_check(combat.base_health[0] == 0, "Wave restarts do not restore consumed save")
	var fresh: MatchCombat = _combat(["one_more_you_git", "bastion_in_a_bottle"])
	_start(fresh)
	_check(fresh.item_command(0, &"bastion_in_a_bottle", "activate") and fresh.item_runtime.defense.leak(0, {}, 1000.0) == 99 and fresh.base_health[0] == 1, "A genuinely new run resets both active readiness and once-per-run lethal save")
