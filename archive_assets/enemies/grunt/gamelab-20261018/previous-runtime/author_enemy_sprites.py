#!/usr/bin/env python3
"""Reproduce seven original, locally pixel-authored enemy designs (Pillow only).

All silhouettes, faces, material clusters and articulated poses are drawn here.
Historical assets/enemies/*.png are references only and NEVER written or sampled.
Run this script to export sheets, SpriteFrames, stills and exact provenance. Review
lineups/contact sheets and a real-time animated preview are written under /tmp.
No external generator, paid service, antialiasing, image rotation or limb masks.
"""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
SIZE = 80
O = '#182322'
SK = ('#384933', '#566b3c', '#84964e', '#b8c776')
FE = ('#29383d', '#45585d', '#74898b', '#bbc9ba')
LE = ('#30291f', '#59402b', '#88613b', '#bd965a')
BO = ('#595b49', '#8f9271', '#c4c6a0', '#f0e7bd')
GO = ('#594325', '#95703b', '#cba659', '#f2d98b')
RED = ('#36282d', '#653b3e', '#a25b50', '#c88a65')
PUR = ('#282b35', '#44394e', '#70556e', '#a17d91')
KINDS = ('orcling', 'grunt', 'runner', 'brute', 'orc_chief', 'necorcmancer', 'skeleorc')
HEIGHTS = (.32, .50, .45, .70, .85, .72, .35)
FPS = {'orcling': 16, 'grunt': 12, 'runner': 20, 'brute': 9, 'orc_chief': 9, 'necorcmancer': 10, 'skeleorc': 17}
IDENTITY = {
    'orcling': 'Scrawny young scavenger; enormous swept ears, round cheek, one chipped tusk, scruffy crest.',
    'grunt': 'Stocky adult veteran; projecting square jaw, broken nose, diagonal cheek scar and leather baldric.',
    'runner': 'Lanky forward-leaning scout; long pinched face, single squint, rust headscarf and trailing ties.',
    'brute': 'Hunched iron juggernaut; broad bowl helmet, narrow recessed face, massive plated shoulders.',
    'orc_chief': 'Older barrel-chested leader; long weathered muzzle, asymmetric ivory tusks, gold circlet and grey sideburn.',
    'necorcmancer': 'Crooked hooded caster; gaunt asymmetric cheekbones, blind eye, hanging lower tusk and skull staff.',
    'skeleorc': 'Bare hollow cranium, broken asymmetric jaw, missing tooth, open ribs and exposed paired leg bones.',
}


class Pixels:
    """Integer geometry rasterized after local shoulder/pelvis counter-turn."""
    def __init__(self, image, x=0, y=0, twist=0, angle=0, pivot=(38,28)):
        self.d = ImageDraw.Draw(image)
        self.x, self.y, self.twist = x, y, twist
        self.angle, self.pivot = angle, pivot
        self.cos, self.sin = math.cos(angle), math.sin(angle)

    def point(self, x, y):
        # Counter-turn shoulder and pelvic planes around the waist before rasterizing.
        x += self.twist*(46-y)/20
        if self.angle:
            dx,dy=x-self.pivot[0],y-self.pivot[1]
            x=self.pivot[0]+dx*self.cos-dy*self.sin
            y=self.pivot[1]+dx*self.sin+dy*self.cos
        return round(x+self.x), round(y+self.y)

    def p(self, pts, color, outline=O):
        points = [self.point(x,y) for x,y in pts]
        self.d.polygon(points, fill=color)
        if outline:
            self.d.line(points + points[:1], fill=outline, width=1)

    def r(self, box, color):
        a, b, c, d = box
        if self.angle:
            self.p([(a,b),(c,b),(c,d),(a,d)],color,None)
        else:
            x1,y1=self.point(a,b)
            x2,y2=self.point(c,d)
            self.d.rectangle((min(x1,x2),y1,max(x1,x2),y2), fill=color)

    def l(self, pts, color, width=1):
        self.d.line([self.point(x,y) for x,y in pts], fill=color, width=width)


def segment(p, a, b, w1, w2, ramp):
    """Redraw a tapered anatomical segment at the current joint positions."""
    dx, dy = b[0]-a[0], b[1]-a[1]
    length = math.hypot(dx, dy) or 1
    nx, ny = -dy/length, dx/length
    points = [(a[0]+nx*w1, a[1]+ny*w1), (b[0]+nx*w2, b[1]+ny*w2),
              (b[0]-nx*w2, b[1]-ny*w2), (a[0]-nx*w1, a[1]-ny*w1)]
    p.p(points, ramp[1])
    # Broad top/left material plane rather than one-pixel noise or airbrushed edges.
    p.p([(a[0]-1,a[1]), (b[0]-1,b[1]), (b[0]-nx*w2+1,b[1]-ny*w2),
         (a[0]-nx*w1+1,a[1]-ny*w1)], ramp[2], None)
    p.l([(a[0]-nx*w1+1,a[1]-ny*w1), (b[0]-nx*w2+1,b[1]-ny*w2)], ramp[3])


def gait(q, stride):
    """Left-facing local gait: airborne foot recovers left; planted foot travels right."""
    recovery=max(0,math.sin(q))
    return math.cos(q)*stride, recovery*4, -recovery*2


def leg(p, hip, side, phase, width, armor=False, bare=False, skeleton=False, stride=5):
    q = phase + (math.pi if side else 0)
    travel,lift,knee_forward = gait(q,stride)
    foot = (hip[0]+travel-2, 68-lift-(2 if side else 0))
    knee = (hip[0]+travel*.36+knee_forward, (hip[1]+foot[1])*.5-1)
    ramp = BO if skeleton else SK if bare else FE if armor else LE
    segment(p, hip, knee, width, width*.80, ramp)
    segment(p, knee, (foot[0]+1,foot[1]-2), width*.75, width*.64, ramp)
    if skeleton:
        p.l([(knee[0]+2,knee[1]+2),(foot[0]+3,foot[1]-2)], BO[2])
        p.r((knee[0]-1,knee[1]-1,knee[0]+1,knee[1]),BO[3])
        p.p([(foot[0]-5,foot[1]),(foot[0]-4,foot[1]-3),(foot[0],foot[1]-3),
             (foot[0]+3,foot[1]-1),(foot[0]+3,foot[1]+1),(foot[0]-5,foot[1]+1)],BO[2])
        p.l([(foot[0]-4,foot[1]-2),(foot[0],foot[1]-2)],BO[3])
    else:
        toe = -2 if math.sin(q)<-.3 else 0
        p.p([(foot[0]-width-3,foot[1]+toe),(foot[0]-width-2,foot[1]-3),
             (foot[0]+width-1,foot[1]-3),(foot[0]+width+1,foot[1]),
             (foot[0]+width,foot[1]+1),(foot[0]-width-3,foot[1]+1)], LE[0] if not armor else FE[0])
        p.l([(foot[0]-width-1,foot[1]-2),(foot[0]+width-2,foot[1]-2)],LE[2] if not armor else FE[2])
        if armor:
            p.p([(knee[0]-width,knee[1]-3),(knee[0]+width-1,knee[1]-3),
                 (knee[0]+width,knee[1]+1),(knee[0]-width+1,knee[1]+2)],FE[2])
            p.l([(knee[0]-width+1,knee[1]-2),(knee[0]+1,knee[1]-2)],FE[3])


def arm(p, shoulder, side, phase, width=4, ramp=SK, reach=None):
    swing = math.cos(phase+(math.pi if side else 0))*3
    elbow = (shoulder[0]+(-3 if side else 3)+swing,shoulder[1]+9)
    hand = (shoulder[0]+(-2 if side else 3)+swing*1.6,shoulder[1]+17)
    if reach:
        elbow, hand = reach
    segment(p,shoulder,elbow,width,width*.82,ramp)
    segment(p,elbow,hand,width*.82,width*.70,ramp)
    p.p([(hand[0]-3,hand[1]-2),(hand[0]+2,hand[1]-3),(hand[0]+3,hand[1]+1),
         (hand[0],hand[1]+3),(hand[0]-3,hand[1]+1)],SK[1] if ramp!=BO else BO[1])
    p.l([(hand[0]-2,hand[1]-1),(hand[0]+1,hand[1]-1)],SK[3] if ramp!=BO else BO[3])
    return hand


