extends SceneTree

class RecordingAudio extends MenuAudio:
	var actions: int = 0

	func play_action() -> void:
		super.play_action()
		actions += 1

var failures: int = 0
var main: Control
var directory: String
var menu_audio: RecordingAudio

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func _run() -> void:
	root.gui_embed_subwindows = true
	directory = OS.get_temp_dir().path_join("gorcs_navigation_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.combat_rules = CombatRules.new()
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	var original_audio: Node = main.get_node("MenuAudio")
	main.remove_child(original_audio)
	original_audio.free()
	menu_audio = RecordingAudio.new()
	menu_audio.name = "MenuAudio"
	main.add_child(menu_audio)
	main.move_child(menu_audio, 0)
	root.add_child(main)
	var title: Control = main.menu.get_node("Center/Panel/Title")
	title.set_process(false)
	_check(not title._intro_finished, "Initial menu setup does not hide and cancel the startup entrance")
	await process_frame
	await process_frame
	_check(main.menu.visible and main.sandbox_screen == null and main.orcieary_screen == null and main.towerieary_screen == null, "Startup shows menu without constructing inactive playgrounds or guides")
	await _check_menu_focus()
	_check(menu_audio.actions == 0, "Native arrows, Tab and focus changes remain silent")
	await _key(KEY_ENTER)
	_check(main.play_screen.visible and not main.menu.visible, "Keyboard activation opens Play")
	_check(menu_audio.actions == 1, "Native Enter emits one clack, not one per navigation callback")
	await process_frame
	await process_frame
	await _click(main.play_screen.join_button.get_global_rect().get_center())
	await process_frame
	main.play_screen.join_code_input.grab_focus()
	main.play_screen.join_code_input.text = "invalid invite"
	await _key(KEY_ENTER)
	_check(main.session.state == MultiplayerSession.State.ERROR, "Invalid invite retains editable connection form")
	_check(menu_audio.actions == 3, "Pointer Join and submitted Enter each emit exactly one action clack")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and main.session.state == MultiplayerSession.State.IDLE, "Escape leaves connection setup cleanly")
	_check(menu_audio.actions == 4, "Lobby Escape shares the Back action without a duplicate cue")
	await _key(KEY_S)
	var sandbox: SandboxScreen = main.sandbox_screen
	_check(sandbox.visible and not main.menu.visible, "Sandbox shortcut opens actual playground")
	_check(menu_audio.actions == 5, "A main-menu letter shortcut emits exactly one clack")
	await _motion(sandbox.cell_screen_position(Vector2i(1, 4)))
	_check(sandbox.layout.used_tiles() == 0, "Idle sandbox hover cannot edit paths")
	await _button(sandbox.cell_screen_position(Vector2i(1, 4)), true)
	await _motion(sandbox.cell_screen_position(Vector2i(2, 4)))
	_check(sandbox.layout.used_tiles() == 2, "Actual pointer drag edits sandbox")
	_check(menu_audio.actions == 5, "Sandbox path editing does not become menu audio")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not sandbox.visible, "Escape interrupts a path stroke and returns to menu")
	await _button(Vector2(10, 10), false)
	await _key(KEY_ESCAPE)
	await _motion(sandbox.cell_screen_position(Vector2i(3, 4)))
	_check(sandbox.layout.used_tiles() == 2, "Resume cannot continue an interrupted stroke")
	for x: int in range(3, 13):
		await _click(sandbox.cell_screen_position(Vector2i(x, 4)))
	_check(sandbox.layout.is_ready(), "Sandbox accepts a complete route")
	var route: Array = sandbox.layout.route.duplicate()
	await _click(sandbox.menu_button.get_global_rect().get_center())
	await _click(sandbox.cell_screen_position(Vector2i(0, 0)))
	_check(sandbox.layout.route == route and sandbox.layout.used_tiles() == 12, "Hidden sandbox cannot accept edits")
	await _key(KEY_B)
	_check(main.orcieary_screen.visible and not sandbox.visible, "Field guide shortcut opens Orcieary without exposing sandbox")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible, "Orcieary Escape returns to menu")
	_check(menu_audio.actions == 10, "Sandbox Back/Escape, menu resume and Orcieary entry/return each cue once")
	await _check_towerieary(sandbox)
	await _key(KEY_S)
	_check(sandbox.layout.route == route and sandbox.layout.is_ready(), "Sandbox state survives visits to other menus")
	await _check_match_music()
	main.queue_free()
	await create_timer(0.2).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: native menu focus/navigation, connection teardown, sandbox edits/resume, both guides, read-only Towerieary tree pointer/arrows and direct Escape, and match music lifecycle")
	quit(1 if failures else 0)

