extends SceneTree
## Numeric expectations are independent of the runtime manifest under test.

var failures: int = 0
var rules: CombatRules

const CASES: Array = [
	["iron_arrowhead", "attacking", {"damage_multiplier": 1.05}],
	["oiled_gears", "attacking", {"speed_multiplier": 1.05}],
	["heavy_ammunition", "attacking", {"damage_multiplier": 1.12, "speed_multiplier": 0.95}],
	["short_bowstring", "arrow", {"damage_multiplier": 1.1, "range": 2.75}],
	["greased_winch", "ballista", {"speed_multiplier": 1.08}],
	["chipped_runestone", "rune", {"damage_multiplier": 1.08}],
	["copper_coil", "lightning", {"damage_multiplier": 1.08}],
	["taut_drumskin", "drums", {"support": 1.05}],
	["leather_bracer", "physical_projectile", {"damage_multiplier": 1.04}],
	["salted_rations", "attacking", {"damage_multiplier": 1.07, "speed_multiplier": 0.97}],
	["field_manual", "rune", {"range": 3.25}],
	["reed_whistle", "attacking", {"speed_multiplier": 1.04}],
	["flint_striker", "fire_arrow", {"item_direct_damage_multiplier": 1.08, "damage_multiplier": 1.0}],
	["snail_shell", "attacking", {"range": 3.25, "speed_multiplier": 0.95}],
	["woven_sling", "orcapult", {"damage_multiplier": 1.08}],
	["steel_arrowhead", "attacking", {"damage_multiplier": 1.1}],
	["balanced_mechanism", "attacking", {"damage_multiplier": 1.06, "speed_multiplier": 1.06}],
	["lucky_fang", "attacking", {"crit_chance": 0.03}],
	["siege_scope", "attacking", {"range": 3.5, "speed_multiplier": 0.92}],
	["lightweight_ammunition", "attacking", {"damage_multiplier": 0.9, "speed_multiplier": 1.18}],
	["heavy_bolts", "physical_ballista", {"damage_multiplier": 1.25, "speed_multiplier": 0.9}],
	["resonant_drumsticks", "drums", {"support": 1.12}],
	["oversized_bucket", "orcapult", {"throw_count": 2, "interval": 1.2}],
	["peppercorn_skewer", "attacking", {"speed_multiplier": 1.08}],
	["surveyors_fieldbook", "attacking", {"range": 3.3, "damage_multiplier": 0.95}],
	["riveted_bracer", "physical", {"damage_multiplier": 1.15, "speed_multiplier": 0.92}],
	["copper_winding", "lightning", {"speed_multiplier": 1.12}],
	["pitch_sealed_sling", "orcapult", {"damage_multiplier": 1.12}],
	["executioners_iron", "attacking", {"damage_multiplier": 1.3, "speed_multiplier": 0.85}],
	["gamblers_lens", "attacking", {"crit_chance": 0.15, "damage_multiplier": 0.88}],
	["surveyors_glass", "attacking", {"range": 3.5}],
	["copper_windings", "lightning", {"hit_count": 3}],
	["packed_powder", "explosive_arrow", {"splash_radius": 1.2, "speed_multiplier": 0.9}],
	["siegecraft_folio", "ballista", {"damage_multiplier": 1.2}],
	["riveted_gorget", "attacking", {"damage_multiplier": 1.18, "range": 2.75}],
	["pepper_roast", "attacking", {"speed_multiplier": 1.12}],
	["masons_plumb", "rune", {"range": 3.5}],
	["reed_warpipes", "drums", {"support": 1.15}],
	["basilisk_fang", "physical", {"damage_multiplier": 1.18}],
	["heartwood_cutting", "rune", {"speed_multiplier": 1.12}],
	["jewelers_torque", "attacking", {"crit_damage_multiplier": 2.4}],
	["samurai_sword", "attacking", {"damage_multiplier": 1.35, "speed_multiplier": 0.9}],
	["warlords_gauntlet", "attacking", {"speed_multiplier": 1.25}],
	["giants_eye", "attacking", {"range": 3.75}],
	["berserkers_crank", "projectile", {"speed_multiplier": 1.45, "damage_multiplier": 0.8, "range": 2.75}],
	["warhide_drumskin", "command_banner", {"attack_speed_bonus": 0.25}],
	["smith_kings_hammer", "forge", {"damage_bonus": 0.25}],
	["glacial_chisel", "rune", {"freeze_slow_multiplier": 0.7}],
	["stormglass_tuning_fork", "lightning", {"jump_distance": 2.5}],
	["besiegers_powder_horn", "grenade_rocket_arrow", {"splash_radius": 1.2, "speed_multiplier": 0.9}],
	["cartographers_field_atlas", "attacking", {"range": 3.5, "damage_multiplier": 0.9}],
	["moon_salt_jerky", "attacking", {"damage_multiplier": 1.15, "crit_chance": 0.05}],
	["falconers_hood", "arrow", {"crit_chance": 0.1, "speed_multiplier": 0.9}],
	["concucktion", "attacking", {"speed_multiplier": 1.5}],
	["ashen_surveyors_chain", "attacking", {"range": 3.75, "speed_multiplier": 0.85}],
	["volcano_bellows", "flamethrower", {"damage_multiplier": 1.35, "range": 2.75}],
	["widows_bone_needle", "bloodlust_totem", {"support_crit": 0.26}],
	["horizon_prism", "lookout_horn", {"range_aura": 1.3}],
	["rune_pulse_metronome", "pulsed_rune", {"speed_multiplier": 1.3}],
	["thunder_eel_jar", "lightning", {"hit_count": 3, "damage_multiplier": 0.85}],
	["obsidian_saddle", "orcapult", {"speed_multiplier": 1.25, "damage_multiplier": 0.85}],
	["cinder_cooks_cauldron", "molotov", {"burn_duration": 5.6}],
	["fossilized_war_beetle", "physical", {"damage_multiplier": 1.35}],
	["vermilion_war_sash", "attacking", {"crit_damage_multiplier": 2.8, "crit_chance": 0.0}],
	["marrow_longbow", "arrow", {"damage_multiplier": 1.4, "range": 2.75}],
	["orc_kings_signet", "attacking", {"damage_multiplier": 1.3, "speed_multiplier": 1.15}],
	["titans_heart", "attacking", {"damage_multiplier": 1.8, "speed_multiplier": 0.7}],
	["perfect_scope", "attacking", {"range": 4.0, "crit_chance": 0.1}],
	["heartwood_siege_arm", "orcapult", {"lift": 2.5}],
	["empresss_warcoat", "attacking", {"damage_multiplier": 1.2, "crit_damage_multiplier": 2.9}],
	["leviathan_anchor", "orcapult", {"item_throw_distance": 1.0, "speed_multiplier": 0.8}],
	["stormcallers_crown", "lightning", {"hit_count": 4, "damage_multiplier": 0.8}],
	["dragons_breath_decanter", "fire", {"damage_multiplier": 1.6, "speed_multiplier": 0.85}],
	["saints_marrow_flute", "bloodlust_totem", {"support_crit": 0.3}],
	["gorcs_right_hand", "attacking", {"damage_multiplier": 1.6, "speed_multiplier": 1.4}],
	["biggest_wood", "physical_ballista", {"damage_multiplier": 2.5, "branch_pierce": 3, "speed_multiplier": 0.75}],
	["forbidden_beat", "drums", {"support": 2.0}]
]


