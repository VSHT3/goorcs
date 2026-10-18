class_name BossRewardLedger
extends RefCounted
## Only the host calls claim after confirming a player-owned real boss death.
## Returned dictionaries and histories never alias durable accepted awards.

var error_message: String = ""
var _enabled: bool = false
var _random: RandomNumberGenerator
var _tiers: Array[Dictionary] = []
var _total_weight: float = 0.0
var _claimed: Array[Dictionary] = [{}, {}]
var _history: Array[Array] = [[], []]
var _next_id: int = 1


func _init(rules: BossRewardRules = null, random: RandomNumberGenerator = null, enabled: bool = true) -> void:
	if rules == null:
		return
	var errors: PackedStringArray = rules.validation_errors()
	if not errors.is_empty():
		error_message = " ".join(errors)
		return
	if random == null and enabled:
		error_message = "Boss rewards require a dedicated authoritative RandomNumberGenerator."
		return
	_tiers = rules.capture_tiers()
	for tier: Dictionary in _tiers:
		_total_weight += float(tier["weight"])
	_random = random
	_enabled = enabled


func claim(slot: int, type_id: String, definition: Dictionary, round_number: int, simulation_time: float) -> Dictionary:
	if not _enabled or not error_message.is_empty() or slot < 0 or slot >= _claimed.size():
		return {}
	if type_id.strip_edges().is_empty() or _claimed[slot].has(type_id) or round_number < 1 or not is_finite(simulation_time) or simulation_time < 0.0:
		return {}
	if typeof(definition.get("boss")) != TYPE_BOOL or not definition["boss"] or typeof(definition.get("title")) != TYPE_STRING or str(definition["title"]).strip_edges().is_empty():
		return {}
	var scale: float = maxf(1.0, float(round_number) / 40.0)
	var tiers: Array[Dictionary] = []
	for tier: Dictionary in _tiers:
		var coins: float = float(tier["coins"]) * scale
		var shards: float = float(tier["shards"]) * scale
		if not is_finite(coins) or not is_finite(shards) or coins > TowerRollRules.MAX_EXACT_COST or shards > TowerRollRules.MAX_EXACT_COST:
			return {}
		tiers.append({"id": tier["id"], "title": tier["title"], "weight": tier["weight"], "coins": ceili(coins), "shards": ceili(shards)})
	var draw: float = _random.randf() * _total_weight
	var selected: Dictionary = tiers.back()
	for tier: Dictionary in tiers:
		draw -= float(tier["weight"])
		if draw < 0.0:
			selected = tier
			break
	var award: Dictionary = {
		"id": _next_id, "boss_id": type_id, "boss_title": str(definition["title"]),
		"rarity": selected["id"], "rarity_title": selected["title"],
		"coins": selected["coins"], "shards": selected["shards"],
		"round": round_number, "time": simulation_time, "tiers": tiers,
	}
	_claimed[slot][type_id] = true
	_history[slot].append(award)
	_next_id += 1
	return award.duplicate(true)


func awards(slot: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if slot < 0 or slot >= _history.size():
		return result
	for award: Dictionary in _history[slot]:
		result.append(award.duplicate(true))
	return result
