"""Additional original low-resolution PBR textures and foliage cards for v0.3."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import math

OUT=Path(__file__).resolve().parents[1]/'assets/textures'
R=np.random.default_rng(3127)
N=256
def cloud(size=16):
    a=R.integers(0,255,(size,size),dtype=np.uint8)
    return np.asarray(Image.fromarray(a).resize((N,N),Image.Resampling.BILINEAR)).astype(float)/255-.5
def material(name,base,rough=.8,grain=1,cracks=False):
    c=cloud(9)*16+cloud(27)*11+cloud(64)*5+R.normal(0,1.7,(N,N))
    rgb=np.array(base)[None,None,:]+c[:,:,None]
    h=.5+c/170*grain
    if cracks:
        im=Image.fromarray(np.uint8(np.clip(rgb,0,255)))
        d=ImageDraw.Draw(im)
        for _ in range(7):
            x,y=map(int,R.integers(0,N,2)); pts=[(x,y)]
            for k in range(int(R.integers(3,8))):
                x+=int(R.integers(-12,18));y+=int(R.integers(5,14));pts.append((x,y))
            d.line(pts,fill=tuple(int(v*.65) for v in base),width=1)
        rgb=np.array(im)
    Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(OUT/f'{name}.png')
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*1.6
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))*1.6
    normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    Image.fromarray(np.uint8((normal*.5+.5)*255)).save(OUT/f'{name}_normal.png')
    Image.fromarray(np.uint8(np.clip(rough*255+c*.3,0,255))).save(OUT/f'{name}_rough.png')

material('plaster',(143,135,116),.96,.4,True)
material('stone_surface',(119,116,100),.88,1.1,True)
material('cave',(50,58,60),.96,3,True)
material('moss',(54,70,32),.99,2)
material('fruit_skin',(165,87,33),.43,.4)
material('pomegranate',(115,35,32),.42,.35)
material('cut_fruit',(221,158,74),.62,.3)
material('copper',(111,68,40),.44,.8)
material('vine',(65,62,37),.9,1)
material('cloth',(124,107,80),.99,.25)

# A heart-shaped ivy leaf: irregular silhouette, veins and muted natural colour.
for name,base in [('ivy_leaf',(74,96,39)),('tree_leaf',(76,102,47))]:
    im=Image.new('RGBA',(64,64))
    d=ImageDraw.Draw(im)
    if name=='ivy_leaf':
        pts=[(32,61),(23,44),(7,34),(15,23),(8,12),(25,17),(32,3),(39,17),(56,12),(49,24),(58,35),(42,44)]
    else:
        pts=[(32,63),(14,47),(10,25),(17,10),(32,1),(48,12),(55,29),(49,47)]
    d.polygon(pts,fill=(*base,255))
    mask=np.array(im)[:,:,3]
    a=np.array(im)
    for y in range(64):
        for x in range(64):
            if mask[y,x]:
                k=R.integers(-7,8)+(5 if x<32 else -5)
                a[y,x,:3]=np.clip(np.array(base)+k,0,255)
    im=Image.fromarray(a);d=ImageDraw.Draw(im)
    d.line([(32,58),(32,9)],fill=(113,126,68,245),width=1)
    for yy in [21,31,41]:
        d.line([(32,yy+12),(17,yy)],fill=(103,117,60,220),width=1)
        d.line([(32,yy+12),(47,yy)],fill=(103,117,60,220),width=1)
    im.save(OUT/f'{name}.png')

fern=Image.new('RGBA',(64,128));d=ImageDraw.Draw(fern)
d.line([(32,124),(32,5)],fill=(84,105,40,255),width=2)
for y in range(13,120,8):
    width=int(25*math.sin(y/128*math.pi))
    for side in [-1,1]:
        d.polygon([(32,y+9),(32+side*width,y-3),(32+side*int(width*.55),y+8),(32,y+14)],fill=(72+int(y/10),102+int(y/15),36,255))
fern.save(OUT/'fern.png')

# Warm pointed windows for the distant city; geometry supplies the building mass.
window=Image.new('RGBA',(48,80));d=ImageDraw.Draw(window)
d.polygon([(7,78),(7,26),(15,13),(24,2),(33,13),(41,26),(41,78)],fill=(225,148,54,255))
for y in [33,55,76]:d.line([(8,y),(40,y)],fill=(78,57,32,255),width=2)
for x in [17,31]:d.line([(x,20),(x,79)],fill=(89,64,34,255),width=2)
d.polygon([(10,76),(10,28),(16,18),(22,11),(22,76)],fill=(248,186,88,255))
window.save(OUT/'lit_window.png')

# Light-projector dapple supplied by the covered garden's luminous ceiling panel.
projector=Image.new('RGB',(256,256),(18,18,18));d=ImageDraw.Draw(projector)
for _ in range(150):
    x,y=map(int,R.integers(0,256,2));r=int(R.integers(4,22))
    c=int(R.integers(100,235));d.ellipse((x-r,y-r,x+r,y+r),fill=(c,c,c))
projector.filter(ImageFilter.GaussianBlur(3)).save(OUT/'dapple.png')
print('Added weathered surface maps, ivy/tree/fern cards, windows and dapple texture.')
