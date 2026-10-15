class_name PathBoard
extends Control

signal edited
signal feedback(message: String)
signal edit_requested(cell: Vector2i, place: bool)
signal cell_clicked(cell: Vector2i, button: MouseButton)
signal tower_dropped(cell: Vector2i, type_id: StringName)
signal enemy_clicked(enemy_id: int)

const GROUND := Color("344336")
const GROUND_PATCH_LIGHT := Color("374638")
const GROUND_PATCH_DARK := Color("314032")
const GRASS := Color("46513c")
const APRON := Color("2b362b")
const EARTH_RIM := Color("3c4030")
const FIELD_EDGE := Color("263429")
const PATH_SOIL := Color("454a36")
const PATH_CONTACT := Color("394332")
const TILE := Color("5f6450")
const STONE := Color("696d57")
const STONE_LIGHT := Color("6c705a")
const STONE_DARK := Color("676b55")
const ENEMY_BLEND_DURATION: float = 0.1
const SHOT_DURATION: float = 0.18
const PULSE_DURATION: float = 0.14
const ENEMY_LATERAL_SPREAD: float = 0.10
const ENEMY_CORNER_BLEND: float = 0.25
const ENDPOINT_FRAME_SIZE: int = 96
const ENDPOINT_FRAME_COUNT: int = 16
const ENDPOINT_FRAME_SECONDS: float = 0.2
const ARROW_ART: TowerReward = preload("res://resources/collection/arrow_tower.tres")
const ARCHER_CROP := Rect2(29, 0, 25, 31)
const SECOND_ARCHER_OFFSET := Vector2(-20, 0)
const ARCHER_BOW := Vector2(46, 19)
const ONYX_PULSE_DURATION: float = 0.30
const BOULDER_ORBIT_SPEED: float = 1.8
static var _rune_stone_shape := PackedVector2Array([
	Vector2(-0.85, -0.45), Vector2(-0.25, -0.95), Vector2(0.60, -0.75),
	Vector2(1.0, 0.15), Vector2(0.35, 0.85), Vector2(-0.65, 0.70),
])

var layout: PathLayout
var command_mode: bool = false
var mirror_horizontal: bool = false
var cell_click_mode: bool = false:
	set(value):
		if cell_click_mode != value:
			cancel_stroke()
		cell_click_mode = value
var combat_towers: Array = []:
	set(value):
		combat_towers = value
		_capture_shots()
		_rebuild_draw_order()
		_sync_combat_animation()
		queue_redraw()
var combat_enemies: Array = []:
	# Only presentation state is blended; accepted enemy dictionaries stay untouched.
	set(value):
		combat_enemies = value
		_blend_enemies()
		_rebuild_draw_order()
		_sync_combat_animation()
		queue_redraw()
var selected_tower_id: int = -1
var selected_enemy_id: int = -1:
	set(value):
		selected_enemy_id = value
		queue_redraw()
var enemy_inspection_enabled: bool = false:
	set(value):
		enemy_inspection_enabled = value
		_update_input_filter()
var tower_types: Dictionary = {}
var placement_id: StringName = &"":
	set(value):
		placement_id = value
		queue_redraw()
var tower_catalog: Array[TowerReward] = CollectionStore.DEFAULT_CATALOG:
	set(value):
		tower_catalog = value
		_tower_art.clear()
		for reward: TowerReward in value:
			_tower_art[String(reward.id)] = reward
			_cache_texture_bounds(reward.icon_texture)
		queue_redraw()
var placement_enabled: bool = true:
	set(value):
		placement_enabled = value
		if not value:
			clear_drag_preview()
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		_update_input_filter()
		if not value:
			cancel_stroke()
var _hover := Vector2i(-1, -1)
var _paint_button: MouseButton = MOUSE_BUTTON_NONE
var _last_painted := Vector2i(-1, -1)
var _seen_shots: Dictionary = {}
var _shot_traces: Array[Dictionary] = []
var _has_boulders: bool = false
var _boulder_phase: float = 0.0
var _enemy_progress: Dictionary[int, Vector2] = {}
var _enemy_blend_elapsed: float = ENEMY_BLEND_DURATION
var _tower_art: Dictionary[String, TowerReward] = {}
var _texture_bounds: Dictionary[Texture2D, Rect2] = {}
var _draw_order: Array[Dictionary] = []
var _drag_placement_id: StringName = &""
var _enemy_art: Dictionary[String, EnemyDefinition] = {}
var _enemy_hit_images: Dictionary[Texture2D, Image] = {}
var _slowed_enemy_textures: Dictionary[Texture2D, Texture2D] = {}
var _portal_texture: AtlasTexture
var _crystal_texture: AtlasTexture
var _endpoint_frame: int = 0
var _endpoint_timer: Timer
var _ground_canvas: Node2D
var _ground_mask := PackedByteArray()
var _ground_rect := Rect2()
var _ground_dimensions := Vector2i.ZERO
var _ground_style: int = -1


func _ready() -> void:
	tower_catalog = tower_catalog
	for definition: EnemyDefinition in CombatRules.DEFAULT_ENEMIES:
		_enemy_art[String(definition.id)] = definition
		_cache_texture_bounds(definition.texture)
		_cache_slow_texture(definition.texture)
	_portal_texture = _endpoint_texture(preload("res://assets/world/enemy_portal_idle.png"))
	_crystal_texture = _endpoint_texture(preload("res://assets/world/health_crystal_idle.png"))
	_cache_texture_bounds(_portal_texture)
	_cache_texture_bounds(_crystal_texture)
	_endpoint_timer = Timer.new()
	_endpoint_timer.wait_time = ENDPOINT_FRAME_SECONDS
	_endpoint_timer.ignore_time_scale = true
	_endpoint_timer.timeout.connect(_advance_endpoints)
	add_child(_endpoint_timer)
	visibility_changed.connect(_sync_endpoint_animation)
	_sync_endpoint_animation()
	_rebuild_draw_order()
	_ground_canvas = Node2D.new()
	_ground_canvas.show_behind_parent = true
	_ground_canvas.draw.connect(_draw_ground)
	add_child(_ground_canvas)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	_sync_combat_animation()


