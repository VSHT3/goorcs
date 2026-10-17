extends SceneTree

var failures: int = 0
var viewport: SubViewport
var portrait: TowerPortrait
var guide := TowerGuide.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Tower portraits require rendered verification.")
		quit(1)
		return
	var rules: CombatRules = preload("res://resources/combat/prototype.tres")
	guide.configure(rules.catalog, rules)
	viewport = SubViewport.new()
	viewport.size = Vector2i(108, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	portrait = TowerPortrait.new()
	portrait.size = Vector2(viewport.size)
	viewport.add_child(portrait)
	var images: Array[Image] = []
	for stage: String in ["base", "damage/speed/special", "damage/speed/special/four_archers", "damage/speed/special/fire_arrows", "damage/speed/special/bomb_arrows"]:
		portrait.configure(guide.preview(&"arrow_tower", stage))
		images.append(await _capture())
	for index: int in range(1, images.size()):
		_check(images[index].get_data() != images[0].get_data(), "Archer advancement renders differently from its base tower")
	_check(images[1].get_data() != images[2].get_data(), "Two and four archers have distinct rendered silhouettes")
	_check(images[3].get_data() != images[4].get_data(), "Fire and bomb arrows retain distinct held-arrow effects")
	var branch_images: Array[Image] = []
	for suffix: String in [
		"four_archers/eight_archers",
		"four_archers/eight_archers/arrow_minigun",
		"fire_arrows/molotov",
		"fire_arrows/molotov/quick_pitch/flamethrower",
		"bomb_arrows/bigger_bombs/anti_orc_grenades",
		"bomb_arrows/bigger_bombs/anti_orc_grenades/aom",
	]:
		portrait.configure(guide.preview(&"arrow_tower", "damage/speed/special/" + suffix))
		var image: Image = await _capture()
		for earlier: Image in branch_images:
			_check(image.get_data() != earlier.get_data(), "Each new weapon/operator tier retains a distinct shared-renderer silhouette")
		branch_images.append(image)
	for record: Dictionary in guide.entries:
		for stage: Dictionary in record["stages"]:
			var preview: Dictionary = guide.preview(record["id"], stage["id"])
			var before: Dictionary = preview["tower"].duplicate(true)
			portrait.configure(preview)
			var image: Image = await _capture()
			var bounds: Rect2i = image.get_used_rect()
			_check(bounds.has_area() and Rect2i(Vector2i.ONE, viewport.size - Vector2i(2, 2)).encloses(bounds), "Selected artwork and effects fit without clipping: %s/%s" % [record["id"], stage["id"]])
			portrait._process(0.2)
			_check(preview["tower"] == before, "Cosmetic portrait animation cannot mutate guide state")
	portrait.configure(guide.preview(&"rune_obelisk", "damage/speed/onyx_ring"))
	var start: Image = await _capture()
	portrait._process(0.4)
	var moved: Image = await _capture()
	_check(start.get_data() != moved.get_data(), "Onyx orbit animates inside the field-guide portrait")
	portrait.hide()
	_check(not portrait.is_processing(), "Hidden guide artwork stops processing")
	portrait.show()
	_check(portrait.is_processing(), "Visible guide artwork resumes its orbit")
	portrait.configure({})
	var cleared: Image = await _capture()
	_check(not cleared.get_used_rect().has_area(), "Unavailable previews clear previous tower layers")
	viewport.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: rendered tier-specific archer rigs/effects, every catalog branch fits, Onyx portrait orbit, hidden lifecycle, isolated state and cleared previews")
	quit(1 if failures > 0 else 0)


func _capture() -> Image:
	portrait.set_process(false)
	portrait.queue_redraw()
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
