"""Rebuild the approved endpoint loops from the preserved static source PNGs.

Run with Python 3 and Pillow. Outputs stay inside this Godot-ignored archive.
No model, external artwork, runtime dependency, or source-image overwrite.
"""

from collections import deque
from hashlib import sha256
from math import atan2, cos, hypot, pi, sin, tau
from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FRAME_COUNT = 16
FRAME_MS = 200
SIZE = 96
PORTAL_SOURCE = HERE / "enemy_portal-source.png"
CRYSTAL_SOURCE = HERE / "health_crystal-source.png"
PORTAL = Image.open(PORTAL_SOURCE).convert("RGBA")
CRYSTAL = Image.open(CRYSTAL_SOURCE).convert("RGBA")
OPENING = Image.new("1", (SIZE, SIZE))
ImageDraw.Draw(OPENING).polygon(
    [(46, 21), (54, 21), (60, 25), (65, 32), (68, 42), (67, 51),
     (63, 60), (55, 67), (45, 70), (38, 66), (32, 58), (29, 49),
     (30, 39), (34, 31), (40, 25)], fill=1
)


def split_body(image):
    """Separate existing disconnected sparks; retain the largest solid component."""
    pixels = image.load()
    unseen = {(x, y) for y in range(SIZE) for x in range(SIZE) if pixels[x, y][3]}
    parts = []
    while unseen:
        first = min(unseen, key=lambda p: (p[1], p[0]))
        unseen.remove(first)
        queue = deque([first])
        part = []
        while queue:
            x, y = queue.popleft()
            part.append((x, y))
            for point in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
                if point in unseen:
                    unseen.remove(point)
                    queue.append(point)
        parts.append(part)
    parts.sort(key=len, reverse=True)
    body = Image.new("RGBA", image.size)
    for point in parts[0]:
        body.putpixel(point, image.getpixel(point))
    return body, parts[1:]


PORTAL_BODY, PORTAL_SPARKS = split_body(PORTAL)
CRYSTAL_BODY, CRYSTAL_SPARKS = split_body(CRYSTAL)


def inside_opening(x, y):
    r, g, _, a = PORTAL.getpixel((x, y))
    return a and OPENING.getpixel((x, y)) and r > 25 and r > g * 1.32


def crystal_surface(x, y):
    r, g, b, a = CRYSTAL.getpixel((x, y))
    return a and y < 65 and b > 140 and g > 75 and b > r * 1.12


def portal_frame(index):
    index %= FRAME_COUNT
    phase = tau * index / FRAME_COUNT
    image = PORTAL_BODY.copy()
    for y in range(21, 71):
        for x in range(29, 69):
            if not inside_opening(x, y):
                continue
            u, v = (x - 48 + 0.16 * (y - 45)) / 18.6, (y - 45) / 24.8
            radius, angle = hypot(u, v), atan2(v, u)
            # A travelling one/two-pixel twist, not rotation of the entire sprite.
            turn = 0.105 * sin(phase - radius * 4) * max(0, min(1, (1.08 - radius) * 2))
            sample_y = round(45 + radius * sin(angle + turn) * 24.8)
            sample_x = round(48 + radius * cos(angle + turn) * 18.6 - 0.16 * (sample_y - 45))
            if 0 <= sample_x < SIZE and 0 <= sample_y < SIZE and inside_opening(sample_x, sample_y):
                image.putpixel((x, y), PORTAL.getpixel((sample_x, sample_y)))
            # A restrained moving hot edge inside the red lip, using its own palette.
            r, g, b, a = image.getpixel((x, y))
            sweep = (angle - phase + pi) % tau - pi
            if radius > 0.72 and abs(sweep) < 0.33 and r > 160 and g < 115:
                image.putpixel((x, y), (255, 118, 80, a) if r > 225 else (239, 62, 55, a))
    # Two small curved wisps circulate behind the existing flame tongues.
    for offset, strength in [(0, 1.0), (pi, 0.8)]:
        for step in range(30):
            t = step / 29
            angle = phase + offset - 1.3 + t * 1.3
            radius = (0.25 + t * 0.34) * strength
            y = round(45 + sin(angle) * radius * 24.8)
            x = round(48 + cos(angle) * radius * 18.6 - 0.16 * (y - 45))
            if inside_opening(x, y) and PORTAL.getpixel((x, y))[0] < 80:
                color = (74, 16, 31, 255) if t < 0.55 else (124, 22, 41, 255)
                image.putpixel((x, y), color)
    for number, part in enumerate(PORTAL_SPARKS):
        age = (index + number * 3) % FRAME_COUNT
        if age in (0, 1, 15):
            continue
        dx, dy = round(sin(tau * age / FRAME_COUNT + number)), 1 - age // 5
        color = (239, 62, 55, 255) if 5 <= age <= 10 else (164, 38, 53, 255)
        for x, y in part:
            point = (x + dx, y + dy)
            if not PORTAL_BODY.getpixel(point)[3]:
                image.putpixel(point, color)
    return image


