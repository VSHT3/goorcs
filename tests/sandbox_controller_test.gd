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
		var choices: Array[Dictionary] = []
		if definition.evolutions.is_empty():
			choices.append({"branch": "", "followup": ""})
		for branch: String in definition.evolutions:
			choices.append({"branch": branch, "followup": ""})
			for followup: String in definition.evolutions[branch].get("followups", {}):
				choices.append({"branch": branch, "followup": followup})
		for choice: Dictionary in choices:
			var branch: String = choice["branch"]
			var followup: String = choice["followup"]
			_check(sandbox.build(Vector2i(3, 1), definition.reward.id), "All tower types build with zero Coins and no collection")
			var tower: Dictionary = sandbox.combat.towers[0].back()
			var id: int = int(tower["id"])
			_check(sandbox.upgrade(id, "damage") and sandbox.upgrade(id, "speed"), "Both normal upgrades are truly free")
			_check(tower["damage_upgraded"] and tower["speed_upgraded"], "Accepted sandbox stat upgrades are retained on the actual instance")
			if not definition.special_upgrade.is_empty():
				if not branch.is_empty():
					_check(not sandbox.upgrade(id, branch) and tower["evolution"] == "", "Chain evolution cannot bypass its shared special prerequisite")
				_check(sandbox.upgrade(id, "special") and tower["special_upgraded"], "Authored shared specials are accepted before dependent evolution")
			if not branch.is_empty():
				_check(sandbox.upgrade(id, branch) and tower["evolution"] == branch, "Every authored evolution is accepted and retained")
			if not followup.is_empty():
				_check(sandbox.upgrade(id, followup) and tower["followup"] == followup, "Every authored economy follow-up is accepted on its own fresh tower")
			if definition.evolutions.get(branch, {}).has("followup"):
				_check(sandbox.upgrade(id, "freeze_runes") and tower["freeze_upgraded"], "Boulders follow-up is free and owned by normal combat rules")
			_check(sandbox.set_targeting(id, MatchCombat.TargetMode.STRONGEST), "Sandbox targeting uses combat owner")
			if definition.special_upgrade == "second_archer":
				_check(sandbox.set_targeting(id, MatchCombat.TargetMode.CLOSEST), "Upgraded archers accept the shared tower targeting policy")
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
	_check(sandbox.resize_map(Vector2i(2, 1)), "Minimal-map resize is accepted")
	_check(sandbox.layout.is_ready(), "Adjacent endpoints form a legal minimal playground")
	_check(sandbox.spawn(&"grunt", 20), "Minimal-map fixture accepts its actual leak horde")
	var initial_health: Array[int] = sandbox.combat.base_health.duplicate()
	sandbox.set_active(true)
	sandbox.toggle_play()
	for index: int in range(120):
		sandbox.advance(1.0 / 60.0)
	_check(sandbox.combat.base_health == initial_health and sandbox.combat.phase != MatchCombat.Phase.FINISHED, "Repeated leaks never damage sandbox lives or end its run")
	_check(bool(sandbox.combat.snapshot()["rules"]["sandbox_mode"]), "Snapshots identify sandbox for persistence isolation")
	_check(sandbox.set_round(1200) and sandbox.spawn(&"grunt", 1) and sandbox.combat.wave == 1200, "Sandbox has no arbitrary normal-match debug round cap")
	_restart_exact_test()
	_restart_weighted_test()
	_restart_editing_test()
	if failures == 0:
		print("PASS: sandbox isolation, content, free evolution, maps, playback, invincible lives and combat-owned last-test restart")
	quit(1 if failures > 0 else 0)


func _replay_sandbox(summoning_wave: bool = false) -> SandboxController:
	var rules := preload("res://resources/combat/prototype.tres").duplicate(true) as CombatRules
	var owned_catalog := catalog.duplicate(true) as ContentCatalog
	rules.enemy_health = 10000
	rules.enemy_speed = 0.25
	rules.spawn_interval = 2.0
	rules.spawn_jitter_ratio = 0.0
	if summoning_wave:
		var enemies: Array[EnemyDefinition] = []
		for source: EnemyDefinition in owned_catalog.enemies:
			var definition := source.duplicate(true) as EnemyDefinition
			if definition.id == &"necorcmancer":
				definition.first_wave = 1
				definition.spawn_weight = 1
				definition.max_per_wave = 0
				definition.max_weight_share = 1.0
				definition.summon_interval = 0.1
				definition.summon_cast_duration = 0.05
				definition.summon_min = 1
				definition.summon_max = 1
				definition.summon_limit = 1
				enemies.append(definition)
			elif definition.id == &"skeleorc":
				enemies.append(definition)
		owned_catalog.enemies = enemies
		rules.wave_weight = 6
		rules.wave_weight_growth = 0
	var sandbox := SandboxController.new()
	sandbox.configure(owned_catalog, rules)
	return sandbox


