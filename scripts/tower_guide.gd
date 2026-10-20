class_name TowerGuide
extends RefCounted
## Read-only, unrolled reference states purchased from the real combat owner.

var entries: Array[Dictionary] = []
var error_message: String = ""

var _rules: CombatRules
var _records: Dictionary = {}
var _previews: Dictionary = {}
var _configuration_error: String = ""


func configure(content: ContentCatalog, rules: CombatRules) -> void:
	entries.clear()
	_records.clear()
	_previews.clear()
	_rules = null
	error_message = ""
	_configuration_error = _admission_error(content, rules)
	if not _configuration_error.is_empty():
		error_message = _configuration_error
		return
	# Capture resources once. Later source edits require an explicit configure;
	# cached and not-yet-selected branches consequently share the same baseline.
	_rules = rules.duplicate() as CombatRules
	_rules.catalog = _capture_catalog(content)
	_rules.roll_rules = null
	_rules.sandbox_mode = false
	_rules.starting_coins = 0x7fffffffffffffff
	for definition: TowerDefinition in _rules.catalog.towers:
		var reward: TowerReward = definition.reward
		var record: Dictionary = {
			"id": reward.id, "title": reward.title, "description": reward.description,
			"role": definition.behavior_kind, "reward": reward,
			"stages": _stages(definition),
		}
		_records[reward.id] = record
		entries.append(_copy_record(record))


func entry(type_id: StringName) -> Dictionary:
	if not _records.has(type_id):
		error_message = _configuration_error if not _configuration_error.is_empty() else "Tower '%s' is not registered in this guide." % type_id
		return {}
	error_message = ""
	return _copy_record(_records[type_id])


func preview(type_id: StringName, stage_id: String = "base") -> Dictionary:
	var record: Dictionary = _records.get(type_id, {})
	if record.is_empty():
		error_message = _configuration_error if not _configuration_error.is_empty() else "Tower '%s' is not registered in this guide." % type_id
		return {}
	var stage: Dictionary = {}
	for candidate: Dictionary in record["stages"]:
		if candidate["id"] == stage_id:
			stage = candidate
			break
	if stage.is_empty():
		error_message = "Tower '%s' has no guide stage '%s'." % [type_id, stage_id]
		return {}
	if not _previews.has(type_id):
		_previews[type_id] = {}
	var cached: Dictionary = _previews[type_id]
	if not cached.has(stage_id):
		var result: Dictionary = _purchase_preview(type_id, stage, record["reward"])
		if result.is_empty():
			return {}
		cached[stage_id] = result
	error_message = ""
	return _copy_record(cached[stage_id])


func _purchase_preview(type_id: StringName, stage: Dictionary, reward: TowerReward) -> Dictionary:
	# A fresh isolated owner per branch prevents exclusive choices, support
	# neighbors, or another selection from leaking into this reference state.
	var owner := MatchCombat.new(_rules)
	if not owner.build(0, Vector2i.ZERO, type_id, MatchCombat.TargetMode.FURTHEST):
		error_message = "The combat owner rejected the baseline for '%s'." % type_id
		return {}
	var tower_id: int = owner.towers[0][0]["id"]
	var steps: Array[Dictionary] = []
	for command: String in stage["commands"]:
		var before: int = owner.coins[0]
		if not owner.upgrade_tower(0, tower_id, command):
			error_message = "The combat owner rejected '%s' in stage '%s' for '%s'." % [command, stage["id"], type_id]
			return {}
		steps.append({"command": command, "title": _command_title(_rules.catalog, type_id, command), "cost": before - owner.coins[0]})
	var accepted: Dictionary = owner.snapshot()
	var tower: Dictionary = accepted["towers"][0][0]
	return {
		"tower": tower, "stats": accepted["tower_types"][String(type_id)],
		"stage": stage.duplicate(true), "reward": reward,
		"steps": steps, "total_cost": int(tower["invested"]),
	}


static func _admission_error(content: ContentCatalog, rules: CombatRules) -> String:
	if content == null:
		return "A content catalog is required for the Towerieary."
	if rules == null:
		return "Combat rules are required for the Towerieary."
	var errors: PackedStringArray = content.validation_errors()
	if not errors.is_empty():
		return "Invalid tower guide catalog: " + " ".join(errors)
	if content.towers.is_empty():
		return "No towers are registered in this catalog."
	if rules.starting_reroll_currency < 0 or rules.clear_reroll_currency < 0:
		return "Combat reroll grants must be nonnegative."
	if rules.wave_weight <= 0 or rules.wave_weight_growth < 0 or not is_finite(rules.spawn_interval) or rules.spawn_interval < 0.0 or not rules.valid_speed_progression():
		return "Combat wave and speed progression rules are invalid."
	for enemy: EnemyDefinition in content.enemies:
		if enemy.regular_spawn_enabled and not enemy.boss and enemy.spawn_weight == 1 and enemy.first_wave == 1 and enemy.max_per_wave == 0 and enemy.max_weight_share == 1.0:
			return ""
	return "Combat requires an always-available, unlimited weight-one remainder enemy."


static func _capture_catalog(content: ContentCatalog) -> ContentCatalog:
	var captured := ContentCatalog.new()
	captured.starter_tower_id = content.starter_tower_id
	for source: TowerDefinition in content.towers:
		var definition := source.duplicate() as TowerDefinition
		definition.reward = _copy_reward(source.reward)
		definition.behavior_config = source.behavior_config.duplicate(true)
		definition.upgrade_effects = source.upgrade_effects.duplicate(true)
		definition.special_upgrade_config = source.special_upgrade_config.duplicate(true)
		definition.evolutions = source.evolutions.duplicate(true)
		definition.advancements = source.advancements.duplicate(true)
		definition.roll_attributes = source.roll_attributes.duplicate()
		captured.towers.append(definition)
	for source: EnemyDefinition in content.enemies:
		var definition := source.duplicate() as EnemyDefinition
		definition.group_weights = source.group_weights.duplicate()
		captured.enemies.append(definition)
	return captured


