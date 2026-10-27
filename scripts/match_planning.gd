class_name MatchPlanning
extends Node

signal changed
signal feedback(message: String)

const SNAPSHOT_CODEC = preload("res://scripts/combat_snapshot_codec.gd")

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
var selecting_loadout: bool = false
var chosen_tower_ids: Array[StringName] = []
var chosen_commander_id: StringName = &""
var commander_ids: Array[StringName] = [&"", &""]
var commander_draft: Dictionary = {}
var loadout_committed: bool = false
var opponent_committed: bool = false
var combat: Dictionary = {}

var _dimensions: Vector2i = Vector2i(14, 9)
var _budget: int = 30
var _entrance: Vector2i = Vector2i(0, 4)
var _base: Vector2i = Vector2i(13, 4)
var _host_layouts: Array[PathLayout] = []
var _host_ready: Array[bool] = [false, false]
var _host_routes: Array[Array] = [[], []]
var _host_speed_votes: Array[bool] = [false, false]
# 3× is a stronger speed vote: it only applies once both players pick it.
var _host_triple_speed_votes: Array[bool] = [false, false]
var _solo_speed: int = 1
var _host_autoplay_votes: Array[bool] = [false, false]
# Full autoplay also starts setup/main strategy rounds once paths are legal.
var _host_full_autoplay_votes: Array[bool] = [false, false]
var _host_locked: bool = false
var _active_peer_id: int = 0
var _synced_guest_id: int = 0
var _pending_snapshot_peer: int = 0
var _host_combat: MatchCombat
var _combat_publish_elapsed: float = 0.0
# Reliable control revisions fence phase/layout/transaction changes. Combat has
# its own reliable channel with one frame in flight and only the newest unsent
# frame retained, so a slow guest cannot build a playback/command backlog.
var _snapshot_revision: int = 0
var _snapshot_sequence: int = 0
var _accepted_revision: int = 0
var _accepted_sequence: int = 0
var _pending_combat_packet := PackedByteArray()
var _pending_combat_revision: int = 0
var _pending_combat_sequence: int = 0
var _combat_flush_queued: bool = false
var _combat_in_flight: int = 0
var _queued_combat_frame: Dictionary = {}
var _queued_combat_revision: int = 0
var _queued_combat_sequence: int = 0
var _combat_baseline: Dictionary = {}
# Private authority state: never send both decks in one peer snapshot.
var _host_loadouts: Array[Array] = [[], []]
var _host_loadout_committed: Array[bool] = [false, false]
var _host_owned_claims: Array[Array] = [[], []]
var _host_commander_ids: Array[StringName] = [&"", &""]
var _commander_rng := RandomNumberGenerator.new()
var _draft_rng := RandomNumberGenerator.new()
var _host_draft_target: int = -1
# Survives match resets so replay/rejoin cannot roll consecutive 67s.
var _previous_draft_target: int = -1
var _host_commander_guesses: Array[int] = [-1, -1]
var _host_first_picker: int = -1
var _host_commander_picker: int = -1
var _host_draft_phase: String = "guessing"

var _ready_seconds_left: float = -1.0
var _expansion_count: int = 0

func _physics_process(delta: float) -> void:
	if not active or (not singleplayer and (session == null or not session.is_host)):
		return
	if _host_combat.phase == MatchCombat.Phase.PLANNING:
		if _ready_seconds_left < 0.0:
			return
		# Readiness consumes wall time, independently of the simulation speed vote.
		_ready_seconds_left = maxf(0.0, _ready_seconds_left - delta)
		_combat_publish_elapsed += delta
		if _ready_seconds_left == 0.0:
			_try_start_wave()
			_update_processing()
			_publish_snapshot()
		elif _combat_publish_elapsed >= 0.1:
			_combat_publish_elapsed = 0.0
			_publish_combat()
		return
	if _host_combat.phase != MatchCombat.Phase.WAVE:
		return
	var previous_phase: MatchCombat.Phase = _host_combat.phase
	if not _host_combat.advance(delta * _speed_multiplier()):
		return
	_combat_publish_elapsed += delta
	if _host_combat.phase != previous_phase:
		if _host_combat.phase == MatchCombat.Phase.FINISHED:
			_host_locked = true
			_host_ready = [false, false]
			_ready_seconds_left = -1.0
			_host_speed_votes = [false, false]
			_host_triple_speed_votes = [false, false]
			_solo_speed = 1
			_host_autoplay_votes = [false, false]
			_host_full_autoplay_votes = [false, false]
		else:
			_enter_planning()
			_try_start_wave()
		_update_processing()
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
	_draft_rng.randomize()
	_reset_match()
	_on_session_changed()


func start_singleplayer() -> void:
	session.leave()
	_reset_match()
	singleplayer = true
	selecting_loadout = true
	_begin_commander_draft()
	_publish_snapshot()


func stop_singleplayer() -> void:
	if singleplayer:
		_reset_match()
		changed.emit()


func is_equipped(type_id: StringName) -> bool:
	return chosen_tower_ids.has(type_id)


