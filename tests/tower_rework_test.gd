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
	_test_war_drums()
	_test_crits()
	_test_capstones()
	if failures == 0:
		print("PASS: circular reach and proportional range rolls, Storm-only Rune range, War Drums damage/speed/range/crit branches, isolated crit rolls and Crystal Mine capstone fork with base HP/regen and compounding Shards")
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


func _test_war_drums() -> void:
	var catalog: ContentCatalog = _rules().catalog
	var drums: TowerDefinition = null
	for definition: TowerDefinition in catalog.towers:
		if definition.reward.id == &"war_drums":
			drums = definition
	_check(drums.cost == 110 and int(drums.evolutions["forge"]["cost"]) == 550 and int(drums.evolutions["command_banner"]["cost"]) == 550, "Forge and Command Banner cost more")
	var combat := MatchCombat.new(_rules())
	var forge := _built(combat, Vector2i(5, 5), &"war_drums", ["damage", "speed", "forge"] + FORGE)
	var arrow := _built(combat, Vector2i(6, 5), &"arrow_tower", [])
	_check(is_equal_approx(float(forge["behavior_config"]["damage_bonus"]), 0.9) and is_equal_approx(float(arrow["support_damage_bonus"]), 0.9), "Dragonfire Forge stacks its steps and keeps both paid upgrades: %s" % forge["behavior_config"])
	_check(is_equal_approx(float(forge["range"]), 2.5), "Master Smith widens the Forge's own aura")
	var lookout_board := MatchCombat.new(_rules())
	var horn := _built(lookout_board, Vector2i(5, 5), &"war_drums", ["damage", "speed", "lookout_horn"])
	var near := _built(lookout_board, Vector2i(6, 5), &"arrow_tower", [])
	var buddy := _built(lookout_board, Vector2i(5, 6), &"war_drums", [])
	_check(is_equal_approx(float(near["range"]), 3.75), "Lookout Horn adds reach to nearby attacking towers: %s" % near["range"])
	_check(is_equal_approx(float(buddy["range"]), 2.0), "Range auras never extend other auras")
	for step: String in LOOKOUT:
		_check(lookout_board.upgrade_tower(0, horn["id"], step), "Lookout Horn accepts %s" % step)
	_check(is_equal_approx(float(near["range"]), 4.75) and is_equal_approx(float(horn["range"]), 3.5) and is_equal_approx(float(near["crit_chance"]), 0.05), "All-Seeing Tower: +1.75 reach, wider aura and Eagle Eyes crits")
	var totem_board := MatchCombat.new(_rules())
	var totem := _built(totem_board, Vector2i(5, 5), &"war_drums", ["damage", "speed", "bloodlust_totem"] + TOTEM)
	var striker := _built(totem_board, Vector2i(6, 5), &"arrow_tower", [])
	_check(is_equal_approx(float(striker["crit_chance"]), 0.3) and is_equal_approx(float(striker["support_range_bonus"]), 0.25), "Skullsplitter Totem: 30% crit chance and a little reach")
	_check(not totem_board.upgrade_tower(0, totem["id"], "forge"), "Drum branches stay exclusive")


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
	_check(coins - combat.coins[0] == 1500 and combat.base_health[0] == 105 and combat.base_max_health[0] == 105 and combat.snapshot()["max_health"][0] == 105, "Heart adds 5 max base HP, filled at once")
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
	var route: Array = [Vector2i(9, 0), Vector2i(8, 0), Vector2i(7, 0)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	combat.base_health[0] = 90
	_check(combat.start_wave(routing), "A regen wave starts")
	for slot: int in range(2):
		combat.enemies[slot].clear()
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned = [0, 0]
	combat.advance(1.0 / 60.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health[0] == 95, "Heart regenerates 5 base HP per cleared round")
	combat.base_health[0] = 104
	_check(combat.start_wave(routing), "A capped regen wave starts")
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned = [0, 0]
	combat.advance(1.0 / 60.0)
	_check(combat.base_health[0] == 105, "Regen never exceeds the maximum")
	_check(combat.sell_tower(0, heart["id"]) and combat.base_max_health[0] == 100 and combat.base_health[0] == 100, "Selling the Heart removes its max HP and caps current HP")

