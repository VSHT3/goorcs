class_name ItemieryRoom
extends Node2D
## Authored at 640×360; the screen scales the viewport with nearest filtering.

const MORTAR := Color("151e1b")
const STONE := Color("303d35")
const EDGE := Color("465244")
const LIGHT := Color("64705a")
const DARK := Color("101915")
const CENTERS: PackedInt32Array = [68, 152, 236, 320, 404, 488, 572]
const DOOR_WOODS: Array[Color] = [
	Color("69503a"), Color("634b2d"), Color("354854"), Color("3e304b"),
	Color("362b2c"), Color("66452b"), Color("263f32"),
]
const DOOR_METALS: Array[Color] = [
	Color("73766b"), Color("9b8451"), Color("92a7b1"), Color("a397b9"),
	Color("a15e4c"), Color("d3b363"), Color("b6c594"),
]

var _door_openings: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _hovered_door: int = -1
var _door_layer: DoorLayer


class DoorLayer extends Node2D:
	var hall: Node2D

	func _draw() -> void:
		hall._draw_doors(self)


static func plaque_rect(index: int) -> Rect2:
	return Rect2(CENTERS[index] - 38, 253, 76, 20)


static func door_rect(index: int) -> Rect2:
	return Rect2(CENTERS[index] - 28, 88, 56, 138)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_layer = DoorLayer.new()
	_door_layer.name = "DoorLeaves"
	_door_layer.hall = self
	add_child(_door_layer)
	set_process(false)


func set_door_opening(index: int, progress: float) -> void:
	if index < 0 or index >= CENTERS.size():
		return
	var opening: float = clampf(progress, 0.0, 1.0)
	if is_equal_approx(_door_openings[index], opening):
		return
	_door_openings[index] = opening
	if is_instance_valid(_door_layer):
		_door_layer.queue_redraw()


func reset_doors() -> void:
	_door_openings.fill(0.0)
	_hovered_door = -1
	if is_instance_valid(_door_layer):
		_door_layer.queue_redraw()


func set_hovered_door(index: int) -> void:
	var hovered: int = index if index >= 0 and index < CENTERS.size() else -1
	if _hovered_door == hovered:
		return
	_hovered_door = hovered
	if is_instance_valid(_door_layer):
		_door_layer.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("0c1410"))
	# Recessed masonry, with fixed variations rather than animated noise.
	for row: int in range(11):
		for column: int in range(12):
			var x: int = column * 60 - (30 if row % 2 else 0)
			var y: int = row * 24
			var shade: float = float((row * 7 + column * 3) % 5) * 0.012
			draw_rect(Rect2(x + 1, y + 1, 58, 22), Color(0.13 + shade, 0.18 + shade, 0.145 + shade))
			draw_line(Vector2(x + 2, y + 2), Vector2(x + 57, y + 2), Color("303c31"))
	# Heavy ceiling cornice, supporting pillars and floor perspective.
	draw_rect(Rect2(0, 0, 640, 12), DARK)
	draw_rect(Rect2(0, 12, 640, 5), EDGE)
	draw_rect(Rect2(0, 17, 640, 3), MORTAR)
	draw_rect(Rect2(0, 20, 640, 6), STONE)
	for x: int in [8, 616]:
		draw_rect(Rect2(x, 26, 16, 220), MORTAR)
		draw_rect(Rect2(x + 3, 26, 10, 220), STONE)
		for y: int in range(30, 240, 27):
			draw_rect(Rect2(x + 2, y, 12, 2), EDGE)
		draw_rect(Rect2(x - 4, 236, 24, 10), EDGE)
		draw_rect(Rect2(x - 6, 246, 28, 5), STONE)
	draw_rect(Rect2(0, 251, 640, 109), Color("222d25"))
	for y: int in [252, 270, 294, 325, 359]:
		draw_line(Vector2(0, y), Vector2(640, y), Color("101b15"), 2)
	for x: int in range(-320, 1000, 80):
		draw_line(Vector2(320 + (x - 320) * 0.65, 251), Vector2(x, 360), Color("152018"), 2)
	# Worn foreground floor slabs and a green inlaid runner.
	draw_colored_polygon(PackedVector2Array([Vector2(287, 251), Vector2(353, 251), Vector2(385, 360), Vector2(255, 360)]), Color("283b29"))
	for side: int in [-1, 1]:
		draw_line(Vector2(320 + side * 32, 251), Vector2(320 + side * 65, 360), Color("536346"), 2)
	for i: int in range(22):
		var x: int = 18 + (i * 137) % 604
		var y: int = 300 + (i * 23) % 57
		draw_line(Vector2(x, y), Vector2(x + 7 + i % 9, y), Color("3b4836"))
	# Door surrounds and the hall itself retain their canvas commands while idle.
	for index: int in range(CENTERS.size()):
		_draw_doorway(index)
	_draw_crest(Vector2(320, 48), 1.0)
	# Iron lintel braces and restrained wall decoration.
	for x: int in [37, 595]:
		draw_rect(Rect2(x, 32, 8, 24), DARK)
		draw_rect(Rect2(x + 2, 35, 4, 17), EDGE)
		draw_rect(Rect2(x + 3, 38, 2, 2), LIGHT)
		draw_rect(Rect2(x + 3, 47, 2, 2), LIGHT)


