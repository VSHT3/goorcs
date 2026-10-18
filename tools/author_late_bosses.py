#!/usr/bin/env python3
"""Author original late-game bosses with integer Pillow geometry and shared Pixels.

No downloaded art, model output, source sprite sampling, antialiasing or rotations.
Only this script's two named boss outputs are written; old enemy art is untouched.
Native contact sheets and animated working previews are exported under /tmp.
"""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw
from author_enemy_sprites import Pixels, segment, O, FE, LE, BO, GO, RED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/animations'
SK = ('#293e38', '#486453', '#73896b', '#a1b28a')
WOOD = ('#2c2420', '#51392b', '#805638', '#b98750')
IRON = ('#202c31', '#3b4c50', '#64787a', '#a6b8ac')
ORC = ('#2f3e28', '#56653b', '#8e9a53', '#c4cc7f')
GOLD = ('#574023', '#977036', '#d5ae56', '#ffe49a')
PURPLE = ('#302637', '#56364c', '#92556b', '#c8848e')
BG = '#26312e'


def lerp(a, b, t):
    return tuple(x+(y-x)*t for x,y in zip(a,b))


def disk(p, center, radius, ramp, spokes=0, phase=0):
    x,y = center
    points=[(x+math.cos(i*math.pi/6)*radius,y+math.sin(i*math.pi/6)*radius) for i in range(12)]
    p.p(points,ramp[0])
    p.p([(x+math.cos(i*math.pi/6)*(radius-3),y+math.sin(i*math.pi/6)*(radius-3)) for i in range(12)],ramp[1])
    if spokes:
        for i in range(spokes):
            a=phase+i*math.tau/spokes
            p.l([(x,y),(x+math.cos(a)*(radius-4),y+math.sin(a)*(radius-4))],ramp[2],3)
    p.p([(x-4,y-3),(x+3,y-4),(x+5,y+2),(x,y+5),(x-4,y+2)],ramp[2])
    p.r((x-2,y-2,x,y),ramp[3])
    p.l([(x-radius+3,y-6),(x-radius+6,y-radius+5),(x-2,y-radius+3)],ramp[3],2)


def rivet(p, x, y, gold=False):
    ramp=GOLD if gold else IRON
    p.r((x-1,y-1,x+2,y+2),ramp[0])
    p.r((x-1,y-1,x+1,y+1),ramp[2])
    p.r((x-1,y-1,x,y),ramp[3])


def plate(p, pts, ramp=IRON):
    p.p(pts,ramp[1])
    p.l(pts[:2],ramp[3],2)
    p.l(pts[1:3],ramp[2])


def tusk(p, x, y, flip=1, length=10):
    p.p([(x-3,y),(x-4,y-5),(x-2,y-length),(x+1,y-length-3),(x+1,y-5),(x+4,y-2)],BO[2])
    p.l([(x-2,y-3),(x-2,y-length+1),(x+1,y-length-3)],BO[3])


def troll_head(p):
    # Low cranial vault, immense projecting muzzle, separate ears and uneven tusks.
    p.p([(79,49),(61,40),(62,52),(75,62)],SK[1])
    p.p([(65,45),(69,51),(75,53)],SK[2],None)
    p.p([(107,47),(123,39),(119,54),(110,59)],SK[0])
    p.p([(82,31),(101,29),(112,35),(115,49),(110,63),(100,73),(80,70),(68,60),(68,47),(74,36)],SK[1])
    p.p([(77,37),(84,33),(99,33),(103,39),(94,43),(78,43),(72,48)],SK[2],None)
    p.p([(105,42),(112,43),(110,57),(102,65),(96,61),(100,49)],SK[0],None)
    p.p([(72,50),(82,46),(90,49),(89,57),(79,61),(67,58),(65,54)],SK[2])
    p.l([(68,54),(77,51),(83,52)],SK[3],2)
    p.r((68,57,73,59),SK[0])
    p.p([(71,61),(81,58),(99,57),(105,61),(100,70),(83,73),(73,69)],SK[1])
    p.l([(74,64),(82,65),(95,62),(101,61)],O,2)
    tusk(p,76,65,length=12)
    tusk(p,98,62,length=9)
    p.p([(70,44),(77,41),(84,44),(82,47),(72,47)],SK[0])
    p.r((73,45,79,47),'#151d1b')
    p.r((74,45,76,46),'#f4d58a')
    p.p([(92,43),(102,40),(106,43),(103,46),(94,47)],SK[0])
    p.r((96,44,102,46),'#151d1b')
    p.r((97,44,98,45),'#f4d58a')
    p.l([(102,48),(100,53),(103,55)],'#bdba93',2)
    p.l([(85,36),(91,35),(96,37)],SK[3])
    p.l([(85,69),(92,69),(96,66)],SK[2])
    for x,y in ((82,31),(89,29),(96,30),(104,32)):
        p.p([(x-2,y+2),(x-1,y-4),(x+2,y-2),(x+3,y+3)],SK[0])
    # Two unmistakable nose rings / ear studs, not a helmeted old enemy.
    p.p([(64,53),(64,58),(68,60),(71,57),(70,54),(68,55),(68,57),(66,56)],GOLD[2])
    rivet(p,117,50,True)


