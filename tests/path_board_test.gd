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
	await _check_archer_advancements(board, viewport)
	await _check_extended_arrow_branches(board, viewport)
	await _check_pierce_attacks(board, viewport)
	await _check_directional_weapons(board, viewport)
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
		_check(board.is_processing(), "Onyx keeps its local orbit active without enemies or attacks")
		var onyx_idle: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(ordinary, onyx_idle, region)["pixels"]) > 10,
			"Idle Onyx has dark orbiting stones rather than a permanent range ring")
		board._process(0.5)
		var onyx_waiting: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(onyx_idle, onyx_waiting, region)["pixels"]) > 25 and board._shot_traces.is_empty(),
			"Onyx stones orbit between snapshots without inventing a damage pulse")
		board.combat_towers = [tower.duplicate(true)]
		var onyx_repeated: Image = await _board_image(board, viewport)
		_check(int(_changed_geometry(onyx_waiting, onyx_repeated, region)["pixels"]) == 0,
			"Repeated snapshots preserve Onyx orbit position")
		var onyx_phase: float = board._boulder_phase
		board.hide()
		board._process(0.3)
		_check(is_equal_approx(board._boulder_phase, onyx_phase) and not board.is_processing(),
			"Hidden Onyx stops processing without resetting its orbit")
		board.show()
		_check(board.is_processing(), "Showing Onyx resumes its orbit without another snapshot")
		board.set_process(false)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		accepted = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1 and board._shot_traces[0]["evolution"] == "onyx_ring",
			"A real Onyx shot counter captures exactly one branch-specific pulse")
		board._process(PathBoard.ONYX_PULSE_DURATION * 0.5)
		var onyx_attack: Image = await _board_image(board, viewport)
		var ring_edge: Vector2 = board._tower_foot(tower["cell"]) + Vector2(-board._cell_size() * 0.775, 0)
		_check(_region_luminance(onyx_attack, ring_edge) < _region_luminance(onyx_idle, ring_edge) - 0.03,
			"Onyx's discrete expanding ring visibly uses dark stone, mirrored=%s" % mirrored)
		_check(_pixels_changed_near(onyx_idle, onyx_attack, board.cell_center(Vector2i(3, 3)))
			and not _pixels_changed_near(onyx_idle, onyx_attack, board.cell_center(Vector2i(4, 4))),
			"Onyx retains readable hit-neighborhood feedback without painting distant ground")
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 1, "Repeated Onyx snapshots cannot duplicate or restart the pulse")
		board._process(PathBoard.ONYX_PULSE_DURATION)
		# Compare at the same orbit angle so movement cannot mask pulse expiry.
		board._boulder_phase = onyx_phase
		var onyx_expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and int(_changed_geometry(onyx_waiting, onyx_expired, region)["pixels"]) == 0,
			"Onyx pulse fully expires while its cosmetic orbit remains")
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
		var second: Dictionary = board._archer_geometry(tower, 1, 1.0)
		var second_rect := Rect2(Vector2(second["pivot"]) - Vector2(16, 24), Vector2(32, 40))
		_check(int(_changed_geometry(ordinary, baseline, Rect2i(second_rect))["pixels"]) > 20,
			"Only the special Arrow tower gains a visibly separate upright archer, mirrored=%s" % mirrored)
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
				"Both independently aimed arrow streams remain visible, mirrored=%s archer=%s" % [mirrored, trace["archer_index"]])
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 2, "Repeated snapshots do not duplicate either arrow stream")
		tower = tower.duplicate(true)
		tower["secondary_shot"] = 2
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 3 and int(board._shot_traces[2]["archer_index"]) == 1,
			"A secondary-only counter advance cannot overwrite or replay the primary stream")
		board._process(PathBoard.SHOT_DURATION)
		_check(board._shot_traces.is_empty(), "Both arrow streams expire without waiting for another snapshot")
		board.combat_towers = []
		tower = _tower(91, Vector2i(2, 3), "orc_ballista")
		tower["special_upgraded"] = true
		tower["evolution"] = "bounce"
		tower["aim"] = Vector2(3, 1)
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
		var captured_position: Vector2 = board._projectile_position(board._shot_traces[0])
		var later: Dictionary = tower.duplicate(true)
		later["aim"] = Vector2(4, 4)
		later["bounce_aim"] = Vector2(4, 0)
		later["bounce_active"] = false
		board.combat_towers = [later]
		repeated = await _board_image(board, viewport)
		_check(board._shot_traces[0]["aim"] == accepted["aim"]
			and board._shot_traces[0]["bounce_aim"] == accepted["bounce_aim"]
			and board._projectile_position(board._shot_traces[0]).is_equal_approx(captured_position)
			and board.combat_towers[0] == later,
			"Later accepted aims cannot redirect an already captured Bounce shot")
		board._process(PathBoard.SHOT_DURATION * 0.49)
		_check(board._shot_traces.size() == 1, "Bounce remains visible until its full two-leg duration")
		board._process(PathBoard.SHOT_DURATION * 0.02)
		var expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and not _pixels_changed_near(baseline, expired, bounce),
			"Bounce expires at its nominal two-leg lifetime without a new combat snapshot")
		board.combat_towers = []
		_check(board._shot_traces.is_empty() and board._seen_shots.is_empty(),
			"Clearing combat resets queued projectile lifetime and both seen counters")
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1, "A fresh combat can reuse a tower ID and shot number without losing its projectile")
		board.combat_towers = []


