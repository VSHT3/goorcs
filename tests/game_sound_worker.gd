extends "res://tests/match_branch_worker.gd"

func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health=1000
	rules.starting_coins=5000
	rules.wave_weight=3
	rules.wave_weight_growth=0
	rules.spawn_interval=0.0
	rules.enemy_health=100
	rules.enemy_speed=0.0
	rules.speed_growth_fraction=0.0
	var enemy: EnemyDefinition=preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
	enemy.send_first_wave=1
	rules.catalog.enemies=[enemy]
	if _lane=="guest":
		for tower: TowerDefinition in rules.catalog.towers:
			tower.attack_sound=CombatSoundEvents.Cue.RUNE
	return rules

func _execute_command(command: Dictionary) -> void:
	match String(command.get("action","")):
		"wound_fixture":
			if _session.is_host:
				for slot: int in range(2):
					for enemy: Dictionary in planning._host_combat.enemies[slot]: enemy["hp"]=1
					for tower: Dictionary in planning._host_combat.towers[slot]: tower["cooldown"]=0.0
				planning._publish_snapshot()
		"leak_fixture":
			if _session.is_host:
				for board: Array in planning._host_combat.enemies:
					for enemy: Dictionary in board:
						enemy["speed"]=1000.0
						enemy["base_speed"]=1000.0
				planning._publish_snapshot()
		"round_fixture":
			if _session.is_host: planning.debug_set_values(3,5000)
		_:
			super._execute_command(command)
