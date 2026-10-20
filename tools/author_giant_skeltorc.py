#!/usr/bin/env python3
"""Derive Giant Skeltorc walk art from read-only skeleton pixels and original bomb.

Run: python3 tools/author_giant_skeltorc.py (Pillow required).
Only giant_skeltorc outputs are written. Existing skeleton art/provenance stays intact.
Death frames reference the original bare skeleton sheet; the dropped bomb is separate.
"""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw
from author_enemy_sprites import Pixels, O, FE, BO, LE

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-giant-skeltorc')
SIZE = 80


def bomb(p, x=57, y=40):
    # Broad iron sphere with flattened visible top and top-left metal planes.
    def pts(values):
        return [(x+dx,y+dy) for dx,dy in values]
    p.p(pts([(-13,-4),(-11,-10),(-5,-14),(4,-14),(11,-10),(15,-3),
             (15,5),(10,12),(2,15),(-7,13),(-13,7)]), FE[0])
    p.p(pts([(-12,-3),(-9,-9),(-4,-12),(3,-12),(9,-8),(7,-1),
             (0,5),(-8,7),(-12,3)]), FE[1], None)
    p.p(pts([(-10,-5),(-7,-9),(-2,-11),(3,-10),(1,-6),(-6,-3)]), FE[2], None)
    p.l(pts([(-8,-8),(-3,-11),(2,-10)]), FE[3], 2)
    p.p(pts([(-11,4),(-3,8),(7,6),(14,0),(14,4),(7,10),(-3,12),(-11,8)]), LE[0])
    p.l(pts([(-11,5),(-3,9),(7,7),(13,2)]), LE[2], 2)
    for dx,dy in ((-7,7),(2,9),(10,5)):
        p.r((x+dx,y+dy,x+dx+1,y+dy+1), BO[2])
    p.p(pts([(-4,-1),(1,-4),(6,0),(2,5),(-3,4)]), BO[2])
    p.p(pts([(-2,0),(0,-1),(1,1),(-1,2)]), O, None)
    p.p(pts([(3,-1),(4,0),(3,2),(2,1)]), O, None)
    p.l(pts([(0,4),(3,3)]), O)
    p.p(pts([(-3,-13),(-3,-17),(4,-18),(7,-14),(4,-11)]), FE[0])
    p.l(pts([(-1,-16),(3,-16),(5,-14)]), FE[2])
    p.l(pts([(1,-17),(0,-21),(4,-25),(9,-25),(11,-28)]), LE[0], 3)
    p.l(pts([(1,-17),(1,-21),(4,-24),(9,-24),(11,-28)]), LE[3])
    p.r((x+10,y-29,x+12,y-28), O)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    source = OUT/'skeleorc.png'
    source_frames = OUT/'skeleorc.tres'
    source_manifest = OUT/'skeleorc.json'
    original = Image.open(source).convert('RGBA')
    frames = []
    for index in range(12):
        frame = Image.new('RGBA', (SIZE,SIZE))
        phase = index*math.tau/12
        bob = round(-abs(math.sin(phase))*1.5)
        bomb(Pixels(frame, 0, bob), x=57, y=42)
        # Skeleton foreground pixels stay exact; no repainting the approved bones.
        frame.alpha_composite(original.crop((index*SIZE,0,(index+1)*SIZE,SIZE)))
        straps = Pixels(frame, 0, bob)
        straps.l([(43,39),(47,45),(49,49)], LE[0], 3)
        straps.l([(43,38),(47,44),(49,48)], LE[2])
        straps.r((45,42,47,44), BO[2])
        box = frame.getbbox()
        if not (0 < box[0] < box[2] < SIZE and 0 < box[1] < box[3] < SIZE):
            raise ValueError(f'Giant artwork needs native margin: {index}, {box}')
        frames.append(frame)
    sheet = Image.new('RGBA', (SIZE*12,SIZE))
    for index,frame in enumerate(frames):
        sheet.alpha_composite(frame,(index*SIZE,0))
    sheet_path = OUT/'giant_skeltorc.png'
    still_path = OUT/'giant_skeltorc_still.png'
    bomb_path = OUT/'giant_skeltorc_bomb.png'
    resource = OUT/'giant_skeltorc.tres'
    sheet.save(sheet_path,optimize=True)
    frames[0].save(still_path,optimize=True)
    ground = Image.new('RGBA',(40,48))
    bomb(Pixels(ground),x=19,y=31)
    ground.save(bomb_path,optimize=True)
    lines = ['[gd_resource type="SpriteFrames" load_steps=27 format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/enemies/animations/giant_skeltorc.png" id="1_walk"]',
             '[ext_resource type="Texture2D" path="res://assets/enemies/animations/skeleorc.png" id="2_bones"]', '']
    for index in range(24):
        atlas = '1_walk' if index < 12 else '2_bones'
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  f'atlas = ExtResource("{atlas}")',f'region = Rect2({index*SIZE}, 0, 80, 80)', '']
    lines += ['[resource]', 'animations = [']
    for row,(name,fps) in enumerate((('walk',17),('death',15))):
        lines += ['{', '"frames": [']
        for index in range(12):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{row*12+index}")', '},' if index < 11 else '}']
        lines += ['],', f'"loop": {str(row == 0).lower()},', f'"name": &"{name}",', f'"speed": {float(fps)}', '},' if row == 0 else '}']
    lines += [']','']
    resource.write_text('\n'.join(lines))
    manifest = {
        'identity': 'Giant Skeltorc: unchanged skeleton foreground with oversized iron sphere backpack, skull warning plate, riveted leather cradle and hooked fuse.',
        'authoring': 'Deterministic Pillow integer geometry for original bomb; existing normal skeleton sheet reused read-only as an explicit derivation.',
        'generator': 'tools/author_giant_skeltorc.py', 'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_giant_skeltorc.py',
        'parents': {str(path.relative_to(ROOT)): digest(path) for path in (source,source_frames,source_manifest)},
        'geometry_helpers': 'tools/author_enemy_sprites.py',
        'geometry_helpers_sha256': digest(ROOT/'tools/author_enemy_sprites.py'),
        'source_origin': 'Existing locally authored skeleton pixels plus original local Pillow bomb geometry; no image service.',
        'source_preservation': 'Normal skeleton sheet, still, SpriteFrames and provenance never written. Only new Giant outputs.',
        'camera': 'Elevated three-quarter facing left, upper-left light, fixed foot anchor.',
        'alpha': 'Binary 0/255; no smoothing, dithering, antialiasing, raster rotation or rescaling in frames.',
        'frame_size': [80,80], 'sheet_size': list(sheet.size), 'base_anchor': [.5,.875],
        'source_faces_left': True, 'recommended_world_height_cells': .95,
        'death': 'Original bare skeleton death frames referenced directly; no attached bomb after real death.',
        'ground_bomb': {'path':str(bomb_path.relative_to(ROOT)),'size':list(ground.size),
                        'anchor':[.475,46/48],'alpha_bounds':list(ground.getbbox()),'sha256':digest(bomb_path)},
        'sheet_sha256':digest(sheet_path),'still_sha256':digest(still_path),'sprite_frames_sha256':digest(resource),
        'walk_alpha_bounds':[list(frame.getbbox()) for frame in frames],
    }
    (OUT/'giant_skeltorc.json').write_text(json.dumps(manifest,indent=2)+'\n')
    contact = Image.new('RGB',(SIZE*12,200),'#26312d')
    draw = ImageDraw.Draw(contact)
    draw.text((4,3),'Giant Skeltorc / original backpack bomb / normal skeleton read-only',fill='#e0dfc6')
    for index,frame in enumerate(frames):
        contact.paste(frame,(index*SIZE,20),frame)
        bones = original.crop(((index+12)*SIZE,0,(index+13)*SIZE,SIZE))
        contact.paste(bones,(index*SIZE,120),bones)
    contact.save(PREVIEW/'giant-skeltorc-contact.png')
    frames[0].save(PREVIEW/'giant-skeltorc-walk.apng',format='PNG',save_all=True,
                   append_images=frames[1:],duration=1000/17,loop=0,disposal=0,blend=0)
    print(f'Exported Giant-only art and provenance; normal art read-only. Previews: {PREVIEW}')


if __name__ == '__main__':
    main()
