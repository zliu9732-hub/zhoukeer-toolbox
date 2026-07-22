#!/usr/bin/env python3
"""Safely add or update a single Steam non-Steam shortcut in shortcuts.vdf."""

from __future__ import annotations

import argparse
import os
import stat
import tempfile
import zlib
from pathlib import Path


TYPE_OBJECT = 0
TYPE_STRING = 1
TYPE_INT32 = 2
TYPE_FLOAT = 3
TYPE_POINTER = 4
TYPE_WSTRING = 5
TYPE_COLOR = 6
TYPE_UINT64 = 7
TYPE_END = 8
FIXED_SIZES = {
    TYPE_INT32: 4,
    TYPE_FLOAT: 4,
    TYPE_POINTER: 4,
    TYPE_COLOR: 4,
    TYPE_UINT64: 8,
}


class VdfError(ValueError):
    pass


def read_cstring(data: bytes, offset: int) -> tuple[bytes, int]:
    end = data.find(b"\0", offset)
    if end < 0:
        raise VdfError("unterminated string")
    return data[offset:end], end + 1


def read_wstring(data: bytes, offset: int) -> tuple[bytes, int]:
    cursor = offset
    while cursor + 1 < len(data):
        if data[cursor:cursor + 2] == b"\0\0":
            return data[offset:cursor], cursor + 2
        cursor += 2
    raise VdfError("unterminated wide string")


def parse_object(data: bytes, offset: int) -> tuple[list[list[object]], int]:
    entries: list[list[object]] = []
    while True:
        if offset >= len(data):
            raise VdfError("object has no terminator")
        value_type = data[offset]
        offset += 1
        if value_type == TYPE_END:
            return entries, offset

        key, offset = read_cstring(data, offset)
        if value_type == TYPE_OBJECT:
            value, offset = parse_object(data, offset)
        elif value_type == TYPE_STRING:
            value, offset = read_cstring(data, offset)
        elif value_type == TYPE_WSTRING:
            value, offset = read_wstring(data, offset)
        elif value_type in FIXED_SIZES:
            size = FIXED_SIZES[value_type]
            if offset + size > len(data):
                raise VdfError("truncated numeric value")
            value = data[offset:offset + size]
            offset += size
        else:
            raise VdfError(f"unsupported VDF type: {value_type}")
        entries.append([value_type, key, value])


def encode_object(entries: list[list[object]]) -> bytes:
    output = bytearray()
    for value_type, key, value in entries:
        output.append(int(value_type))
        output.extend(bytes(key))
        output.append(0)
        if value_type == TYPE_OBJECT:
            output.extend(encode_object(value))
        else:
            output.extend(bytes(value))
            if value_type == TYPE_STRING:
                output.append(0)
            elif value_type == TYPE_WSTRING:
                output.extend(b"\0\0")
    output.append(TYPE_END)
    return bytes(output)


def load_shortcuts(path: Path) -> list[list[object]]:
    if not path.exists():
        return []
    data = path.read_bytes()
    if not data:
        return []
    if data[0] != TYPE_OBJECT:
        raise VdfError("shortcuts.vdf root is not an object")
    key, offset = read_cstring(data, 1)
    if key != b"shortcuts":
        raise VdfError("shortcuts.vdf has an unexpected root key")
    entries, offset = parse_object(data, offset)
    # Steam commonly writes a second TYPE_END byte after the named root object.
    # Older toolbox files used only the object's own terminator; accept both, but
    # continue rejecting arbitrary suffixes so a damaged VDF is never overwritten.
    trailing = data[offset:]
    if len(trailing) > 4 or any(value != TYPE_END for value in trailing):
        raise VdfError("shortcuts.vdf contains trailing data")
    return entries


def field_string(key: str, value: str) -> list[object]:
    return [TYPE_STRING, key.encode(), value.encode("utf-8")]


def field_int(key: str, value: int) -> list[object]:
    return [TYPE_INT32, key.encode(), int(value).to_bytes(4, "little", signed=True)]


def quote_path(value: str) -> str:
    return f'"{value}"'


