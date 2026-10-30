"""Reject GPS/network artifacts without deleting measured turns or sources."""
import copy,math,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from circuit_geography import Track,clean_alignment,clean_observations


def route(coords):
    points=[];s=0.
    for i,(x,z) in enumerate(coords):
        if i:s+=math.dist(coords[i-1],(x,z))
        points.append(dict(x=x,z=z,s=s,alt=300.,lat=48.,lon=7.))
    return dict(points=points,length_m=s)


class RouteCleanupTests(unittest.TestCase):
    def test_gps_spike_is_removed_without_changing_original_or_station(self):
        raw=route([(0,0),(10,0),(20,0),(30,0),(43,1),(31,0),(50,0),(60,0),(70,0)])
        before=copy.deepcopy(raw);kept,rejected=clean_observations(raw['points'])
        self.assertTrue(rejected)
        self.assertEqual(raw,before)
        self.assertEqual(kept[0],raw['points'][0]);self.assertEqual(kept[-1],raw['points'][-1])
        self.assertTrue(all(a['s']<b['s'] for a,b in zip(kept,kept[1:])))

    def test_measured_out_and_back_and_hairpin_survive(self):
        for coords in [[(0,0),(10,0),(20,0),(30,0),(40,0),(30,0),(20,0),(10,0),(0,0)],
                       [(0,0),(10,0),(20,0),(30,0),(35,2),(30,5),(20,5),(10,5),(0,5)]]:
            raw=route(coords);kept,rejected=clean_observations(raw['points'])
            self.assertEqual(kept,raw['points']);self.assertFalse(rejected)

    def test_short_network_reversal_requires_gpx_evidence(self):
        track=Track(route([(0,0),(10,0),(20,0),(30,0),(40,0)]))
        path=[dict(x=x,z=0,source_s=s,osm_way=10) for x,s in [(0,0),(10,10),(16,12),(10,14),(20,20),(40,40)]]
        clean,rejected=clean_alignment(path,track)
        self.assertTrue(rejected)
        self.assertEqual([p['x'] for p in clean],[0,10,20,40])
        turn=Track(route([(0,0),(10,0),(20,0),(30,0),(40,0),(30,0),(20,0),(10,0),(0,0)]))
        path=[dict(x=p['x'],z=p['z'],source_s=p['s'],osm_way=10) for p in turn.points]
        self.assertFalse(clean_alignment(path,turn)[1])
