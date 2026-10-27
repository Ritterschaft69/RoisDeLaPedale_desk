"""Native portable exports, using checksum-verified official export templates."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.6.3'
BASE = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'


def templates():
    data_home = Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))
    target = data_home/f'godot/export_templates/{VERSION}.stable'
    needed = ['windows_release_x86_64.exe','linux_release.x86_64','version.txt']
    if all((target/name).exists() for name in needed):
        return
    cache = Path(os.environ.get('XDG_CACHE_HOME',Path.home()/'.cache'))/'godot'
    cache.mkdir(parents=True,exist_ok=True)
    filename = f'Godot_v{VERSION}-stable_export_templates.tpz'
    with urllib.request.urlopen(BASE+'SHA512-SUMS.txt',timeout=60) as response:
        sums = response.read().decode()
    expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1] == filename)
    archive = cache/filename
    if not archive.exists():
        temporary = archive.with_suffix('.tmp')
        with urllib.request.urlopen(BASE+filename,timeout=120) as source,temporary.open('wb') as output:
            shutil.copyfileobj(source,output,1024*1024)
        temporary.replace(archive)
    digest = hashlib.sha512()
    with archive.open('rb') as source:
        while chunk := source.read(1024*1024): digest.update(chunk)
    if digest.hexdigest() != expected:
        raise RuntimeError('Official export template SHA512 mismatch; refusing to use archive')
    target.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for name in needed:
            (target/name).write_bytes(source.read('templates/'+name))
    (target/'linux_release.x86_64').chmod(0o755)
    print('Official template archive SHA512 verified')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--templates',action='store_true',help='Install missing official export templates (~1.26 GB)')
    parser.add_argument('--target',choices=['all','windows','linux'],default='all')
    parser.add_argument('--installer',action='store_true',help='Build Windows installer with NSIS (no signing)')
    args = parser.parse_args()
    if args.templates: templates()
    version = subprocess.check_output(['godot','--version'],text=True).strip()
    if not version.startswith(VERSION+'.'): raise RuntimeError(f'Expected Godot {VERSION}, got {version}')
    subprocess.run([sys.executable,'tools/prepare_route.py','--all'],cwd=ROOT,check=True)
    subprocess.run(['godot','--headless','--editor','--path',str(ROOT),'--import','--quit'],check=True)
    for platform,preset,binary in [('linux','Linux x86_64','RoisDeLaPedale.x86_64'),('windows','Windows x86_64','RoisDeLaPedale.exe')]:
        if args.target not in ('all',platform): continue
        output = ROOT/'build'/platform
        output.mkdir(parents=True,exist_ok=True)
        subprocess.run(['godot','--headless','--path',str(ROOT),'--export-release',preset,str(output/binary)],check=True)
        for source in [ROOT/'LICENSE',ROOT/'docs/THIRD_PARTY.md',ROOT/'assets/fonts/Apache-2.0.txt',
                       ROOT/'docs/licenses/Godot-LICENSE.txt',ROOT/'docs/licenses/Godot-COPYRIGHT.txt']:
            shutil.copy(source,output/source.name)
        shutil.copy(ROOT/'assets/fonts/LICENSE.txt',output/'OpenSans-LICENSE.txt')
        shutil.copy(ROOT/'docs/sources/licence_ouverte.md',output/'IGN-Licence-Ouverte.md')
        shutil.copy(ROOT/'assets/geodata/circuits/LICENSE.md',output/'GEOGRAPHIC-DATA-LICENSE.md')
        (output/'LISEZMOI.txt').write_text('Rois de la Pédale 0.6.0 — prototype démo natif\nLancer '+binary+' depuis ce dossier, sans serveur ni Internet.\nConserver les fichiers du dossier ensemble. F11 : plein écran.\nChoisir un circuit : Saint-Dié, Sortie vélo le matin, Oderen / Grand Ballon.\nFlèches haut/bas : puissance démo. Espace : pause. H : masquer l’interface.\nConduite à droite et évitement automatiques. Faune et passants procéduraux.\nTrois circuits recalés OSM, relief IGN LiDAR HD et bâtiments IGN hors ligne. Toits et arbres interprétés.\nBluetooth et audio non intégrés. Données OSM : ODbL 1.0, attribution dans THIRD_PARTY.md.\nVersion portable non signée. Données IGN : Licence Ouverte, voir notices.\n',encoding='utf-8')
        archive = ROOT/'build'/f'RoisDeLaPedale-0.6.0-{platform}.zip'
        with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(output.iterdir()): bundle.write(path,arcname='RoisDeLaPedale/'+path.name)
        print(archive.name,hashlib.sha256(archive.read_bytes()).hexdigest())
    if args.installer:
        nsis = shutil.which('makensis')
        local = Path('/workspace/.local/nsis')
        env = dict(os.environ)
        if nsis is None and (local/'usr/bin/makensis').exists():
            nsis = str(local/'usr/bin/makensis')
            env['NSISDIR'] = str(local/'usr/share/nsis')
        if nsis is None: raise RuntimeError('NSIS absent. Run python tools/install_nsis.py on the Debian cloud image.')
        subprocess.run([nsis,'-V2',str(ROOT/'packaging/windows.nsi')],env=env,check=True)
        print('Windows installer built; execution on Windows still needs validation.')


if __name__ == '__main__':
    main()
