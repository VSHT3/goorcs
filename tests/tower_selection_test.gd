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
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	_check(_ids(screen) == ["", "orc_ballista"], "Saved Ballista is selectable while locked Arrow and Rune stay absent")
	screen.tower_menu.select(1)
	screen.tower_menu.item_selected.emit(1)
	main.planning.changed.emit()
	_check(screen._placement_type() == &"orc_ballista", "Combat refresh preserves selection by stable resource identity")
	var opened: ChestResult = main.collection_store.open_chest()
	_check(opened.error_message.is_empty(), "Real chest grant succeeds in isolated save")
	main.planning.changed.emit()
	_check(_ids(screen).has(String(opened.rewards[0].id)) and screen._placement_type() == &"orc_ballista", "Newly granted tower enters the menu without changing the existing selection")
	main.collection_store.reset_progress()
	main.planning.changed.emit()
	_check(_ids(screen) == [""] and screen._placement_type() == &"", "Reset removes placement options and cancels selection; no free locked Arrow remains")
	main.queue_free()
	await process_frame
	# A fourth resource proves the menu has no three-tower identity switch.
	var custom: TowerReward = CollectionStore.DEFAULT_CATALOG[0].duplicate()
	custom.id = &"test_watchtower"
	custom.title = "Test watchtower"
	var definition := TowerDefinition.new()
	definition.reward = custom
	definition.damage = 3
	definition.range_cells = 2.0
	definition.interval = 0.5
	var rules := CombatRules.new()
	rules.tower_definitions = [definition]
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["test_watchtower"]}))
	main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path, [custom])
	main.combat_rules = rules
	root.add_child(main)
	await process_frame
	screen = main.play_screen.planning_screen
	_check(_ids(screen) == ["", "test_watchtower"], "Custom catalog and combat resources automatically expose a fourth tower")
	screen.tower_menu.select(1)
	screen.tower_menu.item_selected.emit(1)
	_check(screen._placement_type() == custom.id, "Custom tower selection carries the resource ID rather than a menu index")
	main.queue_free()
	await process_frame
	rules.tower_definitions = []
	main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path, [custom])
	main.combat_rules = rules
	root.add_child(main)
	await process_frame
	_check(_ids(main.play_screen.planning_screen) == [""], "Unlocked types without a host combat definition cannot be selected")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: saved unlocks gate tower menu, chest grants refresh roster, selection survives snapshots, reset cancels placement, and a fourth resource needs no UI branch")
	quit(1 if failures else 0)


func _ids(screen: MatchPlanningScreen) -> Array[String]:
	var ids: Array[String] = []
	for index: int in range(screen.tower_menu.item_count):
		ids.append(String(screen.tower_menu.get_item_metadata(index)))
	return ids


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
