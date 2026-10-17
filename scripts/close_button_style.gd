class_name CloseButtonStyle
extends RefCounted
## The Towerieary close control, shared by navigation and dismiss actions.

const THEME: Theme = preload("res://resources/ui/menu_theme.tres")


static func apply(button: Button) -> void:
	button.text = "X"
	button.custom_minimum_size = Vector2(40, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.theme = THEME
	button.theme_type_variation = &""
	button.tooltip_text = ""
	button.flat = false
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = THEME.get_stylebox(state, "Button").duplicate()
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state, style)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
