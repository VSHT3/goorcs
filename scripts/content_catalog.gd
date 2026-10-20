class_name ContentCatalog
extends Resource
## The single authored registration list for match and collection content.

@export var towers: Array[TowerDefinition] = []
@export var enemies: Array[EnemyDefinition] = []
# Empty preserves collection-only/custom catalogs with no guaranteed starter.
@export var starter_tower_id: StringName = &""


func tower_rewards() -> Array[TowerReward]:
	var rewards: Array[TowerReward] = []
	for tower: TowerDefinition in towers:
		if tower != null and tower.reward != null:
			rewards.append(tower.reward)
	return rewards


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var tower_ids: Dictionary[StringName, bool] = {}
	for tower: TowerDefinition in towers:
		if tower == null or tower.reward == null:
			errors.append("Tower catalog contains a missing definition or reward.")
			continue
		var id: StringName = tower.reward.id
		if id == &"" or tower_ids.has(id):
			errors.append("Tower catalog contains an empty or duplicate ID '%s'." % id)
		tower_ids[id] = true
		if tower.damage_type not in [&"physical", &"fire", &"magic", &"lightning", &"explosive", &"ice"]:
			errors.append("Tower '%s' has an unknown damage type." % id)
		if tower.reward.title.is_empty() or tower.damage < 0 or (tower.behavior_kind in ["attack", "chain", "catapult"] and tower.damage == 0) or not is_finite(tower.range_cells) or tower.range_cells <= 0.0 or not is_finite(tower.interval) or tower.interval <= 0.0 or tower.cost <= 0 or tower.upgrade_base_cost <= 0 or tower.damage_upgrade_bonus <= 0 or not is_finite(tower.speed_upgrade_multiplier) or tower.speed_upgrade_multiplier <= 0.0 or tower.speed_upgrade_multiplier >= 1.0:
			errors.append("Tower '%s' requires a title, positive attack stats/prices, nonnegative passive damage, and speed multiplier between zero and one." % id)
		if not TowerDefinition.valid_behavior(tower):
			errors.append("Tower '%s' has invalid behavior or role-upgrade metadata." % id)
		if not TowerDefinition.valid_special_upgrade(tower) or not TowerDefinition.valid_evolutions(tower):
			errors.append("Tower '%s' has invalid special upgrade or evolution metadata." % id)
		if not TowerDefinition.valid_roll_attributes(tower):
			errors.append("Tower '%s' has invalid attribute compatibility or roll profile metadata." % id)
		if not TowerDefinition.valid_advancements(tower):
			errors.append("Tower '%s' has invalid advancement metadata." % id)
		if tower.attack_sound not in [CombatSoundEvents.Cue.BOW, CombatSoundEvents.Cue.BALLISTA, CombatSoundEvents.Cue.RUNE]:
			errors.append("Tower '%s' has an unknown attack sound family." % id)
		var art: TowerReward = tower.reward
		if not is_finite(art.board_height) or art.board_height <= 0.0 or not art.board_anchor.is_finite() or not art.projectile_origin.is_finite() or not is_finite(art.projectile_length) or art.projectile_length <= 0.0 or not is_finite(art.projectile_width) or art.projectile_width <= 0.0 or not art.archer_pivot.is_finite() or not art.secondary_sprite_offset.is_finite() or not art.catapult_pivot.is_finite() or not art.catapult_arm_pivot.is_finite():
			errors.append("Tower '%s' has invalid presentation metadata." % id)
		if not _valid_board_variants(tower):
			errors.append("Tower '%s' has invalid branch presentation metadata." % id)
		if not _valid_directional_weapon(art):
			errors.append("Tower '%s' has invalid directional weapon presentation metadata." % id)
		for offset: Vector2 in art.additional_archer_offsets:
			if not offset.is_finite():
				errors.append("Tower '%s' has invalid additional archer offsets." % id)
	if starter_tower_id != &"" and not tower_ids.has(starter_tower_id):
		errors.append("Starter tower '%s' must resolve to a registered tower." % starter_tower_id)
	var enemy_ids: Dictionary[StringName, EnemyDefinition] = {}
	for enemy: EnemyDefinition in enemies:
		if enemy == null:
			errors.append("Enemy catalog contains a missing definition.")
			continue
		if enemy.id == &"" or enemy_ids.has(enemy.id):
			errors.append("Enemy catalog contains an empty or duplicate ID '%s'." % enemy.id)
		enemy_ids[enemy.id] = enemy
		if enemy.title.is_empty() or not is_finite(enemy.health_multiplier) or enemy.health_multiplier <= 0.0 or not is_finite(enemy.speed_multiplier) or enemy.speed_multiplier <= 0.0 or enemy.send_cost <= 0 or (enemy.send_income < 0 and not enemy.boss) or enemy.base_damage <= 0 or enemy.spawn_weight <= 0 or enemy.first_wave < 1 or enemy.max_per_wave < 0 or enemy.count_cap_growth < 0 or enemy.count_cap_growth_interval < 1 or not is_finite(enemy.max_weight_share) or enemy.max_weight_share < 0.0 or enemy.max_weight_share > 1.0:
			errors.append("Enemy '%s' has invalid combat, economy, or wave values." % enemy.id)
		if enemy.send_first_wave < 1 or enemy.kill_bounty < -1 or not is_finite(enemy.group_interval) or enemy.group_interval <= 0.0:
			errors.append("Enemy '%s' has invalid send, bounty, or group timing metadata." % enemy.id)
		if enemy.health_base_multiplier < 1 or (enemy.health_base_type == &"" and enemy.health_base_multiplier != 1):
			errors.append("Enemy '%s' requires a registered HP base with a positive integer multiplier, or empty/one defaults." % enemy.id)
		if enemy.spawn_variant_first_wave < 1 or not is_finite(enemy.spawn_variant_chance) or enemy.spawn_variant_chance < 0.0 or enemy.spawn_variant_chance > 1.0 or ((enemy.spawn_variant == &"") != (enemy.spawn_variant_chance == 0.0)):
			errors.append("Enemy '%s' requires a spawn variant with finite positive odds up to one, or disabled defaults." % enemy.id)
		if enemy.hit_shield < 0 or not is_finite(enemy.death_stun_radius) or enemy.death_stun_radius < 0.0 or not is_finite(enemy.death_stun_duration) or enemy.death_stun_duration < 0.0 or ((enemy.death_stun_radius == 0.0) != (enemy.death_stun_duration == 0.0)):
			errors.append("Enemy '%s' requires a nonnegative hit shield and positive death-stun radius/duration together, or zero defaults." % enemy.id)
		if not is_finite(enemy.death_bomb_fuse) or enemy.death_bomb_fuse < 0.0 or not is_finite(enemy.death_bomb_radius) or enemy.death_bomb_radius < 0.0 or not is_finite(enemy.death_bomb_stun_duration) or enemy.death_bomb_stun_duration < 0.0 or ((enemy.death_bomb_fuse == 0.0) != (enemy.death_bomb_radius == 0.0)) or ((enemy.death_bomb_fuse == 0.0) != (enemy.death_bomb_stun_duration == 0.0)):
			errors.append("Enemy '%s' requires positive death-bomb fuse/radius/stun together, or zero defaults." % enemy.id)
		if enemy.boss and (enemy.group_weights.size() != 1 or not is_finite(enemy.boss_spawn_chance) or enemy.boss_spawn_chance < 0.0 or not is_finite(enemy.boss_spawn_chance_growth) or enemy.boss_spawn_chance_growth < 0.0 or not is_finite(enemy.boss_spawn_chance_cap) or enemy.boss_spawn_chance_cap < enemy.boss_spawn_chance or enemy.boss_spawn_chance_cap > 1.0):
			errors.append("Enemy '%s' requires a single-member boss and finite encounter odds between zero and one with nonnegative growth." % enemy.id)
		# Either zero permits authored enemies with no effective reroll payout.
		if not is_finite(enemy.reroll_drop_chance) or enemy.reroll_drop_chance < 0.0 or enemy.reroll_drop_chance > 1.0 or enemy.reroll_drop_amount < 0:
			errors.append("Enemy '%s' requires a finite reroll drop chance between zero and one and a nonnegative payout." % enemy.id)
		var group_total: int = 0
		for weight: int in enemy.group_weights:
			if weight < 0:
				errors.append("Enemy '%s' has negative group odds." % enemy.id)
			group_total += weight
		if group_total <= 0:
			errors.append("Enemy '%s' requires positive group odds." % enemy.id)
		if not is_finite(enemy.heal_interval) or enemy.heal_interval < 0.0 or not is_finite(enemy.heal_radius) or enemy.heal_radius < 0.0 or not is_finite(enemy.heal_fraction) or enemy.heal_fraction < 0.0 or enemy.heal_fraction > 1.0 or (enemy.heal_interval > 0.0 and (enemy.heal_radius <= 0.0 or enemy.heal_fraction <= 0.0)):
			errors.append("Enemy '%s' has invalid healing metadata." % enemy.id)
		if not is_finite(enemy.physical_damage_multiplier) or enemy.physical_damage_multiplier <= 0.0 or not is_finite(enemy.nonphysical_damage_multiplier) or enemy.nonphysical_damage_multiplier <= 0.0 or not is_finite(enemy.fire_damage_multiplier) or enemy.fire_damage_multiplier <= 0.0 or not is_finite(enemy.lightning_damage_multiplier) or enemy.lightning_damage_multiplier <= 0.0:
			errors.append("Enemy '%s' requires finite positive incoming damage multipliers." % enemy.id)
		if enemy.death_spawn_count < 0 or ((enemy.death_spawn_type == &"") != (enemy.death_spawn_count == 0)):
			errors.append("Enemy '%s' requires a death child and positive count together." % enemy.id)
		if not is_finite(enemy.enrage_health_fraction) or enemy.enrage_health_fraction < 0.0 or enemy.enrage_health_fraction > 1.0 or not is_finite(enemy.enrage_speed_multiplier) or enemy.enrage_speed_multiplier < 1.0 or (enemy.enrage_health_fraction > 0.0 and enemy.enrage_speed_multiplier <= 1.0) or (enemy.enrage_health_fraction == 0.0 and enemy.enrage_speed_multiplier != 1.0):
			errors.append("Enemy '%s' requires an enrage threshold in (0, 1] and speed multiplier above one, or disabled defaults." % enemy.id)
		if not is_finite(enemy.regeneration_interval) or enemy.regeneration_interval < 0.0 or not is_finite(enemy.regeneration_fraction) or enemy.regeneration_fraction < 0.0 or enemy.regeneration_fraction > 1.0 or ((enemy.regeneration_interval == 0.0) != (enemy.regeneration_fraction == 0.0)):
			errors.append("Enemy '%s' requires positive regeneration interval and fraction together, or zero defaults." % enemy.id)
		if not is_finite(enemy.stomp_interval) or enemy.stomp_interval < 0.0 or not is_finite(enemy.stomp_radius) or enemy.stomp_radius < 0.0 or not is_finite(enemy.stomp_health_fraction) or enemy.stomp_health_fraction < 0.0 or enemy.stomp_health_fraction > 1.0 or (enemy.stomp_interval > 0.0 and (enemy.stomp_radius <= 0.0 or enemy.stomp_health_fraction <= 0.0)):
			errors.append("Enemy '%s' has invalid stomp metadata." % enemy.id)
		if not is_finite(enemy.tower_attack_interval) or enemy.tower_attack_interval < 0.0 or not is_finite(enemy.tower_attack_range) or enemy.tower_attack_range < 0.0 or not is_finite(enemy.tower_attack_cast_duration) or enemy.tower_attack_cast_duration < 0.0 or not is_finite(enemy.tower_stun_duration) or enemy.tower_stun_duration < 0.0 or enemy.tower_attack_targets < 1 or (enemy.tower_attack_interval > 0.0 and (enemy.tower_attack_kind not in [&"club", &"cannon"] or (enemy.tower_attack_kind == &"club" and enemy.tower_attack_range <= 0.0) or enemy.tower_attack_cast_duration <= 0.0 or enemy.tower_stun_duration <= 0.0)) or (enemy.tower_attack_interval == 0.0 and enemy.tower_attack_kind != &""):
			errors.append("Enemy '%s' has invalid tower attack metadata." % enemy.id)
		if not is_finite(enemy.jump_interval) or enemy.jump_interval < 0.0 or not is_finite(enemy.jump_deploy_duration) or enemy.jump_deploy_duration < 0.0 or not is_finite(enemy.jump_charge_duration) or enemy.jump_charge_duration < 0.0 or not is_finite(enemy.jump_duration) or enemy.jump_duration < 0.0 or not is_finite(enemy.jump_land_duration) or enemy.jump_land_duration < 0.0 or (enemy.jump_interval > 0.0 and (enemy.jump_deploy_duration <= 0.0 or enemy.jump_charge_duration <= 0.0 or enemy.jump_duration <= 0.0 or enemy.jump_land_duration <= 0.0 or enemy.jump_weights.size() != 4)) or (enemy.jump_interval == 0.0 and not enemy.jump_weights.is_empty()):
			errors.append("Enemy '%s' has invalid periodic jump metadata." % enemy.id)
		var jump_total: int = 0
		for weight: int in enemy.jump_weights:
			if weight < 0:
				errors.append("Enemy '%s' has negative jump odds." % enemy.id)
			jump_total += weight
		if enemy.jump_interval > 0.0 and jump_total <= 0:
			errors.append("Enemy '%s' requires positive jump odds." % enemy.id)
		if enemy.summon_pool.size() != enemy.summon_weights.size():
			errors.append("Enemy '%s' requires matching summon pool and weight counts." % enemy.id)
		for weight: int in enemy.summon_weights:
			if weight <= 0:
				errors.append("Enemy '%s' requires positive summon weights." % enemy.id)
		if not is_finite(enemy.summon_interval) or enemy.summon_interval < 0.0 or not is_finite(enemy.summon_cast_duration) or enemy.summon_cast_duration < 0.0 or enemy.summon_min < 0 or enemy.summon_max < enemy.summon_min or enemy.summon_limit < 0 or (enemy.summon_interval > 0.0 and (enemy.summon_cast_duration <= 0.0 or (enemy.summon_type == &"" and enemy.summon_pool.is_empty()) or enemy.summon_min < 1 or enemy.summon_limit < 1)):
			errors.append("Enemy '%s' has invalid summoning metadata." % enemy.id)
		if not is_finite(enemy.board_height) or enemy.board_height <= 0.0 or not enemy.board_anchor.is_finite():
			errors.append("Enemy '%s' has invalid presentation metadata." % enemy.id)
		if enemy.animation_frames != null:
			var required: Array[StringName] = [&"walk"]
			if enemy.enrage_health_fraction > 0.0:
				required.append(&"walk_enraged")
			if enemy.heal_interval > 0.0 or enemy.regeneration_interval > 0.0:
				required.append(&"heal")
			if enemy.summon_interval > 0.0:
				required.append(&"cast")
			if enemy.tower_attack_interval > 0.0:
				required.append(&"attack")
			if enemy.jump_interval > 0.0:
				required.append_array([&"jump_deploy", &"jump_charge", &"jump", &"jump_land"])
			for animation: StringName in required:
				if not enemy.animation_frames.has_animation(animation) or enemy.animation_frames.get_frame_count(animation) == 0 or not is_finite(enemy.animation_frames.get_animation_speed(animation)) or enemy.animation_frames.get_animation_speed(animation) <= 0.0:
					errors.append("Enemy '%s' requires a playable '%s' animation." % [enemy.id, animation])
	for enemy: EnemyDefinition in enemies:
		if enemy != null:
			_validate_children(enemy, enemy_ids, {}, {}, errors)
			_validate_health_base(enemy, enemy_ids, {}, errors)
	return errors


