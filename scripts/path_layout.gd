class_name PathLayout
extends RefCounted

# Stable ordering for the workshop's representative route and combat fork choices.
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var dimensions: Vector2i
var entrance: Vector2i
var base: Vector2i
var budget: int
var route: Array[Vector2i] = []
var disconnected_count: int = 0
var _tiles: Dictionary[Vector2i, bool] = {}


func _init(board_size: Vector2i = Vector2i(14, 9), tile_budget: int = 30,
		entry_cell: Vector2i = Vector2i(0, 4), base_cell: Vector2i = Vector2i(13, 4)) -> void:
	assert(board_size.x > 1 and board_size.y > 0 and tile_budget >= 0)
	dimensions = board_size
	budget = tile_budget
	entrance = entry_cell
	base = base_cell
	assert(contains(entrance) and contains(base) and entrance != base)
	_recalculate()


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y


func is_endpoint(cell: Vector2i) -> bool:
	return cell == entrance or cell == base


func has_path(cell: Vector2i) -> bool:
	return is_endpoint(cell) or _tiles.has(cell)


func used_tiles() -> int:
	return _tiles.size()


func is_ready() -> bool:
	return not route.is_empty() and disconnected_count == 0


func place(cell: Vector2i) -> bool:
	if not contains(cell) or has_path(cell) or used_tiles() >= budget:
		return false
	_tiles[cell] = true
	_recalculate()
	return true


func erase(cell: Vector2i) -> bool:
	if not _tiles.erase(cell):
		return false
	_recalculate()
	return true


func clear() -> void:
	_tiles.clear()
	_recalculate()


func capture_routing() -> Dictionary:
	var next_cells: Dictionary[Vector2i, Array] = {}
	if not is_ready():
		return {"route": [], "next": next_cells}
	# Distance to the base makes every successor a strictly shorter remaining path.
	var distance: Dictionary[Vector2i, int] = {base: 0}
	var frontier: Array[Vector2i] = [base]
	var cursor: int = 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if contains(neighbor) and has_path(neighbor) and not distance.has(neighbor):
				distance[neighbor] = distance[current] + 1
				frontier.append(neighbor)
	for cell: Vector2i in frontier:
		var successors: Array[Vector2i] = []
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if distance.has(neighbor) and distance[neighbor] == distance[cell] - 1:
				successors.append(neighbor)
		next_cells[cell] = successors
	return {"route": route.duplicate(), "next": next_cells}


func _recalculate() -> void:
	route.clear()
	var frontier: Array[Vector2i] = [entrance]
	var parents: Dictionary[Vector2i, Vector2i] = {entrance: entrance}
	var cursor: int = 0
	# Traverse all reachable tiles, not just the base, to identify isolated islands.
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if contains(neighbor) and has_path(neighbor) and not parents.has(neighbor):
				parents[neighbor] = current
				frontier.append(neighbor)
	disconnected_count = 0
	for cell: Vector2i in _tiles:
		if not parents.has(cell):
			disconnected_count += 1
	if not parents.has(base):
		return
	var cell: Vector2i = base
	while cell != entrance:
		route.append(cell)
		cell = parents[cell]
	route.append(entrance)
	route.reverse()
