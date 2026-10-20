extends SceneTree
## Rune obelisk branch chains (Boulders, Onyx Ring, Storm Sigil, Void Monolith),
## the Void maximum-HP drain, the Shard-producing Crystal Mine, and step-aware
## board variants for finale artwork.

const RUNE_CHAINS: Dictionary = {
	"boulders": ["rolling_stones", "landslide", "mountain_heart"],
	"onyx_ring": ["twin_rings", "obsidian_crown", "eclipse"],
	"storm_sigil": ["charged_orbs", "tempest", "wrath_of_the_storm"],
	"void_monolith": ["gravity_well", "event_horizon", "singularity"],
}
const MINE_CHAIN: Array[String] = ["deeper_veins", "geode_drill", "resonant_lattice", "mother_lode"]

var failures: int = 0


func _init() -> void:
	_test_validation()
	_test_rune_chains()
	_test_void_drain()
	_test_crystal_mine()
	_test_finale_variants()
	if failures == 0:
		print("PASS: ordered Rune branch chains and new Storm/Void branches, Void max-HP drain, Shard-producing Crystal Mine, and step-aware finale artwork")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _rules() -> CombatRules:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	return rules


func _built(type_id: StringName, commands: Array, rules: CombatRules = null) -> MatchCombat:
	var combat := MatchCombat.new(rules if rules != null else _rules())
	combat.build(0, Vector2i(0, 1), type_id, MatchCombat.TargetMode.FURTHEST)
	var tower: Dictionary = combat.towers[0][0]
	for command: Variant in ["damage", "speed"] + commands:
		_check(combat.upgrade_tower(0, tower["id"], String(command)), "%s accepts %s in order" % [type_id, command])
	return combat


func _definition(type_id: StringName) -> TowerDefinition:
	for definition: TowerDefinition in _rules().catalog.towers:
		if definition.reward.id == type_id:
			return definition
	return null


func _test_validation() -> void:
	_check(TowerDefinition.valid_evolutions(_definition(&"rune_obelisk")), "Shipped Rune branches validate")
	_check(TowerDefinition.valid_evolutions(_definition(&"gold_mine")), "Shipped Gold Mine branches validate")
	var rune: TowerDefinition = _definition(&"rune_obelisk").duplicate(true)
	rune.evolutions["storm_sigil"]["continuous"] = true
	_check(not TowerDefinition.valid_evolutions(rune), "Storm Sigil must pulse")
	rune = _definition(&"rune_obelisk").duplicate(true)
	rune.evolutions["onyx_ring"]["max_hp_damage"] = 0.1
	_check(not TowerDefinition.valid_evolutions(rune), "Only the Void Monolith drains maximum HP")
	rune = _definition(&"rune_obelisk").duplicate(true)
	rune.evolutions["void_monolith"]["damage_type"] = "fire"
	_check(not TowerDefinition.valid_evolutions(rune), "Rune branch damage types are restricted")
	_check(not TowerDefinition.valid_branch_upgrades("boulders", [{"id": "x", "title": "X", "cost": 1, "behavior_add": {"clear_shards": 1}}]), "Shard production steps belong to the Crystal Mine only")
	_check(not TowerDefinition.valid_branch_upgrades("crystal_mine", [{"id": "x", "title": "X", "cost": 1, "behavior_add": {"clear_income": 1}}]), "Crystal Mine steps cannot add Coins")
	var mine: TowerDefinition = _definition(&"gold_mine").duplicate(true)
	mine.evolutions["crystal_mine"]["behavior_config"]["clear_shards"] = 0
	_check(not TowerDefinition.valid_evolutions(mine), "A Crystal Mine must dig Shards on round clear")


func _test_rune_chains() -> void:
	var types: Dictionary = {"boulders": &"physical", "onyx_ring": &"magic", "storm_sigil": &"lightning", "void_monolith": &"magic"}
	for branch: String in RUNE_CHAINS:
		var combat := _built(&"rune_obelisk", [branch])
		var tower: Dictionary = combat.towers[0][0]
		var steps: Array = RUNE_CHAINS[branch]
		_check(not combat.upgrade_tower(0, tower["id"], steps[1]), "%s steps are bought in order" % branch)
		var damage: float = float(tower["base_damage"])
		var interval: float = float(tower["base_interval"])
		var reach: float = float(tower["range"])
		var authored: Array = combat._tower_types["rune_obelisk"]["evolutions"][branch]["upgrades"]
		for index: int in range(steps.size()):
			_check(combat.upgrade_tower(0, tower["id"], steps[index]), "%s accepts %s" % [branch, steps[index]])
			var step: Dictionary = authored[index]
			damage *= float(step.get("damage_multiplier", 1.0))
			interval /= float(step.get("attack_rate_multiplier", 1.0))
			reach += float(step.get("range_bonus", 0))
			_check(is_equal_approx(float(tower["base_damage"]), damage) and is_equal_approx(float(tower["base_interval"]), interval) and is_equal_approx(float(tower["range"]), reach), "%s compounds damage, pulse rate and range" % steps[index])
		_check(combat._tower_damage_type(tower) == types[branch] or (branch == "boulders" and combat._tower_damage_type(tower) == &"physical"), "%s keeps its damage type" % branch)
		_check(int(tower["orbit_bonus"]) > 0 and MatchCombat.tower_level(tower) == 4 + steps.size(), "%s adds orbiters and one level per step" % branch)
		_check(not combat.upgrade_tower(0, tower["id"], steps[steps.size() - 1]), "%s finale cannot be bought twice" % branch)
	var frozen := _built(&"rune_obelisk", ["boulders", "rolling_stones", "freeze_runes"])
	_check(frozen.towers[0][0]["freeze_upgraded"] and frozen._tower_damage_type(frozen.towers[0][0]) == &"ice", "Freeze Runes still combine with the Boulders chain")


