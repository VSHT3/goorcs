#!/usr/bin/env python3
"""Author Dreadmaw, the Bone Wyrm: the round-200 boss (Pillow only).

Run: python3 tools/author_dreadmaw.py (requires Pillow).
A skeletal dragon on an articulated joint rig: skull and horns, an S-curved
neck, open ribcage around a burning soulfire heart, spiked spine, tail
vertebrae, four clawed legs with a real gait, a tattered bone wing and a lich
orc rider with a war banner. Integer Pillow geometry through the shared Pixels
primitive; no sampled art, raster rotation, antialiasing or translucency.
Native PNG, SpriteFrames and provenance go to assets/enemies/animations;
review sheets go to /tmp/gorcs-dreadmaw.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image

from author_enemy_sprites import O, Pixels

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-dreadmaw')
KIND = 'dreadmaw'
SIZE = 288
# Local rig ground line; every frame is drawn offset by (X0, Y0) on the canvas.
GROUND = 222
X0, Y0 = 24, 24
BONE = ('#4f4b40', '#8e8873', '#c9c2a6', '#f2ecd6')
DARK = ('#36332c', '#625d4f', '#8f8873', '#b9b39b')
SOUL = ('#1b5638', '#2c9a5b', '#6cee98', '#dcffe6')
MEMBRANE = ('#16131b', '#2a2431', '#42394c')
IRON = ('#1d2226', '#343c42', '#56616a', '#86929b')
BANNER = ('#123a26', '#1f6140', '#36905f')
SPEC = (
    ('walk', 12, 7.5, True), ('walk_enraged', 12, 11, True),
    ('soulfire', 12, 12 / 1.6, False), ('raise_dead', 12, 12 / 1.8, False), ('death', 16, 8, False),
)


class Scaled(Pixels):
    """Pixels whose geometry is scaled about an origin (line widths stay native)."""
    def __init__(self, image, x, y, origin, scale):
        super().__init__(image, x, y)
        self.origin, self.scale = origin, scale

    def point(self, x, y):
        ox, oy = self.origin
        return super().point(ox + (x - ox) * self.scale, oy + (y - oy) * self.scale)


def hole(p, x, y, r):
    """A tear through the wing membrane (true transparency)."""
    p.p([(x - r, y), (x, y - r * .7), (x + r, y), (x, y + r * .7)], (0, 0, 0, 0), None)


def bone(p, a, b, width, ramp=BONE):
    p.l([a, b], O, width + 2)
    p.l([a, b], ramp[1], width)
    p.l([(a[0] - 1, a[1] - 1), (b[0] - 1, b[1] - 1)], ramp[2], max(1, width // 2))
    p.r((a[0] - 1, a[1] - 1, a[0], a[1]), ramp[3])


def knob(p, x, y, r, ramp=BONE):
    p.p([(x - r, y), (x, y - r), (x + r, y), (x, y + r)], ramp[2], O)
    p.r((x - 1, y - 1, x - 1, y - 1), ramp[3])


def flame(p, x, y, h, ramp=SOUL, lean=0):
    """A small soulfire tongue."""
    p.p([(x - 3, y), (x - 1 + lean, y - h), (x + 1 + lean, y - h + 2), (x + 3, y)], ramp[1])
    p.p([(x - 1, y), (x + lean, y - h + 3), (x + 1, y)], ramp[2], None)
    p.r((x, y - 2, x, y - 1), ramp[3])


def leg(p, hip, phase, near, drop, stride=9):
    """Clawed bone leg with gait: shoulder/hip, knee, ankle, splayed talons."""
    ramp = BONE if near else DARK
    lift = max(0.0, math.sin(phase)) * 7
    travel = math.cos(phase) * stride
    foot = (hip[0] - 2 + travel, GROUND - lift)
    knee = (hip[0] + (8 if near else 6) + travel * .3, (hip[1] + foot[1]) * .5 - 4 - lift * .3)
    ankle = (foot[0] + 4, foot[1] - 8)
    bone(p, hip, knee, 10 if near else 8, ramp)
    bone(p, knee, ankle, 8 if near else 6, ramp)
    knob(p, knee[0], knee[1], 6, ramp)
    knob(p, ankle[0], ankle[1], 4, ramp)
    for k, dx in enumerate((-11, -5, 2)):
        p.l([(ankle[0], ankle[1]), (foot[0] + dx, foot[1] - 1), (foot[0] + dx - 4, foot[1] + 1)], O, 5)
        p.l([(ankle[0], ankle[1]), (foot[0] + dx, foot[1] - 1)], ramp[2], 3)
        p.p([(foot[0] + dx - 5, foot[1] + 1), (foot[0] + dx - 1, foot[1] - 2), (foot[0] + dx, foot[1] + 1)], ramp[3], O)


def wing(p, shoulder, raise_amount, phase, near=False):
    """Bone wing arm with fanned finger bones and tattered membrane."""
    flap = math.sin(phase) * 4
    sx, sy = shoulder
    elbow = (sx + 36, sy - 44 - raise_amount * 18 + flap)
    wrist = (sx + 66, sy - 70 - raise_amount * 26 + flap * 1.5)
    tips = [(wrist[0] + 44, wrist[1] + 8 + flap), (wrist[0] + 40, wrist[1] + 34), (wrist[0] + 24, wrist[1] + 58), (wrist[0] - 2, wrist[1] + 70)]
    if near:
        elbow = (sx + 20, sy - 22 - raise_amount * 10)
        wrist = (sx + 46, sy - 26 - raise_amount * 16)
        tips = [(wrist[0] + 26, wrist[1] + 16), (wrist[0] + 14, wrist[1] + 34), (wrist[0] - 6, wrist[1] + 40)]
    prev = shoulder
    for k, tip in enumerate(tips):
        # Ragged membrane between bones: inner points dip toward the arm.
        mid = ((prev[0] + tip[0]) / 2 + 6, (prev[1] + tip[1]) / 2 + 8)
        p.p([wrist, prev, mid, tip], MEMBRANE[1] if k % 2 else MEMBRANE[0])
        p.l([prev, (mid[0] - 3, mid[1] - 2), mid, (mid[0] + 2, mid[1] - 3), tip], MEMBRANE[2])
        prev = tip
    if not near:
        for k, (hx, hy) in enumerate(((wrist[0] + 18, wrist[1] + 24), (wrist[0] + 8, wrist[1] + 46), (wrist[0] + 30, wrist[1] + 40))):
            hole(p, hx, hy + math.sin(phase + k) * 2, 3 + k % 2)
    bone(p, shoulder, elbow, 9 if not near else 7)
    bone(p, elbow, wrist, 7 if not near else 5)
    knob(p, elbow[0], elbow[1], 5)
    for tip in tips:
        bone(p, wrist, tip, 3)
    p.p([(wrist[0] - 2, wrist[1] - 2), (wrist[0] - 8, wrist[1] - 12), (wrist[0] + 2, wrist[1] - 4)], BONE[3], O)
    knob(p, wrist[0], wrist[1], 3)


def skull(p, x, y, jaw, glow, ramp=BONE):
    """Long dragon skull facing left with backswept horns and a soulfire eye."""
    # Horns sweep back over the neck.
    p.l([(x + 18, y - 8), (x + 30, y - 22), (x + 46, y - 30), (x + 58, y - 30)], O, 6)
    p.l([(x + 18, y - 8), (x + 30, y - 22), (x + 46, y - 30), (x + 58, y - 30)], ramp[2], 4)
    p.l([(x + 22, y - 12), (x + 32, y - 24)], ramp[3])
    p.l([(x + 12, y - 6), (x + 18, y - 20), (x + 28, y - 28)], O, 4)
    p.l([(x + 12, y - 6), (x + 18, y - 20), (x + 28, y - 28)], ramp[1], 2)
    # Lower jaw hinges open.
    p.p([(x + 16, y + 6), (x - 14, y + 10 + jaw), (x - 22, y + 8 + jaw), (x - 8, y + 4 + jaw * .5), (x + 10, y + 2)], ramp[1], O)
    for k in range(4):
        tx = x - 18 + k * 7
        p.p([(tx, y + 8 + jaw * (1 - k * .2)), (tx + 2, y + 3 + jaw * (1 - k * .2)), (tx + 4, y + 8 + jaw * (1 - k * .2))], ramp[3])
    if jaw > 2:
        p.p([(x - 18, y + 6), (x + 12, y + 3), (x - 12, y + 4 + jaw * .8)], SOUL[1 if glow < 2 else 2])
    # Upper skull and snout.
    p.p([(x + 22, y - 6), (x + 16, y - 14), (x + 2, y - 14), (x - 14, y - 6), (x - 28, y - 2), (x - 30, y + 3), (x - 18, y + 6), (x + 16, y + 6), (x + 22, y + 2)], ramp[2], O)
    p.p([(x + 14, y - 12), (x + 2, y - 12), (x - 12, y - 5), (x - 24, y - 1), (x - 10, y - 3), (x + 6, y - 7)], ramp[3], None)
    p.l([(x - 26, y + 2), (x + 14, y + 4)], ramp[1])
    for k in range(5):
        tx = x - 26 + k * 7
        p.p([(tx, y + 4), (tx + 2, y + 9), (tx + 4, y + 4)], ramp[3], O)
    # Nostril and soulfire eye socket.
    p.r((x - 25, y - 2, x - 23, y - 1), O)
    p.p([(x + 2, y - 10), (x + 10, y - 11), (x + 12, y - 5), (x + 4, y - 4)], O)
    p.r((x + 5, y - 9, x + 9, y - 6), SOUL[2 + min(1, glow)])
    p.r((x + 6, y - 8, x + 7, y - 7), '#ffffff')
    if glow:
        p.l([(x + 10, y - 8), (x + 16 + glow * 3, y - 11)], SOUL[2])


def rider(p, x, y, phase, raise_banner=0.0, ramp=SOUL):
    """Lich orc warlord in the saddle with a tattered soulfire banner."""
    flutter = math.sin(phase * 1.5) * 3
    pole_top = (x - 12 - raise_banner * 4, y - 56 - raise_banner * 6)
    p.l([(x - 4, y + 10), pole_top], O, 4)
    p.l([(x - 4, y + 10), pole_top], IRON[2], 2)
    bx, by = pole_top
    p.p([(bx, by + 2), (bx - 22, by + 6 + flutter), (bx - 18, by + 12 + flutter), (bx - 24, by + 18 + flutter), (bx - 6, by + 22 + flutter * .5), (bx, by + 20)], BANNER[1], O)
    p.l([(bx - 3, by + 6), (bx - 16, by + 9 + flutter)], BANNER[2])
    p.p([(bx - 12, by + 10 + flutter * .7), (bx - 7, by + 8 + flutter * .7), (bx - 8, by + 14 + flutter * .7)], BONE[3])
    p.p([(bx - 2, by - 4), (bx + 2, by - 4), (bx, by - 9)], IRON[3], O)
    # Tattered cape behind.
    p.p([(x + 4, y - 18), (x + 16, y - 16), (x + 22 + flutter, y + 6), (x + 14, y + 2), (x + 10, y + 10), (x + 4, y + 2)], BANNER[0], O)
    # Armoured torso and pauldrons.
    p.p([(x - 8, y - 20), (x + 8, y - 20), (x + 10, y + 4), (x - 10, y + 4)], IRON[1], O)
    p.p([(x - 7, y - 18), (x - 1, y - 18), (x - 3, y + 2), (x - 8, y + 2)], IRON[2], None)
    p.l([(x - 6, y - 10), (x + 7, y - 10)], ramp[1])
    p.p([(x - 13, y - 20), (x - 6, y - 24), (x, y - 20), (x - 6, y - 14)], IRON[2], O)
    p.p([(x + 6, y - 22), (x + 12, y - 22), (x + 14, y - 16), (x + 8, y - 14)], IRON[1], O)
    # Skull-faced orc head, spiked iron crown, soulfire eyes.
    p.p([(x - 8, y - 34), (x + 6, y - 34), (x + 7, y - 24), (x + 2, y - 20), (x - 6, y - 20), (x - 9, y - 26)], BONE[2], O)
    p.r((x - 6, y - 30, x - 4, y - 28), ramp[2])
    p.r((x, y - 30, x + 2, y - 28), ramp[2])
    p.p([(x - 6, y - 21), (x - 7, y - 25), (x - 5, y - 24)], BONE[3])
    p.p([(x + 1, y - 21), (x + 2, y - 25), (x + 3, y - 23)], BONE[3])
    p.l([(x - 9, y - 34), (x + 7, y - 34)], IRON[2], 2)
    for k in range(4):
        cx = x - 8 + k * 5
        p.p([(cx - 1, y - 35), (cx + 1, y - 41 - (k % 2) * 3), (cx + 3, y - 35)], IRON[3], O)
    # Arm gripping the pole.
    p.l([(x - 6, y - 14), (x - 6, y - 4)], IRON[2], 3)


def wyrm(frame, action='walk'):
    image = Image.new('RGBA', (SIZE, SIZE))
    p = Pixels(image, X0, Y0)
    enraged = action == 'walk_enraged'
    q = frame * math.tau / 12
    walking = action in ('walk', 'walk_enraged')
    bob = round(math.sin(q * 2) * 1.5) if walking else 0
    neck_x, neck_y, jaw, glow, wing_raise, banner = 0.0, 0.0, 2 + (frame % 3 == 0) * 2, 1 + enraged, .2 + .3 * enraged, 0.0
    if action == 'soulfire':
        t = frame / 11
        if t < .5:
            neck_x, neck_y, jaw = 10 * t * 2, -12 * t * 2, 4 + 6 * t * 2
        else:
            k = (t - .5) * 2
            neck_x, neck_y, jaw = 10 - 22 * k, -12 + 22 * k, 12
            # The breath itself is drawn by the board from the jaws to the real target.
        glow = 2
    elif action == 'raise_dead':
        t = frame / 11
        neck_x, neck_y, jaw, glow, wing_raise, banner = 4, -16 * min(1, t * 2), 10, 2, 1.0, 1.0
    body_y = bob
    # Far wing first, then far legs and tail.
    wing(p, (130, 108 + body_y), wing_raise, q)
    for hip, offset in (((118, 150 + body_y), math.pi), ((196, 152 + body_y), 0)):
        leg(p, hip, q + offset if walking else math.pi / 2, False, body_y)
    # S-curved spiked tail ending in a soulfire tip.
    tail = [(206, 146 + body_y)]
    for k in range(1, 9):
        swing = math.sin(q - k * .5) * (k * .7) if walking else math.sin(k * .4) * 2
        rise = -math.sin(k / 8 * math.pi) * 14
        tail.append((206 + k * 5.5, 146 + body_y + k * 5 + rise + swing))
    for k in range(len(tail) - 1):
        bone(p, tail[k], tail[k + 1], max(3, 10 - k))
        x, y = tail[k]
        if k % 2 == 0:
            knob(p, x, y, max(2, 6 - k // 2))
            p.p([(x - 2, y - 3), (x + 1, y - 9 + k // 2), (x + 3, y - 3)], BONE[2], O)
    tx, ty = tail[-1]
    p.p([(tx - 2, ty - 3), (tx + 12, ty + 2), (tx - 1, ty + 6)], BONE[3], O)
    flame(p, tx + 6, ty, 9 + (frame % 3) * 2, lean=2)
    # Spine with burning dorsal spikes, then the soulfire heart inside the ribcage.
    spine = [(206, 140 + body_y), (188, 130 + body_y), (168, 125 + body_y), (148, 122 + body_y), (128, 120 + body_y), (110, 120 + body_y)]
    heart = 13 + (frame % 4 in (1, 2)) * 3 + enraged * 5 + (action in ('soulfire', 'raise_dead')) * 5
    cx, cy = 160, 152 + body_y
    p.p([(cx - heart, cy), (cx - heart * .4, cy - heart), (cx + heart * .5, cy - heart * .8), (cx + heart, cy + 2), (cx + heart * .3, cy + heart * .7), (cx - heart * .6, cy + heart * .6)], SOUL[1])
    p.p([(cx - heart * .6, cy), (cx, cy - heart * .7), (cx + heart * .5, cy), (cx, cy + heart * .5)], SOUL[2], None)
    p.p([(cx - 4, cy), (cx, cy - 5), (cx + 4, cy), (cx, cy + 4)], SOUL[3], None)
    for k in range(3):
        flame(p, cx - 10 + k * 10, cy - heart + 4, 10 + ((frame + k) % 3) * 4, lean=(k - 1))
    for k in range(8):
        x = 124 + k * 11
        top = (x, 122 + body_y + (k > 5) * 5)
        bend = 9 if k < 6 else 5
        rib = [top, (x - bend, 146 + body_y), (x - bend + 2, 170 + body_y - k), (x + 3, 178 + body_y - k * 2)]
        p.l(rib, O, 7)
        p.l(rib, BONE[2], 5)
        p.l([(top[0] - 1, top[1]), (rib[1][0] - 1, rib[1][1])], BONE[3], 2)
    p.l([(118, 176 + body_y), (150, 184 + body_y), (192, 172 + body_y)], O, 6)
    p.l([(118, 176 + body_y), (150, 184 + body_y), (192, 172 + body_y)], BONE[1], 4)
    for k in range(len(spine) - 1):
        bone(p, spine[k], spine[k + 1], 10)
    for k, (x, y) in enumerate(spine):
        h = 15 + (k % 2) * 6 + enraged * 4
        p.p([(x - 6, y - 3), (x + 4, y - h), (x + 7, y - 3)], BONE[2], O)
        p.l([(x - 2, y - 4), (x + 3, y - h + 3)], BONE[3])
        if enraged or action in ('soulfire', 'raise_dead') or (frame + k) % 3 == 0:
            flame(p, x + 2, y - h + 3, 8 + (frame + k) % 3 * 3, lean=1)
    # Pelvis and shoulder blade.
    p.p([(192, 136 + body_y), (216, 130 + body_y), (224, 150 + body_y), (206, 164 + body_y), (190, 154 + body_y)], BONE[2], O)
    p.l([(194, 138 + body_y), (214, 133 + body_y)], BONE[3], 2)
    p.r((205, 145 + body_y, 209, 149 + body_y), O)
    p.p([(102, 114 + body_y), (130, 112 + body_y), (134, 140 + body_y), (112, 148 + body_y), (98, 132 + body_y)], BONE[2], O)
    p.l([(104, 118 + body_y), (128, 116 + body_y)], BONE[3], 2)
    rider(Scaled(image, X0, Y0, (138, 104 + body_y), 1.3), 138, 104 + body_y, q, banner)
    # Thick neck S-curve up to the skull.
    head = (46 - neck_x, 80 + neck_y + round(math.sin(q) * 2) * walking)
    neck = [(108, 122 + body_y)]
    for k in range(1, 7):
        t = k / 6
        neck.append((108 + (head[0] + 22 - 108) * t, 122 + body_y + (head[1] + 4 - 122 - body_y) * t - math.sin(t * math.pi) * 12))
    for k in range(len(neck) - 1):
        bone(p, neck[k], neck[k + 1], 12 - k)
    for k in range(len(neck) - 1):
        x, y = neck[k]
        knob(p, x, y, 5 - k // 2)
        p.p([(x - 3, y - 5), (x + 1, y - 15 + k), (x + 4, y - 5)], BONE[2], O)
    skull(Scaled(image, X0, Y0, head, 1.35), head[0], head[1], jaw, glow)
    # Near legs and the folded near wing in front.
    for hip, offset in (((108, 146 + body_y), 0), ((198, 150 + body_y), math.pi)):
        leg(p, hip, q + offset if walking else 0, True, body_y)
    wing(p, (124, 116 + body_y), wing_raise * .6, q + 1, near=True)
    if action == 'raise_dead':
        t = frame / 11
        for k in range(10):
            a = k * math.tau / 10 + t * 2
            x, y = 150 + math.cos(a) * 70, GROUND - 2 + math.sin(a) * 10
            p.r((x, y, x + 1, y), SOUL[2 + k % 2])
        for k in range(4):
            x = 60 + k * 50
            rise = (frame * 6 + k * 13) % 40
            flame(p, x, GROUND - rise, 8, lean=(k % 2) * 2 - 1)
    return image


def death(frame):
    """Collapse, then an authored bone heap as the soulfire gutters out."""
    if frame < 8:
        t = frame / 7
        pose = wyrm(3, 'walk')
        image = Image.new('RGBA', (SIZE, SIZE))
        shift = round(t * t * 34)
        image.alpha_composite(pose.crop((0, 0, SIZE, SIZE - shift)), (0, shift))
        return _dim(image, t * .6)
    t = (frame - 8) / 7
    image = Image.new('RGBA', (SIZE, SIZE))
    p = Pixels(image, X0, Y0)
    # Scattered long bones settle into a mound.
    heap = ((96, 214, 150, 206), (120, 220, 176, 198), (150, 214, 208, 204), (170, 220, 226, 210),
            (110, 206, 138, 188), (186, 206, 214, 186), (140, 200, 166, 182), (204, 214, 236, 200),
            (128, 216, 160, 214), (160, 208, 192, 190), (92, 220, 120, 212), (176, 196, 196, 176))
    settle = round((1 - t) * 4)
    for k, (x1, y1, x2, y2) in enumerate(heap):
        bone(p, (x1, y1 + settle), (x2, y2 + settle), 6 if k % 3 else 8, DARK if k % 2 else BONE)
    for k in range(6):
        x = 132 + k * 11
        rib = [(x, 196 + settle), (x - 7, 184 + settle), (x - 2, 172 + settle)]
        p.l(rib, O, 6)
        p.l(rib, BONE[2], 4)
    # A wing bone and the rider's broken banner jut from the pile.
    bone(p, (196, 196 + settle), (228, 150 + settle), 6)
    bone(p, (228, 150 + settle), (240, 136 + settle), 3)
    p.l([(118, 214), (84, 168)], O, 4)
    p.l([(118, 214), (84, 168)], IRON[2], 2)
    p.p([(84, 168), (66, 174), (72, 182), (86, 178)], BANNER[0], O)
    # The skull lies on its side at the front of the heap.
    skull(Scaled(image, X0, Y0, (78, 206), 1.35), 78, 206 + settle, 3, 0, DARK)
    # Last soulfire embers rise and wink out.
    for k in range(6):
        if (k + frame) % 3 == 0 and t < .85:
            flame(p, 110 + k * 18, 200 - round(t * 20) - (k % 2) * 6, max(3, round(9 * (1 - t))))
    return image


def _dim(image, amount):
    """Soulfire fades to ash and bones lose their colour as the wyrm dies."""
    out = image.copy()
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if g > r + 30 and g > b:
                v = (r + g + b) // 3
                px[x, y] = (int(r + (v - r) * amount), int(g + (v - g) * amount), int(b + (v - b) * amount), 255)
            else:
                px[x, y] = (int(r * (1 - .25 * amount)), int(g * (1 - .25 * amount)), int(b * (1 - .2 * amount)), 255)
    return out


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frames(name, count):
    if name == 'death':
        return [death(i) for i in range(count)]
    return [wyrm(i, name) for i in range(count)]


def export(animations):
    for name, _, images, _ in animations:
        for image in images:
            box = image.getbbox()
            if box is None or box[0] < 1 or box[1] < 1 or box[2] > SIZE - 1 or box[3] > SIZE - 1:
                raise ValueError(f'{name} needs more native margin: {box}')
    width = max(len(images) for _, _, images, _ in animations)
    sheet = Image.new('RGBA', (SIZE * width, SIZE * len(animations)))
    entries = []
    for row, (name, fps, images, loop) in enumerate(animations):
        for col, image in enumerate(images):
            sheet.alpha_composite(image, (col * SIZE, row * SIZE))
            entries.append((row, col))
    sheet_path = OUT / f'{KIND}.png'
    still = OUT / f'{KIND}_still.png'
    sheet.save(sheet_path, optimize=True)
    animations[0][2][0].save(still, optimize=True)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(entries) + 2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{KIND}.png" id="1_sheet"]', '']
    for index, (row, col) in enumerate(entries):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]', 'atlas = ExtResource("1_sheet")',
                  f'region = Rect2({col * SIZE}, {row * SIZE}, {SIZE}, {SIZE})', '']
    lines += ['[resource]', 'animations = [']
    offset = 0
    for row, (name, fps, images, loop) in enumerate(animations):
        lines += ['{', '"frames": [']
        for index in range(len(images)):
            lines += ['{', '"duration": 1.0,', f'"texture": SubResource("Frame_{offset + index}")', '},' if index + 1 < len(images) else '}']
        lines += ['],', f'"loop": {str(loop).lower()},', f'"name": &"{name}",', f'"speed": {fps:.12f}', '},' if row + 1 < len(animations) else '}']
        offset += len(images)
    lines += [']', '']
    resource = OUT / f'{KIND}.tres'
    resource.write_text('\n'.join(lines))
    manifest = {
        'authoring': 'Original local integer-coordinate pixel geometry on an articulated joint rig through the shared Pixels primitive; no sampled art, model output, raster rotation or translucency.',
        'identity': 'Colossal skeletal dragon: horned dragon skull with soulfire eyes and jaws, S-curved spiked neck, open ribcage around a burning green soul-heart, spiked spine and tail vertebrae, four clawed legs, tattered bone wings, and a lich orc warlord rider with a spiked crown and soulfire war banner.',
        'generator': 'tools/author_dreadmaw.py', 'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_dreadmaw.py',
        'frame_size': [SIZE, SIZE], 'sheet_size': list(sheet.size), 'layout': 'one animation per row',
        'base_anchor': [.5, (GROUND + Y0) / SIZE], 'source_faces_left': True,
        'alpha': 'binary 0/255', 'camera': 'elevated three-quarter left-facing; upper-left highlights',
        'sheet_sha256': digest(sheet_path), 'still': str(still.relative_to(ROOT)), 'still_sha256': digest(still),
        'sprite_frames_sha256': digest(resource),
        'animations': [{'name': name, 'fps': fps, 'frame_count': len(images), 'duration_seconds': len(images) / fps,
                        'loop': loop, 'atlas_row': row, 'alpha_bounds': [list(image.getbbox()) for image in images]}
                       for row, (name, fps, images, loop) in enumerate(animations)],
    }
    (OUT / f'{KIND}.json').write_text(json.dumps(manifest, indent=2) + '\n')


def preview(animations):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    width = max(len(images) for _, _, images, _ in animations)
    sheet = Image.new('RGBA', (SIZE * width, SIZE * len(animations)), (39, 48, 43, 255))
    for row, (_, _, images, _) in enumerate(animations):
        for col, image in enumerate(images):
            sheet.alpha_composite(image, (col * SIZE, row * SIZE))
    sheet.save(PREVIEW / 'contact.png')


def main():
    animations = [(name, fps, frames(name, count), loop) for name, count, fps, loop in SPEC]
    export(animations)
    preview(animations)
    print(f'Exported {KIND}; contact sheet in {PREVIEW}')


if __name__ == '__main__':
    main()
