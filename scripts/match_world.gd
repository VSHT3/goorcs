class_name MatchWorld
extends SubViewportContainer

const CELL_SIZE: float = 48.0
const BOARD_GAP: float = 96.0
const PAN_SPEED: float = 560.0
const HUD_TOP: float = 72.0
const HUD_BOTTOM: float = 100.0
const SIDE_MARGIN: float = 24.0
const MIN_ZOOM_RATIO: float = 0.55
const MAX_ZOOM_RATIO: float = 2.5
const WHEEL_ZOOM_STEP: float = 1.12
const ZOOM_RESPONSE: float = 18.0


class CameraInput extends Node:
	var world: MatchWorld

	func _init(match_world: MatchWorld) -> void:
		world = match_world

	func _input(event: InputEvent) -> void:
		world._handle_camera_input(event)


var camera_bounds := Vector2.ZERO
var camera_vertical_bounds := Vector2.ZERO
var _dimensions := Vector2i.ZERO
var _board_origin_y: int = 0
var _fit_zoom: float = 0.0
var _headroom: float = 0.0
var _bounds_zoom := Vector2.ZERO
var _target_zoom: float = 0.0
var _zoom_anchor := Vector2.ZERO
var _own_slot: int = 0
var _active: bool = false
var _input_blocked: bool = false
var _left_held: bool = false
var _right_held: bool = false
var _up_held: bool = false
var _down_held: bool = false
var _hud_popups: Array[PopupMenu] = []
var _camera_input: CameraInput

@onready var boards: Array[PathBoard] = [$Viewport/Map/Host, $Viewport/Map/Guest]
@onready var camera: Camera2D = $Viewport/Map/Camera2D
@onready var _world_viewport: SubViewport = $Viewport
@onready var _terrain: MatchTerrain = $Viewport/Map/Terrain


func _ready() -> void:
	_world_viewport.world_2d = World2D.new()
	_world_viewport.process_mode = Node.PROCESS_MODE_DISABLED
	resized.connect(_fit_camera)
	mouse_exited.connect(_clear_drag_previews)
	for path: String in ["%EnemyType"]:
		var selector := get_parent().get_node_or_null(path) as OptionButton
		if selector != null:
			_hud_popups.append(selector.get_popup())
	_world_viewport.gui_disable_input = true
	# Container focus notifications change its native input registration.
	# Keep physical camera keys in the root viewport independently of HUD focus.
	_camera_input = CameraInput.new(self)
	add_child(_camera_input)
	_camera_input.set_process_input(false)
	set_process(false)


func configure(dimensions: Vector2i, own_slot: int, board_origin_y: int = 0) -> void:
	if dimensions == _dimensions and own_slot == _own_slot and board_origin_y == _board_origin_y:
		return
	var fresh_focus: bool = _dimensions == Vector2i.ZERO or own_slot != _own_slot
	var grew: bool = _dimensions != Vector2i.ZERO and dimensions.y > _dimensions.y and board_origin_y < _board_origin_y
	_cancel_motion()
	_dimensions = dimensions
	_own_slot = own_slot
	_board_origin_y = board_origin_y
	var board_size := Vector2(dimensions) * CELL_SIZE
	# Shift the mirrored host outward while keeping both portal-facing edges fixed.
	var board_origin := Vector2.ONE * board_origin_y * CELL_SIZE
	for slot: int in range(boards.size()):
		boards[slot].size = board_size
		boards[slot].position = board_origin + Vector2(slot * (board_size.x + BOARD_GAP), 0.0)
		boards[slot].mirror_horizontal = slot == 0
	_fit_camera()
	if fresh_focus:
		_reset_camera()
	elif grew:
		_frame_expanded_board()


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_cancel_motion()
	visible = value
	_world_viewport.gui_disable_input = not value or _input_blocked
	# Canvas visibility does not propagate into a SubViewport; pause its local effects explicitly.
	_world_viewport.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	set_process(value)
	_camera_input.set_process_input(value)
	if value:
		_reset_camera()


