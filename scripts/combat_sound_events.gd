class_name CombatSoundEvents
extends RefCounted
## Host-owned cosmetic facts. Dropping/coalescing cues never changes combat.

enum Cue { BOW, BALLISTA, RUNE, EXPLOSION, HIT, DEATH, BONES, PORTAL, CRYSTAL, PURCHASE, UPGRADE, SEND, REJECT, TROLL_STOMP, CLUB_IMPACT, CANNON, TOWER_STUN, MACHINE_GEAR, MACHINE_JUMP, MACHINE_DOOR }

const CAPACITY: int = 128
const LIFETIME: float = 1.2
const COMBAT_SPACING: float = 0.04

var generation: int = 0
var last_id: int = 0
var _events: Array[Dictionary] = []
var _head: int = 0
var _count: int = 0
var _last_times: PackedFloat64Array = []


static func is_ui_cue(cue: int) -> bool:
	return cue in [Cue.PURCHASE, Cue.UPGRADE, Cue.SEND, Cue.REJECT]


func _init() -> void:
	_events.resize(CAPACITY)
	_last_times.resize(Cue.size() * 2)
	_last_times.fill(-INF)


func record(cue: int, slot: int, position: Vector2, time: float) -> void:
	var key: int = slot * Cue.size() + cue
	# A horde/AoE contributes one representative contact per short sim interval.
	# Purchase acknowledgements remain separate and are locally voice-limited.
	if not is_ui_cue(cue) and time - _last_times[key] < COMBAT_SPACING:
		return
	_last_times[key] = time
	last_id += 1
	_events[_head] = {"id": last_id, "cue": cue, "slot": slot, "pos": position, "time": time}
	_head = (_head + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)


func reset() -> void:
	if _count > 0:
		generation += 1
	_last_times.fill(-INF)
	for offset: int in range(_count):
		_events[(_head - _count + offset + CAPACITY) % CAPACITY] = {}
	_count = 0
	_head = 0


func snapshot(time: float) -> Dictionary:
	var recent: Array[Dictionary] = []
	for offset: int in range(_count):
		var event: Dictionary = _events[(_head - _count + offset + CAPACITY) % CAPACITY]
		if time - float(event["time"]) < LIFETIME:
			recent.append(event.duplicate())
	return {"generation": generation, "last_id": last_id, "time": time, "events": recent}
