class_name MatchBanner
extends Control
## Short, non-blocking HUD beats read from accepted snapshots: a boss arriving
## on your own board and a cleared round with the Coins/Shards it paid you.
## Timing is local real time on the HUD, so the solo pause holds a banner and
## 2x/3x simulation does not rush it. Nothing here feeds gameplay.

const NUMBERS: FontFile = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const ENTER: float = 0.18
const BOSS_HOLD: float = 2.2
const ROUND_HOLD: float = 1.5
const EXIT: float = 0.35
const TOP: float = 92.0
const MARGIN: float = 14.0
const PANEL := Color(0.10, 0.145, 0.13, 0.96)
const BORDER := Color(0.40, 0.46, 0.40)
const TRACK := Color(0.055, 0.085, 0.07)
const GOLD := Color("e0bc77")
const BOSS_ACCENT := Color(0.70, 0.34, 0.31)
const CLEAR_ACCENT := Color("8bac77")
const CLEAR_TEXT := Color("b5e2b7")
const VALUE_TEXT := Color(0.90, 0.88, 0.81)
const MAX_QUEUE: int = 3

var catalog: ContentCatalog
## Visible HUD panels boss announcements keep clear of.
var avoid: Array[Control] = []
var _run: String = ""
var _clears: int = -1
var _seen: Dictionary[int, bool] = {}
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed: float = 0.0
var _portraits: Dictionary[String, Texture2D] = {}


func _init() -> void:
	name = "MatchBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Compares one accepted snapshot with the previous one. A new run only sets
## the baseline, so bosses already present and earlier clears never replay.
func observe(state: Dictionary, own_slot: int) -> void:
	var run: String = String(state.get("statistics_id", ""))
	var clears: Dictionary = state.get("clears", {})
	var count: int = int(clears.get("count", 0))
	var enemies: Array = state.get("enemies", [[], []])
	var own: Array = enemies[own_slot] if own_slot >= 0 and own_slot < enemies.size() else []
	var types: Dictionary = state.get("enemy_types", {})
	if run != _run:
		clear()
		_run = run
		_clears = count
		_seen.clear()
		for enemy: Dictionary in own:
			if _is_boss(enemy, types):
				_seen[int(enemy["id"])] = true
		return
	if int(state.get("phase", MatchCombat.Phase.PLANNING)) == MatchCombat.Phase.FINISHED:
		_clears = count
		clear()
		return
	if count > _clears:
		var gains: Array = clears.get("gains", [])
		var own_gain: Array = gains[own_slot] if own_slot >= 0 and own_slot < gains.size() else [0, 0]
		_push({"kind": "round", "round": int(state.get("wave", 0)), "coins": int(own_gain[0]), "shards": int(own_gain[1])})
	_clears = count
	var alive: Dictionary[int, bool] = {}
	for enemy: Dictionary in own:
		if not _is_boss(enemy, types):
			continue
		var id: int = int(enemy["id"])
		alive[id] = true
		if not _seen.has(id):
			var type_id: String = String(enemy["type_id"])
			_push({"kind": "boss", "type_id": type_id, "title": String(types.get(type_id, {}).get("title", _definition_title(type_id)))})
	# Only living bosses need remembering; IDs never return within a run.
	_seen = alive


func _is_boss(enemy: Dictionary, types: Dictionary) -> bool:
	var type_id: String = String(enemy.get("type_id", ""))
	if types.has(type_id):
		return bool(types[type_id].get("boss", false))
	var definition: EnemyDefinition = _definition(type_id)
	return definition != null and definition.boss


func _definition(type_id: String) -> EnemyDefinition:
	if catalog != null:
		for definition: EnemyDefinition in catalog.enemies:
			if definition != null and String(definition.id) == type_id:
				return definition
	return null


func _definition_title(type_id: String) -> String:
	var definition: EnemyDefinition = _definition(type_id)
	return definition.title if definition != null else type_id


## Drops the banner and anything queued, for a new run, results, hiding or leaving.
func clear() -> void:
	_queue.clear()
	_current = {}
	set_process(false)
	queue_redraw()


func current_kind() -> String:
	return String(_current.get("kind", ""))


func current() -> Dictionary:
	return _current


func queued() -> Array[Dictionary]:
	return _queue


func _push(entry: Dictionary) -> void:
	if entry["kind"] == "boss":
		for waiting: Dictionary in _queue:
			if waiting["kind"] == "boss" and waiting["type_id"] == entry["type_id"]:
				return
		if not _current.is_empty() and _current["kind"] == "boss" and _current["type_id"] == entry["type_id"]:
			return
		# A boss cuts a round beat short instead of waiting behind it.
		if _current.get("kind", "") == "round":
			_elapsed = maxf(_elapsed, ENTER + ROUND_HOLD)
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append(entry)
	if _current.is_empty():
		_next()
	set_process(true)


func _next() -> void:
	_current = {} if _queue.is_empty() else _queue.pop_front()
	_elapsed = 0.0
	set_process(not _current.is_empty())
	queue_redraw()


func _hold() -> float:
	return BOSS_HOLD if _current.get("kind", "") == "boss" else ROUND_HOLD


func _process(delta: float) -> void:
	if _current.is_empty():
		set_process(false)
		return
	_elapsed += delta
	if _elapsed >= ENTER + _hold() + EXIT:
		_next()
	queue_redraw()


