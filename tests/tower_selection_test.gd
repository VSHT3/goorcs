extends SceneTree

var failures: int = 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_tower_selection_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path := directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["orc_ballista"]}))
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	root.add_child(main)
	await process_frame
	main.session.is_host = true
	main.planning.active = true
	main.planning.changed.emit()
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	_check(screen.shop_buttons.size() == 3, "All three collection towers remain visible")
	_check(screen.shop_buttons[&"arrow_tower"].disabled and screen.shop_buttons[&"rune_obelisk"].disabled, "Locked towers are visible but cannot be purchased")
	_check(not screen.shop_buttons[&"orc_ballista"].disabled, "Saved unlocked tower is affordable and selectable")
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	main.planning.changed.emit()
	_check(screen._placement_type() == &"orc_ballista" and screen.boards[0].cell_click_mode, "Click selection survives host snapshots and disables path strokes")
	_check(not screen.boards[1].input_enabled, "Opponent board cannot accept placement or drag commands")
	_check(screen.cancel_interaction() and screen._placement_type() == &"" and not screen.boards[0].cell_click_mode, "Cancel returns to path editing without leaving the match")
	var opened: ChestResult = main.collection_store.open_chest()
	_check(opened.error_message.is_empty(), "Real chest grant succeeds in isolated save")
	main.planning.changed.emit()
	_check(not screen.shop_buttons[opened.rewards[0].id].disabled, "Chest grant enables its previously visible locked tower")
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	main.collection_store.reset_progress()
	main.planning.changed.emit()
	_check(screen.shop_buttons.size() == 3 and screen._placement_type() == &"", "Reset cancels placement without hiding the catalog")
	for button: TowerShopButton in screen.shop_buttons.values():
		_check(button.disabled, "Reset disables every locked purchase")

	# Real model snapshots exercise owned selection, effective upgrades and stale sales.
	var model := MatchCombat.new(main.combat_rules)
	model.coins[0] = 1000
	_check(model.build(0, Vector2i(3, 3), &"orc_ballista", MatchCombat.TargetMode.CLOSEST), "Model creates tower for management consumer")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	var id: int = int(model.towers[0][0]["id"])
	_check(screen.selected_tower_id == id and screen.get_node("%TowerManagement").visible, "Owned inspection opens management")
	_check(screen.targeting_button.selected == MatchCombat.TargetMode.CLOSEST, "Selected targeting comes from host snapshot")
	_check(screen.boards[0].selected_tower_id == id and screen.boards[1].selected_tower_id == -1, "Range selection stays local to owned board")
	_check(not screen.special_upgrade.visible and not screen.onyx_ring_upgrade.visible and screen.damage_upgrade.visible and screen.speed_upgrade.visible, "Special and Rune evolutions are hidden on a fresh non-Rune tower")
	var definition: Dictionary = main.planning.combat["tower_types"]["orc_ballista"]
	_check(model.upgrade_tower(0, id, "damage"), "First real stat upgrade succeeds")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(not screen.special_upgrade.visible and screen.speed_upgrade.visible, "Special stays hidden until both stat upgrades are purchased")
	_check(model.upgrade_tower(0, id, "speed"), "Second real stat upgrade succeeds")
	model.towers[0][0]["kills"] = 7
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.damage_upgrade.disabled and screen.speed_upgrade.disabled, "Purchased upgrades cannot be bought twice in management")
	_check(screen.special_upgrade.visible and not screen.onyx_ring_upgrade.visible and not screen.damage_upgrade.visible and not screen.speed_upgrade.visible and not screen.special_upgrade.disabled, "Both purchased non-Rune stats are replaced by one affordable special action")
	model.coins[0] = 299
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.special_upgrade.disabled, "Special affordability uses its fixed 300-Coin price")
	model.coins[0] = 300
	_check(model.upgrade_tower(0, id, "special"), "Exact fixed price buys the special")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.special_upgrade.visible and screen.special_upgrade.disabled and MatchCombat.tower_level(model.towers[0][0]) == 4, "Purchased special stays visible and cannot be bought twice")
	screen.close_button.pressed.emit()
	_check(screen.selected_tower_id == -1 and model.towers[0].size() == 1, "Close clears selection without selling")
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	_check(model.sell_tower(0, id), "Model sale succeeds")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.selected_tower_id == -1 and not screen.get_node("%TowerManagement").visible, "Sold selection disappears on accepted snapshot")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["orc_ballista"]}))
	main.planning.collection_store = CollectionStore.new(save_path)
	model.coins[0] = int(definition["cost"])
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	model.coins[0] = int(definition["cost"]) - 1
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.shop_buttons[&"orc_ballista"].disabled and screen._placement_type() == &"", "Insufficient host funds disable purchase and cancel stale placement")
	_check_send_visibility(main, screen)
	await _check_rune_evolutions(main, screen)
	await _check_debug_popup(main, screen)
	main.planning.stop_singleplayer()
	main.queue_free()
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: visible locked palette, click/cancel ownership, unlock/reset, effective owned stats, upgrades, Rune evolution choices and command gates, close, sale and affordability snapshots")
	quit(1 if failures else 0)


