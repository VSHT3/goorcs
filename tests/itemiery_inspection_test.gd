extends SceneTree

var failures: int = 0
var main: Control
var guide: ItemieryScreen
var directory: String
var capture_directory: String = ""
var browsing_state: Dictionary = {}
var trace_item: String = "<none>"
var trace_phase: String = "setup"
var pointer_position: Vector2


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> bool:
	if condition:
		return true
	push_error("%s\nItemiery trace: %s" % [description, _failure_context()])
	failures += 1
	return false


func _failure_context() -> String:
	var focus: Control = root.gui_get_focus_owner()
	var focus_path: String = str(focus.get_path()) if is_instance_valid(focus) else "<none>"
	var context: String = "phase=%s item=%s width=%d focus=%s pointer=%s" % [trace_phase, trace_item, root.size.x, focus_path, pointer_position]
	if not is_instance_valid(guide):
		return context + " guide=<unavailable>"
	context += " room=%d transitioning=%s guide_visible=%s" % [guide.current_rarity, guide.transitioning, guide.is_visible_in_tree()]
	var inspector: ItemInspector = guide.inspection
	if not is_instance_valid(inspector):
		return context + " modal=<unavailable>"
	var shown: String = String(inspector.shown_item.id) if is_instance_valid(inspector.shown_item) else "<none>"
	var entrance: Tween = inspector.get("_entrance")
	context += " modal_visible=%s shown=%s layout_pending=%s entrance_running=%s" % [inspector.is_visible_in_tree(), shown, inspector.get("_layout_pending"), entrance != null and entrance.is_running()]
	if is_instance_valid(inspector.back_button):
		context += " modal_x=%s" % inspector.back_button.get_global_rect()
	return context


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
	await _trace()
	await _finish()


func _trace() -> void:
	await _key(KEY_I)
	guide = main.itemiery_screen
	if not _check(guide != null and guide.visible and not main.menu.visible, "Native I opens the actual Itemiery"):
		return
	# Entry performs normal lobby teardown; observe browsing after that boundary.
	browsing_state = _match_state()
	if not _check(not guide.catalog.items.is_empty(), "Registered content provides shelf items"):
		return
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = root.size
		await _settle()
		if not _check_hall() or not await _check_hall_focus():
			return
		if not await _capture("hall", width) or not await _check_transition_cancellation():
			return
		for tier: int in range(ItemRarity.NAMES.size()):
			if not await _enter(tier, width, true):
				return
			if not await _capture("room_%s" % ItemRarity.NAMES[tier].to_lower(), width):
				return
			if not await _check_every_exhibit(width, tier):
				return
			if tier % 2 == 0:
				await _key(KEY_ESCAPE)
			elif not await _click(guide.back_button):
				return
			if not _check_hall(tier):
				return
	if not await _check_nested_preview() or not await _check_hidden_lifecycle():
		return
	if not await _check_synthetic_rooms() or not _check_read_only():
		return
	trace_phase = "leave hall"
	await _key(KEY_ESCAPE)
	if not _check(main.menu.visible and not guide.visible, "Hall Escape leaves the guide"):
		return
	if not _check(root.gui_get_focus_owner() == main.itemiery_button, "Leaving restores the Itemiery menu action's focus"):
		return
	if not _check_hidden_room():
		return
	await _key(KEY_I)
	browsing_state = _match_state()
	if not _check_hall() or not await _click(guide.back_button):
		return
	if not _check(main.menu.visible and not guide.visible, "Hall X returns to the main menu"):
		return
	_check_hidden_room()


func _check_every_exhibit(width: int, tier: int) -> bool:
	trace_phase = "room exhibits"
	var expected: Array[ItemDefinition] = _rarity_items(tier)
	var exhibits: Array[ItemDisplayButton] = _exhibits()
	if not _check(exhibits.size() == mini(expected.size(), ItemieryChamber.slot_count(tier)), "The room exposes only occupied shelf slots for its rarity"):
		return false
	if not _check(not guide.page_previous_button.is_visible_in_tree() and not guide.page_next_button.is_visible_in_tree(), "A single shelf page has no paging controls"):
		return false
	if not await _check_shelf_bounds():
		return false
	if tier == ItemRarity.Tier.COMMON and not await _check_stationary_shelf_focus(exhibits):
		return false
	for item: ItemDefinition in expected:
		trace_item = String(item.id)
		var exhibit: ItemDisplayButton = _exhibit_for(item, exhibits)
		if not _check(exhibit != null, "Matching-rarity catalog entry has a reachable shelf item: %s" % item.id):
			return false
		# A fresh hover is an actual exit/reentry, not a stationary motion event.
		if not await _hover(exhibit):
			return false
		if not _check(not guide.inspection.visible, "Native hover cannot open inspection: %s" % item.id):
			return false
		if not _check(root.gui_get_focus_owner() == exhibit, "Hover focuses the native shelf item without opening it"):
			return false
		if not await _click(exhibit) or not _check_open(item, "Pointer activation"):
			return false
		if not await _wait_inspection() or not await _check_modal_bounds(width):
			return false
		if not await _capture(String(item.id), width) or not await _check_scroll_access():
			return false
		if not _check_read_only():
			return false
		await _key(KEY_ESCAPE)
		if not _check_closed_at(exhibit, "First Escape"):
			return false
		if not _check(guide.current_rarity == tier, "Dismissing inspection preserves its shelf room"):
			return false
		await _key(KEY_ENTER)
		if not _check_open(item, "Native Enter on restored shelf item"):
			return false
		# Resolve X only after the reopened view's real layout and entrance settle.
		if not await _click(guide.inspection.back_button):
			return false
		if not _check_closed_at(exhibit, "Inspection X"):
			return false
		await _key(KEY_SPACE)
		if not _check_open(item, "Native Space on restored shelf item"):
			return false
		await _key(KEY_ESCAPE)
		if not _check_closed_at(exhibit, "Space-opened inspection Escape") or not _check_read_only():
			return false
	trace_item = "<none>"
	return true


