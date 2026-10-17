class_name DiscordPresence
extends Node
## Local presentation only: never exposes room credentials or private decks.

const UPDATE_INTERVAL: float = 15.0

var planning: MatchPlanning
var session: MultiplayerSession
var settings: Node
var screen: String = "Main menu"

var _rpc: Object
var _run_id: String = ""
var _run_started_at: int = 0
# Cosmetic only; never derived from or accepted as a room credential.
var _party_id: String = "gorcs-" + Crypto.new().generate_random_bytes(16).hex_encode()
var _until_update: float = 0.0
var _last_activity: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if planning != null:
		planning.changed.connect(_sync_run_clock)
	_sync_run_clock()
	if settings == null:
		settings = get_node("/root/DiscordSettings")
	settings.changed.connect(_preference_changed)
	_preference_changed()


func _preference_changed() -> void:
	if not settings.enabled:
		_stop_sdk()
		return
	if _rpc != null:
		return
	set_process(false)
	var application_id: int = int(ProjectSettings.get_setting("discord/application_id", 0))
	if application_id <= 0 or not Engine.has_singleton("DiscordRPC"):
		return
	_rpc = Engine.get_singleton("DiscordRPC")
	_rpc.set("app_id", application_id)
	# The SDK uses NoRequireDiscord: a missing client must not block play.
	if not _rpc.call("get_is_discord_working"):
		_rpc = null
		return
	_until_update = 0.0
	set_process(true)


func _sync_run_clock() -> void:
	if planning == null or not planning.active:
		_run_id = ""
		_run_started_at = 0
		return
	var accepted_id: String = str(planning.combat.get("statistics_id", ""))
	if accepted_id != _run_id:
		_run_id = accepted_id
		_run_started_at = int(Time.get_unix_time_from_system()) if not accepted_id.is_empty() else 0


func _process(delta: float) -> void:
	_rpc.call("run_callbacks")
	_until_update -= delta
	if _until_update > 0.0:
		return
	_until_update = UPDATE_INTERVAL
	var current: Dictionary = activity()
	if current == _last_activity or not _rpc.call("get_is_discord_working"):
		return
	_rpc.set("details", current["details"])
	_rpc.set("state", current["state"])
	_rpc.set("large_image", str(ProjectSettings.get_setting("discord/large_image", "gorcs")))
	_rpc.set("large_image_text", "Gorcs")
	_rpc.set("start_timestamp", current["start_timestamp"])
	_rpc.set("party_id", current["party_id"])
	_rpc.set("current_party_size", current["current_party_size"])
	_rpc.set("max_party_size", current["max_party_size"])
	_rpc.call("refresh")
	_last_activity = current


func activity() -> Dictionary:
	var result: Dictionary = {
		"details": screen, "state": "", "start_timestamp": 0,
		"party_id": "", "current_party_size": 0, "max_party_size": 0,
	}
	if screen != "Play" or planning == null or session == null:
		return result
	if not planning.singleplayer:
		var count: int = session.player_count()
		if count > 0:
			result["party_id"] = _party_id
			result["current_party_size"] = count
			result["max_party_size"] = 2
	var mode: String = "Singleplayer" if planning.singleplayer else "Multiplayer"
	if planning.selecting_loadout:
		result["details"] = mode
		result["state"] = "Choosing a loadout"
	elif planning.active:
		var phase: int = int(planning.combat.get("phase", MatchCombat.Phase.PLANNING))
		var round_number: int = int(planning.combat.get("wave", 0))
		var phase_name: String = "Planning"
		if phase == MatchCombat.Phase.PLANNING:
			round_number += 1
		elif phase == MatchCombat.Phase.WAVE:
			phase_name = "Defending"
		elif phase == MatchCombat.Phase.FINISHED:
			phase_name = "Match finished"
		result["details"] = mode
		result["state"] = "Round %d - %s" % [round_number, phase_name]
		result["start_timestamp"] = _run_started_at
	elif session.state == MultiplayerSession.State.HOSTING:
		result["details"] = "Multiplayer"
		result["state"] = "Waiting for a friend"
	elif session.state == MultiplayerSession.State.CONNECTING:
		result["details"] = "Multiplayer"
		result["state"] = "Connecting"
	return result


func _stop_sdk() -> void:
	set_process(false)
	if _rpc != null and _rpc.call("get_is_discord_working"):
		_rpc.call("clear", true)
	_rpc = null
	_last_activity.clear()
	_until_update = 0.0


func _exit_tree() -> void:
	_stop_sdk()
