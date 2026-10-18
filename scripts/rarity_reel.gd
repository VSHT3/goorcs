class_name RarityReel
extends Control
## Cosmetic presentation of an already accepted host result; never rolls gameplay state.

signal finished

const TICK: AudioStream = preload("res://assets/audio/sfx/rarity_tick_01.wav")
const REVEAL: AudioStream = preload("res://assets/audio/sfx/rarity_reveal_01.wav")
const MENU_THEME: Theme = preload("res://resources/ui/menu_theme.tres")
const RARITIES: PackedStringArray = ["broken", "shoddy", "common", "uncommon", "rare", "epic", "legendary", "mythic"]
const SPIN_SECONDS: float = 4.1
const REVEAL_SECONDS: float = 2.8
const CARD_COUNT: int = 38
const WINNER_INDEX: int = 32
const START_POSITION: float = 3.15
const FRAME := Color("425744")
const ACCENT := Color("bad98f")

var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _elapsed: float = 0.0
var _last_crossing: int = 0
var _revealed: bool = false
var _winner_rank: int = 0
var _winner_name: String = ""
var _winner_color: Color
var _previous_focus: WeakRef
var _panel: Control
var _heading: Label
var _result: Label
var _close: Button
var _strip: ReelStrip
var _tick: AudioStreamPlayer
var _reveal: AudioStreamPlayer


class ReelStrip extends Control:
	const CARD_WIDTH: float = 136.0
	const STRIDE: float = 148.0
	const CARD_HEIGHT: float = 184.0
	const FONT: Font = preload("res://assets/fonts/PixelifySans.ttf")
	const MARKER := Color("e0bc77")

	var rarities := PackedInt32Array()
	var names := PackedStringArray()
	var colors := PackedColorArray()
	var shades := PackedColorArray()
	var artwork: Texture2D
	var artwork_bounds := Rect2()
	var scroll_position: float = 0.0
	var winner_index: int = -1
	var reveal: float = 0.0
	var _top_marker := PackedVector2Array()
	var _bottom_marker := PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(_layout_markers)
		_layout_markers()

	func set_artwork(texture: Texture2D) -> void:
		artwork = texture
		artwork_bounds = Rect2()
		if artwork != null:
			var image: Image = artwork.get_image()
			artwork_bounds = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, artwork.get_size())

	func _layout_markers() -> void:
		var center: float = floorf(size.x * 0.5)
		_top_marker = PackedVector2Array([Vector2(center - 7.0, 0.0), Vector2(center + 7.0, 0.0), Vector2(center, 10.0)])
		_bottom_marker = PackedVector2Array([Vector2(center - 7.0, size.y), Vector2(center + 7.0, size.y), Vector2(center, size.y - 10.0)])
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0d1713"))
		var center: float = floorf(size.x * 0.5)
		var half_visible: int = ceili(size.x / STRIDE * 0.5) + 1
		var first: int = maxi(0, floori(scroll_position) - half_visible)
		var last: int = mini(rarities.size(), ceili(scroll_position) + half_visible + 1)
		for index: int in range(first, last):
			var rank: int = rarities[index]
			var color: Color = colors[rank]
			var card := Rect2(Vector2(roundf(center + (float(index) - scroll_position) * STRIDE - CARD_WIDTH * 0.5), 16.0), Vector2(CARD_WIDTH, CARD_HEIGHT))
			var winning: bool = index == winner_index
			if winning and reveal > 0.0:
				for ring: int in range(4, 0, -1):
					var glow: Color = color
					glow.a = reveal * 0.035 * float(5 - ring)
					draw_rect(card.grow(float(ring) * 3.0), glow)
			draw_rect(card, shades[rank])
			draw_rect(card, color.darkened(0.45), false, 1.0)
			draw_rect(Rect2(card.position, Vector2(CARD_WIDTH, 4.0)), color)
			draw_rect(Rect2(card.position + Vector2(0.0, CARD_HEIGHT - 5.0), Vector2(CARD_WIDTH, 5.0)), color)
			if artwork != null and artwork_bounds.has_area():
				var extent: Vector2 = (artwork_bounds.size * (96.0 / maxf(artwork_bounds.size.x, artwork_bounds.size.y))).floor()
				var icon_rect := Rect2((card.position + Vector2((CARD_WIDTH - extent.x) * 0.5, 24.0 + (102.0 - extent.y) * 0.5)).round(), extent)
				draw_texture_rect_region(artwork, icon_rect, artwork_bounds)
			draw_string(FONT, card.position + Vector2(6.0, 158.0), names[rank], HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH - 12.0, 18, color)
			if reveal > 0.0:
				if winning:
					var highlight: Color = color
					highlight.a = reveal
					draw_rect(card.grow(2.0), highlight, false, 2.0)
				else:
					draw_rect(card, Color(0.025, 0.045, 0.035, reveal * 0.60))
		# These stay fixed while the strip moves beneath them.
		draw_line(Vector2(center, 10.0), Vector2(center, 15.0), MARKER, 2.0)
		draw_line(Vector2(center, size.y - 15.0), Vector2(center, size.y - 10.0), MARKER, 2.0)
		draw_colored_polygon(_top_marker, MARKER)
		draw_colored_polygon(_bottom_marker, MARKER)
		# Quiet end masks reinforce the clipped horizontal window without a shader.
		for step: int in range(6):
			var shade := Color(0.051, 0.090, 0.075, float(6 - step) * 0.12)
			draw_rect(Rect2(float(step) * 5.0, 0.0, 5.0, size.y), shade)
			draw_rect(Rect2(size.x - float(step + 1) * 5.0, 0.0, 5.0, size.y), shade)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	theme = MENU_THEME
	_rng.randomize()
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_heading = _label(24)
	_heading.text = "Rarity"
	_panel.add_child(_heading)
	_close = Button.new()
	CloseButtonStyle.apply(_close)
	_close.pressed.connect(cancel)
	_panel.add_child(_close)
	_strip = ReelStrip.new()
	for rarity: String in RARITIES:
		var color: Color = MatchPlanningScreen.tower_rarity_color({"rarity": rarity})
		_strip.names.append(rarity.capitalize())
		_strip.colors.append(color)
		_strip.shades.append(Color("17251f").lerp(color, 0.09))
	_panel.add_child(_strip)
	_result = _label(24)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_result)
	_tick = _audio_player(TICK)
	_reveal = _audio_player(REVEAL)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	set_process(false)
	set_process_input(false)
	hide()


