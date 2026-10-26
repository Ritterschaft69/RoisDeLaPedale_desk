"""Acquire IGN/OSM source data explicitly; the game itself never needs network.

Default is a 3 km audit slice with a 180 m corridor bounding box. Raw responses
are content-addressed, checked before use, and accompanied by a provenance
manifest. Failed/incomplete acquisitions are never labelled as integrated data.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WFS = 'https://data.geopf.fr/wfs/ows'
ALTI = 'https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json'
OVERPASS = 'https://overpass-api.de/api/interpreter'


def coverage(route, start_km, length_km, margin_m):
    points = route['points']
    start, end = start_km*1000, min(route['length_m'], (start_km+length_km)*1000)
    if start < 0 or end <= start or length_km <= 0 or margin_m <= 0:
        raise ValueError('Invalid acquisition coverage')
    selected = [p for p in points if start <= p['s'] <= end]
    before = [p for p in points if p['s'] < start]
    after = [p for p in points if p['s'] > end]
    if before: selected.insert(0,before[-1])
    if after: selected.append(after[0])
    dlat = margin_m / 110574
    dlon = margin_m / (111320 * math.cos(math.radians(selected[0]['lat'])))
    bbox = [min(p['lon'] for p in selected)-dlon, min(p['lat'] for p in selected)-dlat,
            max(p['lon'] for p in selected)+dlon, max(p['lat'] for p in selected)+dlat]
    return {'start_m':start,'end_m':end,'margin_m':margin_m,'bbox_crs84':bbox}, selected


class SourceClient:
    def __init__(self, cache):
        self.cache = Path(cache)
        self.cache.mkdir(parents=True, exist_ok=True)
        self.receipts = []

    def get(self, url, *, form=None, kind='json'):
        body = urllib.parse.urlencode(form).encode() if form else None
        digest = hashlib.sha256(url.encode()+b'\n'+(body or b'')).hexdigest()
        path = self.cache/(digest+('.json' if kind=='json' else '.xml'))
        cached = path.exists()
        if cached:
            content = path.read_bytes()
        else:
            headers = {'User-Agent':'RoisDeLaPedale/0.1 geographic-audit', 'Accept':'application/json' if kind=='json' else 'application/xml'}
            if form: headers['Content-Type'] = 'application/x-www-form-urlencoded'
            request = urllib.request.Request(url, data=body, headers=headers)
            with urllib.request.urlopen(request, timeout=90) as response:
                content = response.read(64*1024*1024+1)
            if len(content) > 64*1024*1024:
                raise ValueError('Response exceeds 64 MiB; use a smaller coverage')
        # Parse even cache hits. Never cache HTML/errors as geographic features.
        parsed = json.loads(content) if kind == 'json' else ET.fromstring(content)
        if kind == 'json' and isinstance(parsed,dict) and any(k in parsed for k in ('error','remark','ExceptionReport')):
            raise ValueError('Service reported an error or incomplete query: '+str(parsed)[:300])
        if kind != 'json' and parsed.tag.split('}')[-1] != 'WFS_Capabilities':
            raise ValueError('Expected WFS capabilities, not an exception document')
        if not cached:
            temporary = path.with_suffix('.tmp')
            temporary.write_bytes(content)
            temporary.replace(path)
            time.sleep(0.3) # respect public infrastructure, no parallel query burst
        self.receipts.append({'url':url,'post_form':form,'file':path.name,
                              'sha256':hashlib.sha256(content).hexdigest(),'cached':cached})
        return parsed


def ign_features(client, layer, bbox):
    features = []
    start = 0
    while True:
        params = {'SERVICE':'WFS','VERSION':'2.0.0','REQUEST':'GetFeature',
                  'TYPENAMES':layer,'OUTPUTFORMAT':'application/json','SRSNAME':'urn:ogc:def:crs:OGC:1.3:CRS84',
                  'BBOX':','.join(map(str,bbox))+',urn:ogc:def:crs:OGC:1.3:CRS84',
                  'COUNT':1000,'STARTINDEX':start}
        result = client.get(WFS+'?'+urllib.parse.urlencode(params))
        if result.get('type') != 'FeatureCollection' or not isinstance(result.get('features'),list):
            raise ValueError('Invalid WFS GeoJSON response')
        batch = result['features']
        features.extend(batch)
        total = result.get('numberMatched')
        if not batch or (str(total).isdigit() and len(features) >= int(total)) or len(batch)<1000:
            if str(total).isdigit() and len(features) != int(total):
                raise ValueError('Incomplete WFS pagination')
            break
        start += len(batch)
        if start >= 20000: raise ValueError('Too many WFS features; reduce the requested coverage')
    ids = [f.get('id') for f in features]
    if len(set(ids)) != len(ids): raise ValueError('Repeated WFS page or feature identifiers')
    return {'type':'FeatureCollection','features':features}


def acquire(args):
    route = json.loads((ROOT/'assets/routes/saint_die.json').read_text())
    area, points = coverage(route,args.start_km,args.length_km,args.margin_m)
    destination = args.output
    destination.mkdir(parents=True,exist_ok=True)
    manifest = {'schema':1,'acquired_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                'route_source_sha256':route['source_sha256'],'coverage':area,
                'status':'planned','sources':{},'receipts':[],
                'integration_status':'source acquisition only; not a verified terrain or building scene'}
    print(json.dumps(area,indent=2))
    if not args.fetch:
        print('Plan only. Use --fetch to contact the public services.')
        return 0
    client = SourceClient(destination/'cache')
    errors = 0
    if args.source in ('ign','all'):
        try:
            capabilities = client.get(WFS+'?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities',kind='xml')
            names = {n.text for n in capabilities.findall('.//{http://www.opengis.net/wfs/2.0}FeatureType/{http://www.opengis.net/wfs/2.0}Name')}
            for layer in ('BDTOPO_V3:batiment','BDTOPO_V3:zone_de_vegetation'):
                if layer not in names:
                    raise ValueError('Requested layer not advertised by WFS: '+layer)
                features = ign_features(client,layer,area['bbox_crs84'])
                filename = layer.split(':')[1]+'.geojson'
                (destination/filename).write_text(json.dumps(features,ensure_ascii=False))
                manifest['sources'][layer] = {'status':'downloaded','file':filename,'features':len(features['features']),
                    'licence':'Licence Ouverte 2.0 — verify current dataset metadata before redistribution',
                    'attribution':'IGN — BD TOPO®', 'crs':'OGC:CRS84'}
        except (OSError,ValueError,ET.ParseError) as exc:
            errors += 1
            manifest['sources']['ign_wfs'] = {'status':'blocked','error':str(exc)}
        try:
            # Audit source elevation every ~100 m along the track. This is NOT
            # a LiDAR terrain grid and must never replace the source GPX.
            sampled = [points[0]]
            for p in points[1:]:
                if p['s']-sampled[-1]['s'] >= 100: sampled.append(p)
            if sampled[-1] != points[-1]: sampled.append(points[-1])
            audit = []
            for index in range(0,len(sampled),100):
                batch = sampled[index:index+100]
                params = {'resource':'ign_rge_alti_wld','lon':'|'.join(str(p['lon']) for p in batch),
                          'lat':'|'.join(str(p['lat']) for p in batch),'zonly':'false'}
                result = client.get(ALTI+'?'+urllib.parse.urlencode(params))
                elevations = result.get('elevations',[])
                if len(elevations) != len(batch): raise ValueError('Incomplete elevation response')
                for p, e in zip(batch,elevations):
                    z = e.get('z') if isinstance(e,dict) else e
                    if not isinstance(z,(int,float)) or not math.isfinite(z) or z < -500:
                        raise ValueError('IGN elevation unavailable at a requested point')
                    audit.append({'lat':p['lat'],'lon':p['lon'],'s':p['s'],'gpx_altitude':p['alt'],'ign_altitude':z,'response':e})
            (destination/'elevation_audit.json').write_text(json.dumps(audit,ensure_ascii=False))
            manifest['sources']['ign_rge_alti_wld'] = {'status':'downloaded','file':'elevation_audit.json',
                'samples':len(audit),'attribution':'IGN — RGE ALTI®',
                'note':'Point elevation audit only. No claim of LiDAR HD acquisition; GPX vertical datum unknown.'}
        except (OSError,ValueError) as exc:
            errors += 1
            manifest['sources']['ign_altimetry'] = {'status':'blocked','error':str(exc)}
    if args.source in ('osm','all'):
        try:
            west,south,east,north = area['bbox_crs84']
            bbox = f'{south},{west},{north},{east}'
            query = f'[out:json][timeout:60];(way["building"]({bbox});relation["building"]({bbox});way["landuse"="forest"]({bbox});relation["landuse"="forest"]({bbox});way["natural"="wood"]({bbox});way["waterway"]({bbox});way["highway"]({bbox}););out geom;'
            result = client.get(OVERPASS,form={'data':query})
            if not isinstance(result.get('elements'),list): raise ValueError('Invalid Overpass response')
            (destination/'osm.json').write_text(json.dumps(result,ensure_ascii=False))
            manifest['sources']['osm'] = {'status':'downloaded','file':'osm.json','elements':len(result['elements']),
                'licence':'ODbL 1.0','attribution':'© OpenStreetMap contributors',
                'copyright':'https://www.openstreetmap.org/copyright',
                'note':'Raw ways and relations retained. Relation rings and holes must be assembled before rendering.'}
        except (OSError,ValueError) as exc:
            errors += 1
            manifest['sources']['osm'] = {'status':'blocked','error':str(exc)}
    manifest['receipts'] = client.receipts
    manifest['status'] = 'blocked_or_partial' if errors else 'downloaded_not_integrated'
    (destination/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    for name,result in manifest['sources'].items(): print(name,result['status'],result.get('error',''))
    return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch',action='store_true')
    parser.add_argument('--source',choices=['all','ign','osm'],default='all')
    parser.add_argument('--start-km',type=float,default=0)
    parser.add_argument('--length-km',type=float,default=3)
    parser.add_argument('--margin-m',type=float,default=180)
    parser.add_argument('--output',type=Path,default=ROOT/'assets/geodata')
    args = parser.parse_args()
    raise SystemExit(acquire(args))


if __name__ == '__main__':
    main()