func _check_match_music() -> void:
	var music: AudioStreamPlayer = main.get_node("MatchMusic")
	_check(not music.playing, "Sandbox stays silent")
	await _key(KEY_ESCAPE)
	await _key(KEY_P)
	await _click(main.play_screen.singleplayer_button.get_global_rect().get_center())
	_check(main.planning.selecting_loadout and not main.planning.active and not music.playing, "Selection stays outside the active match soundtrack lifecycle")
	var leave_cues: int = menu_audio.actions
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not main.play_screen.visible, "Escape leaves the visible loadout chooser for the main menu")
	_check(not main.planning.selecting_loadout and not main.planning.active and not main.planning.singleplayer and main.session.state == MultiplayerSession.State.IDLE, "Leaving loadout selection tears down the pending solo run")
	_check(not music.playing and menu_audio.actions == leave_cues + 1, "Loadout Escape emits one action clack without starting match music")
	await _key(KEY_P)
	await _click(main.play_screen.singleplayer_button.get_global_rect().get_center())
	_check(main.planning.selecting_loadout and not main.planning.loadout_committed and main.play_screen.loadout_panel.visible, "A cancelled loadout can reopen as a fresh selection")
	var browsing_cues: int = menu_audio.actions
	var loadout: LoadoutPanel = main.play_screen.loadout_panel
	await _click(loadout.tower_buttons[&"arrow_tower"].get_global_rect().get_center())
	_check(menu_audio.actions == browsing_cues, "Actual loadout tower-card activation remains silent")
	_check(main.planning.select_loadout([&"arrow_tower"]), "Navigation fixture selects its owned starter")
	await _click(loadout.commit_button.get_global_rect().get_center())
	_check(main.planning.active and menu_audio.actions == browsing_cues + 1, "Native Commit starts the match with exactly one action clack")
	await process_frame
	_check(music.playing, "Match starts local soundtrack")
	music.seek(5.0)
	for x: int in range(1, 13):
		main.planning.request_edit(0, Vector2i(x, 4), true)
	main.planning.submit_ready(true)
	await process_frame
	_check(music.playing and music.get_playback_position() >= 4.0, "Snapshots and wave start do not restart music")
	var pause_cues: int = menu_audio.actions
	await _key(KEY_ESCAPE)
	_check(main.play_screen.planning_screen.pause_menu.visible, "Escape opens active match menu")
	_check(menu_audio.actions == pause_cues + 1, "Escape opening the match menu emits one clack")
	await _click(main.play_screen.planning_screen.pause_menu.quit_button.get_global_rect().get_center())
	_check(main.menu.visible and not music.playing and not main.planning.active, "Quit ends match and stops soundtrack")
	_check(menu_audio.actions == pause_cues + 2, "Native match Quit emits one clack and survives menu navigation")
	await _key(KEY_T)
	_check(main.towerieary_screen.visible and not music.playing and not main.planning.active, "Guide after a match cannot resume gameplay or its soundtrack")
	await _key(KEY_ESCAPE)
	await _key(KEY_S)
	_check(main.sandbox_screen.visible and not music.playing, "Sandbox return does not restart match music")

func _check_menu_focus() -> void:
	var buttons: Array[Button] = []
	for child: Node in main.play_button.get_parent().get_children():
		if child is Button:
			buttons.append(child)
	_check(buttons.size() == 6 and buttons[3] == main.towerieary_button, "Both field guides are discoverable in the six-action menu")
	for button: Button in buttons:
		_check(main.get_global_rect().encloses(button.get_global_rect()), "Every menu action fits the viewport")
	for index: int in range(buttons.size()):
		_check(root.gui_get_focus_owner() == buttons[index], "Down reaches each menu action in display order")
		await _key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == buttons[0], "Down wraps from Quit to Play")
	for index: int in range(buttons.size() - 1, -1, -1):
		await _key(KEY_UP)
		_check(root.gui_get_focus_owner() == buttons[index], "Up reverses every menu link")
	for index: int in range(buttons.size()):
		_check(root.gui_get_focus_owner() == buttons[index], "Tab reaches each menu action in display order")
		await _key(KEY_TAB)
	for index: int in range(buttons.size() - 1, -1, -1):
		await _key(KEY_TAB, true)
		_check(root.gui_get_focus_owner() == buttons[index], "Shift-Tab reverses every menu link")
	await _motion(main.sandbox_button.get_global_rect().get_center())
	_check(root.gui_get_focus_owner() == main.sandbox_button, "Native hover transfers focus without activating an action")
	await _motion(main.play_button.get_global_rect().get_center())
	_check(root.gui_get_focus_owner() == main.play_button, "Hover restores the initial Play selection without an activation cue")

