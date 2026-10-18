extends "res://tests/match_branch_worker.gd"

func _execute_command(command: Dictionary) -> void:
	if String(command.get("action", "")) == "finish_recap":
		if _session.is_host:
			var model: MatchCombat = planning._host_combat
			model.base_health[0] = 1
			model._spawn_enemy(0, "grunt", float(model._routes[0].size() - 1), model._elapsed)
			(planning as ManualPlanning).step(0.001)
			planning._publish_snapshot()
	else:
		super._execute_command(command)
