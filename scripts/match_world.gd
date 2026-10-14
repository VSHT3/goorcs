class_name MatchWorld
extends SubViewportContainer

const CELL_SIZE: float = 48.0
const BOARD_GAP: float = 96.0
const PAN_SPEED: float = 560.0
const HUD_TOP: float = 72.0
const HUD_BOTTOM: float = 100.0
const SIDE_MARGIN: float = 24.0


class CameraInput extends Node:
	var world: MatchWorld

	func _init(match_world: MatchWorld) -> void:
		world = match_world

	func _input(event: InputEvent) -> void:
		world._handle_camera_input(event)


var camera_bounds := Vector2.ZERO
var _dimensions := Vector2i.ZERO
var _own_slot: int = 0
var _active: bool = false
var _left_held: bool = false
var _right_held: bool = false
var _targeting_popup: PopupMenu
var _camera_input: CameraInput

@onready var boards: Array[PathBoard] = [$Viewport/Map/Host, $Viewport/Map/Guest]
@onready var camera: Camera2D = $Viewport/Map/Camera2D
@onready var _world_viewport: SubViewport = $Viewport
@onready var _terrain: MatchTerrain = $Viewport/Map/Terrain


func _ready() -> void:
	_world_viewport.world_2d = World2D.new()
	resized.connect(_fit_camera)
	var targeting := get_parent().get_node_or_null("%Targeting") as OptionButton
	if targeting != null:
		_targeting_popup = targeting.get_popup()
	_world_viewport.gui_disable_input = true
	# Container focus notifications change its native input registration.
	# Keep physical camera keys in the root viewport independently of HUD focus.
	_camera_input = CameraInput.new(self)
	add_child(_camera_input)
	_camera_input.set_process_input(false)
	set_process(false)


func configure(dimensions: Vector2i, own_slot: int) -> void:
	if dimensions == _dimensions and own_slot == _own_slot:
		return
	_cancel_motion()
	_dimensions = dimensions
	_own_slot = own_slot
	var board_size := Vector2(dimensions) * CELL_SIZE
	for slot: int in range(boards.size()):
		boards[slot].size = board_size
		boards[slot].position = Vector2(slot * (board_size.x + BOARD_GAP), 0.0)
		boards[slot].mirror_horizontal = slot == 0
	camera_bounds = Vector2(board_size.x * 0.5, board_size.x * 1.5 + BOARD_GAP)
	_fit_camera()
	_focus_own_board()


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_cancel_motion()
	visible = value
	_world_viewport.gui_disable_input = not value
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	set_process(value)
	_camera_input.set_process_input(value)
	if value:
		_fit_camera()
		_focus_own_board()


func cell_screen_position(slot: int, cell: Vector2i) -> Vector2:
	var board: PathBoard = boards[slot]
	var viewport_position: Vector2 = board.get_global_transform_with_canvas() * board.cell_center(cell)
	var container_position: Vector2 = viewport_position * size / Vector2(_world_viewport.size)
	return get_global_transform_with_canvas() * container_position


func pan(delta: float, direction: float) -> void:
	if not _active or not is_visible_in_tree() or _movement_blocked():
		_cancel_motion()
		return
	var next_x: float = clampf(camera.position.x + PAN_SPEED * maxf(delta, 0.0) * clampf(direction, -1.0, 1.0), camera_bounds.x, camera_bounds.y)
	if is_equal_approx(next_x, camera.position.x):
		return
	_cancel_strokes()
	camera.position.x = next_x
	camera.force_update_scroll()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _movement_blocked():
		_cancel_motion()
		return
	pan(delta, float(_right_held) - float(_left_held))


func _handle_camera_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code != KEY_A and code != KEY_D:
		return
	if not _active or not is_visible_in_tree():
		_cancel_motion()
		return
	if not key.pressed:
		if code == KEY_A:
			_left_held = false
		else:
			_right_held = false
		return
	if key.echo or key.alt_pressed or key.ctrl_pressed or key.meta_pressed or _movement_blocked():
		return
	if code == KEY_A:
		_left_held = true
	else:
		_right_held = true
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
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
	var root_focus: Control = get_viewport().gui_get_focus_owner()
	var world_focus: Control = _world_viewport.gui_get_focus_owner()
	return root_focus is LineEdit or root_focus is TextEdit or world_focus is LineEdit or world_focus is TextEdit or (_targeting_popup != null and _targeting_popup.visible)


func _propagate_input_event(event: InputEvent) -> bool:
	# A native HUD drag belongs to the root viewport; forwarding its mouse
	# events would let the embedded viewport replace the root drop target.
	return _active and is_visible_in_tree() and not (event is InputEventMouse and get_viewport().gui_is_dragging())


func _fit_camera() -> void:
	if not is_node_ready() or _dimensions == Vector2i.ZERO or size.x <= 0.0 or size.y <= 0.0:
		return
	_cancel_strokes()
	var board_size := Vector2(_dimensions) * CELL_SIZE
	var gameplay_height: float = maxf(size.y - HUD_TOP - HUD_BOTTOM, 1.0)
	var zoom_factor: float = minf(maxf(size.x - SIDE_MARGIN * 2.0, 1.0) / board_size.x, gameplay_height / board_size.y)
	camera.zoom = Vector2.ONE * zoom_factor
	camera.position.y = board_size.y * 0.5 + (HUD_BOTTOM - HUD_TOP) * 0.5 / zoom_factor
	camera.position.x = clampf(camera.position.x, camera_bounds.x, camera_bounds.y)
	camera.force_update_scroll()
	var half_view: Vector2 = size / camera.zoom * 0.5
	var terrain_start := Vector2(camera_bounds.x - half_view.x, camera.position.y - half_view.y) - Vector2.ONE * CELL_SIZE
	var terrain_end := Vector2(camera_bounds.y + half_view.x, camera.position.y + half_view.y) + Vector2.ONE * CELL_SIZE
	_terrain.configure(board_size, BOARD_GAP, Rect2(terrain_start, terrain_end - terrain_start))


func _focus_own_board() -> void:
	if _dimensions == Vector2i.ZERO:
		return
	camera.position.x = camera_bounds.x if _own_slot == 0 else camera_bounds.y
	camera.force_update_scroll()


func _cancel_strokes() -> void:
	for board: PathBoard in boards:
		board.cancel_stroke()


func _cancel_motion() -> void:
	_left_held = false
	_right_held = false
	_cancel_strokes()


func _drop_position(at_position: Vector2) -> Vector2:
	var viewport_position: Vector2 = at_position * Vector2(_world_viewport.size) / size
	return boards[_own_slot].get_global_transform_with_canvas().affine_inverse() * viewport_position


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _active or not is_visible_in_tree() or size.x <= 0.0 or size.y <= 0.0:
		return false
	return boards[_own_slot]._can_drop_data(_drop_position(at_position), data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	boards[_own_slot]._drop_data(_drop_position(at_position), data)