func _check_stationary_shelf_focus(exhibits: Array[ItemDisplayButton]) -> bool:
	trace_phase = "stationary shelf focus"
	if not _check(exhibits.size() == 20, "Stationary modal transition regression uses twenty populated native shelf bays"):
		return false
	var origin: ItemDisplayButton = exhibits[0]
	var hovered: ItemDisplayButton = exhibits[1]
	var another: ItemDisplayButton = exhibits[2]
	var item: ItemDefinition = _item_for_id(StringName(origin.name))
	trace_item = String(origin.name)
	for activation: Key in [KEY_ENTER, KEY_SPACE]:
		for use_x: bool in [false, true]:
			if not await _hover(hovered):
				return false
			if not _check(root.gui_get_focus_owner() == hovered, "Genuine pointer entry focuses a different shelf bay"):
				return false
			await _key(KEY_LEFT)
			if not _check(root.gui_get_focus_owner() == origin, "Keyboard navigation leaves the pointer over a different populated bay"):
				return false
			var parked_pointer: Vector2 = pointer_position
			await _key(activation)
			if not _check_open(item, "Keyboard activation with the pointer parked on another shelf item"):
				return false
			if use_x:
				if not await _click(guide.inspection.back_button):
					return false
			else:
				await _key(KEY_ESCAPE)
				if not _check(pointer_position == parked_pointer, "Escape dismisses inspection without moving the parked pointer"):
					return false
			if not _check_closed_at(origin, "Stationary shelf transition"):
				return false
			await _motion(pointer_position)
			if not _check_closed_at(origin, "Zero-motion event after shelf focus restoration"):
				return false
			if not use_x:
				await _motion(pointer_position + Vector2(1, 0))
				if not _check_closed_at(origin, "Motion within the already-hovered bay preserves keyboard focus"):
					return false
			await _motion(another.get_global_rect().get_center())
			if not _check(root.gui_get_focus_owner() == another and not guide.inspection.visible, "Genuine entry after modal close still focuses another exhibit without opening it"):
				return false
	trace_phase = "room exhibits"
	trace_item = "<none>"
	return _check_read_only()


func _check_nested_preview() -> bool:
	trace_phase = "nested preview"
	var linked_item: ItemDefinition
	for item: ItemDefinition in guide.catalog.items:
		if not item.upgrade_to.is_empty():
			linked_item = item
			break
	if not _check(linked_item != null, "Catalog exposes a linked upgrade for native preview navigation"):
		return false
	trace_item = String(linked_item.id)
	if not await _enter(linked_item.rarity):
		return false
	trace_phase = "nested preview"
	var exhibit: ItemDisplayButton = _exhibit_for(linked_item, _exhibits())
	if not _check(exhibit != null, "Linked preview starts from its real rarity shelf"):
		return false
	var target: ItemDefinition = _item_for_id(linked_item.upgrade_to)
	if not _check(target != null, "Linked upgrade resolves to a registered inspectable entry"):
		return false
	if not await _click(exhibit) or not await _wait_inspection():
		return false
	var upgrade: Button = guide.inspection.upgrade_button
	if not _check(upgrade.is_visible_in_tree() and not upgrade.disabled, "Linked upgrade has an accessible read-only preview action"):
		return false
	if not await _click(upgrade) or not _check_open(target, "Native linked-upgrade activation"):
		return false
	if not _check(guide.selected_item == linked_item and guide.current_rarity == linked_item.rarity, "Cross-rarity nested preview preserves its originating selection and room"):
		return false
	if not _check_read_only():
		return false
	await _key(KEY_ESCAPE)
	if not _check_open(linked_item, "Nested Escape returns to the original inspection"):
		return false
	if not _check(root.gui_get_focus_owner() == upgrade, "Nested Escape restores upgrade focus"):
		return false
	await _key(KEY_ENTER)
	if not _check_open(target, "Native Enter reopens the focused upgrade preview"):
		return false
	if not await _click(guide.inspection.back_button):
		return false
	if not _check_open(linked_item, "Nested X returns to the original inspection"):
		return false
	if not _check(root.gui_get_focus_owner() == upgrade, "Nested X restores upgrade focus"):
		return false
	# A zero-motion event under the still-present pointer must not steal restored
	# keyboard focus; only a genuine exit/reentry should perform hover routing.
	if not await _wait_inspection():
		return false
	await _motion(pointer_position)
	if not _check(root.gui_get_focus_owner() == upgrade, "Stationary pointer preserves nested focus restoration"):
		return false
	if not _check(guide.current_rarity == linked_item.rarity, "Nested X never follows the preview into a different room") or not _check_read_only():
		return false
	await _key(KEY_ESCAPE)
	if not _check_closed_at(exhibit, "Escape after nested preview"):
		return false
	await _key(KEY_ESCAPE)
	if not _check_hall(linked_item.rarity):
		return false
	await _key(KEY_ESCAPE)
	if not _check(main.menu.visible and not guide.visible, "Only hall Escape leaves after both inspection and room are closed") or not _check_hidden_room():
		return false
	await _key(KEY_I)
	browsing_state = _match_state()
	if not _check_hall():
		return false
	trace_item = "<none>"
	return _check(guide.selected_item == linked_item, "Return retains selection metadata without reopening its room or inspection")


