extends SceneTree
var failures: int = 0
func _init() -> void:
	_purchase()
	_shared_targets()
	_fire()
	_bombs()
	_immunity()
	_progression()
	_throwers()
	_eight_and_minigun()
	_upgrade_targeting()
	_flamethrower()
	_validation()
	_modified_streams()
	_flame_motion_and_kills()
	if failures == 0: print("PASS: captured archer progression, atomic purchases, shared targeting with distinct streams, thrown splash, fire immunity, continuous fuel/refuel and frame-step invariance")
	quit(1 if failures else 0)
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func rules() -> CombatRules:
	var value := CombatRules.new()
	value.starting_coins = 10000
	value.enemy_health = 100
	value.enemy_speed = 0.0
	value.speed_growth_fraction = 0.0
	value.health_growth = 0
	return value
func routes() -> Array[Dictionary]:
	var layout := PathLayout.new()
	for x: int in range(1,13): layout.place(Vector2i(x,4))
	return [layout.capture_routing(),layout.capture_routing()]
func prepared(branch: String, boosted: bool = false) -> MatchCombat:
	var fixture_rules: CombatRules = rules()
	fixture_rules.sandbox_mode = true
	if boosted:
		fixture_rules.catalog=fixture_rules.catalog.duplicate(true) as ContentCatalog
		var definitions: Array[TowerDefinition]=[]
		for source: TowerDefinition in fixture_rules.catalog.towers:
			if source.reward.id not in [&"arrow_tower",&"war_drums"]: continue
			var definition: TowerDefinition=source.duplicate(true) as TowerDefinition
			definition.roll_attributes=PackedStringArray(["damage","attack_speed"] if definition.reward.id==&"arrow_tower" else ["range"])
			definitions.append(definition)
		fixture_rules.catalog.towers=definitions
		var rolls:=TowerRollRules.new()
		rolls.slot_profiles={"attack":{},"support":{},"economy":{}}
		for rarity: String in TowerRollRules.RARITIES:
			rolls.rarities.append({"id":rarity,"title":rarity.capitalize(),"weight":1.0 if rarity in ["common","uncommon"] else 0.0,"positive_slots":2,"drawback_slots":0,"positive_pool":{"damage":Vector2(0.25,0.25),"attack_speed":Vector2(0.5,0.5),"range":Vector2(1.0,1.0)},"drawback_pool":{}})
			rolls.slot_profiles["support"][rarity]=Vector2i(1,0)
		fixture_rules.roll_rules=rolls
	var model := MatchCombat.new(fixture_rules)
	model.build(0,Vector2i(0,3),&"arrow_tower",0)
	if boosted: model.build(0,Vector2i(1,3),&"war_drums",0)
	for command: String in ["damage","speed","special"]: model.upgrade_tower(0,model.towers[0][0]["id"],command)
	var path: Array[String] = []
	var cursor: String = branch
	var configs: Dictionary = model.snapshot()["tower_types"]["arrow_tower"]["advancements"]
	while not cursor.is_empty():
		path.push_front(cursor)
		cursor = String(configs[cursor].get("requires", ""))
	for command: String in path: model.upgrade_tower(0,model.towers[0][0]["id"],command)
	var roster: Array[String] = []
	model.sandbox_start(routes(),1,roster)
	return model
func spawn(model: MatchCombat, type_id: StringName, pos: Vector2) -> Dictionary:
	model._spawn_enemy(0,String(type_id),0.0,model._elapsed)
	var enemy: Dictionary = model.enemies[0].back()
	enemy["pos"] = pos
	return enemy
