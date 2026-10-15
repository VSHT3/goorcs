extends SceneTree

var failures: int = 0
var _directory: String
var _paths: Array[String] = []


func _init() -> void:
	_directory = "user://enemy_statistics_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_absolute(_directory) == OK, "Create isolated statistics directory")
	_test_lifetime_and_reconnect()
	_test_snapshot_rejection()
	_test_atomic_failure_and_retry()
	_test_invalid_saves()
	_test_real_combat_events()
	_cleanup()
	if failures == 0:
		print("PASS: atomic enemy statistics, owned-slot isolation, cumulative idempotence, restart/reconnect, stale snapshots, failures, and real kill/send/leak events")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _path(name: String) -> String:
	var path: String = _directory.path_join(name)
	_paths.append(path)
	_paths.append(path + ".tmp")
	return path


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Create isolated statistics fixture")
	if file != null:
		file.store_string(text)
		file.close()


func _snapshot(id: String, kills: Dictionary = {}, sent: Dictionary = {}, peer_kills: Dictionary = {}, peer_sent: Dictionary = {}) -> Dictionary:
	return {"statistics_id": id, "rules": {"sandbox_mode": false}, "enemy_totals": [{"kills": kills, "sent": sent}, {"kills": peer_kills, "sent": peer_sent}]}


func _test_lifetime_and_reconnect() -> void:
	var path: String = _path("lifetime.json")
	var store := EnemyStatisticsStore.new(path)
	var notifications: Array[bool] = []
	store.changed.connect(func() -> void: notifications.append(true))
	_check(store.error_message.is_empty() and store.counts(&"grunt") == {"kills": 0, "sent": 0}, "A missing save starts empty without an error")
	_check(not FileAccess.file_exists(path), "Reading empty counters does not create a save")
	var first: Dictionary = _snapshot("match_a", {"grunt": 3, "skeleorc": 2}, {"orcling": 4}, {"grunt": 900}, {"orcling": 900})
	var before: Dictionary = first.duplicate(true)
	_check(store.observe(first, 0), "First accepted own-slot totals are saved")
	_check(first == before, "Observation never mutates the accepted host snapshot")
	_check(store.counts(&"grunt")["kills"] == 3 and store.counts(&"skeleorc")["kills"] == 2 and store.counts(&"orcling")["sent"] == 4, "Individual sends and summoned-only kills use the owned slot")
	_check(not store.observe(first, 0) and notifications.size() == 1, "Repeated cumulative snapshots neither count nor emit again")
	_check(not store.observe(first, 1), "A mirrored peer slot cannot grant a second copy of the same match")
	_check(not store.observe(_snapshot("match_a", {"grunt": 1}, {"orcling": 1}), 0), "Decreasing and missing counters do not lower high-water marks")
	_check(store.observe(_snapshot("match_a", {"grunt": 5}, {"orcling": 7}), 0), "Later increases only add deltas beyond each high-water mark")
	_check(store.counts(&"grunt")["kills"] == 5 and store.counts(&"skeleorc")["kills"] == 2 and store.counts(&"orcling")["sent"] == 7, "A decreased/partial snapshot cannot erase another type")
	var reloaded := EnemyStatisticsStore.new(path)
	_check(reloaded.error_message.is_empty() and reloaded.counts(&"grunt")["kills"] == 5, "Counters survive reconstructing the store")
	_check(not reloaded.observe(first, 0) and not reloaded.observe(first, 1), "Persisted deduplication and ownership survive restart/reconnect")
	_check(reloaded.observe(_snapshot("match_b", {}, {}, {"runner": 4}, {"brute": 2}), 1), "A different match can belong to the other slot")
	_check(reloaded.counts(&"runner")["kills"] == 4 and reloaded.counts(&"brute")["sent"] == 2, "Guest ownership reads only the selected slot")
	_check(not reloaded.observe(first, 0), "A stale snapshot from an older match never recounts after a newer match")
	_check(reloaded.observe(_snapshot("match_a", {"grunt": 6}, {"orcling": 8}), 0), "A late accepted delta from an older match still has its independent watermark")
	var detached: Dictionary = reloaded.counts(&"grunt")
	detached["kills"] = 1000
	_check(reloaded.counts(&"grunt")["kills"] == 6, "Returned counter dictionaries cannot mutate saved state")
	_write(path + ".tmp", JSON.stringify({"version": 1, "matches": {"uncommitted": {"slot": 0, "kills": {"grunt": 999}, "sent": {}}}}))
	var restarted := EnemyStatisticsStore.new(path)
	_check(restarted.counts(&"grunt")["kills"] == 6 and restarted.counts(&"runner")["kills"] == 4, "An interrupted unrenamed temporary file never grants counters")


