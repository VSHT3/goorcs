#!/usr/bin/env python3
"""Original Gorcs Itemiery art: native 32px icons and authored 96px portraits.

No source images, external artwork, models, resampling or antialiasing.
The two sizes have separate compositions; portraits add native-pixel material work.
Rarity modules supply new guide metadata and renderers. Existing item resources
and artwork are retained; catalog registration only adds the authored entries.
"""
import json
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw
from item_runtime_data import gd_runtime

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "items"
ITEM_RESOURCES = ROOT / "resources" / "items"
CATALOG = ROOT / "resources" / "content_catalog.tres"
INK = "#17201b"


def canvas():
    image = Image.new("RGBA", (32, 32))
    return image, ImageDraw.Draw(image)


def tusk():
    im, d = canvas()
    d.polygon([(5, 23), (7, 18), (12, 17), (18, 14), (22, 9), (24, 3), (26, 6), (26, 12), (23, 19), (18, 25), (11, 29), (7, 28)], fill="#77704c", outline=INK)
    d.polygon([(8, 22), (12, 19), (19, 16), (23, 11), (25, 5), (24, 14), (20, 21), (14, 26), (9, 27)], fill="#c4b782")
    d.polygon([(9, 21), (18, 17), (22, 13), (20, 18), (13, 23), (9, 24)], fill="#eee2b1")
    d.line([(7, 20), (10, 23), (12, 24), (12, 27)], fill="#796c47")
    d.line([(16, 20), (17, 22), (15, 24)], fill="#95875a")
    d.line([(10, 20), (18, 16), (22, 12)], fill="#f2e6b7")
    d.line([(21, 18), (20, 20), (21, 21)], fill="#796c47")
    d.polygon([(6, 24), (9, 23), (11, 26), (9, 28), (6, 27)],
              fill="#927451", outline="#514533")
    d.point((8, 25), fill="#c4b782")
    return im


def boot():
    im, d = canvas()
    d.polygon([(8, 5), (12, 7), (15, 5), (18, 7), (22, 6), (22, 19), (27, 22), (29, 24), (28, 28), (5, 28), (4, 24), (7, 19)], fill="#62452f", outline=INK)
    d.polygon([(9, 8), (12, 10), (16, 8), (20, 9), (19, 20), (11, 21), (9, 23), (7, 23)], fill="#926b44")
    d.polygon([(11, 11), (17, 11), (17, 18), (14, 20), (10, 19)], fill="#ad8351")
    d.rectangle((10, 7, 19, 9), fill="#352c24")
    d.line([(11, 13), (18, 14), (11, 17), (18, 18)], fill="#d3b17a", width=1)
    d.polygon([(19, 21), (24, 22), (27, 24), (26, 25), (15, 25), (13, 23)], fill="#795638")
    d.line([(6, 26), (14, 26), (16, 25), (19, 27), (27, 27)], fill="#c2a471")
    d.line([(6, 28), (12, 28), (14, 27), (16, 29), (22, 29)], fill="#403d2b")
    d.rectangle((19, 15, 22, 18), fill="#242b20")
    d.point((20, 14), fill="#c2a471")
    d.line([(18, 14), (19, 15), (18, 17), (20, 19)], fill="#dfbd86")
    d.line([(8, 10), (8, 17)], fill="#c09a66")
    d.line([(20, 23), (24, 24)], fill="#ad8351")
    for x in (8, 12, 21, 25):
        d.point((x, 28), fill="#80704a")
    return im


def banner():
    im, d = canvas()
    d.line([(7, 3), (7, 29)], fill=INK, width=4)
    d.line([(7, 4), (7, 28)], fill="#ad8b56", width=2)
    d.polygon([(7, 2), (10, 5), (7, 8), (4, 5)], fill="#b9bf95", outline=INK)
    d.polygon([(9, 6), (26, 6), (24, 12), (26, 19), (20, 18), (16, 22), (10, 20)], fill="#486c34", outline=INK)
    d.polygon([(11, 7), (23, 7), (22, 13), (24, 17), (19, 16), (16, 19), (12, 18)], fill="#6e963f")
    d.line([(12, 8), (12, 16)], fill="#96b45b")
    d.rectangle((16, 10, 21, 15), fill="#d0d19d")
    d.rectangle((15, 10, 16, 12), fill="#d0d19d")
    d.rectangle((21, 10, 22, 12), fill="#d0d19d")
    d.point((17, 12), fill=INK)
    d.point((20, 12), fill=INK)
    d.line([(17, 15), (20, 15)], fill="#394f2b")
    d.line([(13, 17), (16, 20), (20, 17), (24, 18)], fill="#c6b66e")
    d.point((16, 14), fill="#f2e6b7")
    d.point((21, 14), fill="#f2e6b7")
    d.line([(6, 9), (9, 9)], fill="#e0c48c")
    return im


def sword():
    im, d = canvas()
    d.polygon([(9, 22), (12, 16), (21, 7), (28, 3), (27, 9), (19, 17), (12, 24)], fill="#7c9297", outline=INK)
    d.polygon([(12, 19), (22, 9), (27, 5), (25, 10), (17, 18), (12, 22)], fill="#dde7d4")
    d.line([(13, 20), (24, 9)], fill="#a6bec0")
    d.line([(7, 20), (14, 25)], fill=INK, width=4)
    d.line([(7, 20), (14, 25)], fill="#c49943", width=2)
    d.line([(10, 24), (5, 29)], fill=INK, width=5)
    d.line([(10, 24), (5, 29)], fill="#783d37", width=3)
    for x, y in [(9, 25), (7, 27), (5, 29)]:
        d.line([(x - 1, y - 1), (x + 1, y + 1)], fill="#c5ac78")
    d.line([(14, 18), (22, 10), (26, 6)], fill="#f3f7de")
    d.line([(18, 16), (20, 15), (20, 13)], fill="#789398")
    d.point((8, 20), fill="#ffedb1")
    return im


def potion():
    im, d = canvas()
    d.polygon([(12, 7), (20, 7), (20, 13), (25, 18), (26, 25), (23, 29), (9, 29), (6, 25), (7, 18), (12, 13)], fill="#665a8a", outline=INK)
    d.polygon([(13, 10), (18, 10), (18, 15), (23, 19), (23, 25), (21, 27), (10, 27), (9, 24), (10, 19), (14, 15)], fill="#383f43")
    d.polygon([(10, 20), (14, 21), (18, 19), (23, 20), (23, 25), (21, 27), (10, 27), (9, 24)], fill="#88bc4b")
    d.polygon([(10, 24), (15, 25), (21, 22), (23, 23), (22, 26), (11, 27)], fill="#4d7f3e")
    d.rectangle((12, 5, 20, 9), fill="#a97b49", outline=INK)
    d.line([(13, 6), (18, 6)], fill="#d7b27b")
    d.rectangle((12, 10, 20, 12), fill="#ae86ce")
    d.line([(10, 17), (8, 20), (8, 23)], fill="#c1cee3")
    d.rectangle((12, 20, 13, 21), fill="#d1ed8a")
    d.point((19, 23), fill="#b1d967")
    d.rectangle((17, 16, 18, 17), fill="#a27ac3")
    d.line([(11, 20), (14, 22), (18, 20), (22, 21)], fill="#d1ed8a")
    d.point((12, 23), fill="#e1efb0")
    d.line([(23, 25), (21, 27), (13, 28)], fill="#8f83ac")
    return im


def coins():
    im, d = canvas()
    for x, y in [(13, 6), (4, 14)]:
        d.ellipse((x, y + 2, x + 14, y + 15), fill="#70502b", outline=INK)
        d.ellipse((x, y, x + 14, y + 13), fill="#d2a044", outline=INK)
        d.ellipse((x + 2, y + 2, x + 12, y + 11), fill="#8e652d")
        d.ellipse((x + 3, y + 2, x + 11, y + 10), fill="#e7bc5c")
        d.line([(x + 4, y + 3), (x + 8, y + 3)], fill="#ffe297")
        d.line([(x + 7, y + 4), (x + 5, y + 6), (x + 9, y + 7), (x + 7, y + 9)], fill="#9c732f")
        for dx in (4, 8, 11):
            d.point((x + dx, y + 14), fill="#d2a044")
        d.point((x + 3, y + 6), fill="#ffedb1")
    return im


