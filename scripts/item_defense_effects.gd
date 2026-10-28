class_name ItemDefenseEffects
extends RefCounted
## Owns crystal healing, received tower statuses and run-persistent defenses.

const EPSILON: float = 0.000000001
const WAVE_PHASE: int = 1
const MAX_HEALTH_ITEMS: Array[StringName] = [&"ironroot_bulb", &"troll_kings_molar", &"the_walking_fortress"]
const STUN_ITEMS: Array[StringName] = [&"trollhide_earplugs", &"trollhide_apron", &"bloodglass_hourglass"]
const WARD: StringName = &"bastion_in_a_bottle"
const FORTRESS: StringName = &"the_walking_fortress"
const PAW: StringName = &"monkeys_paw"
const STONER: StringName = &"philosophorers_stoner"
const SUTURES: StringName = &"crystal_sutures"
const HEART: StringName = &"dreadmaws_second_heart"
const LAST_CHANCE: StringName = &"one_more_you_git"

var _runtime_ref: WeakRef
var _runtime: Variant:
	get:
		return _runtime_ref.get_ref()


func _init(runtime: Variant) -> void:
	_runtime_ref = weakref(runtime)


func maximum_health(slot: int, unmodified_max: int) -> int:
	var maximum: float = float(unmodified_max)
	for id: StringName in MAX_HEALTH_ITEMS:
		if _runtime.has(slot, id):
			maximum += float(_runtime.params(slot, id)["max_health_add"])
	if bool(_state(slot).get("paw_cursed", false)):
		maximum *= float(_runtime.params(slot, PAW)["max_health_multiplier"])
	return maxi(1, floori(maximum + EPSILON))


func on_inventory_changed(slot: int) -> void:
	# Core also sets this before awarding Paw's first-grant reward. Never undo it.
	if _runtime.has(slot, PAW):
		_state(slot)["paw_cursed"] = true


func heal(slot: int, amount: float) -> int:
	var combat: Variant = _runtime.combat
	if amount <= 0.0 or not is_finite(amount) or int(combat.base_health[slot]) <= 0:
		return 0
	var state: Dictionary = _state(slot)
	var total: float = amount + float(state.get("heal_fraction", 0.0))
	var missing: int = maxi(0, int(combat.base_max_health[slot]) - int(combat.base_health[slot]))
	var accepted: float = minf(total, float(missing))
	var restored: int = floori(accepted + EPSILON)
	combat.base_health[slot] += restored
	state["heal_fraction"] = maxf(0.0, accepted - float(restored))
	var excess: float = maxf(0.0, total - accepted)
	if excess > 0.0 and _runtime.has(slot, STONER):
		var coins: float = float(state.get("overheal_coins_fraction", 0.0)) + excess * float(_runtime.params(slot, STONER)["overheal_coins_multiplier"])
		var payout: int = floori(coins + EPSILON)
		state["overheal_coins_fraction"] = maxf(0.0, coins - float(payout))
		if payout > 0:
			combat.item_credit(slot, "coins", payout)
	return restored


func leak(slot: int, _enemy: Dictionary, raw_damage: float) -> int:
	var combat: Variant = _runtime.combat
	if int(combat.base_health[slot]) <= 0 or raw_damage < 0.0 or not is_finite(raw_damage):
		return 0
	var state: Dictionary = _state(slot)
	var incoming: float = raw_damage * float(_runtime.progression.base_damage_multiplier())
	if _active(slot, WARD):
		var parameters: Dictionary = _runtime.params(slot, WARD)
		incoming -= minf(incoming * float(parameters["damage_prevent_fraction"]), float(parameters["damage_prevent_cap"]))
		_runtime.state(slot)["active"].erase(String(WARD))
	var damage: int = maxi(0, ceili(incoming - EPSILON))
	var before: int = int(combat.base_health[slot])
	var after: int = maxi(0, before - damage)
	if after == 0 and _runtime.has(slot, LAST_CHANCE) and not bool(state.get("one_more_consumed", false)):
		state["one_more_consumed"] = true
		var parameters: Dictionary = _runtime.params(slot, LAST_CHANCE)
		after = mini(before, int(parameters["health_remaining"]))
		for enemy: Dictionary in combat.enemies[slot]:
			if int(enemy["hp"]) > 0 and not _is_boss(enemy):
				combat.item_stun_enemy(slot, int(enemy["id"]), float(parameters["stun_duration"]))
	combat.base_health[slot] = after
	var lost: int = before - after
	var leaks: int = int(state.get("wave_leaks", 0)) + 1
	state["wave_leaks"] = leaks
	if leaks == 1:
		state["first_leak_loss"] = lost
	if _runtime.has(slot, HEART):
		state["reserve"] = float(state.get("reserve", 0.0)) + float(lost) * float(_runtime.params(slot, HEART)["reserve_fraction"])
	return lost


func on_boss_kill(slot: int, enemy: Dictionary) -> void:
	if not _runtime.has(slot, HEART) or not _is_boss(enemy):
		return
	var state: Dictionary = _state(slot)
	var reserve: float = float(state.get("reserve", 0.0))
	state["reserve"] = 0.0
	heal(slot, reserve)


func on_clear(slot: int, _round_number: int) -> void:
	var state: Dictionary = _state(slot)
	var amount: int = 0
	if _runtime.has(slot, SUTURES) and int(state.get("wave_leaks", 0)) == 1:
		amount = floori(float(state.get("first_leak_loss", 0)) * float(_runtime.params(slot, SUTURES)["heal_fraction"]) + EPSILON)
	_reset_wave_ledger(state)
	if amount > 0:
		heal(slot, float(amount))


