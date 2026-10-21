class_name MatchPlanningScreen
extends Control

signal leave_requested


# Rule: tower levels always display as Roman numerals, at any level.
const ROMAN_NUMERALS: Array[Array] = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]


class CurrencyIcon extends Control:
	var shard: bool = false

	func _draw() -> void:
		if shard:
			draw_colored_polygon(PackedVector2Array([Vector2(10, 1), Vector2(17, 8), Vector2(12, 21), Vector2(4, 15), Vector2(3, 7)]), Color("76cbd8"))
			draw_colored_polygon(PackedVector2Array([Vector2(10, 1), Vector2(10, 15), Vector2(4, 15), Vector2(3, 7)]), Color("c1eff0"))
			draw_line(Vector2(10, 15), Vector2(12, 21), Color("398397"), 2)
		else:
			draw_circle(Vector2(10, 11), 9, Color("9d743b"))
			draw_circle(Vector2(10, 9), 8, Color("e0bc77"))
			draw_arc(Vector2(10, 9), 5, PI * 0.8, PI * 1.8, 8, Color("f5dca5"), 2)
			draw_line(Vector2(10, 5), Vector2(10, 13), Color("9d743b"), 2)

var planning: MatchPlanning
var selected_tower_id: int = -1
var selected_enemy_id: int = -1
var selected_enemy_slot: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)
var _repeat_placement: bool = false
var _placement_id: StringName = &""
var _selected_enemy_type: StringName = &""
var shop_buttons: Dictionary[StringName, TowerShopButton] = {}
var _owns_tree_pause: bool = false
var _special_upgrade_command: String = ""
var _alternate_upgrade_command: String = ""
var advancement_buttons: Dictionary[String, Button] = {}
var results_menu: MatchResultsMenu
var _results_run_id: String = ""
var sound_player: GameSoundPlayer
var _roll_details: Label
var rarity_reroll: Button
var attribute_reroll: Button
var _extra_upgrade_buttons: Dictionary[String, Button] = {}
var _reroll_balance: Label
var _rarity_reel: RarityReel
var _pending_rarity_id: int = -1
var _pending_rarity_count: int = -1
var _queued_rarity_tower: Dictionary = {}
var _boss_rewards := BossRewardPresenter.new()

@onready var world: MatchWorld = $World
@onready var boards: Array[PathBoard] = world.boards
@onready var menu_button: Button = %MenuButton
@onready var pause_menu: MatchPauseMenu = $PauseMenu
@onready var debug_button: Button = %DebugButton
@onready var debug_popup: PopupPanel = $DebugPopup
@onready var debug_round: SpinBox = %DebugRound
@onready var debug_money: SpinBox = %DebugMoney
@onready var debug_shards: SpinBox = %DebugShards
@onready var debug_apply: Button = %DebugApply
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var _ready_timer: Label = %ReadyTimer
@onready var send_button: Button = %SendEnemy
@onready var enemy_selector: OptionButton = %EnemyType
@onready var speed_button: Button = %Speed
@onready var autoplay_button: Button = %Autoplay
@onready var _palette: HBoxContainer = %TowerPalette
@onready var _coins: Label = %Coins
@onready var _health_bar: ProgressBar = %BaseHealth
@onready var _health_value: Label = %BaseHealthValue
@onready var _health_icon: Control = %HealthIcon
@onready var _health_accents: Control = %HealthAccents
@onready var _income: Label = %Income
@onready var _cancel_placement: Button = %CancelPlacement
@onready var _management: PanelContainer = %TowerManagement
@onready var _enemy_inspector: EnemyInspector = %EnemyInspector
@onready var _tower_title: Label = %TowerTitle
@onready var damage_upgrade: Button = %DamageUpgrade
@onready var speed_upgrade: Button = %SpeedUpgrade
@onready var special_upgrade: Button = %SpecialUpgrade
@onready var alternate_upgrade: Button = %AlternateUpgrade
@onready var _upgrade_row: HBoxContainer = %Upgrades
@onready var sell_button: Button = %SellTower
@onready var close_button: Button = %CloseTower
@onready var targeting_button: TargetingCycle = %Targeting
@onready var _tower_stats: Label = %TowerStats
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _titles: Array[Label] = [$HUD/Header/Content/Players/Host/Heading/Title, $HUD/Header/Content/Players/Guest/Heading/Title]
@onready var _budgets: Array[Label] = [$HUD/Header/Content/Players/Host/Budget, $HUD/Header/Content/Players/Guest/Budget]
@onready var _counts: Array[Label] = [$HUD/Header/Content/Players/Host/Count, $HUD/Header/Content/Players/Guest/Count]


func _ready() -> void:
	CloseButtonStyle.apply(_cancel_placement)
	CloseButtonStyle.apply(close_button)
	sound_player = GameSoundPlayer.new()
	sound_player.world = world
	add_child(sound_player)
	for slot: int in range(boards.size()):
		boards[slot].edit_requested.connect(_request_edit.bind(slot))
		boards[slot].cell_clicked.connect(_cell_clicked.bind(slot))
		boards[slot].tower_dropped.connect(_tower_dropped.bind(slot))
		boards[slot].enemy_clicked.connect(_enemy_clicked.bind(slot))
		boards[slot].command_mode = true
		if planning != null:
			boards[slot].content_catalog = planning.combat_rules.catalog
	_create_palette()
	_build_currencies()
	_build_health()
	_build_tower_management()
	_cancel_placement.pressed.connect(cancel_interaction)
	close_button.pressed.connect(cancel_interaction)
	_enemy_inspector.close_requested.connect(cancel_interaction)
	damage_upgrade.pressed.connect(_upgrade.bind("damage"))
	speed_upgrade.pressed.connect(_upgrade.bind("speed"))
	special_upgrade.pressed.connect(_choice_upgrade_pressed.bind(false))
	alternate_upgrade.pressed.connect(_choice_upgrade_pressed.bind(true))
	sell_button.pressed.connect(_sell)
	targeting_button.mode_requested.connect(_target_selected)
	for command: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
		var button: Button = _upgrade_row.get_node(NodePath(command)) as Button
		advancement_buttons[command] = button
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_upgrade.bind(command))
	clear_button.pressed.connect(_clear)
	ready_button.pressed.connect(_toggle_ready)
	send_button.pressed.connect(_send_enemy)
	enemy_selector.item_selected.connect(_enemy_type_selected)
	speed_button.pressed.connect(_request_pacing.bind("speed"))
	autoplay_button.pressed.connect(_request_pacing.bind("autoplay"))
	MenuAudio.bind_action(menu_button)
	menu_button.pressed.connect(open_pause_menu)
	debug_button.pressed.connect(_open_debug)
	debug_apply.pressed.connect(_apply_debug)
	debug_popup.popup_hide.connect(_debug_closed)
	debug_popup.window_input.connect(_debug_window_input)
	for spin: SpinBox in [debug_round, debug_money, debug_shards]:
		spin.get_line_edit().add_theme_font_override("font", _coins.get_theme_font("font"))
		spin.get_line_edit().add_theme_font_size_override("font_size", 16)
	pause_menu.resume_requested.connect(_resume_match)
	pause_menu.quit_requested.connect(_quit_match)
	results_menu = preload("res://scenes/match_results_menu.tscn").instantiate()
	add_child(results_menu)
	results_menu.menu_requested.connect(_quit_match)
	results_menu.inspect_requested.connect(_inspect_results)
	results_menu.replay_requested.connect(_replay_results)
	visibility_changed.connect(_visibility_changed)
	_feedback_timer.timeout.connect(_clear_feedback)
	_rarity_reel = RarityReel.new()
	add_child(_rarity_reel)
	_rarity_reel.finished.connect(_rarity_reel_finished)
	if planning != null:
		planning.changed.connect(_refresh)
		planning.feedback.connect(_show_feedback)
	_refresh()


func _build_tower_management() -> void:
	var content: VBoxContainer = _management.get_node("Content") as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.name = "InspectionScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	_management.add_child(shell)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	content.reparent(scroll, false)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_details = Label.new()
	_roll_details.name = "TowerRoll"
	_roll_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll_details.add_theme_font_override("font", _coins.get_theme_font("font"))
	_roll_details.add_theme_font_size_override("font_size", 16)
	content.add_child(_roll_details)
	content.move_child(_roll_details, 1)
	var rerolls := VBoxContainer.new()
	rerolls.name = "Rerolls"
	content.add_child(rerolls)
	content.move_child(rerolls, 3)
	for kind: String in ["rarity", "attributes"]:
		var button := Button.new()
		button.name = "RerollRarity" if kind == "rarity" else "RerollAttributes"
		button.custom_minimum_size.y = 36
		button.add_theme_font_override("font", _coins.get_theme_font("font"))
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_reroll.bind(kind))
		rerolls.add_child(button)
		if kind == "rarity":
			rarity_reroll = button
		else:
			attribute_reroll = button
	for button: Button in [damage_upgrade, speed_upgrade, special_upgrade, alternate_upgrade]:
		button.custom_minimum_size = Vector2(0, 56)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var heading := HBoxContainer.new()
	shell.add_child(heading)
	shell.move_child(heading, 0)
	_tower_title.reparent(heading, false)
	_tower_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.reparent(heading, false)



func _build_health() -> void:
	_health_icon.draw.connect(_draw_health_emblem)
	_health_accents.draw.connect(_draw_health_accents)
	_health_accents.resized.connect(_health_accents.queue_redraw)


