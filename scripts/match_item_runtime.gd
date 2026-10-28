class_name MatchItemRuntime
extends RefCounted
## Authoritative run ownership, command admission, clocks and detached item views.

const ACTIVE_STATS: Array[StringName] = [&"minute_hand_cannon", &"witchs_folded_ladder"]
const ACTIVE_DEFENSE: Array[StringName] = [&"bastion_in_a_bottle", &"the_walking_fortress"]
const PAW: StringName = &"monkeys_paw"

var _combat_ref: WeakRef
var combat: Variant:
	get:
		return _combat_ref.get_ref()
var definitions: Dictionary = {}
var boards: Array[Dictionary] = []
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var clock: float = 0.0
var stats: ItemStatEffects
var economy: ItemEconomyEffects
var combat_effects: ItemCombatEffects
var defense: ItemDefenseEffects
var progression: ItemProgressionEffects
var error_message: String = ""
var _legendary_pool: Array[String] = []
var _has_history: bool = false


func _init(owner: Variant, source: ContentCatalog, seed_value: int) -> void:
	_combat_ref = weakref(owner)
	random.seed = seed_value
	for _slot: int in range(2):
		boards.append({"owned": {}, "seen": {}, "cooldowns": {}, "active": {}, "economy": {}, "combat": {}, "defense": {}, "progression": {}})
	if source == null:
		error_message = "Item runtime requires a content catalog."
	else:
		_capture_definitions(source)
	stats = ItemStatEffects.new(self)
	economy = ItemEconomyEffects.new(self)
	combat_effects = ItemCombatEffects.new(self)
	defense = ItemDefenseEffects.new(self)
	progression = ItemProgressionEffects.new(self)


func _capture_definitions(source: ContentCatalog) -> void:
	var upgrade_only: Dictionary = {}
	for item: ItemDefinition in source.items:
		if item != null and item.upgrade_to != &"":
			upgrade_only[String(item.upgrade_to)] = true
	for item: ItemDefinition in source.items:
		if item == null or item.id == &"" or definitions.has(String(item.id)):
			error_message = "Item runtime contains a missing, empty or duplicate definition."
			continue
		var errors: PackedStringArray = ItemStatEffects.validate_runtime(item.runtime)
		if not errors.is_empty():
			error_message = "Item '%s' runtime: %s" % [item.id, "; ".join(errors)]
		definitions[String(item.id)] = {
			"id": String(item.id), "title": item.title, "rarity": int(item.rarity),
			"effect_text": item.effect_text, "mechanics": Array(item.mechanics),
			"icon_path": "" if item.icon_texture == null else item.icon_texture.resource_path,
			"detail_path": "" if item.detail_texture == null else item.detail_texture.resource_path,
			"runtime": item.runtime.duplicate(true), "upgrade_to": String(item.upgrade_to),
			"upgrade_cost": item.upgrade_cost, "acquisition_text": item.acquisition_text,
		}
		if item.rarity == ItemRarity.Tier.LEGENDARY and not upgrade_only.has(String(item.id)):
			_legendary_pool.append(String(item.id))


func state(slot: int) -> Dictionary:
	return boards[slot] if _valid_slot(slot) else {}


func has(slot: int, id: StringName) -> bool:
	return _valid_slot(slot) and boards[slot]["owned"].has(String(id))


func config(slot: int, id: StringName) -> Dictionary:
	if not _valid_slot(slot):
		return {}
	return definitions.get(String(id), {}).get("runtime", {})


func params(slot: int, id: StringName) -> Dictionary:
	return config(slot, id).get("parameters", {})


func owned_ids(slot: int) -> Array[String]:
	var result: Array[String] = []
	if _valid_slot(slot):
		for id: String in boards[slot]["owned"]:
			result.append(id)
	return result


