extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _run() -> void:
	var directory := OS.get_temp_dir().path_join("gorcs_results_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var main = load("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	main.combat_rules = CombatRules.new()
	root.add_child(main)
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	check(planning.selecting_loadout and not planning.active and not screen.is_visible_in_tree(),"Singleplayer presents loadout selection before the battlefield")
	check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(),"Result fixture commits its owned starter")
	var run_id: String = planning.combat["statistics_id"]
	screen.enemy_selector.get_popup().popup()
	planning._host_combat.base_health = [0,5]
	planning._host_combat.winner = 1
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._publish_snapshot()
	await process_frame
	check(screen.results_menu.visible and not screen.pause_menu.visible and not paused,"Terminal run opens a real result overlay without tree-pause leakage")
	check(not screen.enemy_selector.get_popup().visible,"Terminal overlay closes an open selector so it cannot steal keyboard or pointer input")
	check(screen.results_menu.replay_button.visible and screen.results_menu.replay_button.has_focus(),"Solo result offers focused fresh-run action")
	for width: int in [1000,1280]:
		root.size = Vector2i(width,720)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		for button: Button in [screen.results_menu.replay_button,screen.results_menu.inspect_button,screen.results_menu.menu_button]: check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"Result actions fit both supported desktop sizes")
	var frozen: Dictionary = planning.combat.duplicate(true)
	planning.build_tower(0,Vector2i(2,3),&"arrow_tower",0)
	planning.submit_ready(true)
	check(planning.combat==frozen,"Visible defeat screen does not waive terminal command rejection")
	screen.results_menu.inspect_button.pressed.emit()
	check(not screen.results_menu.visible and planning.active,"View battlefield dismisses only the local overlay, not the run")
	planning._publish_snapshot()
	check(not screen.results_menu.visible,"Repeated terminal snapshots never reopen dismissed results or steal focus")
	screen.ready_button.pressed.emit()
	check(screen.results_menu.visible,"Results HUD action reopens terminal details")
	screen.results_menu.replay_button.pressed.emit()
	check(planning.selecting_loadout and not planning.active and not screen.results_menu.visible,"Play again returns to fresh loadout selection instead of bypassing admission")
	check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(),"Replay explicitly chooses and commits again")
	check(planning.singleplayer and planning.active and planning.combat["phase"]==MatchCombat.Phase.PLANNING and planning.combat["wave"]==0 and planning.combat["statistics_id"]!=run_id and not screen.results_menu.visible,"Play again creates a fresh solo model and clears results lifecycle")
	check(planning.combat["speed_multiplier"]==1.0 and planning.layouts[0].used_tiles()==0,"Replay resets speed and maze rather than restarting the finished instance")
	planning._host_combat.base_health = [5,0]
	planning._host_combat.winner = 0
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._publish_snapshot()
	check(screen.results_menu.visible,"New terminal run presents its own outcome")
	planning.singleplayer = false
	main.session.is_host = true
	screen.open_results()
	check(not screen.results_menu.replay_button.visible,"Multiplayer results never offer a fake local-only rematch")
	screen.results_menu.menu_button.pressed.emit()
	check(main.menu.visible and not planning.active and main.session.state==MultiplayerSession.State.IDLE and not screen.results_menu.is_visible_in_tree(),"Main menu tears down the connection and result modal")
	main.queue_free()
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures==0: print("PASS: result modal, compact keyboard actions, terminal gates, inspect/reopen, snapshot deduplication, fresh solo replay and multiplayer leave")
	quit(1 if failures else 0)
