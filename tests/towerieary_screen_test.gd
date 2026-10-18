extends SceneTree

var failures: int = 0
var viewport: Window
var screen: ToweriearyScreen
var rules: CombatRules = preload("res://resources/combat/prototype.tres")
var expected := TowerGuide.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	expected.configure(rules.catalog, rules)
	viewport = root
	viewport.gui_embed_subwindows = true
	viewport.size = Vector2i(1000, 720)
	viewport.content_scale_size = viewport.size
	screen = load("res://scenes/towerieary_screen.tscn").instantiate() as ToweriearyScreen
	screen.configure(rules.catalog, rules)
	viewport.add_child(screen)
	await _settle()
	screen.open()
	await _settle()
	_check(screen.tower_buttons.size() == rules.catalog.towers.size() and screen.tower_buttons.size() == 6, "All six catalog identities are discoverable without an ownership store")
	_check(viewport.gui_get_focus_owner() == screen.tower_buttons[0], "Open focuses the selected tower index")
	await _check_input()
	for width: int in [1000, 1280]:
		viewport.size = Vector2i(width, 720)
		viewport.content_scale_size = viewport.size
		await _settle()
		await _check_catalog()
		_check(screen.details_scroll.get_h_scroll_bar().max_value <= screen.details_scroll.size.x + 1.0, "Details do not need horizontal scrolling at either supported width")
		_check(screen.portrait.size.x <= 184.0 and screen.portrait.size.y <= 206.0, "The battlefield portrait stays inside its compact guide area")
	await _check_reopen_and_back()
	await _check_injected_catalog()
	screen.configure(ContentCatalog.new(), rules)
	screen.open()
	await _settle()
	_check(screen.tower_buttons.is_empty() and screen.selected_preview.is_empty() and screen.error_label.visible, "An empty catalog gives a real empty state, never fabricated tower values")
	_check(screen.stage_graph.stage_buttons.is_empty(), "An empty guide never offers fabricated stage choices")
	_check(viewport.gui_get_focus_owner() == screen.back_button, "Empty guide still exposes normal keyboard Back")
	screen.configure(null, rules)
	await _settle()
	_check(screen.error_label.visible and not screen.provider.error_message.is_empty(), "Invalid configuration exposes its provider error without an engine error")
	screen.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: native Towerieary graph pointer/arrows and every catalog branch stats/roles/art/costs, focus cycle and graph geometry, reopen/X/Escape, injected and empty catalogs; no pixel proof")
	quit(1 if failures > 0 else 0)


func _check_input() -> void:
	await _key(KEY_DOWN)
	_check(screen.selected_index == 1 and viewport.gui_get_focus_owner() == screen.tower_buttons[1], "Down synchronizes selection and actual focus")
	await _key(KEY_UP)
	_check(screen.selected_index == 0, "Up returns to the previous tower")
	await _key(KEY_UP)
	_check(screen.selected_index == screen.entries.size() - 1, "Tower index arrows wrap")
	await _key(KEY_RIGHT)
	_check(viewport.gui_get_focus_owner() == screen.stage_graph.stage_buttons[screen.selected_stage_id], "Right enters the selected native upgrade node")
	screen.select_stage("base")
	await _settle()
	_check(screen.stage_graph.selected_stage_id == "base" and screen.stage_graph.stage_buttons["base"].button_pressed, "Public stage selection synchronizes the visible graph node")
	screen.select_stage("damage")
	await _settle()
	_check_graph_preview("damage", "Public non-base selection synchronizes the visible node and actual preview", false)
	await _choose_stage("base")
	await _key(KEY_DOWN)
	_check_graph_preview("damage", "Native Down follows the first actual purchase branch")
	await _key(KEY_RIGHT)
	_check_graph_preview("speed", "Native Right moves to the other stat-upgrade sibling")
	await _key(KEY_DOWN)
	_check_graph_preview("damage/speed", "Native Down from speed reaches the combined upgrade state")
	await _key(KEY_UP)
	_check_graph_preview("damage", "Native Up returns to the first real parent of the combined upgrade")
	await _key(KEY_DOWN)
	_check_graph_preview("damage/speed", "Native Down from damage also reaches the combined upgrade state")
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.back_button, "Selected graph node precedes X in the focus chain")
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.tower_buttons[screen.selected_index], "X cycles to the selected tower index")
	await _key(KEY_TAB)
	_check_graph_preview("damage/speed", "Tab enters the remembered selected node, not an unrelated upgrade")
	await _key(KEY_TAB, true)
	_check(viewport.gui_get_focus_owner() == screen.tower_buttons[screen.selected_index], "BackTab returns from the selected node to the current tower")
	await _key(KEY_TAB, true)
	_check(viewport.gui_get_focus_owner() == screen.back_button, "BackTab wraps from the selected index to X")
	await _key(KEY_TAB, true)
	_check_graph_preview("damage/speed", "BackTab from X reaches the remembered selected node")
	screen.select_tower(&"arrow_tower")
	var deepest: Dictionary = screen.entries[screen.selected_index]["stages"].back()
	screen.select_stage(deepest["id"])
	await _settle()
	screen.stage_graph.focus_selected_stage()
	await _settle()
	_check(screen.stage_graph.get_global_rect().encloses(screen.stage_graph.stage_buttons[deepest["id"]].get_global_rect()), "Programmatic deep selection automatically reveals a full-size node")
	_check(screen.stage_graph.scroll.scroll_vertical > 0, "Deep branches use real scroll space rather than shrinking the graph")
	await _key(KEY_UP)
	_check(screen.selected_stage_id == deepest["parent_id"], "Keyboard Up from a deep tier follows its prerequisite")
	await _key(KEY_DOWN)
	_check(screen.selected_stage_id == deepest["id"], "Keyboard Down returns to the deep tier and keeps it revealed")