func _check_archer_advancements(board: PathBoard, viewport: SubViewport) -> void:
	var old_size: Vector2 = board.size
	board.size = Vector2(240, 240) # Actual 48-pixel game cells, not a magnified preview.
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.combat_enemies = []
	board.selected_tower_id = -1
	board.tower_types = {"arrow_tower": {"range": 3.0, "area_attack": false, "special_upgrade": "second_archer",
		"advancements": {"crowd": {"archer_count": 4}, "ember": {"burn_dps": 4.0},
			"blast": {"splash_radius": 0.85}}}}
	var art: TowerReward = board._tower_art["arrow_tower"]
	var original_pixels: PackedByteArray = art.icon_texture.get_image().get_data()
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		var tower: Dictionary = _tower(190, Vector2i(2, 3), "arrow_tower")
		tower["special_upgraded"] = true
		tower["aim"] = Vector2(0, 0)
		tower["secondary_shot"] = 0
		tower["secondary_aim"] = Vector2(1, 0)
		board.combat_towers = [tower]
		var two: Image = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["advancement"] = "crowd"
		tower["extra_archers"] = [
			{"shot": 0, "aim": Vector2(3, 0), "mode": 1, "target_id": -1},
			{"shot": 0, "aim": Vector2(4, 0), "mode": 2, "target_id": -1}]
		board.combat_towers = [tower]
		var four: Image = await _board_image(board, viewport)
		for index: int in range(2, 4):
			var geometry: Dictionary = board._archer_geometry(tower, index, 1.0)
			var head := Rect2(Vector2(geometry["pivot"]) + Vector2(-8, -15) * float(geometry["scale"]),
				Vector2(16, 14) * float(geometry["scale"]))
			_check(int(_changed_geometry(two, four, Rect2i(head.grow(1.0)))["pixels"]) > 4,
				"Each rear archer has a visible native-scale pink head above the roof, mirrored=%s" % mirrored)
		var held_tips: Array[Vector2] = []
		var directions: Array[Vector2] = []
		for index: int in range(4):
			var geometry: Dictionary = board._archer_geometry(tower, index, 1.0)
			var toward: Vector2 = (board._position_center(board._archer_aim(tower, index))
				+ Vector2(0, board._cell_size() * 0.15) - Vector2(geometry["pivot"])).normalized()
			_check(Vector2(geometry["direction"]).dot(toward) > 0.999,
				"Each upright archer faces its own accepted target, mirrored=%s archer=%s" % [mirrored, index])
			held_tips.append(board._tower_muzzle(tower, index))
			directions.append(geometry["direction"])
		var redirected: Dictionary = tower.duplicate(true)
		redirected["extra_archers"][1]["aim"] = Vector2(0, 4)
		board.combat_towers = [redirected]
		var turned: Image = await _board_image(board, viewport)
		var fourth: Dictionary = board._archer_geometry(redirected, 3, 1.0)
		_check(int(_changed_geometry(four, turned,
			Rect2i(Vector2(fourth["pivot"]) - Vector2(18, 20), Vector2(36, 40)))["pixels"]) > 8,
			"A changed fourth accepted aim visibly turns its head and bow without firing")
		for index: int in range(3):
			_check(Vector2(board._archer_geometry(redirected, index, 1.0)["direction"]).is_equal_approx(directions[index]),
				"Turning one shooter cannot redirect another archer's rig")
		var foot: Vector2 = board._tower_foot(tower["cell"])
		var rect: Rect2 = board._sprite_rect(art.icon_texture, art.board_height, art.board_anchor, foot)
		var ground_region := Rect2i(rect.position + Vector2(0, 38) * rect.size / art.icon_texture.get_size(),
			Vector2(rect.size.x, rect.size.y * 0.45))
		_check(int(_changed_geometry(four, turned, ground_region)["pixels"]) == 0,
			"Archer facing never rotates or repaints the tower's stone base")
		board.combat_towers = [tower]
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["aim"] = Vector2(0, 0)
		tower["secondary_shot"] = 1
		tower["extra_archers"][0]["shot"] = 1
		tower["extra_archers"][1]["shot"] = 1
		var accepted: Dictionary = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 4, "Four accepted counters create four actual independent flights")
		var origins: Array[Vector2] = []
		for trace: Dictionary in board._shot_traces:
			var index: int = int(trace["archer_index"])
			var origin: Vector2 = board._projectile_origin(trace)
			_check(origin.is_equal_approx(held_tips[index]) and not origins.has(origin),
				"Each released arrow tip begins exactly at its own previously held arrow tip")
			origins.append(origin)
		board._process(PathBoard.SHOT_DURATION * 0.5)
		var release_pose: Image = await _board_image(board, viewport)
		var age: float = float(board._archer_poses[Vector2i(190, 0)]["age"])
		board._corpse_paused = true
		board._process(0.2)
		_check(float(board._archer_poses[Vector2i(190, 0)]["age"]) == age,
			"Paused Sandbox freezes the draw/release rig as well as its flight")
		board._corpse_paused = false
		var flights: Image = await _board_image(board, viewport)
		for trace: Dictionary in board._shot_traces:
			_check(_pixels_changed_near(four, flights, board._projectile_position(trace)),
				"Every accepted archer stream has a rendered native-scale projectile")
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 4 and is_equal_approx(float(board._shot_traces[3]["life"]), PathBoard.SHOT_DURATION * 0.5),
			"Repeated four-archer snapshots neither duplicate nor restart flights")
		var changed: Dictionary = tower.duplicate(true)
		changed["extra_archers"][1]["shot"] = 2
		changed["extra_archers"][1]["aim"] = Vector2(4, 1)
		board.combat_towers = [changed]
		board.set_process(false)
		_check(board._shot_traces.size() == 5 and board._shot_traces[4]["archer_index"] == 3
			and board._shot_traces[3]["aim"] == accepted["extra_archers"][1]["aim"]
			and board._projectile_origin(board._shot_traces[3]).is_equal_approx(origins[3]),
			"An extra-only counter adds only its flight and never redirects a prior accepted shot")
		board._process(PathBoard.SHOT_DURATION)
		board._corpse_speed = 3.0
		board._process(0.1)
		board._corpse_speed = 1.0
		var drawn_pose: Image = await _board_image(board, viewport)
		var archer_region := Rect2i(Vector2(board._archer_geometry(changed, 0, 1.0)["pivot"]) - Vector2(22, 24), Vector2(44, 44))
		_check(int(_changed_geometry(release_pose, drawn_pose, archer_region)["pixels"]) > 8
			and board._archer_draw_amount(changed, 0) > 0.0,
			"Release recovers into visibly tensioned nocked bows at accepted 3x speed")
		board.combat_towers = []
		_check(board._archer_poses.is_empty() and board._seen_shots.is_empty(),
			"Leaving/resetting combat removes every per-archer pose and counter")
		tower = _tower(191, Vector2i(2, 3), "arrow_tower")
		tower["special_upgraded"] = true
		tower["aim"] = Vector2(0, 0)
		tower["secondary_shot"] = 0
		tower["secondary_aim"] = Vector2(4, 0)
		board.combat_towers = [tower]
		var plain: Image = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["advancement"] = "ember"
		board.combat_towers = [tower]
		_check(board.is_processing(), "Idle held fire arrows request local animation without enemies or shots")
		var fire_idle: Image = await _board_image(board, viewport)
		board._process(0.1)
		var fire_next: Image = await _board_image(board, viewport)
		for index: int in range(2):
			var tip: Vector2 = board._tower_muzzle(tower, index)
			var flame_region := Rect2i(Vector2i(tip) - Vector2i(5, 8), Vector2i(11, 12))
			_check(int(_changed_geometry(plain, fire_idle, flame_region)["pixels"]) > 3
				and int(_changed_geometry(fire_idle, fire_next, flame_region)["pixels"]) > 0,
				"Both held fire arrow tips visibly flicker while idle at native scale")
		var phase: float = board._flame_elapsed
		board.hide()
		board._process(0.2)
		_check(not board.is_processing() and board._flame_elapsed == phase, "Hidden idle fire animation stops without resetting")
		board.show()
		board._corpse_paused = true
		board._process(0.2)
		_check(board._flame_elapsed == phase, "Paused visual state freezes held fire")
		board._corpse_paused = false
		board._corpse_speed = 2.0
		board._process(0.05)
		_check(is_equal_approx(board._flame_elapsed, phase + 0.1), "Held fire uses the board's accepted visual speed")
		board._corpse_speed = 1.0
		fire_idle = await _board_image(board, viewport)
		var fire_tips: Array[Vector2] = [board._tower_muzzle(tower, 0), board._tower_muzzle(tower, 1)]
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["aim"] = Vector2(0, 0)
		tower["secondary_shot"] = 1
		accepted = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		for trace: Dictionary in board._shot_traces:
			_check(board._projectile_origin(trace).is_equal_approx(fire_tips[int(trace["archer_index"])]),
				"Released flames start on the exact previously held fire arrow tip")
		board._process(PathBoard.SHOT_DURATION * 0.5)
		var fire_flight: Image = await _board_image(board, viewport)
		for trace: Dictionary in board._shot_traces:
			var position: Vector2 = board._projectile_position(trace)
			var direction: Vector2 = (board._projectile_destination(trace) - board._projectile_origin(trace)).normalized()
			var tail: Vector2 = position - direction * board._cell_size() * art.projectile_length
			var trail := Rect2i(Vector2i(tail - direction * 8.0) - Vector2i(6, 6), Vector2i(13, 13))
			_check(int(_changed_geometry(fire_idle, fire_flight, trail)["pixels"]) > 2
				and _warm_pixels(fire_flight, Rect2i(Vector2i(position) - Vector2i(16, 16), Vector2i(33, 33))) > 4,
				"Each moving fire arrow carries actual warm flame and trailing ember pixels")
		_check(tower == accepted, "Idle flames and fire trails cannot mutate accepted gameplay")
		board.combat_towers = []
		tower = _tower(192, Vector2i(2, 3), "arrow_tower")
		tower["special_upgraded"] = true
		tower["aim"] = Vector2(0, 0)
		tower["advancement"] = "blast"
		tower["secondary_shot"] = 0
		tower["secondary_aim"] = Vector2(4, 0)
		board.combat_towers = [tower]
		var bomb_idle: Image = await _board_image(board, viewport)
		for index: int in range(2):
			_check(_pixels_changed_near(plain, bomb_idle, board._tower_muzzle(tower, index)),
				"Both held bomb arrows carry dark physical heads rather than recolored shafts")
		var bomb_tips: Array[Vector2] = [board._tower_muzzle(tower, 0), board._tower_muzzle(tower, 1)]
		tower = tower.duplicate(true)
		tower["shot"] = 1
		tower["aim"] = Vector2(0, 0)
		tower["secondary_shot"] = 1
		accepted = tower.duplicate(true)
		board.combat_towers = [tower]
		board.set_process(false)
		for trace: Dictionary in board._shot_traces:
			_check(board._projectile_origin(trace).is_equal_approx(bomb_tips[int(trace["archer_index"])]),
				"Released bombheads start on the exact previously held bomb arrow tip")
		board._process(PathBoard.SHOT_DURATION * 0.5)
		var bomb_flight: Image = await _board_image(board, viewport)
		for trace: Dictionary in board._shot_traces:
			var position: Vector2 = board._projectile_position(trace)
			var head: Vector2 = position
			_check(_dark_pixels(bomb_flight, Rect2i(Vector2i(head) - Vector2i(3, 3), Vector2i(7, 7))) >= 6,
				"Each moving bomb arrow has a readable broad dark bombhead")
		board._process(PathBoard.SHOT_DURATION * 0.5 + PathBoard.BOMB_IMPACT_DURATION * 0.25)
		var impact: Image = await _board_image(board, viewport)
		for trace: Dictionary in board._shot_traces:
			var hit: Vector2 = board._projectile_destination(trace)
			_check(_pixels_changed_near(bomb_idle, impact, hit), "Captured lethal hit positions produce visible bomb puffs without live targets")
			_check(float(trace["splash_radius"]) == 0.85, "Impact radius comes from accepted behavior metadata")
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		_check(board._shot_traces.size() == 2 and tower == accepted, "Repeated bomb snapshots cannot replay impacts or affect gameplay")
		board._process(PathBoard.BOMB_IMPACT_DURATION)
		var expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty(), "Bomb puffs, rings and sparks fully expire")
		for trace: Dictionary in [{"aim": tower["aim"]}, {"aim": tower["secondary_aim"]}]:
			var hit: Vector2 = board._position_center(trace["aim"]) + Vector2(0, board._cell_size() * 0.15)
			_check(not _pixels_changed_near(bomb_idle, expired, hit), "No impact pixels linger after the captured bomb lifetime")
		board.combat_towers = []
	_check(art.icon_texture.get_image().get_data() == original_pixels, "All branches leave original tower PNG pixels unchanged")
	await _check_burning_enemies(board, viewport)
	board.size = old_size


