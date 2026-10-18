extends SceneTree

var failures: int = 0
var directory: String
var main: Control
var planning: MatchPlanning
var screen: MatchPlanningScreen


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	await _test_reel()
	_test_history_cursor()
	await _test_planning_consumer()
	main.queue_free()
	await create_timer(0.25).timeout
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: accepted boss payout reel, detached per-run/slot queues, pending-reroll serialization, duplicate suppression, modal deferral and safe results/replay/leave")
	quit(1 if failures else 0)


func _award(id: int, rarity: String = "rare") -> Dictionary:
	var tiers: Array[Dictionary] = []
	for index: int in range(RarityReel.RARITIES.size()):
		var tier_id: String = RarityReel.RARITIES[index]
		tiers.append({"id": tier_id, "title": tier_id.capitalize(), "weight": float(index + 1), "coins": 137 * (index + 1), "shards": 3 * (index + 1)})
	# Accepted totals deliberately differ from the decorative tier table.
	return {"id": id, "boss_id": "orc_king", "boss_title": "Orc king war orchine", "rarity": rarity, "rarity_title": rarity.capitalize(), "coins": 9876 + id, "shards": 247 + id, "round": 120, "time": float(id), "tiers": tiers}


func _test_reel() -> void:
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var focus := Button.new()
	host.add_child(focus)
	focus.grab_focus()
	var reel := RarityReel.new()
	host.add_child(reel)
	var completions: Array[int] = []
	reel.finished.connect(func() -> void: completions.append(1))
	var award: Dictionary = _award(1)
	var frozen: Dictionary = award.duplicate(true)
	reel.present_reward(award)
	_check(reel.is_busy() and reel.is_visible_in_tree() and reel._close.has_focus(), "Accepted reward owns the shared reel and keyboard focus")
	var winner: int = RarityReel.RARITIES.find(award["rarity"])
	_check(reel._strip.rarities[RarityReel.WINNER_INDEX] == winner, "The strip lands on the accepted reward rather than a cosmetic random card")
	for tier: Dictionary in award["tiers"]:
		var rank: int = RarityReel.RARITIES.find(tier["id"])
		_check(reel._strip.names[rank] == tier["title"] and reel._strip.coins[rank].contains(str(tier["coins"])) and reel._strip.shards[rank].contains(str(tier["shards"])), "Every reward card consumes its supplied tier title and both scaled payouts")
		for value: String in [reel._strip.coins[rank], reel._strip.shards[rank]]:
			_check(reel._strip.NUMBERS.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= reel._strip.CARD_WIDTH - 12.0, "Whole payout text fits the reward card without clipping")
	reel.present({"rarity": "mythic"}, null)
	_check(reel._strip.rarities[RarityReel.WINNER_INDEX] == winner, "A competing tower presentation cannot replace an active accepted reward")
	reel._process(RarityReel.SPIN_SECONDS + 10.0)
	_check(reel.is_busy() and reel._revealed, "A delayed spin frame still reveals the accepted winner and starts a readable hold")
	_check(reel._result.text.contains(award["rarity_title"]) and reel._payout.text.contains(str(award["coins"])) and reel._payout.text.contains(str(award["shards"])) and reel._heading.text.contains(award["boss_title"]), "Revealed title and totals come from the accepted award, not its decorative payout table")
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		root.content_scale_size = root.size
		await _settle()
		var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
		_check(viewport.encloses(Rect2(reel._panel.global_position, reel._panel.size)), "Reward panel fits the supported desktop viewport")
		for label: Label in [reel._heading, reel._result, reel._payout]:
			_check(Rect2(reel._panel.global_position, reel._panel.size).encloses(label.get_global_rect()) and label.get_minimum_size().y <= label.size.y, "Boss and accepted winner labels remain fully readable within the panel")
			for line: String in label.text.split("\n"):
				_check(label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "Accepted boss/winner text fits at both supported widths")
	reel.set_suspended(true)
	var elapsed: float = reel._elapsed
	reel._process(100.0)
	await _settle()
	_check(reel.is_busy() and not reel.is_visible_in_tree() and reel._elapsed == elapsed and not reel._tick.playing and not reel._reveal.playing, "Higher-priority modals hide and freeze presentation without consuming the reward")
	reel.set_suspended(false)
	_check(reel.is_visible_in_tree() and reel._close.has_focus() and reel._elapsed == elapsed, "Resuming retains the accepted winner and its reveal hold")
	reel._process(RarityReel.REVEAL_SECONDS + 0.1)
	_check(not reel.is_busy() and completions.size() == 1 and award == frozen, "Automatic reveal completion emits once and never mutates the award")
	reel.cancel()
	_check(completions.size() == 1, "Repeated close cannot finish or grant an accepted reward twice")
	reel.present({"rarity": "mythic"}, null)
	_check(reel.is_busy() and reel._strip.coins.is_empty() and reel._strip.shards.is_empty() and reel._winner_payout.is_empty() and not reel._payout.visible, "Ordinary tower rerolls reset all reward-only presentation")
	reel._process(RarityReel.SPIN_SECONDS)
	_check(reel._winner_rank == RarityReel.RARITIES.find("mythic") and not reel._result.text.contains(str(award["coins"])), "The same reveal pipeline still presents an ordinary accepted tower rarity")
	await _key(KEY_ESCAPE)
	_check(not reel.is_busy() and focus.has_focus() and completions.size() == 2, "Escape safely closes the reel and restores the prior visible focus")
	for reward_mode: bool in [false, true]:
		reel.present_reward(award) if reward_mode else reel.present({"rarity": "legendary"}, null)
		await _key(KEY_ENTER)
		_check(reel.is_busy() and reel._revealed and reel._strip.reveal == 1.0, "Enter skips either reel to the accepted, fully visible result without closing")
		_check(award == frozen, "Skipping presentation cannot change accepted rewards")
		reel.cancel()
		reel.present_reward(award) if reward_mode else reel.present({"rarity": "epic"}, null)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		mouse.position = Vector2(10, 10)
		Input.parse_input_event(mouse)
		await process_frame
		mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = Vector2(10, 10)
		Input.parse_input_event(mouse)
		await process_frame
		_check(reel.is_busy() and reel._revealed and reel._payout.visible == reward_mode, "Pointer click skips either spin and leaves the actual reward visible")
		reel.cancel()
	host.queue_free()
	await process_frame


