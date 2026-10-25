#!/usr/bin/env python3
"""Display-only Chinese localization of the pinned, complete Screen Colors ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

from framegen_package import check_tree, extract_verified

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / "data/screen_colors_files.json"
ASSETS = ROOT / "assets/screen-colors"
DATA = ROOT / "data/screen_colors_zh.json"


def metadata(translated=False):
    result = json.loads(META.read_text())
    if translated:
        result["files"] = result["translated_files"]
        result["plugin_name"] = result["translated_name"]
    return result


def build_frontend(source):
    meta = metadata()
    if hashlib.sha256(source).hexdigest() != meta["files"]["dist/index.js"]:
        raise ValueError("unrecognized upstream frontend")
    text = source.decode()
    start, end = text.index("const DICT = {"), text.index('const getState = callable("get_state");')
    # Verify the actual upstream UI key inventory, not just our own dictionary.
    english = re.search(r"en: \{(.*?)\n    \},\n    es:", text[start:end], re.S)
    if english is None:
        raise ValueError("upstream language table missing")
    keys = re.findall(r'"([^"\n]+)":', english[1])
    translations = json.loads(DATA.read_text())
    if set(keys) != set(translations) or len(keys) != len(translations):
        raise ValueError("incomplete Chinese UI inventory")
    text = text[:start] + text[end:]
    for before, after in [
        ("Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.",
         "无法连接插件商城：接口尚未初始化，请重启插件商城后再试。"),
        ('const manifest = {"name":"Screen Colors"};', 'const manifest = ' + json.dumps({"name": meta["translated_name"]}, ensure_ascii=False, separators=(",", ":")) + ';'),
        ('    name: "Screen Colors",', '    name: ' + json.dumps(meta["translated_name"], ensure_ascii=False) + ','),
        ('children: state.detail', 'children: renkitScreenDetail(state.detail)'),
        ('titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: t("title") }),',
         'titleView: renkitScreenTitle(SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: t("title") })),')
    ]:
        if text.count(before) != 1:
            raise ValueError("upstream display or identity layout changed")
        text = text.replace(before, after, 1)
    runtime = (ASSETS / "zh-runtime.js").read_text()
    if runtime.count("__SCREEN_COLORS_ZH__") != 1:
        raise ValueError("invalid Chinese runtime")
    runtime = runtime.replace("__SCREEN_COLORS_ZH__", json.dumps(translations, ensure_ascii=False, separators=(",", ":")))
    return (runtime + "\n" + text).encode()


def make_chinese(root):
    """Called only after full upstream archive and per-file validation."""
    root = Path(root)
    index = root / "dist/index.js"
    index.write_bytes(build_frontend(index.read_bytes()))
    plugin_path = root / "plugin.json"
    plugin = json.loads(plugin_path.read_text())
    plugin["name"] = metadata()["translated_name"]
    plugin["publish"]["description"] = "调整游戏模式下的屏幕色彩，提供影院、鲜艳、舒适和类 OLED 效果。汉化：RenAmamiya。"
    plugin_path.write_text(json.dumps(plugin, ensure_ascii=False, indent=2) + "\n")
    package_path = root / "package.json"
    package = json.loads(package_path.read_text())
    package["description"] = "游戏模式屏幕色彩调整与类 OLED 效果。中文汉化：RenAmamiya。"
    package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n")
    shutil.copy2(ASSETS / "RENKIT_ZH.md", root / "RENKIT_ZH.md")
    for source in (ASSETS / "source").rglob("*"):
        if source.is_file():
            target = root / source.relative_to(ASSETS / "source")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def verify(root):
    meta = metadata(True)
    if not meta["files"]:
        raise ValueError("Chinese release file inventory missing")
    check_tree(root, meta)
    # Python code, numerics, RPC names and licenses must remain byte-identical.
    upstream = metadata()
    for name in ("main.py", "LICENSE", "CREDITS.md"):
        if meta["files"].get(name) != upstream["files"][name]:
            raise ValueError("backend or attribution changed")


def prepare(archive, output):
    output = Path(output)
    if output.is_symlink() or (output.exists() and (not output.is_dir() or any(output.iterdir()))):
        raise ValueError("staging is not empty")
    extract_verified(archive, output, metadata())
    make_chinese(output)
    verify(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "check"])
    parser.add_argument("root", type=Path)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    try:
        if args.mode == "check":
            verify(args.root)
        else:
            if args.archive is None:
                parser.error("--archive is required")
            prepare(args.archive, args.root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Screen Colors package validation failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