func _purchase() -> void:
	for branch: String in ["four_archers","fire_arrows","bomb_arrows"]:
		var model := MatchCombat.new(rules())
		model.build(0,Vector2i(0,3),&"arrow_tower",0)
		var tower: Dictionary = model.towers[0][0]
		var frozen: Dictionary = model.snapshot()
		check(not model.upgrade_tower(0,tower["id"],branch) and model.snapshot()==frozen,"Advanced path cannot bypass three paid prerequisite upgrades")
		for command: String in ["damage","speed","special"]: model.upgrade_tower(0,tower["id"],command)
		var price: int = model.snapshot()["tower_types"]["arrow_tower"]["advancements"][branch]["cost"]
		model.coins[0] = price-1
		frozen = model.snapshot()
		check(not model.upgrade_tower(0,tower["id"],branch) and model.snapshot()==frozen,"Unaffordable path is atomic")
		model.coins[0] = price
		check(model.upgrade_tower(0,tower["id"],branch) and model.coins[0]==0 and MatchCombat.tower_level(tower)==5,"Exact funds buy one permanent level-V path")
		model.coins[0] = 10000
		frozen = model.snapshot()
		for other: String in ["four_archers","fire_arrows","bomb_arrows"]: check(not model.upgrade_tower(0,tower["id"],other) and model.snapshot()==frozen,"Purchased branch forbids repeats and switching")
		check(tower["sell_value"]==floori(float(tower["invested"])*0.6),"Refund includes actual paid advancement investment")
func _stream_targets(tower: Dictionary) -> Array[int]:
	var ids: Array[int] = [tower["target_id"], tower["secondary_target_id"]]
	for archer: Dictionary in tower["extra_archers"]:
		ids.append(archer["target_id"])
	return ids

func _shared_targets() -> void:
	var progress: Array[int] = [2,5,1,4,0,3,8,7,9,6]
	var ordering: Dictionary = {
		2: [[1,3], [0,1], [1,0], [2,0]],
		4: [[1,3,5,0], [0,1,2,3], [3,2,1,0], [4,2,0,5]],
		8: [[8,6,7,9,1,3,5,0], [0,1,2,3,4,5,6,7], [7,6,5,4,3,2,1,0], [4,2,0,5,3,1,9,7]],
	}
	for shooters: int in [2,4,8]:
		var branch: String = "" if shooters == 2 else ("four_archers" if shooters == 4 else "eight_archers")
		var model: MatchCombat = prepared(branch)
		var tower: Dictionary = model.towers[0][0]
		var enemy_ids: Array[int] = []
		for index: int in range(shooters+2):
			var enemy: Dictionary = spawn(model,&"grunt",Vector2(index*0.1,4))
			enemy["progress"] = float(progress[index])
			enemy_ids.append(enemy["id"])
		var volley: int = 0
		for mode: int in [MatchCombat.TargetMode.LAST, MatchCombat.TargetMode.FURTHEST, MatchCombat.TargetMode.CLOSEST, MatchCombat.TargetMode.STRONGEST]:
			for index: int in range(model.enemies[0].size()):
				model.enemies[0][index]["hp"] = 1000+((index+2)%(shooters+2))*10
			var frozen: Dictionary = model.snapshot()
			check(not model.set_targeting(1,tower["id"],mode) and not model.set_targeting(0,tower["id"],-1) and not model.set_targeting(0,tower["id"],MatchCombat.TargetMode.LAST+1) and model.snapshot()==frozen,"Shared policy rejects wrong-owner and invalid modes atomically at every archer count")
			check(model.set_targeting(0,tower["id"],mode),"One accepted policy change controls the next live volley")
			frozen = model.snapshot()
			check(not model.set_targeting(0,tower["id"],mode) and model.snapshot()==frozen,"Repeated shared policy is an atomic no-op")
			var expected: Array[int] = []
			for index: int in ordering[shooters][mode]:
				expected.append(enemy_ids[index])
			var before_damage: int = tower["damage_dealt"]
			tower["cooldown"] = 0.0
			model._attack(0,0.01)
			volley += 1
			check(_stream_targets(tower)==expected,"%d archers use mode %d in score order after excluding all earlier targets" % [shooters,mode])
			check(tower["aim"]==model.enemies[0][ordering[shooters][mode][0]]["pos"] and tower["secondary_aim"]==model.enemies[0][ordering[shooters][mode][1]]["pos"],"First and second streams retain their own accepted aim")
			check(tower["shot"]==volley and tower["secondary_shot"]==volley and tower["damage_dealt"]==before_damage+3*shooters,"Policy changes retain every stream's shot history and full-damage accounting")
			for index: int in range(tower["extra_archers"].size()):
				var archer: Dictionary = tower["extra_archers"][index]
				check(archer["shot"]==volley and archer["aim"]==model.enemies[0][ordering[shooters][mode][index+2]]["pos"],"Every extra stream retains its independently captured shot and aim")
			for index: int in range(model.enemies[0].size()):
				var expected_hp: int = 1000+((index+2)%(shooters+2))*10-(3 if expected.has(enemy_ids[index]) else 0)
				check(model.enemies[0][index]["hp"]==expected_hp,"Distinct selection damages each chosen enemy once without touching unselected enemies")
		for count: int in [1,2,3,7]:
			if count>=shooters:
				continue
			model = prepared(branch)
			tower = model.towers[0][0]
			model.set_targeting(0,tower["id"],MatchCombat.TargetMode.STRONGEST)
			enemy_ids.clear()
			var total_hp: int = 0
			for index: int in range(count):
				var enemy: Dictionary = spawn(model,&"grunt",Vector2(index*0.1,4))
				enemy["hp"] = 100+index*10
				total_hp += int(enemy["hp"])
				enemy_ids.append(enemy["id"])
			model._attack(0,0.01)
			var expected: Array[int] = []
			for index: int in range(shooters):
				expected.append(enemy_ids[maxi(0,count-1-index)] if index<count else enemy_ids[count-1])
			var remaining_hp: int = 0
			for enemy: Dictionary in model.enemies[0]:
				remaining_hp += int(enemy["hp"])
			check(_stream_targets(tower)==expected and remaining_hp==total_hp-3*shooters,"Too-few-enemy volleys exhaust distinct Strongest targets before sharing the best fallback")
			check(tower["shot"]==1 and tower["secondary_shot"]==1 and tower["damage_dealt"]==3*shooters,"Fallback never idles a real archer or changes full-damage accounting")
			for archer: Dictionary in tower["extra_archers"]:
				check(archer["shot"]==1,"Every extra archer releases its accepted fallback shot")
