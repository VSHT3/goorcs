extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _run() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	var rules := CombatRules.new()
	rules.enemy_speed = 0.1
	rules.speed_growth_fraction = 0.0
	rules.base_health = 1000
	rules.spawn_interval = 0.0
	planning.combat_rules = rules
	root.add_child(planning)
	planning.start_singleplayer()
	check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(),"Solo speed fixture commits its loadout")
	for expected: int in [2,3,1,2,3]:
		check(planning.cycle_singleplayer_speed() and planning.combat["speed_multiplier"]==float(expected),"Solo cycles through all three accepted speeds")
	planning.debug_set_values(1,999,int(planning.combat["reroll_currency"][0]))
	check(planning.combat["speed_multiplier"]==3.0,"Money-only debug preserves selected speed")
	for x: int in range(1,13): planning.request_edit(0,Vector2i(x,4),true)
	planning.submit_ready(true)
	planning.set_physics_process(false)
	planning._physics_process(0.2)
	check(is_equal_approx(planning._host_combat._elapsed,0.6),"A 3x solo tick advances the one real simulation clock exactly threefold")
	planning.debug_set_values(2,999,int(planning.combat["reroll_currency"][0]))
	check(planning.combat["speed_multiplier"]==1.0,"Changing rounds resets speed instead of replaying old acceleration")
	planning.cycle_singleplayer_speed()
	planning.cycle_singleplayer_speed()
	planning._host_ready[1] = false
	planning.singleplayer = false
	var frozen: Dictionary = planning.combat.duplicate(true)
	check(not planning.cycle_singleplayer_speed() and planning.combat==frozen,"Network matches cannot call the local three-speed bypass")
	planning.singleplayer = true
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	frozen = planning.combat.duplicate(true)
	check(not planning.cycle_singleplayer_speed() and planning.combat==frozen,"Terminal runs cannot change playback")
	planning.stop_singleplayer()
	planning.start_singleplayer()
	check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(),"A fresh run commits a fresh loadout")
	check(planning.combat["speed_multiplier"]==1.0,"A fresh solo run always starts at normal speed")
	planning.queue_free()
	session.queue_free()
	await process_frame
	if failures==0: print("PASS: solo 1/2/3 cycle, actual 3x simulation clock, money/round/restart transitions, multiplayer and terminal rejection")
	quit(1 if failures else 0)