def lunch_tin():
    im, d = canvas()
    d.rounded_rectangle((12, 4, 21, 12), radius=2, fill="#69715a", outline=INK)
    d.rectangle((14, 6, 19, 9), fill=(0, 0, 0, 0))
    d.polygon([(4, 12), (9, 8), (27, 8), (29, 12), (29, 26), (25, 29), (5, 28)], fill="#40533d", outline=INK)
    d.polygon([(5, 12), (10, 9), (26, 9), (28, 12), (24, 15), (5, 15)], fill="#94a274", outline=INK)
    d.rectangle((6, 16, 24, 26), fill="#687d50")
    d.line([(7, 17), (7, 24)], fill="#9ca876")
    d.polygon([(25, 16), (28, 14), (28, 25), (25, 27)], fill="#354b37")
    d.rectangle((14, 13, 18, 18), fill="#d0b674", outline=INK)
    d.rectangle((15, 14, 17, 15), fill="#f0d991")
    d.rectangle((11, 21, 19, 24), fill="#3a5138")
    d.point((8, 25), fill="#bd8750")
    d.line([(21, 10), (24, 10)], fill="#c8cda1")
    d.point((23, 24), fill="#a27543")
    d.rectangle((12, 20, 18, 24), fill="#b5bd87")
    d.point((13, 21), fill=INK)
    d.point((17, 21), fill=INK)
    d.line([(14, 24), (16, 24)], fill="#3a5138")
    for x, y in [(8, 18), (22, 18), (22, 26)]:
        d.point((x, y), fill="#c1cda0")
    return im


def doom_bells():
    im, d = canvas()
    d.line([(6, 6), (26, 6)], fill=INK, width=5)
    d.line([(6, 5), (26, 5)], fill="#688147", width=2)
    d.polygon([(14, 3), (17, 2), (19, 5), (16, 9), (13, 6)], fill="#a5cf66", outline=INK)
    for x, y in [(3, 8), (16, 12)]:
        d.rectangle((x + 5, y - 2, x + 7, y + 2), fill="#7b9852", outline=INK)
        d.polygon([(x + 4, y), (x + 9, y), (x + 11, y + 3), (x + 11, y + 9), (x + 13, y + 12), (x, y + 12), (x + 2, y + 9), (x + 2, y + 3)], fill="#4b6040", outline=INK)
        d.polygon([(x + 4, y + 2), (x + 7, y + 1), (x + 7, y + 9), (x + 3, y + 10)], fill="#8eaa5d")
        d.line([(x + 9, y + 3), (x + 9, y + 9)], fill="#263a2e")
        d.line([(x + 1, y + 11), (x + 12, y + 11)], fill="#b6cb77")
        d.ellipse((x + 5, y + 12, x + 8, y + 15), fill="#9bbc62", outline=INK)
        d.rectangle((x + 5, y + 5, x + 8, y + 7), fill="#1d3224")
        d.point((x + 5, y + 5), fill="#b4e765")
        d.point((x + 8, y + 5), fill="#b4e765")
    d.point((25, 4), fill="#d6f59b")
    d.line([(7, 9), (10, 9)], fill="#d6f59b")
    d.point((21, 14), fill="#d6f59b")
    return im


GOLD = ("#6e4427", "#a36e2e", "#d5a343", "#f0cd70", "#ffedb1")
BONE = ("#6b6249", "#a5996b", "#cfc391", "#f2e6b7")
GREEN = ("#284332", "#486c3c", "#789b4b", "#b8d779", "#e1efb0")
STEEL = ("#35434a", "#62777d", "#97afb0", "#d8e5da", "#f3f7de")
PURPLE = ("#3a294a", "#69436d", "#a767a0", "#da9dbd", "#ffe0d0")
RED = ("#482c30", "#833b43", "#ba555a", "#e88c7f", "#ffd0a4")


def portrait():
    image = Image.new("RGBA", (96, 96))
    return image, ImageDraw.Draw(image)


def poly(d, points, color, outline=INK, width=2):
    d.polygon(points, fill=color)
    if outline:
        d.line(points + [points[0]], fill=outline, width=width, joint="curve")


def line(d, points, color, width=1):
    d.line(points, fill=color, width=width, joint="curve")


def rivet(d, x, y, ramp=STEEL):
    d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=INK)
    d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=ramp[1])
    d.point((x - 1, y - 1), fill=ramp[3])


def gleam(d, x, y, color, size=3):
    line(d, [(x - size, y), (x + size, y)], color)
    line(d, [(x, y - size), (x, y + size)], color)
    d.point((x - 1, y - 1), fill=color)


def skull(d, x, y, size=1, color=BONE[2]):
    """Small tusked orc seal, drawn at integer motif scale."""
    def points(coords):
        return [(x + a * size, y + b * size) for a, b in coords]
    poly(d, points([(0, 2), (2, 0), (8, 0), (10, 2), (9, 7),
                    (7, 8), (3, 8), (1, 7)]), color, width=1)
    for ex in (2, 6):
        d.rectangle((x + ex * size, y + 3 * size,
                     x + (ex + 1) * size, y + 4 * size), fill=INK)
    line(d, points([(2, 7), (1, 5), (3, 6), (4, 8)]), BONE[3], size)
    line(d, points([(8, 7), (9, 5), (7, 6), (6, 8)]), BONE[3], size)
    d.point((x + 5 * size, y + 5 * size), fill=INK)


