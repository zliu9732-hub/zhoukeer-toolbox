"""No system operations: private archives and an installer with exported mocks."""
import hashlib
import importlib.util
import os
import re
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
 assert 'mitigations=off' in script and 'set -Eeo pipefail' in script
 assert not re.search(r'\bsudo\s', script) and 'toolbox_sudo ' in script
 assert 'ping -c1' not in script and 'restart systemd-zram-setup@zram0' not in script
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
 # Use the actual Renkit runner and authentication helper. The tiny module
 # fixture only simulates its already separately tested device/consent gate.
 (base/'repo/scripts').mkdir(parents=True)
 (base/'repo/modules').mkdir()
 (base/'repo/scripts/run_sdweak.sh').write_bytes((ROOT/'scripts/run_sdweak.sh').read_bytes())
 (base/'repo/modules/sdweak.sh').write_text(
  f'source "{ROOT}/core/auth.sh"\n'
  'set -u\nsdweak_check() { [ "$MOCK_GATE" = open ]; }\n')
 runner=base/'run.sh'
 runner.write_text('''#!/bin/bash
sudo() {
 case "$*" in
  '-k') echo 0 > "$MOCK_ROOT/auth-cache"; return 0 ;;
  '-n true') [ "$(cat "$MOCK_ROOT/auth-cache")" = 1 ]; return ;;
  '-S -p  -v')
    IFS= read -r value
    [ "$value" = fixture-password ] || return 1
    echo 1 > "$MOCK_ROOT/auth-cache"
    echo authenticated >> "$MOCK_ROOT/calls"
    return 0 ;;
 esac
 [ "$1:$2" = '-n:--' ] || return 99
 [ "$(cat "$MOCK_ROOT/auth-cache")" = 1 ] || return 98
 shift 2
 echo "$*" >> "$MOCK_ROOT/calls"
 [ "$MOCK_FAIL" != "$1" ]
}
pacman() { return 1; }
systemctl() { return 1; }
ping() { echo unexpected-ping >> "$MOCK_ROOT/calls"; return 1; }
clear() { :; }
sleep() { :; }
findmnt() { [ -n "$MOCK_MOUNT" ] || return 1; echo "$MOCK_MOUNT"; }
sha256sum() {
 case "$1" in *gamescope*) echo 6303dcacdc3e82e5e9e183c343da85758ca643474406a520651be387898cca21;;
 *) echo 8ff7950a7fca82fe0f9b3c68581ac10ea7c8e74d90e5850b0ca18eb62296b839;; esac
}
export -f sudo pacman systemctl ping clear sleep findmnt sha256sum
bash "$MOCK_ROOT/repo/scripts/run_sdweak.sh" "$MOCK_ROOT/prepared/SDWEAK"
''')
 # A synthetic password tests that invalidating sudo's cached authentication
 # after each command does not break the next one. Nothing uses real credentials.
 record=base/'password.txt'
 record.write_text('密码：fixture-password\n');record.chmod(0o600)
 for failure in ('','cp','systemctl','mkinitcpio'):
  (base/'calls').write_text('')
  (base/'install.log').write_text('')
  (base/'auth-cache').write_text('0')
  env={**os.environ,'MOCK_ROOT':str(base),'MOCK_FAIL':failure,
       'MOCK_MOUNT':'relatime','MOCK_GATE':'open','ZHOUKEER_AUTO_CONFIRM':'1',
       'ZHOUKEER_PASSWORD_RECORD':str(record)}
  result=subprocess.run(['bash',str(runner)],env=env,input='n\n',capture_output=True,text=True)
  assert (result.returncode==0)==(failure==''),(failure,result.stdout,result.stderr)
  calls=(base/'calls').read_text();log=(base/'install.log').read_text()
  assert 'unexpected-ping' not in calls and 'systemd-zram-setup@zram0' not in calls
  assert 'fixture-password' not in calls+log+result.stdout+result.stderr
  assert 'authenticated' in calls and (base/'auth-cache').read_text().strip()=='0'
  if failure:
   assert 'COMPLETE' not in log
   assert 'ERROR: step=' in log and '失败。详细记录' in result.stderr
  else:
   assert 'home.mount.d' in calls and 'options: noatime' in log
   assert 'activation deferred until manual reboot' in log and 'COMPLETE' in log
 for field,value in [('MOCK_GATE','closed'),('ZHOUKEER_AUTO_CONFIRM','0')]:
  (base/'calls').write_text('')
  (base/'install.log').write_text('not-started')
  rejected=subprocess.run(['bash',str(runner)],env={**env,field:value},capture_output=True,text=True)
  assert rejected.returncode and not (base/'calls').read_text()
  assert (base/'install.log').read_text()=='not-started'
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
print('PASS: archive gates, real authentication/runner, blocked ping, empty mount options, reboot-deferred memory setup and failure diagnostics')
