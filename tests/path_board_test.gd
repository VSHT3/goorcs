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
	viewport.queue_free()
	if failures == 0:
		print("PASS: frame-blended enemy motion follows corners, preserves authoritative state, clears removed IDs, and rendered path junctions connect on both board orientations")
	quit(1 if failures else 0)


func _enemy(id: int, progress: float, position: Vector2) -> Dictionary:
	return {"id": id, "progress": progress, "pos": position, "hp": 8, "max_hp": 8}


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
