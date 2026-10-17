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
		tower.reward = source.towers[index].reward.duplicate() as TowerReward
		tower.reward.id = StringName("catalog_tower_%d" % index)
		tower.reward.title = "Catalog tower %d" % index
		catalog.towers.append(tower)
	var enemy: EnemyDefinition = source.enemies[0].duplicate() as EnemyDefinition
	enemy.id = &"catalog_scout"
	enemy.title = "Catalog scout"
	enemy.send_first_wave = 1
	catalog.enemies = [enemy]
	return catalog


func _check_validation() -> void:
	var catalog: ContentCatalog = _variant_catalog()
	_check(catalog.validation_errors().is_empty(), "Unknown stable IDs are valid without shipped identities")
	catalog.starter_tower_id = catalog.towers[0].reward.id
	_check(catalog.validation_errors().is_empty(), "A custom registered tower can be the guaranteed starter")
	catalog.starter_tower_id = &"unregistered_starter"
	_check(not catalog.validation_errors().is_empty(), "A guaranteed starter must resolve within its injected catalog")
	catalog.starter_tower_id = &""
	_check(catalog.validation_errors().is_empty(), "Injected catalogs may omit a guaranteed starter")
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


func _check_directional_validation() -> void:
	var catalog: ContentCatalog = _variant_catalog()
	var art: TowerReward = catalog.towers[0].reward
	var canvas: Texture2D = ImageTexture.create_from_image(Image.create(192, 192, false, Image.FORMAT_RGBA8))
	var wrong_canvas: Texture2D = ImageTexture.create_from_image(Image.create(96, 192, false, Image.FORMAT_RGBA8))
	art.icon_texture = canvas
	art.board_texture = canvas
	art.directional_weapon_textures.resize(8)
	art.directional_weapon_textures.fill(canvas)
	art.directional_projectile_origins.resize(8)
	art.directional_projectile_origins.fill(Vector2(96, 77))
	_check(catalog.validation_errors().is_empty(), "Eight aligned directional layers and finite bolt tips are admitted")
	art.icon_texture = wrong_canvas
	art.board_texture = wrong_canvas
	art.directional_weapon_textures.fill(wrong_canvas)
	art.directional_projectile_origins.fill(Vector2(48, 77))
	_check(catalog.validation_errors().is_empty(), "Aligned directional canvases are not restricted to this Ballista's dimensions")
	var empty_canvas: Texture2D = ImageTexture.new()
	art.icon_texture = empty_canvas
	art.board_texture = empty_canvas
	art.directional_weapon_textures.fill(empty_canvas)
	_check(not catalog.validation_errors().is_empty(), "Zero-sized directional canvases are rejected")
	art.icon_texture = canvas
	art.board_texture = canvas
	art.directional_weapon_textures.fill(canvas)
	art.directional_projectile_origins.fill(Vector2(96, 77))
	art.directional_weapon_textures.resize(7)
	_check(not catalog.validation_errors().is_empty(), "Partial directional texture arrays are rejected")
	art.directional_weapon_textures.append(canvas)
	art.directional_projectile_origins.resize(7)
	_check(not catalog.validation_errors().is_empty(), "Partial directional origin arrays are rejected")
	art.directional_projectile_origins.append(Vector2(96, 77))
	art.directional_weapon_textures[3] = null
	_check(not catalog.validation_errors().is_empty(), "Every directional pose requires a texture")
	art.directional_weapon_textures[3] = wrong_canvas
	_check(not catalog.validation_errors().is_empty(), "Directional weapon canvases must match the fixed icon canvas")
	art.directional_weapon_textures[3] = canvas
	art.board_texture = null
	_check(not catalog.validation_errors().is_empty(), "Directional metadata requires a fixed base")
	art.board_texture = wrong_canvas
	_check(not catalog.validation_errors().is_empty(), "Fixed base and directional icon canvases must match")
	art.board_texture = canvas
	art.icon_texture = null
	_check(not catalog.validation_errors().is_empty(), "Directional metadata requires its framing icon")
	art.icon_texture = wrong_canvas
	_check(not catalog.validation_errors().is_empty(), "Directional icon framing must match every base and weapon canvas")
	art.icon_texture = canvas
	for invalid: Vector2 in [Vector2(NAN, 1), Vector2(1, INF), Vector2(-1, 77), Vector2(96, -1), Vector2(192, 77), Vector2(96, 192)]:
		art.directional_projectile_origins[5] = invalid
		_check(not catalog.validation_errors().is_empty(), "Nonfinite or out-of-canvas directional tips are rejected: %s" % invalid)
	art.directional_projectile_origins[5] = Vector2(96, 77)
	art.directional_weapon_textures.clear()
	_check(not catalog.validation_errors().is_empty(), "Origins without directional textures are rejected")
	art.directional_weapon_textures.resize(8)
	art.directional_weapon_textures.fill(canvas)
	art.directional_projectile_origins.clear()
	_check(not catalog.validation_errors().is_empty(), "Directional textures without origins are rejected")
	art.directional_weapon_textures.clear()
	art.board_texture = null
	_check(catalog.validation_errors().is_empty(), "Empty directional arrays preserve legacy artwork without a board-only base")