def entry_value(entry: list[object], key: bytes) -> str | None:
    for value_type, candidate_key, value in entry[2]:
        if value_type == TYPE_STRING and candidate_key == key:
            return bytes(value).decode("utf-8", errors="replace")
    return None


def set_string(entry: list[object], key: str, value: str) -> None:
    key_bytes = key.encode()
    for field in entry[2]:
        if field[0] == TYPE_STRING and field[1] == key_bytes:
            field[2] = value.encode("utf-8")
            return
    entry[2].append(field_string(key, value))


def next_index(entries: list[list[object]]) -> int:
    indexes = [int(bytes(item[1])) for item in entries if bytes(item[1]).isdigit()]
    return max(indexes, default=-1) + 1


def make_shortcut(
    index: int, name: str, exe: str, start_dir: str, launch_options: str = ""
) -> list[object]:
    fields: list[list[object]] = [
        field_string("appname", name),
        field_string("exe", quote_path(exe)),
        field_string("StartDir", quote_path(start_dir)),
        field_string("icon", ""),
        field_string("ShortcutPath", ""),
        field_string("LaunchOptions", launch_options),
        field_int("IsHidden", 0),
        field_int("AllowDesktopConfig", 1),
        field_int("AllowOverlay", 1),
        field_int("OpenVR", 0),
        field_int("Devkit", 0),
        field_string("DevkitGameID", ""),
        field_int("LastPlayTime", 0),
        field_string("FlatpakAppID", ""),
        [TYPE_OBJECT, b"tags", []],
    ]
    return [TYPE_OBJECT, str(index).encode(), fields]


