class_name ItemieryScreen
extends Control

signal back_requested

const EXHIBIT_AREA := Rect2(-26, 114, 52, 109)
const EXHIBIT_GAP: float = 4.0


@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")

var selected_item: ItemDefinition

var back_button: Button
var inspection: ItemInspector
var _viewport: SubViewport
var _lights: Node2D
var _room: TextureRect
var _rarity_labels: Array[Label] = []
var _item_buttons: Array[ItemDisplayButton] = []
var _item_rects: Array[Rect2] = []
var _inspection_origin: ItemDisplayButton


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1410")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var shell := VBoxContainer.new()
	margin.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	var title := Label.new()
	title.text = "Itemiery"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	back_button = Button.new()
	back_button.name = "Back"
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(_request_back)
	header.add_child(back_button)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_viewport.add_child(ItemieryRoom.new())
	_lights = preload("res://scripts/itemiery_lights.gd").new()
	_viewport.add_child(_lights)
	_room = TextureRect.new()
	_room.name = "Room"
	_room.texture = _viewport.get_texture()
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_room)
	# Text stays in the main viewport, never enlarged from the room's 640×360 image.
	for index: int in range(ItemRarity.NAMES.size()):
		var label := Label.new()
		label.text = ItemRarity.NAMES[index]
		label.add_theme_color_override("font_color", ItemRarity.COLORS[index])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_room.add_child(label)
		_rarity_labels.append(label)
	_build_items()
	inspection = ItemInspector.new()
	add_child(inspection)
	inspection.closed.connect(close_inspection)
	_room.resized.connect(_layout_rarity_labels)
	_layout_rarity_labels()
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()


func _layout_rarity_labels() -> void:
	if _room.size.x <= 0.0 or _room.size.y <= 0.0:
		return
	var art_size := Vector2(_viewport.size)
	var art_scale: float = minf(_room.size.x / art_size.x, _room.size.y / art_size.y)
	var art_origin: Vector2 = (_room.size - art_size * art_scale) * 0.5
	for index: int in range(_rarity_labels.size()):
		var label: Label = _rarity_labels[index]
		var plaque: Rect2 = ItemieryRoom.plaque_rect(index)
		label.add_theme_font_size_override("font_size", maxi(16, roundi(12.0 * art_scale)))
		label.position = (art_origin + plaque.position * art_scale).round()
		label.size = (plaque.size * art_scale).round()
	for index: int in range(_item_buttons.size()):
		var button: ItemDisplayButton = _item_buttons[index]
		button.position = (art_origin + _item_rects[index].position * art_scale).round()
		button.size = (_item_rects[index].size * art_scale).round()
	# Exhibit targets use room coordinates; all lettering stays native resolution.


func _build_items() -> void:
	var totals: Dictionary = {}
	var offsets: Dictionary = {}
	for item: ItemDefinition in catalog.items:
		totals[item.rarity] = int(totals.get(item.rarity, 0)) + 1
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for item: ItemDefinition in catalog.items:
		var ordinal: int = int(offsets.get(item.rarity, 0))
		var count: int = int(totals[item.rarity])
		var button := ItemDisplayButton.new()
		button.name = String(item.id)
		button.icon = item.icon_texture
		button.accent = ItemRarity.color(item.rarity)
		button.button_group = group
		button.pressed.connect(inspect_item.bind(item))
		_room.add_child(button)
		_item_buttons.append(button)
		# Keep the whole target inside the niche's rectangular recess, clear of
		# its arch bevel and the separate rarity plaque below the plinth.
		var gaps: float = EXHIBIT_GAP * float(count - 1)
		var extent: float = minf(48.0, minf(EXHIBIT_AREA.size.x, (EXHIBIT_AREA.size.y - gaps) / float(count)))
		var group_height: float = extent * count + gaps
		var top: float = EXHIBIT_AREA.position.y + (EXHIBIT_AREA.size.y - group_height) * 0.5
		var left: float = ItemieryRoom.CENTERS[item.rarity] + EXHIBIT_AREA.position.x + (EXHIBIT_AREA.size.x - extent) * 0.5
		_item_rects.append(Rect2(left, top + ordinal * (extent + EXHIBIT_GAP), extent, extent))
		offsets[item.rarity] = ordinal + 1
	_wire_exhibit_focus()


func _select_item(item: ItemDefinition) -> void:
	selected_item = item
	# Selection is durable; hovering and keyboard focus never open the inspector.
	for index: int in range(_item_buttons.size()):
		_item_buttons[index].set_pressed_no_signal(catalog.items[index] == item)
		_item_buttons[index].queue_redraw()


func inspect_item(item: ItemDefinition) -> void:
	if item == null or not is_visible_in_tree():
		return
	_select_item(item)
	_inspection_origin = null
	for button: ItemDisplayButton in _item_buttons:
		if button.name == String(item.id):
			_inspection_origin = button
			break
	_set_exhibit_focus(false)
	inspection.show_item(item, catalog)


func close_inspection() -> void:
	inspection.close()
	_set_exhibit_focus(true)
	if is_visible_in_tree():
		if is_instance_valid(_inspection_origin):
			_inspection_origin.grab_focus()
		else:
			back_button.grab_focus()


func open() -> void:
	inspection.close()
	_set_exhibit_focus(true)
	show()
	_sync_visibility()
	for button: ItemDisplayButton in _item_buttons:
		if selected_item != null and button.name == String(selected_item.id):
			button.grab_focus()
			return
	back_button.grab_focus()


func prepare_to_leave() -> void:
	set_process_input(false)
	set_process_unhandled_key_input(false)
	inspection.close()
	_set_exhibit_focus(true)
	_lights.set_process(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_visibility() -> void:
	if inspection == null:
		return
	var active: bool = is_visible_in_tree()
	if not active:
		prepare_to_leave()
		return
	set_process_input(true)
	_lights.set_process(true)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _request_back() -> void:
	if inspection.visible:
		inspection.dismiss()
		return
	prepare_to_leave()
	back_requested.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if inspection.visible:
			MenuAudio.activate(inspection.back_button)
		else:
			MenuAudio.activate(back_button)


func _set_exhibit_focus(enabled: bool) -> void:
	back_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button: ItemDisplayButton in _item_buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _wire_exhibit_focus() -> void:
	if _item_buttons.is_empty():
		return
	back_button.focus_next = back_button.get_path_to(_item_buttons[0])
	back_button.focus_previous = back_button.get_path_to(_item_buttons[-1])
	for index: int in range(_item_buttons.size()):
		var button: ItemDisplayButton = _item_buttons[index]
		var previous: Control = back_button if index == 0 else _item_buttons[index - 1]
		var following: Control = back_button if index == _item_buttons.size() - 1 else _item_buttons[index + 1]
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(following)