func _draw_doorway(index: int) -> void:
	var x: int = CENTERS[index]
	var tint: Color = ItemRarity.COLORS[index]
	# Stepped stone arch, layered bevel and recessed dark interior.
	var arch := PackedVector2Array([
		Vector2(x - 36, 228), Vector2(x - 36, 107), Vector2(x - 30, 107),
		Vector2(x - 30, 91), Vector2(x - 20, 91), Vector2(x - 20, 80),
		Vector2(x + 20, 80), Vector2(x + 20, 91), Vector2(x + 30, 91),
		Vector2(x + 30, 107), Vector2(x + 36, 107), Vector2(x + 36, 228),
	])
	draw_colored_polygon(arch, EDGE)
	var inner := PackedVector2Array([
		Vector2(x - 29, 226), Vector2(x - 29, 110), Vector2(x - 23, 110),
		Vector2(x - 23, 96), Vector2(x - 14, 96), Vector2(x - 14, 87),
		Vector2(x + 14, 87), Vector2(x + 14, 96), Vector2(x + 23, 96),
		Vector2(x + 23, 110), Vector2(x + 29, 110), Vector2(x + 29, 226),
	])
	draw_colored_polygon(inner, DARK)
	draw_rect(Rect2(x - 26, 114, 52, 109), Color("0b120f"))
	for side: int in [-1, 1]:
		var edge_x: int = x + (-36 if side < 0 else 30)
		for y: int in range(114, 225, 23):
			draw_rect(Rect2(edge_x, y, 6, 2), MORTAR)
			draw_rect(Rect2(edge_x + 1, y + 3, 2, 17), LIGHT.darkened(0.25))
	# Carved keystones and real raised thresholds, never display plinths.
	draw_rect(Rect2(x - 7, 81, 14, 7), STONE)
	draw_rect(Rect2(x - 3, 82, 6, 4), tint.darkened(0.2))
	draw_rect(Rect2(x - 31, 226, 62, 7), MORTAR)
	draw_rect(Rect2(x - 29, 226, 58, 3), LIGHT)
	draw_rect(Rect2(x - 29, 229, 58, 3), STONE)
	draw_rect(Rect2(x - 34, 233, 68, 6), Color("17221b"))
	draw_rect(Rect2(x - 32, 233, 64, 2), EDGE)
	draw_rect(Rect2(x - 26, 237, 52, 1), Color("374332"))
	for side: int in [-1, 1]:
		draw_rect(Rect2(x + side * 32 - 1, 109, 2, 116), tint.darkened(0.68))
		if index >= ItemRarity.Tier.RARE:
			for y: int in [119, 165, 211]:
				draw_rect(Rect2(x + side * 33 - 1, y, 2, 3), tint.darkened(0.12))
		if index >= ItemRarity.Tier.EPIC:
			draw_rect(Rect2(x + side * 32 - 2, 99, 4, 6), STONE)
			draw_rect(Rect2(x + side * 32 - 1, 100, 2, 3), tint)
		if index >= ItemRarity.Tier.LEGENDARY:
			draw_rect(Rect2(x + side * 12 - 1, 75, 3, 6), tint.darkened(0.25))
			draw_rect(Rect2(x + side * 19 - 1, 78, 3, 4), tint.darkened(0.25))
	if index == ItemRarity.Tier.ORCFECCION:
		_draw_crest(Vector2(x, 62), 0.45)
		for side: int in [-1, 1]:
			var tusk_x: int = x + side * 37
			draw_colored_polygon(PackedVector2Array([
				Vector2(tusk_x, 225), Vector2(tusk_x + side * 4, 217),
				Vector2(tusk_x + side * 2, 190), Vector2(tusk_x - side * 3, 208),
				Vector2(tusk_x - side * 4, 225),
			]), Color("a7b98c"))
			draw_line(Vector2(tusk_x, 222), Vector2(tusk_x + side * 2, 206), Color("d4d6a6"))
	draw_rect(plaque_rect(index), MORTAR)
	draw_line(Vector2(x - 35, 254), Vector2(x + 35, 254), EDGE)


