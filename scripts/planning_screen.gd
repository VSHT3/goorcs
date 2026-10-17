class_name MatchPlanningScreen
extends Control

signal leave_requested


const TOWER_LEVEL_NUMERALS: Array[String] = ["I", "II", "III", "IV", "V"]

var planning: MatchPlanning
var selected_tower_id: int = -1
var selected_enemy_id: int = -1
var selected_enemy_slot: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)
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
var _extra_upgrades: VBoxContainer
var _extra_upgrade_buttons: Dictionary[String, Button] = {}
var _reroll_balance: Label

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
@onready var _income: Label = %Income
@onready var _cancel_placement: Button = %CancelPlacement
@onready var _management: PanelContainer = %TowerManagement
@onready var _enemy_inspector: EnemyInspector = %EnemyInspector
@onready var _tower_title: Label = %TowerTitle
@onready var damage_upgrade: Button = %DamageUpgrade
@onready var speed_upgrade: Button = %SpeedUpgrade
@onready var special_upgrade: Button = %SpecialUpgrade
@onready var alternate_upgrade: Button = %AlternateUpgrade
@onready var secondary_targeting: TargetingCycle = %SecondaryTargeting
@onready var _secondary_target_row: HBoxContainer = %SecondaryTargetRow
@onready var third_targeting: TargetingCycle = %ThirdTargeting
@onready var fourth_targeting: TargetingCycle = %FourthTargeting
@onready var _extra_target_row: VBoxContainer = %ExtraTargetRow
@onready var _advancement_row: HBoxContainer = %AdvancementRow
@onready var sell_button: Button = %SellTower
@onready var close_button: Button = %CloseTower
@onready var targeting_button: TargetingCycle = %Targeting
@onready var _tower_stats: Label = %TowerStats
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _titles: Array[Label] = [$HUD/Header/Content/Players/Host/Heading/Title, $HUD/Header/Content/Players/Guest/Heading/Title]
@onready var _states: Array[Label] = [$HUD/Header/Content/Players/Host/Heading/State, $HUD/Header/Content/Players/Guest/Heading/State]
@onready var _budgets: Array[Label] = [$HUD/Header/Content/Players/Host/Budget, $HUD/Header/Content/Players/Guest/Budget]
@onready var _counts: Array[Label] = [$HUD/Header/Content/Players/Host/Count, $HUD/Header/Content/Players/Guest/Count]


func _ready() -> void:
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
	secondary_targeting.mode_requested.connect(_secondary_target_selected)
	third_targeting.mode_requested.connect(_extra_target_selected.bind(2))
	fourth_targeting.mode_requested.connect(_extra_target_selected.bind(3))
	for command: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
		var button: Button = _advancement_row.get_node(NodePath(command)) as Button
		advancement_buttons[command] = button
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
	_management.add_child(scroll)
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
	_extra_upgrades = VBoxContainer.new()
	content.add_child(_extra_upgrades)
	content.move_child(_extra_upgrades, content.get_child_count() - 2)
	for button: Button in [special_upgrade, alternate_upgrade]:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reroll_balance = Label.new()
	_reroll_balance.name = "RerollCurrency"
	_reroll_balance.add_theme_font_override("font", _coins.get_theme_font("font"))
	_reroll_balance.add_theme_font_size_override("font_size", 16)
	_reroll_balance.tooltip_text = "Run-only rarity currency. Earned from round clears and enemy drops; spent on rarity rerolls."
	_income.get_parent().add_child(_reroll_balance)
	_income.get_parent().move_child(_reroll_balance, _income.get_index())


func _reroll(kind: String) -> void:
	var button: Button = rarity_reroll if kind == "rarity" else attribute_reroll
	if planning != null and button.is_visible_in_tree() and not button.disabled and not _selected_tower().is_empty():
		planning.reroll_tower(planning.local_slot(), selected_tower_id, kind)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_node_ready():
		for board: PathBoard in boards:
			board.clear_drag_preview()


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
	sound_player.set_combat_paused(planning.singleplayer)
	_owns_tree_pause = planning.singleplayer
	if _owns_tree_pause:
		get_tree().paused = true