func _fire() -> void:
	var model: MatchCombat = prepared("fire_arrows")
	var tower: Dictionary = model.towers[0][0]
	var enemy: Dictionary = spawn(model,&"grunt",Vector2(0,4))
	tower["cooldown"] = 0.0
	model._attack(0,0.01)
	check(enemy["hp"]==94 and enemy["burning"],"Both physical arrows hit while ignition grants no instant burn tick")
	check(tower["damage_dealt"] == 6, "Both accepted projectile hits contribute actual HP once")
	tower["cooldown"] = 100.0
	model.advance(0.25)
	check(enemy["hp"]==93,"Burn integrates exactly four damage per simulation second")
	model._ignite(enemy,tower,model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["fire_arrows"])
	model.advance(0.25)
	check(enemy["hp"]==92,"Repeated ignition refreshes rather than stacks damage")
	model.sell_tower(0,tower["id"])
	model._spawn_enemy(1,"grunt",0.0,model._elapsed)
	enemy["hp"] = 1
	var before: int = model.coins[0]
	model.advance(0.25)
	check(model.enemies[0].is_empty() and tower["kills"]==1 and model.coins[0]==before+3 and not model.snapshot()["deaths"][0].is_empty(),"Burn kill after source sale retains attribution, bounty and confirmed corpse once")
	check(tower["damage_dealt"] == 9, "Burn continues lifetime accounting after source sale and clips its lethal hit to one remaining HP")
func _bombs() -> void:
	var model: MatchCombat = prepared("bomb_arrows")
	var tower: Dictionary = model.towers[0][0]
	var primary: Dictionary = spawn(model,&"grunt",Vector2(0,4))
	var near: Dictionary = spawn(model,&"grunt",Vector2(0.8,4))
	var outside: Dictionary = spawn(model,&"grunt",Vector2(0.7,4.7))
	model._attack_arrow(0,tower,primary["id"],primary["pos"],model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["bomb_arrows"])
	check(primary["hp"]==95 and near["hp"]==98 and outside["hp"]==100,"Bomb primary gets ceil1.5 damage, other true-radius victims ceilhalf, square-corner victim escapes")
	check(tower["damage_dealt"] == 7, "Primary and true-radius splash contribute exactly their distinct removed HP")
