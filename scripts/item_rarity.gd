class_name ItemRarity
extends RefCounted
## Item presentation only; independent of tower-roll odds and tiers.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, MYTHIC, LEGENDARY, ORCFECCION }

const NAMES: PackedStringArray = ["Common", "Uncommon", "Rare", "Epic", "Mythic", "Legendary", "Orcfeccion"]
const COLORS: Array[Color] = [
	Color("eeeede"), Color("99ad92"), Color("64aafa"), Color("bb7aec"),
	Color("f05b59"), Color("ffc15a"), Color("80ce45"),
]

static func color(tier: Tier) -> Color:
	return COLORS[tier]


static func glow_strength(tier: Tier) -> float:
	match tier:
		Tier.MYTHIC:
			return 0.16
		Tier.LEGENDARY:
			return 0.36
		Tier.ORCFECCION:
			return 0.5
	return 0.0
