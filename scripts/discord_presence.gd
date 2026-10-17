class_name DiscordPresence
extends Node
## Local presentation only: never exposes room credentials or private decks.

const UPDATE_INTERVAL: float = 15.0

var planning: MatchPlanning
var session: MultiplayerSession
var screen: String = "Main menu"

var _rpc: Object
var _started_at: int = 0
var _until_update: float = 0.0
var _last_activity: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = int(Time.get_unix_time_from_system())
	var application_id: int = int(ProjectSettings.get_setting("discord/application_id", 0))
	if application_id <= 0 or not Engine.has_singleton("DiscordRPC"):
		set_process(false)
		return
	_rpc = Engine.get_singleton("DiscordRPC")
	_rpc.set("app_id", application_id)
	# The SDK uses NoRequireDiscord: a missing client must not block play.
	if not _rpc.call("get_is_discord_working"):
		_rpc = null
		set_process(false)


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
	_rpc.set("start_timestamp", _started_at)
	_rpc.call("refresh")
	_last_activity = current


func activity() -> Dictionary:
	if screen != "Play" or planning == null or session == null:
		return {"details": screen, "state": ""}
	var mode: String = "Singleplayer" if planning.singleplayer else "Multiplayer"
	if planning.selecting_loadout:
		return {"details": mode, "state": "Choosing a loadout"}
	if planning.active:
		var phase: int = int(planning.combat.get("phase", MatchCombat.Phase.PLANNING))
		var round_number: int = int(planning.combat.get("wave", 0))
		var phase_name: String = "Planning"
		if phase == MatchCombat.Phase.PLANNING:
			round_number += 1
		elif phase == MatchCombat.Phase.WAVE:
			phase_name = "Defending"
		elif phase == MatchCombat.Phase.FINISHED:
			phase_name = "Match finished"
		return {"details": mode, "state": "Round %d - %s" % [round_number, phase_name]}
	if session.state == MultiplayerSession.State.HOSTING:
		return {"details": "Multiplayer", "state": "Waiting for a friend"}
	if session.state == MultiplayerSession.State.CONNECTING:
		return {"details": "Multiplayer", "state": "Connecting"}
	return {"details": "Play", "state": ""}


func _exit_tree() -> void:
	if _rpc != null and _rpc.call("get_is_discord_working"):
		_rpc.call("clear", true)
