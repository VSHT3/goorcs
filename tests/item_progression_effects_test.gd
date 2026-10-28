extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_worldroot_lifetime()
	_test_shebang_slots_and_upgrade()
	_test_all_terminal_paths()
	_test_doom_shared_sequence()
	if failures == 0:
		print("PASS: Worldroot binding/destruction, historical terminal slots, actual-clear growth, discounted BangBang and shared Doom rounds")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rules(simple: bool = true) -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog = preload("res://resources/content_catalog.tres").duplicate(true) as ContentCatalog
	if simple:
		var tower := TowerDefinition.new()
		tower.reward = TowerReward.new()
		tower.reward.id = &"item_fixture"
		tower.reward.title = "Item fixture"
		tower.damage = 100
		tower.interval = 1.0
		tower.range_cells = 20.0
		rules.catalog.towers = [tower]
		rules.catalog.starter_tower_id = tower.reward.id
	var enemy := EnemyDefinition.new()
	enemy.id = &"item_remainder"
	enemy.title = "Item remainder"
	enemy.base_damage = 10
	rules.catalog.enemies = [enemy]
	rules.base_health = 1000000
	rules.starting_coins = 1000000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.wave_reward = 30
	rules.wave_reward_growth = 0
	rules.kill_bounty = 0
	rules.enemy_health = 1
	rules.health_growth = 0
	rules.enemy_speed = 1000.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.roll_rules = null
	return rules


func _owner(simple: bool = true) -> MatchCombat:
	var rules: CombatRules = _rules(simple)
	var owner := MatchCombat.new(rules)
	var ids: Array[String] = []
	for definition: TowerDefinition in rules.catalog.towers:
		ids.append(String(definition.reward.id))
	owner.configure_item_loadouts([ids, ids])
	return owner


func _build(owner: MatchCombat, cell: Vector2i, type_id: StringName = &"item_fixture", slot: int = 0) -> Dictionary:
	if not owner.build(slot, cell, type_id, MatchCombat.TargetMode.FURTHEST):
		_check(false, "Fixture tower is accepted")
		return {}
	return owner.towers[slot].back()


func _routing() -> Array[Dictionary]:
	var route: Array = [Vector2i.ZERO, Vector2i.RIGHT]
	var next: Dictionary = {Vector2i.ZERO: [Vector2i.RIGHT], Vector2i.RIGHT: []}
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _clear(owner: MatchCombat) -> void:
	if not owner.start_wave(_routing()):
		_check(false, "Real progression wave admission succeeds")
		return
	for tick: int in range(200):
		if owner.phase != MatchCombat.Phase.WAVE:
			break
		owner.advance(0.05)
	_check(owner.phase == MatchCombat.Phase.PLANNING, "Real wave completes without debug-generated clears")


func _max_simple(owner: MatchCombat, tower: Dictionary) -> void:
	_check(owner.upgrade_tower(0, int(tower["id"]), "damage"), "Simple terminal buys damage")
	_check(owner.upgrade_tower(0, int(tower["id"]), "speed"), "Simple terminal buys speed")


func _test_worldroot_lifetime() -> void:
	var owner: MatchCombat = _owner()
	var tower: Dictionary = _build(owner, Vector2i(0, 1))
	var other: Dictionary = _build(owner, Vector2i(3, 1))
	var enemy_tower: Dictionary = _build(owner, Vector2i(0, 1), &"item_fixture", 1)
	_clear(owner)
	_check(owner.grant_item(0, &"worldroot_seed"), "Seed is host-granted after a historical clear")
	_check(not owner.item_command(0, &"worldroot_seed", "bind", int(enemy_tower["id"])), "Cannot bind an opposing attacker")
	_check(owner.item_command(0, &"worldroot_seed", "bind", int(tower["id"])), "Seed binds a friendly attacker")
	_check(is_equal_approx(float(tower["damage_multiplier"]), 1.0), "Binding grants no retroactive damage")
	_check(not owner.item_command(0, &"worldroot_seed", "bind", int(other["id"])), "Binding is once per run, not transferable")
	_check(owner.debug_set_round(50), "Debug jump accepted without a clear")
	_check(is_equal_approx(float(tower["damage_multiplier"]), 1.0), "Debug jump never grows the seed")
	_clear(owner)
	_check(is_equal_approx(float(tower["damage_multiplier"]), 1.02), "One actual clear grants exactly two damage percentage points")
	_check(is_equal_approx(float(other["damage_multiplier"]), 1.0), "Seed growth belongs only to its bound tower")
	_check(owner.remove_item(0, &"worldroot_seed"), "Seed can be temporarily unequipped")
	_clear(owner)
	_check(owner.grant_item(0, &"worldroot_seed"), "Regrant retains binding history")
	_check(is_equal_approx(float(tower["damage_multiplier"]), 1.02), "Unequipped clears do not accrue growth")
	for clear_index: int in range(35):
		_clear(owner)
	_check(is_equal_approx(float(tower["damage_multiplier"]), 1.6), "Worldroot caps at sixty percent, not sixty percent per clear")
	_check(owner.remove_item(0, &"worldroot_seed"), "Sale regression removes seed first")
	_check(owner.sell_tower(0, int(tower["id"])), "Bound tower sale succeeds while seed is unequipped")
	_check(owner.grant_item(0, &"worldroot_seed"), "Host inventory may restore an ID but not its destroyed run seed")
	_check(not owner.item_command(0, &"worldroot_seed", "bind", int(other["id"])), "Selling permanently destroys binding and forbids replacement")
	_check(is_equal_approx(float(other["damage_multiplier"]), 1.0), "Destroyed seed never transfers its bonus")
	var passive: MatchCombat = _owner(false)
	var mine: Dictionary = _build(passive, Vector2i.ZERO, &"gold_mine")
	passive.grant_item(0, &"worldroot_seed")
	_check(not passive.item_command(0, &"worldroot_seed", "bind", int(mine["id"])), "Passive economy towers cannot bind Worldroot")


