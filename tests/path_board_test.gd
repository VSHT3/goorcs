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
	board.enemy_route = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board.size = Vector2(400, 400)
	board.input_enabled = false
	viewport.add_child(board)
	await process_frame
	board.combat_enemies = [_enemy(1, 1.8, Vector2(1.8, 1))]
	board.set_process(false)
	board.combat_enemies = [_enemy(1, 2.2, Vector2(2, 1.2))]
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
	_check(board.is_processing(), "Undefended enemies animate even without shot traces")
	board.combat_enemies = [_enemy(2, 0.1, Vector2(0.1, 1))]
	_check(board._enemy_position(board.combat_enemies[0]).is_equal_approx(Vector2(0.1, 1)), "A new enemy never inherits another enemy's interpolation")
	board.combat_enemies = []
	_check(not board.is_processing(), "Cleared boards stop animation without retaining removed enemies")
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		for pair: Array in [[Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(2, 1), Vector2i(2, 2)], [Vector2i(1, 1), Vector2i(1, 2)], [Vector2i(3, 3), Vector2i(4, 3)]]:
			var edge: Vector2 = (board.cell_center(pair[0]) + board.cell_center(pair[1])) * 0.5
			# Sample away from the center to check pavement width across the join.
			var offset := Vector2(0, 12) if pair[0].y == pair[1].y else Vector2(12, 0)
			_check(image.get_pixelv(Vector2i(edge + offset)).is_equal_approx(PathBoard.TILE), "Pavement connects across horizontal, vertical, branch and endpoint edges, mirrored=%s" % mirrored)
		var empty: Vector2 = board.cell_center(Vector2i(3, 2))
		_check(image.get_pixelv(Vector2i(empty)).is_equal_approx(PathBoard.GROUND), "Connections do not fill empty ground, mirrored=%s" % mirrored)
	_check_drop_input(board)
	await _check_ranges_and_attacks(board, viewport)
	await _check_typed_enemies(board, viewport)
	await _check_source_facing(board, viewport)
	viewport.queue_free()
	if failures == 0:
		print("PASS: board motion, path junctions, legal owned drops, contextual clicks, tile ranges, attacks and mixed mirrored enemy sprites")
	quit(1 if failures else 0)


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
		for tower_cell: Vector2i in [Vector2i(2, 2), Vector2i.ZERO]:
			board.combat_towers = [_tower(77, tower_cell, "rune_obelisk")]
			board.selected_tower_id = -1
			var baseline: Image = await _board_image(board, viewport)
			board.selected_tower_id = 77
			var highlighted: Image = await _board_image(board, viewport)
			var highlighted_cells: int = 0
			for y: int in range(5):
				for x: int in range(5):
					var cell := Vector2i(x, y)
					if cell == tower_cell:
						continue
					var sample := Vector2i(board.cell_center(cell))
					var changed: bool = not highlighted.get_pixelv(sample).is_equal_approx(baseline.get_pixelv(sample))
					var in_range: bool = maxi(absi(cell.x - tower_cell.x), absi(cell.y - tower_cell.y)) <= 1
					_check(changed == in_range, "Rendered range includes diagonal boundary tiles and excludes every outer tile, mirrored=%s tower=%s cell=%s" % [mirrored, tower_cell, cell])
					if changed:
						highlighted_cells += 1
			_check(highlighted_cells == (8 if tower_cell == Vector2i(2, 2) else 3), "Obelisk highlights exactly its 3x3 footprint clipped to board edges")
		board.selected_tower_id = -1
		var tower: Dictionary = _tower(88, Vector2i(2, 2), "rune_obelisk")
		tower["aim"] = Vector2(4, 2)
		board.combat_towers = [tower]
		var baseline: Image = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		board.combat_towers = [tower]
		board.set_process(false)
		board._process(PathBoard.PULSE_DURATION * 0.5)
		var pulse: Image = await _board_image(board, viewport)
		var center: Vector2 = board.cell_center(Vector2i(2, 2))
		var radius: float = board._cell_size() * 0.75
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_check(_pixels_changed_near(baseline, pulse, center + direction * radius), "Area attacks pulse in every direction, mirrored=%s direction=%s" % [mirrored, direction])
		_check(not _pixels_changed_near(baseline, pulse, board.cell_center(Vector2i(3, 2))), "Obelisk does not draw an ordinary directional shot toward its cosmetic aim")
		board._process(PathBoard.PULSE_DURATION * 0.25)
		var expanded: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(baseline, expanded, center + Vector2.DOWN * board._cell_size() * 1.125), "Area pulse expands over its lifetime")
		board.combat_towers = [tower.duplicate(true)]
		board.set_process(false)
		board._process(PathBoard.PULSE_DURATION * 0.26)
		var expired: Image = await _board_image(board, viewport)
		_check(not _pixels_changed_near(baseline, expired, center + Vector2.DOWN * board._cell_size() * 1.125), "Repeated snapshots cannot restart an already observed area attack")
		board.combat_towers = []
		tower = _tower(89, Vector2i(2, 2), "arrow_tower")
		tower["aim"] = Vector2(4, 2)
		board.combat_towers = [tower]
		baseline = await _board_image(board, viewport)
		tower = tower.duplicate(true)
		tower["shot"] = 1
		board.combat_towers = [tower]
		board.set_process(false)
		board._process(PathBoard.SHOT_DURATION * 0.25)
		var shot: Image = await _board_image(board, viewport)
		_check(_pixels_changed_near(baseline, shot, board.cell_center(Vector2i(3, 2))), "Non-area towers retain their directional shot traces, mirrored=%s" % mirrored)
		_check(not _pixels_changed_near(baseline, shot, center + Vector2.UP * radius), "Ordinary shots do not become area pulses")
		board.combat_towers = []


