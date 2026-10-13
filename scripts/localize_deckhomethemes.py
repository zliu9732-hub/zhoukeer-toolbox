#!/usr/bin/env python3
"""将用户下载的固定官方包本机汉化；Renkit 不分发上游未授权的代码或资源。"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data/deckhomethemes_zh.json"
RUNTIME = ROOT / "assets/deckhomethemes/zh-runtime.js"
FILES = ROOT / "data/deckhomethemes_files.json"
OUTPUT_SHA256 = "9cd5fcaaf2b1f0efcbfd2e6c3787dc335bdf337ddc3fac69ce91ff4e6143b73c"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def build_frontend(source, translations, runtime):
    if sha256(source) != translations["upstream_sha256"]:
        raise ValueError("官方界面版本不匹配，请更新 Renkit 后重试")
    text = source.decode("utf-8")
    # 只拦截渲染，不全局替换字符串；原始 ID、枚举、方法名和资源名保持原字节。
    text = text.replace("SP_JSX.jsx(", "RenkitThemeHubJSX.jsx(")
    text = text.replace("SP_JSX.jsxs(", "RenkitThemeHubJSX.jsxs(")
    anchors = {
        "async function installFirmware(release, current) {":
            'async function installFirmware(release, current) {\n    throw new Error("请通过 Renkit 安装/更新 ThemeHub 中文版，主题和设置会保留。");',
        "const install = async (release) => {":
            'const install = async (release) => {\n        setMessage("请通过 Renkit 安装/更新 ThemeHub 中文版，主题和设置会保留。");\n        return;',
        "children: [RenkitThemeHubJSX.jsx(Panel, {}), RenkitThemeHubJSX.jsx(Diagnostics, {})]":
            'children: [RenkitThemeHubJSX.jsx("div", { style: { color: "#d9a441", fontSize: "14px", fontWeight: "bold", padding: "8px 12px" }, children: "RenAmamiya汉化" }), RenkitThemeHubJSX.jsx(Panel, {}), RenkitThemeHubJSX.jsx(Diagnostics, {})]',
    }
    for before, after in anchors.items():
        if text.count(before) != 1:
            raise ValueError("界面结构不符合预期，未写入中文组件")
        text = text.replace(before, after, 1)
    marker = "__RENKIT_THEMEHUB_TRANSLATIONS__"
    if runtime.count(marker) != 1:
        raise ValueError("中文组件不完整")
    payload = {key: translations[key] for key in ("strings", "children", "fragments")}
    runtime = runtime.replace(marker, json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return (runtime + "\n" + text).encode("utf-8")


def verify_files(root, translated=False):
    if root.is_symlink() or not root.is_dir():
        raise ValueError("插件目录不安全")
    # 校验整个目录，拒绝 ZIP 外链和多个身份；后端、第三方声明、资源全部保留。
    for path in root.rglob("*"):
        if path.is_symlink():
            raise ValueError("插件包含外部链接，已停止安装")
    for name, expected in json.loads(FILES.read_text()).items():
        if name.startswith("/") or ".." in Path(name).parts:
            raise ValueError("中文组件文件清单不安全")
        path = root / name
        if translated and name == "dist/index.js":
            expected = OUTPUT_SHA256
        if not path.is_file() or sha256(path.read_bytes()) != expected:
            raise ValueError("插件组件不完整或版本不匹配：" + name)


def localize(root):
    verify_files(root)
    plugin = json.loads((root / "plugin.json").read_text())
    package = json.loads((root / "package.json").read_text())
    translations = json.loads(DATA.read_text())
    if plugin.get("name") != "ThemeHub" or package.get("version") != translations["version"]:
        raise ValueError("插件名称或版本不匹配")
    index = root / "dist/index.js"
    result = build_frontend(index.read_bytes(), translations, RUNTIME.read_text())
    if sha256(result) != OUTPUT_SHA256:
        raise ValueError("中文界面校验失败")
    temporary = index.with_name(".renkit-index.js")
    temporary.write_bytes(result)
    temporary.replace(index)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin_dir", type=Path)
    parser.add_argument("--check", action="store_true", help="检查已安装中文包全部必要文件")
    args = parser.parse_args()
    try:
        if args.check:
            verify_files(args.plugin_dir, translated=True)
        else:
            localize(args.plugin_dir)
    except (OSError, ValueError, KeyError) as error:
        print("ThemeHub 汉化失败：" + str(error), file=sys.stderr)
        return 1
    print("ThemeHub 中文界面准备完成。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
