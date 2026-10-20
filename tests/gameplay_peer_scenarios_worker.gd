extends "res://tests/gameplay_peer_worker.gd"

var _scenario: String = "rolls"
var _ballista_boards: Array[PathBoard] = []
var _ballista_probe: Dictionary = {}


func _on_planning_changed() -> void:
	# Only explicit host step commands may advance these real peer matches.
	planning.set_physics_process(false)
	if _scenario == "ballista" and planning.active:
		_update_ballista_boards()


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.starting_coins = 100 if _scenario == "rolls" else 20000
	rules.base_health = 1000
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 4 if _scenario == "chain" else 1
	if _scenario == "ballista":
		rules.wave_weight = 2
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.wave_reward = 11
	rules.wave_reward_growth = 0
	rules.starting_reroll_currency = 8 if _scenario == "rolls" else 0
	rules.clear_reroll_currency = 3
	if _scenario == "rolls":
		rules.roll_rules = _fixture_rolls()
	var towers: Array[TowerDefinition] = []
	for source: TowerDefinition in rules.catalog.towers:
		var tower := source.duplicate(true) as TowerDefinition
		if tower.behavior_kind in ["attack", "chain"]:
			tower.damage = 10
			tower.interval = 1.0
			if tower.behavior_kind == "attack":
				tower.range_cells = 20.0
		if _scenario == "ballista" and tower.reward.id == &"orc_ballista":
			tower.range_cells = 4.0
			tower.interval = 20.0
		if _scenario == "economy" and tower.behavior_kind == "attack":
			tower.damage = 100000
			tower.interval = 0.01
		if _scenario == "bounty" and tower.behavior_kind == "attack":
			tower.damage_upgrade_bonus = 100000
			tower.interval = 0.01
		if _lane == "guest":
			# These are valid, deliberately divergent local resources, not mocks.
			tower.cost = 1
			tower.damage = 1 if tower.behavior_kind in ["attack", "chain", "catapult"] else 0
			for branch: Dictionary in tower.evolutions.values():
				branch["cost"] = 1
		towers.append(tower)
	rules.catalog.towers = towers
	var enemies: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		var enemy := source.duplicate() as EnemyDefinition
		enemy.regular_spawn_enabled = enemy.id == &"grunt"
		enemy.spawn_weight = 1
		enemy.first_wave = 1
		enemy.send_first_wave = 1
		enemy.send_cost = 9
		enemy.send_income = 2
		enemy.health_multiplier = 1.0
		enemy.kill_bounty = 7
		enemy.reroll_drop_chance = 1.0
		enemy.reroll_drop_amount = 2
		if enemy.id == &"runner":
			enemy.kill_bounty = 11
			enemy.reroll_drop_amount = 5
		elif enemy.id == &"necorcmancer":
			enemy.health_multiplier = 2.0
			enemy.kill_bounty = 11
			enemy.reroll_drop_amount = 4
			enemy.summon_interval = 10.0
			enemy.summon_cast_duration = 0.1
			enemy.summon_min = 1
			enemy.summon_max = 1
			enemy.summon_limit = 1
		elif enemy.id == &"skeleorc":
			enemy.health_multiplier = 0.4
			enemy.kill_bounty = 0
			enemy.reroll_drop_amount = 7
		if _lane == "guest":
			enemy.reroll_drop_chance = 0.0
			enemy.reroll_drop_amount = 99
			enemy.kill_bounty = 999
		enemies.append(enemy)
	rules.catalog.enemies = enemies
	if _lane == "guest":
		rules.starting_coins = 99999
		rules.starting_reroll_currency = 999
		rules.clear_reroll_currency = 999
		rules.wave_reward = 999
	return rules


