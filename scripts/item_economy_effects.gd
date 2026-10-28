class_name ItemEconomyEffects
extends RefCounted
## Host integration: quote each purchase unit through price() before preflight;
## batches sum those quotes, and investment/refunds retain actual paid amounts.
## Capture send_profile() at accepted purchase, then multiply arrival_profile()
## from immutable base_max_hp/base_speed on birth/transfer (never compound).
## Call on_wave_start/on_leak/on_clear only for real lifecycle events; abandoned
## waves call on_wave_abandon instead. production() returns production income for
## the host's tower/recap credit; item_credit() bonuses are separate and must not
## reenter production/on_kill. on_kill() returns rewards for the host to credit.
## Board mark percentages pass through bounty_bonus() before the host's existing
## combined rounding/attribution; Stone multiplies only the normal bounty part.

const RARE_STONE: StringName = &"philosophers_stone"
const LEGENDARY_STONE: StringName = &"philosophorers_stone"
const ORC_STONE: StringName = &"philosophorers_stoner"
const EPSILON: float = 0.000000001

var _runtime_ref: WeakRef
var runtime: Variant:
	get:
		return _runtime_ref.get_ref()


func _init(owner: Variant) -> void:
	_runtime_ref = weakref(owner)


func price(slot: int, currency: String, base: int, kind: String = "") -> int:
	if base <= 0:
		return 0
	if currency != "coins" and currency != "shards":
		return base
	var multiplier: float = 1.0
	if runtime.has(slot, &"dabloons"):
		multiplier *= float(runtime.params(slot, &"dabloons")["cost_multiplier"])
	if currency == "coins" and kind == "send" and runtime.has(slot, &"couriers_basalt_boots"):
		multiplier *= float(runtime.params(slot, &"couriers_basalt_boots")["cost_multiplier"])
	return ceili(float(base) * multiplier - EPSILON)


## Sender-only terms are frozen when an order is accepted, not when it arrives.
func send_profile(slot: int, enemy: Dictionary) -> Dictionary:
	var result: Dictionary = {"cost_multiplier": 1.0, "health_multiplier": 1.0, "speed_multiplier": 1.0}
	if not bool(enemy.get("boss", false)) and runtime.has(slot, &"couriers_basalt_boots"):
		var parameters: Dictionary = runtime.params(slot, &"couriers_basalt_boots")
		result["cost_multiplier"] = float(parameters["cost_multiplier"])
		result["health_multiplier"] = float(parameters["health_multiplier"])
	return result


## Defender-relative terms are reevaluated on transfer, using original birth
## provenance. Paid orders and caster/death summons qualify; wave births do not.
func arrival_profile(slot: int, enemy: Dictionary) -> Dictionary:
	var result: Dictionary = {"health_multiplier": 1.0, "speed_multiplier": 1.0}
	var birth: String = _birth_kind(enemy)
	if birth != "send" and birth != "summon":
		return result
	if runtime.has(slot, &"orc_tusk"):
		result["health_multiplier"] *= float(runtime.params(slot, &"orc_tusk")["health_multiplier"])
	if runtime.has(slot, &"torn_boot"):
		result["speed_multiplier"] *= float(runtime.params(slot, &"torn_boot")["speed_multiplier"])
	if runtime.has(1 - slot, &"command_banner"):
		result["speed_multiplier"] *= float(runtime.params(1 - slot, &"command_banner")["speed_multiplier"])
	return result


func bounty_bonus(slot: int, _tower: Dictionary, base_bonus: float, kind: String) -> float:
	if (kind == "mark" or kind == "bounty") and runtime.has(slot, &"gravebound_ledger"):
		return base_bonus * float(runtime.params(slot, &"gravebound_ledger")["mark_multiplier"])
	return base_bonus


func on_kill(slot: int, enemy: Dictionary, normal_bounty: int) -> Dictionary:
	var state: Dictionary = _state(slot)
	var stone: StringName = _stone(slot)
	var triggered: bool = _counter_event(slot, state, stone)
	var bonus_shards: int = int(runtime.params(slot, stone)["shards"]) if triggered else 0
	var multiplier: float = 1.0
	if stone != &"":
		var stone_parameters: Dictionary = runtime.params(slot, stone)
		if (stone == ORC_STONE and float(state["rush_until"]) > float(runtime.clock) + EPSILON) or (stone != ORC_STONE and triggered):
			multiplier = float(stone_parameters["bounty_multiplier"])
	var bonus_coins: int = 0
	if normal_bounty > 0 and not bool(state["first_bounty_paid"]):
		state["first_bounty_paid"] = true
		if runtime.has(slot, &"copper_tooth"):
			var tooth_coins: int = int(runtime.params(slot, &"copper_tooth")["bonus_coins"])
			bonus_coins += tooth_coins
			_record_credit(state, &"copper_tooth", "coins", tooth_coins)
	# Every actual kill resets the wait; summons cannot consume an armed serving.
	if runtime.has(slot, &"mimics_lunch_pail"):
		if bool(state["mimic_ready"]) and _birth_kind(enemy) != "summon":
			var mimic_coins: int = int(runtime.params(slot, &"mimics_lunch_pail")["bonus_coins"])
			bonus_coins += mimic_coins
			state["mimic_ready"] = false
			_record_credit(state, &"mimics_lunch_pail", "coins", mimic_coins)
	state["mimic_wait"] = 0.0
	var golden: bool = multiplier > 1.0
	if golden:
		enemy["item_golden"] = true
		_record_credit(state, stone, "coins", maxi(0, normal_bounty) * (int(multiplier) - 1))
	if bonus_shards > 0:
		_record_credit(state, stone, "shards", bonus_shards)
	return {"bounty_multiplier": multiplier, "bonus_coins": bonus_coins, "bonus_shards": bonus_shards, "golden": golden, "source_item": String(stone)}


