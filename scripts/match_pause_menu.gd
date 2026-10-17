class_name MatchPauseMenu
extends Control
## Local modal presentation only; the match screen owns pausing and navigation.

signal resume_requested
signal quit_requested

@onready var resume_button: Button = %Resume
@onready var settings_button: Button = %Settings
@onready var quit_button: Button = %Quit
@onready var music_slider: HSlider = %MusicSlider
@onready var sound_slider: HSlider = %SoundSlider
@onready var _back_button: Button = %Back
@onready var _heading: Label = %Heading
@onready var _online_note: Label = %OnlineNote
@onready var _choices: VBoxContainer = %Choices
@onready var _settings_page: VBoxContainer = %SettingsPage
@onready var _music_value: Label = %MusicValue
@onready var _sound_value: Label = %SoundValue
@onready var _save_error: Label = %SaveError
@onready var _audio_settings: Node = get_node("/root/AudioSettings")

var _showing_settings: bool = false
var _online_match: bool = false
var _settings_dirty: bool = false


func _ready() -> void:
	CloseButtonStyle.apply(_back_button)
	MenuAudio.bind_action(_back_button)
	resume_button.pressed.connect(resume_requested.emit)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(quit_requested.emit)
	_back_button.pressed.connect(_return_to_choices)
	music_slider.value_changed.connect(_set_music_volume)
	sound_slider.value_changed.connect(_set_sound_volume)
	get_viewport().gui_focus_changed.connect(_keep_focus_inside)
	_set_focus_cycle([resume_button, settings_button, quit_button])
	_set_focus_cycle([music_slider, sound_slider, _back_button])


func open_menu(multiplayer: bool) -> void:
	_online_match = multiplayer
	_showing_settings = false
	_save_error.hide()
	_choices.show()
	_settings_page.hide()
	_back_button.hide()
	_heading.text = "Match menu" if _online_match else "Paused"
	_online_note.visible = _online_match
	show()
	resume_button.grab_focus()


func close_menu() -> void:
	if not visible:
		return
	_save_settings()
	hide()


func handle_escape() -> void:
	if not is_visible_in_tree():
		return
	if _showing_settings:
		MenuAudio.activate(_back_button)
	else:
		MenuAudio.activate(resume_button)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			handle_escape()


func _gui_input(_event: InputEvent) -> void:
	accept_event()


func _unhandled_input(_event: InputEvent) -> void:
	if is_visible_in_tree():
		# GUI gets the first opportunity, including slider drag/wheel/key events.
		get_viewport().set_input_as_handled()


func _open_settings() -> void:
	music_slider.set_value_no_signal(_audio_settings.music_volume * 100.0)
	sound_slider.set_value_no_signal(_audio_settings.sound_volume * 100.0)
	_music_value.text = "%d%%" % roundi(music_slider.value)
	_sound_value.text = "%d%%" % roundi(sound_slider.value)
	_showing_settings = true
	_choices.hide()
	_settings_page.show()
	_back_button.show()
	_heading.text = "Settings"
	music_slider.grab_focus()


func _return_to_choices() -> void:
	_save_settings()
	_showing_settings = false
	_settings_page.hide()
	_back_button.hide()
	_choices.show()
	_heading.text = "Match menu" if _online_match else "Paused"
	settings_button.grab_focus()


func _set_music_volume(value: float) -> void:
	_audio_settings.set_music_volume(value / 100.0)
	_music_value.text = "%d%%" % roundi(value)
	_settings_dirty = true


func _set_sound_volume(value: float) -> void:
	_audio_settings.set_sound_volume(value / 100.0)
	_sound_value.text = "%d%%" % roundi(value)
	_settings_dirty = true


func _save_settings() -> void:
	if not _settings_dirty:
		return
	var result: Error = _audio_settings.save_settings()
	if result != OK:
		_save_error.text = "Could not save audio settings: %s. Changes apply for this session." % error_string(result)
		_save_error.show()
		return
	_save_error.hide()
	_settings_dirty = false




func _set_focus_cycle(controls: Array[Control]) -> void:
	for index in controls.size():
		var control: Control = controls[index]
		var previous: NodePath = control.get_path_to(controls[posmod(index - 1, controls.size())])
		var next: NodePath = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_left = control.get_path_to(control) if control is Slider else previous
		control.focus_neighbor_right = control.get_path_to(control) if control is Slider else next


func _keep_focus_inside(control: Control) -> void:
	if not is_visible_in_tree() or control == null:
		return
	var page: Control = _settings_page if _showing_settings else _choices
	if not page.is_ancestor_of(control) and not (_showing_settings and control == _back_button):
		if _showing_settings:
			music_slider.grab_focus()
		else:
			resume_button.grab_focus()
