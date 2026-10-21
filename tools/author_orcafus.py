#!/usr/bin/env python3
"""Author Grand Mage Orcafus, a gliding late-game boss mage (Pillow only).

Run: python3 tools/author_orcafus.py (requires Pillow).
Integer Pillow geometry through the shared Pixels primitive; no sampled art,
raster rotation, antialiasing or translucency. The staff is the centrepiece:
banded dark wood, a gold crescent cradling a floating crystal that changes
colour with each spell, orbiting motes and trailing ribbons.
Native PNG, SpriteFrames and provenance go to assets/enemies/animations;
review sheets go to /tmp/gorcs-orcafus.
"""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image

from author_enemy_sprites import O, Pixels

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
PREVIEW = Path('/tmp/gorcs-orcafus')
KIND = 'grand_mage_orcafus'
SIZE = 176
# Local ground line; every frame is drawn HEADROOM pixels lower on the canvas.
GROUND = 138
HEADROOM = 16
ROBE = ('#1b1830', '#2c2752', '#463c82', '#6f62b3')
TRIM = ('#5a4222', '#9a7433', '#d8b052', '#ffe9a0')
SKIN = ('#2c3a2c', '#4b6244', '#748d60', '#a3b985')
BEARD = ('#7f827e', '#adb1aa', '#d8dcd3', '#fbfbf6')
WOOD = ('#24180f', '#43301f', '#6c4d32', '#9b7148')
CRYSTAL = {
    'arcane': ('#1d4561', '#2f80aa', '#6ccbec', '#dcfaff'),
    'fire': ('#6e2414', '#c1471c', '#f08a2c', '#ffe08a'),
    'void': ('#341a55', '#653597', '#a271e0', '#ecd9ff'),
    'gold': ('#5a4222', '#b98d34', '#f0cc62', '#fff6c8'),
    'haste': ('#5c5a1c', '#a7a32c', '#e8e45a', '#fffbd0'),
}
DUST = ('#6d6658', '#9a917d', '#c7bea6')
RIBBON = ('#5c1f35', '#923250', '#c95677')
PAGE = ('#8c7c5c', '#e2d4b0', '#f4ead0')
# Seconds and frames per animation; casts match the spellbook timings.
SPEC = (
    ('walk', 12, 9, True), ('nullify', 12, 12 / 1.0, True), ('nullify_strike', 8, 8 / .6, False),
    ('fireball', 12, 12 / 1.4, False), ('portal', 12, 12 / 2.4, False), ('haste', 12, 12 / 1.8, False),
    ('barrier', 12, 12 / 1.8, False), ('death', 24, 7, False),
)


def pix(image, x=0, y=0):
    return Pixels(image, x, y + HEADROOM)


def glow_orb(p, x, y, r, ramp):
    pts = [(x + math.cos(a * math.pi / 4) * r, y + math.sin(a * math.pi / 4) * r) for a in range(8)]
    p.p(pts, ramp[1], ramp[0])
    p.p([(x - r * .6, y - r * .2), (x - r * .2, y - r * .7), (x + r * .3, y - r * .3), (x, y + r * .2)], ramp[2], None)
    p.r((x - r * .45, y - r * .45, x - r * .45 + 1, y - r * .45 + 1), ramp[3])


def crystal(p, x, y, ramp, flare=0):
    """The staff's floating crystal: a tall faceted gem with a hot core and light rays."""
    h = 12 + flare
    p.p([(x, y - h), (x + 6, y - 3), (x + 4, y + 7), (x, y + 10), (x - 4, y + 7), (x - 6, y - 3)], ramp[1], O)
    p.p([(x, y - h + 1), (x - 5, y - 3), (x - 3, y + 6), (x, y + 3)], ramp[2], None)
    p.p([(x + 1, y - h + 4), (x + 4, y - 2), (x + 1, y + 2)], ramp[0], None)
    p.l([(x, y - h + 2), (x, y + 8)], ramp[3])
    p.r((x - 2, y - 4, x - 1, y - 2), '#ffffff')
    for k in range(4 + flare):
        a = k * math.tau / (4 + flare) + math.pi / 4
        inner, outer = 9 + flare, 11 + flare * 2
        p.l([(x + math.cos(a) * inner, y + math.sin(a) * inner), (x + math.cos(a) * outer, y + math.sin(a) * outer)], ramp[3 if k % 2 else 2])


