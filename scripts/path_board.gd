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
# Each Magic Ballista redirect leg; ordinary Bounce legs keep SHOT_DURATION.
const MAGIC_BOUNCE_DURATION: float = 0.13
# Ballista bolts are drawn larger than arrows and grow out of the muzzle.
const BALLISTA_BOLT_LENGTH: float = 0.46
const BALLISTA_BOLT_WIDTH: float = 0.045
const MAGIC_COLOR := Color("b48cff")
const MAGIC_CORE := Color("f1e6ff")
# Onyx Ring: the ring drops onto the ground on each pulse, then rises again.
const RING_FALL: float = 0.09
const RING_RISE: float = 0.33
const ONYX_STONE := Color("1c1b27")
const ONYX_GLOW := Color("b48cff")
# Rune evolutions drawn with orbiting objects; the first five share the inner ring.
const RUNE_ORBITERS: Array[String] = ["boulders", "onyx_ring", "storm_sigil", "void_monolith"]
const INNER_ORBIT_LIMIT: int = 5
const STORM_COLOR := Color("7fe3ff")
const VOID_COLOR := Color("8a4dff")
const SHARD_COLOR := Color("74e0f0")
# Curve side/strength per extra split bolt, relative to the original bolt.
const SPLIT_FAN: Array[float] = [-1.0, 0.55, -0.55, 1.45]
const PULSE_DURATION: float = 0.14
const BOMB_IMPACT_DURATION: float = 0.28
const THROW_FLIGHT_DURATION: float = 0.40
const ROCKET_FLIGHT_DURATION: float = 0.30
const ROCKET_IMPACT_DURATION: float = 0.48
const MAX_SHOT_TRACES: int = 256
const ENEMY_LATERAL_SPREAD: float = 0.10
const ENEMY_CORNER_BLEND: float = 0.25
const ENDPOINT_FRAME_SIZE: int = 128
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
static var _stun_star_shape := PackedVector2Array([
	Vector2(0.0, -1.0), Vector2(0.253, -0.348), Vector2(0.951, -0.309),
	Vector2(0.409, 0.133), Vector2(0.588, 0.809), Vector2(0.0, 0.43),
	Vector2(-0.588, 0.809), Vector2(-0.409, 0.133), Vector2(-0.951, -0.309),
	Vector2(-0.253, -0.348), Vector2(0.0, -1.0),
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
		_capture_stuns()
		_rebuild_draw_order()
		_sync_combat_animation()
		queue_redraw()
var combat_enemies: Array = []:
	# Only presentation state is blended; accepted enemy dictionaries stay untouched.
	set(value):
		combat_enemies = value
		_blend_enemies()
		_capture_boss_actions()
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
var tower_inspection_enabled: bool = false:
	set(value):
		tower_inspection_enabled = value
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
			if definition.animation_frames != null:
				for animation: StringName in definition.animation_frames.get_animation_names():
					for frame: int in range(definition.animation_frames.get_frame_count(animation)):
						_cache_texture_bounds(definition.animation_frames.get_frame_texture(animation, frame))
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
# Onyx Ring presentation: seconds since each tower's last accepted slam.
var _ring_clocks: Dictionary = {}
var _has_boulders: bool = false
var _has_idle_flames: bool = false
var _flame_elapsed: float = 0.0
var _boulder_phase: float = 0.0
var _enemy_progress: Dictionary[int, Vector2] = {}
var _enemies_by_id: Dictionary[int, Dictionary] = {}
var _enemy_lifts: Dictionary[int, Vector2] = {}
var _enemy_position_from: Dictionary[int, Vector2] = {}
var _enemy_position_to: Dictionary[int, Vector2] = {}
var _boss_seen_enemy: Dictionary[int, Vector2i] = {}
var _boss_seen_stuns: Dictionary[int, int] = {}
var _boss_effects: Array[Dictionary] = []
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
	set_process(is_visible_in_tree() and (_has_boulders or _has_idle_flames or _has_archer_motion or not combat_enemies.is_empty() or not _shot_traces.is_empty() or not _corpse_traces.is_empty() or not _boss_effects.is_empty()))


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
	_enemy_blend_elapsed = minf(_enemy_blend_elapsed + (0.0 if _corpse_paused else delta), ENEMY_BLEND_DURATION)
	for id: int in _bounty_hit_life.keys():
		var life: float = _bounty_hit_life[id] - visual_delta
		if life <= 0.0:
			_bounty_hit_life.erase(id)
		else:
			_bounty_hit_life[id] = life
	for id: Variant in _ring_clocks.keys():
		_ring_clocks[id] = minf(float(_ring_clocks[id]) + visual_delta, 30.0)
	for index: int in range(_shot_traces.size() - 1, -1, -1):
		_shot_traces[index]["life"] -= visual_delta
		if float(_shot_traces[index]["life"]) <= 0.0:
			_shot_traces.remove_at(index)
	for index: int in range(_boss_effects.size() - 1, -1, -1):
		_boss_effects[index]["age"] += visual_delta
		if float(_boss_effects[index]["age"]) >= float(_boss_effects[index]["duration"]):
			_boss_effects.remove_at(index)
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
		_boss_effects.clear()
		_boss_seen_enemy.clear()
		_boss_seen_stuns.clear()
		_enemy_lifts.clear()
		_enemy_position_from.clear()
		_enemy_position_to.clear()
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
		_has_boulders = _has_boulders or boulders or tower.get("evolution", "") in RUNE_ORBITERS or _has_finale(tower) or tower.get("behavior_kind", "") == "crystal"
		var advancement: Dictionary = _archer_advancement(tower, definition)
		var weapon: String = advancement.get("weapon", "arrow")
		_has_idle_flames = _has_idle_flames or float(advancement.get("burn_dps", 0.0)) > 0.0 or weapon == "minigun" or not tower.get("magic_bounce", {}).is_empty()
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
	return artwork.board_variant(advancement if not advancement.is_empty() else tower.get("evolution", ""), tower.get("followup", ""), tower.get("branch_upgrades", []), _stat_tiers(tower))


# Purchased pre-branch tiers that may carry their own art: "damage", "speed"
# or "damage_speed", then the tower's special upgrade.
func _stat_tiers(tower: Dictionary) -> Array:
	var tiers: Array = []
	var damage: bool = bool(tower.get("damage_upgraded", false))
	var speed: bool = bool(tower.get("speed_upgraded", false))
	if damage or speed:
		tiers.append("damage_speed" if damage and speed else ("damage" if damage else "speed"))
	var special: String = String(tower_types.get(tower["type_id"], {}).get("special_upgrade", ""))
	if bool(tower.get("special_upgraded", false)) and not special.is_empty():
		tiers.append(special)
	return tiers



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
	var magic: bool = archer_index == 0 and not tower.get("magic_bounce", {}).is_empty()
	var bounce_points: Array = []
	var split_paths: Array = []
	if bounce:
		bounce_points = tower.get("bounce_points", []).duplicate()
		if bounce_points.is_empty():
			bounce_points = [tower.get("bounce_aim", tower.get("aim", Vector2(tower["cell"])))]
		if magic:
			split_paths = tower.get("split_paths", []).duplicate(true)
	var bounce_leg: float = MAGIC_BOUNCE_DURATION if magic else SHOT_DURATION
	var longest: int = bounce_points.size()
	for path: Array in split_paths:
		longest = maxi(longest, path.size())
	var duration: float = (ONYX_PULSE_DURATION if evolution == "onyx_ring" else PULSE_DURATION) if area_attack else SHOT_DURATION + bounce_leg * longest
	if pierce:
		# Longer-reach bolts keep the same speed for their extra flight.
		var range_cells: float = maxf(1.0, float(tower.get("range", definition.get("range", 1.0))))
		duration = PIERCE_SHOT_DURATION * (1.0 + float(tower.get("bolt_reach", 0.0)) / range_cells)
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
	if area_attack and evolution == "onyx_ring":
		_ring_clocks[int(tower["id"])] = maxf(0.0, initial_age)
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
		"bounce_points": bounce_points,
		"split_paths": split_paths,
		"bounce_leg": bounce_leg,
		"magic": magic,
		"bolt_scale": float(tower.get("bolt_scale", 1.0)) if archer_index == 0 else 1.0,
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
	var next_lifts: Dictionary[int, Vector2] = {}
	var next_position_from: Dictionary[int, Vector2] = {}
	var next_position_to: Dictionary[int, Vector2] = {}
	_enemies_by_id.clear()
	for enemy: Dictionary in combat_enemies:
		var id: int = int(enemy["id"])
		_enemies_by_id[id] = enemy
		var lift: float = EnemyVisuals.jump_lift(enemy)
		var old_lift: Vector2 = _enemy_lifts.get(id, Vector2(lift, lift))
		next_lifts[id] = Vector2(lerpf(old_lift.x, old_lift.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION), lift)
		if enemy.get("locomotion", "path") == "jump":
			var duration: float = maxf(0.001, float(enemy["jump_duration"]))
			var phase: float = clampf(1.0 - float(enemy["jump_remaining"]) / duration, 0.0, 1.0)
			var target_position: Vector2 = Vector2(enemy["jump_from"]).lerp(enemy["jump_to"], phase)
			var prior_target: Vector2 = _enemy_position_to.get(id, enemy["jump_from"])
			var prior_from: Vector2 = _enemy_position_from.get(id, prior_target)
			next_position_from[id] = prior_from.lerp(prior_target, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
			next_position_to[id] = target_position
		var hp: float = float(enemy["hp"])
		if int(enemy.get("bounty_tower_id", -1)) >= 0 and float(enemy.get("bounty_damage_bonus", 0.0)) > 0.0 and hp < _bounty_health.get(id, hp):
			_bounty_hit_life[id] = 0.18
		next_health[id] = hp
		var target: float = float(enemy["progress"])
		var previous: Vector2 = _enemy_progress.get(id, Vector2(target, target))
		var displayed: float = lerpf(previous.x, previous.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
		next_progress[id] = Vector2(displayed, target)
	_enemy_progress = next_progress
	_enemy_lifts = next_lifts
	_enemy_position_from = next_position_from
	_enemy_position_to = next_position_to
	_bounty_health = next_health
	_enemy_blend_elapsed = 0.0


func _enemy_position(enemy: Dictionary) -> Vector2:
	if enemy.get("locomotion", "path") == "jump":
		var id: int = int(enemy["id"])
		var target: Vector2 = _enemy_position_to.get(id, enemy["pos"])
		return _enemy_position_from.get(id, target).lerp(target, _enemy_blend_elapsed / ENEMY_BLEND_DURATION)
	if enemy.get("locomotion", "path") == "jump_land":
		return enemy["pos"]
	var route: Array = enemy["route"]
	if route.is_empty():
		return enemy["pos"]
	if route.size() == 1:
		return Vector2(route[0])
	return _route_position(route, _enemy_route_progress(enemy))


func _enemy_visual_position(enemy: Dictionary) -> Vector2:
	if float(enemy.get("jump_duration", 0.0)) > 0.0:
		return _enemy_position(enemy)
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
		var direction: Vector2 = Vector2(route[segment + 1]) - Vector2(route[segment])
		if direction.x != 0:
			return (direction.x < 0) != mirror_horizontal
	for segment: int in range(index + 1, route.size() - 1):
		var direction: Vector2 = Vector2(route[segment + 1]) - Vector2(route[segment])
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
	mouse_filter = Control.MOUSE_FILTER_STOP if input_enabled or enemy_inspection_enabled or tower_inspection_enabled else Control.MOUSE_FILTER_IGNORE


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
	if layout == null or not (input_enabled or enemy_inspection_enabled or tower_inspection_enabled):
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
	_draw_boss_telegraphs()
	_draw_attacks()
	_draw_combat()
	_draw_projectiles()
	_draw_boss_effects()


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


# Status tints are built per frame on first use; eagerly tinting every frame of
# every enemy froze the first board for seconds once the boss rosters landed.
func _slowed_texture(texture: Texture2D) -> Texture2D:
	if not _slowed_enemy_textures.has(texture):
		_slowed_enemy_textures[texture] = EnemyVisuals.slowed_texture(texture)
	return _slowed_enemy_textures[texture]


func _burning_texture(texture: Texture2D) -> Texture2D:
	if not _burning_enemy_textures.has(texture):
		_burning_enemy_textures[texture] = EnemyVisuals.burning_texture(texture)
	return _burning_enemy_textures[texture]


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
		if artwork.jump_duration > 0.0:
			headroom = maxf(headroom, -top + _cell_size() * 0.85 + 10.0)
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
	# Only units and corpses cast ovals; structures sit on their foundations.
	for item: Dictionary in _draw_order:
		if int(item["kind"]) < 2:
			continue
		var artwork: EnemyDefinition = _enemy_art[item["data"]["type_id"]]
		var width: float = cell_size * artwork.board_height * 0.26
		draw_set_transform(item["foot"], 0.0, Vector2(1.0, 0.30))
		var alpha: float = 0.35 * (_corpse_alpha(float(item["data"]["age"])) if int(item["kind"]) == 3 else 1.0)
		draw_circle(Vector2.ZERO, width, Color(0.06, 0.10, 0.07, alpha))
	draw_set_transform(Vector2.ZERO)
	for item: Dictionary in _draw_order:
		match int(item["kind"]):
			0:
				var texture: Texture2D = _portal_texture if item["cell"] == layout.entrance else _crystal_texture
				var anchor := Vector2(0.5, 0.9609375) if item["cell"] == layout.entrance else Vector2(0.50390625, 0.9296875)
				if item["cell"] == layout.entrance and mirror_horizontal:
					draw_set_transform(item["foot"], 0.0, Vector2(-1.0, 1.0))
					draw_texture_rect(texture, _sprite_rect(texture, 1.05, anchor, Vector2.ZERO), false)
					draw_set_transform(Vector2.ZERO)
				else:
					draw_texture_rect(texture, _sprite_rect(texture, 1.05, anchor, item["foot"]), false)
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
	var orbiting: bool = tower.get("evolution", "") in RUNE_ORBITERS
	_draw_tower_underlay(tower, foot)
	if orbiting:
		_draw_boulders(tower, foot, false)
	_draw_stun_stars(tower, foot, false)
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
			var poses: Array = variant.get("directional_weapon_textures", artwork.directional_weapon_textures)
			draw_texture_rect(poses[_directional_weapon_index(tower)], rect, false)
			if not tower.get("magic_bounce", {}).is_empty():
				_draw_magic_ballista(tower, artwork, rect)
		_draw_support_context(tower, foot)
		_draw_tower_overlay(tower, foot, artwork, rect)
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
	_draw_stun_stars(tower, foot, true)


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


func _orbit_count(tower: Dictionary) -> int:
	return 3 + int(tower.get("orbit_bonus", 0))


# Up to five objects share the original inner orbit; more circle on a wider,
# higher outer ring turning the other way.
func _boulder_offset(tower: Dictionary, index: int) -> Vector2:
	var count: int = _orbit_count(tower)
	var inner: int = mini(count, INNER_ORBIT_LIMIT)
	var flip: float = -1.0 if mirror_horizontal else 1.0
	if index < inner:
		var angle: float = _boulder_phase + float(index) * TAU / float(inner) + float(int(tower["id"]) % 17) * 0.37
		return Vector2(cos(angle) * flip * 0.51, sin(angle) * 0.20) * _cell_size()
	var outer: int = count - inner
	var outer_angle: float = -_boulder_phase * 0.7 + float(index - inner) * TAU / float(outer) + float(int(tower["id"]) % 13) * 0.29
	return Vector2(cos(outer_angle) * flip * 0.80, sin(outer_angle) * 0.30 - 0.16) * _cell_size()


# The last branch upgrade of a Rune/Ballista/Crystal Mine branch is its finale.
func _has_finale(tower: Dictionary) -> bool:
	var steps: Array = tower_types.get(tower["type_id"], {}).get("evolutions", {}).get(tower.get("evolution", ""), {}).get("upgrades", [])
	return not steps.is_empty() and tower.get("branch_upgrades", []).size() >= steps.size()


func _draw_boulders(tower: Dictionary, foot: Vector2, front: bool) -> void:
	# The orbit is cosmetic, not a contact/range boundary or a damage event.
	var evolution: String = tower.get("evolution", "")
	for index: int in range(_orbit_count(tower)):
		var offset: Vector2 = _boulder_offset(tower, index)
		if (offset.y >= 0.0) != front:
			continue
		var position: Vector2 = foot + offset + Vector2(0, -_cell_size() * 0.46)
		match evolution:
			"onyx_ring":
				continue
			"storm_sigil":
				_draw_storm_orb(position, _cell_size() * 0.085, index)
			"void_monolith":
				_draw_void_shard(position, _cell_size() * 0.12, _boulder_phase * 0.8 + index)
			_:
				_draw_rune_stone(position, _cell_size() * 0.14, _boulder_phase * 0.35 + index, evolution == "onyx_ring", 1.0, bool(tower.get("freeze_upgraded", false)))
	if evolution == "onyx_ring":
		_draw_onyx_rings(tower, foot, front)
	if front and evolution == "storm_sigil" and _has_finale(tower):
		# Wrath of the Storm: arcs jump between neighbouring orbs.
		for index: int in range(0, _orbit_count(tower) - 1, 2):
			var a: Vector2 = foot + _boulder_offset(tower, index) + Vector2(0, -_cell_size() * 0.46)
			var b: Vector2 = foot + _boulder_offset(tower, index + 1) + Vector2(0, -_cell_size() * 0.46)
			_draw_zigzag(a, b, Color(STORM_COLOR, 0.75), 1.5, index + int(_boulder_phase * 6.0))


# Above-sprite effects: Crystal Mine crystals and every branch finale.
func _draw_tower_overlay(tower: Dictionary, foot: Vector2, artwork: TowerReward, rect: Rect2) -> void:
	var cell_size: float = _cell_size()
	var evolution: String = tower.get("evolution", "")
	var finale: bool = _has_finale(tower)
	var top := Vector2(foot.x, rect.position.y + absf(rect.size.y) * 0.12)
	if artwork.icon_texture != null and _texture_bounds.has(artwork.icon_texture) and artwork.directional_weapon_textures.is_empty():
		top.y = rect.position.y + _texture_bounds[artwork.icon_texture].position.y * absf(rect.size.y) / artwork.icon_texture.get_height()
	if not finale:
		return
	var pulse: float = 0.5 + 0.5 * sin(_boulder_phase * 2.0)
	match evolution:
		"onyx_ring":
			# Eclipse: a dark sun crowned by a violet corona.
			var sun: Vector2 = top + Vector2(0, -cell_size * 0.32)
			draw_circle(sun, cell_size * (0.30 + 0.03 * pulse), Color("b9a6e6", 0.16))
			for index: int in range(16):
				var angle: float = _boulder_phase * 0.4 + float(index) * TAU / 16.0
				var length: float = cell_size * (0.24 + 0.06 * sin(_boulder_phase * 3.0 + index))
				draw_line(sun + Vector2(cos(angle), sin(angle)) * cell_size * 0.17, sun + Vector2(cos(angle), sin(angle)) * length, Color("d9c8ff", 0.65), maxf(1.0, cell_size * 0.012), true)
			draw_circle(sun, cell_size * 0.16, Color("0c0814"))
			draw_arc(sun, cell_size * 0.16, 0.0, TAU, 28, Color("f2e8ff", 0.9), maxf(1.0, cell_size * 0.012), true)
		"void_monolith":
			# Singularity: a black hole with a tilted, spinning accretion ring.
			var hole: Vector2 = top + Vector2(0, -cell_size * 0.30)
			draw_set_transform(hole, 0.35, Vector2(1.0, 0.32))
			for ring: int in range(3):
				draw_arc(Vector2.ZERO, cell_size * (0.24 + 0.05 * ring), _boulder_phase * (2.0 - ring * 0.5), _boulder_phase * (2.0 - ring * 0.5) + PI * 1.4, 24, Color(VOID_COLOR.lerp(Color("ff8ad8"), ring * 0.3), 0.85 - ring * 0.2), maxf(1.5, cell_size * 0.025), true)
			draw_set_transform(Vector2.ZERO)
			draw_circle(hole, cell_size * 0.13, Color("030106"))
			draw_arc(hole, cell_size * 0.13, 0.0, TAU, 24, Color(VOID_COLOR, 0.9), maxf(1.0, cell_size * 0.012), true)
		"storm_sigil":
			# Wrath of the Storm: a brooding cloud that throws lightning down.
			var cloud: Vector2 = top + Vector2(0, -cell_size * 0.38)
			for puff: Vector3 in [Vector3(-0.18, 0.02, 0.15), Vector3(0.0, -0.05, 0.19), Vector3(0.19, 0.02, 0.14), Vector3(0.05, 0.06, 0.15)]:
				draw_circle(cloud + Vector2(puff.x, puff.y) * cell_size, puff.z * cell_size, Color("39445a"))
			draw_circle(cloud + Vector2(0, -0.08) * cell_size, 0.12 * cell_size, Color("56657f"))
			if fposmod(_boulder_phase * 1.7, 1.0) < 0.35:
				_draw_zigzag(cloud + Vector2(0, cell_size * 0.1), top + Vector2(0, cell_size * 0.05), Color(STORM_COLOR, 0.95), 2.0, int(_boulder_phase * 5.0))
		"boulders":
			# Heart of the Mountain: a molten core pulsing above the obelisk.
			var core: Vector2 = top + Vector2(0, -cell_size * 0.26)
			draw_circle(core, cell_size * (0.22 + 0.04 * pulse), Color("ff9a2e", 0.20))
			draw_circle(core, cell_size * 0.12, Color("ffb347"))
			draw_circle(core, cell_size * 0.07, Color("fff1b8"))
			for index: int in range(6):
				var angle: float = float(index) * TAU / 6.0 + _boulder_phase * 0.3
				draw_line(core + Vector2(cos(angle), sin(angle)) * cell_size * 0.13, core + Vector2(cos(angle), sin(angle)) * cell_size * (0.2 + 0.05 * pulse), Color("ffcf7a", 0.8), maxf(1.0, cell_size * 0.014), true)
		"pierce":
			_draw_giant_bolt(tower, artwork, rect)
		"bounce":
			_draw_sumggm(tower, artwork, rect)
	_draw_rising_motes(tower, foot, top)


# Endgame sparks spiralling up from the tower, coloured by branch.
func _draw_rising_motes(tower: Dictionary, foot: Vector2, top: Vector2) -> void:
	var colors: Dictionary = {"boulders": Color("ffb347"), "onyx_ring": Color("d9c8ff"), "storm_sigil": STORM_COLOR, "void_monolith": Color("c79bff"), "bounce": MAGIC_CORE, "pierce": Color("ffcf7a"), "crystal_mine": SHARD_COLOR}
	var color: Color = colors.get(tower.get("evolution", ""), MAGIC_CORE)
	var pixel: float = maxf(2.0, roundf(_cell_size() * 0.025))
	for index: int in range(10):
		var life: float = fposmod(_boulder_phase * 0.32 + float(index) * 0.1 + float(int(tower["id"]) % 7) * 0.05, 1.0)
		var x: float = sin(life * TAU * 1.5 + index * 1.7) * _cell_size() * 0.32
		var position: Vector2 = Vector2(foot.x + x, lerpf(foot.y - _cell_size() * 0.1, top.y - _cell_size() * 0.5, life))
		draw_rect(Rect2((position - Vector2.ONE * pixel * 0.5).floor(), Vector2.ONE * pixel), Color(color, sin(life * PI) * 0.9))


# Direction of the displayed directional weapon pose, in screen space.
func _pose_direction(tower: Dictionary) -> Vector2:
	var angle: float = float(_directional_weapon_index(tower)) * PI * 0.25
	return Vector2(sin(angle), -cos(angle))


# The Biggest Wood III: the loaded bolt tip glows forge-hot, shedding pixel
# embers that drift off along the weapon's facing.
func _draw_giant_bolt(tower: Dictionary, artwork: TowerReward, rect: Rect2) -> void:
	var cell_size: float = _cell_size()
	var muzzle: Vector2 = _tower_muzzle(tower, 0)
	var direction: Vector2 = _pose_direction(tower)
	var heat: float = 0.5 + 0.5 * sin(_boulder_phase * 3.0)
	var pixel: float = maxf(2.0, roundf(cell_size * 0.022))
	draw_circle(muzzle, cell_size * (0.07 + 0.02 * heat), Color("ff8a2a", 0.22))
	draw_rect(Rect2((muzzle - Vector2.ONE * pixel).floor(), Vector2.ONE * pixel * 2.0), Color("ffd27a").lerp(Color("fff4d6"), heat))
	for index: int in range(6):
		var life: float = fposmod(_boulder_phase * 0.45 + float(index) / 6.0, 1.0)
		var drift: Vector2 = direction * cell_size * 0.25 * life + Vector2(sin(life * TAU + index) * cell_size * 0.05, -cell_size * 0.22 * life)
		draw_rect(Rect2((muzzle + drift).floor(), Vector2.ONE * pixel), Color("ff9a3a" if index % 2 == 0 else "ffd27a", (1.0 - life) * 0.9))


# S.U.M.G.G.M.: five orbs (one per split bolt) on a wide tilted orbit well
# clear of the sprite, passing behind and in front of the tower with comet
# tails, linked by a faint pentagram.
func _draw_sumggm(tower: Dictionary, artwork: TowerReward, rect: Rect2) -> void:
	_draw_sumggm_orbs(tower, _tower_foot(tower["cell"]), true)


func _sumggm_orb(foot: Vector2, angle: float) -> Vector2:
	var cell_size: float = _cell_size()
	return foot + Vector2(cos(angle) * 1.02, -1.30 + sin(angle) * 0.30) * cell_size


func _draw_sumggm_orbs(tower: Dictionary, foot: Vector2, front: bool) -> void:
	var cell_size: float = _cell_size()
	var spin: float = -1.0 if mirror_horizontal else 1.0
	var turn: float = _flame_elapsed * 1.6 * spin
	var angles: Array[float] = []
	for index: int in range(5):
		angles.append(turn + float(index) * TAU / 5.0)
	if front:
		# Pentagram: each orb links to the orb two places along.
		for index: int in range(5):
			draw_line(_sumggm_orb(foot, angles[index]), _sumggm_orb(foot, angles[(index + 2) % 5]), Color(MAGIC_COLOR, 0.18), maxf(1.0, cell_size * 0.012), true)
	for index: int in range(5):
		var angle: float = angles[index]
		if (sin(angle) >= 0.0) != front:
			continue
		var depth: float = 0.8 + 0.2 * sin(angle)
		for tail: int in range(6, 0, -1):
			var behind: Vector2 = _sumggm_orb(foot, angle - float(tail) * 0.07 * spin)
			draw_circle(behind, cell_size * 0.035 * depth * (1.0 - tail / 7.0), Color(MAGIC_COLOR, 0.45 * (1.0 - tail / 7.0)))
		var orb: Vector2 = _sumggm_orb(foot, angle)
		draw_circle(orb, cell_size * 0.085 * depth, Color(MAGIC_COLOR, 0.28))
		draw_circle(orb, cell_size * 0.048 * depth, Color(MAGIC_COLOR))
		draw_circle(orb, cell_size * 0.022 * depth, Color(MAGIC_CORE))


# Height above the tower foot of ring `index` (0 = lowest) right now. Each
# accepted pulse slams the ring down; it then floats back up. A second ring
# lands a beat later for a double impact.
func _ring_height(tower: Dictionary, index: int) -> float:
	var cell_size: float = _cell_size()
	var top: float = cell_size * (0.78 + 0.22 * index)
	var ground: float = cell_size * (0.04 + 0.05 * index)
	var bob: float = sin(_boulder_phase * 1.3 + index) * cell_size * 0.02
	if not _ring_clocks.has(int(tower["id"])):
		return top + bob
	var t: float = float(_ring_clocks[int(tower["id"])]) - 0.06 * index
	if t < 0.0:
		return top + bob
	if t < RING_FALL:
		var fall: float = t / RING_FALL
		return lerpf(top, ground, fall * fall)
	var rise: float = clampf((t - RING_FALL) / RING_RISE, 0.0, 1.0)
	return lerpf(ground, top, 1.0 - pow(1.0 - rise, 3.0)) + bob * rise


# Onyx Ring(s): a carved onyx band around the obelisk with glowing runes and
# riding stones. Back halves draw behind the sprite, front halves in front.
func _draw_onyx_rings(tower: Dictionary, foot: Vector2, front: bool) -> void:
	var cell_size: float = _cell_size()
	var bought: Array = tower.get("branch_upgrades", [])
	var rings: int = 2 if bought.has("twin_rings") else 1
	var from: float = 0.0 if front else PI
	var stones: int = 3 + int(tower.get("orbit_bonus", 0))
	var spin: float = _boulder_phase * 0.6 * (-1.0 if mirror_horizontal else 1.0)
	for index: int in range(rings):
		var height: float = _ring_height(tower, index)
		var center: Vector2 = foot + Vector2(0, -height)
		var radius := Vector2(cell_size * (0.56 + 0.08 * index), cell_size * (0.21 + 0.03 * index))
		var charge: float = clampf(1.0 - (height - cell_size * 0.05) / (cell_size * 0.6), 0.0, 1.0)
		draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
		draw_arc(Vector2.ZERO, radius.x, from, from + PI, 28, ONYX_STONE, cell_size * 0.085, true)
		draw_arc(Vector2.ZERO, radius.x + cell_size * 0.03, from, from + PI, 28, Color("4a4160"), maxf(1.0, cell_size * 0.012), true)
		draw_arc(Vector2.ZERO, radius.x, from, from + PI, 28, Color(ONYX_GLOW, 0.35 + 0.5 * charge), maxf(1.0, cell_size * 0.016), true)
		# Rune ticks carved into the band, turning with it.
		for tick: int in range(10):
			var angle: float = spin * (1.0 if index == 0 else -1.0) + float(tick) * TAU / 10.0
			if fposmod(angle, TAU) < PI != front:
				continue
			var a := Vector2(cos(angle), sin(angle)) * (radius.x - cell_size * 0.025)
			var b := Vector2(cos(angle + 0.09), sin(angle + 0.09)) * (radius.x + cell_size * 0.02)
			draw_line(a, b, Color("d9c8ff", 0.5 + 0.4 * charge), maxf(1.0, cell_size * 0.012), true)
		draw_set_transform(Vector2.ZERO)
		# Onyx stones ride on the lowest ring.
		if index == 0:
			for stone: int in range(stones):
				var angle: float = spin + float(stone) * TAU / float(stones)
				var offset := Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
				if (offset.y >= 0.0) != front:
					continue
				_draw_rune_stone(center + offset + Vector2(0, -cell_size * 0.05), cell_size * 0.09, angle, true)
	if front and bought.has("obsidian_crown"):
		_draw_obsidian_crown(tower, foot)


# Obsidian Crown: a spiked crown spinning near the obelisk tip, flaring on slams.
func _draw_obsidian_crown(tower: Dictionary, foot: Vector2) -> void:
	var cell_size: float = _cell_size()
	var center: Vector2 = foot + Vector2(0, -cell_size * 1.18)
	var flare: float = 0.0
	if _ring_clocks.has(int(tower["id"])):
		flare = clampf(1.0 - (float(_ring_clocks[int(tower["id"])]) - RING_FALL) / 0.3, 0.0, 1.0)
	var spikes: int = 8
	for spike: int in range(spikes):
		var angle: float = -_boulder_phase * 0.9 + float(spike) * TAU / float(spikes)
		var base := Vector2(cos(angle) * cell_size * 0.20, sin(angle) * cell_size * 0.07)
		var tip: Vector2 = base + Vector2(0, -cell_size * (0.10 + 0.03 * (spike % 2)))
		var width := Vector2(cell_size * 0.03, 0)
		draw_colored_polygon(PackedVector2Array([center + base - width, center + tip, center + base + width]), Color("1a1424"))
		draw_line(center + base, center + tip, Color(ONYX_GLOW, 0.4 + 0.6 * flare), maxf(1.0, cell_size * 0.01), true)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.35))
	draw_arc(Vector2.ZERO, cell_size * 0.2, 0.0, TAU, 24, Color(ONYX_GLOW, 0.5 + 0.5 * flare), maxf(1.0, cell_size * 0.02), true)
	draw_set_transform(Vector2.ZERO)


func _draw_storm_orb(position: Vector2, radius: float, index: int) -> void:
	var flicker: float = 0.75 + 0.25 * sin(_boulder_phase * 9.0 + float(index) * 2.1)
	draw_circle(position, radius * 1.9, Color(STORM_COLOR, 0.22 * flicker))
	draw_circle(position, radius, Color("2f7fb8"))
	draw_circle(position, radius * 0.62, Color(STORM_COLOR, flicker))
	draw_circle(position, radius * 0.28, Color(1, 1, 1, 0.95))


func _draw_void_shard(position: Vector2, radius: float, rotation: float) -> void:
	draw_circle(position, radius * 1.3, Color(VOID_COLOR, 0.18))
	draw_set_transform(position, rotation * 0.4, Vector2(0.7, 1.0) * radius)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -1), Vector2(0.6, 0), Vector2(0, 1), Vector2(-0.6, 0)]), Color("1a0f2e"))
	draw_polyline(PackedVector2Array([Vector2(0, -1), Vector2(0.6, 0), Vector2(0, 1), Vector2(-0.6, 0), Vector2(0, -1)]), Color(VOID_COLOR, 0.95), 0.12, true)
	draw_set_transform(Vector2.ZERO)


