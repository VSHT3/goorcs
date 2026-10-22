class_name BoardFeedback
extends RefCounted
## Short battlefield flourishes drawn from accepted facts only: elite/boss kill
## bursts with their accepted bounty, crystal hits sized by the accepted HP
## lost, and a warning around a crystal an enemy is about to reach.
## Every clock here is simulation time, so pause and 1x/2x/3x carry through.

const NUMBERS: FontFile = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const ELITE_BURST: float = 0.5
const BOSS_BURST: float = 0.8
const COIN_POP: float = 0.95
const CRYSTAL_HIT: float = 0.7
const CRYSTAL_FLASH: float = 0.16
const CRYSTAL_SHAKE: float = 0.3
## Route cells from the crystal at which the warning begins.
const WARNING_CELLS: float = 3.0
const BONE := Color("f4ecd8")
const GOLD := Color("f0cc62")
const EMBER := Color("ef7d35")
const COIN := Color("e0bc77")
const COIN_RIM := Color("9d743b")
const COIN_SHINE := Color("f5dca5")
const OUTLINE := Color("172120")
const SHARD_LIGHT := Color("b6efff")
const SHARD := Color("64cef5")
const SHARD_DARK := Color("2776b9")
const HIT_RED := Color("e05a3c")
const HIT_TEXT := Color("ffb39f")


static func kill_duration(boss: bool, coins: int) -> float:
	return maxf(BOSS_BURST if boss else ELITE_BURST, COIN_POP if coins > 0 else 0.0)


## Feedback pixels stay at least 2px so a fit-to-board zoom still reads them.
static func _pixel(cell_size: float) -> float:
	return maxf(2.0, floorf(cell_size * 0.045))


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


## A pale spark ring for elites, a wider gold one for bosses, both clear of
## the falling body, and the accepted bounty rising from above its head.
static func draw_kill_burst(surface: CanvasItem, center: Vector2, body_radius: float, elapsed: float, cell_size: float, boss: bool, coins: int, seed_value: int) -> void:
	var pixel: float = _pixel(cell_size)
	var duration: float = BOSS_BURST if boss else ELITE_BURST
	if elapsed >= 0.0 and elapsed < duration:
		var t: float = elapsed / duration
		var fade: float = 1.0 - t
		var spin: float = float(seed_value % 5) * 0.2
		var rings: int = 2 if boss else 1
		for ring: int in range(rings):
			var count: int = 10 if ring == 0 else 14
			var reach: float = body_radius * (0.75 + (0.55 + 0.35 * ring) * _ease_out(t)) + pixel * 2.0 * ring
			for index: int in range(count):
				var direction := Vector2.from_angle(spin + (float(index) + 0.5 * ring) * TAU / float(count))
				var point: Vector2 = center + Vector2(direction.x, direction.y * 0.8) * reach
				var length: float = pixel * (2.0 if index % 2 == 0 else 1.0) * (1.0 - 0.5 * t)
				var color: Color = (GOLD if index % 3 else EMBER) if boss else (BONE if index % 3 else Color("c9d9c2"))
				# Short radial dashes in whole pixels read as a burst, not a box.
				for step: int in range(2):
					var dot: Vector2 = point + direction * pixel * float(step) * 1.5
					surface.draw_rect(Rect2(dot.floor(), Vector2.ONE * maxf(pixel, roundf(length))), Color(color, fade * (1.0 - 0.4 * step)))
	if coins > 0 and elapsed >= 0.0 and elapsed < COIN_POP:
		draw_coin_pop(surface, center - Vector2(0.0, body_radius), elapsed, cell_size, coins, boss)


static func draw_coin_pop(surface: CanvasItem, origin: Vector2, elapsed: float, cell_size: float, coins: int, large: bool) -> void:
	var t: float = clampf(elapsed / COIN_POP, 0.0, 1.0)
	var alpha: float = clampf((1.0 - t) / 0.35, 0.0, 1.0)
	var pixel: float = _pixel(cell_size)
	# Pops up quickly with a small overshoot, then drifts.
	var pop: float = minf(1.0, t * 4.0)
	var rise: float = cell_size * (0.12 * (pop * (2.0 - pop)) + 0.18 * t) + (pixel * 2.0 * sin(pop * PI))
	var radius: float = pixel * (4.0 if large else 3.0)
	var font_size: int = maxi(11, roundi(cell_size * (0.34 if large else 0.26)))
	var text: String = "+%d" % coins
	var text_width: float = NUMBERS.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap: float = pixel * 2.0
	var left: float = origin.x - (radius * 2.0 + gap + text_width) * 0.5
	var coin_center: Vector2 = Vector2(left + radius, origin.y - rise).floor()
	surface.draw_circle(coin_center, radius + pixel, Color(OUTLINE, alpha))
	surface.draw_circle(coin_center + Vector2(0.0, pixel * 0.5), radius, Color(COIN_RIM, alpha))
	surface.draw_circle(coin_center - Vector2(0.0, pixel * 0.5), radius - pixel * 0.5, Color(COIN, alpha))
	surface.draw_rect(Rect2(coin_center - Vector2(pixel, radius * 0.6), Vector2(pixel, radius)), Color(COIN_RIM, alpha))
	surface.draw_rect(Rect2(coin_center + Vector2(-radius * 0.6, -radius * 0.55), Vector2(pixel, pixel)), Color(COIN_SHINE, alpha))
	var baseline: Vector2 = Vector2(left + radius * 2.0 + gap, coin_center.y + font_size * 0.36).floor()
	surface.draw_string_outline(NUMBERS, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(3, roundi(font_size / 5.0)), Color(OUTLINE, alpha))
	surface.draw_string(NUMBERS, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(COIN_SHINE if large else COIN, alpha))


