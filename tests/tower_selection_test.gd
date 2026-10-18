extends SceneTree

var failures: int = 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	directory = OS.get_temp_dir().path_join("gorcs_tower_selection_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	var save_path := directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["orc_ballista"]}))
	var main = preload("res://scenes/main.tscn").instantiate()
	main.collection_store = CollectionStore.new(save_path)
	main.combat_rules = CombatRules.new()
	main.combat_rules.roll_rules = null
	root.add_child(main)
	await process_frame
	main.play_button.pressed.emit()
	main.play_screen.singleplayer_button.pressed.emit()
	_check(main.planning.selecting_loadout and not main.planning.active, "Tower UI starts with explicit collection-backed selection")
	_check(main.planning.select_loadout([&"arrow_tower", &"orc_ballista"]) and main.planning.commit_loadout(), "Tower UI commits the migrated starter and saved Ballista")
	var palette_funds: int = 0
	for tower_definition: TowerDefinition in main.collection_store.content_catalog.towers:
		palette_funds = maxi(palette_funds, tower_definition.cost)
	main.planning.combat["coins"] = [palette_funds, palette_funds]
	main.planning.changed.emit()
	var screen: MatchPlanningScreen = main.play_screen.planning_screen
	var catalog_ids: Array[StringName] = []
	for reward: TowerReward in main.collection_store.catalog:
		catalog_ids.append(reward.id)
	_check(screen.shop_buttons.size() == catalog_ids.size(), "Every registered collection tower remains visible")
	for id: StringName in catalog_ids:
		_check(screen.shop_buttons.has(id), "Palette includes registered tower '%s'" % id)
		if screen.shop_buttons.has(id) and not main.collection_store.is_unlocked(id):
			_check(not screen.shop_buttons[id].visible, "Unowned and unequipped towers stay outside the purchase palette")
			_check(screen.shop_buttons[id].disabled, "Locked registered tower cannot be purchased")
	var starter_id: StringName = main.collection_store.content_catalog.starter_tower_id
	_check(not screen.shop_buttons[starter_id].disabled, "Migrated starter is affordable and selectable without a chest")
	_check(not screen.shop_buttons[&"orc_ballista"].disabled, "Saved unlocked tower is affordable and selectable")
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	main.planning.changed.emit()
	_check(screen._placement_type() == &"orc_ballista" and screen.boards[0].cell_click_mode, "Click selection survives host snapshots and disables path strokes")
	_check(not screen.boards[1].input_enabled, "Opponent board cannot accept placement or drag commands")
	_check(screen.cancel_interaction() and screen._placement_type() == &"" and not screen.boards[0].cell_click_mode, "Cancel returns to path editing without leaving the match")
	var opened: ChestResult = main.collection_store.open_chest()
	_check(opened.error_message.is_empty(), "Real chest grant succeeds in isolated save")
	main.planning.changed.emit()
	_check(not screen.shop_buttons[opened.rewards[0].id].visible and screen.shop_buttons[opened.rewards[0].id].disabled, "Chest ownership cannot change an already committed run deck")
	main.planning.start_singleplayer()
	_check(main.planning.select_loadout([starter_id, &"orc_ballista", opened.rewards[0].id]) and main.planning.commit_loadout(), "A fresh run can explicitly equip the earned reward")
	main.planning._host_combat.coins[0] = palette_funds
	main.planning._host_combat.coins[1] = palette_funds
	main.planning._publish_snapshot()
	_check(screen.shop_buttons[opened.rewards[0].id].visible and not screen.shop_buttons[opened.rewards[0].id].disabled, "Equipping an actually earned reward enables its purchase")
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	_check(main.collection_store.reset_progress(), "Collection resets successfully")
	main.planning.changed.emit()
	_check(screen.shop_buttons.size() == catalog_ids.size() and screen._placement_type() == &"", "Reset cancels placement without hiding the catalog")
	for id: StringName in catalog_ids:
		_check(screen.shop_buttons.has(id), "Reset keeps every registered tower visible")
		if screen.shop_buttons.has(id):
			_check(screen.shop_buttons[id].disabled == (id != starter_id), "Reset keeps the starter selectable and disables nonstarter purchases")

	# Real model snapshots exercise owned selection, effective upgrades and stale sales.
	var model := MatchCombat.new(main.combat_rules)
	model.coins[0] = 1000
	_check(model.build(0, Vector2i(3, 3), &"orc_ballista", MatchCombat.TargetMode.CLOSEST), "Model creates tower for management consumer")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	var id: int = int(model.towers[0][0]["id"])
	_check(screen.selected_tower_id == id and screen.get_node("%TowerManagement").visible, "Owned inspection opens management")
	_check(screen.targeting_button.mode == MatchCombat.TargetMode.CLOSEST, "Selected targeting comes from host snapshot")
	_check(screen.boards[0].selected_tower_id == id and screen.boards[1].selected_tower_id == -1, "Range selection stays local to owned board")
	main.planning.combat["rules"]["base_health"] = 140
	main.planning.combat["health"] = [63, 17]
	main.planning.changed.emit()
	_check(screen._health_bar.max_value == 140 and screen._health_bar.value == 63, "Own health bar consumes accepted health and admitted maximum rather than local defaults or opponent health")
	for accepted_health: int in [140, 90, 35, 7, 0, 140]:
		main.planning.combat["health"] = [accepted_health, 140 - accepted_health]
		main.planning.changed.emit()
		_check(screen._health_bar.max_value == 140 and screen._health_bar.value == accepted_health, "Full, damaged, critical, depleted and restored health follow the accepted own-slot value")
		_check(is_equal_approx(screen._health_bar.get_as_ratio(), float(accepted_health) / 140.0), "Health fill ratio uses the accepted maximum throughout damage and restoration")
	main.planning.combat["rules"]["base_health"] = 80
	main.planning.combat["health"] = [20, 79]
	main.planning.changed.emit()
	_check(screen._health_bar.max_value == 80 and screen._health_bar.value == 20 and is_equal_approx(screen._health_bar.get_as_ratio(), 0.25), "A changed accepted maximum immediately remaps the own health ratio without using opponent health")
	main.planning.combat["rules"]["base_health"] = 0
	main.planning.combat["health"] = [0, 79]
	main.planning.changed.emit()
	_check(screen._health_bar.value == 0 and screen._health_bar.get_as_ratio() == 0.0, "A zero accepted maximum renders an empty finite health display")
	main.planning.combat["rules"]["base_health"] = 140
	main.planning.combat["health"] = [63, 17]
	var accepted_health_state: Dictionary = main.planning.combat.duplicate(true)
	main.planning.changed.emit()
	screen._refresh()
	_check(main.planning.combat == accepted_health_state and screen._health_bar.max_value == 140 and screen._health_bar.value == 63, "Repeated health refresh neither mutates accepted health nor retains a previous maximum")
	var rarity_colors: Array[Color] = []
	for rarity: String in TowerRollRules.RARITIES:
		var color: Color = MatchPlanningScreen.tower_rarity_color({"rarity": rarity})
		_check(not rarity_colors.has(color), "Every accepted rarity has a distinct static title color")
		rarity_colors.append(color)
	_check(not screen.special_upgrade.visible and not screen.alternate_upgrade.visible and screen.damage_upgrade.visible and screen.speed_upgrade.visible, "Evolution choices are hidden until both stat upgrades")
	var definition: Dictionary = main.planning.combat["tower_types"]["orc_ballista"]
	_check(model.upgrade_tower(0, id, "damage"), "First real stat upgrade succeeds")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(not screen.special_upgrade.visible and not screen.damage_upgrade.visible and screen.speed_upgrade.visible and not screen.speed_upgrade.disabled, "Purchasing one stat hides only that upgrade and preserves its unpurchased sibling")
	_check(model.upgrade_tower(0, id, "speed"), "Second real stat upgrade succeeds")
	model.towers[0][0]["kills"] = 7
	model.towers[0][0]["damage_dealt"] = 12345
	model.towers[0][0]["coins_generated"] = 456
	model.towers[0][0]["indirect_damage"] = 789
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	var accepted_counters: Dictionary = model.snapshot()
	screen._refresh()
	_check(model.snapshot() == accepted_counters, "Repeated inspection refresh cannot reset kills or other lifetime statistics")
	_check(screen.damage_upgrade.disabled and screen.speed_upgrade.disabled, "Purchased upgrades cannot be bought twice in management")
	_check(screen.special_upgrade.visible and screen.alternate_upgrade.visible and not screen.damage_upgrade.visible and not screen.speed_upgrade.visible and not screen.special_upgrade.disabled and not screen.alternate_upgrade.disabled, "Both purchased Ballista stats expose two affordable evolution choices")
	var pierce_price: int = int(definition["evolutions"]["pierce"]["cost"])
	model.coins[0] = pierce_price - 1
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.special_upgrade.disabled, "Pierce affordability follows its accepted evolution price")
	model.coins[0] = pierce_price
	_check(model.upgrade_tower(0, id, "pierce"), "Exact configured price buys Pierce")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen._special_upgrade_command == "bounce" and screen.special_upgrade.disabled and MatchCombat.tower_level(model.towers[0][0]) == 4, "Purchased evolution disappears while its excluded sibling remains unavailable")
	_check(screen._alternate_upgrade_command == "bigger_wood_1" and screen.alternate_upgrade.disabled, "Only the branch's next upgrade is offered, and it follows affordability")
	screen.close_button.pressed.emit()
	_check(screen.selected_tower_id == -1 and model.towers[0].size() == 1, "Close clears selection without selling")
	screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
	_check(model.sell_tower(0, id), "Model sale succeeds")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.selected_tower_id == -1 and not screen.get_node("%TowerManagement").visible, "Sold selection disappears on accepted snapshot")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["orc_ballista"]}))
	main.planning.collection_store = CollectionStore.new(save_path)
	model.coins[0] = int(definition["cost"])
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	screen.shop_buttons[&"orc_ballista"].pressed.emit()
	model.coins[0] = int(definition["cost"]) - 1
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(screen.shop_buttons[&"orc_ballista"].disabled and screen._placement_type() == &"", "Insufficient host funds disable purchase and cancel stale placement")
	_check_send_visibility(main, screen)
	await _check_ballista_evolutions(main, screen)
	await _check_rune_evolutions(main, screen)
	await _check_archer_advancements(main, screen)
	await _check_debug_popup(main, screen)
	main.planning.stop_singleplayer()
	main.queue_free()
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: visible locked palette, click/cancel ownership, unlock/reset, effective owned stats, upgrades, Ballista and Rune evolution choices and command gates, close, sale and affordability snapshots")
	quit(1 if failures else 0)


