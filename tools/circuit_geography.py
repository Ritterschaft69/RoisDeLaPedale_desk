"""Acquire full-circuit OSM / IGN geography. Authoring only, never run by the game.

Raw downloads are content-addressed in build/geography/cache; derived data and
receipts are portable. Public services are queried serially with bounded pages.
Pillow is required only to decode IGN float GeoTIFFs (pip install Pillow).
"""
from __future__ import annotations
import argparse
import bisect
from collections import defaultdict
import datetime as dt
import hashlib
import heapq
import io
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

from prepare_route import ROOT, project
from build_geoworld import unproject, distance_segment, inside
from fetch_geodata import ign_features

OUT = ROOT/'assets/geodata/circuits'
RAW = ROOT/'build/geography'
WMS = 'https://data.geopf.fr/wms-r/wms'
CRS84 = 'urn:ogc:def:crs:OGC:1.3:CRS84'
TILE = 2000


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':'))+'\n')
    temporary.replace(path)


def parse_osm(content):
    root=ET.fromstring(content)
    if root.tag!='osm' or root.find('error') is not None:raise ValueError('Incomplete OSM map XML')
    nodes={int(n.attrib['id']):{'lat':float(n.attrib['lat']),'lon':float(n.attrib['lon'])} for n in root.findall('node')}
    elements=[]
    for way in root.findall('way'):
        tags={n.attrib['k']:n.attrib['v'] for n in way.findall('tag')}
        if 'highway' not in tags:continue
        references=[int(n.attrib['ref']) for n in way.findall('nd')]
        if any(n not in nodes for n in references):raise ValueError('OSM API omitted a road node')
        elements.append({'type':'way','id':int(way.attrib['id']),'nodes':references,
                         'tags':tags,'geometry':[nodes[n] for n in references]})
    return {'elements':elements}


class Client:
    def __init__(self):
        self.cache = RAW/'cache'
        self.cache.mkdir(parents=True, exist_ok=True)
        self.receipts = {}

    def get(self, url, *, form=None, kind='json', attempts=3):
        body = urllib.parse.urlencode(form).encode() if form else None
        key = hashlib.sha256(url.encode()+b'\n'+(body or b'')).hexdigest()
        path = self.cache/(key+('.tif' if kind == 'tiff' else '.osm' if kind=='osm' else '.json'))
        cached = path.exists()
        for attempt in range(attempts):
            try:
                if cached:
                    content = path.read_bytes()
                else:
                    request = urllib.request.Request(url, data=body, headers={
                        'User-Agent':'RoisDeLaPedale/0.6 offline-circuit-geography',
                        'Content-Type':'application/x-www-form-urlencoded'})
                    with urllib.request.urlopen(request, timeout=120) as response:
                        content = response.read(48*1024*1024+1)
                    if len(content) > 48*1024*1024: raise ValueError('Geographic response exceeds 48 MiB')
                if kind == 'tiff':
                    from PIL import Image
                    image = Image.open(io.BytesIO(content))
                    if image.mode != 'F': raise ValueError('IGN must return a numeric float GeoTIFF, not a coloured map')
                    image.load()
                    result = image
                elif kind=='osm':
                    result=parse_osm(content)
                else:
                    result = json.loads(content)
                    if any(k in result for k in ('remark', 'error', 'ExceptionReport')):
                        raise ValueError('Incomplete/error geographic response: '+str(result)[:200])
                if not cached:
                    path.with_suffix('.tmp').write_bytes(content)
                    path.with_suffix('.tmp').replace(path)
                    time.sleep(.15)
                self.receipts[key] = {'url':url, 'post_form':form, 'sha256':hashlib.sha256(content).hexdigest(),
                                      'cache_file':path.name, 'bytes':len(content)}
                return result
            except (OSError, ValueError, ET.ParseError) as error:
                if attempt == attempts-1 or cached: raise
                print('RETRY', type(error).__name__, str(error)[:160], flush=True)
                time.sleep(1+attempt*2)
        raise AssertionError('unreachable')


def lambert93(lat, lon):
    """EPSG:2154, GRS80 ellipsoid; metres, Lambert conformal conic 2SP."""
    phi = math.radians(lat)
    e = math.sqrt(6.69438002290e-3)
    iso = math.log(math.tan(math.pi/4+phi/2)*((1-e*math.sin(phi))/(1+e*math.sin(phi)))**(e/2))
    radius = 11754255.426096*math.exp(-.725607765053267*iso)
    angle = .725607765053267*math.radians(lon-3)
    return 700000+radius*math.sin(angle), 12655612.049876-radius*math.cos(angle)


def inverse_lambert93(x, y):
    e = math.sqrt(6.69438002290e-3)
    radius = math.hypot(x-700000, 12655612.049876-y)
    iso = -math.log(radius/11754255.426096)/.725607765053267
    phi = 2*math.atan(math.exp(iso))-math.pi/2
    for _ in range(8):
        phi = 2*math.atan(math.exp(iso)*((1+e*math.sin(phi))/(1-e*math.sin(phi)))**(e/2))-math.pi/2
    return math.degrees(phi), 3+math.degrees(math.atan2(x-700000,12655612.049876-y)/.725607765053267)


class Track:
    def __init__(self, route):
        self.route = route
        self.points = route['points']
        self.stations = [p['s'] for p in self.points]

    def sample(self, s):
        i = max(0,min(len(self.points)-2,bisect.bisect_right(self.stations,s)-1))
        a,b = self.points[i:i+2]
        t = max(0,min(1,(s-a['s'])/max(1e-9,b['s']-a['s'])))
        return {k:a[k]+(b[k]-a[k])*t for k in ('x','z','alt','lat','lon')}

    def stations_at(self, step):
        return [i*step for i in range(math.ceil(self.stations[-1]/step))]+[self.stations[-1]]


def chunks(track, step=6000, margin=350):
    for start in range(0,math.ceil(track.stations[-1]),step):
        points = [track.sample(s) for s in range(start,min(math.ceil(track.stations[-1]),start+step)+1,100)]
        points += [track.sample(min(track.stations[-1],start+step))]
        lat = margin/110574
        lon = margin/(111320*math.cos(math.radians(points[0]['lat'])))
        yield [min(p['lon'] for p in points)-lon,min(p['lat'] for p in points)-lat,
               max(p['lon'] for p in points)+lon,max(p['lat'] for p in points)+lat]