func _check_extended_arrow_branches(board: PathBoard, viewport: SubViewport) -> void:
	var old_size: Vector2 = board.size
	var old_types: Dictionary = board.tower_types
	var advancements: Dictionary = {}
	for definition: TowerDefinition in board.content_catalog.towers:
		if definition.reward.id == &"arrow_tower":
			advancements = definition.advancements
	board.size = Vector2(240, 240)
	board.layout = PathLayout.new(Vector2i(5, 5), 25, Vector2i(0, 2), Vector2i(4, 2))
	board.tower_types = {"arrow_tower": {"range": 4.0, "special_upgrade": "second_archer", "advancements": advancements}}
	board.combat_enemies = []
	var keys: Array[String] = ["fire_arrows", "molotov", "quick_pitch", "flamethrower", "bomb_arrows", "bigger_bombs",
		"anti_orc_grenades", "aom", "aom_speed_1", "aom_speed_2", "four_archers", "eight_archers", "arrow_minigun"]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		var silhouettes: Array[PackedByteArray] = []
		for branch: String in keys:
			board.combat_towers = []
			var config: Dictionary = advancements[branch]
			var weapon: String = config.get("weapon", "arrow")
			var tower: Dictionary = _tower(290, Vector2i(2, 3), "arrow_tower")
			tower.merge({"advancement": branch, "special_upgraded": true, "interval": 0.04 if weapon == "minigun" else 0.8,
				"secondary_shot": 0, "secondary_aim": Vector2(4, 0), "aim": Vector2(4, 1),
				"firing": false, "refuel_remaining": 0.0, "refuel_duration": 6.0, "extra_archers": []}, true)
			for index: int in range(maxi(0, int(config.get("archer_count", 2)) - 2)):
				tower["extra_archers"].append({"shot": 0, "aim": Vector2(index % 5, 0)})
			board.combat_towers = [tower]
			var idle: Image = await _board_image(board, viewport)
			for earlier: PackedByteArray in silhouettes:
				_check(idle.get_data() != earlier, "Every Arrow branch tier has distinct native48px equipment, mirrored=%s branch=%s" % [mirrored, branch])
			silhouettes.append(idle.get_data())
			_save_arrow_capture(idle, branch + ("_left_idle" if mirrored else "_right_idle"))
			if branch == "eight_archers":
				_check(board._archer_poses.size() == 8, "Eight accepted archers own eight independent presentation rigs")
				for index: int in range(4):
					var lower: Vector2 = board._archer_geometry(tower, index, 1.0)["pivot"]
					var upper: Vector2 = board._archer_geometry(tower, index + 4, 1.0)["pivot"]
					_check(lower.y - upper.y > 25.0, "Four upper shooters stand on a separate second floor, mirrored=%s" % mirrored)
			if weapon == "flamethrower":
				tower = tower.duplicate(true)
				tower["firing"] = true
				tower["shot"] = 8 # An unrelated counter cannot manufacture flame arrows.
				board.combat_towers = [tower]
				var firing: Image = await _board_image(board, viewport)
				_check(board._shot_traces.is_empty() and firing.get_data() != idle.get_data(),
					"Accepted continuous fire draws a directional jet and no discrete arrows")
				_save_arrow_capture(firing, branch + ("_left_firing" if mirrored else "_right_firing"))
				board._corpse_paused = true
				board._process(0.20)
				var paused: Image = await _board_image(board, viewport)
				_check(paused.get_data() == firing.get_data(), "Paused flame jet freezes without advancing local gameplay")
				board._corpse_paused = false
				var last_stage: PackedByteArray = firing.get_data()
				for remaining: float in [5.8, 3.0, 0.6]:
					tower = tower.duplicate(true)
					tower["refuel_remaining"] = remaining
					# Refuel must win even if a stale firing flag is also present.
					board.combat_towers = [tower]
					var refueling: Image = await _board_image(board, viewport)
					_check(refueling.get_data() != last_stage and board._shot_traces.is_empty(),
						"Refuel disconnect/exchange/prime stages remain visually distinct with no phantom attacks")
					last_stage = refueling.get_data()
					_save_arrow_capture(refueling, "%s_%s_refuel_%s" % [branch, "left" if mirrored else "right", remaining])
				continue
			tower = tower.duplicate(true)
			tower["shot"] = 4 if weapon == "minigun" else 1
			board.combat_towers = [tower]
			var count: int = board._shot_traces.size()
			_check(count == (4 if weapon == "minigun" else 1), "Accepted counters yield a bounded stream, not simultaneous minigun volleys")
			if weapon == "minigun":
				_check(float(board._shot_traces[0]["life"]) > float(board._shot_traces[3]["life"]),
					"Coalesced minigun snapshots spread arrows along the stream instead of stacking them")
			var trace: Dictionary = board._shot_traces[0]
			var origin: Vector2 = board._projectile_origin(trace)
			var aim: Vector2 = trace["aim"]
			board._process(0.02 if weapon == "minigun" else float(trace["flight_duration"]) * 0.5)
			var flight: Image = await _board_image(board, viewport)
			_save_arrow_capture(flight, branch + ("_left_flight" if mirrored else "_right_flight"))
			if weapon in ["molotov", "grenade"]:
				var linear: Vector2 = origin.lerp(board._projectile_destination(trace), 0.5)
				_check(board._projectile_position(trace).y < linear.y - 5.0, "Thrown physical payload follows a raised arc, not a bow ray")
				_check(trace["weapon"] == weapon, "Payload records retain accepted weapon identity")
			var changed: Dictionary = tower.duplicate(true)
			changed["aim"] = Vector2(0, 4)
			board.combat_towers = [changed]
			_check(board._shot_traces.size() == count and trace["aim"] == aim and board._projectile_origin(trace).is_equal_approx(origin),
				"Snapshot deduplication preserves captured launch origins and lethal-hit destinations")
			if float(config.get("splash_radius", 0.0)) > 0.0:
				board._process(float(trace["flight_duration"]) * 0.5 + float(trace["impact_duration"]) * 0.25)
				var impact: Image = await _board_image(board, viewport)
				_check(impact.get_data() != flight.get_data(), "Molotov flame shatter, grenade shrapnel and rocket blast render at accepted impact")
				_save_arrow_capture(impact, branch + ("_left_impact" if mirrored else "_right_impact"))
			board._process(2.0)
			_check(board._shot_traces.is_empty(), "Every branch retires its bounded shot/effect history")
		board.combat_towers = []
	board.size = old_size
	board.tower_types = old_types


