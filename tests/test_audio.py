"""Integrity of the compact, attributed audio payload; no codec tools required."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AudioPayloadTests(unittest.TestCase):
    def test_unique_cc0_recordings_match_the_packaged_manifest(self):
        directory = ROOT/'assets/audio'
        catalog = json.loads((directory/'catalog.json').read_text())
        self.assertEqual(catalog['licence'],'CC0-1.0')
        self.assertEqual({c['id'] for c in catalog['clips']},
                         {'0097','0100','0659','0870','0904','0905','0908','2713','2715','3616'})
        self.assertEqual(len(catalog['clips']),10)
        self.assertEqual(len({c['original_sha256'] for c in catalog['clips']}),10)
        for clip in catalog['clips']:
            with self.subTest(clip=clip['id']):
                data = (directory/clip['file']).read_bytes()
                self.assertEqual(data[:4],b'OggS')
                self.assertEqual(hashlib.sha256(data).hexdigest(),clip['sha256'])
                self.assertEqual(len(data),clip['size_bytes'])
                self.assertIn(clip['id'],(directory/'LICENSE.md').read_text())