func select_loadout(ids: Array) -> bool:
	if not selecting_loadout or loadout_committed or commander_draft.get("phase", "") != "loadout":
		return false
	var owned: Array = _local_owned_ids()
	var validated: Array[StringName] = _validated_loadout(ids, owned)
	if validated.is_empty():
		feedback.emit("Choose one to four distinct unlocked tower types.")
		return false
	return _request_loadout_command("select", validated, owned)


func select_commander(id: StringName) -> bool:
	if not selecting_loadout or loadout_committed or not CommanderRules.valid(id) or commander_draft.get("phase", "") != "picking" or int(commander_draft.get("picker", -1)) != local_slot() or chosen_commander_id != &"":
		return false
	return _request_loadout_command("commander", [], [], String(id))


func submit_commander_guess(value: int) -> bool:
	if not selecting_loadout or value < 0 or value > 100 or commander_draft.get("phase", "") != "guessing" or commander_draft.get("guess_locked", [false, false])[local_slot()]:
		return false
	return _request_loadout_command("guess", [value], [])


func commit_loadout() -> bool:
	if not selecting_loadout or loadout_committed or chosen_tower_ids.is_empty() or commander_draft.get("phase", "") != "loadout":
		return false
	return _request_loadout_command("commit", [], [])


func _local_owned_ids() -> Array:
	var result: Array = []
	for definition: TowerDefinition in combat_rules.catalog.towers:
		if definition != null and definition.reward != null and (collection_store == null or (collection_store.error_message.is_empty() and collection_store.is_unlocked(definition.reward.id))):
			result.append(definition.reward.id)
	return result


func _catalog_has_tower(id: StringName) -> bool:
	for definition: TowerDefinition in combat_rules.catalog.towers:
		if definition != null and definition.reward != null and definition.reward.id == id:
			return true
	return false


