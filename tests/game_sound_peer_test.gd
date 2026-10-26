extends "res://tests/match_branch_test.gd"

func _run() -> void:
	success_message="PASS: real peers agree on accepted purchase/upgrade/send/portal/shot/hit/death/crystal sound facts, reject speculative success and reset stale history"
	planning_worker_path="res://tests/game_sound_worker.gd"
	_suite_deadline_msec=Time.get_ticks_msec()+90000
	_directory=OS.get_temp_dir().path_join("gorcs_sound_peer_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	var port: int=_unused_port()
	if port==0 or not await _start_workers():
		await _finish()
		return
	var hosted: Dictionary=await _command("host",{"action":"host","port":port})
	await _connect_guest("guest","host",hosted["code"])
	await _wait_for("guest",{"active":true},"Sound peers synchronize")
	_assert_reserved_terrain_cells([Vector2i(1, 1), Vector2i(1, 3)])
	for lane: String in ["host","guest"]:
		var slot: int=0 if lane=="host" else 1
		for x: int in range(1,5): await _edit(lane,slot,x,2)
	await _build("host",0,1,1,0,"arrow_tower")
	var tower: Dictionary=await _wait_tower("guest",0,Vector2i(1,1),0)
	await _build("guest",1,1,1,0,"orc_ballista")
	await _wait_tower("host",1,Vector2i(1,1),0)
	await _build("host",0,1,3,0,"rune_obelisk")
	await _wait_tower("guest",0,Vector2i(1,3),0)
	await _command("host",{"action":"upgrade","slot":0,"tower_id":tower["id"],"upgrade":"damage"})
	await _wait_combat("guest",{"coins":[4855,4915]},"Accepted upgrade publishes host price")
	var accepted: Dictionary=await _agree("Accepted action sound history matches")
	_check(_has_cue(accepted,CombatSoundEvents.Cue.PURCHASE) and _has_cue(accepted,CombatSoundEvents.Cue.UPGRADE),"Both peers see only host-accepted purchase/upgrade facts")
	await _command("guest",{"action":"upgrade","slot":0,"tower_id":tower["id"],"upgrade":"speed"})
	_check(await _agree("Foreign purchase rejection freezes sound facts")==accepted,"A rejected cross-owner action cannot publish a success cue or payment")
	await _command("guest",{"action":"send","slot":1,"type_id":"grunt"})
	await _wait_combat("host",{"income":[0,2]},"Guest send uses host transaction")
	accepted=await _agree("Paid send acknowledgement matches")
	_check(_has_cue(accepted,CombatSoundEvents.Cue.SEND) and not _has_cue(accepted,CombatSoundEvents.Cue.PORTAL),"Planning order acknowledges ownership but never invents an early portal arrival")
	await _both_ready()
	await _wait_combat("guest",{"phase":1},"Sound combat starts")
	await _command("host",{"action":"step","delta":0.01})
	accepted=await _sound_agree_after(int(accepted["sounds"]["last_id"]))
	for cue: int in [CombatSoundEvents.Cue.BOW,CombatSoundEvents.Cue.BALLISTA,CombatSoundEvents.Cue.RUNE,CombatSoundEvents.Cue.HIT,CombatSoundEvents.Cue.PORTAL]:
		_check(_has_cue(accepted,cue),"The real client receives host cue %d despite divergent local tower families"%cue)
	await _command("guest",{"action":"step","delta":100.0})
	_check(await _agree("Guest sound simulation rejection")==accepted,"A client cannot invent movement, damage or sound events from a local clock")
	await _command("host",{"action":"wound_fixture"})
	await _command("host",{"action":"step","delta":0.01})
	accepted=await _sound_agree_after(int(accepted["sounds"]["last_id"]))
	_check(_has_cue(accepted,CombatSoundEvents.Cue.DEATH),"Accepted actual lethal attacks replicate death cues, not missing-ID guesses")
	await _command("host",{"action":"leak_fixture"})
	await _command("host",{"action":"step","delta":0.1})
	accepted=await _sound_agree_after(int(accepted["sounds"]["last_id"]))
	_check(_has_cue(accepted,CombatSoundEvents.Cue.CRYSTAL),"Authoritative leaks publish crystal feedback on the affected board")
	var generation: int=int(accepted["sounds"]["generation"])
	await _command("host",{"action":"round_fixture"})
	await _wait_combat("guest",{"wave":2,"phase":0},"Debug transitions reset cosmetic history")
	accepted=await _agree("Sound generation agrees after reset")
	_check(int(accepted["sounds"]["generation"])>generation and accepted["sounds"]["events"].is_empty(),"A real peer reset invalidates old-position sound history without replay")
	await _finish()

func _has_cue(state: Dictionary,cue: int) -> bool:
	for event: Dictionary in state["sounds"]["events"]:
		if int(event["cue"])==cue: return true
	return false

func _sound_agree_after(previous: int) -> Dictionary:
	var deadline: int=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var host: Dictionary=_snapshot("host").get("combat",{})
		var guest: Dictionary=_snapshot("guest").get("combat",{})
		if not host.is_empty() and host==guest and int(host["sounds"]["last_id"])>previous: return guest
		await create_timer(0.02).timeout
	_check(false,"New accepted sound events agree after the host advances")
	return _snapshot("guest").get("combat",{})
