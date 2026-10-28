extends SceneTree

var failures: int = 0
var viewport: SubViewport
var backdrop: ColorRect
var accepted_details: Label
var reel: RarityReel
var audio_playbacks: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rarity reel concealment requires a graphical renderer")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new()
	host.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accepted_details = Label.new()
	accepted_details.position = Vector2(8, 8)
	accepted_details.add_theme_font_size_override("font_size", 24)
	host.add_child(accepted_details)
	reel = RarityReel.new()
	host.add_child(reel)
	for dimensions: Vector2i in [Vector2i(1000, 720), Vector2i(1280, 720), Vector2i(1568, 921), Vector2i(1920, 1080), Vector2i(2560, 720), Vector2i(720, 1000)]:
		viewport.size = dimensions
		await process_frame
		for reward_mode: bool in [false, true]:
			if reward_mode:
				reel.present_reward(_award())
			else:
				reel.present({"rarity": "epic"}, null)
			reel.set_process(false)
			_check(reel.get_global_rect() == Rect2(Vector2.ZERO, Vector2(dimensions)), "Shared reel covers the complete viewport after resizing")
			_check(not reel._revealed and reel._result.text.is_empty() and reel._payout.text.is_empty(), "Actual result labels stay empty while the reel starts spinning")
			await _check_concealed("spin start")
			reel._process(RarityReel.SPIN_SECONDS - 0.01)
			_check(not reel._revealed, "Continuous braking does not reveal the result before stopping")
			await _check_concealed("last braking frame")
			reel._process(0.02)
			_check(reel._revealed and reel._result.text == "Epic", "Stopping reveals the accepted rarity, not a decorative neighboring card")
			await _check_concealed("reveal hold")
			reel.cancel()
	# Higher-priority modal suspension must still hide the whole reel and freeze it.
	reel.present({"rarity": "epic"}, null)
	reel.set_process(false)
	var elapsed: float = reel._elapsed
	reel.set_suspended(true)
	backdrop.color = Color.WHITE
	var suspended: Image = await _capture()
	_check(reel.is_busy() and not reel.is_visible_in_tree() and suspended.get_pixel(0, 0).is_equal_approx(Color.WHITE), "Suspending removes concealment with the reel so the higher-priority screen can show")
	reel._process(100.0)
	_check(reel._elapsed == elapsed, "Suspending preserves the accepted presentation clock")
	reel.set_suspended(false)
	reel.set_process(false)
	await _check_concealed("resumed spin")
	reel._skip_to_result()
	_check(reel.is_busy() and reel._revealed and reel._result.text == "Epic", "Skip holds the actual result rather than dismissing it")
	await _check_concealed("skipped reveal")
	reel._skip_to_result()
	_check(not reel.is_busy() and not reel.is_visible_in_tree(), "Second activation dismisses the revealed result and its opaque cover together")
	await _check_batches()
	await _check_compact_batches()
	await _check_batch_selectors()
	_remember_audio()
	viewport.queue_free()
	await process_frame
	await _await_audio_retirement()
	if failures == 0:
		print("PASS: rarity reel conceals every underlying pixel through spin, stop, skip and reveal at desktop, ultrawide and portrait sizes; suspension retains its lifecycle")
	quit(1 if failures else 0)


