extends SceneTree

class DualPlanning extends MatchPlanning:
	var rejections: Array[Dictionary] = []

	func _reject(sender: int, message: String) -> void:
		# These synthetic senders have no transport peer. Capture the real
		# authority's outbound feedback instead of issuing an invalid RPC.
		rejections.append({"sender": sender, "message": message})
		if sender == 1:
			feedback.emit(message)

	func _can_accept(sender: int) -> bool:
		return sender in [1, 2] and (selecting_loadout or active)

	func begin_selection() -> void:
		_reset_match()
		selecting_loadout = true
		_begin_commander_draft()
		_publish_snapshot()

	func complete_draft() -> bool:
		if not _apply_loadout_command(1, "guess", [0], []) or not _apply_loadout_command(2, "guess", [100], []):
			return false
		var first: int = int(commander_draft["picker"])
		return _apply_loadout_command(1 if first == 0 else 2, "commander", [], [], "knight") and _apply_loadout_command(2 if first == 0 else 1, "commander", [], [], "priestess")
	func _request_loadout_command(command: String, ids: Array, owned: Array, commander_id: String = "") -> bool:
		return _apply_loadout_command(1, command, ids, owned, commander_id)

	func _request_tower_command(command: String, slot: int, cell: Vector2i, tower_id: int, mode: int, argument: String) -> bool:
		return _apply_tower_command(1, command, slot, cell, tower_id, mode, argument)


class DelayedPlanning extends DualPlanning:
	var pending_commands: Array[Dictionary] = []

	func _publish_snapshot() -> void:
		# Deliver the guest's private view without a network/frame-timing race.
		_mirror_snapshot(_snapshot(1))
		changed.emit()

	func _reject(_sender: int, message: String) -> void:
		feedback.emit(message)

	func _request_loadout_command(command: String, ids: Array, owned: Array, commander_id: String = "") -> bool:
		pending_commands.append({"command": command, "ids": ids.duplicate(), "owned": owned.duplicate(), "commander": commander_id})
		return true

	func deliver_next(reject_ownership: bool = false) -> void:
		var request: Dictionary = pending_commands.pop_front()
		var owned: Array = ["arrow_tower"] if reject_ownership else request["owned"]
		_apply_loadout_command(2, request["command"], request["ids"], owned, request["commander"])


var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _store(path: String, ids: Array, rules: CombatRules) -> CollectionStore:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": CollectionStore.SAVE_VERSION, "unlocked": ids}))
	file.close()
	return CollectionStore.new(path, rules.catalog)


