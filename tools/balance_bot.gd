extends SceneTree
## Headless balance bot: two identical mixed-build players play a real match on
## the shipped rules (rolls, board growth, upgrades, evolutions), without sends.
## Each designs a zig-zag path that lengthens with every main-round expansion,
## keeps an element mix of Physical / Lightning / Magic towers, adds Gold Mines
## early and War Drums beside its attack towers, and spends the rest on the
## upgrade or tower that buys the most estimated damage per Coin. Every third
## Arrow, Ballista and Lightning tower targets Strongest to focus bosses.
##
## Usage: godot --headless --path . -s tools/balance_bot.gd -- <seeds> [first_seed] [max_round] [log] [start_round start_coins]
## Prints one line per seed: the round the match ended and both players' state.
## A start round fast-forwards: the board grows to that round and each player
## spends `start_coins` at once, approximating an economy built up to it.

const STEP: float = 0.1
const WAVE_LIMIT: float = 1500.0
const LANE_COLUMNS: Array[int] = [1, 3, 5, 7, 9, 11]
# Desired share of attack towers per element; Fire and Physical share a slot.
const ELEMENT_SHARES: Dictionary = {"physical": 0.4, "lightning": 0.3, "magic": 0.3}
const ELEMENT_TOWERS: Dictionary = {"physical": [&"arrow_tower", &"orc_ballista"], "lightning": [&"lightning"], "magic": [&"rune_obelisk"]}
const MINES_BY_ROUND: Array[Vector2i] = [Vector2i(2, 1), Vector2i(5, 2), Vector2i(10, 3)]
const ATTACK_KINDS: Array[String] = ["attack", "chain"]

var combat: MatchCombat
var dimensions := Vector2i(14, 9)
var entrance := Vector2i(0, 4)
var base := Vector2i(13, 4)
var budget: int = 30
var tiles_per_expansion: int = 6
var expansions: int = 0
var reach: int = 0
var path: Dictionary = {}
var route: Array = []
var routing: Array[Dictionary] = []
# Route cells within range of a cell, per (cell, range); reset with the path.
var _coverage_cache: Dictionary = {}
var log_file: FileAccess


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if args.size() > 0 else 1
	var first: int = int(args[1]) if args.size() > 1 else 0
	var max_round: int = int(args[2]) if args.size() > 2 else 400
	if args.size() > 3 and not args[3].is_empty():
		log_file = FileAccess.open(args[3], FileAccess.WRITE)
	var start_round: int = int(args[4]) if args.size() > 4 else 1
	var start_coins: int = int(args[5]) if args.size() > 5 else 0
	for seed_index: int in range(first, first + seeds):
		_play(seed_index, max_round, start_round, start_coins)
	quit()


func _play(seed_index: int, max_round: int, start_round: int = 1, start_coins: int = 0) -> void:
	var rules: CombatRules = (load("res://resources/combat/prototype.tres") as CombatRules).duplicate(true)
	tiles_per_expansion = rules.tiles_per_expansion
	var streams: Array[RandomNumberGenerator] = []
	for index: int in range(5):
		var stream := RandomNumberGenerator.new()
		stream.seed = 9100 * (seed_index + 1) + index
		streams.append(stream)
	combat = MatchCombat.new(rules, streams[0], streams[1], streams[2], streams[3], streams[4])
	dimensions = Vector2i(14, 9)
	entrance = Vector2i(0, 4)
	base = Vector2i(13, 4)
	budget = 30
	expansions = 0
	_design_path()
	var started: int = Time.get_ticks_msec()
	var main_interval: int = rules.main_round_interval
	if start_round > 1:
		combat.debug_set_round(start_round)
		for slot: int in range(2):
			combat.coins[slot] = start_coins
	for round_number: int in range(start_round, max_round + 1):
		while expansions < maxi(0, round_number / main_interval - 1):
			_expand()
		for slot: int in range(2):
			_spend(slot, round_number)
		if not combat.start_wave(routing):
			_log("seed %d round %d: wave did not start" % [seed_index, round_number])
			break
		var elapsed: float = 0.0
		var bosses: Dictionary = {}
		while combat.phase == MatchCombat.Phase.WAVE and elapsed < WAVE_LIMIT:
			combat.advance(STEP)
			elapsed += STEP
			_track_bosses(bosses)
		_log("seed %d round %d hp %s coins %s towers %d/%d invested %d/%d path %d wave_s %.0f wall_s %.0f%s" % [seed_index, round_number, str(combat.base_health), str(combat.coins), combat.towers[0].size(), combat.towers[1].size(), _invested(0), _invested(1), route.size(), elapsed, (Time.get_ticks_msec() - started) / 1000.0, _boss_report(bosses)])
		if combat.phase == MatchCombat.Phase.FINISHED or elapsed >= WAVE_LIMIT:
			break
	print("RESULT seed %d ended_round %d hp %s towers %d/%d invested %d/%d path %d wall_s %.0f" % [seed_index, combat.wave, str(combat.base_health), combat.towers[0].size(), combat.towers[1].size(), _invested(0), _invested(1), route.size(), (Time.get_ticks_msec() - started) / 1000.0])


