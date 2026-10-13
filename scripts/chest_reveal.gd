class_name ChestReveal
extends Control

signal finished

const INK := Color("141d1c")
const GOLD := Color("e0bc77")
const PALE := Color("f6e7b2")
const TEXT := Color("e6e0cf")
const CHEST_BODY_Y: int = 55
const CHEST_FOOT_Y: int = 92

@export var closed_chest: Texture2D
@export var open_chest: Texture2D

var _rewards: Array[TowerReward] = []
var _cards: Array[Control] = []
var _targets: Array[Vector2] = []
var _tween: Tween
var _active: bool = false
var _presentation_id: int = 0
var _shake: float = 0.0
var _lid: float = 0.0
var _burst: float = 0.0
var _rise: float = 0.0
var _coins: float = 0.0

@onready var _heading: Label = $Heading
@onready var _results: Control = $Results


class RewardIcon extends Control:
	var reward: TowerReward
	var locked: bool = false

	func _draw() -> void:
		if reward == null:
			return
		if reward.icon_texture != null:
			var texture_size: Vector2 = reward.icon_texture.get_size()
			var scale: float = minf(size.x / texture_size.x, size.y / texture_size.y)
			var extent: Vector2 = (texture_size * scale).floor()
			var rect := Rect2(((size - extent) * 0.5).round(), extent)
			var tint: Color = Color(0.55, 0.55, 0.55) if locked else Color.WHITE
			draw_texture_rect(reward.icon_texture, rect, false, tint)
			return
		var ink: Color = Color("65716a") if locked else reward.accent
		var pixel_scale: float = minf(size.x, size.y) / 48.0
		ChestReveal.paint_icon(self, size * 0.5 + Vector2(0.0, 4.0 * pixel_scale), pixel_scale, reward.icon_kind, ink)


func _ready() -> void:
	resized.connect(_layout_cards)
	_heading.text = "SEALED CHEST"
	queue_redraw()


func clear() -> bool:
	var previous_id: int = _presentation_id
	skip()
	if previous_id != _presentation_id:
		return false # A finished listener supplied a newer presentation.
	_presentation_id += 1
	_rewards.clear()
	for card: Control in _cards:
		_results.remove_child(card)
		card.queue_free()
	_cards.clear()
	_targets.clear()
	_shake = 0.0
	_lid = 0.0
	_burst = 0.0
	_rise = 0.0
	_coins = 0.0
	_heading.text = "SEALED CHEST"
	queue_redraw()
	return true


func present(rewards: Array[TowerReward]) -> void:
	# Clearing a replacement completes its presentation, never a second grant.
	if not clear():
		return
	_rewards = rewards.duplicate()
	_active = true
	_heading.text = "THE CHEST IS STIRRING..."
	for reward: TowerReward in _rewards:
		_cards.append(_make_card(reward))
	_layout_cards()
	queue_redraw()
	if _rewards.is_empty():
		_complete()
		return
	_tween = create_tween()
	_tween.tween_method(_set_shake, 0.0, 1.0, 1.05)
	_tween.tween_callback(_begin_opening)
	_tween.tween_method(_set_lid, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_burst, 0.0, 1.0, 0.55)
	_tween.parallel().tween_method(_set_rise, 0.0, 1.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_coins, 0.0, 1.0, 1.4)
	_tween.tween_callback(_complete)


func skip() -> void:
	if _active:
		_complete()


func is_revealing() -> bool:
	return _active


func _exit_tree() -> void:
	skip()


func _complete() -> void:
	if not _active:
		return
	_active = false
	if _tween != null:
		_tween.kill()
		_tween = null
	_shake = 0.0
	_lid = 1.0
	_burst = 1.0
	_coins = 1.0
	_set_rise(1.0)
	_heading.text = "NEW TOWER UNLOCKED" if _rewards.size() == 1 else "%d NEW TOWERS UNLOCKED" % _rewards.size()
	if _rewards.is_empty():
		_heading.text = "NO REWARDS TO DISPLAY"
	queue_redraw()
	finished.emit()


func _begin_opening() -> void:
	_shake = 0.0
	_heading.text = "YOUR NEW TOWERS"