func on_wave_start(slot: int) -> void:
	_reset_wave_ledger(_state(slot))


func on_wave_abandon(slot: int) -> void:
	var state: Dictionary = _state(slot)
	_reset_wave_ledger(state)
	state.erase("tower_slows")
	var active: Dictionary = _runtime.state(slot)["active"]
	active.erase(String(WARD))
	active.erase(String(FORTRESS))


func can_activate(slot: int, id: StringName, target_id: int = -1) -> bool:
	if slot < 0 or slot >= _runtime.boards.size() or id not in [WARD, FORTRESS] or target_id != -1:
		return false
	if not _runtime.has(slot, id) or int(_runtime.combat.phase) != WAVE_PHASE or int(_runtime.combat.base_health[slot]) <= 0:
		return false
	return float(_runtime.state(slot)["cooldowns"].get(String(id), 0.0)) <= EPSILON and not _active(slot, id)


func activate(slot: int, id: StringName, target_id: int = -1) -> bool:
	if not can_activate(slot, id, target_id):
		return false
	var parameters: Dictionary = _runtime.params(slot, id)
	var board: Dictionary = _runtime.state(slot)
	board["active"][String(id)] = {"remaining": float(parameters["duration"]), "target_id": -1}
	board["cooldowns"][String(id)] = float(parameters["cooldown"])
	if id == FORTRESS:
		heal(slot, float(parameters["heal"]))
	return true


func stun_duration(slot: int, duration: float) -> float:
	if _active(slot, FORTRESS):
		return 0.0
	var result: float = maxf(0.0, duration)
	for id: StringName in STUN_ITEMS:
		if _runtime.has(slot, id):
			result *= float(_runtime.params(slot, id)["duration_multiplier"])
	return result


func tower_slow_duration(slot: int, duration: float) -> float:
	var result: float = maxf(0.0, duration)
	if _runtime.has(slot, &"menders_spool"):
		result *= float(_runtime.params(slot, &"menders_spool")["duration_multiplier"])
	return result


func apply_tower_slow(slot: int, tower_id: int, multiplier: float, duration: float) -> bool:
	if slot < 0 or slot >= _runtime.boards.size() or not is_finite(multiplier) or not is_finite(duration) or multiplier <= 0.0 or multiplier >= 1.0 or duration <= 0.0:
		return false
	var found: bool = false
	for tower: Dictionary in _runtime.combat.towers[slot]:
		if int(tower["id"]) == tower_id:
			found = true
			break
	if not found:
		return false
	var state: Dictionary = _state(slot)
	if not state.has("tower_slows"):
		state["tower_slows"] = {}
	var slows: Dictionary = state["tower_slows"]
	if not slows.has(tower_id):
		slows[tower_id] = []
	var entries: Array = slows[tower_id]
	var expires: float = float(_runtime.clock) + tower_slow_duration(slot, duration)
	# Equal-strength refreshes retain one real deadline; weaker independent slows
	# can outlive a short stronger slow without lengthening the stronger one.
	for entry: Dictionary in entries:
		if is_equal_approx(float(entry["multiplier"]), multiplier):
			entry["expires_at"] = maxf(float(entry["expires_at"]), expires)
			_runtime.recompute(slot)
			return true
	entries.append({"multiplier": multiplier, "expires_at": expires})
	_runtime.recompute(slot)
	return true


func tower_attack_rate_multiplier(slot: int, tower: Dictionary) -> float:
	var result: float = 1.0
	var remaining: float = 0.0
	var slows: Dictionary = _state(slot).get("tower_slows", {})
	for entry: Dictionary in slows.get(int(tower["id"]), []):
		var wait: float = float(entry["expires_at"]) - float(_runtime.clock)
		if wait > EPSILON:
			result = minf(result, float(entry["multiplier"]))
			remaining = maxf(remaining, wait)
	tower["received_slow_multiplier"] = result
	tower["received_slow_remaining"] = remaining
	return result


func advance(_delta: float) -> void:
	for slot: int in range(_runtime.boards.size()):
		var slows: Dictionary = _state(slot).get("tower_slows", {})
		var changed: bool = false
		for tower_id: Variant in slows.keys():
			var entries: Array = slows[tower_id]
			for index: int in range(entries.size() - 1, -1, -1):
				if float(entries[index]["expires_at"]) <= float(_runtime.clock) + EPSILON:
					entries.remove_at(index)
					changed = true
			if entries.is_empty():
				slows.erase(tower_id)
		if changed:
			_runtime.recompute(slot)


func next_event_step(maximum: float) -> float:
	var result: float = maximum
	for slot: int in range(_runtime.boards.size()):
		var slows: Dictionary = _state(slot).get("tower_slows", {})
		for entries: Array in slows.values():
			for entry: Dictionary in entries:
				var wait: float = float(entry["expires_at"]) - float(_runtime.clock)
				if wait > EPSILON:
					result = minf(result, wait)
	return result


func needs_combat_events() -> bool:
	for slot: int in range(_runtime.boards.size()):
		if not _state(slot).get("tower_slows", {}).is_empty():
			return true
	return false


func _active(slot: int, id: StringName) -> bool:
	if not _runtime.has(slot, id):
		return false
	var active: Dictionary = _runtime.state(slot)["active"].get(String(id), {})
	return float(active.get("remaining", 0.0)) > EPSILON


func _state(slot: int) -> Dictionary:
	return _runtime.state(slot)["defense"]


func _is_boss(enemy: Dictionary) -> bool:
	return bool(_runtime.combat._enemy_types[String(enemy["type_id"])]["boss"])


func _reset_wave_ledger(state: Dictionary) -> void:
	state["wave_leaks"] = 0
	state["first_leak_loss"] = 0
