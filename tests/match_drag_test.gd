extends SceneTree

const TOWER_TYPE: StringName = &"arrow_tower"

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
var sandbox: SandboxScreen
var world: MatchWorld
var fixture_viewport: SubViewport
var shop: TowerShopButton
var directory: String
var save_path: String
var saved_bytes: String
var pointer: Vector2 = Vector2.ZERO
var drag_starts: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_match_drag_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_check(false, "Create isolated native drag collection directory")
		quit(1)
		return
	save_path = directory.path_join("collection.json")
	var save := FileAccess.open(save_path, FileAccess.WRITE)
	if save == null:
		_check(false, "Create isolated unlocked native drag collection")
		DirAccess.remove_absolute(directory)
		quit(1)
		return
	save.store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower", "orc_ballista", "rune_obelisk"]}))
	save.close()
	saved_bytes = FileAccess.get_file_as_string(save_path)

	# A standalone SubViewport is its own GUI drag section. Unlike a native Window,
	# its mouse target uses push_input coordinates, not the actual desktop cursor.
	# Keep the real nested world viewport and HUD together inside this section.
	fixture_viewport = SubViewport.new()
	fixture_viewport.size = Vector2i(1440, 900)
	fixture_viewport.world_2d = World2D.new()
	fixture_viewport.handle_input_locally = true
	fixture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(fixture_viewport)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.combat_rules = CombatRules.new()
	fixture_viewport.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	await _settle()
	main.play_screen.singleplayer_button.pressed.emit()
	_check(main.planning.selecting_loadout and not main.planning.active, "Native drag fixture first opens loadout selection")
	_check(main.planning.select_loadout([&"arrow_tower", &"orc_ballista", &"rune_obelisk"]) and main.planning.commit_loadout(), "Native drag fixture commits its owned tested towers")
	await _settle()
	screen = main.play_screen.planning_screen
	world = screen.world
	world.set_process(false)
	_check(screen.is_visible_in_tree() and main.planning.active, "Real solo navigation activates the native drag fixture")
	if not screen.shop_buttons.has(TOWER_TYPE):
		_check(false, "Unlocked tower has a real HUD shop button")
		await _finish()
		return
	shop = screen.shop_buttons[TOWER_TYPE]
	shop.drag_started.connect(_drag_started)
	_check(shop.is_visible_in_tree() and not shop.disabled and shop.cost > 0, "Unlocked HUD tower is visible, available and costs Coins")

	var dimensions: Vector2i = main.planning.layouts[0].dimensions
	var center := Vector2i(dimensions.x / 2, dimensions.y / 2)
	var first_cell: Vector2i = center + Vector2i(-1, -1)
	var transformed_cell: Vector2i = center + Vector2i(0, -1)
	var path_cell: Vector2i = center + Vector2i(1, -1)
	var opponent_cell: Vector2i = center + Vector2i(2, -1)
	for cell: Vector2i in [first_cell, transformed_cell, path_cell, opponent_cell]:
		if not main.planning.layouts[0].contains(cell) or main.planning.layouts[0].has_path(cell):
			_check(false, "Native drag fixture has central empty ground at %s" % cell)
			await _finish()
			return

	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	await _purchase(first_cell, "Native HUD drag onto visible owned ground purchases a tower")
	_check(screen._placement_type() == TOWER_TYPE and screen.selected_tower_id < 0, "Shift-drop retains the purchased identity for the next build without opening inspection")
	shift = shift.duplicate() as InputEventKey
	shift.pressed = false
	Input.parse_input_event(shift)
	screen.cancel_interaction()
	await _settle()
	var original_position: Vector2 = world.camera.position
	var original_zoom: Vector2 = world.camera.zoom
	world.pan(0.08, Vector2.RIGHT)
	world.zoom_at(0.85, world.cell_screen_position(0, transformed_cell))
	world._process(1.0)
	await _settle()
	screen._cell_clicked(first_cell, MOUSE_BUTTON_LEFT, 0)
	_check(screen._management.visible and world.boards[0].selected_tower_id > 0, "Owned tower inspection and its range are open before an actual native drag")
	_check(world.camera.position.x > original_position.x and not world.camera.zoom.is_equal_approx(original_zoom), "Second native drop uses an actually translated and scaled camera")
	await _purchase(transformed_cell, "Native HUD drag purchases the exact owned cell after pan and zoom")
	_check(screen._placement_type() == &"" and screen.selected_tower_id > 0, "An ordinary drop still selects the newly purchased tower after releasing Shift")
	await _rejected(world.cell_screen_position(0, transformed_cell), "Native drop onto occupied ground is rejected without changing accepted state")

	main.planning.request_edit(0, path_cell, true)
	await _settle()
	_check(main.planning.layouts[0].has_path(path_cell), "Real planning command supplies a visible owned path tile")
	await _rejected(world.cell_screen_position(0, path_cell), "Native drop onto an owned path is rejected without changing accepted state")
	await _rejected(world.cell_screen_position(0, Vector2i(-1, transformed_cell.y)), "Native drop outside board bounds is rejected without changing accepted state")

	world.pan(100.0, Vector2.RIGHT)
	world.camera.force_update_scroll()
	await _settle()
	var opponent_ground: bool = main.planning.layouts[1].contains(opponent_cell) and not main.planning.layouts[1].has_path(opponent_cell)
	for tower: Dictionary in main.planning.combat["towers"][1]:
		opponent_ground = opponent_ground and tower["cell"] != opponent_cell
	_check(opponent_ground, "Opponent rejection target is otherwise legal empty ground")
	await _rejected(world.cell_screen_position(1, opponent_cell), "Native drop onto visible opponent ground is rejected without changing accepted state")
	await _rejected(shop.get_global_rect().get_center(), "Native release back over the HUD cancels without restoring inspection", false)
	screen._cell_clicked(first_cell, MOUSE_BUTTON_LEFT, 0)
	var before_escape: Dictionary = _accepted_state()
	var random_before_escape: Array[int] = _random_state()
	await _gesture(world.cell_screen_position(1, opponent_cell), false, true, true)
	_check(_accepted_state() == before_escape and _random_state() == random_before_escape and not screen.pause_menu.visible, "Match Escape cancels native drag without purchase, stale inspection or opening Pause")
	var route: Array[Vector2i] = [path_cell, path_cell + Vector2i.RIGHT]
	main.planning._host_combat._spawn_enemy(0, "skeleorc", 0.0, 0.0, route)
	main.planning._publish_combat()
	screen._enemy_clicked(int(main.planning.combat["enemies"][0][0]["id"]), 0)
	_check(screen._enemy_inspector.visible, "Match native drag starts with a real enemy inspector open")
	var before_enemy_drag: Dictionary = _accepted_state()
	var random_before_enemy_drag: Array[int] = _random_state()
	await _gesture(shop.get_global_rect().get_center(), false, false)
	_check(_accepted_state() == before_enemy_drag and _random_state() == random_before_enemy_drag, "Match native drag dismisses enemy inspection without modifying accepted combat")
	await _sandbox_gestures()
	await _finish()


