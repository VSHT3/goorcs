class_name MatchPlanning
extends Node

signal changed
signal feedback(message: String)

var session: MultiplayerSession
var collection_store: CollectionStore
var combat_rules: CombatRules = preload("res://resources/combat/prototype.tres")
# Presentation copies only. Commands never read these mutable UI-facing values.
var layouts: Array[PathLayout] = [PathLayout.new(), PathLayout.new()]
var ready_flags: Array[bool] = [false, false]
var locked_routes: Array[Array] = [[], []]
var locked: bool = false
var active: bool = false
var singleplayer: bool = false
var combat: Dictionary = {}

var _dimensions: Vector2i = Vector2i(14, 9)
var _budget: int = 30
var _entrance: Vector2i = Vector2i(0, 4)
var _base: Vector2i = Vector2i(13, 4)
var _host_layouts: Array[PathLayout] = []
var _host_ready: Array[bool] = [false, false]
var _host_routes: Array[Array] = [[], []]
var _host_speed_votes: Array[bool] = [false, false]
var _host_autoplay_votes: Array[bool] = [false, false]
var _host_locked: bool = false
var _active_peer_id: int = 0
var _synced_guest_id: int = 0
var _pending_snapshot_peer: int = 0
var _host_combat: MatchCombat
var _combat_publish_elapsed: float = 0.0


func _physics_process(delta: float) -> void:
	if not active or (not singleplayer and not session.is_host) or _host_combat.phase != MatchCombat.Phase.WAVE:
		return
	var previous_phase: MatchCombat.Phase = _host_combat.phase
	if not _host_combat.advance(delta * _speed_multiplier()):
		return
	_combat_publish_elapsed += delta
	if _host_combat.phase != previous_phase:
		_host_locked = _host_combat.phase != MatchCombat.Phase.PLANNING
		_host_ready = [false, false]
		if _host_combat.phase == MatchCombat.Phase.FINISHED:
			_host_speed_votes = [false, false]
			_host_autoplay_votes = [false, false]
		elif _autoplay_enabled():
			_try_start_wave()
		set_physics_process(_host_combat.phase == MatchCombat.Phase.WAVE)
		_publish_snapshot()
	elif _combat_publish_elapsed >= 0.1:
		_combat_publish_elapsed = 0.0
		_publish_combat()


func configure(dimensions: Vector2i, budget: int, entrance: Vector2i, base: Vector2i) -> void:
	assert(not is_inside_tree())
	_dimensions = dimensions
	_budget = budget
	_entrance = entrance
	_base = base
	_reset_match()


func _ready() -> void:
	assert(session != null)
	set_multiplayer_authority(1)
	session.changed.connect(_on_session_changed)
	_reset_match()
	_on_session_changed()


func start_singleplayer() -> void:
	session.leave()
	_reset_match()
	singleplayer = true
	active = true
	_publish_snapshot()


func stop_singleplayer() -> void:
	if singleplayer:
		_reset_match()
		changed.emit()



func local_slot() -> int:
	return 0 if singleplayer or (session != null and session.is_host) else 1


func request_edit(slot: int, cell: Vector2i, place: bool) -> void:
	_request_command("edit", slot, cell, place)


func request_clear(slot: int) -> void:
	_request_command("clear", slot, Vector2i.ZERO, false)


func submit_ready(value: bool) -> void:
	_request_command("ready", local_slot(), Vector2i.ZERO, value)


func request_pacing(option: String, enabled: bool) -> void:
	if option not in ["speed", "autoplay"]:
		return
	_request_command(option, local_slot(), Vector2i.ZERO, enabled)


func build_tower(slot: int, cell: Vector2i, type_id: StringName, mode: int) -> void:
	if collection_store != null and not collection_store.is_unlocked(type_id):
		feedback.emit("Unlock this tower in your collection before buying it.")
		return
	_request_tower_command("build", slot, cell, -1, mode, String(type_id))


func set_targeting(slot: int, tower_id: int, mode: int) -> void:
	_request_tower_command("target", slot, Vector2i.ZERO, tower_id, mode, "")


func upgrade_tower(slot: int, tower_id: int, upgrade: String) -> void:
	_request_tower_command("upgrade", slot, Vector2i.ZERO, tower_id, -1, upgrade)


func sell_tower(slot: int, tower_id: int) -> void:
	_request_tower_command("sell", slot, Vector2i.ZERO, tower_id, -1, "")