func _check_hidden_lifecycle() -> bool:
	trace_phase = "hidden lifecycle"
	var tier: int = guide.catalog.items.back().rarity
	# Interrupt both entry phases using the real visibility lifecycle.
	for push: bool in [false, true]:
		if not await _click(guide.door_buttons[tier]):
			return false
		if push:
			if not await _wait_until(func() -> bool: return guide.transitioning and _camera_forward_visible() and guide._shade.modulate.a > 0.05, "Entry reaches its shaded forward phase before hiding"):
				return false
		elif not await _wait_until(func() -> bool: return guide.transitioning and _door_opening(tier) > 0.02, "Entry reaches its opening phase before hiding"):
			return false
		var transition: Tween = guide.get("_transition")
		guide.hide()
		await _settle()
		if not _check_hidden_room():
			return false
		if not _check(not transition.is_running(), "Hiding entry kills its active transition rather than finishing invisibly"):
			return false
		guide.open()
		await _settle()
		if not _check_hall():
			return false
		if not _check(guide.modulate.a > 0.99 and guide._viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED, "Reopening resets opacity and resumes the visible viewport"):
			return false
	# Interrupt an inspector entrance inside an active chamber as well.
	if not await _enter(tier):
		return false
	trace_phase = "hidden inspection entrance"
	var item: ItemDefinition = _rarity_items(tier).back()
	trace_item = String(item.id)
	var exhibit: ItemDisplayButton = _exhibit_for(item, _exhibits())
	if not _check(exhibit != null, "Lifecycle fixture has an occupied shelf target"):
		return false
	var existing_tweens: Array[Tween] = get_processed_tweens()
	if not await _click(exhibit) or not _check_open(item, "Lifecycle fixture opens inspection before interruption"):
		return false
	var entrance_tweens: Array[Tween] = []
	for tween: Tween in get_processed_tweens():
		if not existing_tweens.has(tween):
			entrance_tweens.append(tween)
	guide.prepare_to_leave()
	guide.hide()
	await _settle()
	if not _check_hidden_room():
		return false
	for tween: Tween in entrance_tweens:
		if not _check(not tween.is_running(), "Hidden inspection and room stop all their active tweens"):
			return false
	if not _check_read_only():
		return false
	guide.open()
	await _settle()
	if not _check_hall():
		return false
	if not _check(guide.selected_item == item, "Hidden modal cleanup retains only selection metadata"):
		return false
	if not await _enter(tier):
		return false
	exhibit = _exhibit_for(item, _exhibits())
	if not _check(exhibit != null, "Lifecycle reset rebuilds the originating shelf target"):
		return false
	if not await _click(exhibit) or not _check_open(item, "Inspection remains explicitly reachable after lifecycle reset"):
		return false
	await _key(KEY_ESCAPE)
	if not _check_closed_at(exhibit, "Returned inspection Escape"):
		return false
	await _key(KEY_ESCAPE)
	trace_item = "<none>"
	return _check_hall(tier)


