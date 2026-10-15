extends SceneTree

const TOWER_CELL := Vector2i(6, 3)
const DROP_CELL := Vector2i(7, 3)

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
var world: MatchWorld
var save_path: String
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_match_world_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated match collection directory")
	save_path = directory.path_join("collection.json")
	var save := FileAccess.open(save_path, FileAccess.WRITE)
	if save == null:
		_check(false, "Create isolated unlocked match collection")
		DirAccess.remove_absolute(directory)
		quit(1)
		return
	save.store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower", "orc_ballista", "rune_obelisk"]}))
	save.close()
	var saved_bytes: String = FileAccess.get_file_as_string(save_path)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	root.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	await _settle()
	main.play_screen.singleplayer_button.pressed.emit()
	await _settle()
	screen = main.play_screen.planning_screen
	world = screen.world
	world.set_process(false)
	_check(screen.is_visible_in_tree() and main.planning.active, "Real match navigation activates the world screen")
	main.planning.build_tower(0, TOWER_CELL, &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	await _settle()
	_check(main.planning.combat["towers"][0].size() == 1 and main.planning.combat["towers"][1].size() == 1, "Real solo command publishes towers on both boards")
	if main.planning.combat["towers"][0].is_empty() or main.planning.combat["towers"][1].is_empty():
		await _finish(saved_bytes)
		return
	screen.cancel_interaction()
	await _check_camera_and_input(0)
	await _check_top_row_visibility(0)
	await _check_stroke_cancellation()
	await _check_focus_and_visibility()
	await _check_leave_and_reopen()

	# Feed the real screen an accepted guest view without opening network sockets.
	# Commands are not faked: guest inspection only reads the published combat model.
	main.planning.build_tower(0, TOWER_CELL, &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	main.planning.singleplayer = false
	main.session.is_host = false
	main.planning.changed.emit()
	await _settle()
	world.set_process(false)
	await _check_camera_and_input(1)
	await _check_top_row_visibility(1)
	await _finish(saved_bytes)


func _check_top_row_visibility(own_slot: int) -> void:
	var old_size: Vector2i = root.size
	var old_scale: Vector2i = root.content_scale_size
	for width: int in [1280, 1000]:
		root.content_scale_size = Vector2i(width, 720)
		root.size = Vector2i(width, 720)
		await _settle()
		var board: PathBoard = world.boards[own_slot]
		var header: Control = screen.get_node("HUD/Header")
		for artwork: TowerReward in board.tower_catalog:
			var rect: Rect2 = board._sprite_rect(artwork.icon_texture, artwork.board_height, artwork.board_anchor,
				board.cell_center(Vector2i(6, 0)) + Vector2(0, board._cell_size() * 0.28))
			var bounds: Rect2 = board._texture_bounds[artwork.icon_texture]
			var visible_top := Vector2(rect.position.x, rect.position.y + bounds.position.y * rect.size.y / artwork.icon_texture.get_height())
			var top: Vector2 = board.get_global_transform_with_canvas() * visible_top
			_check(top.y >= header.get_global_rect().end.y, "Top-row %s clears the fixed HUD at width=%d slot=%d" % [artwork.id, width, own_slot])
	root.content_scale_size = old_scale
	root.size = old_size
	await _settle()


func _check_camera_and_input(own_slot: int) -> void:
	var opponent: int = 1 - own_slot
	var start: Vector2 = world.camera.position
	var own_center: Vector2 = world.boards[own_slot].get_global_transform() * (world.boards[own_slot].size * 0.5)
	_check(absf(start.x - own_center.x) < 1.0, "Startup camera focuses the actual owned board, slot=%d" % own_slot)
	_check(world.camera_bounds.y > world.camera_bounds.x, "Both boards form a traversable continuous world")
	var dimensions: Vector2i = main.planning.layouts[own_slot].dimensions
	var host_left: Vector2 = world.cell_screen_position(0, Vector2i(1, 3))
	var host_right: Vector2 = world.cell_screen_position(0, Vector2i(dimensions.x - 2, 3))
	var guest_left: Vector2 = world.cell_screen_position(1, Vector2i(1, 3))
	var guest_right: Vector2 = world.cell_screen_position(1, Vector2i(dimensions.x - 2, 3))
	_check(host_left.x > host_right.x and guest_left.x < guest_right.x, "Host cells face inward through mirroring while guest cells retain logical orientation")
	_check((host_left.x + host_right.x) * 0.5 < (guest_left.x + guest_right.x) * 0.5, "Host occupies the left world and guest occupies the right world")
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(dimensions.x - 1, 0), Vector2i(0, dimensions.y - 1), dimensions - Vector2i.ONE]:
		_check(world.get_global_rect().has_point(world.cell_screen_position(own_slot, corner)), "Startup fits every owned board corner into gameplay, slot=%d cell=%s" % [own_slot, corner])
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	var presentation: Dictionary = main.planning.combat.duplicate(true)
	var direction: float = 1.0 if own_slot == 0 else -1.0
	var destination: float = world.camera_bounds.y if direction > 0.0 else world.camera_bounds.x
	world.pan(0.025, Vector2(direction, 0.0))
	var first: float = world.camera.position.x
	world.pan(0.025, Vector2(direction, 0.0))
	var second: float = world.camera.position.x
	_check((first - start.x) * direction > 0.0 and (destination - first) * direction > 0.0, "A short pan moves through an intermediate position, slot=%d" % own_slot)
	_check((second - first) * direction > 0.0 and (destination - second) * direction > 0.0, "Successive pan steps keep moving rather than switching boards, slot=%d" % own_slot)
	world.pan(100.0, Vector2(direction, 0.0))
	_check(is_equal_approx(world.camera.position.x, destination), "Pan clamps at the far world extent, slot=%d" % own_slot)
	world.pan(1.0, Vector2(direction, 0.0))
	_check(is_equal_approx(world.camera.position.x, destination), "Holding pan beyond an extent cannot escape the world")
	world.pan(0.025, Vector2(-direction, 0.0))
	_check((world.camera.position.x - destination) * direction < 0.0, "Pan can smoothly reverse away from a clamped extent")
	world.pan(100.0, Vector2(-direction, 0.0))
	var near_extent: float = world.camera_bounds.x if direction > 0.0 else world.camera_bounds.y
	_check(is_equal_approx(world.camera.position.x, near_extent), "Reverse pan clamps at the opposite extent")
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, "Camera traversal cannot mutate authoritative or accepted combat state")

	world.pan(0.08, Vector2(direction, 0.0))
	var panned: Vector2 = world.camera.position
	main.planning._mirror_snapshot(accepted.duplicate(true))
	main.planning.changed.emit()
	await _settle()
	world.set_process(false)
	_check(world.camera.position.is_equal_approx(panned), "Replacing accepted layouts and combat snapshots preserves local pan")
	var clicks: Array[Vector2i] = []
	var opponent_clicks: Array[Vector2i] = []
	var collect_own := func(cell: Vector2i, _button: MouseButton) -> void: clicks.append(cell)
	var collect_opponent := func(cell: Vector2i, _button: MouseButton) -> void: opponent_clicks.append(cell)
	world.boards[own_slot].cell_clicked.connect(collect_own)
	world.boards[opponent].cell_clicked.connect(collect_opponent)
	var original_zoom: Vector2 = world.camera.zoom
	world.zoom_at(0.85, world.cell_screen_position(own_slot, TOWER_CELL))
	await _settle()
	var scaled_position: Vector2 = world.camera.position
	var scaled_zoom: Vector2 = world.camera.zoom
	main.planning._mirror_snapshot(accepted.duplicate(true))
	main.planning.changed.emit()
	await _settle()
	world.set_process(false)
	_check(world.camera.position.is_equal_approx(scaled_position) and world.camera.zoom.is_equal_approx(scaled_zoom),
		"Real accepted snapshot refresh retains both local zoom and cursor-anchored pan")
	var id: int = int(main.planning.combat["towers"][own_slot][0]["id"])
	var hud_before: Array[Rect2] = _hud_rects()
	var world_rect: Rect2 = world.get_global_rect()
	var board_sizes: Array[Vector2] = [world.boards[0].size, world.boards[1].size]
	var camera_before: Vector2 = world.camera.position
	await _click(world.cell_screen_position(own_slot, TOWER_CELL))
	_check(clicks == [TOWER_CELL] and screen.selected_tower_id == id, "Actual root click selects the logical owned tower under scaled, translated camera, slot=%d" % own_slot)
	_check(screen.get_node("%TowerManagement").is_visible_in_tree(), "Owned click visibly opens tower management")
	main.planning.feedback.emit("The selected build cannot be placed on an occupied tile.")
	await _settle()
	_check(screen.get_node("%Feedback").is_visible_in_tree(), "A real planning notice is visible above the world")
	_check(_rects_equal(hud_before, _hud_rects()), "Management and feedback do not reflow fixed HUD controls")
	_check(_rect_equal(world_rect, world.get_global_rect()) and world.boards[0].size == board_sizes[0] and world.boards[1].size == board_sizes[1] and world.camera.position.is_equal_approx(camera_before), "Management and notices do not resize or move gameplay")
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, "Inspection and presentation notices do not alter accepted match state")
	await _check_popup_and_text_focus()
	screen.close_button.pressed.emit()
	screen._clear_feedback()
	await _settle()

	var old_size: Vector2i = root.size
	var old_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i(1500, 900)
	root.size = Vector2i(1500, 900)
	await _settle()
	_check(not world.size.is_equal_approx(world_rect.size), "Resize actually changes the gameplay viewport")
	_check(world.boards[0].size == board_sizes[0] and world.boards[1].size == board_sizes[1], "Resize preserves fixed world board dimensions")
	world.zoom_at(0.85, world.cell_screen_position(own_slot, TOWER_CELL))
	await _settle()
	clicks.clear()
	await _click(world.cell_screen_position(own_slot, TOWER_CELL))
	_check(clicks == [TOWER_CELL] and screen.selected_tower_id == id, "Owned root click still roundtrips to its cell after logical viewport resize, slot=%d" % own_slot)
	screen.cancel_interaction()
	await _settle()
	if own_slot == 0:
		await _check_owned_drop()
		accepted = main.planning._snapshot().duplicate(true)
		presentation = main.planning.combat.duplicate(true)
	world.pan(100.0, Vector2(direction, 0.0))
	world.camera.force_update_scroll()
	await _settle()
	await _click(world.cell_screen_position(opponent, TOWER_CELL))
	_check(opponent_clicks.is_empty() and screen.selected_tower_id == -1, "An actual opponent tower click cannot select or issue owned interaction, slot=%d" % own_slot)
	var payload: Dictionary = {"tower_type": "arrow_tower"}
	var opponent_point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * world.cell_screen_position(opponent, Vector2i(8, 3))
	_check(not world._can_drop_data(opponent_point, payload), "Root drag routing denies the opponent board")
	world._drop_data(opponent_point, payload)
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, "Opponent clicks and native drops cannot mutate the accepted match")
	root.content_scale_size = old_scale
	root.size = old_size
	world.zoom_at(original_zoom.x / world.camera.zoom.x, world.get_global_rect().get_center())
	await _settle()
	world.set_active(false)
	world.set_active(true)
	world.set_process(false)
	world.boards[own_slot].cell_clicked.disconnect(collect_own)
	world.boards[opponent].cell_clicked.disconnect(collect_opponent)


