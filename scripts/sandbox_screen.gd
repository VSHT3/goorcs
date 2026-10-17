class_name SandboxScreen
extends Control

signal back_requested

const NUMBERS: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const MATCH_THEME: Theme = preload("res://resources/ui/match_theme.tres")


class FreeShopButton extends TowerShopButton:
	func _create_presentation(artwork_size: int) -> HBoxContainer:
		var presentation: HBoxContainer = super._create_presentation(artwork_size)
		(presentation.get_node("Caption/Details/Price") as Label).text = "Free"
		return presentation

var controller: SandboxController
var catalog: ContentCatalog
var layout: PathLayout:
	get:
		return controller.layout
var selected_tower_id: int = -1
var selected_enemy_id: int = -1
var placement_id: StringName = &""
var shop_buttons: Dictionary[StringName, TowerShopButton] = {}
var round_input: SpinBox
var width_input: SpinBox
var height_input: SpinBox
var count_input: SpinBox
var enemy_selector: OptionButton
var targeting: TargetingCycle
var secondary_targeting: TargetingCycle
var third_targeting: TargetingCycle
var fourth_targeting: TargetingCycle
var advancement_buttons: Dictionary[String, Button] = {}
var play_button: Button
var wave_button: Button
var spawn_button: Button
var clear_button: Button
var menu_button: Button
var resize_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var _status: Label
var _notice: Label
var _notice_timer: Timer
var _management: PanelContainer
var _tower_title: Label
var _tower_stats: Label
var _upgrade_list: VBoxContainer
var _upgrade_buttons: Dictionary[String, Button] = {}
var _advancement_row: HBoxContainer
var _inspector: EnemyInspector
var _pending_dimensions := Vector2i.ZERO
var _active: bool = false
var sound_player: GameSoundPlayer

@onready var world: SandboxWorld = $World
@onready var board: PathBoard = world.boards[0]


func configure(content: ContentCatalog, rules: CombatRules) -> void:
	catalog = content
	controller = SandboxController.new()
	controller.configure(content, rules)
	if is_node_ready():
		controller.changed.connect(_refresh)
		_refresh()


func _ready() -> void:
	theme = MATCH_THEME.duplicate(true) as Theme
	for type_name: String in ["Button", "LineEdit"]:
		for style_name: String in ["normal", "hover", "pressed", "disabled", "read_only"]:
			if not theme.has_stylebox(style_name, type_name):
				continue
			var style: StyleBox = theme.get_stylebox(style_name, type_name)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 3
			style.content_margin_bottom = 3
	if controller == null:
		configure(preload("res://resources/content_catalog.tres"), CombatRules.new())
	sound_player = GameSoundPlayer.new()
	sound_player.world = world
	add_child(sound_player)
	_build_interface()
	board.content_catalog = catalog
	board.edit_requested.connect(_edit)
	board.cell_clicked.connect(_cell_clicked)
	board.enemy_clicked.connect(_enemy_clicked)
	board.tower_dropped.connect(_tower_dropped)
	if not controller.changed.is_connected(_refresh):
		controller.changed.connect(_refresh)
	visibility_changed.connect(_visibility_changed)
	_refresh()


func open() -> void:
	show()
	_active = true
	controller.set_active(true)
	world.set_active(true)
	_refresh()
	play_button.grab_focus()


func cell_screen_position(cell: Vector2i) -> Vector2:
	return world.cell_screen_position(0, cell)


func prepare_to_leave() -> void:
	sound_player.deactivate()
	_active = false
	controller.set_active(false)
	world.set_active(false)
	resize_dialog.hide()
	reset_dialog.hide()
	world.set_input_blocked(false)
	world.boards[0].cancel_stroke()


func _visibility_changed() -> void:
	if is_node_ready() and not is_visible_in_tree():
		prepare_to_leave()


func _physics_process(delta: float) -> void:
	if _active and is_visible_in_tree():
		# The owner advances at the same fixed physics cadence as real matches.
		controller.advance(delta)