func _draw_health_emblem() -> void:
	_health_icon.draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(18, 6), Vector2(18, 15), Vector2(10, 22), Vector2(2, 15), Vector2(2, 6)]), Color("102c43"))
	_health_icon.draw_colored_polygon(PackedVector2Array([Vector2(10, 2), Vector2(4, 7), Vector2(10, 9)]), Color("b6efff"))
	_health_icon.draw_colored_polygon(PackedVector2Array([Vector2(10, 2), Vector2(16, 7), Vector2(10, 9)]), Color("64cef5"))
	_health_icon.draw_colored_polygon(PackedVector2Array([Vector2(4, 7), Vector2(10, 9), Vector2(10, 20), Vector2(4, 14)]), Color("3ba8e7"))
	_health_icon.draw_colored_polygon(PackedVector2Array([Vector2(10, 9), Vector2(16, 7), Vector2(16, 14), Vector2(10, 20)]), Color("2776b9"))
	_health_icon.draw_rect(Rect2(9, 9, 1, 7), Color("80daf5"))


func _draw_health_accents() -> void:
	var width: int = roundi(_health_accents.size.x)
	var height: int = roundi(_health_accents.size.y)
	var filled_width: int = roundi(float(width) * _health_bar.get_as_ratio())
	if filled_width > 0:
		_health_accents.draw_rect(Rect2(0, height - 1, filled_width, 1), Color("19518b"))


func _refresh_health(accepted_health: int, accepted_maximum: int) -> void:
	# Range needs a nonzero span; the label and tooltip retain accepted host values.
	_health_bar.max_value = maxi(1, accepted_maximum)
	_health_bar.value = accepted_health if accepted_maximum > 0 else 0
	_health_value.text = str(accepted_health)
	_health_bar.tooltip_text = "Base health: %d/%d" % [accepted_health, accepted_maximum]
	_health_value.tooltip_text = _health_bar.tooltip_text
	_health_accents.queue_redraw()


func _build_currencies() -> void:
	var summary: HBoxContainer = _coins.get_parent() as HBoxContainer
	var currencies := HBoxContainer.new()
	currencies.name = "Currencies"
	currencies.add_theme_constant_override("separation", 6)
	summary.add_child(currencies)
	summary.move_child(currencies, _coins.get_index())
	_reroll_balance = Label.new()
	_reroll_balance.name = "RerollCurrency"
	for shard: bool in [false, true]:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("131e1a")
		style.border_color = Color("526b67") if shard else Color("766744")
		style.set_border_width_all(1)
		style.content_margin_left = 6
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		panel.tooltip_text = "Shards" if shard else "Coins"
		currencies.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var icon := CurrencyIcon.new()
		icon.shard = shard
		icon.custom_minimum_size = Vector2(20, 22)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var value: Label = _reroll_balance if shard else _coins
		if shard:
			value.add_theme_font_override("font", _coins.get_theme_font("font"))
			value.add_theme_font_size_override("font_size", 16)
			value.add_theme_color_override("font_color", Color("b7e5e7"))
			row.add_child(value)
		else:
			value.reparent(row, false)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _reroll(kind: String) -> void:
	var button: Button = rarity_reroll if kind == "rarity" else attribute_reroll
	var tower: Dictionary = _selected_tower()
	if planning == null or not button.is_visible_in_tree() or button.disabled or tower.is_empty() or _rarity_reel.is_busy() or _pending_rarity_id >= 0 or not _queued_rarity_tower.is_empty():
		return
	if kind == "rarity":
		_pending_rarity_id = selected_tower_id
		_pending_rarity_count = int(tower["rarity_rerolls"])
		rarity_reroll.disabled = true
	if not planning.reroll_tower(planning.local_slot(), selected_tower_id, kind):
		_pending_rarity_id = -1
		_refresh()


func _observe_rarity_reroll() -> void:
	if _pending_rarity_id < 0:
		return
	for tower: Dictionary in planning.combat.get("towers", [[], []])[planning.local_slot()]:
		if int(tower["id"]) != _pending_rarity_id:
			continue
		if int(tower["rarity_rerolls"]) > _pending_rarity_count:
			_pending_rarity_id = -1
			_queued_rarity_tower = tower.duplicate(true)
		return
	_pending_rarity_id = -1


func _rarity_reel_finished() -> void:
	world.set_input_blocked(pause_menu.visible or debug_popup.visible or results_menu.visible or _rarity_reel.is_busy())
	_refresh.call_deferred()


func _reset_rarity_presentation() -> void:
	_pending_rarity_id = -1
	_pending_rarity_count = -1
	_queued_rarity_tower.clear()
	_rarity_reel.cancel()


func _clear_reel_presentations() -> void:
	_boss_rewards.clear()
	_reset_rarity_presentation()


func _present_pending_reel() -> void:
	if planning == null or not planning.active or not is_visible_in_tree():
		return
	var blocked: bool = pause_menu.visible or debug_popup.visible or results_menu.visible
	_rarity_reel.set_suspended(blocked)
	if not blocked and not _rarity_reel.is_busy():
		if not _queued_rarity_tower.is_empty():
			var button: TowerShopButton = shop_buttons.get(StringName(_queued_rarity_tower["type_id"]))
			_rarity_reel.present(_queued_rarity_tower, button.tower_artwork if button != null else null)
			if _rarity_reel.is_busy():
				_queued_rarity_tower.clear()
		elif _pending_rarity_id < 0 and _boss_rewards.pending_count() > 0:
			var artwork: Texture2D
			var boss_id: StringName = _boss_rewards.next_boss_id()
			for definition: EnemyDefinition in planning.combat_rules.catalog.enemies:
				if definition.id == boss_id:
					artwork = definition.texture
					break
			_boss_rewards.present_next(_rarity_reel, artwork)
	if _rarity_reel.is_busy():
		cancel_strokes()
		enemy_selector.get_popup().hide()
	world.set_input_blocked(blocked or _rarity_reel.is_busy())


func cancel_strokes() -> void:
	if not is_node_ready():
		return
	for board: PathBoard in boards:
		board.cancel_stroke()


func open_pause_menu() -> void:
	if planning == null or not planning.active or not is_visible_in_tree() or pause_menu.visible:
		return
	if int(planning.combat.get("phase",-1)) == MatchCombat.Phase.FINISHED:
		open_results()
		return
	debug_popup.hide()
	cancel_interaction()
	cancel_strokes()
	enemy_selector.get_popup().hide()
	world.set_input_blocked(true)
	$HUD.process_mode = Node.PROCESS_MODE_DISABLED
	pause_menu.open_menu(not planning.singleplayer)
	_rarity_reel.set_suspended(true)
	sound_player.set_combat_paused(planning.singleplayer)
	_owns_tree_pause = planning.singleplayer
	if _owns_tree_pause:
		get_tree().paused = true


func _resume_match() -> void:
	_close_pause_menu()
	if is_visible_in_tree():
		menu_button.grab_focus()
	_present_pending_reel()


func _quit_match() -> void:
	_close_pause_menu()
	_close_results()
	_clear_reel_presentations()
	leave_requested.emit()


func _close_pause_menu() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	pause_menu.close_menu()
	sound_player.set_combat_paused(false)
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT
	world.set_input_blocked(debug_popup.visible or results_menu.visible or _rarity_reel.is_busy())


func _exit_tree() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false


func _visibility_changed() -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
		_clear_reel_presentations()
		sound_player.deactivate()
		debug_popup.hide()
		_close_results()
		_close_pause_menu()
		world.set_active(false)
		cancel_strokes()
		selected_enemy_id = -1
		selected_enemy_slot = -1
		_enemy_inspector.hide()
		for board: PathBoard in boards:
			board.selected_enemy_id = -1
		_clear_feedback()
	else:
		_refresh()


