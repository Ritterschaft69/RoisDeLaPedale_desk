"""Run each circuit in the actual Linux portable export, isolated and offline."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',type=Path,default=ROOT/'build/linux/RoisDeLaPedale.x86_64')
    args=parser.parse_args()
    binary=args.binary.resolve()
    for entry in json.loads((ROOT/'assets/routes/catalog.json').read_text()):
        circuit=entry['id']
        with tempfile.TemporaryDirectory(prefix='rdp-export-',dir=ROOT/'build') as temporary:
            folder=Path(temporary)
            env=dict(os.environ,XDG_DATA_HOME=str(folder/'data'),XDG_CONFIG_HOME=str(folder/'config'),XDG_CACHE_HOME=str(folder/'cache'))
            result=subprocess.run([str(binary),'--headless','--fixed-fps','60','--','--smoke','--smoke-circuit='+circuit],
                cwd=binary.parent,env=env,capture_output=True,text=True,timeout=60)
            if result.returncode:raise RuntimeError(result.stdout[-3000:]+result.stderr[-3000:])
            activities=list((folder/'data').rglob('activities/*.json'))
            if not activities:raise RuntimeError('No activity saved by exported executable: '+circuit)
            activity=json.loads(activities[-1].read_text())
            if activity['route']!=circuit or 'IGN69' not in activity['altitude_source']:
                raise RuntimeError('Wrong circuit or altitude source in exported activity')
            if not activity['samples'] or 'source_gpx' not in activity['samples'][0]:
                raise RuntimeError('Export did not preserve source GPX audit values')
            print('EXPORT_SMOKE_OK',circuit,'metres',round(activity['distance_m'],3),'samples',len(activity['samples']),flush=True)


if __name__=='__main__':main()
