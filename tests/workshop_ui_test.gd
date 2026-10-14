extends SceneTree

var failures: int = 0
var main: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path: String = OS.get_temp_dir().path_join("gorcs_workshop_ui_%d.json" % OS.get_process_id())
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	root.add_child(main)
	await _settle()
	for width: int in [1280, 1000]:
		root.content_scale_size = Vector2i(width, 720)
		root.size = Vector2i(width, 720)
		await _settle()
		await _click(main.open_button.get_global_rect().get_center())
		await _settle()
		var rect: Rect2 = main.board.get_global_rect()
		var entrance: Vector2 = _cell_point(main.layout.entrance)
		var base: Vector2 = _cell_point(main.layout.base)
		for cell: Vector2i in [main.layout.entrance, main.layout.base]:
			for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				var count: int = main.layout.used_tiles()
				var route: Array = main.layout.route.duplicate()
				await _click(_cell_point(cell), button)
				_check(main.feedback_label.is_visible_in_tree(), "Endpoint rejection remains visible instead of hiding the error")
				_check(main.layout.used_tiles() == count and main.layout.route == route, "Endpoint clicks cannot edit workshop state")
				_check(_same_rect(main.board.get_global_rect(), rect) and _cell_point(main.layout.entrance).is_equal_approx(entrance) and _cell_point(main.layout.base).is_equal_approx(base), "Endpoint feedback never changes board bounds or cell coordinates at width %d" % width)
		var timer: Timer = main.get_node("FeedbackTimer")
		var wait_time: float = timer.wait_time
		timer.start(0.02)
		await create_timer(0.08).timeout
		_check(not main.feedback_label.visible and _same_rect(main.board.get_global_rect(), rect), "Feedback expiry cannot resize the board")
		timer.wait_time = wait_time
		for x: int in range(1, 13):
			await _click(_cell_point(Vector2i(x, 4)))
		_check(main.layout.is_ready(), "The reskinned workshop still paints a legal route")
		var saved_route: Array = main.layout.route.duplicate()
		await _click(main.get_node("Margin/Content/Header/Content/Menu").get_global_rect().get_center())
		_check(main.menu.is_visible_in_tree() and not main.feedback_label.visible, "Returning to menu clears workshop-only feedback")
		var before: Rect2 = main.open_button.get_global_rect()
		await _motion(before.get_center())
		await create_timer(0.2).timeout
		_check(_same_rect(main.open_button.get_global_rect(), before), "Menu hover cannot shift the actual clickable control")
		await _click(main.open_button.get_global_rect().get_center())
		_check(main.layout.route == saved_route and main.layout.is_ready(), "Polished menu resume preserves the workshop")
		main.get_node("Margin/Content/Workspace/Sidebar/Content/Clear").pressed.emit()
		await _settle()
		for y: int in range(3):
			for x: int in range(main.layout.dimensions.x):
				if main.layout.used_tiles() < main.layout.budget:
					await _click(_cell_point(Vector2i(x, y)))
		var full: int = main.layout.used_tiles()
		rect = main.board.get_global_rect()
		await _click(_cell_point(Vector2i(12, 6)))
		_check(full == main.layout.budget and main.layout.used_tiles() == full and main.feedback_label.visible, "Over-budget painting is rejected with visible feedback")
		_check(_same_rect(main.board.get_global_rect(), rect), "Budget rejection also leaves board size stable")
		main.get_node("Margin/Content/Workspace/Sidebar/Content/Clear").pressed.emit()
		await _click(main.get_node("Margin/Content/Header/Content/Menu").get_global_rect().get_center())
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if failures == 0:
		print("PASS: workshop endpoint/budget feedback and expiry preserve board geometry, painting/resume work, menu hover keeps hit bounds stable at standard/compact widths")
	quit.call_deferred(1 if failures else 0)


func _cell_point(cell: Vector2i) -> Vector2:
	return main.board.get_global_transform_with_canvas() * main.board.cell_center(cell)


func _same_rect(a: Rect2, b: Rect2) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)


func _settle() -> void:
	await process_frame
	await process_frame


func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