func _check_catalog() -> void:
	var remembered: Dictionary[StringName, String] = {}
	for index: int in range(screen.entries.size()):
		await _click(screen.tower_buttons[index].get_global_rect().get_center())
		var record: Dictionary = screen.entries[index]
		_check(screen.selected_type_id == record["id"] and screen.tower_buttons[index].button_pressed, "Index focus selects the actual identity")
		_check_graph_nodes(record)
		await _key(KEY_RIGHT)
		for stage: Dictionary in record["stages"]:
			var stage_id: String = stage["id"]
			await _choose_stage(stage_id)
			var preview: Dictionary = expected.preview(record["id"], stage_id)
			_check(not preview.is_empty(), "An actual combat-backed preview exists for the selected stage")
			if preview.is_empty():
				continue
			_check(screen.selected_stage_id == stage_id and screen.selected_preview["tower"] == preview["tower"], "Stage selection presents the accepted state, not recomputed gameplay rules")
			_check_value(&"purchase", float(preview["stats"]["cost"]))
			_check_value(&"total", float(preview["total_cost"]))
			_check_value(&"range", float(preview["tower"]["range"]))
			var sum: int = int(preview["stats"]["cost"])
			for step: Dictionary in preview["steps"]:
				sum += int(step["cost"])
			_check(sum == int(preview["total_cost"]), "Displayed investment equals placement plus the actual accepted upgrade costs")
			if not preview["steps"].is_empty():
				_check_value(&"stage_cost", float(preview["steps"].back()["cost"]))
			_check_role(preview)
			_check(screen.stage_graph.selected_stage_id == stage_id and screen.stage_graph.stage_buttons[stage_id].button_pressed, "Exactly the accepted native graph node remains visibly selected")
			_check_fixed_graph()
			_check(screen.stat_values[&"range"].get_global_rect().position.y < screen.stat_values[&"purchase"].get_global_rect().position.y, "Selected role stats remain above meaningful investment rows")
			var scroll_bar: VScrollBar = screen.details_scroll.get_v_scroll_bar()
			if scroll_bar.max_value > scroll_bar.page + 1.0:
				await _wheel_down()
				_check(screen.details_scroll.scroll_vertical > 0, "Hidden scrollbar still permits real native mouse-wheel access to lower stats")
			screen.details_scroll.scroll_vertical = int(screen.details_scroll.get_v_scroll_bar().max_value)
			await _settle()
			_check_fixed_graph()
			screen.details_scroll.scroll_vertical = 0
			await _settle()
			_check(screen.details_scroll.get_global_rect().intersects(screen.stat_values[&"range"].get_global_rect()), "Selected parent range remains reachable at the start of the detail article")
			_check(screen.details_scroll.get_h_scroll_bar().max_value <= screen.details_scroll.size.x + 1.0, "Every selected stage fits without horizontal scrolling")
		remembered[record["id"]] = screen.selected_stage_id
	for index: int in range(screen.entries.size()):
		await _click(screen.tower_buttons[index].get_global_rect().get_center())
		_check(screen.selected_stage_id == remembered[screen.selected_type_id] and screen.stage_graph.selected_stage_id == screen.selected_stage_id and screen.stage_graph.stage_buttons[screen.selected_stage_id].button_pressed, "Each tower restores its own actual selected graph node")


