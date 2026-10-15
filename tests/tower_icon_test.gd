extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered icon sizing needs a graphical renderer. Run without --headless.")
		quit(1)
		return
	var archive_sides: Array[int] = []
	for area: Vector2i in [Vector2i(52, 90), Vector2i(174, 90), Vector2i(240, 120), Vector2i(32, 45)]:
		var sides: Array[int] = []
		for reward: TowerReward in preload("res://resources/content_catalog.tres").tower_rewards():
			var viewport := SubViewport.new()
			viewport.size = area
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var icon := ChestReveal.RewardIcon.new()
			icon.reward = reward
			icon.size = Vector2(area)
			viewport.add_child(icon)
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			var bounds: Rect2i = image.get_used_rect()
			var side: int = maxi(bounds.size.x, bounds.size.y)
			_check(bounds.has_area(), "%s has visible artwork" % reward.title)
			_check(Rect2i(Vector2i.ZERO, area).encloses(bounds), "%s stays within its icon area" % reward.title)
			_check(side <= mini(area.x, area.y) + 1, "%s uses a square visual frame instead of stretching to a tall container" % reward.title)
			var center: Vector2 = Vector2(bounds.position) + Vector2(bounds.size) * 0.5
			_check(center.distance_to(Vector2(area) * 0.5) <= 2.0, "%s visible artwork stays centered" % reward.title)
			sides.append(side)
			viewport.queue_free()
			await process_frame
		_check(sides.max() - sides.min() <= 2, "All tower identities have equal visible size in %s" % str(area))
		if archive_sides.is_empty():
			archive_sides.assign(sides)
		elif area.x >= 52 and area.y >= 90:
			for index: int in range(sides.size()):
				_check(absi(sides[index] - archive_sides[index]) <= 2, "Expanding a reward card cannot enlarge %s beyond its archive size" % preload("res://resources/content_catalog.tres").towers[index].reward.title)
	if failures == 0:
		print("PASS: rendered tower icons have consistent centered visual size in archive, expanded reward, and compact areas")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
