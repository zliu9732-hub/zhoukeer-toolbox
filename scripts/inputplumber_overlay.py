"""Install only verified InputPlumber files, retaining a reversible root-owned backup."""
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import signal
import sys
import tarfile
import tempfile
import uuid

SHA256 = 'bb167707964777751ad15f2da0ac99eb16a926a3997098e884f749b2e06f777b'
EXACT = {
    'usr/bin/inputplumber',
    'usr/lib/systemd/system/inputplumber.service',
    'usr/lib/systemd/system/inputplumber-suspend.service',
    'usr/lib/udev/hwdb.d/59-inputplumber.hwdb',
    'usr/lib/udev/hwdb.d/60-inputplumber-autostart.hwdb',
    'usr/lib/udev/rules.d/99-inputplumber-device-setup.rules',
    'usr/lib/udev/rules.d/50-8bitdo-u2-controller.rules',
    'usr/lib/udev/rules.d/90-inputplumber-autostart.rules',
    'usr/lib/udev/rules.d/60-inputplumber-uaccess.rules',
    'usr/share/dbus-1/system.d/org.shadowblip.InputPlumber.conf',
    'usr/share/polkit-1/rules.d/org.shadowblip.InputPlumber.rules',
    'usr/share/polkit-1/actions/org.shadowblip.InputPlumber.policy',
}


def allowed(name):
    path = PurePosixPath(name)
    return (not path.is_absolute() and str(path) == name and '..' not in path.parts
            and (name in EXACT or
                 (name.startswith('usr/share/inputplumber/')
                  and path.suffix in ('.yaml', '.json'))))


def verified_files(archive):
    data = Path(archive).read_bytes()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError('官方文件校验未通过')
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
        for member in tar:
            raw = member.name.removeprefix('inputplumber/')
            if member.isdir():
                if member.name == 'inputplumber' or (
                        str(PurePosixPath(raw)) == raw and '..' not in PurePosixPath(raw).parts
                        and not raw.startswith('/') and raw.startswith('usr')):
                    continue
                raise ValueError('压缩包目录不安全')
            if not member.isfile() or not allowed(raw) or raw in result:
                raise ValueError('压缩包含有意外文件或链接')
            if member.size > 268435456:
                raise ValueError('压缩包文件过大')
            result[raw] = tar.extractfile(member).read()
    if not EXACT.issubset(result):
        raise ValueError('官方文件不完整')
    binary = result['usr/bin/inputplumber']
    if binary[:6] != b'\x7fELF\x02\x01' or binary[18:20] != b'\x3e\x00':
        raise ValueError('程序不适用于这台机器')
    return result


def safe_target(root, name):
    if not allowed(name):
        raise ValueError('安装路径不受支持')
    target = root / name
    for path in [target, *target.parents]:
        if path == root.parent:
            break
        if path.is_symlink():
            raise ValueError(f'目标路径是链接：{name}')
    if target.exists() and not target.is_file():
        raise ValueError(f'目标不是普通文件：{name}')
    return target


def replace(target, data, mode):
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.renkit-inputplumber-', dir=target.parent)
    try:
        with os.fdopen(fd, 'wb') as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def backup_base(root):
    return root / 'var/lib/renkit/inputplumber-backups'


def restore(root, backup):
    if backup.is_symlink() or backup.parent != backup_base(root) or not backup.name.startswith('v0.81.0-'):
        raise ValueError('备份路径不安全')
    entries = json.loads((backup / 'manifest.json').read_text())
    for entry in entries:
        target = safe_target(root, entry['name'])
        if entry['exists']:
            file = backup / 'files' / entry['name']
            if file.is_symlink() or not file.is_file():
                raise ValueError('备份文件不安全')
            replace(target, file.read_bytes(), entry['mode'])
            os.chown(target, entry['uid'], entry['gid'])
        else:
            target.unlink(missing_ok=True)


def install(root, archive):
    files = verified_files(archive)
    targets = {name: safe_target(root, name) for name in files}
    base = backup_base(root)
    # Ancestors of the backup directory must not redirect writes outside its scope.
    for path in [base, *base.parents]:
        if path == root.parent:
            break
        if path.is_symlink():
            raise ValueError('备份目录是链接')
    backup = base / ('v0.81.0-' + uuid.uuid4().hex)
    backup.mkdir(parents=True, mode=0o700)
    os.chmod(backup, 0o700)
    entries = []
    for name, target in targets.items():
        entry = {'name': name, 'exists': target.exists()}
        if entry['exists']:
            info = target.stat()
            entry.update(mode=info.st_mode & 0o777, uid=info.st_uid, gid=info.st_gid)
            saved = backup / 'files' / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target, saved)
        entries.append(entry)
    (backup / 'manifest.json').write_text(json.dumps(entries))
    try:
        for name, target in targets.items():
            replace(target, files[name], 0o755 if name == 'usr/bin/inputplumber' else 0o644)
    except BaseException:
        restore(root, backup)
        raise
    return backup


def main():
    action, argument = sys.argv[1:3]
    root = Path('/')
    if len(sys.argv) > 3:
        if os.environ.get('ZHOUKEER_TEST_MODE') != '1':
            raise ValueError('测试路径未授权')
        root = Path(sys.argv[3]).resolve()
        if root == Path('/'):
            raise ValueError('测试不得使用真实系统目录')
    elif action != 'verify' and os.geteuid() != 0:
        raise ValueError('需要管理员权限')
    if action == 'verify':
        verified_files(argument)
    elif action == 'install':
        def interrupted(signum, frame):
            raise InterruptedError('更新中断，正在恢复旧文件')
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(signum, interrupted)
        print(install(root, argument))
    elif action == 'restore':
        restore(root, Path(argument))
    else:
        raise ValueError('不支持的操作')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, tarfile.TarError, IndexError) as error:
        print(f'InputPlumber 文件处理失败：{error}', file=sys.stderr)
        sys.exit(1)
