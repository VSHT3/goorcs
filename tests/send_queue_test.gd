extends SceneTree
## Send queue: at most twenty orders wait off-screen per target board (a group
## counts once), refusals cost nothing, delivered orders free their slots, and
## heavier orcs leave a slightly longer gap before the next order.

var failures: int = 0


func _init() -> void:
	_test_queue_limit()
	_test_weight_gap()
	if failures == 0:
		print("PASS: twenty-order send queue per board, groups count once, free refusals and slots, and weight-scaled order gaps")
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.catalog.enemies = [
		preload("res://resources/combat/enemies/grunt.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/brute.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/orcling.tres").duplicate() as EnemyDefinition,
		preload("res://resources/combat/enemies/orc_chief.tres").duplicate() as EnemyDefinition,
	]
	for enemy: EnemyDefinition in rules.catalog.enemies:
		enemy.send_first_wave = 1
	rules.base_health = 1000
	rules.starting_coins = 100000
	rules.enemy_health = 8
	rules.enemy_speed = 1.0
	rules.wave_weight = 1
	rules.wave_weight_growth = 0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.5
	rules.spawn_jitter_ratio = 0.0
	rules.spawn_interval_reduction_per_wave = 0.0
	return rules


func _routing() -> Array[Dictionary]:
	var route: Array[Vector2i] = []
	var next: Dictionary = {}
	for x: int in range(101):
		route.append(Vector2i(x, 0))
		next[Vector2i(x, 0)] = [Vector2i(x + 1, 0)] if x < 100 else []
	return [{"route": route, "next": next}, {"route": route, "next": next}]


func _test_queue_limit() -> void:
	var combat := MatchCombat.new(_rules())
	for order: int in range(MatchCombat.SEND_QUEUE_LIMIT - 1):
		_check(combat.send_enemy(0, &"grunt"), "Order %d queues" % (order + 1))
	var orclings_before: int = combat.queued_sends[1]
	_check(combat.send_enemy(0, &"orcling"), "A grouped order fills the twentieth slot")
	_check(combat.queued_sends[1] - orclings_before >= 1 and combat.queued_send_orders[1] == MatchCombat.SEND_QUEUE_LIMIT, "A group counts as one order: %d orders" % combat.queued_send_orders[1])
	var coins: int = combat.coins[0]
	var income: int = combat.income[0]
	_check(not combat.send_enemy(0, &"grunt") and combat.coins[0] == coins and combat.income[0] == income, "A full queue refuses the order without charging Coins or income")
	_check(combat.send_enemy(1, &"grunt"), "Each target board has its own queue")
	_check(combat.snapshot()["queued_send_orders"] == [1, MatchCombat.SEND_QUEUE_LIMIT] and combat.snapshot()["rules"]["send_queue_limit"] == MatchCombat.SEND_QUEUE_LIMIT, "Snapshots publish order counts and the limit")
	_check(combat.start_wave(_routing()), "The wave starts")
	for step: int in range(40):
		combat.advance(0.1)
	_check(combat.queued_send_orders[1] < MatchCombat.SEND_QUEUE_LIMIT and combat.send_enemy(0, &"grunt"), "Delivered orders free their queue slots")


func _test_weight_gap() -> void:
	var combat := MatchCombat.new(_rules())
	_check(combat.start_wave(_routing()), "The gap fixture starts a wave")
	var base: float = combat._active_send_spawn_interval
	for type_id: StringName in [&"grunt", &"brute", &"orc_chief"]:
		var weight: int = combat._enemy_types[String(type_id)]["spawn_weight"]
		var before: float = maxf(combat._next_send_times[1], combat._elapsed)
		_check(combat.send_enemy(0, type_id), "%s is sent" % type_id)
		var gap: float = combat._next_send_times[1] - before
		_check(is_equal_approx(gap, MatchCombat.send_order_gap(base, weight)), "%s (weight %d) waits %.3f s after its order: %.3f" % [type_id, weight, MatchCombat.send_order_gap(base, weight), gap])
		combat._elapsed = combat._next_send_times[1]
	_check(is_equal_approx(MatchCombat.send_order_gap(1.0, 1), 1.0) and is_equal_approx(MatchCombat.send_order_gap(1.0, 5), 1.0) and is_equal_approx(MatchCombat.send_order_gap(1.0, 10), 1.25) and is_equal_approx(MatchCombat.send_order_gap(1.0, 160), 8.75), "Order gaps grow 5% per weight point above five: Grunt and Brute 1x, HeavyDutyOrc 1.25x, Dreadmaw 8.75x")
