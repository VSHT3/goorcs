extends SceneTree

var failures: int = 0
var main: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	await _key(KEY_S)
	var sandbox: SandboxScreen = main.sandbox_screen
	await _click(sandbox.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _key(KEY_6)
	_check(sandbox.placement_id == &"gold_mine" and sandbox.controller.state["towers"][0].is_empty(), "Number keys select the matching Sandbox palette slot without placing a tower")
	var width_field: LineEdit = sandbox.width_input.get_line_edit()
	width_field.grab_focus()
	width_field.select_all()
	await _key(KEY_2)
	_check(width_field.text == "2" and sandbox.placement_id == &"gold_mine", "Typing a number edits the focused map field without changing the build tool")
	width_field.text = "14"
	width_field.release_focus()
	sandbox._request_reset()
	await _settle()
	await _key(KEY_1)
	_check(sandbox.placement_id == &"gold_mine" and sandbox.reset_dialog.visible, "A confirmation dialog blocks tower shortcuts")
	sandbox.reset_dialog.hide()
	sandbox.cancel_interaction()
	await _key(KEY_1)
	await _shift(true)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2)]:
		await _click(sandbox.cell_screen_position(cell))
		_check(sandbox.placement_id == &"arrow_tower" and sandbox.selected_tower_id < 0, "Shift placement retains the free build tool without opening inspection")
	_check(sandbox.controller.state["towers"][0].size() == 2, "Two distinct Shift clicks create exactly two towers")
	await _click(sandbox.cell_screen_position(sandbox.layout.entrance))
	_check(sandbox.controller.state["towers"][0].size() == 2 and sandbox.placement_id == &"arrow_tower", "An illegal Shift placement keeps the tool and creates nothing")
	await _shift(false)
	await _click(sandbox.cell_screen_position(Vector2i(4, 2)))
	_check(sandbox.placement_id == &"" and sandbox.selected_tower_id > 0 and sandbox.controller.state["towers"][0].size() == 3, "Releasing Shift restores ordinary placement and inspection")
	sandbox.cancel_interaction()
	await _click(sandbox.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	await _click(sandbox.cell_screen_position(Vector2i(5, 2)))
	await _key(KEY_ESCAPE)
	_check(sandbox.placement_id == &"" and sandbox.visible, "Escape cancels repeat building before leaving Sandbox")
	await _shift(false)
	await _sandbox_build_another(sandbox)
	await _sandbox_run_controls(sandbox)
	await _key(KEY_ESCAPE)
	await _key(KEY_P)
	main.play_screen.singleplayer_button.pressed.emit()
	_check(main.planning.select_loadout([&"arrow_tower"]) and main.planning.commit_loadout(), "Real solo run admits the starter loadout")
	main.planning.debug_set_values(1, 200, 8)
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	await _settle()
	await _key(KEY_1)
	_check(screen._placement_type() == &"arrow_tower" and main.planning.combat["towers"][0].is_empty(), "Match shortcut numbering uses only equipped visible slots, not collection identities")
	screen.open_pause_menu()
	await _settle()
	screen.cancel_interaction()
	await _key(KEY_1)
	_check(screen._placement_type() == &"", "Pause blocks build shortcuts")
	screen._resume_match()
	await _settle()
	await _click(screen.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2)]:
		await _click(screen.world.cell_screen_position(0, cell))
		_check(screen._placement_type() == &"arrow_tower" and screen.selected_tower_id < 0, "Paid repeat building retains local build selection after accepted snapshots")
	_check(main.planning.combat["towers"][0].size() == 2 and main.planning.combat["towers"][1].size() == 2 and main.planning.combat["coins"] == [110, 110], "Repeated solo purchases charge both mirrored owners exactly once per tower")
	await _click(screen.world.cell_screen_position(1, Vector2i(4, 2)))
	_check(main.planning.combat["towers"][1].size() == 2 and main.planning.combat["coins"] == [110, 110], "Repeat building cannot purchase on the opponent board")
	await _click(screen.world.cell_screen_position(0, main.planning.layouts[0].entrance))
	_check(main.planning.combat["towers"][0].size() == 2 and screen._placement_type() == &"arrow_tower" and main.planning.combat["coins"] == [110, 110], "Rejected paid placement preserves selection and all money")
	await _shift(false)
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	_check(screen._placement_type() == &"" and screen.selected_tower_id > 0 and main.planning.combat["coins"] == [65, 65], "Normal paid placement still selects its accepted tower")
	await _click(screen.shop_buttons[&"arrow_tower"].get_global_rect().get_center())
	await _shift(true)
	await _click(screen.world.cell_screen_position(0, Vector2i(5, 2)))
	_check(main.planning.combat["towers"][0].size() == 4 and main.planning.combat["coins"] == [20, 20] and screen._placement_type() == &"", "Running out of funds exits repeat placement without a speculative extra purchase")
	await _shift(false)
	await _solo_build_another(screen)
	_finish.call_deferred()


