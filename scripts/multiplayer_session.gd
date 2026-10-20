class_name MultiplayerSession
extends Node

signal changed

enum State { IDLE, HOSTING, CONNECTING, CONNECTED, ERROR }

const INVITE_VERSION: String = "GORCS1"
const AUTH_ACCEPT: String = INVITE_VERSION + "/ACCEPT"
const AUTH_FULL: String = INVITE_VERSION + "/FULL"
const AUTH_INVALID: String = INVITE_VERSION + "/INVALID"
const AUTH_VERSION: String = INVITE_VERSION + "/VERSION"
const CONNECTION_TIMEOUT_SECONDS: float = 12.0
# An invite may list several host addresses (one per network adapter, most
# likely first). The guest tries each in turn; an address that has not answered
# within this many seconds gives way to the next one.
const ADDRESS_ATTEMPT_SECONDS: float = 3.0
const MAX_INVITE_ADDRESSES: int = 6
const AUTH_TIMEOUT_SECONDS: float = 5.0
# Extra transport slots let a third player receive a useful rejection. Only one
# authenticated guest is ever admitted to the SceneMultiplayer room.
const MAX_TRANSPORT_CLIENTS: int = 8
const MAX_AUTH_PACKET_BYTES: int = 96

var state: State = State.IDLE
var is_host: bool = false
var invite_code: String = ""
var error_message: String = ""

var _api: SceneMultiplayer
var _peer: ENetMultiplayerPeer
var _crypto: Crypto = Crypto.new()
var _room_token: String = ""
var _room_token_bytes: PackedByteArray = PackedByteArray()
var _guest_id: int = 0
var _generation: int = 0
var _connection_deadline_msec: int = 0
var _rejected_peers: Dictionary[int, bool] = {}
var _join_addresses: PackedStringArray = PackedStringArray()
var _join_port: int = 0
var _join_index: int = 0
var _attempt_deadline_msec: int = 0
var _reached_host: bool = false


func _ready() -> void:
	set_multiplayer_authority(1)
	set_process(false)


func _process(_delta: float) -> void:
	if state != State.CONNECTING:
		return
	var now: int = Time.get_ticks_msec()
	# Once the host has answered, stay on that address until admission.
	if not _reached_host and now >= _attempt_deadline_msec and _try_next_address():
		return
	if now >= _connection_deadline_msec:
		_fail(_unreachable_message() if not _reached_host else "Connection timed out while joining the room. Ask the host for their current invite and try again.")


func _exit_tree() -> void:
	_close_network()


# advertised_address may list several comma-separated addresses, most likely
# first; the invite carries all of them so the guest can find a reachable one.
func host(advertised_address: String, port: int = 7000) -> bool:
	if _peer != null:
		return _reject_active_action()
	var addresses: PackedStringArray = _address_list(advertised_address)
	if addresses.is_empty():
		return _fail("Enter the host's numeric IPv4 or IPv6 address, not a hostname or an unspecified/broadcast address. Use the address your friend can reach over LAN, forwarded internet UDP, or a private VPN.")
	if port < 1 or port > 65535:
		return _fail("Choose a UDP port from 1 to 65535; unprivileged ports above 1023 are recommended.")
	var random_bytes: PackedByteArray = _crypto.generate_random_bytes(16)
	if random_bytes.size() != 16:
		return _fail("Cannot generate a secure room credential. Restart the game before hosting.")
	var next_peer := ENetMultiplayerPeer.new()
	var create_error: Error = next_peer.create_server(port, MAX_TRANSPORT_CLIENTS)
	if create_error != OK:
		next_peer.close()
		return _fail("Cannot host on UDP port %d: %s. Close the other host or choose another port; check firewall and port permissions." % [port, error_string(create_error)])
	_room_token = random_bytes.hex_encode()
	_room_token_bytes = _room_token.to_utf8_buffer()
	invite_code = "%s/%s/%d/%s" % [INVITE_VERSION, ",".join(addresses), port, _room_token]
	is_host = true
	error_message = ""
	state = State.HOSTING
	_install_peer(next_peer)
	changed.emit()
	return true


func join(code: String) -> bool:
	if _peer != null:
		return _reject_active_action()
	var parts: PackedStringArray = code.strip_edges().split("/", true)
	if parts.size() != 4:
		return _fail("Invalid invite. Paste the complete GORCS1/address/port/credential code copied by the host.")
	if parts[0] != INVITE_VERSION:
		return _fail("This invite uses an incompatible version. Both players need the same game version and a fresh GORCS1 invite.")
	var addresses: PackedStringArray = _address_list(parts[1])
	if addresses.is_empty():
		return _fail("The invite has an invalid numeric IP address. Ask the host to create a code with their reachable LAN, forwarded internet, or private VPN address.")
	if parts[2].is_empty() or parts[2].length() > 5 or not _only_characters(parts[2], "0123456789"):
		return _fail("The invite has an invalid UDP port. Ask the host to copy a new code.")
	var port: int = parts[2].to_int()
	if port < 1 or port > 65535:
		return _fail("The invite's UDP port must be from 1 to 65535. Ask the host to copy a new code.")
	if not _valid_token(parts[3]):
		return _fail("The invite credential must contain exactly 32 lowercase hexadecimal characters. Paste the complete code copied by the host.")
	invite_code = ""
	is_host = false
	error_message = ""
	_join_addresses = addresses
	_join_port = port
	_join_index = -1
	_reached_host = false
	if not _try_next_address():
		return false
	_room_token = parts[3]
	state = State.CONNECTING
	# Every listed address gets its turn before the overall deadline.
	_connection_deadline_msec = Time.get_ticks_msec() + int(maxf(CONNECTION_TIMEOUT_SECONDS, ADDRESS_ATTEMPT_SECONDS * addresses.size() + AUTH_TIMEOUT_SECONDS) * 1000.0)
	set_process(true)
	changed.emit()
	return true