def club(p, hand, angle):
    # Long rough-hewn timber, redrawn around the hand for a real overhead arc.
    dx,dy=math.cos(angle),math.sin(angle)
    nx,ny=-dy,dx
    def q(distance,width):
        return hand[0]+dx*distance+nx*width,hand[1]+dy*distance+ny*width
    p.p([q(-8,-4),q(27,-5),q(28,5),q(-8,4)],WOOD[1])
    p.l([q(-5,-2),q(24,-2)],WOOD[3],2)
    p.p([q(20,-9),q(29,-15),q(57,-17),q(67,-10),q(68,10),q(59,17),q(29,14),q(20,8)],WOOD[1])
    p.p([q(24,-8),q(32,-12),q(58,-13),q(64,-8),q(60,-3),q(30,-2)],WOOD[2],None)
    p.l([q(26,-8),q(56,-10),q(62,-7)],WOOD[3],3)
    p.l([q(31,7),q(44,5),q(54,9),q(62,6)],WOOD[0],2)
    p.l([q(34,-6),q(42,-4),q(54,-6)],WOOD[0])
    for distance in (30,55):
        p.p([q(distance,-14),q(distance+5,-15),q(distance+5,15),q(distance,14)],IRON[1])
        p.l([q(distance+1,-12),q(distance+1,9)],IRON[3],2)
        for w in (-7,6):
            rivet(p,*q(distance+2,w))
    p.p([q(60,-11),q(66,-7),q(66,8),q(61,12),q(58,8),q(59,-7)],WOOD[2])
    p.l([q(61,-5),q(63,-1),q(61,5)],WOOD[0],2)


