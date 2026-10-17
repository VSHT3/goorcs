class_name ToweriearyScreen
extends Control

signal back_requested

const NUMERIC_FONT: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const MUTED := Color(0.69, 0.76, 0.68)
const ACCENT := Color(0.73, 0.85, 0.56)

var provider := TowerGuide.new()
var catalog: ContentCatalog
var rules: CombatRules
var entries: Array[Dictionary] = []
var tower_buttons: Array[Button] = []
var stage_graph: TowerUpgradeGraph
var selected_index: int = 0
var selected_type_id: StringName = &""
var selected_stage_id: String = "base"
var selected_preview: Dictionary = {}
var stat_values: Dictionary[StringName, Label] = {}
var back_button: Button
var portrait: TowerPortrait
var title_label: Label
var stage_label: Label
var role_label: Label
var description_label: Label
var error_label: Label
var details_scroll: ScrollContainer
var index_scroll: ScrollContainer
var _index: VBoxContainer
var _details: VBoxContainer
var _stats: GridContainer
var _costs: GridContainer
var _stage_memory: Dictionary[StringName, String] = {}
var _tower_group := ButtonGroup.new()


func configure(content: ContentCatalog, combat_rules: CombatRules) -> void:
	catalog = content
	rules = combat_rules
	provider.configure(content, combat_rules)
	entries = provider.entries
	if is_node_ready():
		_build_index()


func _ready() -> void:
	_build_layout()
	_build_index()
	visibility_changed.connect(_visibility_changed)


func open() -> void:
	show()
	if not is_node_ready():
		return
	set_process_unhandled_key_input(true)
	details_scroll.scroll_vertical = 0
	if not tower_buttons.is_empty():
		tower_buttons[selected_index].grab_focus()
	else:
		back_button.grab_focus()


func prepare_to_leave() -> void:
	set_process_unhandled_key_input(false)


func select_tower(type_id: StringName) -> void:
	for index: int in range(entries.size()):
		if entries[index]["id"] == type_id:
			_select_tower(index)
			return