def orcling_head(p):
    # Young pear-shaped skull; left ear is taller than the head, one broken tusk.
    p.p([(31,32),(20,25),(23,35),(30,39)],SK[2])
    p.p([(24,29),(27,35),(29,35)],'#727047',None)
    p.p([(43,30),(53,27),(49,35),(44,37)],SK[1])
    p.l([(45,32),(49,30)],SK[2])
    p.p([(31,26),(41,25),(47,30),(46,40),(41,46),(33,45),(28,39),(28,32)],SK[2])
    p.p([(30,31),(33,28),(39,28),(40,32),(35,34),(30,35)],SK[3],None)
    p.p([(40,34),(46,33),(45,41),(40,45),(37,42)],SK[1],None)
    p.p([(28,36),(34,34),(36,38),(34,40),(28,40)],SK[2])
    p.r((29,33,33,35),O)
    p.r((30,34,31,34),'#edd181')
    p.l([(38,32),(43,33)],SK[0],2)
    p.r((39,34,41,35),O)
    p.r((39,34,39,34),'#edd181')
    p.l([(29,41),(34,42),(40,40)],O)
    p.p([(31,42),(30,38),(32,38),(33,41)],BO[3],None)
    p.r((38,41,39,42),BO[2])
    p.p([(31,27),(32,23),(35,25),(37,21),(40,25),(43,23),(44,28),(40,28),(36,27)],SK[0])


def grunt_head(p):
    # Adult: broad flattened cranium, hanging square jaw and blunt broken nose.
    p.p([(29,24),(22,20),(22,28),(28,32)],SK[1])
    p.l([(23,23),(26,27)],SK[3])
    p.p([(44,24),(51,21),(49,29),(44,31)],SK[0])
    p.p([(29,17),(39,16),(46,20),(47,31),(43,39),(30,40),(24,35),(24,27)],SK[2])
    p.p([(28,20),(32,18),(38,18),(39,21),(32,23),(27,25)],SK[3],None)
    p.p([(40,23),(46,23),(46,31),(41,36),(37,36),(38,29)],SK[1],None)
    p.p([(25,29),(29,26),(34,27),(35,32),(30,34),(23,33),(23,30)],SK[2])
    p.l([(25,25),(31,24),(33,25)],SK[0],2)
    p.r((26,26,30,27),O)
    p.r((27,26,28,26),'#d6b65d')
    p.l([(37,24),(43,25)],SK[0],2)
    p.r((38,26,41,27),O)
    p.r((38,26,39,26),'#d6b65d')
    p.l([(25,35),(30,36),(40,34)],O,2)
    p.p([(27,37),(25,31),(27,30),(30,36)],BO[2])
    p.l([(26,32),(28,36)],BO[3])
    p.p([(38,35),(40,29),(42,30),(41,35)],BO[2])
    p.l([(40,30),(40,34)],BO[3])
    p.l([(35,28),(38,30),(40,33)],'#b8a479')
    p.r((35,28,35,29),'#d3bd86')
    p.r((32,37,37,38),SK[1])
    p.p([(30,17),(31,14),(35,16),(38,13),(39,17)],SK[0])


def runner_head(p):
    # Long narrow hooked muzzle and one visible squint, not a scaled grunt.
    p.p([(33,23),(24,20),(27,28),(32,30)],SK[1])
    p.l([(27,23),(30,26)],SK[3])
    p.p([(34,16),(42,17),(47,22),(45,30),(39,36),(32,34),(29,29),(30,22)],SK[2])
    p.p([(33,21),(37,20),(39,23),(35,27),(31,27)],SK[3],None)
    p.p([(40,24),(45,23),(43,31),(38,35),(36,32)],SK[1],None)
    p.p([(31,27),(35,26),(34,30),(30,32),(26,31),(27,29)],SK[2])
    p.l([(30,24),(35,23)],SK[0],2)
    p.l([(30,25),(33,25)],'#e3c971')
    p.r((40,24,42,25),O)
    p.l([(29,32),(34,33),(39,30)],O)
    p.p([(31,34),(31,30),(32,29),(34,33)],BO[2],None)
    p.p([(31,20),(32,15),(36,13),(43,14),(48,18),(47,22),(40,20),(35,19)],RED[1])
    p.l([(33,16),(37,15),(43,16)],RED[3])
    p.l([(33,19),(40,18),(45,20)],RED[2])
    p.r((43,20,46,22),LE[0])


def brute_head(p):
    # Helmet is the head silhouette. Face is a short recessed patch under its rim.
    p.p([(27,25),(42,23),(50,28),(48,39),(39,43),(29,39),(24,32)],SK[0])
    p.p([(26,29),(32,27),(40,29),(42,35),(37,39),(29,36)],SK[1],None)
    p.p([(25,32),(29,30),(32,33),(30,35),(24,35)],SK[2])
    p.l([(26,29),(33,29)],O,2)
    p.r((27,30,29,30),'#e3b567')
    p.r((39,29,42,30),O)
    p.r((40,30,41,30),'#e3b567')
    p.l([(27,36),(36,38),(42,35)],O,2)
    p.p([(28,38),(26,33),(28,32),(31,37)],BO[2])
    p.p([(39,38),(41,33),(44,33),(42,38)],BO[1])
    p.p([(22,26),(23,18),(28,12),(40,10),(50,15),(54,25),(51,30),(42,28),(34,27),(26,29)],FE[1])
    p.p([(24,23),(26,18),(31,14),(39,13),(42,16),(33,17),(30,23)],FE[2],None)
    p.l([(27,18),(31,15),(38,14)],FE[3],2)
    p.p([(42,13),(49,17),(51,24),(46,25),(42,21)],FE[0],None)
    p.p([(20,26),(29,24),(40,24),(52,26),(52,30),(39,28),(29,28),(21,30)],FE[0])
    p.l([(22,26),(31,25),(41,25)],FE[3])
    p.p([(22,18),(17,13),(17,20),(22,25)],BO[1])
    p.p([(48,16),(54,10),(54,18),(52,22)],BO[2])
    p.r((35,16,36,21),GO[1])
    p.r((35,16,35,19),GO[3])


def chief_head(p, crowned=True):
    # Older long muzzle: one tall tusk, drooping brow, grey temple and jowl folds.
    p.p([(29,19),(20,15),(23,23),(29,26)],SK[1])
    p.l([(23,18),(27,22)],SK[3])
    p.p([(44,17),(51,14),(50,21),(45,25)],SK[0])
    p.p([(30,10),(40,9),(47,14),(47,25),(42,33),(33,35),(26,30),(25,21)],SK[2])
    p.p([(29,15),(32,12),(38,12),(39,15),(34,17),(28,18)],SK[3],None)
    p.p([(41,17),(46,16),(45,26),(41,31),(36,31),(37,25)],SK[1],None)
    p.p([(27,22),(32,20),(36,23),(34,27),(25,27),(24,24)],SK[2])
    p.l([(27,19),(32,18),(34,19)],SK[0],2)
    p.r((28,20,31,21),O)
    p.r((28,20,29,20),'#e1c77c')
    p.l([(38,18),(43,19)],SK[0],2)
    p.r((39,20,42,21),O)
    p.r((39,20,40,20),'#e1c77c')
    p.l([(27,29),(32,30),(42,27)],O,2)
    p.p([(28,31),(25,25),(26,21),(28,24),(31,30)],BO[2])
    p.l([(26,24),(29,29)],BO[3])
    p.p([(39,29),(41,24),(44,23),(43,29)],BO[2])
    p.l([(41,25),(41,28)],BO[3])
    p.l([(30,24),(32,25)],SK[0])
    p.l([(35,31),(39,30)],SK[0])
    p.l([(43,22),(45,24),(44,27)],'#a6aa81')
    p.p([(44,16),(47,16),(47,24),(45,26),(44,22)],'#858e77',None)
    p.l([(45,18),(45,22)],'#c4c6a0')
    if crowned:
        p.p([(28,14),(28,10),(33,11),(35,7),(38,11),(43,9),(46,12),(46,16),(37,14)],GO[1])
        p.l([(29,11),(33,12),(36,10),(38,12),(43,11)],GO[3])
        p.r((34,11,37,14),GO[0])
        p.r((35,11,36,13),'#b4d1a1')


