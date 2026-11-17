"""Audit historical updater/policy combinations and run each real installer path."""
import collections
import concurrent.futures
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
archive = Path(sys.argv[1]).resolve()
tags = subprocess.check_output(['git', '-C', str(ROOT), 'tag', '-l', 'v[123].*', '--sort=version:refname']).decode().split()
if 'v3.3.5' not in tags or 'v1.0' not in tags:
    raise AssertionError('缺少历史版本标签，不能跳过旧版兼容检查；请使用完整开发仓库')
groups = collections.OrderedDict()
for tag in tags:
    tree = subprocess.check_output([
        'git', '-C', str(ROOT), 'ls-tree', tag, '--',
        'update.sh', 'core/download_policy.sh', 'core/source_status.sh',
    ]).decode().splitlines()
    key = tuple((path, info.split()[2]) for info, path in (line.split('\t', 1) for line in tree))
    if len(key) != 3:
        raise AssertionError('Historical updater dependencies missing: ' + tag)
    groups.setdefault(key, []).append(tag)


def check(item):
    _, versions = item
    tag = versions[0]
    result = subprocess.run([
        sys.executable, str(ROOT / 'tests/test_legacy_auto_update.py'), str(archive), tag,
    ], env=os.environ.copy(), capture_output=True, text=True, timeout=90)
    if result.returncode:
        return False, f'{tag}..{versions[-1]}: ' + result.stdout + result.stderr
    return True, f'{tag}..{versions[-1]} ({len(versions)} releases): ' + result.stdout.strip()


failed = []
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for ok, message in pool.map(check, groups.items()):
        print(('PASS ' if ok else 'FAIL ') + message, flush=True)
        if not ok:
            failed.append(message)
if failed:
    sys.exit(1)
print(f'PASS: {len(tags)} historical tags, {len(groups)} distinct updater/policy combinations; original updater → actual release installer; customer data preserved', flush=True)
