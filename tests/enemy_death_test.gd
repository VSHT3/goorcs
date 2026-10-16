extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_kill_events()
	_test_expiry_and_resets()
	_test_leaks()
	if failures == 0:
		print("PASS: confirmed-kill death events, detached positions, exactly-once rewards, expiry, reset generations, and bloodless leak semantics")
	quit(1 if failures else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new()
	for x: int in range(1,13): layout.place(Vector2i(x,4))
	return [layout.capture_routing(),layout.capture_routing()]

func _model() -> MatchCombat:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.enemy_health = 1
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	var model := MatchCombat.new(rules)
	var roster: Array[String] = []
	model.sandbox_start(_routes(),1,roster)
	return model

func _test_kill_events() -> void:
	var model: MatchCombat = _model()
	model.build(0,Vector2i(0,3),&"arrow_tower",MatchCombat.TargetMode.FURTHEST)
	model.sandbox_spawn(0,&"grunt",2)
	var victim: Dictionary = model.enemies[0][0].duplicate(true)
	var before: int = model.coins[0]
	model.advance(0.01)
	var accepted: Dictionary = model.snapshot()
	_check(accepted["deaths"][0].size() == 1 and accepted["deaths"][1].is_empty(), "One actual kill publishes exactly one owned-side cosmetic event")
	if accepted["deaths"][0].is_empty(): return
	var event: Dictionary = accepted["deaths"][0][0]
	_check(event["enemy_id"] == victim["id"] and event["type_id"] == "grunt" and event["pos"] == victim["pos"], "Event freezes the victim identity and authoritative death location")
	_check(model.enemies[0].size() == 1 and model.enemies[0][0]["id"] != victim["id"] and model.towers[0][0]["kills"] == 1, "Cosmetic corpse is removed from living targets and counted once")
	_check(model.coins[0] == before + int(accepted["rules"]["kill_bounty"]) and accepted["enemy_totals"][0]["kills"]["grunt"] == 1, "Death presentation grants no extra bounty or progression")
	event["pos"] = Vector2(100,100)
	_check(model.snapshot()["deaths"][0][0]["pos"] == victim["pos"], "A client cannot move a retained authoritative event through a snapshot")
	model.towers[0][0]["cooldown"] = 100.0
	model.advance(0.1)
	_check(model.snapshot()["deaths"][0].size() == 1 and model.towers[0][0]["kills"] == 1, "Repeated publications do not create additional kills or events")

func _test_expiry_and_resets() -> void:
	var model: MatchCombat = _model()
	model.build(0,Vector2i(0,3),&"arrow_tower",MatchCombat.TargetMode.FURTHEST)
	model.sandbox_spawn(0,&"orcling",2)
	model.advance(0.01)
	var first_id: int = model.snapshot()["deaths"][0][0]["id"]
	model.towers[0][0]["cooldown"] = 100.0
	model.advance(MatchCombat.DEATH_EVENT_LIFETIME)
	_check(model.snapshot()["deaths"][0].is_empty() and model.enemies[0].size() == 1, "Old visual events expire without removing a living enemy")
	model.towers[0][0]["cooldown"] = 0.0
	model.advance(0.01)
	_check(model.snapshot()["deaths"][0][0]["id"] > first_id and model.phase == MatchCombat.Phase.PLANNING, "Later kills have ordered distinct events and corpses do not delay wave clearance")
	var generation: int = model.snapshot()["death_generation"]
	model.grow_for_main_round()
	_check(model.snapshot()["deaths"] == [[],[]] and model.snapshot()["death_generation"] > generation, "Map growth clears old-coordinate corpse effects")
	model = _model()
	model.build(0,Vector2i(0,3),&"arrow_tower",MatchCombat.TargetMode.FURTHEST)
	model.sandbox_spawn(0,&"orcling",1)
	model.advance(0.01)
	generation = model.snapshot()["death_generation"]
	model.debug_set_round(3)
	_check(model.snapshot()["deaths"] == [[],[]] and model.snapshot()["death_generation"] > generation, "Debug reset invalidates client corpse playback without resetting lifetime kills")

func _test_leaks() -> void:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.enemy_speed = 1000.0
	var model := MatchCombat.new(rules)
	var roster: Array[String] = []
	model.sandbox_start(_routes(),1,roster)
	model.sandbox_spawn(0,&"skeleorc",1)
	model.advance(0.1)
	_check(model.enemies[0].is_empty() and model.snapshot()["deaths"] == [[],[]] and model.snapshot()["enemy_totals"][0]["kills"].is_empty(), "Reaching the base is not a killed corpse, splatter, bounty, or lifetime kill")
