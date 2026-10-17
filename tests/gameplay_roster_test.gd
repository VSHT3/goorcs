extends SceneTree

var failures: int = 0

func _init() -> void:
	_fixture_isolation()
	_transactions_and_capture()
	_mirrored_rolls()
	_chain()
	_support()
	_support_damage_rounding()
	_rolled_range_cells()
	_production()
	_bounty()
	_bounty_fractional_damage()
	_bounty_fractional_transitions()
	_drops_and_summons()
	_ballista_roll_stacking()
	_effective_original_attacks()
	_sandbox()
	if failures == 0:
		print("PASS: authoritative placement/rerolls, isolated RNG, effective attacks, chain/support/economy/bounty roles, exact rewards, summons, and free Sandbox")
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func rng(seed_value: int) -> RandomNumberGenerator:
	var value := RandomNumberGenerator.new()
	value.seed = seed_value
	return value

func fixture() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog = rules.catalog.duplicate(true) as ContentCatalog
	for index: int in range(rules.catalog.towers.size()):
		var definition := rules.catalog.towers[index].duplicate(true) as TowerDefinition
		definition.reward = definition.reward.duplicate(true) as TowerReward
		rules.catalog.towers[index] = definition
	rules.catalog.starter_tower_id = &""
	var unit := EnemyDefinition.new()
	unit.id = &"unit"
	unit.title = "Test unit"
	unit.kill_bounty = 7
	unit.reroll_drop_chance = 1.0
	unit.reroll_drop_amount = 2
	var bone := EnemyDefinition.new()
	bone.id = &"bone"
	bone.title = "Summoned test unit"
	bone.regular_spawn_enabled = false
	bone.send_enabled = false
	bone.kill_bounty = 0
	bone.reroll_drop_chance = 1.0
	bone.reroll_drop_amount = 3
	var caster := EnemyDefinition.new()
	caster.id = &"caster"
	caster.title = "Test summoner"
	caster.regular_spawn_enabled = false
	caster.summon_type = &"bone"
	caster.summon_interval = 1.0
	caster.summon_cast_duration = 0.25
	caster.summon_min = 1
	caster.summon_max = 1
	caster.summon_limit = 1
	rules.catalog.enemies = [unit, bone, caster]
	rules.enemy_health = 100
	rules.enemy_speed = 0.0
	rules.health_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.starting_coins = 100000
	rules.starting_reroll_currency = 1000
	rules.clear_reroll_currency = 5
	rules.wave_reward = 11
	rules.wave_reward_growth = 0
	return rules

func tower_definition(rules: CombatRules, id: StringName) -> TowerDefinition:
	for definition: TowerDefinition in rules.catalog.towers:
		if definition.reward.id == id:
			return definition
	return null

func _fixture_isolation() -> void:
	var authored := CombatRules.new()
	var first := fixture()
	var second := fixture()
	for definition: TowerDefinition in first.catalog.towers:
		var other: TowerDefinition = tower_definition(second, definition.reward.id)
		var source: TowerDefinition = tower_definition(authored, definition.reward.id)
		check(definition != other and definition != source and definition.reward != other.reward and definition.reward != source.reward, "Fixture owns its definition and reward: %s" % definition.reward.id)
	var arrow: TowerDefinition = tower_definition(first, &"arrow_tower")
	var other_arrow: TowerDefinition = tower_definition(second, &"arrow_tower")
	var source_arrow: TowerDefinition = tower_definition(authored, &"arrow_tower")
	arrow.damage_upgrade_bonus = 999
	arrow.roll_attributes = PackedStringArray(["range"])
	arrow.reward.title = "Fixture-only title"
	check(other_arrow.damage_upgrade_bonus == source_arrow.damage_upgrade_bonus and other_arrow.roll_attributes == source_arrow.roll_attributes and other_arrow.reward.title == source_arrow.reward.title, "Fixture stat, compatibility and reward mutations cannot contaminate later fixtures or authored resources")
	var drums: TowerDefinition = tower_definition(first, &"war_drums")
	var other_drums: TowerDefinition = tower_definition(second, &"war_drums")
	var source_drums: TowerDefinition = tower_definition(authored, &"war_drums")
	drums.behavior_config["damage_bonus"] = 0.9
	check(other_drums.behavior_config == source_drums.behavior_config, "Fixture nested behavior mutations remain isolated")

# Fully authored deterministic test data, not assumptions about shipped odds.
func rolls(pool: Dictionary, slots: int = 1) -> TowerRollRules:
	var rules := TowerRollRules.new()
	rules.slot_profiles = {"attack": {}, "support": {}, "economy": {}}
	rules.rarity_reroll_cost_curve = Vector3(4, 2, 1)
	rules.attribute_reroll_cost_curve = Vector3(9, 3, 2)
	for id: String in TowerRollRules.RARITIES:
		rules.rarities.append({"id": id, "title": id.capitalize(), "weight": 1.0 if id in ["common", "mythic"] else 0.0, "positive_slots": slots, "drawback_slots": 0, "positive_pool": pool.duplicate(), "drawback_pool": {}})
	return rules

