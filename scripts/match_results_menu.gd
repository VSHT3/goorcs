class_name MatchResultsMenu
extends Control

signal menu_requested
signal replay_requested
signal inspect_requested

const NUMBERS: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const GOLD := Color("e0bc77")
var replay_button: Button
var inspect_button: Button
var menu_button: Button
var scroll: ScrollContainer
var _title: Label
var _reason: Label
var _round: Label
var _report: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.035, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	resized.connect(_fit_report.bind(margin))
	_fit_report.call_deferred(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16241e")
	style.border_color = Color("697a62")
	style.set_border_width_all(1)
	for edge: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + edge, 20.0)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_title = _label(content, "", 36)
	_reason = _label(content, "", 18)
	_round = _label(content, "", 16, true)
	content.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_scroll_input)
	content.add_child(scroll)
	_report = VBoxContainer.new()
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report.add_theme_constant_override("separation", 10)
	scroll.add_child(_report)
	content.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	inspect_button = _button(actions, "View battlefield", func() -> void: inspect_requested.emit())
	replay_button = _button(actions, "Play again", func() -> void: replay_requested.emit())
	menu_button = _button(actions, "Main menu", func() -> void: menu_requested.emit())
	var hint: Label = _label(content, "Scroll for details. View battlefield to inspect final tower stats.")
	hint.add_theme_color_override("font_color", Color("a0b09d"))
	hide()

func _fit_report(margin: MarginContainer) -> void:
	var inset: int = maxi(24, (int(size.x) - 1000) / 2)
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_right", inset)

