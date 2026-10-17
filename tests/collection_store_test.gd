extends SceneTree

var failures: int = 0
var _root_path: String
var _cleanup_paths: Array[String] = []


func _init() -> void:
	_root_path = "user://collection_store_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var directory_error: Error = DirAccess.make_dir_absolute(_root_path)
	_check(directory_error == OK, "Create an isolated collection test directory")
	if directory_error == OK:
		_test_roll_boundaries()
		_test_persistence_and_exhaustion()
		_test_expanded_catalog_and_capping()
		_test_shipped_starter()
		_test_starter_persistence_and_reset()
		_test_starter_migration()
		_test_starter_write_failure()
		_test_write_failure()
		_test_reset_progress()
		_test_reset_failure()
		_test_missing_folder_failure()
		_test_invalid_saves()
		_test_unreadable_save()
		_test_invalid_catalog()
	_cleanup()
	if failures == 0:
		print("PASS: collection starter migration/reset, persistence, unique grants, exhaustion, 80/15/5 boundaries, capping, expanded catalog, and save failures")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _path(name: String) -> String:
	var path: String = _root_path.path_join(name)
	_cleanup_paths.append(path)
	_cleanup_paths.append(path + ".tmp")
	return path


func _catalog(size: int) -> ContentCatalog:
	var catalog := ContentCatalog.new()
	for index: int in range(size):
		var reward := TowerReward.new()
		reward.id = StringName("test_tower_%d" % index)
		reward.title = "Test tower %d" % index
		var tower := TowerDefinition.new()
		tower.reward = reward
		catalog.towers.append(tower)
	return catalog