func _run() -> void:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true) as CombatRules
	rules.starting_coins = 10000
	rules.starting_reroll_currency = 10000
	var session := MultiplayerSession.new()
	root.add_child(session)
	var planning := DualPlanning.new()
	planning.session = session
	planning.combat_rules = rules
	var save_path: String = "user://loadout-test-collection.json"
	planning.collection_store = _store(save_path, ["arrow_tower", "orc_ballista", "rune_obelisk", "lightning"], rules)
	root.add_child(planning)
	planning.begin_selection()
	_check(planning.selecting_loadout and not planning.active, "Admission opens private selection rather than an editable board")
	var before: Dictionary = planning.combat.duplicate(true)
	planning._apply_tower_command(1, "build", 0, Vector2i(2, 3), -1, 0, "arrow_tower")
	planning._apply_command(1, "edit", 0, Vector2i(1, 4), true)
	_check(planning.combat == before and planning.layouts[0].used_tiles() == 0, "Selection cannot build or edit before both commits")
	_check(planning.complete_draft(), "Tower validation fixture first completes the real guess and ordered distinct hero draft")
	_check(not planning.commit_loadout(), "An empty deck cannot commit")
	_check(planning.select_loadout([&"arrow_tower"]), "The starter alone is a valid loadout with three empty slots")
	for invalid: Array in [[], [""], [42], ["arrow_tower", "arrow_tower"], ["unknown"], ["war_drums"], ["arrow_tower", "orc_ballista", "rune_obelisk", "lightning", "gold_mine"]]:
		_check(not planning.select_loadout(invalid) and planning.chosen_tower_ids == [&"arrow_tower"], "Invalid length, type, empty, duplicate, unknown, or locked selection is atomic")
	_check(planning.select_loadout(["arrow_tower", "orc_ballista", "rune_obelisk", "lightning"]), "Four distinct owned tower types are accepted")
	_check(planning.select_loadout(["arrow_tower"]), "Players can revise an uncommitted deck")
	_check(not planning._apply_loadout_command(2, "select", ["orc_ballista"], ["arrow_tower"]), "Authority rejects a remote selection outside the remote ownership claim")
	_check(planning.rejections.back() == {"sender": 2, "message": "Choose one to four distinct unlocked tower types."}, "An invalid remote ownership selection returns targeted rejection feedback")
	_check(not planning._apply_loadout_command(2, "select", ["orc_ballista"], ["orc_ballista", "orc_ballista"]), "Malformed duplicate ownership claims do not admit a deck")
	_check(planning._apply_loadout_command(2, "select", ["orc_ballista"], ["orc_ballista"]), "Remote selection uses its own trusted collection claim, not the host collection")
	var own: Dictionary = planning._snapshot(0)
	var guest: Dictionary = planning._snapshot(1)
	_check(own["chosen_tower_ids"] == [&"arrow_tower"] and guest["chosen_tower_ids"] == [&"orc_ballista"], "Targeted snapshots reveal only each recipient's own selected deck")
	guest["chosen_tower_ids"].append(&"rune_obelisk")
	_check(planning._snapshot(1)["chosen_tower_ids"] == [&"orc_ballista"], "Recipient snapshots cannot mutate admitted deck state")
	_check(planning.commit_loadout() and not planning.active and planning.loadout_committed and not planning.opponent_committed, "The first commit freezes that deck but does not start boards")
	_check(not planning.select_loadout(["orc_ballista"]), "A committed local deck cannot change")
	_check(planning._apply_loadout_command(2, "commit", [], []) and planning.active and not planning.selecting_loadout, "Both individual commits activate board planning")
	before = planning.combat.duplicate(true)
	var roll_state: int = planning._host_combat._roll_random.state
	planning._apply_tower_command(1, "build", 0, Vector2i(2, 3), -1, 0, "orc_ballista")
	planning._apply_tower_command(2, "build", 1, Vector2i(2, 3), -1, 0, "arrow_tower")
	_check(planning.combat == before and planning._host_combat._roll_random.state == roll_state, "Host and remote authority reject purchases outside their frozen deck without consuming a roll")
	_check(planning.rejections.back() == {"sender": 2, "message": "This tower is not in your committed run loadout."}, "An unequipped remote purchase returns targeted rejection feedback")
	var build_cell: Vector2i = preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(2, 3), 3)
	_check(planning._apply_tower_command(1, "build", 0, build_cell, -1, 0, "arrow_tower"), "Host can buy an admitted tower")
	_check(planning._apply_tower_command(2, "build", 1, build_cell, -1, 0, "orc_ballista"), "Remote can buy its own admitted tower")
	var id: int = planning.combat["towers"][0][0]["id"]
	_check(planning.reroll_tower(0, id, "attributes"), "Authenticated host reroll publishes its accepted counter and attributes")
	before = planning.combat.duplicate(true)
	_check(not planning._apply_tower_command(2, "reroll", 0, Vector2i.ZERO, id, -1, "attributes") and planning.combat == before, "Remote reroll cannot mutate the other player's tower")
	_check(planning.rejections.back() == {"sender": 2, "message": "Only your own Coins and towers can be changed."}, "A wrong-owner remote reroll returns targeted rejection feedback")
	for x: int in range(1, 13):
		planning._apply_command(1, "edit", 0, Vector2i(x, 4), true)
	planning._apply_command(1, "ready", 0, Vector2i.ZERO, true)
	before = planning.combat.duplicate(true)
	roll_state = planning._host_combat._roll_random.state
	_check(not planning.reroll_tower(0, id, "rarity") and planning.combat == before and planning._host_combat._roll_random.state == roll_state, "Committed Ready rejects rerolls without spending, changing attributes, or consuming a roll")
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._publish_snapshot()
	before = planning.combat.duplicate(true)
	_check(not planning.reroll_tower(0, id, "attributes") and planning.combat == before, "Finished runs reject rerolls")
	planning.begin_selection()
	_check(not planning.active and planning.chosen_tower_ids.is_empty() and not planning.loadout_committed and not planning.opponent_committed and planning.combat["towers"] == [[], []], "A fresh admission clears both private decks, commits, and prior match state")
	planning.queue_free()
	await process_frame
	await _solo(session, rules)
	await _delayed_panel(session, rules)
	session.queue_free()
	DirAccess.remove_absolute(save_path)
	await process_frame
	if failures == 0:
		print("PASS: private loadout validation, delayed panel acknowledgments, individual commits, authoritative purchase/reroll gates, and mirrored solo lifecycle")
	quit(1 if failures > 0 else 0)


