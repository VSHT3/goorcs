extends Node2D
## Restrained door-frame light; no item or pedestal glow exists in the hall.

var _elapsed: float = 0.0
var _frame: int = -1
var _active: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visibility_changed.connect(_sync_processing)
	_sync_processing()


func configure_hall() -> void:
	_elapsed = 0.0
	_frame = -1
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	_sync_processing()


func _sync_processing() -> void:
	set_process(_active and is_visible_in_tree())


func _process(delta: float) -> void:
	if not _active or not is_visible_in_tree():
		set_process(false)
		return
	_elapsed += delta
	var frame: int = int(_elapsed * 12.0)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	for index: int in range(ItemRarity.Tier.EPIC, ItemRarity.NAMES.size()):
		var x: int = ItemieryRoom.CENTERS[index]
		var tint: Color = ItemRarity.COLORS[index]
		var strength: float = 0.12 if index < ItemRarity.Tier.ORCFECCION else 0.19
		if index == ItemRarity.Tier.ORCFECCION:
			strength *= 0.88 + 0.12 * sin(_elapsed * 1.7)
		# Small fixed pixel falloff belongs to stone jamb inlays, not the leaves.
		for side: int in [-1, 1]:
			var lamp_x: int = x + side * 32
			for band: int in range(3, 0, -1):
				canvas_light(Rect2(lamp_x - band - 1, 99 - band, band * 2 + 2, band * 2 + 5), tint, strength * 0.18)
			canvas_light(Rect2(lamp_x - 1, 100, 2, 3), tint.lightened(0.25), strength + 0.3)
		canvas_light(Rect2(x - 3, 82, 6, 2), tint, strength)
	var green: Color = ItemRarity.COLORS[ItemRarity.Tier.ORCFECCION]
	var x: int = ItemieryRoom.CENTERS[ItemRarity.Tier.ORCFECCION]
	# A glint follows the stone arch. It cannot hang in midair after leaves open.
	var sweep: int = int(fmod(_elapsed * 10.0, 58.0))
	if sweep < 26:
		draw_rect(Rect2(x - 13 + sweep, 86, 2, 1), Color("dce6b5"))
	for index: int in range(4):
		var progress: float = fmod(_elapsed * 0.12 + float(index) / 4.0, 1.0)
		var side: int = -1 if index % 2 == 0 else 1
		var px: float = x + side * (33 + floorf(sin(progress * 4.0 + index) * 2.0))
		var py: float = floorf(192.0 - progress * 76.0)
		draw_rect(Rect2(px, py, 1, 2), Color(green, sin(progress * PI) * 0.5))


func canvas_light(rect: Rect2, color: Color, alpha: float) -> void:
	draw_rect(rect, Color(color, alpha))
