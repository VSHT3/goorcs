extends "res://tests/match_branch_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 1000
	rules.starting_coins = 1000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.enemy_health = 100
	rules.health_growth = 0
	rules.enemy_speed = 0.05 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	# Keep the peer economy scenario independent of shipped send balance.
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		var enemy := source.duplicate() as EnemyDefinition
		match enemy.id:
			&"orcling":
				enemy.send_cost = 12
				enemy.send_income = 1
			&"orc_chief":
				enemy.send_cost = 130
				enemy.send_income = 5
			&"necorcmancer":
				enemy.send_cost = 140
				enemy.send_income = 6
		if _lane == "guest":
			# Client-local ability/group metadata must never simulate accepted effects.
			enemy.group_weights = PackedInt32Array([1])
			if enemy.heal_interval > 0.0:
				enemy.heal_interval = 0.01
			if enemy.summon_interval > 0.0:
				enemy.summon_interval = 0.01
		definitions.append(enemy)
	rules.catalog.enemies = definitions
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"round_fixture":
			if _lane == "host":
				planning._set_debug_values(int(command["round"]), 1000, int(planning.combat["reroll_currency"][planning.local_slot()]))
		"wound_fixture":
			if _lane == "host":
				for enemy: Dictionary in planning._host_combat.enemies[1]:
					if enemy["type_id"] == "orcling":
						enemy["hp"] = 10
				planning._publish_snapshot()
		_:
			super._execute_command(command)