func _check_behavior_validation() -> void:
	var catalog: ContentCatalog = _variant_catalog()
	for tower: TowerDefinition in catalog.towers:
		var kind: String = tower.behavior_kind
		var config: Dictionary = tower.behavior_config.duplicate(true)
		var effects: Dictionary = tower.upgrade_effects.duplicate(true)
		var attributes: PackedStringArray = tower.roll_attributes.duplicate()
		var profile: String = tower.roll_profile
		tower.behavior_kind = "unimplemented_behavior"
		_check(not catalog.validation_errors().is_empty(), "Unknown behavior kinds are rejected for %s" % kind)
		tower.behavior_kind = kind
		tower.roll_profile = "economy" if profile != "economy" else "attack"
		_check(not catalog.validation_errors().is_empty(), "Roll profiles must match the %s role" % kind)
		tower.roll_profile = profile
		tower.roll_attributes.append("damage" if kind in ["support", "economy"] else "economy_production")
		_check(not catalog.validation_errors().is_empty(), "Cross-role roll attributes are rejected for %s" % kind)
		tower.roll_attributes = attributes.duplicate()
		if not attributes.is_empty():
			tower.roll_attributes.append(attributes[0])
			_check(not catalog.validation_errors().is_empty(), "Duplicate roll attributes are rejected for %s" % kind)
			tower.roll_attributes = attributes.duplicate()
		tower.behavior_config["unimplemented_effect"] = 1
		_check(not catalog.validation_errors().is_empty(), "Unknown behavior configuration fields are rejected for %s" % kind)
		tower.behavior_config = config.duplicate(true)
		match kind:
			"chain":
				tower.behavior_config["hit_count"] = 0
				_check(not catalog.validation_errors().is_empty(), "Chain behavior requires a positive total hit count")
				tower.behavior_config = config.duplicate(true)
				tower.behavior_config["jump_distance"] = NAN
				_check(not catalog.validation_errors().is_empty(), "Chain jump distance must be finite")
			"support":
				tower.behavior_config["stack_group"] = ""
				_check(not catalog.validation_errors().is_empty(), "Support behavior requires an explicit stacking group")
				tower.behavior_config = config.duplicate(true)
				tower.behavior_config["damage_bonus"] = 0.0
				tower.behavior_config["attack_speed_bonus"] = 0.0
				_check(not catalog.validation_errors().is_empty(), "Support behavior cannot provide an empty aura")
				tower.upgrade_effects["damage"] = {"income_bonus": 0.1}
			"economy":
				tower.behavior_config["periodic_income"] = 1
				tower.behavior_config["periodic_interval"] = 0.0
				_check(not catalog.validation_errors().is_empty(), "Periodic income requires a positive simulation interval")
				tower.behavior_config = config.duplicate(true)
				tower.behavior_config["clear_income"] = 0
				_check(not catalog.validation_errors().is_empty(), "Economy behavior requires positive clear income")
				tower.upgrade_effects["speed"] = {"attack_speed_bonus": 0.1}
		tower.behavior_config = config
		if kind in ["support", "economy"]:
			_check(not catalog.validation_errors().is_empty(), "Passive upgrade effects must match the %s role" % kind)
		tower.upgrade_effects = effects
		_check(catalog.validation_errors().is_empty(), "Restored %s behavior, profile, and attributes remain valid" % kind)


