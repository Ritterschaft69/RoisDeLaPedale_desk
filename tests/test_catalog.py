import hashlib
import json
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_route import convert


class CatalogueTests(unittest.TestCase):
    def test_all_installed_sources_preserve_every_point_and_altitude(self):
        entries = json.loads((ROOT/'assets/routes/catalog.json').read_text())
        self.assertEqual([e['id'] for e in entries],['saint_die','sortie_matin','oderen_grand_ballon'])
        for entry, expected in zip(entries,[3383,19641,20459]):
            with self.subTest(circuit=entry['id']):
                source = ROOT/'assets/routes'/entry['source']
                saved = json.loads((ROOT/entry['data'].removeprefix('res://')).read_text())
                rebuilt = convert(source,entry['name'])
                self.assertEqual(saved,rebuilt)
                self.assertEqual(saved['source_sha256'],hashlib.sha256(source.read_bytes()).hexdigest())
                self.assertEqual(len(saved['points']),expected)
                self.assertEqual(entry['point_count'],expected)
                self.assertEqual(entry['length_m'],saved['length_m'])
                self.assertEqual(entry['ascent_raw_m'],saved['ascent_raw_m'])
                raw = [n for n in ET.parse(source).getroot().iter() if n.tag.split('}')[-1] == 'trkpt']
                for node,p in zip(raw,saved['points']):
                    self.assertEqual(float(node.attrib['lat']),p['lat'])
                    self.assertEqual(float(node.attrib['lon']),p['lon'])
                    self.assertEqual(float(next(c.text for c in node if c.tag.split('}')[-1]=='ele')),p['alt'])

    def test_new_circuit_metrics_are_computed_from_sources(self):
        entries = json.loads((ROOT/'assets/routes/catalog.json').read_text())
        self.assertAlmostEqual(entries[1]['length_m']/1000,102.362,delta=0.001)
        self.assertAlmostEqual(entries[2]['length_m']/1000,120.675,delta=0.001)
        self.assertAlmostEqual(entries[1]['ascent_raw_m'],2233.2,delta=0.1)
        self.assertAlmostEqual(entries[2]['ascent_raw_m'],2229.2,delta=0.1)


if __name__ == '__main__': unittest.main()
