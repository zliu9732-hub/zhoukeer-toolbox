"""No system operations: private archives and an installer with exported mocks."""
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import zipfile
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('prepare_sdweak',ROOT/'scripts/prepare_sdweak.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original=(ROOT/'tests/fixtures/sdweak/install.txt').read_bytes()
with tempfile.TemporaryDirectory() as d:
 base=Path(d);package=base/'package.zip'
 def archive(extra=None):
  with zipfile.ZipFile(package,'w') as z:
   for name in sorted(m.FILES):
    z.writestr('SDWEAK/'+name,original if name=='install.sh' else b'fixture')
   if extra:z.writestr(*extra)
  m.SHA256=hashlib.sha256(package.read_bytes()).hexdigest()
 archive();m.prepare(package,base/'prepared')
 script=(base/'prepared/SDWEAK/install.sh').read_text()
 assert 'TrustAll' not in script and 'pacman-key' not in script
 assert 'sudo reboot' not in script and 'frametime_fix' not in script
 assert 'pacman -U' not in script and '/etc/pacman.d/gnupg' not in script
 assert 'mitigations=off' in script and 'set -eo pipefail' in script
 assert '原作者' in (base/'prepared/SDWEAK/RENKIT-CHANGES.txt').read_text()
 # Exercise real prepared installer with every command that can write/privilege mocked.
 folder=base/'prepared/SDWEAK'
 (folder/'assets/common.sh').write_text('''MODEL=Galileo
steamos_version=3.8
LOG_FILE="$MOCK_ROOT/install.log"
DATE=fixture
SDWEAK_VERSION=fixture
GRUB_CFG=fixture
print_logo() { :; }
log() { echo "$*" >> "$LOG_FILE"; }
green_msg() { echo "$*"; }
yellow_msg() { echo "$*"; }
check_file() { return 0; }
die() { echo "$*"; exit 1; }
print_text() { echo "$1"; }
''')
 (folder/'assets/strings.sh').write_text(':\n')
 runner=base/'run.sh'
 runner.write_text('''#!/bin/bash
sudo() { echo "$*" >> "$MOCK_ROOT/calls"; [ "$MOCK_FAIL" != "$1" ]; }
pacman() { return 1; }
systemctl() { return 1; }
ping() { return 0; }
clear() { :; }
sleep() { :; }
findmnt() { return 1; }
sha256sum() {
 case "$1" in *gamescope*) echo 6303dcacdc3e82e5e9e183c343da85758ca643474406a520651be387898cca21;;
 *) echo 8ff7950a7fca82fe0f9b3c68581ac10ea7c8e74d90e5850b0ca18eb62296b839;; esac
}
export -f sudo pacman systemctl ping clear sleep findmnt sha256sum
cd "$MOCK_ROOT/prepared/SDWEAK"
bash install.sh
''')
 for failure in ('','cp','systemctl','mkinitcpio'):
  (base/'calls').write_text('')
  env={**os.environ,'MOCK_ROOT':str(base),'MOCK_FAIL':failure}
  result=subprocess.run(['bash',str(runner)],env=env,input='n\n',capture_output=True,text=True)
  assert (result.returncode==0)==(failure==''),(failure,result.stdout,result.stderr)
  if failure:assert 'COMPLETE' not in (base/'install.log').read_text()
 for name in ['SDWEAK/../../escape','/tmp/escape','SDWEAK/unexpected.sh']:
  archive((name,b'x'))
  try:m.prepare(package,base/'bad');raise AssertionError('unsafe path accepted')
  except ValueError:pass
 link=zipfile.ZipInfo('SDWEAK/assets/bad');link.external_attr=(stat.S_IFLNK|0o777)<<16
 archive((link,b'/etc/passwd'))
 try:m.prepare(package,base/'bad');raise AssertionError('link accepted')
 except ValueError:pass
 archive();m.SHA256='0'*64
 try:m.prepare(package,base/'bad');raise AssertionError('corrupt package accepted')
 except ValueError:pass
 assert not (base/'bad').exists()
print('PASS: integrity/path/link gates, preserved security checks, no reboot, real prepared installer stops on mocked failures')