func _delayed_panel(session: MultiplayerSession, rules: CombatRules) -> void:
	var planning := DelayedPlanning.new()
	planning.session = session
	planning.combat_rules = rules
	root.add_child(planning)
	planning.begin_selection()
	_check(planning.complete_draft(), "Delayed tower UI begins only after both real hero picks")
	planning._apply_loadout_command(2, "select", ["arrow_tower"], ["arrow_tower"])
	var panel := LoadoutPanel.new()
	panel.planning = planning
	root.add_child(panel)

	panel.tower_buttons[&"orc_ballista"].pressed.emit()
	panel.tower_buttons[&"rune_obelisk"].pressed.emit()
	panel.commit_button.pressed.emit()
	_check(planning.pending_commands.size() == 1 and planning.chosen_tower_ids == [&"arrow_tower"], "Before a guest acknowledgment, rapid toggles and Commit cannot submit replacements from a stale accepted deck")
	_check(panel.tower_buttons[&"rune_obelisk"].disabled and panel.commit_button.disabled and not panel.tower_buttons[&"orc_ballista"].button_pressed, "Pending selection visibly locks all edits and Commit while displaying only the accepted deck")
	planning.opponent_committed = true
	planning.changed.emit()
	_check(panel.tower_buttons[&"rune_obelisk"].disabled and panel.commit_button.disabled, "An unrelated opponent snapshot cannot acknowledge a pending local selection")
	planning.opponent_committed = false
	planning.deliver_next()
	_check(panel.tower_buttons[&"orc_ballista"].button_pressed and not panel.tower_buttons[&"rune_obelisk"].disabled and not panel.commit_button.disabled, "The delayed accepted deck becomes visible and unlocks further gestures")
	panel.tower_buttons[&"rune_obelisk"].pressed.emit()
	planning.deliver_next()
	_check(planning.chosen_tower_ids == [&"arrow_tower", &"orc_ballista", &"rune_obelisk"] and panel.tower_buttons[&"orc_ballista"].button_pressed and panel.tower_buttons[&"rune_obelisk"].button_pressed, "A subsequent enabled gesture preserves the earlier accepted addition")

	panel.tower_buttons[&"orc_ballista"].pressed.emit()
	panel.tower_buttons[&"rune_obelisk"].pressed.emit()
	_check(planning.pending_commands.size() == 1 and panel.tower_buttons[&"rune_obelisk"].disabled, "Rapid removals cannot restore a tower from an older accepted deck")
	planning.deliver_next()
	panel.tower_buttons[&"rune_obelisk"].pressed.emit()
	planning.deliver_next()
	_check(planning.chosen_tower_ids == [&"arrow_tower"] and not panel.tower_buttons[&"orc_ballista"].button_pressed and not panel.tower_buttons[&"rune_obelisk"].button_pressed, "Acknowledged removals remain removed in the visible deck")
	panel.tower_buttons[&"arrow_tower"].pressed.emit()
	_check(planning.pending_commands.is_empty() and panel.tower_buttons[&"arrow_tower"].button_pressed, "The last equipped tower cannot be removed")

	panel.tower_buttons[&"orc_ballista"].pressed.emit()
	planning.deliver_next(true)
	_check(planning.chosen_tower_ids == [&"arrow_tower"] and not panel.tower_buttons[&"orc_ballista"].button_pressed and not panel.tower_buttons[&"orc_ballista"].disabled and not panel.commit_button.disabled and not panel._notice.text.is_empty(), "A delayed authority rejection preserves accepted selection, explains the failure, and unlocks retry")
	for id: StringName in [&"orc_ballista", &"rune_obelisk", &"lightning"]:
		panel.tower_buttons[id].pressed.emit()
		planning.deliver_next()
	panel.tower_buttons[&"gold_mine"].pressed.emit()
	_check(planning.chosen_tower_ids.size() == 4 and planning.pending_commands.is_empty() and panel.tower_buttons[&"gold_mine"].disabled, "Four accepted towers keep a fifth gesture disabled without submitting an oversized deck")
	panel.commit_button.pressed.emit()
	panel.tower_buttons[&"arrow_tower"].pressed.emit()
	panel.commit_button.pressed.emit()
	_check(planning.pending_commands.size() == 1 and panel.tower_buttons[&"arrow_tower"].disabled, "A pending commit cannot race another edit or duplicate commit")
	planning.deliver_next()
	_check(planning.loadout_committed and planning.chosen_tower_ids.size() == 4 and panel.commit_button.text == "Committed" and panel.commit_button.disabled, "Commit freezes the latest visible accepted deck after its acknowledgment")

	planning.begin_selection()
	_check(planning.complete_draft(), "A fresh delayed tower selection completes another draft")
	panel.tower_buttons[&"arrow_tower"].pressed.emit()
	planning.deliver_next()
	_check(panel.tower_buttons[&"arrow_tower"].button_pressed and not panel.commit_button.disabled, "A new selection clears transient commit state")
	panel.tower_buttons[&"orc_ballista"].pressed.emit()
	planning.pending_commands.clear()
	planning._reset_match()
	planning.changed.emit()
	planning.begin_selection()
	_check(planning.complete_draft(), "A reset fixture completes its new draft before editing towers")
	_check(panel._pending_selection.is_empty() and not panel._pending_commit and not panel.tower_buttons[&"arrow_tower"].disabled, "Disconnect/reset clears an unacknowledged selection instead of leaving the panel locked")
	panel.tower_buttons[&"arrow_tower"].pressed.emit()
	panel.leave_button.pressed.emit()
	_check(panel._pending_selection.is_empty() and not panel._pending_commit, "Leaving clears in-flight panel-only state immediately")
	panel.queue_free()
	planning.queue_free()
	await process_frame