func _check_ballista_evolutions(main: Control, screen: MatchPlanningScreen) -> void:
	main.play_screen.show()
	var planning: MatchPlanning = main.planning
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["orc_ballista"]}))
	planning.collection_store = CollectionStore.new(save_path)
	for evolution: String in ["pierce", "bounce"]:
		planning.start_singleplayer()
		_check(planning.select_loadout([&"arrow_tower", &"orc_ballista"]) and planning.commit_loadout(), "Ballista UI fixture commits only its owned towers")
		planning.set_physics_process(false)
		await create_timer(0.05).timeout
		var model: MatchCombat = planning._host_combat
		model.coins = [2000, 2000]
		planning.build_tower(0, Vector2i(3, 3), &"orc_ballista", MatchCombat.TargetMode.FURTHEST)
		_check(model.towers[0].size() == 1 and model.towers[1].size() == 1, "Real planning command creates mirrored Ballista fixtures")
		if model.towers[0].is_empty():
			planning.stop_singleplayer()
			await create_timer(0.2).timeout
			continue
		var tower: Dictionary = model.towers[0][0]
		var id: int = int(tower["id"])
		var choices: Dictionary = planning.combat["tower_types"]["orc_ballista"]["evolutions"]
		var price: int = int(choices[evolution]["cost"])
		var cheapest: int = mini(int(choices["pierce"]["cost"]), int(choices["bounce"]["cost"]))
		screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
		_check(not screen.special_upgrade.visible and not screen.alternate_upgrade.visible, "Ballista choices stay hidden before stat upgrades")
		var frozen: Dictionary = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		for command: String in ["pierce", "bounce", "special", "boulders", "onyx_ring", "freeze_runes"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Hidden Ballista buttons and authoritative branch commands cannot bypass prerequisites")
		var first: Button = screen.damage_upgrade if evolution == "pierce" else screen.speed_upgrade
		var second: Button = screen.speed_upgrade if evolution == "pierce" else screen.damage_upgrade
		first.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 2 and not screen.special_upgrade.visible and not screen.alternate_upgrade.visible, "Either first stat leaves Ballista choices hidden")
		frozen = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Ballista evolution rejects one missing stat prerequisite")
		second.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 3 and screen.special_upgrade.visible and screen.alternate_upgrade.visible and not screen.damage_upgrade.visible and not screen.speed_upgrade.visible, "Both stat orders expose the two Ballista branches")
		var chosen: Button = screen.special_upgrade if evolution == "pierce" else screen.alternate_upgrade
		var other: Button = screen.alternate_upgrade if evolution == "pierce" else screen.special_upgrade
		frozen = planning.combat.duplicate(true)
		for command: String in ["special", "boulders", "onyx_ring", "freeze_runes"]:
			screen._upgrade(command)
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Ballista choices never accept obsolete generic or Rune commands")
		model.coins = [cheapest - 1, cheapest - 1]
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.alternate_upgrade.disabled, "Insufficient funds disable both Ballista branches")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, "pierce")
		planning.upgrade_tower(0, id, "bounce")
		_check(planning.combat == frozen, "Unaffordable Ballista buttons and commands leave both boards untouched")
		model.coins = [price, price]
		planning._publish_snapshot()
		_check(not chosen.disabled, "Exact branch funds enable its purchase")
		planning.combat = planning.combat.duplicate(true)
		var captured_choice: Dictionary = planning.combat["tower_types"]["orc_ballista"]["evolutions"][evolution]
		captured_choice["cost"] = price + 1
		planning.changed.emit()
		_check(chosen.disabled, "Ballista choice affordability follows its host-captured configuration")
		planning._publish_snapshot()
		planning._host_ready[0] = true
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.alternate_upgrade.disabled, "Ready commits both Ballista choices")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Ready blocks Ballista buttons and authoritative purchase commands")
		planning._host_ready[0] = false
		planning._publish_snapshot()
		var stats_before: String = screen._tower_stats.text
		var damage_before: int = int(tower["damage"])
		var interval_before: float = float(tower["interval"])
		chosen.pressed.emit()
		for slot: int in range(2):
			var evolved: Dictionary = model.towers[slot][0]
			_check(evolved.get("evolution", "") == evolution and evolved["special_upgraded"] and MatchCombat.tower_level(evolved) == 4 and model.coins[slot] == 0, "Each native Ballista button buys its own branch with exact funds on both solo boards")
			_check(evolved["damage"] == damage_before and is_equal_approx(float(evolved["interval"]), interval_before), "Ballista branches preserve current upgraded attack stats")
		_check(screen._special_upgrade_command != evolution and screen._alternate_upgrade_command != evolution, "Purchased Ballista branch is absent from remaining controls")
		_check(screen._tower_stats.text == stats_before, "Ballista evolutions preserve ordinary attack-stat presentation")
		model.coins = [2000, 2000]
		planning._publish_snapshot()
		var first_step: String = String(choices[evolution]["upgrades"][0]["id"])
		var sibling: String = "bounce" if evolution == "pierce" else "pierce"
		_check(screen._special_upgrade_command == sibling and screen.special_upgrade.disabled, "Funded Ballista still exposes no enabled repeat or alternate branch purchase")
		_check(screen._alternate_upgrade_command == first_step and not screen.alternate_upgrade.disabled, "The funded branch offers exactly its next upgrade")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		for command: String in ["pierce", "bounce", "special", "boulders", "onyx_ring", "freeze_runes", "bigger_wood_2", "magic_ballista" if evolution == "pierce" else "bigger_wood_1"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen and screen.selected_tower_id == id and screen.boards[0].selected_tower_id == id, "Purchased Ballista preserves the selected tower and rejects repeated purchases, the other branch, out-of-order steps, and unrelated commands even with funds")
		screen.alternate_upgrade.pressed.emit()
		for slot: int in range(2):
			_check(model.towers[slot][0]["branch_upgrades"] == [first_step] and MatchCombat.tower_level(model.towers[slot][0]) == 5, "The next-step button buys exactly that branch upgrade on both solo boards")
		planning.stop_singleplayer()
		await create_timer(0.2).timeout


