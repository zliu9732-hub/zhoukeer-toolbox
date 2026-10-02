import hashlib
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('overlay', ROOT / 'scripts/inputplumber_overlay.py')
overlay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(overlay)


def archive(path, extra=None):
    with tarfile.open(path, 'w:gz') as tar:
        for name in sorted(overlay.EXACT):
            data = b'new config'
            if name == 'usr/bin/inputplumber':
                data = b'\x7fELF\x02\x01' + b'\x00' * 12 + b'\x3e\x00' + b'fixture'
            member = tarfile.TarInfo('inputplumber/' + name)
            member.size = len(data)
            tar.addfile(member, io.BytesIO(data))
        if extra:
            tar.addfile(extra, io.BytesIO(b'x') if extra.isfile() else None)
    overlay.SHA256 = hashlib.sha256(path.read_bytes()).hexdigest()


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    root = base / 'root'
    root.mkdir()
    binary = root / 'usr/bin/inputplumber'
    binary.parent.mkdir(parents=True)
    binary.write_bytes(b'old version')
    binary.chmod(0o751)
    custom = root / 'etc/inputplumber/devices.d/custom.yaml'
    custom.parent.mkdir(parents=True)
    custom.write_text('keep custom')
    package = base / 'package.tar.gz'
    archive(package)
    backup = overlay.install(root, package)
    assert binary.read_bytes().startswith(b'\x7fELF') and binary.stat().st_mode & 0o777 == 0o755
    assert custom.read_text() == 'keep custom'
    overlay.restore(root, backup)
    assert binary.read_bytes() == b'old version' and binary.stat().st_mode & 0o777 == 0o751
    assert not (root / 'usr/lib/systemd/system/inputplumber.service').exists()
    # File-copy failure after the first write must restore every original file.
    original = overlay.replace
    calls = 0
    def broken(target, data, mode):
        global calls
        calls += 1
        if calls == 2:
            raise OSError('simulated disk write failure')
        return original(target, data, mode)
    overlay.replace = broken
    try:
        overlay.install(root, package)
        raise AssertionError('copy failure accepted')
    except OSError:
        assert binary.read_bytes() == b'old version'
        assert not (root / 'usr/lib/systemd/system/inputplumber.service').exists()
    finally:
        overlay.replace = original
    for name, kind in [('inputplumber/usr/../../etc/passwd', tarfile.REGTYPE),
                       ('inputplumber/usr/bin/unsafe', tarfile.SYMTYPE),
                       ('/usr/bin/inputplumber', tarfile.REGTYPE),
                       ('inputplumber/etc/passwd', tarfile.REGTYPE)]:
        member = tarfile.TarInfo(name)
        member.type = kind
        member.size = 1 if kind == tarfile.REGTYPE else 0
        member.linkname = '/etc/passwd' if kind == tarfile.SYMTYPE else ''
        archive(package, member)
        try:
            overlay.install(root, package)
            raise AssertionError('unsafe archive accepted')
        except ValueError:
            assert binary.read_bytes() == b'old version'
    archive(package)
    overlay.SHA256 = '0' * 64
    try:
        overlay.install(root, package)
        raise AssertionError('bad hash accepted')
    except ValueError:
        pass
    archive(package)
    binary.unlink()
    binary.symlink_to(custom)
    try:
        overlay.install(root, package)
        raise AssertionError('target symlink accepted')
    except ValueError:
        assert custom.read_text() == 'keep custom'
print('PASS: verified archive scope, atomic replacement, backup/rollback, modes and custom configuration preservation')