func _endpoint_texture(sheet: Texture2D) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(0, 0, ENDPOINT_FRAME_SIZE, ENDPOINT_FRAME_SIZE)
	return texture


func _sync_endpoint_animation() -> void:
	if is_visible_in_tree():
		_endpoint_timer.start()
	else:
		_endpoint_timer.stop()
	_sync_combat_animation()


func _advance_endpoints() -> void:
	_endpoint_frame = (_endpoint_frame + 1) % ENDPOINT_FRAME_COUNT
	# Mutate only the atlas regions; cached framing stays fixed for the whole loop.
	_portal_texture.region.position.x = _endpoint_frame * ENDPOINT_FRAME_SIZE
	_crystal_texture.region.position.x = _endpoint_frame * ENDPOINT_FRAME_SIZE
	queue_redraw()

func _sync_combat_animation() -> void:
	set_process(is_visible_in_tree() and (_has_boulders or not combat_enemies.is_empty() or not _shot_traces.is_empty()))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _has_boulders:
		_boulder_phase = fposmod(_boulder_phase + delta * BOULDER_ORBIT_SPEED, TAU)
	_enemy_blend_elapsed = minf(_enemy_blend_elapsed + delta, ENEMY_BLEND_DURATION)
	for index: int in range(_shot_traces.size() - 1, -1, -1):
		_shot_traces[index]["life"] -= delta
		if float(_shot_traces[index]["life"]) <= 0.0:
			_shot_traces.remove_at(index)
	queue_redraw()
	_sync_combat_animation()


func _capture_shots() -> void:
	_has_boulders = false
	if combat_towers.is_empty():
		_seen_shots.clear()
		_shot_traces.clear()
		_sync_combat_animation()
		return
	for tower: Dictionary in combat_towers:
		var tower_id: int = int(tower["id"])
		var shot: int = int(tower.get("shot", 0))
		var secondary_shot: int = int(tower.get("secondary_shot", 0))
		var previous: Vector2i = _seen_shots.get(tower_id, Vector2i.ZERO)
		var definition: Dictionary = tower_types.get(tower["type_id"], {})
		var boulders: bool = tower.get("evolution", "") == "boulders"
		_has_boulders = _has_boulders or boulders
		if shot > previous.x and not boulders:
			_capture_attack(tower, definition, false)
		if secondary_shot > previous.y and bool(tower.get("special_upgraded", false)):
			_capture_attack(tower, definition, true)
		_seen_shots[tower_id] = Vector2i(shot, secondary_shot)


func _capture_attack(tower: Dictionary, definition: Dictionary, secondary: bool) -> void:
	var area_attack: bool = bool(definition.get("area_attack", false))
	var bounce: bool = not secondary and bool(tower.get("bounce_active", false))
	var evolution: String = tower.get("evolution", "")
	var duration: float = (ONYX_PULSE_DURATION if evolution == "onyx_ring" else PULSE_DURATION) if area_attack else SHOT_DURATION * (2.0 if bounce else 1.0)
	var hits: Array[Vector2] = []
	if area_attack:
		for enemy: Dictionary in combat_enemies:
			if MatchCombat.cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), float(definition.get("range", 0.0))):
				hits.append(enemy["pos"])
	# Copy accepted positions, including lethal hits whose enemies already disappeared.
	_shot_traces.append({
		"cell": tower["cell"],
		"type_id": tower["type_id"],
		"evolution": evolution,
		"aim": tower.get("secondary_aim" if secondary else "aim", Vector2(tower["cell"])),
		"secondary": secondary,
		"bounce_active": bounce,
		"bounce_aim": tower.get("bounce_aim", tower.get("aim", Vector2(tower["cell"]))),
		"life": duration,
		"duration": duration,
		"area_attack": area_attack,
		"range": float(definition.get("range", 0.0)),
		"hits": hits,
	})
	_sync_combat_animation()