func _enter(tier: int, width: int = 0, capture_transition: bool = false) -> bool:
	trace_phase = "enter %s" % ItemRarity.NAMES[tier]
	if not _check_hall():
		return false
	var door: Button = guide.door_buttons[tier]
	if not await _hover(door):
		return false
	if not _check(root.gui_get_focus_owner() == door and not guide.transitioning, "Door hover focuses without entering"):
		return false
	if tier % 3 == 0:
		if not await _click(door):
			return false
	else:
		await _key(KEY_ENTER if tier % 3 == 1 else KEY_SPACE)
	if not _check(guide.transitioning and guide.current_rarity == -1, "Native door activation starts entry while still in the hall"):
		return false
	if not await _wait_until(func() -> bool: return guide.transitioning and _door_opening(tier) > 0.2 and _door_opening(tier) < 0.95, "Door leaves visibly open before entry completes"):
		return false
	if not _check(not _camera_pushed(), "Door opening precedes the forward camera push"):
		return false
	if capture_transition and not await _capture("opening_%s" % ItemRarity.NAMES[tier].to_lower(), width):
		return false
	if not await _wait_until(func() -> bool: return guide.transitioning and _camera_forward_visible(), "Entry performs an actual forward camera push"):
		return false
	if not _check(_door_opening(tier) > 0.95, "Camera enters through a fully opened doorway"):
		return false
	if capture_transition and not await _capture("forward_%s" % ItemRarity.NAMES[tier].to_lower(), width):
		return false
	if not await _wait_until(func() -> bool: return not guide.transitioning, "Door entry completes within its bounded timeout"):
		return false
	if not _check(guide.current_rarity == tier and not guide.inspection.visible, "Entry selects the requested room without opening an item"):
		return false
	if not _check(not _camera_pushed(), "Room switch restores the logical camera"):
		return false
	for button: Button in guide.door_buttons:
		if not _check(not button.is_visible_in_tree(), "Hall doors are not interactive on top of room shelves"):
			return false
	return _check_read_only()


func _check_transition_cancellation() -> bool:
	trace_phase = "transition cancellation"
	var tier: int = ItemRarity.Tier.COMMON
	for push: bool in [false, true]:
		for use_x: bool in [false, true]:
			if not await _click(guide.door_buttons[tier]):
				return false
			if not _check(guide.transitioning, "Cancellation fixture starts a real entry"):
				return false
			var transition: Tween = guide.get("_transition")
			if push:
				if not await _wait_until(func() -> bool: return guide.transitioning and _camera_forward_visible(), "Cancellation reaches the forward phase"):
					return false
			else:
				if not await _wait_until(func() -> bool: return guide.transitioning and _door_opening(tier) > 0.02, "Cancellation reaches the opening phase"):
					return false
				if not _check(not _camera_pushed(), "Opening cancellation happens before the camera advances"):
					return false
			if use_x:
				if not await _click(guide.back_button):
					return false
			else:
				await _key(KEY_ESCAPE)
			if not _check_hall(tier):
				return false
			if not _check(not transition.is_running(), "Escape/X kills the cancelled tween") or not _check_read_only():
				return false
	# Cache actual presented hall hitpoints before entry disables/hides doors.
	# The following ignored clicks intentionally target those same screen points,
	# not a newly reachable control or an estimated in-flight camera position.
	if not await _wait_control(guide.door_buttons[tier]) or not await _wait_control(guide.door_buttons[ItemRarity.Tier.ORCFECCION]):
		return false
	var same_door_point: Vector2 = guide.door_buttons[tier].get_global_rect().get_center()
	var other_door_point: Vector2 = guide.door_buttons[ItemRarity.Tier.ORCFECCION].get_global_rect().get_center()
	if not await _click(guide.door_buttons[tier]):
		return false
	var transition: Tween = guide.get("_transition")
	await _click_at(same_door_point)
	await _click_at(other_door_point)
	if not _check(guide.transitioning and guide.get("_transition") == transition and guide.current_rarity == -1, "Repeated same/other door clicks cannot restart or retarget an active transition"):
		return false
	if not await _wait_until(func() -> bool: return not guide.transitioning, "Locked entry finishes normally"):
		return false
	if not _check(guide.current_rarity == tier, "Ignored other-door input cannot change the eventual room"):
		return false
	await _key(KEY_ESCAPE)
	return _check_hall(tier)


func _check_hall(expected_focus: int = -1) -> bool:
	if not _check(guide.visible and guide.current_rarity == -1 and not guide.transitioning and not guide.inspection.visible, "Hall is closed, stable, and has no modal"):
		return false
	if not _check(guide._viewport.get_node_or_null("EntryCamera") is Camera2D, "Entry uses a real viewport camera"):
		return false
	if not _check(guide.door_buttons.size() == ItemRarity.NAMES.size(), "Every rarity has one native hall door"):
		return false
	if not _check(_exhibits().is_empty(), "No hall item exhibit is visible or inspectable"):
		return false
	if not _check(not _camera_pushed(), "Hall camera is reset after return/cancel"):
		return false
	if not _check(guide._shade.modulate.a < 0.01 and guide.get("_hall_ui").modulate == Color.WHITE, "Hall restores its shade and native-label opacity"):
		return false
	for control: Control in _controls(guide):
		if control is ItemDisplayButton:
			if not _check(not control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_NONE, "Retired shelf controls cannot be inspected or focused from the hall"):
				return false
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	for tier: int in range(guide.door_buttons.size()):
		var door: Button = guide.door_buttons[tier]
		if not _check(door.is_visible_in_tree() and not door.disabled and surface.encloses(door.get_global_rect()), "Closed hall doors remain reachable native controls"):
			return false
		if not _check(is_zero_approx(_door_opening(tier)), "Returning closes every door leaf"):
			return false
	if expected_focus >= 0:
		return _check(root.gui_get_focus_owner() == guide.door_buttons[expected_focus], "Returning/cancelling restores the originating hall door focus")
	return true