func _check_batches() -> void:
	for dimensions: Vector2i in [Vector2i(1000, 720), Vector2i(1568, 920), Vector2i(720, 1000)]:
		viewport.size = dimensions
		await process_frame
		for count: int in [10, 23, 103]:
			var results: Array[Dictionary] = []
			for index: int in range(count):
				results.append({"rarity": "mythic" if index == count - 2 else "common", "attributes": []})
			var accepted: Dictionary = {"rarity": "mythic", "rarity_batch_results": results, "rarity_batch_winner": count - 2}
			reel.present(accepted, preload("res://assets/towers/arrow_tower_board.png"))
			reel.set_process(false)
			await process_frame
			_check(reel._batch.size() == count and reel._batch_content.get_child_count() == count, "Every accepted result owns an animated reel, without a display cap")
			_check(reel._result.text.is_empty(), "The best batch rarity is concealed until landing")
			_check(reel._batch[0].spin_seconds == RarityReel.SPIN_SECONDS and reel._spin_end() <= RarityReel.SPIN_SECONDS + RarityReel.BATCH_MAX_SPREAD_SECONDS, "First reel keeps its normal clock and Max adds at most 1.5 seconds")
			for index: int in range(1, count):
				_check(reel._batch[index].spin_seconds > reel._batch[index - 1].spin_seconds, "Every result has a strictly later stop clock")
				if index < 10:
					_check(is_equal_approx(reel._batch[index].spin_seconds - reel._batch[index - 1].spin_seconds, 0.06), "First ten reels stop sixty milliseconds apart")
			if count == 10:
				_check(reel._batch_columns == 2 and reel._batch[8].strip.position.y > reel._batch[6].strip.position.y and reel._batch[9].strip.position.y == reel._batch[8].strip.position.y, "Ten results form exactly two columns and five rows")
			for entry: RarityReel.BatchReel in reel._batch:
				_check(entry.strip.size.y >= 88.0 and entry.strip.size.x >= 272.0 and not entry.strip.retained, "Batch cards remain readable and do not identify the winner before reveal")
			await _check_concealed("batch start")
			var start: Image = await _capture()
			reel._process(RarityReel.ACCEL_SECONDS * 0.5)
			var windup: Image = await _capture()
			_check(start.get_data() != windup.get_data(), "Batch wind-up changes actual rendered cards")
			for entry: RarityReel.BatchReel in reel._batch:
				_check(entry.strip.scroll_position > RarityReel.START_POSITION and entry.strip.scroll_position < entry.landing, "Every result independently travels during wind-up")
			reel._process(RarityReel.ACCEL_SECONDS * 0.5 + RarityReel.CRUISE_SECONDS)
			var cruise_positions: Array[float] = []
			for entry: RarityReel.BatchReel in reel._batch:
				cruise_positions.append(entry.strip.scroll_position)
			reel._process(RarityReel.BRAKE_SECONDS - 0.01)
			for index: int in range(count):
				_check(reel._batch[index].strip.scroll_position > cruise_positions[index], "Every reel continues through braking")
			_check(not reel._revealed, "Batch winner stays unannounced until every reel stops")
			await _check_concealed("batch braking")
			reel._process(0.02)
			_check(reel._batch[0].settled and not reel._batch[1].settled and not reel._revealed and reel._result.text.is_empty(), "First result lands alone without announcing the batch winner")
			var partial_positions: Array[float] = []
			for entry: RarityReel.BatchReel in reel._batch:
				partial_positions.append(entry.strip.scroll_position)
				_check(not entry.strip.retained and (entry.settled or entry.strip.reveal == 0.0), "Unsettled results remain unrevealed and no winner is highlighted")
			var partial_elapsed: float = reel._elapsed
			reel.set_suspended(true)
			reel._process(100.0)
			for index: int in range(count):
				_check(reel._batch[index].strip.scroll_position == partial_positions[index], "Suspension freezes every independent strip during a partial landing")
			_check(reel._elapsed == partial_elapsed and reel._batch[0].settled and not reel._batch[1].settled, "Suspension preserves ordered intermediate stop state")
			reel.set_suspended(false)
			reel.set_process(false)
			viewport.size = Vector2i(dimensions.x + 80, dimensions.y + 40)
			await process_frame
			for index: int in range(count):
				_check(reel._batch[index].strip.scroll_position == partial_positions[index], "Resizing during stagger never advances or resets a reel clock")
			_check(reel._elapsed == partial_elapsed and reel._result.text.is_empty(), "Resizing cannot reveal the batch winner early")
			viewport.size = dimensions
			await process_frame
			for stopped: int in range(2, 11):
				reel._process(reel._batch[stopped - 1].spin_seconds + 0.001 - reel._elapsed)
				for index: int in range(count):
					_check(reel._batch[index].settled == (index < stopped), "Intermediate results settle strictly in accepted index order")
					if index >= stopped:
						_check(reel._batch[index].strip.scroll_position != partial_positions[index] and reel._batch[index].strip.reveal == 0.0, "Later strips keep animating on their own clocks without a result reveal")
				if stopped < count:
					_check(not reel._revealed and reel._result.text.is_empty(), "Footer waits for the final result, not the first ten")
			reel._process(maxf(0.0, reel._spin_end() - reel._elapsed) + 0.5)
			_check(reel._revealed and reel._result.text == "Mythic", "Batch reveal displays the accepted highest rarity")
			for index: int in range(count):
				var entry: RarityReel.BatchReel = reel._batch[index]
				_check(entry.strip.rarities[roundi(entry.strip.scroll_position)] == RarityReel.RARITIES.find(results[index]["rarity"]), "Every reel lands on its own accepted candidate")
				_check(entry.strip.retained == (index == count - 2), "Only the retained candidate receives the winner border")
			await _check_concealed("settled batch")
			reel._process(100.0)
			_check(reel.is_busy(), "Large settled batches stay available to read and scroll")
			if count == 103:
				var end := InputEventKey.new()
				end.keycode = KEY_END
				end.pressed = true
				reel._input(end)
				await process_frame
				var last_rect: Rect2 = reel._batch.back().strip.get_global_rect()
				_check(reel._batch_scroll.scroll_vertical > 0 and reel._batch_scroll.get_global_rect().encloses(last_rect), "Chrome-free scrolling reaches the final accepted result")
			reel._skip_to_result()
			_check(not reel.is_busy(), "Activation dismisses the complete settled batch")
			reel.present(accepted, null)
			reel.set_process(false)
			reel._process(RarityReel.SPIN_SECONDS + 0.01)
			_check(reel._batch[0].settled and not reel._batch[1].settled, "Skip fixture begins with only the first candidate settled")
			reel._skip_to_result()
			for entry: RarityReel.BatchReel in reel._batch:
				_check(entry.settled and entry.strip.reveal == 1.0 and roundi(entry.strip.scroll_position) == RarityReel.WINNER_INDEX, "One skip settles every remaining reel immediately")
			reel.set_suspended(true)
			var elapsed: float = reel._elapsed
			reel._process(100.0)
			_check(not reel.is_visible_in_tree() and reel.is_busy() and reel._elapsed == elapsed, "Batch suspension hides and freezes all accepted results")
			reel.set_suspended(false)
			reel.set_process(false)
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			reel._input(escape)
			_check(not reel.is_busy(), "Escape cancels a whole batch")
			reel.present(accepted, null)
			reel.set_process(false)
			_check(reel._elapsed == 0.0 and not reel._batch[0].settled and not reel._batch.back().settled, "A new batch resets every stop clock after cancellation")
			reel._process(RarityReel.SPIN_SECONDS + 0.01)
			reel.get_parent().hide()
			_check(not reel.is_busy(), "Hiding the owning screen cancels a partially settled batch")
			var cancelled_elapsed: float = reel._elapsed
			reel._process(100.0)
			_check(reel._elapsed == cancelled_elapsed and not reel._batch[1].settled, "Cancelled batches cannot finish later on stale clocks")
			reel.get_parent().show()
	reel.present_reward(_award())
	reel.set_process(false)
	_check(reel._batch.is_empty() and reel._strip.visible and not reel._batch_scroll.visible, "Boss rewards return to their unchanged single reel after a batch")
	reel.cancel()


