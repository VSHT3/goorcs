"""Derive Crystal Mine sprite variants from assets/towers/gold_mine.png.

Same 128x128 canvas and anchor as the Gold Mine, so the variants render at the
identical pixel density: gold ore in the cart becomes shard crystal, chunky
pixel crystal clusters grow from the rock faces (outlined like the source art,
with a faint cyan glow on nearby stone), and the tunnel glows from within.
Usage (from the repository root): python3 tools/author_crystal_mine.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/towers/gold_mine.png"
OUT = ROOT / "assets/towers"
OUTLINE = (14, 20, 28, 255)
# Dark -> light shard ramp (matches the in-game Shard cyan).
RAMP = [(20, 52, 84, 255), (31, 104, 146, 255), (63, 172, 210, 255), (150, 232, 246, 255), (236, 253, 255, 255)]
GOLD = {(145, 71, 7): 0, (182, 94, 5): 1, (231, 144, 8): 2, (251, 207, 48): 3}
GLOW = (90, 200, 225)


def prism_pixels(x0, base_y, width, height, lean):
    """Tapered crystal prism leaning by `lean` pixels at its tip; {(x, y): ramp}."""
    pixels = {}
    shades = {1: [3], 2: [3, 1], 3: [3, 2, 1], 4: [3, 2, 2, 1]}[width]
    for row in range(height):
        y = base_y - row
        shift = round(lean * row / max(1, height - 1))
        if row == height - 1:
            cols = [width // 2 - (1 if width == 4 else 0)] if width > 1 else [0]
        elif row == height - 2 and width > 2:
            cols = list(range(1, width - 1))
        else:
            cols = list(range(width))
        for col in cols:
            shade = shades[col]
            if row < 2:
                shade = max(0, shade - 1)
            pixels[(x0 + col + shift, y)] = shade
    # Glint near the tip on the light face.
    tip_shift = round(lean * (height - 3) / max(1, height - 1))
    pixels[(x0 + tip_shift + (1 if width > 2 else 0), base_y - height + 3)] = 4
    return pixels


def stamp_cluster(image, prisms):
    """Prisms are drawn back to front, each with its own outline."""
    every = {}
    for prism in prisms:
        every.update(prism_pixels(*prism))
    # Faint cool light on stone around the cluster.
    for (x, y) in every:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                p = (x + dx, y + dy)
                if p in every or not (0 <= p[0] < image.width and 0 <= p[1] < image.height):
                    continue
                r, g, b, a = image.getpixel(p)
                if a and image.getpixel(p) != OUTLINE:
                    t = 0.05
                    image.putpixel(p, (int(r + (GLOW[0] - r) * t), int(g + (GLOW[1] - g) * t), int(b + (GLOW[2] - b) * t), a))
    for prism in prisms:
        filled = prism_pixels(*prism)
        for (x, y) in filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in filled and 0 <= n[0] < image.width and 0 <= n[1] < image.height:
                    image.putpixel(n, OUTLINE)
        for p, shade in filled.items():
            if 0 <= p[0] < image.width and 0 <= p[1] < image.height:
                image.putpixel(p, RAMP[shade])


def recolor_gold(image):
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if a and (r, g, b) in GOLD:
                image.putpixel((x, y), RAMP[GOLD[(r, g, b)] + 1])


def tunnel_glow(image, strength):
    # Darkest tunnel interior pixels pick up a cool light from deeper crystal.
    for y in range(52, 100):
        for x in range(46, 74):
            r, g, b, a = image.getpixel((x, y))
            if a and r + g + b < 120:
                t = strength * (1.0 - (y - 52) / 60.0)
                image.putpixel((x, y), (int(r + (GLOW[0] - r) * t), int(g + (GLOW[1] - g) * t), int(b + (GLOW[2] - b) * t), a))


# Clusters as lists of prisms (x0, base_y, width, height, lean), back to front.
BASE = [
    [(18, 67, 3, 11, 0), (14, 67, 3, 7, -2), (21, 68, 3, 6, 2)],      # left rock face
    [(33, 41, 3, 9, 0), (30, 41, 2, 5, -1)],                          # upper-left rock
]
GEODE = [
    [(91, 39, 3, 12, 0), (87, 39, 3, 7, -2), (94, 40, 3, 7, 2)],      # upper-right rock
    [(106, 71, 3, 9, 1), (103, 71, 2, 5, -1)],                        # right rock face
]
LODE = [
    [(61, 27, 4, 16, 0), (57, 27, 3, 10, -3), (65, 28, 3, 11, 3), (54, 28, 2, 6, -2), (68, 28, 2, 6, 2)],  # summit crown
    [(12, 95, 3, 9, -1), (15, 96, 3, 6, 1)],                          # front-left boulder
    [(112, 93, 3, 8, 1), (109, 93, 2, 5, -1)],                        # front-right boulder
]

base = Image.open(SRC).convert("RGBA")
for name, clusters, glow in [
    ("crystal_mine", BASE, 0.25),
    ("crystal_geode", BASE + GEODE, 0.4),
    ("crystal_mother_lode", BASE + GEODE + LODE, 0.6),
]:
    image = base.copy()
    recolor_gold(image)
    tunnel_glow(image, glow)
    for cluster in clusters:
        stamp_cluster(image, cluster)
    image.save(f"{OUT}/{name}.png")
    print("wrote", name)
