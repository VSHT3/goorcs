#!/usr/bin/env python3
"""Original gameplay tower artwork, hand-authored by Gorcs contributors (2026).

Native 96x112 RGBA pixels; integer polygons/rectangles, hard alpha, no source
images, sampling, antialiasing, models, or third-party artwork. Upper-left light,
front-dominant elevated timber/stone forms. Run with Pillow to reproduce only
these ten new PNGs; established approved tower PNGs are never read or written.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "towers"
P = {
    "ink": "#202527", "deep": "#303634", "stone_dark": "#505951",
    "stone": "#798473", "stone_light": "#a8b09a", "stone_top": "#c6cbb1",
    "wood_dark": "#49372e", "wood": "#795239", "wood_light": "#a67a4d",
    "wood_top": "#cfaa72", "iron_dark": "#37434b", "iron": "#687d85",
    "iron_light": "#a3bdc2", "copper_dark": "#724936", "copper": "#b97943",
    "copper_light": "#e6b36d", "gold_dark": "#86602c", "gold": "#d6a647",
    "gold_light": "#f7d982", "blue_dark": "#346574", "blue": "#63b5ca",
    "blue_light": "#c0f2ea", "red_dark": "#743934", "red": "#b65442",
    "red_light": "#df8860", "cloth_dark": "#304e56", "cloth": "#487985",
    "cloth_light": "#77a5a1", "paper_dark": "#a98d5f", "paper": "#d5bf89",
    "paper_light": "#efdfad", "fire_dark": "#b54c2f", "fire": "#ee8b36",
    "fire_light": "#ffdb78",
}


def canvas():
    image = Image.new("RGBA", (96, 112))
    return image, ImageDraw.Draw(image)


def poly(d, points, fill, outline="ink"):
    d.polygon(points, fill=P[fill], outline=P[outline] if outline else None)


def rect(d, box, fill, outline=None):
    d.rectangle(box, fill=P[fill], outline=P[outline] if outline else None)


def line(d, points, fill, width=1):
    d.line(points, fill=P[fill], width=width)


def slab(d, x=11, y=87, w=74, h=10, depth=7):
    # A shallow right face and broad front face, not a diamond/isometric icon.
    poly(d, [(x, y), (x + 7, y - depth), (x + w - 7, y - depth), (x + w, y), (x + w - 7, y + 4), (x + 7, y + 4)], "stone_top")
    poly(d, [(x, y), (x + w - 7, y), (x + w - 7, y + h), (x, y + h)], "stone")
    poly(d, [(x + w - 7, y), (x + w, y - 4), (x + w, y + h - 4), (x + w - 7, y + h)], "stone_dark")
    line(d, [(x + 2, y + 1), (x + w - 9, y + 1)], "stone_light")
    for xx in range(x + 15, x + w - 8, 21):
        line(d, [(xx, y + 1), (xx, y + h - 1)], "stone_dark")
    rect(d, (x + 3, y + h - 2, x + w - 9, y + h - 1), "stone_dark")


def footing(d):
    slab(d, 8, 95, 80, 9, 7)
    slab(d, 13, 86, 70, 10, 6)


def block(d, x, y, w, h):
    poly(d, [(x, y), (x + w - 6, y), (x + w - 6, y + h), (x, y + h)], "stone")
    poly(d, [(x + w - 6, y), (x + w, y - 5), (x + w, y + h - 5), (x + w - 6, y + h)], "stone_dark")
    poly(d, [(x, y), (x + 6, y - 5), (x + w, y - 5), (x + w - 6, y)], "stone_light")
    for yy in range(y + 10, y + h, 12):
        line(d, [(x + 1, yy), (x + w - 7, yy)], "stone_dark")
        line(d, [(x + 2, yy + 1), (x + w - 8, yy + 1)], "stone_light")
        xx = x + (w // 3 if (yy - y) // 12 % 2 else w * 2 // 3)
        line(d, [(xx, yy - 10), (xx, yy - 1)], "stone_dark")
    line(d, [(x + 1, y + 1), (x + 1, y + h - 1)], "stone_top")


def timber(d, x, y, w, h):
    rect(d, (x, y, x + w, y + h), "wood_dark", "ink")
    rect(d, (x + 1, y + 1, x + w - 2, y + h - 1), "wood")
    line(d, [(x + 1, y + 1), (x + 1, y + h - 1)], "wood_top")
    line(d, [(x + 3, y + 4), (x + 3, y + h - 5)], "wood_light")
    for yy in (y + 3, y + h - 3):
        rect(d, (x + 1, yy, x + w - 1, yy + 1), "iron_dark")
        rect(d, (x + 2, yy, x + 2, yy), "iron_light")


def coin(d, x, y, count=1):
    for i in range(count - 1, -1, -1):
        yy = y - i * 3
        poly(d, [(x, yy), (x + 2, yy - 2), (x + 8, yy - 2), (x + 10, yy), (x + 10, yy + 3), (x + 8, yy + 5), (x + 2, yy + 5), (x, yy + 3)], "gold_dark")
        rect(d, (x + 1, yy, x + 9, yy + 1), "gold")
        line(d, [(x + 2, yy - 1), (x + 7, yy - 1)], "gold_light")
        line(d, [(x + 4, yy + 2), (x + 6, yy + 2)], "gold")


def roof(d, x, y, w, fill="cloth"):
    poly(d, [(x, y), (x + 7, y - 16), (x + w - 8, y - 16), (x + w, y - 3), (x + w - 7, y + 3)], fill)
    line(d, [(x + 7, y - 15), (x + w - 9, y - 15)], "cloth_light" if fill == "cloth" else "wood_top", 2)
    for yy in (y - 9, y - 3):
        line(d, [(x + 5, yy), (x + w - 7, yy)], "cloth_dark" if fill == "cloth" else "wood_dark")
    line(d, [(x, y), (x + w - 7, y + 3)], "wood_dark", 3)


def coil(d, x, y, height):
    rect(d, (x - 4, y, x + 6, y + height), "iron_dark", "ink")
    rect(d, (x - 2, y + 1, x, y + height - 1), "blue")
    for yy in range(y + 6, y + height - 1, 6):
        poly(d, [(x - 10, yy - 2), (x + 6, yy - 4), (x + 11, yy - 1), (x + 9, yy + 2), (x - 7, yy + 4), (x - 11, yy + 1)], "copper")
        line(d, [(x - 9, yy - 1), (x + 6, yy - 3), (x + 9, yy - 1)], "copper_light")
        line(d, [(x - 6, yy + 3), (x + 8, yy + 1)], "copper_dark")
    poly(d, [(x - 10, y - 3), (x - 5, y - 7), (x + 7, y - 7), (x + 12, y - 3), (x + 8, y + 1), (x - 6, y + 1)], "iron")
    line(d, [(x - 7, y - 4), (x - 3, y - 6), (x + 6, y - 6)], "iron_light", 2)
    rect(d, (x - 1, y - 14, x + 2, y - 7), "blue_dark", "ink")
    rect(d, (x, y - 13, x + 1, y - 9), "blue_light")


def lightning(long_reach=False):
    image, d = canvas()
    footing(d)
    block(d, 25, 63, 46, 24)
    rect(d, (34, 70, 56, 83), "iron_dark", "ink")
    poly(d, [(46, 71), (40, 78), (46, 78), (43, 82), (52, 75), (47, 75)], "blue_light", None)
    slab(d, 20, 59, 56, 7, 5)
    if long_reach:
        # Twin tall outriggers and a triangular terminal give a distinct silhouette.
        coil(d, 30, 29, 28)
        coil(d, 63, 29, 28)
        timber(d, 44, 35, 5, 22)
        poly(d, [(44, 26), (47, 14), (51, 26), (48, 35)], "blue", "iron_dark")
        line(d, [(47, 17), (47, 29)], "blue_light")
        line(d, [(30, 29), (46, 39), (63, 29)], "iron_dark", 3)
        line(d, [(31, 28), (47, 37), (62, 28)], "iron_light")
    else:
        coil(d, 47, 32, 26)
        timber(d, 24, 51, 5, 15)
        timber(d, 64, 51, 5, 15)
        line(d, [(29, 53), (36, 48)], "iron", 3)
        line(d, [(58, 48), (65, 53)], "iron", 3)
    return image


def drum(d, x, y, w, h):
    poly(d, [(x, y), (x + w, y), (x + w - 2, y + h), (x + 3, y + h)], "red_dark")
    rect(d, (x + 3, y + 2, x + w - 5, y + h - 2), "red")
    line(d, [(x + 5, y + 4), (x + 8, y + h - 3), (x + 13, y + 4), (x + 18, y + h - 3), (x + w - 4, y + 4)], "wood_top")
    poly(d, [(x - 1, y), (x + 3, y - 5), (x + w - 4, y - 5), (x + w + 1, y), (x + w - 3, y + 5), (x + 3, y + 5)], "paper", "wood_dark")
    line(d, [(x + 4, y - 3), (x + w - 5, y - 3)], "paper_light", 2)
    poly(d, [(x + 3, y + h - 4), (x + w - 2, y + h - 4), (x + w - 3, y + h), (x + 4, y + h)], "iron_dark")
    line(d, [(x + 5, y + h - 3), (x + w - 4, y + h - 3)], "iron_light")


def war_drums():
    image, d = canvas()
    footing(d)
    timber(d, 20, 54, 6, 32)
    timber(d, 69, 54, 6, 32)
    poly(d, [(18, 46), (24, 42), (79, 47), (76, 55), (20, 51)], "wood", "ink")
    line(d, [(23, 44), (75, 48)], "wood_top", 2)
    drum(d, 45, 57, 28, 24)
    drum(d, 20, 66, 31, 23)
    line(d, [(29, 61), (53, 44)], "ink", 4)
    line(d, [(29, 60), (53, 43)], "wood_top", 2)
    line(d, [(46, 57), (31, 43)], "ink", 4)
    line(d, [(46, 56), (31, 42)], "wood_light", 2)
    rect(d, (51, 40, 56, 45), "paper", "wood_dark")
    rect(d, (28, 39, 33, 44), "paper_light", "wood_dark")
    return image


def forge():
    image, d = canvas()
    footing(d)
    block(d, 55, 25, 19, 59)
    slab(d, 52, 22, 25, 5, 3)
    rect(d, (59, 28, 64, 31), "deep")
    block(d, 20, 58, 48, 29)
    roof(d, 17, 53, 54, "wood")
    poly(d, [(27, 83), (27, 68), (31, 63), (47, 63), (53, 68), (53, 83)], "ink")
    rect(d, (30, 70, 49, 82), "fire_dark")
    poly(d, [(31, 80), (34, 70), (37, 76), (40, 66), (43, 74), (47, 70), (49, 81)], "fire", None)
    poly(d, [(35, 81), (38, 75), (40, 78), (43, 73), (45, 81)], "fire_light", None)
    for xx in (31, 39, 47):
        line(d, [(xx, 72), (xx, 83)], "iron_dark", 2)
    timber(d, 65, 78, 7, 12)
    poly(d, [(58, 73), (77, 73), (81, 69), (82, 76), (74, 80), (61, 80), (57, 77)], "iron", "ink")
    line(d, [(59, 74), (76, 74), (80, 71)], "iron_light")
    return image


def command_banner():
    image, d = canvas()
    footing(d)
    block(d, 33, 73, 30, 14)
    timber(d, 45, 18, 6, 57)
    poly(d, [(47, 7), (52, 15), (48, 21), (43, 15)], "gold", "ink")
    rect(d, (23, 26, 77, 31), "wood", "ink")
    line(d, [(25, 27), (74, 27)], "gold_light")
    poly(d, [(26, 31), (46, 32), (46, 72), (36, 80), (25, 71)], "cloth", "ink")
    poly(d, [(49, 32), (73, 31), (71, 71), (61, 80), (50, 72)], "cloth_dark", "ink")
    line(d, [(27, 33), (27, 69), (36, 76), (44, 70)], "cloth_light", 2)
    line(d, [(52, 34), (52, 70), (61, 76), (69, 70)], "cloth", 2)
    for x in (30, 54):
        poly(d, [(x, 44), (x + 4, 49), (x + 8, 40), (x + 11, 45), (x + 6, 60), (x + 2, 55)], "gold", None)
        line(d, [(x + 1, 44), (x + 4, 50)], "gold_light")
    return image


def gold_mine():
    image, d = canvas()
    footing(d)
    poly(d, [(15, 83), (18, 58), (27, 49), (35, 43), (55, 45), (70, 56), (77, 81)], "stone_dark")
    poly(d, [(18, 62), (27, 50), (35, 46), (45, 48), (34, 58), (31, 73)], "stone_light")
    poly(d, [(55, 47), (67, 56), (71, 74), (59, 68), (52, 55)], "stone")
    poly(d, [(28, 83), (28, 63), (34, 56), (54, 56), (61, 63), (61, 84)], "ink")
    timber(d, 26, 59, 7, 26)
    timber(d, 56, 59, 7, 26)
    timber(d, 24, 53, 41, 7)
    line(d, [(34, 81), (40, 65)], "wood_dark", 2)
    line(d, [(49, 81), (45, 65)], "wood_dark", 2)
    line(d, [(36, 83), (51, 83)], "iron", 2)
    line(d, [(33, 88), (55, 88)], "iron", 2)
    line(d, [(35, 92), (57, 92)], "iron", 2)
    poly(d, [(57, 78), (76, 78), (72, 90), (60, 90)], "wood", "iron_dark")
    poly(d, [(57, 78), (62, 73), (74, 73), (76, 78)], "gold_dark")
    coin(d, 61, 74)
    coin(d, 68, 79)
    rect(d, (61, 90, 64, 94), "ink")
    rect(d, (71, 89, 74, 93), "ink")
    # Pickaxe embedded in the left stone shoulder.
    line(d, [(17, 76), (29, 61)], "wood_dark", 4)
    line(d, [(17, 75), (29, 60)], "wood_top", 2)
    poly(d, [(20, 57), (28, 55), (36, 61), (31, 60), (27, 58), (20, 60)], "iron_light")
    return image


def royal_mint():
    image, d = canvas()
    footing(d)
    block(d, 22, 51, 52, 35)
    timber(d, 24, 52, 5, 33)
    timber(d, 61, 52, 5, 33)
    roof(d, 15, 43, 65)
    poly(d, [(31, 26), (34, 15), (41, 21), (48, 11), (56, 20), (64, 14), (62, 27)], "gold", "ink")
    line(d, [(34, 17), (35, 24), (60, 24)], "gold_light", 2)
    rect(d, (34, 58, 56, 78), "wood_dark", "ink")
    rect(d, (39, 59, 44, 69), "iron", "ink")
    rect(d, (35, 69, 57, 73), "iron_light", "iron_dark")
    rect(d, (35, 78, 57, 82), "wood_top", "wood_dark")
    coin(d, 40, 77, 2)
    coin(d, 62, 87, 3)
    coin(d, 19, 88, 2)
    return image


def bounty_board(greater=False):
    image, d = canvas()
    footing(d)
    timber(d, 22, 43, 7, 44)
    timber(d, 67, 43, 7, 44)
    rect(d, (19, 37, 77, 73), "wood_dark", "ink")
    for yy in (39, 47, 55, 63):
        rect(d, (21, yy, 74, yy + 6), "wood")
        line(d, [(22, yy), (73, yy)], "wood_light")
    roof(d, 15, 33, 66, "wood")
    rect(d, (31, 42, 59, 69), "paper_dark", "ink")
    rect(d, (32, 43, 57, 67), "paper")
    rect(d, (33, 43, 56, 45), "paper_light")
    rect(d, (35, 48, 52, 49), "red_dark")
    # A wanted portrait, not text pretending to be legible at sprite scale.
    poly(d, [(38, 54), (35, 51), (36, 59), (40, 63), (48, 63), (52, 58), (53, 51), (49, 54)], "stone_dark", None)
    rect(d, (40, 54, 48, 59), "deep")
    rect(d, (40, 55, 41, 55), "paper_light")
    rect(d, (47, 55, 48, 55), "paper_light")
    line(d, [(39, 65), (49, 65)], "wood_dark")
    poly(d, [(56, 63), (61, 62), (64, 66), (62, 71), (57, 71), (54, 67)], "red", "red_dark")
    coin(d, 60, 85, 2)
    if greater:
        # Heavy red warrant pennants and a crown distinguish the stronger branch.
        poly(d, [(18, 36), (27, 37), (27, 72), (22, 79), (17, 73)], "red", "ink")
        poly(d, [(68, 37), (77, 36), (78, 73), (73, 79), (68, 72)], "red_dark", "ink")
        line(d, [(19, 39), (19, 71), (22, 75)], "red_light")
        poly(d, [(35, 18), (36, 10), (43, 15), (48, 7), (53, 15), (60, 10), (59, 19)], "gold", "ink")
        line(d, [(37, 17), (57, 17)], "gold_light")
        coin(d, 23, 86, 3)
    return image


def tribute_office():
    image, d = canvas()
    footing(d)
    block(d, 22, 53, 52, 33)
    roof(d, 15, 47, 65)
    timber(d, 24, 53, 5, 33)
    timber(d, 63, 53, 5, 33)
    rect(d, (32, 60, 59, 81), "wood_dark", "ink")
    rect(d, (33, 61, 57, 70), "ink")
    for xx in (36, 43, 50):
        line(d, [(xx, 62), (xx, 69)], "iron", 2)
    rect(d, (30, 71, 61, 75), "wood_top", "wood_dark")
    # Open ledger and money chest make this an office rather than another mark.
    poly(d, [(28, 78), (39, 77), (45, 80), (56, 78), (59, 85), (47, 87), (40, 84), (29, 86)], "paper", "wood_dark")
    line(d, [(43, 80), (44, 85)], "paper_dark")
    line(d, [(31, 80), (37, 80)], "wood")
    line(d, [(48, 82), (54, 81)], "wood")
    rect(d, (62, 80, 77, 90), "wood", "ink")
    rect(d, (64, 79, 75, 82), "gold", "gold_dark")
    rect(d, (68, 83, 71, 87), "gold_light", "gold_dark")
    timber(d, 46, 15, 3, 17)
    poly(d, [(50, 15), (65, 17), (62, 23), (66, 28), (50, 26)], "cloth", "ink")
    coin(d, 64, 90, 2)
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    authored = {
        "lightning": lightning(), "lightning_longer_reach": lightning(True),
        "war_drums": war_drums(), "forge": forge(),
        "command_banner": command_banner(), "gold_mine": gold_mine(),
        "royal_mint": royal_mint(), "bounty_board": bounty_board(),
        "greater_bounty": bounty_board(True), "tribute_office": tribute_office(),
    }
    for name, image in authored.items():
        image.save(OUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
