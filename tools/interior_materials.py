"""Distinct original interior materials, regenerated without altering the vista atlases."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
D=Path(__file__).resolve().parents[1]/'assets/textures';R=np.random.default_rng(50217);N=256

def cloud(n):
 return np.array(Image.fromarray(np.uint8(R.uniform(0,255,(n,n)))).resize((N,N),Image.Resampling.BILINEAR))/255-.5

def pbr(name,rgb,h,rough=.8,strength=2):
 Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(D/f'{name}.png')
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength
 normal=np.stack([-dx,dy,np.ones_like(h)],-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
 Image.fromarray(np.uint8((normal*.5+.5)*255)).save(D/f'{name}_normal.png')
 if np.isscalar(rough):rough=rough+R.normal(0,.045,h.shape)
 Image.fromarray(np.uint8(np.clip(rough,.14,.99)*255)).save(D/f'{name}_rough.png')

# Stone gets broad sediment and sparse pits, rather than uniform high-frequency speckling.
for name,base in [('floor_stone',(137,130,107)),('limestone',(161,145,114)),('hearth_stone',(112,104,83)),('vault_plaster',(133,143,135)),('floor_grout',(68,65,50))]:
 broad=cloud(9);grain=R.normal(0,1,(N,N));medium=cloud(40)
 rgb=np.array(base)[None,None,:]+(broad*38+medium*13+grain*3.0)[:,:,None]
 pits=R.random((N,N))<.018;rgb[pits]-=22
 h=.5+broad*.24+medium*.12+grain*.017-pits*.10
 pbr(name,rgb,h,.81,2.2)

# Iron is soot-dark with brushed, worn metal; ceramics retain coloured glaze and a clay rim.
y,x=np.mgrid[:N,:N];fine=R.normal(0,1,(N,N));patch=cloud(15)+cloud(45)*.25
rgb=np.zeros((N,N,3))+[43,41,34];rgb+=fine[:,:,None]*3
worn=patch>.15;rgb[worn]=np.array([117,106,77])+fine[worn,None]*5
# More edge wear on the upper/lower parts of the pot's UV profile.
edge=(y<24)|(y>230);rgb[edge]+=np.array([22,17,8])
pbr('iron_cook',rgb,.5+fine*.025+cloud(48)*.10,np.where(worn,.36,.72),2.1)
for name,base in [('glazed_ceramic',(43,93,88)),('earthenware',(145,81,47))]:
 patch=cloud(18);grain=R.normal(0,1,(N,N));rgb=np.array(base)[None,None,:]+patch[:,:,None]*25+grain[:,:,None]*3
 chip=(patch>.21)&((y<45)|(y>220));rgb[chip]=np.array([163,121,73])+grain[chip,None]*4
 rim=(y%64<4);rgb[rim]=np.array([177,142,76])+grain[rim,None]*4
 pbr(name,rgb,.5+patch*.08+grain*.012-chip*.06,np.where(chip,.88,.47),1.6)
# Leather has fine irregular grain and faded binding, with the gilt modeled separately.
rgb=np.zeros((N,N,3))+[151,125,91];rgb+=(cloud(18)*29+R.normal(0,3,(N,N)))[:,:,None]
pbr('book_leather',rgb,.5+cloud(40)*.10+R.normal(0,.025,(N,N)),.77,1.5)
# Food: root wrinkles, mottled mushroom caps and matte fruit pores.
wrinkles=np.sin(y*.8+np.sin(x*.07)*1.7)*.5+.5;scar=R.random((N,N))<.017
rgb=np.zeros((N,N,3))+[194,166,111];rgb+=(wrinkles*10+cloud(25)*19+R.normal(0,3,(N,N)))[:,:,None];rgb[scar]-=45
pbr('root',rgb,.5+wrinkles*.07+scar*.06,.8,1.7)
rgb=np.zeros((N,N,3))+[134,102,65];rgb+=(cloud(16)*57+cloud(45)*18+R.normal(0,2,(N,N)))[:,:,None]
pbr('mushroom',rgb,.5+cloud(45)*.15+R.normal(0,.012,(N,N)),.72,1.3)
for name,base in [('fruit_skin',(166,95,36)),('pomegranate',(119,39,32))]:
 grain=R.normal(0,1,(N,N));rgb=np.array(base)[None,None,:]+(cloud(16)*29+grain*3)[:,:,None]
 pbr(name,rgb,.5+grain*.021,.68,1.5)

# Soft, dispersed steam with irregular wisps; no rectangular opaque centre.
N2=128;yy,xx=np.mgrid[0:N2,0:N2];im=Image.new('L',(N2,N2));d=ImageDraw.Draw(im)
for i in range(12):
 cx=int(R.integers(32,96));cy=int(R.integers(18,110));r=int(R.integers(7,20))
 d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=int(R.integers(35,120)))
a=np.array(im.filter(ImageFilter.GaussianBlur(5))).astype(float)
fade=np.sin(np.pi*(xx+.5)/N2)**2*np.sin(np.pi*(yy+.5)/N2)**2;a*=fade
rgba=np.zeros((N2,N2,4),dtype='uint8');rgba[:,:,:3]=[209,220,214];rgba[:,:,3]=np.uint8(a)
Image.fromarray(rgba).save(D/'steam.png')
# Dapple leaves a substantial indirect-light floor instead of black holes.
im=Image.new('L',(256,256),105);d=ImageDraw.Draw(im)
for i in range(170):
 cx,cy=map(int,R.integers(0,256,2));r=int(R.integers(7,25));d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=int(R.integers(150,245)))
im.filter(ImageFilter.GaussianBlur(4)).convert('RGB').save(D/'dapple.png')
# Feathered moss/soil islands for planting beds and cracks.
N2=128;yy,xx=np.mgrid[:N2,:N2];rad=np.sqrt(((xx-64)/62)**2+((yy-64)/62)**2)
mask=np.clip((1-rad)*5+R.normal(0,.18,(N2,N2)),0,1)
rgba=np.zeros((N2,N2,4),dtype='uint8');rgba[:,:,:3]=np.uint8(np.clip(np.array([64,75,34])+R.normal(0,7,(N2,N2,1)),0,255));rgba[:,:,3]=np.uint8(mask*235)
Image.fromarray(rgba).save(D/'earth_patch.png')
print('Interior stone, soot iron, coloured ceramics, food, leather, soft steam and planting maps created.')