func set_input_blocked(value: bool) -> void:
	_input_blocked = value
	_cancel_motion()
	_cancel_strokes()
	_world_viewport.gui_disable_input = value or not _active


func cell_screen_position(slot: int, cell: Vector2i) -> Vector2:
	var board: PathBoard = boards[slot]
	var viewport_position: Vector2 = board.get_global_transform_with_canvas() * board.cell_center(cell)
	var container_position: Vector2 = viewport_position * size / Vector2(_world_viewport.size)
	return get_global_transform_with_canvas() * container_position


func pan(delta: float, direction: Vector2) -> void:
	if not _active or not is_visible_in_tree() or _movement_blocked():
		_cancel_motion()
		return
	if direction == Vector2.ZERO:
		return
	if not camera.zoom.is_equal_approx(_bounds_zoom):
		_update_camera_bounds()
	var next_position: Vector2 = camera.position + direction.limit_length() * PAN_SPEED * (_fit_zoom / camera.zoom.x) * maxf(delta, 0.0)
	next_position = _clamped_position(next_position)
	if next_position.is_equal_approx(camera.position):
		return
	_cancel_strokes()
	camera.position = next_position
	camera.force_update_scroll()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _movement_blocked():
		_cancel_motion()
		return
	_update_zoom(delta)
	pan(delta, Vector2(float(_right_held) - float(_left_held), float(_down_held) - float(_up_held)))


