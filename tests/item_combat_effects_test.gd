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


func _combat(ids: Array = []) -> MatchCombat:
	var rules: CombatRules = _rules()
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
	tower["advancement"] = advancement
	tower["special_upgraded"] = special
	tower["cooldown"] = 0.0
	combat._refresh_board(0)
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
	var solo: Dictionary = _build_arrow(one_archer, "fire_arrows", false)
	_start(one_archer)
	_spawn(one_archer)
	one_archer.advance(0.01)
	_check(_item_events(one_archer, "extra_arrow").is_empty() and not one_archer.item_runtime.state(0)["combat"].get("arrow_counts", {}).has(int(solo["id"])), "A fire advancement's two-archer config does not copy until a second archer is actually purchased")
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
	combat._spawn_enemy(0, "storm_orc", 6.0, combat._elapsed)
	var enemy: Dictionary = combat.enemies[0].back()
	var original_route: Array = enemy["route"].duplicate()
	combat.advance(0.01)
	_check(is_equal_approx(float(tower["behavior_config"]["lift"]), 1.2), "Heartwood lifts the next real nonboss weight class rather than an arbitrary HP amount")
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
