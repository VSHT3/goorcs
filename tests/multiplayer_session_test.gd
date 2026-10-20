extends SceneTree

const LANES: Array[String] = ["host", "guest", "third"]
const WAIT_SECONDS: float = 16.0
const SUITE_DEADLINE_SECONDS: float = 120.0

var failures: int = 0
var _directory: String = ""
var _processes: Dictionary[String, int] = {}
var _command_ids: Dictionary[String, int] = {}
var _suite_deadline_msec: int = 0
var success_message: String = "PASS: real ENet admission, invalid/wrong/version/full rejection, authentication deadline, cancellation, leave/rejoin, host loss, fresh credentials, node exit and port reuse"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_host_address_selection()
	_suite_deadline_msec = Time.get_ticks_msec() + int(SUITE_DEADLINE_SECONDS * 1000.0)
	_directory = OS.get_temp_dir().path_join("goorcs_session_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_check(false, "Create isolated temporary result directory")
		quit(1)
		return
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	await _test_malformed_invites(port)
	await _test_room_lifecycle(port)
	await _finish()


func _test_host_address_selection() -> void:
	var interfaces: Array[Dictionary] = [
		{"name": "utun4", "friendly": "utun4", "addresses": ["172.16.0.2"]},
		{"name": "lo0", "friendly": "lo0", "addresses": ["127.0.0.1"]},
		{"name": "en0", "friendly": "en0", "addresses": ["fe80::1", "169.254.1.2", "10.37.34.238"]},
	]
	_check(MultiplayerLobby._preferred_host_address(interfaces) == "10.37.34.238", "LAN hosting chooses Wi-Fi instead of an earlier VPN tunnel")
	interfaces.reverse()
	_check(MultiplayerLobby._preferred_host_address(interfaces) == "10.37.34.238", "Adapter enumeration order cannot replace Wi-Fi with a VPN address")
	for name: String in ["eth0", "wlp2s0", "{adapter-guid}"]:
		interfaces = [
			{"name": "tun0", "addresses": ["10.8.0.2"]},
			{"name": name, "friendly": "Ethernet", "addresses": ["172.20.1.5"]},
		]
		_check(MultiplayerLobby._preferred_host_address(interfaces) == "172.20.1.5", "LAN adapter is preferred on supported desktop interface names: " + name)
	_check(MultiplayerLobby._preferred_host_address([{"name": "utun4", "addresses": ["172.16.0.2"]}]) == "172.16.0.2", "VPN-only machines retain an available numeric host address")
	_check(MultiplayerLobby._preferred_host_address([{"name": "en0", "addresses": ["::1", "0.0.0.0", "127.0.0.1", "169.254.1.2", "224.0.0.1"]}]) == "127.0.0.1", "No usable interface falls back to local-only hosting")


func _test_malformed_invites(port: int) -> void:
	var token: String = "0123456789abcdef0123456789abcdef"
	var malformed: Array[String] = [
		"", "GORCS1", "GORCS1/127.0.0.1/%d" % port,
		"GORCS2/127.0.0.1/%d/%s" % [port, token],
		"GORCS1/localhost/%d/%s" % [port, token],
		"GORCS1/999.0.0.1/%d/%s" % [port, token],
		"GORCS1/0.0.0.0/%d/%s" % [port, token],
		"GORCS1/::/%d/%s" % [port, token],
		"GORCS1/127.0.0.1/0/%s" % token,
		"GORCS1/127.0.0.1/65536/%s" % token,
		"GORCS1/127.0.0.1/+7000/%s" % token,
		"GORCS1/127.0.0.1/7e3/%s" % token,
		"GORCS1/127.0.0.1/%d/%s" % [port, token.to_upper()],
		"GORCS1/127.0.0.1/%d/%s" % [port, token.left(31)],
		"GORCS1/127.0.0.1/%d/%sz" % [port, token.left(31)],
		"GORCS1/127.0.0.1/%d/%s/extra" % [port, token],
	]
	for code: String in malformed:
		var snapshot: Dictionary = await _command("guest", {"action": "join", "code": code})
		_check(_matches(snapshot, {"result": false, "state": "ERROR", "count": 0, "native_peers": []}) and not String(snapshot.get("error", "")).is_empty(),
			"Malformed invite is rejected before admitting any peer: %s" % code)
	for invalid_host: Dictionary in [
		{"address": "localhost", "port": port},
		{"address": "0.0.0.0", "port": port},
		{"address": "127.0.0.1", "port": 0},
		{"address": "127.0.0.1", "port": 65536},
	]:
		invalid_host["action"] = "host"
		var snapshot: Dictionary = await _command("host", invalid_host)
		_check(_matches(snapshot, {"result": false, "state": "ERROR", "count": 0, "code": ""}) and not String(snapshot.get("error", "")).is_empty(),
			"Invalid hosting endpoint fails visibly without publishing an invite")


func _test_room_lifecycle(port: int) -> void:
	var host_snapshot: Dictionary = await _command("host", {"action": "host", "port": port})
	_check(_matches(host_snapshot, {"result": true, "state": "HOSTING", "is_host": true, "count": 1, "authority": 1, "native_peers": []}),
		"Hosting creates one waiting authoritative player")
	var code: String = String(host_snapshot.get("code", ""))
	if code.is_empty():
		_check(false, "Hosting produces an actual invite")
		return
	var parts: PackedStringArray = code.split("/")
	if parts.size() != 4:
		_check(false, "Generated invite contains the endpoint and room credential")
		return
	var token: String = parts[3]
	var wrong_token: String = ("1" if token.begins_with("0") else "0") + token.substr(1)
	var wrong_code: String = "GORCS1/127.0.0.1/%d/%s" % [port, wrong_token]

	await _command("third", {"action": "join", "code": wrong_code})
	var rejected: Dictionary = await _wait_for("third", {"state": "ERROR", "count": 0, "native_peers": []}, "Wrong room credential is rejected")
	_check(String(rejected.get("error", "")).to_lower().contains("credential"), "Wrong-token failure explains how to obtain a current credential")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "code": code, "native_peers": []}, "Wrong token does not claim the guest slot")

	await _command("third", {"action": "raw_join", "port": port, "payload": "GORCS0/" + token})
	await _wait_for("third", {"raw_state": "REJECTED", "raw_response": "GORCS1/VERSION", "native_peers": []}, "A real version-mismatched peer is never admitted")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "code": code, "native_peers": []}, "Version rejection preserves the waiting host")

	await _command("third", {"action": "raw_join", "port": port, "payload": "GORCS1/" + token})
	await _wait_for("third", {"raw_state": "AUTHENTICATING", "raw_response": "GORCS1/ACCEPT", "native_peers": []}, "Correct credential alone does not count as native admission")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "authenticating": 1, "native_peers": []}, "An unfinished authentication cannot count as the second player")
	await _command("guest", {"action": "join", "code": code})
	var reserved_rejection: Dictionary = await _wait_for("guest", {"state": "ERROR", "count": 0, "native_peers": []}, "A concurrent guest cannot bypass an unfinished admission reservation")
	_check(String(reserved_rejection.get("error", "")).to_lower().contains("full"), "The host reserves only one guest slot during authentication")
	await _wait_for("third", {"raw_state": "ERROR", "native_peers": []}, "Unfinished native authentication has a bounded timeout")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "authenticating": 0, "native_peers": []}, "Authentication timeout frees its reserved slot")

	await _connect_guest("guest", "host", code)
	var accepted_peers: Array = _snapshot("host").get("native_peers", [])
	_check(accepted_peers.size() == 1, "Exactly one real guest is admitted to the host")
	var active_attempt: Dictionary = await _command("host", {"action": "join", "code": "invalid"})
	_check(_matches(active_attempt, {"result": false, "state": "CONNECTED", "count": 2, "code": code, "native_peers": accepted_peers}),
		"Starting another operation cannot tear down an existing room")

	await _command("third", {"action": "join", "code": wrong_code})
	await _wait_for("third", {"state": "ERROR", "count": 0, "native_peers": []}, "Wrong credential remains rejected in an occupied room")
	await _room_intact(code, accepted_peers, "Wrong-token attempt cannot displace the accepted guest")
	await _command("third", {"action": "join", "code": code})
	rejected = await _wait_for("third", {"state": "ERROR", "count": 0, "native_peers": []}, "Third player is rejected without admission")
	_check(String(rejected.get("error", "")).to_lower().contains("full"), "Third player receives an actionable room-full failure")
	await _room_intact(code, accepted_peers, "A full-room attempt preserves both existing players")

	var cancelled: Dictionary = await _command("third", {"action": "join_cancel", "code": code})
	_check(_matches(cancelled, {"result": true, "state": "IDLE", "count": 0, "native_peers": [], "error": ""}), "Immediate cancellation closes the pending peer and returns idle")
	await _room_intact(code, accepted_peers, "Cancelled third-player attempt preserves the room")

	await _command("guest", {"action": "leave"})
	await _wait_for("guest", {"state": "IDLE", "count": 0, "native_peers": []}, "Guest leave closes its session")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "code": code, "native_peers": []}, "Guest disconnect returns host to waiting with the same live invite")
	await _connect_guest("guest", "host", code)

	await _command("host", {"action": "leave"})
	await _wait_for("host", {"state": "IDLE", "count": 0, "code": "", "native_peers": []}, "Host leave removes the invite and closes the room")
	rejected = await _wait_for("guest", {"state": "ERROR", "count": 0, "native_peers": []}, "Host disconnect ends the guest session")
	_check(String(rejected.get("error", "")).to_lower().contains("host"), "Host disconnect explains that a new host invite is needed")
	host_snapshot = await _command("host", {"action": "host", "port": port})
	_check(_matches(host_snapshot, {"result": true, "state": "HOSTING", "count": 1}), "Host can immediately reuse the released UDP port")
	var fresh_code: String = String(host_snapshot.get("code", ""))
	_check(not fresh_code.is_empty() and fresh_code != code, "Restarting the room invalidates the old credential")
	await _command("guest", {"action": "join", "code": code})
	await _wait_for("guest", {"state": "ERROR", "count": 0, "native_peers": []}, "An old room code cannot join a restarted host")
	await _wait_for("host", {"state": "HOSTING", "count": 1, "code": fresh_code}, "Expired-code attempt preserves the restarted host")
	await _connect_guest("guest", "host", fresh_code)

	await _command("host", {"action": "free_session"})
	await _wait_for("guest", {"state": "ERROR", "count": 0, "native_peers": []}, "Removing the session node closes the guest's connection")
	var third_snapshot: Dictionary = await _command("third", {"action": "host", "port": port})
	_check(_matches(third_snapshot, {"result": true, "state": "HOSTING", "count": 1}), "Node exit releases the port for a different real process")
	var third_code: String = String(third_snapshot.get("code", ""))
	await _connect_guest("guest", "third", third_code)
	await _command("guest", {"action": "leave"})
	await _wait_for("third", {"state": "HOSTING", "count": 1, "native_peers": []}, "The replacement host also returns to waiting")
	await _command("third", {"action": "leave"})

	await _command("guest", {"action": "join", "code": third_code})
	rejected = await _wait_for("guest", {"state": "ERROR", "count": 0, "native_peers": []}, "Unreachable host attempt ends within a bounded deadline")
	_check(not String(rejected.get("error", "")).is_empty(), "Unreachable host failure is visible and actionable")
	cancelled = await _command("guest", {"action": "join_cancel", "code": third_code})
	_check(_matches(cancelled, {"result": true, "state": "IDLE", "count": 0, "error": "", "native_peers": []}), "A fresh unreachable attempt can be cancelled immediately after failure")
	host_snapshot = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", String(host_snapshot.get("code", "")))