func _rng_for_roll(expected_roll: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	for seed_value: int in range(10000):
		random.seed = seed_value
		if random.randi_range(0, 99) == expected_roll:
			random.seed = seed_value
			return random
	_check(false, "Find a deterministic seed for roll %d" % expected_roll)
	return null


func _write_fixture(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Write isolated save fixture '%s'" % path)
	if file != null:
		file.store_string(text)
		file.close()


func _check_grant(result: ChestResult, expected_size: int, description: String) -> void:
	_check(result.error_message.is_empty(), description + ": no grant error")
	_check(result.rewards.size() == expected_size, description + ": expected number of rewards")
	var seen: Dictionary[StringName, bool] = {}
	for reward: TowerReward in result.rewards:
		_check(not seen.has(reward.id), description + ": each reward is unique")
		seen[reward.id] = true


func _test_roll_boundaries() -> void:
	var boundaries: Dictionary[int, int] = {0: 1, 79: 1, 80: 3, 94: 3, 95: 5, 99: 5}
	for roll: int in boundaries:
		var random: RandomNumberGenerator = _rng_for_roll(roll)
		if random == null:
			continue
		var store := CollectionStore.new(_path("boundary_%d.json" % roll), _catalog(7), random)
		var result: ChestResult = store.open_chest()
		_check(result.rolled_count == boundaries[roll], "Opening uses the count roll at boundary %d" % roll)
		_check_grant(result, boundaries[roll], "Boundary %d grant" % roll)
	var frequencies: Dictionary[int, int] = {1: 0, 3: 0, 5: 0}
	for roll: int in range(100):
		frequencies[CollectionStore._count_for_roll(roll)] += 1
	_check(frequencies == {1: 80, 3: 15, 5: 5}, "The count mapping covers exactly 80/15/5 of the 100 rolls")


func _test_persistence_and_exhaustion() -> void:
	var path: String = _path("persistence.json")
	var catalog: ContentCatalog = _catalog(7)
	var random: RandomNumberGenerator = _rng_for_roll(0)
	if random == null:
		return
	var store := CollectionStore.new(path, catalog, random)
	_check(store.can_open() and store.unlocked_count() == 0, "Missing save starts an empty, openable collection")
	_check(not FileAccess.file_exists(path), "Construction does not create a save")
	var first: ChestResult = store.open_chest()
	_check_grant(first, 1, "First opening")
	if first.rewards.is_empty():
		return
	var reconstructed := CollectionStore.new(path, catalog, _rng_for_roll(0))
	_check(reconstructed.error_message.is_empty(), "Reconstruction accepts the written save")
	_check(reconstructed.unlocked_count() == 1 and reconstructed.is_unlocked(first.rewards[0].id), "Granted tower persists before any presentation")
	var seen: Dictionary[StringName, bool] = {first.rewards[0].id: true}
	for opening: int in range(catalog.towers.size()):
		if not reconstructed.can_open():
			break
		var result: ChestResult = reconstructed.open_chest()
		_check(result.error_message.is_empty() and not result.rewards.is_empty(), "Every available opening succeeds")
		for reward: TowerReward in result.rewards:
			_check(not seen.has(reward.id), "Later openings only grant previously locked towers")
			seen[reward.id] = true
	_check(seen.size() == catalog.towers.size(), "All catalog identities can be unlocked")
	_check(reconstructed.remaining_count() == 0 and not reconstructed.can_open(), "Exhaustion disables openings")
	var saved: String = FileAccess.get_file_as_string(path)
	var exhausted_result: ChestResult = reconstructed.open_chest()
	_check(exhausted_result.rewards.is_empty() and not exhausted_result.error_message.is_empty(), "Direct exhausted opening grants nothing")
	_check(FileAccess.get_file_as_string(path) == saved, "Exhausted opening does not rewrite the save")
	var final_store := CollectionStore.new(path, catalog)
	_check(final_store.unlocked_count() == catalog.towers.size() and not final_store.can_open(), "Exhaustion survives reconstruction")


func _test_expanded_catalog_and_capping() -> void:
	var random: RandomNumberGenerator = _rng_for_roll(95)
	if random == null:
		return
	var expanded := CollectionStore.new(_path("expanded.json"), _catalog(8), random)
	var five: ChestResult = expanded.open_chest()
	_check(five.rolled_count == 5, "Expanded catalog receives a five-count roll")
	_check_grant(five, 5, "Expanded catalog grants five unique towers")
	for remaining: int in [1, 2, 3, 4]:
		var capped := CollectionStore.new(_path("cap_%d.json" % remaining), _catalog(remaining), _rng_for_roll(99))
		var result: ChestResult = capped.open_chest()
		_check(result.rolled_count == 5, "Capped opening retains the original rolled count")
		_check_grant(result, remaining, "Cap to %d remaining towers" % remaining)
		_check(not capped.can_open(), "Capped opening exhausts its catalog")
	var partial_path: String = _path("partially_unlocked.json")
	_write_fixture(partial_path, '{"version":1,"unlocked":["test_tower_0","test_tower_1"]}')
	var partial := CollectionStore.new(partial_path, _catalog(4), _rng_for_roll(95))
	var last_two: ChestResult = partial.open_chest()
	_check_grant(last_two, 2, "Cap uses remaining locked types, not catalog size")
	for reward: TowerReward in last_two.rewards:
		_check(reward.id != &"test_tower_0" and reward.id != &"test_tower_1", "Capped rewards exclude prior unlocks")


func _test_shipped_starter() -> void:
	var path: String = _path("shipped_starter.json")
	var store := CollectionStore.new(path)
	_check(store.content_catalog.starter_tower_id == &"arrow_tower", "Shipped collection authors Arrow as its guaranteed starter")
	_check(store.error_message.is_empty() and store.is_unlocked(&"arrow_tower"), "Fresh shipped collection grants its saved Arrow starter")
	_check(store.unlocked_count() == 1 and FileAccess.file_exists(path), "Fresh starter is saved without opening a chest")
	var restored := CollectionStore.new(path)
	_check(restored.is_unlocked(&"arrow_tower"), "Shipped starter survives restarting")
	_check(restored.reset_progress(), "Shipped starter collection can reset")
	var reset := CollectionStore.new(path)
	_check(reset.unlocked_count() == 1 and reset.is_unlocked(&"arrow_tower"), "Reset keeps the saved Arrow starter")


func _test_starter_persistence_and_reset() -> void:
	var path: String = _path("custom_starter.json")
	var catalog: ContentCatalog = _catalog(4)
	catalog.starter_tower_id = catalog.towers[2].reward.id
	var store := CollectionStore.new(path, catalog, _rng_for_roll(95))
	_check(store.error_message.is_empty() and store.unlocked_count() == 1 and store.is_unlocked(catalog.starter_tower_id), "Injected catalog grants its authored starter, regardless of identity or position")
	var restored := CollectionStore.new(path, catalog, _rng_for_roll(95))
	_check(restored.unlocked_count() == 1 and restored.is_unlocked(catalog.starter_tower_id), "Authored starter survives reconstruction")
	var result: ChestResult = restored.open_chest()
	_check_grant(result, catalog.towers.size() - 1, "Starter is excluded from chest grants")
	for reward: TowerReward in result.rewards:
		_check(reward.id != catalog.starter_tower_id, "Chest never regrants the guaranteed starter")
	_check(restored.reset_progress(), "Authored starter collection resets successfully")
	var reset := CollectionStore.new(path, catalog)
	for reward: TowerReward in catalog.tower_rewards():
		_check(reset.is_unlocked(reward.id) == (reward.id == catalog.starter_tower_id), "Reset persists only the catalog's starter")
	_check(reset.can_open(), "Reset starter leaves the remaining collection openable")


func _test_starter_migration() -> void:
	var path: String = _path("starter_migration.json")
	var catalog: ContentCatalog = _catalog(4)
	catalog.starter_tower_id = catalog.towers[2].reward.id
	_write_fixture(path, '{"version":1,"unlocked":["test_tower_0","test_tower_1"]}')
	var store := CollectionStore.new(path, catalog)
	_check(store.error_message.is_empty() and store.unlocked_count() == 3, "Version-one saves migrate without changing their schema")
	for id: StringName in [&"test_tower_0", &"test_tower_1", catalog.starter_tower_id]:
		_check(store.is_unlocked(id), "Starter migration preserves every legacy unlock")
	var restored := CollectionStore.new(path, catalog)
	_check(restored.unlocked_count() == 3 and restored.is_unlocked(catalog.starter_tower_id), "Migrated starter is persisted before construction returns")
	var saved: String = FileAccess.get_file_as_string(path)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Block unnecessary migration writes")
	var unchanged := CollectionStore.new(path, catalog)
	_check(unchanged.error_message.is_empty() and unchanged.unlocked_count() == 3, "Already migrated saves load without requiring another write")
	_check(FileAccess.get_file_as_string(path) == saved, "Already migrated save bytes are unchanged")


func _test_starter_write_failure() -> void:
	var catalog: ContentCatalog = _catalog(3)
	catalog.starter_tower_id = catalog.towers[1].reward.id
	var fresh_path: String = _path("blocked_starter.json")
	_check(DirAccess.make_dir_absolute(fresh_path + ".tmp") == OK, "Block first starter save")
	var fresh := CollectionStore.new(fresh_path, catalog)
	_check(not fresh.error_message.is_empty() and fresh.unlocked_count() == 0 and not fresh.can_open(), "Failed first save grants no unpersisted starter")
	_check(not FileAccess.file_exists(fresh_path) and fresh.open_chest().rewards.is_empty(), "Failed starter initialization creates no save or chest rewards")
	var path: String = _path("blocked_starter_migration.json")
	var legacy: String = '{"version":1,"unlocked":["test_tower_0"]}'
	_write_fixture(path, legacy)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Block legacy starter migration")
	var store := CollectionStore.new(path, catalog)
	_check(not store.error_message.is_empty() and store.error_message.contains(path + ".tmp"), "Failed starter migration exposes its write error")
	_check(store.unlocked_count() == 1 and store.is_unlocked(&"test_tower_0") and not store.is_unlocked(catalog.starter_tower_id), "Failed migration preserves legacy unlocks without granting an unpersisted starter")
	_check(not store.can_open() and store.open_chest().rewards.is_empty() and not store.reset_progress(), "Failed migration disables collection mutations")
	_check(FileAccess.get_file_as_string(path) == legacy, "Failed migration preserves original save bytes")
	_check(DirAccess.remove_absolute(path + ".tmp") == OK, "Restore migration save access")
	var restored := CollectionStore.new(path, catalog)
	_check(restored.error_message.is_empty() and restored.unlocked_count() == 2 and restored.is_unlocked(catalog.starter_tower_id), "Reopening after restoring writes safely migrates the legacy collection")
	var saved: String = FileAccess.get_file_as_string(path)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Block starter-preserving reset")
	_check(not restored.reset_progress() and restored.unlocked_count() == 2 and restored.is_unlocked(&"test_tower_0") and restored.is_unlocked(catalog.starter_tower_id), "Failed reset retains both starter and legacy unlocks")
	_check(FileAccess.get_file_as_string(path) == saved, "Failed starter reset preserves saved bytes")


func _test_reset_progress() -> void:
	var path: String = _path("reset.json")
	var catalog: ContentCatalog = _catalog(3)
	var store := CollectionStore.new(path, catalog, _rng_for_roll(95))
	_check_grant(store.open_chest(), 3, "Complete collection before reset")
	_check(not store.can_open(), "Completed collection rejects more chests")
	_check(store.reset_progress(), "Completed collection can be reset")
	_check(store.unlocked_count() == 0 and store.can_open(), "Reset enables openings with no unlocks")
	var restored := CollectionStore.new(path, catalog, _rng_for_roll(0))
	for reward: TowerReward in catalog.tower_rewards():
		_check(not restored.is_unlocked(reward.id), "Reset removes every saved unlock")
	_check_grant(restored.open_chest(), 1, "A reset collection can grant new rewards")


func _test_reset_failure() -> void:
	var path: String = _path("blocked_reset.json")
	var catalog: ContentCatalog = _catalog(3)
	var store := CollectionStore.new(path, catalog, _rng_for_roll(95))
	_check_grant(store.open_chest(), 3, "Pre-failure reset collection")
	var previous_save: String = FileAccess.get_file_as_string(path)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Block reset temporary save")
	_check(not store.reset_progress(), "Failed reset reports failure")
	for reward: TowerReward in catalog.tower_rewards():
		_check(store.is_unlocked(reward.id), "Failed reset retains in-memory unlocks")
	_check(FileAccess.get_file_as_string(path) == previous_save, "Failed reset preserves saved bytes")


func _test_write_failure() -> void:
	var path: String = _path("blocked_write.json")
	var random: RandomNumberGenerator = _rng_for_roll(0)
	if random == null:
		return
	var catalog: ContentCatalog = _catalog(6)
	var store := CollectionStore.new(path, catalog, random)
	var first: ChestResult = store.open_chest()
	_check_grant(first, 1, "Pre-failure opening")
	if first.rewards.is_empty():
		return
	var previous_save: String = FileAccess.get_file_as_string(path)
	var block_error: Error = DirAccess.make_dir_absolute(path + ".tmp")
	_check(block_error == OK, "Block temporary file creation with a directory")
	var failed: ChestResult = store.open_chest()
	_check(failed.rewards.is_empty() and not failed.error_message.is_empty(), "Failed write reports an error and grants nothing")
	_check(failed.error_message == store.error_message and failed.error_message.contains(path + ".tmp"), "Failure identifies its path and is available to the screen")
	_check(store.unlocked_count() == 1 and store.is_unlocked(first.rewards[0].id), "Failed write preserves the prior in-memory collection")
	_check(FileAccess.get_file_as_string(path) == previous_save, "Failed write preserves the previous save byte for byte")
	var reconstructed := CollectionStore.new(path, catalog)
	_check(reconstructed.unlocked_count() == 1 and reconstructed.is_unlocked(first.rewards[0].id), "Only the earlier grant survives reconstruction")
	_check(not store.can_open() and store.open_chest().rewards.is_empty(), "Errored store disables further openings without additional grants")


func _test_missing_folder_failure() -> void:
	var path: String = _path("missing_folder/collection.json")
	var store := CollectionStore.new(path, _catalog(3), _rng_for_roll(95))
	var result: ChestResult = store.open_chest()
	_check(result.rewards.is_empty() and not result.error_message.is_empty(), "Missing save folder is a visible write failure")
	_check(store.unlocked_count() == 0 and not FileAccess.file_exists(path), "Initial write failure leaves collection empty and creates no save")


func _test_invalid_saves() -> void:
	var fixtures: Array[String] = [
		'{broken',
		'',
		'[]',
		'{"version":2,"unlocked":[]}',
		'{"version":1.5,"unlocked":[]}',
		'{"version":true,"unlocked":[]}',
		'{"version":1}',
		'{"version":1,"unlocked":[],"future_field":true}',
		'{"version":1,"unlocked":{}}',
		'{"version":1,"unlocked":["test_tower_0","test_tower_0"]}',
		'{"version":1,"unlocked":["test_tower_0","unknown"]}',
		'{"version":1,"unlocked":["test_tower_0",12]}',
		'{"version":1,"unlocked":[""]}',
	]
	var catalog: ContentCatalog = _catalog(3)
	catalog.starter_tower_id = catalog.towers[1].reward.id
	for index: int in range(fixtures.size()):
		var path: String = _path("invalid_%d.json" % index)
		_write_fixture(path, fixtures[index])
		var store := CollectionStore.new(path, catalog)
		_check(not store.error_message.is_empty() and store.error_message.contains(path), "Invalid save %d has an actionable path-specific error" % index)
		_check(not store.can_open() and store.unlocked_count() == 0, "Invalid save %d disables openings without partial loading" % index)
		var result: ChestResult = store.open_chest()
		_check(result.rewards.is_empty() and result.error_message == store.error_message, "Invalid save %d cannot grant towers" % index)
		_check(not store.reset_progress(), "Invalid save %d cannot be overwritten by reset" % index)
		_check(FileAccess.get_file_as_string(path) == fixtures[index], "Invalid save %d remains untouched" % index)
		_check(not FileAccess.file_exists(path + ".tmp"), "Invalid save %d never attempts a write" % index)


func _test_unreadable_save() -> void:
	var path: String = _path("directory_instead_of_save.json")
	_check(DirAccess.make_dir_absolute(path) == OK, "Create an unreadable save destination")
	var catalog: ContentCatalog = _catalog(3)
	catalog.starter_tower_id = catalog.towers[1].reward.id
	var store := CollectionStore.new(path, catalog)
	_check(not store.error_message.is_empty() and not store.can_open(), "An existing unreadable save disables openings")
	_check(store.open_chest().rewards.is_empty(), "Unreadable save grants nothing")
	_check(DirAccess.dir_exists_absolute(path), "Unreadable save is not removed or replaced")


func _test_invalid_catalog() -> void:
	var catalog: ContentCatalog = _catalog(2)
	catalog.towers[1].reward.id = catalog.towers[0].reward.id
	var path: String = _path("invalid_catalog.json")
	var store := CollectionStore.new(path, catalog)
	_check(not store.can_open() and not store.error_message.is_empty(), "Duplicate catalog IDs are rejected before granting")
	_check(store.open_chest().rewards.is_empty() and not FileAccess.file_exists(path), "Invalid catalog cannot create a collection save")
	var missing_starter: ContentCatalog = _catalog(2)
	missing_starter.starter_tower_id = &"unregistered_starter"
	var starter_path: String = _path("invalid_starter_catalog.json")
	var invalid := CollectionStore.new(starter_path, missing_starter)
	_check(not invalid.error_message.is_empty() and invalid.unlocked_count() == 0, "Unregistered starter is rejected before granting")
	_check(not FileAccess.file_exists(starter_path), "Invalid starter catalog cannot create a save")


func _cleanup() -> void:
	for path: String in _cleanup_paths:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			_check(DirAccess.remove_absolute(path) == OK, "Remove isolated fixture '%s'" % path)
	if DirAccess.dir_exists_absolute(_root_path):
		_check(DirAccess.remove_absolute(_root_path) == OK, "Remove isolated collection test directory")
