class_name EnemyPortrait
extends Control
## A clipped-safe, integer-scaled preview using the board's exact authored frames.

@export var definition: EnemyDefinition:
	set(value):
		definition = value
		_preview_time = 0.0
		_update_animation()
		_sync_processing()
		queue_redraw()
@export var animate: bool = true:
	set(value):
		animate = value
		_sync_processing()
@export var specials_enabled: bool = true

var preview_animation: StringName = &"walk"
var preview_elapsed: float = 0.0
var _preview_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(160, 180)
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_processing)
	_sync_processing()


func configure(value: EnemyDefinition) -> void:
	definition = value


func start_preview() -> void:
	animate = true


func stop_preview() -> void:
	animate = false


func set_preview_time(seconds: float) -> void:
	_preview_time = maxf(0.0, seconds)
	_update_animation()
	queue_redraw()


func _sync_processing() -> void:
	set_process(animate and is_visible_in_tree() and definition != null)


func _process(delta: float) -> void:
	set_preview_time(_preview_time + delta)


func _update_animation() -> void:
	preview_animation = &"walk"
	preview_elapsed = _preview_time
	if definition == null or definition.animation_frames == null or not specials_enabled:
		return
	var special: StringName = &""
	var duration: float = 0.0
	if definition.animation_frames.has_animation(&"heal"):
		special = &"heal"
		duration = 0.55
	elif definition.animation_frames.has_animation(&"cast"):
		special = &"cast"
		duration = 1.15
	if special == &"":
		return
	var phase: float = fposmod(_preview_time, 3.0 + duration)
	if phase >= 3.0:
		preview_animation = special
		preview_elapsed = phase - 3.0
	else:
		preview_elapsed = phase


func _draw() -> void:
	if definition == null:
		return
	var texture: Texture2D = EnemyVisuals.frame_texture(definition, preview_animation, preview_elapsed)
	if texture == null:
		return
	var bounds: Rect2 = EnemyVisuals.union_bounds(definition)
	var available: Vector2 = (size - Vector2(40, 48)).max(Vector2.ONE)
	var scale: float = minf(available.x / maxf(1.0, bounds.size.x), available.y / maxf(1.0, bounds.size.y))
	if scale >= 1.0:
		scale = floorf(scale)
	var origin: Vector2 = ((size - bounds.size * scale) * 0.5 - bounds.position * scale).floor()
	var foot: Vector2 = origin + definition.board_anchor * texture.get_size() * scale
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, bounds.size.x * scale * 0.32, Color(0.035, 0.07, 0.05, 0.55))
	draw_set_transform(Vector2.ZERO)
	if preview_animation != &"walk":
		EnemyVisuals.draw_action_effect(self, foot, minf(available.x * 0.28, bounds.size.x * scale * 0.55), preview_animation, preview_elapsed)
	draw_texture_rect(texture, Rect2(origin, texture.get_size() * scale), false)
