extends SceneTree

var failures: int = 0
var viewport: SubViewport
var screen: OrciearyScreen
var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")
var rules := CombatRules.new()
var store: EnemyStatisticsStore
var _directory: String
var _save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Orcieary pixel regression requires a graphical renderer.")
		quit(1)
		return
	_directory = "user://orcieary_screen_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_absolute(_directory) == OK, "Create isolated Orcieary statistics directory")
	_save_path = _directory.path_join("statistics.json")
	store = EnemyStatisticsStore.new(_save_path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1000, 720)
	viewport.world_2d = World2D.new()
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	screen = load("res://scenes/orcieary_screen.tscn").instantiate() as OrciearyScreen
	screen.configure(catalog, rules, store)
	viewport.add_child(screen)
	await _settle()
	screen.open()
	await _settle()
	_check(screen.enemy_buttons.size() == catalog.enemies.size(), "Standalone Orcieary presents every actual catalog type")
	_check(viewport.gui_get_focus_owner() == screen.enemy_buttons[0], "Opening gives real keyboard focus to the enemy list")
	await _check_keyboard_and_mouse()
	await _check_catalog_and_pixels()
	await _check_counts_and_error()
	await _check_portrait_input()
	await _check_custom_order()
	await _check_lifecycle()
	viewport.queue_free()
	await process_frame
	for path: String in [_save_path + ".tmp", _save_path, _directory]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			_check(DirAccess.remove_absolute(path) == OK, "Remove isolated Orcieary fixture")
	if failures == 0:
		print("PASS: real Orcieary focus/mouse/keyboard, complete catalog, authoritative stats/unlocks, rendered walk/special previews, compact layout, live counters, persistent errors, and leave lifecycle")
	quit(1 if failures > 0 else 0)


func _check_keyboard_and_mouse() -> void:
	await _key(KEY_DOWN)
	_check(screen.selected_index == 1 and viewport.gui_get_focus_owner() == screen.enemy_buttons[1], "Down changes both actual focus and selected enemy")
	await _key(KEY_UP)
	_check(screen.selected_index == 0, "Up returns to the previous entry")
	await _key(KEY_UP)
	_check(screen.selected_index == catalog.enemies.size() - 1, "Arrows wrap at list boundaries without losing focus")
	await _key(KEY_RIGHT)
	_check(screen.selected_index == 0, "Right also navigates the catalog")
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.portrait, "Tab exits the list to the interactive portrait")
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.back_button, "Portrait precedes Back in the focus chain")
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.enemy_buttons[0], "Tab returns to the current enemy rather than resetting selection")
	await _click(screen.enemy_buttons[3].get_global_rect().get_center())
	_check(screen.selected_index == 3 and viewport.gui_get_focus_owner() == screen.enemy_buttons[3], "A real mouse click keeps focus and selection synchronized")
	await _key(KEY_DOWN)
	_check(screen.selected_index == 4, "Keyboard continues from the mouse-selected entry")
	await _key(KEY_ENTER)
	_check(screen.selected_index == 4 and screen.enemy_buttons[4].button_pressed, "Enter preserves the selected list entry")
	for index: int in range(screen.enemy_buttons.size()):
		screen.enemy_buttons[index].pressed.emit()
		await _settle()
		_check_single_selection(index, "Programmatic activation")


