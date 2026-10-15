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
	root.add_child(main)
	await process_frame
	await process_frame
	await _click(main.get_node("Menu/Center/Panel/Collection"))
	# Showing a hidden Container queues its layout for the next frame.
	await process_frame
	await process_frame
	var screen: CollectionScreen = main.collection_screen
	_check(screen.visible and not main.workshop.visible, "Collection navigation opens only the collection screen")
	await _click(screen.open_button)
	var granted: int = main.collection_store.unlocked_count()
	_check(granted > 0 and granted <= 3, "Opening actually grants eligible collection types")
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
	_check(main.collection_store.unlocked_count() == 3 and screen.open_button.disabled, "Exhausting the catalog disables further chests")
	reloaded = CollectionStore.new(SAVE_PATH)
	for reward: TowerReward in reloaded.catalog:
		_check(reloaded.is_unlocked(reward.id), "Final save contains every unlocked identity")
	main.layout.place(Vector2i(1, 4))
	var before_reset: String = FileAccess.get_file_as_string(SAVE_PATH)
	await _click(screen.reset_button)
	await process_frame
	_check(screen.reset_confirmation.visible and main.collection_store.unlocked_count() == 3, "Reset requires confirmation before changing progress")
	await _dialog_click(screen.reset_confirmation.get_cancel_button())
	_check(main.collection_store.unlocked_count() == 3 and FileAccess.get_file_as_string(SAVE_PATH) == before_reset, "Cancel preserves unlocks and saved bytes")
	await _click(screen.reset_button)
	await process_frame
	await _dialog_click(screen.reset_confirmation.get_ok_button())
	_check(main.collection_store.unlocked_count() == 0 and not screen.open_button.disabled, "Confirmed reset clears progress and enables chests")
	_check(screen.reveal.get_node("Results").get_child_count() == 0, "Reset clears old reward cards")
	_check(main.layout.has_path(Vector2i(1, 4)), "Collection reset preserves the workshop layout")
	reloaded = CollectionStore.new(SAVE_PATH)
	_check(reloaded.unlocked_count() == 0 and reloaded.can_open(), "The empty collection persists after reset")
	await _click(screen.open_button)
	_check(main.collection_store.unlocked_count() > 0 and screen.reset_button.disabled, "A fresh chest grants rewards and reset is disabled during its reveal")
	await _click(screen.skip_button)
	main.queue_free()
	await process_frame
	_remove_save()
	if failures == 0:
		print("PASS: chest grants save before reveal, repeat-click/skip/navigation cannot regrant, completion disables openings")
	quit(1 if failures > 0 else 0)


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
