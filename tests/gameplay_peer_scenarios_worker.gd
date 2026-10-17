extends "res://tests/gameplay_peer_worker.gd"

var _scenario: String = "rolls"


func _on_planning_changed() -> void:
	# Only explicit host step commands may advance these real peer matches.
	planning.set_physics_process(false)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.starting_coins = 100 if _scenario == "rolls" else 20000
	rules.base_health = 1000
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 4 if _scenario == "chain" else 1
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
		if _scenario == "economy" and tower.behavior_kind == "attack":
			tower.damage = 100000
			tower.interval = 0.01
		if _scenario == "bounty" and tower.behavior_kind == "attack":
			tower.damage_upgrade_bonus = 100000
			tower.interval = 0.01
		if _lane == "guest":
			# These are valid, deliberately divergent local resources, not mocks.
			tower.cost = 1
			tower.damage = 1 if tower.behavior_kind in ["attack", "chain"] else 0
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