func _check_owned_drop() -> void:
	var drops: Array[Vector2i] = []
	var collect_drop := func(cell: Vector2i, _type_id: StringName) -> void: drops.append(cell)
	world.boards[0].tower_dropped.connect(collect_drop)
	var payload: Dictionary = {"tower_type": "arrow_tower"}
	var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * world.cell_screen_position(0, DROP_CELL)
	_check(world._can_drop_data(point, payload), "Native root drag accepts legal owned ground after pan, scale and resize")
	world._drop_data(point, payload)
	await _settle()
	var built: bool = false
	for tower: Dictionary in main.planning.combat["towers"][0]:
		built = built or tower["cell"] == DROP_CELL
	_check(drops == [DROP_CELL] and built, "Root native drop routes the logical cell through a real authoritative build")
	_check(not world._can_drop_data(point, payload), "Occupied ground reuses board drop legality after the accepted build")
	screen.cancel_interaction()
	world.boards[0].tower_dropped.disconnect(collect_drop)


func _check_popup_and_text_focus() -> void:
	var position: Vector2 = world.camera.position
	for selector: OptionButton in [screen.targeting_button, screen.enemy_selector]:
		selector.show_popup()
		await process_frame
		await _key(KEY_D, true)
		world._process(0.1)
		_check(world.camera.position.is_equal_approx(position), "An open gameplay selector blocks camera movement")
		await _key(KEY_D, false)
		selector.get_popup().hide()
	var editor := LineEdit.new()
	screen.add_child(editor)
	editor.grab_focus()
	await _key(KEY_D, true)
	world._process(0.1)
	_check(world.camera.position.is_equal_approx(position), "Typing in a focused text field cannot pan gameplay")
	await _key(KEY_D, false)
	editor.queue_free()
	await process_frame


