class_name ItemProgressionEffects
extends RefCounted
## Run-owned item ledgers. Only accepted lifecycle hooks advance progression.

const WORLDROOT: StringName = &"worldroot_seed"
const SHEBANG: StringName = &"the_whole_shebang"
const BANGBANG: StringName = &"the_whole_shebang_orcfeccion"
const DOOM: StringName = &"ominous_bells_of_doom"

var _runtime_ref: WeakRef
var _runtime: Variant:
	get:
		return _runtime_ref.get_ref()
var _configured: bool = false
var _terminals: Array[Dictionary] = [{}, {}]
var _doom_steps: int = 0
var _doom_wave: int = -1
var _doom_multiplier: float = 1.0


func _init(runtime: Variant) -> void:
	_runtime_ref = weakref(runtime)


func configure_loadouts(loadouts: Array) -> void:
	# The admitted loadout is immutable, including in Sandbox. Inventory edits
	# must never silently redefine an already historical checklist.
	if _configured or loadouts.size() != 2:
		return
	var authored: Dictionary = _runtime.combat._tower_types
	for slot: int in range(2):
		for raw_type: Variant in loadouts[slot]:
			var type_id: String = String(raw_type)
			if not authored.has(type_id):
				continue
			for terminal: Dictionary in _terminal_metadata(type_id, authored[type_id]):
				var key: String = type_id + ":" + String(terminal["id"])
				_terminals[slot][key] = terminal.duplicate(true)
	_configured = true
	for slot: int in range(2):
		on_inventory_changed(slot)


func _terminal_metadata(type_id: String, definition: Dictionary) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	var base: Array[String] = ["damage", "speed"]
	if not String(definition.get("special_upgrade", "")).is_empty():
		base.append("special")
	stages.append({"id": "/".join(base), "title": "Both upgrades", "commands": base.duplicate()})
	var advancements: Dictionary = definition.get("advancements", {})
	for command: String in advancements:
		var has_child: bool = false
		for candidate: Dictionary in advancements.values():
			if String(candidate.get("requires", "")) == command:
				has_child = true
				break
		if has_child:
			continue
		var chain: Array[String] = []
		var current: String = command
		while not current.is_empty() and advancements.has(current) and not chain.has(current):
			chain.push_front(current)
			current = String(advancements[current].get("requires", ""))
		var path: Array[String] = base.duplicate()
		path.append_array(chain)
		stages.append({"id": "/".join(path), "title": String(advancements[command]["title"]), "commands": path})
	for branch_id: String in definition.get("evolutions", {}):
		var branch: Dictionary = definition["evolutions"][branch_id]
		var branch_path: Array[String] = base.duplicate()
		branch_path.append(branch_id)
		stages.append({"id": "/".join(branch_path), "title": String(branch["title"]), "commands": branch_path.duplicate()})
		var optional: Dictionary = branch.get("followup", {})
		if not optional.is_empty():
			var followup_path: Array[String] = branch_path.duplicate()
			followup_path.append(String(optional["id"]))
			stages.append({"id": "/".join(followup_path), "title": String(optional["title"]), "commands": followup_path})
		for followup_id: String in branch.get("followups", {}):
			var followup_path: Array[String] = branch_path.duplicate()
			followup_path.append(followup_id)
			stages.append({"id": "/".join(followup_path), "title": String(branch["followups"][followup_id]["title"]), "commands": followup_path})
		var upgrade_path: Array[String] = branch_path.duplicate()
		for step: Dictionary in branch.get("upgrades", []):
			upgrade_path.append(String(step["id"]))
			stages.append({"id": "/".join(upgrade_path), "title": String(step["title"]), "commands": upgrade_path.duplicate()})
		for capstone: String in branch.get("capstones", {}):
			var capstone_path: Array[String] = upgrade_path.duplicate()
			for step: Dictionary in branch["capstones"][capstone]:
				capstone_path.append(String(step["id"]))
				stages.append({"id": "/".join(capstone_path), "title": String(step["title"]), "commands": capstone_path.duplicate()})
	for stage: Dictionary in stages:
		var commands: Array = stage["commands"]
		for branch_id: String in definition.get("evolutions", {}):
			if not commands.has(branch_id):
				continue
			var optional: Dictionary = definition["evolutions"][branch_id].get("followup", {})
			if not optional.is_empty() and not commands.has(String(optional["id"])):
				commands.append(String(optional["id"]))
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for candidate: Dictionary in stages:
		var commands: Array = candidate["commands"]
		var has_successor: bool = false
		for other: Dictionary in stages:
			var other_commands: Array = other["commands"]
			if other_commands.size() <= commands.size():
				continue
			var contains: bool = true
			for accepted: String in commands:
				if not other_commands.has(accepted):
					contains = false
					break
			if contains:
				has_successor = true
				break
		if has_successor:
			continue
		var id: String = "/".join(commands)
		if seen.has(id):
			continue
		seen[id] = true
		result.append({"id": id, "type_id": type_id, "title": candidate["title"], "commands": commands.duplicate()})
	return result