func _test_history_cursor() -> void:
	var presenter := BossRewardPresenter.new()
	var first: Dictionary = _award(1)
	var second: Dictionary = _award(2, "epic")
	var snapshot := {"statistics_id": "first", "boss_rewards": [[first], [second]]}
	_check(presenter.observe(snapshot, 1) and presenter.pending_count() == 1, "A new run selects only the local slot's accepted history")
	_check(not presenter.observe(snapshot, 1) and presenter.pending_count() == 1, "Repeated identical snapshots do not enqueue duplicate rewards")
	snapshot["boss_rewards"][1].append(_award(3))
	presenter.observe(snapshot, 1)
	_check(presenter.pending_count() == 2, "A cumulative snapshot queues every newly accepted reward")
	_check(presenter.observe(snapshot, 0) and presenter.pending_count() == 1, "Changing the local slot discards the preceding slot's queue and cursor")
	snapshot["statistics_id"] = "second"
	_check(presenter.observe(snapshot, 0) and presenter.pending_count() == 1, "A new match can present the same numeric award ID without inheriting old duplicate state")
	presenter.clear()
	_check(presenter.pending_count() == 0, "Leaving clears the scene-local queue")
	presenter.observe({"statistics_id": "sandbox", "rules": {"sandbox_mode": true}, "boss_rewards": [[first], []]}, 0)
	_check(presenter.pending_count() == 0, "Sandbox snapshots cannot start boss jackpot presentation")


