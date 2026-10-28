extends "res://tests/match_multiplayer_worker.gd"
var _item_restore: Array[ItemDefinition] = []


func _new_session() -> void:
	_manual_simulation = true
	super._new_session()


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog = rules.catalog.duplicate(true) as ContentCatalog
	rules.roll_rules = null
	rules.base_health = 100
	rules.starting_coins = 20000 if _lane == "host" else 1
	rules.starting_reroll_currency = 10 if _lane == "host" else 0
	rules.enemy_health = 100000
	rules.health_growth = 0
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	var all_ids := PackedStringArray()
	for definition: ItemDefinition in rules.catalog.items:
		_item_restore.append(definition.duplicate(true) as ItemDefinition)
	for definition: ItemDefinition in rules.catalog.items:
		all_ids.append(String(definition.id))
		if _lane == "guest":
			definition.title = "Local divergent item"
			var parameters: Dictionary = definition.runtime.get("parameters", {})
			for key: Variant in parameters:
				if parameters[key] is float or parameters[key] is int:
					if String(key).contains("cost"):
						parameters[key] = 1
					elif String(key).contains("cooldown"):
						parameters[key] = 0.01
	if _lane == "host":
		rules.starting_items = [all_ids, PackedStringArray([
			"dabloons", "spore_spawn_of_marko", "worldroot_seed",
			"the_whole_shebang", "witchs_folded_ladder", "minute_hand_cannon",
			"bastion_in_a_bottle", "the_walking_fortress",
		])]
	else:
		rules.starting_items = [PackedStringArray(), PackedStringArray()]
	return rules


func _execute_command(command: Dictionary) -> void:
	var action: String = String(command.get("action", ""))
	match action:
		"item":
			_last_result = planning.item_command(int(command["slot"]), StringName(command["item"]), String(command["kind"]), int(command.get("target", -1)))
		"forged_item":
			if _lane == "guest":
				planning._receive_item_command.rpc_id(1, int(command["slot"]), String(command["item"]), String(command["kind"]), int(command.get("target", -1)))
			else:
				_last_result = planning._apply_item_command(1, int(command["slot"]), StringName(command["item"]), String(command["kind"]), int(command.get("target", -1)))
		"mutate_local_items":
			planning.combat_rules.starting_items = [PackedStringArray(), PackedStringArray()]
			for definition: ItemDefinition in planning.combat_rules.catalog.items:
				definition.title = "Edited after admission"
				definition.runtime.clear()
			_restore_item_definitions()
		"item_balances":
			if _session.is_host:
				var slot: int = int(command["slot"])
				planning._host_combat.coins[slot] = int(command["coins"])
				planning._host_combat.reroll_currency[slot] = int(command["shards"])
				planning._publish_snapshot()
		"item_clear_wave":
			if _session.is_host:
				var core: MatchCombat = planning._host_combat
				for slot: int in range(2):
					for enemy: Dictionary in core.enemies[slot].duplicate():
						core.item_damage(slot, int(enemy["id"]), 1000000000.0, &"physical", &"iron_arrowhead")
				planning._physics_process(0.01)
				planning._publish_snapshot()
		_:
			if action in ["leave", "quit"]:
				_restore_item_definitions()
			super._execute_command(command)
			return
	# Reuse the existing cross-process observation fence for accepted AND rejected
	# requests. A transport send alone does not prove the host has processed it.
	super._execute_command({"action": "fence"})


func _restore_item_definitions() -> void:
	if planning == null or _item_restore.is_empty():
		return
	planning.combat_rules.catalog.items.assign(_item_restore)
	_item_restore.clear()


func _publish() -> void:
	super._publish()
	if _lane != "host" or planning == null or planning._host_combat == null or _directory.is_empty() or _executing_command or _pending_fence != 0:
		return
	var core: MatchCombat = planning._host_combat
	var states: Array[String] = []
	for generator: RandomNumberGenerator in [core._random, core._wave_random, core._timing_random, core._group_random, core._roll_random, core._drop_random, core._magic_random, core._crit_random, core._variant_random, core.item_runtime.random]:
		states.append(str(generator.state))
	var file := FileAccess.open(_path("item_runtime") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"random_states": states}))
	file.close()
	DirAccess.rename_absolute(_path("item_runtime") + ".tmp", _path("item_runtime"))
