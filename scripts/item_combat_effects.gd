class_name ItemCombatEffects
extends RefCounted

const SPORE: StringName = &"spore_spawn_of_marko"
const SUN: StringName = &"sun_in_a_cage"
const BRACE: StringName = &"siege_carpenters_brace"
const EPSILON: float = 0.000000001

var _runtime_ref: WeakRef
var runtime: Variant:
	get:
		return _runtime_ref.get_ref()


func _init(owner: Variant) -> void:
	_runtime_ref = weakref(owner)


func _state(slot: int) -> Dictionary:
	var state: Dictionary = runtime.state(slot)["combat"]
	if not state.has("arrow_counts"):
		state.merge({"arrow_counts": {}, "chain_count": 0, "brace": {}, "sun": {}, "infected": {}, "infected_once": {}, "receipt": {}})
	return state


func hit_multiplier(slot: int, tower: Dictionary, enemy: Dictionary, context: Dictionary, time: float = -1.0) -> float:
	var result: float = 1.0
	var receipt: Dictionary = _state(slot)["receipt"]
	var sample_clock: float = runtime.clock if time < 0.0 else runtime.clock - (runtime.combat._elapsed - time)
	if runtime.has(slot, &"necromancers_receipt") and float(receipt.get(int(enemy["id"]), 0.0)) > sample_clock + EPSILON:
		result *= float(runtime.params(slot, &"necromancers_receipt")["damage_multiplier"])
	if tower.is_empty() or bool(context.get("item_only", false)):
		return result
	if runtime.has(slot, &"gravediggers_lantern") and String(enemy.get("original_birth_kind", enemy.get("birth_kind", ""))) in ["summon", "death_spawn"]:
		result *= float(runtime.params(slot, &"gravediggers_lantern")["damage_multiplier"])
	if runtime.has(slot, &"mooncap_jerky"):
		var parameters: Dictionary = runtime.params(slot, &"mooncap_jerky")
		result *= float(parameters["boss_multiplier"] if runtime.combat.item_enemy_is_boss(enemy) else parameters["nonboss_multiplier"])
	if runtime.has(slot, &"butchers_apron"):
		var parameters: Dictionary = runtime.params(slot, &"butchers_apron")
		if float(enemy["hp"]) < float(enemy["max_hp"]) * float(parameters["hp_fraction"]):
			result *= float(parameters["damage_multiplier"])
	var slowed: bool = bool(enemy.get("slowed", false)) if time < 0.0 else float(enemy.get("_step_slow_until", 0.0)) > time + EPSILON
	if runtime.has(slot, &"frostbite_nail") and slowed:
		result *= float(runtime.params(slot, &"frostbite_nail")["damage_multiplier"])
	if runtime.has(slot, &"watchmans_cup"):
		var parameters: Dictionary = runtime.params(slot, &"watchmans_cup")
		var progress: float = float(enemy["progress"]) if time < 0.0 else runtime.combat._historical_progress(enemy, time)
		if progress + EPSILON >= float(enemy["route"].size() - int(parameters["tiles"])):
			result *= float(parameters["damage_multiplier"])
	if runtime.has(slot, BRACE) and String(tower.get("type_id", "")) == "orc_ballista":
		var tracking: Dictionary = _state(slot)["brace"].get(int(tower["id"]), {})
		if not tracking.is_empty():
			var parameters: Dictionary = runtime.params(slot, BRACE)
			result *= 1.0 + minf(float(parameters["maximum_bonus"]), float(tracking["elapsed"]) * float(parameters["damage_per_second"]))
	return result


func continuous_damage_boundary(slot: int, enemy: Dictionary) -> int:
	if runtime.has(slot, &"butchers_apron"):
		var threshold: float = float(enemy["max_hp"]) * float(runtime.params(slot, &"butchers_apron")["hp_fraction"])
		if float(enemy["hp"]) >= threshold:
			return maxi(1, int(enemy["hp"]) - ceili(threshold) + 1)
	return int(enemy["hp"])


func before_attack(slot: int, tower: Dictionary, _context: Dictionary) -> void:
	if not runtime.has(slot, &"concucktion"):
		return
	var policies: Array = runtime.combat.item_available_target_modes(tower)
	if not policies.is_empty():
		tower["mode"] = policies[runtime.random.randi_range(0, policies.size() - 1)]