func _blend_enemies() -> void:
	var next_progress: Dictionary[int, Vector2] = {}
	for enemy: Dictionary in combat_enemies:
		var id: int = int(enemy["id"])
		var target: float = float(enemy["progress"])
		var previous: Vector2 = _enemy_progress.get(id, Vector2(target, target))
		var displayed: float = lerpf(previous.x, previous.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
		next_progress[id] = Vector2(displayed, target)
	_enemy_progress = next_progress
	_enemy_blend_elapsed = 0.0


func _enemy_position(enemy: Dictionary) -> Vector2:
	var route: Array = enemy["route"]
	if route.is_empty():
		return enemy["pos"]
	if route.size() == 1:
		return Vector2(route[0])
	return _route_position(route, _enemy_route_progress(enemy))


func _enemy_visual_position(enemy: Dictionary) -> Vector2:
	var route: Array = enemy["route"]
	if route.size() < 2:
		return _enemy_position(enemy)
	var progress: float = _enemy_route_progress(enemy)
	return _route_position(route, progress) + _route_normal(route, progress) * _enemy_lateral_offset(int(enemy["id"]))


func _enemy_lateral_offset(id: int) -> float:
	# Integer-only mixing is stable across snapshots and never consumes combat RNG.
	var mixed: int = (id * 1103515245 + 12345) & 0x7fffffff
	return (float(mixed % 2001) / 1000.0 - 1.0) * ENEMY_LATERAL_SPREAD


func _route_normal(route: Array, progress: float) -> Vector2:
	var index: int = mini(floori(progress), route.size() - 2)
	var fraction: float = progress - index
	var direction: Vector2 = (Vector2(route[index + 1]) - Vector2(route[index])).normalized()
	if index > 0 and fraction < ENEMY_CORNER_BLEND:
		var incoming: Vector2 = (Vector2(route[index]) - Vector2(route[index - 1])).normalized()
		direction = incoming.lerp(direction, smoothstep(-ENEMY_CORNER_BLEND, ENEMY_CORNER_BLEND, fraction))
	elif index + 2 < route.size() and fraction > 1.0 - ENEMY_CORNER_BLEND:
		var outgoing: Vector2 = (Vector2(route[index + 2]) - Vector2(route[index + 1])).normalized()
		direction = direction.lerp(outgoing, smoothstep(1.0 - ENEMY_CORNER_BLEND, 1.0 + ENEMY_CORNER_BLEND, fraction))
	# Do not renormalize the blend: bends gently narrow the spread, and even a
	# reversing fixture passes continuously through zero instead of flipping.
	return Vector2(-direction.y, direction.x)


func _enemy_route_progress(enemy: Dictionary) -> float:
	var blend: Vector2 = _enemy_progress.get(int(enemy["id"]), Vector2(enemy["progress"], enemy["progress"]))
	return clampf(lerpf(blend.x, blend.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION), 0.0, maxf(0.0, enemy["route"].size() - 1))


func _route_position(route: Array, progress: float) -> Vector2:
	var index: int = mini(floori(progress), route.size() - 2)
	return Vector2(route[index]).lerp(Vector2(route[index + 1]), progress - index)


func _enemy_faces_left(route: Array, progress: float) -> bool:
	if route.size() < 2:
		return mirror_horizontal
	# Keep upright sprites facing the last horizontal leg through vertical turns.
	var index: int = mini(floori(progress), route.size() - 2)
	for segment: int in range(index, -1, -1):
		var direction: Vector2i = route[segment + 1] - route[segment]
		if direction.x != 0:
			return (direction.x < 0) != mirror_horizontal
	for segment: int in range(index + 1, route.size() - 1):
		var direction: Vector2i = route[segment + 1] - route[segment]
		if direction.x != 0:
			return (direction.x < 0) != mirror_horizontal
	return mirror_horizontal


func cell_center(cell: Vector2i) -> Vector2:
	return _position_center(Vector2(cell))


func _position_center(position: Vector2) -> Vector2:
	if mirror_horizontal:
		position.x = layout.dimensions.x - 1 - position.x
	return _board_origin() + (position + Vector2(0.5, 0.5)) * _cell_size()


func _cell_size() -> float:
	return floorf(minf(size.x / layout.dimensions.x, size.y / layout.dimensions.y))


func _board_origin() -> Vector2:
	return (size - Vector2(layout.dimensions) * _cell_size()) * 0.5


func _cell_at(position: Vector2) -> Vector2i:
	var cell := Vector2i(((position - _board_origin()) / _cell_size()).floor())
	if mirror_horizontal:
		cell.x = layout.dimensions.x - 1 - cell.x
	return cell


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not input_enabled or not placement_enabled or layout == null or _cell_size() <= 0.0:
		return false
	if not data is Dictionary or not data.get("tower_type") is String:
		return false
	var type_id: String = data["tower_type"]
	if not tower_types.has(type_id):
		return false
	_drag_placement_id = StringName(type_id)
	_hover = _cell_at(at_position)
	queue_redraw()
	return _placement_is_legal(_hover, type_id)


func clear_drag_preview() -> void:
	_drag_placement_id = &""
	queue_redraw()


func _placement_is_legal(cell: Vector2i, type_id: String) -> bool:
	if not placement_enabled or not tower_types.has(type_id) or not layout.contains(cell) or layout.has_path(cell):
		return false
	for tower: Dictionary in combat_towers:
		if tower["cell"] == cell:
			return false
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	cancel_stroke()
	tower_dropped.emit(_cell_at(at_position), StringName(data["tower_type"]))


func _update_input_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if input_enabled or enemy_inspection_enabled else Control.MOUSE_FILTER_IGNORE


func enemy_at(position: Vector2) -> int:
	# Match the interpolated sprite and front-to-back drawing order, not its path cell.
	_update_draw_order()
	for index: int in range(_draw_order.size() - 1, -1, -1):
		var item: Dictionary = _draw_order[index]
		if int(item["kind"]) != 2:
			continue
		var enemy: Dictionary = item["data"]
		if _enemy_contains_point(enemy, item["foot"], item["progress"], position):
			return int(enemy["id"])
	return -1


func _gui_input(event: InputEvent) -> void:
	if layout == null or not (input_enabled or enemy_inspection_enabled):
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
			return
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and enemy_inspection_enabled:
			var enemy_id: int = enemy_at(click.position)
			if enemy_id >= 0:
				cancel_stroke()
				enemy_clicked.emit(enemy_id)
				accept_event()
				return
		if not input_enabled:
			if click.pressed:
				cell_clicked.emit(_cell_at(click.position), click.button_index)
			accept_event()
			return
		if cell_click_mode:
			if click.pressed:
				var cell: Vector2i = _cell_at(click.position)
				if layout.contains(cell):
					cell_clicked.emit(cell, click.button_index)
			accept_event()
			return
		if click.pressed:
			_paint_button = click.button_index
			_last_painted = Vector2i(-1, -1)
			_paint(_cell_at(click.position))
		else:
			_paint_button = MOUSE_BUTTON_NONE
		accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover = _cell_at(motion.position)
		# Releases outside the board must not leave painting latched on.
		if _paint_button != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(_paint_button):
			_paint_button = MOUSE_BUTTON_NONE
		if _paint_button != MOUSE_BUTTON_NONE:
			_paint(_hover)
		queue_redraw()


func cancel_stroke() -> void:
	_paint_button = MOUSE_BUTTON_NONE
	_last_painted = Vector2i(-1, -1)
	_hover = Vector2i(-1, -1)
	clear_drag_preview()
	queue_redraw()


func _paint(cell: Vector2i) -> void:
	if cell == _last_painted or not layout.contains(cell):
		return
	_last_painted = cell
	if command_mode:
		for tower: Dictionary in combat_towers:
			if tower["cell"] == cell:
				if _paint_button == MOUSE_BUTTON_LEFT:
					cell_clicked.emit(cell, _paint_button)
				return
		edit_requested.emit(cell, _paint_button == MOUSE_BUTTON_LEFT)
		return
	if layout.is_endpoint(cell):
		feedback.emit("Entrance and base are fixed; they use no budget.")
		return
	var changed: bool = false
	if _paint_button == MOUSE_BUTTON_LEFT:
		if not layout.has_path(cell) and layout.used_tiles() >= layout.budget:
			feedback.emit("Tile budget reached. Remove a tile before placing another.")
			return
		changed = layout.place(cell)
	elif _paint_button == MOUSE_BUTTON_RIGHT:
		changed = layout.erase(cell)
	if changed:
		edited.emit()
		queue_redraw()


func _on_mouse_exited() -> void:
	_hover = Vector2i(-1, -1)
	_last_painted = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	if layout == null or _cell_size() <= 0.0:
		return
	_update_ground()
	_draw_ranges()
	_draw_hover()
	_draw_attacks()
	_draw_combat()
	_draw_projectiles()


func _update_ground() -> void:
	var rect := Rect2(_board_origin(), Vector2(layout.dimensions) * _cell_size())
	var style: int = int(mirror_horizontal)
	var dirty: bool = rect != _ground_rect or style != _ground_style or layout.dimensions != _ground_dimensions
	if layout.dimensions != _ground_dimensions:
		_ground_mask.resize(layout.dimensions.x * layout.dimensions.y)
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			var index: int = y * layout.dimensions.x + x
			var occupied: int = int(layout.has_path(Vector2i(x, y)))
			if _ground_mask[index] != occupied:
				_ground_mask[index] = occupied
				dirty = true
	if dirty:
		_ground_rect = rect
		_ground_style = style
		_ground_dimensions = layout.dimensions
		_ground_canvas.queue_redraw()


func _draw_ground() -> void:
	if layout == null or _cell_size() <= 0.0:
		return
	var cell_size: float = _cell_size()
	var origin: Vector2 = _board_origin()
	var field := Rect2(origin, Vector2(layout.dimensions) * cell_size)
	# A subdued earth apron is entirely outside the legal rectangular field.
	_ground_canvas.draw_rect(field.grow(cell_size * 0.375), APRON)
	_ground_canvas.draw_rect(field.grow(cell_size * 0.18), EARTH_RIM)
	_ground_canvas.draw_rect(field.grow(cell_size * 0.055), FIELD_EDGE)
	_ground_canvas.draw_rect(field, GROUND)
	# Broad stepped sod masses, not a mark repeated inside every grid cell.
	var patch_size := Vector2(cell_size * 3.4, cell_size * 2.3)
	for row: int in range(ceili(field.size.y / patch_size.y)):
		for column: int in range(ceili(field.size.x / patch_size.x)):
			var pattern: int = absi(column * 47 + row * 83)
			var point: Vector2 = origin + Vector2(column, row) * patch_size
			point += Vector2((pattern % 7) * 0.10 - 0.3, (pattern % 5) * 0.08 - 0.2) * cell_size
			var color: Color = GROUND_PATCH_LIGHT if pattern % 3 else GROUND_PATCH_DARK
			var patch := Rect2(point, patch_size * Vector2(0.78, 0.66))
			_ground_canvas.draw_rect(patch.intersection(field), color)
			patch = Rect2(point + Vector2(cell_size * 0.5, patch_size.y * 0.66),
				patch_size * Vector2(0.51, 0.20))
			_ground_canvas.draw_rect(patch.intersection(field), color)
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			var pattern: int = absi(x * 37 + y * 61)
			if pattern % 7 != 2:
				continue
			var tuft: Vector2 = origin + (Vector2(x, y) + Vector2(0.28 + (pattern % 3) * 0.16, 0.73)) * cell_size
			_ground_canvas.draw_line(tuft, tuft + Vector2(-2, -3), GRASS, 1.0)
			_ground_canvas.draw_line(tuft + Vector2(3, 0), tuft + Vector2(2, -2), GRASS, 1.0)
	# Soil and contact silhouettes precede the stone union, preserving every join.
	for layer: int in range(3):
		for y: int in range(layout.dimensions.y):
			for x: int in range(layout.dimensions.x):
				var cell := Vector2i(x, y)
				if not layout.has_path(cell):
					continue
				var center: Vector2 = cell_center(cell)
				var width: float = cell_size * (0.72 if layer == 2 else (0.84 if layer == 1 else 0.92))
				_draw_pavement_piece(Rect2(center - Vector2.ONE * width * 0.5, Vector2.ONE * width), layer)
				for direction: Vector2i in PathLayout.DIRECTIONS:
					if not layout.contains(cell + direction) or not layout.has_path(cell + direction):
						continue
					var display_direction := Vector2(direction)
					if mirror_horizontal:
						display_direction.x = -display_direction.x
					var arm: Rect2
					if direction.x != 0:
						arm = Rect2(center + Vector2(-cell_size * 0.5 if display_direction.x < 0 else 0.0, -width * 0.5),
							Vector2(cell_size * 0.5, width))
					else:
						arm = Rect2(center + Vector2(-width * 0.5, -cell_size * 0.5 if direction.y < 0 else 0.0),
							Vector2(width, cell_size * 0.5))
					_draw_pavement_piece(arm, layer)


func _draw_pavement_piece(rect: Rect2, layer: int) -> void:
	_ground_canvas.draw_rect(rect, TILE if layer == 2 else (PATH_CONTACT if layer == 1 else PATH_SOIL))
	if layer != 2:
		return
	# World-aligned staggered stones are clipped to the connected pavement mask.
	# Their pattern never restarts at a tile boundary, bend, or branch.
	var brick_height: float = maxf(6.0, floorf(_cell_size() * 0.24))
	var brick_width: float = brick_height * 2.7
	for row: int in range(floori(rect.position.y / brick_height), ceili(rect.end.y / brick_height)):
		var stagger: float = brick_width * 0.5 if row % 2 else 0.0
		for column: int in range(floori((rect.position.x - stagger) / brick_width), ceili((rect.end.x - stagger) / brick_width)):
			var brick := Rect2(Vector2(column * brick_width + stagger + 1.0, row * brick_height + 1.0),
				Vector2(brick_width - 1.0, brick_height - 1.0))
			var clipped: Rect2 = brick.intersection(rect)
			if clipped.has_area():
				var variation: int = absi(column * 7 + row * 11) % 7
				_ground_canvas.draw_rect(clipped, STONE_LIGHT if variation == 0 else (STONE_DARK if variation == 1 else STONE))


func _draw_ranges() -> void:
	var cell_size: float = _cell_size()
	for tower: Dictionary in combat_towers:
		if int(tower["id"]) != selected_tower_id:
			continue
		var tower_cell: Vector2i = tower["cell"]
		var tower_range: float = float(tower_types[tower["type_id"]]["range"])
		for y: int in range(layout.dimensions.y):
			for x: int in range(layout.dimensions.x):
				var cell := Vector2i(x, y)
				if MatchCombat.cell_in_range(tower_cell, cell, tower_range):
					var rect := Rect2(cell_center(cell) - Vector2.ONE * (cell_size * 0.5 - 2.0),
						Vector2.ONE * (cell_size - 4.0))
					draw_rect(rect, Color(0.71, 0.89, 0.72, 0.07))
					draw_rect(rect, Color(0.71, 0.89, 0.72, 0.25), false, 1.0)
		var foot: Vector2 = cell_center(tower_cell) + Vector2(0, cell_size * 0.28)
		draw_arc(foot, cell_size * 0.36, 0.0, TAU, 24, Color(0.79, 0.83, 0.59, 0.8), 1.5)


func _draw_hover() -> void:
	if not input_enabled or not layout.contains(_hover):
		return
	var type_id: StringName = _drag_placement_id if _drag_placement_id != &"" else placement_id
	if type_id == &"" and cell_click_mode:
		return
	var cell_size: float = _cell_size()
	var rect := Rect2(cell_center(_hover) - Vector2.ONE * (cell_size * 0.5 - 3.0), Vector2.ONE * (cell_size - 6.0))
	if type_id == &"":
		draw_rect(rect, Color(0.84, 0.88, 0.75, 0.6), false, 1.5)
		return
	var legal: bool = _placement_is_legal(_hover, String(type_id))
	var color := Color(0.68, 0.85, 0.62, 0.85) if legal else Color(0.87, 0.43, 0.35, 0.9)
	draw_rect(rect, Color(color, 0.10))
	draw_rect(rect, color, false, 2.0)
	if not legal:
		draw_line(rect.position + rect.size * 0.28, rect.position + rect.size * 0.72, color, 2.0)
		draw_line(rect.position + rect.size * Vector2(0.28, 0.72), rect.position + rect.size * Vector2(0.72, 0.28), color, 2.0)


func _cache_texture_bounds(texture: Texture2D) -> void:
	if texture == null or _texture_bounds.has(texture):
		return
	var image: Image = texture.get_image()
	_texture_bounds[texture] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, texture.get_size())


