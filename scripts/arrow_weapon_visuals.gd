class_name ArrowWeaponVisuals
extends RefCounted
## Additive native-pixel equipment for the existing upright eight-facing archer rig.
## All clocks and action flags are presentation inputs from accepted combat state.

const DARK_HEADS: Texture2D = preload("res://assets/towers/archer_dark_heads.png")
const MUSCULAR_BODIES: Texture2D = preload("res://assets/towers/archer_muscular_bodies.png")
const INK := Color("282725")
const STEEL_DARK := Color("344247")
const STEEL := Color("687d85")
const STEEL_LIGHT := Color("b8c9c3")
const SKIN := Color("dca27a")
const SKIN_LIGHT := Color("edbb92")
const CREW_OFFSETS := [Vector2(-18, 2), Vector2(0, -6), Vector2(15, 2)]


static func release_offset(weapon: String, direction: Vector2, scale: float) -> Vector2:
	match weapon:
		"molotov", "grenade":
			return (direction * 9.0 + Vector2(0, -6)) * scale
		"rocket":
			return (direction * 27.0 + Vector2(0, -3)) * scale
		"minigun":
			return (direction * 29.0 + Vector2(0, 1)) * scale
		"flamethrower":
			return (direction * 17.0 + Vector2(0, 1)) * scale
	return Vector2.ZERO


static func draw_operator(canvas: CanvasItem, artwork: TowerReward, geometry: Dictionary, tower: Dictionary, weapon: String, age: float, interval: float, clock: float) -> void:
	var pivot: Vector2 = geometry["pivot"]
	var direction: Vector2 = geometry["direction"]
	var scale: float = geometry["scale"]
	var recoil: float = (1.0 - clampf(age / 0.20, 0.0, 1.0)) * (5.0 if weapon == "rocket" else (1.5 if weapon == "minigun" else 0.0))
	if weapon == "minigun":
		var working: bool = age < maxf(0.14, interval)
		for index: int in range(3):
			var offset: Vector2 = CREW_OFFSETS[index]
			if direction.x < 0.0:
				offset.x = -offset.x
			var brace: Vector2 = Vector2(-direction.x * (1.0 + sin(clock * 42.0 + float(index))) if working else 0.0, 0)
			_draw_person(canvas, artwork, pivot + (offset + brace) * scale, direction, scale, false, false)
			_limb(canvas, pivot + (offset + Vector2(0, -1)) * scale, pivot + (direction * float(8 + index * 3) + Vector2(0, 3)) * scale, scale * 2.0)
		_draw_minigun(canvas, pivot - direction * recoil * scale, direction, scale, clock, working)
		return
	var person: Vector2 = pivot - direction * recoil * scale
	_draw_person(canvas, artwork, person, direction, scale, weapon == "flamethrower" or weapon == "rocket", weapon == "rocket")
	if weapon == "molotov" or weapon == "grenade":
		_draw_throw(canvas, person, direction, scale, weapon, age, interval, clock)
	elif weapon == "rocket":
		_draw_launcher(canvas, person, direction, scale, tower.get("advancement", ""), age)
	elif weapon == "flamethrower":
		_draw_flamethrower(canvas, person, direction, scale, tower, clock)


static func _draw_person(canvas: CanvasItem, artwork: TowerReward, pivot: Vector2, direction: Vector2, scale: float, dark_hair: bool, muscular: bool) -> void:
	var facing: int = posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	var body_facing: int = posmod(roundi(direction.angle() / (PI / 2.0)), 4)
	canvas.draw_texture_rect_region(MUSCULAR_BODIES if muscular else artwork.archer_body_texture,
		Rect2((pivot + Vector2(-7, -3) * scale).round(), Vector2(14, 14) * scale), Rect2(body_facing * 14, 0, 14, 14))
	canvas.draw_texture_rect_region(DARK_HEADS if dark_hair else artwork.archer_head_texture,
		Rect2((pivot + Vector2(-8, -15) * scale).round(), Vector2(16, 14) * scale), Rect2(facing * 16, 0, 16, 14))