func ordinary_arrow(slot: int, tower: Dictionary, target_id: int, damage: float, element: StringName) -> void:
	if String(tower.get("type_id", "")) != "arrow_tower":
		return
	var config: Dictionary = tower.get("effective_attack_config", {})
	if not bool(tower.get("special_upgraded", false)) or int(config.get("archer_count", 2)) < 2 or String(config.get("weapon", "")) == "minigun":
		return
	var source: StringName = &""
	if runtime.has(slot, &"entire_quiver"):
		source = &"entire_quiver"
	elif runtime.has(slot, &"bottomless_quiver"):
		source = &"bottomless_quiver"
	if source == &"":
		return
	var counts: Dictionary = _state(slot)["arrow_counts"]
	var tower_id: int = int(tower["id"])
	counts[tower_id] = int(counts.get(tower_id, 0)) + 1
	var parameters: Dictionary = runtime.params(slot, source)
	if source == &"bottomless_quiver" and int(counts[tower_id]) % int(parameters["every"]) != 0:
		return
	var victim: Dictionary = _enemy(slot, target_id)
	var impact: Vector2 = runtime.combat._arrow_impacts.get(target_id, victim.get("pos", tower["aim"]))
	var copied_damage: float = damage * float(parameters["damage_multiplier"])
	runtime.combat.item_emit("extra_arrow", slot, impact, {"tower_id": tower_id, "target_id": target_id, "aim": impact, "damage_type": String(element), "damage": copied_damage, "source_item": String(source)})
	runtime.combat.item_arrow_copy(slot, tower, target_id, copied_damage, element, source)


func chain_released(slot: int, tower: Dictionary, hit_ids: Array) -> void:
	if not runtime.has(slot, &"clockwork_raincloud"):
		return
	var state: Dictionary = _state(slot)
	state["chain_count"] = int(state["chain_count"]) + 1
	var parameters: Dictionary = runtime.params(slot, &"clockwork_raincloud")
	if int(state["chain_count"]) % int(parameters["every"]) != 0:
		return
	for contact: Variant in hit_ids:
		var id: int = int(contact["id"]) if contact is Dictionary else int(contact)
		var enemy: Dictionary = _enemy(slot, id)
		var boss: bool = bool(contact.get("boss", false)) if contact is Dictionary else (not enemy.is_empty() and runtime.combat.item_enemy_is_boss(enemy))
		if boss:
			continue
		if not enemy.is_empty() and not runtime.combat._immune(enemy, &"lightning"):
			runtime.combat.item_stun_enemy(slot, id, float(parameters["stun_duration"]))
			runtime.combat.item_emit("raincloud_stun", slot, enemy["pos"], {"tower_id": tower["id"], "enemy_id": id, "duration": parameters["stun_duration"]})
		break


func after_damage(slot: int, _tower: Dictionary, enemy: Dictionary, amount: int, killed: bool, _context: Dictionary) -> void:
	if amount <= 0 or not killed:
		return
	var state: Dictionary = _state(slot)
	var id: int = int(enemy["id"])
	if runtime.has(slot, &"necromancers_receipt"):
		var parameters: Dictionary = runtime.params(slot, &"necromancers_receipt")
		for survivor: Dictionary in runtime.combat.enemies[slot]:
			if int(survivor.get("summoner_id", -1)) == id and int(survivor["hp"]) > 0:
				state["receipt"][int(survivor["id"])] = runtime.clock + float(parameters["duration"])
				survivor["receipt_remaining"] = float(parameters["duration"])
				runtime.combat.item_emit("necromancer_receipt", slot, survivor["pos"], {"enemy_id": survivor["id"], "duration": parameters["duration"]})
	if runtime.has(slot, SPORE) and state["infected"].has(id):
		var infection: Dictionary = state["infected"][id]
		# The last instant of an infection still belongs to its damaging exposure.
		if float(infection["remaining"]) >= -EPSILON:
			var radius: float = float(runtime.params(slot, SPORE)["spread_radius"])
			for survivor: Dictionary in runtime.combat.enemies[slot]:
				if int(survivor["hp"]) > 0 and Vector2(enemy["pos"]).distance_squared_to(survivor["pos"]) <= radius * radius:
					_infect(slot, survivor)
	state["infected"].erase(id)
	state["receipt"].erase(id)


func on_spawn(slot: int, enemy: Dictionary) -> void:
	if not runtime.has(slot, SPORE) or String(enemy.get("birth_kind", "")) == "transfer":
		return
	var state: Dictionary = _state(slot)
	_ensure_spore(slot)
	if int(state["spore_remaining"]) > 0 and _infect(slot, enemy):
		state["spore_remaining"] = int(state["spore_remaining"]) - 1