func _draw_zigzag(start: Vector2, end: Vector2, color: Color, width: float, seed_value: int) -> void:
	var direction: Vector2 = end - start
	var normal := Vector2(-direction.y, direction.x).normalized() * minf(_cell_size() * 0.08, direction.length() * 0.18)
	var points := PackedVector2Array([start])
	for step: int in range(1, 4):
		points.append(start.lerp(end, float(step) / 4.0) + normal * (1.0 if (step + seed_value) % 2 == 0 else -1.0))
	points.append(end)
	draw_polyline(points, Color(color, color.a * 0.45), width + 2.0, true)
	draw_polyline(points, color, width, true)


# Effects drawn before the tower sprite: the Void drain and the back half of
# the S.U.M.G.G.M. orb orbit.
func _draw_tower_underlay(tower: Dictionary, foot: Vector2) -> void:
	var evolution: String = tower.get("evolution", "")
	var finale: bool = _has_finale(tower)
	if evolution == "void_monolith":
		_draw_void_drain(tower, foot)
	if finale and evolution == "bounce":
		_draw_sumggm_orbs(tower, foot, false)


func _draw_void_drain(tower: Dictionary, foot: Vector2) -> void:
	# Cosmetic tendrils to enemies currently inside the drained neighborhood.
	var origin: Vector2 = foot + Vector2(0, -_cell_size() * 0.5)
	var range_cells: float = float(tower.get("range", 1.0))
	var drawn: int = 0
	for enemy: Dictionary in combat_enemies:
		if drawn >= 8 or float(enemy.get("hp", 0)) <= 0.0 or not MatchCombat.cell_in_range(tower["cell"], Vector2i(Vector2(enemy["pos"]).round()), range_cells):
			continue
		var target: Vector2 = _position_center(_enemy_position(enemy)) + Vector2(0, _cell_size() * 0.05)
		var bend := Vector2(-(target - origin).y, (target - origin).x).normalized() * _cell_size() * 0.12 * sin(_boulder_phase * 3.0 + drawn)
		var points := PackedVector2Array()
		for step: int in range(7):
			var t: float = float(step) / 6.0
			points.append(origin.lerp(target, t) + bend * sin(t * PI))
		draw_polyline(points, Color(VOID_COLOR, 0.30), 4.0, true)
		draw_polyline(points, Color("d6b8ff", 0.55), 1.5, true)
		drawn += 1


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
	var animation: StringName = EnemyVisuals.damage_animation(artwork, &"death", float(trace.get("hp", 1.0)), float(trace.get("max_hp", 1.0)))
	var frame: Texture2D = EnemyVisuals.frame_texture(artwork, animation, float(trace["age"]))
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
	var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, frame, _cell_size() * artwork.board_height, _enemy_render_foot(enemy, item["foot"]), flip)
	var animation: StringName = StringName(enemy.get("animation", "walk"))
	if animation == &"heal" or (animation == &"cast" and artwork.summon_pool.is_empty()):
		EnemyVisuals.draw_action_effect(self, item["foot"], _cell_size() * 0.38, animation, float(enemy.get("animation_elapsed", 0.0)))
	if flip:
		rect.size.x = -rect.size.x
	var burning: bool = bool(enemy.get("burning", false)) and not bool(enemy.get("fire_immune", false))
	var texture: Texture2D = frame
	if burning:
		texture = _burning_texture(frame)
	elif bool(enemy.get("slowed", false)) and not bool(enemy.get("ice_immune", false)):
		texture = _slowed_texture(frame)
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
	return EnemyVisuals.visible_rect(artwork, frame, _cell_size() * artwork.board_height, _enemy_render_foot(enemy, foot), flip)


