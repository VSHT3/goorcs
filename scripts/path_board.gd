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
const PIERCE_SHOT_DURATION: float = SHOT_DURATION * 2.0
const PULSE_DURATION: float = 0.14
const BOMB_IMPACT_DURATION: float = 0.28
const THROW_FLIGHT_DURATION: float = 0.40
const ROCKET_FLIGHT_DURATION: float = 0.30
const ROCKET_IMPACT_DURATION: float = 0.48
const MAX_SHOT_TRACES: int = 256
const ENEMY_LATERAL_SPREAD: float = 0.10
const ENEMY_CORNER_BLEND: float = 0.25
const ENDPOINT_FRAME_SIZE: int = 96
const ENDPOINT_FRAME_COUNT: int = 16
const ENDPOINT_FRAME_SECONDS: float = 0.2
const ONYX_PULSE_DURATION: float = 0.30
const BOULDER_ORBIT_SPEED: float = 1.8
const CORPSE_LIFETIME: float = 1.8
const BLOOD_DROPS := [Vector2(-3, 0), Vector2(-1, 1), Vector2(0, 0), Vector2(1, -1), Vector2(2, 1), Vector2(4, 0), Vector2(-2, -2)]
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
var content_catalog: ContentCatalog = preload("res://resources/content_catalog.tres"):
	set(value):
		content_catalog = value
		_tower_art.clear()
		_enemy_art.clear()
		_directional_framing.clear()
		_directional_canvas_sizes.clear()
		for definition: TowerDefinition in value.towers:
			var reward: TowerReward = definition.reward
			_tower_art[String(reward.id)] = reward
			_cache_tower_art(reward)
		for definition: EnemyDefinition in value.enemies:
			_enemy_art[String(definition.id)] = definition
			_cache_texture_bounds(definition.texture)
			_cache_status_textures(definition.texture)
			if definition.animation_frames != null:
				for animation: StringName in definition.animation_frames.get_animation_names():
					for frame: int in range(definition.animation_frames.get_frame_count(animation)):
						var texture: Texture2D = definition.animation_frames.get_frame_texture(animation, frame)
						_cache_texture_bounds(texture)
						_cache_status_textures(texture)
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
var _archer_poses: Dictionary[Vector2i, Dictionary] = {}
var _has_archer_motion: bool = false
var _shot_traces: Array[Dictionary] = []
var _has_boulders: bool = false
var _has_idle_flames: bool = false
var _flame_elapsed: float = 0.0
var _boulder_phase: float = 0.0
var _enemy_progress: Dictionary[int, Vector2] = {}
var _enemies_by_id: Dictionary[int, Dictionary] = {}
var _enemy_blend_elapsed: float = ENEMY_BLEND_DURATION
var _bounty_health: Dictionary[int, float] = {}
var _bounty_hit_life: Dictionary[int, float] = {}
var _tower_art: Dictionary[String, TowerReward] = {}
var _texture_bounds: Dictionary[Texture2D, Rect2] = {}
var _directional_framing: Dictionary[TowerReward, Vector2] = {}
var _directional_canvas_sizes: Dictionary[TowerReward, Vector2] = {}
var _draw_order: Array[Dictionary] = []
var _drag_placement_id: StringName = &""
var _drag_clip: Control
var _drag_ghost: PathBoard
var _enemy_art: Dictionary[String, EnemyDefinition] = {}
var _slowed_enemy_textures: Dictionary[Texture2D, Texture2D] = {}
var _burning_enemy_textures: Dictionary[Texture2D, Texture2D] = {}
var _corpse_traces: Array[Dictionary] = []
var _death_match_id: String = ""
var _death_generation: int = -1
var _last_death_id: int = 0
var _corpse_speed: float = 1.0
var _corpse_paused: bool = false
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
	content_catalog = content_catalog
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
		cancel_stroke()
	_sync_combat_animation()


func _advance_endpoints() -> void:
	_endpoint_frame = (_endpoint_frame + 1) % ENDPOINT_FRAME_COUNT
	# Mutate only the atlas regions; cached framing stays fixed for the whole loop.
	_portal_texture.region.position.x = _endpoint_frame * ENDPOINT_FRAME_SIZE
	_crystal_texture.region.position.x = _endpoint_frame * ENDPOINT_FRAME_SIZE
	queue_redraw()

func _sync_combat_animation() -> void:
	set_process(is_visible_in_tree() and (_has_boulders or _has_idle_flames or _has_archer_motion or not combat_enemies.is_empty() or not _shot_traces.is_empty() or not _corpse_traces.is_empty()))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var visual_delta: float = 0.0 if _corpse_paused else delta * _corpse_speed
	if _has_idle_flames:
		_flame_elapsed = fposmod(_flame_elapsed + visual_delta, 12.0)
	if _has_boulders:
		_boulder_phase = fposmod(_boulder_phase + visual_delta * BOULDER_ORBIT_SPEED, TAU)
	_has_archer_motion = false
	for pose: Dictionary in _archer_poses.values():
		var interval: float = maxf(0.14, float(pose["interval"]))
		pose["age"] = minf(float(pose["age"]) + visual_delta, interval)
		_has_archer_motion = _has_archer_motion or float(pose["age"]) < interval
	_enemy_blend_elapsed = minf(_enemy_blend_elapsed + delta, ENEMY_BLEND_DURATION)
	for id: int in _bounty_hit_life.keys():
		var life: float = _bounty_hit_life[id] - visual_delta
		if life <= 0.0:
			_bounty_hit_life.erase(id)
		else:
			_bounty_hit_life[id] = life
	for index: int in range(_shot_traces.size() - 1, -1, -1):
		_shot_traces[index]["life"] -= visual_delta
		if float(_shot_traces[index]["life"]) <= 0.0:
			_shot_traces.remove_at(index)
	var expired: bool = false
	if not _corpse_paused:
		for index: int in range(_corpse_traces.size() - 1, -1, -1):
			_corpse_traces[index]["age"] += delta * _corpse_speed
			if float(_corpse_traces[index]["age"]) >= CORPSE_LIFETIME:
				_corpse_traces.remove_at(index)
				expired = true
	if expired:
		_rebuild_draw_order()
	queue_redraw()
	_sync_combat_animation()

func apply_deaths(state: Dictionary, slot: int, speed: float = 1.0, paused: bool = false) -> void:
	var match_id: String = state.get("statistics_id", "")
	var generation: int = int(state.get("death_generation", 0))
	if match_id != _death_match_id or generation != _death_generation:
		_corpse_traces.clear()
		_last_death_id = 0
		_death_match_id = match_id
		_death_generation = generation
	_corpse_speed = maxf(0.0, speed)
	_corpse_paused = paused
	var clock: float = float(state.get("death_time", 0.0))
	for index: int in range(_corpse_traces.size() - 1, -1, -1):
		var trace: Dictionary = _corpse_traces[index]
		trace["age"] = maxf(float(trace["age"]), clock - float(trace["time"]))
		if float(trace["age"]) >= CORPSE_LIFETIME:
			_corpse_traces.remove_at(index)
	var deaths: Array = state.get("deaths", [[], []])
	if slot >= 0 and slot < deaths.size():
		for event: Dictionary in deaths[slot]:
			var id: int = int(event["id"])
			if id <= _last_death_id:
				continue
			_last_death_id = id
			var age: float = maxf(0.0, clock - float(event["time"]))
			if age >= CORPSE_LIFETIME or not _enemy_art.has(event["type_id"]):
				continue
			var trace: Dictionary = event.duplicate()
			trace["age"] = age
			_corpse_traces.append(trace)
	_rebuild_draw_order()
	_sync_combat_animation()
	queue_redraw()



