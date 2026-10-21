extends SceneTree
## Dreadmaw, the Bone Wyrm: definition and round-200 debut, Soulfire aimed at the
## densest towers and withering their damage, Raise the Fallen from recent nearby
## deaths only, enrage below half HP, and Skeltorcs spilling out on death.

const ID := &"dreadmaw"

var failures: int = 0


func _init() -> void:
	_test_definition()
	_test_soulfire()
	_test_raise_dead()
	_test_enrage_and_death()
	_test_debut()
	if failures == 0:
		print("PASS: Dreadmaw definition, densest-tower Soulfire wither and fade, Raise the Fallen limits, enrage and death Skeltorcs, and round-200 debut")
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


func _definition() -> EnemyDefinition:
	for definition: EnemyDefinition in _rules().catalog.enemies:
		if definition.id == ID:
			return definition
	return null


func _board(rules: CombatRules = null) -> MatchCombat:
	var combat := MatchCombat.new(rules if rules != null else _rules())
	var route: Array = []
	for x: int in range(20):
		route.append(Vector2i(19 - x, 2))
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	_check(combat.sandbox_start([{"route": route, "next": next}, {"route": route, "next": next}], 200, [] as Array[String]), "The sandbox round starts")
	return combat


func _spawn(combat: MatchCombat, type_id: StringName, progress: float, hp: int = 100000) -> Dictionary:
	_check(combat.sandbox_spawn(0, type_id, 1), "%s spawns" % type_id)
	var enemy: Dictionary = combat.enemies[0].back()
	enemy["progress"] = progress
	enemy["pos"] = combat._position(enemy["route"], progress)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	return enemy


func _until(combat: MatchCombat, caster: Dictionary, spell: String, limit: float = 30.0) -> bool:
	var waited: float = 0.0
	while waited < limit:
		if caster["spell"] == spell:
			return true
		combat.advance(0.05)
		waited += 0.05
	return false


func _test_definition() -> void:
	var definition: EnemyDefinition = _definition()
	_check(definition != null and definition.boss and definition.first_wave == 200, "Dreadmaw is the round-200 boss")
	_check(definition.immune_elements.has("ice") and definition.ice_immune and is_equal_approx(definition.physical_damage_multiplier, 0.6) and is_equal_approx(definition.fire_damage_multiplier, 1.5), "Bone resists Physical, burns from Fire, and ignores Ice")
	_check(definition.death_spawn_type == &"skeleorc" and definition.death_spawn_count == 8 and definition.enrage_health_fraction == 0.5, "It enrages at half HP and spills eight Skeltorcs")
	_check(Spellbook.validation_error(definition.spellbook).is_empty() and definition.spellbook["order"] == ["soulfire", "raise_dead"], "Soulfire and Raise the Fallen make up its spellbook")
	var book: Dictionary = definition.spellbook.duplicate(true)
	book["raise_dead"]["window"] = Spellbook.FALLEN_MEMORY + 1.0
	_check(not Spellbook.validation_error(book).is_empty(), "Raise the Fallen cannot reach further back than the death ledger")
	for animation: StringName in [&"walk", &"walk_enraged", &"soulfire", &"raise_dead", &"death"]:
		_check(definition.animation_frames.has_animation(animation), "Dreadmaw has a %s animation" % animation)
	var rules := _rules()
	var raiser: EnemyDefinition = null
	for candidate: EnemyDefinition in rules.catalog.enemies:
		if candidate.id == ID:
			raiser = candidate
	raiser.spellbook["raise_dead"]["type"] = "troll"
	_check(not rules.catalog.validation_errors().is_empty(), "It may never raise a boss")
	raiser.spellbook["raise_dead"]["type"] = "skeleorc"
	_check(rules.catalog.validation_errors().is_empty(), "The restored catalog validates")


