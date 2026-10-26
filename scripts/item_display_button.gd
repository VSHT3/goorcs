class_name ItemDisplayButton
extends Button
## An unframed exhibit with a crisp, continuous hover and selection perimeter.

var accent: Color = Color.WHITE


func _ready() -> void:
	flat = true
	toggle_mode = true
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(3)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_selected: bool) -> void: queue_redraw())


func _draw() -> void:
	if not button_pressed and not has_focus() and not is_hovered():
		return
	var tint: Color = accent if button_pressed else accent.lightened(0.2)
	var bounds := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(bounds, Color(tint, 0.08))
	draw_rect(bounds, tint, false, 2.0)
	if has_focus():
		draw_rect(bounds.grow(-3), Color("f0f6dc"), false, 1.0)