func _capture_shots() -> void:
	_has_boulders = false
	_has_idle_flames = false
	var active_archers: Dictionary[Vector2i, bool] = {}
	if combat_towers.is_empty():
		_seen_shots.clear()
		_shot_traces.clear()
		_archer_poses.clear()
		_has_archer_motion = false
		_sync_combat_animation()
		return
	for tower: Dictionary in combat_towers:
		var definition: Dictionary = tower_types.get(tower["type_id"], {})
		var boulders: bool = tower.get("evolution", "") == "boulders"
		_has_boulders = _has_boulders or boulders or tower.get("evolution", "") == "onyx_ring"
		var advancement: Dictionary = _archer_advancement(tower, definition)
		var weapon: String = advancement.get("weapon", "arrow")
		_has_idle_flames = _has_idle_flames or float(advancement.get("burn_dps", 0.0)) > 0.0 or weapon == "minigun"
		var archer_count: int = int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) and definition.get("special_upgrade", "") == "second_archer" else 1))
		_capture_archer(tower, definition, 0, int(tower.get("shot", 0)), tower.get("aim", Vector2(tower["cell"])), not boulders and weapon != "flamethrower")
		active_archers[Vector2i(int(tower["id"]), 0)] = true
		if archer_count > 1:
			_capture_archer(tower, definition, 1, int(tower.get("secondary_shot", 0)), tower.get("secondary_aim", Vector2(tower["cell"])))
			active_archers[Vector2i(int(tower["id"]), 1)] = true
		var extras: Array = tower.get("extra_archers", [])
		for index: int in range(mini(extras.size(), maxi(0, archer_count - 2))):
			var archer: Dictionary = extras[index]
			_capture_archer(tower, definition, index + 2, int(archer.get("shot", 0)), archer.get("aim", Vector2(tower["cell"])))
			active_archers[Vector2i(int(tower["id"]), index + 2)] = true
	for key: Vector2i in _archer_poses.keys():
		if not active_archers.has(key):
			_archer_poses.erase(key)
	for key: Vector2i in _seen_shots.keys():
		if not active_archers.has(key):
			_seen_shots.erase(key)
	for index: int in range(_shot_traces.size() - 1, -1, -1):
		if not active_archers.has(Vector2i(int(_shot_traces[index].get("tower_id", -1)), 0)):
			_shot_traces.remove_at(index)
	_has_archer_motion = false
	for pose: Dictionary in _archer_poses.values():
		_has_archer_motion = _has_archer_motion or float(pose["age"]) < maxf(0.14, float(pose["interval"]))


func _archer_advancement(tower: Dictionary, definition: Dictionary) -> Dictionary:
	return definition.get("advancements", {}).get(tower.get("advancement", ""), {})

func _tower_variant(tower: Dictionary, artwork: TowerReward) -> Dictionary:
	var advancement: String = tower.get("advancement", "")
	return artwork.board_variant(advancement if not advancement.is_empty() else tower.get("evolution", ""), tower.get("followup", ""))



func _capture_archer(tower: Dictionary, definition: Dictionary, archer_index: int, shot: int, aim: Vector2, visible_shot: bool = true) -> void:
	var key := Vector2i(int(tower["id"]), archer_index)
	var artwork: TowerReward = _tower_art.get(tower["type_id"])
	var rigged: bool = artwork != null and artwork.archer_head_texture != null
	var interval: float = maxf(0.02, float(tower.get("interval", definition.get("interval", 0.8))))
	var pose: Dictionary = _archer_poses.get(key, {"age": maxf(0.14, interval), "interval": interval})
	var advancement: String = tower.get("advancement", "")
	if pose.get("advancement", "") != advancement:
		pose["age"] = maxf(0.14, interval)
	pose["advancement"] = advancement
	pose["interval"] = interval
	if shot < int(_seen_shots.get(key, 0)):
		# A reset counter is a new presentation generation, never a new attack.
		pose["age"] = maxf(0.14, interval)
		for index: int in range(_shot_traces.size() - 1, -1, -1):
			var trace: Dictionary = _shot_traces[index]
			if int(trace.get("tower_id", -1)) == key.x and int(trace["archer_index"]) == key.y:
				_shot_traces.remove_at(index)
	if shot > int(_seen_shots.get(key, 0)) and visible_shot:
		var count: int = mini(4, shot - int(_seen_shots.get(key, 0))) if _archer_advancement(tower, definition).get("weapon", "arrow") == "minigun" else 1
		for index: int in range(count):
			_capture_attack(tower, definition, archer_index, aim, float(index) * interval)
		if rigged:
			pose["age"] = 0.0
	elif rigged and shot > 0 and tower.has("cooldown"):
		pose["age"] = maxf(float(pose["age"]), interval - float(tower["cooldown"]))
	if rigged:
		_archer_poses[key] = pose
	_seen_shots[key] = shot


func _capture_attack(tower: Dictionary, definition: Dictionary, archer_index: int, aim: Vector2, initial_age: float = 0.0) -> void:
	var area_attack: bool = bool(definition.get("area_attack", false))
	var chain: bool = tower.get("behavior_kind", definition.get("behavior_kind", "attack")) == "chain"
	var pierce: bool = archer_index == 0 and bool(tower.get("pierce_active", false))
	var bounce: bool = archer_index == 0 and not pierce and bool(tower.get("bounce_active", false))
	var evolution: String = tower.get("evolution", "")
	var duration: float = (ONYX_PULSE_DURATION if evolution == "onyx_ring" else PULSE_DURATION) if area_attack else SHOT_DURATION * (2.0 if bounce else 1.0)
	if pierce:
		duration = PIERCE_SHOT_DURATION
	var advancement: Dictionary = _archer_advancement(tower, definition)
	var weapon: String = advancement.get("weapon", "arrow")
	if weapon == "flamethrower":
		return
	var flight: float = THROW_FLIGHT_DURATION if weapon in ["molotov", "grenade"] else (ROCKET_FLIGHT_DURATION if weapon == "rocket" else SHOT_DURATION)
	if weapon != "arrow" and weapon != "minigun":
		duration = flight
	var impact: float = ROCKET_IMPACT_DURATION if weapon == "rocket" else BOMB_IMPACT_DURATION
	var splash_radius: float = float(advancement.get("splash_radius", 0.0))
	if splash_radius > 0.0:
		duration += impact
	var hits: Array[Vector2] = []
	if area_attack:
		for enemy: Dictionary in combat_enemies:
			if MatchCombat.cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), float(tower.get("range", definition.get("range", 0.0)))):
				hits.append(enemy["pos"])
	# Copy accepted positions, including lethal hits whose enemies already disappeared.
	var artwork: TowerReward = _tower_art.get(tower["type_id"])
	var directional: bool = artwork != null and not artwork.directional_weapon_textures.is_empty()
	var origin: Vector2 = _tower_muzzle(tower, archer_index, directional)
	if not directional and artwork != null and artwork.archer_head_texture != null:
		origin = _archer_geometry(tower, archer_index, 1.0)["tip"]
	var origin_offset: Vector2 = (origin - cell_center(tower["cell"])) / _cell_size()
	if mirror_horizontal:
		origin_offset.x = -origin_offset.x
	_shot_traces.append({
		"cell": tower["cell"],
		"tower_id": tower["id"],
		"type_id": tower["type_id"],
		"evolution": evolution,
		"advancement": tower.get("advancement", ""),
		"weapon": weapon,
		"flight_duration": flight,
		"impact_duration": impact,
		"aim": aim,
		"archer_index": archer_index,
		"origin_offset": origin_offset,
		"burning": float(advancement.get("burn_dps", 0.0)) > 0.0,
		"splash_radius": splash_radius,
		"pierce_active": pierce,
		"pierce_aim": tower.get("pierce_aim", tower.get("aim", Vector2(tower["cell"]))),
		"bounce_active": bounce,
		"bounce_aim": tower.get("bounce_aim", tower.get("aim", Vector2(tower["cell"]))),
		"life": maxf(0.001, duration - initial_age),
		"duration": duration,
		"area_attack": area_attack,
		"chain": chain,
		"chain_points": tower.get("chain_points", []).duplicate(),
		"range": float(tower.get("range", definition.get("range", 0.0))),
		"hits": hits,
	})
	if _shot_traces.size() > MAX_SHOT_TRACES:
		_shot_traces.pop_front()
	_sync_combat_animation()


