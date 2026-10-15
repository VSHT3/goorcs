extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Path connections need a graphical renderer. Run without --headless.")
		quit(1)
		return
	var board := PathBoard.new()
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 1), Vector2i(4, 3))
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(1, 2)]:
		board.layout.place(cell)
	var route: Array = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board.size = Vector2(400, 400)
	board.input_enabled = false
	viewport.add_child(board)
	await process_frame
	# Offscreen captures must work even when native-window drawing is suppressed.
	RenderingServer.set_render_loop_enabled(false)
	await _check_endpoint_idle(board, viewport)
	RenderingServer.set_render_loop_enabled(true)
	board.combat_enemies = [_enemy(1, 1.8, Vector2(1.8, 1), route)]
	board.set_process(false)
	board.combat_enemies = [_enemy(1, 2.2, Vector2(2, 1.2), route)]
	board.set_process(false)
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(1.8, 1)), "Receiving a snapshot does not jump the existing enemy")
	board._process(0.025)
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(1.9, 1)), "Enemy moves between snapshots along the incoming segment")
	board._process(0.025)
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(2, 1)), "Interpolation goes through the corner instead of cutting diagonally")
	board._process(0.025)
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(2, 1.1)), "Enemy leaves the corner along the outgoing segment")
	_check(board.combat_enemies[0]["pos"] == Vector2(2, 1.2) and board.combat_enemies[0]["progress"] == 2.2, "Visual movement cannot mutate accepted combat state")
	board._process(0.5)
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(2, 1.2)), "Missing snapshots cannot extrapolate enemies beyond the accepted position")
	board.combat_towers = []
	board.combat_enemies = [_enemy(2, 0.1, Vector2(0.1, 1), route)]
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(0.1, 1)), "A new enemy never inherits another enemy's interpolation")
	board.combat_enemies = []
	board.command_mode = true
	var connected_layout: PathLayout = board.layout
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 1), Vector2i(4, 3))
		var ground: Image = await _board_image(board, viewport)
		board.layout = connected_layout
		var pavement: Image = await _board_image(board, viewport)
		for pair: Array in [[Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(2, 1), Vector2i(2, 2)], [Vector2i(1, 1), Vector2i(1, 2)], [Vector2i(3, 3), Vector2i(4, 3)]]:
			var edge: Vector2 = (board.cell_center(pair[0]) + board.cell_center(pair[1])) * 0.5
			var offset := Vector2(0, 12) if pair[0].y == pair[1].y else Vector2(12, 0)
			_check(_pixels_changed_near(ground, pavement, edge + offset), "Stone pavement covers horizontal, vertical, branch and endpoint joins, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(ground, pavement, board.cell_center(Vector2i(3, 2))),
			"Connecting paths does not pave empty buildable ground, mirrored=%s" % mirrored)
		var gap_region := Rect2i(Vector2i(board.cell_center(Vector2i(3, 2))) - Vector2i(30, 30), Vector2i(60, 60))
		_check(int(_changed_geometry(ground, pavement, gap_region)["pixels"]) == 0,
			"Branch stonework and soil edges leave the whole intervening cell unfilled, mirrored=%s" % mirrored)
	await _check_ground_materials()
	await _check_workshop_materials_and_editing()
	_check_drop_input(board)
	await _check_ranges_and_attacks(board, viewport)
	await _check_rune_evolutions(board, viewport)
	await _check_special_attacks(board, viewport)
	await _check_pierce_attacks(board, viewport)
	await _check_typed_enemies(board, viewport)
	await _check_slowed_enemies(board, viewport)
	await _check_source_facing(board, viewport)
	await _check_split_routes(board, viewport)
	await _check_depth_overlap(board, viewport)
	await _check_contextual_hover(board, viewport)
	viewport.queue_free()
	if failures == 0:
		print("PASS: board motion, path junctions, legal owned drops, contextual clicks, tile ranges, attacks and mixed mirrored enemy sprites")
	quit(1 if failures else 0)


func _check_endpoint_idle(board: PathBoard, viewport: SubViewport) -> void:
	var before: Image = await _board_image(board, viewport, false)
	board.combat_enemies = []
	board.combat_towers = []
	await create_timer(0.24).timeout
	var after: Image = await _board_image(board, viewport, false)
	for endpoint: Vector2i in [board.layout.entrance, board.layout.base]:
		var region := Rect2i(Vector2i(board.cell_center(endpoint)) + Vector2i(-40, -65), Vector2i(80, 110))
		_check(int(_changed_geometry(before, after, region)["pixels"]) > 0,
			"Portal and crystal keep visibly animating on an empty board after combat state clears")
	board.hide()
	await create_timer(0.45).timeout
	board.show()
	var resumed: Image = await _board_image(board, viewport, false)
	_check(resumed.get_data() == after.get_data(), "Hidden boards pause their cosmetic loop instead of advancing or resetting it")
	await create_timer(0.24).timeout
	var advanced: Image = await _board_image(board, viewport, false)
	for endpoint: Vector2i in [board.layout.entrance, board.layout.base]:
		var region := Rect2i(Vector2i(board.cell_center(endpoint)) + Vector2i(-40, -65), Vector2i(80, 110))
		_check(int(_changed_geometry(resumed, advanced, region)["pixels"]) > 0,
			"Returning to a board resumes visible endpoint motion without combat")


