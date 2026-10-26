extends SceneTree
## Speed button: solo cycles 1×/2×/3× directly; in multiplayer clicks vote 2×
## (>>), then 3× (>>>), then off, and 3× only turns green once both players pick it.

const NORMAL := "speed_normal.svg"
const DOUBLE := "speed_double.svg"
const TRIPLE := "speed_triple.svg"
const AGREED := Color("b5e2b7")
const PENDING := Color("e0bc77")

var failures: int = 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_pacing_button_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path := directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": []}))
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.combat_rules = CombatRules.new()
	main.combat_rules.roll_rules = null
	root.add_child(main)
	await process_frame
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "A run starts")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var button: Button = screen.speed_button
	for expected: Array in [[DOUBLE, 2.0], [TRIPLE, 3.0], [NORMAL, 1.0]]:
		button.pressed.emit()
		_check(_icon(button) == expected[0] and planning.combat["speed_multiplier"] == expected[1], "Solo clicks cycle 1× / 2× / 3× directly")
	# The same host now applies the multiplayer rule: each slot votes only for itself.
	planning.singleplayer = false
	var me: int = planning.local_slot()
	var them: int = 1 - me
	var cycle: Array = []
	for click: int in range(3):
		var request: Array = MatchPlanningScreen.pacing_request("speed", planning.combat, me)
		cycle.append(request)
		planning._apply_pacing(request[0], me, request[1])
	_check(cycle == [["speed", true], ["triple_speed", true], ["speed", false]], "Multiplayer clicks vote 2×, then 3×, then off: %s" % str(cycle))
	_check(planning.combat["speed_votes"] == [false, false] and planning.combat["triple_speed_votes"] == [false, false] and _icon(button) == NORMAL, "The third click withdraws both votes")
	planning._apply_pacing("triple_speed", me, true)
	_check(_icon(button) == TRIPLE and _color(button) == PENDING and button.tooltip_text.contains("3× speed") and button.tooltip_text.contains("Waiting for opponent"), "A lone 3× vote shows >>> in gold: %s" % button.tooltip_text)
	planning._apply_pacing("speed", them, true)
	_check(planning.combat["speed_multiplier"] == 2.0 and _icon(button) == TRIPLE and _color(button) == PENDING and button.tooltip_text.contains("Running at 2×"), "Against a 2× vote the match runs at 2× while >>> stays gold: %s" % button.tooltip_text)
	planning._apply_pacing("triple_speed", them, true)
	_check(planning.combat["speed_multiplier"] == 3.0 and _icon(button) == TRIPLE and _color(button) == AGREED and button.tooltip_text.contains("· On"), "Both 3× votes turn >>> green at 3×: %s" % button.tooltip_text)
	planning._apply_pacing("triple_speed", me, false)
	_check(planning.combat["speed_multiplier"] == 2.0 and _icon(button) == DOUBLE and _color(button) == AGREED and button.tooltip_text.contains("Click again for 3× speed") and button.tooltip_text.contains("Opponent picked 3×"), "Stepping back shows >> at an agreed 2× and the opponent's 3× pick: %s" % button.tooltip_text)
	planning.singleplayer = true
	planning.stop_singleplayer()
	# Let the last button click finish playing before its player is freed.
	await create_timer(MenuAudio.CLACK.get_length() + 0.5).timeout
	main.queue_free()
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: speed button solo cycle, multiplayer >> / >>> / off votes, gold until both pick 3×, and agreed 2× fallback")
	quit(1 if failures else 0)


func _icon(button: Button) -> String:
	return button.icon.resource_path.get_file() if button.icon != null else ""


func _color(button: Button) -> Color:
	return button.get_theme_color("icon_normal_color")
