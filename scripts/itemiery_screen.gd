class_name ItemieryScreen
extends Control

signal back_requested

@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")

var selected_item: ItemDefinition

var back_button: Button
var _viewport: SubViewport
var _lights: Node2D
var _room: TextureRect
var _rarity_labels: Array[Label] = []
var _item_buttons: Array[ItemDisplayButton] = []
var _item_rects: Array[Rect2] = []
var _details: PanelContainer
var _item_title: Label
var _effect: Label
var _flavor: Label


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
	back_button.pressed.connect(func() -> void: back_requested.emit())
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
	if _details != null:
		_details.position = (art_origin + Vector2(32, 280) * art_scale).round()
		_details.size = (Vector2(576, 74) * art_scale).round()


func _build_items() -> void:
	var totals: Dictionary = {}
	var offsets: Dictionary = {}
	for item: ItemDefinition in catalog.items:
		totals[item.rarity] = int(totals.get(item.rarity, 0)) + 1
	var group := ButtonGroup.new()
	for item: ItemDefinition in catalog.items:
		var ordinal: int = int(offsets.get(item.rarity, 0))
		var count: int = int(totals[item.rarity])
		var button := ItemDisplayButton.new()
		button.name = String(item.id)
		button.icon = item.icon_texture
		button.accent = ItemRarity.color(item.rarity)
		button.button_group = group
		button.pressed.connect(_select_item.bind(item))
		button.focus_entered.connect(_select_item.bind(item))
		_room.add_child(button)
		_item_buttons.append(button)
		_item_rects.append(Rect2(ItemieryRoom.CENTERS[item.rarity] - 14, 195 - (count - ordinal) * 32, 28, 28))
		offsets[item.rarity] = ordinal + 1
	_details = PanelContainer.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.047, 0.078, 0.055, 0.94)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_details.add_theme_stylebox_override("panel", style)
	_room.add_child(_details)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 3)
	_details.add_child(text)
	_item_title = Label.new()
	_item_title.add_theme_font_size_override("font_size", 22)
	text.add_child(_item_title)
	_effect = Label.new()
	_effect.add_theme_font_size_override("font_size", 18)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_effect)
	_flavor = Label.new()
	_flavor.add_theme_font_size_override("font_size", 16)
	_flavor.add_theme_color_override("font_color", Color("aebba5"))
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_flavor)
	for label: Label in [_item_title, _effect, _flavor]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.visible = not catalog.items.is_empty()
	if not catalog.items.is_empty():
		_select_item(catalog.items[0])


func _select_item(item: ItemDefinition) -> void:
	selected_item = item
	_item_title.text = item.title
	_item_title.add_theme_color_override("font_color", ItemRarity.color(item.rarity))
	_effect.text = item.effect_text
	_flavor.text = item.flavor_text
	_flavor.visible = not item.flavor_text.is_empty()
	for index: int in range(_item_buttons.size()):
		_item_buttons[index].set_pressed_no_signal(catalog.items[index] == item)
		_item_buttons[index].queue_redraw()


func open() -> void:
	show()
	back_button.grab_focus()


func prepare_to_leave() -> void:
	set_process_unhandled_key_input(false)
	_lights.set_process(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_visibility() -> void:
	var active: bool = is_visible_in_tree()
	set_process_unhandled_key_input(active)
	_lights.set_process(active)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		MenuAudio.activate(back_button)
		get_viewport().set_input_as_handled()
