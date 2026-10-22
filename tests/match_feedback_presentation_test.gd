extends SceneTree
## Rendered pixels for big-moment feedback: crystal hit flash/shards/number,
## the approaching-leak warning, elite/boss kill bursts with their accepted
## bounty, and the boss/round banners. Pass a directory after `--` to keep PNGs.

var failures: int = 0
var board: PathBoard
var viewport: SubViewport
var save_dir: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		save_dir = args[0]
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func _save(image: Image, name: String) -> void:
	if save_dir != "":
		image.save_png(save_dir.path_join(name + ".png"))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Match feedback pixels require a graphical renderer.")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 420)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = PathBoard.new()
	board.size = Vector2(viewport.size)
	board.layout = PathLayout.new(Vector2i(9, 7), 50, Vector2i(0, 3), Vector2i(8, 3))
	for x: int in range(1, 8):
		board.layout.place(Vector2i(x, 3))
	board.content_catalog = preload("res://resources/content_catalog.tres")
	viewport.add_child(board)
	await process_frame
	board._endpoint_timer.paused = true
	RenderingServer.set_render_loop_enabled(false)
	await _test_crystal_hit()
	await _test_leak_warning()
	await _test_kill_bursts()
	viewport.queue_free()
	await process_frame
	await _test_banners()
	RenderingServer.set_render_loop_enabled(true)
	if failures == 0:
		print("PASS: rendered crystal hit, leak warning, elite/boss kill bursts with bounty, boss and round banners, and clean expiry")
	quit(1 if failures else 0)