func route() -> Dictionary:
	var cells: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(21):
		cells.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < 20 else []
	return {"route": cells, "next": next}

func routes() -> Array[Dictionary]:
	return [route(), route()]

func open_wave(model: MatchCombat) -> void:
	check(model.start_wave(routes()), "Fixture admits an actual validated wave")
	model._spawn_enemies(0)
	model._spawn_enemies(1)

func build(model: MatchCombat, id: StringName, cell: Vector2i = Vector2i(0, 1), slot: int = 0) -> Dictionary:
	check(model.build(slot, cell, id, MatchCombat.TargetMode.CLOSEST), "Fixture placement succeeds: %s" % id)
	return model.towers[slot].back()

func upgrade(model: MatchCombat, tower: Dictionary, commands: Array[String]) -> void:
	for command: String in commands:
		check(model.upgrade_tower(0, tower["id"], command), "Accepted prerequisite/branch %s" % command)

func add_enemy(model: MatchCombat, position: Vector2, type_id: String = "unit", slot: int = 0) -> Dictionary:
	model._spawn_enemy(slot, type_id, position.x, model._elapsed)
	var enemy: Dictionary = model.enemies[slot].back()
	enemy["pos"] = position
	return enemy

func _transactions_and_capture() -> void:
	var rules := fixture()
	rules.catalog.towers = [tower_definition(rules, &"arrow_tower")]
	rules.roll_rules = rolls({"damage": Vector2(0.5, 0.5)})
	var roll_rng := rng(17)
	var tie_rng := rng(29)
	var wave_rng := rng(41)
	var timing_rng := rng(53)
	var drop_rng := rng(67)
	var model := MatchCombat.new(rules, tie_rng, wave_rng, timing_rng, roll_rng, drop_rng)
	var state: int = roll_rng.state
	var before: Dictionary = model.snapshot()
	check(not model.build(-1, Vector2i.ZERO, &"arrow_tower", 0) and not model.build(0, Vector2i.ZERO, &"unknown", 0) and not model.build(0, Vector2i.ZERO, &"arrow_tower", -1), "Invalid placement commands reject")
	check(before == model.snapshot() and state == roll_rng.state, "Rejected placement changes no state or placement RNG")
	var tower: Dictionary = build(model, &"arrow_tower")
	var id: int = tower["id"]
	check(tower["damage"] == 3 and tower["attributes"].size() == 1, "Accepted placement immediately applies its rolled effective damage")
	check(tie_rng.state == rng(29).state and wave_rng.state == rng(41).state and timing_rng.state == rng(53).state and drop_rng.state == rng(67).state, "Placement RNG is isolated from defeat/wave/timing/drop streams")
	before = model.snapshot()
	state = roll_rng.state
	check(not model.build(0, tower["cell"], &"arrow_tower", 0) and not model.reroll_tower(1, id, "rarity") and not model.reroll_tower(0, id, "unknown") and before == model.snapshot() and state == roll_rng.state, "Occupied/wrong-owner/unknown rerolls are atomic including RNG")
	var rarity: String = tower["rarity"]
	var coins_before: int = model.coins[0]
	check(model.reroll_tower(0, id, "attributes") and tower["rarity"] == rarity and model.coins[0] == coins_before - 9 and tower["attribute_rerolls"] == 1 and tower["attribute_reroll_cost"] == 14, "Attribute reroll retains rarity and advances its own accelerating Coin cost")
	check(model.reroll_tower(0, id, "attributes") and tower["attribute_rerolls"] == 2 and tower["attribute_reroll_cost"] == 23, "Second attribute reroll uses completed-count pricing")
	var currency: int = model.reroll_currency[0]
	check(model.reroll_tower(0, id, "rarity") and tower["rarity"] != rarity and model.reroll_currency[0] == currency - 4 and tower["rarity_rerolls"] == 1 and tower["attribute_rerolls"] == 0 and tower["rarity_reroll_cost"] == 7 and tower["attribute_reroll_cost"] == 9, "Rarity reroll excludes current tier, charges separate currency, and resets only attribute count")
	upgrade(model, tower, ["damage", "speed", "special", "bomb_arrows"])
	check(tower["base_damage"] == 3 and tower["damage"] == 5, "Paid baseline and rolled effective damage are stored separately through branches")
	var captured_interval: float = tower["interval"]
	rules.roll_rules.rarities.clear()
	rules.catalog.towers[0].damage_upgrade_bonus = 999
	var copy: Dictionary = model.snapshot()
	copy["towers"][0][0]["attributes"][0]["value"] = 900.0
	copy["tower_types"]["arrow_tower"]["roll_attributes"].clear()
	check(model.reroll_tower(0, id, "rarity") and tower["damage"] == 5 and is_equal_approx(tower["interval"], captured_interval) and tower["rarity_rerolls"] == 2, "Admission deep-captures roll tables and rerolls do not compound or erase upgrades")
	model.coins[0] = 0
	model.reroll_currency[0] = 0
	state = roll_rng.state
	before = model.snapshot()
	check(not model.reroll_tower(0, id, "attributes") and not model.reroll_tower(0, id, "rarity") and not model.build(0, Vector2i(3, 1), &"arrow_tower", 0) and state == roll_rng.state and before == model.snapshot(), "Insufficient funds reject every roll transaction without RNG/counters/state changes")

