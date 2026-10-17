extends SceneTree

var failures: int = 0
var main: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	await _key(KEY_S)
	var sandbox: SandboxScreen = main.sandbox_screen
	await _click(sandbox.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2)]:
		await _click(sandbox.cell_screen_position(cell))
		_check(sandbox.placement_id == &"arrow_tower" and sandbox.selected_tower_id < 0, "Shift placement retains the free build tool without opening inspection")
	_check(sandbox.controller.state["towers"][0].size() == 2, "Two distinct Shift clicks create exactly two towers")
	await _click(sandbox.cell_screen_position(sandbox.layout.entrance))
	_check(sandbox.controller.state["towers"][0].size() == 2 and sandbox.placement_id == &"arrow_tower", "An illegal Shift placement keeps the tool and creates nothing")
	await _shift(false)
	await _click(sandbox.cell_screen_position(Vector2i(4, 2)))
	_check(sandbox.placement_id == &"" and sandbox.selected_tower_id > 0 and sandbox.controller.state["towers"][0].size() == 3, "Releasing Shift restores ordinary placement and inspection")
	sandbox.cancel_interaction()
	await _click(sandbox.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	await _click(sandbox.cell_screen_position(Vector2i(5, 2)))
	await _key(KEY_ESCAPE)
	_check(sandbox.placement_id == &"" and sandbox.visible, "Escape cancels repeat building before leaving Sandbox")
	await _shift(false)
	await _key(KEY_ESCAPE)
	await _key(KEY_P)
	main.play_screen.singleplayer_button.pressed.emit()
	_check(main.planning.select_loadout([&"arrow_tower"]) and main.planning.commit_loadout(), "Real solo run admits the starter loadout")
	main.planning.debug_set_values(1, 200, 8)
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	await _settle()
	await _click(screen.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2)]:
		await _click(screen.world.cell_screen_position(0, cell))
		_check(screen._placement_type() == &"arrow_tower" and screen.selected_tower_id < 0, "Paid repeat building retains local build selection after accepted snapshots")
	_check(main.planning.combat["towers"][0].size() == 2 and main.planning.combat["towers"][1].size() == 2 and main.planning.combat["coins"] == [110, 110], "Repeated solo purchases charge both mirrored owners exactly once per tower")
	await _click(screen.world.cell_screen_position(1, Vector2i(4, 2)))
	_check(main.planning.combat["towers"][1].size() == 2 and main.planning.combat["coins"] == [110, 110], "Repeat building cannot purchase on the opponent board")
	await _click(screen.world.cell_screen_position(0, main.planning.layouts[0].entrance))
	_check(main.planning.combat["towers"][0].size() == 2 and screen._placement_type() == &"arrow_tower" and main.planning.combat["coins"] == [110, 110], "Rejected paid placement preserves selection and all money")
	await _shift(false)
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	_check(screen._placement_type() == &"" and screen.selected_tower_id > 0 and main.planning.combat["coins"] == [65, 65], "Normal paid placement still selects its accepted tower")
	await _click(screen.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	await _click(screen.world.cell_screen_position(0, Vector2i(5, 2)))
	_check(main.planning.combat["towers"][0].size() == 4 and main.planning.combat["coins"] == [20, 20] and screen._placement_type() == &"", "Running out of funds exits repeat placement without a speculative extra purchase")
	await _shift(false)
	_finish.call_deferred()


func _finish() -> void:
	main.planning.stop_singleplayer()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS: native Shift repeat building in Sandbox and solo, normal inspection, rejected/path/opponent purchases, mirrored atomic costs, insufficient funds and Escape cancellation")
	quit.call_deferred(1 if failures else 0)


func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	for index: int in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