def troll(frame, action='walk'):
    image=Image.new('RGBA',(192,192))
    q=frame*math.tau/12
    bob=round(abs(math.sin(q))*2) if action=='walk' else 0
    lean=0
    if action=='attack':
        lean=(0,-1,-3,-4,-4,-3,1,5,7,5,2,0)[frame]
        bob=(0,-1,-2,-3,-4,-3,-1,4,6,4,2,0)[frame]
    if action=='death':
        t=frame/11
        bob=round(29*t)
        lean=-round(10*t)
    # Joint geometry is altered before rasterization, never pasted/rotated art.
    p=Pixels(image,x=-lean,y=bob,angle=-1.13*frame/11 if action=='death' else 0,pivot=(97,118))
    hip=(97,119)
    for side in (1,0):
        phase=q+(math.pi if side else 0)
        travel=math.cos(phase)*11 if action=='walk' else (5 if side else -4)
        lift=max(0,math.sin(phase))*8 if action=='walk' else 0
        hx=hip[0]+(14 if side else -12)
        if action=='death':
            knee=(hx+frame*.5,140+frame*1.8)
            foot=(hx+15,169+frame)
        else:
            knee=(hx+travel*.4-max(0,math.sin(phase))*5,143-lift*.4)
            foot=(hx+travel,169-lift-bob)
        segment(p,(hx,118),knee,12,10,SK)
        segment(p,knee,(foot[0],foot[1]-6),10,8,SK)
        p.p([(foot[0]-16,foot[1]-3),(foot[0]-11,foot[1]-9),(foot[0]+6,foot[1]-8),(foot[0]+10,foot[1]-3),(foot[0]+8,foot[1]+1),(foot[0]-15,foot[1]+1)],SK[1])
        p.l([(foot[0]-12,foot[1]-5),(foot[0]-2,foot[1]-6),(foot[0]+5,foot[1]-4)],SK[3],2)
        for tx in (-11,-5,1):
            p.p([(foot[0]+tx,foot[1]-2),(foot[0]+tx+3,foot[1]-2),(foot[0]+tx+3,foot[1]+1),(foot[0]+tx,foot[1]+1)],BO[2])
        p.p([(knee[0]-10,knee[1]-3),(knee[0]+9,knee[1]-5),(knee[0]+10,knee[1]+4),(knee[0]-8,knee[1]+6)],LE[1])
        p.l([(knee[0]-8,knee[1]),(knee[0]+7,knee[1]-1)],LE[3],2)
    # Far arm and shoulder behind the barrel torso.
    swing=round(math.cos(q)*5) if action=='walk' else 0
    segment(p,(118,73),(135+swing,94),13,11,SK)
    segment(p,(135+swing,94),(140+swing,120),11,9,SK)
    p.p([(133+swing,116),(138+swing,112),(146+swing,115),(150+swing,122),(145+swing,129),(135+swing,127)],SK[1])
    p.l([(135+swing,117),(141+swing,115),(146+swing,119)],SK[3],2)
    for x in (137,141,145):
        p.l([(x+swing,121),(x+swing,125)],SK[0])
    p.p([(74,65),(94,60),(116,66),(130,84),(128,108),(118,127),(94,133),(70,124),(61,105),(62,84)],SK[1])
    p.p([(75,72),(92,67),(108,73),(113,88),(109,103),(91,112),(70,105),(66,91)],SK[2],None)
    p.p([(75,78),(86,74),(92,78),(87,88),(73,91),(67,87)],SK[3],None)
    p.p([(94,76),(105,75),(112,80),(111,88),(94,91)],SK[2],None)
    p.l([(71,95),(81,97),(88,95)],SK[0],2)
    p.l([(94,96),(104,94),(113,96)],SK[0],2)
    p.p([(75,105),(91,101),(110,104),(118,113),(114,123),(98,129),(79,124),(69,115)],SK[2],None)
    p.p([(80,106),(92,104),(105,106),(104,111),(86,113),(76,111)],SK[3],None)
    p.l([(92,118),(95,120),(98,118)],SK[0],2)
    p.l([(76,118),(81,121),(87,121)],SK[1],2)
    # Scalloped abdominal folds, scars, mottled skin and broad muscle insertions.
    p.l([(113,105),(119,109),(120,115),(116,120)],SK[0],2)
    p.l([(76,113),(80,115),(87,115)],SK[2],2)
    p.l([(102,112),(109,110),(113,112)],SK[1],2)
    p.p([(120,87),(124,91),(123,101),(119,105),(117,99)],SK[0],None)
    p.p([(66,95),(70,101),(72,109),(68,108),(65,103)],SK[0],None)
    p.l([(103,101),(106,107),(111,111)],'#b9b59a',2)
    for x,y in ((79,102),(72,115),(112,85),(121,95),(84,117),(108,123)):
        p.r((x,y,x+2,y+1),SK[0])
        p.r((x,y-1,x+1,y-1),SK[2])
    # Diagonal leather baldric and iron buckle; hem made of individual leather scales.
    p.p([(112,66),(119,71),(82,128),(73,124)],LE[0])
    p.p([(112,69),(115,72),(80,124),(77,123)],LE[2],None)
    for x,y in ((105,82),(97,94),(89,106)):
        rivet(p,x,y,True)
    p.p([(90,101),(98,104),(92,114),(84,110)],GOLD[2])
    p.p([(91,104),(94,105),(91,110),(88,109)],LE[0])
    p.p([(69,120),(87,125),(111,123),(121,119),(123,132),(108,139),(81,140),(65,132)],LE[0])
    for x,y in ((67,127),(80,130),(94,131),(108,127)):
        p.p([(x,y),(x+11,y-1),(x+10,y+14),(x+5,y+17),(x-1,y+12)],LE[1])
        p.l([(x+2,y+2),(x+8,y+1)],LE[3],2)
        rivet(p,x+5,y+5)
    # Massive asymmetric spiked iron shoulder.
    plate(p,[(65,68),(74,63),(84,66),(90,77),(83,87),(62,86),(57,79)])
    p.p([(63,71),(69,57),(73,73)],BO[2])
    p.p([(77,68),(82,55),(85,74)],BO[2])
    p.l([(64,80),(81,81)],IRON[2],2)
    rivet(p,63,77)
    rivet(p,82,77)
    troll_head(p)
    if action=='attack':
        hands=[(57,113),(68,99),(83,89),(109,83),(119,80),(117,82),(85,90),(57,108),(52,115),(55,114),(57,114),(57,113)]
        angles=[2.0,2.8,3.7,4.05,4.15,4.15,3.1,2.1,1.6,1.65,1.9,2.0]
        hand=hands[frame]
        elbow=lerp((65,84),hand,.6)
    elif action=='death':
        hand=(54+frame*2,95-frame*3)
        elbow=(51,96-frame*.5)
        angles=None
    else:
        hand=(53-swing,117)
        elbow=(48-swing*.4,97)
        angles=None
    segment(p,(65,80),elbow,15,12,SK)
    segment(p,elbow,hand,12,10,SK)
    p.l([(elbow[0]-6,elbow[1]-2),(hand[0]-4,hand[1]-5)],SK[3],3)
    p.l([(elbow[0]+6,elbow[1]-3),(hand[0]+4,hand[1]-8)],SK[0],2)
    p.l([(59,84),(55,90),(56,96)],SK[2],3)
    p.l([(elbow[0]-3,elbow[1]+2),(elbow[0]+2,elbow[1]+3)],SK[0])
    # Thick wrapped wrist and gripping fingers overlap the handle.
    segment(p,lerp(elbow,hand,.72),hand,11,10,LE)
    club(p,hand,angles[frame] if angles else (1.8-frame*.10 if action=='death' else 2.0+math.cos(q)*.06))
    p.p([(hand[0]-9,hand[1]-5),(hand[0]-5,hand[1]-9),(hand[0]+5,hand[1]-7),(hand[0]+10,hand[1]-1),(hand[0]+8,hand[1]+6),(hand[0]+1,hand[1]+9),(hand[0]-8,hand[1]+5)],SK[1])
    p.p([(hand[0]-7,hand[1]-4),(hand[0]-4,hand[1]-7),(hand[0]+4,hand[1]-5),(hand[0]+5,hand[1]-1),(hand[0]-5,hand[1])],SK[2],None)
    for i in range(3):
        p.l([(hand[0]-6+i*4,hand[1]),(hand[0]-5+i*4,hand[1]+5)],SK[0])
        p.r((hand[0]-6+i*4,hand[1]-4,hand[0]-4+i*4,hand[1]-3),SK[3])
    if action=='attack' and frame in (7,8):
        impact=Pixels(image)
        for dx in (-14,-3,10,20):
            impact.p([(24+dx,174),(21+dx,170),(25+dx,169),(28+dx,172)],'#a4936c')
    return image