func _label(parent: Node, text: String, pixels: int = 16, numeric: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", pixels)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if numeric:
		label.add_theme_font_override("font", NUMBERS)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	MenuAudio.bind_action(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _heading(text: String) -> void:
	if _report.get_child_count() > 0:
		_report.add_child(HSeparator.new())
	var label: Label = _label(_report, text, 24)
	label.add_theme_color_override("font_color", GOLD)

func _row(text: String, own: String, other: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_report.add_child(row)
	var name: Label = _label(row, text)
	name.size_flags_stretch_ratio = 2.0
	for value: String in [own, other]:
		var label: Label = _label(row, value, 16, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func open_result(state: Dictionary, slot: int, solo: bool) -> void:
	var won: bool = int(state.get("winner", -1)) == slot
	_title.text = "Victory" if won else "Defeat"
	_title.modulate = GOLD if won else Color("e0a08d")
	_reason.text = "Both crystals fell. The host coin flip decided the result." if bool(state.get("coin_flip", false)) else ("The opposing crystal has fallen." if won else "Your crystal has fallen.")
	var recap: Dictionary = state.get("recap", {})
	var duration: int = int(recap.get("duration_seconds", 0))
	_round.text = "Round %d   ·   Cleared %d   ·   Combat %02d:%02d" % [int(state.get("wave", 0)), int(recap.get("rounds_cleared", 0)), duration / 60, duration % 60]
	for child: Node in _report.get_children():
		_report.remove_child(child)
		child.queue_free()
	var sides: Array = recap.get("sides", [{}, {}])
	var own: Dictionary = sides[slot]
	var other: Dictionary = sides[1 - slot]
	var fatal: String = own.get("defeated_by", "")
	if not won and not fatal.is_empty():
		var cause: String = "Final crystal hit: " + str(state.get("enemy_types", {}).get(fatal, {}).get("title", fatal))
		_reason.text = _reason.text + " " + cause if bool(state.get("coin_flip", false)) else cause
	_heading("Match overview")
	_row("", "You", "Mirror" if solo else "Opponent")
	_row("Crystal HP", str(state.get("health", [0, 0])[slot]), str(state.get("health", [0, 0])[1 - slot]))
	var totals: Array = state.get("enemy_totals", [{}, {}])
	_row("Enemies killed", str(_sum(totals[slot].get("kills", {}))), str(_sum(totals[1-slot].get("kills", {}))))
	_row("Enemies sent", str(_sum(totals[slot].get("sent", {}))), str(_sum(totals[1-slot].get("sent", {}))))
	_row("Enemies leaked", str(_sum(own.get("leaks", {}))), str(_sum(other.get("leaks", {}))))
	_row("Damage dealt", str(_tower_sum(own, "damage_dealt") + _tower_sum(own, "indirect_damage")), str(_tower_sum(other, "damage_dealt") + _tower_sum(other, "indirect_damage")))
	_row("Coins remaining", str(state.get("coins", [0, 0])[slot]), str(state.get("coins", [0, 0])[1-slot]))
	_row("Shards remaining", str(state.get("reroll_currency", [0, 0])[slot]), str(state.get("reroll_currency", [0, 0])[1-slot]))
	_heading("Economy · Coins earned")
	for entry: Array in [["kill_coins", "Kill rewards, including mark/aura bonuses"], ["wave_coins", "Wave-clear rewards"], ["income_coins", "Send income paid"], ["production_coins", "Mine production"], ["boss_coins", "First-boss bonuses"], ["sale_coins", "Tower sale refunds"]]:
		_flow(entry, own, other, "earned")
	_heading("Economy · Spending")
	for entry: Array in [["towers", "Tower purchases"], ["upgrades", "Upgrades and evolutions"], ["sends", "Enemy orders"], ["attribute_rerolls", "Attribute rerolls"], ["rarity_shards", "Rarity rerolls · Shards"]]:
		_flow(entry, own, other, "spent")
	_heading("Shard income")
	for entry: Array in [["drop_shards", "Enemy drops"], ["clear_shards", "Round-clear Shards"], ["production_shards", "Tower production"], ["boss_shards", "First-boss bonuses"]]:
		_flow(entry, own, other, "earned")
	_heading("Your towers · Damage ranking")
	var records: Array = own.get("towers", state.get("towers", [[], []])[slot]).duplicate()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("damage_dealt", 0)) + int(a.get("indirect_damage", 0)) > int(b.get("damage_dealt", 0)) + int(b.get("indirect_damage", 0)))
	var total_damage: int = _tower_sum(own, "damage_dealt") + _tower_sum(own, "indirect_damage")
	if records.is_empty():
		_label(_report, "No towers built.")
	for tower: Dictionary in records:
		var stats: Dictionary = state.get("tower_types", {}).get(tower["type_id"], {})
		var label: Label = _label(_report, MatchPlanningScreen.tower_display_title(tower, stats) + (" · Sold" if tower.get("sold", false) else ""), 18)
		label.add_theme_color_override("font_color", MatchPlanningScreen.tower_rarity_color(tower))
		var damage: int = int(tower.get("damage_dealt", 0)) + int(tower.get("indirect_damage", 0))
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 8
		bar.max_value = maxi(1, total_damage)
		bar.value = damage
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_report.add_child(bar)
		_label(_report, "Damage %d   ·   Kills %d   ·   Invested %d Coins" % [damage, int(tower.get("kills", 0)), int(tower.get("invested", 0))], 16, true)
		_label(_report, "Generated %d Coins / %d Shards   ·   Indirect damage %d" % [int(tower.get("coins_generated", 0)), int(tower.get("shards_generated", 0)), int(tower.get("indirect_damage", 0))], 16, true)
	_heading("Enemy breakdown")
	_label(_report, "Kills and leaks: your board. Sends: enemies ordered for the opponent.")
	_row("Enemy", "Killed / Sent", "Leaked / HP lost")
	var ids: Dictionary = {}
	for bucket: Dictionary in [totals[slot].get("kills", {}), totals[slot].get("sent", {}), own.get("leaks", {})]:
		for id: String in bucket:
			ids[id] = true
	for id: String in ids:
		_row(str(state.get("enemy_types", {}).get(id, {}).get("title", id)), "%d / %d" % [int(totals[slot].get("kills", {}).get(id, 0)), int(totals[slot].get("sent", {}).get(id, 0))], "%d / %d" % [int(own.get("leaks", {}).get(id, 0)), int(own.get("base_damage", {}).get(id, 0))])
	if ids.is_empty():
		_label(_report, "No enemy encounters recorded.")
	_heading("Boss rewards")
	var rewards: Array = state.get("boss_rewards", [[], []])[slot]
	for reward: Dictionary in rewards:
		_row(str(reward["boss_title"]), str(reward["rarity_title"]), "+%d Coins\n+%d Shards" % [int(reward["coins"]), int(reward["shards"])])
	if rewards.is_empty():
		_label(_report, "No first-boss rewards earned.")
	replay_button.visible = solo
	var buttons: Array[Control] = [inspect_button, menu_button, scroll]
	if solo:
		buttons.insert(1, replay_button)
	var footer_count: int = buttons.size() - 1
	for index: int in range(buttons.size()):
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index+1)%buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[posmod(index-1,buttons.size())])
		if index < footer_count:
			buttons[index].focus_neighbor_left = buttons[index].get_path_to(buttons[posmod(index - 1, footer_count)])
			buttons[index].focus_neighbor_right = buttons[index].get_path_to(buttons[(index + 1) % footer_count])
			buttons[index].focus_neighbor_top = buttons[index].get_path_to(scroll)
			buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(scroll)
	scroll.scroll_vertical = 0
	show()
	var initial: Button = replay_button if solo else inspect_button
	initial.grab_focus()
	initial.grab_focus.call_deferred()

func _flow(entry: Array, own: Dictionary, other: Dictionary, bucket: String) -> void:
	_row(entry[1], str(own.get(bucket, {}).get(entry[0], 0)), str(other.get(bucket, {}).get(entry[0], 0)))

func _sum(values: Dictionary) -> int:
	var total: int = 0
	for value: int in values.values():
		total += value
	return total

func _tower_sum(side: Dictionary, key: String) -> int:
	var total: int = 0
	for tower: Dictionary in side.get("towers", []):
		total += int(tower.get(key, 0))
	return total

func _scroll_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_DOWN: scroll.scroll_vertical += 48
		KEY_UP: scroll.scroll_vertical -= 48
		KEY_PAGEDOWN: scroll.scroll_vertical += int(scroll.size.y * 0.85)
		KEY_PAGEUP: scroll.scroll_vertical -= int(scroll.size.y * 0.85)
		KEY_HOME: scroll.scroll_vertical = 0
		KEY_END: scroll.scroll_vertical = int(_report.size.y)
		_: return
	scroll.accept_event()
