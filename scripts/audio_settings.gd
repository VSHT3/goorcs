extends Node

const SAVE_PATH := "user://audio_settings.cfg"
const DEFAULT_VOLUME := 1.0
const MUSIC_BUS := &"Music"
const SOUND_BUS := &"Sound"

var save_path: String = SAVE_PATH

var music_volume: float = DEFAULT_VOLUME:
	set(value):
		music_volume = _validated_volume(value, "music_volume")
		_apply_volume(MUSIC_BUS, music_volume)
var sound_volume: float = DEFAULT_VOLUME:
	set(value):
		sound_volume = _validated_volume(value, "sound_volume")
		_apply_volume(SOUND_BUS, sound_volume)


func _ready() -> void:
	_load_settings()


func set_music_volume(value: float) -> void:
	music_volume = value


func set_sound_volume(value: float) -> void:
	sound_volume = value


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sound_volume", sound_volume)
	var error: Error = config.save(save_path)
	if error != OK:
		push_warning("Could not save audio settings to '%s': %s." % [save_path, error_string(error)])
	return error


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(save_path)
	if error == OK:
		set_music_volume(_validated_volume(config.get_value("audio", "music_volume", DEFAULT_VOLUME), "music_volume"))
		set_sound_volume(_validated_volume(config.get_value("audio", "sound_volume", DEFAULT_VOLUME), "sound_volume"))
		return
	if error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load audio settings from '%s': %s. Using default volumes; the file was not changed." % [save_path, error_string(error)])
	set_music_volume(DEFAULT_VOLUME)
	set_sound_volume(DEFAULT_VOLUME)


func _validated_volume(value: Variant, key: String) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	push_warning("Invalid audio setting '%s': expected a finite number. Using the default volume." % key)
	return DEFAULT_VOLUME


func _apply_volume(bus_name: StringName, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Audio bus '%s' is missing; its volume could not be applied." % bus_name)
		return
	AudioServer.set_bus_volume_linear(bus_index, value)
	AudioServer.set_bus_mute(bus_index, value == 0.0)
