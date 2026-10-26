extends SceneTree

class ManualPlanning extends MatchPlanning:
	func _physics_process(_delta: float) -> void:
		pass


class DraftPlanning extends ManualPlanning:
	func local_slot() -> int:
		return 0

	func _can_accept(sender: int) -> bool:
		return sender in [1, 2] and (selecting_loadout or active)

	func _reject(_sender: int, _message: String) -> void:
		pass

	func _request_loadout_command(command: String, ids: Array, owned: Array, commander_id: String = "") -> bool:
		return _apply_loadout_command(1, command, ids, owned, commander_id)

	func begin(seed_value: int) -> void:
		_reset_match()
		_draft_rng.seed = seed_value
		selecting_loadout = true
		_begin_commander_draft()
		_publish_snapshot()


var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	_generation()
	_capture_clear_growth()
	_landmarks()
	_rally()
	await _draft()
	_stasis()
	await _planning()
	if failures == 0:
		print("PASS: secret-number draft privacy/order/ties/replay, distinct solo heroes, legal terrain, paid clearing, physical/rate landmarks, Rally/Stasis boundaries and detached snapshots")
	quit(1 if failures else 0)


func _rules(speed: float = 0.0) -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	rules.roll_rules = null
	rules.starting_coins = 100000
	rules.base_health = 10000
	rules.enemy_health = 1000000
	rules.health_growth = 0
	rules.enemy_speed = speed
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	var grunt: EnemyDefinition = preload("res://resources/combat/enemies/grunt.tres").duplicate(true)
	rules.catalog.enemies = [grunt]
	for tower: TowerDefinition in rules.catalog.towers:
		if tower.reward.id == &"arrow_tower":
			tower.damage = 100
			tower.interval = 1.0
	return rules


func _state(id: String = "knight", landmark: Vector2i = Vector2i(5, 3)) -> Dictionary:
	return {"id": id, "landmark": landmark, "obstacles": [Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)] as Array[Vector2i], "ability_remaining": 0.0, "cooldown_remaining": 0.0, "ability_target": -1}


func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(201, 9), 200, Vector2i(0, 4), Vector2i(200, 4))
	for x: int in range(1, 200):
		layout.place(Vector2i(x, 4))
	return [layout.capture_routing(), layout.capture_routing()]


func _core(ids: Array[String] = ["knight", "priestess"], speed: float = 0.0) -> MatchCombat:
	var random := RandomNumberGenerator.new()
	random.seed = 51739
	var core := MatchCombat.new(_rules(speed), null, random)
	core.configure_commanders([_state(ids[0]), _state(ids[1])])
	return core


func _start(core: MatchCombat) -> void:
	_check(core.start_wave(_routes()), "Commander fixture starts through actual wave admission")
	core.advance(0.001)
	for slot: int in range(2):
		core._spawn_enemy(slot, "grunt", 5.0, core._elapsed)


func _generation() -> void:
	for id: StringName in [&"knight", &"priestess"]:
		var arrangements: Dictionary = {}
		for seed_value: int in range(64):
			var layout := PathLayout.new()
			var random := RandomNumberGenerator.new()
			random.seed = seed_value
			var generated: Dictionary = CommanderRules.generate(id, layout, random)
			random.seed = seed_value
			_check(generated == CommanderRules.generate(id, layout, random), "Identical seed and commander replay identical generated terrain")
			_check(generated.get("id", "") == String(id) and generated.get("obstacles", []).size() == 3, "Every supported generated board has its chosen landmark and three obstacles")
			if generated.is_empty():
				continue
			var blocked: Array = generated["obstacles"].duplicate()
			blocked.append(generated["landmark"])
			var unique: Dictionary = {}
			for cell: Vector2i in blocked:
				_check(layout.contains(cell) and not layout.is_endpoint(cell) and cell.y != layout.entrance.y and not unique.has(cell), "Generated blocked cells are distinct, in bounds, off endpoints and off the guaranteed straight route")
				unique[cell] = true
			for x: int in range(layout.entrance.x + 1, layout.base.x):
				layout.place(Vector2i(x, layout.entrance.y))
			_check(layout.is_ready(), "The reserved generated corridor admits an actual legal entrance-to-base path")
			var buildable: int = 0
			for y: int in range(layout.dimensions.y):
				for x: int in range(layout.dimensions.x):
					var cell := Vector2i(x, y)
					if not layout.has_path(cell) and not unique.has(cell):
						buildable += 1
			_check(buildable >= 8, "Every seed retains at least eight genuinely buildable off-route cells")
			arrangements[str(blocked)] = true
		_check(arrangements.size() > 1, "Independent seeds produce actual terrain variation rather than a fixed template")