func _check_graph_nodes(record: Dictionary) -> void:
	_check(screen.stage_graph.stage_buttons.size() == record["stages"].size(), "Every real branch and follow-up has a native graph Button")
	for stage: Dictionary in record["stages"]:
		var stage_id: String = stage["id"]
		_check(screen.stage_graph.stage_buttons.has(stage_id), "Graph contains the actual provider stage " + stage_id)
		if not screen.stage_graph.stage_buttons.has(stage_id):
			continue
		var button: Button = screen.stage_graph.stage_buttons[stage_id]
		_check(button.get_meta("stage_id") is String and button.get_meta("stage_id") == stage_id, "Native Button metadata retains the exact String stage identity")
		_check(button.is_visible_in_tree() and not button.disabled, "Every actual graph node remains visible and clickable")
		var caption: Label = button.get_child(0).get_child(button.get_child(0).get_child_count() - 1) as Label
		_check(caption != null and button.get_global_rect().encloses(caption.get_global_rect()), "Wrapped captions stay within full-size upgrade nodes")
		if stage["commands"].size() != 1:
			var thumbnail: TowerPortrait = button.get_child(0).get_child(0) as TowerPortrait
			var accepted: Dictionary = expected.preview(record["id"], stage_id)
			_check(thumbnail != null and thumbnail.combat_towers[0] == accepted["tower"], "Each illustrated node renders its own accepted battlefield geometry")


func _check_fixed_graph() -> void:
	var graph_rect: Rect2 = screen.stage_graph.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	_check(screen.stage_graph.is_visible_in_tree(), "A nonempty selected stage always has a visible graph")
	_check(not screen.details_scroll.is_ancestor_of(screen.stage_graph), "The upgrade graph is outside the scrolling stat inspector")
	_check(viewport_rect.encloses(graph_rect), "The full fixed graph remains inside the supported viewport")
	_check(not graph_rect.intersects(screen.details_scroll.get_global_rect()), "The fixed diagram never overlaps the scrolling inspector")
	_check(viewport_rect.encloses(screen.details_scroll.get_global_rect()), "The stat inspector does not overflow the viewport")
	_check(viewport_rect.encloses(screen.back_button.get_global_rect()), "The compact X close action stays fully reachable")
	_check(not screen.details_scroll.get_v_scroll_bar().is_visible_in_tree() and not screen.details_scroll.get_h_scroll_bar().is_visible_in_tree(), "Scrolling detail content has no visible scrollbar clutter")
	var buttons: Array = screen.stage_graph.stage_buttons.values()
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var node_rect: Rect2 = button.get_global_rect()
		_check(node_rect.size.x >= 140.0 and node_rect.size.y >= 52.0, "Deep upgrades retain readable native node sizes")
		if button == screen.stage_graph.stage_buttons[screen.selected_stage_id]:
			_check(graph_rect.encloses(node_rect), "Selection is automatically revealed inside the scrollable graph")
		for other_index: int in range(index + 1, buttons.size()):
			_check(not node_rect.intersects(buttons[other_index].get_global_rect()), "Actual upgrade node rectangles never overlap")
	for button: Button in screen.tower_buttons:
		_check(viewport_rect.encloses(button.get_global_rect()) and not graph_rect.intersects(button.get_global_rect()), "Every tower rail control fits without overflowing into the diagram")
	_check(viewport.gui_get_focus_owner() == screen.stage_graph.stage_buttons[screen.selected_stage_id], "The selected native graph Button keeps actual focus even when stat height changes")
	_check(not screen.stage_graph.scroll.get_v_scroll_bar().is_visible_in_tree() and not screen.stage_graph.scroll.get_h_scroll_bar().is_visible_in_tree(), "The graph scrolls without scrollbar chrome")


