#!/usr/bin/env python3
"""Author the Elemental Orcs, ShaOrcs and HeavyDutyOrc from the shared orc rigs (Pillow only).

Run: python3 tools/author_elemental_orcs.py (requires Pillow).
The four basic elementals and the EleMetal Orc re-dress the authored Grunt rig;
the elite Omega Elemental Orc re-dresses the Brute rig. Each rig frame is
palette-swapped by exact colour and then given element-specific geometry drawn
in the same head/body joint space, so features follow the walk bob and twist.
Native PNGs, SpriteFrames and provenance go to assets/enemies/animations;
review sheets go to /tmp/gorcs-elemental-orcs. No sampling of other art, no
randomness, raster rotation or antialiasing.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image

from author_enemy_sprites import O, SK, FE, LE, BO, GO, Pixels, pose, death, leg, arm, grunt_head

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-elemental-orcs')
SIZE = 80
KINDS = ('ember_orc', 'frost_orc', 'storm_orc', 'arcane_orc', 'elemetal_orc', 'omega_orc', 'shaorc', 'greater_shaorc', 'heavy_duty_orc', 'wraithorc')
FPS = {'ember_orc': 12, 'frost_orc': 11, 'storm_orc': 13, 'arcane_orc': 12, 'elemetal_orc': 9, 'omega_orc': 9, 'shaorc': 10, 'greater_shaorc': 9, 'heavy_duty_orc': 6, 'wraithorc': 9}
HEIGHTS = {'ember_orc': .52, 'frost_orc': .52, 'storm_orc': .52, 'arcane_orc': .52, 'elemetal_orc': .56, 'omega_orc': .74, 'shaorc': .56, 'greater_shaorc': .66, 'heavy_duty_orc': .74, 'wraithorc': .6}
EYE = '#d6b65d'
IDENTITY = {
    'ember_orc': 'Ash-skinned orc with smouldering chest cracks, a flickering flame crest and rising embers; charred leathers.',
    'frost_orc': 'Pale blue orc in white fur wraps, ice shards grown through shoulder and skull, drifting snow.',
    'storm_orc': 'Slate-blue orc with a crackling spark crest, bolt war paint and arcs jumping around its body.',
    'arcane_orc': 'Violet orc in deep robes, glowing cyan runes pulsing across its chest and two rune motes circling its head.',
    'elemetal_orc': 'Grunt sealed in heavy full-body iron plate: visored bowl helm with red glare, breathing grille, huge pauldrons and banded cuirass.',
    'shaorc': 'Hunched orc shaman in a red-brown robe with a bone necklace and feather crest; raises a bone staff whose green spirit crystal flares to heal.',
    'greater_shaorc': 'Elder shaman in a wolf-pelt mantle, white beard braid and antler crown; lifts a gilded totem staff whose pale ward crystal flares to shield the horde.',
    'wraithorc': 'Hooded orc spirit in a tattered shroud that trails into wisps instead of legs; pale teal skin, burning white eyes and broken chains swinging from its outstretched wrists.',
    'heavy_duty_orc': 'Hulking plodder in industrial heavy plate: hazard-orange armour over dark steel, black-and-yellow striped pauldron, riveted visor and twin exhaust stacks puffing smoke.',
    'omega_orc': 'Obsidian-skinned armoured hulk with white-gold trim and blazing eyes; fire, ice, lightning and magic orbs orbit it.',
}
# Exact-colour palette swaps of the shared rigs: skin, leather, gold trim, armour, bone, eyes.
SWAPS = {
    'ember_orc': {SK: ('#2e2522', '#4f3a33', '#7a5546', '#a8785c'), LE: ('#211b1b', '#3a2c29', '#5a4038', '#7d5a48'),
                  GO: ('#7a2d17', '#c4521f', '#f08a2c', '#ffd26a'), EYE: '#ffcf4a'},
    'frost_orc': {SK: ('#2d3c4c', '#4a6578', '#7c9fb2', '#bcdbe6'), LE: ('#4f5a63', '#7d8a93', '#b6c3c9', '#e6eef0'),
                  GO: ('#3d6f8f', '#5fa6c9', '#9fd8ee', '#e8fbff'), EYE: '#e8fbff'},
    'storm_orc': {SK: ('#2a2b40', '#424a6b', '#66759e', '#9fb2d6'), LE: ('#222431', '#363a4e', '#545b74', '#7b839c'),
                  GO: ('#7a6420', '#c9a62c', '#f2d84a', '#fff6b0'), EYE: '#fff6b0'},
    'arcane_orc': {SK: ('#2f2438', '#4d3560', '#77538e', '#a984bc'), LE: ('#1f1a2b', '#33294a', '#4f4170', '#76659a'),
                   GO: ('#1f5b6b', '#2f98a8', '#5fd6dc', '#c4fbf5'), EYE: '#5fd6dc'},
    'elemetal_orc': {SK: ('#23282c', '#3b4349', '#636d73', '#9aa5a8'), LE: ('#1c1f22', '#2c3135', '#474e53', '#6c757a'),
                     GO: ('#3b4349', '#636d73', '#9aa5a8', '#d7dedd'), BO: ('#3b4349', '#636d73', '#9aa5a8', '#c3cccc'),
                     EYE: '#e2563a'},
    'shaorc': {LE: ('#3a2220', '#6b3428', '#9a5236', '#c58450'), GO: ('#8f8a6e', '#c4bd96', '#e6dfba', '#fbf6dd')},
    'greater_shaorc': {SK: ('#3d4a36', '#5c6d48', '#87985c', '#b6c48a'), LE: ('#24283a', '#3a3f5c', '#5a5f86', '#8489b0'),
                       GO: ('#7a6122', '#b8952f', '#e6c65a', '#fff0a8')},
    'wraithorc': {SK: ('#3a4850', '#5b7581', '#8fb0ba', '#cdebf0'), LE: ('#10161c', '#1f2b33', '#344751', '#587581'),
                  GO: ('#3a4850', '#5b7581', '#8fb0ba', '#cdebf0'), EYE: '#f4ffff'},
    'heavy_duty_orc': {FE: ('#4a2f12', '#91571c', '#cf8a2a', '#f2c25a'), LE: ('#1c1e22', '#30333a', '#4d5159', '#767b84'),
                       GO: ('#4a3c10', '#a88a1c', '#e8c42a', '#fff07a'), BO: ('#3b4046', '#5d646b', '#8c949b', '#c3cacf')},
    'omega_orc': {SK: ('#1f1c26', '#35303f', '#544b63', '#7d7290'), FE: ('#272a35', '#3f4456', '#636b85', '#9ba3c0'),
                  LE: ('#1b1a21', '#2c2a35', '#45414f', '#635d70'), GO: ('#6b5a2a', '#b39540', '#e6cf72', '#fff3c0'),
                  '#e3b567': '#f4f0ff'},
}
STEEL = SWAPS['elemetal_orc'][SK]
EMBER = SWAPS['ember_orc'][GO]
ICE = SWAPS['frost_orc'][GO]
SPARK = SWAPS['storm_orc'][GO]
RUNE = SWAPS['arcane_orc'][GO]
VIOLET = ('#3b2350', '#6a3c94', '#a46fd6', '#e2c4ff')


def rgba(color):
    color = color.lstrip('#')
    return tuple(int(color[i:i+2], 16) for i in (0, 2, 4)) + (255,)


def swap(image, kind):
    table = {}
    for source, target in SWAPS[kind].items():
        if isinstance(source, tuple):
            for a, b in zip(source, target):
                table[rgba(a)] = rgba(b)
        else:
            table[rgba(source)] = rgba(target)
    out = image.copy()
    pixels = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            mapped = table.get(pixels[x, y])
            if mapped:
                pixels[x, y] = mapped
    return out


def frame_space(frame):
    """Head and body joint space of the shared walk rig (see author_enemy_sprites.pose)."""
    phase = frame*math.tau/12
    bob = round(-abs(math.sin(phase))*1.3)
    counter = round(math.cos(phase)*.8)
    return phase, bob, counter


def ember(image, frame):
    phase, bob, counter = frame_space(frame)
    head = Pixels(image, counter-1, bob)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    flick = (0, 2, 1, 3, 1, 0, 2, 3, 0, 1, 3, 2)[frame]
    head.p([(28, 17), (30, 9-flick), (33, 13), (35, 6-flick), (38, 12), (41, 8-flick//2), (42, 18)], EMBER[1])
    head.p([(31, 17), (33, 12-flick//2), (35, 10-flick), (37, 14), (39, 12-flick//2), (40, 17)], EMBER[2], None)
    head.p([(33, 17), (35, 13-flick//2), (37, 17)], EMBER[3], None)
    # Smouldering cracks follow the torso twist.
    hot = EMBER[3] if frame % 4 < 2 else EMBER[2]
    body.l([(30, 36), (33, 40), (31, 45)], EMBER[1], 2)
    body.l([(30, 36), (33, 40), (31, 45)], hot)
    body.l([(41, 37), (44, 41), (42, 44)], EMBER[1], 2)
    body.l([(41, 37), (44, 41), (42, 44)], hot)
    body.r((33, 40, 33, 40), '#fff1b8')
    for k in range(3):
        rise = (frame*2 + k*7) % 20
        x = (24, 44, 34)[k] + round(math.sin(frame*.9 + k)*1.5)
        Pixels(image).r((x, 20-rise, x, 20-rise), EMBER[3] if rise < 10 else EMBER[2])


def frost(image, frame):
    phase, bob, counter = frame_space(frame)
    head = Pixels(image, counter-1, bob)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    for x, y, h in ((31, 16, 7), (37, 15, 9), (43, 18, 6)):
        head.p([(x-2, y+1), (x, y-h), (x+2, y+1)], ICE[1])
        head.l([(x, y-h+2), (x, y)], ICE[3])
    for x, y, h, lean in ((22, 35, 7, -2), (27, 32, 9, 0), (47, 33, 6, 2)):
        body.p([(x-2, y+1), (x+lean, y-h), (x+2, y+1)], ICE[2])
        body.l([(x-1+lean//2, y-h+3), (x-1, y-1)], ICE[3])
    glint = frame % 6
    if glint < 2:
        head.r((37, 9+glint, 37, 9+glint), '#ffffff')
    for k in range(4):
        fall = (frame*2 + k*9) % 30
        x = (16, 30, 52, 60)[k] + round(math.sin(frame*.6 + k*2))
        Pixels(image).r((x, 8+fall, x, 8+fall), ICE[3])


def zigzag(p, points, color):
    p.l(points, SPARK[1], 3)
    p.l(points, color)


def storm(image, frame):
    phase, bob, counter = frame_space(frame)
    head = Pixels(image, counter-1, bob)
    head.p([(29, 17), (30, 11), (33, 15), (35, 8), (37, 14), (40, 9), (42, 17)], SPARK[2])
    head.l([(31, 13), (33, 15), (35, 10), (37, 14), (40, 11)], SPARK[3])
    head.l([(31, 27), (33, 30), (31, 32)], SPARK[2])
    arcs = (
        [(16, 44), (19, 40), (17, 37), (21, 33)],
        [(55, 50), (58, 46), (56, 43), (60, 39)],
        [(20, 58), (17, 54), (21, 51)],
        [(52, 30), (56, 27), (54, 23), (58, 20)],
    )
    for k, arc in enumerate(arcs):
        if (frame + k) % 4 < 2:
            zigzag(Pixels(image, 0, bob), arc, SPARK[3] if (frame + k) % 2 else '#ffffff')


def arcane(image, frame):
    phase, bob, counter = frame_space(frame)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    glow = RUNE[3] if frame % 6 < 3 else RUNE[2]
    # A ring sigil on the chest with a cross-stroke, pulsing.
    body.p([(33, 38), (36, 36), (40, 36), (43, 38), (43, 42), (40, 44), (36, 44), (33, 42)], RUNE[0], glow)
    body.l([(38, 37), (38, 43)], glow)
    body.l([(35, 40), (41, 40)], RUNE[2])
    body.r((38, 40, 38, 40), '#ffffff' if frame % 6 < 3 else RUNE[3])
    for k in range(2):
        angle = frame*math.tau/12 + k*math.pi
        x = 36 + math.cos(angle)*15
        y = 14 + math.sin(angle)*3 + bob
        p = Pixels(image)
        p.p([(x-2, y), (x, y-2), (x+2, y), (x, y+2)], RUNE[1])
        p.r((x, y, x, y), RUNE[3])


def elemetal(image, frame):
    phase, bob, counter = frame_space(frame)
    head = Pixels(image, counter-1, bob)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    # Banded cuirass and pauldrons over the plated rig.
    for y in (39, 44):
        body.l([(27, y), (37, y+1), (48, y-1)], O)
        body.l([(29, y+1), (36, y+2)], STEEL[3])
    body.p([(15, 34), (20, 29), (29, 29), (32, 35), (27, 41), (16, 41)], STEEL[1])
    body.p([(17, 34), (21, 31), (27, 31), (28, 34), (18, 37)], STEEL[2], None)
    body.l([(18, 33), (22, 31), (26, 31)], STEEL[3])
    body.r((20, 37, 20, 37), STEEL[3])
    body.r((27, 36, 27, 36), STEEL[3])
    body.p([(44, 30), (51, 29), (56, 34), (54, 40), (46, 38)], STEEL[1])
    body.l([(46, 31), (51, 31), (54, 34)], STEEL[2])
    # Visored bowl helm with cheek plates and a breathing grille.
    head.p([(21, 28), (21, 19), (26, 13), (35, 10), (45, 12), (51, 18), (52, 29), (46, 31), (23, 31)], STEEL[1])
    head.p([(23, 21), (27, 15), (35, 12), (38, 15), (30, 18), (25, 24)], STEEL[2], None)
    head.l([(26, 16), (30, 13), (35, 12)], STEEL[3])
    head.l([(35, 11), (34, 24)], STEEL[0])
    head.p([(23, 29), (47, 29), (45, 36), (39, 40), (30, 40), (24, 36)], STEEL[1])
    head.p([(25, 30), (34, 30), (33, 35), (27, 36)], STEEL[2], None)
    head.r((22, 25, 48, 27), O)
    glare = '#ffb08a' if frame % 4 < 2 else '#e2563a'
    head.r((26, 26, 28, 26), glare)
    head.r((38, 26, 40, 26), glare)
    for x in (30, 33, 36, 39):
        head.r((x, 33, x, 34), O)
    for x, y in ((23, 21), (49, 21), (24, 34), (45, 34)):
        head.r((x, y, x, y), STEEL[3])


ORBS = (EMBER, ICE, SPARK, VIOLET)


def orbs(frame, dying=0):
    """Back and front layers of the four orbiting element orbs."""
    back = Image.new('RGBA', (SIZE, SIZE))
    front = Image.new('RGBA', (SIZE, SIZE))
    spread = 1 + dying*.25
    for k, ramp in enumerate(ORBS):
        angle = frame*math.tau/12 + k*math.tau/4
        x = 40 + math.cos(angle)*27*spread
        y = 40 + math.sin(angle)*7*spread - dying*3
        target = front if math.sin(angle) > 0 else back
        p = Pixels(target)
        p.p([(x-3, y-1), (x-1, y-3), (x+1, y-3), (x+3, y-1), (x+3, y+1), (x+1, y+3), (x-1, y+3), (x-3, y+1)], ramp[1], ramp[0])
        p.p([(x-2, y-1), (x-1, y-2), (x+1, y-2), (x+1, y), (x-1, y+1), (x-2, y)], ramp[2], None)
        p.r((x-1, y-1, x-1, y-1), ramp[3])
    return back, front


def omega(frame, dying=False):
    rig = death('brute', frame) if dying else pose('brute', frame)
    image = swap(rig, 'omega_orc')
    if dying and frame >= 6:
        return image
    back, front = orbs(frame, frame if dying else 0)
    out = back
    out.alpha_composite(image)
    out.alpha_composite(front)
    if not dying:
        phase, bob, counter = frame_space(frame)
        head = Pixels(out, counter-2, bob)
        # Prismatic gem set in the helm.
        head.r((35, 16, 36, 21), ORBS[frame % 4][2])
        head.r((35, 16, 35, 17), '#ffffff')
    return out


SPIRIT = ('#245a3a', '#3f9a5c', '#7fdc8c', '#e0ffd8')
WARD = ('#2c5f73', '#5aa7c2', '#9fe3f2', '#f2feff')
WOOD = ('#33261c', '#5a4129', '#8a653c', '#b8935a')
PELT = ('#3a3330', '#5e534c', '#8c7e70', '#bfb2a0')
RAISE = (0, .35, .75, 1, 1, 1, 1, 1, 1, .75, .35, 0)


def shaman(frame, greater=False, action=None):
    """Grunt anatomy re-tailored as a staff-bearing shaman; the near arm lifts the staff to cast."""
    image = Image.new('RGBA', (SIZE, SIZE))
    phase = frame*math.tau/12 if not action else 0
    bob = round(-abs(math.sin(phase))*1.3) if not action else 0
    counter = round(math.cos(phase)*.8) if not action else 0
    p = Pixels(image)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    if greater:
        # Spirit-hemmed cape behind the body widens the elder's silhouette.
        sway = round(math.sin(phase-.8)*2)
        body.p([(27, 30), (49, 30), (56+sway, 50), (58+sway, 64), (50, 62), (44, 66), (36, 63), (28, 66)], LE[0])
        body.l([(50, 34), (56+sway, 52), (57+sway, 63)], LE[2])
        body.l([(44, 66), (50, 62), (58+sway, 64)], WARD[2])
    leg(p, (45, 53+bob), 1, phase, 4, stride=4)
    arm(body, (48, 34), 0, phase, 5)
    leg(p, (33, 54+bob), 0, phase, 4, stride=4)
    body.p([(29, 33), (41, 31), (48, 35), (50, 47), (45, 56), (31, 57), (25, 49), (25, 40)], SK[1])
    body.p([(28, 36), (33, 33), (39, 34), (38, 41), (31, 43), (27, 42)], SK[3], None)
    body.p([(40, 35), (45, 36), (47, 44), (42, 46), (38, 42)], SK[2], None)
    # Long robe over the hips instead of the Grunt's kilt and baldric.
    hem = round(math.sin(phase)*1.5)
    body.p([(26, 46), (47, 45), (50, 56), (49, 64), (45, 62), (41, 65), (36, 62), (31, 65), (26, 63+hem), (23, 55)], LE[1])
    body.p([(28, 48), (35, 48), (34, 60), (28, 61)], LE[2], None)
    body.l([(37, 47), (39, 62)], LE[0])
    body.l([(26, 62+hem), (31, 64), (36, 61), (41, 64), (45, 61), (48, 63)], GO[1])
    body.l([(26, 47), (47, 46)], LE[3], 2)
    # Bone necklace.
    for x, y in ((29, 35), (32, 37), (35, 38), (38, 38), (41, 37), (44, 35)):
        body.r((x, y, x+1, y+1), GO[2])
    body.r((35, 39, 36, 41), GO[3])
    if greater:
        body.p([(22, 31), (30, 27), (42, 27), (52, 31), (53, 38), (46, 36), (36, 34), (26, 36), (21, 38)], PELT[1])
        body.l([(24, 31), (31, 28), (41, 28)], PELT[3])
        body.l([(48, 36), (53, 52), (50, 58)], PELT[0], 2)
    head = Pixels(image, counter-1, bob)
    grunt_head(head)
    if greater:
        # Antler crown and a long white beard braid.
        head.l([(27, 16), (24, 9), (21, 7)], BO[2], 2)
        head.l([(24, 10), (27, 7)], BO[2])
        head.l([(41, 15), (45, 8), (49, 6)], BO[2], 2)
        head.l([(45, 9), (43, 5)], BO[2])
        head.r((31, 14, 38, 15), GO[2])
        head.r((34, 13, 35, 13), WARD[3])
        head.p([(29, 38), (35, 38), (34, 47), (32, 49), (30, 46)], BO[3])
        head.l([(31, 40), (32, 46)], BO[1])
    else:
        for x, h, color in ((31, 8, '#c44a32'), (35, 10, '#e0b04a'), (39, 7, '#3f9a5c')):
            head.l([(x, 16), (x-1, 16-h)], color, 2)
            head.r((x-1, 16-h, x-1, 16-h), O)
    lift = RAISE[frame] if action else 0
    swing = math.cos(phase+math.pi)*3
    rest_elbow = (25-3+swing, 46)
    rest_hand = (25-2+swing*1.6, 54)
    elbow = (rest_elbow[0]+(17-rest_elbow[0])*lift, rest_elbow[1]+(30-rest_elbow[1])*lift)
    hand = (rest_hand[0]+(19-rest_hand[0])*lift, rest_hand[1]+(30-rest_hand[1])*lift)
    arm(body, (25, 37), 1, phase, 5, reach=(elbow, hand))
    # Staff through the near hand: wood shaft, then the crystal head.
    # The grip slides up the shaft as it is raised so the crystal stays in frame.
    reach = (26 if greater else 22) - (12 if greater else 9)*lift
    top = (hand[0]-2, hand[1]-reach)
    foot = (hand[0]-4, min(66, hand[1]+12))
    body.l([foot, top], O, 5)
    body.l([foot, top], WOOD[1], 3)
    body.l([(foot[0]-1, foot[1]-2), (top[0]-1, top[1]+2)], WOOD[3])
    # Hand wraps over the shaft.
    body.p([(hand[0]-5, hand[1]-2), (hand[0]-1, hand[1]-3), (hand[0]+1, hand[1]+1), (hand[0]-2, hand[1]+3), (hand[0]-5, hand[1]+1)], SK[1])
    glow = (WARD if greater else SPIRIT)
    x, y = top
    if greater:
        # Gilded crescent cradling the ward crystal, with two hanging charms.
        body.p([(x-6, y-6), (x-5, y+1), (x, y+3), (x+5, y+1), (x+6, y-6), (x+3, y-1), (x, y), (x-3, y-1)], GO[1])
        body.l([(x-5, y-5), (x-4, y), (x, y+2)], GO[3])
        body.l([(x-5, y+2), (x-5, y+6)], GO[0])
        body.r((x-6, y+6, x-5, y+7), WARD[2])
        body.l([(x+5, y+2), (x+5, y+5)], GO[0])
        body.r((x+4, y+5, x+5, y+6), WARD[2])
    else:
        # Bone fetish: a little skull lashed under the spirit crystal.
        body.p([(x-4, y+1), (x-3, y-2), (x+3, y-2), (x+4, y+1), (x+2, y+4), (x-2, y+4)], BO[2])
        body.l([(x-3, y-1), (x+2, y-1)], BO[3])
        body.r((x-2, y, x-1, y+1), O)
        body.r((x+1, y, x+2, y+1), O)
        body.l([(x-4, y+3), (x-6, y+7)], '#c44a32')
    flare = 2 if action and 3 <= frame <= 8 else 0
    body.p([(x, y-11-flare), (x+3, y-6), (x, y-2), (x-3, y-6)], glow[1], glow[0])
    body.p([(x, y-10-flare), (x+1, y-6), (x, y-4), (x-1, y-7)], glow[2], None)
    body.r((x, y-8, x, y-7), glow[3])
    if flare:
        ring = 3 + (frame-3)
        for angle in range(0, 360, 45):
            px = x + math.cos(math.radians(angle))*ring
            py = y - 4 + math.sin(math.radians(angle))*ring*.7
            Pixels(image).r((px, py, px, py), glow[3] if angle % 90 else glow[2])
    return image


def shaman_death(frame, greater):
    image = death('grunt', frame)
    if frame >= 4:
        settle = min(1, (frame-4)/3)
        p = Pixels(image)
        y = 60 + 6*settle
        p.l([(48, y-14*(1-settle)), (70, y)], O, 4)
        p.l([(48, y-14*(1-settle)), (70, y)], WOOD[1], 2)
        glow = WARD if greater else SPIRIT
        p.r((70, y-1, 71, y), glow[1 if frame > 8 else 2])
    return image


CHAIN = ('#2a2f33', '#4f575d', '#8a949b')


def wraith(frame, dying=False):
    """A hooded orc spirit: shroud for legs, reaching arms trailing broken chains."""
    image = Image.new('RGBA', (SIZE, SIZE))
    phase = frame*math.tau/12
    hover = round(math.sin(phase)*1.5)
    p = Pixels(image, 0, hover)
    sway = math.sin(phase)*2
    if dying:
        t = frame / 11
        hover = -round(t*8)
        p = Pixels(image, 0, hover)
    # Shroud trailing into wisps where legs would be.
    p.p([(26, 44), (50, 42), (54, 58), (52, 64 + sway), (46, 61), (42, 68 - sway), (36, 62), (30, 67 + sway), (24, 60)], LE[1])
    p.p([(28, 46), (36, 45), (34, 60), (28, 62)], LE[2], None)
    for k, x in enumerate((30, 42, 50)):
        w = math.sin(phase*2 + k)*2
        p.l([(x, 64), (x + w, 68), (x - w + 1, 72)], SWAPS['wraithorc'][SK][1])
    # Far arm reaching forward.
    reach = 2 + math.sin(phase)*2
    p.l([(46, 36), (34 - reach, 40), (24 - reach, 41)], O, 6)
    p.l([(46, 36), (34 - reach, 40), (24 - reach, 41)], SK[1], 4)
    # Torso under the shroud and the hood.
    p.p([(28, 32), (46, 30), (52, 44), (26, 46)], LE[1])
    p.l([(30, 34), (45, 32)], LE[3])
    p.p([(26, 26), (30, 16), (40, 12), (50, 16), (54, 28), (48, 34), (30, 34)], LE[1])
    p.p([(29, 18), (38, 14), (44, 16), (36, 20), (30, 26)], LE[3], None)
    p.p([(28, 22), (44, 21), (46, 32), (30, 33)], LE[0])
    p.p([(28, 24), (40, 22), (42, 30), (31, 32)], SK[2], O)
    p.r((31, 25, 33, 26), EYE)
    p.r((37, 25, 39, 26), EYE)
    p.r((32, 25, 32, 25), '#ffffff')
    p.r((38, 25, 38, 25), '#ffffff')
    p.p([(31, 31), (30, 28), (32, 28), (33, 31)], BO[3], O)
    p.p([(38, 31), (38, 28), (40, 28), (40, 31)], BO[3], O)
    # Near arm reaching forward with a shackle and dangling broken chain.
    reach2 = 2 + math.sin(phase + 1)*2
    hand = (16 - reach2, 40)
    p.l([(30, 36), (22 - reach2, 38), hand], O, 7)
    p.l([(30, 36), (22 - reach2, 38), hand], SK[2], 5)
    p.p([(hand[0] - 3, hand[1] - 2), (hand[0] + 1, hand[1] - 3), (hand[0] + 2, hand[1] + 1), (hand[0] - 2, hand[1] + 2)], SK[3], O)
    p.r((hand[0] + 3, hand[1] - 2, hand[0] + 5, hand[1] + 2), CHAIN[1])
    swing = math.sin(phase - .5)*3
    for k in range(4):
        x, y = hand[0] + 4 + swing*k/3, hand[1] + 3 + k*3
        p.r((x - 1, y, x + 1, y + 1), CHAIN[2 if k % 2 else 1])
    if dying:
        # The shade comes apart in rising wisps.
        t = frame / 11
        out = image.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if out[x, y][3] and ((x * 7 + y * 13 + frame) % 11) < round(t * 9):
                    out[x, y] = (0, 0, 0, 0)
    return image


SMOKE = ('#3c3d40', '#5f6166', '#8b8e93')
STRIPE = '#16171a'


def heavy_duty(frame, dying=False):
    """Brute anatomy in industrial plate: hazard stripes, visor slit, exhaust stacks."""
    image = swap(death('brute', frame) if dying else pose('brute', frame), 'heavy_duty_orc')
    if dying:
        return image
    phase, bob, counter = frame_space(frame)
    body = Pixels(image, counter, bob, math.sin(phase)*1.4)
    head = Pixels(image, counter-2, bob)
    # Twin exhaust stacks behind the far shoulder, puffing in step with the stride.
    for x, top in ((56, 12), (63, 16)):
        body.p([(x, top), (x + 4, top), (x + 4, top + 14), (x, top + 14)], SWAPS['heavy_duty_orc'][LE][1], O)
        body.l([(x + 1, top + 1), (x + 1, top + 12)], SWAPS['heavy_duty_orc'][LE][3])
        body.r((x - 1, top, x + 5, top + 1), SWAPS['heavy_duty_orc'][LE][0])
    for k in range(3):
        rise = (frame * 2 + k * 8) % 24
        x = 58 + k * 3 + round(math.sin(frame * .7 + k) * 2)
        y = 9 - rise
        if y > 1:
            r = 1 + rise // 8
            Pixels(image).p([(x - r, y), (x, y - r), (x + r, y), (x, y + r)], SMOKE[min(2, rise // 8)])
    # Black-and-yellow hazard stripes across the near pauldron.
    for k in range(4):
        x = 14 + k * 5
        body.l([(x, 39), (x + 5, 27)], STRIPE, 2)
    # Riveted visor slit across the helmet face.
    head.r((25, 29, 43, 31), O)
    head.r((28, 30, 31, 30), '#ff8a3a')
    head.r((38, 30, 40, 30), '#ff8a3a')
    for x in (24, 46):
        head.r((x, 26, x + 1, 27), SWAPS['heavy_duty_orc'][BO][3])
    return image


DRESS = {'ember_orc': ember, 'frost_orc': frost, 'storm_orc': storm, 'arcane_orc': arcane, 'elemetal_orc': elemetal}


def walk(kind, frame):
    if kind == 'omega_orc':
        return omega(frame)
    if kind == 'wraithorc':
        return swap(wraith(frame), kind)
    if kind == 'heavy_duty_orc':
        return heavy_duty(frame)
    if kind in ('shaorc', 'greater_shaorc'):
        return swap(shaman(frame, kind == 'greater_shaorc'), kind)
    image = swap(pose('grunt', frame), kind)
    DRESS[kind](image, frame)
    return image


def dying(kind, frame):
    if kind == 'omega_orc':
        return omega(frame, True)
    if kind == 'wraithorc':
        return swap(wraith(frame, True), kind)
    if kind == 'heavy_duty_orc':
        return heavy_duty(frame, True)
    if kind in ('shaorc', 'greater_shaorc'):
        return swap(shaman_death(frame, kind == 'greater_shaorc'), kind)
    return swap(death('grunt', frame), kind)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(kind, animations):
    all_frames = [image for _, _, images in animations for image in images]
    for image in all_frames:
        box = image.getbbox()
        if box is None or box[0] < 1 or box[1] < 1 or box[2] > SIZE-1 or box[3] > SIZE-1:
            raise ValueError(f'{kind} geometry needs more native margin: {box}')
    sheet = Image.new('RGBA', (SIZE*len(all_frames), SIZE))
    for index, image in enumerate(all_frames):
        sheet.alpha_composite(image, (index*SIZE, 0))
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
    for index, (name, fps, images) in enumerate(animations):
        lines += ['{', '"frames": [']
        for j in range(len(images)):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{offset+j}")',
                      '},' if j+1 < len(images) else '}']
        lines += ['],', f'"loop": {"true" if name == "walk" else "false"},',
                  f'"name": &"{name}",', f'"speed": {fps:.12f}',
                  '},' if index+1 < len(animations) else '}']
        offset += len(images)
    lines += [']', '']
    resource = OUT/f'{kind}.tres'
    resource.write_text('\n'.join(lines))
    helpers = ROOT/'tools/author_enemy_sprites.py'
    manifest = {
        'authoring': 'Shared articulated orc rig re-dressed per element: exact palette swap plus element geometry in the rig head/body joint space. No image service or sampled art.',
        'identity': IDENTITY[kind], 'generator': 'tools/author_elemental_orcs.py',
        'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_elemental_orcs.py',
        'rig': 'brute' if kind == 'omega_orc' else 'grunt',
        'geometry_helpers': str(helpers.relative_to(ROOT)),
        'geometry_helpers_sha256': digest(helpers),
        'camera': 'Elevated three-quarter facing left; top and left material planes lit.',
        'alpha': 'Binary 0/255, no antialiasing, dithering, smoothing, raster rotation or scaling.',
        'frame_size': [SIZE, SIZE], 'sheet_size': list(sheet.size),
        'base_anchor': [.5, .875], 'source_faces_left': True,
        'recommended_world_height_cells': HEIGHTS[kind],
        'still': str(still_path.relative_to(ROOT)), 'still_dimensions': [SIZE, SIZE],
        'sheet_sha256': digest(sheet_path), 'still_sha256': digest(still_path),
        'sprite_frames_sha256': digest(resource),
        'death': {'duration_seconds': .8, 'blood_in_sprite': False,
                  'last_frame': 'Settled corpse; Omega orbs scatter and fade over the first half.'},
        'animations': [{'name': name, 'fps': fps, 'frame_count': len(images),
                        'duration_seconds': len(images)/fps, 'loop': name == 'walk',
                        'alpha_bounds': [list(image.getbbox()) for image in images]}
                       for name, fps, images in animations],
    }
    (OUT/f'{kind}.json').write_text(json.dumps(manifest, indent=2)+'\n')


def previews(cycles):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    rows = len(cycles)
    sheet = Image.new('RGBA', (SIZE*12, SIZE*rows*2), (39, 48, 43, 255))
    for row, (kind, animations) in enumerate(cycles.items()):
        for column, image in enumerate(animations[0][2]):
            sheet.alpha_composite(image, (column*SIZE, row*2*SIZE))
        for column, image in enumerate(animations[-1][2] if len(animations) == 2 else animations[1][2]):
            sheet.alpha_composite(image, (column*SIZE, (row*2+1)*SIZE))
    sheet.resize((sheet.width*2, sheet.height*2), Image.NEAREST).save(PREVIEW/'contact.png')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cycles = {}
    for kind in KINDS:
        animations = [('walk', FPS[kind], [walk(kind, i) for i in range(12)]),
                      ('death', 15, [dying(kind, i) for i in range(12)])]
        if kind in ('shaorc', 'greater_shaorc'):
            animations.insert(1, ('heal', 12/.55, [swap(shaman(i, kind == 'greater_shaorc', 'heal'), kind) for i in range(12)]))
        export(kind, animations)
        cycles[kind] = animations
    previews(cycles)
    print(f'Exported {len(KINDS)} Elemental Orcs; contact sheet in {PREVIEW}')


if __name__ == '__main__':
    main()