def osm_map(client,bbox):
    west,south,east,north=bbox
    nx=max(1,math.ceil((east-west)*111320*math.cos(math.radians(south))/900))
    ny=max(1,math.ceil((north-south)*110574/900))
    elements={}
    for i in range(nx):
        for j in range(ny):
            bounds=(west+(east-west)*i/nx,south+(north-south)*j/ny,
                    west+(east-west)*(i+1)/nx,south+(north-south)*(j+1)/ny)
            url='https://www.openstreetmap.org/api/0.6/map?'+urllib.parse.urlencode({'bbox':','.join(map(str,bounds))})
            result=client.get(url,kind='osm')
            for way in result['elements']:elements[way['id']]=way
    return {'elements':list(elements.values())}


def osm_roads(client,bbox,depth=0):
    west,south,east,north=bbox
    endpoint='https://overpass-api.de/api/interpreter'
    pattern='[out:json][timeout:%d];way["highway"](%s,%s,%s,%s);out geom;'
    for timeout in (90,25):
        query=pattern%(timeout,south,west,north,east)
        form={'data':query}
        for url,body in ((endpoint,form),(endpoint+'?'+urllib.parse.urlencode(form),None)):
            encoded=urllib.parse.urlencode(body).encode() if body else b''
            key=hashlib.sha256(url.encode()+b'\n'+encoded).hexdigest()
            if (client.cache/(key+'.json')).exists():return client.get(url,form=body)
    if getattr(client,'prefer_osm_api',False):return osm_map(client,bbox)
    query=pattern%(25,south,west,north,east)
    try:
        return client.get(endpoint+'?'+urllib.parse.urlencode({'data':query}),attempts=2)
    except (OSError,ValueError):
        print('Public Overpass gateway unavailable; use OSM map API in 900m tiles',bbox,flush=True)
        return osm_map(client,bbox)


def acquire_vectors(entries, client):
    for entry in entries:
        track = Track(json.loads((ROOT/entry['data'].removeprefix('res://')).read_text()))
        directory = RAW/entry['id']
        directory.mkdir(parents=True,exist_ok=True)
        osm = {}
        layers = {name:{} for name in ('batiment','zone_de_vegetation','lidar_metadata')}
        for index,bbox in enumerate(chunks(track)):
            result=osm_roads(client,bbox)
            if not isinstance(result.get('elements'),list): raise ValueError('Invalid Overpass result')
            for way in result['elements']: osm[str(way['id'])] = way
            for name in layers:
                layer = 'IGNF_LIDAR-HD_METADONNEE:metadata' if name == 'lidar_metadata' else 'BDTOPO_V3:'+name
                result = ign_features(client,layer,bbox)
                for feature in result['features']: layers[name][feature['id']] = feature
            print(entry['id'],'source chunk',index+1,'OSM',len(osm),'buildings',len(layers['batiment']),flush=True)
            # Intermediate snapshots allow acquisition to resume from the HTTP cache.
            save(directory/'osm.json',{'elements':list(osm.values())})
            for name,values in layers.items(): save(directory/(name+'.geojson'),{'type':'FeatureCollection','features':list(values.values())})
        save(directory/'receipts.json',list(client.receipts.values()))


def acquire_water(entries,client):
    for entry in entries:
        track=Track(json.loads((ROOT/entry['data'].removeprefix('res://')).read_text()))
        features={}
        for i,bbox in enumerate(chunks(track,step=6000,margin=450)):
            result=ign_features(client,'BDTOPO_V3:surface_hydrographique',bbox)
            for feature in result['features']:features[feature['id']]=feature
            print(entry['id'],'water chunk',i+1,'features',len(features),flush=True)
        save(RAW/entry['id']/'water.geojson',{'type':'FeatureCollection','features':list(features.values())})
        save(RAW/entry['id']/'water_receipts.json',list(client.receipts.values()))


def tile_plan(entries):
    near,far = set(),set()
    for entry in entries:
        route = json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
        track = Track(route)
        for s in track.stations_at(150):
            p = track.sample(s)
            x,y = lambert93(p['lat'],p['lon'])
            for margin,destination in ((400,near),(1900,far)):
                for i in range(math.floor((x-margin)/TILE),math.floor((x+margin)/TILE)+1):
                    for j in range(math.floor((y-margin)/TILE),math.floor((y+margin)/TILE)+1):
                        # Circle/tile intersection avoids downloading distant square corners.
                        dx=max(i*TILE-x,0,x-(i+1)*TILE)
                        dy=max(j*TILE-y,0,y-(j+1)*TILE)
                        if math.hypot(dx,dy)<=margin: destination.add((i,j))
    return near,far-near


