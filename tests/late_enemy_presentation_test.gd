extends SceneTree

var failures: int = 0
var viewport: SubViewport
var board: PathBoard


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(600, 450)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = PathBoard.new()
	board.layout = PathLayout.new(Vector2i(8, 6), 44, Vector2i(0, 3), Vector2i(7, 3))
	for x: int in range(1, 7):
		board.layout.place(Vector2i(x, 3))
	board.size = Vector2(600, 450)
	board.command_mode = true
	board.content_catalog = preload("res://resources/content_catalog.tres")
	viewport.add_child(board)
	await process_frame
	board._endpoint_timer.paused = true
	RenderingServer.set_render_loop_enabled(false)
	for mirror: bool in [false, true]:
		board.mirror_horizontal = mirror
		var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
		rules.sandbox_mode = true
		rules.enemy_speed = 0.0
		rules.roll_rules = null
		var core := MatchCombat.new(rules)
		_check(core.sandbox_start([board.layout.capture_routing(), board.layout.capture_routing()], 151, []), "Actual model starts rendered late-enemy fixture")
		core._spawn_enemy(0, "kamikaorc", 3.0, core._elapsed)
		core.build(0, Vector2i(7, 0), &"arrow_tower", 0)
		var tower: Dictionary = core.towers[0][0]
		board.apply_combat(core.snapshot(), 0, 1.0, true)
		var shielded: Image = await _capture()
		var victim: Dictionary = core.enemies[0][0]
		var hp: int = victim["hp"]
		for hit: int in range(10):
			core._hit(0, tower, 0, 100000)
		board.apply_combat(core.snapshot(), 0, 1.0, true)
		var broken: Image = await _capture()
		_check(victim["hp"] == hp and shielded.get_data() != broken.get_data(), "Accepted shield charges visibly disappear without inventing HP damage in either orientation")
		core.debug_set_round(151)
		core.sandbox_start([board.layout.capture_routing(), board.layout.capture_routing()], 151, [])
		core._spawn_enemy(0, "giant_skeltorc", 3.0, core._elapsed)
		board.apply_combat(core.snapshot(), 0, 1.0, true)
		await _capture()
		var picked: bool = false
		for y: int in range(150, 350, 2):
			for x: int in range(100, 500, 2):
				if board.enemy_at(Vector2(x, y)) == int(core.enemies[0][0]["id"]):
					picked = true
					break
			if picked:
				break
		_check(picked, "Larger backpack artwork retains alpha picking on normal and mirrored boards")
		core._hit(0, tower, 0, 10000000)
		core._spawn_enemy(0, "grunt", 4.0, core._elapsed)
		var dropped: Dictionary = core.snapshot()
		board.apply_combat(dropped, 0, 1.0, true)
		var fresh: Image = await _capture()
		board._process(0.5)
		var paused: Image = await _capture()
		_check(fresh.get_data() == paused.get_data() and board._ground_bombs.size() == 1, "Paused presentation holds the accepted falling bomb/fuse rather than advancing a local explosion")
		board.apply_combat(dropped, 1, 1.0, true)
		await _capture()
		_check(board._ground_bombs.is_empty(), "A bomb on slot zero is never rendered as a ground bomb on the opponent slot")
		board.apply_combat(dropped, 0, 1.0, false)
		board._process(3.0)
		await _capture()
		_check(board._bomb_explosion_traces.is_empty(), "A client cosmetic clock cannot invent detonation without a host explosion event")
		core.advance(2.0)
		var exploded: Dictionary = core.snapshot()
		board.apply_combat(exploded, 0, 1.0, true)
		var blast: Image = await _capture()
		_check(board._ground_bombs.is_empty() and board._bomb_explosion_traces.size() == 1 and blast.get_data() != fresh.get_data(), "Actual host fuse expiry replaces the ground bomb with an accepted stun burst")
		board.apply_combat(exploded, 0, 1.0, true)
		_check(board._bomb_explosion_traces.size() == 1, "Duplicate host snapshots cannot replay a second explosion")
		core.debug_set_round(1)
		board.apply_combat(core.snapshot(), 0, 1.0, true)
		await _capture()
		_check(board._ground_bombs.is_empty() and board._bomb_explosion_traces.is_empty(), "Round abandonment removes accepted bomb and explosion presentation generations")
	viewport.queue_free()
	await process_frame
	RenderingServer.set_render_loop_enabled(true)
	if failures == 0:
		print("PASS: accepted shield pixels, large mirrored picking, paused bomb/fuse, same-board ownership, host-only explosion and duplicate/reset cleanup")
	quit(1 if failures else 0)


func _capture() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
