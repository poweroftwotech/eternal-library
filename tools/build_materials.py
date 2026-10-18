"""Original, deterministic low-resolution material maps. Optional regeneration only.
Run with Python + Pillow + NumPy. Godot needs only the generated PNG files.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(7331)
N = 128

def save_material(name, rgb, height, roughness=.85, strength=2.4):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(rgb).save(OUT / f'{name}.png')
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    norm = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    norm /= np.linalg.norm(norm, axis=-1, keepdims=True)
    Image.fromarray(((norm * .5 + .5) * 255).astype(np.uint8)).save(OUT / f'{name}_normal.png')
    rough = np.clip(roughness * 255 + RNG.normal(0, 7, height.shape), 0, 255).astype(np.uint8)
    Image.fromarray(rough).save(OUT / f'{name}_rough.png')

def noise(base, amount=7):
    fine = RNG.integers(-amount, amount+1, (N,N,1))
    broad = np.array(Image.fromarray(RNG.integers(0,255,(16,16),dtype=np.uint8)).resize((N,N),Image.Resampling.NEAREST))
    return np.array(base)[None,None,:] + fine + (broad[:,:,None] / 255 - .5) * amount * 2

def masonry(name, base, rows, cols, mortar, weather=8):
    rgb = noise(base, weather)
    h = RNG.uniform(.53,.57,(N,N))
    bw, bh = N//cols, N//rows
    for y in range(N):
        row=y//bh
        for x in range(N):
            xx=(x+(bw//2 if row%2 else 0))%N
            cell=xx//bw
            jitter=math.sin((row+1)*18.13+(cell+2)*7.91)*11
            rgb[y,x] += jitter
            edge=min(xx % bw, bw-1-(xx % bw), y%bh, bh-1-(y%bh))
            if edge < 1:
                rgb[y,x] = np.array(mortar) + RNG.integers(-4,5)
                h[y,x] = .27
            elif edge < 2:
                rgb[y,x] *= .78
                h[y,x] = .43
            elif edge < 3:
                rgb[y,x] += 8
                h[y,x] = .56
    # Small chips are local pixel features, not a blurry photographic overlay.
    for _ in range(175):
        x,y=RNG.integers(0,N,2)
        rgb[y,x] *= RNG.uniform(.65,.95)
        h[y,x] -= .08
    save_material(name,rgb,h,.9,1.5)

masonry('sandstone',(142,120,87),4,3,(63,61,48))
masonry('brick',(111,76,49),8,4,(58,56,44))
masonry('paving',(112,112,94),4,4,(46,55,47),9)

rgb=noise((154,140,111),8)
h=RNG.uniform(.47,.55,(N,N))
for _ in range(70):
    x,y=RNG.integers(0,N,2); size=int(RNG.integers(1,5))
    rgb[y:y+size,x:x+size] *= .72
    h[y:y+size,x:x+size]=.42
save_material('plaster',rgb,h,.94,1.0)

rgb=noise((75,53,34),6)
h=np.full((N,N),.5)
for x in range(N):
    grain=math.sin(x*.43+math.sin(x*.11)*3)*10+math.sin(x*1.9)*4
    rgb[:,x]+=grain
    h[:,x]+=grain/180
for x in [0,31,32,63,64,95,96,127]:
    rgb[:,x] *= .55; h[:,x]=.25
for _ in range(60):
    x,y=RNG.integers(0,N,2); length=int(RNG.integers(4,30))
    rgb[y:y+length,x] *= .65; h[y:y+length,x]-=.1
save_material('wood',rgb,h,.82,1.2)

rgb=noise((82,73,44),10)
h=RNG.uniform(.35,.65,(N,N))
for _ in range(180):
    x,y=RNG.integers(0,N,2)
    rgb[y,x]=[53,72,36] if _%3 else [115,106,79]
save_material('soil',rgb,h,.96,1.2)

rgb=noise((69,54,34),6)
h=RNG.uniform(.4,.6,(N,N))
for x in range(N):
    for y in range(N):
        g=math.sin(x*.7+math.sin(y*.08)*2)
        rgb[y,x]+=g*14; h[y,x]+=g*.16
save_material('bark',rgb,h,.91,1.1)

rgb=noise((43,91,86),5)
h=np.full((N,N),.52)
for y in range(N):
    for x in range(N):
        xx=x%32; yy=y%32
        d=abs(xx-15.5)+abs(yy-15.5)
        if 12<d<15 or (abs(xx-15.5)<2 and abs(yy-15.5)<2):
            rgb[y,x]=[174,142,76];h[y,x]=.55
        if xx<1 or yy<1:
            rgb[y,x]=[54,64,56];h[y,x]=.31
save_material('tile',rgb,h,.28,1.2)

palette=np.array([[103,43,34],[154,106,61],[39,71,76],[189,155,94],[63,48,37]])
rgb=np.zeros((N,N,3))
h=np.full((N,N),.5)
for y in range(N):
    for x in range(N):
        border=min(x,y,N-x-1,N-y-1)
        if border<4: index=3
        elif border<12: index=2 if (x//4+y//4)%2 else 3
        elif border<16: index=4
        else:
            xx=(x-16)%32;yy=(y-16)%32
            d=abs(xx-15.5)+abs(yy-15.5)
            index=3 if d<5 else (2 if 12<d<16 else 0)
        rgb[y,x]=palette[index]+RNG.integers(-6,7)
        rgb[y,x]*=.9 if y%2 else 1
save_material('rug',rgb,h,.99,.15)

rgb=noise((76,68,53),12)
h=RNG.uniform(.43,.55,(N,N))
for _ in range(55):
    x,y=RNG.integers(0,N,2);size=int(RNG.integers(1,6))
    rgb[y:y+size,x:x+size]=np.array([102,59,33])+RNG.integers(-8,9)
save_material('iron',rgb,h,.58,1.2)

rgb=noise((139,85,50),6);h=RNG.uniform(.48,.52,(N,N))
for y in range(N):
    rgb[y]+=math.sin(y*.7)*3
    if 15<y%64<19 or 24<y%64<27:
        rgb[y]=np.array([57,111,105])+RNG.integers(-5,6,(N,1))
save_material('ceramic',rgb,h,.44,.4)

rgb=noise((151,130,89),6);h=RNG.uniform(.48,.52,(N,N))
for y in range(N):
    if y%3==0: rgb[y]*=.64
save_material('pages',rgb,h,.97,.3)

rgb=noise((130,119,96),7);h=RNG.uniform(.48,.53,(N,N))
for y in [9,13,55,59,105,109]:
    rgb[y:y+2]=np.array([192,161,87])+RNG.integers(-8,9,(min(2,N-y),N,1))
for x in [6,121]:rgb[:,x]*=.56
save_material('book',rgb,h,.78,.5)

rgb=noise((181,153,90),5);h=RNG.uniform(.48,.52,(N,N))
for y in range(N):
    rgb[y]+=math.sin(y*.4)*7
save_material('root',rgb,h,.85,.5)

rgb=noise((126,98,65),8);h=RNG.uniform(.48,.52,(N,N))
for _ in range(90):
    x,y=RNG.integers(0,N,2);rgb[y:y+2,x:x+2]*=1.4
save_material('mushroom',rgb,h,.79,.5)

# Texture cards: deliberately modest pixel counts, transparent backgrounds.
leaf=Image.new('RGBA',(32,64));d=ImageDraw.Draw(leaf)
d.polygon([(16,1),(27,14),(28,31),(21,48),(16,61),(7,46),(3,29),(6,13)], fill=(81,110,41,255))
d.polygon([(16,2),(18,29),(16,61),(11,46),(9,25)], fill=(111,134,56,255))
d.line([(16,4),(16,61)],fill=(154,157,75,255),width=1)
for y in [16,26,36,46]:
    d.line([(16,y+6),(7,y)],fill=(113,135,55,255),width=1)
    d.line([(16,y+6),(25,y)],fill=(57,84,34,255),width=1)
leaf.save(OUT/'leaf.png')

grass=Image.new('RGBA',(64,64));d=ImageDraw.Draw(grass)
for _ in range(22):
    x=int(RNG.integers(8,57));top=int(RNG.integers(4,39));lean=int(RNG.integers(-15,16))
    d.polygon([(x-2,63),(x+lean,top),(x+2,63)],fill=(int(RNG.integers(63,110)),int(RNG.integers(80,122)),35,255))
grass.save(OUT/'grass.png')

for name,kind in [('flame','fire'),('steam','steam')]:
    pixels=np.zeros((64,32,4),dtype=np.uint8)
    for y in range(64):
        for x in range(32):
            yy=y/63;xx=(x-15.5)/16
            if kind=='fire':
                width=.06+yy*.57
                center=math.sin(yy*9)*.11
                v=max(0,1-abs(xx-center)/width)
                a=v*(math.sin(yy*math.pi)**.4)
                color=(255, min(255,int(85+v*155)),int(15+v*v*105))
            else:
                v=max(0,1-(xx*xx+((yy-.5)*1.4)**2))
                a=v*v*.7;color=(194,204,198)
            pixels[y,x]=[*color,int(a*255)]
    Image.fromarray(pixels).save(OUT/f'{name}.png')
print(f'Generated {len(list(OUT.glob("*.png")))} original texture maps.')
