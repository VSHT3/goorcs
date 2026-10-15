class_name EnemyStatisticsStore
extends RefCounted
## Local lifetime counters and durable per-match high-water marks.
## Observe only accepted host snapshots and the local player's owned slot.

signal changed

const SAVE_VERSION: int = 1
const MAX_EXACT_COUNT: int = 9007199254740991

var error_message: String = ""
var _save_path: String
var _matches: Dictionary = {}
var _totals: Dictionary = {}
var _load_failed: bool = false


func _init(save_path: String = "user://enemy_statistics.json") -> void:
	_save_path = save_path
	_load()


func counts(id: StringName) -> Dictionary:
	var key: String = String(id)
	var values: Dictionary = _totals.get(key, {})
	return {"kills": int(values.get("kills", 0)), "sent": int(values.get("sent", 0))}


func observe(combat: Dictionary, slot: int) -> bool:
	if _load_failed or slot < 0 or slot > 1:
		return false
	var rules: Variant = combat.get("rules", {})
	if not rules is Dictionary or rules.get("sandbox_mode", true) != false:
		return false
	var match_id: Variant = combat.get("statistics_id", "")
	var sides: Variant = combat.get("enemy_totals")
	if not match_id is String or match_id.is_empty() or not sides is Array or sides.size() != 2:
		return false
	var side: Variant = sides[slot]
	if not side is Dictionary or not _valid_counts(side.get("kills")) or not _valid_counts(side.get("sent")):
		return false
	var previous: Dictionary = _matches.get(match_id, {"slot": slot, "kills": {}, "sent": {}})
	# The first accepted observation binds ownership for this match. A mirrored
	# board or accidentally delivered peer slot must never become a second grant.
	if int(previous["slot"]) != slot:
		return false
	var next_match: Dictionary = previous.duplicate(true)
	var next_totals: Dictionary = _totals.duplicate(true)
	var advanced: bool = not _matches.has(match_id)
	for counter: String in ["kills", "sent"]:
		for raw_id: Variant in side[counter]:
			var id: String = String(raw_id)
			var value: int = int(side[counter][raw_id])
			var old: int = int(previous[counter].get(id, 0))
			if value <= old:
				continue
			var total: Dictionary = next_totals.get(id, {"kills": 0, "sent": 0})
			if int(total[counter]) > MAX_EXACT_COUNT - (value - old):
				_set_error("Enemy statistics could not be saved: the lifetime count for '%s' is too large. The previous save is unchanged." % id)
				return false
			total[counter] = int(total[counter]) + value - old
			next_totals[id] = total
			next_match[counter][id] = value
			advanced = true
	if not advanced:
		return false
	var next_matches: Dictionary = _matches.duplicate()
	next_matches[match_id] = next_match
	var failure: String = _persist(next_matches)
	if not failure.is_empty():
		_set_error(failure)
		return false
	# Counters and the deduplication ledger commit together after the rename.
	_matches = next_matches
	_totals = next_totals
	error_message = ""
	changed.emit()
	return true


func _valid_count(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= 0 and value <= MAX_EXACT_COUNT and value == floor(float(value))


func _valid_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for id: Variant in value:
		if (not id is String and not id is StringName) or String(id).is_empty() or not _valid_count(value[id]):
			return false
	return true


func _load() -> void:
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		var failure: Error = FileAccess.get_open_error()
		if failure == ERR_FILE_NOT_FOUND and not DirAccess.dir_exists_absolute(_save_path):
			return
		_load_failed = true
		error_message = "Cannot read enemy statistics '%s': %s. Restore read access, then reopen the game; the save was not changed." % [_save_path, error_string(failure)]
		return
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		_invalid_save("read failed: %s" % error_string(read_error))
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		_invalid_save("invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	if not json.data is Dictionary:
		_invalid_save("the root must be an object")
		return
	var data: Dictionary = json.data
	if data.size() != 2 or data.get("version") != SAVE_VERSION or not data.get("matches") is Dictionary:
		_invalid_save("expected version %d and a matches object" % SAVE_VERSION)
		return
	var loaded: Dictionary = {}
	var totals: Dictionary = {}
	for match_id: Variant in data["matches"]:
		var entry: Variant = data["matches"][match_id]
		if not match_id is String or match_id.is_empty() or not entry is Dictionary:
			_invalid_save("every match must have an ID and an object")
			return
		if entry.size() != 3 or not _valid_count(entry.get("slot")) or int(entry["slot"]) > 1 or not _valid_counts(entry.get("kills")) or not _valid_counts(entry.get("sent")):
			_invalid_save("match '%s' has invalid ownership or counters" % match_id)
			return
		var normalized: Dictionary = {"slot": int(entry["slot"]), "kills": {}, "sent": {}}
		for counter: String in ["kills", "sent"]:
			for id: String in entry[counter]:
				var value: int = int(entry[counter][id])
				var total: Dictionary = totals.get(id, {"kills": 0, "sent": 0})
				if int(total[counter]) > MAX_EXACT_COUNT - value:
					_invalid_save("lifetime count for '%s' is too large" % id)
					return
				total[counter] = int(total[counter]) + value
				totals[id] = total
				normalized[counter][id] = value
		loaded[match_id] = normalized
	_matches = loaded
	_totals = totals


func _invalid_save(reason: String) -> void:
	_load_failed = true
	error_message = "Enemy statistics save '%s' is invalid: %s. Repair this file or move it aside, then reopen the game; it was not reset or changed." % [_save_path, reason]


func _set_error(message: String) -> void:
	if error_message == message:
		return
	error_message = message
	changed.emit()


func _persist(matches: Dictionary) -> String:
	var temporary_path: String = _save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return "Cannot write enemy statistics temporary save '%s': %s. Check the folder and write permissions. Counts and the previous save are unchanged; later accepted snapshots retry." % [temporary_path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "matches": matches}))
	file.flush()
	var failure: Error = file.get_error()
	file.close()
	if failure != OK:
		DirAccess.remove_absolute(temporary_path)
		return "Cannot finish enemy statistics '%s': %s. Check disk space and permissions. Counts and the previous save are unchanged; later accepted snapshots retry." % [_save_path, error_string(failure)]
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(_save_path))
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return "Cannot replace enemy statistics '%s': %s. Check the destination and folder permissions. Counts and the previous save are unchanged; later accepted snapshots retry." % [_save_path, error_string(rename_error)]
	return ""
