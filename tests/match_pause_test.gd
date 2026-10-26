extends SceneTree

var failures: int = 0
var main: Control
var screen: MatchPlanningScreen
var audio: Node
var audio_path: String
var old_music: float
var old_sound: float
var save_path: String
var discord: Node
var discord_path: String
var old_discord_enabled: bool
var discord_save_path: String
var collection_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	audio = root.get_node("AudioSettings")
	audio_path = audio.save_path
	old_music = audio.music_volume
	old_sound = audio.sound_volume
	var old_viewport_size: Vector2i = root.size
	var old_scale_size: Vector2i = root.content_scale_size
	var fixture_id: String = "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	save_path = OS.get_temp_dir().path_join("gorcs_pause_audio_%s.cfg" % fixture_id)
	collection_path = OS.get_temp_dir().path_join("gorcs_pause_collection_%s.json" % fixture_id)
	audio.save_path = save_path
	discord = root.get_node("DiscordSettings")
	discord_path = discord.save_path
	old_discord_enabled = discord.enabled
	discord_save_path = OS.get_temp_dir().path_join("gorcs_pause_discord_%s.cfg" % fixture_id)
	discord.save_path = discord_save_path
	discord.set_enabled(true)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(collection_path)
	main.combat_rules = CombatRules.new()
	root.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(main.planning), "Fixture completes the hero draft")
	_check(main.planning.select_loadout([&"arrow_tower"]) and main.planning.commit_loadout(), "Pause fixture commits its owned starter")
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
	_check(not FileAccess.file_exists(discord_save_path), "Audio-only changes do not create Discord preferences")
	await _discord_preferences()
	_check(main.planning._host_combat.snapshot() == captured, "Discord keyboard and pointer input leave paused simulation unchanged")
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
		_check(viewport_rect.encloses(screen.pause_menu.discord_presence_toggle.get_global_rect()), "Discord toggle fits the viewport at width %d" % width)
		await _key(KEY_ESCAPE)
		await _click(screen.pause_menu.resume_button.get_global_rect().get_center())
		_check(not paused and main.planning.active, "Resume button unpauses without ending the run")
	await _click(screen.menu_button.get_global_rect().get_center())
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	audio.save_path = save_path.path_join("unwritable.cfg")
	discord.save_path = discord_save_path.path_join("unwritable.cfg")
	screen.pause_menu.music_slider.grab_focus()
	await _key(KEY_LEFT)
	var selected_music: float = audio.music_volume
	screen.pause_menu.discord_presence_toggle.grab_focus()
	await _key(KEY_SPACE)
	_check(not discord.enabled, "Disabling sharing applies before a failing save")
	await _key(KEY_ESCAPE)
	_check(paused and screen.pause_menu.get_node("%SaveError").visible and not discord.enabled, "Preference save failure is visible without trapping Settings or re-enabling sharing")
	audio.save_path = save_path
	await _click(screen.pause_menu.resume_button.get_global_rect().get_center())
	_check(not paused and main.planning.active, "A preference save failure cannot trap a paused match")
	var saved_audio := ConfigFile.new()
	_check(saved_audio.load(save_path) == OK and is_equal_approx(float(saved_audio.get_value("audio", "music_volume", -1.0)), selected_music),
		"A successful audio save is independent of a Discord save failure")
	saved_audio.set_value("fixture", "preserve", true)
	_check(saved_audio.save(save_path) == OK, "Audio independence fixture can be saved")
	var audio_before_retry: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	discord.save_path = discord_save_path
	await _click(screen.menu_button.get_global_rect().get_center())
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	_check(not screen.pause_menu.discord_presence_toggle.button_pressed, "Reopening after a failed save retains disabled sharing")
	await _key(KEY_ESCAPE)
	_check(not screen.pause_menu.get_node("%SaveError").visible, "Retrying retained dirty preferences clears the save error")
	_check(FileAccess.get_file_as_bytes(save_path) == audio_before_retry, "Retrying Discord does not rewrite already-saved audio")
	_check_discord_restart(false)
	await _click(screen.pause_menu.resume_button.get_global_rect().get_center())
	await _click(screen.menu_button.get_global_rect().get_center())
	await _click(screen.pause_menu.quit_button.get_global_rect().get_center())
	_check(not paused and main.menu.visible and not main.planning.active, "Quit returns to title and releases pause")
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(main.planning), "Fixture completes the hero draft")
	_check(main.planning.select_loadout([&"arrow_tower"]) and main.planning.commit_loadout(), "New pause run requires a fresh committed deck")
	await _settle()
	_check(main.planning.active and not screen.pause_menu.visible and not paused, "New run cannot inherit the previous pause")
	await _key(KEY_ESCAPE)
	main.play_screen.prepare_to_leave()
	await _settle()
	_check(not paused and not screen.pause_menu.visible, "External match teardown releases the solo pause")
	main.queue_free()
	await _settle()
	var closing_menu: MatchPauseMenu = load("res://scenes/match_pause_menu.tscn").instantiate()
	root.add_child(closing_menu)
	closing_menu.open_menu(false)
	await _click(closing_menu.settings_button.get_global_rect().get_center())
	closing_menu.discord_presence_toggle.grab_focus()
	await _key(KEY_SPACE)
	var choice_on_close: bool = discord.enabled
	closing_menu.queue_free()
	await _settle()
	_check_discord_restart(choice_on_close)
	audio.save_path = audio_path
	audio.set_music_volume(old_music)
	audio.set_sound_volume(old_sound)
	discord.save_path = discord_path
	discord.set_enabled(old_discord_enabled)
	root.content_scale_size = old_scale_size
	root.size = old_viewport_size
	for path: String in [save_path, discord_save_path, collection_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	await create_timer(0.1).timeout
	if failures == 0:
		print("PASS: live solo freeze/resume, modal input isolation, cog/keyboard navigation, audio and Discord preference isolation/persistence/failure recovery, compact settings, quit and teardown")
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



func _discord_preferences() -> void:
	var audio_fixture := ConfigFile.new()
	_check(audio_fixture.load(save_path) == OK, "Saved audio is available before Discord changes")
	audio_fixture.set_value("fixture", "preserve", true)
	_check(audio_fixture.save(save_path) == OK, "Independent audio fixture can be saved")
	var audio_before: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	var toggle: CheckButton = screen.pause_menu.discord_presence_toggle
	_check(toggle.button_pressed == discord.enabled, "Opening Settings reflects the current Discord preference")
	screen.pause_menu.sound_slider.grab_focus()
	await _key(KEY_TAB)
	_check(toggle.has_focus(), "Tab moves from Sound to the Discord toggle")
	await _key(KEY_TAB)
	_check(screen.pause_menu.get_node("%Back").has_focus(), "Tab moves from Discord to Settings X")
	await _key(KEY_TAB)
	_check(screen.pause_menu.music_slider.has_focus(), "Settings focus wraps from X to Music")
	toggle.grab_focus()
	await _key(KEY_SPACE)
	_check(paused and not discord.enabled and not toggle.button_pressed, "Space disables sharing immediately while paused")
	await _key(KEY_ESCAPE)
	_check_discord_restart(false)
	_check(FileAccess.get_file_as_bytes(save_path) == audio_before, "Discord-only saves preserve the audio file")
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	_check(not toggle.button_pressed, "Reopening Settings reflects persisted disabled sharing")
	toggle.grab_focus()
	await _key(KEY_ENTER)
	_check(paused and discord.enabled and toggle.button_pressed, "Enter re-enables sharing immediately while paused")
	await _key(KEY_ESCAPE)
	_check_discord_restart(true)
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())
	await _click(toggle.get_global_rect().get_center())
	_check(not discord.enabled and not toggle.button_pressed, "Pointer activation disables sharing immediately")
	await _click(toggle.get_global_rect().get_center())
	_check(discord.enabled and toggle.button_pressed, "Pointer activation can re-enable sharing")
	await _key(KEY_ESCAPE)
	_check(FileAccess.get_file_as_bytes(save_path) == audio_before, "Repeated Discord saves do not rewrite audio")
	await _click(screen.pause_menu.settings_button.get_global_rect().get_center())


func _check_discord_restart(expected: bool) -> void:
	var reloaded: Node = load("res://scripts/discord_settings.gd").new()
	reloaded.save_path = discord_save_path
	root.add_child(reloaded)
	_check(reloaded.enabled == expected, "A recreated settings owner restores the selected Discord preference")
	reloaded.queue_free()

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