func _enemy_contains_point(enemy: Dictionary, foot: Vector2, progress: float, position: Vector2) -> bool:
	if not _enemy_sprite_bounds(enemy, foot, progress).has_point(position):
		return false
	var artwork: EnemyDefinition = _enemy_art[enemy["type_id"]]
	var flip: bool = _enemy_faces_left(enemy["route"], progress) != artwork.source_faces_left
	var frame: Texture2D = EnemyVisuals.enemy_texture(artwork, enemy)
	var rect: Rect2 = EnemyVisuals.sprite_rect(artwork, frame, _cell_size() * artwork.board_height, _enemy_render_foot(enemy, foot), flip)
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
	var boss: bool = _enemy_art[enemy["type_id"]].boss
	var bar_size := Vector2(clampf(bounds.size.x * 0.85, _cell_size() * (0.55 if boss else 0.22), _cell_size() * (0.95 if boss else 0.38)),
		maxf(2.0, _cell_size() * (0.055 if boss else 0.04)))
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
		if not bool(tower.get("firing", false)) or float(tower.get("refuel_remaining", 0.0)) > 0.0 or float(tower.get("stunned_remaining", 0.0)) > 0.0:
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
			if trace.get("evolution", "") == "storm_sigil":
				# Each accepted strike is a lightning bolt from the sigil to its victim.
				var sky: Vector2 = _tower_foot(trace["cell"]) + Vector2(0, -_cell_size() * 1.25)
				var index: int = 0
				for hit: Vector2 in trace["hits"]:
					var victim: Vector2 = _position_center(hit) + Vector2(0, _cell_size() * 0.05)
					_draw_zigzag(sky, victim, Color(STORM_COLOR, remaining), 2.0, index + int(trace.get("tower_id", 0)))
					draw_circle(victim, _cell_size() * 0.09 * remaining, Color(1, 1, 1, 0.8 * remaining))
					index += 1
				continue
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
	# An expanding, fading stone ring exists only for a captured discrete shot:
	# the shockwave of the Onyx Ring slamming the ground, with a magic aura.
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.92, Color(ONYX_GLOW, 0.16 * remaining))
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 32, Color(ONYX_GLOW, 0.45 * remaining), maxf(1.0, _cell_size() * 0.025), true)
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
	return _projectile_position_at(trace, float(trace["duration"]) - float(trace["life"]))