func _solo(session: MultiplayerSession, rules: CombatRules) -> void:
	var planning := MatchPlanning.new()
	planning.session = session
	planning.combat_rules = rules
	root.add_child(planning)
	planning.start_singleplayer()
	_check(planning.selecting_loadout and not planning.active, "Singleplayer also requires explicit loadout selection")
	_check(preload("res://tests/commander_fixture_worker.gd").complete_solo(planning), "Solo first completes the real secret-number hero draft")
	_check(planning.select_loadout(["arrow_tower"]) and planning.commit_loadout() and planning.active, "Solo commit admits the same selected deck to both mirrored boards")
	planning.build_tower(0, preload("res://tests/commander_fixture_worker.gd").free_cell(planning, Vector2i(2, 3), 3), &"arrow_tower", 0)
	var own: Dictionary = planning.combat["towers"][0][0]
	var other: Dictionary = planning.combat["towers"][1][0]
	_check(own["id"] != other["id"] and own["rarity"] == other["rarity"] and own["attributes"] == other["attributes"], "Solo placement mirrors one accepted roll while retaining distinct tower identities")
	var id: int = own["id"]
	var old_rarity: String = own["rarity"]
	_check(planning.reroll_tower(0, id, "rarity"), "Solo accepts an affordable rarity reroll")
	own = planning.combat["towers"][0][0]
	other = planning.combat["towers"][1][0]
	_check(own["rarity"] != old_rarity and own["rarity"] == other["rarity"] and own["attributes"] == other["attributes"] and own["rarity_rerolls"] == other["rarity_rerolls"] and planning.combat["reroll_currency"][0] == planning.combat["reroll_currency"][1], "Solo rarity reroll mirrors one accepted outcome and charges both normal balances")
	_check(planning.reroll_tower(0, id, "attributes"), "Solo accepts an affordable attribute reroll")
	own = planning.combat["towers"][0][0]
	other = planning.combat["towers"][1][0]
	_check(own["attributes"] == other["attributes"] and own["attribute_rerolls"] == other["attribute_rerolls"] and planning.combat["coins"][0] == planning.combat["coins"][1], "Solo attribute reroll mirrors accepted attributes and equal normal costs")
	var before: Dictionary = planning.combat.duplicate(true)
	_check(not planning.reroll_tower(1, other["id"], "rarity") and planning.combat == before, "Rejected local opponent commands cannot mutate either mirrored roll")
	planning._host_combat.reroll_currency[1] = 0
	planning._publish_snapshot()
	before = planning.combat.duplicate(true)
	var roll_state: int = planning._host_combat._roll_random.state
	_check(not planning.reroll_tower(0, id, "rarity") and planning.combat == before and planning._host_combat._roll_random.state == roll_state, "An unaffordable counterpart rejects the whole solo reroll before either charge or RNG consumption")
	planning._host_combat.coins = [10000, 0]
	planning._publish_snapshot()
	for command: String in ["upgrade", "send"]:
		before = planning.combat.duplicate(true)
		var authority_before: Dictionary = planning._host_combat.snapshot()
		var group_state: int = planning._host_combat._group_random.state
		var argument: String = "damage" if command == "upgrade" else "orcling"
		var accepted: bool = planning._apply_tower_command(1, command, 0, Vector2i.ZERO, id, -1, argument)
		_check(not accepted and planning._host_combat.snapshot() == authority_before and planning.combat == before, "An unaffordable counterpart rejects the whole solo %s without charging or changing either board" % command)
		_check(planning._host_combat._group_random.state == group_state, "A rejected mirrored %s consumes no paid-group roll" % command)
	planning.start_singleplayer()
	_check(planning.selecting_loadout and not planning.active and planning.chosen_tower_ids.is_empty() and planning.combat["towers"] == [[], []], "Solo replay coherently returns to selection rather than bypassing admission")
	planning.stop_singleplayer()
	_check(not planning.singleplayer and not planning.selecting_loadout and not planning.active, "Leaving solo selection tears down the local lifecycle")
	planning.queue_free()
	await process_frame