func _capture_clear_growth() -> void:
	var core: MatchCombat = _core()
	var source: Array = [_state(), _state("priestess")]
	core.configure_commanders(source)
	source[0]["obstacles"].clear()
	source[1]["landmark"] = Vector2i.ZERO
	_check(core.commanders[0]["obstacles"].size() == 3 and core.commanders[1]["landmark"] == Vector2i(5, 3), "Admission deep-captures mutable terrain from its caller")
	for cell: Vector2i in [Vector2i(5, 3), Vector2i(7, 1)]:
		var before: Dictionary = core.snapshot()
		_check(not core.build(0, cell, &"arrow_tower", 0) and core.snapshot() == before, "Landmarks and obstacles reject tower placement atomically")
	var initial: Dictionary = core.snapshot()
	for cell: Vector2i in [Vector2i(5, 3), Vector2i(-1, 0), Vector2i(2, 2)]:
		_check(not core.clear_obstacle(0, cell) and core.snapshot() == initial, "Landmark, outside and ordinary ground cannot spend clearing Coins")
	core.coins[0] = 24
	initial = core.snapshot()
	_check(not core.clear_obstacle(0, Vector2i(7, 1)) and core.snapshot() == initial, "Insufficient Coins preserve the obstacle and all other accepted state")
	core.coins[0] = 25
	_check(core.clear_obstacle(0, Vector2i(7, 1)) and core.coins[0] == 0 and not core.commanders[0]["obstacles"].has(Vector2i(7, 1)) and core.commanders[1]["obstacles"].size() == 3, "Clearing spends exactly 25 on the owning board and removes exactly one obstacle")
	initial = core.snapshot()
	_check(not core.clear_obstacle(0, Vector2i(7, 1)) and core.snapshot() == initial, "Repeated clearing cannot spend again")
	var detached: Dictionary = core.snapshot(false)
	detached["commanders"][0]["obstacles"].clear()
	detached["commanders"][1]["cooldown_remaining"] = 1000.0
	_check(core.commanders[0]["obstacles"].size() == 2 and core.commanders[1]["cooldown_remaining"] == 0.0, "Ordinary combat frames expose deeply detached commander state")
	core.grow_for_main_round()
	_check(core.commanders[0]["landmark"] == Vector2i(5, 4) and core.commanders[0]["obstacles"] == [Vector2i(8, 2), Vector2i(9, 2)], "Map growth shifts permanent terrain exactly one logical row and never restores cleared obstacles")
	_start(core)
	initial = core.snapshot()
	_check(not core.clear_obstacle(0, Vector2i(8, 2)) and core.snapshot() == initial, "Combat clearing is rejected without charging or altering terrain")
	var sandbox_rules: CombatRules = _rules()
	sandbox_rules.sandbox_mode = true
	var sandbox := MatchCombat.new(sandbox_rules)
	_check(sandbox.commanders == [{}, {}] and sandbox.build(0, Vector2i(5, 3), &"arrow_tower", 0), "Unconfigured Sandbox retains free ordinary ground and no commander rules")