func _test_planning_consumer() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_reward_reel_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	main.combat_rules = CombatRules.new()
	main.combat_rules.roll_rules = preload("res://resources/combat/tower_rolls.tres")
	main.combat_rules.starting_coins = 100000
	main.combat_rules.starting_reroll_currency = 10000
	root.add_child(main)
	await _settle()
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	planning = main.planning
	screen = main.play_screen.planning_screen
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Reward fixture enters an admitted real solo match")
	planning.set_physics_process(false)
	await _settle()
	planning.build_tower(0, Vector2i(3, 3), &"arrow_tower", MatchCombat.TargetMode.CLOSEST)
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	await _settle()
	var reel: RarityReel = screen._rarity_reel
	var reels: int = 0
	for child: Node in screen.get_children():
		if child is RarityReel:
			reels += 1
	_check(reels == 1 and not screen.rarity_reroll.disabled, "Planning owns exactly one available reel shared by tower rerolls and boss rewards")
	var first: Dictionary = _award(1)
	var second: Dictionary = _award(2, "epic")
	var history: Array[Dictionary] = [first, second]
	var stale: Dictionary = planning.combat.duplicate(true)
	# Deliver a real accepted command separately from observing its response,
	# as happens while a remote rarity-reroll request is still pending.
	planning.changed.disconnect(screen._refresh)
	screen.rarity_reroll.pressed.emit()
	_check(screen._pending_rarity_id >= 0 and planning._host_combat.towers[0][0]["rarity_rerolls"] == 1, "Real reroll acceptance can remain pending at the presentation consumer")
	planning.combat = stale
	planning.combat["boss_rewards"] = [history.duplicate(true), [_award(99)]]
	planning.changed.connect(screen._refresh)
	planning.changed.emit()
	_check(not reel.is_busy() and screen._boss_rewards.pending_count() == 2 and screen._pending_rarity_id >= 0, "A reward waits behind the outstanding rarity response instead of stealing its one reel")
	var accepted: Dictionary = planning._host_combat.snapshot()
	var random_before: Dictionary = _random_states(planning._host_combat)
	_publish_rewards(history)
	_check(reel.is_busy() and reel._winner_payout.is_empty() and screen._boss_rewards.pending_count() == 2 and screen._pending_rarity_id == -1, "Accepted rarity response presents first while both boss awards remain queued")
	reel.cancel()
	await _settle()
	_check(reel.is_busy() and reel._winner_name == first["rarity_title"] and screen._boss_rewards.pending_count() == 1 and not paused, "Finishing the rarity reel starts only the first boss award without pausing simulation")
	var detached: Dictionary = planning.combat.duplicate(true)
	screen.open_pause_menu()
	_check(paused and screen.pause_menu.visible and reel.is_busy() and not reel.is_visible_in_tree(), "Solo Pause remains usable and defers an active boss presentation")
	var third: Dictionary = _award(3, "legendary")
	history.append(third)
	_publish_rewards(history)
	var paused_elapsed: float = reel._elapsed
	await _settle()
	_check(screen._boss_rewards.pending_count() == 2 and reel._elapsed == paused_elapsed and screen.pause_menu.visible, "Awards accepted while a modal is open remain queued without advancing the hidden reel")
	screen.pause_menu.resume_button.pressed.emit()
	_check(not paused and reel.is_visible_in_tree() and reel._winner_name == first["rarity_title"], "Resume restores the interrupted reward rather than consuming or replacing it")
	await _key(KEY_ESCAPE)
	_check(not screen.pause_menu.visible and reel.is_busy() and reel._winner_name == second["rarity_title"] and screen._boss_rewards.pending_count() == 1, "Escape dismisses exactly one reward, advances the queue and never opens Pause")
	# The queued copy must survive arbitrary later edits of detached UI snapshots.
	planning.combat["boss_rewards"][0][2]["coins"] = -777
	planning.combat["boss_rewards"][0][2]["tiers"][0]["coins"] = -888
	await _click(reel._close)
	await _settle()
	reel._process(RarityReel.SPIN_SECONDS)
	_check(reel._winner_name == third["rarity_title"] and reel._payout.text.contains(str(third["coins"])) and not reel._payout.text.contains("-777") and not reel._strip.coins[0].contains("-888"), "X advances to the detached accepted award, not later mutable snapshot contents")
	reel._process(RarityReel.REVEAL_SECONDS + 0.1)
	await _settle()
	_publish_rewards(history)
	_check(not reel.is_busy() and screen._boss_rewards.pending_count() == 0, "Automatic completion and repeated cumulative snapshots cannot replay consumed awards")
	_check(planning._host_combat.snapshot() == accepted and _random_states(planning._host_combat) == random_before, "Queue, spin, suspend, Escape, X and completion change neither accepted gameplay nor any gameplay RNG")
	_check(detached["boss_rewards"][0][0] == first, "Presentation leaves previously detached reward snapshots intact")
	await _test_modal_results_and_replay(history)