func _check_compact_batches() -> void:
	for dimensions: Vector2i in [Vector2i(1000, 720), Vector2i(1568, 920)]:
		viewport.size = dimensions
		await process_frame
		for count: int in [1, 10, 24, 40, 103]:
			var results: Array[Dictionary] = []
			for index: int in range(count):
				results.append({"rarity": "mythic" if index == count - 1 else "common", "attributes": []})
			var accepted: Dictionary = {"rarity": "mythic", "rarity_batch_results": results, "rarity_batch_winner": count - 1}
			reel.present(accepted, preload("res://assets/towers/arrow_tower_board.png"), true)
			reel.set_process(false)
			await process_frame
			_check(reel._batch.size() == count and reel._batch_content.get_child_count() == count, "Compact Max keeps every accepted result, including a one-roll Max")
			var available: Vector2 = reel._batch_scroll.size
			var columns: int = mini(count, maxi(1, floori((available.x + 8.0) / 144.0)))
			_check(reel._batch_columns == columns, "Max uses as many single-card columns as fit rather than the ten-roll layout")
			var grid_width: float = columns * 144.0 - 8.0
			_check(absf(reel._batch[0].strip.position.x - (available.x - grid_width) * 0.5) <= 1.0, "The compact Max grid is horizontally centered")
			for index: int in range(count):
				var entry: RarityReel.BatchReel = reel._batch[index]
				_check(entry.strip.single_card and entry.strip.size.x == 136.0 and entry.strip.size.y >= 72.0, "Max has one-card-wide readable windows with no label-obscuring edge masks")
				_check(entry.landing == float(RarityReel.WINNER_INDEX), "A narrow window lands exactly at the accepted card center")
				_check(not entry.settled and not entry.strip.retained and entry.strip.reveal == 0.0, "Compact layout does not reveal results early")
				if index > 0:
					_check(entry.spin_seconds > reel._batch[index - 1].spin_seconds, "Compact Max preserves strictly ordered stops")
					if index < 10:
						_check(is_equal_approx(entry.spin_seconds - reel._batch[index - 1].spin_seconds, 0.06), "Compact Max preserves the first ten sixty-millisecond stops")
				if count <= 40:
					_check(reel._batch_scroll.get_global_rect().encloses(entry.strip.get_global_rect()), "Every typical Max result fits inside the viewport without scrolling")
			_check(reel._batch[0].spin_seconds == RarityReel.SPIN_SECONDS and reel._spin_end() <= RarityReel.SPIN_SECONDS + 1.5, "Compact layout preserves the normal spin and bounded Max duration")
			if count <= 40:
				_check(reel._batch_content.size.y <= available.y and reel._batch_scroll.scroll_vertical == 0, "Max24 and Max40 require no vertical overflow at either desktop size")
			reel._process(RarityReel.ACCEL_SECONDS * 0.5)
			_remember_audio()
			for entry: RarityReel.BatchReel in reel._batch:
				_check(entry.strip.scroll_position > RarityReel.START_POSITION and entry.strip.scroll_position < entry.landing, "Compact windows still scroll real cards during wind-up")
			reel._process(RarityReel.SPIN_SECONDS + 0.001 - reel._elapsed)
			_remember_audio()
			_check(reel._batch[0].settled and (count == 1 or not reel._batch[1].settled), "Compact Max stops its first result independently")
			var elapsed: float = reel._elapsed
			var positions: Array[float] = []
			for entry: RarityReel.BatchReel in reel._batch:
				positions.append(entry.strip.scroll_position)
			reel.set_suspended(true)
			reel._process(100.0)
			_check(reel._elapsed == elapsed and not reel.is_visible_in_tree(), "Compact suspension freezes the presentation")
			reel.set_suspended(false)
			reel.set_process(false)
			viewport.size = Vector2i(720, 1000)
			await process_frame
			for index: int in range(count):
				_check(reel._batch[index].strip.scroll_position == positions[index] and reel._batch[index].strip.size.x == 136.0, "Resize preserves single-card widths and every independent clock")
			viewport.size = dimensions
			await process_frame
			_check(reel._elapsed == elapsed, "Resize does not advance the accepted spin")
			if count % 2 == 0:
				reel._skip_to_result()
			elif count > 1:
				reel._process(reel._spin_end() + 0.5 - reel._elapsed)
			_remember_audio()
			_check(reel._revealed and reel._result.text == "Mythic", "Compact natural landing and skip show the accepted highest rarity")
			for index: int in range(count):
				var entry: RarityReel.BatchReel = reel._batch[index]
				_check(entry.settled and is_equal_approx(entry.strip.scroll_position, float(RarityReel.WINNER_INDEX)), "The complete accepted tile remains centered after stop or skip")
				var left: float = roundf(floorf(entry.strip.size.x * 0.5) + (float(RarityReel.WINNER_INDEX) - entry.strip.scroll_position) * RarityReel.ReelStrip.STRIDE - RarityReel.ReelStrip.CARD_WIDTH * 0.5)
				_check(left == 0.0 and left + RarityReel.ReelStrip.CARD_WIDTH == entry.strip.size.x, "Neither edge of the landed accepted tile is clipped")
				_check(entry.strip.rarities[RarityReel.WINNER_INDEX] == RarityReel.RARITIES.find(results[index]["rarity"]) and entry.strip.retained == (index == count - 1), "Compact layout preserves accepted identities and first-tie winner ownership")
			reel._process(100.0)
			_check(reel.is_busy(), "Compact results remain available until dismissed")
			if count == 103:
				var end := InputEventKey.new()
				end.keycode = KEY_END
				end.pressed = true
				reel._input(end)
				await process_frame
				_check(reel._batch_scroll.scroll_vertical > 0 and reel._batch_scroll.get_global_rect().encloses(reel._batch.back().strip.get_global_rect()), "Huge Max batches retain accessible overflow to the final result")
			reel._skip_to_result()
			_check(not reel.is_busy(), "A second activation dismisses the complete compact batch")
			if count == 10:
				reel.present(accepted, null)
				reel.set_process(false)
				_check(reel._batch_columns == 2 and not reel._batch[0].strip.single_card and reel._batch[0].strip.size.x >= 272.0, "Default ten rolls remain two wide columns, unlike compact Max10")
				reel.cancel()
	_remember_audio()