func _test_shebang_slots_and_upgrade() -> void:
	var owner: MatchCombat = _owner()
	var first: Dictionary = _build(owner, Vector2i(0, 1))
	var duplicate: Dictionary = _build(owner, Vector2i(3, 1))
	_max_simple(owner, first)
	_max_simple(owner, duplicate)
	_clear(owner)
	var baseline: float = float(first["interval"])
	_check(owner.grant_item(0, &"the_whole_shebang"), "Shebang grant registers already-maxed towers")
	_check(is_equal_approx(float(first["interval"]), baseline), "Maxed pre-grant towers receive no historical growth")
	_clear(owner)
	_check(is_equal_approx(float(first["interval"]), baseline / 1.01), "First qualifying tower gains real attack rate on the activation clear")
	_check(is_equal_approx(float(duplicate["interval"]), baseline), "Duplicate terminals do not get extra registered slots")
	owner.configure_item_loadouts([[], []])
	_check(owner.sell_tower(0, int(first["id"])), "Selling registered terminal preserves its slot")
	_clear(owner)
	var replacement: Dictionary = _build(owner, Vector2i(6, 1))
	_max_simple(owner, replacement)
	_check(is_equal_approx(float(replacement["interval"]), baseline / 1.01), "Next same-terminal tower inherits paused vacancy bonus: interval=%s ledger=%s terminals=%s" % [replacement["interval"], owner.item_runtime.state(0)["progression"]["shebang"]["slots"], owner.item_runtime.progression._terminals[0]])
	_check(is_equal_approx(float(duplicate["interval"]), baseline), "Older duplicate does not silently steal a sold slot")
	_clear(owner)
	_check(is_equal_approx(float(replacement["interval"]), baseline / 1.02), "Occupied replacement resumes one-point growth")
	owner.remove_item(0, &"the_whole_shebang")
	_clear(owner)
	owner.grant_item(0, &"the_whole_shebang")
	_check(is_equal_approx(float(replacement["interval"]), baseline / 1.02), "Unequip preserves history but pauses growth")
	for clear_index: int in range(90):
		_clear(owner)
	_check(is_equal_approx(float(replacement["interval"]), baseline / 1.85), "Shebang's actual attack-rate cap is eighty-five percent")
	owner.grant_item(0, &"dabloons")
	owner.coins[0] = 8999
	var before: Dictionary = owner.item_runtime.state(0)["progression"].duplicate(true)
	_check(not owner.item_command(0, &"the_whole_shebang", "upgrade"), "Discounted upgrade still rejects one Coin short")
	_check(owner.coins[0] == 8999 and owner.item_runtime.state(0)["progression"] == before, "Rejected upgrade changes neither currency nor historical ledger")
	owner.coins[0] = 9000
	_check(owner.item_command(0, &"the_whole_shebang", "upgrade"), "BangBang buys for ceil(10000 times 0.9)")
	_check(owner.coins[0] == 0 and not owner.item_runtime.has(0, &"the_whole_shebang") and owner.item_runtime.has(0, &"the_whole_shebang_orcfeccion"), "Paid upgrade is one debit and explicit source replacement")
	_check(is_equal_approx(float(replacement["interval"]), baseline / 1.85), "Upgrade preserves rate and raises only its future cap")
	for clear_index: int in range(35):
		_clear(owner)
	_check(is_equal_approx(float(replacement["interval"]), baseline / 2.15), "BangBang growth caps at one hundred fifteen percent")
	owner.grant_item(0, &"the_whole_shebang")
	owner.remove_item(0, &"the_whole_shebang_orcfeccion")
	_clear(owner)
	owner.grant_item(0, &"the_whole_shebang_orcfeccion")
	_check(is_equal_approx(float(replacement["interval"]), baseline / 2.15), "Temporary lower cap never destroys retained BangBang growth")


