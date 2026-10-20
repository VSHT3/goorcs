extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_budget_and_endpoints()
	_test_shortcuts_and_islands()
	_test_diagonals_and_ties()
	_test_captured_shortest_successors()
	_test_main_round_growth()
	if failures == 0:
		print("PASS: path budget, immutable endpoints, shortcuts, islands, diagonals, and route ties")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _test_budget_and_endpoints() -> void:
	var layout := PathLayout.new(Vector2i(4, 2), 2, Vector2i(0, 0), Vector2i(3, 0))
	var revision: int = layout.revision
	_check(not layout.place(layout.entrance) and not layout.erase(layout.base), "Endpoints cannot be edited")
	_check(not layout.place(Vector2i(-1, 0)) and not layout.place(Vector2i(4, 0)), "Out-of-board placement is rejected")
	_check(layout.revision == revision, "Rejected edits preserve retained-terrain revision")
	_check(layout.place(Vector2i(1, 0)) and layout.place(Vector2i(2, 0)), "Budget permits both connecting tiles")
	_check(layout.revision > revision, "Accepted placement invalidates retained terrain")
	revision = layout.revision
	_check(layout.is_ready() and layout.route.size() == 4, "Endpoints are traversable without spending budget")
	_check(not layout.place(Vector2i(1, 0)), "Duplicate placement does not spend a tile")
	_check(not layout.place(Vector2i(0, 1)) and layout.used_tiles() == 2, "Over-budget action leaves layout unchanged")
	_check(layout.revision == revision, "Duplicate and over-budget placements cannot invalidate retained terrain")
	_check(layout.erase(Vector2i(1, 0)) and not layout.is_ready(), "Deleting a bridge invalidates the route")
	_check(layout.place(Vector2i(1, 0)) and layout.is_ready(), "Removal refunds the tile budget")
	revision = layout.revision
	layout.clear()
	_check(layout.revision > revision, "Clear invalidates retained terrain on the same layout instance")
	_check(layout.used_tiles() == 0 and layout.route.is_empty() and layout.has_path(layout.base), "Clear removes path tiles but preserves endpoints")


func _test_shortcuts_and_islands() -> void:
	var layout := PathLayout.new(Vector2i(5, 4), 9, Vector2i(0, 1), Vector2i(4, 1))
	for x: int in range(5):
		layout.place(Vector2i(x, 0))
	_check(layout.is_ready() and layout.used_tiles() < layout.budget and layout.route.size() == 7, "Connected detour is valid with unused budget")
	for x: int in range(1, 4):
		layout.place(Vector2i(x, 1))
	_check(layout.route == [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)], "Adjacent tiles create a shortcut regardless of placement order")
	layout.place(Vector2i(2, 3))
	_check(not layout.is_ready() and layout.disconnected_count == 1 and layout.route.size() == 5, "Isolated tile invalidates readiness without hiding the reachable route")
	layout.erase(Vector2i(2, 3))
	_check(layout.is_ready(), "Removing the island restores readiness")
	layout.erase(Vector2i(2, 1))
	_check(layout.is_ready() and layout.route.size() == 7, "Erasing shortcut restores the longer route")


func _test_diagonals_and_ties() -> void:
	var layout := PathLayout.new(Vector2i(3, 3), 6, Vector2i(0, 0), Vector2i(2, 2))
	layout.place(Vector2i(1, 1))
	_check(layout.route.is_empty() and layout.disconnected_count == 1, "Corner touching is not a connection")
	layout = PathLayout.new(Vector2i(3, 3), 6, Vector2i(0, 1), Vector2i(2, 1))
	for x: int in range(3):
		layout.place(Vector2i(x, 0))
		layout.place(Vector2i(x, 2))
	_check(layout.route == [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1)], "Equal-length routes follow deterministic right/down/left/up tie order")


func _test_captured_shortest_successors() -> void:
	var layout := PathLayout.new(Vector2i(7, 5), 30, Vector2i(0, 2), Vector2i(6, 2))
	for cell: Vector2i in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(5, 2)]:
		layout.place(cell)
	for x: int in range(2, 5):
		layout.place(Vector2i(x, 1))
		layout.place(Vector2i(x, 3))
		layout.place(Vector2i(x, 0))
	var captured: Dictionary = layout.capture_routing()
	_check(captured["next"][Vector2i(2, 2)] == [Vector2i(2, 3), Vector2i(2, 1)], "Both equally short fork branches are captured in stable order")
	_check(captured["next"][Vector2i(2, 1)] == [Vector2i(3, 1)], "A connected but longer detour is not a shortest successor")
	_check(captured["next"][layout.base].is_empty(), "The base has no outgoing routing edge")
	layout.erase(Vector2i(4, 3))
	_check(captured["next"][Vector2i(2, 2)].size() == 2 and layout.capture_routing()["next"][Vector2i(2, 2)] == [Vector2i(2, 1)], "Capturing preserves the wave's fork after later layout edits")
	captured["next"][layout.entrance].clear()
	captured["route"].clear()
	_check(not layout.capture_routing()["next"][layout.entrance].is_empty() and not layout.route.is_empty(), "Captured dictionaries and route arrays cannot mutate the layout")


func _test_main_round_growth() -> void:
	var layout := PathLayout.new()
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 4))
	var original_route: Array[Vector2i] = layout.route.duplicate()
	for event: int in range(1, 4):
		var previous_width: int = layout.dimensions.x
		var revision: int = layout.revision
		layout.grow_for_main_round(6)
		_check(layout.revision > revision, "Growth invalidates retained terrain along with dimensions and endpoints")
		_check(layout.dimensions == Vector2i(14 + event, 9 + event * 2) and layout.budget == 30 + event * 6, "Each expansion adds one outer column, two rows and its explicit tile allowance")
		_check(layout.entrance == Vector2i(0, 4 + event) and layout.base == Vector2i(13, 4 + event), "Growth never shifts logical entrance/base x coordinates or adds a portal-side column")
		_check(layout.used_tiles() == 12 and layout.is_ready() and layout.route.size() == original_route.size(), "Expansion preserves placed tiles, connectivity and route length")
		for index: int in range(original_route.size()):
			_check(layout.route[index] - Vector2i(0, event) == original_route[index], "Growth reindexes only old path y coordinates")
		_check(layout.place(Vector2i(0, 0)) and layout.place(Vector2i(13, layout.dimensions.y - 1)), "New top and bottom rows are genuinely buildable")
		layout.erase(Vector2i(0, 0))
		layout.erase(Vector2i(13, layout.dimensions.y - 1))
		var retained_route: Array[Vector2i] = layout.route.duplicate()
		for x: int in range(14, layout.dimensions.x):
			_check(layout.place(Vector2i(x, layout.base.y)), "Every outer column beyond the stationary base accepts connected pavement")
		_check(layout.has_path(Vector2i(previous_width, layout.base.y)) and layout.is_ready() and layout.route == retained_route, "The newly added outer column is usable without moving the base or changing the existing route")
		for x: int in range(layout.dimensions.x - 1, 13, -1):
			layout.erase(Vector2i(x, layout.base.y))
		_check(not layout.contains(Vector2i(-1, layout.entrance.y)) and not layout.contains(Vector2i(layout.dimensions.x, layout.base.y)), "Growth leaves the portal-side boundary fixed and adds exactly one outer column")
		_check(not layout.erase(layout.entrance) and not layout.erase(layout.base), "Grown endpoints retain protection")