func _check_rune_evolutions(main: Control, screen: MatchPlanningScreen) -> void:
	main.play_screen.show()
	var planning: MatchPlanning = main.planning
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["rune_obelisk"]}))
	planning.collection_store = CollectionStore.new(save_path)
	for evolution: String in ["boulders", "onyx_ring"]:
		planning.start_singleplayer()
		_check(planning.select_loadout([&"arrow_tower", &"rune_obelisk"]) and planning.commit_loadout(), "Rune UI fixture commits only its owned towers")
		planning.set_physics_process(false)
		await create_timer(0.05).timeout
		var model: MatchCombat = planning._host_combat
		model.coins = [2000, 2000]
		planning.build_tower(0, Vector2i(3, 3), &"rune_obelisk", MatchCombat.TargetMode.FURTHEST)
		_check(model.towers[0].size() == 1 and model.towers[1].size() == 1, "Real planning command creates mirrored Rune fixtures")
		if model.towers[0].is_empty():
			planning.stop_singleplayer()
			await create_timer(0.2).timeout
			continue
		var tower: Dictionary = model.towers[0][0]
		var id: int = int(tower["id"])
		var price: int = int(planning.combat["tower_types"]["rune_obelisk"]["evolutions"][evolution]["cost"])
		screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
		_check(not screen.special_upgrade.visible and not screen.alternate_upgrade.visible, "Both evolution buttons stay hidden at level I")
		var frozen: Dictionary = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		for command: String in ["boulders", "onyx_ring", "special", "freeze_runes"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Hidden buttons and real evolution commands cannot bypass level-I prerequisites")
		var first: Button = screen.damage_upgrade if evolution == "boulders" else screen.speed_upgrade
		var second: Button = screen.speed_upgrade if evolution == "boulders" else screen.damage_upgrade
		first.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 2 and not screen.special_upgrade.visible and not screen.alternate_upgrade.visible, "Either first stat leaves both evolution buttons hidden")
		frozen = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "A real evolution command rejects one missing prerequisite")
		second.pressed.emit()
		_check(MatchCombat.tower_level(tower) == 3 and screen.special_upgrade.visible and screen.alternate_upgrade.visible and not screen.damage_upgrade.visible and not screen.speed_upgrade.visible, "Both stat purchase orders expose exactly the two Rune evolution choices at level III")
		model.coins = [price - 1, price - 1]
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.alternate_upgrade.disabled, "Both choices become unavailable one Coin short")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Unaffordable button presses and authoritative commands leave both boards untouched")
		model.coins = [price, price]
		planning._publish_snapshot()
		_check(not screen.special_upgrade.disabled and not screen.alternate_upgrade.disabled, "Exact funds enable both exclusive alternatives")
		planning._host_ready[0] = true
		planning._publish_snapshot()
		_check(screen.special_upgrade.disabled and screen.alternate_upgrade.disabled, "Committed Ready disables both affordable branches")
		frozen = planning.combat.duplicate(true)
		screen.special_upgrade.pressed.emit()
		screen.alternate_upgrade.pressed.emit()
		planning.upgrade_tower(0, id, evolution)
		_check(planning.combat == frozen, "Committed buttons and real commands cannot purchase an evolution")
		planning._host_ready[0] = false
		planning._publish_snapshot()
		var chosen: Button = screen.special_upgrade if evolution == "boulders" else screen.alternate_upgrade
		var other: Button = screen.alternate_upgrade if evolution == "boulders" else screen.special_upgrade
		chosen.pressed.emit()
		for slot: int in range(2):
			var evolved: Dictionary = model.towers[slot][0]
			_check(evolved.get("evolution", "") == evolution and evolved["special_upgraded"] and MatchCombat.tower_level(evolved) == 4 and model.coins[slot] == 0, "Button command purchases the chosen evolution with exact funds on both real boards")
		if evolution == "boulders":
			_check(screen.special_upgrade.is_visible_in_tree() and not screen.alternate_upgrade.is_visible_in_tree() and screen._special_upgrade_command == "freeze_runes", "Purchased Boulders replaces branch purchases with its reachable follow-up")
		else:
			_check(screen._special_upgrade_command != evolution and screen._alternate_upgrade_command != evolution and not chosen.is_visible_in_tree() and screen.special_upgrade.disabled, "Purchased Onyx is hidden and the excluded branch cannot be bought")
		frozen = planning.combat.duplicate(true)
		chosen.pressed.emit()
		other.pressed.emit()
		for command: String in ["boulders", "onyx_ring", "special", "freeze_runes"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen, "Purchased UI and real commands reject repeats, the other branch, and obsolete generic special")
		model.coins = [2000, 2000]
		planning._publish_snapshot()
		frozen = planning.combat.duplicate(true)
		if evolution == "boulders":
			_check(screen.special_upgrade.is_visible_in_tree() and not screen.alternate_upgrade.is_visible_in_tree() and screen._special_upgrade_command == "freeze_runes" and not screen.special_upgrade.disabled, "Funded Boulders exposes only its legitimate follow-up, not a repeat or branch switch")
		else:
			_check(not chosen.is_visible_in_tree() and screen.special_upgrade.disabled, "Funded Onyx exposes no enabled repeat or alternate branch purchase")
			chosen.pressed.emit()
			other.pressed.emit()
		for command: String in ["boulders", "onyx_ring", "special"]:
			planning.upgrade_tower(0, id, command)
		_check(planning.combat == frozen and screen.selected_tower_id == id and screen.boards[0].selected_tower_id == id, "Funded Rune branch attempts preserve the accepted selection and both boards")
		if evolution == "boulders":
			_check(screen.special_upgrade.visible and not screen.alternate_upgrade.visible, "Boulders replaces the exclusive choices with its follow-up control")
			var followup: Dictionary = planning.combat["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"]
			var followup_price: int = int(followup["cost"])
			model.coins = [followup_price - 1, followup_price - 1]
			planning._publish_snapshot()
			_check(screen.special_upgrade.disabled, "Follow-up affordability uses the accepted Boulders configuration")
			model.coins = [followup_price, followup_price]
			planning._publish_snapshot()
			_check(not screen.special_upgrade.disabled, "Exact funds enable Boulders' second evolution")
			# A host-captured catalog, not a hardcoded UI price, governs affordability.
			planning.combat = planning.combat.duplicate(true)
			var captured_followup: Dictionary = planning.combat["tower_types"]["rune_obelisk"]["evolutions"]["boulders"]["followup"]
			captured_followup["cost"] = followup_price + 1
			planning.changed.emit()
			_check(screen.special_upgrade.disabled, "Follow-up control follows a changed accepted catalog cost")
			planning._publish_snapshot()
			var stats_before: String = screen._tower_stats.text
			planning._host_ready[0] = true
			planning._publish_snapshot()
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			_check(screen.special_upgrade.disabled and planning.combat == frozen, "Ready also commits the follow-up purchase")
			planning._host_ready[0] = false
			planning._publish_snapshot()
			screen.special_upgrade.pressed.emit()
			for slot: int in range(2):
				_check(model.towers[slot][0].get("freeze_upgraded", false) and MatchCombat.tower_level(model.towers[slot][0]) == 5 and model.coins[slot] == 0, "Follow-up button dispatches its real command and reaches level V on both solo boards")
			_check(not screen.special_upgrade.visible and not screen.alternate_upgrade.visible and screen._tower_stats.text == stats_before, "Purchased follow-up disappears without changing continuous damage stats or reviving Onyx")
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			planning.upgrade_tower(0, id, "freeze_runes")
			_check(planning.combat == frozen, "Purchased follow-up rejects duplicate UI and model commands")
		else:
			model.coins = [2000, 2000]
			planning._publish_snapshot()
			frozen = planning.combat.duplicate(true)
			screen.special_upgrade.pressed.emit()
			planning.upgrade_tower(0, id, "freeze_runes")
			_check(planning.combat == frozen and MatchCombat.tower_level(tower) == 4 and not tower.get("freeze_upgraded", false), "Onyx never exposes or accepts the Boulders follow-up")
		planning.stop_singleplayer()
		# Let the audio mixer release each stopped solo fixture before starting another.
		await create_timer(0.2).timeout


