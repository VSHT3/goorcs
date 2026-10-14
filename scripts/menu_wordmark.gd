extends Control
## A single wordmark: the orc occupies the O's advance, not a separate badge.

const TITLE_FONT: Font = preload("res://assets/fonts/PixelifySans.ttf")
const FONT_SIZE: int = 96
const PIXEL: float = 4.0
const IVORY: Color = Color(0.90, 0.88, 0.81, 1.0)
const SHADOW: Color = Color(0.035, 0.055, 0.045, 1.0)
const GREEN: Color = Color(0.48, 0.66, 0.34, 1.0)
const GREEN_LIGHT: Color = Color(0.61, 0.76, 0.43, 1.0)
const GREEN_DARK: Color = Color(0.29, 0.44, 0.24, 1.0)
const INK: Color = Color(0.085, 0.15, 0.105, 1.0)
const FACE_ROWS: Array[String] = [
	"....LLLLLL....",
	"..LLGGGGGGLL..",
	".LGGGGGGGGGGL.",
	"LGGGGGGGGGGGGL",
	"LGGGGGGGGGGGGL",
	"LGIIIGGGGIIIGL",
	"LGGEIGGGGIEGGL",
	"LGGEEGGGGEEGGL",
	"LGGGGGDDGGGGGL",
	"LGGGGDDDDGGGGL",
	"LGGTIIIIIITGGL",
	"LGGTTIIIITTGGL",
	".LGTTGGGGTTGL.",
	"..LGGGGGGGGL..",
	"....LLLLLL....",
]
const BLINK_START: float = 4.3
const BLINK_END: float = 4.46
const IDLE_START: float = 2.1
const IDLE_END: float = 2.65
const CYCLE_SECONDS: float = 6.8

var _elapsed: float = 0.0
var _eyes_closed: bool = false
var _idle_offset: float = 0.0
var _g_width: float = 0.0
var _suffix_width: float = 0.0


func _ready() -> void:
	_g_width = TITLE_FONT.get_string_size("G", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_suffix_width = TITLE_FONT.get_string_size("RCS", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(queue_redraw)
	_on_visibility_changed()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, CYCLE_SECONDS)
	var eyes_closed: bool = _elapsed >= BLINK_START and _elapsed < BLINK_END
	var idle_offset: float = -1.0 if _elapsed >= IDLE_START and _elapsed < IDLE_END else 0.0
	if eyes_closed != _eyes_closed or idle_offset != _idle_offset:
		_eyes_closed = eyes_closed
		_idle_offset = idle_offset
		queue_redraw()


func _draw() -> void:
	var face_width: float = 14.0 * PIXEL
	var gap: float = 4.0
	var word_width: float = _g_width + face_width + gap * 2.0 + _suffix_width
	var origin_x: float = floorf((size.x - word_width) * 0.5)
	# Pixelify's uppercase ink runs from -12 to 631 in a 1000-unit em.
	var baseline: float = floorf((size.y + 0.619 * FONT_SIZE) * 0.5) + _idle_offset
	var g_position: Vector2 = Vector2(origin_x, baseline)
	var suffix_position: Vector2 = Vector2(origin_x + _g_width + face_width + gap * 2.0, baseline)
	draw_string(TITLE_FONT, g_position + Vector2(2, 3), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SHADOW)
	draw_string(TITLE_FONT, suffix_position + Vector2(2, 3), "RCS", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SHADOW)
	draw_string(TITLE_FONT, g_position, "G", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, IVORY)
	draw_string(TITLE_FONT, suffix_position, "RCS", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, IVORY)
	var face_origin: Vector2 = Vector2(floorf(origin_x + _g_width + gap), baseline - 60.0)
	_draw_face(face_origin + Vector2(2, 3), true)
	_draw_face(face_origin, false)


func _draw_face(origin: Vector2, shadow: bool) -> void:
	for row_index in FACE_ROWS.size():
		var row: String = FACE_ROWS[row_index]
		for column in row.length():
			var pixel: String = row.substr(column, 1)
			if pixel == ".":
				continue
			var color: Color = GREEN
			match pixel:
				"L": color = GREEN_LIGHT
				"D": color = GREEN_DARK
				"I": color = INK
				"E", "T": color = IVORY
			if _eyes_closed and row_index >= 6 and row_index <= 7 and (column == 3 or column == 4 or column == 9 or column == 10):
				color = INK if row_index == 7 else GREEN
			if shadow:
				color = SHADOW
			draw_rect(Rect2(origin + Vector2(column * PIXEL, row_index * PIXEL), Vector2(PIXEL, PIXEL)), color)


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if not is_visible_in_tree():
		_elapsed = 0.0
		_eyes_closed = false
		_idle_offset = 0.0
	queue_redraw()