BLUE_PALETTE = sorted({CRYSTAL.getpixel((x, y))[:3] for y in range(SIZE)
                       for x in range(SIZE) if crystal_surface(x, y)})


def luminance(color):
    return sum(c * w for c, w in zip(color, (0.2126, 0.7152, 0.0722)))


def next_highlight(color):
    """A single nearby palette step preserves the original facet contrast."""
    candidates = [c for c in BLUE_PALETTE if 4 < luminance(c) - luminance(color) < 38]
    target = [min(255, c * m + b) for c, m, b in zip(color, (1.18, 1.12, 1.025), (2, 5, 0))]
    return min(candidates, key=lambda c: sum((a - b) ** 2 for a, b in zip(c, target))) if candidates else color


HIGHLIGHTS = {color: next_highlight(color) for color in BLUE_PALETTE}


def crystal_frame(index):
    index %= FRAME_COUNT
    image = CRYSTAL_BODY.copy()
    travel = -14 + index / FRAME_COUNT * 112
    for y in range(65):
        for x in range(18, 78):
            if not crystal_surface(x, y):
                continue
            color = CRYSTAL.getpixel((x, y))
            if abs(y - 0.45 * (x - 48) - travel) < 3:
                image.putpixel((x, y), (*HIGHLIGHTS[color[:3]], 255))
            elif color[:3] == (84, 215, 245) and cos(tau * index / FRAME_COUNT) > 0.4:
                image.putpixel((x, y), (103, 217, 245, 255))
    for number, part in enumerate(CRYSTAL_SPARKS):
        age = (index + number * 5) % FRAME_COUNT
        if age in (0, 1, 15):
            continue
        dy = round(sin(tau * age / FRAME_COUNT + number))
        for x, y in part:
            point = (x, y + dy)
            if CRYSTAL_BODY.getpixel(point)[3]:
                continue
            color = CRYSTAL.getpixel((x, y))
            if age in (2, 3, 13, 14):
                color = (60, 156, 217, 255)
            elif age in (7, 8, 9):
                color = (180, 242, 255, 255)
            image.putpixel(point, color)
    return image


def save_transparent_gif(frames, path, source):
    colors = sorted({p[:3] for p in source.get_flattened_data() if p[3]})
    lookup = {color: index + 1 for index, color in enumerate(colors)}
    palette = [0, 0, 0] + [channel for color in colors for channel in color]
    palette += [0] * (768 - len(palette))
    indexed = []
    for frame in frames:
        image = Image.new("P", frame.size)
        image.putpalette(palette)
        image.putdata([lookup[p[:3]] if p[3] else 0 for p in frame.get_flattened_data()])
        indexed.append(image)
    indexed[0].save(path, save_all=True, append_images=indexed[1:], duration=FRAME_MS,
                    loop=0, transparency=0, disposal=2, optimize=False)


def validate(frames, source, body, allowed):
    palette = {p for p in source.get_flattened_data() if p[3]}
    assert len({frame.tobytes() for frame in frames}) == FRAME_COUNT
    for frame in frames:
        assert frame.size == (SIZE, SIZE)
        assert set(frame.getchannel("A").get_flattened_data()) == {0, 255}
        assert {p for p in frame.get_flattened_data() if p[3]} <= palette
        assert frame.getbbox()[3] == source.getbbox()[3]
        for y in range(SIZE):
            for x in range(SIZE):
                if body.getpixel((x, y))[3] and not allowed(x, y):
                    assert frame.getpixel((x, y)) == source.getpixel((x, y)), (x, y)
    changed = [sum(a != b for a, b in zip(frame.get_flattened_data(), frames[(i + 1) % FRAME_COUNT].get_flattened_data()))
               for i, frame in enumerate(frames)]
    assert changed[-1] <= max(changed[:-1]), "Loop seam is larger than every internal transition"
    return changed


