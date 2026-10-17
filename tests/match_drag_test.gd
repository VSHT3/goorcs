extends SceneTree

const TOWER_TYPE: StringName = &"arrow_tower"

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
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

	await _purchase(first_cell, "Native HUD drag onto visible owned ground purchases a tower")
	screen.cancel_interaction()
	await _settle()
	var original_position: Vector2 = world.camera.position
	var original_zoom: Vector2 = world.camera.zoom
	world.pan(0.08, Vector2.RIGHT)
	world.zoom_at(0.85, world.cell_screen_position(0, transformed_cell))
	world._process(1.0)
	await _settle()
	_check(world.camera.position.x > original_position.x and not world.camera.zoom.is_equal_approx(original_zoom), "Second native drop uses an actually translated and scaled camera")
	await _purchase(transformed_cell, "Native HUD drag purchases the exact owned cell after pan and zoom")
	screen.cancel_interaction()
	await _settle()
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


func _rejected(point: Vector2, description: String) -> void:
	var accepted: Dictionary = main.planning._snapshot().duplicate(true)
	var presentation: Dictionary = main.planning.combat.duplicate(true)
	await _gesture(point, false)
	_check(main.planning._snapshot() == accepted and main.planning.combat == presentation, description)


func _gesture(destination: Vector2, accepted: bool) -> void:
	_check(world.get_global_rect().has_point(destination), "Native gesture destination is visible inside the world viewport")
	_check(not fixture_viewport.gui_is_dragging(), "Previous native gesture has ended before starting another")
	var start: Vector2 = shop.get_global_rect().get_center()
	var starts_before: int = drag_starts.size()
	await _motion(start, 0)
	await _button(start, true)
	# Engine drag initiation accumulates motion.relative beyond its drag threshold.
	# No force_drag, callback invocation, Input singleton seed or synthetic drop.
	await _motion(start + Vector2(20.0, -20.0), MOUSE_BUTTON_MASK_LEFT)
	_check(drag_starts.size() == starts_before + 1 and drag_starts.back() == TOWER_TYPE, "Actual GUI mouse gesture starts the real TowerShopButton drag")
	_check(fixture_viewport.gui_is_dragging(), "Engine GUI drag is active before leaving the HUD")
	var departure: Vector2 = pointer
	for step: int in range(1, 5):
		await _motion(departure.lerp(destination, float(step) / 4.0), MOUSE_BUTTON_MASK_LEFT)
	_check(fixture_viewport.gui_is_dragging(), "Native tower drag survives crossing the HUD into the world viewport")
	await _button(destination, false)
	await _settle()
	_check(not fixture_viewport.gui_is_dragging(), "Native release ends the GUI drag")
	_check(fixture_viewport.gui_is_drag_successful() == accepted, "Engine native drop outcome matches target legality")


func _drag_started(type_id: StringName) -> void:
	drag_starts.append(type_id)


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
		print("PASS: actual native HUD-to-world tower gestures, authoritative paid purchases, transformed drop cells, occupied/path/outside/opponent rejection")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
