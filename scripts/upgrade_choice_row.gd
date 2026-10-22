class_name UpgradeChoiceRow
extends Container
## Purchase choices side by side in equal columns. When the panel is too narrow
## for every choice's longest word, the choices wrap into balanced rows instead
## of splitting a word across lines (four War Drums branches become two by two).

@export var separation: int = 8

var _last_height: float = -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var height: float = _layout(size.x, true)
		if not is_equal_approx(height, _last_height):
			_last_height = height
			update_minimum_size()


func _get_minimum_size() -> Vector2:
	return Vector2(0.0, _layout(size.x, false))


## Most columns whose width still holds every visible choice's longest word,
## then rebalanced so rows differ by at most one choice.
func columns_for(width: float) -> int:
	var items: Array[Control] = _visible_items()
	if items.is_empty():
		return 1
	var widest: float = 0.0
	for item: Control in items:
		widest = maxf(widest, _longest_word(item))
	var columns: int = items.size()
	while columns > 1 and (width - separation * (columns - 1)) / float(columns) < widest:
		columns -= 1
	var rows: int = ceili(float(items.size()) / float(columns))
	return ceili(float(items.size()) / float(rows))


func _layout(width: float, apply: bool) -> float:
	var items: Array[Control] = _visible_items()
	if items.is_empty():
		return 0.0
	var columns: int = columns_for(width)
	var cell_width: float = floorf((width - separation * (columns - 1)) / float(columns))
	var y: float = 0.0
	for start: int in range(0, items.size(), columns):
		var row: Array[Control] = items.slice(start, start + columns)
		var height: float = 0.0
		for item: Control in row:
			height = maxf(height, item.get_combined_minimum_size().y)
		if apply:
			for index: int in range(row.size()):
				fit_child_in_rect(row[index], Rect2(index * (cell_width + separation), y, cell_width, height))
		y += height + separation
	return y - separation


func _visible_items() -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in get_children():
		var control := child as Control
		if control != null and control.visible and not control.top_level:
			result.append(control)
	return result


func _longest_word(item: Control) -> float:
	var button := item as Button
	if button == null:
		return item.get_combined_minimum_size().x
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var widest: float = 0.0
	for line: String in button.text.split("\n"):
		for word: String in line.split(" ", false):
			widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var style: StyleBox = button.get_theme_stylebox("normal")
	return ceilf(widest + (style.get_minimum_size().x if style != null else 0.0)) + 2.0
