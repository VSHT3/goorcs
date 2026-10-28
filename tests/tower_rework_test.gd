extends SceneTree
## Circular tower reach and proportional range rolls, Rune/Storm Sigil range,
## War Drums branches (Forge, Command Banner, Lookout Horn, Bloodlust Totem)
## with range/crit auras, and Crystal Mine capstones (Heart of the Mountain vs
## Mother I-III).

const FORGE: Array[String] = ["tempered_steel", "master_smith", "dragonfire_forge"]
const LOOKOUT: Array[String] = ["signal_fires", "eagle_eyes", "all_seeing_tower"]
const TOTEM: Array[String] = ["sharpened_hooks", "blood_frenzy", "skullsplitter_totem"]
const CRYSTAL: Array[String] = ["crystal_mine", "deeper_veins", "geode_drill", "resonant_lattice", "mother_lode"]

var failures: int = 0


func _init() -> void:
	_test_circular_range()
	_test_rune_range()
	_test_war_drums_rolls()
	_test_war_drums()
	_test_crits()
	_test_capstones()
	if failures == 0:
		print("PASS: circular reach and proportional range rolls, Storm-only Rune range, War Drums damage/speed/range/crit branches, isolated crit rolls and Crystal Mine capstone fork with per-round base max HP growth capped at 1000, regen and compounding Shards")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _rules(sandbox: bool = true) -> CombatRules:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = sandbox
	rules.roll_rules = null
	rules.starting_coins = 1000000
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	return rules


func _tower(combat: MatchCombat, slot: int, cell: Vector2i) -> Dictionary:
	for tower: Dictionary in combat.towers[slot]:
		if tower["cell"] == cell:
			return tower
	return {}


func _built(combat: MatchCombat, cell: Vector2i, type_id: StringName, commands: Array) -> Dictionary:
	_check(combat.build(0, cell, type_id, MatchCombat.TargetMode.FURTHEST), "Build %s" % type_id)
	var tower: Dictionary = _tower(combat, 0, cell)
	for command: Variant in commands:
		_check(combat.upgrade_tower(0, tower["id"], String(command)), "%s accepts %s" % [type_id, command])
	return tower


func _test_circular_range() -> void:
	var origin := Vector2i(5, 5)
	_check(MatchCombat.cell_in_range(origin, Vector2i(8, 5), 3.0) and MatchCombat.cell_in_range(origin, Vector2i(7, 7), 3.0), "Range 3 reaches straight lines and inner diagonals")
	_check(not MatchCombat.cell_in_range(origin, Vector2i(8, 6), 3.0) and not MatchCombat.cell_in_range(origin, Vector2i(8, 8), 3.0), "Range 3 is a circle, not a 7x7 square")
	_check(not MatchCombat.cell_in_range(origin, Vector2i(8, 6), 3.03), "A +1% range bonus no longer adds a whole ring of tiles")
	_check(MatchCombat.cell_in_range(origin, Vector2i(8, 6), 3.2), "A larger bonus adds only the tiles it actually reaches")
	_check(MatchCombat.cell_in_square(origin, Vector2i(7, 7), 2.0) and not MatchCombat.cell_in_range(origin, Vector2i(7, 7), 2.0), "Bomb/death-stun blasts keep their square area")
	var rules := _rules()
	rules.roll_rules = (load("res://resources/combat/prototype.tres") as CombatRules).roll_rules
	var combat := MatchCombat.new(rules)
	var arrow := _built(combat, Vector2i(2, 2), &"arrow_tower", [])
	arrow["attributes"] = [{"effect": "range", "value": 0.01}] as Array[Dictionary]
	combat._refresh_board(0)
	_check(is_equal_approx(float(arrow["range"]), 3.03), "Rolled range scales reach proportionally without rounding up a tile: %s" % arrow["range"])
	arrow["attributes"] = [{"effect": "range", "value": -0.9}] as Array[Dictionary]
	combat._refresh_board(0)
	_check(is_equal_approx(float(arrow["range"]), 1.0), "Range drawbacks never shrink reach below one cell")


