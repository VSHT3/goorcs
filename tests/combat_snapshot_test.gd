extends SceneTree

const CODEC = preload("res://scripts/combat_snapshot_codec.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := MatchPlanning.new()
	authority.configure(Vector2i(14, 9), 30, Vector2i(0, 4), Vector2i(13, 4))
	authority.active = true
	for layout: PathLayout in authority._host_layouts:
		for x: int in range(1, 13):
			layout.place(Vector2i(x, 4))
	var core: MatchCombat = authority._host_combat
	core.coins = [10000, 10000]
	_check(core.build(0, Vector2i(2, 3), &"arrow_tower", 0), "Build actual snapshot tower")
	_check(core.start_wave([authority._host_layouts[0].capture_routing(), authority._host_layouts[1].capture_routing()]), "Capture actual shortest routes")
	var route: Array[Vector2i] = []
	route.assign(authority._host_layouts[0].route)
	for index: int in range(64):
		core._spawn_enemy(index % 2, "grunt", index * 0.1, 0.0, route)
	core.advance(0.05)
	var first: Dictionary = authority._snapshot(1)
	var full_packet: PackedByteArray = CODEC.encode_snapshot(first)
	var decoded: Dictionary = CODEC.decode_snapshot(full_packet)
	_check(decoded == first, "Full snapshot preserves accepted routes, branches, towers, enemies and metadata")
	_check(core.enemies[0][0]["route"] is Array, "Encoding never replaces an authoritative captured route")
	decoded["combat"]["enemies"][0][0]["hp"] = -99
	_check(first["combat"]["enemies"][0][0]["hp"] != -99 and core.enemies[0][0]["hp"] != -99, "Decoded peer state is detached from authority and source snapshot")

	var guest := MatchPlanning.new()
	guest._accept_snapshot_frame(full_packet, 1, 1)
	var changes: Array[int] = [0]
	guest.changed.connect(func() -> void: changes[0] += 1)
	core.advance(0.05)
	core.towers[0][0]["aim"] = Vector2(11, 4)
	var second: Dictionary = authority._combat_snapshot(false)
	core.advance(0.05)
	core.towers[0][0]["aim"] = first["combat"]["towers"][0][0]["aim"]
	var third: Dictionary = authority._combat_snapshot(false)
	var second_packet: PackedByteArray = CODEC.encode_combat(second, first["combat"])
	var third_packet: PackedByteArray = CODEC.encode_combat(third, first["combat"])
	_check(CODEC.decode_combat(third_packet, first["combat"]) == third, "A delta frame decodes against its reliable baseline without receiving any previous combat frame")
	guest._queue_combat_frame(third_packet, 1, 4)
	guest._queue_combat_frame(second_packet, 1, 2)
	guest._queue_combat_frame(third_packet, 1, 4)
	await process_frame
	await process_frame
	_check(changes[0] == 1 and guest.combat["death_time"] == third["death_time"], "Lost, reordered and duplicate frames coalesce to one newest-state presentation")
	_check(guest.combat == authority._combat_snapshot(), "Compact combat frame retains reliable metadata and exact current accepted state")
	guest._accept_snapshot_frame(full_packet, 1, 1)
	_check(guest.combat["death_time"] == third["death_time"], "Late reliable snapshot cannot rewind a newer accepted combat frame")

	core.coins[0] -= 100
	var transaction: Dictionary = authority._snapshot(1)
	core.advance(0.05)
	var future: Dictionary = authority._combat_snapshot(false)
	guest._queue_combat_frame(CODEC.encode_combat(future), 2, 7)
	await process_frame
	_check(guest.combat["coins"][0] != future["coins"][0], "Future combat waits for its reliable transaction/layout baseline")
	guest._accept_snapshot_frame(CODEC.encode_snapshot(transaction), 2, 6)
	await process_frame
	await process_frame
	_check(guest.combat == authority._combat_snapshot(), "Newest buffered frame applies after its baseline arrives")
	guest._queue_combat_frame(third_packet, 1, 8)
	await process_frame
	_check(guest.combat["coins"] == future["coins"], "An old revision cannot resurrect pre-transaction balances even with a newer sequence")

	core.phase = MatchCombat.Phase.FINISHED
	core.winner = 0
	var terminal: Dictionary = authority._snapshot(1)
	guest._accept_snapshot_frame(CODEC.encode_snapshot(terminal), 3, 10)
	guest._queue_combat_frame(CODEC.encode_combat(future), 2, 11)
	await process_frame
	_check(guest.combat["phase"] == MatchCombat.Phase.FINISHED and guest.combat["winner"] == 0, "Reliable results cannot be overwritten by an in-flight combat frame")
	guest.free()
	authority.free()
	if failures == 0:
		print("PASS: compact snapshot fidelity, dropped/reordered frames, latest-only presentation, baseline fencing and terminal-state protection")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