func _handle_camera_input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree() or _input_blocked:
		_cancel_motion()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and (mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var exponent: float = mouse.factor if mouse.factor > 0.0 else 1.0
			if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				exponent = -exponent
			if zoom_at(pow(WHEEL_ZOOM_STEP, exponent), mouse.position):
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		if zoom_at(gesture.factor, gesture.position):
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_HOME:
		if key.pressed and not (key.echo or key.alt_pressed or key.ctrl_pressed or key.meta_pressed or _movement_blocked() or get_viewport().gui_is_dragging()):
			_cancel_motion()
			_frame_expanded_board()
			get_viewport().set_input_as_handled()
		return
	if code != KEY_A and code != KEY_D and code != KEY_W and code != KEY_S:
		return
	if key.pressed and (key.echo or key.alt_pressed or key.ctrl_pressed or key.meta_pressed or _movement_blocked()):
		return
	match code:
		KEY_A: _left_held = key.pressed
		KEY_D: _right_held = key.pressed
		KEY_W: _up_held = key.pressed
		KEY_S: _down_held = key.pressed
	if key.pressed:
		get_viewport().set_input_as_handled()


func zoom_at(factor: float, screen_position: Vector2) -> bool:
	if not _active or not is_visible_in_tree() or factor <= 0.0 or not is_finite(factor) or _fit_zoom <= 0.0:
		return false
	if _movement_blocked() or get_viewport().gui_is_dragging() or _hud_at_point(get_parent(), screen_position):
		return false
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false
	_zoom_anchor = local_position * Vector2(_world_viewport.size) / size
	_target_zoom = clampf(_target_zoom * factor, _minimum_zoom(), _fit_zoom * MAX_ZOOM_RATIO)
	_cancel_strokes()
	return true


func _update_zoom(delta: float) -> void:
	if camera.zoom.x == _target_zoom:
		return
	var next_zoom: float = lerpf(camera.zoom.x, _target_zoom, 1.0 - exp(-ZOOM_RESPONSE * maxf(delta, 0.0)))
	if absf(next_zoom - _target_zoom) < 0.0001:
		next_zoom = _target_zoom
	var canvas_before: Vector2 = _world_viewport.get_canvas_transform().affine_inverse() * _zoom_anchor
	_cancel_strokes()
	camera.zoom = Vector2.ONE * next_zoom
	if next_zoom == _target_zoom:
		# Camera vectors store float32 components; retain the accepted value so
		# a settled float64 target cannot keep cancelling path strokes forever.
		_target_zoom = camera.zoom.x
	camera.force_update_scroll()
	var canvas_after: Vector2 = _world_viewport.get_canvas_transform().affine_inverse() * _zoom_anchor
	camera.position += canvas_before - canvas_after
	_update_camera_bounds()
	camera.position = _clamped_position(camera.position)
	camera.force_update_scroll()
	_configure_terrain()


func _hud_at_point(node: Node, point: Vector2) -> bool:
	# Root _input precedes GUI dispatch, so use this event's position rather
	# than the previous event's hovered control. Never consume panel scrolling.
	if node == self:
		return false
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return false
		var local_point: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and Rect2(Vector2.ZERO, control.size).has_point(local_point):
			return true
		if control.clip_contents and not Rect2(Vector2.ZERO, control.size).has_point(local_point):
			return false
	for child: Node in node.get_children():
		if _hud_at_point(child, point):
			return true
	return false


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_DRAG_END:
		_clear_drag_previews()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_motion()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and _active:
		# A parent's visibility signal runs before its children's inherited
		# visibility is updated. Never undo activation during that propagation.
		if is_visible_in_tree():
			_fit_camera()
		else:
			_cancel_motion()


func _movement_blocked() -> bool:
	if _input_blocked:
		return true
	var root_focus: Control = get_viewport().gui_get_focus_owner()
	var world_focus: Control = _world_viewport.gui_get_focus_owner()
	if root_focus is LineEdit or root_focus is TextEdit or world_focus is LineEdit or world_focus is TextEdit:
		return true
	for popup: PopupMenu in _hud_popups:
		if popup.visible:
			return true
	return false


func _propagate_input_event(event: InputEvent) -> bool:
	# A native HUD drag belongs to the root viewport; forwarding its mouse
	# events would let the embedded viewport replace the root drop target.
	return _active and not _input_blocked and is_visible_in_tree() and not (event is InputEventMouse and get_viewport().gui_is_dragging())


func _fit_camera() -> void:
	if not is_node_ready() or _dimensions == Vector2i.ZERO or size.x <= 0.0 or size.y <= 0.0:
		return
	_cancel_strokes()
	var ratio: float = camera.zoom.x / _fit_zoom if _fit_zoom > 0.0 else 1.0
	var initial_size := Vector2(maxi(_dimensions.x + _board_origin_y, 1), maxi(_dimensions.y + 2 * _board_origin_y, 1)) * CELL_SIZE
	_headroom = maxf(boards[0].visual_headroom(), boards[1].visual_headroom())
	var gameplay_height: float = maxf(size.y - HUD_TOP - HUD_BOTTOM, 1.0)
	_fit_zoom = minf(maxf(size.x - SIDE_MARGIN * 2.0, 1.0) / initial_size.x, gameplay_height / (initial_size.y + _headroom))
	camera.zoom = Vector2.ONE * clampf(_fit_zoom * ratio, _minimum_zoom(), _fit_zoom * MAX_ZOOM_RATIO)
	_target_zoom = camera.zoom.x
	_update_camera_bounds()
	camera.position = _clamped_position(camera.position)
	camera.force_update_scroll()
	_configure_terrain()


func _update_camera_bounds() -> void:
	var board_size := Vector2(_dimensions) * CELL_SIZE
	var half_width: float = minf(board_size.x * 0.5, maxf(size.x - SIDE_MARGIN * 2.0, 1.0) * 0.5 / camera.zoom.x)
	camera_bounds = Vector2(boards[0].position.x + half_width, boards[1].position.x + board_size.x - half_width)
	_bounds_zoom = camera.zoom
	var half_height: float = maxf(size.y - HUD_TOP - HUD_BOTTOM, 1.0) * 0.5 / camera.zoom.y
	var hud_offset: float = (HUD_BOTTOM - HUD_TOP) * 0.5 / camera.zoom.y
	var top: float = _board_origin_y * CELL_SIZE - _headroom
	var bottom: float = _board_origin_y * CELL_SIZE + board_size.y
	camera_vertical_bounds = Vector2(top + half_height + hud_offset, bottom - half_height + hud_offset)
	if camera_vertical_bounds.x > camera_vertical_bounds.y:
		camera_vertical_bounds = Vector2.ONE * ((top + bottom) * 0.5 + hud_offset)


func _clamped_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, camera_bounds.x, camera_bounds.y), clampf(value.y, camera_vertical_bounds.x, camera_vertical_bounds.y))


