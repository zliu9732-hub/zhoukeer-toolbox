"""Check the complete official DeckyGCM tree as data; never import plugin code."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys

ROOT = Path(__file__).resolve().parents[1]


def check(directory, inventory=None):
    inventory = inventory or json.loads((ROOT / 'data/deckygcm_files.json').read_text())
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError('未找到完整插件目录')
    for name, digest in inventory['files'].items():
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or str(relative) != name:
            raise ValueError('插件文件清单异常')
        target = directory / name
        for part in (target, *target.parents):
            if part == directory.parent:
                break
            if part.is_symlink():
                raise ValueError('插件文件不能是链接')
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError('插件文件缺失或不完整：' + name)
    metadata = json.loads((directory / 'plugin.json').read_text())
    package = json.loads((directory / 'package.json').read_text())
    if metadata.get('name') != 'DeckyGCM' or package.get('version') != inventory['version']:
        raise ValueError('插件名称或版本不符合预期')


if __name__ == '__main__':
    try:
        check(Path(sys.argv[1]))
    except (OSError, ValueError, IndexError) as error:
        print('DeckyGCM 文件检查未通过：' + str(error), file=sys.stderr)
        sys.exit(1)