func _check_typed_enemies(board: PathBoard, viewport: SubViewport) -> void:
	board.combat_towers = []
	board.selected_tower_id = -1
	board.command_mode = false
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.enemy_route = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	for cell: Vector2i in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]:
		board.layout.place(cell)
	var enemies: Array[Dictionary] = [
		_enemy(101, 1.0, Vector2(1, 2)),
		_enemy(102, 2.0, Vector2(2, 2)),
		_enemy(103, 3.0, Vector2(3, 2)),
	]
	enemies[1]["type_id"] = "runner"
	enemies[2]["type_id"] = "brute"
	for enemy: Dictionary in enemies:
		enemy["hp"] = 4
	var normal_geometry: Array[Dictionary] = []
	var normal_centers: Array[Vector2i] = []
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_enemies = []
		var baseline: Image = await _board_image(board, viewport)
		board.combat_enemies = enemies
		var image: Image = await _board_image(board, viewport)
		var geometry: Array[Dictionary] = []
		for enemy: Dictionary in enemies:
			var center := Vector2i(board.cell_center(Vector2i(enemy["pos"])))
			# Exclude the bars, but include the complete opaque body and cell margins.
			var body_top: int = -24 if enemy["type_id"] == "brute" else -20
			var region := Rect2i(center + Vector2i(-40, body_top), Vector2i(80, 40 - body_top))
			var body: Dictionary = _changed_geometry(baseline, image, region)
			geometry.append(body)
			var bounds: Rect2i = body["bounds"]
			_check(int(body["pixels"]) > 100 and bounds.size.x < 80 and bounds.size.y < 80,
				"Each typed body renders nonempty geometry smaller than one cell, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			if not mirrored:
				normal_centers.append(center)
			else:
				var original_center: Vector2i = normal_centers[geometry.size() - 1]
				var original: Dictionary = normal_geometry[geometry.size() - 1]
				var original_bounds: Rect2i = original["bounds"]
				var mirrored_offset: Vector2 = Vector2(bounds.get_center() - center)
				var original_offset: Vector2 = Vector2(original_bounds.get_center() - original_center)
				_check(absi(int(body["pixels"]) - int(original["pixels"])) <= maxi(4, ceili(float(original["pixels"]) / 30.0))
					and absi(bounds.size.x - original_bounds.size.x) <= 1 and absi(bounds.size.y - original_bounds.size.y) <= 1
					and absf(mirrored_offset.x + original_offset.x) <= 2.0 and absf(mirrored_offset.y - original_offset.y) <= 1.0,
					"Mirroring preserves each typed silhouette's footprint and centered alignment, type=%s" % enemy["type_id"])
			var scale: float = 0.84 if enemy["type_id"] == "brute" else 0.70
			var visual_top: float = center.y + (0.10 - scale * 0.5) * 80.0
			var bar_y: int = floori(visual_top - 3.0 - 7.2 * 0.5)
			_check(image.get_pixel(center.x - 12, bar_y).is_equal_approx(PathBoard.ROUTE_LINE)
				and image.get_pixel(center.x + 12, bar_y).is_equal_approx(Color("172120")),
				"Half-health bars remain clear and unflipped above every typed body, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
		_check(int(geometry[2]["pixels"]) > int(geometry[1]["pixels"]) * 1.4,
			"Brute's bulky armored silhouette is visibly larger than Runner, mirrored=%s" % mirrored)
		if not mirrored:
			normal_geometry = geometry
	board.combat_enemies = []
	board.enemy_route = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 1)]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		_check(board._enemy_faces_left(0.5) == mirrored and board._enemy_faces_left(1.5) == mirrored,
			"Facing follows the displayed horizontal leg and remains stable along vertical turns")
		_check(board._enemy_faces_left(2.5) != mirrored,
			"Facing reverses on leftward route segments in either board orientation")


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
	board.enemy_route = [Vector2i(0, 2), Vector2i(1, 2)]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_enemies = []
		var baseline: Image = await _board_image(board, viewport)
		board.combat_enemies = [_enemy(104, 1.0, Vector2(1, 2))]
		var image: Image = await _board_image(board, viewport)
		var center := Vector2i(board.cell_center(Vector2i(1, 2)))
		var geometry: Dictionary = _changed_geometry(baseline, image, Rect2i(center + Vector2i(-40, -20), Vector2i(80, 60)))
		var bounds: Rect2i = geometry["bounds"]
		var offset: int = bounds.get_center().x - center.x
		_check(offset < -8 if mirrored else offset > 8, "Left-authored artwork faces along the route on either board, not backward")
	board._enemy_art["grunt"] = original
	board.combat_enemies = []


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


func _board_image(board: PathBoard, viewport: SubViewport) -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
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
	return {"id": id, "cell": cell, "type_id": type_id, "shot": 0, "aim": Vector2(cell)}


func _enemy(id: int, progress: float, position: Vector2) -> Dictionary:
	return {"id": id, "type_id": "grunt", "speed": 2.0, "progress": progress, "pos": position, "hp": 8, "max_hp": 8}


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