func _check_ground_materials() -> void:
	var dimensions := Vector2i(14, 9)
	var board_size := Vector2(dimensions) * 48.0
	var board_gap: float = 96.0
	var scale_factor: float = 548.0 / 469.0
	for width: int in [1000, 1280]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(width, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var map := Node2D.new()
		map.scale = Vector2.ONE * scale_factor
		viewport.add_child(map)
		var terrain := MatchTerrain.new()
		terrain.configure(board_size, board_gap, Rect2(Vector2(-1000, -1000), Vector2(3500, 2500)))
		map.add_child(terrain)
		for mirrored: bool in [false, true]:
			var board := PathBoard.new()
			board.command_mode = true
			board.mirror_horizontal = mirrored
			board.input_enabled = false
			board.layout = PathLayout.new(dimensions, 30, Vector2i(0, 4), Vector2i(13, 4))
			board.size = board_size
			board.position.x = board_size.x + board_gap if mirrored else 0.0
			map.add_child(board)
			map.position = Vector2(width * 0.5, 340.0) - (board.position + board_size * 0.5) * scale_factor
			var empty: Image = await _board_image(board, viewport)
			for edge: Array in [
				[Vector2(14, 110), Vector2(-38, 110)],
				[Vector2(board_size.x - 14, 110), Vector2(board_size.x + 38, 110)],
				[Vector2(400, 14), Vector2(400, -38)],
				[Vector2(400, board_size.y - 14), Vector2(400, board_size.y + 38)]
			]:
				var inside: Vector2 = map.position + (board.position + edge[0]) * scale_factor
				var outside: Vector2 = map.position + (board.position + edge[1]) * scale_factor
				_check(_region_luminance(empty, inside) > _region_luminance(empty, outside) + 0.025,
					"Empty playable footprint stays lighter than scenery at every edge, width=%s mirrored=%s" % [width, mirrored])
			board.layout.place(Vector2i(6, 2))
			var paved: Image = await _board_image(board, viewport)
			var stone: Vector2 = map.position + (board.position + board.cell_center(Vector2i(6, 2))) * scale_factor
			_check(_region_luminance(paved, stone) > _region_luminance(empty, stone) + 0.08,
				"Stone is a third readable material above the buildable field, width=%s mirrored=%s" % [width, mirrored])
			# Scouting the central gap must reveal a ravine, not a paved crossing.
			map.position = Vector2(width * 0.5, 340.0) - Vector2(board_size.x + board_gap * 0.5, board_size.y * 0.5) * scale_factor
			var gap: Image = await _board_image(board, viewport)
			for y: float in [60.0, board_size.y * 0.5, board_size.y - 60.0]:
				var center: Vector2 = map.position + Vector2(board_size.x + board_gap * 0.5, y) * scale_factor
				var bank: Vector2 = map.position + Vector2(board_size.x + board_gap * 0.5 - 110.0, y) * scale_factor
				_check(_region_luminance(gap, center) + 0.025 < _region_luminance(gap, bank),
					"Central crevasse stays dark and uninterrupted through entrance height, width=%s" % width)
			map.remove_child(board)
			board.queue_free()
		viewport.queue_free()
		await process_frame


func _check_workshop_materials_and_editing() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := PathBoard.new()
	board.layout = PathLayout.new(Vector2i(5, 5), 25, Vector2i(0, 2), Vector2i(4, 2))
	board.position = Vector2(40, 40)
	board.size = Vector2(400, 400)
	viewport.add_child(board)
	var commands: Array[Vector2i] = []
	var changes: Array[bool] = []
	var feedback_messages: Array[String] = []
	board.edit_requested.connect(func(cell: Vector2i, _place: bool) -> void: commands.append(cell))
	board.edited.connect(func() -> void: changes.append(true))
	board.feedback.connect(func(message: String) -> void: feedback_messages.append(message))
	var whole := Rect2i(Vector2i.ZERO, viewport.size)
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.command_mode = false
		board.cancel_stroke()
		var workshop: Image = await _board_image(board, viewport)
		board.command_mode = true
		var match_image: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(workshop, match_image, whole)["pixels"]) == 0,
			"Workshop shares match grass patches, external rim, endpoint sprites and shadows, mirrored=%s" % mirrored)
		board.command_mode = false
		var portal: AtlasTexture = board._portal_texture
		var crystal: AtlasTexture = board._crystal_texture
		var transparent := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		transparent.fill(Color.TRANSPARENT)
		var empty_texture := AtlasTexture.new()
		empty_texture.atlas = ImageTexture.create_from_image(transparent)
		empty_texture.region = Rect2(0, 0, 1, 1)
		board._portal_texture = empty_texture
		board._crystal_texture = empty_texture
		var without_art: Image = await _board_image(board, viewport)
		for endpoint: Vector2i in [board.layout.entrance, board.layout.base]:
			var center := Vector2i(board.position + board.cell_center(endpoint))
			var region := Rect2i(center + Vector2i(-40, -65), Vector2i(80, 100))
			_check(int(_changed_geometry(without_art, workshop, region)["pixels"]) > 100,
				"Non-command endpoints draw actual portal/crystal texture silhouettes, mirrored=%s endpoint=%s" % [mirrored, endpoint])
		board._portal_texture = portal
		board._crystal_texture = crystal
		var motion := InputEventMouseMotion.new()
		motion.position = board.cell_center(Vector2i(2, 2))
		board._gui_input(motion)
		var hover: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(workshop, hover, board.position + motion.position + Vector2(37, 0)),
			"Workshop path hover remains visible over shared terrain, mirrored=%s" % mirrored)
		board.cancel_stroke()
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		var before_changes: int = changes.size()
		for y: int in range(5):
			for x: int in range(5):
				var cell := Vector2i(x, y)
				if board.layout.is_endpoint(cell):
					continue
				click.position = board.cell_center(cell)
				board._gui_input(click)
				_check(board.layout.has_path(cell), "Every non-endpoint workshop cell remains locally paintable")
		board.cancel_stroke()
		var paved: Image = await _board_image(board, viewport)
		board.command_mode = true
		var match_paved: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(paved, match_paved, whole)["pixels"]) == 0,
			"Locally painted workshop uses the same stone, soil and connected joins as a match")
		board.command_mode = false
		click.button_index = MOUSE_BUTTON_RIGHT
		for y: int in range(5):
			for x: int in range(5):
				var cell := Vector2i(x, y)
				click.position = board.cell_center(cell)
				board._gui_input(click)
				_check(board.layout.has_path(cell) == board.layout.is_endpoint(cell),
					"Workshop erase removes local pavement but protects endpoint cells")
		board.cancel_stroke()
		var erased: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(workshop, erased, whole)["pixels"]) == 0,
			"Local erasing restores shared grass without damaging endpoint artwork")
		_check(changes.size() == before_changes + 46 and commands.is_empty(),
			"Workshop painting and erasing emits local changes, never authoritative match edit requests")
	_check(feedback_messages.size() == 4, "Protected endpoints provide feedback in both workshop orientations")
	viewport.queue_free()
	await process_frame


func _region_luminance(image: Image, center: Vector2) -> float:
	var total: float = 0.0
	var point := Vector2i(center)
	for y: int in range(point.y - 4, point.y + 4):
		for x: int in range(point.x - 4, point.x + 4):
			total += image.get_pixel(x, y).get_luminance()
	return total / 64.0