func _check_archer_advancements(main: Control, screen: MatchPlanningScreen) -> void:
	main.play_screen.show()
	var planning: MatchPlanning = main.planning
	var save_path: String = directory.path_join("collection.json")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unlocked": ["arrow_tower"]}))
	planning.collection_store = CollectionStore.new(save_path)
	var original_size: Vector2i = root.size
	for branch: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
		planning.start_singleplayer()
		_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Archer UI fixture commits its owned starter")
		planning.set_physics_process(false)
		await create_timer(0.05).timeout
		var model: MatchCombat = planning._host_combat
		model.coins = [10000, 10000]
		planning.build_tower(0, Vector2i(3, 3), &"arrow_tower", MatchCombat.TargetMode.FURTHEST)
		var tower: Dictionary = model.towers[0][0]
		var id: int = int(tower["id"])
		screen._cell_clicked(Vector2i(3, 3), MOUSE_BUTTON_LEFT, 0)
		await _check_upgrade_order(screen, 2)
		var frozen: Dictionary = planning.combat.duplicate(true)
		for button: Button in screen.advancement_buttons.values():
			button.pressed.emit()
		planning.upgrade_tower(0, id, branch)
		_check(planning.combat == frozen, "Hidden Arrow advancement controls cannot bypass prerequisites")
		screen.damage_upgrade.pressed.emit()
		screen.speed_upgrade.pressed.emit()
		_check(not screen.advancement_buttons["four_archers"].visible and screen.special_upgrade.visible, "Both stats expose Second Archer, not level-V choices")
		frozen = planning.combat.duplicate(true)
		planning.upgrade_tower(0, id, branch)
		_check(planning.combat == frozen, "Level-V purchase requires the accepted fourth level")
		screen.special_upgrade.pressed.emit()
		_check(screen.advancement_buttons["four_archers"].visible and not screen.special_upgrade.visible and MatchCombat.tower_level(tower) == 4, "Second Archer replaces its action with three advancement choices")
		await _check_shared_archer_targeting(planning, screen, 2)
		await _check_upgrade_order(screen, 3)
		var choices: Dictionary = planning.combat["tower_types"]["arrow_tower"]["advancements"]
		var price: int = int(choices[branch]["cost"])
		var chosen: Button = screen.advancement_buttons[branch]
		model.coins = [price - 1, price - 1]
		planning._publish_snapshot()
		_check(chosen.disabled, "Arrow path affordability uses the accepted exact price")
		frozen = planning.combat.duplicate(true)
		chosen.pressed.emit()
		planning.upgrade_tower(0, id, branch)
		_check(planning.combat == frozen, "Insufficient funds reject both button and command")
		model.coins = [price, price]
		planning._host_ready[0] = true
		planning._publish_snapshot()
		frozen = planning.combat.duplicate(true)
		chosen.pressed.emit()
		planning.upgrade_tower(0, id, branch)
		_check(chosen.disabled and planning.combat == frozen, "Ready commits Arrow path purchases")
		planning._host_ready[0] = false
		planning._publish_snapshot()
		chosen.pressed.emit()
		_check(tower["advancement"] == branch and MatchCombat.tower_level(tower) == 5 and model.coins == [0, 0], "Native advancement control buys its exclusive fifth level through mirrored owner commands")
		for command: String in ["four_archers", "fire_arrows", "bomb_arrows"]:
			_check(not screen.advancement_buttons[command].is_visible_in_tree(), "Purchased and excluded branch choices leave no stale actions")
		await _check_shared_archer_targeting(planning, screen, 4 if branch == "four_archers" else 2)
		await _check_upgrade_order(screen)
		await _check_targeting_input_guards(planning, screen)
		# A stale enabled HUD must not display a request rejected by committed Ready.
		planning._host_ready[0] = true
		var rejected_mode: int = screen.targeting_button.mode
		await _press_cycle_button(screen.targeting_button.next_button)
		_check(screen.targeting_button.mode == rejected_mode and model.towers[0][0]["mode"] == rejected_mode, "An authoritative Ready rejection never optimistically advances the common policy")
		planning._publish_snapshot()
		frozen = planning.combat.duplicate(true)
		_check(screen.targeting_button.disabled and screen.targeting_button.previous_button.disabled and screen.targeting_button.next_button.disabled, "Ready disables both native targeting arrows")
		await _press_cycle_button(screen.targeting_button.next_button)
		planning.set_targeting(0, id, MatchCombat.TargetMode.LAST)
		_check(planning.combat == frozen, "Ready blocks disabled native targeting arrows and direct gateway commands")
		planning._host_ready[0] = false
		planning._publish_snapshot()
		await _check_upgrade_order(screen)
		var followups: Array = {
			"four_archers": ["eight_archers", "arrow_minigun"],
			"fire_arrows": ["molotov", "quick_pitch", "flamethrower"],
			"bomb_arrows": ["bigger_bombs", "anti_orc_grenades", "aom", "aom_speed_1", "aom_speed_2"],
		}[branch]
		for command: String in followups:
			var next_price: int = int(choices[command]["cost"])
			model.coins = [next_price, next_price]
			planning._publish_snapshot()
			var next_button: Button = screen.advancement_buttons[command]
			_check(next_button.is_visible_in_tree() and not next_button.disabled, "Immediate prerequisite exposes the next native branch purchase")
			await _check_upgrade_order(screen)
			await _press_cycle_button(next_button)
			_check(tower["advancement"] == command and model.coins == [0, 0], "Each deeper native upgrade charges the exact authored price on both mirrored boards")
			_check(tower["advancement_path"].back() == command, "Each accepted native branch purchase appends its history")
			var count: int = 8 if command == "eight_archers" else (2 if command in ["molotov", "quick_pitch", "bigger_bombs", "anti_orc_grenades"] else 1)
			await _check_shared_archer_targeting(planning, screen, count)
			await _check_upgrade_order(screen)
		model.coins = [10000, 10000]
		planning._publish_snapshot()
		frozen = planning.combat.duplicate(true)
		for command: String in screen.advancement_buttons:
			screen.advancement_buttons[command].pressed.emit()
			planning.upgrade_tower(0, id, command)
		planning.upgrade_tower(1, id, branch)
		_check(planning.combat == frozen, "Repeat, switch and foreign-owner branch commands are atomic rejections")
		planning.stop_singleplayer()
		await create_timer(0.2).timeout
	root.size = original_size

