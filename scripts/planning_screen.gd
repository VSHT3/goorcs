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
var shop_buttons: Dictionary[StringName, TowerShopButton] = {}

@onready var world: MatchWorld = $World
@onready var boards: Array[PathBoard] = world.boards
@onready var leave_button: Button = %Leave
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var _palette: HBoxContainer = %TowerPalette
@onready var _coins: Label = %Coins
@onready var _placement_status: Label = %PlacementStatus
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
	leave_button.pressed.connect(leave_requested.emit)
	visibility_changed.connect(_visibility_changed)
	_feedback_timer.timeout.connect(_clear_feedback)
	if planning != null:
		planning.changed.connect(_refresh)
		planning.feedback.connect(_show_feedback)
	_refresh()


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
		button.icon = reward.icon_texture
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.add_theme_font_size_override("font_size", 14)
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
			status = "Unavailable in this match"
		elif coins < button.cost:
			status = "Need %d more Coins" % (button.cost - coins)
		elif not available:
			status = "Match finished" if planning != null and planning.active else "Waiting for match"
		button.disabled = not available or not unlocked or stats.is_empty() or coins < button.cost
		button.set_pressed_no_signal(id == _placement_id)
		var price: String = "%d Coins" % button.cost if not stats.is_empty() else "Unavailable"
		button.text = "%s\n%s" % [title, price + (" · " + status if not status.is_empty() and not stats.is_empty() else "")]
		button.tooltip_text = "%d damage · %.2fs · %d tile range" % [int(stats.get("damage", 0)), float(stats.get("interval", 0.0)), int(stats.get("range", 0))] if not stats.is_empty() else ""
		if id == _placement_id and button.disabled:
			_placement_id = &""
			button.set_pressed_no_signal(false)
	_coins.text = "Coins %d" % coins
	_cancel_placement.visible = _placement_id != &""
	if _placement_id != &"":
		var button: TowerShopButton = shop_buttons[_placement_id]
		_placement_status.text = "%s · %d Coins" % [button.tower_title, button.cost]
	else:
		_placement_status.text = ""


func _own_coins() -> int:
	if planning == null:
		return 0
	var coins: Array = planning.combat.get("coins", [0, 0])
	return int(coins[planning.local_slot()])

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
	_tower_stats.text = "Kills %d · Damage %d · %.2f attacks/s · Range %d" % [
		int(tower.get("kills", 0)), int(tower.get("damage", stats.get("damage", 0))),
		1.0 / interval, int(stats.get("range", 0)),
	]
	targeting_button.select(int(tower["mode"]))
	targeting_button.disabled = not planning.active or int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED
	_refresh_upgrade(damage_upgrade, tower, stats, "damage")
	_refresh_upgrade(speed_upgrade, tower, stats, "speed")
	sell_button.text = "Sell · +%d Coins" % int(tower.get("sell_value", 0))
	sell_button.tooltip_text = "60%% of %d invested Coins, including upgrades." % int(tower.get("invested", 0))
	sell_button.disabled = targeting_button.disabled


func _refresh_upgrade(button: Button, tower: Dictionary, stats: Dictionary, upgrade: String) -> void:
	var purchased: bool = bool(tower.get(upgrade + "_upgraded", false))
	var price: int = int(stats.get(upgrade + "_upgrade_cost", 0))
	var benefit: String = "+%d damage" % int(stats.get("damage_upgrade_bonus", 0)) if upgrade == "damage" else "%.0f%% faster" % ((1.0 / float(stats.get("speed_upgrade_multiplier", 1.0)) - 1.0) * 100.0)
	button.text = "%s · Purchased" % benefit if purchased else "%s · %d Coins" % [benefit, price]
	button.disabled = purchased or targeting_button.disabled or _own_coins() < price
	button.tooltip_text = "One-time upgrade"
	if not purchased and _own_coins() < price:
		button.text += "\nNeed %d more Coins" % (price - _own_coins())


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
		board.layout = layout
		board.cell_click_mode = _placement_id != &"" or not editable
		board.input_enabled = planning.active and not finished and slot == own_slot and (editable or board.cell_click_mode)
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
		var legality: String = "Legal"
		if layout.route.is_empty():
			legality = "Route missing"
		elif layout.disconnected_count > 0:
			legality = "%d isolated" % layout.disconnected_count
		var readiness: String = "Ready" if planning.ready_flags[slot] else "Not ready"
		_states[slot].text = "HP %d / %d" % [int(health[slot]), int(rules.get("base_health", 10))]
		_states[slot].modulate = Color("d99578") if int(health[slot]) <= 0 else Color("b5e2b7")
		if in_wave or finished:
			_budgets[slot].text = "Alive %d · Spawned %d / %d" % [all_enemies[slot].size(), int(spawned[slot]), int(state.get("total", 0))]
			if finished:
				_budgets[slot].text = "%s · %s" % ["Destroyed" if int(health[slot]) <= 0 else "Survived", _budgets[slot].text]
			_budgets[slot].tooltip_text = ""
		else:
			_budgets[slot].text = "%s · %s · %d / %d tiles" % [readiness, legality, layout.used_tiles(), layout.budget]
			_budgets[slot].tooltip_text = "Shortest route: %d steps" % (layout.route.size() - 1) if not layout.route.is_empty() else "No route to base"
		_budgets[slot].modulate = Color("b5e2b7") if in_wave or planning.ready_flags[slot] else Color("e0bc77")
	clear_button.disabled = not editable or planning.layouts[own_slot].used_tiles() == 0
	ready_button.disabled = not editable or (not planning.ready_flags[own_slot] and not planning.layouts[own_slot].is_ready())
	ready_button.text = "Match finished" if finished else ("Wave running" if in_wave else ("Unready" if planning.ready_flags[own_slot] else "Ready for wave %d" % (int(state.get("wave", 0)) + 1)))
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
		_status.text = "Planning · Wave %d" % (int(state.get("wave", 0)) + 1)
		_status.tooltip_text = ""
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