func _open_debug() -> void:
	if planning == null or not planning.can_debug() or not is_visible_in_tree() or pause_menu.visible:
		return
	cancel_interaction()
	cancel_strokes()
	enemy_selector.get_popup().hide()
	var state: Dictionary = planning.combat
	debug_round.value = int(state.get("wave", 0)) + (1 if int(state.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.PLANNING else 0)
	debug_money.value = _own_coins()
	debug_shards.value = int(planning.combat["reroll_currency"][planning.local_slot()])
	world.set_input_blocked(true)
	debug_popup.popup_centered()
	_rarity_reel.set_suspended(true)
	debug_round.get_line_edit().grab_focus()
	debug_round.get_line_edit().select_all()


func _apply_debug() -> void:
	debug_round.apply()
	debug_money.apply()
	debug_shards.apply()
	if planning != null and planning.debug_set_values(int(debug_round.value), int(debug_money.value), int(debug_shards.value)):
		debug_popup.hide()


func _debug_closed() -> void:
	world.set_input_blocked(pause_menu.visible or results_menu.visible or _rarity_reel.is_busy())
	_refresh.call_deferred()


func _debug_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		debug_popup.hide()
		debug_popup.set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _rarity_reel.is_busy():
		return
	if not is_visible_in_tree() or pause_menu.visible or debug_popup.visible or (_placement_id == &"" and selected_enemy_id < 0 and selected_tower_id < 0):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _rarity_reel.is_busy():
		return
	if not is_visible_in_tree() or planning == null or not planning.active or pause_menu.visible or debug_popup.visible or results_menu.visible or get_viewport().gui_is_dragging():
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
		if _management.is_visible_in_tree() and not sell_button.disabled and not _selected_tower().is_empty():
			_sell()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_B:
		if _build_another():
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


func cancel_interaction() -> bool:
	if _placement_id == &"" and selected_tower_id < 0 and selected_enemy_id < 0 and _pending_tower_cell == Vector2i(-1, -1):
		return false
	cancel_strokes()
	_placement_id = &""
	selected_tower_id = -1
	selected_enemy_id = -1
	selected_enemy_slot = -1
	_pending_tower_cell = Vector2i(-1, -1)
	_repeat_placement = false
	_refresh()
	return true


func _tower_drag_started(_type_id: StringName) -> void:
	if not cancel_interaction():
		cancel_strokes()


func _request_edit(cell: Vector2i, place: bool, slot: int) -> void:
	if planning != null and planning.can_edit_path(slot) and slot == planning.local_slot() and _placement_id == &"":
		planning.request_edit(slot, cell, place)


func _cell_clicked(cell: Vector2i, button: MouseButton, slot: int) -> void:
	if planning == null or not planning.active:
		return
	if button == MOUSE_BUTTON_RIGHT:
		cancel_interaction()
		return
	selected_enemy_id = -1
	selected_enemy_slot = -1
	if slot != planning.local_slot():
		_refresh()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	_pending_tower_cell = Vector2i(-1, -1)
	for tower: Dictionary in boards[slot].combat_towers:
		if tower["cell"] == cell:
			cancel_strokes()
			_placement_id = &""
			selected_tower_id = int(tower["id"])
			_refresh()
			return
	selected_tower_id = -1
	if int(planning.combat.get("phase", -1)) == MatchCombat.Phase.FINISHED:
		_refresh()
		return
	if _placement_id != &"":
		_buy_tower(cell, _placement_id, slot)
	else:
		_refresh()


func _tower_dropped(cell: Vector2i, type_id: StringName, slot: int) -> void:
	if planning == null or not planning.active or slot != planning.local_slot():
		return
	if not shop_buttons.has(type_id) or shop_buttons[type_id].disabled:
		return
	cancel_strokes()
	_placement_id = &""
	selected_tower_id = -1
	selected_enemy_id = -1
	selected_enemy_slot = -1
	_buy_tower(cell, type_id, slot)


func _buy_tower(cell: Vector2i, type_id: StringName, slot: int) -> void:
	if not planning.can_manage_towers(slot):
		return
	_pending_tower_cell = cell
	# Capture at submission: remote acknowledgement may arrive after key release.
	_repeat_placement = Input.is_key_pressed(KEY_SHIFT)
	if _repeat_placement:
		_placement_id = type_id
	planning.build_tower(slot, cell, type_id, _default_targeting)
	_refresh()


func _build_another() -> bool:
	var tower: Dictionary = _selected_tower()
	if tower.is_empty() or planning == null or not planning.can_manage_towers(planning.local_slot()):
		return false
	var type_id := StringName(tower["type_id"])
	var button: TowerShopButton = shop_buttons.get(type_id)
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return false
	_select_placement(type_id)
	return true


func _select_placement(type_id: StringName) -> void:
	if not shop_buttons.has(type_id) or shop_buttons[type_id].disabled:
		return
	cancel_strokes()
	_pending_tower_cell = Vector2i(-1, -1)
	selected_tower_id = -1
	selected_enemy_id = -1
	selected_enemy_slot = -1
	_placement_id = type_id
	_refresh()


func _placement_type() -> StringName:
	return _placement_id


func _create_palette() -> void:
	var catalog: Array[TowerReward] = planning.combat_rules.catalog.tower_rewards() if planning != null else []
	for reward: TowerReward in catalog:
		var button := TowerShopButton.new()
		button.name = String(reward.id)
		button.tower_type = reward.id
		button.tower_title = reward.title
		button.tower_artwork = reward.icon_texture
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_select_placement.bind(reward.id))
		button.drag_started.connect(_tower_drag_started)
		_palette.add_child(button)
		shop_buttons[reward.id] = button


func _refresh_palette() -> void:
	var types: Dictionary = planning.combat.get("tower_types", {}) if planning != null else {}
	var coins: int = _own_coins()
	var available: bool = planning != null and planning.can_manage_towers(planning.local_slot())
	var shortcut_number: int = 0
	for id: StringName in shop_buttons:
		var button: TowerShopButton = shop_buttons[id]
		var stats: Dictionary = types.get(String(id), {})
		var unlocked: bool = planning != null and planning.collection_store != null and planning.collection_store.is_unlocked(id)
		var equipped: bool = planning != null and planning.is_equipped(id)
		button.visible = equipped
		if equipped:
			shortcut_number += 1
		button.shortcut_number = shortcut_number if equipped else 0
		var title: String = String(stats.get("title", button.tower_title))
		button.tower_title = title
		button.cost = int(stats.get("cost", 0))
		var status: String = ""
		if not unlocked:
			status = "Locked"
		elif stats.is_empty():
			status = "Unavailable"
		button.disabled = not available or not equipped or not unlocked or stats.is_empty() or coins < button.cost
		button.set_pressed_no_signal(id == _placement_id)
		var price: String = str(button.cost) if not stats.is_empty() else ""
		button.refresh_caption(price, status)
		button.tooltip_text = "%d Coins\n%s" % [button.cost, behavior_summary(stats)] if not stats.is_empty() else "This tower is unavailable in the host's match catalog."
		if not button.disabled:
			button.tooltip_text += "\nHold Shift when placing or dropping to keep building."
		if coins < button.cost:
			button.tooltip_text += "\nNeed %d more Coins." % (button.cost - coins)
		if not unlocked:
			button.tooltip_text = "Unlock this tower in Collection before buying it."
		elif not available:
			if planning != null and planning.active:
				button.tooltip_text += "\nMatch finished." if int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED else "\nReady: planning actions are committed until the round starts."
			else:
				button.tooltip_text += "\nPurchases are unavailable outside an active run."
		if id == _placement_id and button.disabled:
			_placement_id = &""
			button.set_pressed_no_signal(false)
	_coins.text = str(coins)
	var currency: Array = planning.combat.get("reroll_currency", [0, 0]) if planning != null else [0, 0]
	_reroll_balance.text = str(int(currency[planning.local_slot() if planning != null else 0]))
	_refresh_sends()
	_cancel_placement.visible = _placement_id != &""


func _own_coins() -> int:
	if planning == null:
		return 0
	var coins: Array = planning.combat.get("coins", [0, 0])
	return int(coins[planning.local_slot()])


func _refresh_sends() -> void:
	var state: Dictionary = planning.combat if planning != null else {}
	var rules: Dictionary = state.get("rules", {})
	var types: Dictionary = state.get("enemy_types", {})
	_refresh_enemy_selector(types)
	var own_slot: int = planning.local_slot() if planning != null else 0
	var income: Array = state.get("income", [0, 0])
	var queued: Array = state.get("queued_sends", [0, 0])
	var queues: Array = state.get("send_queues", [[], []])
	var phase: int = int(state.get("phase", MatchCombat.Phase.PLANNING))
	var finished: bool = phase == MatchCombat.Phase.FINISHED
	var stats: Dictionary = types.get(String(_selected_enemy_type), {})
	var configured: bool = not stats.is_empty() and rules.has("send_spawn_interval")
	var cost: int = int(stats.get("send_cost", 0))
	var gain: int = int(stats.get("send_income", 0))
	var available: bool = planning != null and planning.can_manage_towers(own_slot) and configured and bool(stats.get("send_available", false))
	enemy_selector.disabled = planning == null or not planning.active or finished or types.is_empty()
	send_button.disabled = not available or _own_coins() < cost or int(income[own_slot]) < -gain
	send_button.text = "Send · %d/%+d" % [cost, gain] if configured else "Send unavailable"
	if finished:
		send_button.text = "Match finished"
	var recurring: int = int(income[own_slot])
	var incoming: int = int(queued[own_slot])
	var outgoing: int = int(queued[1 - own_slot])
	var summary: String = "Income +%d" % recurring if recurring > 0 else ""
	if incoming > 0:
		summary += (" · " if not summary.is_empty() else "") + "In %d" % incoming
	if outgoing > 0:
		summary += (" · " if not summary.is_empty() else "") + "Out %d" % outgoing
	_income.text = summary
	_income.visible = not finished and not summary.is_empty()
	var queue_feedback: String = "Pending send streams:\nIncoming to you: %d (%s).\nOutgoing to opponent: %d (%s)." % [int(queued[own_slot]), _queue_composition(queues[own_slot], types), int(queued[1 - own_slot]), _queue_composition(queues[1 - own_slot], types)]
	if finished:
		queue_feedback += "\nMatch finished; no further delivery or income payouts."
	_income.tooltip_text = "Your recurring bonus: %d Coins at every both-board wave clear, on top of the regular reward. No immediate or terminal payout.\n%s" % [int(income[own_slot]), queue_feedback]
	if not configured:
		send_button.tooltip_text = "Waiting for host enemy types and send rules.\n" + queue_feedback
		enemy_selector.tooltip_text = send_button.tooltip_text
		return
	var delivery: String = "Opponent's independent send stream, delivering during this round." if phase == MatchCombat.Phase.WAVE else "Queued for the opponent's independent stream when combat starts."
	if not available:
		delivery = "Match finished." if finished else ("Ready: planning actions are committed until the round starts." if planning != null and planning.active else "Waiting for match.")
		if configured and not bool(stats.get("send_available", false)) and not finished:
			delivery = "Available from round %d." % int(stats.get("send_first_wave", 1))
	else:
		if _own_coins() < cost:
			delivery += "\nNeed %d more Coins." % (cost - _own_coins())
		if int(income[own_slot]) < -gain:
			delivery += "\nNeed %d more recurring income." % (-gain - int(income[own_slot]))
	var stats_wave: int = int(state.get("wave", 0)) if phase == MatchCombat.Phase.WAVE or finished else int(state.get("wave", 0)) + 1
	send_button.tooltip_text = "%s\n%s\nHost stats for round %d: %d HP · %.2f cells/s.\n%s\nOrder cooldown: %.3f simulation seconds after its final member." % [_enemy_send_description(stats), delivery, stats_wave, int(stats.get("health", 0)), float(stats.get("speed", 0.0)), queue_feedback, float(rules["send_spawn_interval"])]
	enemy_selector.tooltip_text = send_button.tooltip_text
	for index: int in range(enemy_selector.item_count):
		var type_stats: Dictionary = types[String(enemy_selector.get_item_metadata(index))]
		enemy_selector.set_item_tooltip(index, "%s\nHost stats for wave %d: %d HP · %.2f cells/s." % [_enemy_send_description(type_stats), stats_wave, int(type_stats.get("health", 0)), float(type_stats.get("speed", 0.0))])