func _immunity() -> void:
	var model: MatchCombat = prepared("fire_arrows")
	var tower: Dictionary = model.towers[0][0]
	var skeleton: Dictionary = spawn(model,&"skeleorc",Vector2(0,4))
	tower["cooldown"] = 0.0
	model._attack(0,0.01)
	check(skeleton["hp"]==44 and not skeleton["burning"],"Fire-immune skeleton takes both physical arrows but never ignites")
	model.build(0,Vector2i(1,3),&"rune_obelisk",0)
	var rune: Dictionary = model.towers[0][1]
	for command: String in ["damage","speed","boulders","freeze_runes"]: model.upgrade_tower(0,rune["id"],command)
	tower["cooldown"] = 100.0
	model.advance(0.01)
	check(skeleton["hp"]==44 and not skeleton["slowed"] and skeleton["slow_remaining"]==0.0,"Ice-immune enemy rejects Freeze even on positive sub-HP continuous contact")
	model.advance(0.16)
	check(skeleton["hp"]==43 and not skeleton["slowed"] and skeleton["slow_remaining"]==0.0,"Ice immunity preserves continuous Boulders physical damage without applying a slow")

func _progression() -> void:
	var model := MatchCombat.new(rules())
	model.coins[0] = 50000
	model.build(0,Vector2i(0,3),&"arrow_tower",0)
	var tower: Dictionary = model.towers[0][0]
	for command: String in ["damage","speed","special"]: model.upgrade_tower(0,tower["id"],command)
	var configs: Dictionary = model.snapshot()["tower_types"]["arrow_tower"]["advancements"]
	var path: Array[String] = ["bomb_arrows","bigger_bombs","anti_orc_grenades","aom","aom_speed_1","aom_speed_2"]
	for index: int in range(path.size()):
		var frozen: Dictionary = model.snapshot()
		if index+1<path.size(): check(not model.upgrade_tower(0,tower["id"],path[index+1]) and model.snapshot()==frozen,"Cannot skip an exact captured prerequisite")
		var cost: int = configs[path[index]]["cost"]
		var invested: int = tower["invested"]
		var interval: float = tower["base_interval"]
		var funds: int = model.coins[0]
		model.coins[0] = cost-1
		frozen = model.snapshot()
		check(not model.upgrade_tower(0,tower["id"],path[index]) and model.snapshot()==frozen,"Every followup rejects insufficient funds atomically")
		model.coins[0] = funds
		check(model.upgrade_tower(0,tower["id"],path[index]),"Every exact prerequisite accepts its paid followup")
		check(tower["advancement_path"]==path.slice(0,index+1) and MatchCombat.tower_level(tower)==5+index,"History and level retain every purchase")
		check(tower["invested"]==invested+cost and model.coins[0]==funds-cost and tower["sell_value"]==floori(float(invested+cost)*0.6),"Every price contributes to investments and refunds")
		check(is_equal_approx(tower["base_interval"],interval/float(configs[path[index]].get("attack_rate_multiplier",1.0))),"Per-purchase attack multipliers apply exactly once")
		frozen=model.snapshot()
		check(not model.upgrade_tower(0,tower["id"],path[index]) and not model.upgrade_tower(0,tower["id"],"fire_arrows") and model.snapshot()==frozen,"No repeats, branch switches or history rewrites")