func _connect_guest(guest_lane: String, host_lane: String, code: String) -> void:
	var joining: Dictionary = await _command(guest_lane, {"action": "join", "code": code})
	_check(bool(joining.get("result", false)), "A valid invite starts a real guest connection")
	await _wait_for(guest_lane, {"state": "CONNECTED", "count": 2, "is_host": false, "authority": 1, "native_peers": [1]}, "Guest is admitted to the authoritative host")
	var connected: Dictionary = await _wait_for(host_lane, {"state": "CONNECTED", "count": 2, "is_host": true}, "Host sees two genuinely admitted players")
	_check(connected.get("native_peers", []).size() == 1, "Host's native API contains exactly its accepted guest")


func _room_intact(code: String, accepted_peers: Array, description: String) -> void:
	await _wait_for("host", {"state": "CONNECTED", "count": 2, "code": code, "native_peers": accepted_peers}, description)
	await _wait_for("guest", {"state": "CONNECTED", "count": 2, "native_peers": [1]}, description + " (guest)")


func _unused_port() -> int:
	var socket := PacketPeerUDP.new()
	var bind_error: Error = socket.bind(0)
	_check(bind_error == OK, "Reserve an available isolated UDP test endpoint")
	if bind_error != OK:
		return 0
	var port: int = socket.get_local_port()
	socket.close()
	return port