func present(tower: Dictionary, artwork: Texture2D) -> void:
	# The caller owns acceptance detection and duplicate-request locking.
	if _busy or not is_node_ready():
		return
	var parent_item := get_parent() as CanvasItem
	if parent_item != null and not parent_item.is_visible_in_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_winner_rank = RARITIES.find(String(tower.get("rarity", "common")))
	if _winner_rank < 0:
		_winner_rank = 2
	_winner_name = _strip.names[_winner_rank]
	_winner_color = MatchPlanningScreen.tower_rarity_color(tower)
	_strip.set_artwork(artwork)
	_strip.rarities.resize(CARD_COUNT)
	for index: int in range(CARD_COUNT):
		_strip.rarities[index] = _rng.randi_range(0, RARITIES.size() - 1)
	_strip.rarities[WINNER_INDEX] = _winner_rank
	_strip.winner_index = WINNER_INDEX
	_strip.scroll_position = START_POSITION
	_strip.reveal = 0.0
	_elapsed = 0.0
	_revealed = false
	_last_crossing = floori(START_POSITION + 0.5)
	_result.text = ""
	_heading.text = "Rarity"
	_busy = true
	show()
	get_parent().move_child(self, -1)
	_layout()
	_close.grab_focus()
	set_process(true)
	set_process_input(true)
	_strip.queue_redraw()
	queue_redraw()


func is_busy() -> bool:
	return _busy