func _build_interface() -> void:
	var header: VBoxContainer = _panel(Vector4(14, 6, -14, 92), false)
	var summary := HBoxContainer.new()
	header.add_child(summary)
	_label(summary, "Sandbox").custom_minimum_size.x = 115
	_label(summary, "Round")
	round_input = _spin(summary, 1, 1000, 1, true)
	round_input.value_changed.connect(_round_changed)
	wave_button = _button(summary, "Weighted wave", _start_wave)
	wave_button.tooltip_text = "Replace enemies with the regular weighted roster for this round. Uses the same wave rules as a match."
	play_button = _button(summary, "Play", _toggle_play)
	play_button.custom_minimum_size.x = 90
	play_button.tooltip_text = "Space: pause/resume. Starts a weighted wave when stopped."
	var speed := OptionButton.new()
	for title: String in ["1×", "2×", "4×"]:
		speed.add_item(title)
	speed.item_selected.connect(func(index: int) -> void: controller.speed = [1.0, 2.0, 4.0][index])
	summary.add_child(speed)
	world._hud_popups.append(speed.get_popup())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(spacer)
	menu_button = _button(summary, "Menu", _back)
	menu_button.tooltip_text = "Esc: cancel selection, then return to the menu. Your playground is preserved and paused."
	var spawn_row := HBoxContainer.new()
	header.add_child(spawn_row)
	enemy_selector = OptionButton.new()
	enemy_selector.custom_minimum_size.x = 180
	for enemy: EnemyDefinition in catalog.enemies:
		enemy_selector.add_item(enemy.title)
		enemy_selector.set_item_metadata(enemy_selector.item_count - 1, enemy.id)
		enemy_selector.set_item_tooltip(enemy_selector.item_count - 1, enemy.description)
	spawn_row.add_child(enemy_selector)
	_label(spawn_row, "Count")
	count_input = _spin(spawn_row, 1, 100, 1, true)
	spawn_button = _button(spawn_row, "Spawn", _spawn)
	spawn_button.tooltip_text = "Spawn this exact number, including summon-only types. While stopped, creates a paused empty run; Play resumes it."
	_button(spawn_row, "Stop / clear", _stop).tooltip_text = "Remove all enemies and queued spawns; keep paths, towers, upgrades, and selected round. Unlocks path editing."
	_status = _label(spawn_row, "", true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var footer: VBoxContainer = _panel(Vector4(14, -100, -14, -6), true)
	var tools := HBoxContainer.new()
	footer.add_child(tools)
	_label(tools, "Map")
	width_input = _spin(tools, 2, 256, 14, true)
	_label(tools, "×")
	height_input = _spin(tools, 1, 256, 9, true)
	_button(tools, "Resize…", _request_resize).tooltip_text = "Enter larger dimensions directly; there is no fixed maximum map size. Resizing removes paths, towers, and enemies after confirmation."
	clear_button = _button(tools, "Clear path", controller.clear_path)
	_button(tools, "Reset build…", _request_reset).tooltip_text = "Remove every tower and enemy after confirmation; preserve map, path, and round."
	var freedom := _label(tools, "Free builds · Invincible")
	freedom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freedom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	freedom.tooltip_text = "All content unlocked. No Coins are required. Leaks cannot cause defeat. No collection or lifetime statistics are saved. Paths may use every cell. WASD: pan · wheel/pinch: zoom."
	var palette := HBoxContainer.new()
	footer.add_child(palette)
	for definition: TowerDefinition in catalog.towers:
		var reward: TowerReward = definition.reward
		var button := FreeShopButton.new()
		button.tower_type = reward.id
		button.tower_title = reward.title
		button.tower_artwork = reward.icon_texture
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_placement.bind(reward.id))
		button.drag_started.connect(world.boards[0].cancel_stroke.unbind(1))
		palette.add_child(button)
		button.refresh_caption("Free", "")
		button.tooltip_text = "Click then place on empty ground, or drag onto the board. Right-click / Esc cancels."
		shop_buttons[reward.id] = button
	_notice = Label.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_notice.offset_top = 96
	_notice.offset_left = 20
	_notice.offset_right = -340
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_font_size_override("font_size", 16)
	add_child(_notice)
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = 3.5
	_notice_timer.timeout.connect(func() -> void: _notice.text = "")
	add_child(_notice_timer)
	_build_management()
	_inspector = preload("res://scenes/enemy_inspector.tscn").instantiate() as EnemyInspector
	add_child(_inspector)
	_inspector.offset_top = 110
	_inspector.offset_bottom = 110
	_inspector.close_requested.connect(cancel_interaction)
	resize_dialog = _confirmation("Resize map?", "This removes every path tile, tower, and enemy. The selected round is kept.", _confirm_resize)
	reset_dialog = _confirmation("Reset build?", "This removes every tower and enemy. The map, path, and selected round are kept.", _confirm_reset)
	world._hud_popups.append(enemy_selector.get_popup())