func _check_catalog_and_pixels() -> void:
	for width: int in [1000, 1280]:
		viewport.size = Vector2i(width, 720)
		await _settle()
		for index: int in range(screen.entries.size()):
			var definition: EnemyDefinition = screen.entries[index]
			await _click(screen.enemy_buttons[index].get_global_rect().get_center())
			var expected: Dictionary = MatchCombat.enemy_preview(definition, rules, definition.first_wave if definition.boss else 1)
			var values: Array[Label] = []
			values.assign(screen.get_node("%Stats").get_children())
			_check(values[1].text.to_int() == int(expected["max_hp"]) and absf(values[3].text.to_float() - float(expected["speed"])) <= 0.0051 and values[5].text.to_int() == int(expected["base_damage"]), "Visible stats use the combat owner's HP, two-decimal speed, and base damage at the preview round")
			_check(screen.availability_label.get_global_rect().position.y < screen.description_label.get_global_rect().position.y, "Encounter and unlock information comes before the short description")
			if definition.regular_spawn_enabled:
				_check(screen.availability_label.text.contains(str(definition.first_wave)), "Availability exposes the definition's real regular-wave unlock")
			if definition.send_enabled:
				_check(screen.availability_label.text.contains(str(definition.send_first_wave)), "Availability exposes the separate paid-send unlock")
			else:
				_check(values[9].text == "—" and values[11].text == "—", "Summoned-only enemies do not advertise a paid price or income")
				if not definition.regular_spawn_enabled:
					var source_found: bool = false
					for source: EnemyDefinition in catalog.enemies:
						if source.summon_type == definition.id:
							source_found = screen.availability_label.text.contains(source.title)
					_check(source_found, "Summoned-only entries identify their actual catalog summoner")
			_check(_inside(screen.portrait, Rect2(Vector2.ZERO, Vector2(viewport.size))) and _inside(screen.kills_value, Rect2(Vector2.ZERO, Vector2(viewport.size))) and _inside(screen.sent_value, Rect2(Vector2.ZERO, Vector2(viewport.size))), "Preview and counters remain visible at both supported desktop widths")
			_check(screen.kills_value.get_global_rect().position.y > screen.portrait.get_global_rect().end.y, "Lifetime counters sit below the animation and stat preview")
			var stats: GridContainer = screen.get_node("%Stats") as GridContainer
			_check(stats.get_global_rect().position.y >= screen.portrait.get_global_rect().end.y, "Compact stats are below the centered animation, never beside it")
			_check_single_selection(index, "Mouse selection")
			screen.portrait.stop_preview()
			var frames: SpriteFrames = definition.animation_frames
			var finish_time: float = 1.0
			for animation: StringName in frames.get_animation_names():
				finish_time += EnemyVisuals.animation_duration(definition, animation)
			screen.portrait.replay_action()
			screen.portrait.set_preview_time(finish_time)
			var first: Image = await _portrait_image()
			var has_action: bool = frames.has_animation(&"heal") or frames.has_animation(&"cast") or frames.has_animation(&"attack")
			screen.portrait.replay_action()
			if not has_action:
				screen.portrait.set_preview_time(frames.get_frame_duration(&"walk", 0) / frames.get_animation_speed(&"walk") * 1.1)
				var walking: Image = await _portrait_image()
				_check(first.get_data() != walking.get_data(), "Replaying a walking portrait changes its rendered pose")
			else:
				var action_duration: float = EnemyVisuals.animation_duration(definition, screen.portrait.preview_animation)
				screen.portrait.set_preview_time(action_duration * 0.8)
				var special: Image = await _portrait_image()
				_check(screen.portrait.preview_animation != &"walk" and first.get_data() != special.get_data(), "Ability portraits visibly replay their authored action sequence")
				var capture_directory: String = OS.get_environment("GORCS_ORCIEARY_CAPTURE_DIR")
				if not capture_directory.is_empty():
					var path: String = capture_directory.path_join("gorcs_orcieary_%s_%d.png" % [definition.id, width])
					_check(viewport.get_texture().get_image().save_png(path) == OK, "Save requested Orcieary review capture")
				screen.portrait.set_preview_time(finish_time)
				_check(screen.portrait.preview_animation == &"walk" and screen.portrait.preview_elapsed == 0.0, "The complete authored action sequence returns to rest")


func _check_counts_and_error() -> void:
	await _click(screen.enemy_buttons[0].get_global_rect().get_center())
	var id: String = String(screen.entries[0].id)
	var snapshot: Dictionary = {"statistics_id": "screen_match", "rules": {"sandbox_mode": false}, "enemy_totals": [{"kills": {id: 12}, "sent": {id: 7}}, {"kills": {id: 99}, "sent": {id: 99}}]}
	_check(store.observe(snapshot, 0), "Save actual local counters while the screen is open")
	await _settle()
	_check(screen.kills_value.text == "12" and screen.sent_value.text == "7", "The changed signal updates real visible counter labels without reopening")
	_check(DirAccess.make_dir_absolute(_save_path + ".tmp") == OK, "Block the next atomic write for a real UI error")
	snapshot["enemy_totals"][0]["kills"][id] = 13
	_check(not store.observe(snapshot, 0), "The statistics owner actually rejects its blocked save")
	await _settle()
	_check(screen.error_label.is_visible_in_tree() and screen.error_label.text == store.error_message and screen.error_label.text.contains(_save_path), "A real persistence error stays visible and identifies the failed save")
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.error_label, "Save details are keyboard reachable and selectable")
	screen.hide()
	screen.open()
	await _settle()
	_check(screen.error_label.is_visible_in_tree() and screen.kills_value.text == "12", "Leaving/reopening cannot clear an unsaved error or display an uncommitted count")
	_check(DirAccess.remove_absolute(_save_path + ".tmp") == OK, "Unblock local statistics persistence")
	_check(store.observe(snapshot, 0), "Retry the same cumulative update through the real owner")
	await _settle()
	_check(not screen.error_label.visible and screen.kills_value.text == "13", "Only a successful persisted retry clears the error and advances the visible count")


