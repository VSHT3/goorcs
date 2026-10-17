extends SceneTree

var failures: int = 0
var save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = OS.get_temp_dir().path_join("gorcs_discord_settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var settings: Node = _new_owner(save_path)
	_check(not FileAccess.file_exists(save_path), "Opening missing preferences does not create a file")
	settings.set_enabled(true)
	var changes: Array[bool] = []
	settings.changed.connect(func() -> void: changes.append(settings.enabled))
	settings.set_enabled(false)
	settings.set_enabled(false)
	_check(changes == [false], "Disabling sharing emits one change and repeated choices emit none")
	_check(settings.save_settings() == OK, "Disabled sharing can be saved")
	settings.free()
	settings = _new_owner(save_path)
	_check(not settings.enabled, "A recreated owner restores disabled sharing")
	settings.set_enabled(true)
	_check(settings.save_settings() == OK, "Re-enabled sharing can be saved")
	settings.free()
	settings = _new_owner(save_path)
	_check(settings.enabled, "A recreated owner restores an explicit re-enabled choice")
	settings.set_enabled(false)
	settings.save_path = save_path.path_join("unwritable.cfg")
	_check(settings.save_settings() != OK and not settings.enabled, "Save failure does not re-enable sharing")
	settings.free()
	var invalid_path: String = "user://discord_settings_test_invalid.cfg"
	for contents: String in [
		"[discord\nenabled=true\n",
		"[discord]\nenabled=\"true\"\n",
		"[discord]\nenabled=1\n",
		"[discord]\nother=true\n",
	]:
		var file := FileAccess.open(invalid_path, FileAccess.WRITE)
		_check(file != null, "Malformed preference fixture can be written")
		if file == null:
			continue
		file.store_string(contents)
		file.close()
		var original: PackedByteArray = FileAccess.get_file_as_bytes(invalid_path)
		settings = _new_owner(invalid_path)
		_check(not settings.enabled, "Malformed or non-boolean preferences fail closed")
		_check(FileAccess.get_file_as_bytes(invalid_path) == original, "Loading invalid preferences preserves their exact bytes")
		settings.free()
	settings = _new_owner(OS.get_temp_dir())
	_check(not settings.enabled, "An unreadable preference file fails closed")
	settings.free()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(invalid_path)
	if failures == 0:
		print("PASS: Discord preference change signals, disabled/re-enabled persistence, fail-closed invalid files and non-destructive loading")
	quit(1 if failures else 0)


func _new_owner(path: String) -> Node:
	var settings: Node = load("res://scripts/discord_settings.gd").new()
	settings.save_path = path
	root.add_child(settings)
	return settings


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