func _sandbox_build_another(sandbox: SandboxScreen) -> void:
	await _click(sandbox.cell_screen_position(Vector2i(4, 2)))
	var source_id: int = sandbox.selected_tower_id
	_check(sandbox.controller.upgrade(source_id, "damage") and sandbox.controller.reroll_tower(source_id, "attributes"), "Source Sandbox tower can have upgrades and rerolled traits")
	var before: Dictionary = sandbox.controller.state.duplicate(true)
	var random_state: int = sandbox.controller.combat._roll_random.state
	await _key(KEY_B)
	_check(sandbox.placement_id == &"arrow_tower" and sandbox.selected_tower_id == -1 and sandbox.controller.state == before and sandbox.controller.combat._roll_random.state == random_state, "B selects the inspected accepted identity without buying, rolling, or changing the source")
	await _key(KEY_ESCAPE)
	_check(sandbox.placement_id == &"" and sandbox.visible, "Escape cancels Build another without leaving Sandbox")
	await _key(KEY_B)
	_check(sandbox.placement_id == &"", "B without an inspected tower has no side effects")
	await _click(sandbox.cell_screen_position(Vector2i(4, 2)))
	for code: Key in [KEY_B, KEY_F, KEY_R]:
		for variant: String in ["echo", "ctrl", "alt", "meta"]:
			await _guarded_key(code, variant)
	_check(sandbox.selected_tower_id == source_id and sandbox.controller.state == before and sandbox.controller.speed == 1.0, "Repeated and modified B/F/R never trigger Sandbox actions")
	var field: LineEdit = sandbox.width_input.get_line_edit()
	field.grab_focus()
	field.select_all()
	await _key(KEY_B)
	await _key(KEY_F)
	await _key(KEY_R)
	_check(sandbox.selected_tower_id == source_id and sandbox.placement_id == &"" and sandbox.controller.speed == 1.0 and sandbox.controller.state == before, "Typing B/F/R does not trigger Sandbox actions")
	field.text = "14"
	field.release_focus()
	sandbox._request_reset()
	await _settle()
	await _key(KEY_B)
	await _key(KEY_F)
	await _key(KEY_R)
	_check(sandbox.selected_tower_id == source_id and sandbox.controller.speed == 1.0 and sandbox.controller.state == before, "A confirmation modal blocks B/F/R")
	sandbox.reset_dialog.hide()
	await _settle()
	await _click(sandbox.build_another_button.get_global_rect().get_center())
	_check(sandbox.placement_id == &"arrow_tower" and sandbox.controller.state == before, "Inspector button selects ordinary free placement without mutation")
	sandbox.controller.combat._roll_random.seed = 81
	random_state = sandbox.controller.combat._roll_random.state
	await _click(sandbox.cell_screen_position(Vector2i(6, 2)))
	var placed: Dictionary = sandbox._find(sandbox.controller.state["towers"][0], sandbox.selected_tower_id)
	_check(not placed.is_empty() and int(placed["id"]) != source_id and not placed["damage_upgraded"] and not placed["speed_upgraded"] and not placed["special_upgraded"] and placed["attribute_rerolls"] == 0 and placed["rarity_rerolls"] == 0 and sandbox.controller.combat._roll_random.state != random_state, "Build another places a separate base tower with a fresh roll, not the inspected upgrades or rerolled traits")
	# Hidden or disabled catalog entries never become a back door into placement.
	var palette_button: TowerShopButton = sandbox.shop_buttons[&"arrow_tower"]
	palette_button.hide()
	sandbox._refresh()
	await _key(KEY_B)
	_check(sandbox.build_another_button.disabled and sandbox.placement_id == &"", "A hidden palette identity blocks Build another")
	palette_button.show()
	palette_button.disabled = true
	sandbox._refresh()
	await _key(KEY_B)
	_check(sandbox.build_another_button.disabled and sandbox.placement_id == &"", "A disabled palette identity blocks Build another")
	palette_button.disabled = false
	sandbox.cancel_interaction()


