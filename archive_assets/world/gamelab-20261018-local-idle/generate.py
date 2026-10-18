"""Author local-only endpoint idle candidates with Python 3 and Pillow.

Run: python3 /path/to/endpoints-local-idle-20261018/generate.py
The first run snapshots the approved sibling PNGs; subsequent runs use the
preserved local sources. No network, generation service, Godot, or runtime edits.
"""

from collections import deque
from hashlib import sha256
from math import atan2, cos, hypot, pi, sin, tau
from pathlib import Path
import json

from PIL import Image, ImageDraw, __version__ as PILLOW_VERSION

HERE = Path(__file__).resolve().parent
SOURCE_DIR = HERE.parent / "endpoints-gamelab-20261018"
SIZE = 128
FRAME_COUNT = 16
FRAME_MS = 200
NAMES = ("enemy_portal", "health_crystal")


def pixels(image):
    return list(image.get_flattened_data())


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def largest_component(points):
    remaining = set(points)
    parts = []
    while remaining:
        first = min(remaining, key=lambda point: (point[1], point[0]))
        remaining.remove(first)
        queue = deque([first])
        part = {first}
        while queue:
            x, y = queue.popleft()
            for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if point in remaining:
                    remaining.remove(point)
                    part.add(point)
                    queue.append(point)
        parts.append(part)
    return max(parts, key=len)


def material_mask(source, name):
    """Use the new 128px materials, not the old asset's coordinate polygons.

    The largest connected blue component excludes both blue socket inlays.
    The largest connected red component excludes every carved stone rune.
    Nearly white crystal highlights stay fixed rather than broadening this mask.
    """
    points = set()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = source.getpixel((x, y))
            if name == "health_crystal":
                allowed = a and b > r * 1.3 and b > g * 1.1 and b > 70
            else:
                allowed = a and r > g * 2 and r > b * 1.8 and r >= 8
            if allowed:
                points.add((x, y))
    return largest_component(points)


def luminance(color):
    return sum(c * w for c, w in zip(color[:3], (0.2126, 0.7152, 0.0722)))


def nearest_color(target, palette):
    return min(palette, key=lambda color: sum((a - b) ** 2 for a, b in zip(color[:3], target)))


