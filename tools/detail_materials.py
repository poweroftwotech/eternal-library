"""Original granular PBR maps, library facade atlases and woven artwork for v0.4."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import math
D=Path(__file__).resolve().parents[1]/'assets/textures'; R=np.random.default_rng(44119);N=256

def pbr(name,rgb,height,rough=.65,strength=2.0):
 rgb=np.clip(rgb,0,255).astype('uint8');Image.fromarray(rgb).save(D/f'{name}.png')
 dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
 dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
 normals=np.stack([-dx,dy,np.ones_like(dx)],-1);normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
 Image.fromarray(np.uint8(np.clip(normals*.5+.5,0,1)*255)).save(D/f'{name}_normal.png')
 if np.isscalar(rough):rough=rough+R.normal(0,.09,height.shape)
 Image.fromarray(np.uint8(np.clip(rough,.13,1)*255)).save(D/f'{name}_rough.png')

# Preserve authored patterns while adding granular pigment, chips and mineral glints.
for name in ['sandstone','brick','paving','plaster','wood','bark','stone_surface','tile','book','pages','ceramic','iron','copper']:
 base=np.array(Image.open(D/f'{name}.png').convert('RGB').resize((N,N),Image.Resampling.NEAREST)).astype(float)
 old=np.array(Image.open(D/f'{name}_normal.png').convert('RGB').resize((N,N),Image.Resampling.NEAREST)).astype(float)/127.5-1
 grain=R.normal(0,1,(N,N));coarse=np.array(Image.fromarray(np.uint8(R.uniform(0,255,(64,64)))).resize((N,N),Image.Resampling.NEAREST))/255-.5
 amplitude=9 if name in ['book','pages','wood'] else 13
 pigment=grain*amplitude+coarse*15
 pits=R.random((N,N))<.032;flecks=R.random((N,N))<.023
 base+=pigment[:,:,None];base[pits]*=.60;base[flecks]+=R.uniform(18,35)
 h=grain*.055+coarse*.13-pits*.16+flecks*.06
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))*1.4;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*1.4
 normal=old.copy();normal[:,:,0]-=dx;normal[:,:,1]+=dy;normal[:,:,2]=np.maximum(normal[:,:,2],.5)
 normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
 Image.fromarray(np.uint8(np.clip(base,0,255))).save(D/f'{name}.png')
 Image.fromarray(np.uint8(np.clip(normal*.5+.5,0,1)*255)).save(D/f'{name}_normal.png')
 rough={'tile':.42,'iron':.57,'copper':.46,'ceramic':.49,'book':.70}.get(name,.72)+R.normal(0,.105,(N,N))
 rough[flecks]=R.uniform(.18,.36,np.count_nonzero(flecks));rough[pits]=.94
 Image.fromarray(np.uint8(np.clip(rough,.12,.99)*255)).save(D/f'{name}_rough.png')

# Arch stones use pitted stone, without another rectangular brick grid on the voussoirs.
a=np.array(Image.open(D/'stone_surface.png').convert('RGB')).astype(float)*[1.17,1.11,1.02]
pbr('arch_stone',a,R.normal(.5,.07,(N,N)),.70,2.7)

# Small-scale geometric mosaic, usable on spandrels, pilasters and coffered ceilings.
im=Image.new('RGB',(N,N),(21,55,65));dr=ImageDraw.Draw(im)
for cy in range(0,N+1,64):
 for cx in range(0,N+1,64):
  for rad,col in [(31,(168,127,62)),(27,(23,77,85)),(21,(126,102,60))]:
   pts=[(cx+math.cos(k*math.pi/4)*rad,cy+math.sin(k*math.pi/4)*rad) for k in range(8)]
   dr.line(pts+[pts[0]],fill=col,width=2)
  for k in range(8):
   t=k*math.pi/4
   dr.line([(cx,cy),(cx+math.cos(t)*23,cy+math.sin(t)*23)],fill=(198,163,82),width=1)
  dr.ellipse((cx-4,cy-4,cx+4,cy+4),fill=(40,103,107))
rgb=np.array(im).astype(float)+R.normal(0,10,(N,N,1));h=np.mean(rgb,2)/255*.20+R.normal(.4,.045,(N,N))
pbr('mosaic',rgb,h,.43,2.0)

# Dense shelves at correct local book scale; warm varied bindings, gilt bands and scrolls.
im=Image.new('RGB',(256,256),(31,25,20));d=ImageDraw.Draw(im)
palette=[(91,42,29),(46,74,72),(126,92,48),(75,61,43),(42,49,49),(111,58,42),(130,112,73)]
for row in range(8):
 y=row*32;d.rectangle((0,y,255,y+3),fill=(114,80,40));d.line((0,y+4,255,y+4),fill=(45,32,23))
 x=2
 while x<254:
  w=int(R.integers(4,10));h=int(R.integers(20,27));c=palette[int(R.integers(0,len(palette)))];bottom=y+31
  d.rectangle((x,bottom-h,x+w-1,bottom-1),fill=c)
  d.line((x,bottom-h,x,bottom-1),fill=tuple(min(255,int(v*1.4)) for v in c))
  for yy in [bottom-h+3,bottom-4]:d.line((x+1,yy,x+w-2,yy),fill=(164,131,74))
  if w>6:d.line((x+2,bottom-12,x+w-3,bottom-12),fill=(167,143,99))
  x+=w+1
rgb=np.array(im).astype(float)+R.normal(0,5,(N,N,1));pbr('stack_atlas',rgb,np.mean(rgb,2)/255*.30+R.normal(.45,.03,(N,N)),.69,2.1)

# A repeatable, four-storey architectural facade: shelves, recessed galleries, lamps.
im=Image.new('RGB',(256,256),(57,63,57));d=ImageDraw.Draw(im)
books=Image.open(D/'stack_atlas.png')
for row in range(4):
 for col in range(4):
  x=col*64;y=row*64
  d.rectangle((x+4,y+8,x+59,y+57),fill=(13,24,28))
  im.paste(books.resize((46,40)),(x+9,y+16))
  d.line([(x+4,y+57),(x+4,y+18),(x+17,y+8),(x+32,y+3),(x+47,y+8),(x+59,y+18),(x+59,y+57)],fill=(133,116,76),width=3)
  d.rectangle((x,y+59,x+63,y+63),fill=(111,98,69));d.line((x,y+59,x+63,y+59),fill=(175,143,85))
  d.rectangle((x,y+5,x+3,y+58),fill=(34,79,79))
  if R.random()>.18:
   d.rectangle((x+30,y+43,x+34,y+53),fill=(237,166,69));d.point((x+32,y+42),fill=(255,221,137))
rgb=np.array(im).astype(float)+R.normal(0,4,(N,N,1));pbr('library_facade',rgb,np.mean(rgb,2)/255*.30,.65,1.7)

# Three original woven wall hangings, with ornamental borders and tree/bird motifs.
for j in range(3):
 im=Image.new('RGB',(256,384),(71,29,28) if j!=1 else (24,59,68));d=ImageDraw.Draw(im)
 for inset,col in [(4,(180,139,67)),(10,(33,68,77)),(17,(162,120,58)),(25,(37,59,62))]:d.rectangle((inset,inset,255-inset,383-inset),outline=col,width=3)
 for y in range(30,360,24):
  for x in [17,238]:d.polygon([(x,y-7),(x+6,y),(x,y+7),(x-6,y)],outline=(203,160,77))
 for x in range(38,228,24):
  for y in [17,366]:d.ellipse((x-4,y-4,x+4,y+4),outline=(184,146,78),width=2)
 d.line([(128,323),(128,142),(135,92),(128,57)],fill=(197,156,82),width=5)
 for i in range(7):
  y=130+i*25
  for side in [-1,1]:
   x=128+side*(30+(i%3)*12);d.line([(128,y+23),(x,y)],fill=(175,135,65),width=3)
   d.ellipse((x-12,y-7,x+12,y+7),outline=(203,164,91),width=2)
 # Symmetric stylized birds in the lower field.
 for side in [-1,1]:
  x=128+side*52
  d.ellipse((x-11,275,x+11,295),fill=(177,136,65));d.line([(x,281),(x-side*21,254),(x-side*36,261)],fill=(203,163,83),width=5)
  d.ellipse((x-4,260,x+5,270),fill=(204,169,100));d.line([(x,291),(x+side*18,312)],fill=(178,135,70),width=3)
 a=np.array(im).astype(float);weave=R.normal(0,7,a.shape[:2]);weave[::2]+=6;a+=weave[:,:,None]
 Image.fromarray(np.uint8(np.clip(a,0,255))).save(D/f'tapestry_{j}.png')
print('Granular normal/roughness maps, mosaic, shelf/facade atlases, and 3 woven artworks created.')