func _mirrored_rolls() -> void:
	var rules := fixture()
	rules.catalog.towers = [tower_definition(rules, &"arrow_tower")]
	rules.roll_rules = rolls({"damage": Vector2(0.1, 0.9)})
	var solo_rng := rng(71)
	var control_rng := rng(71)
	var model := MatchCombat.new(rules, null, null, null, solo_rng)
	var control := MatchCombat.new(rules, null, null, null, control_rng)
	check(model.build_mirrored(0, Vector2i(0, 1), &"arrow_tower", 0), "Mirrored placement succeeds atomically")
	control.build(0, Vector2i(0, 1), &"arrow_tower", 0)
	check(solo_rng.state == control_rng.state and model.towers[0][0]["attributes"] == model.towers[1][0]["attributes"] and model.towers[0][0]["id"] != model.towers[1][0]["id"], "Mirror uses one accepted roll with independent tower identities")
	check(model.reroll_tower_mirrored(0, model.towers[0][0]["id"], "rarity"), "Mirrored rarity reroll succeeds")
	control.reroll_tower(0, control.towers[0][0]["id"], "rarity")
	check(solo_rng.state == control_rng.state and model.towers[0][0]["attributes"] == model.towers[1][0]["attributes"] and model.reroll_currency[0] == model.reroll_currency[1], "Mirror reroll charges both owners while consuming one roll")
	model.coins[1] = 0
	var before: Dictionary = model.snapshot()
	var state: int = solo_rng.state
	check(not model.reroll_tower_mirrored(0, model.towers[0][0]["id"], "attributes") and model.snapshot() == before and solo_rng.state == state, "Unaffordable mirror counterpart rejects whole transaction before rolling")

func _chain() -> void:
	var rules := fixture()
	var definition: TowerDefinition = tower_definition(rules, &"lightning")
	definition.damage = 10
	definition.damage_upgrade_bonus = 2
	definition.behavior_config = {"hit_count": 3, "jump_distance": 2.0, "successive_hit_bonus": 0.0}
	rules.catalog.towers = [definition]
	var model := MatchCombat.new(rules)
	var tower: Dictionary = build(model, &"lightning")
	open_wave(model)
	var first: Dictionary = model.enemies[0][0]
	first["pos"] = Vector2(1, 1)
	var near: Dictionary = add_enemy(model, Vector2(2, 1))
	var tied: Dictionary = add_enemy(model, Vector2(1, 2))
	var outside: Dictionary = add_enemy(model, Vector2(10, 1))
	model.enemies[0].reverse()
	model._attack(0, 0.01)
	check(tower["chain_points"] == [Vector2(1, 1), Vector2(2, 1), Vector2(1, 2)] and first["hp"] == 90 and near["hp"] == 90 and tied["hp"] == 90 and outside["hp"] == 100, "Chain chooses nearest unhit with stable ID tie, full damage once each, and no distant jump")
	upgrade(model, tower, ["damage", "speed"])
	var before: Dictionary = model.snapshot()
	check(not model.upgrade_tower(0, tower["id"], "longer_reach") and model.snapshot() == before, "Longer Reach requires shared escalation before evolution")
	upgrade(model, tower, ["special", "longer_reach"])
	check(tower["range"] == 5.0 and tower["behavior_config"]["jump_distance"] == 3.5 and tower["behavior_config"]["successive_hit_bonus"] == 0.25 and MatchCombat.tower_level(tower) == 5, "Longer Reach preserves paid escalation and gains authored initial/jump ranges")
	tower["cooldown"] = 0.0
	model._attack(0, 0.01)
	check(first["hp"] == 78 and near["hp"] == 75 and tied["hp"] == 72, "Escalation deals full upgraded base times one plus successive-hit index bonus")
	rules.roll_rules = rolls({"chain_jumps": Vector2(1, 1)})
	model = MatchCombat.new(rules)
	tower = build(model, &"lightning")
	upgrade(model, tower, ["damage", "speed", "special", "longer_reach"])
	open_wave(model)
	for index: int in range(1, 4):
		add_enemy(model, Vector2(index, 0))
	model._attack(0, 0.01)
	var remaining_hp: int = 0
	for enemy: Dictionary in model.enemies[0]:
		remaining_hp += int(enemy["hp"])
	check(tower["chain_points"].size() == 4 and remaining_hp == 334, "Rolled extra chain jump survives evolution and adds a fourth escalating full-base hit")