func _check_stroke_cancellation() -> void:
	screen.cancel_interaction()
	await _stroke_press(world.cell_screen_position(0, Vector2i(4, 5)))
	await _motion(world.cell_screen_position(0, Vector2i(5, 5)), MOUSE_BUTTON_MASK_LEFT)
	await _stroke_release(world.cell_screen_position(0, Vector2i(5, 5)))
	_check(main.planning.layouts[0].has_path(Vector2i(4, 5)) and main.planning.layouts[0].has_path(Vector2i(5, 5)), "Positive control: a held owned stroke paints subsequent logical cells")
	var start_cell := Vector2i(6, 5)
	var next_cell := Vector2i(7, 5)
	await _stroke_press(world.cell_screen_position(0, start_cell))
	_check(main.planning.layouts[0].has_path(start_cell), "Real owned path press reaches authoritative planning")
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	world.pan(0.05, Vector2.RIGHT)
	await _motion(world.cell_screen_position(0, next_cell), MOUSE_BUTTON_MASK_LEFT)
	await _stroke_release(world.cell_screen_position(0, next_cell))
	_check(main.planning._snapshot() == accepted, "Moving the camera cancels a held stroke instead of painting under the cursor")

	await _stroke_press(world.cell_screen_position(0, Vector2i(8, 5)))
	_check(main.planning.layouts[0].has_path(Vector2i(8, 5)), "Fresh press starts a stroke after pan cancellation")
	accepted = main.planning._snapshot().duplicate(true)
	world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _motion(world.cell_screen_position(0, Vector2i(9, 5)), MOUSE_BUTTON_MASK_LEFT)
	await _stroke_release(world.cell_screen_position(0, Vector2i(9, 5)))
	_check(main.planning._snapshot() == accepted, "Application focus loss cancels path drawing until a fresh press")

	await _stroke_press(world.cell_screen_position(0, Vector2i(10, 5)))
	_check(main.planning.layouts[0].has_path(Vector2i(10, 5)), "Fresh press starts a stroke after focus cancellation")
	accepted = main.planning._snapshot().duplicate(true)
	screen.hide()
	await _settle()
	await _motion(world.cell_screen_position(0, Vector2i(11, 5)), MOUSE_BUTTON_MASK_LEFT)
	screen.show()
	await _settle()
	world.set_process(false)
	await _motion(world.cell_screen_position(0, Vector2i(11, 5)), MOUSE_BUTTON_MASK_LEFT)
	await _stroke_release(world.cell_screen_position(0, Vector2i(11, 5)))
	_check(main.planning._snapshot() == accepted, "Hiding and resuming cannot retain or resume a path stroke")