func _check_shared_archer_targeting(planning: MatchPlanning, screen: MatchPlanningScreen, count: int) -> void:
	var selectors: int = 0
	for control: Node in screen._management.find_children("*", "HBoxContainer", true, false):
		if control is TargetingCycle and control.is_visible_in_tree():
			selectors += 1
	_check(selectors == 1, "Every accepted archer tier exposes one common targeting cycle")
	for direction: int in [1, -1]:
		var expected_modes: Array = [MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.FURTHEST] if direction == 1 else [MatchCombat.TargetMode.STRONGEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.FURTHEST]
		for expected: int in expected_modes:
			await _press_cycle_button(screen.targeting_button.next_button if direction == 1 else screen.targeting_button.previous_button)
			for slot: int in range(2):
				var accepted: Dictionary = planning.combat["towers"][slot][0]
				var stats: Dictionary = planning.combat["tower_types"][accepted["type_id"]]
				_check(accepted["mode"] == expected and screen.targeting_button.mode == expected, "Native arrows cycle the accepted common tower policy on both mirrored boards")
				_check(MatchPlanningScreen.independent_weapon_count(accepted, stats) == count and accepted["extra_archers"].size() == maxi(0, count - 2), "Common policy changes preserve every accepted visual firing stream")


func _check_targeting_input_guards(planning: MatchPlanning, screen: MatchPlanningScreen) -> void:
	var cell: Vector2i = planning.combat["towers"][0][0]["cell"]
	var frozen: Dictionary = planning.combat.duplicate(true)
	screen.debug_button.pressed.emit()
	await process_frame
	screen.debug_money.get_line_edit().grab_focus()
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.pressed = pressed
		root.push_input(key, true)
		await process_frame
	_check(planning.combat == frozen, "Typing navigation in a debug field never changes the common targeting policy")
	screen.debug_popup.hide()
	screen._cell_clicked(cell, MOUSE_BUTTON_LEFT, 0)
	await process_frame
	var point: Vector2 = screen.targeting_button.next_button.get_global_rect().get_center()
	screen.open_pause_menu()
	await process_frame
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	_check(planning.combat == frozen, "The pause modal blocks native targeting input behind it")
	screen._resume_match()
	screen._cell_clicked(cell, MOUSE_BUTTON_LEFT, 0)
	await process_frame