static func _copy_reward(source: TowerReward) -> TowerReward:
	var reward := source.duplicate() as TowerReward
	# Keep immutable artwork shared, but never share editable branch records.
	reward.board_variants = source.board_variants.duplicate(true)
	reward.additional_archer_offsets = source.additional_archer_offsets.duplicate()
	reward.directional_weapon_textures = source.directional_weapon_textures.duplicate()
	reward.directional_projectile_origins = source.directional_projectile_origins.duplicate()
	return reward


static func _copy_record(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result["reward"] = _copy_reward(source["reward"])
	return result


static func _stage(commands: Array[String], title: String, parent_id: String) -> Dictionary:
	return {"id": "base" if commands.is_empty() else "/".join(commands), "title": title, "parent_id": parent_id, "commands": commands.duplicate()}


static func _stages(definition: TowerDefinition) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	stages.append(_stage([], definition.reward.title, ""))
	stages.append(_stage(["damage"], _stat_title(definition, "damage"), "base"))
	stages.append(_stage(["speed"], _stat_title(definition, "speed"), "base"))
	var path: Array[String] = ["damage", "speed"]
	stages.append(_stage(path, "Both upgrades", "damage"))
	var parent_id: String = "/".join(path)
	if not definition.special_upgrade.is_empty():
		path.append("special")
		stages.append(_stage(path, definition.special_upgrade_title, parent_id))
		parent_id = "/".join(path)
	for command: String in definition.advancements:
		var advancement_path: Array[String] = path.duplicate()
		var chain: Array[String] = _advancement_chain(definition.advancements, command)
		advancement_path.append_array(chain)
		var advancement_parent: String = parent_id
		if chain.size() > 1:
			advancement_parent = "/".join(advancement_path.slice(0, advancement_path.size() - 1))
		stages.append(_stage(advancement_path, definition.advancements[command]["title"], advancement_parent))
	for command: String in definition.evolutions:
		var branch: Dictionary = definition.evolutions[command]
		var branch_path: Array[String] = path.duplicate()
		branch_path.append(command)
		stages.append(_stage(branch_path, branch["title"], parent_id))
		var branch_id: String = "/".join(branch_path)
		if branch.has("followup"):
			var followup: Dictionary = branch["followup"]
			var followup_path: Array[String] = branch_path.duplicate()
			followup_path.append(followup["id"])
			stages.append(_stage(followup_path, followup["title"], branch_id))
		for followup_id: String in branch.get("followups", {}):
			var followup_path: Array[String] = branch_path.duplicate()
			followup_path.append(followup_id)
			stages.append(_stage(followup_path, branch["followups"][followup_id]["title"], branch_id))
		var step_path: Array[String] = branch_path.duplicate()
		var step_parent: String = branch_id
		for step: Dictionary in branch.get("upgrades", []):
			step_path.append(String(step["id"]))
			stages.append(_stage(step_path, step["title"], step_parent))
			step_parent = "/".join(step_path)
		# Exclusive capstone paths fork from the last ordered step.
		var capstones: Dictionary = branch.get("capstones", {})
		for capstone: String in capstones:
			var capstone_path: Array[String] = step_path.duplicate()
			var capstone_parent: String = step_parent
			for step: Dictionary in capstones[capstone]:
				capstone_path.append(String(step["id"]))
				stages.append(_stage(capstone_path, step["title"], capstone_parent))
				capstone_parent = "/".join(capstone_path)
	return stages


static func _advancement_chain(advancements: Dictionary, command: String) -> Array[String]:
	var chain: Array[String] = []
	var current: String = command
	while not current.is_empty() and advancements.has(current) and not chain.has(current):
		chain.push_front(current)
		current = String(advancements[current].get("requires", ""))
	return chain


static func _stat_title(definition: TowerDefinition, command: String) -> String:
	if definition.behavior_kind == "support":
		return "Damage aura" if command == "damage" else "Attack-speed aura"
	if definition.behavior_kind == "economy":
		return "Income upgrade I" if command == "damage" else "Income upgrade II"
	if definition.behavior_kind == "catapult":
		return "Slam upgrade" if command == "damage" else "Speed upgrade"
	return "Damage upgrade" if command == "damage" else "Speed upgrade"


static func _command_title(catalog: ContentCatalog, type_id: StringName, command: String) -> String:
	for definition: TowerDefinition in catalog.towers:
		if definition.reward.id != type_id:
			continue
		if command in ["damage", "speed"]:
			return _stat_title(definition, command)
		if command == "special":
			return definition.special_upgrade_title
		for branches: Dictionary in [definition.evolutions, definition.advancements]:
			if branches.has(command):
				return branches[command]["title"]
		for branch: Dictionary in definition.evolutions.values():
			if branch.get("followup", {}).get("id", "") == command:
				return branch["followup"]["title"]
			if branch.get("followups", {}).has(command):
				return branch["followups"][command]["title"]
			for step: Dictionary in branch.get("upgrades", []):
				if step["id"] == command:
					return step["title"]
			for path_steps: Array in branch.get("capstones", {}).values():
				for step: Dictionary in path_steps:
					if step["id"] == command:
						return step["title"]
	return command