func _save_arrow_capture(image: Image, label: String) -> void:
	var directory: String = OS.get_environment("GORCS_ARROW_CAPTURE_DIR")
	if directory.is_empty():
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	_check(error == OK, "Arrow capture output directory can be created")
	_check(image.get_region(Rect2i(0, 0, 240, 240)).save_png(directory.path_join(label + ".png")) == OK,
		"Arrow native48px smoke capture saves: " + label)


func _check_burning_enemies(board: PathBoard, viewport: SubViewport) -> void:
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		for type_id: String in ["grunt", "skeleorc"]:
			var enemy: Dictionary = _enemy(193, 0.0, Vector2(2, 2), [])
			enemy["type_id"] = type_id
			enemy["age"] = 0.23
			var definition: EnemyDefinition = board._enemy_art[type_id]
			enemy["fire_immune"] = definition.fire_immune
			enemy["ice_immune"] = definition.ice_immune
			board.combat_enemies = [enemy]
			var normal: Image = await _board_image(board, viewport)
			var frame: Texture2D = EnemyVisuals.enemy_texture(definition, enemy)
			var source_pixels: PackedByteArray = frame.get_image().get_data()
			enemy = enemy.duplicate(true)
			enemy["burning"] = true
			enemy["slowed"] = true
			board.combat_enemies = [enemy]
			var burn: Image = await _board_image(board, viewport)
			var local_immunity: bool = definition.fire_immune
			definition.fire_immune = not local_immunity
			board.combat_enemies = [enemy.duplicate(true)]
			var local_changed: Image = await _board_image(board, viewport)
			definition.fire_immune = local_immunity
			_check(local_changed.get_data() == burn.get_data(), "Accepted host immunity, not mutable local resource flags, controls burn rendering")
			var region := Rect2i(Vector2i(board.cell_center(Vector2i(2, 2))) + Vector2i(-35, -80), Vector2i(70, 110))
			if definition.fire_immune:
				_check(normal.get_data() == burn.get_data(), "Immune SkeleOrc never acquires orange/blue status pixels or flames")
				continue
			_check(int(_changed_geometry(normal, burn, region)["pixels"]) > 20
				and _warm_pixels(burn, region) > _warm_pixels(normal, region), "Burning current-frame bodies visibly shift warm red-orange")
			var cached: Texture2D = board._burning_enemy_textures[frame]
			_check(cached == EnemyVisuals.burning_texture(frame)
				and cached.get_image().get_used_rect() == frame.get_image().get_used_rect()
				and frame.get_image().get_data() == source_pixels, "Burn palette is cached per current frame, preserves alpha, and never mutates source art")
			var source: Image = frame.get_image()
			var tinted: Image = cached.get_image()
			var warmth_gain: float = 0.0
			var alpha_preserved: bool = true
			for y: int in range(source.get_height()):
				for x: int in range(source.get_width()):
					var original: Color = source.get_pixel(x, y)
					var orange: Color = tinted.get_pixel(x, y)
					alpha_preserved = alpha_preserved and is_equal_approx(original.a, orange.a)
					if original.a > 0.5:
						warmth_gain += (orange.r - orange.b) - (original.r - original.b)
			_check(alpha_preserved and warmth_gain > 1.0, "The actual cached current-frame palette shifts red-orange while preserving every alpha pixel")
			enemy["slowed"] = false
			board.combat_enemies = [enemy]
			var burn_only: Image = await _board_image(board, viewport)
			_check(burn_only.get_data() == burn.get_data(), "Burn palette has visual priority over Freeze without changing status state")
			var foot: Vector2 = board.cell_center(Vector2i(2, 2)) + Vector2(0, board._cell_size() * 0.28)
			var bounds: Rect2 = board._enemy_sprite_bounds(enemy, foot, 0.0)
			var opaque: int = 0
			for y: int in range(floori(bounds.position.y), ceili(bounds.end.y)):
				for x: int in range(floori(bounds.position.x), ceili(bounds.end.x)):
					if board._enemy_contains_point(enemy, foot, 0.0, Vector2(x, y)):
						opaque += 1
			enemy["burning"] = false
			board.combat_enemies = [enemy]
			var normal_opaque: int = 0
			for y: int in range(floori(bounds.position.y), ceili(bounds.end.y)):
				for x: int in range(floori(bounds.position.x), ceili(bounds.end.x)):
					if board._enemy_contains_point(enemy, foot, 0.0, Vector2(x, y)):
						normal_opaque += 1
			_check(opaque == normal_opaque, "Burn tint/flames leave current-frame alpha picking unchanged")
	board.combat_enemies = []