func _refresh_enemy_selector(types: Dictionary) -> void:
	var ids: Array[String] = []
	for id: String in types:
		if bool(types[id].get("send_enabled", false)):
			ids.append(id)
	var rebuild: bool = enemy_selector.item_count != ids.size()
	if not rebuild:
		for index: int in range(ids.size()):
			if String(enemy_selector.get_item_metadata(index)) != ids[index]:
				rebuild = true
				break
	if rebuild:
		enemy_selector.clear()
		for id: String in ids:
			enemy_selector.add_item(String(types[id].get("title", id)))
			enemy_selector.set_item_metadata(enemy_selector.item_count - 1, id)
	if ids.is_empty():
		return
	if not ids.has(String(_selected_enemy_type)) or not bool(types[String(_selected_enemy_type)].get("send_available", false)):
		_selected_enemy_type = StringName(ids[0])
		for id: String in ids:
			if bool(types[id].get("send_available", false)):
				_selected_enemy_type = StringName(id)
				break
	for index: int in range(ids.size()):
		enemy_selector.set_item_text(index, String(types[ids[index]].get("title", ids[index])))
		var available: bool = bool(types[ids[index]].get("send_available", false))
		enemy_selector.set_item_disabled(index, not available)
		if ids[index] == String(_selected_enemy_type) and enemy_selector.selected != index:
			enemy_selector.select(index)


func _enemy_send_description(stats: Dictionary) -> String:
	return "%s: %d Coins; %+d recurring Coins per both-board clear." % [String(stats.get("title", _selected_enemy_type)), int(stats.get("send_cost", 0)), int(stats.get("send_income", 0))]


func _queue_composition(queue: Array, types: Dictionary) -> String:
	var counts: Dictionary[String, int] = {}
	for id: String in queue:
		counts[id] = counts.get(id, 0) + 1
	var parts: PackedStringArray = []
	for id: String in counts:
		var stats: Dictionary = types.get(id, {})
		parts.append("%s ×%d" % [String(stats.get("title", id)), counts[id]])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _enemy_type_selected(index: int) -> void:
	_selected_enemy_type = StringName(enemy_selector.get_item_metadata(index))
	_refresh_sends()


func _send_enemy() -> void:
	if planning != null and not send_button.disabled:
		planning.send_enemy(planning.local_slot(), _selected_enemy_type)


func _target_selected(mode: int) -> void:
	var tower: Dictionary = _selected_tower()
	if tower.is_empty():
		_default_targeting = mode
	elif planning != null and planning.active and not targeting_button.disabled:
		planning.set_targeting(planning.local_slot(), selected_tower_id, mode)
	# A requested mode is not displayed as accepted until the host snapshot agrees.
	_refresh_targeting()


# The vote a pacing click sends: off -> on -> stronger (3× speed, or full
# autoplay that also runs main rounds) -> off.
static func pacing_request(option: String, state: Dictionary, slot: int) -> Array:
	var stronger: String = "triple_speed" if option == "speed" else "full_autoplay"
	var voted: bool = bool(state.get(option + "_votes", [false, false])[slot])
	if voted and not bool(state.get(stronger + "_votes", [false, false])[slot]):
		return [stronger, true]
	return [option, not voted]


func _request_pacing(option: String) -> void:
	if planning == null or not planning.active:
		return
	if option == "speed" and planning.singleplayer:
		planning.cycle_singleplayer_speed()
		return
	var request: Array = pacing_request(option, planning.combat, planning.local_slot())
	planning.request_pacing(String(request[0]), bool(request[1]))


func _refresh_pacing() -> void:
	var state: Dictionary = planning.combat if planning != null else {}
	var available: bool = planning != null and planning.active and int(state.get("phase", MatchCombat.Phase.PLANNING)) != MatchCombat.Phase.FINISHED
	var slot: int = planning.local_slot() if planning != null else 0
	for option: String in ["speed", "autoplay"]:
		var button: Button = speed_button if option == "speed" else autoplay_button
		var votes: Array = state.get(option + "_votes", [false, false])
		var enabled: bool = bool(votes[slot])
		var agreed: bool = float(state.get("speed_multiplier", 1.0)) > 1.0 if option == "speed" else bool(state.get("autoplay", false))
		var solo: bool = planning != null and planning.singleplayer
		var multiplier: int = int(state.get("speed_multiplier", 1.0))
		var triple_votes: Array = state.get("triple_speed_votes", [false, false])
		var triple_vote: bool = bool(triple_votes[slot])
		# A 3× vote stays gold until both players pick 3×.
		if option == "speed" and triple_vote and not solo:
			agreed = multiplier == 3
		button.disabled = not available
		button.set_pressed_no_signal(enabled)
		var color := Color("b5e2b7") if agreed else Color("e0bc77")
		for theme_color: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(theme_color, color)
		var full_vote: bool = bool(state.get("full_autoplay_votes", [false, false])[slot])
		if option == "autoplay":
			button.icon = preload("res://assets/ui/autoplay_full.svg") if full_vote else preload("res://assets/ui/autoplay.svg")
			agreed = bool(state.get("full_autoplay", false)) if full_vote else agreed
		if option == "speed":
			# Solo shows the running speed; multiplayer shows your own vote.
			var shown: int = multiplier if solo else (3 if triple_vote else (2 if enabled else 1))
			button.icon = preload("res://assets/ui/speed_triple.svg") if shown == 3 else (preload("res://assets/ui/speed_double.svg") if shown == 2 else preload("res://assets/ui/speed_normal.svg"))
			if solo:
				button.tooltip_text = "%d× speed · click to cycle 1× / 2× / 3×" % multiplier
			else:
				button.tooltip_text = "3× speed" if triple_vote else "2× speed"
				if enabled and not triple_vote:
					button.tooltip_text += "\nClick again for 3× speed"
		else:
			button.tooltip_text = "Full autoplay · includes main rounds" if full_vote else "Autoplay"
			if enabled and not full_vote:
				button.tooltip_text += "\nClick again for full autoplay"
		if agreed:
			button.tooltip_text += " · On"
		elif enabled:
			button.tooltip_text += " · Waiting for opponent"
		elif bool(votes[1 - slot]):
			button.tooltip_text += " · Opponent enabled"
		if option == "speed" and not solo:
			if triple_vote and multiplier == 2:
				button.tooltip_text += " · Running at 2×"
			elif bool(triple_votes[1 - slot]) and not triple_vote:
				button.tooltip_text += "\nOpponent picked 3×"
		if option == "autoplay" and agreed and not planning.locked and (not planning.layouts[0].is_ready() or not planning.layouts[1].is_ready()):
			button.tooltip_text += "\nWaiting for legal paths"
		if option == "autoplay" and agreed and not bool(state.get("full_autoplay", false)) and bool(state.get("path_editing", false)):
			button.tooltip_text += "\nStrategy break: both players must press Ready."


func _enemy_clicked(enemy_id: int, slot: int) -> void:
	if planning == null or not planning.active or _placement_id != &"":
		return
	cancel_strokes()
	selected_tower_id = -1
	_pending_tower_cell = Vector2i(-1, -1)
	selected_enemy_id = enemy_id
	selected_enemy_slot = slot
	_refresh()


func _selected_enemy() -> Dictionary:
	if planning == null or selected_enemy_id < 0 or selected_enemy_slot < 0:
		return {}
	var enemies: Array = planning.combat.get("enemies", [[], []])
	for enemy: Dictionary in enemies[selected_enemy_slot]:
		if int(enemy["id"]) == selected_enemy_id:
			return enemy
	return {}


func _refresh_enemy_inspector() -> void:
	var enemy: Dictionary = _selected_enemy()
	var types: Dictionary = planning.combat.get("enemy_types", {}) if planning != null else {}
	_enemy_inspector.refresh(enemy, types.get(String(enemy.get("type_id", "")), {}))


func _selected_tower() -> Dictionary:
	if planning == null or selected_tower_id < 0:
		return {}
	var all_towers: Array = planning.combat.get("towers", [[], []])
	for tower: Dictionary in all_towers[planning.local_slot()]:
		if int(tower["id"]) == selected_tower_id:
			return tower
	return {}