func _init() -> void:
	rules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	_test_records()
	_test_individual_stats()
	_test_composition_and_boundaries()
	_test_real_explosive_eligibility()
	_test_real_lift_classes()
	_test_real_crit_composition()
	_test_real_refresh_support_and_continuous()
	if failures == 0:
		print("PASS: all authored item schemas, every static modifier, eligibility, multiplicative composition, support purity/maxima, crit boundaries, evolution refresh, cooldown preservation and all-130 continuous combat")
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _near(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s: got %s expected %s" % [message, actual, expected])


func _test_records() -> void:
	_check(rules.catalog.items.size() == 130, "The complete 130-item catalog is admitted")
	for definition: ItemDefinition in rules.catalog.items:
		_check(not definition.runtime.is_empty() and ItemStatEffects.validate_runtime(definition.runtime).is_empty(), "%s has complete finite authored runtime" % definition.id)
	for invalid: Dictionary in [
		{}, {"stats": []}, {"mechanic": "made_up", "parameters": {"x": 1}},
		{"stats": [{"filter": "all", "values": {"damage_multiplier": 2.0}}]},
		{"stats": [{"filter": "attacking", "values": {"damage_multiplier": INF}}]},
		{"stats": [{"filter": "attacking", "values": {"damage_multiplier": "1.1"}}]},
		{"stats": [{"filter": "drums", "values": {"damage_multiplier": 2.0}}]},
		{"stats": [{"filter": "arrow", "values": {"chain_hits_add": 1}}]},
		{"mechanic": "minute_hand_cannon", "parameters": {"duration": 5.0, "cooldown": 30.0}},
		{"mechanic": "bottomless_quiver", "parameters": {"every": 2.5, "damage_multiplier": 0.5}}
	]:
		_check(not ItemStatEffects.validate_runtime(invalid).is_empty(), "Invalid schema/eligibility/numeric atom rejected: %s" % invalid)


func _fixture(filter_name: String) -> Dictionary:
	var tower: Dictionary = {
		"id": 100, "cell": Vector2i(5, 5), "type_id": "arrow_tower", "behavior_kind": "attack",
		"element": "physical", "evolution": "", "advancement": "", "freeze_upgraded": true,
		"range": 3.0, "base_damage": 100.0, "base_interval": 1.0, "interval": 1.0,
		"cooldown": 0.4, "damage_multiplier": 1.0, "speed_multiplier": 1.0, "crit_chance": 0.0,
		"branch_pierce": 0, "behavior_config": {}, "effective_attack_config": {}
	}
	match filter_name:
		"ballista", "physical_ballista": tower["type_id"] = "orc_ballista"
		"rune", "pulsed_rune":
			tower["type_id"] = "rune_obelisk"
			if filter_name == "pulsed_rune": tower["evolution"] = "onyx_ring"
		"lightning":
			tower["type_id"] = "lightning"
			tower["behavior_kind"] = "chain"
			tower["element"] = "lightning"
			tower["behavior_config"] = {"hit_count": 2, "jump_distance": 2.0}
		"orcapult":
			tower["type_id"] = "orcapult"
			tower["behavior_kind"] = "catapult"
			tower["behavior_config"] = {"lift": 1.0, "throw_count": 1}
		"drums", "forge", "command_banner", "lookout_horn", "bloodlust_totem":
			tower["type_id"] = "war_drums"
			tower["behavior_kind"] = "support"
			tower["evolution"] = "" if filter_name == "drums" else filter_name
			tower["behavior_config"] = {"damage_bonus": 0.2, "attack_speed_bonus": 0.2, "range_aura": 0.0, "crit_chance": 0.0}
			if filter_name != "drums":
				tower["behavior_config"] = {"damage_bonus": 0.0, "attack_speed_bonus": 0.0, "range_aura": 0.0, "crit_chance": 0.0}
				var key: String = {"forge": "damage_bonus", "command_banner": "attack_speed_bonus", "lookout_horn": "range_aura", "bloodlust_totem": "crit_chance"}[filter_name]
				tower["behavior_config"][key] = 1.0 if filter_name == "lookout_horn" else 0.2
		"fire", "fire_arrow": tower["element"] = "fire"
		"explosive_arrow", "grenade_rocket_arrow", "molotov", "flamethrower":
			tower["element"] = "fire"
			var weapon: String = "rocket" if filter_name in ["explosive_arrow", "grenade_rocket_arrow"] else filter_name
			tower["effective_attack_config"] = {"weapon": weapon, "splash_radius": 1.0, "burn_duration": 4.0, "burn_dps": 5.0, "continuous_dps": 10.0}
	return tower


func _apply(combat: MatchCombat, tower: Dictionary) -> void:
	combat.item_runtime.stats.prepare_tower(0, tower)
	combat.item_runtime.stats.finish_tower(0, tower, 1.0)


func _test_individual_stats() -> void:
	var combat: MatchCombat = MatchCombat.new(rules)
	var covered: Dictionary = {}
	for row: Array in CASES:
		var identity: String = row[0]
		var filter_name: String = row[1]
		var expected: Dictionary = row[2]
		_check(combat.set_items(0, [identity]), "Equip isolated %s" % identity)
		var tower: Dictionary = _fixture(filter_name)
		_check(ItemStatEffects.matches_filter(tower, filter_name), "%s positive filter fixture" % identity)
		_apply(combat, tower)
		covered[identity] = true
		for key: String in expected:
			var actual: float = 0.0
			if key == "support":
				actual = float(tower["behavior_config"]["damage_bonus"]) / 0.2
				_near(float(tower["behavior_config"]["attack_speed_bonus"]) / 0.2, float(expected[key]), identity + " retained speed component")
			elif key == "support_crit": actual = float(tower["behavior_config"]["crit_chance"])
			elif tower["behavior_config"].has(key): actual = float(tower["behavior_config"][key])
			elif tower["effective_attack_config"].has(key): actual = float(tower["effective_attack_config"][key])
			else: actual = float(tower[key])
			_near(actual, float(expected[key]), identity + " " + key)
		_near(float(tower["cooldown"]), 0.4 * float(tower["interval"]), identity + " rescales cooldown exactly once")
		var passive: Dictionary = _fixture("drums" if filter_name not in ItemStatEffects.SUPPORT_FILTERS else "attacking")
		var before: Dictionary = passive.duplicate(true)
		_apply(combat, passive)
		_near(float(passive["range"]), float(before["range"]), identity + " never changes ineligible coverage/range")
		_near(float(passive["speed_multiplier"]), 1.0, identity + " does not speed ineligible tower")
		_near(float(passive["damage_multiplier"]), 1.0, identity + " does not damage-buff ineligible tower")
	for definition: ItemDefinition in rules.catalog.items:
		if definition.runtime.has("stats"):
			_check(covered.has(String(definition.id)), "%s has an independently expected behavioral case" % definition.id)


func _test_composition_and_boundaries() -> void:
	var combat: MatchCombat = MatchCombat.new(rules)
	_check(combat.set_items(0, ["iron_arrowhead", "steel_arrowhead", "heavy_ammunition", "oiled_gears", "oversized_bucket"]), "Mixed products equipped")
	var tower: Dictionary = _fixture("orcapult")
	_apply(combat, tower)
	_near(float(tower["damage_multiplier"]), 1.05 * 1.1 * 1.12, "Damage products have no additive shortcut")
	_near(float(tower["interval"]), 1.2 / (1.05 * 0.95), "Reload is interval product, rate is divisor")
	_check(combat.set_items(0, ["lucky_fang", "gamblers_lens", "moon_salt_jerky", "perfect_scope", "vermilion_war_sash", "jewelers_torque", "empresss_warcoat"]), "Crit items compose")
	tower = _fixture("attacking")
	tower["crit_chance"] = 0.7
	_apply(combat, tower)
	_near(float(tower["crit_chance"]), 0.75, "Discrete chance caps at existing 75 percent")
	_near(float(tower["crit_damage_multiplier"]), 2.0 * 1.4 * 1.2 * 1.45, "Crit damage multiplies critical factor, not chance")
	_check(combat.set_items(0, ["vermilion_war_sash"]), "Equip crit drawback")
	tower = _fixture("attacking")
	_apply(combat, tower)
	_near(float(tower["crit_chance"]), 0.0, "Crit chance lower boundary is zero")
	_check(combat.set_items(0, ["flint_striker"]), "Equip direct-only Flint")
	tower = _fixture("flamethrower")
	_apply(combat, tower)
	_near(float(tower["effective_attack_config"]["continuous_dps"]), 10.8, "Flint scales direct continuous Fire stream")
	_near(float(tower["effective_attack_config"]["burn_dps"]), 5.0, "Flint excludes burn DPS")
	var physical: Dictionary = _fixture("physical_ballista")
	_check(ItemStatEffects.matches_filter(physical, "physical_ballista"), "Physical Ballista initially eligible")
	physical["element"] = "magic"
	_check(not ItemStatEffects.matches_filter(physical, "physical_ballista"), "Element evolution removes Physical eligibility")
	for filter_name: String in ["projectile", "explosive_arrow", "grenade_rocket_arrow", "molotov", "pulsed_rune"]:
		var negative: Dictionary = _fixture("flamethrower" if filter_name != "pulsed_rune" else "rune")
		_check(not ItemStatEffects.matches_filter(negative, filter_name), filter_name + " excludes wrong continuous branch")
	_check(combat.set_items(0, ["choir_of_empty_helmets", "empty_throne"]), "Equip neighborhood items")
	tower = _fixture("attacking")
	combat.towers[0].assign([tower])
	for index: int in range(5):
		var other: Dictionary = _fixture("drums")
		other["id"] = index
		other["type_id"] = "identity_%d" % index
		other["cell"] = Vector2i(6, 5)
		combat.towers[0].append(other)
	_apply(combat, tower)
	_near(float(tower["damage_multiplier"]), 1.32 * 1.6, "Choir caps four distinct nearby identities; passive neighbors permit Throne")
	var attacker: Dictionary = _fixture("attacking")
	attacker["id"] = 200
	attacker["cell"] = Vector2i(6, 6)
	combat.towers[0].append(attacker)
	var refreshed: Dictionary = _fixture("attacking")
	_apply(combat, refreshed)
	_near(float(refreshed["damage_multiplier"]), 1.32, "Diagonal attacking neighbor disables Throne")
	attacker["cell"] = Vector2i(7, 6)
	refreshed = _fixture("attacking")
	_apply(combat, refreshed)
	_near(float(refreshed["damage_multiplier"]), 1.32 * 1.6, "Nonadjacent attacker permits Throne")
	combat.towers[0].clear()


func _built(combat: MatchCombat, cell: Vector2i, type_id: StringName, commands: Array) -> Dictionary:
	_check(combat.build(0, cell, type_id, MatchCombat.TargetMode.FURTHEST), "Build real %s" % type_id)
	var tower: Dictionary = combat.towers[0].back()
	for command: String in commands:
		_check(combat.upgrade_tower(0, tower["id"], command), "Upgrade real %s %s" % [type_id, command])
	return tower


func _start_stat_wave(combat: MatchCombat) -> void:
	var route: Array[Vector2i] = [Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: [route[3]], route[3]: [route[4]], route[4]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	_check(combat.sandbox_start(routing, 1, [] as Array[String]), "Real stat-consumer wave starts")


func _test_real_explosive_eligibility() -> void:
	var combat: MatchCombat = MatchCombat.new(rules)
	var tower: Dictionary = _built(combat, Vector2i(5, 5), &"arrow_tower", ["damage", "speed", "special"])
	var branches: Array[String] = ["bomb_arrows", "bigger_bombs", "anti_orc_grenades", "aom"]
	var radii: Array[float] = [0.85, 1.25, 1.5, 2.5]
	var subsets: Array = [[], ["packed_powder"], ["besiegers_powder_horn"], ["packed_powder", "besiegers_powder_horn"]]
	_start_stat_wave(combat)
	_check(combat.sandbox_spawn(0, &"grunt", 2), "Real explosive consumers get two ordinary targets")
	var primary: Dictionary = combat.enemies[0][0]
	var neighbor: Dictionary = combat.enemies[0][1]
	primary["pos"] = Vector2(5, 6)
	for index: int in range(branches.size()):
		_check(combat.set_items(0, []), "Clear powder between real branch upgrades")
		_check(combat.upgrade_tower(0, tower["id"], branches[index]), "Buy real explosive branch %s" % branches[index])
		var baseline_rate: float = tower["speed_multiplier"]
		for ids: Array in subsets:
			_check(combat.set_items(0, ids), "Equip real explosive subset %s" % [ids])
			var eligible: int = int("packed_powder" in ids) + int(index >= 2 and "besiegers_powder_horn" in ids)
			_near(float(tower["effective_attack_config"]["splash_radius"]), radii[index] * pow(1.2, eligible), "%s radius with %s" % [branches[index], ids])
			_near(float(tower["speed_multiplier"]), baseline_rate * pow(0.9, eligible), "%s rate drawback with %s" % [branches[index], ids])
			if index < 2:
				# One tile is outside Bomb Arrows; sqrt(2) is outside Bigger Bombs.
				# Both become reachable only when Packed Powder really enlarges the blast.
				neighbor["pos"] = Vector2(6, 6) if index == 0 else Vector2(6, 7)
				primary["hp"] = 1000000
				neighbor["hp"] = 1000000
				combat._attack_arrow(0, tower, int(primary["id"]), primary["pos"], tower["effective_attack_config"])
				_check((int(neighbor["hp"]) < 1000000) == ("packed_powder" in ids), "%s real splash hits its newly reachable neighbor only with Packed Powder: %s" % [branches[index], ids])
	for commands: Array in [
		["damage", "speed", "special"],
		["damage", "speed", "special", "fire_arrows", "molotov"],
		["damage", "speed", "special", "fire_arrows", "molotov", "quick_pitch", "flamethrower"]
	]:
		var excluded: MatchCombat = MatchCombat.new(rules)
		var other: Dictionary = _built(excluded, Vector2i(5, 5), &"arrow_tower", commands)
		var baseline: Dictionary = other["effective_attack_config"].duplicate(true)
		var baseline_rate: float = other["speed_multiplier"]
		_check(excluded.set_items(0, ["packed_powder", "besiegers_powder_horn"]), "Equip powders on non-explosive real Arrow branches")
		_check(other["effective_attack_config"] == baseline, "Ordinary arrows, Molotovs and Flamethrowers retain authored attack configuration")
		_near(float(other["speed_multiplier"]), baseline_rate, "Powders never penalize non-explosive real branches")


func _test_real_lift_classes() -> void:
	var cases: Array = [
		[[], 1.0, 2.5, "brute", true],
		[["damage", "speed", "special", "siege_arm"], 2.5, 3.5, "rage_orc", true],
		[["damage", "speed", "special", "siege_arm", "iron_counterweight"], 3.5, 6.0, "orc_chief", true],
		[["damage", "speed", "special", "siege_arm", "iron_counterweight", "ogre_crew", "warlords_trebuchet"], 6.0, 6.0, "greater_shaorc", false],
		[["damage", "speed", "special", "long_toss"], 2.5, 3.5, "rage_orc", true],
		[["damage", "speed", "special", "long_toss", "greased_sling", "rude_awakening", "over_the_wall"], 3.5, 6.0, "orc_chief", true]
	]
	for row: Array in cases:
		var combat: MatchCombat = MatchCombat.new(rules)
		var tower: Dictionary = _built(combat, Vector2i(5, 5), &"orcapult", row[0])
		_near(float(tower["behavior_config"]["lift"]), float(row[1]), "Real Orcapult starts in its authored lift class")
		var slam: float = tower["damage"]
		var landing: float = tower["behavior_config"]["landing_progress"]
		_check(combat.set_items(0, ["heartwood_siege_arm"]), "Equip Heartwood on real lift progression")
		_near(float(tower["behavior_config"]["lift"]), float(row[2]), "Heartwood advances exactly one authored arm-capacity class")
		_near(float(tower["damage"]), slam, "Heartwood does not alter slam damage")
		_near(float(tower["behavior_config"]["landing_progress"]), landing, "Heartwood does not alter throw distance")
		combat.item_recompute(0)
		_near(float(tower["behavior_config"]["lift"]), float(row[2]), "Repeated refresh never compounds lift classes")
		_start_stat_wave(combat)
		combat._spawn_enemy(0, row[3], 1.0, combat._elapsed)
		var enemy: Dictionary = combat.enemies[0].back()
		tower["cooldown"] = 0.0
		combat._attack_catapult(0, tower, 0.0)
		_check((combat.flights.size() == 1) == bool(row[4]), "Actual catapult launch respects the next authored lift class and its ceiling")
		if bool(row[4]):
			_check(int(combat.flights[0]["enemy"]["id"]) == int(enemy["id"]), "The heavier real enemy, not a substitute, is launched")
		else:
			_check(combat.enemies[0].has(enemy), "Enemies beyond the top authored lift class remain on their route")
		_check(combat.set_items(0, []), "Remove Heartwood after the real launch")
		_near(float(tower["behavior_config"]["lift"]), float(row[1]), "Removing Heartwood restores the authored capacity")
	var boss_combat: MatchCombat = MatchCombat.new(rules)
	var arm: Dictionary = _built(boss_combat, Vector2i(5, 5), &"orcapult", [])
	_check(boss_combat.set_items(0, ["heartwood_siege_arm", "leviathan_anchor"]), "Heartwood and Anchor coexist on a real arm")
	_near(float(arm["behavior_config"]["lift"]), 2.5, "Anchor composition retains base Brute eligibility")
	_start_stat_wave(boss_combat)
	boss_combat._spawn_enemy(0, "grand_mage_orcafus", 1.0, boss_combat._elapsed)
	var boss: Dictionary = boss_combat.enemies[0].back()
	_check(not MatchCombat.throwable(boss, boss_combat._enemy_types[boss["type_id"]], INF), "The actual lift consumer rejects a real boss regardless of capacity")
	arm["cooldown"] = 0.0
	boss_combat._attack_catapult(0, arm, 0.0)
	_check(boss_combat.flights.is_empty(), "Heartwood plus Anchor never launches a boss")


func _test_real_crit_composition() -> void:
	var combat: MatchCombat = MatchCombat.new(rules)
	var totem: Dictionary = _built(combat, Vector2i(5, 5), &"war_drums", ["damage", "speed", "bloodlust_totem", "sharpened_hooks", "blood_frenzy", "skullsplitter_totem"])
	var attacker: Dictionary = _built(combat, Vector2i(6, 5), &"arrow_tower", [])
	var cases: Array = [
		[["vermilion_war_sash"], 0.3, 0.25],
		[["forbidden_beat", "vermilion_war_sash"], 0.6, 0.55],
		[["forbidden_beat", "saints_marrow_flute"], 0.9, 0.75],
		[["forbidden_beat", "saints_marrow_flute", "vermilion_war_sash"], 0.9, 0.75]
	]
	for row: Array in cases:
		_check(combat.set_items(0, row[0]), "Equip real Totem crit subset %s" % [row[0]])
		_near(float(totem["behavior_config"]["crit_chance"]), float(row[1]), "Real Totem retains raw multiplied aura strength")
		_near(float(attacker["crit_chance"]), float(row[2]), "Aura and item additions compose before one final chance clamp")
		combat.item_recompute(0)
		_near(float(attacker["crit_chance"]), float(row[2]), "Crit refresh never compounds aura or subtracts Sash twice")
	_start_stat_wave(combat)
	_check(combat.sandbox_spawn(0, &"grunt", 1), "Actual critical-hit consumer gets a real ordinary enemy")
	var enemy: Dictionary = combat.enemies[0][0]
	enemy["hp"] = 1000000
	enemy["max_hp"] = 1000000
	var oracle: RandomNumberGenerator = RandomNumberGenerator.new()
	oracle.seed = 90210
	combat._crit_random.seed = 90210
	var distinguished: bool = false
	for index: int in range(256):
		var roll: float = oracle.randf()
		distinguished = distinguished or (roll >= 0.7 and roll < 0.75)
		var before: int = enemy["hp"]
		_check(combat._hit(0, attacker, 0, 10), "Accepted discrete hit consumes composed final crit chance")
		_check(before - int(enemy["hp"]) == (28 if roll < 0.75 else 10), "Actual Sash hit follows final 75-percent chance, not a prematurely capped 70-percent chance")
	_check(distinguished, "Deterministic hit sequence exercises the premature-cap gap")


func _test_real_refresh_support_and_continuous() -> void:
	var combat: MatchCombat = MatchCombat.new(rules)
	var forge: Dictionary = _built(combat, Vector2i(5, 5), &"war_drums", ["damage", "speed", "forge"])
	var weak: Dictionary = _built(combat, Vector2i(5, 6), &"war_drums", [])
	var attacker: Dictionary = _built(combat, Vector2i(6, 5), &"arrow_tower", [])
	var source_range: float = forge["range"]
	_check(combat.set_items(0, ["taut_drumskin", "resonant_drumsticks", "reed_warpipes", "forbidden_beat", "smith_kings_hammer"]), "Support products equipped")
	var strength: float = 1.05 * 1.12 * 1.15 * 2.0
	_near(float(forge["behavior_config"]["damage_bonus"]), 0.5 * strength * 1.25, "Retained Forge component strengthened before maximum")
	_near(float(attacker["support_damage_bonus"]), 0.5 * strength * 1.25, "Strongest source wins, no sum with weaker mixed Drums")
	_near(float(forge["behavior_config"]["attack_speed_bonus"]), 0.0, "Pure Forge never acquires speed")
	_near(float(forge["range"]), source_range, "Support coverage never extended")
	_near(float(weak["range"]), 2.0, "Other source coverage remains authored")
	attacker["cooldown"] = float(attacker["interval"]) * 0.4
	var before: Dictionary = attacker.duplicate(true)
	for index: int in range(8):
		combat.item_recompute(0)
	_near(float(attacker["damage_multiplier"]), float(before["damage_multiplier"]), "Repeated refresh never compounds item damage/support")
	_near(float(attacker["interval"]), float(before["interval"]), "Repeated refresh never compounds attack rate")
	_near(float(attacker["cooldown"]), float(before["cooldown"]), "Repeated refresh preserves exact cooldown fraction")
	var stream: MatchCombat = MatchCombat.new(rules)
	var rune: Dictionary = _built(stream, Vector2i(5, 5), &"rune_obelisk", ["damage", "speed", "boulders"])
	var all_ids: Array = []
	for definition: ItemDefinition in rules.catalog.items:
		all_ids.append(String(definition.id))
	_check(stream.set_items(0, all_ids) and stream.item_runtime.owned_ids(0).size() == 130, "All 130 items coexist on one player without a cap")
	_check(float(rune["speed_multiplier"]) > 1.0 and is_finite(float(rune["damage_multiplier"])), "All-item continuous stats are finite and retain real rate modifiers")
	var route: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: [route[3]], route[3]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	_check(stream.sandbox_start(routing, 1, [] as Array[String]), "All-item continuous wave starts")
	stream.sandbox_spawn(0, &"grunt", 1)
	if stream.enemies[0].is_empty():
		_check(false, "All-item stream enemy spawned")
		return
	var enemy: Dictionary = stream.enemies[0][0]
	enemy["hp"] = 1000000
	enemy["max_hp"] = 1000000
	var starting_hp: int = enemy["hp"]
	stream.advance(0.25)
	_check(int(enemy["hp"]) < starting_hp, "All-item continuous attack removes real enemy HP")
	var isolated: MatchCombat = MatchCombat.new(rules)
	var plain: Dictionary = _built(isolated, Vector2i(5, 5), &"rune_obelisk", ["damage", "speed", "boulders"])
	_check(isolated.set_items(0, ["heartwood_cutting"]), "Continuous Rune gets rate-only item")
	_near(float(plain["speed_multiplier"]), 1.12, "Continuous Rune rate increases by exactly twelve percent")
	_check(isolated.sandbox_start(routing, 1, [] as Array[String]), "Rate-only continuous wave starts")
	isolated.sandbox_spawn(0, &"grunt", 1)
	var victim: Dictionary = isolated.enemies[0][0]
	victim["hp"] = 1000000
	victim["max_hp"] = 1000000
	var dps: float = float(plain["base_damage"]) * float(plain["damage_multiplier"]) * 1.12
	isolated.advance(2.0)
	_check(1000000 - int(victim["hp"]) >= floori(dps * 2.0) - 1, "Attack-rate modifier actually scales continuous HP removal")
