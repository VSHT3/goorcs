extends SceneTree

var failures: int = 0
var main: Control
var sandbox: SandboxScreen
var capture_directory: String = ""
var save_directory: String = ""
var pointer_position: Vector2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
	if not capture_directory.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "Rendered capture directory is available")
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	save_directory = OS.get_temp_dir().path_join("gorcs_item_runtime_ui_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(save_directory)
	main = load("res://scenes/main.tscn").instantiate() as Control
	main.combat_rules = CombatRules.new()
	main.collection_store = CollectionStore.new(save_directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(save_directory.path_join("statistics.json"))
	root.add_child(main)
	await _settle()
	await _key(KEY_S)
	sandbox = main.sandbox_screen
	if not _check(sandbox != null and sandbox.visible and sandbox.controller != null, "S opens the real playable Sandbox"):
		await _finish()
		return
	var panel: ItemRuntimePanel = sandbox.item_panel
	if not capture_directory.is_empty():
		await _capture("sandbox_initial")
	_check(panel != null and panel.sandbox, "Sandbox exposes its owned-item runtime editor")
	await _click(panel.toggle_button)
	await _settle()
	await _click(panel.editor_button)
	await _settle()
	_check(panel.editing and panel.editor_checks.size() == 130, "Editor presents every catalog-owned item independently")
	_check(panel.all_button.visible and panel.none_button.visible and panel.search.visible, "The real panel exposes bulk ownership and item search")
	if not capture_directory.is_empty():
		await _capture("item_editor")
	await _click(panel.all_button)
	await _settle()
	var all_owned: Array = sandbox.controller.combat.item_runtime.owned_ids(0)
	var unique_owned: Dictionary = {}
	for id: String in all_owned:
		unique_owned[id] = true
	_check(all_owned.size() == 130 and unique_owned.size() == 130, "All 130 distinct items can be owned together through the live editor")
	_check(panel.owned_buttons.size() == 130 and panel._inventory.get_child_count() == 130, "Every owned item has a native inventory control")
	var missing_icons: Array[String] = []
	for id: String in all_owned:
		var icon_button: Button = panel.owned_buttons.get(id)
		if icon_button == null or icon_button.icon == null:
			missing_icons.append(id)
	_check(missing_icons.is_empty(), "Every simultaneously owned item retains its authored icon: %s" % str(missing_icons))
	if all_owned.size() != 130:
		await _finish()
		return
	await _click(panel.editor_button)
	await _settle()
	var items_scroll: VScrollBar = panel.scroll.get_v_scroll_bar()
	panel.scroll.scroll_vertical = roundi(items_scroll.max_value - items_scroll.page)
	await _settle()
	if not capture_directory.is_empty():
		await _capture("all_items_owned")
	_connect_path(sandbox.controller)
	_check(sandbox.controller.layout.is_ready(), "Actual combat receives a connected Sandbox route")
	_check(sandbox.controller.build(Vector2i(3, 2), &"arrow_tower"), "Actual tower build passes through combat with every item owned")
	if sandbox.controller.combat.towers[0].is_empty():
		await _finish()
		return
	var tower: Dictionary = sandbox.controller.combat.towers[0][0]
	_check(sandbox.controller.set_item_funds(100000, 100), "Playtest grants real item command currencies")
	_check(sandbox.controller.spawn(&"grunt", 1), "The ordinary Sandbox enemy enters the real item-modified battle")
	panel.refresh(sandbox.controller.state, 0, true)
	var needed_actions: Array[String] = ["witchs_folded_ladder:active", "spore_spawn_of_marko:feed", "worldroot_seed:bind", "minute_hand_cannon:active"]
	for key: String in needed_actions:
		_check(panel.action_buttons.has(key), "The in-game panel exposes the owned action " + key)
	for key: String in needed_actions:
		if not panel.action_buttons.has(key):
			await _finish()
			return
	var ladder_button: Button = panel.action_buttons["witchs_folded_ladder:active"]
	_check(not ladder_button.disabled, "A ready combat active is enabled by the host-owned action snapshot")
	await _click(ladder_button)
	panel.refresh(sandbox.controller.state, 0, true)
	var entry: Dictionary = sandbox.controller.state["items"][0]["entries"]["witchs_folded_ladder"]
	_check(float(entry["active_remaining"]) > 0.0 and float(entry["cooldown_remaining"]) > 0.0, "Native active control triggers the actual effect and its cooldown")
	_check(not entry.has("charges") and not panel._action_status["witchs_folded_ladder:active"].text.contains("-1"), "Uncharged actives show no negative placeholder count")
	var cannon_selector: OptionButton = panel.target_selectors["minute_hand_cannon:active"]
	_check(cannon_selector.item_count == 1 and int(cannon_selector.get_item_metadata(0)) == int(tower["id"]), "Target picker offers the actual friendly projectile tower")
	cannon_selector.select(0)
	panel.refresh(sandbox.controller.state, 0, true)
	var cannon_button: Button = panel.action_buttons["minute_hand_cannon:active"]
	_check(not cannon_button.disabled, "Selecting a valid tower enables the targeted ability")
	await _click(cannon_button)
	panel.refresh(sandbox.controller.state, 0, true)
	entry = sandbox.controller.state["items"][0]["entries"]["minute_hand_cannon"]
	_check(int(entry["target_id"]) == int(tower["id"]) and float(entry["active_remaining"]) > 0.0, "Native target selection activates only that tower")
	var spore_button: Button = panel.action_buttons["spore_spawn_of_marko:feed"]
	var before_shards: int = int(sandbox.controller.combat.reroll_currency[0])
	var before_charges: int = int(sandbox.controller.state["items"][0]["entries"]["spore_spawn_of_marko"]["charges"])
	_check(not spore_button.disabled, "Affordable feeding is available during combat")
	await _click(spore_button)
	panel.refresh(sandbox.controller.state, 0, true)
	entry = sandbox.controller.state["items"][0]["entries"]["spore_spawn_of_marko"]
	_check(int(entry["charges"]) == before_charges + 1 and int(sandbox.controller.combat.reroll_currency[0]) < before_shards, "Native feeding consumes Shards and adds one real infection charge")
	var bound_selector: OptionButton = panel.target_selectors["worldroot_seed:bind"]
	_check(bound_selector.item_count == 1 and int(bound_selector.get_item_metadata(0)) == int(tower["id"]), "Binding cannot target a foreign or non-attacker tower")
	bound_selector.select(0)
	panel.refresh(sandbox.controller.state, 0, true)
	var bind_button: Button = panel.action_buttons["worldroot_seed:bind"]
	_check(not bind_button.disabled, "A valid binding is enabled after selecting its tower")
	await _click(bind_button)
	panel.refresh(sandbox.controller.state, 0, true)
	entry = sandbox.controller.state["items"][0]["entries"]["worldroot_seed"]
	_check(int(entry["target_id"]) == int(tower["id"]) and int(entry["charges"]) == 0, "Native binding persists its one-use tower target")
	panel._select_item("witchs_folded_ladder")
	_check(panel._details.text.contains("Witch's Folded Ladder") and panel._details.text.contains("Unfold:"), "Selecting an owned item shows its authored details in-game")
	_check(not panel._details.text.contains("Charges:"), "Items without real charges omit the charge row in their details")
	if not capture_directory.is_empty():
		await _capture("active_items_in_combat")
	await _finish()


func _connect_path(controller: SandboxController) -> void:
	for x: int in range(1, 13):
		controller.edit_path(Vector2i(x, 4), true)


func _check(condition: bool, description: String) -> bool:
	if condition:
		return true
	push_error(description)
	failures += 1
	return false


func _settle(frames: int = 3) -> void:
	for _index: int in range(frames):
		await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw.call_deferred(false)
		await RenderingServer.frame_post_draw


func _click(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
		_check(false, "Expected an enabled visible native item control")
		return
	if sandbox != null and sandbox.item_panel.scroll.is_ancestor_of(control):
		sandbox.item_panel.scroll.ensure_control_visible(control)
		await process_frame
	var bounds: Rect2 = control.get_global_rect()
	var point: Vector2 = bounds.get_center()
	await _motion(point)
	var hovered_bounds: Rect2 = control.get_global_rect()
	if hovered_bounds != bounds:
		point = hovered_bounds.get_center()
		await _motion(point)
	_check(control.get_global_rect().has_point(pointer_position), "Native pointer remains over the hit target after layout settles")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.relative = root.get_final_transform().basis_xform(point - pointer_position)
	pointer_position = point
	Input.parse_input_event(event)
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _capture(name: String) -> void:
	await _settle()
	var image: Image = root.get_texture().get_image()
	_check(not image.is_empty() and image.save_png(capture_directory.path_join("%s.png" % name)) == OK, "The real item-runtime screen produces a reviewable capture")


func _finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await _settle()
	for file: String in DirAccess.get_files_at(save_directory):
		DirAccess.remove_absolute(save_directory.path_join(file))
	DirAccess.remove_absolute(save_directory)
	if failures == 0:
		print("PASS: all-130 Sandbox ownership, rendered inspection and live item command controls")
	quit(1 if failures > 0 else 0)
