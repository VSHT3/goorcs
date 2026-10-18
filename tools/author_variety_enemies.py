#!/usr/bin/env python3
"""Author four original regular enemies using deterministic Pillow integer geometry.

Run: python3 tools/author_variety_enemies.py (requires Pillow).
Only the four new identities are exported. Existing Orc/roster art is read-only.
Native PNGs, SpriteFrames and provenance go to assets/enemies/animations;
comparison sheets, contacts and GIF/APNG motion previews go to /tmp/gorcs-variety-enemies.
No image service, source cutouts, randomness, raster rotations or antialiasing.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image, ImageDraw

from author_enemy_sprites import O, SK, FE, LE, BO, Pixels, segment

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-variety-enemies')
SIZE = 80
ANCHOR = (40, 70)
KINDS = ('scrapguard', 'crate_orc', 'rage_orc', 'moss_orc')
FPS = {'scrapguard': 10, 'crate_orc': 9, 'rage_orc': 14, 'moss_orc': 8}
HEIGHTS = {'scrapguard': .65, 'crate_orc': .62, 'rage_orc': .62, 'moss_orc': .75}
RUST = ('#3b302c', '#725040', '#a77950', '#d1ae76')
WOOD = ('#382c22', '#66472d', '#a07743', '#cfaa65')
WRAP = ('#302b2c', '#584440', '#98705b', '#c5a17a')
MOSS = ('#263e30', '#3e6340', '#74984c', '#b4c878')
GROWTH = ('#285a3c', '#4c9150', '#93ce72', '#dbedab')
RAGE = ('#4b302c', '#914333', '#ce7043', '#f1b76d')
IDENTITY = {
    'scrapguard': 'Low plated infantry, slotted scrap helm, asymmetric riveted armor and oversized patchwork slab shield; small rusted cleaver in the far hand.',
    'crate_orc': 'Stooped porter with broad flattened muzzle, rope harness and huge open packed wooden crate; two distinct Orcling faces peek above its timber rim.',
    'rage_orc': 'Wiry bare-chested long-limbed orc, swept black crest, wrapped fists and ankle ties; calm upright lope becomes forward-pitched open-jawed red-eyed sprint.',
    'moss_orc': 'Heavy root-footed forest orc with hunched moss-and-bark back, shelf fungi, dangling vines and pale branching brow; self-heal draws bright green shoots into its chest.',
}


def pix(image, x=0, y=0, angle=0, pivot=(40, 44)):
    return Pixels(image, SIZE+x, SIZE+y, angle=angle, pivot=pivot)


def finish(image):
    box = image.getbbox()
    if box is None or not (SIZE < box[0] < box[2] < SIZE*2
                           and SIZE < box[1] < box[3] < SIZE*2):
        raise ValueError(f'Geometry needs more native margin: {box}')
    return image.crop((SIZE, SIZE, SIZE*2, SIZE*2))


def hand(p, x, y, wrap=False, open_hand=False):
    ramp = WRAP if wrap else SK
    p.p([(x-3,y-2),(x,y-4),(x+4,y-1),(x+3,y+3),(x-2,y+3),(x-4,y)], ramp[1])
    p.l([(x-2,y-1),(x,y-2),(x+2,y)], ramp[3])
    p.l([(x-2,y+1),(x+1,y+1)], ramp[0])
    if open_hand:
        p.l([(x-3,y-1),(x-5,y-4)], SK[2], 2)
        p.l([(x,y-2),(x,y-6)], SK[2], 2)
        p.l([(x+2,y-1),(x+4,y-4)], SK[2], 2)


def boot(p, x, y, kind):
    if kind == 'moss_orc':
        p.p([(x-4,y-5),(x+3,y-5),(x+5,y-1),(x+7,y),(x+4,y+1),
             (x,y),(x-4,y+1),(x-7,y),(x-6,y-2)], WOOD[1])
        p.l([(x-3,y-4),(x-3,y-1),(x-5,y)], MOSS[2])
        p.l([(x+1,y-3),(x+2,y)], WOOD[3])
    else:
        ramp = FE if kind == 'scrapguard' else WRAP if kind == 'rage_orc' else LE
        p.p([(x-4,y-4),(x+3,y-4),(x+4,y),(x+1,y+1),(x-7,y+1),(x-8,y-1)], ramp[0])
        p.p([(x-4,y-3),(x+1,y-3),(x+2,y-1),(x-5,y-1)], ramp[2], None)
        p.l([(x-5,y),(x+1,y)], ramp[1])
        if kind == 'rage_orc':
            p.l([(x-2,y-3),(x+2,y-2)], WRAP[3])


def limbs(p, shoulder, elbow, grip, kind, far=False, open_hand=False):
    width = {'scrapguard': 3.7, 'crate_orc': 4, 'rage_orc': 2.6, 'moss_orc': 4.8}[kind]
    segment(p, shoulder, elbow, width, width*.8, SK)
    segment(p, elbow, grip, width*.8, width*.65, SK)
    if kind == 'scrapguard':
        cuff = ((elbow[0]+grip[0])/2, (elbow[1]+grip[1])/2)
        segment(p, cuff, grip, width+1, width, FE)
    elif kind == 'rage_orc':
        cuff = (elbow[0]*.3+grip[0]*.7, elbow[1]*.3+grip[1]*.7)
        segment(p, cuff, grip, 3, 3, WRAP)
    elif kind == 'moss_orc':
        p.l([shoulder, (elbow[0]-2, elbow[1])], WOOD[1], 2)
    hand(p, *grip, wrap=kind == 'rage_orc', open_hand=open_hand)


def head(p, kind, alive=True, enraged=False):
    if kind == 'scrapguard':
        # Face projects below a flat, visibly top-lit, welded bucket helmet.
        p.p([(29,25),(47,23),(51,29),(48,36),(40,39),(30,35),(26,30)], SK[1])
        p.p([(28,29),(36,28),(40,31),(37,35),(29,34),(25,32)], SK[2])
        p.l([(29,33),(34,34),(41,33)], O)
        p.p([(30,35),(28,31),(30,31),(33,36)], BO[2])
        p.p([(40,35),(42,30),(44,30),(43,35)], BO[2])
        p.p([(28,28),(25,20),(29,14),(41,12),(49,17),(51,28),
             (44,31),(37,27)], FE[1])
        p.p([(27,20),(31,16),(41,15),(47,18),(40,21),(30,22)], FE[2], None)
        p.l([(29,19),(33,16),(40,15)], FE[3])
        p.p([(41,22),(48,19),(49,27),(44,29),(39,26)], FE[0])
        p.l([(28,26),(36,24),(42,25)], O, 2)
        p.l([(30,27),(33,26)], SK[3] if alive else O)
        p.r((44,24,46,25), SK[3] if alive else O)
        p.l([(36,16),(37,22)], RUST[2], 2)
        p.r((29,22,30,23), RUST[3])
        p.r((46,18,47,19), FE[3])
    elif kind == 'crate_orc':
        # Wide low forehead, very broad lower lip, one drooping notched ear.
        p.p([(28,25),(20,22),(21,27),(26,31),(30,30)], SK[1])
        p.p([(31,20),(42,19),(48,24),(48,33),(43,39),(32,39),
             (25,34),(25,27)], SK[1])
        p.p([(29,23),(34,21),(41,22),(37,26),(28,28)], SK[2], None)
        p.p([(27,29),(34,27),(40,30),(38,34),(27,34),(24,32)], SK[2])
        p.p([(30,35),(39,34),(45,32),(43,37),(35,39),(30,38)], SK[0], None)
        p.l([(28,27),(34,26)], O, 2)
        p.l([(40,25),(45,26)], O, 2)
        p.r((30,28,32,28), BO[2] if alive else O)
        p.r((41,27,43,27), BO[2] if alive else O)
        p.l([(28,33),(33,34),(41,32)], O)
        p.p([(28,35),(26,30),(28,30),(31,35)], BO[2])
        p.p([(39,34),(42,29),(44,29),(42,35)], BO[1])
        p.p([(31,21),(32,17),(36,19),(39,16),(44,20),(42,22)], SK[0])
    elif kind == 'rage_orc':
        # Long narrow skull, swept crest, strong nose, genuinely open rage jaw.
        p.p([(31,23),(23,19),(25,26),(30,28)], SK[1])
        p.p([(33,17),(42,17),(47,22),(46,30),(40,34),(31,32),
             (28,27),(29,21)], SK[1])
        p.p([(31,21),(35,18),(41,19),(37,23),(30,25)], SK[2], None)
        p.p([(28,26),(34,24),(37,27),(34,30),(26,29),(25,27)], SK[2])
        p.l([(29,23),(35,22)], O, 2)
        p.l([(40,22),(44,23)], O, 2)
        eye = RAGE[3] if enraged and alive else BO[2] if alive else O
        p.r((30,24,33,24), eye)
        p.r((41,24,43,24), eye)
        if enraged:
            p.p([(29,30),(36,29),(42,28),(43,34),(37,38),(30,36)], SK[0])
            p.p([(30,31),(40,30),(40,34),(35,36),(31,34)], '#2c2525', None)
            p.l([(31,31),(36,31)], BO[3])
            p.p([(30,34),(28,29),(30,29),(33,35)], BO[2])
            p.p([(38,34),(40,28),(42,28),(41,34)], BO[2])
            p.l([(35,27),(38,26)], RAGE[2])
        else:
            p.l([(29,30),(33,31),(40,29)], O)
            p.p([(30,32),(28,28),(30,28),(33,33)], BO[2])
            p.p([(39,31),(41,27),(43,27),(42,32)], BO[1])
        p.p([(31,19),(31,14),(35,16),(37,11),(40,14),(44,10),
             (44,15),(50,14),(46,20),(39,19),(35,20)], '#25302d')
        p.l([(35,17),(38,14),(40,17),(44,14)], '#53604a')
    else:
        # Deep-set old face framed by a lichen brow and branching wooden horns.
        p.p([(29,24),(22,22),(24,28),(30,31)], SK[0])
        p.p([(31,19),(43,19),(49,25),(47,35),(40,41),(31,38),(26,32),(27,25)], SK[0])
        p.p([(30,24),(34,21),(41,22),(38,27),(29,29)], SK[2], None)
        p.p([(28,30),(35,28),(41,31),(36,35),(27,35),(25,32)], SK[1])
        p.l([(29,28),(34,27)], O, 2)
        p.l([(40,27),(45,28)], O, 2)
        p.r((30,29,33,29), GROWTH[2] if alive else O)
        p.r((41,29,44,29), GROWTH[2] if alive else O)
        p.l([(28,35),(34,36),(41,34)], O)
        p.p([(29,37),(26,31),(28,30),(32,38)], BO[1])
        p.p([(39,37),(42,31),(44,30),(43,36)], BO[2])
        p.p([(28,26),(27,19),(29,14),(27,9),(30,10),(33,17),(36,17),
             (39,13),(43,14),(45,10),(49,8),(49,12),(46,16),(48,23),
             (43,24),(39,20),(34,22)], WOOD[1])
        p.l([(29,13),(31,18),(33,21)], WOOD[3])
        p.l([(47,11),(43,17),(44,21)], WOOD[2])
        p.p([(29,22),(32,17),(37,17),(39,20),(43,18),(46,21),
             (45,25),(39,24),(36,22),(32,25)], MOSS[1])
        p.l([(31,21),(34,19),(36,20)], MOSS[3])
        p.l([(40,21),(43,20),(44,22)], MOSS[2])


def shield(p):
    # Broad upper-left cap and unequal patched planes: unmistakably a scrap slab.
    p.p([(10,34),(17,28),(29,29),(34,35),(32,57),(25,65),(13,61),(9,53)], FE[0])
    p.p([(12,35),(18,31),(28,32),(30,36),(27,59),(23,62),(15,58),(12,52)], FE[1])
    p.p([(12,35),(18,31),(28,32),(26,37),(17,39),(12,38)], FE[3], None)
    p.p([(13,40),(26,37),(26,49),(13,51)], RUST[1])
    p.p([(14,41),(23,39),(23,43),(17,46),(14,46)], RUST[2], None)
    p.p([(14,53),(25,51),(26,58),(23,62),(16,58)], FE[2])
    p.l([(14,54),(23,53)], FE[3])
    p.p([(20,35),(24,35),(21,59),(18,58)], FE[0])
    p.l([(22,37),(20,55)], FE[2])
    for x, y in ((15,36),(27,35),(14,49),(25,47),(16,56),(23,58)):
        p.r((x,y,x+1,y+1), BO[2])
    p.p([(18,45),(21,42),(24,45),(23,50),(19,51),(17,48)], FE[0])
    p.l([(19,45),(21,44),(22,46)], FE[3])
    p.l([(11,49),(9,47),(10,43)], FE[2])


def child_face(p, x, y, variant, alive=True):
    # Newly drawn juvenile faces; they are not scaled/source-image Orclings.
    p.p([(x-4,y-2),(x-8,y-5),(x-7,y),(x-3,y+3)], SK[2])
    p.p([(x-4,y-5),(x+3,y-6),(x+7,y-2),(x+6,y+5),(x+1,y+8),
         (x-4,y+6),(x-6,y+1)], SK[1])
    p.p([(x-3,y-3),(x+2,y-4),(x+4,y-1),(x,y),(x-4,y)], SK[2], None)
    p.l([(x-4,y),(x-1,y-1)], O)
    p.l([(x+2,y-1),(x+4,y)], O)
    p.r((x-3,y+1,x-2,y+1), BO[3] if alive else O)
    p.r((x+3,y+1,x+3,y+1), BO[3] if alive else O)
    p.l([(x-3,y+4),(x+1,y+5),(x+4,y+3)], O)
    p.r((x-3,y+3,x-3,y+5), BO[2])
    if variant:
        p.p([(x-3,y-4),(x-3,y-8),(x,y-6),(x+3,y-9),(x+4,y-4)], SK[0])
    else:
        p.l([(x-2,y-5),(x+2,y-6)], WOOD[2], 2)


def crate(p, alive=True, fallen=False):
    p.p([(46,20),(58,16),(71,22),(71,45),(59,54),(46,47)], WOOD[0])
    p.p([(47,22),(58,18),(69,23),(58,28)], WOOD[1])
    p.p([(48,24),(58,27),(68,24),(68,31),(58,35),(48,31)], O)
    # Sacks, bundled red cloth, and two independently readable faces in the load.
    p.p([(59,18),(61,12),(66,13),(70,20),(68,26),(60,26)], WRAP[1])
    p.l([(63,15),(66,16),(68,21)], WRAP[3])
    if not fallen:
        child_face(p, 53, 20, 0, alive)
        child_face(p, 65, 21, 1, alive)
    p.p([(46,29),(58,33),(71,27),(71,46),(58,54),(46,47)], WOOD[1])
    p.p([(47,30),(57,34),(57,51),(47,46)], WOOD[2], None)
    p.p([(59,34),(70,29),(70,45),(59,51)], WOOD[0], None)
    for y in (36,42,47):
        p.l([(48,y),(57,y+3),(69,y-3)], WOOD[0])
        p.l([(48,y-1),(55,y+1)], WOOD[3])
    p.p([(46,29),(48,29),(48,47),(46,47)], WOOD[3])
    p.p([(56,33),(59,33),(59,53),(56,54)], WOOD[2])
    p.l([(60,35),(69,42),(69,45)], WOOD[2], 2)
    p.l([(60,47),(68,34)], WOOD[2], 2)
    p.l([(50,31),(51,47)], WRAP[3], 2)
    p.l([(65,30),(65,48)], WRAP[2], 2)
    for x,y in ((47,31),(57,35),(69,30),(47,45),(58,51),(69,44)):
        p.r((x,y,x+1,y+1), FE[2])


def leaf(p, x, y, direction=1, bright=False):
    ramp = GROWTH if bright else MOSS
    p.p([(x,y+3),(x-3*direction,y),(x-5*direction,y-5),
         (x,y-4),(x+2*direction,y-1)], ramp[2])
    p.l([(x,y+2),(x-2*direction,y-2)], ramp[3])


def moss_back(p, growth=0):
    p.p([(43,30),(47,23),(55,22),(62,28),(65,40),(61,50),(52,54),(44,47)], WOOD[0])
    p.p([(48,28),(54,25),(59,29),(61,40),(57,48),(49,48)], WOOD[1], None)
    p.l([(52,29),(54,36),(51,43),(54,47)], WOOD[3])
    p.p([(43,32),(44,26),(48,23),(51,25),(54,20),(59,22),(61,26),
         (64,27),(66,34),(62,36),(64,41),(60,45),(55,42),(52,46),
         (48,41),(44,42)], MOSS[1])
    p.p([(46,29),(48,25),(52,27),(55,23),(59,25),(60,29),(55,31),
         (50,29),(49,33),(45,33)], MOSS[2], None)
    p.l([(47,28),(49,26),(51,28)], MOSS[3])
    p.l([(54,27),(56,25),(58,27)], MOSS[3])
    p.p([(59,36),(63,33),(65,35),(62,39),(58,39)], MOSS[2], None)
    for x,y in ((60,28),(64,38)):
        p.l([(x,y),(x+1,y-6)], WOOD[2], 2)
        p.p([(x-4,y-5),(x-2,y-8),(x+2,y-8),(x+5,y-5),(x+3,y-3),(x-3,y-3)], RUST[1])
        p.l([(x-3,y-6),(x+1,y-7),(x+3,y-5)], BO[2])
    p.l([(61,43),(60,49),(62,52)], MOSS[1], 2)
    p.l([(48,43),(47,50),(49,53)], MOSS[1], 2)
    leaf(p, 62, 50, 1)
    leaf(p, 48, 49, -1)
    if growth:
        for x,y,direction in ((48,25,1),(58,24,-1),(63,36,-1)):
            leaf(p, x, y-growth, direction, True)


def torso(p, kind, enraged=False):
    if kind == 'scrapguard':
        p.p([(30,35),(42,32),(53,36),(55,49),(49,57),(30,56),(25,46)], FE[0])
        p.p([(29,37),(40,34),(49,37),(48,44),(38,48),(28,44)], FE[1])
        p.p([(30,38),(39,36),(44,38),(37,43),(29,42)], FE[2], None)
        p.l([(30,38),(38,36),(43,38)], FE[3])
        p.p([(43,43),(51,40),(52,49),(46,53),(39,51)], RUST[1])
        p.l([(45,44),(49,43),(49,48)], RUST[2])
        p.p([(28,45),(37,47),(38,53),(28,52)], FE[2])
        p.l([(28,47),(35,48)], FE[3])
        p.l([(28,53),(40,55),(51,51)], LE[1], 3)
        p.r((38,52,42,55), BO[1])
        p.r((39,53,41,54), O)
        p.p([(43,56),(51,53),(51,59),(46,61),(42,59)], FE[1])
        p.p([(26,34),(31,31),(37,33),(36,40),(29,42),(24,38)], FE[2])
        p.l([(27,34),(31,33),(34,35)], FE[3])
        p.p([(47,34),(53,33),(58,38),(56,43),(50,42),(47,39)], RUST[1])
        for x,y in ((30,35),(35,48),(46,46),(53,37)):
            p.r((x,y,x+1,y+1), BO[2])
    elif kind == 'crate_orc':
        p.p([(30,36),(42,34),(52,40),(53,50),(47,58),(30,57),(26,49)], SK[1])
        p.p([(30,39),(37,37),(42,39),(39,46),(31,47)], SK[2], None)
        p.p([(28,47),(34,48),(37,54),(31,55),(27,51)], SK[0], None)
        p.l([(32,40),(36,42),(40,41)], SK[3])
        p.l([(43,39),(46,45),(43,50)], SK[0])
        p.l([(31,36),(34,45),(47,52)], LE[0], 5)
        p.l([(31,36),(34,45),(47,52)], WOOD[3], 2)
        p.l([(45,36),(43,44),(30,53)], LE[0], 4)
        p.l([(45,36),(43,44),(30,53)], WRAP[2], 2)
        p.l([(28,54),(39,57),(49,53)], LE[1], 4)
        p.r((36,54,41,57), FE[1])
        p.r((38,55,39,56), BO[2])
        p.p([(30,57),(39,58),(36,63),(29,61)], WRAP[1])
    elif kind == 'rage_orc':
        p.p([(32,34),(42,32),(49,37),(47,44),(43,48),(46,54),
             (40,57),(32,53),(33,46),(28,40)], SK[1])
        p.p([(32,35),(39,34),(42,37),(37,41),(31,40)], SK[2], None)
        p.p([(41,36),(45,37),(45,41),(41,43),(38,41)], SK[2], None)
        p.l([(31,37),(36,38)], SK[3])
        p.l([(34,43),(39,45),(43,43)], SK[0])
        p.l([(35,46),(39,48),(42,46)], SK[0])
        p.l([(35,49),(39,51)], SK[2])
        p.l([(30,38),(34,40),(36,39)], RAGE[1], 2)
        p.l([(43,37),(44,41)], RAGE[1], 2)
        p.p([(32,52),(40,54),(46,51),(48,57),(42,60),(32,58),(29,55)], WRAP[0])
        p.l([(32,53),(40,55),(45,53)], WRAP[2], 2)
        p.p([(35,57),(41,58),(39,63),(35,62)], WRAP[1])
        if enraged:
            p.l([(31,36),(35,37)], RAGE[2], 2)
            p.l([(41,36),(44,37)], RAGE[2], 2)
            p.l([(35,44),(37,46)], RAGE[1])
    else:
        p.p([(30,36),(42,34),(54,39),(55,51),(48,60),(30,59),(25,49)], SK[0])
        p.p([(30,39),(38,37),(44,41),(41,48),(30,50),(27,45)], SK[1], None)
        p.p([(30,40),(35,39),(38,41),(35,44),(29,44)], SK[2], None)
        p.l([(30,48),(36,50),(41,48)], WOOD[1], 2)
        p.l([(46,41),(44,47),(47,51)], WOOD[1], 2)
        p.p([(27,51),(35,54),(45,52),(52,50),(52,58),(46,61),(38,60),(30,62),(26,58)], WOOD[1])
        p.l([(29,53),(30,59)], WOOD[3])
        p.l([(36,56),(37,59)], WOOD[2])
        p.l([(48,54),(47,58)], WOOD[3])
        leaf(p, 32, 55, 1)
        leaf(p, 45, 55, -1)
        p.p([(36,40),(40,39),(43,42),(40,46),(36,45),(34,42)], MOSS[0])
        p.l([(37,41),(40,41),(41,43)], MOSS[2])


def pose(kind, frame, action='walk'):
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    p = pix(image)
    q = frame*math.tau/12
    enraged = action == 'walk_enraged'
    heal = action == 'heal'
    stride = 7 if enraged else {'scrapguard': 3, 'crate_orc': 3, 'rage_orc': 5, 'moss_orc': 2.5}[kind]
    bob = 0 if heal else round(-abs(math.sin(q))*(2 if enraged else 1))
    lean = -.32 if enraged else .12 if kind == 'crate_orc' else 0
    body = pix(image, 0, bob, lean)
    # Drawing geometry turns about the pelvis; feet remain on the same ground plane.
    hips = (body.point(34,55), body.point(45,54))
    for side in (1,0):
        phase = q+side*math.pi
        x = 45 if side else 34
        hip = tuple(v-SIZE for v in hips[side])
        travel = math.cos(phase)*stride if not heal else 0
        lift = max(0,math.sin(phase))*(6 if enraged else 3) if not heal else 0
        foot = (x+travel, 68-lift-side)
        knee = (x+travel*.4-2, 61-lift*.5)
        width = 2.5 if kind == 'rage_orc' else 4
        segment(p, hip, knee, width+1, width, LE if kind in ('scrapguard','crate_orc') else SK)
        segment(p, knee, (foot[0],foot[1]-2), width, width*.75, FE if kind == 'scrapguard' else SK)
        if kind == 'rage_orc':
            p.l([(knee[0]-2,knee[1]),(knee[0]+2,knee[1]+1)], WRAP[2], 2)
        boot(p, *foot, kind)
    swing = round(math.cos(q)*3)
    far_grip = (58,47-swing)
    far_elbow = (55,43+swing)
    if kind == 'crate_orc':
        crate(pix(image, 0, bob))
        far_elbow,far_grip = (56,48+bob),(60,35+bob)
    elif kind == 'moss_orc':
        moss_back(body, 2 if heal and 3 <= frame <= 9 else 0)
        far_elbow,far_grip = (58,49),(57,57-swing)
    elif enraged:
        far_elbow,far_grip = (53+swing,39),(57+swing,48)
    if heal:
        rise = (0,1,2,4,6,8,8,7,5,3,1,0)[frame]
        far_elbow,far_grip = (56,48-rise*.3),(45,53-rise)
    # Far arm is drawn before the chest, foreground arm after head and torso.
    far_shoulder = tuple(v-SIZE for v in body.point(49,38))
    limbs(p, far_shoulder, far_elbow, far_grip, kind, True)
    if kind == 'scrapguard':
        x,y = far_grip
        p.l([(x,y-3),(x+2,y-10)], O, 3)
        p.l([(x,y-3),(x+2,y-9)], LE[2])
        p.p([(x+1,y-9),(x+2,y-18),(x+8,y-16),(x+8,y-10),(x+4,y-8)], FE[1])
        p.l([(x+3,y-16),(x+7,y-14),(x+7,y-11)], FE[3])
        hand(p, x, y)
    torso(body, kind, enraged)
    head(pix(image, 0, bob, lean, pivot=(40,44)), kind, enraged=enraged)
    near_shoulder = tuple(v-SIZE for v in body.point(29,39))
    if kind == 'scrapguard':
        limbs(p, near_shoulder, (25,46+bob), (23,49+bob), kind)
        shield(pix(image, -round(math.cos(q)), bob))
    elif kind == 'crate_orc':
        limbs(p, near_shoulder, (23,49+bob), (31,45+bob), kind)
        # Harness-hand actually grasps its taut strap.
        p.l([(30,39+bob),(31,46+bob)], WOOD[3], 2)
        p.l([(29,43+bob),(32,44+bob)], SK[3])
    elif kind == 'rage_orc':
        elbow = (24-swing,47+bob) if not enraged else (17-swing,49+bob)
        grip = (25-swing,55+bob) if not enraged else (12-swing,42+bob)
        limbs(p, near_shoulder, elbow, grip, kind)
    else:
        rise = (0,1,2,4,6,8,8,7,5,3,1,0)[frame] if heal else 0
        limbs(p, near_shoulder, (23,48+bob), (32 if heal else 23,56-rise+bob), kind, open_hand=heal)
        if heal and 2 <= frame <= 10:
            # The source and target of the green action are this orc's own chest.
            pulse = (0,0,1,2,3,4,4,3,2,1,1,0)[frame]
            glow = pix(image, 0, bob)
            glow.p([(36,43),(39,40-pulse),(43,43),(40,47+pulse),(36,46)], GROWTH[1])
            glow.p([(38,43),(40,41),(42,43),(40,46)], GROWTH[3], None)
            for x,y,d in ((29,45,1),(47,43,-1),(33,36,1)):
                leaf(glow, x, y-pulse, d, True)
            glow.l([(29,52-rise),(33,48),(37,45)], GROWTH[2])
            glow.l([(44,45),(48,47),(47,51-rise)], GROWTH[2])
    return finish(image)


# Recoil, buckling knees, body impact, settled. Each part is redrawn in its new
# joint space; there is no squashed/rotated raster or entire-sprite translation.
# torso offset x/y, angle, near knee/foot, far knee/foot, near elbow/grip, far elbow/grip.
DEATH_KEYS = (
    (0,0,0,(32,61),(31,68),(47,60),(48,67),(23,48),(25,55),(55,44),(58,50)),
    (3,7,.25,(28,64),(23,68),(49,64),(52,68),(21,54),(18,60),(58,53),(62,58)),
    (-2,16,-1.08,(39,65),(46,69),(53,62),(62,66),(22,66),(15,69),(36,66),(43,69)),
    (-1,17,-1.25,(40,67),(49,70),(55,65),(64,68),(23,68),(16,70),(37,67),(44,69)),
)


def death_tableau(frame):
    span = min(frame/3.5, 3)
    index = min(int(span), 2)
    t = span-index
    a,b = DEATH_KEYS[index:index+2]
    return tuple(tuple(x+(y-x)*t for x,y in zip(u,v)) if isinstance(u,tuple)
                 else u+(v-u)*t for u,v in zip(a,b))


def death(kind, frame):
    if frame == 0:
        return pose(kind, 0)
    image = Image.new('RGBA', (SIZE*3, SIZE*3))
    p = pix(image)
    dx,dy,angle,nk,nf,fk,ff,ne,ng,fe,fg = death_tableau(frame)
    if kind == 'moss_orc':
        # The branching brow needs its own impact clearance, not a larger canvas.
        fall = max(0, min(1, (frame-3)/4))
        dx += 2*fall
        dy -= 4*fall
    body = pix(image, dx, dy, angle)
    hips = [tuple(v-SIZE for v in body.point(x,55)) for x in (34,45)]
    for side,knee,foot in ((1,fk,ff),(0,nk,nf)):
        ramp = LE if kind in ('scrapguard','crate_orc') else SK
        width = 2.5 if kind == 'rage_orc' else 4
        segment(p, hips[side], knee, width+1, width, ramp)
        segment(p, knee, (foot[0],foot[1]-2), width, width*.75, FE if kind == 'scrapguard' else SK)
        boot(p, *foot, kind)
    if kind == 'crate_orc':
        # Released crate tips separately; visible juveniles go away as the box
        # falls, leaving their release to the authoritative two-child mechanic.
        drop = max(0,frame-2)
        crate(pix(image, -max(0,frame-5), min(15,drop*2),
                  min(.55,drop*.08), pivot=(58,42)), alive=False, fallen=frame >= 5)
    elif kind == 'moss_orc':
        moss_back(body)
    shoulder = tuple(v-SIZE for v in body.point(49,38))
    limbs(p, shoulder, fe, fg, kind, True)
    torso(body, kind)
    head(body, kind, alive=False)
    shoulder = tuple(v-SIZE for v in body.point(29,39))
    limbs(p, shoulder, ne, ng, kind)
    if kind == 'scrapguard':
        # Equipment releases from the actual grip and settles beside the corpse.
        t = min(1,frame/7)
        shield(pix(image, 2*t, 3*t, -.65*t, pivot=(22,54)))
        p.p([(56,65),(59,63),(64,65),(65,68),(58,69),(55,67)], FE[1])
        p.l([(51,69),(57,66)], LE[2], 2)
        p.l([(59,64),(63,66)], FE[3])
    return finish(image)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(kind, animations):
    all_frames = [image for _,_,images in animations for image in images]
    sheet = Image.new('RGBA', (SIZE*len(all_frames), SIZE))
    for index,image in enumerate(all_frames):
        sheet.alpha_composite(image, (index*SIZE,0))
    sheet_path = OUT/f'{kind}.png'
    still_path = OUT/f'{kind}_still.png'
    sheet.save(sheet_path, optimize=True)
    all_frames[0].save(still_path, optimize=True)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(all_frames)+2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{kind}.png" id="1_sheet"]', '']
    for index in range(len(all_frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  'atlas = ExtResource("1_sheet")',
                  f'region = Rect2({index*SIZE}, 0, {SIZE}, {SIZE})', '']
    lines += ['[resource]', 'animations = [']
    offset = 0
    for index,(name,fps,images) in enumerate(animations):
        lines += ['{', '"frames": [']
        for j in range(len(images)):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{offset+j}")',
                      '},' if j+1 < len(images) else '}']
        lines += ['],', f'"loop": {"true" if name.startswith("walk") else "false"},',
                  f'"name": &"{name}",', f'"speed": {fps:.12f}',
                  '},' if index+1 < len(animations) else '}']
        offset += len(images)
    lines += [']', '']
    resource = OUT/f'{kind}.tres'
    resource.write_text('\n'.join(lines))
    helpers = ROOT/'tools/author_enemy_sprites.py'
    reference = OUT/'grunt_still.png'
    manifest = {
        'authoring': 'Original deterministic local Pillow integer geometry; articulated limbs and native-pixel material planes redrawn per frame. No image generation service or source pixels.',
        'identity': IDENTITY[kind], 'generator': 'tools/author_variety_enemies.py',
        'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_variety_enemies.py',
        'geometry_helpers': str(helpers.relative_to(ROOT)),
        'geometry_helpers_sha256': digest(helpers),
        'geometry_helpers_reused': ['Pixels','segment','O','SK','FE','LE','BO'],
        'source_origin': 'Locally authored Pillow pixel clusters; NOT PixelLab-generated',
        'design_reference': str(reference.relative_to(ROOT)),
        'design_reference_sha256': digest(reference),
        'design_reference_status': 'Creator-approved Orc is read-only; comparison only, no sampled/cutout pixels or source replacement.',
        'camera': 'Elevated three-quarter facing left; top and left material planes lit; near left limbs overlap far right limbs.',
        'alpha': 'Binary 0/255, no antialiasing, dithering, smoothing, raster rotation or scaling in authored frames.',
        'frame_size': [SIZE,SIZE], 'sheet_size': list(sheet.size),
        'base_anchor_pixels': list(ANCHOR), 'base_anchor': [.5,.875],
        'source_faces_left': True, 'recommended_world_height_cells': HEIGHTS[kind],
        'still': str(still_path.relative_to(ROOT)), 'still_dimensions': [SIZE,SIZE],
        'still_alpha_bounds': list(all_frames[0].getbbox()),
        'sheet_sha256': digest(sheet_path), 'still_sha256': digest(still_path),
        'sprite_frames_sha256': digest(resource),
        'death': {'duration_seconds': .8, 'articulation': 'Recoil, knee buckle, torso impact and settled joint tableaux with separately released equipment.',
                  'last_frame': 'Settled corpse; empty fallen crate for CrateOrc, dropped shield/cleaver for Scrapguard.', 'blood_in_sprite': False},
        'animations': [{'name':name,'fps':fps,'frame_count':len(images),
                        'duration_seconds':len(images)/fps,'loop':name.startswith('walk'),
                        'alpha_bounds':[list(image.getbbox()) for image in images]}
                       for name,fps,images in animations],
    }
    (OUT/f'{kind}.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps({'id':kind, 'frame_size':manifest['frame_size'],
                      'base_anchor':manifest['base_anchor'],
                      'still_alpha_bounds':manifest['still_alpha_bounds'],
                      'animations':[{k:v for k,v in a.items() if k != 'alpha_bounds'} for a in manifest['animations']],
                      'all_frame_alpha_bounds': [min(im.getbbox()[0] for im in all_frames),
                                                 min(im.getbbox()[1] for im in all_frames),
                                                 max(im.getbbox()[2] for im in all_frames),
                                                 max(im.getbbox()[3] for im in all_frames)]}))


def previews(cycles):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    reference = Image.open(OUT/'grunt_still.png').convert('RGBA')
    stills = [('Approved Orc',reference,.50)] + [(kind,animations[0][2][0],HEIGHTS[kind]) for kind,animations in cycles.items()]
    comparison = Image.new('RGB', (1200,570), '#26312d')
    draw = ImageDraw.Draw(comparison)
    draw.text((15,12), 'NATIVE PIXELS 3x NEAREST / EXISTING ORC READ-ONLY', fill='#e0dfc6')
    for index,(name,image,height) in enumerate(stills):
        x = index*240
        draw.text((x+15,40), name, fill='#e0dfc6')
        large = image.resize((240,240),Image.Resampling.NEAREST)
        comparison.paste(large,(x,60),large)
        # The same clusters over a light background reveal alpha edge problems.
        comparison.paste('#c4c3a4',(x+20,310,x+220,430))
        thumb = image.resize((160,160),Image.Resampling.NEAREST)
        comparison.paste(thumb,(x+40,280),thumb)
        draw.text((x+20,451), f'BOARD: {height:g} cells', fill='#e0dfc6')
        scale = height*48/(image.getbbox()[3]-image.getbbox()[1])
        small = image.resize((round(SIZE*scale),round(SIZE*scale)),Image.Resampling.NEAREST)
        comparison.paste(small,(x+110,round(535-ANCHOR[1]*scale)),small)
        draw.line((x+50,535,x+195,535),fill='#70816a')
    comparison.save(PREVIEW/'comparison.png')
    for kind,animations in cycles.items():
        contact = Image.new('RGB',(SIZE*12,(SIZE+20)*len(animations)), '#26312d')
        draw = ImageDraw.Draw(contact)
        for row,(name,fps,images) in enumerate(animations):
            draw.text((4,row*(SIZE+20)+3), f'{kind} / {name} / {fps:g} FPS', fill='#e0dfc6')
            for index,image in enumerate(images):
                contact.paste(image,(index*SIZE,row*(SIZE+20)+20),image)
            review = []
            for image in images:
                background = Image.new('RGB',(SIZE,SIZE),'#26312d')
                background.paste(image,(0,0),image)
                review.append(background.resize((SIZE*4,SIZE*4),Image.Resampling.NEAREST))
            review[0].save(PREVIEW/f'{kind}-{name}.gif',save_all=True,append_images=review[1:],
                           duration=round(1000/fps),loop=0,disposal=2)
            images[0].save(PREVIEW/f'{kind}-{name}.apng',format='PNG',save_all=True,
                           append_images=images[1:],duration=1000/fps,loop=0,disposal=0,blend=0)
        contact.save(PREVIEW/f'{kind}-contact-native.png')
        contact.resize((contact.width*2,contact.height*2),Image.Resampling.NEAREST).save(PREVIEW/f'{kind}-contact-2x.png')
    motion = []
    for frame in range(12):
        image = Image.new('RGB',(SIZE*6,SIZE+24),'#26312d')
        draw = ImageDraw.Draw(image)
        entries = [(kind,cycles[kind][0][2][frame]) for kind in KINDS]
        entries += [('rage enraged',cycles['rage_orc'][2][2][frame]),
                    ('moss heal',cycles['moss_orc'][2][2][frame])]
        for index,(name,sprite) in enumerate(entries):
            image.paste(sprite,(index*SIZE,24),sprite)
            draw.text((index*SIZE+2,4),name,fill='#e0dfc6')
        motion.append(image.resize((image.width*2,image.height*2),Image.Resampling.NEAREST))
    motion[0].save(PREVIEW/'lineup.gif',save_all=True,append_images=motion[1:],duration=80,loop=0,disposal=2)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cycles = {}
    for kind in KINDS:
        animations = [('walk',FPS[kind],[pose(kind,i) for i in range(12)]),
                      ('death',15,[death(kind,i) for i in range(12)])]
        if kind == 'rage_orc':
            animations.append(('walk_enraged',22,[pose(kind,i,'walk_enraged') for i in range(12)]))
        elif kind == 'moss_orc':
            animations.append(('heal',12/.55,[pose(kind,i,'heal') for i in range(12)]))
        export(kind, animations)
        cycles[kind] = animations
    previews(cycles)
    print(f'Exported four new identities only; comparisons/contact sheets/GIF/APNG in {PREVIEW}')


if __name__ == '__main__':
    main()
