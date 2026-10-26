class_name CommanderVisuals
extends RefCounted

# Original hard-edged masonry; the accepted cell, never the drawing, owns rules.
static func draw_landmark(surface: CanvasItem, foot: Vector2, cell_size: float, id: StringName, active: bool) -> void:
	var pixel: float = maxf(1.0, floorf(cell_size / 24.0))
	var origin: Vector2 = foot.round()
	_rect(surface, origin, pixel, -11, -3, 22, 3, Color("303b36"))
	_rect(surface, origin, pixel, -10, -4, 20, 2, Color("9a9d83"))
	if id == &"knight":
		_rect(surface, origin, pixel, -9, -12, 18, 8, Color("465b60"))
		_rect(surface, origin, pixel, -8, -11, 16, 2, Color("a7b4a0"))
		_rect(surface, origin, pixel, -9, -16, 4, 5, Color("7f9594"))
		_rect(surface, origin, pixel, -2, -16, 4, 5, Color("7f9594"))
		_rect(surface, origin, pixel, 5, -16, 4, 5, Color("7f9594"))
		_rect(surface, origin, pixel, -2, -8, 4, 4, Color("263b40"))
		_rect(surface, origin, pixel, -8, -7, 4, 1, Color("657e7e"))
		_rect(surface, origin, pixel, 4, -9, 4, 1, Color("657e7e"))
		_rect(surface, origin, pixel, 4, -24, 1, 13, Color("c1b98c"))
		_rect(surface, origin, pixel, 5, -23, 7, 6, Color("e7c777") if active else Color("9e613b"))
		_rect(surface, origin, pixel, 5, -22, 5, 1, Color("f5dda0"))
	else:
		_rect(surface, origin, pixel, -8, -6, 16, 2, Color("b1b9ad"))
		_rect(surface, origin, pixel, -7, -18, 4, 12, Color("879eaa"))
		_rect(surface, origin, pixel, 3, -18, 4, 12, Color("879eaa"))
		_rect(surface, origin, pixel, -5, -21, 10, 4, Color("bdced0"))
		_rect(surface, origin, pixel, -8, -18, 16, 2, Color("637c8c"))
		_rect(surface, origin, pixel, -5, -16, 1, 9, Color("d3d9c3"))
		_rect(surface, origin, pixel, 5, -16, 1, 9, Color("d3d9c3"))
		_rect(surface, origin, pixel, -2, -14, 4, 7, Color("579fc0"))
		_rect(surface, origin, pixel, -1, -16, 2, 10, Color("a9edf2"))
		_rect(surface, origin, pixel, -3, -12, 6, 2, Color("d8f7e8"))


static func draw_obstacle(surface: CanvasItem, foot: Vector2, cell_size: float) -> void:
	var pixel: float = maxf(1.0, floorf(cell_size / 24.0))
	var origin: Vector2 = foot.round()
	_rect(surface, origin, pixel, -10, -3, 20, 3, Color("34392e"))
	_rect(surface, origin, pixel, -9, -8, 8, 6, Color("737b65"))
	_rect(surface, origin, pixel, -8, -9, 6, 2, Color("a6ad8b"))
	_rect(surface, origin, pixel, 0, -6, 9, 5, Color("636f63"))
	_rect(surface, origin, pixel, 1, -7, 6, 2, Color("959f84"))
	_rect(surface, origin, pixel, -2, -4, 3, 3, Color("414e44"))
	_rect(surface, origin, pixel, 5, -3, 4, 1, Color("a6ad8b"))


static func _rect(surface: CanvasItem, origin: Vector2, pixel: float, x: int, y: int, width: int, height: int, color: Color) -> void:
	surface.draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2(width, height) * pixel), color)