func _resume_match() -> void:
	_close_pause_menu()
	if is_visible_in_tree():
		menu_button.grab_focus()


func _quit_match() -> void:
	_close_pause_menu()
	_close_results()
	leave_requested.emit()


func _close_pause_menu() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	pause_menu.close_menu()
	sound_player.set_combat_paused(false)
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT
	world.set_input_blocked(false)


func _exit_tree() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false


func _visibility_changed() -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
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
	debug_round.get_line_edit().grab_focus()
	debug_round.get_line_edit().select_all()


func _apply_debug() -> void:
	debug_round.apply()
	debug_money.apply()
	debug_shards.apply()
	if planning != null and planning.debug_set_values(int(debug_round.value), int(debug_money.value), int(debug_shards.value)):
		debug_popup.hide()


func _debug_closed() -> void:
	world.set_input_blocked(pause_menu.visible)


func _debug_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		debug_popup.hide()
		debug_popup.set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or pause_menu.visible or debug_popup.visible or (_placement_id == &"" and selected_enemy_id < 0):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()


func cancel_interaction() -> bool:
	if _placement_id == &"" and selected_tower_id < 0 and selected_enemy_id < 0:
		return false
	cancel_strokes()
	_placement_id = &""
	selected_tower_id = -1
	selected_enemy_id = -1
	selected_enemy_slot = -1
	_pending_tower_cell = Vector2i(-1, -1)
	_refresh()
	return true


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
	if int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED:
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
	planning.build_tower(slot, cell, type_id, _default_targeting)
	_refresh()


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
		button.drag_started.connect(cancel_strokes.unbind(1))
		_palette.add_child(button)
		shop_buttons[reward.id] = button


func _refresh_palette() -> void:
	var types: Dictionary = planning.combat.get("tower_types", {}) if planning != null else {}
	var coins: int = _own_coins()
	var available: bool = planning != null and planning.can_manage_towers(planning.local_slot())
	for id: StringName in shop_buttons:
		var button: TowerShopButton = shop_buttons[id]
		var stats: Dictionary = types.get(String(id), {})
		var unlocked: bool = planning != null and planning.collection_store != null and planning.collection_store.is_unlocked(id)
		var equipped: bool = planning != null and planning.is_equipped(id)
		button.visible = equipped
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
	_coins.text = "Coins %d" % coins
	var currency: Array = planning.combat.get("reroll_currency", [0, 0]) if planning != null else [0, 0]
	_reroll_balance.text = "Shards %d" % int(currency[planning.local_slot() if planning != null else 0])
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
	send_button.disabled = not available or _own_coins() < cost
	send_button.text = "Send · %d/+%d" % [cost, gain] if configured else "Send unavailable"
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
	elif _own_coins() < cost:
		delivery += "\nNeed %d more Coins." % (cost - _own_coins())
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
	return "%s: %d Coins; +%d recurring Coins per both-board clear." % [String(stats.get("title", _selected_enemy_type)), int(stats.get("send_cost", 0)), int(stats.get("send_income", 0))]


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


func _secondary_target_selected(mode: int) -> void:
	if planning != null and secondary_targeting.is_visible_in_tree() and not secondary_targeting.disabled and not _selected_tower().is_empty():
		planning.set_secondary_targeting(planning.local_slot(), selected_tower_id, mode)
	_refresh_targeting()


func _extra_target_selected(mode: int, archer_index: int) -> void:
	var selector: TargetingCycle = third_targeting if archer_index == 2 else fourth_targeting
	if planning != null and selector.is_visible_in_tree() and not selector.disabled and not _selected_tower().is_empty():
		planning.set_archer_targeting(planning.local_slot(), selected_tower_id, archer_index, mode)
	_refresh_targeting()