func _blend_enemies() -> void:
	var next_progress: Dictionary[int, Vector2] = {}
	var next_health: Dictionary[int, float] = {}
	_enemies_by_id.clear()
	for enemy: Dictionary in combat_enemies:
		var id: int = int(enemy["id"])
		_enemies_by_id[id] = enemy
		var hp: float = float(enemy["hp"])
		if int(enemy.get("bounty_tower_id", -1)) >= 0 and float(enemy.get("bounty_damage_bonus", 0.0)) > 0.0 and hp < _bounty_health.get(id, hp):
			_bounty_hit_life[id] = 0.18
		next_health[id] = hp
		var target: float = float(enemy["progress"])
		var previous: Vector2 = _enemy_progress.get(id, Vector2(target, target))
		var displayed: float = lerpf(previous.x, previous.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
		next_progress[id] = Vector2(displayed, target)
	_enemy_progress = next_progress
	_bounty_health = next_health
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
		clear_drag_preview()
		return false
	if not data is Dictionary or not data.get("tower_type") is String:
		clear_drag_preview()
		return false
	var type_id: String = data["tower_type"]
	var cell: Vector2i = _cell_at(at_position)
	if not tower_types.has(type_id) or not layout.contains(cell):
		clear_drag_preview()
		return false
	if _drag_placement_id != StringName(type_id) or _hover != cell:
		_drag_placement_id = StringName(type_id)
		_hover = cell
		queue_redraw()
	return _placement_is_legal(cell, type_id)


func clear_drag_preview() -> void:
	if _drag_placement_id != &"":
		_drag_placement_id = &""
		_hover = Vector2i(-1, -1)
		queue_redraw()
	if is_instance_valid(_drag_clip):
		_drag_clip.hide()


func _has_drag_preview() -> bool:
	return input_enabled and placement_enabled and layout != null and layout.contains(_hover) and tower_types.has(String(_drag_placement_id))


func _sync_drag_preview() -> void:
	if not _has_drag_preview() or _cell_size() <= 0.0:
		if is_instance_valid(_drag_clip):
			_drag_clip.hide()
		return
	if not is_instance_valid(_drag_ghost):
		_drag_clip = Control.new()
		_drag_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_clip.clip_contents = true
		add_child(_drag_clip)
		# Runtime loading avoids a PathBoard/subclass preload cycle.
		_drag_ghost = load("res://scripts/tower_drag_ghost.gd").new()
		_drag_clip.add_child(_drag_ghost)
	_drag_clip.position = _board_origin()
	_drag_clip.size = Vector2(layout.dimensions) * _cell_size()
	_drag_ghost.position = -_drag_clip.position
	_drag_ghost.call(&"configure", self)
	_drag_clip.show()


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
	clear_drag_preview()
	_hover = Vector2i(-1, -1)
	_last_painted = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	_sync_drag_preview()
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
	if _has_drag_preview():
		_draw_tile_range(_hover, float(tower_types[String(_drag_placement_id)]["range"]))
		return
	for tower: Dictionary in combat_towers:
		if int(tower["id"]) == selected_tower_id:
			_draw_tile_range(tower["cell"], float(tower.get("range", tower_types[tower["type_id"]]["range"])))


func _draw_tile_range(tower_cell: Vector2i, tower_range: float) -> void:
	var cell_size: float = _cell_size()
	for y: int in range(layout.dimensions.y):
		for x: int in range(layout.dimensions.x):
			var cell := Vector2i(x, y)
			if MatchCombat.cell_in_range(tower_cell, cell, tower_range):
				var rect := Rect2(cell_center(cell) - Vector2.ONE * (cell_size * 0.5 - 2.0),
					Vector2.ONE * (cell_size - 4.0))
				draw_rect(rect, Color(0.71, 0.89, 0.72, 0.07))
				draw_rect(rect, Color(0.71, 0.89, 0.72, 0.25), false, 1.0)


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


func _cache_status_textures(texture: Texture2D) -> void:
	if texture == null or _slowed_enemy_textures.has(texture):
		return
	_slowed_enemy_textures[texture] = EnemyVisuals.slowed_texture(texture)
	_burning_enemy_textures[texture] = EnemyVisuals.burning_texture(texture)


func _sprite_rect(texture: Texture2D, height: float, anchor: Vector2, foot: Vector2, flip: bool = false) -> Rect2:
	if texture == null:
		return Rect2(foot, Vector2.ZERO)
	_cache_texture_bounds(texture)
	var bounds: Rect2 = _texture_bounds[texture]
	var sprite_size: Vector2 = texture.get_size() * (_cell_size() * height / maxf(1.0, bounds.size.y))
	var displayed_anchor := Vector2(1.0 - anchor.x, anchor.y) if flip else anchor
	return Rect2(foot - sprite_size * displayed_anchor, sprite_size)


func _cache_tower_art(reward: TowerReward) -> void:
	_cache_texture_bounds(reward.icon_texture)
	if not reward.directional_weapon_textures.is_empty():
		_cache_texture_bounds(reward.board_texture)
		for texture: Texture2D in reward.directional_weapon_textures:
			_cache_texture_bounds(texture)
		# All layers share the icon's one framing, never their own alpha bounds.
		var canvas: Vector2 = reward.icon_texture.get_size()
		_directional_canvas_sizes[reward] = canvas
		_directional_framing[reward] = canvas / maxf(1.0, _texture_bounds[reward.icon_texture].size.y)
	for variant: Dictionary in reward.board_variants.values():
		_cache_texture_bounds(variant.get("texture"))


func _directional_weapon_rect(artwork: TowerReward, foot: Vector2) -> Rect2:
	var sprite_size: Vector2 = _directional_framing[artwork] * (_cell_size() * artwork.board_height)
	return Rect2(foot - sprite_size * artwork.board_anchor, sprite_size)


func _directional_weapon_index(tower: Dictionary, released: bool = false) -> int:
	var cell := Vector2(tower["cell"])
	var aim: Vector2 = tower.get("aim", cell) if released else tower.get("tracking_aim", cell)
	if not released:
		var target_id: int = int(tower.get("tracking_target_id", -1))
		if _enemies_by_id.has(target_id):
			var enemy: Dictionary = _enemies_by_id[target_id]
			var range_cells: float = float(tower.get("range", 0.0))
			if not tower.has("range") and tower_types.has(tower["type_id"]):
				range_cells = float(tower_types[tower["type_id"]].get("range", 0.0))
			if float(enemy["hp"]) > 0.0 and MatchCombat.cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), range_cells):
				# Logical interpolation deliberately excludes cosmetic lane jitter.
				aim = _enemy_position(enemy)
	var direction: Vector2 = aim - cell
	if direction.is_zero_approx():
		return 3 # No accepted aim yet: authored SE, on either board.
	if mirror_horizontal:
		direction.x = -direction.x
	# Clockwise sectors from north; exact half-sector boundaries turn clockwise.
	return posmod(floori((direction.angle() + PI * 0.5 + PI * 0.125) / (PI * 0.25)), 8)


