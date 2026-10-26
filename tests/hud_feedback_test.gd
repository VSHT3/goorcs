extends SceneTree

var failures: int = 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	_test_boss_rows()
	_test_status_effects()
	directory = OS.get_temp_dir().path_join("gorcs_hud_feedback_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower", "lightning", "war_drums", "rune_obelisk"]}))
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	root.add_child(main)
	await process_frame
	await _test_match(main)
	main.play_screen.prepare_to_leave()
	main._show_menu()
	await process_frame
	await _test_sandbox(main)
	main.sandbox_screen.prepare_to_leave()
	for player: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	await create_timer(0.1).timeout
	main.queue_free()
	main = null
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: boss bars follow accepted boss HP with trail/kill/leak presentation, crowd-control chips, unsplit upgrade choices and a full round label at both widths")
	quit.call_deferred(1 if failures > 0 else 0)


func _boss(id: int, hp: int, maximum: int = 1000) -> Dictionary:
	return {"id": id, "type_id": "troll", "hp": hp, "max_hp": maximum, "enraged": false, "shield_hits": 0}


func _test_boss_rows() -> void:
	var bars := BossHealthBars.new()
	bars.catalog = preload("res://resources/content_catalog.tres")
	root.add_child(bars)
	var types: Dictionary = {"troll": {"boss": true, "title": "Trollorc", "enrage_health_fraction": 0.0}, "grunt": {"boss": false, "title": "Orc"}}
	bars.refresh([{"id": 1, "type_id": "grunt", "hp": 10, "max_hp": 10}, _boss(2, 1000)], types)
	_check(bars.visible and bars.shown_ids() == [2], "Only bosses get a health row")
	var row = bars.row_for(2)
	bars.refresh([_boss(2, 600)], types)
	_check(is_equal_approx(row.hp, 600.0) and is_equal_approx(row.trail, 1000.0), "Accepted damage leaves a trail at the previous HP")
	row._process(0.1)
	_check(is_equal_approx(row.trail, 1000.0), "The trail holds briefly before draining")
	for step: int in range(40):
		row._process(0.05)
	_check(is_equal_approx(row.trail, 600.0) and not row.is_processing(), "The trail drains to the accepted HP and then stops processing")
	bars.refresh([_boss(2, 750)], types)
	_check(is_equal_approx(row.trail, 750.0), "Healing moves the bar up without a damage trail")
	bars.refresh([], types, [{"enemy_id": 2}])
	_check(row.departing and is_equal_approx(row.hp, 0.0) and row.trail >= 750.0 and bars.shown_ids().is_empty(), "A slain boss drains from its last HP to empty")
	for step: int in range(30):
		if is_instance_valid(row) and not row.is_queued_for_deletion():
			row._process(0.05)
	_check(bars.row_for(2) == null and not bars.visible, "A slain boss row fades out and is removed")
	bars.refresh([_boss(3, 500)], types)
	row = bars.row_for(3)
	bars.refresh([], types, [])
	_check(row.departing and is_equal_approx(row.hp, 500.0), "A leaked boss fades without pretending it was killed")
	bars.refresh([_boss(3, 900)], types)
	_check(bars.row_for(3) != row and not bars.row_for(3).departing, "A reused ID after reset gets a fresh row")
	bars.clear()
	var many: Array = []
	for id: int in range(10, 15):
		many.append(_boss(id, 100))
	bars.refresh(many, types)
	_check(bars.shown_ids() == [10, 11, 12], "At most three rows, in stable spawn order")
	var enraged: Dictionary = _boss(10, 40, 100)
	enraged["enraged"] = true
	bars.refresh([enraged], types)
	_check(bars.row_for(10).enraged and bars.row_for(11).departing, "Rows follow accepted boss state and departures")
	bars.queue_free()


func _test_status_effects() -> void:
	var tower: Dictionary = {"id": 1, "element": "magic", "stunned_remaining": 0.0, "wither": 0.0, "wither_remaining": 0.0}
	_check(TowerStatusStrip.effects(tower, 0.0).is_empty(), "A free tower shows no status")
	tower["stunned_remaining"] = 4.25
	tower["wither"] = 0.5
	tower["wither_remaining"] = 2.0
	var kinds: Array = TowerStatusStrip.effects(tower, 3.0).map(func(effect: Dictionary) -> String: return effect["kind"])
	_check(kinds == ["stun", "wither", "silence"], "Stun, Soulfire wither and Nullify silence all surface on a Magic tower")
	tower["element"] = "physical"
	kinds = TowerStatusStrip.effects(tower, 3.0).map(func(effect: Dictionary) -> String: return effect["kind"])
	_check(kinds == ["stun", "wither"], "Nullify only silences Magic towers")
	_check(String(TowerStatusStrip.effects(tower, 0.0)[1]["value"]).begins_with("-50%"), "Wither shows its accepted damage cut")


