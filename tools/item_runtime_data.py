#!/usr/bin/env python3
"""Authored gameplay numbers for every Itemiery resource; never parse guide prose.

Running this module updates only the runtime field, preserving prose and artwork.
The art author imports RUNTIME so regenerating an item preserves its gameplay.
"""
import json
import re
from pathlib import Path


def stat(filter_name, **values):
    return {"stats": [{"filter": filter_name, "values": values}]}


def special(identity, **parameters):
    return {"mechanic": identity, "parameters": parameters}


RUNTIME = {
    "iron_arrowhead": stat("attacking", damage_multiplier=1.05),
    "oiled_gears": stat("attacking", attack_rate_multiplier=1.05),
    "heavy_ammunition": stat("attacking", damage_multiplier=1.12, attack_rate_multiplier=0.95),
    "short_bowstring": stat("arrow", damage_multiplier=1.10, range_add=-0.25),
    "greased_winch": stat("ballista", attack_rate_multiplier=1.08),
    "chipped_runestone": stat("rune", damage_multiplier=1.08),
    "copper_coil": stat("lightning", damage_multiplier=1.08),
    "sturdy_pickaxe": special("sturdy_pickaxe", production_multiplier=1.08),
    "taut_drumskin": stat("drums", support_multiplier=1.05),
    "copper_tooth": special("copper_tooth", bonus_coins=1),
    "leather_bracer": stat("physical_projectile", damage_multiplier=1.04),
    "salted_rations": stat("attacking", damage_multiplier=1.07, attack_rate_multiplier=0.97),
    "field_manual": stat("rune", range_add=0.25),
    "reed_whistle": stat("attacking", attack_rate_multiplier=1.04),
    "flint_striker": stat("fire_arrow", direct_damage_multiplier=1.08),
    "snail_shell": stat("attacking", range_add=0.25, attack_rate_multiplier=0.95),
    "woven_sling": stat("orcapult", damage_multiplier=1.08),
    "orc_tusk": special("orc_tusk", health_multiplier=0.90),
    "torn_boot": special("torn_boot", speed_multiplier=0.88),
    "dabloons": special("dabloons", cost_multiplier=0.90),
    "steel_arrowhead": stat("attacking", damage_multiplier=1.10),
    "balanced_mechanism": stat("attacking", damage_multiplier=1.06, attack_rate_multiplier=1.06),
    "lucky_fang": stat("attacking", crit_chance_add=0.03),
    "siege_scope": stat("attacking", range_add=0.50, attack_rate_multiplier=0.92),
    "lightweight_ammunition": stat("attacking", damage_multiplier=0.90, attack_rate_multiplier=1.18),
    "heavy_bolts": stat("physical_ballista", damage_multiplier=1.25, attack_rate_multiplier=0.90),
    "resonant_drumsticks": stat("drums", support_multiplier=1.12),
    "oversized_bucket": stat("orcapult", throw_count_add=1, reload_multiplier=1.20),
    "trollhide_earplugs": special("trollhide_earplugs", duration_multiplier=0.80),
    "gravediggers_lantern": special("gravediggers_lantern", damage_multiplier=1.25),
    "peppercorn_skewer": stat("attacking", attack_rate_multiplier=1.08),
    "surveyors_fieldbook": stat("attacking", range_add=0.30, damage_multiplier=0.95),
    "riveted_bracer": stat("physical", damage_multiplier=1.15, attack_rate_multiplier=0.92),
    "copper_winding": stat("lightning", attack_rate_multiplier=1.12),
    "pitch_sealed_sling": stat("orcapult", damage_multiplier=1.12),
    "menders_spool": special("menders_spool", duration_multiplier=0.85),
    "mooncap_jerky": special("mooncap_jerky", boss_multiplier=1.15, nonboss_multiplier=0.95),
    "counting_frame": special("counting_frame", production_multiplier=1.10),
    "command_banner": special("command_banner", speed_multiplier=1.15),
    "orcish_lunch_tin": special("orcish_lunch_tin", base_coins=10, round_divisor=5, streak_divisor=2),
    "executioners_iron": stat("attacking", damage_multiplier=1.30, attack_rate_multiplier=0.85),
    "gamblers_lens": stat("attacking", crit_chance_add=0.15, damage_multiplier=0.88),
    "surveyors_glass": stat("attacking", range_add=0.50),
    "copper_windings": stat("lightning", chain_hits_add=1),
    "packed_powder": stat("explosive_arrow", splash_radius_multiplier=1.20, attack_rate_multiplier=0.90),
    "prospectors_diamond": special("prospectors_diamond", production_multiplier=1.20),
    "frostbite_nail": special("frostbite_nail", damage_multiplier=1.20),
    "watchmans_cup": special("watchmans_cup", damage_multiplier=1.25, tiles=2),
    "butchers_apron": special("butchers_apron", damage_multiplier=1.15, hp_fraction=0.50),
    "crystal_sutures": special("crystal_sutures", heal_fraction=0.50),
    "siegecraft_folio": stat("ballista", damage_multiplier=1.20),
    "riveted_gorget": stat("attacking", damage_multiplier=1.18, range_add=-0.25),
    "pepper_roast": stat("attacking", attack_rate_multiplier=1.12),
    "masons_plumb": stat("rune", range_add=0.50),
    "reed_warpipes": stat("drums", support_multiplier=1.15),
    "basilisk_fang": stat("physical", damage_multiplier=1.18),
    "heartwood_cutting": stat("rune", attack_rate_multiplier=1.12),
    "jewelers_torque": stat("attacking", crit_damage_multiplier=1.20),
    "samurai_sword": stat("attacking", damage_multiplier=1.35, attack_rate_multiplier=0.90),
    "philosophers_stone": special("philosophers_stone", event_period=20, bounty_multiplier=5.0, shards=0, rush_seconds=0.0),
    "warlords_gauntlet": stat("attacking", attack_rate_multiplier=1.25),
    "giants_eye": stat("attacking", range_add=0.75),
    "berserkers_crank": stat("projectile", attack_rate_multiplier=1.45, damage_multiplier=0.80, range_add=-0.25),
    "warhide_drumskin": stat("command_banner", support_speed_multiplier=1.25),
    "smith_kings_hammer": stat("forge", support_damage_multiplier=1.25),
    "glacial_chisel": stat("rune", freeze_slow_multiplier=0.70),
    "wormwood_censer": special("wormwood_censer", healing_multiplier=0.50),
    "siege_carpenters_brace": special("siege_carpenters_brace", damage_per_second=0.05, maximum_bonus=0.35),
    "choir_of_empty_helmets": special("choir_of_empty_helmets", radius=2.0, damage_per_identity=0.08, max_identities=4),
    "necromancers_receipt": special("necromancers_receipt", damage_multiplier=1.25, duration=5.0),
    "stormglass_tuning_fork": stat("lightning", chain_range_add=0.50),
    "besiegers_powder_horn": stat("grenade_rocket_arrow", splash_radius_multiplier=1.20, attack_rate_multiplier=0.90),
    "cartographers_field_atlas": stat("attacking", range_add=0.50, damage_multiplier=0.90),
    "trollhide_apron": special("trollhide_apron", duration_multiplier=0.65),
    "moon_salt_jerky": stat("attacking", damage_multiplier=1.15, crit_chance_add=0.05),
    "accountants_abacus": special("accountants_abacus", clear_multiplier=1.25),
    "ironroot_bulb": special("ironroot_bulb", max_health_add=10),
    "falconers_hood": stat("arrow", crit_chance_add=0.10, attack_rate_multiplier=0.90),
    "concucktion": {**stat("attacking", attack_rate_multiplier=1.50), **special("concucktion", targeting_random=1)},
    "monkeys_paw": special("monkeys_paw", max_health_multiplier=0.50, reward_tier=5),
    "ashen_surveyors_chain": stat("attacking", range_add=0.75, attack_rate_multiplier=0.85),
    "volcano_bellows": stat("flamethrower", damage_multiplier=1.35, range_add=-0.25),
    "widows_bone_needle": stat("bloodlust_totem", support_crit_multiplier=1.30),
    "horizon_prism": stat("lookout_horn", support_range_multiplier=1.30),
    "rune_pulse_metronome": stat("pulsed_rune", attack_rate_multiplier=1.30),
    "troll_kings_molar": special("troll_kings_molar", max_health_add=20),
    "thunder_eel_jar": stat("lightning", chain_hits_add=1, damage_multiplier=0.85),
    "obsidian_saddle": stat("orcapult", attack_rate_multiplier=1.25, damage_multiplier=0.85),
    "cinder_cooks_cauldron": stat("molotov", burn_duration_multiplier=1.40),
    "gravebound_ledger": special("gravebound_ledger", mark_multiplier=1.30),
    "bloodglass_hourglass": special("bloodglass_hourglass", duration_multiplier=0.50),
    "fossilized_war_beetle": stat("physical", damage_multiplier=1.35),
    "witchs_folded_ladder": special("witchs_folded_ladder", duration=5.0, cooldown=30.0, range_add=1.0),
    "mimics_lunch_pail": special("mimics_lunch_pail", wait_seconds=10.0, bonus_coins=3),
    "clockwork_raincloud": special("clockwork_raincloud", every=10, stun_duration=0.50),
    "vermilion_war_sash": stat("attacking", crit_damage_multiplier=1.40, crit_chance_add=-0.05),
    "undertakers_spade": special("undertakers_spade", periodic_multiplier=1.35, clear_multiplier=0.85),
    "marrow_longbow": stat("arrow", damage_multiplier=1.40, range_add=-0.25),
    "couriers_basalt_boots": special("couriers_basalt_boots", health_multiplier=1.10, cost_multiplier=1.10),
    "spore_spawn_of_marko": special("spore_spawn_of_marko", initial_quota=1, feed_cost=5, damage_fraction=0.02, duration=4.0, spread_radius=1.50),
    "orc_kings_signet": stat("attacking", damage_multiplier=1.30, attack_rate_multiplier=1.15),
    "titans_heart": stat("attacking", damage_multiplier=1.80, attack_rate_multiplier=0.70),
    "perfect_scope": stat("attacking", range_add=1.0, crit_chance_add=0.10),
    "royal_printing_plate": special("royal_printing_plate", periodic_multiplier=1.50, clear_multiplier=0.80),
    "heartwood_siege_arm": stat("orcapult", lift_classes_add=1),
    "bottomless_quiver": special("bottomless_quiver", every=5, damage_multiplier=0.50),
    "empty_throne": special("empty_throne", damage_multiplier=1.60),
    "worldroot_seed": special("worldroot_seed", damage_per_clear=0.02, damage_cap=0.60),
    "sun_in_a_cage": special("sun_in_a_cage", charge_duration=10.0, burst_multiplier=3.0, radius=1.0, shutdown_duration=3.0),
    "dreadmaws_second_heart": special("dreadmaws_second_heart", reserve_fraction=0.50),
    "empresss_warcoat": stat("attacking", damage_multiplier=1.20, crit_damage_multiplier=1.45),
    "leviathan_anchor": stat("orcapult", throw_distance_add=1.0, attack_rate_multiplier=0.80),
    "stormcallers_crown": stat("lightning", chain_hits_add=2, damage_multiplier=0.80),
    "golden_harvest_sickle": special("golden_harvest_sickle", clear_multiplier=1.50),
    "dragons_breath_decanter": stat("fire", damage_multiplier=1.60, attack_rate_multiplier=0.85),
    "bastion_in_a_bottle": special("bastion_in_a_bottle", duration=6.0, cooldown=60.0, damage_prevent_fraction=0.50, damage_prevent_cap=20.0),
    "minute_hand_cannon": special("minute_hand_cannon", duration=5.0, cooldown=30.0, attack_rate_multiplier=1.75),
    "saints_marrow_flute": stat("bloodlust_totem", support_crit_multiplier=1.50),
    "philosophorers_stone": special("philosophorers_stone", event_period=10, bounty_multiplier=5.0, shards=1, rush_seconds=0.0),
    "the_whole_shebang": special("the_whole_shebang", rate_per_clear=0.01, rate_cap=0.85),
    "gorcs_right_hand": stat("attacking", damage_multiplier=1.60, attack_rate_multiplier=1.40),
    "biggest_wood": stat("physical_ballista", damage_multiplier=2.50, pierce_add=3, attack_rate_multiplier=0.75),
    "forbidden_beat": stat("drums", support_multiplier=2.0),
    "mountains_pocket_change": special("mountains_pocket_change", production_multiplier=2.0, shard_chance=0.10, shards=1),
    "entire_quiver": special("entire_quiver", every=1, damage_multiplier=0.75),
    "one_more_you_git": special("one_more_you_git", health_remaining=1, stun_duration=3.0),
    "the_walking_fortress": special("the_walking_fortress", max_health_add=30, duration=6.0, cooldown=60.0, heal=10),
    "ominous_bells_of_doom": special("ominous_bells_of_doom", wave_step=10, damage_initial=1.10, damage_step=0.10, damage_cap=10.0),
    "philosophorers_stoner": special("philosophorers_stoner", event_period=5, bounty_multiplier=5.0, shards=1, rush_seconds=4.0, overheal_coins_multiplier=1.0),
    "the_whole_shebang_orcfeccion": special("the_whole_shebang_orcfeccion", rate_per_clear=0.01, rate_cap=1.15),
}


def gd_runtime(identity):
    return json.dumps(RUNTIME[identity], ensure_ascii=False, allow_nan=False)


def write_runtime_resources():
    root = Path(__file__).resolve().parents[1] / "resources" / "items"
    for identity in RUNTIME:
        path = root / f"{identity}.tres"
        text = path.read_text(encoding="utf-8")
        runtime = "runtime = " + gd_runtime(identity)
        if re.search(r"^runtime = .*?$", text, flags=re.MULTILINE):
            text = re.sub(r"^runtime = .*?$", lambda _: runtime, text, flags=re.MULTILINE)
        else:
            text = text.rstrip("\n") + "\n" + runtime + "\n"
        path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    write_runtime_resources()