func _start_workers() -> bool:
	for lane: String in LANES:
		_command_ids[lane] = 0
		var arguments := PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", _directory.path_join(lane + ".log"),
			"--script", "res://tests/multiplayer_session_worker.gd", "--", _directory, lane,
		])
		var pid: int = OS.create_process(OS.get_executable_path(), arguments)
		_check(pid > 0, "Start separate real ENet process: " + lane)
		if pid <= 0:
			return false
		_processes[lane] = pid
	for lane: String in LANES:
		var started: Dictionary = await _wait_for(lane, {"id": 0, "state": "IDLE", "count": 0}, "Worker becomes ready: " + lane)
		if started.is_empty():
			return false
	return true


func _command(lane: String, command: Dictionary) -> Dictionary:
	_send_command(lane, command)
	return await _wait_for(lane, {"id": _command_ids[lane]}, "Worker handles " + String(command["action"]) + ": " + lane)


func _send_command(lane: String, command: Dictionary) -> void:
	_command_ids[lane] += 1
	var payload: Dictionary = command.duplicate()
	payload["id"] = _command_ids[lane]
	var path: String = _path(lane, "command")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		_check(false, "Write isolated worker command: " + lane)
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	_check(DirAccess.rename_absolute(path + ".tmp", path) == OK, "Publish isolated worker command: " + lane)