func _cache_slow_texture(texture: Texture2D) -> void:
	if texture == null or _slowed_enemy_textures.has(texture):
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	_enemy_hit_images[texture] = image
	var tinted: Image = image.duplicate()
	tinted.convert(Image.FORMAT_RGBA8)
	for y: int in range(tinted.get_height()):
		for x: int in range(tinted.get_width()):
			var pixel: Color = tinted.get_pixel(x, y)
			if pixel.a > 0.0:
				tinted.set_pixel(x, y, pixel.lerp(Color(0.40, 0.68, 0.91, pixel.a), 0.38))
	_slowed_enemy_textures[texture] = ImageTexture.create_from_image(tinted)


func _sprite_rect(texture: Texture2D, height: float, anchor: Vector2, foot: Vector2, flip: bool = false) -> Rect2:
	_cache_texture_bounds(texture)
	var bounds: Rect2 = _texture_bounds[texture]
	var sprite_size: Vector2 = texture.get_size() * (_cell_size() * height / maxf(1.0, bounds.size.y))
	var displayed_anchor := Vector2(1.0 - anchor.x, anchor.y) if flip else anchor
	return Rect2(foot - sprite_size * displayed_anchor, sprite_size)


func visual_headroom() -> float:
	# Camera fitting uses the same opaque-height/anchor geometry as drawing.
	var foot := Vector2(0.0, _cell_size() * 0.78)
	var headroom: float = 0.0
	for reward: TowerReward in tower_catalog:
		if reward.icon_texture == null:
			continue
		var rect: Rect2 = _sprite_rect(reward.icon_texture, reward.board_height, reward.board_anchor, foot)
		var bounds: Rect2 = _texture_bounds[reward.icon_texture]
		var top: float = rect.position.y + bounds.position.y * rect.size.y / reward.icon_texture.get_height()
		headroom = maxf(headroom, -top)
	for artwork: EnemyDefinition in _enemy_art.values():
		var rect: Rect2 = _sprite_rect(artwork.texture, artwork.board_height, artwork.board_anchor, foot)
		var bounds: Rect2 = _texture_bounds[artwork.texture]
		var top: float = rect.position.y + bounds.position.y * rect.size.y / artwork.texture.get_height()
		headroom = maxf(headroom, -top + maxf(3.0, _cell_size() * 0.055) + 3.0)
	return ceilf(headroom + 6.0)


