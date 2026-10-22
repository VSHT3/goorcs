extends SceneTree

const SHIPPED: BossRewardRules = preload("res://resources/combat/boss_rewards.tres")
const BOSSES: Array[String] = ["necorcmancer_mancer", "troll", "orc_war_machine"]
const BOSS: Dictionary = {"boss": true, "title": "Fixture boss"}
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ledger_boundaries()
	_test_capture_and_history()
	_test_invalid_rules()
	_test_weights_and_scaling()
	_test_host_kills()
	_test_paid_boss_kills()
	_test_unowned_deaths()
	if failures == 0:
		print("PASS: boss rewards capture authored odds/payouts, isolate randomness, retain detached once-per-type histories, and credit only real host-owned kills")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func _rng(seed_value: int = 731) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = seed_value
	return result


func _owned_rules() -> BossRewardRules:
	var result := SHIPPED.duplicate() as BossRewardRules
	result.rarity_rules = SHIPPED.rarity_rules.duplicate() as TowerRollRules
	result.rarity_rules.rarities = SHIPPED.rarity_rules.rarities.duplicate(true)
	result.payouts = SHIPPED.payouts.duplicate(true)
	return result


func _test_ledger_boundaries() -> void:
	var random := _rng()
	var ledger := BossRewardLedger.new(SHIPPED, random)
	_check(ledger.error_message.is_empty(), "Shipped reward resource admits")
	var initial: int = random.state
	for args: Array in [[-1, "boss", BOSS, 40, 0.0], [2, "boss", BOSS, 40, 0.0], [0, "", BOSS, 40, 0.0], [0, "boss", {}, 40, 0.0], [0, "boss", {"boss": false, "title": "Regular"}, 40, 0.0], [0, "boss", {"boss": 1, "title": "Invalid"}, 40, 0.0], [0, "boss", BOSS, 0, 0.0], [0, "boss", BOSS, 40, -1.0], [0, "boss", BOSS, 40, NAN], [0, "boss", BOSS, 40, INF], [0, "boss", BOSS, 9223372036854775807, 0.0]]:
		_check(ledger.claim(args[0], args[1], args[2], args[3], args[4]).is_empty(), "Invalid claim rejects before RNG or once-only admission")
	_check(random.state == initial and ledger.awards(0).is_empty(), "Invalid claims consume neither random draws nor history")
	var award: Dictionary = ledger.claim(0, "boss", BOSS, 40, 0.0)
	var expected := _rng()
	expected.randf()
	_check(not award.is_empty() and random.state == expected.state, "Accepted claim consumes exactly one injected rarity draw")
	_check(ledger.claim(0, "boss", BOSS, 100, 50.0).is_empty() and random.state == expected.state, "Repeated type never rerolls, including after a round jump")
	_check(not ledger.claim(1, "boss", BOSS, 40, 0.0).is_empty(), "Same boss independently rewards other player")
	_check(not ledger.claim(0, "other", BOSS, 40, 0.0).is_empty(), "Different boss has independent first-kill claim")
	_check(ledger.awards(-1).is_empty() and ledger.awards(2).is_empty(), "Invalid history slots are harmless")
	initial = random.state
	for disabled: BossRewardLedger in [BossRewardLedger.new(null, random), BossRewardLedger.new(SHIPPED, random, false)]:
		_check(disabled.claim(0, "boss", BOSS, 40, 0.0).is_empty(), "Null rules and disabled mode cannot grant")
	_check(random.state == initial, "Disabled claims consume no randomness")
	_check(not BossRewardLedger.new(SHIPPED, _rng()).claim(0, "boss", BOSS, 40, 0.0).is_empty(), "New run restores claims")


