extends SceneTree

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
var world: MatchWorld
var panel: EnemyInspector
var directory: String
var save_path: String
var saved_bytes: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy highlight regression needs a graphical renderer. Run without --headless.")
		quit(1)
		return
	directory = OS.get_temp_dir().path_join("gorcs_enemy_inspection_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_check(false, "Create isolated enemy-inspection collection directory")
		quit(1)
		return
	save_path = directory.path_join("collection.json")
	var save := FileAccess.open(save_path, FileAccess.WRITE)
	if save == null:
		_check(false, "Create isolated enemy-inspection collection save")
		DirAccess.remove_absolute(directory)
		quit(1)
		return
	save.store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower", "orc_ballista", "rune_obelisk"]}))
	save.close()
	saved_bytes = FileAccess.get_file_as_string(save_path)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	# A private real rules resource makes spacing, damage and lifecycle deterministic.
	var rules := CombatRules.new()
	rules.base_health = 100
	rules.enemy_health = 40
	rules.enemy_speed = 2.0
	rules.wave_weight = 3
	rules.spawn_interval = 0.9
	rules.wave_weight_growth = 0
	# This lifecycle fixture needs three separated instances, not rolled groups.
	rules.catalog.enemies = [preload("res://resources/combat/enemies/grunt.tres")]
	main.combat_rules = rules
	root.add_child(main)
	await _open_match()
	panel = screen.get_node("%EnemyInspector") as EnemyInspector
	_check(main.planning.singleplayer and main.planning.active and screen.is_visible_in_tree(), "Navigate the actual main scene into a real singleplayer match")
	_check_closed("New match")
	await _start_wave()
	if main.planning.combat["enemies"][0].size() != 3 or main.planning.combat["enemies"][1].size() != 3:
		_check(false, "Real wave spawns three separated instances on each board")
		await _finish()
		return
	await _check_identity_and_stats()
	await _check_interpolation()
	await _check_opponent_and_layout()
	await _check_lifecycle()
	await _check_leave_and_reopen()
	await _finish()


func _open_match() -> void:
	main.play_button.pressed.emit()
	await _settle()
	main.play_screen.singleplayer_button.pressed.emit()
	_check(main.planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and main.planning.commit_loadout(), "Inspection fixture commits its owned tested identities")
	screen = main.play_screen.planning_screen
	world = screen.world
	_freeze()
	await _settle()

	_check_cursor(screen.menu_button.get_global_rect().get_center(), Input.CURSOR_POINTING_HAND, "HUD cog uses the UI hand")
	_check_cursor(world.cell_screen_position(0, Vector2i(5, 3)), Input.CURSOR_ARROW, "Moving from HUD to terrain restores the gameplay pointer")

func _start_wave() -> void:
	for x: int in range(1, 13):
		main.planning.request_edit(0, Vector2i(x, 4), true)
	main.planning.submit_ready(true)
	_freeze()
	_advance(2.7)
	for board: PathBoard in world.boards:
		board._process(PathBoard.ENEMY_BLEND_DURATION)
	await _settle()
	_check(main.planning.combat["phase"] == MatchCombat.Phase.WAVE, "Fixture runs the host's normal wave simulation")


func _check_identity_and_stats() -> void:
	var first: Dictionary = main.planning.combat["enemies"][0][0]
	var second: Dictionary = main.planning.combat["enemies"][0][1]
	var first_id: int = int(first["id"])
	var second_id: int = int(second["id"])
	_check(first_id != second_id and first["type_id"] == second["type_id"], "Wave contains distinct live IDs of the same enemy type")
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	var cells: Array[Vector2i] = []
	var collect_cell := func(cell: Vector2i, _button: MouseButton) -> void: cells.append(cell)
	world.boards[0].cell_clicked.connect(collect_cell)
	world.pan(0.05, Vector2.RIGHT)
	world.zoom_at(0.9, world.get_global_rect().get_center())
	world._process(1.0)
	await _settle()
	await _click_enemy(0, first_id)
	_check_selected(0, first_id, "Mirrored owned sprite body click")
	_check(cells.is_empty(), "An enemy body click takes precedence over the underlying cell action")
	_check(main.planning._snapshot() == accepted, "Selecting a moving instance is local and cannot change host state")
	_check_stats(first, "Initial instance")
	await _check_highlight(0, first_id)

	# Change the host-owned instance, not the accepted UI dictionary or type preview.
	var actual: Dictionary = _host_enemy(0, first_id)
	actual["hp"] = 27
	actual["speed"] = 0.75
	actual["base_speed"] = 0.75
	actual["damage"] = 3
	_publish()
	await _settle()
	var updated: Dictionary = _accepted_enemy(0, first_id)
	_check_selected(0, first_id, "Accepted per-instance update")
	_check_stats(updated, "Damaged and slowed instance")
	_check(int(updated["hp"]) == 27 and is_equal_approx(float(updated["speed"]), 0.75) and int(updated["damage"]) == 3,
		"Published accepted state carries the real instance's HP, effective speed and damage")
	var preview: Dictionary = main.planning.combat["enemy_types"][String(updated["type_id"])]
	_check(int(preview["health"]) == 40 and is_equal_approx(float(preview["speed"]), 2.0), "Wave/type preview stays different from the damaged, slowed selected instance")

	await _click_enemy(0, second_id)
	_check_selected(0, second_id, "Second same-type body click replaces selection")
	_check_stats(_accepted_enemy(0, second_id), "Independent same-type instance")
	_check(panel.hp_value.text == "40" and is_equal_approx(panel.speed_value.text.to_float(), 2.0), "Switching IDs does not retain the previous same-type instance's damage or slow")
	main.planning._host_combat.enemies[0].reverse()
	main.planning._publish_snapshot()
	_freeze()
	await _settle()
	_check_selected(0, second_id, "A fresh full snapshot with reordered instances")
	_check_stats(_accepted_enemy(0, second_id), "Reordered accepted instance")
	world.boards[0].cell_clicked.disconnect(collect_cell)


func _check_interpolation() -> void:
	var board: PathBoard = world.boards[0]
	var id: int = screen.selected_enemy_id
	var old_position: Vector2 = board._enemy_position(_accepted_enemy(0, id))
	var old_bounds: Rect2 = _sprite_bounds(0, id)
	_advance(0.8)
	var accepted: Dictionary = _accepted_enemy(0, id)
	var target: Vector2 = accepted["pos"]
	_check(old_position.distance_to(target) > 1.5, "Real host movement creates a distinguishable interpolation interval")
	_check(board._enemy_position(accepted).is_equal_approx(old_position), "Incoming snapshot preserves the selected instance's displayed starting position")
	_check_selected(0, id, "Moving accepted snapshot")
	board._process(PathBoard.ENEMY_BLEND_DURATION * 0.5)
	var midpoint: Vector2 = old_position.lerp(target, 0.5)
	_check(board._enemy_position(accepted).is_equal_approx(midpoint), "Selected enemy displays the actual halfway interpolation position")
	var body: Vector2 = _body_position(0, id)
	_check(board.enemy_at(body) == id, "Hit testing follows the interpolated sprite body rather than the incoming target cell")
	await _check_highlight(0, id)
	_check_stats(accepted, "Interpolating instance")
	board._process(PathBoard.ENEMY_BLEND_DURATION)
	_check(board._enemy_position(accepted).is_equal_approx(target), "Selected enemy reaches but does not extrapolate past its accepted target")
	await _check_highlight(0, id, old_bounds)
	await _click_enemy(0, id)
	_check_selected(0, id, "Root click follows the moved sprite, not its old location")
	_check(main.planning.combat["enemies"][0].has(accepted) and accepted["pos"] == target,
		"Interpolated movement and inspection leave accepted instance coordinates intact")


func _check_opponent_and_layout() -> void:
	await _key(KEY_ESCAPE)
	_check_closed("Escape")
	_check(screen.is_visible_in_tree() and main.planning.active and not main.menu.visible, "Escape closes inspection before leaving the actual match")
	world.pan(100.0, Vector2.RIGHT)
	world.pan(0.08, Vector2.LEFT)
	world.zoom_at(0.85, world.get_global_rect().get_center())
	await _settle()
	var opponent: Dictionary = main.planning.combat["enemies"][1][0]
	var id: int = int(opponent["id"])
	_check(not world.boards[1].mirror_horizontal and world.boards[0].mirror_horizontal, "Regression traverses both normal and mirrored world boards")
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	var presentation: Dictionary = main.planning.combat.duplicate(true)
	var layout_before: Array[Rect2] = _layout_rects()
	var sizes: Array[Vector2] = [world.boards[0].size, world.boards[1].size]
	var camera_before: Vector2 = world.camera.position
	var opponent_cells: Array[Vector2i] = []
	var collect_cell := func(cell: Vector2i, _button: MouseButton) -> void: opponent_cells.append(cell)
	world.boards[1].cell_clicked.connect(collect_cell)
	await _click_enemy(1, id)
	_check_selected(1, id, "Panned and zoomed normal opponent sprite body click")
	_check_stats(opponent, "Opponent instance")
	_check(opponent_cells.is_empty(), "Opponent inspection never routes an owned cell command")
	_check(not world.boards[1].input_enabled and world.boards[1].enemy_inspection_enabled, "Opponent enables inspection without enabling gameplay input")
	_check(not screen.get_node("%TowerManagement").is_visible_in_tree() and screen.selected_tower_id == -1,
		"Opponent enemy opens only inspection, never owned tower management")
	_check(_same_rects(layout_before, _layout_rects()) and world.boards[0].size == sizes[0] and world.boards[1].size == sizes[1]
		and world.camera.position.is_equal_approx(camera_before), "Opening inspection does not reflow fixed HUD, resize either board or move the world camera")
	var panel_before: Rect2 = panel.get_global_rect()
	var hud: Control = screen.get_node("HUD")
	var right_gap: float = hud.get_global_rect().end.x - panel_before.end.x
	_check(right_gap >= 0.0 and right_gap < 32.0 and panel_before.position.y >= screen.get_node("HUD/Header").get_global_rect().end.y,
		"Visible inspector sits on the right below the fixed header")
	world.pan(0.04, Vector2.RIGHT)
	await _settle()
	_check(_same_rect(panel_before, panel.get_global_rect()), "Inspector stays screen-anchored while the inspected opponent moves with camera pan")
	var old_size: Vector2i = root.size
	var old_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i(1500, 900)
	root.size = Vector2i(1500, 900)
	await _settle()
	_check(is_equal_approx(hud.get_global_rect().end.x - panel.get_global_rect().end.x, right_gap)
		and is_equal_approx(panel.get_global_rect().position.y, panel_before.position.y), "Viewport resize preserves the inspector's right and top anchoring")
	_check(world.boards[0].size == sizes[0] and world.boards[1].size == sizes[1], "Inspector and viewport resize preserve fixed board dimensions")
	root.content_scale_size = old_scale
	root.size = old_size
	await _settle()
	var payload: Dictionary = {"tower_type": "arrow_tower"}
	var opponent_point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * world.cell_screen_position(1, Vector2i(8, 2))
	_check(not world._can_drop_data(opponent_point, payload), "Native tower drop remains forbidden on the inspected opponent")
	world._drop_data(opponent_point, payload)
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, "Opponent inspection, pan, resize and forbidden drop cannot mutate authoritative or accepted gameplay")
	var close: Button = _close_control()
	if close != null:
		await _click_rendered_control(close)
	_check_closed("Actual inspector Close button")
	await _click_enemy(1, id)
	_check_selected(1, id, "Reopen after Close")
	await _click_rendered_control(screen.shop_buttons[&"arrow_tower"])
	_check_closed("Entering tower placement")
	_check(not world.boards[0].enemy_inspection_enabled and not world.boards[1].enemy_inspection_enabled, "Placement disables inspection on both boards")
	await _click_enemy(1, id)
	_check_closed("Opponent sprite click during placement")
	_check(main.planning._snapshot() == accepted, "Placement cannot turn an opponent inspection click into a build")
	await _key(KEY_ESCAPE)
	world.boards[1].cell_clicked.disconnect(collect_cell)


