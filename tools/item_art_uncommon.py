"""Guide-only Uncommon equipment, with independent native-size pixel drawings."""

from author_items import canvas, portrait, poly, line, rivet, gleam, INK, GOLD, BONE, GREEN, STEEL, PURPLE, RED

TIER = 1

ITEMS = [
    {
        "id": "steel_arrowhead", "title": "Steel Arrowhead",
        "effect": "All attacking towers deal +10% damage.",
        "mechanics": ["Applies to every attacking tower's damage.", "Does not add an attack to support or economy towers."],
    },
    {
        "id": "balanced_mechanism", "title": "Balanced Mechanism",
        "effect": "All attacking towers gain +6% damage and +6% attack speed.",
        "mechanics": ["Both bonuses apply to attacking towers.", "Support strength and production cadence are unchanged."],
    },
    {
        "id": "lucky_fang", "title": "Lucky Fang",
        "effect": "Attacking towers gain +3 percentage points of critical chance on discrete hits.",
        "mechanics": ["Only discrete damage hits can critically strike.", "The existing critical-chance cap still applies."],
    },
    {
        "id": "siege_scope", "title": "Siege Scope",
        "effect": "Attacking towers gain +0.5 attack range but lose 8% attack speed.",
        "mechanics": ["Changes attacking towers' targeting range and attack speed.", "Does not extend any support coverage."],
    },
    {
        "id": "lightweight_ammunition", "title": "Lightweight Ammunition",
        "effect": "Attacking towers gain +18% attack speed but deal 10% less damage.",
        "mechanics": ["Both modifiers apply to all attacking towers.", "Does not change support or economy output."],
    },
    {
        "id": "heavy_bolts", "title": "Heavy Bolts",
        "effect": "Physical Ballista attacks deal +25% damage but have 10% less attack speed.",
        "mechanics": ["Only physical Ballista branches receive these modifiers.", "Elemental Ballista branches are unaffected."],
    },
    {
        "id": "resonant_drumsticks", "title": "Resonant Drumsticks",
        "effect": "Drums gain +12% retained support strength without changing coverage or stacking rules.",
        "mechanics": ["Strengthens only support stats retained by the Drums' pure branch.", "Coverage is unchanged; only the strongest global bonus per stat applies."],
    },
    {
        "id": "oversized_bucket", "title": "Oversized Bucket",
        "effect": "Orcapult throws one additional member per throw, but reload duration increases by 20%.",
        "mechanics": ["Adds exactly one member to each Orcapult throw.", "The full reload duration is multiplied by 1.20."],
    },
    {
        "id": "trollhide_earplugs", "title": "Trollhide Earplugs",
        "effect": "All towers suffer received stuns for 20% less time.",
        "mechanics": ["Multiplies stun durations received by towers by 0.80.", "Does not alter stuns inflicted on enemies."],
    },
    {
        "id": "gravediggers_lantern", "title": "Gravedigger's Lantern",
        "effect": "Attacking towers deal +25% damage against summoned enemies.",
        "mechanics": ["The target must be a summoned enemy.", "Damage against other enemies is unchanged."],
    },
    {
        "id": "peppercorn_skewer", "title": "Peppercorn Skewer",
        "effect": "All attacking towers gain +8% attack speed.",
        "mechanics": ["Applies to attacking towers only.", "Does not accelerate support or gold production."],
    },
    {
        "id": "surveyors_fieldbook", "title": "Surveyor's Fieldbook",
        "effect": "Attacking towers gain +0.3 attack range but deal 5% less damage.",
        "mechanics": ["The range bonus affects attack targeting only.", "Support coverage is unchanged."],
    },
    {
        "id": "riveted_bracer", "title": "Riveted Bracer",
        "effect": "Physical attacking towers deal +15% damage but lose 8% attack speed.",
        "mechanics": ["Applies only to attacks dealing physical damage.", "Elemental attacks and support output are unchanged."],
    },
    {
        "id": "copper_winding", "title": "Copper Winding",
        "effect": "Lightning towers gain +12% attack speed.",
        "mechanics": ["Applies only to Lightning towers.", "Damage type and enemy elemental immunities are unchanged."],
    },
    {
        "id": "pitch_sealed_sling", "title": "Pitch-Sealed Sling",
        "effect": "Orcapult attacks deal +12% damage.",
        "mechanics": ["Applies only to Orcapult damage.", "Members per throw and reload duration are unchanged."],
    },
    {
        "id": "menders_spool", "title": "Mender's Spool",
        "effect": "All towers suffer received slows for 15% less time.",
        "mechanics": ["Multiplies slow durations received by towers by 0.85.", "Does not change slow strength or slows inflicted on enemies."],
    },
    {
        "id": "mooncap_jerky", "title": "Mooncap Jerky",
        "effect": "Attacking towers deal +15% damage to bosses but 5% less damage to other enemies.",
        "mechanics": ["The target's boss status selects the damage modifier.", "Does not change enemy immunities."],
    },
    {
        "id": "counting_frame", "title": "Counting Frame",
        "effect": "Gold Mines produce +10% gold per production payout.",
        "mechanics": ["Applies only to Gold Mine production payouts.", "Production cadence and gold from other sources are unchanged."],
    },
]


def steel_arrowhead_icon():
    im, d = canvas()
    # Broad upright hunting head: two hooked barbs and filed edge teeth.
    d.polygon([(16, 2), (21, 9), (20, 10), (25, 14), (23, 15),
               (29, 20), (25, 27), (20, 22), (12, 22), (7, 27),
               (3, 20), (9, 15), (7, 14), (12, 10), (11, 9)],
              fill=STEEL[1], outline=INK)
    d.polygon([(16, 4), (16, 20), (12, 20), (7, 24), (6, 20),
               (12, 15), (10, 14), (14, 10), (13, 9)], fill=STEEL[3])
    d.polygon([(17, 7), (23, 14), (21, 15), (27, 20), (25, 24),
               (21, 20), (17, 19)], fill=STEEL[0])
    d.line([(16, 4), (16, 21)], fill=STEEL[4])
    d.line([(5, 20), (7, 24)], fill=STEEL[4])
    d.line([(24, 24), (26, 20)], fill=STEEL[2])
    d.polygon([(12, 21), (20, 21), (21, 28), (19, 30), (13, 30),
               (11, 28)], fill=STEEL[1], outline=INK)
    d.line([(13, 23), (13, 27)], fill=STEEL[3])
    d.line([(18, 23), (19, 28)], fill=STEEL[0])
    d.ellipse((12, 27, 20, 30), fill=INK)
    d.arc((12, 27, 20, 30), 0, 180, fill=STEEL[2])
    d.point((16, 24), fill=STEEL[4])
    return im


