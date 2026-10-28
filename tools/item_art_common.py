"""Common guide equipment: native 32px silhouettes and separate 96px studies."""
from author_items import (
    canvas, portrait, poly, line, rivet, gleam, gem,
    INK, GOLD, BONE, GREEN, STEEL, RED,
)

TIER = 0
WOOD = ("#382d25", "#69482f", "#9b7044", "#cfaa70")
COPPER = ("#54362c", "#925238", "#c67e4b", "#f0b976")
CLOTH = ("#343c31", "#637247", "#98a366", "#c9ce92")

ITEMS = [
    {"id": "iron_arrowhead", "title": "Iron Arrowhead", "effect": "Attacking towers deal 5% more damage.", "mechanics": ["All attacking towers; +5% damage.", "No change to support or mine output."]},
    {"id": "oiled_gears", "title": "Oiled Gears", "effect": "Attacking towers gain 5% attack speed.", "mechanics": ["All attacking towers; +5% attack speed.", "No change to support or production clocks."]},
    {"id": "heavy_ammunition", "title": "Heavy Ammunition", "effect": "Attacking towers deal 12% more damage but lose 5% attack speed.", "mechanics": ["All attacking towers; +12% damage.", "Attack speed -5%; support unaffected."]},
    {"id": "short_bowstring", "title": "Short Bowstring", "effect": "Arrow towers deal 10% more damage but lose 0.25 attack range.", "mechanics": ["Arrow family only; +10% damage.", "Attack range -0.25 tiles; no support coverage change."]},
    {"id": "greased_winch", "title": "Greased Winch", "effect": "Ballista towers gain 8% attack speed.", "mechanics": ["Ballista family only; +8% attack speed.", "Damage and attack range stay unchanged."]},
    {"id": "chipped_runestone", "title": "Chipped Runestone", "effect": "Rune towers deal 8% more damage.", "mechanics": ["Rune family only; +8% damage.", "Elemental immunities still apply."]},
    {"id": "copper_coil", "title": "Copper Coil", "effect": "Lightning towers deal 8% more damage.", "mechanics": ["Lightning family only; +8% damage.", "No extra chain targets or immunity bypass."]},
    {"id": "sturdy_pickaxe", "title": "Sturdy Pickaxe", "effect": "Coin-producing Gold Mines and Royal Mints produce 8% more Coins.", "mechanics": ["Coin mine clear and periodic production +8%.", "No bounty, Shard, send-income or interest bonus."]},
    {"id": "taut_drumskin", "title": "Taut Drumskin", "effect": "War Drums gain 5% support strength, without wider coverage.", "mechanics": ["War Drums: +5% to retained support components.", "Pure branches stay pure; coverage unchanged.", "Only the strongest support bonus per stat applies."]},
    {"id": "copper_tooth", "title": "Copper Tooth", "effect": "The board's first bounty-paying kill each wave grants 1 extra Coin.", "mechanics": ["One +1 Coin bonus per board per wave.", "Requires a kill that already pays bounty; leaks do not count."]},
    {"id": "leather_bracer", "title": "Leather Bracer", "effect": "Physical Arrow and Ballista attacks deal 4% more damage.", "mechanics": ["Physical Arrow and Ballista branches only.", "+4% damage; elemental branches receive no bonus."]},
    {"id": "salted_rations", "title": "Salted Rations", "effect": "Attacking towers deal 7% more damage but lose 3% attack speed.", "mechanics": ["All attacking towers; +7% damage.", "Attack speed -3%; support and mines unaffected."]},
    {"id": "field_manual", "title": "Field Manual", "effect": "Rune towers gain 0.25 attack range.", "mechanics": ["Rune family only; +0.25 tiles of attack reach.", "Support coverage and blast radii stay unchanged."]},
    {"id": "reed_whistle", "title": "Reed Whistle", "effect": "Attacking towers gain 4% attack speed.", "mechanics": ["All attacking towers; +4% attack speed.", "Does not strengthen or extend support auras."]},
    {"id": "flint_striker", "title": "Flint Striker", "effect": "Fire Arrow branches deal 8% more direct fire damage.", "mechanics": ["Fire Arrow branches: direct fire damage +8%.", "Burn damage unchanged; fire immunity still applies."]},
    {"id": "snail_shell", "title": "Snail Shell", "effect": "Attacking towers gain 0.25 range but lose 5% attack speed.", "mechanics": ["All attacking towers; +0.25 tiles of attack reach.", "Attack speed -5%; no support coverage bonus."]},
    {"id": "woven_sling", "title": "Woven Sling", "effect": "Orcapult towers deal 8% more damage.", "mechanics": ["Orcapult family only; +8% damage.", "Crew count, reload time and blast radius unchanged."]},
]