func _request_pacing(option: String) -> void:
	if planning == null or not planning.active:
		return
	if option == "speed" and planning.singleplayer:
		planning.cycle_singleplayer_speed()
		return
	var votes: Array = planning.combat.get(option + "_votes", [false, false])
	planning.request_pacing(option, not bool(votes[planning.local_slot()]))


func _refresh_pacing() -> void:
	var state: Dictionary = planning.combat if planning != null else {}
	var available: bool = planning != null and planning.active and int(state.get("phase", MatchCombat.Phase.PLANNING)) != MatchCombat.Phase.FINISHED
	var slot: int = planning.local_slot() if planning != null else 0
	for option: String in ["speed", "autoplay"]:
		var button: Button = speed_button if option == "speed" else autoplay_button
		var votes: Array = state.get(option + "_votes", [false, false])
		var enabled: bool = bool(votes[slot])
		var agreed: bool = float(state.get("speed_multiplier", 1.0)) > 1.0 if option == "speed" else bool(state.get("autoplay", false))
		button.disabled = not available
		button.set_pressed_no_signal(enabled)
		var color := Color("b5e2b7") if agreed else Color("e0bc77")
		for theme_color: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(theme_color, color)
		if option == "speed":
			var multiplier: int = int(state.get("speed_multiplier",1.0))
			button.icon = preload("res://assets/ui/speed_triple.svg") if multiplier == 3 else (preload("res://assets/ui/speed_double.svg") if enabled else preload("res://assets/ui/speed_normal.svg"))
		button.tooltip_text = ("%d× speed · click to cycle 1× / 2× / 3×" % int(state.get("speed_multiplier",1.0)) if planning != null and planning.singleplayer else "2× speed") if option == "speed" else "Autoplay"
		if agreed:
			button.tooltip_text += " · On"
		elif enabled:
			button.tooltip_text += " · Waiting for opponent"
		elif bool(votes[1 - slot]):
			button.tooltip_text += " · Opponent enabled"
		if option == "autoplay" and agreed and not planning.locked and (not planning.layouts[0].is_ready() or not planning.layouts[1].is_ready()):
			button.tooltip_text += "\nWaiting for legal paths"
		if option == "autoplay" and agreed and bool(state.get("path_editing", false)):
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
	_tower_stats.text = tower_stats_text(tower, stats)
	_roll_details.text = roll_details_text(tower)
	targeting_button.get_parent_control().visible = tower.get("behavior_kind", stats.get("behavior_kind", "attack")) in ["attack", "chain"]
	targeting_button.mode = int(tower["mode"])
	targeting_button.disabled = not planning.can_manage_towers(planning.local_slot())
	var currency: Array = planning.combat.get("reroll_currency", [0, 0])
	_refresh_reroll(rarity_reroll, tower, "rarity", int(currency[planning.local_slot()]))
	_refresh_reroll(attribute_reroll, tower, "attributes", _own_coins())
	var actions: Dictionary = tower_upgrade_actions(tower, stats)
	var base_ready: bool = bool(tower.get("damage_upgraded", false)) and bool(tower.get("speed_upgraded", false))
	damage_upgrade.visible = not base_ready or actions.size() == 2
	speed_upgrade.visible = damage_upgrade.visible
	for command: String in ["damage", "speed"]:
		_refresh_action(damage_upgrade if command == "damage" else speed_upgrade, actions[command])
	var choices: Array[String] = []
	for command: String in actions:
		if base_ready and command not in ["damage", "speed"]:
			choices.append(command)
	_special_upgrade_command = choices[0] if not choices.is_empty() else ""
	_alternate_upgrade_command = choices[1] if choices.size() > 1 else ""
	special_upgrade.visible = not _special_upgrade_command.is_empty()
	alternate_upgrade.visible = not _alternate_upgrade_command.is_empty()
	special_upgrade.custom_minimum_size.x = 140.0 if alternate_upgrade.visible else 288.0
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
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_override("font", _coins.get_theme_font("font"))
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(_upgrade.bind(command))
			_extra_upgrades.add_child(button)
			_extra_upgrade_buttons[command] = button
		_extra_upgrade_buttons[command].show()
		_refresh_action(_extra_upgrade_buttons[command], actions[command])
	var second_archer: bool = bool(tower.get("special_upgraded", false)) and String(stats.get("special_upgrade", "")) == "second_archer"
	_secondary_target_row.visible = second_archer
	secondary_targeting.disabled = targeting_button.disabled or not second_archer
	secondary_targeting.mode = int(tower.get("secondary_mode", tower["mode"]))
	var advancements: Dictionary = stats.get("advancements", {})
	_advancement_row.visible = second_archer and not advancements.is_empty()
	if _advancement_row.visible:
		special_upgrade.hide()
		special_upgrade.disabled = true
		_special_upgrade_command = ""
	for command: String in advancement_buttons:
		var button: Button = advancement_buttons[command]
		var definition: Dictionary = advancements.get(command, {})
		var chosen: String = String(tower.get("advancement", ""))
		var purchased: bool = chosen == command
		var locked: bool = not chosen.is_empty() and not purchased
		var price: int = int(definition.get("cost", 0))
		button.text = "%s\n%s" % [String(definition.get("title", command)), "Purchased" if purchased else ("Locked" if locked else str(price))]
		button.disabled = not _advancement_row.visible or definition.is_empty() or purchased or locked or targeting_button.disabled or _own_coins() < price
		button.tooltip_text = advancement_tooltip(command, definition)
		if locked:
			button.tooltip_text += "\nLocked: another advancement was purchased."
		elif not purchased and _own_coins() < price:
			button.tooltip_text += "\nNeed %d more Coins." % (price - _own_coins())
		if targeting_button.disabled:
			button.tooltip_text += "\nUnavailable while Ready or after the run ends."
	var extra_archers: Array = tower.get("extra_archers", [])
	var four_archers: bool = tower.get("advancement", "") == "four_archers" and extra_archers.size() == 2
	_extra_target_row.visible = four_archers
	for index: int in range(2):
		var selector: TargetingCycle = third_targeting if index == 0 else fourth_targeting
		selector.disabled = targeting_button.disabled or not four_archers
		if four_archers:
			selector.mode = int(extra_archers[index]["mode"])
	sell_button.text = "Sell · +%d" % int(tower.get("sell_value", 0))
	sell_button.tooltip_text = "60%% of %d invested Coins, including upgrades." % int(tower.get("invested", 0))
	sell_button.disabled = targeting_button.disabled


