"""Network-free geography regressions and audit of installed source caches."""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import unittest
import tempfile
import io
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from circuit_geography import (lambert93,inverse_lambert93,RoadGraph,Track,
    match_track,resample,gaussian,terrain_transform,polynomial_terms,Terrain,OUT,Client,parse_osm)
from build_geoworld import unproject
from prepare_route import project


class MatchingTests(unittest.TestCase):
    origin=(48.,7.)

    def way(self,identity,nodes,coords,tags=None):
        geometry=[]
        for x,z in coords:
            lat,lon=unproject(x,-z,self.origin)
            geometry.append({'lat':lat,'lon':lon})
        return {'id':identity,'nodes':nodes,'geometry':geometry,'tags':{'highway':'residential',**(tags or {})}}

    def track(self,coords):
        points=[];s=0.
        for i,(x,z) in enumerate(coords):
            if i:s+=math.dist(coords[i-1],(x,z))
            lat,lon=unproject(x,-z,self.origin)
            points.append({'x':x,'z':z,'s':s,'alt':300.,'lat':lat,'lon':lon})
        return Track({'origin':self.origin,'points':points,'length_m':s})

    def test_projection_against_independent_epsg2154_reference_and_roundtrip(self):
        x,y=lambert93(48.85341,2.3488)
        # EPSG:2154 GRS80 control (Paris); deliberately not a circular-only test.
        self.assertAlmostEqual(x,652216.635,delta=.01)
        self.assertAlmostEqual(y,6861682.612,delta=.01)
        for p in [(48.27,6.98),(47.9,7.2)]:
            q=inverse_lambert93(*lambert93(*p))
            self.assertAlmostEqual(p[0],q[0],places=9)
            self.assertAlmostEqual(p[1],q[1],places=9)

    def test_official_osm_xml_import_fresh_download_and_verified_cache(self):
        xml=b'<osm><node id="1" lat="48" lon="7"/><node id="2" lat="48.001" lon="7"/><way id="9"><nd ref="1"/><nd ref="2"/><tag k="highway" v="residential"/></way></osm>'
        with tempfile.TemporaryDirectory() as directory, mock.patch('circuit_geography.RAW',Path(directory)):
            client=Client()
            with mock.patch('urllib.request.urlopen',return_value=io.BytesIO(xml)) as request:
                first=client.get('https://www.openstreetmap.org/api/0.6/map?bbox=fixture',kind='osm')
                self.assertEqual(first['elements'][0]['geometry'][1]['lat'],48.001)
                self.assertEqual(request.call_count,1)
            with mock.patch('urllib.request.urlopen',side_effect=AssertionError('cache should be offline')):
                self.assertEqual(client.get('https://www.openstreetmap.org/api/0.6/map?bbox=fixture',kind='osm'),first)
            self.assertEqual(next(iter(client.receipts.values()))['sha256'],hashlib.sha256(xml).hexdigest())

    def test_osm_api_missing_geometry_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_osm(b'<osm><way id="9"><nd ref="999"/><tag k="highway" v="residential"/></way></osm>')

    def test_hairpin_follows_network_instead_of_diagonal_shortcut(self):
        way=self.way(10,[1,2,3,4],[(0,0),(60,0),(60,12),(0,12)])
        track=self.track([(0,1),(30,1),(59,1),(59,11),(30,11),(0,11)])
        graph=RoadGraph([way],self.origin)
        path,report=match_track(track,graph)
        self.assertGreater(report['matched_fraction'],.95)
        self.assertTrue(any(p['x']>59.5 for p in path))
        derived,_,length=resample(path,2)
        self.assertGreater(length,125)
        self.assertTrue(all(min(abs(p['z']),abs(p['z']-12),abs(p['x']-60))<.01 for p in derived))

    def test_disconnected_crossing_never_becomes_graph_connection(self):
        graph=RoadGraph([self.way(10,[1,2],[(-50,0),(50,0)]),
                         self.way(20,[3,4],[(0,-50),(0,50)],{'bridge':'yes'})],self.origin)
        self.assertTrue(math.isinf(graph.shortest(1,4)[0]))
        # The bridge crosses geometrically but does not share a node.
        a=graph.candidates((-5,0),(1,0))[0]
        b=graph.candidates((0,5),(0,1))[0]
        self.assertTrue(math.isinf(graph.transition(a,b,{})[0]))

    def test_oneway_and_bicycle_exception(self):
        graph=RoadGraph([self.way(10,[1,2],[(0,0),(50,0)],{'oneway':'yes'})],self.origin)
        self.assertTrue(math.isinf(graph.shortest(2,1)[0]))
        graph=RoadGraph([self.way(10,[1,2],[(0,0),(50,0)],{'oneway':'yes','oneway:bicycle':'no'})],self.origin)
        self.assertAlmostEqual(graph.shortest(2,1)[0],50,places=4)

    def test_missing_osm_retains_explicit_source_fallback(self):
        track=self.track([(0,0),(50,0),(100,20)])
        path,report=match_track(track,RoadGraph([],self.origin))
        self.assertEqual(report['matched_fraction'],0)
        self.assertEqual(report['unverified_source_intervals_m'][0][0],0)
        self.assertEqual(path[-1]['source_s'],track.stations[-1])
        self.assertTrue(all(p['osm_way'] is None for p in path))

    def test_uniform_simulation_station_and_preserved_source_mapping(self):
        points=[{'x':0.,'z':0.,'source_s':0.},{'x':5.,'z':0.,'source_s':10.},
                {'x':5.,'z':5.,'source_s':20.}]
        result,spacing,length=resample(points,2)
        self.assertEqual(length,10)
        self.assertEqual(spacing,2)
        self.assertTrue(all(a['source_s']<=b['source_s'] for a,b in zip(result,result[1:])))
        self.assertEqual(result[-1]['source_s'],20)

    def test_altitude_filter_preserves_constant_grade_and_removes_grid_ripple(self):
        line=[300+i*.1 for i in range(200)]
        clean=gaussian(line,5,2)
        self.assertLess(max(abs(a-b) for a,b in zip(line,clean)),1e-9)
        noisy=[v+(.5 if i%2 else -.5) for i,v in enumerate(line)]
        smooth=gaussian(noisy,5,2)
        self.assertLess(max(abs(a-b) for a,b in zip(line[20:-20],smooth[20:-20])),.01)


class InstalledGeographyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries=json.loads((ROOT/'assets/routes/catalog.json').read_text())

    def test_all_complete_derived_routes_and_unchanged_gpx_hashes(self):
        for entry in self.entries:
            with self.subTest(circuit=entry['id']):
                raw=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
                directory=OUT/entry['id']
                metadata=json.loads((directory/'route.json').read_text())
                self.assertEqual(metadata['route_source_sha256'],hashlib.sha256((ROOT/'assets/routes'/entry['source']).read_bytes()).hexdigest())
                self.assertEqual(metadata['route_source_sha256'],raw['source_sha256'])
                packed=(directory/'route.bin').read_bytes()
                self.assertEqual(hashlib.sha256(packed).hexdigest(),metadata['points_sha256'])
                self.assertEqual(len(packed),metadata['point_count']*16)
                coordinates=(directory/'coordinates.bin').read_bytes()
                self.assertEqual(hashlib.sha256(coordinates).hexdigest(),metadata['coordinates_sha256'])
                self.assertEqual(len(coordinates),metadata['point_count']*16)
                self.assertLessEqual(metadata['spacing_m'],2)
                self.assertEqual(metadata['missing_lidar_stations_m'],[])
                points=list(struct.iter_unpack('<ffff',packed))
                self.assertLess(abs(points[-1][3]-raw['length_m']),.01)
                for a,b in zip(points,points[1:]):
                    self.assertTrue(all(math.isfinite(v) for v in b))
                    self.assertGreaterEqual(b[3]+.01,a[3])
                    self.assertLessEqual(math.hypot(b[0]-a[0],b[2]-a[2]),2.02)
                self.assertGreater(metadata['osm_match']['matched_fraction'],.95)

    def test_numeric_lidar_tiles_are_complete_and_hashed(self):
        index=json.loads((OUT/'terrain/index.json').read_text())
        self.assertEqual(index['height_datum'],'IGN69')
        self.assertGreater(len(index['tiles']),200)
        for tile in index['tiles']:
            for source in tile['sources'].values():
                data=(OUT/'terrain'/source['file']).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(),source['sha256'])
                self.assertEqual(len(data),tile['size']**2*4)
                self.assertEqual(source['valid_pixels'],source['total_pixels'])
        horizon=index['horizon']
        data=(OUT/'terrain'/horizon['file']).read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(),horizon['sha256'])
        self.assertEqual(len(data),horizon['width']*horizon['height']*4)
        self.assertGreater(horizon['valid_pixels']/horizon['total_pixels'],.999)

    def test_full_route_terrain_coverage_and_projection_audits(self):
        terrain=Terrain()
        for entry in self.entries:
            raw=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
            world=json.loads((OUT/entry['id']/'world.json').read_text())
            self.assertLess(world['terrain_transform']['max_audited_error_m'],.05)
            self.assertGreater(len(world['buildings']),100)
            for p in raw['points'][::30]:
                self.assertIsNotNone(terrain.height(p['lat'],p['lon']))
                self.assertIsNotNone(terrain.height(p['lat'],p['lon'],'mnh'))

    def test_shared_horizon_covers_every_installed_circuit(self):
        terrain=Terrain()
        for entry in self.entries:
            raw=json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
            for point in raw['points'][::100]:
                x,y=lambert93(point['lat'],point['lon'])
                self.assertIsNotNone(terrain.horizon_height(x,y),entry['id'])

    def test_water_meshes_preserve_island_holes(self):
        from build_geoworld import inside
        holes_checked=0
        for entry in self.entries:
            world=json.loads((OUT/entry['id']/'world.json').read_text())
            for water in world['water']:
                self.assertEqual(len(water['indices'])%3,0)
                for hole in water['holes']:
                    holes_checked+=1
                    for i in range(0,len(water['indices']),3):
                        indices=water['indices'][i:i+3]
                        self.assertTrue(all(j==int(j) for j in indices))
                        vertices=[water['points'][int(j)] for j in indices]
                        centroid=(sum(p[0] for p in vertices)/3,sum(p[2] for p in vertices)/3)
                        self.assertFalse(inside(centroid,hole),'Water triangle fills an island')
        self.assertGreater(holes_checked,0)


if __name__=='__main__':unittest.main()
