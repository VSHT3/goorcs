class_name MatchPlanningScreen
extends Control

signal leave_requested


const TARGET_HELP: Array[String] = [
	"Furthest along the route.",
	"Nearest to this tower.",
	"Highest current HP.",
]

var planning: MatchPlanning
var selected_tower_id: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)
var _placement_id: StringName = &""
var _selected_enemy_type: StringName = &"grunt"
var shop_buttons: Dictionary[StringName, TowerShopButton] = {}

@onready var world: MatchWorld = $World
@onready var boards: Array[PathBoard] = world.boards
@onready var leave_button: Button = %Leave
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var send_button: Button = %SendEnemy
@onready var enemy_selector: OptionButton = %EnemyType
@onready var _palette: HBoxContainer = %TowerPalette
@onready var _coins: Label = %Coins
@onready var _income: Label = %Income
@onready var _cancel_placement: Button = %CancelPlacement
@onready var _management: PanelContainer = %TowerManagement
@onready var _tower_title: Label = %TowerTitle
@onready var damage_upgrade: Button = %DamageUpgrade
@onready var speed_upgrade: Button = %SpeedUpgrade
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
		boards[slot].command_mode = true
		if planning != null and planning.collection_store != null:
			boards[slot].tower_catalog = planning.collection_store.catalog
	targeting_button.add_item("Furthest", 0)
	targeting_button.add_item("Closest", 1)
	targeting_button.add_item("Strongest", 2)
	for index: int in range(TARGET_HELP.size()):
		targeting_button.set_item_tooltip(index, TARGET_HELP[index])
	_create_palette()
	_cancel_placement.pressed.connect(cancel_interaction)
	close_button.pressed.connect(cancel_interaction)
	damage_upgrade.pressed.connect(_upgrade.bind("damage"))
	speed_upgrade.pressed.connect(_upgrade.bind("speed"))
	sell_button.pressed.connect(_sell)
	targeting_button.item_selected.connect(_target_selected)
	clear_button.pressed.connect(_clear)
	ready_button.pressed.connect(_toggle_ready)
	send_button.pressed.connect(_send_enemy)
	enemy_selector.item_selected.connect(_enemy_type_selected)
	leave_button.pressed.connect(leave_requested.emit)
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


func _visibility_changed() -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
		world.set_active(false)
		cancel_strokes()
		_clear_feedback()
	else:
		_refresh()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _placement_id == &"":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()


func cancel_interaction() -> bool:
	if _placement_id == &"" and selected_tower_id < 0:
		return false
	cancel_strokes()
	_placement_id = &""
	selected_tower_id = -1
	_pending_tower_cell = Vector2i(-1, -1)
	_refresh()
	return true


func _request_edit(cell: Vector2i, place: bool, slot: int) -> void:
	if planning != null and planning.active and not planning.locked and slot == planning.local_slot() and _placement_id == &"":
		planning.request_edit(slot, cell, place)


func _cell_clicked(cell: Vector2i, button: MouseButton, slot: int) -> void:
	if planning == null or not planning.active or slot != planning.local_slot():
		return
	if button == MOUSE_BUTTON_RIGHT:
		cancel_interaction()
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
	_buy_tower(cell, type_id, slot)


func _buy_tower(cell: Vector2i, type_id: StringName, slot: int) -> void:
	_pending_tower_cell = cell
	planning.build_tower(slot, cell, type_id, _default_targeting)
	_refresh()


