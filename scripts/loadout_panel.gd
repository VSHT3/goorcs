class_name LoadoutPanel
extends Control

signal leave_requested

var planning: MatchPlanning
var tower_buttons: Dictionary[StringName, Button] = {}
var commander_buttons: Dictionary[StringName, Button] = {}
var _pending_commander: StringName = &""
var commit_button: Button
var leave_button: Button
var _count: Label
var _status: Label
var _notice: Label
var _pending_selection: Array[StringName] = []
var _pending_commit: bool = false
var guess_input: SpinBox
var guess_button: Button
var _pending_guess: bool = false
var _title: Label
var _hint: Label
var _guess_row: HBoxContainer
var _commander_row: HBoxContainer
var _tower_grid: GridContainer
var _draft_reveal: Label


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
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	header.add_child(_title)
	leave_button = Button.new()
	leave_button.name = "LeaveLoadout"
	CloseButtonStyle.apply(leave_button)
	MenuAudio.bind_action(leave_button)
	leave_button.pressed.connect(_leave)
	header.add_child(leave_button)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	column.add_child(_hint)
	_guess_row = HBoxContainer.new()
	_guess_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_guess_row.add_theme_constant_override("separation", 12)
	column.add_child(_guess_row)
	guess_input = SpinBox.new()
	guess_input.name = "CommanderGuess"
	guess_input.min_value = 0
	guess_input.max_value = 100
	guess_input.step = 1
	guess_input.rounded = true
	guess_input.value = 50
	guess_input.custom_minimum_size = Vector2(140, 48)
	_guess_row.add_child(guess_input)
	guess_button = _button("LockCommanderGuess")
	guess_button.text = "Lock guess"
	guess_button.pressed.connect(_submit_guess)
	_guess_row.add_child(guess_button)
	_draft_reveal = Label.new()
	_draft_reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_reveal.add_theme_font_size_override("font_size", 18)
	column.add_child(_draft_reveal)
	_commander_row = HBoxContainer.new()
	_commander_row.add_theme_constant_override("separation", 12)
	column.add_child(_commander_row)
	for id: StringName in [&"knight", &"priestess"]:
		var button := _button(String(id))
		button.custom_minimum_size = Vector2(324, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.text = "Knight · Bastion\nPhysical +15% · Rally" if id == &"knight" else "Priestess · Sanctuary\nAttack rate +15% · Stasis"
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_choose_commander.bind(id))
		_commander_row.add_child(button)
		commander_buttons[id] = button
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf"))
	_count.add_theme_font_size_override("font_size", 16)
	column.add_child(_count)
	_tower_grid = GridContainer.new()
	_tower_grid.columns = 2
	_tower_grid.add_theme_constant_override("h_separation", 12)
	_tower_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(_tower_grid)
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
		_tower_grid.add_child(button)
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
	visibility_changed.connect(_focus_phase)
	planning.feedback.connect(_show_notice)
	_refresh()


func _button(control_name: String) -> GameMenuButton:
	var button: GameMenuButton = preload("res://scripts/menu_button.gd").new()
	button.name = control_name
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _submit_guess() -> void:
	if guess_button.disabled:
		return
	_pending_guess = true
	_notice.text = ""
	if not planning.submit_commander_guess(int(guess_input.value)):
		_pending_guess = false
	_refresh()



func _choose_commander(id: StringName) -> void:
	if not commander_buttons.has(id) or commander_buttons[id].disabled:
		return
	_pending_commander = id
	_notice.text = ""
	if not planning.select_commander(id):
		_pending_commander = &""
	_refresh()


func _toggle(id: StringName) -> void:
	if not _pending_selection.is_empty() or _pending_commander != &"" or _pending_commit or not tower_buttons.has(id) or tower_buttons[id].disabled:
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
	if commit_button.disabled or not _pending_selection.is_empty() or _pending_commander != &"" or _pending_commit:
		return
	_pending_commit = true
	_notice.text = ""
	if not planning.commit_loadout():
		_pending_commit = false
	_refresh()


func _clear_pending() -> void:
	_pending_selection.clear()
	_pending_commit = false
	_pending_commander = &""
	_pending_guess = false


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

