"""Guide-only Rare gear, with independently drawn native-size pixel portraits."""
from author_items import canvas, portrait, poly, line, rivet, gleam, INK, GOLD, BONE, GREEN, STEEL, PURPLE, RED

TIER = 2

ITEMS = [
    {"id": "executioners_iron", "title": "Executioner's Iron", "effect": "Attacking towers gain 30% damage but lose 15% attack speed.", "mechanics": ["Applies to attacking towers only.", "Damage ×1.30; attack speed ×0.85. Extends no support effect."]},
    {"id": "gamblers_lens", "title": "Gambler's Lens", "effect": "Attacking towers gain 15 percentage points of discrete-hit crit chance but lose 12% damage.", "mechanics": ["Adds 15 percentage points to discrete-hit crit chance, respecting the existing cap.", "Attacker damage ×0.88; continuous damage does not gain critical hits."]},
    {"id": "surveyors_glass", "title": "Surveyor's Glass", "effect": "Attacking towers gain 0.5 tiles of attack range.", "mechanics": ["Adds 0.5 tiles to attack targeting range.", "Does not extend support coverage or Lightning jump distance."]},
    {"id": "copper_windings", "title": "Copper Windings", "effect": "Lightning chains can strike one additional target.", "mechanics": ["Adds one target to each Lightning chain; does not change jump distance.", "Each enemy can still be hit only once per chain; elemental immunity remains."]},
    {"id": "packed_powder", "title": "Packed Powder", "effect": "Explosive Arrow attacks gain 20% blast radius but lose 10% attack speed.", "mechanics": ["Applies only to Arrow's explosive attacks: blast radius ×1.20, attack speed ×0.90.", "Does not enlarge non-explosive attacks or bypass elemental immunity."]},
    {"id": "prospectors_diamond", "title": "Prospector's Diamond", "effect": "Crystal Mines produce 20% more Shards.", "mechanics": ["Crystal Mine Shard production ×1.20; no extra Coins.", "Accumulate fractional Shards until whole; never round each production tick upward."]},
    {"id": "frostbite_nail", "title": "Frostbite Nail", "effect": "Attacking towers deal 20% more damage to slowed enemies.", "mechanics": ["Attacker damage ×1.20 only while the victim is slowed.", "Does not apply slow or bypass elemental immunity."]},
    {"id": "watchmans_cup", "title": "Watchman's Cup", "effect": "Attacking towers deal 25% more damage to enemies on the final two path tiles.", "mechanics": ["Checks the victim's position on its own path's final two tiles.", "Attacker damage ×1.25 there; attack range and targeting rules are unchanged."]},
    {"id": "butchers_apron", "title": "Butcher's Apron", "effect": "Attacking towers deal 15% more damage to enemies below half maximum HP.", "mechanics": ["Checks victim HP before damage: strictly below 50% of maximum HP.", "Attacker damage ×1.15 while eligible; does not bypass elemental immunity."]},
    {"id": "crystal_sutures", "title": "Crystal Sutures", "effect": "If a wave has only one leak, heal half that first leak's damage, rounded down, at wave end.", "mechanics": ["Board effect: record the wave's first leak and require all remaining enemies not to leak.", "On wave completion, heal floor(first leak damage / 2); at most once per wave.", "A later leak cancels the heal; healing never exceeds maximum base HP."]},
    {"id": "siegecraft_folio", "title": "Siegecraft Folio", "effect": "Ballista towers gain 20% damage.", "mechanics": ["Ballista attack damage ×1.20, including its evolved attacks.", "Pierce, bounce counts and elemental immunities are unchanged."]},
    {"id": "riveted_gorget", "title": "Riveted Gorget", "effect": "Attacking towers gain 18% damage but lose 0.25 tiles of attack range.", "mechanics": ["Attacker damage ×1.18; attack range −0.25 tiles within existing range limits.", "Never changes support coverage or Lightning jump distance."]},
    {"id": "pepper_roast", "title": "Pepper Roast", "effect": "Attacking towers gain 12% attack speed.", "mechanics": ["Attacking tower attack speed ×1.12.", "Does not accelerate economy production or support effects."]},
    {"id": "masons_plumb", "title": "Mason's Plumb", "effect": "Rune towers gain 0.5 tiles of attack range.", "mechanics": ["Adds 0.5 tiles to Rune attack range, including evolved Rune attacks.", "Does not affect support coverage, slow strength or elemental immunity."]},
    {"id": "reed_warpipes", "title": "Reed Warpipes", "effect": "War Drums' existing support bonuses become 15% stronger.", "mechanics": ["Multiply only the active branch's existing support stats by 1.15; add no new stat.", "Pure branches stay pure; strongest source per stat still wins globally.", "Coverage stays unchanged and discrete crit chance keeps its existing cap."]},
    {"id": "basilisk_fang", "title": "Basilisk Fang", "effect": "Physical attacking towers gain 18% damage.", "mechanics": ["Damage ×1.18 only for attacks whose resolved element is Physical.", "Adds no poison or elemental conversion; Physical immunity remains."]},
    {"id": "heartwood_cutting", "title": "Heartwood Cutting", "effect": "Rune towers gain 12% attack speed.", "mechanics": ["Rune attack speed ×1.12, including evolved Rune attacks.", "Does not add slow, critical hits or an immunity bypass."]},
    {"id": "jewelers_torque", "title": "Jeweler's Torque", "effect": "Attacking towers' discrete critical hits deal 20% more damage.", "mechanics": ["Damage of an eligible discrete critical hit ×1.20.", "No crit chance increase; existing chance cap and non-critting continuous damage remain."]},
]


def executioners_iron():
    im, d = canvas()
    d.polygon([(8, 4), (18, 3), (27, 7), (26, 19), (19, 23), (10, 20)], fill=STEEL[1], outline=INK)
    d.polygon([(9, 5), (17, 4), (24, 8), (23, 15), (11, 17)], fill=STEEL[2])
    d.polygon([(11, 17), (24, 15), (26, 19), (19, 23), (10, 20)], fill=STEEL[3], outline=INK)
    d.line([(11, 18), (19, 21), (25, 18)], fill=STEEL[4])
    d.ellipse((18, 6, 22, 10), fill=INK)
    d.polygon([(6, 18), (10, 18), (12, 29), (7, 29)], fill=RED[1], outline=INK)
    d.line([(7, 21), (11, 22), (8, 24), (11, 25), (8, 27)], fill=BONE[1])
    d.line([(9, 7), (10, 14)], fill=STEEL[3])
    return im