def gem(d, x, y, radius, ramp=PURPLE):
    poly(d, [(x, y - radius), (x + radius, y - radius // 3),
             (x + radius - 2, y + radius // 2), (x, y + radius),
             (x - radius, y + radius // 3), (x - radius, y - radius // 3)],
         ramp[1], width=1)
    poly(d, [(x, y - radius + 2), (x, y + radius - 2),
             (x - radius + 2, y + radius // 3),
             (x - radius + 2, y - radius // 3)], ramp[2], outline=None)
    line(d, [(x - radius + 2, y - radius // 3),
             (x, y - radius + 2), (x + radius - 2, y - radius // 3)], ramp[3])
    line(d, [(x, y - radius + 2), (x, y + radius - 2)], ramp[3])


def tusk_detail():
    im, d = portrait()
    poly(d, [(14, 68), (20, 55), (35, 50), (52, 39), (66, 23),
             (72, 7), (78, 16), (80, 31), (75, 48), (64, 65),
             (47, 79), (30, 88), (17, 85), (10, 78)], BONE[0])
    poly(d, [(18, 68), (26, 58), (42, 52), (59, 37), (71, 16),
             (76, 18), (76, 35), (69, 52), (56, 68), (38, 80),
             (25, 84), (16, 78)], BONE[1], outline=None)
    poly(d, [(21, 66), (40, 54), (58, 39), (70, 21), (72, 29),
             (64, 47), (50, 63), (32, 76), (20, 78)], BONE[2], outline=None)
    poly(d, [(24, 64), (43, 52), (60, 36), (67, 25), (61, 43),
             (45, 60), (26, 71)], BONE[3], outline=None)
    for points in [[(23, 57), (30, 65), (31, 73), (36, 76)],
                   [(51, 54), (48, 60), (51, 64), (46, 69)],
                   [(67, 43), (63, 46), (63, 51)],
                   [(39, 76), (41, 72), (43, 72)]]:
        line(d, points, BONE[0])
    # A rough severed root, bone growth rings, and a carved ownership rune.
    poly(d, [(11, 75), (18, 70), (25, 74), (28, 83),
             (24, 87), (17, 84)], "#665341", width=1)
    poly(d, [(14, 76), (19, 74), (23, 77), (24, 82),
             (20, 84), (16, 81)], "#927451", width=1)
    line(d, [(16, 77), (20, 77), (22, 81), (19, 82)], BONE[2])
    line(d, [(34, 65), (41, 60), (39, 68), (45, 64)], "#958354")
    for x, y in [(30, 62), (36, 57), (51, 46), (58, 39), (26, 78)]:
        d.point((x, y), fill=BONE[3])
    return im


def boot_detail():
    im, d = portrait()
    poly(d, [(24, 13), (34, 18), (45, 13), (54, 18), (65, 15),
             (65, 56), (76, 63), (85, 66), (89, 75), (86, 85),
             (17, 85), (11, 78), (15, 68), (21, 56)], "#4b352a")
    poly(d, [(25, 22), (36, 25), (47, 21), (60, 23), (58, 58),
             (46, 67), (25, 66), (20, 73), (16, 73), (24, 54)],
         "#8f6443", outline=None)
    poly(d, [(28, 27), (46, 26), (49, 43), (44, 59), (30, 61),
             (25, 52)], "#ae8151", outline=None)
    poly(d, [(25, 16), (34, 20), (44, 16), (53, 21), (62, 18),
             (60, 26), (50, 25), (43, 22), (33, 26), (25, 23)],
         "#292b23", width=1)
    line(d, [(27, 28), (25, 50), (22, 61)], "#c09a66", 2)
    for y in (32, 40, 48):
        for x in (33, 51):
            d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=INK)
            d.point((x - 1, y - 1), fill=GOLD[2])
        line(d, [(33, y), (51, y + 7)], "#dfbd81", 2)
        line(d, [(51, y), (33, y + 7)], "#c29a63")
    poly(d, [(55, 60), (67, 62), (79, 68), (85, 73), (82, 77),
             (45, 77), (38, 70)], "#795135", width=1)
    poly(d, [(54, 63), (66, 65), (75, 69), (64, 70), (46, 73)],
         "#a2794b", outline=None)
    poly(d, [(15, 77), (31, 78), (42, 76), (55, 80), (86, 78),
             (85, 85), (49, 86), (42, 83), (34, 86), (17, 85)],
         "#34372a", width=1)
    line(d, [(17, 79), (32, 80), (41, 78), (54, 82), (83, 80)],
         "#d3b17a", 2)
    # Torn leather exposes the dark lining; contrasting repair stitches.
    poly(d, [(57, 42), (65, 39), (63, 45), (66, 49),
             (57, 53), (53, 48)], "#222a20", width=1)
    line(d, [(55, 40), (56, 44), (52, 46), (55, 51), (55, 54)],
         "#c7a071")
    for x, y in [(58, 37), (54, 41), (51, 49), (56, 55)]:
        line(d, [(x, y), (x + 3, y + 1)], "#e0bd86")
    for x in range(23, 82, 6):
        line(d, [(x, 82), (x + 1, 84)], "#80704a")
    line(d, [(64, 69), (61, 73), (65, 74)], "#4b352a")
    line(d, [(29, 58), (34, 60), (31, 64)], "#6b4b33")
    return im


def banner_detail():
    im, d = portrait()
    line(d, [(21, 15), (21, 87)], INK, 7)
    line(d, [(20, 16), (20, 86)], "#87643e", 4)
    line(d, [(19, 17), (19, 85)], "#c1a06a")
    poly(d, [(21, 6), (28, 16), (21, 25), (14, 16)], STEEL[1])
    poly(d, [(21, 8), (21, 21), (16, 16)], STEEL[3], outline=None)
    poly(d, [(25, 22), (79, 22), (75, 38), (80, 57), (64, 54),
             (51, 68), (29, 62)], GREEN[0])
    poly(d, [(29, 25), (73, 25), (69, 39), (74, 52), (62, 49),
             (50, 61), (33, 57)], GREEN[1], outline=None)
    poly(d, [(30, 25), (48, 25), (45, 45), (49, 60), (34, 57)],
         GREEN[2], outline=None)
    poly(d, [(50, 26), (70, 25), (64, 37), (67, 46), (56, 45)],
         "#5b843e", outline=None)
    line(d, [(32, 27), (35, 54), (49, 58), (62, 47), (72, 50)], GOLD[2])
    skull(d, 40, 33, 2, BONE[2])
    line(d, [(40, 33), (44, 30), (57, 30), (60, 34)], BONE[3])
    for y in (25, 40, 57):
        line(d, [(23, y), (29, y + 1)], "#dcc18a", 2)
    # Fold shadows and frayed woven edges, deliberately asymmetric.
    line(d, [(64, 26), (61, 31), (64, 34)], GREEN[0])
    line(d, [(34, 55), (40, 53), (46, 56)], GREEN[3])
    for x, y in [(31, 60), (36, 62), (43, 64), (53, 62),
                 (67, 53), (75, 55)]:
        line(d, [(x, y), (x + 1, y + 4)], GREEN[1])
    for x, y in [(33, 30), (35, 32), (36, 48), (65, 42), (68, 44)]:
        d.point((x, y), fill=GREEN[3])
    return im


def sword_detail():
    im, d = portrait()
    poly(d, [(26, 62), (36, 45), (65, 17), (86, 7), (82, 27),
             (55, 54), (34, 70)], STEEL[1])
    poly(d, [(32, 60), (42, 45), (68, 20), (82, 11),
             (78, 26), (52, 52), (34, 65)], STEEL[3], outline=None)
    poly(d, [(37, 60), (55, 44), (79, 19), (78, 27), (54, 52),
             (34, 67)], STEEL[2], outline=None)
    line(d, [(34, 59), (68, 24), (81, 13)], STEEL[4])
    # Tempered edge follows the curve independently of the central fuller.
    line(d, [(38, 62), (44, 56), (46, 51), (52, 48),
             (56, 42), (63, 38), (67, 32), (74, 27)], "#748f97")
    line(d, [(47, 45), (60, 32)], "#789398")
    line(d, [(58, 34), (60, 36), (63, 32)], STEEL[4])
    line(d, [(23, 59), (42, 75)], INK, 9)
    line(d, [(23, 58), (42, 74)], GOLD[1], 6)
    line(d, [(23, 56), (43, 72)], GOLD[3], 2)
    for x, y in [(26, 60), (33, 66), (39, 71)]:
        d.point((x, y), fill=GOLD[4])
    line(d, [(30, 72), (16, 86)], INK, 11)
    line(d, [(30, 72), (16, 86)], RED[1], 7)
    for x, y in [(28, 74), (24, 78), (20, 82), (16, 86)]:
        line(d, [(x - 3, y - 2), (x + 3, y + 2)], "#dfc08c", 2)
        d.point((x - 1, y), fill=RED[0])
    line(d, [(12, 83), (19, 90)], INK, 5)
    line(d, [(12, 82), (19, 89)], GOLD[2], 3)
    # Maker's tiny rune cut into the blade heel.
    line(d, [(39, 53), (41, 49), (43, 49), (42, 53), (45, 50)], STEEL[0])
    gleam(d, 73, 20, STEEL[4], 3)
    return im


def potion_detail():
    im, d = portrait()
    poly(d, [(36, 20), (60, 20), (59, 38), (72, 50), (80, 65),
             (78, 78), (68, 88), (28, 88), (17, 79), (16, 65),
             (23, 49), (36, 38)], PURPLE[1])
    poly(d, [(39, 28), (56, 28), (55, 41), (67, 53), (74, 65),
             (72, 77), (65, 83), (31, 83), (23, 76), (22, 65),
             (28, 53), (40, 41)], "#293b3e", outline=None)
    poly(d, [(25, 59), (35, 61), (48, 56), (59, 60), (72, 58),
             (75, 68), (70, 80), (63, 84), (31, 84), (23, 76)],
         GREEN[2], outline=None)
    poly(d, [(24, 73), (39, 77), (56, 70), (74, 67), (70, 80),
             (63, 84), (31, 84)], GREEN[1], outline=None)
    line(d, [(26, 59), (35, 62), (48, 57), (59, 61), (70, 59)],
         GREEN[4], 2)
    poly(d, [(34, 16), (36, 9), (60, 9), (63, 16), (61, 26),
             (35, 26)], "#90613e")
    poly(d, [(37, 12), (57, 12), (59, 16), (37, 17)], "#d4ae73", outline=None)
    for x, y in [(40, 19), (52, 17), (56, 22), (44, 23)]:
        line(d, [(x, y), (x + 2, y - 1)], "#61452e")
    d.rectangle((35, 27, 61, 34), fill=INK)
    d.rectangle((36, 28, 60, 32), fill=PURPLE[2])
    line(d, [(37, 28), (58, 28)], PURPLE[3])
    # Curved thick glass reflections, tiny etchings and suspended bubbles.
    line(d, [(33, 45), (25, 56), (21, 66), (22, 73)], "#b5cdd1", 2)
    line(d, [(28, 52), (25, 58)], "#e7ebd4", 2)
    line(d, [(75, 70), (72, 78), (66, 83)], "#7b8ba9")
    for x, y, r in [(35, 69, 3), (55, 74, 2), (61, 63, 2), (45, 51, 2)]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=GREEN[1], outline=GREEN[3])
        d.point((x - 1, y - 1), fill=GREEN[4])
    poly(d, [(43, 36), (52, 37), (56, 47), (46, 51), (40, 44)],
         PURPLE[2], width=1)
    line(d, [(43, 39), (51, 46), (44, 45), (50, 39)], PURPLE[4])
    return im


def coin_face(d, x, y, w, h):
    d.ellipse((x, y + 5, x + w, y + h + 5), fill=GOLD[0], outline=INK, width=2)
    d.ellipse((x, y, x + w, y + h), fill=GOLD[2], outline=INK, width=2)
    d.ellipse((x + 4, y + 3, x + w - 4, y + h - 3),
              fill=GOLD[1], outline=GOLD[3])
    d.ellipse((x + 6, y + 5, x + w - 5, y + h - 4), fill=GOLD[2])
    line(d, [(x + 7, y + 7), (x + 12, y + 4),
             (x + w - 10, y + 4)], GOLD[4], 2)
    for a in range(9, w - 5, 7):
        line(d, [(x + a, y + h + 1), (x + a, y + h + 4)], GOLD[2])
    skull(d, x + w // 2 - 10, y + h // 2 - 7, 2, GOLD[3])
    for a, b in [(8, 12), (w - 9, 13), (9, h - 10), (w - 10, h - 9)]:
        d.point((x + a, y + b), fill=GOLD[4])


def coins_detail():
    im, d = portrait()
    coin_face(d, 36, 10, 45, 39)
    coin_face(d, 39, 44, 43, 34)
    coin_face(d, 10, 39, 47, 39)
    line(d, [(18, 66), (21, 65), (22, 68)], GOLD[0])
    line(d, [(67, 16), (65, 21), (67, 24)], GOLD[0])
    gleam(d, 19, 48, GOLD[4], 3)
    gleam(d, 58, 16, GOLD[4], 2)
    return im


def lunch_detail():
    im, d = portrait()
    d.rounded_rectangle((35, 10, 62, 36), radius=5, fill=STEEL[1], outline=INK, width=2)
    d.rounded_rectangle((41, 15, 56, 30), radius=2, fill=(0, 0, 0, 0))
    line(d, [(39, 12), (57, 12)], STEEL[3], 2)
    poly(d, [(12, 36), (29, 25), (78, 25), (87, 36),
             (86, 76), (74, 86), (15, 83)], GREEN[0])
    poly(d, [(14, 36), (30, 28), (77, 28), (84, 35), (71, 45),
             (15, 44)], "#889b71", width=1)
    poly(d, [(17, 47), (71, 48), (71, 81), (18, 79)],
         "#627a50", outline=None)
    poly(d, [(74, 47), (83, 40), (82, 74), (74, 81)],
         "#3a513c", outline=None)
    line(d, [(19, 50), (20, 76)], "#a2b180", 2)
    line(d, [(17, 37), (68, 39), (79, 32)], "#c1cda0", 2)
    line(d, [(22, 43), (70, 45), (82, 36)], "#344936")
    d.rectangle((43, 38, 56, 53), fill=INK)
    d.rectangle((45, 39, 54, 50), fill=GOLD[2])
    line(d, [(45, 39), (53, 39)], GOLD[4])
    d.rectangle((47, 45, 51, 49), fill=GOLD[0])
    # Stamped orc insignia, welded corners, rust blooms and dented metal.
    skull(d, 32, 58, 2, "#b5bd87")
    for x, y in [(22, 52), (65, 52), (23, 74), (65, 76), (79, 49), (79, 70)]:
        rivet(d, x, y)
    for x, y in [(25, 76), (61, 71), (75, 73), (29, 32)]:
        d.rectangle((x, y, x + 3, y + 2), fill="#91633a")
        d.point((x, y), fill="#bc8a4d")
        d.point((x + 4, y + 2), fill="#48533a")
    line(d, [(56, 61), (64, 59), (67, 62)], "#344936")
    line(d, [(57, 62), (64, 60)], "#94a274")
    line(d, [(33, 76), (40, 77), (42, 75)], "#a4ae80")
    line(d, [(64, 31), (73, 31), (75, 33)], "#d0d8ab")
    return im


def bell_body(d, x, y):
    d.rectangle((x + 14, y - 8, x + 22, y + 2), fill=GREEN[1], outline=INK, width=2)
    line(d, [(x + 16, y - 6), (x + 16, y - 1)], GREEN[3])
    poly(d, [(x + 11, y), (x + 24, y), (x + 30, y + 9),
             (x + 31, y + 29), (x + 37, y + 36), (x + 36, y + 40),
             (x, y + 40), (x - 1, y + 36), (x + 5, y + 28),
             (x + 5, y + 10)], GREEN[0])
    poly(d, [(x + 12, y + 3), (x + 21, y + 2), (x + 24, y + 10),
             (x + 24, y + 29), (x + 28, y + 35), (x + 6, y + 35),
             (x + 10, y + 26), (x + 9, y + 10)], GREEN[1], outline=None)
    poly(d, [(x + 12, y + 5), (x + 17, y + 4), (x + 15, y + 29),
             (x + 10, y + 32)], GREEN[2], outline=None)
    line(d, [(x + 10, y + 9), (x + 13, y + 4),
             (x + 22, y + 4)], GREEN[3])
    line(d, [(x + 28, y + 11), (x + 28, y + 29)], "#172f26")
    d.ellipse((x + 12, y + 37, x + 22, y + 48), fill=GREEN[2], outline=INK, width=2)
    d.ellipse((x + 14, y + 39, x + 17, y + 42), fill=GREEN[3])
    poly(d, [(x + 3, y + 36), (x + 34, y + 36),
             (x + 34, y + 40), (x + 3, y + 40)], GREEN[2], width=1)
    line(d, [(x + 4, y + 36), (x + 32, y + 36)], GREEN[4])
    skull(d, x + 8, y + 14, 2, GREEN[2])
    for dx in (5, 13, 22, 30):
        d.point((x + dx, y + 38), fill=GREEN[4])
    line(d, [(x + 23, y + 28), (x + 20, y + 31),
             (x + 23, y + 34)], INK)


def bells_detail():
    im, d = portrait()
    poly(d, [(13, 15), (79, 15), (84, 20), (80, 26),
             (14, 23), (10, 20)], GREEN[0])
    line(d, [(14, 17), (78, 17)], GREEN[2], 2)
    line(d, [(15, 16), (71, 16)], GREEN[3])
    gem(d, 47, 13, 8, GREEN)
    bell_body(d, 10, 31)
    bell_body(d, 49, 43)
    for x, y in [(15, 29), (77, 32), (84, 51)]:
        line(d, [(x, y), (x + 2, y - 3), (x + 3, y + 1)], GREEN[2])
    gleam(d, 72, 18, GREEN[4], 2)
    return im


def stone_icon(tier):
    im, d = canvas()
    if tier == 2:
        poly(d, [(5, 17), (3, 13), (6, 10), (4, 6), (7, 3), (10, 5),
                 (9, 9), (11, 11), (9, 15)], GREEN[1], width=1)
        poly(d, [(24, 20), (28, 16), (26, 12), (28, 8), (25, 5),
                 (24, 9), (25, 13), (23, 16)], GREEN[2], width=1)
    if tier:
        poly(d, [(6, 12), (4, 6), (11, 10), (16, 3), (21, 10),
                 (28, 6), (26, 17)], GOLD[2], width=1)
        d.point((16, 6), fill=GOLD[4])
    poly(d, [(8, 11), (16, 7), (24, 11), (27, 21),
             (23, 28), (10, 29), (5, 22)], RED[1], width=1)
    poly(d, [(9, 12), (16, 9), (18, 18), (10, 26), (7, 21)],
         RED[2], outline=None)
    poly(d, [(16, 9), (23, 12), (25, 21), (18, 19)], RED[3], outline=None)
    line(d, [(9, 13), (15, 10), (18, 12)], RED[4])
    line(d, [(17, 20), (19, 23), (16, 27)], RED[0])
    if tier:
        line(d, [(7, 22), (11, 27), (22, 26), (26, 21)], GOLD[2], 2)
        gem(d, 16, 25, 3, GREEN)
    else:
        line(d, [(13, 17), (17, 15), (20, 20), (13, 22), (13, 17)], GOLD[3])
        d.point((16, 19), fill=GOLD[4])
    if tier == 2:
        d.rectangle((8, 15, 15, 19), fill=INK)
        d.rectangle((18, 15, 25, 19), fill=INK)
        line(d, [(15, 16), (18, 16)], INK, 2)
        line(d, [(10, 16), (13, 16)], STEEL[2])
        line(d, [(20, 16), (23, 16)], STEEL[2])
    return im


def stone_detail(tier):
    im, d = portrait()
    if tier == 2:
        # Opaque cel-shaped smoke, no transparency or softened halo.
        for points, color in [
            ([(24, 68), (12, 60), (7, 47), (14, 37), (9, 27), (13, 14),
              (22, 8), (29, 14), (27, 24), (20, 27), (24, 39), (18, 48),
              (26, 59)], GREEN[0]),
            ([(19, 57), (12, 47), (19, 37), (14, 25), (19, 15), (25, 14),
              (23, 21), (17, 25), (23, 37), (17, 46), (23, 54)], GREEN[2]),
            ([(75, 74), (88, 62), (86, 51), (79, 44), (87, 32), (85, 21),
              (76, 17), (71, 24), (78, 32), (72, 43), (79, 55),
              (77, 64)], GREEN[0]),
            ([(80, 66), (84, 60), (81, 52), (76, 44), (82, 32), (79, 26),
              (76, 25), (80, 33), (74, 43), (79, 55)], GREEN[2])]:
            poly(d, points, color, width=1)
        line(d, [(15, 43), (20, 36), (16, 26), (20, 19)], GREEN[3])
        line(d, [(79, 62), (81, 58), (78, 51)], GREEN[3])
    if tier:
        poly(d, [(22, 36), (17, 14), (33, 23), (48, 6), (61, 23),
                 (80, 14), (75, 39)], GOLD[1])
        poly(d, [(25, 29), (23, 21), (34, 28), (48, 14), (61, 29),
                 (73, 21), (70, 32)], GOLD[3], outline=None)
        gem(d, 48, 17, 4, GREEN if tier == 2 else PURPLE)
        for x, y in [(21, 17), (76, 17), (34, 28), (62, 28)]:
            rivet(d, x, y, GOLD)
    poly(d, [(27, 32), (47, 23), (68, 31), (78, 57),
             (71, 78), (59, 86), (32, 87), (18, 69), (17, 53)], RED[0])
    poly(d, [(28, 34), (47, 26), (53, 50), (35, 76), (23, 68),
             (22, 52)], RED[2], outline=None)
    poly(d, [(48, 27), (66, 34), (73, 55), (54, 52)],
         RED[3], outline=None)
    poly(d, [(54, 54), (73, 58), (66, 77), (58, 82), (36, 83)],
         RED[1], outline=None)
    poly(d, [(28, 36), (44, 29), (45, 37), (32, 46), (24, 55)],
         RED[3], outline=None)
    line(d, [(27, 37), (43, 30), (50, 32)], RED[4], 2)
    # Cracked cinnabar mineral, with bright inclusions at selected facets.
    for points in [[(56, 33), (54, 41), (58, 47), (55, 54), (61, 60)],
                   [(23, 59), (32, 61), (36, 68), (34, 74)],
                   [(57, 69), (51, 75), (53, 82)],
                   [(67, 53), (64, 56), (66, 62)]]:
        line(d, points, RED[0])
        line(d, [(x - 1, y - 1) for x, y in points[:3]], RED[3])
    for x, y in [(35, 39), (31, 43), (39, 33), (62, 41), (42, 78), (66, 66)]:
        d.rectangle((x, y, x + 1, y + 1), fill=RED[4])
    if tier:
        # Forged filigree is additional geometry, not enlarged icon details.
        poly(d, [(21, 63), (30, 71), (45, 74), (61, 72), (74, 62),
                 (70, 77), (59, 87), (33, 88), (24, 77)], GOLD[1], width=1)
        line(d, [(25, 67), (33, 74), (46, 78), (60, 75), (70, 68)], GOLD[3], 2)
        for x, y in [(30, 77), (38, 81), (57, 81), (66, 76)]:
            line(d, [(x - 2, y + 2), (x - 2, y - 1),
                     (x + 1, y - 2), (x + 2, y)], GOLD[4])
        gem(d, 48, 78, 7, GREEN if tier == 2 else PURPLE)
        line(d, [(26, 43), (28, 36), (33, 34)], GOLD[3], 2)
        line(d, [(65, 36), (70, 44)], GOLD[2], 2)
    else:
        line(d, [(35, 50), (48, 43), (59, 59), (34, 65), (35, 50)],
             GOLD[2], 2)
        line(d, [(39, 52), (48, 48), (53, 57), (39, 61), (39, 52)], GOLD[3])
        d.ellipse((44, 53, 48, 57), fill=GOLD[4])
    if tier == 2:
        poly(d, [(24, 44), (44, 45), (43, 57), (38, 61), (29, 59),
                 (25, 54)], "#111c20", width=2)
        poly(d, [(51, 45), (71, 43), (70, 54), (65, 59), (56, 59),
                 (52, 55)], "#111c20", width=2)
        line(d, [(44, 47), (47, 46), (51, 47)], "#111c20", 3)
        line(d, [(28, 47), (39, 48)], STEEL[2], 2)
        line(d, [(55, 48), (65, 46)], STEEL[2], 2)
        line(d, [(29, 51), (34, 56)], STEEL[1])
        line(d, [(56, 51), (60, 56)], STEEL[1])
        line(d, [(41, 64), (47, 66), (55, 63)], GOLD[3], 2)
        gleam(d, 64, 46, STEEL[4], 2)
    elif tier:
        line(d, [(37, 49), (47, 43), (58, 52), (46, 63),
                 (37, 49)], GOLD[2])
        d.ellipse((44, 49, 49, 54), fill=GOLD[4])
    return im


def paw_icon():
    im, d = canvas()
    poly(d, [(12, 29), (11, 23), (6, 18), (4, 11), (7, 9),
             (11, 15), (10, 5), (13, 3), (16, 13), (16, 4), (19, 3),
             (21, 14), (23, 8), (26, 9), (25, 18), (21, 24), (21, 29)],
         "#62504a", width=1)
    line(d, [(8, 12), (10, 18), (14, 21), (14, 27)], "#b39a74", 2)
    line(d, [(13, 7), (15, 17), (18, 20), (20, 16), (19, 7)], "#927c61")
    poly(d, [(16, 18), (20, 17), (22, 20), (19, 23), (16, 21)],
         PURPLE[2], width=1)
    d.point((18, 19), fill=PURPLE[4])
    line(d, [(12, 27), (21, 27)], RED[2], 2)
    d.rectangle((13, 4, 14, 6), fill=BONE[2])
    d.rectangle((18, 4, 19, 6), fill=BONE[2])
    return im


def paw_detail():
    im, d = portrait()
    # Crooked fingers and a severed charm-bound wrist establish the curse.
    poly(d, [(36, 88), (33, 70), (21, 58), (12, 40), (13, 31),
             (20, 28), (28, 42), (31, 50), (28, 26), (28, 13),
             (33, 8), (39, 12), (43, 41), (46, 46), (46, 15),
             (51, 8), (57, 11), (61, 42), (65, 33), (68, 23),
             (75, 24), (79, 31), (74, 52), (66, 66), (63, 87)],
         "#534841")
    poly(d, [(17, 34), (23, 43), (28, 55), (40, 67), (41, 83),
             (36, 82), (36, 68), (24, 56), (16, 40)],
         "#a68c68", outline=None)
    poly(d, [(33, 13), (36, 15), (40, 43), (46, 54),
             (43, 63), (35, 52), (32, 29)], "#a68c68", outline=None)
    poly(d, [(51, 14), (54, 14), (57, 44), (62, 51),
             (59, 62), (51, 57)], "#92785e", outline=None)
    poly(d, [(69, 29), (73, 28), (74, 32), (70, 50), (64, 57),
             (64, 49)], "#92785e", outline=None)
    poly(d, [(42, 65), (49, 55), (60, 57), (64, 66),
             (59, 80), (44, 83)], "#7c6753", outline=None)
    for points in [[(30, 28), (37, 27)], [(33, 38), (39, 37)],
                   [(48, 28), (56, 27)], [(49, 38), (58, 37)],
                   [(16, 39), (22, 36)], [(20, 47), (26, 44)],
                   [(69, 38), (75, 39)], [(66, 48), (72, 50)],
                   [(39, 63), (44, 65), (47, 71)],
                   [(47, 75), (53, 72), (59, 73)]]:
        line(d, points, "#453b35")
        line(d, [(x, y - 1) for x, y in points], "#c0a782")
    # Yellowed cracked nails and fur tufts, not a human glove.
    for points in [[(30, 15), (32, 10), (36, 13), (37, 20), (32, 20)],
                   [(48, 17), (51, 11), (55, 13), (56, 20), (49, 21)],
                   [(69, 27), (73, 26), (76, 30), (74, 35), (69, 33)]]:
        poly(d, points, BONE[2], width=1)
        line(d, [points[1], points[3]], BONE[0])
    for x, y in [(31, 48), (29, 53), (35, 61), (61, 56),
                 (63, 62), (39, 77), (60, 77)]:
        line(d, [(x, y), (x - 2, y - 4)], "#c0a782")
    gem(d, 52, 62, 7, PURPLE)
    line(d, [(37, 81), (62, 79)], RED[0], 6)
    line(d, [(37, 79), (62, 77)], RED[2], 2)
    line(d, [(38, 83), (61, 81)], GOLD[2])
    line(d, [(61, 78), (70, 83), (70, 89)], GOLD[2])
    poly(d, [(70, 82), (76, 85), (75, 91), (68, 90), (66, 86)],
         GOLD[1], width=1)
    d.point((71, 85), fill=PURPLE[3])
    # Three short curse wisps make a compact frame without hiding fingers.
    for x, y in [(13, 66), (79, 60), (23, 19)]:
        line(d, [(x, y + 6), (x - 3, y + 1), (x, y - 4)], PURPLE[2], 2)
        d.point((x + 2, y - 6), fill=PURPLE[3])
    return im


def mushroom_icon():
    im, d = canvas()
    poly(d, [(10, 29), (10, 24), (12, 19), (21, 18), (23, 26),
             (26, 28), (22, 30), (17, 28), (13, 30)], BONE[1], width=1)
    poly(d, [(12, 23), (14, 18), (19, 19), (20, 26), (14, 27)],
         BONE[3], outline=None)
    poly(d, [(3, 17), (5, 10), (11, 5), (18, 3), (24, 7),
             (29, 17), (26, 21), (7, 21)], PURPLE[1], width=1)
    poly(d, [(5, 15), (10, 8), (17, 5), (23, 9), (26, 16),
             (17, 18)], PURPLE[2], outline=None)
    d.rectangle((10, 9, 13, 11), fill=BONE[3])
    d.rectangle((19, 7, 21, 9), fill=BONE[2])
    d.rectangle((22, 14, 25, 16), fill=BONE[3])
    line(d, [(7, 19), (25, 19)], "#d694af")
    d.rectangle((13, 23, 14, 24), fill=INK)
    d.rectangle((18, 23, 19, 24), fill=INK)
    d.point((14, 23), fill=GREEN[3])
    line(d, [(15, 26), (17, 27), (19, 26)], "#7f6a50")
    return im


def mushroom_detail():
    im, d = portrait()
    # Root feet and velvet stem first, then a broad luminous gilled cap.
    poly(d, [(34, 53), (60, 53), (63, 69), (67, 78), (77, 83),
             (74, 89), (63, 87), (57, 83), (50, 88), (43, 85),
             (31, 90), (24, 86), (29, 79), (32, 66)], BONE[1])
    poly(d, [(37, 56), (51, 56), (53, 72), (58, 80), (50, 84),
             (43, 80), (32, 85), (35, 74)], BONE[3], outline=None)
    poly(d, [(54, 58), (59, 58), (60, 72), (65, 80), (72, 84),
             (65, 84), (57, 79)], BONE[0], outline=None)
    line(d, [(36, 61), (35, 73), (31, 81)], "#fff0c6")
    for points in [[(40, 70), (38, 76), (41, 80)],
                   [(57, 70), (56, 77), (61, 82)],
                   [(37, 85), (42, 82)], [(48, 82), (50, 85)]]:
        line(d, points, BONE[1])
    poly(d, [(8, 47), (14, 31), (26, 19), (44, 10), (56, 12),
             (72, 24), (82, 40), (87, 51), (79, 61), (61, 65),
             (33, 64), (15, 58)], PURPLE[0])
    poly(d, [(11, 48), (22, 36), (43, 32), (66, 37), (83, 50),
             (76, 58), (59, 62), (33, 60), (17, 55)], "#c48e9b", outline=None)
    for x, y in [(17, 52), (25, 54), (34, 57), (44, 59),
                 (55, 59), (66, 58), (77, 54)]:
        line(d, [(48, 44), (x, y)], "#744762")
        line(d, [(49, 46), (x + 1, y)], "#e4b3b4")
    poly(d, [(9, 46), (16, 31), (29, 20), (44, 12), (56, 14),
             (70, 25), (80, 41), (85, 49), (70, 50), (57, 46),
             (42, 47), (29, 51), (17, 48)], PURPLE[1], width=1)
    poly(d, [(14, 42), (23, 29), (36, 21), (45, 15), (54, 17),
             (63, 26), (68, 37), (58, 39), (43, 38), (28, 45)],
         PURPLE[2], outline=None)
    poly(d, [(23, 32), (35, 23), (45, 18), (49, 19), (43, 27),
             (31, 34)], PURPLE[3], outline=None)
    # Irregular cream scales follow the cap's surface, not polka-dot noise.
    for points in [[(28, 27), (35, 23), (39, 24), (36, 29), (30, 31)],
                   [(48, 20), (53, 21), (57, 26), (50, 27), (46, 24)],
                   [(20, 38), (26, 35), (30, 37), (28, 42), (21, 43)],
                   [(61, 35), (67, 34), (73, 42), (66, 44), (60, 41)],
                   [(41, 38), (47, 36), (51, 40), (47, 44), (40, 43)]]:
        poly(d, points, BONE[2], width=1)
        line(d, points[:3], BONE[3])
    d.rounded_rectangle((38, 67, 43, 72), radius=1, fill=INK)
    d.rounded_rectangle((51, 67, 56, 72), radius=1, fill=INK)
    d.point((39, 68), fill=GREEN[4])
    d.point((52, 68), fill=GREEN[4])
    line(d, [(45, 76), (48, 78), (52, 76)], "#7a6850")
    # Spore motes and small satellites make this a creature, not food.
    for x, y in [(12, 71), (79, 70), (22, 17), (73, 15), (83, 29)]:
        d.rectangle((x, y, x + 2, y + 2), fill=GREEN[2])
        d.point((x, y), fill=GREEN[4])
    line(d, [(17, 84), (17, 77)], BONE[2], 2)
    poly(d, [(11, 77), (14, 72), (19, 71), (23, 77)], PURPLE[2], width=1)
    d.point((16, 73), fill=BONE[3])
    return im


def shebang_icon(upgraded):
    im, d = canvas()
    # Composite trophy: lookout, rune spire, ballista, drum and mine plinth.
    poly(d, [(4, 25), (9, 21), (24, 21), (28, 25), (27, 29),
             (4, 29)], GOLD[1], width=1)
    d.rectangle((6, 25, 25, 27), fill=GOLD[3])
    d.rectangle((6, 10, 12, 23), fill=STEEL[1], outline=INK)
    poly(d, [(4, 10), (9, 5), (14, 10)], RED[2], width=1)
    d.rectangle((8, 13, 10, 15), fill=INK)
    poly(d, [(14, 22), (15, 12), (19, 12), (21, 22)], STEEL[2], width=1)
    gem(d, 17, 10, 5, GREEN if upgraded else PURPLE)
    line(d, [(23, 12), (23, 22)], "#8a6040", 3)
    line(d, [(20, 14), (25, 18), (28, 12)], INK, 3)
    line(d, [(20, 14), (25, 17), (28, 12)], GOLD[2])
    d.rectangle((10, 20, 15, 24), fill=RED[2], outline=INK)
    line(d, [(10, 20), (15, 20)], BONE[2])
    if upgraded:
        poly(d, [(10, 5), (9, 2), (14, 4), (17, 2), (21, 4),
                 (25, 2), (24, 6)], GREEN[2], width=1)
        d.point((17, 3), fill=GREEN[4])
        d.rectangle((16, 25, 20, 28), fill=GREEN[1])
        d.point((17, 26), fill=GREEN[4])
    else:
        d.rectangle((16, 25, 20, 28), fill=GOLD[1])
    return im


def tower_medallion(d, x, y, family, upgraded):
    """Seven miniature reliefs: the actual collection's tower families."""
    ramp = GREEN if upgraded else GOLD
    poly(d, [(x - 11, y - 12), (x + 11, y - 12), (x + 12, y + 7),
             (x, y + 13), (x - 12, y + 7)], ramp[0], width=1)
    poly(d, [(x - 9, y - 10), (x + 9, y - 10), (x + 10, y + 6),
             (x, y + 10), (x - 10, y + 6)], "#313c36", outline=ramp[2], width=1)
    if family == "arrow":
        d.rectangle((x - 5, y - 3, x + 5, y + 7), fill=STEEL[1], outline=INK)
        poly(d, [(x - 8, y - 3), (x, y - 10), (x + 8, y - 3)], RED[2], width=1)
        d.rectangle((x - 2, y, x + 1, y + 3), fill=INK)
        line(d, [(x - 3, y + 6), (x + 4, y + 6)], STEEL[3])
    elif family == "ballista":
        line(d, [(x - 3, y + 6), (x + 3, y - 4)], "#a4794b", 4)
        line(d, [(x - 8, y - 6), (x - 5, y + 1), (x + 2, y + 3),
                 (x + 8, y)], GOLD[3], 2)
        line(d, [(x - 8, y - 6), (x + 8, y)], BONE[2])
        line(d, [(x - 3, y + 6), (x + 5, y - 8)], STEEL[3])
    elif family == "orcapult":
        line(d, [(x - 7, y + 6), (x + 7, y + 6)], "#ab8050", 3)
        line(d, [(x - 4, y + 5), (x, y - 4), (x + 4, y + 5)], GOLD[1], 2)
        line(d, [(x - 4, y + 2), (x + 4, y - 8)], "#c59a60", 3)
        poly(d, [(x + 1, y - 9), (x + 7, y - 9), (x + 6, y - 5),
                 (x + 2, y - 5)], STEEL[1], width=1)
        for dx in (-6, 6):
            d.ellipse((x + dx - 2, y + 5, x + dx + 2, y + 9), fill=INK, outline=GOLD[2])
    elif family == "rune":
        poly(d, [(x - 6, y + 7), (x - 4, y - 2), (x + 4, y - 2),
                 (x + 6, y + 7)], STEEL[1], width=1)
        gem(d, x, y - 6, 5, PURPLE)
        line(d, [(x - 2, y + 1), (x + 1, y + 2), (x - 1, y + 5)], "#8bcfd2")
    elif family == "lightning":
        d.rectangle((x - 4, y, x + 4, y + 8), fill=STEEL[1], outline=INK)
        line(d, [(x, y - 7), (x, y + 3)], "#c1864c", 3)
        for dy in (-4, 0, 4):
            line(d, [(x - 4, y + dy), (x + 4, y + dy)], GOLD[3])
        line(d, [(x + 5, y - 9), (x + 1, y - 5), (x + 6, y - 5),
                 (x + 2, y)], "#b8e9ec", 2)
    elif family == "mine":
        poly(d, [(x - 8, y + 7), (x - 8, y - 3), (x - 3, y - 8),
                 (x + 5, y - 7), (x + 8, y + 7)], STEEL[1], width=1)
        d.rectangle((x - 4, y - 2, x + 4, y + 7), fill=INK)
        line(d, [(x - 7, y + 5), (x - 7, y - 3), (x + 6, y - 3),
                 (x + 6, y + 5)], "#b08b55", 2)
        d.ellipse((x - 2, y + 3, x + 4, y + 7), fill=GOLD[3], outline=GOLD[0])
    else:
        for dx, dy in [(-5, 1), (4, -2)]:
            d.rectangle((x + dx - 4, y + dy - 3, x + dx + 4, y + dy + 6),
                        fill=RED[1], outline=INK)
            d.ellipse((x + dx - 4, y + dy - 5, x + dx + 4, y + dy), fill=BONE[2], outline=INK)
            line(d, [(x + dx - 3, y + dy + 1), (x + dx, y + dy + 5),
                     (x + dx + 3, y + dy + 1)], GOLD[2])
    d.point((x - 9, y - 10), fill=ramp[4])


def shebang_detail(upgraded):
    im, d = portrait()
    ramp = GREEN if upgraded else GOLD
    # Winged trophy chassis unifies seven independently legible family seals.
    poly(d, [(12, 32), (8, 19), (21, 25), (26, 17), (35, 29),
             (48, 20), (60, 29), (69, 17), (75, 25), (87, 19),
             (84, 34), (79, 62), (69, 77), (28, 77), (17, 63)],
         GOLD[0])
    line(d, [(12, 25), (20, 30), (25, 23), (34, 33),
             (48, 24), (61, 33), (69, 23), (76, 30), (83, 25)], GOLD[3], 2)
    if upgraded:
        for x, direction in [(14, 1), (82, -1)]:
            poly(d, [(x, 36), (x - direction * 7, 29),
                     (x - direction * 6, 17), (x + direction * 3, 25),
                     (x + direction * 7, 20), (x + direction * 5, 35)],
                 GREEN[1], width=1)
            line(d, [(x - direction * 4, 22), (x - direction * 3, 29),
                     (x + direction * 2, 32)], GREEN[3])
            gem(d, x, 30, 3, GREEN)
    # Side laurel leaves are forged pointed plates, lit at the upper left.
    for x, y, direction in [(14, 45, 1), (17, 57, 1), (22, 68, 1),
                            (82, 45, -1), (79, 57, -1), (74, 68, -1)]:
        poly(d, [(x, y + 7), (x - direction * 7, y - 4),
                 (x - direction * 6, y - 9), (x + direction * 3, y - 2)],
             ramp[2], width=1)
        line(d, [(x, y + 4), (x - direction * 4, y - 5)], ramp[4])
    for x, y, family in [(23, 35, "arrow"), (48, 42, "rune"),
                         (73, 35, "ballista"), (23, 61, "orcapult"),
                         (48, 65, "mine"), (73, 61, "lightning"),
                         (48, 18, "drums")]:
        tower_medallion(d, x, y, family, upgraded)
    poly(d, [(27, 77), (68, 77), (74, 83), (74, 89),
             (21, 89), (21, 83)], GOLD[1])
    d.rectangle((25, 80, 70, 83), fill=GOLD[3])
    line(d, [(26, 80), (67, 80)], GOLD[4])
    line(d, [(25, 87), (70, 87)], GOLD[0])
    for x in (29, 65):
        rivet(d, x, 85, GOLD)
    if upgraded:
        # Exclusive upgrade receives an unmistakable emerald orc crest.
        poly(d, [(34, 11), (34, 7), (41, 10), (48, 7), (55, 10),
                 (62, 7), (61, 14), (49, 20)], GREEN[1], width=1)
        line(d, [(36, 9), (42, 12), (48, 9), (54, 12), (60, 9)], GREEN[3])
        skull(d, 43, 11, 1, GREEN[4])
        gem(d, 48, 83, 6, GREEN)
        for x in (35, 59):
            line(d, [(x - 2, 85), (x - 2, 81), (x + 1, 83),
                     (x + 2, 80)], GREEN[0])
            d.point((x - 2, 80), fill=GREEN[4])
        for x, y in [(13, 13), (83, 12), (9, 73), (85, 75)]:
            gleam(d, x, y, GREEN[3], 2)
    else:
        skull(d, 42, 80, 1, GOLD[4])
    return im


def _gd_string(value):
    """Godot text-resource strings use JSON-compatible quoted escapes."""
    return json.dumps(value, ensure_ascii=False)


def write_item_resource(item, tier):
    """Write authored guide metadata and its preserved numeric gameplay record."""
    item_id = item["id"]
    mechanics = ", ".join(_gd_string(rule) for rule in item["mechanics"])
    text = (
        '[gd_resource type="Resource" script_class="ItemDefinition" load_steps=4 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/item_definition.gd" id="1"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/items/{item_id}.png" id="2"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/items/{item_id}_detail.png" id="3"]\n\n'
        '[resource]\n'
        'script = ExtResource("1")\n'
        f'id = &{_gd_string(item_id)}\n'
        f'title = {_gd_string(item["title"])}\n'
        f'rarity = {tier}\n'
        f'effect_text = {_gd_string(item["effect"])}\n'
        f'flavor_text = {_gd_string(item.get("flavor", ""))}\n'
        'icon_texture = ExtResource("2")\n'
        'detail_texture = ExtResource("3")\n'
        f'mechanics = PackedStringArray({mechanics})\n'
        f'runtime = {gd_runtime(item_id)}\n'
    )
    (ITEM_RESOURCES / f"{item_id}.tres").write_text(text, encoding="utf-8")


def register_catalog_items(items):
    """Append missing item references without rebuilding tower/enemy resources."""
    text = CATALOG.read_text(encoding="utf-8")
    resource_ids = dict(re.findall(
        r'^\[ext_resource [^\n]*path="([^"]+)" id="([^"]+)"\]$', text, re.MULTILINE
    ))
    item_array = re.search(
        r'^items = Array\[ExtResource\("([^"]+)"\)\]\(\[(.*?)\]\)$', text, re.MULTILINE
    )
    if item_array is None:
        raise ValueError("Content catalog is missing its typed item array")
    script_id, current_items = item_array.groups()
    references = re.findall(r'ExtResource\("([^"]+)"\)', current_items)
    declarations = []
    for item in items:
        item_id = item["id"]
        resource_path = f"res://resources/items/{item_id}.tres"
        resource_id = resource_ids.get(resource_path)
        if resource_id is None:
            resource_id = f"item_{item_id}"
            declarations.append(
                f'[ext_resource type="Resource" path="{resource_path}" id="{resource_id}"]'
            )
            resource_ids[resource_path] = resource_id
        if resource_id not in references:
            references.append(resource_id)
    array_body = ", ".join(f'ExtResource("{reference}")' for reference in references)
    text = text[:item_array.start()] + (
        f'items = Array[ExtResource("{script_id}")]([{array_body}])'
    ) + text[item_array.end():]
    if declarations:
        text = text.replace("\n[resource]\n", "\n" + "\n".join(declarations) + "\n\n[resource]\n", 1)
    load_steps = len(re.findall(r'^\[(?:ext_resource|sub_resource)\b', text, re.MULTILINE)) + 1
    text = re.sub(r'\bload_steps=\d+', f"load_steps={load_steps}", text, count=1)
    CATALOG.write_text(text, encoding="utf-8")


def main():
    # Modules import the drawing helpers above, never another running main().
    sys.modules.setdefault("author_items", sys.modules[__name__])
    import item_art_common
    import item_art_uncommon
    import item_art_rare
    import item_art_epic
    import item_art_mythic
    import item_art_legendary
    import item_art_orcfeccion

    modules = (
        item_art_common, item_art_uncommon, item_art_rare, item_art_epic,
        item_art_mythic, item_art_legendary, item_art_orcfeccion,
    )
    OUT.mkdir(parents=True, exist_ok=True)
    original_renderers = {
        "orc_tusk": (tusk, tusk_detail),
        "torn_boot": (boot, boot_detail),
        "command_banner": (banner, banner_detail),
        "samurai_sword": (sword, sword_detail),
        "concucktion": (potion, potion_detail),
        "dabloons": (coins, coins_detail),
        "orcish_lunch_tin": (lunch_tin, lunch_detail),
        "ominous_bells_of_doom": (doom_bells, bells_detail),
        "philosophers_stone": (lambda: stone_icon(0), lambda: stone_detail(0)),
        "philosophorers_stone": (lambda: stone_icon(1), lambda: stone_detail(1)),
        "philosophorers_stoner": (lambda: stone_icon(2), lambda: stone_detail(2)),
        "monkeys_paw": (paw_icon, paw_detail),
        "spore_spawn_of_marko": (mushroom_icon, mushroom_detail),
        "the_whole_shebang": (lambda: shebang_icon(False), lambda: shebang_detail(False)),
        "the_whole_shebang_orcfeccion": (lambda: shebang_icon(True), lambda: shebang_detail(True)),
    }
    renderers = dict(original_renderers)
    new_items = []
    for module in modules:
        for item in module.ITEMS:
            item_id = item["id"]
            if item_id in renderers:
                raise ValueError(f"Duplicate Itemiery ID: {item_id}")
            renderers[item_id] = module.RENDERERS[item_id]
            new_items.append((item, module.TIER))
    ITEM_RESOURCES.mkdir(parents=True, exist_ok=True)
    for name, (render_icon, render_detail) in renderers.items():
        for suffix, render, size in [("", render_icon, 32), ("_detail", render_detail, 96)]:
            destination = OUT / f"{name}{suffix}.png"
            if name in original_renderers and destination.exists():
                continue
            image = render()
            assert image.mode == "RGBA"
            assert image.size == (size, size)
            assert set(image.getchannel("A").tobytes()) <= {0, 255}
            image.save(destination)
            print(f"{name}{suffix}: {size}x{size} RGBA, hard alpha")
    for item, tier in new_items:
        write_item_resource(item, tier)
    register_catalog_items([item for item, _tier in new_items])
    print(f"Registered {len(new_items)} new guide-only Itemiery definitions; preserved 15 originals")


if __name__ == "__main__":
    main()
