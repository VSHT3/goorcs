extends Node

signal changed

const SAVE_PATH := "user://discord_settings.cfg"

var save_path: String = SAVE_PATH
var enabled: bool = true


func _ready() -> void:
	_load_settings()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	changed.emit()


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("discord", "enabled", enabled)
	var error: Error = config.save(save_path)
	if error != OK:
		push_warning("Could not save Discord settings to '%s': %s." % [save_path, error_string(error)])
	return error


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(save_path)
	if error == ERR_FILE_NOT_FOUND:
		set_enabled(true)
		return
	if error != OK:
		push_warning("Could not load Discord settings from '%s': %s. Sharing is disabled; the file was not changed." % [save_path, error_string(error)])
		set_enabled(false)
		return
	var value: Variant = config.get_value("discord", "enabled") if config.has_section_key("discord", "enabled") else null
	if not value is bool:
		push_warning("Invalid Discord setting 'enabled': expected a boolean. Sharing is disabled; the file was not changed.")
		set_enabled(false)
		return
	set_enabled(value)