func _ensure_spore(slot: int) -> void:
	var state: Dictionary = _state(slot)
	if not state.has("spore_quota"):
		state["spore_quota"] = int(runtime.params(slot, SPORE)["initial_quota"])
		state["spore_remaining"] = state["spore_quota"]


func _infect(slot: int, enemy: Dictionary) -> bool:
	var state: Dictionary = _state(slot)
	var id: int = int(enemy["id"])
	if state["infected_once"].has(id) or int(enemy["hp"]) <= 0:
		return false
	var duration: float = float(runtime.params(slot, SPORE)["duration"])
	state["infected_once"][id] = true
	state["infected"][id] = {"remaining": duration}
	enemy["infected"] = true
	enemy["infected_remaining"] = duration
	runtime.combat.item_emit("spore_infected", slot, enemy["pos"], {"enemy_id": id, "duration": duration})
	return true


func can_feed(slot: int, id: StringName) -> bool:
	if id != SPORE or not runtime.has(slot, id) or int(runtime.combat.phase) == 2:
		return false
	var cost: int = runtime.economy.price(slot, "shards", int(runtime.params(slot, id)["feed_cost"]), "feed")
	return int(runtime.combat.reroll_currency[slot]) >= cost


func feed(slot: int, id: StringName) -> bool:
	if not can_feed(slot, id):
		return false
	_ensure_spore(slot)
	var cost: int = runtime.economy.price(slot, "shards", int(runtime.params(slot, id)["feed_cost"]), "feed")
	runtime.combat.item_credit(slot, "shards", -cost)
	var state: Dictionary = _state(slot)
	state["spore_quota"] = int(state["spore_quota"]) + 1
	if int(runtime.combat.phase) == 1:
		state["spore_remaining"] = int(state["spore_remaining"]) + 1
	_emit_pet(slot)
	return true


func track_activity(slot: int, tower: Dictionary, target: Dictionary, delta: float) -> void:
	var state: Dictionary = _state(slot)
	var tower_id: int = int(tower["id"])
	if runtime.has(slot, BRACE) and String(tower["type_id"]) == "orc_ballista":
		if target.is_empty():
			state["brace"].erase(tower_id)
			tower["item_brace_bonus"] = 0.0
		else:
			var bucket: int = runtime.combat.item_aim_bucket(tower, target)
			var tracking: Dictionary = state["brace"].get(tower_id, {})
			if tracking.is_empty() or int(tracking["target_id"]) != int(target["id"]) or int(tracking["bucket"]) != bucket:
				tracking = {"target_id": int(target["id"]), "bucket": bucket, "elapsed": 0.0}
				state["brace"][tower_id] = tracking
			if delta > 0.0:
				var parameters: Dictionary = runtime.params(slot, BRACE)
				tracking["elapsed"] = minf(float(parameters["maximum_bonus"]) / float(parameters["damage_per_second"]), float(tracking["elapsed"]) + delta)
			tower["item_brace_bonus"] = minf(float(runtime.params(slot, BRACE)["maximum_bonus"]), float(tracking["elapsed"]) * float(runtime.params(slot, BRACE)["damage_per_second"]))
	if not _sun_eligible(slot, tower):
		return
	var sun: Dictionary = state["sun"].get(tower_id, {})
	if sun.is_empty():
		sun = {"heat": 0.0, "shutdown": 0.0, "engaged": false}
		state["sun"][tower_id] = sun
	delta = maxf(0.0, delta - float(sun.get("paused_span", 0.0)))
	sun["paused_span"] = 0.0
	sun["engaged"] = delta > 0.0 and not target.is_empty() and float(sun["shutdown"]) <= EPSILON
	if not bool(sun["engaged"]):
		return
	var parameters: Dictionary = runtime.params(slot, SUN)
	sun["heat"] = float(sun["heat"]) + delta
	tower["item_sun_heat"] = sun["heat"]
	if float(sun["heat"]) + EPSILON < float(parameters["charge_duration"]):
		return
	sun["heat"] = 0.0
	sun["shutdown"] = float(parameters["shutdown_duration"])
	sun["engaged"] = false
	tower["item_sun_heat"] = 0.0
	tower["item_sun_shutdown"] = sun["shutdown"]
	var impact: Vector2 = target["pos"]
	var radius: float = float(parameters["radius"])
	var damage: float = float(tower["damage"]) * float(parameters["burst_multiplier"])
	runtime.combat.item_emit("sun_burst", slot, impact, {"tower_id": tower_id, "target_id": target["id"], "radius": radius, "damage": damage})
	var victims: Array[int] = []
	for enemy: Dictionary in runtime.combat.enemies[slot]:
		if int(enemy["hp"]) > 0 and impact.distance_squared_to(enemy["pos"]) <= radius * radius:
			victims.append(int(enemy["id"]))
	for id: int in victims:
		runtime.combat.item_damage(slot, id, damage, &"fire", SUN, tower, {"secondary": true, "no_crit": true})


