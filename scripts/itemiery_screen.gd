class_name ItemieryScreen
extends Control

signal back_requested

const ART_SIZE := Vector2(640, 360)
const CAMERA_HOME := Vector2(320, 180)

@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")

var selected_item: ItemDefinition
var current_rarity: int = -1
var transitioning: bool = false
var door_buttons: Array[Button] = []
var back_button: Button
var inspection: ItemInspector
var page_previous_button: Button
var page_next_button: Button
var page_label: Label

var _viewport: SubViewport
var _lights: Node2D
var _hall: ItemieryRoom
var _chamber: ItemieryChamber
var _camera: Camera2D
var _room: TextureRect
var _heading: Label
var _hall_ui: Control
var _shelf_ui: Control
var _shade: ColorRect
var _paging: HBoxContainer
var _rarity_labels: Array[Label] = []
var _item_buttons: Array[ItemDisplayButton] = []
var _page_items: Array[ItemDefinition] = []
var _room_items: Array[ItemDefinition] = []
var _room_page: int = 0
var _last_door: int = 0
var _inspection_origin: ItemDisplayButton
var _transition: Tween


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
	_heading = Label.new()
	_heading.text = "Itemiery"
	_heading.add_theme_font_size_override("font_size", 34)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	back_button = Button.new()
	back_button.name = "Back"
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(_request_back)
	header.add_child(back_button)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_hall = ItemieryRoom.new()
	_viewport.add_child(_hall)
	_lights = preload("res://scripts/itemiery_lights.gd").new()
	_viewport.add_child(_lights)
	_lights.call(&"configure_hall")
	_chamber = ItemieryChamber.new()
	_viewport.add_child(_chamber)
	_chamber.set_active(false)
	_chamber.hide()
	_camera = Camera2D.new()
	_camera.name = "EntryCamera"
	_camera.position = CAMERA_HOME
	_camera.position_smoothing_enabled = false
	_viewport.add_child(_camera)

	_room = TextureRect.new()
	_room.name = "Room"
	_room.texture = _viewport.get_texture()
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_room)
	_hall_ui = _overlay("Doors")
	_shelf_ui = _overlay("Shelves")
	_shelf_ui.hide()
	_build_doors()
	_shade = ColorRect.new()
	_shade.name = "EntryShade"
	_shade.color = Color("080e0b")
	_shade.modulate.a = 0.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.add_child(_shade)
	_build_paging(shell)

	inspection = ItemInspector.new()
	add_child(inspection)
	inspection.closed.connect(close_inspection)
	_room.resized.connect(_layout_rarity_labels)
	_layout_rarity_labels()
	visibility_changed.connect(_sync_visibility)
	_update_navigation()
	_sync_visibility()


func _overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.add_child(overlay)
	return overlay


func _build_doors() -> void:
	for index: int in range(ItemRarity.NAMES.size()):
		var button := Button.new()
		button.name = ItemRarity.NAMES[index] + "Door"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(ItemRarity.COLORS[index], 0.07)
		hover.border_color = ItemRarity.COLORS[index].lightened(0.2)
		hover.set_border_width_all(2)
		button.add_theme_stylebox_override("hover", hover)
		var focus: StyleBoxFlat = hover.duplicate()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("f0f6dc")
		button.add_theme_stylebox_override("focus", focus)
		MenuAudio.bind_action(button)
		button.pressed.connect(enter_room.bind(index as ItemRarity.Tier))
		button.mouse_entered.connect(_highlight_door.bind(index))
		button.mouse_exited.connect(_restore_door_highlight)
		button.focus_entered.connect(_highlight_door.bind(index))
		button.focus_exited.connect(_restore_door_highlight)
		_hall_ui.add_child(button)
		door_buttons.append(button)
		var label := Label.new()
		label.text = ItemRarity.NAMES[index]
		label.add_theme_color_override("font_color", ItemRarity.COLORS[index])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hall_ui.add_child(label)
		_rarity_labels.append(label)


