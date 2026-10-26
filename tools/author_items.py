#!/usr/bin/env python3
"""Original Gorcs Itemiery icons. Native 32x32, integer geometry, hard alpha.

No source images, external artwork, models, resampling or antialiasing.
Pillow is an offline authoring dependency, never a runtime dependency.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "items"
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
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, render in {"orc_tusk": tusk, "torn_boot": boot, "command_banner": banner,
                         "samurai_sword": sword, "concucktion": potion,
                         "dabloons": coins, "orcish_lunch_tin": lunch_tin,
                         "ominous_bells_of_doom": doom_bells}.items():
        image = render()
        assert set(image.getchannel("A").tobytes()) <= {0, 255}
        image.save(OUT / f"{name}.png")
        print(f"{name}: 32x32 RGBA, hard alpha")


if __name__ == "__main__":
    main()