func _fixture_rolls() -> TowerRollRules:
	var rolls := TowerRollRules.new()
	rolls.slot_profiles = {"attack": {}, "support": {}, "economy": {}}
	for rarity: String in TowerRollRules.RARITIES:
		var value: float = 0.99 if _lane == "guest" else 0.25
		rolls.rarities.append({
			"id": rarity, "title": rarity.capitalize(),
			"weight": 1.0 if rarity in ["common", "mythic"] else 0.0,
			"positive_slots": 1, "drawback_slots": 0,
			"positive_pool": {"damage": Vector2(value, value), "support_buff": Vector2(value, value), "economy_production": Vector2(value, value)},
			"drawback_pool": {},
		})
	return rolls


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"scenario":
			_scenario = String(command["name"])
			planning.combat_rules = _planning_rules()
		"seed_fixture":
			if _session.is_host and planning._host_combat != null:
				planning._host_combat._roll_random.seed = 1249
				planning._host_combat._drop_random.seed = 5723
		"step":
			if _session.is_host:
				planning._physics_process(float(command["delta"]))
				planning._publish_snapshot()
		"formation_fixture":
			if _session.is_host:
				var model: MatchCombat = planning._host_combat
				var slot: int = int(command.get("slot", 0))
				var positions: Array = command["progress"]
				for index: int in range(mini(positions.size(), model.enemies[slot].size())):
					var enemy: Dictionary = model.enemies[slot][index]
					enemy["progress"] = float(positions[index])
					enemy["pos"] = model._position(enemy["route"], enemy["progress"])
				planning._publish_snapshot()
		"ballista_formation":
			if _session.is_host:
				var model: MatchCombat = planning._host_combat
				for index: int in range(model.enemies[0].size()):
					var enemy: Dictionary = model.enemies[0][index]
					# Inside the Ballista's circular 4-cell reach from (4, 3): the
					# victim starts west at x=1, the decoy waits south at x=4.
					enemy["progress"] = 1.0 if index == 0 else 4.0
					enemy["pos"] = model._position(enemy["route"], enemy["progress"])
					enemy["hp"] = 300 if index == 0 else 100
					enemy["max_hp"] = enemy["hp"]
					enemy["base_speed"] = 1.0 if index == 0 else 0.0
					enemy["speed"] = enemy["base_speed"]
				planning._publish_snapshot()
		"ballista_reload":
			if _session.is_host:
				planning._host_combat.towers[0][0]["cooldown"] = float(command["seconds"])
				planning._publish_snapshot()
		"ballista_targeting":
			if _session.is_host:
				planning.set_targeting(0, int(planning._host_combat.towers[0][0]["id"]), int(command["mode"]))
		"ballista_target_state":
			if _session.is_host:
				var model: MatchCombat = planning._host_combat
				var target_id: int = int(model.towers[0][0]["target_id"])
				for index: int in range(model.enemies[0].size()):
					var enemy: Dictionary = model.enemies[0][index]
					if int(enemy["id"]) != target_id:
						continue
					match String(command["state"]):
						"out_of_range":
							enemy["progress"] = 12.0
							enemy["pos"] = model._position(enemy["route"], enemy["progress"])
						"dead":
							enemy["progress"] = 7.001
							enemy["pos"] = model._position(enemy["route"], enemy["progress"])
							enemy["hp"] = 0
						"absent":
							model.enemies[0].remove_at(index)
					break
				if String(command["state"]) == "none":
					model.enemies[0].clear()
				model._update_tracking_target(0, model.towers[0][0])
				planning._publish_snapshot()
		"ballista_probe":
			_ballista_probe = {"ballista_probe": int(command["id"]), "ballista_views": _observe_ballista_boards()}
		"authenticated_ready":
			if _session.is_host:
				planning._apply_command(1, "ready", 0, Vector2i.ZERO, true)
			else:
				planning._receive_command.rpc_id(1, "ready", 1, Vector2i.ZERO, true)
		"forged_rewards":
			if not _session.is_host:
				# Exercise the actual authenticated command endpoint, not a fake
				# forwarding object or a second local simulation.
				for action: String in ["currency", "drop", "outcome"]:
					planning._receive_tower_command.rpc_id(1, action, 1, Vector2i.ZERO, -1, 999999, "mythic")
		"mutate_display":
			if not _session.is_host:
				planning.combat["coins"] = [999999, 999999]
				planning.combat["reroll_currency"] = [999999, 999999]
				planning.combat["winner"] = 1
				planning.combat["coin_flip"] = true
				planning.combat["enemies"] = [[], []]
				planning._request_snapshot.rpc_id(1)
		_:
			super._execute_command(command)