func _portrait(type_id: String) -> Texture2D:
	if not _portraits.has(type_id):
		var definition: EnemyDefinition = _definition(type_id)
		_portraits[type_id] = definition.texture if definition != null else null
	return _portraits[type_id]


func _panel_size() -> Vector2:
	var font: Font = get_theme_default_font()
	if _current.get("kind", "") == "boss":
		var title: float = font.get_string_size(String(_current["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		return Vector2(ceilf(maxf(220.0, 72.0 + title + 22.0)), 64.0)
	var heading: float = font.get_string_size(_round_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	return Vector2(ceilf(maxf(heading, _gains_width()) + 48.0), 64.0 if _has_gains() else 40.0)


func _round_text() -> String:
	return "Round %d cleared" % int(_current.get("round", 0))


func _has_gains() -> bool:
	return int(_current.get("coins", 0)) > 0 or int(_current.get("shards", 0)) > 0


func _gains_width() -> float:
	var width: float = 0.0
	for key: String in ["coins", "shards"]:
		if int(_current.get(key, 0)) > 0:
			width += 26.0 + NUMBERS.get_string_size("+%d" % int(_current[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0
	return maxf(0.0, width - 14.0)


## Round rewards stay viewport-centered; boss announcements avoid other panels.
func panel_rect() -> Rect2:
	var panel_size: Vector2 = _panel_size()
	if _current.get("kind", "") == "round":
		return Rect2(Vector2(floorf((size.x - panel_size.x) * 0.5), TOP), panel_size)
	var left: float = MARGIN
	var right: float = size.x - MARGIN
	for control: Control in avoid:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var other: Rect2 = Rect2(get_global_transform().affine_inverse() * control.get_global_rect().position, control.get_global_rect().size)
			if other.position.x > size.x * 0.5:
				right = minf(right, other.position.x - 8.0)
	var rect := Rect2(Vector2(floorf(left + (right - left - panel_size.x) * 0.5), TOP), panel_size)
	for control: Control in avoid:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var other: Rect2 = Rect2(get_global_transform().affine_inverse() * control.get_global_rect().position, control.get_global_rect().size)
			if other.intersects(rect):
				rect.position.y = other.end.y + 6.0
	return rect


func _draw() -> void:
	if _current.is_empty():
		return
	var alpha: float = 1.0
	var drop: float = 0.0
	if _elapsed < ENTER:
		var t: float = _elapsed / ENTER
		alpha = t
		drop = -10.0 * (1.0 - t) * (1.0 - t)
	elif _elapsed > ENTER + _hold():
		var t: float = clampf((_elapsed - ENTER - _hold()) / EXIT, 0.0, 1.0)
		alpha = 1.0 - t
		drop = -6.0 * t
	var rect: Rect2 = panel_rect()
	rect.position.y += roundf(drop)
	var boss: bool = _current["kind"] == "boss"
	var accent: Color = BOSS_ACCENT if boss else CLEAR_ACCENT
	draw_rect(rect, Color(PANEL, PANEL.a * alpha))
	draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE), Color(BORDER, alpha), false, 1.0)
	# Accent rails along the top and bottom edges, inset like the HUD bars.
	draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(rect.size.x - 8, 2)), Color(accent, alpha))
	draw_rect(Rect2(Vector2(rect.position.x + 4, rect.end.y - 5), Vector2(rect.size.x - 8, 2)), Color(accent, alpha))
	var font: Font = get_theme_default_font()
	if boss:
		# A hold-then-sweep glint across the portrait well marks the arrival.
		var well := Rect2(rect.position + Vector2(12, 10), Vector2(44, 44))
		draw_rect(well, Color(TRACK, alpha))
		var portrait: Texture2D = _portrait(String(_current["type_id"]))
		if portrait != null:
			draw_texture_rect_region(portrait, well.grow(-2), BossHealthBars.portrait_region(portrait), Color(1, 1, 1, alpha))
		var rim: Color = BORDER.lerp(Color("f4ecd8"), clampf(1.0 - (_elapsed - ENTER) / 0.3, 0.0, 1.0))
		draw_rect(Rect2(well.position + Vector2(0.5, 0.5), well.size - Vector2.ONE), Color(rim, alpha), false, 1.0)
		draw_string(font, rect.position + Vector2(68, 27), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(accent.lightened(0.25), alpha))
		draw_string(font, rect.position + Vector2(68, 51), String(_current["title"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 80, 24, Color(GOLD, alpha))
		return
	var heading: String = _round_text()
	var heading_width: float = font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, Vector2(floorf(rect.get_center().x - heading_width * 0.5), rect.position.y + 29), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(CLEAR_TEXT, alpha))
	if not _has_gains():
		return
	var x: float = floorf(rect.get_center().x - _gains_width() * 0.5)
	for key: String in ["coins", "shards"]:
		var amount: int = int(_current.get(key, 0))
		if amount <= 0:
			continue
		MatchPlanningScreen.CurrencyIcon.paint(self, Vector2(x, rect.position.y + 34), key == "shards", alpha)
		var text: String = "+%d" % amount
		draw_string(NUMBERS, Vector2(x + 26, rect.position.y + 52), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(GOLD if key == "coins" else Color("b7e5e7"), alpha))
		x += 26.0 + NUMBERS.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0
