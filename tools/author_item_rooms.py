#!/usr/bin/env python3
"""Original 640x360 Itemiery interiors; integer Pillow geometry, no source art.

Five physical shelf boards support six bays apiece. Item hit areas are shared
with ItemieryChamber.slot_rect: (83 + column*82, 58 + row*44, 64, 36).
Run with --contact-sheet /tmp/itemiery-rooms.png for an outside-assets overview.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "ui" / "itemiery"
SIZE = (640, 360)
INK = "#0b1110"
BONE = ("#514e3b", "#8b8260", "#c4ba8d", "#eee2b6")
GOLD = ("#382b21", "#6b4929", "#ab7937", "#dbb65a", "#f7dfa0")
JADE = ("#0b1c1a", "#183c32", "#28634a", "#56a96a", "#a2e89a")


def rect(d, box, fill, outline=None):
    d.rectangle(tuple(int(v) for v in box), fill=fill, outline=outline)


def line(d, points, fill, width=1):
    d.line([(int(x), int(y)) for x, y in points], fill=fill, width=width)


def poly(d, points, fill, outline=None):
    d.polygon([(int(x), int(y)) for x, y in points], fill=fill, outline=outline)


def diamond(d, x, y, w, h, ramp):
    poly(d, [(x, y-h), (x+w, y), (x, y+h), (x-w, y)], ramp[1], INK)
    poly(d, [(x, y-h+1), (x, y+h-2), (x-w+1, y)], ramp[2])
    line(d, [(x-w+2, y), (x, y-h+2), (x+w-2, y)], ramp[-1])


def rivet(d, x, y, ramp):
    rect(d, (x-1, y-1, x+1, y+1), ramp[0])
    d.point((x, y-1), fill=ramp[-1])
    d.point((x+1, y), fill=ramp[2])


def filigree(d, x, y, flip, ramp):
    # A deliberately angular acanthus curl, not repeated pseudo-lettering.
    pts = [(0, 0), (8, -2), (14, -8), (14, -13), (10, -16),
           (6, -14), (6, -10), (9, -9)]
    line(d, [(x+px*flip, y+py) for px, py in pts], ramp[1], 3)
    line(d, [(x+px*flip, y+py-1) for px, py in pts], ramp[3])
    line(d, [(x+5*flip, y-2), (x+4*flip, y-7), (x, y-11)], ramp[2])
    d.point((x+10*flip, y-16), fill=ramp[-1])


def masonry(d, ramp, block_w=64, block_h=26):
    rect(d, (0, 0, 639, 291), ramp[0])
    for row in range(12):
        y = row * block_h
        for col in range(-1, 12):
            x = col * block_w + (block_w//2 if row % 2 else 0)
            shade = 1 + ((row*3+col*5) % 3 == 0)
            rect(d, (x+1, y+1, x+block_w-2, y+block_h-2), ramp[shade])
            line(d, [(x+3, y+2), (x+block_w-5, y+2)], ramp[3])
            line(d, [(x+block_w-2, y+4), (x+block_w-2, y+block_h-4)], ramp[0])
            # A handful of cut marks, not full-surface noise.
            if (row+col) % 4 == 0:
                line(d, [(x+11, y+block_h-6), (x+19, y+block_h-6)], ramp[0])


def floor(d, stone, accent, tier):
    rect(d, (0, 289, 639, 359), stone[1])
    rect(d, (0, 289, 639, 294), stone[0])
    line(d, [(0, 295), (639, 295)], stone[3])
    for y in (308, 330, 359):
        line(d, [(0, y), (639, y)], stone[0], 2)
        line(d, [(0, y+2), (639, y+2)], stone[2])
    for x in range(-340, 1040, 86):
        line(d, [(320+(x-320)*0.60, 295), (x, 360)], stone[0], 2)
    if tier == 0:
        for x, y, length in ((35, 315, 27), (145, 343, 16), (470, 321, 31), (541, 349, 24)):
            line(d, [(x, y), (x+length, y)], stone[3])
        return
    # Inlay is on the floor, safely below the item shelves.
    poly(d, [(244, 296), (396, 296), (452, 359), (188, 359)], accent[0])
    for side in (-1, 1):
        line(d, [(320+side*74, 296), (320+side*130, 359)], accent[2], 2)
        line(d, [(320+side*66, 296), (320+side*116, 359)], accent[1])
    if tier == 1:
        for y in range(302, 360, 8):
            half = 70+(y-296)*3//4
            line(d, [(320-half, y), (320+half, y)], "#294335")
        for side in (-1, 1):
            line(d, [(320+side*57, 302), (320+side*100, 356)], "#6f8051")
    elif tier == 2:
        for x in (286, 320, 354):
            diamond(d, x, 324, 21, 10, accent)
        line(d, [(246, 344), (320, 308), (394, 344)], accent[2])
    elif tier == 3:
        d.ellipse((276, 302, 364, 350), outline=accent[2], width=2)
        d.ellipse((285, 306, 355, 346), outline=accent[1])
        poly(d, [(320, 307), (343, 337), (286, 319), (354, 319), (297, 337)], outline=accent[3], fill=None)
        for x in (230, 410):
            diamond(d, x, 349, 8, 4, accent)
    elif tier == 4:
        poly(d, [(320, 304), (377, 331), (349, 352), (320, 343), (291, 352), (263, 331)], accent[0], accent[2])
        for side in (-1, 1):
            line(d, [(320+side*8, 316), (320+side*30, 330), (320+side*13, 341)], accent[3], 2)
    elif tier == 5:
        for side in (-1, 1):
            for x in range(245, 310, 16):
                xx = x if side < 0 else 640-x
                filigree(d, xx, 349, side, GOLD)
        diamond(d, 320, 326, 30, 15, GOLD)
        diamond(d, 320, 326, 15, 8, accent)
    else:
        # Monumental emerald seal, with broad jaw and upward ivory tusks.
        poly(d, [(320, 301), (370, 315), (384, 340), (320, 356), (256, 340), (270, 315)], JADE[1], JADE[3])
        line(d, [(276, 318), (320, 308), (364, 318)], GOLD[2], 2)
        poly(d, [(291, 322), (306, 325), (304, 331), (291, 328)], JADE[4])
        poly(d, [(349, 322), (334, 325), (336, 331), (349, 328)], JADE[4])
        line(d, [(303, 341), (337, 341)], JADE[0], 3)
        for side in (-1, 1):
            poly(d, [(320+side*18, 345), (320+side*26, 342), (320+side*29, 328),
                     (320+side*24, 334)], BONE[2])
        for x in (224, 416):
            diamond(d, x, 351, 8, 5, GOLD)


def wood_grain(d, box, ramp, phase=0):
    x0, y0, x1, y1 = box
    for y in range(y0+3, y1-1, 7):
        offset = (y*3+phase*17) % 21
        line(d, [(x0+4+offset, y), (min(x1-3, x0+36+offset), y)], ramp[1])
        if x1-x0 > 90:
            line(d, [(x1-66+offset, y+1), (x1-13, y+1)], ramp[3])


def rack(d, timber, metal, kind):
    # Continuous back panelling and five boards, not thirty UI cards.
    rect(d, (71, 49, 568, 283), INK)
    rect(d, (78, 55, 561, 271), timber[0])
    for bay in range(6):
        x = 80+bay*82
        rect(d, (x, 56, x+70, 269), timber[1])
        rect(d, (x+2, 57, x+69, 268), timber[0])
        # Dim horizontal grain leaves the icon silhouettes clean.
        if kind in (0, 1, 3, 5):
            for y in range(66+bay % 3, 265, 17):
                line(d, [(x+7, y), (x+22+(y % 19), y)], timber[1])
            line(d, [(x+35, 57), (x+35, 268)], timber[1])
        elif kind == 2:
            line(d, [(x+2, 58), (x+2, 268)], "#233847")
        elif kind == 4:
            for y in (62, 149, 237):
                line(d, [(x+5, y), (x+13, y+7), (x+15, y+14)], "#241e22")
        else:
            line(d, [(x+5, 62), (x+5, 264)], "#18362d")
    # Shelf undersides cast long quiet shadows; each board has a shallow
    # horizontal return at the back. These are carpentry, not slot borders.
    for row in range(5):
        y = 58+row*44
        rect(d, (82, y, 559, y+3), INK)
        line(d, [(82, y+4), (559, y+4)], timber[0])
        rect(d, (82, y+31, 559, y+34), timber[1])
        line(d, [(82, y+35), (559, y+35)], timber[2])
    # Top and bottom beams.
    for y, h in ((48, 9), (276, 9)):
        rect(d, (70, y, 569, y+h), timber[0], INK)
        rect(d, (73, y+1, 566, y+3), timber[3])
        rect(d, (73, y+4, 566, y+h-1), timber[2])
        wood_grain(d, (75, y+3, 564, y+h), timber)
        if kind >= 3:
            for x in range(87, 555, 18):
                line(d, [(x, y+5), (x+4, y+7), (x+8, y+5)], metal[2])
                if kind >= 5:
                    d.point((x+4, y+6), fill=metal[3])
    # Uprights sit in the 18px gaps between the contractual 64px hit areas.
    for col in range(7):
        x = 74+col*82
        rect(d, (x, 55, x+7, 279), timber[0])
        rect(d, (x+1, 56, x+5, 277), timber[2])
        line(d, [(x+1, 57), (x+1, 275)], timber[3])
        if kind in (2, 4, 6):
            line(d, [(x+3, 59), (x+3, 275)], metal[1])
        for y in (62, 278):
            rivet(d, x+4, y, metal)
        if kind in (1, 5):
            for yy in range(69, 266, 22):
                line(d, [(x+2, yy), (x+4, yy+3), (x+2, yy+6)], metal[1])
        elif kind == 6:
            for yy in (73, 161, 249):
                line(d, [(x+2, yy), (x+4, yy-2), (x+4, yy+3), (x+2, yy+5)], JADE[3])
    for row in range(5):
        y = 94+row*44
        rect(d, (78, y-1, 561, y+8), INK)
        # The shallow top plane is directly under each slot's feet.
        rect(d, (79, y-1, 560, y), timber[3])
        rect(d, (77, y+1, 562, y+5), timber[2])
        line(d, [(79, y+2), (560, y+2)], timber[3])
        line(d, [(79, y+6), (560, y+6)], timber[0])
        if kind in (2, 4, 5, 6):
            rect(d, (78, y+3, 561, y+5), metal[1])
            line(d, [(79, y+3), (560, y+3)], metal[2])
        for col in range(7):
            x = 77+col*82
            # Carved brackets attach to the supports, below the board.
            poly(d, [(x-3, y+6), (x+4, y+6), (x+4, y+13), (x+1, y+13)], timber[1])
            if kind > 0:
                poly(d, [(x-3, y+6), (x+4, y+6), (x+4, y+10), (x, y+10)], metal[1])
                d.point((x+2, y+7), fill=metal[3])
        if kind == 0:
            wood_grain(d, (81, y+1, 558, y+6), timber, row)
        if kind in (1, 3, 5, 6):
            for bay in range(6):
                x = 115+bay*82
                if kind == 1:
                    line(d, [(x-8, y+4), (x, y+2), (x+8, y+4)], metal[2])
                elif kind == 3:
                    diamond(d, x, y+4, 4, 2, metal)
                elif kind == 5:
                    line(d, [(x-19, y+5), (x-12, y+3), (x-4, y+5), (x+4, y+3), (x+12, y+5), (x+19, y+3)], GOLD[2])
                else:
                    line(d, [(x-21, y+5), (x-13, y+3), (x-5, y+5)], JADE[3])
                    line(d, [(x+5, y+5), (x+13, y+3), (x+21, y+5)], JADE[3])
    for x in (72, 154, 482, 564):
        rect(d, (x-2, 284, x+8, 291), timber[0])
        line(d, [(x-2, 284), (x+8, 284)], timber[3])


def cornice(d, wall, trim, tier):
    rect(d, (0, 0, 639, 8), INK)
    rect(d, (0, 9, 639, 14), wall[3])
    rect(d, (0, 15, 639, 19), wall[1])
    rect(d, (0, 20, 639, 22), INK)
    for x in range(8, 640, 23 if tier < 5 else 16):
        rect(d, (x, 14, x+6, 19), trim[1])
        line(d, [(x, 14), (x+5, 14)], trim[2])
    for side in (-1, 1):
        x = 15 if side < 0 else 609
        rect(d, (x, 25, x+15, 282), wall[0])
        rect(d, (x+2, 27, x+12, 279), wall[2])
        line(d, [(x+2, 28), (x+2, 278)], wall[3])
        for y in range(48, 280, 32):
            line(d, [(x+2, y), (x+12, y)], wall[0])
        rect(d, (x-4, 277, x+19, 287), wall[2], wall[0])
        line(d, [(x-3, 278), (x+18, 278)], wall[3])


def lantern(d, x, y, metal, light, style):
    # All fixtures are mounted on the side walls, outside item hit areas.
    line(d, [(x-10, y+5), (x-10, y-12), (x, y-12), (x, y-7)], metal[1], 3)
    line(d, [(x-9, y-11), (x-1, y-11)], metal[3])
    if style == "crystal":
        poly(d, [(x, y-15), (x+7, y-5), (x+5, y+12), (x, y+18), (x-6, y+10), (x-7, y-5)], light[1], INK)
        poly(d, [(x, y-13), (x+1, y+13), (x-4, y+8), (x-5, y-4)], light[3])
        line(d, [(x, y-12), (x+4, y-4), (x+2, y+10)], light[2])
        poly(d, [(x-8, y+11), (x+8, y+11), (x+5, y+17), (x-5, y+17)], metal[2], INK)
    elif style == "orb":
        d.ellipse((x-8, y-8, x+8, y+8), fill=light[1], outline=INK)
        d.ellipse((x-5, y-6, x+5, y+5), fill=light[2])
        rect(d, (x-3, y-5, x, y-2), light[3])
        line(d, [(x-11, y+2), (x-8, y+9), (x, y+12), (x+8, y+9), (x+11, y+2)], metal[2], 2)
        diamond(d, x, y+17, 3, 5, metal)
    elif style == "brazier":
        poly(d, [(x-9, y+3), (x-5, y-4), (x-6, y-15), (x, y-9), (x+2, y-24), (x+8, y-12), (x+10, y-2), (x+6, y+5)], light[1])
        poly(d, [(x-3, y+2), (x-1, y-11), (x+3, y-6), (x+5, y-13), (x+6, y+2)], light[2])
        poly(d, [(x-2, y+3), (x+2, y-6), (x+4, y+3)], light[3])
        poly(d, [(x-12, y+3), (x+12, y+3), (x+7, y+12), (x-7, y+12)], metal[1], INK)
        line(d, [(x-10, y+4), (x+10, y+4)], metal[3])
        rect(d, (x-2, y+12, x+2, y+22), metal[2])
    else:
        poly(d, [(x-8, y-8), (x+8, y-8), (x+10, y+12), (x-10, y+12)], metal[1], INK)
        rect(d, (x-6, y-5, x+6, y+9), light[1])
        rect(d, (x-4, y-4, x+3, y+7), light[2])
        rect(d, (x-2, y-3, x+1, y+5), light[3])
        line(d, [(x, y-5), (x, y+10)], metal[1])
        rect(d, (x-10, y+11, x+10, y+14), metal[2], INK)
        poly(d, [(x-10, y-9), (x, y-16), (x+10, y-9)], metal[2], INK)
        d.point((x-3, y-11), fill=metal[3])


def leaf_vine(d, x, y, length, flip):
    for i in range(length):
        yy = y+i*9
        xx = x + ((i % 5)-2)*flip
        line(d, [(xx, yy), (xx+flip*3, yy+10)], "#344d30")
        side = flip if i % 2 else -flip
        poly(d, [(xx, yy+2), (xx+side*7, yy-1), (xx+side*9, yy+3), (xx+side*4, yy+7)], "#42653a", INK)
        line(d, [(xx+side*2, yy+3), (xx+side*6, yy+2)], "#7c9250")


def tusk(d, x, y, height, side, jade=False):
    # Upward-curving load-bearing tusks, with a separate shaded inner face.
    ramp = JADE if jade else BONE
    pts = [(x-10*side, y), (x+11*side, y), (x+17*side, y-height*2//5),
           (x+13*side, y-height*3//4), (x-3*side, y-height),
           (x+3*side, y-height*3//4), (x+3*side, y-height//2)]
    poly(d, pts, ramp[1], INK)
    pts2 = [(x-7*side, y-3), (x+4*side, y-4), (x+10*side, y-height*2//5),
            (x+9*side, y-height*3//4), (x-1*side, y-height+8),
            (x+6*side, y-height//2)]
    poly(d, pts2, ramp[2])
    line(d, [(x-7*side, y-5), (x+1*side, y-height//2), (x-2*side, y-height+8)], ramp[3], 2)
    for yy in (y-10, y-17):
        line(d, [(x-9*side, yy), (x+10*side, yy-2)], GOLD[1], 3)
        line(d, [(x-8*side, yy-1), (x+9*side, yy-3)], GOLD[3])


def orc_crest(d, x, y):
    # Architectural keystone: crown, brows, jaw, ears and upward tusks.
    poly(d, [(x-32, y-8), (x-43, y-18), (x-39, y-3), (x-27, y+3)], JADE[2], INK)
    poly(d, [(x+32, y-8), (x+43, y-18), (x+39, y-3), (x+27, y+3)], JADE[2], INK)
    poly(d, [(x-27, y-18), (x+27, y-18), (x+30, y+5), (x+18, y+19), (x-18, y+19), (x-30, y+5)], JADE[1], GOLD[2])
    poly(d, [(x-23, y-13), (x+23, y-13), (x+21, y+8), (x+14, y+14), (x-14, y+14), (x-21, y+8)], JADE[2])
    line(d, [(x-22, y-10), (x-5, y-6)], JADE[0], 4)
    line(d, [(x+22, y-10), (x+5, y-6)], JADE[0], 4)
    rect(d, (x-18, y-5, x-9, y-3), JADE[4])
    rect(d, (x+9, y-5, x+18, y-3), JADE[4])
    poly(d, [(x-3, y-3), (x+3, y-3), (x+5, y+5), (x-5, y+5)], JADE[3])
    line(d, [(x-13, y+10), (x+13, y+10)], JADE[0], 3)
    for side in (-1, 1):
        poly(d, [(x+side*12, y+15), (x+side*19, y+11), (x+side*20, y-1), (x+side*15, y+4)], BONE[2], INK)
        line(d, [(x+side*15, y+12), (x+side*18, y+2)], BONE[3])
    poly(d, [(x-26, y-18), (x-29, y-29), (x-16, y-24), (x-12, y-32),
             (x, y-24), (x+12, y-32), (x+16, y-24), (x+29, y-29), (x+26, y-18)], GOLD[2], INK)
    line(d, [(x-24, y-20), (x+24, y-20)], GOLD[4])
    diamond(d, x, y-21, 4, 6, JADE)


PALETTES = [
    # wall, shelf timber/stone, hardware, ambient lamp
    (("#18221e", "#2c3830", "#354237", "#4a5746"),
     ("#271f18", "#3c2e21", "#735238", "#a17e50"),
     ("#222925", "#454c3b", "#777b58", "#a4a784"),
     ("#4c3525", "#a06b35", "#d4a354", "#f4d18a")),
    (("#15231d", "#283b2d", "#344836", "#506049"),
     ("#241f16", "#3a2e1b", "#80562f", "#b58c4c"),
     ("#30291b", "#665432", "#9f8344", "#cfb673"),
     ("#354027", "#899148", "#c4c46c", "#ede4a6")),
    (("#111c28", "#223140", "#293e4e", "#425b6c"),
     ("#111e29", "#1c303d", "#3c5363", "#7c959c"),
     ("#1c2b36", "#405c6d", "#7897a5", "#bbd9de"),
     ("#1c3c4c", "#3b8192", "#80c9cf", "#d1f0e2")),
    (("#1a1528", "#30263f", "#3d2e4f", "#5a456c"),
     ("#211a29", "#322438", "#594057", "#927080"),
     ("#2a2638", "#62516d", "#a28ba4", "#d6b7d6"),
     ("#402e59", "#82569e", "#c59cdb", "#f3dbef")),
    (("#100f17", "#211e29", "#2c2731", "#43383f"),
     ("#16151c", "#221d25", "#49313a", "#77515a"),
     ("#2a171f", "#62303a", "#aa5356", "#d8917c"),
     ("#4a201e", "#b4432e", "#ec8744", "#ffe2a0")),
    (("#252019", "#44382a", "#574732", "#7b6746"),
     ("#2a1c18", "#4a2c20", "#855333", "#c38b4d"),
     GOLD,
     ("#6b4929", "#bd913f", "#efcf76", "#fff0b5")),
    (("#091612", "#132a23", "#1e3a2f", "#385342"),
     ("#0a1916", "#102c24", "#28503b", "#54845a"),
     GOLD,
     ("#143e2d", "#37895a", "#81d783", "#d8f3b1")),
]
NAMES = ("common", "uncommon", "rare", "epic", "mythic", "legendary", "orcfeccion")


def render(tier):
    wall, timber, metal, light = PALETTES[tier]
    im = Image.new("RGBA", SIZE, INK)
    d = ImageDraw.Draw(im)
    masonry(d, wall, 58 if tier == 0 else 72, 24 if tier < 2 else 28)
    floor(d, wall, light, tier)
    cornice(d, wall, metal, tier)
    if tier == 0:
        # Plain dressed lintel, chisel-worn oak uprights, wall pegs.
        rect(d, (62, 35, 577, 45), wall[0])
        rect(d, (65, 36, 574, 41), wall[2])
        line(d, [(66, 36), (572, 36)], wall[3])
        for x in (46, 590):
            for y in (196, 212, 228):
                rect(d, (x-3, y, x+3, y+3), timber[1])
                d.point((x-2, y), fill=timber[3])
    elif tier == 1:
        # Timber roof braces, copper straps and edge-growing ivy.
        for side in (-1, 1):
            x = 49 if side < 0 else 591
            rect(d, (x-9, 30, x+9, 284), timber[0], INK)
            rect(d, (x-6, 32, x+5, 282), timber[2])
            line(d, [(x-5, 35), (x-5, 275)], timber[3])
            poly(d, [(x-7, 38), (x+side*64, 38), (x+side*35, 48), (x+2, 91)], timber[1], INK)
            line(d, [(x, 76), (x+side*32, 43), (x+side*58, 43)], timber[3], 2)
            for y in (58, 192, 263):
                rect(d, (x-8, y, x+8, y+7), metal[1], metal[0])
                rivet(d, x-4, y+3, metal)
                rivet(d, x+4, y+3, metal)
            leaf_vine(d, 9 if side < 0 else 631, 25, 17, side)
            leaf_vine(d, 61 if side < 0 else 579, 25, 6, side)
        for x in range(105, 550, 82):
            filigree(d, x, 44, 1, metal)
    elif tier == 2:
        # Blue-slate voussoirs and steel vertical ribbing.
        for side in (-1, 1):
            x = 48 if side < 0 else 592
            rect(d, (x-12, 31, x+12, 284), wall[0])
            for dx in (-8, 0, 8):
                rect(d, (x+dx-1, 35, x+dx+1, 280), metal[2])
                line(d, [(x+dx+2, 35), (x+dx+2, 280)], metal[0])
            for y in (46, 188, 270):
                rect(d, (x-13, y, x+13, y+6), metal[1], metal[0])
                for dx in (-9, 9):
                    rivet(d, x+dx, y+3, metal)
        poly(d, [(61, 48), (103, 25), (537, 25), (579, 48)], wall[2], wall[0])
        line(d, [(65, 45), (105, 28), (535, 28), (575, 45)], metal[2], 2)
        for x in range(125, 530, 40):
            line(d, [(x, 26), (x-6, 46)], wall[0], 2)
        diamond(d, 320, 36, 15, 10, light)
    elif tier == 3:
        # Stepped horseshoe vault with inset celestial carvings.
        for side in (-1, 1):
            x = 42 if side < 0 else 598
            poly(d, [(x-13, 284), (x-13, 65), (x+side*17, 30), (x+side*74, 22),
                     (x+side*74, 31), (x+side*26, 43), (x+8, 74), (x+8, 284)], wall[2], INK)
            line(d, [(x-8, 275), (x-8, 69), (x+side*22, 36), (x+side*72, 27)], metal[2], 2)
            for y in (74, 195, 241):
                diamond(d, x-1, y, 5, 9, light)
            for y in (210, 257):
                line(d, [(x-5, y), (x+3, y-4), (x+3, y+5), (x+7, y+7)], metal[2])
        d.ellipse((287, 20, 353, 49), outline=metal[2])
        d.ellipse((294, 22, 346, 47), outline=light[1])
        diamond(d, 320, 35, 11, 11, light)
        for x in (234, 270, 370, 406):
            diamond(d, x, 35, 3, 4, metal)
    elif tier == 4:
        # Basalt piers are deliberately faceted, not rectangular gold pillars.
        for side in (-1, 1):
            x = 43 if side < 0 else 597
            poly(d, [(x-18, 284), (x-15, 83), (x-8, 50), (x+3, 29),
                     (x+17, 70), (x+13, 284)], wall[0], INK)
            poly(d, [(x-9, 280), (x-6, 87), (x+2, 48), (x+6, 96), (x+4, 280)], wall[3])
            line(d, [(x+8, 79), (x+6, 263)], metal[1], 3)
            line(d, [(x+8, 92), (x+8, 121), (x+3, 126), (x+3, 166)], light[1])
            tusk(d, x+side*6, 90, 66, -side)
            for y in (184, 241):
                poly(d, [(x-13, y), (x+13, y), (x+9, y+8), (x-10, y+8)], metal[1], INK)
                line(d, [(x-10, y+1), (x+10, y+1)], metal[2])
        poly(d, [(76, 44), (108, 27), (272, 27), (290, 20), (350, 20), (368, 27), (532, 27), (564, 44)], metal[0], INK)
        line(d, [(100, 40), (276, 36), (290, 29), (350, 29), (364, 36), (540, 40)], metal[2], 2)
        for x in (300, 320, 340):
            diamond(d, x, 36, 5, 7, light)
    elif tier == 5:
        # Treasury columns and bright but small golden scrollwork.
        for side in (-1, 1):
            x = 44 if side < 0 else 596
            rect(d, (x-13, 36, x+13, 280), timber[0], INK)
            rect(d, (x-9, 38, x+8, 278), timber[2])
            for dx in (-9, -3, 5, 9):
                line(d, [(x+dx, 44), (x+dx, 273)], GOLD[2])
            for y in (38, 73, 260, 279):
                rect(d, (x-17, y, x+17, y+5), GOLD[1], INK)
                line(d, [(x-15, y+1), (x+15, y+1)], GOLD[3])
            for y in (104, 215, 251):
                filigree(d, x, y, -1, GOLD)
                filigree(d, x, y, 1, GOLD)
            diamond(d, x, 237, 7, 9, GOLD)
        for x in range(103, 570, 47):
            filigree(d, x, 44, 1, GOLD)
            filigree(d, x, 44, -1, GOLD)
        poly(d, [(282, 30), (298, 20), (342, 20), (358, 30), (343, 46), (297, 46)], GOLD[1], GOLD[3])
        diamond(d, 320, 32, 11, 10, GOLD)
        for x in (260, 380):
            diamond(d, x, 37, 5, 7, GOLD)
    else:
        # A temple-scale jade entablature and two immense upward tusk columns.
        poly(d, [(5, 27), (87, 27), (111, 37), (258, 37), (280, 15),
                 (360, 15), (382, 37), (529, 37), (553, 27), (634, 27),
                 (634, 45), (547, 45), (527, 48), (113, 48), (93, 45), (5, 45)], JADE[1], GOLD[1])
        line(d, [(13, 30), (83, 30), (108, 41), (256, 41)], JADE[3], 2)
        line(d, [(627, 30), (557, 30), (532, 41), (384, 41)], JADE[3], 2)
        for side in (-1, 1):
            x = 40 if side < 0 else 600
            rect(d, (x-16, 99, x+16, 280), JADE[0], INK)
            rect(d, (x-12, 99, x+10, 277), JADE[1])
            line(d, [(x-9, 116), (x-9, 269)], JADE[3], 2)
            line(d, [(x+7, 116), (x+7, 269)], GOLD[2])
            tusk(d, x, 261, 207, -side)
            for y in (267, 279):
                rect(d, (x-21, y, x+21, y+7), JADE[1], GOLD[1])
                line(d, [(x-19, y+1), (x+19, y+1)], GOLD[3])
            for y in (113, 213):
                diamond(d, x, y, 5, 8, JADE)
            filigree(d, x, 282, side, GOLD)
        for x in (132, 195, 445, 508):
            filigree(d, x, 42, 1, GOLD)
            filigree(d, x, 42, -1, GOLD)
    rack(d, timber, metal, tier)
    # Crest/capstone sits in front of the rack lintel, never in an item bay.
    if tier == 6:
        orc_crest(d, 320, 34)
    style = ("lantern", "lantern", "crystal", "orb", "brazier", "lantern", "orb")[tier]
    lamp_y = 139 if tier != 4 else 145
    for x in (42, 598):
        lantern(d, x, lamp_y, metal, light, style)
    if tier in (2, 5):
        for x in (42, 598):
            lantern(d, x, 225, metal, light, style)
    if tier == 6:
        # Low emerald offering flames are architecture, below the shelf bank.
        for x in (102, 538):
            lantern(d, x, 306, GOLD, light, "brazier")
    return im


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    rooms = []
    for tier, name in enumerate(NAMES):
        image = render(tier)
        image.save(OUT / f"{name}_room.png")
        rooms.append(image)
        print(f"{name}_room.png: 640x360 native integer geometry")
    if args.contact_sheet:
        # Exact native artwork, not filtered thumbnails. Labels live only here.
        sheet = Image.new("RGB", (1280, 4*384), "#101713")
        d = ImageDraw.Draw(sheet)
        for tier, image in enumerate(rooms):
            x, y = (tier % 2)*640, (tier//2)*384
            d.text((x+8, y+6), NAMES[tier].upper(), fill="#d8d8bb")
            sheet.paste(image, (x, y+24))
        args.contact_sheet.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.contact_sheet)
        print(f"Contact sheet: {args.contact_sheet}")


if __name__ == "__main__":
    main()
