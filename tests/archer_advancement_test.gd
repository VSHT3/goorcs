extends SceneTree
var failures: int = 0
func _init() -> void:
	_purchase()
	_four_targets()
	_fire()
	_bombs()
	_immunity()
	if failures == 0: print("PASS: exclusive paid archer branches, level/refund, four independent targets, timed nonstack burn, circular bombs, and skeleton physical/status precedence")
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
	value.speed_growth = 0.0
	value.health_growth = 0
	return value
func routes() -> Array[Dictionary]:
	var layout := PathLayout.new()
	for x: int in range(1,13): layout.place(Vector2i(x,4))
	return [layout.capture_routing(),layout.capture_routing()]
func prepared(branch: String) -> MatchCombat:
	var fixture_rules: CombatRules = rules()
	fixture_rules.sandbox_mode = true
	var model := MatchCombat.new(fixture_rules)
	model.build(0,Vector2i(0,3),&"arrow_tower",0)
	for command: String in ["damage","speed","special",branch]: model.upgrade_tower(0,model.towers[0][0]["id"],command)
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
func _four_targets() -> void:
	var model: MatchCombat = prepared("four_archers")
	var tower: Dictionary = model.towers[0][0]
	model.set_archer_targeting(0,tower["id"],2,MatchCombat.TargetMode.STRONGEST)
	model.set_archer_targeting(0,tower["id"],3,MatchCombat.TargetMode.CLOSEST)
	for index: int in range(4):
		var enemy: Dictionary = spawn(model,&"grunt",Vector2(index*0.2,4))
		enemy["progress"] = float(index)
		enemy["hp"] = 100+index*10
	tower["cooldown"] = 0.0
	model._attack(0,0.01)
	var ids: Array = [tower["target_id"],tower["secondary_target_id"],tower["extra_archers"][0]["target_id"],tower["extra_archers"][1]["target_id"]]
	var unique: Dictionary = {}
	for id: int in ids: unique[id]=true
	check(unique.size()==4 and not unique.has(-1),"All four modes choose distinct living enemies")
	for index: int in range(4): check(model.enemies[0][index]["hp"]==97+index*10,"Every selected enemy takes one upgraded physical hit")
	model.enemies[0].resize(1)
	tower["cooldown"] = 0.0
	var hp: int = model.enemies[0][0]["hp"]
	model._attack(0,0.01)
	check(model.enemies[0][0]["hp"]==hp-3,"Fewer enemies do not receive duplicated four-archer hits")
	check(tower["extra_archers"][0]["mode"]==MatchCombat.TargetMode.STRONGEST and tower["extra_archers"][1]["mode"]==MatchCombat.TargetMode.CLOSEST,"Extra independent targeting modes survive volley")
func _fire() -> void:
	var model: MatchCombat = prepared("fire_arrows")
	var tower: Dictionary = model.towers[0][0]
	var enemy: Dictionary = spawn(model,&"grunt",Vector2(0,4))
	tower["cooldown"] = 0.0
	model._attack(0,0.01)
	check(enemy["hp"]==97 and enemy["burning"],"Ignition keeps current physical damage and grants no instant burn tick")
	tower["cooldown"] = 100.0
	model.advance(0.25)
	check(enemy["hp"]==96,"Burn integrates exactly four damage per simulation second")
	model._ignite(enemy,tower,model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["fire_arrows"])
	model.advance(0.25)
	check(enemy["hp"]==95,"Repeated ignition refreshes rather than stacks damage")
	model.sell_tower(0,tower["id"])
	model._spawn_enemy(1,"grunt",0.0,model._elapsed)
	enemy["hp"] = 1
	var before: int = model.coins[0]
	model.advance(0.25)
	check(model.enemies[0].is_empty() and tower["kills"]==1 and model.coins[0]==before+3 and not model.snapshot()["deaths"][0].is_empty(),"Burn kill after source sale retains attribution, bounty and confirmed corpse once")
func _bombs() -> void:
	var model: MatchCombat = prepared("bomb_arrows")
	var tower: Dictionary = model.towers[0][0]
	var primary: Dictionary = spawn(model,&"grunt",Vector2(0,4))
	var near: Dictionary = spawn(model,&"grunt",Vector2(0.8,4))
	var outside: Dictionary = spawn(model,&"grunt",Vector2(0.7,4.7))
	model._attack_arrow(0,tower,primary["id"],primary["pos"],model.snapshot()["tower_types"]["arrow_tower"]["advancements"]["bomb_arrows"])
	check(primary["hp"]==95 and near["hp"]==98 and outside["hp"]==100,"Bomb primary gets ceil1.5 damage, other true-radius victims ceilhalf, square-corner victim escapes")
func _immunity() -> void:
	var model: MatchCombat = prepared("fire_arrows")
	var tower: Dictionary = model.towers[0][0]
	var skeleton: Dictionary = spawn(model,&"skeleorc",Vector2(0,4))
	tower["cooldown"] = 0.0
	model._attack(0,0.01)
	check(skeleton["hp"]==47 and not skeleton["burning"],"Fire-immune skeleton takes physical arrow damage but never ignites")
	model.build(0,Vector2i(1,3),&"rune_obelisk",0)
	var rune: Dictionary = model.towers[0][1]
	for command: String in ["damage","speed","boulders","freeze_runes"]: model.upgrade_tower(0,rune["id"],command)
	model._hit(0,rune,0,20)
	check(skeleton["hp"]==27 and not skeleton["slowed"] and skeleton["slow_remaining"]==0.0,"Ice immunity preserves physical Rune damage but rejects threshold-qualified Freeze")