func on_inventory_changed(slot: int) -> void:
	var data: Dictionary = _state(slot)
	if not _configured or not _has_shebang(slot):
		return
	var ledger: Dictionary = data["shebang"]
	if bool(ledger["initialized"]):
		return
	ledger["initialized"] = true
	ledger["requirements"] = _terminals[slot].duplicate(true)
	for key: String in ledger["requirements"]:
		ledger["slots"][key] = {"tower_id": -1, "bonus": 0.0, "completed": false}
	# Towers maxed before the first grant qualify, but carry zero past growth.
	for tower: Dictionary in _runtime.combat.towers[slot]:
		on_tower_changed(slot, tower)


func on_tower_changed(slot: int, tower: Dictionary) -> void:
	if not _has_shebang(slot):
		return
	var ledger: Dictionary = _state(slot)["shebang"]
	if not bool(ledger["initialized"]):
		return
	for key: String in ledger["requirements"]:
		var terminal: Dictionary = ledger["requirements"][key]
		var registered: Dictionary = ledger["slots"][key]
		if int(registered["tower_id"]) >= 0 or not _matches_terminal(tower, terminal):
			continue
		registered["tower_id"] = int(tower["id"])
		registered["completed"] = true
	if not bool(ledger["activated"]) and not ledger["slots"].is_empty():
		var complete: bool = true
		for registered: Dictionary in ledger["slots"].values():
			if not bool(registered["completed"]):
				complete = false
				break
		ledger["activated"] = complete


func on_tower_sold(slot: int, tower: Dictionary) -> void:
	var data: Dictionary = _state(slot)
	var seed: Dictionary = data["worldroot"]
	if int(seed["bound_id"]) == int(tower["id"]):
		seed["bound_id"] = -1
		seed["damage_bonus"] = 0.0
		seed["destroyed"] = true
		# Sale destroys the actual item too, even if it was temporarily removed.
		if _runtime.has(slot, WORLDROOT):
			_runtime.remove(slot, WORLDROOT)
	for registered: Dictionary in data["shebang"]["slots"].values():
		if int(registered["tower_id"]) == int(tower["id"]):
			registered["tower_id"] = -1


func on_clear(slot: int, _round_number: int) -> void:
	var data: Dictionary = _state(slot)
	var seed: Dictionary = data["worldroot"]
	if _runtime.has(slot, WORLDROOT) and not bool(seed["destroyed"]) and not _tower(slot, int(seed["bound_id"])).is_empty():
		var parameters: Dictionary = _runtime.params(slot, WORLDROOT)
		seed["damage_bonus"] = minf(float(parameters["damage_cap"]), float(seed["damage_bonus"]) + float(parameters["damage_per_clear"]))
	var ledger: Dictionary = data["shebang"]
	if _has_shebang(slot) and bool(ledger["activated"]):
		var parameters: Dictionary = _runtime.params(slot, BANGBANG if _runtime.has(slot, BANGBANG) else SHEBANG)
		for registered: Dictionary in ledger["slots"].values():
			if _tower(slot, int(registered["tower_id"])).is_empty():
				continue
			registered["bonus"] = maxf(float(registered["bonus"]), minf(float(parameters["rate_cap"]), float(registered["bonus"]) + float(parameters["rate_per_clear"])))


func can_bind(slot: int, id: StringName, target_id: int) -> bool:
	if id != WORLDROOT or not _runtime.has(slot, WORLDROOT):
		return false
	var data: Dictionary = _runtime.state(slot)["progression"]
	var seed: Dictionary = data.get("worldroot", {})
	return not bool(seed.get("consumed", false)) and not bool(seed.get("destroyed", false)) and _attacker(_tower(slot, target_id))


func bind(slot: int, id: StringName, target_id: int) -> bool:
	if not can_bind(slot, id, target_id):
		return false
	var seed: Dictionary = _state(slot)["worldroot"]
	seed["bound_id"] = target_id
	seed["consumed"] = true
	_runtime.recompute(slot)
	return true


func damage_multiplier(slot: int, tower: Dictionary) -> float:
	if not _runtime.has(slot, WORLDROOT):
		return 1.0
	var seed: Dictionary = _state(slot)["worldroot"]
	if bool(seed["destroyed"]) or int(seed["bound_id"]) != int(tower.get("id", -1)) or not _attacker(tower):
		return 1.0
	return 1.0 + float(seed["damage_bonus"])