def main():
    portal_frames = [portal_frame(i) for i in range(FRAME_COUNT)]
    crystal_frames = [crystal_frame(i) for i in range(FRAME_COUNT)]
    assert portal_frame(FRAME_COUNT).tobytes() == portal_frames[0].tobytes()
    assert crystal_frame(FRAME_COUNT).tobytes() == crystal_frames[0].tobytes()
    manifest = {
        "status": "approved; enabled by PathBoard in matches and the workshop",
        "authoring": "Deterministic edits of the original pixel clusters; Python 3 + Pillow; no external service or model.",
        "frame_size": [SIZE, SIZE], "frames": FRAME_COUNT, "frame_duration_ms": FRAME_MS,
        "loop_duration_ms": FRAME_COUNT * FRAME_MS, "sheet_layout": "one horizontal row, left to right",
        "alpha": "0/255 only; no smoothing, blur, rescaling, or new colors in sprite exports",
        "playback": "5 fps, looping; cosmetic local real time, independent of match speed and authority",
        "assets": [],
    }
    for name, frames, source, source_path, body, allowed in [
        ("enemy_portal_idle", portal_frames, PORTAL, PORTAL_SOURCE, PORTAL_BODY, inside_opening),
        ("health_crystal_idle", crystal_frames, CRYSTAL, CRYSTAL_SOURCE, CRYSTAL_BODY, crystal_surface),
    ]:
        changed = validate(frames, source, body, allowed)
        sheet = Image.new("RGBA", (SIZE * FRAME_COUNT, SIZE))
        for index, frame in enumerate(frames):
            sheet.paste(frame, (SIZE * index, 0))
        sheet_path, gif_path = HERE / f"{name}.png", HERE / f"{name}.gif"
        sheet.save(sheet_path)
        save_transparent_gif(frames, gif_path, source)
        manifest["assets"].append({
            "source": str(source_path.relative_to(ROOT)),
            "source_sha256": sha256(source_path.read_bytes()).hexdigest(),
            "sheet": sheet_path.name, "sheet_sha256": sha256(sheet_path.read_bytes()).hexdigest(),
            "runtime_sheet": f"assets/world/{name}.png",
            "preview": gif_path.name, "preview_sha256": sha256(gif_path.read_bytes()).hexdigest(),
            "fixed_framing_bounds": list(source.getbbox()), "board_anchor": [0.5, 0.97],
            "board_height": 1.05, "adjacent_changed_pixels_including_seam": changed,
            "preserved": "All attached stone, pedestal, outline, rune, and non-magical body pixels are identical to source.",
        })
    # One shared palette avoids unrelated GIF quantization flicker between frames.
    font = ImageFont.truetype(str(ROOT / "assets/fonts/silkscreen/Silkscreen-Regular.ttf"), 14)
    previews = []
    for index in range(FRAME_COUNT):
        image = Image.new("RGB", (848, 288), "#263429")
        draw = ImageDraw.Draw(image)
        for x, title, sprite in [
            (16, "PORTAL / ORIGINAL", PORTAL), (224, "PORTAL / IDLE", portal_frames[index]),
            (432, "CRYSTAL / ORIGINAL", CRYSTAL), (640, "CRYSTAL / IDLE", crystal_frames[index]),
        ]:
            draw.text((x, 16), title, font=font, fill="#cbd1bc")
            draw.rectangle((x, 48, x + 191, 239), fill="#344336")
            draw.ellipse((x + 34, 217, x + 168, 237), fill="#283429")
            zoom = sprite.resize((192, 192), Image.Resampling.NEAREST)
            image.paste(zoom, (x, 48), zoom)
        draw.text((16, 258), "16 PIXEL FRAMES / 5 FPS / ORIGINAL STONEWORK / APPROVED IDLE LOOPS", font=font, fill="#a5b09a")
        previews.append(image)
    palette = Image.new("RGB", (848, 288 * FRAME_COUNT))
    for index, image in enumerate(previews):
        palette.paste(image, (0, index * 288))
    palette = palette.quantize(colors=256, dither=Image.Dither.NONE)
    previews = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in previews]
    previews[0].save(HERE / "idle_comparison.gif", save_all=True, append_images=previews[1:],
                     duration=FRAME_MS, loop=0, disposal=2, optimize=False)
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PASS: both 16-frame loops; hard alpha; source-only palettes; fixed stonework and silhouettes; bounded loop seams.")
    print("Approved archive regenerated; runtime sheets and original source PNGs are not overwritten.")


if __name__ == "__main__":
    main()
