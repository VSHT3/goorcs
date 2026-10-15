extends SceneTree

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
var audio: Node
var audio_path: String
var old_music: float
var old_sound: float
var save_path: String
var collection_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	audio = root.get_node("AudioSettings")
	audio_path = audio.save_path
	old_music = audio.music_volume
	old_sound = audio.sound_volume
	save_path = OS.get_temp_dir().path_join("gorcs_pause_audio_%d.cfg" % OS.get_process_id())
	collection_path = OS.get_temp_dir().path_join("gorcs_pause_collection_%d.json" % OS.get_process_id())
	audio.save_path = save_path
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(collection_path)
	root.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	await _settle()
	screen = main.play_screen.planning_screen
	for x: int in range(1, 13):
		main.planning.request_edit(0, Vector2i(x, 4), true)
	main.planning.submit_ready(true)
	await create_timer(0.3).timeout
	_check(main.planning.combat["phase"] == MatchCombat.Phase.WAVE, "Live solo wave begins before pause")
	await _key(KEY_ESCAPE)
	_check(paused and screen.pause_menu.visible and main.planning.active, "Escape pauses solo instead of leaving")
	var captured: Dictionary = main.planning._host_combat.snapshot()
	var camera_position: Vector2 = screen.world.camera.position
	var zoom: Vector2 = screen.world.camera.zoom
	await _key(KEY_D)
	await _click(screen.ready_button.get_global_rect().get_center())
	await _click(screen.world.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	await create_timer(0.35).timeout
	_check(main.planning._host_combat.snapshot() == captured, "Paused simulation cannot move enemies, spawn, or deal damage")
	_check(screen.world.camera.position == camera_position and screen.world.camera.zoom == zoom, "Modal blocks camera keys and wheel input")
	var music: AudioStreamPlayer = main.get_node("MatchMusic")
	_check(music.playing and not music.stream_paused, "Music remains audible while solo settings are open")
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	await _settings()
	await _key(KEY_ESCAPE)
	_check(paused and screen.pause_menu.resume_button.is_visible_in_tree(), "Escape from Settings returns to pause choices")
	await _key(KEY_ESCAPE)
	_check(not paused and not screen.pause_menu.visible and main.planning.active, "Escape from pause resumes the same match")
	await create_timer(0.3).timeout
	_check(main.planning._host_combat.snapshot() != captured, "Resuming advances the existing wave")
	_check(screen.world.camera.position == camera_position, "Resume cannot revive a held camera key")
	for width: int in [1280, 1000]:
		root.content_scale_size = Vector2i(width, 720)
		root.size = Vector2i(width, 720)
		await _settle()
		await _click(screen.menu_button.get_global_rect().get_center())
		_check(paused and screen.pause_menu.visible, "Cog opens pause at width %d" % width)
		await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(width, 720))
		for slider: HSlider in [screen.pause_menu.music_slider, screen.pause_menu.sound_slider]:
			_check(viewport_rect.encloses(slider.get_global_rect()), "Audio slider fits the viewport at width %d" % width)
		await _key(KEY_ESCAPE)
		await _click(screen.pause_menu.resume_button.get_global_rect().get_center())
		_check(not paused and main.planning.active, "Resume button unpauses without ending the run")
	await _click(screen.menu_button.get_global_rect().get_center())
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	audio.save_path = save_path.path_join("unwritable.cfg")
	screen.pause_menu.music_slider.grab_focus()
	await _key(KEY_LEFT)
	await _key(KEY_ESCAPE)
	_check(paused and screen.pause_menu.get_node("%SaveError").visible, "Preference save failure is visible without trapping the Settings page")
	await _click(screen.pause_menu.resume_button.get_global_rect().get_center())
	_check(not paused and main.planning.active, "A preference save failure cannot trap a paused match")
	audio.save_path = save_path
	await _click(screen.menu_button.get_global_rect().get_center())
	await _click(screen.pause_menu.quit_button.get_global_rect().get_center())
	_check(not paused and main.menu.visible and not main.planning.active, "Quit returns to title and releases pause")
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	await _settle()
	_check(main.planning.active and not screen.pause_menu.visible and not paused, "New run cannot inherit the previous pause")
	await _key(KEY_ESCAPE)
	main.play_screen.prepare_to_leave()
	await _settle()
	_check(not paused and not screen.pause_menu.visible, "External match teardown releases the solo pause")
	main.queue_free()
	await _settle()
	audio.save_path = audio_path
	audio.set_music_volume(old_music)
	audio.set_sound_volume(old_sound)
	for path: String in [save_path, collection_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	await create_timer(0.1).timeout
	if failures == 0:
		print("PASS: live solo freeze/resume, modal input isolation, cog/keyboard navigation, audio mute/isolation/persistence, compact settings, quit and teardown")
	quit(1 if failures else 0)


func _settings() -> void:
	var music_bus: int = AudioServer.get_bus_index("Music")
	var sound_bus: int = AudioServer.get_bus_index("Sound")
	var master_db: float = AudioServer.get_bus_volume_db(0)
	var music: AudioStreamPlayer = main.get_node("MatchMusic")
	var playback: float = music.get_playback_position()
	# Native slider keys exercise the actual UI while SceneTree is paused.
	screen.pause_menu.music_slider.grab_focus()
	await _key(KEY_HOME)
	_check(AudioServer.is_bus_mute(music_bus), "Music slider minimum fully mutes Music")
	screen.pause_menu.sound_slider.grab_focus()
	await _key(KEY_HOME)
	_check(AudioServer.is_bus_mute(sound_bus), "Sound slider minimum independently mutes Sound")
	screen.pause_menu.music_slider.grab_focus()
	await _key(KEY_END)
	await _key(KEY_LEFT)
	_check(not AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(sound_bus), "Raising Music unmutes only Music")
	_check(AudioServer.get_bus_volume_db(0) == master_db, "Changing category volume never changes Master")
	_check(music.playing and music.get_playback_position() >= playback, "Volume changes do not restart the soundtrack")
	var selected: float = audio.music_volume
	_check(selected > 0.0 and selected < 1.0, "Slider accepts an intermediate volume")
	await _key(KEY_ESCAPE)
	var settings := ConfigFile.new()
	_check(settings.load(save_path) == OK, "Leaving Settings persists audio values")
	_check(is_equal_approx(float(settings.get_value("audio", "music_volume", -1.0)), selected)
		and float(settings.get_value("audio", "sound_volume", -1.0)) == 0.0, "Saved volumes preserve independent user choices")
	var reloaded: Node = load("res://scripts/audio_settings.gd").new()
	reloaded.save_path = save_path
	root.add_child(reloaded)
	_check(is_equal_approx(reloaded.music_volume, selected) and reloaded.sound_volume == 0.0, "A new settings owner restores saved volumes")
	reloaded.queue_free()
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())


func _settle() -> void:
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()


func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
