"""Author Lightning tier sprites from assets/towers/lightning.png.

Small cumulative pixel changes on the same canvas and silhouette (so framing is
unchanged), keyed by purchased tiers:
- damage: polished, brighter copper coils
- speed: brighter base window and two lit cyan status lights on the iron plates
- damage_speed: both
- escalating_chain: both, plus a white-hot glass chamber and a brighter spark arc
Usage (from the repository root): python3 tools/author_lightning_tiers.py
"""
import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TOWERS = ROOT / "assets/towers"


def hsv(p):
    return colorsys.rgb_to_hsv(p[0] / 255.0, p[1] / 255.0, p[2] / 255.0)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def edit(image, box, test, change):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p = image.getpixel((x, y))
            if p[3] and test(p):
                image.putpixel((x, y), change(p) + (p[3],))


def is_copper(p):
    h, s, v = hsv(p)
    return 0.02 <= h <= 0.09 and s > 0.35 and v > 0.35


def is_blue(p):
    h, s, v = hsv(p)
    return 0.52 <= h <= 0.62 and s > 0.25


def is_iron(p):
    h, s, v = hsv(p)
    return s < 0.16 and 0.12 < v < 0.42


def polish_coils(image):
    for box in [(30, 31, 62, 42), (30, 54, 62, 64)]:
        edit(image, box, is_copper, lambda p: lerp(p[:3], (255, 200, 150), 0.5))
    # The dark iron bands across the body become polished copper.
    copper = [(70, 34, 18), (150, 84, 48), (214, 140, 86)]
    def to_copper(p):
        v = hsv(p)[2]
        t = (v - 0.12) / 0.30
        return lerp(copper[0], copper[1], t * 2) if t < 0.5 else lerp(copper[1], copper[2], (t - 0.5) * 2)
    edit(image, (11, 76, 85, 90), is_iron, to_copper)


def glow_around(image, source, box, color, amount):
    for y in range(box[1], box[3] + 1):
        for x in range(box[0], box[2] + 1):
            p = source.getpixel((x, y))
            if not p[3] or is_blue(p):
                continue
            if any(is_blue(source.getpixel((x + dx, y + dy))) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                image.putpixel((x, y), lerp(p[:3], color, amount) + (p[3],))


def brighten_window(image):
    source = image.copy()
    edit(image, (39, 90, 50, 120), is_blue, lambda p: lerp(p[:3], (215, 246, 255), 0.6))
    glow_around(image, source, (37, 88, 52, 122), (110, 210, 250), 0.5)


def status_lights(image):
    for cx, cy in [(16, 83), (65, 83)]:
        for dx in range(3):
            for dy in range(3):
                color = (200, 245, 255) if (dx, dy) == (1, 1) else (70, 185, 240)
                image.putpixel((cx + dx, cy + dy), color + (255,))


def arc(image, points):
    for x, y in points:
        if 0 <= x < image.width and 0 <= y < image.height:
            image.putpixel((x, y), (190, 245, 255, 255))


def overcharge(image):
    source = image.copy()
    edit(image, (36, 42, 57, 54), is_blue, lambda p: lerp(p[:3], (245, 252, 255), 0.85))
    edit(image, (34, 13, 60, 21), is_blue, lambda p: lerp(p[:3], (235, 250, 255), 0.7))
    glow_around(image, source, (34, 41, 60, 56), (110, 210, 250), 0.5)
    edit(image, (30, 13, 64, 20), is_copper, lambda p: lerp(p[:3], (255, 236, 200), 0.6))
    # Small arcs crackling off both prong tips.
    arc(image, [(35, 21), (34, 22), (35, 23), (34, 24), (33, 25), (34, 26), (33, 27)])
    arc(image, [(58, 21), (59, 22), (58, 23), (59, 24), (60, 25), (59, 26), (60, 27)])


TIERS = {
    "lightning_damage": [polish_coils],
    "lightning_speed": [brighten_window, status_lights],
    "lightning_damage_speed": [polish_coils, brighten_window, status_lights],
    "lightning_escalating": [polish_coils, brighten_window, status_lights, overcharge],
}

if __name__ == "__main__":
    base = Image.open(TOWERS / "lightning.png").convert("RGBA")
    for name, steps in TIERS.items():
        image = base.copy()
        for step in steps:
            step(image)
        assert image.getbbox() == base.getbbox()
        image.save(TOWERS / f"{name}.png")
        print("wrote", name)