func _purchase(cell: Vector2i, description: String) -> void:
	var before: Dictionary = main.planning._snapshot().duplicate(true)
	var before_combat: Dictionary = before["combat"]
	var cost: int = shop.cost
	await _gesture(world.cell_screen_position(0, cell), true)
	var after: Dictionary = main.planning._snapshot()
	var after_combat: Dictionary = after["combat"]
	var bought: bool = false
	for tower: Dictionary in after_combat["towers"][0]:
		if tower["cell"] == cell and tower["type_id"] == String(TOWER_TYPE):
			bought = true
	_check(bought and after_combat["towers"][0].size() == before_combat["towers"][0].size() + 1, description)
	_check(int(after_combat["coins"][0]) == int(before_combat["coins"][0]) - cost, "Native accepted drop authoritatively debits exactly the displayed tower price")
	_check(main.planning.combat == after_combat, "Native purchase publishes the authoritative combat state to the real screen")
	_check(after["tiles"] == before["tiles"], "A shop drag does not accidentally paint a world path")


func _rejected(point: Vector2, description: String, in_world: bool = true) -> void:
	var inspected: Dictionary = main.planning.combat["towers"][0][0]
	screen._cell_clicked(inspected["cell"], MOUSE_BUTTON_LEFT, 0)
	_check(screen._management.visible, "Rejected or cancelled native drag begins with an owned inspector open")
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	var presentation: Dictionary = main.planning.combat.duplicate(true)
	var random_before: Array[int] = _random_state()
	await _gesture(point, false, in_world)
	_check(_random_state() == random_before, "Rejected or cancelled native drag consumes no random rolls")
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, description)


