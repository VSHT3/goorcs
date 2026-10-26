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


static func draw_obstacle(surface: CanvasItem, foot: Vector2, cell_size: float, variant: int) -> void:
	var pixel: float = maxf(1.0, floorf(cell_size / 24.0))
	var origin: Vector2 = foot.round()
	match variant:
		0: # Tall, cold-grey split boulder with a smaller scree stone.
			_rect(surface, origin, pixel, -10, -4, 20, 4, Color("303b36"))
			_rect(surface, origin, pixel, -7, -13, 12, 10, Color("505e65"))
			_rect(surface, origin, pixel, -4, -16, 7, 4, Color("89979b"))
			_rect(surface, origin, pixel, -6, -12, 5, 4, Color("a4aeaa"))
			_rect(surface, origin, pixel, 0, -11, 2, 6, Color("35434c"))
			_rect(surface, origin, pixel, 5, -7, 5, 5, Color("75868a"))
			_rect(surface, origin, pixel, -9, -5, 4, 3, Color("708079"))
			_rect(surface, origin, pixel, -6, -3, 5, 2, Color("596d43"))
		1: # Low, wide warm masonry: stepped courses and dark mortar seams.
			_rect(surface, origin, pixel, -11, -4, 22, 4, Color("4c4033"))
			_rect(surface, origin, pixel, -10, -8, 8, 5, Color("a98d6a"))
			_rect(surface, origin, pixel, -9, -9, 7, 2, Color("d1b18a"))
			_rect(surface, origin, pixel, -1, -7, 10, 4, Color("927653"))
			_rect(surface, origin, pixel, -5, -13, 7, 5, Color("b79b77"))
			_rect(surface, origin, pixel, -4, -14, 6, 2, Color("dfc39a"))
			_rect(surface, origin, pixel, 3, -11, 5, 3, Color("806447"))
			_rect(surface, origin, pixel, -5, -7, 3, 3, Color("604d3c"))
			_rect(surface, origin, pixel, 5, -3, 5, 2, Color("c1a27c"))
		2: # Russet stump, pale cut rings, roots and a fallen branch.
			_rect(surface, origin, pixel, -10, -3, 20, 3, Color("493e2a"))
			_rect(surface, origin, pixel, -5, -12, 10, 9, Color("754a2f"))
			_rect(surface, origin, pixel, -6, -12, 12, 3, Color("c6a067"))
			_rect(surface, origin, pixel, -3, -11, 6, 1, Color("7f5c38"))
			_rect(surface, origin, pixel, -4, -9, 2, 7, Color("a66e3d"))
			_rect(surface, origin, pixel, 2, -9, 2, 6, Color("4e3425"))
			_rect(surface, origin, pixel, -8, -4, 5, 3, Color("865a34"))
			_rect(surface, origin, pixel, 3, -5, 7, 3, Color("956739"))
			_rect(surface, origin, pixel, 7, -7, 2, 3, Color("b78a4d"))
			_rect(surface, origin, pixel, -7, -2, 3, 1, Color("69804a"))
		3: # Broken barricade: separated upright stakes, crossbeam and iron.
			_rect(surface, origin, pixel, -10, -3, 20, 3, Color("343c30"))
			_rect(surface, origin, pixel, -8, -16, 4, 14, Color("775838"))
			_rect(surface, origin, pixel, -7, -18, 2, 3, Color("b59c69"))
			_rect(surface, origin, pixel, 4, -12, 4, 10, Color("6e4c31"))
			_rect(surface, origin, pixel, 5, -14, 2, 3, Color("b59c69"))
			_rect(surface, origin, pixel, -10, -9, 20, 4, Color("a17c4b"))
			_rect(surface, origin, pixel, -9, -9, 18, 1, Color("c4a06c"))
			_rect(surface, origin, pixel, -8, -8, 3, 3, Color("536267"))
			_rect(surface, origin, pixel, 4, -8, 3, 3, Color("536267"))
			_rect(surface, origin, pixel, -2, -5, 3, 4, Color("765030"))
			_rect(surface, origin, pixel, 0, -3, 6, 2, Color("ab8953"))


static func _rect(surface: CanvasItem, origin: Vector2, pixel: float, x: int, y: int, width: int, height: int, color: Color) -> void:
	surface.draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2(width, height) * pixel), color)