func _refresh_action(button: Button, action: Dictionary) -> void:
	var purchased: bool = bool(action["purchased"])
	var locked: bool = bool(action["locked"])
	var price: int = int(action["cost"])
	button.text = "%s\n%s" % [action["title"], "Owned" if purchased else ("Locked" if locked else str(price))]
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
	button.disabled = targeting_button.disabled or price < 0 or balance < price
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
	var title: String = String(followup.get("title", branch.get("title", stats.get("title", "Tower"))))
	var level: int = MatchCombat.tower_level(tower)
	return "%s · %s" % [title, TOWER_LEVEL_NUMERALS[level - 1] if level <= TOWER_LEVEL_NUMERALS.size() else str(level)]


static func roll_details_text(tower: Dictionary) -> String:
	var rarity: String = String(tower.get("rarity", ""))
	var lines := PackedStringArray()
	if not rarity.is_empty():
		lines.append(rarity.capitalize())
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
	if lines.size() == 1:
		lines.append("No attributes")
	return "\n".join(lines)


static func tower_stats_text(tower: Dictionary, stats: Dictionary) -> String:
	var result: String = behavior_summary(tower, stats)
	if tower.get("behavior_kind", stats.get("behavior_kind", "attack")) in ["attack", "chain"]:
		result = "Kills %d\n%s" % [int(tower.get("kills", 0)), result]
		var damage_buff: float = float(tower.get("support_damage_bonus", 0.0))
		var speed_buff: float = float(tower.get("support_speed_bonus", 0.0))
		if damage_buff > 0.0 or speed_buff > 0.0:
			result += "\nSupport: +%.0f%% damage / +%.0f%% speed" % [damage_buff * 100.0, speed_buff * 100.0]
	return result