func _rebuild_draw_order() -> void:
	_draw_order.clear()
	_draw_order.append({"kind": 0, "entrance": true, "cell": Vector2i.ZERO, "foot": Vector2.ZERO})
	_draw_order.append({"kind": 0, "entrance": false, "cell": Vector2i.ZERO, "foot": Vector2.ZERO})
	for tower: Dictionary in combat_towers:
		_draw_order.append({"kind": 1, "data": tower, "foot": Vector2.ZERO})
	for enemy: Dictionary in combat_enemies:
		_draw_order.append({"kind": 2, "data": enemy, "foot": Vector2.ZERO, "progress": 0.0})


func _depth_before(a: Dictionary, b: Dictionary) -> bool:
	if a["foot"].y != b["foot"].y:
		return a["foot"].y < b["foot"].y
	if a["foot"].x != b["foot"].x:
		return a["foot"].x < b["foot"].x
	if int(a["kind"]) != int(b["kind"]):
		return int(a["kind"]) < int(b["kind"])
	# Deterministic ties prevent overlapping enemies flickering between snapshots.
	return int(a["data"]["id"]) < int(b["data"]["id"]) if int(a["kind"]) != 0 else false


func _update_draw_order() -> void:
	var cell_size: float = _cell_size()
	for item: Dictionary in _draw_order:
		var center: Vector2
		match int(item["kind"]):
			0:
				item["cell"] = layout.entrance if bool(item["entrance"]) else layout.base
				center = cell_center(item["cell"])
			1:
				center = cell_center(item["data"]["cell"])
			2:
				var enemy: Dictionary = item["data"]
				var progress: float = _enemy_route_progress(enemy)
				item["progress"] = progress
				center = _position_center(_enemy_visual_position(enemy))
		item["foot"] = center + Vector2(0, cell_size * 0.28)
	_draw_order.sort_custom(_depth_before)


