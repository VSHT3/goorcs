class_name ItemieryRoom
extends Node2D
## Authored at 640×360; the screen scales the viewport with nearest filtering.

const FONT: Font = preload("res://assets/fonts/PixelifySans.ttf")
const MORTAR := Color("151e1b")
const STONE := Color("303d35")
const EDGE := Color("465244")
const LIGHT := Color("64705a")
const DARK := Color("101915")
const CENTERS: PackedInt32Array = [68, 152, 236, 320, 404, 488, 572]


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
	# Empty niches: no item silhouettes, fake locks or promised rewards.
	for index: int in range(CENTERS.size()):
		_draw_niche(index)
	_draw_crest(Vector2(320, 48), 1.0)
	# Iron lintel braces and restrained wall decoration.
	for x: int in [37, 595]:
		draw_rect(Rect2(x, 32, 8, 24), DARK)
		draw_rect(Rect2(x + 2, 35, 4, 17), EDGE)
		draw_rect(Rect2(x + 3, 38, 2, 2), LIGHT)
		draw_rect(Rect2(x + 3, 47, 2, 2), LIGHT)


func _draw_niche(index: int) -> void:
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
	# The rarity appears in the crest, the plinth inlay and the carved name.
	draw_rect(Rect2(x - 7, 81, 14, 7), STONE)
	draw_rect(Rect2(x - 3, 82, 6, 4), tint)
	for y: int in [128, 158, 188]:
		draw_line(Vector2(x - 20, y), Vector2(x + 20, y), Color("111b15"))
	draw_ellipse_shadow(Vector2(x, 234))
	draw_rect(Rect2(x - 28, 230, 56, 9), MORTAR)
	draw_rect(Rect2(x - 25, 225, 50, 9), EDGE)
	draw_rect(Rect2(x - 21, 202, 42, 25), STONE)
	draw_rect(Rect2(x - 17, 205, 34, 19), Color("26332b"))
	draw_rect(Rect2(x - 27, 196, 54, 8), LIGHT)
	draw_rect(Rect2(x - 29, 193, 58, 5), EDGE)
	draw_rect(Rect2(x - 23, 194, 46, 2), Color("7b8369"))
	draw_rect(Rect2(x - 8, 210, 16, 3), tint.darkened(0.3))
	# Higher tiers earn extra metalwork without representing actual items.
	if index >= ItemRarity.Tier.EPIC:
		for side: int in [-1, 1]:
			draw_rect(Rect2(x + side * 20 - 1, 199, 2, 27), tint.darkened(0.5))
	if index >= ItemRarity.Tier.LEGENDARY:
		for side: int in [-1, 1]:
			draw_rect(Rect2(x + side * 12 - 1, 75, 3, 6), tint.darkened(0.25))
			draw_rect(Rect2(x + side * 19 - 1, 78, 3, 4), tint.darkened(0.25))
	if index == ItemRarity.Tier.ORCFECCION:
		_draw_crest(Vector2(x, 62), 0.45)
	draw_rect(Rect2(x - 38, 253, 76, 20), MORTAR)
	draw_line(Vector2(x - 35, 254), Vector2(x + 35, 254), EDGE)
	var text: String = ItemRarity.NAMES[index]
	var text_width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(FONT, Vector2(x - floorf(text_width * 0.5), 267), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)


func draw_ellipse_shadow(center: Vector2) -> void:
	# Squared pixel shadow under the stone footing.
	draw_rect(Rect2(center - Vector2(31, 0), Vector2(62, 5)), Color("131e17"))
	draw_rect(Rect2(center - Vector2(25, -5), Vector2(50, 2)), Color("19241c"))


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