func set_owned(slot: int, ids: Array) -> bool:
	if not _valid_slot(slot) or not error_message.is_empty():
		return false
	var next: Dictionary = {}
	for value: Variant in ids:
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		var id: String = String(value)
		if id.is_empty() or not definitions.has(id) or next.has(id):
			return false
		next[id] = true
	var board: Dictionary = boards[slot]
	var first_paw: bool = next.has(String(PAW)) and not board["seen"].has(String(PAW))
	if first_paw and _legendary_pool.is_empty():
		return false
	if next == board["owned"]:
		return true
	board["owned"] = next
	for id: String in next:
		board["seen"][id] = true
	if first_paw:
		# Draw from the complete eligible pool, including already owned results.
		# Duplicate rewards are valid and cannot reapply an owned item's effects.
		var reward: String = _legendary_pool[random.randi_range(0, _legendary_pool.size() - 1)]
		board["owned"][reward] = true
		board["seen"][reward] = true
		board["defense"]["paw_cursed"] = true
		board["defense"]["paw_reward"] = reward
	for id: Variant in board["active"].keys():
		if not board["owned"].has(id):
			board["active"].erase(id)
	_has_history = true
	economy.on_inventory_changed(slot)
	combat_effects.on_inventory_changed(slot)
	defense.on_inventory_changed(slot)
	progression.on_inventory_changed(slot)
	recompute(slot)
	return true


func grant(slot: int, id: StringName) -> bool:
	if not _valid_slot(slot) or not definitions.has(String(id)) or not error_message.is_empty():
		return false
	if has(slot, id):
		return true
	var ids: Array = owned_ids(slot)
	ids.append(String(id))
	return set_owned(slot, ids)


func remove(slot: int, id: StringName) -> bool:
	if not _valid_slot(slot) or not definitions.has(String(id)) or not error_message.is_empty():
		return false
	if not has(slot, id):
		return true
	var ids: Array = owned_ids(slot)
	ids.erase(String(id))
	return set_owned(slot, ids)


func configure_loadouts(loadouts: Array) -> void:
	progression.configure_loadouts(loadouts)


func recompute(slot: int = -1) -> void:
	combat.item_recompute(slot)


func can_command(slot: int, id: StringName, action: String, target_id: int = -1) -> bool:
	action = _normalize_action(action)
	if not error_message.is_empty() or not has(slot, id) or int(combat.phase) == 2:
		return false
	match action:
		"active":
			if id in ACTIVE_DEFENSE:
				return defense.can_activate(slot, id, target_id)
			return _can_activate_stats(slot, id, target_id)
		"bind":
			return id == &"worldroot_seed" and progression.can_bind(slot, id, target_id)
		"feed":
			return target_id == -1 and id == &"spore_spawn_of_marko" and combat_effects.can_feed(slot, id)
		"upgrade":
			return target_id == -1 and id == &"the_whole_shebang" and progression.can_upgrade(slot, id)
	return false


func command(slot: int, id: StringName, action: String, target_id: int = -1) -> bool:
	action = _normalize_action(action)
	if not can_command(slot, id, action, target_id):
		return false
	match action:
		"active":
			if id in ACTIVE_DEFENSE:
				return defense.activate(slot, id, target_id)
			var parameters: Dictionary = params(slot, id)
			boards[slot]["active"][String(id)] = {"remaining": float(parameters["duration"]), "target_id": target_id}
			boards[slot]["cooldowns"][String(id)] = float(parameters["cooldown"])
			recompute(slot)
			return true
		"bind":
			return progression.bind(slot, id, target_id)
		"feed":
			return combat_effects.feed(slot, id)
		"upgrade":
			return progression.upgrade(slot, id)
	return false


func _normalize_action(action: String) -> String:
	return "active" if action == "activate" else action


func _can_activate_stats(slot: int, id: StringName, target_id: int) -> bool:
	if id not in ACTIVE_STATS or int(combat.phase) != 1 or int(combat.base_health[slot]) <= 0:
		return false
	var board: Dictionary = boards[slot]
	if float(board["cooldowns"].get(String(id), 0.0)) > 0.0 or board["active"].has(String(id)):
		return false
	if id == &"witchs_folded_ladder":
		return target_id == -1
	for tower: Dictionary in combat.towers[slot]:
		if int(tower["id"]) == target_id:
			return ItemStatEffects.matches_filter(tower, "projectile")
	return false


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or int(combat.phase) != 1:
		return
	clock += delta
	if not _has_history:
		return
	for slot: int in range(2):
		var board: Dictionary = boards[slot]
		for id: String in board["cooldowns"]:
			board["cooldowns"][id] = maxf(0.0, float(board["cooldowns"][id]) - delta)
		var expired: bool = false
		for id: Variant in board["active"].keys():
			var active: Dictionary = board["active"][id]
			active["remaining"] = maxf(0.0, float(active["remaining"]) - delta)
			if float(active["remaining"]) <= 0.0:
				board["active"].erase(id)
				expired = true
		if expired:
			recompute(slot)
	economy.advance(delta)
	combat_effects.advance(delta)
	defense.advance(delta)
