class_name ItemInspector
extends Control
## Read-only item portraits and rules. Upgrade navigation never changes a run.

signal closed

var shown_item: ItemDefinition
var back_button: Button
var portrait: TextureRect
var upgrade_button: Button

var _catalog: ContentCatalog
var _preview_source: ItemDefinition
var _panel: PanelContainer
var _heading: Label
var _rarity: Label
var _effect: Label
var _mechanics: Label
var _flavor: Label
var _acquisition: Label
var _cost: Label
var _return_button: Button
var _scroll: ScrollContainer
var _art_column: VBoxContainer
var _art_frame: PortraitFrame
var _entrance: Tween
var _layout_pending: bool = false
var _layout_generation: int = 0


class PortraitFrame extends Control:
	var accent: Color = Color.WHITE
	var tier: ItemRarity.Tier = ItemRarity.Tier.COMMON
	var _elapsed: float = 0.0
	var _frame: int = -1

	func _process(delta: float) -> void:
		_elapsed += delta
		var frame: int = int(_elapsed * 24.0)
		if frame != _frame:
			_frame = frame
			queue_redraw()

	func _draw() -> void:
		var bounds := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		draw_rect(bounds, Color("0b1510"))
		var strength: float = ItemRarity.glow_strength(tier)
		for band: int in range(5, 0, -1):
			var inset: float = 7.0 + float(band) * 5.0
			draw_rect(bounds.grow(-inset), Color(accent, strength * 0.035))
		draw_rect(bounds, Color(accent, 0.55), false, 2.0)
		draw_rect(bounds.grow(-7), Color(accent, 0.18), false, 1.0)
		for corner: Vector2 in [Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(1, size.y - 1), size - Vector2.ONE]:
			var direction := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
			draw_line(corner, corner + Vector2(direction.x * 22, 0), accent, 3.0)
			draw_line(corner, corner + Vector2(0, direction.y * 22), accent, 3.0)
		if tier == ItemRarity.Tier.ORCFECCION:
			var travel: float = fmod(_elapsed * 0.22, 1.0)
			var x: float = 24.0 + travel * (size.x - 48.0)
			var alpha: float = sin(travel * PI)
			draw_line(Vector2(x - 12, 1), Vector2(x + 12, 1), Color("e5ffc8", alpha), 3.0)
			for index: int in range(4):
				var progress: float = fmod(travel + float(index) / 4.0, 1.0)
				var point := Vector2(15.0 + float(index % 2) * (size.x - 30.0), size.y - 20.0 - progress * (size.y - 40.0))
				draw_rect(Rect2(point, Vector2(2, 2)), Color(accent, sin(progress * PI) * 0.75))


func _ready() -> void:
	name = "ItemInspector"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = CloseButtonStyle.THEME
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.02, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "InspectionPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17251c")
	style.border_color = Color("57664c")
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	# Keep wrapped content minimums from resizing the viewport-owned modal.
	var panel_content := Control.new()
	panel_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(panel_content)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 22)
	panel_content.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	shell.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 4)
	header.add_child(title_stack)
	_rarity = _label(17)
	title_stack.add_child(_rarity)
	_heading = _label(30)
	_heading.name = "ItemTitle"
	title_stack.add_child(_heading)
	var close_space := Control.new()
	close_space.custom_minimum_size = Vector2(40, 40)
	close_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(close_space)
	back_button = Button.new()
	back_button.name = "CloseInspection"
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(dismiss)
	# The close target must not move when a title or description rewraps.
	panel_content.add_child(back_button)
	back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back_button.offset_left = -40
	back_button.offset_bottom = 40
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	shell.add_child(body)
	_art_column = VBoxContainer.new()
	_art_column.add_theme_constant_override("separation", 14)
	body.add_child(_art_column)
	_art_frame = PortraitFrame.new()
	_art_frame.name = "PortraitFrame"
	_art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_column.add_child(_art_frame)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 16
	portrait.offset_top = 16
	portrait.offset_right = -16
	portrait.offset_bottom = -16
	_art_frame.add_child(portrait)
	_cost = _label(18)
	_cost.name = "UpgradeCost"
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_column.add_child(_cost)
	upgrade_button = Button.new()
	upgrade_button.name = "PreviewUpgrade"
	upgrade_button.text = "Preview upgrade"
	upgrade_button.custom_minimum_size.y = 44
	MenuAudio.bind_action(upgrade_button)
	upgrade_button.pressed.connect(_preview_upgrade)
	_art_column.add_child(upgrade_button)
	_return_button = Button.new()
	_return_button.name = "ReturnFromPreview"
	_return_button.custom_minimum_size.y = 44
	_return_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuAudio.bind_action(_return_button)
	_return_button.pressed.connect(_return_from_preview)
	_art_column.add_child(_return_button)
	_scroll = ScrollContainer.new()
	_scroll.name = "ItemRulesScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.follow_focus = true
	var scroll_focus := StyleBoxFlat.new()
	scroll_focus.bg_color = Color.TRANSPARENT
	scroll_focus.border_color = Color("d5dba8")
	scroll_focus.set_border_width_all(2)
	_scroll.add_theme_stylebox_override("focus", scroll_focus)
	_scroll.gui_input.connect(_scroll_input)
	body.add_child(_scroll)
	var content := VBoxContainer.new()
	content.name = "Rules"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	_scroll.add_child(content)
	_effect = _label(21)
	_effect.name = "Effect"
	content.add_child(_effect)
	_mechanics = _label(18)
	_mechanics.name = "ExactMechanics"
	_mechanics.add_theme_constant_override("line_spacing", 4)
	content.add_child(_mechanics)
	_acquisition = _label(18)
	_acquisition.name = "Acquisition"
	content.add_child(_acquisition)
	_flavor = _label(18)
	_flavor.name = "Flavor"
	_flavor.add_theme_color_override("font_color", Color("c5cbb3"))
	content.add_child(_flavor)
	_panel.minimum_size_changed.connect(_queue_panel_layout)
	shell.minimum_size_changed.connect(_queue_panel_layout)
	resized.connect(_queue_panel_layout)
	visibility_changed.connect(_visibility_changed)
	_layout_panel()
	hide()
	set_process_input(false)