def staff(p, base, top, ramp, phase, flare=0):
    """Banded spiral-wrapped shaft, curled gold crescent, floating crystal and motes."""
    bx, by = base
    tx, ty = top
    p.l([base, top], O, 6)
    p.l([base, top], WOOD[1], 4)
    p.l([(bx - 1, by), (tx - 1, ty)], WOOD[2], 2)
    p.l([(bx - 2, by), (tx - 2, ty)], WOOD[3])
    length = math.hypot(tx - bx, ty - by) or 1
    ux, uy = (tx - bx) / length, (ty - by) / length
    nx, ny = -uy, ux
    # Gold spiral wrap up the upper shaft, then two heavy bands.
    for k in range(10):
        t = .45 + k * .05
        cx, cy = bx + (tx - bx) * t, by + (ty - by) * t
        side = 1 if k % 2 else -1
        p.l([(cx + nx * 2 * side, cy + ny * 2 * side), (cx - nx * 2 * side + ux * 2, cy - ny * 2 * side + uy * 2)], TRIM[2])
    for t in (.32, .96):
        cx, cy = bx + (tx - bx) * t, by + (ty - by) * t
        p.l([(cx + nx * 3, cy + ny * 3), (cx - nx * 3, cy - ny * 3)], TRIM[1], 3)
        p.l([(cx + nx * 3, cy + ny * 3 - 1), (cx - nx * 2, cy - ny * 2 - 1)], TRIM[3])
    p.r((bx - 2, by - 2, bx + 1, by + 1), TRIM[1])
    # Curled gold crescent whose horns cup the floating crystal.
    cx, cy = tx, ty
    for side in (1, -1):
        hx, hy = cx + nx * 11 * side + ux * 9, cy + ny * 11 * side + uy * 9
        p.p([(cx + nx * 3 * side, cy + ny * 3 * side), (cx + nx * 9 * side + ux * 2, cy + ny * 9 * side + uy * 2),
             (hx, hy), (hx - nx * 3 * side + ux * 2, hy - ny * 3 * side + uy * 2),
             (cx + nx * 6 * side + ux * 5, cy + ny * 6 * side + uy * 5), (cx + nx * 2 * side + ux * 2, cy + ny * 2 * side + uy * 2)], TRIM[1], O)
        p.l([(cx + nx * 4 * side, cy + ny * 4 * side), (cx + nx * 9 * side + ux * 3, cy + ny * 9 * side + uy * 3), (hx, hy)], TRIM[3])
        p.r((hx - 1, hy - 1, hx, hy), ramp[2])
    p.p([(cx - nx * 3, cy - ny * 3), (cx + nx * 3, cy + ny * 3), (cx + ux * 4, cy + uy * 4)], TRIM[2], O)
    gx, gy = tx + ux * 14, ty + uy * 14 + math.sin(phase) * 1.5
    crystal(p, gx, gy, ramp, flare)
    for k in range(3):
        a = phase * 1.5 + k * math.tau / 3
        mx, my = gx + math.cos(a) * 14, gy + math.sin(a) * 5
        p.r((mx, my, mx + 1, my + 1), ramp[3] if k else '#ffffff')


def rune(p, x, y, color, kind):
    shapes = (
        [(x - 2, y), (x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)],
        [(x - 2, y - 2), (x + 2, y - 2), (x, y + 2), (x - 2, y - 2)],
        [(x, y - 2), (x, y + 2)],
    )
    p.l(shapes[kind % 3], color)
    if kind % 3 == 2:
        p.l([(x - 2, y), (x + 2, y)], color)


def orbit_runes(image, phase, front, color=None):
    p = pix(image)
    for k in range(2):
        a = phase * .9 + k * math.pi
        if (math.sin(a) > 0) != front:
            continue
        rune(p, 84 + math.cos(a) * 40, 100 + math.sin(a) * 8, color or CRYSTAL['arcane'][3 if front else 2], k)


def halo(p, phase, ramp, scale=1.0):
    """The aura: a slowly turning gold rune ring behind the Grand Mage's head."""
    cx, cy, r = 86, 44, 21 * scale
    for k in range(40):
        a = k * math.tau / 40 + phase * .25
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        p.r((x, y, x, y), TRIM[2] if k % 2 else TRIM[1])
    for k in range(6):
        a = k * math.tau / 6 - phase * .25
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        rune(p, x, y, TRIM[3], k)
    for k in range(16):
        a = k * math.tau / 16 - phase * .4
        if k % 2:
            x, y = cx + math.cos(a) * (r - 4), cy + math.sin(a) * (r - 4)
            p.r((x, y, x, y), ramp[1])