func _select_placement(type_id: StringName) -> void:
	if not shop_buttons.has(type_id) or shop_buttons[type_id].disabled:
		return
	cancel_strokes()
	_pending_tower_cell = Vector2i(-1, -1)
	selected_tower_id = -1
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
	var available: bool = planning != null and planning.active and int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) != MatchCombat.Phase.FINISHED
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
	var configured: bool = not stats.is_empty() and rules.has("send_cutoff_seconds")
	var cost: int = int(stats.get("send_cost", 0))
	var gain: int = int(stats.get("send_income", 0))
	var available: bool = planning != null and planning.active and not finished and configured
	var delivers_now: bool = phase == MatchCombat.Phase.WAVE and bool(state.get("sends_open", false))
	enemy_selector.disabled = planning == null or not planning.active or finished or types.is_empty()
	send_button.disabled = not available or _own_coins() < cost
	send_button.text = "%s · %d/+%d" % ["Send now" if delivers_now else "Send next", cost, gain] if configured else "Send unavailable"
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
	var queue_feedback: String = "Next-wave queues:\nIncoming to you: %d (%s).\nOutgoing to opponent: %d (%s)." % [int(queued[own_slot]), _queue_composition(queues[own_slot], types), int(queued[1 - own_slot]), _queue_composition(queues[1 - own_slot], types)]
	if finished:
		queue_feedback += "\nMatch finished; no further delivery or income payouts."
	_income.tooltip_text = "Your recurring bonus: %d Coins at every both-board wave clear, on top of the regular reward. No immediate or terminal payout.\n%s" % [int(income[own_slot]), queue_feedback]
	if not configured:
		send_button.tooltip_text = "Waiting for host enemy types and send rules.\n" + queue_feedback
		enemy_selector.tooltip_text = send_button.tooltip_text
		return
	var delivery: String = "Delivered to the opponent now, in wave %d." % int(state.get("wave", 0)) if delivers_now else "Queued for the opponent's next wave (%d)." % (int(state.get("wave", 0)) + 1)
	if not available:
		delivery = "Match finished." if finished else "Waiting for match."
	elif _own_coins() < cost:
		delivery += "\nNeed %d more Coins." % (cost - _own_coins())
	var stats_wave: int = int(state.get("wave", 0)) if phase == MatchCombat.Phase.WAVE or finished else int(state.get("wave", 0)) + 1
	send_button.tooltip_text = "%s\n%s\nHost stats for wave %d: %d HP · %.2f cells/s.\n%s\nCurrent-wave delivery closes %.1fs after wave start; breaks and later sends queue for the next wave." % [_enemy_send_description(stats), delivery, stats_wave, int(stats.get("health", 0)), float(stats.get("speed", 0.0)), queue_feedback, float(rules.get("send_cutoff_seconds", 0.0))]
	if phase == MatchCombat.Phase.WAVE and not delivers_now and not finished:
		send_button.tooltip_text += "\nQueued enemies use next-wave health and speed when delivered."
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
	_tower_title.text = String(stats.get("title", "Tower"))
	_tower_stats.text = "Kills %d · Damage %d\n%.2f attacks/s · Range %d" % [
		int(tower.get("kills", 0)), int(tower.get("damage", stats.get("damage", 0))),
		1.0 / interval, int(stats.get("range", 0)),
	]
	targeting_button.select(int(tower["mode"]))
	targeting_button.disabled = not planning.active or int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED
	_refresh_upgrade(damage_upgrade, tower, stats, "damage")
	_refresh_upgrade(speed_upgrade, tower, stats, "speed")
	sell_button.text = "Sell · +%d" % int(tower.get("sell_value", 0))
	sell_button.tooltip_text = "60%% of %d invested Coins, including upgrades." % int(tower.get("invested", 0))
	sell_button.disabled = targeting_button.disabled


func _refresh_upgrade(button: Button, tower: Dictionary, stats: Dictionary, upgrade: String) -> void:
	var purchased: bool = bool(tower.get(upgrade + "_upgraded", false))
	var price: int = int(stats.get(upgrade + "_upgrade_cost", 0))
	var benefit: String = "+%d damage" % int(stats.get("damage_upgrade_bonus", 0)) if upgrade == "damage" else "%.0f%% faster" % ((1.0 / float(stats.get("speed_upgrade_multiplier", 1.0)) - 1.0) * 100.0)
	button.text = "%s\nPurchased" % benefit if purchased else "%s\n%d" % [benefit, price]
	button.disabled = purchased or targeting_button.disabled or _own_coins() < price
	button.tooltip_text = "One-time upgrade"
	if not purchased and _own_coins() < price:
		button.tooltip_text += "\nNeed %d more Coins." % (price - _own_coins())


func _upgrade(upgrade: String) -> void:
	var button: Button = damage_upgrade if upgrade == "damage" else speed_upgrade
	if planning != null and not button.disabled and not _selected_tower().is_empty():
		planning.upgrade_tower(planning.local_slot(), selected_tower_id, upgrade)


func _sell() -> void:
	if planning != null and not sell_button.disabled and not _selected_tower().is_empty():
		planning.sell_tower(planning.local_slot(), selected_tower_id)


func _clear() -> void:
	if planning != null and not clear_button.disabled:
		planning.request_clear(planning.local_slot())


func _toggle_ready() -> void:
	if planning != null and not ready_button.disabled:
		planning.submit_ready(not planning.ready_flags[planning.local_slot()])


