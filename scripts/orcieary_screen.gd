class_name OrciearyScreen
extends Control

signal back_requested

const NUMERIC_FONT: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const CATEGORY_NAMES: Array[String] = ["Basic", "Elite", "Boss"]
const CATEGORY_COLORS: Array[Color] = [Color.WHITE, Color("c79aef"), Color("ef7777")]

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
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(_request_back)
	visibility_changed.connect(_visibility_changed)
	_details_scroll.resized.connect(_resize_stats)
	_resize_stats()
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
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		MenuAudio.activate(back_button)


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
	for child: Node in enemy_list.get_children():
		enemy_list.remove_child(child)
		child.queue_free()
	enemy_buttons.clear()
	entries.clear()
	if catalog == null:
		return
	entries.assign(catalog.enemies)
	var availability: Dictionary[StringName, int] = {}
	for definition: EnemyDefinition in entries:
		availability[definition.id] = mini(definition.first_wave if definition.regular_spawn_enabled or definition.boss else 2147483647, definition.send_first_wave if definition.send_enabled else 2147483647)
	# Propagate first encounters through summons, death children and gated variants.
	for pass_index: int in range(entries.size()):
		var changed: bool = false
		for source: EnemyDefinition in entries:
			for child: String in ContentCatalog.child_ids(source):
				var child_id := StringName(child)
				if availability.has(child_id) and availability[source.id] < availability[child_id]:
					availability[child_id] = availability[source.id]
					changed = true
			if source.spawn_variant != &"" and availability.has(source.spawn_variant):
				var first_variant: int = maxi(availability[source.id], source.spawn_variant_first_wave)
				if first_variant < availability[source.spawn_variant]:
					availability[source.spawn_variant] = first_variant
					changed = true
		if not changed:
			break
	entries.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool:
		var a_category: int = _category(a)
		var b_category: int = _category(b)
		if a_category != b_category:
			return a_category < b_category
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
	var previous_category: int = -1
	for index: int in range(entries.size()):
		var definition: EnemyDefinition = entries[index]
		var category: int = _category(definition)
		var color: Color = CATEGORY_COLORS[category]
		if category != previous_category:
			var heading := Label.new()
			heading.text = CATEGORY_NAMES[category]
			heading.custom_minimum_size.y = 30.0
			heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			heading.add_theme_font_size_override("font_size", 18)
			heading.add_theme_color_override("font_color", color)
			enemy_list.add_child(heading)
			previous_category = category
		var button := Button.new()
		button.name = String(definition.id)
		button.text = definition.title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(218.0, 48.0)
		button.add_theme_font_size_override("font_size", 18)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(state, color)
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
	title_label.add_theme_color_override("font_color", CATEGORY_COLORS[_category(definition)])
	availability_label.text = _availability(definition)
	description_label.text = definition.description
	portrait.configure(definition)
	if is_visible_in_tree():
		portrait.start_preview()
	else:
		portrait.stop_preview()
	var preview_wave: int = definition.first_wave if definition.boss else 1
	var variant_source: EnemyDefinition = _variant_source(definition)
	if variant_source != null:
		preview_wave = variant_source.spawn_variant_first_wave
	var preview: Dictionary = MatchCombat.enemy_preview(definition, rules, preview_wave)
	_stat_values[&"health"].text = "%d HP" % int(preview["max_hp"])
	_stat_values[&"speed"].text = "%.2f cells/s" % float(preview["speed"])
	_stat_values[&"damage"].text = str(int(preview["base_damage"]))
	var bounty: int = rules.kill_bounty if definition.kill_bounty < 0 else definition.kill_bounty
	_stat_values[&"bounty"].text = "%d %s" % [bounty, "Coin" if bounty == 1 else "Coins"]
	_stat_values[&"cost"].text = "%d %s" % [definition.send_cost, "Coin" if definition.send_cost == 1 else "Coins"] if definition.send_enabled else "—"
	_stat_values[&"income"].text = "%+d / clear" % definition.send_income if definition.send_enabled else "—"
	mechanics_label.text = _mechanics(definition)
	if definition.boss:
		mechanics_label.text = "Later waves %s%%–%s%% · Weight %d\n" % [String.num(definition.boss_spawn_chance * 100.0, 1), String.num(definition.boss_spawn_chance_cap * 100.0, 1), definition.spawn_weight] + mechanics_label.text
	var immunities := PackedStringArray()
	if definition.fire_immune:
		immunities.append("Fire")
	if definition.ice_immune:
		immunities.append("Ice")
	if not immunities.is_empty():
		if not mechanics_label.text.is_empty():
			mechanics_label.text += "\n"
		mechanics_label.text += "Immune: " + " · ".join(immunities)
	if definition.fire_immune:
		mechanics_label.text += "\nNo burning · ignores Flamethrowers"
	if definition.ice_immune:
		mechanics_label.text += "\nNo slowing"
	mechanics_label.visible = not mechanics_label.text.is_empty()
	scaling_label.text = "Wave %d · HP ×%s · Speed ×%s" % [preview_wave, String.num(definition.health_multiplier, 2), String.num(definition.speed_multiplier, 2)]
	_details_scroll.scroll_vertical = 0
	_refresh_counts()


