extends SceneTree

const SAVE_PATH := "user://chest_flow_test_collection.json"
var failures: int = 0
var main: Control


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	_remove_save()
	var random := RandomNumberGenerator.new()
	random.seed = 42
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(SAVE_PATH, preload("res://resources/content_catalog.tres"), random)
	var catalog_size: int = main.collection_store.catalog.size()
	var starter_id: StringName = main.collection_store.content_catalog.starter_tower_id
	var initial_unlocked: int = main.collection_store.unlocked_count()
	_check(main.collection_store.is_unlocked(starter_id), "Collection navigation starts with its guaranteed starter")
	root.add_child(main)
	await process_frame
	await process_frame
	await _click(main.get_node("Menu/Center/Panel/Collection"))
	# Showing a hidden Container queues its layout for the next frame.
	await process_frame
	await process_frame
	var screen: CollectionScreen = main.collection_screen
	_check(screen.visible and (main.sandbox_screen == null or not main.sandbox_screen.visible), "Collection navigation opens only the collection screen")
	await _check_layout(screen)
	await _click(screen.open_button)
	var granted: int = main.collection_store.unlocked_count()
	_check(granted > initial_unlocked and granted <= catalog_size, "Opening actually grants previously locked collection types")
	_check(screen.reveal.is_revealing(), "Grant starts the chest reveal")
	var reloaded := CollectionStore.new(SAVE_PATH)
	_check(reloaded.unlocked_count() == granted, "Grant is saved before reveal finishes")
	await _click(screen.open_button)
	_check(main.collection_store.unlocked_count() == granted, "Repeated opening during reveal cannot grant again")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not screen.visible, "Escape returns to navigation during reveal")
	_check(not screen.reveal.is_revealing(), "Leaving completes presentation without leaving it active")
	await _key(KEY_ESCAPE)
	_check(screen.visible and main.collection_store.unlocked_count() == granted, "Resume preserves granted collection without rerolling")
	screen.reveal.skip()
	screen.reveal.skip()
	_check(main.collection_store.unlocked_count() == granted, "Repeated skip after leaving cannot grant anything")
	while main.collection_store.can_open():
		var previous: int = main.collection_store.unlocked_count()
		await _click(screen.open_button)
		await _click(screen.skip_button)
		_check(main.collection_store.unlocked_count() > previous, "Next chest unlocks additional eligible types")
		_check(not screen.reveal.is_revealing(), "Skip completes the reveal")
		if main.collection_store.unlocked_count() == previous:
			break
	_check(main.collection_store.unlocked_count() == catalog_size and screen.open_button.disabled, "Exhausting the catalog disables further chests")
	reloaded = CollectionStore.new(SAVE_PATH)
	for reward: TowerReward in reloaded.catalog:
		_check(reloaded.is_unlocked(reward.id), "Final save contains every unlocked identity")
	main.sandbox_button.pressed.emit()
	main.sandbox_screen.controller.edit_path(Vector2i(1, 4), true)
	main.get_node("Menu/Center/Panel/Collection").pressed.emit()
	var before_reset: String = FileAccess.get_file_as_string(SAVE_PATH)
	await _click(screen.reset_button)
	await process_frame
	_check(screen.reset_confirmation.visible and main.collection_store.unlocked_count() == catalog_size, "Reset requires confirmation before changing progress")
	await _dialog_click(screen.reset_confirmation.get_cancel_button())
	_check(main.collection_store.unlocked_count() == catalog_size and FileAccess.get_file_as_string(SAVE_PATH) == before_reset, "Cancel preserves unlocks and saved bytes")
	await _click(screen.reset_button)
	await process_frame
	await _dialog_click(screen.reset_confirmation.get_ok_button())
	_check(main.collection_store.unlocked_count() == initial_unlocked and main.collection_store.is_unlocked(starter_id) and not screen.open_button.disabled, "Confirmed reset retains the starter and enables chests")
	_check(screen.reveal.get_node("Results").get_child_count() == 0, "Reset clears old reward cards")
	_check(main.sandbox_screen.layout.has_path(Vector2i(1, 4)), "Collection reset preserves the sandbox layout")
	reloaded = CollectionStore.new(SAVE_PATH)
	_check(reloaded.unlocked_count() == initial_unlocked and reloaded.is_unlocked(starter_id) and reloaded.can_open(), "Starter-only collection persists after reset")
	for reward: TowerReward in reloaded.catalog:
		_check(reloaded.is_unlocked(reward.id) == (reward.id == starter_id), "Reset removes every nonstarter unlock")
	await _click(screen.open_button)
	_check(main.collection_store.unlocked_count() > initial_unlocked and screen.reset_button.disabled, "A fresh chest grants rewards beyond the starter and reset is disabled during its reveal")
	await _click(screen.skip_button)
	main.queue_free()
	await process_frame
	# Menu clacks release their stopped playbacks on the native mix thread.
	await create_timer(0.2).timeout
	_remove_save()
	if failures == 0:
		print("PASS: chest grants save before reveal, repeat-click/skip/navigation cannot regrant, completion disables openings")
	quit(1 if failures > 0 else 0)


func _check_layout(screen: CollectionScreen) -> void:
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		var surface := Rect2(Vector2.ZERO, Vector2(root.size))
		for control: Control in [screen.get_node("Margin/Content/Header"), screen.open_button, screen.reset_button, screen.back_button]:
			_check(surface.encloses(control.get_global_rect()), "The full collection keeps its header and actions inside the %dpx viewport" % width)
		var scroll := screen._catalog.get_parent() as ScrollContainer
		var last: Control = screen._catalog.get_child(screen._catalog.get_child_count() - 1)
		scroll.ensure_control_visible(last)
		await process_frame
		_check(scroll.get_global_rect().encloses(last.get_global_rect()), "The last registered collection entry remains reachable at %dpx width" % width)
		scroll.scroll_vertical = 0


func _click(control: Control) -> void:
	var point: Vector2 = root.get_final_transform() * (control.global_position + control.size * 0.5)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _dialog_click(control: Control) -> void:
	var window := control.get_viewport() as Window
	var point: Vector2 = root.get_final_transform() * (Vector2(window.position) + control.global_position + control.size * 0.5)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _remove_save() -> void:
	for suffix: String in ["", ".tmp"]:
		var path: String = ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