func _check_drop_input(board: PathBoard) -> void:
	var drops: Array[Dictionary] = []
	var clicks: Array[Dictionary] = []
	var edits: Array[Vector2i] = []
	board.tower_dropped.connect(func(cell: Vector2i, type_id: StringName) -> void:
		drops.append({"cell": cell, "type_id": type_id}))
	board.cell_clicked.connect(func(cell: Vector2i, button: MouseButton) -> void:
		clicks.append({"cell": cell, "button": button}))
	board.edit_requested.connect(func(cell: Vector2i, _place: bool) -> void: edits.append(cell))
	board.tower_types = {"arrow_tower": {"range": 2.0, "area_attack": false}}
	board.combat_towers = [_tower(1, Vector2i(4, 0), "arrow_tower")]
	board.command_mode = true
	board.size = Vector2(460, 420)
	var payload: Dictionary = {"tower_type": "arrow_tower"}
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.input_enabled = true
		var destination := Vector2i(0, 4)
		var position: Vector2 = board.cell_center(destination)
		_check(board._can_drop_data(position, payload), "An empty owned ground cell accepts native tower payloads, mirrored=%s" % mirrored)
		var before: int = drops.size()
		board._drop_data(position, payload)
		_check(drops.size() == before + 1 and drops.back()["cell"] == destination and drops.back()["type_id"] == &"arrow_tower",
			"A drop emits the authoritative cell and tower type without mirroring the model, mirrored=%s" % mirrored)
		_check(not board.layout.has_path(destination), "Dropping submits a command without changing path state")
		for blocked: Vector2i in [board.layout.entrance, board.layout.base, Vector2i(1, 1), Vector2i(4, 0)]:
			_check(not board._can_drop_data(board.cell_center(blocked), payload), "Endpoints, path and occupied cells reject drops, mirrored=%s cell=%s" % [mirrored, blocked])
			board._drop_data(board.cell_center(blocked), payload)
		var origin: Vector2 = board._board_origin()
		var extent: Vector2 = Vector2(board.layout.dimensions) * board._cell_size()
		for outside: Vector2 in [origin - Vector2(0.5, 0), origin - Vector2(0, 0.5), origin + Vector2(extent.x, 0), origin + Vector2(0, extent.y)]:
			_check(not board._can_drop_data(outside, payload), "Margins and far board boundaries reject drops, mirrored=%s" % mirrored)
			board._drop_data(outside, payload)
		_check(drops.size() == before + 1, "Invalid drop callbacks emit no build commands")
		for invalid: Variant in [null, "arrow_tower", {}, {"tower_type": 3}, {"tower_type": ""}, {"tower_type": "unknown"}]:
			_check(not board._can_drop_data(position, invalid), "Malformed or unsupported tower payloads cannot be dropped")
		board.placement_enabled = false
		_check(not board._can_drop_data(position, payload) and not board._placement_is_legal(destination, "arrow_tower"), "Committed planning blocks drops and legal-placement previews while inspection stays enabled")
		board._drop_data(position, payload)
		_check(drops.size() == before + 1 and board.input_enabled, "Ready placement lock cannot emit a build and does not disable board inspection")
		board.placement_enabled = true
		board.input_enabled = false
		_check(not board._can_drop_data(position, payload), "Opponent and finished-run boards reject tower drops")
		board._drop_data(position, payload)
		_check(drops.size() == before + 1, "A board disabled between drag acceptance and release emits no build command")
		board.input_enabled = true
		board.cell_click_mode = true
		var click := InputEventMouseButton.new()
		click.position = board.cell_center(Vector2i(1, 1))
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = true
		board._gui_input(click)
		_check(clicks.back()["cell"] == Vector2i(1, 1) and clicks.back()["button"] == MOUSE_BUTTON_RIGHT and edits.is_empty() and board.layout.has_path(Vector2i(1, 1)),
			"Placement-mode right-click cancels through cell_clicked without erasing pavement")
		click.position = position
		click.button_index = MOUSE_BUTTON_LEFT
		board._gui_input(click)
		_check(clicks.back()["cell"] == destination and clicks.back()["button"] == MOUSE_BUTTON_LEFT, "Click placement preserves logical coordinates on both orientations")
		board.cell_click_mode = false
		click.position = board.cell_center(Vector2i(4, 0))
		board._gui_input(click)
		_check(clicks.back()["cell"] == Vector2i(4, 0) and edits.is_empty(), "An existing tower remains inspectable without sending a path edit")
		board.cancel_stroke()
	board.input_enabled = false
	board.combat_towers = []
	board.size = Vector2(400, 400)


func _check_ranges_and_attacks(board: PathBoard, viewport: SubViewport) -> void:
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.tower_types = {
		"rune_obelisk": {"range": 1.0, "area_attack": true},
		"arrow_tower": {"range": 2.0, "area_attack": false},
	}
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.selected_tower_id = -1
		var tower: Dictionary = _tower(88, Vector2i(2, 2), "rune_obelisk")
		tower["aim"] = Vector2(4, 2)
		board.combat_towers = [tower]
		var baseline: Image = await _board_image(board, viewport)
		board.selected_tower_id = 88
		var selected: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(baseline, selected, board.cell_center(Vector2i(3, 3))),
			"Selected range includes diagonal tiles in the legal neighborhood, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(baseline, selected, board.cell_center(Vector2i(4, 4))),
			"Selected range does not extend into unrelated ground, mirrored=%s" % mirrored)
		board.selected_tower_id = -1
		tower = tower.duplicate(true)
		tower["shot"] = 1
		board.combat_towers = [tower]
		board.set_process(false)
		board._process(PathBoard.PULSE_DURATION * 0.25)
		var attack: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(baseline, attack, board.cell_center(Vector2i(3, 3))),
			"Rune attacks visibly communicate their affected tile neighborhood, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(baseline, attack, board.cell_center(Vector2i(4, 4))),
			"Rune feedback remains local to its affected neighborhood, mirrored=%s" % mirrored)
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		board._process(PathBoard.PULSE_DURATION)
		var expired: Image = await _board_image(board, viewport)
		_check(not _pixels_changed_near(baseline, expired, board.cell_center(Vector2i(3, 3))),
			"Attack feedback expires and repeated snapshots cannot restart it, mirrored=%s" % mirrored)
		board.combat_towers = []
		tower = _tower(89, Vector2i(2, 2), "arrow_tower")
		tower["aim"] = Vector2(3, 3)
		board.combat_towers = [tower]
		baseline = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		board.combat_towers = [tower]
		board.set_process(false)
		board._process(PathBoard.SHOT_DURATION * 0.25)
		attack = await _board_image(board, viewport)
		var impact: Vector2 = board.cell_center(Vector2i(3, 3)) + Vector2(0, board._cell_size() * 0.15)
		var flight: Vector2 = board._projectile_origin(board._shot_traces[0]).lerp(impact, 0.25)
		_check(_pixels_changed_near(baseline, attack, flight),
			"Arrow attacks draw a small moving projectile along their captured aim, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(baseline, attack, impact),
			"Arrow attacks do not draw an immediate full-length tracer or premature impact, mirrored=%s" % mirrored)
		board.combat_towers = []


