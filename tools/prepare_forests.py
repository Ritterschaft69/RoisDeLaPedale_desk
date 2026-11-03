"""Bake IGN forest parcels as shared canopy envelopes, never individual trees.

Authoring: .venv/bin/python tools/prepare_forests.py [--circuit ID]
No acquisition. Polygon holes, roads, buildings and water remain openings.
Runtime reads only nearby 256 m cells, and needs no Shapely or Python.
"""
import argparse,hashlib,json,math,struct,gzip
from pathlib import Path
from collections import defaultdict
from functools import lru_cache
from shapely import Polygon,LineString,Point,box,make_valid,constrained_delaunay_triangles
from shapely.ops import unary_union
from shapely.prepared import prep
from circuit_geography import Terrain,polynomial_terms
ROOT=Path(__file__).resolve().parents[1]
TILE=256;STEP=32


def polygon_parts(shape):
    if shape.is_empty:return []
    if shape.geom_type=='Polygon':return [shape]
    return [p for child in getattr(shape,'geoms',[]) for p in polygon_parts(child)]


def forest_mask(world,roads):
    # Hedges, vineyards, orchards and moorland are not closed forest stands.
    selected=[make_valid(Polygon(z['rings'][0],z['rings'][1:])) for z in world['vegetation']
              if z['nature'] in ('Bois','Forêt fermée de feuillus','Forêt fermée mixte','Forêt ouverte','Forêt fermée de conifères','Peupleraie')]
    forest=unary_union(selected).simplify(.65,preserve_topology=True)
    exclusions=[]
    for road in roads:
        line=road['points']
        if len(line)>1:
            kind=road.get('tags',{}).get('highway','')
            radius=4 if kind in ('path','footway','cycleway','track') else 10
            exclusions.append(LineString([(p[0],p[2]) for p in line]).simplify(.5).buffer(radius,quad_segs=2))
    for b in world['buildings']:exclusions.append(Polygon(b['footprint']).buffer(4,quad_segs=2))
    for w in world.get('water',[]):
        vertices=w['points'];indices=list(map(int,w['indices']))
        triangles=[Polygon([(vertices[j][0],vertices[j][2]) for j in indices[i:i+3]]) for i in range(0,len(indices),3)]
        if triangles:exclusions.append(unary_union(triangles).buffer(1,quad_segs=2))
    if exclusions:forest=forest.difference(unary_union(exclusions))
    return make_valid(forest)


