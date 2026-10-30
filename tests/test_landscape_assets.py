"""Independent audit of baked forest coverage, heights and bounded buffers."""
import gzip,hashlib,json,math,struct,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from circuit_geography import Terrain,polynomial_terms


class LandscapeAssetsTests(unittest.TestCase):
    def test_forest_tiles_match_lidar_and_have_valid_bounded_geometry(self):
        terrain=Terrain()
        for entry in json.loads((ROOT/'assets/routes/catalog.json').read_text()):
            directory=ROOT/'assets/geodata/circuits'/entry['id']
            metadata=json.loads((directory/'forest.json').read_text())
            world=json.loads((directory/'world.json').read_text());transform=world['terrain_transform']
            data=(directory/metadata['file']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(),metadata['sha256'])
            self.assertEqual(metadata['route_source_sha256'],world['route_source_sha256'])
            self.assertEqual(metadata['compression'],'gzip_tiles')
            self.assertGreater(len(metadata['tiles']),20)
            total=0
            for tile in metadata['tiles']:
                block=gzip.decompress(data[tile['offset']:tile['offset']+tile['byte_length']])
                self.assertEqual(len(block),tile['vertices']*16)
                self.assertEqual(tile['vertices']%3,0);total+=tile['vertices']//3
                # Spread checks across all cells, not just around the origin:
                # catches a double-normalisation of the geographic transform.
                vertices=list(struct.iter_unpack('<ffff',block))
                for p in vertices[::max(1,len(vertices)//5)]:
                    self.assertTrue(all(math.isfinite(v) for v in p))
                    self.assertTrue(tile['x']-.02<=p[0]<=tile['x']+metadata['tile_size_m']+.02)
                    self.assertTrue(tile['z']-.02<=p[2]<=tile['z']+metadata['tile_size_m']+.02)
                    if p[1]>=p[3]-.05:
                        terms=polynomial_terms(p[0],p[2]);e=sum(a*b for a,b in zip(transform['x'],terms));n=sum(a*b for a,b in zip(transform['y'],terms))
                        ground=terrain.at(e,n)
                        self.assertIsNotNone(ground)
                        self.assertAlmostEqual(p[3],ground,delta=.04)
                        self.assertGreaterEqual(p[1]-ground,-.1)
                        self.assertLessEqual(p[1]-ground,28)
            self.assertEqual(total,metadata['triangles'])

    def test_forest_mask_preserves_clearings_roads_buildings_and_water(self):
        from prepare_forests import forest_mask
        from shapely import Point
        world={'vegetation':[{'nature':'Bois','rings':[
          [[0,0],[200,0],[200,200],[0,200],[0,0]],
          [[60,60],[80,60],[80,80],[60,80],[60,60]]]},
          {'nature':'Vigne','rings':[[[300,0],[350,0],[350,50],[300,50],[300,0]]]}],
          'buildings':[{'footprint':[[20,20],[30,20],[30,30],[20,30]]}],
          'water':[{'points':[[140,0,40],[160,0,40],[160,0,60],[140,0,60]],'indices':[0,1,2,0,2,3]}]}
        roads=[{'tags':{'highway':'residential'},'points':[[100,0,0],[100,0,200]]}]
        mask=forest_mask(world,roads)
        for p in [(70,70),(100,150),(25,25),(150,50),(320,20)]:
            self.assertFalse(mask.contains(Point(*p)),p)
        self.assertTrue(mask.contains(Point(40,150)))