func _sandbox_run_controls(sandbox: SandboxScreen) -> void:
	sandbox.set_physics_process(false)
	sandbox.controller.stop()
	sandbox.controller.clear_path()
	sandbox._refresh()
	var before: Dictionary = sandbox.controller.state.duplicate(true)
	await _key(KEY_R)
	_check(sandbox.restart_button.disabled and sandbox.controller.state == before, "R cannot create a run before an accepted test")
	for expected: float in [2.0, 4.0, 1.0]:
		await _key(KEY_F)
		_check(sandbox.controller.speed == expected and [1.0, 2.0, 4.0][sandbox.speed_selector.selected] == expected, "F cycles accepted speed and keeps its selector synchronized")
	await _click(sandbox.speed_selector.get_global_rect().get_center())
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(sandbox.controller.speed == 2.0 and sandbox.speed_selector.selected == 1, "Native speed selector changes actual simulation speed")
	await _key(KEY_F)
	_check(sandbox.controller.speed == 4.0 and sandbox.speed_selector.selected == 2, "F continues cycling from the pointer-selected speed")
	var popup: PopupMenu = sandbox.enemy_selector.get_popup()
	popup.popup()
	await _settle()
	await _key(KEY_F)
	_check(sandbox.controller.speed == 4.0, "Open selector popup blocks speed shortcuts")
	popup.hide()
	for x: int in range(1, sandbox.layout.dimensions.x - 1):
		_check(sandbox.controller.edit_path(Vector2i(x, sandbox.layout.entrance.y), true), "Run control test builds a valid independent route")
	_check(sandbox.controller.spawn(&"skeleorc", 3), "Exact Spawn creates a restartable test")
	before = sandbox.controller.state.duplicate(true)
	for code: Key in [KEY_R, KEY_F, KEY_SPACE]:
		for variant: String in ["echo", "ctrl", "alt", "meta"]:
			await _guarded_key(code, variant)
	_check(sandbox.controller.paused and sandbox.controller.speed == 4.0 and sandbox.controller.state == before, "Enabled restart, speed, and Space still ignore repeats and modifiers")
	sandbox.shop_buttons[&"arrow_tower"].force_drag({"tower_type": "arrow_tower"}, Label.new())
	await _settle()
	_check(root.gui_is_dragging(), "Native drag guard test starts a real viewport drag")
	await _key(KEY_R)
	await _key(KEY_F)
	await _key(KEY_SPACE)
	_check(sandbox.controller.paused and sandbox.controller.speed == 4.0 and sandbox.controller.state == before, "Dragging cannot restart, change speed, or toggle Play with Space")
	await _click(sandbox.menu_button.get_global_rect().get_center() - Vector2(50, 0))
	sandbox.controller.stop()
	await _settle()
	var build: Array = sandbox.controller.state["towers"][0].duplicate(true)
	await _key(KEY_R)
	_check(sandbox.controller.combat.phase == MatchCombat.Phase.WAVE and not sandbox.controller.paused and sandbox.controller.state["enemies"][0].size() == 3 and sandbox.controller.state["towers"][0] == build and sandbox.controller.speed == 4.0, "Native R restarts the last exact Spawn after Stop while retaining the build and speed")
	sandbox.controller.stop()
	await _settle()
	await _click(sandbox.restart_button.get_global_rect().get_center())
	_check(sandbox.controller.combat.phase == MatchCombat.Phase.WAVE and not sandbox.controller.paused and sandbox.controller.state["enemies"][0].size() == 3, "Restart button repeats the accepted batch through the owner")
	sandbox.controller.stop()
	sandbox.controller.clear_path()
	await _settle()
	before = sandbox.controller.state.duplicate(true)
	await _key(KEY_R)
	_check(sandbox.restart_button.disabled and sandbox.controller.state == before, "An invalid current route disables restart and R remains inert")
	sandbox.controller.speed = 1.0
	sandbox._refresh()
	sandbox.set_physics_process(true)