func _remember_audio() -> void:
	for node: Node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer and node.has_stream_playback():
			audio_playbacks.append({"reference": weakref(node.get_stream_playback()), "owner": String(node.get_path()), "stream": node.stream.resource_path})
		elif node is AudioStreamPlayer2D and node.has_stream_playback():
			audio_playbacks.append({"reference": weakref(node.get_stream_playback()), "owner": String(node.get_path()), "stream": node.stream.resource_path})


func _await_audio_retirement() -> void:
	var deadline: int = Time.get_ticks_usec() + 2_000_000
	while not audio_playbacks.is_empty():
		for index: int in range(audio_playbacks.size() - 1, -1, -1):
			if audio_playbacks[index]["reference"].get_ref() == null:
				audio_playbacks.remove_at(index)
		if audio_playbacks.is_empty() or Time.get_ticks_usec() >= deadline:
			break
		await process_frame
	for playback: Dictionary in audio_playbacks:
		_check(false, "Stopped audio playback still retained after teardown: %s (%s)" % [playback["owner"], playback["stream"]])


func _check_concealed(stage: String) -> void:
	# Change every underlying pixel as well as the title color, stats, attributes
	# and reroll prices. Any transparency or uncovered edge changes the capture.
	backdrop.color = Color.WHITE
	accepted_details.text = "Mythic Orcapult\nDamage 999 · Range 8\n+50% attack speed\nReroll 999 Shards · Count 40"
	accepted_details.add_theme_color_override("font_color", Color("ff3322"))
	var before: Image = await _capture()
	backdrop.color = Color.BLACK
	accepted_details.text = "Broken Orcapult\nDamage 1 · Range 1\n-50% attack speed\nReroll 1 Shard · Count 0"
	accepted_details.add_theme_color_override("font_color", Color("22ff33"))
	var after: Image = await _capture()
	_check(before.get_data() == after.get_data(), "No underlying title, color, stats, attributes, prices or edge pixels leak during " + stage)