func _draw_doors(canvas: Node2D) -> void:
	for index: int in range(CENTERS.size()):
		var center: int = CENTERS[index]
		var progress: float = _door_openings[index]
		if progress > 0.0:
			_draw_aperture(canvas, index, progress)
		for side: int in [-1, 1]:
			_draw_leaf(canvas, center, side, index, progress)
		if index == _hovered_door:
			var tint: Color = ItemRarity.COLORS[index].lightened(0.3)
			var outline := PackedVector2Array([
				Vector2(center - 29, 225), Vector2(center - 29, 110),
				Vector2(center - 23, 110), Vector2(center - 23, 96),
				Vector2(center - 14, 96), Vector2(center - 14, 87),
				Vector2(center + 14, 87), Vector2(center + 14, 96),
				Vector2(center + 23, 96), Vector2(center + 23, 110),
				Vector2(center + 29, 110), Vector2(center + 29, 225),
			])
			canvas.draw_polyline(outline, tint, 1.0, false)
			canvas.draw_line(Vector2(center - 29, 225), Vector2(center + 29, 225), tint)


func _draw_aperture(canvas: Node2D, index: int, progress: float) -> void:
	var x: int = CENTERS[index]
	var tint: Color = ItemRarity.COLORS[index]
	# The room beyond is revealed by moving solid leaves, not by fading them.
	var aperture := PackedVector2Array([
		Vector2(x - 27, 225), Vector2(x - 27, 111), Vector2(x - 21, 111),
		Vector2(x - 21, 97), Vector2(x - 13, 97), Vector2(x - 13, 89),
		Vector2(x + 13, 89), Vector2(x + 13, 97), Vector2(x + 21, 97),
		Vector2(x + 21, 111), Vector2(x + 27, 111), Vector2(x + 27, 225),
	])
	canvas.draw_colored_polygon(aperture, Color("121d18").lerp(tint.darkened(0.78), 0.5))
	# Converging jambs, a distant lintel and a lit passage floor give depth.
	canvas.draw_rect(Rect2(x - 17, 119, 34, 81), Color("0b1310"))
	canvas.draw_rect(Rect2(x - 17, 117, 34, 3), tint.darkened(0.58))
	for side: int in [-1, 1]:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x + side * 27, 112), Vector2(x + side * 17, 121),
			Vector2(x + side * 17, 200), Vector2(x + side * 27, 225),
		]), tint.darkened(0.82 if side < 0 else 0.88))
		canvas.draw_line(Vector2(x + side * 25, 115), Vector2(x + side * 17, 123), tint.darkened(0.4))
		canvas.draw_rect(Rect2(x + side * 12 - 1, 146, 3, 9), tint.darkened(0.1))
		canvas.draw_rect(Rect2(x + side * 12, 148, 1, 5), Color("e6e3ae"))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 17, 200), Vector2(x + 17, 200),
		Vector2(x + 27, 225), Vector2(x - 27, 225),
	]), tint.darkened(0.74))
	for y: int in [206, 214, 224]:
		canvas.draw_line(Vector2(x - 17 - (y - 200) / 3, y), Vector2(x + 17 + (y - 200) / 3, y), Color("18231a"))
	var spill: Color = Color(tint, 0.10 * progress)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 25, 239), Vector2(x + 25, 239),
		Vector2(x + 35, 250), Vector2(x - 35, 250),
	]), spill)