func _category(definition: EnemyDefinition) -> int:
	return 2 if definition.boss else (1 if definition.elite else 0)


func _availability(definition: EnemyDefinition) -> String:
	if definition.boss:
		var sends: String = "Sends %d+" % definition.send_first_wave if definition.send_enabled else "No paid sends"
		return "Boss round %d · %s" % [definition.first_wave, sends]
	var variant_source: EnemyDefinition = _variant_source(definition)
	if variant_source != null:
		return "%s births %d+ · %s%% chance\nNo regular waves or paid sends." % [variant_source.title, variant_source.spawn_variant_first_wave, String.num(variant_source.spawn_variant_chance * 100.0, 2)]
	if not definition.regular_spawn_enabled and not definition.send_enabled:
		var sources := PackedStringArray()
		for candidate: EnemyDefinition in catalog.enemies:
			if String(definition.id) in ContentCatalog.child_ids(candidate):
				sources.append(candidate.title)
		var source: String = "Created by " + ", ".join(sources) if not sources.is_empty() else "Child only"
		return source + "\nNo regular waves or paid sends."
	var regular: String = "Regular waves %d+" % definition.first_wave if definition.regular_spawn_enabled else "No regular waves"
	var sends: String = "Sends %d+" % definition.send_first_wave if definition.send_enabled else "No paid sends"
	return regular + " · " + sends


