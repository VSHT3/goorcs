extends RefCounted


# Exercise real draft commands before legacy tower-focused scenarios.
static func complete_solo(planning: MatchPlanning) -> bool:
	if not planning.singleplayer or not planning.selecting_loadout:
		return false
	var draft: Dictionary = planning.commander_draft
	if draft.get("phase", "") == "guessing" and not bool(draft.get("guess_locked", [false, false])[0]):
		if not planning.submit_commander_guess(50):
			return false
		draft = planning.commander_draft
	if draft.get("phase", "") == "picking" and int(draft.get("picker", -1)) == 0:
		var picks: Array = draft.get("picks", ["", ""])
		var id: StringName = &"priestess" if picks.has("knight") else &"knight"
		if not planning.select_commander(id):
			return false
		draft = planning.commander_draft
	if draft.get("phase", "") != "loadout" or draft.get("picks", ["", ""])[0] == "" or draft["picks"][1] == "" or draft["picks"][0] == draft["picks"][1]:
		return false
	# Legacy solo scenarios author builds and paths in the upper five rows.
	# Keep real terrain deterministic elsewhere; commander suites generate freely.
	var reserved: Array[Vector2i] = []
	for y: int in range(mini(5, planning.layouts[0].dimensions.y - 3)):
		for x: int in range(planning.layouts[0].dimensions.x):
			reserved.append(Vector2i(x, y))
	return seed_terrain(planning, reserved)


# Choose only the RNG seed: final admission still generates both real boards.
static func seed_terrain(planning: MatchPlanning, reserved: Array[Vector2i]) -> bool:
	if planning == null or planning._host_layouts.size() != 2:
		return false
	for id: StringName in planning._host_commander_ids:
		if not CommanderRules.valid(id):
			return false
	var random := RandomNumberGenerator.new()
	for candidate: int in range(65536):
		random.seed = candidate
		var accepted: bool = true
		for slot: int in range(2):
			var terrain: Dictionary = CommanderRules.generate(planning._host_commander_ids[slot], planning._host_layouts[slot], random)
			if terrain.is_empty():
				return false
			if reserved.has(terrain["landmark"]):
				accepted = false
				break
			for obstacle: Vector2i in terrain["obstacles"]:
				if reserved.has(obstacle):
					accepted = false
					break
			if not accepted:
				break
		if accepted:
			planning._commander_rng.seed = candidate
			return true
	return false


static func free_cell(planning: MatchPlanning, preferred: Vector2i, row: int = -1) -> Vector2i:
	var best := Vector2i(-1, -1)
	var distance: int = 2147483647
	var states: Array = planning.combat.get("commanders", [{}, {}])
	for y: int in range(planning.layouts[0].dimensions.y):
		if row >= 0 and y != row:
			continue
		for x: int in range(planning.layouts[0].dimensions.x):
			var cell := Vector2i(x, y)
			var blocked: bool = false
			for slot: int in range(2):
				var state: Dictionary = states[slot]
				if planning.layouts[slot].has_path(cell) or (not state.is_empty() and (state.get("landmark") == cell or state.get("obstacles", []).has(cell))):
					blocked = true
					break
				for tower: Dictionary in planning.combat.get("towers", [[], []])[slot]:
					if tower["cell"] == cell:
						blocked = true
						break
			if blocked:
				continue
			var candidate: int = absi(cell.x - preferred.x) + absi(cell.y - preferred.y)
			if candidate < distance:
				distance = candidate
				best = cell
	return best
