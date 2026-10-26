import hashlib
import json
import math
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from prepare_route import convert, project, haversine


class RouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = ROOT/'assets/routes/saint_die.gpx'
        cls.route = convert(cls.source)

    def test_preserves_every_coordinate_and_altitude(self):
        nodes = [x for x in ET.parse(self.source).getroot().iter() if x.tag.split('}')[-1] == 'trkpt']
        self.assertEqual(len(nodes), 3383)
        self.assertEqual(len(self.route['points']), len(nodes))
        for node, p in zip(nodes, self.route['points']):
            self.assertEqual(float(node.attrib['lat']), p['lat'])
            self.assertEqual(float(node.attrib['lon']), p['lon'])
            self.assertEqual(float(next(c.text for c in node if c.tag.split('}')[-1] == 'ele')), p['alt'])

    def test_distance_and_raw_ascent(self):
        self.assertAlmostEqual(self.route['length_m'], 66298.9, delta=1)
        self.assertAlmostEqual(self.route['ascent_raw_m'], 1585.4, delta=0.01)
        self.assertNotAlmostEqual(self.route['ascent_raw_m'], 1242, delta=10)
        points = self.route['points']
        self.assertEqual(points[0]['s'], 0)
        for a, b in zip(points, points[1:]):
            self.assertGreaterEqual(b['s'], a['s'])
            self.assertLess(b['s']-a['s'], 200, 'Unexpected source discontinuity')

    def test_local_frame_metric_and_orientation(self):
        origin = (48.27588, 6.96345)
        self.assertEqual(project(*origin, origin), (0, 0))
        east = project(origin[0], origin[1]+0.001, origin)
        north = project(origin[0]+0.001, origin[1], origin)
        self.assertGreater(east[0], 70)
        self.assertLess(abs(east[1]), 0.01)
        self.assertGreater(north[1], 110)
        self.assertLess(abs(north[0]), 0.01)
        for p in self.route['points']:
            if p['s'] == 0: continue
            direct = haversine(origin, (p['lat'],p['lon']))
            local = math.hypot(p['x'],p['z'])
            # Spherical distance vs ellipsoidal ENU, bounded and documented.
            self.assertLess(abs(local-direct), max(1, direct*0.004))

    def test_derived_file_is_current_and_repeatable(self):
        saved = json.loads((ROOT/'assets/routes/saint_die.json').read_text())
        self.assertEqual(saved, self.route)
        self.assertEqual(saved['source_sha256'],hashlib.sha256(self.source.read_bytes()).hexdigest())


if __name__ == '__main__':
    unittest.main()
