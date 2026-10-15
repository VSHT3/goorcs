extends SceneTree

var failures: int = 0
var main: Control
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_navigation_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.menu.visible and main.sandbox_screen == null, "Startup shows menu without constructing an inactive sandbox")
	await _key(KEY_ENTER)
	_check(main.play_screen.visible and not main.menu.visible, "Keyboard activation opens Play")
	await process_frame
	await process_frame
	await _click(main.play_screen.join_button.get_global_rect().get_center())
	await process_frame
	main.play_screen.join_code_input.grab_focus()
	main.play_screen.join_code_input.text = "invalid invite"
	await _key(KEY_ENTER)
	_check(main.session.state == MultiplayerSession.State.ERROR, "Invalid invite retains editable connection form")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and main.session.state == MultiplayerSession.State.IDLE, "Escape leaves connection setup cleanly")
	await _key(KEY_S)
	var sandbox: SandboxScreen = main.sandbox_screen
	_check(sandbox.visible and not main.menu.visible, "Sandbox shortcut opens actual playground")
	await _motion(sandbox.cell_screen_position(Vector2i(1, 4)))
	_check(sandbox.layout.used_tiles() == 0, "Idle sandbox hover cannot edit paths")
	await _button(sandbox.cell_screen_position(Vector2i(1, 4)), true)
	await _motion(sandbox.cell_screen_position(Vector2i(2, 4)))
	_check(sandbox.layout.used_tiles() == 2, "Actual pointer drag edits sandbox")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not sandbox.visible, "Escape interrupts a path stroke and returns to menu")
	await _button(Vector2(10, 10), false)
	await _key(KEY_ESCAPE)
	await _motion(sandbox.cell_screen_position(Vector2i(3, 4)))
	_check(sandbox.layout.used_tiles() == 2, "Resume cannot continue an interrupted stroke")
	for x: int in range(3, 13):
		await _click(sandbox.cell_screen_position(Vector2i(x, 4)))
	_check(sandbox.layout.is_ready(), "Sandbox accepts a complete route")
	var route: Array = sandbox.layout.route.duplicate()
	await _click(sandbox.menu_button.get_global_rect().get_center())
	await _click(sandbox.cell_screen_position(Vector2i(4, 0)))
	_check(sandbox.layout.route == route and sandbox.layout.used_tiles() == 12, "Hidden sandbox cannot accept edits")
	await _key(KEY_B)
	_check(main.orcieary_screen.visible and not sandbox.visible, "Field guide shortcut opens Orcieary without exposing sandbox")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible, "Orcieary Escape returns to menu")
	await _key(KEY_S)
	_check(sandbox.layout.route == route and sandbox.layout.is_ready(), "Sandbox state survives visits to other menus")
	await _check_match_music()
	main.queue_free()
	await create_timer(0.2).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: keyboard navigation, connection teardown, sandbox native edits/resume, Orcieary navigation, and match music lifecycle")
	quit(1 if failures else 0)

func _check_match_music() -> void:
	var music: AudioStreamPlayer = main.get_node("MatchMusic")
	_check(not music.playing, "Sandbox stays silent")
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	await process_frame
	_check(music.playing, "Match starts local soundtrack")
	music.seek(5.0)
	for x: int in range(1, 13):
		main.planning.request_edit(0, Vector2i(x, 4), true)
	main.planning.submit_ready(true)
	await process_frame
	_check(music.playing and music.get_playback_position() >= 4.0, "Snapshots and wave start do not restart music")
	await _key(KEY_ESCAPE)
	_check(main.play_screen.planning_screen.pause_menu.visible, "Escape opens active match menu")
	main.play_screen.planning_screen.pause_menu.quit_button.pressed.emit()
	_check(main.menu.visible and not music.playing and not main.planning.active, "Quit ends match and stops soundtrack")
	main.sandbox_button.pressed.emit()
	_check(main.sandbox_screen.visible and not music.playing, "Sandbox return does not restart match music")

func _click(point: Vector2) -> void:
	await _button(point, true)
	await _button(point, false)

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