func _mechanics(definition: EnemyDefinition) -> String:
	var lines := PackedStringArray()
	if definition.hit_shield > 0:
		lines.append("Shield: first %d hits · no overflow\nBlocks ignition and freezing\nContinuous attacks: one charge per attack interval" % definition.hit_shield)
	if definition.death_stun_radius > 0.0 and definition.death_stun_duration > 0.0:
		lines.append("On death: %ss tower stun · within %s tile (incl. diagonals)\nNo stun on leaks · attacks, support and income stop" % [String.num(definition.death_stun_duration, 1), String.num(definition.death_stun_radius, 1)])
	if definition.death_bomb_radius > 0.0 and definition.death_bomb_stun_duration > 0.0:
		lines.append("On death: drops a bomb · %ss fuse\nBlast: %ss enemy + tower stun · within %s tiles (incl. diagonals)\nNo damage or extra Coins · no bomb on leaks" % [String.num(definition.death_bomb_fuse, 1), String.num(definition.death_bomb_stun_duration, 1), String.num(definition.death_bomb_radius, 1)])
	if definition.spawn_variant != &"":
		for variant: EnemyDefinition in catalog.enemies:
			if variant.id == definition.spawn_variant:
				lines.append("Round %d+: each birth has a fixed %s%% chance of %s" % [definition.spawn_variant_first_wave, String.num(definition.spawn_variant_chance * 100.0, 2), variant.title])
				break
	if definition.health_base_type != &"":
		for source: EnemyDefinition in catalog.enemies:
			if source.id == definition.health_base_type:
				lines.append("%s× %s HP · %s%% slower\nSame round · same immunities" % [String.num(definition.health_base_multiplier, 0), source.title, String.num((1.0 - definition.speed_multiplier / source.speed_multiplier) * 100.0, 0)])
				break
	if not is_equal_approx(definition.physical_damage_multiplier, 1.0):
		lines.append("Physical damage ×%s" % String.num(definition.physical_damage_multiplier, 2))
	if definition.death_spawn_count > 0:
		for child: EnemyDefinition in catalog.enemies:
			if child.id == definition.death_spawn_type:
				lines.append("On death: %d %s\nChildren inherit its remaining route · no children on leak" % [definition.death_spawn_count, child.title])
				break
	if definition.enrage_health_fraction > 0.0:
		lines.append("At %s%% HP: permanent speed ×%s" % [String.num(definition.enrage_health_fraction * 100.0, 1), String.num(definition.enrage_speed_multiplier, 2)])
	if definition.regeneration_interval > 0.0:
		lines.append("Regenerates %s%% max HP every %ss\nSelf only · rounded up" % [String.num(definition.regeneration_fraction * 100.0, 1), String.num(definition.regeneration_interval, 2)])
	if definition.heal_interval > 0.0:
		lines.append("Heals allies %s%% every %ss\nWithin %s cells · cannot heal itself" % [String.num(definition.heal_fraction * 100.0, 1), String.num(definition.heal_interval, 2), String.num(definition.heal_radius, 2)])
	if definition.summon_interval > 0.0:
		lines.append("Summons %d–%d every %ss · %ss cast\nAt most %d living summons" % [definition.summon_min, definition.summon_max, String.num(definition.summon_interval, 2), String.num(definition.summon_cast_duration, 2), definition.summon_limit])
		if not definition.summon_pool.is_empty():
			var troops := PackedStringArray()
			for index: int in range(definition.summon_pool.size()):
				var weight: int = definition.summon_weights[index] if index < definition.summon_weights.size() else 1
				for child: EnemyDefinition in catalog.enemies:
					if String(child.id) == definition.summon_pool[index]:
						troops.append("%s ×%d" % [child.title, weight])
			lines.append("Troop weights: " + " · ".join(troops))
	if not is_equal_approx(definition.nonphysical_damage_multiplier, 1.0):
		lines.append("Non-physical damage ×%s" % String.num(definition.nonphysical_damage_multiplier, 2))
	if not is_equal_approx(definition.fire_damage_multiplier, 1.0):
		lines.append("Fire damage ×%s" % String.num(definition.fire_damage_multiplier, 2))
	if not is_equal_approx(definition.lightning_damage_multiplier, 1.0):
		lines.append("Lightning damage ×%s" % String.num(definition.lightning_damage_multiplier, 2))
	if definition.stomp_interval > 0.0:
		lines.append("Walking stomp every %ss · %s-cell radius\nHurts other enemies for %s%% of their max HP" % [String.num(definition.stomp_interval, 1), String.num(definition.stomp_radius, 1), String.num(definition.stomp_health_fraction * 100.0, 1)])
	if definition.tower_attack_interval > 0.0:
		var targets: String = "%d random towers · whole board" % definition.tower_attack_targets if definition.tower_attack_kind == &"cannon" else "Nearest tower · %s-cell range" % String.num(definition.tower_attack_range, 1)
		lines.append("%s every %ss · %s\n%ss windup · %ss stun" % [String(definition.tower_attack_kind).capitalize(), String.num(definition.tower_attack_interval, 1), targets, String.num(definition.tower_attack_cast_duration, 1), String.num(definition.tower_stun_duration, 1)])
	if definition.tower_stun_duration > 0.0:
		lines.append("Stun suspends attacks, support and income")
	if definition.jump_interval > 0.0:
		lines.append("Follows the painted path on wheels\nJumps 2–5 path tiles every %ss" % String.num(definition.jump_interval, 1))
		var odds := PackedStringArray()
		var total: int = 0
		for weight: int in definition.jump_weights:
			total += weight
		for index: int in range(definition.jump_weights.size()):
			odds.append("%d tiles %s%%" % [index + 2, String.num(float(definition.jump_weights[index]) / total * 100.0, 1)])
		lines.append(" · ".join(odds))
		lines.append("Legs → crouch → jump → land → wheels")
	var minimum: int = 0
	var maximum: int = 0
	for index: int in range(definition.group_weights.size()):
		if definition.group_weights[index] > 0:
			if minimum == 0:
				minimum = index + 1
			maximum = index + 1
	if maximum > 1:
		lines.append("Arrives in groups of %d–%d\nOne send buys one whole group" % [minimum, maximum])
	return "\n".join(lines)


func _resize_stats() -> void:
	%Stats.columns = 2 if _details_scroll.size.x < 540.0 else (4 if _details_scroll.size.x < 820.0 else 6)


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


func _variant_source(definition: EnemyDefinition) -> EnemyDefinition:
	for source: EnemyDefinition in catalog.enemies:
		if source.spawn_variant == definition.id:
			return source
	return null