func _landmarks() -> void:
	var core: MatchCombat = _core()
	for slot: int in range(2):
		for cell: Vector2i in [Vector2i(5, 2), Vector2i(7, 2), Vector2i(8, 3)]:
			_check(core.build(slot, cell, &"arrow_tower", 0), "Build near, edge-inside and outside landmark consumers")
		_check(core.build(slot, Vector2i(4, 3), &"rune_obelisk", 0), "Build actual magic consumer beside landmark")
	var knight: Array = core.towers[0]
	var priestess: Array = core.towers[1]
	_check(knight[0]["damage"] == 115 and knight[1]["damage"] == 115 and knight[2]["damage"] == 100, "Bastion gives physical towers exactly 15-percent damage inside the 2.5-cell circle only")
	_check(knight[3]["damage"] == core._tower_types["rune_obelisk"]["damage"] and is_equal_approx(knight[0]["interval"], 1.0), "Bastion does not increase magic damage or attack rate")
	_check(is_equal_approx(priestess[0]["interval"], 1.0 / 1.15) and is_equal_approx(priestess[1]["interval"], 1.0 / 1.15) and is_equal_approx(priestess[2]["interval"], 1.0), "Sanctuary gives 15-percent attack rate using the same circular radius")
	_check(is_equal_approx(float(priestess[3]["interval"]), float(core._tower_types["rune_obelisk"]["interval"]) / 1.15) and priestess[0]["damage"] == 100, "Sanctuary helps magic attack rate without adding damage")
	_start(core)
	for slot: int in range(2):
		var victim: Dictionary = core.enemies[slot].back()
		var hp: int = victim["hp"]
		core._hit(slot, core.towers[slot][0], core.enemies[slot].size() - 1)
		_check(hp - int(victim["hp"]) == (115 if slot == 0 else 100), "Real accepted contacts consume landmark-adjusted damage on the appropriate board")
	for tick: int in range(158):
		core.advance(0.05)
	_check(int(priestess[0]["shot"]) > int(knight[0]["shot"]), "Sanctuary's accepted rate produces more actual attacks, not merely different displayed stats")
	var baseline := MatchCombat.new(_rules())
	_check(baseline.build(0, Vector2i(4, 3), &"rune_obelisk", 0), "Build the unbuffed conversion control")
	for upgrade: String in ["damage", "speed", "boulders"]:
		_check(core.upgrade_tower(0, knight[3]["id"], upgrade) and baseline.upgrade_tower(0, baseline.towers[0][0]["id"], upgrade), "Purchase real physical Rune conversion on both consumers")
	_check(knight[3]["damage"] == ceili(float(baseline.towers[0][0]["damage"]) * 1.15 - 0.000000001), "Bastion starts helping an existing magic tower only when its purchased branch becomes physical")
	_check(core.upgrade_tower(0, knight[3]["id"], "freeze_runes") and baseline.upgrade_tower(0, baseline.towers[0][0]["id"], "freeze_runes"), "Purchase the actual ice conversion")
	_check(knight[3]["damage"] == baseline.towers[0][0]["damage"], "Changing that same accepted tower from physical to ice removes Bastion's damage bonus")


func _rally_fixture() -> MatchCombat:
	var core: MatchCombat = _core(["knight", "knight"])
	for slot: int in range(2):
		_check(core.build(slot, Vector2i(5, 2), &"arrow_tower", 0), "Build paired physical attack-rate consumers")
	_start(core)
	return core




