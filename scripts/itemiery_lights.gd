extends Node2D
## Only the highest rarity shines/moves; lower-tier glows remain steady.

var _elapsed: float = 0.0
var _frame: int = -1


func _process(delta: float) -> void:
	_elapsed += delta
	var frame: int = int(_elapsed * 15.0)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	for index: int in range(ItemRarity.Tier.MYTHIC, ItemRarity.NAMES.size()):
		var x: int = ItemieryRoom.CENTERS[index]
		var tier := index as ItemRarity.Tier
		var tint: Color = ItemRarity.color(tier)
		var strength: float = ItemRarity.glow_strength(tier)
		if tier == ItemRarity.Tier.ORCFECCION:
			strength *= 0.85 + 0.15 * sin(_elapsed * 1.7)
		# Pixel falloff stays crisp rather than washing the masonry with bloom.
		for band: int in range(5, 0, -1):
			var spread: float = float(band * 3)
			draw_rect(Rect2(x - 23 - spread, 191 - spread, 46 + spread * 2, 6 + spread * 2), Color(tint, strength * 0.025))
		draw_rect(Rect2(x - 23, 194, 46, 1), Color(tint, strength))
		draw_rect(Rect2(x - 8, 210, 16, 3), Color(tint, strength))
	var green: Color = ItemRarity.color(ItemRarity.Tier.ORCFECCION)
	var x: int = ItemieryRoom.CENTERS[ItemRarity.Tier.ORCFECCION]
	# A narrow travelling glint across the empty plinth, and rising green embers.
	var sweep: float = fmod(_elapsed * 13.0, 70.0)
	if sweep < 46.0:
		draw_rect(Rect2(x - 23 + floorf(sweep), 193, 3, 3), Color("e1ffc2"))
	for index: int in range(6):
		var progress: float = fmod(_elapsed * 0.17 + float(index) / 6.0, 1.0)
		var px: float = x + floorf(sin(float(index) * 2.4 + progress * 2.0) * 22.0)
		var py: float = floorf(191.0 - progress * 80.0)
		var alpha: float = sin(progress * PI) * 0.7
		draw_rect(Rect2(px, py, 2, 2), Color(green, alpha))
		if index % 2 == 0:
			draw_rect(Rect2(px - 1, py + 1, 4, 1), Color(green, alpha * 0.5))