func _warm_pixels(image: Image, region: Rect2i) -> int:
	var pixels: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r > color.g * 1.35 and color.g > color.b * 1.25 and color.r > 0.45:
				pixels += 1
	return pixels


func _dark_pixels(image: Image, region: Rect2i) -> int:
	var pixels: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.r < 0.15 and color.g < 0.15 and color.b < 0.16:
				pixels += 1
	return pixels


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
		tower["aim"] = Vector2(1, 3)
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
		_check(ray.normalized().is_equal_approx((beyond - origin).normalized())
			and (beyond - origin).length() > (board._position_center(accepted["aim"]) - board.cell_center(accepted["cell"])).length(),
			"Pierce stays on the accepted forward ray after passing the primary target")
		board.combat_towers = [tower.duplicate(true)]
		var repeated: Image = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1 and repeated.get_data() == flight.get_data(),
			"Repeated Pierce snapshots cannot duplicate, bend or restart the captured ray")
		_check(tower == accepted and board.combat_towers[0] == accepted,
			"Capturing and rendering a lethal Pierce shot preserves the accepted tower snapshot")
		var captured_position: Vector2 = board._projectile_position(trace)
		var later: Dictionary = tower.duplicate(true)
		later["aim"] = Vector2(0, 0)
		later["pierce_aim"] = Vector2(0, 0)
		later["pierce_active"] = false
		later["target_id"] = -1
		board.combat_towers = [later]
		repeated = await _board_image(board, viewport)
		_check(trace["aim"] == accepted["aim"] and trace["pierce_aim"] == accepted["pierce_aim"]
			and board._projectile_position(trace).is_equal_approx(captured_position) and board.combat_towers[0] == later,
			"A later snapshot cannot move an accepted Pierce endpoint or require a living target")
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.24)
		var near_end: Image = await _board_image(board, viewport)
		_check(board._shot_traces.size() == 1
			and _pixels_changed_near(baseline, near_end, origin.lerp(endpoint, 0.99)),
			"Pierce remains one visible straight bolt until the full-ray lifetime ends")
		board._process(PathBoard.PIERCE_SHOT_DURATION * 0.02)
		var expired: Image = await _board_image(board, viewport)
		_check(board._shot_traces.is_empty() and not _pixels_changed_near(baseline, expired, endpoint),
			"Pierce expires at its nominal full-ray lifetime without waiting for a snapshot")
		_check(tower == accepted and board.combat_towers[0] == later,
			"Expiring Pierce presentation never mutates either accepted snapshot")
		board.combat_towers = []