func _rally() -> void:
	var core: MatchCombat = _rally_fixture()
	var coins: Array[int] = core.coins.duplicate()
	var health: Array[int] = core.base_health.duplicate()
	var initial: Dictionary = core.snapshot()
	_check(not core.activate_commander(0, 1) and core.snapshot() == initial, "Rally cannot target the opposing board")
	_check(core.activate_commander(0, 0) and core.coins == coins and core.base_health == health, "Rally activates for free without directly damaging either base")
	_check(is_equal_approx(core.towers[0][0]["interval"], 1.0 / 1.3) and is_equal_approx(core.towers[1][0]["interval"], 1.0), "Rally immediately boosts only its own board's real attack interval")
	initial = core.snapshot()
	_check(not core.activate_commander(0, 0) and core.snapshot() == initial, "Repeated Rally cannot refresh duration or bypass its cooldown")
	core.advance(7.5)
	_check(float(core.commanders[0]["ability_remaining"]) > 0.0 and int(core.towers[0][0]["shot"]) > int(core.towers[1][0]["shot"]), "Live Rally produces additional actual attacks before expiry")
	core.advance(1.0)
	_check(core.commanders[0]["ability_remaining"] == 0.0 and is_equal_approx(core.towers[0][0]["interval"], 1.0) and is_equal_approx(core.commanders[0]["cooldown_remaining"], 36.5), "Crossing eight seconds restores baseline rate and ages the 45-second cooldown by simulation time")
	var fine: MatchCombat = _rally_fixture()
	fine.activate_commander(0, 0)
	for tick: int in range(170):
		fine.advance(0.05)
	_check(fine.towers[0][0]["shot"] == core.towers[0][0]["shot"] and fine.enemies[0].back()["hp"] == core.enemies[0].back()["hp"], "Coarse and fine simulation partitions produce the same real Rally attacks across expiry")
	core.advance(36.5)
	_check(core.commanders[0]["cooldown_remaining"] == 0.0 and core.activate_commander(0, 0), "Exactly 45 combat seconds allow another activation")
	core.phase = MatchCombat.Phase.PLANNING
	initial = core.snapshot()
	core.advance(100.0)
	_check(core.snapshot() == initial and not core.activate_commander(1, 1), "Planning cannot age cooldowns or activate commander abilities")
	core.phase = MatchCombat.Phase.FINISHED
	_check(not core.activate_commander(1, 1), "Finished matches cannot activate a ready commander")


func _stasis() -> void:
	var core: MatchCombat = _core(["priestess", "priestess"], 1.0)
	_start(core)
	var victim: Dictionary = core.enemies[0].back()
	var other: Dictionary = core.enemies[1].back()
	var start: float = victim["progress"]
	var other_start: float = other["progress"]
	_check(core.activate_commander(0, 0), "Stasis can target the owner's board")
	core.advance(2.0)
	_check(is_equal_approx(float(victim["progress"]) - start, 1.2) and is_equal_approx(float(other["progress"]) - other_start, 2.0), "Actual Stasis movement is 40-percent slower on only the selected board")
	_check(core.activate_commander(1, 0), "The other Priestess can target the same board independently")
	core.advance(4.5)
	_check(is_equal_approx(float(victim["progress"]) - start, 3.9) and core.commanders[0]["ability_remaining"] == 0.0 and is_equal_approx(core.commanders[1]["ability_remaining"], 1.5), "Overlapping Stasis never multiplies and the later source survives the first expiry")
	core.advance(2.0)
	_check(is_equal_approx(float(victim["progress"]) - start, 5.3) and is_equal_approx(victim["speed"], victim["base_speed"]), "A coarse tick integrates the final slow span and ordinary post-expiry movement separately")
	var fine: MatchCombat = _core(["priestess", "priestess"], 1.0)
	_start(fine)
	fine.activate_commander(0, 0)
	for tick: int in range(40):
		fine.advance(0.05)
	fine.activate_commander(1, 0)
	for tick: int in range(130):
		fine.advance(0.05)
	_check(is_equal_approx(fine.enemies[0].back()["progress"], victim["progress"]), "Staggered Stasis expiry preserves exact movement under fine and coarse steps")
	var frozen: MatchCombat = _core(["priestess", "knight"], 1.0)
	_start(frozen)
	var iced: Dictionary = frozen.enemies[0].back()
	iced["slowed"] = true
	iced["slow_remaining"] = 8.0
	iced["speed"] = float(iced["base_speed"]) * TowerDefinition.FREEZE_SPEED_MULTIPLIER
	start = iced["progress"]
	frozen.activate_commander(0, 0)
	frozen.advance(7.0)
	_check(is_equal_approx(float(iced["progress"]) - start, 6.0 * 0.6 + TowerDefinition.FREEZE_SPEED_MULTIPLIER), "Stronger Stasis takes precedence without multiplying Freeze, then surviving Freeze resumes after Stasis expires")
	frozen.advance(2.0)
	_check(is_equal_approx(float(iced["progress"]) - start, 6.0 * 0.6 + 2.0 * TowerDefinition.FREEZE_SPEED_MULTIPLIER + 1.0) and is_equal_approx(iced["speed"], iced["base_speed"]), "A second coarse tick integrates Freeze expiry and finally restores ordinary movement")


