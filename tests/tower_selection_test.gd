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
	var definition: Dictionary = main.planning.combat["tower_types"]["orc_ballista"]
	_check(model.upgrade_tower(0, id, "damage") and model.upgrade_tower(0, id, "speed"), "Both real one-time model upgrades succeed")
	model.towers[0][0]["kills"] = 7
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.damage_upgrade.disabled and screen.speed_upgrade.disabled, "Purchased upgrades cannot be bought twice in management")
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
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: visible locked palette, click/cancel ownership, unlock/reset, effective owned stats, upgrades, close, sale and affordability snapshots")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