func _refresh_targeting() -> void:
	var tower: Dictionary = _selected_tower()
	_management.visible = not tower.is_empty()
	if tower.is_empty():
		targeting_button.mode = _default_targeting
		return
	var types: Dictionary = planning.combat.get("tower_types", {})
	var stats: Dictionary = types.get(String(tower["type_id"]), {})
	_tower_title.text = tower_display_title(tower, stats)
	_tower_title.add_theme_color_override("font_color", tower_rarity_color(tower))
	_tower_stats.text = tower_stats_text(tower, stats)
	_roll_details.text = roll_details_text(tower)
	targeting_button.get_parent_control().visible = tower.get("behavior_kind", stats.get("behavior_kind", "attack")) in ["attack", "chain"]
	targeting_button.mode = int(tower["mode"])
	targeting_button.disabled = not planning.can_manage_towers(planning.local_slot())
	var terminal: bool = int(planning.combat.get("phase", -1)) == MatchCombat.Phase.FINISHED
	rarity_reroll.visible = not terminal
	attribute_reroll.visible = not terminal
	sell_button.visible = not terminal
	if terminal:
		for control: Control in _upgrade_row.get_children():
			control.hide()
		_upgrade_row.hide()
		return
	var currency: Array = planning.combat.get("reroll_currency", [0, 0])
	_refresh_reroll(rarity_reroll, tower, "rarity", int(currency[planning.local_slot()]))
	_refresh_reroll(attribute_reroll, tower, "attributes", _own_coins())
	var actions: Dictionary = tower_upgrade_actions(tower, stats)
	var base_ready: bool = bool(tower.get("damage_upgraded", false)) and bool(tower.get("speed_upgraded", false))
	for command: String in ["damage", "speed"]:
		_refresh_action(damage_upgrade if command == "damage" else speed_upgrade, actions[command])
	var choices: Array[String] = []
	for command: String in actions:
		if base_ready and command not in ["damage", "speed"] and not bool(actions[command]["purchased"]):
			choices.append(command)
	_special_upgrade_command = choices[0] if not choices.is_empty() else ""
	_alternate_upgrade_command = choices[1] if choices.size() > 1 else ""
	special_upgrade.visible = not _special_upgrade_command.is_empty()
	alternate_upgrade.visible = not _alternate_upgrade_command.is_empty()
	if special_upgrade.visible:
		_refresh_action(special_upgrade, actions[_special_upgrade_command])
	if alternate_upgrade.visible:
		_refresh_action(alternate_upgrade, actions[_alternate_upgrade_command])
	for button: Button in _extra_upgrade_buttons.values():
		button.hide()
	for index: int in range(2, choices.size()):
		var command: String = choices[index]
		if not _extra_upgrade_buttons.has(command):
			var button := Button.new()
			button.custom_minimum_size.y = 56
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_override("font", _coins.get_theme_font("font"))
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(_upgrade.bind(command))
			_upgrade_row.add_child(button)
			_extra_upgrade_buttons[command] = button
		_extra_upgrade_buttons[command].show()
		_refresh_action(_extra_upgrade_buttons[command], actions[command])
	var second_archer: bool = bool(tower.get("special_upgraded", false)) and String(stats.get("special_upgrade", "")) == "second_archer"
	var advancements: Dictionary = stats.get("advancements", {})
	var available: Dictionary = advancement_actions(tower, stats)
	if second_archer and not available.is_empty():
		special_upgrade.hide()
		special_upgrade.disabled = true
		_special_upgrade_command = ""
	for command: String in advancements:
		if not advancement_buttons.has(command):
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_override("font", _coins.get_theme_font("font"))
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(_upgrade.bind(command))
			_upgrade_row.add_child(button)
			advancement_buttons[command] = button
	for command: String in advancement_buttons:
		var button: Button = advancement_buttons[command]
		button.visible = second_archer and available.has(command)
		if button.visible:
			_refresh_action(button, available[command])
		else:
			button.disabled = true
	_upgrade_row.visible = _upgrade_row.get_children().any(func(button: Button) -> bool: return button.visible)
	sell_button.text = "Sell · +%d" % int(tower.get("sell_value", 0))
	sell_button.tooltip_text = "60%% of %d invested Coins, including upgrades." % int(tower.get("invested", 0))
	sell_button.disabled = targeting_button.disabled


func _refresh_action(button: Button, action: Dictionary) -> void:
	var purchased: bool = bool(action["purchased"])
	button.visible = not purchased
	var locked: bool = bool(action["locked"])
	var price: int = int(action["cost"])
	button.text = "%s\n%s" % [action["title"], "Locked" if locked else str(price)]
	button.disabled = purchased or locked or targeting_button.disabled or _own_coins() < price
	button.tooltip_text = String(action["description"])
	if locked:
		button.tooltip_text += "\nRequires the preceding upgrades; permanent branches are exclusive."
	if not purchased and _own_coins() < price:
		button.tooltip_text += "\nNeed %d more Coins." % (price - _own_coins())
	if targeting_button.disabled:
		button.tooltip_text += "\nUnavailable while Ready or after the run ends."


func _refresh_reroll(button: Button, tower: Dictionary, kind: String, balance: int) -> void:
	var price: int = int(tower.get("rarity_reroll_cost" if kind == "rarity" else "attribute_reroll_cost", -1))
	button.text = "%s · %s" % ["Reroll rarity" if kind == "rarity" else "Reroll attributes", ("%d Shards" if kind == "rarity" else "%d Coins") % price if price >= 0 else "Unavailable"]
	button.disabled = targeting_button.disabled or price < 0 or balance < price or _pending_rarity_id >= 0 or not _queued_rarity_tower.is_empty() or _rarity_reel.is_busy()
	button.tooltip_text = reroll_tooltip(kind)
	if balance < price:
		button.tooltip_text += "\nNeed %d more %s." % [price - balance, "Shards" if kind == "rarity" else "Coins"]
	if targeting_button.disabled:
		button.tooltip_text += "\nReady commits planning actions until combat starts; finished runs cannot reroll."


static func reroll_tooltip(kind: String) -> String:
	if kind == "rarity":
		return "Roll a different rarity using the placement odds, then replace every attribute. Downgrades are possible. Resets only the attribute-reroll price counter; purchased upgrades and evolutions remain."
	return "Keep the current rarity and replace every attribute and value. Purchased upgrades and evolutions remain."


static func tower_display_title(tower: Dictionary, stats: Dictionary) -> String:
	var evolutions: Dictionary = stats.get("evolutions", {})
	var branch: Dictionary = evolutions.get(String(tower.get("evolution", "")), {})
	var followups: Dictionary = branch.get("followups", {})
	var followup: Dictionary = followups.get(String(tower.get("followup", "")), {})
	var advancement: Dictionary = stats.get("advancements", {}).get(tower.get("advancement", ""), {})
	var title: String = String(advancement.get("title", followup.get("title", branch.get("title", stats.get("title", "Tower")))))
	var steps: Array = branch.get("upgrades", [])
	var purchased_steps: int = tower.get("branch_upgrades", []).size()
	if purchased_steps > 0 and purchased_steps <= steps.size():
		title = String(steps[purchased_steps - 1]["title"])
	var capstone_steps: Array = branch.get("capstones", {}).get(String(tower.get("capstone", "")), [])
	if purchased_steps > steps.size() and purchased_steps - steps.size() <= capstone_steps.size():
		title = String(capstone_steps[purchased_steps - steps.size() - 1]["title"])
	var level: int = MatchCombat.tower_level(tower)
	var rarity: String = String(tower.get("rarity", ""))
	return "%s%s · %s" % [rarity.capitalize() + " " if not rarity.is_empty() else "", title, roman_numeral(level)]


static func roman_numeral(value: int) -> String:
	var result: String = ""
	var remaining: int = maxi(1, value)
	for pair: Array in ROMAN_NUMERALS:
		while remaining >= int(pair[0]):
			result += String(pair[1])
			remaining -= int(pair[0])
	return result


static func tower_rarity_color(tower: Dictionary) -> Color:
	match String(tower.get("rarity", "")):
		"broken": return Color("c69886")
		"shoddy": return Color("bdba91")
		"common": return Color("e4e7de")
		"uncommon": return Color("9bd38d")
		"rare": return Color("81b8ed")
		"epic": return Color("c6a0e8")
		"legendary": return Color("f1c76e")
		"mythic": return Color("f28eab")
		_: return Color("e0bc77")


static func roll_details_text(tower: Dictionary) -> String:
	var lines := PackedStringArray()
	for attribute: Dictionary in tower.get("attributes", []):
		var effect: String = String(attribute.get("effect", ""))
		var value: float = float(attribute.get("value", 0.0))
		var amount: String = "%+d" % int(value) if effect in ["pierce", "bounce", "chain_jumps"] else "%+.1f%%" % (value * 100.0)
		var title: String = effect.replace("_", " ").capitalize()
		match effect:
			"support_buff":
				title = "Support strength"
			"economy_production":
				title = "Income"
			"chain_jumps":
				title = "Chain hits"
		lines.append("%s %s" % [amount, title])
	if lines.is_empty():
		lines.append("No attributes")
	return "\n".join(lines)


static func tower_stats_text(tower: Dictionary, stats: Dictionary) -> String:
	var kind: String = String(tower.get("behavior_kind", stats.get("behavior_kind", "attack")))
	var lines := PackedStringArray()
	lines.append("Kills %d" % int(tower.get("kills", 0)))
	if kind in ["attack", "chain", "catapult"] or int(tower.get("damage_dealt", 0)) > 0:
		lines.append("Damage dealt %d" % int(tower.get("damage_dealt", 0)))
	if kind in ["economy", "bounty", "income_aura"] or int(tower.get("coins_generated", 0)) > 0:
		lines.append("Coins generated %d" % int(tower.get("coins_generated", 0)))
	if kind == "catapult":
		lines.append("Enemies thrown %d" % int(tower.get("thrown", 0)))
	if kind == "crystal" or int(tower.get("shards_generated", 0)) > 0:
		lines.append("Shards generated %d" % int(tower.get("shards_generated", 0)))
	if kind == "bounty" or int(tower.get("indirect_damage", 0)) > 0:
		lines.append("Indirect damage %d" % int(tower.get("indirect_damage", 0)))
	lines.append(behavior_summary(tower, stats))
	var damage_buff: float = float(tower.get("support_damage_bonus", 0.0))
	var speed_buff: float = float(tower.get("support_speed_bonus", 0.0))
	if damage_buff > 0.0 or speed_buff > 0.0:
		lines.append("Buff: +%.0f%% damage / +%.0f%% speed" % [damage_buff * 100.0, speed_buff * 100.0])
	if float(tower.get("support_range_bonus", 0.0)) > 0.0:
		lines.append("Buff: +%s range" % String.num(float(tower["support_range_bonus"]), 2))
	if float(tower.get("crit_chance", 0.0)) > 0.0:
		lines.append("Crit chance %s%% · %d crits" % [String.num(float(tower["crit_chance"]) * 100.0, 1), int(tower.get("crits", 0))])
	return "\n".join(lines)


