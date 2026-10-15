extends Button
## Inner pixel marks respond without moving the button or its label.

const ACCENT: Color = Color(0.878, 0.737, 0.467, 1.0)
const RESPONSE_SECONDS: float = 0.12

var _emphasis: float = 0.0:
	set(value):
		_emphasis = value
		queue_redraw()
var _response: Tween


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_update_emphasis)
	focus_entered.connect(_update_emphasis)
	focus_exited.connect(_update_emphasis)
	visibility_changed.connect(_on_visibility_changed)


func _draw() -> void:
	if _emphasis <= 0.0:
		return
	var color: Color = Color(ACCENT, _emphasis)
	var middle: float = floorf(size.y * 0.5)
	var reach: float = 4.0 + floorf(4.0 * _emphasis)
	for edge in [22.0, size.x - 24.0]:
		draw_rect(Rect2(Vector2(edge, middle - reach), Vector2(2, reach * 2.0)), color)
		var tip_x: float = edge + 2.0 if edge < size.x * 0.5 else edge - 3.0
		draw_rect(Rect2(Vector2(tip_x, middle - reach), Vector2(3, 2)), color)
		draw_rect(Rect2(Vector2(tip_x, middle + reach - 2.0), Vector2(3, 2)), color)

func _on_mouse_entered() -> void:
	if not disabled and focus_mode != Control.FOCUS_NONE:
		grab_focus()
	_update_emphasis()



func _update_emphasis() -> void:
	if _response != null:
		_response.kill()
	if not is_visible_in_tree():
		_emphasis = 0.0
		return
	var target: float = 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
	_response = create_tween()
	_response.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_response.tween_property(self, "_emphasis", target, RESPONSE_SECONDS)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		if _response != null:
			_response.kill()
		_emphasis = 0.0
	else:
		_update_emphasis()
