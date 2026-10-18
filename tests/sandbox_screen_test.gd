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
	await _check_upgrade_order(3)
	_check(screen._upgrade_buttons["special"].disabled, "Locked Second Archer remains visible beside both base stat choices")
	screen._upgrade_buttons["damage"].pressed.emit()
	_check(not screen._upgrade_buttons["damage"].visible and screen._upgrade_buttons["speed"].visible and not screen._upgrade_buttons["speed"].disabled, "Sandbox hides the purchased stat while retaining its available sibling")
	screen._upgrade_buttons["speed"].pressed.emit()
	_check(screen.controller.combat.towers[0][0]["damage_upgraded"] and screen.controller.combat.towers[0][0]["speed_upgraded"], "Upgrade controls call real owner with no currency gate")
	_check(not screen._upgrade_buttons["damage"].visible and not screen._upgrade_buttons["speed"].visible, "Sandbox removes both purchased base upgrades from inspection")
	for direction: int in [1, -1]:
		var expected_modes: Array = [MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.FURTHEST] if direction == 1 else [MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.FURTHEST]
		for expected: int in expected_modes:
			await _press_cycle_button(screen.targeting.next_button if direction == 1 else screen.targeting.previous_button)
			_check(screen.controller.state["towers"][0][0]["mode"] == expected and screen.targeting.mode == expected, "Sandbox native arrows wrap in both directions through accepted targeting policies")
	screen._upgrade_buttons["special"].pressed.emit()
	await _check_shared_targeting(2)
	await _check_upgrade_order(3)
	await _press_cycle_button(screen.advancement_buttons["four_archers"])
	_check(screen.controller.state["towers"][0][0]["advancement"] == "four_archers", "Sandbox accepts the real free four-archer advancement")
	await _check_shared_targeting(4)
	await _check_upgrade_order()
	await _check_targeting_input_guards()
	await _check_advancement_controls()
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



func _check_advancement_controls() -> void:
	await _press_cycle_button(screen.advancement_buttons["eight_archers"])
	var tower: Dictionary = screen.controller.state["towers"][0][0]
	_check(tower["advancement"] == "eight_archers" and tower["extra_archers"].size() == 6, "Native Eight Archers control purchases all eight streams")
	await _check_shared_targeting(8)
	await _check_upgrade_order()
	await _press_cycle_button(screen.advancement_buttons["arrow_minigun"])
	_check(screen.controller.state["towers"][0][0]["advancement"] == "arrow_minigun", "Native minigun purchase reaches its accepted terminal tier")
	await _check_shared_targeting(1)
	await _check_upgrade_order()
	for chain: Array in [
		["fire_arrows", "molotov", "quick_pitch", "flamethrower"],
		["bomb_arrows", "bigger_bombs", "anti_orc_grenades", "aom", "aom_speed_1", "aom_speed_2"],
	]:
		screen._sell()
		screen.shop_buttons[&"arrow_tower"].pressed.emit()
		screen._cell_clicked(Vector2i(3, 2), MOUSE_BUTTON_LEFT)
		for command: String in ["damage", "speed", "special"]:
			await _press_cycle_button(screen._upgrade_buttons[command])
		await _check_shared_targeting(2)
		await _check_upgrade_order()
		for command: String in chain:
			var button: Button = screen.advancement_buttons[command]
			_check(button.is_visible_in_tree() and not button.disabled, "Only eligible next advancement is exposed for native purchase")
			await _press_cycle_button(button)
			var accepted: Dictionary = screen.controller.state["towers"][0][0]
			_check(accepted["advancement"] == command and accepted["advancement_path"].has(command), "Native branch control reaches the accepted advancement and history")
			_check(not screen.advancement_buttons[command].is_visible_in_tree(), "Purchased advancement disappears while the next eligible purchase remains available")
			await _check_shared_targeting(1 if command in ["flamethrower", "aom", "aom_speed_1", "aom_speed_2"] else 2)
			await _check_upgrade_order()