static func behavior_summary(state: Dictionary, fallback: Dictionary = {}) -> String:
	var kind: String = String(state.get("behavior_kind", fallback.get("behavior_kind", "attack")))
	var config: Dictionary = state.get("behavior_config", fallback.get("behavior_config", {}))
	var range_cells: float = float(state.get("range", fallback.get("range", 0.0)))
	var result: String
	match kind:
		"support":
			var auras := PackedStringArray()
			if float(config.get("damage_bonus", 0.0)) > 0.0:
				auras.append("+%s%% damage" % String.num(float(config["damage_bonus"]) * 100.0, 1))
			if float(config.get("attack_speed_bonus", 0.0)) > 0.0:
				auras.append("+%s%% attack speed" % String.num(float(config["attack_speed_bonus"]) * 100.0, 1))
			if float(config.get("range_aura", 0.0)) > 0.0:
				auras.append("+%s range" % String.num(float(config["range_aura"]), 2))
			if float(config.get("crit_chance", 0.0)) > 0.0:
				auras.append("%s%% crit chance (×%s damage)" % [String.num(float(config["crit_chance"]) * 100.0, 1), String.num(TowerDefinition.CRIT_MULTIPLIER, 1)])
			result = "Nearby towers:\n%s\nStrongest duplicate only" % " · ".join(auras)
		"economy":
			result = "%s Coins / round clear" % String.num(float(config.get("clear_income", 0.0)), 1)
			if float(config.get("periodic_income", 0.0)) > 0.0:
				result += "\n%s Coins / %.2fs combat" % [String.num(float(config["periodic_income"]), 1), float(config.get("periodic_interval", 0.0))]
		"crystal":
			result = "%d Shards / round clear" % int(config.get("clear_shards", 0))
			if int(config.get("periodic_shards", 0)) > 0:
				result += "\n%d Shards / %.2fs combat" % [int(config["periodic_shards"]), float(config.get("periodic_interval", 0.0))]
			if float(state.get("output_multiplier", 1.0)) > 1.0:
				result += "\nShard output ×%s" % String.num(float(state["output_multiplier"]), 3)
			if int(state.get("base_max_health_per_round", 0)) > 0 or int(state.get("base_regen", 0)) > 0:
				result += "\n+%d base max HP & %d HP regen / round clear" % [int(state.get("base_max_health_per_round", 0)), int(state.get("base_regen", 0))]
				if int(state.get("base_max_health_per_round", 0)) > 0:
					result += "\nGrown +%d base max HP · cap %d" % [int(state.get("base_max_health_bonus", 0)), int(state.get("base_max_health_limit", 0))]
		"bounty":
			result = "Auto mark: highest max HP\n+%.1f%% damage taken\n+%.1f%% normal kill Coins\nOne persistent, exclusive target" % [float(config.get("mark_damage_bonus", 0.0)) * 100.0, float(config.get("mark_income_bonus", 0.0)) * 100.0]
		"catapult":
			var interval: float = float(state.get("interval", fallback.get("interval", 1.0)))
			result = "Throws %d enem%s every %.2fs\nLifts up to %s× Grunt HP · no bosses\nSlam %d damage · %s cells" % [int(config.get("throw_count", 1)), "y" if int(config.get("throw_count", 1)) == 1 else "ies", interval, String.num(float(config.get("lift", 0.0)), 2), int(state.get("damage", fallback.get("damage", 0))), String.num(float(config.get("slam_radius", 0.0)), 2)]
			if float(config.get("landing_progress", 0.0)) > 0.0 or float(config.get("landing_haste", 1.0)) > 1.0:
				result += "\nLands %s cells down their path · +%.0f%% speed" % [String.num(float(config.get("landing_progress", 0.0)), 1), (float(config.get("landing_haste", 1.0)) - 1.0) * 100.0]
		"income_aura":
			result = "Nearby killing towers:\n+%.1f%% kill Coins\nStrongest duplicate only" % (float(config.get("kill_income_bonus", 0.0)) * 100.0)
		_:
			var damage: int = int(state.get("damage", fallback.get("damage", 0)))
			var interval: float = float(state.get("interval", fallback.get("interval", 1.0)))
			if state.get("evolution", "") == "boulders":
				result = "%d DPS · Continuous" % damage
			else:
				result = "Damage %d · %.2f attacks/s\nEvery %.2fs" % [damage, 1.0 / interval, interval]
			if float(state.get("max_hp_drain", 0.0)) > 0.0:
				result += "\n+%s%% max HP / s drain, up to %s%% per enemy" % [String.num(float(state["max_hp_drain"]) * 100.0, 1), String.num(float(state.get("max_hp_drain_limit", 0.0)) * 100.0, 1)]
				result += "\n%d tendrils" % int(state.get("void_tendrils", 0))
			if kind == "chain":
				result += "\n%d chain hits · %.2f jump reach\n+%.0f%% damage / successive hit" % [int(config.get("hit_count", 1)), float(config.get("jump_distance", 0.0)), float(config.get("successive_hit_bonus", 0.0)) * 100.0]
	var advancement: Dictionary = fallback.get("advancements", {}).get(state.get("advancement", ""), {})
	if not advancement.is_empty():
		var weapon: String = String(advancement.get("weapon", "arrow"))
		var damage: float = float(state.get("damage", 0))
		var interval: float = maxf(float(state.get("interval", 1.0)), 0.001)
		if weapon == "flamethrower":
			result = "%s FIRE / s · 1 operator\n%ss fuel · %ss refuel" % [String.num(float(advancement.get("continuous_dps", 0.0)) * float(state.get("damage_multiplier", 1.0)) * float(state.get("speed_multiplier", 1.0)), 1), String.num(float(advancement.get("fuel_duration", 60.0)), 0), String.num(float(advancement.get("refuel_duration", 6.0)), 0)]
			if advancement.has("scorch_fraction"):
				result += "\nScorches orcs within %s cells for %s%%" % [String.num(float(advancement["scorch_radius"]), 2), String.num(float(advancement["scorch_fraction"]) * 100.0, 0)]
		elif weapon == "minigun":
			result = "3 crew · 1 arrow stream\n%s damage · %.2f arrows/s" % [String.num(damage, 0), 1.0 / interval]
		else:
			result = "%d %s · %.2f attacks/s each\n%s primary damage" % [independent_weapon_count(state, fallback), "rocket operator" if weapon == "rocket" else ("throwers" if weapon in ["grenade", "molotov"] else "archers"), 1.0 / interval, String.num(ceilf(damage * float(advancement.get("primary_multiplier", 1.0))), 0)]
		if advancement.has("splash_multiplier"):
			result += "\n%s splash · %s cells" % [String.num(ceilf(damage * float(advancement["splash_multiplier"])), 0), String.num(float(advancement.get("splash_radius", 0.0)), 2)]
		if advancement.has("burn_dps"):
			result += "\n%s burn/s · %ss" % [String.num(float(advancement["burn_dps"]) * float(state.get("damage_multiplier", 1.0)), 1), String.num(float(advancement.get("burn_duration", 0.0)), 1)]
	if not String(state.get("element", "")).is_empty():
		result += "\n%s element" % element_title(String(state["element"]))
	return result + "\nRange %.2f cells" % range_cells


static func element_title(element: String) -> String:
	return element.capitalize()


static func tower_upgrade_actions(tower: Dictionary, stats: Dictionary) -> Dictionary:
	var actions: Dictionary = {}
	var base_ready: bool = bool(tower.get("damage_upgraded", false)) and bool(tower.get("speed_upgraded", false))
	var effects: Dictionary = stats.get("upgrade_effects", {})
	for command: String in ["damage", "speed"]:
		var benefit: String
		if effects.has(command):
			benefit = effect_description(effects[command])
		else:
			benefit = ("+%d slam damage" if stats.get("behavior_kind", "") == "catapult" else "+%d damage") % int(stats.get("damage_upgrade_bonus", 0)) if command == "damage" else "%.0f%% faster" % ((1.0 / float(stats.get("speed_upgrade_multiplier", 1.0)) - 1.0) * 100.0)
		actions[command] = {"title": benefit, "cost": MatchCombat.tower_upgrade_cost(tower, stats), "purchased": bool(tower.get(command + "_upgraded", false)), "locked": false, "description": "One-time upgrade: " + benefit + ". Preserved through evolutions."}
	var special: String = String(stats.get("special_upgrade", ""))
	if not special.is_empty() and not (special == "second_archer" and bool(tower.get("special_upgraded", false))):
		var description: String = "Adds a second archer and 10% more attacks per second. Both use the tower's targeting policy, preferring distinct enemies and sharing when necessary." if special == "second_archer" else "Each successive chain hit gains +%.0f%% damage. Preserved through evolution." % (float(stats.get("special_upgrade_config", {}).get("successive_hit_bonus", 0.0)) * 100.0)
		if special == "double_scoop":
			description = "Grabs and throws %d more enem%s per swing. Preserved through evolution." % [int(stats.get("special_upgrade_config", {}).get("extra_throws", 1)), "y" if int(stats.get("special_upgrade_config", {}).get("extra_throws", 1)) == 1 else "ies"]
		actions["special"] = {"title": stats.get("special_upgrade_title", special.capitalize()), "cost": int(stats.get("special_upgrade_cost", 0)), "purchased": bool(tower.get("special_upgraded", false)), "locked": not base_ready, "description": description}
	var evolutions: Dictionary = stats.get("evolutions", {})
	var chosen: String = String(tower.get("evolution", ""))
	var chosen_definition: Dictionary = evolutions.get(chosen, {})
	var has_followups: bool = not chosen_definition.get("followup", {}).is_empty() or not chosen_definition.get("followups", {}).is_empty()
	for command: String in evolutions:
		# Once a branch is chosen, only its own continuation is offered; the
		# model still rejects every excluded sibling.
		if has_followups or (not chosen.is_empty() and chosen != command):
			continue
		var definition: Dictionary = evolutions[command]
		var locked: bool = not base_ready or (not chosen.is_empty() and chosen != command) or (special == "escalating_chain" and not bool(tower.get("special_upgraded", false)))
		actions[command] = {"title": definition.get("title", command.capitalize()), "cost": int(definition.get("cost", 0)), "purchased": chosen == command, "locked": locked, "description": upgrade_description(command, definition) + "\nPermanent evolution; rolled attributes and purchased bonuses remain."}
	if not chosen_definition.get("followup", {}).is_empty():
		var definition: Dictionary = chosen_definition["followup"]
		actions["freeze_runes"] = {"title": definition.get("title", "Freeze Runes"), "cost": int(definition.get("cost", 0)), "purchased": bool(tower.get("freeze_upgraded", false)), "locked": false, "description": upgrade_description("freeze_runes", definition)}
	# Ordered branch upgrades: purchased steps stay listed as purchased, and
	# only the next step in the chain is offered.
	var steps: Array = chosen_definition.get("upgrades", [])
	var purchased_steps: Array = tower.get("branch_upgrades", [])
	for index: int in range(mini(steps.size(), purchased_steps.size() + 1)):
		var step: Dictionary = steps[index]
		actions[step["id"]] = {"title": step["title"], "cost": int(step["cost"]), "purchased": index < purchased_steps.size(), "locked": false, "description": branch_upgrade_description(step) + ("\nNext: " + String(steps[index + 1]["title"]) if index + 1 < steps.size() else "")}
	# Once every ordered step is bought, choose one capstone path, then continue it.
	var capstones: Dictionary = chosen_definition.get("capstones", {})
	if not steps.is_empty() and purchased_steps.size() >= steps.size():
		var chosen_capstone: String = String(tower.get("capstone", ""))
		var bought: int = purchased_steps.size() - steps.size()
		for path: String in capstones:
			if not chosen_capstone.is_empty() and chosen_capstone != path:
				continue
			var path_steps: Array = capstones[path]
			for index: int in range(mini(path_steps.size(), (bought if path == chosen_capstone else 0) + 1)):
				var step: Dictionary = path_steps[index]
				var tail: String = "\nNext: " + String(path_steps[index + 1]["title"]) if index + 1 < path_steps.size() else ""
				if chosen_capstone.is_empty():
					tail += "\nChoose one permanent path."
				actions[step["id"]] = {"title": step["title"], "cost": int(step["cost"]), "purchased": path == chosen_capstone and index < bought, "locked": false, "description": branch_upgrade_description(step) + tail}
	var followups: Dictionary = chosen_definition.get("followups", {})
	var followup: String = String(tower.get("followup", ""))
	for command: String in followups:
		var definition: Dictionary = followups[command]
		actions[command] = {"title": definition.get("title", command.capitalize()), "cost": int(definition.get("cost", 0)), "purchased": followup == command, "locked": not followup.is_empty() and followup != command, "description": upgrade_description(command, definition) + "\nChoose one permanent specialization."}
	return actions