func select_stage(stage_id: String) -> void:
	if entries.is_empty():
		return
	for stage: Dictionary in entries[selected_index]["stages"]:
		if stage["id"] == stage_id:
			selected_stage_id = stage_id
			_stage_memory[selected_type_id] = stage_id
			details_scroll.scroll_vertical = 0
			stage_graph.select_stage(stage_id)
			_refresh_preview()
			return


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.067, 0.10, 0.086)
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
	shell.add_theme_constant_override("separation", 16)
	margin.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	var heading := _label("Towerieary", 34)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	back_button = Button.new()
	back_button.name = "Back"
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(_request_back)
	header.add_child(back_button)
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	shell.add_child(workspace)
	var index_column := VBoxContainer.new()
	index_column.custom_minimum_size.x = 88
	index_column.add_theme_constant_override("separation", 8)
	workspace.add_child(index_column)
	index_scroll = ScrollContainer.new()
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	index_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	index_scroll.follow_focus = true
	index_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_column.add_child(index_scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 8)
	index_scroll.add_child(_index)
	var graph_column := VBoxContainer.new()
	graph_column.custom_minimum_size.x = 450
	graph_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_column.add_theme_constant_override("separation", 8)
	workspace.add_child(graph_column)
	graph_column.add_child(_label("Upgrades", 18, MUTED))
	stage_graph = TowerUpgradeGraph.new()
	stage_graph.name = "StageGraph"
	stage_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_graph.stage_selected.connect(select_stage)
	graph_column.add_child(stage_graph)
	var article_column := VBoxContainer.new()
	article_column.custom_minimum_size.x = 340
	article_column.add_theme_constant_override("separation", 8)
	workspace.add_child(article_column)
	details_scroll = ScrollContainer.new()
	details_scroll.name = "DetailsScroll"
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	article_column.add_child(details_scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(_details)
	error_label = _label("", 20, Color(0.95, 0.70, 0.64), true)
	_details.add_child(error_label)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	_details.add_child(hero)
	var art_panel := PanelContainer.new()
	art_panel.add_theme_stylebox_override("panel", _material())
	art_panel.custom_minimum_size = Vector2(108, 128)
	art_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero.add_child(art_panel)
	portrait = TowerPortrait.new()
	portrait.custom_minimum_size = Vector2(84, 104)
	portrait.name = "TowerPortrait"
	art_panel.add_child(portrait)
	var introduction := VBoxContainer.new()
	introduction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	introduction.add_theme_constant_override("separation", 6)
	hero.add_child(introduction)
	role_label = _label("", 16, ACCENT, true)
	introduction.add_child(role_label)
	title_label = _label("", 24, Color(0.90, 0.88, 0.81), true)
	introduction.add_child(title_label)
	stage_label = _label("", 16, MUTED, true)
	introduction.add_child(stage_label)
	description_label = _label("", 16, Color(0.90, 0.88, 0.81), true)
	introduction.add_child(description_label)
	_details.add_child(HSeparator.new())
	_stats = _grid()
	_details.add_child(_stats)
	_details.add_child(HSeparator.new())
	_costs = _grid()
	_details.add_child(_costs)


func _build_index() -> void:
	_clear(_index)
	tower_buttons.clear()
	stage_graph.configure({}, provider)
	var valid_memory: Dictionary[StringName, String] = {}
	for record: Dictionary in entries:
		var remembered_stage: String = _stage_memory.get(record["id"], "base")
		for stage: Dictionary in record["stages"]:
			if stage["id"] == remembered_stage:
				valid_memory[record["id"]] = remembered_stage
				break
	_stage_memory = valid_memory
	for index: int in range(entries.size()):
		var record: Dictionary = entries[index]
		var button := _button(Vector2(88, 76))
		button.name = String(record["id"])
		button.button_group = _tower_group
		_index.add_child(button)
		button.tooltip_text = ""
		button.set_meta("tower_id", record["id"])
		var thumbnail := _texture(Vector2.ZERO)
		thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumbnail.offset_left = 12
		thumbnail.offset_right = -12
		thumbnail.offset_top = 8
		thumbnail.offset_bottom = -8
		var reward: TowerReward = record["reward"]
		thumbnail.texture = reward.icon_texture if reward != null else null
		button.add_child(thumbnail)
		button.pressed.connect(_select_tower.bind(index))
		button.focus_entered.connect(_select_tower.bind(index))
		button.gui_input.connect(_index_input.bind(index))
		tower_buttons.append(button)
	if entries.is_empty():
		selected_index = 0
		selected_type_id = &""
		selected_stage_id = "base"
		_show_unavailable()
		return
	var remembered: int = selected_index
	for index: int in range(entries.size()):
		if entries[index]["id"] == selected_type_id:
			remembered = index
			break
	selected_type_id = &""
	_select_tower(clampi(remembered, 0, entries.size() - 1))


func _select_tower(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	if selected_type_id == entries[index]["id"] and not selected_preview.is_empty():
		tower_buttons[index].set_pressed_no_signal(true)
		return
	selected_index = index
	var record: Dictionary = entries[index]
	selected_type_id = record["id"]
	selected_stage_id = _stage_memory.get(selected_type_id, "base")
	for other: int in range(tower_buttons.size()):
		tower_buttons[other].set_pressed_no_signal(other == index)
	stage_graph.configure(record, provider)
	if stage_graph.stage_buttons.is_empty():
		_show_unavailable()
		return
	if not stage_graph.stage_buttons.has(selected_stage_id):
		selected_stage_id = "base"
	_stage_memory[selected_type_id] = selected_stage_id
	stage_graph.select_stage(selected_stage_id)
	details_scroll.scroll_vertical = 0
	_refresh_preview()




func _refresh_preview() -> void:
	selected_preview = provider.preview(selected_type_id, selected_stage_id)
	if selected_preview.is_empty():
		_show_unavailable()
		return
	error_label.hide()
	var record: Dictionary = entries[selected_index]
	var tower: Dictionary = selected_preview["tower"]
	var stats: Dictionary = selected_preview["stats"]
	var stage: Dictionary = selected_preview["stage"]
	title_label.text = record["title"] if selected_stage_id == "base" else String(stage["title"])
	stage_label.text = String(record["title"])
	stage_label.visible = selected_stage_id != "base"
	role_label.text = _role_title(tower.get("behavior_kind", record["role"]))
	description_label.text = _stage_description(record, tower, stats)
	portrait.configure(selected_preview)
	stat_values.clear()
	_clear(_costs)
	_clear(_stats)
	_add_stat(_costs, &"purchase", "Base placement", "%d Coins" % int(stats.get("cost", 0)))
	_add_stat(_costs, &"total", "Total investment", "%d Coins" % int(selected_preview["total_cost"]))
	var steps: Array = selected_preview["steps"]
	if not steps.is_empty():
		_add_stat(_costs, &"stage_cost", "Selected upgrade cost", "%d Coins" % int(steps.back()["cost"]))
	_add_stat(_stats, &"range", "Range", "%s cells" % _number(float(tower["range"])))
	_populate_role_stats(tower, stats)
	stage_graph.select_stage(selected_stage_id)
	_refresh_focus_chain()




func _stage_description(record: Dictionary, tower: Dictionary, stats: Dictionary) -> String:
	var kind: String = tower.get("behavior_kind", "attack")
	var config: Dictionary = tower.get("behavior_config", {})
	match kind:
		"support":
			if float(config.get("attack_speed_bonus", 0.0)) == 0.0:
				return "Increases nearby towers' damage."
			if float(config.get("damage_bonus", 0.0)) == 0.0:
				return "Increases nearby towers' attack speed."
			return "Increases nearby towers' damage and attack speed."
		"economy":
			if float(config.get("periodic_income", 0.0)) > 0.0:
				return "Produces Coins on round clear and at regular intervals during combat."
			return "Produces Coins when a round is cleared."
		"bounty":
			return "Marks enemies for increased damage taken and kill rewards."
		"income_aura":
			return "Increases nearby towers' kill rewards."
		"chain":
			return "Chains through nearby enemies, dealing more damage with each jump." if float(config.get("successive_hit_bonus", 0.0)) > 0.0 else "Chains through nearby enemies at full damage."
	var advancement: Dictionary = stats.get("advancements", {}).get(tower.get("advancement", ""), {})
	match String(advancement.get("weapon", "arrow")):
		"flamethrower":
			return "One operator sprays continuous FIRE damage. After 60 uninterrupted firing seconds, refuel for 6 seconds. Losing a target resets the streak; refueling cannot be canceled. Burn refreshes without stacking."
		"molotov":
			return "Two throwers lob incendiary bottles: impact, splash, and refreshing burn."
		"grenade":
			return "Two throwers lob anti-orc grenades with a wider, heavier blast."
		"rocket":
			return "One muscular operator fires slow, heavy rockets with a huge blast."
		"minigun":
			return "Three archers crew one rotary arrow gun: a single stream with the output of twenty archers."
	if advancement.has("burn_dps"):
		return "Independent archers fire arrows that burn their targets. Burning refreshes without stacking."
	if advancement.has("splash_multiplier"):
		return "Independent archers fire explosive arrows, damaging the primary target and nearby enemies."
	if advancement.has("archer_count") or (stats.get("special_upgrade", "") == "second_archer" and bool(tower.get("special_upgraded", false))):
		return "Independent archers prefer different enemies, sharing targets when needed."
	var evolution: String = tower.get("evolution", "")
	var branch: Dictionary = stats.get("evolutions", {}).get(evolution, {})
	if bool(stats.get("area_attack", false)):
		if bool(tower.get("freeze_upgraded", false)):
			return "Immediately slows nearby ice-susceptible enemies. Higher maximum HP means faster thawing."
		if bool(branch.get("continuous", false)):
			return "Deals continuous damage to enemies in the surrounding tile neighborhood."
		return "Pulses damage through enemies in the surrounding tile neighborhood."
	if evolution == "pierce":
		return "Projectiles pass straight through an enemy and can hit a second aligned target."
	if evolution == "bounce":
		return "Projectiles redirect to another nearby enemy after the first hit."
	return String(record["description"])


func _populate_role_stats(tower: Dictionary, stats: Dictionary) -> void:
	var kind: String = tower.get("behavior_kind", "attack")
	var config: Dictionary = tower.get("behavior_config", {})
	match kind:
		"support":
			_add_stat(_stats, &"damage_buff", "Nearby tower damage", "+%s%%" % _number(float(config["damage_bonus"]) * 100.0))
			_add_stat(_stats, &"speed_buff", "Nearby attack speed", "+%s%%" % _number(float(config["attack_speed_bonus"]) * 100.0))
		"economy":
			_add_stat(_stats, &"clear_income", "Round-clear income", "%d Coins" % int(config["clear_income"]))
			if float(config["periodic_income"]) > 0.0:
				_add_stat(_stats, &"periodic_income", "Periodic income", "%d Coins" % int(config["periodic_income"]))
				_add_stat(_stats, &"periodic_interval", "Production interval", "%s combat s" % _number(float(config["periodic_interval"])))
		"bounty":
			_add_stat(_stats, &"mark_damage", "Marked damage taken", "+%s%%" % _number(float(config["mark_damage_bonus"]) * 100.0))
			_add_stat(_stats, &"mark_income", "Marked normal kill Coins", "+%s%%" % _number(float(config["mark_income_bonus"]) * 100.0))
		"income_aura":
			_add_stat(_stats, &"kill_income", "Normal kill Coins", "+%s%%" % _number(float(config["kill_income_bonus"]) * 100.0))
		_:
			_populate_attack_stats(tower, stats)


func _populate_attack_stats(tower: Dictionary, stats: Dictionary) -> void:
	var evolution: String = tower.get("evolution", "")
	var branch: Dictionary = stats.get("evolutions", {}).get(evolution, {})
	var continuous: bool = bool(branch.get("continuous", false))
	var damage: int = int(tower["damage"])
	var advancement: Dictionary = stats.get("advancements", {}).get(tower.get("advancement", ""), {})
	var weapon: String = String(advancement.get("weapon", "arrow"))
	continuous = continuous or weapon == "flamethrower"
	if continuous:
		var dps: float = float(advancement.get("continuous_dps", damage)) * (float(tower.get("damage_multiplier", 1.0)) * float(tower.get("speed_multiplier", 1.0)) if weapon == "flamethrower" else 1.0)
		_add_stat(_stats, &"continuous_dps", "Continuous FIRE" if weapon == "flamethrower" else "Continuous damage", "%s / s" % _number(dps))
	else:
		var caption: String = "Initial hit damage" if tower.get("behavior_kind", "attack") == "chain" else ("Damage per pulse" if bool(stats.get("area_attack", false)) else "Damage per hit")
		if advancement.has("primary_multiplier"):
			_add_stat(_stats, &"primary_damage", "Primary hit damage", str(ceili(float(damage) * float(advancement["primary_multiplier"]))))
		else:
			_add_stat(_stats, &"damage", caption, str(damage))
		_add_stat(_stats, &"interval", "Attack interval", "%s s" % _number(float(tower["interval"])))
		_add_stat(_stats, &"attack_rate", "Stream rate" if weapon == "minigun" else "Attacks / s per weapon", _number(1.0 / maxf(float(tower["interval"]), 0.001)))
	if weapon == "flamethrower":
		_add_stat(_stats, &"fuel_duration", "Uninterrupted fire", "%s s" % _number(float(advancement.get("fuel_duration", 60.0))))
		_add_stat(_stats, &"refuel_duration", "Mandatory refuel", "%s s" % _number(float(advancement.get("refuel_duration", 6.0))))
	if tower.get("behavior_kind", "attack") == "chain":
		var config: Dictionary = tower["behavior_config"]
		_add_stat(_stats, &"chain_hits", "Maximum chain hits", str(int(config["hit_count"])))
		_add_stat(_stats, &"jump_distance", "Jump reach", "%s cells" % _number(float(config["jump_distance"])))
		_add_stat(_stats, &"successive_bonus", "Each successive hit", "+%s%% base damage" % _number(float(config["successive_hit_bonus"]) * 100.0))
	elif bool(stats.get("area_attack", false)):
		if bool(tower.get("freeze_upgraded", false)):
			_add_stat(_stats, &"freeze_hp_scale", "Thaw HP scale", "%s HP" % _number(TowerDefinition.FREEZE_HP_SCALE))
			_add_stat(_stats, &"freeze_slow", "Movement reduction", "%s%%" % _number((1.0 - TowerDefinition.FREEZE_SPEED_MULTIPLIER) * 100.0))
			_add_stat(_stats, &"freeze_duration", "Base slow duration", "%s s" % _number(TowerDefinition.FREEZE_DURATION))
	else:
		if stats.get("special_upgrade", "") == "second_archer":
			var count: int = int(advancement.get("archer_count", 2 if bool(tower.get("special_upgraded", false)) else 1))
			if weapon == "minigun":
				_add_stat(_stats, &"crew", "Crew / arrow streams", "3 / 1")
			else:
				_add_stat(_stats, &"archers", "Operators" if weapon in ["flamethrower", "rocket"] else ("Independent throwers" if weapon in ["molotov", "grenade"] else "Independent archers"), str(count))
			if advancement.has("splash_multiplier"):
				_add_stat(_stats, &"splash_damage", "Other splash targets", str(ceili(float(damage) * float(advancement["splash_multiplier"]))))
				_add_stat(_stats, &"splash_radius", "Splash radius", "%s cells" % _number(float(advancement["splash_radius"])))
			if advancement.has("burn_dps"):
				_add_stat(_stats, &"burn_dps", "Burn damage", "%s / s" % _number(float(advancement["burn_dps"]) * float(tower.get("damage_multiplier", 1.0))))
				_add_stat(_stats, &"burn_duration", "Burn duration", "%s s" % _number(float(advancement["burn_duration"])))
		elif evolution == "pierce":
			_add_stat(_stats, &"pierce_hits", "Straight-through hits", "2")
		elif evolution == "bounce":
			_add_stat(_stats, &"redirects", "Additional redirects", "1")
			_add_stat(_stats, &"bounce_damage", "Redirect damage", str(ceili(float(damage) * TowerDefinition.BOUNCE_DAMAGE_MULTIPLIER)))




func _index_input(event: InputEvent, index: int) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		tower_buttons[index].accept_event()
		var direction: int = 1 if event.is_action_pressed("ui_down") else -1
		tower_buttons[posmod(index + direction, tower_buttons.size())].grab_focus()
	elif event.is_action_pressed("ui_right") and not stage_graph.stage_buttons.is_empty():
		tower_buttons[index].accept_event()
		stage_graph.focus_selected_stage()


func _refresh_focus_chain() -> void:
	if tower_buttons.is_empty():
		back_button.focus_next = back_button.get_path_to(back_button)
		back_button.focus_previous = back_button.get_path_to(back_button)
		return
	var selected_node: Button = stage_graph.stage_buttons.get(selected_stage_id)
	var next_control: Control = back_button if selected_node == null else selected_node
	for button: Button in tower_buttons:
		button.focus_next = button.get_path_to(next_control)
		button.focus_previous = button.get_path_to(back_button)
		button.focus_neighbor_right = button.get_path_to(next_control)
	for button: Button in stage_graph.stage_buttons.values():
		button.focus_previous = button.get_path_to(tower_buttons[selected_index])
		button.focus_next = button.get_path_to(back_button)
	back_button.focus_next = back_button.get_path_to(tower_buttons[selected_index])
	back_button.focus_previous = back_button.get_path_to(next_control if next_control != back_button else tower_buttons[selected_index])


func _show_unavailable() -> void:
	selected_preview = {}
	stage_graph.configure({}, provider)
	portrait.configure({})
	title_label.text = "No tower preview available"
	stage_label.text = ""
	role_label.text = ""
	description_label.text = "The field guide needs a valid tower catalog and combat rules."
	error_label.text = provider.error_message if not provider.error_message.is_empty() else "This catalog has no towers."
	error_label.show()
	_clear(_stats)
	_clear(_costs)
	stat_values.clear()
	_refresh_focus_chain()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		MenuAudio.activate(back_button)


func _request_back() -> void:
	prepare_to_leave()
	back_requested.emit()


func _visibility_changed() -> void:
	if is_node_ready() and not is_visible_in_tree():
		prepare_to_leave()


func _add_stat(grid: GridContainer, key: StringName, caption: String, text: String) -> void:
	var label := _label(caption, 16, MUTED, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var value := _label(text, 16, Color(0.90, 0.88, 0.81))
	value.add_theme_font_override("font", NUMERIC_FONT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(value)
	stat_values[key] = value


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


func _label(text: String, font_size: int, color: Color = Color(0.90, 0.88, 0.81), wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _texture(minimum: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.custom_minimum_size = minimum
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _button(minimum: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = minimum
	button.toggle_mode = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = get_theme_stylebox(state, "Button").duplicate()
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	var focus: StyleBoxFlat = get_theme_stylebox("focus", "Button").duplicate() as StyleBoxFlat
	focus.set_expand_margin_all(0)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _material() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.145, 0.13)
	style.border_color = Color(0.26, 0.34, 0.27)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	return style


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _number(value: float) -> String:
	return String.num(value, 2)


func _role_title(role: String) -> String:
	match role:
		"attack": return "Damage"
		"chain": return "Chain damage"
		"support": return "Tower support"
		"economy": return "Coin production"
		"bounty": return "Enemy marking"
		"income_aura": return "Kill-income support"
		_: return role.replace("_", " ").capitalize()
