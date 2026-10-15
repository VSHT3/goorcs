class_name SandboxWorld
extends MatchWorld
## Reuse match camera/input and board rendering, with only the owned board visible.

var _opened_once: bool = false


func configure(dimensions: Vector2i, _slot: int = 0, _origin: int = 0) -> void:
	if dimensions == _dimensions:
		return
	super.configure(dimensions, 0)
	boards[0].mirror_horizontal = false
	boards[1].position = boards[0].position
	boards[1].hide()
	boards[1].input_enabled = false
	_reset_camera()


func set_active(value: bool) -> void:
	var previous_position: Vector2 = camera.position
	var previous_zoom: Vector2 = camera.zoom
	super.set_active(value)
	if value and _opened_once:
		camera.position = previous_position
		camera.zoom = previous_zoom
		_target_zoom = previous_zoom.x
		_update_camera_bounds()
		camera.position = _clamped_position(camera.position)
		camera.force_update_scroll()
	if value:
		_opened_once = true


func _configure_terrain() -> void:
	# PathBoard draws the shared terrain/apron itself; no phantom opponent field.
	_terrain.hide()