def executioners_iron_detail():
    im, d = portrait()
    poly(d, [(22, 12), (51, 8), (82, 21), (79, 57), (59, 72), (29, 61)], STEEL[1])
    poly(d, [(26, 16), (49, 12), (76, 24), (72, 44), (31, 53)], STEEL[2], None)
    poly(d, [(30, 53), (72, 44), (79, 57), (59, 72), (29, 61)], STEEL[3])
    line(d, [(32, 57), (58, 67), (76, 55)], STEEL[4], 2)
    d.ellipse((56, 20, 69, 33), fill=INK)
    d.arc((54, 18, 70, 34), 180, 300, fill=STEEL[4], width=2)
    poly(d, [(19, 54), (30, 53), (35, 86), (21, 89), (18, 82)], RED[0])
    poly(d, [(21, 57), (26, 56), (30, 84), (23, 86)], RED[1], None)
    for y in (62, 69, 76, 83):
        line(d, [(20, y), (32, y + 3)], BONE[1], 2)
    line(d, [(29, 20), (31, 43)], STEEL[3], 2)
    line(d, [(42, 28), (46, 30), (42, 36)], STEEL[1])
    line(d, [(56, 48), (59, 52), (57, 57)], STEEL[1])
    rivet(d, 25, 56)
    return im


def gamblers_lens():
    im, d = canvas()
    d.line([(21, 21), (27, 28)], fill=INK, width=6)
    d.line([(21, 21), (27, 28)], fill=GOLD[1], width=3)
    d.ellipse((3, 3, 25, 25), fill=GOLD[1], outline=INK)
    d.ellipse((6, 6, 22, 22), fill="#34535b", outline=INK)
    d.polygon([(8, 9), (15, 7), (20, 12), (18, 19), (10, 20), (7, 15)], fill="#789b97")
    d.polygon([(9, 9), (15, 8), (18, 11), (12, 13), (8, 16)], fill="#d0e8c8")
    d.polygon([(13, 13), (18, 14), (18, 18), (13, 19)], fill=BONE[2], outline=INK)
    d.point((15, 15), fill=INK)
    d.point((17, 17), fill=INK)
    d.line([(5, 9), (8, 5), (15, 4)], fill=GOLD[3])
    return im


def gamblers_lens_detail():
    im, d = portrait()
    line(d, [(65, 65), (81, 85)], INK, 15)
    line(d, [(66, 66), (81, 84)], GOLD[1], 10)
    line(d, [(66, 66), (79, 82)], GOLD[3], 3)
    d.ellipse((9, 8, 75, 74), fill=GOLD[0], outline=INK, width=2)
    d.ellipse((12, 11, 72, 71), fill=GOLD[2], outline=INK, width=2)
    d.ellipse((19, 18, 65, 64), fill="#29454f", outline=INK, width=2)
    poly(d, [(24, 28), (37, 21), (52, 23), (61, 35), (58, 51), (43, 60), (26, 54), (21, 42)], "#759e98", None)
    poly(d, [(25, 28), (37, 23), (50, 25), (38, 36), (23, 44)], "#c2dfc6", None)
    poly(d, [(39, 38), (53, 34), (58, 47), (44, 53), (35, 47)], BONE[2])
    poly(d, [(39, 38), (49, 36), (50, 43), (38, 47), (35, 44)], BONE[3], None)
    for x, y in ((40, 41), (46, 40), (44, 46), (50, 45), (53, 48)):
        d.rectangle((x, y, x + 1, y + 1), fill=INK)
    d.arc((13, 12, 71, 70), 188, 269, fill=GOLD[4], width=3)
    for x, y in ((18, 29), (29, 15), (60, 20), (67, 47), (44, 68), (19, 56)):
        rivet(d, x, y, GOLD)
    line(d, [(30, 53), (35, 55)], "#a3c5b4", 2)
    return im


def surveyors_glass():
    im, d = canvas()
    d.polygon([(4, 20), (9, 14), (23, 7), (28, 12), (13, 22), (8, 26)], fill=GOLD[1], outline=INK)
    d.polygon([(8, 16), (21, 10), (24, 13), (11, 21)], fill=GOLD[3])
    d.polygon([(18, 9), (23, 6), (29, 11), (27, 16), (22, 17), (22, 13)], fill=GOLD[0], outline=INK)
    d.polygon([(24, 8), (28, 11), (26, 14), (23, 12)], fill="#8ab8b2", outline=INK)
    d.line([(24, 9), (26, 10)], fill=STEEL[4])
    d.polygon([(3, 20), (7, 17), (12, 22), (8, 27), (4, 26)], fill=STEEL[1], outline=INK)
    d.line([(5, 20), (9, 23)], fill=STEEL[3])
    d.line([(13, 15), (16, 19)], fill=GOLD[0], width=2)
    return im


def surveyors_glass_detail():
    im, d = portrait()
    poly(d, [(13, 57), (28, 42), (67, 18), (80, 32), (41, 60), (26, 77)], GOLD[1])
    poly(d, [(23, 49), (64, 24), (70, 31), (30, 59)], GOLD[3], None)
    poly(d, [(33, 56), (72, 31), (76, 35), (41, 60), (28, 72)], GOLD[0], None)
    poly(d, [(59, 19), (70, 12), (86, 24), (84, 40), (72, 46), (69, 34)], GOLD[1])
    poly(d, [(72, 17), (82, 25), (80, 36), (72, 39), (69, 29)], "#42656b")
    poly(d, [(73, 20), (79, 25), (77, 30), (71, 33)], "#afd4c5", None)
    line(d, [(73, 21), (78, 25)], STEEL[4], 2)
    poly(d, [(9, 58), (19, 49), (34, 61), (29, 77), (21, 83), (11, 76)], STEEL[0])
    poly(d, [(13, 58), (19, 54), (29, 62), (25, 70), (15, 68)], STEEL[2], None)
    line(d, [(15, 57), (27, 63)], STEEL[4], 2)
    for a, b in (((36, 37), (45, 51)), ((48, 30), (57, 43))):
        line(d, [a, b], GOLD[0], 4)
        line(d, [(a[0] - 1, a[1]), (b[0] - 1, b[1] - 2)], GOLD[4])
    line(d, [(35, 44), (40, 41)], GOLD[4], 2)
    rivet(d, 28, 68)
    return im