def tome(p, phase, ramp, open_amount=0.0):
    """A floating open grimoire attending the far hand; pages flare while casting."""
    bob = math.sin(phase + 1.3) * 2
    x, y = 120, 84 + bob
    lift = round(open_amount * 3)
    p.p([(x - 9, y - 1), (x, y + 2), (x + 9, y - 1), (x + 9, y + 6), (x, y + 9), (x - 9, y + 6)], RIBBON[0], O)
    p.p([(x - 8, y - 2 - lift), (x - 1, y), (x - 1, y + 7), (x - 8, y + 4)], PAGE[1])
    p.p([(x + 1, y), (x + 8, y - 2 - lift), (x + 8, y + 4), (x + 1, y + 7)], PAGE[2])
    p.l([(x - 6, y + 1), (x - 3, y + 2)], ramp[2] if open_amount else PAGE[0])
    p.l([(x - 6, y + 3), (x - 3, y + 4)], PAGE[0])
    p.l([(x + 3, y + 1), (x + 6, y)], ramp[2] if open_amount else PAGE[0])
    p.l([(x + 3, y + 3), (x + 6, y + 2)], PAGE[0])
    p.r((x - 1, y, x, y + 7), TRIM[1])
    if open_amount:
        for k in range(3):
            a = phase * 2 + k * math.tau / 3
            p.r((x + math.cos(a) * 6, y - 6 + math.sin(a) * 3, x + math.cos(a) * 6, y - 6 + math.sin(a) * 3), ramp[3])


