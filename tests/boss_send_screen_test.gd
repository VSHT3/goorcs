extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	var directory: String = OS.get_temp_dir().path_join("gorcs_boss_send_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	main.combat_rules = CombatRules.new()
	root.add_child(main)
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	planning.set_physics_process(false)
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Fixture completes the hero draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Boss-send UI fixture admits an ordinary mirrored run")
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	for type_id: String in ["necorcmancer_mancer", "troll", "orc_war_machine"]:
		var terms: Dictionary = planning.combat["enemy_types"][type_id]
		var cost: int = int(terms["send_cost"])
		var penalty: int = -int(terms["send_income"])
		_check(planning.debug_set_values(int(terms["send_first_wave"]), cost, 0), "Normal host debug command selects paid-boss unlock")
		var index: int = -1
		for entry: int in range(screen.enemy_selector.item_count):
			if String(screen.enemy_selector.get_item_metadata(entry)) == type_id:
				index = entry
		_check(index >= 0, "Boss is visible in the normal send selector")
		if index < 0:
			continue
		screen.enemy_selector.select(index)
		screen.enemy_selector.item_selected.emit(index)
		_check(not screen.enemy_selector.is_item_disabled(index) and screen.send_button.disabled, "Unlocked boss stays selectable when recurring income cannot pay its penalty")
		_check(screen.send_button.text.contains(str(cost)) and screen.send_button.text.get_slice("/", 1).to_int() == -penalty, "Send action exposes current accepted Coin price and signed recurring-income loss")
		planning._host_combat.income = [penalty, penalty]
		planning._publish_snapshot()
		_check(String(screen._selected_enemy_type) == type_id and not screen.send_button.disabled, "Funding income enables the selected boss without resetting selection")
		_check(planning.debug_set_values(int(terms["send_first_wave"]) + 200, cost, 0), "Host can progress beyond the boss's send unlock")
		_check(String(screen._selected_enemy_type) == type_id and not screen.enemy_selector.is_item_disabled(index) and not screen.send_button.disabled, "Selected boss remains visible, selectable and funded far into late game")
		planning._host_combat.coins = [cost - 1, cost - 1]
		planning._publish_snapshot()
		_check(screen.send_button.disabled and String(screen._selected_enemy_type) == type_id, "Insufficient Coins disables purchase without hiding selected boss")
		planning._host_combat.coins = [cost, cost]
		planning._publish_snapshot()
		screen.send_button.pressed.emit()
		_check(planning.combat["coins"] == [0, 0] and planning.combat["income"] == [0, 0] and planning.combat["send_queues"] == [[type_id], [type_id]], "Actual UI action uses the mirrored host transaction for exact Coins, income and FIFO effects")
		_check(screen.send_button.disabled and String(screen._selected_enemy_type) == type_id and not screen.enemy_selector.is_item_disabled(index), "Spent boss stays selected and offered while unaffordable")
	main.play_screen.prepare_to_leave()
	for player: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	await create_timer(0.1).timeout
	main.queue_free()
	main = null
	planning = null
	screen = null
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: boss selector visibility, signed price/loss, independent Coin/income affordability and actual mirrored UI purchase")
	quit.call_deferred(1 if failures > 0 else 0)
