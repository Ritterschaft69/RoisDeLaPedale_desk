import json
import hashlib
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_route import project
from build_geoworld import unproject, inside, distance_segment
from fetch_geodata import coverage


class GeographicDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = ROOT/'assets/geodata'
        cls.route = json.loads((ROOT/'assets/routes/saint_die.json').read_text())
        cls.world = json.loads((cls.directory/'world.json').read_text())

    def test_acquired_sources_are_real_and_counted(self):
        manifest = json.loads((self.directory/'manifest.json').read_text())
        self.assertEqual(manifest['status'],'downloaded_not_integrated')
        for source in ['BDTOPO_V3:batiment','BDTOPO_V3:zone_de_vegetation','osm','ign_rge_alti_wld']:
            self.assertEqual(manifest['sources'][source]['status'],'downloaded')
        self.assertEqual(len(json.loads((self.directory/'batiment.geojson').read_text())['features']),2100)
        self.assertEqual(len(json.loads((self.directory/'osm.json').read_text())['elements']),2861)

    def test_reproducible_raw_response_receipts(self):
        manifest = json.loads((self.directory/'manifest.json').read_text())
        terrain = json.loads((self.directory/'terrain.json').read_text())
        # Source files in the repository remain usable without ignored HTTP
        # caches. If caches are present, check their exact receipt hashes too.
        checked = 0
        for receipt in manifest['receipts']+terrain['receipts']:
            path = self.directory/'cache'/receipt['file']
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),receipt['sha256'])
                checked += 1
        self.assertTrue(manifest['receipts'])

    def test_inverse_projection_roundtrip(self):
        origin = self.route['origin']
        for east,north in [(0,0),(20000,-12000),(-4000,1000)]:
            lat,lon = unproject(east,north,origin)
            x,y = project(lat,lon,origin)
            self.assertAlmostEqual(x,east,delta=0.001)
            self.assertAlmostEqual(y,north,delta=0.001)

    def test_source_footprints_and_heights_preserved(self):
        sources = {f['properties']['cleabs']:f for f in json.loads((self.directory/'batiment.geojson').read_text())['features']}
        for building in self.world['buildings']:
            identity,index = building['id'].split(':')
            source = sources[identity]
            polygon = source['geometry']['coordinates'][int(index)][0]
            for projected,raw in zip(building['footprint'],polygon):
                x,y = project(raw[1],raw[0],self.route['origin'])
                self.assertAlmostEqual(projected[0],x)
                self.assertAlmostEqual(projected[1],-y)
            if not building['height_estimated']:
                self.assertEqual(building['height'],source['properties']['hauteur'])
        self.assertGreater(len(self.world['buildings']),500)

    def test_terrain_source_and_visual_offsets_are_separate(self):
        rows = self.world['terrain']['rows']
        self.assertEqual(len(rows),61)
        self.assertEqual(sum(len(r['samples']) for r in rows),549)
        for row in rows:
            self.assertAlmostEqual(row['samples'][4]['ign_altitude']+row['render_vertical_offset'],row['gpx_altitude'])
            for p in row['samples']:
                self.assertTrue(math.isfinite(p['ign_altitude']))
        self.assertEqual(self.world['route_source_sha256'],self.route['source_sha256'])

    def test_coverage_and_geometric_primitives(self):
        area,points = coverage(self.route,0,3,180)
        self.assertEqual(area['end_m'],3000)
        self.assertGreater(points[-1]['s'],3000)
        self.assertTrue(inside((1,1),[[0,0],[2,0],[2,2],[0,2]]))
        self.assertFalse(inside((3,1),[[0,0],[2,0],[2,2],[0,2]]))
        self.assertEqual(distance_segment((5,3),(0,0),(10,0)),(3,0.5))
        with self.assertRaises(ValueError): coverage(self.route,0,-1,180)


if __name__ == '__main__': unittest.main()
