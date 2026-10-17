class_name MatchResultsMenu
extends Control

signal menu_requested
signal replay_requested
signal inspect_requested

const NUMBERS: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")

var replay_button: Button
var inspect_button: Button
var menu_button: Button
var _title: Label
var _reason: Label
var _round: Label
var _health: Label
var _kills: Label
var _sent: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.04,0.035,0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(510,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16241e")
	style.border_color = Color("697a62")
	style.set_border_width_all(1)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	panel.add_child(content)
	_title = _label(content,36)
	_reason = _label(content,18)
	_round = _label(content,20,true)
	var divider := HSeparator.new()
	content.add_child(divider)
	_health = _label(content,16,true)
	var totals := HBoxContainer.new()
	totals.add_theme_constant_override("separation",24)
	content.add_child(totals)
	_kills = _label(totals,16,true)
	_sent = _label(totals,16,true)
	replay_button = _button(content,"Play again",func() -> void: replay_requested.emit())
	replay_button.theme_type_variation = &"PrimaryButton"
	inspect_button = _button(content,"View battlefield",func() -> void: inspect_requested.emit())
	menu_button = _button(content,"Main menu",func() -> void: menu_requested.emit())


func _label(parent: Node, font_size: int, numeric: bool = false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	if numeric:
		label.add_theme_font_override("font",NUMBERS)
	parent.add_child(label)
	return label


func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0,46)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	MenuAudio.bind_action(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func open_result(state: Dictionary, slot: int, solo: bool) -> void:
	var won: bool = int(state.get("winner",-1)) == slot
	_title.text = "Victory" if won else "Defeat"
	_title.modulate = Color("e0bc77") if won else Color("e0a08d")
	_reason.text = "Both crystals fell. The coin flip decided this run." if bool(state.get("coin_flip",false)) else ("The opposing crystal has fallen." if won else "Your crystal has fallen.")
	_round.text = "Round %d" % int(state.get("wave",0))
	var health: Array = state.get("health",[0,0])
	_health.text = "Your HP %d  ·  %s HP %d" % [int(health[slot]),"Mirror" if solo else "Opponent",int(health[1-slot])]
	var own: Dictionary = state.get("enemy_totals",[{},{ }])[slot]
	_kills.text = "Killed %d" % _sum(own.get("kills",{}))
	_sent.text = "Sent %d" % _sum(own.get("sent",{}))
	replay_button.visible = solo
	var first: Button = replay_button if solo else inspect_button
	first.focus_neighbor_top = first.get_path_to(menu_button)
	first.focus_neighbor_bottom = first.get_path_to(inspect_button if solo else menu_button)
	first.focus_next = first.focus_neighbor_bottom
	first.focus_previous = first.focus_neighbor_top
	inspect_button.focus_neighbor_top = inspect_button.get_path_to(replay_button if solo else menu_button)
	inspect_button.focus_neighbor_bottom = inspect_button.get_path_to(menu_button)
	inspect_button.focus_next = inspect_button.focus_neighbor_bottom
	inspect_button.focus_previous = inspect_button.focus_neighbor_top
	menu_button.focus_neighbor_top = menu_button.get_path_to(inspect_button)
	menu_button.focus_neighbor_bottom = menu_button.get_path_to(first)
	menu_button.focus_next = menu_button.focus_neighbor_bottom
	menu_button.focus_previous = menu_button.focus_neighbor_top
	show()
	first.grab_focus()
	first.grab_focus.call_deferred()


func _sum(values: Dictionary) -> int:
	var total: int = 0
	for count: int in values.values():
		total += count
	return total
