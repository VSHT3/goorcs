extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_budget_and_endpoints()
	_test_shortcuts_and_islands()
	_test_diagonals_and_ties()
	_test_captured_shortest_successors()
	_test_vertical_growth()
	if failures == 0:
		print("PASS: path budget, immutable endpoints, shortcuts, islands, diagonals, and route ties")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _test_budget_and_endpoints() -> void:
	var layout := PathLayout.new(Vector2i(4, 2), 2, Vector2i(0, 0), Vector2i(3, 0))
	_check(not layout.place(layout.entrance) and not layout.erase(layout.base), "Endpoints cannot be edited")
	_check(not layout.place(Vector2i(-1, 0)) and not layout.place(Vector2i(4, 0)), "Out-of-board placement is rejected")
	_check(layout.place(Vector2i(1, 0)) and layout.place(Vector2i(2, 0)), "Budget permits both connecting tiles")
	_check(layout.is_ready() and layout.route.size() == 4, "Endpoints are traversable without spending budget")
	_check(not layout.place(Vector2i(1, 0)), "Duplicate placement does not spend a tile")
	_check(not layout.place(Vector2i(0, 1)) and layout.used_tiles() == 2, "Over-budget action leaves layout unchanged")
	_check(layout.erase(Vector2i(1, 0)) and not layout.is_ready(), "Deleting a bridge invalidates the route")
	_check(layout.place(Vector2i(1, 0)) and layout.is_ready(), "Removal refunds the tile budget")
	layout.clear()
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


func _test_vertical_growth() -> void:
	var layout := PathLayout.new(Vector2i(5, 5), 12, Vector2i(0, 2), Vector2i(4, 2))
	for x: int in range(1, 4):
		layout.place(Vector2i(x, 2))
	var original_route: Array[Vector2i] = layout.route.duplicate()
	for event: int in range(1, 4):
		layout.grow_vertical(6)
		_check(layout.dimensions == Vector2i(5, 5 + event * 2) and layout.budget == 12 + event * 6, "Each expansion adds two rows and its explicit tile allowance")
		_check(layout.used_tiles() == 3 and layout.is_ready() and layout.route.size() == original_route.size(), "Expansion preserves placed tiles, connectivity and route length")
		for index: int in range(original_route.size()):
			_check(layout.route[index] - Vector2i(0, event) == original_route[index], "Moving the world origin up cancels logical coordinate shifts")
		_check(layout.place(Vector2i(0, 0)) and layout.place(Vector2i(4, layout.dimensions.y - 1)), "New top and bottom rows are genuinely buildable")
		layout.erase(Vector2i(0, 0))
		layout.erase(Vector2i(4, layout.dimensions.y - 1))
		_check(not layout.erase(layout.entrance) and not layout.erase(layout.base), "Grown endpoints retain protection")