func _tower_foot(cell: Vector2i) -> Vector2:
	# Put the front foundation edge near the tile's bottom, without a floating pad.
	return cell_center(cell) + Vector2(0, _cell_size() * 0.45)


func visual_headroom() -> float:
	# Retain conservative top-row clearance even with the lower tower foundations.
	var foot := Vector2(0.0, _cell_size() * 0.78)
	var headroom: float = 0.0
	for reward: TowerReward in _tower_art.values():
		if reward.icon_texture == null:
			continue
		var rect: Rect2 = _sprite_rect(reward.icon_texture, reward.board_height, reward.board_anchor, foot)
		var bounds: Rect2 = _texture_bounds[reward.icon_texture]
		var top: float = rect.position.y + bounds.position.y * rect.size.y / reward.icon_texture.get_height()
		headroom = maxf(headroom, -top)
		var scale: Vector2 = rect.size / reward.icon_texture.get_size()
		if not reward.directional_weapon_textures.is_empty():
			rect = _directional_weapon_rect(reward, foot)
			# Include the fixed base and every pose at the same icon-derived scale.
			var base_bounds: Rect2 = _texture_bounds[reward.board_texture]
			headroom = maxf(headroom, -(rect.position.y + base_bounds.position.y * scale.y))
			for texture: Texture2D in reward.directional_weapon_textures:
				var weapon_bounds: Rect2 = _texture_bounds[texture]
				headroom = maxf(headroom, -(rect.position.y + weapon_bounds.position.y * scale.y))
		if reward.archer_head_texture != null:
			# Upright heads and a fully vertical bow, including held fire/bomb tips.
			var offsets: Array[Vector2] = [Vector2.ZERO, reward.secondary_sprite_offset]
			for offset: Vector2 in reward.additional_archer_offsets:
				offsets.append(offset)
			for offset: Vector2 in offsets:
				headroom = maxf(headroom, -(rect.position.y + (reward.archer_pivot.y + offset.y - 25.0) * scale.y - 6.0))
		for variant: Dictionary in reward.board_variants.values():
			var texture: Texture2D = variant.get("texture")
			if texture == null:
				continue
			var variant_rect: Rect2 = _sprite_rect(texture, float(variant.get("board_height", reward.board_height)), variant.get("board_anchor", reward.board_anchor), foot)
			var variant_bounds: Rect2 = _texture_bounds[texture]
			var variant_top: float = variant_rect.position.y + variant_bounds.position.y * variant_rect.size.y / texture.get_height()
			headroom = maxf(headroom, -variant_top)
			if reward.archer_head_texture != null:
				var pivot: Vector2 = variant.get("archer_pivot", reward.archer_pivot)
				var variant_scale: float = variant_rect.size.y / texture.get_height()
				var offsets: PackedVector2Array = variant.get("additional_archer_offsets", reward.additional_archer_offsets)
				headroom = maxf(headroom, -(variant_rect.position.y + (pivot.y - 25.0) * variant_scale - 6.0))
				for offset: Vector2 in offsets:
					headroom = maxf(headroom, -(variant_rect.position.y + (pivot.y + offset.y - 25.0) * variant_scale - 6.0))
			if variant.has("portrait_bounds"):
				var equipment_bounds: Rect2 = variant["portrait_bounds"]
				headroom = maxf(headroom, -foot.y - equipment_bounds.position.y * _cell_size())
	for artwork: EnemyDefinition in _enemy_art.values():
		var texture: Texture2D = EnemyVisuals.frame_texture(artwork)
		var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, texture, _cell_size() * artwork.board_height, foot)
		var bounds: Rect2 = EnemyVisuals.union_bounds(artwork)
		var top: float = rect.position.y + bounds.position.y * rect.size.y / texture.get_height()
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
	for trace: Dictionary in _corpse_traces:
		_draw_order.append({"kind": 3, "data": trace, "foot": Vector2.ZERO})


func _depth_before(a: Dictionary, b: Dictionary) -> bool:
	if a["foot"].y != b["foot"].y:
		return a["foot"].y < b["foot"].y
	if a["foot"].x != b["foot"].x:
		return a["foot"].x < b["foot"].x
	if int(a["kind"]) != int(b["kind"]):
		# A fallen body belongs behind a live unit at the same feet position.
		var a_kind: int = -1 if int(a["kind"]) == 3 else int(a["kind"])
		var b_kind: int = -1 if int(b["kind"]) == 3 else int(b["kind"])
		return a_kind < b_kind
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
			3:
				center = _position_center(item["data"]["pos"])
		item["foot"] = _tower_foot(item["data"]["cell"]) if int(item["kind"]) == 1 else center + Vector2(0, cell_size * 0.28)
	_draw_order.sort_custom(_depth_before)


func _draw_combat() -> void:
	_update_draw_order()
	var cell_size: float = _cell_size()
	for trace: Dictionary in _corpse_traces:
		_draw_death_blood(trace, _position_center(trace["pos"]) + Vector2(0, cell_size * 0.28))
	# Buildings sit directly on their foundations; only units/endpoints cast ovals.
	for item: Dictionary in _draw_order:
		if int(item["kind"]) == 1:
			continue
		var width: float = cell_size * 0.35
		if int(item["kind"]) == 2 or int(item["kind"]) == 3:
			var artwork: EnemyDefinition = _enemy_art[item["data"]["type_id"]]
			width = cell_size * artwork.board_height * 0.26
		draw_set_transform(item["foot"], 0.0, Vector2(1.0, 0.30))
		var alpha: float = 0.35 * (_corpse_alpha(float(item["data"]["age"])) if int(item["kind"]) == 3 else 1.0)
		draw_circle(Vector2.ZERO, width, Color(0.06, 0.10, 0.07, alpha))
	draw_set_transform(Vector2.ZERO)
	for item: Dictionary in _draw_order:
		match int(item["kind"]):
			0:
				var texture: Texture2D = _portal_texture if item["cell"] == layout.entrance else _crystal_texture
				draw_texture_rect(texture, _sprite_rect(texture, 1.05, Vector2(0.5, 0.97), item["foot"]), false)
			1:
				_draw_tower(item["data"], item["foot"])
			2:
				_draw_enemy(item)
			3:
				_draw_enemy_death(item)
	# Bars are an information overlay; foreground bodies must not cover them.
	for item: Dictionary in _draw_order:
		if int(item["kind"]) == 2:
			if int(item["data"]["id"]) == selected_enemy_id:
				_draw_enemy_selection(item)
			_draw_enemy_health(item)
			_draw_bounty_indicator(item)


func _draw_tower(tower: Dictionary, foot: Vector2) -> void:
	var artwork: TowerReward = _tower_art.get(tower["type_id"])
	var orbiting: bool = tower.get("evolution", "") in ["boulders", "onyx_ring"]
	if orbiting:
		_draw_boulders(tower, foot, false)
	if artwork != null and artwork.icon_texture != null:
		var variant: Dictionary = _tower_variant(tower, artwork)
		var texture: Texture2D = variant.get("texture", artwork.board_texture if artwork.board_texture != null else artwork.icon_texture)
		var directional: bool = not artwork.directional_weapon_textures.is_empty()
		var flip: bool = not directional and artwork.mirror_board and mirror_horizontal
		var framing: Texture2D = texture if not variant.is_empty() else artwork.icon_texture
		var rect: Rect2 = _directional_weapon_rect(artwork, foot) if directional else _sprite_rect(framing, float(variant.get("board_height", artwork.board_height)), variant.get("board_anchor", artwork.board_anchor), foot, flip)
		if flip:
			rect.size.x = -rect.size.x
		draw_texture_rect(texture, rect, false)
		if directional:
			draw_texture_rect(artwork.directional_weapon_textures[_directional_weapon_index(tower)], rect, false)
		_draw_support_context(tower, foot)
		if artwork.archer_head_texture != null:
			var definition: Dictionary = tower_types.get(tower["type_id"], {})
			var advancement: Dictionary = _archer_advancement(tower, definition)
			var count: int = int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) and definition.get("special_upgrade", "") == "second_archer" else 1))
			# Each actual floor's rear row precedes its front row.
			var extras: Array = tower.get("extra_archers", [])
			for index: int in range(mini(extras.size(), maxi(0, count - 2)) - 1, -1, -1):
				_draw_archer(tower, artwork, index + 2)
			if count > 1:
				_draw_archer(tower, artwork, 1)
			_draw_archer(tower, artwork, 0)
	if orbiting:
		_draw_boulders(tower, foot, true)