def crown_mesh(x,z,height,conifer,survey):
    """Small shared-shape crown cluster; interpreted foliage, not a tree survey."""
    leaves=[];trunks=[]
    def point(dx,y,dz):
        px,pz=round(x+dx,3),round(z+dz,3);ground,_=survey(px,pz)
        return None if ground is None else (px,ground+y,pz,ground)
    radius=min(4.4,max(2.1,height*.24))
    if conifer:
        rings=[(.34,1),(.55,.86),(.77,.50),(1,.02)]
        for level in range(3):
            for j in range(6):
                corners=[]
                for k,n in [(level,j),(level,j+1),(level+1,j+1),(level+1,j)]:
                    y,r=rings[k];angle=n*math.tau/6
                    r*=1+.12*math.sin(n*2.4+k)
                    corners.append(point(math.cos(angle)*radius*r,height*y,math.sin(angle)*radius*r))
                for face in [(0,1,2),(0,2,3)]:leaves.append(tuple(corners[k] for k in face))
    else:
        t=(1+math.sqrt(5))/2
        vertices=[(-1,t,0),(1,t,0),(-1,-t,0),(1,-t,0),(0,-1,t),(0,1,t),(0,-1,-t),(0,1,-t),(t,0,-1),(t,0,1),(-t,0,-1),(-t,0,1)]
        faces=[(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),(1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),(3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),(4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
        for offset,cy,ry,scale in [(-.25,.70,.28,1.0),(.30,.81,.22,.84)]:
            blob=[]
            for vx,vy,vz in vertices:
                norm=math.sqrt(vx*vx+vy*vy+vz*vz)
                blob.append(point(radius*(offset+vx/norm*scale),height*(cy+vy/norm*ry),radius*vz/norm*scale))
            leaves.extend(tuple(blob[i] for i in face) for face in faces)
    for j in range(5):
        a=j*math.tau/5;b=(j+1)*math.tau/5;r=max(.12,min(.30,height*.012))
        q=[point(math.cos(a)*r,-.15,math.sin(a)*r),point(math.cos(b)*r,-.15,math.sin(b)*r),point(math.cos(b)*r*.4,height*.68,math.sin(b)*r*.4),point(math.cos(a)*r*.4,height*.68,math.sin(a)*r*.4)]
        trunks.extend([(q[0],q[1],q[2]),(q[0],q[2],q[3])])
    return leaves,trunks


def bake(entry):
    directory=ROOT/'assets/geodata/circuits'/entry['id']
    world=json.loads((directory/'world.json').read_text())
    roads=json.loads((directory/world['roads_file']).read_text())['roads']
    mask=forest_mask(world,roads)
    route=[(p[0],p[2]) for p in struct.iter_unpack('<ffff',(directory/'route.bin').read_bytes())]
    mask=mask.intersection(LineString(route[::8]+[route[-1]]).buffer(1800,quad_segs=3))
    mask=mask.difference(LineString(route).buffer(12,quad_segs=2))
    prepared=prep(mask);fringe_zone=prep(LineString(route[::6]+[route[-1]]).buffer(110,quad_segs=3));terrain=Terrain();projection=world['terrain_transform'];tiles=defaultdict(list)
    for polygon in polygon_parts(mask):
        left,bottom,right,top=polygon.bounds
        for tx in range(math.floor(left/TILE),math.floor(right/TILE)+1):
            for tz in range(math.floor(bottom/TILE),math.floor(top/TILE)+1):tiles[tx,tz].append(polygon)
    data=bytearray();records=[];missing=0;triangle_count=0
    @lru_cache(maxsize=160000)
    def survey(x,z):
        terms=polynomial_terms(x,z)
        e=sum(a*b for a,b in zip(projection['x'],terms));n=sum(a*b for a,b in zip(projection['y'],terms))
        ground=terrain.at(e,n);height=terrain.at(e,n,'mnh')
        return ground,height
    print(entry['id'],'forest mask km2',round(mask.area/1e6,2),'tiles',len(tiles),flush=True)
    for number,((tx,tz),polygons) in enumerate(sorted(tiles.items())):
        tilebox=box(tx*TILE,tz*TILE,(tx+1)*TILE,(tz+1)*TILE)
        local=unary_union(polygons).intersection(tilebox)
        if local.is_empty:continue
        # Raster clearings must become real holes before computing the canopy
        # margin, otherwise a skipped cell leaves a roof suspended in the air.
        nearby=unary_union(polygons)
        clearings=[]
        for cx in range(tx*TILE-STEP,(tx+1)*TILE+STEP,STEP):
            for cz in range(tz*TILE-STEP,(tz+1)*TILE+STEP,STEP):
                _,height=survey(cx+STEP*.5,cz+STEP*.5)
                if height is not None and height<3:clearings.append(box(cx,cz,cx+STEP,cz+STEP))
        if clearings:nearby=nearby.difference(unary_union(clearings))
        local=nearby.intersection(tilebox)
        # True stand boundary, not artificial tile/cell boundaries.
        boundary=nearby.boundary.intersection(tilebox.buffer(48))
        start=len(data);count=0;covered_area=0.
        @lru_cache(maxsize=None)
        def vertex(x,z):
            ground,measured=survey(round(x,3),round(z,3))
            if ground is None:return None
            h=max(4,min(25,measured)) if measured is not None else 13.
            # Rounded stand margins and coherent height between adjacent tiles.
            edge=boundary.distance(Point(x,z)) if not boundary.is_empty else 48.
            envelope=h*(.74+.26*min(1,edge/18))
            variation=1.2*math.sin(x*.105+math.sin(z*.07))*math.cos(z*.11)
            return (x,ground+max(1.5,envelope+variation),z,ground)
        def triangle(a,b,c):
            nonlocal count,covered_area
            if None in (a,b,c):return
            u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
            normal=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
            size=math.sqrt(sum(x*x for x in normal))
            if size<.001:return
            if normal[1]<0:b,c=c,b;normal=tuple(-n for n in normal)
            normal=tuple(n/size for n in normal)
            for p in (a,b,c):data.extend(struct.pack('<ffff',*p))
            covered_area+=abs((b[0]-a[0])*(c[2]-a[2])-(b[2]-a[2])*(c[0]-a[0]))*.5
            count+=3
        for x in range(tx*TILE,(tx+1)*TILE,STEP):
            for z in range(tz*TILE,(tz+1)*TILE,STEP):
                cell=box(x,z,x+STEP,z+STEP)
                if not prepared.intersects(cell):continue
                _,canopy=survey(x+STEP*.5,z+STEP*.5)
                if canopy is not None and canopy<3:continue
                piece=local.intersection(cell)
                if piece.area<16:continue
                for polygon in polygon_parts(piece):
                    for tri in constrained_delaunay_triangles(polygon).geoms:
                        corners=[vertex(round(p[0],3),round(p[1],3)) for p in list(tri.exterior.coords)[:3]]
                        if None in corners:missing+=1;continue
                        triangle(*corners)
                    # Close the upper foliage layer at real stand margins. Internal grid
                    # seams have no walls or redundant hidden faces.
                    for ring in [polygon.exterior,*polygon.interiors]:
                        coords=list(ring.coords)
                        for p,q in zip(coords,coords[1:]):
                            if any(abs(p[k]-q[k])<.001 and (abs(p[k]-[x,z][k])<.001 or abs(p[k]-([x,z][k]+STEP))<.001) for k in (0,1)):continue
                            a=vertex(round(p[0],3),round(p[1],3));b=vertex(round(q[0],3),round(q[1],3))
                            if a is None or b is None:continue
                            base_a=(a[0],a[3]+max(1.5,a[1]-a[3]-4.5),a[2],a[3]);base_b=(b[0],b[3]+max(1.5,b[1]-b[3]-4.5),b[2],b[3])
                            triangle(a,base_b,b);triangle(a,base_a,base_b)
        canopy_area=covered_area;crown_start=count;trunks=[];clusters=0
        if fringe_zone.intersects(tilebox):
            candidates=[]
            for gx in range(tx*TILE,(tx+1)*TILE,16):
                for gz in range(tz*TILE,(tz+1)*TILE,16):
                    seed=(gx*73856093 ^ gz*19349663)&0xffffffff
                    px=gx+8+((seed%97)/96-.5)*4;pz=gz+8+(((seed//97)%97)/96-.5)*4
                    candidate=Point(px,pz)
                    if not fringe_zone.contains(candidate) or not nearby.contains(candidate):continue
                    edge=boundary.distance(candidate) if not boundary.is_empty else 48
                    if not 1.5<edge<11:continue
                    ground,h=survey(round(px,3),round(pz,3))
                    if ground is None or h is not None and h<4:continue
                    candidates.append((seed,px,pz,max(6,min(24,h if h is not None else 13))))
            for seed,px,pz,h in sorted(candidates)[:28]:
                crowns,wood=crown_mesh(px,pz,h,seed%3==0,survey)
                for face in crowns:triangle(*face)
                trunks.extend(wood);clusters+=1
        trunk_start=count
        for face in trunks:triangle(*face)
        if count:
            compressed=gzip.compress(bytes(data[start:]),compresslevel=6,mtime=0)
            del data[start:];data.extend(compressed)
            records.append({'key':f'{tx}_{tz}','x':tx*TILE,'z':tz*TILE,'offset':start,'byte_length':len(compressed),'vertices':count,'forest_fraction':min(1,canopy_area/(TILE*TILE)),'crown_start':crown_start,'trunk_start':trunk_start,'fringe_clusters':clusters})
            triangle_count+=count//3
        if number%150==0:print(entry['id'],'forest',number,'/',len(tiles),flush=True)
    (directory/'forest.bin').write_bytes(data)
    metadata={'schema':3,'source':'IGN BD TOPO wooded parcels with holes; LiDAR MNT + MNH heights when available',
      'licence':'Licence Ouverte 2.0; road exclusions derived from OSM ODbL 1.0',
      'route_source_sha256':world['route_source_sha256'],'file':'forest.bin','sha256':hashlib.sha256(data).hexdigest(),
      'compression':'gzip_tiles','format':'float32 little endian x,y,z,ground_y; triangle list; offsets in bytes',
      'tile_size_m':TILE,'grid_m':STEP,'triangles':triangle_count,'missing_terrain_triangles':missing,
      'forest_area_m2':mask.area,'tiles':records,'note':'Canopy envelope with sparse interpreted border crowns and trunks, not an inventory of individual trees; height fallback 13m where no MNH canopy sample'}
    (directory/'forest.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n')
    print(entry['id'],'FOREST_BUILT',len(data),'bytes',triangle_count,'triangles',len(records),'cells',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--circuit');args=parser.parse_args()
    for entry in json.loads((ROOT/'assets/routes/catalog.json').read_text()):
        if args.circuit is None or entry['id']==args.circuit:bake(entry)
