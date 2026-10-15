class_name MatchPlanningScreen
extends Control

signal leave_requested


const TARGET_HELP: Array[String] = [
	"Furthest along the route.",
	"Nearest to this tower.",
	"Highest current HP.",
]
const TOWER_LEVEL_NUMERALS: Array[String] = ["I", "II", "III", "IV"]

var planning: MatchPlanning
var selected_tower_id: int = -1
var selected_enemy_id: int = -1
var selected_enemy_slot: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)
var _placement_id: StringName = &""
var _selected_enemy_type: StringName = &"grunt"
var shop_buttons: Dictionary[StringName, TowerShopButton] = {}
var _owns_tree_pause: bool = false

@onready var world: MatchWorld = $World
@onready var boards: Array[PathBoard] = world.boards
@onready var menu_button: Button = %MenuButton
@onready var pause_menu: MatchPauseMenu = $PauseMenu
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
@onready var secondary_targeting: OptionButton = %SecondaryTargeting
@onready var _secondary_target_row: HBoxContainer = %SecondaryTargetRow
@onready var sell_button: Button = %SellTower
@onready var close_button: Button = %CloseTower
@onready var targeting_button: OptionButton = %Targeting
@onready var _tower_stats: Label = %TowerStats
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _titles: Array[Label] = [$HUD/Header/Content/Players/Host/Heading/Title, $HUD/Header/Content/Players/Guest/Heading/Title]
@onready var _states: Array[Label] = [$HUD/Header/Content/Players/Host/Heading/State, $HUD/Header/Content/Players/Guest/Heading/State]
@onready var _budgets: Array[Label] = [$HUD/Header/Content/Players/Host/Budget, $HUD/Header/Content/Players/Guest/Budget]
@onready var _counts: Array[Label] = [$HUD/Header/Content/Players/Host/Count, $HUD/Header/Content/Players/Guest/Count]


func _ready() -> void:
	for slot: int in range(boards.size()):
		boards[slot].edit_requested.connect(_request_edit.bind(slot))
		boards[slot].cell_clicked.connect(_cell_clicked.bind(slot))
		boards[slot].tower_dropped.connect(_tower_dropped.bind(slot))
		boards[slot].enemy_clicked.connect(_enemy_clicked.bind(slot))
		boards[slot].command_mode = true
		if planning != null and planning.collection_store != null:
			boards[slot].tower_catalog = planning.collection_store.catalog
	for selector: OptionButton in [targeting_button, secondary_targeting]:
		selector.add_item("Furthest", 0)
		selector.add_item("Closest", 1)
		selector.add_item("Strongest", 2)
		for index: int in range(TARGET_HELP.size()):
			selector.set_item_tooltip(index, TARGET_HELP[index])
	_create_palette()
	_cancel_placement.pressed.connect(cancel_interaction)
	close_button.pressed.connect(cancel_interaction)
	_enemy_inspector.close_requested.connect(cancel_interaction)
	damage_upgrade.pressed.connect(_upgrade.bind("damage"))
	speed_upgrade.pressed.connect(_upgrade.bind("speed"))
	special_upgrade.pressed.connect(_upgrade.bind("special"))
	sell_button.pressed.connect(_sell)
	targeting_button.item_selected.connect(_target_selected)
	secondary_targeting.item_selected.connect(_secondary_target_selected)
	clear_button.pressed.connect(_clear)
	ready_button.pressed.connect(_toggle_ready)
	send_button.pressed.connect(_send_enemy)
	enemy_selector.item_selected.connect(_enemy_type_selected)
	speed_button.pressed.connect(_request_pacing.bind("speed"))
	autoplay_button.pressed.connect(_request_pacing.bind("autoplay"))
	menu_button.pressed.connect(open_pause_menu)
	pause_menu.resume_requested.connect(_resume_match)
	pause_menu.quit_requested.connect(_quit_match)
	visibility_changed.connect(_visibility_changed)
	_feedback_timer.timeout.connect(_clear_feedback)
	if planning != null:
		planning.changed.connect(_refresh)
		planning.feedback.connect(_show_feedback)
	_refresh()


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
	cancel_interaction()
	cancel_strokes()
	for selector: OptionButton in [targeting_button, secondary_targeting, enemy_selector]:
		selector.get_popup().hide()
	world.set_input_blocked(true)
	$HUD.process_mode = Node.PROCESS_MODE_DISABLED
	pause_menu.open_menu(not planning.singleplayer)
	_owns_tree_pause = planning.singleplayer
	if _owns_tree_pause:
		get_tree().paused = true


func _resume_match() -> void:
	_close_pause_menu()
	if is_visible_in_tree():
		menu_button.grab_focus()


func _quit_match() -> void:
	_close_pause_menu()
	leave_requested.emit()