def copper_windings():
    im, d = canvas()
    d.rectangle((9, 4, 22, 28), fill=STEEL[0], outline=INK)
    d.polygon([(8, 4), (12, 2), (24, 2), (25, 6), (21, 8), (8, 8)], fill=STEEL[2], outline=INK)
    d.polygon([(8, 25), (22, 24), (25, 27), (22, 30), (8, 29)], fill=STEEL[1], outline=INK)
    for y in (8, 12, 16, 20):
        d.polygon([(7, y + 1), (21, y - 2), (25, y), (24, y + 3), (9, y + 6), (6, y + 4)], fill="#a35a36", outline=INK)
        d.line([(8, y + 1), (21, y - 1), (23, y)], fill="#efb36c")
    d.line([(24, 19), (29, 19), (29, 10), (26, 8)], fill=INK, width=3)
    d.line([(24, 19), (29, 19), (29, 10), (26, 8)], fill="#d18b4b")
    return im


def copper_windings_detail():
    im, d = portrait()
    poly(d, [(28, 13), (62, 10), (69, 76), (32, 84)], STEEL[0])
    poly(d, [(22, 15), (32, 7), (67, 7), (74, 15), (65, 25), (24, 25)], STEEL[2])
    line(d, [(28, 15), (62, 14)], STEEL[4], 2)
    poly(d, [(24, 74), (63, 71), (74, 79), (67, 89), (27, 89), (21, 84)], STEEL[1])
    for y in (25, 37, 49, 61):
        poly(d, [(21, y + 2), (59, y - 5), (71, y), (70, y + 8), (32, y + 15), (20, y + 9)], "#99502f")
        poly(d, [(24, y + 2), (58, y - 3), (65, y), (31, y + 8), (23, y + 7)], "#d88c4c", None)
        line(d, [(25, y + 2), (57, y - 3), (63, y)], "#f3c488", 2)
        line(d, [(33, y + 12), (65, y + 6)], "#6b3b29", 2)
    line(d, [(69, 63), (84, 60), (84, 34), (78, 28)], INK, 7)
    line(d, [(69, 62), (82, 59), (82, 35), (77, 29)], "#d88c4c", 3)
    d.rectangle((73, 23, 80, 30), fill=GOLD[2], outline=INK)
    rivet(d, 31, 18)
    rivet(d, 64, 82)
    return im


def packed_powder():
    im, d = canvas()
    d.polygon([(9, 5), (20, 5), (19, 11), (26, 21), (25, 28), (7, 29), (4, 23), (10, 11)], fill="#705337", outline=INK)
    d.polygon([(11, 12), (17, 11), (22, 21), (21, 26), (9, 27), (7, 22)], fill="#ac8951")
    d.line([(10, 12), (19, 12)], fill=GOLD[3], width=2)
    d.line([(13, 13), (12, 18)], fill="#d3b978")
    d.polygon([(13, 17), (17, 15), (19, 19), (17, 23), (12, 23), (11, 20)], fill=INK)
    d.line([(17, 16), (18, 13), (22, 13), (23, 10)], fill=RED[2])
    d.point((24, 9), fill=GOLD[4])
    d.line([(10, 6), (18, 6)], fill="#d3b978")
    return im


def packed_powder_detail():
    im, d = portrait()
    poly(d, [(29, 14), (56, 12), (60, 19), (54, 31), (74, 57), (78, 76), (69, 87), (24, 87), (15, 74), (20, 54), (33, 30)], "#705337")
    poly(d, [(33, 33), (47, 31), (62, 53), (65, 75), (55, 82), (28, 81), (23, 70), (28, 48)], "#ac8951", None)
    poly(d, [(53, 35), (71, 58), (75, 74), (67, 83), (61, 79), (64, 65)], "#543d2d", None)
    line(d, [(28, 33), (56, 30)], INK, 7)
    line(d, [(28, 32), (55, 29)], GOLD[2], 3)
    line(d, [(38, 32), (37, 43), (30, 48)], GOLD[3], 2)
    line(d, [(44, 31), (50, 40), (56, 44)], GOLD[2], 2)
    poly(d, [(34, 53), (47, 49), (58, 58), (56, 70), (45, 76), (32, 70), (29, 60)], INK)
    line(d, [(49, 51), (53, 43), (63, 43), (66, 37)], RED[2], 3)
    gleam(d, 67, 35, GOLD[4], 3)
    line(d, [(29, 17), (36, 21), (44, 17), (53, 17)], "#d6b67a", 2)
    for x, y in ((23, 60), (29, 77), (63, 59), (57, 80)):
        line(d, [(x, y), (x + 3, y - 1)], "#c9a565")
    return im


def prospectors_diamond():
    im, d = canvas()
    d.polygon([(5, 24), (10, 18), (24, 18), (28, 24), (24, 29), (8, 28)], fill="#5d594b", outline=INK)
    d.polygon([(8, 22), (13, 19), (22, 21), (24, 26), (13, 26)], fill="#8d8870")
    d.polygon([(10, 10), (16, 4), (24, 9), (26, 15), (17, 24), (8, 16)], fill="#5d9db4", outline=INK)
    d.polygon([(10, 10), (16, 5), (18, 12), (9, 15)], fill="#d9f2dd")
    d.polygon([(18, 12), (23, 10), (25, 15), (17, 23)], fill="#46758f")
    d.polygon([(10, 16), (18, 12), (17, 22)], fill="#9cdbc9")
    d.line([(11, 10), (18, 12), (23, 10)], fill="#eef9df")
    d.point((8, 25), fill=GOLD[2])
    return im