func _capture() -> Image:
	board.set_process(false)
	board.queue_redraw()
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _changed(before: Image, after: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if before.get_pixel(x, y).to_rgba32() != after.get_pixel(x, y).to_rgba32():
				count += 1
	return count


func _near(image: Image, region: Rect2i, color: Color, tolerance: float = 0.08) -> int:
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var pixel: Color = image.get_pixel(x, y)
			if absf(pixel.r - color.r) < tolerance and absf(pixel.g - color.g) < tolerance and absf(pixel.b - color.b) < tolerance:
				count += 1
	return count


func _count(image: Image, region: Rect2i, matches: Callable) -> int:
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if matches.call(image.get_pixel(x, y)):
				count += 1
	return count


static func _whitish(pixel: Color) -> bool:
	return pixel.r > 0.8 and pixel.g > 0.8 and pixel.b > 0.8


static func _reddish(pixel: Color) -> bool:
	return pixel.r - pixel.g > 0.12 and pixel.r - pixel.b > 0.12


static func _goldish(pixel: Color) -> bool:
	return pixel.r > 0.6 and pixel.g > 0.45 and pixel.r - pixel.b > 0.25 and pixel.r >= pixel.g


func _state(health: int, enemies: Array = [], deaths: Array = [], time: float = 0.0) -> Dictionary:
	return {"statistics_id": "feedback", "health": [health, 100], "enemies": [enemies, []], "towers": [[], []],
		"deaths": [deaths, []], "death_time": time, "death_generation": 0}


func _crystal_region() -> Rect2i:
	var foot: Vector2 = board.cell_center(board.layout.base)
	return Rect2i(Vector2i(foot) - Vector2i(70, 90), Vector2i(140, 130)).intersection(Rect2i(Vector2i.ZERO, viewport.size))


func _test_crystal_hit() -> void:
	board.apply_combat(_state(100), 0)
	var calm: Image = await _capture()
	board.apply_combat(_state(92), 0)
	board._process(0.02)
	var hit: Image = await _capture()
	_save(hit, "crystal_hit")
	var region: Rect2i = _crystal_region()
	_check(_changed(calm, hit, region) > 200, "An accepted base hit visibly flashes and shakes the crystal")
	_check(_count(hit, region, _whitish) > _count(calm, region, _whitish) + 40, "The crystal shows a white hit silhouette")
	_check(_near(hit, region, BoardFeedback.HIT_TEXT, 0.1) > 6, "The HP lost rises above the crystal")
	board._process(0.25)
	var later: Image = await _capture()
	_check(_changed(hit, later, region) > 50, "Shards and the number keep moving after the flash")
	board._process(1.0)
	var settled: Image = await _capture()
	_check(settled.get_data() == calm.get_data(), "The crystal hit leaves no stale pixels once it expires")
	var small_hit: Image
	board.apply_combat(_state(91), 0)
	board._process(0.12)
	small_hit = await _capture()
	board._process(1.0)
	board.apply_combat(_state(71), 0)
	board._process(0.12)
	var big_hit: Image = await _capture()
	_save(big_hit, "crystal_hit_big")
	_check(_changed(calm, big_hit, region) > _changed(calm, small_hit, region), "A heavier leak throws a larger hit than a single HP")
	board._process(1.0)


func _route() -> Array:
	var route: Array = []
	for x: int in range(0, 9):
		route.append(Vector2i(x, 3))
	return route


func _test_leak_warning() -> void:
	board.apply_combat(_state(71), 0)
	var calm: Image = await _capture()
	var far: Dictionary = {"id": 50, "type_id": "grunt", "hp": 5, "max_hp": 5, "progress": 2.0, "pos": Vector2(2, 3), "route": _route(), "age": 0.0}
	board.apply_combat(_state(71, [far]), 0)
	board._enemy_blend_elapsed = PathBoard.ENEMY_BLEND_DURATION
	var distant: Image = await _capture()
	var region: Rect2i = _crystal_region()
	_check(_count(distant, region, _reddish) == _count(calm, region, _reddish), "A distant enemy raises no crystal warning")
	var near: Dictionary = far.duplicate(true)
	near["progress"] = 7.4
	near["pos"] = Vector2(7.4, 3)
	board.apply_combat(_state(71, [near]), 0)
	board._enemy_blend_elapsed = PathBoard.ENEMY_BLEND_DURATION
	var warning: Image = await _capture()
	_save(warning, "leak_warning")
	_check(_count(warning, region, _reddish) > _count(calm, region, _reddish) + 20, "An enemy closing on the crystal draws red warning corners")
	board.apply_combat(_state(71), 0)


func _kill(type_id: StringName) -> Dictionary:
	var rules := CombatRules.new()
	rules.sandbox_mode = true
	rules.enemy_health = 1
	rules.catalog = board.content_catalog
	var definition: EnemyDefinition
	for enemy: EnemyDefinition in rules.catalog.enemies:
		if enemy.id == type_id:
			definition = enemy
	var tower: TowerDefinition = rules.catalog.towers[0].duplicate(true)
	tower.damage = 100000
	for element: StringName in TowerDefinition.ELEMENTS:
		if not definition.immune_elements.has(String(element)):
			tower.damage_type = element
			break
	rules.catalog = rules.catalog.duplicate() as ContentCatalog
	rules.catalog.towers = [tower]
	var model := MatchCombat.new(rules)
	var roster: Array[String] = []
	var routing: Array[Dictionary] = [board.layout.capture_routing(), board.layout.capture_routing()]
	model.sandbox_start(routing, 1, roster)
	model.sandbox_spawn(0, type_id, 1)
	model.advance(0.8)
	model.build(0, Vector2i(2, 2), tower.reward.id, MatchCombat.TargetMode.FURTHEST)
	for contact: int in range(definition.hit_shield):
		model._hit(0, model.towers[0][0], 0, 1000)
	var coins: int = model.coins[0]
	model.advance(0.001)
	var state: Dictionary = model.snapshot()
	_check(state["deaths"][0].size() == 1 and int(state["deaths"][0][0]["coins"]) == model.coins[0] - coins - _boss_loot(state) - _clear_coins(state), "A real %s kill publishes the bounty actually paid" % type_id)
	return state


# Killing the only enemy also clears the sandbox wave, which pays separately.
func _clear_coins(state: Dictionary) -> int:
	return int(state["clears"]["gains"][0][0]) if int(state["clears"]["count"]) > 0 else 0


func _boss_loot(state: Dictionary) -> int:
	var total: int = 0
	for award: Dictionary in state["boss_rewards"][0]:
		total += int(award.get("coins", 0))
	return total


func _burst_region(state: Dictionary) -> Rect2i:
	var center: Vector2 = board._position_center(state["deaths"][0][0]["pos"])
	return Rect2i(Vector2i(center) - Vector2i(120, 200), Vector2i(240, 250)).intersection(Rect2i(Vector2i.ZERO, viewport.size))


func _death_image(state: Dictionary, age: float, coins: int = -1) -> Image:
	var copy: Dictionary = state.duplicate(true)
	copy["statistics_id"] = "kill_%d_%d" % [Time.get_ticks_usec(), coins]
	if coins >= 0:
		copy["deaths"][0][0]["coins"] = coins
	copy["death_time"] = float(copy["deaths"][0][0]["time"]) + age
	board.apply_deaths(copy, 0)
	return await _capture()


func _test_kill_bursts() -> void:
	var elite: Dictionary = _kill(&"orc_chief")
	var boss: Dictionary = _kill(&"troll")
	var basic: Dictionary = _kill(&"grunt")
	var elite_bounty: int = int(elite["deaths"][0][0]["coins"])
	_check(elite_bounty > 0 and int(boss["deaths"][0][0]["coins"]) >= 100 and int(basic["deaths"][0][0]["coins"]) > 0, "Elite, boss and basic kills all paid a bounty")
	var region: Rect2i = _burst_region(elite)
	var with_coin: Image = await _death_image(elite, 0.12)
	_save(with_coin, "elite_kill")
	var without_coin: Image = await _death_image(elite, 0.12, 0)
	_check(_changed(without_coin, with_coin, region) > 30, "An elite kill pops its accepted bounty")
	_check(_near(with_coin, region, BoardFeedback.COIN, 0.06) > _near(without_coin, region, BoardFeedback.COIN, 0.06) + 8, "The bounty pops as a gold coin")
	var basic_coin: Image = await _death_image(basic, 0.12)
	var basic_plain: Image = await _death_image(basic, 0.12, 0)
	_check(basic_coin.get_data() == basic_plain.get_data(), "Ordinary kills stay quiet so hordes remain readable")
	var boss_region: Rect2i = _burst_region(boss)
	var boss_burst: Image = await _death_image(boss, 0.2)
	_save(boss_burst, "boss_kill")
	var boss_plain: Image = await _death_image(boss, 0.2, 0)
	_check(_count(boss_burst, boss_region, _goldish) > _count(with_coin, region, _goldish) + 20, "A boss kill bursts larger and golder than an elite")
	_check(_changed(boss_plain, boss_burst, boss_region) > 60, "A boss kill pops its large accepted bounty")
	var expired: Image = await _death_image(boss, BoardFeedback.kill_duration(true, 100) + 0.05)
	var expired_plain: Image = await _death_image(boss, BoardFeedback.kill_duration(true, 100) + 0.05, 0)
	_check(expired.get_data() == expired_plain.get_data(), "The burst and coin finish while the corpse is still fading")
	board.apply_deaths({"statistics_id": "done", "deaths": [[], []], "death_time": 0.0}, 0)


func _test_banners() -> void:
	var holder := SubViewport.new()
	holder.size = Vector2i(1000, 220)
	holder.world_2d = World2D.new()
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	var backdrop := ColorRect.new()
	backdrop.color = Color("344336")
	backdrop.size = Vector2(holder.size)
	holder.add_child(backdrop)
	var banner := MatchBanner.new()
	banner.catalog = preload("res://resources/content_catalog.tres")
	banner.size = Vector2(holder.size)
	holder.add_child(banner)
	var types: Dictionary = {"troll": {"boss": true, "title": "Trollorc"}}
	var state: Dictionary = {"statistics_id": "banner", "phase": MatchCombat.Phase.WAVE, "wave": 59, "enemies": [[], []], "enemy_types": types, "clears": {"count": 0, "gains": [[0, 0], [0, 0]]}}
	banner.observe(state, 0)
	var empty: Image = await _banner_capture(holder)
	state["enemies"] = [[{"id": 7, "type_id": "troll"}], []]
	banner.observe(state, 0)
	banner._process(0.5)
	var boss: Image = await _banner_capture(holder)
	_save(boss, "boss_banner")
	var panel: Rect2i = Rect2i(banner.panel_rect())
	_check(_changed(empty, boss, panel) > panel.get_area() / 2, "The boss banner draws its panel")
	_check(_near(boss, panel, MatchBanner.GOLD, 0.08) > 60, "The boss title is drawn in gold")
	var well := Rect2i(panel.position + Vector2i(14, 12), Vector2i(40, 40))
	_check(_changed(empty, boss, well) > 400, "The boss portrait fills its well")
	for step: int in range(40):
		banner._process(0.1)
	var gone: Image = await _banner_capture(holder)
	_check(gone.get_data() == empty.get_data(), "The boss banner leaves nothing behind")
	state["clears"] = {"count": 1, "gains": [[57, 3], [0, 0]]}
	state["phase"] = MatchCombat.Phase.PLANNING
	banner.observe(state, 0)
	banner._process(0.4)
	var round: Image = await _banner_capture(holder)
	_save(round, "round_banner")
	panel = Rect2i(banner.panel_rect())
	_check(_near(round, panel, Color("e0bc77"), 0.05) > 20 and _near(round, panel, Color("76cbd8"), 0.05) > 10, "The round banner shows the Coin and Shard it paid")
	banner._process(0.0)
	holder.queue_free()
	await process_frame


func _banner_capture(holder: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return holder.get_texture().get_image()
