extends "res://tests/multiplayer_session_worker.gd"

var planning: MatchPlanning
var _loadout_select_sent: bool = false
var _loadout_commit_sent: bool = false
var _requested_loadout: Array[StringName] = []


func _new_session() -> void:
	super._new_session()
	planning = MatchPlanning.new()
	planning.name = "Planning"
	planning.session = _session
	planning.combat_rules = _planning_rules()
	planning.changed.connect(_on_planning_changed)
	# Different guest defaults prove that the host supplies match settings.
	if _lane == "guest":
		planning.configure(Vector2i(8, 5), 8, Vector2i(0, 2), Vector2i(7, 2))
	_main.add_child(planning)


func _planning_rules() -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true) as CombatRules
	rules.roll_rules = null
	return rules


func _process(delta: float) -> bool:
	if planning != null and _session.state == MultiplayerSession.State.CONNECTED and not planning.active and Time.get_ticks_msec() < _deadline_msec:
		var command: Dictionary = _read_json(_path("command"))
		var action: String = String(command.get("action", ""))
		if int(command.get("id", 0)) > _command_id and action in ["edit", "clear", "ready", "build", "target", "upgrade", "sell", "send", "debug", "step"]:
			# Transport admission precedes both explicit deck commits. Keep this
			# command pending until gameplay is admitted, then dispatch it once.
			_publish()
			return false
	return super._process(delta)


func _on_planning_changed() -> void:
	if not planning.selecting_loadout:
		_loadout_select_sent = false
		_loadout_commit_sent = false
		_requested_loadout.clear()
		return
	if planning.loadout_committed:
		return
	if not _loadout_select_sent:
		_requested_loadout.clear()
		for definition: TowerDefinition in planning.combat_rules.catalog.towers:
			if definition.reward.id in [&"arrow_tower", &"orc_ballista", &"rune_obelisk"]:
				_requested_loadout.append(definition.reward.id)
		# Own the pending request before the host's synchronous changed emission.
		_loadout_select_sent = true
		if not planning.select_loadout(_requested_loadout):
			push_error("Peer fixture could not select its explicit registered deck")
		return
	# Remote selection is asynchronous: only an accepted owner snapshot enables commit.
	if not _loadout_commit_sent and planning.chosen_tower_ids == _requested_loadout:
		_loadout_commit_sent = true
		if not planning.commit_loadout():
			push_error("Peer fixture could not commit its accepted deck")


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"edit":
			planning.request_edit(int(command["slot"]), Vector2i(int(command["x"]), int(command["y"])), bool(command.get("place", true)))
		"clear":
			planning.request_clear(int(command["slot"]))
		"ready":
			planning.submit_ready(bool(command["value"]))
		"build":
			planning.build_tower(int(command["slot"]), Vector2i(int(command["x"]), int(command["y"])), StringName(command["type_id"]), int(command["mode"]))
		"target":
			planning.set_targeting(int(command["slot"]), int(command["tower_id"]), int(command["mode"]))
		"upgrade":
			planning.upgrade_tower(int(command["slot"]), int(command["tower_id"]), String(command["upgrade"]))
		"sell":
			planning.sell_tower(int(command["slot"]), int(command["tower_id"]))
		"send":
			planning.send_enemy(int(command["slot"]), StringName(command["type_id"]))
		_:
			super._execute_command(command)


func _publish() -> void:
	if planning == null:
		super._publish()
		return
	if _directory.is_empty() or _executing_command:
		return
	var boards: Array = []
	for layout: PathLayout in planning.layouts:
		var tiles: Array = []
		for y: int in range(layout.dimensions.y):
			for x: int in range(layout.dimensions.x):
				var cell := Vector2i(x, y)
				if layout.has_path(cell) and not layout.is_endpoint(cell):
					tiles.append([x, y])
		boards.append({"tiles": tiles, "legal": layout.is_ready(), "used": layout.used_tiles(), "route": _cells(layout.route)})
	var routes: Array = []
	for route: Array in planning.locked_routes:
		routes.append(_cells(route))
	var file := FileAccess.open(_path("planning") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"active": planning.active, "locked": planning.locked, "flags": planning.ready_flags, "boards": boards, "routes": routes, "combat": planning.combat}))
	file.close()
	DirAccess.rename_absolute(_path("planning") + ".tmp", _path("planning"))
	# Publish accepted planning state before exposing the command acknowledgement.
	super._publish()


func _cells(cells: Array) -> Array:
	var result: Array = []
	for cell: Vector2i in cells:
		result.append([cell.x, cell.y])
	return result