func _sun_eligible(slot: int, tower: Dictionary) -> bool:
	return runtime.has(slot, SUN) and String(tower.get("type_id", "")) == "arrow_tower" and tower.get("effective_attack_config", {}).has("burn_dps")


func attack_disabled(slot: int, tower: Dictionary) -> bool:
	if not runtime.has(slot, SUN):
		return false
	var sun: Dictionary = _state(slot)["sun"].get(int(tower["id"]), {})
	return float(sun.get("shutdown", 0.0)) > EPSILON


func healing_multiplier(slot: int, enemy: Dictionary) -> float:
	if not runtime.has(slot, &"wormwood_censer") or not bool(enemy.get("burning", false)) or runtime.combat._immune(enemy, &"fire"):
		return 1.0
	var burn: Dictionary = runtime.combat._burns.get(int(enemy["id"]), {})
	var source: Dictionary = burn.get("source", {})
	if String(source.get("type_id", "")) != "arrow_tower":
		return 1.0
	return float(runtime.params(slot, &"wormwood_censer")["healing_multiplier"])


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for slot: int in range(2):
		var state: Dictionary = _state(slot)
		for tower_id: Variant in state["sun"].keys():
			var sun: Dictionary = state["sun"][tower_id]
			sun["paused_span"] = minf(delta, float(sun["shutdown"]))
			sun["shutdown"] = maxf(0.0, float(sun["shutdown"]) - delta)
			for tower: Dictionary in runtime.combat.towers[slot]:
				if int(tower["id"]) == int(tower_id):
					tower["item_sun_shutdown"] = sun["shutdown"]
		for enemy_id: Variant in state["receipt"].keys():
			var enemy: Dictionary = _enemy(slot, int(enemy_id))
			var remaining: float = maxf(0.0, float(state["receipt"][enemy_id]) - runtime.clock)
			if not enemy.is_empty():
				enemy["receipt_remaining"] = remaining
			if remaining <= EPSILON or enemy.is_empty():
				state["receipt"].erase(enemy_id)
		if not runtime.has(slot, SPORE):
			continue
		# Capture IDs: one damage callback may retire a victim and infect others.
		for enemy_id: Variant in state["infected"].keys():
			if not state["infected"].has(enemy_id):
				continue
			var enemy: Dictionary = _enemy(slot, int(enemy_id))
			if enemy.is_empty():
				state["infected"].erase(enemy_id)
				continue
			var infection: Dictionary = state["infected"][enemy_id]
			var exposure: float = minf(delta, maxf(0.0, float(infection["remaining"])))
			infection["remaining"] = float(infection["remaining"]) - exposure
			var damage: float = float(enemy["max_hp"]) * float(runtime.params(slot, SPORE)["damage_fraction"]) * exposure
			runtime.combat.item_damage(slot, int(enemy_id), damage, &"magic", SPORE, {}, {"item_only": true, "continuous": true, "exposure": exposure, "no_crit": true})
			if state["infected"].has(enemy_id) and float(infection["remaining"]) <= EPSILON:
				state["infected"].erase(enemy_id)
				enemy["infected"] = false
				enemy["infected_remaining"] = 0.0
			elif int(enemy["hp"]) > 0:
				enemy["infected_remaining"] = infection["remaining"]


func next_event_step(maximum: float) -> float:
	var result: float = maximum
	for slot: int in range(2):
		var state: Dictionary = _state(slot)
		for enemy_id: Variant in state["infected"]:
			var infection: Dictionary = state["infected"][enemy_id]
			result = _deadline(result, float(infection["remaining"]))
			var enemy: Dictionary = _enemy(slot, int(enemy_id))
			if not enemy.is_empty():
				var rate: float = float(enemy["max_hp"]) * float(runtime.params(slot, SPORE)["damage_fraction"])
				result = runtime.combat.item_damage_event_step(slot, int(enemy_id), rate, &"magic", SPORE, result)
		for expiry: Variant in state["receipt"].values():
			result = _deadline(result, float(expiry) - runtime.clock)
		for tower: Dictionary in runtime.combat.towers[slot]:
			if not _sun_eligible(slot, tower):
				continue
			var sun: Dictionary = state["sun"].get(int(tower["id"]), {})
			var shutdown: float = float(sun.get("shutdown", 0.0))
			if shutdown > EPSILON:
				result = _deadline(result, shutdown)
			elif float(tower.get("stunned_remaining", 0.0)) <= EPSILON and not runtime.combat._silenced(slot, tower) and float(tower.get("refuel_remaining", 0.0)) <= EPSILON:
				if runtime.combat._target(slot, tower, float(tower["range"])) >= 0:
					result = _deadline(result, float(runtime.params(slot, SUN)["charge_duration"]) - float(sun.get("heat", 0.0)))
	return result