func _capture() -> Image:
	await process_frame
	RenderingServer.force_draw.call_deferred(false)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _award() -> Dictionary:
	var tiers: Array[Dictionary] = []
	for rank: int in range(RarityReel.RARITIES.size()):
		var rarity: String = RarityReel.RARITIES[rank]
		tiers.append({"id": rarity, "title": rarity.capitalize(), "coins": 100 * (rank + 1), "shards": rank + 1})
	return {"boss_title": "Orc king war orchine", "rarity": "epic", "rarity_title": "Epic", "coins": 600, "shards": 6, "tiers": tiers}


func _check_batch_selectors() -> void:
	var directory: String = OS.get_temp_dir().path_join("gorcs_batch_selectors_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var main: Control = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(directory.path_join("collection.json"))
	main.statistics_store = EnemyStatisticsStore.new(directory.path_join("statistics.json"))
	main.combat_rules = CombatRules.new()
	main.combat_rules.roll_rules = preload("res://resources/combat/tower_rolls.tres")
	main.combat_rules.starting_coins = 100000
	main.combat_rules.starting_reroll_currency = 10000
	root.add_child(main)
	await _selector_settle()
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	var planning: MatchPlanning = main.planning
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Batch selector fixture completes the real commander draft")
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Batch selector fixture commits its loadout")
	planning.set_physics_process(false)
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var cell: Vector2i = preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(3, 3))
	planning.build_tower(0, cell, &"arrow_tower", MatchCombat.TargetMode.CLOSEST)
	screen._cell_clicked(cell, MOUSE_BUTTON_LEFT, 0)
	await _selector_settle()
	var original: Dictionary = screen._selected_tower().duplicate(true)
	screen.rarity_batch_selector.grab_focus()
	await _selector_key(KEY_ENTER)
	_check(screen._rarity_batch == 10 and screen.rarity_batch_selector.has_focus(), "Keyboard activation cycles to ten without moving focus")
	_check(screen.rarity_batch_selector.get_global_rect().position.x >= screen.rarity_reroll.get_global_rect().end.x, "Batch selector occupies the right end of the rarity row")
	var quote: Dictionary = screen._selected_tower()["rarity_batch_quotes"]["10"]
	_check(not screen.rarity_reroll.disabled and int(quote["count"]) == 10, "An affordable accepted ten-roll quote enables the action")
	var shards: int = int(planning.combat["reroll_currency"][0])
	# Hold delivery to exercise the real pending-command lock, then deliver the
	# accepted snapshot through the existing observer rather than inventing a roll.
	planning.changed.disconnect(screen._refresh)
	screen.rarity_reroll.pressed.emit()
	_check(screen._pending_rarity_id >= 0 and screen.rarity_batch_selector.disabled, "Submitting a batch immediately locks its selector before acknowledgement")
	screen.rarity_batch_selector.pressed.emit()
	_check(screen._rarity_batch == 10, "Pending acceptance cannot change the submitted batch selection")
	planning.changed.connect(screen._refresh)
	screen._refresh()
	screen._rarity_reel.set_process(false)
	var accepted: Dictionary = screen._selected_tower()
	_check(int(accepted["rarity_rerolls"]) == int(original["rarity_rerolls"]) + 10 and int(planning.combat["reroll_currency"][0]) == shards - int(quote["cost"]), "The selected batch reaches the host API and spends its complete accepted quote")
	_check(accepted["rarity_batch_results"].size() == 10 and screen._rarity_reel.is_busy() and screen.rarity_batch_selector.disabled, "All accepted batch results reach the shared presentation while controls stay locked")
	_check(screen._rarity_reel._batch_columns == 2 and not screen._rarity_reel._batch[0].strip.single_card, "Match ten-roll selector retains the wide two-column layout")
	_remember_audio()
	screen._rarity_reel.cancel()
	await _selector_settle()
	_check(screen._rarity_batch == 10 and not screen.rarity_batch_selector.disabled, "Finishing presentation preserves the chosen batch and unlocks its selector")
	_check(planning.debug_set_values(1, 100000, 0), "Fixture drains Shards through the real solo debug action")
	_check(screen.rarity_reroll.disabled and not screen.rarity_batch_selector.disabled, "An unaffordable batch locks purchase but leaves the mode selectable")
	screen.rarity_batch_selector.pressed.emit()
	_check(screen._rarity_batch == 0 and screen.rarity_reroll.disabled, "Max with no affordable rolls cannot submit an empty batch")
	_check(planning.debug_set_values(1, 100000, 10000), "Fixture restores Shards for Max")
	quote = screen._selected_tower()["rarity_batch_quotes"]["max"].duplicate()
	var count_before: int = int(screen._selected_tower()["rarity_rerolls"])
	screen.rarity_reroll.pressed.emit()
	screen._rarity_reel.set_process(false)
	_check(int(screen._selected_tower()["rarity_rerolls"]) == count_before + int(quote["count"]), "Max submits the complete accepted affordable count")
	_check(screen._rarity_reel._batch.size() == int(quote["count"]) and screen._rarity_reel._batch[0].strip.single_card and screen._rarity_reel._batch[0].strip.size.x == 136.0, "Match Max selector propagates compact presentation independently of its accepted count")
	_remember_audio()
	screen._rarity_reel.cancel()
	await _selector_settle()
	screen.rarity_batch_selector.pressed.emit()
	_check(screen._rarity_batch == 1, "The batch cycle returns from Max to one")
	planning.ready_flags[0] = true
	screen._refresh_targeting()
	screen.rarity_batch_selector.pressed.emit()
	_check(screen.rarity_batch_selector.disabled and screen._rarity_batch == 1, "Accepted Ready state locks batch selection as well as mutation")
	planning.ready_flags[0] = false
	planning.combat["phase"] = MatchCombat.Phase.FINISHED
	screen._refresh_targeting()
	_check(screen.rarity_batch_selector.disabled and not screen.rarity_batch_selector.visible, "Terminal inspection exposes no usable batch selector")
	screen._quit_match()
	await _selector_settle()
	main.sandbox_button.pressed.emit()
	var sandbox: SandboxScreen = main.sandbox_screen
	_check(sandbox.controller.build(Vector2i(3, 3), &"arrow_tower"), "Sandbox batch fixture builds a real tower")
	sandbox._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT)
	await _selector_settle()
	for batch: int in [10, 0]:
		sandbox.rarity_batch_selector.pressed.emit()
		_check(sandbox._rarity_batch == batch, "Sandbox uses the same batch cycle")
		count_before = int(sandbox.controller.state["towers"][0][0]["rarity_rerolls"])
		sandbox.rarity_reroll.pressed.emit()
		sandbox._rarity_reel.set_process(false)
		accepted = sandbox.controller.state["towers"][0][0]
		_check(int(accepted["rarity_rerolls"]) == count_before + 10 and accepted["rarity_batch_results"].size() == 10, "Sandbox ten and Max both produce ten accepted free previews")
		_check(sandbox._rarity_reel.is_busy() and sandbox.rarity_batch_selector.disabled, "Sandbox batch uses the shared locked presentation lifecycle")
		_check(sandbox._rarity_reel._batch[0].strip.single_card == (batch == 0), "Sandbox Max10 uses compact windows while ordinary ten keeps two wide columns")
		_check(sandbox._rarity_reel._batch[0].strip.size.x == 136.0 if batch == 0 else sandbox._rarity_reel._batch_columns == 2, "Sandbox selector chooses layout by mode, not equal accepted counts")
		_remember_audio()
		sandbox._rarity_reel.cancel()
		await _selector_settle()
	var rarity_before: String = String(sandbox.controller.state["towers"][0][0]["rarity"])
	count_before = int(sandbox.controller.state["towers"][0][0]["attribute_rerolls"])
	sandbox.attribute_reroll.pressed.emit()
	accepted = sandbox.controller.state["towers"][0][0]
	_check(int(accepted["attribute_rerolls"]) == count_before + 1 and accepted["rarity"] == rarity_before and not sandbox._rarity_reel.is_busy(), "Max selection does not batch or animate attribute rerolls")
	_remember_audio()
	sandbox.prepare_to_leave()
	main.queue_free()
	await _selector_settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func _selector_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame


func _selector_settle() -> void:
	for frame: int in range(4):
		await process_frame
