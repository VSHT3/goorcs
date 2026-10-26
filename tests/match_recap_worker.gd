extends "res://tests/match_branch_worker.gd"

func _fixture_reserved_cells() -> Array[Vector2i]:
	# This recap scenario uses a straight route, not the parent's two branches.
	var reserved: Array[Vector2i] = [Vector2i(1, 0)]
	for x: int in range(6):
		reserved.append(Vector2i(x, 2))
	return reserved


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
