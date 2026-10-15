extends SceneTree

var failures: int = 0
var board: PathBoard
var viewport: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Horde presentation needs a graphical renderer. Run without --headless.")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = PathBoard.new()
	board.size = Vector2(400, 400)
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.input_enabled = false
	board.command_mode = true
	board.enemy_inspection_enabled = true
	viewport.add_child(board)
	await process_frame
	await _check_spread()
	viewport.queue_free()
	if failures == 0:
		print("PASS: shipped small mixed horde silhouettes, stable route-normal spread, mirrored corners, isolated input/highlight and immutable snapshots")
	quit(1 if failures else 0)


func _check_spread() -> void:
	var route: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	for cell: Vector2i in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]:
		board.layout.place(cell)
	var low: Dictionary = _enemy(1, 1.4, route)
	var high: Dictionary = low.duplicate(true)
	for id: int in range(2, 65):
		var candidate: Dictionary = _enemy(id, 1.4, route)
		if board._enemy_visual_position(candidate).y < board._enemy_visual_position(low).y:
			low = candidate
		if board._enemy_visual_position(candidate).y > board._enemy_visual_position(high).y:
			high = candidate
	_check(board._enemy_visual_position(low).y < 1.94 and board._enemy_visual_position(high).y > 2.06,
		"Live IDs occupy both sides of the route within the shipped cosmetic spread")
	var coincident: Dictionary = high.duplicate(true)
	var enemies: Array[Dictionary] = [low, _enemy(int(high["id"]), 1.55, route), _enemy(900, 2.05, route)]
	enemies[1]["type_id"] = "runner"
	enemies[2]["type_id"] = "brute"
	var source: Array = enemies.duplicate(true)
	var clicked: Array[int] = []
	var on_click: Callable = func(id: int) -> void: clicked.append(id)
	board.enemy_clicked.connect(on_click)
	var normal_feet: Array[Vector2] = []
	var whole := Rect2i(Vector2i.ZERO, viewport.size)
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.selected_enemy_id = -1
		board.combat_enemies = []
		var ground: Image = await _image()
		board.combat_enemies = [low]
		var first_silhouette: Image = await _image()
		board.combat_enemies = [coincident]
		var second_silhouette: Image = await _image()
		_check(int(_changed_geometry(first_silhouette, second_silhouette, whole)["pixels"]) > 50,
			"Same-position shipped Grunts have distinct stable silhouettes rather than a shared centerline, mirrored=%s" % mirrored)
		board.combat_enemies = enemies.duplicate(true)
		board._process(PathBoard.ENEMY_BLEND_DURATION)
		var mixed: Image = await _image()
		var accepted: Array = board.combat_enemies.duplicate(true)
		var feet: Array[Vector2] = []
		var bounds: Array[Rect2] = []
		var heights: Array[float] = [0.50, 0.45, 0.70]
		for index: int in range(board.combat_enemies.size()):
			var enemy: Dictionary = board.combat_enemies[index]
			var visual: Vector2 = board._enemy_visual_position(enemy)
			var center: Vector2 = board._enemy_position(enemy)
			var foot: Vector2 = _foot(enemy)
			feet.append(foot)
			var rect: Rect2 = board._enemy_sprite_bounds(enemy, foot, board._enemy_route_progress(enemy))
			bounds.append(rect)
			_check(is_equal_approx(rect.size.y, board._cell_size() * heights[index]),
				"Regression uses actual smaller shipped body height, type=%s" % enemy["type_id"])
			_check(absf(visual.x - center.x) < 0.00001 and absf(visual.y - center.y) <= 0.10001,
				"Straight-route spread is bounded and purely sideways, never authoritative travel")
			_check(int(_changed_geometry(ground, mixed, Rect2i(rect.grow(2)))["pixels"]) > 30,
				"Adjacent mixed shipped body is actually rendered, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			if mirrored:
				_check(foot.is_equal_approx(Vector2(board.size.x - normal_feet[index].x, normal_feet[index].y)),
					"Mirroring reflects the same stable world offset, not a new random lane")
			for item: Dictionary in board._draw_order:
				if int(item["kind"]) == 2 and int(item["data"]["id"]) == int(enemy["id"]):
					_check(Vector2(item["foot"]).is_equal_approx(foot), "Sprite, shadow and depth order share the spread visual foot")
		if not mirrored:
			normal_feet = feet
		_check(bounds[0].intersects(bounds[1]) or bounds[1].intersects(bounds[2]),
			"Regression exercises overlapping mixed bodies, not only separated easy targets")
		_check_hit_pixels(bounds, mirrored)
		for index: int in range(board.combat_enemies.size()):
			var enemy: Dictionary = board.combat_enemies[index]
			var point: Vector2 = _visible_enemy_point(enemy, bounds[index])
			_check(point.x >= 0.0, "Each overlapping shipped instance retains a visible independently clickable body")
			if point.x < 0.0:
				continue
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			board._gui_input(click)
			_check(not clicked.is_empty() and clicked.back() == int(enemy["id"]),
				"Spread hit testing selects only the visible instance, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			board.selected_enemy_id = int(enemy["id"])
			var highlighted: Image = await _image()
			var allowed: Rect2 = bounds[index].grow(5.0)
			var changed: int = 0
			var outside: int = 0
			for y: int in range(viewport.size.y):
				for x: int in range(viewport.size.x):
					if mixed.get_pixel(x, y).is_equal_approx(highlighted.get_pixel(x, y)):
						continue
					changed += 1
					if not allowed.has_point(Vector2(x, y)):
						outside += 1
			_check(changed > 8 and outside == 0,
				"Only selected body's local brackets change, without neighbor highlight or billboard, mirrored=%s type=%s" % [mirrored, enemy["type_id"]])
			board.selected_enemy_id = -1
		_check(board.combat_enemies == accepted and enemies == source,
			"Drawing, overlap picking and selection never mutate accepted snapshots or source enemies")
		var reordered: Array = board.combat_enemies.duplicate(true)
		reordered.reverse()
		board.combat_enemies = reordered
		var repeated: Image = await _image()
		_check(int(_changed_geometry(mixed, repeated, whole)["pixels"]) == 0,
			"Reordered full snapshots preserve exact spread, depth, shadows and pixels without jitter")
		await _check_corners(int(high["id"]), mirrored)
	var explicit: Dictionary = _enemy(901, 0.0, [])
	explicit["pos"] = Vector2(1.7, 3.2)
	_check(board._enemy_visual_position(explicit) == explicit["pos"], "Empty-route position fixtures do not acquire an invented cosmetic route")
	board.enemy_clicked.disconnect(on_click)
	board.combat_enemies = []


func _check_corners(id: int, mirrored: bool) -> void:
	board.combat_enemies = []
	var route: Array = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2)]
	for cell: Vector2i in route:
		board.layout.place(cell)
	var ground: Image = await _image()
	var previous := Vector2.ZERO
	for step: int in range(601):
		var enemy: Dictionary = _enemy(id, step * 0.01, route)
		var visual: Vector2 = board._enemy_visual_position(enemy)
		_check(visual.distance_to(board._enemy_position(enemy)) <= 0.10001, "Blended corner spread stays within path pavement")
		if step > 0:
			_check(visual.distance_to(previous) < 0.017, "Route-normal spread remains continuous through alternating bends")
		previous = visual
	var previous_bounds := Rect2i()
	for progress: float in [1.999, 2.0, 2.001]:
		board.combat_enemies = []
		board.combat_enemies = [_enemy(id, progress, route)]
		var corner: Image = await _image()
		var geometry: Dictionary = _changed_geometry(ground, corner, Rect2i(Vector2i.ZERO, viewport.size))
		var current_bounds: Rect2i = geometry["bounds"]
		_check(int(geometry["pixels"]) > 100, "Corner continuity exercises rendered shipped artwork")
		if previous_bounds.has_area():
			_check(Vector2(current_bounds.position).distance_to(Vector2(previous_bounds.position)) <= 1.5,
				"Shipped sprite crosses route vertex without a rendered sideways snap, mirrored=%s" % mirrored)
		previous_bounds = current_bounds


