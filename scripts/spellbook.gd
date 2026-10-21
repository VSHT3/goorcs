class_name Spellbook
extends RefCounted
## Grand Mage spell rotation: authored tuning, validation and readable summaries.
## MatchCombat owns the clocks, targets, rolls and every gameplay effect.

const SPELLS: Array[String] = ["nullify", "fireball", "portal", "haste", "barrier", "soulfire", "raise_dead"]
# Every spell's tuning keys; all are positive numbers.
const FIELDS: Dictionary = {
	"nullify": ["shield", "strike", "duration"],
	"fireball": ["windup", "radius", "stun"],
	"portal": ["cast", "count"],
	"haste": ["cast", "radius", "multiplier", "duration"],
	"barrier": ["cast", "hits", "heal", "below", "limit"],
	"soulfire": ["windup", "radius", "wither", "duration"],
	"raise_dead": ["cast", "radius", "count", "window", "type"],
}
# Integer counts; fractions must stay within (0, 1]; multipliers must exceed one.
const WHOLE: Array[String] = ["count", "hits", "limit"]
const FRACTIONS: Array[String] = ["heal", "below", "wither"]
# Text fields: the enemy type a spell raises (checked against the catalog).
const NAMES: Array[String] = ["type"]
# The portal drops its passengers this many cells in front of the caster.
const PORTAL_LEAD: float = 0.8
# Seconds a non-boss death stays in the board's ledger for Raise the Fallen.
const FALLEN_MEMORY: float = 15.0


static func validation_error(book: Dictionary) -> String:
	if book.is_empty():
		return ""
	if not _positive(book.get("glide")):
		return "needs a positive glide time between casts"
	var order: Variant = book.get("order")
	if not order is Array or (order as Array).is_empty():
		return "needs a non-empty spell order"
	var seen: Dictionary = {}
	for spell: Variant in order:
		if not spell is String or String(spell) not in SPELLS or seen.has(spell):
			return "lists an unknown or repeated spell '%s'" % str(spell)
		seen[spell] = true
		var config: Variant = book.get(spell)
		if not config is Dictionary or (config as Dictionary).size() != FIELDS[spell].size():
			return "needs exactly %s for '%s'" % [", ".join(FIELDS[spell]), spell]
		for field: String in FIELDS[spell]:
			var value: Variant = config.get(field)
			if field in NAMES:
				if not value is String or String(value).is_empty():
					return "needs an enemy type for '%s'" % spell
				continue
			if not _positive(value) or (field in WHOLE and not value is int) or (field in FRACTIONS and float(value) > 1.0) or (field == "multiplier" and float(value) <= 1.0) or (field == "window" and float(value) > FALLEN_MEMORY):
				return "has an invalid '%s' for '%s'" % [field, spell]
	for key: Variant in book:
		if key not in ["glide", "order", "death_bolt"] and not seen.has(key):
			return "has an unused entry '%s'" % str(key)
	if book.has("death_bolt"):
		var bolt: Variant = book["death_bolt"]
		if not bolt is Dictionary or (bolt as Dictionary).keys() != ["stun"] or not _positive(bolt["stun"]):
			return "needs a positive death_bolt stun"
	return ""


# Seconds the caster stands still before the spell resolves.
static func cast_time(book: Dictionary, spell: String) -> float:
	var config: Dictionary = book[spell]
	match spell:
		"nullify":
			return float(config["shield"])
		"fireball", "soulfire":
			return float(config["windup"])
	return float(config["cast"])


static func summary(book: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if book.is_empty():
		return lines
	lines.append("Moves %ss, then stops to cast in order:" % String.num(float(book["glide"]), 1))
	for spell: String in book["order"]:
		var config: Dictionary = book[spell]
		match spell:
			"nullify":
				lines.append("Nullify: immune to all damage for %ss, then the staff strike silences every Magic tower on the board for %ss" % [String.num(float(config["shield"]), 1), String.num(float(config["duration"]), 1)])
			"fireball":
				lines.append("Fireball: %ss windup at a random tower · stuns towers within %s cells for %ss" % [String.num(float(config["windup"]), 1), String.num(float(config["radius"]), 1), String.num(float(config["stun"]), 1)])
			"portal":
				lines.append("Portal: pulls the %d rearmost orcs up to just in front of it" % int(config["count"]))
			"haste":
				lines.append("Haste: orcs within %s cells move %s%% faster for %ss" % [String.num(float(config["radius"]), 1), String.num((float(config["multiplier"]) - 1.0) * 100.0, 0), String.num(float(config["duration"]), 1)])
			"barrier":
				lines.append("Barrier (below %s%% HP, at most %d times): %d-hit shield and heals %s%% max HP" % [String.num(float(config["below"]) * 100.0, 0), int(config["limit"]), int(config["hits"]), String.num(float(config["heal"]) * 100.0, 0)])
			"soulfire":
				lines.append("Soulfire Breath: %ss windup at your densest towers · towers within %s cells deal %s%% less damage for %ss" % [String.num(float(config["windup"]), 1), String.num(float(config["radius"]), 1), String.num(float(config["wither"]) * 100.0, 0), String.num(float(config["duration"]), 1)])
			"raise_dead":
				lines.append("Raise the Fallen: up to %d orcs that died within %s cells in the last %ss rise again" % [int(config["count"]), String.num(float(config["radius"]), 1), String.num(float(config["window"]), 0)])
	if book.has("death_bolt"):
		lines.append("On death: a staff bolt stuns your most valuable tower for %ss" % String.num(float(book["death_bolt"]["stun"]), 1))
	return lines


static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0