func _check_lifecycle() -> void:
	world.pan(100.0, Vector2.RIGHT)
	await _settle()
	var victim_id: int = int(main.planning.combat["enemies"][1][0]["id"])
	await _click_enemy(1, victim_id)
	_check_selected(1, victim_id, "Select enemy before real tower kill")
	main.planning.build_tower(0, Vector2i(7, 3), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
	_freeze()
	_host_enemy(1, victim_id)["hp"] = 1
	_publish()
	var kills_before: int = int(main.planning.combat["towers"][1][0]["kills"])
	_advance(0.1)
	await _settle()
	_check(_accepted_enemy(1, victim_id).is_empty() and int(main.planning.combat["towers"][1][0]["kills"]) == kills_before + 1,
		"Real authoritative tower attack kills the selected opponent instance")
	_check_closed("Selected instance death while same-type enemies survive")
	var leaker: Dictionary = main.planning.combat["enemies"][1][0]
	var leak_id: int = int(leaker["id"])
	for board: PathBoard in world.boards:
		board._process(PathBoard.ENEMY_BLEND_DURATION)
	await _click_enemy(1, leak_id)
	_check_selected(1, leak_id, "Select another live instance before leak")
	var health_before: int = int(main.planning.combat["health"][1])
	var damage: int = int(leaker["damage"])
	_host_enemy(1, leak_id)["speed"] = 200.0
	_host_enemy(1, leak_id)["base_speed"] = 200.0
	_advance(0.1)
	await _settle()
	_check(_accepted_enemy(1, leak_id).is_empty() and int(main.planning.combat["health"][1]) == health_before - damage,
		"Real authoritative movement leaks the selected instance and applies its base damage")
	_check_closed("Selected instance leak")
	var removed_id: int = int(main.planning.combat["enemies"][1][0]["id"])
	for board: PathBoard in world.boards:
		board._process(PathBoard.ENEMY_BLEND_DURATION)
	await _click_enemy(1, removed_id)
	_check_selected(1, removed_id, "Select last opponent instance before accepted removal")
	main.planning._host_combat.enemies[1].erase(_host_enemy(1, removed_id))
	_publish()
	await _settle()
	_check_closed("Accepted snapshot removal")
	world.pan(100.0, Vector2.LEFT)
	for board: PathBoard in world.boards:
		board._process(PathBoard.ENEMY_BLEND_DURATION)
	await _settle()
	var survivor_id: int = int(main.planning.combat["enemies"][0][0]["id"])
	await _click_enemy(0, survivor_id)
	_check_selected(0, survivor_id, "Select surviving enemy before results")
	main.planning._host_combat.base_health[1] = 0
	_advance(0.1)
	await _settle()
	_check(main.planning.combat["phase"] == MatchCombat.Phase.FINISHED and not _accepted_enemy(0, survivor_id).is_empty(),
		"Real terminal resolution reaches results while the selected instance still exists")
	_check_closed("Match results")
	_check(not world.boards[0].enemy_inspection_enabled and not world.boards[1].enemy_inspection_enabled, "Results cannot reopen stale inspection")


func _check_leave_and_reopen() -> void:
	await _click_rendered_control(screen.results_menu.menu_button)
	await _open_match()
	await _start_wave()
	var id: int = int(main.planning.combat["enemies"][0][0]["id"])
	await _click_enemy(0, id)
	_check_selected(0, id, "Fresh match enemy before Leave")
	await _click_rendered_control(screen.menu_button)
	await _click_rendered_control(screen.pause_menu.quit_button)
	_check(main.menu.visible and not main.planning.active and not screen.is_visible_in_tree(), "Menu Quit deactivates the inspected match")
	_check_closed("Leaving inspected match")
	await _open_match()
	_check_closed("Reopening singleplayer")
	await _start_wave()
	_check(int(main.planning.combat["enemies"][0][0]["id"]) == id, "New match genuinely reuses a prior enemy ID")
	_check_closed("A reused enemy ID in a later match cannot resurrect selection")
	await _click_enemy(0, id)
	_check_selected(0, id, "Reused ID remains inspectable after explicit new click")


func _check_stats(enemy: Dictionary, context: String) -> void:
	_check(panel.is_visible_in_tree() and panel.hp_value.is_visible_in_tree() and panel.speed_value.is_visible_in_tree()
		and panel.damage_value.is_visible_in_tree() and panel.health_bar.is_visible_in_tree(), "%s: actual stats controls are visible" % context)
	_check(panel.hp_value.text == str(int(enemy["hp"])), "%s: HP shows only the current instance HP, not current/max or preview health" % context)
	_check(is_equal_approx(panel.health_bar.max_value, float(enemy["max_hp"])) and is_equal_approx(panel.health_bar.value, float(enemy["hp"])),
		"%s: visible health bar reflects current and maximum HP" % context)
	_check(panel.speed_value.text.is_valid_float() and is_equal_approx(panel.speed_value.text.to_float(), float(enemy["speed"])),
		"%s: displayed speed equals effective accepted instance speed" % context)
	_check(panel.damage_value.text == str(int(enemy["damage"])), "%s: displayed base damage equals accepted instance damage" % context)


func _check_selected(slot: int, id: int, context: String) -> void:
	_check(screen.selected_enemy_slot == slot and screen.selected_enemy_id == id and panel.is_visible_in_tree(), "%s: one visible panel selects the exact board and instance ID" % context)
	_check(world.boards[slot].selected_enemy_id == id and world.boards[1 - slot].selected_enemy_id == -1,
		"%s: only the selected instance's board owns the highlight" % context)


func _check_closed(context: String) -> void:
	_check(screen.selected_enemy_id == -1 and screen.selected_enemy_slot == -1 and not panel.is_visible_in_tree()
		and world.boards[0].selected_enemy_id == -1 and world.boards[1].selected_enemy_id == -1,
		"%s clears the panel and both boards' instance selection" % context)


func _check_highlight(slot: int, id: int, old_bounds: Rect2 = Rect2()) -> void:
	_freeze()
	var board: PathBoard = world.boards[slot]
	var selected: Image = await _world_image()
	board.selected_enemy_id = -1
	board.queue_redraw()
	var baseline: Image = await _world_image()
	board.selected_enemy_id = id
	board.queue_redraw()
	var current_region: Rect2i = _image_region(board, _sprite_bounds(slot, id).grow(6.0))
	_check(_changed_pixels(baseline, selected, current_region) > 8, "Selected instance has a visible highlight at its displayed interpolated sprite bounds")
	for enemy: Dictionary in board.combat_enemies:
		if int(enemy["id"]) == id:
			continue
		var other_region: Rect2i = _image_region(board, _sprite_bounds(slot, int(enemy["id"])).grow(3.0))
		if not current_region.intersects(other_region):
			_check(_changed_pixels(baseline, selected, other_region) == 0, "Same-type unselected instance does not inherit the selected highlight")
	if old_bounds.has_area():
		var old_region: Rect2i = _image_region(board, old_bounds.grow(6.0))
		_check(not old_region.intersects(current_region) and _changed_pixels(baseline, selected, old_region) == 0,
			"Moving highlight leaves no mark at the instance's previous snapshot position")


func _sprite_bounds(slot: int, id: int) -> Rect2:
	var board: PathBoard = world.boards[slot]
	var enemy: Dictionary = _accepted_enemy(slot, id)
	var artwork: EnemyDefinition = board._enemy_art[String(enemy["type_id"])]
	var foot: Vector2 = board._position_center(board._enemy_visual_position(enemy)) + Vector2(0, board._cell_size() * 0.28)
	var flip: bool = board._enemy_faces_left(enemy["route"], board._enemy_route_progress(enemy)) != artwork.source_faces_left
	var texture: Texture2D = EnemyVisuals.enemy_texture(artwork, enemy)
	return EnemyVisuals.visible_rect(artwork, texture, board._cell_size() * artwork.board_height, foot, flip)


func _body_position(slot: int, id: int) -> Vector2:
	# Click the displayed torso, above the foot/cell centre and outside texture padding.
	var bounds: Rect2 = _sprite_bounds(slot, id)
	return bounds.position + bounds.size * Vector2(0.5, 0.4)


func _click_enemy(slot: int, id: int) -> void:
	# UI refreshes re-enable cosmetic processing. Hold this fixture's displayed
	# pose while preparing the synthetic body click.
	_freeze()
	var board: PathBoard = world.boards[slot]
	var local: Vector2 = _body_position(slot, id)
	var viewport_position: Vector2 = board.get_global_transform_with_canvas() * local
	var viewport: SubViewport = world.get_node("Viewport")
	var point: Vector2 = world.get_global_transform_with_canvas() * (viewport_position * world.size / Vector2(viewport.size))
	_check(world.get_global_rect().has_point(point), "Selected sprite body is actually inside the visible transformed gameplay viewport")
	_check_cursor(point, Input.CURSOR_ARROW, "Hovering an inspectable enemy keeps the gameplay pointer")
	await _click(point)


func _check_cursor(point: Vector2, expected: Input.CursorShape, message: String) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	_check(Input.get_current_cursor_shape() == expected, message)


func _image_region(board: PathBoard, rect: Rect2) -> Rect2i:
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var region := Rect2i(Rect2(transform * rect.position, rect.size * world.camera.zoom).abs())
	var viewport: SubViewport = world.get_node("Viewport")
	return region.intersection(Rect2i(Vector2i.ZERO, viewport.size))


func _changed_pixels(first: Image, second: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if not first.get_pixel(x, y).is_equal_approx(second.get_pixel(x, y)):
				count += 1
	return count


func _world_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport: SubViewport = world.get_node("Viewport")
	return viewport.get_texture().get_image()


func _host_enemy(slot: int, id: int) -> Dictionary:
	for enemy: Dictionary in main.planning._host_combat.enemies[slot]:
		if int(enemy["id"]) == id:
			return enemy
	return {}


func _accepted_enemy(slot: int, id: int) -> Dictionary:
	for enemy: Dictionary in main.planning.combat["enemies"][slot]:
		if int(enemy["id"]) == id:
			return enemy
	return {}


func _publish() -> void:
	main.planning._publish_combat()
	_freeze()


func _advance(delta: float) -> void:
	main.planning._physics_process(delta)
	_freeze()


func _freeze() -> void:
	main.planning.set_physics_process(false)
	world.set_process(false)
	for board: PathBoard in world.boards:
		board.set_process(false)
		board._endpoint_timer.paused = true


func _close_control() -> Button:
	for child: Node in panel.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and not button.disabled:
			return button
	_check(false, "Inspector exposes an actual usable Close button")
	return null


func _layout_rects() -> Array[Rect2]:
	var rectangles: Array[Rect2] = [world.get_global_rect(), screen.menu_button.get_global_rect(), screen.send_button.get_global_rect(),
		screen.enemy_selector.get_global_rect(), screen.get_node("HUD/Header").get_global_rect(), screen.get_node("%Coins").get_global_rect()]
	for button: TowerShopButton in screen.shop_buttons.values():
		rectangles.append(button.get_global_rect())
	return rectangles


func _same_rects(first: Array[Rect2], second: Array[Rect2]) -> bool:
	if first.size() != second.size():
		return false
	for index: int in range(first.size()):
		if not _same_rect(first[index], second[index]):
			return false
	return true


func _same_rect(first: Rect2, second: Rect2) -> bool:
	return first.position.is_equal_approx(second.position) and first.size.is_equal_approx(second.size)


func _settle() -> void:
	await process_frame
	await process_frame


func _click_rendered_control(control: Control) -> void:
	# New modal containers must finish layout before reading their click position.
	root.grab_focus()
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	await process_frame
	await _click(control.get_global_rect().get_center())


func _click(point: Vector2) -> void:
	# Dispatch one click in one input frame, so native focus/motion cannot
	# replace the synthetic hover between its press and release.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _finish() -> void:
	_check(FileAccess.get_file_as_string(save_path) == saved_bytes, "Inspection leaves isolated collection save unchanged")
	main.planning.stop_singleplayer()
	main._match_music.stop()
	main.queue_free()
	await process_frame
	# Let the mixer retire stopped match playback before the script exits.
	await create_timer(maxf(0.0, AudioServer.get_time_to_next_mix()) + 0.025).timeout
	_check(DirAccess.remove_absolute(save_path) == OK, "Remove isolated enemy-inspection collection save")
	_check(DirAccess.remove_absolute(directory) == OK, "Remove isolated enemy-inspection collection directory")
	if failures == 0:
		print("PASS: instance-identity enemy inspection, real accepted stats, interpolated highlight, transformed mirrored/opponent input, anchored HUD and lifecycle reset")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