def steel_arrowhead_detail():
    im, d = portrait()
    # A separate broad composition exposes the serrations, hooked heels,
    # raised central web and rolled hollow socket rather than a tied tang.
    poly(d, [(48, 7), (61, 25), (58, 28), (72, 39), (67, 42),
             (87, 59), (75, 79), (59, 63), (37, 63), (21, 79),
             (9, 59), (29, 42), (24, 39), (38, 28), (35, 25)],
         STEEL[1])
    poly(d, [(46, 13), (46, 58), (36, 58), (22, 72), (15, 59),
             (35, 42), (30, 39), (43, 28), (40, 25)],
         STEEL[2], None)
    poly(d, [(43, 22), (43, 51), (33, 53), (20, 66), (18, 59),
             (39, 41), (35, 39), (46, 28)], STEEL[3], None)
    poly(d, [(50, 15), (56, 25), (53, 29), (66, 39), (61, 42),
             (80, 59), (74, 72), (61, 58), (50, 55)], STEEL[0], None)
    poly(d, [(53, 26), (53, 50), (63, 53), (76, 65), (78, 59),
             (58, 41), (62, 39), (50, 28)], STEEL[1], None)
    line(d, [(48, 11), (48, 59)], STEEL[4], 2)
    line(d, [(37, 26), (41, 28), (27, 39), (32, 42),
             (12, 59), (21, 75)], STEEL[4], 2)
    line(d, [(75, 75), (84, 59), (65, 43)], STEEL[2], 2)
    # Two small pierced reliefs keep the barbs visibly separate from the web.
    poly(d, [(32, 48), (37, 44), (37, 52), (29, 60)], INK, width=1)
    line(d, [(30, 59), (37, 52)], STEEL[3])
    poly(d, [(59, 44), (64, 48), (67, 60), (59, 52)], INK, width=1)
    line(d, [(60, 52), (66, 59)], STEEL[2])
    poly(d, [(37, 59), (59, 59), (63, 83), (59, 89),
             (37, 89), (33, 83)], STEEL[1])
    poly(d, [(39, 62), (47, 62), (47, 83), (38, 85),
             (36, 81)], STEEL[3], None)
    poly(d, [(52, 62), (57, 62), (60, 82), (55, 86)],
         STEEL[0], None)
    line(d, [(51, 62), (55, 82)], STEEL[0])
    line(d, [(50, 62), (54, 81)], STEEL[2])
    d.ellipse((34, 80, 62, 91), fill=INK, outline=STEEL[0], width=2)
    d.arc((35, 80, 61, 90), 0, 180, fill=STEEL[2], width=2)
    d.arc((38, 82, 58, 88), 185, 340, fill=STEEL[1])
    rivet(d, 44, 69)
    rivet(d, 45, 76)
    # Directional grinding marks stop at the raised central ridge.
    for x, y in ((29, 55), (32, 52), (35, 49), (61, 52), (64, 55)):
        line(d, [(x, y), (x + 2, y + 2)], STEEL[2])
    line(d, [(40, 34), (44, 31)], STEEL[4])
    line(d, [(54, 33), (57, 36)], STEEL[2])
    return im


def balanced_mechanism_icon():
    im, d = canvas()
    d.polygon([(6, 8), (13, 4), (26, 8), (27, 23), (19, 28), (5, 24)], fill="#67533b", outline=INK)
    d.line([(7, 9), (13, 6), (24, 9)], fill="#b69862")
    d.rectangle((7, 13, 25, 17), fill=INK)
    d.line([(8, 14), (24, 14)], fill=STEEL[2], width=2)
    d.ellipse((6, 9, 17, 21), fill=GOLD[1], outline=INK)
    d.ellipse((9, 12, 14, 18), fill=STEEL[0], outline=INK)
    d.ellipse((17, 15, 26, 24), fill=STEEL[1], outline=INK)
    d.ellipse((20, 18, 23, 21), fill=GOLD[3])
    for x, y in ((8, 9), (13, 9), (6, 14), (14, 19), (18, 18), (23, 23)):
        d.rectangle((x, y, x + 2, y + 1), fill=GOLD[2])
    d.line([(16, 6), (20, 10), (21, 13)], fill=STEEL[3], width=2)
    d.point((10, 11), fill=GOLD[4])
    return im


def balanced_mechanism_detail():
    im, d = portrait()
    poly(d, [(14, 24), (38, 12), (81, 24), (83, 71), (60, 85), (13, 72)], "#594634")
    poly(d, [(17, 26), (39, 16), (77, 26), (57, 36)], "#aa8854")
    poly(d, [(17, 31), (57, 41), (57, 79), (17, 69)], "#7a5d3d")
    poly(d, [(60, 40), (79, 29), (79, 69), (60, 80)], "#3c392c")
    line(d, [(20, 62), (32, 64), (43, 62)], "#bb9458")
    line(d, [(22, 66), (33, 69), (47, 68)], "#4b3b2c")
    line(d, [(22, 45), (72, 57)], INK, 8)
    line(d, [(22, 43), (72, 55)], STEEL[2], 4)
    for x, y in ((32, 42), (62, 59)):
        for dx, dy in ((-13, -5), (-10, -12), (0, -15), (10, -10), (13, 0), (9, 10), (-2, 13), (-12, 7)):
            d.rectangle((x + dx - 2, y + dy - 2, x + dx + 3, y + dy + 3), fill=INK)
            d.rectangle((x + dx - 1, y + dy - 1, x + dx + 2, y + dy + 2), fill=GOLD[2])
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill=GOLD[1], outline=INK, width=2)
        d.arc((x - 11, y - 11, x + 11, y + 11), 185, 285, fill=GOLD[4], width=2)
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=STEEL[0], outline=INK, width=2)
        rivet(d, x, y, STEEL)
    poly(d, [(45, 18), (51, 17), (66, 33), (64, 44), (58, 44), (60, 34)], STEEL[1])
    line(d, [(48, 19), (63, 34), (62, 41)], STEEL[3], 2)
    for x, y in ((19, 29), (74, 28), (20, 68), (73, 69)):
        rivet(d, x, y, STEEL)
    return im


def lucky_fang_icon():
    im, d = canvas()
    d.line([(9, 10), (8, 5), (13, 2), (20, 4), (22, 8)], fill=INK, width=3)
    d.line([(9, 9), (9, 5), (13, 3), (20, 5), (21, 8)], fill="#9e794d")
    d.polygon([(9, 8), (22, 8), (24, 12), (22, 21), (17, 27), (10, 30), (13, 23), (14, 15)], fill=BONE[1], outline=INK)
    d.polygon([(11, 10), (18, 10), (19, 16), (17, 23), (12, 28), (15, 20)], fill=BONE[3])
    d.polygon([(19, 11), (22, 11), (21, 20), (17, 25), (19, 18)], fill=BONE[0])
    d.line([(9, 10), (22, 12), (11, 14), (20, 16)], fill="#704d35")
    d.rectangle((13, 10, 15, 12), fill=GOLD[3])
    d.point((18, 19), fill=BONE[2])
    return im


def lucky_fang_detail():
    im, d = portrait()
    line(d, [(27, 29), (23, 20), (27, 11), (42, 7), (61, 12), (68, 28)], INK, 6)
    line(d, [(27, 28), (26, 20), (30, 13), (43, 10), (59, 15), (65, 28)], "#986c42", 3)
    line(d, [(30, 13), (42, 11), (52, 14)], "#d5af70")
    poly(d, [(27, 26), (64, 25), (73, 35), (70, 55), (58, 73), (39, 86), (24, 89), (37, 73), (42, 53), (35, 41)], BONE[1])
    poly(d, [(31, 31), (50, 30), (56, 40), (54, 57), (43, 75), (29, 86), (40, 67), (45, 48)], BONE[3], None)
    poly(d, [(59, 31), (68, 36), (65, 54), (53, 71), (42, 79), (53, 60), (59, 43)], BONE[0], None)
    line(d, [(35, 33), (47, 36), (49, 46)], "#fff5cc", 2)
    line(d, [(48, 58), (44, 69), (38, 76)], BONE[2], 2)
    line(d, [(62, 41), (61, 48), (57, 52)], "#827552")
    line(d, [(30, 30), (67, 35), (35, 39), (65, 44), (40, 46)], "#523a2c", 4)
    line(d, [(31, 29), (65, 34)], "#be945e", 2)
    line(d, [(35, 38), (64, 43)], "#be945e", 2)
    poly(d, [(42, 32), (51, 33), (51, 42), (43, 41)], GOLD[1])
    line(d, [(44, 34), (49, 35), (49, 39)], GOLD[3], 2)
    d.point((46, 37), fill=GOLD[4])
    return im


