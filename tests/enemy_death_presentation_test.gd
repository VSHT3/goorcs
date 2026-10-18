extends SceneTree

var failures: int = 0
var board: PathBoard
var viewport: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy death pixels require a graphical renderer.")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(500,500)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = PathBoard.new()
	board.size = Vector2(500,500)
	board.layout = PathLayout.new(Vector2i(5,5),20,Vector2i(0,2),Vector2i(4,2))
	for x: int in range(1,4): board.layout.place(Vector2i(x,2))
	board.command_mode = true
	board.content_catalog = preload("res://resources/content_catalog.tres").duplicate(true)
	viewport.add_child(board)
	await process_frame
	board._endpoint_timer.paused = true
	# Exercise offscreen captures without depending on native-window presentation.
	RenderingServer.set_render_loop_enabled(false)
	var ground: Image = await _capture()
	for definition: EnemyDefinition in board.content_catalog.enemies:
		var rules := CombatRules.new()
		rules.sandbox_mode = true
		rules.enemy_health = 1
		rules.catalog = board.content_catalog
		var tower: TowerDefinition = rules.catalog.towers[0].duplicate(true)
		tower.damage = 1000
		rules.catalog = rules.catalog.duplicate() as ContentCatalog
		rules.catalog.towers = [tower]
		var model := MatchCombat.new(rules)
		var roster: Array[String] = []
		var routing: Array[Dictionary] = [board.layout.capture_routing(),board.layout.capture_routing()]
		model.sandbox_start(routing,1,roster)
		model.sandbox_spawn(0,definition.id,1)
		model.advance(0.5)
		model.build(0,Vector2i(1,1),tower.reward.id,MatchCombat.TargetMode.FURTHEST)
		model.advance(0.001)
		var state: Dictionary = model.snapshot()
		_check(state["deaths"][0].size() == 1 and state["enemies"][0].is_empty(), "Real accepted kill supplies one nonliving corpse: %s" % definition.id)
		if state["deaths"][0].is_empty(): continue
		var accepted: Dictionary = state.duplicate(true)
		board.apply_deaths(state,0)
		var initial: Image = await _capture()
		board._process(0.24)
		var falling: Image = await _capture()
		_check(initial.get_data() != falling.get_data(), "Actual corpse frames animate rather than disappearing instantly: %s" % definition.id)
		var blood_color: Color = definition.blood_color
		definition.blood_color = Color.TRANSPARENT
		board.queue_redraw()
		var without_blood: Image = await _capture()
		definition.blood_color = blood_color
		board.queue_redraw()
		_check((falling.get_data() != without_blood.get_data()) == (definition.id != &"skeleorc"), "Map splatter is visible for living Orcs and absent for SkeleOrcs: %s" % definition.id)
		var age: float = board._corpse_traces[0]["age"]
		board.apply_deaths(state,0,2.0,true)
		board._process(0.3)
		_check(board._corpse_traces.size() == 1 and is_equal_approx(board._corpse_traces[0]["age"],age), "Repeated snapshots cannot restart death and sandbox pause freezes its clock")
		board.apply_deaths(state,0,2.0,false)
		board._process(0.2)
		_check(is_equal_approx(board._corpse_traces[0]["age"],age+0.4), "Death animation follows selected simulation playback speed")
		board._process(0.2)
		var settled: Image = await _capture()
		_check(settled.get_data() != ground.get_data(), "Fallen body or bones linger after the collapse: %s" % definition.id)
		var foot: Vector2 = board._position_center(state["deaths"][0][0]["pos"]) + Vector2(0,board._cell_size()*0.28)
		_check(board.enemy_at(foot) == -1 and board.combat_enemies.is_empty(), "Rendered dead body is never a live selectable enemy")
		board._process(2.0)
		var expired: Image = await _capture()
		_check(expired.get_data() == ground.get_data(), "Corpse, shadow and splatter all clean up without another host snapshot")
		board.apply_deaths(state,0)
		_check(board._corpse_traces.is_empty(), "Republishing expired event IDs cannot resurrect visual corpses")
		_check(state == accepted, "Visual death playback never mutates accepted host state")
		model.debug_set_round(2)
		board.apply_deaths(model.snapshot(),0)
	viewport.queue_free()
	await process_frame
	RenderingServer.set_render_loop_enabled(true)
	if failures == 0:
		print("PASS: actual corpse pixels, living blood/bloodless skeleton bones, pause/speed, non-targetability, duplicate-event rejection and complete visual cleanup")
	quit(1 if failures else 0)

func _capture() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
