#!/usr/bin/env python3
"""Verify bundled RC74XA files without importing or running the repair engine."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys

MANIFEST_SHA256 = "c6f4ef44a1c42c3b9a83ad30eabc5375a0cd8ffc8044f5d4c9d69674601f5ce0"


def verify(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError("missing package directory")
    manifest = root / "manifest.json"
    if manifest.is_symlink() or not manifest.is_file():
        raise ValueError("missing manifest")
    data = manifest.read_bytes()
    if hashlib.sha256(data).hexdigest() != MANIFEST_SHA256:
        raise ValueError("manifest checksum mismatch")
    files = json.loads(data)["sha256"]
    for name, digest in files.items():
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or str(path) != name:
            raise ValueError("unsafe manifest path")
        target = root / name
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError("file checksum mismatch: " + name)
    actual = set()
    for target in root.rglob("*"):
        if target.is_symlink():
            raise ValueError("symlink in package")
        if target.is_file():
            actual.add(target.relative_to(root).as_posix())
        elif not target.is_dir():
            raise ValueError("unsupported file type")
    if actual != set(files) | {"manifest.json"}:
        raise ValueError("package file list mismatch")


if __name__ == "__main__":
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, KeyError, IndexError) as error:
        print("修复组件检查未通过，请更新 Renkit 后重试。", file=sys.stderr)
        print("RC74XA package: " + str(error), file=sys.stderr)
        sys.exit(1)