func _set_shake(value: float) -> void:
	_shake = sin(value * TAU * 9.0) * (3.0 + value * 6.0) if value < 1.0 else 0.0
	queue_redraw()


func _set_lid(value: float) -> void:
	_lid = value
	queue_redraw()


func _set_burst(value: float) -> void:
	_burst = value
	queue_redraw()


func _set_coins(value: float) -> void:
	_coins = value
	queue_redraw()


func _set_rise(value: float) -> void:
	_rise = value
	for index: int in range(_cards.size()):
		var card: Control = _cards[index]
		var source := Vector2(size.x * 0.5 - card.size.x * 0.5, size.y - 150.0)
		card.position = source.lerp(_targets[index], value).round()
		card.modulate.a = value


func _make_card(reward: TowerReward) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24332e")
	style.border_color = reward.accent.darkened(0.2)
	style.set_border_width_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var icon := RewardIcon.new()
	icon.reward = reward
	icon.custom_minimum_size = Vector2(0.0, 32.0 if _rewards.size() > 3 else 52.0)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var title := Label.new()
	title.text = reward.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = reward.title
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TEXT)
	content.add_child(title)
	var tag := Label.new()
	tag.text = "UNLOCKED"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", GOLD)
	content.add_child(tag)
	_results.add_child(card)
	return card


func _layout_cards() -> void:
	if _cards.is_empty():
		queue_redraw()
		return
	# One and three rise as one row; five use a centered three-over-two arrangement.
	# Larger caller-supplied arrays use the same grid without dropping rewards.
	var columns: int = mini(3, _cards.size())
	var rows: int = ceili(float(_cards.size()) / float(columns))
	var gap: float = 12.0
	var width: float = minf(184.0, (size.x - 40.0 - gap * (columns - 1)) / columns)
	var available_height: float = _chest_rect().position.y - 62.0 - 12.0
	var height: float = minf(190.0, (available_height - gap * (rows - 1)) / rows)
	_targets.clear()
	for index: int in range(_cards.size()):
		var row: int = floori(float(index) / float(columns))
		var row_count: int = mini(columns, _cards.size() - row * columns)
		var row_width: float = row_count * width + gap * (row_count - 1)
		var column: int = index % columns
		_cards[index].size = Vector2(width, height)
		_targets.append(Vector2((size.x - row_width) * 0.5 + column * (width + gap), 62.0 + row * (height + gap)))
	_set_rise(_rise)
	queue_redraw()


func _chest_scale() -> float:
	return 1.0 if _rewards.size() > 3 else 2.0


func _chest_rect() -> Rect2:
	var sprite_size: Vector2 = closed_chest.get_size() * _chest_scale()
	return Rect2(Vector2(roundf((size.x - sprite_size.x) * 0.5), roundf(size.y - 10.0 - sprite_size.y)), sprite_size)


func _opening_position() -> Vector2:
	var rect: Rect2 = _chest_rect()
	return rect.position + Vector2(rect.size.x * 0.5, (CHEST_BODY_Y - 3) * _chest_scale())


func _draw() -> void:
	var rect: Rect2 = _chest_rect()
	var floor_y: float = rect.position.y + CHEST_FOOT_Y * _chest_scale()
	draw_rect(Rect2(Vector2(24.0, floor_y), Vector2(size.x - 48.0, 2.0)), Color("36483d"))
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.15, floor_y - 2.0), Vector2(rect.size.x * 0.7, 6.0)), Color("101917"))
	if _lid > 0.0:
		_draw_light()
	_draw_chest()
	if _coins > 0.0 and _coins < 1.0:
		_draw_coins()


func _draw_light() -> void:
	var origin: Vector2 = _opening_position()
	var intensity: float = 0.16 + sin(_burst * PI) * 0.32
	for index: int in range(9):
		var angle: float = -PI + 0.23 + index * 0.335
		var ray_length: float = 155.0 + float(index % 3) * 35.0
		var ray_color := Color(GOLD, intensity * minf(_lid, 1.0))
		var points := PackedVector2Array([origin, origin + Vector2.from_angle(angle - 0.055) * ray_length, origin + Vector2.from_angle(angle + 0.055) * ray_length])
		draw_colored_polygon(points, ray_color)
	var glow := Color(PALE, 0.15 + sin(_burst * PI) * 0.35)
	draw_rect(Rect2(origin + Vector2(-25.0, -3.0) * _chest_scale(), Vector2(50.0, 6.0) * _chest_scale()), glow)


