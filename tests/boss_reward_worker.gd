extends "res://tests/match_branch_worker.gd"

func _fixture_reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(6):
		cells.append(Vector2i(x, 2))
	cells.append(Vector2i(1, 0))
	return cells

func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.boss_reward_rules = load("res://resources/combat/boss_rewards.tres").duplicate(true) as BossRewardRules
	rules.starting_coins = 10000
	rules.base_health = 10000
	rules.enemy_speed = 0.01
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	if _lane == "guest":
		# Valid local disagreement must not decide another authoritative reward.
		for rarity: String in rules.boss_reward_rules.payouts:
			rules.boss_reward_rules.payouts[rarity] *= 7
	return rules

func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"round_fixture":
			if _lane == "host":
				planning._set_debug_values(int(command["round"]), 10000, int(planning.combat["reroll_currency"][0]))
		"boss_hit_fixture":
			if _session.is_host:
				var model: MatchCombat = planning._host_combat
				var slot: int = int(command["slot"])
				for index: int in range(model.enemies[slot].size()):
					if model.enemies[slot][index]["type_id"] == "necorcmancer_mancer":
						model._hit(slot, model.towers[slot][0], index, 10000000)
						break
				planning._publish_snapshot()
		_:
			super._execute_command(command)
