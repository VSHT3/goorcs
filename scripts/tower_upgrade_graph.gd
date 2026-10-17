class_name TowerUpgradeGraph
extends Control

signal stage_selected(stage_id: String)

const ACCENT := Color(0.73, 0.85, 0.56)
const INK := Color(0.90, 0.88, 0.81)
const LINE := Color(0.34, 0.43, 0.34)

var stage_buttons: Dictionary[String, Button] = {}
var selected_stage_id: String = "base"
var _stages: Dictionary[String, Dictionary] = {}
var _parents: Dictionary[String, Array] = {}
var _children: Dictionary[String, Array] = {}
var _rows: Dictionary[int, Array] = {}
var _leaf_positions: Dictionary[String, float] = {}
var _horizontal_positions: Dictionary[String, float] = {}
var _group := ButtonGroup.new()
var _max_depth: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_nodes)
	_layout_nodes()


func configure(record: Dictionary, provider: TowerGuide) -> void:
	for button: Button in stage_buttons.values():
		remove_child(button)
		button.queue_free()
	stage_buttons.clear()
	_stages.clear()
	_parents.clear()
	_children.clear()
	_rows.clear()
	_leaf_positions.clear()
	_horizontal_positions.clear()
	_max_depth = 0
	for stage: Dictionary in record.get("stages", []):
		var stage_id: String = stage["id"]
		_stages[stage_id] = stage
		_parents[stage_id] = []
		_children[stage_id] = []
		var depth: int = stage["commands"].size()
		_max_depth = maxi(_max_depth, depth)
		if not _rows.has(depth):
			_rows[depth] = []
		_rows[depth].append(stage_id)
	# Purchase sets, not the provider's canonical display ancestry: either
	# single stat purchase can lead to the combined-upgrades state.
	for child_id: String in _stages:
		var child_commands: Array = _stages[child_id]["commands"]
		for parent_id: String in _stages:
			var parent_commands: Array = _stages[parent_id]["commands"]
			if child_commands.size() != parent_commands.size() + 1:
				continue
			var contains_parent := true
			for command: String in parent_commands:
				if not child_commands.has(command):
					contains_parent = false
					break
			if contains_parent:
				_parents[child_id].append(parent_id)
				_children[parent_id].append(child_id)
	var leaves: Array[String] = []
	for stage_id: String in _stages:
		if _children[stage_id].is_empty():
			leaves.append(stage_id)
	for index: int in range(leaves.size()):
		_leaf_positions[leaves[index]] = (float(index) + 0.5) / float(leaves.size())
	for stage_id: String in _stages:
		_horizontal_positions[stage_id] = _branch_center(stage_id)
		var stage: Dictionary = _stages[stage_id]
		var preview: Dictionary = provider.preview(record["id"], stage_id)
		var button := _make_node(stage, preview)
		stage_buttons[stage_id] = button
		add_child(button)
		button.pressed.connect(_activate.bind(stage_id))
		button.focus_entered.connect(_activate.bind(stage_id))
		button.gui_input.connect(_node_input.bind(stage_id))
	select_stage("base")
	_layout_nodes()


func select_stage(stage_id: String) -> void:
	if not stage_buttons.has(stage_id):
		return
	selected_stage_id = stage_id
	for id: String in stage_buttons:
		stage_buttons[id].set_pressed_no_signal(id == stage_id)
	queue_redraw()


func focus_selected_stage() -> void:
	if stage_buttons.has(selected_stage_id):
		stage_buttons[selected_stage_id].grab_focus()


func _activate(stage_id: String) -> void:
	select_stage(stage_id)
	stage_selected.emit(stage_id)


func _branch_center(stage_id: String) -> float:
	var leaves: Array[String] = []
	_collect_leaves(stage_id, leaves)
	if leaves.is_empty():
		return 0.5
	var first: float = 1.0
	var last: float = 0.0
	for leaf: String in leaves:
		first = minf(first, _leaf_positions[leaf])
		last = maxf(last, _leaf_positions[leaf])
	return (first + last) * 0.5


func _collect_leaves(stage_id: String, leaves: Array[String]) -> void:
	if _children[stage_id].is_empty():
		if not leaves.has(stage_id):
			leaves.append(stage_id)
		return
	for child_id: String in _children[stage_id]:
		_collect_leaves(child_id, leaves)


