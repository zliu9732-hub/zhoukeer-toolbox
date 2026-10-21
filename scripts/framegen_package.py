#!/usr/bin/env python3
"""Validate release/catalog contents without importing or running plugin code."""
import argparse
import hashlib
import json
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

KINDS = {
    'lsfg-v2': {'repo': 'zhoukeer-toolbox-mirror-4', 'target': 'Decky LSFG-VK', 'baseline': '0.14.4',
                'roots': ['Decky LSFG-VK', '小黄鸭2.0'], 'names': ['小黄鸭2.0', 'Decky LSFG-VK'],
                'ids': ['lsfg-v2-zh-signed', 'lsfg-v2-zh-auto']},
    'fsr4': {'repo': 'zhoukeer-toolbox-mirror-3', 'target': 'Decky-Framegen', 'baseline': '0.17',
             'roots': ['Decky-Framegen'], 'names': ['Decky-Framegen（FSR4）', 'Decky-Framegen'],
             'ids': ['fsr4-zh-signed', 'fsr4-zh-auto']},
}
HEX = re.compile(r'[0-9a-f]{64}')

def version(v):
    if not isinstance(v, str) or len(v) > 64 or not re.fullmatch(r'v?\d+(?:\.\d+){1,3}', v):
        raise ValueError('invalid release version')
    numbers = tuple(int(n) for n in v.lstrip('v').split('.'))
    return numbers + (0,) * (4-len(numbers))

def safe_path(p):
    if not isinstance(p, str) or not p or len(p) > 500 or '\\' in p or any(ord(c) < 32 for c in p):
        raise ValueError('invalid package path')
    path = PurePosixPath(p)
    if path.is_absolute() or any(c in ['', '.', '..'] for c in p.split('/')):
        raise ValueError('unsafe package path')
    return p

def digest(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for block in iter(lambda: f.read(1048576), b''):
            h.update(block)
    return h.hexdigest()

def zip_modes(path):
    modes = {}
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            name = info.filename
            if not info.flag_bits & 0x800:
                try: name = name.encode('cp437').decode('utf-8')
                except UnicodeError: pass
            modes[name] = 0o755 if (info.external_attr >> 16) & 0o111 else 0o644
    return modes

def entry(catalog, kind):
    if not isinstance(catalog, dict) or catalog.get('schema') != 1 or not isinstance(catalog.get('packages'), dict):
        raise ValueError('unsupported catalog')
    e = catalog['packages'][kind]
    if not isinstance(e,dict):
        raise ValueError('invalid package entry')
    k = KINDS[kind]
    if version(e['upstream_version']) < version(k['baseline']):
        raise ValueError('release below supported baseline')
    if e['mirror_id'] not in k['ids'] or e['archive_root'] not in k['roots'] or e['plugin_name'] not in k['names']:
        raise ValueError('unexpected plugin identity')
    if e['attribution'] not in ['RenAmamiya', 'upstream']:
        raise ValueError('invalid attribution')
    if 'translation_revision' in e and (type(e['translation_revision']) is not int or not 1 <= e['translation_revision'] <= 1000):
        raise ValueError('invalid translation revision')
    for key in ['package_sha256', 'upstream_sha256', 'frontend_sha256']:
        if not HEX.fullmatch(e[key]):
            raise ValueError('invalid checksum')
    files = e['files']
    if not isinstance(files, dict) or not 4 <= len(files) <= 3000:
        raise ValueError('invalid file list')
    for path, sha in files.items():
        safe_path(path)
        if not isinstance(sha, str) or not HEX.fullmatch(sha):
            raise ValueError('invalid file checksum')
    if files.get('dist/index.js') != e['frontend_sha256'] or not all(p in files for p in ['plugin.json', 'package.json', 'main.py']):
        raise ValueError('incomplete plugin')
    if not any(p.upper().startswith('LICENSE') for p in files) or not any(p.startswith('bin/') for p in files):
        raise ValueError('missing license or runtime')
    if 'modes' in e and (set(e['modes']) != set(files) or any(m not in [0o644,0o755] for m in e['modes'].values())):
        raise ValueError('invalid file permissions')
    return e

def merge_catalog(current, previous):
    result = {'schema': 1, 'packages': {}}
    for kind in KINDS:
        new = entry(current, kind)
        try:
            old = entry(previous, kind)
            old_order = (version(old['upstream_version']), old['attribution'] == 'upstream', old.get('translation_revision', 0))
            new_order = (version(new['upstream_version']), new['attribution'] == 'upstream', new.get('translation_revision', 0))
            result['packages'][kind] = old if old_order > new_order else new
        except (ValueError, KeyError, TypeError):
            result['packages'][kind] = new
    return result

def zip_files(path):
    """Return normalized names/bytes, rejecting links, duplicates and archive bombs."""
    result = {}
    total = 0
    with zipfile.ZipFile(path) as z:
        if len(z.infolist()) > 4000:
            raise ValueError('too many files')
        for info in z.infolist():
            if info.is_dir():
                continue
            name = info.filename
            if not info.flag_bits & 0x800:
                try:
                    name = name.encode('cp437').decode('utf-8')
                except (UnicodeError, LookupError):
                    pass
            safe_path(name)
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in [0, stat.S_IFREG]):
                raise ValueError('non-regular archive entry')
            if name in result or info.file_size > 536870912:
                raise ValueError('duplicate or oversized archive entry')
            total += info.file_size
            if total > 1073741824:
                raise ValueError('archive too large')
            result[name] = z.read(info)
    if not result:
        raise ValueError('empty archive')
    return result

