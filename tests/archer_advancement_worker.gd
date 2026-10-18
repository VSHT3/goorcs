extends "res://tests/match_multiplayer_worker.gd"
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