func _make_node(stage: Dictionary, preview: Dictionary) -> Button:
	var button := Button.new()
	var stage_id: String = stage["id"]
	var depth: int = stage["commands"].size()
	button.name = "Stage_" + stage_id.replace("/", "_")
	button.set_meta("stage_id", stage_id)
	button.toggle_mode = true
	button.button_group = _group
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = ""
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.15, 0.12)
		style.border_color = Color(0.28, 0.36, 0.28)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.set_content_margin_all(5)
		if state == "hover":
			style.bg_color = Color(0.16, 0.22, 0.16)
			style.border_color = Color(0.48, 0.58, 0.39)
		elif state == "pressed":
			style.bg_color = Color(0.18, 0.25, 0.16)
			style.border_color = ACCENT
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(0.91, 0.96, 0.77)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	focus.set_expand_margin_all(3)
	button.add_theme_stylebox_override("focus", focus)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_right = -6
	content.offset_top = 5
	content.offset_bottom = -5
	content.add_theme_constant_override("separation", 2)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)
	if depth != 1:
		var artwork := TextureRect.new()
		artwork.custom_minimum_size = Vector2(0, 40 if depth != 2 else 32)
		artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reward: TowerReward = preview.get("reward", null)
		if reward != null:
			var tower: Dictionary = preview["tower"]
			var variant: Dictionary = reward.board_variant(tower.get("evolution", ""), tower.get("followup", ""))
			artwork.texture = variant.get("texture", reward.icon_texture)
		content.add_child(artwork)
	var caption := Label.new()
	caption.text = _caption(stage)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", INK)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	return button


func _caption(stage: Dictionary) -> String:
	match String(stage["title"]):
		"Damage upgrade": return "Damage +"
		"Speed upgrade": return "Speed +"
		"Attack-speed aura": return "Speed aura +"
		"Damage aura": return "Damage aura +"
		"Income upgrade I": return "Income I"
		"Income upgrade II": return "Income II"
		"Both upgrades": return "III"
	return String(stage["title"])


func _layout_nodes() -> void:
	if stage_buttons.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		queue_redraw()
		return
	var diagram_height: float = minf(size.y - 16.0, 570.0)
	var step: float = minf(116.0, (diagram_height - 100.0) / float(maxi(_max_depth, 1)))
	var top: float = maxf(8.0, (size.y - (step * _max_depth + 96.0)) * 0.5)
	for depth: int in _rows:
		var row: Array = _rows[depth]
		for index: int in range(row.size()):
			var stage_id: String = row[index]
			var button: Button = stage_buttons[stage_id]
			var width: float = 144.0 if depth != 1 else 140.0
			var height: float = 92.0 if depth != 1 else 52.0
			if depth == 2:
				height = 80.0
			var x: float = _horizontal_positions[stage_id] * size.x
			# Parallel stat purchases share every descendant, but must remain
			# visibly separate arms of the purchase diamond.
			if depth == 1:
				x = size.x * 0.5 + (float(index) - float(row.size() - 1) * 0.5) * 184.0
			button.position = Vector2(clampf(x - width * 0.5, 6.0, size.x - width - 6.0), top + depth * step + (92.0 - height) * 0.5)
			button.size = Vector2(width, height)
	queue_redraw()


func _draw() -> void:
	for parent_id: String in _children:
		var parent: Button = stage_buttons[parent_id]
		for child_id: String in _children[parent_id]:
			var child: Button = stage_buttons[child_id]
			var start := Vector2(parent.position.x + parent.size.x * 0.5, parent.position.y + parent.size.y + 2.0)
			var finish := Vector2(child.position.x + child.size.x * 0.5, child.position.y - 2.0)
			var middle: float = (start.y + finish.y) * 0.5
			var color: Color = Color(0.55, 0.65, 0.43) if child_id == selected_stage_id or parent_id == selected_stage_id else LINE
			draw_polyline(PackedVector2Array([start, Vector2(start.x, middle), Vector2(finish.x, middle), finish]), color, 2.0, false)


func _node_input(event: InputEvent, stage_id: String) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var button: Button = stage_buttons[stage_id]
	var target: String = ""
	if event.is_action_pressed("ui_up"):
		target = _nearest(stage_id, _parents[stage_id])
	elif event.is_action_pressed("ui_down"):
		target = _nearest(stage_id, _children[stage_id])
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var depth: int = _stages[stage_id]["commands"].size()
		var row: Array = _rows[depth]
		var offset: int = -1 if event.is_action_pressed("ui_left") else 1
		var index: int = row.find(stage_id) + offset
		if index >= 0 and index < row.size():
			target = row[index]
		elif offset < 0 and not button.focus_previous.is_empty():
			var previous: Control = button.get_node(button.focus_previous) as Control
			previous.grab_focus()
	else:
		return
	button.accept_event()
	if not target.is_empty():
		stage_buttons[target].grab_focus()


func _nearest(stage_id: String, candidates: Array) -> String:
	var nearest: String = ""
	var distance: float = INF
	var origin: Button = stage_buttons[stage_id]
	var center: float = origin.position.x + origin.size.x * 0.5
	for candidate_id: String in candidates:
		var candidate: Button = stage_buttons[candidate_id]
		var candidate_distance: float = absf(center - candidate.position.x - candidate.size.x * 0.5)
		if candidate_distance < distance - 0.01:
			distance = candidate_distance
			nearest = candidate_id
	return nearest