func attack_rate_bonus(slot: int, tower: Dictionary) -> float:
	if not _has_shebang(slot) or not _attacker(tower):
		return 0.0
	var ledger: Dictionary = _state(slot)["shebang"]
	if not bool(ledger["activated"]):
		return 0.0
	var parameters: Dictionary = _runtime.params(slot, BANGBANG if _runtime.has(slot, BANGBANG) else SHEBANG)
	for registered: Dictionary in ledger["slots"].values():
		if int(registered["tower_id"]) == int(tower.get("id", -1)):
			return minf(float(registered["bonus"]), float(parameters["rate_cap"]))
	return 0.0


func upgrade_price(slot: int) -> int:
	var definition: Dictionary = _runtime.definitions.get(String(SHEBANG), {})
	return _runtime.economy.price(slot, "coins", int(definition.get("upgrade_cost", 0)), "item_upgrade")


func can_upgrade(slot: int, id: StringName) -> bool:
	return id == SHEBANG and _runtime.has(slot, SHEBANG) and not _runtime.has(slot, BANGBANG) and int(_runtime.combat.coins[slot]) >= upgrade_price(slot)


func upgrade(slot: int, id: StringName) -> bool:
	if not can_upgrade(slot, id):
		return false
	var cost: int = upgrade_price(slot)
	var ids: Array[String] = _runtime.owned_ids(slot)
	ids.erase(String(SHEBANG))
	ids.append(String(BANGBANG))
	# The known replacement is validated before any debit; this is one owned-set
	# change, never two grants with an observable half-upgraded state.
	if not _runtime.set_owned(slot, ids):
		return false
	_runtime.combat.item_credit(slot, "coins", -cost)
	return true


func next_wave_number(current_wave: int) -> int:
	var slot: int = _doom_owner()
	if slot < 0:
		return current_wave + 1
	var step: int = int(_runtime.params(slot, DOOM)["wave_step"])
	return (floori(float(current_wave) / float(step)) + 1) * step


func on_wave_start(round_number: int) -> void:
	var slot: int = _doom_owner()
	_doom_wave = round_number
	if slot < 0:
		_doom_multiplier = 1.0
		return
	var parameters: Dictionary = _runtime.params(slot, DOOM)
	_doom_steps += 1
	_doom_multiplier = minf(float(parameters["damage_cap"]), float(parameters["damage_initial"]) + float(_doom_steps - 1) * float(parameters["damage_step"]))


func base_damage_multiplier() -> float:
	return _doom_multiplier if _doom_owner() >= 0 and _doom_wave >= 0 else 1.0


func _doom_owner() -> int:
	for slot: int in range(2):
		if _runtime.has(slot, DOOM):
			return slot
	return -1


func _has_shebang(slot: int) -> bool:
	return _runtime.has(slot, SHEBANG) or _runtime.has(slot, BANGBANG)


func _state(slot: int) -> Dictionary:
	var data: Dictionary = _runtime.state(slot)["progression"]
	if not data.has("worldroot"):
		data["worldroot"] = {"bound_id": -1, "consumed": false, "destroyed": false, "damage_bonus": 0.0}
	if not data.has("shebang"):
		data["shebang"] = {"initialized": false, "activated": false, "requirements": {}, "slots": {}}
	return data


func _tower(slot: int, tower_id: int) -> Dictionary:
	if tower_id < 0:
		return {}
	for tower: Dictionary in _runtime.combat.towers[slot]:
		if int(tower["id"]) == tower_id:
			return tower
	return {}


static func _attacker(tower: Dictionary) -> bool:
	return tower.get("behavior_kind", "") in ["attack", "chain", "catapult"]


static func _matches_terminal(tower: Dictionary, terminal: Dictionary) -> bool:
	if String(tower.get("type_id", "")) != String(terminal["type_id"]):
		return false
	var accepted: Array[String] = []
	for command: String in ["damage", "speed", "special"]:
		if bool(tower.get(command + "_upgraded", false)):
			accepted.append(command)
	if bool(tower.get("freeze_upgraded", false)):
		accepted.append("freeze_runes")
	for field: String in ["evolution", "followup"]:
		var command: String = String(tower.get(field, ""))
		if not command.is_empty():
			accepted.append(command)
	for field: String in ["advancement_path", "branch_upgrades"]:
		for command: String in tower.get(field, []):
			accepted.append(command)
	for command: String in terminal["commands"]:
		if not accepted.has(command):
			return false
	return true
