"""Validate ThemeHub catalog/ZIP/tree contents without executing plugin code."""
import argparse
import json
import zipfile
from pathlib import Path
from framegen_package import HEX, digest, safe_path, version, zip_files

def entry(catalog):
    if not isinstance(catalog, dict) or catalog.get('schema') != 1: raise ValueError('invalid ThemeHub catalog')
    e = catalog['package']
    if e['plugin_name'] != 'ThemeHub' or e['archive_root'] != 'DeckHomeThemes' or e['mirror_id'] != 'themehub-zh-auto': raise ValueError('invalid ThemeHub identity')
    if version(e['upstream_version']) < version('1.10.7'): raise ValueError('unsupported ThemeHub version')
    if type(e['translation_revision']) is not int or not 1 <= e['translation_revision'] <= 1000: raise ValueError('invalid translation revision')
    if e['attribution'] != 'RenAmamiya': raise ValueError('invalid ThemeHub attribution')
    extra=e.get('extra_translations',{})
    if not isinstance(extra,dict) or len(extra)>10000 or any(not isinstance(k,str) or not isinstance(v,str) or not 0<len(k)<1800 or not 0<len(v)<9000 for k,v in extra.items()): raise ValueError('invalid translation data')
    for key in ['package_sha256','upstream_sha256','frontend_sha256']:
        if not isinstance(e[key], str) or not HEX.fullmatch(e[key]): raise ValueError('invalid checksum')
    files = e['files']
    if not isinstance(files, dict) or not 4 <= len(files) <= 3000: raise ValueError('invalid file list')
    for name, sha in files.items():
        safe_path(name)
        if not isinstance(sha, str) or not HEX.fullmatch(sha): raise ValueError('invalid file checksum')
    if not all(name in files for name in ['plugin.json','package.json','main.py','dist/index.js','RENKIT_UI_COVERAGE.json']): raise ValueError('incomplete ThemeHub package')
    if files['dist/index.js'] != e['frontend_sha256']: raise ValueError('invalid frontend checksum')
    if set(e['modes']) != set(files) or any(mode not in [0o644,0o755] for mode in e['modes'].values()): raise ValueError('invalid permissions')
    if not any('LICENSE' in name.upper() or name.endswith('-BSD.txt') for name in files): raise ValueError('missing license')
    return e

def merge(current, previous):
    new, old = entry(current), entry(previous)
    order = lambda e: (version(e['upstream_version']), e['translation_revision'])
    return previous if order(old) > order(new) else current

def check_tree(root, e):
    root = Path(root)
    if root.is_symlink() or not root.is_dir(): raise ValueError('unsafe plugin root')
    for name, sha in e['files'].items():
        p = root/name
        parts=Path(name).parts
        if any(root.joinpath(*parts[:i]).is_symlink() for i in range(1,len(parts)+1)) or not p.is_file() or digest(p) != sha: raise ValueError('installed file mismatch: '+name)
    if json.loads((root/'plugin.json').read_text())['name'] != 'ThemeHub' or version(json.loads((root/'package.json').read_text())['version']) != version(e['upstream_version']): raise ValueError('installed identity mismatch')

def extract(archive, root, e):
    if digest(archive) != e['package_sha256']: raise ValueError('package checksum mismatch')
    files = zip_files(archive); prefix = e['archive_root']+'/'
    if any(not n.startswith(prefix) for n in files): raise ValueError('unexpected archive root')
    relative = {n[len(prefix):]: data for n, data in files.items()}
    import hashlib
    if set(relative) != set(e['files']) or any(hashlib.sha256(data).hexdigest() != e['files'][n] for n, data in relative.items()): raise ValueError('package file list/checksum mismatch')
    root = Path(root)
    if root.exists() or root.is_symlink(): raise ValueError('extraction target already exists')
    root.mkdir(parents=True)
    for name, data in relative.items():
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);target.chmod(e['modes'][name])
    check_tree(root,e)

def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['merge','resolve','check','extract']);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--previous',type=Path);p.add_argument('--root',type=Path);p.add_argument('--archive',type=Path);a=p.parse_args()
    catalog=json.loads(a.catalog.read_text());e=entry(catalog)
    if a.mode=='merge':
        if a.previous:
            try:catalog=merge(catalog,json.loads(a.previous.read_text()))
            except (OSError,ValueError,KeyError,TypeError):pass
        print(json.dumps(catalog,ensure_ascii=False));return
    if a.mode=='resolve':print('\t'.join([e['upstream_version'],e['mirror_id'],e['package_sha256']]));return
    if a.mode=='check':check_tree(a.root,e)
    else:extract(a.archive,a.root,e)

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile) as error:raise SystemExit('ThemeHub package check failed: '+str(error))
