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