# Path -1 is the original bolt; 0.. are the extra Double Magic/S.U.M.G.G.M. bolts.
func _redirect_points(trace: Dictionary, split: int) -> Array:
	if split >= 0:
		return trace.get("split_paths", [])[split]
	var points: Array = trace.get("bounce_points", [])
	return points if not points.is_empty() else [trace["bounce_aim"]]


func _bounce_point(point: Vector2) -> Vector2:
	return _position_center(point) + Vector2(0, _cell_size() * 0.15)


# The accepted redirect leg at this presentation time: its start, end and progress.
func _bounce_leg(trace: Dictionary, elapsed: float, split: int = -1) -> Dictionary:
	var points: Array = _redirect_points(trace, split)
	var leg: float = float(trace.get("bounce_leg", SHOT_DURATION))
	var index: int = clampi(floori((elapsed - SHOT_DURATION) / leg), 0, points.size() - 1)
	var start: Vector2 = _projectile_destination(trace) if index == 0 else _bounce_point(points[index - 1])
	return {"index": index, "start": start, "end": _bounce_point(points[index]),
		"fraction": clampf((elapsed - SHOT_DURATION - index * leg) / leg, 0.0, 1.0)}


func _projectile_position_at(trace: Dictionary, elapsed: float, split: int = -1) -> Vector2:
	var primary: Vector2 = _projectile_destination(trace)
	if bool(trace["pierce_active"]):
		return _projectile_origin(trace).lerp(primary, clampf(elapsed / float(trace["duration"]), 0.0, 1.0))
	if bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION:
		var leg: Dictionary = _bounce_leg(trace, elapsed, split)
		var position: Vector2 = Vector2(leg["start"]).lerp(leg["end"], leg["fraction"])
		if bool(trace.get("magic", false)):
			# Homing arc: swing out sideways, then curve into the next victim.
			# Split bolts fan out to alternating sides with varied swing so they visibly diverge.
			var span: Vector2 = Vector2(leg["end"]) - Vector2(leg["start"])
			var fan: float = 1.0 if split < 0 else SPLIT_FAN[split % SPLIT_FAN.size()]
			var side := Vector2(-span.y, span.x).normalized() * (1.0 if int(leg["index"]) % 2 == 0 else -1.0) * fan
			position += side * sin(float(leg["fraction"]) * PI) * minf(_cell_size() * 0.7, span.length() * 0.35)
		return position
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
		var bolt_art: TowerReward = _tower_art.get(trace["type_id"])
		if bolt_art != null and not bolt_art.directional_weapon_textures.is_empty():
			_draw_ballista_bolt(trace, elapsed)
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