func _check_directional_weapons(board: PathBoard, viewport: SubViewport) -> void:
	var original_catalog: ContentCatalog = board.content_catalog
	var original_types: Dictionary = board.tower_types
	var art: TowerReward = board._tower_art["orc_ballista"]
	_check(art.directional_weapon_textures.size() == 8 and art.directional_projectile_origins.size() == 8,
		"Ballista supplies all eight aligned weapon layers and release tips")
	if art.directional_weapon_textures.size() != 8 or art.directional_projectile_origins.size() != 8:
		return
	var catalog := ContentCatalog.new()
	for definition: TowerDefinition in original_catalog.towers:
		if definition.reward == art:
			catalog.towers.append(definition)
	board.content_catalog = catalog
	board.tower_types = {"orc_ballista": {"range": 3.0, "area_attack": false}}
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.selected_tower_id = -1
	board.command_mode = true
	board.combat_enemies = []
	var directions: Array[Vector2] = [Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2.ONE,
		Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		var tower: Dictionary = _tower(182, Vector2i(2, 3), "orc_ballista")
		tower["range"] = 3.0
		board.combat_towers = [tower]
		_check(board._directional_weapon_index(tower) == 3, "Un-aimed Ballista starts SE on either board")
		var foot: Vector2 = board._tower_foot(tower["cell"])
		var rect: Rect2 = board._directional_weapon_rect(art, foot)
		var scale: Vector2 = rect.size / Vector2(192, 192)
		_check((rect.position + Vector2(96, 157) * scale).is_equal_approx(foot),
			"Every directional pose grounds the identical stationary foundation at the tile foot")
		_check(rect.is_equal_approx(board._sprite_rect(art.icon_texture, art.board_height, art.board_anchor, foot)),
			"Directional layers reuse one SE-icon framing rather than resizing per pose")
		var lower_region := Rect2i(rect.position + Vector2(55, 135) * scale, Vector2(85, 22) * scale)
		var weapon_region := Rect2i(rect.position + Vector2(20, 15) * scale, Vector2(152, 110) * scale)
		var first: Image
		var first_lower: PackedByteArray
		for index: int in range(8):
			tower["aim"] = Vector2(tower["cell"]) + directions[index]
			board.combat_towers = [tower]
			var expected: int = posmod(8 - index, 8) if mirrored else index
			_check(board._directional_weapon_index(tower) == expected,
				"Cardinal/diagonal Ballista pose matches displayed direction, mirrored=%s index=%s" % [mirrored, index])
			var tip: Vector2 = rect.position + art.directional_projectile_origins[expected] * scale
			_check(board._tower_muzzle(tower, 0, true).is_equal_approx(tip),
				"Every displayed pose releases at its own authored bolt tip")
			var pose: Image = await _board_image(board, viewport)
			if first == null:
				first = pose
				first_lower = pose.get_region(lower_region).get_data()
			else:
				_check(int(_changed_geometry(first, pose, weapon_region)["pixels"]) > 20,
					"Each cardinal/diagonal weapon pose visibly changes the upper sprite")
				_check(pose.get_region(lower_region).get_data() == first_lower,
					"Turning or mirroring the weapon never rotates, flips, shifts or rescales its lower masonry")
		for sector: int in range(8):
			for side: float in [-0.0001, 0.0001]:
				var angle: float = -PI * 0.5 + float(sector) * PI * 0.25 + PI * 0.125 + side
				var logical := Vector2(cos(angle), sin(angle))
				if mirrored:
					logical.x = -logical.x
				tower["aim"] = Vector2(tower["cell"]) + logical
				_check(board._directional_weapon_index(tower, true) == posmod(sector + (1 if side > 0.0 else 0), 8),
					"Half-sector boundaries select adjacent cardinal/diagonal poses without mirror bias")
		var accepted_aim := Vector2(0, 3)
		tower["aim"] = accepted_aim
		tower["target_id"] = 802
		var route: Array = [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]
		var target: Dictionary = _enemy(802, 0.0, Vector2(2, 0), route)
		var decoy: Dictionary = _enemy(803, 0.0, Vector2(3, 3), [])
		board.combat_enemies = [decoy, target]
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._directional_weapon_index(tower) == 0,
			"Exact accepted target wins over a closer decoy without a new shot")
		target = _enemy(802, 5.0, Vector2(4, 3), route)
		board.combat_enemies = [decoy, target]
		board.set_process(false)
		_check(board._directional_weapon_index(tower) == 0, "A target snapshot cannot snap the directional weapon ahead of interpolation")
		board._process(PathBoard.ENEMY_BLEND_DURATION * 0.5)
		_check(board._directional_weapon_index(tower) == (7 if mirrored else 1),
			"Directional aim follows the accepted target through its interpolated logical route")
		board._process(PathBoard.ENEMY_BLEND_DURATION * 0.5)
		_check(board._directional_weapon_index(tower) == (6 if mirrored else 2)
			and tower["shot"] == 0 and tower["aim"] == accepted_aim,
			"Live target movement rotates only presentation, never host aim or shot state")
		var accepted_index: int = 2 if mirrored else 6
		var released_tip: Vector2 = rect.position + art.directional_projectile_origins[accepted_index] * scale
		tower["shot"] = 1
		board.combat_towers = [tower]
		board.set_process(false)
		_check(board._shot_traces.size() == 1 and board._directional_weapon_index(tower, true) == accepted_index,
			"A moving live target cannot change the host-captured release pose")
		var trace: Dictionary = board._shot_traces[0]
		_check(board._projectile_origin(trace).is_equal_approx(released_tip)
			and board._projectile_position(trace).is_equal_approx(released_tip),
			"The visible bolt begins at the captured pose's exact authored tip")
		for state: String in ["missing", "dead", "out_of_range"]:
			var invalid_target: Dictionary = _enemy(802, 0.0, Vector2(4, 3), [])
			if state == "dead":
				invalid_target["hp"] = 0
			elif state == "out_of_range":
				invalid_target["pos"] = Vector2(20, 3)
			board.combat_enemies = [decoy] if state == "missing" else [decoy, invalid_target]
			board.set_process(false)
			_check(board._directional_weapon_index(tower) == accepted_index,
				"A %s accepted target holds the last host aim instead of selecting a decoy" % state)
		tower["aim"] = Vector2(2, 0)
		board.combat_towers = [tower]
		_check(board._projectile_origin(trace).is_equal_approx(released_tip)
			and board._directional_weapon_index(tower) == 0,
			"Later rotation cannot drag an already released projectile")
		board.combat_towers = []
		board.combat_enemies = []
	var headroom_foot := Vector2(0, board._cell_size() * 0.78)
	var headroom_rect: Rect2 = board._directional_weapon_rect(art, headroom_foot)
	var headroom_scale: Vector2 = headroom_rect.size / Vector2(192, 192)
	var expected_headroom: float = 0.0
	var layers: Array[Texture2D] = [art.icon_texture, art.board_texture]
	layers.append_array(art.directional_weapon_textures)
	for texture: Texture2D in layers:
		var bounds := Rect2(texture.get_image().get_used_rect())
		expected_headroom = maxf(expected_headroom, -(headroom_rect.position.y + bounds.position.y * headroom_scale.y))
	_check(board.visual_headroom() == ceilf(expected_headroom + 6.0),
		"Camera headroom covers every directional weapon and the fixed base at the one icon scale")
	_check(art.directional_weapon_textures[0].get_image().get_used_rect().position.y < art.icon_texture.get_image().get_used_rect().position.y,
		"The regression includes a north pose extending above the SE framing icon")
	board.content_catalog = original_catalog
	board.tower_types = original_types


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