func _support() -> void:
	var rules := fixture()
	var arrow: TowerDefinition = tower_definition(rules, &"arrow_tower")
	arrow.damage = 100
	arrow.interval = 2.0
	var drums: TowerDefinition = tower_definition(rules, &"war_drums")
	drums.behavior_config = {"stack_group": "mixed", "damage_bonus": 0.2, "attack_speed_bonus": 0.3}
	var model := MatchCombat.new(rules)
	var attack: Dictionary = build(model, &"arrow_tower")
	var first: Dictionary = build(model, &"war_drums", Vector2i(1, 1))
	var duplicate: Dictionary = build(model, &"war_drums", Vector2i(2, 1))
	check(attack["damage"] == 120 and is_equal_approx(attack["interval"], 2.0 / 1.3), "Duplicate mixed supports use strongest effect rather than sum")
	upgrade(model, first, ["damage", "speed"])
	check(is_equal_approx(attack["support_damage_bonus"], 0.3) and is_equal_approx(attack["support_speed_bonus"], 0.4), "Strongest upgraded duplicate wins each component")
	upgrade(model, first, ["forge"])
	check(first["behavior_config"]["attack_speed_bonus"] == 0.0 and is_equal_approx(first["behavior_config"]["damage_bonus"], 0.7), "Forge remains pure damage and both prerequisite purchases retain useful role effects")
	check(is_equal_approx(attack["support_damage_bonus"], 0.9) and is_equal_approx(attack["support_speed_bonus"], 0.3), "Different mixed/Forge stack groups add")
	upgrade(model, duplicate, ["damage", "speed", "command_banner"])
	check(duplicate["behavior_config"]["damage_bonus"] == 0.0 and is_equal_approx(attack["support_damage_bonus"], 0.7) and is_equal_approx(attack["support_speed_bonus"], 0.7), "Banner replaces mixed role with pure speed while stacking independently with Forge")
	open_wave(model)
	model._attack(0, 0.01)
	check(first["shot"] == 0 and duplicate["shot"] == 0, "Support structures never perform passive attacks")
	model.sell_tower(0, first["id"])
	check(attack["support_damage_bonus"] == 0.0 and is_equal_approx(attack["support_speed_bonus"], 0.7), "Selling support immediately removes only its accepted buff")
	rules = fixture()
	arrow = tower_definition(rules, &"arrow_tower")
	drums = tower_definition(rules, &"war_drums")
	rules.catalog.towers = [arrow, drums]
	arrow.roll_attributes = PackedStringArray(["range"])
	rules.roll_rules = rolls({"range": Vector2(1, 1), "support_buff": Vector2(0.5, 0.5)}, 2)
	for rarity: String in TowerRollRules.RARITIES:
		rules.roll_rules.slot_profiles["attack"][rarity] = Vector2i(1, 0)
	model = MatchCombat.new(rules)
	attack = build(model, &"arrow_tower", Vector2i(4, 1))
	first = build(model, &"war_drums", Vector2i(0, 1))
	check(is_equal_approx(attack["support_damage_bonus"], 0.225) and is_equal_approx(attack["support_speed_bonus"], 0.225), "Rolled range reaches a distant tower and rolled strength scales both mixed support components")
	upgrade(model, first, ["damage", "speed", "forge"])
	check(model.reroll_tower(0, first["id"], "rarity") and is_equal_approx(attack["support_damage_bonus"], 1.05) and attack["support_speed_bonus"] == 0.0, "Support rolls and role purchases survive evolution/reroll without compounding or restoring replaced mixed speed")

func _support_damage_rounding() -> void:
	var bonuses: Array[float] = [0.2, (0.1 + 0.2) * 1.5, 0.200001]
	var expected: Array[int] = [120, 145, 121]
	for index: int in range(bonuses.size()):
		var rules := fixture()
		var arrow: TowerDefinition = tower_definition(rules, &"arrow_tower")
		arrow.damage = 100
		var drums: TowerDefinition = tower_definition(rules, &"war_drums")
		drums.behavior_config["damage_bonus"] = bonuses[index]
		rules.catalog.towers = [arrow, drums]
		var model := MatchCombat.new(rules)
		var attack: Dictionary = build(model, &"arrow_tower")
		build(model, &"war_drums", Vector2i(1, 1))
		check(attack["support_damage_bonus"] == bonuses[index] and attack["damage"] == expected[index], "Support bonuses retain float precision and ceil only genuine fractional damage: %.9f" % bonuses[index])

func _rolled_range_cells() -> void:
	for bonus: float in [0.0, 0.25, -0.25]:
		var rules := fixture()
		rules.catalog.towers = [tower_definition(rules, &"rune_obelisk")]
		if bonus != 0.0:
			rules.roll_rules = rolls({"range": Vector2(bonus, bonus)})
			if bonus < 0.0:
				for tier: Dictionary in rules.roll_rules.rarities:
					tier["positive_slots"] = 0
					tier["drawback_slots"] = 1
					tier["positive_pool"] = {}
					tier["drawback_pool"] = {"range": Vector2(bonus, bonus)}
		var model := MatchCombat.new(rules)
		var rune: Dictionary = build(model, &"rune_obelisk")
		open_wave(model)
		var enemy: Dictionary = model.enemies[0][0]
		enemy["pos"] = Vector2(2, 0)
		model._attack(0, 0.01)
		check(rune["range"] == (2.0 if bonus > 0.0 else 1.0) and enemy["hp"] == (99 if bonus > 0.0 else 100), "A positive Rune range roll hits a newly included tile; unrolled range and minimum drawback radius stay intact")
		var support_rules := fixture()
		support_rules.catalog.towers = [tower_definition(support_rules, &"arrow_tower"), tower_definition(support_rules, &"war_drums")]
		support_rules.roll_rules = rules.roll_rules
		model = MatchCombat.new(support_rules)
		var far: Dictionary = build(model, &"arrow_tower", Vector2i(3, 1))
		var edge: Dictionary = build(model, &"arrow_tower", Vector2i(2, 1))
		var drums: Dictionary = build(model, &"war_drums")
		check(drums["range"] == (3.0 if bonus > 0.0 else (1.0 if bonus < 0.0 else 2.0)) and is_equal_approx(far["support_damage_bonus"], 0.15 if bonus > 0.0 else 0.0) and is_equal_approx(edge["support_damage_bonus"], 0.0 if bonus < 0.0 else 0.15), "Signed support range rolls add or remove usable tiles without changing unrolled coverage")