def crew(p,x,y,phase=0,king=False):
    if king:
        # Fat bejewelled king: huge belly, ermine robe, broad face and gold crown.
        p.p([(x-20,y+8),(x-26,y+32),(x-21,y+46),(x+20,y+47),(x+26,y+31),(x+17,y+9)],PURPLE[1])
        p.p([(x-17,y+9),(x-12,y+16),(x-18,y+38),(x-23,y+35)],BO[2])
        p.p([(x+12,y+12),(x+20,y+13),(x+24,y+35),(x+16,y+38)],BO[2])
        for ex,ey in ((-18,19),(-20,29),(19,22),(21,31)):
            p.r((x+ex,y+ey,x+ex+1,y+ey+2),O)
        p.p([(x-11,y+13),(x+10,y+12),(x+17,y+23),(x+16,y+36),(x+6,y+42),(x-10,y+41),(x-18,y+30),(x-16,y+20)],ORC[1])
        p.p([(x-10,y+17),(x+5,y+16),(x+11,y+23),(x+8,y+30),(x-10,y+31),(x-15,y+25)],ORC[2],None)
        p.p([(x-7,y+18),(x+1,y+17),(x+6,y+22),(x-1,y+24),(x-10,y+22)],ORC[3],None)
        p.l([(x-6,y+34),(x-2,y+36),(x+2,y+34)],ORC[0],2)
        p.p([(x-17,y+36),(x+16,y+35),(x+14,y+41),(x-12,y+44)],GOLD[1])
        p.r((x-4,y+37,x+3,y+42),GOLD[2])
        p.r((x-2,y+38,x+1,y+40),'#aa4146')
        # Royal sceptre and signet ring.
        p.l([(x+24,y+9),(x+20,y+35)],GOLD[0],5)
        p.l([(x+23,y+8),(x+19,y+33)],GOLD[2],2)
        disk(p,(x+24,y+6),5,GOLD)
        p.r((x+23,y+4,x+25,y+7),'#ac4754')
        hx,hy=x-3,y+2
    else:
        hx,hy=x,y
        p.p([(x-7,y+6),(x+6,y+5),(x+9,y+19),(x-8,y+20)],RED[1])
        p.l([(x-5,y+10),(x-10,y+14+phase),(x-12,y+18+phase)],ORC[2],4)
        p.l([(x+5,y+10),(x+11,y+12-phase),(x+14,y+10-phase)],ORC[2],4)
    p.p([(hx-7,hy-5),(hx-13,hy-8),(hx-11,hy-1),(hx-6,hy+3)],ORC[1])
    p.p([(hx+5,hy-5),(hx+12,hy-7),(hx+10,hy),(hx+5,hy+2)],ORC[1])
    p.p([(hx-6,hy-9),(hx+4,hy-10),(hx+9,hy-4),(hx+8,hy+5),(hx+2,hy+10),(hx-8,hy+7),(hx-11,hy+1)],ORC[2])
    p.p([(hx-7,hy-6),(hx+1,hy-7),(hx+4,hy-3),(hx-5,hy-2)],ORC[3],None)
    p.p([(hx-10,hy),(hx-4,hy-2),(hx+1,hy+1),(hx-1,hy+5),(hx-10,hy+4)],ORC[2])
    p.r((hx-7,hy-4,hx-3,hy-2),O)
    p.r((hx-6,hy-4,hx-5,hy-3),'#ffda86')
    p.r((hx+2,hy-4,hx+5,hy-2),O)
    p.r((hx+2,hy-4,hx+3,hy-3),'#ffda86')
    p.l([(hx-8,hy+5),(hx-2,hy+6),(hx+5,hy+3)],O)
    tusk(p,hx-6,hy+6,length=3)
    if king:
        p.p([(hx-10,hy-10),(hx-13,hy-20),(hx-6,hy-16),(hx-3,hy-25),(hx+2,hy-16),(hx+9,hy-22),(hx+9,hy-10)],GOLD[1])
        p.l([(hx-11,hy-19),(hx-7,hy-14),(hx-3,hy-23),(hx+2,hy-14),(hx+8,hy-21)],GOLD[3],2)
        p.r((hx-10,hy-12,hx+8,hy-9),GOLD[2])
        p.r((hx-2,hy-12,hx+1,hy-9),'#b63b4b')
    else:
        p.p([(hx-7,hy-9),(hx-3,hy-14),(hx+4,hy-12),(hx+7,hy-8)],IRON[1])
        p.l([(hx-5,hy-10),(hx+4,hy-10)],IRON[3])


def timber(p, box, vertical=False, damage=0):
    x1,y1,x2,y2=box
    p.r(box,WOOD[1])
    p.l([(x1,y2),(x1,y1),(x2,y1)],WOOD[3],2)
    if vertical:
        for x in range(round(x1)+5,round(x2),7):
            p.l([(x,y1+3),(x-1,y1+11),(x+1,y2-4)],WOOD[0])
        p.l([(x2-2,y1+3),(x2-2,y2-2)],WOOD[2],2)
    else:
        for y in range(round(y1)+4,round(y2),5):
            p.l([(x1+4,y),(x1+17,y-1),(x2-5,y)],WOOD[0])
        p.l([(x1+5,y1+3),(x2-5,y1+3)],WOOD[2])


