class_name ItemRuntimePanel
extends Control
## Presentation of accepted item state; commands never mutate a local inventory.

signal command_requested(id: StringName, action: String, target_id: int)
signal owned_set_requested(ids: Array)
signal expanded_changed(expanded: bool)
const MATCH_THEME: Theme = preload("res://resources/ui/match_theme.tres")

const ACTION_TITLES: Dictionary = {"active": "Activate", "activate": "Activate", "bind": "Bind", "feed": "Feed", "upgrade": "Upgrade"}

var toggle_button: Button
var close_button: Button
var editor_button: Button
var all_button: Button
var none_button: Button
var search: LineEdit
var scroll: ScrollContainer
var action_buttons: Dictionary[String, Button] = {}
var target_selectors: Dictionary[String, OptionButton] = {}
var owned_buttons: Dictionary[String, Button] = {}
var editor_checks: Dictionary[String, CheckBox] = {}
var expanded: bool = false
var editing: bool = false
var sandbox: bool = false
var _body: PanelContainer
var _actions: VBoxContainer
var _inventory: GridContainer
var _editor: VBoxContainer
var _editor_tools: HBoxContainer
var _details: Label
var _empty: Label
var _entries: Dictionary = {}
var _types: Dictionary = {}
var _owned: Array = []
var _towers: Dictionary = {}
var _art: Dictionary = {}
var _action_rows: Dictionary = {}
var _action_labels: Dictionary = {}
var _action_status: Dictionary = {}
var _command_records: Dictionary = {}
var _enabled: bool = false
var _selected: String = ""
var _structure_key: String = ""


func configure(catalog: ContentCatalog, allow_editor: bool = false) -> void:
	sandbox = allow_editor
	for definition: ItemDefinition in catalog.items:
		_art[String(definition.id)] = definition.icon_texture
	if is_node_ready():
		editor_button.visible = sandbox


func _ready() -> void:
	theme = MATCH_THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 16)
	toggle_button = _button(self, "Items · 0", _toggle)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toggle_button.offset_bottom = 36
	_body = PanelContainer.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.offset_top = 42
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2521")
	style.border_color = Color("667666")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_body.add_theme_stylebox_override("panel", style)
	add_child(_body)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	_body.add_child(shell)
	var heading := HBoxContainer.new()
	shell.add_child(heading)
	var title := _label(heading, "Owned items")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_button = _button(heading, "Edit set", _toggle_editor)
	editor_button.visible = sandbox
	close_button = _button(heading, "X", close)
	CloseButtonStyle.apply(close_button)
	_editor_tools = HBoxContainer.new()
	shell.add_child(_editor_tools)
	all_button = _button(_editor_tools, "All 130", _set_all)
	none_button = _button(_editor_tools, "None", _set_none)
	search = LineEdit.new()
	search.placeholder_text = "Find item"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", 16)
	search.text_changed.connect(_filter_editor)
	_editor_tools.add_child(search)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	content.add_child(_actions)
	_empty = _label(content, "No owned items.")
	_inventory = GridContainer.new()
	_inventory.columns = 5
	_inventory.add_theme_constant_override("h_separation", 6)
	_inventory.add_theme_constant_override("v_separation", 6)
	content.add_child(_inventory)
	_details = _label(content, "")
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor = VBoxContainer.new()
	_editor.add_theme_constant_override("separation", 2)
	content.add_child(_editor)
	_update_visibility()


func refresh(state: Dictionary, slot: int, input_available: bool) -> void:
	if not is_node_ready():
		return
	_enabled = input_available
	_types = state.get("item_types", {})
	var boards: Array = state.get("items", [])
	var board: Dictionary = boards[slot] if slot >= 0 and slot < boards.size() else {}
	_owned = board.get("owned", [])
	_entries = board.get("entries", {})
	_towers.clear()
	for tower: Dictionary in state.get("towers", [[], []])[slot]:
		_towers[int(tower["id"])] = tower
	toggle_button.text = "Items · %d" % _owned.size()
	toggle_button.disabled = not input_available and not expanded
	var key_parts: PackedStringArray = []
	for id: String in _owned:
		key_parts.append(id)
		for action: String in _entries.get(id, {}).get("actions", {}):
			key_parts.append(id + ":" + action)
	var structure_key: String = "|".join(key_parts) + ":" + str(_types.size())
	if structure_key != _structure_key:
		_structure_key = structure_key
		_rebuild()
	_update_actions()
	for id: String in editor_checks:
		editor_checks[id].set_pressed_no_signal(_owned.has(id))
		editor_checks[id].disabled = not _enabled
	all_button.text = "All %d" % _types.size()
	all_button.disabled = not _enabled
	none_button.disabled = not _enabled
	_empty.visible = _owned.is_empty() and not editing
	_update_details()
	_update_visibility()


