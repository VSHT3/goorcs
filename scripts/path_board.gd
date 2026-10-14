class_name PathBoard
extends Control

signal edited
signal feedback(message: String)
signal edit_requested(cell: Vector2i, place: bool)

const GROUND := Color("222c2b")
const TILE := Color("6e7465")
const ROUTE_TILE := Color("426957")
const ROUTE_LINE := Color("b5e2b7")
const ENTRY_COLOR := Color("e0bc77")
const BASE_COLOR := Color("96c8dc")

var layout: PathLayout
var command_mode: bool = false
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		if not value:
			cancel_stroke()
var _hover := Vector2i(-1, -1)
var _paint_button: MouseButton = MOUSE_BUTTON_NONE
var _last_painted := Vector2i(-1, -1)


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)


func cell_center(cell: Vector2i) -> Vector2:
	return _board_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size()


func _cell_size() -> float:
	return floorf(minf(size.x / layout.dimensions.x, size.y / layout.dimensions.y))


func _board_origin() -> Vector2:
	return (size - Vector2(layout.dimensions) * _cell_size()) * 0.5


func _cell_at(position: Vector2) -> Vector2i:
	return Vector2i(((position - _board_origin()) / _cell_size()).floor())


func _gui_input(event: InputEvent) -> void:
	if layout == null or not input_enabled:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
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
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 2))
			var color: Color = GROUND
			if layout.has_path(cell):
				color = ROUTE_TILE if layout.route.has(cell) else TILE
			draw_rect(rect, color)
			if input_enabled and cell == _hover:
				draw_rect(rect.grow(-2), Color("e6e0cf"), false, 2.0)
	for i: int in range(1, layout.route.size()):
		draw_line(cell_center(layout.route[i - 1]), cell_center(layout.route[i]), ROUTE_LINE, 4.0, true)
	_draw_endpoint(layout.entrance, ENTRY_COLOR, "E")
	_draw_endpoint(layout.base, BASE_COLOR, "B")


func _draw_endpoint(cell: Vector2i, color: Color, letter: String) -> void:
	var center: Vector2 = cell_center(cell)
	var extent: float = _cell_size() * 0.29
	draw_rect(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2), color)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1c2625"))
