extends "res://tests/match_planning_worker.gd"

var _manual_simulation: bool = false


func _new_session() -> void:
	super._new_session()
	planning.changed.connect(func() -> void:
		if _manual_simulation:
			planning.set_physics_process(false)
	)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.roll_rules = null
	rules.catalog.towers = [
		preload("res://resources/combat/towers/arrow_tower.tres").duplicate(true) as TowerDefinition,
		preload("res://resources/combat/towers/orc_ballista.tres").duplicate(true) as TowerDefinition,
		preload("res://resources/combat/towers/rune_obelisk.tres").duplicate(true) as TowerDefinition,
	]
	rules.base_health = 2
	rules.enemy_health = 4
	rules.health_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight_growth = 0
	rules.wave_weight = 1
	rules.enemy_speed = 6.5
	rules.spawn_interval = 0.05
	rules.spawn_interval_reduction_per_wave = 0.0
	var definitions: Array[TowerDefinition] = []
	for source: TowerDefinition in rules.catalog.towers:
		var definition := source.duplicate(true) as TowerDefinition
		# Preserve authored roles and metadata while isolating attacking scenario stats.
		if definition.behavior_kind in ["attack", "chain"]:
			definition.damage = 1 if _lane == "guest" else 99
			definition.range_cells = 0.5 if _lane == "guest" else 1.5
			definition.interval = 5.0 if _lane == "guest" else 0.05
		definition.special_upgrade_cost = 1 if _lane == "guest" else source.special_upgrade_cost
		if _lane == "guest":
			for branch: Dictionary in definition.evolutions.values():
				branch["cost"] = 1
				if branch.has("damage"):
					branch["damage"] = 99
				if branch.has("followup"):
					branch["followup"]["cost"] = 1
		definitions.append(definition)
	rules.catalog.towers = definitions
	var enemy_definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		if source.id not in [&"grunt", &"runner", &"brute"]:
			continue
		var definition := source.duplicate() as EnemyDefinition
		definition.send_first_wave = 1
		if _lane == "guest":
			definition.health_multiplier = 9.0
			definition.speed_multiplier = 0.1
			definition.send_cost = 1
			definition.send_income = 99
		enemy_definitions.append(definition)
	rules.catalog.enemies = enemy_definitions
	if _lane == "guest":
		rules.base_health = 7
		rules.starting_coins = 999
		rules.kill_bounty = 99
		rules.wave_reward = 99
		rules.wave_reward_growth = 99
	return rules


func _execute_command(command: Dictionary) -> void:
	var action: String = String(command.get("action", ""))
	if action == "special_scenario":
		var rules: CombatRules = _planning_rules()
		rules.starting_coins = 2000 if _lane == "host" else 1
		rules.base_health = 100
		rules.enemy_health = 100
		rules.enemy_speed = 0.0
		_manual_simulation = true
		planning.set_physics_process(false)
		planning.combat_rules = rules
		return
	if action in ["send_scenario", "typed_send_scenario", "stream_scenario"]:
		var rules: CombatRules = _planning_rules()
		var typed: bool = action == "typed_send_scenario"
		rules.base_health = (12 if typed else 6) if _lane == "host" else 99
		rules.starting_coins = (200 if typed else 45) if _lane == "host" else 999
		rules.health_growth = 2
		rules.enemy_speed = 2.0
		_manual_simulation = true
		planning.set_physics_process(false)
		rules.send_spawn_interval = (0.35 if typed else 0.25) if _lane == "host" else 99.0
		if action == "stream_scenario":
			rules.base_health = 20
			rules.starting_coins = 400
			rules.wave_weight = 2
			rules.enemy_speed = 26.0 if _lane == "host" else 0.01
			rules.spawn_interval = 1.0
			rules.spawn_jitter_ratio = 0.0
			rules.send_spawn_interval = 1.0 if _lane == "host" else 99.0
			rules.spawn_interval_reduction_per_wave = 0.005 if _lane == "host" else 0.25
			rules.max_spawn_interval_reduction = 0.5 if _lane == "host" else 0.9
		planning.combat_rules = rules
	elif action == "debug":
		_last_result = planning.debug_set_values(int(command["round"]), int(command["money"]), int(command["shards"]))
	elif action == "step":
		if _lane == "host":
			planning._physics_process(float(command["delta"]))
			planning._publish_snapshot()
	else:
		super._execute_command(command)


func _publish() -> void:
	super._publish()
	if planning == null or planning._host_combat == null or _directory.is_empty() or _executing_command or _lane != "host":
		return
	var core: MatchCombat = planning._host_combat
	var states: Array[String] = []
	for generator: RandomNumberGenerator in [core._random, core._wave_random, core._timing_random, core._group_random, core._roll_random, core._drop_random]:
		states.append(str(generator.state))
	var file := FileAccess.open(_path("debug_runtime") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"elapsed": core._elapsed, "random_states": states}))
	file.close()
	DirAccess.rename_absolute(_path("debug_runtime") + ".tmp", _path("debug_runtime"))
