"""Author pixel-art branch/finale sprite variants by recolouring shipped art.

Same canvases, framing and silhouettes as the source sprites, so variants render
at identical pixel density (like tools/author_crystal_mine.py):
- Rune obelisk: Storm Sigil and Void Monolith branch looks, and finale looks for
  Heart of the Mountain, Eclipse, Wrath of the Storm and Singularity. Runes,
  crown crystal and stone are recoloured by pixel class.
- Ballista: S.U.M.G.G.M. (arcane violet weapon, glowing carved runes and slit)
  and The Biggest Wood III (dark hardwood and bronze, forge-lit slit), for the
  base and all eight directional weapon poses.
Usage (from the repository root): python3 tools/author_finale_variants.py
"""
import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TOWERS = ROOT / "assets/towers"
DIRECTIONS = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]


def hsv(pixel):
    r, g, b = pixel[:3]
    return colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)


def ramp(colors, t):
    """Sample a dark->light colour ramp at t in [0, 1]."""
    t = max(0.0, min(1.0, t))
    position = t * (len(colors) - 1)
    index = min(int(position), len(colors) - 2)
    f = position - index
    a, b = colors[index], colors[index + 1]
    return tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3))


# Brightness window of each source pixel class, stretched onto the full ramp.
VALUE_WINDOWS = {"rune": (0.55, 1.0), "crystal": (0.0, 0.6), "crack": (0.12, 0.30)}


def recolor(image, classify, palettes):
    out = image.copy()
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel[3] == 0:
                continue
            kind = classify(pixel, x, y)
            if kind == "crack" and palettes.get("crack") is None:
                kind = "stone"
            if kind in palettes and palettes[kind] is not None:
                low, high = VALUE_WINDOWS.get(kind, (0.0, 1.0))
                value = (hsv(pixel)[2] - low) / (high - low)
                out.putpixel((x, y), ramp(palettes[kind], value) + (pixel[3],))
    return out


# --- Rune obelisk -----------------------------------------------------------

def rune_class(pixel, x, y):
    h, s, v = hsv(pixel)
    if 100 <= x <= 156 and y <= 84 and s > 0.25 and 0.6 <= h <= 0.85:
        return "crystal"
    if 0.55 <= h <= 0.8 and s > 0.3 and v > 0.55:
        return "rune"
    if s < 0.22:
        # Dark seams inside the obelisk body can glow (Heart of the Mountain).
        if 96 <= x <= 160 and 86 <= y <= 186 and 0.12 < v < 0.30:
            return "crack"
        return "stone"
    return None


RUNE_LOOKS = {
    # name: {class: dark->light ramp, or None to keep the source pixels}
    "rune_storm": {"rune": [(24, 96, 160), (70, 200, 250), (190, 245, 255)], "crystal": [(8, 36, 64), (40, 140, 200), (160, 238, 255)], "stone": None},
    "rune_void": {"rune": [(84, 18, 124), (186, 80, 250), (236, 176, 255)], "crystal": [(4, 0, 10), (40, 6, 70), (160, 80, 240)], "stone": None},
    "rune_mountain_heart": {"rune": [(140, 44, 8), (250, 140, 36), (255, 206, 96)], "crystal": [(70, 16, 2), (214, 96, 18), (255, 206, 104)], "stone": [(30, 22, 18), (104, 86, 72), (184, 164, 142), (224, 206, 180)], "crack": [(140, 40, 6), (240, 120, 30), (255, 190, 80)]},
    "rune_eclipse": {"rune": [(84, 62, 130), (196, 176, 255), (236, 228, 255)], "crystal": [(2, 0, 6), (20, 12, 34), (170, 150, 230)], "stone": [(8, 6, 14), (34, 28, 48), (78, 70, 98), (120, 112, 140)]},
    "rune_storm_wrath": {"rune": [(36, 128, 196), (110, 226, 255), (220, 252, 255)], "crystal": [(16, 64, 104), (80, 200, 250), (220, 252, 255)], "stone": [(14, 20, 30), (58, 72, 92), (122, 140, 162), (180, 196, 214)]},
    "rune_singularity": {"rune": [(120, 20, 156), (224, 86, 255), (255, 184, 255)], "crystal": [(0, 0, 0), (12, 2, 22), (190, 90, 255)], "stone": [(4, 2, 8), (24, 14, 36), (62, 46, 82), (104, 88, 124)]},
}


