extends "res://tests/match_branch_worker.gd"


func _new_session() -> void:
	_session = MultiplayerSession.new()
	_session.name = "Session"
	_session.changed.connect(_publish)
	_main.add_child(_session)
	planning = ManualPlanning.new()
	planning.name = "Planning"
	planning.session = _session
	planning.combat_rules = _planning_rules()
	planning.changed.connect(_on_planning_changed)
	if _lane == "host":
		planning.configure(Vector2i(14, 5), 68, Vector2i(0, 2), Vector2i(13, 2))
	_main.add_child(planning)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog = rules.catalog.duplicate(true) as ContentCatalog
	rules.roll_rules = null
	rules.base_health = 100000
	rules.starting_coins = 100000
	rules.enemy_health = 10000
	rules.health_growth = 0
	rules.enemy_speed = 0.02
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	rules.main_round_interval = 1000
	for definition: EnemyDefinition in rules.catalog.enemies:
		if definition.id == &"orc_war_machine":
			# Keep late movement observable without waiting through the normal slow speed.
			definition.speed_multiplier = 50.0
		if _lane == "guest" and definition.id in [&"troll", &"orc_war_machine"]:
			definition.health_multiplier = 0.1
			definition.speed_multiplier = 100.0
			definition.first_wave = 1
			definition.send_enabled = true
			definition.send_first_wave = 1
			definition.nonphysical_damage_multiplier = 9.0
			definition.tower_attack_interval = 0.01
			definition.tower_attack_cast_duration = 0.01
			definition.tower_stun_duration = 0.01
			definition.stomp_interval = 0.01 if definition.id == &"troll" else 0.0
			definition.road_speed_multiplier = 9.0
			definition.grass_speed_multiplier = 9.0
			definition.jump_charge_duration = 0.01
			definition.jump_duration = 0.01
			if definition.id == &"orc_war_machine":
				definition.summon_interval = 0.01
				definition.summon_cast_duration = 0.01
				definition.summon_weights = PackedInt32Array([1, 8, 1])
	if _lane == "guest":
		rules.enemy_health = 999
		rules.enemy_speed = 99.0
		for definition: TowerDefinition in rules.catalog.towers:
			definition.damage = 999
			definition.damage_type = &"physical"
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"round_fixture":
			if _lane == "host":
				var combat: MatchCombat = planning._host_combat
				var streams: Array[RandomNumberGenerator] = [combat._random, combat._wave_random, combat._timing_random, combat._group_random, combat._roll_random, combat._drop_random]
				for index: int in range(streams.size()):
					streams[index].seed = 1471 + index * 97
				planning.debug_set_values(int(command["round"]), 100000, int(planning.combat["reroll_currency"][planning.local_slot()]))
		"typed_damage_fixture":
			if _lane == "host":
				var combat: MatchCombat = planning._host_combat
				for slot: int in range(2):
					for index: int in range(combat.enemies[slot].size()):
						if combat.enemies[slot][index]["type_id"] == "troll":
							combat._hit(slot, combat.towers[slot][0], index, 20, false, StringName(command["kind"]))
				planning._publish_snapshot()
		"retire_boss_fixture":
			if _lane == "host":
				var combat: MatchCombat = planning._host_combat
				for slot: int in range(2):
					for index: int in range(combat.enemies[slot].size() - 1, -1, -1):
						if combat.enemies[slot][index]["type_id"] == String(command["type_id"]) and not combat.towers[slot].is_empty():
							combat._hit(slot, combat.towers[slot][0], index, 100000000)
				planning._publish_snapshot()
		_:
			super._execute_command(command)
