extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _variant_catalog() -> ContentCatalog:
	var source: ContentCatalog = preload("res://resources/content_catalog.tres")
	var catalog := ContentCatalog.new()
	for index: int in range(source.towers.size()):
		var tower: TowerDefinition = source.towers[index].duplicate(true) as TowerDefinition
		tower.reward.id = StringName("catalog_tower_%d" % index)
		tower.reward.title = "Catalog tower %d" % index
		catalog.towers.append(tower)
	var enemy: EnemyDefinition = source.enemies[0].duplicate() as EnemyDefinition
	enemy.id = &"catalog_scout"
	enemy.title = "Catalog scout"
	catalog.enemies = [enemy]
	return catalog


func _check_validation() -> void:
	var catalog: ContentCatalog = _variant_catalog()
	_check(catalog.validation_errors().is_empty(), "Unknown stable IDs are valid without shipped identities")
	catalog.towers.append(catalog.towers[0])
	_check(not catalog.validation_errors().is_empty(), "Duplicate tower IDs are rejected")
	catalog.towers.pop_back()
	catalog.enemies.append(catalog.enemies[0])
	_check(not catalog.validation_errors().is_empty(), "Duplicate enemy IDs are rejected")
	catalog.enemies.pop_back()
	catalog.towers.append(null)
	_check(not catalog.validation_errors().is_empty(), "Missing tower definitions are rejected")
	catalog.towers.pop_back()
	catalog.enemies[0].id = &""
	_check(not catalog.validation_errors().is_empty(), "Empty enemy IDs are rejected")
	catalog.enemies[0].id = &"catalog_scout"
	catalog.towers[0].interval = NAN
	_check(not catalog.validation_errors().is_empty(), "Nonfinite attack intervals are rejected")
	catalog.towers[0].interval = 0.75
	catalog.towers[0].special_upgrade = "unimplemented_mechanic"
	_check(not catalog.validation_errors().is_empty(), "Resources cannot invent unimplemented mechanics")
	catalog.towers[0].special_upgrade = "second_archer"
	catalog.enemies[0].spawn_weight = 0
	_check(not catalog.validation_errors().is_empty(), "Nonpositive enemy weights are rejected")
	var first_rules := CombatRules.new()
	var second_rules := CombatRules.new()
	var registered: Array[TowerDefinition] = second_rules.catalog.towers.duplicate()
	first_rules.catalog.towers = []
	_check(second_rules.catalog.towers == registered, "Injected registration edits do not mutate another rules instance")


func _run() -> void:
	_check_validation()
	var catalog: ContentCatalog = _variant_catalog()
	var directory: String = OS.get_temp_dir().path_join("gorcs_catalog_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path: String = directory.path_join("collection.json")
	var store := CollectionStore.new(save_path, catalog)
	while store.can_open():
		var grant: ChestResult = store.open_chest()
		_check(grant.error_message.is_empty() and not grant.rewards.is_empty(), "Custom rewards save before presentation")
		if not grant.error_message.is_empty() or grant.rewards.is_empty():
			break
	var restored := CollectionStore.new(save_path, catalog)
	_check(restored.unlocked_count() == catalog.towers.size(), "Custom stable IDs survive the unchanged collection save format")
	var rules := CombatRules.new()
	rules.catalog = catalog
	rules.starting_coins = 5000
	rules.enemy_health = 1000
	rules.enemy_speed = 0.0
	rules.wave_weight = 2
	rules.wave_weight_growth = 0
	rules.spawn_interval = 0.0
	catalog.towers[0].range_cells = 20.0
	var main = preload("res://scenes/main.tscn").instantiate()
	main.combat_rules = rules
	main.collection_store = restored
	root.add_child(main)
	await process_frame
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	main.planning.set_physics_process(false)
	var planning: MatchPlanning = main.planning
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	_check(screen.shop_buttons.size() == catalog.towers.size() and screen.shop_buttons.has(&"catalog_tower_0"), "Actual placement palette uses the injected catalog, not default rewards")
	_check(screen.enemy_selector.item_count == 1 and screen.enemy_selector.get_item_metadata(0) == "catalog_scout", "Send menu accepts a catalog with no shipped enemy IDs")
	for board: PathBoard in screen.boards:
		_check(board.content_catalog == catalog and board._tower_art.has("catalog_tower_0") and board._enemy_art.has("catalog_scout"), "Both board renderers use the same injected registry")
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)
	screen.shop_buttons[&"catalog_tower_0"].pressed.emit()
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	_check(planning.combat["towers"][0].size() == 1 and planning.combat["towers"][1].size() == 1, "Unknown tower placement flows through UI, collection gate, and mirrored host validator")
	if not planning.combat["towers"][0].is_empty():
		var tower_id: int = int(planning.combat["towers"][0][0]["id"])
		for upgrade: String in ["damage", "speed", "special"]:
			planning.upgrade_tower(0, tower_id, upgrade)
		screen.enemy_selector.item_selected.emit(0)
		screen.send_button.pressed.emit()
		_check(planning.combat["income"] == [2, 2] and planning.combat["send_queues"] == [["catalog_scout"], ["catalog_scout"]], "Unknown enemy send keeps host-owned purchase, mirror, income, and FIFO identity")
		planning.submit_ready(true)
		_check(planning.combat["phase"] == MatchCombat.Phase.WAVE and planning.combat["wave_roster"] == ["catalog_scout", "catalog_scout"], "A custom weight-one remainder enemy fills regular waves without Grunt")
		planning._host_combat.advance(0.01)
		planning._publish_snapshot()
		var accepted: Dictionary = planning.combat
		_check(accepted["tower_types"].has("catalog_tower_0") and accepted["enemy_types"].has("catalog_scout") and accepted["enemies"][0][0]["type_id"] == "catalog_scout", "Accepted snapshots retain new definitions and instance identities")
		var board: PathBoard = screen.boards[0]
		_check(board._shot_traces.size() == 2, "An unknown second-archer variant captures both existing projectile streams")
		if board._shot_traces.size() == 2:
			var primary: Dictionary = board._shot_traces[0]
			var secondary: Dictionary = board._shot_traces[1]
			var artwork: TowerReward = catalog.towers[0].reward
			var foot: Vector2 = board.cell_center(primary["cell"]) + Vector2(0, board._cell_size() * 0.28)
			var rect: Rect2 = board._sprite_rect(artwork.icon_texture, artwork.board_height, artwork.board_anchor, foot)
			var expected: Vector2 = rect.position + artwork.projectile_origin * rect.size / artwork.icon_texture.get_size()
			_check(board._projectile_origin(primary).is_equal_approx(expected), "Unknown tower muzzle uses authored texture-local coordinates")
			var offset: Vector2 = artwork.secondary_sprite_offset * rect.size / artwork.icon_texture.get_size()
			_check((board._projectile_origin(secondary) - board._projectile_origin(primary)).is_equal_approx(offset), "Unknown secondary projectile uses the authored overlay offset")
		var captured: Dictionary = accepted["enemy_types"].duplicate(true)
		catalog.enemies[0].send_cost = 1
		_check(planning._host_combat.snapshot()["enemy_types"] == captured, "Editing source definitions cannot rewrite admitted host stats")
	planning.stop_singleplayer()
	main.queue_free()
	await process_frame
	# Let the audio mix thread retire the stopped match playback before exit.
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: typed catalog validation and custom IDs across collection, actual UI, host commands, waves, snapshots, board artwork, and projectiles")
	quit(1 if failures else 0)