func show_item(item: ItemDefinition, catalog: ContentCatalog) -> void:
	if item == null:
		return
	_catalog = catalog
	_preview_source = null
	_present(item)


func dismiss() -> void:
	if _preview_source != null:
		_return_from_preview()
		return
	close()
	closed.emit()


func close() -> void:
	_stop_entrance()
	_preview_source = null
	hide()
	set_process_input(false)
	if _art_frame != null:
		_art_frame.set_process(false)


func _present(item: ItemDefinition) -> void:
	_stop_entrance()
	shown_item = item
	_heading.text = item.title
	_rarity.text = ItemRarity.NAMES[item.rarity]
	var accent: Color = ItemRarity.color(item.rarity)
	_rarity.add_theme_color_override("font_color", accent)
	_heading.add_theme_color_override("font_color", Color("f0f3df"))
	portrait.texture = item.detail_texture
	_effect.text = item.effect_text
	_mechanics.text = "• " + "\n• ".join(item.mechanics)
	_flavor.text = item.flavor_text
	_flavor.visible = not item.flavor_text.is_empty()
	_acquisition.text = item.acquisition_text
	_acquisition.visible = not item.acquisition_text.is_empty()
	_acquisition.add_theme_color_override("font_color", accent.lightened(0.25))
	var has_upgrade: bool = _find_upgrade(item) != null
	upgrade_button.visible = has_upgrade
	_cost.visible = has_upgrade
	_cost.text = "Upgrade · %s Coins" % _grouped_price(item.upgrade_cost)
	_cost.add_theme_color_override("font_color", accent)
	_return_button.visible = _preview_source != null
	if _preview_source != null:
		_return_button.text = "Back to " + _preview_source.title
	_art_frame.accent = accent
	_art_frame.tier = item.rarity
	_art_frame.queue_redraw()
	_scroll.scroll_vertical = 0
	show()
	set_process_input(is_visible_in_tree())
	_art_frame.set_process(is_visible_in_tree() and item.rarity == ItemRarity.Tier.ORCFECCION)
	_layout_panel()
	back_button.grab_focus()
	_panel.modulate.a = 0.7
	_entrance = create_tween().set_parallel(true)
	_entrance.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(_panel, "modulate:a", 1.0, 0.18)


func _preview_upgrade() -> void:
	var target: ItemDefinition = _find_upgrade(shown_item)
	if target == null:
		return
	_preview_source = shown_item
	_present(target)


func _return_from_preview() -> void:
	if _preview_source == null:
		return
	var source: ItemDefinition = _preview_source
	_preview_source = null
	_present(source)
	upgrade_button.grab_focus()


func _find_upgrade(item: ItemDefinition) -> ItemDefinition:
	if item == null or item.upgrade_to == &"" or _catalog == null:
		return null
	for candidate: ItemDefinition in _catalog.items:
		if candidate.id == item.upgrade_to:
			return candidate
	return null


func _queue_panel_layout() -> void:
	if _layout_pending or not is_visible_in_tree():
		return
	_layout_pending = true
	_flush_panel_layout.call_deferred(_layout_generation)


func _flush_panel_layout(generation: int) -> void:
	if generation != _layout_generation:
		return
	_layout_pending = false
	if is_visible_in_tree():
		_layout_panel()


func _cancel_panel_layout() -> void:
	_layout_generation += 1
	_layout_pending = false


func _layout_panel() -> void:
	if _panel == null:
		return
	var panel_size := Vector2(minf(1120, size.x - 64), minf(660, size.y - 64))
	var art_side: float = clampf((panel_size.x - 48) * 0.33, 288, 352)
	_art_column.custom_minimum_size.x = art_side
	_art_frame.custom_minimum_size = Vector2.ONE * art_side
	# Coalesce wrapped-content sorts while keeping panel and close geometry owned
	# by the viewport, not by a label's transient minimum size.
	_panel.size = panel_size.round()
	_panel.position = ((size - panel_size) * 0.5).round()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_TAB:
		var controls: Array[Control] = [back_button, _scroll]
		if upgrade_button.visible:
			controls.append(upgrade_button)
		if _return_button.visible:
			controls.append(_return_button)
		var index: int = controls.find(get_viewport().gui_get_focus_owner())
		var direction: int = -1 if event.shift_pressed else 1
		controls[posmod(index + direction, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()


func _scroll_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var amount: int = 0
	match event.keycode:
		KEY_DOWN:
			amount = 42
		KEY_UP:
			amount = -42
		KEY_PAGEDOWN, KEY_SPACE:
			amount = maxi(42, int(_scroll.size.y) - 42)
		KEY_PAGEUP:
			amount = -maxi(42, int(_scroll.size.y) - 42)
		KEY_HOME:
			_scroll.scroll_vertical = 0
		KEY_END:
			_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
		_:
			return
	_scroll.scroll_vertical += amount
	_scroll.accept_event()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_cancel_panel_layout()
		_stop_entrance()
		set_process_input(false)
		if _art_frame != null:
			_art_frame.set_process(false)


func _exit_tree() -> void:
	_cancel_panel_layout()
	_stop_entrance()


func _stop_entrance() -> void:
	if _entrance != null:
		_entrance.kill()
		_entrance = null
	if _panel != null:
		_panel.modulate.a = 1.0


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6ebdb"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _grouped_price(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
