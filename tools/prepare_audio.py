"""Prepare compact, seamless Ogg loops from the user-supplied CC0 MP3 files.
Authoring only: requires ffmpeg/ffprobe. No codec tools are needed by the game.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LABELS = {'0097':'Campagne','0100':'Forêt','0659':'Vent dans un arbre',
          '0870':'Ville de campagne 2','0904':'Vent à la cime des arbres',
          '0905':'Lisière de forêt','0908':'Vent dans les herbes hautes',
          '2713':'Forêt et ruisseau 1','2715':'Forêt 3','3616':'Forêt et brame de cerfs sika'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    sources = {}
    for path in sorted(args.source_dir.rglob('*.mp3')):
        match = re.search(r'ID (\d+)', path.name)
        if not match or match[1] not in LABELS:
            continue
        ident = match[1]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if ident in sources and sources[ident][1] != digest:
            raise ValueError(f'Different recordings share ID {ident}')
        sources[ident] = (path, digest)
    if set(sources) != set(LABELS):
        raise ValueError(f'Missing clips: {set(LABELS)-set(sources)}')
    output = ROOT/'assets/audio'
    output.mkdir(exist_ok=True)
    clips = []
    for ident in sorted(sources):
        source, digest = sources[ident]
        info = json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(source)],text=True))
        duration = float(info['format']['duration'])
        end = duration-1.5
        # Rotate the loop seam into a 1.5s crossfade. The final sample leads
        # continuously into the middle section at the start of the next loop.
        graph = (f'[0:a]loudnorm=I=-23:TP=-2:LRA=11,aresample=44100,'
                 f'aformat=sample_fmts=fltp:channel_layouts=stereo,asplit=3[m][t][h];'
                 f'[m]atrim=start=1.5:end={end},asetpts=PTS-STARTPTS[mid];'
                 f'[t]atrim=start={end},asetpts=PTS-STARTPTS[tail];'
                 '[h]atrim=end=1.5,asetpts=PTS-STARTPTS[head];'
                 '[tail][head]acrossfade=d=1.5:c1=tri:c2=tri[seam];'
                 '[mid][seam]concat=n=2:v=0:a=1[out]')
        target = output/f'{ident}.ogg'
        subprocess.run(['ffmpeg','-nostdin','-v','error','-y','-i',str(source),
                        '-filter_complex',graph,'-map','[out]','-c:a','libvorbis','-q:a','3',
                        '-map_metadata','-1',str(target)],check=True)
        clips.append({'id':ident,'name':LABELS[ident],'file':target.name,
                      'original_filename':source.name,'original_sha256':digest,
                      'original_duration_s':duration,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
                      'size_bytes':target.stat().st_size})
        print(ident, target.stat().st_size, flush=True)
    (output/'catalog.json').write_text(json.dumps({'licence':'CC0-1.0','source':'La Sonothèque, files supplied by user',
        'processing':'Vorbis quality 3, stereo 44.1 kHz; loudnorm -23 LUFS, -2 dBTP; rotated 1.5s crossfade seam',
        'clips':clips},ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    main()
