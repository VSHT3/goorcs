extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_progression_economics()
	_test_exclusive_nested_branches()
	_test_passive_roles()
	_test_stage_index()
	_test_flat_advancement_chains()
	_test_isolation_and_reconfiguration()
	_test_invalid_inputs()
	if failures == 0:
		print("PASS: Towerieary real-owner baseline stats, exact progression economics, exclusive followups, passive roles, detached captures, and honest invalid inputs")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _tower(id: StringName) -> TowerDefinition:
	var definition := TowerDefinition.new()
	definition.reward = TowerReward.new()
	definition.reward.id = id
	definition.reward.title = "Fixture " + String(id)
	definition.reward.description = "An injected reference tower."
	definition.damage = 7
	definition.interval = 1.6
	definition.range_cells = 4.0
	definition.cost = 73
	definition.upgrade_base_cost = 37
	definition.damage_upgrade_bonus = 5
	definition.speed_upgrade_multiplier = 0.625
	return definition


func _fixture() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog = ContentCatalog.new()
	var enemy := EnemyDefinition.new()
	enemy.id = &"guide_remainder"
	enemy.title = "Guide remainder"
	rules.catalog.enemies = [enemy]
	var arrow: TowerDefinition = _tower(&"guide_archers")
	arrow.special_upgrade = "second_archer"
	arrow.special_upgrade_title = "Twin sentries"
	arrow.special_upgrade_cost = 83
	arrow.reward.icon_texture = preload("res://resources/content_catalog.tres").towers[0].reward.icon_texture
	arrow.reward.board_variants = {"second_archer": {"texture": arrow.reward.icon_texture, "board_height": 1.1, "board_anchor": Vector2(0.5, 0.9)}}
	arrow.advancements = {
		"four_archers": {"title": "Four sentries", "cost": 101, "archer_count": 4, "attack_rate_multiplier": 1.25},
		"fire_arrows": {"title": "Embers", "cost": 103, "burn_dps": 5.0, "burn_duration": 3.2},
		"bomb_arrows": {"title": "Explosives", "cost": 107, "primary_multiplier": 2.2, "splash_multiplier": 0.4, "splash_radius": 1.4},
	}
	var ballista: TowerDefinition = _tower(&"guide_bolts")
	ballista.evolutions = {"pierce": {"title": "Straight bolt", "cost": 131}, "bounce": {"title": "Redirected bolt", "cost": 133}}
	var rune: TowerDefinition = _tower(&"guide_stones")
	rune.area_attack = true
	rune.damage = 4
	rune.interval = 0.9
	rune.cost = 71
	rune.upgrade_base_cost = 31
	rune.evolutions = {
		"boulders": {"title": "Rolling stones", "cost": 137, "damage": 23, "interval": 0.0, "continuous": true, "followup": {"id": "freeze_runes", "title": "Frost stones", "cost": 139}},
		"onyx_ring": {"title": "Heavy pulses", "cost": 149, "damage": 29, "interval": 1.3, "continuous": false},
	}
	var chain: TowerDefinition = _tower(&"guide_chain")
	chain.behavior_kind = "chain"
	chain.behavior_config = {"hit_count": 5, "jump_distance": 2.5, "successive_hit_bonus": 0.07}
	chain.special_upgrade = "escalating_chain"
	chain.special_upgrade_title = "Rising current"
	chain.special_upgrade_cost = 83
	chain.special_upgrade_config = {"successive_hit_bonus": 0.2}
	chain.evolutions = {"longer_reach": {"title": "Distant current", "cost": 151, "behavior_kind": "chain", "range_cells": 8.0, "behavior_config": {"hit_count": 6, "jump_distance": 6.0, "successive_hit_bonus": 0.07}}}
	var support: TowerDefinition = _tower(&"guide_aura")
	support.damage = 0
	support.behavior_kind = "support"
	support.roll_profile = "support"
	support.behavior_config = {"stack_group": "guide_forge", "damage_bonus": 0.11, "attack_speed_bonus": 0.17}
	support.upgrade_effects = {"damage": {"damage_bonus": 0.07}, "speed": {"attack_speed_bonus": 0.13}}
	support.evolutions = {
		"forge": {"title": "Fixture forge", "cost": 153, "behavior_kind": "support", "behavior_config": {"stack_group": "guide_forge", "damage_bonus": 0.41, "attack_speed_bonus": 0.0}},
		"command_banner": {"title": "Fixture banner", "cost": 155, "behavior_kind": "support", "behavior_config": {"stack_group": "guide_forge", "damage_bonus": 0.0, "attack_speed_bonus": 0.53}},
	}
	var mine: TowerDefinition = _tower(&"guide_income")
	mine.damage = 0
	mine.behavior_kind = "economy"
	mine.roll_profile = "economy"
	mine.behavior_config = {"clear_income": 11, "periodic_income": 0, "periodic_interval": 0.0}
	mine.upgrade_effects = {"damage": {"income_bonus": 0.25}, "speed": {"income_bonus": 0.4}}
	mine.evolutions = {
		"royal_mint": {"title": "Fixture mint", "cost": 157, "behavior_kind": "economy", "behavior_config": {"clear_income": 17, "periodic_income": 7, "periodic_interval": 2.75}},
		"bounty_board": {"title": "Fixture board", "cost": 163, "behavior_kind": "bounty", "behavior_config": {"mark_damage_bonus": 0.23, "mark_income_bonus": 0.35}, "followups": {
			"stronger_mark": {"title": "Fixture greater mark", "cost": 167, "behavior_kind": "bounty", "behavior_config": {"mark_damage_bonus": 0.47, "mark_income_bonus": 0.61}},
			"income_aura": {"title": "Fixture tribute", "cost": 173, "behavior_kind": "income_aura", "behavior_config": {"stack_group": "guide_tribute", "kill_income_bonus": 0.43}},
		}},
	}
	rules.catalog.towers = [arrow, ballista, rune, chain, support, mine]
	rules.starting_coins = 3
	rules.sandbox_mode = true
	return rules


