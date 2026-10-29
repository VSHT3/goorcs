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
	main.combat_rules.roll_rules = null
	main.combat_rules.starting_coins = 41
	var starting_items: Array[PackedStringArray] = [PackedStringArray(["dabloons"]), PackedStringArray()]
	main.combat_rules.starting_items = starting_items
	main.collection_store = CollectionStore.new(save_directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(save_directory.path_join("statistics.json"))
	root.add_child(main)
	await _settle()
	await _test_normal_planning()
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
	sandbox.selected_tower_id = int(tower["id"])
	sandbox._refresh()
	await _click(cannon_selector)
	_check(cannon_selector.get_popup().visible, "Native item target picker opens its accessible popup")
	await _key(KEY_ESCAPE)
	_check(not cannon_selector.get_popup().visible and panel.expanded and sandbox.selected_tower_id == int(tower["id"]), "Escape closes the item target popup before its panel or underlying inspection")
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
	await _test_sandbox_transitions(int(tower["id"]))
	await _finish()


func _test_normal_planning() -> void:
	await _click(main.play_button)
	await _click(main.play_screen.singleplayer_button)
	var planning: MatchPlanning = main.planning
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Normal item UI completes the real commander draft")
	if not _check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Normal item UI enters an accepted MatchPlanning run"):
		return
	await _settle()
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var arrow: TowerShopButton = screen.shop_buttons[&"arrow_tower"]
	_check(arrow.cost == 41 and not arrow.disabled and arrow.tooltip_text.begins_with("41 Coins"), "Dabloons at exactly 41 Coins displays an affordable 41-Coin Arrow in the normal palette, not raw 45")
	if not capture_directory.is_empty():
		await _capture("normal_dabloons_palette_41")
	var cell: Vector2i = preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(3, 2))
	await _click(arrow)
	await _click_point(screen.world.cell_screen_position(0, cell))
	if not _check(planning.combat["towers"][0].size() == 1 and int(planning.combat["coins"][0]) == 0, "Native normal purchase spends the displayed discounted 41 Coins"):
		planning.stop_singleplayer()
		main._show_menu()
		return
	var tower_id: int = int(planning.combat["towers"][0][0]["id"])
	for command: String in ["damage", "speed", "special"]:
		var tower: Dictionary = planning.combat["towers"][0][0]
		var action: Dictionary = MatchPlanningScreen.tower_upgrade_actions(tower, planning.combat["tower_types"]["arrow_tower"])[command]
		var price: int = ceili(float(action["cost"]) * 0.9)
		planning._host_combat.coins = [price, price]
		planning._publish_snapshot()
		await _settle()
		var button: Button = screen.damage_upgrade if command == "damage" else (screen.speed_upgrade if command == "speed" else screen.special_upgrade)
		_check(not button.disabled and button.text.ends_with("\n%d" % price), "Normal %s upgrade displays and enables the authoritative discounted price" % command)
		await _click(button)
		_check(int(planning.combat["coins"][0]) == 0 and bool(planning.combat["towers"][0][0].get(command + "_upgraded", false)), "Native %s upgrade spends exactly its displayed discounted price" % command)
	var upgraded: Dictionary = planning.combat["towers"][0][0]
	var advancements: Dictionary = MatchPlanningScreen.advancement_actions(upgraded, planning.combat["tower_types"]["arrow_tower"])
	if _check(not advancements.is_empty(), "Real base and special purchases unlock the authored archer advancements"):
		var command: String = String(advancements.keys()[0])
		var price: int = ceili(float(advancements[command]["cost"]) * 0.9)
		planning._host_combat.coins = [price, price]
		planning._publish_snapshot()
		await _settle()
		var button: Button = screen.advancement_buttons[command]
		_check(not button.disabled and button.text.ends_with("\n%d" % price), "Normal advancement displays the host-discounted price after real prerequisite purchases")
		await _click(button)
		_check(int(planning.combat["coins"][0]) == 0 and String(planning.combat["towers"][0][0]["advancement"]) == command, "Native advancement charges its exact displayed price")
	var send_type: String = String(screen._selected_enemy_type)
	var send_price: int = ceili(float(planning.combat["enemy_types"][send_type]["send_cost"]) * 0.9)
	planning._host_combat.coins = [send_price, send_price]
	planning._publish_snapshot()
	await _settle()
	_check(not screen.send_button.disabled and screen.send_button.text.begins_with("Send · %d/" % send_price) and screen.send_button.tooltip_text.contains(": %d Coins;" % send_price), "Normal send caption, tooltip and affordability use the same owner-specific discounted quote")
	await _click(screen.send_button)
	_check(int(planning.combat["coins"][0]) == 0 and int(planning.combat["queued_send_orders"][1]) == 1, "Native send spends the displayed discounted price")
	var obstacle: Vector2i = planning.combat["commanders"][0]["obstacles"][0]
	var clear_price: int = ceili(float(CommanderRules.CLEAR_COST) * 0.9)
	planning._host_combat.coins = [clear_price, clear_price]
	planning._publish_snapshot()
	await _settle()
	await _click_point(screen.world.cell_screen_position(0, obstacle))
	_check(not screen.obstacle_clear_button.disabled and screen.obstacle_clear_button.text == "Clear · %d Coins" % clear_price, "Normal terrain Clear displays and enables its discounted host quote")
	await _click(screen.obstacle_clear_button)
	_check(int(planning.combat["coins"][0]) == 0 and not planning.combat["commanders"][0]["obstacles"].has(obstacle), "Native terrain Clear spends exactly the displayed quote")
	var all_ids: Array = planning._host_combat.item_runtime.definitions.keys()
	_check(planning._host_combat.set_items(0, all_ids), "Normal host accepts all 130 items together without acquisition")
	planning._host_combat.coins[0] = 100000
	planning._host_combat.reroll_currency[0] = 100
	planning._publish_snapshot()
	await _settle()
	var panel: ItemRuntimePanel = screen.item_panel
	await _click(panel.toggle_button)
	_check(panel.owned_buttons.size() == 130 and not panel.editor_button.visible, "Normal MatchPlanning renders all 130 owned items without exposing Sandbox acquisition controls")
	screen.selected_tower_id = tower_id
	screen._refresh()
	await _key(KEY_ESCAPE)
	_check(not panel.expanded and screen.selected_tower_id == tower_id and panel.toggle_button.has_focus(), "Normal Escape dismisses only the Items layer and restores toggle focus, preserving tower inspection")
	await _click(panel.toggle_button)
	screen.cancel_interaction()
	_check(not panel.expanded and screen.selected_tower_id == -1, "Normal programmatic cancellation clears both Items and the previous tower selection")
	await _click(panel.toggle_button)
	_check(not panel.action_buttons["spore_spawn_of_marko:feed"].disabled, "Normal item feeding is enabled before Ready")
	planning._host_ready[0] = true
	planning._publish_snapshot()
	await _settle()
	_check(not planning.can_manage_towers(0) and not planning.item_command(0, &"spore_spawn_of_marko", "feed"), "Accepted Ready state makes the actual host reject item commands")
	for button: Button in panel.action_buttons.values():
		_check(button.disabled, "Normal Ready disables every native item action instead of offering host-rejected commands")
	if not capture_directory.is_empty():
		await _capture("normal_all130_ready")
	await _key(KEY_ESCAPE)
	_check(not panel.expanded and not screen.pause_menu.visible, "Items remains keyboard-dismissable after Ready disables its actions")
	planning.stop_singleplayer()
	main._show_menu()
	await _settle()