def siege_scope_icon():
    im, d = canvas()
    d.polygon([(6, 20), (22, 6), (27, 9), (13, 25)], fill=GOLD[1], outline=INK)
    d.polygon([(9, 18), (22, 7), (24, 9), (12, 21)], fill=GOLD[3])
    d.polygon([(3, 19), (7, 16), (15, 23), (11, 28), (7, 28), (3, 24)], fill=STEEL[1], outline=INK)
    d.ellipse((3, 20, 11, 28), fill="#234e57", outline=INK)
    d.line([(5, 22), (8, 22), (9, 24)], fill="#87d2cc")
    d.polygon([(20, 5), (24, 3), (29, 8), (28, 12), (25, 14), (20, 9)], fill=STEEL[0], outline=INK)
    d.line([(21, 6), (25, 9), (27, 9)], fill=STEEL[3])
    d.line([(15, 14), (19, 18)], fill=INK, width=3)
    d.line([(16, 14), (19, 17)], fill=GOLD[2])
    return im


def siege_scope_detail():
    im, d = portrait()
    poly(d, [(19, 58), (64, 20), (79, 31), (37, 73)], GOLD[1])
    poly(d, [(23, 56), (64, 23), (70, 27), (32, 65)], GOLD[3], None)
    poly(d, [(33, 67), (76, 31), (75, 38), (39, 74)], GOLD[0], None)
    line(d, [(26, 55), (63, 25)], GOLD[4], 2)
    poly(d, [(11, 57), (21, 49), (43, 68), (37, 81), (22, 87), (9, 74)], STEEL[1])
    d.ellipse((11, 62, 35, 86), fill=STEEL[0], outline=INK, width=2)
    d.ellipse((15, 65, 31, 81), fill="#1e424d", outline=INK, width=2)
    poly(d, [(18, 68), (25, 67), (28, 70), (20, 77), (17, 75)], "#75b7bd", None)
    line(d, [(21, 68), (25, 68)], "#cbf0dc", 2)
    line(d, [(23, 68), (23, 79)], "#345d63")
    line(d, [(17, 73), (29, 73)], "#345d63")
    poly(d, [(59, 18), (69, 11), (88, 27), (86, 38), (78, 44), (59, 28)], STEEL[0])
    poly(d, [(63, 20), (70, 16), (83, 27), (79, 31)], STEEL[2], None)
    line(d, [(63, 20), (70, 17), (78, 23)], STEEL[4])
    poly(d, [(44, 34), (50, 30), (66, 43), (61, 50)], "#614733")
    line(d, [(46, 35), (61, 47)], GOLD[2], 2)
    rivet(d, 53, 40, GOLD)
    d.rectangle((47, 25, 54, 31), fill=INK)
    d.rectangle((48, 24, 53, 28), fill=STEEL[2])
    line(d, [(48, 23), (52, 23)], STEEL[4])
    for x, y in ((35, 52), (39, 48), (43, 44)):
        line(d, [(x, y), (x + 2, y + 2)], GOLD[0])
    return im


def lightweight_ammunition_icon():
    im, d = canvas()
    for x, y in ((5, 11), (12, 5), (20, 8)):
        d.line([(x, y + 15), (x + 7, y + 2)], fill=INK, width=3)
        d.line([(x, y + 15), (x + 7, y + 2)], fill="#c5ac73")
        d.polygon([(x + 4, y + 5), (x + 8, y), (x + 10, y + 6)], fill=STEEL[2], outline=INK)
        d.polygon([(x, y + 10), (x - 3, y + 11), (x - 2, y + 17), (x + 2, y + 15), (x + 4, y + 11)], fill=BONE[2], outline=INK)
        d.line([(x - 1, y + 12), (x, y + 15)], fill=BONE[3])
    d.line([(7, 21), (20, 25), (23, 21)], fill="#875b3e", width=2)
    return im


def lightweight_ammunition_detail():
    im, d = portrait()
    for x, y in ((21, 20), (40, 9), (60, 17)):
        line(d, [(x - 5, y + 58), (x + 14, y + 9)], INK, 5)
        line(d, [(x - 5, y + 57), (x + 14, y + 9)], "#bca36e", 3)
        line(d, [(x - 5, y + 55), (x + 12, y + 13)], "#f0d697")
        poly(d, [(x + 8, y + 16), (x + 18, y), (x + 20, y + 19), (x + 14, y + 15)], STEEL[1])
        poly(d, [(x + 11, y + 14), (x + 17, y + 4), (x + 14, y + 13)], STEEL[3], None)
        poly(d, [(x - 3, y + 36), (x - 12, y + 42), (x - 11, y + 58), (x - 5, y + 64), (x - 2, y + 53), (x + 5, y + 43), (x + 5, y + 33)], BONE[1])
        poly(d, [(x - 4, y + 40), (x - 9, y + 44), (x - 9, y + 55), (x - 5, y + 59), (x - 2, y + 48), (x + 2, y + 40)], BONE[3], None)
        for dy in (42, 47, 52):
            line(d, [(x - 9, y + dy), (x - 4, y + dy + 2)], BONE[0])
        line(d, [(x - 5, y + 59), (x + 4, y + 35)], "#f8edc6")
        line(d, [(x + 8, y + 22), (x + 12, y + 24)], "#80623c", 2)
    line(d, [(18, 68), (50, 77), (69, 67)], INK, 7)
    line(d, [(18, 67), (50, 75), (68, 66)], "#966745", 4)
    line(d, [(20, 66), (49, 73)], "#d1a671")
    poly(d, [(43, 71), (51, 69), (56, 75), (50, 81)], "#68492f")
    line(d, [(51, 78), (58, 86)], "#966745", 3)
    return im


def heavy_bolts_icon():
    im, d = canvas()
    for x, y in ((7, 7), (17, 3)):
        d.line([(x - 1, y + 20), (x + 6, y + 7)], fill=INK, width=5)
        d.line([(x - 1, y + 20), (x + 6, y + 7)], fill="#825a38", width=3)
        d.polygon([(x + 1, y + 9), (x + 8, y), (x + 11, y + 11), (x + 5, y + 14)], fill=STEEL[1], outline=INK)
        d.polygon([(x + 3, y + 8), (x + 8, y + 2), (x + 6, y + 11)], fill=STEEL[3])
        d.line([(x - 4, y + 18), (x + 3, y + 22)], fill=INK, width=3)
        d.line([(x - 4, y + 17), (x + 3, y + 21)], fill=RED[1], width=2)
        d.line([(x, y + 14), (x + 4, y + 16)], fill=GOLD[2], width=2)
    return im


def heavy_bolts_detail():
    im, d = portrait()
    for x, y in ((23, 21), (53, 8)):
        line(d, [(x - 6, y + 62), (x + 15, y + 20)], INK, 11)
        line(d, [(x - 6, y + 61), (x + 15, y + 20)], "#765034", 7)
        line(d, [(x - 7, y + 59), (x + 12, y + 23)], "#bc925a", 2)
        poly(d, [(x + 1, y + 24), (x + 22, y), (x + 30, y + 30), (x + 14, y + 38)], STEEL[1])
        poly(d, [(x + 5, y + 23), (x + 21, y + 5), (x + 17, y + 29)], STEEL[3], None)
        poly(d, [(x + 21, y + 5), (x + 26, y + 28), (x + 19, y + 32)], STEEL[0], None)
        line(d, [(x + 8, y + 21), (x + 21, y + 6)], STEEL[4], 2)
        poly(d, [(x - 15, y + 49), (x - 4, y + 50), (x + 5, y + 58), (x + 4, y + 68), (x - 7, y + 65), (x - 15, y + 59)], RED[0])
        poly(d, [(x - 12, y + 51), (x - 4, y + 53), (x + 1, y + 59), (x - 6, y + 60)], RED[2], None)
        line(d, [(x - 13, y + 53), (x - 4, y + 60)], RED[3])
        line(d, [(x + 1, y + 39), (x + 9, y + 43)], INK, 7)
        line(d, [(x + 1, y + 38), (x + 9, y + 42)], GOLD[2], 4)
        rivet(d, x + 6, y + 40, GOLD)
        line(d, [(x + 20, y + 22), (x + 23, y + 24)], STEEL[2])
    return im


