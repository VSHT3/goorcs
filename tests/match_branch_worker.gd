extends "res://tests/match_planning_worker.gd"


class ManualPlanning extends MatchPlanning:
	func _physics_process(_delta: float) -> void:
		pass

	func step(delta: float) -> void:
		super._physics_process(delta)


func _new_session() -> void:
	_session = MultiplayerSession.new()
	_session.name = "Session"
	_session.changed.connect(_publish)
	_main.add_child(_session)
	planning = ManualPlanning.new()
	planning.name = "Planning"
	planning.session = _session
	planning.combat_rules = _planning_rules()
	if _lane == "host":
		planning.configure(Vector2i(6, 5), 30, Vector2i(0, 2), Vector2i(5, 2))
	_main.add_child(planning)


func _planning_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_health = 100 if _lane == "host" else 1
	rules.starting_coins = 1000
	rules.wave_weight = 4
	rules.wave_weight_growth = 0
	rules.enemy_speed = 1.0 if _lane == "host" else 99.0
	rules.speed_growth = 0.0
	rules.spawn_interval = 0.0
	return rules


func _execute_command(command: Dictionary) -> void:
	if String(command.get("action", "")) == "step":
		if _session.is_host:
			(planning as ManualPlanning).step(float(command["delta"]))
			planning._publish_snapshot()
	else:
		super._execute_command(command)
