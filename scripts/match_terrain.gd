class_name MatchTerrain
extends Node2D

const GROUND := Color("253329")
const PATCH_LIGHT := Color("28362b")
const PATCH_DARK := Color("233127")
const GRASS := Color("35412f")
const RAVINE := Color("1c2923")
const RAVINE_BANK := Color("3b4231")
const RAVINE_CONTACT := Color("202e25")
const PATCH_SPACING: float = 240.0
const RAVINE_STEP: float = 40.0

var _extents := Rect2()
var _gap := Rect2()


func configure(board_size: Vector2, board_gap: float, extents: Rect2) -> void:
	_extents = extents
	_gap = Rect2(Vector2(board_size.x, extents.position.y), Vector2(board_gap, extents.size.y))
	queue_redraw()


func _draw() -> void:
	if not _extents.has_area():
		return
	draw_rect(_extents, GROUND)
	# Large, quiet world-anchored sod masses survive camera travel without confetti.
	var first_column: int = floori(_extents.position.x / PATCH_SPACING)
	var last_column: int = ceili(_extents.end.x / PATCH_SPACING)
	var first_row: int = floori(_extents.position.y / PATCH_SPACING)
	var last_row: int = ceili(_extents.end.y / PATCH_SPACING)
	for row: int in range(first_row, last_row):
		for column: int in range(first_column, last_column):
			var pattern: int = absi(column * 47 + row * 83)
			var point := Vector2(column, row) * PATCH_SPACING + Vector2(pattern % 53, pattern % 37)
			var color: Color = PATCH_LIGHT if pattern % 3 else PATCH_DARK
			draw_rect(Rect2(point, Vector2(172.0, 106.0)), color)
			draw_rect(Rect2(point + Vector2(32.0, 106.0), Vector2(112.0, 32.0)), color)
			if pattern % 3 != 1:
				continue
			var tuft: Vector2 = point + Vector2(151.0, 158.0)
			draw_line(tuft, tuft + Vector2(-2.0, -3.0), GRASS, 1.0)
			draw_line(tuft + Vector2(4.0, 0.0), tuft + Vector2(3.0, -2.0), GRASS, 1.0)
	# A continuous jagged crevasse, never an earth crossing or a third playable path.
	# Every bank remains inside the gap, leaving the two cell rectangles untouched.
	for step: int in range(floori(_gap.position.y / RAVINE_STEP), ceili(_gap.end.y / RAVINE_STEP)):
		var pattern: int = absi(step * 37 + 19)
		var inset_left: float = _gap.size.x * (0.24 + (pattern % 5) * 0.025)
		var inset_right: float = _gap.size.x * (0.24 + (floori(float(pattern) / 5.0) % 5) * 0.025)
		var left: float = _gap.position.x + inset_left
		var right: float = _gap.end.x - inset_right
		var top: float = maxf(step * RAVINE_STEP, _gap.position.y)
		var bottom: float = minf((step + 1) * RAVINE_STEP, _gap.end.y)
		var rift := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
		draw_rect(rift.grow_individual(4.0, 0.0, 4.0, 0.0), RAVINE_BANK)
		draw_rect(rift.grow_individual(1.0, 0.0, 2.0, 0.0), RAVINE_CONTACT)
		draw_rect(rift, RAVINE)
