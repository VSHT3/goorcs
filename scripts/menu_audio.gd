class_name MenuAudio
extends Node
## Local presentation audio; survives screen changes without entering match state.

const CLACK: AudioStream = preload("res://assets/audio/sfx/menu_click.wav")
const ROAR: AudioStream = preload("res://assets/audio/sfx/intro_roar.wav")

var _clack: AudioStreamPlayer
var _roar: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_clack = _player("Clack", CLACK)
	_roar = _player("TitleRoar", ROAR)


func _player(player_name: String, audio: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = audio
	player.bus = &"Sound"
	add_child(player)
	return player


func play_action() -> void:
	_clack.play()


func play_roar() -> void:
	_roar.play()


func stop_roar() -> void:
	_roar.stop()


static func find_owner(source: Node) -> MenuAudio:
	var ancestor: Node = source
	while ancestor != null:
		var audio: MenuAudio = ancestor.get_node_or_null(^"MenuAudio") as MenuAudio
		if audio != null:
			return audio
		ancestor = ancestor.get_parent()
	return null


static func bind_action(button: Button) -> void:
	var callback: Callable = play_action_for.bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


static func activate(button: Button) -> void:
	# Shortcuts share the native pressed route, including its one audio callback.
	if not button.disabled and button.is_visible_in_tree():
		button.pressed.emit()


static func play_action_for(button: Button) -> void:
	var audio: MenuAudio = find_owner(button)
	if audio != null:
		audio.play_action()
