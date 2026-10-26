class_name ItemDisplayButton
extends Button
## An unframed exhibit; corners mark selection without covering the artwork.

var accent: Color = Color.WHITE


func _ready() -> void:
	flat = true
	toggle_mode = true
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(func() -> void:
		grab_focus()
		queue_redraw())
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_selected: bool) -> void: queue_redraw())


func _draw() -> void:
	if not button_pressed and not has_focus() and not is_hovered():
		return
	var tint: Color = accent if button_pressed else Color(accent, 0.55)
	var reach: float = 5.0
	for point: Vector2 in [Vector2(1, 1), Vector2(size.x - 2, 1), Vector2(1, size.y - 2), size - Vector2(2, 2)]:
		var direction := Vector2(1 if point.x < size.x * 0.5 else -1, 1 if point.y < size.y * 0.5 else -1)
		draw_line(point, point + Vector2(direction.x * reach, 0), tint)
		draw_line(point, point + Vector2(0, direction.y * reach), tint)
