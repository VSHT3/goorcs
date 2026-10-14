extends "res://tests/match_planning_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 2
	rules.enemy_health = 4
	rules.health_growth = 0
	rules.speed_growth = 0.0
	rules.count_growth = 0
	rules.enemies_per_wave = 1
	rules.enemy_speed = 6.5
	rules.spawn_interval = 0.05
	var definitions: Array[TowerDefinition] = []
	for source: TowerDefinition in rules.tower_definitions:
		var definition := TowerDefinition.new()
		definition.reward = source.reward
		definition.damage = 1 if _lane == "guest" else 99
		definition.range_cells = 0.5 if _lane == "guest" else 1.5
		definition.interval = 5.0 if _lane == "guest" else 0.05
		definition.cost = source.cost
		definition.damage_upgrade_cost = source.damage_upgrade_cost
		definition.damage_upgrade_bonus = source.damage_upgrade_bonus
		definition.speed_upgrade_cost = source.speed_upgrade_cost
		definition.speed_upgrade_multiplier = source.speed_upgrade_multiplier
		definition.area_attack = source.area_attack
		definitions.append(definition)
	rules.tower_definitions = definitions
	if _lane == "guest":
		rules.base_health = 7
		rules.starting_coins = 999
		rules.kill_bounty = 99
		rules.wave_reward = 99
		rules.wave_reward_growth = 99
	return rules
