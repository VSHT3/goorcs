extends SceneTree

var failures: int = 0


func _init() -> void:
	_test_budget_and_endpoints()
	_test_shortcuts_and_islands()
	_test_diagonals_and_ties()
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