func _draw(planning: MatchPlanning) -> void:
	for x: int in range(planning.layouts[0].entrance.x + 1, planning.layouts[0].base.x):
		planning.request_edit(0, Vector2i(x, planning.layouts[0].entrance.y), true)


func _draft() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := DraftPlanning.new()
	planning.session = session
	planning.combat_rules = _rules()
	root.add_child(planning)
	for seed_value: int in range(32):
		planning.begin(seed_value)
		var expected := RandomNumberGenerator.new()
		expected.seed = seed_value
		var target: int = expected.randi_range(0, 100)
		var hidden: Dictionary = planning._snapshot(1)["commander_draft"]
		_check(hidden["target"] == -1 and hidden["guesses"] == [-1, -1] and hidden["picker"] == -1, "Admission never exposes the secret target or either unlocked guess")
		_check(not planning.select_loadout([&"arrow_tower"]) and not planning.select_commander(&"knight"), "Tower selection and premature hero picks cannot bypass guessing")
		var rng_state: int = planning._draft_rng.state
		for invalid: Array in [[-1], [101], [50.5], ["50"], [], [50, 50]]:
			_check(not planning._apply_loadout_command(2, "guess", invalid, []) and planning._draft_rng.state == rng_state and planning._snapshot(1)["commander_draft"] == hidden, "Malformed, noninteger and out-of-range guesses neither lock nor consume host randomness")
		_check(planning.submit_commander_guess(0), "Zero is a valid irreversible integer guess")
		var locked: Dictionary = planning._snapshot(1)["commander_draft"]
		_check(locked["guess_locked"] == [true, false] and locked["target"] == -1 and locked["guesses"] == [-1, -1], "The first lock reveals only lock status, not even the submitted value")
		_check(not planning.submit_commander_guess(100) and planning._snapshot(1)["commander_draft"] == locked, "A locked guess cannot be revised while waiting for the opponent")
		_check(planning._apply_loadout_command(2, "guess", [100], []), "One hundred is valid and completes both commitments")
		var draft: Dictionary = planning.commander_draft
		var first: int = expected.randi_range(0, 1) if target == 50 else (0 if target < 50 else 1)
		_check(draft["target"] == target and draft["guesses"] == [0, 100] and draft["first_picker"] == first and draft["picker"] == first, "Both locked values reveal the real host target and the strictly closer player picks first")
		_check(not planning.select_loadout([&"arrow_tower"]), "Revealing the number still cannot expose tower selection before both picks")
		_check(not planning._apply_loadout_command(2 if first == 0 else 1, "commander", [], [], "knight"), "The player who lost priority cannot pick out of turn")
		_check(planning._apply_loadout_command(1 if first == 0 else 2, "commander", [], [], "knight"), "The actual current picker freezes the first hero immediately")
		var after_pick: Dictionary = planning._snapshot()["commander_draft"]
		_check(not planning._apply_loadout_command(1 if first == 0 else 2, "commander", [], [], "priestess") and planning._snapshot()["commander_draft"] == after_pick, "The first hero cannot be changed even before tower commitment")
		_check(not planning._apply_loadout_command(2 if first == 0 else 1, "commander", [], [], "knight"), "The second picker cannot duplicate the already chosen hero")
		_check(planning._apply_loadout_command(2 if first == 0 else 1, "commander", [], [], "priestess") and planning.commander_draft["phase"] == "loadout" and planning.commander_draft["picker"] == -1, "Only two distinct final hero picks unlock the tower phase")
		var detached: Dictionary = planning._snapshot(1)
		detached["commander_draft"]["guesses"][0] = 101
		detached["commander_draft"]["picks"][0] = "unknown"
		_check(planning.commander_draft["guesses"] == [0, 100] and not planning._snapshot()["commander_draft"]["picks"].has("unknown"), "Draft snapshots cannot mutate accepted guesses or picked heroes")
	for endpoint: int in [0, 100]:
		var found: bool = false
		var candidate := RandomNumberGenerator.new()
		for seed_value: int in range(100000):
			candidate.seed = seed_value
			if candidate.randi_range(0, 100) != endpoint:
				continue
			planning.begin(seed_value)
			planning.submit_commander_guess(0)
			planning._apply_loadout_command(2, "guess", [100], [])
			_check(planning.commander_draft["target"] == endpoint, "The secret random number can genuinely reach either inclusive endpoint")
			found = true
			break
		_check(found, "Find a deterministic inclusive-endpoint draft fixture")
	var winners: Dictionary = {}
	for seed_value: int in range(32):
		planning.begin(seed_value)
		var expected := RandomNumberGenerator.new()
		expected.seed = seed_value
		expected.randi_range(0, 100)
		var winner: int = expected.randi_range(0, 1)
		planning.submit_commander_guess(50)
		planning._apply_loadout_command(2, "guess", [50], [])
		_check(planning.commander_draft["first_picker"] == winner and planning._draft_rng.state == expected.state, "Equal-distance guesses consume exactly one host-owned coin flip after both commitments")
		winners[winner] = true
	_check(winners.size() == 2, "Host tie rolls can award either player, not a fixed role")
	planning.queue_free()
	session.queue_free()
	await process_frame