func _throwers() -> void:
	var model: MatchCombat = prepared("molotov")
	var tower: Dictionary = model.towers[0][0]
	var primary: Dictionary = spawn(model,&"grunt",Vector2(0,4))
	var near: Dictionary = spawn(model,&"grunt",Vector2(0.8,4))
	var corner: Dictionary = spawn(model,&"grunt",Vector2(0.9,4.9))
	var immune: Dictionary = spawn(model,&"skeleorc",Vector2(0.4,4))
	model._attack_arrow(0,tower,primary["id"],primary["pos"],model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["molotov"])
	check(primary["hp"]==96 and near["hp"]==98 and corner["hp"]==100,"Thrown bottle has increased primary damage and a true circular splash")
	check(primary["burning"] and near["burning"] and not corner["burning"] and not immune["burning"],"Every affected nonimmune splash victim burns, outside/immune victims do not")
	var before: float=tower["interval"]
	check(model.upgrade_tower(0,tower["id"],"quick_pitch") and is_equal_approx(tower["interval"],before/1.5),"Quick Pitch gives exactly fifty percent more throws")
	for branch: String in ["aom","aom_speed_1","aom_speed_2"]:
		model=prepared(branch)
		tower=model.towers[0][0]
		var victim: Dictionary=spawn(model,&"grunt",Vector2(0,4))
		victim["hp"]=10000
		model._attack(0,0.01)
		check(tower["shot"]==1 and tower["secondary_shot"]==0 and tower["secondary_target_id"]==-1 and tower["extra_archers"].is_empty(),"Rocket branches have one real operator, never a phantom second projectile")

func _eight_and_minigun() -> void:
	var model: MatchCombat=prepared("eight_archers")
	var tower: Dictionary=model.towers[0][0]
	for index: int in range(8):
		var enemy: Dictionary=spawn(model,&"grunt",Vector2(index*0.1,4))
		enemy["progress"]=index*0.1
	check(model.set_targeting(0,tower["id"],MatchCombat.TargetMode.LAST),"Eight archers accept one shared Last policy")
	model._attack(0,0.01)
	var ids: Dictionary={tower["target_id"]:true,tower["secondary_target_id"]:true}
	for archer: Dictionary in tower["extra_archers"]: ids[archer["target_id"]]=true
	check(ids.size()==8 and not ids.has(-1),"Eight real streams choose eight distinct living targets")
	var victim: Dictionary=model.enemies[0][0]
	model.enemies[0]=[victim]
	tower["cooldown"]=0.0
	var hp: int=victim["hp"]
	model._attack(0,0.01)
	check(victim["hp"]==hp-24,"Eight archers deliver eight full baseline hits")
	var baseline: float=tower["interval"]
	check(model.upgrade_tower(0,tower["id"],"arrow_minigun") and tower["extra_archers"].is_empty() and is_equal_approx(tower["interval"],baseline/20.0),"Minigun replaces all streams with one twenty-archer-rate gun")
	var reference: int=-1
	for step: float in [0.01,0.1,0.5]:
		model=prepared("arrow_minigun")
		tower=model.towers[0][0]
		victim=spawn(model,&"grunt",Vector2(0,4))
		victim["hp"]=100000
		var duration: float=2.0
		for tick: int in range(roundi(duration/step)): model.advance(step)
		var expected: int=floori(duration/float(tower["interval"])+0.000000001)+1
		check(tower["shot"]==expected and victim["hp"]==100000-3*expected and tower["secondary_shot"]==0,"Minigun catches subinterval shots at every practical simulation step")
		if reference<0: reference=tower["shot"]
		check(tower["shot"]==reference,"Single-stream throughput is independent of physics/playback step")