# A heavy Ballista bolt: dark-outlined shaft, iron head and fins, scaled by
# Biggest Wood. On its first leg it grows out of the muzzle instead of appearing
# whole over the masonry. Magic bolts glow violet and leave a sparkling trail.
func _draw_ballista_bolt(trace: Dictionary, elapsed: float) -> void:
	var leg: float = float(trace.get("bounce_leg", SHOT_DURATION))
	for split: int in range(-1, trace.get("split_paths", []).size()):
		if split >= 0 and (_redirect_points(trace, split).is_empty() or elapsed < SHOT_DURATION):
			continue
		# A chain that already reached its last victim stops drawing its bolt.
		if bool(trace["bounce_active"]) and elapsed > SHOT_DURATION + leg * _redirect_points(trace, split).size() + 0.000001:
			continue
		_draw_ballista_bolt_path(trace, elapsed, split)
	if bool(trace.get("magic", false)):
		_draw_magic_impacts(trace, elapsed, maxf(2.0, roundf(_cell_size() * BALLISTA_BOLT_WIDTH * float(trace.get("bolt_scale", 1.0)))))


func _draw_ballista_bolt_path(trace: Dictionary, elapsed: float, split: int) -> void:
	var cell_size: float = _cell_size()
	var scale: float = float(trace.get("bolt_scale", 1.0))
	var magic: bool = bool(trace.get("magic", false))
	var tip: Vector2 = _projectile_position_at(trace, elapsed, split)
	var direction: Vector2 = (tip - _projectile_position_at(trace, maxf(0.0, elapsed - 0.01), split)).normalized()
	if direction == Vector2.ZERO:
		direction = (_projectile_destination(trace) - _projectile_origin(trace)).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var width: float = maxf(2.0, roundf(cell_size * BALLISTA_BOLT_WIDTH * scale))
	var length: float = cell_size * BALLISTA_BOLT_LENGTH * scale
	var redirected: bool = bool(trace["bounce_active"]) and elapsed >= SHOT_DURATION
	if not redirected:
		length = minf(length, _projectile_origin(trace).distance_to(tip))
	_draw_bolt_trail(trace, elapsed, width, magic, split)
	if length < 1.0:
		return
	var side := Vector2(-direction.y, direction.x)
	var tail: Vector2 = tip - direction * length
	var head_length: float = minf(length * 0.45, maxf(4.0, length * 0.26))
	var head_width: float = width * 1.5 + 1.0
	var neck: Vector2 = tip - direction * head_length
	var outline := Color("2a1745") if magic else Color("33241a")
	var shaft := Color("8f6fd8") if magic else Color("a57a45")
	var fin := Color("cdb2ff") if magic else Color("e2d6b0")
	var iron := Color("efe4ff") if magic else Color("a7adb0")
	if magic:
		draw_line(tail, tip, Color(MAGIC_COLOR, 0.30), width + 6.0, true)
	draw_line(tail, neck, outline, width + 2.0, true)
	draw_line(tail, neck, shaft, width, true)
	var fin_length: float = length * 0.24
	var fin_width: float = width * 1.4 + 1.0
	for fin_side: float in [-1.0, 1.0]:
		var fin_points := PackedVector2Array([tail, tail + direction * fin_length, tail + direction * fin_length * 0.25 + side * fin_width * fin_side])
		draw_colored_polygon(fin_points, fin)
	var head := PackedVector2Array([tip, neck + side * head_width, neck + direction * head_length * 0.25, neck - side * head_width])
	draw_colored_polygon(head, iron)
	draw_polyline(PackedVector2Array([neck + side * head_width, tip, neck - side * head_width]), outline, 1.0, true)
	if magic:
		draw_circle(tip, width * 2.2, Color(MAGIC_COLOR, 0.35))
		draw_circle(tip, width * 1.0, Color(MAGIC_CORE, 0.85))


