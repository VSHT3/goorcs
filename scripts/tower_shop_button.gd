class_name TowerShopButton
extends Button

signal drag_started(type_id: StringName)

var tower_type: StringName = &""
var tower_title: String = ""
var cost: int = 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or tower_type == &"":
		return null
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(content)
	var artwork := TextureRect.new()
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.texture = icon
	artwork.custom_minimum_size = Vector2(52, 52)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(artwork)
	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "%s\n%d Coins" % [tower_title, cost]
	content.add_child(caption)
	set_drag_preview(preview)
	drag_started.emit(tower_type)
	return {"tower_type": String(tower_type)}
