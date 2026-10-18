class_name GameSoundPlayer
extends Node
## Local snapshot consumer: no gameplay timers, RPCs, or speculative success cues.

const Cues = CombatSoundEvents.Cue
const WORLD_VOICES: int = 10
const UI_VOICES: int = 3
const MAX_STARTS_PER_FRAME: int = 4
const STREAMS: Array = [
	[preload("res://assets/audio/sfx/bow_01.wav"), preload("res://assets/audio/sfx/bow_02.wav"), preload("res://assets/audio/sfx/bow_03.wav")],
	[preload("res://assets/audio/sfx/ballista_01.wav"), preload("res://assets/audio/sfx/ballista_02.wav"), preload("res://assets/audio/sfx/ballista_03.wav")],
	[preload("res://assets/audio/sfx/rune_01.wav"), preload("res://assets/audio/sfx/rune_02.wav")],
	[preload("res://assets/audio/sfx/explosion_01.wav"), preload("res://assets/audio/sfx/explosion_02.wav")],
	[preload("res://assets/audio/sfx/hit_01.wav"), preload("res://assets/audio/sfx/hit_02.wav"), preload("res://assets/audio/sfx/hit_03.wav")],
	[preload("res://assets/audio/sfx/death_01.wav"), preload("res://assets/audio/sfx/death_02.wav"), preload("res://assets/audio/sfx/death_03.wav")],
	[preload("res://assets/audio/sfx/bone_death_01.wav"), preload("res://assets/audio/sfx/bone_death_02.wav")],
	[preload("res://assets/audio/sfx/portal_01.wav"), preload("res://assets/audio/sfx/portal_02.wav")],
	[preload("res://assets/audio/sfx/crystal_01.wav"), preload("res://assets/audio/sfx/crystal_02.wav")],
	[preload("res://assets/audio/sfx/purchase_01.wav")],
	[preload("res://assets/audio/sfx/upgrade_01.wav")],
	[preload("res://assets/audio/sfx/portal_01.wav"), preload("res://assets/audio/sfx/portal_02.wav")],
	[preload("res://assets/audio/sfx/reject_01.wav")],
	[preload("res://assets/audio/sfx/troll_stomp_01.wav"), preload("res://assets/audio/sfx/troll_stomp_02.wav")],
	[preload("res://assets/audio/sfx/club_impact_01.wav"), preload("res://assets/audio/sfx/club_impact_02.wav")],
	[preload("res://assets/audio/sfx/cannon_01.wav"), preload("res://assets/audio/sfx/cannon_02.wav")],
	[preload("res://assets/audio/sfx/tower_stun_01.wav"), preload("res://assets/audio/sfx/tower_stun_02.wav")],
	[preload("res://assets/audio/sfx/machine_gear_01.wav"), preload("res://assets/audio/sfx/machine_gear_02.wav")],
	[preload("res://assets/audio/sfx/machine_jump_01.wav"), preload("res://assets/audio/sfx/machine_jump_02.wav")],
	[preload("res://assets/audio/sfx/machine_door_01.wav"), preload("res://assets/audio/sfx/machine_door_02.wav")],
	[preload("res://assets/audio/sfx/sale_01.wav")],
]
const GAINS_DB: Array[float] = [-7.0, -5.0, -8.0, -7.0, -11.0, -9.0, -9.0, -8.0, -4.0, -3.0, -3.0, -8.0, -4.0, -4.0, -4.0, -4.0, -7.0, -7.0, -5.0, -6.0, -3.0]
const GAPS_MSEC: Array[int] = [75, 100, 150, 140, 110, 170, 170, 220, 180, 65, 100, 160, 180, 260, 180, 200, 160, 300, 250, 220, 65]
const PRIORITY: Array[int] = [30, 35, 40, 60, 10, 45, 45, 25, 100, 100, 100, 100, 100, 65, 75, 80, 75, 50, 70, 60, 100]

