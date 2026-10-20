extends "res://tests/match_multiplayer_test.gd"


func _run() -> void:
	success_message = "PASS: real combat stream bursts, stale-frame rejection, reliable purchases, guest commands and terminal convergence"
	planning_worker_path = "res://tests/combat_stream_worker.gd"
	_suite_deadline_msec = Time.get_ticks_msec() + 60000
	_directory = OS.get_temp_dir().path_join("gorcs_stream_peer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int = _unused_port()
	if port == 0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary = await _command("host", {"action": "host", "port": port})
	await _connect_guest("guest", "host", hosted["code"])
	await _wait_for("host", {"active": true}, "Both loadouts admit the host")
	await _wait_for("guest", {"active": true}, "Both loadouts admit the guest")
	await _command("host", {"action": "stream_fixture"})
	var initial: Dictionary = _snapshot("host")["combat"]
	await _wait_combat("guest", initial, "Reliable baseline preserves full captured combat and metadata")
	await _command("guest", {"action": "pause_poll"})
	await _command("host", {"action": "stream_burst"})
	var live: Dictionary = _snapshot("host")["combat"]
	_check(_snapshot("guest")["combat"]["death_time"] == initial["death_time"], "A deliberately stalled guest cannot make the authoritative host wait")
	await _command("guest", {"action": "resume_poll"})
	await _wait_combat("guest", {"death_time": live["death_time"], "health": live["health"], "coins": live["coins"], "enemies": live["enemies"]}, "Guest receives current combat instead of replaying a late stale frame")
	_check(_snapshot("guest")["combat"]["tower_types"] == initial["tower_types"], "Combat stream retains the reliable host's authored tower rules")
	await _command("host", {"action": "stream_transaction"})
	var purchased: Dictionary = _snapshot("host")["combat"]
	await _wait_combat("guest", {"coins": purchased["coins"], "towers": purchased["towers"]}, "Reliable live purchase cannot be undone by a stale pre-purchase combat revision")
	await _command("guest", {"action": "send", "slot": 1, "type_id": "orcling"})
	var debit: int = int(initial["enemy_types"]["orcling"]["send_cost"])
	await _wait_combat("host", {"coins": [purchased["coins"][0], purchased["coins"][1] - debit]}, "Guest management command is accepted after the combat burst")
	await _wait_combat("guest", {"coins": _snapshot("host")["combat"]["coins"]}, "Guest receives authoritative command cost without waiting for obsolete combat frames")
	await _command("host", {"action": "stream_end"})
	var terminal: Dictionary = _snapshot("host")["combat"]
	await _wait_combat("guest", terminal, "Reliable terminal state converges exactly despite in-flight combat frames")
	await _finish()
