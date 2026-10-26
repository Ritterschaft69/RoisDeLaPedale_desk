"""Prepare a traceable first geographic slice. Never rewrites the source GPX.

IGN source heights are retained separately from the explicit visual alignment
offset used to connect a route whose vertical datum is unknown.
"""
import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path

from prepare_route import ROOT, project
from fetch_geodata import ALTI, SourceClient


def sample(route, s):
    points = route['points']
    distances = [p['s'] for p in points]
    i = max(0,min(len(points)-2,bisect.bisect_right(distances,s)-1))
    a,b = points[i:i+2]
    t = max(0,min(1,(s-a['s'])/max(1e-9,b['s']-a['s'])))
    return {key:a[key]+(b[key]-a[key])*t for key in ('x','z','lat','lon','alt')}


def unproject(east, north, origin):
    lat,lon = origin
    # Newton inverse of the exact ECEF->ENU projection. Tiny finite
    # differences are only used for its Jacobian, never for source positions.
    for _ in range(5):
        x,y = project(lat,lon,origin)
        dx,dy = east-x,north-y
        if abs(dx)+abs(dy)<1e-5: break
        a,b = project(lat+1e-5,lon,origin)
        c,d = project(lat,lon+1e-5,origin)
        j00,j10,j01,j11 = (a-x)/1e-5,(b-y)/1e-5,(c-x)/1e-5,(d-y)/1e-5
        determinant = j00*j11-j01*j10
        lat += (dx*j11-dy*j01)/determinant
        lon += (dy*j00-dx*j10)/determinant
    return lat,lon


