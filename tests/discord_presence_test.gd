extends SceneTree

var failures: int = 0


func _init() -> void:
	var planning := MatchPlanning.new()
	var session := MultiplayerSession.new()
	var presence := DiscordPresence.new()
	presence.planning = planning
	presence.session = session
	presence.screen = "Play"
	planning.active = true
	planning.combat = {"phase": MatchCombat.Phase.PLANNING, "wave": 0}
	_check(_round(presence) == 1, "Initial planning must show the upcoming first round, not round zero")
	planning.combat = {"phase": MatchCombat.Phase.PLANNING, "wave": 9}
	_check(_round(presence) == 10, "Planning must show the upcoming round")
	var before_wave: Dictionary = presence.activity()
	planning.combat = {"phase": MatchCombat.Phase.WAVE, "wave": 10}
	_check(_round(presence) == 10, "Combat must show the active round")
	_check(before_wave != presence.activity(), "Planning and combat must have distinct presence")
	var during_wave: Dictionary = presence.activity()
	planning.combat["phase"] = MatchCombat.Phase.FINISHED
	_check(_round(presence) == 10, "Results must not advance to an unplayed round")
	_check(during_wave != presence.activity(), "Terminal results must not retain defending presence")
	var public_activity: Dictionary = presence.activity()
	session.invite_code = "PRIVATE_ADDRESS_PORT_CREDENTIAL"
	planning.chosen_tower_ids = [&"PRIVATE_DECK"]
	planning.combat["coins"] = [98132, 71823]
	planning.combat["private_data"] = "PRIVATE_SNAPSHOT"
	_check(presence.activity() == public_activity, "Private session, deck and economy changes must never alter presence")
	var captured: Dictionary = planning.combat.duplicate(true)
	planning.singleplayer = true
	_check(presence.activity() != public_activity, "Solo and multiplayer must be distinguishable")
	presence.screen = "Main menu"
	var menu_activity: Dictionary = presence.activity()
	planning.combat["wave"] = 99
	planning.selecting_loadout = true
	_check(presence.activity() == menu_activity, "A hidden match must not override the visible menu")
	presence.screen = "Play"
	var loadout_activity: Dictionary = presence.activity()
	planning.combat["wave"] = 100
	_check(presence.activity() == loadout_activity, "Loadout selection must not publish stale match rounds")
	planning.combat = captured.duplicate(true)
	planning.selecting_loadout = false
	presence.activity()
	_check(planning.combat == captured, "Presence must not mutate accepted gameplay state")
	presence.free()
	planning.free()
	session.free()
	if failures == 0:
		print("PASS: Discord presence round boundaries, phase/mode transitions, visible-screen priority, private-data exclusion and gameplay nonmutation")
	quit(1 if failures > 0 else 0)


func _round(presence: DiscordPresence) -> int:
	var expression := RegEx.new()
	expression.compile("[0-9]+")
	var result: RegExMatch = expression.search(str(presence.activity()["state"]))
	return -1 if result == null else int(result.get_string())


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