func _build_management() -> void:
	_management = PanelContainer.new()
	_management.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_management.offset_left = -324
	_management.offset_right = -14
	_management.offset_top = 110
	_management.offset_bottom = 570
	add_child(_management)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("1a2521")
	panel_style.border_color = Color("667666")
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_management.add_theme_stylebox_override("panel", panel_style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_management.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 286
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	_tower_title = _label(heading, "Tower")
	_tower_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(heading, "×", cancel_interaction)
	_tower_stats = _label(content, "", true)
	targeting = _target_selector(content, 0)
	secondary_targeting = _target_selector(content, 1)
	third_targeting = _target_selector(content, 2)
	fourth_targeting = _target_selector(content, 3)
	_upgrade_list = VBoxContainer.new()
	content.add_child(_upgrade_list)
	_advancement_row = HBoxContainer.new()
	content.add_child(_advancement_row)
	for command: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
		var button: Button = _button(_advancement_row, "", _upgrade.bind(command))
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		advancement_buttons[command] = button
	_button(content, "Sell tower", _sell)


func _target_selector(parent: Node, archer_index: int) -> TargetingCycle:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, "Archer %d" % (archer_index + 1))
	var selector := TargetingCycle.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.mode_requested.connect(func(mode: int) -> void:
		if not selector.is_visible_in_tree() or selector.disabled:
			return
		if archer_index < 2:
			controller.set_targeting(selected_tower_id, mode, archer_index == 1)
		else:
			controller.set_archer_targeting(selected_tower_id, archer_index, mode)
	)
	row.add_child(selector)
	return selector