def necro_head(p):
    # Uneven deeply sunken face, one milky eye; hood contains a diagonal opening.
    p.p([(31,20),(35,16),(41,17),(44,23),(42,32),(37,36),(31,33),(28,27)],SK[1])
    p.p([(31,20),(34,18),(36,20),(33,25),(29,27)],'#a1ad75',None)
    p.p([(38,20),(41,21),(42,26),(38,30),(36,27)],SK[0],None)
    p.p([(30,26),(33,24),(34,28),(31,30),(27,29)],'#89955c')
    p.p([(30,22),(34,21),(34,25),(30,26)],O,None)
    p.r((31,23,32,23),'#c1d2b7')
    p.l([(38,22),(41,24)],O,2)
    p.r((38,23,38,23),'#88b7a3')
    p.l([(30,31),(35,32),(39,30)],O)
    p.p([(32,32),(33,29),(34,30),(35,35),(33,35)],BO[2],None)
    p.l([(36,27),(37,30)],SK[2])
    p.p([(24,27),(25,18),(30,11),(39,9),(46,15),(49,27),(47,34),(42,32),(43,22),
         (39,16),(34,16),(29,22),(28,31)],PUR[1])
    p.p([(26,24),(28,18),(32,13),(38,12),(35,15),(30,20),(28,26)],PUR[2],None)
    p.l([(28,19),(31,15),(36,12)],PUR[3])
    p.l([(28,30),(30,23),(34,17),(39,16),(43,22),(44,29)],GO[1])
    p.p([(42,14),(45,17),(47,27),(45,30),(44,22)],PUR[0],None)


def skeleton_head(p):
    # Orc skull: broad cheek arches, real hollow sockets, nasal void, broken jaw.
    p.p([(29,24),(34,20),(43,21),(48,26),(47,34),(43,38),(34,37),(28,33),(26,28)],BO[2])
    p.p([(29,26),(33,23),(39,23),(39,25),(34,27),(29,29)],BO[3],None)
    p.p([(43,25),(47,27),(46,32),(42,35),(39,32)],BO[1],None)
    p.p([(28,28),(34,27),(35,30),(33,33),(28,32)],O,None)
    p.p([(39,27),(44,26),(45,30),(42,32),(38,30)],O,None)
    p.r((30,29,31,29),'#7fac9a')
    p.r((41,28,42,28),'#7fac9a')
    p.p([(35,30),(37,30),(38,34),(34,34)],O,None)
    p.l([(27,33),(31,35),(33,34)],BO[0])
    p.p([(28,35),(31,37),(38,38),(41,35),(44,35),(43,41),(38,44),(31,42),(28,39)],BO[1])
    p.l([(29,37),(32,39),(38,40),(40,38)],BO[3],2)
    p.r((32,35,33,38),BO[3])
    p.r((36,36,37,39),BO[2])
    # Missing right jaw corner leaves an unmistakable asymmetrical opening.
    p.p([(41,35),(44,34),(44,38),(41,39)],O,None)
    p.p([(29,38),(27,33),(28,31),(31,37)],BO[3])
    p.p([(43,34),(46,30),(46,34)],BO[2],None)
    p.l([(37,22),(36,25),(38,26)],BO[0])


def skull_staff(p, x, y):
    p.l([(x-1,68),(x,43),(x+1,y+13),(x-1,y+9)],O,5)
    p.l([(x-1,67),(x,43),(x+1,y+13),(x-1,y+9)],LE[1],3)
    p.l([(x-2,65),(x-1,44),(x,y+14)],LE[3])
    for yy in (39,44,49):
        p.l([(x-2,yy),(x+1,yy-1)],GO[1],2)
    p.p([(x-6,y+4),(x-4,y),(x+2,y-1),(x+7,y+3),(x+6,y+8),(x+2,y+11),
         (x+1,y+15),(x-3,y+14),(x-4,y+10),(x-7,y+8)],BO[2])
    p.p([(x-5,y+3),(x-3,y+1),(x+1,y+1),(x+2,y+3),(x-3,y+5)],BO[3],None)
    p.p([(x-5,y+5),(x-1,y+5),(x-1,y+8),(x-4,y+8)],O,None)
    p.p([(x+2,y+4),(x+5,y+4),(x+5,y+7),(x+2,y+8)],O,None)
    p.r((x-4,y+6,x-3,y+6),'#9fcaad')
    p.r((x+3,y+5,x+4,y+5),'#9fcaad')
    p.r((x,y+8,x+1,y+10),BO[0])
    p.l([(x-2,y+12),(x+2,y+12)],BO[0])