func _draw_chest() -> void:
	var rect: Rect2 = _chest_rect()
	rect.position.x += roundf(_shake)
	var scale: float = _chest_scale()
	var frame_size: Vector2 = closed_chest.get_size()
	var body_source := Rect2(Vector2(0.0, CHEST_BODY_Y), Vector2(frame_size.x, frame_size.y - CHEST_BODY_Y))
	var body_target := Rect2(rect.position + body_source.position * scale, body_source.size * scale)
	# Draw the original lower body once: only the lid/interior transitions.
	draw_texture_rect_region(closed_chest, body_target, body_source)
	var lid_source := Rect2(Vector2.ZERO, Vector2(frame_size.x, CHEST_BODY_Y))
	var lid_target := Rect2(rect.position, lid_source.size * scale)
	var progress: float = clampf(_lid, 0.0, 1.0)
	if progress < 1.0:
		draw_texture_rect_region(closed_chest, lid_target, lid_source, Color(1.0, 1.0, 1.0, 1.0 - progress))
	if progress > 0.0:
		draw_texture_rect_region(open_chest, lid_target, lid_source, Color(1.0, 1.0, 1.0, progress))


func _draw_coins() -> void:
	var origin: Vector2 = _opening_position()
	for index: int in range(28):
		var t: float = _coins
		var sideways: float = sin(float(index) * 2.4) * (80.0 + float(index % 5) * 23.0)
		var upward: float = 170.0 + float(index % 7) * 16.0
		var at: Vector2 = origin + Vector2(sideways * t, -upward * t + 220.0 * t * t)
		var alpha: float = 1.0 - smoothstep(0.65, 1.0, t)
		var coin_width: float = 3.0 if index % 3 == 0 else 7.0
		draw_rect(Rect2(at.round(), Vector2(coin_width, 9.0)), Color(GOLD, alpha))
		draw_rect(Rect2(at.round() + Vector2(1.0, 2.0), Vector2(2.0, 4.0)), Color(PALE, alpha))


static func _pixel(canvas: CanvasItem, x: int, y: int, width: int, height: int, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y, width, height), color)


static func paint_icon(canvas: CanvasItem, center: Vector2, pixel_scale: float, kind: int, accent: Color) -> void:
	canvas.draw_set_transform(center.round(), 0.0, Vector2.ONE * pixel_scale)
	var stone := Color("a3ac98")
	var shadow := Color("46574d")
	var wood := Color("a98350")
	_pixel(canvas, -16, 13, 32, 5, INK)
	match kind:
		0:
			_pixel(canvas, -10, -7, 20, 21, INK)
			_pixel(canvas, -8, -5, 16, 19, stone)
			_pixel(canvas, 3, -5, 5, 19, shadow)
			_pixel(canvas, -13, -12, 26, 9, INK)
			_pixel(canvas, -11, -11, 22, 6, accent)
			for x: int in [-11, -2, 7]:
				_pixel(canvas, x, -16, 4, 6, stone)
			_pixel(canvas, -3, 0, 5, 8, INK)
			_pixel(canvas, -1, -23, 2, 12, wood)
			_pixel(canvas, 1, -22, 9, 5, accent)
		1:
			_pixel(canvas, -12, 10, 24, 6, shadow)
			_pixel(canvas, -8, -17, 16, 29, INK)
			_pixel(canvas, -6, -16, 12, 28, stone)
			_pixel(canvas, 3, -14, 3, 26, shadow)
			_pixel(canvas, -4, -22, 8, 7, stone)
			_pixel(canvas, -2, -26, 4, 6, accent)
			_pixel(canvas, -3, -11, 6, 3, accent)
			_pixel(canvas, 0, -8, 3, 8, accent)
			_pixel(canvas, -3, -1, 6, 3, accent)
			_pixel(canvas, -3, 2, 3, 5, accent)
	canvas.draw_set_transform(Vector2.ZERO)