def prospectors_diamond_detail():
    im, d = portrait()
    poly(d, [(12, 71), (28, 54), (66, 53), (82, 69), (78, 85), (56, 91), (22, 87)], "#57574b")
    poly(d, [(15, 71), (31, 59), (51, 63), (67, 58), (76, 70), (59, 80), (28, 79)], "#93917a", None)
    poly(d, [(28, 31), (47, 12), (69, 24), (77, 43), (49, 76), (21, 46)], "#5d9db4")
    poly(d, [(28, 31), (47, 13), (50, 36), (22, 45)], "#d5eedb", None)
    poly(d, [(50, 36), (69, 25), (76, 43), (49, 75)], "#46758f", None)
    poly(d, [(23, 46), (50, 36), (49, 74)], "#91d4c7", None)
    poly(d, [(47, 14), (67, 25), (50, 35)], "#a7e4dc", None)
    line(d, [(28, 31), (50, 36), (69, 25)], "#f0ffe8", 2)
    line(d, [(50, 36), (49, 70)], "#c5f4dd", 2)
    line(d, [(34, 31), (42, 23)], "#ffffff", 2)
    line(d, [(27, 78), (37, 73), (39, 82)], "#56574b", 2)
    for x, y in ((21, 75), (69, 75), (58, 84)):
        d.rectangle((x, y, x + 3, y + 2), fill=GOLD[2])
        d.point((x, y), fill=GOLD[4])
    return im


def frostbite_nail():
    im, d = canvas()
    d.polygon([(11, 6), (18, 6), (21, 11), (16, 28), (13, 30), (12, 13)], fill=STEEL[1], outline=INK)
    d.polygon([(13, 11), (17, 11), (15, 26), (14, 28)], fill=STEEL[3])
    d.polygon([(7, 5), (12, 2), (21, 4), (23, 8), (18, 11), (9, 9)], fill=STEEL[2], outline=INK)
    d.line([(10, 5), (18, 5), (20, 7)], fill=STEEL[4])
    d.polygon([(10, 12), (6, 16), (10, 17), (8, 22), (13, 20), (16, 14), (21, 17), (23, 12), (18, 9)], fill="#84c9d2", outline="#3b6f86")
    d.line([(10, 13), (13, 17), (17, 11), (20, 13)], fill="#daf6e9")
    return im


def frostbite_nail_detail():
    im, d = portrait()
    poly(d, [(37, 21), (54, 23), (61, 34), (47, 80), (39, 89), (34, 38)], STEEL[1])
    poly(d, [(40, 31), (51, 32), (45, 76), (40, 83)], STEEL[3], None)
    poly(d, [(23, 16), (35, 7), (61, 12), (70, 25), (57, 34), (29, 28)], STEEL[2])
    poly(d, [(29, 16), (37, 11), (59, 15), (63, 21), (41, 20)], STEEL[3], None)
    line(d, [(30, 16), (38, 12), (58, 16)], STEEL[4], 2)
    poly(d, [(32, 35), (18, 45), (27, 50), (20, 66), (34, 60), (41, 44), (49, 49), (60, 38), (70, 53), (76, 37), (58, 26), (49, 33)], "#689eb6")
    poly(d, [(31, 39), (24, 45), (33, 47), (26, 60), (36, 51), (42, 38)], "#bce9e2", None)
    poly(d, [(51, 35), (59, 31), (69, 39), (69, 46), (60, 36), (52, 43)], "#a6dcd9", None)
    line(d, [(27, 44), (35, 46), (40, 37)], "#effff0", 2)
    line(d, [(53, 35), (60, 31), (69, 38)], "#effff0", 2)
    line(d, [(42, 62), (44, 55)], STEEL[4], 2)
    d.rectangle((24, 31, 27, 34), fill="#bce9e2")
    return im


def watchmans_cup():
    im, d = canvas()
    d.ellipse((20, 10, 29, 23), fill=GOLD[1], outline=INK)
    d.ellipse((22, 13, 26, 20), fill=(0, 0, 0, 0))
    d.polygon([(5, 8), (23, 8), (22, 23), (19, 27), (9, 27), (6, 23)], fill=STEEL[1], outline=INK)
    d.polygon([(7, 11), (12, 12), (13, 24), (9, 24), (8, 21)], fill=STEEL[3])
    d.ellipse((5, 5, 23, 12), fill=GOLD[2], outline=INK)
    d.ellipse((8, 7, 20, 10), fill="#3d3429")
    d.rectangle((15, 16, 18, 22), fill=GOLD[2], outline=INK)
    d.rectangle((12, 19, 15, 22), fill=GOLD[2], outline=INK)
    d.line([(8, 26), (20, 26)], fill=GOLD[3])
    return im


def watchmans_cup_detail():
    im, d = portrait()
    d.ellipse((59, 28, 87, 69), fill=GOLD[1], outline=INK, width=2)
    d.ellipse((66, 35, 79, 60), fill=(0, 0, 0, 0))
    poly(d, [(17, 24), (69, 24), (65, 68), (57, 81), (30, 82), (21, 70)], STEEL[1])
    poly(d, [(23, 34), (34, 37), (38, 74), (30, 74), (26, 65)], STEEL[3], None)
    poly(d, [(58, 36), (65, 32), (61, 66), (54, 76), (51, 66)], STEEL[0], None)
    d.ellipse((17, 15, 69, 36), fill=GOLD[2], outline=INK, width=2)
    d.ellipse((23, 20, 63, 30), fill="#3d3429", outline=GOLD[0])
    line(d, [(24, 20), (38, 18), (55, 20)], GOLD[4], 2)
    poly(d, [(39, 57), (47, 57), (47, 48), (56, 48), (56, 66), (39, 66)], GOLD[2])
    line(d, [(40, 58), (47, 58), (47, 50), (54, 50)], GOLD[4])
    line(d, [(28, 78), (58, 77)], GOLD[3], 3)
    rivet(d, 66, 39, GOLD)
    rivet(d, 62, 67, GOLD)
    line(d, [(28, 44), (30, 55)], STEEL[4], 2)
    line(d, [(36, 72), (40, 73)], STEEL[2], 2)
    return im


