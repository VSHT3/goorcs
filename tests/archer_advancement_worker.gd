extends "res://tests/match_multiplayer_worker.gd"
func _planning_rules() -> CombatRules:
	_manual_simulation = true
	var rules := CombatRules.new()
	rules.starting_coins = 10000
	rules.base_health = 1000
	rules.enemy_health = 400
	rules.health_growth = 0
	rules.enemy_speed = 0.01
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 6
	rules.spawn_interval = 0.0
	var enemy: EnemyDefinition = rules.catalog.enemies[0].duplicate() as EnemyDefinition
	enemy.send_first_wave = 1
	rules.catalog.enemies = [enemy]
	var tower: TowerDefinition = rules.catalog.towers[0].duplicate(true) as TowerDefinition
	tower.range_cells = 20.0
	if _lane == "guest":
		tower.damage = 99
		for branch: Dictionary in tower.advancements.values(): branch["cost"] = 1
	rules.catalog.towers = [tower]
	return rules

func _execute_command(command: Dictionary) -> void:
	var action: String = command.get("action","")
	if action in ["target_archer_3","target_archer_4"]:
		planning.set_archer_targeting(int(command["slot"]),int(command["tower_id"]),2 if action=="target_archer_3" else 3,int(command["mode"]))
	else:
		super._execute_command(command)
