extends SceneTree

var failures: int = 0
var fixture: Control
var world: MatchWorld
var header: PanelContainer
var management: PanelContainer
var scroll: ScrollContainer
var editor: LineEdit
var selector: OptionButton
var initial_zoom: float
var initial_position: Vector2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	fixture = Control.new()
	fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fixture)
	fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = load("res://scenes/match_world.tscn").instantiate()
	fixture.add_child(world)
	for board: PathBoard in world.boards:
		board.layout = PathLayout.new()
		board.cell_click_mode = true
	world.boards[0].input_enabled = true
	world.boards[1].input_enabled = false
	header = PanelContainer.new()
	header.position = Vector2(14, 6)
	header.size = Vector2(1252, 66)
	fixture.add_child(header)
	selector = OptionButton.new()
	selector.name = "Targeting"
	selector.add_item("Furthest")
	selector.add_item("Closest")
	header.add_child(selector)
	# MatchWorld discovers real root popups in its normal scene. This isolated
	# fixture supplies the same popup owner without inventing an input mock.
	world._hud_popups.append(selector.get_popup())
	management = PanelContainer.new()
	management.position = Vector2(1010, 100)
	management.size = Vector2(250, 270)
	fixture.add_child(management)
	scroll = ScrollContainer.new()
	management.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for index: int in range(24):
		var label := Label.new()
		label.text = "Tower stat %d" % index
		label.custom_minimum_size.y = 32
		rows.add_child(label)
	management.hide()
	editor = LineEdit.new()
	editor.position = Vector2(20, 80)
	editor.size = Vector2(200, 32)
	fixture.add_child(editor)
	editor.hide()
	await _settle()
	world.configure(Vector2i(14, 9), 0)
	world.set_active(true)
	world.set_process(false)
	await _settle()
	initial_zoom = world.camera.zoom.x
	initial_position = world.camera.position
	await _check_growth()
	await _check_four_way_keys()
	await _check_zoom()
	await _check_input_priority()
	await _check_transformed_clicks()
	await _check_lifecycle()
	fixture.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: root WASD and normalized diagonals, anchored bounded wheel/pinch, expanded coordinate invariance, terrain clamps, HUD/focus priority, transformed owned clicks and lifecycle reset")
	quit(1 if failures else 0)