def butchers_apron():
    im, d = canvas()
    d.line([(11, 10), (11, 3), (20, 3), (21, 10)], fill=INK, width=3)
    d.line([(11, 10), (11, 4), (19, 4), (21, 10)], fill="#bead7c")
    d.polygon([(9, 9), (22, 9), (21, 15), (26, 28), (6, 29), (10, 16)], fill="#b6a87d", outline=INK)
    d.polygon([(11, 11), (17, 11), (17, 26), (9, 27), (12, 17)], fill="#ded2a3")
    d.rectangle((12, 18, 20, 24), fill="#92845f", outline=INK)
    d.line([(13, 19), (19, 19)], fill=BONE[3])
    d.polygon([(20, 14), (23, 18), (21, 20), (19, 17)], fill=RED[1])
    d.line([(9, 26), (11, 27), (13, 26)], fill=RED[2])
    return im


def butchers_apron_detail():
    im, d = portrait()
    line(d, [(32, 30), (33, 10), (56, 9), (63, 30)], INK, 8)
    line(d, [(32, 29), (35, 13), (54, 12), (60, 29)], "#b3a075", 4)
    poly(d, [(27, 28), (65, 28), (62, 46), (78, 83), (19, 88), (29, 49)], "#b6a87d")
    poly(d, [(32, 33), (46, 32), (46, 78), (26, 82), (34, 48)], "#ded2a3", None)
    poly(d, [(58, 35), (61, 49), (73, 79), (61, 80), (52, 58)], "#8b7b57", None)
    poly(d, [(34, 55), (58, 53), (59, 72), (36, 75)], "#a29368")
    line(d, [(36, 57), (56, 55)], BONE[3], 2)
    line(d, [(38, 61), (39, 70)], "#cdbd8d")
    line(d, [(24, 84), (70, 80)], "#786b50", 2)
    for x, y in ((29, 76), (34, 78), (59, 42), (63, 46), (53, 67)):
        poly(d, [(x, y), (x + 4, y - 1), (x + 6, y + 4), (x + 2, y + 5)], RED[1], None)
    line(d, [(27, 44), (19, 47), (13, 43)], "#b3a075", 3)
    line(d, [(63, 44), (76, 47), (83, 43)], "#8b7b57", 3)
    rivet(d, 33, 30, GOLD)
    rivet(d, 60, 30, GOLD)
    return im


def crystal_sutures():
    im, d = canvas()
    d.polygon([(5, 11), (12, 6), (19, 10), (19, 18), (12, 25), (5, 19)], fill="#448897", outline=INK)
    d.polygon([(7, 11), (12, 8), (13, 16), (7, 18)], fill="#b8e8d4")
    d.polygon([(14, 12), (18, 11), (17, 18), (13, 22)], fill="#75baba")
    d.line([(11, 9), (14, 13), (11, 17), (14, 21)], fill=INK)
    for y in (12, 16, 20):
        d.line([(9, y + 1), (15, y - 1)], fill=BONE[3])
    d.line([(16, 18), (23, 25), (28, 21), (27, 14)], fill=PURPLE[2])
    d.line([(25, 7), (23, 19)], fill=INK, width=3)
    d.line([(25, 7), (23, 19)], fill=STEEL[3])
    d.point((25, 9), fill=INK)
    return im


def crystal_sutures_detail():
    im, d = portrait()
    poly(d, [(15, 30), (37, 14), (60, 26), (62, 53), (38, 77), (15, 58)], "#448897")
    poly(d, [(19, 31), (35, 20), (39, 46), (20, 56)], "#b8e8d4", None)
    poly(d, [(42, 44), (57, 29), (58, 52), (39, 71)], "#75baba", None)
    line(d, [(36, 20), (43, 34), (35, 48), (43, 60), (37, 70)], INK, 3)
    for x, y in ((35, 31), (34, 44), (35, 57), (34, 66)):
        line(d, [(x - 7, y + 3), (x + 11, y - 3)], "#53736d", 4)
        line(d, [(x - 7, y + 1), (x + 10, y - 4)], BONE[3], 2)
    line(d, [(45, 59), (60, 77), (75, 81), (84, 71), (84, 59), (76, 52)], PURPLE[1], 4)
    line(d, [(45, 58), (61, 75), (75, 78), (81, 70), (81, 60), (75, 54)], PURPLE[3], 2)
    poly(d, [(73, 19), (78, 17), (76, 44), (68, 66), (69, 43)], STEEL[2])
    line(d, [(74, 25), (72, 43), (69, 57)], STEEL[4], 2)
    d.ellipse((73, 21, 75, 27), fill=INK)
    line(d, [(23, 30), (30, 25)], "#efffed", 2)
    return im


def siegecraft_folio():
    im, d = canvas()
    d.polygon([(6, 7), (23, 3), (27, 7), (27, 25), (10, 29), (5, 25)], fill="#503e36", outline=INK)
    d.polygon([(9, 9), (24, 6), (24, 24), (10, 27)], fill=BONE[2], outline=INK)
    d.polygon([(5, 7), (21, 3), (24, 6), (9, 10), (9, 27), (5, 25)], fill="#75524a", outline=INK)
    d.polygon([(10, 10), (23, 7), (23, 23), (10, 26)], fill="#476253", outline=INK)
    d.line([(12, 20), (21, 14), (18, 12), (16, 22)], fill=GOLD[3])
    d.line([(12, 15), (21, 19)], fill=BONE[3])
    d.rectangle((22, 15, 27, 18), fill=GOLD[2], outline=INK)
    return im


def siegecraft_folio_detail():
    im, d = portrait()
    poly(d, [(17, 22), (65, 10), (79, 22), (79, 77), (30, 90), (16, 79)], "#503e36")
    poly(d, [(29, 28), (74, 17), (74, 74), (30, 85)], BONE[2])
    for y in (37, 46, 55, 64, 73, 81):
        line(d, [(32, y), (72, y - 9)], "#a79971")
    poly(d, [(16, 22), (62, 10), (71, 17), (29, 29), (29, 86), (16, 79)], "#75524a")
    poly(d, [(29, 29), (72, 18), (72, 71), (30, 84)], "#476253")
    poly(d, [(35, 34), (66, 26), (66, 66), (35, 75)], "#354c40", None)
    line(d, [(38, 58), (61, 43), (54, 38), (47, 65)], GOLD[3], 3)
    line(d, [(37, 45), (62, 58)], BONE[3], 2)
    line(d, [(42, 60), (57, 56)], GOLD[1], 2)
    for y in (31, 47, 64, 76):
        line(d, [(19, y), (26, y + 3)], "#af7863", 3)
    poly(d, [(67, 44), (80, 42), (80, 52), (67, 55)], GOLD[2])
    rivet(d, 73, 48, GOLD)
    line(d, [(34, 32), (64, 24)], "#93a181", 2)
    return im


