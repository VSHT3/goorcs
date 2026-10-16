extends "res://tests/match_branch_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	# This peer fixture measures ordinary, single-member cadence.
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition]
	rules.catalog.enemies[0].send_first_wave = 1
	rules.base_health = 100
	rules.starting_coins = 1000
	rules.wave_weight = 6
	rules.wave_weight_growth = 0
	rules.enemy_speed = 0.1 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.75 if _lane == "host" else 0.01
	rules.spawn_jitter_ratio = 0.4 if _lane == "host" else 0.0
	return rules