func _check_rune_evolutions(board: PathBoard, viewport: SubViewport) -> void:
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.tower_types = {"rune_obelisk": {"range": 1.0, "area_attack": true}}
	board.selected_tower_id = -1
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		board.combat_enemies = []
		var tower: Dictionary = _tower(92, Vector2i(2, 2), "rune_obelisk")
		board.combat_towers = [tower]
		var ordinary: Image = await _board_image(board, viewport)
		var center := Vector2i(board.cell_center(tower["cell"]))
		var region := Rect2i(center + Vector2i(-65, -90), Vector2i(130, 135))
		tower = tower.duplicate(true)
		tower["evolution"] = "boulders"
		tower["special_upgraded"] = true
		board.combat_towers = [tower]
		_check(board.is_processing(), "Boulders keep local animation active even without enemies or shot events")
		var accepted: Dictionary = tower.duplicate(true)
		var orbit_start: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(ordinary, orbit_start, region)["pixels"]) > 25,
			"Boulders visibly add stone silhouettes without replacing Rune art, mirrored=%s" % mirrored)
		board._process(0.27)
		var orbit_moved: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(orbit_start, orbit_moved, region)["pixels"]) > 25,
			"Rendered Boulders move between accepted snapshots, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(orbit_start, orbit_moved, board.cell_center(Vector2i(3, 3))),
			"Boulder motion never paints an unselected permanent neighborhood indicator")
		_check(tower == accepted, "Orbit animation cannot mutate the accepted tower snapshot")
		board.combat_towers = [tower.duplicate(true)]
		var repeated: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(orbit_moved, repeated, region)["pixels"]) == 0,
			"Repeated snapshots neither reset nor jump Boulders' local orbit")
		tower = tower.duplicate(true)
		tower["shot"] = 1
		board.combat_towers = [tower]
		var counter_changed: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and int(_changed_geometry(repeated, counter_changed, region)["pixels"]) == 0,
			"Boulder damage counter changes never create discrete pulses or shimmer")
		var phase_before_freeze: float = board._boulder_phase
		tower = tower.duplicate(true)
		tower["freeze_upgraded"] = true
		board.combat_towers = [tower]
		var icy: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(counter_changed, icy, region)["pixels"]) > 25,
			"Purchased Freeze makes the same orbiting Boulders visibly icy, mirrored=%s" % mirrored)
		_check(is_equal_approx(board._boulder_phase, phase_before_freeze) and board._shot_traces.is_empty(),
			"Freeze's visual indication neither restarts the orbit nor creates a damage pulse")
		board._process(0.19)
		var icy_moved: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(icy, icy_moved, region)["pixels"]) > 25,
			"Icy Boulders retain independent local orbit animation")
		var enemy: Dictionary = _enemy(301, 0.0, Vector2(3, 3), [])
		var enemy_before: Dictionary = enemy.duplicate(true)
		board.combat_enemies = [enemy]
		board._process(0.2)
		board.set_process(false)
		_check(enemy == enemy_before and board.combat_towers[0] == tower,
			"Local evolution animation never applies damage or changes accepted enemy/tower state")
		board.combat_enemies = []
		var phase: float = board._boulder_phase
		board.hide()
		board._process(0.3)
		_check(is_equal_approx(board._boulder_phase, phase) and not board.is_processing(),
			"Hidden boards pause their orbit without resetting phase")
		board.show()
		_check(board.is_processing(), "Showing the board resumes Boulders without another snapshot")
		paused = true
		await create_timer(0.06).timeout
		paused = false
		board.set_process(false)
		_check(is_equal_approx(board._boulder_phase, phase), "Local tree pause freezes the Boulders clock")
		var resumed: Image = await _board_image(board, viewport)
		board._sync_combat_animation()
		await create_timer(0.10).timeout
		var live_motion: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(resumed, live_motion, region)["pixels"]) > 20,
			"Real scene processing keeps Boulders visibly moving without snapshot delivery")
		board.selected_tower_id = 92
		var selected: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(live_motion, selected, board.cell_center(Vector2i(3, 3))),
			"Selected Boulders still expose the true neighborhood independently of their cosmetic orbit")
		board.selected_tower_id = -1
		board.combat_towers = []
		tower = _tower(93, Vector2i(2, 2), "rune_obelisk")
		tower["evolution"] = "onyx_ring"
		tower["special_upgraded"] = true
		board.combat_towers = [tower]
		var onyx_idle: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(ordinary, onyx_idle, region)["pixels"]) > 10,
			"Idle Onyx has a distinct dark stone keystone rather than a permanent range ring")
		board._process(0.5)
		var onyx_waiting: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(onyx_idle, onyx_waiting, region)["pixels"]) == 0 and board._shot_traces.is_empty(),
			"Onyx never pulses merely because local time advances")
		tower = tower.duplicate(true)
		tower["shot"] = 1
		accepted = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1 and board._shot_traces[0]["evolution"] == "onyx_ring",
			"A real Onyx shot counter captures exactly one branch-specific pulse")
		board._process(PathBoard.ONYX_PULSE_DURATION * 0.5)
		var onyx_attack: Image = await _board_image(board, viewport)
		var ring_edge: Vector2 = board.cell_center(tower["cell"]) + Vector2(-board._cell_size() * 0.775, board._cell_size() * 0.28)
		_check(_region_luminance(onyx_attack, ring_edge) < _region_luminance(onyx_idle, ring_edge) - 0.03,
			"Onyx's discrete expanding ring visibly uses dark stone, mirrored=%s" % mirrored)
		_check(_pixels_changed_near(onyx_idle, onyx_attack, board.cell_center(Vector2i(3, 3)))
			and not _pixels_changed_near(onyx_idle, onyx_attack, board.cell_center(Vector2i(4, 4))),
			"Onyx retains readable hit-neighborhood feedback without painting distant ground")
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 1, "Repeated Onyx snapshots cannot duplicate or restart the pulse")
		board._process(PathBoard.ONYX_PULSE_DURATION)
		var onyx_expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and int(_changed_geometry(onyx_idle, onyx_expired, region)["pixels"]) == 0,
			"Onyx ring fully disappears between discrete shots instead of becoming a range indicator")
		_check(tower == accepted and board.combat_towers[0] == accepted,
			"Capturing, rendering and expiring Onyx effects cannot mutate accepted snapshots")
		board.combat_towers = []


