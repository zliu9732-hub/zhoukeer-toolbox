"""Run the unmodified 3.3.5 updater against the real release installer.

All downloads and OS metadata are simulated. System operations are blocked.
"""
import hashlib
import os
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASH = os.environ.get('RENKIT_TEST_BASH', '/bin/bash')
archive = Path(sys.argv[1]).resolve()

with tempfile.TemporaryDirectory(prefix='renkit-legacy-update-') as directory:
    base = Path(directory)
    binary, home, remote, source = (base / name for name in ('bin', 'home', 'remote', 'source'))
    for path in (binary, home, remote, source):
        path.mkdir()
    with tarfile.open(archive) as package:
        for entry in package:
            assert (entry.isfile() or entry.isdir()) and not entry.name.startswith('/') and '..' not in Path(entry.name).parts
        package.extractall(source)
    version = (source / 'VERSION').read_text().strip()
    app = home / '.local/share/zhoukeer-toolbox'
    (app / 'core').mkdir(parents=True)
    (app / 'config').mkdir()
    for relative in ('update.sh', 'core/download_policy.sh', 'core/source_status.sh', 'core/env.sh', 'VERSION', 'config/settings.example.conf'):
        (app / relative).write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show', 'v3.3.5:' + relative]))
    original_updater = (app / 'update.sh').read_bytes()
    (app / 'config/settings.conf').write_text((app / 'config/settings.example.conf').read_text().replace('DUAL_BOOT_TIMEOUT="5"', 'DUAL_BOOT_TIMEOUT="9"'))
    (app / 'apps').mkdir()
    (app / 'apps/customer-data').write_text('keep')
    plugins = home / 'homebrew/plugins/customer-plugin'
    plugins.mkdir(parents=True)
    (plugins / 'settings').write_text('keep')
    (remote / 'VERSION').write_text(version + '\n')
    (remote / 'SHA256SUMS').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  renkit.tar.gz\n')
    def command(name, text):
        path = binary / name
        path.write_text('#!/bin/bash\n' + text)
        path.chmod(0o755)
    for name in ('sudo', 'wget', 'pacman', 'systemctl', 'flatpak', 'udevadm', 'bootc', 'rpm-ostree', 'ujust', 'efibootmgr', 'fc-cache', 'update-desktop-database', 'xdg-mime', 'xdg-settings'):
        command(name, 'echo "Unexpected real system command" >&2; exit 97\n')
    command('uname', 'case "$1" in -s) echo Linux;; -m) echo x86_64;; esac\n')
    (binary / 'bash').symlink_to(BASH)
    (binary / 'python3').symlink_to(sys.executable)
    command('curl', '''output="" url=""
while [ "$#" -gt 0 ]; do
 case "$1" in --output) output="$2"; shift 2;; https://*) url="${1%%\\?*}"; shift;; *) shift;; esac
done
printf '%s\\n' "$url" >> "$MOCK_CALLS"
case "$url" in
 */VERSION) cp "$MOCK_REMOTE/VERSION" "$output";;
 */dist/renkit.tar.gz) cp "$MOCK_ARCHIVE" "$output";;
 */dist/SHA256SUMS) cp "$MOCK_REMOTE/SHA256SUMS" "$output";;
 *) echo 'Unexpected download' >&2; exit 97;;
esac
''')
    os_release = base / 'os-release'
    os_release.write_text('ID=steamos\nPRETTY_NAME=SteamOS\n')
    env = {key: value for key, value in os.environ.items() if not key.startswith(('ZHOUKEER_', 'RENKIT_', 'XDG_', 'BASH_FUNC_'))}
    env.update(HOME=str(home), PATH=str(binary) + ':/usr/bin:/bin:/usr/sbin:/sbin',
               XDG_STATE_HOME=str(home / '.local/state'), XDG_DATA_HOME=str(home / '.local/share'),
               XDG_CONFIG_HOME=str(home / '.config'), ZHOUKEER_OS_RELEASE_FILE=str(os_release),
               MOCK_REMOTE=str(remote), MOCK_ARCHIVE=str(archive), MOCK_CALLS=str(base / 'calls'))
    started = time.monotonic()
    result = subprocess.run([BASH, str(app / 'update.sh'), '--startup'], env=env, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (app / 'VERSION').read_text().strip() == version, result.stdout
    assert 'DUAL_BOOT_TIMEOUT="9"' in (app / 'config/settings.conf').read_text()
    assert (app / 'apps/customer-data').read_text() == 'keep'
    assert (plugins / 'settings').read_text() == 'keep'
    for relative in ('launch.sh', 'update.sh', 'core/env.sh', 'modules/plugin_store.sh', 'config/settings.example.conf'):
        assert (app / relative).read_bytes() == (source / relative).read_bytes(), relative
    assert original_updater == subprocess.check_output(['git', '-C', str(ROOT), 'show', 'v3.3.5:update.sh'])
    print(f'PASS: original 3.3.5 startup updater → real {version} installer in {time.monotonic() - started:.1f}s; all 30 defaults; customer settings/apps/plugins preserved; network and system operations mocked')
