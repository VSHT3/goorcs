class_name CollectionStore
extends RefCounted

const SAVE_VERSION: int = 1
const DEFAULT_CATALOG: Array[TowerReward] = [
	preload("res://resources/collection/arrow_tower.tres"),
	preload("res://resources/collection/orc_ballista.tres"),
	preload("res://resources/collection/rune_obelisk.tres"),
]

var catalog: Array[TowerReward] = []
var error_message: String = ""
var _save_path: String
var _random: RandomNumberGenerator
var _unlocked: Dictionary[StringName, bool] = {}


func _init(save_path: String = "user://collection.json",
		catalog_override: Array[TowerReward] = [], random: RandomNumberGenerator = null) -> void:
	_save_path = save_path
	catalog.assign(DEFAULT_CATALOG if catalog_override.is_empty() else catalog_override)
	_random = random
	if _random == null:
		_random = RandomNumberGenerator.new()
		_random.randomize()
	var known_ids: Dictionary[StringName, bool] = {}
	for reward: TowerReward in catalog:
		if reward == null or reward.id == &"" or known_ids.has(reward.id):
			error_message = "Collection catalog contains a missing or duplicate tower ID. Fix the catalog before opening chests."
			return
		known_ids[reward.id] = true
	_load(known_ids)


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func remaining_count() -> int:
	return catalog.size() - _unlocked.size()


func can_open() -> bool:
	return error_message.is_empty() and remaining_count() > 0


# These provisional odds concern the local collection, not match rewards.
static func _count_for_roll(roll: int) -> int:
	if roll < 80:
		return 1
	if roll < 95:
		return 3
	return 5


func open_chest() -> ChestResult:
	var result := ChestResult.new()
	if not error_message.is_empty():
		result.error_message = error_message
		return result
	if remaining_count() == 0:
		result.error_message = "Every tower in this collection is already unlocked."
		return result
	var locked: Array[TowerReward] = []
	for reward: TowerReward in catalog:
		if not is_unlocked(reward.id):
			locked.append(reward)
	result.rolled_count = _count_for_roll(_random.randi_range(0, 99))
	var pending: Array[TowerReward] = []
	var next_unlocked: Dictionary[StringName, bool] = _unlocked.duplicate()
	for index: int in range(mini(result.rolled_count, locked.size())):
		var chosen_index: int = _random.randi_range(0, locked.size() - 1)
		var reward: TowerReward = locked[chosen_index]
		locked.remove_at(chosen_index)
		pending.append(reward)
		next_unlocked[reward.id] = true
	error_message = _persist(next_unlocked)
	if not error_message.is_empty():
		result.error_message = error_message
		return result
	# Commit only after the complete save has replaced the previous file.
	_unlocked = next_unlocked
	result.rewards = pending
	return result


func _load(known_ids: Dictionary[StringName, bool]) -> void:
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		if open_error == ERR_FILE_NOT_FOUND and not DirAccess.dir_exists_absolute(_save_path):
			return
		error_message = "Cannot read collection save '%s': %s. Restore read access, then reopen the game; no save was changed." % [_save_path, error_string(open_error)]
		return
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		error_message = "Cannot read collection save '%s': %s. Restore read access, then reopen the game; no save was changed." % [_save_path, error_string(read_error)]
		return
	var json := JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		_invalid_save("invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	if not json.data is Dictionary:
		_invalid_save("the root must be an object")
		return
	var data: Dictionary = json.data
	if data.size() != 2 or not data.has("version") or not data.has("unlocked"):
		_invalid_save("expected exactly 'version' and 'unlocked' fields")
		return
	var version: Variant = data["version"]
	if (typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT) or version != SAVE_VERSION:
		_invalid_save("unsupported save version '%s' (expected %d)" % [str(version), SAVE_VERSION])
		return
	if not data["unlocked"] is Array:
		_invalid_save("'unlocked' must be an array of tower IDs")
		return
	var loaded: Dictionary[StringName, bool] = {}
	for value: Variant in data["unlocked"]:
		if not value is String or value.is_empty():
			_invalid_save("every unlocked ID must be a nonempty string")
			return
		var id := StringName(value)
		if not known_ids.has(id):
			_invalid_save("unknown tower ID '%s'; use a catalog that contains it" % value)
			return
		if loaded.has(id):
			_invalid_save("duplicate unlocked tower ID '%s'" % value)
			return
		loaded[id] = true
	_unlocked = loaded


func _invalid_save(reason: String) -> void:
	error_message = "Collection save '%s' is invalid: %s. Repair this file or move it aside to start a new collection, then reopen the game; the file was not changed." % [_save_path, reason]


func _persist(next_unlocked: Dictionary[StringName, bool]) -> String:
	var ids: Array[String] = []
	for reward: TowerReward in catalog:
		if next_unlocked.has(reward.id):
			ids.append(String(reward.id))
	var temporary_path: String = _save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return "Cannot write collection temporary save '%s': %s. Check the folder and write permissions, then reopen the game. No towers were granted; the previous save is unchanged." % [temporary_path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "unlocked": ids}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return "Cannot finish writing collection save '%s': %s. Check free disk space and write permissions, then reopen the game. No towers were granted; the previous save is unchanged." % [temporary_path, error_string(write_error)]
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(_save_path))
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return "Cannot replace collection save '%s': %s. Check the destination and folder permissions, then reopen the game. No towers were granted; the previous save is unchanged." % [_save_path, error_string(rename_error)]
	return ""