func _solo_build_another(screen: MatchPlanningScreen) -> void:
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	var source_id: int = screen.selected_tower_id
	var before: Dictionary = main.planning.combat.duplicate(true)
	await _key(KEY_B)
	_check(screen.build_another_button.disabled and screen._placement_type() == &"" and main.planning.combat == before, "Insufficient funds disable B without changing inspection or balances")
	main.planning.debug_set_values(1, 1000, 8)
	main.planning.upgrade_tower(0, source_id, "damage")
	_check(main.planning.reroll_tower(0, source_id, "attributes"), "Paid source tower has rerolled traits")
	before = main.planning.combat.duplicate(true)
	var random_state: int = main.planning._host_combat._roll_random.state
	await _key(KEY_B)
	_check(screen._placement_type() == &"arrow_tower" and main.planning.combat == before and main.planning._host_combat._roll_random.state == random_state, "Paid B selects accepted identity without spending or rerolling either mirror")
	await _key(KEY_ESCAPE)
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	screen.open_pause_menu()
	await _settle()
	await _key(KEY_B)
	_check(screen._placement_type() == &"" and main.planning.combat == before, "Pause blocks B without changing the accepted paid state")
	screen._resume_match()
	await _settle()
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	_check(screen.selected_tower_id == source_id, "Resume allows inspecting the source tower again before Ready")
	main.planning._host_ready[0] = true
	main.planning._publish_snapshot()
	before = main.planning.combat.duplicate(true)
	await _key(KEY_B)
	screen.build_another_button.pressed.emit()
	_check(screen.build_another_button.disabled and screen._placement_type() == &"" and main.planning.combat == before, "Committed Ready blocks both B and the button callback")
	main.planning._host_ready[0] = false
	main.planning._publish_snapshot()
	await _settle()
	await _click(screen.build_another_button.get_global_rect().get_center())
	_check(screen._placement_type() == &"arrow_tower", "Clearing the Ready lock restores native Build another placement")
	var coins: int = main.planning.combat["coins"][0]
	var cost: int = main.planning.combat["tower_types"]["arrow_tower"]["cost"]
	var count: int = main.planning.combat["towers"][0].size()
	main.planning._host_combat._roll_random.seed = 81
	random_state = main.planning._host_combat._roll_random.state
	await _click(screen.world.cell_screen_position(0, Vector2i(6, 2)))
	var placed: Dictionary = screen._selected_tower()
	var mirrored: Dictionary = main.planning.combat["towers"][1][-1]
	_check(not placed.is_empty() and placed["id"] != source_id and not placed["damage_upgraded"] and not placed["speed_upgraded"] and not placed["special_upgraded"] and placed["attribute_rerolls"] == 0 and placed["rarity_rerolls"] == 0 and main.planning._host_combat._roll_random.state != random_state, "Paid Build another creates a fresh base tower, never cloning source upgrades or trait rolls")
	_check(main.planning.combat["towers"][0].size() == count + 1 and main.planning.combat["towers"][1].size() == count + 1 and main.planning.combat["coins"] == [coins - cost, coins - cost] and placed["rarity"] == mirrored["rarity"] and placed["attributes"] == mirrored["attributes"], "The ordinary purchase charges both mirrors once and mirrors one newly accepted roll")
	main.planning.debug_set_values(1, 10000, 8)
	await _click(screen.world.cell_screen_position(0, Vector2i(4, 2)))
	for command: String in ["speed", "special", "four_archers", "eight_archers"]:
		main.planning.upgrade_tower(0, source_id, command)
	await _settle()
	_check(screen._selected_tower().get("advancement", "") == "eight_archers", "Long inspector fixture reaches Eight Archers")
	var scroll := screen._management.find_child("InspectionScroll", true, false) as ScrollContainer
	var title_rect: Rect2 = screen._tower_title.get_global_rect()
	var close_rect: Rect2 = screen.close_button.get_global_rect()
	var build_rect: Rect2 = screen.build_another_button.get_global_rect()
	_check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Eight independent weapons require real inspector scrolling")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	_check(screen._tower_title.get_global_rect() == title_rect and screen.close_button.get_global_rect() == close_rect and screen.build_another_button.get_global_rect() == build_rect, "Tower identity, close and Build another stay pinned while long stats scroll")
	before = main.planning.combat.duplicate(true)
	await _click(screen.close_button.get_global_rect().get_center())
	_check(not screen._management.visible and main.planning.combat == before, "Pinned X dismisses a scrolled inspector without changing gameplay")


func _finish() -> void:
	main.planning.stop_singleplayer()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS: native repeat and Build another placement, fresh paid/free towers, mirrored prices, guards, Escape, and Sandbox restart/speed controls")
	quit.call_deferred(1 if failures else 0)


func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _guarded_key(code: Key, variant: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.echo = pressed and variant == "echo"
		event.ctrl_pressed = variant == "ctrl"
		event.alt_pressed = variant == "alt"
		event.meta_pressed = variant == "meta"
		Input.parse_input_event(event)
		await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		if code >= KEY_0 and code <= KEY_9:
			event.unicode = code
		elif code >= KEY_A and code <= KEY_Z:
			event.unicode = code + 32
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	for index: int in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