static func child_ids(source: EnemyDefinition) -> PackedStringArray:
	var children := PackedStringArray()
	if source.summon_type != &"":
		children.append(String(source.summon_type))
	for child: String in source.summon_pool:
		if child not in children:
			children.append(child)
	if source.death_spawn_type != &"" and String(source.death_spawn_type) not in children:
		children.append(String(source.death_spawn_type))
	return children


static func _validate_children(source: EnemyDefinition, definitions: Dictionary[StringName, EnemyDefinition], ancestors: Dictionary, visited: Dictionary, errors: PackedStringArray) -> void:
	if ancestors.has(source.id):
		errors.append("Enemy '%s' has a cyclic summon/death-spawn/variant chain." % source.id)
		return
	if visited.has(source.id):
		return
	ancestors[source.id] = true
	var children: PackedStringArray = child_ids(source)
	if source.spawn_variant != &"" and String(source.spawn_variant) not in children:
		children.append(String(source.spawn_variant))
	for child_id: String in children:
		if not definitions.has(StringName(child_id)):
			errors.append("Enemy '%s' requires a registered summon/death-spawn/variant child '%s'." % [source.id, child_id])
			continue
		var child: EnemyDefinition = definitions[StringName(child_id)]
		if child.boss:
			errors.append("Enemy '%s' cannot create boss child '%s'." % [source.id, child_id])
		_validate_children(child, definitions, ancestors, visited, errors)
	ancestors.erase(source.id)
	visited[source.id] = true