func _upgrade_targeting() -> void:
	for branch: String in ["arrow_minigun","flamethrower","aom_speed_2"]:
		var fixture_rules: CombatRules = rules()
		fixture_rules.sandbox_mode = true
		var model := MatchCombat.new(fixture_rules)
		model.build(0,Vector2i(0,3),&"arrow_tower",MatchCombat.TargetMode.FURTHEST)
		var tower: Dictionary = model.towers[0][0]
		check(model.set_targeting(0,tower["id"],MatchCombat.TargetMode.STRONGEST),"Shared Strongest policy can be chosen before adding or replacing archers")
		var path: Array[String] = []
		var cursor: String = branch
		var configs: Dictionary = model.snapshot()["tower_types"]["arrow_tower"]["advancements"]
		while not cursor.is_empty():
			path.push_front(cursor)
			cursor = String(configs[cursor].get("requires",""))
		for command: String in ["damage","speed","special"]+path:
			check(model.upgrade_tower(0,tower["id"],command) and tower["mode"]==MatchCombat.TargetMode.STRONGEST,"Every stat, archer and branch upgrade retains the chosen tower policy")
		var roster: Array[String] = []
		model.sandbox_start(routes(),1,roster)
		var enemy_ids: Array[int] = []
		for index: int in range(4):
			var enemy: Dictionary = spawn(model,&"grunt",Vector2(index*0.2,4))
			enemy["progress"] = index*0.2
			enemy_ids.append(enemy["id"])
		var expected: Dictionary = {
			MatchCombat.TargetMode.FURTHEST: 3,
			MatchCombat.TargetMode.CLOSEST: 0,
			MatchCombat.TargetMode.STRONGEST: 2,
			MatchCombat.TargetMode.LAST: 0,
		}
		for mode: int in [MatchCombat.TargetMode.STRONGEST,MatchCombat.TargetMode.LAST,MatchCombat.TargetMode.FURTHEST,MatchCombat.TargetMode.CLOSEST]:
			if mode!=tower["mode"]:
				check(model.set_targeting(0,tower["id"],mode),"The same targeting action controls evolved single operators during combat")
			for index: int in range(4):
				model.enemies[0][index]["hp"] = [1000,1100,1500,1200][index]
			var previous_shots: int = tower["shot"]
			tower["cooldown"] = 0.0
			model.advance(0.01)
			check(tower["target_id"]==enemy_ids[expected[mode]] and tower["aim"]==model.enemies[0][expected[mode]]["pos"],"Minigun, Flame and Rocket use the accepted shared mode and captured aim")
			check(tower["firing"] if branch=="flamethrower" else tower["shot"]>previous_shots,"Chosen single-operator targets produce real firing rather than only policy metadata")

func flame_fixture() -> MatchCombat:
	var model: MatchCombat=prepared("flamethrower")
	var enemy: Dictionary=spawn(model,&"grunt",Vector2(0,4))
	enemy["hp"]=100000
	return model

