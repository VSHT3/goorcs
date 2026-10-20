#!/usr/bin/env python3
"""Original procedural gameplay tower artwork, authored for Gorcs (2026).

Native 96x112 RGBA pixels; integer polygons/rectangles, hard alpha, no source
images, sampling, antialiasing, models, or third-party artwork. Upper-left light,
front-dominant elevated timber/stone forms. Run with Pillow to reproduce only
the War Drums family PNGs (base, four branches and their finales); accepted
Lightning and Gold Mine families and established tower PNGs are never written.
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


def roof(d, x, y, w, fill="cloth"):
    poly(d, [(x, y), (x + 7, y - 16), (x + w - 8, y - 16), (x + w, y - 3), (x + w - 7, y + 3)], fill)
    line(d, [(x + 7, y - 15), (x + w - 9, y - 15)], "cloth_light" if fill == "cloth" else "wood_top", 2)
    for yy in (y - 9, y - 3):
        line(d, [(x + 5, yy), (x + w - 7, yy)], "cloth_dark" if fill == "cloth" else "wood_dark")
    line(d, [(x, y), (x + w - 7, y + 3)], "wood_dark", 3)


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


def dragonfire_forge():
    # The Forge finale: white-hot blue dragonfire and gilded eaves.
    image, d = canvas()
    footing(d)
    block(d, 55, 25, 19, 59)
    slab(d, 52, 22, 25, 5, 3)
    rect(d, (59, 28, 64, 31), "deep")
    for yy in (16, 10):
        poly(d, [(60, yy + 5), (62, yy), (64, yy + 5)], "blue_light", None)
    block(d, 20, 58, 48, 29)
    roof(d, 17, 53, 54, "wood")
    line(d, [(24, 38), (62, 38)], "gold", 2)
    line(d, [(17, 53), (64, 56)], "gold_dark", 2)
    poly(d, [(27, 83), (27, 68), (31, 63), (47, 63), (53, 68), (53, 83)], "ink")
    rect(d, (30, 70, 49, 82), "blue_dark")
    poly(d, [(31, 80), (34, 68), (37, 75), (40, 63), (43, 73), (47, 68), (49, 81)], "blue", None)
    poly(d, [(35, 81), (38, 73), (40, 77), (43, 71), (45, 81)], "blue_light", None)
    for xx in (31, 39, 47):
        line(d, [(xx, 72), (xx, 83)], "gold_dark", 2)
    timber(d, 65, 78, 7, 12)
    poly(d, [(58, 73), (77, 73), (81, 69), (82, 76), (74, 80), (61, 80), (57, 77)], "iron", "ink")
    line(d, [(59, 74), (76, 74), (80, 71)], "gold_light")
    return image


def warlords_standard():
    # The Command Banner finale: blood-red standards with a gold skull.
    image, d = canvas()
    footing(d)
    block(d, 33, 73, 30, 14)
    timber(d, 45, 12, 6, 63)
    poly(d, [(47, 1), (53, 9), (48, 15), (42, 9)], "gold", "ink")
    rect(d, (21, 22, 79, 27), "wood", "ink")
    line(d, [(23, 23), (76, 23)], "gold_light")
    poly(d, [(24, 27), (46, 28), (46, 74), (35, 83), (23, 73)], "red", "ink")
    poly(d, [(49, 28), (76, 27), (74, 73), (62, 83), (50, 74)], "red_dark", "ink")
    line(d, [(25, 29), (25, 71), (35, 79), (44, 72)], "red_light", 2)
    line(d, [(52, 30), (52, 72), (62, 79), (72, 72)], "red", 2)
    for x in (28, 54):
        poly(d, [(x + 2, 42), (x + 12, 42), (x + 14, 50), (x + 11, 56), (x + 3, 56), (x, 50)], "gold", "gold_dark")
        rect(d, (x + 4, 47, x + 5, 49), "ink")
        rect(d, (x + 9, 47, x + 10, 49), "ink")
        line(d, [(x + 5, 53), (x + 9, 53)], "gold_dark")
        line(d, [(x + 3, 43), (x + 11, 43)], "gold_light")
    return image


def _lookout(d, height):
    top = 86 - height
    timber(d, 26, top + 10, 6, height - 10)
    timber(d, 64, top + 10, 6, height - 10)
    line(d, [(31, top + 22), (64, top + 44)], "wood_dark", 3)
    line(d, [(31, top + 44), (64, top + 22)], "wood_dark", 3)
    poly(d, [(20, top + 10), (26, top + 4), (76, top + 4), (78, top + 10), (74, top + 15), (22, top + 15)], "wood", "ink")
    line(d, [(25, top + 6), (75, top + 6)], "wood_top", 2)
    for xx in range(26, 74, 8):
        line(d, [(xx, top + 4), (xx, top - 4)], "wood_dark", 2)
    line(d, [(24, top - 4), (74, top - 4)], "wood_light", 2)
    return top


def _horn(d, x, y):
    # A curved ivory war horn with brass bands, bell to the left.
    poly(d, [(x, y), (x + 8, y - 6), (x + 22, y - 9), (x + 34, y - 7), (x + 36, y - 3), (x + 24, y - 3), (x + 11, y + 1), (x + 4, y + 9)], "paper", "ink")
    line(d, [(x + 6, y - 3), (x + 22, y - 7), (x + 32, y - 6)], "paper_light", 2)
    poly(d, [(x - 4, y - 4), (x + 2, y - 9), (x + 6, y + 6), (x, y + 12)], "paper_dark", "ink")
    for bx in (x + 14, x + 26):
        line(d, [(bx, y - 9), (bx, y - 2)], "gold", 2)


def lookout_horn():
    image, d = canvas()
    footing(d)
    top = _lookout(d, 52)
    _horn(d, 30, top - 8)
    timber(d, 66, top - 30, 4, 26)
    poly(d, [(70, top - 30), (84, top - 26), (70, top - 21)], "cloth_light", "ink")
    return image


def all_seeing_tower():
    # Lookout Horn finale: a taller tower, signal beacon and a watching-eye banner.
    image, d = canvas()
    footing(d)
    top = _lookout(d, 62)
    _horn(d, 30, top - 8)
    rect(d, (60, top - 16, 74, top - 4), "iron_dark", "ink")
    poly(d, [(61, top - 16), (64, top - 28), (67, top - 21), (70, top - 31), (73, top - 16)], "fire", None)
    poly(d, [(64, top - 16), (67, top - 24), (70, top - 16)], "fire_light", None)
    poly(d, [(33, top + 16), (63, top + 16), (61, top + 34), (48, top + 40), (35, top + 34)], "cloth", "ink")
    poly(d, [(40, top + 25), (48, top + 20), (56, top + 25), (48, top + 30)], "paper_light", "ink")
    rect(d, (46, top + 23, 50, top + 27), "ink")
    return image


def _totem(d, x, top, big):
    timber(d, x, top, 18, 86 - top)
    faces = 3
    for i in range(faces):
        fy = top + 4 + i * ((86 - top - 8) // faces)
        rect(d, (x + 3, fy + 4, x + 6, fy + 6), "ink")
        rect(d, (x + 11, fy + 4, x + 14, fy + 6), "ink")
        line(d, [(x + 4, fy + 11), (x + 13, fy + 11)], "red", 2)
        line(d, [(x + 2, fy + 2), (x + 7, fy + 5)], "red", 1)
        line(d, [(x + 16, fy + 2), (x + 11, fy + 5)], "red", 1)
    size = 10 if big else 8
    cx, cy = x + 9, top - size + 2
    poly(d, [(cx - size, cy), (cx - size + 2, cy - size), (cx + size - 2, cy - size), (cx + size, cy), (cx + size - 3, cy + size - 2), (cx - size + 3, cy + size - 2)], "paper_light", "ink")
    rect(d, (cx - 5, cy - 3, cx - 2, cy), "fire" if big else "ink")
    rect(d, (cx + 2, cy - 3, cx + 5, cy), "fire" if big else "ink")
    line(d, [(cx - 3, cy + 4), (cx + 3, cy + 4)], "paper_dark")
    if big:
        poly(d, [(cx - size, cy - 6), (cx - size - 8, cy - 16), (cx - size + 1, cy - 10)], "paper", "ink")
        poly(d, [(cx + size, cy - 6), (cx + size + 8, cy - 16), (cx + size - 1, cy - 10)], "paper", "ink")


def _axe(d, x, y, flip):
    s = -1 if flip else 1
    line(d, [(x, y), (x + 14 * s, y + 26)], "wood_dark", 3)
    poly(d, [(x - 2 * s, y - 2), (x + 8 * s, y - 6), (x + 10 * s, y + 6), (x + 2 * s, y + 5)], "iron", "ink")
    line(d, [(x + 8 * s, y - 5), (x + 10 * s, y + 5)], "iron_light")


def bloodlust_totem():
    image, d = canvas()
    footing(d)
    _axe(d, 26, 52, False)
    _axe(d, 70, 52, True)
    _totem(d, 39, 34, False)
    for x in (37, 57):
        line(d, [(x, 42), (x + (-4 if x < 50 else 4), 58)], "red", 2)
    return image


def skullsplitter_totem():
    image, d = canvas()
    footing(d)
    for off in (0, 8):
        _axe(d, 22 + off, 46 + off, False)
        _axe(d, 74 - off, 46 + off, True)
    _totem(d, 39, 30, True)
    for x in (37, 57):
        line(d, [(x, 38), (x + (-5 if x < 50 else 5), 60)], "red_dark", 3)
        line(d, [(x, 38), (x + (-5 if x < 50 else 5), 58)], "red", 1)
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    authored = {
        "war_drums": war_drums(), "forge": forge(),
        "command_banner": command_banner(),
        "forge_dragonfire": dragonfire_forge(),
        "banner_warlords_standard": warlords_standard(),
        "lookout_horn": lookout_horn(), "lookout_all_seeing": all_seeing_tower(),
        "bloodlust_totem": bloodlust_totem(), "bloodlust_skullsplitter": skullsplitter_totem(),
    }
    for name, image in authored.items():
        image.save(OUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
