class_name SandboxController
extends RefCounted
## Session-local playground; gameplay transactions always belong to MatchCombat.

signal changed

enum TestKind { NONE, WAVE, SPAWN }

var layout: PathLayout
var combat: MatchCombat
var rules: CombatRules
var round_number: int = 1
var paused: bool = true
var speed: float = 1.0
var active: bool = false
var state: Dictionary = {}
var _snapshot_elapsed: float = 0.0
var _last_test_kind: TestKind = TestKind.NONE
var _last_spawn_type: StringName = &""
var _last_spawn_count: int = 0
# Reset/resize start a fresh run with this session's current ownership, not its
# consumed flags, cooldowns, growth, or item rewards. Stop only abandons a wave.
var _session_items: Array[String] = []


func configure(catalog: ContentCatalog, source_rules: CombatRules) -> void:
	rules = source_rules.duplicate() as CombatRules
	rules.catalog = catalog
	rules.sandbox_mode = true
	layout = _new_layout(Vector2i(14, 9))
	combat = null
	_session_items.clear()
	if not source_rules.starting_items.is_empty():
		for id: String in source_rules.starting_items[0]:
			_session_items.append(id)
	_new_combat()
	_publish()


func set_active(value: bool) -> void:
	active = value
	if not value:
		paused = true
	_publish()


func advance(delta: float) -> void:
	if not active or paused or combat.phase != MatchCombat.Phase.WAVE:
		return
	combat.advance(delta * speed)
	_snapshot_elapsed += delta
	if combat.phase != MatchCombat.Phase.WAVE:
		paused = true
	if _snapshot_elapsed >= 0.1 or paused:
		_publish()


func edit_path(cell: Vector2i, place: bool) -> bool:
	if combat.phase != MatchCombat.Phase.PLANNING or combat.has_tower(0, cell):
		return false
	var accepted: bool = layout.place(cell) if place else layout.erase(cell)
	if accepted:
		_publish()
	return accepted


func clear_path() -> void:
	if combat.phase == MatchCombat.Phase.PLANNING:
		layout.clear()
		_publish()


func resize_map(dimensions: Vector2i) -> bool:
	if dimensions.x < 2 or dimensions.y < 1:
		return false
	layout = _new_layout(dimensions)
	_new_combat()
	combat.debug_set_round(round_number)
	paused = true
	_publish()
	return true


func set_round(value: int) -> bool:
	if value < 1:
		return false
	round_number = value
	return stop()


func start_wave() -> bool:
	if not layout.is_ready():
		return false
	var accepted: bool = combat.sandbox_start_wave(_routing(), round_number)
	if accepted:
		_last_test_kind = TestKind.WAVE
		paused = false
		_publish()
	return accepted


func spawn(type_id: StringName, count: int) -> bool:
	if count < 1 or not layout.is_ready():
		return false
	# Reject an unknown type before replacing any current simulation.
	if not state.get("enemy_types", {}).has(String(type_id)):
		return false
	if combat.phase != MatchCombat.Phase.WAVE and not _start_empty_wave():
		return false
	var accepted: bool = combat.sandbox_spawn(0, type_id, count)
	if accepted:
		_last_test_kind = TestKind.SPAWN
		_last_spawn_type = type_id
		_last_spawn_count = count
		_publish()
	return accepted


func can_restart() -> bool:
	return _last_test_kind != TestKind.NONE and layout.is_ready()


func restart() -> bool:
	if not can_restart():
		return false
	if _last_test_kind == TestKind.WAVE:
		return start_wave()
	# The combat owner validates and abandons the old stream before the exact batch.
	if not _start_empty_wave():
		return false
	if not spawn(_last_spawn_type, _last_spawn_count):
		return false
	set_paused(false)
	return true


func set_paused(value: bool) -> void:
	paused = value
	_publish()


func toggle_play() -> bool:
	if combat.phase != MatchCombat.Phase.WAVE:
		return start_wave()
	paused = not paused
	_publish()
	return true


func stop() -> bool:
	var accepted: bool = combat.debug_set_round(round_number)
	if accepted:
		paused = true
		_publish()
	return accepted