func _draw_bolt_trail(trace: Dictionary, elapsed: float, width: float, magic: bool, split: int = -1) -> void:
	var samples: int = 10 if magic else 3
	var spacing: float = 0.014 if magic else 0.008
	var previous: Vector2 = _projectile_position_at(trace, elapsed, split)
	for index: int in range(1, samples + 1):
		var time: float = elapsed - float(index) * spacing
		if time < 0.0:
			break
		var point: Vector2 = _projectile_position_at(trace, time, split)
		var fade: float = 1.0 - float(index) / float(samples + 1)
		if magic:
			draw_line(previous, point, Color(MAGIC_COLOR, 0.22 * fade), width * (1.5 + 3.5 * fade), true)
			draw_line(previous, point, Color(MAGIC_COLOR, 0.75 * fade), width * (0.6 + 1.8 * fade), true)
			if index % 2 == 0:
				# Deterministic sparkle offsets: identical on every redraw of this trace.
				var jitter := Vector2(sin(float(index * 7 + int(trace["tower_id"]))), cos(float(index * 5))) * width * 1.5
				var pixel: float = maxf(1.0, roundf(width * 0.7))
				draw_rect(Rect2((point + jitter - Vector2.ONE * pixel * 0.5).floor(), Vector2.ONE * pixel), Color(MAGIC_CORE, 0.8 * fade))
		else:
			draw_line(previous, point, Color(0.93, 0.89, 0.76, 0.25 * fade), width * 0.8, true)
		previous = point