func cancel() -> void:
	var was_busy: bool = _busy
	_busy = false
	set_process(false)
	set_process_input(false)
	if _tick != null:
		_tick.stop()
	if _reveal != null:
		_reveal.stop()
	hide()
	if not was_busy:
		return
	if _previous_focus != null:
		var previous := _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
			previous.grab_focus()
	_previous_focus = null
	finished.emit()


func _process(delta: float) -> void:
	_elapsed += delta
	if not _revealed:
		var progress: float = minf(_elapsed / SPIN_SECONDS, 1.0)
		# Quartic ease-out gives long travel, then individually audible final crossings.
		var remaining: float = 1.0 - progress
		_strip.scroll_position = lerpf(START_POSITION, float(WINNER_INDEX), 1.0 - remaining * remaining * remaining * remaining)
		var crossing: int = floori(_strip.scroll_position + 0.5)
		if crossing != _last_crossing:
			_last_crossing = crossing
			_tick.pitch_scale = lerpf(1.18, 0.86, progress)
			_tick.volume_db = -12.0
			_tick.play()
		if progress >= 1.0:
			_begin_reveal()
	else:
		_strip.reveal = minf((_elapsed - SPIN_SECONDS) / 0.45, 1.0)
		if _elapsed >= SPIN_SECONDS + REVEAL_SECONDS:
			cancel()
			return
	_strip.queue_redraw()
	queue_redraw()


func _begin_reveal() -> void:
	_revealed = true
	# Start the readable hold at the actual reveal, even after a delayed frame.
	_elapsed = SPIN_SECONDS
	_strip.scroll_position = float(WINNER_INDEX)
	_tick.stop()
	_reveal.pitch_scale = 0.92 + float(_winner_rank) * 0.035
	_reveal.volume_db = -8.0 + float(_winner_rank) * 0.35
	_reveal.play()
	_result.text = _winner_name
	_result.add_theme_color_override("font_color", _winner_color)


func _input(event: InputEvent) -> void:
	if not _busy or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		return # Keep the native close-button hover; the owning screen blocks world motion.
	# Handle actions before dismissal so the same event cannot reach another screen.
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				cancel()
			else:
				_close.grab_focus()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _close.get_global_rect().has_point(event.position):
			_close.pressed.emit()
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept"):
		cancel()


func _gui_input(_event: InputEvent) -> void:
	# Empty overlay space is still modal, including wheel and gesture events.
	accept_event()


func _visibility_changed() -> void:
	# Inherited visibility changes also fire when the owning screen is hidden.
	if _busy and not is_visible_in_tree():
		cancel()


func _exit_tree() -> void:
	cancel()


func _layout() -> void:
	if _panel == null:
		return
	_panel.size = Vector2(minf(1000.0, maxf(0.0, size.x - 64.0)), 354.0)
	_panel.position = ((size - _panel.size) * 0.5).floor()
	_heading.position = Vector2(24.0, 18.0)
	_heading.size = Vector2(maxf(0.0, _panel.size.x - 100.0), 40.0)
	_close.position = Vector2(_panel.size.x - 60.0, 18.0)
	_close.size = Vector2(40.0, 40.0)
	_strip.position = Vector2(20.0, 76.0)
	_strip.size = Vector2(maxf(0.0, _panel.size.x - 40.0), 216.0)
	_result.position = Vector2(24.0, 302.0)
	_result.size = Vector2(maxf(0.0, _panel.size.x - 48.0), 36.0)
	queue_redraw()


func _draw() -> void:
	if not _busy or _panel == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.020, 0.76))
	var panel := Rect2(_panel.position, _panel.size)
	draw_rect(panel, Color("17251f"))
	draw_rect(panel, FRAME, false, 2.0)
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3.0)), ACCENT)
	draw_line(panel.position + Vector2(20.0, 66.0), panel.position + Vector2(panel.size.x - 20.0, 66.0), FRAME, 1.0)
	if _revealed:
		var glow: Color = _winner_color
		glow.a = _strip.reveal * 0.6
		draw_rect(panel.grow(2.0), glow, false, 2.0)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _audio_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Sound"
	add_child(player)
	return player