static func branch_upgrade_description(step: Dictionary) -> String:
	if step.has("description"):
		return String(step["description"])
	var parts := PackedStringArray()
	if step.has("magic_bounce"):
		var magic: Dictionary = step["magic_bounce"]
		if step.has("damage_type"):
			parts.append("Homing magic bolt. After its bounce it has a %.0f%% chance to bounce again to the nearest enemy, %.0f%% less likely each further bounce. With no new enemy left it loops back to earlier victims. Bounces deal 50%% damage." % [float(magic.get("chance", 0.0)) * 100.0, float(magic.get("decay", 0.0)) * 100.0])
		else:
			parts.append("Stronger redirects: %.0f%% chance to bounce again, only %.0f%% less likely each further bounce." % [float(magic.get("chance", 0.0)) * 100.0, float(magic.get("decay", 0.0)) * 100.0])
	if int(step.get("magic_split", 1)) > 1:
		parts.append("After its first hit the bolt splits into %d homing bolts that seek different enemies and bounce independently." % int(step["magic_split"]))
	if step.has("damage_type"):
		parts.append("Deals %s damage." % String(step["damage_type"]).to_upper())
	if step.has("damage_multiplier"):
		parts.append("+%.0f%% damage" % ((float(step["damage_multiplier"]) - 1.0) * 100.0))
	if int(step.get("pierce", 0)) > 0:
		parts.append("+%d pierce" % int(step["pierce"]))
	if float(step.get("bolt_scale", 0.0)) > 0.0:
		parts.append("bigger bolt")
	if float(step.get("bolt_reach", 0.0)) > 0.0:
		parts.append("flies %s cell%s further" % [String.num(float(step["bolt_reach"]), 1), "" if float(step["bolt_reach"]) == 1.0 else "s"])
	if step.has("attack_rate_multiplier"):
		var change: float = (float(step["attack_rate_multiplier"]) - 1.0) * 100.0
		parts.append("%s%s%% attack speed" % ["+" if change > 0.0 else "", String.num(change, 1)])
	return " · ".join(parts)


static func effect_description(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for effect: String in effects:
		var title: String = "Income" if effect == "income_bonus" else ("Damage buff" if effect == "damage_bonus" else "Speed buff")
		parts.append("+%.0f%% %s" % [float(effects[effect]) * 100.0, title])
	return " / ".join(parts)


static func upgrade_description(command: String, definition: Dictionary) -> String:
	if definition.has("description"):
		return String(definition["description"])
	if definition.get("behavior_kind", "") == "chain":
		var config: Dictionary = definition.get("behavior_config", {})
		return "Initial range %.2f cells; jumps reach %.2f cells. Keeps current damage, attack speed, purchased escalation, and all rolled modifiers." % [float(definition.get("range_cells", 0.0)), float(config.get("jump_distance", 0.0))]
	if definition.has("behavior_kind"):
		var state: Dictionary = definition.duplicate()
		state["range"] = float(definition.get("range_cells", 0.0))
		var description: String = behavior_summary(state)
		if not definition.has("range_cells"):
			description = description.get_slice("\nRange", 0)
		if command == "income_aura":
			description += "\nReplaces marking and immediately releases the current mark. Rewards follow the killing tower's location."
		return description
	match command:
		"pierce":
			return "A straight bolt hits the first two enemies along its forward ray at full damage. Rolled extra Pierce adds more hits."
		"bounce":
			return "A bolt redirects to the nearest other enemy for 50% damage, rounded up. Rolled extra Bounce adds more redirects."
		"freeze_runes":
			return "Boulders immediately slow ice-susceptible enemies by 20% while exposed. Higher maximum HP means faster thawing; ice-immune enemies ignore the slow."
		_:
			return "Deals %d %s to every enemy in the surrounding neighborhood%s." % [int(definition.get("damage", 0)), "damage per second" if bool(definition.get("continuous", false)) else "damage", "" if bool(definition.get("continuous", false)) else " every %.2fs" % float(definition.get("interval", 1.0))]



static func advancement_actions(tower: Dictionary, stats: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var advancements: Dictionary = stats.get("advancements", {})
	var chosen: String = String(tower.get("advancement", ""))
	var history: Array = tower.get("advancement_path", [])
	var ready: bool = bool(tower.get("special_upgraded", false))
	for command: String in advancements:
		var definition: Dictionary = advancements[command]
		var requires: String = String(definition.get("requires", ""))
		var purchased: bool = chosen == command or history.has(command)
		# Only unpurchased roots or immediate successors remain actionable.
		if purchased or (chosen.is_empty() and not requires.is_empty()) or (not chosen.is_empty() and requires != chosen):
			continue
		var title: String = String(definition.get("title", command.capitalize()))
		if command in ["aom_speed_1", "aom_speed_2"]:
			title = "Rapid Reload I" if command == "aom_speed_1" else "Rapid Reload II"
		result[command] = {
			"title": title,
			"cost": int(definition.get("cost", 0)), "purchased": purchased,
			"locked": not ready, "description": advancement_tooltip(command, definition),
		}
	return result


static func independent_weapon_count(tower: Dictionary, stats: Dictionary) -> int:
	var advancement: Dictionary = stats.get("advancements", {}).get(tower.get("advancement", ""), {})
	return int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) and stats.get("special_upgrade", "") == "second_archer" else 1))


static func advancement_tooltip(_command: String, definition: Dictionary) -> String:
	var parts := PackedStringArray()
	var weapon: String = String(definition.get("weapon", "arrow"))
	match weapon:
		"flamethrower":
			parts.append("Continuous FIRE damage; one operator. Fire for %ss uninterrupted, then refuel for %ss. Losing a target resets the firing streak; refueling cannot be canceled." % [String.num(float(definition.get("fuel_duration", 60.0)), 0), String.num(float(definition.get("refuel_duration", 6.0)), 0)])
		"minigun":
			parts.append("Three-archer crew; one rotary arrow stream with the output of twenty archers.")
		"rocket":
			parts.append("One rocket operator. Slow, heavy missiles with a huge blast.")
		"molotov":
			parts.append("Thrown incendiary bottles; impact, splash, and refreshing burn.")
		"grenade":
			parts.append("Thrown anti-orc grenades; heavy impact and a wide blast.")
		_:
			parts.append("%d archers share the tower's targeting policy, preferring distinct enemies and sharing when necessary." % int(definition.get("archer_count", 2)))
	if definition.has("primary_multiplier"):
		parts.append("Primary ×%s; splash ×%s within %s cells." % [String.num(float(definition["primary_multiplier"]), 2), String.num(float(definition.get("splash_multiplier", 0.0)), 2), String.num(float(definition.get("splash_radius", 0.0)), 2)])
	if definition.has("burn_dps"):
		parts.append("Burn %s/s for %ss; refreshes without stacking." % [String.num(float(definition["burn_dps"]), 1), String.num(float(definition.get("burn_duration", 0.0)), 1)])
	var rate: float = float(definition.get("attack_rate_multiplier", 1.0))
	if not is_equal_approx(rate, 1.0):
		parts.append("Attack rate +%s%%." % String.num((rate - 1.0) * 100.0, 0))
	return "\n".join(parts)

func _choice_upgrade_pressed(alternate: bool) -> void:
	_upgrade(_alternate_upgrade_command if alternate else _special_upgrade_command)


func _upgrade(upgrade: String) -> void:
	var button: Button = null
	if upgrade == "damage":
		button = damage_upgrade
	elif upgrade == "speed":
		button = speed_upgrade
	elif advancement_buttons.has(upgrade):
		button = advancement_buttons[upgrade]
	elif upgrade == _special_upgrade_command:
		button = special_upgrade
	elif upgrade == _alternate_upgrade_command:
		button = alternate_upgrade
	else:
		button = _extra_upgrade_buttons.get(upgrade)
	if planning != null and button != null and button.is_visible_in_tree() and not button.disabled and not _selected_tower().is_empty():
		planning.upgrade_tower(planning.local_slot(), selected_tower_id, upgrade)