func _test_rune_range() -> void:
	var combat := MatchCombat.new(_rules())
	var plain := _built(combat, Vector2i(1, 1), &"rune_obelisk", [])
	_check(is_equal_approx(float(plain["range"]), 1.5) and MatchCombat.cell_in_range(Vector2i(1, 1), Vector2i(2, 2), plain["range"]), "Unevolved Rune keeps its 3x3 pulse")
	var boulders := _built(combat, Vector2i(4, 1), &"rune_obelisk", ["damage", "speed", "boulders", "rolling_stones", "landslide", "mountain_heart"])
	var storm := _built(combat, Vector2i(7, 1), &"rune_obelisk", ["damage", "speed", "storm_sigil", "charged_orbs", "tempest", "wrath_of_the_storm"])
	_check(is_equal_approx(float(boulders["range"]), 1.5), "Boulders no longer grow beyond the 3x3 pulse")
	_check(is_equal_approx(float(storm["range"]), 4.0), "Storm Sigil is the long-range Rune path")


func _test_war_drums_rolls() -> void:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = false
	_check(rules.roll_rules != null, "The actual prototype enables placement rolls")
	if rules.roll_rules == null:
		return
	var drums_definition: TowerDefinition
	var valid: bool = true
	for definition: TowerDefinition in rules.catalog.towers:
		var errors: PackedStringArray = rules.roll_rules.validation_errors(definition.roll_attributes, definition.roll_profile)
		_check(errors.is_empty(), "Prototype roll rules admit %s: %s" % [definition.reward.id, " ".join(errors)])
		valid = valid and errors.is_empty()
		if definition.reward.id == &"war_drums":
			drums_definition = definition
	if not valid:
		return
	_check(drums_definition != null, "The actual prototype includes War Drums")
	if drums_definition == null:
		return
	_check(drums_definition.roll_attributes == PackedStringArray(["support_buff"]), "Shipped Drums opt into only support strength, never range")
	for index: int in range(TowerRollRules.RARITIES.size()):
		var rarity: String = TowerRollRules.RARITIES[index]
		var random := RandomNumberGenerator.new()
		random.seed = 0
		if not _select_drums_roll(random, rules.roll_rules, drums_definition, rarity):
			continue
		var combat := MatchCombat.new(rules, null, null, null, random)
		var coins: int = combat.coins[0]
		var accepted: bool = combat.build(0, Vector2i(5, 5), &"war_drums", MatchCombat.TargetMode.FURTHEST)
		_check(accepted and coins - combat.coins[0] == drums_definition.cost, "%s Drums placement succeeds and charges its authored price" % rarity)
		if not accepted:
			continue
		var drums := _tower(combat, 0, Vector2i(5, 5))
		_check(drums["rarity"] == rarity, "Paid placement exercises %s using the unchanged shipped pools and weights" % rarity)
		_check_drums_roll(drums, rules.roll_rules, drums_definition)
		var attribute_cost: int = drums["attribute_reroll_cost"]
		var shards: int = combat.reroll_currency[0]
		coins = combat.coins[0]
		_check(combat.reroll_tower(0, drums["id"], "attributes") and coins - combat.coins[0] == attribute_cost and combat.reroll_currency[0] == shards and drums["attribute_rerolls"] == 1 and drums["rarity"] == rarity, "%s attribute reroll is paid in Coins and retains its tier" % rarity)
		_check_drums_roll(drums, rules.roll_rules, drums_definition)
		var next_rarity: String = TowerRollRules.RARITIES[(index + 1) % TowerRollRules.RARITIES.size()]
		if not _select_drums_roll(random, rules.roll_rules, drums_definition, next_rarity, rarity):
			continue
		var rarity_cost: int = drums["rarity_reroll_cost"]
		coins = combat.coins[0]
		_check(combat.reroll_tower(0, drums["id"], "rarity") and shards - combat.reroll_currency[0] == rarity_cost and combat.coins[0] == coins and drums["rarity_rerolls"] == 1 and drums["attribute_rerolls"] == 0 and drums["rarity"] == next_rarity, "Paid %s-to-%s rarity reroll replaces the tier, including Mythic-to-Broken downgrade" % [rarity, next_rarity])
		_check_drums_roll(drums, rules.roll_rules, drums_definition)