def pose(kind, frame, action=None):
    im = Image.new('RGBA',(SIZE,SIZE))
    phase = frame*math.tau/12 if not action else 0
    bob = round(-abs(math.sin(phase))*1.3) if not action else 0
    counter = round(math.cos(phase)*.8) if not action else 0
    p = Pixels(im)
    twist = math.sin(phase)*1.4
    body = Pixels(im,counter,bob,twist)
    # Far limbs precede body, near limbs follow: consistent elevated 3/4 overlap.
    if kind == 'orcling':
        leg(p,(42,55+bob),1,phase,2,bare=True,stride=5)
        arm(body,(43,45),0,phase,2)
        leg(p,(35,56+bob),0,phase,2,bare=True,stride=5)
        body.p([(32,43),(41,42),(46,51),(44,58),(39,60),(36,58),(30,59),(29,53)],LE[1])
        body.p([(32,44),(36,44),(35,52),(31,55)],LE[2],None)
        body.p([(38,44),(42,44),(44,51),(39,52)],SK[2])
        body.l([(31,49),(34,47)],LE[3])
        body.l([(30,54),(42,53)],LE[0],3)
        body.r((35,53,38,55),GO[2])
        body.p([(31,55),(35,57),(33,60),(30,59)],LE[3],None)
        orcling_head(Pixels(im,counter-1,bob))
        arm(body,(29,46),1,phase,2)
        body.r((26+round(math.cos(phase)*3),56,29+round(math.cos(phase)*3),57),LE[0])
    elif kind == 'grunt':
        leg(p,(45,53+bob),1,phase,4,stride=5)
        arm(body,(48,34),0,phase,5)
        leg(p,(33,54+bob),0,phase,4,stride=5)
        body.p([(29,33),(41,31),(48,35),(50,47),(45,56),(31,57),(25,49),(25,40)],SK[1])
        body.p([(28,36),(33,33),(39,34),(38,41),(31,43),(27,42)],SK[3],None)
        body.p([(40,35),(45,36),(47,44),(42,46),(38,42)],SK[2],None)
        body.l([(30,45),(34,46),(38,45)],SK[0])
        body.p([(42,32),(47,34),(29,51),(25,47)],LE[1])
        body.l([(43,34),(27,48)],LE[3],2)
        body.p([(27,49),(46,47),(47,56),(40,59),(34,56),(28,59)],LE[0])
        body.p([(29,51),(36,51),(35,56),(30,56)],LE[2],None)
        body.p([(27,48),(46,47),(47,51),(27,53)],LE[1])
        body.r((34,48,40,52),GO[1])
        body.r((35,49,39,51),GO[3])
        body.r((36,50,38,51),LE[0])
        grunt_head(Pixels(im,counter-1,bob))
        arm(body,(25,37),1,phase,5)
        body.p([(20,44),(26,43),(29,48),(24,51),(20,49)],LE[1])
        body.l([(21,45),(25,45)],LE[3])
    elif kind == 'runner':
        lag = round(math.sin(phase-.8)*3)
        body.p([(44,18),(50,19),(58+lag,26),(52+lag,25),(57+lag,31),(49,27)],RED[1])
        body.l([(47,20),(53+lag,24)],RED[2])
        leg(p,(44,51+bob),1,phase,2.5,stride=9)
        arm(body,(46,34),0,phase,2.6,reach=((50+math.cos(phase)*5,39),(44+math.cos(phase)*7,43)))
        leg(p,(35,52+bob),0,phase,2.5,stride=9)
        body.p([(34,32),(43,31),(48,36),(46,45),(43,53),(32,55),(30,48)],LE[1])
        body.p([(34,34),(38,34),(38,41),(33,46),(32,43)],LE[3],None)
        body.p([(40,35),(45,34),(45,42),(41,47),(38,46)],LE[2],None)
        body.l([(33,43),(41,37)],LE[0],2)
        body.p([(31,48),(44,46),(45,50),(32,53)],LE[0])
        body.r((36,48,39,50),GO[2])
        body.p([(41,47),(47,48),(48+lag,56),(43,54)],RED[1])
        body.l([(44,49),(46+lag,54)],RED[2])
        runner_head(Pixels(im,counter-3,bob))
        arm(body,(31,35),1,phase,2.8,reach=((25-math.cos(phase)*5,42),(28-math.cos(phase)*7,47)))
        body.l([(26-math.cos(phase)*7,45),(30-math.cos(phase)*7,44)],LE[0],3)
    elif kind == 'brute':
        leg(p,(49,51+bob),1,phase,5,armor=True,stride=4)
        arm(body,(57,35),0,phase,6,FE)
        leg(p,(31,53+bob),0,phase,5.5,armor=True,stride=4)
        body.p([(24,29),(39,25),(55,30),(61,41),(55,54),(29,57),(20,47),(18,37)],FE[0])
        body.p([(26,31),(37,29),(45,32),(43,43),(30,47),(23,42)],FE[1])
        body.p([(28,32),(36,31),(40,33),(37,36),(27,36)],FE[3],None)
        body.p([(27,38),(39,37),(40,42),(30,45),(24,41)],FE[2],None)
        body.p([(45,33),(54,32),(58,40),(53,48),(44,47)],FE[1])
        body.l([(46,35),(52,34),(55,39)],FE[2],2)
        for yy in (43,48):
            body.l([(26,yy),(36,yy+2),(51,yy-2)],O,2)
            body.l([(29,yy+1),(35,yy+2)],FE[2])
        body.p([(26,50),(52,47),(54,54),(43,57),(40,53),(35,59),(26,57)],LE[1])
        body.p([(35,49),(43,49),(44,55),(39,58),(34,55)],FE[1])
        body.r((37,50,40,52),GO[2])
        # Different shoulder masses reinforce the oblique hunched pose.
        body.p([(13,30),(18,23),(27,24),(32,31),(30,40),(16,41),(12,36)],FE[1])
        body.p([(15,30),(19,26),(25,27),(27,31),(24,34),(15,34)],FE[2],None)
        body.l([(17,29),(20,27),(25,28)],FE[3],2)
        body.p([(48,27),(56,25),(64,30),(66,38),(60,42),(51,38)],FE[1])
        body.l([(52,28),(57,28),(62,31)],FE[3],2)
        for xx,yy in ((17,25),(25,25),(57,27),(63,32)):
            body.p([(xx,yy),(xx-1,yy-6),(xx+3,yy-1)],BO[2])
        brute_head(Pixels(im,counter-2,bob))
        arm(body,(16,39),1,phase,6,FE)
        body.p([(9,47),(18,45),(22,51),(20,56),(11,57),(8,53)],FE[0])
        body.p([(10,48),(17,47),(20,51),(12,52)],FE[2])
        body.l([(12,49),(16,49)],FE[3])
    elif kind == 'orc_chief':
        # .55 second action: anticipatory dip, palm lift, release, full recovery.
        a = [0,-1,-2,0,3,7,11,13,13,9,4,0][frame] if action else 0
        dip = 1 if action and frame in (1,2,3) else 0
        body = Pixels(im,counter,bob+dip,twist)
        lag = round(math.sin(phase-.7)*2)
        body.p([(30,27),(50,28),(55,47),(58+lag,61),(49,64),(43,59),(33,64),(23-lag,61),(26,40)],RED[0])
        body.p([(28,34),(33,36),(31,55),(27-lag,60),(25-lag,59)],RED[2],None)
        leg(p,(47,52+bob),1,phase,4.5,armor=True,stride=4)
        arm(body,(55,34),0,phase,4.5,FE,reach=((59,44-a*.45),(59-a*.2,49-a)) if action and frame<11 else None)
        leg(p,(31,54+bob),0,phase,4.5,armor=True,stride=4)
        body.p([(27,29),(39,27),(52,30),(56,42),(50,53),(29,54),(22,43)],FE[0])
        body.p([(28,31),(37,30),(42,34),(40,43),(30,45),(25,40)],FE[2])
        body.p([(29,32),(36,32),(38,34),(36,36),(28,35)],FE[3],None)
        body.p([(43,32),(51,32),(53,40),(49,45),(42,43)],FE[1])
        body.l([(44,34),(49,34),(51,38)],FE[2],2)
        body.l([(29,44),(38,47),(50,43)],GO[1],2)
        body.l([(29,43),(37,45)],GO[3])
        body.p([(27,47),(51,46),(52,52),(28,55)],LE[0])
        body.p([(34,47),(42,46),(44,50),(40,54),(34,53)],GO[1])
        body.l([(35,48),(40,48),(42,50),(39,52)],GO[3])
        body.r((36,49,39,51),LE[0])
        body.p([(29,54),(37,54),(35+lag,63),(28,61)],RED[1])
        body.l([(30,55),(34,55),(32+lag,61)],RED[2])
        body.p([(42,53),(50,52),(52+lag,61),(44,62)],RED[1])
        body.l([(44,54),(48,54),(50+lag,60)],GO[1])
        body.p([(16,31),(20,25),(29,25),(34,32),(31,39),(18,40),(14,36)],FE[1])
        body.p([(18,31),(22,27),(28,28),(30,32),(27,35),(18,35)],FE[2],None)
        body.l([(20,29),(23,28),(28,29)],FE[3],2)
        body.l([(17,36),(26,37),(30,34)],GO[2])
        body.p([(47,28),(54,26),(61,31),(63,37),(57,41),(49,36)],FE[1])
        body.l([(50,29),(55,29),(59,32)],FE[3],2)
        body.l([(51,36),(57,39),(61,36)],GO[2])
        chief_head(Pixels(im,counter-1,bob+dip))
        arm(body,(18,39),1,phase,4.8,FE)
        if action and 2 <= frame <= 10:
            x,y=59-a*.2,49-a
            body.p([(x-3,y+1),(x-4,y-4),(x-3,y-8),(x-1,y-8),(x-1,y-4),
                    (x+1,y-10),(x+2,y-9),(x+2,y-4),(x+4,y-7),(x+5,y-5),(x+3,y+1),(x,y+3)],SK[2])
            body.l([(x-2,y-3),(x,y-4),(x+2,y-2)],SK[3])
            if frame in (7,8):
                body.r((x-2,y-2,x,y),GO[3])
    elif kind == 'necorcmancer':
        # Staff plants, caster coils, staff rises, release, then returns to planted pose.
        raise_y = [0,0,1,0,-4,-8,-12,-15,-15,-10,-4,0][frame] if action else round(max(0,math.sin(phase)))*-1
        lean = [0,1,3,4,3,2,0,-2,-2,-1,0,0][frame] if action else counter
        lag = round(math.sin(phase-.9)*2) if not action else [0,0,0,1,2,3,2,0,-1,-2,-1,0][frame]
        body = Pixels(im,lean,bob,twist*.7)
        leg(p,(42,56+bob),1,phase,2,stride=3)
        leg(p,(34,57+bob),0,phase,2,stride=3)
        body.p([(29,32),(41,30),(48,35),(49,48),(54+lag,64),(49,67),(42,65),(36,68),
                (30,65),(24-lag,67),(25,57),(28,45)],PUR[1])
        body.p([(30,35),(34,35),(32,49),(29-lag,63),(26-lag,64),(28,52)],PUR[2],None)
        body.p([(37,38),(41,37),(42,50),(46+lag,64),(41,63),(38,52)],PUR[2],None)
        body.l([(31,40),(30,51),(27-lag,62)],PUR[3])
        body.p([(44,40),(47,38),(47,51),(51+lag,63),(47,64),(43,52)],PUR[0],None)
        body.l([(25-lag,64),(30,63),(36,66),(42,63),(49,65),(53+lag,63)],GO[1])
        body.l([(31,47),(44,46)],LE[0],3)
        body.r((36,45,39,48),BO[2])
        body.r((37,46,38,47),O)
        # Crooked mantle, with two individually placed bone clasps.
        body.p([(26,31),(31,29),(37,35),(44,30),(49,32),(48,38),(39,42),(28,38)],PUR[0])
        body.l([(28,32),(32,33),(37,37)],PUR[2],2)
        body.p([(29,34),(32,33),(34,35),(33,38),(30,38)],BO[2])
        body.r((30,35,31,36),O)
        body.p([(42,35),(45,34),(47,36),(45,39),(42,38)],BO[1])
        necro_head(Pixels(im,lean-2,bob))
        free_hand = ((22,44),(25,49))
        if action:
            free_hand = ((21,43-max(0,-raise_y)*.4),(21-max(0,-raise_y)*.25,48+raise_y))
        arm(body,(27,38),1,phase,3,PUR,reach=free_hand)
        sx = 59 + (1 if action and frame in (3,4,5) else 0)
        staff = Pixels(im,0,raise_y)
        skull_staff(staff,sx,19)
        # Hand stays on the actual moving staff shaft, not a detached overlay.
        arm(body,(46,37),0,phase,3,PUR,reach=((51,42+raise_y*.4),(sx,43+raise_y-bob)))
        body.l([(sx-2,41+raise_y-bob),(sx+1,41+raise_y-bob)],SK[3])
        if action and frame in (7,8):
            body.r((19,37,21,39),'#afd5b4')
    elif kind == 'skeleorc':
        leg(p,(43,55+bob),1,phase,1.6,skeleton=True,stride=6)
        arm(body,(46,42),0,phase,1.8,BO)
        leg(p,(34,56+bob),0,phase,1.6,skeleton=True,stride=6)
        body.p([(32,51),(39,49),(46,50),(47,55),(41,59),(37,57),(32,58),(29,54)],BO[1])
        body.p([(32,52),(36,51),(37,54),(33,55)],BO[3],None)
        body.p([(40,52),(44,51),(44,54),(40,56)],O,None)
        body.l([(37,39),(38,51)],BO[1],3)
        body.l([(37,40),(37,49)],BO[3])
        body.l([(30,41),(35,39),(43,40),(47,43)],BO[2],3)
        # Open negative space between curved ribs; no filled shirt-shaped rib cage.
        for yy in (43,47,51):
            body.l([(30,yy-1),(31,yy+1),(35,yy+2),(39,yy+1)],O,4)
            body.l([(30,yy-1),(32,yy),(36,yy+1)],BO[2],2)
            body.l([(31,yy-1),(33,yy)],BO[3])
            body.l([(40,yy),(44,yy-1),(46,yy-3)],O,4)
            body.l([(40,yy),(44,yy-1),(46,yy-3)],BO[1],2)
        lag=round(math.sin(phase-.7)*2)
        body.p([(30,53),(36,54),(43,52),(46,54),(42,57),(40+lag,62),(36,59),(33,60)],RED[1])
        body.l([(31,54),(36,55),(41,54)],RED[2])
        skeleton_head(Pixels(im,counter-2,bob))
        arm(body,(29,43),1,phase,1.8,BO)
    return im