func _check_growth() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 4), Vector2i(13, 4), Vector2i(6, 3)]
	# End on the host so the remaining input-priority checks keep their fixture.
	for own_slot: int in [1, 0]:
		for slot: int in range(2):
			world.boards[slot].layout = PathLayout.new()
			world.boards[slot].input_enabled = slot == own_slot
		world.configure(Vector2i(14, 9), own_slot)
		await _settle()
		var old_positions: Array[Vector2] = []
		var initial_gap: Rect2 = world._terrain._gap
		for slot: int in range(2):
			world.boards[slot].layout.place(cells[2])
			for cell: Vector2i in cells:
				old_positions.append(world.boards[slot].get_global_transform() * world.boards[slot].cell_center(cell))
		world.pan(0.07, Vector2.RIGHT)
		var panned: Vector2 = world.camera.position
		var before_zoom: Vector2 = world.camera.zoom
		for board: PathBoard in world.boards:
			board.layout.grow_for_main_round(6)
		world.configure(Vector2i(15, 11), own_slot, -1)
		await _settle()
		_check(world.camera.zoom.x < before_zoom.x, "Growth reveals the enlarged three-edge board, own slot=%d" % own_slot)
		_check(is_equal_approx(world._fit_zoom, initial_zoom), "Growth retains the original width and height as the manual zoom reference")
		var growth_zoom: Vector2 = world.camera.zoom
		var own_board: PathBoard = world.boards[own_slot]
		_check(is_equal_approx(world.camera.position.x, own_board.position.x + own_board.size.x * 0.5), "Growth framing uses the translated owned-board center, slot=%d" % own_slot)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(14, 0), Vector2i(0, 10), Vector2i(14, 10)]:
			var point: Vector2 = world.cell_screen_position(own_slot, corner)
			_check(point.x >= MatchWorld.SIDE_MARGIN and point.x <= world.size.x - MatchWorld.SIDE_MARGIN and point.y >= MatchWorld.HUD_TOP and point.y <= world.size.y - MatchWorld.HUD_BOTTOM, "All new outer/top/bottom cells are immediately visible, slot=%d cell=%s" % [own_slot, corner])
		for slot: int in range(2):
			for index: int in range(cells.size()):
				var shifted: Vector2i = cells[index] + Vector2i.DOWN
				var actual: Vector2 = world.boards[slot].get_global_transform() * world.boards[slot].cell_center(shifted)
				_check(actual == old_positions[slot * cells.size() + index], "Existing portal/crystal/path cell world position stays exact, slot=%d cell=%s" % [slot, shifted])
		_check(world.boards[0].position == Vector2(-48, -48) and world.boards[1].position == Vector2(768, -48), "Mirrored host grows left and guest grows right without moving inward edges")
		_check(world._terrain._gap.position.x == initial_gap.position.x and world._terrain._gap.end.x == initial_gap.end.x, "Ravine banks remain at the original world x coordinates")
		_check(world.boards[0].position.x + world.boards[0].size.x == initial_gap.position.x and world.boards[1].position.x == initial_gap.end.x, "Both portal-facing board edges stay flush with the fixed central gap")
		var clicks: Array[Vector2i] = []
		var collect := func(cell: Vector2i, _button: MouseButton) -> void: clicks.append(cell)
		own_board.cell_clicked.connect(collect)
		var new_cells: Array[Vector2i] = [Vector2i(14, 5), Vector2i(6, 0), Vector2i(6, 10)]
		for cell: Vector2i in new_cells:
			await _click(world.cell_screen_position(own_slot, cell))
		own_board.cell_clicked.disconnect(collect)
		_check(clicks == new_cells, "Real root clicks on all three added sides emit exact authoritative logical cells, slot=%d" % own_slot)
		world.pan(100.0, Vector2.LEFT)
		var half_width: float = minf(own_board.size.x * 0.5, (world.size.x - MatchWorld.SIDE_MARGIN * 2.0) * 0.5 / world.camera.zoom.x)
		_check(is_equal_approx(world.camera.position.x, -MatchWorld.CELL_SIZE + half_width), "Left camera bound follows the host's new world minimum")
		world.pan(100.0, Vector2.RIGHT)
		_check(is_equal_approx(world.camera.position.x, -MatchWorld.CELL_SIZE + own_board.size.x * 2.0 + MatchWorld.BOARD_GAP - half_width), "Right camera bound follows the guest's new world maximum")
		world.pan(100.0, Vector2.LEFT)
		world.pan(100.0, Vector2.UP)
		_check(is_equal_approx(world.camera.position.y, world.camera_vertical_bounds.x), "Top scrolling clamps on enlarged terrain")
		var top_cell: Vector2 = world.cell_screen_position(0, Vector2i(6, 0))
		_check(top_cell.y >= MatchWorld.HUD_TOP, "Top clamp exposes the added top row below the HUD")
		world.pan(100.0, Vector2.DOWN)
		_check(is_equal_approx(world.camera.position.y, world.camera_vertical_bounds.y), "Bottom scrolling clamps on enlarged terrain")
		var bottom_cell: Vector2 = world.cell_screen_position(0, Vector2i(6, 10))
		_check(bottom_cell.y <= world.size.y - MatchWorld.HUD_BOTTOM, "Bottom clamp exposes the added bottom row above the footer")
		world.camera.position = panned
		world.camera.force_update_scroll()
		world.configure(Vector2i(15, 11), own_slot, -1)
		_check(world.camera.position.is_equal_approx(panned) and world.camera.zoom.is_equal_approx(growth_zoom), "Repeated accepted board configuration preserves camera state")