func send_enemy(slot: int, type_id: StringName) -> void:
	_request_tower_command("send", slot, Vector2i.ZERO, -1, -1, String(type_id))


func _request_tower_command(command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String) -> void:
	if singleplayer:
		_apply_tower_command(1, command, slot, cell, tower_id, mode, argument)
		return
	if session == null or session.state != MultiplayerSession.State.CONNECTED or _active_peer_id == 0:
		feedback.emit("Wait for both players to connect and synchronize their boards.")
		return
	if session.is_host:
		_apply_tower_command(1, command, slot, cell, tower_id, mode, argument)
	else:
		_receive_tower_command.rpc_id(1, command, slot, cell, tower_id, mode, argument)


func _request_command(command: String, slot: int, cell: Vector2i, value: bool) -> void:
	if singleplayer:
		_apply_command(1, command, slot, cell, value)
		return
	if session == null or session.state != MultiplayerSession.State.CONNECTED or _active_peer_id == 0:
		feedback.emit("Wait for both players to connect and synchronize their boards.")
		return
	if session.is_host:
		_apply_command(1, command, slot, cell, value)
	else:
		_receive_command.rpc_id(1, command, slot, cell, value)


func _admitted_guest() -> int:
	var peers: PackedInt32Array = multiplayer.get_peers()
	return peers[0] if peers.size() == 1 else 0


func _on_session_changed() -> void:
	if session.state != MultiplayerSession.State.CONNECTED:
		_reset_match()
		changed.emit()
		return
	if session.is_host:
		var guest_id: int = _admitted_guest()
		if guest_id == 0 or guest_id == _active_peer_id:
			return
		var requested_snapshot: bool = _pending_snapshot_peer == guest_id
		_reset_match()
		_active_peer_id = guest_id
		active = true
		_publish_snapshot()
		if requested_snapshot:
			_sync_guest(guest_id)
	elif _active_peer_id == 0:
		# Do not expose editable boards until the host's settings and state arrive.
		# The host may have become connected before or after our deferred signal.
		_request_snapshot.rpc_id(1)


func _reset_match() -> void:
	_host_layouts = [
		PathLayout.new(_dimensions, _budget, _entrance, _base),
		PathLayout.new(_dimensions, _budget, _entrance, _base),
	]
	layouts = [
		PathLayout.new(_dimensions, _budget, _entrance, _base),
		PathLayout.new(_dimensions, _budget, _entrance, _base),
	]
	_host_ready = [false, false]
	_host_routes = [[], []]
	_host_speed_votes = [false, false]
	_host_autoplay_votes = [false, false]
	_host_locked = false
	ready_flags = [false, false]
	locked_routes = [[], []]
	locked = false
	active = false
	singleplayer = false
	_active_peer_id = 0
	_synced_guest_id = 0
	_pending_snapshot_peer = 0
	_host_combat = MatchCombat.new(combat_rules)
	combat = _combat_snapshot()
	_combat_publish_elapsed = 0.0
	set_physics_process(false)


@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not session.is_host or sender == 0 or sender != _admitted_guest():
		return
	if session.state == MultiplayerSession.State.HOSTING:
		# Authentication is complete, but MultiplayerSession's peer_connected
		# callback is deferred. Remember the handshake until admission is visible.
		_pending_snapshot_peer = sender
	elif session.state == MultiplayerSession.State.CONNECTED:
		_on_session_changed()
		_sync_guest(sender)


func _sync_guest(guest_id: int) -> void:
	if not _can_accept(guest_id):
		return
	_synced_guest_id = guest_id
	_receive_snapshot.rpc_id(guest_id, _snapshot())


@rpc("any_peer", "call_remote", "reliable")
func _receive_command(command: String, slot: int, cell: Vector2i, value: bool) -> void:
	_apply_command(multiplayer.get_remote_sender_id(), command, slot, cell, value)


@rpc("any_peer", "call_remote", "reliable")
func _receive_tower_command(command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String) -> void:
	_apply_tower_command(multiplayer.get_remote_sender_id(), command, slot, cell, tower_id, mode, argument)