func _build_paging(shell: VBoxContainer) -> void:
	_paging = HBoxContainer.new()
	_paging.name = "RoomPages"
	_paging.alignment = BoxContainer.ALIGNMENT_CENTER
	_paging.add_theme_constant_override("separation", 14)
	shell.add_child(_paging)
	page_previous_button = Button.new()
	page_previous_button.name = "PreviousShelfPage"
	page_previous_button.text = "‹"
	page_previous_button.custom_minimum_size = Vector2(40, 34)
	MenuAudio.bind_action(page_previous_button)
	page_previous_button.pressed.connect(_change_page.bind(-1))
	_paging.add_child(page_previous_button)
	page_label = Label.new()
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.add_theme_font_size_override("font_size", 18)
	_paging.add_child(page_label)
	page_next_button = Button.new()
	page_next_button.name = "NextShelfPage"
	page_next_button.text = "›"
	page_next_button.custom_minimum_size = Vector2(40, 34)
	MenuAudio.bind_action(page_next_button)
	page_next_button.pressed.connect(_change_page.bind(1))
	_paging.add_child(page_next_button)
	_paging.hide()


func _layout_rarity_labels() -> void:
	if _room.size.x <= 0.0 or _room.size.y <= 0.0:
		return
	var art_scale: float = minf(_room.size.x / ART_SIZE.x, _room.size.y / ART_SIZE.y)
	var art_origin: Vector2 = (_room.size - ART_SIZE * art_scale) * 0.5
	# Native targets and lettering follow the letterboxed art, never its camera zoom.
	for index: int in range(door_buttons.size()):
		var door: Rect2 = ItemieryRoom.door_rect(index)
		door_buttons[index].position = (art_origin + door.position * art_scale).round()
		door_buttons[index].size = (door.size * art_scale).round()
		var label: Label = _rarity_labels[index]
		var plaque: Rect2 = ItemieryRoom.plaque_rect(index)
		label.add_theme_font_size_override("font_size", clampi(roundi(12.0 * art_scale), 16, 28))
		label.position = (art_origin + plaque.position * art_scale).round()
		label.size = (plaque.size * art_scale).round()
	for index: int in range(_item_buttons.size()):
		var slot: Rect2 = ItemieryChamber.slot_rect(index)
		_item_buttons[index].position = (art_origin + slot.position * art_scale).round()
		_item_buttons[index].size = (slot.size * art_scale).round()