var world: MatchWorld
var _world_players: Array[AudioStreamPlayer2D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _voice_priority: Array[int] = []
var _next_allowed: PackedInt64Array = []
var _candidates: Array[Dictionary] = []
var _run_id: String = ""
var _generation: int = -1
var _last_id: int = 0
var _active: bool = false
var _paused: bool = false
var _frame: int = -1
var _starts: int = 0
var _ui_cursor: int = 0
var _reject_serial: int = 0
var _pending_explosion: Dictionary = {}


func _ready() -> void:
	_next_allowed.resize(STREAMS.size())
	_candidates.resize(STREAMS.size())
	set_process(false)
	for index: int in range(WORLD_VOICES):
		var player := AudioStreamPlayer2D.new()
		player.bus = &"Sound"
		player.max_distance = 100000.0
		player.attenuation = 0.0
		player.panning_strength = 0.7
		add_child(player)
		_world_players.append(player)
		_voice_priority.append(0)
	for index: int in range(UI_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = &"Sound"
		add_child(player)
		_ui_players.append(player)


func observe(state: Dictionary, own_slot: int, active: bool, combat_paused: bool = false) -> void:
	if not active:
		deactivate()
		return
	var sound: Dictionary = state.get("sounds", {})
	var run_id: String = state.get("statistics_id", "")
	var generation: int = int(sound.get("generation", 0))
	var latest: int = int(sound.get("last_id", 0))
	if not _active or run_id != _run_id or generation != _generation:
		stop_all()
		_active = true
		_run_id = run_id
		_generation = generation
		_last_id = latest
		_paused = combat_paused
		return # Admission/reopen/reset is a baseline, never an old-audio replay.
	set_combat_paused(combat_paused)
	var events: Array = sound.get("events", [])
	var now: int = Time.get_ticks_msec()
	var speed: float = maxf(1.0, float(state.get("speed_multiplier", 1.0)))
	var clock: float = float(sound.get("time", 0.0))
	for index: int in range(_candidates.size()):
		_candidates[index] = {}
	for event: Dictionary in events:
		var id: int = int(event["id"])
		if id <= _last_id:
			continue
		var cue: int = int(event["cue"])
		var slot: int = int(event["slot"])
		if cue < 0 or cue >= STREAMS.size() or slot not in [0, 1]:
			continue
		var ui: bool = CombatSoundEvents.is_ui_cue(cue)
		if ui and slot != own_slot:
			continue # Includes the solo mirror: one confirmation per local action.
		if not ui and (_paused or (clock - float(event["time"])) / speed > 0.35):
			continue
		var point: Vector2 = _screen_position(slot, event["pos"]) if not ui else Vector2.ZERO
		var gain: float = spatial_gain(point) if not ui else 1.0
		if cue == Cues.CRYSTAL and slot == own_slot:
			gain = maxf(0.65, gain) # Your base alarm remains useful while scouting.
		if gain <= 0.01:
			continue
		var previous: Dictionary = _candidates[cue]
		if previous.is_empty() or gain > float(previous["gain"]):
			_candidates[cue] = {"id": id, "gain": gain, "point": point}
	_last_id = maxi(_last_id, latest)
	# Prioritize urgent feedback before disposable contacts; no audio backlog.
	for cue: int in [Cues.CRYSTAL, Cues.SALE, Cues.PURCHASE, Cues.UPGRADE, Cues.SEND, Cues.CANNON, Cues.CLUB_IMPACT, Cues.TOWER_STUN, Cues.MACHINE_JUMP, Cues.TROLL_STOMP, Cues.MACHINE_DOOR, Cues.MACHINE_GEAR, Cues.EXPLOSION, Cues.DEATH, Cues.BONES, Cues.RUNE, Cues.BALLISTA, Cues.BOW, Cues.PORTAL, Cues.HIT]:
		var candidate: Dictionary = _candidates[cue]
		if candidate.is_empty():
			continue
		if cue == Cues.EXPLOSION:
			if _pending_explosion.is_empty() and now >= _next_allowed[cue]:
				candidate["due"] = now + roundi(1000.0 * PathBoard.SHOT_DURATION / speed)
				_pending_explosion = candidate
				set_process(true)
		else:
			_play(cue, candidate["id"], candidate["gain"], candidate["point"], now)

func _process(_delta: float) -> void:
	if _pending_explosion.is_empty():
		set_process(false)
		return
	var now: int = Time.get_ticks_msec()
	if now >= int(_pending_explosion["due"]):
		_play(Cues.EXPLOSION, _pending_explosion["id"], _pending_explosion["gain"], _pending_explosion["point"], now)
		_pending_explosion = {}
		set_process(false)



func spatial_gain(point: Vector2) -> float:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var center: Vector2 = rect.get_center()
	var normalized: Vector2 = (point - center) / (rect.size * 0.5)
	# Visible edge is softer; offscreen combat fades to silence within half a screen.
	var distance: float = normalized.length()
	return pow(clampf((1.8 - distance) / 1.2, 0.0, 1.0), 2.0)


func _screen_position(slot: int, position: Vector2) -> Vector2:
	if world == null:
		return get_viewport().get_visible_rect().get_center()
	var board: PathBoard = world.boards[slot]
	var viewport_point: Vector2 = board.get_global_transform_with_canvas() * board._position_center(position)
	var local_point: Vector2 = viewport_point * world.size / Vector2(world._world_viewport.size)
	return world.get_global_transform_with_canvas() * local_point


func reject() -> void:
	if _active and not get_tree().paused:
		_reject_serial += 1
		_play(Cues.REJECT, _reject_serial, 1.0, Vector2.ZERO, Time.get_ticks_msec())


func set_combat_paused(value: bool) -> void:
	if value and not _paused:
		_pending_explosion = {}
		set_process(false)
		for player: AudioStreamPlayer2D in _world_players:
			player.stop()
	_paused = value


func deactivate() -> void:
	stop_all()
	_active = false
	_run_id = ""
	_generation = -1
	_last_id = 0
	_paused = false


func stop_all() -> void:
	for player: AudioStreamPlayer2D in _world_players:
		player.stop()
	for player: AudioStreamPlayer in _ui_players:
		player.stop()
	_next_allowed.fill(0)
	_pending_explosion = {}
	set_process(false)

func _exit_tree() -> void:
	stop_all()



func _play(cue: int, id: int, gain: float, point: Vector2, now: int) -> void:
	var bus: int = AudioServer.get_bus_index(&"Sound")
	if bus < 0 or AudioServer.is_bus_mute(bus) or now < _next_allowed[cue]:
		return
	var ui: bool = CombatSoundEvents.is_ui_cue(cue)
	var stream: AudioStream = STREAMS[cue][posmod(id * 7 + cue, STREAMS[cue].size())]
	# Cosmetic variation is deterministic and never consumes combat RNG.
	var pitch: float = 1.0 + (posmod(id * 13 + cue, 7) - 3) * 0.008
	if ui:
		var player: AudioStreamPlayer = _ui_players[_ui_cursor]
		_ui_cursor = (_ui_cursor + 1) % UI_VOICES
		player.stream = stream
		player.volume_db = GAINS_DB[cue]
		player.pitch_scale = pitch
		player.play()
	else:
		var frame: int = Engine.get_process_frames()
		if frame != _frame:
			_frame = frame
			_starts = 0
		if _starts >= MAX_STARTS_PER_FRAME:
			return
		var selected: int = -1
		for index: int in range(_world_players.size()):
			if not _world_players[index].playing:
				selected = index
				break
			if _voice_priority[index] < PRIORITY[cue] and (selected < 0 or _voice_priority[index] < _voice_priority[selected]):
				selected = index
		if selected < 0:
			return
		var player: AudioStreamPlayer2D = _world_players[selected]
		player.stream = stream
		player.global_position = point.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
		player.volume_db = GAINS_DB[cue] + linear_to_db(gain)
		player.pitch_scale = pitch
		_voice_priority[selected] = PRIORITY[cue]
		player.play()
		_starts += 1
	_next_allowed[cue] = now + GAPS_MSEC[cue]