func _production() -> void:
	var rules := fixture()
	var model := MatchCombat.new(rules)
	var mine: Dictionary = build(model, &"gold_mine")
	upgrade(model, mine, ["damage", "speed", "royal_mint"])
	check(mine["behavior_config"]["clear_income"] == 22 and mine["behavior_config"]["periodic_income"] == 5, "Passive upgrades apply to authored production and round up per payout")
	var before: int = model.coins[0]
	check(not model.advance(100.0) and model.coins[0] == before, "Mint never pays during planning")
	open_wave(model)
	model.advance(12.4)
	check(model.coins[0] == before + 10 and is_equal_approx(mine["production_elapsed"], 2.4), "Mint pays every elapsed simulation interval even on coarse deltas")
	model.debug_set_round(7)
	before = model.coins[0]
	check(mine["production_elapsed"] == 0.0 and not model.advance(100.0) and model.coins[0] == before, "Debug abandonment clears partial Mint clock and grants no rewards")
	var clear_rules := fixture()
	clear_rules.enemy_speed = 20.0
	model = MatchCombat.new(clear_rules)
	mine = build(model, &"gold_mine")
	upgrade(model, mine, ["damage", "speed", "royal_mint"])
	before = model.coins[0]
	var currency: int = model.reroll_currency[0]
	open_wave(model)
	model.advance(1000.0)
	check(model.phase == MatchCombat.Phase.PLANNING and model.coins[0] == before + 11 + 22 and model.coins[1] == clear_rules.starting_coins + 11 and model.reroll_currency[0] == currency + 5, "Both-board clear pays one normal reward, mine income and run currency without idle coarse-tick Mint payouts")
	before = model.coins[0]
	check(not model.advance(1000.0) and model.coins[0] == before, "Finished clear cannot pay twice")
	clear_rules.base_health = 1
	model = MatchCombat.new(clear_rules)
	mine = build(model, &"gold_mine")
	upgrade(model, mine, ["damage", "speed", "royal_mint"])
	before = model.coins[0]
	currency = model.reroll_currency[0]
	open_wave(model)
	model.advance(1000.0)
	check(model.phase == MatchCombat.Phase.FINISHED and model.coins[0] == before and model.reroll_currency[0] == currency and mine["production_elapsed"] == 0.0, "Terminal leak grants neither clear production nor rarity currency nor post-terminal Mint payouts")