func _focus_phase() -> void:
	if not is_node_ready() or not is_visible_in_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and focus.is_visible_in_tree() and is_ancestor_of(focus):
		return
	if planning.commander_draft.get("phase", "") == "guessing" and not guess_button.disabled:
		guess_input.get_line_edit().grab_focus()
	elif planning.commander_draft.get("phase", "") == "picking":
		for button: Button in commander_buttons.values():
			if not button.disabled:
				button.grab_focus()
				return
	elif not commit_button.disabled:
		commit_button.grab_focus()



func _refresh() -> void:
	if not is_node_ready():
		return
	var draft: Dictionary = planning.commander_draft
	var phase: String = draft.get("phase", "guessing")
	var slot: int = planning.local_slot()
	var locked: bool = draft.get("guess_locked", [false, false])[slot]
	var picks: Array = draft.get("picks", ["", ""])
	if not planning.selecting_loadout or planning.loadout_committed:
		_clear_pending()
	elif planning.chosen_tower_ids == _pending_selection:
		_pending_selection.clear()
	if locked:
		_pending_guess = false
	if planning.chosen_commander_id == _pending_commander or phase != "picking":
		_pending_commander = &""
	var waiting: bool = not _pending_selection.is_empty() or _pending_commander != &"" or _pending_commit or _pending_guess
	var loadout: bool = phase == "loadout"
	_title.text = "Guess the number" if phase == "guessing" else ("Choose your hero" if not loadout else "Choose your loadout")
	_hint.text = "0–100" if phase == "guessing" else ("Your pick" if int(draft.get("picker", -1)) == slot else "Opponent is picking")
	_hint.visible = not loadout
	_guess_row.visible = phase == "guessing"
	guess_input.editable = not locked and not waiting
	guess_button.disabled = locked or waiting or phase != "guessing" or not planning.selecting_loadout
	guess_button.text = "Locked" if locked else ("Waiting…" if _pending_guess else "Lock guess")
	_draft_reveal.visible = phase != "guessing"
	if phase != "guessing":
		var guesses: Array = draft.get("guesses", [-1, -1])
		_draft_reveal.text = "Target %d · You %d · Opponent %d\nFirst pick: %s" % [int(draft.get("target", -1)), int(guesses[slot]), int(guesses[1 - slot]), "You" if int(draft.get("first_picker", -1)) == slot else "Opponent"]
	_commander_row.visible = phase != "guessing"
	for id: StringName in commander_buttons:
		var owner: String = " · You" if String(picks[slot]) == String(id) else (" · Opponent" if String(picks[1 - slot]) == String(id) else "")
		var text: String = "Knight · Bastion\nPhysical +15% · Rally" if id == &"knight" else "Priestess · Sanctuary\nAttack rate +15% · Stasis"
		commander_buttons[id].text = text + owner
		commander_buttons[id].set_pressed_no_signal(String(picks[slot]) == String(id))
		commander_buttons[id].disabled = waiting or phase != "picking" or int(draft.get("picker", -1)) != slot or picks.has(String(id)) or not planning.selecting_loadout
	_count.visible = loadout
	_tower_grid.visible = loadout
	_count.text = "%d / 4 equipped" % planning.chosen_tower_ids.size()
	for definition: TowerDefinition in planning.combat_rules.catalog.towers:
		var reward: TowerReward = definition.reward
		var button: Button = tower_buttons[reward.id]
		var owned: bool = planning.collection_store == null or (planning.collection_store.error_message.is_empty() and planning.collection_store.is_unlocked(reward.id))
		var equipped: bool = planning.is_equipped(reward.id)
		button.text = reward.title + (" · locked" if not owned else "")
		button.set_pressed_no_signal(equipped)
		button.disabled = not loadout or waiting or not planning.selecting_loadout or planning.loadout_committed or not owned or (not equipped and planning.chosen_tower_ids.size() >= 4)
		button.tooltip_text = "Unlock in Collection" if not owned else reward.description
	commit_button.visible = loadout
	commit_button.disabled = not loadout or waiting or not planning.selecting_loadout or planning.loadout_committed or planning.chosen_tower_ids.is_empty()
	commit_button.text = "Waiting for host…" if waiting else ("Committed" if planning.loadout_committed else "Commit loadout")
	_status.text = "Guess locked · Waiting for opponent" if locked else ""
	if loadout:
		_status.text = "You: %s   ·   Opponent: %s" % ["committed" if planning.loadout_committed else "choosing towers", "committed" if planning.opponent_committed else "choosing towers"]
	elif phase == "picking":
		_status.text = ""
	if not planning.selecting_loadout:
		_notice.text = ""
	_focus_phase.call_deferred()
