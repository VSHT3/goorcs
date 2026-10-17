#!/usr/bin/env python3
"""Author additive Arrow branch pixel rigs; approved source PNGs stay unchanged."""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "towers"
SOURCE = Image.open(OUT / "arrow_tower_board.png").convert("RGBA")
INK = "#282725"
STEEL = "#687d85"
LIGHT = "#b8c9c3"
WOOD = "#986e42"


def box(draw, bounds, color, outline=None):
    draw.rectangle(bounds, fill=color, outline=outline)


def crate(draw, x, y, kind):
    box(draw, (x, y, x + 12, y + 9), "#735239", INK)
    box(draw, (x + 1, y + 1, x + 11, y + 2), "#c59960")
    box(draw, (x + 2, y + 5, x + 10, y + 6), "#49392d")
    for xx in (x + 3, x + 8):
        if kind == "fire":
            box(draw, (xx, y - 6, xx + 3, y), "#426d4b", INK)
            box(draw, (xx + 1, y - 8, xx + 2, y - 5), "#91b982")
            box(draw, (xx + 1, y - 9, xx + 2, y - 8), "#d5b779")
        else:
            box(draw, (xx, y - 4, xx + 3, y), "#56654c", INK)
            box(draw, (xx + 1, y - 6, xx + 2, y - 4), LIGHT)


def board(kind, step=0):
    image = SOURCE.copy()
    d = ImageDraw.Draw(image)
    colors = {"fire": ("#a84930", "#e69350"), "bomb": ("#4d5853", "#99a17d"),
              "flame": ("#b7622f", "#f1ba65"), "rocket": ("#465a5b", "#a3bab1"),
              "four": ("#53694a", "#a8b87c"), "minigun": ("#68635b", "#d1b47a")}
    dark, light = colors[kind]
    # Applied hardware is mounted on the existing parapet, never a replacement base.
    d.polygon([(14, 40), (25, 43), (25, 56), (20, 53), (15, 55)], fill=dark, outline=INK)
    d.line([(16, 41), (23, 44), (23, 51)], fill=light)
    box(d, (18, 44, 20, 49), light)
    if kind in ("fire", "bomb"):
        crate(d, 39, 22, kind)
        if step:
            box(d, (49, 34, 60, 38), STEEL, INK)
            for x in (50, 54, 58):
                box(d, (x, 35, x, 36), LIGHT)
            box(d, (6, 27, 9, 40), "#b8934f", INK)
    elif kind == "flame":
        for x in (9, 52):
            box(d, (x, 22, x + 8, 37), "#5c5c42", INK)
            box(d, (x + 2, 23, x + 3, 35), "#c2aa61")
            box(d, (x, 27, x + 8, 29), "#3a4543")
            box(d, (x + 3, 19, x + 5, 22), STEEL, INK)
        d.line([(16, 34), (21, 38), (28, 36)], fill="#3b3430", width=2)
    elif kind in ("rocket", "minigun"):
        box(d, (12, 29, 58, 33), STEEL, INK)
        box(d, (13, 29, 57, 29), LIGHT)
        for x in (15, 27, 40, 53):
            box(d, (x, 31, x + 1, 31), "#dfb86c")
        if kind == "rocket":
            box(d, (8, 21, 17, 29), "#535c4b", INK)
            for x in (10, 14):
                box(d, (x, 15, x + 2, 26), STEEL, INK)
                d.polygon([(x, 15), (x + 1, 12), (x + 2, 15)], fill="#c7975c")
        else:
            box(d, (8, 23, 20, 30), "#9a774b", INK)
            for x in range(9, 20, 3):
                box(d, (x, 24, x, 28), "#e1c68a")
        for i in range(step):
            box(d, (44 + i * 5, 35, 47 + i * 5, 39), "#c9a75b", INK)
    return image


def eight_story():
    image = Image.new("RGBA", (70, 124))
    d = ImageDraw.Draw(image)
    for x in (9, 56):
        box(d, (x, 21, x + 5, 76), "#59422f", INK)
        box(d, (x + 1, 22, x + 1, 75), "#c19863")
        for y in (37, 53):
            box(d, (x, y, x + 5, y + 2), "#586465")
    d.line([(14, 32), (55, 70)], fill="#493d2c", width=4)
    d.line([(14, 31), (55, 69)], fill="#aa8051", width=2)
    image.alpha_composite(board("four"), (0, 38))
    image.alpha_composite(SOURCE.crop((0, 0, 70, 39)), (0, 0))
    d = ImageDraw.Draw(image)
    box(d, (7, 35, 61, 38), "#49372b", INK)
    box(d, (9, 35, 59, 35), "#c8a173")
    # Ladder links the two actual walkable decks.
    for x in (51, 57):
        box(d, (x, 37, x + 1, 65), "#59422f")
    for y in range(39, 65, 5):
        box(d, (52, y, 56, y + 1), "#c19863")
    return image


def dark_heads():
    image = Image.open(OUT / "archer_heads.png").convert("RGBA")
    # Recolor only the magenta hair pixels, retaining every native face/facing pixel.
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if a and r > g * 1.25 and b > g * 1.10 and b > 55:
                value = min(87, max(31, int((r + b) * 0.18)))
                image.putpixel((x, y), (value, int(value * .86), int(value * .77), a))
    return image


def muscular_bodies():
    image = Image.open(OUT / "archer_bodies.png").convert("RGBA")
    d = ImageDraw.Draw(image)
    for frame in range(4):
        x = frame * 14
        # Broad exposed shoulders, vest and native boot/leg silhouette retained below.
        box(d, (x, 1, x + 13, 6), "#654532", INK)
        box(d, (x + 1, 1, x + 12, 4), "#d89c70")
        box(d, (x + 2, 1, x + 4, 2), "#f2c295")
        box(d, (x + 9, 1, x + 11, 2), "#e8b183")
        box(d, (x + 4, 1, x + 9, 8), "#4d5949")
        box(d, (x + 5, 2, x + 6, 6), "#78836a")
        box(d, (x + 2, 7, x + 11, 8), "#705037")
        box(d, (x + 7, 7, x + 8, 8), "#d0bd83")
    return image


def main():
    variants = {
        "fire_arrows": board("fire"), "molotov": board("fire", 1),
        "quick_pitch": board("fire", 2), "flamethrower": board("flame"),
        "bomb_arrows": board("bomb"), "bigger_bombs": board("bomb", 1),
        "anti_orc_grenades": board("bomb", 2), "aom": board("rocket"),
        "aom_speed_1": board("rocket", 1), "aom_speed_2": board("rocket", 2),
        "four_archers": board("four"), "eight_archers": eight_story(),
        "arrow_minigun": board("minigun"),
    }
    # Quick-pitch and grenade branch upgrades get visibly different supply hardware.
    for key in ("quick_pitch", "anti_orc_grenades"):
        d = ImageDraw.Draw(variants[key])
        box(d, (30, 32, 38, 36), "#c59a58", INK)
        box(d, (31, 32, 37, 32), "#efce8b")
    for key, image in variants.items():
        image.save(OUT / ("arrow_" + key + ".png"))
    dark_heads().save(OUT / "archer_dark_heads.png")
    muscular_bodies().save(OUT / "archer_muscular_bodies.png")


if __name__ == "__main__":
    main()