func _test_snapshot_rejection() -> void:
	var path: String = _path("ignored.json")
	var store := EnemyStatisticsStore.new(path)
	var sandbox: Dictionary = _snapshot("sandbox", {"grunt": 10}, {"grunt": 10})
	sandbox["rules"]["sandbox_mode"] = true
	_check(not store.observe(sandbox, 0), "Sandbox totals never create a ledger or grant counters")
	_check(not store.observe({}, 0) and not store.observe(_snapshot(""), 0), "Incomplete snapshots and missing match identities are ignored")
	_check(not store.observe(_snapshot("valid"), -1) and not store.observe(_snapshot("valid"), 2), "Invalid ownership never chooses a board")
	var invalid: Array[Dictionary] = [
		_snapshot("bad", {"grunt": -1}), _snapshot("bad", {"grunt": 1.5}),
		_snapshot("bad", {"grunt": true}), _snapshot("bad", {"": 1}),
		_snapshot("bad", {}, {"grunt": "3"}),
	]
	for snapshot: Dictionary in invalid:
		_check(not store.observe(snapshot, 0), "Malformed cumulative counters are rejected as a whole")
	_check(store.counts(&"grunt") == {"kills": 0, "sent": 0} and not FileAccess.file_exists(path), "Ignored/rejected snapshots leave lifetime persistence untouched")
	_check(store.observe(_snapshot("valid"), 0), "An accepted empty match can durably bind ownership")
	_check(not store.observe(_snapshot("valid", {}, {}, {"grunt": 10}), 1), "An initial zero snapshot also prevents mirrored ownership changes")


func _test_atomic_failure_and_retry() -> void:
	var path: String = _path("atomic.json")
	var store := EnemyStatisticsStore.new(path)
	_check(store.observe(_snapshot("atomic", {"grunt": 2}, {"orcling": 3}), 0), "Persist initial counters before a forced failure")
	var original: String = FileAccess.get_file_as_string(path)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Block the temporary save without touching its committed file")
	var errors: Array[bool] = []
	store.changed.connect(func() -> void: errors.append(true))
	var next: Dictionary = _snapshot("atomic", {"grunt": 5}, {"orcling": 7})
	_check(not store.observe(next, 0) and not store.error_message.is_empty(), "A failed atomic save exposes an actionable error")
	_check(store.error_message.contains(path) and errors.size() == 1, "The visible failure signal includes the actual save path")
	_check(store.counts(&"grunt")["kills"] == 2 and store.counts(&"orcling")["sent"] == 3, "A failed save does not commit counts or consume the watermark")
	_check(FileAccess.get_file_as_string(path) == original, "A failed save preserves every byte of the prior save")
	_check(not store.observe(_snapshot("atomic", {"grunt": 1}), 0) and not store.error_message.is_empty(), "Unchanged/decreasing snapshots cannot dismiss an unsaved error")
	_check(DirAccess.remove_absolute(path + ".tmp") == OK, "Restore the temporary-save destination")
	_check(store.observe(next, 0) and store.error_message.is_empty(), "The next accepted cumulative snapshot retries the complete unsaved delta")
	_check(store.counts(&"grunt")["kills"] == 5 and store.counts(&"orcling")["sent"] == 7 and not FileAccess.file_exists(path + ".tmp"), "Successful retry commits counters once and leaves no temporary save")
	var reloaded := EnemyStatisticsStore.new(path)
	_check(not reloaded.observe(next, 0) and reloaded.counts(&"grunt")["kills"] == 5, "Retry watermarks persist atomically with counters")
	var absent: String = _path("missing_folder/statistics.json")
	var missing := EnemyStatisticsStore.new(absent)
	_check(not missing.observe(_snapshot("missing", {"grunt": 1}), 0) and not missing.error_message.is_empty(), "An unavailable save folder cannot silently claim a saved count")
	var replaced_path: String = _path("replace.json")
	var replacement := EnemyStatisticsStore.new(replaced_path)
	_check(replacement.observe(_snapshot("replace", {"grunt": 1}), 0), "Persist counters before a destination replacement failure")
	var preserved_path: String = _path("preserved.json")
	_check(DirAccess.rename_absolute(replaced_path, preserved_path) == OK and DirAccess.make_dir_absolute(replaced_path) == OK, "Preserve the original bytes and block the final rename with a directory")
	var preserved: String = FileAccess.get_file_as_string(preserved_path)
	_check(not replacement.observe(_snapshot("replace", {"grunt": 2}), 0) and replacement.error_message.contains(replaced_path), "A failed final atomic rename reports its destination")
	_check(replacement.counts(&"grunt")["kills"] == 1 and FileAccess.get_file_as_string(preserved_path) == preserved and DirAccess.dir_exists_absolute(replaced_path), "Rename failure cannot consume a watermark or destroy existing destination data")


