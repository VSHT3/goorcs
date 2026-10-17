extends "res://tests/match_branch_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.starting_coins = 1000
	rules.base_health = 10000
	rules.enemy_speed = 0.05 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	if _lane == "guest":
		rules.enemy_health = 999
		rules.health_growth = 99
		rules.catalog = rules.catalog.duplicate()
		var definitions: Array[EnemyDefinition] = []
		for source: EnemyDefinition in rules.catalog.enemies:
			var enemy := source.duplicate() as EnemyDefinition
			if enemy.id == &"necorcmancer_mancer":
				enemy.health_multiplier = 0.1
				enemy.speed_multiplier = 10.0
				enemy.first_wave = 1
				enemy.boss_spawn_chance = 1.0
				enemy.boss_spawn_chance_cap = 1.0
				enemy.send_enabled = true
				enemy.send_first_wave = 1
				enemy.summon_interval = 0.01
			definitions.append(enemy)
		rules.catalog.enemies = definitions
	return rules


func _execute_command(command: Dictionary) -> void:
	if String(command.get("action", "")) == "round_fixture":
		if _lane == "host":
			planning.debug_set_values(int(command["round"]), 1000, int(planning.combat["reroll_currency"][planning.local_slot()]))
	else:
		super._execute_command(command)