func _draw_magic_impacts(trace: Dictionary, elapsed: float, width: float) -> void:
	var leg: float = float(trace.get("bounce_leg", MAGIC_BOUNCE_DURATION))
	var points: Array = trace.get("bounce_points", []).duplicate()
	var indices: Array[int] = []
	for index: int in range(points.size()):
		indices.append(index)
	for path: Array in trace.get("split_paths", []):
		for index: int in range(path.size()):
			points.append(path[index])
			indices.append(index)
	for index: int in range(-1, points.size()):
		var hit_time: float = SHOT_DURATION + float((indices[index] if index >= 0 else -1) + 1) * leg
		var age: float = elapsed - hit_time
		if age < 0.0 or age > 0.16:
			continue
		var center: Vector2 = _projectile_destination(trace) if index < 0 else _bounce_point(points[index])
		var phase: float = age / 0.16
		draw_arc(center, width * (2.0 + 5.0 * phase), 0.0, TAU, 16, Color(MAGIC_COLOR, 0.8 * (1.0 - phase)), maxf(1.0, width * 0.6), true)
		draw_circle(center, width * 1.4 * (1.0 - phase), Color(MAGIC_CORE, 0.7 * (1.0 - phase)))


# Magic Ballista: a faint rune ring on the turret, a charged violet bolt tip at
# the live muzzle, and three orbiting motes. Purely cosmetic and local.
func _draw_magic_ballista(tower: Dictionary, artwork: TowerReward, rect: Rect2) -> void:
	var cell_size: float = _cell_size()
	var pulse: float = 0.5 + 0.5 * sin(_flame_elapsed * 4.0)
	var canvas: Vector2 = _directional_canvas_sizes[artwork]
	var center: Vector2 = rect.position + Vector2(canvas.x * 0.5, canvas.y * 0.36) * rect.size / canvas
	if _has_finale(tower):
		# The S.U.M.G.G.M. orbs replace the small ring and motes; keep the charged tip.
		var tip: Vector2 = _tower_muzzle(tower, 0)
		draw_circle(tip, cell_size * (0.065 + 0.02 * pulse), Color(MAGIC_COLOR, 0.40))
		draw_circle(tip, cell_size * 0.03, Color(MAGIC_CORE, 0.95))
		return
	draw_set_transform(center, 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, cell_size * 0.30, 0.0, TAU, 24, Color(MAGIC_COLOR, 0.35 + 0.25 * pulse), maxf(1.0, cell_size * 0.018), true)
	draw_set_transform(Vector2.ZERO)
	for index: int in range(3):
		var angle: float = _flame_elapsed * 1.8 + float(index) * TAU / 3.0
		var mote: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.45) * cell_size * 0.42 + Vector2(0, -cell_size * 0.08)
		var pixel: float = maxf(2.0, roundf(cell_size * 0.028))
		draw_rect(Rect2((mote - Vector2.ONE * pixel * 0.5).floor(), Vector2.ONE * pixel), Color(MAGIC_COLOR, 0.65 + 0.3 * pulse))
	var muzzle: Vector2 = _tower_muzzle(tower, 0)
	draw_circle(muzzle, cell_size * (0.055 + 0.015 * pulse), Color(MAGIC_COLOR, 0.40))
	draw_circle(muzzle, cell_size * 0.026, Color(MAGIC_CORE, 0.9))


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


func _enemy_render_foot(enemy: Dictionary, ground_foot: Vector2) -> Vector2:
	var lift: float = EnemyVisuals.jump_lift(enemy)
	var blend: Vector2 = _enemy_lifts.get(int(enemy["id"]), Vector2(lift, lift))
	return ground_foot - Vector2(0.0, lerpf(blend.x, blend.y, _enemy_blend_elapsed / ENEMY_BLEND_DURATION) * _cell_size())


func _capture_boss_actions() -> void:
	var active: Dictionary[int, bool] = {}
	for enemy: Dictionary in combat_enemies:
		var id: int = int(enemy["id"])
		active[id] = true
		var count := Vector2i(int(enemy.get("tower_attack_count", 0)), int(enemy.get("stomp_count", 0)))
		var previous: Vector2i = _boss_seen_enemy.get(id, Vector2i(0, count.y))
		var definition: EnemyDefinition = _enemy_art.get(enemy["type_id"])
		if definition == null:
			continue
		if count.x > previous.x and definition.tower_attack_kind == &"cannon" and float(enemy.get("tower_attack_remaining", 0.0)) > 0.0:
			var duration: float = maxf(0.001, definition.tower_attack_cast_duration)
			for aim: Vector2 in enemy.get("tower_attack_aims", []):
				_boss_effects.append({"kind": "cannon", "from": enemy["pos"], "to": aim, "age": maxf(0.0, duration - float(enemy["tower_attack_remaining"])), "duration": duration})
		if count.y > previous.y:
			_boss_effects.append({"kind": "stomp", "pos": enemy["pos"], "radius": definition.stomp_radius, "age": 0.0, "duration": 0.55})
		_boss_seen_enemy[id] = count
	for id: int in _boss_seen_enemy.keys():
		if not active.has(id):
			_boss_seen_enemy.erase(id)
	_limit_boss_effects()


func _capture_stuns() -> void:
	var active: Dictionary[int, bool] = {}
	for tower: Dictionary in combat_towers:
		var id: int = int(tower["id"])
		active[id] = true
		var count: int = int(tower.get("stun_count", 0))
		if count > int(_boss_seen_stuns.get(id, count)):
			_boss_effects.append({"kind": "stun", "pos": Vector2(tower["cell"]), "source": tower.get("stun_source", ""), "age": 0.0, "duration": 0.48})
		_boss_seen_stuns[id] = count
	for id: int in _boss_seen_stuns.keys():
		if not active.has(id):
			_boss_seen_stuns.erase(id)
	_limit_boss_effects()