static func behavior_summary(state: Dictionary, fallback: Dictionary = {}) -> String:
	var kind: String = String(state.get("behavior_kind", fallback.get("behavior_kind", "attack")))
	var config: Dictionary = state.get("behavior_config", fallback.get("behavior_config", {}))
	var range_cells: float = float(state.get("range", fallback.get("range", 0.0)))
	var result: String
	match kind:
		"support":
			result = "Nearby towers:\n+%.1f%% damage · +%.1f%% attack speed\nStrongest duplicate only" % [float(config.get("damage_bonus", 0.0)) * 100.0, float(config.get("attack_speed_bonus", 0.0)) * 100.0]
		"economy":
			result = "%s Coins / round clear" % String.num(float(config.get("clear_income", 0.0)), 1)
			if float(config.get("periodic_income", 0.0)) > 0.0:
				result += "\n%s Coins / %.2fs combat" % [String.num(float(config["periodic_income"]), 1), float(config.get("periodic_interval", 0.0))]
		"bounty":
			result = "Auto mark: highest max HP\n+%.1f%% damage taken\n+%.1f%% normal kill Coins\nOne persistent, exclusive target" % [float(config.get("mark_damage_bonus", 0.0)) * 100.0, float(config.get("mark_income_bonus", 0.0)) * 100.0]
		"income_aura":
			result = "Nearby killing towers:\n+%.1f%% kill Coins\nStrongest duplicate only" % (float(config.get("kill_income_bonus", 0.0)) * 100.0)
		_:
			var damage: int = int(state.get("damage", fallback.get("damage", 0)))
			var interval: float = float(state.get("interval", fallback.get("interval", 1.0)))
			if state.get("evolution", "") == "boulders":
				result = "%d DPS · Continuous" % damage
			else:
				result = "Damage %d · %.2f attacks/s\nEvery %.2fs" % [damage, 1.0 / interval, interval]
			if kind == "chain":
				result += "\n%d chain hits · %.2f jump reach\n+%.0f%% damage / successive hit" % [int(config.get("hit_count", 1)), float(config.get("jump_distance", 0.0)), float(config.get("successive_hit_bonus", 0.0)) * 100.0]
	return result + "\nRange %.2f cells" % range_cells