func _layout_widths(width: int) -> void:
	root.size = Vector2i(width, 720)
	root.content_scale_size = Vector2i(width, 720)


func _words_fit(button: Button) -> bool:
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var room: float = button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
	for line: String in button.text.split("\n"):
		for word: String in line.split(" ", false):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room + 0.5:
				return false
	return true


func _choice_buttons(row: Control) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in row.get_children():
		if child is Button and (child as Button).visible:
			result.append(child)
	return result


func _test_match(main) -> void:
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	planning.set_physics_process(false)
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower", &"lightning", &"war_drums", &"rune_obelisk"]) and planning.commit_loadout(), "HUD fixture commits a four-tower deck")
	_check(planning.debug_set_values(60, 50000, 50), "Solo debug selects the Trollorc debut round")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var layout: PathLayout = planning.layouts[0]
	var step: int = 1 if layout.base.x > layout.entrance.x else -1
	var x: int = layout.entrance.x + step
	while x != layout.base.x:
		planning.request_edit(0, Vector2i(x, layout.entrance.y), true)
		x += step
	_check(planning.layouts[0].is_ready(), "Straight fixture route is legal")
	var drums_cell: Vector2i = preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(layout.entrance.x + step * 4, layout.entrance.y + 1))
	planning.build_tower(0, drums_cell, &"war_drums", 0)
	var arrow_cell: Vector2i = preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(layout.entrance.x + step * 2, layout.entrance.y - 1))
	planning.build_tower(0, arrow_cell, &"arrow_tower", 0)
	var drums_id: int = -1
	var arrow_id: int = -1
	for tower: Dictionary in planning.combat["towers"][0]:
		if Vector2i(tower["cell"]) == drums_cell:
			drums_id = int(tower["id"])
		if Vector2i(tower["cell"]) == arrow_cell:
			arrow_id = int(tower["id"])
	planning.upgrade_tower(0, drums_id, "damage")
	planning.upgrade_tower(0, drums_id, "speed")
	for width: int in [1280, 1000]:
		_layout_widths(width)
		screen._cell_clicked(drums_cell, MOUSE_BUTTON_LEFT, 0)
		await process_frame
		await process_frame
		var status: Label = screen._status
		var font: Font = status.get_theme_font("font")
		_check(status.size.x + 0.5 >= font.get_string_size(status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, status.get_theme_font_size("font_size")).x, "Round label is not clipped at %dpx" % width)
		var header: Control = screen.get_node("HUD/Header")
		_check(header.get_global_rect().encloses(screen.menu_button.get_global_rect()) and header.get_global_rect().encloses(screen.enemy_selector.get_global_rect()), "Header controls stay inside the header at %dpx" % width)
		var choices: Array[Button] = _choice_buttons(screen._upgrade_row)
		_check(choices.size() == 4, "War Drums offers its four branches")
		var rows: Dictionary = {}
		for button: Button in choices:
			rows[roundi(button.get_global_rect().position.y)] = true
			_check(_words_fit(button), "Branch '%s' keeps whole words at %dpx" % [button.text.get_slice("\n", 0), width])
			for other: Button in choices:
				if other != button:
					_check(not button.get_global_rect().intersects(other.get_global_rect()), "Branch buttons never overlap")
		_check(rows.size() == 2, "Four branches that cannot fit one row wrap into balanced rows of two at %dpx" % width)
		_check(screen.sell_button.get_global_rect().position.y >= choices[-1].get_global_rect().end.y, "Sell stays below every branch choice")
		screen._cell_clicked(arrow_cell, MOUSE_BUTTON_LEFT, 0)
		await process_frame
		await process_frame
		var base_choices: Array[Button] = _choice_buttons(screen._upgrade_row)
		var base_rows: Dictionary = {}
		for button: Button in base_choices:
			base_rows[roundi(button.get_global_rect().position.y)] = true
		_check(base_choices.size() == 2 and base_rows.size() == 1, "Choices that fit stay side by side in one row")
	_check(not screen.tower_status.visible, "An unaffected tower shows no status chips")
	planning.submit_ready(true)
	var host: MatchCombat = planning._host_combat
	var troll_id: int = -1
	for tick: int in range(2400):
		host.advance(0.05)
		for enemy: Dictionary in host.enemies[0]:
			if String(enemy["type_id"]) == "troll":
				troll_id = int(enemy["id"])
		if troll_id >= 0:
			break
	_check(troll_id >= 0, "The guaranteed Trollorc actually spawns in the real wave")
	var arrow: Dictionary = {}
	for tower: Dictionary in host.towers[0]:
		if int(tower["id"]) == arrow_id:
			arrow = tower
	host._stun_tower(0, arrow, 6.0, "club", Vector2(arrow["cell"]))
	planning._publish_snapshot()
	var before: Dictionary = planning.combat.duplicate(true)
	screen._refresh()
	var boss_ids: Array[int] = []
	for enemy: Dictionary in planning.combat["enemies"][0]:
		if bool(planning.combat["enemy_types"][String(enemy["type_id"])]["boss"]):
			boss_ids.append(int(enemy["id"]))
	boss_ids.sort()
	_check(screen.boss_bars.visible and troll_id in screen.boss_bars.shown_ids() and screen.boss_bars.shown_ids() == boss_ids.slice(0, BossHealthBars.MAX_ROWS), "Every boss on your board, and only bosses, gets a health row")
	_check(planning.combat == before, "Refreshing boss rows never changes accepted match state")
	for width: int in [1280, 1000]:
		_layout_widths(width)
		screen._cell_clicked(arrow_cell, MOUSE_BUTTON_LEFT, 0)
		await process_frame
		await process_frame
		_check(screen.tower_status.visible and screen.tower_status.active_kinds() == ["stun"], "The inspected stunned tower shows its stun")
		var chips: Rect2 = screen.tower_status.get_global_rect()
		_check(screen._tower_title.get_global_rect().end.y <= chips.position.y + 0.5 and screen._management.get_global_rect().encloses(chips), "Status chips sit pinned under the title inside the panel")
		var bars: Rect2 = screen.boss_bars.get_global_rect()
		_check(Rect2(Vector2.ZERO, Vector2(width, 720)).encloses(bars), "Boss rows stay on screen at %dpx" % width)
		_check(not bars.intersects(screen._management.get_global_rect()) and not bars.intersects(screen.get_node("HUD/Bottom").get_global_rect()) and not bars.intersects(screen.get_node("HUD/Header").get_global_rect()), "Boss rows clear the management panel and HUD bands at %dpx" % width)
	var row: Control = screen.boss_bars.row_for(troll_id)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	row._gui_input(click)
	_check(screen.selected_enemy_id == troll_id and screen._enemy_inspector.visible and not screen._management.visible, "Clicking a boss row inspects that boss")
	_check(screen.boss_bars.selected_id == troll_id, "The inspected boss row is marked")
	await process_frame
	_check(not screen._enemy_inspector.get_global_rect().intersects(screen.boss_bars.get_global_rect()), "Boss rows clear the enemy inspector")
	screen.cancel_interaction()
	host.advance(7.0)
	planning._publish_snapshot()
	screen._cell_clicked(arrow_cell, MOUSE_BUTTON_LEFT, 0)
	_check(not screen.tower_status.visible, "Status chips disappear when the accepted stun expires")
	screen.cancel_interaction()