func _draw_support_context(tower: Dictionary, foot: Vector2) -> void:
	# Only accepted bonuses on the inspected recipient; never recompute an aura.
	if int(tower["id"]) != selected_tower_id:
		return
	var pixel: float = maxf(1.0, floorf(_cell_size() * 0.025))
	var base: Vector2 = (foot + Vector2(-pixel * 5.0, -pixel * 4.0)).floor()
	if float(tower.get("support_damage_bonus", 0.0)) > 0.0:
		draw_line(base, base + Vector2(pixel * 4.0, -pixel * 4.0), Color("d8b472"), pixel * 2.0)
		draw_line(base + Vector2(0, -pixel * 2.0), base + Vector2(pixel * 2.0, 0), Color("f1d6a0"), pixel)
	if float(tower.get("support_speed_bonus", 0.0)) > 0.0:
		for index: int in range(2):
			var point: Vector2 = base + Vector2(pixel * float(7 + index * 3), -pixel * 2.0)
			draw_line(point + Vector2(-pixel, pixel), point, Color("86bec6"), pixel)
			draw_line(point, point + Vector2(pixel, pixel), Color("86bec6"), pixel)


func _draw_bounty_indicator(item: Dictionary) -> void:
	var enemy: Dictionary = item["data"]
	if int(enemy.get("bounty_tower_id", -1)) < 0:
		return
	var bounds: Rect2 = _enemy_sprite_bounds(enemy, item["foot"], item["progress"])
	var pixel: float = maxf(1.0, floorf(_cell_size() * 0.022))
	# A gold coin with a red warrant ribbon remains distinct from selection/bar.
	var center: Vector2 = Vector2(bounds.position.x - pixel * 3.0, bounds.position.y + pixel * 2.0).floor()
	draw_rect(Rect2(center - Vector2.ONE * pixel * 3.0, Vector2.ONE * pixel * 6.0), Color("252a29"))
	draw_rect(Rect2(center - Vector2.ONE * pixel * 2.0, Vector2.ONE * pixel * 4.0), Color("d6a647"))
	draw_line(center + Vector2(-pixel, -pixel), center + Vector2(pixel, -pixel), Color("f7d982"), pixel)
	if float(enemy.get("bounty_income_bonus", 0.0)) > 0.0:
		draw_line(center + Vector2(0, -pixel), center + Vector2(0, pixel), Color("86602c"), pixel)
	if float(enemy.get("bounty_damage_bonus", 0.0)) > 0.0:
		draw_line(center + Vector2(-pixel * 2.0, pixel * 3.0), center + Vector2(0, pixel * 5.0), Color("cf7352"), pixel)
		draw_line(center + Vector2(0, pixel * 5.0), center + Vector2(pixel * 2.0, pixel * 3.0), Color("cf7352"), pixel)
	if _bounty_hit_life.has(int(enemy["id"])):
		var fade: float = _bounty_hit_life[int(enemy["id"])] / 0.18
		var hit: Vector2 = bounds.get_center()
		for side: float in [-1.0, 1.0]:
			draw_line(hit + Vector2(pixel * 3.0 * side, pixel * 2.0), hit + Vector2(pixel * 6.0 * side, -pixel * 3.0), Color(1.0, 0.58, 0.32, fade), pixel * 2.0)


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
			_cell_size() * 0.14, _boulder_phase * 0.35 + index, tower.get("evolution", "") == "onyx_ring", 1.0, bool(tower.get("freeze_upgraded", false)))


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


func _corpse_alpha(age: float) -> float:
	return clampf((CORPSE_LIFETIME - age) / 0.5, 0.0, 1.0)


func _draw_death_blood(trace: Dictionary, foot: Vector2) -> void:
	var artwork: EnemyDefinition = _enemy_art[trace["type_id"]]
	if artwork.blood_color.a <= 0.0:
		return
	var age: float = trace["age"]
	var color := Color(artwork.blood_color, artwork.blood_color.a * _corpse_alpha(age) * 0.85)
	var pixel: float = maxf(1.0, floorf(_cell_size() * 0.025))
	var spread: float = clampf(age / 0.13, 0.0, 1.0)
	var sign_x: float = -1.0 if int(trace["enemy_id"]) % 2 else 1.0
	for offset: Vector2 in BLOOD_DROPS:
		var position: Vector2 = foot + Vector2(offset.x * sign_x, offset.y * 0.65) * pixel * spread
		draw_rect(Rect2(position.floor(), Vector2(pixel * 2.0, pixel)), color)


func _draw_enemy_death(item: Dictionary) -> void:
	var trace: Dictionary = item["data"]
	var artwork: EnemyDefinition = _enemy_art[trace["type_id"]]
	var frame: Texture2D = EnemyVisuals.frame_texture(artwork, &"death", float(trace["age"]))
	if frame == null:
		return
	var flip: bool = (bool(trace["faces_left"]) != mirror_horizontal) != artwork.source_faces_left
	var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, frame, _cell_size() * artwork.board_height, item["foot"], flip)
	if flip:
		rect.size.x = -rect.size.x
	draw_texture_rect(frame, rect, false, Color(1.0, 1.0, 1.0, _corpse_alpha(float(trace["age"]))))


func _draw_enemy(item: Dictionary) -> void:
	var enemy: Dictionary = item["data"]
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], item["progress"]) != artwork.source_faces_left
	var frame: Texture2D = EnemyVisuals.enemy_texture(artwork, enemy)
	var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, frame, _cell_size() * artwork.board_height, item["foot"], flip)
	var animation: StringName = StringName(enemy.get("animation", "walk"))
	if animation == &"heal" or animation == &"cast":
		EnemyVisuals.draw_action_effect(self, item["foot"], _cell_size() * 0.38, animation, float(enemy.get("animation_elapsed", 0.0)))
	if flip:
		rect.size.x = -rect.size.x
	var burning: bool = bool(enemy.get("burning", false)) and not bool(enemy.get("fire_immune", false))
	var texture: Texture2D = frame
	if burning:
		texture = _burning_enemy_textures.get(frame, frame)
	elif bool(enemy.get("slowed", false)) and not bool(enemy.get("ice_immune", false)):
		texture = _slowed_enemy_textures.get(frame, frame)
	draw_texture_rect(texture, rect, false)
	if burning:
		var pixel: float = maxf(1.0, floorf(_cell_size() * 0.022))
		var phase: int = int(float(enemy.get("age", 0.0)) * 10.0) + int(enemy["id"])
		_draw_pixel_flame(item["foot"] + Vector2(-pixel * 3.0, -_cell_size() * artwork.board_height * 0.30), pixel, phase)
		_draw_pixel_flame(item["foot"] + Vector2(pixel * 3.0, -_cell_size() * artwork.board_height * 0.48), pixel, phase + 2)