func _check_rune_evolutions(main: Control, screen: MatchPlanningScreen) -> void:
	main.play_screen.show()
	var planning: MatchPlanning = main.planning
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["rune_obelisk"]}))
	planning.collection_store = CollectionStore.new(save_path)
	for evolution: String in ["boulders", "onyx_ring"]:
		planning.start_singleplayer()
		planning.set_physics_process(false)
		await create_timer(0.05).timeout
		var model: MatchCombat = planning._host_combat
		model.coins = [2000, 2000]
		planning.build_tower(0, Vector2i(3, 3), &"rune_obelisk", MatchCombat.TargetMode.FURTHEST)
		_check(model.towers[0].size() == 1 and model.towers[1].size() == 1, "Real planning command creates mirrored Rune fixtures")
		if model.towers[0].is_empty():
			planning.stop_singleplayer()
			await create_timer(0.2).timeout
			continue
		var tower: Dictionary = model.towers[0][0]
		var id: int = int(tower["id"])
		var price: int = int(planning.combat["tower_types"]["rune_obelisk"]["evolutions"][evolution]["cost"])
		screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
		_check(not screen.special_upgrade.visible and not screen.onyx_ring_upgrade.visible, "Both evolution buttons stay hidden at level I")
		var frozen: Dictionary = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.onyx_ring_upgrade.pressed.emit()
		for command: String in ["boulders", "onyx_ring", "special", "freeze_runes"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Hidden buttons and real evolution commands cannot bypass level-I prerequisites")
		var first: Button = screen.damage_upgrade if evolution == "boulders" else screen.speed_upgrade
		var second: Button = screen.speed_upgrade if evolution == "boulders" else screen.damage_upgrade
		first.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 2 and not screen.special_upgrade.visible and not screen.onyx_ring_upgrade.visible, "Either first stat leaves both evolution buttons hidden")
		frozen = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "A real evolution command rejects one missing prerequisite")
		second.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 3 and screen.special_upgrade.visible and screen.onyx_ring_upgrade.visible and not screen.damage_upgrade.visible and not screen.speed_upgrade.visible, "Both stat purchase orders expose exactly the two Rune evolution choices at level III")
		model.coins = [price - 1, price - 1]
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.onyx_ring_upgrade.disabled, "Both choices become unavailable one Coin short")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.onyx_ring_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Unaffordable button presses and authoritative commands leave both boards untouched")
		model.coins = [price, price]
		planning._publish_snapshot()
		_check(not screen.special_upgrade.disabled and not screen.onyx_ring_upgrade.disabled, "Exact funds enable both exclusive alternatives")
		planning._host_ready[0] = true
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.onyx_ring_upgrade.disabled, "Committed Ready disables both affordable branches")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.onyx_ring_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Committed buttons and real commands cannot purchase an evolution")
		planning._host_ready[0] = false
		planning._publish_snapshot()
		var chosen: Button = screen.special_upgrade if evolution == "boulders" else screen.onyx_ring_upgrade
		var other: Button = screen.onyx_ring_upgrade if evolution == "boulders" else screen.special_upgrade
		chosen.pressed.emit()
		for slot: int in range(2):
			var evolved: Dictionary = model.towers[slot][0]
			_check(evolved.get("evolution", "") == evolution and evolved["special_upgraded"] and MatchCombat.tower_level(evolved) == 4 and model.coins[slot] == 0, "Button command purchases the chosen evolution with exact funds on both real boards")
		_check(chosen.disabled and other.disabled, "Purchased evolution disables both exclusive choices")
		frozen = planning.combat.duplicate(true)
		chosen.pressed.emit()
		other.pressed.emit()
		for command: String in ["boulders", "onyx_ring", "special", "freeze_runes"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Purchased UI and real commands reject repeats, the other branch, and obsolete generic special")
		if evolution == "boulders":
			_check(screen.special_upgrade.visible and not screen.onyx_ring_upgrade.visible, "Boulders replaces the exclusive choices with its follow-up control")
			var followup: Dictionary = planning.combat["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"]
			var followup_price: int = int(followup["cost"])
			model.coins = [followup_price - 1, followup_price - 1]
			planning._publish_snapshot()
			_check(screen.special_upgrade.disabled, "Follow-up affordability uses the accepted Boulders configuration")
			model.coins = [followup_price, followup_price]
			planning._publish_snapshot()
			_check(not screen.special_upgrade.disabled, "Exact funds enable Boulders' second evolution")
			# A host-captured catalog, not a hardcoded UI price, governs affordability.
			planning.combat = planning.combat.duplicate(true)
			var captured_followup: Dictionary = planning.combat["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"]
			captured_followup["cost"] = followup_price + 1
			planning.changed.emit()
			_check(screen.special_upgrade.disabled, "Follow-up control follows a changed accepted catalog cost")
			planning._publish_snapshot()
			var stats_before: String = screen._tower_stats.text
			planning._host_ready[0] = true
			planning._publish_snapshot()
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			_check(screen.special_upgrade.disabled and planning.combat == frozen, "Ready also commits the follow-up purchase")
			planning._host_ready[0] = false
			planning._publish_snapshot()
			screen.special_upgrade.pressed.emit()
			for slot: int in range(2):
				_check(model.towers[slot][0].get("freeze_upgraded", false) and MatchCombat.tower_level(model.towers[slot][0]) == 5 and model.coins[slot] == 0, "Follow-up button dispatches its real command and reaches level V on both solo boards")
			_check(screen.special_upgrade.disabled and not screen.onyx_ring_upgrade.visible and screen._tower_stats.text == stats_before, "Purchased follow-up stays visible without changing continuous damage stats or reviving Onyx")
			_check(screen._tower_title.text.ends_with(MatchPlanningScreen.TOWER_LEVEL_NUMERALS[4]), "Management displays the accepted fifth tower level")
			await process_frame
			var row: Control = screen.special_upgrade.get_parent()
			_check(is_equal_approx(screen.special_upgrade.size.x, row.size.x), "Boulders follow-up uses the entire existing upgrade row")
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			planning.upgrade_tower(0, id, "freeze_runes")
			_check(planning.combat == frozen, "Purchased follow-up rejects duplicate UI and model commands")
		else:
			model.coins = [2000, 2000]
			planning._publish_snapshot()
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			planning.upgrade_tower(0, id, "freeze_runes")
			_check(planning.combat == frozen and MatchCombat.tower_level(tower) == 4 and not tower.get("freeze_upgraded", false), "Onyx never exposes or accepts the Boulders follow-up")
		planning.stop_singleplayer()
		# Let the audio mixer release each stopped solo fixture before starting another.
		await create_timer(0.2).timeout


func _check_debug_popup(main: Control, screen: MatchPlanningScreen) -> void:
	var planning: MatchPlanning = main.planning
	planning.start_singleplayer()
	planning.set_physics_process(false)
	await create_timer(0.05).timeout
	_check(screen.debug_button.visible and planning.can_debug(), "Solo exposes the compact authoritative debug control")
	var original_size: Vector2i = root.size
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		await process_frame
		var world_rect: Rect2 = screen.world.get_global_rect()
		var header: Control = screen.get_node("HUD/Header")
		var header_rect: Rect2 = header.get_global_rect()
		screen.debug_button.pressed.emit()
		await process_frame
		_check(screen.debug_popup.visible and int(screen.debug_round.value) == 1 and int(screen.debug_money.value) == int(planning.combat["coins"][0]), "Opening debug uses accepted displayed round and own money")
		_check(screen.world.get_global_rect() == world_rect and header.get_global_rect() == header_rect, "Opening the debug popup cannot reflow world or HUD at width %d" % width)
		_check(Rect2(screen.global_position, screen.size).encloses(screen.debug_button.get_global_rect()), "Tiny debug control stays inside the game surface at width %d" % width)
		var camera_position: Vector2 = screen.world.camera.position
		var camera_zoom: Vector2 = screen.world.camera.zoom
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = screen.world.size * 0.5
		screen.world._handle_camera_input(wheel)
		var key := InputEventKey.new()
		key.keycode = KEY_D
		key.pressed = true
		screen.world._handle_camera_input(key)
		screen.world._process(0.2)
		_check(screen.world.camera.position == camera_position and screen.world.camera.zoom == camera_zoom and screen.world._world_viewport.gui_disable_input, "Popup scroll, typing and board input remain isolated from the world")
		screen.debug_round.value = 1001
		screen.debug_money.value = 1000000001
		_check(int(screen.debug_round.value) == 1000 and int(screen.debug_money.value) == 1000000000, "Popup accepts the full supported upper bounds without overflowing")
		screen.debug_round.value = 0
		screen.debug_money.value = -1
		_check(int(screen.debug_round.value) == 1 and int(screen.debug_money.value) == 0, "Popup keeps both values inside the supported lower bounds")
		screen.debug_popup.hide()
		_check(not screen.world._world_viewport.gui_disable_input, "Closing debug restores board input")
	root.size = original_size
	await process_frame
	screen.debug_button.pressed.emit()
	screen.debug_round.get_line_edit().text = "31"
	screen.debug_money.get_line_edit().text = "123456"
	screen.debug_apply.pressed.emit()
	_check(not screen.debug_popup.visible and int(planning.combat["wave"]) == 30 and planning.combat["coins"] == [123456, 123456], "Apply commits typed values through the real authoritative debug operation and closes")
	screen.debug_button.pressed.emit()
	_check(int(screen.debug_round.value) == 31 and int(screen.debug_money.value) == 123456, "Reopening reflects the accepted upcoming round rather than a stale draft")
	screen.debug_popup.hide()
	planning._host_combat.phase = MatchCombat.Phase.WAVE
	planning._host_combat.wave = 31
	planning._publish_snapshot()
	screen.debug_button.pressed.emit()
	_check(int(screen.debug_round.value) == 31, "During combat debug uses the current displayed round rather than the next one")
	screen.debug_apply.pressed.emit()
	_check(int(planning.combat["phase"]) == MatchCombat.Phase.WAVE and int(planning.combat["wave"]) == 31, "Applying the same displayed round preserves ongoing combat")
	screen.debug_button.pressed.emit()
	screen.open_pause_menu()
	_check(not screen.debug_popup.visible and screen.pause_menu.visible, "Pause closes debug before opening its own input layer")
	screen._resume_match()
	screen.debug_button.pressed.emit()
	main.play_screen.hide()
	_check(not screen.debug_popup.visible, "Leaving the play screen closes the debug window")
	main.play_screen.show()
	planning.start_singleplayer()
	planning.set_physics_process(false)
	await create_timer(0.05).timeout
	var was_host: bool = main.session.is_host
	var was_state: MultiplayerSession.State = main.session.state
	var was_peer: int = planning._active_peer_id
	planning.singleplayer = false
	main.session.is_host = false
	planning.changed.emit()
	_check(not screen.debug_button.visible, "Guests never receive the debug entry point")
	screen.debug_button.pressed.emit()
	_check(not screen.debug_popup.visible, "Programmatic guest presses cannot open debug")
	main.session.is_host = true
	main.session.state = MultiplayerSession.State.CONNECTED
	planning._active_peer_id = 77
	planning.changed.emit()
	_check(screen.debug_button.visible, "An active host retains the same local debug control")
	planning.singleplayer = true
	main.session.is_host = was_host
	main.session.state = was_state
	planning._active_peer_id = was_peer
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._publish_snapshot()
	_check(not screen.debug_button.visible and not screen.debug_popup.visible, "Finished matches do not expose a revival control")
	planning.stop_singleplayer()
	await create_timer(0.2).timeout


func _check_send_visibility(main: Control, screen: MatchPlanningScreen) -> void:
	var model := MatchCombat.new(main.combat_rules)
	var income: Control = screen.get_node("%Income")
	_check(model.send_enemy(1, &"grunt"), "Opponent purchase creates a real incoming-only planning queue")
	_check(model.send_enemy(1, &"runner"), "A second purchase reserves a different type in the same incoming stream")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible, "An incoming queue remains discoverable even without local recurring income")
	var layout := PathLayout.new()
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 4))
	var routes: Array[Dictionary] = [layout.capture_routing(), layout.capture_routing()]
	_check(model.start_wave(routes), "Legal routes deliver the accepted queue")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible and model.queued_sends == [1, 0], "Incoming summary stays visible while a paced delivery remains pending")
	model.advance(main.combat_rules.send_spawn_interval)
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(not income.visible, "Delivered queues with no local income remove their obsolete HUD summary")
	_check(model.send_enemy(0, &"grunt"), "Real local send earns recurring income")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible, "Earned recurring income remains visible after immediate delivery clears queues")
	for tick: int in range(5000):
		if model.phase == MatchCombat.Phase.PLANNING:
			model.start_wave(routes)
		model.advance(1.0 / 60.0)
		if model.phase == MatchCombat.Phase.FINISHED:
			break
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(model.phase == MatchCombat.Phase.FINISHED and not income.visible, "Terminal results hide income that can no longer pay out")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