func _wait_for(lane: String, expected: Dictionary, description: String, seconds: float = WAIT_SECONDS) -> Dictionary:
	var deadline_msec: int = mini(_suite_deadline_msec, Time.get_ticks_msec() + int(seconds * 1000.0))
	var snapshot: Dictionary = {}
	while Time.get_ticks_msec() < deadline_msec:
		snapshot = _snapshot(lane)
		if _matches(snapshot, expected):
			return snapshot
		if _processes.has(lane) and not OS.is_process_running(_processes[lane]):
			break
		await create_timer(0.02).timeout
	_check(false, "%s; expected %s, observed %s" % [description, expected, snapshot])
	return snapshot


func _matches(snapshot: Dictionary, expected: Dictionary) -> bool:
	for key: Variant in expected:
		if not snapshot.has(key):
			return false
		var actual: Variant = snapshot[key]
		var wanted: Variant = expected[key]
		if wanted is Array:
			if not actual is Array or actual.size() != wanted.size():
				return false
			# JSON numbers become floats; compare peer IDs by value, not Array's
			# strict element-type equality between [1.0] and [1].
			for index: int in range(wanted.size()):
				if actual[index] != wanted[index]:
					return false
		elif actual != wanted:
			return false
	return true


func _snapshot(lane: String) -> Dictionary:
	var path: String = _path(lane, "status")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _path(lane: String, kind: String) -> String:
	return _directory.path_join("%s.%s.json" % [lane, kind])


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _finish() -> void:
	for lane: String in _processes:
		if OS.is_process_running(_processes[lane]):
			_send_command(lane, {"action": "quit"})
	var deadline_msec: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline_msec:
		var still_running: bool = false
		for pid: int in _processes.values():
			still_running = still_running or OS.is_process_running(pid)
		if not still_running:
			break
		await create_timer(0.02).timeout
	for lane: String in _processes:
		var pid: int = _processes[lane]
		if OS.is_process_running(pid):
			OS.kill(pid)
			_check(false, "Worker required bounded forced cleanup: " + lane)
		else:
			_check(OS.get_process_exit_code(pid) == 0, "Worker exits cleanly: " + lane)
		var log_path: String = _directory.path_join(lane + ".log")
		if FileAccess.file_exists(log_path):
			var log_text: String = FileAccess.get_file_as_string(log_path)
			_check(not log_text.contains("ERROR:"), "Worker produces no Godot runtime/script errors: " + lane)
	if failures == 0:
		print(success_message)
	else:
		for lane: String in _processes:
			var log_path: String = _directory.path_join(lane + ".log")
			if FileAccess.file_exists(log_path):
				print("Session worker log (%s):\n%s" % [lane, FileAccess.get_file_as_string(log_path)])
	_cleanup_results()
	quit(1 if failures > 0 else 0)


func _cleanup_results() -> void:
	if _directory.is_empty():
		return
	var directory := DirAccess.open(_directory)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(_directory.path_join(file_name))
	directory = null
	DirAccess.remove_absolute(_directory)
