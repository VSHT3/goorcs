class_name ItemDefinition
extends Resource
## Authored Itemiery presentation and numeric host-owned run configuration.

@export var id: StringName = &""
@export var title: String = ""
@export var rarity: ItemRarity.Tier = ItemRarity.Tier.COMMON
@export_multiline var effect_text: String = ""
@export_multiline var flavor_text: String = ""
@export var icon_texture: Texture2D
@export var detail_texture: Texture2D
@export var mechanics: PackedStringArray = []
@export var upgrade_to: StringName = &""
@export var upgrade_cost: int = 0
@export_multiline var acquisition_text: String = ""
@export var runtime: Dictionary = {}