func _test_modal_results_and_replay(history: Array[Dictionary]) -> void:
	var reel: RarityReel = screen._rarity_reel
	planning.singleplayer = false
	main.session.is_host = true
	history.append(_award(4, "mythic"))
	_publish_rewards(history)
	screen.open_pause_menu()
	_check(screen.pause_menu.visible and not paused and reel.is_busy() and not reel.is_visible_in_tree(), "Online Pause defers reward UI but never pauses the shared simulation tree")
	history.append(_award(5, "broken"))
	_publish_rewards(history)
	_check(screen._boss_rewards.pending_count() == 1 and not paused, "An accepted online reward remains queued behind the local pause menu")
	screen.pause_menu.resume_button.pressed.emit()
	reel.cancel()
	await _settle()
	_check(reel.is_busy() and reel._winner_name == history[-1]["rarity_title"], "Closing the online menu preserves reward ordering")
	planning.singleplayer = true
	var model: MatchCombat = planning._host_combat
	model.base_health = [0, 5]
	model.winner = 1
	model.phase = MatchCombat.Phase.FINISHED
	history.append(_award(6, "uncommon"))
	_publish_rewards(history)
	await _settle()
	_check(screen.results_menu.visible and not paused and reel.is_busy() and not reel.is_visible_in_tree() and screen._boss_rewards.pending_count() == 1, "Results take modal priority while retaining both active and queued accepted rewards")
	var frozen: Dictionary = model.snapshot()
	var random_before: Dictionary = _random_states(model)
	await _key(KEY_ESCAPE)
	_check(not screen.results_menu.visible and reel.is_visible_in_tree() and screen._boss_rewards.pending_count() == 1, "View battlefield via Escape permits deferred reward presentation without reopening results")
	screen.open_results()
	await _settle()
	_check(screen.results_menu.replay_button.has_focus() and not reel.is_visible_in_tree(), "Reopened results retain keyboard focus above the interrupted reel")
	_check(model.snapshot() == frozen and _random_states(model) == random_before, "Result modal deferral does not modify accepted rewards, terminal state or RNG")
	await _key(KEY_ENTER)
	_check(planning.selecting_loadout and not planning.active and not screen.results_menu.visible and not reel.is_busy() and screen._boss_rewards.pending_count() == 0, "Keyboard Play again safely clears old presentation and returns to fresh loadout selection")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Replay admits a fresh run explicitly")
	planning.set_physics_process(false)
	_publish_rewards([_award(1), _award(2)])
	_check(reel.is_busy() and screen._boss_rewards.pending_count() == 1, "A fresh run accepts reused reward IDs and has no old cursor or queued payout")
	screen._quit_match()
	await _settle()
	_check(main.menu.visible and not planning.active and not reel.is_busy() and screen._boss_rewards.pending_count() == 0 and not paused, "Leaving discards active and queued presentation without trapping menu navigation or tree pause")


func _publish_rewards(history: Array[Dictionary]) -> void:
	planning.combat = planning._host_combat.snapshot()
	planning.combat["boss_rewards"] = [history.duplicate(true), [_award(99)]]
	planning.changed.emit()


func _random_states(owner: Object) -> Dictionary:
	var states: Dictionary = {}
	for property: Dictionary in owner.get_property_list():
		var value: Variant = owner.get(property["name"])
		if value is RandomNumberGenerator:
			states[property["name"]] = value.state
		elif value is BossRewardLedger:
			states[property["name"]] = _random_states(value)
	return states


func _settle() -> void:
	await process_frame
	await process_frame


func _click(control: Control) -> void:
	var point: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()
