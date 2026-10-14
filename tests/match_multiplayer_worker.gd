extends "res://tests/match_planning_worker.gd"


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 2
	rules.enemy_health = 4
	rules.health_growth = 0
	rules.enemies_per_wave = 1
	rules.enemy_speed = 6.5
	rules.spawn_interval = 0.05
	rules.tower_damage = 99
	rules.tower_range = 1.5
	rules.tower_interval = 0.05
	if _lane == "guest":
		rules.base_health = 7
	return rules
