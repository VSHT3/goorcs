extends SceneTree

# Planning-screen safeguards: two-press Sell, Undo clear and locked send rounds.

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	var directory: String = OS.get_temp_dir().path_join("gorcs_safeguards_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	main.combat_rules = CombatRules.new()
	root.add_child(main)
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	planning.set_physics_process(false)
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Safeguard fixture admits a mirrored solo run")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var row: int = planning.layouts[0].entrance.y
	for x: int in range(1, planning.layouts[0].dimensions.x - 1):
		planning.request_edit(0, Vector2i(x, row), true)
	_check(planning.layouts[0].is_ready(), "Fixture route is legal")
	await _sell_confirmation(planning, screen)
	await _undo_clear(planning, screen, row)
	_locked_send_rounds(planning, screen)
	main.play_screen.prepare_to_leave()
	for player: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	await create_timer(0.1).timeout
	main.queue_free()
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: two-press Sell with double-click guard and expiry, Undo clear restoring the accepted path, and locked send unlock rounds")
	quit.call_deferred(1 if failures > 0 else 0)


func _sell_confirmation(planning: MatchPlanning, screen: MatchPlanningScreen) -> void:
	_check(planning.debug_set_values(1, 1000, 8), "Fixture funds towers")
	for cell: Vector2i in [Vector2i(2, 1), Vector2i(4, 1)]:
		planning.build_tower(0, cell, &"arrow_tower", 0)
	var first: Dictionary = planning.combat["towers"][0][0]
	var second: Dictionary = planning.combat["towers"][0][1]
	screen.selected_tower_id = int(first["id"])
	screen._refresh()
	var refund: int = int(first["sell_value"])
	_check(screen.sell_button.text == "Sell · +%d" % refund and not screen.is_sell_armed(), "Sell starts unarmed with its refund")
	var before: Dictionary = planning.combat.duplicate(true)
	screen.sell_button.pressed.emit()
	_check(planning.combat == before and screen.is_sell_armed() and screen.sell_button.text == "Confirm · +%d" % refund, "First Sell press only arms the sale and spells out the refund")
	screen.sell_button.pressed.emit()
	_check(planning.combat == before and screen.is_sell_armed(), "A double-click inside the guard cannot confirm")
	screen.get_node("SellConfirmTimer").timeout.emit()
	_check(not screen.is_sell_armed() and screen.sell_button.text.begins_with("Sell") and planning.combat == before, "Unconfirmed sales expire back to Sell")
	screen.sell_button.pressed.emit()
	screen.selected_tower_id = int(second["id"])
	screen._refresh()
	_check(not screen.is_sell_armed() and screen.sell_button.text.begins_with("Sell"), "Inspecting another tower disarms the pending sale")
	screen.sell_button.pressed.emit()
	screen.cancel_interaction()
	screen.selected_tower_id = int(second["id"])
	screen._refresh()
	_check(not screen.is_sell_armed(), "Closing inspection disarms the pending sale")
	screen.sell_button.pressed.emit()
	planning._host_ready[0] = true
	planning._publish_snapshot()
	_check(not screen.is_sell_armed() and screen.sell_button.disabled, "Ready commitment disarms and disables Sell")
	planning._host_ready[0] = false
	planning._publish_snapshot()
	var coins: int = int(planning.combat["coins"][0])
	screen.sell_button.pressed.emit()
	screen._sell_armed_msec -= MatchPlanningScreen.SELL_CONFIRM_GUARD_MSEC
	screen.sell_button.pressed.emit()
	_check(planning.combat["towers"][0].size() == 1 and planning.combat["towers"][1].size() == 1 and int(planning.combat["coins"][0]) == coins + int(second["sell_value"]), "A deliberate second press sells once through the mirrored host action")
	_check(screen.selected_tower_id == -1 and not screen.is_sell_armed(), "Accepted sale clears inspection and the armed state")


func _undo_clear(planning: MatchPlanning, screen: MatchPlanningScreen, row: int) -> void:
	var original: Array[Vector2i] = planning.layouts[0].tiles()
	_check(planning.debug_set_values(10, 1000, 8) and bool(planning.combat["main_round"]) and planning.can_edit_path(0), "Fixture reaches main-round planning")
	original = planning.layouts[0].tiles()
	_check(screen.clear_button.visible and not screen.clear_button.disabled and screen.clear_button.text == "Clear path", "Main round offers Clear path")
	screen.clear_button.pressed.emit()
	_check(planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Clear empties both mirrored paths")
	_check(screen.can_undo_clear() and not screen.clear_button.disabled and screen.clear_button.text == "Undo clear", "Cleared path offers Undo clear in place")
	screen.clear_button.pressed.emit()
	_check(planning.layouts[0].used_tiles() == 0 and screen.can_undo_clear(), "A double-clicked Clear does not undo itself")
	screen._cleared_msec -= MatchPlanningScreen.SELL_CONFIRM_GUARD_MSEC
	var blocker := Vector2i(3, row)
	planning.build_tower(0, blocker, &"arrow_tower", 0)
	screen.clear_button.pressed.emit()
	var restored: Array[Vector2i] = planning.layouts[0].tiles()
	_check(restored.size() == original.size() - 1 and not restored.has(blocker) and original.all(func(cell: Vector2i) -> bool: return cell == blocker or planning.layouts[0].has_path(cell)), "Undo restores every cleared tile except one now under a tower")
	_check(planning.layouts[1].tiles().size() == restored.size(), "Restored tiles mirror through ordinary edits")
	_check(not screen.can_undo_clear() and screen.clear_button.text == "Clear path", "Undo is single-use")
	var tower_id: int = -1
	for tower: Dictionary in planning.combat["towers"][0]:
		if tower["cell"] == blocker:
			tower_id = int(tower["id"])
	planning.sell_tower(0, tower_id)
	planning.request_edit(0, blocker, true)
	_check(planning.layouts[0].is_ready(), "Fixture route is legal again")
	screen.clear_button.pressed.emit()
	planning.request_edit(0, Vector2i(1, row), true)
	_check(not screen.can_undo_clear() and screen.clear_button.text == "Clear path", "Drawing after Clear discards the undo record")
	planning.request_edit(0, Vector2i(1, row), false)
	_check(screen.clear_button.disabled and screen.clear_button.text == "Clear path", "An emptied path after drawing cannot resurrect the discarded record")
	for cell: Vector2i in original:
		planning.request_edit(0, cell, true)
	screen.clear_button.pressed.emit()
	_check(planning.debug_set_values(11, 1000, 8), "Fixture leaves the main round")
	_check(not screen.can_undo_clear(), "Leaving the strategy break discards the undo record")
	await process_frame


func _locked_send_rounds(planning: MatchPlanning, screen: MatchPlanningScreen) -> void:
	_check(planning.debug_set_values(1, 1000, 8), "Fixture returns to round 1")
	var types: Dictionary = planning.combat["enemy_types"]
	var locked: int = 0
	for index: int in range(screen.enemy_selector.item_count):
		var stats: Dictionary = types[String(screen.enemy_selector.get_item_metadata(index))]
		var text: String = screen.enemy_selector.get_item_text(index)
		var tooltip: String = screen.enemy_selector.get_item_tooltip(index)
		if bool(stats["send_available"]):
			_check(text == String(stats["title"]), "Available send %s shows only its title" % stats["title"])
		else:
			locked += 1
			_check(text == "%s · round %d" % [stats["title"], int(stats["send_first_wave"])] and screen.enemy_selector.is_item_disabled(index), "Locked send %s names its unlock round" % stats["title"])
			_check(tooltip.ends_with("Available from round %d." % int(stats["send_first_wave"])), "Locked send tooltip repeats its unlock round")
	_check(locked > 0, "Round 1 has locked send types")
	for index: int in range(1, screen.enemy_selector.item_count):
		var previous: Dictionary = types[String(screen.enemy_selector.get_item_metadata(index - 1))]
		var current: Dictionary = types[String(screen.enemy_selector.get_item_metadata(index))]
		_check(int(previous["send_first_wave"]) <= int(current["send_first_wave"]), "Send list is ordered by unlock round")
	_check(not screen.enemy_selector.text.contains(" · round "), "The selected send stays an available, untagged title")
	var brute: Dictionary = types.get("brute", {})
	if not brute.is_empty():
		_check(planning.debug_set_values(int(brute["send_first_wave"]), 1000, 8), "Fixture reaches the Brute unlock")
		for index: int in range(screen.enemy_selector.item_count):
			if String(screen.enemy_selector.get_item_metadata(index)) == "brute":
				_check(screen.enemy_selector.get_item_text(index) == String(brute["title"]) and not screen.enemy_selector.is_item_disabled(index), "Unlocking drops the round tag")
