extends Control

# Prototype settings, not final map or balance decisions.
@export var board_dimensions := Vector2i(14, 9)
@export var tile_budget: int = 30
@export var entrance_cell := Vector2i(0, 4)
@export var base_cell := Vector2i(13, 4)

var layout: PathLayout

@onready var board: PathBoard = $Margin/Content/Workspace/Board
@onready var status: Label = $Margin/Content/Workspace/Sidebar/Status
@onready var budget_label: Label = $Margin/Content/Workspace/Sidebar/Budget
@onready var route_label: Label = $Margin/Content/Workspace/Sidebar/Route
@onready var feedback_label: Label = $Margin/Content/Feedback


func _ready() -> void:
	layout = PathLayout.new(board_dimensions, tile_budget, entrance_cell, base_cell)
	board.layout = layout
	board.edited.connect(_refresh)
	board.feedback.connect(_show_feedback)
	$Margin/Content/Workspace/Sidebar/Clear.pressed.connect(_clear)
	$Margin/Content/Workspace/Sidebar/Settings.text = "%d × %d board · %d tile maximum\nTemporary prototype settings" % [board_dimensions.x, board_dimensions.y, tile_budget]
	_refresh()


func _refresh() -> void:
	budget_label.text = "%d / %d tiles placed\n%d remaining · endpoints are free" % [layout.used_tiles(), layout.budget, layout.budget - layout.used_tiles()]
	if layout.is_ready():
		status.text = "READY\nConnected entrance to base"
		status.modulate = Color("b5e2b7")
	elif layout.route.is_empty():
		status.text = "BUILD A ROUTE\nConnect entrance to base"
		status.modulate = Color("e0bc77")
	else:
		status.text = "DISCONNECTED TILES\nJoin or remove isolated tiles"
		status.modulate = Color("e0bc77")
	if layout.route.is_empty():
		route_label.text = "No route to base yet.\n%d isolated placed tiles." % layout.disconnected_count
	else:
		route_label.text = "Shortest route: %d steps\n%d isolated placed tiles" % [layout.route.size() - 1, layout.disconnected_count]
	feedback_label.text = "Unused budget is allowed. Every placed tile must connect to the entrance."
	board.queue_redraw()


func _show_feedback(message: String) -> void:
	feedback_label.text = message


func _clear() -> void:
	layout.clear()
	_refresh()