# Four authored joint tableaux per character: standing, recoil/kneel, impact,
# settled. Coordinates describe anatomy, never masks or a rotated whole sprite.
# Each pose: neck, pelvis, near knee/foot, far knee/foot, near elbow/hand,
# far elbow/hand, head centre, head tilt (degrees).
DEATH_POSES = {
    'orcling': [
        ((37,43),(37,56),(32,62),(29,68),(45,61),(47,66),(25,53),(25,60),(48,50),(50,56),(37,35),0),
        ((34,47),(40,58),(31,63),(28,68),(44,62),(49,67),(23,55),(26,62),(45,51),(43,58),(32,40),-15),
        ((29,58),(43,63),(42,67),(33,69),(51,65),(55,69),(21,63),(24,68),(38,62),(39,68),(25,53),-55),
        ((29,62),(43,64),(41,68),(34,70),(49,66),(55,69),(22,66),(28,70),(38,64),(41,69),(23,58),-65)],
    'grunt': [
        ((37,35),(38,53),(31,61),(26,68),(47,60),(50,66),(21,46),(20,54),(54,43),(54,51),(36,27),0),
        ((40,39),(38,55),(29,62),(25,68),(45,62),(51,67),(25,44),(20,48),(56,48),(56,55),(41,30),20),
        ((31,51),(44,59),(50,65),(59,68),(43,63),(39,69),(22,57),(18,63),(43,54),(48,61),(25,46),-38),
        ((31,59),(47,62),(56,63),(66,66),(48,67),(58,70),(24,65),(18,68),(42,61),(46,67),(23,55),-70)],
    'runner': [
        ((37,34),(39,52),(32,60),(27,68),(46,59),(51,66),(24,42),(25,48),(51,38),(46,44),(35,26),0),
        ((29,39),(40,53),(34,61),(25,66),(46,57),(52,61),(21,47),(17,54),(44,43),(45,49),(26,32),-25),
        ((24,51),(43,57),(53,59),(62,62),(45,64),(53,69),(18,59),(12,64),(29,57),(34,65),(19,47),-60),
        ((26,61),(44,63),(56,61),(66,65),(49,68),(60,70),(20,67),(11,68),(35,65),(40,70),(20,58),-83)],
    'brute': [
        ((38,31),(40,51),(29,60),(25,68),(50,59),(56,66),(14,45),(15,54),(61,43),(62,52),(37,25),0),
        ((38,38),(40,55),(28,65),(23,69),(49,64),(56,68),(15,52),(18,62),(61,50),(58,61),(36,31),-5),
        ((31,48),(46,59),(37,66),(32,70),(56,64),(62,69),(19,57),(15,66),(49,53),(55,63),(30,41),-28),
        ((31,56),(48,61),(42,68),(34,70),(59,64),(69,68),(22,65),(14,68),(46,60),(51,68),(28,51),-57)],
    'orc_chief': [
        ((38,30),(39,53),(29,61),(25,68),(48,60),(53,66),(17,47),(17,55),(59,43),(59,51),(37,22),0),
        ((37,38),(40,57),(29,65),(25,69),(49,64),(55,67),(20,52),(26,60),(57,49),(54,57),(35,29),-10),
        ((30,49),(44,60),(35,67),(29,70),(53,63),(60,68),(20,58),(16,65),(45,54),(49,63),(27,41),-35),
        ((31,60),(46,63),(40,68),(31,70),(56,64),(66,69),(23,65),(17,69),(43,62),(48,68),(25,54),-65)],
    'necorcmancer': [
        ((36,35),(38,54),(32,63),(28,68),(43,62),(47,66),(24,45),(26,51),(51,43),(59,43),(35,25),0),
        ((34,42),(39,57),(30,64),(27,69),(44,64),(50,68),(23,52),(27,60),(51,48),(59,47),(32,32),-12),
        ((29,54),(43,61),(35,67),(29,70),(49,65),(56,69),(21,61),(22,68),(43,57),(49,65),(25,45),-42),
        ((31,62),(45,64),(37,68),(30,70),(52,66),(59,70),(24,66),(19,69),(44,64),(50,69),(25,56),-64)],
    'skeleorc': [
        ((37,41),(38,55),(31,61),(27,68),(46,60),(49,66),(25,50),(26,56),(51,48),(51,54),(36,30),0),
        ((35,47),(38,58),(29,63),(23,69),(46,61),(53,66),(23,56),(19,62),(50,54),(56,59),(34,35),-15),
        ((31,57),(43,62),(36,67),(29,70),(51,64),(62,68),(20,63),(13,67),(49,58),(58,61),(27,46),-44),
        ((33,64),(45,65),(39,70),(30,71),(55,63),(67,67),(22,67),(13,70),(52,60),(63,61),(24,59),-70)],
}
HEADS = {'orcling':orcling_head,'grunt':grunt_head,'runner':runner_head,'brute':brute_head,
         'orc_chief':chief_head,'necorcmancer':necro_head,'skeleorc':skeleton_head}