func _check_lifecycle() -> void:
	var requests: Array[bool] = []
	screen.back_requested.connect(func() -> void: requests.append(true))
	screen.open()
	await _key(KEY_ESCAPE)
	_check(requests.size() == 1 and not screen.portrait.animate, "Escape requests Back and stops its animation before navigation")
	screen.open()
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	await _key(KEY_ENTER)
	_check(requests.size() == 2 and not screen.portrait.animate, "Tab/Enter activates the real Back action")
	screen.open()
	_check(screen.portrait.animate, "Reopening restarts the selected preview")
	screen.prepare_to_leave()
	_check(not screen.portrait.animate, "The public leave hook stops all preview processing")


func _check_portrait_input() -> void:
	for index: int in range(screen.entries.size()):
		screen._select(index)
		screen.enemy_buttons[index].grab_focus()
		await _settle()
		_check(screen.portrait.preview_animation == &"walk" and screen.portrait.preview_elapsed == 0.0 and not screen.portrait.is_processing(), "Arrow/focus selection rests without automatically playing")
		screen.portrait.start_preview()
		await _click(screen.portrait.get_global_rect().get_center())
		var definition: EnemyDefinition = screen.entries[index]
		var activated: StringName = screen.portrait.preview_animation
		_check(viewport.gui_get_focus_owner() == screen.portrait and screen.portrait.is_processing(), "Native portrait click starts the enemy's actual action sequence")
		screen.portrait.stop_preview()
		screen.portrait.set_preview_time(0.3)
		await _key(KEY_ENTER)
		_check(screen.portrait.preview_animation == activated and screen.portrait.preview_elapsed == 0.0, "Enter restarts the active sequence from its original action")
		var scroll: ScrollContainer = screen.get_node("%DetailsScroll") as ScrollContainer
		var previous_scroll: int = scroll.scroll_vertical
		screen.portrait.set_preview_time(0.2)
		await _key(KEY_SPACE)
		_check(screen.portrait.preview_elapsed == 0.0 and scroll.scroll_vertical == previous_scroll, "Space replays without scrolling details")
		screen.portrait.set_preview_time(100.0)
		_check(screen.portrait.preview_animation == &"walk" and screen.portrait.preview_elapsed == 0.0 and not screen.portrait.is_processing(), "One complete action ends at rest")
		screen.portrait.replay_action()
		screen.hide()
		_check(not screen.portrait.is_processing(), "Hidden previews never process")
		screen.portrait.set_preview_time(0.2)
		var elapsed: float = screen.portrait.preview_elapsed
		screen.portrait.replay_action()
		_check(screen.portrait.preview_elapsed == elapsed, "Hidden replay input is ignored")
		screen.open()
		screen.enemy_buttons[(index + 1) % screen.entries.size()].grab_focus()
		_check(screen.portrait.preview_animation == &"walk" and screen.portrait.preview_elapsed == 0.0, "Switching enemies clears the active action")


func _check_custom_order() -> void:
	var custom := ContentCatalog.new()
	var late := EnemyDefinition.new()
	late.id = &"late_custom"
	late.first_wave = 20
	late.send_enabled = false
	var early := EnemyDefinition.new()
	early.id = &"early_custom"
	early.first_wave = 9
	early.send_enabled = true
	early.send_first_wave = 2
	early.summon_interval = 3.0
	early.summon_type = &"summoned_custom"
	var summoned := EnemyDefinition.new()
	summoned.id = &"summoned_custom"
	summoned.regular_spawn_enabled = false
	summoned.send_enabled = false
	var unreachable := EnemyDefinition.new()
	unreachable.id = &"unreachable_custom"
	unreachable.regular_spawn_enabled = false
	unreachable.send_enabled = false
	custom.enemies.assign([late, unreachable, summoned, early])
	var original: Array[EnemyDefinition] = custom.enemies.duplicate()
	screen.configure(custom, rules, store)
	_check(screen.entries == [early, summoned, late, unreachable], "Custom-only catalogs derive send, chained summon, regular and unreachable order from metadata")
	_check(custom.enemies == original, "Presentation never mutates canonical catalog order")
	screen.enemy_buttons[1].grab_focus()
	screen.configure(catalog, rules, store)
	screen.open()


func _inside(control: Control, bounds: Rect2) -> bool:
	var rect: Rect2 = control.get_global_rect()
	return bounds.encloses(rect) and rect.size.x > 0.0 and rect.size.y > 0.0


func _portrait_image() -> Image:
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	return image.get_region(Rect2i(screen.portrait.get_global_rect()))


func _settle() -> void:
	await process_frame
	await process_frame


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame


func _check_single_selection(index: int, context: String) -> void:
	var pressed_count: int = 0
	for button: Button in screen.enemy_buttons:
		if button.button_pressed:
			pressed_count += 1
	_check(pressed_count == 1 and screen.enemy_buttons[index].button_pressed, context + " leaves exactly one selected entry")
	_check(viewport.gui_get_focus_owner() == screen.enemy_buttons[index], context + " synchronizes the actual keyboard focus")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
