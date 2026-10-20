#!/usr/bin/env python3
"""Author only KamikaOrc assets with deterministic native-pixel Pillow geometry.

Run: python3 tools/author_kamikaorc.py (Pillow required).
No image service, source cutouts, raster rotation, antialiasing or roster rewrites.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image, ImageDraw
from author_enemy_sprites import O, SK, FE, LE, BO, Pixels, segment
from author_variety_enemies import death_tableau

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-kamikaorc')
SIZE = 80
POWDER = ('#3d2627', '#783c32', '#b56340', '#e2a465')
ROPE = ('#54422e', '#977846', '#d2b875', '#f1d99b')


def pixels(image, x=0, y=0, angle=0, pivot=(40, 44)):
    return Pixels(image, SIZE+x, SIZE+y, angle=angle, pivot=pivot)


def finish(image):
    box = image.getbbox()
    if box is None or not (SIZE < box[0] < box[2] < SIZE*2
                           and SIZE < box[1] < box[3] < SIZE*2):
        raise ValueError(f'Kamika geometry needs native margins: {box}')
    return image.crop((SIZE, SIZE, SIZE*2, SIZE*2))


def boot(p, x, y):
    p.p([(x-4,y-4),(x+2,y-4),(x+4,y),(x+1,y+1),(x-7,y+1),(x-8,y-1)], LE[0])
    p.l([(x-5,y-2),(x+1,y-2)], LE[2], 2)
    p.l([(x-2,y-4),(x+2,y-3)], ROPE[2])


def arm(p, shoulder, elbow, grip):
    segment(p, shoulder, elbow, 3, 2.5, SK)
    segment(p, elbow, grip, 2.5, 2, SK)
    p.p([(grip[0]-3,grip[1]-2),(grip[0]+2,grip[1]-2),
         (grip[0]+3,grip[1]+1),(grip[0]-2,grip[1]+3)], SK[1])
    p.l([(grip[0]-2,grip[1]-1),(grip[0]+1,grip[1]-1)], SK[3])


def powder_pack(p, alive=True, ember=0):
    # Oversized red wooden powder keg: visible elliptical lid, iron hoops,
    # black powder diamond and a thick hooked fuse, not a generic crate.
    p.p([(46,28),(57,25),(66,30),(65,53),(59,58),(46,54),(43,34)], POWDER[0])
    p.p([(47,31),(56,29),(61,33),(60,54),(48,51)], POWDER[1], None)
    p.p([(60,33),(65,30),(64,51),(60,54)], POWDER[0], None)
    p.p([(45,29),(53,25),(61,26),(66,30),(58,34),(49,33)], POWDER[2])
    p.l([(48,29),(54,27),(61,28)], POWDER[3])
    p.l([(51,34),(51,51)], POWDER[2])
    p.l([(57,35),(56,53)], POWDER[2])
    for y in (35, 47):
        p.p([(45,y),(58,y+3),(65,y-1),(65,y+2),(58,y+6),(45,y+3)], FE[0])
        p.l([(46,y+1),(57,y+4)], FE[2])
        p.r((48,y+1,49,y+2), FE[3])
    p.p([(53,38),(58,42),(54,47),(49,42)], ROPE[2])
    p.p([(53,40),(56,42),(53,45),(51,42)], O, None)
    p.l([(55,27),(57,22),(62,20),(64,16)], ROPE[0], 3)
    p.l([(55,26),(58,22),(62,21),(64,17)], ROPE[2])
    if alive:
        p.p([(63,17),(62,13-ember),(65,15),(67,12+ember),(68,17),(65,19)], POWDER[2])
        p.r((64,15,65,17), '#ffe3a1')
    else:
        p.r((63,16,65,17), O)


def torso(p):
    p.p([(30,36),(44,34),(50,42),(47,55),(38,58),(29,52),(27,42)], SK[1])
    p.p([(30,38),(39,36),(43,39),(38,47),(30,46)], SK[2], None)
    p.p([(29,48),(39,50),(48,47),(48,56),(37,59),(29,55)], LE[0])
    p.l([(30,51),(43,54),(48,52)], LE[2], 2)
    # Rope chest harness crosses the body and wraps the keg.
    p.l([(31,36),(43,52)], ROPE[0], 4)
    p.l([(30,36),(42,52)], ROPE[2], 2)
    p.l([(45,35),(33,52)], ROPE[0], 4)
    p.l([(44,35),(32,52)], ROPE[1], 2)
    p.r((36,44,40,48), FE[0])
    p.r((37,44,39,46), FE[3])


def head(p, alive=True):
    # Slanted aviator-like goggles and red tied hood distinguish this runner.
    p.p([(28,24),(19,21),(22,28),(29,30)], SK[1])
    p.l([(22,24),(26,27)], SK[3])
    p.p([(31,18),(42,18),(48,23),(47,32),(42,38),(31,37),(25,32),(25,25)], SK[1])
    p.p([(28,23),(33,20),(40,21),(36,25),(27,27)], SK[2], None)
    p.p([(25,28),(32,26),(37,29),(34,33),(26,33),(23,31)], SK[2])
    p.p([(29,34),(38,34),(44,31),(42,37),(33,39)], SK[0], None)
    p.l([(27,33),(33,34),(41,32)], O)
    p.p([(29,35),(27,30),(29,30),(32,36)], BO[2])
    p.p([(38,35),(41,29),(43,29),(41,35)], BO[2])
    p.p([(28,22),(28,17),(35,14),(44,16),(48,22),(39,23)], POWDER[1])
    p.l([(30,18),(36,16),(42,18)], POWDER[3])
    p.p([(45,20),(51,18),(55,22),(49,23),(53,26),(47,25)], POWDER[2])
    p.l([(25,26),(44,25),(47,23)], LE[0], 3)
    for x,y in ((28,25),(39,24)):
        p.p([(x-2,y-1),(x+4,y-1),(x+5,y+3),(x-2,y+4)], FE[0])
        p.r((x,y,x+2,y+2), '#e6c478' if alive else '#60574b')
        if alive:
            p.r((x,y,x+1,y), BO[3])


def pose(frame):
    phase = frame*math.tau/12
    bob = (0,0,-1,-1,0,1,0,0,-1,-1,0,1)[frame]
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    p = pixels(image)
    body = pixels(image, 0, bob)
    for side in (1,0):
        q = phase + side*math.pi
        hip = (44 if side else 34, 54+bob)
        foot = (hip[0]+math.cos(q)*5-2, 68-max(0,math.sin(q))*4-(1 if side else 0))
        knee = (hip[0]+math.cos(q)*2-2, 60+bob)
        segment(p, hip, knee, 3, 2.5, LE)
        segment(p, knee, (foot[0],foot[1]-2), 2.5, 2, SK)
        boot(p, *foot)
    powder_pack(body, ember=frame%2)
    swing = math.cos(phase)*3
    arm(p, (47,38+bob), (53-swing,45+bob), (53-swing,51+bob))
    torso(body)
    head(body)
    arm(p, (29,39+bob), (24+swing,47+bob), (27+swing,52+bob))
    return finish(image)


def death(frame):
    if frame == 0:
        return pose(0)
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    p = pixels(image)
    dx,dy,angle,nk,nf,fk,ff,ne,ng,fe,fg = death_tableau(frame)
    body = pixels(image, dx, dy, angle)
    hips = [tuple(v-SIZE for v in body.point(x,54)) for x in (34,44)]
    for side,knee,foot in ((1,fk,ff),(0,nk,nf)):
        segment(p, hips[side], knee, 3, 2.5, LE)
        segment(p, knee, (foot[0],foot[1]-2), 2.5, 2, SK)
        boot(p, *foot)
    powder_pack(body, alive=False)
    arm(p, tuple(v-SIZE for v in body.point(47,38)), fe, fg)
    torso(body)
    head(body, alive=False)
    arm(p, tuple(v-SIZE for v in body.point(29,39)), ne, ng)
    # Small settled grains, not a locally predicted gameplay blast.
    if frame >= 6:
        for x,y in ((57,68),(61,70),(66,67),(68,70)):
            p.r((x,y,x+1,y), O)
    return finish(image)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    animations = [('walk',12,[pose(i) for i in range(12)]),
                  ('death',15,[death(i) for i in range(12)])]
    frames = [image for _,_,images in animations for image in images]
    sheet = Image.new('RGBA', (SIZE*len(frames), SIZE))
    for index,image in enumerate(frames):
        sheet.alpha_composite(image, (index*SIZE,0))
    sheet_path,still_path = OUT/'kamikaorc.png',OUT/'kamikaorc_still.png'
    sheet.save(sheet_path, optimize=True)
    frames[0].save(still_path, optimize=True)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/enemies/animations/kamikaorc.png" id="1_sheet"]', '']
    for index in range(len(frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  'atlas = ExtResource("1_sheet")', f'region = Rect2({index*SIZE}, 0, {SIZE}, {SIZE})', '']
    lines += ['[resource]', 'animations = [']
    offset = 0
    for index,(name,fps,images) in enumerate(animations):
        lines += ['{', '"frames": [']
        for j in range(len(images)):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{offset+j}")',
                      '},' if j+1 < len(images) else '}']
        lines += ['],', f'"loop": {str(name == "walk").lower()},', f'"name": &"{name}",',
                  f'"speed": {float(fps)}', '},' if index+1 < len(animations) else '}']
        offset += len(images)
    lines += [']', '']
    resource = OUT/'kamikaorc.tres'
    resource.write_text('\n'.join(lines))
    helpers = [ROOT/'tools/author_enemy_sprites.py', ROOT/'tools/author_variety_enemies.py']
    reference = OUT/'grunt_still.png'
    manifest = {
        'identity': 'KamikaOrc: lean goggled powder runner, red tied hood, crossed rope harness, oversized iron-hooped red keg, powder diamond and hooked glowing fuse.',
        'authoring': 'Original deterministic local Pillow integer geometry; no image generation service or sampled source pixels.',
        'generator': 'tools/author_kamikaorc.py', 'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_kamikaorc.py',
        'geometry_helpers': {str(path.relative_to(ROOT)): digest(path) for path in helpers},
        'reused_primitives': ['Pixels','segment','O','SK','FE','LE','BO','death_tableau'],
        'design_reference': str(reference.relative_to(ROOT)), 'design_reference_sha256': digest(reference),
        'design_reference_status': 'Approved Orc is read-only; palette/style comparison only, no sampled pixels or replacement.',
        'source_origin': 'Locally authored Pillow pixel clusters; NOT PixelLab-generated',
        'camera': 'Elevated three-quarter facing left, top-left lighting, fixed foot anchor; articulated near/far limbs.',
        'alpha': 'Binary 0/255; no antialiasing, dithering, raster rotation or scaling in frames.',
        'frame_size': [SIZE,SIZE], 'sheet_size': list(sheet.size), 'base_anchor_pixels': [40,70],
        'base_anchor': [.5,.875], 'source_faces_left': True, 'recommended_world_height_cells': .6,
        'still': str(still_path.relative_to(ROOT)), 'still_alpha_bounds': list(frames[0].getbbox()),
        'sheet_sha256': digest(sheet_path), 'still_sha256': digest(still_path),
        'sprite_frames_sha256': digest(resource),
        'death': {'duration_seconds': .8, 'articulation': 'Recoil, buckled knees, turned torso, settled corpse and darkened fuse. No baked blast or blood.'},
        'animations': [{'name':name,'fps':fps,'frame_count':len(images),'loop':name == 'walk',
                        'duration_seconds':len(images)/fps,
                        'alpha_bounds':[list(image.getbbox()) for image in images]} for name,fps,images in animations],
    }
    (OUT/'kamikaorc.json').write_text(json.dumps(manifest, indent=2)+'\n')
    contact = Image.new('RGB',(SIZE*12, (SIZE+20)*2), '#26312d')
    draw = ImageDraw.Draw(contact)
    for row,(name,fps,images) in enumerate(animations):
        draw.text((4,row*(SIZE+20)+3), f'KamikaOrc / {name} / {fps} FPS', fill='#e0dfc6')
        for index,image in enumerate(images):
            contact.paste(image,(index*SIZE,row*(SIZE+20)+20),image)
        images[0].save(PREVIEW/f'kamikaorc-{name}.apng',format='PNG',save_all=True,
                       append_images=images[1:],duration=1000/fps,loop=0,disposal=0,blend=0)
    contact.save(PREVIEW/'kamikaorc-contact.png')
    print(f'Exported KamikaOrc only: {sheet_path}, {still_path}, {resource}; provenance kamikaorc.json; previews {PREVIEW}')


if __name__ == '__main__':
    main()
