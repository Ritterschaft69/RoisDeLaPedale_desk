"""Lossless GPX source + derived WGS84 local tangent plane, no network required."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
A = 6378137.0
E2 = 6.6943799901413165e-3


def ecef(lat, lon, height=0):
    lat, lon = math.radians(lat), math.radians(lon)
    n = A / math.sqrt(1 - E2 * math.sin(lat)**2)
    return ((n+height)*math.cos(lat)*math.cos(lon),
            (n+height)*math.cos(lat)*math.sin(lon),
            (n*(1-E2)+height)*math.sin(lat))


def project(lat, lon, origin):
    """East, north in metres; WGS84 ECEF -> local ENU, surface height zero."""
    lat0, lon0 = map(math.radians, origin)
    delta = [a-b for a, b in zip(ecef(lat, lon), ecef(*origin))]
    x, y, z = delta
    return (-math.sin(lon0)*x + math.cos(lon0)*y,
            -math.sin(lat0)*math.cos(lon0)*x-math.sin(lat0)*math.sin(lon0)*y+math.cos(lat0)*z)


def haversine(a, b):
    """Horizontal great-circle distance; explicit mean Earth radius, metres."""
    p, q = math.radians(a[0]), math.radians(b[0])
    h = math.sin((q-p)/2)**2 + math.cos(p)*math.cos(q)*math.sin(math.radians(b[1]-a[1])/2)**2
    return 6371008.8 * 2 * math.asin(min(1, math.sqrt(h)))


def convert(source: Path, name: str | None = None):
    root = ET.parse(source).getroot()
    segments = [n for n in root.iter() if n.tag.split('}')[-1] == 'trkseg']
    if len(segments) != 1:
        raise ValueError('Expected one continuous GPX track segment; refusing to bridge gaps')
    points = []
    for node in segments[0]:
        if node.tag.split('}')[-1] != 'trkpt':
            continue
        ele = next((c.text for c in node if c.tag.split('}')[-1] == 'ele'), None)
        if ele is None:
            raise ValueError('Missing altitude; do not invent elevation')
        p = [float(node.attrib['lat']), float(node.attrib['lon']), float(ele)]
        if not all(math.isfinite(x) for x in p) or not -90 <= p[0] <= 90 or not -180 <= p[1] <= 180:
            raise ValueError('Invalid coordinates')
        points.append(p)
    if len(points) < 2:
        raise ValueError('Track requires at least two points')
    origin = points[0][:2]
    samples, distance, ascent = [], 0.0, 0.0
    for i, p in enumerate(points):
        if i:
            distance += haversine(points[i-1], p)
            ascent += max(0, p[2]-points[i-1][2])
        east, north = project(*p[:2], origin)
        samples.append({'lat': p[0], 'lon': p[1], 'alt': p[2], 's': distance, 'x': east, 'z': -north})
    if name is None:
        name = 'Boucle de Saint-Dié-des-Vosges' if source.stem == 'saint_die' else next(
            (n.text.strip() for n in root.iter() if n.tag.split('}')[-1] == 'name' and n.text), source.stem)
    return {'schema': 1, 'name': name,
            'source': source.name, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'origin': origin, 'projection': 'WGS84 ECEF to local ENU; Godot x=east, z=-north, y=GPX elevation',
            'distance_method': 'horizontal haversine, mean Earth radius 6371008.8 m',
            'elevation_note': 'GPX source, vertical datum unspecified; ascent is raw, not denoised',
            'length_m': distance, 'ascent_raw_m': ascent, 'points': samples}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT/'assets/routes/saint_die.gpx')
    parser.add_argument('--output', type=Path, default=ROOT/'assets/routes/saint_die.json')
    parser.add_argument('--all', action='store_true', help='Prepare every circuit in the local catalogue')
    args = parser.parse_args()
    jobs = [(args.source,args.output,None)]
    entries = []
    if args.all:
        entries = json.loads((ROOT/'assets/routes/catalog.json').read_text())
        jobs = [(ROOT/'assets/routes'/entry['source'],ROOT/entry['data'].removeprefix('res://'),entry['name']) for entry in entries]
    for source,output,name in jobs:
        route = convert(source,name)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(route, separators=(',', ':'), ensure_ascii=False)+'\n')
        print(f"{route['name']} · {len(route['points'])} points · {route['length_m']/1000:.3f} km · D+ brut {route['ascent_raw_m']:.1f} m")
        if args.all:
            entry = next(e for e in entries if e['source'] == source.name)
            entry.update(length_m=route['length_m'],ascent_raw_m=route['ascent_raw_m'],point_count=len(route['points']))
    if args.all:
        (ROOT/'assets/routes/catalog.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    main()
