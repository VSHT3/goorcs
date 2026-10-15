extends SceneTree

const WORDMARK_SCRIPT = preload("res://scripts/menu_wordmark.gd")

var failures: int = 0
var viewport: SubViewport
var menu: Control
var title: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Menu roar regression needs a graphical renderer. Run without --headless.")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	menu = load("res://scenes/main_menu.tscn").instantiate()
	viewport.add_child(menu)
	title = menu.get_node("Center/Panel/Title")
	title.set_process(false)
	await process_frame
	await process_frame
	var title_bounds: Rect2 = title.get_global_rect()
	var button: Button = menu.get_node("Center/Panel/Play")
	var button_bounds: Rect2 = button.get_global_rect()
	var activations: Array[int] = [0]
	button.pressed.connect(func() -> void: activations[0] += 1)

	# Native clicks during assembly cannot restart or replace the one-shot entrance.
	var face_point: Vector2 = title.position + title.get_parent().global_position + title._face_origin() + Vector2(34, 34)
	await _click(face_point)
	_check(title._roar_time < 0.0 and not title._intro_finished, "Startup ignores replay activation without skipping assembly")
	title._process(0.80)
	_check(title._eyes_closed and title._face_pose == WORDMARK_SCRIPT.FacePose.ROARING and title.material != null, "Startup retains its roar and entrance material")
	title._process(2.0)
	_check(title._intro_finished and title.material == null, "Startup finishes once and removes the logo shader")
	var neutral: Image = await _capture()
	var face_origin: Vector2 = title.global_position + title._face_origin()
	face_point = face_origin + Vector2(34, 34)
	var eye_area := Rect2i(Vector2i(face_origin + Vector2(0, 24)), Vector2i(68, 8))
	var g_area := Rect2i(Vector2i(title.global_position + Vector2(title._word_origin_x(), 0)), Vector2i(int(title._g_width), int(title.size.y)))
	var face_width: float = WORDMARK_SCRIPT.FACE_ROWS[0].length() * WORDMARK_SCRIPT.PIXEL
	var suffix_x: float = face_origin.x + face_width + 4.0
	var suffix_area := Rect2i(Vector2i(suffix_x, title.global_position.y), Vector2i(int(title._suffix_width) + 4, int(title.size.y)))

	for point: Vector2 in [Vector2(g_area.get_center()), Vector2(suffix_area.get_center()), title.global_position + Vector2(2, 2), face_origin + Vector2(2, 2)]:
		await _click(point)
		_check(title._roar_time < 0.0, "Other glyphs, title whitespace and transparent face corners do not roar")
		_check(viewport.gui_get_hovered_control() != title, "Only face ink receives the native title cursor and input")
	await _click(face_point, MOUSE_BUTTON_RIGHT)
	_check(title._roar_time < 0.0, "Right click does not replay the roar")
	await _click(face_point)
	_check(viewport.gui_get_hovered_control() == title and title.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Orc face receives native pointer hover")
	_check(title._eyes_closed and title._face_pose == WORDMARK_SCRIPT.FacePose.BRACED, "Real left click immediately braces the face with closed eyes")
	var braced: Image = await _capture()
	_check(neutral.get_region(eye_area).get_data() != braced.get_region(eye_area).get_data(), "Clicked roar visibly closes the eyes")
	title._process(0.30)
	var roaring: Image = await _capture()
	_check(title._face_pose == WORDMARK_SCRIPT.FacePose.ROARING and title._eyes_closed, "Clicked animation opens the roaring jaw and keeps eyes closed")
	var face_area := Rect2i(Vector2i(face_origin - Vector2(0, 2)), Vector2i(int(face_width) + 4, 90))
	_check(roaring.get_region(face_area).get_used_rect().size.y > neutral.get_region(face_area).get_used_rect().size.y, "Rendered roar extends the lower jaw beyond its neutral height")
	_check(neutral.get_region(g_area).get_data() == roaring.get_region(g_area).get_data(), "Roar does not move or redraw the G differently")
	_check(neutral.get_region(suffix_area).get_data() == roaring.get_region(suffix_area).get_data(), "Roar does not move or redraw RCS differently")
	_check(title.material == null and title.get_global_rect() == title_bounds and button.get_global_rect() == button_bounds, "Replay preserves completed shader state and title/button layout")
	await _click(face_point)
	_check(is_equal_approx(title._roar_time, 0.30), "Spam cannot restart a busy roar")
	title._process(0.80)
	_check(title._roar_time < 0.0 and title._face_pose == WORDMARK_SCRIPT.FacePose.NEUTRAL and not title._eyes_closed, "Roar settles back to its neutral open-eyed face")
	await _click(face_point)
	_check(title._roar_time == 0.0, "A settled roar can be activated again")
	title._process(0.30)
	menu.hide()
	_check(title._roar_time < 0.0 and title._face_pose == WORDMARK_SCRIPT.FacePose.NEUTRAL and not title._eyes_closed and not title.is_processing(), "Leaving mid-roar cancels animation and restores neutral")
	menu.show()
	title.set_process(false)
	await process_frame
	_check(title._intro_finished and title.material == null and title._roar_time < 0.0, "Returning neither replays entrance nor resumes interrupted roar")
	await _click(button.get_global_rect().get_center())
	_check(activations[0] == 1 and title._roar_time < 0.0, "Existing native menu button paths remain clickable")
	title._process((WORDMARK_SCRIPT.BLINK_START + WORDMARK_SCRIPT.BLINK_END) * 0.5)
	_check(title._eyes_closed and title._face_pose == WORDMARK_SCRIPT.FacePose.NEUTRAL, "Idle blinking resumes after replay cancellation")
	title._process(WORDMARK_SCRIPT.BLINK_END - title._elapsed + 0.01)
	_check(not title._eyes_closed, "Idle blink reopens normally")
	title._process(WORDMARK_SCRIPT.CYCLE_SECONDS - title._elapsed + (WORDMARK_SCRIPT.IDLE_START + WORDMARK_SCRIPT.IDLE_END) * 0.5)
	_check(title._idle_offset < 0.0 and title._roar_time < 0.0, "Tiny idle lift remains active without replaying the roar")

	# Pointer navigation transfers keyboard focus instead of leaving two selections.
	var workshop: Button = menu.get_node("Center/Panel/Open")
	var collection: Button = menu.get_node("Center/Panel/Collection")
	button.grab_focus()
	for hovered: Button in [workshop, collection, button]:
		var motion := InputEventMouseMotion.new()
		motion.position = hovered.get_global_rect().get_center()
		motion.global_position = motion.position
		viewport.push_input(motion, true)
		await process_frame
		_check(viewport.gui_get_focus_owner() == hovered, "Mouse hover transfers the menu selection")
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_DOWN
		key.pressed = pressed
		viewport.push_input(key, true)
		await process_frame
	_check(viewport.gui_get_focus_owner() == workshop, "Arrow navigation continues from the hovered menu item")

	# Interrupting the first entrance also stays completed on menu return.
	var interrupted: Control = load("res://scenes/main_menu.tscn").instantiate()
	viewport.add_child(interrupted)
	var interrupted_title: Control = interrupted.get_node("Center/Panel/Title")
	interrupted_title.set_process(false)
	interrupted_title._process(0.80)
	interrupted.hide()
	interrupted.show()
	interrupted_title.set_process(false)
	_check(interrupted_title._intro_finished and interrupted_title.material == null and interrupted_title._face_pose == WORDMARK_SCRIPT.FacePose.NEUTRAL, "Leaving during startup permanently cancels its choreography")
	viewport.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: rendered native Orc-O clicks, closed eyes/jaw, glyph isolation, stable layout, spam, repeat and navigation cancellation")
	quit(1 if failures else 0)


func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _click(point: Vector2, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button_index
		event.pressed = pressed
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button_index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		viewport.push_input(event, true)
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
