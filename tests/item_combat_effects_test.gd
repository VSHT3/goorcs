extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_effective_projectile_configuration()
	_test_quiver_precedence_and_real_archers()
	_test_sun_burst_and_shutdown()
	_test_conditionals_apply_before_continuous_quantization()
	_test_summon_receipt_and_spore_infection()
	_test_siege_brace_and_burning_heals()
	_test_tenth_chain_stuns_one_victim()
	_test_lift_class_and_anchored_throw()
	_test_continuous_item_deadlines()
	_test_live_burn_conditionals()
	_test_hasted_transfer_preserves_multiplier()
	_test_high_health_infection_event_horizons()
	if failures == 0:
		print("PASS: combat items alter real accepted projectiles, continuous/burn damage, attack windows, summon marks, infection, and chain effects")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.starting_coins = 1000000
	rules.starting_reroll_currency = 100000
	rules.enemy_health = 1000
	rules.health_growth = 0
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	return rules


func _combat(ids: Array = [], speed: float = 0.0) -> MatchCombat:
	var rules: CombatRules = _rules()
	rules.enemy_speed = speed
	var combat := MatchCombat.new(rules)
	var loadout: Array[String] = []
	for definition: TowerDefinition in rules.catalog.towers:
		loadout.append(String(definition.reward.id))
	combat.configure_item_loadouts([loadout, loadout.duplicate()])
	if not ids.is_empty():
		_check(combat.set_items(0, ids), "Combat fixture accepts its authored item set")
	return combat


func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(14, 5), 30, Vector2i(0, 2), Vector2i(13, 2))
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 2))
	return [layout.capture_routing(), layout.capture_routing()]


func _start(combat: MatchCombat) -> void:
	_check(combat.sandbox_start(_routes(), 1, []), "Combat fixture admits a deterministic real simulation")


func _spawn(combat: MatchCombat, count: int = 1) -> Array[Dictionary]:
	_check(combat.sandbox_spawn(0, &"grunt", count), "Combat fixture spawns real ordinary enemies")
	return combat.enemies[0]


func _build_arrow(combat: MatchCombat, advancement: String = "fire_arrows", special: bool = true) -> Dictionary:
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Combat fixture builds an accepted Arrow Tower")
	var tower: Dictionary = combat.towers[0].back()
	if special or not advancement.is_empty():
		for upgrade: String in ["damage", "speed", "special"]:
			_check(combat.upgrade_tower(0, int(tower["id"]), upgrade), "Arrow fixture purchases its real prerequisite " + upgrade)
	var path: Array[String] = []
	var current: String = advancement
	var definitions: Dictionary = combat._tower_types["arrow_tower"]["advancements"]
	while not current.is_empty():
		path.push_front(current)
		current = String(definitions[current].get("requires", ""))
	for upgrade: String in path:
		_check(combat.upgrade_tower(0, int(tower["id"]), upgrade), "Arrow fixture purchases its authored advancement " + upgrade)
	return tower