func _limit_boss_effects() -> void:
	while _boss_effects.size() > MAX_SHOT_TRACES:
		_boss_effects.pop_front()


func _draw_boss_telegraphs() -> void:
	var cell_size: float = _cell_size()
	for enemy: Dictionary in combat_enemies:
		var locomotion: String = enemy.get("locomotion", "path")
		if locomotion in ["jump_deploy", "jump_charge", "jump", "jump_land"] and enemy.has("jump_to"):
			var landing: Vector2 = _position_center(enemy["jump_to"])
			var rect := Rect2(landing - Vector2.ONE * cell_size * 0.38, Vector2.ONE * cell_size * 0.76)
			draw_rect(rect, Color(0.90, 0.66, 0.27, 0.12))
			draw_rect(rect, Color(0.95, 0.73, 0.33, 0.85), false, 2.0)
			var foot: Vector2 = _position_center(_enemy_position(enemy))
			if locomotion in ["jump_deploy", "jump_charge"]:
				var phase: float = 0.5 + sin(float(enemy.get("animation_elapsed", 0.0)) * 12.0) * 0.5
				draw_line(foot, landing, Color(0.93, 0.70, 0.31, 0.25 + phase * 0.35), 2.0)
				draw_set_transform(foot, 0.0, Vector2(1.0, 0.35))
				draw_arc(Vector2.ZERO, cell_size * (0.48 + phase * 0.12), 0.0, TAU, 24, Color(0.95, 0.73, 0.33, 0.80), 2.0, false)
				draw_set_transform(Vector2.ZERO)
		if float(enemy.get("tower_attack_remaining", 0.0)) > 0.0:
			for aim: Vector2 in enemy.get("tower_attack_aims", []):
				var target: Vector2 = _position_center(aim)
				draw_set_transform(target, 0.0, Vector2(1.0, 0.4))
				draw_arc(Vector2.ZERO, cell_size * 0.33, 0.0, TAU, 24, Color(0.94, 0.45, 0.27, 0.9), 2.0, false)
				draw_set_transform(Vector2.ZERO)


func _draw_boss_effects() -> void:
	var cell_size: float = _cell_size()
	var pixel: float = maxf(1.0, floorf(cell_size * 0.025))
	for effect: Dictionary in _boss_effects:
		var phase: float = clampf(float(effect["age"]) / float(effect["duration"]), 0.0, 1.0)
		if effect["kind"] == "cannon":
			# This trajectory only exists after an accepted host attack/aim.
			# Its arrival coincides with the accepted windup boundary; impacts
			# are separate stun-count facts, not a local gameplay prediction.
			var flight: float = minf(0.36, float(effect["duration"]))
			var travel: float = (float(effect["age"]) - float(effect["duration"]) + flight) / flight
			if travel < 0.0:
				continue
			var start: Vector2 = _position_center(effect["from"]) + Vector2(0.0, -cell_size * 0.46)
			var end: Vector2 = _position_center(effect["to"]) + Vector2(0.0, -cell_size * 0.50)
			var point: Vector2 = start.lerp(end, travel) - Vector2(0.0, sin(travel * PI) * cell_size * 0.35)
			var tail: Vector2 = point + (start - end).normalized() * pixel * 7.0
			draw_line(tail.floor(), point.floor(), Color("c28a4e"), pixel * 3.0)
			draw_rect(Rect2(point.floor() - Vector2.ONE * pixel * 3.0, Vector2.ONE * pixel * 6.0), Color("24292c"))
			draw_rect(Rect2(point.floor() - Vector2.ONE * pixel * 2.0, Vector2.ONE * pixel * 2.0), Color("93938a"))
		elif effect["kind"] == "stomp":
			var foot: Vector2 = _position_center(effect["pos"]) + Vector2(0.0, cell_size * 0.28)
			var radius: float = maxf(0.3, float(effect["radius"])) * cell_size
			draw_set_transform(foot, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, radius * (0.2 + phase * 0.8), 0.0, TAU, 32, Color(0.76, 0.64, 0.44, 1.0 - phase), pixel * 2.0, false)
			draw_set_transform(Vector2.ZERO)
			for index: int in range(7):
				var angle: float = float(index) * TAU / 7.0
				var dust: Vector2 = foot + Vector2(cos(angle), sin(angle) * 0.42) * radius * phase
				draw_rect(Rect2(dust.floor(), Vector2(pixel * 3.0, pixel * 2.0)), Color(0.65, 0.57, 0.40, 1.0 - phase))
		elif effect["kind"] == "stun":
			var point: Vector2 = _position_center(effect["pos"]) - Vector2(0.0, cell_size * 0.48)
			if effect.get("source", "") == "club":
				draw_line(point + Vector2(-cell_size * 0.28, -cell_size * 0.26), point + Vector2(cell_size * 0.22, cell_size * 0.10), Color(0.84, 0.64, 0.35, 1.0 - phase), pixel * 3.0)
			for index: int in range(6):
				var angle: float = float(index) * TAU / 6.0
				var start: Vector2 = point + Vector2(cos(angle), sin(angle)) * cell_size * (0.12 + phase * 0.28)
				draw_line(start, start + Vector2(cos(angle), sin(angle)) * pixel * 4.0, Color(1.0, 0.83, 0.38, 1.0 - phase), pixel * 2.0)


func _draw_stun_stars(tower: Dictionary, foot: Vector2, front: bool) -> void:
	var remaining: float = float(tower.get("stunned_remaining", 0.0))
	if remaining <= 0.0:
		return
	var cell_size: float = _cell_size()
	var center: Vector2 = _tower_stun_center(tower, foot)
	var radius: float = maxf(3.0, cell_size * 0.085)
	for index: int in range(3):
		# Actual remaining sim time drives the orbit: pause cannot consume stun.
		var angle: float = -remaining * 2.6 + float(index) * TAU / 3.0
		if (sin(angle) >= 0.0) != front:
			continue
		var point: Vector2 = center + Vector2(cos(angle) * cell_size * 0.31, sin(angle) * cell_size * 0.10)
		draw_set_transform(point.round(), 0.0, Vector2.ONE * radius)
		draw_colored_polygon(_stun_star_shape, Color("f5ce56"))
		draw_polyline(_stun_star_shape, Color("8c5b2c"), maxf(1.0, cell_size * 0.018) / radius, false)
		draw_set_transform(Vector2.ZERO)


func _tower_stun_center(tower: Dictionary, foot: Vector2) -> Vector2:
	var cell_size: float = _cell_size()
	var artwork: TowerReward = _tower_art.get(tower["type_id"])
	if artwork == null or artwork.icon_texture == null:
		return foot - Vector2(0.0, cell_size * 1.15)
	var variant: Dictionary = _tower_variant(tower, artwork)
	var texture: Texture2D = variant.get("texture", artwork.icon_texture)
	var rect: Rect2 = _sprite_rect(texture, float(variant.get("board_height", artwork.board_height)), variant.get("board_anchor", artwork.board_anchor), foot)
	var scale: float = rect.size.y / texture.get_height()
	var top: float = rect.position.y + _texture_bounds[texture].position.y * scale
	if artwork.archer_head_texture != null:
		var definition: Dictionary = tower_types.get(tower["type_id"], {})
		var advancement: Dictionary = _archer_advancement(tower, definition)
		var count: int = int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) and definition.get("special_upgrade", "") == "second_archer" else 1))
		var pivot: Vector2 = variant.get("archer_pivot", artwork.archer_pivot)
		for index: int in range(count):
			var offset: Vector2 = _archer_offset(artwork, index, variant)
			top = minf(top, rect.position.y + (pivot.y + offset.y - 15.0) * scale)
	return Vector2(foot.x, top - cell_size * 0.07)