func _planning() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := ManualPlanning.new()
	planning.session = session
	planning.combat_rules = _rules(0.1)
	root.add_child(planning)
	var seed_value: int = 0
	var target: int = 0
	var expected := RandomNumberGenerator.new()
	while true:
		expected.seed = seed_value
		target = expected.randi_range(0, 100)
		if target != expected.randi_range(0, 100):
			break
		seed_value += 1
	for id: StringName in [&"knight", &"priestess"]:
		planning._draft_rng.seed = seed_value
		planning.start_singleplayer()
		_check(planning.commander_draft["guess_locked"] == [false, true] and planning.commander_draft["target"] == -1 and planning.commander_draft["guesses"] == [-1, -1], "Solo locks one host-generated opponent guess without revealing it or the target")
		_check(planning.submit_commander_guess(target) and planning.commander_draft["picker"] == 0, "A deterministic closer local guess grants the real first pick")
		var draft_rng_state: int = planning._draft_rng.state
		_check(planning.select_commander(id) and planning.chosen_commander_id == id and planning.commander_draft["phase"] == "loadout" and planning._draft_rng.state == draft_rng_state, "The solo opponent takes the sole remaining hero without an extra random draw")
		_check(not planning.select_commander(&"unknown") and not planning.select_commander(&"priestess" if id == &"knight" else &"knight"), "A final hero pick cannot be revised before or after tower selection")
		_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Only the finished hero draft admits a real tower commitment")
		var states: Array = planning.combat["commanders"]
		_check(states[0]["id"] == String(id) and states[1]["id"] != states[0]["id"], "Solo gives the opponent a distinct drafted commander rather than mirroring the hero")
		var landmark: Vector2i = states[0]["landmark"]
		var obstacle: Vector2i = states[0]["obstacles"][0]
		var before: Dictionary = planning.combat.duplicate(true)
		for cell: Vector2i in [landmark, obstacle]:
			planning.request_edit(0, cell, true)
			planning.build_tower(0, cell, &"arrow_tower", 0)
		_check(planning.combat == before and planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Independent accepted terrain blocks invalid mirrored path and tower actions atomically")
		_check(not planning.request_clear_obstacle(landmark), "The public clear action cannot remove a permanent landmark")
		var coins: Array = planning.combat["coins"].duplicate()
		var opponent: Dictionary = states[1].duplicate(true)
		_check(planning.request_clear_obstacle(obstacle), "The public paid clear succeeds before Ready")
		_check(planning.combat["coins"] == [int(coins[0]) - 25, int(coins[1])] and planning.combat["commanders"][1] == opponent, "Solo clearing spends only owned Coins and cannot alter the other drafted hero's board")
		var free := Vector2i(-1, -1)
		for y: int in range(3):
			for x: int in range(1, 13):
				var cell := Vector2i(x, y)
				if not planning._host_combat.terrain_blocks(0, cell) and not planning._host_combat.terrain_blocks(1, cell):
					free = cell
					break
			if free.x >= 0:
				break
		planning.build_tower(0, free, &"arrow_tower", 0)
		_check(planning.combat["towers"][0].size() == 1 and planning.combat["towers"][1].size() == 1, "Tower construction still mirrors once both independent terrains permit the cell")
		var next_obstacle: Vector2i = planning.combat["commanders"][0]["obstacles"][0]
		_draw(planning)
		_check(planning.layouts[0].is_ready() and planning.layouts[1].is_ready(), "Both independently generated solo boards preserve the shared legal path corridor")
		planning.submit_ready(true)
		before = planning.combat.duplicate(true)
		_check(not planning.request_clear_obstacle(next_obstacle) and planning.combat == before, "Combat clear is atomic through the real planning consumer")
		_check(planning.request_commander_ability(0), "The drafted owned commander activates after wave start")
		var commanders: Array = planning.combat["commanders"]
		_check(float(commanders[0]["ability_remaining"]) > 0.0 and commanders[1]["ability_remaining"] == 0.0 and commanders[1]["cooldown_remaining"] == 0.0, "Solo does not activate the other distinct hero or start its cooldown")
		before = planning.combat.duplicate(true)
		_check(not planning.request_commander_ability(0) and planning.combat == before, "Repeat activation cannot refresh the owned cooldown")
		planning.stop_singleplayer()
		_check(not planning.active and planning.combat["commanders"] == [{}, {}], "Leaving removes both prior commander states")
	var opponent_seed: int = 0
	var opponent_target: int = 0
	var far: int = 0
	while true:
		expected.seed = opponent_seed
		opponent_target = expected.randi_range(0, 100)
		var opponent_guess: int = expected.randi_range(0, 100)
		far = 100 if opponent_target < 50 else 0
		if absi(opponent_guess - opponent_target) < absi(far - opponent_target):
			break
		opponent_seed += 1
	planning._draft_rng.seed = opponent_seed
	planning.start_singleplayer()
	_check(planning.submit_commander_guess(far) and planning.commander_draft["first_picker"] == 1 and planning.commander_draft["picker"] == 0 and planning.commander_draft["picks"][0] == "" and planning.commander_draft["picks"][1] in ["knight", "priestess"], "A closer host-generated solo guess picks a real hero first and leaves the local player second")
	var opponent_pick := StringName(planning.commander_draft["picks"][1])
	var after_auto_pick: int = planning._draft_rng.state
	_check(not planning.select_commander(opponent_pick), "The local second pick cannot duplicate the opponent's already frozen hero")
	_check(planning.select_commander(&"priestess" if opponent_pick == &"knight" else &"knight") and planning.commander_draft["phase"] == "loadout" and planning._draft_rng.state == after_auto_pick, "The local second pick takes the remaining hero without rerolling the opponent")
	planning.stop_singleplayer()
	expected.state = planning._draft_rng.state
	var replay_target: int = expected.randi_range(0, 100)
	expected.randi_range(0, 100)
	planning.start_singleplayer()
	_check(planning.commander_draft["phase"] == "guessing" and planning.chosen_commander_id == &"" and planning.commander_draft["picks"] == ["", ""] and planning.commander_draft["target"] == -1 and planning._draft_rng.state == expected.state, "Replay draws fresh host target/opponent guess and clears both picks instead of replaying the previous draft")
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning) and planning.commander_draft["target"] == replay_target and planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout() and planning.combat["commanders"][0]["obstacles"].size() == 3 and planning.combat["commanders"][0]["cooldown_remaining"] == 0.0, "A completed replay draft reveals its newly drawn target, regenerates terrain and resets all run-only cooldowns")
	planning.queue_free()
	session.queue_free()
	await process_frame