func _test_all_terminal_paths() -> void:
	var rules: CombatRules = _rules(false)
	var owner := MatchCombat.new(rules)
	var ids: Array[String] = []
	for definition: TowerDefinition in rules.catalog.towers:
		ids.append(String(definition.reward.id))
	owner.configure_item_loadouts([ids, ids])
	owner.grant_item(0, &"the_whole_shebang")
	var expected_counts: Dictionary = {"arrow_tower": 3, "orc_ballista": 2, "rune_obelisk": 4, "lightning": 1, "war_drums": 4, "gold_mine": 5, "orcapult": 2}
	var placed: int = 0
	var registered_towers: Array[Dictionary] = []
	for definition: TowerDefinition in rules.catalog.towers:
		var terminals: Array[Dictionary] = TowerGuide.terminal_command_metadata(definition)
		_check(terminals.size() == int(expected_counts[String(definition.reward.id)]), "Every authored terminal, not intermediate branch, is required for " + String(definition.reward.id))
		for terminal: Dictionary in terminals:
			var tower: Dictionary = _build(owner, Vector2i(placed * 5, 3), definition.reward.id)
			placed += 1
			registered_towers.append(tower)
			var key: String = String(definition.reward.id) + ":" + String(terminal["id"])
			var commands: Array[String] = terminal["commands"]
			for index: int in range(commands.size()):
				_check(int(owner.item_runtime.state(0)["progression"]["shebang"]["slots"][key]["tower_id"]) == -1, "Incomplete terminal cannot register early: " + key)
				_check(owner.upgrade_tower(0, int(tower["id"]), commands[index]), "Pure terminal metadata is actually purchasable: " + key + " / " + commands[index])
			_check(int(owner.item_runtime.state(0)["progression"]["shebang"]["slots"][key]["tower_id"]) == int(tower["id"]), "Fully maxed ordered/optional/capstone path registers: " + key)
			if commands.has("boulders"):
				_check(commands.has("freeze_runes") and commands.has("mountain_heart"), "Boulders terminal requires both compatible Freeze and finale")
			if commands.has("mother_iii"):
				_check(not commands.has("heart_of_the_mountain"), "Exclusive mine capstones stay distinct")
	_check(bool(owner.item_runtime.state(0)["progression"]["shebang"]["activated"]), "All attacker/support/economy terminal paths finish the frozen checklist")
	_clear(owner)
	for tower: Dictionary in registered_towers:
		var bonus: float = owner.item_runtime.progression.attack_rate_bonus(0, tower)
		var attacking: bool = tower["behavior_kind"] in ["attack", "chain", "catapult"]
		_check(is_equal_approx(bonus, 0.01 if attacking else 0.0), "Actual clear grows occupied attacker slots without fabricating passive attack rates")


func _test_doom_shared_sequence() -> void:
	var owner: MatchCombat = _owner()
	_check(owner.next_wave_number() == 1, "Normal run has no implicit Doom skip")
	owner.grant_item(0, &"ominous_bells_of_doom")
	owner.grant_item(1, &"ominous_bells_of_doom")
	for preview: int in range(3):
		_check(owner.next_wave_number() == 10, "Both owners and repeated previews share one upcoming Doom step")
	var coins_before: int = owner.coins[0]
	var health_before: int = owner.base_health[0]
	_clear(owner)
	_check(owner.wave == 10 and owner.next_wave_number() == 20, "Actual played Doom rounds advance ten, never twenty for two owners")
	_check(owner.coins[0] - coins_before == 30 and owner.reroll_currency[0] == 3, "Skipped Doom numbers grant no additional clear rewards")
	_check(health_before - owner.base_health[0] == 11 and health_before - owner.base_health[1] == 11, "Both crystals take the same first-step times-1.1 leak damage")
	_check(is_equal_approx(owner.item_runtime.progression.base_damage_multiplier(), 1.1), "First admitted Doom step has authored initial damage")
	health_before = owner.base_health[0]
	_clear(owner)
	_check(owner.wave == 20 and health_before - owner.base_health[0] == 12, "Second played step uses times-1.2 rather than displayed-round scaling")
	owner.remove_item(0, &"ominous_bells_of_doom")
	_check(owner.next_wave_number() == 30, "One remaining owner keeps shared Doom enabled")
	owner.remove_item(1, &"ominous_bells_of_doom")
	_check(owner.next_wave_number() == 21 and is_equal_approx(owner.item_runtime.progression.base_damage_multiplier(), 1.0), "No owners restores normal upcoming wave and leak damage")
	owner.grant_item(0, &"ominous_bells_of_doom")
	_clear(owner)
	_check(owner.wave == 30 and is_equal_approx(owner.item_runtime.progression.base_damage_multiplier(), 1.3), "Regrant retains the run step counter")
	for step: int in range(100):
		owner.item_runtime.progression.on_wave_start(40 + step * 10)
	_check(is_equal_approx(owner.item_runtime.progression.base_damage_multiplier(), 10.0), "Shared escalating leak multiplier caps at ten")
	var midrun: MatchCombat = _owner()
	_check(midrun.debug_set_round(17), "Midrun debug fixture starts after wave sixteen")
	midrun.grant_item(1, &"ominous_bells_of_doom")
	_check(midrun.next_wave_number() == 20, "Midrun first Doom step aligns strictly after the current wave")
	_check(midrun.debug_set_round(21), "Exact-multiple alignment fixture accepted")
	_check(midrun.next_wave_number() == 30, "Grant on a multiple never replays the current numbered wave")
