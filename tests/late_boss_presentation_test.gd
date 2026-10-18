extends SceneTree

var failures: int = 0
var viewport: SubViewport
var board: PathBoard

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Late boss presentation requires a graphical renderer.")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 560)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = PathBoard.new()
	board.size = Vector2(viewport.size)
	board.layout = PathLayout.new(Vector2i(9, 7), 50, Vector2i(0, 4), Vector2i(8, 4))
	for x: int in range(1, 8):
		board.layout.place(Vector2i(x, 4))
	board.input_enabled = false
	viewport.add_child(board)
	await process_frame
	board._endpoint_timer.paused = true
	var rules := preload("res://resources/combat/prototype.tres").duplicate(true) as CombatRules
	rules.sandbox_mode = true
	rules.roll_rules = null
	var core := MatchCombat.new(rules)
	var roster: Array[String] = []
	var routing: Dictionary = board.layout.capture_routing()
	_check(core.sandbox_start([routing, routing], 100, roster), "Visual scenario uses an actual admitted combat owner")
	board.tower_types = core.snapshot()["tower_types"]
	for mirrored: bool in [false, true]:
		board.mirror_horizontal = mirrored
		for type_id: StringName in [&"troll", &"orc_war_machine"]:
			core.enemies = [[], []]
			_check(core.sandbox_spawn(0, type_id, 1), "Registered late boss can be previewed on the real battlefield")
			var enemy: Dictionary = core.enemies[0][0].duplicate(true)
			enemy["progress"] = 4.0
			enemy["pos"] = Vector2(4, 4)
			board.combat_enemies = [enemy]
			var walking: Image = await _image()
			enemy = enemy.duplicate(true)
			enemy["animation_elapsed"] = 0.6
			board.combat_enemies = [enemy]
			var stride: Image = await _image()
			_check(_changed(walking, stride) > 40, "Large boss actually articulates while walking on either orientation")
			enemy["animation"] = "attack"
			enemy["animation_elapsed"] = 0.8
			board.combat_enemies = [enemy]
			var attacking: Image = await _image()
			_check(_changed(walking, attacking) > 100, "Club/cannon action changes visible anatomy, not just a clock")
			if type_id == &"orc_war_machine":
				enemy["animation"] = "walk"
				enemy["animation_elapsed"] = 0.0
				enemy["locomotion"] = "jump_deploy"
				enemy["animation"] = "jump_deploy"
				enemy["animation_elapsed"] = 0.5
				board.combat_enemies = [enemy]
				var legs: Image = await _image()
				_check(_changed(walking, legs) > 100, "Jump preparation visibly deploys legs instead of reusing wheels")
				for phase: float in [0.60, 0.25]:
					enemy["hp"] = floori(float(enemy["max_hp"]) * phase)
					board.combat_enemies = [enemy]
					var damaged: Image = await _image()
					_check(_changed(legs, damaged) > 100, "Damage phases alter substantial machine artwork on both orientations")
					legs = damaged
				enemy["animation"] = "cast"
				enemy["animation_elapsed"] = 0.6
				board.combat_enemies = [enemy]
				var doors: Image = await _image()
				_check(_changed(legs, doors) > 50, "Critical machine still visibly opens troop doors")
				enemy["locomotion"] = "jump"
				enemy["animation"] = "jump"
				enemy["jump_duration"] = 1.5
				enemy["jump_remaining"] = 0.75
				enemy["jump_from"] = Vector2(3, 4)
				enemy["jump_to"] = Vector2(5, 4)
				board.combat_enemies = [enemy]
				var airborne: Image = await _image()
				_check(_changed(doors, airborne) > 100, "Charged jump produces a distinct airborne machine pose")
				enemy["locomotion"] = "jump_land"
				enemy["animation"] = "jump_land"
				enemy["animation_elapsed"] = 0.1
				enemy["jump_remaining"] = 0.0
				enemy["progress"] = 5.0
				enemy["pos"] = Vector2(5, 4)
				board.combat_enemies = [enemy]
				var landing: Image = await _image()
				enemy = enemy.duplicate(true)
				enemy["animation_elapsed"] = 0.6
				board.combat_enemies = [enemy]
				var retracting: Image = await _image()
				_check(_changed(airborne, landing) > 100 and _changed(landing, retracting) > 100, "Landing visibly settles and retracts the legs on both orientations")
				enemy["animation"] = "walk"
				enemy["locomotion"] = "wheels"
				enemy["animation_elapsed"] = 0.0
				enemy["tower_attack_remaining"] = 0.0
				board.combat_enemies = [enemy]
				var before_cannons: Image = await _image()
				enemy = enemy.duplicate(true)
				enemy["tower_attack_count"] = 1
				enemy["tower_attack_remaining"] = 1.4
				enemy["tower_attack_aims"] = [Vector2(1, 3), Vector2(7, 3)]
				board.combat_enemies = [enemy]
				var aimed: Image = await _image()
				for aim: Vector2 in enemy["tower_attack_aims"]:
					var region := Rect2i(board.cell_center(Vector2i(aim)) - Vector2.ONE * 28.0, Vector2i(56, 56))
					_check(_changed(before_cannons.get_region(region), aimed.get_region(region)) > 10, "Both accepted random cannon targets receive visible windup warnings")
		board.combat_enemies = []
		board._process(2.0)
		core.towers = [[], []]
		_check(core.build(0, Vector2i(4, 3), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Tower status fixture uses an actual tower instance")
		var tower: Dictionary = core.towers[0][0].duplicate(true)
		board.combat_towers = [tower]
		var ready: Image = await _image()
		tower["stunned_remaining"] = 30.0
		tower["stun_count"] = 1
		tower["stun_source"] = "club"
		tower["stun_position"] = Vector2(4, 4)
		board.combat_towers = [tower]
		var stunned: Image = await _image()
		_check(_changed(ready, stunned) > 25, "Accepted stun draws visible cartoon stars around the tower")
		board._process(0.6)
		tower = tower.duplicate(true)
		tower["stunned_remaining"] = 0.0
		board.combat_towers = [tower]
		var recovered: Image = await _image()
		_check(recovered.get_data() == ready.get_data(), "Stars vanish on accepted stun expiry without leaving stale pixels")
		board.combat_towers = []
	viewport.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: rendered boss walk/actions, wheels/deploy/jump/land, progressive damage, troop doors, dual cannon targets and transient stun stars on both orientations")
	quit(1 if failures else 0)

func _image() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	RenderingServer.call_deferred("force_draw", false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _changed(before: Image, after: Image) -> int:
	var changed: int = 0
	for y: int in range(before.get_height()):
		for x: int in range(before.get_width()):
			if not before.get_pixel(x, y).is_equal_approx(after.get_pixel(x, y)):
				changed += 1
	return changed

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
