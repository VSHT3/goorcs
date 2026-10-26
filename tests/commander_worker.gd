extends "res://tests/match_branch_worker.gd"

class CommanderPlanning extends MatchPlanning:
	var fence_id: int = 0

	func _physics_process(_delta: float) -> void:
		pass

	func step(delta: float) -> void:
		super._physics_process(delta)

	@rpc("any_peer", "call_remote", "reliable")
	func command_fence(token: int) -> void:
		if session.is_host and multiplayer.get_remote_sender_id() == _active_peer_id:
			_publish_snapshot()
			accept_fence.rpc_id(_active_peer_id, token)

	@rpc("authority", "call_remote", "reliable")
	func accept_fence(token: int) -> void:
		if not session.is_host and multiplayer.get_remote_sender_id() == 1:
			fence_id = token


func _new_session() -> void:
	_session = MultiplayerSession.new()
	_session.name = "Session"
	_session.changed.connect(_publish)
	_main.add_child(_session)
	planning = CommanderPlanning.new()
	planning.name = "Planning"
	planning.session = _session
	planning.combat_rules = _planning_rules()
	planning.changed.connect(_on_planning_changed)
	if _lane == "guest":
		planning.configure(Vector2i(8, 5), 8, Vector2i(0, 2), Vector2i(7, 2))
	_main.add_child(planning)


func _planning_rules() -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	rules.roll_rules = null
	rules.base_health = 10000 if _lane == "host" else 1
	rules.starting_coins = 1000 if _lane == "host" else 1
	rules.enemy_health = 1000000
	rules.health_growth = 0
	rules.enemy_speed = 0.1 if _lane == "host" else 99.0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres").duplicate(true) as EnemyDefinition]
	for tower: TowerDefinition in rules.catalog.towers:
		if tower.reward.id == &"arrow_tower":
			tower.damage = 100 if _lane == "host" else 1
			tower.interval = 1.0 if _lane == "host" else 0.01
	return rules


func _on_planning_changed() -> void:
	# Selection and commitment are explicit peer gestures in this suite.
	pass


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"draft_seed":
			planning._draft_rng.seed = int(command["seed"])
		"guess":
			_last_result = planning.submit_commander_guess(int(command["value"]))
		"forge_guess":
			planning._receive_loadout_command.rpc_id(1, "guess", [command["value"]], [])
		"forge_deck":
			planning._receive_loadout_command.rpc_id(1, "select", ["arrow_tower"], ["arrow_tower"])
		"seed":
			if _session.is_host:
				planning._commander_rng.seed = int(command["seed"])
		"commander":
			_last_result = planning.select_commander(StringName(command["commander"]))
		"deck":
			_last_result = planning.select_loadout([&"arrow_tower"])
		"commit":
			_last_result = planning.commit_loadout()
		"ability":
			_last_result = planning.request_commander_ability(int(command["target"]))
		"obstacle":
			_last_result = planning.request_clear_obstacle(Vector2i(int(command["x"]), int(command["y"])))
		"grow":
			if _session.is_host:
				planning._grow_to_round(20)
				planning._publish_snapshot()
		"forged":
			var cell := Vector2i(int(command.get("x", 0)), int(command.get("y", 0)))
			var action: String = command["command"]
			var slot: int = int(command["slot"])
			var target: int = int(command.get("target", -1))
			if _session.is_host:
				_last_result = planning._apply_tower_command(1, action, slot, cell, -1, target, "")
			else:
				planning._receive_tower_command.rpc_id(1, action, slot, cell, -1, target, "")
		"forge_commander":
			planning._receive_loadout_command.rpc_id(1, "commander", [], [], String(command["commander"]))
		"tamper":
			if not _session.is_host:
				planning.combat["coins"][1] = 1000000
				planning.combat["commanders"][1]["cooldown_remaining"] = 0.0
				planning.combat["commanders"][1]["ability_remaining"] = 0.0
				planning.combat["commanders"][1]["obstacles"].append(Vector2i(int(command.get("x", 2)), int(command.get("y", 2))))
		"balance":
			if _session.is_host:
				planning._host_combat.coins[int(command["slot"])] = int(command["coins"])
				planning._publish_snapshot()
		"fence":
			if not _session.is_host:
				(planning as CommanderPlanning).command_fence.rpc_id(1, int(command["token"]))
		"step":
			if _session.is_host:
				(planning as CommanderPlanning).step(float(command["delta"]))
				planning._publish_snapshot()
		_:
			super._execute_command(command)


func _publish() -> void:
	if planning != null and not _directory.is_empty() and not _executing_command:
		var file := FileAccess.open(_path("commander") + ".tmp", FileAccess.WRITE)
		# Local test observation only; never included in a gameplay peer snapshot.
		var observed: Dictionary = {"selecting": planning.selecting_loadout, "chosen_commander": String(planning.chosen_commander_id), "commander_ids": planning.commander_ids, "commander_draft": planning.commander_draft, "committed": planning.loadout_committed, "chosen_deck": planning.chosen_tower_ids, "fence": (planning as CommanderPlanning).fence_id}
		if _session.is_host:
			observed["authority_target"] = planning._host_draft_target
		file.store_string(JSON.stringify(observed))
		file.close()
		DirAccess.rename_absolute(_path("commander") + ".tmp", _path("commander"))
	super._publish()