func _check_upgrade_order(screen: MatchPlanningScreen, expected_choices: int = -1) -> void:
	var original_size: Vector2i = root.size
	var scroll: ScrollContainer = screen._management.find_child("InspectionScroll", true, false) as ScrollContainer
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		await process_frame
		await process_frame
		var buttons: Array = [screen.damage_upgrade, screen.speed_upgrade, screen.special_upgrade, screen.alternate_upgrade]
		buttons.append_array(screen._extra_upgrade_buttons.values())
		buttons.append_array(screen.advancement_buttons.values())
		var visible_buttons: Array[Button] = []
		for button: Button in buttons:
			if button.is_visible_in_tree():
				visible_buttons.append(button)
		if expected_choices >= 0:
			_check(visible_buttons.size() == expected_choices, "The accepted tier exposes all %d purchase choices together" % expected_choices)
		if not visible_buttons.is_empty():
			scroll.ensure_control_visible(visible_buttons[0])
			await process_frame
			await process_frame
			visible_buttons.sort_custom(func(left: Button, right: Button) -> bool: return left.get_global_rect().position.x < right.get_global_rect().position.x)
			var first_rect: Rect2 = visible_buttons[0].get_global_rect()
			var previous_end: float = first_rect.position.x
			for button: Button in visible_buttons:
				var button_rect: Rect2 = button.get_global_rect()
				_check(scroll.get_global_rect().encloses(button_rect), "All purchase choices, including locked actions, fit simultaneously inside the inspector at width %d" % width)
				_check(is_equal_approx(button_rect.position.y, first_rect.position.y) and is_equal_approx(button_rect.size.y, first_rect.size.y), "Every visible purchase shares one horizontal row and consistent height at width %d" % width)
				_check(button_rect.position.x >= previous_end, "Side-by-side purchase choices never overlap at width %d" % width)
				_check(button_rect.end.y <= screen.sell_button.get_global_rect().position.y, "The single purchase row consistently precedes Sell at width %d" % width)
				previous_end = button_rect.end.x
		scroll.ensure_control_visible(screen.sell_button)
		await process_frame
		await process_frame
		_check(screen._management.get_global_rect().encloses(screen.sell_button.get_global_rect()), "Sell remains the reachable final action at width %d" % width)
		scroll.ensure_control_visible(screen.targeting_button)
		await process_frame
		await process_frame
		for control: Control in [screen.targeting_button.previous_button, screen.targeting_button.mode_label, screen.targeting_button.next_button]:
			_check(screen._management.get_global_rect().encloses(control.get_global_rect()), "The common targeting cycle fits the scrolled inspector at width %d" % width)
	root.size = original_size
	await process_frame