## Shards spray off the crystal, a red ring hits the pedestal and the accepted
## HP lost rises above it. Larger hits throw more shards farther.
static func draw_crystal_hit(surface: CanvasItem, crystal: Rect2, foot: Vector2, elapsed: float, damage: int, cell_size: float, seed_value: int) -> void:
	if elapsed < 0.0 or elapsed >= CRYSTAL_HIT:
		return
	var t: float = elapsed / CRYSTAL_HIT
	var fade: float = 1.0 - t
	var pixel: float = _pixel(cell_size)
	var weight: float = clampf(float(damage) / 10.0, 0.0, 1.0)
	surface.draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
	surface.draw_arc(Vector2.ZERO, cell_size * (0.2 + (0.35 + 0.25 * weight) * _ease_out(t)), 0.0, TAU, 24, Color(HIT_RED, 0.8 * fade), pixel, false)
	surface.draw_set_transform(Vector2.ZERO)
	var origin: Vector2 = crystal.get_center() - Vector2(0.0, crystal.size.y * 0.1)
	var count: int = 5 + roundi(7.0 * weight)
	for index: int in range(count):
		var angle: float = -PI * 0.5 + (float(index) / float(maxi(1, count - 1)) - 0.5) * PI * 1.25 + float((seed_value + index * 7) % 5) * 0.06
		var speed: float = cell_size * (1.8 + 1.2 * weight) * (0.7 + 0.1 * float((seed_value + index * 3) % 4))
		var position: Vector2 = origin + Vector2.from_angle(angle) * speed * elapsed + Vector2(0.0, cell_size * 2.4 * elapsed * elapsed)
		var color: Color = [SHARD_LIGHT, SHARD, SHARD_DARK][index % 3]
		var size := Vector2(pixel, pixel * (2.0 if index % 2 else 1.0)) * (1.5 if index % 3 == 0 else 1.0)
		surface.draw_rect(Rect2(position.floor(), size), Color(color, fade))
	if damage > 0:
		var font_size: int = maxi(11, roundi(cell_size * (0.3 + 0.12 * weight)))
		var rise: float = cell_size * 0.35 * _ease_out(t)
		var text: String = "-%d" % damage
		var width: float = NUMBERS.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: Vector2 = Vector2(crystal.get_center().x - width * 0.5, crystal.position.y - pixel * 2.0 - rise).floor()
		var alpha: float = clampf(fade / 0.4, 0.0, 1.0)
		surface.draw_string_outline(NUMBERS, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, roundi(font_size / 6.0)), Color(OUTLINE, alpha))
		surface.draw_string(NUMBERS, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(HIT_TEXT, alpha))


## Horizontal pixel offset for the shaken crystal; zero once the shake settles.
static func crystal_shake(elapsed: float, damage: int, cell_size: float) -> float:
	if elapsed < 0.0 or elapsed >= CRYSTAL_SHAKE or damage <= 0:
		return 0.0
	var amplitude: float = _pixel(cell_size) * clampf(1.0 + float(damage) * 0.3, 1.0, 4.0) * (1.0 - elapsed / CRYSTAL_SHAKE)
	return roundf(sin(elapsed * 70.0) * amplitude)


## 0 when no enemy is within WARNING_CELLS route cells of the crystal, 1 at arrival.
static func leak_danger(remaining_cells: float) -> float:
	if remaining_cells >= WARNING_CELLS or remaining_cells < 0.0:
		return 0.0
	return clampf(1.0 - remaining_cells / WARNING_CELLS, 0.0, 1.0)


## Red corner marks around the crystal that pulse faster and brighter as the
## nearest enemy closes in.
static func draw_leak_warning(surface: CanvasItem, crystal: Rect2, danger: float, clock: float, cell_size: float) -> void:
	if danger <= 0.0:
		return
	var pixel: float = _pixel(cell_size)
	var pulse: float = 0.5 + 0.5 * sin(clock * (5.0 + 5.0 * danger))
	var alpha: float = clampf(0.35 + 0.65 * danger, 0.0, 1.0) * (0.55 + 0.45 * pulse)
	var rect: Rect2 = crystal.grow(pixel * (1.5 + 1.5 * (1.0 - pulse))).abs()
	rect.position = rect.position.floor()
	rect.size = rect.size.floor()
	var corner: float = minf(pixel * 4.0, rect.size.x * 0.3)
	var width: float = pixel
	for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction := Vector2(1.0 if point.x == rect.position.x else -1.0, 1.0 if point.y == rect.position.y else -1.0)
		var left: float = point.x if direction.x > 0.0 else point.x - corner
		var top: float = point.y if direction.y > 0.0 else point.y - width
		surface.draw_rect(Rect2(left, top, corner, width), Color(HIT_RED, alpha))
		left = point.x if direction.x > 0.0 else point.x - width
		top = point.y if direction.y > 0.0 else point.y - corner
		surface.draw_rect(Rect2(left, top, width, corner), Color(HIT_RED, alpha))
