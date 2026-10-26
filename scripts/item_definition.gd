class_name ItemDefinition
extends Resource
## Authored Itemiery entry. Effect text describes design, not active run rules.

@export var id: StringName = &""
@export var title: String = ""
@export var rarity: ItemRarity.Tier = ItemRarity.Tier.COMMON
@export_multiline var effect_text: String = ""
@export_multiline var flavor_text: String = ""
@export var icon_texture: Texture2D
