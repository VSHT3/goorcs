extends "res://tests/match_planning_worker.gd"


func _planning_rules() -> CombatRules:
	return preload("res://resources/combat/prototype.tres").duplicate(true) as CombatRules


func _on_planning_changed() -> void:
	# This worker's callers exercise selection/commit explicitly.
	pass


func _new_session() -> void:
	super._new_session()
	var ids: Array = []
	for reward: TowerReward in planning.combat_rules.catalog.tower_rewards():
		ids.append(String(reward.id))
	_set_owned(ids)


func _set_owned(ids: Array) -> void:
	var save_path: String = _directory.path_join(_lane + ".collection.json")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": CollectionStore.SAVE_VERSION, "unlocked": ids}))
	file.close()
	planning.collection_store = CollectionStore.new(save_path, planning.combat_rules.catalog)


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"select":
			_last_result = planning.select_loadout(command.get("ids", []))
		"commit":
			_last_result = planning.commit_loadout()
		"reroll":
			_last_result = planning.reroll_tower(int(command["slot"]), int(command["tower_id"]), String(command["kind"]))
		"set_owned":
			_set_owned(command.get("ids", []))
			_last_result = planning.collection_store.error_message.is_empty()
		"debug":
			_last_result = planning.debug_set_values(int(command["round"]), int(command["money"]), int(command["shards"]))
		"authenticated_select":
			if _session.is_host:
				_last_result = planning._apply_loadout_command(1, "select", command.get("ids", []), command.get("owned", []))
			else:
				planning._receive_loadout_command.rpc_id(1, "select", command.get("ids", []), command.get("owned", []))
				_last_result = true
		"authenticated_build":
			var cell := Vector2i(int(command["x"]), int(command["y"]))
			if _session.is_host:
				_last_result = planning._apply_tower_command(1, "build", int(command["slot"]), cell, -1, int(command.get("mode", 0)), String(command["type_id"]))
			else:
				planning._receive_tower_command.rpc_id(1, "build", int(command["slot"]), cell, -1, int(command.get("mode", 0)), String(command["type_id"]))
				_last_result = true
		_:
			super._execute_command(command)


func _publish() -> void:
	super._publish()
	if planning == null or _directory.is_empty() or _executing_command:
		return
	var file := FileAccess.open(_path("gameplay") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"active": planning.active,
		"selecting_loadout": planning.selecting_loadout,
		"chosen_tower_ids": planning.chosen_tower_ids,
		"loadout_committed": planning.loadout_committed,
		"opponent_committed": planning.opponent_committed,
		"combat": planning.combat,
	}))
	file.close()
	DirAccess.rename_absolute(_path("gameplay") + ".tmp", _path("gameplay"))
