class_name EnemyDefinition
extends Resource

# Multipliers apply to the match's wave-scaled baseline; artwork is local only.
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
# Apply after rounding the referenced type's HP, rather than before rounding.
@export var health_base_type: StringName = &""
@export var health_base_multiplier: int = 1
@export var spawn_variant: StringName = &""
@export var spawn_variant_first_wave: int = 1
@export_range(0.0, 1.0) var spawn_variant_chance: float = 0.0
@export var hit_shield: int = 0
@export var death_stun_radius: float = 0.0
@export var death_stun_duration: float = 0.0
@export var death_bomb_fuse: float = 0.0
@export var death_bomb_radius: float = 0.0
@export var death_bomb_stun_duration: float = 0.0
@export var base_damage: int = 1
@export var fire_immune: bool = false
@export var ice_immune: bool = false
@export var physical_damage_multiplier: float = 1.0
@export var nonphysical_damage_multiplier: float = 1.0
@export var fire_damage_multiplier: float = 1.0
@export var lightning_damage_multiplier: float = 1.0
# Elements (TowerDefinition.ELEMENTS) that deal no damage; towers skip it as a target.
@export var immune_elements: PackedStringArray = PackedStringArray()
@export var spawn_weight: int = 1
@export var first_wave: int = 1
# Zero means unlimited. Share caps this type's total weight, not its head count.
@export var max_per_wave: int = 0
# Finite caps gain this amount every interval waves after first_wave.
@export var count_cap_growth: int = 0
@export var count_cap_growth_interval: int = 1
@export_range(0.0, 1.0) var max_weight_share: float = 1.0
@export var send_cost: int = 20
# Signed recurring income change per paid order; boss sends may spend income.
@export var send_income: int = 2
@export var send_first_wave: int = 1
@export var regular_spawn_enabled: bool = true
# Bosses reserve one encounter at debut, then roll once per eligible wave.
@export var boss: bool = false
@export_range(0.0, 1.0, 0.005) var boss_spawn_chance: float = 0.05
@export_range(0.0, 1.0, 0.005) var boss_spawn_chance_growth: float = 0.005
@export_range(0.0, 1.0, 0.005) var boss_spawn_chance_cap: float = 0.25
@export var send_enabled: bool = true
# Index zero is one member. A regular budget entry or purchase buys one group.
@export var group_weights: PackedInt32Array = PackedInt32Array([1])
@export var group_interval: float = 0.065
@export var kill_bounty: int = -1
# Separate run-only rarity currency, including zero-bounty summoned enemies.
@export_range(0.0, 1.0) var reroll_drop_chance: float = 0.0
@export var reroll_drop_amount: int = 0
@export var death_spawn_type: StringName
@export var death_spawn_count: int = 0
@export var enrage_health_fraction: float = 0.0
@export var enrage_speed_multiplier: float = 1.0
@export var regeneration_interval: float = 0.0
@export var regeneration_fraction: float = 0.0
@export var heal_interval: float = 0.0
@export var heal_radius: float = 0.0
@export var heal_fraction: float = 0.0
# Each heal also refills the caster's hit shield (ShaOrc).
@export var heal_restores_shield: bool = false
# OrcShakra: each other living caster of this type within the radius quickens
# heals by shakra_max_bonus * (1 - 0.5^n) for n neighbours: 20/30/35/37.5% of a 40% cap.
@export var shakra_radius: float = 0.0
@export var shakra_max_bonus: float = 0.0
# Greater ShaOrc: every interval, other non-boss, non-warding enemies within the
# radius become immune to all damage for the duration, or until the caster leaves.
@export var ward_interval: float = 0.0
@export var ward_duration: float = 0.0
@export var ward_radius: float = 0.0
@export var summon_interval: float = 0.0
@export var summon_cast_duration: float = 0.0
@export var summon_type: StringName
@export var summon_min: int = 0
@export var summon_max: int = 0
@export var summon_limit: int = 0
@export var summon_pool: PackedStringArray = PackedStringArray()
@export var summon_weights: PackedInt32Array = PackedInt32Array()
@export var stomp_interval: float = 0.0
@export var stomp_radius: float = 0.0
@export var stomp_health_fraction: float = 0.0
@export var tower_attack_kind: StringName = &""
@export var tower_attack_interval: float = 0.0
@export var tower_attack_range: float = 0.0
@export var tower_attack_cast_duration: float = 0.0
@export var tower_stun_duration: float = 0.0
@export var tower_attack_targets: int = 1
@export var jump_interval: float = 0.0
# Indices zero through three select two through five captured-route cells.
@export var jump_weights: PackedInt32Array = PackedInt32Array()
@export var jump_deploy_duration: float = 0.0
@export var jump_charge_duration: float = 0.0
@export var jump_duration: float = 0.0
@export var jump_land_duration: float = 0.0
@export var animation_frames: SpriteFrames
@export var texture: Texture2D
@export var source_faces_left: bool = false

# Local presentation only; never part of the host's combat rules.
@export var elite: bool = false
@export var board_height: float = 0.50
@export var board_anchor: Vector2 = Vector2(0.5, 0.90625)
# Transparent for bloodless types; corpse anatomy is authored in the death frames.
@export var blood_color: Color = Color("713535")