func _preserved_state(sandbox: SandboxController) -> Dictionary:
	var captured: Dictionary = sandbox.combat.snapshot()
	var towers: Array[Dictionary] = []
	for tower: Dictionary in captured["towers"][0]:
		var retained: Dictionary = {}
		for key: String in ["id", "cell", "type_id", "mode", "kills", "damage_upgraded", "speed_upgraded", "special_upgraded", "freeze_upgraded", "evolution", "advancement", "advancement_path", "followup", "rarity", "attributes", "rarity_rerolls", "attribute_rerolls", "rarity_reroll_cost", "attribute_reroll_cost", "damage", "interval", "range", "behavior_kind", "behavior_config", "invested", "sell_value"]:
			retained[key] = tower[key]
		towers.append(retained)
	return {
		"towers": towers, "coins": captured["coins"], "shards": captured["reroll_currency"],
		"health": captured["health"], "income": captured["income"],
		"statistics_id": captured["statistics_id"], "enemy_totals": captured["enemy_totals"],
		"routing": sandbox.layout.capture_routing(), "round": sandbox.round_number,
		"speed": sandbox.speed, "active": sandbox.active,
	}


func _restart_exact_test() -> void:
	var sandbox: SandboxController = _replay_sandbox()
	var initial: Dictionary = sandbox.combat.snapshot()
	_check(not sandbox.can_restart() and not sandbox.restart() and sandbox.combat.snapshot() == initial and sandbox.paused, "No recorded test rejects restart without altering the initial playground")
	_connect_path(sandbox)
	initial = sandbox.combat.snapshot()
	_check(not sandbox.can_restart() and not sandbox.restart() and sandbox.combat.snapshot() == initial, "A ready route alone does not invent a replay recipe")
	_check(sandbox.build(Vector2i(3, 1), &"arrow_tower"), "Replay fixture owns a real rolled tower")
	var tower_id: int = sandbox.combat.towers[0][0]["id"]
	for command: String in ["damage", "speed", "special", "four_archers"]:
		_check(sandbox.upgrade(tower_id, command), "Replay fixture accepts real upgrade " + command)
	_check(sandbox.reroll_tower(tower_id, "rarity") and sandbox.reroll_tower(tower_id, "attributes"), "Replay fixture records accepted roll traits and counters")
	_check(sandbox.set_targeting(tower_id, MatchCombat.TargetMode.STRONGEST), "Replay fixture customizes the shared tower targeting policy")
	_check(sandbox.set_round(12) and sandbox.start_wave(), "Replay fixture begins a weighted test")
	sandbox.set_active(true)
	sandbox.speed = 4.0
	_check(sandbox.spawn(&"grunt", 2), "Spawn still appends its first exact batch to the running weighted wave")
	var before_append: int = sandbox.combat.enemies[0].size()
	var roster: Array[String] = sandbox.combat.wave_roster.duplicate()
	_check(sandbox.spawn(&"skeleorc", 3) and sandbox.combat.enemies[0].size() == before_append + 3 and sandbox.combat.wave_roster == roster, "Mixed Spawn appends without replacing the weighted queue")
	sandbox.advance(0.2)
	_check(int(sandbox.state["spawned"][0]) < int(sandbox.state["total"]) and float(sandbox.combat.enemies[0].back()["age"]) > 0.0, "Replay fixture has both progressed enemies and future regular spawns")
	var old_ids: Array[int] = []
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		old_ids.append(enemy["id"])
	sandbox.set_paused(true)
	var preserved: Dictionary = _preserved_state(sandbox)
	var before_rejection: Dictionary = sandbox.combat.snapshot()
	_check(not sandbox.spawn(&"missing_enemy", 5) and not sandbox.spawn(&"grunt", 0) and sandbox.combat.snapshot() == before_rejection and sandbox.paused, "Rejected exact actions do not mutate the current paused test")
	_check(sandbox.can_restart() and sandbox.restart(), "Last accepted Spawn can restart after mixed and advanced combat")
	_check(not sandbox.paused and sandbox.combat.phase == MatchCombat.Phase.WAVE, "Restart resumes an actual paused combat owner")
	_check(_preserved_state(sandbox) == preserved, "Restart preserves build, all purchased branches, rolls, targeting, balances, route, round, speed and session identity")
	_check(sandbox.combat.enemies[0].size() == 3 and sandbox.combat.enemies[1].is_empty() and sandbox.state["total"] == 0 and sandbox.state["spawn_times"].is_empty(), "Exact replay discards previous mixed enemies and every queued regular spawn")
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		_check(enemy["type_id"] == "skeleorc" and not old_ids.has(enemy["id"]) and enemy["hp"] == enemy["max_hp"] and enemy["progress"] == 0.0 and enemy["age"] == 0.0 and enemy["route"] == sandbox.layout.route, "Exact replay creates only fresh selected enemies on the current captured route")
	sandbox.advance(0.6)
	_check(sandbox.combat.enemies[0].size() == 3 and sandbox.state["total"] == 0, "Abandoned weighted events cannot leak into the restarted exact batch")