def save_shortcuts(path: Path, entries: list[list[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (
        bytes([TYPE_OBJECT]) + b"shortcuts\0" + encode_object(entries) + bytes([TYPE_END])
    )
    fd, temporary_path = tempfile.mkstemp(prefix=".shortcuts.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary_path, stat.S_IRUSR | stat.S_IWUSR)
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def add_shortcut(args: argparse.Namespace) -> None:
    entries = load_shortcuts(args.shortcut_file)
    quoted_exe = quote_path(args.exe)
    for entry in entries:
        if entry[0] == TYPE_OBJECT and entry_value(entry, b"exe") == quoted_exe:
            if entry_value(entry, b"appname") != args.name:
                set_string(entry, "appname", args.name)
                set_string(entry, "StartDir", quote_path(args.start_dir))
                set_string(entry, "LaunchOptions", args.launch_options)
                save_shortcuts(args.shortcut_file, entries)
                print("updated")
                return
            if (
                entry_value(entry, b"StartDir") != quote_path(args.start_dir)
                or entry_value(entry, b"LaunchOptions") != args.launch_options
            ):
                set_string(entry, "StartDir", quote_path(args.start_dir))
                set_string(entry, "LaunchOptions", args.launch_options)
                save_shortcuts(args.shortcut_file, entries)
                print("updated")
                return
            print("existing")
            return
    for entry in entries:
        if entry[0] != TYPE_OBJECT or entry_value(entry, b"appname") != args.name:
            continue
        set_string(entry, "exe", quoted_exe)
        set_string(entry, "StartDir", quote_path(args.start_dir))
        set_string(entry, "LaunchOptions", args.launch_options)
        save_shortcuts(args.shortcut_file, entries)
        print("updated")
        return
    entries.append(
        make_shortcut(
            next_index(entries), args.name, args.exe, args.start_dir, args.launch_options
        )
    )
    save_shortcuts(args.shortcut_file, entries)
    print("added")


def update_shortcut(args: argparse.Namespace) -> None:
    entries = load_shortcuts(args.shortcut_file)
    old_exe = quote_path(args.old_exe)
    for entry in entries:
        if entry[0] != TYPE_OBJECT or entry_value(entry, b"exe") != old_exe:
            continue
        set_string(entry, "exe", quote_path(args.new_exe))
        set_string(entry, "StartDir", quote_path(str(Path(args.new_exe).parent)))
        save_shortcuts(args.shortcut_file, entries)
        print("updated")
        return
    raise VdfError("the installer shortcut was not found")


def verify_shortcut(args: argparse.Namespace) -> None:
    entries = load_shortcuts(args.shortcut_file)
    quoted_exe = quote_path(args.exe)
    for entry in entries:
        if (
            entry[0] == TYPE_OBJECT
            and entry_value(entry, b"appname") == args.name
            and entry_value(entry, b"exe") == quoted_exe
        ):
            if args.icon and entry_value(entry, b"icon") != args.icon:
                raise VdfError("the shortcut icon was not written")
            if (
                args.launch_options is not None
                and entry_value(entry, b"LaunchOptions") != args.launch_options
            ):
                raise VdfError("the shortcut launch options were not written")
            print("verified")
            return
    raise VdfError("the expected shortcut was not written")


def set_shortcut_icon(args: argparse.Namespace) -> None:
    entries = load_shortcuts(args.shortcut_file)
    quoted_exe = quote_path(args.exe)
    for entry in entries:
        if (
            entry[0] == TYPE_OBJECT
            and entry_value(entry, b"appname") == args.name
            and entry_value(entry, b"exe") == quoted_exe
        ):
            set_string(entry, "icon", args.icon)
            save_shortcuts(args.shortcut_file, entries)
            print("updated")
            return
    raise VdfError("the shortcut to receive the icon was not found")


def shortcut_app_id(name: str, exe: str) -> int:
    checksum = zlib.crc32((quote_path(exe) + name).encode("utf-8"))
    return checksum | 0x80000000


def shortcut_game_id(name: str, exe: str) -> int:
    return (shortcut_app_id(name, exe) << 32) | 0x02000000


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shortcut-file", type=Path, required=True)
    subparsers = parser.add_subparsers(dest="command", required=True)

    add = subparsers.add_parser("add")
    add.add_argument("--name", required=True)
    add.add_argument("--exe", required=True)
    add.add_argument("--start-dir", required=True)
    add.add_argument("--launch-options", default="")

    update = subparsers.add_parser("update")
    update.add_argument("--old-exe", required=True)
    update.add_argument("--new-exe", required=True)

    verify = subparsers.add_parser("verify")
    verify.add_argument("--name", required=True)
    verify.add_argument("--exe", required=True)
    verify.add_argument("--icon")
    verify.add_argument("--launch-options")

    set_icon = subparsers.add_parser("set-icon")
    set_icon.add_argument("--name", required=True)
    set_icon.add_argument("--exe", required=True)
    set_icon.add_argument("--icon", required=True)

    appid = subparsers.add_parser("appid")
    appid.add_argument("--name", required=True)
    appid.add_argument("--exe", required=True)

    gameid = subparsers.add_parser("gameid")
    gameid.add_argument("--name", required=True)
    gameid.add_argument("--exe", required=True)

    args = parser.parse_args()
    if not os.path.isabs(args.shortcut_file):
        parser.error("--shortcut-file must be absolute")
    if args.command == "add":
        if not os.path.isabs(args.exe) or not os.path.isabs(args.start_dir):
            parser.error("shortcut paths must be absolute")
        add_shortcut(args)
    elif args.command == "update":
        if not os.path.isabs(args.old_exe) or not os.path.isabs(args.new_exe):
            parser.error("shortcut paths must be absolute")
        update_shortcut(args)
    elif args.command == "verify":
        if not os.path.isabs(args.exe):
            parser.error("shortcut paths must be absolute")
        if args.icon and not os.path.isabs(args.icon):
            parser.error("shortcut icon path must be absolute")
        verify_shortcut(args)
    elif args.command == "set-icon":
        if not os.path.isabs(args.exe) or not os.path.isabs(args.icon):
            parser.error("shortcut and icon paths must be absolute")
        if not os.path.isfile(args.icon):
            parser.error("shortcut icon must be an existing file")
        set_shortcut_icon(args)
    elif args.command == "appid":
        if not os.path.isabs(args.exe):
            parser.error("shortcut paths must be absolute")
        print(shortcut_app_id(args.name, args.exe))
    else:
        if not os.path.isabs(args.exe):
            parser.error("shortcut paths must be absolute")
        print(shortcut_game_id(args.name, args.exe))


if __name__ == "__main__":
    try:
        main()
    except (OSError, VdfError) as error:
        raise SystemExit(f"steam_shortcut.py: {error}")
