#!/usr/bin/env python3
"""Assemble approved Ballista stills; offline Pillow tooling, never game code."""
from pathlib import Path
import hashlib
import json
import math
import zipfile
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent
ORDER = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
CANVAS = (192, 192)
OFFSET = (32, 32)
SWIVEL = (96, 84)
PLANE = (96, 63)
GROUND = (96, 157)
BACKGROUND = (48, 65, 51, 255)
# Measured native stock-axis landmarks. Cardinal views need different projected
# x/y scales: this is perspective normalization, never in-plane rotation.
WORLD_LENGTH = math.hypot(61, 61)
LANDMARKS = {
    "N": {"rear": (64, 83), "tip": (64, 16), "pivot": (64, 58), "scale": (78 / 99, 55 / 67)},
    "NE": {"rear": (29, 77), "tip": (103, 31), "pivot": (65, 56), "scale": (61 / 74, 38 / 46)},
    "E": {"rear": (16, 60), "tip": (116, 59), "pivot": (65, 59), "scale": (WORLD_LENGTH / 100, 48 / 73)},
    "SE": {"rear": (41, 7), "tip": (102, 45), "pivot": (64, 31), "scale": (1, 1)},
    "S": {"rear": (66, 25), "tip": (66, 93), "pivot": (66, 62), "scale": (78 / 94, 55 / 68)},
    "SW": {"rear": (98, 33), "tip": (23, 75), "pivot": (62, 57), "scale": (61 / 75, 38 / 42)},
    "W": {"rear": (106, 59), "tip": (15, 53), "pivot": (59, 56), "scale": (WORLD_LENGTH / 91, 48 / 68)},
    "NW": {"rear": (105, 79), "tip": (26, 22), "pivot": (65, 52), "scale": (61 / 79, 38 / 57)},
}
# Remove only the redundant dangling support in these generated views. The
# unrotating iron post belongs to base.png, so a view cannot move the socket.
SUPPORT_CUTS = {
    "N": (56, 86, 74, 105),
    "NE": (59, 70, 77, 87),
    "SW": (55, 78, 73, 92),
    "NW": (56, 75, 75, 94),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def palette_map(image, palette):
    mapping = {}
    result = image.copy()
    pixels = result.load()
    for y in range(image.height):
        for x in range(image.width):
            rgba = pixels[x, y]
            if not rgba[3]:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            rgb = rgba[:3]
            if rgb not in mapping:
                mapping[rgb] = min(palette, key=lambda p: sum((a - b) ** 2 for a, b in zip(rgb, p)))
            pixels[x, y] = (*mapping[rgb], 255)
    return result


def fixed_base(master):
    # Keep the facade and foundation. Only the roof previously hidden by the
    # crossbow is repaired. The same base bytes are reused in every direction.
    native = Image.new("RGBA", (128, 128))
    draw = ImageDraw.Draw(native)
    ink = (32, 36, 39, 255)
    roof = (150, 142, 135, 255)
    light = (195, 185, 170, 255)
    dark = (91, 92, 95, 255)
    draw.polygon([(34, 49), (61, 41), (91, 48), (76, 60), (35, 55)], fill=ink)
    draw.polygon([(36, 49), (61, 43), (88, 49), (75, 57), (37, 54)], fill=roof)
    draw.line([(38, 49), (61, 44), (83, 49)], fill=light, width=1)
    draw.line([(45, 51), (67, 46), (81, 51)], fill=dark, width=1)
    native.alpha_composite(master.crop((0, 54, 128, 128)), (0, 54))
    for box in [(29, 46, 44, 54), (76, 48, 92, 54)]:
        native.alpha_composite(master.crop(box), box[:2])
    # A single circular lower socket and vertical mounting post, not generated
    # separately for each direction. The weapon joint is twenty pixels above it.
    draw.ellipse((56, 47, 73, 54), fill=ink)
    draw.ellipse((58, 48, 71, 52), fill=dark)
    draw.line([(59, 49), (69, 49)], fill=roof)
    draw.rectangle((61, 35, 67, 49), fill=ink)
    draw.rectangle((62, 36, 66, 48), fill=dark)
    draw.line([(62, 37), (62, 47)], fill=roof)
    draw.ellipse((60, 33, 68, 37), fill=ink)
    draw.line([(62, 34), (66, 34)], fill=roof)
    output = Image.new("RGBA", CANVAS)
    output.alpha_composite(native, OFFSET)
    return output


def source_se(master):
    mask = Image.new("L", master.size)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((0, 0, 127, 42), fill=255)
    draw.polygon([(39, 42), (52, 42), (58, 47), (69, 47), (73, 43), (91, 42),
                  (101, 43), (104, 47), (98, 47), (90, 44), (75, 45), (68, 49),
                  (58, 49), (51, 45), (39, 45)], fill=255)
    result = master.copy()
    alpha = result.getchannel("A")
    result.putalpha(Image.frombytes("L", master.size, bytes(a & b for a, b in zip(alpha.tobytes(), mask.tobytes()))))
    return result


def remove_loose_pixels(image):
    pixels = image.load()
    remaining = {(x, y) for y in range(image.height) for x in range(image.width) if pixels[x, y][3]}
    removed = 0
    while remaining:
        start = remaining.pop()
        group, pending = [start], [start]
        while pending:
            x, y = pending.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    point = (x + dx, y + dy)
                    if point in remaining:
                        remaining.remove(point)
                        group.append(point)
                        pending.append(point)
        if len(group) <= 16:
            for point in group:
                pixels[point] = (0, 0, 0, 0)
            removed += len(group)
    return removed


def draw_review(base, frames):
    review = Image.new("RGBA", (960, 850), BACKGROUND)
    draw = ImageDraw.Draw(review)
    draw.text((20, 12), "BALLISTA / ALIGNED EIGHT-DIRECTION ASSEMBLY", fill="#e1dfc3", font_size=18)
    draw.text((20, 39), "One fixed base, socket and foot anchor; no in-plane rotations; artwork preview, not gameplay", fill="#b2baa6", font_size=13)
    # Constant world scale, not an independent fit per direction.
    for i, direction in enumerate(ORDER):
        col, row = i % 4, i // 4
        cx, top = 120 + col * 240, 75 + row * 380
        draw.text((col * 240 + 18, top), direction, fill="#e1dfc3", font_size=17)
        image = frames[direction].resize((240, 240), Image.Resampling.NEAREST)
        review.alpha_composite(image, (cx - 120, top + 22))
        small = frames[direction].resize((138, 138), Image.Resampling.NEAREST)
        review.alpha_composite(small, (cx - 69, top + 240))
    review.convert("RGB").save(OUT / "review.png")
    gif_frames = []
    for direction in ORDER:
        image = Image.new("RGBA", (576, 620), BACKGROUND)
        image.alpha_composite(frames[direction].resize((576, 576), Image.Resampling.NEAREST), (0, 30))
        label = ImageDraw.Draw(image)
        label.text((20, 8), "BALLISTA / " + direction, fill="#e1dfc3", font_size=18)
        gif_frames.append(image.convert("RGB"))
    # One common GIF palette prevents background/base colors pumping by frame.
    palette = gif_frames[0].quantize(colors=128, dither=Image.Dither.NONE)
    quantized = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in gif_frames]
    quantized[0].save(OUT / "rotation.gif", save_all=True, append_images=quantized[1:],
                      duration=400, loop=0, disposal=2, optimize=False)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = Image.open(SOURCE / "SE_approved_master.png").convert("RGBA")
    palette = sorted({p[:3] for p in master.getdata() if p[3]})
    base = palette_map(fixed_base(master), palette)
    base.save(OUT / "base.png")
    manifest = {
        "status": "Assembled approved designs; derived roof repair and alignment pending review; not imported",
        "canvas": list(CANVAS), "order": ORDER, "swivel_pixels": list(SWIVEL),
        "weapon_plane_pixels": list(PLANE), "foot_pixels": list(GROUND),
        "source_master": "../SE_approved_master.png", "source_sha256": digest(SOURCE / "SE_approved_master.png"),
        "base": {"file": "base.png", "sha256": digest(OUT / "base.png"),
                 "repair": "Facade/foundation below native y54 retained; occluded roof reconstructed; shared fixed iron socket/post."},
        "pixel_policy": "Nearest-neighbor perspective normalization, binary alpha, nearest master-palette mapping without dithering; never rotate a finished PNG in its image plane.",
        "additional_generation_credits": 0, "views": {},
    }
    frames = {}
    for direction in ORDER:
        source_path = SOURCE / ("SE_approved_master.png" if direction == "SE" else f"{direction}_weapon.png")
        source = source_se(master) if direction == "SE" else Image.open(source_path).convert("RGBA")
        if direction in SUPPORT_CUTS:
            ImageDraw.Draw(source).rectangle(SUPPORT_CUTS[direction], fill=(0, 0, 0, 0))
        source = palette_map(source, palette)
        landmark = LANDMARKS[direction]
        sx, sy = landmark["scale"]
        size = (round(source.width * sx), round(source.height * sy))
        normalized = source.resize(size, Image.Resampling.NEAREST)
        effective = (size[0] / source.width, size[1] / source.height)
        pivot = landmark["pivot"]
        translation = (round(PLANE[0] - pivot[0] * effective[0]), round(PLANE[1] - pivot[1] * effective[1]))
        weapon = Image.new("RGBA", CANVAS)
        weapon.alpha_composite(normalized, translation)
        removed_pixels = remove_loose_pixels(weapon)
        bounds = weapon.getbbox()
        assert bounds and 0 < bounds[0] < bounds[2] < CANVAS[0] and 0 < bounds[1] < bounds[3] < CANVAS[1], direction
        weapon.save(OUT / f"weapon_{direction}.png")
        frame = Image.alpha_composite(base, weapon)
        frame.save(OUT / f"ballista_{direction}.png")
        frames[direction] = frame
        transformed = {key: [round(translation[j] + landmark[key][j] * effective[j], 3) for j in [0, 1]]
                       for key in ["rear", "tip", "pivot"]}
        manifest["views"][direction] = {
            "source_file": str(source_path.relative_to(SOURCE)), "source_sha256": digest(source_path),
            "source_landmarks": landmark, "support_cut": SUPPORT_CUTS.get(direction),
            "detached_pixels_removed": removed_pixels,
            "effective_scale": list(effective), "translation": list(translation), "landmarks": transformed,
            "weapon_file": f"weapon_{direction}.png", "frame_file": f"ballista_{direction}.png",
            "weapon_bounds": list(bounds), "frame_bounds": list(frame.getbbox()),
            "weapon_sha256": digest(OUT / f"weapon_{direction}.png"),
            "frame_sha256": digest(OUT / f"ballista_{direction}.png"),
        }
    sheet = Image.new("RGBA", (CANVAS[0] * 8, CANVAS[1]))
    for i, direction in enumerate(ORDER):
        sheet.alpha_composite(frames[direction], (i * CANVAS[0], 0))
    sheet.save(OUT / "ballista_8_directions.png")
    draw_review(base, frames)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    with zipfile.ZipFile(OUT / "ballista-assembled.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(OUT.iterdir()):
            if path.name != "ballista-assembled.zip" and path.is_file():
                archive.write(path, arcname=path.name)
    print("Prepared", len(frames), "frames, fixed base, weapon layers, sheet, review and rotation GIF")


if __name__ == "__main__":
    main()