static func tower_upgrade_actions(tower: Dictionary, stats: Dictionary) -> Dictionary:
	var actions: Dictionary = {}
	var base_ready: bool = bool(tower.get("damage_upgraded", false)) and bool(tower.get("speed_upgraded", false))
	var effects: Dictionary = stats.get("upgrade_effects", {})
	for command: String in ["damage", "speed"]:
		var benefit: String
		if effects.has(command):
			benefit = effect_description(effects[command])
		else:
			benefit = "+%d damage" % int(stats.get("damage_upgrade_bonus", 0)) if command == "damage" else "%.0f%% faster" % ((1.0 / float(stats.get("speed_upgrade_multiplier", 1.0)) - 1.0) * 100.0)
		actions[command] = {"title": benefit, "cost": MatchCombat.tower_upgrade_cost(tower, stats), "purchased": bool(tower.get(command + "_upgraded", false)), "locked": false, "description": "One-time upgrade: " + benefit + ". Preserved through evolutions."}
	var special: String = String(stats.get("special_upgrade", ""))
	if not special.is_empty() and not (special == "second_archer" and bool(tower.get("special_upgraded", false))):
		var description: String = "Adds a second archer with independent targeting and 10% more attacks per second. Prefers distinct enemies, sharing when necessary." if special == "second_archer" else "Each successive chain hit gains +%.0f%% damage. Preserved through evolution." % (float(stats.get("special_upgrade_config", {}).get("successive_hit_bonus", 0.0)) * 100.0)
		actions["special"] = {"title": stats.get("special_upgrade_title", special.capitalize()), "cost": int(stats.get("special_upgrade_cost", 0)), "purchased": bool(tower.get("special_upgraded", false)), "locked": not base_ready, "description": description}
	var evolutions: Dictionary = stats.get("evolutions", {})
	var chosen: String = String(tower.get("evolution", ""))
	var chosen_definition: Dictionary = evolutions.get(chosen, {})
	var has_followups: bool = not chosen_definition.get("followup", {}).is_empty() or not chosen_definition.get("followups", {}).is_empty()
	for command: String in evolutions:
		if has_followups:
			continue
		var definition: Dictionary = evolutions[command]
		var locked: bool = not base_ready or (not chosen.is_empty() and chosen != command) or (special == "escalating_chain" and not bool(tower.get("special_upgraded", false)))
		actions[command] = {"title": definition.get("title", command.capitalize()), "cost": int(definition.get("cost", 0)), "purchased": chosen == command, "locked": locked, "description": upgrade_description(command, definition) + "\nPermanent evolution; rolled attributes and purchased bonuses remain."}
	if not chosen_definition.get("followup", {}).is_empty():
		var definition: Dictionary = chosen_definition["followup"]
		actions["freeze_runes"] = {"title": definition.get("title", "Freeze Runes"), "cost": int(definition.get("cost", 0)), "purchased": bool(tower.get("freeze_upgraded", false)), "locked": false, "description": upgrade_description("freeze_runes", definition)}
	var followups: Dictionary = chosen_definition.get("followups", {})
	var followup: String = String(tower.get("followup", ""))
	for command: String in followups:
		var definition: Dictionary = followups[command]
		actions[command] = {"title": definition.get("title", command.capitalize()), "cost": int(definition.get("cost", 0)), "purchased": followup == command, "locked": not followup.is_empty() and followup != command, "description": upgrade_description(command, definition) + "\nChoose one permanent specialization."}
	return actions


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
			return "Boulders also slow eligible enemies, following the authored freeze duration and strength. Ice-immune enemies ignore the slow."
		_:
			return "Deals %d %s to every enemy in the surrounding neighborhood%s." % [int(definition.get("damage", 0)), "damage per second" if bool(definition.get("continuous", false)) else "damage", "" if bool(definition.get("continuous", false)) else " every %.2fs" % float(definition.get("interval", 1.0))]