def resonant_drumsticks_icon():
    im, d = canvas()
    d.line([(7, 28), (23, 7)], fill=INK, width=5)
    d.line([(7, 27), (23, 7)], fill="#ab7e49", width=3)
    d.line([(25, 27), (10, 7)], fill=INK, width=5)
    d.line([(25, 26), (10, 7)], fill="#bc9259", width=3)
    d.ellipse((20, 3, 27, 11), fill="#aa8554", outline=INK)
    d.ellipse((6, 3, 13, 11), fill="#cbb17c", outline=INK)
    d.line([(8, 5), (10, 4), (11, 6)], fill=BONE[3])
    d.line([(22, 5), (24, 5)], fill=BONE[2])
    d.line([(9, 22), (12, 24)], fill=GREEN[1], width=3)
    d.line([(20, 21), (23, 19)], fill=GREEN[1], width=3)
    d.point((10, 22), fill=GREEN[3])
    d.point((21, 20), fill=GREEN[3])
    return im


def resonant_drumsticks_detail():
    im, d = portrait()
    line(d, [(17, 85), (70, 21)], INK, 11)
    line(d, [(18, 83), (70, 21)], "#916137", 7)
    line(d, [(17, 81), (67, 21)], "#d6b477", 2)
    line(d, [(79, 84), (29, 22)], INK, 11)
    line(d, [(78, 82), (29, 22)], "#b1844a", 7)
    line(d, [(75, 80), (28, 24)], "#e2c78a", 2)
    poly(d, [(62, 12), (69, 7), (77, 10), (82, 18), (79, 28), (72, 32), (65, 27), (61, 20)], "#a07b4d")
    poly(d, [(64, 13), (70, 10), (75, 12), (77, 19), (72, 25), (66, 22)], "#d6b77e", None)
    poly(d, [(20, 11), (27, 8), (34, 11), (38, 20), (34, 29), (27, 31), (20, 25), (17, 18)], "#b89b66")
    poly(d, [(21, 13), (27, 11), (32, 14), (33, 20), (27, 24), (21, 21)], BONE[3], None)
    line(d, [(65, 15), (70, 12), (74, 14)], BONE[3], 2)
    line(d, [(22, 16), (28, 14)], "#fff1c7", 2)
    line(d, [(25, 24), (30, 27), (33, 24)], "#8c704a")
    for x, y, dx in ((23, 67, 8), (64, 65, -8)):
        for offset in (0, 4, 8):
            line(d, [(x + offset // 2, y - offset), (x + dx + offset // 2, y + 5 - offset)], INK, 5)
            line(d, [(x + offset // 2, y - offset), (x + dx + offset // 2, y + 4 - offset)], GREEN[1], 3)
        line(d, [(x + 1, y - 7), (x + 4, y - 5)], GREEN[3])
    line(d, [(38, 50), (42, 46)], "#765132")
    line(d, [(57, 52), (60, 56)], "#765132")
    return im


def oversized_bucket_icon():
    im, d = canvas()
    d.arc((8, 2, 25, 22), 175, 365, fill=INK, width=3)
    d.arc((9, 3, 24, 21), 180, 360, fill=STEEL[2])
    d.polygon([(3, 12), (28, 12), (25, 28), (9, 30)], fill="#815b39", outline=INK)
    d.polygon([(5, 14), (14, 15), (15, 28), (10, 28)], fill="#b58d52")
    d.polygon([(21, 14), (27, 13), (24, 27), (21, 28)], fill="#503e2d")
    d.ellipse((3, 9, 28, 17), fill=STEEL[1], outline=INK)
    d.ellipse((6, 11, 25, 15), fill="#302e25", outline=INK)
    d.line([(7, 20), (26, 20)], fill=STEEL[2], width=2)
    d.line([(9, 26), (24, 26)], fill=STEEL[1], width=2)
    d.line([(16, 16), (17, 28)], fill="#493a2c")
    d.point((11, 20), fill=STEEL[4])
    d.point((22, 26), fill=STEEL[3])
    return im


def oversized_bucket_detail():
    im, d = portrait()
    d.arc((23, 5, 76, 60), 175, 365, fill=INK, width=7)
    d.arc((26, 8, 73, 57), 180, 360, fill=STEEL[2], width=3)
    line(d, [(28, 23), (30, 17), (35, 13)], STEEL[4], 2)
    poly(d, [(12, 36), (83, 35), (74, 79), (61, 86), (29, 84), (20, 77)], "#815b38")
    poly(d, [(18, 42), (34, 44), (37, 81), (26, 78)], "#b38b51", None)
    poly(d, [(38, 44), (54, 44), (54, 83), (40, 82)], "#987042", None)
    poly(d, [(65, 42), (79, 38), (72, 76), (62, 82)], "#4b3b2c", None)
    for points in ([(34, 44), (38, 81)], [(55, 44), (55, 82)], [(65, 42), (62, 81)]):
        line(d, points, "#392f25", 2)
    d.ellipse((11, 26, 84, 48), fill=STEEL[1], outline=INK, width=2)
    d.ellipse((17, 30, 78, 43), fill="#292c24", outline=INK, width=2)
    d.arc((14, 27, 81, 45), 175, 290, fill=STEEL[3], width=2)
    poly(d, [(18, 55), (49, 61), (79, 53), (77, 60), (49, 67), (20, 61)], STEEL[1])
    line(d, [(22, 56), (49, 62), (73, 56)], STEEL[3], 2)
    poly(d, [(23, 74), (50, 78), (74, 71), (73, 77), (51, 85), (26, 81)], STEEL[0])
    line(d, [(28, 76), (50, 80), (67, 75)], STEEL[2])
    for x, y in ((26, 59), (49, 64), (70, 58), (31, 79), (66, 79)):
        rivet(d, x, y, STEEL)
    rivet(d, 23, 36, STEEL)
    rivet(d, 74, 35, STEEL)
    line(d, [(26, 46), (27, 51)], "#d6b77b")
    line(d, [(43, 68), (47, 71), (45, 74)], "#5c432e")
    return im


def trollhide_earplugs_icon():
    im, d = canvas()
    d.line([(8, 14), (6, 23), (11, 29), (20, 28), (25, 21), (23, 12)], fill=INK, width=3)
    d.line([(8, 14), (7, 23), (12, 28), (20, 27), (24, 21), (23, 12)], fill="#976e46")
    d.polygon([(4, 7), (8, 4), (14, 7), (15, 14), (11, 19), (6, 17), (4, 12)], fill=GREEN[1], outline=INK)
    d.polygon([(18, 6), (24, 4), (28, 8), (28, 14), (24, 19), (19, 16)], fill=GREEN[0], outline=INK)
    d.polygon([(6, 8), (9, 6), (12, 9), (11, 14), (7, 13)], fill=GREEN[2])
    d.polygon([(20, 7), (24, 6), (26, 9), (24, 14), (21, 12)], fill=GREEN[2])
    d.line([(6, 15), (11, 16)], fill=BONE[1])
    d.line([(20, 15), (25, 17)], fill=BONE[1])
    d.point((7, 8), fill=GREEN[3])
    d.point((21, 7), fill=GREEN[3])
    return im


def trollhide_earplugs_detail():
    im, d = portrait()
    line(d, [(27, 46), (18, 64), (23, 79), (37, 87), (61, 83), (75, 66), (69, 43)], INK, 6)
    line(d, [(27, 46), (21, 64), (25, 77), (38, 84), (60, 80), (72, 66), (68, 43)], "#9d7449", 3)
    line(d, [(26, 73), (31, 78), (39, 81)], "#d4b379")
    poly(d, [(13, 24), (24, 14), (37, 19), (45, 32), (43, 48), (32, 59), (19, 52), (13, 39)], GREEN[1])
    poly(d, [(18, 26), (26, 20), (34, 24), (38, 34), (34, 46), (23, 45), (18, 36)], GREEN[2], None)
    poly(d, [(54, 20), (69, 14), (82, 25), (84, 41), (73, 56), (58, 50), (52, 35)], GREEN[0])
    poly(d, [(57, 23), (67, 19), (76, 26), (77, 35), (69, 44), (60, 39)], GREEN[2], None)
    line(d, [(20, 27), (26, 23), (30, 25)], GREEN[3], 2)
    line(d, [(59, 24), (66, 22), (71, 25)], GREEN[3], 2)
    line(d, [(18, 43), (30, 49), (40, 42)], "#263d2c", 3)
    line(d, [(59, 43), (71, 48), (79, 38)], "#182e25", 3)
    for x, y in ((20, 43), (26, 46), (33, 46), (38, 42), (60, 42), (66, 45), (73, 44), (77, 39)):
        line(d, [(x, y - 2), (x - 1, y + 3)], BONE[1], 2)
    for x, y in ((25, 32), (32, 37), (24, 39), (65, 30), (70, 34), (62, 35)):
        d.rectangle((x, y, x + 2, y + 2), fill=GREEN[1])
        d.point((x, y), fill=GREEN[3])
    line(d, [(30, 53), (32, 59)], "#b49261", 3)
    line(d, [(68, 51), (70, 56)], "#b49261", 3)
    return im


def gravediggers_lantern_icon():
    im, d = canvas()
    d.arc((11, 1, 22, 12), 175, 365, fill=INK, width=3)
    d.arc((12, 2, 21, 11), 180, 360, fill=STEEL[2])
    d.polygon([(8, 9), (24, 9), (27, 13), (24, 28), (9, 28), (6, 13)], fill=STEEL[0], outline=INK)
    d.polygon([(10, 14), (22, 14), (21, 25), (11, 25)], fill="#263e32")
    d.polygon([(13, 23), (12, 19), (16, 14), (16, 18), (19, 16), (20, 22), (17, 25)], fill=GREEN[2])
    d.polygon([(15, 23), (15, 20), (17, 18), (18, 23)], fill=GREEN[4])
    d.line([(9, 11), (23, 11)], fill=STEEL[2], width=2)
    d.line([(10, 13), (11, 26), (22, 26), (23, 13)], fill=STEEL[1])
    d.line([(7, 28), (25, 28)], fill=INK, width=3)
    d.line([(9, 27), (23, 27)], fill=STEEL[2])
    return im


def gravediggers_lantern_detail():
    im, d = portrait()
    d.arc((34, 6, 64, 36), 175, 365, fill=INK, width=6)
    d.arc((37, 9, 61, 33), 180, 360, fill=STEEL[2], width=2)
    poly(d, [(28, 27), (68, 27), (79, 39), (73, 78), (63, 85), (31, 84), (23, 76), (18, 39)], STEEL[0])
    poly(d, [(28, 40), (65, 40), (63, 74), (32, 75)], "#294237")
    poly(d, [(66, 41), (74, 39), (69, 75), (64, 78)], "#1c302d", None)
    poly(d, [(38, 71), (33, 59), (38, 49), (48, 40), (47, 52), (56, 46), (59, 57), (56, 70), (48, 77)], GREEN[1], None)
    poly(d, [(39, 68), (38, 59), (45, 49), (45, 58), (53, 52), (54, 63), (48, 72)], GREEN[3], None)
    poly(d, [(43, 68), (43, 60), (48, 56), (50, 65), (47, 70)], GREEN[4], None)
    poly(d, [(19, 36), (28, 25), (68, 25), (79, 36), (75, 41), (23, 41)], STEEL[1])
    line(d, [(23, 35), (29, 29), (65, 29)], STEEL[3], 2)
    line(d, [(30, 43), (33, 76), (62, 76), (65, 43)], STEEL[2], 3)
    line(d, [(33, 44), (35, 69)], "#89bba1")
    line(d, [(24, 43), (28, 75)], STEEL[1], 3)
    poly(d, [(26, 77), (69, 77), (76, 84), (72, 89), (24, 89), (19, 84)], STEEL[1])
    line(d, [(25, 82), (65, 82)], STEEL[3], 2)
    poly(d, [(43, 27), (52, 27), (56, 32), (52, 38), (43, 38), (39, 32)], "#596e53")
    d.rectangle((43, 30, 46, 32), fill=INK)
    d.rectangle((50, 30, 52, 32), fill=INK)
    line(d, [(46, 36), (50, 36)], BONE[1])
    for x, y in ((27, 38), (70, 37), (29, 83), (66, 83)):
        rivet(d, x, y, STEEL)
    return im


def peppercorn_skewer_icon():
    im, d = canvas()
    d.line([(5, 29), (26, 3)], fill=INK, width=3)
    d.line([(5, 28), (26, 3)], fill="#cbb17c")
    for x, y in ((9, 22), (16, 14), (22, 7)):
        d.polygon([(x - 4, y - 2), (x - 1, y - 6), (x + 4, y - 3), (x + 3, y + 3), (x - 2, y + 4)], fill=RED[1], outline=INK)
        d.line([(x - 2, y - 3), (x + 1, y - 3), (x + 2, y - 1)], fill=RED[3])
        d.point((x, y + 1), fill="#e6b76e")
        d.point((x + 2, y - 1), fill=INK)
    d.polygon([(10, 20), (14, 18), (17, 20), (14, 23)], fill=GREEN[2], outline=INK)
    d.polygon([(17, 11), (20, 9), (23, 11), (20, 14)], fill=GREEN[1], outline=INK)
    return im


def peppercorn_skewer_detail():
    im, d = portrait()
    line(d, [(14, 88), (80, 8)], INK, 6)
    line(d, [(14, 86), (80, 8)], "#b99562", 3)
    line(d, [(15, 84), (78, 10)], "#f1d8a0")
    for x, y in ((29, 65), (49, 43), (69, 21)):
        poly(d, [(x - 15, y - 4), (x - 8, y - 16), (x + 6, y - 14), (x + 15, y - 4), (x + 10, y + 12), (x - 2, y + 16), (x - 14, y + 8)], RED[0])
        poly(d, [(x - 12, y - 4), (x - 6, y - 12), (x + 4, y - 11), (x + 10, y - 4), (x + 7, y + 7), (x - 3, y + 11), (x - 11, y + 5)], RED[2], None)
        line(d, [(x - 10, y - 3), (x - 5, y - 9), (x + 2, y - 9)], RED[3], 2)
        line(d, [(x - 5, y + 7), (x + 3, y + 3), (x + 8, y - 5)], "#6e3430", 2)
        for dx, dy in ((-6, -1), (2, -5), (5, 5), (-3, 6)):
            d.rectangle((x + dx, y + dy, x + dx + 2, y + dy + 2), fill=INK)
            d.point((x + dx, y + dy), fill="#a68c60")
        d.rectangle((x - 6, y - 5, x - 4, y - 4), fill="#ffd0a4")
    poly(d, [(30, 51), (40, 46), (48, 52), (43, 60), (33, 60), (27, 56)], GREEN[1])
    line(d, [(31, 52), (39, 49), (44, 52)], GREEN[3], 2)
    poly(d, [(51, 29), (60, 24), (68, 30), (61, 38), (54, 36)], GREEN[1])
    line(d, [(54, 30), (60, 27), (64, 30)], GREEN[3], 2)
    return im


def surveyors_fieldbook_icon():
    im, d = canvas()
    d.polygon([(5, 7), (24, 3), (28, 7), (28, 25), (10, 30), (5, 26)], fill="#344f45", outline=INK)
    d.polygon([(8, 10), (26, 6), (26, 23), (9, 27)], fill=BONE[1], outline=INK)
    d.polygon([(5, 7), (22, 4), (25, 7), (25, 23), (8, 28), (5, 25)], fill=GREEN[0], outline=INK)
    d.line([(8, 9), (21, 6), (22, 20), (9, 24), (8, 9)], fill=GREEN[2])
    d.line([(11, 20), (16, 11), (20, 18), (11, 20)], fill=GOLD[3])
    d.line([(16, 11), (16, 20)], fill=GOLD[2])
    d.line([(7, 8), (7, 25)], fill=GREEN[1])
    d.polygon([(21, 23), (25, 22), (24, 29), (22, 28), (20, 30)], fill=RED[2], outline=INK)
    return im


def surveyors_fieldbook_detail():
    im, d = portrait()
    poly(d, [(15, 22), (68, 9), (82, 18), (81, 73), (29, 88), (14, 78)], "#2b443b")
    poly(d, [(24, 30), (78, 18), (78, 70), (27, 84)], BONE[1])
    for y in (36, 43, 50, 57, 64, 71):
        line(d, [(30, y + 10), (75, y - 2)], BONE[0])
    poly(d, [(15, 22), (65, 11), (74, 18), (73, 68), (24, 82), (15, 76)], GREEN[0])
    poly(d, [(25, 27), (63, 18), (65, 62), (27, 73)], "#3b5c43", None)
    line(d, [(25, 27), (63, 18), (65, 62), (27, 73), (25, 27)], GREEN[2], 2)
    line(d, [(20, 24), (21, 75)], "#6b8154", 2)
    poly(d, [(31, 61), (46, 32), (59, 53)], GOLD[2], None)
    poly(d, [(36, 58), (46, 39), (54, 52)], "#3b5c43", None)
    line(d, [(46, 32), (47, 62)], GOLD[3], 2)
    line(d, [(32, 64), (60, 56)], GOLD[1], 2)
    d.ellipse((42, 28, 49, 35), fill=GOLD[3], outline=INK)
    for x, y in ((32, 59), (37, 49), (52, 45), (57, 52)):
        d.point((x, y), fill=GOLD[4])
    poly(d, [(58, 74), (70, 70), (68, 89), (63, 85), (57, 91)], RED[1])
    line(d, [(61, 76), (60, 85)], RED[3], 2)
    poly(d, [(15, 68), (23, 70), (24, 80), (15, 76)], "#73583a")
    rivet(d, 19, 73, GOLD)
    line(d, [(30, 29), (35, 27)], GREEN[3])
    return im


def riveted_bracer_icon():
    im, d = canvas()
    d.polygon([(6, 6), (19, 3), (26, 9), (23, 25), (13, 29), (5, 23)], fill=STEEL[0], outline=INK)
    d.polygon([(8, 8), (18, 5), (22, 11), (19, 24), (13, 26), (8, 21)], fill=STEEL[1])
    d.polygon([(9, 9), (14, 7), (16, 24), (12, 25), (9, 20)], fill=STEEL[3])
    d.line([(6, 12), (23, 16)], fill=INK, width=4)
    d.line([(6, 12), (23, 16)], fill="#895f3b", width=2)
    d.line([(5, 20), (21, 23)], fill=INK, width=4)
    d.line([(5, 20), (21, 23)], fill="#895f3b", width=2)
    d.rectangle((18, 13, 22, 17), fill=GOLD[2], outline=INK)
    d.point((20, 15), fill=INK)
    for p in ((8, 8), (18, 6), (10, 24), (20, 21)):
        d.point(p, fill=GOLD[3])
    return im


def riveted_bracer_detail():
    im, d = portrait()
    poly(d, [(19, 20), (56, 9), (78, 28), (69, 74), (39, 88), (16, 67)], "#483c30")
    poly(d, [(23, 22), (56, 14), (72, 30), (64, 72), (40, 82), (22, 64)], STEEL[0])
    poly(d, [(26, 26), (41, 20), (48, 77), (40, 80), (26, 63)], STEEL[2], None)
    poly(d, [(44, 19), (55, 17), (67, 30), (60, 70), (51, 74)], STEEL[1], None)
    line(d, [(27, 28), (38, 24), (43, 71)], STEEL[4], 2)
    line(d, [(47, 22), (52, 66)], STEEL[2], 2)
    poly(d, [(18, 35), (72, 47), (70, 56), (18, 44)], "#765033")
    line(d, [(21, 36), (66, 46)], "#ba915a", 2)
    poly(d, [(17, 59), (67, 69), (65, 77), (20, 68)], "#765033")
    line(d, [(22, 60), (61, 68)], "#ba915a", 2)
    for x, y in ((58, 43), (54, 66)):
        poly(d, [(x, y), (x + 12, y + 2), (x + 11, y + 13), (x - 1, y + 10)], GOLD[1])
        poly(d, [(x + 3, y + 4), (x + 8, y + 5), (x + 7, y + 9), (x + 2, y + 8)], INK, None)
        line(d, [(x + 1, y + 1), (x + 10, y + 3)], GOLD[3], 2)
        line(d, [(x + 6, y + 3), (x + 5, y + 9)], STEEL[2])
    for x, y in ((26, 25), (55, 19), (28, 65), (45, 77), (65, 31)):
        rivet(d, x, y, GOLD)
    line(d, [(47, 56), (51, 53), (55, 54)], STEEL[0])
    line(d, [(32, 49), (33, 55)], STEEL[1])
    return im


def copper_winding_icon():
    im, d = canvas()
    d.polygon([(9, 5), (15, 2), (22, 5), (22, 27), (15, 30), (9, 27)], fill=STEEL[0], outline=INK)
    d.polygon([(11, 6), (15, 4), (18, 6), (18, 27), (15, 28), (11, 26)], fill=STEEL[2])
    for y in (8, 12, 16, 20, 24):
        d.line([(7, y), (21, y - 3), (25, y), (22, y + 3), (9, y + 4), (7, y)], fill=INK, width=3)
        d.line([(8, y), (21, y - 2), (24, y), (21, y + 2), (9, y + 3)], fill="#ad6035", width=2)
        d.line([(9, y), (20, y - 2)], fill="#edb16a")
    d.line([(24, 9), (28, 7), (28, 4)], fill="#b87942", width=2)
    d.line([(8, 24), (4, 26), (4, 29)], fill="#b87942", width=2)
    return im


def copper_winding_detail():
    im, d = portrait()
    poly(d, [(30, 12), (47, 5), (64, 14), (64, 80), (47, 89), (29, 79)], STEEL[0])
    poly(d, [(34, 16), (46, 11), (52, 15), (52, 81), (46, 84), (34, 77)], STEEL[2], None)
    line(d, [(36, 19), (36, 73)], STEEL[3], 2)
    poly(d, [(31, 14), (47, 8), (61, 15), (47, 22)], STEEL[1])
    line(d, [(34, 14), (46, 11), (55, 15)], STEEL[4])
    for y in (26, 37, 48, 59, 70):
        line(d, [(24, y), (57, y - 8), (72, y - 2), (69, y + 7), (36, y + 14), (22, y + 8), (24, y)], INK, 8)
        line(d, [(25, y), (57, y - 7), (69, y - 2), (67, y + 5), (36, y + 11), (25, y + 7), (25, y)], "#96502f", 5)
        line(d, [(25, y), (55, y - 6), (65, y - 3)], "#e6a565", 3)
        line(d, [(29, y - 1), (52, y - 6)], "#ffcf83")
        line(d, [(68, y), (66, y + 4), (43, y + 9)], "#603e2d", 2)
    line(d, [(68, 26), (80, 20), (80, 10)], INK, 6)
    line(d, [(68, 26), (79, 19), (79, 10)], "#ca7e44", 3)
    line(d, [(27, 77), (15, 81), (15, 89)], INK, 6)
    line(d, [(27, 77), (16, 82), (16, 88)], "#ca7e44", 3)
    d.rectangle((76, 8, 82, 13), fill=STEEL[1], outline=INK)
    d.rectangle((13, 86, 19, 91), fill=STEEL[1], outline=INK)
    d.point((77, 9), fill=STEEL[4])
    d.point((14, 87), fill=STEEL[4])
    return im


def pitch_sealed_sling_icon():
    im, d = canvas()
    d.line([(5, 3), (7, 13), (12, 21)], fill=INK, width=3)
    d.line([(5, 3), (8, 13), (13, 20)], fill="#b39861")
    d.line([(27, 3), (25, 14), (20, 22)], fill=INK, width=3)
    d.line([(27, 3), (24, 14), (19, 21)], fill="#b39861")
    d.polygon([(7, 18), (13, 15), (22, 17), (26, 23), (21, 29), (11, 28), (6, 23)], fill="#634a33", outline=INK)
    d.polygon([(10, 19), (15, 18), (21, 20), (22, 24), (18, 26), (12, 25)], fill="#a17c4b")
    d.polygon([(9, 23), (13, 21), (16, 24), (21, 23), (23, 25), (20, 28), (12, 27)], fill="#28332c")
    d.line([(10, 19), (14, 18), (18, 19)], fill="#c7a66b")
    d.line([(8, 21), (10, 24)], fill=BONE[1])
    d.line([(23, 20), (23, 23)], fill=BONE[1])
    return im


def pitch_sealed_sling_detail():
    im, d = portrait()
    line(d, [(14, 7), (19, 35), (33, 61)], INK, 7)
    line(d, [(14, 7), (21, 35), (34, 61)], "#aa8b57", 3)
    line(d, [(79, 8), (75, 32), (60, 60)], INK, 7)
    line(d, [(79, 8), (73, 32), (59, 60)], "#aa8b57", 3)
    for x, y in ((16, 17), (18, 26), (23, 39), (77, 16), (75, 25), (70, 38)):
        line(d, [(x - 2, y), (x + 2, y + 2)], "#e0c58b")
    poly(d, [(22, 54), (38, 46), (61, 49), (77, 65), (72, 78), (58, 87), (33, 84), (18, 70)], "#664831")
    poly(d, [(27, 57), (40, 51), (58, 54), (69, 65), (64, 75), (54, 80), (36, 77), (25, 67)], "#aa8050", None)
    poly(d, [(32, 58), (44, 54), (58, 57), (65, 65), (57, 73), (41, 72), (31, 66)], "#765734", None)
    line(d, [(30, 58), (41, 54), (52, 56)], "#d0aa70", 2)
    poly(d, [(21, 68), (32, 64), (43, 70), (48, 67), (58, 72), (69, 67), (73, 75), (60, 85), (35, 82), (23, 74)], "#26332b")
    line(d, [(26, 70), (32, 68), (41, 73), (48, 71)], "#51604b", 2)
    line(d, [(58, 77), (64, 75), (66, 72)], "#51604b")
    for x, y in ((25, 60), (27, 66), (32, 74), (38, 79), (64, 58), (69, 64), (68, 71), (62, 78)):
        line(d, [(x - 2, y - 1), (x + 1, y + 2)], BONE[1], 2)
    poly(d, [(27, 50), (32, 48), (35, 54), (31, 58), (27, 56)], "#533d2c")
    poly(d, [(63, 51), (68, 53), (67, 59), (62, 60), (60, 56)], "#533d2c")
    line(d, [(29, 51), (32, 54)], BONE[1])
    line(d, [(64, 54), (65, 57)], BONE[1])
    return im


def menders_spool_icon():
    im, d = canvas()
    d.ellipse((7, 22, 24, 29), fill="#725338", outline=INK)
    d.rectangle((9, 9, 22, 25), fill=PURPLE[1], outline=INK)
    for y in (11, 14, 17, 20, 23):
        d.line([(10, y), (21, y - 1)], fill=PURPLE[3])
    d.ellipse((6, 5, 25, 12), fill="#b8935b", outline=INK)
    d.ellipse((13, 7, 18, 10), fill="#3e3427", outline=INK)
    d.line([(9, 7), (12, 6)], fill=BONE[2])
    d.line([(23, 6), (7, 29)], fill=INK, width=3)
    d.line([(23, 6), (7, 29)], fill=STEEL[3])
    d.line([(20, 9), (22, 7)], fill=INK)
    d.line([(22, 22), (28, 22), (29, 26), (26, 29)], fill=PURPLE[2])
    return im


def menders_spool_detail():
    im, d = portrait()
    d.ellipse((22, 66, 73, 87), fill="#775236", outline=INK, width=2)
    d.arc((25, 68, 70, 83), 0, 170, fill="#b88c53", width=3)
    poly(d, [(28, 29), (66, 29), (66, 74), (57, 80), (36, 79), (28, 73)], PURPLE[1])
    poly(d, [(30, 31), (42, 32), (42, 77), (34, 75), (30, 70)], PURPLE[2], None)
    for y in (35, 40, 45, 50, 55, 60, 65, 70):
        line(d, [(31, y), (49, y + 1), (64, y - 3)], PURPLE[3], 2)
        line(d, [(32, y + 2), (48, y + 3), (63, y - 1)], "#563355")
    d.ellipse((20, 15, 74, 37), fill="#ae844c", outline=INK, width=2)
    d.ellipse((25, 18, 69, 31), fill="#cba66a", outline=INK)
    d.ellipse((40, 21, 53, 28), fill="#4a3b2b", outline=INK, width=2)
    line(d, [(28, 22), (36, 19), (52, 19)], BONE[2], 2)
    line(d, [(29, 28), (35, 30)], "#81613c")
    line(d, [(74, 15), (18, 87)], INK, 5)
    line(d, [(73, 16), (19, 86)], STEEL[3], 2)
    line(d, [(65, 26), (70, 20)], STEEL[0], 2)
    line(d, [(64, 25), (68, 20)], STEEL[4])
    line(d, [(66, 66), (81, 65), (87, 71), (84, 82), (76, 87), (68, 83)], PURPLE[2], 3)
    line(d, [(66, 65), (79, 64), (84, 68)], PURPLE[3])
    line(d, [(46, 79), (51, 80)], "#e6bd79")
    return im


def mooncap_jerky_icon():
    im, d = canvas()
    d.polygon([(6, 9), (15, 5), (25, 9), (23, 25), (17, 29), (7, 26)], fill="#563b35", outline=INK)
    d.polygon([(8, 11), (15, 8), (22, 11), (20, 23), (15, 26), (9, 24)], fill="#98624f")
    d.line([(10, 12), (19, 14), (10, 18), (19, 20), (13, 24)], fill="#c88c66")
    d.polygon([(15, 7), (17, 3), (23, 3), (27, 6), (26, 10), (19, 11)], fill=PURPLE[1], outline=INK)
    d.line([(18, 5), (22, 4), (25, 6)], fill=PURPLE[3])
    d.rectangle((20, 7, 22, 8), fill=BONE[2])
    d.line([(5, 14), (24, 19)], fill=INK, width=3)
    d.line([(5, 14), (24, 19)], fill="#bd9b61")
    d.polygon([(13, 16), (17, 16), (19, 19), (15, 21), (12, 19)], fill=GREEN[1], outline=INK)
    return im


def mooncap_jerky_detail():
    im, d = portrait()
    poly(d, [(21, 30), (43, 17), (70, 27), (75, 44), (67, 76), (49, 87), (24, 78), (17, 58)], "#51382f")
    poly(d, [(25, 34), (43, 23), (64, 31), (68, 45), (61, 71), (47, 81), (29, 73), (23, 56)], "#975e49", None)
    poly(d, [(32, 34), (43, 28), (60, 34), (62, 43), (54, 67), (44, 75), (33, 68), (28, 51)], "#b47758", None)
    line(d, [(30, 40), (39, 37), (58, 43), (37, 49), (57, 55), (35, 61), (49, 68)], "#d09b70", 3)
    line(d, [(29, 44), (47, 49), (32, 53)], "#704633", 2)
    line(d, [(49, 33), (58, 36), (62, 40)], "#e1b07b")
    poly(d, [(47, 23), (50, 12), (63, 7), (76, 12), (83, 22), (79, 31), (61, 34)], PURPLE[1])
    poly(d, [(51, 21), (55, 14), (64, 11), (73, 15), (78, 22), (65, 25)], PURPLE[2], None)
    line(d, [(54, 20), (60, 15), (68, 15)], PURPLE[3], 2)
    line(d, [(53, 27), (62, 30), (77, 27)], BONE[1], 2)
    line(d, [(58, 27), (61, 31)], "#5b4158")
    line(d, [(66, 27), (65, 32)], "#5b4158")
    d.rectangle((64, 18, 69, 21), fill=BONE[2])
    d.rectangle((74, 22, 76, 24), fill=BONE[2])
    line(d, [(16, 46), (71, 61)], INK, 6)
    line(d, [(17, 45), (70, 59)], "#c5a16a", 3)
    poly(d, [(37, 48), (47, 49), (55, 55), (48, 63), (38, 60), (33, 55)], GREEN[1])
    line(d, [(36, 53), (46, 52), (51, 55)], GREEN[3], 2)
    line(d, [(46, 57), (51, 63), (52, 70)], "#c5a16a", 2)
    for x, y in ((31, 37), (55, 47), (38, 69), (59, 62)):
        d.point((x, y), fill=BONE[2])
    return im


def counting_frame_icon():
    im, d = canvas()
    d.polygon([(5, 6), (25, 3), (28, 6), (28, 25), (8, 29), (4, 26)], fill="#755032", outline=INK)
    d.polygon([(8, 9), (24, 6), (24, 23), (8, 26)], fill="#29362b", outline=INK)
    for y in (11, 16, 21):
        d.line([(8, y + 2), (24, y - 1)], fill=STEEL[2])
    for x, y in ((11, 11), (15, 10), (20, 14), (12, 21), (17, 20), (21, 19)):
        d.rectangle((x - 1, y - 1, x + 2, y + 3), fill=GOLD[1], outline=INK)
        d.line([(x, y), (x, y + 2)], fill=GOLD[3])
    d.line([(6, 7), (24, 4)], fill="#c9a467")
    d.line([(6, 8), (6, 25)], fill="#af844c")
    d.point((25, 25), fill=GOLD[3])
    return im


def counting_frame_detail():
    im, d = portrait()
    poly(d, [(15, 19), (72, 7), (82, 16), (82, 75), (25, 90), (14, 81)], "#62432f")
    poly(d, [(24, 29), (71, 18), (71, 68), (25, 80)], "#27372b")
    poly(d, [(17, 22), (23, 25), (24, 85), (17, 79)], "#ad8049", None)
    poly(d, [(19, 19), (70, 10), (77, 15), (25, 27)], "#bb9255", None)
    poly(d, [(73, 20), (78, 18), (78, 72), (73, 74)], "#805a36", None)
    line(d, [(22, 19), (68, 12)], "#e0bd7f", 2)
    line(d, [(18, 30), (18, 73)], "#d3ac6e")
    for y in (34, 48, 62):
        line(d, [(25, y + 7), (71, y - 4)], INK, 4)
        line(d, [(25, y + 6), (71, y - 5)], STEEL[2], 2)
    for x, y in ((32, 36), (44, 33), (57, 43), (65, 41), (33, 65), (45, 62), (57, 59)):
        poly(d, [(x - 4, y - 4), (x + 2, y - 6), (x + 5, y - 2), (x + 5, y + 6), (x, y + 9), (x - 4, y + 5)], GOLD[1])
        line(d, [(x - 2, y - 2), (x + 1, y - 3), (x + 2, y + 3), (x, y + 5)], GOLD[3], 2)
        d.point((x - 1, y - 2), fill=GOLD[4])
        line(d, [(x + 3, y), (x + 3, y + 5)], GOLD[0])
    for x, y in ((20, 23), (75, 16), (20, 80), (76, 74)):
        rivet(d, x, y, GOLD)
    line(d, [(29, 83), (40, 80), (45, 80)], "#b68b51")
    line(d, [(73, 46), (74, 51), (73, 57)], "#4a382b")
    return im


RENDERERS = {
    "steel_arrowhead": (steel_arrowhead_icon, steel_arrowhead_detail),
    "balanced_mechanism": (balanced_mechanism_icon, balanced_mechanism_detail),
    "lucky_fang": (lucky_fang_icon, lucky_fang_detail),
    "siege_scope": (siege_scope_icon, siege_scope_detail),
    "lightweight_ammunition": (lightweight_ammunition_icon, lightweight_ammunition_detail),
    "heavy_bolts": (heavy_bolts_icon, heavy_bolts_detail),
    "resonant_drumsticks": (resonant_drumsticks_icon, resonant_drumsticks_detail),
    "oversized_bucket": (oversized_bucket_icon, oversized_bucket_detail),
    "trollhide_earplugs": (trollhide_earplugs_icon, trollhide_earplugs_detail),
    "gravediggers_lantern": (gravediggers_lantern_icon, gravediggers_lantern_detail),
    "peppercorn_skewer": (peppercorn_skewer_icon, peppercorn_skewer_detail),
    "surveyors_fieldbook": (surveyors_fieldbook_icon, surveyors_fieldbook_detail),
    "riveted_bracer": (riveted_bracer_icon, riveted_bracer_detail),
    "copper_winding": (copper_winding_icon, copper_winding_detail),
    "pitch_sealed_sling": (pitch_sealed_sling_icon, pitch_sealed_sling_detail),
    "menders_spool": (menders_spool_icon, menders_spool_detail),
    "mooncap_jerky": (mooncap_jerky_icon, mooncap_jerky_detail),
    "counting_frame": (counting_frame_icon, counting_frame_detail),
}