def edge_distances(mask):
    """Integer distance to the material boundary, including concave edges."""
    distance = {}
    queue = deque()
    for x, y in mask:
        if any(p not in mask for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
            distance[x, y] = 1
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if p in mask and p not in distance:
                distance[p] = distance[x, y] + 1
                queue.append(p)
    return distance


def portal_frames(source, mask):
    """Advect only the recessed energy; retain the entire arch/runes/base.

    A full periodic turn is combined with a time-varying, radius-dependent
    angular shear and radial ripple. This is not a rigid rotation of the ring
    or of the whole sprite. The perimeter blends back to the original pixels.
    Sampling and final palette mapping never interpolate alpha or introduce RGB.
    """
    palette = sorted({source.getpixel(p) for p in mask})
    distance = edge_distances(mask)
    frames = []
    for index in range(FRAME_COUNT):
        phase = tau * index / FRAME_COUNT
        frame = source.copy()
        for x, y in sorted(mask):
            u, v = (x - 62.5) / 20.0, (y - 57.0) / 33.0
            radius, angle = hypot(u, v), atan2(v, u)
            turn = phase + 0.28 * sin(2 * angle - phase + 4.5 * radius)
            turn += 0.13 * sin(phase + 7 * radius)
            warped_radius = radius * (1 + 0.055 * sin(phase + 2 * angle - 5 * radius))
            sx = round(62.5 + cos(angle + turn) * warped_radius * 20.0)
            sy = round(57.0 + sin(angle + turn) * warped_radius * 33.0)
            original = source.getpixel((x, y))
            if (sx, sy) not in mask:
                continue
            sampled = source.getpixel((sx, sy))
            # Three stationary-edge pixels protect the recessed rim. The center
            # is strongly advected, rather than merely pulsing its brightness.
            mix = min(0.90, max(0.0, (distance[x, y] - 1) / 5.0))
            target = [a * (1 - mix) + b * mix for a, b in zip(original[:3], sampled[:3])]
            frame.putpixel((x, y), nearest_color(target, palette))
        frames.append(frame)
    return frames


def crystal_frames(source, mask):
    """A narrow diagonal traveling highlight, with zero positional movement."""
    palette = sorted({source.getpixel(p) for p in mask})
    highlight = {}
    for color in palette:
        candidates = [c for c in palette if 4 < luminance(c) - luminance(color) < 31]
        target = [min(255, c + gain) for c, gain in zip(color[:3], (8, 23, 11))]
        highlight[color] = nearest_color(target, candidates) if candidates else color
    frames = []
    for index in range(FRAME_COUNT):
        frame = source.copy()
        travel = -4 + index / FRAME_COUNT * 94
        for x, y in sorted(mask):
            # Circular distance makes the last-to-first transition ordinary.
            position = y - 0.35 * (x - 64)
            delta = (position - travel + 47) % 94 - 47
            if abs(delta) >= 10:
                continue
            strength = 0.5 + 0.5 * cos(pi * delta / 10)
            original = source.getpixel((x, y))
            lit = highlight[original]
            target = [a + strength * (b - a) for a, b in zip(original[:3], lit[:3])]
            frame.putpixel((x, y), nearest_color(target, palette))
        frames.append(frame)
    return frames


def save_gif(frames, path):
    """One exact global palette; no quantization flicker or GIF dithering."""
    colors = sorted({p[:3] for frame in frames for p in pixels(frame) if p[3]})
    if len(colors) > 255:
        raise ValueError("Exact GIF palette exceeds 255 opaque colors")
    lookup = {color: i + 1 for i, color in enumerate(colors)}
    palette = [0, 0, 0] + [channel for color in colors for channel in color]
    palette += [0] * (768 - len(palette))
    indexed = []
    for frame in frames:
        image = Image.new("P", frame.size)
        image.putpalette(palette)
        image.putdata([lookup[p[:3]] if p[3] else 0 for p in pixels(frame)])
        indexed.append(image)
    indexed[0].save(path, save_all=True, append_images=indexed[1:], duration=FRAME_MS,
                    loop=0, transparency=0, disposal=2, optimize=False)


def export_record(name, source, mask, frames):
    # These are authoring invariants, not Godot tests or gameplay verification.
    source_pixels = pixels(source)
    source_palette = {p for p in source_pixels if p[3]}
    for frame in frames:
        data = pixels(frame)
        assert frame.size == (SIZE, SIZE)
        assert frame.getchannel("A").tobytes() == source.getchannel("A").tobytes()
        assert {p for p in data if p[3]} <= source_palette
        assert all(p == q for i, (p, q) in enumerate(zip(data, source_pixels))
                   if (i % SIZE, i // SIZE) not in mask)
    sheet = Image.new("RGBA", (SIZE * FRAME_COUNT, SIZE))
    for index, frame in enumerate(frames):
        sheet.paste(frame, (index * SIZE, 0))
    sheet_path = HERE / f"{name}_idle.png"
    gif_path = HERE / f"{name}_idle.gif"
    sheet.save(sheet_path)
    save_gif(frames, gif_path)
    mask_image = Image.new("1", (SIZE, SIZE))
    for point in mask:
        mask_image.putpixel(point, 1)
    mask_image.save(HERE / f"{name}_effect_mask.png")
    changes = [sum(a != b for a, b in zip(pixels(frame), pixels(frames[(i + 1) % FRAME_COUNT])))
               for i, frame in enumerate(frames)]
    return {
        "name": name,
        "approved_still_original_path": str(SOURCE_DIR / f"{name}.png"),
        "approved_still_original_sha256": digest(HERE / f"{name}-approved.png"),
        "preserved_original_copy": f"{name}-approved.png",
        "cleaned_source": f"{name}.png",
        "cleaned_source_sha256": digest(HERE / f"{name}.png"),
        "opaque_source_palette_colors": len(source_palette),
        "alpha_bounds": list(source.getbbox()),
        "effect_mask": f"{name}_effect_mask.png",
        "effect_mask_pixels": len(mask),
        "sheet": sheet_path.name,
        "sheet_sha256": digest(sheet_path),
        "preview": gif_path.name,
        "preview_sha256": digest(gif_path),
        "unique_frames": len({frame.tobytes() for frame in frames}),
        "adjacent_changed_pixels_including_loop_seam": changes,
        "preservation": "Every pixel outside the saved effect mask and the complete alpha channel remain identical to the cleaned approved still. All opaque source pixels are unmodified by cleanup.",
    }


def paired_preview(sources, animations):
    frames = []
    columns = [
        ("PORTAL / APPROVED STILL", "enemy_portal", False),
        ("PORTAL / LOCAL IDLE", "enemy_portal", True),
        ("CRYSTAL / APPROVED STILL", "health_crystal", False),
        ("CRYSTAL / LOCAL IDLE", "health_crystal", True),
    ]
    for index in range(FRAME_COUNT):
        image = Image.new("RGBA", (1104, 336), (25, 32, 28, 255))
        draw = ImageDraw.Draw(image)
        for column, (title, name, animated) in enumerate(columns):
            x = 16 + column * 272
            draw.text((x, 14), title, fill=(226, 227, 213, 255))
            draw.rectangle((x, 40, x + 255, 295), fill=(50, 64, 53, 255))
            sprite = animations[name][index] if animated else sources[name]
            image.alpha_composite(sprite.resize((256, 256), Image.Resampling.NEAREST), (x, 40))
        draw.text((16, 312), "CANDIDATES ONLY / 128PX / 16 FRAMES / 5 FPS / FIXED MASONRY / NO PAID GENERATION", fill=(182, 195, 176, 255))
        # Pillow's default small font may antialias; snap labels to three fixed
        # preview-only colors so the GIF remains exact and under 256 colors.
        preview_colors = {(25, 32, 28, 255), (50, 64, 53, 255),
                          (226, 227, 213, 255), (182, 195, 176, 255)}
        sprite_colors = {p for source in sources.values() for p in pixels(source) if p[3]}
        allowed = preview_colors | sprite_colors
        image.putdata([p if p in allowed else nearest_color(p[:3], sorted(preview_colors)) for p in pixels(image)])
        frames.append(image)
    save_gif(frames, HERE / "idle_comparison.gif")
    frames[0].save(HERE / "idle_comparison.png")


def main():
    sources = {}
    provenance_path = HERE / "source-generation.json"
    if not provenance_path.exists():
        provenance_path.write_bytes((SOURCE_DIR / "generation.json").read_bytes())
    for name in NAMES:
        original = HERE / f"{name}-approved.png"
        if not original.exists():
            original.write_bytes((SOURCE_DIR / f"{name}.png").read_bytes())
        raw = Image.open(original).convert("RGBA")
        assert raw.size == (SIZE, SIZE)
        assert set(raw.getchannel("A").get_flattened_data()) <= {0, 255}
        # Source exports retain hidden glow RGB under zero alpha. Clear those
        # invisible pixels only; never recolor/remove an opaque silhouette pixel.
        clean = Image.new("RGBA", raw.size)
        clean.putdata([p if p[3] else (0, 0, 0, 0) for p in pixels(raw)])
        clean.save(HERE / f"{name}.png")
        sources[name] = clean
    animations = {}
    records = []
    for name in NAMES:
        mask = material_mask(sources[name], name)
        frames = (portal_frames if name == "enemy_portal" else crystal_frames)(sources[name], mask)
        animations[name] = frames
        records.append(export_record(name, sources[name], mask, frames))
    paired_preview(sources, animations)
    manifest = {
        "status": "LOCAL ANIMATION CANDIDATES; approved input stills, animation review pending; NOT installed at runtime",
        "authoring": "Deterministic local Python + Pillow pixel edits; no network, credentials, model inference, generation service, GPU, or credits used.",
        "pillow_version": PILLOW_VERSION,
        "script": "generate.py",
        "script_sha256": digest(HERE / "generate.py"),
        "source_provenance_snapshot": "source-generation.json",
        "source_provenance_sha256": digest(provenance_path),
        "source_approval_note": "Creator-approved stills supplied for this task; the original provider manifest predates that approval and is preserved verbatim.",
        "frame_size": [SIZE, SIZE],
        "frame_count": FRAME_COUNT,
        "frame_duration_ms": FRAME_MS,
        "frames_per_second": 1000 / FRAME_MS,
        "loop_duration_ms": FRAME_COUNT * FRAME_MS,
        "sheet_size": [SIZE * FRAME_COUNT, SIZE],
        "sheet_layout": "Single horizontal row, left-to-right chronological 128x128 cells; no padding.",
        "alpha_policy": "0/255 only; exact source alpha every frame; transparent RGB cleared to zero; no halo, blur, antialiasing, dilation, or shape movement.",
        "palette_policy": "Opaque pixels in sheets/individual GIFs belong to that approved still's exact RGB palette; no dithering or new sprite colors. Comparison background/text colors are preview-only.",
        "filtering": "No sprite resampling except exact nearest-neighbor 2x enlargement in comparison previews; intended runtime filtering remains nearest if later approved.",
        "motion": {
            "health_crystal": "One restrained traveling diagonal facet shimmer; no bob, scaling, silhouette change, socket/inlay motion, or pedestal edits. Nearly white highlights remain fixed.",
            "enemy_portal": "Interior-only full-turn polar advection with periodic angular shear and radial ripple; source-palette remapping; stationary boundary taper. Stone ring, carved red runes, foundation, and silhouette never rotate or move.",
        },
        "limitations": [
            "Manual 16-frame/5fps pixel animation, not model-generated material or volumetric animation; nearest sampling and limited source colors produce visible pixel steps, especially at 2x preview scale.",
            "Portal perimeter taper is intentionally restrained to protect masonry; the interior does not emit new external glow, sparks, or changing carved runes.",
            "Crystal effect is deliberately subtle and can read weakly when reduced on the battlefield; isolated socket inlays and pale fixed facet highlights do not animate.",
            "No Godot import, tests, build, game launch, runtime integration, or gameplay/scale review performed. Animation approval is still required.",
        ],
        "paired_preview": "idle_comparison.gif",
        "paired_preview_sha256": digest(HERE / "idle_comparison.gif"),
        "assets": records,
        "optional_existing_video": str(HERE.parent / "endpoint-idles-orc-gamelab-20261018/enemy_portal-idle.mp4"),
        "optional_existing_video_action": "Untouched; remains an alternative, not an input to these candidates.",
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"output": str(HERE), "assets": records, "paired_preview": "idle_comparison.gif"}, indent=2))


if __name__ == "__main__":
    main()