func _check_variant_geometry_validation() -> void:
	var catalog: ContentCatalog = _variant_catalog()
	var art: TowerReward = catalog.towers[0].reward
	var variant: Dictionary = {
		"texture": art.icon_texture,
		"archer_pivot": Vector2(40, 24),
		"secondary_sprite_offset": Vector2(10, -2),
		"additional_archer_offsets": PackedVector2Array([Vector2(-12, -30), Vector2(12, -30)]),
		"portrait_bounds": Rect2(-0.8, -2.4, 1.6, 2.5),
	}
	art.board_variants = {"four_archers": variant}
	_check(catalog.validation_errors().is_empty(), "A branch can frame a taller platform and independently place its crew")
	var invalid: Array[Dictionary] = [
		{"archer_pivot": Vector2(NAN, 0)},
		{"secondary_sprite_offset": "not a position"},
		{"additional_archer_offsets": PackedVector2Array([Vector2(0, INF)])},
		{"additional_archer_offsets": [Vector2.ZERO]},
		{"portrait_bounds": Rect2(0, 0, -1, 2)},
		{"portrait_bounds": Rect2(0, 0, 1, 0)},
		{"portrait_bounds": Rect2(INF, 0, 1, 2)},
	]
	for change: Dictionary in invalid:
		var broken: Dictionary = variant.duplicate(true)
		broken.merge(change, true)
		art.board_variants = {"four_archers": broken}
		_check(not catalog.validation_errors().is_empty(), "Malformed branch rig/frame metadata cannot enter a playable catalog")


func _check_null_art_scene() -> void:
	var reward := TowerReward.new()
	reward.id = &"no_art_fixture"
	reward.title = "Rule fixture"
	var tower := TowerDefinition.new()
	tower.reward = reward
	var catalog := ContentCatalog.new()
	catalog.towers = [tower]
	_check(catalog.validation_errors().is_empty(), "Non-rendered rule fixtures may omit tower artwork")
	var board := PathBoard.new()
	board.content_catalog = catalog
	board.layout = PathLayout.new(Vector2i(5, 5), 20, Vector2i(0, 2), Vector2i(4, 2))
	board.size = Vector2(400, 400)
	board.command_mode = true
	board.tower_types = {"no_art_fixture": {"range": 3.0, "interval": 0.75, "area_attack": false}}
	root.add_child(board)
	var drops: Array = []
	board.tower_dropped.connect(func(cell: Vector2i, type_id: StringName) -> void: drops.append([cell, type_id]))
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		board.combat_towers = []
		var cell := Vector2i(1, 1)
		board._drop_data(board.cell_center(cell), {"tower_type": "no_art_fixture"})
		_check(drops.size() == 1 and drops[0] == [cell, &"no_art_fixture"], "A registered no-art fixture remains placeable in either orientation")
		drops.clear()
		board._drop_data(board.cell_center(cell), {"tower_type": "unregistered_fixture"})
		_check(drops.is_empty(), "Null-art support does not admit unregistered tower identities")
		board.combat_towers = [{"id": 1, "cell": cell, "type_id": "no_art_fixture"}]
		await process_frame
		_check(is_finite(board.visual_headroom()), "An active board can frame registered no-art fixtures")
	board.queue_free()
	await process_frame


func _run() -> void:
	_check_validation()
	_check_directional_validation()
	_check_behavior_validation()
	_check_variant_geometry_validation()
	await _check_null_art_scene()
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
	var loadout: Array[StringName] = []
	for definition: TowerDefinition in catalog.towers.slice(0, 4):
		loadout.append(definition.reward.id)
	_check(planning.select_loadout(loadout) and planning.commit_loadout(), "Injected six-type catalog admits an owned first-four deck")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	_check(screen.shop_buttons.size() == catalog.towers.size() and screen.shop_buttons.has(&"catalog_tower_0") and screen.shop_buttons[&"catalog_tower_0"].visible, "Actual placement palette uses the injected catalog and committed deck, not default rewards")
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
			var first_tip: Vector2 = board._projectile_origin(primary)
			var second_tip: Vector2 = board._projectile_origin(secondary)
			_check(not first_tip.is_equal_approx(second_tip), "Custom two-archer content captures distinct physical projectile tips")
			_check(board._projectile_position(primary).is_equal_approx(first_tip), "A new projectile begins exactly at its captured held-arrow tip")
			var captured_tip: Vector2 = first_tip
			planning._host_combat.towers[0][0]["aim"] = Vector2(12, 0)
			planning._publish_snapshot()
			_check(board._projectile_origin(primary).is_equal_approx(captured_tip), "Later accepted aim cannot drag a custom variant's in-flight source")
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
	quit.call_deferred(1 if failures else 0)
