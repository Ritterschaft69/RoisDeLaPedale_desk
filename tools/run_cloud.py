"""Start the native app on an existing display or an isolated software X display.

No HTTP server and no web preview. Requires the already installed Xorg dummy
driver on this cloud image. Stop only the display process started here.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    env = dict(os.environ)
    for name,suffix in [('XDG_CONFIG_HOME','.config'),('XDG_CACHE_HOME','.cache'),('XDG_DATA_HOME','.local/share')]:
        env.setdefault(name,str(Path('/workspace')/suffix))
        Path(env[name]).mkdir(parents=True,exist_ok=True)
    server = None
    try:
        if not env.get('DISPLAY'):
            if not shutil.which('Xorg'): raise RuntimeError('No display; Xorg unavailable. Use godot --headless for tests.')
            number = next(i for i in range(90,110) if not Path(f'/tmp/.X{i}-lock').exists())
            env['DISPLAY'] = f':{number}'
            config = Path(env['XDG_CONFIG_HOME'])/'rdp-xorg.conf'
            config.write_text('''Section "ServerFlags"
 Option "AutoAddDevices" "false"
 Option "DontVTSwitch" "true"
EndSection
Section "Device"
 Identifier "dummy"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "monitor"
 HorizSync 28.0-80.0
 VertRefresh 48.0-75.0
 Modeline "1440x900" 106.5 1440 1520 1672 1904 900 903 909 934 -HSync +Vsync
EndSection
Section "Screen"
 Identifier "screen"
 Device "dummy"
 Monitor "monitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1440x900"
 EndSubSection
EndSection
''')
            server = subprocess.Popen(['Xorg',env['DISPLAY'],'-noreset','-nolisten','tcp','-config',str(config),
                '-logfile',str(Path(env['XDG_CACHE_HOME'])/'rdp-xorg.log')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            for _ in range(100):
                if server.poll() is not None: raise RuntimeError('Xorg failed; see rdp-xorg.log')
                if Path(f'/tmp/.X11-unix/X{number}').exists(): break
                time.sleep(0.05)
            else: raise RuntimeError('Display did not become ready')
        return subprocess.call(['godot','--audio-driver','Dummy','--path',str(ROOT),*sys.argv[1:]],env=env)
    finally:
        if server is not None:
            server.terminate()
            try: server.wait(timeout=5)
            except subprocess.TimeoutExpired: server.kill(); server.wait()


if __name__ == '__main__': raise SystemExit(main())