def mechanical_leg(p, hip, phase, extend, back=False, ground=218):
    x,y=hip
    step=math.cos(phase)*9*extend
    lift=max(0,math.sin(phase))*9*extend
    knee=(x+(20 if back else -18)*extend,y+16+9*extend)
    foot=(x+(28 if back else -25)*extend+step,ground-lift)
    if extend<.4:
        foot=(x+12,y+27)
    segment(p,hip,knee,7,6,IRON)
    segment(p,knee,(foot[0],foot[1]-4),5,4,IRON)
    p.l([(x+2,y+3),(knee[0]+2,knee[1]-1)],GOLD[2],2)
    disk(p,knee,6,IRON)
    p.p([(foot[0]-11,foot[1]),(foot[0]-8,foot[1]-6),(foot[0]+8,foot[1]-6),(foot[0]+13,foot[1]-1),(foot[0]+12,foot[1]+2),(foot[0]-12,foot[1]+2)],IRON[1])
    p.l([(foot[0]-8,foot[1]-4),(foot[0]+7,foot[1]-4)],IRON[3],2)
    p.l([(foot[0]-5,foot[1]),(foot[0]-5,foot[1]+2)],O)


def cannon(p,x,y,recoil=0,flash=False):
    x+=recoil
    # Open left muzzle with elliptical stepped rings, bronze breach and iron bore.
    p.p([(x,y-8),(x+43,y-13),(x+54,y-5),(x+53,y+9),(x+42,y+15),(x,y+10)],IRON[0])
    p.p([(x+1,y-7),(x+40,y-10),(x+49,y-4),(x+47,y+1),(x+1,y+3)],IRON[2],None)
    p.l([(x+5,y-6),(x+37,y-8),(x+44,y-5)],IRON[3],2)
    for bx in (10,34):
        p.p([(x+bx,y-8),(x+bx+5,y-9),(x+bx+5,y+11),(x+bx,y+12)],GOLD[1])
        p.l([(x+bx+1,y-6),(x+bx+1,y+7)],GOLD[3],2)
    p.p([(x-5,y-8),(x+2,y-9),(x+7,y-3),(x+7,y+6),(x+2,y+12),(x-5,y+10),(x-9,y+4),(x-9,y-3)],IRON[1])
    p.p([(x-4,y-4),(x,y-5),(x+3,y-1),(x+3,y+5),(x,y+8),(x-4,y+6),(x-6,y+2)],'#10191b')
    p.l([(x-6,y-4),(x-3,y-7),(x+1,y-7)],IRON[3],2)
    if flash:
        p.p([(x-8,y-5),(x-18,y-10),(x-15,y-4),(x-31,y-5),(x-22,y+1),(x-37,y+6),(x-22,y+7),(x-24,y+15),(x-13,y+10),(x-8,y+6)],'#d67b36',None)
        p.p([(x-9,y-2),(x-20,y-4),(x-17,y+2),(x-26,y+5),(x-16,y+7),(x-10,y+4)],'#ffe4a0',None)