# Each boss's lowest HP and last progress: it leaked if it was last seen at the base.
func _track_bosses(bosses: Dictionary) -> void:
	for slot: int in range(2):
		for enemy: Dictionary in combat.enemies[slot]:
			if not bool(combat._enemy_types[enemy["type_id"]]["boss"]):
				continue
			var key := Vector2i(slot, int(enemy["id"]))
			var entry: Array = bosses.get(key, [enemy["type_id"], 1.0, 0.0, float(enemy["route"].size() - 1)])
			entry[1] = minf(float(entry[1]), float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"])))
			entry[2] = float(enemy["progress"])
			bosses[key] = entry


func _boss_report(bosses: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: Vector2i in bosses:
		var entry: Array = bosses[key]
		var leaked: bool = float(entry[2]) >= float(entry[3]) - 1.0
		parts.append("%s:%d:%s@%d%%" % [entry[0], key.x, "leaked" if leaked else "killed", roundi(float(entry[1]) * 100.0)])
	return "" if parts.is_empty() else " bosses " + " ".join(parts)


func _log(line: String) -> void:
	if log_file != null:
		log_file.store_line(line)
		log_file.flush()


func _invested(slot: int) -> int:
	var total: int = 0
	for tower: Dictionary in combat.towers[slot]:
		total += int(tower["invested"])
	return total


# Main rounds grow the board by a row above and below and a column, shifting
# everything down one row, and add path budget.
func _expand() -> void:
	combat.grow_for_main_round()
	dimensions += Vector2i(1, 2)
	entrance += Vector2i.DOWN
	base += Vector2i.DOWN
	budget += tiles_per_expansion
	expansions += 1
	_design_path()


# Six vertical lanes between the entrance and base column, joined alternately
# at the top and bottom, with a free column between lanes for towers. Lanes
# reach `reach` rows above and below the entrance row: 10 * reach + 12 tiles.
func _design_path() -> void:
	var row: int = entrance.y
	reach = clampi((budget - 12) / 10, 0, mini(row, dimensions.y - 1 - row))
	path.clear()
	var top: int = row - reach
	var bottom: int = row + reach
	for index: int in range(LANE_COLUMNS.size()):
		var column: int = LANE_COLUMNS[index]
		var from: int = top if index % 2 == 1 else bottom
		var to: int = bottom if index % 2 == 1 else top
		if index == 0:
			from = row
		if index == LANE_COLUMNS.size() - 1:
			to = row
		for y: int in range(mini(from, to), maxi(from, to) + 1):
			path[Vector2i(column, y)] = true
		if index < LANE_COLUMNS.size() - 1:
			path[Vector2i(column + 1, top if index % 2 == 0 else bottom)] = true
	path[Vector2i(12, row)] = true
	var layout := PathLayout.new(dimensions, budget, entrance, base)
	for cell: Vector2i in path:
		layout.place(cell)
	assert(layout.is_ready() and layout.used_tiles() == path.size(), "Bot path must be legal")
	var captured: Dictionary = layout.capture_routing()
	route = captured["route"]
	_coverage_cache.clear()
	routing = [captured, captured.duplicate(true)]


# Cells no current or future zig-zag can claim: towers there never block growth.
func _safe(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= dimensions.x or cell.y >= dimensions.y:
		return false
	if cell == entrance or cell == base or path.has(cell):
		return false
	var row: int = entrance.y
	if cell.x in [3, 5, 7, 9]:
		return false
	if cell.x in [1, 11]:
		return cell.y > row
	if cell.x in [2, 6, 10]:
		return cell.y > row - reach
	if cell.x in [4, 8]:
		return cell.y < row + reach
	return true


func _coverage(cell: Vector2i, range_cells: float) -> int:
	var key := Vector3(cell.x, cell.y, range_cells)
	if _coverage_cache.has(key):
		return _coverage_cache[key]
	var covered: int = 0
	for step: Vector2i in route:
		if MatchCombat.cell_in_range(cell, step, range_cells):
			covered += 1
	_coverage_cache[key] = covered
	return covered


func _best_cell(slot: int, range_cells: float, prefer_far: bool = false) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: int = -1000000
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var cell := Vector2i(x, y)
			if not _safe(cell) or combat.has_tower(slot, cell):
				continue
			var covered: int = _coverage(cell, range_cells)
			var score: int = -covered if prefer_far else covered
			if score > best_score:
				best_score = score
				best = cell
	return best


func _spend(slot: int, round_number: int) -> void:
	for purchase: int in range(5000):
		if not _buy_once(slot, round_number):
			return


func _buy_once(slot: int, round_number: int) -> bool:
	var coins: int = combat.coins[slot]
	# Early economy: a few Gold Mines on cells the path never reaches.
	var mines: int = _count(slot, &"gold_mine")
	for step: Vector2i in MINES_BY_ROUND:
		if round_number >= step.x and mines < step.y:
			var mine_cost: int = int(combat._tower_types["gold_mine"]["cost"])
			if coins < mine_cost:
				return false
			var spot: Vector2i = _best_cell(slot, 3.0, true)
			return spot.x >= 0 and combat.build(slot, spot, &"gold_mine", MatchCombat.TargetMode.FURTHEST)
	var attackers: Array = combat.towers[slot].filter(func(tower: Dictionary) -> bool: return tower["behavior_kind"] in ATTACK_KINDS)
	# One War Drums for every seven attack towers, beside the most of them.
	var drums_cost: int = int(combat._tower_types["war_drums"]["cost"])
	if _count(slot, &"war_drums") < attackers.size() / 7 and coins >= drums_cost:
		var cell: Vector2i = _drums_cell(slot, attackers)
		if cell.x >= 0:
			return combat.build(slot, cell, &"war_drums", MatchCombat.TargetMode.FURTHEST)
	var best_value: float = 0.0
	var best_action: Callable
	# A new tower of the element the mix lacks most.
	var type_id: StringName = _next_tower_type(slot, attackers)
	var definition: Dictionary = combat._tower_types[String(type_id)]
	var cell: Vector2i = _best_cell(slot, float(definition["range"]))
	if cell.x >= 0 and coins >= int(definition["cost"]):
		var covered: int = _coverage(cell, float(definition["range"]))
		if covered >= 3:
			best_value = _base_dps(definition) * sqrt(float(covered)) / float(definition["cost"])
			var focus: bool = type_id in [&"arrow_tower", &"orc_ballista", &"lightning"] and _count(slot, type_id) % 3 == 2
			var mode: int = MatchCombat.TargetMode.STRONGEST if focus else MatchCombat.TargetMode.FURTHEST
			best_action = func() -> bool: return combat.build(slot, cell, type_id, mode)
	# Or the upgrade that adds the most estimated damage per Coin.
	for tower: Dictionary in attackers:
		var stats: Dictionary = combat._tower_types[tower["type_id"]]
		var options: Dictionary = MatchPlanningScreen.tower_upgrade_actions(tower, stats)
		if bool(tower.get("special_upgraded", false)):
			options.merge(MatchPlanningScreen.advancement_actions(tower, stats))
		var commands: Array = options.keys()
		for index: int in range(commands.size()):
			var command: String = commands[index]
			var action: Dictionary = options[command]
			var cost: int = int(action["cost"])
			if bool(action.get("purchased", false)) or bool(action.get("locked", false)) or cost <= 0 or cost > coins:
				continue
			# Spread branch choices across towers instead of always the first.
			if _is_branch_choice(options, command) and not _preferred_branch(tower, options, command):
				continue
			var value: float = _tower_dps(tower) * sqrt(float(maxi(1, _coverage(tower["cell"], float(tower["range"]))))) * _gain(tower, stats, command) / float(cost)
			if value > best_value:
				best_value = value
				var tower_id: int = tower["id"]
				best_action = func() -> bool: return combat.upgrade_tower(slot, tower_id, command)
	return best_value > 0.0 and best_action.call()


func _count(slot: int, type_id: StringName) -> int:
	return combat.towers[slot].filter(func(tower: Dictionary) -> bool: return tower["type_id"] == String(type_id)).size()


func _next_tower_type(slot: int, attackers: Array) -> StringName:
	var counts: Dictionary = {"physical": 0, "lightning": 0, "magic": 0}
	for tower: Dictionary in attackers:
		var element: String = "physical" if tower.get("element", "") == "fire" else String(tower.get("element", "physical"))
		counts[element] = int(counts.get(element, 0)) + 1
	var total: float = maxf(1.0, float(attackers.size()))
	var lacking: String = "physical"
	var deficit: float = -INF
	for element: String in ELEMENT_SHARES:
		var gap: float = float(ELEMENT_SHARES[element]) - float(counts[element]) / total
		if gap > deficit:
			deficit = gap
			lacking = element
	var choices: Array = ELEMENT_TOWERS[lacking]
	return choices[int(counts[lacking]) % choices.size()]


func _drums_cell(slot: int, attackers: Array) -> Vector2i:
	var range_cells: float = float(combat._tower_types["war_drums"]["range"])
	var best := Vector2i(-1, -1)
	var best_count: int = 1
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var cell := Vector2i(x, y)
			if not _safe(cell) or combat.has_tower(slot, cell):
				continue
			var near: int = attackers.filter(func(tower: Dictionary) -> bool: return MatchCombat.cell_in_range(cell, tower["cell"], range_cells)).size()
			if near > best_count:
				best_count = near
				best = cell
	return best


func _base_dps(definition: Dictionary) -> float:
	var dps: float = float(definition["damage"]) / maxf(0.05, float(definition["interval"]))
	return dps * (2.0 if definition["behavior_kind"] == "chain" or bool(definition.get("area_attack", false)) else 1.0)


func _tower_dps(tower: Dictionary) -> float:
	var interval: float = float(tower.get("interval", 1.0))
	var dps: float = float(tower.get("damage", 1)) / maxf(0.05, interval) if interval > 0.0 else float(tower.get("damage", 1)) * 2.0
	return dps * (2.0 if tower["behavior_kind"] == "chain" or bool(combat._tower_types[tower["type_id"]].get("area_attack", false)) else 1.0)


func _gain(tower: Dictionary, stats: Dictionary, command: String) -> float:
	match command:
		"damage":
			return float(stats.get("damage_upgrade_bonus", 1)) / maxf(1.0, float(tower.get("damage", 1)))
		"speed":
			return 1.0 / maxf(0.1, float(stats.get("speed_upgrade_multiplier", 1.0))) - 1.0
	# Specials, evolutions, branch steps and advancements: roughly a large step.
	return 0.6


func _is_branch_choice(options: Dictionary, command: String) -> bool:
	return _open_siblings(options, command).size() > 1


# Unpurchased, unlocked options of the same price tier compete as branches.
func _open_siblings(options: Dictionary, command: String) -> Array:
	var stats_cost: int = int(options[command]["cost"])
	var siblings: Array = []
	for other: String in options:
		var action: Dictionary = options[other]
		if other in ["damage", "speed", "special"] or bool(action.get("purchased", false)) or bool(action.get("locked", false)):
			continue
		if int(action["cost"]) == stats_cost:
			siblings.append(other)
	return siblings


func _preferred_branch(tower: Dictionary, options: Dictionary, command: String) -> bool:
	var siblings: Array = _open_siblings(options, command)
	siblings.sort()
	return siblings[int(tower["id"]) % siblings.size()] == command
