class_name SandboxController
extends RefCounted
## Session-local playground; gameplay transactions always belong to MatchCombat.

signal changed

var layout: PathLayout
var combat: MatchCombat
var rules: CombatRules
var round_number: int = 1
var paused: bool = true
var speed: float = 1.0
var active: bool = false
var state: Dictionary = {}
var _snapshot_elapsed: float = 0.0


func configure(catalog: ContentCatalog, source_rules: CombatRules) -> void:
	rules = source_rules.duplicate() as CombatRules
	rules.catalog = catalog
	rules.sandbox_mode = true
	layout = _new_layout(Vector2i(14, 9))
	combat = MatchCombat.new(rules)
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
	combat = MatchCombat.new(rules)
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
		paused = false
		_publish()
	return accepted


func spawn(type_id: StringName, count: int) -> bool:
	if count < 1 or not layout.is_ready():
		return false
	# Reject an unknown type before replacing any current simulation.
	if not state.get("enemy_types", {}).has(String(type_id)):
		return false
	if combat.phase != MatchCombat.Phase.WAVE:
		var roster: Array[String] = []
		if not combat.sandbox_start(_routing(), round_number, roster):
			return false
	var accepted: bool = combat.sandbox_spawn(0, type_id, count)
	if accepted:
		_publish()
	return accepted


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
	combat = MatchCombat.new(rules)
	combat.debug_set_round(round_number)
	paused = true
	_publish()


func build(cell: Vector2i, type_id: StringName, mode: int = MatchCombat.TargetMode.FURTHEST) -> bool:
	if not layout.contains(cell) or layout.has_path(cell):
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


func sell(tower_id: int) -> bool:
	var accepted: bool = combat.sell_tower(0, tower_id)
	if accepted:
		_publish()
	return accepted


func set_targeting(tower_id: int, mode: int, secondary: bool = false) -> bool:
	var accepted: bool = combat.set_secondary_targeting(0, tower_id, mode) if secondary else combat.set_targeting(0, tower_id, mode)
	if accepted:
		_publish()
	return accepted


func set_archer_targeting(tower_id: int, archer_index: int, mode: int) -> bool:
	var accepted: bool = combat.set_archer_targeting(0, tower_id, archer_index, mode)
	if accepted:
		_publish()
	return accepted


func _new_layout(dimensions: Vector2i) -> PathLayout:
	var row: int = floori(float(dimensions.y) * 0.5)
	return PathLayout.new(dimensions, dimensions.x * dimensions.y - 2, Vector2i(0, row), Vector2i(dimensions.x - 1, row))


func _routing() -> Array[Dictionary]:
	var captured: Dictionary = layout.capture_routing()
	return [captured, captured]


func _publish() -> void:
	_snapshot_elapsed = 0.0
	state = combat.snapshot()
	changed.emit()
