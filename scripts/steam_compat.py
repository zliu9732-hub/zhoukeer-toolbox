#!/usr/bin/env python3
"""Safely set one Steam compatibility-tool mapping in config.vdf."""

from __future__ import annotations

import argparse
import os
import re
import stat
import tempfile
from pathlib import Path


class VdfError(ValueError):
    pass


TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|[{}]|//[^\r\n]*')


def unquote(token: str) -> str:
    if not token.startswith('"'):
        raise VdfError("expected a quoted VDF key")
    return re.sub(r'\\(["\\])', r'\1', token[1:-1])


def object_ranges(text: str) -> dict[tuple[str, ...], tuple[int, int]]:
    tokens = [match for match in TOKEN.finditer(text) if not match.group().startswith("//")]
    ranges: dict[tuple[str, ...], tuple[int, int]] = {}
    stack: list[tuple[str, ...]] = []
    pending_key: tuple[str, int] | None = None

    for token in tokens:
        value = token.group()
        if value.startswith('"'):
            pending_key = (unquote(value), token.start())
        elif value == "{":
            if pending_key is None:
                raise VdfError("object has no key")
            path = (*stack[-1], pending_key[0]) if stack else (pending_key[0],)
            stack.append(path)
            ranges[path] = (pending_key[1], -1)
            pending_key = None
        elif value == "}":
            if not stack:
                raise VdfError("unexpected closing brace")
            path = stack.pop()
            ranges[path] = (ranges[path][0], token.start())
            pending_key = None
    if stack:
        raise VdfError("object has no closing brace")
    return ranges


def mapping_block(app_id: str, tool: str, indent: str) -> str:
    child = indent + "\t"
    return (
        f'{indent}"{app_id}"\n{indent}{{\n'
        f'{child}"name"\t\t"{tool}"\n'
        f'{child}"config"\t\t""\n'
        f'{child}"priority"\t\t"250"\n'
        f'{indent}}}\n'
    )


def set_mapping(path: Path, app_id: str, tool: str) -> None:
    if path.is_symlink():
        raise VdfError("config.vdf must not be a symbolic link")
    if not path.is_file():
        raise VdfError("Steam config.vdf was not found")
    original_mode = stat.S_IMODE(path.stat().st_mode)
    text = path.read_text(encoding="utf-8")
    ranges = object_ranges(text)
    steam_path = ("InstallConfigStore", "Software", "Valve", "Steam")
    mapping_path = (*steam_path, "CompatToolMapping")

    if steam_path not in ranges:
        raise VdfError("Steam config.vdf has an unexpected structure")

    app_path = (*mapping_path, app_id)
    if app_path in ranges:
        start, close = ranges[app_path]
        line_start = text.rfind("\n", 0, start) + 1
        indent = text[line_start:start]
        end = close + 1
        if end < len(text) and text[end] == "\r":
            end += 1
        if end < len(text) and text[end] == "\n":
            end += 1
        text = text[:line_start] + mapping_block(app_id, tool, indent) + text[end:]
    elif mapping_path in ranges:
        _, close = ranges[mapping_path]
        line_start = text.rfind("\n", 0, close) + 1
        closing_indent = text[line_start:close]
        text = text[:line_start] + mapping_block(app_id, tool, closing_indent + "\t") + text[line_start:]
    else:
        _, close = ranges[steam_path]
        line_start = text.rfind("\n", 0, close) + 1
        closing_indent = text[line_start:close]
        child = closing_indent + "\t"
        block = (
            f'{child}"CompatToolMapping"\n{child}{{\n'
            + mapping_block(app_id, tool, child + "\t")
            + f"{child}}}\n"
        )
        text = text[:line_start] + block + text[line_start:]

    fd, temporary = tempfile.mkstemp(prefix=".config.vdf.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as output:
            output.write(text)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, original_mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-file", type=Path, required=True)
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--tool", default="proton_experimental")
    args = parser.parse_args()
    if not args.config_file.is_absolute():
        parser.error("--config-file must be absolute")
    if not args.app_id.isdigit():
        parser.error("--app-id must be numeric")
    if not re.fullmatch(r"[a-z0-9_]+", args.tool):
        parser.error("--tool has invalid characters")
    set_mapping(args.config_file, args.app_id, args.tool)
    print("updated")


if __name__ == "__main__":
    try:
        main()
    except (OSError, UnicodeError, VdfError) as error:
        raise SystemExit(f"steam_compat.py: {error}")