func _check_towerieary(sandbox: SandboxScreen) -> void:
	var sandbox_state: Dictionary = sandbox.controller.state.duplicate(true)
	var route: Array = sandbox.layout.route.duplicate()
	var collection_bytes: PackedByteArray = FileAccess.get_file_as_bytes(directory.path_join("collection.json"))
	var unlocked: Array[StringName] = []
	for reward: TowerReward in main.collection_store.catalog:
		if main.collection_store.is_unlocked(reward.id):
			unlocked.append(reward.id)
	var totals: Dictionary = _enemy_totals()
	var statistics_existed: bool = FileAccess.file_exists(directory.path_join("statistics.json"))
	var match_state: Dictionary = main.planning.combat.duplicate(true)
	var session_state: MultiplayerSession.State = main.session.state
	var session_error: String = main.session.error_message
	_check(session_state in [MultiplayerSession.State.IDLE, MultiplayerSession.State.ERROR] and main.session.get("_peer") == null and not main.session.is_processing(), "Navigation fixture starts disconnected, including a retained connection error")
	await _key(KEY_T)
	var guide: ToweriearyScreen = main.towerieary_screen
	_check(guide != null and guide.visible and not main.menu.visible and not sandbox.visible, "T opens the actual Towerieary without exposing Sandbox")
	if guide == null:
		return
	_check(guide.tower_buttons.size() == main.combat_rules.catalog.towers.size(), "Towerieary includes the entire catalog, including unowned towers")
	_check(guide.tower_buttons.size() > 1, "Guide exposes a selectable tower index")
	var browsing_cues: int = menu_audio.actions
	if guide.tower_buttons.size() > 1:
		await _click(guide.tower_buttons.back().get_global_rect().get_center())
	var selected_type: StringName = guide.selected_type_id
	_check(not main.collection_store.is_unlocked(selected_type), "Native guide navigation can inspect an unowned tower")
	_check(guide.stage_graph.stage_buttons.size() > 1, "Guide exposes real upgrades through its visible diagram")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == guide.stage_graph.stage_buttons[guide.selected_stage_id], "Index Right reaches the selected native upgrade node")
	await _click(guide.stage_graph.stage_buttons["speed"].get_global_rect().get_center())
	_check_towerieary_node(guide, "speed", "Actual pointer input selects the native speed-upgrade node")
	await _key(KEY_UP)
	_check_towerieary_node(guide, "base", "Native Up returns from a stat upgrade to the actual base state")
	await _key(KEY_DOWN)
	_check_towerieary_node(guide, "damage", "Native Down follows the first actual purchase branch")
	await _key(KEY_RIGHT)
	_check_towerieary_node(guide, "speed", "Native Right reaches the other stat-upgrade sibling")
	await _key(KEY_DOWN)
	var selected_stage: String = "damage/speed"
	_check_towerieary_node(guide, selected_stage, "Native Down reaches the combined purchase state and actual preview")
	_check(menu_audio.actions == browsing_cues, "Actual tower switching, upgrade previews, native graph clicks and arrow browsing stay silent")
	await _key(KEY_ESCAPE)
	_check(main.menu.visible and not guide.visible and root.gui_get_focus_owner() == main.towerieary_button, "Escape from the native graph directly returns to the focused Towerieary menu action")
	await _key(KEY_ESCAPE)
	_check(guide.visible and not main.menu.visible and main.towerieary_screen == guide, "Menu Escape resumes the existing guide instance")
	_check(menu_audio.actions == browsing_cues + 2, "Guide Escape and menu resume each cue once")
	_check(guide.selected_type_id == selected_type and guide.selected_stage_id == selected_stage, "Escape resume retains the selected tower and upgrade stage")
	await _key(KEY_TAB)
	_check_towerieary_node(guide, selected_stage, "Resumed index Tab reaches the actual remembered selected node")
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == guide.back_button, "Selected node Tab reaches the compact X")
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == guide.tower_buttons[guide.selected_index], "X Tab wraps to the current tower")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == guide.back_button, "Current tower BackTab returns to X")
	await _key(KEY_TAB, true)
	_check_towerieary_node(guide, selected_stage, "BackTab reverses X to the selected native node")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == guide.tower_buttons[guide.selected_index], "Selected node BackTab returns to the current tower")
	_check(menu_audio.actions == browsing_cues + 2, "Guide Tab/BackTab and focus restoration stay silent")
	await _click(guide.back_button.get_global_rect().get_center())
	_check(main.menu.visible and not guide.visible and root.gui_get_focus_owner() == main.towerieary_button, "Guide X returns to its corresponding focused menu action")
	_check(menu_audio.actions == browsing_cues + 3, "The guide X is an action and emits one clack")
	await _key(KEY_UP)
	_check(root.gui_get_focus_owner() == main.orcieary_button, "Orcieary remains immediately above Towerieary")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(guide.visible and not main.orcieary_screen.visible, "Native menu Enter activates Towerieary rather than its neighbor")
	await _key(KEY_ESCAPE)
	await _click(main.towerieary_button.get_global_rect().get_center())
	_check(guide.visible and guide.selected_type_id == selected_type and guide.selected_stage_id == selected_stage, "Actual main-menu pointer entry preserves guide selection")
	await _key(KEY_ESCAPE)
	await _key(KEY_C)
	_check(main.collection_screen.visible and not guide.visible, "Collection shortcut remains independent of Towerieary")
	await _key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() == main.collection_button, "Collection keeps its own return focus")
	_check(sandbox.controller.state == sandbox_state and sandbox.layout.route == route and sandbox.controller.paused, "Guide navigation leaves the retained Sandbox build and paused state unchanged")
	# Normal menu teardown recreates the inert model's identity, not a run.
	var observed_match: Dictionary = main.planning.combat.duplicate(true)
	match_state.erase("statistics_id")
	observed_match.erase("statistics_id")
	_check(observed_match == match_state and not main.planning.active and not main.planning.selecting_loadout, "Read-only guide preserves inactive match state without starting a run")
	_check(main.session.state == session_state and main.session.error_message == session_error and main.session.get("_peer") == null and not main.session.is_processing(), "Read-only guide preserves the disconnected session without creating a network peer or clearing its existing error")
	_check(not main.get_node("MatchMusic").playing, "Guide and collection navigation remain outside match music")
	for reward: TowerReward in main.collection_store.catalog:
		_check(main.collection_store.is_unlocked(reward.id) == unlocked.has(reward.id), "Guide browsing cannot grant collection ownership")
	_check(FileAccess.get_file_as_bytes(directory.path_join("collection.json")) == collection_bytes, "Guide browsing leaves saved progression bytes untouched")
	_check(_enemy_totals() == totals and FileAccess.file_exists(directory.path_join("statistics.json")) == statistics_existed, "Guide browsing cannot create lifetime records")

func _check_towerieary_node(guide: ToweriearyScreen, stage_id: String, description: String) -> void:
	var button: Button = guide.stage_graph.stage_buttons[stage_id]
	var preview: Dictionary = guide.provider.preview(guide.selected_type_id, stage_id)
	_check(guide.selected_stage_id == stage_id and guide.stage_graph.selected_stage_id == stage_id and button.button_pressed and root.gui_get_focus_owner() == button, description)
	_check(button.get_meta("stage_id") == stage_id and guide.selected_preview["tower"] == preview["tower"], "Native graph interaction presents the actual accepted preview for " + stage_id)

func _enemy_totals() -> Dictionary:
	var totals: Dictionary = {}
	for enemy: EnemyDefinition in main.combat_rules.catalog.enemies:
		totals[enemy.id] = main.statistics_store.counts(enemy.id)
	return totals

func _click(point: Vector2) -> void:
	await _motion(point)
	await _button(point, true)
	await _button(point, false)

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
