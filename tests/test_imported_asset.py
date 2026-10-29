import hashlib
import json
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]


class ImportedAssetTests(unittest.TestCase):
    def test_supplied_glb_is_losslessly_preserved_and_self_contained(self):
        folder=ROOT/'assets/models/imported-cyclist'
        data=(folder/'cycliste-universel.glb').read_bytes()
        metadata=json.loads((folder/'metadata.json').read_text())
        expected='bb1b9a9385bc27e0c18f88979c0d1feed14b44c29c7cbbab205b9e0368a6e9e3'
        self.assertEqual(hashlib.sha256(data).hexdigest(),expected)
        self.assertEqual(metadata['sha256'],expected)
        magic,version,size=struct.unpack_from('<4sII',data)
        self.assertEqual((magic,version,size),(b'glTF',2,len(data)))
        length,kind=struct.unpack_from('<I4s',data,12)
        self.assertEqual(kind,b'JSON')
        gltf=json.loads(data[20:20+length])
        self.assertEqual({a['name'] for a in gltf['animations']},{'PedalForward_60rpm','WheelRoll_1turn'})
        self.assertEqual(len(gltf['skins'][0]['joints']),22)
        self.assertFalse(gltf.get('images'))
        self.assertTrue(all('uri' not in b for b in gltf['buffers']))
        triangles=sum(gltf['accessors'][p.get('indices',p['attributes']['POSITION'])]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
        self.assertEqual(triangles,12072)

    def test_tricolour_model_contains_new_skinned_geometry_and_shared_animation_contract(self):
        folder=ROOT/'assets/models/tricolour-cyclist'
        data=(folder/'cycliste-tricolore.glb').read_bytes()
        metadata=json.loads((folder/'metadata.json').read_text())
        self.assertEqual(hashlib.sha256(data).hexdigest(),metadata['sha256'])
        self.assertEqual(metadata['source_bicycle_sha256'],'bb1b9a9385bc27e0c18f88979c0d1feed14b44c29c7cbbab205b9e0368a6e9e3')
        length=struct.unpack_from('<I',data,12)[0]
        gltf=json.loads(data[20:20+length])
        self.assertEqual({a['name'] for a in gltf['animations']},{'PedalForward_60rpm','WheelRoll_1turn'})
        body=next(n for n in gltf['nodes'] if n.get('name')=='TricolourFemaleCharacter')
        self.assertEqual(body['skin'],0)
        mesh=gltf['meshes'][body['mesh']]
        triangles=sum(gltf['accessors'][p['attributes']['POSITION']]['count']//3 for p in mesh['primitives'])
        self.assertEqual(triangles,metadata['character_triangles'])
        self.assertLess(triangles,35000)
        names={gltf['materials'][p['material']]['name'] for p in mesh['primitives']}
        self.assertTrue({'Tricolour_navy','Tricolour_white','Tricolour_red','Tricolour_blue','Tricolour_hair'}<=names)
        self.assertTrue(all('mesh' not in n for n in gltf['nodes'] if n.get('name','').startswith('Cyclist_Mesh') or n.get('name')=='Hy3dUpperBody'))
