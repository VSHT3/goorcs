class_name SandboxScreen
extends Control

signal back_requested

const NUMBERS: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const MATCH_THEME: Theme = preload("res://resources/ui/match_theme.tres")
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]


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
var sell_button: Button
var max_button: Button
var advancement_buttons: Dictionary[String, Button] = {}
var play_button: Button
var restart_button: Button
var speed_selector: OptionButton
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
var _upgrade_row: UpgradeChoiceRow
var _upgrade_buttons: Dictionary[String, Button] = {}
var _inspector: EnemyInspector
var _pending_dimensions := Vector2i.ZERO
var _active: bool = false
var sound_player: GameSoundPlayer
var _roll_details: Label
var rarity_reroll: Button
var rarity_batch_selector: Button
var _rarity_batch: int = 1
var attribute_reroll: Button
var _rarity_reel: RarityReel
var boss_bars: BossHealthBars
var tower_status: TowerStatusStrip

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
	_rarity_reel = RarityReel.new()
	add_child(_rarity_reel)
	_rarity_reel.finished.connect(_rarity_reel_finished)
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
	_rarity_reel.cancel()
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
	round_input = _spin(summary, 1, 9999, 1, true)
	round_input.value_changed.connect(_round_changed)
	wave_button = _button(summary, "Weighted wave", _start_wave)
	wave_button.tooltip_text = "Replace enemies with the regular weighted roster for this round. Uses the same wave rules as a match."
	play_button = _button(summary, "Play", _toggle_play)
	play_button.custom_minimum_size.x = 90
	play_button.tooltip_text = "Space: pause/resume. Starts a weighted wave when stopped."
	restart_button = _button(summary, "Restart [R]", _restart)
	speed_selector = OptionButton.new()
	for title: String in ["1× [F]", "2× [F]", "4× [F]", "8× [F]"]:
		speed_selector.add_item(title)
	speed_selector.item_selected.connect(_select_speed)
	summary.add_child(speed_selector)
	world._hud_popups.append(speed_selector.get_popup())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(spacer)
	menu_button = _button(summary, "X", _back)
	CloseButtonStyle.apply(menu_button)
	MenuAudio.bind_action(menu_button)
	var spawn_row := HBoxContainer.new()
	header.add_child(spawn_row)
	enemy_selector = OptionButton.new()
	enemy_selector.custom_minimum_size.x = 220
	# Grouped like the Orcieary, each entry with its small portrait.
	enemy_selector.get_popup().add_theme_constant_override("icon_max_width", 28)
	enemy_selector.add_theme_constant_override("icon_max_width", 24)
	for category: int in range(3):
		enemy_selector.add_separator(["Basic", "Elite", "Boss"][category])
		for enemy: EnemyDefinition in catalog.enemies:
			if (2 if enemy.boss else (1 if enemy.elite else 0)) != category:
				continue
			if enemy.texture != null:
				enemy_selector.add_icon_item(enemy.texture, enemy.title)
			else:
				enemy_selector.add_item(enemy.title)
			enemy_selector.set_item_metadata(enemy_selector.item_count - 1, enemy.id)
			enemy_selector.set_item_tooltip(enemy_selector.item_count - 1, enemy.description)
	enemy_selector.select(1)
	spawn_row.add_child(enemy_selector)
	_label(spawn_row, "Count")
	count_input = _spin(spawn_row, 1, 100, 1, true)
	spawn_button = _button(spawn_row, "Spawn", _spawn)
	spawn_button.tooltip_text = "Spawn this exact number, including summon-only types. While stopped, creates a paused empty run; Play resumes it. [E]"
	_button(spawn_row, "Stop / clear", _stop).tooltip_text = "Remove all enemies and queued spawns; keep paths, towers, upgrades, and selected round. Unlocks path editing."
	_status = _label(spawn_row, "", true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var footer: VBoxContainer = _panel(Vector4(14, -120, -14, -6), true)
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
	freedom.tooltip_text = "All content unlocked. No Coins are required. Leaks cannot cause defeat. No collection or lifetime statistics are saved. Paths may use every cell. WASD: pan · wheel/pinch: zoom · Home: fit board."
	var palette := HBoxContainer.new()
	footer.add_child(palette)
	for definition: TowerDefinition in catalog.towers:
		var reward: TowerReward = definition.reward
		var button := FreeShopButton.new()
		button.shortcut_number = shop_buttons.size() + 1
		button.tower_type = reward.id
		button.tower_title = reward.title
		button.tower_artwork = reward.icon_texture
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_placement.bind(reward.id))
		button.drag_started.connect(_tower_drag_started)
		palette.add_child(button)
		button.refresh_caption("Free", "")
		button.tooltip_text = "Click then place on empty ground, or drag onto the board. Hold Shift to keep building. Right-click / Esc cancels."
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
	boss_bars = BossHealthBars.new()
	boss_bars.catalog = catalog
	add_child(boss_bars)
	boss_bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	boss_bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boss_bars.offset_left = 14
	boss_bars.offset_right = 14 + BossHealthBars.ROW_SIZE.x
	boss_bars.offset_top = -128
	boss_bars.offset_bottom = -128
	boss_bars.boss_selected.connect(_enemy_clicked)
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
	_management.offset_left = -404
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
	var shell := VBoxContainer.new()
	_management.add_child(shell)
	var heading := HBoxContainer.new()
	shell.add_child(heading)
	_tower_title = _label(heading, "Tower")
	_tower_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CloseButtonStyle.apply(_button(heading, "X", cancel_interaction))
	tower_status = TowerStatusStrip.new()
	shell.add_child(tower_status)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 0
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_tower_stats = _label(content, "", true)
	_tower_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll_details = _label(content, "", true)
	_roll_details.name = "TowerRoll"
	_roll_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rarity_row := HBoxContainer.new()
	content.add_child(rarity_row)
	rarity_reroll = _button(rarity_row, "Reroll rarity · Free", _reroll.bind("rarity"))
	rarity_reroll.name = "RerollRarity"
	rarity_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_batch_selector = _button(rarity_row, "1×", _cycle_rarity_batch)
	rarity_batch_selector.name = "RarityBatch"
	rarity_batch_selector.custom_minimum_size.x = 56
	rarity_reroll.focus_neighbor_right = rarity_reroll.get_path_to(rarity_batch_selector)
	rarity_batch_selector.focus_neighbor_left = rarity_batch_selector.get_path_to(rarity_reroll)
	attribute_reroll = _button(content, "Reroll attributes · Free", _reroll.bind("attributes"))
	attribute_reroll.name = "RerollAttributes"
	attribute_reroll.tooltip_text = MatchPlanningScreen.reroll_tooltip("attributes") + "\nFree in Sandbox."
	targeting = _target_selector(content)
	_upgrade_row = UpgradeChoiceRow.new()
	content.add_child(_upgrade_row)
	for command: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
		var button: Button = _button(_upgrade_row, "", _upgrade.bind(command))
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.add_theme_font_override("font", NUMBERS)
		button.add_theme_font_size_override("font_size", 16)
		advancement_buttons[command] = button
	max_button = _button(content, "Max upgrades", _max_upgrades)
	max_button.tooltip_text = "Buy every remaining upgrade for free, taking the first open branch at each choice. [M]"
	sell_button = _button(content, "Sell tower", _sell)