func _test_sandbox(main) -> void:
	main.sandbox_button.pressed.emit()
	var screen: SandboxScreen = main.sandbox_screen
	var controller: SandboxController = screen.controller
	for x: int in range(1, 13):
		controller.edit_path(Vector2i(x, 4), true)
	_check(controller.build(Vector2i(6, 3), &"lightning"), "Sandbox builds a Lightning tower")
	var lightning: Dictionary = controller.combat.towers[0][0]
	screen.selected_tower_id = int(lightning["id"])
	screen._refresh()
	for width: int in [1000, 1280]:
		_layout_widths(width)
		await process_frame
		await process_frame
		for button: Button in _choice_buttons(screen._upgrade_row):
			_check(_words_fit(button), "Sandbox choice '%s' keeps whole words at %dpx" % [button.text.get_slice("\n", 0), width])
	_check(controller.spawn(&"grand_mage_orcafus", 1) and controller.spawn(&"grunt", 2), "Sandbox spawns a boss and regular orcs")
	controller.combat.towers[0][0]["wither"] = 0.5
	controller.combat.towers[0][0]["wither_remaining"] = 5.0
	controller.combat.towers[0][0]["withered_until"] = controller.combat._elapsed + 5.0
	controller._publish()
	_check(screen.tower_status.visible and screen.tower_status.active_kinds() == ["wither"], "Sandbox inspection shows Soulfire wither")
	_check(screen.boss_bars.visible and screen.boss_bars.shown_ids().size() == 1, "Sandbox shows one row for the spawned boss only")
	var boss_id: int = screen.boss_bars.shown_ids()[0]
	screen.boss_bars.boss_selected.emit(boss_id)
	_check(screen.selected_enemy_id == boss_id and screen.selected_tower_id == -1, "Sandbox boss row inspects the boss")
	_check(controller.stop(), "Stop clears the sandbox wave")
	_check(screen.boss_bars.shown_ids().is_empty(), "Cleared bosses leave the bars")
	screen.prepare_to_leave()
	_check(not screen.boss_bars.visible, "Leaving Sandbox drops boss rows")