func _guide(rules: CombatRules) -> TowerGuide:
	var guide := TowerGuide.new()
	guide.configure(rules.catalog, rules)
	_check(guide.error_message.is_empty() and guide.entries.size() == 6, "Explicit six-role fixtures configure without shipped identity assumptions")
	return guide


func _costs(preview: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for step: Dictionary in preview.get("steps", []):
		result.append(int(step["cost"]))
	return result


func _commands(preview: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for step: Dictionary in preview.get("steps", []):
		result.append(step["command"])
	return result


func _test_progression_economics() -> void:
	var rules: CombatRules = _fixture()
	var guide: TowerGuide = _guide(rules)
	var base: Dictionary = guide.preview(&"guide_archers")
	_check(not base.is_empty(), "Base preview exists even when source rules are poor and in Sandbox")
	if base.is_empty():
		return
	_check(base["stats"]["damage"] == 7 and base["stats"]["cost"] == 73 and base["stats"]["upgrade_base_cost"] == 37, "Captured type stats retain injected damage and non-default prices")
	_check(base["tower"]["damage"] == 7 and is_equal_approx(base["tower"]["interval"], 1.6) and base["tower"]["range"] == 4.0, "Effective base stats come from isolated unrolled combat state")
	_check(base["total_cost"] == 73 and base["tower"]["invested"] == 73 and base["steps"].is_empty(), "Base price appears exactly once despite source Sandbox mode")
	var damage: Dictionary = guide.preview(&"guide_archers", "damage")
	var speed: Dictionary = guide.preview(&"guide_archers", "speed")
	_check(damage["tower"]["damage"] == 12 and not damage["tower"]["speed_upgraded"] and damage["total_cost"] == 110 and _costs(damage) == [37], "Damage-only reference has its own first-purchase economics")
	_check(speed["tower"]["damage"] == 7 and is_equal_approx(speed["tower"]["interval"], 1.0) and speed["total_cost"] == 110 and _costs(speed) == [37], "Speed-only reference never inherits a prior damage selection or level-II price")
	var both: Dictionary = guide.preview(&"guide_archers", "damage/speed")
	_check(both["tower"]["damage"] == 12 and is_equal_approx(both["tower"]["interval"], 1.0) and _costs(both) == [37, 56] and both["total_cost"] == 166, "Both-upgrade display includes exact rounded second-charge, not twice the base upgrade price")
	var special: Dictionary = guide.preview(&"guide_archers", "damage/speed/special")
	_check(_costs(special) == [37, 56, 83] and special["total_cost"] == 249 and is_equal_approx(special["tower"]["interval"], 1.0 / 1.1), "Special price and second-archer attack-rate change are real-owner values")
	var four: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/four_archers")
	_check(_commands(four) == ["damage", "speed", "special", "four_archers"] and _costs(four) == [37, 56, 83, 101] and four["total_cost"] == 350, "Advancement shows every accepted prerequisite and exact final investment")
	_check(four["stage"]["parent_id"] == "damage/speed/special" and four["tower"]["extra_archers"].size() == 2 and is_equal_approx(four["tower"]["interval"], 1.0 / 1.1 / 1.25), "Four-archer stage is nested under the special and retains its real streams/rate")
	for step: Dictionary in four["steps"]:
		_check(not String(step["title"]).is_empty(), "Every priced progression step has a consumable title")


func _test_exclusive_nested_branches() -> void:
	var guide: TowerGuide = _guide(_fixture())
	var pierce: Dictionary = guide.preview(&"guide_bolts", "damage/speed/pierce")
	var bounce: Dictionary = guide.preview(&"guide_bolts", "damage/speed/bounce")
	_check(pierce["tower"]["evolution"] == "pierce" and bounce["tower"]["evolution"] == "bounce" and pierce["total_cost"] == 297 and bounce["total_cost"] == 299, "Exclusive bolt branches use distinct accepted states and distinct authored charges")
	var freeze: Dictionary = guide.preview(&"guide_stones", "damage/speed/boulders/freeze_runes")
	var onyx: Dictionary = guide.preview(&"guide_stones", "damage/speed/onyx_ring")
	_check(_commands(freeze) == ["damage", "speed", "boulders", "freeze_runes"] and _costs(freeze) == [31, 47, 137, 139] and freeze["total_cost"] == 425, "Singular followup includes only its chosen evolution and exact prerequisite economics")
	_check(freeze["tower"]["freeze_upgraded"] and freeze["tower"]["damage"] == 23 and freeze["tower"]["interval"] == 0.0 and freeze["stage"]["parent_id"] == "damage/speed/boulders", "Freeze consumes the continuous branch baseline, not invented finite DPS")
	_check(not onyx["tower"]["freeze_upgraded"] and onyx["tower"]["damage"] == 29 and is_equal_approx(onyx["tower"]["interval"], 1.3) and onyx["total_cost"] == 298, "Alternate Rune branch is pulse-based and never inherits freeze")
	var fire: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/fire_arrows")
	var bomb: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/bomb_arrows")
	_check(fire["tower"]["advancement"] == "fire_arrows" and fire["total_cost"] == 352 and bomb["tower"]["advancement"] == "bomb_arrows" and bomb["total_cost"] == 356, "Exclusive archer advancement selections never combine sibling mechanics or charges")
	var reach: Dictionary = guide.preview(&"guide_chain", "damage/speed/special/longer_reach")
	_check(_costs(reach) == [37, 56, 83, 151] and reach["total_cost"] == 400 and reach["stage"]["parent_id"] == "damage/speed/special", "Lightning evolution requires and charges its distinct special first")
	_check(reach["tower"]["range"] == 8.0 and reach["tower"]["behavior_config"]["jump_distance"] == 6.0 and is_equal_approx(reach["tower"]["behavior_config"]["successive_hit_bonus"], 0.27), "Longer Reach retains accepted branch geometry and the special's escalation")
	_check(guide.preview(&"guide_stones", "damage/speed/onyx_ring/freeze_runes").is_empty() and not guide.error_message.is_empty(), "Impossible sibling-followup selection fails honestly")


func _test_passive_roles() -> void:
	var guide: TowerGuide = _guide(_fixture())
	var aura: Dictionary = guide.preview(&"guide_aura", "damage/speed")
	var forge: Dictionary = guide.preview(&"guide_aura", "damage/speed/forge")
	var banner: Dictionary = guide.preview(&"guide_aura", "damage/speed/command_banner")
	_check(aura["tower"]["damage"] == 0 and is_equal_approx(aura["tower"]["behavior_config"]["damage_bonus"], 0.18) and is_equal_approx(aura["tower"]["behavior_config"]["attack_speed_bonus"], 0.30), "Support previews expose purchased aura components rather than manufacturing attack DPS")
	_check(is_equal_approx(forge["tower"]["behavior_config"]["damage_bonus"], 0.61) and forge["tower"]["behavior_config"]["attack_speed_bonus"] == 0.0 and forge["total_cost"] == 319, "Forge transfers both purchased components into its surviving damage aura")
	_check(banner["tower"]["behavior_config"]["damage_bonus"] == 0.0 and is_equal_approx(banner["tower"]["behavior_config"]["attack_speed_bonus"], 0.73) and banner["total_cost"] == 321, "Command Banner independently transfers purchases into speed aura")
	var mine: Dictionary = guide.preview(&"guide_income", "damage/speed")
	var mint: Dictionary = guide.preview(&"guide_income", "damage/speed/royal_mint")
	_check(mine["tower"]["damage"] == 0 and mine["tower"]["behavior_config"]["clear_income"] == 19, "Economy upgrades expose actual rounded Coin production, not damage upgrades")
	_check(mint["tower"]["behavior_config"]["clear_income"] == 29 and mint["tower"]["behavior_config"]["periodic_income"] == 12 and mint["tower"]["behavior_config"]["periodic_interval"] == 2.75 and mint["total_cost"] == 323, "Mint preview retains both rounded production amounts and simulation interval")
	var mark: Dictionary = guide.preview(&"guide_income", "damage/speed/bounty_board/stronger_mark")
	var tribute: Dictionary = guide.preview(&"guide_income", "damage/speed/bounty_board/income_aura")
	_check(_costs(mark) == [37, 56, 163, 167] and mark["total_cost"] == 496 and mark["tower"]["behavior_kind"] == "bounty" and is_equal_approx(mark["tower"]["behavior_config"]["mark_income_bonus"], 1.0065), "Plural stronger-mark followup preserves compounded purchased economy effects and exact path")
	_check(_costs(tribute) == [37, 56, 163, 173] and tribute["total_cost"] == 502 and tribute["tower"]["behavior_kind"] == "income_aura" and is_equal_approx(tribute["tower"]["behavior_config"]["kill_income_bonus"], 0.7095), "Plural tribute followup replaces marking with accepted killing-location income behavior")
	_check(mark["stage"]["parent_id"] == "damage/speed/bounty_board" and tribute["stage"]["parent_id"] == mark["stage"]["parent_id"] and not tribute["tower"]["behavior_config"].has("mark_damage_bonus"), "Bounty followups share a parent but never share applied sibling state")


func _test_stage_index() -> void:
	var guide: TowerGuide = _guide(_fixture())
	var expected_counts: Dictionary = {
		&"guide_archers": 8, &"guide_bolts": 6, &"guide_stones": 7,
		&"guide_chain": 6, &"guide_aura": 6, &"guide_income": 8,
	}
	for record: Dictionary in guide.entries:
		var ids: Dictionary = {}
		_check(record["stages"].size() == expected_counts[record["id"]], "Index exposes every independent upgrade and authored branch/followup")
		for stage: Dictionary in record["stages"]:
			_check(not ids.has(stage["id"]), "Distinct selectable stages have unique IDs")
			_check(stage["parent_id"] == "" or ids.has(stage["parent_id"]), "Selectable progression parents exist before their children")
			ids[stage["id"]] = true



func _test_flat_advancement_chains() -> void:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres")
	var guide := TowerGuide.new()
	guide.configure(rules.catalog, rules)
	var definition: TowerDefinition = rules.catalog.towers[0]
	var record: Dictionary = guide.entry(definition.reward.id)
	var visited: Dictionary = {}
	for stage: Dictionary in record["stages"]:
		var commands: Array = stage["commands"]
		if commands.is_empty() or not definition.advancements.has(commands.back()):
			continue
		var command: String = commands.back()
		var config: Dictionary = definition.advancements[command]
		var preview: Dictionary = guide.preview(definition.reward.id, stage["id"])
		_check(not preview.is_empty(), "Every flat advancement can be purchased through the real owner")
		if preview.is_empty():
			continue
		visited[command] = true
		var history: Array = commands.slice(3)
		_check(preview["tower"]["advancement_path"] == history and preview["tower"]["advancement"] == command, "Accepted branch history includes every prerequisite, root onward")
		_check(int(preview["steps"].back()["cost"]) == int(config["cost"]) and preview["steps"].back()["title"] == config["title"], "Flat node title and exact price come from the authored config")
		var sum: int = int(preview["stats"]["cost"])
		for step: Dictionary in preview["steps"]:
			sum += int(step["cost"])
		_check(sum == int(preview["total_cost"]), "Deep branch total includes every actual charge once")
		var requires: String = String(config.get("requires", ""))
		if not requires.is_empty():
			_check(commands[commands.size() - 2] == requires and stage["parent_id"] == "/".join(commands.slice(0, commands.size() - 1)), "Recursive prerequisite ancestry supplies the immediate connected graph parent")
	_check(visited.size() == definition.advancements.size() and visited.size() == 13, "Guide exposes all thirteen Arrow branch tiers")

func _test_isolation_and_reconfiguration() -> void:
	var rules: CombatRules = _fixture()
	rules.sandbox_mode = false
	rules.starting_coins = 10000
	var rolls := TowerRollRules.new()
	rules.roll_rules = rolls
	var live_rules := rules.duplicate() as CombatRules
	live_rules.roll_rules = null
	var live := MatchCombat.new(live_rules)
	_check(live.build(0, Vector2i(2, 2), &"guide_archers", MatchCombat.TargetMode.CLOSEST), "Unrelated live model is meaningfully populated")
	var before: Dictionary = live.snapshot()
	var path: String = "user://tower_guide_read_only_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := CollectionStore.new(path, rules.catalog)
	var guide: TowerGuide = _guide(rules)
	var initial: Dictionary = guide.preview(&"guide_archers")
	_check(initial["tower"]["rarity"] == "" and initial["tower"]["attributes"].is_empty() and initial["tower"]["support_damage_bonus"] == 0.0 and initial["tower"]["support_speed_bonus"] == 0.0, "Preview removes placement rolls and has no support neighbors")
	var changed: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/fire_arrows")
	changed["tower"]["damage"] = 999
	changed["stats"]["advancements"]["fire_arrows"]["burn_dps"] = 999.0
	changed["steps"][0]["cost"] = 999
	changed["stage"]["commands"].clear()
	changed["reward"].title = "Changed externally"
	changed["reward"].board_variants["second_archer"]["board_height"] = 999.0
	var again: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/fire_arrows")
	_check(again["tower"]["damage"] == 12 and again["stats"]["advancements"]["fire_arrows"]["burn_dps"] == 5.0 and _costs(again) == [37, 56, 83, 103] and again["stage"]["commands"].size() == 4 and again["reward"].title == "Fixture guide_archers" and again["reward"].board_variants["second_archer"]["board_height"] == 1.1, "Returned nested previews, paths, prices, and rewards cannot mutate the cache")
	guide.entries[0]["stages"].clear()
	guide.entries[0]["reward"].title = "Index mutation"
	var detached_entry: Dictionary = guide.entry(&"guide_archers")
	detached_entry["stages"][0]["title"] = "Mutated entry"
	_check(guide.entry(&"guide_archers")["stages"].size() == 8 and guide.entry(&"guide_archers")["reward"].title == "Fixture guide_archers", "Public index and entry edits never rewrite internal records or source rewards")
	_check(rules.starting_coins == 10000 and not rules.sandbox_mode and rules.roll_rules == rolls and rules.catalog.towers[0].damage == 7 and rules.catalog.towers[0].advancements["fire_arrows"]["burn_dps"] == 5.0 and rules.catalog.towers[0].reward.board_variants["second_archer"]["board_height"] == 1.1, "Guide admission and purchases do not mutate source rules or nested definitions")
	_check(live.snapshot() == before and store.unlocked_count() == 0 and store.remaining_count() == 6 and not FileAccess.file_exists(path), "Reading every guide path leaves unrelated live model, collection ownership, and save file untouched")
	var source_reward: TowerReward = rules.catalog.towers[0].reward
	_check(initial["reward"] != source_reward and initial["reward"].icon_texture != null and initial["reward"].icon_texture == source_reward.icon_texture, "Presentation reward is detached while retaining authored artwork references")
	rules.catalog.towers[0].damage = 19
	rules.catalog.towers[0].cost = 89
	rules.catalog.towers[0].advancements["bomb_arrows"]["cost"] = 211
	_check(guide.preview(&"guide_archers")["tower"]["damage"] == 7 and guide.preview(&"guide_archers", "damage/speed/special/bomb_arrows")["total_cost"] == 356, "Cached and previously unseen branches share the original configuration capture after source edits")
	guide.configure(rules.catalog, rules)
	var reconfigured: Dictionary = guide.preview(&"guide_archers", "damage/speed/special/bomb_arrows")
	_check(reconfigured["tower"]["damage"] == 24 and reconfigured["total_cost"] == 476 and guide.entries[0]["stages"].size() == 8, "Reconfigure discards prior selection cache and public index mutations, then captures changed prices/stats")
	var other: TowerGuide = _guide(_fixture())
	_check(other.preview(&"guide_archers")["tower"]["damage"] == 7 and guide.preview(&"guide_archers")["tower"]["damage"] == 19, "Independent guides cannot contaminate each other's configurations")


func _assert_invalid(content: ContentCatalog, rules: CombatRules, message: String) -> void:
	var guide := TowerGuide.new()
	guide.configure(content, rules)
	_check(guide.entries.is_empty() and not guide.error_message.is_empty(), message + ": honest empty index and useful error")
	_check(guide.preview(&"guide_archers").is_empty() and not guide.error_message.is_empty(), message + ": no fabricated preview")


func _test_invalid_inputs() -> void:
	var rules: CombatRules = _fixture()
	_assert_invalid(null, rules, "Null catalog")
	_assert_invalid(rules.catalog, null, "Null rules")
	_assert_invalid(ContentCatalog.new(), rules, "Empty catalog")
	var invalid: CombatRules = _fixture()
	invalid.catalog.towers[0].interval = NAN
	_assert_invalid(invalid.catalog, invalid, "Invalid tower data")
	invalid = _fixture()
	invalid.catalog.enemies.clear()
	_assert_invalid(invalid.catalog, invalid, "Missing remainder enemy")
	invalid = _fixture()
	invalid.wave_weight = 0
	_assert_invalid(invalid.catalog, invalid, "Invalid match wave configuration")
	invalid = _fixture()
	invalid.speed_growth_rounds = 0
	_assert_invalid(invalid.catalog, invalid, "Invalid speed progression")
	invalid = _fixture()
	invalid.clear_reroll_currency = -1
	_assert_invalid(invalid.catalog, invalid, "Invalid reroll grants")
	var guide: TowerGuide = _guide(rules)
	_check(guide.preview(&"unknown").is_empty() and not guide.error_message.is_empty(), "Unknown identity is rejected without guessed stats")
	_check(guide.preview(&"guide_archers", "unknown").is_empty() and not guide.error_message.is_empty(), "Unknown stage is rejected without falling back to base")
	_check(not guide.preview(&"guide_archers").is_empty() and guide.error_message.is_empty(), "Valid selection recovers from prior lookup errors")
	guide.configure(null, rules)
	_check(guide.entries.is_empty() and guide.preview(&"guide_archers").is_empty(), "Invalid reconfiguration clears all previously valid entries/cache")
	guide.configure(rules.catalog, rules)
	_check(not guide.preview(&"guide_archers").is_empty() and guide.error_message.is_empty(), "Corrected configuration fully recovers after invalid input")
