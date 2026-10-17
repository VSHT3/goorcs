extends SceneTree

var failures: int = 0
var screen: SandboxScreen


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	screen = preload("res://scenes/sandbox_screen.tscn").instantiate() as SandboxScreen
	screen.configure(preload("res://resources/content_catalog.tres"), CombatRules.new())
	root.add_child(screen)
	screen.open()
	screen.set_physics_process(false)
	await _settle()
	_check(screen.world.boards[0].visible and not screen.world.boards[1].visible, "Sandbox renders only its isolated owned board")
	_check(screen.shop_buttons.size() == screen.catalog.towers.size(), "Whole tower catalog is visible without collection unlocks")
	_check(screen.enemy_selector.item_count == screen.catalog.enemies.size(), "Enemy selector includes every definition, including summon-only")
	for width: int in [1280, 1000]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i(width, 720)
		await _settle()
		for control: Control in [screen.play_button, screen.wave_button, screen.spawn_button, screen.round_input, screen.enemy_selector, screen.width_input, screen.height_input]:
			_check(Rect2(Vector2.ZERO, Vector2(width, 720)).encloses(control.get_global_rect()), "Sandbox controls fit compact and wide viewports")
		for button: TowerShopButton in screen.shop_buttons.values():
			_check(Rect2(Vector2.ZERO, Vector2(width, 720)).encloses(button.get_global_rect()), "Free tower palette stays inside viewport")
	var initial_world_rect: Rect2 = screen.world.get_global_rect()
	var endpoint_position: Vector2 = screen.cell_screen_position(screen.layout.entrance)
	screen._edit(screen.layout.entrance, true)
	screen._edit(screen.layout.base, false)
	_check(screen.layout.used_tiles() == 0 and screen._notice.text.is_empty(), "Endpoint strokes are silent no-ops")
	_check(screen.world.get_global_rect() == initial_world_rect and screen.cell_screen_position(screen.layout.entrance).is_equal_approx(endpoint_position), "Rejected endpoint input never changes board geometry or click positions")
	screen._show_notice("Place towers on empty ground.")
	_check(not screen._notice.text.is_empty() and screen.world.get_global_rect() == initial_world_rect, "Feedback is visible without reflowing the board")
	await screen._notice_timer.timeout
	await _settle()
	_check(screen._notice.text.is_empty() and screen.world.get_global_rect() == initial_world_rect, "Rejection feedback expires without shifting the board")
	for x: int in range(1, 13):
		screen.controller.edit_path(Vector2i(x, 4), true)
	var tower_id: StringName = &"arrow_tower"
	screen.shop_buttons[tower_id].pressed.emit()
	screen._cell_clicked(Vector2i(3, 2), MOUSE_BUTTON_LEFT)
	_check(screen.controller.combat.towers[0].size() == 1 and screen.selected_tower_id >= 0, "Free palette click places and inspects accepted tower")
	var placed_id: int = screen.selected_tower_id
	_check(screen._management.visible, "Selected tower opens fixed management overlay")
	screen._upgrade_buttons["damage"].pressed.emit()
	screen._upgrade_buttons["speed"].pressed.emit()
	_check(screen.controller.combat.towers[0][0]["damage_upgraded"] and screen.controller.combat.towers[0][0]["speed_upgraded"], "Upgrade controls call real owner with no currency gate")
	for direction: int in [1, -1]:
		var expected_modes: Array = [MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.FURTHEST] if direction == 1 else [MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.FURTHEST]
		for expected: int in expected_modes:
			await _press_cycle_button(screen.targeting.next_button if direction == 1 else screen.targeting.previous_button)
			_check(screen.controller.state["towers"][0][0]["mode"] == expected and screen.targeting.mode == expected, "Sandbox native arrows wrap in both directions through accepted targeting policies")
	screen._upgrade_buttons["special"].pressed.emit()
	screen.advancement_buttons["four_archers"].pressed.emit()
	_check(screen.controller.state["towers"][0][0]["advancement"] == "four_archers", "Sandbox exposes independent archer cycles after the real free advancement")
	await _press_cycle_button(screen.secondary_targeting.next_button)
	await _press_cycle_button(screen.third_targeting.next_button)
	await _press_cycle_button(screen.third_targeting.next_button)
	await _press_cycle_button(screen.fourth_targeting.previous_button)
	var tower: Dictionary = screen.controller.state["towers"][0][0]
	_check(tower["mode"] == MatchCombat.TargetMode.FURTHEST and tower["secondary_mode"] == MatchCombat.TargetMode.LAST and tower["extra_archers"][0]["mode"] == MatchCombat.TargetMode.CLOSEST and tower["extra_archers"][1]["mode"] == MatchCombat.TargetMode.STRONGEST, "All four sandbox archers retain distinct accepted targeting policies")
	var selectors: Array[TargetingCycle] = [screen.targeting, screen.secondary_targeting, screen.third_targeting, screen.fourth_targeting]
	var independent_modes: Array[int] = [MatchCombat.TargetMode.FURTHEST, MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST]
	for index: int in range(selectors.size()):
		_check(selectors[index].is_visible_in_tree() and selectors[index].mode == independent_modes[index], "Each sandbox archer displays its accepted enum value, not a dropdown index")
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i(width, 720)
		await _settle()
		for selector: TargetingCycle in selectors:
			for control: Control in [selector.previous_button, selector.mode_label, selector.next_button]:
				_check(screen._management.get_global_rect().encloses(control.get_global_rect()), "Four labeled sandbox cycles fit inside the compact management panel")
	var header_rect: Rect2 = screen.play_button.get_global_rect()
	screen.cancel_interaction()
	_check(not screen._management.visible and screen.play_button.get_global_rect() == header_rect, "Inspector visibility never moves fixed HUD")
	screen.width_input.get_line_edit().text = "40"
	screen.height_input.get_line_edit().text = "24"
	screen._request_resize()
	await _settle()
	_check(screen.resize_dialog.visible and screen.controller.layout.dimensions == Vector2i(14, 9), "Resize is explicitly confirmed before destructive changes")
	screen.resize_dialog.hide()
	_check(screen.controller.combat.towers[0].size() == 1 and screen.controller.layout.is_ready(), "Cancel resize preserves towers and path")
	screen._request_resize()
	screen.resize_dialog.confirmed.emit()
	screen.resize_dialog.hide()
	await _settle()
	_check(screen.controller.layout.dimensions == Vector2i(40, 24) and screen.controller.combat.towers[0].is_empty(), "Confirmed resize replaces actual map and clears build")
	_check(screen.width_input.allow_greater and screen.height_input.allow_greater, "Map fields accept dimensions beyond their arrow range")
	for x: int in range(1, 39):
		screen.controller.edit_path(Vector2i(x, 12), true)
	_check(screen.layout.used_tiles() == 38 and screen.layout.is_ready(), "Paths exceed the obsolete finite tile budget on a larger board")
	screen.round_input.value = 34
	for index: int in range(screen.enemy_selector.item_count):
		if screen.enemy_selector.get_item_metadata(index) == &"skeleorc":
			screen.enemy_selector.select(index)
	screen.count_input.get_line_edit().text = "7"
	screen.spawn_button.pressed.emit()
	_check(screen.controller.combat.enemies[0].size() == 7 and screen.controller.paused, "Exact summon-only spawning creates a paused inspectable run")
	_check(not screen.controller.combat.enemies[0].is_empty() and screen.controller.combat.enemies[0][0]["type_id"] == "skeleorc" and screen.controller.combat.wave == 34, "Enemy controls retain type and selected round")
	screen.play_button.grab_focus()
	screen._input(_key(KEY_SPACE))
	_check(not screen.controller.paused, "Space resumes direct-spawn simulation")
	screen.count_input.get_line_edit().grab_focus()
	screen._input(_key(KEY_SPACE))
	_check(not screen.controller.paused, "Typing takes priority over Space shortcut")
	screen._input(_key(KEY_ESCAPE))
	_check(screen.count_input.get_line_edit() != root.gui_get_focus_owner(), "Escape in numeric entry cancels editing, not navigation")
	screen._input(_key(KEY_SPACE))
	_check(screen.controller.paused, "Space pauses after text focus leaves")
	screen.world.pan(0.05, Vector2.RIGHT)
	var saved_camera: Vector2 = screen.world.camera.position
	var saved_state: Dictionary = screen.controller.combat.snapshot()
	screen.prepare_to_leave()
	screen.hide()
	screen.controller.advance(5.0)
	_check(screen.controller.paused and screen.controller.combat.snapshot() == saved_state, "Menu leave pauses and preserves simulation")
	screen.open()
	await _settle()
	_check(screen.controller.combat.snapshot() == saved_state and screen.controller.layout.dimensions == Vector2i(40, 24), "Reopen preserves playground instead of resetting")
	_check(screen.world.camera.position.is_equal_approx(saved_camera), "Reopen preserves local camera framing")
	_check(screen.controller.paused, "Reopened playground waits for explicit Play")
	screen._stop()
	screen.controller.build(Vector2i(3, 2), tower_id)
	screen._cell_clicked(Vector2i(3, 2), MOUSE_BUTTON_LEFT)
	var before: int = screen.controller.combat.towers[0].size()
	screen._request_reset()
	screen.reset_dialog.hide()
	_check(screen.controller.combat.towers[0].size() == before, "Reset cancellation is nondestructive")
	screen._request_reset()
	screen.reset_dialog.confirmed.emit()
	screen.reset_dialog.hide()
	_check(screen.controller.combat.towers[0].is_empty() and screen.controller.layout.is_ready(), "Reset confirmation clears build but preserves route")
	_check(placed_id >= 0, "Initial selected ID was a normal combat identifier")
	var returned: Array[bool] = []
	screen.back_requested.connect(func() -> void: returned.append(true))
	screen.play_button.grab_focus()
	screen._input(_key(KEY_ESCAPE))
	_check(returned.size() == 1 and not screen.controller.active, "Unconsumed Escape returns to menu and deactivates simulation")
	screen.queue_free()
	await _settle()
	await create_timer(maxf(0.0, AudioServer.get_time_to_next_mix()) + 0.025).timeout
	if failures == 0:
		print("PASS: sandbox screen controls, compact layout, confirmations, exact spawns, keyboard and menu persistence")
	quit(1 if failures > 0 else 0)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _settle() -> void:
	await process_frame
	await process_frame


func _press_cycle_button(button: Button) -> void:
	button.grab_focus()
	_check(button.has_focus(), "Sandbox targeting arrows support native keyboard focus")
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
