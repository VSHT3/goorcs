class_name MatchPlanningScreen
extends Control

enum Tool { PATH, TOWER, INSPECT }

const RULES := "Edges connect; corners do not. Every tile must reach the entrance. Edits clear your ready state.\nFree Arrow placement · No economy · All combat numbers are provisional playtest settings."
const TARGET_HELP: Array[String] = [
	"Furthest: greatest progress along the route.",
	"Closest: shortest distance to this tower.",
	"Strongest: highest current HP.",
]

var planning: MatchPlanning
var selected_tower_id: int = -1
var _default_targeting: int = 0
var _pending_tower_cell := Vector2i(-1, -1)
var _feedback_message: String = ""
var _feedback_until_msec: int = 0

@onready var boards: Array[PathBoard] = [$Content/Boards/Host/Board, $Content/Boards/Guest/Board]
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var tool_button: OptionButton = %Tool
@onready var targeting_button: OptionButton = %Targeting
@onready var _target_help: Label = %TargetHelp
@onready var _controls: Label = %Controls
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _titles: Array[Label] = [$Content/Boards/Host/Title, $Content/Boards/Guest/Title]
@onready var _states: Array[Label] = [$Content/Boards/Host/State, $Content/Boards/Guest/State]
@onready var _budgets: Array[Label] = [$Content/Boards/Host/Budget, $Content/Boards/Guest/Budget]
@onready var _routes: Array[Label] = [$Content/Boards/Host/Route, $Content/Boards/Guest/Route]


func _ready() -> void:
	for slot: int in range(boards.size()):
		boards[slot].edit_requested.connect(_request_edit.bind(slot))
		boards[slot].cell_clicked.connect(_cell_clicked.bind(slot))
		boards[slot].command_mode = true
	tool_button.add_item("Path", Tool.PATH)
	tool_button.add_item("Tower", Tool.TOWER)
	tool_button.add_item("Inspect", Tool.INSPECT)
	targeting_button.add_item("Furthest", 0)
	targeting_button.add_item("Closest", 1)
	targeting_button.add_item("Strongest", 2)
	for index: int in range(TARGET_HELP.size()):
		targeting_button.set_item_tooltip(index, TARGET_HELP[index] + " Ties use the lowest enemy ID.")
	tool_button.item_selected.connect(_tool_selected)
	targeting_button.item_selected.connect(_target_selected)
	clear_button.pressed.connect(_clear)
	ready_button.pressed.connect(_toggle_ready)
	visibility_changed.connect(_visibility_changed)
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


func _request_edit(cell: Vector2i, place: bool, slot: int) -> void:
	if planning != null and planning.active and not planning.locked and slot == planning.local_slot() and tool_button.selected == Tool.PATH:
		planning.request_edit(slot, cell, place)


func _cell_clicked(cell: Vector2i, button: MouseButton, slot: int) -> void:
	if planning == null or not planning.active or slot != planning.local_slot() or button != MOUSE_BUTTON_LEFT:
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
	if tool_button.selected == Tool.TOWER:
		_pending_tower_cell = cell
		planning.build_tower(slot, cell, _default_targeting)
	_refresh()


