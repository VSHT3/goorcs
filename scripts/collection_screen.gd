class_name CollectionScreen
extends Control

signal back_requested

var store: CollectionStore
var _opening: bool = false
var _last_error: String = ""
var _catalog_statuses: Array[Label] = []
var _catalog_icons: Array[ChestReveal.RewardIcon] = []

@onready var reveal: ChestReveal = $Margin/Content/Workspace/ChestPanel/ChestContent/Reveal
@onready var open_button: Button = $Margin/Content/Workspace/ChestPanel/ChestContent/Actions/Open
@onready var skip_button: Button = $Margin/Content/Workspace/ChestPanel/ChestContent/Actions/Skip
@onready var back_button: Button = $Margin/Content/Header/Back
@onready var reset_button: Button = $Margin/Content/Header/Reset
@onready var reset_confirmation: ConfirmationDialog = $ResetConfirmation
@onready var _count: Label = $Margin/Content/Workspace/Archive/Count
@onready var _catalog: VBoxContainer = $Margin/Content/Workspace/Archive/Catalog
@onready var _status: RichTextLabel = $Margin/Content/Workspace/Archive/Status


func _ready() -> void:
	open_button.pressed.connect(_open_chest)
	skip_button.pressed.connect(reveal.skip)
	back_button.pressed.connect(_request_back)
	reset_button.pressed.connect(_request_reset)
	reset_confirmation.confirmed.connect(_reset_progress)
	reset_confirmation.canceled.connect(_focus_action)
	reveal.finished.connect(_reveal_finished)
	visibility_changed.connect(_visibility_changed)
	if store != null:
		for reward: TowerReward in store.catalog:
			_add_catalog_entry(reward)
	_refresh()
	if is_visible_in_tree():
		_focus_action()


func prepare_to_leave() -> void:
	if is_node_ready():
		reset_confirmation.hide()
		reveal.skip()


func _request_back() -> void:
	prepare_to_leave()
	back_requested.emit()


func _visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_refresh()
		_focus_action()
	else:
		prepare_to_leave()


func _focus_action() -> void:
	if reveal.is_revealing():
		skip_button.grab_focus()
	elif not open_button.disabled:
		open_button.grab_focus()
	else:
		back_button.grab_focus()


func _request_reset() -> void:
	if not reset_button.disabled:
		reset_confirmation.popup_centered(Vector2i(480, 180))


func _reset_progress() -> void:
	if store == null or _opening or reveal.is_revealing() or store.unlocked_count() == 0:
		return
	if not store.reset_progress():
		_last_error = store.error_message
		_refresh()
		_focus_action()
		return
	reveal.clear()
	_last_error = ""
	_refresh()
	_focus_action()


func _open_chest() -> void:
	if _opening or reveal.is_revealing() or store == null or not store.can_open():
		return
	_opening = true
	open_button.disabled = true
	var result: ChestResult = store.open_chest()
	_opening = false
	if not result.error_message.is_empty():
		_last_error = result.error_message
		_refresh()
		return
	if result.rewards.is_empty():
		_refresh()
		return
	_last_error = ""
	# The model has persisted the grant before presentation begins.
	reveal.present(result.rewards)
	_refresh()
	if is_visible_in_tree():
		skip_button.grab_focus()


func _reveal_finished() -> void:
	_refresh()
	if is_visible_in_tree():
		_focus_action()


func _refresh() -> void:
	var active: bool = reveal.is_revealing()
	skip_button.visible = active
	skip_button.disabled = not active
	reset_button.disabled = true
	if store == null:
		_count.text = "Collection unavailable"
		_status.text = "No collection store was supplied. Openings are disabled."
		_status.show()
		_status.modulate = Color("e1a397")
		open_button.disabled = true
		return
	_count.text = "Revealing…" if active else "%d / %d unlocked" % [store.unlocked_count(), store.catalog.size()]
	# Persist immediately, but don't spoil reward identities before the reveal.
	if not active:
		for index: int in range(_catalog_statuses.size()):
			var unlocked: bool = store.is_unlocked(store.catalog[index].id)
			_catalog_statuses[index].text = "UNLOCKED" if unlocked else "LOCKED"
			_catalog_statuses[index].modulate = Color("b5e2b7") if unlocked else Color("9ba99b")
			_catalog_icons[index].locked = not unlocked
			_catalog_icons[index].queue_redraw()
	open_button.disabled = _opening or active or not store.can_open()
	reset_button.disabled = _opening or active or not store.error_message.is_empty() or store.unlocked_count() == 0
	var error: String = store.error_message if not store.error_message.is_empty() else _last_error
	_status.visible = not error.is_empty()
	if not error.is_empty():
		_status.text = "Could not update collection.\n" + error
		_status.modulate = Color("e1a397")
	else:
		_status.text = ""
	open_button.text = "Collection complete" if store.remaining_count() == 0 else "Open free chest"


func _add_catalog_entry(reward: TowerReward) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 106.0)
	card.tooltip_text = reward.description
	var style := StyleBoxFlat.new()
	style.bg_color = Color("222e29")
	style.border_color = Color("3c5042")
	style.border_width_left = 3
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := ChestReveal.RewardIcon.new()
	icon.reward = reward
	icon.custom_minimum_size = Vector2(52.0, 70.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_catalog_icons.append(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := Label.new()
	title.text = reward.title
	title.add_theme_font_size_override("font_size", 18)
	text.add_child(title)
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 16)
	text.add_child(status)
	_catalog_statuses.append(status)
	_catalog.add_child(card)