static func _validate_health_base(source: EnemyDefinition, definitions: Dictionary[StringName, EnemyDefinition], ancestors: Dictionary, errors: PackedStringArray) -> void:
	if source.health_base_type == &"":
		return
	if ancestors.has(source.id):
		errors.append("Enemy '%s' has a cyclic HP-base chain." % source.id)
		return
	if not definitions.has(source.health_base_type):
		errors.append("Enemy '%s' requires a registered HP base '%s'." % [source.id, source.health_base_type])
		return
	ancestors[source.id] = true
	_validate_health_base(definitions[source.health_base_type], definitions, ancestors, errors)
	ancestors.erase(source.id)


static func _valid_directional_weapon(art: TowerReward) -> bool:
	if art.directional_weapon_textures.is_empty() and art.directional_projectile_origins.is_empty():
		return true
	if art.directional_weapon_textures.size() != 8 or art.directional_projectile_origins.size() != 8:
		return false
	if art.icon_texture == null or art.board_texture == null:
		return false
	var canvas: Vector2 = art.icon_texture.get_size()
	if canvas.x <= 0.0 or canvas.y <= 0.0 or art.board_texture.get_size() != canvas:
		return false
	for index: int in range(8):
		var texture: Texture2D = art.directional_weapon_textures[index]
		var origin: Vector2 = art.directional_projectile_origins[index]
		if texture == null or texture.get_size() != canvas or not origin.is_finite():
			return false
		if origin.x < 0.0 or origin.y < 0.0 or origin.x >= canvas.x or origin.y >= canvas.y:
			return false
	return true