func _enemy_sprite_bounds(enemy: Dictionary, foot: Vector2, progress: float) -> Rect2:
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], progress) != artwork.source_faces_left
	var frame: Texture2D = EnemyVisuals.enemy_texture(artwork, enemy)
	return EnemyVisuals.visible_rect(artwork, frame, _cell_size() * artwork.board_height, foot, flip)


func _enemy_contains_point(enemy: Dictionary, foot: Vector2, progress: float, position: Vector2) -> bool:
	if not _enemy_sprite_bounds(enemy, foot, progress).has_point(position):
		return false
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], progress) != artwork.source_faces_left
	var frame: Texture2D = EnemyVisuals.enemy_texture(artwork, enemy)
	var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, frame, _cell_size() * artwork.board_height, foot, flip)
	var uv: Vector2 = (position - rect.position) / rect.size
	if flip:
		uv.x = 1.0 - uv.x
	var image: Image = EnemyVisuals.image(frame)
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
	# Continuous fire is accepted state, never an invented train of discrete arrows.
	for tower: Dictionary in combat_towers:
		var definition: Dictionary = tower_types.get(tower["type_id"], {})
		if _archer_advancement(tower, definition).get("weapon", "arrow") != "flamethrower":
			continue
		if not bool(tower.get("firing", false)) or float(tower.get("refuel_remaining", 0.0)) > 0.0:
			continue
		var geometry: Dictionary = _archer_geometry(tower, 0, 1.0)
		var end: Vector2 = _position_center(tower.get("aim", Vector2(tower["cell"]))) + Vector2(0, cell_size * 0.15)
		ArrowWeaponVisuals.draw_flame_jet(self, geometry["tip"], end, cell_size, _flame_elapsed)
	for trace: Dictionary in _shot_traces:
		var remaining: float = clampf(float(trace["life"]) / float(trace["duration"]), 0.0, 1.0)
		if bool(trace.get("chain", false)):
			_draw_chain(trace, remaining)
			continue
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


func _draw_chain(trace: Dictionary, remaining: float) -> void:
	# Ordered accepted strike positions include lethal hits. No local target search.
	var start: Vector2 = _projectile_origin(trace)
	var segment: int = 0
	for point: Vector2 in trace["chain_points"]:
		var end: Vector2 = _position_center(point) + Vector2(0, _cell_size() * 0.12)
		var direction: Vector2 = end - start
		var normal := Vector2(-direction.y, direction.x).normalized()
		var bend: float = minf(_cell_size() * 0.10, direction.length() * 0.14)
		var handedness: float = -1.0 if mirror_horizontal else 1.0
		var zig: float = (1.0 if segment % 2 == 0 else -1.0) * handedness
		var points := PackedVector2Array([start.floor(),
			(start.lerp(end, 0.28) + normal * bend * zig).floor(),
			(start.lerp(end, 0.55) - normal * bend * zig).floor(),
			(start.lerp(end, 0.76) + normal * bend * 0.6 * zig).floor(), end.floor()])
		draw_polyline(points, Color(0.18, 0.45, 0.62, remaining * 0.75), 4.0)
		draw_polyline(points, Color(0.68, 0.94, 0.98, remaining), 2.0)
		draw_line(end + Vector2(-3, -3), end + Vector2(3, 3), Color(0.86, 1.0, 0.97, remaining), 2.0)
		draw_line(end + Vector2(-3, 3), end + Vector2(3, -3), Color(0.86, 1.0, 0.97, remaining), 2.0)
		start = end
		segment += 1


func _draw_onyx_pulse(trace: Dictionary, remaining: float) -> void:
	var foot: Vector2 = _tower_foot(trace["cell"])
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
	if trace.has("origin_offset"):
		var offset: Vector2 = trace["origin_offset"]
		if mirror_horizontal:
			offset.x = -offset.x
		return cell_center(trace["cell"]) + offset * _cell_size()
	return _tower_muzzle(trace, int(trace["archer_index"]))


func _tower_muzzle(tower: Dictionary, archer_index: int, released: bool = false) -> Vector2:
	var cell_size: float = _cell_size()
	var artwork: TowerReward = _tower_art.get(tower["type_id"])
	if artwork != null and not artwork.directional_weapon_textures.is_empty():
		var rect: Rect2 = _directional_weapon_rect(artwork, _tower_foot(tower["cell"]))
		var origin: Vector2 = artwork.directional_projectile_origins[_directional_weapon_index(tower, released)]
		return rect.position + origin * (rect.size / _directional_canvas_sizes[artwork])
	if artwork != null and artwork.archer_head_texture != null:
		return _archer_geometry(tower, archer_index, _archer_draw_amount(tower, archer_index))["tip"]
	if artwork != null and artwork.icon_texture != null and artwork.projectile_origin.x >= 0.0 and artwork.projectile_origin.y >= 0.0:
		var foot: Vector2 = _tower_foot(tower["cell"])
		var variant: Dictionary = _tower_variant(tower, artwork)
		var texture: Texture2D = variant.get("texture", artwork.icon_texture)
		var flip: bool = artwork.mirror_board and mirror_horizontal
		var rect: Rect2 = _sprite_rect(texture, float(variant.get("board_height", artwork.board_height)), variant.get("board_anchor", artwork.board_anchor), foot, flip)
		var muzzle: Vector2 = artwork.projectile_origin + _archer_offset(artwork, archer_index)
		if flip:
			muzzle.x = texture.get_width() - muzzle.x
		return rect.position + muzzle * rect.size / texture.get_size()
	return _tower_foot(tower["cell"]) + Vector2(0, -cell_size * 0.58)


func _projectile_destination(trace: Dictionary) -> Vector2:
	if bool(trace["pierce_active"]):
		# Keep the muzzle height for the whole accepted ray, without a bend at aim.
		return _projectile_origin(trace) + _position_center(trace["pierce_aim"]) - cell_center(trace["cell"])
	return _position_center(trace["aim"]) + Vector2(0, _cell_size() * 0.15)


func _projectile_position(trace: Dictionary) -> Vector2:
	var elapsed: float = float(trace["duration"]) - float(trace["life"])
	var primary: Vector2 = _projectile_destination(trace)
	if bool(trace["pierce_active"]):
		return _projectile_origin(trace).lerp(primary, clampf(elapsed / float(trace["duration"]), 0.0, 1.0))
	if bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION:
		var bounce: Vector2 = _position_center(trace["bounce_aim"]) + Vector2(0, _cell_size() * 0.15)
		return primary.lerp(bounce, clampf((elapsed - SHOT_DURATION) / SHOT_DURATION, 0.0, 1.0))
	var fraction: float = clampf(elapsed / float(trace.get("flight_duration", SHOT_DURATION)), 0.0, 1.0)
	var position: Vector2 = _projectile_origin(trace).lerp(primary, fraction)
	if trace.get("weapon", "arrow") in ["molotov", "grenade"]:
		position.y -= sin(fraction * PI) * minf(_cell_size() * 0.75, _projectile_origin(trace).distance_to(primary) * 0.25)
	return position


