class_name BossRewardRules
extends Resource
## Run-only payouts; rarity identities, titles and odds belong to tower roll rules.

@export var rarity_rules: TowerRollRules
# Rarity ID -> Vector2i(Coins, Shards), before round scaling.
@export var payouts: Dictionary = {}
# Lowest rarity a boss can drop; lower tiers leave the roll and the reel.
@export var minimum_rarity: String = ""


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if rarity_rules == null:
		errors.append("Boss rewards require referenced rarity rules.")
		return errors
	var seen: Dictionary = {}
	var total: float = 0.0
	for tier: Dictionary in rarity_rules.rarities:
		var id: Variant = tier.get("id")
		if typeof(id) != TYPE_STRING or id not in TowerRollRules.RARITIES or seen.has(id):
			errors.append("Boss rewards require unique known rarity IDs.")
			continue
		seen[id] = true
		if typeof(tier.get("title")) != TYPE_STRING or str(tier.get("title", "")).strip_edges().is_empty():
			errors.append("Boss reward rarity '%s' requires a title." % id)
		var weight: Variant = tier.get("weight")
		if (typeof(weight) != TYPE_INT and typeof(weight) != TYPE_FLOAT) or not is_finite(float(weight)) or float(weight) <= 0.0:
			errors.append("Boss reward rarity '%s' requires finite positive weight." % id)
		else:
			total += float(weight)
	if not is_finite(total) or total <= 0.0:
		errors.append("Boss rewards require finite positive total weight.")
	var previous := Vector2i.ZERO
	for id: String in TowerRollRules.RARITIES:
		if not seen.has(id):
			errors.append("Boss rewards are missing rarity '%s'." % id)
		if typeof(payouts.get(id)) != TYPE_VECTOR2I:
			errors.append("Boss reward rarity '%s' requires integer Coin/Shard payouts." % id)
			continue
		var payout: Vector2i = payouts[id]
		if payout.x <= previous.x or payout.y <= previous.y:
			errors.append("Boss reward payouts must be positive and ascend in both currencies.")
		previous = payout
	for id: Variant in payouts:
		if typeof(id) != TYPE_STRING or id not in TowerRollRules.RARITIES:
			errors.append("Boss rewards contain an unknown payout rarity.")
	if not minimum_rarity.is_empty() and minimum_rarity not in TowerRollRules.RARITIES:
		errors.append("Boss reward minimum rarity '%s' is unknown." % minimum_rarity)
	return errors


## Call only after validation; capture scalars rather than retain resource aliases.
func capture_tiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var floor_index: int = maxi(0, TowerRollRules.RARITIES.find(minimum_rarity))
	for id: String in TowerRollRules.RARITIES.slice(floor_index):
		for tier: Dictionary in rarity_rules.rarities:
			if tier["id"] == id:
				var payout: Vector2i = payouts[id]
				result.append({"id": id, "title": str(tier["title"]), "weight": float(tier["weight"]), "coins": payout.x, "shards": payout.y})
				break
	return result
