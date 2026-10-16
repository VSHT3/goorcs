extends "res://tests/match_planning_worker.gd"

var _publications: int = 0
var _previous_wave: int = 0
var _wave_rosters: Dictionary = {}


func _new_session() -> void:
	super._new_session()
	planning.changed.connect(_record_snapshot)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 100
	rules.wave_weight = 12
	rules.wave_weight_growth = 0
	rules.enemy_health = 1000
	rules.health_growth = 0
	rules.enemy_speed = 13.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.02
	rules.send_spawn_interval = 0.6
	var definitions: Array[EnemyDefinition] = []
	for source: EnemyDefinition in rules.catalog.enemies:
		if source.id not in [&"grunt", &"runner", &"brute"]:
			continue
		var definition := source.duplicate() as EnemyDefinition
		# Every roster is eligible immediately in this isolated networking scenario.
		definition.first_wave = 1
		definition.send_first_wave = 1
		definitions.append(definition)
	rules.catalog.enemies = definitions
	if _lane == "guest":
		# The client cannot substitute its own roster, budget, or movement rules.
		rules.wave_weight = 1
		rules.enemy_speed = 0.1
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"pacing":
			planning.request_pacing(String(command["option"]), bool(command["enabled"]))
		"forged_pacing":
			# Exercise the same command envelope a hostile client could send.
			planning._request_command(String(command["option"]), int(command["slot"]), Vector2i.ZERO, bool(command["enabled"]))
		"unknown_sender":
			planning._apply_command(987654321, "speed", 1, Vector2i.ZERO, true)
		"terminal_scenario":
			var rules: CombatRules = _planning_rules()
			rules.base_health = 1
			rules.wave_weight = 1
			rules.catalog.enemies = [rules.catalog.enemies[0]]
			planning.combat_rules = rules
		_:
			super._execute_command(command)


func _record_snapshot() -> void:
	_publications += 1
	var wave: int = int(planning.combat.get("wave", 0))
	if wave == 0:
		_previous_wave = 0
		_wave_rosters.clear()
		return
	if wave > _previous_wave:
		_previous_wave = wave
		_wave_rosters[str(wave)] = planning.combat.get("wave_roster", []).duplicate()


func _publish() -> void:
	super._publish()
	if planning == null or _directory.is_empty() or _executing_command:
		return
	var file := FileAccess.open(_path("pacing") + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"publications": _publications, "wave_rosters": _wave_rosters}))
	file.close()
	DirAccess.rename_absolute(_path("pacing") + ".tmp", _path("pacing"))