func _draw_projectiles() -> void:
	var cell_size: float = _cell_size()
	for trace: Dictionary in _shot_traces:
		if bool(trace["area_attack"]) or bool(trace.get("chain", false)):
			continue
		var position: Vector2 = _projectile_position(trace)
		var elapsed: float = float(trace["duration"]) - float(trace["life"])
		var end: Vector2 = _projectile_destination(trace)
		var weapon: String = trace.get("weapon", "arrow")
		var flight: float = float(trace.get("flight_duration", SHOT_DURATION))
		if float(trace["splash_radius"]) > 0.0 and elapsed >= flight:
			var phase: float = (elapsed - flight) / float(trace.get("impact_duration", BOMB_IMPACT_DURATION))
			if weapon in ["molotov", "grenade", "rocket"]:
				ArrowWeaponVisuals.draw_impact(self, end, float(trace["splash_radius"]) * cell_size, phase, maxf(1, floorf(cell_size * 0.022)), weapon)
			else:
				_draw_bomb_impact(end, float(trace["splash_radius"]), phase)
			continue
		var start: Vector2 = _projectile_origin(trace)
		if bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION:
			start = end
			end = _position_center(trace["bounce_aim"]) + Vector2(0, cell_size * 0.15)
		var direction: Vector2 = (end - start).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		if weapon in ["molotov", "grenade", "rocket"]:
			var pixel: float = maxf(0.65, cell_size * 0.014)
			var spin: float = direction.angle() if weapon == "rocket" else elapsed * 16.0 * (-1.0 if mirror_horizontal else 1.0)
			if weapon == "rocket":
				for index: int in range(8):
					var puff: Vector2 = position - direction * pixel * float(15 + index * 5) + Vector2(0, -index * pixel)
					var width: float = pixel * float(3 + index)
					draw_rect(Rect2((puff - Vector2.ONE * width * 0.5).floor(), Vector2.ONE * width), Color(0.48, 0.48, 0.41, 0.70 - float(index) * 0.07))
			ArrowWeaponVisuals.draw_payload(self, position, pixel, weapon, spin, elapsed)
			continue
		var side := Vector2(-direction.y, direction.x)
		var artwork: TowerReward = _tower_art.get(trace["type_id"])
		var length: float = cell_size * (artwork.projectile_length if artwork != null else 0.18)
		var width: float = artwork.projectile_width if artwork != null else 1.3
		# Position is the physical arrow TIP, shared with the nocked arrow at release.
		var tail: Vector2 = position - direction * length
		var tip: Vector2 = position
		draw_line(tail, tip, Color("b9a575"), width, true)
		if float(trace["splash_radius"]) > 0.0:
			_draw_bomb_head(tip, maxf(1.0, floorf(cell_size * 0.022)), int(elapsed * 20.0))
		else:
			draw_line(tip, tip - direction * length * 0.32 + side * length * 0.22, Color("e8e3c9"), width, true)
			draw_line(tip, tip - direction * length * 0.32 - side * length * 0.22, Color("e8e3c9"), width, true)
		if bool(trace["burning"]):
			var pixel: float = maxf(1.0, floorf(cell_size * 0.022))
			var phase: int = int(elapsed * 24.0) + int(trace["archer_index"])
			_draw_pixel_flame(tip, pixel, phase)
			for index: int in range(3):
				var ember: Vector2 = tail - direction * pixel * float(index * 4 + 2)
				ember.y -= pixel * float((index + phase) % 3)
				draw_rect(Rect2(ember.floor(), Vector2.ONE * pixel * (2.0 if index == 0 else 1.0)),
					Color("ef7d35") if index == 0 else Color("b94a2c"))
		draw_line(tail, tail + direction * length * 0.25 + side * length * 0.18, Color("d3cbab"), width, true)
		draw_line(tail, tail + direction * length * 0.25 - side * length * 0.18, Color("d3cbab"), width, true)


func _archer_offset(artwork: TowerReward, archer_index: int, variant: Dictionary = {}) -> Vector2:
	if archer_index == 1:
		return variant.get("secondary_sprite_offset", artwork.secondary_sprite_offset)
	var offsets: PackedVector2Array = variant.get("additional_archer_offsets", artwork.additional_archer_offsets)
	if archer_index >= 2 and archer_index - 2 < offsets.size():
		return offsets[archer_index - 2]
	return Vector2.ZERO


func _archer_aim(tower: Dictionary, archer_index: int) -> Vector2:
	if archer_index == 1:
		return tower.get("secondary_aim", Vector2(tower["cell"]))
	if archer_index >= 2:
		var extras: Array = tower.get("extra_archers", [])
		if archer_index - 2 < extras.size():
			return extras[archer_index - 2].get("aim", Vector2(tower["cell"]))
	return tower.get("aim", Vector2(tower["cell"]))


func _archer_draw_amount(tower: Dictionary, archer_index: int) -> float:
	var pose: Dictionary = _archer_poses.get(Vector2i(int(tower["id"]), archer_index), {})
	if pose.is_empty():
		return 1.0
	var age: float = float(pose["age"])
	# Host-confirmed first shots release immediately. Recovery, nocking and then
	# string tension anticipate the NEXT accepted volley, never inventing a hit.
	return smoothstep(0.16, maxf(0.21, float(pose["interval"]) * 0.85), age)


func _archer_geometry(tower: Dictionary, archer_index: int, tension: float) -> Dictionary:
	var artwork: TowerReward = _tower_art[tower["type_id"]]
	var foot: Vector2 = _tower_foot(tower["cell"])
	var variant: Dictionary = _tower_variant(tower, artwork)
	var texture: Texture2D = variant.get("texture", artwork.icon_texture)
	var rect: Rect2 = _sprite_rect(texture, float(variant.get("board_height", artwork.board_height)), variant.get("board_anchor", artwork.board_anchor), foot)
	var scale: float = rect.size.y / texture.get_height()
	var local: Vector2 = variant.get("archer_pivot", artwork.archer_pivot) + _archer_offset(artwork, archer_index, variant)
	# Mirror the whole placement, never rotate/mirror the stationary tower.
	if mirror_horizontal:
		local.x = texture.get_width() - local.x
	var pivot: Vector2 = (rect.position + local * scale).round()
	var aim: Vector2 = _archer_aim(tower, archer_index)
	var direction: Vector2 = Vector2.LEFT if mirror_horizontal else Vector2.RIGHT
	if not aim.is_equal_approx(Vector2(tower["cell"])):
		direction = (_position_center(aim) + Vector2(0, _cell_size() * 0.15) - pivot).normalized()
	var side := Vector2(-direction.y, direction.x)
	var bow: Vector2 = pivot + direction * 9.0 * scale
	var nock: Vector2 = bow - direction * lerpf(1.0, 7.0, tension) * scale
	var tip: Vector2 = nock + direction * _cell_size() * artwork.projectile_length
	var definition: Dictionary = tower_types.get(tower["type_id"], {})
	var weapon: String = _archer_advancement(tower, definition).get("weapon", "arrow")
	if weapon != "arrow":
		tip = pivot + ArrowWeaponVisuals.release_offset(weapon, direction, scale)
	return {"pivot": pivot, "direction": direction, "side": side, "bow": bow,
		"nock": nock.round(), "tip": tip.round(), "scale": scale}


func _draw_archer(tower: Dictionary, artwork: TowerReward, archer_index: int) -> void:
	var tension: float = _archer_draw_amount(tower, archer_index)
	var geometry: Dictionary = _archer_geometry(tower, archer_index, tension)
	var pivot: Vector2 = geometry["pivot"]
	var direction: Vector2 = geometry["direction"]
	var scale: float = geometry["scale"]
	var pose: Dictionary = _archer_poses.get(Vector2i(int(tower["id"]), archer_index), {})
	var age: float = float(pose.get("age", 100.0))
	var definition: Dictionary = tower_types.get(tower["type_id"], {})
	var weapon: String = _archer_advancement(tower, definition).get("weapon", "arrow")
	if weapon != "arrow":
		ArrowWeaponVisuals.draw_operator(self, artwork, geometry, tower, weapon, age, float(pose.get("interval", tower.get("interval", 0.8))), _flame_elapsed)
		return
	var recoil: Vector2 = -direction * scale * (2.0 * (1.0 - clampf(age / 0.12, 0.0, 1.0)))
	var facing: int = posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	var body_facing: int = posmod(roundi(direction.angle() / (PI / 2.0)), 4)
	var body_rect := Rect2((pivot + Vector2(-7, -3) * scale + recoil).round(), Vector2(14, 14) * scale)
	draw_texture_rect_region(artwork.archer_body_texture, body_rect, Rect2(body_facing * 14, 0, 14, 14))
	# Upward bows sit behind the head; downward/sideways bows pass in front.
	if direction.y < -0.4:
		_draw_archer_bow(tower, archer_index, geometry, age)
	var head_rect := Rect2((pivot + Vector2(-8, -15) * scale + recoil).round(), Vector2(16, 14) * scale)
	draw_texture_rect_region(artwork.archer_head_texture, head_rect, Rect2(facing * 16, 0, 16, 14))
	if direction.y >= -0.4:
		_draw_archer_bow(tower, archer_index, geometry, age)


