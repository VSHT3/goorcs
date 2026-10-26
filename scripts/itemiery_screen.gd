class_name ItemieryScreen
extends Control

signal back_requested

var back_button: Button
var _viewport: SubViewport
var _lights: Node2D


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1410")
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
	margin.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	var title := Label.new()
	title.text = "Itemiery"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	back_button = Button.new()
	back_button.name = "Back"
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back_button)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_viewport.add_child(ItemieryRoom.new())
	_lights = preload("res://scripts/itemiery_lights.gd").new()
	_viewport.add_child(_lights)
	var room := TextureRect.new()
	room.name = "Room"
	room.texture = _viewport.get_texture()
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(room)
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()


func open() -> void:
	show()
	back_button.grab_focus()


func prepare_to_leave() -> void:
	set_process_unhandled_key_input(false)
	_lights.set_process(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_visibility() -> void:
	var active: bool = is_visible_in_tree()
	set_process_unhandled_key_input(active)
	_lights.set_process(active)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		MenuAudio.activate(back_button)
		get_viewport().set_input_as_handled()