def acquire_rasters(entries, client):
    near,far = tile_plan(entries)
    directory = OUT/'terrain'
    directory.mkdir(parents=True,exist_ok=True)
    existing=json.loads((directory/'index.json').read_text()) if (directory/'index.json').exists() else {}
    tiles={tile['key']:tile for tile in existing.get('tiles',[])}
    print('LiDAR tile plan:',len(near),'MNT+MNH tiles,',len(far),'MNT-only far tiles; numeric grids 10m',flush=True)
    for index,(i,j) in enumerate(sorted(near|far)):
        # One raster lattice avoids seams where near/far tiles meet. The
        # rendered mesh, not the source elevation grid, uses distance LOD.
        resolution = 10
        size = TILE//resolution
        sources = {}
        for product in (('MNT','MNH') if (i,j) in near else ('MNT',)):
            params = {'SERVICE':'WMS','VERSION':'1.3.0','REQUEST':'GetMap',
                'LAYERS':f'IGNF_LIDAR-HD_{product}_ELEVATION.ELEVATIONGRIDCOVERAGE.LAMB93',
                'FORMAT':'image/geotiff','STYLES':'normal','CRS':'EPSG:2154',
                'BBOX':f'{i*TILE},{j*TILE},{(i+1)*TILE},{(j+1)*TILE}','WIDTH':size,'HEIGHT':size}
            url = WMS+'?'+urllib.parse.urlencode(params)
            image = client.get(url,kind='tiff')
            if image.size != (size,size): raise ValueError('Wrong IGN raster dimensions')
            values = list(image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata())
            valid = sum(math.isfinite(v) and -100 <= v <= 5000 for v in values)
            filename = f'{i}_{j}_{product.lower()}.bin'
            # IEEE float32 little endian; NaNs/nodata stay nodata, never silently zeroed.
            data = struct.pack('<'+'f'*len(values),*values)
            (directory/filename).write_bytes(data)
            sources[product.lower()] = {'file':filename,'sha256':hashlib.sha256(data).hexdigest(),
                'valid_pixels':valid,'total_pixels':len(values),'url':url}
        previous=tiles.get(f'{i}_{j}',{})
        combined={**previous.get('sources',{}),**sources}
        tiles[f'{i}_{j}']={'key':f'{i}_{j}','x':i*TILE,'y':j*TILE,'size':size,'resolution_m':resolution,'sources':combined}
        receipts={r['sha256']+r['url']:r for r in existing.get('receipts',[])}
        receipts.update({r['sha256']+r['url']:r for r in client.receipts.values()})
        save(directory/'index.pending.json',{'schema':1,'crs':'EPSG:2154','height_datum':'IGN69','tile_size_m':TILE,
            'source':'IGN LiDAR HD derived MNT and MNH float GeoTIFF, not raw LAZ point clouds',
            'tiles':sorted(tiles.values(),key=lambda t:t['key']),'receipts':list(receipts.values())})
        if index%10 == 0: print('LiDAR raster tiles',index+1,'/',len(near|far),flush=True)
    (directory/'index.pending.json').replace(directory/'index.json')


def acquire_horizon(entries,client):
    positions=[]
    for entry in entries:
        route=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
        positions.extend(lambert93(p['lat'],p['lon']) for p in route['points'][::20])
    resolution=100
    west=math.floor((min(p[0] for p in positions)-17000)/resolution)*resolution
    south=math.floor((min(p[1] for p in positions)-17000)/resolution)*resolution
    east=math.ceil((max(p[0] for p in positions)+17000)/resolution)*resolution
    north=math.ceil((max(p[1] for p in positions)+17000)/resolution)*resolution
    width,height=int((east-west)/resolution),int((north-south)/resolution)
    params={'SERVICE':'WMS','VERSION':'1.3.0','REQUEST':'GetMap',
        'LAYERS':'IGNF_LIDAR-HD_MNT_ELEVATION.ELEVATIONGRIDCOVERAGE.LAMB93',
        'FORMAT':'image/geotiff','STYLES':'normal','CRS':'EPSG:2154',
        'BBOX':f'{west},{south},{east},{north}','WIDTH':width,'HEIGHT':height}
    image=client.get(WMS+'?'+urllib.parse.urlencode(params),kind='tiff')
    if image.size!=(width,height):raise ValueError('Wrong horizon raster dimensions')
    values=list(image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata())
    data=struct.pack('<'+'f'*len(values),*values)
    directory=OUT/'terrain'
    (directory/'horizon.bin').write_bytes(data)
    index=json.loads((directory/'index.json').read_text())
    index['horizon']={'x':west,'y':south,'width':width,'height':height,'resolution_m':resolution,
        'file':'horizon.bin','sha256':hashlib.sha256(data).hexdigest(),
        'valid_pixels':sum(math.isfinite(v) and -100<=v<=5000 for v in values),'total_pixels':len(values),
        'note':'Coarse LiDAR-derived MNT for distant silhouettes; not the road elevation grid',
        'receipts':list(client.receipts.values())}
    save(directory/'index.json',index)
    print('HORIZON',width,height,index['horizon']['valid_pixels'],'/',len(values),'valid',flush=True)


