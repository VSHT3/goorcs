#!/usr/bin/env python3
"""Author only NecOrcmancer Mancer's original integer-geometry sprite resources.

Run: python3 tools/author_necorcmancer_mancer.py
Requires Pillow. Existing enemy source/art is read-only. Comparison, contacts and
animated previews are exported to /tmp/gorcs-necorcmancer-mancer/. No model,
service, raster rotation, antialiasing, source cutouts or randomness is involved.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image, ImageDraw

from author_enemy_sprites import O, SK, Pixels, segment

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-necorcmancer-mancer')
KIND = 'necorcmancer_mancer'
SIZE = 128
ANCHOR = (64, 112)
# Dark violet is retained in the folds, not substituted for the old purple robe.
ROBE = ('#191f29', '#282c3d', '#414455', '#626477')
BONE = ('#535b50', '#8c9981', '#c5cfad', '#f0e9c8')
METAL = ('#232e32', '#3c5054', '#708382', '#a4b5a6')
GHOST = ('#275b55', '#4d9680', '#8ed1ad', '#d0eed1')


def pixels(image, x=0, y=0, angle=0, pivot=(58, 43)):
    """Draw in native coordinates inside a padded clipping-detection canvas."""
    return Pixels(image, SIZE+x, SIZE+y, angle=angle, pivot=pivot)


def finish(image):
    bounds = image.getbbox()
    if bounds is None or not (SIZE <= bounds[0] < bounds[2] <= SIZE*2
                              and SIZE <= bounds[1] < bounds[3] <= SIZE*2):
        raise ValueError(f'Authored geometry exceeds {SIZE}px frame: {bounds}')
    return image.crop((SIZE, SIZE, SIZE*2, SIZE*2))


def hand(p, point, raised=False, alive=True):
    x, y = point
    if raised:
        p.p([(x-4,y+3),(x-6,y-3),(x-6,y-8),(x-4,y-9),(x-3,y-3),
             (x-2,y-12),(x,y-12),(x,y-4),(x+2,y-10),(x+4,y-9),
             (x+3,y-2),(x+6,y-5),(x+7,y-3),(x+4,y+3),(x,y+5)], SK[1])
        p.l([(x-3,y),(x,y-2),(x+3,y)], SK[3])
        if alive:
            p.r((x-1,y-1,x+1,y+1), GHOST[2])
    else:
        p.p([(x-4,y-2),(x,y-4),(x+4,y-2),(x+4,y+2),(x,y+4),(x-4,y+2)], SK[1])
        p.l([(x-2,y-2),(x+2,y-2),(x+2,y)], SK[3])
        p.l([(x-2,y+1),(x+1,y+1)], SK[0])


def sleeve(p, shoulder, elbow, grip, width=5):
    segment(p, shoulder, elbow, width+1, width, ROBE)
    segment(p, elbow, grip, width, width*.72, ROBE)
    # Metal bracer with a pale edge, separately following the forearm.
    cuff = (elbow[0]*.25+grip[0]*.75, elbow[1]*.25+grip[1]*.75)
    segment(p, cuff, grip, width*.85, width*.83, METAL)
    hand(p, grip)


def crown_head(p, alive=True):
    # A broad, upright executioner's hood with swept bone crown tines. The face
    # has a projecting square muzzle, tall twin tusks and a heavy diagonal brow.
    p.p([(41,46),(38,35),(41,25),(49,19),(62,19),(71,25),(76,40),
         (73,54),(66,58),(47,55)], ROBE[0])
    p.p([(40,36),(44,27),(50,23),(58,22),(52,28),(47,39),(45,49)], ROBE[2], None)
    p.l([(43,34),(46,28),(51,25)], ROBE[3])
    p.p([(64,24),(70,29),(73,42),(70,51),(67,46)], ROBE[1], None)
    p.p([(46,34),(51,28),(61,28),(67,34),(68,44),(63,53),(52,55),
         (44,50),(42,43)], SK[0])
    p.p([(46,36),(50,31),(54,31),(53,36),(48,40),(43,41)], SK[2], None)
    p.p([(56,33),(61,31),(65,35),(65,44),(61,48),(56,43)], SK[1], None)
    p.p([(43,42),(48,39),(53,41),(53,45),(49,47),(41,46)], SK[2])
    p.p([(45,48),(51,48),(58,46),(63,47),(61,54),(51,57),(45,54)], SK[1])
    p.l([(46,50),(51,51),(59,49)], O, 2)
    p.l([(45,37),(51,35),(54,37)], O, 2)
    p.l([(58,36),(64,37)], O, 2)
    p.l([(46,39),(50,38)], GHOST[2] if alive else O, 2)
    p.r((59,38,61,39), GHOST[2] if alive else O)
    p.p([(46,53),(43,48),(43,44),(45,44),(49,52)], BONE[2])
    p.l([(44,46),(47,51)], BONE[3])
    p.p([(58,51),(60,44),(63,43),(63,48),(61,52)], BONE[1])
    p.l([(61,45),(61,49)], BONE[3])
    # Crown is a real asymmetric osseous silhouette, not a recolored hood rim.
    p.p([(40,29),(37,22),(37,14),(41,17),(43,24),(47,23),(47,14),
         (50,10),(52,13),(52,23),(57,22),(59,12),(62,8),(64,12),
         (62,24),(66,26),(70,19),(75,16),(74,23),(70,32),
         (62,28),(51,27),(43,32)], BONE[1])
    p.p([(39,18),(41,21),(42,27),(45,28),(43,30),(40,26)], BONE[3], None)
    p.l([(49,15),(49,24),(53,25)], BONE[3], 2)
    p.l([(62,12),(60,25),(65,28)], BONE[2], 2)
    p.l([(72,21),(68,28)], BONE[3])
    p.p([(52,26),(57,23),(61,27),(57,33),(53,30)], METAL[0])
    p.p([(54,27),(57,25),(59,27),(57,30)], GHOST[2] if alive else GHOST[0], None)
    p.r((56,26,57,27), GHOST[3] if alive else METAL[1])


def pauldron(p, x, y, far=False):
    # A broad angular iron blade capped by a split bone ridge and three tusks.
    p.p([(x-14,y-2),(x-7,y-10),(x+5,y-9),(x+13,y-2),(x+12,y+7),
         (x+4,y+12),(x-8,y+10),(x-15,y+4)], METAL[1])
    p.p([(x-12,y-2),(x-6,y-7),(x+4,y-6),(x+10,y-1),(x+2,y+2),(x-9,y+3)], METAL[2], None)
    p.p([(x+3,y+3),(x+11,y),(x+10,y+6),(x+4,y+9),(x-7,y+7),(x-9,y+4)], METAL[0], None)
    p.l([(x-12,y-1),(x-6,y-6),(x+3,y-5)], METAL[3])
    p.p([(x-13,y-4),(x-15,y-11),(x-10,y-8),(x-7,y-4),(x-1,y-5),
         (x+3,y-10),(x+6,y-10),(x+5,y-4),(x+11,y),(x+7,y+3),
         (x,y-1),(x-8,y+1)], BONE[1] if far else BONE[2])
    p.l([(x-12,y-7),(x-9,y-3),(x-3,y-3)], BONE[3])
    for dx, drop in ((-9,3),(-2,5),(6,2)):
        p.p([(x+dx,y+5),(x+dx+3,y+4),(x+dx+3,y+9+drop),
             (x+dx+1,y+11+drop)], BONE[1] if far else BONE[2])
        p.l([(x+dx+1,y+6),(x+dx+1,y+10+drop)], BONE[3])
    p.r((x-5,y+3,x-4,y+4), GHOST[1])


def robes(p, sway=0):
    p.p([(43,52),(63,50),(75,57),(76,79),(85+sway,105),(76,109),
         (65,106),(58,110),(49,107),(36-sway,109),(31-sway,104),
         (38,83),(37,66)], ROBE[1])
    p.p([(42,58),(49,61),(46,82),(39-sway,104),(34-sway,105),
         (40,79)], ROBE[2], None)
    p.l([(43,66),(43,81),(37-sway,102)], ROBE[3])
    p.p([(55,65),(61,63),(62,81),(70+sway,105),(63,104),
         (56,86),(53,78)], ROBE[2], None)
    p.p([(68,63),(73,62),(73,80),(82+sway,104),(75,105),(66,82)], ROBE[0], None)
    # Broad, quiet hem planes; just two restrained spectral embroidered seams.
    p.l([(33-sway,104),(38-sway,106),(49,104),(58,107),(65,103),
         (76,106),(83+sway,103)], METAL[2])
    p.l([(47,85),(44,98),(44,102)], GHOST[0])
    p.l([(64,85),(69,100)], GHOST[0])
    # Obsidian sternum plate and a rib-shaped ivory gorget, not another belt.
    p.p([(43,55),(56,51),(69,55),(69,68),(62,80),(53,81),(43,70)], METAL[0])
    p.p([(46,57),(55,54),(56,71),(53,76),(47,68)], METAL[1], None)
    for yy in (59,64,69):
        p.l([(46,yy),(51,yy+2),(54,yy+1)], BONE[1], 2)
        p.l([(59,yy+1),(63,yy),(66,yy-2)], BONE[1], 2)
        p.l([(47,yy),(51,yy+1)], BONE[2])
    p.p([(53,57),(57,54),(61,58),(59,65),(55,67),(52,63)], BONE[2])
    p.r((54,58,55,60), O)
    p.r((58,58,59,60), O)
    p.p([(56,62),(57,61),(58,63)], O, None)
    p.l([(41,78),(54,80),(67,77)], METAL[2], 3)
    p.p([(53,77),(58,75),(62,78),(59,83),(54,82)], BONE[1])
    p.p([(56,78),(58,77),(59,79),(57,81)], GHOST[1], None)
    # Two weighted tabards move independently of the feet and outer robe.
    p.p([(47,81),(53,82),(50-sway,103),(45-sway,105)], ROBE[0])
    p.l([(49,85),(47-sway,101)], METAL[2])
    p.p([(61,82),(65,80),(72+sway,102),(68+sway,104)], ROBE[0])
    p.l([(64,85),(70+sway,100)], METAL[1])


def skull_staff(p, alive=True, flare=0):
    # Staff-local coordinates. The grand ram-skull reliquary has a metal spear
    # cage, swept horns, hanging jaw and a spectral diamond above its forehead.
    p.l([(97,111),(98,77),(96,49)], O, 6)
    p.l([(97,110),(98,77),(96,49)], METAL[1], 4)
    p.l([(96,109),(97,77),(95,51)], METAL[3])
    for yy in (60,69,88,101):
        p.l([(95,yy),(100,yy-1)], BONE[1], 2)
    p.p([(94,52),(90,44),(86,39),(84,32),(85,25),(88,29),(89,35),
         (94,39),(101,38),(106,33),(106,27),(110,23),(113,26),
         (113,35),(109,43),(102,47),(101,53)], METAL[1])
    p.l([(86,28),(86,34),(89,39),(94,42)], METAL[3])
    p.l([(111,27),(111,34),(107,40)], METAL[2])
    p.p([(89,38),(84,35),(80,28),(80,22),(83,23),(85,29),(91,32),
         (98,30),(105,31),(111,27),(116,19),(118,20),(118,28),
         (112,35),(105,39)], BONE[1])
    p.l([(82,25),(84,31),(89,35)], BONE[3], 2)
    p.l([(115,25),(111,31),(105,34)], BONE[2], 2)
    p.p([(90,33),(94,29),(102,30),(107,35),(106,43),(102,46),
         (101,51),(94,52),(90,47),(88,40)], BONE[2])
    p.p([(91,34),(95,31),(100,32),(99,35),(94,37),(90,37)], BONE[3], None)
    p.p([(100,36),(105,35),(104,42),(100,45),(98,42)], BONE[1], None)
    p.p([(90,38),(95,37),(96,41),(92,43),(89,41)], O, None)
    p.p([(100,37),(104,37),(104,40),(100,42)], O, None)
    p.r((91,39,93,40), GHOST[2] if alive else GHOST[0])
    p.r((101,38,102,39), GHOST[2] if alive else GHOST[0])
    p.p([(97,41),(99,44),(96,45)], O, None)
    p.l([(92,46),(95,48),(100,47),(103,44)], BONE[0])
    p.r((94,45,95,47), BONE[3])
    p.r((99,45,100,47), BONE[3])
    p.p([(93,52),(96,49),(101,51),(99,56),(95,56)], METAL[1])
    p.p([(94,27),(96,22),(99,18),(102,23),(101,27),(98,30)], METAL[0])
    p.p([(96,26),(98,21),(100,24),(99,28)], GHOST[2] if alive else GHOST[0], None)
    p.r((98,23,98,25), GHOST[3] if alive else GHOST[1])
    if flare:
        # Sparse hard-edged sparks only at release; no bloom/alpha halo.
        p.l([(78,27),(76,23)], GHOST[2])
        p.l([(109,24),(111,20)], GHOST[2])
        p.p([(89,27),(91,23),(93,27),(91,31)], GHOST[1], None)
        p.r((105,20,106,21), GHOST[3])


def boot(p, x, y):
    p.p([(x-7,y-4),(x+3,y-5),(x+5,y),(x+3,y+2),(x-9,y+2),(x-10,y)], METAL[0])
    p.p([(x-7,y-3),(x,y-4),(x+2,y-1),(x-7,y-1)], METAL[2], None)
    p.l([(x-8,y+1),(x+2,y+1)], METAL[1])


def pose(frame, cast=False):
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    phase = frame*math.tau/12 if not cast else 0
    # Low lift, long planted step, broad counter-sway: a heavy march, not a run.
    bob = round(-abs(math.sin(phase)))
    sway = round(math.sin(phase-.5)*2) if not cast else 0
    lean = round(math.cos(phase)) if not cast else [0,0,1,2,2,1,0,-1,-1,0,0,0][frame]
    rise = [0,0,1,2,-2,-7,-12,-16,-16,-10,-4,0][frame] if cast else -round(max(0,math.sin(phase)))
    p = pixels(image)
    for x, side in ((68,1),(49,0)):
        q = phase + side*math.pi
        travel = math.cos(q)*3
        lift = max(0,math.sin(q))*2
        hip = (x,89+bob)
        knee = (x+travel*.4-1,99-lift*.4)
        foot = (x+travel,109-lift-side)
        segment(p,hip,knee,4,3.5,ROBE)
        segment(p,knee,(foot[0],foot[1]-2),3.5,3,METAL)
        boot(p,*foot)
    body = pixels(image,lean,bob)
    # Far arm reaches the actual shaft in canvas coordinates throughout casting.
    grip = (98,77+rise)
    sleeve(p,(76+lean,62+bob),(84+lean,72+rise*.45),grip)
    robes(body,sway)
    pauldron(body,76,57,True)
    pauldron(body,35,59)
    crown_head(pixels(image,lean,bob))
    free_grip = (28+round(math.cos(phase)*2),88+bob)
    if cast:
        lift = max(0,-rise)
        free_grip = (27-lift*.4,85-lift*1.1)
    sleeve(p,(31+lean,68+bob),(24+lean,77+(rise*.6 if cast else bob)),free_grip)
    if cast and frame in range(4,11):
        hand(p,free_grip,raised=True)
    skull_staff(pixels(image,0,rise),flare=cast and frame in (7,8))
    # Foreground fingers wrap the shaft rather than hovering beside it.
    hand(p,grip)
    p.l([(96,76+rise),(99,76+rise)], SK[3])
    return finish(image)


def death(frame):
    if frame == 0:
        return pose(0)
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    # Recoil -> kneel -> leftward impact. Bones/armor stay attached to the body;
    # staff is released and topples separately. Final two frames hold the corpse.
    t = [0,.05,.14,.26,.40,.56,.72,.85,.94,1,1,1][frame]
    angle = math.radians(-62*t)
    pivot = (58,70)
    body = pixels(image,8*t,6*t,angle,pivot)
    p = pixels(image)
    for x, side in ((68,1),(49,0)):
        hip = (x-5*t,89+7*t)
        knee = (x+9*t,99+5*t-side*2)
        foot = (x+14*t,109-side)
        segment(p,hip,knee,4.5,3.5,ROBE)
        segment(p,knee,(foot[0],foot[1]-2),3.5,3,METAL)
        boot(p,*foot)
    robes(body,round(3*t))
    # Both arm joints bend independently of the falling torso.
    sleeve(body,(76,62),(81-9*t,75+4*t),(91-14*t,79+9*t))
    sleeve(body,(31,68),(24+6*t,80),(28+12*t,89))
    pauldron(body,76,57,True)
    pauldron(body,35,59)
    head = pixels(image,8*t,6*t,angle,pivot)
    crown_head(head,alive=False)
    # Rotate geometry around the planted ferrule, not a rotated sprite cutout.
    fall = max(0,(t-.1)/.9)
    staff_angle = math.radians(73*fall)
    skull_staff(pixels(image,-82*math.sin(staff_angle),0,staff_angle,(97,111)),alive=False)
    return finish(image)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(animations):
    frames = [image for _,_,images in animations for image in images]
    sheet = Image.new('RGBA',(SIZE*len(frames),SIZE))
    for index,image in enumerate(frames):
        sheet.alpha_composite(image,(index*SIZE,0))
    sheet_path = OUT/f'{KIND}.png'
    still_path = OUT/f'{KIND}_still.png'
    sheet.save(sheet_path,optimize=True)
    frames[0].save(still_path,optimize=True)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{KIND}.png" id="1_sheet"]','']
    for index in range(len(frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  'atlas = ExtResource("1_sheet")',
                  f'region = Rect2({index*SIZE}, 0, {SIZE}, {SIZE})','']
    lines += ['[resource]','animations = [']
    offset = 0
    for index,(name,fps,images) in enumerate(animations):
        lines += ['{','"frames": [']
        for j in range(len(images)):
            lines += ['{','"duration": 1.0,',f'"texture": SubResource("Frame_{offset+j}")',
                      '},' if j+1<len(images) else '}']
        lines += ['],',f'"loop": {"true" if name=="walk" else "false"},',
                  f'"name": &"{name}",',f'"speed": {fps:.12f}',
                  '},' if index+1<len(animations) else '}']
        offset += len(images)
    lines += [']','']
    resource = OUT/f'{KIND}.tres'
    resource.write_text('\n'.join(lines))
    reference = OUT/'necorcmancer_still.png'
    geometry_source = ROOT/'tools/author_enemy_sprites.py'
    manifest = {
        'authoring': 'Original local integer pixel geometry; all poses redrawn from articulated joints. No model, external service, raster cutouts or sampled source pixels.',
        'identity': 'High-rank orc death sovereign: broad tusked face, swept bone-crowned executioner hood, angular iron-and-ivory shoulder blades, rib gorget, weighted dark tabards and grand horned skull reliquary staff.',
        'generator': 'tools/author_necorcmancer_mancer.py',
        'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_necorcmancer_mancer.py',
        'geometry_helpers': str(geometry_source.relative_to(ROOT)),
        'geometry_helpers_sha256': digest(geometry_source),
        'geometry_helpers_reused': ['Pixels','segment','O','SK'],
        'source_origin': 'Locally authored Pillow pixel clusters; NOT PixelLab-generated',
        'historical_reference': str(reference.relative_to(ROOT)),
        'historical_reference_sha256': digest(reference),
        'historical_reference_status': 'Read only for comparison/provenance; no source pixels used in the new sprite',
        'design_reference': 'User-supplied Orcieary screenshot of the ordinary purple-robed NecOrcmancer; existing hooded orc/skull-staff identity retained, anatomy and equipment authored anew.',
        'frame_size': [SIZE,SIZE], 'sheet_size': list(sheet.size),
        'alpha': 'binary 0/255; nearest-neighbour; no antialiasing, smoothing, dithering or raster-image rotation',
        'lighting': 'Upper-left broad material planes, dark outlines, muted ivory/iron and restrained cyan-green emissive clusters',
        'camera': 'Elevated three-quarter facing left, consistent with existing enemy roster',
        'base_anchor_pixels': list(ANCHOR),
        'base_anchor': [ANCHOR[0]/SIZE,ANCHOR[1]/SIZE],
        'source_faces_left': True, 'recommended_world_height_cells': 1.05,
        'sheet_sha256': digest(sheet_path),
        'sprite_frames_sha256': digest(resource),
        'still': str(still_path.relative_to(ROOT)),
        'still_sha256': digest(still_path), 'still_dimensions': [SIZE,SIZE],
        'still_alpha_bounds': list(frames[0].getbbox()),
        'death': {'duration_seconds': .8, 'last_frame': 'Settled armored corpse and fallen intact staff',
                  'articulation': 'Recoil, bending knees, leftward torso/head impact and independently released toppling staff',
                  'blood_in_sprite': False},
        'animations': [{'name':name,'fps':fps,'duration_seconds':len(images)/fps,
                        'frame_count':len(images),'loop':name=='walk',
                        'alpha_bounds':[list(image.getbbox()) for image in images]}
                       for name,fps,images in animations],
    }
    (OUT/f'{KIND}.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'frame_size':manifest['frame_size'],
                      'base_anchor':manifest['base_anchor'],
                      'still_alpha_bounds':manifest['still_alpha_bounds'],
                      'animations':manifest['animations']},indent=2))


def previews(animations):
    PREVIEW.mkdir(parents=True,exist_ok=True)
    old = Image.open(OUT/'necorcmancer_still.png').convert('RGBA')
    new = animations[0][2][0]
    comparison = Image.new('RGB',(960,540),'#25302d')
    d = ImageDraw.Draw(comparison)
    d.text((20,12),'ORDINARY / NEW BOSS - equal native pixels (3x nearest)',fill='#e1e0c5')
    comparison.paste(old.resize((240,240),Image.Resampling.NEAREST),(80,90),old.resize((240,240),Image.Resampling.NEAREST))
    large = new.resize((384,384),Image.Resampling.NEAREST)
    comparison.paste(large,(450,26),large)
    # Native world-height comparison uses the exact ordinary and proposed boss
    # opaque heights, so canvas padding never distorts the suggested size ratio.
    d.text((20,400),'BOARD HEIGHTS: ordinary 0.72 / boss 1.05 cells (48 px cell)',fill='#e1e0c5')
    for image,height,x in ((old,.72,150),(new,1.05,300)):
        box = image.getbbox()
        scale = height*48/(box[3]-box[1])
        thumb = image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.NEAREST)
        anchor_y = image.height*.875*scale
        comparison.paste(thumb,(x,round(505-anchor_y)),thumb)
    d.line((80,505,420,505),fill='#6a7d6a')
    comparison.save(PREVIEW/'comparison.png')
    # Every native frame, plus a magnified contact for pose and clipping review.
    contact = Image.new('RGB',(SIZE*12,SIZE*3+60),'#26312d')
    d = ImageDraw.Draw(contact)
    for row,(name,_,images) in enumerate(animations):
        y = row*(SIZE+20)
        d.text((4,y+3),name.upper(),fill='#e0dfc6')
        for index,image in enumerate(images):
            contact.paste(image,(index*SIZE,y+20),image)
    contact.save(PREVIEW/'contact-native.png')
    contact.resize((contact.width*2,contact.height*2),Image.Resampling.NEAREST).save(PREVIEW/'contact-2x.png')
    for name,fps,images in animations:
        review = []
        for image in images:
            background = Image.new('RGB',(SIZE,SIZE),'#26312d')
            background.paste(image,(0,0),image)
            review.append(background.resize((SIZE*4,SIZE*4),Image.Resampling.NEAREST))
        review[0].save(PREVIEW/f'{name}.gif',save_all=True,append_images=review[1:],
                       duration=round(1000/fps),loop=0,disposal=2)
    # Lossless animation preserves the exact cast/death timing (GIF is 10ms).
    for name,fps,images in animations:
        images[0].save(PREVIEW/f'{name}.apng',format='PNG',save_all=True,
                       append_images=images[1:],duration=1000/fps,loop=0,disposal=0,blend=0)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    animations = [('walk',7,[pose(i) for i in range(12)]),
                  ('cast',12/1.15,[pose(i,True) for i in range(12)]),
                  ('death',15,[death(i) for i in range(12)])]
    export(animations)
    previews(animations)
    print(f'Exported only {KIND}; review PNG/GIF/APNG previews in {PREVIEW}')


if __name__ == '__main__':
    main()