func _foot(enemy: Dictionary) -> Vector2:
	return board._position_center(board._enemy_visual_position(enemy)) + Vector2(0, board._cell_size() * 0.28)


func _visible_enemy_point(enemy: Dictionary, bounds: Rect2) -> Vector2:
	var foot: Vector2 = _foot(enemy)
	var progress: float = board._enemy_route_progress(enemy)
	for y: int in range(ceili(bounds.position.y), floori(bounds.end.y)):
		for x: int in range(ceili(bounds.position.x), floori(bounds.end.x)):
			var point := Vector2(x + 0.5, y + 0.5)
			if board._enemy_contains_point(enemy, foot, progress, point) and board.enemy_at(point) == int(enemy["id"]):
				return point
	return Vector2(-1, -1)


func _check_hit_pixels(bounds: Array[Rect2], mirrored: bool) -> void:
	var region: Rect2 = bounds[0]
	for rect: Rect2 in bounds:
		region = region.merge(rect)
	var sources: Array[Dictionary] = []
	for item: Dictionary in board._draw_order:
		if int(item["kind"]) != 2:
			continue
		var enemy: Dictionary = item["data"]
		var art: EnemyDefinition = board._enemy_art[enemy["type_id"]]
		var flip: bool = board._enemy_faces_left(enemy["route"], item["progress"]) != art.source_faces_left
		sources.append({"id": int(enemy["id"]), "image": art.texture.get_image(), "flip": flip,
			"rect": board._sprite_rect(art.texture, art.board_height, art.board_anchor, item["foot"], flip)})
	var mismatches: int = 0
	var transparent_samples: int = 0
	var overlapping_samples: int = 0
	for y: int in range(floori(region.position.y), ceili(region.end.y), 2):
		for x: int in range(floori(region.position.x), ceili(region.end.x), 2):
			var point := Vector2(x + 0.5, y + 0.5)
			var expected: int = -1
			var opaque_count: int = 0
			for source: Dictionary in sources:
				var rect: Rect2 = source["rect"]
				if not rect.has_point(point):
					continue
				var uv: Vector2 = (point - rect.position) / rect.size
				if bool(source["flip"]):
					uv.x = 1.0 - uv.x
				var image: Image = source["image"]
				var pixel := Vector2i(uv * Vector2(image.get_size()))
				pixel = pixel.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
				if image.get_pixelv(pixel).a < 0.1:
					transparent_samples += 1
					continue
				opaque_count += 1
				expected = int(source["id"])
			if opaque_count > 1:
				overlapping_samples += 1
			if board.enemy_at(point) != expected:
				mismatches += 1
	_check(transparent_samples > 0 and overlapping_samples > 0 and mismatches == 0,
		"Every sampled mixed-body hit follows topmost source opacity, not neighbor padding, mirrored=%s" % mirrored)


func _image() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


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


func _enemy(id: int, progress: float, route: Array) -> Dictionary:
	return {"id": id, "type_id": "grunt", "speed": 2.0, "progress": progress,
		"pos": board._route_position(route, progress) if route.size() > 1 else Vector2.ZERO,
		"hp": 8, "max_hp": 8, "route": route}


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
