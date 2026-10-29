"""Real app update and verified InputPlumber data copying in temporary roots only.

All OS/network/service commands are guarded. Never execute the Linux binary.
Arguments: Renkit release tar, previously SHA256-verified upstream 0.83.1 tar.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

package, upstream = map(lambda p: Path(p).resolve(), sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='renkit-inputplumber-installed-') as temporary:
    base = Path(temporary)
    source = base / 'release'
    source.mkdir()
    with tarfile.open(package) as tar:
        for member in tar:
            assert not member.issym() and not member.islnk()
            assert not Path(member.name).is_absolute() and '..' not in Path(member.name).parts
        tar.extractall(source, filter='data')
    (source / 'modules/software.sh').write_text('#!/bin/bash\nexit 0\n')
    (source / 'core/platform.sh').write_text('detect_platform() { IS_STEAMOS=1; IS_CHIMERAOS=0; PLATFORM_FAMILY=steamos; }\n')
    binary = base / 'bin'
    binary.mkdir()
    for command in ('sudo', 'curl', 'wget', 'pacman', 'systemctl', 'flatpak', 'udevadm', 'steamos-readonly'):
        p = binary / command
        p.write_text('#!/bin/sh\necho "Forbidden real command" >&2\nexit 97\n')
        p.chmod(0o755)
    (binary / 'uname').write_text('#!/bin/sh\nprintf "Linux\\n"\n')
    (binary / 'uname').chmod(0o755)
    (binary / 'python3').symlink_to(sys.executable)
    home = base / 'home'
    home.mkdir()
    installed = home / 'renkit'
    installed.mkdir()
    (installed / 'apps').mkdir()
    (installed / 'apps/customer-data').write_text('keep')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('ZHOUKEER_', 'RENKIT_', 'BASH_FUNC_', 'XDG_'))}
    env.update(HOME=str(home), PATH=str(binary)+':'+os.environ['PATH'],
               XDG_CONFIG_HOME=str(home / '.config'), XDG_DATA_HOME=str(home / '.local/share'),
               ZHOUKEER_INSTALL_DIR=str(installed), ZHOUKEER_DESKTOP_DIR=str(home / 'Desktop'))
    result = subprocess.run(['bash', str(source / 'install.sh')], env=env, capture_output=True, text=True, timeout=90)
    assert result.returncode == 0, result.stdout + result.stderr
    helper = installed / 'scripts/inputplumber_overlay.py'
    assert helper.read_bytes() == (source / 'scripts/inputplumber_overlay.py').read_bytes()
    assert (installed / 'apps/customer-data').read_text() == 'keep'
    fixture = json.loads((source / 'tests/fixtures/inputplumber-v0.83.1.json').read_text())
    digest = fixture['source']['sha256']
    subprocess.run([sys.executable, str(helper), 'verify', str(upstream), digest], env=env, check=True)
    target = base / 'virtual-steamos'
    (target / 'usr/bin').mkdir(parents=True)
    (target / 'usr/bin/inputplumber').write_bytes(b'old binary')
    config = target / 'etc/inputplumber/devices.d/customer.yaml'
    config.parent.mkdir(parents=True)
    config.write_text('keep custom mapping')
    env['ZHOUKEER_TEST_MODE'] = '1'
    result = subprocess.run([sys.executable, str(helper), 'install', str(upstream), digest,
                             '0.83.1', '--test-root', str(target)], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    for row in fixture['members']:
        if row['type'] == '0':
            name = row['name'].removeprefix('inputplumber/')
            assert hashlib.sha256((target / name).read_bytes()).hexdigest() == row['sha256'], name
    assert config.read_text() == 'keep custom mapping'
    subprocess.run([sys.executable, str(helper), 'restore', result.stdout.strip(), '--test-root', str(target)], env=env, check=True)
    assert (target / 'usr/bin/inputplumber').read_bytes() == b'old binary'
    assert not (target / 'usr/lib/modules-load.d/inputplumber-hrtimer.conf').exists()
    assert config.read_text() == 'keep custom mapping'
print('PASS: release → actual app installer → updated helper → real 0.83.1 package install/restore in a private root')
