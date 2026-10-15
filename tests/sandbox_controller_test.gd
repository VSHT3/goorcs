extends SceneTree

var failures: int = 0
var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rules := CombatRules.new()
	rules.starting_coins = 0
	var sandbox := SandboxController.new()
	sandbox.configure(catalog, rules)
	_check(not rules.sandbox_mode and sandbox.rules.sandbox_mode, "Sandbox captures isolated rules without changing real matches")
	_check(sandbox.layout.budget == 14 * 9 - 2, "Every non-endpoint cell is available, not a finite play budget")
	_check(not sandbox.start_wave() and not sandbox.spawn(&"grunt", 1), "Disconnected route cannot begin combat")
	_connect_path(sandbox)
	_check(sandbox.layout.is_ready(), "Sandbox accepts a normal connected PathLayout")
	var initial_coins: Array[int] = sandbox.combat.coins.duplicate()
	for definition: TowerDefinition in catalog.towers:
		var branches: Array = definition.evolutions.keys()
		if branches.is_empty():
			branches.append("special" if not definition.special_upgrade.is_empty() else "")
		for branch: String in branches:
			_check(sandbox.build(Vector2i(3, 1), definition.reward.id), "All tower types build with zero Coins and no collection")
			var tower: Dictionary = sandbox.combat.towers[0].back()
			var id: int = int(tower["id"])
			_check(sandbox.upgrade(id, "damage") and sandbox.upgrade(id, "speed"), "Both normal upgrades are truly free")
			if not branch.is_empty():
				_check(sandbox.upgrade(id, branch), "Every authored special/evolution branch is available")
			if definition.evolutions.get(branch, {}).has("followup"):
				_check(sandbox.upgrade(id, "freeze_runes"), "Boulders follow-up is free and owned by normal combat rules")
			_check(sandbox.set_targeting(id, MatchCombat.TargetMode.STRONGEST), "Sandbox targeting uses combat owner")
			if definition.special_upgrade == "second_archer":
				_check(sandbox.set_targeting(id, MatchCombat.TargetMode.CLOSEST, true), "Second archer has independent targeting")
			_check(sandbox.sell(id), "Sandbox tower can be sold for a different branch")
	_check(sandbox.combat.coins == initial_coins, "Free buys, upgrades, and sales do not spend or fabricate balances")
	_check(not sandbox.build(sandbox.layout.entrance, catalog.towers[0].reward.id), "Towers cannot occupy an endpoint or path")
	_check(not sandbox.build(Vector2i(-1, 0), catalog.towers[0].reward.id), "Towers cannot leave board bounds")
	_check(sandbox.set_round(46), "Any supported defined round is selectable")
	for enemy: EnemyDefinition in catalog.enemies:
		_check(sandbox.spawn(enemy.id, 3), "Every enemy, including summon-only, spawns directly")
		_check(sandbox.combat.enemies[0].size() == 3 and sandbox.combat.enemies[1].is_empty(), "Direct spawn is exact and only on owned board")
		_check(sandbox.combat.enemies[0][0]["type_id"] == String(enemy.id), "Selected enemy identity is retained")
		_check(sandbox.combat.wave == 46, "Direct enemies use selected round scaling")
		_check(sandbox.paused, "Direct spawn while stopped is inspectable before playing")
		sandbox.stop()
	_check(not sandbox.spawn(&"missing_enemy", 2) and sandbox.combat.phase == MatchCombat.Phase.PLANNING, "Invalid direct spawn does not discard current state")
	_check(sandbox.build(Vector2i(3, 1), catalog.towers[0].reward.id), "Build retained for stop test")
	_check(sandbox.start_wave(), "Selected round uses real weighted wave generator")
	_check(sandbox.combat.wave == 46 and not sandbox.combat.wave_roster.is_empty(), "Weighted round preserves selected round and generated roster")
	for type_id: String in sandbox.combat.wave_roster:
		_check(type_id != "skeleorc", "Weighted waves never include summon-only units")
	_check(not sandbox.edit_path(Vector2i(2, 2), true), "Captured routes are locked during combat")
	sandbox.set_active(true)
	sandbox.advance(0.2)
	var before_pause: Dictionary = sandbox.combat.snapshot()
	sandbox.toggle_play()
	sandbox.advance(5.0)
	_check(sandbox.combat.snapshot() == before_pause, "Pause freezes actual accepted simulation")
	sandbox.set_active(false)
	sandbox.advance(5.0)
	_check(sandbox.combat.snapshot() == before_pause, "Inactive playground cannot simulate")
	_check(sandbox.stop() and sandbox.combat.towers[0].size() == 1 and sandbox.combat.enemies[0].is_empty(), "Stop clears enemies but preserves the build")
	_check(sandbox.combat.wave == 45 and sandbox.layout.is_ready(), "Stop retains round and editable route")
	sandbox.reset_build()
	_check(sandbox.combat.towers[0].is_empty() and sandbox.layout.is_ready() and sandbox.round_number == 46, "Reset build preserves paths and round")
	_check(sandbox.resize_map(Vector2i(80, 40)), "Large maps are supported beyond old dimensions")
	_check(sandbox.layout.dimensions == Vector2i(80, 40) and sandbox.layout.budget == 3198, "Resize gives the whole new map unlimited path capacity")
	_check(sandbox.layout.used_tiles() == 0 and sandbox.round_number == 46, "Destructive resize clears paths while retaining round")
	_check(not sandbox.resize_map(Vector2i(1, 4)) and sandbox.layout.dimensions == Vector2i(80, 40), "Invalid resize leaves map intact")
	sandbox.resize_map(Vector2i(2, 1))
	_check(sandbox.layout.is_ready(), "Adjacent endpoints form a legal minimal playground")
	sandbox.spawn(&"grunt", 20)
	var initial_health: Array[int] = sandbox.combat.base_health.duplicate()
	sandbox.set_active(true)
	sandbox.toggle_play()
	for index: int in range(120):
		sandbox.advance(1.0 / 60.0)
	_check(sandbox.combat.base_health == initial_health and sandbox.combat.phase != MatchCombat.Phase.FINISHED, "Repeated leaks never damage sandbox lives or end its run")
	_check(bool(sandbox.combat.snapshot()["rules"]["sandbox_mode"]), "Snapshots identify sandbox for persistence isolation")
	_check(sandbox.set_round(1200) and sandbox.spawn(&"grunt", 1) and sandbox.combat.wave == 1200, "Sandbox has no arbitrary normal-match debug round cap")
	if failures == 0:
		print("PASS: sandbox controller isolation, content, waves, free evolution, map editing, pause and invincible lives")
	quit(1 if failures > 0 else 0)


func _connect_path(sandbox: SandboxController) -> void:
	for x: int in range(1, sandbox.layout.dimensions.x - 1):
		sandbox.edit_path(Vector2i(x, sandbox.layout.entrance.y), true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