def body(image, phase, lift, pose, crystal_ramp, flare=0, raise_staff=0.0, strike=0.0, spread=0.0):
    """One left-facing Grand Mage frame; everything glides on `lift`."""
    p = pix(image, 0, -lift)
    sway = math.sin(phase) * 2
    halo(p, phase, crystal_ramp, 1.0 + flare * .04)
    # Crimson-lined cape streaming back from the gliding mage.
    s2 = round(sway * 1.5)
    p.p([(76, 64), (104, 62), (116, 80), (124 + s2, 102), (132 + s2, 124), (124 + s2, 121), (120 + s2, 131), (112, 125), (104, 132), (96, 124)], ROBE[0], O)
    p.l([(106, 66), (118, 86), (126 + s2, 106), (130 + s2, 122)], RIBBON[1], 2)
    p.l([(104, 132), (112, 125), (120 + s2, 131), (124 + s2, 121), (132 + s2, 124)], TRIM[1])
    # Far arm in a bell sleeve; raised palm glows while casting.
    fx, fy = 106 + spread * 8, 96 - spread * 18
    p.p([(96, 72), (104, 74), (fx + 6, fy - 4), (fx + 8, fy + 6), (fx - 6, fy + 8), (94, 88)], ROBE[1], O)
    p.l([(fx - 5, fy + 7), (fx + 7, fy + 5)], TRIM[2], 2)
    p.p([(fx - 1, fy + 6), (fx + 4, fy + 5), (fx + 5, fy + 10), (fx + 1, fy + 11), (fx - 2, fy + 9)], SKIN[1], O)
    tome(p, phase, crystal_ramp, spread)
    if spread > .3:
        glow_orb(p, fx + 2, fy + 1, 3, crystal_ramp)
    # Robe: flared starry skirt; the tattered hem lifts into spell-light wisps.
    hem = [(54, 126), (60, 131 + round(sway)), (66, 127), (73, 132 - round(sway)), (80, 128), (87, 132 + round(sway)), (94, 128), (101, 131), (108, 127)]
    p.p([(68, 74), (100, 72), (106, 98), (108, 127)] + hem[::-1] + [(58, 104)], ROBE[1], O)
    p.p([(69, 78), (80, 76), (78, 102), (72, 127), (58, 126), (61, 104)], ROBE[2], None)
    p.l([(68, 78), (61, 104), (56, 125)], ROBE[3])
    p.p([(80, 78), (90, 78), (95, 128), (76, 129)], ROBE[0])
    p.l([(80, 78), (76, 129)], TRIM[2], 2)
    p.l([(90, 78), (95, 128)], TRIM[1], 2)
    for k, (x, y) in enumerate(((84, 108), (88, 118), (82, 122), (66, 112), (100, 110), (62, 120), (70, 100))):
        p.r((x, y, x, y), TRIM[3] if (k + int(phase * 2)) % 3 else crystal_ramp[3])
    p.l(hem, TRIM[2], 2)
    for k, x in enumerate((62, 80, 98)):
        w = math.sin(phase * 2 + k) * 2
        p.l([(x, 131), (x + w, 135), (x - w + 2, 139)], crystal_ramp[1 + k % 2])
    # Gold sash dipping to a clasp, with hanging talismans.
    p.p([(64, 97), (84, 101), (102, 95), (103, 100), (84, 106), (64, 102)], TRIM[1], O)
    p.l([(65, 98), (84, 102), (101, 96)], TRIM[3])
    p.r((82, 101, 85, 104), TRIM[3])
    for k, x in enumerate((72, 96)):
        t = math.sin(phase + k) * 1.5
        p.l([(x, 103), (x + t, 112)], TRIM[0])
        p.r((x + t - 1, 112, x + t + 1, 115), crystal_ramp[2])
    # Gold V collar with a chest gem.
    p.p([(68, 70), (100, 70), (86, 88), (82, 88)], ROBE[2], O)
    p.l([(68, 70), (84, 88), (100, 70)], TRIM[2], 2)
    glow_orb(p, 84, 82, 3, crystal_ramp)
    # Curled, gold-rimmed pauldrons.
    for cx, flip in ((64, -1), (102, 1)):
        p.p([(cx - 8, 72), (cx - 6, 64), (cx, 60), (cx + 7, 63), (cx + 9, 71), (cx + 2, 77)], ROBE[2] if flip < 0 else ROBE[1], O)
        p.l([(cx - 7, 70), (cx - 5, 64), (cx, 61), (cx + 6, 63)], TRIM[2], 2)
        tip = cx + flip * 8
        p.p([(cx + flip * 3, 62), (tip, 52), (tip + flip * 2, 50), (cx + flip * 7, 60)], TRIM[1], O)
        p.r((tip, 52, tip, 52), TRIM[3])
    head(p, phase, crystal_ramp, flare)
    # Near arm in a bell sleeve gripping the staff (raised for casts).
    hx = 50 - raise_staff * 2 + strike * 8
    hy = 98 - raise_staff * 24 + strike * 12
    tilt = strike * 26
    base = (hx - 3 + tilt * .2, min(GROUND + lift - 2, hy + 38 - raise_staff * 4))
    top = (hx + 3 - tilt, hy - 64 + raise_staff * 22 + strike * 22)
    staff(p, base, top, crystal_ramp, phase, flare)
    p.p([(62, 70), (70, 74), (hx + 9, hy - 4), (hx + 8, hy + 8), (hx - 2, hy + 10), (hx - 4, hy + 2)], ROBE[2], O)
    p.l([(hx - 3, hy + 8), (hx + 8, hy + 7)], TRIM[2], 2)
    p.p([(hx - 4, hy + 2), (hx + 3, hy), (hx + 5, hy + 6), (hx + 1, hy + 9), (hx - 4, hy + 7)], SKIN[2], O)
    p.l([(hx - 3, hy + 4), (hx + 3, hy + 3)], SKIN[3])
    return top