func _check_focus_and_visibility() -> void:
	world.pan(0.08, Vector2.RIGHT)
	var before_key: Vector2 = world.camera.position
	await _key(KEY_D, true)
	world._process(0.1)
	_check(world.camera.position.x > before_key.x, "Held D advances the real camera continuously")
	world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var after_focus: Vector2 = world.camera.position
	world._process(0.5)
	_check(world.camera.position.is_equal_approx(after_focus), "Focus loss releases held pan without snapping the current view")
	await _key(KEY_D, false)
	await _key(KEY_A, true)
	world._process(0.05)
	_check(world.camera.position.x < after_focus.x, "A fresh A press moves back after focus cancellation")
	screen.hide()
	await _settle()
	var hidden_position: Vector2 = world.camera.position
	world._process(0.5)
	world.pan(0.5, Vector2.LEFT)
	_check(world.camera.position.is_equal_approx(hidden_position), "Hidden world ignores held keys and direct pan input")
	screen.show()
	await _settle()
	world.set_process(false)
	var own_center: Vector2 = world.boards[0].get_global_transform() * (world.boards[0].size * 0.5)
	_check(absf(world.camera.position.x - own_center.x) < 1.0, "New screen activation restores owned-board startup focus")
	var reopened: Vector2 = world.camera.position
	world._process(0.5)
	_check(world.camera.position.is_equal_approx(reopened), "Activation cannot revive a key held before hiding")
	await _key(KEY_A, false)