func _target_selector(parent: Node) -> TargetingCycle:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, "Target")
	var selector := TargetingCycle.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.mode_requested.connect(func(mode: int) -> void:
		if not selector.is_visible_in_tree() or selector.disabled:
			return
		controller.set_targeting(selected_tower_id, mode)
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


func _restart() -> void:
	if not controller.restart():
		_show_notice("Start a weighted wave or Spawn batch, then connect the portal, crystal, and all path tiles before restarting.")


func _select_speed(index: int) -> void:
	controller.speed = SPEEDS[index]
	_refresh()


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


func _build_another() -> bool:
	var tower: Dictionary = _find(controller.state["towers"][0], selected_tower_id)
	if not _active or tower.is_empty():
		return false
	var type_id := StringName(tower["type_id"])
	var button: TowerShopButton = shop_buttons.get(type_id)
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return false
	_select_placement(type_id)
	return true


func _select_placement(type_id: StringName) -> void:
	cancel_interaction()
	placement_id = type_id
	_refresh()


func _tower_dropped(cell: Vector2i, type_id: StringName) -> void:
	var repeat_placement: bool = Input.is_key_pressed(KEY_SHIFT)
	if controller.build(cell, type_id):
		cancel_interaction()
		if repeat_placement:
			_select_placement(type_id)
		else:
			_cell_clicked(cell, MOUSE_BUTTON_LEFT)


func _cell_clicked(cell: Vector2i, button: MouseButton) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		cancel_interaction()
		return
	selected_enemy_id = -1
	for tower: Dictionary in controller.state["towers"][0]:
		if Rect2i(tower["cell"], tower.get("footprint", Vector2i.ONE)).has_point(cell):
			selected_tower_id = int(tower["id"])
			placement_id = &""
			world.boards[0].cancel_stroke()
			_refresh()
			return
	selected_tower_id = -1
	if placement_id != &"":
		var repeat_placement: bool = Input.is_key_pressed(KEY_SHIFT)
		if controller.build(cell, placement_id):
			if not repeat_placement:
				placement_id = &""
				_cell_clicked(cell, button)
			else:
				_refresh()
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


func _tower_drag_started(_type_id: StringName) -> void:
	cancel_interaction()


func _sell() -> void:
	if _active and _management.is_visible_in_tree() and not _find(controller.state["towers"][0], selected_tower_id).is_empty():
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
	board.apply_combat(state, 0, controller.speed, controller.paused and running)
	sound_player.observe(state, 0, _active and is_visible_in_tree(), controller.paused and running)
	board.queue_redraw()
	for type_id: StringName in shop_buttons:
		shop_buttons[type_id].set_pressed_no_signal(type_id == placement_id)
	play_button.text = "Pause" if running and not controller.paused else "Play"
	restart_button.disabled = not _active or not controller.can_restart()
	speed_selector.disabled = not _active
	speed_selector.select(SPEEDS.find(controller.speed))
	_status.text = ("Paused" if controller.paused else "Running") if running else "Editing"
	_status.tooltip_text = "%d path tiles · Unlimited tiles · %d × %d map" % [controller.layout.used_tiles(), controller.layout.dimensions.x, controller.layout.dimensions.y]
	clear_button.disabled = running or controller.layout.used_tiles() == 0
	_refresh_management(state)
	var enemy: Dictionary = _find(state["enemies"][0], selected_enemy_id)
	if enemy.is_empty():
		selected_enemy_id = -1
		board.selected_enemy_id = -1
	_inspector.refresh(enemy, state["enemy_types"].get(String(enemy.get("type_id", "")), {}))
	if _active and is_visible_in_tree():
		boss_bars.catalog = catalog
		boss_bars.refresh(state["enemies"][0], state["enemy_types"], state.get("deaths", [[]])[0])
		boss_bars.selected_id = selected_enemy_id
	else:
		boss_bars.clear()


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
		board.selected_tower_id = -1
		return
	var stats: Dictionary = state["tower_types"][tower["type_id"]]
	_tower_title.text = MatchPlanningScreen.tower_display_title(tower, stats)
	_tower_title.add_theme_color_override("font_color", MatchPlanningScreen.tower_rarity_color(tower))
	_tower_stats.text = MatchPlanningScreen.tower_stats_text(tower, stats)
	_roll_details.text = MatchPlanningScreen.roll_details_text(tower)
	tower_status.refresh(tower, float(state.get("magic_nullified", [0.0])[0]))
	var quote: Dictionary = tower.get("rarity_batch_quotes", {}).get("max" if _rarity_batch == 0 else str(_rarity_batch), {})
	var terminal: bool = int(state.get("phase", -1)) == MatchCombat.Phase.FINISHED
	rarity_batch_selector.disabled = not _active or terminal or _rarity_reel.is_busy()
	rarity_batch_selector.text = "Max" if _rarity_batch == 0 else "%d×" % _rarity_batch
	rarity_reroll.disabled = rarity_batch_selector.disabled or int(quote.get("count", 0)) <= 0 or int(quote.get("cost", -1)) < 0
	attribute_reroll.disabled = not _active or int(tower.get("attribute_reroll_cost", -1)) < 0 or _rarity_reel.is_busy()
	targeting.get_parent_control().visible = tower.get("behavior_kind", stats.get("behavior_kind", "attack")) in ["attack", "chain"]
	targeting.mode = int(tower["mode"])
	targeting.disabled = not _active
	var advancements: Dictionary = stats.get("advancements", {})
	var available: Dictionary = MatchPlanningScreen.advancement_actions(tower, stats)
	for command: String in advancements:
		if not advancement_buttons.has(command):
			var button: Button = _button(_upgrade_row, "", _upgrade.bind(command))
			button.custom_minimum_size = Vector2(0, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD
			button.add_theme_font_override("font", NUMBERS)
			button.add_theme_font_size_override("font_size", 16)
			advancement_buttons[command] = button
	for command: String in advancement_buttons:
		var button: Button = advancement_buttons[command]
		button.visible = bool(tower["special_upgraded"]) and available.has(command)
		if not available.has(command):
			continue
		var action: Dictionary = available[command]
		button.text = "%s\n%s" % [action["title"], "Locked" if action["locked"] else "Free"]
		button.disabled = not _active or not bool(tower["special_upgraded"]) or action["purchased"] or action["locked"]
		button.tooltip_text = String(action["description"]) + "\nFree in Sandbox; normal price %d Coins." % int(action["cost"])
	var commands: Dictionary = MatchPlanningScreen.tower_upgrade_actions(tower, stats)
	for command: String in _upgrade_buttons:
		_upgrade_buttons[command].visible = commands.has(command)
	for command: String in commands:
		if not _upgrade_buttons.has(command):
			_upgrade_buttons[command] = _button(_upgrade_row, "", _upgrade.bind(command))
			_upgrade_buttons[command].custom_minimum_size = Vector2(0, 56)
			_upgrade_buttons[command].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_upgrade_buttons[command].autowrap_mode = TextServer.AUTOWRAP_WORD
			_upgrade_buttons[command].add_theme_font_override("font", NUMBERS)
			_upgrade_buttons[command].add_theme_font_size_override("font_size", 16)
		var details: Dictionary = commands[command]
		var button: Button = _upgrade_buttons[command]
		button.visible = not bool(details["purchased"])
		button.text = "%s\n%s" % [details["title"], "Locked" if details["locked"] else "Free"]
		button.disabled = not _active or details["purchased"] or details["locked"]
		button.tooltip_text = String(details["description"]) + "\nFree in Sandbox; normal prerequisites apply. Sell and rebuild to choose another permanent branch."
	_upgrade_row.visible = _upgrade_row.get_children().any(func(button: Button) -> bool: return button.visible)


# Sandbox: keep buying the first open upgrade until the tower is fully upgraded.
func _max_upgrades() -> void:
	if not _active or not max_button.is_visible_in_tree():
		return
	for attempt: int in range(64):
		var tower: Dictionary = _find(controller.state["towers"][0], selected_tower_id)
		if tower.is_empty():
			return
		var stats: Dictionary = controller.state["tower_types"][tower["type_id"]]
		var options: Dictionary = MatchPlanningScreen.tower_upgrade_actions(tower, stats)
		if bool(tower["special_upgraded"]):
			options.merge(MatchPlanningScreen.advancement_actions(tower, stats))
		var bought: bool = false
		for command: String in options:
			var action: Dictionary = options[command]
			if not bool(action.get("purchased", false)) and not bool(action.get("locked", false)) and controller.upgrade(selected_tower_id, command):
				bought = true
				break
		if not bought:
			break
	_refresh()


func _upgrade(command: String) -> void:
	var button: Button = advancement_buttons.get(command, _upgrade_buttons.get(command))
	if button != null and button.is_visible_in_tree() and not button.disabled:
		controller.upgrade(selected_tower_id, command)


func _cycle_rarity_batch() -> void:
	if rarity_batch_selector.disabled:
		return
	_rarity_batch = 10 if _rarity_batch == 1 else (0 if _rarity_batch == 10 else 1)
	_refresh_management(controller.state)


func _reroll(kind: String) -> void:
	var button: Button = rarity_reroll if kind == "rarity" else attribute_reroll
	if not button.is_visible_in_tree() or button.disabled or _rarity_reel.is_busy():
		return
	if controller.reroll_tower(selected_tower_id, kind, _rarity_batch if kind == "rarity" else 1) and kind == "rarity":
		var tower: Dictionary = _find(controller.state["towers"][0], selected_tower_id)
		var shop: TowerShopButton = shop_buttons[StringName(tower["type_id"])]
		world.boards[0].cancel_stroke()
		world.set_input_blocked(true)
		_rarity_reel.present(tower, shop.tower_artwork)
		_refresh()


func _rarity_reel_finished() -> void:
	world.set_input_blocked(resize_dialog.visible or reset_dialog.visible)
	_refresh()


func _show_notice(message: String) -> void:
	if is_visible_in_tree():
		sound_player.reject()
	_notice.text = message
	_notice_timer.start()


func _input(event: InputEvent) -> void:
	if _rarity_reel.is_busy():
		return
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
	if get_viewport().gui_is_dragging():
		return
	if event.keycode == KEY_SPACE:
		_toggle_play()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if not cancel_interaction():
			MenuAudio.activate(menu_button)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _rarity_reel.is_busy():
		return
	if not _active or not is_visible_in_tree() or resize_dialog.visible or reset_dialog.visible or get_viewport().gui_is_dragging():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	for popup: PopupMenu in world._hud_popups:
		if popup.visible:
			return
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_BACKSPACE:
		if _management.is_visible_in_tree() and not _find(controller.state["towers"][0], selected_tower_id).is_empty():
			_sell()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_B:
		if _build_another():
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_E:
		_spawn()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_M:
		if _management.is_visible_in_tree():
			_max_upgrades()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_R:
		if not restart_button.disabled:
			_restart()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F:
		_select_speed((speed_selector.selected + 1) % speed_selector.item_count)
		get_viewport().set_input_as_handled()
		return
	var number: int = TowerShopButton.shortcut_number_from_event(event)
	if number == 0:
		return
	for id: StringName in shop_buttons:
		var button: TowerShopButton = shop_buttons[id]
		if button.shortcut_number == number and button.is_visible_in_tree() and not button.disabled:
			_select_placement(id)
			get_viewport().set_input_as_handled()
			return