func _check_graph_preview(stage_id: String, description: String, require_focus: bool = true) -> void:
	var button: Button = screen.stage_graph.stage_buttons[stage_id]
	var preview: Dictionary = expected.preview(screen.selected_type_id, stage_id)
	_check(screen.stage_graph.selected_stage_id == stage_id and button.button_pressed and screen.selected_stage_id == stage_id and screen.selected_preview["tower"] == preview["tower"], description)
	if require_focus:
		_check(viewport.gui_get_focus_owner() == button, "Native graph focus belongs to the actual selected node: " + stage_id)
	for other_id: String in screen.stage_graph.stage_buttons:
		_check(screen.stage_graph.stage_buttons[other_id].button_pressed == (other_id == stage_id), "Only the accepted upgrade node is visibly selected")


func _choose_stage(stage_id: String) -> void:
	var button: Button = screen.stage_graph.stage_buttons[stage_id]
	screen.stage_graph.scroll.ensure_control_visible(button)
	await _settle()
	await _click(button.get_global_rect().get_center())
	_check_graph_preview(stage_id, "Real pointer input selects the requested native node and actual preview")


func _check_role(preview: Dictionary) -> void:
	var tower: Dictionary = preview["tower"]
	var stats: Dictionary = preview["stats"]
	var config: Dictionary = tower["behavior_config"]
	var kind: String = tower["behavior_kind"]
	match kind:
		"support":
			_check_value(&"damage_buff", float(config["damage_bonus"]) * 100.0)
			_check_value(&"speed_buff", float(config["attack_speed_bonus"]) * 100.0)
		"economy":
			_check_value(&"clear_income", float(config["clear_income"]))
			if float(config["periodic_income"]) > 0.0:
				_check_value(&"periodic_income", float(config["periodic_income"]))
				_check_value(&"periodic_interval", float(config["periodic_interval"]))
		"bounty":
			_check_value(&"mark_damage", float(config["mark_damage_bonus"]) * 100.0)
			_check_value(&"mark_income", float(config["mark_income_bonus"]) * 100.0)
		"income_aura":
			_check_value(&"kill_income", float(config["kill_income_bonus"]) * 100.0)
		"crystal":
			_check_value(&"clear_shards", float(config["clear_shards"]))
			if int(config["periodic_shards"]) > 0:
				_check_value(&"periodic_shards", float(config["periodic_shards"]))
				_check_value(&"periodic_interval", float(config["periodic_interval"]))
		_:
			var advancement: Dictionary = stats["advancements"].get(tower["advancement"], {})
			var weapon: String = String(advancement.get("weapon", "arrow"))
			if weapon == "flamethrower":
				_check_value(&"continuous_dps", float(advancement["continuous_dps"]) * float(tower.get("damage_multiplier", 1.0)) * float(tower.get("speed_multiplier", 1.0)))
				_check_value(&"fuel_duration", float(advancement["fuel_duration"]))
				_check_value(&"refuel_duration", float(advancement["refuel_duration"]))
				_check(not screen.stat_values.has(&"interval"), "Continuous flame is not represented as discrete projectile attacks")
			elif bool(stats["evolutions"].get(tower["evolution"], {}).get("continuous", false)):
				_check_value(&"continuous_dps", float(tower["damage"]))
				_check(not screen.stat_values.has(&"interval"), "Continuous damage is never divided by a zero attack interval")
			else:
				if not advancement.has("primary_multiplier"):
					_check_value(&"damage", float(tower["damage"]))
				_check_value(&"interval", float(tower["interval"]))
			if kind == "chain":
				_check_value(&"chain_hits", float(config["hit_count"]))
				_check_value(&"jump_distance", float(config["jump_distance"]))
				_check_value(&"successive_bonus", float(config["successive_hit_bonus"]) * 100.0)
			if bool(tower["freeze_upgraded"]):
				_check_value(&"freeze_hp_scale", TowerDefinition.FREEZE_HP_SCALE)
				_check_value(&"freeze_slow", (1.0 - TowerDefinition.FREEZE_SPEED_MULTIPLIER) * 100.0)
				_check_value(&"freeze_duration", TowerDefinition.FREEZE_DURATION)
			if weapon == "minigun":
				_check(screen.stat_values.has(&"crew") and not screen.stat_values.has(&"archers"), "The minigun has three crew and one stream, not one independent archer")
			elif stats.get("special_upgrade", "") == "second_archer":
				_check_value(&"archers", float(MatchPlanningScreen.independent_weapon_count(tower, stats)))
			if advancement.has("primary_multiplier"):
				_check_value(&"primary_damage", float(ceili(float(tower["damage"]) * float(advancement["primary_multiplier"]))))
			if advancement.has("splash_multiplier"):
				_check_value(&"splash_damage", float(ceili(float(tower["damage"]) * float(advancement["splash_multiplier"]))))
			if advancement.has("burn_dps"):
				_check_value(&"burn_dps", float(advancement["burn_dps"]))
	if kind in ["support", "economy", "bounty", "income_aura"]:
		_check(not screen.stat_values.has(&"damage") and not screen.stat_values.has(&"continuous_dps") and not screen.stat_values.has(&"interval"), "Nonattacking roles show only their real support/economy stats")