func _item_events(combat: MatchCombat, kind: String, source_item: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in combat.snapshot()["item_events"]:
		if event["kind"] == kind and (source_item.is_empty() or String(event.get("source_item", "")) == source_item):
			result.append(event)
	return result


func _test_effective_projectile_configuration() -> void:
	var burn_combat: MatchCombat = _combat(["cinder_cooks_cauldron"])
	var burner: Dictionary = _build_arrow(burn_combat, "molotov")
	_start(burn_combat)
	var target: Dictionary = _spawn(burn_combat)[0]
	burn_combat.advance(0.01)
	var burn: Dictionary = burn_combat._burns[int(target["id"])]
	var burn_remaining: float = float(burn["end_time"]) - burn_combat._elapsed
	_check(is_equal_approx(float(burner["effective_attack_config"]["burn_duration"]), 4.2) and is_equal_approx(burn_remaining, 4.2), "Molotov's accepted projectile and live burn use its 40% cauldron duration")

	var packed: MatchCombat = _combat(["packed_powder"])
	var explosive: Dictionary = _build_arrow(packed, "anti_orc_grenades", false)
	_start(packed)
	var enemies: Array = _spawn(packed, 2)
	enemies[0]["progress"] = 5.0
	enemies[0]["pos"] = Vector2(5.0, 2.0)
	enemies[1]["progress"] = 6.65
	enemies[1]["pos"] = Vector2(6.65, 2.0)
	var before_splash: int = int(enemies[1]["hp"])
	packed._attack_arrow(0, explosive, int(enemies[0]["id"]), Vector2(enemies[0]["pos"]), explosive["effective_attack_config"])
	_check(is_equal_approx(float(explosive["effective_attack_config"]["splash_radius"]), 1.8), "Item splash expansion rebuilds the effective attack resource")
	_check(int(enemies[1]["hp"]) < before_splash, "The expanded real explosive projectile reaches a neighbor outside its vanilla radius")

	var unmodified: MatchCombat = _combat()
	var plain: Dictionary = _build_arrow(unmodified, "anti_orc_grenades", false)
	_start(unmodified)
	var plain_enemies: Array = _spawn(unmodified, 2)
	plain_enemies[0]["progress"] = 5.0
	plain_enemies[0]["pos"] = Vector2(5.0, 2.0)
	plain_enemies[1]["progress"] = 6.65
	plain_enemies[1]["pos"] = Vector2(6.65, 2.0)
	var untouched: int = int(plain_enemies[1]["hp"])
	unmodified._attack_arrow(0, plain, int(plain_enemies[0]["id"]), Vector2(plain_enemies[0]["pos"]), plain["effective_attack_config"])
	_check(int(plain_enemies[1]["hp"]) == untouched, "The same real splash contact outside base radius remains unharmed without Powder")


func _test_quiver_precedence_and_real_archers() -> void:
	var combat: MatchCombat = _combat(["bottomless_quiver", "entire_quiver", "concucktion"])
	var tower: Dictionary = _build_arrow(combat)
	_start(combat)
	var enemy: Dictionary = _spawn(combat)[0]
	var random_before: int = combat.item_runtime.random.state
	combat.advance(0.01)
	_check(combat.item_runtime.random.state != random_before, "Concucktion rerolls the accepted attack's live targeting mode")
	var copied: Array[Dictionary] = _item_events(combat, "extra_arrow", "entire_quiver")
	_check(copied.size() == 2 and int(combat.item_runtime.state(0)["combat"]["arrow_counts"][int(tower["id"])]) == 2, "Whole Quiver copies both actually fired accepted arrows and owns the shared counter")
	_check(not _item_events(combat, "extra_arrow", "bottomless_quiver").size(), "Entire Quiver replaces Bottomless rather than stacking its trigger")
	var one_archer: MatchCombat = _combat(["entire_quiver"])
	var solo: Dictionary = _build_arrow(one_archer, "", false)
	_start(one_archer)
	_spawn(one_archer)
	one_archer.advance(0.01)
	_check(_item_events(one_archer, "extra_arrow").is_empty() and not one_archer.item_runtime.state(0)["combat"].get("arrow_counts", {}).has(int(solo["id"])), "An actually unupgraded single archer does not copy arrows before Second Archer is purchased")
	var interval: float = float(tower["interval"])
	_check(combat.remove_item(0, &"entire_quiver"), "Removing Whole Quiver leaves the retained ordinary-arrow counter")
	combat.advance(interval)
	combat.advance(interval)
	var bottomless: Array[Dictionary] = _item_events(combat, "extra_arrow", "bottomless_quiver")
	_check(bottomless.size() == 1 and int(combat.item_runtime.state(0)["combat"]["arrow_counts"][int(tower["id"])]) == 6, "Bottomless fires once on the fifth actual arrow after Whole Quiver is removed")
	_check(int(enemy["hp"]) < int(enemy["max_hp"]), "Copied arrows resolve damage through ordinary projectile hit rules")


func _test_sun_burst_and_shutdown() -> void:
	var combat: MatchCombat = _combat(["sun_in_a_cage"])
	var tower: Dictionary = _build_arrow(combat)
	_start(combat)
	var enemy: Dictionary = _spawn(combat)[0]
	enemy["hp"] = 100000
	combat.advance(10.0)
	_check(not _item_events(combat, "sun_burst").is_empty(), "Ten real eligible attacking seconds release the Fire burst")
	_check(float(tower.get("item_sun_shutdown", 0.0)) > 2.9, "The burst begins its three-second real attack shutdown")
	var id: int = int(enemy["id"])
	enemy["hp"] = int(enemy["max_hp"])
	enemy["burning"] = false
	enemy["burn_remaining"] = 0.0
	combat._burns.erase(id)
	tower["cooldown"] = 0.0
	var shots: int = int(tower["shot"])
	combat.advance(1.0)
	_check(int(tower["shot"]) == shots, "Sun shutdown actually suppresses accepted tower attacks, not just its display")
	combat.advance(2.1)
	_check(int(tower["shot"]) > shots, "The same tower resumes firing after its real shutdown deadline")


func _test_conditionals_apply_before_continuous_quantization() -> void:
	var plain: MatchCombat = _combat()
	var boosted: MatchCombat = _combat(["butchers_apron"])
	var plain_tower: Dictionary = _build_arrow(plain, "flamethrower", false)
	var boosted_tower: Dictionary = _build_arrow(boosted, "flamethrower", false)
	_start(plain)
	_start(boosted)
	var plain_enemy: Dictionary = _spawn(plain)[0]
	var boosted_enemy: Dictionary = _spawn(boosted)[0]
	plain_enemy["hp"] = 400
	boosted_enemy["hp"] = 400
	var starting: int = int(plain_enemy["hp"])
	_check(plain_tower["behavior_kind"] == "attack" and boosted_tower["behavior_kind"] == "attack", "Flamethrower fixtures are accepted attacker towers")
	plain.advance(0.1)
	boosted.advance(0.1)
	_check(int(boosted_enemy["hp"]) < int(plain_enemy["hp"]) and int(plain_enemy["hp"]) < starting, "Conditional Butcher damage scales a real continuous flame before fractional HP is quantized")

	var direct: MatchCombat = _combat(["butchers_apron", "frostbite_nail", "watchmans_cup", "gravediggers_lantern", "mooncap_jerky", "necromancers_receipt"])
	var arrow: Dictionary = _build_arrow(direct, "fire_arrows", false)
	_start(direct)
	var victim: Dictionary = _spawn(direct)[0]
	victim["original_birth_kind"] = "summon"
	victim["progress"] = float(victim["route"].size() - 2)
	victim["hp"] = floori(float(victim["max_hp"]) * float(direct.item_runtime.params(0, &"butchers_apron")["hp_fraction"])) - 1
	victim["slowed"] = true
	var runtime_state: Dictionary = direct.item_runtime.state(0)["combat"]
	runtime_state["receipt"][int(victim["id"])] = direct.item_runtime.clock + 5.0
	victim["receipt_remaining"] = 5.0
	arrow["crit_chance"] = 0.0
	var multiplier: float = direct.item_runtime.combat_effects.hit_multiplier(0, arrow, victim, {})
	var expected: int = ceili(10.0 * multiplier - 0.000000001)
	var hp_before: int = int(victim["hp"])
	var victim_index: int = direct._enemy_index(0, int(victim["id"]))
	_check(direct._hit(0, arrow, victim_index, 10), "Accepted direct hit reaches conditional combat modifiers")
	_check(hp_before - int(victim["hp"]) == expected, "Summoned nonboss, low-HP, slow, final-tile and Receipt conditions compose on the actual host hit")
	direct._spawn_enemy(0, "dreadmaw", 0.0, direct._elapsed)
	var boss: Dictionary = direct.enemies[0].back()
	boss["progress"] = float(boss["route"].size() - 2)
	boss["hp"] = floori(float(boss["max_hp"]) * float(direct.item_runtime.params(0, &"butchers_apron")["hp_fraction"])) - 1
	boss["slowed"] = true
	boss["original_birth_kind"] = "wave"
	runtime_state["receipt"][int(boss["id"])] = direct.item_runtime.clock + 5.0
	var boss_multiplier: float = direct.item_runtime.combat_effects.hit_multiplier(0, arrow, boss, {})
	var boss_expected: int = ceili(ceili(10.0 * boss_multiplier - 0.000000001) * direct._damage_multiplier(boss, direct._tower_damage_type(arrow)) - 0.000000001)
	var boss_before: int = int(boss["hp"])
	var boss_index: int = direct._enemy_index(0, int(boss["id"]))
	_check(direct._hit(0, arrow, boss_index, 10), "Accepted boss hit resolves conditional item effects")
	_check(boss_before - int(boss["hp"]) == boss_expected and is_equal_approx(boss_multiplier, multiplier * 1.15 / (0.95 * 1.25)), "Boss Jerky replaces its nonboss penalty while the summon-only bonus stops")


func _test_siege_brace_and_burning_heals() -> void:
	var combat: MatchCombat = _combat(["siege_carpenters_brace"])
	_check(combat.build(0, Vector2i(1, 1), &"orc_ballista", MatchCombat.TargetMode.FURTHEST), "Brace fixture builds a real Ballista")
	var tower: Dictionary = combat.towers[0].back()
	_start(combat)
	var enemy: Dictionary = _spawn(combat)[0]
	enemy["hp"] = 100000
	combat.advance(7.0)
	_check(is_equal_approx(float(tower.get("item_brace_bonus", 0.0)), 0.35), "Seven uninterrupted aim-bucket seconds reach Brace's authored cap")
	var before: int = int(enemy["hp"])
	var index: int = combat._enemy_index(0, int(enemy["id"]))
	combat._hit(0, tower, index, 10)
	_check(before - int(enemy["hp"]) == 14, "The accepted Brace bonus multiplies a real Ballista hit before integer damage")

	var censer: MatchCombat = _combat(["wormwood_censer"])
	var archer: Dictionary = _build_arrow(censer, "fire_arrows", false)
	_start(censer)
	var burned: Dictionary = _spawn(censer)[0]
	burned["hp"] = 100
	burned["burning"] = true
	censer._burns[int(burned["id"])] = {"source": archer}
	_check(censer.item_heal_enemy(0, burned, 20.0) == 10 and int(burned["hp"]) == 110, "The Censer halves real healing of an enemy under the owner's Arrow burn")


func _test_lift_class_and_anchored_throw() -> void:
	var combat: MatchCombat = _combat(["heartwood_siege_arm", "leviathan_anchor"])
	_check(combat.build(0, Vector2i(5, 1), &"orcapult", MatchCombat.TargetMode.FURTHEST), "Anchor fixture builds a real Orcapult")
	var tower: Dictionary = combat.towers[0].back()
	_start(combat)
	combat._spawn_enemy(0, "brute", 6.0, combat._elapsed)
	var enemy: Dictionary = combat.enemies[0].back()
	var original_route: Array = enemy["route"].duplicate()
	combat.advance(0.01)
	_check(is_equal_approx(float(tower["behavior_config"]["lift"]), 2.5), "Heartwood lifts the next authored nonboss weight class rather than an arbitrary HP amount")
	_check(combat.flights.size() == 1 and bool(combat.flights[0]["anchored"]), "Leviathan accepts the heavier target as a same-route anchored flight")
	if combat.flights.is_empty():
		return
	var flight: Dictionary = combat.flights[0]
	_check(int(flight["to_slot"]) == 0 and flight["route"] == original_route and is_equal_approx(float(flight["progress"]), 5.0), "The anchored throw stays on the victim's route and lands one extra cell toward its entrance")
	combat.advance(float(flight["land_time"]) - combat._elapsed + 0.01)
	_check(combat.flights.is_empty() and not combat.enemies[0].is_empty() and combat.enemies[0][0]["route"] == original_route, "Landing preserves the same accepted route instead of transferring or teleporting the enemy")


func _test_summon_receipt_and_spore_infection() -> void:
	var receipt_combat: MatchCombat = _combat(["necromancers_receipt"])
	var attacker: Dictionary = _build_arrow(receipt_combat, "", false)
	_start(receipt_combat)
	var parent: Dictionary = _spawn(receipt_combat)[0]
	receipt_combat._spawn_enemy(0, "grunt", 0.0, receipt_combat._elapsed, [], int(parent["id"]))
	var child: Dictionary = receipt_combat.enemies[0].back()
	parent["hp"] = 1
	var parent_index: int = receipt_combat._enemy_index(0, int(parent["id"]))
	receipt_combat._hit(0, attacker, parent_index, 1)
	_check(float(child.get("receipt_remaining", 0.0)) == 5.0, "Killing a summoner places a real five-second Receipt on its surviving child")
	var before: int = int(child["hp"])
	var child_index: int = receipt_combat._enemy_index(0, int(child["id"]))
	receipt_combat._hit(0, attacker, child_index, 10)
	_check(before - int(child["hp"]) > 10, "Receipt multiplies the actual next accepted hit on a surviving summon")

	var spores: MatchCombat = _combat(["spore_spawn_of_marko"])
	_start(spores)
	var infected: Dictionary = _spawn(spores)[0]
	_check(bool(infected["infected"]) and int(spores.item_runtime.state(0)["combat"]["spore_remaining"]) == 0, "The first real wave arrival consumes and displays the owner's infection quota")
	var before_hp: int = int(infected["hp"])
	spores.advance(4.0)
	_check(before_hp - int(infected["hp"]) == int(infected["max_hp"]) * 8 / 100, "Four continuous infection seconds resolve exactly eight percent magic damage through the shared host damage path")
	_check(not bool(infected["infected"]) and spores.item_runtime.has(0, &"spore_spawn_of_marko"), "The infection expires while the owned crystal-side pet remains available")


func _test_tenth_chain_stuns_one_victim() -> void:
	var combat: MatchCombat = _combat(["clockwork_raincloud"])
	_check(combat.build(0, Vector2i(1, 1), &"lightning", MatchCombat.TargetMode.FURTHEST), "Combat fixture builds a real chain tower")
	var tower: Dictionary = combat.towers[0].back()
	_start(combat)
	tower["interval"] = 0.1
	tower["cooldown"] = 0.0
	var enemies: Array = _spawn(combat, 12)
	for enemy: Dictionary in enemies:
		enemy["hp"] = 100000
	for _chain: int in range(10):
		combat.advance(0.1)
	_check(int(combat.item_runtime.state(0)["combat"]["chain_count"]) == 10, "Only ten actual released chain attacks advance the board counter")
	var stuns: Array[Dictionary] = _item_events(combat, "raincloud_stun")
	var stunned: int = 0
	for enemy: Dictionary in enemies:
		if float(enemy["stunned_remaining"]) > 0.0:
			stunned += 1
	_check(stuns.size() == 1 and stunned == 1, "Exactly the tenth released Lightning chain stuns its first eligible nonboss victim")


func _advance_partitioned(combat: MatchCombat, duration: float, fine: bool) -> void:
	if not fine:
		combat.advance(duration)
		return
	var remaining: float = duration
	while remaining > 0.000000001:
		var step: float = minf(0.01, remaining)
		combat.advance(step)
		remaining -= step


func _flame_field(ids: Array, immune: bool = false, dying_primary: bool = false) -> MatchCombat:
	var combat: MatchCombat = _combat(ids)
	_build_arrow(combat, "flamethrower")
	_start(combat)
	_check(combat.sandbox_spawn(0, &"skeleorc" if immune else &"grunt", 1), "Timeline fixture spawns a real elemental target")
	var enemy: Dictionary = combat.enemies[0].back()
	enemy["hp"] = 100 if dying_primary else 1000000
	enemy["max_hp"] = int(enemy["hp"])
	if dying_primary:
		_spawn(combat)
		combat.enemies[0].back()["hp"] = 1000000
		combat.enemies[0].back()["max_hp"] = 1000000
	return combat


func _test_continuous_item_deadlines() -> void:
	for scenario: String in ["primary", "immune", "death", "all130"]:
		var ids: Array = ["sun_in_a_cage"]
		if scenario == "all130":
			ids.clear()
			for item: ItemDefinition in _rules().catalog.items:
				ids.append(String(item.id))
		var coarse: MatchCombat = _flame_field(ids, scenario == "immune", scenario == "death")
		var fine: MatchCombat = _flame_field(ids, scenario == "immune", scenario == "death")
		_advance_partitioned(coarse, 13.1, false)
		_advance_partitioned(fine, 13.1, true)
		var first: Dictionary = coarse.towers[0][0]
		var second: Dictionary = fine.towers[0][0]
		_check(first["damage_dealt"] == second["damage_dealt"] and first["kills"] == second["kills"], "Sun integrates exposure, target death and immunity identically across coarse/fine host advances: " + scenario)
		_check(is_equal_approx(float(first.get("item_sun_shutdown", 0.0)), float(second.get("item_sun_shutdown", 0.0))) and is_equal_approx(float(first.get("item_sun_heat", 0.0)), float(second.get("item_sun_heat", 0.0))), "Sun's charge/shutdown boundaries are frame-partition independent: " + scenario)
		if scenario == "primary":
			_check(int(first["damage_dealt"]) == 1620, "Ten firing seconds, three shutdown seconds of residual burn, burst9 and resumed0.1s deliver the authored1620 whole HP")
		elif scenario == "immune":
			_check(int(first["damage_dealt"]) == 0 and float(first.get("item_sun_heat", 0.0)) == 0.0, "A real Fire-immune target neither takes flame damage nor charges Sun")
		elif scenario == "death":
			_check(int(first["kills"]) == 1, "A primary death is retired exactly once before continuous retargeting")
		else:
			_check(coarse.item_runtime.owned_ids(0).size() == 130 and fine.item_runtime.owned_ids(0).size() == 130, "Every simultaneous item survives the real purchased-Flamethrower timeline")
	var ladder_coarse: MatchCombat = _flame_field(["witchs_folded_ladder"])
	var ladder_fine: MatchCombat = _flame_field(["witchs_folded_ladder"])
	for combat: MatchCombat in [ladder_coarse, ladder_fine]:
		var enemy: Dictionary = combat.enemies[0][0]
		enemy["progress"] = 4.0
		enemy["pos"] = Vector2(4.0, 2.0)
		combat._enemies_relocated(0)
		_check(combat.item_command(0, &"witchs_folded_ladder", "active"), "Ladder activates through the actual host command")
	_advance_partitioned(ladder_coarse, 5.0, false)
	_advance_partitioned(ladder_fine, 5.0, true)
	_check(int(ladder_coarse.towers[0][0]["damage_dealt"]) == 780 and int(ladder_fine.towers[0][0]["damage_dealt"]) == 780, "All five seconds of Ladder-only range integrate before expiry, without a frame-sized substitute")
	_check(ladder_coarse.item_runtime.state(0)["active"].is_empty() and is_equal_approx(float(ladder_coarse.towers[0][0]["range"]), 3.0), "Ladder retires its active range at the same boundary after the preceding exposure")


func _burn_field(ids: Array, speed: float = 0.0) -> MatchCombat:
	var combat: MatchCombat = _combat(ids, speed)
	_build_arrow(combat, "fire_arrows")
	_start(combat)
	_spawn(combat)
	combat.towers[0][0]["cooldown"] = 1000.0
	return combat


func _ignite_target(combat: MatchCombat, enemy: Dictionary) -> void:
	var tower: Dictionary = combat.towers[0][0]
	combat._attack_arrow(0, tower, int(enemy["id"]), enemy["pos"], tower["effective_attack_config"])


func _test_live_burn_conditionals() -> void:
	for fine: bool in [false, true]:
		var butcher: MatchCombat = _burn_field(["butchers_apron"])
		var enemy: Dictionary = butcher.enemies[0][0]
		_ignite_target(butcher, enemy)
		enemy["hp"] = 400
		var before: int = int(enemy["hp"])
		_advance_partitioned(butcher, 2.0, fine)
		var burn: Dictionary = butcher._burns[int(enemy["id"])]
		_check(before - int(enemy["hp"]) == 9 and is_equal_approx(float(burn["dps"]), 4.6) and is_equal_approx(float(burn["fraction"]), 0.2), "A live burn re-evaluates Butcher after ignition above half HP, before every positive exposure")

		var crossing: MatchCombat = _burn_field(["butchers_apron"])
		var crossing_enemy: Dictionary = crossing.enemies[0][0]
		_ignite_target(crossing, crossing_enemy)
		crossing_enemy["hp"] = 501
		_advance_partitioned(crossing, 2.0, fine)
		var crossing_burn: Dictionary = crossing._burns[int(crossing_enemy["id"])]
		_check(int(crossing_enemy["hp"]) == 493 and is_equal_approx(float(crossing_burn["fraction"]), 0.9), "Butcher switches a running burn exactly when whole-HP damage crosses below half, not at the next render frame")

		var receipt: MatchCombat = _burn_field(["necromancers_receipt"])
		var parent: Dictionary = receipt.enemies[0][0]
		receipt._spawn_enemy(0, "grunt", 0.0, receipt._elapsed, [], int(parent["id"]))
		var child: Dictionary = receipt.enemies[0].back()
		receipt._hit(0, receipt.towers[0][0], receipt._enemy_index(0, int(parent["id"])), 1000000, true)
		receipt.advance(4.0)
		_ignite_target(receipt, child)
		before = int(child["hp"])
		_advance_partitioned(receipt, 2.0, fine)
		_check(before - int(child["hp"]) == 9 and is_equal_approx(float(receipt._burns[int(child["id"])]["dps"]), 4.0), "Receipt boosts exactly the preceding one-second burn exposure before its real five-second expiry")

		var frost: MatchCombat = _burn_field(["frostbite_nail"])
		enemy = frost.enemies[0][0]
		_ignite_target(frost, enemy)
		enemy["slowed"] = true
		enemy["slow_remaining"] = 1.0
		frost._prepare_motion(enemy)
		before = int(enemy["hp"])
		_advance_partitioned(frost, 2.0, fine)
		burn = frost._burns[int(enemy["id"])]
		_check(before - int(enemy["hp"]) == 8 and is_equal_approx(float(burn["fraction"]), 0.8) and is_equal_approx(float(burn["dps"]), 4.0), "Frostbite follows the victim's changing real slow duration instead of caching ignition state")

		var watch: MatchCombat = _burn_field(["watchmans_cup"], 1.0)
		enemy = watch.enemies[0][0]
		_ignite_target(watch, enemy)
		enemy["progress"] = 10.5
		enemy["pos"] = Vector2(10.5, 2.0)
		watch._enemies_relocated(0)
		before = int(enemy["hp"])
		_advance_partitioned(watch, 2.0, fine)
		burn = watch._burns[int(enemy["id"])]
		_check(before - int(enemy["hp"]) == 8 and is_equal_approx(float(burn["fraction"]), 0.5) and is_equal_approx(float(burn["dps"]), 5.0), "Watchman's existing burn gains its final-tile bonus only after the exact path-entry boundary")


func _test_hasted_transfer_preserves_multiplier() -> void:
	var combat: MatchCombat = _combat([], 1.0)
	_check(combat.build(0, Vector2i(1, 1), &"orcapult", 0), "Haste fixture purchases its real transport tower")
	var tower: Dictionary = combat.towers[0][0]
	_start(combat)
	var enemy: Dictionary = _spawn(combat)[0]
	var baseline: float = float(enemy["base_speed"])
	_check(combat.sandbox_spawn(0, &"grand_mage_orcafus", 1), "Haste fixture admits the real spellcasting boss")
	var mage: Dictionary = combat.enemies[0].back()
	var book: Dictionary = combat._enemy_types["grand_mage_orcafus"]["spellbook"]
	_check(combat._begin_spell(0, mage, book, "haste"), "The real Grand Mage spellbook admits Haste")
	combat._resolve_spell(0, mage, book)
	_check(is_equal_approx(float(enemy["base_speed"]), baseline * 1.4), "The actual Haste spell multiplies the departure baseline")
	combat._attack_catapult(0, tower, 0.0)
	_check(combat.flights.size() == 1, "The real transport attack accepts a hasted passenger")
	combat.advance(MatchCombat.FLIGHT_DURATION + 0.01)
	_check(String(enemy["birth_kind"]) == "transfer" and is_equal_approx(float(enemy["base_speed"]), baseline * 1.4), "Arrival recomputation preserves the same still-live Haste multiplier")
	combat.advance(6.01 - combat._elapsed)
	_check(is_equal_approx(float(enemy["haste_multiplier"]), 1.0) and is_equal_approx(float(enemy["base_speed"]), baseline), "Haste expiry divides out exactly the multiplier retained on landing, restoring the original baseline")


func _test_high_health_infection_event_horizons() -> void:
	var combat: MatchCombat = _combat(["spore_spawn_of_marko"])
	_start(combat)
	var enemy: Dictionary = _spawn(combat)[0]
	enemy["max_hp"] = 1000000
	enemy["hp"] = 1000000
	var rate: float = 20000.0
	_check(is_equal_approx(combat.item_damage_event_step(0, int(enemy["id"]), rate, &"magic", &"spore_spawn_of_marko", 4.0), 4.0) and is_equal_approx(combat._next_event_step(4.0), 4.0), "A million-HP infection schedules its actual duration boundary, never20000 whole-HP bookkeeping events per second")
	enemy["hp"] = 40000
	_check(is_equal_approx(combat.item_damage_event_step(0, int(enemy["id"]), rate, &"magic", &"spore_spawn_of_marko", 4.0), 2.0), "Infection's next damage event is its real lethal horizon rather than the next quantized HP")
	combat.item_damage(0, int(enemy["id"]), 0.5, &"magic", &"spore_spawn_of_marko", {}, {"continuous": true, "exposure": 0.000025})
	_check(is_equal_approx(combat.item_damage_event_step(0, int(enemy["id"]), rate, &"magic", &"spore_spawn_of_marko", 4.0), (40000.0 - 0.5) / rate), "The lethal infection horizon retains the actual continuous stream's fractional HP")
	combat.advance(0.5)
	_check(int(enemy["hp"]) == 30000, "One accepted half-second high-HP infection integrates10000 actual damage without per-HP passes")

	for fine: bool in [false, true]:
		var shared: MatchCombat = _flame_field(["spore_spawn_of_marko"])
		var infected: Dictionary = shared.enemies[0][0]
		infected["max_hp"] = 1000000
		infected["hp"] = 1000
		var event: float = shared._next_event_step(1.0)
		_check(event > 0.049 and event < 0.05, "The shared death solver combines Spore with real flame/burn streams before choosing the lethal boundary")
		_advance_partitioned(shared, 0.1, fine)
		_check(shared.enemies[0].is_empty() and shared.enemy_totals[0]["kills"].get("grunt", 0) == 1, "Coarse/fine combined infection and tower damage retire one high-HP victim exactly once")