func _check_debug_popup(main: Control, screen: MatchPlanningScreen) -> void:
	var planning: MatchPlanning = main.planning
	planning.start_singleplayer()
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Debug UI fixture commits its owned starter")
	planning.set_physics_process(false)
	_check(planning.debug_set_values(1, int(planning.combat["coins"][0]), 71), "Debug UI fixture starts with an explicitly accepted non-default Shard balance")
	await create_timer(0.05).timeout
	_check(screen.debug_button.visible and planning.can_debug(), "Solo exposes the compact authoritative debug control")
	var original_size: Vector2i = root.size
	for width: int in [1000, 1280]:
		root.size = Vector2i(width, 720)
		await process_frame
		var world_rect: Rect2 = screen.world.get_global_rect()
		var header: Control = screen.get_node("HUD/Header")
		var header_rect: Rect2 = header.get_global_rect()
		screen.debug_button.pressed.emit()
		await process_frame
		_check(screen.debug_popup.visible and int(screen.debug_round.value) == 1 and int(screen.debug_money.value) == int(planning.combat["coins"][0]) and int(screen.debug_shards.value) == int(planning.combat["reroll_currency"][0]), "Opening debug uses accepted displayed round and own Coins/Shards")
		_check(screen.debug_shards.get_line_edit().get_theme_font("font") == screen.debug_money.get_line_edit().get_theme_font("font"), "Shard input uses the same legible numeric font as money")
		var popup_rect := Rect2(Vector2.ZERO, Vector2(screen.debug_popup.size))
		var round_rect: Rect2 = screen.debug_round.get_global_rect()
		var money_rect: Rect2 = screen.debug_money.get_global_rect()
		var shards_rect: Rect2 = screen.debug_shards.get_global_rect()
		var apply_rect: Rect2 = screen.debug_apply.get_global_rect()
		_check(popup_rect.encloses(round_rect) and popup_rect.encloses(money_rect) and popup_rect.encloses(shards_rect) and popup_rect.encloses(apply_rect) and round_rect.end.y <= money_rect.position.y and money_rect.end.y <= shards_rect.position.y and shards_rect.end.y <= apply_rect.position.y, "All three numeric rows and Apply fit the popup without overlap at width %d" % width)
		_check(screen.world.get_global_rect() == world_rect and header.get_global_rect() == header_rect, "Opening the debug popup cannot reflow world or HUD at width %d" % width)
		_check(Rect2(screen.global_position, screen.size).encloses(screen.debug_button.get_global_rect()), "Tiny debug control stays inside the game surface at width %d" % width)
		var camera_position: Vector2 = screen.world.camera.position
		var camera_zoom: Vector2 = screen.world.camera.zoom
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = screen.world.size * 0.5
		screen.world._handle_camera_input(wheel)
		var key := InputEventKey.new()
		key.keycode = KEY_D
		key.pressed = true
		screen.world._handle_camera_input(key)
		screen.world._process(0.2)
		_check(screen.world.camera.position == camera_position and screen.world.camera.zoom == camera_zoom and screen.world._world_viewport.gui_disable_input, "Popup scroll, typing and board input remain isolated from the world")
		screen.debug_round.value = 1001
		screen.debug_money.value = 1000000001
		screen.debug_shards.value = 1000000001
		_check(int(screen.debug_round.value) == 1000 and int(screen.debug_money.value) == 1000000000 and int(screen.debug_shards.value) == 1000000000, "Popup accepts the full supported upper bounds without overflowing")
		screen.debug_round.value = 0
		screen.debug_money.value = -1
		screen.debug_shards.value = -1
		_check(int(screen.debug_round.value) == 1 and int(screen.debug_money.value) == 0 and int(screen.debug_shards.value) == 0, "Popup keeps all three values inside their supported lower bounds")
		var before: Dictionary = planning._snapshot().duplicate(true)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		screen.debug_popup.window_input.emit(escape)
		_check(not screen.debug_popup.visible and not screen.world._world_viewport.gui_disable_input and planning._snapshot() == before, "Escape discards drafts and restores board input without changing accepted balances")
		screen.debug_button.pressed.emit()
		await process_frame
		_check(int(screen.debug_shards.value) == int(planning.combat["reroll_currency"][0]), "Reopening after cancel discards the unaccepted Shard draft at width %d" % width)
		var next_shards: int = width + 17
		screen.debug_round.get_line_edit().text = "1"
		screen.debug_money.get_line_edit().text = str(planning.combat["coins"][0])
		screen.debug_shards.get_line_edit().text = str(next_shards)
		screen.debug_apply.pressed.emit()
		_check(not screen.debug_popup.visible and planning.combat["reroll_currency"] == [next_shards, next_shards] and not screen.world._world_viewport.gui_disable_input, "Typed Shards apply through the solo transaction and release modal input at width %d" % width)
		screen.debug_button.pressed.emit()
		await process_frame
		_check(int(screen.debug_shards.value) == next_shards, "Reopened popup initializes from the new accepted Shards at width %d" % width)
		screen.debug_popup.hide()
	root.size = original_size
	await process_frame
	await _check_debug_path_drag(screen)
	screen.debug_button.pressed.emit()
	screen.debug_round.get_line_edit().text = "31"
	screen.debug_money.get_line_edit().text = "123456"
	screen.debug_shards.get_line_edit().text = "4567"
	screen.debug_apply.pressed.emit()
	_check(not screen.debug_popup.visible and int(planning.combat["wave"]) == 30 and planning.combat["coins"] == [123456, 123456] and planning.combat["reroll_currency"] == [4567, 4567], "Apply commits typed round, Coins and Shards through the real authoritative operation and closes")
	screen.debug_button.pressed.emit()
	_check(int(screen.debug_round.value) == 31 and int(screen.debug_money.value) == 123456 and int(screen.debug_shards.value) == 4567, "Reopening reflects all accepted values rather than a stale draft")
	screen.debug_popup.hide()
	planning._host_combat.phase = MatchCombat.Phase.WAVE
	planning._host_combat.wave = 31
	planning._publish_snapshot()
	screen.debug_button.pressed.emit()
	_check(int(screen.debug_round.value) == 31, "During combat debug uses the current displayed round rather than the next one")
	screen.debug_apply.pressed.emit()
	_check(int(planning.combat["phase"]) == MatchCombat.Phase.WAVE and int(planning.combat["wave"]) == 31, "Applying the same displayed round preserves ongoing combat")
	screen.debug_button.pressed.emit()
	screen.open_pause_menu()
	_check(not screen.debug_popup.visible and screen.pause_menu.visible, "Pause closes debug before opening its own input layer")
	screen._resume_match()
	screen.debug_button.pressed.emit()
	main.play_screen.hide()
	_check(not screen.debug_popup.visible, "Leaving the play screen closes the debug window")
	main.play_screen.show()
	planning.start_singleplayer()
	_check(planning.select_loadout([&"arrow_tower"]) and planning.commit_loadout(), "Reopened debug UI fixture commits a fresh deck")
	planning.set_physics_process(false)
	await create_timer(0.05).timeout
	var was_host: bool = main.session.is_host
	var was_state: MultiplayerSession.State = main.session.state
	var was_peer: int = planning._active_peer_id
	planning.singleplayer = false
	main.session.is_host = false
	planning.changed.emit()
	_check(not screen.debug_button.visible, "Guests never receive the debug entry point")
	screen.debug_button.pressed.emit()
	_check(not screen.debug_popup.visible, "Programmatic guest presses cannot open debug")
	main.session.is_host = true
	main.session.state = MultiplayerSession.State.CONNECTED
	planning._active_peer_id = 77
	planning.changed.emit()
	_check(screen.debug_button.visible, "An active host retains the same local debug control")
	planning.singleplayer = true
	main.session.is_host = was_host
	main.session.state = was_state
	planning._active_peer_id = was_peer
	planning._host_combat.phase = MatchCombat.Phase.FINISHED
	planning._publish_snapshot()
	_check(not screen.debug_button.visible and not screen.debug_popup.visible, "Finished matches do not expose a revival control")
	planning.stop_singleplayer()
	await create_timer(0.2).timeout