func _check_hall_focus() -> bool:
	trace_phase = "hall focus"
	if not await _hover(guide.door_buttons[0]):
		return false
	for tier: int in range(guide.door_buttons.size()):
		if not _check(root.gui_get_focus_owner() == guide.door_buttons[tier], "Native Right reaches each closed door in order"):
			return false
		if tier + 1 < guide.door_buttons.size():
			await _key(KEY_RIGHT)
	for tier: int in range(guide.door_buttons.size() - 1, -1, -1):
		if not _check(root.gui_get_focus_owner() == guide.door_buttons[tier], "Native Left reverses the door focus links"):
			return false
		if tier > 0:
			await _key(KEY_LEFT)
	for tier: int in range(guide.door_buttons.size()):
		if not _check(root.gui_get_focus_owner() == guide.door_buttons[tier], "Native Tab reaches each door without opening it"):
			return false
		await _key(KEY_TAB)
	if not _check(root.gui_get_focus_owner() == guide.back_button, "Door Tab reaches the hall X"):
		return false
	await _key(KEY_TAB)
	if not _check(root.gui_get_focus_owner() == guide.door_buttons[0], "Hall X Tab wraps to the first door"):
		return false
	await _key(KEY_TAB, true)
	return _check(root.gui_get_focus_owner() == guide.back_button and not guide.inspection.visible and not guide.transitioning, "Hall BackTab reverses focus without inspecting or entering")


func _check_synthetic_rooms() -> bool:
	trace_phase = "synthetic empty room"
	var actual: ItemieryScreen = guide
	var empty_catalog := ContentCatalog.new()
	# Leave a different rarity populated: absence must be filtering, not an
	# entirely empty catalog or a default-catalog fallback.
	var source: ItemDefinition = actual.catalog.items.front()
	var other: ItemDefinition = source.duplicate()
	other.id = &"synthetic_other_rarity"
	other.rarity = ItemRarity.Tier.ORCFECCION
	other.upgrade_to = &""
	other.upgrade_cost = 0
	empty_catalog.items.append(other)
	actual.hide()
	guide = ItemieryScreen.new()
	guide.catalog = empty_catalog
	main.add_child(guide)
	guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide.open()
	await _settle()
	if not await _enter(ItemRarity.Tier.COMMON):
		return false
	trace_phase = "synthetic empty room"
	if not _check(_exhibits().is_empty(), "A synthetic empty rarity has empty shelves, not items borrowed from another room/default catalog"):
		return false
	if not _check(not guide.page_next_button.is_visible_in_tree() and not guide.page_previous_button.is_visible_in_tree(), "Empty shelves expose no meaningless paging actions"):
		return false
	await _key(KEY_TAB)
	if not _check(not guide.inspection.visible, "An empty room has no focusable item inspection"):
		return false
	await _key(KEY_ESCAPE)
	if not _check_hall(ItemRarity.Tier.COMMON) or not await _enter(ItemRarity.Tier.ORCFECCION):
		return false
	if not _check(_exhibits().size() == 1 and _exhibit_for(other, _exhibits()) != null, "Synthetic content remains reachable in its actual rarity"):
		return false
	await _key(KEY_ESCAPE)
	guide.hide()
	guide.queue_free()
	await _settle()
	var overflow_catalog := ContentCatalog.new()
	var expected_ids: Dictionary = {}
	var capacity: int = ItemieryChamber.slot_count(ItemRarity.Tier.COMMON)
	for index: int in range(capacity + 5):
		var item: ItemDefinition = source.duplicate()
		item.id = StringName("synthetic_shelf_%02d" % index)
		item.rarity = ItemRarity.Tier.COMMON
		item.upgrade_to = &""
		item.upgrade_cost = 0
		overflow_catalog.items.append(item)
		expected_ids[item.id] = true
	overflow_catalog.items.append(other)
	guide = ItemieryScreen.new()
	guide.catalog = overflow_catalog
	main.add_child(guide)
	guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide.open()
	await _settle()
	if not await _enter(ItemRarity.Tier.COMMON):
		return false
	trace_phase = "synthetic overflow"
	var seen: Dictionary = {}
	var page_limit: int = ceili(float(expected_ids.size()) / float(capacity))
	for page: int in range(page_limit):
		var exhibits: Array[ItemDisplayButton] = _exhibits()
		if not _check(exhibits.size() == mini(capacity, expected_ids.size() - seen.size()), "Each page occupies at most the room's shelf capacity"):
			return false
		if not await _check_shelf_bounds():
			return false
		for exhibit: ItemDisplayButton in exhibits:
			var id := StringName(exhibit.name)
			trace_item = String(id)
			if not _check(expected_ids.has(id) and not seen.has(id), "Paging shows matching-rarity entries once, with no duplicates or borrowed items"):
				return false
			seen[id] = true
			if not await _click(exhibit) or not _check_open(_item_for_id(id), "Overflow shelf pointer activation"):
				return false
			await _key(KEY_ESCAPE)
			if not _check_closed_at(exhibit, "Overflow inspection Escape"):
				return false
		if not _check(guide.page_previous_button.is_visible_in_tree() and guide.page_next_button.is_visible_in_tree(), "Overflow uses reachable native page controls"):
			return false
		if not _check(guide.page_previous_button.disabled == (page == 0), "Previous-page boundary is enforced"):
			return false
		if not _check(guide.page_next_button.disabled == (page == page_limit - 1), "Next-page boundary is enforced"):
			return false
		if page + 1 < page_limit:
			if not await _click(guide.page_next_button):
				return false
			await _settle()
	if not _check(seen.size() == expected_ids.size(), "All overflow entries are inspectable without silent drops"):
		return false
	if not await _click(guide.page_previous_button):
		return false
	await _settle()
	if not _check(_exhibits().size() == capacity and _exhibit_for(overflow_catalog.items.front(), _exhibits()) != null, "Previous returns to the complete first shelf page") or not _check_read_only():
		return false
	guide.hide()
	guide.queue_free()
	await _settle()
	guide = actual
	guide.open()
	await _settle()
	trace_item = "<none>"
	return _check_hall()