static func _limb(canvas: CanvasItem, shoulder: Vector2, hand: Vector2, width: float) -> void:
	var elbow: Vector2 = shoulder.lerp(hand, 0.52) + Vector2(0, 2)
	canvas.draw_line(shoulder.round(), elbow.round(), INK, maxf(3.0, width + 2.0))
	canvas.draw_line(elbow.round(), hand.round(), INK, maxf(3.0, width + 2.0))
	canvas.draw_line(shoulder.round(), elbow.round(), SKIN, maxf(1.0, width))
	canvas.draw_line(elbow.round(), hand.round(), SKIN_LIGHT, maxf(1.0, width))


static func _draw_throw(canvas: CanvasItem, pivot: Vector2, direction: Vector2, scale: float, weapon: String, age: float, interval: float, clock: float) -> void:
	# Accepted shot starts at release, followed by follow-through, recovery and windup.
	var ready: float = smoothstep(interval * 0.45, interval * 0.92, age)
	var release: Vector2 = direction * 9.0 + Vector2(0, -6)
	var rest: Vector2 = -direction * 3.0 + Vector2(0, 4)
	var wound: Vector2 = -direction * 7.0 + Vector2(0, -13)
	var hand: Vector2 = release.lerp(rest, clampf(age / 0.28, 0.0, 1.0)).lerp(wound, ready)
	_limb(canvas, pivot - direction * scale * 2.0, pivot + hand * scale, scale * 2.0)
	_limb(canvas, pivot + direction * scale * 2.0, pivot + (direction * 4.0 + Vector2(0, 4)) * scale, scale * 1.5)
	if age > minf(0.24, interval * 0.35):
		draw_payload(canvas, pivot + hand * scale, maxf(0.7, scale * 0.70), weapon, -0.35 * direction.x, clock)


