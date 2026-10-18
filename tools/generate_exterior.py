"""Original low-resolution faience and feather relief; deterministic PBR maps."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, math
OUT=Path(__file__).resolve().parents[1]/'assets/textures'
rng=np.random.default_rng(19371)

def maps(name,im,h):
    a=np.array(im).astype(float)
    n=rng.normal(0,3,a.shape[:2])
    a=np.clip(a+n[:,:,None],0,255).astype('uint8')
    Image.fromarray(a).save(OUT/f'{name}.png')
    v=np.array(h).astype(float)/255
    dy,dx=np.gradient(v)
    normals=np.dstack((-dx*5,-dy*5,np.ones_like(dx)))
    normals/=np.linalg.norm(normals,axis=2,keepdims=True)
    Image.fromarray(((normals*.5+.5)*255).astype('uint8')).save(OUT/f'{name}_normal.png')
    Image.fromarray(np.clip(150-v*55+rng.normal(0,9,v.shape),45,210).astype('uint8')).save(OUT/f'{name}_rough.png')

im=Image.new('RGB',(256,256),(18,47,77));d=ImageDraw.Draw(im)
h=Image.new('L',im.size,70);q=ImageDraw.Draw(h)
for y in range(0,256,64):
 for x in range(0,256,64):
    d.rectangle((x+1,y+1,x+62,y+62),outline=(43,104,120),width=2)
    cx=x+32;cy=y+32
    pts=[]
    for i in range(16):
        r=28 if i%2==0 else 13
        pts.append((cx+math.cos(i*math.pi/8)*r,cy+math.sin(i*math.pi/8)*r))
    d.polygon(pts,fill=(24,80,108),outline=(189,143,64));q.polygon(pts,fill=165)
    d.ellipse((cx-5,cy-5,cx+5,cy+5),fill=(193,151,77));q.ellipse((cx-5,cy-5,cx+5,cy+5),fill=210)
    d.line((x+2,y+32,x+14,y+32),fill=(199,158,79),width=2)
maps('exterior_faience',im,h)
im=Image.new('RGB',(256,256),(20,41,61));d=ImageDraw.Draw(im)
h=Image.new('L',im.size,40);q=ImageDraw.Draw(h)
# Stylised standing winged guardian. Original low-resolution bas-relief artwork.
def shape(points,fill=(164,135,85),level=166):
 d.polygon(points,fill=fill,outline=(211,183,123));q.polygon(points,fill=level)
for side in [-1,1]:
 for row in range(3):
  for i in range(13):
    root=(128+side*(9+row*6),142-row*6)
    tip=(128+side*(35+row*7+i*3),53+i*7.8+row*7)
    v=np.array(tip)-root;v=v/np.linalg.norm(v);perp=np.array([-v[1],v[0]])*(3.9-row*.6)
    pts=[root,tuple(np.array(tip)-v*12+perp),tip,tuple(np.array(tip)-v*12-perp)]
    shape(pts,(135+row*13,112+row*10,73),140+row*27)
    d.line((root,tip),fill=(67,60,45),width=1)
# Pleated long robe, shoulders, belt, boots, face, beard and crenellated crown.
shape([(112,113),(145,113),(151,162),(159,211),(101,211),(108,161)],(160,136,91),189)
for x in range(108,155,6):
 d.line((128+(x-128)*.48,145,x,209),fill=(97,84,59),width=2)
 d.line((130+(x-128)*.48,146,x+2,209),fill=(207,177,115),width=1)
shape([(109,116),(101,139),(93,163),(98,168),(111,149),(120,129)])
shape([(143,118),(153,139),(171,146),(174,139),(156,130),(150,115)])
shape([(112,209),(124,209),(124,219),(108,219)],(143,122,84))
shape([(136,209),(149,209),(154,219),(136,219)],(143,122,84))
d.rectangle((109,147,148,153),fill=(205,171,104));q.rectangle((109,147,148,153),fill=219)
d.ellipse((116,74,142,103),fill=(186,159,111),outline=(221,192,139));q.ellipse((116,74,142,103),fill=222)
shape([(116,95),(141,95),(140,111),(130,122),(117,109)],(100,88,65),208)
for x in range(119,141,4):
 for y in range(98,115,4):
  d.arc((x-2,y-2,x+2,y+2),0,300,fill=(197,161,98),width=1)
d.rectangle((114,66,143,78),fill=(168,139,85),outline=(221,185,115));q.rectangle((114,66,143,78),fill=231)
for x in range(114,143,7):
 d.rectangle((x,59,x+4,68),fill=(194,159,96));q.rectangle((x,59,x+4,68),fill=238)
d.ellipse((135,84,138,87),fill=(38,43,43))
d.line((174,83,174,220),fill=(195,162,97),width=3);q.line((174,83,174,220),fill=225,width=3)
shape([(174,73),(179,84),(174,91),(169,84)],(208,179,120))
# Dense engraved border and corner rosettes tie the art into the architecture.
for inset in [4,9,17]:
 d.rectangle((inset,inset,255-inset,255-inset),outline=(157,130,80),width=2);q.rectangle((inset,inset,255-inset,255-inset),outline=175,width=2)
for x,y in [(31,31),(225,31),(31,225),(225,225)]:
 for i in range(8):
  a=i*math.pi/4;cx=x+math.cos(a)*7;cy=y+math.sin(a)*7
  d.ellipse((cx-2,cy-2,cx+2,cy+2),fill=(193,161,98));q.ellipse((cx-2,cy-2,cx+2,cy+2),fill=200)
for z in range(48,222,12):
 d.polygon([(12,z-4),(15,z),(12,z+4),(9,z)],outline=(189,151,88))
 d.polygon([(244,z-4),(247,z),(244,z+4),(241,z)],outline=(189,151,88))
maps('wing_relief',im,h)
print('Created six exterior PBR maps')
