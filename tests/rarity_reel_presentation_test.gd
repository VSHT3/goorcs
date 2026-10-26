extends SceneTree

var failures: int = 0
var viewport: SubViewport
var backdrop: ColorRect
var accepted_details: Label
var reel: RarityReel


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rarity reel concealment requires a graphical renderer")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new()
	host.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accepted_details = Label.new()
	accepted_details.position = Vector2(8, 8)
	accepted_details.add_theme_font_size_override("font_size", 24)
	host.add_child(accepted_details)
	reel = RarityReel.new()
	host.add_child(reel)
	for dimensions: Vector2i in [Vector2i(1000, 720), Vector2i(1280, 720), Vector2i(1568, 921), Vector2i(1920, 1080), Vector2i(2560, 720), Vector2i(720, 1000)]:
		viewport.size = dimensions
		await process_frame
		for reward_mode: bool in [false, true]:
			if reward_mode:
				reel.present_reward(_award())
			else:
				reel.present({"rarity": "epic"}, null)
			reel.set_process(false)
			_check(reel.get_global_rect() == Rect2(Vector2.ZERO, Vector2(dimensions)), "Shared reel covers the complete viewport after resizing")
			_check(not reel._revealed and reel._result.text.is_empty() and reel._payout.text.is_empty(), "Actual result labels stay empty while the reel starts spinning")
			await _check_concealed("spin start")
			reel._process(RarityReel.SPIN_SECONDS - 0.01)
			_check(not reel._revealed, "Continuous braking does not reveal the result before stopping")
			await _check_concealed("last braking frame")
			reel._process(0.02)
			_check(reel._revealed and reel._result.text == "Epic", "Stopping reveals the accepted rarity, not a decorative neighboring card")
			await _check_concealed("reveal hold")
			reel.cancel()
	# Higher-priority modal suspension must still hide the whole reel and freeze it.
	reel.present({"rarity": "epic"}, null)
	reel.set_process(false)
	var elapsed: float = reel._elapsed
	reel.set_suspended(true)
	backdrop.color = Color.WHITE
	var suspended: Image = await _capture()
	_check(reel.is_busy() and not reel.is_visible_in_tree() and suspended.get_pixel(0, 0).is_equal_approx(Color.WHITE), "Suspending removes concealment with the reel so the higher-priority screen can show")
	reel._process(100.0)
	_check(reel._elapsed == elapsed, "Suspending preserves the accepted presentation clock")
	reel.set_suspended(false)
	reel.set_process(false)
	await _check_concealed("resumed spin")
	reel._skip_to_result()
	_check(reel.is_busy() and reel._revealed and reel._result.text == "Epic", "Skip holds the actual result rather than dismissing it")
	await _check_concealed("skipped reveal")
	reel._skip_to_result()
	_check(not reel.is_busy() and not reel.is_visible_in_tree(), "Second activation dismisses the revealed result and its opaque cover together")
	viewport.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: rarity reel conceals every underlying pixel through spin, stop, skip and reveal at desktop, ultrawide and portrait sizes; suspension retains its lifecycle")
	quit(1 if failures else 0)


func _check_concealed(stage: String) -> void:
	# Change every underlying pixel as well as the title color, stats, attributes
	# and reroll prices. Any transparency or uncovered edge changes the capture.
	backdrop.color = Color.WHITE
	accepted_details.text = "Mythic Orcapult\nDamage 999 · Range 8\n+50% attack speed\nReroll 999 Shards · Count 40"
	accepted_details.add_theme_color_override("font_color", Color("ff3322"))
	var before: Image = await _capture()
	backdrop.color = Color.BLACK
	accepted_details.text = "Broken Orcapult\nDamage 1 · Range 1\n-50% attack speed\nReroll 1 Shard · Count 0"
	accepted_details.add_theme_color_override("font_color", Color("22ff33"))
	var after: Image = await _capture()
	_check(before.get_data() == after.get_data(), "No underlying title, color, stats, attributes, prices or edge pixels leak during " + stage)


func _capture() -> Image:
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _award() -> Dictionary:
	var tiers: Array[Dictionary] = []
	for rank: int in range(RarityReel.RARITIES.size()):
		var rarity: String = RarityReel.RARITIES[rank]
		tiers.append({"id": rarity, "title": rarity.capitalize(), "coins": 100 * (rank + 1), "shards": rank + 1})
	return {"boss_title": "Orc king war orchine", "rarity": "epic", "rarity_title": "Epic", "coins": 600, "shards": 6, "tiers": tiers}