def riveted_gorget():
    im, d = canvas()
    d.polygon([(4, 9), (10, 4), (21, 4), (28, 10), (25, 22), (17, 29), (7, 24)], fill=STEEL[1], outline=INK)
    d.ellipse((8, 4, 24, 16), fill=INK)
    d.arc((8, 4, 24, 16), 5, 175, fill=STEEL[3], width=3)
    d.polygon([(6, 13), (13, 18), (17, 26), (9, 22)], fill=STEEL[3])
    d.polygon([(14, 18), (24, 14), (23, 21), (17, 27)], fill=STEEL[2])
    for x, y in ((7, 12), (10, 21), (18, 24), (24, 13)):
        d.point((x, y), fill=GOLD[3])
    d.line([(7, 16), (12, 19)], fill=STEEL[4])
    return im


def riveted_gorget_detail():
    im, d = portrait()
    poly(d, [(12, 28), (29, 13), (60, 11), (82, 28), (75, 64), (52, 86), (24, 71)], STEEL[1])
    d.ellipse((26, 13, 67, 44), fill=INK)
    d.arc((25, 12, 68, 45), 4, 176, fill=STEEL[3], width=7)
    d.arc((28, 16, 65, 42), 5, 175, fill=STEEL[0], width=3)
    poly(d, [(18, 37), (33, 47), (48, 78), (27, 66)], STEEL[3], None)
    poly(d, [(36, 48), (73, 37), (68, 61), (51, 79)], STEEL[2], None)
    poly(d, [(60, 53), (76, 38), (72, 61), (54, 80)], STEEL[0], None)
    line(d, [(16, 33), (34, 47), (51, 81), (72, 61), (78, 33)], GOLD[1], 3)
    line(d, [(20, 42), (29, 48)], STEEL[4], 2)
    line(d, [(37, 53), (43, 66)], STEEL[4], 2)
    for x, y in ((18, 32), (29, 46), (39, 62), (50, 78), (66, 61), (76, 33)):
        rivet(d, x, y, GOLD)
    line(d, [(48, 51), (53, 48), (57, 51)], STEEL[1], 2)
    return im


def pepper_roast():
    im, d = canvas()
    d.polygon([(5, 23), (8, 19), (24, 19), (29, 24), (25, 28), (9, 28)], fill="#756747", outline=INK)
    d.polygon([(6, 16), (8, 9), (14, 6), (22, 9), (24, 17), (20, 23), (11, 23)], fill="#86432e", outline=INK)
    d.polygon([(8, 14), (11, 9), (17, 9), (20, 13), (17, 18), (10, 18)], fill="#c77a44")
    d.line([(11, 11), (13, 14), (12, 17)], fill="#f0b16d")
    d.line([(17, 11), (18, 14)], fill="#60382c")
    d.polygon([(21, 20), (24, 16), (27, 10), (29, 11), (28, 18), (24, 23)], fill=RED[2], outline=INK)
    d.line([(27, 10), (26, 7), (24, 7)], fill=GREEN[2])
    d.point((11, 20), fill=INK)
    d.point((18, 16), fill=INK)
    return im


def pepper_roast_detail():
    im, d = portrait()
    poly(d, [(10, 69), (24, 55), (70, 55), (86, 72), (77, 84), (29, 87)], "#756747")
    poly(d, [(16, 69), (28, 61), (68, 61), (79, 72), (72, 79), (30, 81)], "#c3b07c", None)
    poly(d, [(17, 47), (23, 28), (40, 17), (59, 22), (70, 40), (67, 59), (55, 72), (29, 71), (18, 61)], "#86432e")
    poly(d, [(22, 44), (29, 30), (41, 23), (56, 28), (62, 40), (51, 53), (29, 56)], "#c77a44", None)
    poly(d, [(24, 57), (43, 60), (61, 49), (62, 59), (52, 67), (31, 66)], "#a65d36", None)
    for x, y in ((31, 34), (43, 29), (54, 34)):
        line(d, [(x, y), (x + 5, y + 8), (x + 2, y + 16)], "#69372b", 3)
        line(d, [(x - 2, y), (x + 2, y + 7)], "#f0b16d", 2)
    poly(d, [(60, 71), (69, 58), (78, 39), (84, 43), (82, 61), (73, 74), (65, 77)], RED[1])
    poly(d, [(69, 65), (79, 43), (81, 46), (76, 63), (68, 72)], RED[3], None)
    line(d, [(80, 40), (78, 31), (71, 29)], GREEN[2], 3)
    for x, y in ((28, 56), (42, 52), (56, 46), (47, 64), (35, 45)):
        d.rectangle((x, y, x + 1, y + 1), fill=INK)
    line(d, [(30, 77), (48, 76)], "#eed6a1", 2)
    return im


def masons_plumb():
    im, d = canvas()
    d.line([(16, 3), (16, 17)], fill=BONE[2])
    d.line([(16, 3), (23, 3), (26, 7), (23, 10), (19, 8), (20, 5)], fill=INK, width=3)
    d.line([(16, 3), (23, 3), (25, 7), (23, 9), (20, 8), (20, 5)], fill=BONE[2])
    d.polygon([(11, 14), (20, 14), (24, 21), (16, 30), (8, 21)], fill=GOLD[1], outline=INK)
    d.polygon([(12, 16), (16, 16), (16, 28), (10, 21)], fill=GOLD[3])
    d.polygon([(17, 16), (20, 16), (22, 21), (17, 27)], fill=GOLD[0])
    d.line([(11, 20), (16, 18), (21, 20)], fill=GOLD[4])
    return im


