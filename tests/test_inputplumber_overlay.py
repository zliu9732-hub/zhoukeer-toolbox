import hashlib
import importlib.util
import io
import json
import sys
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
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
    digest = archive(package)
    backup = overlay.install(root, package, digest, "0.90.0")
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
        overlay.install(root, package, digest, "0.90.0")
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
        digest = archive(package, member)
        try:
            overlay.install(root, package, digest, "0.90.0")
            raise AssertionError('unsafe archive accepted')
        except ValueError:
            assert binary.read_bytes() == b'old version'
    digest = archive(package)
    digest = '0' * 64
    try:
        overlay.install(root, package, digest, "0.90.0")
        raise AssertionError('bad hash accepted')
    except ValueError:
        pass
    digest = archive(package)
    binary.unlink()
    binary.symlink_to(custom)
    try:
        overlay.install(root, package, digest, "0.90.0")
        raise AssertionError('target symlink accepted')
    except ValueError:
        assert custom.read_text() == 'keep custom'
print('PASS: verified archive scope, atomic replacement, backup/rollback, modes and custom configuration preservation')

# This inventory is captured from the SHA256-verified upstream 0.83.1 release,
# independent of the installer's allowlist. Never run its binary in these tests.
fixture = json.loads((ROOT / 'tests/fixtures/inputplumber-v0.83.1.json').read_text())
NEW_RULE = 'usr/lib/udev/rules.d/55-8bitdo-u2-controller.rules'
NEW_TIMER = 'usr/lib/modules-load.d/inputplumber-hrtimer.conf'
OLD_RULE = 'usr/lib/udev/rules.d/50-8bitdo-u2-controller.rules'
FAKE_ELF = b'\x7fELF\x02\x01' + b'\x00' * 12 + b'\x3e\x00fixture'


def modern_archive(path, omit=(), extra=None):
    with tarfile.open(path, 'w:gz') as tar:
        for item in fixture['members']:
            name = item['name'].removeprefix('inputplumber/')
            if name in omit:
                continue
            member = tarfile.TarInfo(item['name'])
            member.type = item['type'].encode()
            if member.isdir():
                tar.addfile(member)
            else:
                data = FAKE_ELF if name == 'usr/bin/inputplumber' else b'new config'
                if name == NEW_TIMER:
                    data = b'iio_trig_hrtimer\n\n'
                member.size = len(data)
                tar.addfile(member, io.BytesIO(data))
        if extra:
            tar.addfile(extra, io.BytesIO(b'x') if extra.isfile() else None)
    return hashlib.sha256(path.read_bytes()).hexdigest()


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    root = base / 'root'
    root.mkdir()
    package = base / 'modern.tar.gz'
    digest = modern_archive(package)
    files = overlay.verified_files(package, digest)
    assert NEW_RULE in files and NEW_TIMER in files and OLD_RULE not in files
    binary = root / 'usr/bin/inputplumber'
    binary.parent.mkdir(parents=True)
    binary.write_bytes(b'old version')
    custom = root / 'etc/inputplumber/devices.d/customer.yaml'
    custom.parent.mkdir(parents=True)
    custom.write_text('preserve custom mapping')
    backup = overlay.install(root, package, digest, '0.83.1')
    assert binary.read_bytes() == FAKE_ELF
    assert (root / NEW_RULE).read_bytes() == files[NEW_RULE]
    assert (root / NEW_TIMER).read_bytes() == b'iio_trig_hrtimer\n\n'
    assert (root / NEW_TIMER).stat().st_mode & 0o777 == 0o644
    assert custom.read_text() == 'preserve custom mapping'
    overlay.restore(root, backup)
    assert binary.read_bytes() == b'old version'
    assert not (root / NEW_RULE).exists() and not (root / NEW_TIMER).exists()
    # Neither supported filename, an incomplete service, and newly-allowed
    # filenames used as links must still be rejected before any install writes.
    for omit in [(NEW_RULE,), ('usr/lib/systemd/system/inputplumber.service',)]:
        digest = modern_archive(package, omit=omit)
        try:
            overlay.install(root, package, digest, '0.83.1')
            raise AssertionError('incomplete modern package accepted')
        except ValueError:
            assert binary.read_bytes() == b'old version'
    for name, kind in [(NEW_RULE, tarfile.SYMTYPE), (NEW_TIMER, tarfile.LNKTYPE),
                       ('usr/lib/modules-load.d/unexpected.conf', tarfile.REGTYPE),
                       ('usr/lib/udev/rules.d/unexpected.rules', tarfile.REGTYPE),
                       (NEW_TIMER, tarfile.REGTYPE)]:
        member = tarfile.TarInfo('inputplumber/' + name)
        member.type = kind
        member.size = 1 if member.isfile() else 0
        member.linkname = '/etc/passwd' if member.issym() or member.islnk() else ''
        digest = modern_archive(package, omit=(name,) if kind != tarfile.REGTYPE else (), extra=member)
        try:
            overlay.install(root, package, digest, '0.83.1')
            raise AssertionError('unsafe modern package accepted: ' + name)
        except ValueError:
            assert binary.read_bytes() == b'old version'
    # A failure after writing the new timer file must restore it as well.
    digest = modern_archive(package)
    timer = root / NEW_TIMER
    timer.parent.mkdir(parents=True, exist_ok=True)
    timer.write_bytes(b'previous timer setting')
    original = overlay.replace
    def fail_new_rule(target, data, mode):
        if target == root / NEW_RULE:
            raise OSError('simulated rule copy failure')
        return original(target, data, mode)
    overlay.replace = fail_new_rule
    try:
        overlay.install(root, package, digest, '0.83.1')
        raise AssertionError('copy failure accepted')
    except OSError:
        assert binary.read_bytes() == b'old version'
        assert timer.read_bytes() == b'previous timer setting'
        assert not (root / NEW_RULE).exists()
    finally:
        overlay.replace = original
print('PASS: upstream 0.83.1 layout, renamed rule, timer config, completeness, link/unknown/duplicate rejection and rollback')

if len(sys.argv) > 1:
    assert len(sys.argv) == 2
    upstream = Path(sys.argv[1])
    with tempfile.TemporaryDirectory(prefix='inputplumber-real-package-') as temporary:
        root = Path(temporary)
        files = overlay.verified_files(upstream, fixture['source']['sha256'])
        expected = {i['name'].removeprefix('inputplumber/'): i['sha256']
                    for i in fixture['members'] if i['type'] == '0'}
        assert set(files) == set(expected)
        for name, data in files.items():
            assert hashlib.sha256(data).hexdigest() == expected[name], name
        backup = overlay.install(root, upstream, fixture['source']['sha256'], '0.83.1')
        for name, data in files.items():
            assert (root / name).read_bytes() == data, name
        overlay.restore(root, backup)
        assert all(not (root / name).exists() for name in files)
    print('PASS: actual SHA256-verified 0.83.1 archive, every deployed file, and complete restore; binary never executed')