def head(p, phase, crystal_ramp, flare):
    # Swept-back hood; the face sits in its shadow under a heavy brow.
    p.p([(62, 60), (60, 48), (64, 38), (72, 30), (84, 26), (96, 28), (108, 18), (104, 32), (102, 46), (100, 60)], ROBE[1], O)
    p.p([(66, 44), (72, 34), (84, 29), (95, 30), (104, 21), (100, 30), (88, 32), (76, 36)], ROBE[3], None)
    p.l([(62, 60), (60, 48), (64, 38), (72, 31), (84, 27)], TRIM[2], 2)
    p.p([(65, 58), (65, 46), (71, 38), (82, 35), (91, 38), (94, 50), (92, 60)], ROBE[0])
    p.p([(64, 48), (76, 44), (86, 46), (89, 54), (85, 62), (72, 64), (62, 57)], SKIN[2], O)
    p.p([(64, 49), (72, 46), (75, 50), (66, 53)], SKIN[3], None)
    p.l([(63, 50), (72, 47), (82, 50)], SKIN[0], 2)
    eye = crystal_ramp[3] if flare or int(phase * 2) % 6 else crystal_ramp[2]
    for x in (65, 76):
        p.r((x, 50, x + 3, 52), eye)
        p.r((x + 1, 51, x + 2, 51), '#ffffff')
    # Eye-light trails sweep back under the hood: the aura never rests.
    trail = 3 + flare
    p.l([(69, 51), (69 + trail, 50)], crystal_ramp[2])
    p.l([(80, 51), (80 + trail, 49)], crystal_ramp[2])
    p.p([(59, 54), (64, 52), (66, 56), (61, 57)], SKIN[1], O)
    p.l([(66, 59), (72, 60), (78, 59)], SKIN[0])
    # Narrow braided beard below the mouth; tusks rise beside it.
    sway = math.sin(phase - .4) * 2
    p.p([(66, 61), (85, 61), (84, 70), (81, 80), (78 + sway, 92), (76 + sway, 104), (73 + sway, 92), (70, 80), (67, 70)], BEARD[2], O)
    p.l([(69, 64), (72, 78), (75 + sway, 92), (76 + sway, 101)], BEARD[3])
    p.l([(80, 63), (78, 76), (77 + sway, 88)], BEARD[1])
    p.l([(74, 66), (75, 80)], BEARD[1])
    for y in (82, 94):
        k = (y - 70) / 34
        p.l([(72 + sway * k, y), (79 + sway * k, y)], TRIM[2], 2)
        p.r((75 + sway * k, y, 75 + sway * k, y), TRIM[3])
    p.l([(62, 62), (67, 60), (75, 62), (83, 60), (88, 62)], BEARD[3], 2)
    p.l([(62, 62), (60, 70), (61, 74)], BEARD[2], 2)
    p.l([(88, 62), (89, 70), (88, 74)], BEARD[2], 2)
    for x, lean in ((63, -1), (86, 1)):
        p.p([(x, 63), (x + lean * 2, 57), (x + lean * 3, 54), (x + lean * 4, 56), (x + lean * 3, 62)], BEARD[3], O)


def ground_circle(image, phase, ramp, scale=1.0):
    p = pix(image)
    for k in range(28):
        a = phase * .5 + k * math.tau / 28
        if k % 7 == 0:
            continue
        x, y = 84 + math.cos(a) * 28 * scale, GROUND - 2 + math.sin(a) * 6 * scale
        p.r((x, y, x + (1 if k % 2 else 0), y), ramp[2] if k % 2 else ramp[1])
    for k in range(4):
        a = -phase * .5 + k * math.tau / 4
        rune(p, 84 + math.cos(a) * 20 * scale, GROUND - 2 + math.sin(a) * 4 * scale, ramp[3], k)


def glide(frame):
    image = Image.new('RGBA', (SIZE, SIZE))
    phase = frame * math.tau / 12
    lift = 4 + round(math.sin(phase) * 2)
    orbit_runes(image, phase, False)
    ground_circle(image, phase, CRYSTAL['arcane'])
    body(image, phase, lift, 'walk', CRYSTAL['arcane'])
    orbit_runes(image, phase, True)
    return image