func _close_pause_menu() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	pause_menu.close_menu()
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


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or pause_menu.visible or (_placement_id == &"" and selected_enemy_id < 0):
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
	var catalog: Array[TowerReward] = CollectionStore.DEFAULT_CATALOG
	if planning != null and planning.collection_store != null:
		catalog = planning.collection_store.catalog
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
		var title: String = String(stats.get("title", button.tower_title))
		button.tower_title = title
		button.cost = int(stats.get("cost", 0))
		var status: String = ""
		if not unlocked:
			status = "Locked"
		elif stats.is_empty():
			status = "Unavailable"
		button.disabled = not available or not unlocked or stats.is_empty() or coins < button.cost
		button.set_pressed_no_signal(id == _placement_id)
		var price: String = str(button.cost) if not stats.is_empty() else ""
		button.refresh_caption(price, status)
		button.tooltip_text = "%d Coins · %d damage · %.2fs · %d tile range" % [button.cost, int(stats.get("damage", 0)), float(stats.get("interval", 0.0)), int(stats.get("range", 0))] if not stats.is_empty() else "This tower is unavailable in the host's match catalog."
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
	var available: bool = planning != null and planning.can_manage_towers(own_slot) and configured
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
	elif _own_coins() < cost:
		delivery += "\nNeed %d more Coins." % (cost - _own_coins())
	var stats_wave: int = int(state.get("wave", 0)) if phase == MatchCombat.Phase.WAVE or finished else int(state.get("wave", 0)) + 1
	send_button.tooltip_text = "%s\n%s\nHost stats for round %d: %d HP · %.2f cells/s.\n%s\nSend cadence: one enemy every %.3f simulation seconds, independently of regular spawns. No combat cutoff." % [_enemy_send_description(stats), delivery, stats_wave, int(stats.get("health", 0)), float(stats.get("speed", 0.0)), queue_feedback, float(rules["send_spawn_interval"])]
	enemy_selector.tooltip_text = send_button.tooltip_text
	for index: int in range(enemy_selector.item_count):
		var type_stats: Dictionary = types[String(enemy_selector.get_item_metadata(index))]
		enemy_selector.set_item_tooltip(index, "%s\nHost stats for wave %d: %d HP · %.2f cells/s." % [_enemy_send_description(type_stats), stats_wave, int(type_stats.get("health", 0)), float(type_stats.get("speed", 0.0))])


func _refresh_enemy_selector(types: Dictionary) -> void:
	var ids: Array[String] = []
	for id: String in types:
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
	if not ids.has(String(_selected_enemy_type)):
		_selected_enemy_type = &"grunt" if ids.has("grunt") else StringName(ids[0])
	for index: int in range(ids.size()):
		enemy_selector.set_item_text(index, String(types[ids[index]].get("title", ids[index])))
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


func _target_selected(index: int) -> void:
	var tower: Dictionary = _selected_tower()
	if tower.is_empty():
		_default_targeting = index
	elif planning != null and planning.active:
		planning.set_targeting(planning.local_slot(), selected_tower_id, index)
	# A requested mode is not displayed as accepted until the host snapshot agrees.
	_refresh_targeting()


func _secondary_target_selected(index: int) -> void:
	if planning != null and not secondary_targeting.disabled and not _selected_tower().is_empty():
		planning.set_secondary_targeting(planning.local_slot(), selected_tower_id, index)
	_refresh_targeting()


func _request_pacing(option: String) -> void:
	if planning == null or not planning.active:
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
			button.icon = preload("res://assets/ui/speed_double.svg") if enabled else preload("res://assets/ui/speed_normal.svg")
		button.tooltip_text = "2× speed" if option == "speed" else "Autoplay"
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
		return
	var types: Dictionary = planning.combat.get("tower_types", {})
	var stats: Dictionary = types.get(String(tower["type_id"]), {})
	var interval: float = float(tower.get("interval", stats.get("interval", 1.0)))
	_tower_title.text = "%s · Level %s" % [String(stats.get("title", "Tower")), TOWER_LEVEL_NUMERALS[MatchCombat.tower_level(tower) - 1]]
	_tower_stats.text = "Kills %d · Damage %d\n%.2f attacks/s · Range %d" % [
		int(tower.get("kills", 0)), int(tower.get("damage", stats.get("damage", 0))),
		1.0 / interval, int(stats.get("range", 0)),
	]
	targeting_button.select(int(tower["mode"]))
	targeting_button.disabled = not planning.can_manage_towers(planning.local_slot())
	_refresh_upgrade(damage_upgrade, tower, stats, "damage")
	_refresh_upgrade(speed_upgrade, tower, stats, "speed")
	var unlocked_special: bool = bool(tower.get("damage_upgraded", false)) and bool(tower.get("speed_upgraded", false)) and not String(stats.get("special_upgrade", "")).is_empty()
	damage_upgrade.visible = not unlocked_special
	speed_upgrade.visible = not unlocked_special
	special_upgrade.visible = unlocked_special
	_refresh_special_upgrade(tower, stats)
	var second_archer: bool = bool(tower.get("special_upgraded", false)) and String(stats.get("special_upgrade", "")) == "second_archer"
	_secondary_target_row.visible = second_archer
	secondary_targeting.disabled = targeting_button.disabled or not second_archer
	secondary_targeting.select(int(tower.get("secondary_mode", tower["mode"])))
	sell_button.text = "Sell · +%d" % int(tower.get("sell_value", 0))
	sell_button.tooltip_text = "60%% of %d invested Coins, including upgrades." % int(tower.get("invested", 0))
	sell_button.disabled = targeting_button.disabled


