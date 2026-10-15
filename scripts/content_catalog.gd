class_name ContentCatalog
extends Resource
## The single authored registration list for match and collection content.

@export var towers: Array[TowerDefinition] = []
@export var enemies: Array[EnemyDefinition] = []


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
		if tower.reward.title.is_empty() or tower.damage <= 0 or not is_finite(tower.range_cells) or tower.range_cells <= 0.0 or not is_finite(tower.interval) or tower.interval <= 0.0 or tower.cost <= 0 or tower.upgrade_base_cost <= 0 or tower.damage_upgrade_bonus <= 0 or not is_finite(tower.speed_upgrade_multiplier) or tower.speed_upgrade_multiplier <= 0.0 or tower.speed_upgrade_multiplier >= 1.0:
			errors.append("Tower '%s' requires a title, positive stats/prices, and speed multiplier between zero and one." % id)
		if tower.special_upgrade not in ["", "second_archer"] or (not tower.special_upgrade.is_empty() and (tower.special_upgrade_title.is_empty() or tower.special_upgrade_cost <= 0)) or not TowerDefinition.valid_evolutions(tower):
			errors.append("Tower '%s' has invalid special upgrade or evolution metadata." % id)
		var art: TowerReward = tower.reward
		if not is_finite(art.board_height) or art.board_height <= 0.0 or not art.board_anchor.is_finite() or not art.projectile_origin.is_finite() or not is_finite(art.projectile_length) or art.projectile_length <= 0.0 or not is_finite(art.projectile_width) or art.projectile_width <= 0.0 or not art.secondary_sprite_region.position.is_finite() or not art.secondary_sprite_region.size.is_finite() or art.secondary_sprite_region.size.x < 0.0 or art.secondary_sprite_region.size.y < 0.0 or not art.secondary_sprite_offset.is_finite():
			errors.append("Tower '%s' has invalid presentation metadata." % id)
	var enemy_ids: Dictionary[StringName, bool] = {}
	for enemy: EnemyDefinition in enemies:
		if enemy == null:
			errors.append("Enemy catalog contains a missing definition.")
			continue
		if enemy.id == &"" or enemy_ids.has(enemy.id):
			errors.append("Enemy catalog contains an empty or duplicate ID '%s'." % enemy.id)
		enemy_ids[enemy.id] = true
		if enemy.title.is_empty() or not is_finite(enemy.health_multiplier) or enemy.health_multiplier <= 0.0 or not is_finite(enemy.speed_multiplier) or enemy.speed_multiplier <= 0.0 or enemy.send_cost <= 0 or enemy.send_income < 0 or enemy.base_damage <= 0 or enemy.spawn_weight <= 0 or enemy.first_wave < 1 or enemy.max_per_wave < 0 or enemy.count_cap_growth < 0 or enemy.count_cap_growth_interval < 1 or not is_finite(enemy.max_weight_share) or enemy.max_weight_share < 0.0 or enemy.max_weight_share > 1.0:
			errors.append("Enemy '%s' has invalid combat, economy, or wave values." % enemy.id)
		if not is_finite(enemy.board_height) or enemy.board_height <= 0.0 or not enemy.board_anchor.is_finite():
			errors.append("Enemy '%s' has invalid presentation metadata." % enemy.id)
	return errors