# Connect to the next listed host address, replacing any unanswered attempt.
func _try_next_address() -> bool:
	while _join_index + 1 < _join_addresses.size():
		_join_index += 1
		var next_peer := ENetMultiplayerPeer.new()
		if next_peer.create_client(_join_addresses[_join_index], _join_port) != OK:
			next_peer.close()
			continue
		var token: String = _room_token
		_drop_peer()
		_room_token = token
		_install_peer(next_peer)
		_attempt_deadline_msec = Time.get_ticks_msec() + int(ADDRESS_ATTEMPT_SECONDS * 1000.0)
		return true
	if _peer == null:
		_fail("Cannot start the connection. Check the invite address and network access, then try again.")
	return false


func _unreachable_message() -> String:
	return "Cannot reach the host at %s. Check that the host is still waiting, both computers are on the same network (guest/public Wi-Fi can block devices from seeing each other), and the host allowed Gorcs through their firewall (on Windows, tick Private networks). Over the internet, forward UDP port %d or use a private VPN." % [", ".join(_join_addresses), _join_port]


func leave() -> void:
	_close_network()
	state = State.IDLE
	is_host = false
	invite_code = ""
	error_message = ""
	changed.emit()


func player_count() -> int:
	if state == State.CONNECTED:
		return 2
	if is_host and state == State.HOSTING:
		return 1
	return 0


func _install_peer(peer: ENetMultiplayerPeer) -> void:
	_generation += 1
	_peer = peer
	_api = SceneMultiplayer.new()
	_api.auth_timeout = AUTH_TIMEOUT_SECONDS
	_api.server_relay = false
	_api.auth_callback = _receive_auth.bind(_generation)
	# Never replace/close the multiplayer peer inside its polling callback. Deferred
	# delivery also makes queued signals harmless after leave() or a new attempt.
	_api.peer_authenticating.connect(_on_peer_authenticating.bind(_generation), CONNECT_DEFERRED)
	_api.peer_authentication_failed.connect(_on_authentication_failed.bind(_generation), CONNECT_DEFERRED)
	_api.peer_connected.connect(_on_peer_connected.bind(_generation), CONNECT_DEFERRED)
	_api.peer_disconnected.connect(_on_peer_disconnected.bind(_generation), CONNECT_DEFERRED)
	_api.connection_failed.connect(_on_connection_failed.bind(_generation), CONNECT_DEFERRED)
	_api.server_disconnected.connect(_on_server_disconnected.bind(_generation), CONNECT_DEFERRED)
	get_tree().set_multiplayer(_api)
	_api.multiplayer_peer = _peer


func _close_network() -> void:
	_drop_peer()
	set_process(false)
	_room_token = ""
	_room_token_bytes.clear()
	_guest_id = 0
	_rejected_peers.clear()
	_connection_deadline_msec = 0
	_join_addresses = PackedStringArray()
	_join_index = 0
	_reached_host = false


func _drop_peer() -> void:
	_generation += 1
	if _api != null:
		_api.auth_callback = Callable()
		_api.multiplayer_peer = null
	if _peer != null:
		_peer.close()
	_peer = null
	_api = null


func _current_attempt(generation: int) -> bool:
	return generation == _generation and _peer != null and _api != null


func _on_peer_authenticating(id: int, generation: int) -> void:
	if not _current_attempt(generation) or not _api.get_authenticating_peers().has(id):
		return
	if not is_host and id == 1 and state == State.CONNECTING:
		_reached_host = true
		var send_error: Error = _api.send_auth(id, (INVITE_VERSION + "/" + _room_token).to_utf8_buffer())
		if send_error != OK:
			_fail("Cannot send the room credential. Check the connection and ask the host for a fresh invite.")


func _receive_auth(id: int, data: PackedByteArray, generation: int) -> void:
	# This callback runs within SceneMultiplayer.poll(), unlike our signal handlers.
	_process_auth.call_deferred(id, data, generation)