func _flamethrower() -> void:
	var reference: int=-1
	for step: float in [0.01,0.25,1.0]:
		var model: MatchCombat=flame_fixture()
		var tower: Dictionary=model.towers[0][0]
		for tick: int in range(roundi(67.0/step)): model.advance(step)
		var hp: int=model.enemies[0][0]["hp"]
		check(is_equal_approx(tower["continuous_fire_time"],1.0) and tower["firing"] and is_zero_approx(tower["refuel_remaining"]) and tower["shot"]==0 and tower["secondary_shot"]==0,"Sixty firing seconds, six locked refuel seconds, then one firing second produce no discrete arrows")
		if reference<0: reference=hp
		check(hp==reference,"Continuous fractional fire plus sustained burn is frame-step independent through refuel")
		check(tower["damage_dealt"] == 100000 - hp, "Flame plus burn count every removed HP once through refuel at each simulation cadence")
	var model: MatchCombat=flame_fixture()
	var tower: Dictionary=model.towers[0][0]
	model.advance(59.5)
	check(is_equal_approx(tower["continuous_fire_time"],59.5) and tower["refuel_remaining"]==0.0,"Fuel lasts until exact sixtieth uninterrupted simulation second")
	model.advance(0.5)
	check(not tower["firing"] and tower["continuous_fire_time"]==0.0 and is_equal_approx(tower["refuel_remaining"],6.0),"Exact fuel boundary immediately enters mandatory six-second refuel")
	var enemy: Dictionary=model.enemies[0][0]
	enemy["fire_immune"]=true
	model.advance(3.0)
	check(is_equal_approx(tower["refuel_remaining"],3.0),"Losing every eligible target never cancels refuel")
	model.advance(3.0)
	check(is_zero_approx(tower["refuel_remaining"]) and not tower["firing"],"Refuel completes on exact simulation boundary without a phantom shot")
	enemy["fire_immune"]=false
	model.advance(2.0)
	check(is_equal_approx(tower["continuous_fire_time"],2.0),"Firing restarts with a fresh streak after refueling")
	enemy["fire_immune"]=true
	model.advance(0.1)
	check(not tower["firing"] and tower["continuous_fire_time"]==0.0,"Targetless interruption resets the streak")
	model=prepared("flamethrower")
	tower=model.towers[0][0]
	var skeleton: Dictionary=spawn(model,&"skeleorc",Vector2(0,4))
	var hp: int=skeleton["hp"]
	model.advance(2.0)
	check(skeleton["hp"]==hp and not skeleton["burning"] and not tower["firing"] and tower["continuous_fire_time"]==0.0,"Fire immunity rejects the entire continuous weapon, with no physical leak or fuel use")
	model=flame_fixture()
	tower=model.towers[0][0]
	model.advance(3.0)
	model.debug_set_round(2)
	check(not tower["firing"] and tower["continuous_fire_time"]==0.0,"Debug wave transitions reset accepted firing streak")
	model=flame_fixture()
	tower=model.towers[0][0]
	model.advance(60.0)
	for tick: int in range(122): model.advance(0.05)
	check(tower["refuel_remaining"]==0.0 and tower["firing"],"Fractional clock steps retire the refuel flag completely so the resumed flame can render")
	for step: float in [0.01, 2.0]:
		model = flame_fixture()
		tower = model.towers[0][0]
		enemy = model.enemies[0][0]
		check(model.build(0, Vector2i(1, 3), &"gold_mine", 0), "Marked flame fixture places its real Board")
		var board: Dictionary = model.towers[0][1]
		for command: String in ["damage", "speed", "bounty_board"]:
			check(model.upgrade_tower(0, board["id"], command), "Marked flame fixture accepts its Board prerequisite")
		model._update_bounties(0)
		for tick: int in range(roundi(2.0 / step)):
			model.advance(step)
		var config: Dictionary = model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["flamethrower"]
		var bonus: float = enemy["bounty_damage_bonus"]
		var extra: int = floori(2.0 * float(config["continuous_dps"]) * float(tower["damage_multiplier"]) * float(tower["speed_multiplier"]) * bonus + 0.000000001) + floori(2.0 * float(config["burn_dps"]) * float(tower["damage_multiplier"]) * bonus + 0.000000001)
		check(board["indirect_damage"] == extra and tower["damage_dealt"] + extra == 100000 - int(enemy["hp"]), "Marked flame and burn accumulate separate fractional bonus streams without duplicate attribution at %.2fs cadence" % step)

func _validation() -> void:
	var definition: TowerDefinition=(load("res://resources/combat/towers/arrow_tower.tres") as TowerDefinition).duplicate(true) as TowerDefinition
	check(TowerDefinition.valid_advancements(definition),"Full authored flat advancement graph is admitted")
	for value: Variant in [NAN,INF,-1.0,0.0,"fast"]:
		var invalid: TowerDefinition=definition.duplicate(true) as TowerDefinition
		invalid.advancements["quick_pitch"]["attack_rate_multiplier"]=value
		check(not TowerDefinition.valid_advancements(invalid),"Nonfinite, nonnumeric and nonpositive combat rates reject")
	var invalid: TowerDefinition=definition.duplicate(true) as TowerDefinition
	invalid.advancements["molotov"]["requires"]="flamethrower"
	check(not TowerDefinition.valid_advancements(invalid),"Cyclic prerequisite chains reject")
	invalid=definition.duplicate(true) as TowerDefinition
	invalid.advancements["aom"]["requires"]="missing"
	check(not TowerDefinition.valid_advancements(invalid),"Dangling prerequisites reject")
	invalid=definition.duplicate(true) as TowerDefinition
	invalid.advancements["aom"]["splash_radius"]=false
	check(not TowerDefinition.valid_advancements(invalid),"Boolean values cannot masquerade as numeric splash stats")
	var fixture_rules: CombatRules=rules()
	fixture_rules.catalog=fixture_rules.catalog.duplicate(true) as ContentCatalog
	fixture_rules.catalog.towers=[definition]
	var captured := MatchCombat.new(fixture_rules)
	var original: Dictionary=captured.snapshot()["tower_types"]["arrow_tower"]["advancements"].duplicate(true)
	definition.advancements["aom"]["cost"]=1
	definition.advancements["flamethrower"]["continuous_dps"]=9999.0
	definition.advancements["eight_archers"]["requires"]="fire_arrows"
	check(captured.snapshot()["tower_types"]["arrow_tower"]["advancements"]==original,"Live source-resource changes cannot mutate captured prices, damage, or prerequisites")