func _apply_tower_command(sender: int, command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String) -> void:
	if not _can_accept(sender):
		return
	var permitted_slot: int = 0 if sender == 1 else 1
	if slot != permitted_slot:
		_reject(sender, "Only your own Coins and towers can be changed.")
		return
	if _host_combat.phase == MatchCombat.Phase.FINISHED:
		_reject(sender, "The run has ended. Leave to start another room.")
		return
	# IDs are globally unique, so resolve the counterpart by cell before a sale.
	var mirror_id: int = -1
	if singleplayer and sender == 1 and command not in ["build", "send"]:
		for tower: Dictionary in _host_combat.towers[0]:
			if tower["id"] == tower_id:
				for opponent: Dictionary in _host_combat.towers[1]:
					if opponent["cell"] == tower["cell"]:
						mirror_id = opponent["id"]
						break
				break
	if command == "send":
		if not _host_combat.send_enemy(slot, StringName(argument)):
			_reject(sender, "Not enough Coins or this enemy type is unavailable.")
			return
	elif command == "build":
		var layout: PathLayout = _host_layouts[slot]
		if not layout.contains(cell) or layout.has_path(cell):
			_reject(sender, "Build towers on empty ground, never on a path or endpoint.")
			return
		if not _host_combat.build(slot, cell, StringName(argument), mode):
			_reject(sender, "Not enough Coins, this cell is occupied, the tower type is unavailable, or the targeting mode is invalid.")
			return
	elif command == "target":
		if not _host_combat.set_targeting(slot, tower_id, mode):
			_reject(sender, "Choose an existing own tower and a different valid targeting mode.")
			return
	elif command == "upgrade":
		if not _host_combat.upgrade_tower(slot, tower_id, argument):
			_reject(sender, "Not enough Coins, this upgrade was already bought, or the tower/upgrade is invalid.")
			return
	elif command == "sell":
		if not _host_combat.sell_tower(slot, tower_id):
			_reject(sender, "Only an existing own tower can be sold.")
			return
	else:
		_reject(sender, "Unknown tower command.")
		return
	if _host_combat.phase == MatchCombat.Phase.PLANNING:
		_host_ready[slot] = false
	if singleplayer and sender == 1:
		_apply_tower_command(2, command, 1, cell, mirror_id, mode, argument)
		return
	_publish_snapshot()


func _can_accept(sender: int) -> bool:
	if singleplayer:
		return active and sender in [1, 2]
	if not session.is_host or session.state != MultiplayerSession.State.CONNECTED:
		return false
	var guest_id: int = _admitted_guest()
	return guest_id != 0 and guest_id == _active_peer_id and (sender == 1 or sender == guest_id)


func _apply_command(sender: int, command: String, slot: int, cell: Vector2i, value: bool) -> void:
	if not _can_accept(sender):
		return
	var permitted_slot: int = 0 if sender == 1 else 1
	if slot != permitted_slot:
		_reject(sender, "Only your own board can be changed.")
		return
	if command in ["speed", "autoplay"]:
		_apply_pacing(command, permitted_slot, value)
		return
	if _host_locked:
		_reject(sender, "Paths and readiness are locked during a wave or after the run ends.")
		return
	var layout: PathLayout = _host_layouts[permitted_slot]
	match command:
		"edit":
			if not layout.contains(cell) or layout.is_endpoint(cell):
				return
			if value and _host_combat.has_tower(permitted_slot, cell):
				_reject(sender, "A path cannot overlap an existing tower.")
				return
			if layout.has_path(cell) == value:
				return
			if value and layout.used_tiles() >= layout.budget:
				_reject(sender, "The path tile budget is exhausted.")
				return
			var edited: bool = layout.place(cell) if value else layout.erase(cell)
			if not edited:
				return
			_host_ready[permitted_slot] = false
		"clear":
			if layout.used_tiles() == 0:
				return
			layout.clear()
			_host_ready[permitted_slot] = false
		"ready":
			if value and not layout.is_ready():
				_reject(sender, "Connect the entrance to the base and remove all disconnected path tiles before readying.")
				return
			if _host_ready[permitted_slot] == value:
				return
			_host_ready[permitted_slot] = value
			# Manual readiness and autoplay capture routes through the same gate.
		_:
			_reject(sender, "Unknown planning command.")
			return
	if singleplayer and sender == 1:
		_apply_command(2, command, 1, cell, value)
		return
	if (_host_ready[0] and _host_ready[1]) or _autoplay_enabled():
		_try_start_wave()
	_publish_snapshot()


func _apply_pacing(option: String, slot: int, enabled: bool) -> void:
	if not active or _host_combat.phase not in [MatchCombat.Phase.PLANNING, MatchCombat.Phase.WAVE]:
		return
	var votes: Array[bool] = _host_speed_votes if option == "speed" else _host_autoplay_votes
	if votes[slot] == enabled:
		return
	votes[slot] = enabled
	if singleplayer:
		votes[1 - slot] = enabled
	if option == "autoplay" and _autoplay_enabled():
		_try_start_wave()
	_publish_snapshot()