func _check_special_attacks(board: PathBoard, viewport: SubViewport) -> void:
	board.combat_enemies = []
	board.selected_tower_id = -1
	board.tower_types = {
		"arrow_tower": {"range": 3.0, "area_attack": false, "special_upgrade": "second_archer"},
		"orc_ballista": {"range": 3.0, "area_attack": false, "evolutions": {
			"pierce": {"title": "Pierce 2", "cost": 300},
			"bounce": {"title": "Bounce 1", "cost": 300},
		}},
	}
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		var tower: Dictionary = _tower(90, Vector2i(2, 3), "arrow_tower")
		board.combat_towers = [tower]
		var ordinary: Image = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["special_upgraded"] = true
		board.combat_towers = [tower]
		var baseline: Image = await _board_image(board, viewport)
		var artwork: TowerReward = board._tower_art["arrow_tower"]
		var foot: Vector2 = board.cell_center(tower["cell"]) + Vector2(0, board._cell_size() * 0.28)
		var rect: Rect2 = board._sprite_rect(artwork.icon_texture, artwork.board_height, artwork.board_anchor, foot)
		var art_scale: Vector2 = rect.size / artwork.icon_texture.get_size()
		var second_rect := Rect2(rect.position + (artwork.secondary_sprite_region.position + artwork.secondary_sprite_offset) * art_scale,
			artwork.secondary_sprite_region.size * art_scale)
		_check(int(_changed_geometry(ordinary, baseline, Rect2i(second_rect.grow(1.0)))["pixels"]) > 20,
			"Only the special Arrow tower gains a visibly separate cropped source archer, mirrored=%s" % mirrored)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["aim"] = Vector2(4, 1)
		tower["secondary_shot"] = 1
		tower["secondary_aim"] = Vector2(0, 1)
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 2, "Primary and secondary events retain separate queued arrows even without living targets")
		board._process(PathBoard.SHOT_DURATION * 0.5)
		var flight: Image = await _board_image(board, viewport)
		for trace: Dictionary in board._shot_traces:
			var destination: Vector2 = board._position_center(trace["aim"]) + Vector2(0, board._cell_size() * 0.15)
			var midpoint: Vector2 = board._projectile_origin(trace).lerp(destination, 0.5)
			_check(_pixels_changed_near(baseline, flight, midpoint),
				"Both independently aimed arrow streams remain visible, mirrored=%s secondary=%s" % [mirrored, trace["secondary"]])
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 2, "Repeated snapshots do not duplicate either arrow stream")
		tower = tower.duplicate(true)
		tower["secondary_shot"] = 2
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 3 and bool(board._shot_traces[2]["secondary"]),
			"A secondary-only counter advance cannot overwrite or replay the primary stream")
		board._process(PathBoard.SHOT_DURATION)
		_check(board._shot_traces.is_empty(), "Both arrow streams expire without waiting for another snapshot")
		board.combat_towers = []
		tower = _tower(91, Vector2i(2, 3), "orc_ballista")
		tower["special_upgraded"] = true
		tower["evolution"] = "bounce"
		board.combat_towers = [tower]
		baseline = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["aim"] = Vector2(3, 1)
		tower["bounce_active"] = true
		tower["bounce_aim"] = Vector2(0, 1)
		var accepted: Dictionary = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		board._process(PathBoard.SHOT_DURATION * 0.5)
		flight = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1, "Ballista bounce uses exactly one queued projectile")
		var primary: Vector2 = board._position_center(tower["aim"]) + Vector2(0, board._cell_size() * 0.15)
		var bounce: Vector2 = board._position_center(tower["bounce_aim"]) + Vector2(0, board._cell_size() * 0.15)
		var first_midpoint: Vector2 = board._projectile_origin(board._shot_traces[0]).lerp(primary, 0.5)
		_check(_pixels_changed_near(baseline, flight, first_midpoint) and not _pixels_changed_near(baseline, flight, primary.lerp(bounce, 0.5)),
			"Ballista flies toward its primary before drawing any bounce leg, mirrored=%s" % mirrored)
		board._process(PathBoard.SHOT_DURATION)
		flight = await _board_image(board, viewport)
		_check(_pixels_changed_near(baseline, flight, primary.lerp(bounce, 0.5)) and not _pixels_changed_near(baseline, flight, first_midpoint),
			"The same Ballista projectile subsequently travels primary-to-bounce, mirrored=%s" % mirrored)
		board.combat_towers = [tower.duplicate(true)]
		var repeated: Image = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1 and repeated.get_data() == flight.get_data(),
			"Repeated Bounce snapshots preserve the single redirected projectile without restarting it")
		_check(tower == accepted and board.combat_towers[0] == accepted,
			"Rendering both Bounce legs after lethal hits does not mutate accepted tower state")
		var later: Dictionary = tower.duplicate(true)
		later["aim"] = Vector2(4, 4)
		later["bounce_aim"] = Vector2(4, 0)
		later["bounce_active"] = false
		board.combat_towers = [later]
		repeated = await _board_image(board, viewport)
		_check(board._shot_traces[0]["aim"] == accepted["aim"]
			and board._shot_traces[0]["bounce_aim"] == accepted["bounce_aim"]
			and repeated.get_data() == flight.get_data() and board.combat_towers[0] == later,
			"Later accepted aims cannot redirect an already captured Bounce shot")
		board._process(PathBoard.SHOT_DURATION * 0.49)
		_check(board._shot_traces.size() == 1, "Bounce remains visible until its full two-leg duration")
		board._process(PathBoard.SHOT_DURATION * 0.02)
		var expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and expired.get_data() == baseline.get_data(),
			"Bounce expires at its nominal two-leg lifetime without a new combat snapshot")
		board.combat_towers = []
		_check(board._shot_traces.is_empty() and board._seen_shots.is_empty(),
			"Clearing combat resets queued projectile lifetime and both seen counters")
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1, "A fresh combat can reuse a tower ID and shot number without losing its projectile")
		board.combat_towers = []


func _check_pierce_attacks(board: PathBoard, viewport: SubViewport) -> void:
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.combat_enemies = []
	board.selected_tower_id = -1
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		var tower: Dictionary = _tower(92, Vector2i(0, 3), "orc_ballista")
		tower["special_upgraded"] = true
		tower["evolution"] = "pierce"
		board.combat_towers = [tower]
		var baseline: Image = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["target_id"] = 901
		tower["aim"] = Vector2(1, 3)
		tower["pierce_active"] = true
		tower["pierce_aim"] = Vector2(3.5, 3)
		# A stale, off-axis endpoint must never become a second Pierce leg.
		tower["bounce_aim"] = Vector2(1, 0)
		var accepted: Dictionary = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1 and bool(board._shot_traces[0]["pierce_active"])
			and not bool(board._shot_traces[0]["bounce_active"]),
			"Pierce captures exactly one straight projectile even when all victims have already died")
		var trace: Dictionary = board._shot_traces[0]
		var origin: Vector2 = board._projectile_origin(trace)
		var endpoint: Vector2 = origin + board._position_center(accepted["pierce_aim"]) - board.cell_center(accepted["cell"])
		var primary: Vector2 = board._position_center(accepted["aim"]) + Vector2(0, board._cell_size() * 0.15)
		var redirected: Vector2 = primary.lerp(board._position_center(tower["bounce_aim"]) + Vector2(0, board._cell_size() * 0.15), 0.5)
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.25)
		var flight: Image = await _board_image(board, viewport)
		_check(board._projectile_position(trace).is_equal_approx(origin.lerp(endpoint, 0.25))
			and _pixels_changed_near(baseline, flight, origin.lerp(endpoint, 0.25))
			and not _pixels_changed_near(baseline, flight, endpoint),
			"Pierce starts as one moving bolt, not a full-length tracer, mirrored=%s" % mirrored)
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.5)
		flight = await _board_image(board, viewport)
		var beyond: Vector2 = origin.lerp(endpoint, 0.75)
		_check(board._projectile_position(trace).is_equal_approx(beyond)
			and _pixels_changed_near(baseline, flight, beyond)
			and not _pixels_changed_near(baseline, flight, origin.lerp(endpoint, 0.25))
			and not _pixels_changed_near(baseline, flight, redirected),
			"The same Pierce bolt continues straight beyond its aimed enemy without bouncing, mirrored=%s" % mirrored)
		var ray: Vector2 = endpoint - origin
		_check(is_zero_approx(ray.cross(beyond - origin))
			and (beyond - origin).length() > (board._position_center(accepted["aim"]) - board.cell_center(accepted["cell"])).length(),
			"Pierce stays on the accepted forward ray after passing the primary target")
		board.combat_towers = [tower.duplicate(true)]
		var repeated: Image = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1 and repeated.get_data() == flight.get_data(),
			"Repeated Pierce snapshots cannot duplicate, bend or restart the captured ray")
		_check(tower == accepted and board.combat_towers[0] == accepted,
			"Capturing and rendering a lethal Pierce shot preserves the accepted tower snapshot")
		var later: Dictionary = tower.duplicate(true)
		later["aim"] = Vector2(0, 0)
		later["pierce_aim"] = Vector2(0, 0)
		later["pierce_active"] = false
		later["target_id"] = -1
		board.combat_towers = [later]
		repeated = await _board_image(board, viewport)
		_check(trace["aim"] == accepted["aim"] and trace["pierce_aim"] == accepted["pierce_aim"]
			and repeated.get_data() == flight.get_data() and board.combat_towers[0] == later,
			"A later snapshot cannot move an accepted Pierce endpoint or require a living target")
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.24)
		var near_end: Image = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1
			and _pixels_changed_near(baseline, near_end, origin.lerp(endpoint, 0.99)),
			"Pierce remains one visible straight bolt until the full-ray lifetime ends")
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.02)
		var expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and expired.get_data() == baseline.get_data(),
			"Pierce expires at its nominal full-ray lifetime without waiting for a snapshot")
		_check(tower == accepted and board.combat_towers[0] == later,
			"Expiring Pierce presentation never mutates either accepted snapshot")
		board.combat_towers = []


