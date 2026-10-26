extends "res://tests/match_branch_worker.gd"


func _fixture_reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = super._fixture_reserved_cells()
	# These original-board cells move with the normal late-round expansion.
	cells.append_array([Vector2i(5, 0), Vector2i(2, 1)])
	return cells


func _planning_rules() -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	rules.roll_rules = null
	rules.base_health = 10000
	rules.starting_coins = 100000
	rules.enemy_health = 1000
	rules.health_growth = 0
	rules.enemy_speed = 0.05
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 1000.0
	rules.spawn_jitter_ratio = 0.0
	if _lane == "guest":
		for enemy: EnemyDefinition in rules.catalog.enemies:
			if enemy.id == &"skeleorc":
				enemy.spawn_variant_chance = 1.0
			if enemy.id == &"giant_skeltorc":
				enemy.health_base_multiplier = 2
				enemy.speed_multiplier = 9.0
				enemy.fire_immune = false
				enemy.ice_immune = false
				enemy.death_bomb_fuse = 0.05
				enemy.death_bomb_radius = 0.1
				enemy.death_bomb_stun_duration = 0.05
			if enemy.id == &"kamikaorc":
				enemy.hit_shield = 2
				enemy.death_stun_radius = 0.1
				enemy.death_stun_duration = 0.05
	return rules


func _execute_command(command: Dictionary) -> void:
	var action: String = String(command.get("action", ""))
	if action == "late_round":
		if _lane == "host":
			planning._set_debug_values(152, 100000, 0)
	elif action == "late_births":
		if _lane == "host":
			var core: MatchCombat = planning._host_combat
			for slot: int in range(2):
				var random := RandomNumberGenerator.new()
				var winning_seed: int = 0
				for seed_value: int in range(100000):
					random.seed = seed_value
					if random.randf() < 0.01:
						winning_seed = seed_value
						break
				core._variant_random.seed = winning_seed
				core._spawn_enemy(slot, "skeleorc", 2.0, core._elapsed)
				core._spawn_enemy(slot, "kamikaorc", 2.0, core._elapsed)
				core._spawn_enemy(slot, "necorcmancer", 2.5, core._elapsed)
				for tower: Dictionary in core.towers[slot]:
					tower["cooldown"] = 10000.0
			planning._publish_snapshot()
	elif action == "late_hits":
		if _lane == "host":
			var core: MatchCombat = planning._host_combat
			for slot: int in range(2):
				for hit: int in range(int(command["count"])):
					var index: int = _index(core, slot, "kamikaorc")
					if index >= 0:
						core._hit(slot, core.towers[slot][0], index, 1000000)
			planning._publish_snapshot()
	elif action == "late_giant_death":
		if _lane == "host":
			var core: MatchCombat = planning._host_combat
			var slot: int = int(command["slot"])
			var index: int = _index(core, slot, "giant_skeltorc")
			if index >= 0:
				core._hit(slot, core.towers[slot][0], index, 100000000)
			planning._publish_snapshot()
	else:
		super._execute_command(command)


func _index(core: MatchCombat, slot: int, type_id: String) -> int:
	for index: int in range(core.enemies[slot].size()):
		if core.enemies[slot][index]["type_id"] == type_id:
			return index
	return -1