func _check_shelf_bounds() -> bool:
	var exhibits: Array[ItemDisplayButton] = _exhibits()
	if not _check(exhibits.size() <= ItemieryChamber.slot_count(guide.current_rarity), "Occupied shelf controls never exceed room capacity"):
		return false
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	var art: Control = guide.get("_room")
	var art_scale: float = minf(art.size.x / 640.0, art.size.y / 360.0)
	var origin: Vector2 = art.global_position + (art.size - Vector2(640, 360) * art_scale) * 0.5
	for index: int in range(exhibits.size()):
		var exhibit: ItemDisplayButton = exhibits[index]
		var bounds: Rect2 = exhibit.get_global_rect()
		var slot: Rect2 = ItemieryChamber.slot_rect(index, guide.current_rarity)
		var native_slot := Rect2(origin + slot.position * art_scale, slot.size * art_scale).grow(2.0)
		if not _check(bounds.has_area() and surface.encloses(bounds) and native_slot.encloses(bounds), "Every item target fits a reachable physical shelf slot"):
			return false
		var item: ItemDefinition = _item_for_id(StringName(exhibit.name))
		if not _check(item != null and item.rarity == guide.current_rarity, "Only the current rarity is inspectable from shelf controls"):
			return false
		for other: ItemDisplayButton in exhibits:
			if exhibit != other:
				if not _check(not bounds.intersects(other.get_global_rect()), "Occupied shelf targets do not overlap"):
					return false
	if not exhibits.is_empty():
		if not await _hover(exhibits[0]):
			return false
		for index: int in range(exhibits.size()):
			if not _check(root.gui_get_focus_owner() == exhibits[index], "Native Tab reaches every occupied shelf slot"):
				return false
			await _key(KEY_TAB)
	return true


func _rarity_items(tier: int) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item: ItemDefinition in guide.catalog.items:
		if item.rarity == tier:
			result.append(item)
	return result


func _item_for_id(id: StringName) -> ItemDefinition:
	for item: ItemDefinition in guide.catalog.items:
		if item.id == id:
			return item
	return null


func _door_opening(tier: int) -> float:
	for child: Node in guide._viewport.get_children():
		if child is ItemieryRoom:
			return child._door_openings[tier]
	return -1.0


func _camera_pushed() -> bool:
	var camera := guide._viewport.get_node_or_null("EntryCamera") as Camera2D
	return camera != null and (not camera.position.is_equal_approx(Vector2(320, 180)) or not camera.zoom.is_equal_approx(Vector2.ONE))


func _camera_forward_visible() -> bool:
	var camera := guide._viewport.get_node_or_null("EntryCamera") as Camera2D
	return camera != null and camera.zoom.x > 1.3 and camera.position.distance_to(Vector2(320, 180)) > 8.0