func _check_debug_path_drag(screen: MatchPlanningScreen) -> void:
	screen.debug_button.pressed.emit()
	screen.debug_round.get_line_edit().text = "100"
	screen.debug_apply.pressed.emit()
	await create_timer(0.1).timeout
	screen.world.zoom_at(1.12, screen.world.get_global_rect().get_center())
	await create_timer(0.8).timeout
	var cells: Array[Vector2i] = [Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13)]
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var start: Vector2 = screen.world.cell_screen_position(0, cells[0])
		var press := InputEventMouseButton.new()
		press.position = start
		press.global_position = start
		press.button_index = button
		press.pressed = true
		Input.parse_input_event(press)
		root.push_input(press, true)
		await process_frame
		for cell: Vector2i in cells.slice(1):
			var motion := InputEventMouseMotion.new()
			motion.position = screen.world.cell_screen_position(0, cell)
			motion.global_position = motion.position
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
			Input.parse_input_event(motion)
			root.push_input(motion, true)
			await process_frame
			await process_frame
		var release := press.duplicate() as InputEventMouseButton
		release.position = screen.world.cell_screen_position(0, cells[-1])
		release.global_position = release.position
		release.pressed = false
		Input.parse_input_event(release)
		root.push_input(release, true)
		await process_frame
		for slot: int in range(2):
			for cell: Vector2i in cells:
				_check(screen.planning.layouts[slot].has_path(cell) == (button == MOUSE_BUTTON_LEFT), "Round-100 path strokes place/delete every dragged cell on both mirrored boards")


func _press_cycle_button(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await process_frame
			await process_frame
			break
		ancestor = ancestor.get_parent()
	if button.disabled:
		var point: Vector2 = button.get_global_rect().get_center()
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
	else:
		button.grab_focus()
		_check(button.has_focus(), "Targeting arrows support native keyboard focus")
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
	await process_frame


func _check_send_visibility(main: Control, screen: MatchPlanningScreen) -> void:
	var rules: CombatRules = main.combat_rules.duplicate() as CombatRules
	# Keep the bounded terminal-visibility scenario independent of starting-health balance.
	rules.base_health = 10
	rules.catalog = rules.catalog.duplicate(true) as ContentCatalog
	for enemy: EnemyDefinition in rules.catalog.enemies:
		enemy.send_first_wave = 1
	var model := MatchCombat.new(rules)
	var income: Control = screen.get_node("%Income")
	_check(model.send_enemy(1, &"grunt"), "Opponent purchase creates a real incoming-only planning queue")
	_check(model.send_enemy(1, &"runner"), "A second purchase reserves a different type in the same incoming stream")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible, "An incoming queue remains discoverable even without local recurring income")
	var layout := PathLayout.new()
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 4))
	var routes: Array[Dictionary] = [layout.capture_routing(), layout.capture_routing()]
	_check(model.start_wave(routes), "Legal routes deliver the accepted queue")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible and model.queued_sends == [1, 0], "Incoming summary stays visible while a paced delivery remains pending")
	model.advance(main.combat_rules.send_spawn_interval)
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(not income.visible, "Delivered queues with no local income remove their obsolete HUD summary")
	_check(model.send_enemy(0, &"grunt"), "Real local send earns recurring income")
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(income.visible, "Earned recurring income remains visible after immediate delivery clears queues")
	for tick: int in range(5000):
		if model.phase == MatchCombat.Phase.PLANNING:
			model.start_wave(routes)
		model.advance(1.0 / 60.0)
		if model.phase == MatchCombat.Phase.FINISHED:
			break
	main.planning.combat = model.snapshot()
	main.planning.changed.emit()
	_check(model.phase == MatchCombat.Phase.FINISHED and not income.visible, "Terminal results hide income that can no longer pay out")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
