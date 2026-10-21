extends SceneTree
## Grand Mage Orcafus: spellbook validation, glide/cast rhythm, Nullify immunity
## and Magic silence, Fireball area stuns, Portal, Haste, Barrier, silent regen,
## the death bolt, boss loot of Rare or better, and his round-140 debut.

const ID := &"grand_mage_orcafus"
const RUNE_CELL := Vector2i(10, 1)
const ARROW_CELL := Vector2i(10, 3)

var failures: int = 0


func _init() -> void:
	_test_definition()
	_test_rotation_and_nullify()
	_test_fireball()
	_test_portal()
	_test_haste()
	_test_barrier_and_regen()
	_test_death_bolt()
	_test_spell_edges()
	_test_rewards()
	_test_debut()
	if failures == 0:
		print("PASS: Grand Mage spellbook validation, glide/cast rhythm, Nullify immunity and Magic silence, Fireball stuns, Portal, Haste, Barrier, silent regen, death bolt, Rare+ boss loot and round-140 debut")
	quit(1 if failures else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _rules(speed: float = 0.0) -> CombatRules:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	rules.sandbox_mode = true
	rules.roll_rules = null
	rules.enemy_speed = speed
	rules.speed_growth_fraction = 0.0
	return rules


func _definition() -> EnemyDefinition:
	for definition: EnemyDefinition in _rules().catalog.enemies:
		if definition.id == ID:
			return definition
	return null


func _route() -> Array:
	var route: Array = []
	for x: int in range(20):
		route.append(Vector2i(19 - x, 2))
	return route


func _routing() -> Array[Dictionary]:
	var route: Array = _route()
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _board(rules: CombatRules = null) -> MatchCombat:
	var combat := MatchCombat.new(rules if rules != null else _rules())
	_check(combat.sandbox_start(_routing(), 140, [] as Array[String]), "The sandbox round starts")
	return combat


func _spawn(combat: MatchCombat, type_id: StringName, progress: float, hp: int = 100000) -> Dictionary:
	_check(combat.sandbox_spawn(0, type_id, 1), "%s spawns" % type_id)
	var enemy: Dictionary = combat.enemies[0].back()
	enemy["progress"] = progress
	enemy["pos"] = combat._position(enemy["route"], progress)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	return enemy


func _until(combat: MatchCombat, mage: Dictionary, spell: String, limit: float = 60.0) -> bool:
	var waited: float = 0.0
	while waited < limit:
		if mage["spell"] == spell:
			return true
		combat.advance(0.05)
		waited += 0.05
	return false


# Steer the rotation so the next cast is the wanted spell.
func _next_cast(mage: Dictionary, spell: String) -> void:
	mage["spell_index"] = _definition().spellbook["order"].find(spell)


func _test_definition() -> void:
	var definition: EnemyDefinition = _definition()
	_check(definition != null and definition.boss and definition.first_wave == 140, "Orcafus is a round-140 boss")
	_check(definition.immune_elements.has("fire") and definition.immune_elements.has("ice") and definition.immune_elements.has("magic") and not definition.immune_elements.has("physical") and not definition.immune_elements.has("lightning"), "Physical and Lightning are the only elements that hurt him")
	_check(Spellbook.validation_error(definition.spellbook).is_empty(), "The shipped spellbook validates")
	for animation: StringName in [&"walk", &"nullify", &"nullify_strike", &"fireball", &"portal", &"haste", &"barrier", &"death"]:
		_check(definition.animation_frames.has_animation(animation), "Orcafus has a %s animation" % animation)
	_check(definition.corpse_lifetime > EnemyVisuals.animation_duration(definition, &"death"), "His corpse outlives the slow dust animation")
	var book: Dictionary = definition.spellbook.duplicate(true)
	book["order"] = ["nullify", "meteor"]
	_check(not Spellbook.validation_error(book).is_empty(), "Unknown spells are rejected")
	book = definition.spellbook.duplicate(true)
	book["haste"]["multiplier"] = 0.9
	_check(not Spellbook.validation_error(book).is_empty(), "Haste must speed orcs up")
	book = definition.spellbook.duplicate(true)
	book["portal"]["count"] = 2.5
	_check(not Spellbook.validation_error(book).is_empty(), "Portal counts are whole orcs")
	_check(Spellbook.summary(definition.spellbook).size() == 7, "The Orcieary lists the glide rhythm, five spells and the death bolt")


func _test_rotation_and_nullify() -> void:
	var combat := _board(_rules(2.0))
	combat.build(0, RUNE_CELL, &"rune_obelisk", MatchCombat.TargetMode.FURTHEST)
	combat.build(0, ARROW_CELL, &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var rune: Dictionary = combat.towers[0][0]
	var arrow: Dictionary = combat.towers[0][1]
	var mage := _spawn(combat, ID, 3.0)
	combat.advance(1.0)
	_check(mage["spell"] == "" and float(mage["progress"]) > 3.0, "He glides between casts")
	_check(_until(combat, mage, "nullify", 2.0), "Nullify opens the rotation after the glide")
	var parked: float = mage["progress"]
	combat.advance(1.0)
	_check(is_equal_approx(float(mage["progress"]), parked) and float(mage["speed"]) == 0.0, "He stands still while casting")
	var index: int = combat.enemies[0].find(mage)
	_check(bool(mage["spell_shielded"]) and not combat._hit(0, arrow, index, 500) and int(mage["hp"]) == 100000, "The Nullify channel makes him immune to all damage")
	combat.advance(1.6)
	_check(mage["spell_phase"] == "strike" and not bool(mage["spell_shielded"]), "The channel ends in the staff strike")
	_check(combat.snapshot()["magic_nullified"][0] > 7.0 and combat.snapshot()["magic_nullified"][1] == 0.0, "The strike silences Magic on his board only")
	var target := _spawn(combat, &"grunt", 9.5)
	target["base_speed"] = 0.0
	target["speed"] = 0.0
	combat.advance(1.0)
	# Hold further casts so the fade is measured on this Nullify alone.
	mage["next_spell"] = 1000.0
	_check(bool(rune["nullified"]) and not bool(arrow["nullified"]) and combat.snapshot()["towers"][0][0]["nullified"], "Magic towers fall silent; Physical towers keep firing")
	var hp: int = target["hp"]
	combat.advance(2.0)
	_check(int(rune["damage_dealt"]) == 0 and int(target["hp"]) <= hp, "A silenced Rune deals no damage while Physical keeps working")
	combat.advance(8.0)
	_check(not bool(rune["nullified"]) and combat.snapshot()["magic_nullified"][0] == 0.0, "Magic returns once the Nullify fades")


func _test_fireball() -> void:
	var combat := _board()
	combat.build(0, Vector2i(5, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	combat.build(0, Vector2i(6, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	combat.build(0, Vector2i(15, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var mage := _spawn(combat, ID, 3.0)
	_next_cast(mage, "fireball")
	_check(_until(combat, mage, "fireball"), "Fireball winds up")
	var aim := Vector2i(mage["spell_aim"])
	_check(combat.towers[0].any(func(tower: Dictionary) -> bool: return tower["cell"] == aim), "The fireball is aimed at a real tower")
	combat.advance(1.5)
	for tower: Dictionary in combat.towers[0]:
		var inside: bool = MatchCombat.cell_in_range(aim, tower["cell"], 1.6)
		_check((float(tower["stunned_remaining"]) > 3.0) == inside, "Towers within 1.6 cells of the blast are stunned, others are not: %s" % tower["cell"])
	_check(mage["spell_effect"]["kind"] == "fireball" and Vector2(mage["spell_effect"]["to"]) == Vector2(aim), "The blast reaches the board as an accepted effect")


func _test_portal() -> void:
	var combat := _board()
	var mage := _spawn(combat, ID, 12.0)
	var rear: Array[Dictionary] = []
	for index: int in range(12):
		rear.append(_spawn(combat, &"grunt", 0.2 * index))
	var boss := _spawn(combat, &"troll", 0.1)
	var ahead := _spawn(combat, &"grunt", 15.0)
	_next_cast(mage, "portal")
	_check(_until(combat, mage, "portal"), "Portal opens")
	_check(Vector2(mage["spell_aim"]).is_equal_approx(combat._position(mage["route"], 12.8)), "The exit opens just in front of him")
	combat.advance(2.5)
	var moved: int = 0
	for enemy: Dictionary in rear:
		moved += int(is_equal_approx(float(enemy["progress"]), 12.8))
	_check(moved == 10, "The ten rearmost orcs step out of the portal: %d" % moved)
	_check(float(rear[10]["progress"]) < 3.0 and float(rear[11]["progress"]) < 3.0, "Only the rearmost ten are taken")
	_check(float(boss["progress"]) < 1.0 and is_equal_approx(float(ahead["progress"]), 15.0), "Bosses and orcs already ahead are never pulled")
	_check(mage["spell_effect"]["kind"] == "portal" and mage["spell_effect"]["from"].size() == 10, "Every jump is published for the board")


func _test_haste() -> void:
	var combat := _board(_rules(1.0))
	var mage := _spawn(combat, ID, 6.0)
	var near := _spawn(combat, &"grunt", 8.0)
	var far := _spawn(combat, &"grunt", 16.0)
	for enemy: Dictionary in [mage, near, far]:
		enemy["base_speed"] = 0.2
		enemy["speed"] = 0.2
	_next_cast(mage, "haste")
	_check(_until(combat, mage, "haste"), "Haste is cast")
	combat.advance(1.9)
	_check(is_equal_approx(float(near["base_speed"]), 0.28) and is_equal_approx(float(far["base_speed"]), 0.2), "Orcs within five cells move 40%% faster; distant ones do not")
	combat.advance(3.0)
	_check(is_equal_approx(float(near["base_speed"]), 0.28) and float(near["haste_remaining"]) > 0.0, "Haste lasts")
	combat.advance(3.2)
	_check(is_equal_approx(float(near["base_speed"]), 0.2) and float(near["haste_multiplier"]) == 1.0, "Haste fades back to the exact base speed")


func _test_barrier_and_regen() -> void:
	var combat := _board()
	var mage := _spawn(combat, ID, 6.0)
	_next_cast(mage, "barrier")
	combat.advance(1.5)
	_check(mage["spell"] != "barrier", "A healthy mage skips the Barrier")
	var scratched := _board()
	var grazed := _spawn(scratched, ID, 6.0)
	grazed["hp"] = 60000
	_next_cast(grazed, "barrier")
	scratched.advance(1.5)
	_check(grazed["spell"] != "barrier", "Above half HP the Barrier stays down")
	var healthy := _board()
	var hurt := _spawn(healthy, ID, 6.0)
	hurt["hp"] = 40000
	_next_cast(hurt, "barrier")
	_check(_until(healthy, hurt, "barrier"), "A wounded mage raises the Barrier")
	var before: int = hurt["hp"]
	healthy.advance(1.9)
	_check(int(hurt["shield_hits"]) == 10 and int(hurt["shield_max_hits"]) == 10, "The Barrier is a ten-hit shield")
	_check(int(hurt["hp"]) >= before + 20000, "The Barrier heals 20%% of maximum HP: %d -> %d" % [before, hurt["hp"]])
	for repeat: int in range(2):
		hurt["hp"] = 40000
		hurt["spell"] = ""
		hurt["cast_remaining"] = 0.0
		hurt["next_spell"] = float(hurt["age"])
		_next_cast(hurt, "barrier")
		healthy.advance(0.05)
		if repeat == 0:
			_check(hurt["spell"] == "barrier", "A second Barrier is allowed")
			healthy.advance(1.9)
	_check(hurt["spell"] != "barrier" and int(hurt["barriers"]) == 2, "He raises the Barrier at most twice per life")
	var regen := _board()
	var resting := _spawn(regen, ID, 6.0)
	resting["hp"] = 50000
	resting["next_spell"] = 1000.0
	regen.advance(2.05)
	_check(int(resting["hp"]) == 50250 and resting["animation"] == "walk", "He silently regenerates 0.25%% every two seconds")


func _test_death_bolt() -> void:
	var rules := _rules()
	rules.sandbox_mode = false
	rules.starting_coins = 100000
	var combat := MatchCombat.new(rules)
	combat.build(0, Vector2i(5, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	combat.build(0, Vector2i(7, 1), &"rune_obelisk", MatchCombat.TargetMode.FURTHEST)
	var valuable: Dictionary = combat.towers[0][1]
	_check(combat.upgrade_tower(0, valuable["id"], "damage"), "One tower holds more investment")
	var route: Array = _route()
	var next: Dictionary = {}
	for index: int in range(route.size()):
		next[route[index]] = [route[index + 1]] if index + 1 < route.size() else []
	_check(combat.start_wave([{"route": route, "next": next}, {"route": route, "next": next}]), "A real round starts")
	combat._spawn_enemy(0, String(ID), 6.0, combat._elapsed)
	var mage: Dictionary = combat.enemies[0].back()
	var arrow: Dictionary = combat.towers[0][0]
	_check(combat._hit(0, arrow, combat.enemies[0].find(mage), int(mage["hp"]) + 10), "The killing blow lands")
	_check(float(valuable["stunned_remaining"]) == 10.0 and float(arrow["stunned_remaining"]) == 0.0, "His dying bolt stuns the most valuable tower for ten seconds")
	var death: Dictionary = combat.snapshot()["deaths"][0].back()
	_check(death["type_id"] == String(ID) and Vector2(death["bolt_to"]) == Vector2(valuable["cell"]), "The bolt's target reaches the board with his corpse")
	_check(combat.snapshot()["boss_rewards"][0].size() == 1, "He drops boss loot")


# Silence and wither end with their wave, a silenced tower's frozen cooldown is
# not a simulation event, and a Portal near the base never pulls orcs backwards.
func _test_spell_edges() -> void:
	var combat := _board()
	combat.build(0, RUNE_CELL, &"rune_obelisk", MatchCombat.TargetMode.FURTHEST)
	combat.build(0, ARROW_CELL, &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	var rune: Dictionary = combat.towers[0][0]
	var arrow: Dictionary = combat.towers[0][1]
	var damage: int = arrow["damage"]
	var mage := _spawn(combat, ID, 3.0)
	mage["next_spell"] = 1000.0
	combat._boss_stream = true
	rune["cooldown"] = 0.000001
	combat._magic_nullified_until[0] = combat._elapsed + 8.0
	_check(combat._next_event_step(0.5) > 0.01, "A silenced tower's frozen cooldown never shreds the step: %f" % combat._next_event_step(0.5))
	arrow["withered_until"] = combat._elapsed + 100.0
	arrow["wither"] = 0.5
	combat._refresh_board(0)
	_check(int(arrow["damage"]) < damage, "The fixture withers the arrow")
	_check(combat.sandbox_start(_routing(), 140, [] as Array[String]), "The sandbox restarts")
	_check(float(arrow["withered_until"]) == 0.0 and int(arrow["damage"]) == damage and not bool(rune["nullified"]) and combat.snapshot()["magic_nullified"][0] == 0.0, "A restart clears wither and silence")
	var grunt := _spawn(combat, &"grunt", 3.0, 1)
	arrow["withered_until"] = combat._elapsed + 100.0
	arrow["wither"] = 0.5
	combat._refresh_board(0)
	combat._magic_nullified_until[0] = combat._elapsed + 100.0
	combat.advance(0.1)
	combat._hit(0, arrow, combat.enemies[0].find(grunt), 100)
	for step: int in range(20):
		if combat.phase == MatchCombat.Phase.PLANNING:
			break
		combat.advance(0.1)
	var state: Dictionary = combat.snapshot()
	_check(combat.phase == MatchCombat.Phase.PLANNING and int(arrow["damage"]) == damage and float(arrow["wither_remaining"]) == 0.0 and not bool(rune["nullified"]) and state["magic_nullified"][0] == 0.0, "A cleared wave leaves no wither or silence for Planning")
	combat = _board()
	var last: float = float(_route().size() - 1)
	mage = _spawn(combat, ID, last - 0.1)
	var near := _spawn(combat, &"grunt", last - 0.4)
	var rear := _spawn(combat, &"grunt", 1.0)
	_next_cast(mage, "portal")
	_check(_until(combat, mage, "portal"), "Portal opens near the base")
	combat.advance(2.5)
	_check(is_equal_approx(float(near["progress"]), last - 0.4) and is_equal_approx(float(rear["progress"]), last - 0.5), "Near the base the portal only pulls orcs forward: %.2f / %.2f" % [near["progress"], rear["progress"]])


func _test_rewards() -> void:
	var rules: BossRewardRules = load("res://resources/combat/boss_rewards.tres")
	_check(rules.validation_errors().is_empty() and rules.minimum_rarity == "rare", "Boss loot is configured with a Rare floor")
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var seen: Dictionary = {}
	for index: int in range(400):
		var ledger := BossRewardLedger.new(rules, random)
		var award: Dictionary = ledger.claim(0, "troll", {"boss": true, "title": "Troll"}, 60, 1.0)
		seen[award["rarity"]] = true
		_check(award["tiers"].size() == 4, "The reel only shows Rare and better")
	_check(seen.keys().all(func(id: String) -> bool: return TowerRollRules.RARITIES.find(id) >= TowerRollRules.RARITIES.find("rare")), "Bosses never drop below Rare: %s" % str(seen.keys()))
	_check(seen.has("rare") and seen.has("epic"), "Rare and Epic both occur")


func _test_debut() -> void:
	var rules := _rules()
	rules.sandbox_mode = false
	var debut := MatchCombat.new(rules)
	var groups: Array[Dictionary] = debut._generate_wave_groups(140)
	_check(groups.any(func(group: Dictionary) -> bool: return group["type_id"] == String(ID)), "Round 140 guarantees his debut")
	var before := MatchCombat.new(rules)
	_check(not before._generate_wave_groups(139).any(func(group: Dictionary) -> bool: return group["type_id"] == String(ID)), "He never appears before round 140")
	var later: int = 0
	for seed: int in range(200):
		var combat := MatchCombat.new(rules)
		combat._wave_random.seed = seed
		later += int(combat._generate_wave_groups(220).any(func(group: Dictionary) -> bool: return group["type_id"] == String(ID)))
	_check(later > 70 and later < 130, "By round 220 he joins about half of all waves: %d / 200" % later)
