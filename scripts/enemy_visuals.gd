class_name EnemyVisuals
extends RefCounted
## Shared simulation-time frame selection and fixed-size sprite geometry.
## Rendering and hit picking resolve the same Texture2D; no local gameplay clock.

static var _bounds: Dictionary[Texture2D, Rect2] = {}
static var _images: Dictionary[Texture2D, Image] = {}
static var _slow_textures: Dictionary[Texture2D, Texture2D] = {}
static var _burn_textures: Dictionary[Texture2D, Texture2D] = {}
static var _unions: Dictionary[EnemyDefinition, Rect2] = {}


static func frame_texture(definition: EnemyDefinition, animation: StringName = &"walk", elapsed: float = 0.0) -> Texture2D:
	var frames: SpriteFrames = definition.animation_frames
	if frames == null:
		return definition.texture
	if not frames.has_animation(animation):
		animation = &"walk"
	if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		return definition.texture
	var count: int = frames.get_frame_count(animation)
	var duration: float = 0.0
	for index: int in range(count):
		duration += frames.get_frame_duration(animation, index)
	var cursor: float = maxf(0.0, elapsed) * frames.get_animation_speed(animation)
	if frames.get_animation_loop(animation):
		cursor = fposmod(cursor, duration)
	for index: int in range(count):
		cursor -= frames.get_frame_duration(animation, index)
		if cursor < 0.0 or index == count - 1:
			return frames.get_frame_texture(animation, index)
	return definition.texture


static func enemy_texture(definition: EnemyDefinition, enemy: Dictionary) -> Texture2D:
	var animation: StringName = StringName(enemy.get("animation", "walk"))
	var locomotion: StringName = StringName(enemy.get("locomotion", "path"))
	if animation == &"walk" and locomotion in [&"legs", &"jump_charge", &"jump"]:
		animation = locomotion
	animation = damage_animation(definition, animation, float(enemy.get("hp", 1.0)), float(enemy.get("max_hp", 1.0)))
	return frame_texture(definition, animation, float(enemy.get("animation_elapsed", enemy.get("age", 0.0))))


static func damage_animation(definition: EnemyDefinition, animation: StringName, hp: float, max_hp: float) -> StringName:
	var fraction: float = hp / maxf(1.0, max_hp)
	var suffix: String = "_critical" if fraction <= 0.33 else ("_damaged" if fraction <= 0.66 else "")
	var variant := StringName(String(animation) + suffix)
	if not suffix.is_empty() and definition.animation_frames != null and definition.animation_frames.has_animation(variant):
		return variant
	return animation


static func jump_lift(enemy: Dictionary) -> float:
	if enemy.get("locomotion", "path") != "jump":
		return 0.0
	var duration: float = maxf(0.001, float(enemy.get("jump_duration", 1.0)))
	var phase: float = clampf(1.0 - float(enemy.get("jump_remaining", duration)) / duration, 0.0, 1.0)
	return sin(phase * PI) * 0.85


static func animation_duration(definition: EnemyDefinition, animation: StringName) -> float:
	var frames: SpriteFrames = definition.animation_frames
	if frames == null or not frames.has_animation(animation):
		return 0.0
	var duration: float = 0.0
	for index: int in range(frames.get_frame_count(animation)):
		duration += frames.get_frame_duration(animation, index)
	return duration / maxf(0.001, frames.get_animation_speed(animation))


static func image(texture: Texture2D) -> Image:
	if not _images.has(texture):
		var pixels: Image = texture.get_image()
		if pixels != null and pixels.is_compressed():
			pixels.decompress()
		_images[texture] = pixels
	return _images[texture]


static func opaque_bounds(texture: Texture2D) -> Rect2:
	if not _bounds.has(texture):
		var pixels: Image = image(texture)
		_bounds[texture] = Rect2(pixels.get_used_rect()) if pixels != null else Rect2(Vector2.ZERO, texture.get_size())
	return _bounds[texture]


static func union_bounds(definition: EnemyDefinition) -> Rect2:
	if _unions.has(definition):
		return _unions[definition]
	var bounds: Rect2 = opaque_bounds(frame_texture(definition))
	var frames: SpriteFrames = definition.animation_frames
	if frames != null:
		for animation: StringName in frames.get_animation_names():
			for index: int in range(frames.get_frame_count(animation)):
				bounds = bounds.merge(opaque_bounds(frames.get_frame_texture(animation, index)))
	_unions[definition] = bounds
	return bounds