def masons_plumb_detail():
    im, d = portrait()
    line(d, [(46, 11), (46, 44)], BONE[1], 3)
    line(d, [(45, 11), (45, 44)], BONE[3])
    line(d, [(47, 11), (68, 10), (79, 19), (77, 29), (66, 33), (58, 28), (59, 21), (65, 18), (69, 21)], INK, 6)
    line(d, [(47, 10), (68, 9), (78, 18), (76, 28), (66, 31), (60, 27), (60, 22), (65, 20), (68, 22)], BONE[2], 3)
    poly(d, [(34, 42), (58, 42), (70, 61), (46, 88), (22, 61)], GOLD[1])
    poly(d, [(35, 45), (45, 45), (45, 83), (27, 61)], GOLD[3], None)
    poly(d, [(48, 45), (57, 45), (66, 61), (49, 81)], GOLD[0], None)
    line(d, [(26, 60), (46, 51), (67, 60)], GOLD[4], 2)
    line(d, [(46, 52), (46, 84)], GOLD[2], 2)
    d.rectangle((39, 37, 53, 44), fill=STEEL[1], outline=INK, width=2)
    d.rectangle((42, 38, 49, 40), fill=STEEL[3])
    line(d, [(31, 62), (36, 64)], GOLD[4], 2)
    line(d, [(55, 58), (60, 60)], GOLD[1], 2)
    return im


def reed_warpipes():
    im, d = canvas()
    d.polygon([(6, 14), (12, 10), (24, 15), (25, 25), (18, 29), (7, 25)], fill=GREEN[1], outline=INK)
    d.polygon([(8, 15), (13, 13), (20, 16), (19, 24), (9, 23)], fill=GREEN[2])
    for x, y in ((10, 3), (17, 5), (24, 8)):
        d.rectangle((x - 2, y, x + 1, 19), fill="#996c3b", outline=INK)
        d.line([(x - 1, y + 1), (x - 1, 17)], fill="#dfbf7d")
        d.line([(x - 2, y + 4), (x + 1, y + 4)], fill=GOLD[1])
    d.polygon([(9, 23), (14, 22), (14, 28), (12, 30), (9, 29)], fill="#996c3b", outline=INK)
    d.line([(7, 21), (22, 24)], fill=BONE[2])
    return im


def reed_warpipes_detail():
    im, d = portrait()
    poly(d, [(15, 46), (32, 33), (66, 42), (77, 61), (68, 79), (48, 86), (20, 74)], GREEN[1])
    poly(d, [(21, 47), (34, 39), (53, 45), (58, 68), (45, 77), (23, 68)], GREEN[2], None)
    poly(d, [(57, 46), (66, 47), (72, 61), (64, 74), (53, 79), (59, 64)], GREEN[0], None)
    for x, y, end in ((28, 9, 53), (48, 15, 60), (69, 24, 62)):
        poly(d, [(x - 5, y), (x + 4, y), (x + 2, end), (x - 5, end + 3)], "#996c3b")
        line(d, [(x - 2, y + 2), (x - 3, end - 2)], "#dfbf7d", 3)
        for band in (y + 8, end - 8):
            d.rectangle((x - 5, band, x + 3, band + 3), fill=GOLD[1], outline=INK)
        d.rectangle((x - 6, y - 2, x + 4, y + 3), fill=BONE[2], outline=INK)
        for hole in (y + 15, y + 23):
            d.rectangle((x, hole, x + 1, hole + 2), fill=INK)
    poly(d, [(29, 72), (43, 72), (42, 85), (36, 91), (29, 86)], "#996c3b")
    line(d, [(32, 75), (32, 85)], "#dfbf7d", 2)
    line(d, [(18, 64), (33, 68), (50, 67), (68, 72)], BONE[2], 3)
    line(d, [(23, 52), (26, 59)], GREEN[3], 2)
    return im


def basilisk_fang():
    im, d = canvas()
    d.polygon([(6, 5), (13, 3), (22, 8), (25, 15), (23, 22), (17, 27), (8, 29), (13, 23), (16, 17), (14, 12), (8, 11)], fill=BONE[1], outline=INK)
    d.polygon([(8, 5), (13, 5), (19, 9), (22, 15), (20, 21), (14, 25), (18, 18), (16, 11), (9, 9)], fill=BONE[3])
    d.polygon([(5, 6), (8, 3), (13, 4), (14, 8), (10, 13), (5, 11)], fill=GREEN[1], outline=INK)
    d.line([(6, 6), (10, 5), (12, 7)], fill=GREEN[3])
    d.line([(18, 10), (20, 14)], fill=BONE[2])
    d.point((8, 8), fill=GOLD[3])
    return im


def basilisk_fang_detail():
    im, d = portrait()
    poly(d, [(18, 18), (36, 11), (59, 22), (73, 40), (74, 57), (62, 73), (43, 85), (21, 88), (40, 74), (48, 58), (47, 45), (37, 33), (21, 33)], BONE[1])
    poly(d, [(24, 19), (36, 16), (55, 25), (66, 42), (67, 55), (58, 68), (39, 81), (51, 61), (53, 45), (40, 28), (24, 29)], BONE[3], None)
    poly(d, [(61, 32), (69, 43), (70, 57), (59, 71), (48, 77), (61, 60), (63, 46)], BONE[2], None)
    poly(d, [(13, 20), (21, 10), (35, 12), (40, 23), (29, 38), (15, 34)], GREEN[1])
    for points in (
        [(17, 21), (23, 15), (29, 18), (24, 24)],
        [(25, 27), (31, 20), (35, 23), (29, 31)],
        [(17, 28), (22, 25), (23, 31), (18, 32)],
    ):
        poly(d, points, GREEN[2], None)
    line(d, [(20, 17), (25, 14), (31, 16)], GREEN[3], 2)
    line(d, [(54, 29), (61, 40)], "#fff2c9", 2)
    line(d, [(57, 51), (58, 58), (54, 65)], BONE[1], 2)
    d.rectangle((24, 24, 27, 26), fill=GOLD[2])
    return im


def heartwood_cutting():
    im, d = canvas()
    d.polygon([(8, 9), (15, 5), (24, 8), (25, 18), (20, 26), (14, 29), (13, 23), (6, 25), (10, 18)], fill="#745338", outline=INK)
    d.polygon([(11, 10), (16, 8), (20, 10), (18, 23), (15, 25), (15, 18), (11, 20)], fill="#b88a50")
    d.ellipse((8, 5, 24, 13), fill="#d8bd7e", outline=INK)
    d.ellipse((12, 7, 20, 11), fill="#8e6541")
    d.line([(14, 8), (18, 9)], fill="#e8d39a")
    d.line([(20, 10), (24, 5)], fill=GREEN[1], width=2)
    d.polygon([(22, 6), (23, 2), (28, 2), (27, 6)], fill=GREEN[2], outline=INK)
    d.line([(9, 23), (6, 28)], fill="#745338", width=2)
    return im


