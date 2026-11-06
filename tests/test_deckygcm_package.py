"""Inspect bytes only, including the actual official ZIP when supplied."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checker', ROOT / 'scripts/deckygcm_package.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
inventory = json.loads((ROOT / 'data/deckygcm_files.json').read_text())
assert len(inventory['files']) == 354
assert 'py_modules/_gcm_core/auth.pyc' in inventory['files']
assert 'py_modules/_vendor/rapidfuzz/fuzz_cpp.cpython-314-x86_64-linux-gnu.so' in inventory['files']
assert 'gcm/LICENSE.txt' in inventory['files'] and 'LICENSE' in inventory['files']

def rejects(directory, fixture=None):
    try:
        checker.check(directory, fixture)
    except ValueError:
        return
    raise AssertionError('Incomplete or redirected plugin was accepted')

with tempfile.TemporaryDirectory(prefix='deckygcm-files-') as temporary:
    base = Path(temporary)
    root = base / 'DeckyGCM'
    root.mkdir()
    fixture = {'version': '1.0.1', 'files': {}}
    for name, content in {'plugin.json': b'{"name":"DeckyGCM"}', 'package.json': b'{"version":"1.0.1"}',
                          'main.py': b'# never executed', 'py_modules/backend.pyc': b'fixture bytecode'}.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        fixture['files'][name] = hashlib.sha256(content).hexdigest()
    checker.check(root, fixture)
    (root / 'py_modules/backend.pyc').write_bytes(b'corrupt')
    rejects(root, fixture)
    shutil.rmtree(root / 'py_modules')
    outside = base / 'outside'
    outside.mkdir()
    (outside / 'backend.pyc').write_bytes(b'fixture bytecode')
    (root / 'py_modules').symlink_to(outside, target_is_directory=True)
    rejects(root, fixture)
    if len(sys.argv) > 1:
        archive = Path(sys.argv[1])
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == inventory['sha256']
        with zipfile.ZipFile(archive) as z:
            assert set(z.namelist()) == {'DeckyGCM/' + name for name in inventory['files']}
            for name, digest in inventory['files'].items():
                assert hashlib.sha256(z.read('DeckyGCM/' + name)).hexdigest() == digest
            z.extractall(base / 'actual')
        actual = base / 'actual/DeckyGCM'
        checker.check(actual)
        (actual / 'py_modules/_gcm_core/auth.pyc').unlink()
        rejects(actual)
print('PASS: complete official inventory, every runtime/dependency/license hash, damaged/missing backend and symlink rejection; plugin code never imported or executed')
