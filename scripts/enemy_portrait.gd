class_name EnemyPortrait
extends Control
## A clipped-safe, integer-scaled preview using the board's exact authored frames.

@export var definition: EnemyDefinition:
	set(value):
		definition = value
		_preview_time = 0.0
		_action = &""
		_playing = false
		_update_animation()
		_sync_processing()
		queue_redraw()
@export var animate: bool = true:
	set(value):
		animate = value
		_sync_processing()

var preview_animation: StringName = &"walk"
var preview_elapsed: float = 0.0
var _preview_time: float = 0.0
var _action: StringName = &""
var _playing: bool = false
var _action_duration: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click or press Enter / Space to replay this enemy's animation."
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
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


## Repeated activation deliberately restarts the action from its first frame.
func replay_action() -> void:
	if not is_visible_in_tree() or definition == null:
		return
	_action = &""
	_playing = true
	if definition.animation_frames != null:
		if definition.animation_frames.has_animation(&"heal"):
			_action = &"heal"
		elif definition.animation_frames.has_animation(&"cast"):
			_action = &"cast"
	_action_duration = 0.55 if _action == &"heal" else 1.15
	if _action == &"":
		_action_duration = 0.0
		if definition.animation_frames != null:
			var frames: SpriteFrames = definition.animation_frames
			for index: int in range(frames.get_frame_count(&"walk")):
				_action_duration += frames.get_frame_duration(&"walk", index) / frames.get_animation_speed(&"walk")
	set_preview_time(0.0)
	_sync_processing()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		replay_action()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		replay_action()
		accept_event()


func _sync_processing() -> void:
	set_process(animate and _playing and is_visible_in_tree() and definition != null)


func _process(delta: float) -> void:
	set_preview_time(_preview_time + delta)


func _update_animation() -> void:
	preview_animation = &"walk"
	preview_elapsed = 0.0
	if definition == null or definition.animation_frames == null or not _playing:
		return
	if _preview_time < _action_duration:
		preview_animation = _action if _action != &"" else &"walk"
		preview_elapsed = _preview_time
	else:
		_action = &""
		_playing = false
		_sync_processing()


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size).grow(-4.0))
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
