#!/usr/bin/env python3
"""Prepare a pinned AYANEO 3 plugin; only its display layer changes."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from framegen_package import check_tree, extract_verified

ROOT = Path(__file__).resolve().parent.parent
FILES = ROOT / 'data/ayaneo3_files.json'
DATA = ROOT / 'data/ayaneo3_zh.json'
RUNTIME = ROOT / 'assets/ayaneo3/zh-runtime.js'
TITLE = 'titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "AYANEO 3 Companion" })'


def metadata(translated=False):
    result = json.loads(FILES.read_text())
    if translated:
        result['files']['dist/index.js'] = result['frontend_zh_sha256']
    return result


def build_frontend(source):
    if hashlib.sha256(source).hexdigest() != metadata()['files']['dist/index.js']:
        raise ValueError('upstream frontend checksum mismatch')
    text = source.decode('utf-8')
    if text.count(TITLE) != 1 or text.count('const manifest = {"name":"AYANEO 3 Companion"};') != 1:
        raise ValueError('upstream plugin identity/layout changed')
    text = text.replace(TITLE, 'titleView: RenkitAyaneo3JSX.title(' + TITLE.split('titleView: ', 1)[1] + ')', 1)
    text = text.replace('SP_JSX.jsx(', 'RenkitAyaneo3JSX.jsx(').replace('SP_JSX.jsxs(', 'RenkitAyaneo3JSX.jsxs(')
    text = text.replace('toaster.toast(', 'RenkitAyaneo3JSX.toast(')
    runtime = RUNTIME.read_text()
    marker = '__RENKIT_AYANEO3_TRANSLATIONS__'
    if runtime.count(marker) != 1:
        raise ValueError('translation runtime incomplete')
    translations = json.loads(DATA.read_text())
    if translations['version'] != metadata()['upstream_version']:
        raise ValueError('translation version mismatch')
    runtime = runtime.replace(marker, json.dumps(translations, ensure_ascii=False, separators=(',', ':')))
    return (runtime + '\n' + text).encode('utf-8')


def verify(root, translated=True):
    check_tree(root, metadata(translated))


def prepare(archive, output):
    output = Path(output)
    if output.exists() and (output.is_symlink() or any(output.iterdir())):
        raise ValueError('staging directory is not empty')
    extract_verified(archive, output, metadata())
    index = output / 'dist/index.js'
    result = build_frontend(index.read_bytes())
    if hashlib.sha256(result).hexdigest() != metadata()['frontend_zh_sha256']:
        raise ValueError('Chinese frontend checksum mismatch')
    temporary = index.with_name('.renkit-index.js')
    temporary.write_bytes(result)
    temporary.replace(index)
    verify(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['prepare', 'check'])
    parser.add_argument('root', type=Path)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    try:
        if args.mode == 'check':
            verify(args.root)
        else:
            if args.archive is None:
                parser.error('--archive is required for prepare')
            prepare(args.archive, args.root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('AYANEO3 package validation failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