func _select_drums_roll(random: RandomNumberGenerator, rules: TowerRollRules, definition: TowerDefinition, rarity: String, excluded: String = "") -> bool:
	for tier: Dictionary in rules.rarities:
		if tier["id"] != rarity:
			continue
		_check(float(tier["weight"]) > 0.0 and rarity != excluded, "Requested paid Drums tier is selectable")
		if float(tier["weight"]) <= 0.0 or rarity == excluded:
			return false
		# Find a stream state, not a pinned seed/result or modified rarity weight.
		# Replay that state through the real paid placement/reroll transaction.
		while true:
			var state: int = random.state
			var rolled: Dictionary = rules.generate_admitted(random, definition.roll_attributes, excluded, definition.roll_profile)
			if rolled["rarity"] == rarity:
				random.state = state
				return true
	_check(false, "Requested Drums tier exists in the shipped rules")
	return false


func _check_drums_roll(drums: Dictionary, rules: TowerRollRules, definition: TowerDefinition) -> void:
	var attributes: Array[Dictionary] = drums["attributes"]
	_check(attributes.size() == 1, "Every shipped Drums tier has exactly one non-opposing strength effect")
	_check(is_equal_approx(float(drums["range"]), definition.range_cells), "Placement and both rerolls preserve authored Drums coverage")
	if attributes.size() != 1:
		return
	var attribute: Dictionary = attributes[0]
	_check(attribute["effect"] == "support_buff", "Paid Drums placement and rerolls never roll range or fake effects")
	if attribute["effect"] != "support_buff":
		return
	var positive: bool = drums["rarity"] not in ["broken", "shoddy"]
	var value: float = attribute["value"]
	_check(attribute["positive"] == positive and (value > 0.0 if positive else value < 0.0), "Broken/Shoddy weaken support; higher rarities strengthen it without an opposing effect")
	for tier: Dictionary in rules.rarities:
		if tier["id"] == drums["rarity"]:
			var bounds: Vector2 = tier["positive_pool" if positive else "drawback_pool"]["support_buff"]
			_check(value >= bounds.x and value <= bounds.y, "Support strength retains its authored rarity-specific bounds")
	for component: String in ["damage_bonus", "attack_speed_bonus"]:
		_check(is_equal_approx(float(drums["behavior_config"][component]), float(definition.behavior_config[component]) * (1.0 + value)), "Paid Drums rolls apply their strength to the real %s aura" % component)


func _test_war_drums() -> void:
	_check(_rules().catalog.validation_errors().is_empty(), "Rebalanced authored resources satisfy content validation")
	var branches: Dictionary = {
		"forge": [FORGE, "support_damage_bonus", [0.5, 0.6, 0.7, 0.9], 825],
		"command_banner": [["drill_sergeant", "rallying_cry", "warlords_standard"], "support_speed_bonus", [0.5, 0.6, 0.7, 0.9], 825],
		"lookout_horn": [LOOKOUT, "support_range_bonus", [0.75, 1.0, 1.25, 1.75], 750],
		"bloodlust_totem": [TOTEM, "crit_chance", [0.1, 0.15, 0.2, 0.3], 750],
	}
	for branch: String in branches:
		var combat := MatchCombat.new(_rules(false))
		var before: int = combat.coins[0]
		var source := _built(combat, Vector2i(5, 5), &"war_drums", [])
		_check(before - combat.coins[0] == 110, "Placement retains its actual 110-Coin charge")
		var attack := _built(combat, Vector2i(6, 5), &"arrow_tower", [])
		var buddy := _built(combat, Vector2i(5, 6), &"war_drums", [])
		var buddy_radius: float = buddy["range"]
		# Remove the second mixed aura before purity assertions, but retain a
		# support target to prove the Horn never extends other support coverage.
		_check(combat.upgrade_tower(0, buddy["id"], "damage") and combat.upgrade_tower(0, buddy["id"], "speed") and combat.upgrade_tower(0, buddy["id"], branch), "Companion specializes into the same pure branch")
		var commands: Array = ["damage", "speed", branch] + branches[branch][0]
		var prices: Array[int] = [75, 113, int(branches[branch][3]), 900, 1350, 2250]
		for index: int in range(commands.size()):
			var command: String = commands[index]
			combat.coins[0] = prices[index] - 1
			var state: Dictionary = source.duplicate(true)
			_check(not combat.upgrade_tower(0, source["id"], command) and combat.coins[0] == prices[index] - 1 and source == state, "%s rejects unaffordable %s without spending or changing accepted state" % [branch, command])
			combat.coins[0] = prices[index]
			_check(combat.upgrade_tower(0, source["id"], command) and combat.coins[0] == 0, "%s charges exactly %d for %s" % [branch, prices[index], command])
			if index < 2:
				continue
			var expected: float = branches[branch][2][index - 2]
			for stat: String in ["support_damage_bonus", "support_speed_bonus", "support_range_bonus", "crit_chance"]:
				_check(is_equal_approx(float(attack[stat]), expected if stat == branches[branch][1] else 0.0), "%s tier %d affects only its chosen attacker stat (%s)" % [branch, index - 1, stat])
			var expected_radius: float = [2.0, 2.5, 2.5, 3.5][index - 2] if branch == "lookout_horn" else 2.0
			_check(is_equal_approx(float(source["range"]), expected_radius) and is_equal_approx(float(buddy["range"]), buddy_radius), "%s tier %d has only its own authored coverage; supports never extend each other" % [branch, index - 1])
		combat.coins[0] = 100000
		var final_state: Dictionary = source.duplicate(true)
		_check(not combat.upgrade_tower(0, source["id"], branch) and not combat.upgrade_tower(0, source["id"], String(commands.back())) and source == final_state and combat.coins[0] == 100000, "Terminal branches reject repurchase without spending")