func _rebuild() -> void:
	for parent: Control in [_actions, _inventory, _editor]:
		for child: Node in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	action_buttons.clear()
	target_selectors.clear()
	owned_buttons.clear()
	editor_checks.clear()
	_action_rows.clear()
	_action_labels.clear()
	_action_status.clear()
	for id: String in _owned:
		var definition: Dictionary = _types.get(id, {})
		for action: String in _entries.get(id, {}).get("actions", {}):
			var key: String = id + ":" + action
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 3)
			_actions.add_child(column)
			_action_rows[key] = column
			var title := _label(column, String(definition.get("title", id)))
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_action_labels[key] = title
			_action_status[key] = _label(column, "")
			var row := HBoxContainer.new()
			column.add_child(row)
			var selector := OptionButton.new()
			selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			selector.fit_to_longest_item = false
			selector.custom_minimum_size = Vector2(0, 36)
			selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			selector.add_theme_font_size_override("font_size", 16)
			selector.item_selected.connect(_target_changed.bind(key))
			row.add_child(selector)
			target_selectors[key] = selector
			var button := _button(row, "", _request_command.bind(key))
			button.custom_minimum_size.y = 36
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_buttons[key] = button
		var button := _button(_inventory, "", _select_item.bind(id))
		button.custom_minimum_size = Vector2(56, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = _art.get(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.tooltip_text = String(definition.get("title", id))
		button.focus_entered.connect(_select_item.bind(id))
		owned_buttons[id] = button
	var ids: Array = _types.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(_types[a].get("title", a)).naturalnocasecmp_to(String(_types[b].get("title", b))) < 0)
	for raw_id: Variant in ids:
		var id: String = String(raw_id)
		var check := CheckBox.new()
		check.text = String(_types[id].get("title", id))
		check.add_theme_font_size_override("font_size", 16)
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.custom_minimum_size.y = 36
		check.toggled.connect(_edit_owned.bind(id))
		_editor.add_child(check)
		editor_checks[id] = check
	_filter_editor(search.text)


func _update_actions() -> void:
	_command_records.clear()
	for id: String in _owned:
		var entry: Dictionary = _entries.get(id, {})
		var actions: Dictionary = entry.get("actions", {})
		for action: String in actions:
			var command: Dictionary = actions[action]
			var key: String = id + ":" + action
			_command_records[key] = command
			var selector: OptionButton = target_selectors[key]
			var old_target: int = int(selector.get_item_metadata(selector.selected)) if selector.selected >= 0 else -1
			var targets: Array = command.get("target_ids", [])
			var previous: Array[int] = []
			for index: int in range(selector.item_count):
				previous.append(int(selector.get_item_metadata(index)))
			if previous != targets:
				selector.clear()
				for target: int in targets:
					var tower: Dictionary = _towers.get(target, {})
					var cell: Vector2i = tower.get("cell", Vector2i.ZERO)
					selector.add_item("#%d · %d,%d" % [target, cell.x + 1, cell.y + 1])
					selector.set_item_metadata(selector.item_count - 1, target)
					if target == old_target:
						selector.select(selector.item_count - 1)
			selector.visible = action == "bind" or id == "minute_hand_cannon"
			selector.disabled = not _enabled or targets.is_empty()
			var button: Button = action_buttons[key]
			button.text = String(ACTION_TITLES.get(action, action.capitalize()))
			if command.has("currency") and not String(command["currency"]).is_empty():
				button.text += " · %d %s" % [int(command.get("cost", 0)), String(command["currency"]).capitalize()]
			button.disabled = not _enabled or not bool(command.get("enabled", false)) or (selector.visible and selector.selected < 0)
			var states: PackedStringArray = []
			if float(entry.get("active_remaining", 0.0)) > 0.0:
				states.append("Active %.1fs" % float(entry["active_remaining"]))
			if float(entry.get("cooldown_remaining", 0.0)) > 0.0:
				states.append("Cooldown %.1fs" % float(entry["cooldown_remaining"]))
			if entry.has("charges"):
				states.append("%d charge%s" % [int(entry["charges"]), "" if int(entry["charges"]) == 1 else "s"])
			if not String(entry.get("status", "")).is_empty():
				states.append(String(entry["status"]))
			if states.is_empty():
				states.append("Ready" if bool(command.get("enabled", false)) else ("No eligible tower" if selector.visible and targets.is_empty() else "Unavailable"))
			var status: Label = _action_status[key]
			status.text = " · ".join(states)
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _target_changed(_index: int, _key: String) -> void:
	_update_actions()


func _request_command(key: String) -> void:
	if not _enabled or not action_buttons.has(key) or action_buttons[key].disabled:
		return
	var parts: PackedStringArray = key.split(":")
	var selector: OptionButton = target_selectors[key]
	var target: int = int(selector.get_item_metadata(selector.selected)) if selector.visible and selector.selected >= 0 else -1
	command_requested.emit(StringName(parts[0]), parts[1], target)


func _select_item(id: String) -> void:
	_selected = id
	_update_details()


func _update_details() -> void:
	if not _owned.has(_selected):
		_selected = String(_owned[0]) if not _owned.is_empty() else ""
	var definition: Dictionary = _types.get(_selected, {})
	var entry: Dictionary = _entries.get(_selected, {})
	_details.text = String(definition.get("title", ""))
	if definition.has("effect_text"):
		_details.text += "\n" + String(definition["effect_text"])
	if entry.has("charges"):
		_details.text += "\nCharges: %d" % int(entry["charges"])
	if not String(entry.get("status", "")).is_empty():
		_details.text += "\n" + String(entry["status"])


func _edit_owned(pressed: bool, id: String) -> void:
	if not sandbox or not _enabled:
		return
	var ids: Array = _owned.duplicate()
	if pressed and not ids.has(id):
		ids.append(id)
	elif not pressed:
		ids.erase(id)
	owned_set_requested.emit(ids)


func _set_all() -> void:
	if sandbox and _enabled:
		owned_set_requested.emit(_types.keys())


func _set_none() -> void:
	if sandbox and _enabled:
		owned_set_requested.emit([])


func _filter_editor(text: String) -> void:
	for id: String in editor_checks:
		editor_checks[id].visible = text.is_empty() or editor_checks[id].text.to_lower().contains(text.to_lower())


func _toggle_editor() -> void:
	editing = not editing
	_update_visibility()
	if editing:
		search.grab_focus()


func _toggle() -> void:
	set_expanded(not expanded)


func set_expanded(value: bool) -> void:
	if expanded == value:
		return
	expanded = value
	if not expanded:
		editing = false
		for selector: OptionButton in target_selectors.values():
			selector.get_popup().hide()
	_update_visibility()
	expanded_changed.emit(expanded)
	if expanded:
		close_button.grab_focus()
	else:
		toggle_button.grab_focus()


func close() -> void:
	set_expanded(false)


func handle_key(event: InputEvent) -> bool:
	if not expanded:
		return false
	for selector: OptionButton in target_selectors.values():
		if selector.get_popup().visible:
			return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if editing:
			editing = false
			_update_visibility()
			editor_button.grab_focus()
		else:
			close()
		get_viewport().set_input_as_handled()
		return true
	return event is InputEventKey


func _update_visibility() -> void:
	_body.visible = expanded
	_editor_tools.visible = editing and sandbox
	_editor.visible = editing and sandbox
	_actions.visible = not editing
	_inventory.visible = not editing
	_details.visible = not editing and not _owned.is_empty()
	_empty.visible = not editing and _owned.is_empty()
	editor_button.text = "Owned" if editing else "Edit set"


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label