func _wait_until(predicate: Callable, description: String, timeout_ms: int = 3000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return _check(predicate.call(), description)


func _wait_inspection() -> bool:
	if not await _wait_until(_inspection_settled, "Inspection layout and entrance settle before pointer input/bounds/capture"):
		return false
	return await _wait_control(guide.inspection.back_button)


func _inspection_settled() -> bool:
	var inspector: ItemInspector = guide.inspection
	var tween: Tween = inspector.get("_entrance")
	return inspector.is_visible_in_tree() and not inspector.get("_layout_pending") and (tween == null or not tween.is_running())


func _check_open(item: ItemDefinition, action: String) -> bool:
	if not _check(item != null, "%s resolves an actual catalog item" % action):
		return false
	if not _check(guide.visible and not main.menu.visible and guide.inspection.visible and guide.inspection.shown_item == item, "%s shows the intended item without leaving Itemiery: %s" % [action, item.id]):
		return false
	var focus: Control = root.gui_get_focus_owner()
	return _check(focus != null and guide.inspection.is_ancestor_of(focus), "Open inspection owns keyboard focus")


func _check_closed_at(exhibit: Variant, action: String) -> bool:
	if not _check(not guide.inspection.visible and guide.visible and not main.menu.visible, "%s closes inspection without leaving Itemiery" % action):
		return false
	if not _check(is_instance_valid(exhibit), "%s preserves the originating shelf control" % action):
		return false
	return _check(root.gui_get_focus_owner() == exhibit, "%s restores the originating exhibit's focus" % action)


func _check_modal_bounds(width: int) -> bool:
	var inspector: ItemInspector = guide.inspection
	var panel: Control = _inspection_panel()
	if not _check(panel != null, "Detailed inspection has a bounded content panel"):
		return false
	var bounds: Rect2 = panel.get_global_rect()
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	if not _check(surface.encloses(bounds), "Inspection panel stays in the %dpx viewport" % width):
		return false
	if not _check(bounds.encloses(inspector.back_button.get_global_rect()) and bounds.encloses(inspector.portrait.get_global_rect()), "Detailed portrait and X stay inside the modal"):
		return false
	if not _check(inspector.portrait.get_global_rect().size.x > 96.0 and inspector.portrait.get_global_rect().size.y > 96.0, "Inspection gives detailed art a genuinely enlarged display area"):
		return false
	var has_readable_content: bool = false
	var has_scroll_content: bool = false
	for control: Control in _controls(inspector):
		if not control.is_visible_in_tree():
			continue
		if control is Label and not control.text.is_empty():
			has_readable_content = true
			var rect: Rect2 = control.get_global_rect()
			if not _check(rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0, "Native inspection text does not spill horizontally"):
				return false
			if not _check(control.get_minimum_size().y <= control.size.y + 1.0, "Wrapped inspection text is not vertically truncated"):
				return false
			var scroll: ScrollContainer = _scroll_ancestor(control)
			if scroll == null:
				if not _check(bounds.encloses(rect), "Unscrolled inspection text stays inside the modal"):
					return false
			else:
				has_scroll_content = true
				var reach: float = scroll.get_global_rect().position.y + scroll.get_v_scroll_bar().max_value
				if not _check(rect.end.y + float(scroll.scroll_vertical) <= reach + 2.0, "Scrolled inspection text is reachable within its content range"):
					return false
	if not _check(has_readable_content, "Detailed inspection exposes readable native text alongside the portrait"):
		return false
	if not _check(has_scroll_content, "Detailed inspection exposes nonempty native content in its accessible rules scroll"):
		return false
	var first_focus: Control = root.gui_get_focus_owner()
	await _key(KEY_TAB)
	var next_focus: Control = root.gui_get_focus_owner()
	if not _check(next_focus != null and inspector.is_ancestor_of(next_focus), "Native Tab cannot escape the inspection into gallery exhibits"):
		return false
	await _key(KEY_TAB, true)
	return _check(root.gui_get_focus_owner() == first_focus, "Inspection BackTab reverses native focus navigation")


func _check_scroll_access() -> bool:
	for control: Control in _controls(guide.inspection):
		if not control is ScrollContainer or not control.is_visible_in_tree():
			continue
		var scroll := control as ScrollContainer
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		if bar.max_value <= bar.page + 1.0:
			continue
		var before: int = scroll.scroll_vertical
		if not await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN):
			return false
		if not _check(scroll.scroll_vertical > before, "Overflowing mechanics remain reachable through native wheel scrolling"):
			return false
		scroll.grab_focus()
		await _key(KEY_HOME)
		before = scroll.scroll_vertical
		await _key(KEY_DOWN)
		if not _check(scroll.scroll_vertical > before, "Overflowing mechanics remain reachable through native keyboard scrolling"):
			return false
		if not await _wheel(scroll, MOUSE_BUTTON_WHEEL_UP):
			return false
	return true


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
		if control is ItemDisplayButton and control.is_visible_in_tree():
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
		"session_error": main.session.error_message,
		"peer": main.session.get("_peer"),
		"statistics_exists": FileAccess.file_exists(directory.path_join("statistics.json")),
		"statistics": FileAccess.get_file_as_bytes(directory.path_join("statistics.json")) if FileAccess.file_exists(directory.path_join("statistics.json")) else PackedByteArray(),
		"collection": FileAccess.get_file_as_bytes(directory.path_join("collection.json")),
	}


func _check_read_only() -> bool:
	return _check(_match_state() == browsing_state, "Inspection, scrolling, and upgrade previews leave match state, currency, session, and collection unchanged")


