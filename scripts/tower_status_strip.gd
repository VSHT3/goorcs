class_name TowerStatusStrip
extends HFlowContainer
## Accepted crowd control on the inspected tower, matching its battlefield
## marks: orbiting stars (stun), green Soulfire (wither), crossed sigil (silence).

const NUMBERS: FontFile = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const STAR := Color("f5ce56")
const STAR_EDGE := Color("8c5b2c")
const SOULFIRE: Array[Color] = [Color("1f6b43"), Color("4fd27f"), Color("dcffe6")]
const VOID := Color("9d7bff")
const STYLES: Dictionary[String, Array] = {
	"stun": [Color("ead58c"), Color("7d6a33")],
	"wither": [Color("8fe0a8"), Color("2f7a50")],
	"silence": [Color("c9b5f2"), Color("5f4c99")],
}

var _chips: Dictionary[String, PanelContainer] = {}


func _init() -> void:
	name = "TowerStatus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)
	hide()


## The tower's active effects, longest-lasting control first in a fixed order.
static func effects(tower: Dictionary, silenced_remaining: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stunned: float = float(tower.get("stunned_remaining", 0.0))
	if stunned > 0.0:
		result.append({"kind": "stun", "title": "Stunned", "value": "%.1fs" % stunned})
	var withered: float = float(tower.get("wither_remaining", 0.0))
	if withered > 0.0 and float(tower.get("wither", 0.0)) > 0.0:
		result.append({"kind": "wither", "title": "Withered", "value": "-%d%% · %.1fs" % [roundi(float(tower["wither"]) * 100.0), withered]})
	if silenced_remaining > 0.0 and String(tower.get("element", "")) == "magic":
		result.append({"kind": "silence", "title": "Silenced", "value": "%.1fs" % silenced_remaining})
	return result


func refresh(tower: Dictionary, silenced_remaining: float) -> void:
	var active: Array[Dictionary] = effects(tower, silenced_remaining) if not tower.is_empty() else [] as Array[Dictionary]
	var shown: Dictionary[String, bool] = {}
	for effect: Dictionary in active:
		var kind: String = effect["kind"]
		shown[kind] = true
		if not _chips.has(kind):
			_chips[kind] = _chip(kind)
			add_child(_chips[kind])
		var chip: PanelContainer = _chips[kind]
		(chip.get_node("Row/Title") as Label).text = effect["title"]
		(chip.get_node("Row/Value") as Label).text = effect["value"]
		chip.show()
		move_child(chip, shown.size() - 1)
	for kind: String in _chips:
		_chips[kind].visible = shown.has(kind)
	visible = not shown.is_empty()


func active_kinds() -> Array[String]:
	var result: Array[String] = []
	if not visible:
		return result
	for child: Node in get_children():
		if child is PanelContainer and (child as Control).visible:
			result.append(String(child.name))
	return result


func _chip(kind: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = kind
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1714")
	style.border_color = STYLES[kind][1]
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, kind))
	row.add_child(icon)
	for part: String in ["Title", "Value"]:
		var label := Label.new()
		label.name = part
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", STYLES[kind][0])
		if part == "Value":
			label.add_theme_font_override("font", NUMBERS)
		row.add_child(label)
	return chip


# Pixel glyphs drawn on a 14×14 grid, echoing each effect's board mark.
static func _draw_icon(icon: Control, kind: String) -> void:
	match kind:
		"stun":
			var points := PackedVector2Array()
			for index: int in range(10):
				var radius: float = 6.5 if index % 2 == 0 else 2.8
				var angle: float = -PI / 2.0 + float(index) * PI / 5.0
				points.append((Vector2(7, 7.5) + Vector2(cos(angle), sin(angle)) * radius).round())
			icon.draw_colored_polygon(points, STAR)
			points.append(points[0])
			icon.draw_polyline(points, STAR_EDGE, 1.0)
		"wither":
			for cell: Array in [[6, 1, 1], [5, 3, 1], [7, 3, 1], [4, 5, 1], [8, 5, 1], [6, 4, 2], [3, 7, 0], [4, 7, 1], [6, 6, 2], [8, 7, 1], [9, 7, 0], [3, 9, 0], [4, 9, 1], [6, 8, 2], [8, 9, 1], [9, 9, 0], [4, 11, 0], [6, 10, 1], [8, 11, 0], [5, 12, 0], [7, 12, 0]]:
				icon.draw_rect(Rect2(int(cell[0]), int(cell[1]), 2, 2), SOULFIRE[int(cell[2])])
		"silence":
			icon.draw_arc(Vector2(7, 7), 5.5, 0.0, TAU, 16, VOID, 2.0, false)
			icon.draw_rect(Rect2(6, 6, 2, 2), Color("ecd9ff"))
			icon.draw_line(Vector2(2, 12), Vector2(12, 2), Color("ff6b6b"), 2.0)