func _bounty() -> void:
	var rules := fixture()
	var model := MatchCombat.new(rules)
	var board: Dictionary = build(model, &"gold_mine")
	var second: Dictionary = build(model, &"gold_mine", Vector2i(1, 1))
	var attack: Dictionary = build(model, &"arrow_tower", Vector2i(2, 1))
	upgrade(model, board, ["damage", "speed", "bounty_board"])
	upgrade(model, second, ["damage", "speed", "bounty_board"])
	open_wave(model)
	var first: Dictionary = model.enemies[0][0]
	first["max_hp"] = 200
	first["hp"] = 20
	var tied: Dictionary = add_enemy(model, Vector2(2, 0))
	tied["max_hp"] = 200
	var lower: Dictionary = add_enemy(model, Vector2(1, 0))
	lower["max_hp"] = 150
	model.enemies[0].reverse()
	model._update_bounties(0)
	check(first["bounty_tower_id"] == board["id"] and tied["bounty_tower_id"] == second["id"] and lower["bounty_tower_id"] == -1, "Boards choose greatest maximum HP rather than current HP, stable ID ties and exclusive targets")
	first["pos"] = Vector2(19, 0)
	model._update_bounties(0)
	check(board["bounty_target_id"] == first["id"] and first["bounty_tower_id"] == board["id"], "Mark persists outside Board range and occupies its sole slot")
	var hp: int = first["hp"]
	model._hit(0, attack, model._enemy_index(0, first["id"]), 5)
	check(first["hp"] == hp - 6, "Marked enemy takes authored increased damage")
	upgrade(model, board, ["income_aura"])
	check(first["bounty_tower_id"] == -1 and board["bounty_target_id"] == -1 and board["behavior_kind"] == "income_aura", "Income-aura branch immediately clears its previous active mark")
	upgrade(model, second, ["stronger_mark"])
	var rejected: Dictionary = model.snapshot()
	check(not model.upgrade_tower(0, board["id"], "stronger_mark") and not model.upgrade_tower(0, second["id"], "income_aura") and model.snapshot() == rejected, "Permanent bounty followups are exclusive")
	var aura2: Dictionary = build(model, &"gold_mine", Vector2i(3, 1))
	upgrade(model, aura2, ["damage", "speed", "bounty_board", "income_aura"])
	var before: int = model.coins[0]
	model._hit(0, attack, model._enemy_index(0, tied["id"]), 1000)
	# Upgraded mark: 1.0*1.45; upgraded aura: .35*1.45. One final ceil.
	check(model.coins[0] == before + 21 and second["bounty_target_id"] == -1, "One normal bounty plus upgraded mark plus strongest aura pays exact Coins once, never duplicate aura stacking")
	before = model.coins[0]
	model._hit(0, attack, model._enemy_index(0, first["id"]), 1000)
	check(model.coins[0] == before + 11, "Aura eligibility uses killing tower position even when enemy is far outside aura")
	attack["cell"] = Vector2i(19, 1)
	before = model.coins[0]
	model._hit(0, attack, model._enemy_index(0, lower["id"]), 1000)
	check(model.coins[0] == before + 7, "Enemy near aura does not qualify a distant killing tower")
	var next: Dictionary = add_enemy(model, Vector2(1, 0))
	model._update_bounties(0)
	check(next["bounty_tower_id"] == second["id"], "Freed Board slot acquires next eligible target")
	model.sell_tower(0, second["id"])
	check(next["bounty_tower_id"] == -1 and next["bounty_damage_bonus"] == 0.0 and next["bounty_income_bonus"] == 0.0, "Selling Board cleans every active mark effect")
	check(not board["behavior_config"].has("clear_income") and not aura2["behavior_config"].has("periodic_income"), "Bounty branches replace rather than retain production")
	model = MatchCombat.new(rules)
	board = build(model, &"gold_mine")
	upgrade(model, board, ["damage", "speed", "bounty_board"])
	open_wave(model)
	model._update_bounties(0)
	check(board["bounty_target_id"] >= 0, "Board marks a real admitted enemy before debug reset")
	model.debug_set_round(2)
	check(board["bounty_target_id"] == -1 and model.enemies[0].is_empty(), "Debug round abandonment removes every active mark without rewards")
	rules.enemy_speed = 20.0
	rules.base_health = 1
	model = MatchCombat.new(rules)
	board = build(model, &"gold_mine")
	upgrade(model, board, ["damage", "speed", "bounty_board"])
	open_wave(model)
	model._update_bounties(0)
	model.advance(1.0)
	check(model.phase == MatchCombat.Phase.FINISHED and board["bounty_target_id"] == -1 and model.enemies[0].is_empty(), "Crystal arrival and terminal transition retire marked target and Board slot")

func _bounty_exposure_fixture(burn: bool, marked: bool) -> Dictionary:
	var rules := fixture()
	var source_id: StringName = &"arrow_tower" if burn else &"rune_obelisk"
	rules.catalog.towers = [tower_definition(rules, source_id), tower_definition(rules, &"gold_mine")]
	if burn:
		rules.roll_rules = rolls({"damage": Vector2(0.5, 0.5)})
		for rarity: String in TowerRollRules.RARITIES:
			rules.roll_rules.slot_profiles["economy"][rarity] = Vector2i.ZERO
	var model := MatchCombat.new(rules)
	var source: Dictionary = build(model, source_id)
	var board: Dictionary = build(model, &"gold_mine", Vector2i(1, 1))
	upgrade(model, board, ["damage", "speed"])
	if marked:
		upgrade(model, board, ["bounty_board"])
	var source_upgrades: Array[String] = []
	if burn:
		source_upgrades = ["damage", "speed", "special", "fire_arrows"]
	else:
		source_upgrades = ["damage", "speed", "boulders", "freeze_runes"]
	upgrade(model, source, source_upgrades)
	open_wave(model)
	model._update_bounties(0)
	var enemy: Dictionary = model.enemies[0][0]
	if burn:
		model._attack(0, 0.01)
		source["cooldown"] = 100.0
	return {"model": model, "source": source, "board": board, "enemy": enemy}

func _advance_exposure(model: MatchCombat, duration: float, step: float) -> void:
	var remaining: float = duration
	while remaining > 0.000000001:
		var delta: float = minf(remaining, step)
		model.advance(delta)
		remaining -= delta

