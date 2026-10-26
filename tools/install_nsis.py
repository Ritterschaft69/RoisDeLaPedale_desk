"""Install NSIS locally on this Debian cloud image, without root/system writes.

APT verifies the signed Debian index and package checksums. No unauthenticated
options. Files are extracted under /workspace and require no service changes.
"""
import os
import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix',type=Path,default=Path('/workspace/.local/nsis'))
    args = parser.parse_args()
    target = args.prefix
    executable = target/'usr/bin/makensis'
    if executable.exists():
        env = dict(os.environ,NSISDIR=str(target/'usr/share/nsis'))
        subprocess.run([str(executable),'-VERSION'],env=env,check=True)
        return
    cache = Path('/workspace/.cache/rdp-apt')
    for path in ['lists/partial','cache/archives/partial','packages']: (cache/path).mkdir(parents=True,exist_ok=True)
    sources = cache/'sources.list'
    keyring = Path('/usr/share/keyrings/debian-archive-keyring.gpg')
    if not keyring.exists(): raise RuntimeError('Debian trusted archive keyring required; verification must not be bypassed')
    sources.write_text(f'deb [signed-by={keyring}] https://deb.debian.org/debian trixie main\n')
    config = cache/'apt.conf'
    config.write_text(f'''Dir::Etc::parts "-";
Dir::Etc::sourcelist "{sources}";
Dir::Etc::sourceparts "-";
Dir::State::lists "{cache}/lists";
Dir::Cache "{cache}/cache";
APT::Sandbox::User "{os.getlogin() if os.isatty(0) else 'agent'}";
''')
    env = dict(os.environ,APT_CONFIG=str(config))
    subprocess.run(['apt-get','update'],env=env,check=True)
    subprocess.run(['apt-get','download','nsis=3.11-1','nsis-common=3.11-1'],cwd=cache/'packages',env=env,check=True)
    target.mkdir(parents=True,exist_ok=True)
    for package in (cache/'packages').glob('nsis*.deb'):
        subprocess.run(['dpkg-deb','--extract',str(package),str(target)],check=True)
    subprocess.run([str(executable),'-VERSION'],env=dict(os.environ,NSISDIR=str(target/'usr/share/nsis')),check=True)


if __name__ == '__main__': main()
