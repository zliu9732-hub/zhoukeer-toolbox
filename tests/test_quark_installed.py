"""Verify release -> real app installer -> portable client, using guarded temporary roots."""
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

package, client = (Path(p).resolve() for p in sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='renkit-quark-installed-') as temporary:
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
    (installed / 'apps').mkdir(parents=True)
    (installed / 'apps/customer-data').write_text('keep')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('ZHOUKEER_', 'RENKIT_', 'BASH_FUNC_', 'XDG_', 'QUARK_TEST_'))}
    env.update(HOME=str(home), PATH=str(binary)+':'+os.environ['PATH'],
               XDG_CONFIG_HOME=str(home / '.config'), XDG_DATA_HOME=str(home / '.local/share'),
               ZHOUKEER_INSTALL_DIR=str(installed), ZHOUKEER_DESKTOP_DIR=str(home / 'Desktop'))
    result = subprocess.run(['bash', str(source / 'install.sh')], env=env, capture_output=True, text=True, timeout=90)
    assert result.returncode == 0, result.stdout + result.stderr
    for name in ['modules/quark.sh', 'modules/game_launchers.sh', 'scripts/quark_portable.py', 'data/quark_portable_files.json']:
        assert (installed / name).read_bytes() == (source / name).read_bytes(), name
    assert (installed / 'apps/customer-data').read_text() == 'keep'
    env['QUARK_TEST_APP_ROOT'] = str(installed)
    subprocess.run(['bash', str(source / 'tests/test_quark.sh'), str(client)], env=env, check=True, timeout=150)
print('PASS: release -> actual app installer -> portable extraction and fake launch; no real Windows execution')
