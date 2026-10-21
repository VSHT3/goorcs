class_name RarityReel
extends Control
## Cosmetic presentation of an already accepted host result; never rolls gameplay state.

signal finished

const TICK: AudioStream = preload("res://assets/audio/sfx/rarity_tick_01.wav")
const REVEAL: AudioStream = preload("res://assets/audio/sfx/rarity_reveal_01.wav")
const MENU_THEME: Theme = preload("res://resources/ui/menu_theme.tres")
const RARITIES: PackedStringArray = ["broken", "shoddy", "common", "uncommon", "rare", "epic", "legendary", "mythic"]
const ACCEL_SECONDS: float = 1.15
const CRUISE_SECONDS: float = 1.35
const BRAKE_SECONDS: float = 4.0
const SPIN_SECONDS: float = ACCEL_SECONDS + CRUISE_SECONDS + BRAKE_SECONDS
const REVEAL_SECONDS: float = 2.8
const CARD_COUNT: int = 141
const WINNER_INDEX: int = 135
const START_POSITION: float = 3.15
const LANDING_RADIUS: int = 5
const FRAME := Color("425744")
const ACCENT := Color("bad98f")

var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _suspended: bool = false
var _elapsed: float = 0.0
var _last_crossing: int = 0
var _landing_position: float = float(WINNER_INDEX)
var _peak_speed: float = 0.0
var _revealed: bool = false
var _winner_rank: int = 0
# Lowest rank the current presentation can land on; filler cards never show less.
var _floor_rank: int = 0
var _winner_name: String = ""
var _winner_color: Color
var _winner_payout: String = ""
var _previous_focus: WeakRef
var _panel: Control
var _heading: Label
var _result: Label
var _payout: Label
var _close: Button
var _strip: ReelStrip
var _tick: AudioStreamPlayer
var _reveal: AudioStreamPlayer


class ReelStrip extends Control:
	const CARD_WIDTH: float = 136.0
	const STRIDE: float = CARD_WIDTH
	const CARD_HEIGHT: float = 184.0
	const FONT: Font = preload("res://assets/fonts/PixelifySans.ttf")
	const NUMBERS: Font = preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
	const MARKER := Color("e0bc77")

	var rarities := PackedInt32Array()
	var names := PackedStringArray()
	var colors := PackedColorArray()
	var coins := PackedStringArray()
	var shards := PackedStringArray()
	var shades := PackedColorArray()
	var artwork: Texture2D
	var artwork_bounds := Rect2()
	var scroll_position: float = 0.0
	var winner_index: int = -1
	var reveal: float = 0.0
	var _top_marker := PackedVector2Array()
	var flap_angle: float = 0.0
	var flap_velocity: float = 0.0

	func release_contact() -> void:
		# Release stored spring deflection; don't inject an unrelated full flip.
		flap_velocity = minf(flap_velocity, 0.0)

	func advance_flap(delta: float) -> void:
		# Small spring steps stay stable even when the rendered frame is delayed.
		var remaining: float = minf(delta, 0.1)
		while remaining > 0.0:
			var step: float = minf(remaining, 1.0 / 120.0)
			var edge_phase: float = scroll_position + 0.5 - floorf(scroll_position + 0.5)
			var contact: float = clampf((edge_phase - 0.82) / 0.18, 0.0, 1.0)
			var pressed_angle: float = contact * 0.62
			flap_velocity += (-640.0 * flap_angle - 19.0 * flap_velocity) * step
			flap_angle += flap_velocity * step
			# A passing tooth is solid: the pointer cannot spring through it.
			if flap_angle < pressed_angle:
				flap_angle = pressed_angle
				flap_velocity = maxf(0.0, flap_velocity)
			remaining -= step

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
		_top_marker = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(4, 8), Vector2(0, 17), Vector2(-4, 8)])
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
				var reward: bool = not coins.is_empty()
				var icon_size: float = 60.0 if reward else 96.0
				var extent: Vector2 = (artwork_bounds.size * (icon_size / maxf(artwork_bounds.size.x, artwork_bounds.size.y))).floor()
				var icon_rect := Rect2((card.position + Vector2((CARD_WIDTH - extent.x) * 0.5, 18.0 + (64.0 - extent.y) * 0.5 if reward else 24.0 + (102.0 - extent.y) * 0.5)).round(), extent)
				draw_texture_rect_region(artwork, icon_rect, artwork_bounds)
			var name_y: float = 104.0 if not coins.is_empty() else 158.0
			draw_string(FONT, card.position + Vector2(6.0, name_y), names[rank], HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH - 12.0, 18, color)
			if not coins.is_empty():
				draw_string(NUMBERS, card.position + Vector2(6.0, 136.0), coins[rank], HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH - 12.0, 16, Color("f5dca5"))
				draw_string(NUMBERS, card.position + Vector2(6.0, 160.0), shards[rank], HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH - 12.0, 16, Color("c1eff0"))
			if reveal > 0.0:
				if winning:
					var highlight: Color = color
					highlight.a = reveal
					draw_rect(card.grow(2.0), highlight, false, 2.0)
				else:
					draw_rect(card, Color(0.025, 0.045, 0.035, reveal * 0.60))
		# The top flapper catches shared card edges, resting freely over card centers.
		draw_set_transform(Vector2(center, 1.0), flap_angle)
		draw_colored_polygon(_top_marker, MARKER)
		draw_circle(Vector2.ZERO, 2.5, Color("f5dca5"))
		draw_set_transform(Vector2.ZERO)
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
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_payout = _label(20)
	_payout.add_theme_font_override("font", ReelStrip.NUMBERS)
	_payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_payout)
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
	if not _can_present():
		return
	_strip.coins.clear()
	_strip.shards.clear()
	for index: int in range(RARITIES.size()):
		_strip.names[index] = RARITIES[index].capitalize()
	_winner_payout = ""
	_heading.text = "Rarity"
	_floor_rank = 0
	_start(String(tower.get("rarity", "common")), artwork)