func _draw_leaf(canvas: Node2D, center: int, side: int, tier: int, progress: float) -> void:
	var wood: Color = DOOR_WOODS[tier].darkened(progress * 0.24)
	var metal: Color = DOOR_METALS[tier].darkened(progress * 0.18)
	var accent: Color = ItemRarity.COLORS[tier]
	var shape := PackedVector2Array([
		Vector2(0, 225), Vector2(0, 111), Vector2(6, 111), Vector2(6, 97),
		Vector2(14, 97), Vector2(14, 89), Vector2(27, 89), Vector2(27, 225),
	])
	for point: int in range(shape.size()):
		shape[point] = _leaf_point(center, side, shape[point], progress)
	canvas.draw_colored_polygon(shape, Color("0a110d"))
	# Thick cut timber edges remain opaque as the leaf turns into the passage.
	var thickness := PackedVector2Array([
		_leaf_point(center, side, Vector2(27, 90), progress),
		_leaf_point(center, side, Vector2(27, 225), progress),
		_leaf_point(center, side, Vector2(27, 225), progress) + Vector2(side * 2, 0),
		_leaf_point(center, side, Vector2(27, 90), progress) + Vector2(side * 2, 0),
	])
	canvas.draw_colored_polygon(thickness, metal.darkened(0.65))
	_leaf_rect(canvas, center, side, Rect2(1, 112, 25, 112), progress, wood)
	_leaf_rect(canvas, center, side, Rect2(7, 98, 19, 14), progress, wood)
	_leaf_rect(canvas, center, side, Rect2(15, 90, 11, 8), progress, wood)
	# Individual boards and short deterministic grain marks, never noise.
	for board: int in range(4):
		var bx: int = 2 + board * 6
		_leaf_line(canvas, center, side, Vector2(bx, 114), Vector2(bx, 222), progress, wood.lightened(0.13))
		_leaf_line(canvas, center, side, Vector2(bx + 4, 114), Vector2(bx + 4, 222), progress, wood.darkened(0.3))
		for grain: int in range(3):
			var gy: int = 122 + (board * 19 + grain * 31 + tier * 7) % 93
			_leaf_line(canvas, center, side, Vector2(bx + 2, gy), Vector2(bx + 2, gy + 7), progress, wood.darkened(0.19))
	# Recessed panels, hinge straps and a continuous center closing stile.
	for panel: Rect2 in [Rect2(5, 118, 17, 32), Rect2(5, 180, 17, 35)]:
		_leaf_rect(canvas, center, side, panel.grow(1), progress, wood.darkened(0.48))
		_leaf_rect(canvas, center, side, panel, progress, wood.lightened(0.06))
		_leaf_line(canvas, center, side, panel.position, panel.position + Vector2(panel.size.x, 0), progress, metal.darkened(0.28))
	for y: int in [113, 157, 218]:
		_leaf_rect(canvas, center, side, Rect2(0, y, 24, 4), progress, metal.darkened(0.35))
		_leaf_line(canvas, center, side, Vector2(2, y), Vector2(22, y), progress, metal)
		for rivet: int in [3, 19]:
			_leaf_rect(canvas, center, side, Rect2(rivet, y + 1, 2, 2), progress, metal.lightened(0.2))
		_leaf_rect(canvas, center, side, Rect2(0, y - 2, 3, 8), progress, Color("242d26"))
		_leaf_line(canvas, center, side, Vector2(1, y - 1), Vector2(1, y + 5), progress, metal)
	_leaf_rect(canvas, center, side, Rect2(25, 99, 1, 124), progress, metal.darkened(0.15))
	if tier >= ItemRarity.Tier.UNCOMMON:
		for y: int in [123, 184]:
			_leaf_line(canvas, center, side, Vector2(7, y), Vector2(19, y + 22), progress, metal.darkened(0.2))
			_leaf_line(canvas, center, side, Vector2(19, y), Vector2(7, y + 22), progress, metal.darkened(0.2))
		_leaf_rect(canvas, center, side, Rect2(11, 130, 4, 8), progress, accent.darkened(0.45))
	if tier >= ItemRarity.Tier.RARE:
		for y: int in [125, 189]:
			_leaf_motif(canvas, center, side, PackedVector2Array([
				Vector2(13, y), Vector2(19, y + 9), Vector2(13, y + 18),
				Vector2(7, y + 9), Vector2(13, y),
			]), progress, metal)
	if tier >= ItemRarity.Tier.EPIC:
		for y: int in [103, 163, 208]:
			_leaf_line(canvas, center, side, Vector2(8, y), Vector2(12, y - 3), progress, accent)
			_leaf_line(canvas, center, side, Vector2(12, y - 3), Vector2(16, y), progress, accent)
			_leaf_line(canvas, center, side, Vector2(12, y - 3), Vector2(12, y + 3), progress, metal)
	if tier == ItemRarity.Tier.MYTHIC:
		_leaf_motif(canvas, center, side, PackedVector2Array([
			Vector2(7, 141), Vector2(4, 130), Vector2(11, 135),
			Vector2(13, 122), Vector2(16, 135), Vector2(22, 130), Vector2(19, 141),
		]), progress, metal)
	if tier >= ItemRarity.Tier.LEGENDARY:
		for y: int in [122, 183]:
			for px: int in [6, 20]:
				_leaf_motif(canvas, center, side, PackedVector2Array([
					Vector2(px, y + 10), Vector2(px - 2, y + 5),
					Vector2(px, y + 1), Vector2(px + 2, y + 5), Vector2(px, y + 10),
				]), progress, metal.lightened(0.08))
		_leaf_line(canvas, center, side, Vector2(3, 119), Vector2(3, 216), progress, metal)
		_leaf_line(canvas, center, side, Vector2(23, 119), Vector2(23, 216), progress, metal)
	if tier == ItemRarity.Tier.ORCFECCION:
		# Tusks are carved into each leaf; they swing with the door itself.
		var tusk := PackedVector2Array([
			Vector2(8, 203), Vector2(5, 192), Vector2(8, 177),
			Vector2(9, 191), Vector2(14, 200), Vector2(20, 203),
		])
		for point: int in range(tusk.size()):
			tusk[point] = _leaf_point(center, side, tusk[point], progress)
		canvas.draw_colored_polygon(tusk, Color("d1d5a5").darkened(progress * 0.2))
		_leaf_line(canvas, center, side, Vector2(9, 146), Vector2(20, 151), progress, metal)
		_leaf_rect(canvas, center, side, Rect2(15, 152, 6, 2), progress, accent.lightened(0.3))
		_leaf_line(canvas, center, side, Vector2(4, 118), Vector2(4, 216), progress, accent.darkened(0.2))
	# A backed ring handle and its dark center read as hardware, not an item.
	_leaf_rect(canvas, center, side, Rect2(19, 164, 5, 12), progress, metal.darkened(0.55))
	_leaf_rect(canvas, center, side, Rect2(20, 166, 3, 2), progress, metal.lightened(0.15))
	_leaf_motif(canvas, center, side, PackedVector2Array([
		Vector2(21, 168), Vector2(19, 170), Vector2(19, 173),
		Vector2(22, 175), Vector2(24, 173), Vector2(24, 170), Vector2(21, 168),
	]), progress, metal)