func _bounty_fractional_damage() -> void:
	for burn: bool in [false, true]:
		for step: float in [0.01, 1.0]:
			var setup: Dictionary = _bounty_exposure_fixture(burn, true)
			var model: MatchCombat = setup["model"]
			var source: Dictionary = setup["source"]
			var enemy: Dictionary = setup["enemy"]
			var label: String = "burn" if burn else "Boulders"
			# Boulders is 6 DPS; Fire is 4 DPS with a single +50% roll.
			# A 20% mark contributes 7.2 HP over one second: seven whole HP.
			check(enemy["hp"] == (88 if burn else 100), "Marked physical arrows retain per-hit ceil and ignition has no instant damage")
			var hp: int = enemy["hp"]
			_advance_exposure(model, 1.0, step)
			check(enemy["hp"] == hp - 7, "Marked %s at %.2fs cadence integrates seven HP, without per-tick ceil or repeated modifiers" % [label, step])
			if burn:
				check(enemy["burning"] and is_equal_approx(enemy["burn_remaining"], 2.0), "Marked burn retains authored expiry and status")
				check(model.sell_tower(0, source["id"]), "Burn source can be sold during marked exposure")
			else:
				check(enemy["slowed"] and is_equal_approx(enemy["slow_remaining"], 1.0), "Bounty damage modifiers neither gate nor lengthen the maximum-HP-based Freeze slow")
			enemy["hp"] = 1
			var coins_before: int = model.coins[0]
			_advance_exposure(model, 1.0 / 6.0, step)
			# Seven normal Coins plus a 50% mark scaled by both income upgrades:
			# ceil(7 * (1 + 0.5 * (1 + 0.25 + 0.2))) = 13.
			check(model.enemies[0].is_empty() and source["kills"] == 1 and model.coins[0] == coins_before + 13 and model.snapshot()["deaths"][0].size() == 1, "Marked %s retains source attribution, actual-HP kill capping, one bounty and one corpse%s" % [label, " after source sale" if burn else ""])

func _bounty_fractional_transitions() -> void:
	for burn: bool in [false, true]:
		for step: float in [0.001, 1.0]:
			var setup: Dictionary = _bounty_exposure_fixture(burn, false)
			var model: MatchCombat = setup["model"]
			var board: Dictionary = setup["board"]
			var enemy: Dictionary = setup["enemy"]
			var hp: int = enemy["hp"]
			var label: String = "burn" if burn else "Boulders"
			# Each stage adds already-adjusted HP: .9 + .09 + .84 + .12 + .06.
			_advance_exposure(model, 0.15, step)
			check(enemy["hp"] == hp, "Unmarked %s preserves its initial .9 fractional HP" % label)
			upgrade(model, board, ["bounty_board"])
			model._update_bounties(0)
			_advance_exposure(model, 0.0125, step)
			check(enemy["hp"] == hp, "Gaining a mark does not retroactively amplify %s's pre-mark fraction (.99 total)" % label)
			upgrade(model, board, ["stronger_mark"])
			_advance_exposure(model, 0.1, step)
			check(enemy["hp"] == hp - 1, "Strengthened mark affects only new %s exposure (1.83 total)" % label)
			check(model.sell_tower(0, board["id"]) and enemy["bounty_tower_id"] == -1, "Selling the owning Board removes vulnerability during ongoing exposure")
			_advance_exposure(model, 0.02, step)
			check(enemy["hp"] == hp - 1, "Lost mark does not boost new %s exposure (1.95 total)" % label)
			_advance_exposure(model, 0.01, step)
			check(enemy["hp"] == hp - 2, "Lost mark preserves already-earned %s fractional credit (2.01 total)" % label)

func _drops_and_summons() -> void:
	var rules := fixture()
	var drop_rng := rng(89)
	var tie_rng := rng(97)
	var model := MatchCombat.new(rules, tie_rng, null, null, null, drop_rng)
	rules.catalog.enemies[0].reroll_drop_chance = 0.0
	rules.catalog.enemies[0].reroll_drop_amount = 999
	var attack: Dictionary = build(model, &"arrow_tower", Vector2i(0, 1), 1)
	check(model.send_enemy(0, &"unit"), "Owner zero buys a real enemy send to owner one")
	open_wave(model)
	var before: int = model.reroll_currency[1]
	var coins_before: int = model.coins[1]
	model._hit(1, attack, 0, 1000)
	check(model.reroll_currency[1] == before + 2 and model.reroll_currency[0] == rules.starting_reroll_currency and model.coins[1] == coins_before + 7, "Sent enemy Coins/drop belong to defending killer, never sender")
	model._spawn_enemy(1, "caster", 0.0, model._elapsed)
	model.advance(1.3)
	var bone: Dictionary = {}
	for enemy: Dictionary in model.enemies[1]:
		if enemy["type_id"] == "bone":
			bone = enemy
	check(not bone.is_empty() and int(bone["summoner_id"]) >= 0, "Actual accepted summoner ritual creates a living child")
	if bone.is_empty():
		return
	before = model.reroll_currency[1]
	coins_before = model.coins[1]
	model._hit(1, attack, model._enemy_index(1, bone["id"]), 1000)
	check(model.reroll_currency[1] == before + 3 and model.coins[1] == coins_before, "Zero-normal-bounty summoned child still drops its authored rarity currency exactly once")
	check(tie_rng.state == rng(97).state, "Drops never perturb host simultaneous-defeat coin flip RNG")

