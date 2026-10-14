extends "res://tests/multiplayer_session_worker.gd"

var planning: MatchPlanning


func _new_session() -> void:
	super._new_session()
	planning = MatchPlanning.new()
	planning.name = "Planning"
	planning.session = _session
	planning.combat_rules = _planning_rules()
	# Different guest defaults prove that the host supplies match settings.
	if _lane == "guest":
		planning.configure(Vector2i(8, 5), 8, Vector2i(0, 2), Vector2i(7, 2))
	_main.add_child(planning)


func _planning_rules() -> CombatRules:
	return preload("res://resources/combat/prototype.tres")


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
			planning.send_enemy(int(command["slot"]))
		_:
			super._execute_command(command)


func _publish() -> void:
	super._publish()
	if planning == null or _directory.is_empty() or _executing_command:
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


func _cells(cells: Array) -> Array:
	var result: Array = []
	for cell: Vector2i in cells:
		result.append([cell.x, cell.y])
	return result
