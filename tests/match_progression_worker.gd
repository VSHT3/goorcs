extends "res://tests/match_planning_worker.gd"


func _new_session() -> void:
	super._new_session()
	# Real peers exchange every accepted state; only elapsed time is manual.
	planning.changed.connect(_freeze_clock)


func _freeze_clock() -> void:
	planning.set_physics_process(false)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 1000
	rules.starting_coins = 2000
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition]
	rules.catalog.enemies[0].send_first_wave = 1
	rules.enemy_speed = 26.0
	rules.speed_growth = 0.0
	rules.health_growth = 0
	rules.spawn_interval = 0.0
	var tower := rules.catalog.towers[0].duplicate() as TowerDefinition
	tower.range_cells = 0.1
	rules.catalog.towers = [tower]
	if _lane == "guest":
		# Neither local tuning nor elapsed-time calls may decide host outcomes.
		rules.main_round_interval = 3
		rules.ready_window_seconds = 1.0
		rules.tiles_per_expansion = 99
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"advance":
			planning._physics_process(float(command["seconds"]))
		"pacing":
			planning.request_pacing(String(command["option"]), bool(command["enabled"]))
		"advance_to_strategy":
			if _session.is_host:
				for tick: int in range(40):
					if planning._host_combat.phase != MatchCombat.Phase.WAVE:
						break
					planning._physics_process(1.0)
		"repeat_planning":
			if _session.is_host:
				planning._enter_planning()
				planning._publish_snapshot()
				planning._publish_snapshot()
		"forged_ready":
			planning._request_command("ready", int(command["slot"]), Vector2i.ZERO, true)
		_:
			super._execute_command(command)
	_freeze_clock()


func _publish() -> void:
	super._publish()
	if planning == null or _directory.is_empty() or _executing_command:
		return
	var boards: Array = []
	for layout: PathLayout in planning.layouts:
		boards.append({"dimensions": [layout.dimensions.x, layout.dimensions.y], "budget": layout.budget, "entrance": [layout.entrance.x, layout.entrance.y], "base": [layout.base.x, layout.base.y]})
	var permissions: Array = []
	for slot: int in range(2):
		permissions.append({"path": planning.can_edit_path(slot), "towers": planning.can_manage_towers(slot)})
	var file := FileAccess.open(_path("progression") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"board_settings": boards, "permissions": permissions}))
	file.close()
	DirAccess.rename_absolute(_path("progression") + ".tmp", _path("progression"))