def war_machine(frame,action='walk',damage=0):
    image=Image.new('RGBA',(256,256))
    q=frame*math.tau/(8 if action=='jump_charge' else 12)
    bob=round(math.sin(q*2)) if action in ('walk','legs') else 0
    squash=0
    if action=='jump_charge':
        squash=round(frame/7*10)
    if action=='jump':
        # Global flight trajectory belongs to accepted presentation position.
        # Art changes suspension/crew/leg articulation, never adds a second arc.
        squash=(7,3,0,-2,-3,-3,-3,-2,0,2,5,2)[frame]
    p=Pixels(image,x=-round(frame/11*18) if action=='death' else 0,y=bob+squash,angle=.29*frame/11 if action=='death' else 0,pivot=(128,195))
    leg_mode=action in ('legs','attack','cast','jump_charge','jump','death')
    extend=1 if leg_mode else .18
    if action=='jump':
        extend=(.8,.6,.35,.25,.2,.2,.2,.3,.5,.8,1,.9)[frame]
    if action=='jump_charge':
        extend=1-frame/7*.22
    wheel_phase=q if action=='walk' else 0
    leg_phase=q if action=='legs' else 0
    wheel_lift=8 if leg_mode else 0
    # Three-dimensional chassis, far wheels and articulated far support legs.
    mechanical_leg(p,(182,162),leg_phase+math.pi,extend,True,218-bob-squash)
    mechanical_leg(p,(82,160),leg_phase,extend,False,218-bob-squash)
    for x,y,r in ((92,185,24),(199,181,25)):
        disk(p,(x,y-bob-squash-wheel_lift),r,WOOD,8,-wheel_phase)
        disk(p,(x,y-bob-squash-wheel_lift),r-5,IRON,6,-wheel_phase)
    p.p([(54,159),(173,143),(226,161),(215,194),(94,209),(49,190)],IRON[0])
    p.p([(52,171),(175,158),(221,171),(211,188),(91,201),(51,187)],WOOD[1])
    timber(p,(63,178,181,188))
    plate(p,[(51,163),(171,149),(175,161),(51,177)])
    p.l([(62,170),(169,157)],IRON[2],2)
    for x in (64,86,110,135,159):
        rivet(p,x,168-(x-64)*.11)
    # Tall two-storey rear troop hold with actual paired hinged doors.
    p.p([(153,94),(208,87),(232,104),(230,169),(176,181),(151,165)],WOOD[0])
    p.p([(207,90),(230,105),(228,167),(206,158)],WOOD[1])
    for x in (211,218,225):
        p.l([(x,109+(x-211)*.4),(x-1,155+(x-211)*.4)],WOOD[2],2)
    openness=(0,.1,.25,.55,.9,1,1,1,.8,.5,.2,0)[frame] if action=='cast' else 0
    p.p([(177,109),(218,108),(218,164),(178,172)],'#151b1b')
    # Door planes hinge outward, revealing dark hold and waiting Orclings.
    if openness>.25:
        crew(p,195,135,round(math.sin(q)*2))
        crew(p,208,143,-round(math.sin(q)*2))
    for side in (0,1):
        hinge=177 if side==0 else 219
        inside=198 if side==0 else 198
        edge=inside+(-28 if side==0 else 28)*openness
        top=110+(4 if side else 0)*openness
        p.p([(hinge,109),(edge,top),(edge,164),(hinge,171 if side==0 else 164)],WOOD[1])
        p.l([(hinge+1,111),(edge,top+2)],WOOD[3],2)
        p.l([(hinge,137),(edge,134)],IRON[1],4)
        p.l([(hinge,160),(edge,156)],IRON[1],4)
        for frac in (.3,.65):
            xx=hinge+(edge-hinge)*frac
            p.l([(xx,115),(xx,159)],WOOD[0])
        rivet(p,hinge+(-2 if side else 2),134)
    # Timber cabin and angled front armour with intentional plank clusters.
    p.p([(61,98),(145,88),(174,107),(171,168),(66,183),(47,164),(48,111)],WOOD[0])
    for n in range(5):
        y=107+n*12
        timber(p,(53,y,167,y+10))
    p.p([(51,108),(62,104),(66,178),(56,175)],IRON[1])
    p.l([(54,109),(60,172)],IRON[3],2)
    p.p([(157,99),(169,105),(168,168),(159,170)],IRON[1])
    p.l([(160,103),(161,166)],IRON[3],2)
    # Cross braces, bolts, angular ram and skull heraldry.
    segment(p,(63,165),(150,109),4,4,IRON)
    segment(p,(66,111),(149,163),4,4,IRON)
    for x,y in ((62,113),(66,162),(149,112),(149,160),(105,137)):
        rivet(p,x,y,True)
    p.p([(45,156),(57,151),(64,165),(56,182),(42,178),(35,169)],IRON[1])
    p.p([(39,160),(34,145),(46,157)],BO[2])
    p.p([(40,175),(28,181),(35,166)],BO[2])
    p.l([(43,161),(51,158),(58,165)],IRON[3],2)
    # Two independent cannon decks, offset in depth and elevation.
    recoil=(0,0,0,0,0,0,0,0,2,7,5,2)[frame] if action=='attack' else 0
    cannon(p,67,124,recoil,action=='attack' and frame in (9,10))
    cannon(p,94,94,recoil*.7,action=='attack' and frame in (9,10))
    # Exposed machinery below cabin: gear, chain, hot chimney and piston.
    disk(p,(161,174),13,IRON,8,q)
    disk(p,(137,182),8,GOLD,6,-q)
    p.l([(134,176),(157,162),(170,168),(145,188),(134,176)],IRON[0],3)
    p.l([(135,176),(157,164),(168,168)],IRON[2])
    timber(p,(165,79,174,108),True)
    p.p([(171,82),(178,78),(183,81),(183,114),(176,115)],IRON[1])
    p.l([(174,84),(174,106)],IRON[3],2)
    p.r((172,79,183,83),IRON[0])
    # Upper deck railing, little left-facing cannon crew and rear engineer.
    p.p([(83,72),(177,63),(211,81),(112,95),(75,82)],WOOD[1])
    p.l([(82,74),(176,66),(205,81)],WOOD[3],2)
    crew(p,96,64,round(math.sin(q)*2))
    crew(p,190,75,round(math.cos(q)*2))
    p.l([(80,80),(111,90),(209,77)],IRON[1],4)
    p.l([(80,78),(111,88),(209,75)],IRON[3])
    for x,y in ((82,80),(112,88),(157,82),(207,77)):
        p.l([(x,y),(x,y+12)],IRON[1],3)
        rivet(p,x,y)
    # Ornate royal throne, red canopy poles, king silhouette stays intact in damage.
    p.p([(118,41),(155,36),(168,49),(163,80),(129,85),(115,74)],GOLD[0])
    p.p([(122,43),(154,39),(163,49),(159,76),(130,80),(120,73)],PURPLE[1])
    p.l([(123,45),(153,42),(159,49)],GOLD[2],3)
    for x,y in ((126,44),(151,41),(159,49)):
        rivet(p,x,y,True)
    crew(p,140,35+round(math.sin(q)),king=True)
    p.p([(120,79),(162,74),(172,80),(129,88),(117,85)],GOLD[1])
    p.l([(122,80),(161,77),(166,79)],GOLD[3],2)
    for x in (128,138,149,159):
        rivet(p,x,82-(x-128)*.14,True)
    # Royal pennant is individually articulated and loses cloth with damage.
    p.l([(206,79),(207,34)],IRON[0],4)
    p.l([(206,77),(207,34)],GOLD[2])
    wave=round(math.sin(q)*3)
    p.p([(208,36),(227,37+wave),(222,43+wave),(231 if damage<2 else 221,51+wave),(208,49)],PURPLE[1])
    p.l([(210,38),(224,39+wave)],PURPLE[3],2)
    p.r((212,41,216,45),GOLD[2])
    # Near wheels rotate in road poses; legs have genuinely separate knee/foot poses.
    for x,y,r in ((82,197,23),(188,192,25)):
        y-=bob+squash+wheel_lift
        disk(p,(x,y),r,IRON,0)
        disk(p,(x,y),r-4,WOOD,8,-wheel_phase)
        disk(p,(x,y),7,IRON)
        for a in range(8):
            aa=a*math.tau/8-wheel_phase
            rivet(p,x+math.cos(aa)*(r-2),y+math.sin(aa)*(r-2))
    mechanical_leg(p,(71,174),leg_phase+math.pi,extend,False,218-bob-squash)
    mechanical_leg(p,(182,170),leg_phase,extend,True,218-bob-squash)
    # All actions receive phase-specific structural damage, never a palette swap.
    if damage:
        p.p([(110,145),(119,139),(127,141),(121,151),(129,157),(118,164),(109,159)],WOOD[0])
        p.l([(114,146),(119,148),(116,156),(121,161)],'#121c1e',3)
        p.l([(116,142),(120,145),(118,149)],WOOD[3])
        p.l([(61,112),(70,118),(67,127),(75,132)],'#172326',3)
        p.l([(62,113),(68,118),(65,125)],WOOD[3])
        p.p([(199,113),(211,117),(209,128),(202,132),(195,124)],'#202726')
        p.l([(201,115),(207,120),(203,127)],WOOD[3],2)
        for x,y in ((87,154),(143,120),(178,153),(207,158)):
            p.l([(x,y),(x+4,y-4),(x+9,y-3)],IRON[0],2)
            p.l([(x,y+1),(x+4,y-2)],IRON[2])
        # Faceted opaque smoke puffs, fully binary alpha; small at damaged phase.
        for i in range(3 if damage==1 else 5):
            sx=179+round(math.sin(q+i)*4)+i*4
            sy=76-i*9-round((frame+i)%4)
            rr=4+i//2
            p.p([(sx-rr,sy),(sx-rr,sy-rr),(sx,sy-rr-2),(sx+rr,sy-rr),(sx+rr+1,sy+2),(sx,sy+rr)],'#46514c' if i%2 else '#303c3a',None)
            p.l([(sx-rr+1,sy-rr+1),(sx,sy-rr)],'#69716a')
    if damage==2:
        # Missing cabin section, exposed jagged beams, open embers and broken rim.
        p.p([(132,146),(150,135),(159,140),(157,158),(143,169),(127,162)],'#131e20')
        p.p([(133,147),(139,141),(142,151),(149,147),(147,159),(137,163)],'#9b492b',None)
        p.p([(136,150),(139,145),(140,156),(144,152),(142,160),(136,160)],'#efa75a',None)
        p.l([(128,147),(136,141),(141,142)],WOOD[3],2)
        p.l([(147,164),(155,157),(154,149)],WOOD[2],2)
        p.p([(59,151),(63,146),(69,151),(66,155),(75,159),(70,164),(58,158)],WOOD[0])
        p.p([(204,188),(211,184),(215,190),(214,200),(205,210),(202,205),(209,198)],IRON[0])
        p.l([(210,188),(212,191),(211,197)],IRON[2],2)
        p.l([(169,111),(174,118),(172,131),(179,140)],'#10191c',3)
        for x,y in ((154,155),(180,97),(142,160)):
            px=x+round(math.sin(q+x)*2)
            p.r((px,y-frame%4,px+1,y+2-frame%4),'#ffd087')
    if action=='death':
        # Buckling chassis, falling timbers and final grounded wreck, no alpha fade.
        for i in range(4):
            x=48+i*43+round(math.sin(i+q)*5)
            y=213-squash+min(frame,7)
            timber(p,(x,y,x+17,y+4))
        if frame>3:
            p.p([(108,151),(120,144),(126,152),(123,168),(113,171)],'#182427')
            p.l([(112,150),(116,155),(113,167)],'#c88b45',2)
    return image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(kind,size,anchor,animations,identity):
    # One animation per atlas row keeps each PNG comfortably below GPU limits.
    sheet=Image.new('RGBA',(size*12,size*len(animations)))
    entries=[]
    for row,(name,fps,frames,loop) in enumerate(animations):
        for col,image in enumerate(frames):
            sheet.alpha_composite(image,(col*size,row*size))
            entries.append((row,col,image))
    sheet_path=OUT/f'{kind}.png'
    sheet.save(sheet_path,optimize=True)
    still=OUT/f'{kind}_still.png'
    animations[0][2][0].save(still,optimize=True)
    lines=[f'[gd_resource type="SpriteFrames" load_steps={len(entries)+2} format=3]','',f'[ext_resource type="Texture2D" path="res://assets/enemies/animations/{kind}.png" id="1_sheet"]','']
    for index,(row,col,_) in enumerate(entries):
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]','atlas = ExtResource("1_sheet")',f'region = Rect2({col*size}, {row*size}, {size}, {size})','']
    lines += ['[resource]','animations = [']
    offset=0
    for row,(name,fps,frames,loop) in enumerate(animations):
        lines+=['{','"frames": [']
        for index in range(len(frames)):
            lines+=['{','"duration": 1.0,',f'"texture": SubResource("Frame_{offset+index}")','},' if index+1<len(frames) else '}']
        lines += ['],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps:.12f}','},' if row+1<len(animations) else '}']
        offset+=len(frames)
    lines += [']','']
    (OUT/f'{kind}.tres').write_text('\n'.join(lines))
    manifest={
        'authoring':'Original local integer-coordinate pixel geometry. Articulated anatomy, mechanical joints, crew, material planes and wear clusters authored in generator; no image sampling, raster rotation, AI image generation or external assets.',
        'identity':identity,'generator':'tools/author_late_bosses.py','generator_sha256':digest(Path(__file__)),
        'shared_pixel_primitives':'tools/author_enemy_sprites.py: Pixels, segment and material ramps',
        'source_origin':'Locally authored Pillow geometry; no external artist or service credits claimed',
        'frame_size':[size,size],'sheet_size':list(sheet.size),'layout':'one animation per row, up to 12 columns',
        'base_anchor':anchor,'source_faces_left':True,
        'alpha':'binary 0/255; crisp native pixels, no antialiasing or alpha fading',
        'camera':'elevated three-quarter left-facing; upper-left material highlights',
        'sheet_sha256':digest(sheet_path),'still':str(still.relative_to(ROOT)),'still_sha256':digest(still),
        'still_dimensions':[size,size],
        'damage_phase_thresholds':{'damaged':.66,'critical':.33} if kind=='orc_war_machine' else {},
        'action_support':'Mechanical legs visible for attack/cast in every damage phase; jump displacement supplied by accepted presentation position' if kind=='orc_war_machine' else 'Overhead club windup, heavy ground follow-through, articulated opposed walk and collapse',
        'animations':[{'name':name,'fps':fps,'duration_seconds':len(frames)/fps,'frame_count':len(frames),'loop':loop,'atlas_row':row,'alpha_bounds':[list(im.getbbox()) for im in frames]} for row,(name,fps,frames,loop) in enumerate(animations)]}
    (OUT/f'{kind}.json').write_text(json.dumps(manifest,indent=2)+'\n')


