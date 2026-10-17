class_name TowerPortrait
extends PathBoard
## Field-guide presentation of an isolated accepted tower, using battlefield layers.

var _frame := Rect2(-0.8, -1.8, 1.6, 1.95)


func _ready() -> void:
	# No board terrain, endpoints, input, or simulation is needed in a portrait.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_combat_animation)
	_sync_combat_animation()


func configure(preview: Dictionary) -> void:
	combat_towers = []
	tower_types.clear()
	_tower_art.clear()
	if preview.is_empty():
		queue_redraw()
		return
	var tower: Dictionary = preview["tower"].duplicate(true)
	var reward: TowerReward = preview["reward"]
	if reward == null:
		return
	_tower_art[String(tower["type_id"])] = reward
	tower_types[String(tower["type_id"])] = preview["stats"].duplicate(true)
	combat_towers = [tower]
	_fit_artwork(tower, reward)


func _fit_artwork(tower: Dictionary, reward: TowerReward) -> void:
	var art_branch: String = String(tower.get("advancement", ""))
	if art_branch.is_empty():
		art_branch = String(tower.get("evolution", ""))
	var variant: Dictionary = reward.board_variant(art_branch, tower.get("followup", ""))
	var texture: Texture2D = variant.get("texture", reward.icon_texture)
	if texture == null:
		return
	_cache_texture_bounds(texture)
	var bounds: Rect2 = _texture_bounds[texture]
	var units: float = float(variant.get("board_height", reward.board_height)) / maxf(1.0, bounds.size.y)
	var anchor: Vector2 = variant.get("board_anchor", reward.board_anchor)
	_frame = Rect2((bounds.position - texture.get_size() * anchor) * units, bounds.size * units)
	# Reserve the battlefield's orbit envelope, even as stones pass behind it.
	_frame = _frame.merge(Rect2(-0.7, -0.85, 1.4, 0.65))
	if reward.archer_head_texture != null:
		var offsets: Array[Vector2] = [Vector2.ZERO]
		var advancement: Dictionary = tower_types[String(tower["type_id"])].get("advancements", {}).get(tower.get("advancement", ""), {})
		var count: int = int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) else 1))
		if count > 1:
			offsets.append(variant.get("secondary_sprite_offset", reward.secondary_sprite_offset))
		var additional: PackedVector2Array = variant.get("additional_archer_offsets", reward.additional_archer_offsets)
		for index: int in range(maxi(0, count - 2)):
			offsets.append(additional[index] if index < additional.size() else _archer_offset(reward, index + 2))
		for offset: Vector2 in offsets:
			var pivot: Vector2 = (Vector2(variant.get("archer_pivot", reward.archer_pivot)) + offset - texture.get_size() * anchor) * units
			# Upright head, bow, held arrow, and attached fire/bomb tip at any facing.
			var radius: float = 25.0 * units + reward.projectile_length
			_frame = _frame.merge(Rect2(pivot - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	if variant.has("portrait_bounds"):
		_frame = _frame.merge(variant["portrait_bounds"])
	_frame = _frame.grow(0.08)
	queue_redraw()


func _cell_size() -> float:
	return maxf(1.0, floorf(minf(size.x / _frame.size.x, size.y / _frame.size.y)))


func _tower_foot(_cell: Vector2i) -> Vector2:
	return ((size - _frame.size * _cell_size()) * 0.5 - _frame.position * _cell_size()).floor()


func _draw() -> void:
	if not combat_towers.is_empty():
		var tower: Dictionary = combat_towers[0]
		_draw_tower(tower, _tower_foot(tower["cell"]))
