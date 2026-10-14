class_name MatchPlanningScreen
extends Control


const TARGET_HELP: Array[String] = [
	"Furthest along the route.",
	"Nearest to this tower.",
	"Highest current HP.",
]

var planning: MatchPlanning
var selected_tower_id: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)

@onready var boards: Array[PathBoard] = [$Content/Boards/Host/Board, $Content/Boards/Guest/Board]
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var tower_menu: OptionButton = %TowerMenu
@onready var targeting_button: OptionButton = %Targeting
@onready var _arrow_stats: Label = %ArrowStats
@onready var _target_label: Label = $Content/Tools/TargetLabel
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _titles: Array[Label] = [$Content/Boards/Host/Title, $Content/Boards/Guest/Title]
@onready var _states: Array[Label] = [$Content/Boards/Host/State, $Content/Boards/Guest/State]
@onready var _budgets: Array[Label] = [$Content/Boards/Host/Budget, $Content/Boards/Guest/Budget]


func _ready() -> void:
	for slot: int in range(boards.size()):
		boards[slot].edit_requested.connect(_request_edit.bind(slot))
		boards[slot].cell_clicked.connect(_cell_clicked.bind(slot))
		boards[slot].command_mode = true
	boards[0].mirror_horizontal = true
	tower_menu.add_item("None", 0)
	tower_menu.add_item("Arrow tower", 1)
	tower_menu.set_item_tooltip(0, "Inspect towers. During breaks, left drag places paths and right drag erases them.")
	tower_menu.set_item_tooltip(1, "Left click: place an Arrow on empty ground. Right click: cancel placement.")
	targeting_button.add_item("Furthest", 0)
	targeting_button.add_item("Closest", 1)
	targeting_button.add_item("Strongest", 2)
	for index: int in range(TARGET_HELP.size()):
		targeting_button.set_item_tooltip(index, TARGET_HELP[index])
	tower_menu.item_selected.connect(_tower_selected)
	targeting_button.item_selected.connect(_target_selected)
	clear_button.pressed.connect(_clear)
	ready_button.pressed.connect(_toggle_ready)
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
	if not is_visible_in_tree():
		cancel_strokes()
		_clear_feedback()


func _request_edit(cell: Vector2i, place: bool, slot: int) -> void:
	if planning != null and planning.active and not planning.locked and slot == planning.local_slot() and tower_menu.selected == 0:
		planning.request_edit(slot, cell, place)


func _cell_clicked(cell: Vector2i, button: MouseButton, slot: int) -> void:
	if planning == null or not planning.active or slot != planning.local_slot():
		return
	if button == MOUSE_BUTTON_RIGHT and tower_menu.selected != 0:
		tower_menu.select(0)
		_tower_selected(0)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED:
		return
	_pending_tower_cell = Vector2i(-1, -1)
	for tower: Dictionary in boards[slot].combat_towers:
		if tower["cell"] == cell:
			selected_tower_id = int(tower["id"])
			_refresh()
			return
	selected_tower_id = -1
	if tower_menu.selected == 1:
		_pending_tower_cell = cell
		planning.build_tower(slot, cell, _default_targeting)
	_refresh()


func _tower_selected(_index: int) -> void:
	cancel_strokes()
	_pending_tower_cell = Vector2i(-1, -1)
	selected_tower_id = -1
	_refresh()


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
	var mode: int = int(tower["mode"]) if not tower.is_empty() else _default_targeting
	targeting_button.select(mode)
	var has_controls: bool = tower_menu.selected != 0 or not tower.is_empty()
	targeting_button.visible = has_controls
	_target_label.visible = has_controls
	_arrow_stats.visible = has_controls
	var rules: Dictionary = planning.combat.get("rules", {}) if planning != null else {}
	_arrow_stats.text = "Arrow · %d dmg · %.2fs · %.1f cells" % [int(rules.get("damage", 2)), float(rules.get("interval", 0.75)), float(rules.get("range", 3.0))]
	_arrow_stats.tooltip_text = "Damage · Firing interval · Circular range"
	targeting_button.tooltip_text = "New Arrow priority" if tower.is_empty() else "Selected Arrow priority"


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
		cancel_strokes()
		_clear_feedback()
		clear_button.disabled = true
		ready_button.disabled = true
		tower_menu.disabled = true
		targeting_button.disabled = true
		_status.text = "Planning unavailable"
		return
	var own_slot: int = planning.local_slot()
	if not planning.active:
		_clear_feedback()
		selected_tower_id = -1
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
	tower_menu.disabled = not planning.active or finished
	targeting_button.disabled = not planning.active or finished
	if _pending_tower_cell != Vector2i(-1, -1):
		for tower: Dictionary in all_towers[own_slot]:
			if tower["cell"] == _pending_tower_cell:
				selected_tower_id = int(tower["id"])
				_pending_tower_cell = Vector2i(-1, -1)
				break
	if selected_tower_id >= 0 and _selected_tower().is_empty():
		selected_tower_id = -1
	for slot: int in range(boards.size()):
		var layout: PathLayout = planning.layouts[slot]
		var board: PathBoard = boards[slot]
		board.layout = layout
		board.cell_click_mode = tower_menu.selected != 0 or not editable
		board.input_enabled = planning.active and not finished and slot == own_slot and (editable or board.cell_click_mode)
		board.selected_tower_id = selected_tower_id if slot == own_slot else -1
		board.tower_range = float(rules.get("range", 3.0))
		board.enemy_route = planning.locked_routes[slot]
		board.combat_towers = all_towers[slot]
		board.combat_enemies = all_enemies[slot]
		board.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if board.input_enabled else Control.CURSOR_ARROW
		board.queue_redraw()
		var role: String = "Host" if slot == 0 else "Guest"
		_titles[slot].text = "You" if slot == own_slot else "Opponent"
		_titles[slot].tooltip_text = role
		var legality: String = "Legal"
		if layout.route.is_empty():
			legality = "No route to base"
		elif layout.disconnected_count > 0:
			legality = "%d isolated tiles" % layout.disconnected_count
		var readiness: String = "Ready" if planning.ready_flags[slot] else "Not ready"
		_states[slot].text = "HP %d / %d" % [int(health[slot]), int(rules.get("base_health", 10))]
		_states[slot].modulate = Color("d99578") if int(health[slot]) <= 0 else Color("b5e2b7")
		if in_wave or finished:
			_budgets[slot].text = "Alive %d · Spawned %d / %d" % [all_enemies[slot].size(), int(spawned[slot]), int(state.get("total", 0))]
			if finished:
				_budgets[slot].text = "%s · %s" % ["Destroyed" if int(health[slot]) <= 0 else "Survived", _budgets[slot].text]
			_budgets[slot].tooltip_text = ""
		else:
			_budgets[slot].text = "%s · %s · Tiles %d / %d" % [readiness, legality, layout.used_tiles(), layout.budget]
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
	tower_menu.tooltip_text = tower_menu.get_item_tooltip(tower_menu.selected)
	_refresh_targeting()
	if not planning.active:
		cancel_strokes()


func _show_feedback(message: String) -> void:
	_pending_tower_cell = Vector2i(-1, -1)
	_feedback.text = message
	_feedback.show()
	_feedback_timer.start()


func _clear_feedback() -> void:
	_feedback_timer.stop()
	_feedback.text = ""
	_feedback.hide()