func _check_leave_and_reopen() -> void:
	world.pan(0.15, Vector2.RIGHT)
	var fresh_zoom: float = world._fit_zoom
	world.zoom_at(1.4, world.get_global_rect().get_center())
	await _key(KEY_D, true)
	await _click(_center(screen.leave_button))
	_check(main.menu.visible and not screen.is_visible_in_tree() and not main.planning.active, "Real HUD Leave returns to navigation and deactivates the match")
	main.play_button.pressed.emit()
	await _settle()
	main.play_screen.singleplayer_button.pressed.emit()
	await _settle()
	world.set_process(false)
	var own_center: Vector2 = world.boards[0].get_global_transform() * (world.boards[0].size * 0.5)
	_check(absf(world.camera.position.x - own_center.x) < 1.0, "Leaving and reopening starts at the owned board instead of the previous pan")
	_check(is_equal_approx(world.camera.zoom.x, fresh_zoom), "Real Leave and new match restore initial fit instead of previous user zoom")
	var reopened: Vector2 = world.camera.position
	world._process(0.5)
	_check(world.camera.position.is_equal_approx(reopened), "A held key from the previous match cannot move the reopened match")
	await _key(KEY_D, false)


func _hud_rects() -> Array[Rect2]:
	var rectangles: Array[Rect2] = [screen.ready_button.get_global_rect(), screen.clear_button.get_global_rect(), screen.leave_button.get_global_rect(), screen.get_node("%Coins").get_global_rect(), screen.send_button.get_global_rect(), screen.enemy_selector.get_global_rect()]
	for button: TowerShopButton in screen.shop_buttons.values():
		rectangles.append(button.get_global_rect())
	return rectangles


func _rects_equal(first: Array[Rect2], second: Array[Rect2]) -> bool:
	if first.size() != second.size():
		return false
	for index: int in range(first.size()):
		if not _rect_equal(first[index], second[index]):
			return false
	return true


func _rect_equal(first: Rect2, second: Rect2) -> bool:
	return first.position.is_equal_approx(second.position) and first.size.is_equal_approx(second.size)


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _settle() -> void:
	await process_frame
	await process_frame


func _click(point: Vector2) -> void:
	await _button(point, true)
	await _button(point, false)


func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = buttons
	root.push_input(event, true)
	await process_frame


func _stroke_press(point: Vector2) -> void:
	_set_mouse_held(true)
	await _button(point, true)


func _stroke_release(point: Vector2) -> void:
	await _button(point, false)
	_set_mouse_held(false)


func _set_mouse_held(pressed: bool) -> void:
	# push_input supplies logical coordinates but does not update Input's held state.
	# Seed that state outside every control; only _button delivers the board press.
	var event := InputEventMouseButton.new()
	event.position = Vector2(-1000, -1000)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _finish(saved_bytes: String) -> void:
	_check(FileAccess.get_file_as_string(save_path) == saved_bytes, "Match interactions leave isolated collection save unchanged")
	main.queue_free()
	await process_frame
	# Let the audio mix thread retire the stopped match playback before exit.
	await create_timer(maxf(0.0, AudioServer.get_time_to_next_mix()) + 0.025).timeout
	_check(DirAccess.remove_absolute(save_path) == OK, "Remove isolated match collection save")
	_check(DirAccess.remove_absolute(directory) == OK, "Remove isolated match collection directory")
	if failures == 0:
		print("PASS: continuous owned world camera, clamps, snapshot isolation, transformed root clicks and drops, fixed HUD, focus/stroke cancellation and leave/reopen")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
