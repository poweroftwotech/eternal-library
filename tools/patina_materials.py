"""Adds coarse chipped pigment alongside the fine granular maps. Run after detail_materials."""
from pathlib import Path
from PIL import Image
import numpy as np
D=Path(__file__).resolve().parents[1]/'assets/textures';R=np.random.default_rng(41991);N=256
for name in ['stone_surface','arch_stone','sandstone','ceramic','iron','copper']:
 a=np.array(Image.open(D/f'{name}.png').convert('RGB')).astype(float)
 cells=np.uint8(R.uniform(0,255,(32,32)))
 patches=np.array(Image.fromarray(cells).resize((N,N),Image.Resampling.NEAREST))/255
 broad=np.array(Image.fromarray(np.uint8(R.uniform(0,255,(12,12)))).resize((N,N),Image.Resampling.BILINEAR))/255
 p=patches*.58+broad*.42
 if name in ['iron','copper']:
  worn=p>.58
  a[worn]=a[worn]*.42+np.array([173,115,49])*.58
  a[p<.34]*=.56
 elif name=='ceramic':
  worn=p>.67;a[worn]=a[worn]*.3+np.array([190,149,90])*.7
  a[p<.31]*=.64
 else:
  a+=(p-.5)[:,:,None]*48
 Image.fromarray(np.uint8(np.clip(a,0,255))).save(D/f'{name}.png')
# Emission comes from lamps, while book surfaces retain shaded colour and relief.
a=np.array(Image.open(D/'library_facade.png').convert('RGB')).astype(float)
lamps=(a[:,:,0]>180)&(a[:,:,1]>120)&(a[:,:,2]<130)
emit=a*.025;emit[lamps]=a[lamps]
Image.fromarray(np.uint8(np.clip(emit,0,255))).save(D/'library_facade_emission.png')
print('Added chipped patina and a separate facade lamp emission mask.')