func _test_void_drain() -> void:
	var combat := _built(&"rune_obelisk", ["void_monolith", "gravity_well", "event_horizon", "singularity"])
	var tower: Dictionary = combat.towers[0][0]
	_check(is_equal_approx(float(tower["max_hp_drain"]), 0.06), "Singularity drains 6% of maximum HP per second")
	var route: Array = [Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	combat.sandbox_start(routing, 1, [] as Array[String])
	combat.sandbox_spawn(0, &"grunt", 1)
	var enemy: Dictionary = combat.enemies[0][0]
	# Void keeps the 1.5-cell Rune reach (only Storm Sigil gains range).
	enemy["progress"] = 2.0
	enemy["pos"] = combat._position(route, 2.0)
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["base_speed"] = 0.0
	enemy["speed"] = 0.0
	combat.advance(1.0)
	var dealt: int = 10000 - int(enemy["hp"])
	var expected: float = (float(tower["base_damage"]) * float(tower["speed_multiplier"]) + 10000.0 * 0.06) * float(tower["damage_multiplier"]) * combat._elemental_damage_multiplier(enemy, &"magic")
	_check(absf(float(dealt) - expected) <= 1.0, "One exposed second deals base damage plus the max-HP drain: dealt=%d expected=%.1f" % [dealt, expected])


func _test_crystal_mine() -> void:
	var rules := _rules()
	rules.sandbox_mode = false
	rules.starting_coins = 100000
	var combat := _built(&"gold_mine", ["crystal_mine"], rules)
	var tower: Dictionary = combat.towers[0][0]
	_check(tower["behavior_kind"] == "crystal", "Crystal Mine changes the mine's production kind")
	_check(not combat.upgrade_tower(0, tower["id"], "geode_drill"), "Crystal Mine steps are bought in order")
	var coins_before: int = combat.coins[0]
	var shards_before: int = combat.reroll_currency[0]
	var clear: int = int(tower["behavior_config"]["clear_shards"])
	var route: Array = [Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0)]
	var next: Dictionary = {route[0]: [route[1]], route[1]: [route[2]], route[2]: []}
	var routing: Array[Dictionary] = [{"route": route, "next": next}, {"route": route, "next": next}]
	_check(combat.start_wave(routing), "A wave starts for the production fixture")
	for enemy_slot: int in range(2):
		combat.enemies[enemy_slot].clear()
	combat.wave_roster.clear()
	combat.spawn_times.clear()
	combat._spawned[0] = 0
	combat._spawned[1] = 0
	var ticks: int = 0
	while combat.phase == MatchCombat.Phase.WAVE and ticks < 600:
		combat.advance(1.0 / 60.0)
		ticks += 1
	var reward: int = combat._rules.wave_reward + combat.wave * combat._rules.wave_reward_growth
	_check(combat.coins[0] - coins_before == reward + combat.income[0], "A Crystal Mine adds no Coins of its own on round clear")
	_check(combat.reroll_currency[0] - shards_before == combat._rules.clear_reroll_currency + clear and int(tower["shards_generated"]) == clear, "Round clear digs %d Shards into the reroll currency" % clear)
	for step: String in MINE_CHAIN:
		_check(combat.upgrade_tower(0, tower["id"], step), "Crystal Mine accepts %s" % step)
	var config: Dictionary = tower["behavior_config"]
	_check(int(config["periodic_shards"]) > 0 and float(config["periodic_interval"]) < 8.0 and int(config["clear_shards"]) > clear, "Mother Lode raises clear and periodic Shards and drills faster")
	_check(combat._periodic_amount(tower) == int(config["periodic_shards"]) and combat._has_periodic_production(), "Periodic Shard production drives the combat clock")
	var summary: String = MatchPlanningScreen.behavior_summary(tower)
	_check(summary.contains("Shards / round clear") and MatchPlanningScreen.tower_stats_text(tower, combat._tower_types["gold_mine"]).contains("Shards generated"), "Inspection explains Shard production")


func _test_finale_variants() -> void:
	var rune: TowerReward = _definition(&"rune_obelisk").reward
	_check(rune.board_variant("storm_sigil").has("texture") and rune.board_variant("storm_sigil", "", ["charged_orbs"]) == rune.board_variant("storm_sigil"), "Storm Sigil has its own look until a step with art is bought")
	_check(rune.board_variant("storm_sigil", "", ["charged_orbs", "tempest", "wrath_of_the_storm"]) == rune.board_variants["wrath_of_the_storm"], "The finale step's art wins over the branch art")
	var ballista: TowerReward = _definition(&"orc_ballista").reward
	var finale: Dictionary = ballista.board_variant("bounce", "", ["magic_ballista", "double_magic", "stronger_magic", "sumggm"])
	_check(finale.get("directional_weapon_textures", []).size() == 8, "S.U.M.G.G.M. replaces all eight weapon poses")
	var mine: TowerReward = _definition(&"gold_mine").reward
	_check(mine.board_variant("crystal_mine", "", ["deeper_veins", "geode_drill", "resonant_lattice"]) == mine.board_variants["geode_drill"], "Crystal Mine art follows the latest step that has its own art")
	var catalog: ContentCatalog = _rules().catalog
	_check(catalog.validation_errors().is_empty(), "The shipped catalog accepts every new branch and variant: %s" % [catalog.validation_errors()])