func _check_typed_enemies(board: PathBoard, viewport: SubViewport) -> void:
	board.combat_towers = []
	board.selected_tower_id = -1
	board.command_mode = false
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	var route: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	for cell: Vector2i in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]:
		board.layout.place(cell)
	var enemies: Array[Dictionary] = [
		_enemy(101, 1.0, Vector2(1, 2), route),
		_enemy(102, 2.0, Vector2(2, 2), route),
		_enemy(103, 3.0, Vector2(3, 2), route),
	]
	enemies[1]["type_id"] = "runner"
	enemies[2]["type_id"] = "brute"
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		var masses: Array[int] = []
		for enemy: Dictionary in enemies:
			board.combat_enemies = []
			var baseline: Image = await _board_image(board, viewport)
			board.combat_enemies = [enemy]
			var full: Image = await _board_image(board, viewport)
			var center := Vector2i(board.cell_center(Vector2i(enemy["pos"])))
			var region := Rect2i(center + Vector2i(-40, -100), Vector2i(80, 140))
			var body: Dictionary = _changed_geometry(baseline, full, region)
			masses.append(int(body["pixels"]))
			_check(int(body["pixels"]) > 100,
				"Every shipped enemy has a readable nonempty silhouette, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			var stronger: Dictionary = enemy.duplicate(true)
			stronger["hp"] = 16
			stronger["max_hp"] = 16
			board.combat_enemies = [stronger]
			var full_stronger: Image = await _board_image(board, viewport)
			_check(int(_changed_geometry(full, full_stronger, region)["pixels"]) == 0,
				"Full health adds no routine bar clutter regardless of actual maximum HP")
			stronger["hp"] = 8
			board.combat_enemies = [stronger]
			var damaged: Image = await _board_image(board, viewport)
			var health: Dictionary = _changed_geometry(full_stronger, damaged, region)
			var health_bounds: Rect2i = health["bounds"]
			var body_bounds: Rect2i = body["bounds"]
			_check(int(health["pixels"]) > 0 and health_bounds.end.y <= body_bounds.position.y,
				"Damage reveals health information above the opaque body without repainting it, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			_check(health_bounds.size.x <= ceili(board._cell_size() * 0.38) + 1 and health_bounds.size.y <= 4,
				"Damaged shipped enemies use compact body-sized bars instead of the old wide health billboards")
		_check(masses[2] > masses[1], "Brute has more visible mass than Runner on either board")
	board.combat_enemies = []
	var turning_route: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 1)]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		_check(board._enemy_faces_left(turning_route, 0.5) == mirrored and board._enemy_faces_left(turning_route, 1.5) == mirrored,
			"Facing follows the displayed horizontal leg and remains stable along vertical turns")
		_check(board._enemy_faces_left(turning_route, 2.5) != mirrored,
			"Facing reverses on leftward route segments in either board orientation")


func _check_slowed_enemies(board: PathBoard, viewport: SubViewport) -> void:
	board.combat_towers = []
	board.combat_enemies = []
	board.selected_enemy_id = -1
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		for type_id: String in ["grunt", "runner", "brute"]:
			var enemy: Dictionary = _enemy(501, 0.0, Vector2(2, 2), [])
			enemy["type_id"] = type_id
			board.combat_enemies = []
			var empty: Image = await _board_image(board, viewport)
			board.combat_enemies = [enemy]
			var ordinary: Image = await _board_image(board, viewport)
			var center := Vector2i(board.cell_center(Vector2i(2, 2)))
			var region := Rect2i(center + Vector2i(-40, -100), Vector2i(80, 140))
			var original_body: Dictionary = _changed_geometry(empty, ordinary, region)
			var texture: Texture2D = EnemyVisuals.enemy_texture(board._enemy_art[type_id], enemy)
			var cached: Texture2D = board._slowed_enemy_textures[texture]
			enemy = enemy.duplicate(true)
			enemy["slowed"] = true
			enemy["slow_remaining"] = 2.0
			enemy["speed"] = 1.6
			var accepted: Dictionary = enemy.duplicate(true)
			board.combat_enemies = [enemy]
			var slowed: Image = await _board_image(board, viewport)
			var slowed_body: Dictionary = _changed_geometry(empty, slowed, region)
			_check(int(_changed_geometry(ordinary, slowed, region)["pixels"]) > 25,
				"Slowed enemy gains a visible restrained blue tint, type=%s mirrored=%s" % [type_id, mirrored])
			_check(original_body["bounds"] == slowed_body["bounds"],
				"Slow tint preserves the original sprite silhouette, scale and facing")
			var normal_pixels: Image = texture.get_image()
			var blue_pixels: Image = cached.get_image()
			var blue_gain: float = 0.0
			for y: int in range(normal_pixels.get_height()):
				for x: int in range(normal_pixels.get_width()):
					var normal: Color = normal_pixels.get_pixel(x, y)
					var blue: Color = blue_pixels.get_pixel(x, y)
					if normal.a > 0.5:
						blue_gain += (blue.b - blue.r) - (normal.b - normal.r)
			_check(blue_gain > 1.0, "The cached slow palette shifts toward blue rather than merely darkening the sprite")
			board.combat_enemies = [enemy.duplicate(true)]
			var repeated: Image = await _board_image(board, viewport)
			_check(board._slowed_enemy_textures[texture] == cached and repeated.get_data() == slowed.get_data() and enemy == accepted,
				"Repeated slow snapshots reuse the same texture without changing accepted state or local visuals")
			enemy = enemy.duplicate(true)
			enemy["slowed"] = false
			enemy["slow_remaining"] = 0.0
			enemy["speed"] = enemy["base_speed"]
			board.combat_enemies = [enemy]
			var expired: Image = await _board_image(board, viewport)
			_check(expired.get_data() == ordinary.get_data(), "An accepted expiry restores the original sprite without lingering blue")
	board.combat_enemies = []


