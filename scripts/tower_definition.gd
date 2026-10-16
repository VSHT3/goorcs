class_name TowerDefinition
extends Resource

const SECOND_ARCHER_ATTACK_RATE_MULTIPLIER: float = 1.1
const BOUNCE_DAMAGE_MULTIPLIER: float = 0.5
const FREEZE_DAMAGE_THRESHOLD: float = 0.2
const FREEZE_SPEED_MULTIPLIER: float = 0.8
const FREEZE_DURATION: float = 2.0

@export var reward: TowerReward
@export var damage: int = 2
@export var range_cells: float = 3.0
@export var interval: float = 0.75
@export var cost: int = 45
@export var upgrade_base_cost: int = 30
@export var damage_upgrade_bonus: int = 1
@export var speed_upgrade_multiplier: float = 0.8
@export var area_attack: bool = false
# Presentation family, not a targeting or damage rule.
@export_enum("Bow", "Ballista", "Rune") var attack_sound: int = CombatSoundEvents.Cue.BOW
@export var special_upgrade: String = ""
@export var special_upgrade_title: String = ""
@export var special_upgrade_cost: int = 0
@export var evolutions: Dictionary = {}
@export var advancements: Dictionary = {}


static func valid_advancements(definition: TowerDefinition) -> bool:
	if not definition.advancements.is_empty() and (definition.special_upgrade != "second_archer" or definition.area_attack or not definition.evolutions.is_empty()):
		return false
	for branch: Variant in definition.advancements:
		if not branch is String or branch not in ["four_archers", "fire_arrows", "bomb_arrows"] or not definition.advancements[branch] is Dictionary:
			return false
		var config: Dictionary = definition.advancements[branch]
		if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
			return false
		var fields: Array[String] = []
		match branch:
			"four_archers":
				if config.size() != 4 or not config.get("archer_count") is int or config["archer_count"] != 4:
					return false
				fields = ["attack_rate_multiplier"]
			"fire_arrows":
				if config.size() != 4:
					return false
				fields = ["burn_dps", "burn_duration"]
			"bomb_arrows":
				if config.size() != 5:
					return false
				fields = ["primary_multiplier", "splash_multiplier", "splash_radius"]
		for field: String in fields:
			if typeof(config.get(field)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(config[field])) or float(config[field]) <= 0.0:
				return false
	return true


static func valid_evolutions(definition: TowerDefinition) -> bool:
	if not definition.evolutions.is_empty() and not definition.special_upgrade.is_empty():
		return false
	for branch: Variant in definition.evolutions:
		if not branch is String or branch not in ["boulders", "onyx_ring", "pierce", "bounce"] or not definition.evolutions[branch] is Dictionary:
			return false
		var config: Dictionary = definition.evolutions[branch]
		if not config.get("title") is String or String(config["title"]).is_empty() or not config.get("cost") is int or int(config["cost"]) <= 0:
			return false
		if branch in ["pierce", "bounce"]:
			if definition.area_attack or config.size() != 2:
				return false
			for other_branch: Variant in definition.evolutions:
				if other_branch not in ["pierce", "bounce"]:
					return false
			continue
		if not config.get("damage") is int or int(config["damage"]) <= 0 or not config.get("continuous") is bool:
			return false
		if typeof(config.get("interval")) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var interval: float = float(config["interval"])
		if not is_finite(interval) or (bool(config["continuous"]) and interval != 0.0) or (not bool(config["continuous"]) and interval <= 0.0):
			return false
		if bool(config["continuous"]) != (branch == "boulders") or not definition.area_attack:
			return false
		if branch == "boulders" and not config.has("followup"):
			return false
		if config.has("followup"):
			if branch != "boulders" or not config["followup"] is Dictionary:
				return false
			var followup: Dictionary = config["followup"]
			if followup.get("id") != "freeze_runes" or not followup.get("title") is String or String(followup["title"]).is_empty() or not followup.get("cost") is int or int(followup["cost"]) <= 0:
				return false
	return true
