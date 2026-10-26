extends SceneTree

var failures: int = 0
var main: Control
var guide: ItemieryScreen
var directory: String
var capture_directory: String = ""
var browsing_state: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
			if not capture_directory.is_absolute_path():
				_check(false, "Capture directory must be absolute")
				quit(1)
				return
	if not capture_directory.is_empty():
		if DirAccess.make_dir_recursive_absolute(capture_directory) != OK:
			_check(false, "Requested capture directory can be created")
			quit(1)
			return
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	directory = OS.get_temp_dir().path_join("gorcs_item_inspection_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	main = load("res://scenes/main.tscn").instantiate()
	main.combat_rules = CombatRules.new()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	root.add_child(main)
	await _settle()
	await _key(KEY_I)
	guide = main.itemiery_screen
	_check(guide != null and guide.visible and not main.menu.visible, "Native I opens the actual Itemiery")
	if guide == null:
		await _finish()
		return
	# Opening a guide performs normal lobby teardown, including statistics_id reset.
	# Observe only after entry, so read-only assertions measure browsing itself.
	browsing_state = _match_state()
	_check(not guide.catalog.items.is_empty(), "Registered content provides inspectable exhibits")
	_check(not guide.inspection.visible, "Entering Itemiery does not automatically open inspection")
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = root.size
		await _settle()
		await _check_every_exhibit(width)
	await _check_nested_preview()
	await _check_hidden_lifecycle()
	_check_read_only()
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not guide.visible, "Escape with inspection closed leaves the guide")
	_check(root.gui_get_focus_owner() == main.itemiery_button, "Leaving restores the Itemiery menu action's focus")
	_check_hidden_room()
	await _key(KEY_I)
	browsing_state = _match_state()
	_check(guide.visible and not guide.inspection.visible, "Native return does not reopen a dismissed inspection")
	await _settle()
	await _click(guide.back_button.get_global_rect().get_center())
	_check(main.menu.visible and not guide.visible, "Guide X remains independently reachable after inspection browsing")
	_check_hidden_room()
	await _finish()


func _check_every_exhibit(width: int) -> void:
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	var exhibits: Array[ItemDisplayButton] = _exhibits()
	for item: ItemDefinition in guide.catalog.items:
		var exhibit: ItemDisplayButton = _exhibit_for(item, exhibits)
		_check(exhibit != null, "Every catalog entry has a native exhibit: %s" % item.id)
		if exhibit == null:
			continue
		var exhibit_rect: Rect2 = exhibit.get_global_rect()
		_check(exhibit.is_visible_in_tree() and surface.encloses(exhibit_rect) and exhibit_rect.has_area(), "Exhibit is visible and inside the %dpx gallery: %s" % [width, item.id])
		for other: ItemDisplayButton in exhibits:
			if other != exhibit:
				_check(not exhibit_rect.intersects(other.get_global_rect()), "Separately clickable exhibits do not overlap: %s / %s" % [exhibit.name, other.name])
		await _motion(exhibit_rect.get_center())
		_check(not guide.inspection.visible, "Native hover cannot open inspection: %s" % item.id)
		exhibit.grab_focus()
		await _settle()
		_check(root.gui_get_focus_owner() == exhibit and not guide.inspection.visible, "Keyboard focus alone cannot open inspection: %s" % item.id)
		await _click(exhibit_rect.get_center())
		_check_open(item, "Pointer activation")
		await create_timer(0.3).timeout
		await _check_modal_bounds(width)
		await _capture(item, width)
		await _check_scroll_access()
		_check_read_only()
		await _key(KEY_ESCAPE)
		_check_closed_at(exhibit, "First Escape")
		await _key(KEY_ENTER)
		_check_open(item, "Native Enter on restored exhibit")
		await create_timer(0.3).timeout
		await _click(guide.inspection.back_button.get_global_rect().get_center())
		_check_closed_at(exhibit, "Inspection X")
		await _key(KEY_SPACE)
		_check_open(item, "Native Space on restored exhibit")
		await _key(KEY_ESCAPE)
		_check_closed_at(exhibit, "Space-opened inspection Escape")
		_check_read_only()


