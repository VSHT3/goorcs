class_name TargetingCycle
extends HBoxContainer

signal mode_requested(mode: int)

const DISPLAY_ORDER: Array[int] = [
	MatchCombat.TargetMode.FURTHEST,
	MatchCombat.TargetMode.LAST,
	MatchCombat.TargetMode.CLOSEST,
	MatchCombat.TargetMode.STRONGEST,
]
const TITLES: Dictionary[int, String] = {
	MatchCombat.TargetMode.FURTHEST: "First",
	MatchCombat.TargetMode.LAST: "Last",
	MatchCombat.TargetMode.CLOSEST: "Closest",
	MatchCombat.TargetMode.STRONGEST: "Strongest",
}

var mode: int = MatchCombat.TargetMode.FURTHEST:
	set(value):
		if mode == value:
			return
		mode = value
		if is_node_ready():
			_refresh()
var disabled: bool = false:
	set(value):
		if disabled == value:
			return
		disabled = value
		if is_node_ready():
			_refresh()
var previous_button: Button
var mode_label: Label
var next_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	previous_button = Button.new()
	previous_button.name = "Previous"
	previous_button.text = "<"
	previous_button.custom_minimum_size = Vector2(20, 24)
	previous_button.focus_mode = Control.FOCUS_ALL
	previous_button.pressed.connect(_request_step.bind(-1))
	add_child(previous_button)
	mode_label = Label.new()
	mode_label.name = "CurrentMode"
	mode_label.custom_minimum_size.x = 80
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(mode_label)
	next_button = Button.new()
	next_button.name = "Next"
	next_button.text = ">"
	next_button.custom_minimum_size = Vector2(20, 24)
	next_button.focus_mode = Control.FOCUS_ALL
	next_button.pressed.connect(_request_step.bind(1))
	add_child(next_button)
	var arrow_style := StyleBoxEmpty.new()
	for button: Button in [previous_button, next_button]:
		button.flat = true
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_hover_color", Color(0.878, 0.737, 0.467))
		button.add_theme_color_override("font_focus_color", Color(0.878, 0.737, 0.467))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, arrow_style)
	_refresh()


func _request_step(direction: int) -> void:
	if disabled or not is_visible_in_tree():
		return
	var index: int = DISPLAY_ORDER.find(mode)
	if index < 0:
		return
	# Only the consumer's accepted snapshot changes mode; requests never advance it.
	mode_requested.emit(DISPLAY_ORDER[posmod(index + direction, DISPLAY_ORDER.size())])


func _refresh() -> void:
	mode_label.text = TITLES.get(mode, "")
	previous_button.disabled = disabled
	next_button.disabled = disabled
	mode_label.modulate = Color("91a191") if disabled else Color.WHITE