func _speed_multiplier() -> float:
	return 2.0 if _host_speed_votes[0] and _host_speed_votes[1] else 1.0


func _autoplay_enabled() -> bool:
	return _host_autoplay_votes[0] and _host_autoplay_votes[1]


func _try_start_wave() -> bool:
	if not active or _host_combat.phase != MatchCombat.Phase.PLANNING:
		return false
	if not _host_layouts[0].is_ready() or not _host_layouts[1].is_ready():
		return false
	var routes: Array[Array] = [_host_layouts[0].route.duplicate(), _host_layouts[1].route.duplicate()]
	if not _host_combat.start_wave(routes):
		return false
	_host_routes = routes
	_host_locked = true
	_combat_publish_elapsed = 0.0
	set_physics_process(true)
	return true


func _combat_snapshot() -> Dictionary:
	var snapshot: Dictionary = _host_combat.snapshot()
	snapshot["speed_votes"] = _host_speed_votes.duplicate()
	snapshot["autoplay_votes"] = _host_autoplay_votes.duplicate()
	snapshot["speed_multiplier"] = _speed_multiplier()
	snapshot["autoplay"] = _autoplay_enabled()
	return snapshot


func _reject(sender: int, message: String) -> void:
	if singleplayer or sender == 1:
		feedback.emit(message)
	else:
		_receive_feedback.rpc_id(sender, message)


@rpc("authority", "call_remote", "reliable")
func _receive_feedback(message: String) -> void:
	if not session.is_host and session.state == MultiplayerSession.State.CONNECTED and multiplayer.get_remote_sender_id() == 1:
		feedback.emit(message)


func _snapshot() -> Dictionary:
	var tiles: Array[Array] = [[], []]
	for slot: int in range(2):
		var layout: PathLayout = _host_layouts[slot]
		for y: int in range(layout.dimensions.y):
			for x: int in range(layout.dimensions.x):
				var cell := Vector2i(x, y)
				if not layout.is_endpoint(cell) and layout.has_path(cell):
					tiles[slot].append(cell)
	return {
		"dimensions": _dimensions,
		"budget": _budget,
		"entrance": _entrance,
		"base": _base,
		"tiles": tiles,
		"ready": _host_ready.duplicate(),
		"locked": _host_locked,
		"routes": [_host_routes[0].duplicate(), _host_routes[1].duplicate()],
		"combat": _combat_snapshot(),
	}


func _publish_snapshot() -> void:
	var snapshot: Dictionary = _snapshot()
	_mirror_snapshot(snapshot)
	changed.emit()
	if _synced_guest_id != 0 and _can_accept(_synced_guest_id):
		_receive_snapshot.rpc_id(_synced_guest_id, snapshot)



func _publish_combat() -> void:
	combat = _combat_snapshot()
	changed.emit()
	if _synced_guest_id != 0 and _can_accept(_synced_guest_id):
		_receive_combat.rpc_id(_synced_guest_id, combat)


@rpc("authority", "call_remote", "reliable")
func _receive_combat(snapshot: Dictionary) -> void:
	if session.is_host or session.state != MultiplayerSession.State.CONNECTED or multiplayer.get_remote_sender_id() != 1:
		return
	combat = snapshot
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(snapshot: Dictionary) -> void:
	if session.is_host or session.state != MultiplayerSession.State.CONNECTED or multiplayer.get_remote_sender_id() != 1:
		return
	_active_peer_id = 1
	active = true
	_mirror_snapshot(snapshot)
	changed.emit()


func _mirror_snapshot(snapshot: Dictionary) -> void:
	var next_layouts: Array[PathLayout] = []
	for slot: int in range(2):
		var layout := PathLayout.new(snapshot["dimensions"], snapshot["budget"], snapshot["entrance"], snapshot["base"])
		for cell: Vector2i in snapshot["tiles"][slot]:
			layout.place(cell)
		next_layouts.append(layout)
	layouts = next_layouts
	ready_flags = [snapshot["ready"][0], snapshot["ready"][1]]
	locked = snapshot["locked"]
	locked_routes = [snapshot["routes"][0].duplicate(), snapshot["routes"][1].duplicate()]
	combat = snapshot["combat"]