func _refresh() -> void:
	if not is_node_ready():
		return
	if planning == null:
		world.set_active(false)
		cancel_strokes()
		_clear_feedback()
		clear_button.disabled = true
		ready_button.disabled = true
		_refresh_palette()
		_management.hide()
		_status.text = "Planning unavailable"
		return
	var own_slot: int = planning.local_slot()
	for slot: int in range(boards.size()):
		boards[slot].layout = planning.layouts[slot]
	world.configure(planning.layouts[0].dimensions, own_slot)
	if not planning.active:
		_clear_feedback()
		selected_tower_id = -1
		_placement_id = &""
		_pending_tower_cell = Vector2i(-1, -1)
	var state: Dictionary = planning.combat
	var phase: int = int(state.get("phase", MatchCombat.Phase.PLANNING))
	var finished: bool = phase == MatchCombat.Phase.FINISHED
	var in_wave: bool = phase == MatchCombat.Phase.WAVE
	var editable: bool = planning.active and not planning.locked
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
	for slot: int in range(boards.size()):
		var layout: PathLayout = planning.layouts[slot]
		var board: PathBoard = boards[slot]
		board.cell_click_mode = _placement_id != &"" or not editable
		board.input_enabled = planning.active and not finished and slot == own_slot and (editable or board.cell_click_mode)
		board.placement_id = _placement_id if slot == own_slot else &""
		board.selected_tower_id = selected_tower_id if slot == own_slot else -1
		board.tower_types = state.get("tower_types", {})
		board.enemy_route = planning.locked_routes[slot]
		board.combat_towers = all_towers[slot]
		board.combat_enemies = all_enemies[slot]
		board.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if board.input_enabled else Control.CURSOR_ARROW
		board.queue_redraw()
		var role: String = "Local testing · mirrors your actions" if planning.singleplayer else ("Host" if slot == 0 else "Guest")
		_titles[slot].text = "You" if slot == own_slot else ("Mirror" if planning.singleplayer else "Opponent")
		_titles[slot].tooltip_text = role
		var path_state: String = "Legal route." if layout.is_ready() else \
			("No route to base." if layout.route.is_empty() else "%d disconnected tiles." % layout.disconnected_count)
		_states[slot].tooltip_text = "Base health. %s\n%s" % [role, path_state]
		_states[slot].modulate = Color("d99578") if int(health[slot]) <= 0 else Color("b5e2b7")
		_states[slot].text = "HP %d/%d" % [int(health[slot]), int(rules.get("base_health", 10))]
		_budgets[slot].text = "Ready" if editable and slot != own_slot and planning.ready_flags[slot] else ""
		_budgets[slot].modulate = Color("b5e2b7")
		_counts[slot].visible = not finished and (in_wave or slot == own_slot)
		if in_wave:
			_counts[slot].text = "Alive %d" % all_enemies[slot].size()
			_counts[slot].tooltip_text = "Regular enemies spawned: %d/%d.\nHold A / D to scout." % [int(spawned[slot]), int(state.get("total", 0))]
			_counts[slot].modulate = Color("b5e2b7")
		else:
			_counts[slot].text = "%d/%d tiles" % [layout.used_tiles(), layout.budget]
			_counts[slot].tooltip_text = "%s\nOnly your board accepts edits. Hold A / D to scout." % path_state
			_counts[slot].modulate = Color("b5e2b7") if layout.is_ready() else Color("e0bc77")
	clear_button.disabled = not editable or planning.layouts[own_slot].used_tiles() == 0
	ready_button.disabled = not editable or (not planning.ready_flags[own_slot] and not planning.layouts[own_slot].is_ready())
	clear_button.visible = editable and phase == MatchCombat.Phase.PLANNING
	ready_button.visible = editable and phase == MatchCombat.Phase.PLANNING
	ready_button.text = "Unready" if planning.ready_flags[own_slot] else "Ready"
	var own_layout: PathLayout = planning.layouts[own_slot]
	if own_layout.is_ready():
		ready_button.tooltip_text = "Both players must ready for wave %d. Edits clear readiness." % (int(state.get("wave", 0)) + 1)
	else:
		ready_button.tooltip_text = "Connect the entrance to the base and all placed path tiles before readying."
	if finished:
		var winning_slot: int = int(state.get("winner", -1))
		_status.text = "%s · Wave %d" % ["Victory" if winning_slot == own_slot else "Defeat", int(state.get("wave", 0))]
		if bool(state.get("coin_flip", false)):
			_status.text += " · Coin flip"
			_status.tooltip_text = "Both bases fell in one tick; a coin flip decided the winner."
		else:
			_status.tooltip_text = ""
	elif in_wave:
		_status.text = "Wave %d" % int(state.get("wave", 0))
		_status.tooltip_text = ""
	else:
		_status.text = "Wave %d" % (int(state.get("wave", 0)) + 1)
		_status.tooltip_text = "Planning: build a legal route, then ready for the next wave."
	_refresh_targeting()
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
