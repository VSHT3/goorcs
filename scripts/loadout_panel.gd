class_name LoadoutPanel
extends Control

signal leave_requested

var planning: MatchPlanning
var tower_buttons: Dictionary[StringName, Button] = {}
var commit_button: Button
var leave_button: Button
var _count: Label
var _status: Label
var _notice: Label
var _pending_selection: Array[StringName] = []
var _pending_commit: bool = false


func _ready() -> void:
	theme = preload("res://resources/ui/menu_theme.tres")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 660
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := Label.new()
	title.text = "Choose your loadout"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)
	leave_button = Button.new()
	leave_button.name = "LeaveLoadout"
	CloseButtonStyle.apply(leave_button)
	MenuAudio.bind_action(leave_button)
	leave_button.pressed.connect(_leave)
	header.add_child(leave_button)
	var hint := Label.new()
	hint.text = "Equip one to four unlocked towers. Empty slots are fine.\nYour choices stay private until you build. Committing locks this run."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	column.add_child(hint)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf"))
	_count.add_theme_font_size_override("font_size", 16)
	column.add_child(_count)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for definition: TowerDefinition in planning.combat_rules.catalog.towers:
		var reward: TowerReward = definition.reward
		var button := _button(String(reward.id))
		button.activation_sound_enabled = false
		button.custom_minimum_size = Vector2(324, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.icon = reward.icon_texture
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 48)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_toggle.bind(reward.id))
		grid.add_child(button)
		tower_buttons[reward.id] = button
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	column.add_child(_status)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size.y = 24
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 16)
	column.add_child(_notice)
	commit_button = _button("CommitLoadout")
	commit_button.text = "Commit loadout"
	commit_button.theme_type_variation = &"PrimaryButton"
	commit_button.pressed.connect(_commit)
	column.add_child(commit_button)
	planning.changed.connect(_refresh)
	planning.feedback.connect(_show_notice)
	_refresh()


func _button(control_name: String) -> GameMenuButton:
	var button: GameMenuButton = preload("res://scripts/menu_button.gd").new()
	button.name = control_name
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _toggle(id: StringName) -> void:
	if not _pending_selection.is_empty() or _pending_commit or not tower_buttons.has(id) or tower_buttons[id].disabled:
		_refresh()
		return
	var ids: Array = planning.chosen_tower_ids.duplicate()
	if ids.has(id):
		if ids.size() == 1:
			_refresh()
			return
		ids.erase(id)
	else:
		ids.append(id)
	# Guest submission does not update the accepted snapshot. Lock edits until
	# that exact replacement is acknowledged, not merely any changed signal.
	_pending_selection.assign(ids)
	_notice.text = ""
	if not planning.select_loadout(ids):
		_pending_selection.clear()
	_refresh()


func _commit() -> void:
	if commit_button.disabled or not _pending_selection.is_empty() or _pending_commit:
		return
	_pending_commit = true
	_notice.text = ""
	if not planning.commit_loadout():
		_pending_commit = false
	_refresh()


func _clear_pending() -> void:
	_pending_selection.clear()
	_pending_commit = false


func _leave() -> void:
	_clear_pending()
	leave_requested.emit()


func _exit_tree() -> void:
	_clear_pending()


func _show_notice(message: String) -> void:
	_clear_pending()
	_refresh()
	if planning.selecting_loadout:
		_notice.text = message


func _refresh() -> void:
	if not is_node_ready():
		return
	if not planning.selecting_loadout or planning.loadout_committed:
		_clear_pending()
	elif planning.chosen_tower_ids == _pending_selection:
		_pending_selection.clear()
	var waiting: bool = not _pending_selection.is_empty() or _pending_commit
	_count.text = "%d / 4 equipped" % planning.chosen_tower_ids.size()
	for definition: TowerDefinition in planning.combat_rules.catalog.towers:
		var reward: TowerReward = definition.reward
		var button: Button = tower_buttons[reward.id]
		var owned: bool = planning.collection_store == null or (planning.collection_store.error_message.is_empty() and planning.collection_store.is_unlocked(reward.id))
		var equipped: bool = planning.is_equipped(reward.id)
		button.text = reward.title + (" · locked" if not owned else "")
		button.set_pressed_no_signal(equipped)
		button.disabled = waiting or not planning.selecting_loadout or planning.loadout_committed or not owned or (not equipped and planning.chosen_tower_ids.size() >= 4)
		button.tooltip_text = "Unlock in Collection" if not owned else reward.description
	commit_button.disabled = waiting or not planning.selecting_loadout or planning.loadout_committed or planning.chosen_tower_ids.is_empty()
	commit_button.text = "Waiting for host…" if waiting else ("Committed" if planning.loadout_committed else "Commit loadout")
	_status.text = "You: %s   ·   Friend: %s" % ["committed" if planning.loadout_committed else "choosing", "committed" if planning.opponent_committed else "choosing"]
	if planning.singleplayer:
		_status.text = "Your opponent will mirror this loadout."
	if not planning.selecting_loadout:
		_notice.text = ""
