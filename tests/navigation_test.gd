extends SceneTree

var failures: int = 0
var main: Control


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new("user://navigation_test_%d.json" % OS.get_process_id())
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.menu.visible and not main.workshop.visible, "Startup shows only the menu")
	await _key(KEY_ENTER)
	_check(main.workshop.visible and not main.menu.visible, "Keyboard activation opens the workshop")
	await _motion(_cell_point(Vector2i(1, 4)))
	await _motion(_cell_point(Vector2i(2, 4)))
	_check(main.layout.used_tiles() == 0, "Idle hovering cannot place tiles")
	await _button(_cell_point(Vector2i(1, 4)), true)
	await _motion(_cell_point(Vector2i(2, 4)))
	_check(main.layout.used_tiles() == 2, "Dragging places tiles")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not main.workshop.visible, "Escape interrupts drawing and returns to menu")
	await _button(Vector2(10, 10), false)
	await _key(KEY_ESCAPE)
	await _motion(_cell_point(Vector2i(3, 4)))
	_check(main.layout.used_tiles() == 2, "Resuming cannot continue an interrupted stroke")
	await _button(_cell_point(Vector2i(3, 4)), true)
	await _button(Vector2(10, 10), false)
	await _motion(_cell_point(Vector2i(4, 4)))
	_check(main.layout.used_tiles() == 3, "Releasing outside the board ends the stroke")
	for x: int in range(4, 13):
		await _click(_cell_point(Vector2i(x, 4)))
	_check(main.layout.is_ready(), "The workshop still builds valid routes")
	var saved_route: Array[Vector2i] = main.layout.route.duplicate()
	var saved_used: int = main.layout.used_tiles()
	await _click(_control_center(main.get_node("Margin/Content/Header/Menu")))
	await _click(_cell_point(Vector2i(0, 0)))
	_check(main.menu.visible and main.layout.used_tiles() == saved_used, "Hidden board does not accept edits")
	await _click(_control_center(main.open_button))
	_check(main.workshop.visible and main.layout.is_ready() and main.layout.route == saved_route and main.layout.used_tiles() == saved_used, "Menu button and resume preserve the entire layout")
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	_check(main.workshop.visible and main.layout.route == saved_route, "Keyboard resume preserves layout")
	if failures == 0:
		print("PASS: navigation preserves layout, hidden board rejects edits, idle hover is safe, interrupted/outside-release strokes end")
	quit(1 if failures > 0 else 0)


func _cell_point(cell: Vector2i) -> Vector2:
	return main.board.global_position + main.board.cell_center(cell)


func _control_center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5


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
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