func _check_shared_targeting(count: int) -> void:
	var selectors: int = 0
	for control: Node in screen._management.find_children("*", "HBoxContainer", true, false):
		if control is TargetingCycle and control.is_visible_in_tree():
			selectors += 1
	_check(selectors == 1, "Every Sandbox archer tier exposes one common targeting cycle")
	for direction: int in [1, -1]:
		var expected_modes: Array = [MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.FURTHEST] if direction == 1 else [MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.FURTHEST]
		for expected: int in expected_modes:
			await _press_cycle_button(screen.targeting.next_button if direction == 1 else screen.targeting.previous_button)
			var tower: Dictionary = screen.controller.state["towers"][0][0]
			var stats: Dictionary = screen.controller.state["tower_types"][tower["type_id"]]
			_check(tower["mode"] == expected and screen.targeting.mode == expected, "Sandbox native arrows update the accepted common tower policy")
			_check(MatchPlanningScreen.independent_weapon_count(tower, stats) == count and tower["extra_archers"].size() == maxi(0, count - 2), "Common Sandbox targeting retains every visual firing stream")


func _check_upgrade_order(expected_choices: int = -1) -> void:
	var original_size: Vector2i = root.size
	var scroll: ScrollContainer = screen.targeting.get_parent().get_parent().get_parent() as ScrollContainer
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = Vector2i(width, 720)
		await _settle()
		var buttons: Array = screen._upgrade_buttons.values()
		buttons.append_array(screen.advancement_buttons.values())
		var visible_buttons: Array[Button] = []
		for button: Button in buttons:
			if button.is_visible_in_tree():
				visible_buttons.append(button)
		if expected_choices >= 0:
			_check(visible_buttons.size() == expected_choices, "Sandbox exposes all %d purchase choices together" % expected_choices)
		if not visible_buttons.is_empty():
			scroll.ensure_control_visible(visible_buttons[0])
			await _settle()
			visible_buttons.sort_custom(func(left: Button, right: Button) -> bool: return left.get_global_rect().position.x < right.get_global_rect().position.x)
			var first_rect: Rect2 = visible_buttons[0].get_global_rect()
			var previous_end: float = first_rect.position.x
			for button: Button in visible_buttons:
				var button_rect: Rect2 = button.get_global_rect()
				_check(scroll.get_global_rect().encloses(button_rect), "Every Sandbox choice, including locked actions, fits simultaneously inside the inspector at width %d" % width)
				_check(is_equal_approx(button_rect.position.y, first_rect.position.y) and is_equal_approx(button_rect.size.y, first_rect.size.y), "All Sandbox purchases share one horizontal row and consistent height at width %d" % width)
				_check(button_rect.position.x >= previous_end, "Sandbox purchase choices sit side by side without overlap at width %d" % width)
				_check(button_rect.end.y <= screen.sell_button.get_global_rect().position.y, "The single Sandbox purchase row consistently precedes Sell at width %d" % width)
				var font: Font = button.get_theme_font("font")
				var font_size: int = button.get_theme_font_size("font_size")
				var text_width: float = button_rect.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
				for word: String in button.text.get_slice("\n", 0).split(" ", false):
					_check(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= text_width, "Sandbox upgrade titles retain whole readable words at width %d" % width)
				previous_end = button_rect.end.x
		scroll.ensure_control_visible(screen.sell_button)
		await _settle()
		_check(screen._management.get_global_rect().encloses(screen.sell_button.get_global_rect()), "Sandbox Sell remains the reachable final action at width %d" % width)
		scroll.ensure_control_visible(screen.targeting)
		await _settle()
		for control: Control in [screen.targeting.previous_button, screen.targeting.mode_label, screen.targeting.next_button]:
			_check(screen._management.get_global_rect().encloses(control.get_global_rect()), "One Sandbox targeting cycle fits the compact scrolled inspector at width %d" % width)
	root.size = original_size
	root.content_scale_size = original_size
	await _settle()


func _check_targeting_input_guards() -> void:
	var frozen: Dictionary = screen.controller.state.duplicate(true)
	screen.count_input.get_line_edit().grab_focus()
	for pressed: bool in [true, false]:
		var key: InputEventKey = _key(KEY_RIGHT)
		key.pressed = pressed
		root.push_input(key, true)
		await process_frame
	_check(screen.controller.state == frozen, "Typing navigation does not change the inspected common policy")
	screen._request_reset()
	await _settle()
	var point: Vector2 = screen.targeting.next_button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	_check(screen.controller.state == frozen, "A confirmation modal blocks native targeting clicks behind it")
	screen.reset_dialog.hide()
	await _settle()


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _settle() -> void:
	await process_frame
	await process_frame


func _press_cycle_button(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await _settle()
			break
		ancestor = ancestor.get_parent()
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
