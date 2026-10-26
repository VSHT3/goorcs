#!/usr/bin/env python3
"""Draw the Orcapult tower art reproducibly with Pillow.

Outputs native hard-alpha RGBA PNGs into assets/towers/:

- orcapult.png              collection/shop icon: base plus the arm cocked back
- orcapult_base.png         board layer without the arm
- orcapult_arm.png          throwing arm, rotated by the renderer about ARM_PIVOT
- orcapult_<look>_base.png / orcapult_<look>_arm.png for the Siege Arm,
  Warlord's Trebuchet, Long Toss and Over the Wall looks, plus the Double
  Scoop arm (orcapult_scoop_arm.png), which reuses the plain base.

Every base shares a natively drawn 192x128 canvas with the arm pivot at
BASE_PIVOT. Arms use a 32x88 canvas with their pivot at ARM_PIVOT. The
unflipped art throws to the left; boards mirror it toward the opponent.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "towers"
CANVAS = (192, 128)
BASE_PIVOT = (104, 92)
ARM_CANVAS = (32, 88)
ARM_PIVOT = (16, 70)
COCKED_DEGREES = 62.0
LENGTHS = {"plain": 44, "scoop": 44, "siege": 46, "trebuchet": 48, "long": 54, "wall": 60}

OUTLINE = (14, 12, 12, 255)
WOOD = [(56, 41, 28), (82, 54, 31), (110, 71, 40), (146, 93, 50), (186, 128, 72), (214, 164, 104)]
DARK_WOOD = [(40, 30, 22), (60, 43, 28), (82, 56, 34), (104, 70, 42), (130, 90, 54), (150, 108, 66)]
IRON = [(38, 42, 47), (55, 60, 66), (78, 82, 88), (108, 108, 110), (150, 146, 142)]
STONE = [(30, 30, 36), (92, 92, 96), (122, 116, 110), (146, 138, 128), (168, 158, 144), (190, 180, 164)]
ROPE = [(120, 88, 52), (166, 122, 77), (213, 191, 137), (239, 223, 173)]
GREEN = [(38, 70, 40), (62, 104, 52), (98, 146, 70), (140, 186, 98)]
RED = [(78, 26, 26), (122, 40, 36), (170, 62, 50), (206, 98, 74)]
BRASS = [(96, 70, 30), (150, 112, 44), (204, 162, 70), (240, 214, 130)]
BONE = [(150, 140, 118), (198, 188, 160), (232, 224, 200)]


def rgba(color):
    return color if len(color) == 4 else (*color, 255)


def layer():
    return Image.new("RGBA", CANVAS, (0, 0, 0, 0))


def outlined(base, part, color=OUTLINE):
    """Composite a part with its own one-pixel dark outline (4-neighbour)."""
    alpha = part.getchannel("A").point(lambda a: 255 if a else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(3))
    # Diagonal-free outline: grow with a cross by OR-ing four shifted masks.
    cross = Image.new("L", alpha.size, 0)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        cross = ImageChops.lighter(cross, ImageChops.offset(alpha, dx, dy))
    ring = ImageChops.subtract(ImageChops.lighter(cross, alpha), alpha)
    del grown
    edge = Image.new("RGBA", alpha.size, rgba(color))
    edge.putalpha(ring)
    base.alpha_composite(edge)
    base.alpha_composite(part)


def beam(image, p0, p1, width, palette, grain_seed=0, light=(-0.6, -0.8)):
    """Rasterise a shaded wooden/iron beam between two points."""
    x0, y0 = p0
    x1, y1 = p1
    length = math.hypot(x1 - x0, y1 - y0)
    if length == 0:
        return
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    nx, ny = -uy, ux
    if nx * light[0] + ny * light[1] < 0:
        nx, ny = -nx, -ny
    half = width / 2.0
    rng = random.Random(grain_seed)
    streaks = {k: rng.random() for k in range(-8, 64)}
    pixels = image.load()
    pad = int(width) + 2
    for y in range(int(min(y0, y1)) - pad, int(max(y0, y1)) + pad + 1):
        for x in range(int(min(x0, x1)) - pad, int(max(x0, x1)) + pad + 1):
            if not (0 <= x < image.width and 0 <= y < image.height):
                continue
            px, py = x + 0.5 - x0, y + 0.5 - y0
            s = px * ux + py * uy
            d = px * nx + py * ny
            if s < -0.01 or s > length + 0.01 or abs(d) > half:
                continue
            # d > 0 faces the light.
            t = d / half
            if t > 0.55:
                shade = 4
            elif t > -0.2:
                shade = 3
            elif t > -0.7:
                shade = 2
            else:
                shade = 1
            lane = int(round(d))
            if streaks[lane % 64] > 0.55 and int(s / 3 + lane * 7) % 5 == 0 and shade > 1:
                shade -= 1
            pixels[x, y] = rgba(palette[min(shade, len(palette) - 1)])


def band(image, center, along, width, length, palette, rivet=True):
    """An iron band across a beam: a short perpendicular beam."""
    cx, cy = center
    ux, uy = along
    nx, ny = -uy, ux
    p0 = (cx - nx * length / 2, cy - ny * length / 2)
    p1 = (cx + nx * length / 2, cy + ny * length / 2)
    beam(image, p0, p1, width, palette)
    if rivet:
        image.putpixel((int(cx), int(cy)), rgba(palette[-1]))


def stone_platform(base, look):
    part = layer()
    draw = ImageDraw.Draw(part)
    left, right, top, front, bottom, depth = 24, 166, 98, 106, 120, 5
    rng = random.Random(7)
    # Right side face (shadowed).
    draw.polygon([(right, front), (right + depth, top), (right + depth, bottom - 7), (right, bottom)], fill=rgba(STONE[1]))
    for y in range(top + 3, bottom - 2, 5):
        draw.line([(right + 1, y + 3), (right + depth - 1, y - 1)], fill=rgba(STONE[0]))
    # Top face.
    draw.polygon([(left, front), (right, front), (right + depth, top), (left + depth, top)], fill=rgba(STONE[4]))
    for x in range(left + 9, right, 13):
        draw.line([(x, front - 1), (x + depth - 1, top + 1)], fill=rgba(STONE[2]))
    draw.line([(left + depth, top), (right + depth, top)], fill=rgba(STONE[5]))
    draw.line([(left + 3, top + 4), (right + 2, top + 4)], fill=rgba(STONE[3]))
    # Front face: two staggered courses of blocks.
    draw.rectangle([left, front, right - 1, bottom - 1], fill=rgba(STONE[2]))
    course_height = (bottom - front) // 2
    for row in range(2):
        y0 = front + row * course_height
        x = left - (6 if row else 0)
        while x < right:
            x1 = min(right - 1, x + 14)
            xa = max(left, x)
            tone = STONE[3] if rng.random() < 0.55 else STONE[2]
            draw.rectangle([xa, y0, x1 - 1, y0 + course_height - 2], fill=rgba(tone))
            draw.line([(xa, y0), (x1 - 2, y0)], fill=rgba(STONE[4]))
            draw.line([(xa, y0 + course_height - 2), (x1 - 1, y0 + course_height - 2)], fill=rgba(STONE[1]))
            draw.line([(x1, y0), (x1, y0 + course_height - 1)], fill=rgba(STONE[0]))
            if rng.random() < 0.35:
                cx = rng.randint(xa + 2, max(xa + 2, x1 - 3))
                part.putpixel((cx, y0 + 2), rgba(STONE[1]))
            x += 15
        draw.line([(left, y0 + course_height - 1), (right - 1, y0 + course_height - 1)], fill=rgba(STONE[0]))
    if look in ("trebuchet",):
        # Iron corner caps on the finale's plinth.
        for x in (left, right - 5):
            draw.rectangle([x, front, x + 4, bottom - 1], fill=rgba(IRON[2]))
            draw.line([(x, front), (x + 4, front)], fill=rgba(IRON[4]))
            part.putpixel((x + 2, front + 3), rgba(IRON[4]))
            part.putpixel((x + 2, bottom - 4), rgba(IRON[4]))
    outlined(base, part)


def boulders(base, spots):
    for cx, cy, r in spots:
        part = layer()
        draw = ImageDraw.Draw(part)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(STONE[2]))
        draw.ellipse([cx - r + 1, cy - r + 1, cx + r - 2, cy + r - 2], fill=rgba(STONE[3]))
        draw.point([(cx - r // 2, cy - r // 2)], fill=rgba(STONE[5]))
        draw.arc([cx - r, cy - r, cx + r, cy + r], 20, 160, fill=rgba(STONE[1]))
        outlined(base, part)


def flag(base, pole_x, pole_bottom, pole_top, cloth, length=16, height=9, emblem=None, seed=3):
    part = layer()
    beam(part, (pole_x, pole_bottom), (pole_x, pole_top), 2, DARK_WOOD, seed)
    draw = ImageDraw.Draw(part)
    draw.rectangle([pole_x - 1, pole_top - 2, pole_x + 1, pole_top], fill=rgba(BRASS[2]))
    outlined(base, part)
    part = layer()
    draw = ImageDraw.Draw(part)
    top = pole_top + 2
    pts = []
    for i in range(length + 1):
        wave = int(round(math.sin(i / length * math.pi * 1.4 + seed) * 1.5))
        pts.append((pole_x + 1 + i, top + wave))
    lower = [(x, y + height - (abs(i - length) < 4) * (4 - abs(i - length))) for i, (x, y) in enumerate(pts)]
    draw.polygon(pts + lower[::-1], fill=rgba(cloth[2]))
    for i, (x, y) in enumerate(pts):
        part.putpixel((x, y), rgba(cloth[3]))
        if i % 5 == 2:
            draw.line([(x, y + 2), (x, y + height - 3)], fill=rgba(cloth[1]))
    for (x, y) in lower:
        if 0 <= y < CANVAS[1]:
            part.putpixel((x, y), rgba(cloth[1]))
    if emblem == "skull":
        ex, ey = pole_x + length // 2 + 1, top + height // 2
        draw.ellipse([ex - 3, ey - 3, ex + 3, ey + 2], fill=rgba(BONE[2]))
        draw.point([(ex - 1, ey - 1), (ex + 1, ey - 1)], fill=rgba(OUTLINE))
        draw.line([(ex - 1, ey + 2), (ex + 1, ey + 2)], fill=rgba(BONE[1]))
    outlined(base, part)


def frame(base, look):
    heavy = look in ("siege", "trebuchet")
    # A long chassis is built from native-width timbers, not stretched art.
    # Rear rail and splayed rear support leave room for the loading deck.
    part = layer()
    beam(part, (66, 96), (99, 52), 5, DARK_WOOD, 11)
    beam(part, (142, 96), (105, 52), 5, DARK_WOOD, 12)
    beam(part, (32, 96), (166, 96), 5, DARK_WOOD, 13)
    outlined(base, part)
    part = layer()
    # Repeating deck planks retain the original square-pixel grain scale.
    for x in range(35, 162, 12):
        beam(part, (x + 4, 96), (x, 103), 7, WOOD, x)
    beam(part, (30, 101), (82, 76), 4, DARK_WOOD, 14)
    beam(part, (160, 101), (120, 77), 4, DARK_WOOD, 15)
    outlined(base, part)
    # Torsion bundle around the axle.
    part = layer()
    draw = ImageDraw.Draw(part)
    px, py = BASE_PIVOT
    w = 8 if heavy else 7
    draw.rounded_rectangle([px - w, py - 7, px + w, py + 7], radius=3, fill=rgba(ROPE[2]))
    for k in range(-w - 6, w + 6, 3):
        draw.line([(px + k, py - 7), (px + k + 5, py + 7)], fill=rgba(ROPE[1]))
    draw.line([(px - w + 2, py - 6), (px + w - 2, py - 6)], fill=rgba(ROPE[3]))
    cap = IRON if heavy else DARK_WOOD
    draw.rectangle([px - w - 3, py - 4, px - w, py + 4], fill=rgba(cap[2]))
    draw.rectangle([px + w, py - 4, px + w + 3, py + 4], fill=rgba(cap[2]))
    draw.point([(px - w - 2, py), (px + w + 2, py)], fill=rgba(cap[-1]))
    outlined(base, part)
    # Front rail with brackets.
    part = layer()
    beam(part, (28, 102), (164, 102), 6, WOOD, 21)
    draw = ImageDraw.Draw(part)
    for x in (32, 60, 96, 132, 160):
        palette = IRON
        draw.rectangle([x - 2, 99, x + 2, 104], fill=rgba(palette[2]))
        draw.point([(x, 100), (x, 103)], fill=rgba(palette[4]))
    if heavy:
        for x in range(38, 157, 6):
            draw.point([(x, 101)], fill=rgba(IRON[3]))
        draw.line([(30, 104), (162, 104)], fill=rgba(IRON[1]))
    outlined(base, part)
    # Front A-frame with the padded stop beam the arm slams into.
    part = layer()
    beam(part, (56, 101), (94, 56), 6, WOOD, 31)
    beam(part, (130, 101), (101, 56), 6, WOOD, 32)
    beam(part, (76, 75), (114, 75), 4, WOOD, 33)
    beam(part, (87, 56), (108, 56), 6, WOOD, 34)
    draw = ImageDraw.Draw(part)
    draw.rounded_rectangle([86, 52, 94, 60], radius=2, fill=rgba(ROPE[2]))
    for k in range(86, 95, 2):
        draw.line([(k, 52), (k + 1, 60)], fill=rgba(ROPE[1]))
    if heavy:
        for x, y in ((94, 56), (102, 56), (66, 89), (122, 89)):
            draw.rectangle([x - 1, y - 2, x + 1, y + 2], fill=rgba(IRON[2]))
            draw.point([(x, y)], fill=rgba(IRON[4]))
    outlined(base, part)


def winch(base):
    part = layer()
    draw = ImageDraw.Draw(part)
    cx, cy, r = 145, 88, 9
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=rgba(BRASS[1]), width=2)
    for k in range(6):
        a = k * math.pi / 3
        draw.line([(cx, cy), (cx + int(round(math.cos(a) * (r - 1))), cy + int(round(math.sin(a) * (r - 1))))], fill=rgba(DARK_WOOD[3]))
    draw.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=rgba(BRASS[2]))
    draw.arc([cx - r, cy - r, cx + r, cy + r], 200, 300, fill=rgba(BRASS[3]))
    outlined(base, part)


def skull(base, cx, cy):
    part = layer()
    draw = ImageDraw.Draw(part)
    draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 3], fill=rgba(BONE[1]))
    draw.ellipse([cx - 3, cy - 4, cx + 3, cy + 1], fill=rgba(BONE[2]))
    draw.point([(cx - 2, cy - 1), (cx + 2, cy - 1)], fill=rgba(OUTLINE))
    draw.point([(cx - 1, cy - 1), (cx + 1, cy - 1)], fill=rgba(OUTLINE))
    draw.line([(cx - 2, cy + 3), (cx + 2, cy + 3)], fill=rgba(BONE[0]))
    draw.point([(cx - 4, cy + 2), (cx + 4, cy + 2)], fill=rgba(BONE[2]))
    outlined(base, part)


def draw_base(look):
    base = layer()
    if look == "trebuchet":
        flag(base, 158, 100, 40, RED, length=18, height=13, emblem="skull", seed=1)
    elif look == "siege":
        flag(base, 158, 98, 58, RED, length=14, height=8, seed=2)
    elif look == "wall":
        flag(base, 158, 100, 42, GREEN, length=18, height=12, seed=4)
        flag(base, 32, 100, 54, GREEN, length=12, height=8, seed=5)
    elif look == "long":
        flag(base, 158, 98, 52, GREEN, length=15, height=8, seed=6)
    else:
        flag(base, 158, 98, 64, GREEN, length=11, height=6, seed=8)
    stone_platform(base, look)
    if look == "trebuchet":
        boulders(base, [(40, 96, 4), (49, 98, 3), (34, 99, 3), (43, 90, 3)])
    else:
        boulders(base, [(39, 97, 3), (47, 99, 2), (33, 100, 2)])
    frame(base, look)
    if look == "wall":
        winch(base)
    if look in ("siege", "trebuchet"):
        skull(base, 96, 102)
    return base


def arm_canvas():
    return Image.new("RGBA", ARM_CANVAS, (0, 0, 0, 0))


def draw_arm(look):
    """Arm points straight up from ARM_PIVOT; its cup opens toward -x."""
    arm = arm_canvas()
    px, py = ARM_PIVOT
    length = LENGTHS[look]
    heavy = look in ("siege", "trebuchet")
    width = 6 if heavy else 5
    tip = py - length
    part = arm_canvas()
    beam(part, (px, py + 4), (px, tip + 8), width, WOOD, 41 + length, light=(-1.0, 0.0))
    for k in range(3 if heavy else 2):
        y = py - 10 - k * (length - 16) // (3 if heavy else 2)
        beam(part, (px - width / 2 - 1, y), (px + width / 2 + 1, y), 2, IRON, 0, light=(0.0, -1.0))
        part.putpixel((px, y), rgba(IRON[4]))
    # Axle hub at the pivot.
    draw = ImageDraw.Draw(part)
    draw.ellipse([px - 3, py - 3, px + 3, py + 3], fill=rgba(IRON[2]))
    draw.point([(px - 1, py - 1)], fill=rgba(IRON[4]))
    if look == "trebuchet":
        # A spiked counterweight hanging below the axle.
        draw.rectangle([px - 7, py + 4, px + 7, py + 12], fill=rgba(IRON[1]))
        draw.line([(px - 7, py + 4), (px + 7, py + 4)], fill=rgba(IRON[3]))
        for x in (px - 5, px, px + 5):
            draw.point([(x, py + 7)], fill=rgba(IRON[4]))
            draw.line([(x, py + 13), (x, py + 14)], fill=rgba(IRON[3]))
    outlined(arm, part)
    # The cup.
    part = arm_canvas()
    draw = ImageDraw.Draw(part)
    cup = IRON if heavy else WOOD
    cy = tip
    # A deep bowl seen from the side, its mouth facing -x.
    draw.ellipse([px - 10, cy - 8, px + 7, cy + 8], fill=rgba(cup[2]))
    draw.chord([px - 10, cy - 8, px + 7, cy + 8], 20, 160, fill=rgba(cup[1]))
    draw.ellipse([px - 13, cy - 6, px - 1, cy + 6], fill=rgba(cup[0]))
    draw.arc([px - 13, cy - 6, px - 1, cy + 6], 300, 60, fill=rgba(cup[1]))
    draw.arc([px - 10, cy - 8, px + 7, cy + 8], 200, 320, fill=rgba(cup[4]))
    # The mouth is a straight rim at the bowl's open side.
    for y in range(cy - 9, cy + 10):
        for x in range(0, px - 9):
            if 0 <= y < ARM_CANVAS[1]:
                part.putpixel((x, y), (0, 0, 0, 0))
    draw.line([(px - 9, cy - 6), (px - 9, cy + 6)], fill=rgba(cup[3]))
    band_color = BRASS if look in ("long", "wall") else IRON
    draw.line([(px + 2, cy - 8), (px + 2, cy + 8)], fill=rgba(band_color[2]))
    if heavy:
        for y in (cy - 9, cy + 9):
            draw.point([(px - 7, y), (px - 3, y), (px + 1, y)], fill=rgba(IRON[3]))
    outlined(arm, part)
    if look == "scoop":
        # Double Scoop: a second bowl riveted behind the first.
        part = arm_canvas()
        draw = ImageDraw.Draw(part)
        cy2 = cy + 12
        draw.ellipse([px - 9, cy2 - 6, px + 5, cy2 + 6], fill=rgba(WOOD[2]))
        draw.ellipse([px - 12, cy2 - 4, px - 1, cy2 + 4], fill=rgba(WOOD[0]))
        draw.arc([px - 9, cy2 - 6, px + 5, cy2 + 6], 200, 320, fill=rgba(WOOD[4]))
        for y in range(cy2 - 7, cy2 + 8):
            for x in range(0, px - 8):
                part.putpixel((x, y), (0, 0, 0, 0))
        draw.line([(px - 8, cy2 - 4), (px - 8, cy2 + 4)], fill=rgba(WOOD[3]))
        draw.line([(px + 2, cy2 - 6), (px + 2, cy2 + 6)], fill=rgba(IRON[2]))
        outlined(arm, part)
    if look == "wall":
        # Streamers tied below the cup flutter as the arm swings.
        part = arm_canvas()
        draw = ImageDraw.Draw(part)
        for k, color in enumerate((GREEN[2], BRASS[2])):
            x = px + 4 + k * 2
            draw.line([(x, cy + 9), (x + 2, cy + 16), (x + 1, cy + 22)], fill=rgba(color))
        arm.alpha_composite(part)
    return arm


def rock_in_cup(arm, look):
    """Icon only: a boulder sitting in the cocked cup."""
    length = LENGTHS[look]
    px, py = ARM_PIVOT
    cy = py - length
    part = arm_canvas()
    draw = ImageDraw.Draw(part)
    draw.ellipse([px - 12, cy - 4, px - 4, cy + 4], fill=rgba(STONE[3]))
    draw.point([(px - 10, cy - 2)], fill=rgba(STONE[5]))
    outlined(arm, part)


def compose_icon(base, arm):
    icon = base.copy()
    placed = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    placed.alpha_composite(arm, (BASE_PIVOT[0] - ARM_PIVOT[0], BASE_PIVOT[1] - ARM_PIVOT[1]))
    # PIL rotates counter-clockwise; the cocked arm leans back (clockwise).
    rotated = placed.rotate(-COCKED_DEGREES, resample=Image.NEAREST, center=BASE_PIVOT)
    icon.alpha_composite(rotated)
    return icon


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    looks = {"plain": "", "scoop": "_scoop", "siege": "_siege", "trebuchet": "_trebuchet", "long": "_long", "wall": "_wall"}
    for look, suffix in looks.items():
        base = draw_base(look)
        arm = draw_arm(look)
        if look != "scoop":
            # Double Scoop keeps the plain base and only swaps the arm.
            base.save(OUT / f"orcapult{suffix}_base.png")
        arm.save(OUT / f"orcapult{suffix}_arm.png")
        if look == "plain":
            loaded = arm.copy()
            rock_in_cup(loaded, look)
            compose_icon(base, loaded).save(OUT / "orcapult.png")
    print("wrote Orcapult art to", OUT)


if __name__ == "__main__":
    main()