func _publish() -> void:
	super._publish()
	if planning == null or _directory.is_empty() or _executing_command:
		return
	var extra: Dictionary = {}
	extra.merge(_ballista_probe)
	if _session.is_host and planning._host_combat != null:
		extra["roll_state"] = str(planning._host_combat._roll_random.state)
		extra["drop_state"] = str(planning._host_combat._drop_random.state)
		var registered_ids: Dictionary = {}
		for definition: TowerDefinition in planning.combat_rules.catalog.towers:
			if definition != null and definition.reward != null:
				registered_ids[String(definition.reward.id)] = true
		var fixture_catalog_ids: Array = registered_ids.keys()
		fixture_catalog_ids.sort()
		extra["fixture_catalog_ids"] = fixture_catalog_ids
		extra["wire_deck_paths"] = []
		extra["wire_public_towers"] = []
		for slot: int in range(2):
			var snapshot: Dictionary = planning._snapshot(slot)
			extra["wire_deck_paths"].append(_deck_paths(snapshot, registered_ids))
			var public_combat: Dictionary = snapshot["combat"]
			var placed_ids: Array = [[], []]
			for board: int in range(2):
				for tower: Dictionary in public_combat.get("towers", [[], []])[board]:
					placed_ids[board].append(tower["type_id"])
			# JSON sorts dictionary keys but preserves array order. Compare catalog
			# identities canonically, independently of resource declaration order.
			var catalog_ids: Array = public_combat.get("tower_types", {}).keys()
			catalog_ids.sort()
			extra["wire_public_towers"].append({
				"catalog_ids": catalog_ids,
				"placed_ids": placed_ids,
			})
	var file := FileAccess.open(_path("scenario") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(extra))
	file.close()
	DirAccess.rename_absolute(_path("scenario") + ".tmp", _path("scenario"))


func _deck_paths(value: Variant, registered_ids: Dictionary, prefix: String = "") -> Dictionary:
	var found: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			found.merge(_deck_paths(value[key], registered_ids, String(key) if prefix.is_empty() else prefix + "." + String(key)))
	elif value is Array:
		# Decks are arrays of identities. Catalog dictionary keys and placed
		# towers' scalar type_id fields are public, not private deck disclosures.
		# Still descend through those objects to catch any nested deck array.
		var identities: Array = []
		for item: Variant in value:
			if (item is String or item is StringName) and registered_ids.has(String(item)):
				identities.append(String(item))
		if not identities.is_empty():
			found[prefix] = identities
		for index: int in range(value.size()):
			found.merge(_deck_paths(value[index], registered_ids, prefix + "[%d]" % index))
	return found


func _update_ballista_boards() -> void:
	if _ballista_boards.is_empty():
		for mirrored: bool in [false, true]:
			var board := PathBoard.new()
			board.hide()
			board.size = Vector2(900, 600)
			board.mirror_horizontal = mirrored
			board.content_catalog = planning.combat_rules.catalog
			_main.add_child(board)
			_ballista_boards.append(board)
	for board: PathBoard in _ballista_boards:
		board.layout = planning.layouts[0]
		board.tower_types = planning.combat.get("tower_types", {})
		board.combat_enemies = planning.combat.get("enemies", [[], []])[0]
		board.combat_towers = planning.combat.get("towers", [[], []])[0]
		# Advance presentation time only at the deterministic probe samples below.
		board.set_process(false)


func _observe_ballista_boards() -> Array:
	var views: Array = []
	for board: PathBoard in _ballista_boards:
		if board.combat_towers.is_empty():
			continue
		var tower: Dictionary = board.combat_towers[0]
		var poses: Array[int] = []
		for fraction: float in [0.0, 0.5, 1.0]:
			board._enemy_blend_elapsed = PathBoard.ENEMY_BLEND_DURATION * fraction
			poses.append(board._directional_weapon_index(tower))
		var traces: Array = board._shot_traces
		views.append({
			"mirrored": board.mirror_horizontal,
			"poses": poses,
			"released_pose": board._directional_weapon_index(tower, true),
			"live_muzzle": str(board._tower_muzzle(tower, 0)),
			"released_origin_error": board._projectile_origin(traces[0]).distance_to(board._tower_muzzle(tower, 0, true)) / board._cell_size() if not traces.is_empty() else 0.0,
			"trace_count": traces.size(),
			"trace_origin": str(board._projectile_origin(traces[0])) if not traces.is_empty() else "",
			"trace_aim": str(traces[0]["aim"]) if not traces.is_empty() else "",
			"target_id": tower["target_id"],
			"tracking_target_id": tower["tracking_target_id"],
			"tracking_aim": str(tower["tracking_aim"]),
			"shot": tower["shot"],
		})
	return views
