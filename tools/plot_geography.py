"""Export a reproducible audit overview of the actual geographic caches.

Optional authoring dependency: matplotlib. Not used by the game or CI.
"""
import json
import math
import struct
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from circuit_geography import ROOT,OUT,Terrain,polynomial_terms


def main():
    entries=json.loads((ROOT/'assets/routes/catalog.json').read_text())
    terrain=Terrain()
    fig,axes=plt.subplots(3,2,figsize=(13,14),layout='constrained')
    fig.suptitle('Trois circuits reconstruits · OpenStreetMap + IGN LiDAR HD',fontsize=17,fontweight='bold')
    for row,entry in enumerate(entries):
        directory=OUT/entry['id']
        raw=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
        metadata=json.loads((directory/'route.json').read_text())
        world=json.loads((directory/'world.json').read_text())
        points=list(struct.iter_unpack('<ffff',(directory/'route.bin').read_bytes()))
        minimum=[min(p[i] for p in points)-800 for i in (0,2)]
        maximum=[max(p[i] for p in points)+800 for i in (0,2)]
        nx,ny=140,140
        raster=[]
        transform=world['terrain_transform']
        for j in range(ny):
            line=[]
            z=maximum[1]-(maximum[1]-minimum[1])*j/(ny-1)
            for i in range(nx):
                x=minimum[0]+(maximum[0]-minimum[0])*i/(nx-1)
                terms=polynomial_terms(x,z)
                lx=sum(a*b for a,b in zip(transform['x'],terms));ly=sum(a*b for a,b in zip(transform['y'],terms))
                h=terrain.at(lx,ly)
                line.append(h if h is not None else math.nan)
            raster.append(line)
        ax=axes[row,0]
        ax.imshow(raster,extent=[minimum[0]/1000,maximum[0]/1000,-maximum[1]/1000,-minimum[1]/1000],origin='lower',cmap='terrain',alpha=.55)
        roads=json.loads((directory/'osm_environment.json').read_text())['roads']
        ax.add_collection(LineCollection([[(p[0]/1000,-p[2]/1000) for p in road['points']] for road in roads],colors='#627171',linewidths=.25,alpha=.5))
        ax.plot([p[0]/1000 for p in points],[ -p[2]/1000 for p in points],color='#db541c',linewidth=1.2)
        ax.plot(points[0][0]/1000,-points[0][2]/1000,'o',color='#143e3a',ms=5)
        ax.set_aspect('equal');ax.set_xlabel('Est local (km)');ax.set_ylabel('Nord local (km)')
        ax.set_title(entry['short_name']+' · '+f"{metadata['length_m']/1000:.2f} km reconstruits",fontsize=11)
        ax=axes[row,1]
        ax.plot([p['s']/1000 for p in raw['points']],[p['alt'] for p in raw['points']],color='#a2a7a9',linewidth=.7,label='GPX original, référentiel vertical inconnu')
        ax.plot([p[3]/1000 for p in points],[p[1] for p in points],color='#175b51',linewidth=1,label='Route simulée · IGN69 · altitude filtrée')
        ax.set_xlabel('Station dans le GPX source (km)');ax.set_ylabel('Altitude (m)')
        ax.grid(alpha=.2);ax.legend(loc='upper right',fontsize=8)
        ax.set_title(f"Recalage réseau : {metadata['osm_match']['matched_fraction']*100:.2f} % · pas ≤ 2 m",fontsize=11)
    fig.text(.5,.001,'© OpenStreetMap contributors · ODbL 1.0 | IGN BD TOPO / LiDAR HD · Licence Ouverte 2.0 | acquisitions du 27/10/2026',ha='center',fontsize=8)
    path=ROOT/'docs/previews/v0.6.0-geographie.png'
    fig.savefig(path,dpi=140)
    print(path)


if __name__=='__main__':main()
