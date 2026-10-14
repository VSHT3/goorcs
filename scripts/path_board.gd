class_name PathBoard
extends Control

signal edited
signal feedback(message: String)
signal edit_requested(cell: Vector2i, place: bool)
signal cell_clicked(cell: Vector2i, button: MouseButton)

const GROUND := Color("222c2b")
const TILE := Color("6e7465")
const ENEMY_BLEND_DURATION: float = 0.1
const ROUTE_LINE := Color("b5e2b7")
const ENTRY_COLOR := Color("e0bc77")
const BASE_COLOR := Color("96c8dc")
const ARROW_REWARD: TowerReward = preload("res://resources/collection/arrow_tower.tres")
const SHOT_DURATION: float = 0.18

var layout: PathLayout
var command_mode: bool = false
var mirror_horizontal: bool = false
var cell_click_mode: bool = false:
	set(value):
		if cell_click_mode != value:
			cancel_stroke()
		cell_click_mode = value
var combat_towers: Array = []:
	set(value):
		combat_towers = value
		_capture_shots()
		queue_redraw()
var combat_enemies: Array = []:
	# Only presentation state is blended; accepted enemy dictionaries stay untouched.
	set(value):
		combat_enemies = value
		_blend_enemies()
		set_process(not combat_enemies.is_empty() or not _shot_traces.is_empty())
		queue_redraw()
var selected_tower_id: int = -1
var tower_range: float = 3.0
var enemy_route: Array = []
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		if not value:
			cancel_stroke()
var _hover := Vector2i(-1, -1)
var _paint_button: MouseButton = MOUSE_BUTTON_NONE
var _last_painted := Vector2i(-1, -1)
var _seen_shots: Dictionary = {}
var _shot_traces: Array[Dictionary] = []
var _enemy_progress: Dictionary[int, Vector2] = {}
var _enemy_blend_elapsed: float = ENEMY_BLEND_DURATION


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	set_process(not combat_enemies.is_empty() or not _shot_traces.is_empty())


func _process(delta: float) -> void:
	_enemy_blend_elapsed = minf(_enemy_blend_elapsed + delta, ENEMY_BLEND_DURATION)
	for index: int in range(_shot_traces.size() - 1, -1, -1):
		_shot_traces[index]["life"] -= delta
		if float(_shot_traces[index]["life"]) <= 0.0:
			_shot_traces.remove_at(index)
	queue_redraw()
	if _shot_traces.is_empty() and combat_enemies.is_empty():
		set_process(false)


func _capture_shots() -> void:
	if combat_towers.is_empty():
		_seen_shots.clear()
		_shot_traces.clear()
		set_process(not combat_enemies.is_empty())
		return
	for tower: Dictionary in combat_towers:
		var tower_id: int = int(tower["id"])
		var shot: int = int(tower["shot"])
		if shot > int(_seen_shots.get(tower_id, 0)):
			_shot_traces.append({
				"cell": tower["cell"],
				"aim": tower["aim"],
				"life": SHOT_DURATION,
			})
			set_process(true)
		_seen_shots[tower_id] = shot


