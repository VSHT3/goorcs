extends SceneTree

var failures: int = 0
const C = CombatSoundEvents.Cue

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.enemy_health = 2
	rules.health_growth = 0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	return rules

func _routes() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(14,9),30,Vector2i(0,4),Vector2i(13,4))
	for x: int in range(1,13): layout.place(Vector2i(x,4))
	return [layout.capture_routing(),layout.capture_routing()]

func _cues(model: MatchCombat) -> Array[int]:
	var cues: Array[int] = []
	for event: Dictionary in model.snapshot()["sounds"]["events"]: cues.append(int(event["cue"]))
	return cues

func _test_event_boundaries() -> void:
	var events := CombatSoundEvents.new()
	for index: int in range(1000):
		events.record(C.HIT,index%2,Vector2(index,0),0.5)
	_check(events.snapshot(0.5)["events"].size()==2,"A simultaneous horde/AoE produces bounded representative contacts per destination")
	for index: int in range(200): events.record(C.PURCHASE,index%2,Vector2.ZERO,0.5)
	var state: Dictionary = events.snapshot(0.5)
	_check(state["events"].size()==CombatSoundEvents.CAPACITY and int(state["events"].back()["id"])==events.last_id,"Accepted-event history is bounded and retains the newest ordered facts")
	var previous: int = 0
	for event: Dictionary in state["events"]:
		_check(int(event["id"])>previous,"Retained event IDs remain strictly ordered across ring wrap")
		previous=int(event["id"])
	state["events"][0]["cue"]=-1
	_check(events.snapshot(0.5)["events"][0]["cue"]==C.PURCHASE,"Consumer mutation cannot rewrite accepted event history")
	_check(events.snapshot(2.0)["events"].is_empty(),"Expired history cannot produce a late sound burst")
	var id: int = events.last_id
	events.reset()
	_check(events.generation==1 and events.last_id==id and events.snapshot(2.0)["events"].is_empty(),"Debug/growth reset retires stale coordinates without reusing sound IDs")

func _test_accepted_gameplay() -> void:
	for entry: Array in [[&"arrow_tower",C.BOW],[&"orc_ballista",C.BALLISTA],[&"rune_obelisk",C.RUNE]]:
		var model := MatchCombat.new(_rules())
		_check(model.build(0,Vector2i(1,3),entry[0],0),"Real tower purchase succeeds")
		_check(_cues(model)==[C.PURCHASE],"Only an accepted purchase acknowledges success")
		var before: Dictionary = model.snapshot()
		_check(not model.build(0,Vector2i(1,3),entry[0],0) and model.snapshot()==before,"A rejected overlap cannot announce a purchase or change any accepted state")
		var roster: Array[String] = ["grunt"]
		model.sandbox_start(_routes(),1,roster)
		model.advance(0.01)
		model.advance(0.8)
		var cues: Array[int] = _cues(model)
		_check(cues.has(entry[1]) and cues.has(C.HIT) and cues.has(C.DEATH),"Actual "+String(entry[0])+" attack and lethal damage emit its own shot family, contact and death")
	var model := MatchCombat.new(_rules())
	model.build(0,Vector2i(1,3),&"arrow_tower",0)
	var id: int = model.towers[0][0]["id"]
	for command: String in ["damage","speed","special","bomb_arrows"]:
		_check(model.upgrade_tower(0,id,command),"Real prerequisite and bomb upgrades succeed")
	var before: Dictionary = model.snapshot()
	_check(not model.upgrade_tower(0,id,"bomb_arrows") and model.snapshot()==before,"Repeated upgrade never produces a misleading success cue")
	var roster: Array[String] = ["skeleorc","skeleorc"]
	model.sandbox_start(_routes(),1,roster)
	model.advance(0.01)
	_check(_cues(model).has(C.EXPLOSION) and _cues(model).has(C.BONES),"Real bomb impacts and bloodless SkeleOrc deaths use their distinct events")
	model = MatchCombat.new(_rules())
	_check(model.send_enemy(0,&"orcling") and _cues(model)==[C.SEND],"Planning sends acknowledge only accepted orders, never a fake portal delivery")
	model.start_wave(_routes())
	_check(_cues(model).has(C.PORTAL),"The destination portal cues only when paid enemies actually arrive")
	var rules := _rules()
	rules.sandbox_mode=false
	rules.enemy_speed=100.0
	model=MatchCombat.new(rules)
	model.start_wave(_routes())
	model.advance(0.2)
	_check(_cues(model).has(C.CRYSTAL) and model.base_health[0]<rules.base_health,"Real leaking enemies produce crystal damage feedback")

func _test_local_playback() -> void:
	var audio: Node = root.get_node("AudioSettings")
	var original: float = audio.sound_volume
	audio.set_sound_volume(1.0)
	var player := GameSoundPlayer.new()
	root.add_child(player)
	var model := MatchCombat.new(_rules())
	player.observe(model.snapshot(),0,true)
	model.build(0,Vector2i(1,3),&"arrow_tower",0)
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1 and player._ui_players[0].playing,"Accepted local purchase starts actual Sound-bus playback")
	player._next_allowed.fill(0)
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1,"Repeated accepted snapshots cannot replay an acknowledgement even after its cooldown")
	model.build(1,Vector2i(1,3),&"arrow_tower",0)
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1,"Opponent/solo-mirror purchases cannot duplicate the owned action's confirmation")
	audio.set_sound_volume(0.0)
	model.upgrade_tower(0,model.towers[0][0]["id"],"damage")
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1 and player._last_id==model.snapshot()["sounds"]["last_id"],"Muted actions are consumed without starting or queueing audio")
	audio.set_sound_volume(1.0)
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1,"Unmuting does not replay previously muted events")
	var roster: Array[String]=["grunt"]
	model.sandbox_start(_routes(),1,roster)
	player.observe(model.snapshot(),0,true)
	model.advance(0.01)
	player.observe(model.snapshot(),0,true)
	await physics_frame
	await process_frame
	_check(player._starts<=GameSoundPlayer.MAX_STARTS_PER_FRAME and player._world_players.any(func(voice:AudioStreamPlayer2D)->bool:return voice.playing),"Actual combat starts world audio within the per-frame budget")
	player.set_combat_paused(true)
	_check(not player._world_players.any(func(voice:AudioStreamPlayer2D)->bool:return voice.playing),"Pausing stops combat voices instead of resuming stale tails")
	var center: Vector2=root.get_visible_rect().get_center()
	_check(player.spatial_gain(center)>player.spatial_gain(root.get_visible_rect().position) and player.spatial_gain(Vector2(-10000,0))==0.0,"Visible combat is audible while distant offscreen events fade away")
	player.deactivate()
	_check(not player._ui_players.any(func(voice:AudioStreamPlayer)->bool:return voice.playing) and not player._active,"Leaving stops all actual playback and retires event identity")
	player.observe(model.snapshot(),0,true)
	_check(player._ui_cursor==1 and player._last_id==model.snapshot()["sounds"]["last_id"],"Returning to an existing state establishes a silent baseline rather than replaying combat history")
	player.queue_free()
	audio.set_sound_volume(original)
	await process_frame
	await create_timer(0.2).timeout

func _run() -> void:
	_test_event_boundaries()
	_test_accepted_gameplay()
	await _test_local_playback()
	if failures==0: print("PASS: accepted sound facts, bounded history, real attacks/deaths/actions, local playback deduplication, mute, pause, spatial fade and leave/reopen")
	quit(1 if failures else 0)
