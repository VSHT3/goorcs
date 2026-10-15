"""Export the chosen manual ballista master and its two PixelLab-ready layers.

Pillow is authoring-only. base.png is the approved hand-pixeled foundation;
source-crossbow.png preserves the extracted original weapon and repaired saddle.
No AI service, procedural rotation, or game resource is used by this export.
"""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
STEEL = ['#252225', '#3e3a3e', '#545457', '#666686', '#727690', '#9ea2c7', '#cbceeb', '#e8e7f9']
WOOD = ['#2f1d13', '#503422', '#734911', '#a06d3f', '#c16528', '#d38437', '#f1a45b', '#f9bc80', '#ffe69a']
APPROVED_BASE_SHA256 = '761d8984cde66a1bf0b05ce51cf403a9f527e7bee0bcead10382151b1c8b4225'


def detail_crossbow(source):
    image = source.copy()
    draw = ImageDraw.Draw(image)
    # Forged binding around the stock's top and side face.
    draw.polygon([(58,26),(60,27),(58,31),(56,30)], fill=STEEL[1])
    draw.line([(58,26),(60,27),(58,30)], fill=STEEL[5])
    draw.point((58,27), fill=STEEL[7])
    draw.line([(60,31),(63,33)], fill=WOOD[1])
    draw.line([(63,29),(67,31)], fill=WOOD[8])
    draw.line([(65,32),(69,34)], fill=WOOD[3])
    # Side windlass, hub, axle and wooden winding handle.
    draw.polygon([(58,39),(61,39),(63,41),(62,44),(59,45),(57,43),(57,41)], fill=STEEL[0])
    draw.line([(59,40),(61,40),(62,42),(60,44),(58,43)], fill=STEEL[3])
    draw.line([(58,42),(61,42)], fill=STEEL[5])
    draw.point((60,41), fill=STEEL[6])
    draw.line([(61,43),(64,45)], fill=STEEL[2])
    draw.line([(64,44),(65,45)], fill=WOOD[5])
    for position in [(50,26),(75,39),(63,49)]:
        draw.point(position, fill=STEEL[6])
    return image


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    base_path = ROOT / 'base.png'
    assert sha256(base_path) == APPROVED_BASE_SHA256, 'Approved foundation changed'
    base = Image.open(base_path).convert('RGBA')
    source = Image.open(ROOT / 'source-crossbow.png').convert('RGBA')
    crossbow = detail_crossbow(source)
    assert base.size == source.size == (128, 128)
    assert crossbow.getbbox() == source.getbbox(), 'Detail work enlarged the crossbow'
    master = base.copy()
    master.alpha_composite(crossbow)
    assert ImageChops.difference(master.crop((0,65,128,128)), base.crop((0,65,128,128))).getbbox(alpha_only=False) is None
    for name, image in [('ballista.png', master), ('crossbow.png', crossbow)]:
        assert set(image.getchannel('A').get_flattened_data()) == {0, 255}
        bounds = image.getbbox()
        assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 128 and bounds[3] < 128
        image.save(ROOT / name)
    font_path = ROOT.parents[3] / 'assets/fonts/silkscreen/Silkscreen-Regular.ttf'
    font = ImageFont.truetype(str(font_path), 16)
    preview = Image.new('RGB', (440,464), '#2c3d30')
    draw = ImageDraw.Draw(preview)
    draw.text((24,16), 'MANUAL BALLISTA / STARTING POSE', font=font, fill='#e4e4d2')
    enlarged = master.resize((384,384), Image.Resampling.NEAREST)
    preview.paste(enlarged, (28,44), enlarged)
    draw.text((24,438), '128 X 128 PNG / TRANSPARENT', font=font, fill='#b7c1aa')
    preview.save(ROOT / 'preview.png')
    manifest = {
        'status': 'Single starting image for creator-led PixelLab rotations; not installed in gameplay',
        'canvas': [128,128],
        'source_facing': 'south-east',
        'foot_anchor_pixels': [64,117],
        'swivel_socket_pixels': [64,52],
        'layer_order': ['base.png','crossbow.png'],
        'master': 'ballista.png',
        'rotation_guidance': 'Rotate crossbow.png only; retain the identical base.png and full canvas/anchor.',
        'provenance': {
            'base': 'Hand-pixeled taller buttressed foundation approved by the creator in this session.',
            'crossbow': 'Existing PixelLab source manually separated, saddle repaired, then steel bindings, stock highlights, windlass and rivets edited at native pixel scale.',
            'original_source': 'assets/towers/ballista_tower.png',
            'original_source_sha256': '9ac5e953f4e02e4f18aa20064b392a09f6c5b6938b69248fd6720c68f79ae38a',
            'source_layer_translation': [16,4],
            'new_ai_generations': 0,
        },
        'validation': {'approved_base_unchanged': True, 'crossbow_bounds_unchanged': True,
                       'alpha': [0,255], 'native_scale': True, 'margins_unclipped': True},
        'files': {name: sha256(ROOT/name) for name in ['base.png','source-crossbow.png','crossbow.png','ballista.png','preview.png','prepare.py']},
    }
    (ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('PASS: approved base unchanged; crossbow not enlarged; hard alpha; unclipped layers')
    print(ROOT / 'ballista.png')


if __name__ == '__main__':
    main()
