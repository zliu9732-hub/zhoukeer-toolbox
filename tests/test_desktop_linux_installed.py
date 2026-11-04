"""Real release install in private HOME, mocked Linux metadata and guarded system tools."""
import os,subprocess,sys,tarfile,tempfile
from pathlib import Path
archive=Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='renkit-desktop-install-')as directory:
 base=Path(directory);source=base/'release';source.mkdir()
 with tarfile.open(archive)as tar:
  for entry in tar.getmembers():assert not entry.issym()and not entry.islnk()and not Path(entry.name).is_absolute()and'..'not in Path(entry.name).parts
  tar.extractall(source,filter='data')
 # The app installer is real; software/shortcut repair is outside this test.
 (source/'modules/software.sh').write_text('#!/bin/bash\nexit 0\n')
 binary=base/'bin';binary.mkdir()
 for command in ['sudo','curl','wget','pacman','systemctl','flatpak','udevadm','bootc','rpm-ostree','ujust','efibootmgr']:
  p=binary/command;p.write_text('#!/bin/sh\necho "Forbidden real command" >&2\nexit 97\n');p.chmod(0o755)
 p=binary/'uname';p.write_text('#!/bin/sh\ncase "$1" in -s) echo Linux;; -m) echo x86_64;; esac\n');p.chmod(0o755)
 for identity,title,family in [('anatase','Anatase','anatase'),('fedora','Linux','unknown')]:
  home=base/identity;home.mkdir();installed=home/'renkit';desktop=home/'Desktop';osr=home/'os-release';osr.write_text(f'ID={identity}\nPRETTY_NAME="Desktop test"\n')
  env={k:v for k,v in os.environ.items()if not k.startswith(('ZHOUKEER_','RENKIT_','BASH_FUNC_','XDG_'))}
  env.update(HOME=str(home),PATH=str(binary)+':'+os.environ['PATH'],XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),ZHOUKEER_INSTALL_DIR=str(installed),ZHOUKEER_DESKTOP_DIR=str(desktop),ZHOUKEER_OS_RELEASE_FILE=str(osr))
  r=subprocess.run(['bash',str(source/'install.sh')],env=env,capture_output=True,text=True,timeout=90);assert r.returncode==0,r.stdout+r.stderr
  assert(installed/'.renkit-platform').read_text().strip()==family
  assert f'Name=Renkit {title}版' in(desktop/'Renkit.desktop').read_text()
  for relative in ['core/platform.sh','core/ui.sh','main-bazzite.sh','modules/plugin_store.sh','modules/bazzite_decky.sh','modules/clover_boot.sh','modules/themehub_updates.sh','modules/framegen_updates.sh','modules/lsfg_install.sh','modules/ayaneo3.sh','modules/screen_colors.sh','modules/gfg_extreme.sh']:
   assert(installed/relative).read_bytes()==(source/relative).read_bytes(),relative
  assert 'RENKIT_COMPACT_MENUS=1' in(installed/'main-bazzite.sh').read_text()
  probe=home/'probe.sh';probe.write_text('source "'+str(installed/'core/platform.sh')+'"\ndetect_platform\nrequire_supported_gaming_os || exit 1\nprintf "%s:%s:%s:%s\\n" "$PLATFORM_FAMILY" "$IS_DESKTOP_LINUX" "$IS_BAZZITE" "$IS_STEAMOS"\n')
  r=subprocess.run(['bash',str(probe)],env=env,capture_output=True,text=True,timeout=10);assert r.returncode==0 and r.stdout.strip()==family+':1:0:0',r.stdout+r.stderr
print('PASS: actual update installer → Anatase/Linux desktop entries, true system metadata and installed common platform helper; no system modifications')