func _test_invalid_saves() -> void:
	var fixtures: Array[String] = [
		"broken json", "[]", '{"version":2,"matches":{}}',
		'{"version":1,"matches":[]}', '{"version":1,"matches":{},"extra":1}',
		'{"version":1,"matches":{"x":{"slot":2,"kills":{},"sent":{}}}}',
		'{"version":1,"matches":{"x":{"slot":0,"kills":{"grunt":-1},"sent":{}}}}',
		'{"version":1,"matches":{"x":{"slot":0,"kills":{"grunt":1.5},"sent":{}}}}',
		'{"version":1,"matches":{"x":{"slot":0,"kills":{},"sent":{"grunt":true}}}}',
		'{"version":1,"matches":{"x":{"slot":0,"kills":{}}}}',
		'{"version":1,"matches":{"good":{"slot":0,"kills":{"grunt":3},"sent":{}},"bad":null}}',
	]
	for index: int in range(fixtures.size()):
		var path: String = _path("invalid_%d.json" % index)
		_write(path, fixtures[index])
		var store := EnemyStatisticsStore.new(path)
		_check(not store.error_message.is_empty() and store.error_message.contains(path), "Invalid save reports an actionable, persistent error")
		_check(not store.observe(_snapshot("later", {"grunt": 5}), 0), "A corrupt save cannot be overwritten by a later accepted match")
		_check(store.counts(&"grunt")["kills"] == 0 and FileAccess.get_file_as_string(path) == fixtures[index], "Invalid saves never partially load, reset, or replace data")
	var unreadable: String = _path("directory.json")
	_check(DirAccess.make_dir_absolute(unreadable) == OK, "Create unreadable save destination")
	var blocked := EnemyStatisticsStore.new(unreadable)
	_check(not blocked.error_message.is_empty() and not blocked.observe(_snapshot("later"), 0), "An unreadable existing save is not mistaken for a new player")
	_check(DirAccess.dir_exists_absolute(unreadable), "An unreadable save destination remains untouched")


func _test_real_combat_events() -> void:
	var rules := CombatRules.new()
	var enemy := EnemyDefinition.new()
	enemy.id = &"statistics_fixture"
	enemy.title = "Statistics fixture"
	var reward := TowerReward.new()
	reward.id = &"statistics_tower"
	reward.title = "Statistics tower"
	var tower := TowerDefinition.new()
	tower.reward = reward
	tower.damage = 20
	tower.interval = 0.1
	tower.range_cells = 20.0
	rules.catalog = ContentCatalog.new()
	rules.catalog.enemies = [enemy]
	rules.catalog.towers = [tower]
	rules.enemy_health = 1
	rules.enemy_speed = 1.0
	rules.wave_weight = 1
	rules.base_health = 100
	rules.starting_coins = 1000
	var combat := MatchCombat.new(rules)
	var store := EnemyStatisticsStore.new(_path("real_combat.json"))
	_check(combat.build(0, Vector2i(0, 1), reward.id, MatchCombat.TargetMode.FURTHEST), "Build a real owned defense for statistics")
	_check(not combat.send_enemy(0, &"missing_type"), "An unknown paid send is actually rejected")
	_check(combat.send_enemy(0, enemy.id) and combat.send_enemy(1, enemy.id), "Both sides actually purchase one individual send")
	_check(store.observe(combat.snapshot(), 0) and store.counts(enemy.id)["sent"] == 1, "Accepted host totals count only the local purchase, not the mirrored peer")
	combat.coins[0] = 0
	_check(not combat.send_enemy(0, enemy.id), "An unfunded send is actually rejected")
	_check(not store.observe(combat.snapshot(), 0) and store.counts(enemy.id)["sent"] == 1, "A rejected send does not change saved totals")
	var routing: Array[Dictionary] = [{"route": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)], "next": {Vector2i.ZERO: [Vector2i.RIGHT], Vector2i.RIGHT: [Vector2i(2, 0)], Vector2i(2, 0): []}}]
	routing.append(routing[0].duplicate(true))
	_check(combat.start_wave(routing), "Start a real regular plus sent wave")
	for tick: int in range(600):
		if combat.phase != MatchCombat.Phase.WAVE:
			break
		combat.advance(1.0 / 60.0)
	_check(combat.phase == MatchCombat.Phase.PLANNING and combat.base_health[1] == 98, "The undefended peer really leaks two units while the owned defense kills two")
	_check(store.observe(combat.snapshot(), 0) and store.counts(enemy.id) == {"kills": 2, "sent": 1}, "Only actual deaths and accepted sends become lifetime counters")
	var leak_store := EnemyStatisticsStore.new(_path("leaks.json"))
	_check(leak_store.observe(combat.snapshot(), 1) and leak_store.counts(enemy.id) == {"kills": 0, "sent": 1}, "Actual leaks are not kills on the losing/undefended slot")
	rules.sandbox_mode = true
	var sandbox := MatchCombat.new(rules)
	_check(sandbox.send_enemy(0, enemy.id), "Sandbox can exercise the same accepted send path")
	_check(not store.observe(sandbox.snapshot(), 0) and store.counts(enemy.id) == {"kills": 2, "sent": 1}, "The real sandbox snapshot is excluded regardless of accepted actions")


func _cleanup() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			_check(DirAccess.remove_absolute(path) == OK, "Remove isolated statistics fixture")
	_check(DirAccess.remove_absolute(_directory) == OK, "Remove isolated statistics directory")