def cast(spell, frame, count):
    image = Image.new('RGBA', (SIZE, SIZE))
    t = frame / max(1, count - 1)
    phase = frame * math.tau / 12
    lift = 6
    ramp = {'nullify': CRYSTAL['void'], 'nullify_strike': CRYSTAL['void'], 'fireball': CRYSTAL['fire'],
            'portal': CRYSTAL['void'], 'haste': CRYSTAL['haste'], 'barrier': CRYSTAL['gold']}[spell]
    raise_staff, strike, spread, flare = 0.0, 0.0, 0.0, 0
    if spell == 'nullify':
        raise_staff, spread, flare = 1.0, .6 + .2 * math.sin(phase), 2 + frame % 2
        lift = 8 + round(math.sin(phase))
    elif spell == 'nullify_strike':
        raise_staff = max(0.0, 1 - t * 3)
        strike = min(1.0, t * 2.5)
        lift = max(2, 8 - frame * 2)
        flare = 3 if frame < 4 else 1
    elif spell == 'fireball':
        raise_staff = min(1.0, t * 1.6) if t < .75 else 1 - (t - .75) * 3
        strike = 0.0 if t < .75 else (t - .75) * 2.4
        flare = min(4, frame // 2)
    elif spell == 'portal':
        raise_staff, spread, flare = .7, min(1.0, t * 2), 2
    elif spell == 'haste':
        raise_staff, spread, flare = .8 + .2 * math.sin(phase * 2), .5, 1 + frame % 3
    elif spell == 'barrier':
        raise_staff, flare = .3, 1 + min(3, frame // 3)
    orbit_runes(image, phase * 2, False, ramp[2])
    ground_circle(image, phase * 2, ramp, 1.0 + (0.3 if spell in ('nullify', 'portal') else 0.0))
    top = body(image, phase, lift, spell, ramp, flare, raise_staff, strike, spread)
    orbit_runes(image, phase * 2, True, ramp[3])
    p = pix(image)
    if spell == 'fireball' and frame >= 3:
        # A growing fireball on the crystal, hurled forward on the last frames.
        r = min(5, 1 + frame // 2)
        fx, fy = top[0] - 9, top[1] - 6 - lift
        if t > .75:
            fx -= (t - .75) * 80
        glow_orb(p, fx, fy, r, CRYSTAL['fire'])
    if spell == 'nullify_strike' and frame >= 3:
        # Shockwave ripples where the staff meets the ground.
        r = (frame - 2) * 6
        for k in range(10):
            a = k * math.tau / 10
            x, y = 48 + math.cos(a) * r, GROUND + math.sin(a) * r * .25
            if 1 <= x < SIZE - 1:
                p.r((x, y - 1, x + 1, y), CRYSTAL['void'][3 if k % 2 else 2])
    if spell == 'barrier':
        r = 6 + frame * 2
        for k in range(12):
            a = k * math.tau / 12 + phase
            x, y = 80 + math.cos(a) * min(30, r), 92 - lift + math.sin(a) * min(42, r * 1.4)
            p.r((x, y, x + 1, y + 1), CRYSTAL['gold'][3 if k % 3 else 2])
    if spell == 'haste':
        for k in range(4):
            y = 70 + k * 14
            off = (frame * 5 + k * 9) % 24
            p.l([(112 + off, y), (120 + off, y)], CRYSTAL['haste'][2])
    return image


def death(frame):
    """Final staff swing and bolt, a frozen beat, then a slow blow-away into dust."""
    if frame < 6:
        image = cast('nullify_strike', min(7, frame + 2), 8)
        if frame in (2, 3):
            p = pix(image)
            p.l([(40, 20), (36, 8), (42, 2)], '#ffffff', 2)
        return image
    still = cast('nullify_strike', 7, 8)
    grey = still.copy()
    px = grey.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a:
                v = (r + g + b) // 3
                px[x, y] = (v + 24, v + 20, v + 10, 255) if frame >= 8 else (r, g, b, a)
    if frame < 10:
        return grey
    # Rows dissolve top-down; each removed pixel drifts right/up as dust and fades.
    progress = (frame - 10) / 13
    top, bottom = grey.getbbox()[1], grey.getbbox()[3]
    cut = top + (bottom - top + 12) * progress
    image = Image.new('RGBA', (SIZE, SIZE))
    src = grey.load()
    out = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3] == 0:
                continue
            if y > cut:
                out[x, y] = src[x, y]
                continue
            seed = (x * 73856093 ^ y * 19349663) & 1023
            if seed % 5:
                continue
            age = (cut - y) / 10
            if age > 2.4:
                continue
            dx = round(age * (6 + seed % 7))
            dy = round(-age * (2 + seed % 4) + math.sin(seed + age * 3) * 1.5)
            nx, ny = x + dx, y + dy
            if 0 <= nx < SIZE and 0 <= ny < SIZE:
                out[nx, ny] = tuple(int(DUST[min(2, int(age))][i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    return image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frames(name, count):
    if name == 'walk':
        return [glide(i) for i in range(count)]
    if name == 'death':
        return [death(i) for i in range(count)]
    return [cast(name, i, count) for i in range(count)]


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
        'authoring': 'Original local integer-coordinate pixel geometry through the shared Pixels primitive; no sampled art, model output, raster rotation or translucency.',
        'identity': 'Gliding elder orc archmage: indigo robe and trailing cape, gold-rimmed mantle and hood with floating rune stones, glowing eyes, long braided beard; banded staff with a gold crescent cradling a floating spell-coloured crystal, orbiting motes and ribbons; runes orbit him and a rune circle turns beneath him.',
        'generator': 'tools/author_orcafus.py', 'generator_sha256': digest(Path(__file__)),
        'reproduce': 'python3 tools/author_orcafus.py',
        'frame_size': [SIZE, SIZE], 'sheet_size': list(sheet.size), 'layout': 'one animation per row',
        'base_anchor': [.5, (GROUND + HEADROOM) / SIZE], 'source_faces_left': True,
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