def check_tree(root, e):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError('plugin directory unavailable')
    for relative, sha in e['files'].items():
        p = root / relative
        parts = PurePosixPath(relative).parts
        if any(root.joinpath(*parts[:i]).is_symlink() for i in range(1, len(parts)+1)) or not p.is_file() or digest(p) != sha:
            raise ValueError('installed file does not match release')
    if json.loads((root/'plugin.json').read_text())['name'] != e['plugin_name'] or version(json.loads((root/'package.json').read_text())['version']) != version(e['upstream_version']):
        raise ValueError('plugin version mismatch')

def extract_verified(archive, output, e):
    if digest(archive) != e['package_sha256']:
        raise ValueError('package checksum mismatch')
    files = zip_files(archive)
    prefix = e['archive_root'] + '/'
    if any(not name.startswith(prefix) for name in files):
        raise ValueError('unexpected archive root')
    relative = {name[len(prefix):]: data for name, data in files.items()}
    if set(relative) != set(e['files']):
        raise ValueError('package file list mismatch')
    for name, data in relative.items():
        if hashlib.sha256(data).hexdigest() != e['files'][name]:
            raise ValueError('package content mismatch')
    output = Path(output)
    for name, data in relative.items():
        p = output/name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        p.chmod(e.get('modes', {}).get(name, 0o644))
    check_tree(output, e)

def main():
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=['resolve', 'check', 'extract', 'versions', 'merge', 'selected'])
    p.add_argument('--catalog', type=Path)
    p.add_argument('--previous', type=Path)
    p.add_argument('--kind', choices=KINDS)
    p.add_argument('--entry-output', type=Path)
    p.add_argument('--root', type=Path)
    p.add_argument('--archive', type=Path)
    args = p.parse_args()
    if args.mode == 'selected':
        root=args.root
        if root.is_symlink() or not root.is_dir() or any((root/n).is_symlink() for n in ['plugin.json','package.json']):
            raise ValueError('not an installed 2.0 plugin')
        name=json.loads((root/'plugin.json').read_text())['name']
        v=json.loads((root/'package.json').read_text())['version']
        if name not in KINDS['lsfg-v2']['names'] or version(v) < version('0.14.0'):
            raise ValueError('not an installed 2.0 plugin')
        return
    if args.catalog is None:
        p.error('--catalog is required')
    if args.catalog.stat().st_size > 1048576 or args.catalog.is_symlink():
        raise ValueError('invalid catalog file')
    c = json.loads(args.catalog.read_text())
    if args.mode == 'merge':
        previous={}
        if args.previous and args.previous.is_file() and not args.previous.is_symlink() and args.previous.stat().st_size<=1048576:
            try: previous=json.loads(args.previous.read_text())
            except (OSError,ValueError): pass
        print(json.dumps(merge_catalog(c, previous),ensure_ascii=False))
        return
    if args.mode == 'versions':
        for kind in KINDS:
            e = entry(c, kind)
            print('\t'.join([kind, e['upstream_version'].lstrip('v'), e['package_sha256'], e['frontend_sha256']]))
        return
    e = entry(c, args.kind)
    if args.mode == 'resolve':
        if args.entry_output:
            args.entry_output.write_text(json.dumps({'schema': 1, 'packages': {args.kind: e}}, ensure_ascii=False))
        print('\t'.join([e['upstream_version'].lstrip('v'), e['mirror_id'], e['package_sha256'], e['archive_root'], e['plugin_name'], e['attribution']]))
    elif args.mode == 'check':
        check_tree(args.root, e)
    else:
        extract_verified(args.archive, args.root, e)

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        raise SystemExit('framegen package check failed: ' + str(error))
