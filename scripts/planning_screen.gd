class_name MatchPlanningScreen
extends Control

const RULES := "Edges connect; corners do not. Every placed tile must reach the entrance.\nUnused budget is allowed. Editing clears your ready state."

var planning: MatchPlanning

@onready var boards: Array[PathBoard] = [$Content/Boards/Host/Board, $Content/Boards/Guest/Board]
@onready var clear_button: Button = %Clear
@onready var ready_button: Button = %Ready
@onready var _status: Label = %Status
@onready var _feedback: Label = %Feedback
@onready var _titles: Array[Label] = [$Content/Boards/Host/Title, $Content/Boards/Guest/Title]
@onready var _states: Array[Label] = [$Content/Boards/Host/State, $Content/Boards/Guest/State]
@onready var _budgets: Array[Label] = [$Content/Boards/Host/Budget, $Content/Boards/Guest/Budget]
@onready var _routes: Array[Label] = [$Content/Boards/Host/Route, $Content/Boards/Guest/Route]


func _ready() -> void:
	for slot: int in range(boards.size()):
		boards[slot].edit_requested.connect(_request_edit.bind(slot))
		boards[slot].command_mode = true
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
	if planning != null and planning.active and not planning.locked:
		planning.request_edit(slot, cell, place)


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
		_status.text = "Planning unavailable"
		return
	var own_slot: int = planning.local_slot()
	var editable: bool = planning.active and not planning.locked
	for slot: int in range(boards.size()):
		var layout: PathLayout = planning.layouts[slot]
		boards[slot].layout = layout
		boards[slot].input_enabled = editable and slot == own_slot
		boards[slot].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if boards[slot].input_enabled else Control.CURSOR_ARROW
		boards[slot].queue_redraw()
		var role: String = "Host" if slot == 0 else "Guest"
		_titles[slot].text = "%s · %s" % ["Your board" if slot == own_slot else "Opponent · Read-only", role]
		var legality: String = "Legal path"
		if layout.route.is_empty():
			legality = "No route to base"
		elif layout.disconnected_count > 0:
			legality = "%d isolated tiles" % layout.disconnected_count
		var readiness: String = "Ready" if planning.ready_flags[slot] else "Not ready"
		_states[slot].text = "Routes locked · Legal path" if planning.locked else "%s · %s" % [readiness, legality]
		_states[slot].modulate = Color("b5e2b7") if planning.ready_flags[slot] else Color("e0bc77")
		_budgets[slot].text = "%d / %d tiles · %d remaining" % [layout.used_tiles(), layout.budget, layout.budget - layout.used_tiles()]
		var route_size: int = planning.locked_routes[slot].size() if planning.locked else layout.route.size()
		var route_text: String = "No route yet"
		if route_size > 0:
			route_text = "%s: %d steps" % ["Captured route" if planning.locked else "Shortest route", route_size - 1]
		_routes[slot].text = "%s · %d isolated tiles\nE entrance / B base · Green line: shortest route" % [route_text, layout.disconnected_count]
	clear_button.disabled = not editable or planning.layouts[own_slot].used_tiles() == 0
	ready_button.disabled = not editable or (not planning.ready_flags[own_slot] and not planning.layouts[own_slot].is_ready())
	ready_button.text = "Routes locked" if planning.locked else ("Unready" if planning.ready_flags[own_slot] else "Ready")
	if planning.locked:
		_status.text = "Routes locked · Both players ready\nCombat is not implemented. Leave to end this session."
		_feedback.text = "Both routes have been captured. Editing, clearing, and readiness are now locked."
	elif planning.ready_flags[own_slot]:
		_status.text = "Connected · You are ready\nWaiting for your opponent. You can unready or edit your board."
		_feedback.text = RULES
	else:
		_status.text = "Connected · Shared planning\nBuild a legal path, then ready. Both players must be ready to lock routes."
		_feedback.text = RULES
	if not planning.active:
		cancel_strokes()


func _show_feedback(message: String) -> void:
	_feedback.text = message