func needs_attack_tracking() -> bool:
	for slot: int in range(2):
		if runtime.has(slot, SUN) or runtime.has(slot, BRACE):
			return true
	return false


func needs_combat_events() -> bool:
	if needs_attack_tracking():
		return true
	for slot: int in range(2):
		if runtime.has(slot, &"butchers_apron") or runtime.has(slot, &"frostbite_nail") or runtime.has(slot, &"watchmans_cup"):
			return true
		var state: Dictionary = _state(slot)
		if not state["infected"].is_empty() or not state["receipt"].is_empty():
			return true
	return false
	# End of needs_combat_events.


func _deadline(current: float, remaining: float) -> float:
	return minf(current, remaining) if remaining > EPSILON else current


func on_wave_start() -> void:
	for slot: int in range(2):
		_clear_wave(slot)
		if runtime.has(slot, SPORE):
			_ensure_spore(slot)
			_state(slot)["spore_remaining"] = _state(slot)["spore_quota"]
			_emit_pet(slot)


func on_wave_abandon() -> void:
	for slot: int in range(2):
		_clear_wave(slot)


func _clear_wave(slot: int) -> void:
	var state: Dictionary = _state(slot)
	for enemy: Dictionary in runtime.combat.enemies[slot]:
		if runtime.has(slot, SPORE) or enemy.has("infected"):
			enemy["infected"] = false
			enemy["infected_remaining"] = 0.0
		if runtime.has(slot, &"necromancers_receipt") or enemy.has("receipt_remaining"):
			enemy["receipt_remaining"] = 0.0
	for key: String in ["brace", "sun", "infected", "infected_once", "receipt"]:
		state[key].clear()
	for tower: Dictionary in runtime.combat.towers[slot]:
		if runtime.has(slot, BRACE) or tower.has("item_brace_bonus"):
			tower["item_brace_bonus"] = 0.0
		if runtime.has(slot, SUN) or tower.has("item_sun_heat"):
			tower["item_sun_heat"] = 0.0
			tower["item_sun_shutdown"] = 0.0


func on_inventory_changed(slot: int) -> void:
	var state: Dictionary = _state(slot)
	if runtime.has(slot, SPORE):
		_ensure_spore(slot)
		state["spore_feed_quote"] = runtime.economy.price(slot, "shards", int(runtime.params(slot, SPORE)["feed_cost"]), "feed")
		_emit_pet(slot)
	else:
		state["infected"].clear()
		for enemy: Dictionary in runtime.combat.enemies[slot]:
			if enemy.has("infected"):
				enemy["infected"] = false
				enemy["infected_remaining"] = 0.0
	if not runtime.has(slot, BRACE):
		state["brace"].clear()
	if not runtime.has(slot, SUN):
		state["sun"].clear()
	if not runtime.has(slot, &"necromancers_receipt"):
		state["receipt"].clear()
		for enemy: Dictionary in runtime.combat.enemies[slot]:
			if enemy.has("receipt_remaining"):
				enemy["receipt_remaining"] = 0.0
	for tower: Dictionary in runtime.combat.towers[slot]:
		if not runtime.has(slot, BRACE) and tower.has("item_brace_bonus"):
			tower["item_brace_bonus"] = 0.0
		if not runtime.has(slot, SUN) and tower.has("item_sun_heat"):
			tower["item_sun_heat"] = 0.0
			tower["item_sun_shutdown"] = 0.0


func on_tower_sold(slot: int, tower: Dictionary) -> void:
	var state: Dictionary = _state(slot)
	state["brace"].erase(int(tower["id"]))
	state["sun"].erase(int(tower["id"]))



func _emit_pet(slot: int) -> void:
	var state: Dictionary = _state(slot)
	runtime.combat.item_emit("spore_pet", slot, runtime.combat.item_crystal_position(slot), {"quota": state["spore_quota"], "remaining": state["spore_remaining"]})


func _enemy(slot: int, id: int) -> Dictionary:
	var index: int = runtime.combat._enemy_index(slot, id)
	return runtime.combat.enemies[slot][index] if index >= 0 else {}