func _check_nested_preview() -> void:
	var linked_item: ItemDefinition
	for item: ItemDefinition in guide.catalog.items:
		if not item.upgrade_to.is_empty():
			linked_item = item
			break
	_check(linked_item != null, "Catalog exposes a linked upgrade for native preview navigation")
	if linked_item == null:
		return
	var exhibit: ItemDisplayButton = _exhibit_for(linked_item, _exhibits())
	if exhibit == null:
		return
	var target: ItemDefinition
	for item: ItemDefinition in guide.catalog.items:
		if item.id == linked_item.upgrade_to:
			target = item
	_check(target != null, "Linked upgrade resolves to a registered inspectable entry")
	if target == null:
		return
	await _click(exhibit.get_global_rect().get_center())
	await create_timer(0.3).timeout
	var upgrade: Button = guide.inspection.upgrade_button
	_check(upgrade.is_visible_in_tree() and not upgrade.disabled, "The linked upgrade has an accessible read-only preview action")
	await _click(upgrade.get_global_rect().get_center())
	_check_open(target, "Native linked-upgrade activation")
	_check(guide.selected_item == linked_item, "Nested preview preserves the originating gallery selection")
	_check_read_only()
	await _key(KEY_ESCAPE)
	_check_open(linked_item, "Nested Escape returns to the original inspection")
	_check(root.gui_get_focus_owner() == upgrade, "Nested Escape restores the upgrade action's focus")
	await _key(KEY_ENTER)
	_check_open(target, "Native Enter reopens the focused upgrade preview")
	await create_timer(0.3).timeout
	await _click(guide.inspection.back_button.get_global_rect().get_center())
	_check_open(linked_item, "Nested X returns to the original inspection")
	_check(root.gui_get_focus_owner() == upgrade, "Nested X restores the upgrade action's focus")
	_check_read_only()
	await _key(KEY_ESCAPE)
	_check_closed_at(exhibit, "Escape after returning from nested preview")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not guide.visible, "Second Escape leaves only after the entire inspection is closed")
	_check_hidden_room()
	await _key(KEY_I)
	browsing_state = _match_state()
	_check(guide.selected_item == linked_item and not guide.inspection.visible, "Native return retains selection without reopening the nested inspection")


func _check_hidden_lifecycle() -> void:
	if guide.catalog.items.is_empty():
		return
	var item: ItemDefinition = guide.catalog.items.back()
	var exhibit: ItemDisplayButton = _exhibit_for(item, _exhibits())
	if exhibit == null:
		return
	var existing_tweens: Array[Tween] = get_processed_tweens()
	await _click(exhibit.get_global_rect().get_center())
	_check_open(item, "Lifecycle fixture opens inspection before interruption")
	var entrance_tweens: Array[Tween] = []
	for tween: Tween in get_processed_tweens():
		if not existing_tweens.has(tween):
			entrance_tweens.append(tween)
	guide.prepare_to_leave()
	guide.hide()
	await _settle()
	_check(not guide.inspection.visible, "Hiding the guide closes inspection even during entrance")
	_check_hidden_room()
	var portrait: TextureRect = guide.inspection.portrait
	var hidden_transform: Transform2D = portrait.get_transform()
	var hidden_modulate: Color = portrait.modulate
	await create_timer(0.35).timeout
	for tween: Tween in entrance_tweens:
		_check(not tween.is_running(), "Hidden inspection stops its entrance tween")
	_check(portrait.get_transform() == hidden_transform and portrait.modulate == hidden_modulate, "Hidden portrait remains still rather than finishing an unseen entrance")
	_check_read_only()
	guide.open()
	await _settle()
	_check(guide.visible and guide.selected_item == item and not guide.inspection.visible, "Showing the same guide preserves selection without restoring the modal")
	_check(guide._lights.is_processing() and guide._viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED, "Visible return resumes only the gallery effects and viewport")
	await _click(exhibit.get_global_rect().get_center())
	_check_open(item, "Inspection can be explicitly reopened after hidden lifecycle cleanup")
	await _key(KEY_ESCAPE)
	_check_closed_at(exhibit, "Returned inspection Escape")


func _check_open(item: ItemDefinition, action: String) -> void:
	_check(guide.visible and not main.menu.visible and guide.inspection.visible and guide.inspection.shown_item == item, "%s shows the intended item without leaving Itemiery: %s" % [action, item.id])
	var focus: Control = root.gui_get_focus_owner()
	_check(focus != null and guide.inspection.is_ancestor_of(focus), "Open inspection owns keyboard focus")


func _check_closed_at(exhibit: ItemDisplayButton, action: String) -> void:
	_check(not guide.inspection.visible and guide.visible and not main.menu.visible, "%s closes inspection without leaving Itemiery" % action)
	_check(root.gui_get_focus_owner() == exhibit, "%s restores the originating exhibit's focus" % action)