func _check_four_way_keys() -> void:
	world.zoom_at(1.5, world.get_global_rect().get_center())
	world._process(1.0)
	world.camera.position.y = (world.camera_vertical_bounds.x + world.camera_vertical_bounds.y) * 0.5
	world.camera.force_update_scroll()
	var start: Vector2 = world.camera.position
	await _key(KEY_W, true)
	world._process(0.025)
	await _key(KEY_W, false)
	_check(world.camera.position.y < start.y and is_equal_approx(world.camera.position.x, start.x), "Physical W moves upward without lateral motion")
	await _key(KEY_S, true)
	world._process(0.025)
	await _key(KEY_S, false)
	_check(world.camera.position.is_equal_approx(start), "Physical S smoothly reverses W")
	await _key(KEY_D, true)
	await _key(KEY_S, true)
	world._process(0.025)
	await _key(KEY_D, false)
	await _key(KEY_S, false)
	var diagonal: Vector2 = world.camera.position - start
	_check(diagonal.x > 0.0 and diagonal.y > 0.0 and is_equal_approx(diagonal.x, diagonal.y), "Two held physical keys move diagonally")
	_check(is_equal_approx(diagonal.length(), MatchWorld.PAN_SPEED * (world._fit_zoom / world.camera.zoom.x) * 0.025), "Diagonal movement has the same zoom-scaled speed as cardinal movement")
	world.camera.position = start
	world.camera.force_update_scroll()
	await _key(KEY_W, true)
	await _key(KEY_S, true)
	world._process(0.05)
	_check(world.camera.position.is_equal_approx(start), "Opposing vertical keys cancel")
	await _key(KEY_W, false)
	await _key(KEY_S, false)