func _test_soulfire() -> void:
	var combat := _board()
	for cell: Vector2i in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 3), Vector2i(15, 1)]:
		combat.build(0, cell, &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var damage: int = combat.towers[0][0]["damage"]
	var dread := _spawn(combat, ID, 6.0)
	_check(_until(combat, dread, "soulfire"), "Soulfire winds up")
	var aim := Vector2i(dread["spell_aim"])
	_check(aim in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 3)], "It aims at the densest group of towers: %s" % aim)
	combat.advance(1.7)
	var withered: int = 0
	for tower: Dictionary in combat.towers[0]:
		if MatchCombat.cell_in_range(aim, tower["cell"], 2.2):
			withered += 1
			_check(float(tower["wither_remaining"]) > 7.0 and int(tower["damage"]) == ceili(damage * 0.5 - 0.000000001), "Withered towers deal half damage: %d" % tower["damage"])
		else:
			_check(float(tower["wither_remaining"]) == 0.0 and int(tower["damage"]) == damage, "Distant towers are untouched")
	_check(withered >= 2, "The breath catches the cluster")
	dread["next_spell"] = 1000.0
	combat.advance(8.5)
	for tower: Dictionary in combat.towers[0]:
		_check(float(tower["wither_remaining"]) == 0.0 and int(tower["damage"]) == damage, "Wither fades back to full damage")


func _test_raise_dead() -> void:
	var combat := _board()
	combat.build(0, Vector2i(10, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var arrow: Dictionary = combat.towers[0][0]
	var dread := _spawn(combat, ID, 6.0)
	dread["spell_index"] = 1
	combat.advance(3.5)
	_check(dread["spell"] == "soulfire", "With no fallen orcs nearby it breathes instead of raising")
	dread["spell"] = ""
	dread["cast_remaining"] = 0.0
	dread["animation"] = "walk"
	var near: Array[int] = []
	for index: int in range(8):
		var grunt := _spawn(combat, &"grunt", 4.0 + index * 0.3, 1)
		near.append(int(grunt["id"]))
	var far := _spawn(combat, &"grunt", 18.0, 1)
	for id: int in near + [int(far["id"])]:
		_check(combat._hit(0, arrow, combat._enemy_index(0, id), 10), "An orc falls")
	dread["spell_index"] = 1
	dread["next_spell"] = float(dread["age"])
	_check(_until(combat, dread, "raise_dead", 3.0), "Raise the Fallen begins")
	combat.advance(1.9)
	var risen: Array = combat.enemies[0].filter(func(enemy: Dictionary) -> bool: return enemy["type_id"] == "skeleorc")
	_check(risen.size() == 6, "Six of the fallen rise again: %d" % risen.size())
	_check(risen.all(func(enemy: Dictionary) -> bool: return int(enemy["summoner_id"]) == int(dread["id"]) and float(enemy["progress"]) >= 4.0 and float(enemy["progress"]) <= 6.2), "They rise where they fell, bound to Dreadmaw")
	for enemy: Dictionary in risen:
		combat._hit(0, arrow, combat._enemy_index(0, enemy["id"]), 100000)
	combat.advance(0.01)
	_check(combat._fallen[0].size() == 3, "Only the unraised fallen remain and the risen never rise twice: %d" % combat._fallen[0].size())


func _test_enrage_and_death() -> void:
	var rules := _rules()
	rules.enemy_speed = 1.0
	var combat := _board(rules)
	combat.build(0, Vector2i(10, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var arrow: Dictionary = combat.towers[0][0]
	var dread := _spawn(combat, ID, 6.0)
	var calm: float = dread["base_speed"]
	dread["next_spell"] = 1000.0
	# Bone takes 60% of Physical damage: 100000 lands as 60000.
	combat._hit(0, arrow, combat.enemies[0].find(dread), 100000)
	_check(int(dread["hp"]) == 40000 and is_equal_approx(float(dread["base_speed"]), calm * 1.7), "Below half HP it moves 70%% faster")
	combat._hit(0, arrow, combat.enemies[0].find(dread), 100000)
	var skeletons: int = combat.enemies[0].filter(func(enemy: Dictionary) -> bool: return enemy["type_id"] == "skeleorc").size()
	_check(skeletons == 8, "Its death spills eight Skeltorcs: %d" % skeletons)


func _test_debut() -> void:
	var rules := _rules()
	rules.sandbox_mode = false
	var debut := MatchCombat.new(rules)
	_check(debut._generate_wave_groups(200).any(func(group: Dictionary) -> bool: return group["type_id"] == String(ID)), "Round 200 guarantees Dreadmaw")
	_check(not MatchCombat.new(rules)._generate_wave_groups(199).any(func(group: Dictionary) -> bool: return group["type_id"] == String(ID)), "It never appears before round 200")
