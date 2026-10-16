class_name OrciearyScreen
extends Control

signal back_requested

const NUMERIC_FONT: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")

var catalog: ContentCatalog
var rules: CombatRules
var store: EnemyStatisticsStore
var selected_index: int = 0
var enemy_buttons: Array[Button] = []
var entries: Array[EnemyDefinition] = []
var portrait: EnemyPortrait
var _stat_values: Dictionary[StringName, Label] = {}
var _button_group := ButtonGroup.new()

@onready var back_button: Button = %Back
@onready var enemy_list: VBoxContainer = %EnemyList
@onready var title_label: Label = %EnemyTitle
@onready var availability_label: Label = %Availability
@onready var description_label: Label = %Description
@onready var mechanics_label: Label = %Mechanics
@onready var scaling_label: Label = %Scaling
@onready var kills_value: Label = %KillsValue
@onready var sent_value: Label = %SentValue
@onready var error_label: RichTextLabel = %SaveError
@onready var _details_scroll: ScrollContainer = %DetailsScroll


func configure(content: ContentCatalog, combat_rules: CombatRules, statistics: EnemyStatisticsStore) -> void:
	if store != null and store.changed.is_connected(_refresh_counts):
		store.changed.disconnect(_refresh_counts)
	catalog = content
	rules = combat_rules
	store = statistics
	if store != null:
		store.changed.connect(_refresh_counts)
	if is_node_ready():
		_build_catalog()
		_select(selected_index)


func _ready() -> void:
	back_button.pressed.connect(_request_back)
	visibility_changed.connect(_visibility_changed)
	portrait = EnemyPortrait.new()
	portrait.name = "EnemyPortrait"
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	%Preview.add_child(portrait)
	portrait.custom_minimum_size = Vector2(300.0, 220.0)
	for entry: Array in [[&"health", "Health"], [&"speed", "Speed"], [&"damage", "Base damage"], [&"bounty", "Kill bounty"], [&"cost", "Send cost"], [&"income", "Added income"]]:
		var caption := Label.new()
		caption.text = entry[1]
		caption.add_theme_font_size_override("font_size", 18)
		%Stats.add_child(caption)
		var value := Label.new()
		value.add_theme_font_override("font", NUMERIC_FONT)
		value.add_theme_font_size_override("font_size", 16)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		%Stats.add_child(value)
		_stat_values[entry[0]] = value
	_build_catalog()
	_select(selected_index)
	if not is_visible_in_tree():
		prepare_to_leave()


func open() -> void:
	show()
	if not is_node_ready():
		return
	_refresh_counts()
	if not enemy_buttons.is_empty():
		enemy_buttons[selected_index].grab_focus()
		portrait.start_preview()
	else:
		back_button.grab_focus()


func prepare_to_leave() -> void:
	if portrait != null:
		portrait.stop_preview()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_back()


func _request_back() -> void:
	prepare_to_leave()
	back_requested.emit()


func _visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		open()
	else:
		prepare_to_leave()


func _build_catalog() -> void:
	for button: Button in enemy_buttons:
		enemy_list.remove_child(button)
		button.queue_free()
	enemy_buttons.clear()
	entries.clear()
	if catalog == null:
		return
	entries.assign(catalog.enemies)
	var availability: Dictionary[StringName, int] = {}
	for definition: EnemyDefinition in entries:
		availability[definition.id] = mini(definition.first_wave if definition.regular_spawn_enabled else 2147483647, definition.send_first_wave if definition.send_enabled else 2147483647)
	# Propagate through summon chains; unreachable cycles retain the last-place sentinel.
	for pass_index: int in range(entries.size()):
		var changed: bool = false
		for source: EnemyDefinition in entries:
			if source.summon_interval <= 0.0 or not availability.has(source.summon_type):
				continue
			if availability[source.id] < availability[source.summon_type]:
				availability[source.summon_type] = availability[source.id]
				changed = true
		if not changed:
			break
	entries.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool:
		if availability[a.id] != availability[b.id]:
			return availability[a.id] < availability[b.id]
		var a_send: int = a.send_first_wave if a.send_enabled else 2147483647
		var b_send: int = b.send_first_wave if b.send_enabled else 2147483647
		if a_send != b_send:
			return a_send < b_send
		var a_regular: int = a.first_wave if a.regular_spawn_enabled else 2147483647
		var b_regular: int = b.first_wave if b.regular_spawn_enabled else 2147483647
		if a_regular != b_regular:
			return a_regular < b_regular
		return String(a.id) < String(b.id)
	)
	for index: int in range(entries.size()):
		var definition: EnemyDefinition = entries[index]
		var button := Button.new()
		button.name = String(definition.id)
		button.text = definition.title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(218.0, 48.0)
		button.add_theme_font_size_override("font_size", 18)
		button.toggle_mode = true
		button.button_group = _button_group
		enemy_list.add_child(button)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = button.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 14.0
			style.content_margin_right = 14.0
			button.add_theme_stylebox_override(state, style)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_activate.bind(index))
		button.focus_entered.connect(_select.bind(index))
		button.gui_input.connect(_list_input.bind(index))
		enemy_buttons.append(button)
	selected_index = clampi(selected_index, 0, maxi(0, enemy_buttons.size() - 1))
	_refresh_focus_chain()


