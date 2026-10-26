extends "res://tests/match_multiplayer_worker.gd"


func _fixture_reserved_cells() -> Array[Vector2i]:
	var reserved: Array[Vector2i] = []
	for x: int in range(planning.layouts[0].dimensions.x):
		reserved.append(Vector2i(x, planning.layouts[0].entrance.y))
	for x: int in [0, 2, 4, 6, 8]:
		reserved.append(Vector2i(x, 3))
	return reserved


func _fixture_landmark_exclusions() -> Array[Vector2i]:
	var reserved: Array[Vector2i] = []
	# This fixture observes the baseline first volley after all six spawns.
	# Sanctuary enables event-boundary attacks on both boards, before that
	# observation; keep real landmarks outside every authored tower's aura.
	for x: int in [0, 2, 4, 6, 8]:
		var build := Vector2i(x, 3)
		for y: int in range(planning.layouts[0].dimensions.y):
			for column: int in range(planning.layouts[0].dimensions.x):
				var cell := Vector2i(column, y)
				if Vector2(cell).distance_squared_to(Vector2(build)) <= CommanderRules.RADIUS * CommanderRules.RADIUS and not reserved.has(cell):
					reserved.append(cell)
	return reserved


func _planning_rules() -> CombatRules:
	_manual_simulation = true
	var rules := CombatRules.new()
	rules.starting_coins = 50000
	rules.base_health = 1000
	rules.enemy_health = 400
	rules.health_growth = 0
	rules.enemy_speed = 0.01
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 6
	rules.spawn_interval = 0.001
	var enemy: EnemyDefinition = rules.catalog.enemies[0].duplicate() as EnemyDefinition
	enemy.send_first_wave = 1
	rules.catalog.enemies = [enemy]
	var tower: TowerDefinition = rules.catalog.towers[0].duplicate(true) as TowerDefinition
	tower.range_cells = 20.0
	if _lane == "guest":
		tower.damage = 99
		for branch: Dictionary in tower.advancements.values():
			branch["cost"] = 1
			if branch.has("burn_dps"): branch["burn_dps"] = 999.0
			if branch.has("continuous_dps"): branch["continuous_dps"] = 999.0
			if branch.has("attack_rate_multiplier"): branch["attack_rate_multiplier"] = 99.0
			if branch.has("splash_radius"): branch["splash_radius"] = 99.0
	rules.catalog.towers = [tower]
	return rules

