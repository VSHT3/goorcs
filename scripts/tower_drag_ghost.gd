extends PathBoard
## Visual-only base tower; all battlefield layers inherit one translucent tint.

var _tower: Dictionary = {"id": -2, "type_id": "", "cell": Vector2i.ZERO}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(board: PathBoard) -> void:
	# References share the already-loaded artwork and its accepted framing cache.
	layout = board.layout
	size = board.size
	mirror_horizontal = board.mirror_horizontal
	tower_types = board.tower_types
	_tower_art = board._tower_art
	_texture_bounds = board._texture_bounds
	_directional_framing = board._directional_framing
	_directional_canvas_sizes = board._directional_canvas_sizes
	_tower["type_id"] = String(board._drag_placement_id)
	_tower["cell"] = board._hover
	modulate = Color(1.0, 1.0, 1.0, 0.48) if board._placement_is_legal(board._hover, _tower["type_id"]) else Color(1.0, 0.32, 0.25, 0.48)
	queue_redraw()


func _draw() -> void:
	_draw_tower(_tower, _tower_foot(_tower["cell"]))
