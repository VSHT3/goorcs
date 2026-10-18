class_name MatchRecap
extends RefCounted
## Event accounting only. Never infers earnings from balances or changes gameplay.

var rounds_cleared: int = 0
var _sides: Array[Dictionary] = []
var _towers: Array[Array] = [[], []]

func _init() -> void:
	for _slot: int in range(2):
		_sides.append({"spent": {"towers": 0, "upgrades": 0, "sends": 0, "attribute_rerolls": 0, "rarity_shards": 0}, "earned": {"kill_coins": 0, "wave_coins": 0, "income_coins": 0, "production_coins": 0, "boss_coins": 0, "sale_coins": 0, "drop_shards": 0, "clear_shards": 0, "production_shards": 0, "boss_shards": 0}, "leaks": {}, "base_damage": {}, "defeated_by": ""})

func add(slot: int, bucket: String, key: String, amount: int) -> void:
	_sides[slot][bucket][key] += amount

func register_tower(slot: int, tower: Dictionary) -> void:
	_towers[slot].append({"tower": tower, "sold": false})

func sell(slot: int, id: int) -> void:
	for record: Dictionary in _towers[slot]:
		if int(record["tower"]["id"]) == id:
			record["sold"] = true
			return

func leak(slot: int, type_id: String, damage: int, fatal: bool) -> void:
	var side: Dictionary = _sides[slot]
	side["leaks"][type_id] = int(side["leaks"].get(type_id, 0)) + 1
	side["base_damage"][type_id] = int(side["base_damage"].get(type_id, 0)) + damage
	if fatal and damage > 0:
		side["defeated_by"] = type_id

func snapshot(duration: float) -> Dictionary:
	var sides: Array[Dictionary] = []
	for slot: int in range(2):
		var side: Dictionary = _sides[slot].duplicate(true)
		var towers: Array[Dictionary] = []
		for record: Dictionary in _towers[slot]:
			var tower: Dictionary = record["tower"].duplicate(true)
			tower["sold"] = record["sold"]
			towers.append(tower)
		side["towers"] = towers
		sides.append(side)
	return {"duration_seconds": duration, "rounds_cleared": rounds_cleared, "sides": sides}
