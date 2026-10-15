#!/usr/bin/env python3
"""Reproduce Gorcs' locally authored enemy animation exports (Pillow required).

Original grunt/runner/brute PNGs are accepted PixelLab inputs and never modified.
Their walk cycles use separately masked arms and legs, with nearest-neighbour
joint rotation and opposing strides. Four new characters are hand-plotted below
in the same dark-outline, upper-left-lit palette. No models, services, credentials,
or runtime Python dependency. All output is 80px RGBA with binary alpha.
"""
from pathlib import Path
import math
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
SIZE = 80
O = '#172323'
SKIN_DARK, SKIN, SKIN_LIGHT = '#4e622f', '#7d9146', '#b2bd68'
STEEL_DARK, STEEL, STEEL_LIGHT = '#38494d', '#71858a', '#b5c5bd'
BONE_DARK, BONE, BONE_LIGHT = '#7e8264', '#c5c6a1', '#ece6be'
LEATHER_DARK, LEATHER, LEATHER_LIGHT = '#3d3024', '#715337', '#a17c4d'
GOLD_DARK, GOLD, GOLD_LIGHT = '#71562d', '#bd9251', '#e8cb7c'


def canvas():
    return Image.new('RGBA', (SIZE, SIZE))


def poly(d, points, fill, outline=O, width=1):
    d.polygon(points, fill=fill)
    if outline:
        d.line(points + [points[0]], fill=outline, width=width)


def rect(d, box, fill, outline=None):
    d.rectangle(box, fill=fill, outline=outline)


def limb(d, points, dark, mid, light, width=6):
    d.line(points, fill=O, width=width + 2)
    d.line(points, fill=dark, width=width)
    shifted = [(x - 1, y - 1) for x, y in points]
    d.line(shifted, fill=mid, width=max(1, width - 2))
    d.line([(x - 2, y - 1) for x, y in points], fill=light, width=1)


def face(d, cx, y, small=False, bone=False):
    dark, mid, light = (BONE_DARK, BONE, BONE_LIGHT) if bone else (SKIN_DARK, SKIN, SKIN_LIGHT)
    w = 7 if small else 9
    poly(d, [(cx-w,y+3),(cx-w-5,y),(cx-w-3,y+7),(cx-w,y+8)], mid)
    poly(d, [(cx+w-1,y+3),(cx+w+5,y+1),(cx+w+3,y+7),(cx+w-1,y+8)], dark)
    poly(d, [(cx-w+2,y),(cx+4,y-1),(cx+w,y+3),(cx+w,y+13),(cx+3,y+18),(cx-w+2,y+15),(cx-w,y+7)], mid)
    poly(d, [(cx-w+2,y+1),(cx+2,y),(cx+4,y+3),(cx-3,y+4),(cx-4,y+10),(cx-w+1,y+9)], light, None)
    poly(d, [(cx+4,y+6),(cx+w-1,y+5),(cx+w-1,y+12),(cx+3,y+14),(cx+1,y+11)], dark, None)
    rect(d, (cx-4,y+5,cx,y+7), O)
    rect(d, (cx+4,y+5,cx+7,y+7), O)
    rect(d, (cx-2,y+6,cx-1,y+6), '#e2bd64' if not bone else '#7fbaae')
    rect(d, (cx+5,y+6,cx+6,y+6), '#e2bd64' if not bone else '#7fbaae')
    d.line([(cx-3,y+12),(cx+6,y+12)], fill=O, width=2)
    poly(d, [(cx-4,y+14),(cx-5,y+9),(cx-2,y+11),(cx-1,y+14)], BONE_LIGHT, None)
    poly(d, [(cx+4,y+14),(cx+6,y+9),(cx+7,y+13)], BONE_LIGHT, None)