func _test_sandbox_transitions(tower_id: int) -> void:
	var panel: ItemRuntimePanel = sandbox.item_panel
	sandbox.selected_tower_id = tower_id
	sandbox._refresh()
	await _click(panel.editor_button)
	_check(panel.editing and panel.search.has_focus(), "Owned-set editor moves keyboard focus into its search field")
	await _key(KEY_ESCAPE)
	_check(panel.expanded and not panel.editing and panel.editor_button.has_focus(), "Escape leaves the editor before dismissing Items and restores editor-toggle focus")
	sandbox._request_reset()
	await _settle()
	await _key(KEY_ESCAPE)
	_check(not sandbox.reset_dialog.visible and panel.expanded and sandbox.world._input_blocked and sandbox.world._world_viewport.gui_disable_input, "Canceling Sandbox reset cannot unblock the world underneath expanded Items")
	sandbox.width_input.value += 1
	await _settle()
	sandbox._request_resize()
	await _settle()
	await _key(KEY_ESCAPE)
	_check(not sandbox.resize_dialog.visible and panel.expanded and sandbox.world._input_blocked and sandbox.world._world_viewport.gui_disable_input, "Canceling Sandbox resize also preserves the expanded Items input barrier")
	await _key(KEY_ESCAPE)
	_check(not panel.expanded and sandbox.selected_tower_id == tower_id and panel.toggle_button.has_focus(), "Sandbox Escape dismisses Items without discarding the underlying tower")
	await _click(panel.toggle_button)
	sandbox._select_placement(&"arrow_tower")
	_check(not panel.expanded and sandbox.selected_tower_id == -1 and sandbox.placement_id == &"arrow_tower", "Programmatic palette selection fully cancels old tower inspection even when Items was open")
	sandbox.cancel_interaction()
	sandbox.selected_tower_id = tower_id
	sandbox._refresh()
	await _click(panel.toggle_button)
	sandbox._request_reset()
	await _settle()
	sandbox.reset_dialog.get_ok_button().pressed.emit()
	await _settle()
	_check(not panel.expanded and sandbox.selected_tower_id == -1 and sandbox.controller.state["towers"][0].is_empty(), "Confirming reset with Items open clears removed tower selection as well as the panel")
	_check(sandbox.controller.build(Vector2i(3, 2), &"arrow_tower"), "Resize transition receives a real replacement tower")
	sandbox.selected_tower_id = int(sandbox.controller.state["towers"][0][0]["id"])
	sandbox._refresh()
	await _click(panel.toggle_button)
	sandbox.width_input.value += 1
	await _settle()
	sandbox._request_resize()
	await _settle()
	sandbox.resize_dialog.get_ok_button().pressed.emit()
	await _settle()
	_check(not panel.expanded and sandbox.selected_tower_id == -1 and sandbox.controller.state["towers"][0].is_empty(), "Confirming resize with Items open clears removed tower selection and the panel")
	_check(sandbox.controller.combat.item_runtime.owned_ids(0).size() == 130, "Panel cleanup and confirmed map changes preserve all 130 owned items")
	if not capture_directory.is_empty():
		await _capture("sandbox_items_transition_cleanup")


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
	await _click_point(control.get_global_rect().get_center(), control)


func _click_point(point: Vector2, control: Control = null) -> void:
	var bounds: Rect2 = control.get_global_rect() if control != null else Rect2()
	await _motion(point)
	if control != null:
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
		print("PASS: normal discounted prices and Ready gating, all-130 ownership, native item actions and layered keyboard/modal transitions")
	quit(1 if failures > 0 else 0)
