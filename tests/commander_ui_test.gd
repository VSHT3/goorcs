extends SceneTree

const NO_CELL := Vector2i(-1, -1)
const UPPER := Vector2i(5, 1)
const LOWER := Vector2i(5, 2)
const LANDMARK := Vector2i(5, 3)

var failures: int = 0
var main: Control
var planning: MatchPlanning
var screen: MatchPlanningScreen
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	directory = OS.get_temp_dir().path_join("gorcs_commander_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": []}))
	main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.combat_rules = CombatRules.new()
	main.combat_rules.roll_rules = null
	root.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	planning = main.planning
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Native commander UI fixture completes the real solo draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Native commander UI fixture starts an accepted run")
	screen = main.play_screen.planning_screen
	_seed_terrain()
	await _settle()

	await _click(screen.world.cell_screen_position(0, LOWER))
	_check(_selected(LOWER) and screen.obstacle_clear_button.is_visible_in_tree() and not screen.obstacle_clear_button.disabled, "Clicking the lower of adjacent rubble cells selects an available paid Clear action")
	planning._publish_snapshot()
	planning._publish_snapshot()
	await _settle()
	_check(_selected(LOWER) and screen.obstacle_clear_button.is_visible_in_tree(), "Repeated ordinary accepted snapshots preserve the same terrain selection")

	# Reset the real authority without publishing its empty intermediate state;
	# the first accepted new-run frame deliberately has the same selected cell.
	var previous_run: String = planning.combat["statistics_id"]
	var previous_origin: int = planning.combat["board_origin_y"]
	var loadouts: Array[Array] = planning._host_loadouts.duplicate(true)
	var commander_ids: Array[StringName] = planning._host_commander_ids.duplicate()
	planning._reset_match()
	planning.singleplayer = true
	planning.active = true
	planning._host_loadouts = loadouts
	planning._host_loadout_committed = [true, true]
	planning._host_commander_ids = commander_ids
	_seed_terrain()
	await _settle()
	_check(planning.combat["statistics_id"] != previous_run and planning.combat["board_origin_y"] == previous_origin, "Real authority reset changes the run identity without changing the board origin")
	_check(_selected(NO_CELL) and not screen._commander_panel.is_visible_in_tree(), "A new run cannot inherit the previous run's matching rubble coordinate")
	_assert_stale_clear_inert("New-run stale clearing cannot spend Coins or remove matching terrain")

	await _click(screen.world.cell_screen_position(0, LOWER))
	_check(_selected(LOWER), "The lower rubble is explicitly reselected in the new run")
	_grow(2)
	await _settle()
	_check(planning.combat["board_origin_y"] == -1 and planning._host_combat.commanders[0]["obstacles"] == [UPPER + Vector2i.DOWN, LOWER + Vector2i.DOWN], "Real host growth shifts both adjacent obstacles while the upper enters the old lower coordinate")
	_check(_selected(NO_CELL) and not screen._commander_panel.is_visible_in_tree(), "Growth invalidates rubble selection before the old coordinate can retarget its upper neighbor")
	_assert_stale_clear_inert("Stale rubble Clear cannot remove its different upper neighbor or charge Coins after growth")

	var landmark: Vector2i = LANDMARK + Vector2i.DOWN
	await _click(screen.world.cell_screen_position(0, landmark))
	_check(_selected(landmark) and screen._commander_panel.is_visible_in_tree() and not screen.obstacle_clear_button.is_visible_in_tree(), "Selecting the landmark presents inspection without a paid Clear action")
	planning._publish_snapshot()
	await _settle()
	_check(_selected(landmark), "An ordinary snapshot also preserves landmark selection")
	_grow(3)
	await _settle()
	_check(planning._host_combat.commanders[0]["obstacles"].has(landmark), "Second real growth puts rubble at the former landmark coordinate")
	_check(_selected(NO_CELL) and not screen._commander_panel.is_visible_in_tree(), "Growth cannot turn selected landmark inspection into a paid rubble action")
	_assert_stale_clear_inert("Stale landmark Clear cannot spend Coins or remove the rubble shifted into its old coordinate")

	var shifted_lower: Vector2i = LOWER + Vector2i.DOWN * 2
	await _click(screen.world.cell_screen_position(0, shifted_lower))
	_check(_selected(shifted_lower) and screen.obstacle_clear_button.is_visible_in_tree(), "Fresh post-growth selection restores Clear only for the explicitly selected rubble")
	var coins: int = planning._host_combat.coins[0]
	await _click(screen.obstacle_clear_button.get_global_rect().get_center())
	_check(planning._host_combat.coins[0] == coins - CommanderRules.CLEAR_COST and planning._host_combat.commanders[0]["obstacles"] == [UPPER + Vector2i.DOWN * 2], "A fresh native Clear click charges exactly once and removes only the newly selected lower rubble")

	planning.stop_singleplayer()
	await create_timer(MenuAudio.CLACK.get_length() + 0.5).timeout
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: native terrain selection survives normal snapshots, resets across runs and growth, never retargets paid clearing, and fresh clearing remains usable")
	quit(1 if failures else 0)


func _seed_terrain() -> void:
	var states: Array[Dictionary] = []
	for id: StringName in planning._host_commander_ids:
		states.append({"id": String(id), "landmark": LANDMARK, "obstacles": [UPPER, LOWER] as Array[Vector2i], "ability_remaining": 0.0, "cooldown_remaining": 0.0, "ability_target": -1})
	planning._host_combat.configure_commanders(states)
	planning._host_combat.coins = [100, 100]
	planning._publish_snapshot()


func _grow(main_round: int) -> void:
	planning._grow_to_round(planning.combat_rules.main_round_interval * main_round)
	planning._publish_snapshot()


func _selected(cell: Vector2i) -> bool:
	return screen._selected_terrain == cell and screen.boards[0].selected_terrain == cell


func _assert_stale_clear_inert(message: String) -> void:
	var before: Dictionary = planning._host_combat.snapshot()
	# Exercise the real connected handler even if an old press was queued before refresh.
	screen.obstacle_clear_button.pressed.emit()
	_check(planning._host_combat.snapshot() == before, message)


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	for index: int in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
