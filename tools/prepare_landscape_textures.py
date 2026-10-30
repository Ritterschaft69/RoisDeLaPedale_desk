"""Small seamless opaque material inputs; authoring only, no photo downloads."""
from pathlib import Path
import random,math
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/textures';folder.mkdir(exist_ok=True)
# Alpha is a colour mask only; the facade shader stays fully opaque.
im=Image.new('RGBA',(128,128),(255,255,255,0));d=ImageDraw.Draw(im)
d.rectangle((40,29,87,95),fill=(222,215,193,255))
d.rectangle((44,33,83,91),fill=(65,85,88,255))
d.rectangle((46,35,62,59),fill=(93,115,117,255))
d.rectangle((65,35,81,59),fill=(80,103,108,255))
d.rectangle((62,33,65,91),fill=(202,196,175,255));d.rectangle((44,60,83,63),fill=(202,196,175,255))
for x in [25,91]:
 d.rectangle((x,32,x+12,93),fill=(79,101,83,255))
 for y in range(37,90,6):d.line((x+2,y,x+10,y),fill=(62,82,67,255))
d.rectangle((38,94,89,98),fill=(187,181,160,255))
im.save(folder/'facade-window.png')
# Periodic overlapping crowns: one texture and a tiny baked bump map replace
# leaf meshes. Alpha is not used for transparency anywhere in the forest.
rng=random.Random(6909);blobs=[(rng.random(),rng.random(),rng.uniform(.035,.09),rng.uniform(.65,1.0)) for _ in range(95)]
heights=[]
for y in range(128):
 row=[]
 for x in range(128):
  u,v=x/128,y/128
  row.append(max(w*math.exp(-(min(abs(u-a),1-abs(u-a))**2+min(abs(v-b),1-abs(v-b))**2)/(r*r)) for a,b,r,w in blobs))
 heights.append(row)
im=Image.new('RGB',(128,128));normal=Image.new('RGB',(128,128))
for y in range(128):
 for x in range(128):
  t=heights[y][x];im.putpixel((x,y),(int(36+66*t),int(63+69*t),int(28+40*t)))
  dx=-(heights[y][(x+1)%128]-heights[y][(x-1)%128])*5
  dz=-(heights[(y+1)%128][x]-heights[(y-1)%128][x])*5
  length=math.sqrt(dx*dx+dz*dz+1)
  normal.putpixel((x,y),tuple(int(127.5*(1+n/length)) for n in (dx,dz,1)))
im.save(folder/'forest-canopy.png');normal.save(folder/'forest-normal.png')
print('LANDSCAPE_TEXTURES',folder)
