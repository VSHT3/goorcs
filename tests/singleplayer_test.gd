extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := MatchPlanning.new()
	planning.session = session
	root.add_child(planning)
	planning.start_singleplayer()
	_check(planning.active and planning.local_slot() == 0 and session.state == MultiplayerSession.State.IDLE and not root.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "Singleplayer starts locally without installing a network peer")
	var notices: Array[String] = []
	planning.feedback.connect(func(message: String) -> void: notices.append(message))
	var untouched: Dictionary = planning.combat.duplicate(true)
	for cell: Vector2i in [Vector2i(0, 4), Vector2i(13, 4), Vector2i(-1, 4), Vector2i(14, 4)]:
		planning.request_edit(0, cell, true)
		planning.request_edit(0, cell, false)
	_check(notices.is_empty() and planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0 and planning.combat == untouched, "Endpoint and out-of-bounds strokes are silent no-ops on both boards")
	planning.submit_ready(true)
	_check(not planning.locked and planning.ready_flags == [false, false], "Illegal routes cannot start a solo wave")
	planning.request_edit(1, Vector2i(1, 4), true)
	_check(planning.layouts[1].used_tiles() == 0, "Opponent remains read-only")
	planning.request_edit(0, Vector2i(1, 4), true)
	_check(planning.layouts[1].has_path(Vector2i(1, 4)), "Accepted paths mirror")
	planning.request_edit(0, Vector2i(1, 4), false)
	_check(not planning.layouts[0].has_path(Vector2i(1, 4)) and not planning.layouts[1].has_path(Vector2i(1, 4)), "Erasing mirrors")
	planning.request_edit(0, Vector2i(1, 4), true)
	planning.request_clear(0)
	_check(planning.layouts[0].used_tiles() == 0 and planning.layouts[1].used_tiles() == 0, "Clearing mirrors")
	for x: int in range(1, 13):
		planning.request_edit(0, Vector2i(x, 4), true)
	_check(planning.layouts[0].is_ready() and planning.layouts[0].route == planning.layouts[1].route, "Both routes are legal and identical")
	var initial_coins: Array = planning.combat["coins"].duplicate()
	planning.build_tower(0, Vector2i(1, 4), &"arrow_tower", 0)
	_check(planning.combat["coins"] == initial_coins and planning.combat["towers"] == [[], []], "Rejected purchases spend nothing on either board")
	planning.build_tower(0, Vector2i(2, 3), &"arrow_tower", 0)
	var own_id: int = planning.combat["towers"][0][0]["id"]
	var other_id: int = planning.combat["towers"][1][0]["id"]
	_check(own_id != other_id and planning.combat["coins"][0] == planning.combat["coins"][1] and planning.combat["coins"][0] < initial_coins[0], "Mirrored towers retain independent IDs and pay the same price")
	planning.set_targeting(0, own_id, MatchCombat.TargetMode.STRONGEST)
	planning.upgrade_tower(0, own_id, "damage")
	planning.upgrade_tower(0, own_id, "speed")
	for slot: int in range(2):
		var tower: Dictionary = planning.combat["towers"][slot][0]
		_check(tower["mode"] == MatchCombat.TargetMode.STRONGEST and tower["damage_upgraded"] and tower["speed_upgraded"], "Targeting and both upgrades mirror by cell, not tower ID")
	var upgraded_coins: Array = planning.combat["coins"].duplicate()
	planning.upgrade_tower(0, own_id, "damage")
	_check(planning.combat["coins"] == upgraded_coins, "Rejected repeat upgrade cannot spend on either board")
	planning.sell_tower(0, other_id)
	_check(planning.combat["towers"][1].size() == 1, "Opponent tower IDs cannot be used to sell")
	planning.sell_tower(0, own_id)
	_check(planning.combat["towers"] == [[], []] and planning.combat["coins"][0] == planning.combat["coins"][1] and planning.combat["coins"][0] > upgraded_coins[0], "Selling removes both counterparts and refunds both")
	planning.submit_ready(true)
	_check(planning.locked and planning.combat["phase"] == MatchCombat.Phase.WAVE, "One Ready starts both boards")
	planning.request_clear(0)
	_check(planning.layouts[0].is_ready() and planning.layouts[1].is_ready(), "Wave routes remain locked")
	planning.build_tower(0, Vector2i(0, 0), &"arrow_tower", 0)
	_check(planning.combat["towers"][0].size() == 1 and planning.combat["towers"][1].size() == 1, "Live construction mirrors during combat")
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break
	_check(planning.combat["phase"] == MatchCombat.Phase.PLANNING and planning.combat["health"][0] < planning.combat["rules"]["base_health"] and planning.combat["health"][0] == planning.combat["health"][1], "Both boards simulate leaks and return to a planning break")
	_check(planning.ready_flags == [false, false], "Every new wave requires readiness again")
	planning.submit_ready(true)
	for tick: int in range(2400):
		planning._physics_process(1.0 / 60.0)
		if planning.combat["phase"] != MatchCombat.Phase.WAVE:
			break
	_check(planning.combat["phase"] == MatchCombat.Phase.FINISHED and planning.combat["coin_flip"], "Mirrored base destruction uses the normal terminal coin flip")
	var final_state: Dictionary = planning.combat.duplicate(true)
	planning.build_tower(0, Vector2i(4, 3), &"arrow_tower", 0)
	planning.submit_ready(true)
	_check(planning.combat == final_state, "Finished solo runs reject mutations")
	planning.stop_singleplayer()
	_check(not planning.active and not planning.singleplayer and not planning.is_physics_processing(), "Leaving clears solo mode and stops simulation")
	planning.start_singleplayer()
	_check(planning.layouts[0].used_tiles() == 0 and planning.combat["wave"] == 0 and planning.combat["towers"] == [[], []] and planning.combat["coins"] == initial_coins, "Reopening starts a fresh match")
	planning.stop_singleplayer()
	planning.queue_free()
	session.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: offline mirrored commands, ownership, transactions, waves, results, and fresh restart")
	quit(1 if failures > 0 else 0)
