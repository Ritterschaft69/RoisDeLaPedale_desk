"""Freeze the BLE bridge on its native OS; no Python required on Windows PCs."""
import importlib.metadata as md
import os,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
platform='windows' if sys.platform=='win32' else 'linux'
output=ROOT/'build/bluetooth'/platform;output.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,'-m','PyInstaller','--noconfirm','--clean','--onefile','--name','RoisBluetooth',
    '--distpath',str(output),'--workpath',str(ROOT/'build/bluetooth/work'/platform),
    '--specpath',str(ROOT/'build/bluetooth'),'--paths',str(ROOT/'bluetooth'),
    '--collect-submodules','bleak',*(['--collect-submodules','winrt'] if platform=='windows' else []),
    str(ROOT/'bluetooth/bridge.py')],cwd=ROOT,check=True)
executable=output/('RoisBluetooth.exe' if platform=='windows' else 'RoisBluetooth')
result=subprocess.run([str(executable),'--self-test'],capture_output=True,text=True,timeout=60)
if result.returncode or 'BLUETOOTH_SELF_TEST_OK' not in result.stdout:raise RuntimeError(result.stdout+result.stderr)
licenses=['Rois de la Pédale — module Bluetooth\nPython '+sys.version+'\n']
for candidate in [Path(sys.base_prefix)/'LICENSE.txt',Path(sys.base_prefix)/('lib/python'+str(sys.version_info.major)+'.'+str(sys.version_info.minor))/'LICENSE.txt']:
    if candidate.exists():licenses.append(candidate.read_text(encoding='utf-8',errors='replace'));break
for dist in sorted(md.distributions(),key=lambda d:d.metadata['Name'].lower()):
    name=dist.metadata['Name']
    if name.lower().startswith(('bleak','winrt','dbus-fast','pyinstaller','altgraph','packaging')):
        licenses.append('\n'+name+' '+dist.version+'\n'+str(dist.metadata.get('License','')))
        for f in dist.files or []:
            if any(word in f.name.lower() for word in ('license','copying')):
                p=dist.locate_file(f)
                if p.is_file() and p.stat().st_size<250000:licenses.append(p.read_text(encoding='utf-8',errors='replace'))
(output/'Bluetooth-LICENSES.txt').write_text('\n'.join(licenses),encoding='utf-8')
print(result.stdout.strip(),executable)