func _draw_combat() -> void:
	_update_draw_order()
	var cell_size: float = _cell_size()
	# All contact shadows belong to the ground, not in front of foreground units.
	for item: Dictionary in _draw_order:
		var width: float = cell_size * 0.35
		if int(item["kind"]) == 2:
			var artwork: EnemyDefinition = _enemy_art[item["data"]["type_id"]]
			width = cell_size * artwork.board_height * 0.26
		draw_set_transform(item["foot"], 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, width, Color(0.06, 0.10, 0.07, 0.35))
	draw_set_transform(Vector2.ZERO)
	for item: Dictionary in _draw_order:
		if int(item["kind"]) != 1 or item["data"].get("evolution", "") != "boulders":
			continue
		for index: int in range(3):
			var offset: Vector2 = _boulder_offset(item["data"], index)
			var shadow: Vector2 = item["foot"] + Vector2(offset.x, offset.y * 0.5)
			draw_set_transform(shadow, 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, cell_size * 0.12, Color(0.06, 0.10, 0.07, 0.24))
	draw_set_transform(Vector2.ZERO)
	for item: Dictionary in _draw_order:
		match int(item["kind"]):
			0:
				var texture: Texture2D = _portal_texture if item["cell"] == layout.entrance else _crystal_texture
				draw_texture_rect(texture, _sprite_rect(texture, 1.05, Vector2(0.5, 0.97), item["foot"]), false)
			1:
				var tower: Dictionary = item["data"]
				var artwork: TowerReward = _tower_art.get(tower["type_id"])
				if tower.get("evolution", "") == "boulders":
					_draw_boulders(tower, item["foot"], false)
				if artwork != null and artwork.icon_texture != null:
					var rect: Rect2 = _sprite_rect(artwork.icon_texture, artwork.board_height, artwork.board_anchor, item["foot"])
					draw_texture_rect(artwork.icon_texture, rect, false)
					if tower["type_id"] == "arrow_tower" and bool(tower.get("special_upgraded", false)) and artwork.icon_texture == ARROW_ART.icon_texture:
						# Reuse the original archer pixels locally; the source texture stays untouched.
						var art_scale: Vector2 = rect.size / artwork.icon_texture.get_size()
						var second_rect := Rect2(rect.position + (ARCHER_CROP.position + SECOND_ARCHER_OFFSET) * art_scale,
							ARCHER_CROP.size * art_scale)
						draw_texture_rect_region(artwork.icon_texture, second_rect, ARCHER_CROP)
				match String(tower.get("evolution", "")):
					"boulders":
						_draw_boulders(tower, item["foot"], true)
					"onyx_ring":
						# A faceted keystone identifies the branch while its pulse is idle.
						_draw_rune_stone(item["foot"] + Vector2(0, -cell_size * 0.54), cell_size * 0.13, 0.0, true)
			2:
				_draw_enemy(item)
	# Bars are an information overlay; foreground bodies must not cover them.
	for item: Dictionary in _draw_order:
		if int(item["kind"]) == 2:
			if int(item["data"]["id"]) == selected_enemy_id:
				_draw_enemy_selection(item)
			_draw_enemy_health(item)