func _process_auth(id: int, data: PackedByteArray, generation: int) -> void:
	if not _current_attempt(generation) or not _api.get_authenticating_peers().has(id):
		return
	if is_host:
		if _rejected_peers.has(id) or id == _guest_id:
			return
		if data.size() > MAX_AUTH_PACKET_BYTES:
			_reject_peer(id, "INVALID")
			return
		var request: PackedStringArray = data.get_string_from_utf8().split("/", true)
		if request.size() != 2 or request[0] != INVITE_VERSION:
			_reject_peer(id, "VERSION")
			return
		if not _valid_token(request[1]) or not _crypto.constant_time_compare(_room_token_bytes, request[1].to_utf8_buffer()):
			_reject_peer(id, "INVALID")
			return
		if _guest_id != 0:
			_reject_peer(id, "FULL")
			return
		# Reserve before completing native auth so simultaneous correct requests
		# cannot both become admitted. A failed authentication releases this slot.
		_guest_id = id
		var send_error: Error = _api.send_auth(id, AUTH_ACCEPT.to_utf8_buffer())
		if send_error != OK:
			_guest_id = 0
			_api.disconnect_peer(id)
			return
		if _api.complete_auth(id) != OK:
			_guest_id = 0
			_api.disconnect_peer(id)
		return
	if id != 1 or state != State.CONNECTING:
		return
	if data.size() > MAX_AUTH_PACKET_BYTES:
		_fail("The host sent invalid authentication data. Use the same game version and ask for a fresh invite.")
		return
	match data.get_string_from_utf8():
		AUTH_ACCEPT:
			if _api.complete_auth(id) != OK:
				_fail("Room admission failed. Ask the host for a fresh invite and try again.")
		AUTH_FULL:
			_fail("This room is full (host plus one guest). Ask your friend to leave or host a new room.")
		AUTH_INVALID:
			_fail("The room credential was rejected. This code may be wrong or from an earlier room; ask the host to copy their current invite.")
		AUTH_VERSION:
			_fail("The host rejected this game version. Both players need the same version and a fresh invite.")
		_:
			_fail("The host sent invalid authentication data. Use the same game version and ask for a fresh invite.")


func _reject_peer(id: int, reason: String) -> void:
	_rejected_peers[id] = true
	# Keep this peer unauthenticated until it receives the reliable reason and
	# closes, or native auth_timeout drops it. Immediate disconnect loses the reply.
	if _api.send_auth(id, (INVITE_VERSION + "/" + reason).to_utf8_buffer()) != OK:
		_rejected_peers.erase(id)
		_api.disconnect_peer(id)


func _on_peer_connected(id: int, generation: int) -> void:
	if not _current_attempt(generation) or not _api.get_peers().has(id):
		return
	if is_host:
		if id != _guest_id:
			_api.disconnect_peer(id)
			return
	elif id != 1 or state != State.CONNECTING:
		return
	state = State.CONNECTED
	error_message = ""
	set_process(false)
	changed.emit()


func _on_peer_disconnected(id: int, generation: int) -> void:
	if not _current_attempt(generation):
		return
	if is_host and id == _guest_id:
		_guest_id = 0
		state = State.HOSTING
		error_message = ""
		changed.emit()
	elif not is_host and id == 1:
		_on_server_disconnected(generation)


func _on_authentication_failed(id: int, generation: int) -> void:
	if not _current_attempt(generation):
		return
	if is_host:
		_rejected_peers.erase(id)
		if id == _guest_id:
			_guest_id = 0
		return
	if id == 1 and state == State.CONNECTING:
		_fail("Room authentication failed or timed out. Check that both players use the same game version and ask the host for their current invite.")


func _on_connection_failed(generation: int) -> void:
	if _current_attempt(generation) and not is_host and not _try_next_address():
		_fail(_unreachable_message())


func _on_server_disconnected(generation: int) -> void:
	if _current_attempt(generation) and not is_host:
		_fail("The host disconnected or closed the room. Ask them to host again and send a new invite.")


func _fail(message: String) -> bool:
	_close_network()
	state = State.ERROR
	is_host = false
	invite_code = ""
	error_message = message
	changed.emit()
	return false


func _reject_active_action() -> bool:
	error_message = "Leave the current room or cancel the connection before starting another one."
	changed.emit()
	return false


static func _valid_token(token: String) -> bool:
	return token.length() == 32 and _only_characters(token, "0123456789abcdef")


static func _only_characters(value: String, allowed: String) -> bool:
	for character: String in value:
		if not allowed.contains(character):
			return false
	return true


# Parse a comma-separated host address list; empty if any entry is invalid.
static func _address_list(text: String) -> PackedStringArray:
	var addresses := PackedStringArray()
	for entry: String in text.split(",", false):
		var address: String = entry.strip_edges()
		if not _valid_address(address):
			return PackedStringArray()
		if address not in addresses:
			addresses.append(address)
	if addresses.size() > MAX_INVITE_ADDRESSES:
		return PackedStringArray()
	return addresses


static func _valid_address(address: String) -> bool:
	if not address.is_valid_ip_address():
		return false
	if address.contains(":"):
		var first_group: String = address.get_slice(":", 0).to_lower()
		var is_multicast: bool = first_group.length() == 4 and first_group.begins_with("ff")
		return not address.replace(":", "").replace("0", "").is_empty() and not is_multicast
	var first_octet: int = address.get_slice(".", 0).to_int()
	return first_octet > 0 and first_octet < 224
