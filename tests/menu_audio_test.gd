extends SceneTree

const WORDMARK_SCRIPT = preload("res://scripts/menu_wordmark.gd")

class RecordingAudio extends MenuAudio:
	var actions: int = 0
	var roars: int = 0
	var action_muted: bool = false
	var roar_muted: bool = false
	var action_gain: float = 0.0
	var roar_gain: float = 0.0

	func play_action() -> void:
		super.play_action()
		actions += 1
		var bus_index: int = AudioServer.get_bus_index(_clack.bus)
		action_muted = AudioServer.is_bus_mute(bus_index)
		action_gain = AudioServer.get_bus_volume_linear(bus_index)

	func play_roar() -> void:
		super.play_roar()
		roars += 1
		var bus_index: int = AudioServer.get_bus_index(_roar.bus)
		roar_muted = AudioServer.is_bus_mute(bus_index)
		roar_gain = AudioServer.get_bus_volume_linear(bus_index)


var failures: int = 0
var fixture: Control
var audio: RecordingAudio
var settings: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	settings = root.get_node("AudioSettings")
	var original_volume: float = settings.sound_volume
	# A pre-existing mute must apply to the very first startup cue.
	settings.set_sound_volume(0.0)
	fixture = Control.new()
	fixture.size = Vector2(1280, 720)
	root.add_child(fixture)
	audio = RecordingAudio.new()
	audio.name = "MenuAudio"
	fixture.add_child(audio)
	_check_intro()
	settings.set_sound_volume(0.35)
	_check_live_volume()
	_check_manual_replay()
	_check_pause_and_navigation()
	settings.set_sound_volume(original_volume)
	fixture.queue_free()
	await process_frame
	# Stopped native playbacks retire on the audio mix thread.
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS: startup mouth timing, one-shot/early-hide lifecycle, local navigation survival, pause-safe cues and live Sound volume/mute")
	quit(1 if failures else 0)


func _title() -> Control:
	var title: Control = WORDMARK_SCRIPT.new()
	title.size = Vector2(600, 140)
	fixture.add_child(title)
	title.set_process(false)
	return title


func _check_intro() -> void:
	var title: Control = _title()
	title._process(0.50)
	_check(audio.roars == 0, "Bracing before the mouth opens is silent")
	title._process(0.139)
	_check(audio.roars == 0, "The last closed-mouth frame remains silent")
	title._process(0.002)
	_check(audio.roars == 1 and title._face_pose == WORDMARK_SCRIPT.FacePose.OPEN, "First open-mouth frame triggers exactly one actual roar")
	_check(audio.roar_muted, "Startup roar honors a Sound mute applied before it exists")
	title._process(0.10)
	_check(audio.roars == 1, "Following open-mouth frames cannot restart the startup recording")
	title.hide()
	_check(not audio._roar.playing, "Leaving during the intro immediately stops its current vocal")
	title.show()
	title.set_process(false)
	title._process(10.0)
	_check(audio.roars == 1 and title._intro_finished, "Menu returns and idle animation never replay the vocal")
	title.free()

	var early: Control = _title()
	early._process(0.40)
	early.hide()
	early._process(1.0)
	early.show()
	early.set_process(false)
	early._process(1.0)
	_check(audio.roars == 1, "Leaving before mouth opening discards the cue instead of deferring it offscreen or to a return")
	early.free()

	var stalled: Control = _title()
	stalled._process(2.0)
	_check(audio.roars == 1, "A stalled startup cannot emit a late vocal over the already settled face")
	stalled.free()


func _check_live_volume() -> void:
	var title: Control = _title()
	title._process(0.65)
	_check(audio.roars == 2 and not audio.roar_muted and is_equal_approx(audio.roar_gain, 0.35), "A live Sound-volume change affects the next roar without rebuilding its owner")
	var button := GameMenuButton.new()
	fixture.add_child(button)
	MenuAudio.activate(button)
	_check(audio.actions == 1 and not audio.action_muted and is_equal_approx(audio.action_gain, 0.35), "The same live Sound-volume change affects menu clacks")
	settings.set_sound_volume(0.0)
	MenuAudio.activate(button)
	_check(audio.actions == 2 and audio.action_muted and AudioServer.is_bus_mute(AudioServer.get_bus_index(audio._roar.bus)), "Sound mute affects new clacks and the currently playing title vocal")
	title._process(2.0)
	title._process(10.0)
	title.hide()
	title.show()
	title.set_process(false)
	title._process(1.0)
	_check(title._intro_finished and audio.roars == 2, "A naturally completed startup stays one-shot through idle time and a later menu return")
	title.free()
	button.free()


func _check_manual_replay() -> void:
	var title: Control = _title()
	title._process(2.0)
	var before: int = audio.roars
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	title._gui_input(click)
	title._process(0.15)
	_check(audio.roars == before + 1 and audio.roar_muted and title._face_pose == WORDMARK_SCRIPT.FacePose.OPEN, "Click replay reaches the opening-mouth frame and honors Sound mute")
	title._process(0.20)
	title._gui_input(click)
	_check(not audio._roar.playing and title._face_pose == WORDMARK_SCRIPT.FacePose.BRACED, "Clicking during a roar stops its voice and restarts the jaw")
	settings.set_sound_volume(0.35)
	title._process(0.15)
	_check(audio.roars == before + 2 and not audio.roar_muted and is_equal_approx(audio.roar_gain, 0.35), "The repeated click starts a fresh vocal with current Sound gain")
	title.hide()
	title._gui_input(click)
	_check(not audio._roar.playing and audio.roars == before + 2, "Leaving cancels click audio and hidden input cannot restart it")
	title.show()
	title.set_process(false)
	title._process(2.0)
	_check(audio.roars == before + 2, "Returning does not resume a canceled click roar")
	title.free()
	var assembling: Control = _title()
	assembling._process(0.20)
	assembling._gui_input(click)
	assembling._process(0.15)
	_check(assembling._intro_finished and assembling.material == null and audio.roars == before + 3, "A click during assembly replaces startup with the requested roar")
	assembling._process(2.0)
	_check(audio.roars == before + 3, "Replacing assembly cannot leave a second automatic vocal queued")
	assembling.free()


func _check_pause_and_navigation() -> void:
	settings.set_sound_volume(0.35)
	var screen := Control.new()
	fixture.add_child(screen)
	var button := GameMenuButton.new()
	screen.add_child(button)
	var heard_after_hide: Array[bool] = [false]
	button.pressed.connect(func() -> void:
		screen.hide()
		heard_after_hide[0] = audio._clack.playing
	)
	var before: int = audio.actions
	MenuAudio.activate(button)
	_check(audio.actions == before + 1 and heard_after_hide[0], "Activation emits one clack that survives its action immediately hiding the source screen")
	MenuAudio.activate(button)
	_check(audio.actions == before + 1, "A hidden shortcut target cannot activate or emit audio")
	screen.show()
	button.disabled = true
	MenuAudio.activate(button)
	_check(audio.actions == before + 1, "A disabled shortcut target stays silent")
	button.disabled = false
	paused = true
	MenuAudio.activate(button)
	_check(audio.actions == before + 2 and audio._clack.playing and audio.can_process(), "A local menu action still plays on the root owner while the scene tree is paused")
	paused = false
	screen.free()


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