func _boulder_offset(tower: Dictionary, index: int) -> Vector2:
	var angle: float = _boulder_phase + float(index) * TAU / 3.0 + float(int(tower["id"]) % 17) * 0.37
	return Vector2(cos(angle) * (-1.0 if mirror_horizontal else 1.0) * 0.51, sin(angle) * 0.20) * _cell_size()


func _draw_boulders(tower: Dictionary, foot: Vector2, front: bool) -> void:
	# The orbit is cosmetic, not a contact/range boundary or a damage event.
	for index: int in range(3):
		var offset: Vector2 = _boulder_offset(tower, index)
		if (offset.y >= 0.0) != front:
			continue
		_draw_rune_stone(foot + offset + Vector2(0, -_cell_size() * 0.46),
			_cell_size() * 0.14, _boulder_phase * 0.35 + index, false, 1.0, bool(tower.get("freeze_upgraded", false)))


func _draw_rune_stone(position: Vector2, radius: float, rotation: float, onyx: bool, alpha: float = 1.0, frozen: bool = false) -> void:
	var stone := Color("1c1b27") if onyx else (Color("7193a4") if frozen else Color("716b5d"))
	var edge := Color("8e859e") if onyx else (Color("c2e5ed") if frozen else Color("c1b496"))
	var rune := Color("514a64") if onyx else (Color("92c5d9") if frozen else Color("978a70"))
	draw_set_transform(position, rotation, Vector2.ONE * radius)
	draw_colored_polygon(_rune_stone_shape, Color(stone, alpha))
	draw_line(_rune_stone_shape[0], _rune_stone_shape[1], Color(edge, alpha), 0.12, true)
	draw_line(_rune_stone_shape[1], _rune_stone_shape[2], Color(edge, alpha), 0.12, true)
	draw_line(_rune_stone_shape[1], Vector2(0.10, 0.05), Color(rune, alpha), 0.10, true)
	draw_line(Vector2(0.10, 0.05), _rune_stone_shape[4], Color(rune, alpha), 0.10, true)
	draw_set_transform(Vector2.ZERO)


func _draw_enemy(item: Dictionary) -> void:
	var enemy: Dictionary = item["data"]
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], item["progress"]) != artwork.source_faces_left
	var rect: Rect2 = _sprite_rect(artwork.texture, artwork.board_height, artwork.board_anchor, item["foot"], flip)
	if flip:
		rect.size.x = -rect.size.x
	var texture: Texture2D = _slowed_enemy_textures.get(artwork.texture, artwork.texture) if bool(enemy.get("slowed", false)) else artwork.texture
	draw_texture_rect(texture, rect, false)


func _enemy_sprite_bounds(enemy: Dictionary, foot: Vector2, progress: float) -> Rect2:
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], progress) != artwork.source_faces_left
	var rect: Rect2 = _sprite_rect(artwork.texture, artwork.board_height, artwork.board_anchor, foot, flip)
	var bounds: Rect2 = _texture_bounds[artwork.texture]
	if flip:
		bounds.position.x = artwork.texture.get_width() - bounds.end.x
	var scale: Vector2 = rect.size / artwork.texture.get_size()
	return Rect2(rect.position + bounds.position * scale, bounds.size * scale)


func _enemy_contains_point(enemy: Dictionary, foot: Vector2, progress: float, position: Vector2) -> bool:
	if not _enemy_sprite_bounds(enemy, foot, progress).has_point(position):
		return false
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], progress) != artwork.source_faces_left
	var rect: Rect2 = _sprite_rect(artwork.texture, artwork.board_height, artwork.board_anchor, foot, flip)
	var uv: Vector2 = (position - rect.position) / rect.size
	if flip:
		uv.x = 1.0 - uv.x
	if not _enemy_hit_images.has(artwork.texture):
		_enemy_hit_images[artwork.texture] = artwork.texture.get_image()
	var image: Image = _enemy_hit_images[artwork.texture]
	var pixel := Vector2i(uv * Vector2(image.get_size()))
	pixel = pixel.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(pixel).a >= 0.1


func _draw_enemy_selection(item: Dictionary) -> void:
	var rect: Rect2 = _enemy_sprite_bounds(item["data"], item["foot"], item["progress"]).grow(3.0)
	var color := Color("e0bc77")
	var corner: float = minf(7.0, rect.size.x * 0.25)
	for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction := Vector2(1.0 if point.x == rect.position.x else -1.0, 1.0 if point.y == rect.position.y else -1.0)
		draw_line(point, point + Vector2(direction.x * corner, 0), color, 2.0)
		draw_line(point, point + Vector2(0, direction.y * corner), color, 2.0)