func _test_capture_and_history() -> void:
	var rules := _owned_rules()
	var ledger := BossRewardLedger.new(rules, _rng())
	var untouched := BossRewardLedger.new(SHIPPED, _rng())
	rules.payouts["mythic"] = Vector2i(1, 1)
	rules.rarity_rules.rarities[0]["weight"] = 900000.0
	rules.rarity_rules.rarities[0]["title"] = "Changed"
	rules.rarity_rules.rarities.clear()
	var award: Dictionary = ledger.claim(0, "boss", BOSS, 61, 3.5)
	_check(award == untouched.claim(0, "boss", BOSS, 61, 3.5), "Admitted match captures nested rarity data and payouts independently")
	var accepted: Dictionary = award.duplicate(true)
	award["coins"] = -1
	award["tiers"][0]["title"] = "Corrupt"
	var history: Array[Dictionary] = ledger.awards(0)
	_check(history.size() == 1 and history[0] == accepted, "Mutating returned claim cannot mutate accepted award")
	history[0]["tiers"].clear()
	history.clear()
	_check(ledger.awards(0)[0] == accepted, "Mutating snapshot history cannot erase durable awards or nested tiers")
	ledger.claim(0, "second", BOSS, 80, 5.0)
	_check(ledger.awards(0).size() == 2 and ledger.awards(0)[1]["id"] > accepted["id"], "Unobserved awards persist with monotonic identities")


func _test_invalid_rules() -> void:
	var invalids: Array[BossRewardRules] = []
	var rules := _owned_rules()
	rules.rarity_rules = null
	invalids.append(rules)
	for value: Variant in [0.0, -1.0, NAN, INF, "bad"]:
		rules = _owned_rules()
		rules.rarity_rules.rarities[0]["weight"] = value
		invalids.append(rules)
	rules = _owned_rules()
	rules.rarity_rules.rarities[1]["id"] = "broken"
	invalids.append(rules)
	rules = _owned_rules()
	rules.rarity_rules.rarities.pop_back()
	invalids.append(rules)
	for value: Variant in [Vector2i(0, 1), Vector2i(49, 2), Vector2(80, 2), null]:
		rules = _owned_rules()
		rules.payouts["shoddy"] = value
		invalids.append(rules)
	for invalid: BossRewardRules in invalids:
		var random := _rng()
		var state: int = random.state
		var ledger := BossRewardLedger.new(invalid, random)
		_check(not ledger.error_message.is_empty() and ledger.claim(0, "boss", BOSS, 40, 0.0).is_empty() and random.state == state, "Invalid authored rewards report an admission error without fallback or RNG")
	_check(not BossRewardLedger.new(SHIPPED).error_message.is_empty(), "Enabled rewards reject missing authoritative RNG")


func _test_weights_and_scaling() -> void:
	var ledger := BossRewardLedger.new(SHIPPED, _rng(99))
	var counts: Dictionary = {}
	var previous: String = ""
	var repeated: bool = false
	for index: int in range(10000):
		var award: Dictionary = ledger.claim(0, str(index), BOSS, 41, float(index))
		var rarity: String = award["rarity"]
		counts[rarity] = int(counts.get(rarity, 0)) + 1
		repeated = repeated or rarity == previous
		previous = rarity
	# Bosses drop Rare or better: only those tiers roll, at their authored weights.
	var floor_index: int = TowerRollRules.RARITIES.find(SHIPPED.minimum_rarity)
	var eligible_weight: float = 0.0
	for tier: Dictionary in SHIPPED.rarity_rules.rarities:
		if TowerRollRules.RARITIES.find(tier["id"]) >= floor_index:
			eligible_weight += float(tier["weight"])
	_check(SHIPPED.minimum_rarity == "rare" and repeated and counts.size() == 4, "Rare, Epic, Legendary and Mythic remain possible and consecutive rarity results are not excluded")
	for tier: Dictionary in SHIPPED.rarity_rules.rarities:
		var observed: float = float(counts.get(tier["id"], 0)) / 10000.0
		var expected: float = float(tier["weight"]) / eligible_weight if TowerRollRules.RARITIES.find(tier["id"]) >= floor_index else 0.0
		_check(absf(observed - expected) < 0.025, "Observed independent draws follow referenced authored weight above the Rare floor: " + str(tier["id"]))
	for round_number: int in [1, 39, 40, 41, 60, 61, 80, 100]:
		var award: Dictionary = ledger.claim(1, str(round_number), BOSS, round_number, 0.0)
		var previous_coins: int = 0
		var previous_shards: int = 0
		for tier: Dictionary in award["tiers"]:
			var payout: Vector2i = SHIPPED.payouts[tier["id"]]
			_check(tier["coins"] == ceili(payout.x * maxf(1.0, round_number / 40.0)) and tier["shards"] == ceili(payout.y * maxf(1.0, round_number / 40.0)), "Both currencies scale at kill round with one upward rounding")
			_check(tier["coins"] > previous_coins and tier["shards"] > previous_shards, "Every scaled tier pays more of both currencies")
			previous_coins = tier["coins"]
			previous_shards = tier["shards"]
			if tier["id"] == award["rarity"]:
				_check(award["coins"] == tier["coins"] and award["shards"] == tier["shards"], "Accepted totals match the displayed winning tier")