def _rod(d, points, width, ramp=WOOD):
    line(d, points, INK, width + 2)
    line(d, points, ramp[1], width)
    line(d, [(x - 1, y - 1) for x, y in points], ramp[2], max(1, width // 3))


def _gear(d, x, y, r, ramp=STEEL):
    # Four broad squared teeth and four corner teeth, never a generic cog badge.
    w = max(2, r // 3)
    d.rectangle((x - w, y - r - 2, x + w, y + r + 2), fill=ramp[1], outline=INK)
    d.rectangle((x - r - 2, y - w, x + r + 2, y + w), fill=ramp[1], outline=INK)
    for dx, dy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        cx, cy = x + dx * (r - w), y + dy * (r - w)
        d.rectangle((cx - w, cy - w, cx + w, cy + w), fill=ramp[1], outline=INK)
    d.ellipse((x - r, y - r, x + r, y + r), fill=ramp[1], outline=INK)
    d.arc((x - r + 1, y - r + 1, x + r - 1, y + r - 1), 180, 280, fill=ramp[3], width=max(1, r // 5))
    hole = max(1, r // 3)
    d.ellipse((x - hole, y - hole, x + hole, y + hole), fill=INK)
    d.point((x - hole, y - hole), fill=ramp[2])


def iron_arrowhead_icon():
    im, d = canvas()
    poly(d, [(7, 22), (8, 14), (24, 3), (28, 4), (25, 21), (17, 24), (15, 29), (10, 27)], STEEL[1], width=1)
    poly(d, [(10, 16), (25, 5), (18, 20), (10, 23)], STEEL[3], outline=None)
    poly(d, [(25, 6), (23, 20), (18, 21)], STEEL[0], outline=None)
    line(d, [(12, 23), (25, 5)], STEEL[2])
    line(d, [(12, 24), (14, 25), (12, 28)], WOOD[3], 2)
    line(d, [(9, 20), (12, 18)], STEEL[4])
    d.point((19, 15), fill=STEEL[0])
    return im


def iron_arrowhead_detail():
    im, d = portrait()
    poly(d, [(17, 65), (22, 40), (71, 10), (82, 12), (72, 61), (50, 70), (43, 86), (29, 83)], STEEL[0])
    poly(d, [(23, 62), (28, 43), (76, 15), (55, 54), (40, 67)], STEEL[2], outline=None)
    poly(d, [(29, 44), (70, 20), (49, 50), (24, 62)], STEEL[3], outline=None)
    poly(d, [(78, 17), (68, 58), (49, 64), (56, 52)], STEEL[1], outline=None)
    line(d, [(38, 67), (56, 51), (78, 15)], STEEL[4], 2)
    line(d, [(25, 46), (66, 21)], STEEL[4])
    poly(d, [(30, 67), (40, 69), (37, 80), (31, 79), (27, 76)], WOOD[1], width=1)
    for y in (69, 73, 77, 81):
        line(d, [(28, y), (40, y + 3)], BONE[1], 2)
        d.point((30, y), fill=BONE[3])
    line(d, [(58, 34), (55, 37), (59, 37)], STEEL[0])
    line(d, [(62, 55), (64, 51), (68, 51)], STEEL[0])
    line(d, [(30, 57), (34, 54)], STEEL[4])
    line(d, [(45, 41), (48, 39)], STEEL[1])
    d.point((69, 26), fill=STEEL[4])
    return im


def oiled_gears_icon():
    im, d = canvas()
    _gear(d, 21, 11, 7, COPPER)
    _gear(d, 11, 21, 7)
    poly(d, [(22, 18), (25, 23), (25, 27), (22, 29), (19, 27), (19, 24)], "#393c2d", width=1)
    line(d, [(21, 24), (21, 26)], GOLD[2])
    d.point((22, 23), fill=GOLD[3])
    return im


def oiled_gears_detail():
    im, d = portrait()
    _gear(d, 62, 31, 20, COPPER)
    _gear(d, 31, 63, 22)
    # Recessed spoke windows and hand-filed teeth distinguish the two wheels.
    for box in ((54, 19, 59, 25), (68, 25, 73, 31), (58, 38, 63, 43)):
        d.rectangle(box, fill=COPPER[0], outline=INK)
    for pts in ([(19, 55), (25, 49), (28, 54), (24, 58)],
                [(38, 53), (45, 58), (40, 62), (36, 58)],
                [(33, 72), (38, 75), (32, 81), (28, 76)]):
        poly(d, pts, STEEL[0], width=1)
    d.ellipse((25, 57, 37, 69), fill=WOOD[0], outline=INK)
    line(d, [(28, 58), (35, 65)], STEEL[3], 2)
    for x, y in ((18, 44), (48, 65), (34, 83), (62, 11), (78, 36)):
        line(d, [(x, y), (x + 3, y - 1)], BONE[2])
    poly(d, [(69, 59), (77, 70), (79, 78), (75, 86), (66, 87), (60, 81), (61, 74)], "#353a2d", width=1)
    poly(d, [(67, 70), (70, 66), (73, 74), (69, 81), (65, 80)], "#7c7540", outline=None)
    line(d, [(65, 74), (64, 79), (67, 82)], GOLD[3], 2)
    line(d, [(48, 42), (48, 48), (44, 51)], "#363a2c", 3)
    d.point((67, 73), fill=GOLD[4])
    return im


def heavy_ammunition_icon():
    im, d = canvas()
    # Three lead slugs cradled by a folded leather ammunition belt.
    poly(d, [(3, 14), (26, 7), (29, 24), (7, 30)], WOOD[1], width=1)
    for x, y in ((6, 10), (14, 7), (22, 5)):
        d.ellipse((x, y, x + 6, y + 10), fill=STEEL[1], outline=INK)
        d.ellipse((x + 1, y + 1, x + 4, y + 4), fill=STEEL[3])
        d.rectangle((x, y + 7, x + 6, y + 12), fill=STEEL[0], outline=INK)
    poly(d, [(5, 22), (27, 15), (28, 23), (7, 29)], WOOD[2], width=1)
    line(d, [(8, 24), (25, 19)], WOOD[3])
    d.rectangle((15, 21, 19, 25), fill=GOLD[2], outline=INK)
    return im


def heavy_ammunition_detail():
    im, d = portrait()
    poly(d, [(9, 42), (78, 18), (88, 73), (23, 90)], WOOD[0])
    poly(d, [(13, 43), (76, 23), (83, 69), (25, 85)], WOOD[1], outline=None)
    for x, y in ((17, 27), (40, 20), (63, 12)):
        d.ellipse((x, y, x + 18, y + 33), fill=STEEL[1], outline=INK, width=2)
        d.ellipse((x + 3, y + 3, x + 13, y + 15), fill=STEEL[2])
        line(d, [(x + 5, y + 5), (x + 4, y + 14)], STEEL[4], 2)
        d.rectangle((x, y + 25, x + 18, y + 40), fill=STEEL[0], outline=INK, width=2)
        line(d, [(x + 2, y + 28), (x + 15, y + 28)], STEEL[2])
        line(d, [(x + 4, y + 33), (x + 13, y + 35)], STEEL[1])
    poly(d, [(16, 65), (82, 43), (86, 71), (24, 87)], WOOD[2])
    line(d, [(21, 67), (79, 49)], WOOD[3], 2)
    line(d, [(25, 82), (80, 68)], WOOD[0])
    for x, y in ((25, 66), (34, 63), (68, 53), (77, 50), (30, 80), (72, 69)):
        line(d, [(x, y), (x + 1, y + 4)], BONE[1])
    poly(d, [(45, 61), (58, 57), (61, 75), (48, 79)], GOLD[1], width=1)
    poly(d, [(48, 64), (55, 62), (57, 72), (50, 74)], INK, width=1)
    line(d, [(45, 62), (57, 58)], GOLD[3], 2)
    line(d, [(52, 64), (53, 75)], STEEL[2], 2)
    rivet(d, 25, 71, GOLD)
    rivet(d, 76, 57, GOLD)
    return im


def short_bowstring_icon():
    im, d = canvas()
    line(d, [(9, 4), (21, 10), (25, 16), (21, 23), (9, 28)], INK, 5)
    line(d, [(9, 4), (21, 10), (25, 16), (21, 23), (9, 28)], WOOD[2], 3)
    line(d, [(9, 4), (14, 16), (9, 28)], BONE[2])
    line(d, [(12, 16), (28, 16)], INK, 3)
    line(d, [(12, 15), (27, 15)], WOOD[3])
    poly(d, [(25, 12), (30, 15), (25, 18)], STEEL[2], width=1)
    line(d, [(23, 14), (23, 19)], WOOD[0], 3)
    line(d, [(23, 14), (23, 18)], BONE[1])
    return im


def short_bowstring_detail():
    im, d = portrait()
    # A short recurved bow shown braced; its thick string bends around the nock.
    line(d, [(25, 9), (38, 16), (58, 29), (68, 45), (65, 58), (50, 73), (24, 87)], INK, 10)
    line(d, [(25, 9), (38, 16), (58, 29), (68, 45), (65, 58), (50, 73), (24, 87)], WOOD[1], 7)
    line(d, [(25, 8), (39, 15), (58, 28), (66, 44), (63, 57), (49, 72), (24, 85)], WOOD[3], 2)
    line(d, [(26, 11), (39, 46), (25, 85)], WOOD[0], 3)
    line(d, [(26, 11), (38, 46), (25, 85)], BONE[2])
    _rod(d, [(19, 47), (83, 47)], 3)
    poly(d, [(78, 38), (89, 47), (77, 55), (81, 47)], STEEL[1], width=1)
    poly(d, [(80, 41), (87, 47), (81, 47)], STEEL[3], outline=None)
    poly(d, [(20, 46), (13, 38), (25, 41), (30, 46)], RED[1], width=1)
    poly(d, [(20, 49), (14, 57), (25, 54), (30, 49)], RED[2], width=1)
    for y in (37, 41, 45, 49, 53, 57):
        line(d, [(62, y), (70, y + 1)], WOOD[0], 2)
        line(d, [(62, y), (68, y + 1)], BONE[1])
    for x, y in ((31, 12), (53, 25), (48, 73), (30, 84)):
        line(d, [(x, y), (x + 2, y + 3)], WOOD[0])
    line(d, [(19, 42), (24, 45)], RED[3])
    line(d, [(20, 54), (25, 51)], RED[3])
    return im


def greased_winch_icon():
    im, d = canvas()
    poly(d, [(5, 9), (9, 7), (12, 26), (7, 29)], WOOD[2], width=1)
    poly(d, [(23, 5), (27, 7), (26, 24), (22, 26)], WOOD[1], width=1)
    _rod(d, [(9, 16), (24, 13)], 6, STEEL)
    for x in (12, 15, 18, 21):
        line(d, [(x, 12), (x + 1, 18)], BONE[1], 2)
    _rod(d, [(25, 13), (28, 17), (27, 22)], 2, COPPER)
    line(d, [(16, 18), (14, 28)], BONE[2])
    d.rectangle((14, 22, 15, 25), fill="#303b2e")
    return im


def greased_winch_detail():
    im, d = portrait()
    poly(d, [(15, 26), (27, 21), (36, 78), (23, 87)], WOOD[1])
    poly(d, [(66, 16), (76, 21), (76, 71), (63, 79)], WOOD[0])
    poly(d, [(18, 29), (24, 27), (31, 74), (25, 79)], WOOD[2], outline=None)
    line(d, [(20, 31), (25, 67), (23, 72)], WOOD[3])
    poly(d, [(27, 37), (65, 26), (70, 48), (31, 59)], STEEL[0])
    poly(d, [(30, 37), (64, 29), (67, 42), (33, 51)], STEEL[2], outline=None)
    for x, y in ((34, 37), (41, 35), (48, 33), (55, 31), (62, 29)):
        line(d, [(x, y), (x + 4, y + 20)], WOOD[0], 5)
        line(d, [(x, y), (x + 4, y + 18)], BONE[1], 3)
        line(d, [(x, y + 1), (x + 1, y + 7)], BONE[3])
    line(d, [(47, 54), (45, 74), (49, 84)], BONE[0], 4)
    line(d, [(46, 54), (44, 74), (48, 84)], BONE[2], 2)
    _rod(d, [(73, 38), (85, 48), (81, 66)], 5, COPPER)
    _rod(d, [(81, 61), (87, 63)], 6)
    d.ellipse((66, 31, 76, 43), fill=STEEL[1], outline=INK, width=2)
    rivet(d, 70, 35, GOLD)
    rivet(d, 25, 42)
    rivet(d, 28, 62)
    poly(d, [(34, 54), (38, 52), (41, 58), (39, 65), (35, 63)], "#3d4430", width=1)
    line(d, [(36, 55), (38, 61)], GOLD[2])
    line(d, [(69, 58), (70, 69)], WOOD[2])
    return im


def chipped_runestone_icon():
    im, d = canvas()
    poly(d, [(10, 3), (23, 5), (26, 12), (23, 16), (27, 21), (23, 28), (8, 29), (5, 21), (7, 10)], "#535d55", width=1)
    poly(d, [(11, 5), (21, 7), (22, 12), (20, 17), (23, 22), (20, 26), (9, 26), (8, 20)], "#929d83", outline=None)
    line(d, [(16, 9), (12, 14), (19, 16), (13, 22)], "#34454c", 3)
    line(d, [(16, 9), (12, 14), (19, 16), (13, 22)], "#8ec0c2")
    line(d, [(9, 6), (8, 15)], BONE[2])
    line(d, [(22, 23), (18, 25)], "#bdc5a0")
    return im


def chipped_runestone_detail():
    im, d = portrait()
    poly(d, [(27, 9), (65, 12), (77, 32), (67, 47), (79, 63), (67, 83), (24, 88), (14, 66), (20, 29)], "#39463f")
    poly(d, [(30, 13), (62, 17), (68, 31), (59, 47), (70, 64), (62, 78), (27, 82), (20, 64), (26, 30)], "#7a8976", outline=None)
    poly(d, [(30, 16), (52, 18), (46, 40), (50, 65), (28, 80), (23, 62)], "#a5ae8f", outline=None)
    poly(d, [(64, 20), (73, 32), (63, 46), (55, 45)], "#535f56", outline=None)
    line(d, [(45, 27), (34, 40), (56, 48), (38, 66)], "#2e4349", 7)
    line(d, [(45, 27), (34, 40), (56, 48), (38, 66)], "#74a9ab", 3)
    line(d, [(44, 28), (35, 39), (47, 43)], "#c1dfcc")
    line(d, [(51, 52), (40, 64)], "#c1dfcc")
    line(d, [(29, 16), (25, 31), (22, 49)], BONE[2], 2)
    line(d, [(58, 17), (62, 23), (58, 29)], "#4a5950")
    line(d, [(25, 66), (31, 69), (30, 77)], "#536451")
    line(d, [(61, 65), (57, 72), (61, 76)], "#b5bea0")
    # Exposed granular fracture and a detached chip, not a glow cloud.
    poly(d, [(69, 47), (76, 53), (70, 58), (64, 52)], "#bbc3a8", width=1)
    poly(d, [(80, 76), (85, 79), (82, 85), (76, 83)], "#788674", width=1)
    for x, y in ((28, 26), (31, 24), (57, 66), (56, 70), (35, 76), (62, 36)):
        d.point((x, y), fill="#d1d7b8")
    return im


def copper_coil_icon():
    im, d = canvas()
    _rod(d, [(9, 8), (23, 25)], 7, STEEL)
    for x, y in ((8, 9), (12, 13), (16, 17), (20, 21)):
        d.arc((x - 4, y - 5, x + 8, y + 5), 120, 440, fill=INK, width=4)
        d.arc((x - 3, y - 4, x + 7, y + 4), 120, 440, fill=COPPER[2], width=2)
        d.point((x, y - 4), fill=COPPER[3])
    line(d, [(7, 8), (5, 5), (9, 3)], COPPER[2], 2)
    line(d, [(25, 25), (28, 28)], COPPER[2], 2)
    return im


def copper_coil_detail():
    im, d = portrait()
    _rod(d, [(29, 24), (68, 70)], 19, STEEL)
    line(d, [(22, 19), (12, 18), (10, 29), (17, 32)], INK, 6)
    line(d, [(22, 19), (12, 18), (10, 29), (17, 32)], COPPER[2], 3)
    for x, y in ((26, 25), (35, 35), (44, 45), (53, 55), (62, 65)):
        d.arc((x - 14, y - 14, x + 19, y + 13), 115, 440, fill=INK, width=10)
        d.arc((x - 12, y - 12, x + 17, y + 11), 115, 440, fill=COPPER[1], width=7)
        d.arc((x - 11, y - 12, x + 16, y + 9), 180, 290, fill=COPPER[3], width=3)
        line(d, [(x + 13, y + 4), (x + 10, y + 8)], COPPER[0], 2)
    poly(d, [(62, 74), (69, 69), (77, 76), (71, 83)], STEEL[0], width=1)
    line(d, [(65, 75), (70, 72)], STEEL[3], 2)
    line(d, [(74, 72), (84, 73), (84, 83), (78, 86)], INK, 6)
    line(d, [(74, 72), (84, 73), (84, 83), (78, 86)], COPPER[2], 3)
    line(d, [(78, 85), (80, 85)], STEEL[3], 2)
    # Verdigris in two sheltered recesses, with bright polished wire crowns.
    line(d, [(25, 42), (29, 46)], "#537966", 2)
    line(d, [(43, 63), (46, 66)], "#537966", 2)
    d.point((23, 15), fill=STEEL[4])
    return im


def sturdy_pickaxe_icon():
    im, d = canvas()
    _rod(d, [(9, 28), (21, 8)], 3)
    poly(d, [(4, 11), (10, 5), (20, 4), (27, 9), (29, 17), (24, 12), (17, 10), (10, 10)], STEEL[1], width=1)
    poly(d, [(7, 10), (12, 6), (20, 6), (25, 10), (18, 8), (11, 9)], STEEL[3], outline=None)
    d.rectangle((16, 6, 21, 11), fill=STEEL[0], outline=INK)
    line(d, [(17, 7), (19, 7)], STEEL[2])
    line(d, [(10, 25), (13, 27)], BONE[1], 2)
    return im


def sturdy_pickaxe_detail():
    im, d = portrait()
    _rod(d, [(24, 84), (61, 19)], 8)
    line(d, [(25, 80), (40, 53), (44, 48)], WOOD[3])
    poly(d, [(10, 35), (20, 20), (39, 12), (60, 13), (76, 25), (87, 47), (75, 40), (62, 29), (43, 27), (27, 30)], STEEL[0])
    poly(d, [(15, 31), (24, 22), (41, 16), (59, 17), (73, 28), (78, 37), (61, 25), (43, 24), (26, 27)], STEEL[2], outline=None)
    line(d, [(18, 29), (27, 22), (43, 17), (57, 18)], STEEL[4], 2)
    poly(d, [(58, 15), (66, 20), (61, 33), (49, 28), (49, 18)], STEEL[1], width=1)
    poly(d, [(53, 19), (59, 19), (60, 24), (55, 27), (52, 25)], INK, width=1)
    line(d, [(56, 21), (58, 22)], WOOD[3], 2)
    line(d, [(30, 70), (38, 74)], WOOD[0], 6)
    for y in (68, 73, 78):
        line(d, [(28 - (y - 68) // 2, y), (35 - (y - 68) // 2, y + 4)], BONE[1], 2)
    line(d, [(23, 34), (30, 31), (34, 31)], STEEL[3])
    line(d, [(71, 29), (70, 32), (74, 35)], STEEL[0])
    line(d, [(39, 19), (36, 22)], STEEL[1])
    rivet(d, 62, 24)
    return im


def taut_drumskin_icon():
    im, d = canvas()
    poly(d, [(5, 11), (27, 10), (25, 25), (21, 29), (9, 27)], WOOD[1], width=1)
    for x in (8, 15, 22):
        line(d, [(x, 13), (x + 3, 25)], BONE[1])
        line(d, [(x + 5, 13), (x, 25)], BONE[1])
    d.ellipse((4, 4, 28, 17), fill=BONE[0], outline=INK)
    d.ellipse((6, 5, 26, 14), fill=BONE[2], outline=INK)
    d.arc((8, 6, 24, 13), 190, 320, fill=BONE[3])
    line(d, [(7, 24), (24, 26)], WOOD[3], 2)
    d.point((16, 10), fill=BONE[0])
    return im


def taut_drumskin_detail():
    im, d = portrait()
    poly(d, [(14, 34), (82, 32), (75, 76), (64, 87), (30, 83), (20, 72)], WOOD[0])
    poly(d, [(21, 39), (75, 36), (70, 73), (62, 81), (31, 77), (25, 69)], WOOD[1], outline=None)
    for x in (29, 40, 51, 62):
        line(d, [(x, 42), (x - 1, 76)], WOOD[2], 3)
        line(d, [(x + 4, 45), (x + 3, 72)], WOOD[0])
    for x in (23, 38, 53, 68):
        line(d, [(x, 37), (x + 8, 77)], INK, 4)
        line(d, [(x, 37), (x + 8, 77)], BONE[1], 2)
        line(d, [(x + 12, 38), (x, 75)], BONE[2], 2)
    d.ellipse((11, 14, 85, 49), fill=WOOD[1], outline=INK, width=2)
    d.ellipse((16, 15, 80, 43), fill=BONE[0], outline=INK, width=2)
    d.ellipse((20, 17, 77, 39), fill=BONE[2], outline=INK)
    d.arc((24, 19, 72, 36), 185, 315, fill=BONE[3], width=2)
    d.ellipse((41, 26, 55, 32), fill="#b1a476")
    for x, y in ((24, 26), (32, 21), (48, 19), (65, 22), (75, 28), (66, 37), (45, 41), (26, 35)):
        line(d, [(x, y), (x - 2, y - 3)], WOOD[1], 2)
        d.point((x, y), fill=BONE[3])
    line(d, [(24, 75), (34, 81), (64, 85), (74, 76)], WOOD[3], 3)
    line(d, [(27, 52), (29, 59), (25, 63)], WOOD[3])
    rivet(d, 32, 79, GOLD)
    rivet(d, 66, 81, GOLD)
    return im


def copper_tooth_icon():
    im, d = canvas()
    line(d, [(11, 13), (6, 9), (8, 4), (18, 3), (24, 8), (22, 14)], WOOD[0], 2)
    line(d, [(11, 12), (7, 8), (9, 5), (18, 4), (23, 8), (21, 13)], BONE[1])
    poly(d, [(10, 12), (19, 9), (24, 14), (20, 22), (14, 29), (13, 22), (8, 19)], COPPER[1], width=1)
    poly(d, [(11, 13), (17, 12), (18, 19), (14, 26), (14, 19), (10, 18)], COPPER[2], outline=None)
    line(d, [(11, 14), (13, 17), (13, 20)], COPPER[3])
    d.rectangle((13, 9, 18, 13), fill=STEEL[1], outline=INK)
    line(d, [(14, 10), (17, 10)], STEEL[3])
    return im


def copper_tooth_detail():
    im, d = portrait()
    line(d, [(31, 33), (17, 24), (20, 12), (43, 7), (66, 12), (77, 23), (69, 39)], INK, 5)
    line(d, [(31, 33), (17, 24), (20, 12), (43, 7), (66, 12), (77, 23), (69, 39)], WOOD[1], 3)
    line(d, [(30, 32), (18, 23), (21, 13), (43, 8), (65, 13)], BONE[1])
    poly(d, [(31, 34), (54, 26), (69, 39), (66, 55), (52, 74), (41, 88), (39, 67), (26, 58), (22, 44)], COPPER[0])
    poly(d, [(31, 38), (49, 32), (56, 43), (53, 60), (43, 78), (42, 62), (30, 55), (27, 44)], COPPER[2], outline=None)
    poly(d, [(52, 32), (64, 40), (61, 54), (52, 67), (57, 48)], COPPER[1], outline=None)
    poly(d, [(32, 39), (39, 37), (40, 55), (32, 51), (29, 44)], COPPER[3], outline=None)
    poly(d, [(34, 28), (52, 25), (57, 35), (39, 40)], STEEL[0], width=1)
    line(d, [(36, 30), (51, 27), (54, 32), (39, 36)], STEEL[2], 3)
    rivet(d, 44, 32, GOLD)
    line(d, [(47, 48), (43, 52), (48, 55), (43, 59)], COPPER[0])
    line(d, [(59, 43), (61, 47), (58, 51)], "#5c7e64", 2)
    line(d, [(30, 54), (35, 57)], "#5c7e64")
    for x, y in ((36, 42), (38, 47), (45, 66), (53, 38)):
        d.point((x, y), fill=GOLD[4])
    return im


def leather_bracer_icon():
    im, d = canvas()
    poly(d, [(8, 5), (20, 3), (26, 9), (25, 25), (14, 29), (7, 23)], WOOD[0], width=1)
    poly(d, [(10, 6), (19, 5), (21, 11), (20, 24), (14, 27), (9, 22)], WOOD[2], outline=None)
    for y in (11, 20):
        poly(d, [(7, y), (23, y - 3), (26, y), (9, y + 4)], WOOD[1], width=1)
        d.rectangle((17, y - 2, 22, y + 2), fill=STEEL[1], outline=INK)
        d.point((18, y - 1), fill=STEEL[3])
    line(d, [(11, 8), (12, 10)], WOOD[3])
    line(d, [(11, 16), (12, 18)], WOOD[3])
    return im


def leather_bracer_detail():
    im, d = portrait()
    poly(d, [(24, 16), (57, 9), (75, 26), (72, 76), (42, 88), (21, 71)], WOOD[0])
    poly(d, [(28, 20), (53, 14), (61, 31), (58, 75), (43, 82), (26, 69)], WOOD[2], outline=None)
    poly(d, [(58, 17), (69, 28), (66, 73), (59, 77), (64, 32)], WOOD[1], outline=None)
    line(d, [(30, 23), (28, 63), (43, 76), (54, 72)], WOOD[3], 2)
    for y in (33, 61):
        poly(d, [(21, y), (66, y - 12), (76, y - 3), (75, y + 6), (27, y + 17), (21, y + 10)], WOOD[1], width=1)
        line(d, [(25, y + 2), (65, y - 8)], WOOD[3])
        poly(d, [(49, y - 4), (65, y - 8), (68, y + 5), (52, y + 10)], STEEL[1], width=1)
        poly(d, [(54, y - 1), (62, y - 3), (63, y + 2), (55, y + 5)], WOOD[0], width=1)
        line(d, [(51, y - 3), (64, y - 6)], STEEL[3], 2)
        line(d, [(58, y), (71, y + 2)], STEEL[2], 2)
        for x in (31, 38, 44):
            d.ellipse((x, y + 5 - (x - 31) // 4, x + 2, y + 7 - (x - 31) // 4), fill=INK)
    for x, y in ((29, 24), (28, 29), (29, 54), (32, 73), (38, 78), (46, 79)):
        line(d, [(x, y), (x + 2, y + 2)], BONE[1])
    line(d, [(38, 46), (42, 43), (45, 46)], WOOD[0])
    rivet(d, 68, 39)
    rivet(d, 65, 67)
    return im


def salted_rations_icon():
    im, d = canvas()
    poly(d, [(4, 15), (15, 7), (27, 11), (29, 23), (18, 29), (6, 25)], CLOTH[1], width=1)
    poly(d, [(5, 15), (15, 9), (25, 12), (19, 20)], CLOTH[3], outline=None)
    poly(d, [(10, 10), (13, 4), (20, 4), (25, 9), (23, 18), (16, 21), (10, 17)], RED[1], width=1)
    poly(d, [(13, 8), (19, 6), (23, 10), (21, 15), (16, 18), (12, 15)], RED[2], outline=None)
    line(d, [(13, 13), (18, 9), (20, 11)], RED[3], 2)
    poly(d, [(5, 17), (18, 22), (28, 16), (28, 24), (18, 29), (6, 25)], CLOTH[2], width=1)
    for x, y in ((15, 7), (21, 13), (18, 15)):
        d.point((x, y), fill=BONE[3])
    line(d, [(9, 21), (21, 25)], WOOD[1])
    return im


def salted_rations_detail():
    im, d = portrait()
    poly(d, [(9, 46), (37, 23), (76, 31), (87, 66), (56, 88), (17, 76)], CLOTH[0])
    poly(d, [(14, 44), (38, 27), (72, 33), (63, 51), (41, 62)], CLOTH[2], outline=None)
    poly(d, [(17, 47), (35, 32), (43, 35), (35, 47)], CLOTH[3], outline=None)
    poly(d, [(28, 29), (40, 12), (61, 11), (77, 26), (72, 49), (56, 61), (34, 54), (24, 42)], RED[0])
    poly(d, [(33, 30), (43, 17), (59, 15), (71, 28), (66, 46), (54, 54), (38, 49), (29, 40)], RED[1], outline=None)
    poly(d, [(35, 32), (45, 22), (57, 21), (65, 30), (60, 42), (47, 48), (35, 41)], RED[2], outline=None)
    line(d, [(36, 34), (45, 28), (56, 28), (60, 32)], RED[3], 3)
    line(d, [(40, 41), (48, 36), (57, 38)], BONE[1], 2)
    poly(d, [(12, 48), (43, 62), (82, 47), (85, 67), (56, 86), (19, 74)], CLOTH[1])
    poly(d, [(17, 52), (42, 67), (54, 80), (22, 71)], CLOTH[2], outline=None)
    poly(d, [(46, 65), (78, 53), (74, 67), (58, 78)], CLOTH[2], outline=None)
    line(d, [(18, 56), (41, 71), (52, 80)], CLOTH[3])
    line(d, [(59, 77), (66, 63), (77, 56)], CLOTH[0], 2)
    line(d, [(21, 68), (38, 63), (59, 68), (76, 58)], WOOD[0], 3)
    line(d, [(21, 67), (38, 62), (59, 67), (76, 57)], BONE[1])
    for x, y in ((44, 20), (48, 23), (60, 32), (57, 43), (37, 37), (49, 44), (64, 26)):
        d.rectangle((x, y, x + 1, y + 1), fill=BONE[3])
    return im


def field_manual_icon():
    im, d = canvas()
    poly(d, [(5, 7), (23, 3), (27, 7), (27, 25), (9, 29), (5, 26)], CLOTH[0], width=1)
    poly(d, [(8, 9), (25, 6), (25, 23), (8, 27)], BONE[1], width=1)
    poly(d, [(5, 6), (22, 3), (24, 6), (24, 23), (7, 27), (5, 25)], CLOTH[1], width=1)
    line(d, [(8, 7), (8, 24)], CLOTH[3])
    poly(d, [(13, 11), (18, 8), (21, 13), (18, 19), (12, 20)], "#87968a", width=1)
    line(d, [(17, 11), (15, 14), (18, 15), (15, 18)], "#c5dcc2")
    d.rectangle((20, 18, 27, 21), fill=WOOD[1], outline=INK)
    d.point((23, 19), fill=GOLD[3])
    return im


def field_manual_detail():
    im, d = portrait()
    poly(d, [(17, 22), (69, 9), (82, 20), (82, 74), (31, 88), (16, 78)], CLOTH[0])
    poly(d, [(26, 29), (78, 16), (78, 70), (28, 83)], BONE[1], width=1)
    for y in (35, 43, 51, 59, 67, 75):
        line(d, [(30, y), (76, y - 12)], BONE[3])
        line(d, [(71, y - 9), (76, y - 11)], BONE[0])
    poly(d, [(16, 21), (68, 9), (74, 17), (74, 69), (25, 83), (16, 77)], CLOTH[1])
    poly(d, [(25, 26), (64, 16), (68, 23), (67, 63), (28, 75)], CLOTH[2], outline=None)
    line(d, [(23, 25), (23, 72), (28, 77), (66, 66)], CLOTH[3])
    line(d, [(20, 25), (20, 73)], CLOTH[0], 2)
    poly(d, [(39, 34), (51, 27), (61, 37), (55, 53), (37, 57), (33, 47)], "#60766c", width=1)
    poly(d, [(41, 35), (50, 31), (55, 37), (50, 49), (39, 52), (37, 46)], "#a4b79c", outline=None)
    line(d, [(48, 35), (42, 42), (51, 44), (44, 51)], "#345350", 3)
    line(d, [(48, 35), (42, 42), (51, 44), (44, 51)], "#d8e5ba")
    poly(d, [(62, 54), (82, 49), (84, 60), (64, 66)], WOOD[1], width=1)
    poly(d, [(69, 55), (78, 53), (79, 59), (70, 61)], GOLD[1], width=1)
    rivet(d, 74, 57, GOLD)
    for x, y in ((30, 28), (35, 27), (57, 68), (62, 67), (28, 67)):
        line(d, [(x, y), (x + 2, y + 2)], BONE[1])
    poly(d, [(39, 81), (46, 79), (47, 92), (42, 88), (39, 93)], RED[1], width=1)
    return im


def reed_whistle_icon():
    im, d = canvas()
    poly(d, [(6, 23), (23, 4), (28, 7), (11, 28), (7, 29)], "#778044", width=1)
    poly(d, [(8, 23), (23, 6), (25, 7), (10, 27)], "#c0b76e", outline=None)
    line(d, [(9, 24), (24, 8)], "#e2d394")
    for x, y in ((13, 21), (17, 16), (21, 12)):
        d.ellipse((x, y, x + 2, y + 2), fill=INK)
        d.point((x + 1, y + 2), fill="#8f844a")
    line(d, [(21, 7), (25, 10)], WOOD[0], 2)
    line(d, [(7, 24), (12, 28)], BONE[1])
    return im


def reed_whistle_detail():
    im, d = portrait()
    poly(d, [(16, 72), (67, 12), (80, 19), (32, 81), (22, 87), (15, 82)], "#485638")
    poly(d, [(20, 72), (67, 16), (76, 20), (29, 78), (22, 83), (19, 80)], "#9ba05d", outline=None)
    poly(d, [(21, 72), (67, 18), (71, 20), (25, 78)], "#d6c88a", outline=None)
    line(d, [(24, 72), (66, 22)], "#f0e2aa", 2)
    line(d, [(30, 78), (74, 23)], "#65713e", 2)
    for x, y in ((31, 63), (42, 50), (53, 37)):
        d.ellipse((x - 3, y - 4, x + 4, y + 4), fill=INK)
        d.arc((x - 3, y - 4, x + 4, y + 4), 30, 160, fill="#d9c989", width=2)
        d.point((x - 1, y - 2), fill="#384b36")
    poly(d, [(63, 22), (68, 17), (74, 20), (69, 26)], "#303d2d", width=1)
    line(d, [(63, 24), (70, 29)], WOOD[0], 5)
    line(d, [(63, 23), (70, 28)], BONE[1], 3)
    line(d, [(61, 27), (68, 32)], WOOD[0], 3)
    line(d, [(61, 26), (68, 31)], BONE[2])
    line(d, [(23, 75), (34, 82)], WOOD[0], 5)
    line(d, [(23, 74), (34, 81)], BONE[1], 2)
    line(d, [(31, 82), (44, 85), (48, 78)], WOOD[0], 2)
    line(d, [(31, 82), (44, 85), (48, 78)], BONE[1])
    poly(d, [(46, 77), (51, 76), (53, 85), (48, 88)], RED[1], width=1)
    line(d, [(48, 79), (50, 85)], RED[3])
    line(d, [(44, 62), (49, 56)], "#6e783f")
    return im


def flint_striker_icon():
    im, d = canvas()
    poly(d, [(4, 18), (10, 10), (18, 13), (20, 23), (12, 29), (5, 25)], "#535c61", width=1)
    poly(d, [(6, 18), (10, 13), (15, 15), (12, 23), (6, 24)], "#9bada9", outline=None)
    poly(d, [(17, 5), (25, 3), (29, 8), (27, 14), (22, 20), (19, 17), (24, 10), (22, 8), (17, 10)], STEEL[1], width=1)
    line(d, [(18, 6), (24, 4), (27, 8)], STEEL[3])
    line(d, [(19, 21), (23, 24)], GOLD[3])
    d.point((26, 21), fill=GOLD[4])
    d.point((22, 28), fill=RED[3])
    return im


def flint_striker_detail():
    im, d = portrait()
    poly(d, [(12, 55), (28, 31), (48, 36), (59, 58), (49, 77), (28, 87), (13, 76)], "#343f45")
    poly(d, [(17, 55), (29, 37), (43, 41), (36, 59), (18, 71)], "#8a9b9d", outline=None)
    poly(d, [(45, 42), (53, 58), (45, 71), (29, 79), (37, 62)], "#566b73", outline=None)
    line(d, [(18, 56), (30, 39), (41, 42)], "#cad0bb", 2)
    line(d, [(20, 72), (31, 67), (34, 57), (38, 53)], "#3e5059")
    poly(d, [(48, 18), (69, 8), (83, 14), (87, 30), (79, 46), (64, 60), (54, 53), (69, 37), (75, 25), (69, 20), (51, 29)], STEEL[0])
    poly(d, [(50, 19), (68, 12), (80, 17), (82, 29), (75, 42), (62, 54), (58, 52), (72, 36), (78, 24), (69, 16), (51, 24)], STEEL[2], outline=None)
    line(d, [(51, 20), (68, 13), (78, 17)], STEEL[4], 2)
    line(d, [(81, 30), (74, 42), (63, 52)], STEEL[3])
    # Repeated strike scars and tiny restrained sparks at the contact edge.
    for x, y in ((57, 49), (61, 45), (65, 41)):
        line(d, [(x, y), (x + 4, y + 2)], STEEL[0])
    line(d, [(53, 61), (65, 67)], GOLD[2], 2)
    line(d, [(59, 61), (68, 60)], GOLD[3])
    line(d, [(55, 67), (58, 75)], RED[3])
    gleam(d, 74, 68, GOLD[4], 2)
    d.point((67, 79), fill=GOLD[3])
    d.point((78, 56), fill=GOLD[2])
    return im


def snail_shell_icon():
    im, d = canvas()
    poly(d, [(7, 21), (5, 14), (8, 7), (15, 4), (23, 7), (27, 14), (26, 23), (20, 28), (11, 28), (6, 25)], "#7b5d3e", width=1)
    poly(d, [(8, 18), (8, 11), (15, 7), (22, 10), (24, 17), (20, 23), (14, 24)], "#c2a36e", outline=None)
    line(d, [(11, 24), (7, 18), (10, 10), (17, 8), (22, 13), (21, 19), (16, 21), (13, 17), (15, 13), (18, 14), (18, 17)], "#6d5139", 2)
    line(d, [(10, 10), (16, 8), (20, 10)], BONE[3])
    d.ellipse((7, 23, 18, 28), fill=WOOD[0], outline=INK)
    line(d, [(9, 25), (12, 24), (16, 25)], BONE[1])
    return im


def snail_shell_detail():
    im, d = portrait()
    poly(d, [(19, 65), (13, 45), (20, 24), (39, 12), (61, 14), (77, 30), (82, 52), (75, 72), (58, 85), (32, 86), (16, 77)], "#70533c")
    poly(d, [(22, 61), (18, 45), (25, 27), (41, 17), (59, 19), (72, 33), (75, 51), (68, 68), (54, 78), (34, 79)], "#b49668", outline=None)
    poly(d, [(24, 36), (37, 23), (51, 23), (58, 29), (38, 30), (28, 45)], "#e1c68d", outline=None)
    line(d, [(29, 73), (20, 56), (25, 35), (41, 24), (58, 28), (68, 42), (65, 57), (53, 65), (40, 61), (34, 50), (39, 39), (49, 37), (56, 43), (55, 52), (48, 56), (43, 50), (46, 45), (50, 47)], "#6f5038", 5)
    line(d, [(23, 53), (28, 36), (42, 27), (56, 31), (64, 43)], "#f0d8a0", 2)
    line(d, [(38, 50), (42, 42), (49, 41)], "#dec18a", 2)
    d.ellipse((18, 68, 49, 86), fill=WOOD[0], outline=INK, width=2)
    d.arc((22, 70, 46, 82), 180, 350, fill=BONE[1], width=3)
    d.ellipse((25, 74, 43, 84), fill="#342c26")
    for pts in ([(24, 27), (28, 31), (31, 32)], [(43, 16), (44, 21)],
                [(65, 24), (63, 29)], [(77, 43), (71, 44)],
                [(72, 66), (68, 63)], [(55, 80), (53, 73)]):
        line(d, pts, "#8d6b49", 2)
    line(d, [(59, 57), (55, 61), (49, 62)], "#f0d8a0")
    d.point((34, 32), fill=BONE[3])
    return im


def woven_sling_icon():
    im, d = canvas()
    line(d, [(12, 16), (5, 8), (7, 3), (12, 3)], INK, 3)
    line(d, [(12, 16), (5, 8), (7, 3), (12, 3)], BONE[1])
    line(d, [(22, 22), (29, 27), (27, 29)], INK, 3)
    line(d, [(22, 22), (29, 27), (27, 29)], BONE[2])
    poly(d, [(8, 16), (16, 10), (24, 15), (26, 22), (19, 27), (11, 23)], WOOD[1], width=1)
    for y in (14, 18, 22):
        line(d, [(12, y), (22, y + 3)], BONE[1])
    for x in (12, 17, 22):
        line(d, [(x, 13), (x - 2, 23)], WOOD[3])
    return im


def woven_sling_detail():
    im, d = portrait()
    line(d, [(32, 44), (15, 27), (17, 12), (29, 8), (36, 16), (30, 23)], INK, 6)
    line(d, [(32, 44), (15, 27), (17, 12), (29, 8), (36, 16), (30, 23)], BONE[1], 3)
    line(d, [(31, 43), (14, 26), (16, 11), (28, 7)], BONE[3])
    line(d, [(65, 66), (84, 78), (81, 88), (73, 86)], INK, 5)
    line(d, [(65, 66), (84, 78), (81, 88), (73, 86)], BONE[1], 3)
    poly(d, [(22, 44), (42, 28), (65, 36), (76, 57), (62, 76), (40, 82), (25, 66)], WOOD[0])
    poly(d, [(27, 46), (43, 34), (61, 40), (68, 56), (59, 69), (42, 75), (31, 63)], WOOD[1], outline=None)
    # Individually interlaced rush strands, with brighter raised crossings.
    for pts in ([(29, 46), (49, 55), (67, 55)], [(29, 53), (47, 62), (64, 62)],
                [(33, 62), (45, 69), (58, 70)], [(38, 38), (54, 46), (64, 46)]):
        line(d, pts, BONE[0], 4)
        line(d, pts, BONE[1], 2)
    for pts in ([(39, 38), (35, 54), (42, 73)], [(47, 36), (43, 53), (48, 72)],
                [(56, 40), (51, 55), (54, 69)], [(63, 45), (59, 56), (60, 65)]):
        line(d, pts, WOOD[0], 4)
        line(d, pts, WOOD[3], 2)
    for x, y in ((36, 50), (43, 54), (51, 56), (48, 63), (58, 48)):
        line(d, [(x, y), (x + 2, y + 1)], BONE[3])
    line(d, [(25, 45), (28, 63), (41, 79), (61, 73), (73, 57), (63, 38), (43, 31), (25, 44)], BONE[1], 2)
    for x, y in ((28, 48), (28, 56), (32, 66), (40, 75), (54, 75), (64, 67), (69, 58), (66, 47), (58, 37), (45, 34), (35, 39)):
        line(d, [(x, y), (x + 3, y + 1)], WOOD[0])
    line(d, [(77, 83), (76, 91)], BONE[2])
    line(d, [(79, 84), (81, 91)], BONE[1])
    return im


RENDERERS = {
    "iron_arrowhead": (iron_arrowhead_icon, iron_arrowhead_detail),
    "oiled_gears": (oiled_gears_icon, oiled_gears_detail),
    "heavy_ammunition": (heavy_ammunition_icon, heavy_ammunition_detail),
    "short_bowstring": (short_bowstring_icon, short_bowstring_detail),
    "greased_winch": (greased_winch_icon, greased_winch_detail),
    "chipped_runestone": (chipped_runestone_icon, chipped_runestone_detail),
    "copper_coil": (copper_coil_icon, copper_coil_detail),
    "sturdy_pickaxe": (sturdy_pickaxe_icon, sturdy_pickaxe_detail),
    "taut_drumskin": (taut_drumskin_icon, taut_drumskin_detail),
    "copper_tooth": (copper_tooth_icon, copper_tooth_detail),
    "leather_bracer": (leather_bracer_icon, leather_bracer_detail),
    "salted_rations": (salted_rations_icon, salted_rations_detail),
    "field_manual": (field_manual_icon, field_manual_detail),
    "reed_whistle": (reed_whistle_icon, reed_whistle_detail),
    "flint_striker": (flint_striker_icon, flint_striker_detail),
    "snail_shell": (snail_shell_icon, snail_shell_detail),
    "woven_sling": (woven_sling_icon, woven_sling_detail),
}