func _tool_selected(_index: int) -> void:
	cancel_strokes()
	_pending_tower_cell = Vector2i(-1, -1)
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
	var subject: String = "New Arrow towers" if tower.is_empty() else "Selected Arrow #%d" % selected_tower_id
	_target_help.text = "%s · %s Ties: lowest enemy ID." % [subject, TARGET_HELP[mode]]
	_target_help.tooltip_text = "Arrow fires instant hits in circular range. Selected tower's range is outlined.\nOnly accepted host state changes the selected tower's displayed mode."


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
		clear_button.disabled = true
		ready_button.disabled = true
		tool_button.disabled = true
		targeting_button.disabled = true
		_status.text = "Planning unavailable"
		return
	var own_slot: int = planning.local_slot()
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
	tool_button.disabled = not planning.active or finished
	tool_button.set_item_disabled(Tool.PATH, planning.locked)
	if planning.locked and tool_button.selected == Tool.PATH:
		cancel_strokes()
		tool_button.select(Tool.INSPECT)
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
		board.cell_click_mode = tool_button.selected != Tool.PATH
		board.input_enabled = planning.active and not finished and slot == own_slot and (editable or board.cell_click_mode)
		board.selected_tower_id = selected_tower_id if slot == own_slot else -1
		board.tower_range = float(rules.get("range", 3.0))
		board.combat_towers = all_towers[slot]
		board.combat_enemies = all_enemies[slot]
		board.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if board.input_enabled else Control.CURSOR_ARROW
		board.queue_redraw()
		var role: String = "Host" if slot == 0 else "Guest"
		_titles[slot].text = "%s · %s" % ["Your board" if slot == own_slot else "Opponent · Read-only", role]
		var legality: String = "Legal path"
		if layout.route.is_empty():
			legality = "No route to base"
		elif layout.disconnected_count > 0:
			legality = "%d isolated tiles" % layout.disconnected_count
		var readiness: String = "Ready" if planning.ready_flags[slot] else "Not ready"
		var board_state: String = "Defending · Path locked" if in_wave else ("%s · %s" % [readiness, legality])
		if finished:
			board_state = "Base destroyed" if int(health[slot]) <= 0 else "Base survived"
		_states[slot].text = "Base %d / %d · %s" % [int(health[slot]), int(rules.get("base_health", 10)), board_state]
		_states[slot].modulate = Color("d99578") if int(health[slot]) <= 0 else (Color("b5e2b7") if in_wave or planning.ready_flags[slot] else Color("e0bc77"))
		_budgets[slot].text = "%d / %d path tiles · %d Arrow towers" % [layout.used_tiles(), layout.budget, all_towers[slot].size()]
		var route_size: int = planning.locked_routes[slot].size() if planning.locked else layout.route.size()
		var route_text: String = "No route yet"
		if route_size > 0:
			route_text = "%s: %d steps" % ["Captured route" if planning.locked else "Shortest route", route_size - 1]
		if in_wave or finished:
			_routes[slot].text = "Spawned %d / %d · Alive %d · %s\nE entrance / B base · Green: captured route" % [int(spawned[slot]), int(state.get("total", 0)), all_enemies[slot].size(), route_text]
		else:
			_routes[slot].text = "%s · %d isolated tiles\nE entrance / B base · Green: shortest route" % [route_text, layout.disconnected_count]
	clear_button.disabled = not editable or planning.layouts[own_slot].used_tiles() == 0
	ready_button.disabled = not editable or (not planning.ready_flags[own_slot] and not planning.layouts[own_slot].is_ready())
	ready_button.text = "Match finished" if finished else ("Wave running" if in_wave else ("Unready" if planning.ready_flags[own_slot] else "Ready for wave %d" % (int(state.get("wave", 0)) + 1)))
	if finished:
		var winning_slot: int = int(state.get("winner", -1))
		var winning_role: String = "Host" if winning_slot == 0 else "Guest"
		_status.text = "You %s · %s wins · Wave %d\n%s" % [
			"Won" if winning_slot == own_slot else "Lost", winning_role, int(state.get("wave", 0)),
			"Both bases fell in one tick. One host coin flip decided the winner." if bool(state.get("coin_flip", false)) else "A base was destroyed. The result is final."]
		_feedback.text = "Match finished · Leave / Esc to end the session. Workshop and collection remain local."
	elif in_wave:
		_status.text = "Wave %d · Defend both captured routes\nBuild free Arrow towers or change targets live. Paths are locked until both boards clear." % int(state.get("wave", 0))
		_feedback.text = "Free Arrow placement · No economy · Provisional stats: %d damage · %.2fs interval · %.1f-cell circular range." % [int(rules.get("damage", 2)), float(rules.get("interval", 0.75)), float(rules.get("range", 3.0))]
	elif planning.ready_flags[own_slot]:
		_status.text = "Planning wave %d · You are ready\nWaiting for your opponent. Editing or changing a tower clears your ready state." % (int(state.get("wave", 0)) + 1)
		_feedback.text = RULES
	else:
		var wave_number: int = int(state.get("wave", 0))
		_status.text = "%s · Planning wave %d\nBuild a legal path and free Arrow towers. Both players ready starts every wave." % ["Wave cleared; health and towers kept" if wave_number > 0 else "Connected", wave_number + 1]
		_feedback.text = RULES
	match tool_button.selected:
		Tool.PATH:
			_controls.text = "Left drag: place · Right drag: erase\nOnly your board is editable."
		Tool.TOWER:
			_controls.text = "Left click: build / select Arrow\nRight click: no action · No selling."
		Tool.INSPECT:
			_controls.text = "Left click: select your Arrow\nOpponent board stays read-only."
	_refresh_targeting()
	if not finished and not _feedback_message.is_empty() and Time.get_ticks_msec() < _feedback_until_msec:
		_feedback.text = _feedback_message
	if not planning.active:
		cancel_strokes()


func _show_feedback(message: String) -> void:
	_pending_tower_cell = Vector2i(-1, -1)
	_feedback_message = message
	_feedback_until_msec = Time.get_ticks_msec() + 3500
	_feedback.text = message
