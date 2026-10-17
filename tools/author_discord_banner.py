#!/usr/bin/env python3
"""Export the Discord 1024x576 cover from existing Gorcs art (Pillow only).

No gameplay assets are modified. Compose on a 512x288 pixel grid, then enlarge
with nearest-neighbor sampling. The cover is promotional artwork, not a game
screenshot. Run from any directory with Python and Pillow installed.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/ui/discord_cover.png"
SIZE = (512, 288)


def main():
    rng = random.Random(1037)
    image = Image.new("RGBA", SIZE, "#101c1b")
    draw = ImageDraw.Draw(image)

    # Quiet, stepped woodland silhouettes leave the wordmark's sky uncluttered.
    draw.rectangle((0, 164, 511, 287), fill="#23352b")
    draw.polygon([(0, 152), (32, 152), (32, 144), (67, 144), (67, 155),
                  (106, 155), (106, 148), (141, 148), (141, 158),
                  (184, 158), (184, 153), (249, 153), (249, 160),
                  (312, 160), (312, 146), (352, 146), (352, 151),
                  (391, 151), (391, 141), (452, 141), (452, 154),
                  (511, 154), (511, 288), (0, 288)], fill="#1b2c25")
    for side in (0, 1):
        for i in range(7):
            x = i * 15 - 16 if side == 0 else 432 + i * 15
            y = 96 + rng.randrange(0, 30)
            height = rng.randrange(48, 80)
            draw.rectangle((x + 9, y + 16, x + 13, y + height + 30), fill="#182720")
            draw.polygon([(x, y + 32), (x + 4, y + 32), (x + 4, y + 19),
                          (x + 9, y + 19), (x + 9, y), (x + 14, y),
                          (x + 14, y + 19), (x + 20, y + 19),
                          (x + 20, y + 33), (x + 25, y + 33),
                          (x + 25, y + height), (x, y + height)], fill="#15261f")

    # Broad terrain planes, not a checkerboard or UI frame.
    draw.polygon([(0, 216), (67, 203), (149, 215), (244, 177), (327, 182),
                  (391, 172), (512, 197), (512, 288), (0, 288)], fill="#2b402f")
    draw.polygon([(0, 263), (96, 236), (184, 248), (277, 230), (374, 247),
                  (452, 231), (512, 248), (512, 288), (0, 288)], fill="#344a33")
    for _ in range(160):
        x, y = rng.randrange(512), rng.randrange(204, 288)
        color = rng.choice(("#304630", "#3b5034", "#293e2e"))
        draw.rectangle((x, y, x + rng.randrange(2, 8), y + 1), fill=color)

    # One connected, winding lane: the product's maze-building silhouette.
    route = [(395, 200), (346, 230), (280, 230), (244, 207), (207, 207),
             (161, 257), (101, 257)]
    draw.line(route, fill="#25332b", width=27, joint="curve")
    draw.line(route, fill="#696650", width=21, joint="curve")
    draw.line(route, fill="#85806a", width=15, joint="curve")
    for index, (a, b) in enumerate(zip(route, route[1:])):
        steps = max(abs(b[0] - a[0]), abs(b[1] - a[1])) // 9
        for step in range(steps):
            t = (step + 0.5) / steps
            x = round(a[0] + (b[0] - a[0]) * t)
            y = round(a[1] + (b[1] - a[1]) * t)
            draw.line((x - 2, y - 5, x + 3, y + 4), fill="#5d604e", width=1)

    def sprite(path, foot, height):
        art = Image.open(ROOT / path).convert("RGBA")
        art = art.crop(art.getbbox())
        width = round(art.width * height / art.height)
        art = art.resize((width, height), Image.Resampling.NEAREST)
        x, y = round(foot[0] - width / 2), round(foot[1] - height)
        draw.ellipse((foot[0] - width // 3, foot[1] - 4,
                      foot[0] + width // 3, foot[1] + 3), fill="#23342a")
        image.alpha_composite(art, (x, y))

    # Back-to-front composition, keeping the original pixels and silhouettes.
    sprite("assets/world/enemy_portal.png", (395, 207), 65)
    sprite("assets/towers/arrow_tower.png", (100, 235), 104)
    sprite("assets/enemies/necorcmancer.png", (351, 221), 38)
    sprite("assets/enemies/brute.png", (309, 238), 46)
    sprite("assets/enemies/grunt.png", (271, 232), 35)
    sprite("assets/enemies/runner.png", (232, 215), 33)
    sprite("assets/enemies/grunt.png", (198, 233), 35)
    sprite("assets/enemies/orcling.png", (176, 247), 24)
    sprite("assets/world/health_crystal.png", (99, 273), 49)
    sprite("assets/towers/rune_obelisk.png", (431, 277), 111)

    # Reuse the actual title's G + orc O + RCS identity, not a new logo.
    font = ImageFont.truetype(str(ROOT / "assets/fonts/PixelifySans.ttf"), 112)
    small = ImageFont.truetype(str(ROOT / "assets/fonts/PixelifySans.ttf"), 12)
    face = Image.open(ROOT / "assets/ui/app_icon.png").convert("RGBA")
    face = face.crop(face.getbbox()).resize((84, 73), Image.Resampling.NEAREST)
    g_width = round(font.getlength("G"))
    suffix_width = round(font.getlength("RCS"))
    x = (512 - g_width - 84 - suffix_width - 8) // 2

    def text_at(position, text, face_font, color):
        x, top = position
        offset = face_font.getbbox(text)[1]
        draw.text((x + 2, top - offset + 3), text, font=face_font, fill="#081410")
        draw.text((x, top - offset), text, font=face_font, fill=color)

    text_at((x, 48), "G", font, "#e6e0cf")
    image.alpha_composite(face, (x + g_width + 4, 48))
    text_at((x + g_width + 92, 48), "RCS", font, "#e6e0cf")
    tagline = "BUILD. DEFEND. SEND ORCS."
    tagline_width = round(small.getlength(tagline))
    text_at(((512 - tagline_width) // 2, 135), tagline, small, "#a5b88b")

    # Keep the export opaque, lossless and exactly the portal's 16:9 dimensions.
    image = image.convert("RGB").resize((1024, 576), Image.Resampling.NEAREST)
    image.save(OUT, optimize=True)
    print(f"Exported {OUT.relative_to(ROOT)}: {image.width}x{image.height}, {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