def acquire_terrain(route,directory):
    manifest = json.loads((directory/'manifest.json').read_text())
    area = manifest['coverage']
    rows = []
    columns = [-140,-90,-45,-12,0,12,45,90,140]
    stations = list(range(int(area['start_m']),int(area['end_m']),50))+[int(area['end_m'])]
    requests = []
    for station in stations:
        center = sample(route,station)
        previous,next_p = sample(route,max(0,station-2)),sample(route,min(route['length_m'],station+2))
        dx,dz = next_p['x']-previous['x'],next_p['z']-previous['z']
        length = math.hypot(dx,dz)
        right = (-dz/length,dx/length)
        row = {'s':station,'gpx_altitude':center['alt'],'samples':[]}
        for lateral in columns:
            x,z = center['x']+right[0]*lateral,center['z']+right[1]*lateral
            lat,lon = unproject(x,-z,route['origin'])
            point = {'cross':lateral,'x':x,'z':z,'lat':lat,'lon':lon}
            row['samples'].append(point)
            requests.append(point)
        rows.append(row)
    client = SourceClient(directory/'cache')
    import urllib.parse
    for index in range(0,len(requests),100):
        batch = requests[index:index+100]
        query = {'lon':'|'.join(str(p['lon']) for p in batch),'lat':'|'.join(str(p['lat']) for p in batch),
                 'resource':'ign_rge_alti_wld','zonly':'false'}
        response = client.get(ALTI+'?'+urllib.parse.urlencode(query))
        elevations = response.get('elevations',[])
        if len(elevations) != len(batch): raise ValueError('Incomplete terrain elevations')
        for point,value in zip(batch,elevations):
            z = value.get('z') if isinstance(value,dict) else value
            if not isinstance(z,(float,int)) or not math.isfinite(z) or not -100<z<5000:
                raise ValueError('Missing/invalid terrain elevation')
            point['ign_altitude'] = z
        print('Terrain elevations',min(index+100,len(requests)),'/',len(requests),flush=True)
    for row in rows:
        row['render_vertical_offset'] = row['gpx_altitude']-row['samples'][4]['ign_altitude']
    result = {'schema':1,'coverage':area,'columns_m':columns,'rows':rows,
        'source':'IGN RGE ALTI point-elevation service; NOT a LiDAR HD point-cloud download',
        'resolution_note':'50 m along route; irregular lateral 12–50 m spacing, not a 25 m DEM',
        'render_alignment':'At each station add GPX altitude minus IGN centre elevation. GPX source unchanged.',
        'receipts':client.receipts}
    (directory/'terrain.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print('Terrain source samples saved; visual offsets are explicit.')


def distance_segment(p,a,b):
    dx,dz = b[0]-a[0],b[1]-a[1]
    t = max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/max(1e-9,dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz),t


def inside(point,ring):
    x,y = point
    result = False
    for a,b in zip(ring,ring[1:]+ring[:1]):
        if (a[1]>y) != (b[1]>y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: result = not result
    return result


def prepare(route,directory):
    terrain = json.loads((directory/'terrain.json').read_text())
    manifest = json.loads((directory/'manifest.json').read_text())
    source = json.loads((directory/'batiment.geojson').read_text())
    rows = terrain['rows']
    stations = [row['s'] for row in rows]
    route_points = route['points']
    segments = [(a,b) for a,b in zip(route_points,route_points[1:]) if a['s'] <= manifest['coverage']['end_m']+250 and b['s'] >= manifest['coverage']['start_m']-250]
    buildings, skipped = [], {'holes_or_complex':0,'outside_corridor':0,'road_conflict':0,'invalid':0}

    def nearest(point):
        best,station = math.inf,0
        for a,b in segments:
            d,t = distance_segment(point,(a['x'],a['z']),(b['x'],b['z']))
            if d < best: best,station = d,a['s']+(b['s']-a['s'])*t
        return best,station

    def alignment(station):
        i = max(0,min(len(rows)-2,bisect.bisect_right(stations,station)-1))
        t = max(0,min(1,(station-stations[i])/max(1,stations[i+1]-stations[i])))
        return rows[i]['render_vertical_offset']*(1-t)+rows[i+1]['render_vertical_offset']*t

    for feature in source['features']:
        geometry = feature['geometry']
        polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']] if geometry['type'] == 'Polygon' else []
        properties = feature['properties']
        for part,rings in enumerate(polygons):
            if len(rings) != 1:
                skipped['holes_or_complex'] += 1
                continue
            ring = []
            for vertex in rings[0]:
                east,north = project(vertex[1],vertex[0],route['origin'])
                if not ring or math.hypot(ring[-1][0]-east,ring[-1][1]+north)>0.05: ring.append([east,-north])
            if len(ring)>1 and math.dist(ring[0],ring[-1])<0.05: ring.pop()
            if len(ring)<3:
                skipped['invalid'] += 1
                continue
            center = [sum(p[i] for p in ring)/len(ring) for i in (0,1)]
            distance,station = nearest(center)
            if distance > 150:
                skipped['outside_corridor'] += 1
                continue
            # Reject actual source conflicts; never move a footprint off-road.
            conflict = any(nearest(p)[0]<4.8 for p in ring)
            if not conflict:
                for a,b in segments:
                    if abs(a['x']-center[0])>200 or abs(a['z']-center[1])>200: continue
                    if inside((a['x'],a['z']),ring): conflict = True; break
                    if any(distance_segment((a['x'],a['z']),p,q)[0]<4.8 for p,q in zip(ring,ring[1:]+ring[:1])): conflict = True; break
            if conflict:
                skipped['road_conflict'] += 1
                continue
            base = properties.get('altitude_minimale_sol')
            base_estimated = not isinstance(base,(int,float))
            if base_estimated: base = sample(route,station)['alt']-alignment(station)
            height = properties.get('hauteur')
            height_estimated = not isinstance(height,(int,float)) or height<1 or height>70
            if height_estimated: height = 7.0
            identity = str(properties.get('cleabs',feature.get('id','unknown')))+':'+str(part)
            buildings.append({'id':identity,'seed':int(hashlib.sha256(identity.encode()).hexdigest()[:7],16),
                'footprint':ring,'center':center,'station':station,'base_ign':base,
                'base_render':base+alignment(station),'base_estimated':base_estimated,
                'height':height,'height_estimated':height_estimated,'nature':properties.get('nature'),
                'source':'IGN BD TOPO','roof':'procedural estimate; not surveyed roof geometry'})
    # Preserve polygon holes in the vegetation masks; they are used at runtime.
    vegetation = []
    for feature in json.loads((directory/'zone_de_vegetation.geojson').read_text())['features']:
        geometry = feature['geometry']
        polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
        for rings in polygons:
            projected = []
            for ring in rings:
                projected.append([[project(v[1],v[0],route['origin'])[0],-project(v[1],v[0],route['origin'])[1]] for v in ring])
            vegetation.append({'id':feature['id'],'nature':feature['properties'].get('nature'),'rings':projected})
    result = {'schema':1,'route_source_sha256':route['source_sha256'],'coverage':manifest['coverage'],
        'buildings':buildings,'vegetation':vegetation,'terrain':terrain,
        'skipped_buildings':skipped,'attribution':'IGN — BD TOPO® / RGE ALTI® ; © OpenStreetMap contributors (source cache)',
        'notes':['Building footprints are IGN, roofs/facades are procedural estimates.',
                 'Source IGN heights and explicit per-station display offsets are both retained.',
                 'OSM is acquired separately, not merged into IGN geometry or redistributed as IGN.']}
    output = directory/'world.json'
    output.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print('World cache:',len(buildings),'buildings,',len(vegetation),'vegetation polygons; skipped',skipped)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--terrain',action='store_true',help='Fetch IGN terrain samples for acquired coverage')
    parser.add_argument('--directory',type=Path,default=ROOT/'assets/geodata')
    args = parser.parse_args()
    route = json.loads((ROOT/'assets/routes/saint_die.json').read_text())
    if args.terrain: acquire_terrain(route,args.directory)
    prepare(route,args.directory)


if __name__ == '__main__':
    main()
