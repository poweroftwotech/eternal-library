"""Original pixel-scale surface design; separate colour, microrelief and roughness."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
D=Path(__file__).resolve().parents[1]/'assets/textures'
rng=np.random.default_rng(8081); N=256

def field(n):
 a=rng.random((n,n)).astype('float32')
 return np.asarray(Image.fromarray(a).resize((N,N),Image.Resampling.BILINEAR))-.5

def save(name,c,h,rough):
 Image.fromarray(np.uint8(np.clip(c,0,255))).save(D/f'{name}.png')
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))*1.7; dy=(np.roll(h,-1,0)-np.roll(h,1,0))*1.7
 v=np.stack([-dx,dy,np.ones_like(h)],axis=-1);v/=np.linalg.norm(v,axis=-1)[...,None]
 Image.fromarray(np.uint8((v*.5+.5)*255)).save(D/f'{name}_normal.png')
 Image.fromarray(np.uint8(np.clip(rough,0.15,1)*255)).save(D/f'{name}_rough.png')

for name,base in [('floor_stone',(137,115,83)),('limestone',(170,144,101)),('hearth_stone',(118,93,63)),('sandstone',(153,126,88)),('vault_plaster',(111,126,119))]:
 macro=field(12); fleck=np.repeat(np.repeat(rng.normal(0,1,(64,64)),4,0),4,1)
 patch=field(38); c=np.array(base)+ (macro*62+patch*32+fleck*8)[...,None]
 c+=np.stack([patch*12,patch*4,-patch*8],-1)
 pits=(field(90)>.27); h=.5+macro*.08+patch*.10+fleck*.018-pits*.10
 c[pits]-=22
 save(name,c,h,.82+patch*.18)
# Glazed geometric tesserae have coarse colour cells, quiet relief and selective glaze.
y,x=np.mgrid[:N,:N]; u=x//8;v=y//8
palette=np.array([[26,79,83],[34,107,113],[50,120,119],[161,122,65],[191,151,86],[74,70,47]])
pattern=((u+v)%8==0)|((u-v)%8==0)|((u%8==4)&(v%8==4))
idx=rng.integers(0,3,(32,32))[v,u];idx[pattern]=3+(u[pattern]+v[pattern])%2
c=palette[idx].astype(float)+rng.normal(0,3,(N,N,1)); grout=(x%8==0)|(y%8==0);c[grout]=[58,54,37]
h=np.where(grout,.25,.52);save('mosaic',c,h,np.where(grout,.96,.32+field(50)*.2))
# Oxidised hammered iron with broader patches, not sparkling white grain.
p=field(55)+field(12)*.3;hammer=np.repeat(np.repeat(rng.random((64,64)),4,0),4,1)
c=np.zeros((N,N,3))+[58,49,35];c+=(p*50+hammer*14)[...,None]
wear=(y<22)|((p>.12)&(y<220)); c[wear]+=np.array([45,34,19])
save('iron_cook',c,.5+hammer*.06+p*.08,np.where(wear,.32,.68))
for name,base in [('glazed_ceramic',(35,92,91)),('earthenware',(143,86,45))]:
 p=field(32);tiles=np.repeat(np.repeat(rng.normal(0,7,(64,64)),4,0),4,1)
 c=np.array(base)+(p*45+tiles)[...,None]
 motif=((x//8+y//8)%6==0)&(y%80<36);rim=(y%80<4)
 c[motif]=[183,141,73];c[rim]=[198,158,91]
 chips=p>.26;c[chips]=[144,112,70]
 save(name,c,.5+p*.06+chips*.05,np.where(chips,.9,.58+p*.15))
# Woven rug with a coherent border and several diamond medallions.
im=Image.new('RGB',(256,256),(78,37,31));d=ImageDraw.Draw(im)
for inset,col in [(3,(174,131,74)),(7,(28,68,69)),(17,(174,131,74)),(21,(105,43,30))]:d.rectangle((inset,inset,255-inset,255-inset),outline=col,width=4)
for cy in range(40,231,38):
 for cx in range(42,230,43):
  for r,col in [(19,(174,127,71)),(15,(33,73,74)),(10,(126,53,33)),(4,(205,168,102))]:
   d.polygon([(cx,cy-r),(cx+r,cy),(cx,cy+r),(cx-r,cy)],fill=col)
  for q in [-1,1]:d.line((cx-17,cy+q*3,cx-17,cy+q*9),fill=(174,127,71),width=2)
for cy in range(12,248,10):
 for cx in [12,243]:d.polygon([(cx,cy-3),(cx+3,cy),(cx,cy+3),(cx-3,cy)],fill=(174,131,74))
c=np.asarray(im).astype(float);grain=rng.normal(0,4,(N,N));c+=grain[...,None];save('rug',c,.5+((x+y)%2)*.025+grain*.001,.92+field(40)*.05)
print('Benchmark materials generated')