func _panel(offsets: Vector4, bottom: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2521")
	style.border_color = Color("667666")
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	return content


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 30
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, text: String, numeric: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	if numeric:
		label.add_theme_font_override("font", NUMBERS)
	parent.add_child(label)
	return label


func _spin(parent: Node, minimum: int, maximum: int, initial: int, unlimited: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.allow_greater = unlimited
	spin.value = initial
	spin.custom_minimum_size = Vector2(88, 30)
	spin.get_line_edit().add_theme_font_override("font", NUMBERS)
	spin.get_line_edit().add_theme_font_size_override("font_size", 16)
	parent.add_child(spin)
	return spin


func _confirmation(title: String, message: String, callback: Callable) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(callback)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			world.set_input_blocked(false)
	)
	add_child(dialog)
	return dialog


func _request_resize() -> void:
	width_input.apply()
	height_input.apply()
	_pending_dimensions = Vector2i(int(width_input.value), int(height_input.value))
	if _pending_dimensions == controller.layout.dimensions:
		return
	controller.set_paused(true)
	world.set_input_blocked(true)
	resize_dialog.popup_centered()


func _confirm_resize() -> void:
	cancel_interaction()
	controller.resize_map(_pending_dimensions)


func _request_reset() -> void:
	controller.set_paused(true)
	world.set_input_blocked(true)
	reset_dialog.popup_centered()


func _confirm_reset() -> void:
	cancel_interaction()
	controller.reset_build()


func _round_changed(value: float) -> void:
	controller.set_round(int(value))


func _start_wave() -> void:
	if not controller.start_wave():
		_show_notice("Connect the portal, crystal, and all path tiles first.")


func _toggle_play() -> void:
	if not controller.toggle_play():
		_show_notice("Connect the portal, crystal, and all path tiles first.")


func _spawn() -> void:
	count_input.apply()
	if enemy_selector.selected >= 0 and not controller.spawn(StringName(enemy_selector.get_item_metadata(enemy_selector.selected)), int(count_input.value)):
		_show_notice("Connect the portal, crystal, and all path tiles first.")


func _stop() -> void:
	selected_enemy_id = -1
	controller.stop()


func _back() -> void:
	prepare_to_leave()
	back_requested.emit()


func _edit(cell: Vector2i, place: bool) -> void:
	if placement_id == &"":
		controller.edit_path(cell, place)


func _select_placement(type_id: StringName) -> void:
	cancel_interaction()
	placement_id = type_id
	_refresh()


func _tower_dropped(cell: Vector2i, type_id: StringName) -> void:
	if controller.build(cell, type_id):
		cancel_interaction()
		_cell_clicked(cell, MOUSE_BUTTON_LEFT)


func _cell_clicked(cell: Vector2i, button: MouseButton) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		cancel_interaction()
		return
	selected_enemy_id = -1
	for tower: Dictionary in controller.state["towers"][0]:
		if tower["cell"] == cell:
			selected_tower_id = int(tower["id"])
			placement_id = &""
			world.boards[0].cancel_stroke()
			_refresh()
			return
	selected_tower_id = -1
	if placement_id != &"":
		if controller.build(cell, placement_id):
			placement_id = &""
			_cell_clicked(cell, button)
			return
		_show_notice("Place towers on empty, non-path ground.")
	_refresh()


func _enemy_clicked(enemy_id: int) -> void:
	selected_tower_id = -1
	selected_enemy_id = enemy_id
	_refresh()


func cancel_interaction() -> bool:
	var had_selection: bool = placement_id != &"" or selected_tower_id >= 0 or selected_enemy_id >= 0
	placement_id = &""
	selected_tower_id = -1
	selected_enemy_id = -1
	world.boards[0].cancel_stroke()
	_refresh()
	return had_selection


func _sell() -> void:
	controller.sell(selected_tower_id)
	cancel_interaction()


func _refresh() -> void:
	if not is_node_ready() or _status == null:
		return
	var state: Dictionary = controller.state
	board.layout = controller.layout
	world.boards[1].layout = controller.layout
	world.configure(controller.layout.dimensions)
	var running: bool = controller.combat.phase == MatchCombat.Phase.WAVE
	board.cell_click_mode = running or placement_id != &"" or selected_tower_id >= 0
	board.input_enabled = _active
	board.placement_enabled = _active
	board.enemy_inspection_enabled = _active and placement_id == &""
	board.placement_id = placement_id
	board.selected_tower_id = selected_tower_id
	board.selected_enemy_id = selected_enemy_id
	board.tower_types = state["tower_types"]
	board.combat_towers = state["towers"][0]
	board.combat_enemies = state["enemies"][0]
	board.apply_deaths(state, 0, controller.speed, controller.paused and running)
	sound_player.observe(state, 0, _active and is_visible_in_tree(), controller.paused and running)
	board.queue_redraw()
	for type_id: StringName in shop_buttons:
		shop_buttons[type_id].set_pressed_no_signal(type_id == placement_id)
	play_button.text = "Pause" if running and not controller.paused else "Play"
	_status.text = "%s · Alive %d" % [("Paused" if controller.paused else "Running") if running else "Editing", state["enemies"][0].size()]
	_status.tooltip_text = "%d path tiles · Unlimited tiles · %d × %d map" % [controller.layout.used_tiles(), controller.layout.dimensions.x, controller.layout.dimensions.y]
	clear_button.disabled = running or controller.layout.used_tiles() == 0
	_refresh_management(state)
	var enemy: Dictionary = _find(state["enemies"][0], selected_enemy_id)
	if enemy.is_empty():
		selected_enemy_id = -1
		board.selected_enemy_id = -1
	_inspector.refresh(enemy, state["enemy_types"].get(String(enemy.get("type_id", "")), {}))


func _find(items: Array, id: int) -> Dictionary:
	for item: Dictionary in items:
		if int(item["id"]) == id:
			return item
	return {}


func _refresh_management(state: Dictionary) -> void:
	var tower: Dictionary = _find(state["towers"][0], selected_tower_id)
	_management.visible = not tower.is_empty()
	if tower.is_empty():
		selected_tower_id = -1
		return
	var stats: Dictionary = state["tower_types"][tower["type_id"]]
	_tower_title.text = "%s · %s" % [stats["title"], MatchPlanningScreen.TOWER_LEVEL_NUMERALS[MatchCombat.tower_level(tower) - 1]]
	if tower.get("evolution", "") == "boulders":
		_tower_stats.text = "Kills %d · %d DPS\nContinuous" % [int(tower["kills"]), int(tower["damage"])]
	else:
		_tower_stats.text = "Kills %d · Damage %d\nEvery %.2fs" % [int(tower["kills"]), int(tower["damage"]), float(tower["interval"])]
	targeting.mode = int(tower["mode"])
	targeting.disabled = not _active
	secondary_targeting.get_parent_control().visible = bool(tower["special_upgraded"]) and stats.get("special_upgrade", "") == "second_archer"
	secondary_targeting.disabled = not _active or not secondary_targeting.get_parent_control().visible
	secondary_targeting.mode = int(tower["secondary_mode"])
	var extra_archers: Array = tower.get("extra_archers", [])
	var four_archers: bool = tower.get("advancement", "") == "four_archers" and extra_archers.size() == 2
	for index: int in range(2):
		var selector: TargetingCycle = third_targeting if index == 0 else fourth_targeting
		selector.get_parent_control().visible = four_archers
		selector.disabled = not _active or not four_archers
		if four_archers:
			selector.mode = int(extra_archers[index]["mode"])
	var advancements: Dictionary = stats.get("advancements", {})
	_advancement_row.visible = secondary_targeting.get_parent_control().visible and not advancements.is_empty()
	for command: String in advancement_buttons:
		var definition: Dictionary = advancements.get(command, {})
		var chosen: String = String(tower.get("advancement", ""))
		var purchased: bool = chosen == command
		var locked: bool = not chosen.is_empty() and not purchased
		var button: Button = advancement_buttons[command]
		button.text = "%s\n%s" % [String(definition.get("title", command)), "Owned" if purchased else ("Locked" if locked else "Free")]
		button.disabled = not _advancement_row.visible or definition.is_empty() or purchased or locked
		button.tooltip_text = MatchPlanningScreen.advancement_tooltip(command, definition) + "\nFree in sandbox; sell and rebuild to choose another path."
	var commands: Dictionary[String, Dictionary] = {
		"damage": {"title": "+%d damage" % int(stats["damage_upgrade_bonus"]), "purchased": bool(tower["damage_upgraded"]), "locked": false},
		"speed": {"title": "%.0f%% faster" % ((1.0 / float(stats["speed_upgrade_multiplier"]) - 1.0) * 100.0), "purchased": bool(tower["speed_upgraded"]), "locked": false},
	}
	var ready_special: bool = bool(tower["damage_upgraded"]) and bool(tower["speed_upgraded"])
	if not String(stats.get("special_upgrade", "")).is_empty() and not _advancement_row.visible:
		commands["special"] = {"title": stats["special_upgrade_title"], "purchased": bool(tower["special_upgraded"]), "locked": not ready_special}
	var evolutions: Dictionary = stats.get("evolutions", {})
	for branch: String in evolutions:
		commands[branch] = {"title": evolutions[branch]["title"], "purchased": tower["evolution"] == branch, "locked": not ready_special or (tower["evolution"] != "" and tower["evolution"] != branch)}
		var followup: Dictionary = evolutions[branch].get("followup", {})
		if not followup.is_empty():
			commands["freeze_runes"] = {"title": followup["title"], "purchased": bool(tower["freeze_upgraded"]), "locked": tower["evolution"] != branch}
	for command: String in _upgrade_buttons:
		_upgrade_buttons[command].visible = commands.has(command)
	for command: String in commands:
		if not _upgrade_buttons.has(command):
			_upgrade_buttons[command] = _button(_upgrade_list, "", _upgrade.bind(command))
		var details: Dictionary = commands[command]
		var button: Button = _upgrade_buttons[command]
		button.show()
		button.text = "%s · %s" % [details["title"], "Purchased" if details["purchased"] else ("Locked" if details["locked"] else "Free")]
		button.disabled = details["purchased"] or details["locked"]
		button.tooltip_text = "Choose either evolution after damage and speed. Sell and rebuild freely to try another branch." if evolutions.has(command) else "Free sandbox upgrade; normal tower prerequisites apply."


func _upgrade(command: String) -> void:
	var button: Button = advancement_buttons.get(command, _upgrade_buttons.get(command))
	if button != null and button.is_visible_in_tree() and not button.disabled:
		controller.upgrade(selected_tower_id, command)


func _show_notice(message: String) -> void:
	if is_visible_in_tree():
		sound_player.reject()
	_notice.text = message
	_notice_timer.start()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree() or resize_dialog.visible or reset_dialog.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and (placement_id != &"" or selected_enemy_id >= 0 or selected_tower_id >= 0):
		cancel_interaction()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	for popup: PopupMenu in world._hud_popups:
		if popup.visible:
			return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		if event.keycode == KEY_ESCAPE:
			focus.release_focus()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_SPACE:
		_toggle_play()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if not cancel_interaction():
			_back()
		get_viewport().set_input_as_handled()