# --- Ballista ---------------------------------------------------------------

def weapon_class(pixel, x, y):
    h, s, v = hsv(pixel)
    if 0.03 <= h <= 0.16 and 0.08 < s <= 0.30 and v > 0.72:
        return "string"
    if 0.03 <= h <= 0.14 and s > 0.28:
        return "wood"
    if s < 0.18 and v < 0.75:
        return "iron"
    return None


def base_class(pixel, x, y):
    h, s, v = hsv(pixel)
    # The arrow slit on the front face is the darkest interior pixels.
    if 84 <= x <= 92 and 105 <= y <= 120 and v < 0.12:
        return "slit"
    return None


BALLISTA_LOOKS = {
    "ballista_sumggm": {
        "weapon": {"wood": [(14, 10, 18), (38, 28, 46), (74, 58, 92), (124, 104, 150)], "iron": [(26, 26, 34), (128, 130, 150), (226, 228, 242)], "string": [(150, 90, 255), (214, 176, 255), (248, 236, 255)]},
        "slit": [(150, 80, 255), (230, 190, 255)],
        "runes": [(122, 70, 220), (214, 180, 255)],
    },
    "ballista_biggest": {
        "weapon": {"wood": [(30, 14, 8), (92, 44, 22), (150, 82, 40), (196, 128, 74)], "iron": [(46, 28, 12), (150, 104, 44), (232, 190, 110)]},
        "slit": [(255, 120, 30), (255, 214, 120)],
        "runes": None,
    },
}

# Carved rune glyphs (x, y offsets) glowing on the base's stone blocks.
RUNE_GLYPHS = [
    [(1, 0), (1, 1), (1, 2), (1, 3), (0, 1), (2, 2)],
    [(0, 0), (2, 0), (1, 1), (1, 2), (1, 3)],
    [(0, 0), (1, 0), (2, 0), (2, 1), (1, 2), (0, 3), (1, 3), (2, 3)],
    [(0, 0), (0, 1), (0, 2), (0, 3), (1, 1), (2, 0), (2, 2)],
]
# Front face either side of the slit, its lower course, and the side face.
GLYPH_SPOTS = [(78, 110, 0), (96, 108, 1), (79, 124, 2), (97, 122, 3), (114, 106, 2), (116, 120, 0)]


def author_ballista(name, look):
    base = Image.open(TOWERS / "ballista_base.png").convert("RGBA")
    out = base.copy()
    for y in range(base.height):
        for x in range(base.width):
            pixel = base.getpixel((x, y))
            if pixel[3] and base_class(pixel, x, y) == "slit":
                t = (y - 105) / 15.0
                out.putpixel((x, y), ramp(look["slit"], 1.0 - abs(t - 0.5) * 2.0) + (255,))
    if look["runes"]:
        for gx, gy, glyph in GLYPH_SPOTS:
            cells = {(gx + dx, gy + dy) for dx, dy in RUNE_GLYPHS[glyph]}
            # A faint violet light on the stone around each carved glyph.
            for (x, y) in cells:
                for nx in range(x - 1, x + 2):
                    for ny in range(y - 1, y + 2):
                        r, g, b, a = out.getpixel((nx, ny))
                        if a and (nx, ny) not in cells:
                            out.putpixel((nx, ny), (int(r * 0.8 + 120 * 0.2), int(g * 0.8 + 80 * 0.2), int(b * 0.8 + 220 * 0.2), a))
            for index, p in enumerate(sorted(cells)):
                if out.getpixel(p)[3]:
                    out.putpixel(p, ramp(look["runes"], 0.55 + 0.45 * (index % 2)) + (255,))
    out.save(TOWERS / f"{name}_base.png")
    for direction in DIRECTIONS:
        weapon = Image.open(TOWERS / f"ballista_weapon_{direction}.png").convert("RGBA")
        recolor(weapon, weapon_class, look["weapon"]).save(TOWERS / f"{name}_weapon_{direction}.png")
    print("wrote", name)


if __name__ == "__main__":
    obelisk = Image.open(TOWERS / "rune_obelisk.png").convert("RGBA")
    for name, palettes in RUNE_LOOKS.items():
        recolor(obelisk, rune_class, palettes).save(TOWERS / f"{name}.png")
        print("wrote", name)
    for name, look in BALLISTA_LOOKS.items():
        author_ballista(name, look)
