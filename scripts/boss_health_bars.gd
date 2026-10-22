class_name BossHealthBars
extends VBoxContainer
## Bosses alive on one board, read from accepted snapshots only.
## Damage leaves a short pale trail that drains after a brief hold; a slain
## boss drains to empty before its row fades. Nothing here feeds gameplay.

signal boss_selected(enemy_id: int)

const MAX_ROWS: int = 3
const ROW_SIZE := Vector2(288, 50)
const NUMBERS: FontFile = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const PANEL := Color(0.10, 0.145, 0.13, 0.96)
const BORDER := Color(0.40, 0.46, 0.40)
const SELECTED := Color("e0bc77")
const TRACK := Color(0.055, 0.085, 0.07)
const FILL := Color(0.70, 0.34, 0.31)
const ENRAGED := Color("d2552f")
const IMMUNE := Color("8f7cc4")
const SHIELD := Color("ead58c")
const TRAIL := Color("eadbb0")
const TRAIL_HOLD: float = 0.35
const FADE_SECONDS: float = 0.45

var catalog: ContentCatalog
var selected_id: int = -1:
	set(value):
		selected_id = value
		for row: Row in _rows.values():
			row.queue_redraw()
var _rows: Dictionary[int, Row] = {}
## One HP column for every row, so stacked bars share a length.
var number_width: float = 44.0
var _definitions: Dictionary[String, EnemyDefinition] = {}


func _init() -> void:
	name = "BossHealthBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	hide()