class Terrain:
    def __init__(self):
        index = json.loads((OUT/'terrain/index.json').read_text())
        self.tiles = {(t['x']//TILE,t['y']//TILE):t for t in index['tiles']}
        self.loaded = {}
        self.horizon=index.get('horizon',{})
        self.horizon_values=None

    def horizon_height(self,x,y):
        h=self.horizon
        if not h:return None
        u=(x-h['x'])/h['resolution_m']-.5
        v=(h['y']+h['height']*h['resolution_m']-y)/h['resolution_m']-.5
        i,j=math.floor(u),math.floor(v)
        if not 0<=i<h['width']-1 or not 0<=j<h['height']-1:return None
        if self.horizon_values is None:
            data=(OUT/'terrain'/h['file']).read_bytes()
            self.horizon_values=struct.unpack('<'+'f'*(len(data)//4),data)
        values=[self.horizon_values[(j+dy)*h['width']+i+dx] for dx,dy in ((0,0),(1,0),(0,1),(1,1))]
        if not all(math.isfinite(z) and -100<=z<=5000 for z in values):return None
        tx,ty=u-i,v-j
        return (values[0]*(1-tx)+values[1]*tx)*(1-ty)+(values[2]*(1-tx)+values[3]*tx)*ty

    def height(self, lat, lon, product='mnt'):
        x,y = lambert93(lat,lon)
        return self.at(x,y,product)

    def at(self,x,y,product='mnt'):
        tile = self.tiles.get((int(x//TILE),int(y//TILE)))
        if not tile:return self.horizon_height(x,y) if product=='mnt' else None
        if product not in tile['sources']:return None
        key = tile['key']+product
        if key not in self.loaded:
            data = (OUT/'terrain'/tile['sources'][product]['file']).read_bytes()
            self.loaded[key] = struct.unpack('<'+'f'*(len(data)//4),data)
        values = self.loaded[key]
        size,res = tile['size'],tile['resolution_m']
        u,v = (x-tile['x'])/res-.5,(tile['y']+TILE-y)/res-.5
        i,j = math.floor(u),math.floor(v)
        tx,ty = u-i,v-j
        total,weight = 0.,0.
        for dx,dy,w in ((0,0,(1-tx)*(1-ty)),(1,0,tx*(1-ty)),(0,1,(1-tx)*ty),(1,1,tx*ty)):
            a,b = i+dx,j+dy
            # Fetch a neighbour tile at pixel centres to avoid clamped tile seams.
            if 0<=a<size and 0<=b<size:
                z = values[b*size+a]
            else:
                other = self.tiles.get((int((tile['x']+(a+.5)*res)//TILE),int((tile['y']+TILE-(b+.5)*res)//TILE)))
                if not other or product not in other['sources']: continue
                neighbour_key = other['key']+product
                if neighbour_key not in self.loaded:
                    data = (OUT/'terrain'/other['sources'][product]['file']).read_bytes()
                    self.loaded[neighbour_key] = struct.unpack('<'+'f'*(len(data)//4),data)
                ox,oy = tile['x']+(a+.5)*res,tile['y']+TILE-(b+.5)*res
                oi = min(other['size']-1,max(0,int((ox-other['x'])/other['resolution_m'])))
                oj = min(other['size']-1,max(0,int((other['y']+TILE-oy)/other['resolution_m'])))
                z = self.loaded[neighbour_key][oj*other['size']+oi]
            if math.isfinite(z) and -100<=z<=5000:
                total += z*w
                weight += w
        return total/weight if weight>.999 else None


class RoadGraph:
    """Directed OSM topology and local candidate search, in the GPX's ENU frame."""
    def __init__(self, ways, origin):
        self.nodes,self.edges,self.adjacency,self.cells = {},[],defaultdict(list),defaultdict(set)
        for way in sorted(ways,key=lambda w:w['id']):
            tags = way.get('tags',{})
            if tags.get('highway') in ('motorway','motorway_link','construction','proposed','steps'): continue
            geometry = way.get('geometry',[])
            ids = way.get('nodes',[])
            if len(ids)!=len(geometry): continue
            for identity,p in zip(ids,geometry):
                east,north = project(p['lat'],p['lon'],origin)
                self.nodes[identity] = (east,-north)
            oneway = tags.get('oneway:bicycle',tags.get('oneway','no'))
            if tags.get('cycleway') in ('opposite','opposite_lane','opposite_track'): oneway='no'
            for a,b in zip(ids,ids[1:]):
                length = math.dist(self.nodes[a],self.nodes[b])
                if length<.01: continue
                for u,v in (([(b,a)] if oneway=='-1' else [(a,b)]) if oneway in ('yes','1','true','-1') else [(a,b),(b,a)]):
                    index = len(self.edges)
                    self.edges.append({'u':u,'v':v,'length':length,'way':way['id'],'tags':tags})
                    self.adjacency[u].append(index)
                    p,q = self.nodes[u],self.nodes[v]
                    for x in range(math.floor(min(p[0],q[0])/64),math.floor(max(p[0],q[0])/64)+1):
                        for z in range(math.floor(min(p[1],q[1])/64),math.floor(max(p[1],q[1])/64)+1): self.cells[x,z].add(index)

    def candidates(self,p,direction,radius=40):
        candidates = []
        nearby = set()
        for x in range(math.floor((p[0]-radius)/64),math.floor((p[0]+radius)/64)+1):
            for z in range(math.floor((p[1]-radius)/64),math.floor((p[1]+radius)/64)+1): nearby.update(self.cells[x,z])
        for index in sorted(nearby):
            edge = self.edges[index]
            a,b = self.nodes[edge['u']],self.nodes[edge['v']]
            distance,t = distance_segment(p,a,b)
            heading = ((b[0]-a[0])*direction[0]+(b[1]-a[1])*direction[1])/edge['length']
            if distance<=radius and heading>-.35:
                point = (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
                candidates.append({'edge':index,'t':t,'point':point,'distance':distance,
                    'emission':distance*distance/32+8*(1-heading)})
        # Keep topological alternatives at junctions, not many collinear copies.
        candidates.sort(key=lambda c:(c['emission'],c['edge']))
        return candidates[:6]

    def shortest(self,start,end,limit=130):
        if start==end: return 0.,[]
        heap,dist,parent = [(0.,start)],{start:0.},{}
        while heap:
            distance,u = heapq.heappop(heap)
            if distance>dist[u]+1e-6: continue
            if u==end:
                path = []
                while u!=start:
                    edge = parent[u]
                    path.append(edge)
                    u = self.edges[edge]['u']
                return distance,list(reversed(path))
            for index in self.adjacency.get(u,[]):
                edge = self.edges[index]
                v,new = edge['v'],distance+edge['length']
                if new<=limit and new<dist.get(v,math.inf):
                    dist[v]=new;parent[v]=index
                    heapq.heappush(heap,(new,v))
        return math.inf,[]

    def transition(self,a,b,cache):
        ea,eb = self.edges[a['edge']],self.edges[b['edge']]
        if a['edge']==b['edge'] and b['t']>=a['t']:
            return (b['t']-a['t'])*ea['length'],[]
        key = (ea['v'],eb['u'])
        if key not in cache: cache[key] = self.shortest(*key)
        distance,path = cache[key]
        return (1-a['t'])*ea['length']+distance+b['t']*eb['length'],path


def match_track(track, graph):
    stations = track.stations_at(12)
    layers,parents,previous_cost = [],[],[]
    for index,s in enumerate(stations):
        raw = track.sample(s)
        before,after = track.sample(max(0,s-5)),track.sample(min(track.stations[-1],s+5))
        dx,dz = after['x']-before['x'],after['z']-before['z']
        norm = max(1e-9,math.hypot(dx,dz))
        candidates = graph.candidates((raw['x'],raw['z']),(dx/norm,dz/norm))
        # A source fallback is a real state: gaps never become straight invented OSM links.
        candidates.append({'edge':None,'point':(raw['x'],raw['z']),'distance':0.,'emission':42.})
        costs,back = [],[]
        cache = {}
        for candidate in candidates:
            if not layers:
                costs.append(candidate['emission']);back.append(-1);continue
            best,best_j = math.inf,-1
            for j,old in enumerate(layers[-1]):
                if candidate['edge'] is None or old['edge'] is None:
                    transition = 12. if candidate['edge']!=old['edge'] else 0.
                else:
                    distance,_ = graph.transition(old,candidate,cache)
                    transition = abs(distance-(s-stations[index-1]))*.8
                    if distance>max(60,(s-stations[index-1])*3): transition=math.inf
                cost = previous_cost[j]+transition+candidate['emission']
                if cost<best: best,best_j=cost,j
            costs.append(best);back.append(best_j)
        minimum=min(costs)
        previous_cost=[c-minimum for c in costs]
        layers.append(candidates);parents.append(back)
    chosen = []
    j = min(range(len(previous_cost)),key=previous_cost.__getitem__)
    for i in range(len(layers)-1,-1,-1):
        chosen.append(layers[i][j]);j=parents[i][j]
    chosen.reverse()
    path = []
    matched,offsets,fallbacks = 0.,[],[]
    for index,(s,candidate) in enumerate(zip(stations,chosen)):
        if candidate['edge'] is not None: offsets.append(candidate['distance'])
        if index:
            old = chosen[index-1]
            start = stations[index-1]
            distance,edges = (graph.transition(old,candidate,{}) if old['edge'] is not None and candidate['edge'] is not None else (math.inf,[]))
            if math.isfinite(distance) and distance<=max(60,(s-start)*3):
                matched += s-start
                # Reconstruct the actual graph path: no diagonal shortcut at bends/junctions.
                shape = [old['point']]
                for edge_index in edges:
                    edge = graph.edges[edge_index]
                    shape.extend([graph.nodes[edge['u']],graph.nodes[edge['v']]])
                ea = graph.edges[old['edge']]
                eb = graph.edges[candidate['edge']]
                if old['edge']!=candidate['edge']:
                    shape.insert(1,graph.nodes[ea['v']])
                    shape.append(graph.nodes[eb['u']])
                shape.append(candidate['point'])
                lengths = [0.]
                for a,b in zip(shape,shape[1:]):lengths.append(lengths[-1]+math.dist(a,b))
                for point,d in zip(shape[1:-1],lengths[1:-1]):
                    source_s=start+(s-start)*d/max(.001,lengths[-1])
                    path.append({'x':point[0],'z':point[1],'source_s':source_s,'osm_way':ea['way']})
            else:
                fallbacks.append([start,s])
                # Blend only within an explicit unverified interval; retain source vertices.
                for source in track.points:
                    if start<source['s']<s:path.append({'x':source['x'],'z':source['z'],'source_s':source['s'],'osm_way':None})
        path.append({'x':candidate['point'][0],'z':candidate['point'][1],'source_s':s,
                     'osm_way':graph.edges[candidate['edge']]['way'] if candidate['edge'] is not None else None})
    merged = []
    for a,b in fallbacks:
        if merged and abs(merged[-1][1]-a)<.01:merged[-1][1]=b
        else:merged.append([a,b])
    return path,{'matched_source_m':matched,'source_length_m':track.stations[-1],
        'matched_fraction':matched/track.stations[-1],'max_candidate_offset_m':max(offsets,default=0),
        'mean_candidate_offset_m':sum(offsets)/max(1,len(offsets)),'unverified_source_intervals_m':merged,
        'method':'12 m GPX observations, 40 m candidate radius, heading emissions + directed-network Viterbi; graph edges reconstructed'}


def resample(points, step=2):
    """Uniform horizontal arc length; carry the monotone original GPX station."""
    compact = [points[0]]
    lengths = [0.]
    for point in points[1:]:
        distance=math.hypot(point['x']-compact[-1]['x'],point['z']-compact[-1]['z'])
        if distance>.001:
            compact.append(point);lengths.append(lengths[-1]+distance)
    if len(compact)<2: raise ValueError('Degenerate reconstructed route')
    count=math.ceil(lengths[-1]/step)
    spacing=lengths[-1]/count
    output=[]
    j=0
    for i in range(count+1):
        s=i*spacing
        while j<len(compact)-2 and lengths[j+1]<s:j+=1
        t=(s-lengths[j])/max(1e-9,lengths[j+1]-lengths[j])
        a,b=compact[j:j+2]
        point={key:a[key]+(b[key]-a[key])*t for key in ('x','z','source_s')}
        if 'alt' in a:point['alt']=a['alt']+(b['alt']-a['alt'])*t
        point['osm_way']=a.get('osm_way') if t<.5 else b.get('osm_way')
        point['s']=s
        output.append(point)
    return output,spacing,lengths[-1]


def gaussian(values,sigma,spacing):
    radius=math.ceil(sigma*3/spacing)
    weights=[math.exp(-.5*(i*spacing/sigma)**2) for i in range(-radius,radius+1)]
    result=[]
    for j in range(len(values)):
        # Linear endpoint extension preserves genuine road grade at the ends.
        total=0.
        for i,w in zip(range(-radius,radius+1),weights):
            k=j+i
            v=(values[0]+k*(values[1]-values[0]) if k<0 else
               values[-1]+(k-len(values)+1)*(values[-1]-values[-2]) if k>=len(values) else values[k])
            total+=v*w
        result.append(total/sum(weights))
    return result


class NearbyRoute:
    def __init__(self,points,radius=360):
        # 12m bins are sufficient for clipping scenery; geometry stays at 2m.
        self.points=points[::6]+[points[-1]]
        self.cells=defaultdict(set)
        for i,(a,b) in enumerate(zip(self.points,self.points[1:])):
            for x in range(math.floor((min(a['x'],b['x'])-radius)/256),math.floor((max(a['x'],b['x'])+radius)/256)+1):
                for z in range(math.floor((min(a['z'],b['z'])-radius)/256),math.floor((max(a['z'],b['z'])+radius)/256)+1):self.cells[x,z].add(i)

    def nearest(self,point):
        best,station=math.inf,0.
        for i in self.cells.get((math.floor(point[0]/256),math.floor(point[1]/256)),[]):
            a,b=self.points[i:i+2]
            d,t=distance_segment(point,(a['x'],a['z']),(b['x'],b['z']))
            if d<best:best,station=d,a['s']+(b['s']-a['s'])*t
        return best,station


def polynomial_terms(x,z):
    x,z=x/10000,z/10000
    return [1,x,z,x*x,x*z,z*z,x*x*x,x*x*z,x*z*z,z*z*z]


def solve(matrix,vector):
    augmented=[row[:]+[b] for row,b in zip(matrix,vector)]
    for i in range(len(vector)):
        pivot=max(range(i,len(vector)),key=lambda j:abs(augmented[j][i]))
        augmented[i],augmented[pivot]=augmented[pivot],augmented[i]
        divisor=augmented[i][i]
        if abs(divisor)<1e-18:raise ValueError('Degenerate projection fit')
        augmented[i]=[v/divisor for v in augmented[i]]
        for j in range(len(vector)):
            if i==j:continue
            factor=augmented[j][i]
            augmented[j]=[a-factor*b for a,b in zip(augmented[j],augmented[i])]
    return [row[-1] for row in augmented]


def terrain_transform(route,points):
    """Fit ENU -> Lambert93 locally, then audit an independent 9x9 grid."""
    minimum=[min(p[k] for p in points)-17500 for k in ('x','z')]
    maximum=[max(p[k] for p in points)+17500 for k in ('x','z')]
    rows,targets=[],[]
    for i in range(6):
        for j in range(6):
            x,z=[a+(b-a)*t/5 for a,b,t in zip(minimum,maximum,(i,j))]
            rows.append(polynomial_terms(x,z))
            lat,lon=unproject(x,-z,route['origin'])
            targets.append(lambert93(lat,lon))
    matrix=[[sum(row[i]*row[j] for row in rows) for j in range(10)] for i in range(10)]
    coefficients=[solve(matrix,[sum(row[i]*target[axis] for row,target in zip(rows,targets)) for i in range(10)]) for axis in (0,1)]
    error=0.
    for i in range(9):
        for j in range(9):
            x,z=[a+(b-a)*(t+.3)/9 for a,b,t in zip(minimum,maximum,(i,j))]
            lat,lon=unproject(x,-z,route['origin'])
            expected=lambert93(lat,lon)
            got=[sum(a*b for a,b in zip(c,polynomial_terms(x,z))) for c in coefficients]
            error=max(error,math.dist(expected,got))
    if error>.05:raise ValueError(f'ENU / Lambert transform audit error {error}m')
    return {'x':coefficients[0],'y':coefficients[1],'scale_m':10000,'max_audited_error_m':error,
            'bounds_enu':[minimum,maximum],'method':'cubic polynomial, 36 fit samples, 81 independent audit samples'}


def water_meshes(features,route,terrain,nearby):
    # Optional authoring dependency; the game and verification require neither
    # Shapely nor GEOS. Constrained triangulation preserves real island holes.
    sys.path.insert(0,str(RAW/'python'))
    from shapely import Polygon, constrained_delaunay_triangles
    result=[]
    for feature in features:
        geometry=feature['geometry']
        if not geometry:continue
        polygons=geometry['coordinates'] if geometry['type']=='MultiPolygon' else [geometry['coordinates']] if geometry['type']=='Polygon' else []
        for rings in polygons:
            converted=[]
            for ring in rings:
                converted.append([(lambda p:(p[0],-p[1]))(project(v[1],v[0],route['origin'])) for v in ring])
            polygon=Polygon(converted[0],converted[1:])
            if not polygon.is_valid or polygon.area<.1:continue
            triangles=constrained_delaunay_triangles(polygon)
            vertices,indices,lookup=[],[],{}
            for triangle in triangles.geoms:
                coords=list(triangle.exterior.coords)[:3]
                if not any(nearby.nearest(p)[0]<550 for p in coords):continue
                heights=[]
                for x,z in coords:
                    lat,lon=unproject(x,-z,route['origin'])
                    height=terrain.height(lat,lon)
                    if height is None:break
                    heights.append(height+.10)
                if len(heights)!=3:continue
                for (x,z),h in zip(coords,heights):
                    key=(round(x,3),round(z,3))
                    if key not in lookup:
                        lookup[key]=len(vertices);vertices.append([key[0],round(h,3),key[1]])
                    indices.append(lookup[key])
            if indices:result.append({'id':feature['id'],'points':vertices,'indices':indices,
                'holes':[[[round(x,3),round(z,3)] for x,z in ring] for ring in converted[1:]]})
    return result


def build(entry):
    route=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
    track=Track(route)
    raw=RAW/entry['id']
    directory=OUT/entry['id']
    directory.mkdir(parents=True,exist_ok=True)
    ways=json.loads((raw/'osm.json').read_text())['elements']
    graph=RoadGraph(ways,route['origin'])
    print(entry['id'],'matching',len(graph.edges),'directed OSM segments',flush=True)
    path,report=match_track(track,graph)
    print(entry['id'],'OSM match',round(100*report['matched_fraction'],2),'%',flush=True)
    # Persist the graph-derived polyline independently for ODbL inspection.
    save(directory/'osm_alignment.json',{'schema':1,'source_sha256':route['source_sha256'],
        'licence':'ODbL 1.0','attribution':'© OpenStreetMap contributors',
        'report':report,'points':[[round(p['x'],3),round(p['z'],3),round(p['source_s'],3),p['osm_way']] for p in path]})
    points,spacing,_=resample(path,1)
    # One metre temporary grid, bounded binomial smoothing. Maximum added
    # lateral displacement 0.6m; preserve tight corners and narrow road corridors.
    for _ in range(2):
        original=[(p['x'],p['z']) for p in points]
        for i in range(1,len(points)-1):
            delta=[sum((original[min(len(points)-1,max(0,i+j))][axis]-original[i][axis])*w/16 for j,w in zip(range(-2,3),(1,4,6,4,1))) for axis in (0,1)]
            scale=min(1,.3/max(1e-9,math.hypot(*delta)))
            points[i]['x']+=delta[0]*scale;points[i]['z']+=delta[1]*scale
    points,spacing,length=resample(points,2)
    terrain=Terrain()
    missing=[]
    for p in points:
        lat,lon=unproject(p['x'],-p['z'],route['origin'])
        height=terrain.height(lat,lon)
        if height is None:
            missing.append(p['s']);height=track.sample(p['source_s'])['alt']
        p['alt']=height
    if missing:
        save(directory/'incomplete_terrain.json',{'missing_lidar_stations_m':missing})
        raise ValueError(f'{entry["id"]}: missing LiDAR coverage at {len(missing)} simulated stations; refusing to publish a complete cache')
    # LiDAR measures ground, not the deck of a bridge or the inside of a tunnel.
    # Interpolate surveyed approach elevations for these explicitly tagged spans.
    specials={way['id'] for way in ways if way.get('tags',{}).get('bridge','no') not in ('no','false','0') or way.get('tags',{}).get('tunnel','no') not in ('no','false','0')}
    spans=[]
    structures=[]
    way_tags={way['id']:way.get('tags',{}) for way in ways}
    index=0
    while index<len(points):
        if points[index]['osm_way'] not in specials:index+=1;continue
        start=index
        while index<len(points) and points[index]['osm_way'] in specials:index+=1
        lo=max(0,start-8);hi=min(len(points)-1,index+8)
        a,b=points[lo]['alt'],points[hi]['alt']
        for j in range(lo,hi+1):points[j]['alt']=a+(b-a)*(j-lo)/max(1,hi-lo)
        spans.append([points[lo]['s'],points[hi]['s']])
        tags=way_tags[points[start]['osm_way']]
        kind='bridge' if tags.get('bridge','no') not in ('no','false','0') else 'tunnel'
        structures.append({'kind':kind,'start_m':points[start]['s'],'end_m':points[min(index,len(points)-1)]['s']})
    smoothed=gaussian([p['alt'] for p in points],5,spacing)
    for p,h in zip(points,smoothed):p['alt']=h
    ascent=sum(max(0,b-a) for a,b in zip(smoothed,smoothed[1:]))
    packed=b''.join(struct.pack('<ffff',p['x'],p['alt'],p['z'],p['source_s']) for p in points)
    (directory/'route.bin').write_bytes(packed)
    coordinates=b''.join(struct.pack('<dd',*unproject(p['x'],-p['z'],route['origin'])) for p in points)
    (directory/'coordinates.bin').write_bytes(coordinates)
    metadata={'schema':2,'route_source_sha256':route['source_sha256'],'length_m':length,'spacing_m':spacing,
        'point_count':len(points),'points_file':'route.bin','points_sha256':hashlib.sha256(packed).hexdigest(),
        'coordinates_file':'coordinates.bin','coordinates_sha256':hashlib.sha256(coordinates).hexdigest(),
        'format':'little endian float32 x,y,z,source_GPX_station_m; uniform horizontal station',
        'ascent_m':ascent,'source_length_m':route['length_m'],'source_ascent_raw_m':route['ascent_raw_m'],
        'altitude_source':'IGN LiDAR HD MNT, IGN69; Gaussian sigma 5m along road',
        'missing_lidar_stations_m':missing,'bridge_tunnel_approach_interpolations_m':spans,
        'structures':structures,
        'osm_match':report,'licence':'OSM-derived alignment ODbL 1.0; IGN elevations Licence Ouverte 2.0; original GPX retained separately'}
    save(directory/'route.json',metadata)
    nearby=NearbyRoute(points)
    transform=terrain_transform(route,points)
    audit=[]
    for p in points[::max(1,len(points)//45)]:
        for offset in (0,200,1000,12000):
            x,z=p['x']+offset,p['z']
            lat,lon=unproject(x,-z,route['origin'])
            height=terrain.height(lat,lon)
            if height is not None:audit.append({'x':x,'z':z,'height_m':height})
    save(directory/'terrain_audit.json',audit)
    buildings,vegetation,side_roads,water=[],[],[],[]
    skipped=defaultdict(int)
    for feature in json.loads((raw/'batiment.geojson').read_text())['features']:
        geometry,properties=feature['geometry'],feature['properties']
        if not geometry:continue
        polygons=geometry['coordinates'] if geometry['type']=='MultiPolygon' else [geometry['coordinates']] if geometry['type']=='Polygon' else []
        for part,rings in enumerate(polygons):
            if len(rings)!=1:skipped['holes_or_complex']+=1;continue
            ring=[]
            for v in rings[0]:
                x,n=project(v[1],v[0],route['origin'])
                if not ring or math.dist(ring[-1],[x,-n])>.05:ring.append([x,-n])
            if len(ring)>1 and math.dist(ring[0],ring[-1])<.05:ring.pop()
            if len(ring)<3:skipped['invalid']+=1;continue
            center=[sum(v[i] for v in ring)/len(ring) for i in (0,1)]
            distance,station=nearby.nearest(center)
            if distance>250:skipped['outside_corridor']+=1;continue
            conflict=distance<5 or any(nearby.nearest(p)[0]<4.8 for p in ring)
            if not conflict:
                for index in nearby.cells.get((math.floor(center[0]/256),math.floor(center[1]/256)),[]):
                    a,b=nearby.points[index:index+2]
                    point=(a['x'],a['z'])
                    if inside(point,ring) or any(distance_segment(point,p,q)[0]<4.8 for p,q in zip(ring,ring[1:]+ring[:1])):
                        conflict=True;break
            if conflict:
                skipped['road_conflict']+=1;continue
            base=properties.get('altitude_minimale_sol')
            estimated=not isinstance(base,(int,float))
            if estimated:
                lat,lon=unproject(center[0],-center[1],route['origin']);base=terrain.height(lat,lon)
            if base is None:skipped['missing_height']+=1;continue
            height=properties.get('hauteur')
            height_estimated=not isinstance(height,(int,float)) or not 1<=height<=70
            if height_estimated:height=7.
            identity=str(properties.get('cleabs',feature['id']))+':'+str(part)
            buildings.append({'id':identity,'seed':int(hashlib.sha256(identity.encode()).hexdigest()[:7],16),
                'footprint':[[round(v,3) for v in p] for p in ring],'center':center,'station':station,
                'base_ign':base,'base_render':base,'base_estimated':estimated,'height':height,'height_estimated':height_estimated,
                'nature':properties.get('nature'),'source':'IGN BD TOPO','roof':'procedural estimate'})
    for feature in json.loads((raw/'zone_de_vegetation.geojson').read_text())['features']:
        geometry=feature['geometry']
        if not geometry:continue
        polygons=geometry['coordinates'] if geometry['type']=='MultiPolygon' else [geometry['coordinates']] if geometry['type']=='Polygon' else []
        for rings in polygons:
            projected=[]
            for ring in rings:
                converted=[]
                for v in ring:
                    x,n=project(v[1],v[0],route['origin']);converted.append([round(x,2),round(-n,2)])
                projected.append(converted)
            if not projected or not projected[0]:continue
            # Keep polygons touching a 350m corridor, including holes.
            if not any(nearby.nearest(p)[0]<350 for p in projected[0]):
                if not any(inside((p['x'],p['z']),projected[0]) for p in points[::100]):continue
            vegetation.append({'id':feature['id'],'nature':feature['properties'].get('nature'),'rings':projected})
    for way in ways:
        tags=way.get('tags',{})
        if tags.get('highway') in ('motorway','motorway_link','proposed','construction','steps'):continue
        geometry=way.get('geometry',[])
        dense=[]
        for a,b in zip(geometry,geometry[1:]):
            pa,pb=project(a['lat'],a['lon'],route['origin']),project(b['lat'],b['lon'],route['origin'])
            count=max(1,math.ceil(math.dist(pa,pb)/5))
            for i in range(count):dense.append({k:a[k]+(b[k]-a[k])*i/count for k in ('lat','lon')})
        if geometry:dense.append(geometry[-1])
        line=[]
        for v in dense:
            x,n=project(v['lat'],v['lon'],route['origin'])
            h=terrain.height(v['lat'],v['lon'])
            if h is None:continue
            line.append([round(x,3),round(h,3),round(-n,3)])
        if len(line)<2 or not any(nearby.nearest((p[0],p[2]))[0]<270 for p in line):continue
        side_roads.append({'id':way['id'],'tags':tags,'points':line})
    water_path=raw/'water.geojson'
    if water_path.exists():
        water_source=json.loads(water_path.read_text())
        water=water_meshes(water_source['features'],route,terrain,nearby)
        save(directory/'water_source.geojson',water_source)
    receipts=json.loads((raw/'receipts.json').read_text())
    lidar=json.loads((raw/'lidar_metadata.geojson').read_text())
    # Source snapshots are reviewable and distinct; no IGN/OSM licence conflation.
    save(directory/'osm_roads.json',{'licence':'ODbL 1.0','attribution':'© OpenStreetMap contributors','elements':ways})
    save(directory/'lidar_metadata.geojson',lidar)
    world={'schema':2,'route_source_sha256':route['source_sha256'],
        'coverage':{'start_m':0,'end_m':length,'near_corridor_m':400,'far_corridor_m':1900,'horizon_margin_m':17000},
        'terrain_transform':transform,'buildings':buildings,'vegetation':vegetation,'roads_file':'osm_environment.json',
        'water':water,
        'skipped_buildings':dict(skipped),'attribution':'IGN BD TOPO / LiDAR HD (Licence Ouverte 2.0)',
        'notes':['LiDAR-derived MNT/MNH numeric rasters, not raw LAZ clouds.',
                 'Roof/facade details and individual tree meshes are procedural interpretations.',
                 'IGN terrain is in IGN69. Source GPX coordinates/heights are retained unchanged.']}
    save(directory/'world.json',world)
    save(directory/'osm_environment.json',{'licence':'ODbL 1.0','attribution':'© OpenStreetMap contributors','roads':side_roads})
    save(directory/'manifest.json',{'schema':1,'acquired_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
        'route_source_sha256':route['source_sha256'],'status':'integrated','receipts':receipts,
        'counts':{'osm_ways':len(ways),'buildings_source':len(json.loads((raw/'batiment.geojson').read_text())['features']),
                  'rendered_buildings':len(buildings),'vegetation_polygons':len(vegetation),'lidar_metadata_tiles':len(lidar['features']),
                  'water_polygons':len(water),'water_island_holes':sum(len(w['holes']) for w in water)},
        'route_report':metadata})
    if (raw/'water_receipts.json').exists():
        save(directory/'water_receipts.json',json.loads((raw/'water_receipts.json').read_text()))
    catalog=json.loads((ROOT/'assets/routes/catalog.json').read_text())
    for item in catalog:
        if item['id']==entry['id']:
            item.update(simulation_length_m=length,simulation_ascent_m=ascent,start_m=0.,
                description='Tracé OpenStreetMap recalé · relief IGN LiDAR HD · GPX source conservé')
    (ROOT/'assets/routes/catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    subprocess.run(['godot','--headless','--path',str(ROOT),'--script','res://tools/validate_geographic_world.gd','--',entry['id']],check=True)
    print(entry['id'],'BUILT',round(length/1000,3),'km',len(points),'samples;',len(buildings),'buildings;',len(missing),'missing LiDAR elevations',flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',choices=['plan','vectors','water','rasters','horizon','build','all'],default='plan')
    parser.add_argument('--circuit',choices=['saint_die','sortie_matin','oderen_grand_ballon'])
    parser.add_argument('--osm-api',action='store_true',help='Prefer small official OSM map extracts when Overpass is unavailable')
    args=parser.parse_args()
    entries=json.loads((ROOT/'assets/routes/catalog.json').read_text())
    if args.circuit:entries=[e for e in entries if e['id']==args.circuit]
    if args.stage=='plan':
        near,far=tile_plan(entries)
        print('Circuits:',[e['id'] for e in entries],'MNT+MNH 10m:',len(near),'MNT-only 10m:',len(far));return
    client=Client()
    client.prefer_osm_api=args.osm_api
    if args.stage in ('vectors','all'): acquire_vectors(entries,client)
    if args.stage in ('water','all'): acquire_water(entries,client)
    if args.stage in ('rasters','all'): acquire_rasters(entries,client)
    if args.stage in ('horizon','all'): acquire_horizon(entries,client)
    if args.stage in ('build','all'):
        for entry in entries: build(entry)


if __name__=='__main__': main()
