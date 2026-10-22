class_name BaseHealthFeedback
extends Control
## HUD reaction to accepted base damage: the crystal gauge flashes, the lost
## HP lingers as a pale trail that drains after a short hold, the value blinks
## red and the loss pops up beside it. Rapid leaks add into one number.
## Local real time only; the solo pause holds it with the rest of the HUD.

const NUMBERS: FontFile = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const TRAIL := Color("eadbb0")
const HIT_TEXT := Color("ffb39f")
const OUTLINE := Color("172120")
const TRAIL_HOLD: float = 0.35
const FLASH: float = 0.22
const POP: float = 1.1
## A further hit within this window adds to the number already shown.
const POP_MERGE: float = 0.6

var bar: ProgressBar
var value_label: Label
var _run: String = ""
var _health: int = -1
var _maximum: int = 1
## Health the pale trail still reaches, in HP.
var trail: float = 0.0
var _hold: float = 0.0
var _flash: float = 0.0
var pop_amount: int = 0
var _pop_age: float = POP


func _init() -> void:
	name = "BaseHealthFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Mirrors one accepted value; only a drop within the same run reacts.
func observe(run: String, health: int, maximum: int) -> void:
	maximum = maxi(1, maximum)
	if run != _run or _health < 0 or maximum != _maximum:
		var new_run: bool = run != _run
		_run = run
		_health = health
		_maximum = maximum
		trail = health
		if new_run:
			reset()
		queue_redraw()
		return
	if health < _health:
		var damage: int = _health - health
		trail = maxf(trail, float(_health))
		_hold = TRAIL_HOLD
		_flash = FLASH
		pop_amount = pop_amount + damage if _pop_age < POP_MERGE else damage
		_pop_age = 0.0
		set_process(true)
	elif float(health) > trail:
		trail = health
	_health = health
	queue_redraw()


func reset() -> void:
	trail = maxf(0.0, float(_health))
	_hold = 0.0
	_flash = 0.0
	pop_amount = 0
	_pop_age = POP
	if bar != null:
		_tint_value(0.0)
	set_process(false)
	queue_redraw()


func is_active() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_pop_age = minf(POP, _pop_age + delta)
	if _hold > 0.0:
		_hold -= delta
	elif trail > _health:
		trail = lerpf(trail, float(_health), 1.0 - exp(-6.0 * delta))
		# Snap once the remaining trail is under half a gauge pixel.
		var width: float = bar.size.x if bar != null else 154.0
		if (trail - _health) / _maximum * width < 0.5:
			trail = _health
	_tint_value(clampf(1.0 - _pop_age / 0.45, 0.0, 1.0))
	if _flash <= 0.0 and _pop_age >= POP and trail <= _health:
		pop_amount = 0
		set_process(false)
	queue_redraw()


func _tint_value(amount: float) -> void:
	if value_label != null:
		value_label.self_modulate = Color.WHITE.lerp(HIT_TEXT, amount)


func _local_rect(control: Control) -> Rect2:
	var global: Rect2 = control.get_global_rect()
	return Rect2(get_global_transform().affine_inverse() * global.position, global.size)


func _draw() -> void:
	if bar == null or not bar.is_visible_in_tree():
		return
	var track: Rect2 = _local_rect(bar)
	var filled: float = roundf(track.size.x * clampf(float(_health) / _maximum, 0.0, 1.0))
	var trailing: float = roundf(track.size.x * clampf(trail / _maximum, 0.0, 1.0))
	if trailing > filled:
		draw_rect(Rect2(track.position + Vector2(filled, 0.0), Vector2(trailing - filled, track.size.y)), TRAIL)
	if _flash > 0.0 and filled > 0.0:
		draw_rect(Rect2(track.position, Vector2(filled, track.size.y)), Color(1.0, 1.0, 1.0, 0.55 * _flash / FLASH))
	if pop_amount > 0 and _pop_age < POP and value_label != null:
		var t: float = _pop_age / POP
		var alpha: float = clampf((1.0 - t) / 0.4, 0.0, 1.0)
		var anchor: Rect2 = _local_rect(value_label)
		var font_size: int = 20 if pop_amount < 10 else 24
		var baseline := Vector2(anchor.end.x + 8.0, anchor.position.y + anchor.size.y * 0.5 + font_size * 0.4 - 10.0 * (1.0 - (1.0 - t) * (1.0 - t)))
		var text: String = "-%d" % pop_amount
		draw_string_outline(NUMBERS, baseline.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(OUTLINE, alpha))
		draw_string(NUMBERS, baseline.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(HIT_TEXT, alpha))
