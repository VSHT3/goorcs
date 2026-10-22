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
	await _check_boss_bar()
	if failures == 0:
		print("PASS: rendered boss walk/actions, wheels/deploy/jump/land, progressive damage, troop doors, dual cannon targets, transient stun stars on both orientations and the boss health row")
	quit(1 if failures else 0)

func _image() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	RenderingServer.call_deferred("force_draw", false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

# The HUD boss row draws accepted HP, a draining damage trail, enrage colour and portrait.
func _check_boss_bar() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(BossHealthBars.ROW_SIZE) + Vector2i(0, 4)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bars := BossHealthBars.new()
	bars.catalog = preload("res://resources/content_catalog.tres")
	bars.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(bars)
	var types: Dictionary = {"dreadmaw": {"boss": true, "title": "Dreadmaw, the Bone Wyrm", "enrage_health_fraction": 0.5}}
	var boss: Dictionary = {"id": 7, "type_id": "dreadmaw", "hp": 1000, "max_hp": 1000, "enraged": false, "shield_hits": 0}
	bars.refresh([boss], types)
	var full: Image = await _bar_image()
	var row: Control = bars.row_for(7)
	var track: Rect2 = row._bar_rect()
	var middle: int = int(track.position.y + track.size.y * 0.5)
	var full_fill: int = _matching(full, middle, BossHealthBars.FILL)
	_check(full_fill >= int(track.size.x) - 4, "A full-HP boss row fills its whole bar")
	var well: Rect2i = Rect2i(10, 9, 32, 32)
	var portrait: int = 0
	for y: int in range(well.position.y, well.end.y):
		for x: int in range(well.position.x, well.end.x):
			if not full.get_pixel(x, y).is_equal_approx(BossHealthBars.TRACK):
				portrait += 1
	_check(portrait > 120, "The row shows the boss's own artwork")
	boss = boss.duplicate()
	boss["hp"] = 600
	bars.refresh([boss], types)
	var hit: Image = await _bar_image()
	_check(absi(_matching(hit, middle, BossHealthBars.FILL) - roundi(full_fill * 0.6)) <= 2, "Fill follows accepted HP")
	_check(_matching(hit, middle, BossHealthBars.TRAIL) >= roundi(full_fill * 0.4) - 2, "Lost HP shows as a pale trail")
	for step: int in range(40):
		row._process(0.05)
	var settled: Image = await _bar_image()
	_check(_matching(settled, middle, BossHealthBars.TRAIL) == 0 and _changed(hit, settled) > 0, "The trail drains away after the hit")
	boss = boss.duplicate()
	boss["hp"] = 400
	boss["enraged"] = true
	bars.refresh([boss], types)
	for step: int in range(40):
		row._process(0.05)
	var enraged: Image = await _bar_image()
	_check(_matching(enraged, middle, BossHealthBars.ENRAGED) >= roundi(full_fill * 0.4) - 2 and _matching(enraged, middle, BossHealthBars.FILL) == 0, "An enraged boss's bar changes colour")
	viewport.queue_free()
	await process_frame


func _bar_image() -> Image:
	await process_frame
	RenderingServer.call_deferred("force_draw", false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _matching(image: Image, y: int, color: Color) -> int:
	var count: int = 0
	for x: int in range(image.get_width()):
		var pixel: Color = image.get_pixel(x, y)
		if absf(pixel.r - color.r) < 0.02 and absf(pixel.g - color.g) < 0.02 and absf(pixel.b - color.b) < 0.02:
			count += 1
	return count


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