def bone_pile(frame):
    """A loose debris heap: no connected spine, paired legs or intact rib cage."""
    im=Image.new('RGBA',(SIZE,SIZE))
    p=Pixels(im)
    settle=1 if frame==8 else 0
    # Far loose femur and forearm, with separated enlarged joint ends.
    for a,b in [((45,59-settle),(61,63)),((53,68),(66,66)),
                ((16,64),(24,62)),((29,71),(41,73)),((45,72),(54,70))]:
        p.l([a,b],O,4)
        p.l([a,b],BO[1],2)
        p.l([(a[0],a[1]-1),(b[0],b[1]-1)],BO[3])
        for x,y in (a,b):
            p.r((x-1,y-1,x+1,y+1),BO[2])
            p.r((x-1,y-1,x,y-1),BO[3])
    # Pelvis fragment and crossed broken rib slats form the central heap.
    p.p([(36,65),(39,60-settle),(45,61),(49,65),(45,69),(41,67),(37,69)],BO[1])
    p.p([(39,63),(42,62),(43,65),(40,66)],O,None)
    p.p([(45,63),(47,65),(45,67),(43,66)],O,None)
    for points in [((31,67),(39,64),(48,65)),((35,70),(42,66),(52,68)),
                   ((34,63-settle),(40,65),(48,70)),((39,69),(46,66),(55,64))]:
        p.l(list(points),O,4)
        p.l(list(points),BO[2],2)
        p.l([(x,y-1) for x,y in points[:2]],BO[3])
    # Detached jaw sits to the left rather than remaining hinged to the skull.
    p.p([(16,69),(19,71),(25,69),(27,71),(24,74),(18,74),(14,71)],BO[1])
    p.l([(16,70),(19,72),(24,71)],BO[3],2)
    p.r((18,68,19,71),BO[2])
    p.r((23,68,24,70),BO[3])
    # Hollow tilted cranium, with cheek broken clear of the separate jaw.
    y=-settle
    p.p([(23,55+y),(29,52+y),(35,54+y),(38,59+y),(35,65+y),
         (29,67+y),(23,64+y),(20,60+y)],BO[2])
    p.p([(23,56+y),(28,54+y),(33,55+y),(31,58+y),(25,59+y)],BO[3],None)
    p.p([(23,59+y),(28,57+y),(29,61+y),(25,64+y),(22,62+y)],O,None)
    p.p([(31,57+y),(35,58+y),(35,61+y),(32,63+y),(30,61+y)],O,None)
    p.p([(29,62+y),(31,63+y),(30,66+y),(27,65+y)],O,None)
    p.l([(24,64+y),(26,65+y)],BO[0])
    p.l([(29,53+y),(28,55+y),(30,56+y)],BO[0])
    # Only a rag scrap remains under the heap; there is no blood or eye glow.
    p.p([(36,71),(40,69),(43,72),(40,73)],RED[1])
    return im