func present_reward(award: Dictionary, artwork: Texture2D = null) -> void:
	if not _can_present():
		return
	_strip.coins.resize(RARITIES.size())
	_strip.shards.resize(RARITIES.size())
	_floor_rank = RARITIES.size() - 1
	for tier: Dictionary in award["tiers"]:
		var rank: int = RARITIES.find(String(tier["id"]))
		if rank < 0:
			continue
		_floor_rank = mini(_floor_rank, rank)
		_strip.names[rank] = String(tier["title"])
		_strip.coins[rank] = "%d Coins" % int(tier["coins"])
		_strip.shards[rank] = "%d Shards" % int(tier["shards"])
	_winner_payout = "%d Coins · %d Shards" % [int(award["coins"]), int(award["shards"])]
	_heading.text = String(award["boss_title"])
	_start(String(award["rarity"]), artwork, String(award["rarity_title"]))


func _can_present() -> bool:
	if _busy or not is_node_ready():
		return false
	var parent_item := get_parent() as CanvasItem
	return parent_item == null or parent_item.is_visible_in_tree()


func _start(rarity: String, artwork: Texture2D, winner_name: String = "") -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_winner_rank = RARITIES.find(rarity)
	if _winner_rank < 0:
		_winner_rank = 2
	_floor_rank = mini(_floor_rank, _winner_rank)
	_winner_name = _strip.names[_winner_rank] if winner_name.is_empty() else winner_name
	_winner_color = MatchPlanningScreen.tower_rarity_color({"rarity": rarity})
	_strip.set_artwork(artwork)
	_strip.rarities.resize(CARD_COUNT)
	for index: int in range(CARD_COUNT):
		_strip.rarities[index] = _rng.randi_range(_floor_rank, RARITIES.size() - 1)
	_strip.rarities[WINNER_INDEX] = _winner_rank
	# Clear every potentially visible landing neighbor before staging one near-miss.
	for index: int in range(WINNER_INDEX - LANDING_RADIUS, WINNER_INDEX + LANDING_RADIUS + 1):
		if index != WINNER_INDEX:
			_strip.rarities[index] = _rng.randi_range(_floor_rank, maxi(_floor_rank, mini(_winner_rank, RARITIES.find("rare"))))
	if _winner_rank < RARITIES.size() - 1:
		var offset: int = _rng.randi_range(1, 2)
		if _rng.randi_range(0, 1) == 0:
			offset = -offset
		var better_rank: int = _rng.randi_range(maxi(RARITIES.find("epic"), _winner_rank + 1), RARITIES.size() - 1)
		_strip.rarities[WINNER_INDEX + offset] = better_rank
	_strip.winner_index = WINNER_INDEX
	_strip.scroll_position = START_POSITION
	_strip.reveal = 0.0
	_strip.flap_angle = 0.0
	_strip.flap_velocity = 0.0
	# Keep the accepted result inside its card; the pointer rests over its face.
	_landing_position = float(WINNER_INDEX) + _rng.randf_range(-0.14, 0.14)
	_peak_speed = (_landing_position - START_POSITION) / (ACCEL_SECONDS * 0.5 + CRUISE_SECONDS + BRAKE_SECONDS / 5.0)
	_elapsed = 0.0
	_revealed = false
	_last_crossing = floori(START_POSITION + 0.5)
	_result.text = ""
	_payout.text = ""
	_payout.visible = not _winner_payout.is_empty()
	_suspended = false
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


func set_suspended(suspended: bool) -> void:
	if not _busy or _suspended == suspended:
		return
	_suspended = suspended
	set_process(not suspended)
	set_process_input(not suspended)
	if suspended:
		_tick.stop()
		_reveal.stop()
		hide()
	else:
		show()
		get_parent().move_child(self, -1)
		_close.grab_focus()


