class_name MatchTerrain
extends Node2D

const GROUND := Color("2f3c30")
const GRASS := Color("354232")
const EARTH := Color("3b4232")
const STONE := Color("435039")
const PATCH_SPACING: float = 72.0

var _extents := Rect2()
var _corridor := Rect2()


func configure(board_size: Vector2, board_gap: float, extents: Rect2) -> void:
	_extents = extents
	_corridor = Rect2(Vector2(board_size.x, board_size.y * 0.5 - 30.0), Vector2(board_gap, 60.0))
	queue_redraw()


func _draw() -> void:
	if not _extents.has_area():
		return
	draw_rect(_extents, GROUND)
	# World-anchored marks keep the ground continuous while the camera travels.
	var first_column: int = floori(_extents.position.x / PATCH_SPACING)
	var last_column: int = ceili(_extents.end.x / PATCH_SPACING)
	var first_row: int = floori(_extents.position.y / PATCH_SPACING)
	var last_row: int = ceili(_extents.end.y / PATCH_SPACING)
	for row: int in range(first_row, last_row):
		for column: int in range(first_column, last_column):
			var pattern: int = absi(column * 37 + row * 61)
			var point := Vector2(column, row) * PATCH_SPACING + Vector2(16 + pattern % 41, 12 + pattern % 53)
			draw_rect(Rect2(point - Vector2(12, 8), Vector2(43.0 + pattern % 29, 18.0)), GRASS if pattern % 3 else EARTH)
			draw_line(point, point + Vector2(-2.0, -3.0), STONE, 1.0)
			draw_line(point + Vector2(4.0, 0.0), point + Vector2(3.0, -2.0), STONE, 1.0)
	# A neutral earth crossing joins the boards without adding path cells or rules.
	draw_rect(_corridor.grow(8.0), GRASS)
	draw_rect(_corridor, EARTH)
	for step: int in range(floori(_corridor.size.x / 24.0)):
		var point := _corridor.position + Vector2(10.0 + step * 24.0, 18.0 + (step % 2) * 19.0)
		draw_rect(Rect2(point, Vector2(7.0, 3.0)), STONE)