## One cycle is one real payout event, even if carried fractional output yields
## no whole currency that cycle. No Coin amount can create extra counter/RNG rolls.
func production(slot: int, tower: Dictionary, currency: String, base_amount: int, cycles: int, periodic: bool) -> int:
	if cycles <= 0 or base_amount <= 0 or (currency != "coins" and currency != "shards"):
		return 0
	if periodic and int(runtime.combat.phase) != 1:
		return 0
	var state: Dictionary = _state(slot)
	var source_id: int = int(tower["id"])
	var sources: Dictionary = state["production_sources"]
	if not sources.has(source_id):
		sources[source_id] = {}
	var source: Dictionary = sources[source_id]
	if not source.has(currency):
		source[currency] = {"fraction": 0.0, "payouts": 0, "produced": 0, "item_shards": 0}
	var ledger: Dictionary = source[currency]
	var multiplier: float = _production_multiplier(slot, tower, currency, periodic)
	var coin_mine: bool = _is_coin_mine(tower) and currency == "coins"
	var mine_family: bool = String(tower.get("type_id", "")) == "gold_mine" and (String(tower.get("behavior_kind", "")) == "economy" or String(tower.get("behavior_kind", "")) == "crystal")
	var stone: StringName = _stone(slot)
	var count_production: bool = mine_family and (stone == LEGENDARY_STONE or stone == ORC_STONE)
	var mountain: bool = coin_mine and runtime.has(slot, &"mountains_pocket_change")
	var mountain_parameters: Dictionary = runtime.params(slot, &"mountains_pocket_change") if mountain else {}
	var produced: int = 0
	for cycle: int in range(cycles):
		var accumulated: float = float(ledger["fraction"]) + float(base_amount) * multiplier
		var whole: int = floori(accumulated + EPSILON)
		ledger["fraction"] = maxf(0.0, accumulated - whole)
		ledger["payouts"] += 1
		ledger["produced"] += whole
		produced += whole
		if count_production and _counter_event(slot, state, stone):
			var shards: int = int(runtime.params(slot, stone)["shards"])
			ledger["item_shards"] += shards
			_credit(slot, state, stone, "shards", shards)
		if mountain and runtime.random.randf() < float(mountain_parameters["shard_chance"]):
			var shards: int = int(mountain_parameters["shards"])
			ledger["item_shards"] += shards
			_credit(slot, state, &"mountains_pocket_change", "shards", shards)
	return produced


func on_wave_start(slot: int) -> void:
	var state: Dictionary = _state(slot)
	state["wave_open"] = true
	state["first_bounty_paid"] = false
	state["wave_leaks"] = 0


func on_leak(slot: int) -> void:
	var state: Dictionary = _state(slot)
	state["wave_leaks"] += 1
	state["clean_streak"] = 0


func on_clear(slot: int, round_number: int) -> void:
	var state: Dictionary = _state(slot)
	if not bool(state["wave_open"]):
		return
	state["wave_open"] = false
	if int(state["wave_leaks"]) > 0:
		state["clean_streak"] = 0
		return
	if not runtime.has(slot, &"orcish_lunch_tin"):
		return
	state["clean_streak"] += 1
	var parameters: Dictionary = runtime.params(slot, &"orcish_lunch_tin")
	var coins: int = floori(float(parameters["base_coins"]) + float(round_number) / float(parameters["round_divisor"])) + floori(float(state["clean_streak"]) / float(parameters["streak_divisor"]))
	_credit(slot, state, &"orcish_lunch_tin", "coins", coins)


func on_wave_abandon(slot: int) -> void:
	var state: Dictionary = _state(slot)
	state["wave_open"] = false
	state["wave_leaks"] = 0
	state["rush_until"] = 0.0


func on_inventory_changed(slot: int) -> void:
	if not runtime.has(slot, ORC_STONE):
		_state(slot)["rush_until"] = 0.0


func advance(delta: float) -> void:
	if delta <= 0.0 or int(runtime.combat.phase) != 1:
		return
	for slot: int in range(2):
		if not runtime.has(slot, &"mimics_lunch_pail"):
			continue
		var state: Dictionary = _state(slot)
		if bool(state["mimic_ready"]):
			continue
		var wait: float = float(runtime.params(slot, &"mimics_lunch_pail")["wait_seconds"])
		state["mimic_wait"] = minf(wait, float(state["mimic_wait"]) + delta)
		if float(state["mimic_wait"]) + EPSILON >= wait:
			state["mimic_ready"] = true