func _check_reopen_and_back() -> void:
	var type_id: StringName = screen.selected_type_id
	var stage_id: String = screen.selected_stage_id
	screen.hide()
	screen.open()
	await _settle()
	_check(screen.selected_type_id == type_id and screen.selected_stage_id == stage_id, "Reopen preserves the selected identity and branch")
	await _key(KEY_RIGHT)
	_check_graph_preview(stage_id, "Reopen retains the actual selected graph node and focus target")
	var requests: Array[bool] = []
	screen.back_requested.connect(func() -> void:
		requests.append(true)
		screen.hide())
	await _key(KEY_TAB)
	_check(viewport.gui_get_focus_owner() == screen.back_button, "The selected node leads to the compact X close action")
	await _key(KEY_ENTER)
	_check(requests.size() == 1 and not screen.visible, "Real Enter on X activates the normal close signal")
	screen.open()
	await _key(KEY_RIGHT)
	_check_graph_preview(stage_id, "Reopened guide exposes the selected node without a popup")
	await _key(KEY_ESCAPE)
	_check(requests.size() == 2 and not screen.visible, "Escape from the graph directly uses the normal navigation signal")
	screen.open()


func _check_injected_catalog() -> void:
	var injected := ContentCatalog.new()
	injected.enemies.assign(rules.catalog.enemies)
	var tower := TowerDefinition.new()
	tower.reward = rules.catalog.towers[0].reward.duplicate() as TowerReward
	# This fixture borrows only baseline artwork, not branches it does not
	# declare. Branch-art admission deliberately rejects unknown stage keys.
	tower.reward.board_variants = {}
	tower.reward.id = &"injected_sentry"
	tower.reward.title = "Injected sentry"
	tower.damage = 37
	tower.interval = 1.25
	tower.range_cells = 5.0
	tower.cost = 123
	injected.towers.append(tower)
	var custom_rules: CombatRules = rules.duplicate(true) as CombatRules
	custom_rules.catalog = injected
	custom_rules.roll_rules = null
	screen.configure(injected, custom_rules)
	screen.open()
	await _settle()
	_check(screen.tower_buttons.size() == 1 and screen.selected_type_id == tower.reward.id, "Injected identities are discovered without hardcoded ID branches")
	_check_value(&"damage", 37.0)
	_check_value(&"interval", 1.25)
	_check_value(&"range", 5.0)
	_check_value(&"purchase", 123.0)


func _check_value(key: StringName, value: float) -> void:
	_check(screen.stat_values.has(key), "Selected role exposes actual stat row: " + String(key))
	if screen.stat_values.has(key):
		_check(absf(screen.stat_values[key].text.to_float() - value) <= 0.011, "Numeric value matches accepted rule data: " + String(key))
		_check(screen.stat_values[key].get_theme_font_size("font_size") >= 16, "Numeric guide values remain at least 16 pixels")


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _wheel_down() -> void:
	var position: Vector2 = root.get_final_transform() * screen.details_scroll.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
