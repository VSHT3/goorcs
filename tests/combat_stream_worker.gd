extends "res://tests/match_planning_worker.gd"

const CODEC = preload("res://scripts/combat_snapshot_codec.gd")
var _streaming: bool = false


func _planning_rules() -> CombatRules:
	var rules: CombatRules = preload("res://resources/combat/prototype.tres").duplicate(true)
	rules.roll_rules = null
	rules.base_health = 10000
	rules.starting_coins = 100000
	rules.enemy_health = 10000
	rules.health_growth = 0
	rules.enemy_speed = 0.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	return rules


func _execute_command(command: Dictionary) -> void:
	match String(command.get("action", "")):
		"pause_poll":
			multiplayer_poll = false
		"resume_poll":
			multiplayer_poll = true
		"stream_fixture":
			_streaming = true
			for layout: PathLayout in planning._host_layouts:
				for x: int in range(1, 13):
					layout.place(Vector2i(x, 4))
			var routes: Array[Dictionary] = [planning._host_layouts[0].capture_routing(), planning._host_layouts[1].capture_routing()]
			_last_result = planning._host_combat.start_wave(routes)
			planning._host_locked = true
			for slot: int in range(2):
				planning._host_routes[slot] = planning._host_layouts[slot].route.duplicate()
				var route: Array[Vector2i] = []
				route.assign(planning._host_routes[slot])
				for index: int in range(120):
					planning._host_combat._spawn_enemy(slot, "grunt", fmod(index * 0.07, 10.0), 0.0, route)
				for index: int in range(12):
					planning._host_combat.build(slot, Vector2i(index, 2), &"arrow_tower", 0)
			planning._publish_snapshot()
			planning.set_physics_process(false)
			_streaming = false
		"stream_burst":
			_streaming = true
			var old: PackedByteArray = CODEC.encode_combat(planning._combat_snapshot(false))
			var old_sequence: int = planning._snapshot_sequence
			for index: int in range(24):
				planning._host_combat.advance(0.02)
				planning._publish_combat()
			# Deliberate application-level reorder after a real frame burst.
			planning._send_combat_packet(planning._synced_guest_id, old, planning._snapshot_revision, old_sequence)
			_streaming = false
		"stream_transaction":
			_streaming = true
			var old: PackedByteArray = CODEC.encode_combat(planning._combat_snapshot(false))
			var revision: int = planning._snapshot_revision
			planning.build_tower(0, Vector2i(12, 8), &"arrow_tower", 0)
			planning._send_combat_packet(planning._synced_guest_id, old, revision, planning._snapshot_sequence + 1)
			_streaming = false
		"stream_end":
			var old: PackedByteArray = CODEC.encode_combat(planning._combat_snapshot(false))
			var revision: int = planning._snapshot_revision
			planning._host_combat.phase = MatchCombat.Phase.FINISHED
			planning._host_combat.winner = 0
			planning._publish_snapshot()
			planning._send_combat_packet(planning._synced_guest_id, old, revision, planning._snapshot_sequence + 1)
		_:
			super._execute_command(command)


func _publish() -> void:
	if not _streaming:
		super._publish()
