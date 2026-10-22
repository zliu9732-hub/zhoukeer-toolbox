"""No system operations: private archives and an installer with exported mocks."""
import hashlib
import importlib.util
import os
import pty
import re
import select
from pathlib import Path
import stat
import subprocess
import tempfile
import time
import zipfile
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('prepare_sdweak',ROOT/'scripts/prepare_sdweak.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original=(ROOT/'tests/fixtures/sdweak/install.txt').read_bytes()
core=ROOT/'assets/sdweak/SDWEAK-core-v2.1.0.zip'
with zipfile.ZipFile(core) as z:
 real_runtime=z.read('SDWEAK/assets/SDWEAK.sh')
 real_unit=z.read('SDWEAK/assets/sdweak.service')
with tempfile.TemporaryDirectory() as d:
 base=Path(d);package=base/'package.zip'
 m.prepare(core,base/'bundled',home=base/'customer with %name')
 bundled=base/'bundled/SDWEAK'
 assert not any(bundled.rglob('*.pkg.tar.zst'))
 assert len(list(p for p in bundled.rglob('*') if p.is_file()))==15
 unit=(bundled/'assets/sdweak.service').read_text()
 assert '/home/deck/' not in unit and 'customer with %%name' in unit
 assert f'ExecStart=/usr/bin/bash "{base}/customer with %%name/.local/tweak/SDWEAK.sh"' in unit
 assert f'ConditionPathExists={base}/customer with %%name/.local/tweak/SDWEAK.sh\n' in unit
 assert 'gamescope-3.16' not in (bundled/'install.sh').read_text()
 damaged=base/'damaged-core.zip';damaged.write_bytes(core.read_bytes()+b'corruption')
 try:m.prepare(damaged,base/'rejected-core');raise AssertionError('damaged bundled package accepted')
 except ValueError:pass
 assert not (base/'rejected-core').exists()
 def archive(extra=None):
  with zipfile.ZipFile(package,'w') as z:
   for name in sorted(m.FILES):
    payload={'install.sh':original,'assets/SDWEAK.sh':real_runtime,'assets/sdweak.service':real_unit}.get(name,b'fixture')
    z.writestr('SDWEAK/'+name,payload)
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
 # Execute a copy with ALL /proc and /sys paths redirected to private fixtures.
 # No kernel writes, privilege, service or network commands are possible here.
 mock_root=base/'kernel';mock_root.mkdir()
 def fixture_runtime(data):
  text=re.sub(r'/(proc|sys)/',lambda match:str(mock_root)+match.group(0),data.decode())
  return text.replace('#!/bin/bash\n', '''#!/bin/bash
id() { echo 0; }
sync() { :; }
printf() {
 if [ "${MOCK_WRITE_FAIL:-}" = bfq ] && [ "${2:-}" = bfq ]; then return 1; fi
 builtin printf "$@"
}
''',1)
 node=mock_root/'proc/sys/vm/swappiness';node.parent.mkdir(parents=True);node.write_text('60')
 card=mock_root/'sys/block/mmcblk0/queue';card.mkdir(parents=True);(card/'scheduler').write_text('mq-deadline')
 for label,data in [('old',real_runtime),('new',(bundled/'assets/SDWEAK.sh').read_bytes())]:
  runtime_file=base/(label+'-runtime.sh');runtime_file.write_text(fixture_runtime(data))
  result=subprocess.run(['bash',str(runtime_file)],env={**os.environ,'LC_ALL':'C'},capture_output=True,text=True)
  assert result.returncode==(1 if label=='old' else 0),(label,result.stdout,result.stderr)
  assert 'FAIL=0' in result.stdout and 'SKIP=' in result.stdout
 # A real write failure must fail even when the final optional write succeeds.
 (card/'iosched').mkdir();(card/'iosched/back_seek_penalty').write_text('0')
 for label in ['old','new']:
  result=subprocess.run(['bash',str(base/(label+'-runtime.sh'))],env={**os.environ,'LC_ALL':'C','MOCK_WRITE_FAIL':'bfq'},capture_output=True,text=True)
  assert result.returncode==(0 if label=='old' else 1),(label,result.returncode,result.stdout.splitlines()[-8:],result.stderr[-300:])
  assert 'FAIL=1' in result.stdout
 # Exercise real prepared installer with every command that can write/privilege mocked.
 folder=base/'prepared/SDWEAK'
 (folder/'assets/common.sh').write_text('''MODEL="${MOCK_MODEL:-Galileo}"
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
   assert 'power_efficiency_prompt [y/N]' in result.stdout
   assert '正在更新启动所需文件' in result.stdout and '正在更新开机设置' in result.stdout
 # Real terminal input/output, but stderr is separately buffered by the
 # launcher. Questions must be visible on stdout BEFORE an answer is sent.
 for model in ('Galileo','Jupiter'):
  (base/'calls').write_text('');(base/'auth-cache').write_text('0')
  (base/'display.lua').write_text('stock')
  with (folder/'assets/common.sh').open('a') as f:
   f.write(f'\nLCD_LUA_PATH="{base}/display.lua"\n')
  master,slave=pty.openpty()
  proc=subprocess.Popen(['bash',str(runner)],env={**env,'MOCK_FAIL':'','MOCK_MODEL':model},
      stdin=slave,stdout=slave,stderr=subprocess.PIPE)
  os.close(slave);seen=b''
  try:
   questions=['display_overclock_prompt','power_efficiency_prompt'] if model=='Jupiter' else ['power_efficiency_prompt']
   for question in questions:
    deadline=time.monotonic()+10
    while question.encode() not in seen and time.monotonic()<deadline:
     ready,_,_=select.select([master],[],[],0.1)
     if ready:
      try:seen+=os.read(master,65536)
      except OSError:break
    assert question.encode() in seen,(model,question,seen[-1000:])
    os.write(master,b'\n')
   deadline=time.monotonic()+10
   while proc.poll() is None and time.monotonic()<deadline:
    ready,_,_=select.select([master],[],[],0.1)
    if ready:
     try:seen+=os.read(master,65536)
     except OSError:break
   proc.wait(timeout=2)
   assert proc.returncode==0,(model,seen[-1500:],proc.stderr.read())
   assert 'COMPLETE' in (base/'install.log').read_text()
  finally:
   if proc.poll() is None:proc.kill();proc.wait()
   proc.stderr.close();os.close(master)
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
print('PASS: verified offline payload, real TF-card exit-status regression, actual write failure, service user path, authentication/runner, visible LCD/OLED terminal questions and failure cleanup')