func reset_build() -> void:
	_new_combat()
	combat.debug_set_round(round_number)
	paused = true
	_publish()


func build(cell: Vector2i, type_id: StringName, mode: int = MatchCombat.TargetMode.FURTHEST) -> bool:
	var footprint: Vector2i = combat.tower_footprint(type_id)
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	var occupied: Rect2i = TowerDefinition.footprint_rect(cell, footprint)
	for y: int in range(occupied.position.y, occupied.end.y):
		for x: int in range(occupied.position.x, occupied.end.x):
			var covered := Vector2i(x, y)
			if not layout.contains(covered) or layout.has_path(covered):
				return false
	var accepted: bool = combat.build(0, cell, type_id, mode)
	if accepted:
		_publish()
	return accepted


func upgrade(tower_id: int, command: String) -> bool:
	var accepted: bool = combat.upgrade_tower(0, tower_id, command)
	if accepted:
		_publish()
	return accepted


func reroll_tower(tower_id: int, kind: String, requested: Variant = 1) -> bool:
	var accepted: bool = combat.reroll_tower(0, tower_id, kind, requested)
	if accepted:
		_publish()
	return accepted


func sell(tower_id: int) -> bool:
	var accepted: bool = combat.sell_tower(0, tower_id)
	if accepted:
		_publish()
	return accepted


func set_targeting(tower_id: int, mode: int) -> bool:
	var accepted: bool = combat.set_targeting(0, tower_id, mode)
	if accepted:
		_publish()
	return accepted



func set_items(ids: Array) -> bool:
	var accepted: bool = combat.set_items(0, ids)
	if accepted:
		_session_items.assign(combat.item_runtime.owned_ids(0))
		_publish()
	return accepted


func add_item(id: StringName) -> bool:
	var accepted: bool = combat.grant_item(0, id)
	if accepted:
		_session_items.assign(combat.item_runtime.owned_ids(0))
		_publish()
	return accepted


func remove_item(id: StringName) -> bool:
	var accepted: bool = combat.remove_item(0, id)
	if accepted:
		_session_items.assign(combat.item_runtime.owned_ids(0))
		_publish()
	return accepted


func item_command(id: StringName, action: String, target_id: int = -1) -> bool:
	if action not in ["active", "bind", "feed", "upgrade"]:
		return false
	var accepted: bool = combat.item_command(0, id, action, target_id)
	if accepted:
		_session_items.assign(combat.item_runtime.owned_ids(0))
		_publish()
	return accepted


func set_item_funds(coins: int, shards: int) -> bool:
	if coins < 0 or shards < 0:
		return false
	combat.coins[0] = coins
	combat.reroll_currency[0] = shards
	_publish()
	return true


func _new_combat() -> void:
	# Ownership is session-local. Replacing the model never changes collection.
	if combat != null:
		_session_items.assign(combat.item_runtime.owned_ids(0))
	var captured_rules: CombatRules = rules.duplicate() as CombatRules
	captured_rules.starting_items = [PackedStringArray(_session_items), PackedStringArray()]
	combat = MatchCombat.new(captured_rules)
	var tower_ids: Array[String] = []
	for definition: TowerDefinition in rules.catalog.towers:
		if definition != null and definition.reward != null:
			tower_ids.append(String(definition.reward.id))
	combat.configure_item_loadouts([tower_ids, tower_ids.duplicate()])
	_session_items.assign(combat.item_runtime.owned_ids(0))

func _new_layout(dimensions: Vector2i) -> PathLayout:
	var row: int = floori(float(dimensions.y) * 0.5)
	return PathLayout.new(dimensions, dimensions.x * dimensions.y - 2, Vector2i(0, row), Vector2i(dimensions.x - 1, row))


func _start_empty_wave() -> bool:
	var roster: Array[String] = []
	return combat.sandbox_start(_routing(), round_number, roster)


func _routing() -> Array[Dictionary]:
	var captured: Dictionary = layout.capture_routing()
	return [captured, captured]


func _publish() -> void:
	_snapshot_elapsed = 0.0
	state = combat.snapshot()
	changed.emit()