def authored(kind, frame, special=False):
    im = canvas()
    d = ImageDraw.Draw(im)
    stride = [0, 1, 2, 1, 0, -1, -2, -1][frame % 8]
    lift = [0, 1, 1, 0, 0, 0, 0, 0][frame % 8]
    other_lift = [0, 0, 0, 0, 0, 1, 1, 0][frame % 8]
    if special:
        stride = lift = other_lift = 0
    if kind == 'orcling':
        # Oversized ears and head, ragged short tunic, bare skinny limbs.
        limb(d, [(37,57),(34-stride,63),(33-stride,68-lift)], SKIN_DARK,SKIN,SKIN_LIGHT,4)
        limb(d, [(44,57),(45+stride,63),(47+stride,68-other_lift)], SKIN_DARK,SKIN,SKIN_LIGHT,4)
        rect(d,(29-stride,67-lift,35-stride,69-lift),LEATHER_DARK,O)
        rect(d,(44+stride,67-other_lift,51+stride,69-other_lift),LEATHER_DARK,O)
        limb(d,[(32,46),(28+stride,53),(30+stride,57)],SKIN_DARK,SKIN,SKIN_LIGHT,4)
        poly(d,[(33,44),(44,44),(48,57),(44,60),(40,58),(36,60),(31,57)],LEATHER)
        poly(d,[(33,45),(38,45),(36,55),(32,56)],LEATHER_LIGHT,None)
        rect(d,(32,54,47,56),LEATHER_DARK)
        rect(d,(38,54,41,56),GOLD)
        face(d,40,29,small=True)
        # Scruffy three-point crest, not a miniature helmeted Brute.
        poly(d,[(34,29),(35,24),(38,28),(40,24),(43,29),(45,27),(46,31)],SKIN_DARK)
        limb(d,[(47,47),(51-stride,52),(49-stride,57)],SKIN_DARK,SKIN,SKIN_LIGHT,4)
    elif kind == 'skeleorc':
        # Bone limbs have hollow articulation and open negative-space ribs.
        for x, step, up in [(36,-stride,lift),(44,stride,other_lift)]:
            limb(d,[(x,53),(x+step,60),(x+step-1,68-up)],BONE_DARK,BONE,BONE_LIGHT,3)
            rect(d,(x+step-4,67-up,x+step+2,69-up),BONE,O)
            rect(d,(x+step-3,67-up,x+step+1,67-up),BONE_LIGHT)
            rect(d,(x+step-1,58,x+step+1,60),BONE_DARK)
        poly(d,[(33,48),(46,48),(47,54),(42,58),(38,57),(32,53)],BONE_DARK)
        poly(d,[(35,49),(44,49),(42,53),(37,53)],BONE)
        limb(d,[(39,40),(40,49)],BONE_DARK,BONE,BONE_LIGHT,3)
        for y in (41,45,49):
            d.line([(33,y-1),(35,y+1),(44,y+1),(47,y-2)],fill=O,width=4)
            d.line([(33,y-2),(35,y),(44,y),(47,y-3)],fill=BONE,width=2)
            rect(d,(34,y-2,37,y-2),BONE_LIGHT)
        limb(d,[(32,41),(28+stride,48),(30+stride,53)],BONE_DARK,BONE,BONE_LIGHT,3)
        limb(d,[(47,40),(51-stride,47),(49-stride,51)],BONE_DARK,BONE,BONE_LIGHT,3)
        face(d,40,23,bone=True)
        rect(d,(35,31,38,34),O)
        rect(d,(44,30,47,33),O)
        rect(d,(36,32,37,32),'#88bba7')
        rect(d,(45,31,46,31),'#88bba7')
        for x in (37,40,43):
            rect(d,(x,36,x,39),BONE_DARK)
        # A torn red waist binding is the only cloth; skeleton reads at small size.
        poly(d,[(32,51),(46,51),(44,55),(39,54),(35,58),(34,54)],'#795147')
    elif kind == 'orc_chief':
        # Broad layered steel, split crimson surcoat and a gold brow circlet.
        for x, step, up in [(30,-stride,lift),(48,stride,other_lift)]:
            limb(d,[(x,51),(x+step,60),(x+step,67-up)],STEEL_DARK,STEEL,STEEL_LIGHT,8)
            rect(d,(x+step-6,65-up,x+step+6,69-up),STEEL_DARK,O)
            rect(d,(x+step-5,65-up,x+step+4,66-up),STEEL_LIGHT)
        poly(d,[(25,43),(53,43),(55,60),(45,62),(40,55),(35,62),(24,59)],'#6f3437')
        d.line([(29,48),(28,57)],fill='#a55a4c',width=2)
        d.line([(49,48),(50,57)],fill='#9a4d44',width=2)
        poly(d,[(25,30),(52,30),(56,45),(50,52),(29,52),(23,43)],STEEL_DARK)
        poly(d,[(27,31),(40,33),(41,44),(29,46),(25,40)],STEEL)
        poly(d,[(27,32),(37,33),(36,36),(27,35)],STEEL_LIGHT,None)
        poly(d,[(42,33),(52,32),(53,43),(44,45)],'#56696e')
        for y in (40,44):
            d.line([(29,y),(39,y+2),(50,y)],fill=O,width=1)
        rect(d,(26,47,53,51),LEATHER_DARK,O)
        rect(d,(37,47,43,52),GOLD_DARK,O)
        rect(d,(38,48,42,51),GOLD)
        rect(d,(39,49,41,50),LEATHER_DARK)
        for x in (24,51):
            poly(d,[(x-7,30),(x-3,25),(x+5,26),(x+9,34),(x+7,39),(x-6,38)],STEEL)
            d.line([(x-5,30),(x-2,27),(x+4,28)],fill=STEEL_LIGHT,width=2)
            poly(d,[(x-3,26),(x-4,20),(x,25)],BONE_LIGHT)
            rect(d,(x-4,35,x-3,36),GOLD)
        face(d,39,12)
        poly(d,[(31,12),(32,8),(35,11),(39,7),(42,11),(46,8),(47,13)],GOLD_DARK)
        d.line([(32,12),(46,12)],fill=GOLD_LIGHT,width=1)
        rect(d,(38,10,40,13),'#9bbf95')
        arm_y = 33 if not special else 27 - min(frame, 3)*2
        limb(d,[(20,37),(18+stride,45),(22+stride,49)],STEEL_DARK,STEEL,STEEL_LIGHT,7)
        limb(d,[(57,36),(60-stride,arm_y+8),(57-stride,arm_y+12)],STEEL_DARK,STEEL,STEEL_LIGHT,7)
        if special:
            # Palm lifted to invoke the heal; open fingers change actual pose.
            poly(d,[(54,arm_y+9),(55,arm_y+4),(57,arm_y+6),(58,arm_y+2),(60,arm_y+3),(61,arm_y+8),(60,arm_y+12),(56,arm_y+12)],SKIN)
            rect(d,(55,arm_y+7,58,arm_y+8),SKIN_LIGHT)
    elif kind == 'necorcmancer':
        # Long asymmetrical plum robe, bone clasps and crooked skull-topped staff.
        for x, step, up in [(35,-stride,lift),(45,stride,other_lift)]:
            rect(d,(x+step-4,65-up,x+step+5,69-up),LEATHER_DARK,O)
            rect(d,(x+step-3,65-up,x+step+3,66-up),LEATHER_LIGHT)
        poly(d,[(32,30),(47,31),(51,46),(55+stride,65),(48,68),(41,65),(35,68),(26-stride,65),(30,44)],'#3f354d')
        poly(d,[(32,33),(37,33),(35,52),(32-stride,64),(28-stride,64)],'#78627e',None)
        poly(d,[(40,34),(45,34),(47,52),(50+stride,65),(44,64),(41,54)],'#594961',None)
        d.line([(38,42),(37,56),(35,64)],fill='#a18a96',width=1)
        d.line([(44,45),(46,58),(48,64)],fill='#2a2a38',width=2)
        d.line([(29-stride,64),(35,66),(41,63),(48,66),(54+stride,64)],fill=GOLD_DARK,width=1)
        face(d,39,18)
        poly(d,[(28,23),(29,15),(34,10),(43,11),(48,17),(50,30),(45,28),(45,20),(40,16),(34,18),(32,27)],'#40354e')
        d.line([(29,23),(31,16),(35,12),(41,12)],fill='#8a718b',width=2)
        d.line([(32,27),(34,19),(40,16),(45,20)],fill=GOLD_DARK,width=1)
        poly(d,[(29,29),(34,31),(40,36),(47,31),(50,30),(50,36),(41,41),(29,35)],'#302e3d')
        for x,y in [(33,33),(43,35)]:
            rect(d,(x,y,x+3,y+3),BONE,O)
            rect(d,(x+1,y+1,x+2,y+1),O)
        limb(d,[(30,38),(25+stride,45),(29+stride,49)],'#3f354d','#78627e','#a18a96',6)
        raise_staff = [0,2,5,7,7,5,2,0][frame%8] if special else 0
        sx, sy = 58, 15-raise_staff
        # Staff is authored after robe and before gripping hand; never a label/effect overlay.
        d.line([(sx-2,67-raise_staff),(sx-1,44-raise_staff),(sx,sy+12),(sx-3,sy+8)],fill=O,width=5)
        d.line([(sx-2,66-raise_staff),(sx-1,44-raise_staff),(sx,sy+12),(sx-3,sy+8)],fill=LEATHER,width=3)
        d.line([(sx-3,64-raise_staff),(sx-2,44-raise_staff),(sx-1,sy+13)],fill=LEATHER_LIGHT,width=1)
        poly(d,[(sx-6,sy+2),(sx-2,sy),(sx+4,sy+1),(sx+6,sy+5),(sx+3,sy+10),(sx+1,sy+14),(sx-3,sy+13),(sx-4,sy+9),(sx-7,sy+6)],BONE)
        poly(d,[(sx-6,sy+2),(sx-1,sy+1),(sx+2,sy+2),(sx-2,sy+4),(sx-5,sy+5)],BONE_LIGHT,None)
        rect(d,(sx-4,sy+5,sx-2,sy+7),O)
        rect(d,(sx+1,sy+4,sx+3,sy+6),O)
        rect(d,(sx-3,sy+5,sx-3,sy+5),'#8cc3a0')
        rect(d,(sx+2,sy+4,sx+2,sy+4),'#8cc3a0')
        d.line([(sx-2,sy+10),(sx+2,sy+10)],fill=BONE_DARK,width=1)
        limb(d,[(48,38),(52,43-raise_staff),(57,42-raise_staff)],'#3f354d','#78627e','#a18a96',6)
        rect(d,(55,39-raise_staff,59,43-raise_staff),SKIN_DARK,O)
        rect(d,(55,39-raise_staff,58,40-raise_staff),SKIN_LIGHT)
    return im


