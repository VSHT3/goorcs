extends Node2D
## Accents stay on wall fixtures, ornament and floor, leaving item art untouched.

const LIGHT_COLORS: Array[Color] = [
	Color("f4d18a"), Color("ede4a6"), Color("d1f0e2"), Color("f3dbef"),
	Color("ffe2a0"), Color("fff0b5"), Color("d8f3b1"),
]
const SHELF_ROWS: int = 5
const FIXTURE_X: PackedInt32Array = [42, 598]
const CHANNEL_X: PackedInt32Array = [31, 591]
const OFFERING_X: PackedInt32Array = [102, 538]

var _tier: ItemRarity.Tier = ItemRarity.Tier.COMMON
var _elapsed: float = 0.0
var _frame: int = -1
var _active: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(false)


func configure(tier: ItemRarity.Tier) -> void:
	_tier = tier
	_elapsed = 0.0
	_frame = -1
	set_process(_active and _tier >= ItemRarity.Tier.MYTHIC)
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active and _tier >= ItemRarity.Tier.MYTHIC)
	if not active:
		_elapsed = 0.0
		_frame = -1
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var frame: int = int(_elapsed * 12.0)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var light: Color = LIGHT_COLORS[int(_tier)]
	var pulse: float = 1.0
	if _tier >= ItemRarity.Tier.MYTHIC:
		pulse = 0.88 + sin(_elapsed * 2.3) * 0.08 + sin(_elapsed * 5.7) * 0.04
	var lamp_y: int = 145 if _tier == ItemRarity.Tier.MYTHIC else 139
	for x: int in FIXTURE_X:
		# Quantized warm/cool spill is confined to the fixture's wall column.
		draw_rect(Rect2(x - 15, lamp_y - 22, 30, 44), Color(light, 0.035 * pulse))
		draw_rect(Rect2(x - 10, lamp_y - 14, 20, 29), Color(light, 0.065 * pulse))
		if _tier == ItemRarity.Tier.RARE or _tier == ItemRarity.Tier.LEGENDARY:
			draw_rect(Rect2(x - 13, 208, 26, 33), Color(light, 0.05 * pulse))
	if _tier == ItemRarity.Tier.MYTHIC:
		_draw_brazier_embers(light)
	elif _tier == ItemRarity.Tier.LEGENDARY:
		# A rare pinpoint glint on the treasury's two polished capitals.
		for index: int in range(2):
			var phase: float = fmod(_elapsed * 0.19 + float(index) * 0.5, 1.0)
			if phase < 0.12:
				var x: int = FIXTURE_X[index]
				_draw_gleam(Vector2(x, 74), Color(light, sin(phase / 0.12 * PI) * 0.7))
	elif _tier == ItemRarity.Tier.ORCFECCION:
		_draw_temple_accents(light)


func _draw_brazier_embers(light: Color) -> void:
	for side: int in range(2):
		for index: int in range(3):
			var phase: float = fmod(_elapsed * 0.21 + float(index) / 3.0 + float(side) * 0.17, 1.0)
			var x: float = FIXTURE_X[side] + floorf(sin(phase * 4.0 + float(index)) * 7.0)
			var y: float = floorf(130.0 - phase * 39.0)
			draw_rect(Rect2(x, y, 1, 2), Color(light, sin(phase * PI) * 0.65))


func _draw_temple_accents(light: Color) -> void:
	# Breathing crest eyes and narrow channels are separate from the PNG.
	var breath: float = 0.16 + sin(_elapsed * 1.3) * 0.07
	draw_rect(Rect2(302, 29, 10, 2), Color(light, breath))
	draw_rect(Rect2(329, 29, 10, 2), Color(light, breath))
	for x: int in CHANNEL_X:
		draw_rect(Rect2(x, 168, 1, 64), Color("81d783", breath * 0.6))
	# Light travels on shelf-front metal, below the actual 36px item rectangles.
	var sweep: float = fmod(_elapsed * 31.0, 650.0)
	if sweep < 482.0:
		var x: float = 79.0 + floorf(sweep)
		for row: int in range(SHELF_ROWS):
			var alpha: float = 0.28 + 0.12 * sin(float(row) + _elapsed)
			draw_rect(Rect2(x, 97 + row * 44, 3, 1), Color(light, alpha))
	for index: int in range(12):
		var phase: float = fmod(_elapsed * 0.095 + float(index) / 12.0, 1.0)
		var side: int = index % 2
		var x: float = (39.0 if side == 0 else 601.0) + floorf(sin(float(index) * 2.4 + phase * 4.0) * 15.0)
		var y: float = floorf(261.0 - phase * 188.0)
		draw_rect(Rect2(x, y, 1 + index % 2, 1), Color("a2e89a", sin(phase * PI) * 0.7))
	# Occasional asymmetric gleams make the immense tusks feel polished.
	for index: int in range(4):
		var phase: float = fmod(_elapsed * 0.13 + float(index) * 0.29, 1.0)
		if phase < 0.16:
			var x: float = 34.0 if index % 2 == 0 else 606.0
			var y: float = 95.0 + float(index >> 1) * 139.0
			_draw_gleam(Vector2(x, y), Color(light, sin(phase / 0.16 * PI) * 0.8))
	for x: int in OFFERING_X:
		draw_rect(Rect2(x - 12, 299, 24, 15), Color("81d783", 0.04 + breath * 0.2))


func _draw_gleam(at: Vector2, tint: Color) -> void:
	draw_rect(Rect2(at.x - 3, at.y, 7, 1), tint)
	draw_rect(Rect2(at.x, at.y - 3, 1, 7), tint)
	draw_rect(Rect2(at.x - 1, at.y - 1, 3, 3), Color(tint, tint.a * 0.5))