static func draw_payload(canvas: CanvasItem, position: Vector2, pixel: float, weapon: String, angle: float, clock: float) -> void:
	canvas.draw_set_transform(position.round(), angle, Vector2.ONE * pixel)
	if weapon == "molotov":
		_rect(canvas, -3, -3, 6, 8, INK)
		_rect(canvas, -2, -2, 4, 6, Color("477a50"))
		_rect(canvas, -2, 0, 4, 3, Color("b9904e"))
		_rect(canvas, -1, -6, 2, 4, Color("92ad71"))
		_rect(canvas, -1, -8, 3, 2, Color("dac698"))
		_rect(canvas, 1, -11, 2, 4, Color("ef7d35"))
		_rect(canvas, 1, -10 - posmod(int(clock * 18.0), 2), 1, 2, Color("ffe3a0"))
		_rect(canvas, -2, -2, 1, 3, Color("a8c589"))
	elif weapon == "grenade":
		_rect(canvas, -3, -3, 6, 7, INK)
		_rect(canvas, -4, -1, 8, 3, INK)
		_rect(canvas, -2, -3, 4, 6, Color("73815a"))
		_rect(canvas, -3, -1, 6, 3, Color("5b694b"))
		_rect(canvas, -3, -1, 6, 1, Color("a2ad7b"))
		_rect(canvas, -1, -5, 2, 2, STEEL_LIGHT)
		_rect(canvas, 1, -5, 3, 1, STEEL)
		_rect(canvas, 3, -5, 1, 5, STEEL_LIGHT)
	elif weapon == "rocket":
		_rect(canvas, -11, -3, 18, 6, INK)
		_rect(canvas, -9, -2, 16, 4, STEEL)
		_rect(canvas, -7, -2, 12, 1, STEEL_LIGHT)
		_rect(canvas, 6, -2, 3, 4, Color("b98754"))
		_rect(canvas, 9, -1, 2, 2, Color("e5bf7d"))
		_rect(canvas, -11, -5, 3, 3, Color("6c785b"))
		_rect(canvas, -11, 2, 3, 3, Color("6c785b"))
		_rect(canvas, -15, -2, 5, 4, Color("e46b31"))
		_rect(canvas, -18 - posmod(int(clock * 30.0), 3), -1, 6, 2, Color("ffcf70"))
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_launcher(canvas: CanvasItem, pivot: Vector2, direction: Vector2, scale: float, advancement: String, age: float) -> void:
	_limb(canvas, pivot - direction * scale * 3.0, pivot + direction * scale * 7.0, scale * 3.0)
	_limb(canvas, pivot + direction * scale * 2.0, pivot + direction * scale * 16.0, scale * 3.0)
	canvas.draw_set_transform((pivot + Vector2(0, -3) * scale).round(), direction.angle(), Vector2(scale, -scale if direction.x < 0.0 else scale))
	_rect(canvas, -14, -5, 39, 10, INK)
	_rect(canvas, -13, -4, 36, 8, STEEL_DARK)
	_rect(canvas, -11, -3, 33, 5, STEEL)
	_rect(canvas, -10, -3, 31, 1, STEEL_LIGHT)
	_rect(canvas, 21, -6, 6, 12, INK)
	_rect(canvas, 22, -5, 4, 10, STEEL_LIGHT)
	_rect(canvas, 24, -3, 3, 6, Color("1c2426"))
	_rect(canvas, -15, -6, 5, 12, Color("879482"))
	_rect(canvas, -6, -6, 3, 12, Color("536651"))
	_rect(canvas, 10, -6, 3, 12, Color("536651"))
	_rect(canvas, 3, -9, 8, 3, INK)
	_rect(canvas, 4, -8, 6, 1, Color("c5b574"))
	_rect(canvas, 1, 5, 4, 5, INK)
	var bands: int = 2 if advancement == "aom_speed_2" else (1 if advancement == "aom_speed_1" else 0)
	for index: int in range(bands):
		_rect(canvas, 15 + index * 3, -3, 2, 6, Color("d6b666"))
	if age < 0.17:
		_rect(canvas, -23, -4, 10, 8, Color(0.44, 0.43, 0.37, 1.0 - age / 0.17))
		_rect(canvas, -18, -2, 5, 4, Color("e9a450"))
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_minigun(canvas: CanvasItem, pivot: Vector2, direction: Vector2, scale: float, clock: float, working: bool) -> void:
	# A grounded triangular carriage supports one rotary weapon, not cloned bows.
	canvas.draw_line((pivot + Vector2(0, 3) * scale).round(), (pivot + Vector2(-10, 14) * scale).round(), INK, maxf(2, scale * 4))
	canvas.draw_line((pivot + Vector2(0, 3) * scale).round(), (pivot + Vector2(10, 14) * scale).round(), STEEL, maxf(1, scale * 3))
	canvas.draw_set_transform((pivot + Vector2(0, 1) * scale).round(), direction.angle(), Vector2(scale, -scale if direction.x < 0.0 else scale))
	_rect(canvas, -13, -7, 18, 14, INK)
	_rect(canvas, -11, -6, 14, 11, STEEL_DARK)
	_rect(canvas, -10, -5, 12, 3, STEEL)
	_rect(canvas, -11, -7, 9, 1, STEEL_LIGHT)
	_rect(canvas, -15, -4, 5, 9, Color("a1814e"))
	for index: int in range(4):
		var phase: float = float(index) * TAU / 4.0 + (clock * 28.0 if working else 0.0)
		var y: int = roundi(sin(phase) * 4.0)
		_rect(canvas, 1, y - 1, 25, 3, INK)
		_rect(canvas, 2, y, 24, 1, STEEL_LIGHT if cos(phase) > 0.0 else STEEL)
	_rect(canvas, 6, -7, 3, 14, STEEL_DARK)
	_rect(canvas, 20, -7, 4, 14, STEEL_DARK)
	_rect(canvas, 21, -6, 1, 12, STEEL_LIGHT)
	_rect(canvas, 26, -6, 3, 12, INK)
	_rect(canvas, 27, -5, 1, 10, STEEL)
	if working:
		var y: int = posmod(int(clock * 45.0), 5) - 2
		_rect(canvas, 29, y, 9, 1, Color("d3cbab"))
		_rect(canvas, 36, y - 1, 2, 3, Color("e8e3c9"))
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_flamethrower(canvas: CanvasItem, pivot: Vector2, direction: Vector2, scale: float, tower: Dictionary, clock: float) -> void:
	var remaining: float = float(tower.get("refuel_remaining", 0.0))
	var duration: float = maxf(0.01, float(tower.get("refuel_duration", 6.0)))
	var refuel: float = 1.0 - remaining / duration
	var back: Vector2 = pivot - Vector2(signf(direction.x) * 6.0, 0) * scale
	var tank_offset: Vector2 = Vector2.ZERO
	if remaining > 0.0 and refuel > 0.25 and refuel < 0.72:
		tank_offset = Vector2(-signf(direction.x) * 7.0, 9.0 * sin((refuel - 0.25) / 0.47 * PI)) * scale
	if remaining > 0.0 and refuel > 0.48:
		# The exhausted cylinder stays visibly on the deck while a fresh one is fitted.
		canvas.draw_set_transform((pivot + Vector2(-signf(direction.x) * 13.0, 8) * scale).round(), 0, Vector2.ONE * scale)
		_rect(canvas, -7, -3, 14, 6, INK)
		_rect(canvas, -6, -2, 12, 4, Color("55594a"))
		_rect(canvas, -5, -2, 10, 1, Color("8f9473"))
		_rect(canvas, -3, -3, 2, 6, STEEL_DARK)
		_rect(canvas, 3, -3, 2, 6, STEEL_DARK)
		canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_set_transform((back + tank_offset).round(), 0, Vector2.ONE * scale)
	_rect(canvas, -4, -7, 8, 17, INK)
	_rect(canvas, -3, -6, 6, 15, Color("9c914e"))
	_rect(canvas, -2, -5, 2, 13, Color("d7c27a"))
	_rect(canvas, -4, -3, 8, 2, STEEL_DARK)
	_rect(canvas, -4, 5, 8, 2, STEEL_DARK)
	_rect(canvas, -1, -10, 3, 3, STEEL)
	_rect(canvas, -3, -11, 7, 1, Color("a95436"))
	canvas.draw_set_transform(Vector2.ZERO)
	var nozzle_direction: Vector2 = direction if remaining <= 0.0 else direction.rotated(0.65 * signf(direction.x))
	var hand: Vector2 = pivot + nozzle_direction * 9.0 * scale
	_limb(canvas, pivot, hand, scale * 2.0)
	var other_hand: Vector2 = hand - nozzle_direction * 4.0 * scale
	if remaining > 0.0:
		var prime: float = sin(refuel * 60.0) if refuel > 0.72 else 0.0
		other_hand = back + tank_offset + Vector2(prime, -7 if refuel < 0.25 or refuel > 0.72 else 2) * scale
	_limb(canvas, pivot - direction * scale * 2.0, other_hand, scale * 2.0)
	var hose_end: Vector2 = back + Vector2(0, 7) * scale
	if remaining <= 0.0 or refuel < 0.25 or refuel > 0.72:
		canvas.draw_line(hose_end.round(), (pivot + Vector2(0, 12) * scale).round(), INK, maxf(2, scale * 3))
		canvas.draw_line((pivot + Vector2(0, 12) * scale).round(), hand.round(), INK, maxf(2, scale * 3))
		canvas.draw_line(hose_end.round(), (pivot + Vector2(0, 11) * scale).round(), Color("765a3b"), maxf(1, scale))
	canvas.draw_set_transform((pivot + Vector2(0, 1) * scale).round(), nozzle_direction.angle(), Vector2(scale, -scale if direction.x < 0.0 else scale))
	_rect(canvas, 3, -3, 12, 6, INK)
	_rect(canvas, 4, -2, 11, 3, STEEL)
	_rect(canvas, 12, -4, 5, 8, STEEL_DARK)
	_rect(canvas, 14, -3, 2, 6, Color("c39357"))
	_rect(canvas, 6, 2, 3, 4, Color("64452d"))
	if remaining <= 0.0:
		_rect(canvas, 16, -1, 3, 2, Color("f8c86e") if posmod(int(clock * 12.0), 2) else Color("d46a31"))
	elif refuel > 0.85:
		_rect(canvas, 16, 0, 2, 1, Color("e99a42"))
	canvas.draw_set_transform(Vector2.ZERO)
	if remaining > 0.0:
		# Three readable stages: disconnect, exchange the lowered tank, then prime.
		var stage: int = 0 if refuel < 0.25 else (1 if refuel < 0.72 else 2)
		var top: Vector2 = pivot + Vector2(-10, -21) * scale
		canvas.draw_rect(Rect2(top.round(), Vector2(20, 3) * scale), INK)
		canvas.draw_rect(Rect2((top + Vector2.ONE * scale).round(), Vector2(18 * clampf(refuel, 0, 1), 1) * scale), Color("e5b967"))
		for index: int in range(3):
			canvas.draw_rect(Rect2((top + Vector2(index * 7, -4) * scale).round(), Vector2(5, 2) * scale), Color("e5b967") if index == stage else STEEL_DARK)