## Mirrors the accepted bosses on `enemies`; `deaths` distinguishes a kill from a leak.
func refresh(enemies: Array, types: Dictionary, deaths: Array = []) -> void:
	var alive: Dictionary[int, Dictionary] = {}
	for enemy: Dictionary in enemies:
		var stats: Dictionary = types.get(String(enemy.get("type_id", "")), {})
		if bool(stats.get("boss", false)) and int(enemy.get("hp", 0)) > 0:
			alive[int(enemy["id"])] = enemy
	var slain: Dictionary[int, bool] = {}
	for event: Dictionary in deaths:
		slain[int(event.get("enemy_id", -1))] = true
	for id: int in _rows.keys():
		if not alive.has(id):
			_rows[id].depart(slain.has(id))
	var ids: Array[int] = alive.keys()
	ids.sort()
	for id: int in ids:
		var enemy: Dictionary = alive[id]
		if _rows.has(id) and _rows[id].departing:
			# A reset run may reuse an ID while its predecessor still fades.
			_rows[id].queue_free()
			_rows.erase(id)
		if not _rows.has(id):
			if _living_rows() >= MAX_ROWS:
				continue
			var row := Row.new()
			row.owner_bars = self
			row.enemy_id = id
			row.definition = _definition(String(enemy["type_id"]))
			row.title = String(types[String(enemy["type_id"])].get("title", enemy["type_id"]))
			row.enrage_fraction = float(types[String(enemy["type_id"])].get("enrage_health_fraction", 0.0))
			_rows[id] = row
			add_child(row)
		_rows[id].accept(enemy)
	var widest: float = 38.0
	for row: Row in _rows.values():
		widest = maxf(widest, NUMBERS.get_string_size(str(int(row.max_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	if not is_equal_approx(widest + 6.0, number_width):
		number_width = widest + 6.0
		for row: Row in _rows.values():
			row.queue_redraw()
	_order_rows()
	visible = not _rows.is_empty()


## Drops every row immediately, for a new run, hidden screen, or results.
func clear() -> void:
	for row: Row in _rows.values():
		row.queue_free()
	_rows.clear()
	hide()


func row_for(enemy_id: int) -> Control:
	return _rows.get(enemy_id)


func shown_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in _rows:
		if not _rows[id].departing:
			result.append(id)
	result.sort()
	return result


func _living_rows() -> int:
	var count: int = 0
	for row: Row in _rows.values():
		if not row.departing:
			count += 1
	return count


func _order_rows() -> void:
	var ids: Array[int] = _rows.keys()
	ids.sort()
	for index: int in range(ids.size()):
		move_child(_rows[ids[index]], index)


func _definition(type_id: String) -> EnemyDefinition:
	if not _definitions.has(type_id) and catalog != null:
		for definition: EnemyDefinition in catalog.enemies:
			if definition != null and String(definition.id) == type_id:
				_definitions[type_id] = definition
	return _definitions.get(type_id)


## A head-and-shoulders crop: the top square of the opaque artwork.
static func portrait_region(texture: Texture2D) -> Rect2:
	var bounds: Rect2 = EnemyVisuals.opaque_bounds(texture)
	var side: float = minf(bounds.size.x, bounds.size.y)
	return Rect2(bounds.position.x + (bounds.size.x - side) * 0.5, bounds.position.y, side, side)


func _row_finished(row: Row) -> void:
	_rows.erase(row.enemy_id)
	row.queue_free()
	if _rows.is_empty():
		hide()


class Row extends Control:
	var owner_bars: BossHealthBars
	var enemy_id: int = -1
	var definition: EnemyDefinition
	var title: String = ""
	var enrage_fraction: float = 0.0
	var departing: bool = false
	var hp: float = 0.0
	var max_hp: float = 1.0
	## Pale trail of recently lost HP; it lags `hp` and drains toward it.
	var trail: float = 0.0
	var enraged: bool = false
	var immune: bool = false
	var shielded: bool = false
	var _hold: float = 0.0
	var _flash: float = 0.0
	var _fade: float = -1.0
	var _portrait: Texture2D
	var _portrait_region := Rect2()

	func _init() -> void:
		custom_minimum_size = BossHealthBars.ROW_SIZE
		size = BossHealthBars.ROW_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_process(false)

	func _ready() -> void:
		if definition != null and definition.texture != null:
			_portrait = definition.texture
			_portrait_region = BossHealthBars.portrait_region(_portrait)

	func accept(enemy: Dictionary) -> void:
		var next_max: float = maxf(1.0, float(enemy.get("max_hp", 1)))
		var next_hp: float = clampf(float(enemy.get("hp", 0)), 0.0, next_max)
		if max_hp != next_max or next_hp >= trail or trail <= 0.0:
			trail = next_hp
		elif next_hp < hp:
			_hold = BossHealthBars.TRAIL_HOLD
			_flash = 0.14
		max_hp = next_max
		hp = next_hp
		enraged = bool(enemy.get("enraged", false))
		immune = bool(enemy.get("spell_shielded", false)) or bool(enemy.get("warded", false))
		shielded = int(enemy.get("shield_hits", 0)) > 0
		_sync_processing()
		queue_redraw()

	## A slain boss drains to empty first; a leaked one simply fades.
	func depart(slain: bool) -> void:
		if departing:
			return
		departing = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		if slain:
			trail = maxf(trail, hp)
			hp = 0.0
			_hold = 0.1
			_flash = 0.14
		_fade = BossHealthBars.FADE_SECONDS + (0.35 if slain else 0.0)
		_sync_processing()

	func _sync_processing() -> void:
		set_process(departing or trail > hp + 0.001 or _flash > 0.0)

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta)
		if _hold > 0.0:
			_hold -= delta
		elif trail > hp:
			# Ease toward the accepted value; snap once under half a pixel.
			trail = lerpf(trail, hp, 1.0 - exp(-7.0 * delta))
			if (trail - hp) / max_hp * _bar_rect().size.x < 0.5:
				trail = hp
		if departing:
			_fade -= delta
			modulate.a = clampf(_fade / BossHealthBars.FADE_SECONDS, 0.0, 1.0)
			if _fade <= 0.0:
				owner_bars._row_finished(self)
				return
		_sync_processing()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not departing:
			accept_event()
			owner_bars.boss_selected.emit(enemy_id)

	func _bar_rect() -> Rect2:
		return Rect2(52, 32, size.x - 52 - 12 - _hp_width(), 8)

	func _hp_width() -> float:
		return owner_bars.number_width if owner_bars != null else 44.0

	func _draw() -> void:
		var selected: bool = owner_bars != null and owner_bars.selected_id == enemy_id and not departing
		draw_rect(Rect2(Vector2.ZERO, size), BossHealthBars.PANEL)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), BossHealthBars.SELECTED if selected else BossHealthBars.BORDER, false, 1.0)
		# Portrait well with a one-frame white rim when a hit lands.
		var well := Rect2(8, 7, 36, 36)
		draw_rect(well, BossHealthBars.TRACK)
		if _portrait != null:
			draw_texture_rect_region(_portrait, well.grow(-2), _portrait_region)
		var rim: Color = BossHealthBars.BORDER.lerp(Color("f4ecd8"), clampf(_flash / 0.14, 0.0, 1.0))
		draw_rect(Rect2(well.position + Vector2(0.5, 0.5), well.size - Vector2.ONE), rim, false, 1.0)
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(52, 21), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 16, BossHealthBars.SELECTED)
		draw_string(BossHealthBars.NUMBERS, Vector2(size.x - 12 - _hp_width(), 41), str(int(hp)), HORIZONTAL_ALIGNMENT_RIGHT, _hp_width(), 16, Color(0.90, 0.88, 0.81))
		var bar: Rect2 = _bar_rect()
		draw_rect(bar, BossHealthBars.TRACK)
		var inner := Rect2(bar.position + Vector2.ONE, bar.size - Vector2.ONE * 2.0)
		var filled: float = floorf(inner.size.x * hp / max_hp)
		var trailing: float = floorf(inner.size.x * trail / max_hp)
		if trailing > filled:
			draw_rect(Rect2(inner.position + Vector2(filled, 0), Vector2(trailing - filled, inner.size.y)), BossHealthBars.TRAIL)
		if filled > 0.0:
			var color: Color = BossHealthBars.IMMUNE if immune else (BossHealthBars.ENRAGED if enraged else BossHealthBars.FILL)
			draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), color)
			draw_rect(Rect2(inner.position, Vector2(filled, 1)), color.lightened(0.3))
		if enrage_fraction > 0.0 and not enraged:
			var notch: float = inner.position.x + floorf(inner.size.x * enrage_fraction)
			draw_rect(Rect2(notch, bar.position.y - 1, 1, bar.size.y + 2), Color("f4ecd8"))
		draw_rect(Rect2(bar.position + Vector2(0.5, 0.5), bar.size - Vector2.ONE), BossHealthBars.SHIELD if shielded else BossHealthBars.BORDER, false, 1.0)
