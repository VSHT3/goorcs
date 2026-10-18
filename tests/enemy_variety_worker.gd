extends "res://tests/match_branch_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		definitions.append(source.duplicate() as EnemyDefinition)
	rules.catalog.enemies = definitions
	rules.base_health = 10000
	rules.starting_coins = 10000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.05 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	if _lane == "guest":
		# Divergent valid local data must never decide accepted enemy abilities.
		for enemy: EnemyDefinition in rules.catalog.enemies:
			if enemy.physical_damage_multiplier != 1.0:
				enemy.physical_damage_multiplier = 1.0
			if enemy.death_spawn_count > 0:
				enemy.death_spawn_count = 5
			if enemy.enrage_health_fraction > 0.0:
				enemy.enrage_speed_multiplier = 7.0
			if enemy.regeneration_interval > 0.0:
				enemy.regeneration_interval = 0.02
				enemy.regeneration_fraction = 0.5
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"variety_round":
			if _lane == "host":
				planning.debug_set_values(66, 10000, 0)
		"variety_damage":
			if _lane == "host":
				var combat: MatchCombat = planning._host_combat
				var tower: Dictionary = combat.towers[1][0]
				for index: int in range(combat.enemies[1].size() - 1, -1, -1):
					var enemy: Dictionary = combat.enemies[1][index]
					match String(enemy["type_id"]):
						"scrapguard":
							combat._hit(1, tower, index, 10, false, &"physical")
						"rage_orc":
							combat._hit(1, tower, index, int(enemy["max_hp"]) / 2, false, &"physical")
						"moss_orc":
							combat._hit(1, tower, index, 100, false, &"magic")
						"crate_orc":
							combat._hit(1, tower, index, 10000, false, &"physical")
				planning._publish_snapshot()
		_:
			super._execute_command(command)
