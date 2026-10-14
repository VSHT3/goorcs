class_name PathBoard
extends Control

signal edited
signal feedback(message: String)
signal edit_requested(cell: Vector2i, place: bool)
signal cell_clicked(cell: Vector2i, button: MouseButton)
signal tower_dropped(cell: Vector2i, type_id: StringName)

const GROUND := Color("222c2b")
const TILE := Color("6e7465")
const ENEMY_BLEND_DURATION: float = 0.1
const ROUTE_LINE := Color("b5e2b7")
const ENTRY_COLOR := Color("e0bc77")
const BASE_COLOR := Color("96c8dc")
const SHOT_DURATION: float = 0.18
const PULSE_DURATION: float = 0.45

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
var tower_types: Dictionary = {}
var tower_catalog: Array[TowerReward] = CollectionStore.DEFAULT_CATALOG:
	set(value):
		tower_catalog = value
		_tower_textures.clear()
		for reward: TowerReward in value:
			_tower_textures[String(reward.id)] = reward.icon_texture
		queue_redraw()
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
var _tower_textures: Dictionary[String, Texture2D] = {}
var _endpoint_textures_loaded: bool = false
var _portal_texture: Texture2D
var _crystal_texture: Texture2D


func _ready() -> void:
	tower_catalog = tower_catalog
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
			var definition: Dictionary = tower_types[tower["type_id"]]
			var area_attack: bool = bool(definition["area_attack"])
			var duration: float = PULSE_DURATION if area_attack else SHOT_DURATION
			_shot_traces.append({
				"cell": tower["cell"],
				"aim": tower["aim"],
				"life": duration,
				"duration": duration,
				"area_attack": area_attack,
				"range": float(definition["range"]),
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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not input_enabled or layout == null or _cell_size() <= 0.0:
		return false
	if not data is Dictionary or not data.get("tower_type") is String:
		return false
	var type_id: String = data["tower_type"]
	if not tower_types.has(type_id):
		return false
	var cell: Vector2i = _cell_at(at_position)
	if not layout.contains(cell) or layout.has_path(cell):
		return false
	for tower: Dictionary in combat_towers:
		if tower["cell"] == cell:
			return false
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	cancel_stroke()
	tower_dropped.emit(_cell_at(at_position), StringName(data["tower_type"]))


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
	_draw_endpoint(layout.entrance, ENTRY_COLOR, "E")
	_draw_endpoint(layout.base, BASE_COLOR, "B")
	_draw_combat()


func _draw_combat() -> void:
	var cell_size: float = _cell_size()
	for tower: Dictionary in combat_towers:
		if int(tower["id"]) == selected_tower_id:
			var tower_cell: Vector2i = tower["cell"]
			var tower_range: float = float(tower_types[tower["type_id"]]["range"])
			for y: int in range(layout.dimensions.y):
				for x: int in range(layout.dimensions.x):
					var cell := Vector2i(x, y)
					if not MatchCombat.cell_in_range(tower_cell, cell, tower_range):
						continue
					var rect := Rect2(cell_center(cell) - Vector2.ONE * cell_size * 0.5 + Vector2.ONE * 2.0,
						Vector2.ONE * (cell_size - 4.0))
					draw_rect(rect, Color(0.71, 0.89, 0.72, 0.12))
					draw_rect(rect, ROUTE_LINE, false, 1.5)
	for tower: Dictionary in combat_towers:
		var center: Vector2 = cell_center(tower["cell"])
		var selected: bool = int(tower["id"]) == selected_tower_id
		var extent: float = cell_size * 0.45
		draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0),
			Color("e0bc77") if selected else Color("526353"), false, 2.0)
		var texture: Texture2D = _tower_textures.get(tower["type_id"])
		if texture != null:
			var texture_size: Vector2 = texture.get_size()
			var icon_size: Vector2 = texture_size * (cell_size * 0.86 / maxf(texture_size.x, texture_size.y))
			draw_texture_rect(texture, Rect2(center - icon_size * 0.5, icon_size), false)
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
		var color := Color("f6df99")
		var remaining: float = clampf(float(trace["life"]) / float(trace["duration"]), 0.0, 1.0)
		color.a = remaining
		if bool(trace["area_attack"]):
			var radius: float = (float(trace["range"]) + 0.5) * cell_size * (1.0 - remaining)
			draw_circle(cell_center(trace["cell"]), radius, color, false, 2.5, true)
		else:
			var aim: Vector2 = trace["aim"]
			var end: Vector2 = _position_center(aim)
			draw_line(cell_center(trace["cell"]), end, color, 2.0, true)
			draw_circle(end, cell_size * 0.13, color, false, 1.5, true)


func _draw_endpoint(cell: Vector2i, color: Color, letter: String) -> void:
	var center: Vector2 = cell_center(cell)
	if command_mode:
		if not _endpoint_textures_loaded:
			_portal_texture = load("res://assets/world/enemy_portal.png") as Texture2D
			_crystal_texture = load("res://assets/world/health_crystal.png") as Texture2D
			_endpoint_textures_loaded = true
		var texture: Texture2D = _portal_texture if cell == layout.entrance else _crystal_texture
		if texture != null:
			var texture_size: Vector2 = texture.get_size()
			var icon_size: Vector2 = texture_size * (_cell_size() * 0.94 / maxf(texture_size.x, texture_size.y))
			draw_texture_rect(texture, Rect2(center - icon_size * 0.5, icon_size), false)
		return
	var extent: float = _cell_size() * 0.29
	draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2), color)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1c2625"))