func _sell() -> void:
	if planning != null and not sell_button.disabled and not _selected_tower().is_empty():
		planning.sell_tower(planning.local_slot(), selected_tower_id)


func _clear() -> void:
	if planning != null and not clear_button.disabled:
		planning.request_clear(planning.local_slot())


func _toggle_ready() -> void:
	if planning != null and int(planning.combat.get("phase",-1)) == MatchCombat.Phase.FINISHED:
		open_results()
		return
	if planning != null and not ready_button.disabled:
		planning.submit_ready(true)


func _refresh() -> void:
	if not is_node_ready():
		return
	debug_button.visible = planning != null and planning.can_debug()
	if not debug_button.visible:
		debug_popup.hide()
	if planning == null:
		_clear_reel_presentations()
		world.set_active(false)
		cancel_strokes()
		_clear_feedback()
		clear_button.disabled = true
		ready_button.disabled = true
		_ready_timer.hide()
		_refresh_pacing()
		_refresh_palette()
		_management.hide()
		selected_enemy_id = -1
		selected_enemy_slot = -1
		_enemy_inspector.hide()
		_status.text = "Planning unavailable"
		return
	var own_slot: int = planning.local_slot()
	if not planning.active or not is_visible_in_tree():
		_clear_reel_presentations()
	else:
		if _boss_rewards.observe(planning.combat, own_slot):
			_reset_rarity_presentation()
		_observe_rarity_reroll()
	for slot: int in range(boards.size()):
		boards[slot].layout = planning.layouts[slot]
	world.configure(planning.layouts[0].dimensions, own_slot, int(planning.combat.get("board_origin_y", 0)))
	if not planning.active:
		_clear_feedback()
		selected_tower_id = -1
		_placement_id = &""
		selected_enemy_id = -1
		selected_enemy_slot = -1
		_pending_tower_cell = Vector2i(-1, -1)
	var state: Dictionary = planning.combat
	var phase: int = int(state.get("phase", MatchCombat.Phase.PLANNING))
	var finished: bool = phase == MatchCombat.Phase.FINISHED
	var in_wave: bool = phase == MatchCombat.Phase.WAVE
	var editable: bool = planning.can_edit_path(own_slot)
	var all_towers: Array = state.get("towers", [[], []])
	var health: Array = state.get("health", [0, 0])
	var rules: Dictionary = state.get("rules", {})
	_refresh_health(int(health[own_slot]), int(state.get("max_health", [rules.get("base_health", 0), rules.get("base_health", 0)])[own_slot]))
	if _pending_tower_cell != Vector2i(-1, -1):
		for tower: Dictionary in all_towers[own_slot]:
			if tower["cell"] == _pending_tower_cell:
				if not _repeat_placement:
					selected_tower_id = int(tower["id"])
					_placement_id = &""
				_pending_tower_cell = Vector2i(-1, -1)
				break
	_refresh_palette()
	if selected_tower_id >= 0 and _selected_tower().is_empty():
		selected_tower_id = -1
	if finished or _selected_enemy().is_empty():
		selected_enemy_id = -1
		selected_enemy_slot = -1
	for slot: int in range(boards.size()):
		var layout: PathLayout = planning.layouts[slot]
		var board: PathBoard = boards[slot]
		board.tower_inspection_enabled = planning.active and finished and slot == own_slot
		board.cell_click_mode = _placement_id != &"" or not editable
		board.input_enabled = planning.active and not finished and slot == own_slot
		board.placement_enabled = slot == own_slot and planning.can_manage_towers(slot)
		board.enemy_inspection_enabled = planning.active and in_wave and _placement_id == &""
		board.selected_enemy_id = selected_enemy_id if slot == selected_enemy_slot else -1
		board.placement_id = _placement_id if slot == own_slot else &""
		board.selected_tower_id = selected_tower_id if slot == own_slot else -1
		board.apply_combat(state, slot, float(state.get("speed_multiplier", 1.0)))
		var role: String = "Local testing · mirrors your actions" if planning.singleplayer else ("Host" if slot == 0 else "Guest")
		_titles[slot].text = "You" if slot == own_slot else ("Mirror" if planning.singleplayer else "Opponent")
		_titles[slot].visible = slot != own_slot
		_titles[slot].tooltip_text = role
		var path_state: String = "Legal route." if layout.is_ready() else \
			("No route to base." if layout.route.is_empty() else "%d disconnected tiles." % layout.disconnected_count)
		_budgets[slot].text = "Ready" if phase == MatchCombat.Phase.PLANNING and slot != own_slot and planning.ready_flags[slot] else ""
		_budgets[slot].modulate = Color("b5e2b7")
		_counts[slot].visible = not finished and not in_wave and slot == own_slot
		_counts[slot].text = "%d/%d tiles%s" % [layout.used_tiles(), layout.budget, " · Main" if bool(state.get("main_round", false)) else ""]
		_counts[slot].tooltip_text = "%s\nPaths change only in setup and main rounds. WASD: pan · Scroll / pinch: zoom · Home: fit your board." % path_state
		_counts[slot].modulate = Color("b5e2b7") if layout.is_ready() else Color("e0bc77")
	clear_button.disabled = not editable or planning.layouts[own_slot].used_tiles() == 0
	ready_button.disabled = not finished and (not planning.active or phase != MatchCombat.Phase.PLANNING or planning.ready_flags[own_slot] or not planning.layouts[own_slot].is_ready())
	clear_button.visible = planning.active and bool(state.get("main_round", false))
	ready_button.visible = planning.active and (phase == MatchCombat.Phase.PLANNING or finished)
	ready_button.text = "Results" if finished else "Ready"
	var time_left: float = float(state.get("ready_seconds_left", -1.0))
	_ready_timer.visible = planning.active and phase == MatchCombat.Phase.PLANNING and time_left >= 0.0
	_ready_timer.text = "%ds" % ceili(time_left) if time_left >= 0.0 else ""
	var own_layout: PathLayout = planning.layouts[own_slot]
	if planning.ready_flags[own_slot]:
		ready_button.tooltip_text = "Committed until the round starts."
	elif not own_layout.is_ready():
		ready_button.tooltip_text = "Connect the entrance to the base and all placed path tiles before readying."
	elif bool(state.get("path_editing", false)):
		ready_button.tooltip_text = "Untimed strategy break. Both players must ready; Ready commits your planning actions."
	else:
		ready_button.tooltip_text = "First Ready starts the host's %ds window; both Ready starts immediately." % int(rules.get("ready_window_seconds", 20))
	if finished:
		var winning_slot: int = int(state.get("winner", -1))
		_status.text = "%s · Round %d" % ["Victory" if winning_slot == own_slot else "Defeat", int(state.get("wave", 0))]
		if bool(state.get("coin_flip", false)):
			_status.text += " · Coin flip"
			_status.tooltip_text = "Both bases fell in one tick; a coin flip decided the winner."
		else:
			_status.tooltip_text = ""
	elif in_wave:
		_status.text = "Round %d" % int(state.get("wave", 0))
		_status.tooltip_text = ""
	else:
		_status.text = "Round %d" % (int(state.get("wave", 0)) + 1)
		_status.tooltip_text = "Untimed strategy break: redesign your path, then both Ready." if bool(state.get("path_editing", false)) else "Paths stay locked until the next main round. Ready commits your planning actions."
	_refresh_targeting()
	_refresh_pacing()
	_refresh_enemy_inspector()
	if not planning.active:
		cancel_strokes()
	world.set_active(planning.active and is_visible_in_tree())
	sound_player.observe(state, own_slot, planning.active and is_visible_in_tree(), _owns_tree_pause)
	if not finished or not planning.active:
		_results_run_id = ""
		_close_results()
	elif is_visible_in_tree() and _results_run_id != String(state.get("statistics_id","")):
		_results_run_id = state.get("statistics_id","")
		open_results()
	_present_pending_reel()


func open_results() -> void:
	if planning == null or not planning.active or int(planning.combat.get("phase",-1)) != MatchCombat.Phase.FINISHED:
		return
	_close_pause_menu()
	debug_popup.hide()
	cancel_strokes()
	enemy_selector.get_popup().hide()
	selected_tower_id = -1
	_placement_id = &""
	_management.hide()
	world.set_input_blocked(true)
	$HUD.process_mode = Node.PROCESS_MODE_DISABLED
	results_menu.open_result(planning.combat,planning.local_slot(),planning.singleplayer)
	_rarity_reel.set_suspended(true)


func _close_results() -> void:
	if results_menu == null or not results_menu.visible:
		return
	results_menu.hide()
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT
	world.set_input_blocked(pause_menu.visible or debug_popup.visible or _rarity_reel.is_busy())


func _inspect_results() -> void:
	_close_results()
	menu_button.grab_focus()
	_present_pending_reel()


func _replay_results() -> void:
	if planning == null or not planning.singleplayer or int(planning.combat.get("phase",-1)) != MatchCombat.Phase.FINISHED:
		return
	_close_results()
	_clear_reel_presentations()
	world.set_active(false)
	planning.start_singleplayer()
	ready_button.grab_focus()


func handle_results_escape() -> void:
	if results_menu.visible:
		MenuAudio.activate(results_menu.inspect_button)
	else:
		if not cancel_interaction():
			MenuAudio.activate(menu_button)


func _show_feedback(message: String) -> void:
	_pending_rarity_id = -1
	if is_visible_in_tree():
		sound_player.reject()
	_pending_tower_cell = Vector2i(-1, -1)
	_feedback.text = message
	_feedback.show()
	_feedback_timer.start()
	_refresh_targeting()
	_refresh.call_deferred()


func _clear_feedback() -> void:
	_feedback_timer.stop()
	_feedback.text = ""
	_feedback.hide()