func _draw_archer_bow(tower: Dictionary, archer_index: int, geometry: Dictionary, age: float) -> void:
	var pivot: Vector2 = geometry["pivot"]
	var direction: Vector2 = geometry["direction"]
	var side: Vector2 = geometry["side"]
	var scale: float = geometry["scale"]
	var bow: Vector2 = geometry["bow"]
	var nock: Vector2 = geometry["nock"]
	var tip: Vector2 = geometry["tip"]
	var upper: Vector2 = (bow + (side * 6.5 - direction * 2.0) * scale).round()
	var lower: Vector2 = (bow + (-side * 6.5 - direction * 2.0) * scale).round()
	var belly: Vector2 = (bow + direction * 2.0 * scale).round()
	var shoulder: Vector2 = (pivot + side * 2.0 * scale).round()
	var elbow: Vector2 = (shoulder - direction * 3.0 * scale + side * 3.0 * scale).round()
	var hand: Vector2 = nock if age >= 0.14 else (pivot - direction * scale * 3.0).round()
	var string_nock: Vector2 = nock if age >= 0.14 else (bow - direction * scale * (1.0 + sin(age * 110.0) * 0.6)).round()
	var arm_width: float = maxf(1.0, roundf(scale * 2.0))
	draw_line(pivot, bow.round(), Color("30291e"), arm_width + 2.0)
	draw_line(pivot, bow.round(), Color("77925a"), arm_width + 1.0)
	draw_line(pivot.lerp(bow, 0.6).round(), bow.round(), Color("dca27a"), arm_width)
	draw_line(shoulder, elbow, Color("30291e"), arm_width + 2.0)
	draw_line(shoulder, elbow, Color("536e3f"), arm_width + 1.0)
	draw_line(elbow, hand, Color("30291e"), arm_width + 2.0)
	draw_line(elbow, hand, Color("dca27a"), arm_width)
	draw_rect(Rect2(hand - Vector2.ONE * scale, Vector2.ONE * maxf(2.0, 2.0 * scale)), Color("edbb92"))
	draw_line(upper, belly, Color("50361f"), maxf(2.0, scale * 3.0))
	draw_line(belly, lower, Color("50361f"), maxf(2.0, scale * 3.0))
	draw_line(upper, belly, Color("ba8b4f"), maxf(1.0, scale))
	draw_line(belly, lower, Color("ba8b4f"), maxf(1.0, scale))
	draw_line(upper, string_nock, Color("d3cbab"), 1.0)
	draw_line(string_nock, lower, Color("d3cbab"), 1.0)
	if age < 0.14:
		return
	draw_line(nock, tip, Color("b9a575"), maxf(1.0, scale))
	draw_line(nock, (nock + (direction * 3.0 + side * 2.0) * scale).round(), Color("d3cbab"), 1.0)
	draw_line(nock, (nock + (direction * 3.0 - side * 2.0) * scale).round(), Color("d3cbab"), 1.0)
	var definition: Dictionary = tower_types.get(tower["type_id"], {})
	var advancement: Dictionary = _archer_advancement(tower, definition)
	var pixel: float = maxf(1.0, floorf(_cell_size() * 0.022))
	var phase: int = int(_flame_elapsed * 12.0) + int(tower["id"]) + archer_index * 2
	if float(advancement.get("splash_radius", 0.0)) > 0.0:
		_draw_bomb_head(tip, pixel, phase)
	else:
		draw_line(tip, (tip - direction * scale * 3.0 + side * scale * 2.0).round(), Color("e8e3c9"), 1.0)
		draw_line(tip, (tip - direction * scale * 3.0 - side * scale * 2.0).round(), Color("e8e3c9"), 1.0)
	if float(advancement.get("burn_dps", 0.0)) > 0.0:
		_draw_pixel_flame(tip, pixel, phase)


func _draw_pixel_flame(position: Vector2, pixel: float, phase: int) -> void:
	# Deliberately tiny, hard-edged native pixels, not a glow/particle billboard.
	var base: Vector2 = position.floor()
	var lean: float = float(posmod(phase, 3) - 1) * pixel
	var height: float = float(4 + posmod(phase, 2)) * pixel
	draw_rect(Rect2(base + Vector2(-pixel * 2.0, -pixel * 2.0), Vector2(pixel * 4.0, pixel * 3.0)), Color("b94027"))
	draw_rect(Rect2(base + Vector2(-pixel, -height), Vector2(pixel * 2.0, height + pixel)), Color("ef7d35"))
	draw_rect(Rect2(base + Vector2(lean, -height - pixel), Vector2(pixel, pixel * 2.0)), Color("ef7d35"))
	draw_rect(Rect2(base + Vector2(0.0, -pixel * 2.0), Vector2(pixel, pixel * 2.0)), Color("ffe3a0"))


func _draw_bomb_head(position: Vector2, pixel: float, phase: int) -> void:
	var base: Vector2 = position.floor()
	draw_rect(Rect2(base + Vector2(-pixel * 2.0, -pixel * 2.0), Vector2.ONE * pixel * 4.0), Color("171b20"))
	draw_rect(Rect2(base + Vector2(-pixel * 3.0, -pixel), Vector2(pixel * 6.0, pixel * 2.0)), Color("171b20"))
	draw_rect(Rect2(base + Vector2(-pixel, -pixel * 2.0), Vector2(pixel * 2.0, pixel)), Color("707477"))
	draw_line(base + Vector2(pixel, -pixel * 2.0), base + Vector2(pixel * 2.0, -pixel * 4.0), Color("c6a671"), pixel)
	draw_rect(Rect2(base + Vector2(pixel * 2.0, -pixel * 5.0), Vector2.ONE * pixel), Color("ffe3a0") if posmod(phase, 2) else Color("ef7d35"))


func _draw_bomb_impact(position: Vector2, splash_radius: float, phase: float) -> void:
	var fade: float = 1.0 - clampf(phase, 0.0, 1.0)
	var pixel: float = maxf(1.0, floorf(_cell_size() * 0.022))
	var radius: float = splash_radius * _cell_size()
	draw_arc(position, radius * phase, 0.0, TAU, 24, Color(0.85, 0.66, 0.40, fade * 0.45), pixel, false)
	var puff: float = pixel * (3.0 + phase * 5.0)
	draw_rect(Rect2((position - Vector2(puff, puff * 0.5)).floor(), Vector2(puff * 2.0, puff)), Color(0.48, 0.44, 0.37, fade))
	draw_rect(Rect2((position - Vector2(puff * 0.5, puff)).floor(), Vector2(puff, puff * 2.0)), Color(0.62, 0.57, 0.46, fade))
	for index: int in range(5):
		var angle: float = float(index) * TAU / 5.0
		var spark: Vector2 = position + Vector2(cos(angle), sin(angle)) * radius * phase * 0.55
		draw_rect(Rect2(spark.floor(), Vector2.ONE * pixel * 2.0), Color(1.0, 0.62, 0.24, fade))