func cancel() -> void:
	var was_busy: bool = _busy
	_busy = false
	_suspended = false
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
	if not _busy or _suspended:
		return
	_elapsed += delta
	if not _revealed:
		var previous_position: float = _strip.scroll_position
		var travel: float = _spin_position(_elapsed)
		# Tooth resistance eases through each release point, most visible at low speed.
		_strip.scroll_position = travel + 0.12 * sin(TAU * travel)
		var crossing: int = floori(_strip.scroll_position + 0.5)
		if crossing != _last_crossing:
			_last_crossing = crossing
			var cards_per_second: float = (_strip.scroll_position - previous_position) / maxf(delta, 0.0001)
			_tick.pitch_scale = lerpf(0.92, 1.08, clampf(cards_per_second / _peak_speed, 0.0, 1.0))
			_tick.volume_db = lerpf(-5.0, -11.0, clampf(cards_per_second / 10.0, 0.0, 1.0))
			_tick.play()
			_strip.release_contact()
		if _elapsed >= SPIN_SECONDS:
			_begin_reveal()
	else:
		_strip.reveal = maxf(_strip.reveal, minf((_elapsed - SPIN_SECONDS) / 0.45, 1.0))
		if _elapsed >= SPIN_SECONDS + REVEAL_SECONDS:
			cancel()
			return
	_strip.advance_flap(delta)
	_strip.queue_redraw()
	queue_redraw()


func _spin_position(elapsed: float) -> float:
	if elapsed >= SPIN_SECONDS:
		return _landing_position
	if elapsed < ACCEL_SECONDS:
		var progress: float = elapsed / ACCEL_SECONDS
		var ramp_area: float = progress * progress * progress * (1.0 - progress * 0.5)
		return START_POSITION + _peak_speed * ACCEL_SECONDS * ramp_area
	var cruise_start: float = START_POSITION + _peak_speed * ACCEL_SECONDS * 0.5
	if elapsed < ACCEL_SECONDS + CRUISE_SECONDS:
		return cruise_start + _peak_speed * (elapsed - ACCEL_SECONDS)
	var progress: float = clampf((elapsed - ACCEL_SECONDS - CRUISE_SECONDS) / BRAKE_SECONDS, 0.0, 1.0)
	var remaining: float = 1.0 - progress
	# Fast early braking leaves time for distinct, progressively slower final teeth.
	return _landing_position - _peak_speed * BRAKE_SECONDS * remaining * remaining * remaining * remaining * remaining / 5.0


func _skip_to_result() -> void:
	if _revealed:
		cancel()
		return
	_tick.stop()
	_strip.flap_angle = 0.0
	_strip.flap_velocity = 0.0
	_begin_reveal()
	_elapsed = SPIN_SECONDS + 0.45
	_strip.reveal = 1.0
	_strip.queue_redraw()
	queue_redraw()


func _begin_reveal() -> void:
	_revealed = true
	# Start the readable hold at the actual reveal, even after a delayed frame.
	_elapsed = SPIN_SECONDS
	_strip.scroll_position = _landing_position + 0.12 * sin(TAU * _landing_position)
	_reveal.pitch_scale = 0.92 + float(_winner_rank) * 0.035
	_reveal.volume_db = -8.0 + float(_winner_rank) * 0.35
	_reveal.play()
	_result.text = _winner_name
	_payout.text = _winner_payout
	_result.add_theme_color_override("font_color", _winner_color)
	_strip.reveal = 0.0
	_strip.queue_redraw()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _busy or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		return # Keep the native close-button hover; the owning screen blocks world motion.
	# Handle actions before dismissal so the same event cannot reach another screen.
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				cancel()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_skip_to_result()
			else:
				_close.grab_focus()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _close.get_global_rect().has_point(event.position):
				cancel()
			else:
				_skip_to_result()
	elif event.is_action_pressed(&"ui_cancel"):
		cancel()
	elif event.is_action_pressed(&"ui_accept"):
		_skip_to_result()


func _gui_input(_event: InputEvent) -> void:
	# Empty overlay space is still modal, including wheel and gesture events.
	accept_event()


func _visibility_changed() -> void:
	# Inherited visibility changes also fire when the owning screen is hidden.
	if _busy and not _suspended and not is_visible_in_tree():
		cancel()


func _exit_tree() -> void:
	cancel()


func _layout() -> void:
	if _panel == null:
		return
	_panel.size = Vector2(minf(1000.0, maxf(0.0, size.x - 64.0)), 382.0 if not _winner_payout.is_empty() else 354.0)
	_panel.position = ((size - _panel.size) * 0.5).floor()
	_heading.position = Vector2(24.0, 18.0)
	_heading.size = Vector2(maxf(0.0, _panel.size.x - 100.0), 40.0)
	_close.position = Vector2(_panel.size.x - 60.0, 18.0)
	_close.size = Vector2(40.0, 40.0)
	_strip.position = Vector2(20.0, 76.0)
	_strip.size = Vector2(maxf(0.0, _panel.size.x - 40.0), 216.0)
	_result.position = Vector2(24.0, 302.0)
	_result.size = Vector2(maxf(0.0, _panel.size.x - 48.0), 28.0 if not _winner_payout.is_empty() else 36.0)
	_payout.position = Vector2(24.0, 334.0)
	_payout.size = Vector2(maxf(0.0, _panel.size.x - 48.0), 28.0)
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