static func draw_flame_jet(canvas: CanvasItem, origin: Vector2, end: Vector2, cell_size: float, clock: float) -> void:
	var direction: Vector2 = (end - origin).normalized()
	var side := Vector2(-direction.y, direction.x)
	var distance: float = origin.distance_to(end)
	var pixel: float = maxf(1.0, floorf(cell_size * 0.020))
	var count: int = clampi(ceili(distance / (pixel * 3.0)), 2, 80)
	for index: int in range(count):
		var fraction: float = float(index) / float(count)
		var phase: float = clock * 29.0 - float(index) * 1.7
		var width: float = (1.0 + fraction * 4.5) * pixel
		var point: Vector2 = origin.lerp(end, fraction) + side * sin(phase) * pixel * fraction * 2.0
		canvas.draw_rect(Rect2((point - Vector2.ONE * width).floor(), Vector2.ONE * width * 2), Color("bc4927"))
		canvas.draw_rect(Rect2((point - Vector2.ONE * width * 0.65).floor(), Vector2.ONE * width * 1.3), Color("f28a36"))
		canvas.draw_rect(Rect2((point - Vector2.ONE * pixel).floor(), Vector2.ONE * pixel * (2.0 if index % 3 else 3.0)), Color("ffe2a0"))


static func draw_impact(canvas: CanvasItem, position: Vector2, radius: float, phase: float, pixel: float, weapon: String) -> void:
	var fade: float = 1.0 - clampf(phase, 0.0, 1.0)
	var rocket: bool = weapon == "rocket"
	var molotov: bool = weapon == "molotov"
	var count: int = 12 if rocket else 8
	for index: int in range(count):
		var angle: float = float(index) * TAU / float(count)
		var outward := Vector2(cos(angle), sin(angle) * 0.60)
		var point: Vector2 = position + outward * radius * (0.18 + phase * 0.70)
		var size: float = pixel * ((5.0 if rocket else 3.0) + phase * 6.0)
		var smoke := Color(0.30 + float(index % 3) * 0.055, 0.32 + float(index % 3) * 0.045, 0.30, fade * 0.9)
		if not molotov:
			canvas.draw_rect(Rect2((point - Vector2.ONE * size * 0.5 - Vector2(0, phase * radius * 0.3)).floor(), Vector2.ONE * size), smoke)
		if phase < 0.60 or molotov:
			var flame_size: float = size * (1.0 - phase * 0.7)
			canvas.draw_rect(Rect2((point - Vector2.ONE * flame_size * 0.5).floor(), Vector2(flame_size, flame_size * (1.8 if molotov else 1.0))), Color(0.94, 0.39, 0.13, fade))
			canvas.draw_rect(Rect2(point.floor(), Vector2.ONE * pixel * 2), Color(1.0, 0.85, 0.46, fade))
		var fragment: Vector2 = position + outward * radius * phase
		canvas.draw_line(fragment.floor(), (fragment + outward * pixel * (4 if rocket else 2)).floor(), Color(0.80, 0.87, 0.73, fade) if not molotov else Color(0.49, 0.67, 0.34, fade), pixel)
	if rocket and phase < 0.4:
		var core: float = radius * (0.10 + phase * 0.50)
		# Stepped radial flash: a large square obscures the blast and reads as a UI panel.
		var band: float = maxf(pixel, floorf(core / (6.0 * pixel)) * pixel)
		for row: int in range(-6, 7):
			var fraction: float = float(row) / 6.5
			var half_width: float = maxf(pixel, floorf(core * sqrt(1.0 - fraction * fraction) / pixel) * pixel)
			canvas.draw_rect(Rect2((position + Vector2(-half_width, row * band)).floor(),
				Vector2(half_width * 2.0, band)), Color(1.0, 0.86, 0.55, fade))


static func _rect(canvas: CanvasItem, x: float, y: float, width: float, height: float, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y, width, height), color)