func _check_source_facing(board: PathBoard, viewport: SubViewport) -> void:
	# An asymmetric marker makes facing observable without pinning sprite pixels.
	var marker := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	marker.fill(Color.TRANSPARENT)
	marker.fill_rect(Rect2i(0, 1, 3, 6), Color.MAGENTA)
	var artwork := EnemyDefinition.new()
	artwork.texture = ImageTexture.create_from_image(marker)
	artwork.source_faces_left = true
	var original: EnemyDefinition = board._enemy_art["grunt"]
	board._enemy_art["grunt"] = artwork
	var route: Array = [Vector2i(0, 2), Vector2i(1, 2)]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_enemies = []
		var baseline: Image = await _board_image(board, viewport)
		board.combat_enemies = [_enemy(104, 1.0, Vector2(1, 2), route)]
		var image: Image = await _board_image(board, viewport)
		var enemy: Dictionary = board.combat_enemies[0]
		var foot: Vector2 = board._position_center(board._enemy_visual_position(enemy)) + Vector2(0,board._cell_size()*0.28)
		var rect: Rect2 = board._sprite_rect(artwork.texture,artwork.board_height,artwork.board_anchor,foot,mirrored != artwork.source_faces_left)
		var region := Rect2i(Vector2i(rect.position)-Vector2i.ONE,Vector2i(rect.size)+Vector2i(2,2))
		var geometry: Dictionary = _changed_geometry(baseline,image,region)
		var bounds: Rect2i = geometry["bounds"]
		var offset: float = bounds.get_center().x - rect.get_center().x
		_check(offset < 0 if mirrored else offset > 0, "Left-authored artwork faces along the route on either board, not backward")
	board._enemy_art["grunt"] = original
	board.combat_enemies = []


func _check_split_routes(board: PathBoard, viewport: SubViewport) -> void:
	var upper: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2)]
	var lower: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2)]
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	for route: Array in [upper, lower]:
		for index: int in range(1, route.size() - 1):
			board.layout.place(route[index])
	board.command_mode = false
	board.combat_towers = []
	board.enemy_inspection_enabled = true
	var clicked: Array[int] = []
	var on_click: Callable = func(id: int) -> void: clicked.append(id)
	board.enemy_clicked.connect(on_click)
	var marker := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	marker.fill(Color.CYAN)
	marker.fill_rect(Rect2i(0, 0, 2, 8), Color.MAGENTA)
	var artwork := EnemyDefinition.new()
	artwork.texture = ImageTexture.create_from_image(marker)
	artwork.board_height = 0.45
	artwork.board_anchor = Vector2(0.5, 1.0)
	artwork.source_faces_left = true
	var original: EnemyDefinition = board._enemy_art["grunt"]
	board._enemy_art["grunt"] = artwork
	board._cache_texture_bounds(artwork.texture)
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.selected_enemy_id = -1
		board.combat_enemies = []
		var ground: Image = await _board_image(board, viewport)
		board.combat_enemies = [
			_enemy(301, 1.8, Vector2(1, 1.2), upper),
			_enemy(302, 1.8, Vector2(1, 2.8), lower),
		]
		board.set_process(false)
		board._process(PathBoard.ENEMY_BLEND_DURATION)
		board.combat_enemies = [
			_enemy(301, 2.2, Vector2(1.2, 1), upper),
			_enemy(302, 2.2, Vector2(1.2, 3), lower),
		]
		board.set_process(false)
		var steps: Array = [
			[Vector2(1, 1.1), Vector2(1, 2.9)],
			[Vector2(1, 1), Vector2(1, 3)],
			[Vector2(1.1, 1), Vector2(1.1, 3)],
		]
		for expected: Array in steps:
			board._process(PathBoard.ENEMY_BLEND_DURATION * 0.25)
			var image: Image = await _board_image(board, viewport)
			for index: int in range(2):
				var enemy: Dictionary = board.combat_enemies[index]
				var center: Vector2 = board._position_center(board._enemy_visual_position(enemy))
				var foot: Vector2 = center + Vector2(0, board._cell_size() * 0.28)
				var rect := Rect2(foot - Vector2(18, 36), Vector2(36, 36))
				var region := Rect2i(rect.grow(4))
				var geometry: Dictionary = _changed_geometry(ground, image, region)
				var bounds: Rect2i = geometry["bounds"]
				_check(int(geometry["pixels"]) > 900
					and absf(bounds.position.x - rect.position.x) < 2.0
					and absf(bounds.position.y - rect.position.y) < 2.0,
					"Rendered same-type instance follows its own branch through the corner, mirrored=%s id=%s" % [mirrored, enemy["id"]])
				_check(board._enemy_position(enemy).is_equal_approx(expected[index]),
					"Split interpolation turns at the route cell instead of taking a diagonal chord")
				var marker_point: Vector2 = rect.position + Vector2(4 if mirrored else 32, 12)
				_check(image.get_pixelv(Vector2i(marker_point)).is_equal_approx(Color.MAGENTA),
					"Source-facing marker follows each branch's horizontal heading through its vertical corner in both orientations")
				_check(board.enemy_at(rect.get_center()) == int(enemy["id"]),
					"Hit bounds follow the displayed split-route instance")
		var unselected: Image = await _board_image(board, viewport)
		for index: int in range(2):
			var enemy: Dictionary = board.combat_enemies[index]
			var foot: Vector2 = board._position_center(board._enemy_visual_position(enemy)) + Vector2(0, board._cell_size() * 0.28)
			var click := InputEventMouseButton.new()
			click.position = foot - Vector2(0, 18)
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			board._gui_input(click)
			_check(not clicked.is_empty() and clicked.back() == int(enemy["id"]),
				"Click selects only the actual same-type instance on its displayed branch")
			board.selected_enemy_id = int(enemy["id"])
			var highlighted: Image = await _board_image(board, viewport)
			for branch: int in range(2):
				var branch_foot: Vector2 = board._position_center(board._enemy_visual_position(board.combat_enemies[branch])) + Vector2(0, board._cell_size() * 0.28)
				var region := Rect2i(Rect2(branch_foot - Vector2(18, 36), Vector2(36, 36)).grow(6))
				var pixels: int = int(_changed_geometry(unselected, highlighted, region)["pixels"])
				_check(pixels > 0 if branch == index else pixels == 0,
					"Rendered highlight follows only the selected split-route ID, mirrored=%s selected=%s branch=%s" % [mirrored, index, branch])
	board.enemy_clicked.disconnect(on_click)
	board.enemy_inspection_enabled = false
	board.selected_enemy_id = -1
	board.combat_enemies = []
	board._enemy_art["grunt"] = original