def heartwood_cutting_detail():
    im, d = portrait()
    poly(d, [(25, 28), (44, 17), (67, 25), (71, 50), (63, 69), (46, 87), (40, 72), (22, 79), (28, 58), (18, 52)], "#745338")
    poly(d, [(30, 35), (43, 28), (53, 33), (50, 61), (44, 76), (41, 61), (28, 69), (34, 50)], "#b88a50", None)
    poly(d, [(60, 35), (67, 31), (67, 51), (59, 69), (49, 80), (56, 59)], "#4b3b2e", None)
    d.ellipse((24, 16, 69, 39), fill="#d8bd7e", outline=INK, width=2)
    d.ellipse((31, 20, 62, 34), fill="#a57c4d", outline="#745338", width=2)
    d.ellipse((39, 23, 55, 31), fill="#d8bd7e", outline="#745338")
    line(d, [(43, 26), (49, 28)], "#f4deaa", 2)
    line(d, [(34, 42), (39, 48), (35, 58)], "#e1b576", 2)
    line(d, [(57, 42), (55, 50), (58, 55)], "#372e28", 2)
    line(d, [(60, 31), (71, 17), (72, 9)], GREEN[1], 4)
    poly(d, [(68, 20), (61, 14), (61, 7), (70, 9), (73, 15)], GREEN[2])
    poly(d, [(72, 13), (78, 6), (87, 7), (84, 17), (75, 21)], GREEN[2])
    line(d, [(76, 15), (83, 9)], GREEN[3], 2)
    line(d, [(28, 70), (19, 82), (12, 84)], "#745338", 4)
    line(d, [(29, 69), (21, 80)], "#b88a50", 2)
    return im


def jewelers_torque():
    im, d = canvas()
    d.arc((4, 3, 28, 29), 30, 153, fill=INK, width=6)
    d.arc((4, 3, 28, 29), 30, 153, fill=GOLD[2], width=4)
    d.arc((6, 5, 26, 27), 35, 148, fill=GOLD[4], width=1)
    d.polygon([(4, 17), (9, 15), (13, 19), (11, 24), (6, 24), (3, 21)], fill=GOLD[1], outline=INK)
    d.polygon([(20, 19), (24, 15), (29, 17), (30, 21), (27, 25), (22, 24)], fill=GOLD[1], outline=INK)
    d.polygon([(5, 19), (8, 17), (11, 19), (9, 22), (6, 22)], fill=PURPLE[3], outline=PURPLE[0])
    d.polygon([(23, 19), (25, 17), (28, 19), (26, 23), (23, 22)], fill=PURPLE[2], outline=PURPLE[0])
    d.point((7, 18), fill=PURPLE[4])
    return im


def jewelers_torque_detail():
    im, d = portrait()
    d.arc((12, 9, 84, 83), 28, 153, fill=INK, width=16)
    d.arc((12, 9, 84, 83), 28, 153, fill=GOLD[1], width=12)
    d.arc((14, 11, 82, 81), 30, 152, fill=GOLD[3], width=6)
    d.arc((16, 13, 80, 79), 33, 149, fill=GOLD[4], width=2)
    poly(d, [(11, 52), (23, 45), (37, 56), (34, 72), (20, 77), (9, 66)], GOLD[1])
    poly(d, [(60, 56), (72, 45), (86, 52), (89, 67), (77, 77), (63, 72)], GOLD[1])
    poly(d, [(15, 56), (23, 50), (31, 57), (29, 67), (20, 70), (14, 64)], PURPLE[2])
    poly(d, [(15, 56), (23, 51), (23, 60), (15, 63)], PURPLE[4], None)
    poly(d, [(23, 60), (30, 57), (28, 66), (21, 69)], PURPLE[1], None)
    poly(d, [(65, 57), (73, 50), (82, 56), (83, 65), (76, 70), (67, 66)], PURPLE[2])
    poly(d, [(66, 57), (73, 52), (76, 59), (68, 64)], PURPLE[3], None)
    line(d, [(17, 55), (23, 51), (28, 55)], PURPLE[4], 2)
    for x, y in ((12, 56), (32, 58), (20, 73), (64, 59), (85, 57), (77, 73)):
        rivet(d, x, y, GOLD)
    for a, b in (((32, 77), (35, 72)), ((44, 80), (46, 74)), ((56, 79), (55, 73)), ((66, 75), (63, 70))):
        line(d, [a, b], GOLD[0], 2)
    return im


RENDERERS = {
    "executioners_iron": (executioners_iron, executioners_iron_detail),
    "gamblers_lens": (gamblers_lens, gamblers_lens_detail),
    "surveyors_glass": (surveyors_glass, surveyors_glass_detail),
    "copper_windings": (copper_windings, copper_windings_detail),
    "packed_powder": (packed_powder, packed_powder_detail),
    "prospectors_diamond": (prospectors_diamond, prospectors_diamond_detail),
    "frostbite_nail": (frostbite_nail, frostbite_nail_detail),
    "watchmans_cup": (watchmans_cup, watchmans_cup_detail),
    "butchers_apron": (butchers_apron, butchers_apron_detail),
    "crystal_sutures": (crystal_sutures, crystal_sutures_detail),
    "siegecraft_folio": (siegecraft_folio, siegecraft_folio_detail),
    "riveted_gorget": (riveted_gorget, riveted_gorget_detail),
    "pepper_roast": (pepper_roast, pepper_roast_detail),
    "masons_plumb": (masons_plumb, masons_plumb_detail),
    "reed_warpipes": (reed_warpipes, reed_warpipes_detail),
    "basilisk_fang": (basilisk_fang, basilisk_fang_detail),
    "heartwood_cutting": (heartwood_cutting, heartwood_cutting_detail),
    "jewelers_torque": (jewelers_torque, jewelers_torque_detail),
}