def contact(kind,size,animations):
    # Native pixels, four representative frames per row; labels stay outside sprites.
    result=Image.new('RGB',(size*4,(size+22)*len(animations)),BG)
    d=ImageDraw.Draw(result)
    for row,(name,fps,frames,_) in enumerate(animations):
        y=row*(size+22)
        d.text((5,y+3),f'{kind} / {name} / {len(frames)/fps:.2f}s',fill='#e4d9b7')
        indices=(0,4,9,11) if kind=='orc_war_machine' and name.startswith('attack') else (0,len(frames)//3,len(frames)*2//3,len(frames)-1)
        for col,index in enumerate(indices):
            image=frames[index]
            result.paste(image,(col*size,y+22),image)
    path=Path(f'/tmp/gorcs-{kind}-contact-native.png')
    result.save(path)
    if kind=='orc_war_machine':
        for phase in range(3):
            result.crop((0,phase*7*(size+22),size*4,(phase+1)*7*(size+22))).save(f'/tmp/gorcs-{kind}-phase-{phase}-native.png')
    walk=animations[0][2]
    gif=[]
    for image in walk:
        canvas=Image.new('RGB',(size*2,size*2),BG)
        big=image.resize((size*2,size*2),Image.Resampling.NEAREST)
        canvas.paste(big,(0,0),big)
        gif.append(canvas)
    gif[0].save(f'/tmp/gorcs-{kind}-walk.gif',save_all=True,append_images=gif[1:],duration=160,loop=0,disposal=2)
    return path


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    troll_animations=[('walk',7.5,[troll(i) for i in range(12)],True),('attack',12/1.25,[troll(i,'attack') for i in range(12)],False),('death',10,[troll(i,'death') for i in range(12)],False)]
    machine_animations=[]
    machine_spec=(('walk',12,8,True),('legs',12,7,True),('attack',12,12/1.4,False),('cast',12,10,False),('jump_charge',8,8/2.5,False),('jump',12,8,False),('death',12,10,False))
    for damage,suffix in ((0,''),(1,'_damaged'),(2,'_critical')):
        for action,count,fps,loop in machine_spec:
            machine_animations.append((action+suffix,fps,[war_machine(i,action,damage) for i in range(count)],loop))
    export('troll',192,[.5,.89],troll_animations,'Gargantuan bare-skinned tusked troll; muscular barrel belly, iron shoulder, diagonal leather straps, tremendous bound-timber club.')
    export('orc_war_machine',256,[.5,.86],machine_animations,'Multi-storey timber-and-riveted-iron siege crawler; rotating wheels, articulated outrigger legs, two bronze-banded cannons, working rear troop doors, two orc crew and obese crowned king in ermine throne.')
    for kind,size,animations in (('troll',192,troll_animations),('orc_war_machine',256,machine_animations)):
        print(contact(kind,size,animations))
    overview=Image.new('RGB',(640,300),BG)
    d=ImageDraw.Draw(overview)
    for x,name,size in ((40,'troll',192),(330,'orc_war_machine',256)):
        image=Image.open(OUT/f'{name}_still.png')
        overview.paste(image,(x,255-round(size*(.89 if name=='troll' else .86))),image)
        d.text((x,275),name,fill='#e4d9b7')
    overview.save('/tmp/gorcs-late-boss-lineup-native.png')
    overview.resize((1280,600),Image.Resampling.NEAREST).save('/tmp/gorcs-late-boss-lineup-enlarged.png')
    print('/tmp/gorcs-late-boss-lineup-native.png')


if __name__=='__main__':
    main()