static func _valid_board_variants(tower: TowerDefinition) -> bool:
	var art: TowerReward = tower.reward
	if art.board_variants.is_empty():
		return true
	# Stat tiers may carry art too (see PathBoard._stat_tiers).
	var branches: Dictionary = {"damage": true, "speed": true, "damage_speed": true}
	if not tower.special_upgrade.is_empty():
		branches[tower.special_upgrade] = true
	for branch: Variant in tower.advancements:
		branches[branch] = true
	for branch: Variant in tower.evolutions:
		branches[branch] = true
		var config: Variant = tower.evolutions[branch]
		if not config is Dictionary:
			continue
		var followup: Variant = config.get("followup")
		if followup is Dictionary and typeof(followup.get("id")) == TYPE_STRING:
			branches[followup["id"]] = true
		var followups: Variant = config.get("followups")
		if followups is Dictionary:
			for followup_id: Variant in followups:
				branches[followup_id] = true
		var steps: Variant = config.get("upgrades")
		if steps is Array:
			for step: Variant in steps:
				if step is Dictionary and typeof(step.get("id")) == TYPE_STRING:
					branches[step["id"]] = true
		var capstones: Variant = config.get("capstones")
		if capstones is Dictionary:
			for path: Variant in capstones:
				if capstones[path] is Array:
					for step: Variant in capstones[path]:
						if step is Dictionary and typeof(step.get("id")) == TYPE_STRING:
							branches[step["id"]] = true
	for branch: Variant in art.board_variants:
		if typeof(branch) != TYPE_STRING or String(branch).is_empty() or not branches.has(branch) or not art.board_variants[branch] is Dictionary:
			return false
		var variant: Dictionary = art.board_variants[branch]
		for field: Variant in variant:
			if typeof(field) != TYPE_STRING or field not in ["texture", "board_height", "board_anchor", "archer_pivot", "secondary_sprite_offset", "additional_archer_offsets", "portrait_bounds", "directional_weapon_textures", "catapult_arm_texture"]:
				return false
		if not variant.get("texture") is Texture2D:
			return false
		if variant.has("catapult_arm_texture") and (art.catapult_arm_texture == null or not variant["catapult_arm_texture"] is Texture2D):
			return false
		if variant.has("directional_weapon_textures"):
			# A directional look replaces the base and all eight poses on the
			# shared canvas, keeping the authored release tips valid.
			var poses: Variant = variant["directional_weapon_textures"]
			if art.directional_weapon_textures.is_empty() or not poses is Array or (poses as Array).size() != 8:
				return false
			var canvas: Vector2 = art.icon_texture.get_size()
			if (variant["texture"] as Texture2D).get_size() != canvas:
				return false
			for pose: Variant in poses:
				if not pose is Texture2D or (pose as Texture2D).get_size() != canvas:
					return false
		var height: Variant = variant.get("board_height", art.board_height)
		if typeof(height) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(height)) or float(height) <= 0.0:
			return false
		var anchor: Variant = variant.get("board_anchor", art.board_anchor)
		if not anchor is Vector2:
			return false
		var normalized_anchor: Vector2 = anchor
		if not normalized_anchor.is_finite() or normalized_anchor.x < 0.0 or normalized_anchor.x > 1.0 or normalized_anchor.y < 0.0 or normalized_anchor.y > 1.0:
			return false
		for field: String in ["archer_pivot", "secondary_sprite_offset"]:
			if variant.has(field):
				if not variant[field] is Vector2 or not Vector2(variant[field]).is_finite():
					return false
		if variant.has("additional_archer_offsets"):
			if not variant["additional_archer_offsets"] is PackedVector2Array:
				return false
			for offset: Vector2 in variant["additional_archer_offsets"]:
				if not offset.is_finite():
					return false
		if variant.has("portrait_bounds"):
			if not variant["portrait_bounds"] is Rect2:
				return false
			var portrait: Rect2 = variant["portrait_bounds"]
			if not portrait.position.is_finite() or not portrait.size.is_finite() or portrait.size.x <= 0.0 or portrait.size.y <= 0.0:
				return false
	return true
