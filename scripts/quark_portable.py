#!/usr/bin/env python3
"""Stage the reviewed portable client; never execute archive contents."""
import argparse
import hashlib
import json
import lzma
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tempfile
import sys

VERSION = '3.24.0'
DIRECTORY = f'QuarkCloudDrive-Portable-{VERSION}'
INVENTORY = Path(__file__).resolve().parents[1] / 'data/quark_portable_files.json'


def digest_file(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def inventory():
    return json.loads(INVENTORY.read_text(encoding='utf-8'))


def target_directory(drive):
    # drive_c itself may be the existing managed external-storage link.
    drive = drive.resolve(strict=True)
    if not drive.is_dir():
        raise ValueError('程序保存位置不可用。')
    return drive / DIRECTORY


def check(drive):
    target = target_directory(drive)
    if target.is_symlink() or not target.is_dir():
        raise ValueError('尚未准备好夸克网盘程序。')
    for name, expected in inventory().items():
        path = target
        for part in PurePosixPath(name).parts:
            path = path / part
            if path.is_symlink():
                raise ValueError('夸克网盘程序位置异常，已有文件已保留。')
        if not path.is_file() or path.stat().st_size != expected['size'] or digest_file(path) != expected['sha256']:
            raise ValueError('夸克网盘程序不完整，已有文件已保留。')
    return target / 'QuarkCloudDrive.exe'


def install(archive, drive):
    target = target_directory(drive)
    if target.exists() or target.is_symlink():
        # Never overwrite an existing program or account settings.
        return check(drive)
    expected = inventory()
    stage = Path(tempfile.mkdtemp(prefix='.quark-prepare-', dir=target.parent))
    try:
        with tarfile.open(archive, 'r:xz') as bundle:
            members = bundle.getmembers()
            seen = set()
            for member in members:
                path = PurePosixPath(member.name)
                if (not member.isfile() or not member.name.startswith('quark-cloud-drive/')
                        or any(part in ('', '.', '..') for part in member.name.split('/'))
                        or '\\' in member.name or path.is_absolute()):
                    raise ValueError('夸克网盘文件检查未通过，已有文件已保留。')
                name = str(path.relative_to('quark-cloud-drive'))
                if name not in expected or name in seen or member.size != expected[name]['size']:
                    raise ValueError('夸克网盘文件检查未通过，已有文件已保留。')
                seen.add(name)
            if seen != set(expected):
                raise ValueError('夸克网盘程序文件不完整，已有文件已保留。')
            for member in members:
                name = str(PurePosixPath(member.name).relative_to('quark-cloud-drive'))
                output = stage / name
                output.parent.mkdir(parents=True, exist_ok=True)
                value = hashlib.sha256()
                with bundle.extractfile(member) as source, output.open('xb') as dest:
                    for block in iter(lambda: source.read(1024 * 1024), b''):
                        value.update(block)
                        dest.write(block)
                if value.hexdigest() != expected[name]['sha256']:
                    raise ValueError('夸克网盘文件检查未通过，已有文件已保留。')
                output.chmod(0o644)
        # mkdir is an exclusive claim; another process cannot be overwritten.
        target.mkdir()
        try:
            for child in stage.iterdir():
                child.rename(target / child.name)
        except OSError:
            shutil.rmtree(target)
            raise
        return target / 'QuarkCloudDrive.exe'
    finally:
        shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['check', 'install'])
    parser.add_argument('drive', type=Path)
    parser.add_argument('archive', type=Path, nargs='?')
    args = parser.parse_args()
    try:
        if args.action == 'check':
            print(check(args.drive))
        else:
            if args.archive is None:
                raise ValueError('缺少夸克网盘文件。')
            print(install(args.archive, args.drive))
    except (OSError, ValueError, EOFError, lzma.LZMAError, tarfile.TarError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
