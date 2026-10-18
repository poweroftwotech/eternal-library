"""Fit the original book atlas into the pointed niche opening; preserve PBR maps."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
out=Path(__file__).resolve().parents[1]/'assets/textures'
w,h=256,400
polygon=[(-1.37,0),(-1.37,2.2)]
radius,rise=1.37,1.82
center=(radius*radius-rise*rise)/(2*radius)
cr=radius-center; angle=math.atan2(rise,-center)
for i in range(1,49):
 u=i/48;t=1-abs(2*u-1);sign=-1 if u<.5 else 1
 polygon.append((sign*(center+cr*math.cos(angle*t)),2.2+cr*math.sin(angle*t)))
polygon.append((1.37,0))
mask=Image.new('L',(w,h),0)
ImageDraw.Draw(mask).polygon([((x/2.75+.5)*w,(1-y/4.2)*h) for x,y in polygon],fill=255)
for suffix in ['', '_normal','_rough']:
 src=Image.open(out/f'stack_atlas{suffix}.png')
 target=Image.new(src.mode,(w,h))
 for y in range(0,h,src.height):target.paste(src,(0,y))
 if not suffix:target=target.convert('RGBA');target.putalpha(mask)
 target.save(out/f'gorge_books{suffix}.png')
print('Created pointed book inset maps')