func _check_depth_overlap(board: PathBoard, viewport: SubViewport) -> void:
	# Solid test sprites make visual occlusion observable independent of production art.
	var tower_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	tower_image.fill(Color.MAGENTA)
	var enemy_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	enemy_image.fill(Color.CYAN)
	var tower_art := TowerReward.new()
	tower_art.icon_texture = ImageTexture.create_from_image(tower_image)
	tower_art.board_height = 1.2
	tower_art.board_anchor = Vector2(0.5, 0.9)
	var enemy_art := EnemyDefinition.new()
	enemy_art.texture = ImageTexture.create_from_image(enemy_image)
	enemy_art.board_height = 1.2
	enemy_art.board_anchor = Vector2(0.5, 0.9)
	var original_tower: TowerReward = board._tower_art["arrow_tower"]
	var original_enemy: EnemyDefinition = board._enemy_art["grunt"]
	board._tower_art["arrow_tower"] = tower_art
	board._enemy_art["grunt"] = enemy_art
	board.command_mode = true
	board.selected_tower_id = -1
	var tower: Dictionary = _tower(201, Vector2i(2, 2), "arrow_tower")
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		var sample := Vector2i(board.cell_center(Vector2i(2, 2)) + Vector2(0, -board._cell_size() * 0.2))
		board.combat_enemies = []
		board.combat_towers = [tower]
		var tower_only: Image = await _board_image(board, viewport)
		var front: Dictionary = _enemy(202, 0.0, Vector2(2, 2.4), [])
		board.combat_towers = []
		board.combat_enemies = [front]
		var enemy_only: Image = await _board_image(board, viewport)
		board.combat_towers = [tower]
		var front_overlap: Image = await _board_image(board, viewport)
		_check(front_overlap.get_pixelv(sample).is_equal_approx(enemy_only.get_pixelv(sample))
			and not front_overlap.get_pixelv(sample).is_equal_approx(tower_only.get_pixelv(sample)),
			"An enemy whose feet are in front occludes the tower rather than inheriting type draw order")
		board.combat_enemies = [_enemy(202, 0.0, Vector2(2, 1.6), [])]
		var rear_overlap: Image = await _board_image(board, viewport)
		_check(rear_overlap.get_pixelv(sample).is_equal_approx(tower_only.get_pixelv(sample)),
			"The same moving enemy passes behind a tower when its feet are farther back")
	board._tower_art["arrow_tower"] = original_tower
	board._enemy_art["grunt"] = original_enemy
	board.combat_towers = []
	board.combat_enemies = []


func _check_contextual_hover(board: PathBoard, viewport: SubViewport) -> void:
	board.command_mode = true
	board.cell_click_mode = true
	board.combat_towers = []
	board.combat_enemies = []
	board.selected_tower_id = -1
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.tower_types = {"arrow_tower": {"range": 2.0, "area_attack": false}}
	board.input_enabled = true
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.cancel_stroke()
		board.placement_id = &""
		var idle: Image = await _board_image(board, viewport)
		var cell := Vector2i(2, 3)
		var motion := InputEventMouseMotion.new()
		motion.position = board.cell_center(cell)
		board._gui_input(motion)
		var hover: Image = await _board_image(board, viewport)
		var region := Rect2i(Vector2i(board.cell_center(cell)) - Vector2i(40, 40), Vector2i(80, 80))
		_check(int(_changed_geometry(idle, hover, region)["pixels"]) == 0,
			"Idle combat inspection has no hover square")
		board.placement_id = &"arrow_tower"
		var legal: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(idle, legal, region)["pixels"]) > 0,
			"Explicit tower placement visibly marks legal ground")
		board.layout.place(cell)
		var illegal: Image = await _board_image(board, viewport)
		board.placement_id = &""
		var paved: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(paved, illegal, region)["pixels"]) > 0
			and int(_changed_geometry(legal, illegal, region)["pixels"]) > 0,
			"Placement over pavement provides distinct illegal feedback")
		board.layout.erase(cell)
		board.cancel_stroke()
		board.cell_click_mode = false
		idle = await _board_image(board, viewport)
		board._gui_input(motion)
		var planning_hover: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(idle, planning_hover, region)["pixels"]) > 0,
			"Planning path editing retains discoverable hover feedback")
		board.cell_click_mode = true
		board.input_enabled = false
		var denied: Image = await _board_image(board, viewport)
		board.placement_id = &"arrow_tower"
		var opponent: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(denied, opponent, region)["pixels"]) == 0,
			"Read-only boards never display owned placement feedback")
		board.placement_id = &""
		board.input_enabled = true
	board.cancel_stroke()
	board.input_enabled = false


func _changed_geometry(before: Image, after: Image, region: Rect2i) -> Dictionary:
	var minimum: Vector2i = region.end
	var maximum: Vector2i = region.position - Vector2i.ONE
	var pixels: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if before.get_pixel(x, y).is_equal_approx(after.get_pixel(x, y)):
				continue
			pixels += 1
			minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
			maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
	return {"pixels": pixels, "bounds": Rect2i(minimum, maximum - minimum + Vector2i.ONE)}


func _board_image(board: PathBoard, viewport: SubViewport, freeze_idle: bool = true) -> Image:
	board.set_process(false)
	# Static material/geometry comparisons must not straddle a cosmetic frame tick.
	if freeze_idle:
		board._endpoint_timer.paused = true
	board.queue_redraw()
	await process_frame
	# Native frame_post_draw can stop indefinitely while the macOS window is
	# minimized/occluded. Flush queued canvas updates, then draw the offscreen
	# UPDATE_ALWAYS viewport explicitly without presenting a native window.
	RenderingServer.call_deferred("force_draw", false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _pixels_changed_near(before: Image, after: Image, position: Vector2) -> bool:
	var center := Vector2i(position)
	for y: int in range(center.y - 2, center.y + 3):
		for x: int in range(center.x - 2, center.x + 3):
			if not before.get_pixel(x, y).is_equal_approx(after.get_pixel(x, y)):
				return true
	return false


func _tower(id: int, cell: Vector2i, type_id: String) -> Dictionary:
	return {"id": id, "cell": cell, "type_id": type_id, "evolution": "", "freeze_upgraded": false,
		"shot": 0, "aim": Vector2(cell), "pierce_active": false, "pierce_aim": Vector2(cell),
		"bounce_active": false, "bounce_aim": Vector2(cell)}


func _enemy(id: int, progress: float, position: Vector2, route: Array) -> Dictionary:
	# Empty routes are explicit position-only fixtures, never a board-wide route.
	return {"id": id, "type_id": "grunt", "base_speed": 2.0, "speed": 2.0, "slowed": false, "slow_remaining": 0.0, "progress": progress, "pos": position, "hp": 8, "max_hp": 8, "route": route}


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