func _check_modal_bounds(width: int) -> void:
	var inspector: ItemInspector = guide.inspection
	var panel: Control = _inspection_panel()
	_check(panel != null, "Detailed inspection has a bounded content panel")
	if panel == null:
		return
	var bounds: Rect2 = panel.get_global_rect()
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(surface.encloses(bounds), "Inspection panel stays in the %dpx viewport" % width)
	_check(bounds.encloses(inspector.back_button.get_global_rect()) and bounds.encloses(inspector.portrait.get_global_rect()), "Detailed portrait and X stay inside the modal")
	_check(inspector.portrait.get_global_rect().size.x > 96.0 and inspector.portrait.get_global_rect().size.y > 96.0, "Inspection gives detailed art a genuinely enlarged display area")
	var has_readable_content: bool = false
	var has_scroll_content: bool = false
	for control: Control in _controls(inspector):
		if not control.is_visible_in_tree():
			continue
		if control is Label and not control.text.is_empty():
			has_readable_content = true
			var rect: Rect2 = control.get_global_rect()
			_check(rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0, "Native inspection text does not spill horizontally")
			_check(control.get_minimum_size().y <= control.size.y + 1.0, "Wrapped inspection text is not vertically truncated")
			var scroll: ScrollContainer = _scroll_ancestor(control)
			if scroll == null:
				_check(bounds.encloses(rect), "Unscrolled inspection text stays inside the modal")
			else:
				has_scroll_content = true
				var reach: float = scroll.get_global_rect().position.y + scroll.get_v_scroll_bar().max_value
				_check(rect.end.y + float(scroll.scroll_vertical) <= reach + 2.0, "Scrolled inspection text is reachable within its content range")
	_check(has_readable_content, "Detailed inspection exposes readable native text alongside the portrait")
	_check(has_scroll_content, "Detailed inspection exposes nonempty native content in its accessible rules scroll")
	var first_focus: Control = root.gui_get_focus_owner()
	await _key(KEY_TAB)
	var next_focus: Control = root.gui_get_focus_owner()
	_check(next_focus != null and inspector.is_ancestor_of(next_focus), "Native Tab cannot escape the inspection into gallery exhibits")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == first_focus, "Inspection BackTab reverses native focus navigation")


func _check_scroll_access() -> void:
	for control: Control in _controls(guide.inspection):
		if not control is ScrollContainer or not control.is_visible_in_tree():
			continue
		var scroll := control as ScrollContainer
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		if bar.max_value <= bar.page + 1.0:
			continue
		var before: int = scroll.scroll_vertical
		await _wheel(scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
		_check(scroll.scroll_vertical > before, "Overflowing mechanics remain reachable through native wheel scrolling")
		scroll.grab_focus()
		await _key(KEY_HOME)
		before = scroll.scroll_vertical
		await _key(KEY_DOWN)
		_check(scroll.scroll_vertical > before, "Overflowing mechanics remain reachable through native keyboard scrolling")
		await _wheel(scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)


func _inspection_panel() -> Control:
	var ancestor: Node = guide.inspection.portrait.get_parent()
	while ancestor != null and ancestor != guide.inspection:
		if ancestor is PanelContainer and ancestor.is_ancestor_of(guide.inspection.back_button):
			return ancestor as Control
		ancestor = ancestor.get_parent()
	return null


func _scroll_ancestor(control: Control) -> ScrollContainer:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != guide.inspection:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null


func _controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control:
			result.append(child)
		result.append_array(_controls(child))
	return result


func _exhibits() -> Array[ItemDisplayButton]:
	var result: Array[ItemDisplayButton] = []
	for control: Control in _controls(guide):
		if control is ItemDisplayButton:
			result.append(control)
	return result


func _exhibit_for(item: ItemDefinition, exhibits: Array[ItemDisplayButton]) -> ItemDisplayButton:
	for exhibit: ItemDisplayButton in exhibits:
		if String(exhibit.name) == String(item.id):
			return exhibit
	return null


func _match_state() -> Dictionary:
	return {
		"combat": main.planning.combat.duplicate(true),
		"active": main.planning.active,
		"selecting_loadout": main.planning.selecting_loadout,
		"session": main.session.state,
		"collection": FileAccess.get_file_as_bytes(directory.path_join("collection.json")),
	}


func _check_read_only() -> void:
	_check(_match_state() == browsing_state, "Inspection, scrolling, and upgrade previews leave match state, currency, session, and collection unchanged")


func _check_hidden_room() -> void:
	_check(not guide._lights.is_processing() and guide._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden Itemiery stops animation and viewport rendering")


func _capture(item: ItemDefinition, width: int) -> void:
	if capture_directory.is_empty():
		return
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(not image.is_empty(), "Explicit rendered review produces viewport pixels")
	var path: String = capture_directory.path_join("itemiery_%s_%dx720.png" % [item.id, width])
	_check(image.save_png(path) == OK, "Requested item inspection capture is saved: %s" % path)


func _settle() -> void:
	await process_frame
	await process_frame


func _click(point: Vector2) -> void:
	await _motion(point)
	await _button(point, MOUSE_BUTTON_LEFT, true)
	await _button(point, MOUSE_BUTTON_LEFT, false)


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	await process_frame


func _wheel(point: Vector2, button: MouseButton) -> void:
	await _motion(point)
	await _button(point, button, true)
	await _button(point, button, false)


func _button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _finish() -> void:
	main.queue_free()
	await create_timer(0.2).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: actual-main-scene Itemiery pointer/Enter/Space inspection, nested preview and Escape/X focus restoration, hidden lifecycle, all-entry compact/wide reachability and read-only match state")
	quit(1 if failures else 0)
