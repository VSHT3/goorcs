extends Control

# Prototype settings, not final map or balance decisions.
@export var board_dimensions := Vector2i(14, 9)
@export var tile_budget: int = 30
@export var entrance_cell := Vector2i(0, 4)
@export var base_cell := Vector2i(13, 4)
@export var combat_rules: CombatRules = preload("res://resources/combat/prototype.tres")

var layout: PathLayout
var _workshop_opened: bool = false
var collection_store: CollectionStore
var collection_screen: CollectionScreen
var session: MultiplayerSession
var planning: MatchPlanning
var play_screen: MultiplayerLobby
var _last_activity: Control

@onready var board: PathBoard = $Margin/Content/Workspace/BoardArea/Board
@onready var status: Label = $Margin/Content/Workspace/Sidebar/Content/Status
@onready var budget_label: Label = $Margin/Content/Workspace/Sidebar/Content/Budget
@onready var route_label: Label = $Margin/Content/Workspace/Sidebar/Content/Route
@onready var feedback_label: Label = $WorkshopFeedback
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var menu: Control = $Menu
@onready var workshop: Control = $Margin
@onready var open_button: Button = $Menu/Center/Panel/Open
@onready var play_button: Button = $Menu/Center/Panel/Play
@onready var _match_music: AudioStreamPlayer = $MatchMusic


func _ready() -> void:
	Input.set_custom_mouse_cursor(preload("res://assets/ui/cursor_arrow.png"), Input.CURSOR_ARROW, Vector2(2, 2))
	Input.set_custom_mouse_cursor(preload("res://assets/ui/cursor_hand.png"), Input.CURSOR_POINTING_HAND, Vector2(10, 2))
	layout = PathLayout.new(board_dimensions, tile_budget, entrance_cell, base_cell)
	board.layout = layout
	board.edited.connect(_refresh)
	board.feedback.connect(_show_feedback)
	_feedback_timer.timeout.connect(_clear_feedback)
	$Margin/Content/Workspace/Sidebar/Content/Clear.pressed.connect(_clear)
	open_button.pressed.connect(_open_workshop)
	$Menu/Center/Panel/Quit.pressed.connect(_quit)
	$Margin/Content/Header/Content/Menu.pressed.connect(_show_menu)
	$Menu/Center/Panel/Collection.pressed.connect(_open_collection)
	play_button.pressed.connect(_open_play)
	if collection_store == null:
		collection_store = CollectionStore.new()
	session = MultiplayerSession.new()
	session.name = "Session"
	add_child(session)
	planning = MatchPlanning.new()
	planning.name = "Planning"
	planning.session = session
	planning.collection_store = collection_store
	planning.combat_rules = combat_rules
	planning.configure(board_dimensions, tile_budget, entrance_cell, base_cell)
	add_child(planning)
	play_screen = preload("res://scenes/multiplayer_lobby.tscn").instantiate()
	play_screen.session = session
	play_screen.planning = planning
	play_screen.hide()
	add_child(play_screen)
	(_match_music.stream as AudioStreamMP3).loop = true
	planning.changed.connect(_sync_match_music)
	play_screen.visibility_changed.connect(_sync_match_music)
	play_screen.back_requested.connect(_show_menu)
	collection_screen = preload("res://scenes/collection_screen.tscn").instantiate()
	collection_screen.store = collection_store
	collection_screen.hide()
	add_child(collection_screen)
	collection_screen.back_requested.connect(_show_menu)
	budget_label.tooltip_text = "%d × %d board. Endpoints are free; unused budget is allowed." % [board_dimensions.x, board_dimensions.y]
	_refresh()
	_show_menu()


func _open_workshop() -> void:
	_workshop_opened = true
	_last_activity = workshop
	play_screen.prepare_to_leave()
	play_screen.hide()
	collection_screen.prepare_to_leave()
	collection_screen.hide()
	menu.hide()
	workshop.show()
	$Margin/Content/Header/Content/Menu.grab_focus()


func _open_collection() -> void:
	board.cancel_stroke()
	_last_activity = collection_screen
	play_screen.prepare_to_leave()
	play_screen.hide()
	menu.hide()
	workshop.hide()
	collection_screen.show()


func _open_play() -> void:
	board.cancel_stroke()
	_last_activity = play_screen
	collection_screen.prepare_to_leave()
	collection_screen.hide()
	workshop.hide()
	menu.hide()
	play_screen.show()
	play_screen.open()


func _show_menu() -> void:
	board.cancel_stroke()
	_feedback_timer.stop()
	_clear_feedback()
	workshop.hide()
	collection_screen.prepare_to_leave()
	collection_screen.hide()
	play_screen.prepare_to_leave()
	play_screen.hide()
	menu.show()
	open_button.text = "Resume workshop" if _workshop_opened else "Workshop"
	if _last_activity == workshop:
		open_button.grab_focus()
	else:
		play_button.grab_focus()


func _sync_match_music() -> void:
	var playing_match: bool = planning.active and play_screen.is_visible_in_tree() \
		and int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) != MatchCombat.Phase.FINISHED
	if playing_match:
		if not _match_music.playing:
			_match_music.play()
	else:
		_match_music.stop()


func _quit() -> void:
	session.leave()
	get_tree().quit()


func _input(event: InputEvent) -> void:
	# Connection forms still cancel with Escape; active matches open their menu.
	if play_screen.visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			var screen: MatchPlanningScreen = play_screen.planning_screen
			if screen != null and screen.is_visible_in_tree():
				if screen.pause_menu.visible:
					screen.pause_menu.handle_escape()
				elif not screen.cancel_interaction():
					screen.open_pause_menu()
			else:
				_show_menu()
			get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			if workshop.visible or collection_screen.visible:
				_show_menu()
			elif _last_activity == workshop:
				_open_workshop()
			elif _last_activity == collection_screen:
				_open_collection()
			elif _last_activity == play_screen:
				_open_play()
			get_viewport().set_input_as_handled()


func _refresh() -> void:
	budget_label.text = "%d / %d tiles" % [layout.used_tiles(), layout.budget]
	if layout.is_ready():
		status.text = "Ready"
		status.modulate = Color("b5e2b7")
	elif layout.route.is_empty():
		status.text = "No route"
		status.modulate = Color("e0bc77")
	else:
		status.text = "Disconnected"
		status.modulate = Color("e0bc77")
	if layout.route.is_empty():
		route_label.text = "%d isolated tiles" % layout.disconnected_count if layout.disconnected_count > 0 else ""
	else:
		route_label.text = "%d steps" % [layout.route.size() - 1]
		if layout.disconnected_count > 0:
			route_label.text += " · %d isolated" % layout.disconnected_count
	route_label.visible = not route_label.text.is_empty()
	_feedback_timer.stop()
	_clear_feedback()
	board.queue_redraw()


func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.show()
	_feedback_timer.start()


func _clear_feedback() -> void:
	feedback_label.text = ""
	feedback_label.hide()


func _clear() -> void:
	layout.clear()
	_refresh()


func _exit_tree() -> void:
	# Release native cursor textures before the rendering server shuts down.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