func _test_crits() -> void:
	var combat := MatchCombat.new(_rules())
	_built(combat, Vector2i(5, 5), &"war_drums", ["damage", "speed", "bloodlust_totem"] + TOTEM)
	var striker := _built(combat, Vector2i(5, 6), &"arrow_tower", [])
	var plain_board := MatchCombat.new(_rules())
	var plain := _built(plain_board, Vector2i(5, 6), &"arrow_tower", [])
	var route: Array = [Vector2i(9, 6), Vector2i(8, 6), Vector2i(7, 6), Vector2i(6, 6)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: [route[3]], route[3]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	for board: MatchCombat in [combat, plain_board]:
		_check(board.sandbox_start(routing, 1, [] as Array[String]), "Crit fixture starts")
		board.sandbox_spawn(0, &"grunt", 1)
		board.enemies[0][0]["hp"] = 1000000
		board.enemies[0][0]["max_hp"] = 1000000
	var damage: int = striker["damage"]
	var doubled: int = 0
	for hit: int in range(400):
		var before: int = combat.enemies[0][0]["hp"]
		combat._hit(0, striker, 0)
		var dealt: int = before - int(combat.enemies[0][0]["hp"])
		_check(dealt == damage or dealt == ceili(damage * TowerDefinition.CRIT_MULTIPLIER), "Every hit is normal or exactly doubled")
		doubled += int(dealt != damage)
	_check(doubled == int(striker["crits"]) and doubled > 80 and doubled < 160, "About 30%% of discrete hits crit, and the tower counts them: %d" % doubled)
	var state: int = plain_board._crit_random.state
	for hit: int in range(50):
		plain_board._hit(0, plain, 0)
	_check(plain_board._crit_random.state == state and int(plain["crits"]) == 0, "Towers without crit chance never draw from the crit stream")
	var before: int = combat.enemies[0][0]["hp"]
	combat._hit(0, striker, 0, 7, true, &"", {}, true)
	_check(before - int(combat.enemies[0][0]["hp"]) == 7, "Continuous/burn damage never crits")


func _test_capstones() -> void:
	var rules := _rules(false)
	var combat := MatchCombat.new(rules)
	var heart := _built(combat, Vector2i(1, 1), &"gold_mine", ["damage", "speed"] + CRYSTAL)
	_check(not combat.upgrade_tower(0, heart["id"], "mother_ii"), "Mother II requires Mother I")
	var coins: int = combat.coins[0]
	_check(combat.upgrade_tower(0, heart["id"], "heart_of_the_mountain"), "Heart of the Mountain follows Mother Lode")
	_check(coins - combat.coins[0] == 2000 and combat.base_health[0] == 100 and combat.base_max_health[0] == 100, "Heart costs 2000 and grows nothing before a round clear")
	_check(not combat.upgrade_tower(0, heart["id"], "mother_i"), "The capstone paths are exclusive")
	var early := _built(combat, Vector2i(3, 1), &"gold_mine", ["damage", "speed", "crystal_mine", "deeper_veins"])
	_check(not combat.upgrade_tower(0, early["id"], "heart_of_the_mountain"), "Capstones wait for Mother Lode")
	var mother := _built(combat, Vector2i(5, 1), &"gold_mine", ["damage", "speed"] + CRYSTAL)
	var lode_clear: int = mother["behavior_config"]["clear_shards"]
	coins = combat.coins[0]
	for step: String in ["mother_i", "mother_ii", "mother_iii"]:
		_check(combat.upgrade_tower(0, mother["id"], step), "Mother path accepts %s" % step)
	_check(coins - combat.coins[0] == 6000 and is_equal_approx(float(mother["output_multiplier"]), 1.331), "Mother I-III cost 1K/2K/3K and compound +10% each")
	_check(int(mother["behavior_config"]["clear_shards"]) == ceili(lode_clear * 1.331 - 0.000000001), "Shard output is multiplied by 1.331: %d from %d" % [mother["behavior_config"]["clear_shards"], lode_clear])
	_check(MatchCombat.tower_level(mother) == MatchCombat.tower_level(heart) + 2, "Each capstone step adds a level")
	combat.base_health[0] = 90
	_clear_round(combat)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_max_health[0] == 105 and combat.base_health[0] == 95 and combat.snapshot()["max_health"][0] == 105 and int(heart["base_max_health_bonus"]) == 5, "A cleared round grows base max HP by 5 and regenerates 5")
	_check(combat.base_max_health[1] == 100, "The Heart only grows its own board")
	_clear_round(combat)
	_check(combat.base_max_health[0] == 110 and combat.base_health[0] == 100, "Max HP keeps growing every cleared round")
	var summary: String = MatchPlanningScreen.behavior_summary(heart)
	_check(summary.contains("+5 base max HP & 5 HP regen / round clear") and summary.contains("Grown +10 base max HP · cap 1000") and not MatchPlanningScreen.behavior_summary(mother).contains("base max HP"), "The HUD summary shows the Heart's growth: %s" % summary)
	_clear_round(combat, heart)
	_check(combat.base_max_health[0] == 110 and combat.base_health[0] == 100, "A stunned Heart neither grows nor regenerates")
	var second := _built(combat, Vector2i(7, 1), &"gold_mine", ["damage", "speed"] + CRYSTAL + ["heart_of_the_mountain"])
	heart["base_max_health_bonus"] = 893
	combat._refresh_board(0)
	combat.base_health[0] = 993
	_clear_round(combat)
	_check(combat.base_max_health[0] == 1000 and combat.base_health[0] == 1000 and int(heart["base_max_health_bonus"]) == 898 and int(second["base_max_health_bonus"]) == 2, "Two Hearts share the 1000 max HP limit: %d" % combat.base_max_health[0])
	_clear_round(combat)
	_check(combat.base_max_health[0] == 1000 and combat.base_health[0] == 1000, "Growth and regen stop at 1000 max HP")
	_check(combat.sell_tower(0, heart["id"]) and combat.base_max_health[0] == 102 and combat.base_health[0] == 102, "Selling a Heart removes the max HP it grew and caps current HP")
	_check(combat.sell_tower(0, second["id"]) and combat.base_max_health[0] == 100 and combat.base_health[0] == 100, "Selling the last Heart restores the starting maximum")


func _clear_round(combat: MatchCombat, stunned: Dictionary = {}) -> void:
	var route: Array = [Vector2i(9, 0), Vector2i(8, 0), Vector2i(7, 0)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	_check(combat.start_wave(routing), "A Heart round starts")
	for slot: int in range(2):
		combat.enemies[slot].clear()
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned = [0, 0]
	if not stunned.is_empty():
		# Wave start clears stuns, so the stun lands during the round.
		stunned["stunned_remaining"] = 1.0
	combat.advance(1.0 / 60.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING, "The empty Heart round clears")
