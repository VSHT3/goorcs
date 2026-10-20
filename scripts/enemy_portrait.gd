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
var _actions: Array[StringName] = []


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
	_actions.clear()
	if definition.animation_frames != null:
		for action: StringName in [&"heal", &"attack", &"cast", &"jump_deploy", &"jump_charge", &"jump", &"jump_land", &"walk_enraged", &"walk_damaged", &"walk_critical"]:
			if definition.animation_frames.has_animation(action):
				_actions.append(action)
	if _actions.is_empty():
		_actions.append(&"walk")
	_action = _actions[0]
	_playing = true
	_action_duration = 0.0
	for action: StringName in _actions:
		_action_duration += EnemyVisuals.animation_duration(definition, action)
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
	var cursor: float = _preview_time
	if cursor < _action_duration:
		for action: StringName in _actions:
			var duration: float = EnemyVisuals.animation_duration(definition, action)
			if cursor < duration:
				_action = action
				preview_animation = action
				preview_elapsed = cursor
				return
			cursor -= duration
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
	var jump_room: float = 32.0 if definition.animation_frames != null and definition.animation_frames.has_animation(&"jump") else 0.0
	bounds.position.y -= jump_room
	bounds.size.y += jump_room
	var available: Vector2 = (size - Vector2(40, 48)).max(Vector2.ONE)
	var scale: float = minf(available.x / maxf(1.0, bounds.size.x), available.y / maxf(1.0, bounds.size.y))
	if scale >= 1.0:
		scale = floorf(scale)
	var origin: Vector2 = ((size - bounds.size * scale) * 0.5 - bounds.position * scale).floor()
	var foot: Vector2 = origin + definition.board_anchor * texture.get_size() * scale
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, bounds.size.x * scale * 0.32, Color(0.035, 0.07, 0.05, 0.55))
	draw_set_transform(Vector2.ZERO)
	if preview_animation == &"heal" or (preview_animation == &"cast" and definition.summon_pool.is_empty()):
		EnemyVisuals.draw_action_effect(self, foot, minf(available.x * 0.28, bounds.size.x * scale * 0.55), preview_animation, preview_elapsed)
	if preview_animation == &"jump":
		var duration: float = maxf(0.001, EnemyVisuals.animation_duration(definition, &"jump"))
		origin.y -= sin(clampf(preview_elapsed / duration, 0.0, 1.0) * PI) * jump_room * scale
	draw_texture_rect(texture, Rect2(origin, texture.get_size() * scale), false)
	if preview_animation != &"death" and definition.hit_shield > 0:
		var visible: Rect2 = EnemyVisuals.opaque_bounds(texture)
		visible = Rect2(origin + visible.position * scale, visible.size * scale)
		EnemyVisuals.draw_hit_shield(self, visible, definition.hit_shield, definition.hit_shield, minf(available.x, available.y) * 0.65)
