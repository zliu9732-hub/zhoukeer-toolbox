"""Run the legacy entry point in a fake project with denied OS/network commands."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='deckygcm-standalone-') as temporary:
    base = Path(temporary)
    for name in ('scripts', 'core', 'modules', 'bin', 'plugins', 'home'):
        (base / name).mkdir()
    shutil.copy2(ROOT / 'scripts/install-decky-plugin.sh', base / 'scripts/install-decky-plugin.sh')
    (base / 'core/env.sh').write_text('load_config() { :; }\n')
    (base / 'modules/plugin_store.sh').write_text('''
install_configured_plugin() {
    [ "$1" = cheatdeck ] || return 98
    printf 'paired-installer\\n'
    toolbox_sudo printf authorized
}
''')
    for name in ('curl', 'unzip', 'find', 'sha256sum', 'systemctl', 'pacman'):
        path = base / 'bin' / name
        path.write_text('#!/bin/sh\necho "Forbidden OS/network command" >&2\nexit 97\n')
        path.chmod(0o755)
    sudo = base / 'bin/sudo'
    sudo.write_text('''#!/bin/sh
case "$*" in
    '-n true') exit 0 ;;
    '-n -- printf authorized') printf 'stored-authorization-retained\\n'; exit 0 ;;
    *) echo 'Forbidden authorization operation' >&2; exit 97 ;;
esac
''')
    sudo.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('BASH_FUNC_', 'ZHOUKEER_', 'DECKY_'))}
    env.update(HOME=str(base / 'home'), DECKY_PLUGIN_DIR=str(base / 'plugins'), PATH=str(base / 'bin') + ':' + os.environ['PATH'])
    result = subprocess.run(['bash', str(base / 'scripts/install-decky-plugin.sh'), 'cheatdeck'], env=env,
                            capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout == 'paired-installer\nstored-authorization-retained\n', result.stdout
    assert not any((base / 'plugins').iterdir())
print('PASS: actual standalone entry uses paired installer and retains stored-password sudo adapter; no real network, sudo, service or installation')
