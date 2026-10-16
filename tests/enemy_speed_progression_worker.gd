extends "res://tests/match_multiplayer_worker.gd"


func _planning_rules() -> CombatRules:
	_manual_simulation = true
	var rules := CombatRules.new()
	rules.base_health = 1000
	rules.starting_coins = 1000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.enemy_speed = 2.0 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.1 if _lane == "host" else 0.9
	rules.speed_growth_rounds = 5 if _lane == "host" else 1
	var enemy: EnemyDefinition = preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition
	enemy.send_first_wave = 1
	rules.catalog.enemies = [enemy]
	return rules