func _restart_weighted_test() -> void:
	var sandbox: SandboxController = _replay_sandbox(true)
	_connect_path(sandbox)
	_check(sandbox.spawn(&"skeleorc", 3) and sandbox.start_wave(), "Weighted test replaces the earlier exact-batch recipe")
	sandbox.set_active(true)
	sandbox.advance(0.3)
	var old_ids: Array[int] = []
	var summons: int = 0
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		old_ids.append(enemy["id"])
		if enemy["summoner_id"] >= 0:
			summons += 1
	_check(summons > 0 and int(sandbox.state["spawned"][0]) < int(sandbox.state["total"]), "Weighted replay fixture contains actual combat-owned summons and unfinished regular spawns")
	sandbox.set_paused(true)
	_check(not sandbox.spawn(&"missing_enemy", 2), "Rejected Spawn cannot replace the weighted recipe")
	_check(sandbox.restart() and not sandbox.paused, "A paused weighted test restarts through the normal wave generator")
	_check(sandbox.combat.enemies[0].is_empty() and sandbox.combat.enemies[1].is_empty() and sandbox.state["spawned"][0] == 0, "Weighted restart removes all old enemies and summons and resets queue progress")
	_check(sandbox.state["total"] == 6 and sandbox.state["spawn_times"].size() == sandbox.state["total"], "Weighted replay creates a valid fresh weighted roster and timetable, not the last exact count")
	for type_id: String in sandbox.combat.wave_roster:
		_check(type_id == "necorcmancer", "Weighted replay uses eligible regular enemies rather than summon-only extras")
	sandbox.advance(0.3)
	_check(not sandbox.combat.enemies[0].is_empty(), "Restarted weighted queue produces actual enemies")
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		_check(not old_ids.has(enemy["id"]) and enemy["route"] == sandbox.layout.route, "Weighted replay creates new combat-owned identities with the captured current route")
	_check(sandbox.stop() and sandbox.can_restart() and sandbox.set_round(7) and sandbox.restart() and sandbox.combat.wave == 7 and sandbox.state["total"] == 6, "Stop and round changes retain the weighted recipe and apply the currently selected round")


func _restart_editing_test() -> void:
	var sandbox: SandboxController = _replay_sandbox()
	_connect_path(sandbox)
	var old_route: Array[Vector2i] = sandbox.layout.route.duplicate()
	_check(sandbox.spawn(&"runner", 2) and sandbox.stop() and sandbox.set_round(27), "Exact recipe survives Stop and round edits")
	sandbox.clear_path()
	var before_rejection: Dictionary = sandbox.combat.snapshot()
	var preserved: Dictionary = _preserved_state(sandbox)
	_check(not sandbox.can_restart() and not sandbox.restart() and not sandbox.start_wave() and not sandbox.spawn(&"grunt", 1), "No replay or replacement test is accepted while the route is disconnected")
	_check(sandbox.combat.snapshot() == before_rejection and _preserved_state(sandbox) == preserved and sandbox.paused, "Route-not-ready replay has no simulation, build, layout or playback side effects")
	var row: int = sandbox.layout.entrance.y + 1
	for x: int in range(sandbox.layout.dimensions.x):
		_check(sandbox.edit_path(Vector2i(x, row), true), "Edited replay route accepts its detour")
	_check(sandbox.layout.is_ready() and sandbox.layout.route != old_route and sandbox.can_restart(), "Reconnecting a different route re-enables the retained recipe")
	var expected_health: int = sandbox.state["enemy_types"]["runner"]["health"]
	var expected_speed: float = sandbox.state["enemy_types"]["runner"]["speed"]
	_check(sandbox.restart() and sandbox.combat.wave == 27 and sandbox.combat.enemies[0].size() == 2, "Rejected attempts preserve the last accepted type/count and replay uses the current round")
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		_check(enemy["type_id"] == "runner" and enemy["max_hp"] == expected_health and enemy["speed"] == expected_speed and enemy["route"] == sandbox.layout.route, "Replayed batch uses the new route and real current-round HP/speed scaling")
	_check(sandbox.stop(), "Replay can return to editable planning")
	sandbox.reset_build()
	_check(sandbox.can_restart() and sandbox.restart() and sandbox.combat.enemies[0].size() == 2, "Reset build retains the session-local exact recipe")
	_check(sandbox.resize_map(Vector2i(18, 9)) and not sandbox.can_restart(), "Resize retains the recipe but waits for its new map to be ready")
	before_rejection = sandbox.combat.snapshot()
	_check(not sandbox.restart() and sandbox.combat.snapshot() == before_rejection, "An unready resized map rejects replay without side effects")
	_connect_path(sandbox)
	_check(sandbox.can_restart() and sandbox.restart() and sandbox.combat.enemies[0].size() == 2 and sandbox.combat.wave == 27, "Rebuilt resized route can replay the retained exact recipe")
	for enemy: Dictionary in sandbox.combat.enemies[0]:
		_check(enemy["type_id"] == "runner" and enemy["route"] == sandbox.layout.route, "Resize replay uses the retained type and newly captured board route")


func _connect_path(sandbox: SandboxController) -> void:
	for x: int in range(1, sandbox.layout.dimensions.x - 1):
		_check(sandbox.edit_path(Vector2i(x, sandbox.layout.entrance.y), true), "Sandbox accepts each route tile")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
