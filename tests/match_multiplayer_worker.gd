extends "res://tests/match_planning_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 2
	rules.enemy_health = 4
	rules.health_growth = 0
	rules.speed_growth = 0.0
	rules.wave_weight_growth = 0
	rules.wave_weight = 1
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
	var enemy_definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.enemy_definitions:
		var definition := source.duplicate() as EnemyDefinition
		if _lane == "guest":
			definition.health_multiplier = 9.0
			definition.speed_multiplier = 0.1
			definition.send_cost = 1
			definition.send_income = 99
		enemy_definitions.append(definition)
	rules.enemy_definitions = enemy_definitions
	if _lane == "guest":
		rules.base_health = 7
		rules.starting_coins = 999
		rules.kill_bounty = 99
		rules.wave_reward = 99
		rules.wave_reward_growth = 99
	return rules


func _execute_command(command: Dictionary) -> void:
	var action: String = String(command.get("action", ""))
	if action in ["send_scenario", "typed_send_scenario"]:
		var rules: CombatRules = _planning_rules()
		var typed: bool = action == "typed_send_scenario"
		rules.base_health = (12 if typed else 6) if _lane == "host" else 99
		rules.starting_coins = (200 if typed else 45) if _lane == "host" else 999
		rules.health_growth = 2
		rules.send_cutoff_seconds = (0.8 if typed else 0.5) if _lane == "host" else 99.0
		planning.combat_rules = rules
	else:
		super._execute_command(command)