func _modified_streams() -> void:
	var reference: int=-1
	for step: float in [0.01,0.1,0.5]:
		var model: MatchCombat=prepared("arrow_minigun",true)
		var tower: Dictionary=model.towers[0][0]
		var enemy: Dictionary=spawn(model,&"grunt",Vector2(0,4))
		enemy["hp"]=100000
		check(tower["attributes"].size()==2 and tower["damage_multiplier"]>1.25 and tower["speed_multiplier"]>1.5,"Real placement rolls and neighboring support survive every minigun prerequisite")
		for tick: int in range(roundi(2.0/step)): model.advance(step)
		var expected: int=floori(2.0/float(tower["interval"])+0.000000001)+1
		check(tower["shot"]==expected and enemy["hp"]==100000-int(tower["damage"])*expected,"Modified minigun preserves rolled/support damage and full fractional interval throughput")
		if reference<0: reference=tower["shot"]
		check(tower["shot"]==reference,"Rolled/support speed does not expose physics-step shot capping")
	var model: MatchCombat=prepared("flamethrower",true)
	var tower: Dictionary=model.towers[0][0]
	var enemy: Dictionary=spawn(model,&"grunt",Vector2(0,4))
	enemy["hp"]=100000
	var config: Dictionary=model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["flamethrower"]
	model.advance(2.0)
	var expected: int=floori(2.0*float(config["continuous_dps"])*float(tower["damage_multiplier"])*float(tower["speed_multiplier"])+0.000000001)+floori(2.0*float(config["burn_dps"])*float(tower["damage_multiplier"])+0.000000001)
	check(enemy["hp"]==100000-expected,"Continuous fire preserves rolled/support damage and speed, while burn preserves its own damage scaling")
	var frozen: Dictionary=model.snapshot()
	check(not model.advance(0.0) and model.snapshot()==frozen,"No simulation time means no firing, fuel, refuel or burn progress")

func _flame_motion_and_kills() -> void:
	var remaining: int=-1
	for step: float in [0.01,0.5,8.5]:
		var model: MatchCombat=flame_fixture()
		var tower: Dictionary=model.towers[0][0]
		var enemy: Dictionary=model.enemies[0][0]
		enemy["base_speed"]=1.0
		enemy["speed"]=1.0
		for tick: int in range(roundi(8.5/step)): model.advance(step)
		check(not tower["firing"] and tower["continuous_fire_time"]==0.0 and not enemy["burning"],"Leaving range interrupts fire and the longer sustained burn expires on simulation time")
		if remaining<0: remaining=enemy["hp"]
		check(enemy["hp"]==remaining,"Motion through the range edge has identical fire and burn exposure across coarse/fine frames")
	remaining=-1
	for step: float in [0.01,0.5,2.0]:
		var model: MatchCombat=prepared("flamethrower")
		var tower: Dictionary=model.towers[0][0]
		for index: int in range(4):
			var enemy: Dictionary=spawn(model,&"grunt",Vector2(0,4))
			enemy["hp"]=100
		for tick: int in range(roundi(2.0/step)): model.advance(step)
		var total: int=0
		for enemy: Dictionary in model.enemies[0]: total+=int(enemy["hp"])
		if remaining<0: remaining=total
		check(total==remaining and tower["kills"]>=2,"Lethal continuous fractions retarget inside coarse ticks without wasting damage or inventing arrows")
		check(tower["damage_dealt"] == 400 - total, "Lethal flame retargeting accounts exactly for living and killed enemies without overkill")
