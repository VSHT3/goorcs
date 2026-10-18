#!/usr/bin/env python3
"""Install the approved Orc with free, deterministic nearest-pixel cutout animation.

Run with Python + Pillow from any directory. No model, network or Godot is used.
Source PNGs are immutable; every visible color comes from the approved cutout.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = ROOT / 'assets/enemies/animations'
SIZE = 80
PAD = (8, 14)
SOURCE = HERE / 'source/basic_orc.png'
# Coordinates are in the untouched 64px approved source. Earlier masks own pixels
# where polygons overlap. The torso is the exact remainder, not a redrawn fill.
MASKS = {
    'cleaver': [(19,39),(21,38),(28,44),(29,48),(27,51),(23,47),(19,43),(18,41)],
    'head': [(27,8),(42,8),(42,22),(39,26),(35,28),(30,25),(28,22),(26,16)],
    'near_arm': [(22,16),(25,19),(24,26),(21,30),(21,34),(23,36),(21,39),(16,40),(13,36),(12,32),(14,26),(16,21)],
    'far_arm': [(41,18),(44,21),(45,27),(48,30),(48,33),(50,35),(49,39),(45,39),(43,36),(43,33),(40,29)],
    'near_boot': [(20,43),(26,43),(26,49),(25,56),(18,56),(18,51)],
    'far_boot': [(36,43),(44,43),(44,48),(48,50),(48,53),(41,53),(36,50)],
    'near_thigh': [(24,35),(32,35),(31,39),(28,44),(25,46),(20,44),(20,40)],
    'far_thigh': [(34,35),(40,35),(43,39),(44,44),(40,46),(36,44),(34,40)],
}
# Pivots describe source anatomy, not newly drawn anatomy.
PIVOTS = {
    'torso': ((32,35),(32,24)),
    'head': ((35,19),(35,10)),
    'near_arm': ((21,21),(18,36)),
    'far_arm': ((42,22),(46,36)),
    'near_thigh': ((27,36),(24,44)),
    'near_boot': ((24,44),(22,54)),
    'far_thigh': ((37,36),(40,44)),
    'far_boot': ((40,44),(44,51)),
    'cleaver': ((22,41),(26,48)),
}
ORDER = ('far_boot','far_thigh','far_arm','near_boot','near_thigh','torso','head','near_arm','cleaver')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def layers(source):
    remaining = source.copy()
    result = {}
    for name, polygon in MASKS.items():
        mask = Image.new('1', source.size)
        ImageDraw.Draw(mask).polygon(polygon, fill=1)
        part = Image.new('RGBA', source.size)
        part.paste(remaining, mask=mask)
        remaining.paste((0,0,0,0), mask=mask)
        result[name] = part
    result['torso'] = remaining
    return result


def articulated(part, source_a, source_b, target_a, target_b):
    """Map one source cutout between anatomical joints, nearest sampling only."""
    sx, sy = source_b[0]-source_a[0], source_b[1]-source_a[1]
    tx, ty = target_b[0]-target_a[0], target_b[1]-target_a[1]
    length2 = sx*sx+sy*sy
    a, b = (tx*sx+ty*sy)/length2, (ty*sx-tx*sy)/length2
    det = a*a+b*b
    # Inverse similarity map, with runtime padding applied after articulation.
    x, y = target_a[0]+PAD[0], target_a[1]+PAD[1]
    matrix = (a/det, b/det, source_a[0]-(a*x+b*y)/det,
              -b/det, a/det, source_a[1]-(-b*x+a*y)/det)
    return part.transform((SIZE,SIZE), Image.Transform.AFFINE, matrix,
                          resample=Image.Resampling.NEAREST)


def compose(parts, joints):
    image = Image.new('RGBA',(SIZE,SIZE))
    for name in ORDER:
        image.alpha_composite(articulated(parts[name], *PIVOTS[name], *joints[name]))
    return image


def add(point, offset):
    return (point[0]+offset[0],point[1]+offset[1])


def walk(parts, index, still):
    if index == 0:
        return still.copy()
    phase = index*math.tau/12
    bob = -round(abs(math.sin(phase))*1)
    joints = {}
    # Source faces right: planted feet sweep LEFT, lifted recovery travels RIGHT.
    # Subtract the frame-zero position so the creator-approved pose is exact at 0.
    for prefix, opposite in (('near',False),('far',True)):
        q = phase+(math.pi if opposite else 0)
        q0 = math.pi if opposite else 0
        dx = -3*(math.cos(q)-math.cos(q0))
        lift = -2*max(0,math.sin(q))
        hip = add(PIVOTS[prefix+'_thigh'][0],(0,bob))
        knee = add(PIVOTS[prefix+'_thigh'][1],(round(dx*.45),round(lift*.5)+bob))
        foot = add(PIVOTS[prefix+'_boot'][1],(round(dx),round(lift)))
        joints[prefix+'_thigh'] = (hip,knee)
        joints[prefix+'_boot'] = (knee,foot)
    for name in ('torso','head'):
        joints[name] = tuple(add(p,(0,bob)) for p in PIVOTS[name])
    for name, sign in (('near_arm',-1),('far_arm',1)):
        shoulder, wrist = PIVOTS[name]
        swing = round(sign*math.sin(phase)*1.5)
        joints[name] = (add(shoulder,(0,bob)),add(wrist,(swing,bob)))
    wrist_delta = (joints['near_arm'][1][0]-18,joints['near_arm'][1][1]-36)
    joints['cleaver'] = tuple(add(p,wrist_delta) for p in PIVOTS['cleaver'])
    return compose(parts,joints)


# Every target is an independently placed anatomical segment. No whole-sprite
# rotation, squashing or art substitution: recoil -> buckled knees -> side impact.
DEATH_KEYS = [
    {name: pair for name,pair in PIVOTS.items()},
    {'torso':((32,38),(34,27)), 'head':((37,22),(38,13)),
     'near_arm':((22,25),(16,35)), 'far_arm':((43,26),(47,39)),
     'near_thigh':((27,39),(23,46)), 'near_boot':((23,46),(22,54)),
     'far_thigh':((37,39),(42,47)), 'far_boot':((42,47),(46,52)),
     'cleaver':((20,40),(23,47))},
    {'torso':((36,47),(30,37)), 'head':((29,31),(24,24)),
     'near_arm':((24,37),(16,46)), 'far_arm':((37,34),(42,45)),
     'near_thigh':((31,47),(36,52)), 'near_boot':((36,52),(43,55)),
     'far_thigh':((40,45),(45,50)), 'far_boot':((45,50),(51,54)),
     'cleaver':((16,49),(10,52))},
    {'torso':((38,52),(27,49)), 'head':((21,45),(13,43)),
     'near_arm':((26,51),(18,55)), 'far_arm':((30,45),(36,53)),
     'near_thigh':((35,52),(43,53)), 'near_boot':((43,53),(52,55)),
     'far_thigh':((41,49),(49,49)), 'far_boot':((49,49),(55,53)),
     'cleaver':((15,54),(8,54))},
]


def death(parts, index, still):
    if index == 0:
        return still.copy()
    # Four tableaux, settle after frame 9; the same corpse remains in frames 10/11.
    cursor = min(3,index/3)
    key = min(2,int(cursor))
    fraction = cursor-key
    joints = {}
    for name in PIVOTS:
        joints[name] = tuple(tuple(a+(b-a)*fraction for a,b in zip(p,q))
                             for p,q in zip(DEATH_KEYS[key][name],DEATH_KEYS[key+1][name]))
    return compose(parts,joints)


def preview(frames, path, death_loop=False):
    images=[]
    timeline=([frames[0]]*6+frames+[frames[-1]]*12 if death_loop else frames)
    for frame in timeline:
        enlarged=frame.resize((480,480),Image.Resampling.NEAREST)
        background=Image.new('RGB',enlarged.size,'#35413b')
        background.paste(enlarged,(0,0),enlarged)
        images.append(background)
    images[0].save(path,save_all=True,append_images=images[1:],duration=67 if death_loop else 83,
                   loop=0,optimize=False,disposal=2)


def main():
    source=Image.open(SOURCE).convert('RGBA')
    parts=layers(source)
    still=Image.new('RGBA',(SIZE,SIZE))
    still.paste(source,PAD)
    animations=[('walk',12,[walk(parts,i,still) for i in range(12)]),
                ('death',15,[death(parts,i,still) for i in range(12)])]
    OUT.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGBA',(SIZE*24,SIZE))
    for i,frame in enumerate(frame for _,_,frames in animations for frame in frames):
        sheet.paste(frame,(SIZE*i,0))
    sheet.save(OUT/'grunt.png',optimize=True)
    still.save(OUT/'grunt_still.png',optimize=True)
    # The existing 24 atlas regions, walk/death names and timing are unchanged.
    preview(animations[0][2],HERE/'walk-preview-6x.gif')
    preview(animations[1][2],HERE/'death-preview-6x.gif',True)
    contact=Image.new('RGB',(SIZE*12,SIZE*2),'#35413b')
    for row,(_,_,frames) in enumerate(animations):
        for col,frame in enumerate(frames):
            contact.paste(frame,(col*SIZE,row*SIZE),frame)
    contact.resize((SIZE*12*3,SIZE*2*3),Image.Resampling.NEAREST).save(HERE/'walk-death-contact-3x.png')
    files={str(path.relative_to(ROOT)):digest(path) for path in
           (SOURCE,HERE/'source/basic_orc-provider.png',HERE/'source/generation.json',Path(__file__),
            OUT/'grunt.png',OUT/'grunt_still.png',OUT/'grunt.tres',
            ROOT/'resources/combat/enemies/grunt.tres',ROOT/'tools/author_enemy_sprites.py')}
    manifest={
        'approval':'Creator approved basic Orc still: enemy looks perfect; install it.',
        'source_origin':'GameLab generated still, creator approved; free local source-cutout animation',
        'provider':{'image_job_id':'ce3cd60b-93f1-45e3-8db5-9cd08b804a00','asset_id':69895,
                    'project_id':32579,'image_credits_debited':2,'local_animation_credits':0},
        'generator':str(Path(__file__).relative_to(ROOT)),
        'source':str(SOURCE.relative_to(ROOT)),
        'source_dimensions':[64,64], 'source_alpha_bounds':list(source.getbbox()),
        'frame_size':[SIZE,SIZE], 'sheet_size':list(sheet.size),
        'still':str((OUT/'grunt_still.png').relative_to(ROOT)),
        'sprite_frames':'Existing grunt.tres retained byte-for-byte: 24 80px atlas regions, 12fps walk loop and 15fps nonlooping death.',
        'still_derivation':{'operation':'lossless transparent padding only','offset':list(PAD),
                            'source_pixels':'unchanged RGBA including RGB under alpha'},
        'alpha':'binary 0/255; nearest-neighbor inverse affine sampling; no smoothing or dithering',
        'base_anchor':[.5,.875], 'board_height':.50, 'source_faces_left':False,
        'camera':'approved front/right elevated three-quarter source; mirrored by shared renderer',
        'masks_in_ownership_order':MASKS, 'pivots':PIVOTS, 'compositing_order':ORDER,
        'death_keyframes':DEATH_KEYS, 'sha256':files,
        'gait':{'source_faces_left':False,'source_direction':'right',
                'grounded_back_sweep':'left in local space', 'airborne_front_recovery':'right in local space',
                'stride_pixels':3,'lift_pixels':2,'arm_counter_swing_pixels':1.5,
                'method':'independent thigh/knee/boot joints; counter-swing arms with cleaver attached to hand'},
        'animations':[{'name':name,'fps':fps,'frame_count':len(frames),'duration_seconds':len(frames)/fps,
                       'loop':name=='walk','alpha_bounds':[list(im.getbbox()) for im in frames]}
                      for name,fps,frames in animations],
        'previous_runtime':'previous-runtime/ preserves original sheet, still, resources, imports, manifest and authoring script byte-for-byte',
        'previous_runtime_sha256':{str(path.relative_to(HERE)):digest(path)
                                   for path in sorted((HERE/'previous-runtime').iterdir()) if path.is_file()},
        'limitations':['Local cutout articulation, not provider-generated or hand-redrawn in-between anatomy.',
                       'Conservative motion cannot reveal unseen back/side surfaces; face pixels are sampled unchanged.',
                       'No Godot import, game launch, build or test was run during this asset derivation.'],
    }
    (HERE/'derivations.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'grunt.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Installed approved Orc still, twelve-frame articulated walk/death and local previews.')


if __name__=='__main__':
    main()