def death(kind, frame):
    if frame==0:
        return pose(kind,0)
    if kind=='skeleorc' and frame>=8:
        return bone_pile(frame)
    # Early recoil is brief; final two drawings are a stable corpse hold.
    keytime=[0,.35,.7,1.1,1.45,1.8,2.15,2.5,2.8,3,3,3][frame]
    lo=min(2,int(keytime))
    mix=keytime-lo
    left,right=DEATH_POSES[kind][lo:lo+2]
    joints=[tuple(a+(b-a)*mix for a,b in zip(l,r)) if isinstance(l,tuple)
            else l+(r-l)*mix for l,r in zip(left,right)]
    neck,hip,nk,nf,fk,ff,ne,nh,fe,fh,head,angle=joints
    im=Image.new('RGBA',(SIZE,SIZE))
    p=Pixels(im)
    skeleton=kind=='skeleorc'
    armored=kind in ('brute','orc_chief')
    robe=kind=='necorcmancer'
    ramp=BO if skeleton else FE if armored else PUR if robe else SK if kind=='grunt' else LE
    size={'orcling':5,'grunt':10,'runner':6,'brute':13,'orc_chief':11,'necorcmancer':8,'skeleorc':7}[kind]
    dx,dy=hip[0]-neck[0],hip[1]-neck[1]
    distance=math.hypot(dx,dy) or 1
    vx,vy=-dy/distance,dx/distance
    def off(point,width):
        return point[0]+vx*width,point[1]+vy*width
    far_shoulder=off(neck,-size)
    near_shoulder=off(neck,size)
    far_hip=off(hip,-size*.55)
    near_hip=off(hip,size*.55)
    leg_ramp=BO if skeleton else FE if armored else SK if kind=='orcling' else LE
    width=1.6 if skeleton else 2 if kind=='orcling' else 2.6 if kind=='runner' else 4.5
    for h,knee,foot in ((far_hip,fk,ff),(near_hip,nk,nf)):
        scatter=max(0,keytime-1.5)*1.5 if skeleton else 0
        segment(p,h,(knee[0]-scatter,knee[1]-scatter),width,width*.8,leg_ramp)
        segment(p,(knee[0]+scatter,knee[1]),foot,width*.8,width*.6,leg_ramp)
        p.p([(foot[0]-4,foot[1]-2),(foot[0]+2,foot[1]-2),(foot[0]+3,foot[1]+1),
             (foot[0]-5,foot[1]+1)],leg_ramp[1])
        p.l([(foot[0]-3,foot[1]-1),(foot[0]+1,foot[1]-1)],leg_ramp[3])
    arm_ramp=BO if skeleton else FE if armored else PUR if robe else SK
    for shoulder,elbow,hand in ((far_shoulder,fe,fh),(near_shoulder,ne,nh)):
        scatter=max(0,keytime-1.5)*1.5 if skeleton else 0
        segment(p,shoulder,(elbow[0]-scatter,elbow[1]-scatter),width,width*.8,arm_ramp)
        segment(p,(elbow[0]+scatter,elbow[1]),hand,width*.8,width*.55,arm_ramp)
        p.p([(hand[0]-2,hand[1]-2),(hand[0]+2,hand[1]-1),(hand[0]+2,hand[1]+2),
             (hand[0]-2,hand[1]+2)],BO[2] if skeleton else SK[2])
    if skeleton:
        segment(p,neck,hip,1.5,1.5,BO)
        for t in (.2,.45,.7):
            centre=(neck[0]+dx*t,neck[1]+dy*t)
            # Ribs detach from the spine as the joint pile settles.
            drift=max(0,keytime-1.8)*(t-.4)*5
            a=off(centre,-6)
            b=off(centre,6)
            p.l([(a[0]+drift,a[1]),(centre[0]+2,centre[1]+2),(b[0],b[1])],O,4)
            p.l([(a[0]+drift,a[1]-1),(centre[0]+2,centre[1]+1),(b[0],b[1]-1)],BO[2],2)
        p.p([off(hip,5),(hip[0]+4,hip[1]+3),off(hip,-5),(hip[0]-3,hip[1]-2)],BO[1])
        p.p([(hip[0]-3,hip[1]),(hip[0]+4,hip[1]-1),(hip[0]+2,hip[1]+3)],RED[1])
    else:
        hem=(hip[0]+dx*.3,hip[1]+dy*.3) if robe else hip
        p.p([near_shoulder,far_shoulder,off(hem,-size*.8),off(hem,size*.85)],ramp[1])
        p.p([near_shoulder,neck,(hip[0],hip[1]),off(hem,size*.7)],ramp[2],None)
        p.l([off(neck,size*.8),off(hip,size*.7)],ramp[3],2)
        if armored:
            p.l([off((neck[0]+dx*.55,neck[1]+dy*.55),size*.8),
                 (neck[0]+dx*.65,neck[1]+dy*.65),
                 off((neck[0]+dx*.55,neck[1]+dy*.55),-size*.8)],O,2)
            for shoulder in (near_shoulder,far_shoulder):
                x,y=shoulder
                p.p([(x-6,y-3),(x-2,y-6),(x+5,y-4),(x+7,y+2),(x+3,y+5),(x-5,y+3)],FE[1])
                p.l([(x-4,y-2),(x-1,y-4),(x+4,y-2)],FE[3],2)
        if kind in ('grunt','runner','orcling'):
            p.l([off(neck,-size*.6),off(hip,size*.7)],LE[0],4)
            p.l([off(neck,-size*.6),off(hip,size*.7)],LE[3],2)
        p.l([off(hip,-size*.7),off(hip,size*.7)],LE[0],3)
        p.r((hip[0]-2,hip[1]-2,hip[0]+2,hip[1]+1),GO[2])
        if kind=='orc_chief':
            p.p([off(hip,-8),(hip[0]+10,hip[1]+4),off(hip,7)],RED[1])
            p.l([off(hip,-6),(hip[0]+8,hip[1]+3)],GO[2])
        if robe:
            p.l([off(hem,-size*.8),hem,off(hem,size*.8)],GO[1])
            p.l([off(neck,4),off(hip,5),off(hem,4)],PUR[3])
    head_pixels=Pixels(im,head[0]-38,head[1]-28,angle=math.radians(angle))
    if kind=='orc_chief':
        chief_head(head_pixels,crowned=frame<6)
    else:
        HEADS[kind](head_pixels)
    # Close the two individual eye positions, preserving each unique facial geometry.
    eyes={'orcling':((29,34,32,35),(39,34,41,35)), 'grunt':((26,26,30,27),(38,26,41,27)),
          'runner':((30,25,33,25),(40,24,42,25)), 'brute':((27,30,29,30),(40,30,41,30)),
          'orc_chief':((28,20,31,21),(39,20,42,21)), 'necorcmancer':((31,23,32,23),(38,23,38,23)),
          'skeleorc':((30,29,31,29),(41,28,42,28))}
    for eye in eyes[kind]:
        head_pixels.r(eye,O)
    if kind=='runner':
        p.l([(head[0]+8,head[1]-2),(head[0]+15,head[1]+3),(head[0]+17,head[1]+1)],RED[1],2)
    if kind=='orc_chief' and frame>=6:
        # A small separate crown settles beside the leader, not a blood effect.
        x=15-max(0,keytime-2)*3
        y=63+max(0,keytime-2)*5
        p.p([(x-5,y),(x-6,y-4),(x-2,y-2),(x,y-6),(x+2,y-2),(x+6,y-4),(x+5,y+1)],GO[1])
        p.l([(x-4,y-1),(x+4,y-1)],GO[3])
    if robe:
        # Released shaft and skull tip articulate down to the ground independently.
        fall=min(1, max(0,(keytime-.35)/2.65))
        base=(58-25*fall,68+2*fall)
        tip=(59+10*fall,23+40*fall)
        p.l([base,tip],O,5)
        p.l([base,tip],LE[1],3)
        p.l([(base[0]-1,base[1]-1),(tip[0]-1,tip[1]-1)],LE[3])
        x,y=tip
        p.p([(x-5,y-3),(x+1,y-5),(x+5,y-2),(x+4,y+3),(x,y+6),(x-5,y+3)],BO[2])
        p.r((x-3,y-1,x-1,y+1),O)
        p.r((x+1,y-2,x+3,y),O)
        p.l([(x-1,y+4),(x+2,y+3)],BO[0])
    return im


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(kind, animations):
    all_frames = [im for _,_,frames in animations for im in frames]
    sheet = Image.new('RGBA',(SIZE*len(all_frames),SIZE))
    for i,im in enumerate(all_frames):
        sheet.alpha_composite(im,(i*SIZE,0))
    sheet_path = OUT/f'{kind}.png'
    sheet.save(sheet_path,optimize=True)
    still_path = OUT/f'{kind}_still.png'
    all_frames[0].save(still_path,optimize=True)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(all_frames)+2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{kind}.png" id="1_sheet"]','']
    for i in range(len(all_frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1_sheet")',
                  f'region = Rect2({i*SIZE}, 0, {SIZE}, {SIZE})','']
    lines += ['[resource]','animations = [']
    offset=0
    for n,(name,speed,frames) in enumerate(animations):
        lines += ['{','"frames": [']
        for j in range(len(frames)):
            lines += ['{','"duration": 1.0,',f'"texture": SubResource("Frame_{offset+j}")','},' if j+1<len(frames) else '}']
        lines += ['],',f'"loop": {"true" if name=="walk" else "false"},',f'"name": &"{name}",',
                  f'"speed": {speed:.12f}', '},' if n+1<len(animations) else '}']
        offset += len(frames)
    lines += [']','']
    (OUT/f'{kind}.tres').write_text('\n'.join(lines))
    historical=ROOT/f'assets/enemies/{kind}.png'
    manifest = {
        'authoring': 'Original local pixel geometry; seven individually authored heads/anatomies; every pose redrawn from articulated joints. No source-image sampling or model generation.',
        'identity': IDENTITY[kind],
        'generator': 'tools/author_enemy_sprites.py',
        'generator_sha256': digest(Path(__file__)),
        'frame_size': [SIZE,SIZE], 'sheet_size': list(sheet.size),
        'alpha': 'binary 0/255; nearest-neighbour; no antialiasing, smoothing, dithering, masks or raster-image rotation',
        'lighting': 'upper-left broad material planes; dark selective outlines and warm leather/bone shadows',
        'camera': 'elevated three-quarter view facing left; foreground left shoulder/foot overlap far right limbs',
        'base_anchor': [.5,.875], 'source_faces_left': True,
        'sheet_sha256': digest(sheet_path),
        'still': str(still_path.relative_to(ROOT)), 'still_sha256': digest(still_path),
        'still_dimensions': [SIZE,SIZE],
        'death': {'duration_seconds': .8, 'last_frame': 'settled corpse; bone pile for SkeleOrc',
                  'articulation': 'individually authored recoil, knee/trip, impact and settled joint tableaux',
                  'blood_in_sprite': False, 'dropped_equipment': 'Chief crown / NecOrcmancer skullstaff'},
        'historical_reference': str(historical.relative_to(ROOT)),
        'historical_reference_dimensions': list(Image.open(historical).size),
        'historical_reference_sha256': digest(historical),
        'historical_reference_status': 'Pre-existing source preserved byte-for-byte; not used as cutout or runtime frame',
        'historical_reference_origin': ('Prior accepted Klein reference edit' if kind=='grunt'
                                        else 'Prior locally authored Pillow sprite'),
        'source_origin': 'Locally authored Pillow pixel clusters; NOT PixelLab-generated',
        'animations': [{'name':name,'fps':speed,'duration_seconds':len(frames)/speed,'frame_count':len(frames),
                        'loop':name=='walk','alpha_bounds':[list(im.getbbox()) for im in frames]}
                       for name,speed,frames in animations],
    }
    (OUT/f'{kind}.json').write_text(json.dumps(manifest,indent=2)+'\n')


def previews(cycles):
    """Show equal native pixels, enlarged clusters, and actual board-height ratios."""
    background='#27302b'
    lineup=Image.new('RGB',(SIZE*7,112),background)
    d=ImageDraw.Draw(lineup)
    for i,kind in enumerate(KINDS):
        lineup.paste(cycles[kind][0][2][0],(i*SIZE,7),cycles[kind][0][2][0])
        d.text((i*SIZE+3,92),kind,fill='#dfd4ac')
    lineup.save('/tmp/gorcs-enemy-lineup-native.png')
    lineup.resize((1120,224),Image.Resampling.NEAREST).save('/tmp/gorcs-enemy-lineup-enlarged.png')
    contact=Image.new('RGB',(SIZE*12,7*104),background)
    d=ImageDraw.Draw(contact)
    for row,kind in enumerate(KINDS):
        d.text((3,row*104+2),kind,fill='#dfd4ac')
        for f,im in enumerate(cycles[kind][0][2]):
            contact.paste(im,(f*SIZE,row*104+18),im)
    contact.save('/tmp/gorcs-enemy-walk-contact.png')
    actions=Image.new('RGB',(SIZE*12,208),background)
    d=ImageDraw.Draw(actions)
    for row,kind in enumerate(('orc_chief','necorcmancer')):
        d.text((3,row*104+2),kind+' '+cycles[kind][1][0],fill='#dfd4ac')
        for f,im in enumerate(cycles[kind][1][2]):
            actions.paste(im,(f*SIZE,row*104+18),im)
    actions.save('/tmp/gorcs-enemy-action-contact.png')
    deaths=Image.new('RGB',(SIZE*12,7*104),background)
    draw=ImageDraw.Draw(deaths)
    for row,kind in enumerate(KINDS):
        draw.text((3,row*104+2),kind+' death / .8s',fill='#dfd4ac')
        for f,im in enumerate(cycles[kind][-1][2]):
            deaths.paste(im,(f*SIZE,row*104+18),im)
    deaths.save('/tmp/gorcs-enemy-death-contact.png')
    corpses=Image.new('RGB',(SIZE*7,112),background)
    draw=ImageDraw.Draw(corpses)
    for i,kind in enumerate(KINDS):
        im=cycles[kind][-1][2][-1]
        corpses.paste(im,(i*SIZE,7),im)
        draw.text((i*SIZE+3,92),kind,fill='#dfd4ac')
    corpses.save('/tmp/gorcs-enemy-corpse-lineup-native.png')
    corpses.resize((1120,224),Image.Resampling.NEAREST).save('/tmp/gorcs-enemy-corpse-lineup-enlarged.png')
    death_gif=[]
    for tick in range(60):
        image=Image.new('RGB',(1120,224),background)
        draw=ImageDraw.Draw(image)
        for i,kind in enumerate(KINDS):
            frames=cycles[kind][-1][2]
            index=max(0,min(11,int((tick*.05-.5)*15)))
            im=frames[index].resize((160,160),Image.Resampling.NEAREST)
            image.paste(im,(i*160,14),im)
            draw.text((i*160+8,190),kind+' / death',fill='#dfd4ac')
        death_gif.append(image)
    death_gif[0].save('/tmp/gorcs-enemy-death-preview.gif',save_all=True,append_images=death_gif[1:],
                      duration=50,loop=0,optimize=False,disposal=2)
    relative=Image.new('RGB',(SIZE*7,130),background)
    d=ImageDraw.Draw(relative)
    d.line((0,90,SIZE*7,90),fill='#64745a')
    for i,(kind,height) in enumerate(zip(KINDS,HEIGHTS)):
        frame=cycles[kind][0][2][0]
        bb=frame.getbbox()
        crop=frame.crop(bb)
        target=round(height*64)
        crop=crop.resize((round(crop.width*target/crop.height),target),Image.Resampling.NEAREST)
        relative.paste(crop,(i*SIZE+40-crop.width//2,90-target),crop)
        d.text((i*SIZE+3,100),kind,fill='#dfd4ac')
    relative.save('/tmp/gorcs-enemy-board-relative.png')
    relative.resize((1120,260),Image.Resampling.NEAREST).save('/tmp/gorcs-enemy-board-relative-enlarged.png')
    gif=[]
    # 3s walk, simultaneous heal/cast demonstration, then walk recovery. 50ms per image.
    for tick in range(120):
        time=tick*.05
        image=Image.new('RGB',(1120,224),background)
        draw=ImageDraw.Draw(image)
        for i,kind in enumerate(KINDS):
            name,speed,frames=cycles[kind][0]
            if kind in ('orc_chief','necorcmancer') and 3<=time<3+len(cycles[kind][1][2])/cycles[kind][1][1]:
                name,speed,frames=cycles[kind][1]
                index=min(len(frames)-1,int((time-3)*speed))
            else:
                index=int(time*speed)%len(frames)
            image.paste(frames[index].resize((160,160),Image.Resampling.NEAREST),(i*160,14),
                        frames[index].resize((160,160),Image.Resampling.NEAREST))
            draw.text((i*160+8,190),kind+' / '+name,fill='#dfd4ac')
        gif.append(image)
    gif[0].save('/tmp/gorcs-enemy-animation-preview.gif',save_all=True,append_images=gif[1:],
                duration=50,loop=0,optimize=False,disposal=2)


def gait_review(cycles):
    """Export directional evidence using the same numeric gait that draws the legs."""
    report={}
    for kind,stride in zip(KINDS,(5,5,9,4,4,3,6)):
        recovery=[gait(i*math.pi/12,stride)[0] for i in range(13)]
        stance=[gait(math.pi+i*math.pi/12,stride)[0] for i in range(13)]
        knee=gait(math.pi/2,stride)[2]
        # A left-moving actor's stance foot must move right in actor-local space.
        assert all(b>=a-1e-9 for a,b in zip(stance,stance[1:])), kind+' left stance reversed'
        assert all(b<=a+1e-9 for a,b in zip(recovery,recovery[1:])), kind+' left recovery reversed'
        assert knee<0, kind+' recovery knee must bend toward the left-facing front'
        mirrored_stance=[-x for x in stance]
        mirrored_recovery=[-x for x in recovery]
        assert all(b<=a+1e-9 for a,b in zip(mirrored_stance,mirrored_stance[1:])), kind+' right stance reversed'
        assert all(b>=a-1e-9 for a,b in zip(mirrored_recovery,mirrored_recovery[1:])), kind+' right recovery reversed'
        report[kind]={'stride_pixels':stride,'source_faces_left':True,
                      'left':{'airborne_front_recovery_x':recovery,'grounded_back_sweep_x':stance,
                              'recovery_knee_forward_x':knee},
                      'mirrored_right':{'airborne_front_recovery_x':mirrored_recovery,
                                        'grounded_back_sweep_x':mirrored_stance,
                                        'recovery_knee_forward_x':-knee},
                      'phase':{'airborne':'0 < q < pi','grounded':'pi < q < tau'}}
    Path('/tmp/gorcs-enemy-gait-audit.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet=Image.new('RGB',(960,32+len(KINDS)*216),'#27302b')
    draw=ImageDraw.Draw(sheet)
    draw.text((5,5),'Time ---> frame 00..11 | Near foot AIR 00..05, GROUND 06..11 | Far foot opposite',fill='#dfd4ac')
    for row,kind in enumerate(KINDS):
        for mirror in (False,True):
            y=32+row*216+(108 if mirror else 0)
            label=(kind+'   ---> RIGHT / mirrored: ground foot sweeps LEFT' if mirror
                   else kind+'   <--- LEFT / source: ground foot sweeps RIGHT')
            draw.text((5,y+2),label,fill='#dfd4ac')
            for f,im in enumerate(cycles[kind][0][2]):
                if mirror:
                    im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                sheet.paste(im,(f*80,y+18),im)
                draw.text((f*80+3,y+96),f'{f:02d}',fill='#b4c49c')
    sheet.save('/tmp/gorcs-enemy-walk-direction-contact.png')
    print('Gait authoring audit: seven left-facing stance sweeps right, recovery left; mirrored-right signs opposite.')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    cycles={}
    for kind in KINDS:
        animations=[('walk',FPS[kind],[pose(kind,i) for i in range(12)])]
        if kind=='orc_chief':
            animations.append(('heal',12/.55,[pose(kind,i,'heal') for i in range(12)]))
        if kind=='necorcmancer':
            animations.append(('cast',12/1.15,[pose(kind,i,'cast') for i in range(12)]))
        animations.append(('death',15,[death(kind,i) for i in range(12)]))
        export(kind,animations)
        cycles[kind]=animations
    previews(cycles)
    gait_review(cycles)
    print('Exported seven original 12-frame walks/deaths, .55s heal, 1.15s cast; review images/GIF in /tmp/gorcs-enemy-*.')


if __name__=='__main__':
    main()