func _draw_enemy_health(item: Dictionary) -> void:
	var enemy: Dictionary = item["data"]
	if float(enemy["hp"]) >= float(enemy["max_hp"]):
		return
	var bounds: Rect2 = _enemy_sprite_bounds(enemy, item["foot"], item["progress"])
	var bar_size := Vector2(clampf(bounds.size.x * 0.85, _cell_size() * 0.22, _cell_size() * 0.38),
		maxf(2.0, _cell_size() * 0.04))
	var bar_position := Vector2(item["foot"].x - bar_size.x * 0.5, bounds.position.y - bar_size.y - 3.0)
	draw_rect(Rect2(bar_position, bar_size), Color("172120"))
	var fraction: float = clampf(float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"])), 0.0, 1.0)
	draw_rect(Rect2(bar_position, Vector2(bar_size.x * fraction, bar_size.y)), Color("8bac77"))


func _draw_attacks() -> void:
	var cell_size: float = _cell_size()
	for trace: Dictionary in _shot_traces:
		var remaining: float = clampf(float(trace["life"]) / float(trace["duration"]), 0.0, 1.0)
		if bool(trace["area_attack"]):
			var onyx: bool = trace.get("evolution", "") == "onyx_ring"
			if onyx:
				_draw_onyx_pulse(trace, remaining)
			# Both discrete Rune attacks communicate the actual neighborhood footprint.
			for y: int in range(layout.dimensions.y):
				for x: int in range(layout.dimensions.x):
					var cell := Vector2i(x, y)
					if not MatchCombat.cell_in_range(trace["cell"], cell, float(trace["range"])):
						continue
					var center: Vector2 = cell_center(cell)
					draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.43, Vector2.ONE * cell_size * 0.86),
						Color(0.64, 0.55, 0.76, 0.10 * remaining) if onyx else Color(0.55, 0.66, 0.87, 0.06 * remaining))
			for hit: Vector2 in trace["hits"]:
				var foot: Vector2 = _position_center(hit) + Vector2(0, cell_size * 0.28)
				draw_line(foot + Vector2(-cell_size * 0.10, 2), foot + Vector2(cell_size * 0.10, -4),
					Color(0.85, 0.75, 0.95, remaining) if onyx else Color(0.73, 0.79, 0.96, remaining), 2.0)


func _draw_onyx_pulse(trace: Dictionary, remaining: float) -> void:
	var foot: Vector2 = cell_center(trace["cell"]) + Vector2(0, _cell_size() * 0.28)
	var radius: float = _cell_size() * lerpf(0.30, 1.25, 1.0 - remaining)
	# An expanding, fading stone ring exists only for a captured discrete shot.
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.10, 0.08, 0.15, remaining * 0.9), _cell_size() * 0.07, true)
	draw_arc(Vector2.ZERO, radius - 2.0, 0.0, TAU, 32, Color(0.65, 0.58, 0.76, remaining * 0.65), 1.0, true)
	draw_set_transform(Vector2.ZERO)
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0
		var offset := Vector2(cos(angle), sin(angle) * 0.55) * radius
		_draw_rune_stone(foot + offset, _cell_size() * 0.075, angle, true, remaining)


func _projectile_origin(trace: Dictionary) -> Vector2:
	var cell_size: float = _cell_size()
	if trace["type_id"] == "arrow_tower":
		var artwork: TowerReward = _tower_art.get("arrow_tower")
		if artwork != null and artwork.icon_texture == ARROW_ART.icon_texture:
			var foot: Vector2 = cell_center(trace["cell"]) + Vector2(0, cell_size * 0.28)
			var rect: Rect2 = _sprite_rect(artwork.icon_texture, artwork.board_height, artwork.board_anchor, foot)
			var bow: Vector2 = ARCHER_BOW + (SECOND_ARCHER_OFFSET if bool(trace["secondary"]) else Vector2.ZERO)
			return rect.position + bow * rect.size / artwork.icon_texture.get_size()
	return cell_center(trace["cell"]) + Vector2(0, -cell_size * 0.30)


func _projectile_position(trace: Dictionary) -> Vector2:
	var elapsed: float = float(trace["duration"]) - float(trace["life"])
	var primary: Vector2 = _position_center(trace["aim"]) + Vector2(0, _cell_size() * 0.15)
	if bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION:
		var bounce: Vector2 = _position_center(trace["bounce_aim"]) + Vector2(0, _cell_size() * 0.15)
		return primary.lerp(bounce, clampf((elapsed - SHOT_DURATION) / SHOT_DURATION, 0.0, 1.0))
	return _projectile_origin(trace).lerp(primary, clampf(elapsed / SHOT_DURATION, 0.0, 1.0))


func _draw_projectiles() -> void:
	var cell_size: float = _cell_size()
	for trace: Dictionary in _shot_traces:
		if bool(trace["area_attack"]):
			continue
		var position: Vector2 = _projectile_position(trace)
		var elapsed: float = float(trace["duration"]) - float(trace["life"])
		var end: Vector2 = _position_center(trace["aim"]) + Vector2(0, cell_size * 0.15)
		var start: Vector2 = _projectile_origin(trace)
		if bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION:
			start = end
			end = _position_center(trace["bounce_aim"]) + Vector2(0, cell_size * 0.15)
		var direction: Vector2 = (end - start).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var side := Vector2(-direction.y, direction.x)
		var heavy: bool = trace["type_id"] == "orc_ballista"
		var length: float = cell_size * (0.26 if heavy else 0.18)
		var width: float = 2.0 if heavy else 1.3
		var tail: Vector2 = position - direction * length * 0.5
		var tip: Vector2 = position + direction * length * 0.5
		draw_line(tail, tip, Color("b9a575"), width, true)
		draw_line(tip, tip - direction * length * 0.32 + side * length * 0.22, Color("e8e3c9"), width, true)
		draw_line(tip, tip - direction * length * 0.32 - side * length * 0.22, Color("e8e3c9"), width, true)
		draw_line(tail, tail + direction * length * 0.25 + side * length * 0.18, Color("d3cbab"), width, true)
		draw_line(tail, tail + direction * length * 0.25 - side * length * 0.18, Color("d3cbab"), width, true)
