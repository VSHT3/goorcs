extends SceneTree

const WORKER_DEADLINE_MSEC: int = 150000

var _session: MultiplayerSession
var _main: Node
var _directory: String
var _lane: String
var _command_id: int = 0
var _last_result: bool = true
var _executing_command: bool = false
var _last_snapshot: String = ""
var _deadline_msec: int
var _raw_api: SceneMultiplayer
var _raw_peer: ENetMultiplayerPeer
var _raw_generation: int = 0
var _raw_payload: String = ""
var _raw_state: String = "IDLE"
var _raw_response: String = ""
var _raw_complete: bool = false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Session worker requires a temporary directory and lane name")
		quit(1)
		return
	_directory = arguments[0]
	_lane = arguments[1]
	_deadline_msec = Time.get_ticks_msec() + WORKER_DEADLINE_MSEC
	_main = Node.new()
	_main.name = "Main"
	root.add_child(_main)
	_new_session()
	_publish()


func _process(_delta: float) -> bool:
	if _directory.is_empty():
		return false
	if Time.get_ticks_msec() >= _deadline_msec:
		_close_raw()
		_session.leave()
		push_error("Session worker exceeded its bounded lifetime")
		quit(1)
		return false
	# Read the command file once per frame: the deferral check and dispatch must
	# see the same command, or a command published between two reads would skip
	# the check and run before the worker is ready for it.
	var command: Dictionary = _read_json(_path("command"))
	if int(command.get("id", 0)) > _command_id:
		if _defers_command(command):
			_publish()
			return false
		_command_id = int(command["id"])
		_executing_command = true
		_execute_command(command)
		_executing_command = false
	_publish()
	return false


# Subclasses keep a new command pending (unacknowledged) until they can run it.
func _defers_command(_command: Dictionary) -> bool:
	return false


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"host":
			_close_raw()
			_last_result = _session.host(String(command.get("address", "127.0.0.1")), int(command["port"]))
		"join":
			_close_raw()
			_last_result = _session.join(String(command["code"]))
		"join_cancel":
			_close_raw()
			_last_result = _session.join(String(command["code"]))
			_session.leave()
		"leave":
			_close_raw()
			_session.leave()
			_last_result = true
		"free_session":
			_close_raw()
			_session.free()
			_new_session()
			_last_result = true
		"raw_join":
			_session.leave()
			_close_raw()
			_start_raw(command)
		"quit":
			_close_raw()
			_session.leave()
			_last_result = true
			_publish()
			quit()
		_:
			_last_result = false
			push_error("Unknown session worker command")


func _new_session() -> void:
	_session = MultiplayerSession.new()
	_session.name = "Session"
	_session.changed.connect(_publish)
	_main.add_child(_session)


func _start_raw(command: Dictionary) -> void:
	_raw_generation += 1
	_raw_payload = String(command.get("payload", ""))
	_raw_complete = bool(command.get("complete", false))
	_raw_response = ""
	_raw_state = "CONNECTING"
	_raw_peer = ENetMultiplayerPeer.new()
	var create_error: Error = _raw_peer.create_client("127.0.0.1", int(command["port"]))
	_last_result = create_error == OK
	if not _last_result:
		_close_raw()
		_raw_state = "ERROR"
		return
	_raw_api = SceneMultiplayer.new()
	_raw_api.auth_timeout = 8.0
	_raw_api.server_relay = false
	_raw_api.auth_callback = _receive_raw_auth.bind(_raw_generation)
	_raw_api.peer_authenticating.connect(_raw_authenticating.bind(_raw_generation), CONNECT_DEFERRED)
	_raw_api.peer_authentication_failed.connect(_raw_failed.bind(_raw_generation), CONNECT_DEFERRED)
	_raw_api.peer_connected.connect(_raw_connected.bind(_raw_generation), CONNECT_DEFERRED)
	set_multiplayer(_raw_api)
	_raw_api.multiplayer_peer = _raw_peer


func _raw_authenticating(id: int, generation: int) -> void:
	if generation == _raw_generation and _raw_api != null and not _raw_payload.is_empty():
		_raw_api.send_auth(id, _raw_payload.to_utf8_buffer())


func _receive_raw_auth(id: int, data: PackedByteArray, generation: int) -> void:
	_handle_raw_auth.call_deferred(id, data, generation)


func _handle_raw_auth(id: int, data: PackedByteArray, generation: int) -> void:
	if generation != _raw_generation or _raw_api == null:
		return
	_raw_response = data.get_string_from_utf8()
	if _raw_response == "GORCS1/ACCEPT":
		_raw_state = "AUTHENTICATING"
		if _raw_complete:
			_raw_api.complete_auth(id)
	else:
		_close_raw()
		_raw_state = "REJECTED"


func _raw_failed(_id: int, generation: int) -> void:
	if generation == _raw_generation:
		_close_raw()
		_raw_state = "ERROR"


func _raw_connected(_id: int, generation: int) -> void:
	if generation == _raw_generation:
		_raw_state = "CONNECTED"


func _close_raw() -> void:
	_raw_generation += 1
	if _raw_api != null:
		_raw_api.auth_callback = Callable()
		_raw_api.multiplayer_peer = null
	if _raw_peer != null:
		_raw_peer.close()
	_raw_peer = null
	_raw_api = null
	_raw_state = "IDLE"


func _publish() -> void:
	if _session == null or _directory.is_empty() or _executing_command:
		return
	var api: MultiplayerAPI = get_multiplayer()
	var peer_ids: Array[int] = []
	var authenticating: int = 0
	if api.has_multiplayer_peer():
		for id: int in api.get_peers():
			peer_ids.append(id)
		if api is SceneMultiplayer:
			authenticating = (api as SceneMultiplayer).get_authenticating_peers().size()
	var snapshot: String = JSON.stringify({
		"id": _command_id,
		"result": _last_result,
		"state": MultiplayerSession.State.keys()[_session.state],
		"is_host": _session.is_host,
		"count": _session.player_count(),
		"code": _session.invite_code,
		"error": _session.error_message,
		"native_peers": peer_ids,
		"authenticating": authenticating,
		"authority": _session.get_multiplayer_authority(),
		"raw_state": _raw_state,
		"raw_response": _raw_response,
	})
	if snapshot == _last_snapshot:
		return
	_last_snapshot = snapshot
	var temporary_path: String = _path("status") + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write isolated session worker status")
		quit(1)
		return
	file.store_string(snapshot)
	file.close()
	if DirAccess.rename_absolute(temporary_path, _path("status")) != OK:
		push_error("Cannot publish isolated session worker status")
		quit(1)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _path(kind: String) -> String:
	return _directory.path_join("%s.%s.json" % [_lane, kind])