func _gesture(destination: Vector2, accepted: bool, in_world: bool = true, cancel_with_escape: bool = false) -> void:
	if in_world:
		_check(world.get_global_rect().has_point(destination), "Native gesture destination is visible inside the world viewport")
	_check(not fixture_viewport.gui_is_dragging(), "Previous native gesture has ended before starting another")
	var start: Vector2 = shop.get_global_rect().get_center()
	var starts_before: int = drag_starts.size()
	var state_before: Dictionary = _accepted_state()
	var random_before: Array[int] = _random_state()
	await _motion(start, 0)
	await _button(start, true)
	# Engine drag initiation accumulates motion.relative beyond its drag threshold.
	# No force_drag, callback invocation, Input singleton seed or synthetic drop.
	await _motion(start + Vector2(20.0, -20.0), MOUSE_BUTTON_MASK_LEFT)
	_check(drag_starts.size() == starts_before + 1 and drag_starts.back() == TOWER_TYPE, "Actual GUI mouse gesture starts the real TowerShopButton drag")
	_check(fixture_viewport.gui_is_dragging(), "Engine GUI drag is active before leaving the HUD")
	_assert_drag_cleared()
	_check(_accepted_state() == state_before and _random_state() == random_before, "Crossing the engine drag threshold changes neither accepted state nor RNG")
	var departure: Vector2 = pointer
	for step: int in range(1, 5):
		await _motion(departure.lerp(destination, float(step) / 4.0), MOUSE_BUTTON_MASK_LEFT)
	_check(fixture_viewport.gui_is_dragging(), "Native tower drag survives crossing the HUD into the world viewport")
	_assert_drag_cleared()
	_check(_accepted_state() == state_before and _random_state() == random_before, "Native hover changes neither accepted state nor RNG before release")
	if cancel_with_escape:
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		fixture_viewport.push_input(escape, true)
		await _settle()
		_check(not fixture_viewport.gui_is_dragging(), "Escape ends the actual native GUI drag before mouse release")
		escape = escape.duplicate() as InputEventKey
		escape.pressed = false
		fixture_viewport.push_input(escape, true)
		await process_frame
	await _button(destination, false)
	await _settle()
	_check(not fixture_viewport.gui_is_dragging(), "Native release ends the GUI drag")
	_check(fixture_viewport.gui_is_drag_successful() == accepted, "Engine native drop outcome matches target legality")
	_check(world.boards[0]._drag_placement_id == &"" and world.boards[1]._drag_placement_id == &"", "Native drag end clears both boards' local previews")
	if not accepted:
		_assert_drag_cleared()


func _drag_started(type_id: StringName) -> void:
	drag_starts.append(type_id)


func _accepted_state() -> Dictionary:
	if sandbox != null:
		return sandbox.controller.combat.snapshot().duplicate(true)
	return main.planning._snapshot().duplicate(true)


func _random_state() -> Array[int]:
	var combat: MatchCombat = sandbox.controller.combat if sandbox != null else main.planning._host_combat
	return [combat._random.state, combat._wave_random.state, combat._timing_random.state, combat._group_random.state, combat._roll_random.state, combat._drop_random.state]


func _assert_drag_cleared() -> void:
	if sandbox != null:
		_check(sandbox.selected_tower_id < 0 and sandbox.selected_enemy_id < 0 and sandbox.placement_id == &"", "Sandbox native drag clears tower, enemy and click placement selection immediately")
		_check(not sandbox._management.visible and not sandbox._inspector.visible, "Sandbox native drag hides both inspectors before hover or release")
	else:
		_check(screen.selected_tower_id < 0 and screen.selected_enemy_id < 0 and screen.selected_enemy_slot < 0 and screen._placement_type() == &"" and screen._pending_tower_cell == Vector2i(-1, -1), "Match native drag clears tower, enemy, click placement and pending selection immediately")
		_check(not screen._management.visible and not screen._enemy_inspector.visible, "Match native drag hides both inspectors before hover or release")
	for board: PathBoard in world.boards:
		_check(board.selected_tower_id < 0 and board.selected_enemy_id < 0 and board.placement_id == &"", "Native drag removes old selected-tower ranges and enemy highlights on every board")