func needs_combat_events() -> bool:
	for board: Dictionary in boards:
		if not board["active"].is_empty():
			return true
	return economy.needs_combat_events() or combat_effects.needs_combat_events() or defense.needs_combat_events()


func needs_attack_tracking() -> bool:
	return combat_effects.needs_attack_tracking()


func next_event_step(maximum: float) -> float:
	if not is_finite(maximum) or maximum <= 0.0 or not _has_history or int(combat.phase) != 1:
		return maximum
	var step: float = maximum
	for board: Dictionary in boards:
		for remaining: Variant in board["cooldowns"].values():
			if float(remaining) > 0.0:
				step = minf(step, float(remaining))
		for active: Dictionary in board["active"].values():
			if float(active["remaining"]) > 0.0:
				step = minf(step, float(active["remaining"]))
	step = economy.next_event_step(step)
	step = combat_effects.next_event_step(step)
	step = defense.next_event_step(step)
	return step


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in range(2):
		var board: Dictionary = boards[slot].duplicate(true)
		board["owned"] = owned_ids(slot)
		var entries: Dictionary = {}
		for id: String in board["owned"]:
			entries[id] = _entry_snapshot(slot, StringName(id))
		board["entries"] = entries
		result.append(board)
	return result


func _entry_snapshot(slot: int, id: StringName) -> Dictionary:
	var board: Dictionary = boards[slot]
	var active: Dictionary = board["active"].get(String(id), {})
	var entry: Dictionary = {
		"cooldown_remaining": float(board["cooldowns"].get(String(id), 0.0)),
		"active_remaining": float(active.get("remaining", 0.0)),
		"target_id": int(active.get("target_id", -1)),
		"actions": {}, "status": "",
	}
	if id in ACTIVE_STATS or id in ACTIVE_DEFENSE:
		entry["actions"]["active"] = _action_snapshot(slot, id, "active", "", 0, id == &"minute_hand_cannon")
	if id == &"worldroot_seed":
		entry["actions"]["bind"] = _action_snapshot(slot, id, "bind", "", 0, true)
		var root: Dictionary = board["progression"].get("worldroot", {})
		entry["charges"] = 0 if bool(root.get("consumed", false)) else 1
		entry["target_id"] = int(root.get("bound_id", -1))
		entry["status"] = "Destroyed" if bool(root.get("destroyed", false)) else ("Bound" if int(entry["target_id"]) >= 0 else "Unbound")
	if id == &"spore_spawn_of_marko":
		var feed_cost: int = economy.price(slot, "shards", int(params(slot, id)["feed_cost"]), "feed")
		entry["actions"]["feed"] = _action_snapshot(slot, id, "feed", "shards", feed_cost, false)
		entry["charges"] = int(board["combat"].get("spore_remaining", 0))
		entry["status"] = "Quota %d" % int(board["combat"].get("spore_quota", 0))
	if id == &"the_whole_shebang":
		var upgrade_cost: int = progression.upgrade_price(slot)
		entry["actions"]["upgrade"] = _action_snapshot(slot, id, "upgrade", "coins", upgrade_cost, false)
	if id == &"one_more_you_git":
		entry["charges"] = 0 if bool(board["defense"].get("one_more_consumed", false)) else 1
	if id == &"dreadmaws_second_heart":
		entry["status"] = "Reserve %.1f HP" % float(board["defense"].get("reserve", 0.0))
	return entry


func _action_snapshot(slot: int, id: StringName, action: String, currency: String, cost: int, targeted: bool) -> Dictionary:
	var targets: Array[int] = []
	var enabled: bool = false
	if targeted:
		for tower: Dictionary in combat.towers[slot]:
			var target_id: int = int(tower["id"])
			if can_command(slot, id, action, target_id):
				targets.append(target_id)
		enabled = not targets.is_empty()
	else:
		enabled = can_command(slot, id, action)
	return {"enabled": enabled, "cost": cost, "currency": currency, "requires_target": targeted, "target_ids": targets}


func _valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < boards.size()