func needs_combat_events() -> bool:
	for slot: int in range(2):
		if not runtime.has(slot, &"mimics_lunch_pail"):
			continue
		var state: Dictionary = _state(slot)
		if not bool(state.get("mimic_ready", false)) or (runtime.has(slot, ORC_STONE) and float(state.get("rush_until", 0.0)) > runtime.clock + EPSILON):
			return true
	return false

func next_event_step(maximum: float) -> float:
	var step: float = maximum
	for slot: int in range(2):
		var state: Dictionary = runtime.state(slot)["economy"]
		var rush_remaining: float = float(state.get("rush_until", 0.0)) - float(runtime.clock)
		if runtime.has(slot, ORC_STONE) and rush_remaining > EPSILON:
			step = minf(step, rush_remaining)
		if runtime.has(slot, &"mimics_lunch_pail") and not bool(state.get("mimic_ready", false)):
			var wait_remaining: float = float(runtime.params(slot, &"mimics_lunch_pail")["wait_seconds"]) - float(state.get("mimic_wait", 0.0))
			if wait_remaining > EPSILON:
				step = minf(step, wait_remaining)
	return step


func _production_multiplier(slot: int, tower: Dictionary, currency: String, periodic: bool) -> float:
	var multiplier: float = 1.0
	if currency == "shards" and String(tower.get("type_id", "")) == "gold_mine" and String(tower.get("behavior_kind", "")) == "crystal":
		if runtime.has(slot, &"prospectors_diamond"):
			multiplier *= float(runtime.params(slot, &"prospectors_diamond")["production_multiplier"])
		return multiplier
	if currency != "coins" or not _is_coin_mine(tower):
		return multiplier
	for id: StringName in [&"sturdy_pickaxe", &"mountains_pocket_change"]:
		if runtime.has(slot, id):
			multiplier *= float(runtime.params(slot, id)["production_multiplier"])
	# Counting Frame names the unevolved Gold Mine, not its Royal Mint branch.
	if String(tower.get("evolution", "")) == "" and runtime.has(slot, &"counting_frame"):
		multiplier *= float(runtime.params(slot, &"counting_frame")["production_multiplier"])
	if not periodic:
		for id: StringName in [&"accountants_abacus", &"golden_harvest_sickle"]:
			if runtime.has(slot, id):
				multiplier *= float(runtime.params(slot, id)["clear_multiplier"])
	if runtime.has(slot, &"undertakers_spade"):
		multiplier *= float(runtime.params(slot, &"undertakers_spade")["periodic_multiplier" if periodic else "clear_multiplier"])
	if String(tower.get("evolution", "")) == "royal_mint" and runtime.has(slot, &"royal_printing_plate"):
		multiplier *= float(runtime.params(slot, &"royal_printing_plate")["periodic_multiplier" if periodic else "clear_multiplier"])
	return multiplier


func _counter_event(_slot: int, state: Dictionary, stone: StringName) -> bool:
	if stone == &"":
		return false
	state["stone_counter"] += 1
	var parameters: Dictionary = runtime.params(_slot, stone)
	if int(state["stone_counter"]) % int(parameters["event_period"]) != 0:
		return false
	if stone == ORC_STONE:
		state["rush_until"] = float(runtime.clock) + float(parameters["rush_seconds"])
	return true


func _stone(slot: int) -> StringName:
	if runtime.has(slot, ORC_STONE):
		return ORC_STONE
	if runtime.has(slot, LEGENDARY_STONE):
		return LEGENDARY_STONE
	if runtime.has(slot, RARE_STONE):
		return RARE_STONE
	return &""


func _state(slot: int) -> Dictionary:
	var state: Dictionary = runtime.state(slot)["economy"]
	if state.is_empty():
		state.merge({"stone_counter": 0, "rush_until": 0.0, "first_bounty_paid": false, "wave_leaks": 0, "wave_open": false, "clean_streak": 0, "mimic_wait": 0.0, "mimic_ready": false, "production_sources": {}, "item_credits": {}})
	return state


func _credit(slot: int, state: Dictionary, id: StringName, currency: String, amount: int) -> void:
	if amount <= 0:
		return
	_record_credit(state, id, currency, amount)
	runtime.combat.item_credit(slot, currency, amount)


func _record_credit(state: Dictionary, id: StringName, currency: String, amount: int) -> void:
	if amount <= 0:
		return
	var ledger: Dictionary = state["item_credits"]
	var key: String = String(id)
	if not ledger.has(key):
		ledger[key] = {"coins": 0, "shards": 0}
	ledger[key][currency] += amount


static func _is_coin_mine(tower: Dictionary) -> bool:
	return String(tower.get("type_id", "")) == "gold_mine" and String(tower.get("behavior_kind", "")) == "economy"


static func _birth_kind(enemy: Dictionary) -> String:
	return String(enemy.get("original_birth_kind", enemy.get("birth_kind", "summon" if int(enemy.get("summoner_id", -1)) >= 0 else "wave")))