func _host(sandbox: bool = false) -> MatchCombat:
	var rules := CombatRules.new()
	rules.boss_reward_rules = SHIPPED
	rules.sandbox_mode = sandbox
	rules.starting_coins = 100000
	rules.base_health = 100000
	rules.enemy_speed = 0.0
	rules.speed_growth_fraction = 0.0
	rules.spawn_interval = 0.0
	rules.spawn_jitter_ratio = 0.0
	var combat := MatchCombat.new(rules, _rng(1), _rng(2), _rng(3), _rng(4), _rng(5))
	var routing: Array[Dictionary] = _routing()
	_check(combat.build(0, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Reward fixture builds real owned killer")
	_check(combat.build(1, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Reward fixture builds opponent killer")
	_check(combat.sandbox_start(routing, 40, ["grunt"]) if sandbox else (combat.debug_set_round(40) and combat.start_wave(routing)), "Reward fixture admits actual host combat")
	return combat


func _routing() -> Array[Dictionary]:
	var layout := PathLayout.new(Vector2i(14, 5), 30, Vector2i(0, 2), Vector2i(13, 2))
	for x: int in range(1, 13):
		layout.place(Vector2i(x, 2))
	return [layout.capture_routing(), layout.capture_routing()]


func _kill(combat: MatchCombat, slot: int, type_id: String) -> void:
	combat._spawn_enemy(slot, type_id, 0.0, 0.0)
	combat._hit(slot, combat.towers[slot][0], combat.enemies[slot].size() - 1, 100000000)


func _test_host_kills() -> void:
	var combat := _host()
	var other_streams: Array[int] = [combat._wave_random.state, combat._timing_random.state, combat._group_random.state, combat._roll_random.state]
	for slot: int in range(2):
		for type_id: String in BOSSES:
			var before_coins: int = combat.coins[slot]
			var before_shards: int = combat.reroll_currency[slot]
			_kill(combat, slot, type_id)
			var rewards: Array = combat.snapshot()["boss_rewards"][slot]
			_check(rewards.size() == BOSSES.find(type_id) + 1, "Actual confirmed boss kill grants one independent type/slot award")
			if rewards.is_empty():
				continue
			var award: Dictionary = rewards.back()
			var definition: Dictionary = combat.snapshot()["enemy_types"][type_id]
			var bounty: int = int(definition["kill_bounty"])
			_check(combat.coins[slot] - before_coins == int(award["coins"]) + bounty, "Host credits reward Coins synchronously in addition to ordinary bounty")
			var shard_delta: int = combat.reroll_currency[slot] - before_shards - int(award["shards"])
			_check(shard_delta == 0 or shard_delta == int(definition["reroll_drop_amount"]), "Host credits accepted Shards synchronously, with only the separate ordinary drop added")
			_kill(combat, slot, type_id)
			_check(combat.snapshot()["boss_rewards"][slot].size() == rewards.size(), "Repeated real kills do not duplicate bonus")
	_check(other_streams == [combat._wave_random.state, combat._timing_random.state, combat._group_random.state, combat._roll_random.state], "Boss reward rolls never perturb wave, timing, group or tower-roll RNG")
	var detached: Dictionary = combat.snapshot()
	detached["boss_rewards"][0][0]["tiers"].clear()
	_check(combat.snapshot()["boss_rewards"][0][0]["tiers"].size() == 4, "Host snapshots deeply detach reward history")
	_check(combat.debug_set_round(100), "Debug jump remains available")
	_check(combat.start_wave(_routing()), "Debug jump re-admits actual routes for repeated kill")
	_kill(combat, 0, BOSSES[0])
	_check(combat.snapshot()["boss_rewards"][0].size() == 3, "Debug round jump retains once-per-run claims")
	var fresh := _host()
	_kill(fresh, 0, BOSSES[0])
	_check(fresh.snapshot()["boss_rewards"][0].size() == 1, "New host model resets boss claims")


func _test_paid_boss_kills() -> void:
	for type_id: String in BOSSES:
		var rules := CombatRules.new()
		rules.boss_reward_rules = SHIPPED
		rules.roll_rules = null
		rules.starting_coins = 200000
		rules.enemy_speed = 0.0
		rules.speed_growth_fraction = 0.0
		rules.wave_weight = 1
		rules.wave_weight_growth = 0
		rules.spawn_interval = 0.0
		rules.spawn_jitter_ratio = 0.0
		var combat := MatchCombat.new(rules, _rng(1), _rng(2))
		var terms: Dictionary = combat.snapshot()["enemy_types"][type_id]
		combat.debug_set_round(int(terms["send_first_wave"]))
		combat.income[0] = -int(terms["send_income"]) * 2
		_check(combat.build(1, Vector2i(1, 1), &"arrow_tower", MatchCombat.TargetMode.FURTHEST), "Paid-boss reward fixture admits an actual defending killer")
		_check(combat.send_enemy(0, StringName(type_id)) and combat.start_wave(_routing()), "Boss reward candidate is a legitimately purchased FIFO send")
		for kill_number: int in range(2):
			if kill_number == 1:
				_check(combat.send_enemy(0, StringName(type_id)), "A second fully paid boss can use the same ordinary FIFO")
			# Heavy boss orders leave a weight-scaled gap before the next one.
			combat.advance(MatchCombat.send_order_gap(rules.send_spawn_interval, int(terms["spawn_weight"])) + 0.001)
			var index: int = -1
			for candidate: int in range(combat.enemies[1].size()):
				if combat.enemies[1][candidate]["type_id"] == type_id:
					index = candidate
					break
			_check(index >= 0, "Actual paid boss delivers without a regular boss reservation")
			if index < 0:
				continue
			var before: int = combat.coins[1]
			combat._hit(1, combat.towers[1][0], index, 100000000)
			var rewards: Array = combat.snapshot()["boss_rewards"][1]
			_check(rewards.size() == 1 and combat.snapshot()["boss_rewards"][0].is_empty(), "First real paid-boss kill rewards defender once; repeats never reward sender or duplicate claim")
			if not rewards.is_empty():
				var bonus: int = int(rewards[0]["coins"]) if kill_number == 0 else 0
				_check(combat.coins[1] - before == int(terms["kill_bounty"]) + bonus, "Paid boss preserves ordinary bounty and existing first-kill bonus rules")


func _test_unowned_deaths() -> void:
	var sandbox := _host(true)
	_kill(sandbox, 0, BOSSES[0])
	_check(sandbox.snapshot()["boss_rewards"][0].is_empty(), "Real Sandbox boss deaths never grant run rewards")
	var combat := _host()
	# A real leak reaches the accepted route endpoint; it must not consume a claim.
	combat._spawn_enemy(0, BOSSES[0], 1000.0, 0.0)
	combat.advance(0.000001)
	_check(combat.snapshot()["boss_rewards"][0].is_empty(), "Boss leaks never award")
	_kill(combat, 0, BOSSES[0])
	_check(combat.snapshot()["boss_rewards"][0].size() == 1, "Leak does not consume the later real-kill claim")
	# Troll's actual stomp path owns collateral deaths, not a player tower.
	combat._spawn_enemy(0, "troll", 0.0, 0.0)
	var troll: Dictionary = combat.enemies[0].back()
	combat._spawn_enemy(0, "orc_war_machine", 0.0, 0.0)
	var victim: Dictionary = combat.enemies[0].back()
	victim["hp"] = 1
	troll["stepped"] = true
	troll["age"] = troll["next_stomp"]
	combat._boss_abilities(0, troll, combat._enemy_types["troll"])
	_check(combat._enemy_index(0, victim["id"]) < 0 and combat.snapshot()["boss_rewards"][0].size() == 1, "Actual collateral boss death grants no bonus")
	_kill(combat, 0, "orc_war_machine")
	_check(combat.snapshot()["boss_rewards"][0].size() == 2, "Collateral death does not consume later player-owned claim")