func _leaf_point(center: int, side: int, point: Vector2, progress: float) -> Vector2:
	var angle: float = progress * PI * 0.475
	var depth: float = sin(angle) * point.x / 27.0
	return Vector2(
		roundf(center + side * 27 - side * point.x * cos(angle)),
		roundf(160.0 + (point.y - 160.0) * (1.0 - depth * 0.22))
	)


func _leaf_rect(canvas: Node2D, center: int, side: int, rect: Rect2, progress: float, color: Color) -> void:
	var corners := PackedVector2Array([
		_leaf_point(center, side, rect.position, progress),
		_leaf_point(center, side, rect.position + Vector2(rect.size.x, 0), progress),
		_leaf_point(center, side, rect.end, progress),
		_leaf_point(center, side, rect.position + Vector2(0, rect.size.y), progress),
	])
	# Subpixel-width hardware disappears naturally when the leaf turns edge-on.
	if corners[0].x == corners[1].x or corners[0].y == corners[3].y:
		return
	canvas.draw_colored_polygon(corners, color)


func _leaf_line(canvas: Node2D, center: int, side: int, start: Vector2, end: Vector2, progress: float, color: Color) -> void:
	canvas.draw_line(_leaf_point(center, side, start, progress), _leaf_point(center, side, end, progress), color, 1.0, false)


func _leaf_motif(canvas: Node2D, center: int, side: int, points: PackedVector2Array, progress: float, color: Color) -> void:
	for point: int in range(points.size()):
		points[point] = _leaf_point(center, side, points[point], progress)
	canvas.draw_polyline(points, color, 1.0, false)


func _draw_crest(center: Vector2, scale_factor: float) -> void:
	draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	# Broad jaw, pointed ears, heavy brows and upward tusks echo the wordmark.
	draw_rect(Rect2(-22, -16, 44, 37), MORTAR)
	draw_rect(Rect2(-19, -19, 38, 4), EDGE)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -12), Vector2(-29, -16), Vector2(-23, -3), Vector2(-16, 0)]), Color("54823a"))
	draw_colored_polygon(PackedVector2Array([Vector2(16, -12), Vector2(29, -16), Vector2(23, -3), Vector2(16, 0)]), Color("54823a"))
	draw_rect(Rect2(-16, -15, 32, 27), Color("648f42"))
	draw_rect(Rect2(-12, 10, 24, 8), Color("456631"))
	draw_rect(Rect2(-13, -10, 11, 4), Color("253e25"))
	draw_rect(Rect2(2, -10, 11, 4), Color("253e25"))
	draw_rect(Rect2(-11, -5, 6, 3), Color("a8bf76"))
	draw_rect(Rect2(5, -5, 6, 3), Color("a8bf76"))
	draw_rect(Rect2(-3, -2, 6, 8), Color("4c7435"))
	draw_rect(Rect2(-10, 10, 20, 2), MORTAR)
	for x: int in [-11, 8]:
		draw_rect(Rect2(x, 3, 3, 10), Color("cbd0a1"))
	draw_set_transform(Vector2.ZERO)