static func advancement_tooltip(command: String, definition: Dictionary) -> String:
	var details: String = ""
	match command:
		"four_archers":
			details = "%d archers with independent targeting; prefer distinct enemies, then share targets if needed. Attack rate ×%s." % [int(definition.get("archer_count", 0)), String.num(float(definition.get("attack_rate_multiplier", 1.0)), 2)]
		"fire_arrows":
			details = "Physical arrows ignite enemies for %s damage/s over %ss. Burn refreshes without stacking." % [String.num(float(definition.get("burn_dps", 0.0)), 2), String.num(float(definition.get("burn_duration", 0.0)), 2)]
		"bomb_arrows":
			details = "Primary damage ×%s; other enemies within %s cells take ×%s damage, rounded up." % [String.num(float(definition.get("primary_multiplier", 0.0)), 2), String.num(float(definition.get("splash_radius", 0.0)), 2), String.num(float(definition.get("splash_multiplier", 0.0)), 2)]
	return details + "\nRequires Second Archer. Choose one advancement."

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
	var all_enemies: Array = state.get("enemies", [[], []])
	var health: Array = state.get("health", [10, 10])
	var spawned: Array = state.get("spawned", [0, 0])
	var rules: Dictionary = state.get("rules", {})
	if _pending_tower_cell != Vector2i(-1, -1):
		for tower: Dictionary in all_towers[own_slot]:
			if tower["cell"] == _pending_tower_cell:
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
		board.cell_click_mode = _placement_id != &"" or not editable
		board.input_enabled = planning.active and not finished and slot == own_slot
		board.placement_enabled = slot == own_slot and planning.can_manage_towers(slot)
		board.enemy_inspection_enabled = planning.active and in_wave and _placement_id == &""
		board.selected_enemy_id = selected_enemy_id if slot == selected_enemy_slot else -1
		board.placement_id = _placement_id if slot == own_slot else &""
		board.selected_tower_id = selected_tower_id if slot == own_slot else -1
		board.tower_types = state.get("tower_types", {})
		board.combat_towers = all_towers[slot]
		board.combat_enemies = all_enemies[slot]
		board.apply_deaths(state, slot, float(state.get("speed_multiplier", 1.0)))
		board.queue_redraw()
		var role: String = "Local testing · mirrors your actions" if planning.singleplayer else ("Host" if slot == 0 else "Guest")
		_titles[slot].text = "You" if slot == own_slot else ("Mirror" if planning.singleplayer else "Opponent")
		_titles[slot].tooltip_text = role
		var path_state: String = "Legal route." if layout.is_ready() else \
			("No route to base." if layout.route.is_empty() else "%d disconnected tiles." % layout.disconnected_count)
		_states[slot].tooltip_text = "Base health. %s\n%s" % [role, path_state]
		_states[slot].modulate = Color("d99578") if int(health[slot]) <= 0 else Color("b5e2b7")
		_states[slot].text = "HP %d/%d" % [int(health[slot]), int(rules.get("base_health", 10))]
		_budgets[slot].text = "Ready" if phase == MatchCombat.Phase.PLANNING and slot != own_slot and planning.ready_flags[slot] else ""
		_budgets[slot].modulate = Color("b5e2b7")
		_counts[slot].visible = not finished and (in_wave or slot == own_slot)
		if in_wave:
			_counts[slot].text = "Alive %d" % all_enemies[slot].size()
			_counts[slot].tooltip_text = "Regular enemies spawned: %d/%d.\nWASD: pan · Scroll / pinch: zoom." % [int(spawned[slot]), int(state.get("total", 0))]
			_counts[slot].modulate = Color("b5e2b7")
		else:
			_counts[slot].text = "%d/%d tiles%s" % [layout.used_tiles(), layout.budget, " · Main" if bool(state.get("main_round", false)) else ""]
			_counts[slot].tooltip_text = "%s\nPaths change only in setup and main rounds. WASD: pan · Scroll / pinch: zoom." % path_state
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


func _close_results() -> void:
	if results_menu == null or not results_menu.visible:
		return
	results_menu.hide()
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT
	world.set_input_blocked(false)


func _inspect_results() -> void:
	_close_results()
	menu_button.grab_focus()


func _replay_results() -> void:
	if planning == null or not planning.singleplayer or int(planning.combat.get("phase",-1)) != MatchCombat.Phase.FINISHED:
		return
	_close_results()
	world.set_active(false)
	planning.start_singleplayer()
	ready_button.grab_focus()


func handle_results_escape() -> void:
	if results_menu.visible:
		MenuAudio.activate(results_menu.inspect_button)
	else:
		MenuAudio.activate(menu_button)


func _show_feedback(message: String) -> void:
	if is_visible_in_tree():
		sound_player.reject()
	_pending_tower_cell = Vector2i(-1, -1)
	_feedback.text = message
	_feedback.show()
	_feedback_timer.start()


func _clear_feedback() -> void:
	_feedback_timer.stop()
	_feedback.text = ""
	_feedback.hide()