static func sprite_rect(definition: EnemyDefinition, texture: Texture2D, height: float, foot: Vector2, flip: bool = false) -> Rect2:
	# Reference height is stable for every pose: raised hands/staff never shrink bodies.
	var reference: Rect2 = opaque_bounds(frame_texture(definition))
	var scale: float = height / maxf(1.0, reference.size.y)
	var sprite_size: Vector2 = texture.get_size() * scale
	var anchor: Vector2 = definition.board_anchor
	if flip:
		anchor.x = 1.0 - anchor.x
	return Rect2(foot - sprite_size * anchor, sprite_size)


static func visible_rect(definition: EnemyDefinition, texture: Texture2D, height: float, foot: Vector2, flip: bool = false) -> Rect2:
	var rect: Rect2 = sprite_rect(definition, texture, height, foot, flip)
	var bounds: Rect2 = opaque_bounds(texture)
	if flip:
		bounds.position.x = texture.get_width() - bounds.end.x
	var scale: Vector2 = rect.size / texture.get_size()
	return Rect2(rect.position + bounds.position * scale, bounds.size * scale)


static func slowed_texture(texture: Texture2D) -> Texture2D:
	if not _slow_textures.has(texture):
		var source: Image = image(texture)
		if source == null:
			return texture
		var tinted: Image = source.duplicate()
		tinted.convert(Image.FORMAT_RGBA8)
		for y: int in range(tinted.get_height()):
			for x: int in range(tinted.get_width()):
				var pixel: Color = tinted.get_pixel(x, y)
				if pixel.a > 0.0:
					tinted.set_pixel(x, y, pixel.lerp(Color(0.40, 0.68, 0.91, pixel.a), 0.38))
		_slow_textures[texture] = ImageTexture.create_from_image(tinted)
	return _slow_textures[texture]


static func burning_texture(texture: Texture2D) -> Texture2D:
	if not _burn_textures.has(texture):
		var source: Image = image(texture)
		if source == null:
			return texture
		var tinted: Image = source.duplicate()
		tinted.convert(Image.FORMAT_RGBA8)
		for y: int in range(tinted.get_height()):
			for x: int in range(tinted.get_width()):
				var pixel: Color = tinted.get_pixel(x, y)
				if pixel.a > 0.0:
					var light: float = pixel.get_luminance()
					var ember := Color(0.48 + light * 0.52, 0.12 + light * 0.39, 0.04 + light * 0.12, pixel.a)
					tinted.set_pixel(x, y, pixel.lerp(ember, 0.72))
		_burn_textures[texture] = ImageTexture.create_from_image(tinted)
	return _burn_textures[texture]


static func effect_color(animation: StringName) -> Color:
	return Color("9cda9a") if animation == &"heal" else Color("ac97cf")


static func draw_action_effect(surface: CanvasItem, foot: Vector2, radius: float, animation: StringName, elapsed: float) -> void:
	# A brief ground pulse and upward motes identify actual host actions, not auras.
	var duration: float = 0.55 if animation == &"heal" else 1.15
	if elapsed < 0.0 or elapsed >= duration:
		return
	var phase: float = elapsed / duration
	var color: Color = effect_color(animation)
	color.a = (1.0 - phase) * 0.8
	surface.draw_set_transform(foot, 0.0, Vector2(1.0, 0.38))
	surface.draw_arc(Vector2.ZERO, radius * (0.45 + phase * 0.75), 0.0, TAU, 24, color, 1.5, false)
	surface.draw_set_transform(Vector2.ZERO)
	for index: int in range(3):
		var x: float = (float(index) - 1.0) * radius * 0.65
		var center: Vector2 = foot + Vector2(x, -radius * (0.3 + phase * 1.8) - (3.0 if index == 1 else 0.0))
		var pixel: float = maxf(1.0, radius * 0.09)
		if animation == &"heal":
			surface.draw_rect(Rect2(center - Vector2(pixel * 0.5, pixel * 1.5), Vector2(pixel, pixel * 3.0)), color)
			surface.draw_rect(Rect2(center - Vector2(pixel * 1.5, pixel * 0.5), Vector2(pixel * 3.0, pixel)), color)
		else:
			surface.draw_rect(Rect2(center, Vector2.ONE * pixel * 1.5), color)
