extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _check_validation(catalog: ContentCatalog, accepted: bool, description: String) -> void:
	_check(catalog.validation_errors().is_empty() == accepted, description)


func _item(identity: StringName, tier: ItemRarity.Tier) -> ItemDefinition:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	var item := ItemDefinition.new()
	item.id = identity
	item.title = "Synthetic catalog entry"
	item.rarity = tier
	item.effect_text = "A fixture rule described for the guide."
	item.icon_texture = texture
	item.detail_texture = texture
	item.mechanics = PackedStringArray(["A deterministic fixture mechanic."])
	item.upgrade_to = &""
	item.upgrade_cost = 0
	return item


func _check_item_registration() -> void:
	var catalog := ContentCatalog.new()
	_check_validation(catalog, true, "An empty item registry is valid")
	var item: ItemDefinition = _item(&"fixture_compass", ItemRarity.Tier.RARE)
	catalog.items = [item]
	_check_validation(catalog, true, "A fully authored custom item needs no shipped identity or upgrade")

	var portrait: Texture2D = item.detail_texture
	item.detail_texture = null
	_check_validation(catalog, false, "An item without its detailed inspection portrait is rejected")
	item.detail_texture = portrait
	_check_validation(catalog, true, "Restoring the same item's detail portrait restores admission")

	item.mechanics.clear()
	_check_validation(catalog, false, "An item without inspection mechanics is rejected")
	item.mechanics.append("A deterministic fixture mechanic.")
	_check_validation(catalog, true, "Restoring the same item's mechanic restores admission")
	item.mechanics.append(" \t\n ")
	_check_validation(catalog, false, "A blank mechanic is rejected even beside a usable mechanic")
	item.mechanics[1] = "A second fixture rule."
	_check_validation(catalog, true, "Replacing the blank mechanic restores admission")

	var second: ItemDefinition = _item(&"fixture_lantern", ItemRarity.Tier.UNCOMMON)
	catalog.items.append(second)
	_check_validation(catalog, true, "Distinct custom item identities can share a registry")
	second.id = item.id
	_check_validation(catalog, false, "Different resources cannot register the same item identity")
	second.id = &"fixture_lantern"
	_check_validation(catalog, true, "Repairing the duplicate identity restores the same registry")
	catalog.items.append(item)
	_check_validation(catalog, false, "Registering the same resource twice also duplicates its identity")
	catalog.items.pop_back()
	_check_validation(catalog, true, "Removing the repeated registration restores admission")

	second.id = &""
	_check_validation(catalog, false, "An item without an identity cannot enter the registry")
	second.id = &"fixture_lantern"
	_check_validation(catalog, true, "Restoring the custom identity restores admission")
	catalog.items.append(null)
	_check_validation(catalog, false, "A missing item definition cannot enter the registry")
	catalog.items.pop_back()
	_check_validation(catalog, true, "Removing the missing definition restores admission")
	catalog.items.clear()
	_check_validation(catalog, true, "Removing custom items leaves a valid empty registry")


func _check_upgrade_prices() -> void:
	var source: ItemDefinition = _item(&"fixture_seed", ItemRarity.Tier.UNCOMMON)
	var target: ItemDefinition = _item(&"fixture_bloom", ItemRarity.Tier.MYTHIC)
	target.acquisition_text = "Exchange the fixture seed through its guide upgrade."
	var catalog := ContentCatalog.new()
	catalog.items = [source, target]
	_check_validation(catalog, true, "Registered items may have no upgrade link and no upgrade price")

	for invalid_price: int in [-1, 7]:
		source.upgrade_cost = invalid_price
		_check_validation(catalog, false, "A price without an upgrade link is rejected: %d" % invalid_price)
		source.upgrade_cost = 0
		_check_validation(catalog, true, "Removing an unlinked price restores admission")

	source.upgrade_to = target.id
	for invalid_price: int in [0, -1]:
		source.upgrade_cost = invalid_price
		_check_validation(catalog, false, "A linked upgrade requires a positive price: %d" % invalid_price)
		source.upgrade_cost = 7
		_check_validation(catalog, true, "A positive custom price admits the same registered higher-rarity upgrade")
	source.upgrade_to = &""
	_check_validation(catalog, false, "Removing a priced upgrade link cannot leave a valid advertised upgrade")
	source.upgrade_cost = 0
	_check_validation(catalog, true, "Removing both the link and its price restores a standalone item")


func _check_upgrade_targets() -> void:
	var source: ItemDefinition = _item(&"fixture_map", ItemRarity.Tier.RARE)
	var target: ItemDefinition = _item(&"fixture_atlas", ItemRarity.Tier.LEGENDARY)
	source.upgrade_to = target.id
	source.upgrade_cost = 13
	target.acquisition_text = "Upgrade the fixture map to obtain this atlas."
	var catalog := ContentCatalog.new()
	# The target precedes its source so resolution cannot depend on registry order.
	catalog.items = [target, source]
	_check_validation(catalog, true, "A registered higher-rarity upgrade with acquisition instructions is valid")

	source.upgrade_to = &"fixture_unregistered_atlas"
	_check_validation(catalog, false, "A positive price cannot make an unknown upgrade target valid")
	source.upgrade_to = target.id
	_check_validation(catalog, true, "Resolving the link to the registered target restores admission")
	catalog.items.erase(target)
	_check_validation(catalog, false, "Unregistering a target invalidates an otherwise valid upgrade preview")
	catalog.items.append(target)
	_check_validation(catalog, true, "Registering the same target after its source also restores admission")

	source.acquisition_text = "Synthetic acquisition instructions."
	source.upgrade_to = source.id
	_check_validation(catalog, false, "An item cannot advertise itself as its upgrade")
	source.upgrade_to = target.id
	_check_validation(catalog, true, "Restoring a distinct higher-rarity target restores admission")
	for invalid_tier: ItemRarity.Tier in [ItemRarity.Tier.RARE, ItemRarity.Tier.COMMON]:
		target.rarity = invalid_tier
		_check_validation(catalog, false, "A distinct target at the same or lower rarity is not an upgrade")
		target.rarity = ItemRarity.Tier.LEGENDARY
		_check_validation(catalog, true, "Restoring the target's higher rarity restores admission")

	for missing_instructions: String in ["", " \t\n "]:
		target.acquisition_text = missing_instructions
		_check_validation(catalog, false, "A higher-rarity target requires usable acquisition instructions")
		target.acquisition_text = "Exchange the fixture map through its upgrade."
		_check_validation(catalog, true, "Restoring target acquisition instructions restores the upgrade")

	var portrait: Texture2D = target.detail_texture
	target.detail_texture = null
	_check_validation(catalog, false, "A resolved higher-rarity target without a portrait cannot be advertised as valid")
	target.detail_texture = portrait
	_check_validation(catalog, true, "Repairing the target portrait restores the same upgrade")
	target.mechanics.clear()
	_check_validation(catalog, false, "A resolved higher-rarity target without mechanics cannot be advertised as valid")
	target.mechanics.append("An upgraded fixture mechanic.")
	_check_validation(catalog, true, "Repairing target mechanics restores the same upgrade")


func _run() -> void:
	_check_item_registration()
	_check_upgrade_prices()
	_check_upgrade_targets()
	await process_frame
	if failures == 0:
		print("PASS: synthetic item registration, inspection requirements, upgrade prices, target resolution, rarity, and acquisition contracts")
	quit.call_deferred(1 if failures else 0)
