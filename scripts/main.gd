extends Control

@export var board_dimensions := Vector2i(14, 9)
@export var tile_budget: int = 30
@export var entrance_cell := Vector2i(0, 4)
@export var base_cell := Vector2i(13, 4)
@export var combat_rules: CombatRules = preload("res://resources/combat/prototype.tres")

var collection_store: CollectionStore
var statistics_store: EnemyStatisticsStore
var collection_screen: CollectionScreen
var sandbox_screen: SandboxScreen
var orcieary_screen: OrciearyScreen
var towerieary_screen: ToweriearyScreen
var session: MultiplayerSession
var planning: MatchPlanning
var play_screen: MultiplayerLobby
var _last_activity: Control

@onready var menu: Control = $Menu
@onready var sandbox_button: Button = $Menu/Center/Panel/Sandbox
@onready var orcieary_button: Button = $Menu/Center/Panel/Orcieary
@onready var towerieary_button: Button = $Menu/Center/Panel/Towerieary
@onready var collection_button: Button = $Menu/Center/Panel/Collection
@onready var play_button: Button = $Menu/Center/Panel/Play
@onready var _match_music: AudioStreamPlayer = $MatchMusic


func _ready() -> void:
	Input.set_custom_mouse_cursor(preload("res://assets/ui/cursor_arrow.png"), Input.CURSOR_ARROW, Vector2(1, 1))
	Input.set_custom_mouse_cursor(preload("res://assets/ui/cursor_hand.png"), Input.CURSOR_POINTING_HAND, Vector2(10, 2))
	sandbox_button.pressed.connect(_open_sandbox)
	orcieary_button.pressed.connect(_open_orcieary)
	towerieary_button.pressed.connect(_open_towerieary)
	collection_button.pressed.connect(_open_collection)
	play_button.pressed.connect(_open_play)
	$Menu/Center/Panel/Quit.pressed.connect(_quit)
	if collection_store == null:
		collection_store = CollectionStore.new("user://collection.json", combat_rules.catalog)
	if statistics_store == null:
		statistics_store = EnemyStatisticsStore.new()
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
	planning.changed.connect(_observe_enemy_totals)
	play_screen.visibility_changed.connect(_sync_match_music)
	play_screen.back_requested.connect(_show_menu)
	collection_screen = preload("res://scenes/collection_screen.tscn").instantiate()
	collection_screen.store = collection_store
	collection_screen.hide()
	add_child(collection_screen)
	collection_screen.back_requested.connect(_show_menu)
	_show_menu()


func _hide_activities() -> void:
	play_screen.prepare_to_leave()
	play_screen.hide()
	collection_screen.prepare_to_leave()
	collection_screen.hide()
	if sandbox_screen != null:
		sandbox_screen.prepare_to_leave()
		sandbox_screen.hide()
	if orcieary_screen != null:
		orcieary_screen.prepare_to_leave()
		orcieary_screen.hide()
	if towerieary_screen != null:
		towerieary_screen.prepare_to_leave()
		towerieary_screen.hide()
	menu.hide()


func _open_sandbox() -> void:
	_hide_activities()
	if sandbox_screen == null:
		sandbox_screen = preload("res://scenes/sandbox_screen.tscn").instantiate()
		sandbox_screen.configure(combat_rules.catalog, combat_rules)
		sandbox_screen.hide()
		add_child(sandbox_screen)
		sandbox_screen.back_requested.connect(_show_menu)
	_last_activity = sandbox_screen
	sandbox_screen.show()
	sandbox_screen.open()


func _open_orcieary() -> void:
	_hide_activities()
	if orcieary_screen == null:
		orcieary_screen = preload("res://scenes/orcieary_screen.tscn").instantiate()
		orcieary_screen.configure(combat_rules.catalog, combat_rules, statistics_store)
		orcieary_screen.hide()
		add_child(orcieary_screen)
		orcieary_screen.back_requested.connect(_show_menu)
	_last_activity = orcieary_screen
	orcieary_screen.show()
	orcieary_screen.open()


func _open_towerieary() -> void:
	_hide_activities()
	if towerieary_screen == null:
		towerieary_screen = preload("res://scenes/towerieary_screen.tscn").instantiate()
		towerieary_screen.configure(combat_rules.catalog, combat_rules)
		towerieary_screen.hide()
		add_child(towerieary_screen)
		towerieary_screen.back_requested.connect(_show_menu)
	_last_activity = towerieary_screen
	towerieary_screen.show()
	towerieary_screen.open()


func _open_collection() -> void:
	_hide_activities()
	_last_activity = collection_screen
	collection_screen.show()
	collection_screen.back_button.grab_focus()


func _open_play() -> void:
	_hide_activities()
	_last_activity = play_screen
	play_screen.show()
	play_screen.open()


func _show_menu() -> void:
	_hide_activities()
	menu.show()
	if sandbox_screen != null and _last_activity == sandbox_screen:
		sandbox_button.grab_focus()
	elif orcieary_screen != null and _last_activity == orcieary_screen:
		orcieary_button.grab_focus()
	elif towerieary_screen != null and _last_activity == towerieary_screen:
		towerieary_button.grab_focus()
	elif _last_activity == collection_screen:
		collection_button.grab_focus()
	else:
		play_button.grab_focus()


func _observe_enemy_totals() -> void:
	if planning.active:
		statistics_store.observe(planning.combat, planning.local_slot())


func _sync_match_music() -> void:
	var playing_match: bool = planning.active and play_screen.is_visible_in_tree() \
		and int(planning.combat.get("phase", MatchCombat.Phase.PLANNING)) != MatchCombat.Phase.FINISHED
	if playing_match:
		if not _match_music.playing:
			_match_music.play()
	else:
		_match_music.stop()


func _quit() -> void:
	_observe_enemy_totals()
	session.leave()
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if play_screen.visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			var screen: MatchPlanningScreen = play_screen.planning_screen
			if screen != null and screen.is_visible_in_tree():
				if int(planning.combat.get("phase",-1)) == MatchCombat.Phase.FINISHED:
					screen.handle_results_escape()
					get_viewport().set_input_as_handled()
					return
				if screen.debug_popup.visible:
					screen.debug_popup.hide()
				elif screen.pause_menu.visible:
					screen.pause_menu.handle_escape()
				elif not screen.cancel_interaction():
					screen.open_pause_menu()
			else:
				_show_menu()
			get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if menu.visible:
		match key.keycode:
			KEY_P:
				_open_play()
			KEY_S:
				_open_sandbox()
			KEY_B:
				_open_orcieary()
			KEY_T:
				_open_towerieary()
			KEY_C:
				_open_collection()
			KEY_ESCAPE:
				if sandbox_screen != null and _last_activity == sandbox_screen:
					_open_sandbox()
				elif orcieary_screen != null and _last_activity == orcieary_screen:
					_open_orcieary()
				elif towerieary_screen != null and _last_activity == towerieary_screen:
					_open_towerieary()
				elif _last_activity == collection_screen:
					_open_collection()
				elif _last_activity == play_screen:
					_open_play()
				else:
					return
			_:
				return
	elif key.keycode == KEY_ESCAPE and collection_screen.visible:
		_show_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