func enter_room(tier: ItemRarity.Tier) -> void:
	if not is_visible_in_tree() or transitioning or current_rarity != -1 or inspection.visible:
		return
	if tier < 0 or tier >= door_buttons.size():
		return
	_last_door = tier
	transitioning = true
	_hall.set_hovered_door(-1)
	_update_navigation()
	back_button.grab_focus()
	var doorway: Rect2 = ItemieryRoom.door_rect(tier)
	_transition = create_tween()
	_transition.tween_method(_open_door.bind(tier), 0.0, 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_callback(_hall_ui.hide)
	_transition.tween_property(_camera, "position", doorway.get_center(), 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_transition.parallel().tween_property(_camera, "zoom", Vector2.ONE * 3.4, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_transition.parallel().tween_property(_shade, "modulate:a", 1.0, 0.10).set_delay(0.24)
	_transition.tween_callback(_show_chamber.bind(tier))
	_transition.tween_property(_shade, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_transition.tween_callback(_finish_entry)


func _open_door(progress: float, tier: int) -> void:
	_hall.set_door_opening(tier, progress)


func _show_chamber(tier: ItemRarity.Tier) -> void:
	current_rarity = tier
	_hall.hide()
	_lights.hide()
	_lights.call(&"set_active", false)
	_reset_camera()
	_hall.reset_doors()
	_chamber.configure(tier)
	_chamber.show()
	_chamber.set_active(is_visible_in_tree())
	_heading.text = ItemRarity.NAMES[tier]
	_heading.add_theme_color_override("font_color", ItemRarity.COLORS[tier])
	_room_items.clear()
	for item: ItemDefinition in catalog.items:
		if item != null and item.rarity == tier:
			_room_items.append(item)
	var selected_index: int = _room_items.find(selected_item)
	_room_page = maxi(0, selected_index) / ItemieryChamber.SLOT_COUNT
	_build_items()
	_shelf_ui.show()


func _finish_entry() -> void:
	_transition = null
	transitioning = false
	_update_navigation()
	_focus_shelf()


func leave_room() -> void:
	if inspection != null and inspection.visible:
		inspection.dismiss()
		return
	_return_to_hall()
	if is_visible_in_tree():
		door_buttons[_last_door].grab_focus()


func _return_to_hall() -> void:
	_cancel_transition()
	current_rarity = -1
	_room_page = 0
	_room_items.clear()
	_clear_items()
	_shelf_ui.hide()
	_paging.hide()
	_chamber.set_active(false)
	_chamber.hide()
	_hall.show()
	_hall.reset_doors()
	_hall.set_hovered_door(-1)
	_hall_ui.show()
	_heading.text = "Itemiery"
	_heading.remove_theme_color_override("font_color")
	_update_navigation()
	_sync_effects()


func _cancel_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
	transitioning = false
	_reset_camera()
	_shade.modulate.a = 0.0
	_hall_ui.modulate = Color.WHITE
	_shelf_ui.modulate = Color.WHITE
	_hall.reset_doors()


func _reset_camera() -> void:
	_camera.position = CAMERA_HOME
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	_camera.force_update_scroll()


func _clear_items() -> void:
	_inspection_origin = null
	for button: ItemDisplayButton in _item_buttons:
		_shelf_ui.remove_child(button)
		button.queue_free()
	_item_buttons.clear()
	_page_items.clear()


func _build_items() -> void:
	_clear_items()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var start: int = _room_page * ItemieryChamber.SLOT_COUNT
	var end: int = mini(start + ItemieryChamber.SLOT_COUNT, _room_items.size())
	for index: int in range(start, end):
		var item: ItemDefinition = _room_items[index]
		var button := ItemDisplayButton.new()
		button.name = String(item.id)
		button.icon = item.icon_texture
		button.accent = ItemRarity.color(item.rarity)
		button.button_group = group
		button.pressed.connect(inspect_item.bind(item))
		_shelf_ui.add_child(button)
		button.set_pressed_no_signal(item == selected_item)
		_item_buttons.append(button)
		_page_items.append(item)
	_paging.visible = _room_items.size() > ItemieryChamber.SLOT_COUNT
	page_label.text = "%d / %d" % [_room_page + 1, _page_count()]
	_layout_rarity_labels()
	_update_navigation()


func _page_count() -> int:
	return maxi(1, ceili(float(_room_items.size()) / ItemieryChamber.SLOT_COUNT))


func _change_page(direction: int) -> void:
	if transitioning or current_rarity < 0 or inspection.visible:
		return
	var next_page: int = clampi(_room_page + direction, 0, _page_count() - 1)
	if next_page == _room_page:
		return
	_room_page = next_page
	_build_items()
	_focus_shelf()


func _select_item(item: ItemDefinition) -> void:
	selected_item = item
	for index: int in range(_item_buttons.size()):
		_item_buttons[index].set_pressed_no_signal(_page_items[index] == item)
		_item_buttons[index].queue_redraw()


func inspect_item(item: ItemDefinition) -> void:
	if item == null or not is_visible_in_tree() or current_rarity < 0 or transitioning or inspection.visible:
		return
	var index: int = _page_items.find(item)
	if index < 0 or item.rarity != current_rarity:
		return
	_select_item(item)
	_inspection_origin = _item_buttons[index]
	inspection.show_item(item, catalog)
	_update_navigation()


func close_inspection() -> void:
	inspection.close()
	_update_navigation()
	if not is_visible_in_tree():
		return
	if is_instance_valid(_inspection_origin) and _inspection_origin.is_inside_tree():
		_inspection_origin.grab_focus()
	elif current_rarity >= 0:
		_focus_shelf()
	else:
		door_buttons[_last_door].grab_focus()


func _focus_shelf() -> void:
	var selected_index: int = _page_items.find(selected_item)
	if selected_index >= 0:
		_item_buttons[selected_index].grab_focus()
	elif not _item_buttons.is_empty():
		_item_buttons[0].grab_focus()
	elif _paging.visible and not page_next_button.disabled:
		page_next_button.grab_focus()
	else:
		back_button.grab_focus()


func open() -> void:
	inspection.close()
	_return_to_hall()
	show()
	_sync_visibility()
	door_buttons[_last_door].grab_focus()


func prepare_to_leave() -> void:
	set_process_input(false)
	set_process_unhandled_key_input(false)
	inspection.close()
	_return_to_hall()
	_lights.call(&"set_active", false)
	_lights.hide()
	_chamber.set_active(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_visibility() -> void:
	if inspection == null:
		return
	if not is_visible_in_tree():
		prepare_to_leave()
		return
	set_process_input(true)
	_update_navigation()
	_sync_effects()


func _sync_effects() -> void:
	var active: bool = is_visible_in_tree()
	var hall_active: bool = active and current_rarity < 0
	_lights.visible = hall_active
	_lights.call(&"set_active", hall_active)
	_chamber.set_active(active and current_rarity >= 0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _request_back() -> void:
	if inspection.visible:
		inspection.dismiss()
	elif transitioning or current_rarity >= 0:
		leave_room()
	else:
		prepare_to_leave()
		back_requested.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		MenuAudio.activate(inspection.back_button if inspection.visible else back_button)
		return
	if not transitioning:
		return
	# Keep only the native close target live while the camera owns navigation.
	if event is InputEventMouseButton and back_button.get_global_rect().has_point(event.position):
		return
	if event is InputEventScreenTouch and back_button.get_global_rect().has_point(event.position):
		return
	if event is InputEventKey and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE) and back_button.has_focus():
		return
	get_viewport().set_input_as_handled()


func _update_navigation() -> void:
	var available: bool = is_visible_in_tree() and (inspection == null or not inspection.visible)
	back_button.disabled = not available
	back_button.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	var hall_enabled: bool = available and current_rarity < 0 and not transitioning
	for button: Button in door_buttons:
		button.disabled = not hall_enabled
		button.focus_mode = Control.FOCUS_ALL if hall_enabled else Control.FOCUS_NONE
	var shelf_enabled: bool = available and current_rarity >= 0 and not transitioning
	for button: ItemDisplayButton in _item_buttons:
		button.disabled = not shelf_enabled
		button.focus_mode = Control.FOCUS_ALL if shelf_enabled else Control.FOCUS_NONE
	page_previous_button.disabled = not shelf_enabled or _room_page == 0
	page_next_button.disabled = not shelf_enabled or _room_page + 1 >= _page_count()
	page_previous_button.focus_mode = Control.FOCUS_NONE if page_previous_button.disabled else Control.FOCUS_ALL
	page_next_button.focus_mode = Control.FOCUS_NONE if page_next_button.disabled else Control.FOCUS_ALL
	_wire_exhibit_focus()


func _wire_exhibit_focus() -> void:
	var controls: Array[Control] = [back_button]
	if not transitioning:
		if current_rarity < 0:
			for button: Button in door_buttons:
				controls.append(button)
		else:
			for button: ItemDisplayButton in _item_buttons:
				controls.append(button)
			if _paging.visible:
				if not page_previous_button.disabled:
					controls.append(page_previous_button)
				if not page_next_button.disabled:
					controls.append(page_next_button)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_top = control.get_path_to(back_button)
		control.focus_neighbor_bottom = control.focus_next
	if current_rarity >= 0:
		for index: int in range(_item_buttons.size()):
			var button: ItemDisplayButton = _item_buttons[index]
			var above: Control = back_button if index < ItemieryChamber.SLOT_COLUMNS else _item_buttons[index - ItemieryChamber.SLOT_COLUMNS]
			var below: Control = back_button if index + ItemieryChamber.SLOT_COLUMNS >= _item_buttons.size() else _item_buttons[index + ItemieryChamber.SLOT_COLUMNS]
			button.focus_neighbor_top = button.get_path_to(above)
			button.focus_neighbor_bottom = button.get_path_to(below)


func _highlight_door(index: int) -> void:
	if current_rarity < 0 and not transitioning:
		if not door_buttons[index].has_focus():
			door_buttons[index].grab_focus()
		_hall.set_hovered_door(index)


func _restore_door_highlight() -> void:
	if current_rarity >= 0 or transitioning:
		return
	for index: int in range(door_buttons.size()):
		if door_buttons[index].is_hovered() or door_buttons[index].has_focus():
			_hall.set_hovered_door(index)
			return
	_hall.set_hovered_door(-1)


func _exit_tree() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