func _ballista_roll_stacking() -> void:
	for evolution: String in ["pierce", "bounce"]:
		var rules := fixture()
		var definition: TowerDefinition = tower_definition(rules, &"orc_ballista")
		definition.damage = 9
		definition.damage_upgrade_bonus = 1
		definition.range_cells = 5.0
		rules.catalog.towers = [definition]
		rules.roll_rules = rolls({"pierce": Vector2(1, 1), "bounce": Vector2(1, 1)}, 2)
		var model := MatchCombat.new(rules, null, null, null, rng(101))
		var tower: Dictionary = build(model, &"orc_ballista", Vector2i.ZERO)
		upgrade(model, tower, ["damage", "speed", evolution])
		open_wave(model)
		model.enemies[0][0]["pos"] = Vector2(1, 0)
		for index: int in range(2, 7):
			add_enemy(model, Vector2(index, 0) if index <= 3 else Vector2(index - 1, 1))
		model._attack(0, 0.01)
		var damage: int = 0
		for enemy: Dictionary in model.enemies[0]:
			damage += 100 - int(enemy["hp"])
		check(damage == (35 if evolution == "pierce" else 30) and tower["pierce_active"] and tower["bounce_active"], "Rolled pierce AND bounce both execute and add independently to purchased %s capacity" % evolution)
		check(model.reroll_tower(0, tower["id"], "rarity") and tower["attributes"].size() == 2 and tower["evolution"] == evolution, "Reroll retains compatible mechanical attributes and purchased branch")

func _effective_original_attacks() -> void:
	for branch: String in ["boulders", "onyx_ring"]:
		var rules := fixture()
		var definition: TowerDefinition = tower_definition(rules, &"rune_obelisk")
		rules.catalog.towers = [definition]
		rules.roll_rules = rolls({"damage": Vector2(0.5, 0.5), "attack_speed": Vector2(1, 1), "range": Vector2(1, 1)}, 3)
		var model := MatchCombat.new(rules)
		var tower: Dictionary = build(model, &"rune_obelisk")
		upgrade(model, tower, ["damage", "speed", branch])
		open_wave(model)
		var enemy: Dictionary = model.enemies[0][0]
		enemy["progress"] = 2.0
		enemy["pos"] = Vector2(2, 0)
		model.advance(1.0)
		check(enemy["hp"] == 82 and tower["range"] == 2.0, "Rolled damage/range/speed all affect evolved %s combat" % branch)
	var rules := fixture()
	rules.catalog.towers = [tower_definition(rules, &"arrow_tower")]
	rules.roll_rules = rolls({"damage": Vector2(1, 1)})
	var model := MatchCombat.new(rules)
	var tower: Dictionary = build(model, &"arrow_tower")
	upgrade(model, tower, ["damage", "speed", "special", "fire_arrows"])
	open_wave(model)
	var enemy: Dictionary = model.enemies[0][0]
	model._attack(0, 0.01)
	check(enemy["hp"] == 88 and enemy["burning"], "Every independent archer consumes rolled effective primary damage")
	tower["cooldown"] = 100.0
	model.advance(0.5)
	check(enemy["hp"] == 84, "Rolled effective damage scales timed burn rather than only physical arrows")
	model = MatchCombat.new(rules)
	tower = build(model, &"arrow_tower")
	upgrade(model, tower, ["damage", "speed", "special", "bomb_arrows"])
	open_wave(model)
	enemy = model.enemies[0][0]
	var nearby: Dictionary = add_enemy(model, Vector2(0.8, 0))
	var outside: Dictionary = add_enemy(model, Vector2(0.7, 0.7))
	model._attack_arrow(0, tower, enemy["id"], enemy["pos"], model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["bomb_arrows"])
	check(enemy["hp"] == 91 and nearby["hp"] == 97 and outside["hp"] == 100, "Rolled effective damage scales both heavy primary and true-circle reduced splash")

func _sandbox() -> void:
	var rules := fixture()
	rules.sandbox_mode = true
	rules.starting_coins = 0
	rules.starting_reroll_currency = 0
	rules.catalog.towers = [tower_definition(rules, &"gold_mine")]
	rules.roll_rules = rolls({"economy_production": Vector2(0.5, 0.5)})
	var model := MatchCombat.new(rules)
	var tower: Dictionary = build(model, &"gold_mine")
	upgrade(model, tower, ["damage", "speed", "bounty_board", "income_aura"])
	check(model.reroll_tower(0, tower["id"], "attributes") and model.reroll_tower(0, tower["id"], "rarity") and model.coins[0] == 0 and model.reroll_currency[0] == 0 and tower["invested"] == 0, "Sandbox permits every role upgrade/reroll without spending or investment")
	check(is_equal_approx(tower["behavior_config"]["kill_income_bonus"], 0.6825), "Economy roll and both paid role modifiers survive Bounty and income-aura evolution")
	rules.roll_rules = null
	model = MatchCombat.new(rules)
	tower = build(model, &"gold_mine")
	var before: Dictionary = model.snapshot()
	check(tower["attributes"].is_empty() and tower["rarity"] == "" and not model.reroll_tower(0, tower["id"], "rarity") and model.snapshot() == before, "Explicit no-roll injected rules never generate meaningless passive attributes")