func _refresh_focus_chain() -> void:
	if enemy_buttons.is_empty():
		return
	for index: int in range(enemy_buttons.size()):
		var button: Button = enemy_buttons[index]
		button.focus_neighbor_top = button.get_path_to(enemy_buttons[posmod(index - 1, enemy_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(enemy_buttons[(index + 1) % enemy_buttons.size()])
		button.focus_next = button.get_path_to(portrait)
		button.focus_previous = button.get_path_to(back_button)
	back_button.focus_next = back_button.get_path_to(enemy_buttons[selected_index])
	back_button.focus_previous = back_button.get_path_to(error_label if error_label.visible else portrait)
	portrait.focus_previous = portrait.get_path_to(enemy_buttons[selected_index])
	portrait.focus_next = portrait.get_path_to(error_label if error_label.visible else back_button)
	error_label.focus_next = error_label.get_path_to(back_button)
	error_label.focus_previous = error_label.get_path_to(portrait)


func _list_input(event: InputEvent, index: int) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var direction: int = 0
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		direction = 1
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		direction = -1
	if direction != 0:
		enemy_buttons[index].accept_event()
		enemy_buttons[posmod(index + direction, enemy_buttons.size())].grab_focus()


func _activate(index: int) -> void:
	var already_selected: bool = selected_index == index
	if not enemy_buttons[index].has_focus() and is_visible_in_tree():
		enemy_buttons[index].grab_focus()
	else:
		_select(index)
	if already_selected:
		portrait.replay_action()

func _select(index: int) -> void:
	if catalog == null or rules == null or entries.is_empty():
		title_label.text = "Orcieary unavailable"
		_refresh_counts()
		return
	selected_index = clampi(index, 0, entries.size() - 1)
	var definition: EnemyDefinition = entries[selected_index]
	for button_index: int in range(enemy_buttons.size()):
		enemy_buttons[button_index].set_pressed_no_signal(button_index == selected_index)
	title_label.text = definition.title
	availability_label.text = _availability(definition)
	description_label.text = definition.description
	portrait.configure(definition)
	if is_visible_in_tree():
		portrait.start_preview()
	else:
		portrait.stop_preview()
	var preview: Dictionary = MatchCombat.enemy_preview(definition, rules, 1)
	_stat_values[&"health"].text = "%d HP" % int(preview["max_hp"])
	_stat_values[&"speed"].text = "%.2f cells/s" % float(preview["speed"])
	_stat_values[&"damage"].text = str(int(preview["base_damage"]))
	var bounty: int = rules.kill_bounty if definition.kill_bounty < 0 else definition.kill_bounty
	_stat_values[&"bounty"].text = "%d %s" % [bounty, "Coin" if bounty == 1 else "Coins"]
	_stat_values[&"cost"].text = "%d %s" % [definition.send_cost, "Coin" if definition.send_cost == 1 else "Coins"] if definition.send_enabled else "—"
	_stat_values[&"income"].text = "+%d / clear" % definition.send_income if definition.send_enabled else "—"
	mechanics_label.text = _mechanics(definition)
	var immunities := PackedStringArray()
	if definition.fire_immune:
		immunities.append("Fire")
	if definition.ice_immune:
		immunities.append("Ice")
	if not immunities.is_empty():
		if not mechanics_label.text.is_empty():
			mechanics_label.text += "\n"
		mechanics_label.text += "Immune: " + " · ".join(immunities)
	mechanics_label.visible = not mechanics_label.text.is_empty()
	scaling_label.text = "Wave 1 · HP ×%s · Speed ×%s\nHP and speed grow with the delivery wave." % [String.num(definition.health_multiplier, 2), String.num(definition.speed_multiplier, 2)]
	_details_scroll.scroll_vertical = 0
	_refresh_counts()


func _availability(definition: EnemyDefinition) -> String:
	if not definition.regular_spawn_enabled and not definition.send_enabled:
		var sources := PackedStringArray()
		for candidate: EnemyDefinition in catalog.enemies:
			if candidate.summon_type == definition.id:
				sources.append(candidate.title)
		var source: String = "Summoned by " + ", ".join(sources) if not sources.is_empty() else "Summon only"
		return source + "\nNo regular waves or paid sends."
	var regular: String = "Regular waves %d+" % definition.first_wave if definition.regular_spawn_enabled else "No regular waves"
	var sends: String = "Sends %d+" % definition.send_first_wave if definition.send_enabled else "No paid sends"
	return regular + " · " + sends


func _mechanics(definition: EnemyDefinition) -> String:
	if definition.heal_interval > 0.0:
		return "Heals allies %s%% every %ss\nWithin %s cells · cannot heal itself" % [String.num(definition.heal_fraction * 100.0, 1), String.num(definition.heal_interval, 2), String.num(definition.heal_radius, 2)]
	if definition.summon_interval > 0.0:
		return "Summons %d–%d every %ss\n%ss cast · at most %d living summons" % [definition.summon_min, definition.summon_max, String.num(definition.summon_interval, 2), String.num(definition.summon_cast_duration, 2), definition.summon_limit]
	var minimum: int = 0
	var maximum: int = 0
	for index: int in range(definition.group_weights.size()):
		if definition.group_weights[index] > 0:
			if minimum == 0:
				minimum = index + 1
			maximum = index + 1
	if maximum > 1:
		return "Arrives in groups of %d–%d\nOne send buys one whole group" % [minimum, maximum]
	return ""


func _refresh_counts() -> void:
	if not is_node_ready():
		return
	var failure: String = ""
	if store == null:
		failure = "Enemy statistics are unavailable: no local statistics store was supplied."
	elif not store.error_message.is_empty():
		failure = store.error_message
	var values: Dictionary = {"kills": 0, "sent": 0}
	if store != null and selected_index < entries.size():
		values = store.counts(entries[selected_index].id)
	kills_value.text = str(values["kills"])
	sent_value.text = str(values["sent"])
	error_label.text = failure
	error_label.visible = not failure.is_empty()
	_refresh_focus_chain()
