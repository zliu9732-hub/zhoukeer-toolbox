"""Verify pinned upstream files, then apply the two SteamOS compatibility changes."""
import hashlib
from pathlib import Path
import re
import shutil
import sys


def prepare(source, destination):
    sums = source / 'SHA256SUMS'
    expected_names = {'PKGBUILD', 'Makefile', 'dkms.conf', 'claw_rt721_amp.c',
                      'claw-rt721-fix.service', 'claw-rt721-fix-sleep',
                      'README.md', 'TECHNICAL.md', 'LICENSE'}
    seen = set()
    for line in sums.read_text().splitlines():
        checksum, name = line.split('  ')
        if name not in expected_names or name in seen:
            raise ValueError('Unexpected source manifest entry')
        path = source / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Unsafe source file')
        if hashlib.sha256(path.read_bytes()).hexdigest() != checksum:
            raise ValueError(f'Source checksum mismatch: {name}')
        seen.add(name)
    if seen != expected_names:
        raise ValueError('Incomplete source manifest')
    destination.mkdir(mode=0o700)
    for name in sorted(seen):
        shutil.copyfile(source / name, destination / name)
    makefile = destination / 'Makefile'
    original = makefile.read_text()
    if original.count(' LLVM=1') != 2:
        raise ValueError('Unsupported Makefile')
    makefile.write_text(original.replace(' LLVM=1', ''))
    driver = destination / 'claw_rt721_amp.c'
    original = driver.read_text()
    old = '!strcmp(product, "Claw 8 EX AI+ CG3EM") &&'
    new = ('(!strcmp(product, "Claw 8 EX AI+ CG3EM") || '
           '!strcmp(product, "Claw 8 EX AI+ CG3EM Launch Pack")) &&')
    if original.count(old) != 1:
        raise ValueError('Unsupported DMI check')
    driver.write_text(original.replace(old, new))
    # Recalculate all inputs after verifying the pinned bundle. Upstream's README hash
    # is stale at this commit; preserving it would reject even the unchanged README.
    pkgbuild = destination / 'PKGBUILD'
    original = pkgbuild.read_text()
    names = ['claw_rt721_amp.c', 'Makefile', 'dkms.conf', 'README.md',
             'claw-rt721-fix.service', 'claw-rt721-fix-sleep']
    matches = re.findall(r"sha256sums=\(([^)]*)\)", original)
    if len(matches) != 1 or len(re.findall(r"'[0-9a-f]{64}'", matches[0])) != 6:
        raise ValueError('Unsupported package checksums')
    checksums = ' '.join("'" + hashlib.sha256((destination / name).read_bytes()).hexdigest()
                         + "'" for name in names)
    original = re.sub(r"sha256sums=\([^)]*\)", 'sha256sums=(' + checksums + ')', original)
    if original.count("depends=('dkms' 'clang')") != 1:
        raise ValueError('Unsupported build dependencies')
    original = original.replace("depends=('dkms' 'clang')", "depends=('dkms' 'gcc')")
    # Independent of the user's makepkg.conf compression preferences.
    pkgbuild.write_text(original + "\nPKGEXT='.pkg.tar.zst'\n")


if __name__ == '__main__':
    try:
        prepare(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, IndexError) as error:
        print(f'音频修复文件检查失败：{error}', file=sys.stderr)
        sys.exit(1)