def source_cycle(kind):
    src = Image.open(ROOT / f'assets/enemies/{kind}.png').convert('RGBA')
    # Joint masks follow the source silhouette, not rectangular whole-body warps.
    if kind == 'grunt':
        masks = [([(10,29),(20,23),(22,33),(20,46),(10,47)],(17,29)),
                 ([(44,23),(55,25),(56,47),(44,46),(42,34)],(46,29)),
                 ([(18,46),(33,45),(32,58),(17,58)],(27,46)),
                 ([(33,45),(48,45),(48,59),(33,59)],(38,46))]
    elif kind == 'runner':
        masks = [([(9,16),(16,18),(18,25),(13,29),(7,22)],(15,19)),
                 ([(30,20),(39,20),(44,25),(39,29),(29,27)],(31,22)),
                 ([(22,28),(29,30),(22,37),(8,42),(6,37)],(25,30)),
                 ([(27,29),(34,29),(35,38),(40,44),(29,44),(25,35)],(29,30))]
    else:
        masks = [([(5,21),(14,22),(16,34),(10,37),(5,32)],(12,23)),
                 ([(35,21),(43,20),(45,33),(38,37),(33,31)],(36,23)),
                 ([(10,34),(25,34),(24,46),(9,46)],(19,35)),
                 ([(25,34),(40,34),(42,46),(25,46)],(30,35))]
    torso = src.copy()
    layers=[]
    for points,pivot in masks:
        mask=Image.new('L',src.size)
        ImageDraw.Draw(mask).polygon(points,fill=255)
        layer=canvas()
        cut=Image.new('RGBA',src.size)
        cut.paste(src,(0,0),mask)
        ox=40-src.width//2
        oy=70-src.getbbox()[3]
        layer.alpha_composite(cut,(ox,oy))
        layers.append((layer,(pivot[0]+ox,pivot[1]+oy)))
        torso.paste((0,0,0,0),(0,0,src.width,src.height),mask)
    body=canvas()
    body.alpha_composite(torso,(40-src.width//2,70-src.getbbox()[3]))
    frames=[]
    for f in range(8):
        if f==0:
            still=canvas()
            still.alpha_composite(src,(40-src.width//2,70-src.getbbox()[3]))
            frames.append(still)
            continue
        phase=math.sin(f*math.tau/8)
        im=canvas()
        for index,(layer,pivot) in enumerate(layers):
            sign=1 if index in (0,3) else -1
            angle=phase*sign*(12 if kind=='runner' else 8)
            posed=layer.rotate(angle,resample=Image.Resampling.NEAREST,center=pivot)
            # Each foot lifts only in its recovery half-cycle.
            dx=round(phase*sign*(2 if index>=2 else 1))
            dy=-1 if index>=2 and phase*sign>0.65 else 0
            im.alpha_composite(posed,(dx,dy))
        im.alpha_composite(body)
        frames.append(im)
    return frames


def export(kind, animations):
    all_frames=[im for _,_,frames in animations for im in frames]
    sheet=Image.new('RGBA',(SIZE*len(all_frames),SIZE))
    for index,im in enumerate(all_frames):
        # Rotation stays nearest-filtered; enforce the project's hard-alpha policy.
        alpha=im.getchannel('A').point(lambda a:255 if a>=128 else 0)
        im.putalpha(alpha)
        sheet.alpha_composite(im,(index*SIZE,0))
    sheet.save(OUT/f'{kind}.png',optimize=True)
    lines=[f'[gd_resource type="SpriteFrames" load_steps={len(all_frames)+2} format=3]', '',
           f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{kind}.png" id="1_sheet"]','']
    for index in range(len(all_frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]','atlas = ExtResource("1_sheet")',
                  f'region = Rect2({index*SIZE}, 0, {SIZE}, {SIZE})','']
    lines += ['[resource]','animations = [']
    offset=0
    for n,(name,speed,frames) in enumerate(animations):
        lines += ['{','"frames": [']
        for j in range(len(frames)):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{offset+j}")', '},' if j+1<len(frames) else '}']
        lines += ['],',f'"loop": {"true" if name=="walk" else "false"},',f'"name": &"{name}",',f'"speed": {speed:.1f}', '},' if n+1<len(animations) else '}']
        offset+=len(frames)
    lines += [']','']
    (OUT/f'{kind}.tres').write_text('\n'.join(lines))
    manifest = {
        'authoring': 'Local hand-plotted pixels and joint-masked accepted source animation',
        'generator': 'tools/author_enemy_sprites.py',
        'frame_size': [SIZE, SIZE],
        'sheet_size': list(sheet.size),
        'alpha': 'binary 0/255; nearest-neighbour; no antialiasing or dithering',
        'lighting': 'upper left; dark fantasy outline',
        'base_anchor': [0.5, 0.875],
        'sheet_sha256': hashlib.sha256((OUT/f'{kind}.png').read_bytes()).hexdigest(),
        'animations': [
            {'name': name, 'fps': speed, 'loop': name == 'walk',
             'alpha_bounds': [list(im.getbbox()) for im in frames]}
            for name, speed, frames in animations
        ],
    }
    if kind in ('grunt', 'runner', 'brute'):
        source_path = ROOT/f'assets/enemies/{kind}.png'
        manifest['source'] = str(source_path.relative_to(ROOT))
        manifest['source_sha256'] = hashlib.sha256(source_path.read_bytes()).hexdigest()
        manifest['source_origin'] = 'Accepted pre-existing PixelLab still; unchanged'
    else:
        manifest['source_origin'] = 'Original locally hand-plotted character in generator; no external generation service'
    (OUT/f'{kind}.json').write_text(json.dumps(manifest, indent=2) + '\n')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for kind,speed in [('grunt',10),('runner',14),('brute',8)]:
        export(kind,[('walk',speed,source_cycle(kind))])
    for kind,speed in [('orcling',12),('skeleorc',14),('orc_chief',8),('necorcmancer',9)]:
        animations=[('walk',speed,[authored(kind,i) for i in range(8)])]
        if kind=='orc_chief':
            animations.append(('heal',14.5,[authored(kind,i,True) for i in range(8)]))
        if kind=='necorcmancer':
            animations.append(('cast',7,[authored(kind,i,True) for i in range(8)]))
        export(kind,animations)
        # New identities have a true authored still; accepted legacy stills stay untouched.
        authored(kind,0).save(ROOT/f'assets/enemies/{kind}.png',optimize=True)


if __name__=='__main__':
    main()