func _validated_loadout(ids: Array, owned: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	if ids.is_empty() or ids.size() > 4:
		return result
	for value: Variant in ids:
		if not value is String and not value is StringName:
			return []
		var id := StringName(value)
		if id == &"" or result.has(id) or not owned.has(id) or not _catalog_has_tower(id):
			return []
		result.append(id)
	return result


func _request_loadout_command(command: String, ids: Array, owned: Array, commander_id: String = "") -> bool:
	if singleplayer:
		return _apply_loadout_command(1, command, ids, owned, commander_id)
	if session == null or session.state != MultiplayerSession.State.CONNECTED or _active_peer_id == 0:
		return false
	if session.is_host:
		return _apply_loadout_command(1, command, ids, owned, commander_id)
	_receive_loadout_command.rpc_id(1, command, ids, owned, commander_id)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _receive_loadout_command(command: String, ids: Array, owned: Array, commander_id: String = "") -> void:
	_apply_loadout_command(multiplayer.get_remote_sender_id(), command, ids, owned, commander_id)


func _apply_loadout_command(sender: int, command: String, ids: Array, owned: Array, commander_id: String = "") -> bool:
	if not _can_accept(sender) or not selecting_loadout:
		return false
	var slot: int = 0 if sender == 1 else 1
	if _host_loadout_committed[slot]:
		_reject(sender, "Your run loadout is already committed.")
		return false
	if command not in ["guess", "commander"] and _host_draft_phase != "loadout":
		_reject(sender, "Finish the commander draft before choosing towers.")
		return false
	if command == "select":
		# There are no accounts: remote ownership is a trusted local-save claim.
		# Validate its shape/catalog, never substitute the host's own collection.
		var claim: Array = _local_owned_ids() if slot == 0 else owned
		var known: Array = []
		for value: Variant in claim:
			if (not value is String and not value is StringName) or StringName(value) == &"":
				return false
			var id := StringName(value)
			if known.has(id) or not _catalog_has_tower(id):
				return false
			known.append(id)
		var validated: Array[StringName] = _validated_loadout(ids, known)
		if validated.is_empty():
			_reject(sender, "Choose one to four distinct unlocked tower types.")
			return false
		_host_loadouts[slot] = validated
		_host_owned_claims[slot] = known
	elif command == "guess":
		if ids.size() != 1 or not ids[0] is int or not _apply_commander_guess(slot, int(ids[0])):
			_reject(sender, "Lock one integer guess from 0 to 100.")
			return false
		_auto_pick_solo_commander()
	elif command == "commander":
		if not _pick_commander(slot, StringName(commander_id)):
			_reject(sender, "Wait for your pick and choose an available commander.")
			return false
		_auto_pick_solo_commander()
	elif command == "commit":
		var claim: Array = _local_owned_ids() if slot == 0 else _host_owned_claims[slot]
		if _validated_loadout(_host_loadouts[slot], claim).is_empty():
			_reject(sender, "Select your unlocked tower types before committing.")
			return false
		if not CommanderRules.valid(_host_commander_ids[slot]):
			return false
		var both_committed: bool = singleplayer or _host_loadout_committed[1 - slot]
		if both_committed and not _configure_commander_boards():
			_reject(sender, "This board cannot fit commander terrain and a legal route.")
			return false
		_host_loadout_committed[slot] = true
		if singleplayer:
			_host_loadouts[1] = _host_loadouts[0].duplicate()
			_host_owned_claims[1] = _host_owned_claims[0].duplicate()
			_host_loadout_committed[1] = true
		if _host_loadout_committed[0] and _host_loadout_committed[1]:
			selecting_loadout = false
			active = true
	else:
		return false
	_publish_snapshot()
	return true


func _begin_commander_draft() -> void:
	if _previous_draft_target != 67 and _draft_rng.randi_range(0, 2) == 0:
		_host_draft_target = 67
	else:
		# Uniformly choose among the other 100 integers without a retry loop.
		_host_draft_target = _draft_rng.randi_range(0, 99)
		if _host_draft_target >= 67:
			_host_draft_target += 1
	_previous_draft_target = _host_draft_target
	if singleplayer:
		_host_commander_guesses[1] = _draft_rng.randi_range(0, 100)


func _apply_commander_guess(slot: int, value: int) -> bool:
	if _host_draft_phase != "guessing" or _host_draft_target < 0 or _host_commander_guesses[slot] >= 0 or value < 0 or value > 100:
		return false
	_host_commander_guesses[slot] = value
	if _host_commander_guesses[0] >= 0 and _host_commander_guesses[1] >= 0:
		var first_distance: int = absi(_host_commander_guesses[0] - _host_draft_target)
		var second_distance: int = absi(_host_commander_guesses[1] - _host_draft_target)
		_host_first_picker = _draft_rng.randi_range(0, 1) if first_distance == second_distance else (0 if first_distance < second_distance else 1)
		_host_commander_picker = _host_first_picker
		_host_draft_phase = "picking"
	return true


func _pick_commander(slot: int, id: StringName) -> bool:
	if _host_draft_phase != "picking" or slot != _host_commander_picker or _host_commander_ids[slot] != &"" or not CommanderRules.valid(id) or _host_commander_ids.has(id):
		return false
	_host_commander_ids[slot] = id
	if _host_commander_ids[0] != &"" and _host_commander_ids[1] != &"":
		_host_draft_phase = "loadout"
		_host_commander_picker = -1
	else:
		_host_commander_picker = 1 - slot
	return true


func _auto_pick_solo_commander() -> void:
	if not singleplayer or _host_draft_phase != "picking" or _host_commander_picker != 1:
		return
	var available: Array[StringName] = []
	for id: StringName in [CommanderRules.KNIGHT, CommanderRules.PRIESTESS]:
		if not _host_commander_ids.has(id):
			available.append(id)
	var index: int = _draft_rng.randi_range(0, available.size() - 1) if available.size() > 1 else 0
	_pick_commander(1, available[index])


func _commander_draft_snapshot() -> Dictionary:
	var revealed: bool = _host_commander_guesses[0] >= 0 and _host_commander_guesses[1] >= 0
	return {
		"phase": _host_draft_phase,
		"guess_locked": [_host_commander_guesses[0] >= 0, _host_commander_guesses[1] >= 0],
		"guesses": _host_commander_guesses.duplicate() if revealed else [-1, -1],
		"target": _host_draft_target if revealed else -1,
		"first_picker": _host_first_picker, "picker": _host_commander_picker,
		"picks": [String(_host_commander_ids[0]), String(_host_commander_ids[1])],
	}


func _configure_commander_boards() -> bool:
	var previous_rng_state: int = _commander_rng.state
	var first: Dictionary = CommanderRules.generate(_host_commander_ids[0], _host_layouts[0], _commander_rng)
	var second: Dictionary = CommanderRules.generate(_host_commander_ids[1], _host_layouts[1], _commander_rng)
	if first.is_empty() or second.is_empty():
		_commander_rng.state = previous_rng_state
		return false
	_host_combat.configure_commanders([first, second])
	return true



func local_slot() -> int:
	return 0 if singleplayer or (session != null and session.is_host) else 1


func can_edit_path(slot: int) -> bool:
	return active and slot in [0, 1] and bool(combat.get("path_editing", false)) and not ready_flags[slot]


func can_manage_towers(slot: int) -> bool:
	if not active or slot not in [0, 1]:
		return false
	var phase: int = int(combat.get("phase", MatchCombat.Phase.FINISHED))
	return phase == MatchCombat.Phase.WAVE or (phase == MatchCombat.Phase.PLANNING and not ready_flags[slot])


# Round / Coin / Shard editing is a solo tool; multiplayer matches never offer it.
func can_debug() -> bool:
	return singleplayer and _host_can_set_values()


func debug_set_values(round_number: int, money: int, shards: int) -> bool:
	return can_debug() and _set_debug_values(round_number, money, shards)


func _host_can_set_values() -> bool:
	if not active or _host_combat == null or _host_combat.phase == MatchCombat.Phase.FINISHED:
		return false
	return singleplayer or (session != null and session.is_host and session.state == MultiplayerSession.State.CONNECTED and _active_peer_id != 0)


# Host-authoritative round/balance jump; test fixtures use it in network matches.
func _set_debug_values(round_number: int, money: int, shards: int) -> bool:
	if not _host_can_set_values() or round_number < 1 or round_number > 1000 or money < 0 or money > 1000000000 or shards < 0 or shards > 1000000000:
		return false
	var displayed_round: int = _host_combat.wave + 1 if _host_combat.phase == MatchCombat.Phase.PLANNING else _host_combat.wave
	if round_number != displayed_round:
		if not _host_combat.debug_set_round(round_number):
			return false
		_host_routes = [[], []]
		_host_speed_votes = [false, false]
		_host_triple_speed_votes = [false, false]
		_solo_speed = 1
		_host_autoplay_votes = [false, false]
		_host_full_autoplay_votes = [false, false]
		_enter_planning()
	_host_combat.coins[0] = money
	_host_combat.reroll_currency[0] = shards
	if singleplayer:
		_host_combat.coins[1] = money
		_host_combat.reroll_currency[1] = shards
	_update_processing()
	_publish_snapshot()
	return true


func request_edit(slot: int, cell: Vector2i, place: bool) -> void:
	_request_command("edit", slot, cell, place)


func request_clear(slot: int) -> void:
	_request_command("clear", slot, Vector2i.ZERO, false)


func submit_ready(value: bool) -> void:
	_request_command("ready", local_slot(), Vector2i.ZERO, value)


func request_pacing(option: String, enabled: bool) -> void:
	if option not in ["speed", "triple_speed", "autoplay", "full_autoplay"]:
		return
	_request_command(option, local_slot(), Vector2i.ZERO, enabled)


func cycle_singleplayer_speed() -> bool:
	if not singleplayer or not active or _host_combat.phase == MatchCombat.Phase.FINISHED:
		return false
	_solo_speed = _solo_speed % 3 + 1
	_host_speed_votes = [_solo_speed > 1, _solo_speed > 1]
	_host_triple_speed_votes = [_solo_speed > 2, _solo_speed > 2]
	_publish_snapshot()
	return true


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
func reroll_tower(slot: int, tower_id: int, kind: String, requested: Variant = 1) -> bool:
	if kind not in ["rarity", "attributes"] or not TowerRollRules.valid_reroll_batch(kind, requested):
		return false
	return _request_tower_command("reroll", slot, Vector2i.ZERO, tower_id, -1, kind, requested)


func request_commander_ability(target: int) -> bool:
	if target not in [0, 1]:
		return false
	return _request_tower_command("ability", local_slot(), Vector2i.ZERO, -1, target, "")


func request_clear_obstacle(cell: Vector2i) -> bool:
	return _request_tower_command("clear_obstacle", local_slot(), cell, -1, -1, "")




func send_enemy(slot: int, type_id: StringName) -> void:
	_request_tower_command("send", slot, Vector2i.ZERO, -1, -1, String(type_id))


func _request_tower_command(command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String, requested: Variant = 1) -> bool:
	if singleplayer:
		return _apply_tower_command(1, command, slot, cell, tower_id, mode, argument, requested)
	if session == null or session.state != MultiplayerSession.State.CONNECTED or _active_peer_id == 0:
		feedback.emit("Wait for both players to connect and synchronize their boards.")
		return false
	if session.is_host:
		return _apply_tower_command(1, command, slot, cell, tower_id, mode, argument, requested)
	_receive_tower_command.rpc_id(1, command, slot, cell, tower_id, mode, argument, requested)
	return true

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
		selecting_loadout = true
		_begin_commander_draft()
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
	_host_triple_speed_votes = [false, false]
	_solo_speed = 1
	_host_autoplay_votes = [false, false]
	_host_full_autoplay_votes = [false, false]
	_host_locked = false
	ready_flags = [false, false]
	locked_routes = [[], []]
	locked = false
	active = false
	singleplayer = false
	selecting_loadout = false
	chosen_tower_ids = []
	chosen_commander_id = &""
	commander_ids = [&"", &""]
	commander_draft = {}
	loadout_committed = false
	opponent_committed = false
	_host_loadouts = [[], []]
	_host_loadout_committed = [false, false]
	_host_owned_claims = [[], []]
	_host_commander_ids = [&"", &""]
	_host_draft_target = -1
	_host_commander_guesses = [-1, -1]
	_host_first_picker = -1
	_host_commander_picker = -1
	_host_draft_phase = "guessing"
	_commander_rng.randomize()
	_active_peer_id = 0
	_synced_guest_id = 0
	_pending_snapshot_peer = 0
	_host_combat = MatchCombat.new(combat_rules)
	_ready_seconds_left = -1.0
	_expansion_count = 0
	combat = _combat_snapshot()
	_combat_publish_elapsed = 0.0
	_accepted_revision = 0
	_accepted_sequence = 0
	_pending_combat_packet.clear()
	_pending_combat_revision = 0
	_pending_combat_sequence = 0
	_combat_in_flight = 0
	_queued_combat_frame = {}
	_combat_baseline = {}
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
	_publish_snapshot()


@rpc("any_peer", "call_remote", "reliable")
func _receive_command(command: String, slot: int, cell: Vector2i, value: bool) -> void:
	_apply_command(multiplayer.get_remote_sender_id(), command, slot, cell, value)


@rpc("any_peer", "call_remote", "reliable")
func _receive_tower_command(command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String, requested: Variant = 1) -> void:
	_apply_tower_command(multiplayer.get_remote_sender_id(), command, slot, cell, tower_id, mode, argument, requested)


func _apply_tower_command(sender: int, command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String, requested: Variant = 1) -> bool:
	if not _can_accept(sender) or not active:
		return false
	var permitted_slot: int = 0 if sender == 1 else 1
	if slot != permitted_slot:
		_reject(sender, "Only your own Coins and towers can be changed.")
		return false
	if _host_combat.phase == MatchCombat.Phase.FINISHED:
		_reject(sender, "The run has ended. Leave to start another room.")
		return false
	if not _host_can_manage_towers(slot):
		_reject(sender, "Ready commits your planning actions until combat starts.")
		return false
	if command == "clear_obstacle" and _host_combat.phase != MatchCombat.Phase.PLANNING:
		_reject(sender, "Obstacles can only be cleared during planning before Ready.")
		return false
	if command == "ability" and (_host_combat.phase != MatchCombat.Phase.WAVE or mode not in [0, 1]):
		_reject(sender, "Use your commander ability during combat on a valid board.")
		return false
	var mirrored: bool = singleplayer and sender == 1
	if singleplayer and sender != 1 and command in ["ability", "clear_obstacle"]:
		return false
	# IDs are globally unique, so resolve the counterpart by cell before a sale.
	var mirror_id: int = -1
	if mirrored and command not in ["build", "send", "reroll", "upgrade", "ability", "clear_obstacle"]:
		for tower: Dictionary in _host_combat.towers[0]:
			if tower["id"] == tower_id:
				for opponent: Dictionary in _host_combat.towers[1]:
					if opponent["cell"] == tower["cell"]:
						mirror_id = opponent["id"]
						break
				break
	var accepted: bool = false
	match command:
		"ability":
			accepted = _host_combat.activate_commander(slot, mode)
		"clear_obstacle":
			accepted = _host_combat.clear_obstacle(slot, cell)
		"send":
			accepted = _host_combat.send_enemy_mirrored(slot, StringName(argument)) if mirrored else _host_combat.send_enemy(slot, StringName(argument))
		"build":
			if not _host_loadout_committed[slot] or not _host_loadouts[slot].has(StringName(argument)):
				_reject(sender, "This tower is not in your committed run loadout.")
				return false
			var footprint: Vector2i = _host_combat.tower_footprint(StringName(argument))
			if not _build_layout_clear(slot, cell, footprint) or (mirrored and not _build_layout_clear(1 - slot, cell, footprint)):
				_reject(sender, "Build towers on empty ground, never on paths, endpoints, or terrain.")
				return false
			if mirrored:
				accepted = _host_combat.build_mirrored(slot, cell, StringName(argument), mode)
			else:
				accepted = _host_combat.build(slot, cell, StringName(argument), mode)
		"reroll":
			accepted = _host_combat.reroll_tower_mirrored(slot, tower_id, argument, requested) if mirrored else _host_combat.reroll_tower(slot, tower_id, argument, requested)
		"target":
			accepted = _host_combat.set_targeting(slot, tower_id, mode)
		"upgrade":
			accepted = _host_combat.upgrade_tower_mirrored(slot, tower_id, argument) if mirrored else _host_combat.upgrade_tower(slot, tower_id, argument)
		"sell":
			accepted = _host_combat.sell_tower(slot, tower_id)
	if not accepted:
		_reject(sender, "Action unavailable: check your tower, currency, prerequisites, and command.")
		return false
	# Paid commands atomically mirror in the model before publishing either board.
	if mirrored and command not in ["build", "reroll", "upgrade", "send", "ability", "clear_obstacle"]:
		_apply_tower_command(2, command, 1, cell, mirror_id, mode, argument)
	else:
		_publish_snapshot()
	return true


func _build_layout_clear(slot: int, cell: Vector2i, footprint: Vector2i) -> bool:
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	var layout: PathLayout = _host_layouts[slot]
	var occupied: Rect2i = TowerDefinition.footprint_rect(cell, footprint)
	for y: int in range(occupied.position.y, occupied.end.y):
		for x: int in range(occupied.position.x, occupied.end.x):
			var covered := Vector2i(x, y)
			if not layout.contains(covered) or layout.has_path(covered) or _terrain_blocks(slot, covered):
				return false
	return true


func _terrain_blocks(slot: int, cell: Vector2i) -> bool:
	var state: Dictionary = _host_combat.commanders[slot]
	return not state.is_empty() and (state["landmark"] == cell or state["obstacles"].has(cell))


func _can_accept(sender: int) -> bool:
	if singleplayer:
		return (active or selecting_loadout) and sender in [1, 2]
	if not session.is_host or session.state != MultiplayerSession.State.CONNECTED:
		return false
	var guest_id: int = _admitted_guest()
	return guest_id != 0 and guest_id == _active_peer_id and (sender == 1 or sender == guest_id)


func _apply_command(sender: int, command: String, slot: int, cell: Vector2i, value: bool) -> void:
	if not _can_accept(sender) or not active:
		return
	var permitted_slot: int = 0 if sender == 1 else 1
	if slot != permitted_slot:
		_reject(sender, "Only your own board can be changed.")
		return
	if command in ["speed", "triple_speed", "autoplay", "full_autoplay"]:
		_apply_pacing(command, permitted_slot, value)
		return
	if _host_locked:
		_reject(sender, "Paths and readiness are locked during a wave or after the run ends.")
		return
	if _host_ready[permitted_slot]:
		if command == "ready" and value:
			# A solo mirror may already be committed when the local vote arrives.
			if _try_start_wave():
				_publish_snapshot()
		else:
			_reject(sender, "Ready commits your planning actions until combat starts.")
		return
	if command in ["edit", "clear"] and not _host_can_edit_path(permitted_slot):
		_reject(sender, "Paths can only change during initial setup and main-round planning.")
		return
	if command == "clear" and not _is_main_round():
		_reject(sender, "Clear is available only during main-round planning.")
		return
	var layout: PathLayout = _host_layouts[permitted_slot]
	match command:
		"edit":
			if not layout.contains(cell) or layout.is_endpoint(cell):
				return
			if value and (_host_combat.has_tower(permitted_slot, cell) or _terrain_blocks(permitted_slot, cell)):
				_reject(sender, "A path cannot overlap an existing tower or commander terrain.")
				return
			if singleplayer and sender == 1 and value and (_host_combat.has_tower(1, cell) or _terrain_blocks(1, cell)):
				_reject(sender, "The mirrored path must avoid terrain on both boards.")
				return
			if layout.has_path(cell) == value:
				return
			if value and layout.used_tiles() >= layout.budget:
				_reject(sender, "The path tile budget is exhausted.")
				return
			var edited: bool = layout.place(cell) if value else layout.erase(cell)
			if not edited:
				return
		"clear":
			if layout.used_tiles() == 0:
				return
			layout.clear()
		"ready":
			if not value:
				return
			if not layout.is_ready():
				_reject(sender, "Connect the entrance to the base and remove all disconnected path tiles before readying.")
				return
			_host_ready[permitted_slot] = true
			if not _is_strategy_round() and _ready_seconds_left < 0.0:
				_ready_seconds_left = combat_rules.ready_window_seconds
				_combat_publish_elapsed = 0.0
				_update_processing()
		_:
			_reject(sender, "Unknown planning command.")
			return
	if singleplayer and sender == 1:
		_apply_command(2, command, 1, cell, value)
		return
	_try_start_wave()
	_publish_snapshot()


func _apply_pacing(option: String, slot: int, enabled: bool) -> void:
	if not active or _host_combat.phase not in [MatchCombat.Phase.PLANNING, MatchCombat.Phase.WAVE]:
		return
	if singleplayer and option in ["speed", "triple_speed"]:
		if option == "speed":
			_solo_speed = 2 if enabled else 1
		else:
			_solo_speed = 3 if enabled else mini(_solo_speed, 2)
		_host_speed_votes = [_solo_speed > 1, _solo_speed > 1]
		_host_triple_speed_votes = [_solo_speed > 2, _solo_speed > 2]
		_publish_snapshot()
		return
	var votes: Array[bool] = _host_autoplay_votes
	match option:
		"speed":
			votes = _host_speed_votes
		"triple_speed":
			votes = _host_triple_speed_votes
		"full_autoplay":
			votes = _host_full_autoplay_votes
	if votes[slot] == enabled:
		return
	var slots: Array[int] = [slot]
	if singleplayer:
		slots.append(1 - slot)
	for voter: int in slots:
		votes[voter] = enabled
		# Full autoplay and 3× are stronger votes; dropping the base vote drops both.
		if option == "full_autoplay" and enabled:
			_host_autoplay_votes[voter] = true
		elif option == "autoplay" and not enabled:
			_host_full_autoplay_votes[voter] = false
		elif option == "triple_speed" and enabled:
			_host_speed_votes[voter] = true
		elif option == "speed" and not enabled:
			_host_triple_speed_votes[voter] = false
	if option in ["autoplay", "full_autoplay"] and _autoplay_enabled():
		_try_start_wave()
	_publish_snapshot()


func _speed_multiplier() -> float:
	if singleplayer:
		return float(_solo_speed)
	if not (_host_speed_votes[0] and _host_speed_votes[1]):
		return 1.0
	return 3.0 if _host_triple_speed_votes[0] and _host_triple_speed_votes[1] else 2.0


func _autoplay_enabled() -> bool:
	return _host_autoplay_votes[0] and _host_autoplay_votes[1]


func _full_autoplay_enabled() -> bool:
	return _autoplay_enabled() and _host_full_autoplay_votes[0] and _host_full_autoplay_votes[1]



func _is_main_round() -> bool:
	return _host_combat.phase == MatchCombat.Phase.PLANNING and (_host_combat.wave + 1) % combat_rules.main_round_interval == 0


func _is_setup_round() -> bool:
	return _host_combat.phase == MatchCombat.Phase.PLANNING and _host_combat.wave == 0


func _is_strategy_round() -> bool:
	return _is_setup_round() or _is_main_round()


func _host_can_edit_path(slot: int) -> bool:
	return slot in [0, 1] and _is_strategy_round() and not _host_ready[slot]


func _host_can_manage_towers(slot: int) -> bool:
	return slot in [0, 1] and (_host_combat.phase == MatchCombat.Phase.WAVE or (_host_combat.phase == MatchCombat.Phase.PLANNING and not _host_ready[slot]))


func _update_processing() -> void:
	set_physics_process(_host_combat.phase == MatchCombat.Phase.WAVE or (_host_combat.phase == MatchCombat.Phase.PLANNING and _ready_seconds_left > 0.0))


func _enter_planning() -> void:
	_host_locked = false
	_host_ready = [false, false]
	_ready_seconds_left = -1.0
	_combat_publish_elapsed = 0.0
	_grow_to_round(_host_combat.wave + 1)


func _grow_to_round(round_number: int) -> void:
	var required_expansions: int = maxi(0, round_number / combat_rules.main_round_interval - 1)
	while _expansion_count < required_expansions:
		for layout: PathLayout in _host_layouts:
			layout.grow_for_main_round(combat_rules.tiles_per_expansion)
		_host_combat.grow_for_main_round()
		for route: Array in _host_routes:
			for index: int in range(route.size()):
				route[index] += Vector2i.DOWN
		_expansion_count += 1

func _try_start_wave() -> bool:
	if not active or _host_combat.phase != MatchCombat.Phase.PLANNING:
		return false
	if not (_host_ready[0] and _host_ready[1]):
		var waits_for_strategy: bool = _is_strategy_round() and not _full_autoplay_enabled()
		if waits_for_strategy or (not _autoplay_enabled() and _ready_seconds_left != 0.0):
			return false
	if not _host_layouts[0].is_ready() or not _host_layouts[1].is_ready():
		return false
	var routes: Array[Array] = [_host_layouts[0].route.duplicate(), _host_layouts[1].route.duplicate()]
	var routing: Array[Dictionary] = [_host_layouts[0].capture_routing(), _host_layouts[1].capture_routing()]
	if not _host_combat.start_wave(routing):
		return false
	_host_routes = routes
	_host_locked = true
	_ready_seconds_left = -1.0
	_combat_publish_elapsed = 0.0
	set_physics_process(true)
	return true


func _combat_snapshot(include_metadata: bool = true) -> Dictionary:
	var snapshot: Dictionary = _host_combat.snapshot(include_metadata, singleplayer)
	snapshot["speed_votes"] = _host_speed_votes.duplicate()
	snapshot["triple_speed_votes"] = _host_triple_speed_votes.duplicate()
	snapshot["autoplay_votes"] = _host_autoplay_votes.duplicate()
	snapshot["speed_multiplier"] = _speed_multiplier()
	snapshot["autoplay"] = _autoplay_enabled()
	snapshot["full_autoplay_votes"] = _host_full_autoplay_votes.duplicate()
	snapshot["full_autoplay"] = _full_autoplay_enabled()
	snapshot["main_round"] = _is_main_round()
	snapshot["setup_round"] = _is_setup_round()
	snapshot["path_editing"] = _is_strategy_round()
	snapshot["board_origin_y"] = -_expansion_count
	snapshot["ready_seconds_left"] = _ready_seconds_left
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


func _snapshot(recipient_slot: int = 0) -> Dictionary:
	var tiles: Array[Array] = [[], []]
	for slot: int in range(2):
		var layout: PathLayout = _host_layouts[slot]
		for y: int in range(layout.dimensions.y):
			for x: int in range(layout.dimensions.x):
				var cell := Vector2i(x, y)
				if not layout.is_endpoint(cell) and layout.has_path(cell):
					tiles[slot].append(cell)
	return {
		"active": active,
		"selecting_loadout": selecting_loadout,
		"chosen_tower_ids": _host_loadouts[recipient_slot].duplicate(),
		"chosen_commander_id": String(_host_commander_ids[recipient_slot]),
		"commander_ids": [String(_host_commander_ids[0]), String(_host_commander_ids[1])],
		"commander_draft": _commander_draft_snapshot(),
		"loadout_committed": _host_loadout_committed[recipient_slot],
		"opponent_committed": _host_loadout_committed[1 - recipient_slot],
		"dimensions": _host_layouts[0].dimensions,
		"budget": _host_layouts[0].budget,
		"entrance": _host_layouts[0].entrance,
		"base": _host_layouts[0].base,
		"tiles": tiles,
		"ready": _host_ready.duplicate(),
		"locked": _host_locked,
		"routes": [_host_routes[0].duplicate(), _host_routes[1].duplicate()],
		"combat": _combat_snapshot(),
	}


func _publish_snapshot() -> void:
	_snapshot_revision += 1
	_snapshot_sequence += 1
	_queued_combat_frame = {}
	var snapshot: Dictionary = _snapshot()
	_combat_baseline = snapshot["combat"]
	_mirror_snapshot(snapshot)
	if _synced_guest_id != 0 and _can_accept(_synced_guest_id):
		# Only the recipient's deck is ever encoded. Publish before changed:
		# local listeners can synchronously submit another accepted command.
		var remote: Dictionary = snapshot.duplicate()
		remote["chosen_tower_ids"] = _host_loadouts[1].duplicate()
		remote["chosen_commander_id"] = String(_host_commander_ids[1])
		remote["loadout_committed"] = _host_loadout_committed[1]
		remote["opponent_committed"] = _host_loadout_committed[0]
		_receive_snapshot.rpc_id(_synced_guest_id, SNAPSHOT_CODEC.encode_snapshot(remote), _snapshot_revision, _snapshot_sequence)
	changed.emit()


func _publish_combat() -> void:
	var frame: Dictionary = _combat_snapshot(false)
	var next: Dictionary = combat.duplicate()
	next.merge(frame, true)
	combat = next
	_snapshot_sequence += 1
	if _synced_guest_id != 0 and _can_accept(_synced_guest_id):
		_queued_combat_frame = frame
		_queued_combat_revision = _snapshot_revision
		_queued_combat_sequence = _snapshot_sequence
		_send_latest_combat()
	changed.emit()


func _send_latest_combat() -> void:
	if _combat_in_flight != 0 or _queued_combat_frame.is_empty() or _synced_guest_id == 0 or not _can_accept(_synced_guest_id):
		return
	var packet: PackedByteArray = SNAPSHOT_CODEC.encode_combat(_queued_combat_frame, _combat_baseline)
	var revision: int = _queued_combat_revision
	var sequence: int = _queued_combat_sequence
	_queued_combat_frame = {}
	_combat_in_flight = sequence
	_send_combat_packet(_synced_guest_id, packet, revision, sequence)


func _send_combat_packet(peer_id: int, packet: PackedByteArray, revision: int, sequence: int) -> void:
	_receive_combat.rpc_id(peer_id, packet, revision, sequence)


@rpc("authority", "call_remote", "reliable", 1)
func _receive_combat(packet: PackedByteArray, revision: int, sequence: int) -> void:
	if session.is_host or session.state != MultiplayerSession.State.CONNECTED or multiplayer.get_remote_sender_id() != 1:
		return
	_queue_combat_frame(packet, revision, sequence)


@rpc("any_peer", "call_remote", "reliable", 1)
func _acknowledge_combat(sequence: int) -> void:
	if session.is_host and multiplayer.get_remote_sender_id() == _synced_guest_id and sequence == _combat_in_flight:
		_combat_in_flight = 0
		_send_latest_combat()


func _ack_combat_frame(sequence: int) -> void:
	if sequence > 0 and session != null and not session.is_host and session.state == MultiplayerSession.State.CONNECTED:
		_acknowledge_combat.rpc_id(1, sequence)


func _queue_combat_frame(packet: PackedByteArray, revision: int, sequence: int) -> void:
	if revision < _accepted_revision or sequence <= _accepted_sequence or sequence <= _pending_combat_sequence:
		_ack_combat_frame(sequence)
		return
	_pending_combat_packet = packet
	_pending_combat_revision = revision
	_pending_combat_sequence = sequence
	_schedule_combat_flush()


func _schedule_combat_flush() -> void:
	if not _combat_flush_queued and not _pending_combat_packet.is_empty():
		_combat_flush_queued = true
		_flush_combat_frame.call_deferred()


func _flush_combat_frame() -> void:
	_combat_flush_queued = false
	# A frame can outrun its reliable baseline on the independent channel.
	# Keep only the newest one until that baseline has actually arrived.
	if _pending_combat_packet.is_empty() or _pending_combat_revision != _accepted_revision:
		return
	var frame: Dictionary = SNAPSHOT_CODEC.decode_combat(_pending_combat_packet, _combat_baseline)
	_accepted_sequence = _pending_combat_sequence
	_pending_combat_packet.clear()
	_pending_combat_sequence = 0
	_ack_combat_frame(_accepted_sequence)
	if frame.is_empty():
		return
	var next: Dictionary = combat.duplicate()
	next.merge(frame, true)
	combat = next
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(packet: PackedByteArray, revision: int, sequence: int) -> void:
	if session.is_host or session.state != MultiplayerSession.State.CONNECTED or multiplayer.get_remote_sender_id() != 1:
		return
	_accept_snapshot_frame(packet, revision, sequence)


func _accept_snapshot_frame(packet: PackedByteArray, revision: int, sequence: int) -> void:
	if revision < _accepted_revision or sequence <= _accepted_sequence:
		return
	var snapshot: Dictionary = SNAPSHOT_CODEC.decode_snapshot(packet)
	if snapshot.is_empty():
		return
	_accepted_revision = revision
	_accepted_sequence = sequence
	_active_peer_id = 1
	if _pending_combat_revision < revision or _pending_combat_sequence <= sequence:
		_ack_combat_frame(_pending_combat_sequence)
		_pending_combat_packet.clear()
		_pending_combat_sequence = 0
	_combat_baseline = snapshot["combat"]
	_mirror_snapshot(snapshot)
	changed.emit()
	_schedule_combat_flush()


func _mirror_snapshot(snapshot: Dictionary) -> void:
	active = snapshot["active"]
	selecting_loadout = snapshot["selecting_loadout"]
	chosen_tower_ids.assign(snapshot["chosen_tower_ids"])
	chosen_commander_id = StringName(snapshot["chosen_commander_id"])
	commander_draft = snapshot["commander_draft"]
	var accepted_ids: Array = snapshot["commander_ids"]
	commander_ids = [StringName(accepted_ids[0]), StringName(accepted_ids[1])]
	loadout_committed = snapshot["loadout_committed"]
	opponent_committed = snapshot["opponent_committed"]
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