func _sandbox_gestures() -> void:
	main.sandbox_button.pressed.emit()
	await _settle()
	sandbox = main.sandbox_screen
	world = sandbox.world
	world.set_process(false)
	sandbox.set_physics_process(false)
	shop = sandbox.shop_buttons[TOWER_TYPE]
	shop.drag_started.connect(_drag_started)
	_check(sandbox.is_visible_in_tree() and not shop.disabled, "Real main-menu navigation opens the native Sandbox fixture")
	var first := Vector2i(5, 2)
	var second := Vector2i(6, 2)
	_check(sandbox.controller.build(first, TOWER_TYPE), "Sandbox fixture creates a real owned tower for inspection")
	sandbox._cell_clicked(first, MOUSE_BUTTON_LEFT)
	_check(sandbox._management.visible and world.boards[0].selected_tower_id > 0, "Sandbox starts a native gesture with owned tower inspection and range open")
	var before: Dictionary = _accepted_state()
	await _gesture(world.cell_screen_position(0, second), true)
	var after: Dictionary = _accepted_state()
	_check(after["towers"][0].size() == before["towers"][0].size() + 1 and after["coins"] == before["coins"], "Sandbox native accepted drop builds for free")
	_check(sandbox.selected_tower_id > 0 and sandbox._management.visible and sandbox.placement_id == &"", "Sandbox ordinary native drop inspects the newly built tower")
	var selected: Dictionary = sandbox._find(after["towers"][0], sandbox.selected_tower_id)
	_check(selected.get("cell") == second and selected.get("type_id") == String(TOWER_TYPE), "Sandbox engine drop purchases the exact hovered cell and identity")
	var random_before: Array[int] = _random_state()
	await _gesture(world.cell_screen_position(0, first), false)
	_check(_accepted_state() == after and _random_state() == random_before, "Sandbox occupied native drop preserves accepted state and RNG while leaving inspection closed")
	sandbox._cell_clicked(first, MOUSE_BUTTON_LEFT)
	await _gesture(shop.get_global_rect().get_center(), false, false)
	_check(_accepted_state() == after and _random_state() == random_before, "Sandbox cancelled native drag preserves its free build and RNG without restoring inspection")
	sandbox._cell_clicked(first, MOUSE_BUTTON_LEFT)
	await _gesture(world.cell_screen_position(0, first), false, true, true)
	_check(_accepted_state() == after and _random_state() == random_before, "Sandbox Escape cancels its native drag without restoring inspection or changing state")
	for x: int in range(1, 13):
		sandbox.controller.edit_path(Vector2i(x, 4), true)
	_check(sandbox.controller.spawn(&"skeleorc", 1), "Sandbox native enemy inspection fixture spawns an actual paused enemy")
	if not sandbox.controller.state["enemies"][0].is_empty():
		sandbox._enemy_clicked(int(sandbox.controller.state["enemies"][0][0]["id"]))
		_check(sandbox._inspector.visible, "Sandbox enemy inspector is open before native drag starts")
		before = _accepted_state()
		random_before = _random_state()
		await _gesture(shop.get_global_rect().get_center(), false, false)
		_check(_accepted_state() == before and _random_state() == random_before, "Sandbox native drag dismisses enemy inspection without changing the paused simulation")


func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	pointer = point
	fixture_viewport.push_input(event, true)
	await process_frame


func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - pointer
	event.button_mask = buttons
	pointer = point
	fixture_viewport.push_input(event, true)
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame


func _finish() -> void:
	_check(FileAccess.get_file_as_string(save_path) == saved_bytes, "Native match drags leave the isolated collection save unchanged")
	fixture_viewport.queue_free()
	await process_frame
	# Let the audio mix thread retire the stopped match playback before exit.
	await create_timer(maxf(0.0, AudioServer.get_time_to_next_mix()) + 0.025).timeout
	_check(DirAccess.remove_absolute(save_path) == OK, "Remove isolated native drag collection save")
	_check(DirAccess.remove_absolute(directory) == OK, "Remove isolated native drag collection directory")
	if failures == 0:
		print("PASS: native match and Sandbox drags dismiss inspection, preserve hover state/RNG, accept paid/free builds, and clean up rejected/cancelled drops")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
