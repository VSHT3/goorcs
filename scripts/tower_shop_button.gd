class_name TowerShopButton
extends Button

signal drag_started(type_id: StringName)

const NUMBER_FONT: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")

var tower_type: StringName = &""
var tower_title: String = ""
var cost: int = 0
var tower_artwork: Texture2D

var _content: MarginContainer
var _presentation: HBoxContainer


func _ready() -> void:
	_content = MarginContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 8)
	_content.add_theme_constant_override("margin_right", 8)
	_content.add_theme_constant_override("margin_top", 4)
	_content.add_theme_constant_override("margin_bottom", 4)
	add_child(_content)
	_presentation = _create_presentation(32)
	_content.add_child(_presentation)
	_content.minimum_size_changed.connect(update_minimum_size)
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	return _content.get_combined_minimum_size() if is_instance_valid(_content) else Vector2.ZERO


func refresh_caption(price: String, status: String) -> void:
	(_presentation.get_node("Caption/Title") as Label).text = tower_title
	var price_label := _presentation.get_node("Caption/Details/Price") as Label
	price_label.text = price
	price_label.visible = not price.is_empty()
	var status_label := _presentation.get_node("Caption/Details/Status") as Label
	status_label.text = ("· " if not price.is_empty() else "") + status if not status.is_empty() else ""
	status_label.visible = not status.is_empty()
	queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW or not is_instance_valid(_presentation):
		return
	var suffix: String = ""
	match get_draw_mode():
		BaseButton.DRAW_DISABLED:
			suffix = "_disabled"
		BaseButton.DRAW_PRESSED:
			suffix = "_pressed"
		BaseButton.DRAW_HOVER:
			suffix = "_hover"
		BaseButton.DRAW_HOVER_PRESSED:
			suffix = "_hover_pressed"
	var color: Color = get_theme_color("font%s_color" % suffix)
	for path: String in ["Caption/Title", "Caption/Details/Price", "Caption/Details/Status"]:
		var caption_label := _presentation.get_node(path) as Label
		if caption_label.get_theme_color("font_color") != color:
			caption_label.add_theme_color_override("font_color", color)
	var icon_suffix: String = "_normal" if suffix.is_empty() else suffix
	(_presentation.get_node("Artwork") as TextureRect).self_modulate = get_theme_color("icon%s_color" % icon_suffix)


func _create_presentation(artwork_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var artwork := TextureRect.new()
	artwork.name = "Artwork"
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.texture = tower_artwork
	artwork.custom_minimum_size = Vector2(artwork_size, artwork_size)
	artwork.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(artwork)
	var caption := VBoxContainer.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.add_theme_constant_override("separation", 0)
	row.add_child(caption)
	var details := HBoxContainer.new()
	details.name = "Details"
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_constant_override("separation", 6)
	caption.add_child(details)
	for label_name: String in ["Title", "Price", "Status"]:
		var label := Label.new()
		label.name = label_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 16)
		if label_name == "Price":
			label.add_theme_font_override("font", NUMBER_FONT)
			details.add_child(label)
		elif label_name == "Status":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(label)
		else:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.add_child(label)
	caption.move_child(caption.get_node("Title"), 0)
	(caption.get_node("Title") as Label).text = tower_title
	(details.get_node("Price") as Label).text = "%d Coins" % cost
	(details.get_node("Status") as Label).hide()
	return row


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or tower_type == &"":
		return null
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content: HBoxContainer = _create_presentation(52)
	content.custom_minimum_size.x = 240.0
	preview.add_child(content)
	set_drag_preview(preview)
	drag_started.emit(tower_type)
	return {"tower_type": String(tower_type)}