func _check_zoom() -> void:
	var anchor: Vector2 = world.cell_screen_position(0, Vector2i(6, 5))
	var anchor_world: Vector2 = _world_point(anchor)
	var start_zoom: float = world.camera.zoom.x
	var start_position: Vector2 = world.camera.position
	world.pan(0.01, Vector2.RIGHT)
	var low_zoom_distance: float = world.camera.position.x - start_position.x
	world.camera.position = start_position
	world.camera.force_update_scroll()
	world.zoom_at(1.2, anchor)
	_check(world.camera.zoom.x == start_zoom, "Zoom input does not jump the camera immediately")
	world._process(1.0 / 60.0)
	_check(world.camera.zoom.x > start_zoom and world.camera.zoom.x < start_zoom * 1.2, "Zoom traverses an intermediate scale on the next frame")
	_check(_world_point(anchor).distance_to(anchor_world) < 0.01, "Cursor anchor stays fixed during the zoom transition")
	world.zoom_at(1.1, anchor)
	for frame: int in range(60):
		world._process(1.0 / 60.0)
	_check(is_equal_approx(world.camera.zoom.x, start_zoom * 1.2 * 1.1), "Rapid inputs accumulate on the zoom destination, not the intermediate scale")
	_check(_world_point(anchor).distance_to(anchor_world) < 0.01, "Cursor anchor stays fixed through zoom completion")
	start_position = world.camera.position
	world.pan(0.01, Vector2.RIGHT)
	var high_zoom_distance: float = world.camera.position.x - start_position.x
	_check(high_zoom_distance < low_zoom_distance and is_equal_approx(high_zoom_distance * world.camera.zoom.x, low_zoom_distance * start_zoom), "Zoomed-in panning covers less world distance at the same screen speed")
	world.camera.position = start_position
	world.camera.force_update_scroll()
	var point: Vector2 = world.cell_screen_position(0, Vector2i(6, 5))
	var before: Vector2 = _world_point(point)
	var previous_zoom: float = world.camera.zoom.x
	await _wheel(point, MOUSE_BUTTON_WHEEL_UP)
	_check(world.camera.zoom.x > previous_zoom, "Root wheel event zooms the actual world")
	_check(_world_point(point).distance_to(before) < 0.01, "Wheel zoom preserves the world point beneath the cursor away from clamps")
	before = _world_point(point)
	var zoom: float = world.camera.zoom.x
	await _magnify(point, 1.15)
	_check(world.camera.zoom.x > zoom and _world_point(point).distance_to(before) < 0.01, "Native magnify gesture zooms around its cursor anchor")
	await _magnify(point, 100.0)
	var maximum: float = world.camera.zoom.x
	await _wheel(point, MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(maximum, world.camera.zoom.x), "Repeated wheel zoom cannot exceed the pinch maximum")
	await _magnify(point, 0.001)
	var minimum: float = world.camera.zoom.x
	await _wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(minimum, world.camera.zoom.x) and minimum > 0.0 and maximum > minimum, "Wheel and pinch share a finite lower zoom bound")
	await _magnify(world.get_global_rect().get_center(), 1.0 / MatchWorld.MIN_ZOOM_RATIO)
	await _wheel(world.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	var ratio: float = world.camera.zoom.x / world._fit_zoom
	root.content_scale_size = Vector2i(1500, 900)
	root.size = Vector2i(1500, 900)
	await _settle()
	_check(is_equal_approx(world.camera.zoom.x / world._fit_zoom, ratio), "Window resize retains the user's zoom ratio")
	root.content_scale_size = Vector2i(640, 900)
	root.size = Vector2i(640, 900)
	await _settle()
	var reference_fit: float = minf((world.size.x - MatchWorld.SIDE_MARGIN * 2.0) / (14.0 * MatchWorld.CELL_SIZE),
		(world.size.y - MatchWorld.HUD_TOP - MatchWorld.HUD_BOTTOM) / (9.0 * MatchWorld.CELL_SIZE + world._headroom))
	_check(is_equal_approx(world._fit_zoom, reference_fit), "A width-limited resize still uses the original 14-column zoom reference after growth")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await _settle()
	var position: Vector2 = world.camera.position
	var retained_zoom: Vector2 = world.camera.zoom
	world.configure(Vector2i(15, 11), 0, -1)
	_check(world.camera.position.is_equal_approx(position) and world.camera.zoom.is_equal_approx(retained_zoom), "Accepted snapshot refresh retains zoom and pan")
	var old_positions: Array[Vector2] = []
	var cells: Array[Vector2i] = [Vector2i(0, 5), Vector2i(13, 5), Vector2i(6, 4)]
	var initial_gap: Rect2 = world._terrain._gap
	for board: PathBoard in world.boards:
		for cell: Vector2i in cells:
			old_positions.append(board.get_global_transform() * board.cell_center(cell))
	for board: PathBoard in world.boards:
		board.layout.grow_for_main_round(6)
	world.configure(Vector2i(16, 13), 0, -2)
	await _settle()
	for slot: int in range(2):
		for index: int in range(cells.size()):
			var actual: Vector2 = world.boards[slot].get_global_transform() * world.boards[slot].cell_center(cells[index] + Vector2i.DOWN)
			_check(actual == old_positions[slot * cells.size() + index], "Repeated three-edge growth keeps both portal/crystal/path world positions exact, slot=%d" % slot)
	_check(world._terrain._gap.position.x == initial_gap.position.x and world._terrain._gap.end.x == initial_gap.end.x, "Later expansion cannot shift the central ravine")
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(15, 0), Vector2i(0, 12), Vector2i(15, 12)]:
		var corner_point: Vector2 = world.cell_screen_position(0, corner)
		_check(corner_point.x >= MatchWorld.SIDE_MARGIN and corner_point.x <= world.size.x - MatchWorld.SIDE_MARGIN and corner_point.y >= MatchWorld.HUD_TOP and corner_point.y <= world.size.y - MatchWorld.HUD_BOTTOM, "Later growth also exposes all three added edges")
	_check(world.camera.zoom.x < retained_zoom.x, "Later growth also frames the complete enlarged playable area")
	var revealed: Vector2 = world.camera.position
	var revealed_zoom: Vector2 = world.camera.zoom
	world.configure(Vector2i(16, 13), 0, -2)
	_check(world.camera.position.is_equal_approx(revealed) and world.camera.zoom.is_equal_approx(revealed_zoom), "Ordinary snapshots do not repeat growth framing")