func _configure_terrain() -> void:
	var half_view: Vector2 = size / camera.zoom * 0.5
	var terrain_start := Vector2(camera_bounds.x - half_view.x, camera_vertical_bounds.x - half_view.y) - Vector2.ONE * CELL_SIZE
	var terrain_end := Vector2(camera_bounds.y + half_view.x, camera_vertical_bounds.y + half_view.y) + Vector2.ONE * CELL_SIZE
	_terrain.configure(Vector2(_dimensions) * CELL_SIZE, BOARD_GAP, Rect2(terrain_start, terrain_end - terrain_start), boards[0].position.x)


func _expanded_fit_zoom() -> float:
	var board_size := Vector2(_dimensions) * CELL_SIZE
	return minf(maxf(size.x - SIDE_MARGIN * 2.0, 1.0) / board_size.x,
		maxf(size.y - HUD_TOP - HUD_BOTTOM - 24.0, 1.0) / (board_size.y + _headroom))


func _minimum_zoom() -> float:
	return minf(_fit_zoom * MIN_ZOOM_RATIO, _expanded_fit_zoom())


func _frame_expanded_board() -> void:
	camera.zoom = Vector2.ONE * _expanded_fit_zoom()
	_target_zoom = camera.zoom.x
	_update_camera_bounds()
	var board_size := Vector2(_dimensions) * CELL_SIZE
	camera.position = boards[_own_slot].position + Vector2(board_size.x * 0.5,
		(board_size.y - _headroom) * 0.5 + (HUD_BOTTOM - HUD_TOP) * 0.5 / camera.zoom.y)
	camera.position = _clamped_position(camera.position)
	camera.force_update_scroll()
	_configure_terrain()


func _reset_camera() -> void:
	if _dimensions == Vector2i.ZERO:
		return
	_fit_zoom = 0.0
	_fit_camera()
	var board_size := Vector2(_dimensions) * CELL_SIZE
	var headroom: float = _headroom
	camera.position = boards[_own_slot].position + Vector2(board_size.x * 0.5,
		(board_size.y - headroom) * 0.5 + (HUD_BOTTOM - HUD_TOP) * 0.5 / camera.zoom.y)
	camera.position = _clamped_position(camera.position)
	camera.force_update_scroll()


func _cancel_strokes() -> void:
	for board: PathBoard in boards:
		board.cancel_stroke()


func _clear_drag_previews() -> void:
	for board: PathBoard in boards:
		board.clear_drag_preview()


func _cancel_motion() -> void:
	_left_held = false
	_right_held = false
	_up_held = false
	_down_held = false
	_target_zoom = camera.zoom.x
	_cancel_strokes()


func _drop_position(at_position: Vector2) -> Vector2:
	var viewport_position: Vector2 = at_position * Vector2(_world_viewport.size) / size
	return boards[_own_slot].get_global_transform_with_canvas().affine_inverse() * viewport_position


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _active or _input_blocked or not is_visible_in_tree() or size.x <= 0.0 or size.y <= 0.0:
		_clear_drag_previews()
		return false
	return boards[_own_slot]._can_drop_data(_drop_position(at_position), data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	boards[_own_slot]._drop_data(_drop_position(at_position), data)
