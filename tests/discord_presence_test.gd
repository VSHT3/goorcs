extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	_test_party_boundaries(presence, planning, session)
	presence.free()
	planning.free()
	session.free()
	await _test_match_clock()
	if failures == 0:
		print("PASS: Discord presence round/phase boundaries, private non-joinable party metadata, per-run clock stability/reset, visible-screen priority and gameplay nonmutation")
	quit(1 if failures > 0 else 0)


func _test_party_boundaries(presence: DiscordPresence, planning: MatchPlanning, session: MultiplayerSession) -> void:
	planning.active = false
	planning.selecting_loadout = false
	planning.singleplayer = false
	session.state = MultiplayerSession.State.HOSTING
	session.is_host = true
	session.invite_code = "PRIVATE_ROOM_CREDENTIAL"
	var hosting: Dictionary = presence.activity()
	_check(hosting["current_party_size"] == 1 and hosting["max_party_size"] == 2, "Waiting host exposes one occupied slot out of two")
	_check(not str(hosting).contains(session.invite_code), "Party identity cannot reveal the room credential")
	for secret: String in ["join_secret", "match_secret", "spectate_secret"]:
		_check(not hosting.has(secret), "Cosmetic party counts cannot enable Discord admission")
	session.invite_code = "REPLACEMENT_PRIVATE_CREDENTIAL"
	_check(presence.activity() == hosting, "Rotating room credentials cannot alter the public party identity")
	session.state = MultiplayerSession.State.CONNECTED
	var connected: Dictionary = presence.activity()
	_check(connected["current_party_size"] == 2 and connected["party_id"] == hosting["party_id"], "Admission fills the same cosmetic party rather than creating another")
	planning.singleplayer = true
	_check(_has_no_party(presence.activity()), "Solo removes all stale multiplayer party metadata")
	planning.singleplayer = false
	presence.screen = "Main menu"
	_check(_has_no_party(presence.activity()), "A visible menu cannot retain a hidden room's party")
	presence.screen = "Play"
	session.state = MultiplayerSession.State.CONNECTING
	_check(_has_no_party(presence.activity()), "Unadmitted connection attempts cannot claim an occupied party")
	session.state = MultiplayerSession.State.ERROR
	_check(_has_no_party(presence.activity()), "Connection failure removes all party metadata")


func _has_no_party(activity: Dictionary) -> bool:
	return activity["party_id"] == "" and activity["current_party_size"] == 0 and activity["max_party_size"] == 0


func _test_match_clock() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	root.add_child(planning)
	var preferences: Node = load("res://scripts/discord_settings.gd").new()
	preferences.set_enabled(false)
	var presence := DiscordPresence.new()
	presence.session = session
	presence.planning = planning
	presence.settings = preferences
	presence.screen = "Play"
	root.add_child(presence)
	_check(presence.activity()["start_timestamp"] == 0, "Menus and unstarted matches have no match timer")
	planning.start_singleplayer()
	_check(presence.activity()["start_timestamp"] == 0, "Loadout selection does not start the run clock")
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Clock fixture admits an actual solo match")
	var started_at: int = presence.activity()["start_timestamp"]
	_check(started_at > 0, "The run clock starts when board planning is admitted, even with sharing disabled")
	# Cross a Unix-second boundary so a clock incorrectly reset on every snapshot fails.
	# Wait on the wall clock itself: a timer's first frame delta also counts time
	# spent earlier in that frame, so a 1.1 s timer can finish in under a second.
	while int(Time.get_unix_time_from_system()) <= started_at:
		await create_timer(0.05).timeout
	_check(planning.debug_set_values(10, 200, 8), "Clock fixture changes round through the real owner")
	_check(presence.activity()["start_timestamp"] == started_at, "Round changes cannot reset elapsed match time")
	preferences.set_enabled(true)
	_check(presence.activity()["start_timestamp"] == started_at, "Re-enabling sharing during a run retains its original start")
	planning.combat["phase"] = MatchCombat.Phase.FINISHED
	planning.changed.emit()
	_check(presence.activity()["start_timestamp"] == started_at, "Results retain the completed run's start")
	planning.stop_singleplayer()
	_check(presence.activity()["start_timestamp"] == 0, "Leaving removes the old run timer")
	planning.start_singleplayer()
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "A second run is admitted through normal loadout selection")
	_check(presence.activity()["start_timestamp"] > started_at, "A new run cannot reuse the previous run's elapsed timer")
	presence.free()
	preferences.free()
	planning.free()
	session.free()


func _round(presence: DiscordPresence) -> int:
	var expression := RegEx.new()
	expression.compile("[0-9]+")
	var result: RegExMatch = expression.search(str(presence.activity()["state"]))
	return -1 if result == null else int(result.get_string())


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