func _check_input_priority() -> void:
	var zoom: Vector2 = world.camera.zoom
	await _wheel(header.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_check(world.camera.zoom.is_equal_approx(zoom), "Root wheel over the fixed header never zooms gameplay")
	management.show()
	await _settle()
	await _wheel(scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	_check(world.camera.zoom.is_equal_approx(zoom), "Management panel scrolling never zooms gameplay")
	_check(scroll.scroll_vertical > 0, "World input leaves native panel scrolling available; size=%s max=%s value=%s" % [scroll.size, scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().value])
	await _magnify(management.get_global_rect().get_center(), 1.2)
	_check(world.camera.zoom.is_equal_approx(zoom), "Inspector-style overlay takes priority over magnify gestures")
	management.hide()
	selector.show_popup()
	await process_frame
	var position: Vector2 = world.camera.position
	await _wheel(world.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	await _key(KEY_W, true)
	world._process(0.05)
	_check(world.camera.zoom.is_equal_approx(zoom) and world.camera.position.is_equal_approx(position), "Open targeting popup blocks zoom and keyboard panning")
	await _key(KEY_W, false)
	selector.get_popup().hide()
	editor.show()
	editor.grab_focus()
	await _magnify(world.get_global_rect().get_center(), 1.2)
	await _key(KEY_S, true)
	world._process(0.05)
	_check(world.camera.zoom.is_equal_approx(zoom) and world.camera.position.is_equal_approx(position), "Focused typing blocks magnify and physical WASD")
	await _key(KEY_S, false)
	editor.release_focus()
	editor.hide()
	await _key(KEY_W, true)
	world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	world._process(0.2)
	_check(world.camera.position.is_equal_approx(position), "Focus loss cancels held vertical motion without resetting framing")
	await _key(KEY_W, false)


func _check_transformed_clicks() -> void:
	var own_clicks: Array[Vector2i] = []
	var other_clicks: Array[Vector2i] = []
	world.boards[0].cell_clicked.connect(func(cell: Vector2i, _button: MouseButton) -> void: own_clicks.append(cell))
	world.boards[1].cell_clicked.connect(func(cell: Vector2i, _button: MouseButton) -> void: other_clicks.append(cell))
	var cell := Vector2i(6, 6)
	await _wheel(world.cell_screen_position(0, cell), MOUSE_BUTTON_WHEEL_UP)
	await _click(world.cell_screen_position(0, cell))
	_check(own_clicks == [cell], "Actual root click maps to the owned mirrored logical cell after zoom and growth")
	world.pan(100.0, Vector2.RIGHT)
	await _click(world.cell_screen_position(1, cell))
	_check(other_clicks.is_empty(), "Zoomed opponent clicks remain read-only")


func _check_lifecycle() -> void:
	await _key(KEY_S, true)
	var hidden_position: Vector2 = world.camera.position
	fixture.hide()
	await _wheel(world.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	world._process(0.2)
	_check(world.camera.position.is_equal_approx(hidden_position), "Hidden match cancels held movement")
	fixture.show()
	world.set_process(false)
	var resumed: Vector2 = world.camera.position
	world._process(0.2)
	_check(world.camera.position.is_equal_approx(resumed), "Showing cannot revive a key held before hiding")
	await _key(KEY_S, false)
	world.set_active(false)
	world.set_active(true)
	world.set_process(false)
	var grown_center: Vector2 = world.boards[0].position + world.boards[0].size * 0.5
	_check(is_equal_approx(world.camera.position.x, grown_center.x) and is_equal_approx(world.camera.zoom.x, initial_zoom), "Reactivation resets to the translated grown owned side with the original manual fit")
	world.set_active(false)
	for board: PathBoard in world.boards:
		board.layout = PathLayout.new()
	world.configure(Vector2i(14, 9), 0)
	world.set_active(true)
	world.set_process(false)
	_check(world.camera.position.is_equal_approx(initial_position) and is_equal_approx(world.camera.zoom.x, initial_zoom), "New match restores initial own-side focus and fit rather than old zoom/pan")
	world.set_active(false)
	world.configure(Vector2i(14, 9), 1)
	world.set_active(true)
	world.set_process(false)
	var own_center: Vector2 = world.boards[1].position + world.boards[1].size * 0.5
	_check(is_equal_approx(world.camera.position.x, own_center.x), "A new guest match focuses the guest board")


func _world_point(point: Vector2) -> Vector2:
	var local: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * point
	var viewport: SubViewport = world.get_node("Viewport")
	return viewport.get_canvas_transform().affine_inverse() * (local * Vector2(viewport.size) / world.size)


func _wheel(point: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	event.factor = 1.0
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	world._process(1.0)


func _magnify(point: Vector2, factor: float) -> void:
	var event := InputEventMagnifyGesture.new()
	event.position = point
	event.factor = factor
	root.push_input(event, true)
	await process_frame
	world._process(1.0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	# Deliberately use a different logical key: controls follow physical WASD.
	event.keycode = KEY_Z
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