func _check_hidden_room() -> bool:
	if not _check(not guide._lights.is_processing() and guide._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden Itemiery stops animation and viewport rendering"):
		return false
	if not _check(not guide.transitioning and guide.current_rarity == -1 and not guide.inspection.visible, "Hiding resets navigation to the hall and closes inspection"):
		return false
	if not _check(not _camera_pushed(), "Hidden entry camera cannot remain pushed forward"):
		return false
	if not _check(guide._shade.modulate.a < 0.01 and not guide._chamber.visible, "Hidden cleanup clears the shade and deactivates the chamber"):
		return false
	for tier: int in range(ItemRarity.NAMES.size()):
		if not _check(is_zero_approx(_door_opening(tier)), "Hidden cleanup closes every hall door"):
			return false
	return _check_stopped_effects(guide._viewport)


func _check_stopped_effects(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Node2D:
			if not _check(not child.is_processing(), "Hidden hall/chamber visual processing is stopped: %s" % child.name):
				return false
		if not _check_stopped_effects(child):
			return false
	return true


func _capture(surface: String, width: int) -> bool:
	if capture_directory.is_empty():
		return true
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _check(not image.is_empty(), "Explicit rendered review produces viewport pixels"):
		return false
	var path: String = capture_directory.path_join("itemiery_%s_%dx720.png" % [surface, width])
	return _check(image.save_png(path) == OK, "Requested real Itemiery surface is saved: %s" % path)


func _settle() -> void:
	await process_frame
	await process_frame


func _wait_control(control: Control) -> bool:
	if not _check(is_instance_valid(control), "Pointer target exists before resolving its geometry"):
		return false
	var target_path: String = str(control.get_path())
	var deadline: int = Time.get_ticks_msec() + 3000
	var previous: Array[Rect2] = []
	while Time.get_ticks_msec() < deadline:
		await _presented_frame()
		if not _check(is_instance_valid(control), "Pointer target survives presentation: %s" % target_path):
			return false
		if not _control_ready(control):
			previous.clear()
			continue
		var geometry: Array[Rect2] = [control.get_global_rect()]
		if guide.inspection.is_ancestor_of(control):
			var panel: Control = _inspection_panel()
			if not _check(panel != null, "Visible inspection owns its pointer target"):
				return false
			geometry.append(panel.get_global_rect())
			geometry.append(guide.inspection.back_button.get_global_rect())
		# Compare actual bounds on consecutive presented frames, after container
		# sorts/deferred layout and entrance complete; never predict their size.
		if geometry == previous:
			return true
		previous = geometry
	return _check(false, "Pointer target reaches stable presented geometry: %s" % target_path)


func _control_ready(control: Control) -> bool:
	if not control.is_visible_in_tree() or not control.get_global_rect().has_area():
		return false
	if control is BaseButton and control.disabled:
		return false
	if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect()):
		return false
	return not guide.inspection.is_ancestor_of(control) or _inspection_settled()


func _presented_frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw.call_deferred(false)
		await RenderingServer.frame_post_draw


func _hover(control: Control) -> bool:
	if not await _wait_control(guide.back_button) or not await _wait_control(control):
		return false
	await _motion(guide.back_button.get_global_rect().get_center())
	await _motion(control.get_global_rect().get_center())
	return true


func _click(control: Control) -> bool:
	if not await _wait_control(control):
		return false
	var bounds: Rect2 = control.get_global_rect()
	var point: Vector2 = bounds.get_center()
	await _motion(point)
	if not _check(is_instance_valid(control) and _control_ready(control) and control.get_global_rect() == bounds, "Presented pointer target stays stable through native hover"):
		return false
	await _button(point, MOUSE_BUTTON_LEFT, true)
	await _button(point, MOUSE_BUTTON_LEFT, false)
	return true


func _click_at(point: Vector2) -> void:
	await _motion(point)
	await _button(point, MOUSE_BUTTON_LEFT, true)
	await _button(point, MOUSE_BUTTON_LEFT, false)


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.relative = root.get_final_transform().basis_xform(point - pointer_position)
	pointer_position = point
	Input.parse_input_event(event)
	await process_frame


func _wheel(control: Control, button: MouseButton) -> bool:
	if not await _wait_control(control):
		return false
	var point: Vector2 = control.get_global_rect().get_center()
	await _motion(point)
	await _button(point, button, true)
	await _button(point, button, false)
	return true


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
	# Match the game's quit boundary: finish the final clack before driver teardown.
	var tail: float = MenuAudio.CLACK.get_length() + AudioServer.get_output_latency() + AudioServer.get_time_to_next_mix()
	await create_timer(tail, true, false, true).timeout
	main.queue_free()
	await _settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: native seven-door opening/push, cancellation and hide reset; rarity shelf/empty/overflow reachability; inspection/nested focus; compact/wide bounds and read-only gameplay")
	quit(1 if failures else 0)