func _blend_enemies() -> void:
	var next_progress: Dictionary[int, Vector2] = {}
	for enemy: Dictionary in combat_enemies:
		var id: int = int(enemy["id"])
		var target: float = float(enemy["progress"])
		var previous: Vector2 = _enemy_progress.get(id, Vector2(target, target))
		var displayed: float = lerpf(previous.x, previous.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
		next_progress[id] = Vector2(displayed, target)
	_enemy_progress = next_progress
	_enemy_blend_elapsed = 0.0


func _enemy_position(enemy: Dictionary) -> Vector2:
	if enemy_route.size() < 2:
		return enemy["pos"]
	var blend: Vector2 = _enemy_progress.get(int(enemy["id"]), Vector2(enemy["progress"], enemy["progress"]))
	var progress: float = clampf(lerpf(blend.x, blend.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION), 0.0, enemy_route.size() - 1)
	var index: int = mini(floori(progress), enemy_route.size() - 2)
	return Vector2(enemy_route[index]).lerp(Vector2(enemy_route[index + 1]), progress - index)


func cell_center(cell: Vector2i) -> Vector2:
	return _position_center(Vector2(cell))


func _position_center(position: Vector2) -> Vector2:
	if mirror_horizontal:
		position.x = layout.dimensions.x - 1 - position.x
	return _board_origin() + (position + Vector2(0.5, 0.5)) * _cell_size()


func _cell_size() -> float:
	return floorf(minf(size.x / layout.dimensions.x, size.y / layout.dimensions.y))


func _board_origin() -> Vector2:
	return (size - Vector2(layout.dimensions) * _cell_size()) * 0.5


func _cell_at(position: Vector2) -> Vector2i:
	var cell := Vector2i(((position - _board_origin()) / _cell_size()).floor())
	if mirror_horizontal:
		cell.x = layout.dimensions.x - 1 - cell.x
	return cell


func _gui_input(event: InputEvent) -> void:
	if layout == null or not input_enabled:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
			return
		if cell_click_mode:
			if click.pressed:
				var cell: Vector2i = _cell_at(click.position)
				if layout.contains(cell):
					cell_clicked.emit(cell, click.button_index)
			accept_event()
			return
		if click.pressed:
			_paint_button = click.button_index
			_last_painted = Vector2i(-1, -1)
			_paint(_cell_at(click.position))
		else:
			_paint_button = MOUSE_BUTTON_NONE
		accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover = _cell_at(motion.position)
		# Releases outside the board must not leave painting latched on.
		if _paint_button != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(_paint_button):
			_paint_button = MOUSE_BUTTON_NONE
		if _paint_button != MOUSE_BUTTON_NONE:
			_paint(_hover)
		queue_redraw()


func cancel_stroke() -> void:
	_paint_button = MOUSE_BUTTON_NONE
	_last_painted = Vector2i(-1, -1)
	_hover = Vector2i(-1, -1)
	queue_redraw()


func _paint(cell: Vector2i) -> void:
	if cell == _last_painted or not layout.contains(cell):
		return
	_last_painted = cell
	if command_mode:
		for tower: Dictionary in combat_towers:
			if tower["cell"] == cell:
				if _paint_button == MOUSE_BUTTON_LEFT:
					cell_clicked.emit(cell, _paint_button)
				return
		edit_requested.emit(cell, _paint_button == MOUSE_BUTTON_LEFT)
		return
	if layout.is_endpoint(cell):
		feedback.emit("Entrance and base are fixed; they use no budget.")
		return
	var changed: bool = false
	if _paint_button == MOUSE_BUTTON_LEFT:
		if not layout.has_path(cell) and layout.used_tiles() >= layout.budget:
			feedback.emit("Tile budget reached. Remove a tile before placing another.")
			return
		changed = layout.place(cell)
	elif _paint_button == MOUSE_BUTTON_RIGHT:
		changed = layout.erase(cell)
	if changed:
		edited.emit()
		queue_redraw()


func _on_mouse_exited() -> void:
	_hover = Vector2i(-1, -1)
	_last_painted = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	var cell_size: float = _cell_size()
	var origin: Vector2 = _board_origin()
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			var rect := Rect2(origin + Vector2(x, y) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 2))
			draw_rect(rect, GROUND)
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			var cell := Vector2i(x, y)
			var display_x: int = layout.dimensions.x - 1 - x if mirror_horizontal else x
			if layout.has_path(cell):
				var center := origin + (Vector2(display_x, y) + Vector2.ONE * 0.5) * cell_size
				var width: float = cell_size * 0.64
				draw_rect(Rect2(center - Vector2.ONE * width * 0.5, Vector2.ONE * width), TILE)
				if layout.contains(cell + Vector2i.RIGHT) and layout.has_path(cell + Vector2i.RIGHT):
					var direction: float = -1.0 if mirror_horizontal else 1.0
					var start := center + Vector2(minf(0.0, direction * cell_size), -width * 0.5)
					draw_rect(Rect2(start, Vector2(cell_size, width)), TILE)
				if layout.contains(cell + Vector2i.DOWN) and layout.has_path(cell + Vector2i.DOWN):
					draw_rect(Rect2(center - Vector2(width * 0.5, 0.0), Vector2(width, cell_size)), TILE)
	if input_enabled and layout.contains(_hover):
		var rect := Rect2(cell_center(_hover) - Vector2.ONE * cell_size * 0.5 + Vector2.ONE * 3, Vector2.ONE * (cell_size - 6))
		draw_rect(rect, Color("e6e0cf"), false, 2.0)
	for i: int in range(1, layout.route.size()):
		draw_line(cell_center(layout.route[i - 1]), cell_center(layout.route[i]), ROUTE_LINE, 4.0, true)
	_draw_endpoint(layout.entrance, ENTRY_COLOR, "E")
	_draw_endpoint(layout.base, BASE_COLOR, "B")
	_draw_combat()


func _draw_combat() -> void:
	var cell_size: float = _cell_size()
	var texture_size: Vector2 = ARROW_REWARD.icon_texture.get_size()
	var icon_size: Vector2 = texture_size * (cell_size * 0.86 / maxf(texture_size.x, texture_size.y))
	for tower: Dictionary in combat_towers:
		if int(tower["id"]) == selected_tower_id:
			var center: Vector2 = cell_center(tower["cell"])
			draw_circle(center, tower_range * cell_size, Color(0.71, 0.89, 0.72, 0.06))
			draw_arc(center, tower_range * cell_size, 0.0, TAU, 96, ROUTE_LINE, 1.5, true)
	for tower: Dictionary in combat_towers:
		var center: Vector2 = cell_center(tower["cell"])
		var selected: bool = int(tower["id"]) == selected_tower_id
		var extent: float = cell_size * 0.45
		draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0),
			Color("e0bc77") if selected else Color("526353"), false, 2.0)
		draw_texture_rect(ARROW_REWARD.icon_texture, Rect2(center - icon_size * 0.5, icon_size), false)
	for enemy: Dictionary in combat_enemies:
		var position: Vector2 = _enemy_position(enemy)
		var center: Vector2 = _position_center(position)
		var radius: float = maxf(4.0, cell_size * 0.20)
		draw_circle(center, radius + 1.5, Color("172120"))
		draw_circle(center, radius, Color("d99578"))
		var bar_size: Vector2 = Vector2(cell_size * 0.62, maxf(3.0, cell_size * 0.09))
		var bar_position: Vector2 = center - Vector2(bar_size.x * 0.5, radius + bar_size.y + 3.0)
		draw_rect(Rect2(bar_position, bar_size), Color("172120"))
		var fraction: float = clampf(float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"])), 0.0, 1.0)
		draw_rect(Rect2(bar_position, Vector2(bar_size.x * fraction, bar_size.y)), ROUTE_LINE)
	for trace: Dictionary in _shot_traces:
		var aim: Vector2 = trace["aim"]
		var end: Vector2 = _position_center(aim)
		var color := Color("f6df99")
		color.a = clampf(float(trace["life"]) / SHOT_DURATION, 0.0, 1.0)
		draw_line(cell_center(trace["cell"]), end, color, 2.0, true)
		draw_circle(end, cell_size * 0.13, color, false, 1.5, true)


func _draw_endpoint(cell: Vector2i, color: Color, letter: String) -> void:
	var center: Vector2 = cell_center(cell)
	var extent: float = _cell_size() * 0.29
	draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2), color)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1c2625"))