func _refresh_upgrade(button: Button, tower: Dictionary, stats: Dictionary, upgrade: String) -> void:
	var purchased: bool = bool(tower.get(upgrade + "_upgraded", false))
	var price: int = MatchCombat.tower_upgrade_cost(tower, stats)
	var benefit: String = "+%d damage" % int(stats.get("damage_upgrade_bonus", 0)) if upgrade == "damage" else "%.0f%% faster" % ((1.0 / float(stats.get("speed_upgrade_multiplier", 1.0)) - 1.0) * 100.0)
	button.text = "%s\nPurchased" % benefit if purchased else "%s\n%d" % [benefit, price]
	button.disabled = purchased or targeting_button.disabled or _own_coins() < price
	button.tooltip_text = "One-time upgrade"
	if not purchased and _own_coins() < price:
		button.tooltip_text += "\nNeed %d more Coins." % (price - _own_coins())


func _refresh_special_upgrade(tower: Dictionary, stats: Dictionary) -> void:
	var purchased: bool = bool(tower.get("special_upgraded", false))
	var price: int = int(stats.get("special_upgrade_cost", 0))
	var title: String = String(stats.get("special_upgrade_title", "Special upgrade"))
	special_upgrade.text = "%s\nPurchased" % title if purchased else "%s\n%d" % [title, price]
	special_upgrade.disabled = not special_upgrade.visible or purchased or targeting_button.disabled or _own_coins() < price
	match String(stats.get("special_upgrade", "")):
		"second_archer":
			special_upgrade.tooltip_text = "Adds a second archer with independent targeting and 10% more attacks per second. Archers choose different enemies."
		"bounce":
			special_upgrade.tooltip_text = "Each bolt bounces once to the nearest other enemy for 50% damage, rounded up."
		"freeze":
			special_upgrade.tooltip_text = "After this obelisk has dealt 20% of an enemy's maximum HP, each hit applies a 20% slow for 2 simulation seconds and refreshes its duration. Does not stack."
		_:
			special_upgrade.tooltip_text = ""
	special_upgrade.tooltip_text += "\nFixed price; unaffected by level pricing."
	if not purchased and _own_coins() < price:
		special_upgrade.tooltip_text += "\nNeed %d more Coins." % (price - _own_coins())


func _upgrade(upgrade: String) -> void:
	var button: Button = special_upgrade if upgrade == "special" else (damage_upgrade if upgrade == "damage" else speed_upgrade)
	if planning != null and button.is_visible_in_tree() and not button.disabled and not _selected_tower().is_empty():
		planning.upgrade_tower(planning.local_slot(), selected_tower_id, upgrade)


func _sell() -> void:
	if planning != null and not sell_button.disabled and not _selected_tower().is_empty():
		planning.sell_tower(planning.local_slot(), selected_tower_id)


func _clear() -> void:
	if planning != null and not clear_button.disabled:
		planning.request_clear(planning.local_slot())


func _toggle_ready() -> void:
	if planning != null and not ready_button.disabled:
		planning.submit_ready(true)


func _refresh() -> void:
	if not is_node_ready():
		return
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
	ready_button.disabled = not planning.active or phase != MatchCombat.Phase.PLANNING or planning.ready_flags[own_slot] or not planning.layouts[own_slot].is_ready()
	clear_button.visible = planning.active and bool(state.get("main_round", false))
	ready_button.visible = planning.active and phase == MatchCombat.Phase.PLANNING
	ready_button.text = "Ready"
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


func _show_feedback(message: String) -> void:
	_pending_tower_cell = Vector2i(-1, -1)
	_feedback.text = message
	_feedback.show()
	_feedback_timer.start()


func _clear_feedback() -> void:
	_feedback_timer.stop()
	_feedback.text = ""
	_feedback.hide()
